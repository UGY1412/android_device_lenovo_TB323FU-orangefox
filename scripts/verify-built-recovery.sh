#!/usr/bin/env bash
# Verify a freshly built OrangeFox recovery.img against the device-tree contract.
#
# Checks (all inside the distro, no device needed):
#   1. size <= BOARD_RECOVERYIMAGE_PARTITION_SIZE (104857600) and SHA-256 recorded
#   2. boot image unpack (AOSP unpack_bootimg), ramdisk decompress (lz4/gzip/plain),
#      cpio extract
#   3. every one of the 103 proprietary payload files is present in the ramdisk with
#      the pinned SHA-256 (or the hash recorded in proprietary-overrides.tsv)
#   4. the device contract strings survived into the ramdisk:
#      microSD + USB storage entries, Android-16 FBE/inlinecrypt params,
#      keymaster_ver=4.x, dm-default-key v2, KeyMint V4 + StrongBox declaration,
#      twrp.module.handler_done wait, no stale copySqliteDb reference
#
# Usage:  SRC=/root/fox_16.0 scripts/verify-built-recovery.sh <recovery.img> [--keep]
#
# Exit code 0 only when every check passes.

set -uo pipefail

IMG="${1:-}"
SRC="${SRC:-/root/fox_16.0}"
TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEEP=0
[ "${2:-}" = "--keep" ] && KEEP=1

die() { echo "ERROR: $*" >&2; exit 1; }
note() { echo "[verify] $*"; }

[ -n "$IMG" ] || die "usage: $0 <recovery.img> [--keep]"
[ -s "$IMG" ] || die "image not found or empty: $IMG"
[ -f "$TREE/proprietary-sources.tsv" ] || die "run from the device tree (proprietary-sources.tsv missing)"
[ -d "$SRC" ] || die "SRC is not a source checkout: $SRC"

WORK="$(mktemp -d /tmp/foxverify.XXXXXX)"
cleanup() { [ "$KEEP" -eq 1 ] || rm -rf "$WORK"; }
trap cleanup EXIT

PART_SIZE=104857600
FAILED=0
pass() { echo "  PASS  $*"; }
fail() { echo "  FAIL  $*"; FAILED=$((FAILED + 1)); }

# ---------------------------------------------------------------- 1. image file
echo "=== 1. image ==="
SIZE=$(stat -c '%s' "$IMG")
SHA=$(sha256sum "$IMG" | awk '{print $1}')
echo "  file : $IMG"
echo "  size : $SIZE bytes (limit $PART_SIZE)"
echo "  sha256: $SHA"
if [ "$SIZE" -le "$PART_SIZE" ]; then pass "size within the recovery partition"; else fail "size exceeds $PART_SIZE"; fi

# ---------------------------------------------------------------- 2. unpack
echo "=== 2. unpack ramdisk ==="
UNPACK="$SRC/system/tools/mkbootimg/unpack_bootimg.py"
[ -f "$UNPACK" ] || die "unpack_bootimg.py not found at $UNPACK"
python3 "$UNPACK" --boot_img "$IMG" --out "$WORK/boot" >/dev/null 2>&1 || die "unpack_bootimg failed"
RD="$WORK/boot/ramdisk"
[ -s "$RD" ] || die "no ramdisk extracted"
note "ramdisk archive: $(stat -c '%s' "$RD") bytes, magic $(head -c4 "$RD" | od -An -tx1 | tr -d ' ')"

CPIO="$WORK/ramdisk.cpio"
if head -c4 "$RD" | grep -q $'\x02\x21\x4c\x18' 2>/dev/null || [ "$(head -c4 "$RD" | od -An -tx1 | tr -d ' ')" = "02214c18" ]; then
    note "LZ4 (legacy or frame) ramdisk -> decompressing"
    lz4 -d -f "$RD" "$CPIO" >/dev/null 2>&1 || lz4 -d -l -f "$RD" "$CPIO" >/dev/null 2>&1 || die "lz4 decompress failed"
elif [ "$(head -c2 "$RD" | od -An -tx1 | tr -d ' ')" = "1f8b" ]; then
    note "gzip ramdisk -> decompressing"
    gzip -dc "$RD" > "$CPIO" || die "gzip decompress failed"
else
    note "uncompressed ramdisk assumed"
    cp "$RD" "$CPIO"
fi
[ -s "$CPIO" ] || die "ramdisk payload is empty"

mkdir -p "$WORK/root"
( cd "$WORK/root" && cpio -i -d --no-absolute-filenames --quiet < "$CPIO" ) || die "cpio extract failed"
FILE_COUNT=$(find "$WORK/root" -type f | wc -l)
note "extracted $FILE_COUNT files from the recovery ramdisk"
[ "$FILE_COUNT" -gt 100 ] || fail "ramdisk looks empty ($FILE_COUNT files)"

