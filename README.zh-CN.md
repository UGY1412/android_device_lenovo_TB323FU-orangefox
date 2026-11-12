# TB323FU recovery 设备树 — TWRP 3.7.1（Android 16）/ OrangeFox R12.0（fox_16.0）

作者/维护者：自恋也是种美，@DeepSeek V4.1 Flash 1017

面向 **联想拯救者 Y700 五代（TB323FU / Baldur，高通 SM8850P）** 的非官方社区维护
recovery 设备树。

本设备树最初是已验证的 **Android 16 TWRP 3.7.1** recovery 基线（**fix3b**），
同时也是 **OrangeFox R12.0（fox_16.0）** 产品线所用的设备树；后者加入了本项目的
**Android 17 解密修正**（见下文）。本项目不是 TeamWin 或 OrangeFox 的官方发布，
与 Lenovo、Qualcomm、Google、TeamWin、OrangeFox Recovery Project 均无隶属、
赞助或背书关系。

> **警告**
>
> 本项目按 **“现状（AS IS）”** 提供，不附带任何形式的担保。安装或使用第三方
> recovery 可能造成数据丢失、设备无法启动、失去对加密数据的访问、安全问题或
> 其他非预期后果。是否构建、刷入、修改或使用本项目，以及是否做好备份，完全由你
> 自行决定并自行负责。维护者与贡献者对因使用本项目造成的损坏、数据丢失、功能
> 丧失或其他后果不承担任何责任。

作者/维护者：自恋也是种美，@DeepSeek V4.1 Flash 1017

Copyright (C) 2026 自恋也是种美 (krollv)

## 概览

| 项目 | 值 |
| --- | --- |
| 目标设备 | 联想拯救者 Y700 五代 — **仅 TB323FU**（代号 Baldur） |
| SoC / 平台 | 高通 SM8850P（kaanapali / canoe） |
| 内核页大小 | 4 KiB |
| 分区布局 | A/B + 独立、非分槽的 `recovery` 分区；virtual A/B |
| recovery 分区大小 | 104,857,600 字节（100 MiB） |
| recovery 源码树 | TWRP 线：TWRP-Test `twrp-16.0` manifest + polygraphene `twrp-16.0-TB322FC` recovery 分支；OrangeFox 线：OrangeFox `fox_16.0` manifest |
| 已验证的自定义槽位 | `recovery_b`（TWRP 基线）；`recovery_a` 保持原厂 |
| UI 方向 | 竖屏（面板竖屏尺寸 1904 × 3040） |

## 已验证基线

| 构建 | 产物 | SHA-256 | 大小 | 状态 |
| --- | --- | --- | --- | --- |
| TWRP 3.7.1（Android 16）fix3b | `TWRP-3.7.1-16-TB323FU-20260813-portrait-crypto-fix3b-tzdata-a16.img` | `851ec167d32b8474228a3e2864663489907c69334e9fa3a592c245a332f5ac28` | 104,857,600 B | 已真机运行验证的基线；刷入 `recovery_b`，`recovery_a` 保持原厂 |
| OrangeFox R12.0（fox_16.0）2026-11-03 | `OrangeFox-R12.0-fox16.0-TB323FU-20261103-recovery.img` | `41528bb44e7978cb974a8af6e15a4bfe7134958eb90ea69a6837f479d0f171d8` | 104,857,600 B | Android 17 解密 + UI 修正；已刷入项目设备，并作为回退锚点 |
| OrangeFox R12.0（fox_16.0）2026-11-04（OTA Guard） | `OrangeFox-R12.0-fox16.0-TB323FU-20261104-recovery.img` | `5cf43fbc62bd0bb4950c44e39a8b775366b90671b7623e9e0817e82419c6a129` | 104,857,600 B | 离线构建；**未经真机验证**（新增 recovery 内 OTA 辅助功能） |
| A17 解密实验件 2026-10-17 | `recovery_a17_crypto_fix.img` | `9550f1bfbf4a22eab2d342284f390d37de53859718d137f82bc5dc18c5fd4757` | 104,857,600 B | 仅离线产出的历史产物；已被 OrangeFox 产品线取代 |

fix3b 源码/运行基线的详细说明见 [`docs/KNOWN_GOOD.md`](docs/KNOWN_GOOD.md)；
本次公开源码发布“已验证/未验证”清单见
[`docs/PUBLICATION_STATUS.md`](docs/PUBLICATION_STATUS.md)。

## 已真机验证的功能

在 fix3b TWRP 镜像上验证通过：

- recovery 启动；
- 竖屏显示与触摸；
- 正常息屏/唤醒；
- 外置 microSD；
- `/metadata` 挂载（F2FS）；
- Android 16 `/data` 在线解密与 `/data/media` 访问；
- TWRP 备份与恢复；
- ADB；
- MTP；
- sideload 传输；
- recovery 侧诊断信息采集。

