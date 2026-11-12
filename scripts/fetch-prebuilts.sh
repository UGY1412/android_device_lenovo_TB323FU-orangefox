#!/usr/bin/env bash
# fetch-prebuilts.sh - check and stage the six hash-pinned third-party shell
# tools used by the TB323FU recovery builds.
#
# The six tools (curl, fastfetch, git, wget, zsh, zstd) are third-party binary
# prebuilts. The normal TWRP/OrangeFox build does not rebuild them; the exact
# bytes are pinned by prebuilt-tools.tsv and their licenses/notices are kept
# under LICENSES/third-party-tools/ (see docs/THIRD_PARTY_TOOLS.md).
#
# What this script does:
#   1) verifies every target in prebuilt-tools.tsv (presence, size, SHA-256);
#   2) when something is missing or mismatched, explains how to obtain the
#      exact bytes and refuses to accept unverified replacements;
#   3) with --from-dir, stages verified files from a local directory you
#      already trust.
#
# What this script deliberately does NOT do:
#   * no network downloads (no download URL is hardcoded, because a mirror
#     could serve different bytes);
#   * it never commits anything to Git and never builds a binary;
#   * it never modifies prebuilt-tools.tsv or the expected hashes.
#
# Usage:
#   scripts/fetch-prebuilts.sh                 # verify only (default)
#   scripts/fetch-prebuilts.sh --check         # same as above
#   scripts/fetch-prebuilts.sh --from-dir DIR  # stage verified copies from DIR
#   scripts/fetch-prebuilts.sh --tree PATH     # run against another tree
#   scripts/fetch-prebuilts.sh -h | --help
#
# --from-dir DIR looks for each tool as:
#   DIR/<name>
#   DIR/prebuilts/zsh_bin/<name>
#   DIR/zsh_bin/<name>
# and copies it to <tree>/prebuilts/zsh_bin/<name> after size/SHA-256 match.
#
# Exit codes: 0 = all six present and verified, 1 = missing/mismatch,
#             2 = usage or environment error.

set -euo pipefail

TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TSV=""
FROM_DIR=""
MODE="check"

