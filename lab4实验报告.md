# 实验四 实验报告：虚拟内存管理与内核线程调度

- 课程：操作系统（ucore / RISC-V Sv39）
- 小组成员学号：2411438、2411513
- 实验环境：Windows 11 + WSL2(Ubuntu)，`riscv64-unknown-elf-gcc` 10.2.0、`qemu-system-riscv64`
- 代码目录：本仓库根目录（即 `lab4`）
- 自测结果：`make grade` → **Total Score: 30/30**

---

## 一、实验内容概述

前三个实验里，内核已经能把物理内存管起来（`pmm`）、能建立虚拟地址到物理地址的映射（`get_pte`）、能响应中断和异常。但系统仍然只有一条执行流：从 `kern_init` 一路执行到结束，没有任何"并发"的痕迹。

本实验要在这条单执行流上补两块内容，把内核推进到"**支持多线程调度的内核**"：

1. **虚拟内存页操作**：在现有多级页表框架上实现最基本的映射维护——`page_insert()` 把物理页挂到指定线性地址上，`page_remove()` 把已有映射安全撤销，并且始终保持"页表项内容 / 物理页引用计数 / TLB 状态"三者同步。注意本实验采用**预映射**方式：建立地址空间时一次性完成所有需要的页表映射，不涉及按需分配和页面置换。
2. **内核线程机制**：实现线程控制块（`proc_struct`）的分配与初始化、内核线程的创建（`kernel_thread`/`do_fork`/`copy_thread`）、调度器（`schedule`）和上下文切换（`switch_to`），最后让 CPU 从 `idleproc` 手中交给第一个真正的内核线程 `initproc`。

对应的执行链可以概括为：

```
kern_init -> pmm_init -> pic_init/idt_init -> vmm_init -> proc_init -> cpu_idle
          -> schedule -> proc_run -> switch_to -> forkret/forkrets -> __trapret
          -> kernel_thread_entry -> init_main
```

前半段负责"把地址空间准备好"，后半段负责"让第一个可运行线程真正跑起来"。

---

## 二、本章节整体逻辑线

按"虚拟内存页操作 → 进程创建与初始化 → 进程调度"三条主线展开，每一条都是上一条的物理/逻辑前提：

1. **先有页表维护能力**。线程要运行就要有地址空间，`proc_struct.pgdir` 指向页表，而页表的建立/撤销全靠 `page_insert`/`page_remove`。所以功能模块一放在最前面，它也是 `check_pgdir()`、`check_boot_pgdir()` 能通过的前提。
2. **再能创建并登记线程**。有了地址空间，才谈得上"给线程分配内核栈、建立上下文、挂进链表"。模块二把 `kern_init` 当前的执行现场包装成 `idleproc`（第 0 个内核线程），再用 `kernel_thread` 创建 `initproc`（第 1 个内核线程）。
3. **最后让线程真正跑起来**。模块三的 `schedule` 负责"选谁"，`proc_run` 负责"换页表 + 换现场"，`switch_to` 负责"换寄存器"，三者配合把 CPU 从 `idleproc` 交出去。首次运行的线程不是从 `switch_to` 返回后继续执行调用者，而是靠 `context.ra = forkret` + 栈顶 `trapframe`，走 `forkret → forkrets → __trapret` 这条恢复链路进入 `kernel_thread_entry`，再调用 `init_main`。

这三个模块的边界非常清晰：

| 模块 | 关注点 | 关键不变量 |
| --- | --- | --- |
| 页操作 | 页表项、引用计数、TLB | 表项有效 ⇒ 引用计数已计入；表项清零 ⇒ TLB 已失效 |
| 线程创建 | PCB、内核栈、trapframe、链表 | 只有 `PROC_RUNNABLE` 才能被调度；资源失败要回滚 |
| 调度切换 | 选线程、换页表、换寄存器 | 切换过程原子（关中断），`current` 与 satp 同步更新 |

---

## 三、功能模块一：虚拟内存页操作

### 3.1 依赖的既有接口与数据结构

`kern/mm/pmm.c`、`kern/mm/pmm.h`、`kern/mm/mmu.h` 已经提供了：

- `get_pte(pgdir, la, create)`：定位目标页表项，`create=1` 时缺失的中间级页表会被分配并清零；
- `pte_create(ppn, perm)`、`pte2page()`、`page2ppn()`、`page2pa()`、`pa2page()`；
- `page_ref()` / `page_ref_inc()` / `page_ref_dec()` / `set_page_ref()`；
- `alloc_page()` / `free_page()`、`tlb_invalidate()` / `flush_tlb()`；
- `struct Page`（`ref` 引用计数、`flags`、`property` 块大小、链表项）；
- `PTE_V/R/W/X/U` 等权限位宏，以及 Sv39 的 `PDX1/PDX0/PTX/PGOFF/PTE_ADDR` 宏。

`struct Page` 数组 `pages`、`npage`、`boot_pgdir_va`、`boot_pgdir_pa` 是全局的，所有页表项都通过 `KADDR(pa)` 转成内核虚拟地址后访问。

### 3.2 `page_insert`

```c
int page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm)
{
    pte_t *ptep = get_pte(pgdir, la, 1);      // 可能分配中间级页表，可能失败
    if (ptep == NULL) return -E_NO_MEM;
    page_ref_inc(page);                        // 先计入新映射
    if (*ptep & PTE_V) {
        struct Page *old_page = pte2page(*ptep);
        if (old_page == page) page_ref_dec(page);   // 同一页重复映射：净增加为 0
        else page_remove(pgdir, la);                // 不同页：先撤销旧映射
    }
    *ptep = pte_create(page2ppn(page), PTE_V | perm);
    tlb_invalidate(pgdir, la);                 // 表项变了，TLB 必须失效
    return 0;
}
```