OrangeFox R12.0 产品线额外提供以下功能（详见项目产物中的发布说明）：

- Android 17 `/data` 解密（FBE）；
- 内置 Magisk 集成；
- 中文界面、24 小时制、`CST-8` 时区默认值；
- A/B 槽位切换与槽位状态显示；
- 内置文件管理器、分区管理器与 Fox 插件；
- OTA Guard：A/B 全量 OTA 包支持（2026-11-04 构建；未经真机验证）。

## Android 17 解密修正（历史说明）

设备出厂为原厂 Android 17，而 OrangeFox 产品线基于 Android 16 recovery 基线
构建。故障现象是：`/data` 能挂载，但 `/data/media` 为空 —— 即 F2FS 挂上了、
FBE 没有解开。

根因（本项目通过对原厂 Android 17 `vendor.img` 逐文件哈希比对确认）：大部分
SPU KeyMint / onekeymint / gatekeeper-rust 文件已经是 Android 17 版本，但
**TEE 通信链仍是 Android 16（TB322FC）版本**，与 Android 17 的 TZ/SPU 服务
不配套。修正方式是把 recovery ramdisk 内的 8 个文件替换为配套 Android 17
原厂固件中的字节：

| 文件（recovery ramdisk 内路径） | Android 16 基线大小 | Android 17 原厂大小 |
| --- | --- | --- |
| `system/bin/qseecomd` | 69,168 B | 85,992 B |
| `system/lib64/libQSEEComAPI.so` | 85,168 B | 69,360 B |
| `system/lib64/hw/libqtigatekeeper.so` | 101,760 B | 101,912 B |
| `system/lib64/libdrmfs.so` | 101,048 B | 101,480 B |
| `system/lib64/libminkdescriptor.so` | 85,512 B | 85,976 B |
| `system/lib64/libdmabufheap.so` | 102,352 B | 102,400 B |
| `system/lib64/libion.so` | 51,232 B | 51,312 B |
| `system/lib64/libqcbor.so` | 52,024 B | 52,112 B |

该替换属于 ramdisk 层修正，先离线产出，随后进入 OrangeFox R12.0 产品线，并
在本项目中刷入真机。修正后的 Android 17 recovery 能解开 `/data` 并访问
`/data/media/0`。

重建者须知：

- 这 8 个文件是 **联想/高通的专有字节**，不在本 Git 仓库中分发；请从你有权
  使用的、配套的 Android 17 原厂固件中获取并暂存。
- 它们**不属于** `proprietary-sources.tsv` 锁定的 103 个 Android 16 fix3b
  payload；该清单另在 `proprietary-overrides.tsv` 中以
  `status=substituted` 记录了 11 个 Android 17 替代的 crypto 文件。
- 这 8 个 Android 17 TEE 字节在**每一个**原厂固件版本上的精确来源与校验
  仍为 **待验证**；表中大小是记录到的逐文件数值。

## 专有文件

本仓库的组织方式保证联想/高通专有二进制**不提交进 Git**。

`proprietary-files.tsv` 记录每个外部文件的目标路径与 SHA-256。
`proprietary-sources.tsv` 把每个目标锁定到“配套 TB323FU 原厂固件
（`tb323fu-stock`）”或“公开的 TB322FC donor 树（`public-tb322fc-git`）”。
`scripts/acquire-proprietary-files.sh` 会暂存本地提供的缓存，并拒绝安装哈希与
清单不符的文件。

私有开发缓存不属于本仓库，且绝不可公开发布。

## 构建

构建目标是 **TB323FU**。本设备树中出现的 TB322FC 仅指上游 donor/基线来源；
TB322FC 不是构建目标。

### 依赖

| 依赖 | 用途 | 说明 |
| --- | --- | --- |
| Linux 构建主机 | Android/TWRP 源码构建 | 基于 Ubuntu、具备常规 AOSP 构建环境的发行版 |
| `repo`、`git`、`python3`、`sha256sum`、`rsync`、`cp`、`cmp`、`stat` | 源码同步 + payload 获取/校验 | 构建脚本会检查 |
| TWRP 源码检出 | TWRP 线 | TWRP-Test `platform_manifest_twrp_aosp`，分支 `twrp-16.0` |
| recovery 分支 | TWRP 线 | polygraphene `android_bootable_recovery`，分支 `twrp-16.0-TB322FC`，锁定提交 `ced4ad75f311fc8a3350e21de415c23d5f0aec74` |
| OrangeFox 源码检出 | OrangeFox 线 | OrangeFox `fox_16.0` manifest |
| 103 个专有 payload 文件 | 构建 payload | 另行获取；绝不提交 |
| 六个 shell 工具预编译件 | `curl`、`fastfetch`、`git`、`wget`、`zsh`、`zstd` | 由 `prebuilt-tools.tsv` 锁定的第三方预编译件；见 `scripts/fetch-prebuilts.sh` |
| `ccache` | 可选的构建加速 | 可用 `NO_CCACHE=1` 关闭 |

