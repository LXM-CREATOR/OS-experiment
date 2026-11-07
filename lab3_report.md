# 实验 3：中断处理机制 实验报告
## 实验基本信息

| 项目 | 内容 |
|------|------|
| **实验名称** | Lab3: 中断处理机制 |
| **小组成员** | <2411438>-李熙铭、<2411513>-杨珺童、<2413101>-谢沛霖 |
| **完成日期** | 2026-11-3 |

### 小组分工

练习如何分工？

| 成员 | 负责的练习/模块 |
|------|----------------|
| 李熙铭 | Trap 上下文与入口 |
| 杨珺童 | 中断与异常处理 |
| 谢沛霖 | 工程依赖、验证与整合 |

实验报告如何分工？

实验报告分为三个分节文档，由三位成员分别撰写对应模块的内容，最后由组长李熙铭合并为总报告，并统一检查格式和截图路径。

---


> 实验环境：Windows 11 + WSL2（Ubuntu），`riscv64-unknown-elf-gcc 14.2.0`，GNU binutils 2.45，QEMU `qemu-system-riscv64`（`-machine virt`，OpenSBI v0.4），2026-11-07。
>
> 代码位置：`kern/trap/trapentry.S`、`kern/trap/trap.c`；为让本工作区的 lab2 依赖能够编译，另外补齐了 `kern/mm/pmm.c` 的 `page_init()` 和 `kern/mm/best_fit_pmm.c` 的 best-fit 管理器。
>
> 判分结果：`make grade` → `Total Score: 100/100`（35 + 25 + 40）。

---

## 1. 实验目的与完成情况

本实验围绕 RISC-V 64 位 S 模式的中断/异常处理机制展开，目标是把“能产生 Trap”推进到“能保存 Trap 上下文、进入 C 语言处理函数、完成中断与异常处理，并恢复上下文返回原执行流”的完整闭环。

完成的内容：

| 模块 | 文件 | 完成内容 |
| --- | --- | --- |
| Trap 上下文恢复 | `kern/trap/trapentry.S` | `RESTORE_ALL` 宏、`__alltraps` 中 `a0 = sp` 与 `jal trap` |
| Trap 入口/返回 | `kern/trap/trapentry.S` | `__trapret` 继续使用 `RESTORE_ALL` + `sret`，形成完整返回路径 |
| 中断处理 | `kern/trap/trap.c` | `interrupt_handler()`：时钟中断重装、计数、统计输出、软中断/外部中断分类、未知中断兜底 |
| 异常处理 | `kern/trap/trap.c` | `exception_handler()`：非法指令、断点异常输出并推进 `epc`，其他异常 `print_trapframe()` 兜底 |
| lab2 依赖修复 | `kern/mm/pmm.c`、`kern/mm/best_fit_pmm.c` | 补 `page_init()`、best-fit 空闲链表管理器，保证工程可编译、PMM 可初始化 |

---

## 2. 本章整体逻辑线

本章可以概括为三条主线，但它们不是三个孤立练习，而是一条从“硬件入口”到“C 处理函数”再回到“原执行流”的完整链路：

```text
Trap 上下文保存与恢复
        ↓
Trap 入口与返回（汇编 ↔ C 的调用约定）
        ↓
中断与异常处理（按 scause 分类处理）
        ↓
sret 返回原执行流
```

### 2.1 启动与初始化顺序

`kern/init/entry.S` 先建立 Sv39 的 boot page table、设置 `sp`，然后跳转到 `kern_init()`。`kern_init()` 的关键顺序是：

```c
memset(edata, 0, end - edata);
dtb_init();          // 从 DTB 读出物理内存 base/size
cons_init();
print_kerninfo();
idt_init();          // 第一次：stvec <- __alltraps，sscratch <- 0
pmm_init();          // 物理内存管理初始化（lab2 依赖）
idt_init();          // 第二次：pmm 之后重新确认 Trap 入口
clock_init();        // 使能 S 模式时钟中断，设置第一个时钟事件
intr_enable();       // sstatus.SIE = 1
while (1) ;
```

`idt_init()` 做两件事：

```c
write_csr(sscratch, 0);
write_csr(stvec, &__alltraps);
```

- `stvec` 是 S 模式的 Trap 入口地址。这里使用 Direct 模式，所以所有中断/异常都跳到 `__alltraps`。
- `sscratch` 先置 0，表示当前在核内执行；本实验没有真正的 U 模式，`sscratch` 主要用来在入口处暂存被打断的 `sp`。

### 2.2 一次时钟中断的完整执行流

```text
OpenSBI 定时器到期
  → 硬件把 scause/sepc/stval/sstatus 写好，跳转 stvec
  → __alltraps: SAVE_ALL 在当前内核栈上构造 trapframe
  → a0 = sp（trapframe 首地址）
  → jal trap
  → trap() → trap_dispatch()
  → scause 最高位为 1：interrupt_handler()
  → case IRQ_S_TIMER:
        clock_set_next_event();   // 重装下一次时钟事件
        ticks++;
        ticks % 100 == 0 → print_ticks()
  → 返回 __trapret
  → RESTORE_ALL: 恢复 sstatus/sepc 和 32 个通用寄存器
  → sret: 按 sstatus.SPP/SPIE 返回原执行流
```

### 2.3 一次断点/非法指令异常的完整执行流

```text
ebreak / 非法指令
  → 硬件写 scause=3/2、sepc=出错指令地址
  → __alltraps → SAVE_ALL → trap()
  → trap_dispatch(): scause 最高位为 0 → exception_handler()
  → 打印 "Breakpoint at ..." / "Illegal instruction at ..."
  → tf->epc += 指令长度（本实验为 4）
  → __trapret → RESTORE_ALL → sret
  → 从下一条指令继续执行，而不是重复执行出错指令
```

这条链路里，“保存/恢复”与“处理”之间的契约就是 **trapframe 的内存布局**：汇编按固定偏移写，C 按同一个 `struct trapframe` 读；任何一方偏移不一致，都会出现“寄存器看起来恢复了但值是错的”这种很难定位的问题。

---

## 3. 功能模块一：Trap 上下文恢复与 Trap 入口

### 3.1 trapframe 的布局

