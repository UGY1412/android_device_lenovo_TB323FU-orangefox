# TB323FU recovery device tree — TWRP 3.7.1 (Android 16) / OrangeFox R12.0 (fox_16.0)

Author/Maintainer: krollv, @DeepSeek V4.1 Flash 1017

Unofficial, community-maintained recovery device tree for the **Lenovo Legion
Y700 Gen 5 (TB323FU / Baldur, Qualcomm SM8850P)**.

This tree started as the validated **Android 16 TWRP 3.7.1** recovery baseline
(**fix3b**) and is also the tree used for the **OrangeFox R12.0 (fox_16.0)**
line, which adds the project's **Android 17 decryption correction** (see below).
It is not an official TeamWin or OrangeFox release and is not affiliated with,
sponsored by, or endorsed by Lenovo, Qualcomm, Google, TeamWin, or the OrangeFox
Recovery Project.

> **Warning**
>
> This project is provided **AS IS**, without warranty of any kind. Installing
> or using a custom recovery can cause data loss, an unbootable device, loss of
> access to encrypted data, security problems, or other unintended
> consequences. You are solely responsible for deciding whether to build,
> flash, modify, or use this project and for maintaining appropriate backups.
> The maintainer and contributors accept no responsibility or liability for
> damage, data loss, loss of functionality, or other consequences arising from
> its use.

Author/Maintainer: krollv, @DeepSeek V4.1 Flash 1017

Copyright (C) 2026 自恋也是种美 (krollv)

## At a glance

| Item | Value |
| --- | --- |
| Target device | Lenovo Legion Y700 Gen 5 — **TB323FU only** (codename Baldur) |
| SoC / platform | Qualcomm SM8850P (kaanapali / canoe) |
| Kernel page size | 4 KiB |
| Partition layout | A/B with a dedicated, non-slotted `recovery` partition; virtual A/B |
| Recovery partition size | 104,857,600 bytes (100 MiB) |
| Recovery source trees | TWRP-Test `twrp-16.0` manifest + polygraphene `twrp-16.0-TB322FC` recovery fork (TWRP line); OrangeFox `fox_16.0` manifest (OrangeFox line) |
| Validated custom slot | `recovery_b` (TWRP baseline); `recovery_a` was kept stock |
| UI orientation | Portrait (panel is 1904 × 3040 in portrait) |

## Verified baselines

| Build | Artifact | SHA-256 | Size | Status |
| --- | --- | --- | --- | --- |
| TWRP 3.7.1 (Android 16) fix3b | `TWRP-3.7.1-16-TB323FU-20260813-portrait-crypto-fix3b-tzdata-a16.img` | `851ec167d32b8474228a3e2864663489907c69334e9fa3a592c245a332f5ac28` | 104,857,600 B | Runtime-validated baseline; installed on `recovery_b`, `recovery_a` kept stock |
| OrangeFox R12.0 (fox_16.0) 2026-11-03 | `OrangeFox-R12.0-fox16.0-TB323FU-20261103-recovery.img` | `41528bb44e7978cb974a8af6e15a4bfe7134958eb90ea69a6837f479d0f171d8` | 104,857,600 B | Android 17 decryption + UI fixes; installed on the project device and used as a rollback anchor |
| OrangeFox R12.0 (fox_16.0) 2026-11-04 (OTA Guard) | `OrangeFox-R12.0-fox16.0-TB323FU-20261104-recovery.img` | `5cf43fbc62bd0bb4950c44e39a8b775366b90671b7623e9e0817e82419c6a129` | 104,857,600 B | Offline build; **not device-validated** (adds an in-recovery OTA helper) |
| A17 decryption experiment 2026-10-17 | `recovery_a17_crypto_fix.img` | `9550f1bfbf4a22eab2d342284f390d37de53859718d137f82bc5dc18c5fd4757` | 104,857,600 B | Offline-only historical artifact; superseded by the OrangeFox line |

See [`docs/KNOWN_GOOD.md`](docs/KNOWN_GOOD.md) for the detailed fix3b
source/runtime baseline and [`docs/PUBLICATION_STATUS.md`](docs/PUBLICATION_STATUS.md)
for what has and has not been validated for the public source release.

## Features validated on hardware

Validated on the fix3b TWRP image:

- recovery boot;
- portrait display and touch;
- normal screen blank/wake;
- external microSD;
- `/metadata` mount (F2FS);
- live Android 16 `/data` decryption and `/data/media` access;
- TWRP backup and restore;
- ADB;
- MTP;
- sideload transport;
- recovery-side diagnostic capture.