usage() {
  sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() {
  echo "ERROR: $*" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --from-dir)
      [ $# -ge 2 ] || die "--from-dir requires a directory argument"
      FROM_DIR="$2"; MODE="from-dir"; shift 2 ;;
    --tree)
      [ $# -ge 2 ] || die "--tree requires a path argument"
      TREE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (use --help)" ;;
  esac
done

TREE="$(cd "$TREE" && pwd)" || die "tree path does not exist"
TSV="$TREE/prebuilt-tools.tsv"

for c in sha256sum stat awk mkdir cp cmp; do
  command -v "$c" >/dev/null 2>&1 || die "required command missing: $c"
done
[ -f "$TSV" ] || die "missing $TSV"

EXPECTED=0
OK=0
MISSING=""
MISMATCH=""

verify_all() {
  EXPECTED=0
  OK=0
  MISSING=""
  MISMATCH=""
  while IFS=$'\t' read -r target expected_sha expected_size status rest; do
    [ "$target" != "target_path" ] || continue
    [ -n "${target:-}" ] || continue
    EXPECTED=$((EXPECTED + 1))
    path="$TREE/$target"
    if [ ! -f "$path" ]; then
      MISSING="$MISSING $target"
      continue
    fi
    actual_size="$(stat -c '%s' "$path" 2>/dev/null || stat -f '%z' "$path")"
    actual_sha="$(sha256sum "$path" | awk '{print $1}')"
    if [ "$actual_size" = "$expected_size" ] && [ "$actual_sha" = "$expected_sha" ]; then
      OK=$((OK + 1))
    else
      MISMATCH="$MISMATCH $target"
      echo "MISMATCH: $target" >&2
      echo "  expected size $expected_size / sha256 $expected_sha" >&2
      echo "  actual   size $actual_size / sha256 $actual_sha" >&2
    fi
  done < "$TSV"
}

print_guidance() {
  cat <<'GUIDANCE'

How to obtain the six third-party shell tools
---------------------------------------------
These are third-party prebuilt binaries; this repository does not rebuild them
in the normal recovery build. The exact accepted bytes are pinned in
prebuilt-tools.tsv. Obtain them from ONE of the following sources:

  1. The accompanying corresponding-source bundle:
       TB323FU-TWRP-third-party-corresponding-source-fix3b.tar.xz
       SHA-256: 49eaaf833512753260320cdc0c7263a3de16fb0ac3a9159a0815146307f6b79d
     It contains the upstream source archives, the exact Git archives, the
     resolved dependencies and the build recipes used for the inherited static
     binaries. A rebuild follows the documented ndk-pkg recipe; an exact
     byte-for-byte rebuild is NOT claimed (see docs/THIRD_PARTY_TOOLS.md).

  2. A local, already-verified staging directory. If you keep the known-good
     tool binaries from a previous validated build, point this script at it:
       scripts/fetch-prebuilts.sh --from-dir /path/to/prebuilt-cache
     Files are copied only after their size and SHA-256 match.

  3. A release asset published together with this repository, if one is
     provided by the maintainers. Verify its SHA-256 against prebuilt-tools.tsv
     before staging.

Do NOT substitute binaries from unrelated sources or rebuilds with different
toolchains and then edit prebuilt-tools.tsv to match. The pinned hashes are what
the validated recovery images were built and tested with.

Verify after staging with:
  scripts/fetch-prebuilts.sh
  scripts/verify-third-party-tools.sh

Notes:
  * This script performs no network access and adds nothing to Git.
  * Staged binaries live under prebuilts/ (tracked third-party prebuilts per
    prebuilt-tools.tsv and docs/THIRD_PARTY_TOOLS.md).
  * License/notice texts are preserved under LICENSES/third-party-tools/.
GUIDANCE
}

stage_from_dir() {
  [ -n "$FROM_DIR" ] || die "--from-dir requires a directory"
  [ -d "$FROM_DIR" ] || die "--from-dir path does not exist: $FROM_DIR"
  local staged=0
  while IFS=$'\t' read -r target expected_sha expected_size status rest; do
    [ "$target" != "target_path" ] || continue
    [ -n "${target:-}" ] || continue
    path="$TREE/$target"
    if [ -f "$path" ]; then
      actual_size="$(stat -c '%s' "$path" 2>/dev/null || stat -f '%z' "$path")"
      actual_sha="$(sha256sum "$path" | awk '{print $1}')"
      if [ "$actual_size" = "$expected_size" ] && [ "$actual_sha" = "$expected_sha" ]; then
        continue
      fi
    fi
    name="$(basename "$target")"
    candidate=""
    for c in "$FROM_DIR/$name" "$FROM_DIR/$target" "$FROM_DIR/$name.prebuilt"; do
      if [ -f "$c" ]; then candidate="$c"; break; fi
    done
    if [ -z "$candidate" ]; then
      echo "NOT FOUND in --from-dir: $name" >&2
      continue
    fi
    c_size="$(stat -c '%s' "$candidate" 2>/dev/null || stat -f '%z' "$candidate")"
    c_sha="$(sha256sum "$candidate" | awk '{print $1}')"
    if [ "$c_size" != "$expected_size" ] || [ "$c_sha" != "$expected_sha" ]; then
      echo "REFUSED (hash/size mismatch), not copying: $candidate" >&2
      continue
    fi
    mkdir -p "$(dirname "$path")"
    cp -f "$candidate" "$path"
    chmod 0755 "$path" 2>/dev/null || true
    echo "staged: $target"
    staged=$((staged + 1))
  done < "$TSV"
  echo "files staged from --from-dir: $staged"
}

verify_all

if [ "$MODE" = "from-dir" ]; then
  if [ -z "$MISSING$MISMATCH" ]; then
    echo "All $OK/$EXPECTED prebuilt tools already present and verified."
  else
    echo "Staging missing/mismatched tools from: $FROM_DIR"
    stage_from_dir
    verify_all
  fi
fi

if [ -z "$MISSING$MISMATCH" ]; then
  echo "PASS: $OK/$EXPECTED prebuilt tools present, size and SHA-256 verified."
  if [ -x "$TREE/scripts/verify-third-party-tools.sh" ]; then
    "$TREE/scripts/verify-third-party-tools.sh" "$TREE" || exit 1
  fi
  exit 0
fi

echo "" >&2
echo "prebuilt tools state: $OK/$EXPECTED verified" >&2
[ -n "$MISSING" ] && echo "missing:$MISSING" >&2
[ -n "$MISMATCH" ] && echo "mismatched:$MISMATCH" >&2
print_guidance >&2
echo "" >&2
echo "Resolve the files above and re-run: scripts/fetch-prebuilts.sh" >&2
exit 1
