#!/usr/bin/env bash
# Build OrangeFox R12 (fox_16.0) for the Lenovo TB323FU.
#
# Device tree: this directory (device/lenovo/TB323FU), derived from the validated
# TWRP baseline isrgish/TB323FU-TWRP plus the OrangeFox variables listed in
# BoardConfig.mk.
#
# Source tree: the official OrangeFox Android 16 manifest
# (gitlab.com/OrangeFox/Manifest, branch fox_16.0), synced into $SRC.
#
# Usage:
#   SRC=/root/fox_16.0 STOCK_ROOT=/root/stock-root \
#       scripts/build-orangefox-recovery.sh [--preflight-only] [--skip-acquire]
#
# Env knobs:
#   SRC            source checkout           (default /root/fox_16.0)
#   STOCK_ROOT     extracted TB323FU stock   (required unless --skip-acquire)
#   ARTIFACTS      output dir for the image  (default <tree>/../../artifacts)
#   JOBS           ninja parallelism         (default 8; fall back to 4 or 1 if OOM)
#   NO_CCACHE=1    disable ccache
#
# This script never flashes anything.
#
# ASCII-only on purpose (the Windows side reads BOM-less UTF-8 as ANSI).

set -eo pipefail   # Android's envsetup is not compatible with set -u

TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${SRC:-/root/fox_16.0}"
STOCK_ROOT="${STOCK_ROOT:-}"
DEVICE="TB323FU"
DEVICE_PATH="device/lenovo/TB323FU"
PARTITION_SIZE=104857600
JOBS="${JOBS:-8}"
ARTIFACTS="${ARTIFACTS:-$(cd "$TREE/../.." && pwd)/artifacts}"
PREFLIGHT_ONLY=0
DO_ACQUIRE=1
# Optional local clone of the donor repository
# (polygraphene/android_device_lenovo_TB322FC). GitHub is intermittently blocked on
# this network, so the acquire step can take a prepared clone instead of cloning.
UPSTREAM_DIR="${UPSTREAM_DIR:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --preflight-only) PREFLIGHT_ONLY=1; shift ;;
        --skip-acquire)   DO_ACQUIRE=0; shift ;;
        -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "required command missing: $1"; }

for c in git python3 sha256sum rsync grep sed awk find stat cp cmp; do need "$c"; done

mkdir -p "$ARTIFACTS"
RUN_ID="$(date -u +%Y%m%d-%H%M%S)"
LOG="$ARTIFACTS/build-fox16-$RUN_ID.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== OrangeFox R12 (fox_16.0) build for $DEVICE ==="
echo "tree      : $TREE"
echo "source    : $SRC"
echo "artifacts : $ARTIFACTS"
echo "log       : $LOG"

echo "[1/9] sanity checks"
for f in BoardConfig.mk device.mk AndroidProducts.mk twrp_TB323FU.mk recovery.fstab system.prop; do
    [ -f "$TREE/$f" ] || die "device tree file missing: $f"
done
[ -d "$TREE/recovery/root" ] || die "device tree recovery/root missing"
grep -qE '^OF_DEFAULT_KEYMASTER_VERSION[[:space:]]*:=[[:space:]]*4\.x' "$TREE/BoardConfig.mk" ||
    die "OF_DEFAULT_KEYMASTER_VERSION := 4.x is required by OrangeFox when TW_FORCE_KEYMASTER_VER=true"
grep -qE '^TW_FORCE_KEYMASTER_VER[[:space:]]*:=[[:space:]]*true' "$TREE/BoardConfig.mk" ||
    die "TW_FORCE_KEYMASTER_VER := true missing from the device tree"
grep -qE '^OF_SCREEN_H[[:space:]]*:=[[:space:]]*3040' "$TREE/BoardConfig.mk" ||
    die "OF_SCREEN_H := 3040 missing (panel is 1904x3040 in portrait)"
[ -d "$SRC/build" ] || die "not an Android source checkout: $SRC"

