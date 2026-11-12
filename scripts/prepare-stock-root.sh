#!/usr/bin/env bash
# Build a "stock root" (an Android filesystem root such as /vendor, /system) for
# acquire-proprietary-files.sh, by loop-mounting the local TB323FU firmware
# images read-only and verifying every hash-pinned "tb323fu-stock" file.
#
# Usage:
#   scripts/prepare-stock-root.sh <images-dir> <mount-root>
#
#   <images-dir>  directory holding vendor.img, system.img, odm.img, ... (ext4,
#                 as produced by payload_dumper from the official full OTA)
#   <mount-root>  empty directory used as the merged Android root
#
# Everything is mounted read-only; nothing is written to the images.
# ASCII-only on purpose (the Windows side reads BOM-less UTF-8 as ANSI).

set -euo pipefail

IMAGES="${1:-}"
MNT="${2:-}"
TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ -n "$IMAGES" ] || { echo "usage: $0 <images-dir> <mount-root>" >&2; exit 2; }
[ -n "$MNT" ] || { echo "usage: $0 <images-dir> <mount-root>" >&2; exit 2; }
[ -d "$IMAGES" ] || { echo "ERROR: no such directory: $IMAGES" >&2; exit 1; }
[ -f "$TREE/proprietary-sources.tsv" ] || { echo "ERROR: run from the device tree" >&2; exit 1; }

mkdir -p "$MNT"

# Android partition name -> mount point under the stock root
PARTS="system system_ext product vendor odm vendor_dlkm system_dlkm"

mounted=""
cleanup() {
    for d in $mounted; do umount "$d" 2>/dev/null || true; done
}
trap cleanup EXIT

echo "=== mounting stock images from $IMAGES ==="
for p in $PARTS; do
    img="$IMAGES/$p.img"
    [ -f "$img" ] || { echo "    missing $p.img - skipped"; continue; }
    target="$MNT/$p"
    mkdir -p "$target"
    if mountpoint -q "$target" 2>/dev/null; then
        echo "    $p already mounted"
    else
        mount -o loop,ro "$img" "$target" || { echo "ERROR: mount failed for $img (need root/loop support)"; exit 1; }
        echo "    mounted $p.img -> $target"
    fi
    mounted="$mounted $target"
done

echo
echo "=== verifying hash-pinned tb323fu-stock files ==="
python3 - "$TREE/proprietary-sources.tsv" "$MNT" <<'PY'
from pathlib import Path
import hashlib, sys

tsv = Path(sys.argv[1])
root = Path(sys.argv[2])
lines = tsv.read_text().splitlines()
header = lines[0].split("\t")
rows = [dict(zip(header, ln.split("\t"))) for ln in lines[1:] if ln.strip()]
stock = [r for r in rows if r.get("acquisition") == "tb323fu-stock"]

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

ok = bad = missing = 0
for r in stock:
    rel = r["source_path"].lstrip("/")
    src = root / rel
    if not src.exists():
        print(f"MISSING  {rel}")
        missing += 1
        continue
    size = src.stat().st_size
    if size != int(r["size"]) or sha256(src) != r["expected_sha256"]:
        print(f"MISMATCH {rel} (size {size} vs {r['size']})")
        bad += 1
    else:
        ok += 1

print()
print(f"stock files: {len(stock)}  match={ok}  mismatch={bad}  missing={missing}")
print("RESULT: " + ("ALL-STOCK-FILES-MATCH" if bad == 0 and missing == 0 else "STOCK-SOURCE-INCOMPLETE"))
PY