### TWRP 线（fix3b 基线）

```bash
# 1) 源码检出（历史初始化使用浅克隆的 TWRP-Test manifest）
repo init --depth=1 \
  -u https://github.com/TWRP-Test/platform_manifest_twrp_aosp \
  -b twrp-16.0
repo sync -c --force-sync --no-clone-bundle --no-tags \
  --optimized-fetch --prune --fail-fast --retry-fetches=3 -j2

# 2) 把本设备树放到 device/lenovo/TB323FU，然后准备 103 个文件的 payload
scripts/acquire-proprietary-files.sh --stock-root /path/to/TB323FU-stock-root

# 3) 不编译、只做校验（建议作为第一步）
scripts/build-tb323fu-recovery.sh \
  --src /path/to/twrp-src \
  --stock-root /path/to/TB323FU-stock-root \
  --preflight-only

# 4) 构建
scripts/build-tb323fu-recovery.sh \
  --src /path/to/twrp-src \
  --stock-root /path/to/TB323FU-stock-root
```

构建封装脚本要求设备树处于 Git 检出状态，且绝不刷写任何 recovery 分区。
Lunch 目标：`twrp_TB323FU-bp2a-eng`；构建命令：`m -j1 recoveryimage`
（已验证的构建使用保守并行度，并约 8 GiB swap）。详见
[`docs/BUILDING.md`](docs/BUILDING.md) 与
[`docs/PROPRIETARY_FILES.md`](docs/PROPRIETARY_FILES.md)。

### OrangeFox 线（R12.0 / fox_16.0）

```bash
SRC=/root/fox_16.0 STOCK_ROOT=/root/stock-root \
  scripts/build-orangefox-recovery.sh --preflight-only   # 先校验
SRC=/root/fox_16.0 STOCK_ROOT=/root/stock-root \
  scripts/build-orangefox-recovery.sh                    # 构建
```

封装脚本会校验 OrangeFox 所需的 board 取值（例如
`OF_DEFAULT_KEYMASTER_VERSION := 4.x`、`OF_SCREEN_H := 3040`），通过同一个
获取脚本暂存专有 payload，并且绝不刷写任何内容。`JOBS` 控制并行度；
`NO_CCACHE=1` 关闭 ccache。

### 构建状态

最初的 fix3b 镜像与 OrangeFox R12.0 产品线均已成功编译；fix3b 经过真机运行
验证，OrangeFox 2026-11-03 构建已刷入项目设备。在公开仓库清理过程中，**没有**
仅仅为了验证打包改动而重新执行完整 TWRP 编译。

最终公开构建封装与 stock 文件提取说明仍在整合中。不要使用早期开发快照里的
旧式 resume/retry 脚本。

## 仓库结构

| 路径 | 内容 |
| --- | --- |
| `BoardConfig.mk`、`device.mk`、`AndroidProducts.mk`、`twrp_TB323FU.mk`、`Android.bp`、`system.prop`、`recovery.fstab` | 设备配置（AOSP/TWRP 约定 + TB323FU 修正） |
| `recovery/root/` | recovery ramdisk 配置文件（init rc、fstab flags、VINTF manifest、脚本）；专有二进制已被 `.gitignore` 排除 |
| `patches/` | 应用到 recovery 源码的 Android 16 兼容补丁（1 个为本项目编写，2 个上游作者为 polygraphene） |
| `scripts/` | 构建封装、哈希锁定 payload 获取、预编译工具获取/校验、文档校验脚本 |
| `docs/` | 构建、已知可用状态、专有文件、许可、发布状态、归属与合规文档 |
| `proprietary-files.tsv`、`proprietary-sources.tsv`、`proprietary-overrides.tsv` | 哈希锁定的专有 payload 清单（不含二进制内容） |
| `prebuilt-tools.tsv` | 六个第三方 shell 工具预编译件的哈希清单 |
| `LICENSES/` | Apache-2.0 原文与第三方工具许可/声明原文 |
| `TREE_PROVENANCE.md`、`NOTICE`、`AUTHORS.md`、`CREDITS.md` | 来源、归属与许可信息 |

## 第三方材料

- 六个 shell 工具（`curl`、`fastfetch`、`git`、`wget`、`zsh`、`zstd`）是随
  仓库跟踪的第三方二进制预编译件。其版本、哈希、源码来源、许可声明以及配套的
  对应源码包记录在 [`docs/THIRD_PARTY_TOOLS.md`](docs/THIRD_PARTY_TOOLS.md)
  与 `LICENSES/third-party-tools/`。若某个检出中缺少它们，
  `scripts/fetch-prebuilts.sh` 说明了获取与校验方式。