Additional OrangeFox R12.0 features shipped by the OrangeFox line (see the
release notes in the project artifacts):

- Android 17 `/data` decryption (FBE);
- built-in Magisk integration;
- Chinese UI, 24-hour clock, `CST-8` time zone defaults;
- A/B slot switching and slot state display;
- built-in file manager, partition manager and Fox add-ons;
- OTA Guard for full A/B OTA packages (2026-11-04 build; not device-validated).

## Android 17 decryption correction (historical)

The device shipped with stock Android 17 while the OrangeFox line is built from
an Android 16 recovery base. The symptom was: `/data` mounts but `/data/media`
stays empty — F2FS mounts, FBE is not unlocked.

Root cause (established by file-by-file hash comparison against Android 17
stock `vendor.img` in the project): most SPU KeyMint / onekeymint /
gatekeeper-rust files were already Android 17 versions, but the **TEE
communication chain was still Android 16 (TB322FC)** and does not match the
Android 17 TZ/SPU services. The correction replaced eight recovery-ramdisk
files with bytes from the matching Android 17 stock firmware:

| File (recovery ramdisk path) | Android 16 baseline size | Android 17 stock size |
| --- | --- | --- |
| `system/bin/qseecomd` | 69,168 B | 85,992 B |
| `system/lib64/libQSEEComAPI.so` | 85,168 B | 69,360 B |
| `system/lib64/hw/libqtigatekeeper.so` | 101,760 B | 101,912 B |
| `system/lib64/libdrmfs.so` | 101,048 B | 101,480 B |
| `system/lib64/libminkdescriptor.so` | 85,512 B | 85,976 B |
| `system/lib64/libdmabufheap.so` | 102,352 B | 102,400 B |
| `system/lib64/libion.so` | 51,232 B | 51,312 B |
| `system/lib64/libqcbor.so` | 52,024 B | 52,112 B |

The replacement is a ramdisk-level fix that was produced offline and then
carried into the OrangeFox R12.0 line, which was installed on the device in
this project. The resulting Android 17 recovery decrypts `/data` and exposes
`/data/media/0`.

Important notes for rebuilders:

- These eight files are **proprietary Lenovo/Qualcomm bytes** and are not
  distributed in this Git repository; stage them from a matching Android 17
  stock firmware you are entitled to use.
- They are **not part of the 103-file Android 16 fix3b payload** pinned by
  `proprietary-sources.tsv`. That manifest additionally documents 11
  Android-17-substituted crypto files in `proprietary-overrides.tsv`
  (`status=substituted`).
- The exact provenance/verification of the eight Android 17 TEE bytes across
  every stock firmware revision is **待验证 (to be verified)**; the file sizes
  above are the recorded per-file values.

## Proprietary files

This repository is structured so Lenovo/Qualcomm proprietary binaries are
**not committed to Git**.

`proprietary-files.tsv` records the required target path and SHA-256 for each
external file. `proprietary-sources.tsv` pins every target to either the
matching TB323FU stock firmware (`tb323fu-stock`) or the public TB322FC donor
tree (`public-tb322fc-git`). `scripts/acquire-proprietary-files.sh` stages a
locally supplied cache and refuses to install files whose hashes do not match
the manifest.

The private development cache is not part of this repository and must never be
published.

## Build

The build target is **TB323FU**. TB322FC references in this tree identify the
upstream donor/base work only; TB322FC is not the build target.

### Dependencies

| Dependency | Purpose | Notes |
| --- | --- | --- |
| Linux build host | Android/TWRP source build | Ubuntu-based distribution with a normal AOSP build environment |
| `repo`, `git`, `python3`, `sha256sum`, `rsync`, `cp`, `cmp`, `stat` | source sync + payload acquisition/verification | checked by the build scripts |
| TWRP source checkout | TWRP line | TWRP-Test `platform_manifest_twrp_aosp`, branch `twrp-16.0` |
| Recovery fork | TWRP line | polygraphene `android_bootable_recovery`, branch `twrp-16.0-TB322FC`, pinned commit `ced4ad75f311fc8a3350e21de415c23d5f0aec74` |
| OrangeFox source checkout | OrangeFox line | OrangeFox `fox_16.0` manifest |
| 103 proprietary payload files | build payload | acquired separately; never committed |
| Six shell-tool prebuilts | `curl`, `fastfetch`, `git`, `wget`, `zsh`, `zstd` | tracked third-party prebuilts pinned by `prebuilt-tools.tsv`; see `scripts/fetch-prebuilts.sh` |
| `ccache` | optional build acceleration | can be disabled with `NO_CCACHE=1` |

