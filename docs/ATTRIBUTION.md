# Attribution — directory-level source mapping / 归属 — 逐目录来源映射

Last updated / 最后更新: 2026-11-12

This document maps each part of the repository to its upstream origin. The
same mapping is given in English and Chinese. It complements
[`../CREDITS.md`](../CREDITS.md) (per-project credits) and
[`COMPLIANCE.md`](COMPLIANCE.md) (inclusion/exclusion policy).

本文档把仓库的每个部分映射到其上游来源，提供英文与中文两个版本。它与
[`../CREDITS.md`](../CREDITS.md)（逐项目致谢）和 [`COMPLIANCE.md`](COMPLIANCE.md)
（收录/排除策略）互补。

## English

| Path | Content | Upstream origin | Status / notes |
| --- | --- | --- | --- |
| `BoardConfig.mk`, `device.mk`, `AndroidProducts.mk`, `twrp_TB323FU.mk`, `Android.bp`, `system.prop`, `recovery.fstab` | Device configuration | Derived from the baseline TB323FU TWRP device tree (isrgish/TB323FU-TWRP lineage) and AOSP/TWRP device-tree conventions; TB323FU-specific corrections were made for Android 16/17 | Apache-2.0 SPDX headers on inherited files; project corrections are provided under the project terms in `NOTICE` |
| `recovery/root/` (text files: init rc, `twrp.flags`, VINTF manifests, scripts) | Recovery ramdisk configuration | Baseline device tree lineage (isrgish/TB323FU-TWRP / polygraphene TB322FC) with TB323FU corrections; proprietary binaries under these paths are excluded by `.gitignore` | Per-file notices retained; no proprietary bytes committed |
| `recovery/root/` proprietary targets listed in `.gitignore` and `proprietary-files.tsv` | Lenovo/Qualcomm proprietary services, libraries and firmware | Acquired separately: 25 files from matching TB323FU stock firmware, 78 from public polygraphene TB322FC Git history (`c9c6a9f1287e5b416c3480c5fe06b23dc54c9ab8`) | Not distributed; builders must obtain them lawfully |
| `patches/0001-android16-remove-stale-copySqliteDb.patch` | Android 16 compatibility patch | Project-authored adaptation of upstream Android 16 recovery code | Upstream (AOSP/TWRP) terms apply to the patched code |
| `patches/0002-tb323fu-wait-module-handler-done.patch` | Recovery fix | Authored upstream by polygraphene (retains `From:`/`Subject:` headers) | Upstream author and terms retained |
| `patches/0003-tb323fu-dynamic-thermal-zone.patch` | Recovery fix | Authored upstream by polygraphene (retains `From:`/`Subject:` headers) | Upstream author and terms retained |
| `scripts/` | Build wrappers, payload acquisition/verification, prebuilt-tool fetch/verify, documentation checks | Project-authored | Project terms; third-party tool license texts under `LICENSES/third-party-tools/` |
| `proprietary-files.tsv`, `proprietary-sources.tsv`, `proprietary-overrides.tsv`, `prebuilt-tools.tsv` | Hash-pinned manifests (paths, sizes, SHA-256; no binary content) | Project-authored from provenance research | Project terms |
| `docs/`, `README.md`, `README.zh-CN.md`, `AUTHORS.md`, `CREDITS.md`, `NOTICE`, `TREE_PROVENANCE.md` | Documentation | Project-authored; some inherited baseline documentation was written for the validated fix3b tree | Project terms; see `NOTICE` |
| `LICENSES/Apache-2.0.txt` | Apache-2.0 license text | Apache Software Foundation | Verbatim license text |
| `LICENSES/third-party-tools/` | License/notice texts for the six prebuilt shell tools | Upstream curl, fastfetch, git, wget, zsh, zstd projects and their dependencies | Verbatim notices; see `NOTICE-SOURCE-MAP.tsv` |
| `prebuilts/` (when present) | Six tracked third-party shell-tool binaries | Third-party upstream projects (see `docs/THIRD_PARTY_TOOLS.md`) | Pinned by `prebuilt-tools.tsv`; license texts under `LICENSES/third-party-tools/` |
| `THIRD_PARTY_SOURCE_BUNDLE.sha256` | Checksum pointer to the corresponding-source bundle | Project-authored / third-party sources | See `docs/THIRD_PARTY_TOOLS.md` |