`kern/trap/trap.h` 中：

```c
struct pushregs {
    uintptr_t zero, ra, sp, gp, tp;
    uintptr_t t0, t1, t2;
    uintptr_t s0, s1;
    uintptr_t a0, a1, a2, a3, a4, a5, a6, a7;
    uintptr_t s2 ... s11;
    uintptr_t t3, t4, t5, t6;
};

struct trapframe {
    struct pushregs gpr;   // 32 个寄存器，偏移 0 .. 31*REGBYTES
    uintptr_t status;      // 32*REGBYTES
    uintptr_t epc;         // 33*REGBYTES
    uintptr_t badvaddr;    // 34*REGBYTES
    uintptr_t cause;       // 35*REGBYTES
};
```

因此在 RV64 下 `sizeof(struct trapframe) = 36 * 8 = 288` 字节。寄存器编号与数组下标一致：`x0` 在 0，`x1` 在 1，……，`x31` 在 31。

### 3.2 SAVE_ALL 的关键点

已提供的 `SAVE_ALL` 做了三件容易出错的事：

1. **先保存旧 `sp` 到 `sscratch`**：

   ```asm
   csrw sscratch, sp
   addi sp, sp, -36 * REGBYTES
   ```

   此时 `sp` 已经指向新 trapframe，但 `tf->gpr.sp` 应该保存“进入 Trap 之前”的栈指针，而不是新栈指针。

2. **用 `csrrw s0, sscratch, x0` 取回旧 `sp`，同时把 `sscratch` 清零**：

   ```asm
   csrrw s0, sscratch, x0
   ...
   STORE s0, 2*REGBYTES(sp)
   ```

   `s0` 在通用寄存器里对应 `x8`，但它在第 8 个槽位已经被 `STORE x8, 8*REGBYTES(sp)` 保存过了；这里只是把 `s0` 当临时寄存器用，最后把旧 `sp` 写到偏移 2 的位置。

3. **CSR 不能直接 store 到内存**，所以先 `csrr` 到 `s1..s4`，再 `STORE` 到 32..35 槽位：

   ```asm
   csrr s1, sstatus
   csrr s2, sepc
   csrr s3, stval
   csrr s4, scause
   STORE s1, 32*REGBYTES(sp)
   ...
   ```

> 工具链兼容性说明：骨架里原本写的是 `sbadaddr`，它是特权规范 1.10 之前的旧 CSR 名；当前 binutils 2.45 只接受新名字 `stval`。两者是同一个 CSR（0x143），所以这里改成 `stval`，语义不变。报告中把它列为“环境兼容性 bug”。

### 3.3 RESTORE_ALL 的实现

实现位于 `kern/trap/trapentry.S` 第 59 行起：

```asm
.macro RESTORE_ALL
    LOAD s1, 32*REGBYTES(sp)
    csrw sstatus, s1
    LOAD s2, 33*REGBYTES(sp)
    csrw sepc, s2

    LOAD x1, 1*REGBYTES(sp)
    LOAD x3, 3*REGBYTES(sp)
    ...                       # x4 .. x31
    LOAD x31, 31*REGBYTES(sp)
    LOAD x2, 2*REGBYTES(sp)   # sp 必须最后恢复
.endm
```

设计要点：

1. **先恢复 CSR，再恢复通用寄存器。** `sret` 使用 `sstatus.SPP` 选择返回特权级、使用 `sstatus.SPIE` 恢复中断使能、使用 `sepc` 作为返回地址。如果先恢复通用寄存器再恢复 CSR，虽然也能工作，但一旦中途发生异常，状态会不一致；先写 CSR 更符合“先把返回路径准备好，再恢复数据”的顺序。

2. **`x2`（`sp`）必须最后恢复。** 前面所有 `LOAD` 都以当前 `sp` 为基址；如果先执行 `LOAD x2, 2*REGBYTES(sp)`，`sp` 立刻变成旧栈指针，后续 `LOAD x3, 3*REGBYTES(sp)` 就会从错误地址取数据，轻则寄存器值错乱，重则触发 load page fault。

3. **`x0` 不需要恢复。** RISC-V 的 `x0` 硬连线为 0，`LOAD x0, ...` 也不会改变它；`SAVE_ALL` 保存 `x0` 只是为了让 trapframe 布局完整。这里直接跳过 `x0`，从 `x1` 开始恢复。

4. **`x4`（`tp`）和 `x3`（`gp`）也要恢复。** 它们不是“临时寄存器”，内核 C 代码可能依赖 `gp` 做全局访问、依赖 `tp` 做 per-hart 数据；上下文测试也专门检查了 `t0..t6`、`s0..s11`、`a1..a7`。

5. **不恢复 `sscratch`。** 进入 Trap 时 `SAVE_ALL` 已经把 `sscratch` 清零；本实验所有 Trap 都发生在 S 模式，返回后继续保持 0 即可。若将来支持 U 模式，则 `sscratch` 应保存内核栈顶，供下一次从 U 模式进入 Trap 时换栈。

6. **不恢复 `scause`/`stval`。** 它们是“本次 Trap 的原因/故障地址”，不是返回执行流所必需的 CPU 状态；`sret` 只依赖 `sstatus` 和 `sepc`。

### 3.4 `__alltraps`：汇编入口到 C 函数的桥

```asm
__alltraps:
    SAVE_ALL
    mv a0, sp
    jal trap
    # sp should be the same as before "jal trap"
__trapret:
    RESTORE_ALL
    sret
```

关键点：

- `SAVE_ALL` 之后，`sp` 正好指向 trapframe 的起始地址，所以 `mv a0, sp` 就是把 `struct trapframe *` 作为第一个参数传给 `trap()`。
- `jal trap` 会把返回地址写入 `ra`（`x1`）。`ra` 在 `SAVE_ALL` 中已经保存过，所以 `trap()` 返回后 `ra` 被破坏也没关系；`__trapret` 会从 trapframe 恢复它。
- `trap()` 遵循 RISC-V 调用约定，`sp` 是 callee-saved，返回后仍然等于进入 `jal` 之前的值。因此注释里的 “sp should be the same as before `jal trap`” 是成立的，不需要额外调整 `sp`。
- 没有在 `jal trap` 之后再加 `addi sp, sp, 36*REGBYTES`：因为 `RESTORE_ALL` 的最后一条 `LOAD x2, 2*REGBYTES(sp)` 会把 `sp` 恢复成旧值，trapframe 所占的栈空间自然被“弹出”。

