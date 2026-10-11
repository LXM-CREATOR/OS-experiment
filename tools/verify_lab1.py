#!/usr/bin/env python3
"""Local boot and debugger checks; this is NOT the course grading script."""
from pathlib import Path
import re
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT if (ROOT / 'Makefile').is_file() else ROOT / 'lab1'
LOGS = PROJECT / 'logs'


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def main():
    qemu, gdb = sys.argv[1:3]
    LOGS.mkdir(exist_ok=True)
    with (LOGS / 'build.log').open('w') as output:
        subprocess.run(['make', '-B', '-j2'], cwd=PROJECT, stdout=output,
                       stderr=subprocess.STDOUT, check=True)
    with (LOGS / 'environment.log').open('w') as output:
        for args in (['uname', '-a'], ['riscv64-unknown-elf-gcc', '--version'],
                     [qemu, '--version'], [gdb, '--version']):
            subprocess.run(args, stdout=output, stderr=subprocess.STDOUT, check=True)
    with (LOGS / 'elf.log').open('w') as output:
        for tool, opts in [('readelf', ['-h', '-S']), ('nm', ['-n']), ('objdump', ['-d'])]:
            subprocess.run(['riscv64-unknown-elf-' + tool, *opts, 'bin/kernel'],
                           cwd=PROJECT, stdout=output, stderr=subprocess.STDOUT, check=True)
    command = [qemu, '-machine', 'virt', '-m', '128M', '-smp', '1',
               '-nographic', '-bios', 'default', '-kernel', 'bin/ucore.img']
    with (LOGS / 'qemu.log').open('w') as output:
        process = subprocess.Popen(command, cwd=PROJECT, stdin=subprocess.DEVNULL,
                                   stdout=output, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 12
            while time.monotonic() < deadline:
                text = (LOGS / 'qemu.log').read_text(errors='replace')
                if '(THU.CST) os is loading ...' in text:
                    break
                if process.poll() is not None:
                    raise RuntimeError('QEMU exited before the kernel message')
                time.sleep(0.1)
            else:
                raise RuntimeError('Kernel boot message missing; see qemu.log')
            if 'Domain0 Next Address      : 0x0000000080200000' not in text:
                raise RuntimeError('Unexpected OpenSBI next address; see qemu.log')
        finally:
            stop(process)
    disassembly = subprocess.check_output(
        ['riscv64-unknown-elf-objdump', '-d', 'bin/kernel'], cwd=PROJECT, text=True)
    # GCC can inline sbi_call and discard its standalone section.
    sbi_block = disassembly.split('<sbi_console_putchar>:', 1)[1].split('\n\n', 1)[0]
    ecall_match = re.search(r'^\s*([0-9a-f]+):.*\becall\b', sbi_block, re.M)
    if not ecall_match:
        raise RuntimeError('Cannot find SBI ecall instruction')
    ecall = ecall_match.group(1)
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        port = listener.getsockname()[1]
    commands = f'''set pagination off
set confirm off
set architecture riscv:rv64
file bin/kernel
target remote 127.0.0.1:{port}
printf "RESET pc=%#lx\\n", $pc
x/6i $pc
printf "PRELOADED_KERNEL before CPU execution\\n"
x/4i 0x80200000
set $entry_instruction = *(unsigned int*)0x80200000
stepi
printf "ROM_STEP1 pc=%#lx t0=%#lx\\n", $pc, $t0
stepi
printf "ROM_STEP2 pc=%#lx a2=%#lx\\n", $pc, $a2
stepi
printf "ROM_STEP3 pc=%#lx a0=%#lx\\n", $pc, $a0
stepi
printf "ROM_STEP4 pc=%#lx a1=%#lx\\n", $pc, $a1
stepi
printf "ROM_STEP5 pc=%#lx t0=%#lx\\n", $pc, $t0
stepi
printf "OPENSBI pc=%#lx priv=%ld\\n", $pc, $priv
if $pc != 0x80000000 || $priv != 3
  echo FAIL reset ROM to OpenSBI transfer\\n
  quit 1
end
x/6i $pc
watch *(unsigned int*)0x80200000
hbreak kern_entry
continue
printf "ENTRY pc=%#lx priv=%ld\\n", $pc, $priv
if $pc != (unsigned long)&kern_entry
  echo FAIL entry address\\n
  quit 1
end
if $priv != 1
  echo FAIL kernel privilege\\n
  quit 1
end
if *(unsigned int*)0x80200000 != $entry_instruction
  echo FAIL preloaded kernel unexpectedly changed\\n
  quit 1
end
printf "PRELOAD_CHECK kernel was already present at reset; watchpoint did not fire\\n"
delete
x/4i $pc
stepi 2
printf "STACK sp=%#lx top=%#lx size=%ld\\n", $sp, &bootstacktop, (char*)&bootstacktop-(char*)&bootstack
if $sp != (unsigned long)&bootstacktop
  echo FAIL stack initialization\\n
  quit 1
end
if (char*)&bootstacktop-(char*)&bootstack != 8192
  echo FAIL stack size\\n
  quit 1
end
hbreak kern_init
continue
printf "KERN_INIT pc=%#lx\\n", $pc
hbreak memset
continue
printf "BSS start=%#lx end=%#lx dst=%#lx value=%ld length=%ld\\n", &edata, &end, $a0, $a1, $a2
if $a0 != (unsigned long)&edata || $a1 != 0 || $a2 != (char*)&end-(char*)&edata
  echo FAIL BSS clear arguments\\n
  quit 1
end
finish
hbreak cprintf
continue
printf "CPRINTF pc=%#lx\\n", $pc
x/s $a0
hbreak *0x{ecall}
continue
printf "SBI_BEFORE pc=%#lx priv=%ld a7=%ld a0=%ld\\n", $pc, $priv, $a7, $a0
if $priv != 1 || $a7 != 1 || $a0 != 40
  echo FAIL SBI console arguments\\n
  quit 1
end
stepi
printf "SBI_TRAP pc=%#lx priv=%ld mepc=%#lx mcause=%ld\\n", $pc, $priv, $mepc, $mcause
if $priv != 3 || $mcause != 9 || $mepc != 0x{ecall}
  echo FAIL S-mode ecall trap\\n
  quit 1
end
printf "PASS: entry, S-mode, stack, BSS call, printf, SBI ecall\\n"
detach
quit
'''
    (LOGS / 'verify.gdb').write_text(commands)
    with (LOGS / 'qemu-debug.log').open('w') as output:
        process = subprocess.Popen(command + ['-S', '-gdb', f'tcp:127.0.0.1:{port}'],
                                   cwd=PROJECT, stdin=subprocess.DEVNULL,
                                   stdout=output, stderr=subprocess.STDOUT)
        try:
            # GDB retries its connection; the short delay also lets QEMU initialize.
            time.sleep(0.5)
            result = subprocess.run([gdb, '-q', '-batch', '-x', str(LOGS / 'verify.gdb')],
                                    cwd=PROJECT, capture_output=True, text=True, timeout=30)
            (LOGS / 'gdb.log').write_text(result.stdout + result.stderr)
            if result.returncode or 'PASS: entry' not in result.stdout:
                raise RuntimeError('Debugger check failed; see gdb.log')
        finally:
            stop(process)
    summary = ('PASS: build ELF and BIN\nPASS: BIN boot banner\n'
               'PASS: six reset ROM instructions and M-mode firmware at 0x80000000\n'
               'PASS: preloaded kernel memory watchpoint and S-mode entry at 0x80200000\n'
               'PASS: GDB entry, S-mode, 8 KiB stack, BSS call, printf, SBI ecall\n'
               'NOTE: Lab1 guide requires two exercises and a Markdown report, not make grade.\n')
    (LOGS / 'verification.txt').write_text(summary)
    print(summary, end='')


if __name__ == '__main__':
    main()