### TWRP line (fix3b baseline)

```bash
# 1) source checkout (historical initialization used a shallow TWRP-Test manifest)
repo init --depth=1 \
  -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp \
  -b twrp-16.0
repo sync -c --force-sync --no-clone-bundle --no-tags \
  --optimized-fetch --prune --fail-fast --retry-fetches=3 -j2

# 2) put this tree at device/lenovo/TB323FU, then prepare the 103-file payload
scripts/acquire-proprietary-files.sh --stock-root /path/to/TB323FU-stock-root

# 3) verify everything without compiling (recommended first step)
scripts/build-tb323fu-recovery.sh \
  --src /path/to/twrp-src \
  --stock-root /path/to/TB323FU-stock-root \
  --preflight-only

# 4) build
scripts/build-tb323fu-recovery.sh \
  --src /path/to/twrp-src \
  --stock-root /path/to/TB323FU-stock-root
```

The build wrapper requires a Git checkout of the device tree and never flashes
a recovery partition. Lunch target: `twrp_TB323FU-bp2a-eng`; build command:
`m -j1 recoveryimage` (the proven build used conservative parallelism and
approximately 8 GiB swap). See [`docs/BUILDING.md`](docs/BUILDING.md) and
[`docs/PROPRIETARY_FILES.md`](docs/PROPRIETARY_FILES.md).

### OrangeFox line (R12.0 / fox_16.0)

```bash
SRC=/root/fox_16.0 STOCK_ROOT=/root/stock-root \
  scripts/build-orangefox-recovery.sh --preflight-only   # validate first
SRC=/root/fox_16.0 STOCK_ROOT=/root/stock-root \
  scripts/build-orangefox-recovery.sh                    # build
```

The wrapper validates the OrangeFox-required board values (for example
`OF_DEFAULT_KEYMASTER_VERSION := 4.x`, `OF_SCREEN_H := 3040`), stages the
proprietary payload through the same acquisition script, and never flashes
anything. `JOBS` controls parallelism; `NO_CCACHE=1` disables ccache.

### Build status

The original fix3b image and the OrangeFox R12.0 line were successfully
compiled; fix3b was runtime tested and the OrangeFox 2026-11-03 build was
installed on the project device. During the public-repository cleanup a new
full TWRP compile is intentionally **not** being performed solely to validate
packaging changes.

The final public build wrapper and stock-file extraction instructions are still
being consolidated. Do not use old resume/retry scripts from earlier
development snapshots.

## Repository layout

| Path | Content |
| --- | --- |
| `BoardConfig.mk`, `device.mk`, `AndroidProducts.mk`, `twrp_TB323FU.mk`, `Android.bp`, `system.prop`, `recovery.fstab` | device configuration (AOSP/TWRP conventions; TB323FU corrections) |
| `recovery/root/` | recovery ramdisk configuration files (init rc, fstab flags, VINTF manifests, scripts); proprietary binaries are excluded by `.gitignore` |
| `patches/` | Android 16 compatibility patches applied to the recovery source (one authored in-project, two authored upstream by polygraphene) |
| `scripts/` | build wrappers, hash-pinned payload acquisition, prebuilt-tool fetch/verify and documentation checks |
| `docs/` | build, known-good, proprietary, licensing, publication, attribution and compliance documentation |
| `proprietary-files.tsv`, `proprietary-sources.tsv`, `proprietary-overrides.tsv` | hash-pinned proprietary payload manifests (no binary content) |
| `prebuilt-tools.tsv` | hash-pinned manifest of the six third-party shell-tool prebuilts |
| `LICENSES/` | Apache-2.0 text and third-party tool license/notice texts |
| `TREE_PROVENANCE.md`, `NOTICE`, `AUTHORS.md`, `CREDITS.md` | provenance, attribution and licensing information |

## Third-party material

- The six shell tools (`curl`, `fastfetch`, `git`, `wget`, `zsh`, `zstd`) are
  tracked third-party binary prebuilts. Versions, hashes, source provenance,
  notices and the accompanying corresponding-source bundle are documented in
  [`docs/THIRD_PARTY_TOOLS.md`](docs/THIRD_PARTY_TOOLS.md) and
  `LICENSES/third-party-tools/`. If they are missing from a checkout,
  `scripts/fetch-prebuilts.sh` explains how to obtain and verify them.