### 3.5 本模块的接口与不变量

| 项目 | 约定 |
| --- | --- |
| 入口 | `stvec = &__alltraps`，Direct 模式，4 字节对齐 |
| 输入 | 硬件已写好 `sstatus/sepc/stval/scause`，`sp` 指向当前栈 |
| 输出 | 栈上形成 36 个 `uintptr_t` 的 trapframe；`a0` 指向它 |
| C 接口 | `void trap(struct trapframe *tf)` |
| 返回 | `RESTORE_ALL` 恢复 32 个 GPR + `sstatus` + `sepc`，`sret` 返回 |
| 禁止 | 修改 `SAVE_ALL` 的保存关系、修改 `struct trapframe`、修改 `trap()` 签名 |

---

## 4. 功能模块二：中断与异常处理

`trap()` 只做分发：

```c
static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
        interrupt_handler(tf);   // scause[63] == 1
    } else {
        exception_handler(tf);   // scause[63] == 0
    }
}
```

### 4.1 `interrupt_handler()`

实现位于 `kern/trap/trap.c` 第 106 行起。核心是先清掉 `scause` 的最高位（Interrupt 位），再按中断码分类：

```c
uintptr_t cause = tf->cause & ~((uintptr_t)1 << 63);

switch (cause) {
case IRQ_S_TIMER:
    clock_set_next_event();
    ticks++;
    if (ticks % TICK_NUM == 0)
        print_ticks();
    break;
case IRQ_S_SOFT:
    cprintf("Supervisor software interrupt\n");
    break;
case IRQ_S_EXT:
    cprintf("Supervisor external interrupt\n");
    break;
default:
    cprintf("Unknown interrupt: cause %d\n", (int)cause);
    break;
}
```

时钟中断部分有三个必须同时成立的动作：

1. **重装下一次时钟事件。** OpenSBI 的 `sbi_set_timer()` 一次只设置一个绝对时刻；如果只计数不重装，系统只会收到一次时钟中断，之后永远安静。`clock_set_next_event()` 内部是：

   ```c
   sbi_set_timer(get_cycles() + timebase);
   ```

   QEMU 的 `time` CSR 频率约 10 MHz，`timebase = 100000`，所以约 10 ms 一次，1 秒 100 次。

2. **计数 `ticks++`。** `ticks` 是 `volatile size_t`，中断处理函数和主循环（测试代码）都会读它，`volatile` 防止编译器把它缓存在寄存器里。

3. **每 `TICK_NUM` 次输出一次。** `TICK_NUM = 100`，即每秒输出一行 `100 ticks`。`print_ticks()` 是框架已提供的函数，`DEBUG_GRADE` 下还会输出 `End of Test.` 并 `panic`。

> 关于 `SHUTDOWN_AFTER`：课程指导书提到“累计输出达到 `SHUTDOWN_AFTER` 后调用关机接口”，但本工作区的 `trap.c`/`clock.h` 并没有定义这个宏，`tools/grade.sh` 的计时用例也要求内核持续输出到 `ticks >= 200`，再由 `timeout` 结束 QEMU。因此本实现按框架现状“持续输出”，没有自动关机。若你的框架提供了 `SHUTDOWN_AFTER`，可以在 `print_ticks()` 之后加：
>
> ```c
> #ifdef SHUTDOWN_AFTER
> if (ticks >= SHUTDOWN_AFTER) {
>     sbi_shutdown();
> }
> #endif
> ```
>
> 并在 `trap.c` 中包含 `<sbi.h>`。

关于 `scause` 最高位：

- 中断的 `scause` 形如 `0x8000000000000005`（最高位 1 + 中断码 5）。
- 如果直接 `switch (tf->cause)`，`case IRQ_S_TIMER`（值为 5）永远匹配不上，所有中断都会掉进 `default`。
- 因此必须先 `cause &= ~(1UL << 63)`，或者用 `tf->cause & 0xff` 取低 8 位。

关于其他中断：

- `IRQ_S_SOFT` 打印 `Supervisor software interrupt`，用于区分“软件中断”这一类型。
- `IRQ_S_EXT` 打印 `Supervisor external interrupt`；本实验的控制台是轮询式，不会真的产生外部中断，但保留分类输出符合“其他类型中断完成基本类型区分”的要求。
- 未识别中断（例如平台保留的中断码 15）打印 `Unknown interrupt: cause %d`，便于调试。

### 4.2 `exception_handler()`

实现位于 `kern/trap/trap.c` 第 141 行起：

```c
switch (tf->cause) {
case CAUSE_ILLEGAL_INSTRUCTION:
    cprintf("Illegal instruction at 0x%016lx\n", tf->epc);
    tf->epc += trap_insn_len(tf->epc);
    break;
case CAUSE_BREAKPOINT:
    cprintf("Breakpoint at 0x%016lx\n", tf->epc);
    tf->epc += trap_insn_len(tf->epc);
    break;
default:
    print_trapframe(tf);
    break;
}
```

关键点：

1. **异常发生时 `sepc` 指向“出错的那条指令”**，而不是下一条。如果直接 `sret`，会再次执行同一条 `ebreak`/非法指令，形成异常循环。因此必须把 `tf->epc` 推进到出错指令之后。

2. **推进量取决于指令长度。** RISC-V 指令长度编码在第一个半字的低两位：
   - `bits[1:0] != 0b11`：16 位压缩指令，`+2`；
   - `bits[1:0] == 0b11`：32 位指令，`+4`。

   `trap_insn_len()` 读取 `epc` 处的第一个半字并返回 2 或 4。本实验的 `ebreak` 和 `.word 0x0000007b` 都是 4 字节，`+4` 也能通过；但按指令编码判断更符合“不能假定所有异常使用相同偏移量”的要求，也为将来开启 C 扩展留出余地。

3. **非法指令异常与断点异常的 `epc` 语义相同**：都指向 faulting instruction，所以处理方式一致。两者的区别只是 `scause` 的异常码（2 vs 3）和输出文案。