echo "[2/9] proprietary payload (103 hash-pinned files)"
# acquire-proprietary-files.sh refuses to run outside a Git checkout, and it writes
# the staged blobs into the tree it is given. So work on a writable Linux-side copy
# (git init'd) instead of the workspace tree on /mnt/d: the upstream script contract
# is preserved, the real device tree stays clean, and blob I/O stays on ext4.
WORK_TREE="${WORK_TREE:-$(dirname "$SRC")/tb323fu-worktree}"
if [ "$DO_ACQUIRE" -eq 1 ]; then
    [ -n "$STOCK_ROOT" ] || die "STOCK_ROOT is required (use --skip-acquire to reuse an already staged tree)"
    echo "    working copy: $WORK_TREE"
    mkdir -p "$WORK_TREE"
    rsync -a --delete --exclude '.git' --exclude 'build-artifacts' --exclude '.build-out' \
        "$TREE/" "$WORK_TREE/"
    # Windows checkouts are CRLF, which breaks bash heredocs, init .rc parsing and
    # fstab. Normalise before anything runs out of this tree.
    python3 "$WORK_TREE/scripts/normalize_line_endings.py" "$WORK_TREE" --quiet
    if [ ! -d "$WORK_TREE/.git" ]; then
        git -C "$WORK_TREE" init -q
        git -C "$WORK_TREE" config user.name  "tb323fu-port"
        git -C "$WORK_TREE" config user.email "port@localhost"
    fi
    if [ -n "$UPSTREAM_DIR" ]; then
        echo "    donor repo: $UPSTREAM_DIR"
        "$WORK_TREE/scripts/acquire-proprietary-files.sh" --tree "$WORK_TREE" \
            --stock-root "$STOCK_ROOT" --upstream-dir "$UPSTREAM_DIR"
    else
        "$WORK_TREE/scripts/acquire-proprietary-files.sh" --tree "$WORK_TREE" --stock-root "$STOCK_ROOT"
    fi
    SRC_TREE="$WORK_TREE"
else
    SRC_TREE="$TREE"
    echo "    skipped (--skip-acquire)"
fi
[ -f "$SRC_TREE/recovery/root/system/lib64/libspukeymint.so" ] ||
    die "SPU KeyMint payload not staged - decryption would fail at runtime"

echo "[3/9] install device tree into $SRC/$DEVICE_PATH"
# Content-based sync, NOT delete-and-recopy: Soong's analysis is invalidated by
# mtime changes, and re-analysing this tree costs 50-60 minutes on this machine
# (measured 2026-10-08). With --checksum/cmp only genuinely changed files are
# touched, so a rerun of an unchanged tree goes straight to compiling.
DEVICE_DIR="$SRC/$DEVICE_PATH"
mkdir -p "$DEVICE_DIR"
for f in Android.bp AndroidProducts.mk BoardConfig.mk device.mk recovery.fstab system.prop twrp_TB323FU.mk; do
    if [ ! -f "$DEVICE_DIR/$f" ] || ! cmp -s "$SRC_TREE/$f" "$DEVICE_DIR/$f"; then
        cp -a "$SRC_TREE/$f" "$DEVICE_DIR/"
    fi
done
rsync -a --checksum "$SRC_TREE/recovery/" "$DEVICE_DIR/recovery/"
rsync -a --checksum "$SRC_TREE/prebuilts/" "$DEVICE_DIR/prebuilts/"

echo "[4/9] stage Android 16 tzdata"
TZDATA_SRC="$(find "$SRC/system/timezone" -type f -path '*/output_data/iana/tzdata' -print -quit 2>/dev/null || true)"
TZDATA_DST="$DEVICE_DIR/recovery/root/system/usr/share/zoneinfo/tzdata"
if [ -n "$TZDATA_SRC" ] && [ -s "$TZDATA_SRC" ]; then
    mkdir -p "$(dirname "$TZDATA_DST")"
    cp -f "$TZDATA_SRC" "$TZDATA_DST"
    cmp -s "$TZDATA_SRC" "$TZDATA_DST" || die "staged tzdata differs from AOSP source"
    echo "    staged $(sha256sum "$TZDATA_DST" | awk '{print $1}')"
else
    echo "    WARN: AOSP output_data/iana/tzdata not found; timezone display may be limited"
fi

echo "[5/9] Android 16 recovery fixes"
"$SRC_TREE/scripts/patch-a16-copysqlitedb.sh" "$SRC/bootable/recovery"
python3 "$SRC_TREE/scripts/port_tb323fu_fixes.py" "$SRC/bootable/recovery"
MAGISK_DIR="$SRC/external/magisk-prebuilt"
[ -d "$MAGISK_DIR" ] || die "external/magisk-prebuilt missing (OrangeFox needs magiskboot for boot patch/repack)"
"$SRC_TREE/scripts/apply-magiskboot-4k-exception.sh" "$MAGISK_DIR"

echo "[6/9] static assertions"
grep -q 'twrp_TB323FU-bp2a-eng' "$DEVICE_DIR/AndroidProducts.mk" || die "bp2a lunch choice missing"
grep -qE '^PRODUCT_DEVICE[[:space:]]*:=[[:space:]]*TB323FU' "$DEVICE_DIR/twrp_TB323FU.mk" || die "PRODUCT_DEVICE is not TB323FU"
grep -qE '^PRODUCT_MODEL[[:space:]]*:=[[:space:]]*TB323FU' "$DEVICE_DIR/twrp_TB323FU.mk" || die "PRODUCT_MODEL is not TB323FU"
! grep -q 'TW_NO_SCREEN_BLANK' "$DEVICE_DIR/BoardConfig.mk" || die "screen blanking must stay enabled"
grep -Rqs --include='*.xml' 'IKeyMintDevice/strongbox' "$DEVICE_DIR/recovery/root" || die "StrongBox KeyMint declaration missing"
grep -Rqs --include='*.xml' '<version>[[:space:]]*4[[:space:]]*</version>' "$DEVICE_DIR/recovery/root" || die "KeyMint V4 declaration missing"
grep -q '/external_sd' "$DEVICE_DIR/recovery/root/system/etc/twrp.flags" || die "microSD entry missing from twrp.flags"
grep -q '/usbstorage' "$DEVICE_DIR/recovery/root/system/etc/twrp.flags" || die "USB storage entry missing from twrp.flags"