要点与理解：

- **顺序很关键**。如果先判断旧映射、再 `page_ref_inc`，那么"旧页恰好是被插入的同一页且引用计数为 1"时，会被 `page_remove` 误释放。先加引用再处理旧映射，才不会出现悬空页。
- **必须区分两种情况**：原地址已映射到同一物理页（只更新权限，计数不变）、已映射到其他物理页（回收旧页）。简单覆盖会漏掉旧页的引用计数，造成内存泄漏。
- **`get_pte(..., create=1)` 可能失败**（物理内存不足），此时必须原样返回 `-E_NO_MEM`，并且不能留下"半成品"表项：`get_pte` 内部只有在成功分配时才写入 `*pdep`，所以失败路径天然是干净的。
- **TLB 失效**不能省。RISC-V 只有在 `sfence.vma` 之后才会丢弃缓存的翻译，否则测试里会出现"页表已经改了但 CPU 还在用旧翻译"的怪现象。

### 3.3 `page_remove`

```c
void page_remove(pde_t *pgdir, uintptr_t la)
{
    pte_t *ptep = get_pte(pgdir, la, 0);       // 只查不建
    if (ptep != NULL && (*ptep & PTE_V)) {
        struct Page *page = pte2page(*ptep);
        if (page_ref_dec(page) == 0) free_page(page);   // 最后一个引用才真正回收
        *ptep = 0;
        tlb_invalidate(pgdir, la);
    }
}
```

要点：

- **不能假定目标地址一定有映射**：`get_pte(..., 0)` 返回 `NULL` 或表项无效时直接返回，因此 `page_remove` 可以被安全地重复调用（测试中连续两次 `page_remove(boot_pgdir_va, 2*PGSIZE)` 就是验证这一点）。
- **引用计数减到 0 才回收**：同一个物理页可以被映射到多个线性地址（如 `check_boot_pgdir()` 里 `p` 同时映射到 `0x100` 和 `0x100+PGSIZE`），只要还有一个映射就不该回收。
- 表项清零 + TLB 失效必须成对出现，否则会出现"页已经回收但 TLB 里还有旧翻译"的严重错误。

### 3.4 与测试对照

`test_lab4_pmm_basic()`（由 `tools/inject.py` 注入到 `pmm_init` 末尾）依次检查：建映射后 `ref==1`、覆盖映射后旧页 `ref==0`、重复映射同一页时 `ref` 不变且空闲页数不变、多次 `page_remove` 不崩溃且最终三个页的 `ref` 都为 0。这些都对应上面的四条不变量。

---

## 四、功能模块二：进程创建及初始化

### 4.1 `alloc_proc`

`kmalloc` 出一个 `proc_struct` 后，把所有字段置成确定的初值：

| 字段 | 初值 | 含义 |
| --- | --- | --- |
| `state` | `PROC_UNINIT` | 刚创建，尚未运行 |
| `pid` | `-1` | 身份未分配 |
| `kstack` | `0` | 内核栈待分配 |
| `need_resched` | `0` | 不需要调度 |
| `parent` / `mm` | `NULL` | 无父进程、暂无用户地址空间 |
| `context` | 全 0 | 尚无执行现场 |
| `tf` | `NULL` | 尚无中断帧 |
| `pgdir` | `boot_pgdir_pa` | 内核线程共享内核页表（物理地址） |
| `name` | 全 0 | 名字待设置 |

"安全空白"很重要：后续 `proc_init`、`do_fork` 会按需填写字段，未填写字段必须是确定值，否则 `assert(current->mm == NULL)`、`context.ra != 0` 这类检查会随机失败。

### 4.2 `proc_init`：造出第 0 和第 1 个内核线程

```c
list_init(&proc_list);
for (i = 0; i < HASH_LIST_SIZE; i++) list_init(hash_list + i);   // 全局结构

idleproc = alloc_proc();
idleproc->pid = 0;
idleproc->state = PROC_RUNNABLE;
idleproc->kstack = (uintptr_t)bootstack;    // 复用启动栈，不是新分配的
idleproc->need_resched = 1;                 // 尽快交出 CPU
set_proc_name(idleproc, "idle");
nr_process++;
current = idleproc;

int pid = kernel_thread(init_main, "Hello world!!", 0);
initproc = find_proc(pid);
set_proc_name(initproc, "init");
```

`idleproc` 的特殊性在于：它不是 `fork` 出来的，而是**把 `kern_init` 一路执行到现在的执行现场直接接管**。因此它的内核栈就是 `bootstack`，`tf` 为 `NULL`，`context` 也没必要保存（它还没被切换出去过）。`need_resched = 1` 让 `cpu_idle` 的第一轮循环就调用 `schedule()`。

`initproc` 则是真正通过 `kernel_thread → do_fork → copy_thread` 创建的：有自己独立的内核栈、有完整的 `trapframe` 和 `context`。

### 4.3 `kernel_thread`：把普通函数包装成线程

```c
struct trapframe tf;
memset(&tf, 0, sizeof(tf));
tf.gpr.s0 = (uintptr_t)fn;      // 要执行的函数
tf.gpr.s1 = (uintptr_t)arg;     // 函数的参数
tf.status = read_csr(sstatus);
tf.status &= ~SSTATUS_SIE;      // sret 之后先关中断
tf.status |=  SSTATUS_SPP;      // sret 之后仍在内核态
tf.status |=  SSTATUS_SPIE;     // sret 之后重新开中断
tf.epc = (uintptr_t)kernel_thread_entry;
return do_fork(clone_flags, 0, &tf);
```