4. **未列出的异常使用 `print_trapframe(tf)` 兜底。** 本实验不要求实现缺页、访问异常等的恢复逻辑；完整打印 trapframe（32 个寄存器 + status/epc/badvaddr/cause）是框架提供的调试手段。

### 4.3 为什么异常处理不能“只打印不推进”

假设断点异常处理只打印、不修改 `epc`：

```text
ebreak → trap → 打印 → sret 回到 ebreak → trap → 打印 → ...
```

系统会陷入死循环，串口不断输出 `Breakpoint at ...`。这类 bug 在 QEMU 里表现为“程序像卡住了，但其实一直在重复同一条指令”。推进 `epc` 后，`sret` 才会回到 `ebreak` 的下一条指令。

### 4.4 两个处理函数的对外接口

| 函数 | 输入 | 输出/副作用 |
| --- | --- | --- |
| `void interrupt_handler(struct trapframe *tf)` | 当前 trapframe，`tf->cause` 最高位为 1 | 重装时钟、`ticks++`、按类型输出；返回后由 `__trapret` 恢复上下文 |
| `void exception_handler(struct trapframe *tf)` | 当前 trapframe，`tf->cause` 最高位为 0 | 输出异常信息；对非法指令/断点更新 `tf->epc`；其他异常打印 trapframe |

两个函数都返回 `void`，不直接 `sret`；它们只修改 trapframe，真正的返回统一由 `__trapret` 完成。这样“处理逻辑”和“上下文恢复”解耦，后续增加新的中断/异常类型时不需要改汇编。

---

## 5. 运行与判分结果

### 5.1 正常启动

在 WSL 中执行 `make qemu`，串口输出（节选）：

```text
DTB init completed
(THU.CST) os is loading ...
Special kernel symbols:
  entry  0xffffffffc0200054 (virtual)
  ...
memory management: default_pmm_manager
check_alloc_page() succeeded!
satp virtual address: 0xffffffffc0205000
satp physical address: 0x0000000080205000
++ setup timer interrupts
100 ticks
100 ticks
100 ticks
100 ticks
```

`100 ticks` 每秒出现一次，说明时钟中断被持续重装、`ticks` 持续累加、`sret` 能反复回到被打断的执行流。

### 5.2 官方判分脚本

```text
$ make grade
...
  - trap entry, register restore, and breakpoint EPC: PASS (35/35)
  - illegal instruction EPC advance and return: PASS (25/25)
  - re-armed supervisor timer and repeated trap return: PASS (40/40)
Total Score: 100/100
```

三个用例分别覆盖：

| 用例 | 覆盖点 | 分数 |
| --- | --- | --- |
| `GRADE_LAB3_CONTEXT` | 设置 `t0..t6/s0..s11/a1..a7` 后执行 `ebreak`，检查所有寄存器是否原样恢复；检查断点 `epc` 推进 | 35 |
| `GRADE_LAB3_ILLEGAL` | 执行非法指令 `.word 0x0000007b`，检查非法指令返回；检查软中断/未知中断/未知异常的兜底输出 | 25 |
| `GRADE_LAB3_TIMER` | 检查 `clock_init()` 后 `ticks == 0`；使能中断后等待 `ticks >= 200`，检查持续时钟中断 | 40 |

---

## 6. 每个练习的 spec 与 prompt

> 这一节按“如果让我重新设计提示词，我会怎样让 AI 一次写对”来写。spec 是给人和 AI 的共同契约，prompt 是在 spec 之上给 AI 的具体任务描述。

### 6.1 练习一：`RESTORE_ALL` 与 `__alltraps`

#### spec（契约）

**输入/前置条件**

- `sp` 指向 `SAVE_ALL` 构造好的 trapframe 首地址。
- trapframe 布局固定：`gpr[0..31]` 在偏移 `0..31*REGBYTES`，`status/epc/badvaddr/cause` 在 `32..35*REGBYTES`。
- `SAVE_ALL` 已把旧 `sp` 保存在偏移 `2*REGBYTES`，并已把 `sscratch` 清零。

**输出/后置条件**

- `sstatus`、`sepc` 从 trapframe 恢复。
- `x1, x3..x31` 从 trapframe 恢复；`x2` 最后从偏移 `2*REGBYTES` 恢复。
- 宏执行完后，`sp` 回到进入 Trap 之前的值，trapframe 所占栈空间被释放。
- `__alltraps` 执行 `a0 = sp; jal trap;`，`trap()` 返回后直接落入 `__trapret`。

**不变量/约束**

- 不修改 `SAVE_ALL` 的保存关系、`struct trapframe`、`trap()` 签名。
- 不在恢复 `x2` 之后再使用 `sp` 寻址。
- 不恢复 `x0`（硬连线 0）。
- 不在 `RESTORE_ALL` 里调用 C 函数（会破坏刚恢复的寄存器/栈）。
- 保留 `#lab3 function1` 注释。

**验收**

- `ebreak` 前后 `t0..t6/s0..s11/a1..a7` 全部保持不变。
- `sret` 后回到 `ebreak` 的下一条指令，不重复触发断点。
- 时钟中断可以连续发生，`100 ticks` 每秒输出一次。

#### prompt（可直接复用）

```text
你是 RISC-V 64 位操作系统内核开发者。请在 kern/trap/trapentry.S 中补全
RESTORE_ALL 宏和 __alltraps 中“调用 C 函数 trap”的部分。

已知上下文：
1. struct trapframe 由 struct pushregs gpr（32 个 uintptr_t）、status、epc、
   badvaddr、cause 组成，共 36 * REGBYTES 字节。
2. SAVE_ALL 已经存在且不能修改。它把 x0、x1、x3..x31 保存在偏移
   0、1、3..31；把进入 Trap 前的 sp 保存在偏移 2；把 sstatus、sepc、
   stval、scause 保存在偏移 32..35。
3. 进入 __alltraps 时 sp 指向当前内核栈；SAVE_ALL 执行后 sp 指向
   trapframe 首地址。
4. trap(struct trapframe *tf) 遵循 RISC-V 调用约定，sp 是 callee-saved，
   返回后 sp 不变。

要求：
1. RESTORE_ALL 先恢复 sstatus 和 sepc，再恢复 x1、x3..x31，最后恢复 x2。
2. 解释为什么 x2 必须最后恢复；如果先恢复 x2 会发生什么。
3. __alltraps 中用 mv a0, sp 把 trapframe 指针作为第一个参数传给 trap，
   然后 jal trap；trap 返回后不要额外调整 sp，直接落入 __trapret。
4. 不得修改 SAVE_ALL、struct trapframe、trap() 的函数签名。
5. 只输出可以放进 trapentry.S 的汇编代码，不要伪代码；保留
   "#lab3 function1" 注释。
6. 最后给出一份自检清单：寄存器偏移、sp 恢复顺序、sret 前的 CSR 状态。

请先复述 trapframe 的偏移表，再给出代码，避免偏移写错。
```

