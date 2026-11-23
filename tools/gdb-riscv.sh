#!/bin/sh
# gdb-riscv.sh - RISC-V 远程调试的 gdb 包装脚本
#
# 有些实验环境（例如只装了 gcc-riscv64-unknown-elf 的 WSL）里没有
# riscv64-unknown-elf-gdb，只有 gdb-multiarch。gdb-multiarch 默认不知道
# 目标架构，直接连接 QEMU 的 gdbstub 会因为架构不匹配而报
# "Truncated register 37 in remote 'g' packet"。
# 因此在处理任何命令（包括 grade.sh 传入的 -x 脚本）之前，
# 先显式把架构设置为 riscv:rv64，再交给 gdb-multiarch。
exec gdb-multiarch -ex 'set architecture riscv:rv64' "$@"
