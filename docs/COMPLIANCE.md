# Compliance and redistribution notes / 合规与再分发说明

Last updated / 最后更新: 2026-11-12

This document records what the repository intentionally includes and excludes,
how third-party material is handled, and how to contact the maintainers about a
takedown request. The same content is provided in English and Chinese.

本文档记录仓库刻意收录/排除的内容、第三方材料的处理方式，以及下架请求的联系
渠道。以下提供英文与中文两个版本。

## English

### 1. Scope

This repository is a community device tree for the Lenovo Legion Y700 Gen 5
(TB323FU). It is **not** an official Lenovo, Qualcomm, TeamWin or OrangeFox
release. It contains build configuration, recovery configuration, project
scripts, patches, documentation and hash-pinned manifests. It does **not**
contain Lenovo/Qualcomm proprietary binaries, stock firmware images, build
outputs or private development caches.

### 2. Included in Git

| Item | Location | Basis |
| --- | --- | --- |
| Device configuration and recovery config (text) | repository root, `recovery/root/` | Project work derived from the attributed baseline; Apache-2.0 SPDX headers where present |
| Build/acquisition/verification scripts | `scripts/` | Project-authored scripts |
| Compatibility patches | `patches/` | Project work; two patches retain their upstream author (polygraphene) and upstream terms |
| Documentation | `README*.md`, `AUTHORS.md`, `CREDITS.md`, `NOTICE`, `docs/`, `TREE_PROVENANCE.md` | Project-authored documentation |
| Hash-pinned payload/tool manifests (no binaries) | `proprietary-files.tsv`, `proprietary-sources.tsv`, `proprietary-overrides.tsv`, `prebuilt-tools.tsv` | Project-authored manifests recording paths/sizes/SHA-256 |
| License texts and third-party notices | `LICENSES/` | Verbatim upstream license/notice texts |
| Six third-party shell tools | `prebuilts/` (when staged) | Tracked third-party binary prebuilts, pinned by `prebuilt-tools.tsv`; licenses in `LICENSES/third-party-tools/` |

### 3. Excluded from Git

| Item | Why excluded |
| --- | --- |
| Lenovo/Qualcomm proprietary services, libraries and firmware (`recovery/root/**` paths listed in `.gitignore` and `proprietary-files.tsv`) | No redistribution rights; builders must acquire them from a source they are legally entitled to use |
| Stock firmware images / partition dumps | Proprietary; not redistributable by this project |
| Built recovery images, ramdisks, OTA payloads | Build outputs; not source |
| Eight Android 17 TEE-chain files used by the Android 17 decryption correction | Proprietary Android 17 stock bytes; not part of the published 103-file manifest; must be staged from matching stock firmware |
| Private development caches, private blob directories | Private; never published |
| Credentials, keys, local environment files | Security; never published |
| User data / device-specific dumps (including serial numbers and MAC addresses) | Privacy and security; never published |

The acquisition flow is deliberately hash-pinned: `proprietary-sources.tsv`
pins every payload target and `scripts/acquire-proprietary-files.sh` verifies
size/SHA-256 before installing anything into the recovery tree.

### 4. Third-party handling

- Repository-level licensing: [`LICENSE`](../LICENSE) states the mixed-origin
  policy; per-file SPDX notices govern each file.
- Upstream copyright/SPDX/license notices are preserved per file.
- The two polygraphene-authored patches retain their `From:`/`Subject:` headers.
- The six prebuilt shell tools keep their license/notice texts under
  `LICENSES/third-party-tools/`, and their corresponding source/provenance
  bundle is identified in `docs/THIRD_PARTY_TOOLS.md`.
- No blanket license is asserted over files that lack an explicit license or a
  clear upstream origin. See `docs/LICENSING.md`.

### 5. Takedown / rights-holder contact (72 hours)

If you are a rights holder and believe material in this repository should not
be redistributed:

1. Open an issue on this repository (preferred), or contact the maintainer's
   GitHub account: <https://github.com/UGY1412>.
2. Include the exact file path(s), the material you own, and the legal basis
   for the request.
3. The maintainers will acknowledge and act on a clear, complete request
   within **72 hours** — typically by removing or replacing the identified
   material. No dedicated e-mail address has been published for this project
   yet; if one is added later it will be listed here (待验证 / to be verified).

This section describes project policy.

### 6. Disclaimer

- The project is provided **AS IS**, without warranty of any kind.
- It is unofficial and not affiliated with or endorsed by Lenovo, Qualcomm,
  Google, TeamWin, or the OrangeFox Recovery Project. All trademarks belong to
  their respective owners.
- Nothing in this repository grants rights to proprietary Lenovo/Qualcomm
  material.
- This is compliance documentation; obtain
  professional advice if you intend to redistribute third-party material.

### 7. Items marked "to be verified" (待验证)

- Per-file license identification for inherited device-tree and recovery files.
- Exact redistribution terms of the isrgish/TB323FU-TWRP baseline (no explicit
  LICENSE was found upstream; only a provenance/lineage statement).
- Provenance of the eight Android 17 TEE-chain files across stock firmware
  revisions.
