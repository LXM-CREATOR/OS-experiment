# 杨珺童负责部分的截图操作清单

本目录保存“内核入口、栈初始化与练习1”的五张实际运行截图，均已在实验报告中引用。

## 截图1和截图2：反汇编和符号地址

在WSL中进入仓库根目录，重新构建并执行：

```bash
make clean
make
riscv64-unknown-elf-objdump -d bin/kernel | sed -n '/<kern_entry>:/,+5p'
riscv64-unknown-elf-nm -n bin/kernel | grep -E 'kern_entry|kern_init|bootstack'
```

截图应完整包含：

- `kern_entry`的三条实际反汇编结果；
- `kern_entry = 0x80200000`；
- `kern_init = 0x8020000a`；
- `bootstack = 0x80201000`；
- `bootstacktop = 0x80203000`。

两部分输出分别保存为：

```text
images/entry/01_entry_disassembly.png
images/entry/02_stack_symbols.png
```

## 截图3至截图5：GDB验证

打开两个WSL终端，并确保都位于仓库根目录。

终端A执行：

```bash
bash tools/entry-stack-debug.sh
```

终端B执行：

```bash
make gdb
```

连接成功并出现GDB提示符后执行：

```gdb
source tools/entry-stack-verify.gdb
```

这里使用专门的`entry-stack-debug.sh`，是为了保证QEMU按照本仓库验证日志采用的`-kernel bin/ucore.img`方式设置下一阶段入口地址，并在CPU执行第一条指令前暂停。

脚本会自动完成以下操作：

1. 在`kern_entry`设置硬件断点；
2. 显示`kern_entry`实际反汇编；
3. 输出`bootstack`、`bootstacktop`和栈大小；
4. 记录执行入口指令前的`pc`和`sp`；
5. 单步执行`la`对应的两条机器指令；
6. 验证`sp = bootstacktop = 0x80203000`；
7. 单步执行`tail`，验证`pc = kern_init = 0x8020000a`；
8. 输出最终PASS信息。

把包含“执行入口指令前”一段的画面保存为：

```text
images/entry/03_gdb_entry_before.png
```

把包含`AFTER_STEP_1`和`AFTER_LA`的画面保存为：

```text
images/entry/04_gdb_after_la.png
```

把包含`AFTER_TAIL`和`kern_init`反汇编的画面保存为：

```text
images/entry/05_gdb_after_tail.png
```

## 截图检查

提交前确认：

- 图片文字清晰，没有被窗口边缘截断；
- 图片中能看出执行的命令和输出值；
- 不要裁掉GDB中的`pc`、`sp`和地址；
- 五张图片都已加入Git；
- GitHub上的Markdown报告能够正常显示图片。