这个 prompt 的关键是：**先把布局和保存关系说清楚，再要求“先复述再写代码”**。AI 最容易犯的错误不是不会写 `ld`，而是把 `sp` 的槽位记成 0 或 1，或者先恢复 `sp`。

### 6.2 练习二：`interrupt_handler` 与 `exception_handler`

#### spec（契约）

**输入/前置条件**

- `tf` 指向当前 trapframe，`tf->cause` 是完整的 `scause`（中断时最高位为 1）。
- 时钟中断时 `sstatus.SIE` 已被硬件清零；`clock_set_next_event()` 可用。
- `ticks` 是 `volatile size_t`，`TICK_NUM = 100`。
- `print_ticks()`、`print_trapframe()` 已提供。

**输出/后置条件**

- 时钟中断：调用 `clock_set_next_event()` 重装下一次事件；`ticks++`；`ticks % 100 == 0` 时 `print_ticks()`。
- 软件中断：输出 `Supervisor software interrupt`。
- 外部中断：输出 `Supervisor external interrupt`。
- 未知中断：输出 `Unknown interrupt: cause <code>`。
- 非法指令：输出 `Illegal instruction at 0x...`，`tf->epc += 指令长度`。
- 断点：输出 `Breakpoint at 0x...`，`tf->epc += 指令长度`。
- 其他异常：`print_trapframe(tf)` 兜底。
- 两个函数都返回 `void`，不直接 `sret`，由 `__trapret` 统一返回。

**不变量/约束**

- 不修改函数签名，不修改 `trap.c` 中规定以外的函数。
- 中断分支必须先清 `scause` 最高位再 `switch`。
- 异常分支必须按指令长度推进 `epc`，不能假定所有异常都是 `+4`。
- 不能只计数不重装时钟。
- 保留 `//lab3 function2` 注释。

**验收**

- 连续时钟中断：`100 ticks` 每秒一次，`ticks` 能到 200 以上。
- `ebreak` 返回后不重复断点。
- 非法指令返回后不重复非法指令。
- 软中断、未知中断、未知异常都有输出，不崩溃。

#### prompt（可直接复用）

```text
你是 RISC-V 64 位操作系统内核开发者。请在 kern/trap/trap.c 中实现
interrupt_handler(struct trapframe *tf) 和
exception_handler(struct trapframe *tf)。

已知上下文：
1. trap() 已经根据 (intptr_t)tf->cause < 0 把中断和异常分开；你只需要实现
   两个 handler，不要改 trap() 和函数签名。
2. RISC-V 的 scause 最高位是 Interrupt 位：1 表示中断，0 表示异常；
   低位的 Exception Code 才是中断/异常编号。
3. IRQ_S_TIMER = 5，IRQ_S_SOFT = 1，IRQ_S_EXT = 9；
   CAUSE_ILLEGAL_INSTRUCTION = 2，CAUSE_BREAKPOINT = 3。
4. OpenSBI 的 sbi_set_timer() 一次只设置一个绝对时刻；clock_set_next_event()
   会调用 sbi_set_timer(get_cycles() + timebase)。
5. ticks 是 volatile size_t，TICK_NUM = 100；print_ticks() 会输出
   "100 ticks"；print_trapframe(tf) 会打印完整 trapframe。
6. 异常发生时 sepc 指向出错指令本身，不是下一条；RISC-V 指令长度由第一个
   半字的低两位决定：0b11 为 32 位（+4），否则为 16 位（+2）。

行为要求：
- 时钟中断：先 clock_set_next_event()，再 ticks++；ticks % TICK_NUM == 0
  时 print_ticks()。
- 软件中断：输出 "Supervisor software interrupt\n"。
- 外部中断：输出 "Supervisor external interrupt\n"。
- 其他中断：输出 "Unknown interrupt: cause %d\n"，注意先清掉最高位。
- 非法指令：输出 "Illegal instruction at 0x%016lx\n"，按指令长度推进 epc。
- 断点：输出 "Breakpoint at 0x%016lx\n"，按指令长度推进 epc。
- 其他异常：print_trapframe(tf) 兜底。

约束：
1. 不得修改函数签名和 trap.c 中规定以外的函数。
2. 中断分支必须先清 scause 最高位，否则 case 永远匹配不上；请解释原因。
3. 不要只计数不重装时钟；请解释为什么。
4. 不要假定所有异常都是 +4；请说明如何根据指令编码判断长度。
5. 保留 "//lab3 function2" 注释。

请先列出“中断码/异常码 → 行为”的表格，再给出实现，最后给出自检清单：
- scause 最高位处理
- 时钟重装顺序
- ticks 累加与输出条件
- epc 推进
- 未知类型兜底
```

这个 prompt 的关键是：**把“行为表”和“容易漏掉的副作用”写清楚**。AI 常见错误是只写 `ticks++` 忘了 `clock_set_next_event()`，或者直接 `switch (tf->cause)` 导致所有中断都进 `default`。

### 6.3 让 AI 少跑偏的通用做法