- License status of some OrangeFox/LineageOS-adjacent components where no
  per-file notice is present in this tree.

## 中文

### 1. 范围

本仓库是联想拯救者 Y700 五代（TB323FU）的社区设备树，**不是**联想、高通、
TeamWin 或 OrangeFox 的官方发布。它包含构建配置、recovery 配置、项目脚本、
补丁、文档与哈希锁定清单；**不**包含联想/高通专有二进制、原厂固件镜像、构建
产物或私有开发缓存。

### 2. Git 中收录的内容

| 项目 | 位置 | 依据 |
| --- | --- | --- |
| 设备配置与 recovery 配置（文本） | 仓库根目录、`recovery/root/` | 基于已署名基线衍生的本项目成果；有 SPDX 头处为 Apache-2.0 |
| 构建/获取/校验脚本 | `scripts/` | 本项目编写的脚本 |
| 兼容补丁 | `patches/` | 本项目成果；其中两个补丁保留上游作者（polygraphene）与上游条款 |
| 文档 | `README*.md`、`AUTHORS.md`、`CREDITS.md`、`NOTICE`、`docs/`、`TREE_PROVENANCE.md` | 本项目编写的文档 |
| 哈希锁定 payload/工具清单（无二进制） | `proprietary-files.tsv`、`proprietary-sources.tsv`、`proprietary-overrides.tsv`、`prebuilt-tools.tsv` | 本项目编写、记录路径/大小/SHA-256 的清单 |
| 许可原文与第三方声明 | `LICENSES/` | 逐字复制的上游许可/声明原文 |
| 六个第三方 shell 工具 | `prebuilts/`（暂存后） | 随仓库跟踪的第三方二进制预编译件，由 `prebuilt-tools.tsv` 锁定；许可原文见 `LICENSES/third-party-tools/` |

### 3. Git 中排除的内容

| 项目 | 排除原因 |
| --- | --- |
| 联想/高通专有服务、库与固件（`.gitignore` 与 `proprietary-files.tsv` 中列出的 `recovery/root/**` 路径） | 无再分发权；构建者须从合法来源获取 |
| 原厂固件镜像 / 分区 dump | 专有材料；本项目无权再分发 |
| 已构建的 recovery 镜像、ramdisk、OTA payload | 构建产物，非源码 |
| Android 17 解密修正所用的 8 个 TEE 通信链文件 | 专有 Android 17 原厂字节；不在公开的 103 文件清单内；须从配套原厂固件暂存 |
| 私有开发缓存、私有 blob 目录 | 私有；永不公开 |
| 凭据、密钥、本地环境文件 | 安全；永不公开 |
| 用户数据 / 设备相关 dump（含序列号、MAC 地址） | 隐私与安全；永不公开 |

获取流程刻意采用哈希锁定：`proprietary-sources.tsv` 锁定每个 payload 目标，
`scripts/acquire-proprietary-files.sh` 在写入 recovery 树之前校验大小/SHA-256。

### 4. 第三方材料处理

- 仓库级许可说明见 [`LICENSE`](../LICENSE)（混合来源；逐文件 SPDX 声明为准）。
- 逐文件保留上游版权/SPDX/许可声明。
- 两个由 polygraphene 编写的补丁保留其 `From:`/`Subject:` 头。
- 六个预编译 shell 工具在 `LICENSES/third-party-tools/` 下保留许可/声明原文，
  其对应源码/来源包在 `docs/THIRD_PARTY_TOOLS.md` 中标识。
- 对于缺少显式许可或明确上游来源的文件，不主张任何笼统许可。见
  `docs/LICENSING.md`。

### 5. 下架 / 权利人联系（72 小时）

如果你是权利人，并认为本仓库中的材料不应被再分发：

1. 在本仓库提交 issue（首选），或联系维护者的 GitHub 账号：
   <https://github.com/UGY1412>。
2. 注明确切的文件路径、你拥有权利的材料，以及请求的法律依据。
3. 维护者将在 **72 小时**内对清晰、完整的请求作出确认并采取行动——通常为移除
   或替换被指出的材料。本项目目前尚未公布专用电子邮箱；如后续添加，会在此处
   更新（待验证）。

本节为项目实务政策，不构成法律意见。

### 6. 免责

- 本项目按 **“现状（AS IS）”** 提供，不附带任何形式的担保。
- 本项目为非官方项目，与联想、高通、Google、TeamWin、OrangeFox Recovery
  Project 无隶属或背书关系。所有商标归其各自所有者。
- 本仓库中的任何内容都不授予联想/高通专有材料的任何权利。
- 本文档为实务合规文档，不构成法律意见；如计划再分发第三方材料，请获取专业
  意见。

### 7. 标注为“待验证”的事项

- 继承的设备树与 recovery 文件的逐文件许可识别。
- isrgish/TB323FU-TWRP 基线的确切再分发条款（上游未发现显式 LICENSE，只有
  来源/传承声明）。
- 8 个 Android 17 TEE 通信链文件在各原厂固件版本上的来源。
- 本树中部分与 OrangeFox/LineageOS 相关、但缺失逐文件声明的组件的许可状态。