为什么要手工构造一个"空的"中断帧？因为操作系统启动初期没有父进程可以复制，而首次运行又必须依赖 `sret` 这条路径来恢复特权级、`sstatus` 和 `pc`。所以这里造一个"模板"：`epc` 指向入口，`s0/s1` 传递函数和参数，`status` 精心设置好 SPP/SPIE/SIE 三位。

### 4.4 `copy_thread` 与首次运行链路

```c
proc->tf = (struct trapframe *)(proc->kstack + KSTACKSIZE - sizeof(struct trapframe));
*(proc->tf) = *tf;
proc->tf->gpr.a0 = 0;                                    // 子线程返回值为 0
proc->tf->gpr.sp = (esp == 0) ? (uintptr_t)proc->tf : esp;
proc->context.ra = (uintptr_t)forkret;                   // 首次执行 forkret
proc->context.sp = (uintptr_t)(proc->tf);                // 栈顶就是 trapframe
```

链路是：

```
switch_to（恢复 ra=forkret, sp=tf）→ ret → forkret → forkrets(tf)
   → move sp, a0；j __trapret → RESTORE_ALL → sret
   → epc = kernel_thread_entry → 把 s1 放进 a0，跳 s0(fn)
   → init_main(arg) → 返回后 jal do_exit
```

`copy_thread` 做的其实就是"把父进程的中断帧复制到子线程自己的内核栈顶"，这样每个线程都有独立的 `tf`，`__trapret` 恢复的是各自的那一份。

### 4.5 `do_fork`：资源组合与失败回滚

```c
if (nr_process >= MAX_PROCESS) goto fork_out;
ret = -E_NO_MEM;
if ((proc = alloc_proc()) == NULL) goto fork_out;
proc->parent = current;
if (setup_kstack(proc) != 0)     goto bad_fork_cleanup_proc;
if (copy_mm(clone_flags, proc) != 0) goto bad_fork_cleanup_kstack;
copy_thread(proc, stack, tf);

local_intr_save(intr_flag);
    proc->pid = get_pid();
    hash_proc(proc);
    list_add(&proc_list, &(proc->list_link));   // 挂到链表头
    nr_process++;
local_intr_restore(intr_flag);

wakeup_proc(proc);      // PROC_UNINIT -> PROC_RUNNABLE，等待调度
ret = proc->pid;
```

要点：

- **失败回滚顺序与申请顺序相反**（栈后进先出）：`kfree(proc)`、`put_kstack(proc)`。
- **PID 分配、哈希挂接、链表插入必须在同一个临界区里**，否则两个线程同时 fork 可能拿到相同 pid，或链表被并发修改。
- **先挂链表、再 wakeup**：调度器只遍历 `proc_list`，如果先 wakeup 再挂链表，可能出现"就绪但找不到"的窗口。
- 本阶段 `copy_mm` 只是接口占位（`current->mm` 为 `NULL`，内核线程共享内核地址空间），但保持函数形态完整，方便实验五继续扩展。

---

## 五、功能模块三：进程调度

### 5.1 `schedule`：FIFO 轮转

```c
current->need_resched = 0;
last = (current == idleproc) ? &proc_list : &(current->list_link);
le = last;
do {
    if ((le = list_next(le)) != &proc_list) {
        next = le2proc(le, list_link);
        if (next->state == PROC_RUNNABLE) break;
    }
} while (le != last);
if (next == NULL || next->state != PROC_RUNNABLE) next = idleproc;   // 保底
next->runs++;
if (next != current) proc_run(next);
```

三种情况正对应实验指导书里的说明：当前不是 `idleproc` 时从下一个位置开始找（轮转）；当前是 `idleproc` 时从链表头开始找（所有人机会均等）；找不到就回退 `idleproc`（空转保底）。整个查找 + 切换在关中断的临界区内完成。

### 5.2 `proc_run`：换页表、换现场

```c
local_intr_save(intr_flag);
    current = proc;                                   // 1. 更新当前线程
    write_csr(satp, 0x8000000000000000L | (next->pgdir >> RISCV_PGSHIFT));  // 2. 切页表
    flush_tlb();
    switch_to(&(prev->context), &(next->context));    // 3. 换寄存器现场
local_intr_restore(intr_flag);
```

`satp = (8 << 60) | (PPN)`，其中 8 是 Sv39 模式。本实验所有内核线程共享同一张内核页表，所以 satp 实际上没变，但代码形态要和后续"每个用户进程一张页表"一致。

### 5.3 `switch_to`：只做保存/恢复

```asm
switch_to:
    STORE ra,  0*REGBYTES(a0)     # 保存 from 的 ra/sp/s0~s11
    STORE sp,  1*REGBYTES(a0)
    ...
    LOAD  ra,  0*REGBYTES(a1)     # 恢复 to 的 ra/sp/s0~s11
    LOAD  sp,  1*REGBYTES(a1)
    ...
    ret
```

只保存"被调用者保存寄存器"（callee-saved），共 14 个，与 `struct context` 的 14 个字段一一对应；`t0~t6`、`a0~a7` 等调用者保存寄存器由编译器在调用点负责。`switch_to` 不做任何调度决策，`ret` 之后要么回到原线程的 `proc_run` 里继续，要么进入新线程的 `forkret`。

### 5.4 `cpu_idle` 与"谁来唤醒 idleproc"

```c
void cpu_idle(void) {
    while (1) {
        if (current->need_resched) schedule();
    }
}
```

调度点只在 `cpu_idle` 里，这是实验四的设计。但这里有一个容易被忽略的问题：当调度器把 CPU 从 `initproc` 切回 `idleproc` 时，`idleproc->need_resched` 早在它第一次调度时就被清 0 了，于是 `cpu_idle` 会一直空转、再也不调度，另外两个线程永远得不到 CPU（自测的 `test_lab4_schedule` 就会卡死）。