1. **先给数据结构，再给任务。** 例如 trapframe 的字段顺序、`REGBYTES`、偏移表；不要只说“实现上下文恢复”。
2. **把“不能改什么”写进 prompt。** 本实验明确不能改 `SAVE_ALL`、`struct trapframe`、`trap()` 签名；AI 很容易“顺手重构”。
3. **要求 AI 先复述再写代码。** 让它在输出代码前复述偏移表/行为表，可以提前发现理解偏差。
4. **要求给出自检清单。** 例如“sp 是否最后恢复”“scause 最高位是否清零”“epc 是否推进”。
5. **要求只输出 diff/目标片段。** 避免 AI 重写整个文件，减少引入无关改动的风险。
6. **用测试反推。** 本实验的 `tools/test_lab3.c` 和 `tools/grade.sh` 就是最好的 spec；把期望输出字符串写进 prompt，AI 更容易对齐。

---

## 7. 使用提示词让 AI 生成代码时出现的 bug 与解决

> 下面记录的是本次实际踩到/在迭代中验证过的问题。前两个是环境/框架问题，后面是 AI 生成上下文中常见的典型错误。

### 7.1 `sbadaddr` 在当前 binutils 中不存在

**现象**

```text
kern/trap/trapentry.S:47: Error: unknown CSR `sbadaddr'
```

**原因**

`sbadaddr` 是 RISC-V 特权规范 1.10 之前的 CSR 名；新版 binutils（2.45）只接受 `stval`。两者是同一个 CSR（0x143），不是两个不同的寄存器。

**解决**

把 `SAVE_ALL` 中的 `csrr s3, sbadaddr` 改为 `csrr s3, stval`，并加注释说明。C 侧 `print_trapframe()` 仍然使用 `tf->badvaddr` 字段，语义不变。

**启示**

AI 生成汇编时容易照抄旧教材/旧代码；如果工具链版本较新，CSR 别名、伪指令、`-march` 默认值都可能变化。遇到“代码看起来对但汇编器不认”的情况，先查工具链版本和规范版本。

### 7.2 `page_init()` 缺失导致链接/编译失败

**现象**

```text
kern/mm/pmm.c:97:5: error: implicit declaration of function 'page_init'
```

以及后续 `best_fit_pmm.c` 中 `free_list`、`nr_free` 未定义。

**原因**

工作区的 lab2 代码没有补全：`pmm.c` 调用了 `page_init()` 但函数不存在；`best_fit_pmm.c` 只有 check 函数，没有空闲链表和 manager 实现。lab3 依赖 lab2 的 PMM，所以必须先让工程可编译。

**解决**

- 在 `pmm.c` 中补 `page_init()`：设置 `va_pa_offset`、`npage`、`pages` 数组，先把所有页标 `PG_reserved`，再把内核和页数组之后的物理内存交给 `init_memmap()`。
- 在 `best_fit_pmm.c` 中补 `free_area`、`best_fit_init/init_memmap/alloc_pages/free_pages/nr_free_pages` 和 `best_fit_pmm_manager`。

> 本框架的 `init_pmm_manager()` 仍然选择 `default_pmm_manager`；补齐 best-fit 是为了让 lab2 代码完整、可编译。若要让本实验改用 best-fit，把 `pmm_manager = &best_fit_pmm_manager;` 即可。本次没有切换，以免改变 lab3 判分基线。

### 7.3 `npage` 语义错误导致 `pa2page called with invalid pa`

**现象**

```text
memory management: default_pmm_manager
kernel panic at kern/mm/pmm.h:107:
    pa2page called with invalid pa
```

**原因**

最初按“页数”理解 `npage`，写成 `npage = mem_size / PGSIZE`（128 MB → 0x8000）。但框架的 `pa2page()` 是：

```c
if (PPN(pa) >= npage) panic(...);
return &pages[PPN(pa) - nbase];
```

它拿**绝对 PPN**（物理地址 0x80000000 对应 PPN 0x80000）和 `npage` 比较。如果 `npage = 0x8000`，任何物理页的 PPN 都大于它，必然 panic。`basic_check` 里的 `page2pa(p0) < npage * PGSIZE` 也要求 `npage` 是“物理内存末尾的绝对 PPN”。

**解决**

```c
npage = (mem_base + mem_size) / PGSIZE;   // 绝对上界，例如 0x88000
size_t page_count = npage - nbase;        // pages[] 实际需要的条目数
```

`pages[]` 只分配 `page_count` 项，索引 `PPN - nbase`；`pa2page()` 的边界检查和 `page2pa()` 的 sanity check 都满足。

**启示**

“页数”和“最大页号”是两个概念，尤其在物理内存不从 0 开始的 RISC-V 平台上。写代码前先看 `page2ppn/pa2page` 的定义，不要凭直觉命名。

### 7.4 先恢复 `sp` 导致后续 `LOAD` 全部错位

**错误写法**

```asm
LOAD x2, 2*REGBYTES(sp)   # 先恢复 sp
LOAD x1, 1*REGBYTES(sp)   # 此时 sp 已经是旧栈指针，读错位置
```

**现象**

寄存器上下文测试失败；严重时在 `RESTORE_ALL` 内触发 load page fault，形成二次 Trap。

**解决**

`x2` 最后恢复。所有以 `sp` 为基址的 `LOAD` 完成后，再把 `x2` 从 `2*REGBYTES(sp)` 弹出。

### 7.5 `switch (tf->cause)` 匹配不上中断

**错误写法**

```c
switch (tf->cause) {
case IRQ_S_TIMER:   // 5
    ...
}
```

**现象**

时钟中断确实发生了，但每次都打印 `Unknown interrupt: cause ...`，`ticks` 不增加。

**原因**

中断的 `scause` 最高位是 1，实际值是 `0x8000000000000005`，不等于 5。

**解决**

先清最高位：

```c
uintptr_t cause = tf->cause & ~((uintptr_t)1 << 63);
switch (cause) { ... }
```

或者用 `tf->cause & 0xff` 取低位中断码。

### 7.6 只计数不重装时钟，系统只收到一次中断

**错误写法**

```c
case IRQ_S_TIMER:
    ticks++;
    if (ticks % TICK_NUM == 0) print_ticks();
    break;
```

**现象**

串口只输出一次 `100 ticks`（如果恰好到 100），之后不再有输出；或者只输出一行就停住。

**原因**

OpenSBI 的 `sbi_set_timer()` 是“一次性”的：设置一个绝对时刻，到点触发一次。不重装就不会有下一次。

**解决**

每次时钟中断先 `clock_set_next_event()`，再计数：

```c
clock_set_next_event();
ticks++;
```

### 7.7 不推进 `epc` 导致异常循环

**错误写法**

```c
case CAUSE_BREAKPOINT:
    cprintf("Breakpoint at ...\n");
    break;   // 没有修改 tf->epc
