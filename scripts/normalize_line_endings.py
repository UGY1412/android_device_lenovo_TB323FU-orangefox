#!/usr/bin/env python3
"""Normalise line endings of text files to LF (Windows checkouts of this device
tree come with CRLF, which breaks bash heredocs, init .rc parsing and fstab).

Only files with known text extensions are touched - never binaries (the tree ships
ELF prebuilts such as prebuilts/zsh_bin/* and prebuilts/avbtool is a script).

Usage:
    python normalize_line_endings.py <directory> [--check-only]

Exit code 0 when everything is LF (or was converted), 1 when --check-only found
CRLF files.
"""

import argparse
import sys
from pathlib import Path

TEXT_SUFFIXES = {
    ".sh", ".py", ".mk", ".bp", ".md", ".txt", ".tsv", ".prop", ".rc", ".xml",
    ".fstab", ".json", ".yaml", ".yml", ".conf", ".ini", ".service", ".cfg",
}

TEXT_NAMES = {
    "NOTICE", "LICENSE", "README", "OWNERS", "avbtool", "Android.bp",
    "Android.mk", "AndroidProducts.mk", "BoardConfig.mk", "device.mk",
    "recovery.fstab", "system.prop", ".gitignore", ".gitattributes",
}


def is_text(path: Path) -> bool:
    if path.suffix.lower() in TEXT_SUFFIXES:
        return True
    if path.name in TEXT_NAMES:
        return True
    # BOM-less files with no suffix that look like scripts
    if path.suffix == "" and path.name.startswith(("NOTICE", "LICENSE")):
        return True
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("directory")
    ap.add_argument("--check-only", action="store_true", help="report CRLF files without modifying them")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    root = Path(args.directory)
    if not root.is_dir():
        raise SystemExit(f"not a directory: {root}")

    changed = []
    checked = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file() or ".git" in path.parts:
            continue
        if not is_text(path):
            continue
        checked += 1
        data = path.read_bytes()
        if b"\r\n" not in data:
            continue
        if args.check_only:
            changed.append(path)
            continue
        path.write_bytes(data.replace(b"\r\n", b"\n"))
        changed.append(path)

    if not args.quiet:
        for p in changed:
            print(f"{'CRLF  ' if args.check_only else 'fixed '} {p.relative_to(root)}")
    print(f"\ntext files checked: {checked}; CRLF files {'found' if args.check_only else 'converted'}: {len(changed)}")
    if args.check_only and changed:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