if grep -q '^TW_NO_SCREEN_BLANK' "$DEVICE_DIR/BoardConfig.mk"; then die "TW_NO_SCREEN_BLANK must not be set"; fi
echo "    all static assertions passed"

if [ "$PREFLIGHT_ONLY" -eq 1 ]; then
    echo "PREFLIGHT-OK (no compile invoked)"
    exit 0
fi

echo "[7/9] lunch"
cd "$SRC"
export ALLOW_MISSING_DEPENDENCIES=true
export FOX_BUILD_DEVICE="$DEVICE"
export FOX_TARGET_DEVICES="$DEVICE"
export OUT_DIR="${OUT_DIR:-out}"
export GOMAXPROCS="${GOMAXPROCS:-2}"
export GOGC="${GOGC:-10}"
export GOMEMLIMIT="${GOMEMLIMIT:-6GiB}"
export CCACHE_DIR="${CCACHE_DIR:-/root/.ccache}"
export CCACHE_EXEC="${CCACHE_EXEC:-$(command -v ccache || true)}"
export CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-30G}"
# ccache stays OFF by default, exactly like the validated baseline (isrgish's build
# script also sets USE_CCACHE=0). AOSP runs C++ actions inside Soong's sbox sandbox,
# which exposes /root read-only, so ccache cannot create $CCACHE_DIR/tmp and kills
# the build with a misleading
#   "ccache: error: Failed to create directory /root/.ccache/tmp: Read-only file system"
# Seen 2026-10-08 twice, always at target 21/23368 (the first C++ action). The guest
# filesystem is fine: dmesg shows no ext4 error and no read-only remount.
# Opt in with CCACHE_ENABLE=1.
if [ "${CCACHE_ENABLE:-0}" = "1" ] && [ -n "$CCACHE_EXEC" ]; then
    mkdir -p "$CCACHE_DIR" 2>/dev/null || true
    if touch "$CCACHE_DIR/.write-test" 2>/dev/null; then
        rm -f "$CCACHE_DIR/.write-test"
        export USE_CCACHE=1
        echo "    ccache: enabled by request (dir=$CCACHE_DIR, max=$CCACHE_MAXSIZE)"
    else
        export USE_CCACHE=0
        echo "    WARN: ccache dir not writable ($CCACHE_DIR) - continuing without ccache"
    fi
else
    export USE_CCACHE=0
    echo "    ccache: disabled (baseline setting; Soong's sbox cannot write $CCACHE_DIR)"
fi
unset USE_LANDSCAPE

set +e
source build/envsetup.sh
lunch "twrp_${DEVICE}-bp2a-eng"
rc=$?
set -e
[ "$rc" -eq 0 ] || die "lunch failed ($rc)"
[ "${TARGET_PRODUCT:-}" = "twrp_${DEVICE}" ] || die "unexpected TARGET_PRODUCT=${TARGET_PRODUCT:-unset}"
echo "    TARGET_PRODUCT=$TARGET_PRODUCT"

echo "[8/9] build recoveryimage with -j$JOBS (this is the long step)"
set +e
m -j"$JOBS" recoveryimage 2>&1 | tee "$ARTIFACTS/recovery-build-$RUN_ID.log"
BUILD_RC=${PIPESTATUS[0]}
set -e
[ "$BUILD_RC" -eq 0 ] || die "build failed ($BUILD_RC) - see $ARTIFACTS/recovery-build-$RUN_ID.log"

echo "[9/9] collect artifact"
IMAGE="$SRC/$OUT_DIR/target/product/$DEVICE/recovery.img"
[ -s "$IMAGE" ] || die "build produced no recovery.img at $IMAGE"
IMAGE_SIZE="$(stat -c '%s' "$IMAGE")"
echo "    raw recovery.img size: $IMAGE_SIZE bytes (partition limit $PARTITION_SIZE)"
[ "$IMAGE_SIZE" -le "$PARTITION_SIZE" ] || die "recovery.img exceeds the 104857600-byte recovery partition"

OUT_IMAGE="$ARTIFACTS/OrangeFox-R12.0-fox16.0-${DEVICE}-$(date -u +%Y%m%d)-recovery.img"
cp -f "$IMAGE" "$OUT_IMAGE"
sha256sum "$OUT_IMAGE" | tee "$OUT_IMAGE.sha256"
echo "OF-BUILD-OK"
echo "image: $OUT_IMAGE"
echo "This script never flashes recovery."