```

**现象**

串口不断打印 `Breakpoint at ...`，系统像卡死。

**原因**

`sret` 回到 `sepc`，而 `sepc` 仍指向 `ebreak`，于是再次触发断点。

**解决**

按指令长度推进：

```c
tf->epc += trap_insn_len(tf->epc);
```

### 7.8 误以为 `trap()` 返回后要手动 `addi sp, sp, 36*REGBYTES`

**错误写法**

```asm
jal trap
addi sp, sp, 36*REGBYTES   # 多余
```

**现象**

`RESTORE_ALL` 从错误的栈位置取数据，寄存器恢复错乱，甚至 `sret` 跳到非法地址。

**原因**

`RESTORE_ALL` 的最后一条 `LOAD x2, 2*REGBYTES(sp)` 已经把 `sp` 恢复成旧值，相当于弹出了 trapframe；不需要再 `addi`。

**解决**

`jal trap` 后直接落入 `__trapret`，让 `RESTORE_ALL` 负责恢复 `sp`。

---

## 8. 本实验重要知识点与 OS 原理的对应

| 实验中的知识点 | 对应 OS 原理 | 含义、关系与差异 |
| --- | --- | --- |
| `struct trapframe` | 中断帧 / 进程上下文（context） | 都是“被打断时刻的 CPU 状态快照”。差异：trapframe 是每次 Trap 在内核栈上临时构造的，不是完整 PCB；本实验没有进程切换，只保存 32 个 GPR + 4 个 CSR，不保存浮点/向量寄存器。 |
| `SAVE_ALL` / `RESTORE_ALL` | 上下文保存与恢复、上下文切换 | 都是保存/恢复寄存器现场。差异：本实验是“Trap 返回”而不是“进程切换”；不涉及页表基址 `satp`、不涉及调度器选下一个进程。 |
| `sscratch` | 内核栈指针 / per-hart 数据、用户态-内核态栈切换 | xv6 用 `sscratch` 保存内核栈顶，进入 Trap 时换栈；本实验所有 Trap 在 S 模式，`sscratch` 主要用来暂存旧 `sp`，进入后清零。 |
| `stvec` | 中断向量表 / IDT | 都是“Trap 入口地址”。差异：RISC-V S 模式 Direct 模式只有一个入口 `__alltraps`，由软件读 `scause` 再分发；x86 IDT 有 256 个门，硬件按向量号选入口。 |
| `scause` | 中断/异常原因 | 对应 x86 的 vector + error code。最高位区分中断/异常，低位是原因码；本实验用 `cause < 0` 判断中断。 |
| `sepc` | 返回地址 / 程序计数器 | 对应 x86 的 `eip`/`rip` 保存位置。异常时指向 faulting instruction，所以处理完要手动推进；中断时指向被打断的下一条指令。 |
| `stval`（旧名 `sbadaddr`） | 故障地址 | 对应 x86 的 `CR2`（缺页地址）。本实验只用于 `print_trapframe()` 调试，没有实现缺页处理。 |
| `sstatus.SPP/SPIE/SIE` | 特权级 / 中断使能 / 返回状态 | `sret` 根据 `SPP` 决定返回 S/U 模式，根据 `SPIE` 恢复 `SIE`。对应 x86 的 `CS/EFLAGS` 恢复。 |
| `sret` | 中断返回指令（`iret`） | 都是“恢复现场并返回”。差异：RISC-V 用 `sepc` + `sstatus`，x86 用栈上的 `eip/cs/eflags`。 |
| 时钟中断 + `sbi_set_timer` | 可编程定时器 / 时间片 | 都是“每隔固定时间产生一次中断”。差异：本实验通过 SBI ecall 设置绝对时刻，QEMU 的 `time` CSR 频率 10 MHz；x86 常用 PIT/APIC 定时器。 |
| `intr_enable/disable`、`local_intr_save/restore` | 关中断 / 临界区 | 都是保证一段代码不被中断打断。差异：本实验是单核，关中断就够了；多核还需要自旋锁、原子指令、内存屏障。 |
| `page_init()` / `struct Page` / 空闲链表 | 物理内存管理（PMM） | 都是把物理页组织成可分配的资源。差异：本实验只做物理页分配，没有虚拟内存、没有页表映射的按需建立。 |
| best-fit 分配 | 动态分区分配 / 外部碎片 | 都是“找满足大小的空闲块”。差异：best-fit 选最小满足块，减少大块被拆碎，但会产生小碎片；first-fit 更快但可能留下大块尾部碎片。 |
| `print_trapframe()` / `panic()` | 内核调试 / 故障转储 | 都是“出问题时打印现场”。差异：本实验的 panic 进入 `kmonitor` 循环，不是完整的 kdump/核心转储。 |

---

## 9. OS 原理中很重要、但本实验没有对应覆盖的知识点

1. **虚拟内存与缺页异常处理**
   本实验只建立了固定的 boot page table（Sv39 的 1 GB 大页映射），没有实现缺页异常（page fault）、按需分页、页面置换、写时复制。`stval` 只被打印，没有被用来做地址翻译或恢复。

2. **进程/线程与调度**
   本实验没有 PCB、没有进程切换、没有调度器。`trapframe` 只是 Trap 现场，不是“进程上下文”；没有 `fork/exec/wait/exit`，也没有时间片轮转。

3. **用户态与系统调用**
   所有代码都在 S 模式执行，没有真正的 U 模式；没有从 U 模式 `ecall` 进入内核、没有参数传递/返回值/权限检查。`sret` 的 `SPP` 在本实验中始终是 1（返回 S 模式）。

4. **同步与互斥**
   本实验只有单核关中断，没有锁、信号量、条件变量、原子操作的多核语义；没有临界区竞争、死锁、优先级反转等问题。

5. **文件系统与 I/O 子系统**
   没有 VFS、inode、目录、文件描述符、块设备驱动；控制台是轮询式 `sbi_console_putchar`，没有中断驱动的 UART 驱动。

6. **中断下半部/软中断/工作队列**
   本实验的软中断只是打印一句话，没有“上半部快速响应、下半部延迟处理”的机制；没有 tasklet/workqueue。

7. **多核与并发**
   没有 per-CPU 数据、IPI（核间中断）、内存一致性、锁的原子性；`sscratch` 的 per-hart 语义也没有真正使用。

8. **安全与隔离**
   没有页表权限隔离（U/S 位）、没有用户指针校验、没有栈保护/ASLR 等。

---

## 10. 附录 A：在 WSL 中完成本实验的具体步骤

### 10.1 安装/进入 WSL

在 Windows 管理员 PowerShell 中：

```powershell
wsl --install -d Ubuntu
```

如果已经安装过：

```powershell
wsl -l -v
wsl -d Ubuntu
```

首次进入 Ubuntu 时设置 UNIX 用户名和密码。后面的命令都在 Ubuntu 终端里执行。

### 10.2 安装 RISC-V 工具链和 QEMU

```bash
sudo apt update
sudo apt install -y \
    build-essential git python3 \
    gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf \
    qemu-system-misc gdb-multiarch
