#include <riscv.h>

//LAB4 function3 2411438_2411513
/*
 * switch_to(struct context *from, struct context *to)
 *   a0 = from（原线程的执行现场），a1 = to（目标线程的执行现场）
 *
 * 只负责“被调用者保存寄存器”的保存与恢复：
 *   ra, sp, s0 ~ s11 共 14 个寄存器，正好对应 struct context 的 14 个字段。
 * 调用者保存寄存器（t0~t6、a0~a7）由编译器在函数调用处自己负责，
 * 所以这里不需要保存。真正的调度策略由 schedule()/proc_run() 决定，
 * switch_to 不参与任何判断。
 *
 * 新线程第一次被切换进来时，a1 指向的 context 中 ra = forkret、sp 指向
 * 内核栈顶的 trapframe，于是 ret 之后会进入 forkret -> forkrets ->
 * __trapret 这条首次运行链路。
 */
.text
.globl switch_to
.align 2
switch_to:
    # 保存 from 线程的执行现场
    STORE ra,  0*REGBYTES(a0)
    STORE sp,  1*REGBYTES(a0)
    STORE s0,  2*REGBYTES(a0)
    STORE s1,  3*REGBYTES(a0)
    STORE s2,  4*REGBYTES(a0)
    STORE s3,  5*REGBYTES(a0)
    STORE s4,  6*REGBYTES(a0)
    STORE s5,  7*REGBYTES(a0)
    STORE s6,  8*REGBYTES(a0)
    STORE s7,  9*REGBYTES(a0)
    STORE s8, 10*REGBYTES(a0)
    STORE s9, 11*REGBYTES(a0)
    STORE s10, 12*REGBYTES(a0)
    STORE s11, 13*REGBYTES(a0)

    # 恢复 to 线程的执行现场
    LOAD ra,  0*REGBYTES(a1)
    LOAD sp,  1*REGBYTES(a1)
    LOAD s0,  2*REGBYTES(a1)
    LOAD s1,  3*REGBYTES(a1)
    LOAD s2,  4*REGBYTES(a1)
    LOAD s3,  5*REGBYTES(a1)
    LOAD s4,  6*REGBYTES(a1)
    LOAD s5,  7*REGBYTES(a1)
    LOAD s6,  8*REGBYTES(a1)
    LOAD s7,  9*REGBYTES(a1)
    LOAD s8, 10*REGBYTES(a1)
    LOAD s9, 11*REGBYTES(a1)
    LOAD s10, 12*REGBYTES(a1)
    LOAD s11, 13*REGBYTES(a1)

    ret