# ---------------------------------------------------------------- 3. payload files
echo "=== 3. proprietary payload (103 hash-pinned files) ==="
python3 - "$TREE/proprietary-sources.tsv" "$TREE/proprietary-overrides.tsv" "$WORK/root" <<'PY'
from pathlib import Path
import hashlib, sys

sources = Path(sys.argv[1])
overrides_file = Path(sys.argv[2])
root = Path(sys.argv[3])

lines = sources.read_text(encoding="utf-8").splitlines()
header = lines[0].split("\t")
rows = [dict(zip(header, ln.split("\t"))) for ln in lines[1:] if ln.strip()]

overrides = {}
if overrides_file.is_file():
    ol = overrides_file.read_text(encoding="utf-8").splitlines()
    oh = ol[0].split("\t")
    for ln in ol[1:]:
        if ln.strip():
            r = dict(zip(oh, ln.split("\t")))
            overrides[r["target_path"]] = r

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()

ok = pinned = substituted = missing = bad = 0
for r in rows:
    target = r["target_path"]
    rel = target[len("recovery/root/"):] if target.startswith("recovery/root/") else target
    p = root / rel
    if not p.is_file():
        print(f"  FAIL  missing from ramdisk: {rel}")
        missing += 1
        continue
    got = sha256(p)
    if got == r["expected_sha256"] and p.stat().st_size == int(r["size"]):
        ok += 1
        pinned += 1
    else:
        ov = overrides.get(target)
        if ov and ov.get("status") == "substituted" and got == ov.get("found_sha256") \
                and p.stat().st_size == int(ov.get("found_size", -1)):
            ok += 1
            substituted += 1
        else:
            print(f"  FAIL  hash mismatch: {rel} (ramdisk {got[:12]} vs pinned {r['expected_sha256'][:12]})")
            bad += 1

print(f"  payload files in ramdisk: {ok}/{len(rows)} ok "
      f"({pinned} pinned-exact, {substituted} documented substitutes), "
      f"missing={missing}, hash-mismatch={bad}")
sys.exit(0 if ok == len(rows) else 2)
PY
[ $? -eq 0 ] && pass "all 103 payload files present and verified" || fail "payload verification failed"

# ---------------------------------------------------------------- 4. contract strings
echo "=== 4. device contract inside the ramdisk ==="
check() { # label pattern file
    local label="$1" pattern="$2" file="$3"
    if [ ! -f "$file" ]; then fail "$label (file missing: ${file#$WORK/root/})"; return; fi
    if grep -qsE -- "$pattern" "$file"; then pass "$label"; else fail "$label"; fi
}

check_any() { # label pattern
    local label="$1" pattern="$2"
    if grep -rqIsE -- "$pattern" "$WORK/root" 2>/dev/null; then pass "$label"; else fail "$label (not found anywhere in ramdisk)"; fi
}

check "microSD entry in twrp.flags"            '/external_sd' "$WORK/root/system/etc/twrp.flags"
check "USB storage entry in twrp.flags"        '/usbstorage'   "$WORK/root/system/etc/twrp.flags"
check "/metadata is F2FS in twrp.flags"        '^/metadata[[:space:]]+f2fs' "$WORK/root/system/etc/twrp.flags"
check_any "Android 16 userdata FBE policy"     'fileencryption=aes-256-xts:aes-256-cts:v2\+inlinecrypt_optimized\+wrappedkey_v0'
check_any "metadata encryption policy"         'metadata_encryption=aes-256-xts:wrappedkey_v0'
check_any "dm-default-key options format v2"   'ro\.crypto\.dm_default_key\.options_format\.version=2'
check_any "keymaster_ver=4.x"                  '^keymaster_ver=4\.x'
check_any "SPU gatekeeper security level"      'vendor\.gatekeeper\.is_security_level_spu=1'
check_any "KeyMint StrongBox V4 declaration"   'IKeyMintDevice/strongbox'
check_any "twrp.module.handler_done wait"      'twrp\.module\.handler_done'
if grep -rqIs 'keystore::copySqliteDb' "$WORK/root" 2>/dev/null; then
    fail "stale copySqliteDb reference present"
else
    pass "no stale copySqliteDb reference"
fi

echo
if [ "$FAILED" -eq 0 ]; then
    echo "VERIFY-RESULT: PASS ($FILE_COUNT ramdisk files, sha256 $SHA)"
    exit 0
else
    echo "VERIFY-RESULT: FAIL ($FAILED checks failed)"
    exit 1
fi