解决办法是在**时钟中断处理里给当前线程置 `need_resched = 1`**：

```c
case IRQ_S_TIMER:
    clock_set_next_event();
    if (current != NULL) current->need_resched = 1;   // 时间片到期，标记需要重调度
    if (++ticks % TICK_NUM == 0) print_ticks();
    break;
```

这样时间片到期后，`cpu_idle` 会重新进入调度器，轮转得以继续；这也让"抢占式"的时间片调度真正成立。

### 5.5 状态机与 `wakeup_proc`

`alloc_proc` → `PROC_UNINIT` →（`wakeup_proc`）→ `PROC_RUNNABLE` →（`do_exit`）→ `PROC_ZOMBIE`；`PROC_SLEEPING` 留给后续实验。`schedule` 只挑 `PROC_RUNNABLE`，所以"就绪"与"运行"在实验四里是同一个状态。

---

## 六、lab2/lab3 依赖部分的补齐

实验四的骨架代码里，lab2/lab3 的位置是空的，不补齐根本编译不过、也跑不起来。本次补齐内容如下（这些不属于实验四的评分点，但是实验四的运行前提）：

1. **`kern/mm/default_pmm.c`（lab2）**：实现 best-fit 物理内存管理器。`free_list` 按物理地址有序串起空闲块，块首 `Page.property` 记录块大小；分配时挑"能满足且最小"的块并从块尾切分；释放时按地址插回并与前后相邻块合并。`default_init/init_memmap/alloc_pages/free_pages/nr_free_pages/check` 组装成 `default_pmm_manager`。
2. **`kern/mm/pmm.c: page_init`（lab2）**：从 DTB 取物理内存范围，设置 `va_pa_offset = PHYSICAL_MEMORY_OFFSET`、`npage = (mem_base + mem_size)/PGSIZE`；把 `struct Page` 数组放在内核映像 `end` 之后，先把整个内存标记 `reserved`，再把 `[数组末尾, 内存末尾)` 交给 `init_memmap`。
3. **`kern/trap/trapentry.S`（lab3）**：补全 `RESTORE_ALL`（先恢复 `sstatus`/`sepc`，再恢复 31 个通用寄存器，最后 `addi sp, sp, 36*REGBYTES` 弹栈）和 `__alltraps` 里的 `move a0, sp; jal trap`。
4. **`kern/trap/trap.c`（lab3）**：实现 `interrupt_handler`（S 态时钟中断 → 重置下一次事件、置 `need_resched`、每 100 tick 打印）和 `exception_handler`（各类异常打印 trapframe 后 panic；缺页异常留给后续实验）。
5. **`kern/mm/kmalloc.c`**：补齐 `slob_lock` / `block_lock` 两个占位锁，并修正 `kva2page(kva)` 的指针类型（原代码把 `unsigned long` 直接传给 `void *` 形参，在 GCC 14 下是 `-Wint-conversion` 错误）。

---

## 七、每个练习的 spec 与 prompt 是怎么写的

### 7.1 spec 的写法

我们把"提示词工程"分成两步：先写 **spec**（把实验指导书里的自然语言变成可验证的契约），再写 **prompt**（把 spec 和上下文喂给 AI）。spec 固定包含六项：

1. **签名与文件位置**：函数原型、所在文件、是否 static；
2. **输入/输出/错误码**：参数含义、返回值、失败时返回什么；
3. **前置条件**：调用者保证什么（例如"调用前中断已关闭"、"current 不为 NULL"）；
4. **后置条件**：成功返回后哪些不变量必须成立（例如"表项有效 ⇔ ref 已计入"）；
5. **边界与异常**：空指针、重复调用、资源不足、并发/中断打断；
6. **验收标准**：用哪段测试、期望什么现象（`check_pgdir()`、`[Test PMM] PASS` 等）。

以功能模块一为例，spec 的要点写成：

> `page_insert(pgdir, page, la, perm)`：在 `pgdir` 中建立 `la → page` 的映射，权限为 `perm`。
> - 必须处理"该地址已有映射"的两种情况：同一物理页（只更新权限，引用计数不变）、不同物理页（先 `page_remove` 再写新表项）；
> - `get_pte(create=1)` 失败返回 `-E_NO_MEM`，且不得改变页表状态；
> - 成功返回 0 后：`get_pte(pgdir, la, 0)` 得到的表项有效、`pte2page(*ptep)==page`、`page_ref(page)` 比调用前多 1（同一页覆写除外）；
> - 任何表项修改后必须 `tlb_invalidate(pgdir, la)`。

### 7.2 prompt 的写法

prompt 采用"角色 + 上下文 + spec + 约束 + 输出格式 + 自检"的结构。三条主线各写一条，示意如下（实际使用时会把实验指导书原文、相关头文件和已有函数一起贴进去）：

**模块一 prompt（节选）**

> 你是 ucore OS 内核开发者。当前文件 `kern/mm/pmm.c` 已提供 `get_pte`、`pte_create`、`page_ref_inc/dec`、`free_page`、`tlb_invalidate` 等接口，`struct Page` 有 `ref` 引用计数。请实现 `page_insert` 与 `page_remove`，要求：
> 1. 严格保证"页表项 / 引用计数 / TLB"同步；
> 2. 处理同一页重复映射、不同页覆盖映射、目标地址无映射三种情况；
> 3. `get_pte` 分配中间级页表失败时返回 `-E_NO_MEM` 且不留脏状态；
> 4. 不要改动 `get_pte` 和测试函数；
> 5. 每行关键逻辑加中文注释，说明"为什么"而不是"做什么"。
> 输出：完整的两个函数 + 一段不超过 10 行的设计说明。

**模块二 prompt（节选）**

