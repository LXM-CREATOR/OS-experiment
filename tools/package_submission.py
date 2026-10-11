#!/usr/bin/env python3
"""Package the final Lab1 source, report and original verification logs."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

PROJECT = Path(__file__).resolve().parents[1]
OS_ROOT = PROJECT.parents[1]
OUTPUT = OS_ROOT / 'Lab1_提交包.zip'
SKIP = {'bin', 'obj', '__pycache__', '.git'}

with ZipFile(OUTPUT, 'w', compression=ZIP_DEFLATED) as archive:
    for path in sorted(PROJECT.rglob('*')):
        relative = path.relative_to(PROJECT)
        if not path.is_file() or any(part in SKIP for part in relative.parts):
            continue
        if path.suffix in {'.pyc', '.zip', '.tar', '.gz'}:
            continue
        archive.write(path, 'labcodes/lab1/' + relative.as_posix())
    instructions = OS_ROOT / 'Lab1_提交说明.md'
    if instructions.is_file():
        archive.write(instructions, instructions.name)

with ZipFile(OUTPUT) as archive:
    assert archive.testzip() is None, 'Damaged ZIP archive'
    assert 'labcodes/lab1/实验报告.md' in archive.namelist()
    assert 'labcodes/lab1/logs/gdb.log' in archive.namelist()
    print(f'Created: {OUTPUT}')
    print(f'Files: {len(archive.namelist())}')