- `patches/0002` and `patches/0003` retain their upstream authorship and
  upstream terms.
- The repository-level mixed-origin licensing statement is in
  [`LICENSE`](LICENSE); no blanket license applies to every file.
- Full attribution is in [`CREDITS.md`](CREDITS.md),
  [`docs/ATTRIBUTION.md`](docs/ATTRIBUTION.md) and
  [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md).

## Known issues and limitations

- A full TWRP compile and device flash were **not** repeated merely to validate
  documentation, licensing cleanup, or repository packaging. The existing
  fix3b recovery remains the proven runtime baseline; a future build may differ
  byte-for-byte from the historical image.
- The OrangeFox 2026-11-04 (OTA Guard) build is an offline build and was not
  device-validated. Its release-note file records a different historical hash
  (`6518747a…`) than the produced artifact (`5cf43fbc…`); use the recomputed
  `5cf43fbc…` value and verify any downloaded copy yourself.
- Rebuilding byte-identical Android 17 OrangeFox images requires the eight
  extra Android 17 TEE bytes described above; per-file provenance beyond the
  recorded sizes is 待验证.
- The public payload acquisition path targets the validated Android 16 fix3b
  payload; Android 17-specific substitutions are documented, not guaranteed
  reproducible byte-for-byte.
- Planned post-publication work (in order): ORS / TWRP command-line behavior;
  keyboard repeat/caps behavior; File Explorer directory creation; Wi-Fi;
  Bluetooth.
- Do not use old resume/retry scripts from earlier development snapshots.

## Safety rules

- Target device: **Lenovo TB323FU only**.
- Keep an exact stock recovery backup before testing.
- Preserve a known-good recovery path.
- For first testing of a new image, flash only the intended recovery slot.
- Do not casually overwrite both recovery slots.
- Verify image hashes before flashing.
- The build workflow never flashes a recovery partition.

## Related projects and documentation

- Main project repository (LineageOS 24 / Android 17 system device tree for
  TB323FU): <https://github.com/UGY1412/android_device_lenovo_TB323FU>
  — build, flash, hardware-support, root-cause and troubleshooting
  documentation in English and Chinese under its `docs/` directory.
- Sibling AERA Recovery device tree for the same device:
  <https://github.com/UGY1412/android_device_lenovo_TB323FU-aera>
- Repository documentation index: [`docs/INDEX.md`](docs/INDEX.md)
- Known-good baseline: [`docs/KNOWN_GOOD.md`](docs/KNOWN_GOOD.md)
- Build workflow: [`docs/BUILDING.md`](docs/BUILDING.md)
- Provenance: [`TREE_PROVENANCE.md`](TREE_PROVENANCE.md)
- Attribution and compliance: [`docs/ATTRIBUTION.md`](docs/ATTRIBUTION.md),
  [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md)
- Licensing: [`docs/LICENSING.md`](docs/LICENSING.md), [`NOTICE`](NOTICE),
  [`LICENSES/`](LICENSES/)

<!-- TB323FU_PUBLICATION_DOCS_BEGIN -->
## Public build and documentation

This repository targets the **Lenovo TB323FU**. References to **TB322FC**
identify the upstream donor/base source only.

Start with the [documentation index](docs/INDEX.md). Key references include:

- [known-good fix3b baseline](docs/KNOWN_GOOD.md);
- [canonical build workflow](docs/BUILDING.md);
- [proprietary-file acquisition](docs/PROPRIETARY_FILES.md);
- [third-party recovery tools](docs/THIRD_PARTY_TOOLS.md);
- [publication/testing status](docs/PUBLICATION_STATUS.md);
- [decryption troubleshooting](docs/DECRYPTION_TROUBLESHOOTING.md).

The repository intentionally does not track the proprietary recovery payload.
The canonical acquisition script reconstructs the required 103-file payload
from hash-pinned sources and verifies every file before use.

The build workflow supports `--preflight-only` and never flashes a recovery
partition. Preserve the stock recovery slot when validating a new image.
<!-- TB323FU_PUBLICATION_DOCS_END -->

---

Copyright (C) 2026 自恋也是种美 (krollv). Original project content is provided
under the terms stated in [`NOTICE`](NOTICE), [`LICENSE`](LICENSE) and
[`docs/LICENSING.md`](docs/LICENSING.md); third-party components retain their
own licenses.