> 请为 ucore 实现内核线程创建：`alloc_proc`、`proc_init`、`kernel_thread`、`copy_thread`、`copy_mm`、`do_fork`。
> 背景：`struct proc_struct` 含 state/pid/runs/kstack/need_resched/parent/mm/context/tf/pgdir/flags/name/list_link/hash_link；`context` 含 ra/sp/s0~s11；`trapframe` 含 32 个通用寄存器 + status/epc/badvaddr/cause。
> 约束：
> - `idleproc` 复用当前执行现场（`kstack = bootstack`、`pid = 0`、`need_resched = 1`）；
> - `kernel_thread` 必须手工构造空 trapframe，`epc = kernel_thread_entry`，`s0 = fn`，`s1 = arg`，`status` 需按 SPP/SPIE/SIE 三位设置；
> - `copy_thread` 要把 trapframe 放在新内核栈顶，`context.ra = forkret`，`context.sp = tf`；
> - `do_fork` 失败时必须按申请的逆序释放资源；
> - PID 分配 + 哈希挂接 + 链表插入必须放在同一个关中断临界区。
> 输出：按依赖顺序给出完整函数，并在结尾用 5 行说明"首次运行链路"。

**模块三 prompt（节选）**

> 请实现 FIFO 轮转调度：`schedule`（`kern/schedule/sched.c`）、`proc_run`（`kern/process/proc.c`）、`cpu_idle` 和 `switch_to`（`kern/process/switch.S`）。
> 约束：
> - `schedule` 从 `current` 的下一个位置开始找 `PROC_RUNNABLE`，当前是 `idleproc` 时从表头开始，找不到用 `idleproc` 保底；
> - 查找与切换必须在关中断临界区内；
> - `proc_run` 依次更新 `current`、写 `satp`（`(8<<60) | (pgdir>>12)`）、`sfence.vma`、`switch_to`；
> - `switch_to` 只保存/恢复 ra、sp、s0~s11，共 14 个寄存器，偏移与 `struct context` 一致；
> - 注意 `libs/riscv.h` 里的 `lsatp()` 是 Sv32 遗留，不能用于 Sv39。
> 输出：C 代码 + 汇编 + 一段调度流程图说明。

---

## 八、AI 生成代码过程中出现的 bug 与解决

| # | 现象 | 原因 | 解决 |
| --- | --- | --- | --- |
| 1 | `fatal error: best_fit_pmm.h: No such file` | 骨架 `default_pmm.c` 里残留了 lab2 另一版本的 include，且 `free_list/nr_free`、`pmm_manager` 全部缺失 | 删除错误 include，在文件内实现 `free_area_t free_area` + 宏 `free_list/nr_free`，文件末尾组装 `default_pmm_manager` |
| 2 | `undefined reference to 'page_init'` | lab2 的 `page_init()` 是空位 | 依据 DTB 内存信息实现 `page_init`（`npage`、`pages` 数组位置、reserved 标记、空闲区间） |
| 3 | `kmalloc.c: passing argument 1 of 'kva2page' makes pointer from integer` | `__slob_free_pages(unsigned long kva, ...)` 把整数直接传给 `void *` 形参，GCC 14 视为错误 | 改为 `kva2page((void *)kva)`；同时补上缺失的 `slob_lock`/`block_lock` 占位变量 |
| 4 | `undefined reference to 'interrupt_handler' / 'exception_handler'` | lab3 的 trap 分发函数是空的 | 实现 `interrupt_handler`（时钟中断）与 `exception_handler`（异常 panic），并补全 `RESTORE_ALL`、`__alltraps` |
| 5 | `undefined reference to 'kernel_thread'` | 第一版只写了 `alloc_proc/proc_init/copy_mm/copy_thread/do_fork`，漏了 `kernel_thread` 本体 | 补上 `kernel_thread`，并保证 `proc_init` 的调用在 `kernel_thread` 定义之前（原型在 `proc.h`） |
| 6 | `test_lab4.c: passing argument 1 of 'kernel_thread' from incompatible pointer type` | 测试注入的线程函数是 `void (*)(void *)`，而骨架原型是 `int (*)(void *)`，GCC 14 把该诊断升级为错误 | 把 `proc.h/proc.c` 的形参统一为 `void (*fn)(void *)`，`init_main` 改为 `void`，`kernel_thread_entry` 本来就不使用返回值 |
| 7 | 调度测试卡死：`[Test Schedule]` 之后的断言不返回 | 切回 `idleproc` 时它的 `need_resched` 已被清零，`cpu_idle` 再也不调 `schedule` | 在时钟中断里给 `current->need_resched` 置 1，让时间片到期后能重新进入调度器 |
| 8 | `make grade` 三项全 `no $qemu_out` | WSL 里没有 `riscv64-unknown-elf-gdb`；用 `gdb-multiarch` 直接连 QEMU 会报 `Truncated register 37 in remote 'g' packet`（没有指定 RISC-V 架构），gdb 立刻退出并把 QEMU 杀掉 | 新增 `tools/gdb-riscv.sh`（`gdb-multiarch -ex 'set architecture riscv:rv64'`），Makefile 在找不到 `$(GCCPREFIX)gdb` 时自动回退到它 |
| 9 | `check_alloc_page() succeeded!` 打印两次 | `default_check()` 里重复打印 | 删掉管理器里的重复打印，保留 `pmm.c` 中的那一句 |

第 7 条是最有代表性的"AI 生成代码能编译但跑不起来"的 bug：从代码上看 `cpu_idle` 完全符合"检测到 need_resched 才调度"的描述，但忽略了"谁会把 `need_resched` 重新置 1"。这类问题只能靠跑测试、看现象来发现，也说明**spec 里必须写清楚"调度点由谁触发"**。

