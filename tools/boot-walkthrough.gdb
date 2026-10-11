# 先运行 bash tools/run.sh debug，再运行 bash tools/run.sh gdb。
# 在 GDB 中执行 source tools/boot-walkthrough.gdb。
set pagination off
set confirm off
echo === Reset ROM: six instructions ===\n
x/6i $pc
echo === The kernel is already loaded before CPU execution ===\n
x/4i 0x80200000
stepi 6
printf "OpenSBI: pc=%#lx, privilege=%ld\n", $pc, $priv
x/6i $pc
watch *(unsigned int*)0x80200000
hbreak *0x80200000
continue
printf "Kernel entry: pc=%#lx, privilege=%ld\n", $pc, $priv
info registers pc sp a0 a1
delete
stepi 2
printf "Stack: sp=%#lx, bootstacktop=%#lx\n", $sp, &bootstacktop
x/8gx $sp-64
# tail 被链接为跳转；再单步一次即可进入 kern_init 第一条机器指令。
stepi
printf "C entry first instruction: pc=%#lx\n", $pc
x/5i $pc
echo === Walkthrough complete; type continue to print the boot message ===\n
