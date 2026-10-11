set pagination off
set confirm off
set architecture riscv:rv64
file bin/kernel
target remote 127.0.0.1:34877
printf "RESET pc=%#lx\n", $pc
x/6i $pc
printf "PRELOADED_KERNEL before CPU execution\n"
x/4i 0x80200000
set $entry_instruction = *(unsigned int*)0x80200000
stepi
printf "ROM_STEP1 pc=%#lx t0=%#lx\n", $pc, $t0
stepi
printf "ROM_STEP2 pc=%#lx a2=%#lx\n", $pc, $a2
stepi
printf "ROM_STEP3 pc=%#lx a0=%#lx\n", $pc, $a0
stepi
printf "ROM_STEP4 pc=%#lx a1=%#lx\n", $pc, $a1
stepi
printf "ROM_STEP5 pc=%#lx t0=%#lx\n", $pc, $t0
stepi
printf "OPENSBI pc=%#lx priv=%ld\n", $pc, $priv
if $pc != 0x80000000 || $priv != 3
  echo FAIL reset ROM to OpenSBI transfer\n
  quit 1
end
x/6i $pc
watch *(unsigned int*)0x80200000
hbreak kern_entry
continue
printf "ENTRY pc=%#lx priv=%ld\n", $pc, $priv
if $pc != (unsigned long)&kern_entry
  echo FAIL entry address\n
  quit 1
end
if $priv != 1
  echo FAIL kernel privilege\n
  quit 1
end
if *(unsigned int*)0x80200000 != $entry_instruction
  echo FAIL preloaded kernel unexpectedly changed\n
  quit 1
end
printf "PRELOAD_CHECK kernel was already present at reset; watchpoint did not fire\n"
delete
x/4i $pc
stepi 2
printf "STACK sp=%#lx top=%#lx size=%ld\n", $sp, &bootstacktop, (char*)&bootstacktop-(char*)&bootstack
if $sp != (unsigned long)&bootstacktop
  echo FAIL stack initialization\n
  quit 1
end
if (char*)&bootstacktop-(char*)&bootstack != 8192
  echo FAIL stack size\n
  quit 1
end
hbreak kern_init
continue
printf "KERN_INIT pc=%#lx\n", $pc
hbreak memset
continue
printf "BSS start=%#lx end=%#lx dst=%#lx value=%ld length=%ld\n", &edata, &end, $a0, $a1, $a2
if $a0 != (unsigned long)&edata || $a1 != 0 || $a2 != (char*)&end-(char*)&edata
  echo FAIL BSS clear arguments\n
  quit 1
end
finish
hbreak cprintf
continue
printf "CPRINTF pc=%#lx\n", $pc
x/s $a0
hbreak *0x8020048a
continue
printf "SBI_BEFORE pc=%#lx priv=%ld a7=%ld a0=%ld\n", $pc, $priv, $a7, $a0
if $priv != 1 || $a7 != 1 || $a0 != 40
  echo FAIL SBI console arguments\n
  quit 1
end
stepi
printf "SBI_TRAP pc=%#lx priv=%ld mepc=%#lx mcause=%ld\n", $pc, $priv, $mepc, $mcause
if $priv != 3 || $mcause != 9 || $mepc != 0x8020048a
  echo FAIL S-mode ecall trap\n
  quit 1
end
printf "PASS: entry, S-mode, stack, BSS call, printf, SBI ecall\n"
detach
quit