---

## 九、本实验知识点与 OS 原理知识点的对照

| 本实验的知识点 | OS 原理中的对应概念 | 含义、关系与差异 |
| --- | --- | --- |
| `struct Page` + `pages` 数组 + `ref`/`flags`/`property` | 页框描述符 / 页帧数据库（frame table, `mem_map`） | 都是"用数据结构描述每个物理页框"。本实验用一个大数组，`ref` 计引用、`property` 兼作空闲块大小；原理中还会区分 zone/NUMA、page flags、mapping、LRU 链等，并且普遍用 `struct page` 的联合体节省空间 |
| best-fit + 有序空闲链表 + 相邻块合并 | 连续内存分配：first-fit / best-fit / worst-fit / 伙伴系统 | 目标相同（找一块足够大的连续页框），策略不同。best-fit 碎片小但查找 O(n)、易产生小碎片；伙伴系统用 2 的幂 + 位图，合并/分裂 O(log n)，是真实内核的主流选择。本实验的"相邻合并"正是伙伴系统合并的简化版 |
| `get_pte` 三级页表遍历（Sv39） | 多级页表（x86 四级、Sv48 五级） | 都是"用地址的位段逐级索引，缺页时补建中间级页表"。本实验固定三级、每级 512 项、页表页 4KB；原理中还要考虑页表本身的分页、大页（superpage）、页表项缓存（TLB）、反向页表/哈希页表 |
| `page_insert` / `page_remove` 维护引用计数 | 页表项管理与物理页生命周期（`get_page`/`put_page`） | 语义一致：映射建立/撤销必须同步调整引用计数。差异在于本实验单核、共享内核地址空间，`tlb_invalidate` 只需本地 `sfence.vma`；原理中多核还要 TLB shootdown（IPI），并处理 COW、swap entry 等特殊 PTE |
| **预映射**（一次性建好所有映射） | 按需分页 / 缺页异常处理 / 惰性分配 | 本实验明确不涉及按需分配和页面置换，`do_pgfault` 不需要实现。原理中虚拟内存的真正价值恰恰在"用时才分配"：缺页 → 调页 → 置换，`mm_struct`/VMA 记录"合法但未映射"的区域 |
| `proc_struct`（PCB）+ 内核栈 + `trapframe` + `context` | 进程控制块、内核栈、上下文（context switch） | 一一对应。本实验的 PCB 极度简化：无文件表、无信号、无凭证、无调度实体；`context` 只保存 callee-saved 寄存器，`trapframe` 保存完整现场 |
| `kernel_thread` + 空 trapframe 模板 + `forkret/forkrets/__trapret` | 进程创建（fork）+ 首次进入执行流 | 原理上 fork 复制父进程的地址空间和上下文；本实验没有父进程可复制，所以"手工构造模板"，这是 ucore 对"第一个进程从哪来"的经典回答 |
| FIFO/RR + `need_resched` + 时钟中断抢占 | 调度策略与调度时机（抢占式 vs 协作式） | 本实验只有单一调度类、无优先级、无时间片队列；原理中有 MLFQ、CFS、实时调度，以及优先级反转、饥饿、公平性等问题 |
| 内核线程统一按"进程"管理 | Linux `task_struct` 统一 task/thread | 与 ucore 文档一致：线程 = 共享地址空间的进程。差异体现在 `clone_flags`（`CLONE_VM`/`CLONE_THREAD`），本实验的 `copy_mm` 只是占位 |
| `idleproc` / `cpu_idle` | idle 任务（swapper / idle thread） | 都是"没有就绪任务时占用 CPU"的保底线程。原理中 idle 还承担进入低功耗、触发负载均衡、回收僵尸进程等职责；本实验只做空转 + 轮询 `need_resched` |

---

## 十、OS 原理中很重要、但本实验没有对应上的知识点

1. **缺页异常与页面置换**：FIFO/LRU/Clock 算法、工作集模型、Belady 异常、抖动（thrashing）、写回与脏页。本实验是预映射，`do_pgfault` 未实现。
2. **用户进程与系统调用**：U/S 态切换、`ecall` 分派、参数校验、`copy_from_user`、`sys_fork/exec/wait/exit` 的完整语义。
3. **进程生命周期管理**：`do_exit` 的资源回收、`do_wait`、僵尸进程与父进程回收、孤儿进程过继。本实验 `do_exit` 仍是 `panic`。
4. **同步与互斥**：信号量、管程、条件变量、自旋锁、`lr/sc` 与原子指令、死锁（预防/避免/检测，银行家算法）。本实验只用"关中断"实现临界区。
5. **多核与内存一致性**：每 CPU 变量、自旋锁、TLB shootdown、`fence`/内存序、IPI。本实验是单核。
6. **文件系统**：VFS、inode、目录项、页缓存、日志、磁盘调度。本实验完全没有 IO。
7. **调度算法进阶**：MLFQ、CFS（红黑树 + vruntime）、实时调度（EDF/RM）、优先级反转与优先级继承。
8. **虚拟内存高级机制**：`mmap`/`munmap`、写时复制（COW）、共享内存、`mprotect`、swap、大页、内存映射文件。
9. **安全与保护**：页表 U 位与 SUM/SMEP、栈金丝雀、ASLR、用户态指针校验、权限最小化。
10. **进程间通信**：管道、共享内存、消息队列、信号。

---

## 十一、运行与测试结果

### 11.1 编译

```bash
$ make
...
+ cc kern/mm/pmm.c
+ cc kern/process/proc.c
+ cc kern/process/switch.S
+ cc kern/schedule/sched.c
+ ld bin/kernel
```

无 warning、无 error。

### 11.2 运行（`make qemu`）