- `patches/0002` 与 `patches/0003` 保留其上游作者信息与上游条款。
- 仓库级混合来源许可声明见 [`LICENSE`](LICENSE)；并非所有文件适用同一条许可。
- 完整归属见 [`CREDITS.md`](CREDITS.md)、
  [`docs/ATTRIBUTION.md`](docs/ATTRIBUTION.md) 与
  [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md)。

## 已知问题与限制

- **没有**仅仅为了验证文档、许可清理或仓库打包而重新执行完整 TWRP 编译与设备
  刷写。现有 fix3b recovery 仍是被验证的运行基线；未来的构建可能因构建元数据、
  源码/toolchain 状态或环境差异而与历史镜像不是逐字节一致。
- OrangeFox 2026-11-04（OTA Guard）是离线构建，未经真机验证。其发布说明文件
  记录了一个不同的历史哈希（`6518747a…`），而实际产物哈希为 `5cf43fbc…`；
  请使用重新计算得到的 `5cf43fbc…`，并自行校验任何下载到的副本。
- 若要重建逐字节一致的 Android 17 OrangeFox 镜像，还需要上文所述的 8 个
  Android 17 TEE 字节；除记录到的大小外，其逐文件来源仍为待验证。
- 公开 payload 获取路径针对的是已验证的 Android 16 fix3b payload；Android 17
  专用替代件已文档化，但不保证可逐字节复现。
- 公开后计划中的后续工作（按顺序）：ORS / TWRP 命令行行为；键盘重复/大写
  行为；文件管理器目录创建；Wi-Fi；蓝牙。
- 不要使用早期开发快照里的旧式 resume/retry 脚本。

## 安全规则

- 目标设备：**仅联想 TB323FU**。
- 测试前保留一份完全一致的原厂 recovery 备份。
- 保留一条已知可用的 recovery 路径。
- 首次测试新镜像时，只刷入目标 recovery 槽位。
- 不要随意同时覆盖两个 recovery 槽位。
- 刷入前校验镜像哈希。
- 构建流程本身绝不刷写 recovery 分区。

## 相关项目与文档

- 主项目仓库（TB323FU 的 LineageOS 24 / Android 17 系统设备树）：
  <https://github.com/UGY1412/android_device_lenovo_TB323FU>
  —— 其 `docs/` 目录下提供构建、刷写、硬件支持、根因与排障的中英文文档。
- 同设备的兄弟 AERA Recovery 设备树：
  <https://github.com/UGY1412/android_device_lenovo_TB323FU-aera>
- 仓库文档索引：[`docs/INDEX.md`](docs/INDEX.md)
- 已知可用基线：[`docs/KNOWN_GOOD.md`](docs/KNOWN_GOOD.md)
- 构建流程：[`docs/BUILDING.md`](docs/BUILDING.md)
- 来源：[`TREE_PROVENANCE.md`](TREE_PROVENANCE.md)
- 归属与合规：[`docs/ATTRIBUTION.md`](docs/ATTRIBUTION.md)、
  [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md)
- 许可：[`docs/LICENSING.md`](docs/LICENSING.md)、[`NOTICE`](NOTICE)、
  [`LICENSES/`](LICENSES/)

<!-- TB323FU_PUBLICATION_DOCS_BEGIN -->
## 公开构建与文档

本仓库的目标设备是 **联想 TB323FU**。文中出现的 **TB322FC** 仅指上游
donor/基线来源。

请从[文档索引](docs/INDEX.md)开始。关键参考包括：

- [已知可用 fix3b 基线](docs/KNOWN_GOOD.md)；
- [标准构建流程](docs/BUILDING.md)；
- [专有文件获取](docs/PROPRIETARY_FILES.md)；
- [第三方 recovery 工具](docs/THIRD_PARTY_TOOLS.md)；
- [发布/测试状态](docs/PUBLICATION_STATUS.md)；
- [解密排障](docs/DECRYPTION_TROUBLESHOOTING.md)。

本仓库刻意不跟踪专有 recovery payload。标准获取脚本按哈希锁定来源重建所需的
103 个文件 payload，并在使用前逐文件校验。

构建流程支持 `--preflight-only`，且绝不刷写 recovery 分区。验证新镜像时请
保留原厂 recovery 槽位。
<!-- TB323FU_PUBLICATION_DOCS_END -->

---

Copyright (C) 2026 自恋也是种美 (krollv)。本项目原创内容按 [`NOTICE`](NOTICE)、
[`LICENSE`](LICENSE) 与 [`docs/LICENSING.md`](docs/LICENSING.md) 所述条款提供；
第三方组件保留其各自许可。