```

验证：

```bash
riscv64-unknown-elf-gcc --version
riscv64-unknown-elf-as --version
qemu-system-riscv64 --version
python3 --version
```

如果 `qemu-system-riscv64` 找不到，确认安装的是 `qemu-system-misc`（Ubuntu 把 RISC-V 系统模拟器放在这个包里）。

### 10.3 把工程放进 WSL

可以直接在 `/mnt/c` 下工作：

```bash
cd /mnt/c/Users/lxmre/OneDrive/Desktop/lab3_new
```

更推荐复制到 WSL 自己的文件系统，避免 OneDrive 同步和跨文件系统性能问题：

```bash
cp -r /mnt/c/Users/lxmre/OneDrive/Desktop/lab3_new ~/lab3
cd ~/lab3
```

如果复制后要继续在 Windows 编辑器里改，注意两边是两份副本；可以改用 VS Code 的 WSL Remote 直接打开 `~/lab3`。

检查换行符（如果从 Windows 拷贝后脚本报 `\r` 错误）：

```bash
file tools/grade.sh Makefile
# 若显示 CRLF：
sed -i 's/\r$//' Makefile tools/grade.sh
```

### 10.4 编译

```bash
make clean
make
```

期望看到最后两行：

```text
ld bin/kernel
riscv64-unknown-elf-objcopy bin/kernel --strip-all -O binary bin/ucore.img
```

产物：

```bash
ls -l bin/kernel bin/ucore.img
```

### 10.5 运行

```bash
make qemu
```

期望输出（节选）：

```text
++ setup timer interrupts
100 ticks
100 ticks
100 ticks
```

退出 QEMU：先按 `Ctrl-A`，再按 `X`。如果只是想看几秒输出：

```bash
timeout 8 make qemu
```

### 10.6 跑官方判分

```bash
make grade
```

它会：

1. `make clean`；
2. 把工程复制到 `/tmp/lab3_grade`；
3. 用 `tools/inject.py` 注入 `kern/test/test_lab3.c` 等测试代码；
4. 分别用 `-DGRADE_LAB3_CONTEXT`、`-DGRADE_LAB3_ILLEGAL`、`-DGRADE_LAB3_TIMER` 编译并运行 QEMU；
5. 用 `grep` 检查输出字符串，计算分数。

期望：

```text
  - trap entry, register restore, and breakpoint EPC: PASS (35/35)
  - illegal instruction EPC advance and return: PASS (25/25)
  - re-armed supervisor timer and repeated trap return: PASS (40/40)
Total Score: 100/100
```

如果 `/tmp/lab3_grade` 残留导致权限问题：

```bash
sudo rm -rf /tmp/lab3_grade
```

### 10.7 调试（可选）

终端 1：

```bash
make debug
```

它会启动 QEMU 并等待 GDB 连接（`-s -S`，端口 1234）。

终端 2：

```bash
riscv64-unknown-elf-gdb \
    -ex 'file bin/kernel' \
    -ex 'set arch riscv:rv64' \
    -ex 'target remote localhost:1234'
```

如果系统没有 `riscv64-unknown-elf-gdb`，用 `gdb-multiarch`：

```bash
gdb-multiarch \
    -ex 'file bin/kernel' \
    -ex 'set arch riscv:rv64' \
    -ex 'target remote localhost:1234'
```

常用命令：

```gdb
b trap
b interrupt_handler
b exception_handler
c
info registers
x/36gx $sp        # 查看 trapframe
p/x $sepc
p/x $scause
```

---

## 11. 附录 B：提交前自检清单

- [] `make` 无 warning/error（本工程使用 `-Wall -Werror`）。
- [] `make qemu` 能持续输出 `100 ticks`。
- [] `make grade` 为 `100/100`。
- [] `RESTORE_ALL` 中 `x2` 最后恢复。
- [] `RESTORE_ALL` 先写 `sstatus/sepc`。
- [] `__alltraps` 用 `a0 = sp` 传 trapframe，`jal trap` 后不额外调整 `sp`。
- [] `interrupt_handler` 先清 `scause` 最高位。
- [] 时钟中断每次调用 `clock_set_next_event()`。
- [] `ticks` 每收到一次时钟中断加一，`ticks % 100 == 0` 输出。
- [] 非法指令/断点按指令长度推进 `epc`。
- [] 未知中断/异常有兜底输出。

---

## 12. 参考

- RISC-V Privileged Architecture, Volume II: Supervisor Cause Register (`scause`), Table 4.2.
- RISC-V Calling Convention（`sp` 为 callee-saved，`a0` 为第一个参数）。
- xv6-riscv `trap.c` / `trapentry.S` 的 trapframe 与 `sscratch` 用法（本实验框架与其同源）。
- 课程实验指导书：实验 3“中断处理机制”功能模块一、二。
- 本仓库：`kern/trap/trapentry.S`、`kern/trap/trap.c`、`kern/mm/pmm.c`、`kern/mm/best_fit_pmm.c`、`tools/test_lab3.c`、`tools/grade.sh`。