```
(THU.CST) os is loading ...
Special kernel symbols:
  entry  0xc020004a (virtual)
  etext  0xc0203d44 (virtual)
  edata  0xc0209030 (virtual)
  end    0xc020d4e8 (virtual)
Kernel executable memory footprint: 54KB
memory management: best_fit_pmm_manager
npage: 88000, pages array: [0xffffffffc020e000, 0xffffffffc040e000), free memory: [0x8040e000, 0x88000000)
check_alloc_page() succeeded!
check_pgdir() succeeded!
check_boot_pgdir() succeeded!
use SLOB allocator
kmalloc_init() succeeded!
check_vma_struct() succeeded.
check_vmm() succeeded.
++ setup timer interrupts
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
kernel panic at kern/process/proc.c:210:
    process exit!!.
```

可以看到：两个内核线程 `idleproc`（pid 0）与 `initproc`（pid 1）都创建成功，`initproc` 被真正切换执行并打印了三条信息；最后的 `process exit!!` 是实验四骨架里 `do_exit` 留的 `panic`（进程退出属于后续实验），符合预期。

### 11.3 评分脚本（`make grade`）

`tools/grade.sh` 会：把代码树复制到临时目录 → `tools/inject.py` 注入 `kern/test/test_lab4.c` → 编译 → 用 QEMU + gdb 运行 → 用正则检查输出。

```
  -check PMM:                                OK
  -check Process Create:                     OK
  -check Schedule:                           OK
Total Score: 30/30
```

注入后的完整输出（节选）：

```
[Test PMM] PASS
check_vma_struct() succeeded.
check_vmm() succeeded.
[Test Process Create] PASS
++ setup timer interrupts
[Test Schedule] PASS
this initproc, pid = 1, name = "init"
To U: "Hello world!!".
To U: "en.., Bye, Bye. :)"
```

三项测试分别验证了：

- `[Test PMM]`：`page_insert/page_remove` 的引用计数与 TLB 语义；
- `[Test Process Create]`：`idleproc`（pid 0、`kstack == bootstack`、`tf == NULL`、`context.ra == 0`、`parent == NULL`、`mm == NULL`）与 `initproc`（pid 1、`parent == idleproc`、`context.ra/sp != 0`）的字段与状态；
- `[Test Schedule]`：动态创建两个内核线程，8 次 `schedule()` 后两个线程都能得到执行，说明 FIFO 轮转与上下文切换正确。

### 11.4 环境适配说明

本机 WSL 只有 `gdb-multiarch`，没有 `riscv64-unknown-elf-gdb`，而 `grade.sh` 依赖 `$(make_print GDB)` 做 "运行到断点" 的控制。为此：

- 新增 `tools/gdb-riscv.sh`：先 `set architecture riscv:rv64` 再执行传入参数（否则 QEMU 的 gdbstub 描述会被 gdb 拒绝）；
- `Makefile` 在 `command -v $(GCCPREFIX)gdb` 为空时自动把 `GDB` 设为 `sh tools/gdb-riscv.sh`，在装有交叉 gdb 的环境里行为不变。

---

## 十二、扩展练习 Challenge

### 12.1 `local_intr_save(intr_flag); ... local_intr_restore(intr_flag);` 是如何实现开关中断的？

```c
static inline bool __intr_save(void) {
    if (read_csr(sstatus) & SSTATUS_SIE) {   // 原来开着吗？
        intr_disable();                      // 开着 → 关掉
        return 1;                            // 记住"原来是开着的"
    }
    return 0;                                // 原来就关着 → 什么都不做
}
static inline void __intr_restore(bool flag) {
    if (flag) intr_enable();                 // 只有原来是开着的才恢复
}
```

关键点有三：

1. **保存的是"之前的状态"而不是"关中断"这个动作**。`intr_flag` 为 1 表示进入临界区前中断是开的；为 0 表示之前就已经在关中断的上下文里。
2. **因此可以嵌套**。内核里 `schedule` 会调用 `proc_run`，两者都用了这一对宏：外层把 `intr_flag` 存成 1 并关中断，内层读到 SIE=0 于是存成 0；内层 restore 时 `flag==0` 不会开中断，只有外层 restore 才真正开中断。这保证了"临界区只由最外层负责重新开中断"，不会出现提前开中断导致原子性被破坏。
3. **底层是 CSR 的原子读改写**：`intr_disable()` → `clear_csr(sstatus, SSTATUS_SIE)`（`csrrc`），`intr_enable()` → `set_csr(sstatus, SSTATUS_SIE)`（`csrrs`）。单条 CSR 指令不会被中断打断，所以"读-判断-清"之间不存在窗口期。

在 `schedule`/`proc_run` 里，这个机制保证"更新 current、写 satp、保存/恢复寄存器"这三件事对外部中断而言是原子的，不会出现"current 已经是新线程、但 satp 还是旧页表"这种不一致状态。

### 12.2 深入理解不同分页模式：`get_pte()` 里两段相似的代码

`get_pte()` 对 `pdep1`（PDX1 层）和 `pdep0`（PDX0 层）写了两段几乎一样的代码：

```c
pde_t *pdep1 = &pgdir[PDX1(la)];
if (!(*pdep1 & PTE_V)) { page = alloc_page(); ... *pdep1 = pte_create(page2ppn(page), PTE_U|PTE_V); }
pde_t *pdep0 = &((pte_t *)KADDR(PDE_ADDR(*pdep1)))[PDX0(la)];
if (!(*pdep0 & PTE_V)) { ... 同样的分配 + 清零 + 写表项 ... }
return &((pte_t *)KADDR(PDE_ADDR(*pdep0)))[PTX(la)];
```

**为什么这么像？** 因为三级页表的每一级做的都是同一件事：