## 中文

| 路径 | 内容 | 上游来源 | 状态 / 说明 |
| --- | --- | --- | --- |
| `BoardConfig.mk`、`device.mk`、`AndroidProducts.mk`、`twrp_TB323FU.mk`、`Android.bp`、`system.prop`、`recovery.fstab` | 设备配置 | 衍生自 TB323FU TWRP 设备树基线（isrgish/TB323FU-TWRP 传承）与 AOSP/TWRP 设备树约定；针对 Android 16/17 做了 TB323FU 专用修正 | 继承文件保留 Apache-2.0 SPDX 头；本项目修正按 `NOTICE` 所述项目条款提供 |
| `recovery/root/`（文本文件：init rc、`twrp.flags`、VINTF manifest、脚本） | recovery ramdisk 配置 | 基线设备树传承（isrgish/TB323FU-TWRP / polygraphene TB322FC）加 TB323FU 修正；这些路径下的专有二进制已被 `.gitignore` 排除 | 保留逐文件声明；不提交任何专有字节 |
| `.gitignore` 与 `proprietary-files.tsv` 中列出的 `recovery/root/` 专有目标 | 联想/高通专有服务、库与固件 | 另行获取：25 个来自配套 TB323FU 原厂固件，78 个来自公开的 polygraphene TB322FC Git 历史（`c9c6a9f1287e5b416c3480c5fe06b23dc54c9ab8`） | 不分发；构建者须合法获取 |
| `patches/0001-android16-remove-stale-copySqliteDb.patch` | Android 16 兼容补丁 | 本项目基于上游 Android 16 recovery 代码所做适配 | 被修改代码适用上游（AOSP/TWRP）条款 |
| `patches/0002-tb323fu-wait-module-handler-done.patch` | recovery 修复 | 上游作者为 polygraphene（保留 `From:`/`Subject:` 头） | 保留上游作者与条款 |
| `patches/0003-tb323fu-dynamic-thermal-zone.patch` | recovery 修复 | 上游作者为 polygraphene（保留 `From:`/`Subject:` 头） | 保留上游作者与条款 |
| `scripts/` | 构建封装、payload 获取/校验、预编译工具获取/校验、文档校验 | 本项目编写 | 项目条款；第三方工具许可原文见 `LICENSES/third-party-tools/` |
| `proprietary-files.tsv`、`proprietary-sources.tsv`、`proprietary-overrides.tsv`、`prebuilt-tools.tsv` | 哈希锁定清单（路径、大小、SHA-256；不含二进制内容） | 本项目基于来源研究编写 | 项目条款 |
| `docs/`、`README.md`、`README.zh-CN.md`、`AUTHORS.md`、`CREDITS.md`、`NOTICE`、`TREE_PROVENANCE.md` | 文档 | 本项目编写；部分继承的基线文档是为已验证的 fix3b 树所写 | 项目条款；见 `NOTICE` |
| `LICENSES/Apache-2.0.txt` | Apache-2.0 许可原文 | Apache Software Foundation | 逐字许可原文 |
| `LICENSES/third-party-tools/` | 六个预编译 shell 工具的许可/声明原文 | 上游 curl、fastfetch、git、wget、zsh、zstd 项目及其依赖 | 逐字声明；见 `NOTICE-SOURCE-MAP.tsv` |
| `prebuilts/`（存在时） | 六个随仓库跟踪的第三方 shell 工具二进制 | 第三方上游项目（见 `docs/THIRD_PARTY_TOOLS.md`） | 由 `prebuilt-tools.tsv` 锁定；许可原文见 `LICENSES/third-party-tools/` |
| `THIRD_PARTY_SOURCE_BUNDLE.sha256` | 对应源码包校验指针 | 本项目编写 / 第三方源码 | 见 `docs/THIRD_PARTY_TOOLS.md` |

## Remarks / 备注

- The `.gitignore` file lists the exact proprietary target paths that must not
  be committed. Do not weaken it. / `.gitignore` 列出了不得提交的专有目标路径，
  不要放宽它。
- Repository-level licensing: `LICENSE` (mixed-origin) and
  `docs/LICENSING.md`. / 仓库级许可：`LICENSE`（混合来源）与
  `docs/LICENSING.md`。
- No binary file is added by the documentation/compliance work documented here.
  / 本文档/合规工作不新增任何二进制文件。
