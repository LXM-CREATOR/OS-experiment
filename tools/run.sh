#!/usr/bin/env bash
set -euo pipefail
PROJECT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT"
QEMU=${QEMU:-/usr/bin/qemu-system-riscv64}
if [[ ! -x "$QEMU" ]]; then QEMU=$(command -v qemu-system-riscv64); fi
GDB=${GDB:-$(command -v riscv64-unknown-elf-gdb || command -v gdb-multiarch || true)}
if [[ -z "$GDB" ]]; then
  GDB="$PROJECT/../../riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14/riscv64-unknown-elf-toolchain-10.2.0-2020.12.8-x86_64-linux-ubuntu14/bin/riscv64-unknown-elf-gdb"
fi
case "${1:-run}" in
  build) make -j2 ;;
  run) make qemu QEMU="$QEMU" ;;
  debug) make debug QEMU="$QEMU" ;;
  gdb) make gdb GDB="$GDB" ;;
  check) python3 tools/verify_lab1.py "$QEMU" "$GDB" ;;
  inspect)
    riscv64-unknown-elf-readelf -h -S bin/kernel
    riscv64-unknown-elf-nm -n bin/kernel
    riscv64-unknown-elf-objdump -d bin/kernel ;;
  *) echo 'Usage: bash tools/run.sh {build|run|debug|gdb|check|inspect}' >&2; exit 2 ;;
esac