1. 用"当前级索引"去索引"当前级页表"，得到一个 PTE；
2. 若 `PTE_V == 0`，分配一个 4KB 页作下一级页表、清零、填入 `PPN | PTE_V`（并按需带 `PTE_U`）；
3. 用 `PTE_ADDR` 从表项里取出下一级页表的物理地址，`KADDR` 转成内核虚拟地址，进入下一级。

**sv32 / sv39 / sv48 的异同：**

| 模式 | 级数 | 每级索引位数 | 页内偏移 | PTE 大小 | 单张页表覆盖 |
| --- | --- | --- | --- | --- | --- |
| Sv32 | 2（PDX1、PDX0） | 10 + 10 | 12 | 4 B | 一级 4MB |
| Sv39 | 3（PDX1、PDX0、PTX） | 9 + 9 + 9 | 12 | 8 B | 一级 2MB |
| Sv48 | 4（PDX2、PDX1、PDX0、PTX） | 9 × 4 | 12 | 8 B | 一级 512GB |

相同的部分：**每级页表都是 512 项（Sv32 是 1024 项）、页内偏移都是 12 位、PPN 都从第 10 位开始**，所以 `PDE_ADDR`（`(pte & ~0x3FF) << (PTXSHIFT - PTE_PPN_SHIFT)`）、`PTX(la)`、`PDX0(la)` 这些宏在三种模式下写法完全一样，代码自然长得一模一样。

不同的部分：**级数**和**各级索引的位移**。Sv39 比 Sv32 多一级，Sv48 比 Sv39 再多一级（PDX2SHIFT = 39）。所以如果把 sv39 换成 sv48，`get_pte` 只需要在最前面再加一段 `pdep2`，或者在它外面套一层 `for (level = 2; level >= 0; level--)` 的循环，用 `(la >> (12 + 9*level)) & 0x1FF` 统一取索引——这正是把"每级重复逻辑"抽象成循环的动机。

### 12.3 把页表查找和页表页分配合并在一个函数里，好不好？

**现在的写法（`get_pte(pgdir, la, create)`）的优点：**

- 调用者一行代码就能拿到叶子 PTE，不用关心有几级、哪一级缺页表；
- `create` 参数用 0/1 区分"只查"和"查不到就建"，`page_insert` 与 `get_page` 都能复用；
- 分配页表页的时机与"发现哪一级缺失"天然耦合，写在一起最直观。

**缺点：**

- 一个函数承担"查询"和"分配"两件事，违反单一职责；
- 错误路径混在正常路径里：分配失败必须返回 `NULL`，且要求"已经建好的上级页表不能回滚"（本实现接受这个泄漏，因为上级页表本来就要长期存在），语义不够干净；
- 有副作用导致不好测试：想测"只查"路径必须传 `create=0`，想测分配失败要注入分配失败；
- 复用性差：缺页处理想"先查、失败再决定是否分配"、`munmap` 想遍历释放页表页、`fork` 想批量复制页表，都需要绕过这个"顺手分配"的语义。

**是否要拆？** 我认为应该拆，但保留对外的便捷接口，形如：

```c
pte_t *walk_pgdir(pde_t *pgdir, uintptr_t la, int *level);   // 只走表，返回叶子 PTE 或缺失层级
int  alloc_pgdir_page(pde_t *pgdir, uintptr_t la, int level); // 只负责补齐某一级
pte_t *get_pte(pde_t *pgdir, uintptr_t la, bool create) {     // 便捷组合
    pte_t *ptep = walk_pgdir(pgdir, la, &level);
    if (!ptep && create) { if (alloc_pgdir_page(...) < 0) return NULL; ptep = walk_pgdir(...); }
    return ptep;
}
```

这样查询路径没有副作用、分配失败可以精确回滚、两条路径各自可测，上层接口保持不变。Linux 的 `pud_alloc/pmd_alloc/pte_alloc` 与 `walk_page_range` 的分层正是这个思路。不过在实验四这个规模下，`get_pte` 已经足够清晰，拆分的主要收益是为后续实验（缺页、swap、`munmap`）留好扩展点。

---

## 十三、小组分工

| 学号 | 分工 |
| --- | --- |
| 2411438 | 虚拟内存页操作（`page_insert`/`page_remove`）、lab2 物理内存管理器与 `page_init`、整体联调与评分脚本排错 |
| 2411513 | 进程创建与初始化（`alloc_proc`/`proc_init`/`kernel_thread`/`do_fork`/`copy_thread`/`copy_mm`）、调度与上下文切换（`schedule`/`proc_run`/`switch_to`/`cpu_idle`）、lab3 trap 入口补齐 |

报告撰写与测试由两人共同完成。

---

## 附录：本次修改/新增的文件清单

```
Makefile                     GDB 自动回退（无交叉 gdb 时用 gdb-multiarch 包装脚本）
tools/gdb-riscv.sh           新增：gdb-multiarch + set architecture riscv:rv64 包装
kern/mm/default_pmm.c        lab2：best-fit 物理内存管理器
kern/mm/pmm.c                lab2：page_init；lab4-1：page_insert/page_remove
kern/mm/kmalloc.c            补齐锁占位变量、修正 kva2page 参数类型
kern/trap/trap.c             lab3：interrupt_handler/exception_handler（含 need_resched 置位）
kern/trap/trapentry.S        lab3：RESTORE_ALL、__alltraps 调用 trap
kern/process/proc.h          kernel_thread 形参类型与测试保持一致
kern/process/proc.c          lab4-2：alloc_proc/proc_init/kernel_thread/copy_mm/copy_thread/do_fork
                             lab4-3：cpu_idle/proc_run
kern/process/switch.S        lab4-3：switch_to
kern/schedule/sched.c        lab4-3：schedule
```
