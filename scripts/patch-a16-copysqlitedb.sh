#!/usr/bin/env bash
# Remove the stale Android-16 keystore::copySqliteDb() call from a TWRP/OrangeFox
# recovery tree.
#
# Why: Android 16's keystore sources no longer export copySqliteDb(), so the
# inherited call is stale. The validated TB323FU TWRP baseline (fix3b) removed
# it (patches/0001-android16-remove-stale-copySqliteDb.patch) before decryption
# was confirmed working. OrangeFox's fork still carries the call -- e.g. in the
# fox_16.0 branch: twrp.cpp:251-253
#
#     #ifdef TW_INCLUDE_CRYPTO
#         android::keystore::copySqliteDb();
#     #endif
#
# This script does a context-checked removal (tolerating LF or CRLF), then
# verifies that the call is gone and the normal decryption entry point is
# untouched. Idempotent: re-running it on a patched tree is a no-op.
#
# ASCII-only on purpose (the Windows side reads BOM-less UTF-8 as ANSI).

set -euo pipefail

REC="${1:-}"
if [ -z "$REC" ]; then
    echo "usage: $0 /path/to/bootable/recovery" >&2
    exit 2
fi
[ -d "$REC" ] || { echo "ERROR: not a directory: $REC" >&2; exit 1; }

F="$REC/twrp.cpp"
[ -f "$F" ] || { echo "ERROR: missing $F" >&2; exit 1; }

python3 - "$F" <<'PY'
from pathlib import Path
import re, sys

p = Path(sys.argv[1])
src = p.read_text()

if "keystore::copySqliteDb" not in src:
    print(f"OK: {p} has no stale keystore::copySqliteDb call (already clean)")
    raise SystemExit(0)

pattern = re.compile(
    r'[ \t]*#ifdef[ \t]+TW_INCLUDE_CRYPTO\r?\n'
    r'[ \t]*android::keystore::copySqliteDb\(\);[ \t]*\r?\n'
    r'[ \t]*#endif[ \t]*\r?\n',
)
replacement = (
    "\t// Android 16 keystore sources do not export copySqliteDb().\n"
    "\t// Continue with the normal TWRP/OrangeFox decryption startup path.\n"
)
new, n = pattern.subn(replacement, src)

if n == 0:
    raise SystemExit(
        "ERROR: keystore::copySqliteDb is referenced in %s but the guarded block "
        "was not found -- inspect the file before continuing" % p
    )
if n > 1:
    raise SystemExit("ERROR: expected exactly one guarded block, found %d" % n)

p.write_text(new)
print(f"PATCHED: removed the guarded copySqliteDb block from {p}")
PY

if grep -q 'keystore::copySqliteDb' "$F"; then
    echo "ERROR: stale keystore::copySqliteDb call still present in $F" >&2
    exit 1
fi

if ! grep -q 'Decrypt_Page(skip_decryption, datamedia);' "$F"; then
    echo "ERROR: Decrypt_Page(skip_decryption, datamedia); not found - the crypto" >&2
    echo "       startup path changed unexpectedly; do not build blind." >&2
    exit 1
fi

echo "PASS: Android 16 stale copySqliteDb removed; decryption entry point intact"
