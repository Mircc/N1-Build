---
name: n1-build
description: 基于 ImmortalWrt 源码，用 GitHub Actions 自动编译 N1 (s905d) 与 X86_64 固件的完整工作流。涵盖插件管理、旁路由模式、N1 amlogic 打包、Docker 本地编译、安全 CVE 信息注入、已知坑与修复。LAN 通过 DHCP 自动获取 IP，内核 6.12.y。
agent_created: true
version: v2.0_20260726
compatible_platforms:
  - workbuddy
  - openclaw
  - hermes
  - codex
---

# N1-Build Skill (v2.0)

基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) `master` 分支，通过 GitHub Actions 自动编译 **N1 (Amlogic s905d)** 与 **X86_64** 固件的完整体系。本技能是整个项目的唯一真相来源（single source of truth），可被任意 AI Agent 复用以搭建、维护或排错。

---

## 0. 关键事实速查（必读）

| 项 | 值 |
|----|----|
| 源码 | `immortalwrt/immortalwrt` 分支 `master`（≈ OpenWrt 25.12 系列） |
| N1 打包 Action | `OldCoding/amlogic-s9xxx-openwrt@main`（**不是** 旧的 `ophub/flippy-openwrt-actions`） |
| 默认 IP | DHCP 自动获取（`network.lan.proto='dhcp'`） |
| 主机名 / Web | `OpenWrt-N1` → `http://OpenWrt-N1` |
| 用户名 / 密码 | `root` / `password` |
| 内核版本 | `6.12.y`（`KernelVersion` 文件，N1 打包时解析为最新 6.12.x） |
| 网络模式 | **旁路由**（LAN DHCP 关闭，主路由分配 IP） |
| 编译周期 | 每月 9 号（N1 北京时间 04:00 / X86 05:00）+ `workflow_dispatch` 手动 |
| Git 提交作者 | 用 `AI助手` 或 `GitHub Actions Bot`，**不要用个人名** |
| 包管理器 | APK（OpenWrt 25.12 引入，**依赖检查严格**，缺 .so 会直接编译失败） |

---

## 1. 项目结构

```
N1-Build/
├── .github/workflows/
│   ├── build-n1.yml        # N1 ARM 编译 + amlogic 打包 + aarch64 通用镜像
│   ├── build-x86.yml       # X86_64 编译 + EFI 镜像
│   └── sync-upstream.yml   # 每半月同步 OldCoding 的 immo_diy.sh
├── immo_diy.sh             # 添加第三方软件源 + 默认IP + 旁路由 + 个性化
├── KernelVersion           # 内容: 6.12.y
├── build.sh                # 本地 Docker 编译入口: ./build.sh [n1|aarch64|x86]
├── README.md
├── scripts/
│   └── sync_immo_diy.py    # 同步上游 immo_diy.sh 的 Python 脚本
├── docker/
│   ├── Dockerfile          # Ubuntu 22.04 编译环境
│   ├── docker-compose.yml  # 缓存卷 + 输入输出映射
│   └── scripts/entrypoint.sh  # 复刻 workflow 的本地编译流程
└── output/                 # 本地编译产物
```

**同步关系**：`sync-upstream.yml` 每半月从 `OldCoding/openwrt_packit_arm` 拉取最新 `immo_diy.sh`，保留本地「默认 IP / 旁路由」配置块后覆盖提交。

---

## 2. 插件清单（当前实际状态）

### 2.1 编译进固件的三方插件（`.config` 中 `CONFIG_PACKAGE_*=y`）

> ⚠️ **核心原则**：`immo_diy.sh` 只负责把源码 `git clone` 进 `package/`，**必须**在 workflow / entrypoint 的 `.config` 中再加 `CONFIG_PACKAGE_luci-app-xxx=y` 才会被编译进固件。漏加 = 源码在但固件无插件（历史真实 bug）。

**全部目标通用：**
| 插件 | 用途 |
|------|------|
| `luci-app-passwall` + `luci-app-passwall2` | 代理（双栈） |
| `luci-app-openclash` | Clash 客户端 |
| `luci-app-mosdns` | DNS 分流 |
| `luci-app-adguardhome` | 去广告 |
| `luci-app-homeproxy` | HomeProxy 代理 |
| `luci-app-tailscale` | Tailscale 组网 |
| `luci-app-filebrowser` | 文件浏览器（HTTP） |
| `luci-app-netdata` | 系统监控 |
| `luci-app-pushbot` | 全能推送 |
| `luci-app-dockerman` | Docker 管理 |
| `luci-app-openlist2` | OpenList 文件列表 |
| `luci-app-qbittorrent` + `qbittorrent-ee` | qBittorrent 增强版 |
| `rclone` | 云存储同步（**含 WebDAV server**，替代 samba4） |

**仅 N1 / aarch64：**
| 插件 | 用途 |
|------|------|
| `luci-app-amlogic` | 晶晨宝盒（N1 固件管理 / 在线升级） |
| `autocore-arm` | ARM 性能监视 |

**X86_64 额外内核驱动**：`kmod-igb` `kmod-igc` `kmod-e1000` `kmod-e1000e` `kmod-ixgbe` `kmod-r8169` `kmod-mii`

**主题**：`luci-theme-argon` + `luci-app-argon-config` `luci-theme-design` `luci-theme-glass`

### 2.2 已显式移除的插件（不要再加回）

| 插件 | 移除原因 |
|------|---------|
| `luci-app-ssr-plus` | 与 passwall 功能重复，无依赖关系 |
| `luci-app-kodexplorer` | 用户不需要 |
| `luci-app-ddns-go` | 用户不需要 |
| `samba4-utils` + `wsdd2` | **编译失败根因**：samba4-libs 依赖 ICU 库（`libicui18n.so.78`/`libicuuc.so.78`），APK 严格依赖检查失败；全套依赖 50–70MB 过大。文件共享改用 `rclone serve webdav` |

### 2.3 immo_diy.sh 中实际 clone 的三方源（节选关键项）

- 主题：`jerrykuku/luci-theme-argon`、`papagaye744/luci-theme-design`（Mircc 派生）、`Mircc/luci-theme-glass`
- 代理：`Openwrt-Passwall/openwrt-passwall-packages`、`Openwrt-Passwall/openwrt-passwall`、`Openwrt-Passwall/openwrt-passwall2`、`vernesong/OpenClash`(dev)、`immortalwrt/homeproxy`
- 工具：`sbwml/luci-app-dockerman`、`sbwml/luci-app-mosdns`、`sbwml/luci-app-openlist2`、`zykfork/luci-app-pushbot`、`ophub/luci-app-amlogic`、`Mircc/luci-app-filebrowser`、`Mircc/luci-app-adguardhome`、`Mircc/OpenWrt-qBittorrent-Enhanced-Edition`、`nikkinikki-org/OpenWrt-nikki`、`EasyTier/luci-app-easytier`
- 通过 `svn_export` 拉取单目录：`Tokisaki-Galaxy/luci-app-tailscale-community`、`openwrt/luci`(cloudflared)、`timsaya/luci-app-bandix`、`sbwml/luci-app-mosdns`(mosdns/v2dat)、`openwrt/packages`(cloudflared)

> `svn_export` 函数：先用 `git clone --depth 1` 缓存整个仓库，再 `cp -af` 需要的子目录到目标。比直接 `svn export` 更稳（GitHub 禁用 SVN）。

---

## 3. immo_diy.sh 深度解析

脚本在 `Update feeds` 之后、`feeds install` 之前由 workflow 调用，顺序：

1. 定义 `svn_export` 函数（git 缓存 + 子目录拷贝）
2. `rm -rf feeds/...` 删除官方 feeds 中会与三方源冲突的包（**必须先删，否则 `feeds install` 选到旧版**）
3. `git clone` / `svn_export` 拉取三方源到 `package/` 或 `feeds/`
4. 修正目录结构（`mv ./package/xxx/* ./package/ && rm -rf ./package/xxx` 处理扁平化仓库）
5. aria2 补丁、turboacc 补丁（`chenmozhijin/turboacc`）
6. `./scripts/feeds update -i && ./scripts/feeds install -a`
7. 写入 `files/etc/uci-defaults/99-set-default-ip`（LAN DHCP 自动获取 + 不提供 DHCP 服务）
8. 写入 `files/etc/banner`
9. 个性化 sed：`menu.d` 菜单位置、pushbot 渠道、NTP 服务器、amlogic 品牌名、OpenClash 核心/Geo 数据库下载

### 3.1 旁路由模式（关键）

`files/etc/uci-defaults/99-set-default-ip` 末尾：

```sh
# 旁路由模式：关闭 LAN DHCP（由主路由负责分配 IP）
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci commit dhcp
```

恢复主路由模式：注释掉上述三行即可。

---

## 4. GitHub Actions 工作流

### 4.1 build-n1.yml

**触发**：`workflow_dispatch` + `schedule: '0 20 8 * *'`（每月 9 号 UTC20:00 = 北京 04:00）+ `watch`(star) + `repository_dispatch`

**环境变量**：
```yaml
REPO_URL: https://github.com/immortalwrt/immortalwrt
REPO_BRANCH: master
DIY_SH: immo_diy.sh
PRODUCT_NAME: N1-ImmortalWrt
permissions: contents: write   # 必须，否则 Release 403
```

**关键步骤顺序**：
1. Checkout → 检查服务器配置 → 初始化环境（装依赖）
2. 创建模拟物理磁盘（LVM loop 设备，绕过 runner 空间限制）
3. Clone 源码 → 读 `KernelVersion` 到 `KERNEL_VER` 环境变量 → `VER=R$(date +%Y.%m.%d)`
4. Update feeds → 运行 `immo_diy.sh`
5. 生成 `.config`（armsr/armv8 目标 + 所有插件 `=y`）→ `make defconfig`
6. `make download` → `make -j$(nproc)` → 失败自动 `make -j1 V=s` 排错
7. 清理空间 → 整理 `Packages.tar.gz`
8. **N1 打包**：`uses: OldCoding/amlogic-s9xxx-openwrt@main`，参数：
   ```yaml
   with:
     openwrt_path: openwrt/bin/targets/*/*/*.tar.gz
     kernel_usage: stable
     openwrt_board: s905d
     kernel_repo: OldCoding/openwrt_packit_arm
     openwrt_kernel: ${{ env.KERNEL_VER }}   # 6.12.y
     auto_kernel: true
     builder_name: Mircc
   ```
9. 计算 MD5 → 上传 Release（body 见 §4.3）
10. **aarch64 通用镜像**：复制 `openwrt/bin/targets/armsr/armv8/*.img.gz` 到 `output/aarch64/` 并追加上传同一 Release（让 `allowUpdates: true` + `removeArtifacts: false`）

> N1 打包产物路径用 `${{ env.PACKAGED_OUTPUTPATH }}`；aarch64 通用镜像必须用真实路径 `${{ github.workspace }}/output/aarch64/*.img.gz`（`with:` 块里 `$GITHUB_WORKSPACE` shell 变量**不会展开**，必须用 `${{ github.workspace }}`）。

### 4.2 build-x86.yml

与 N1 几乎相同，差异：
- 目标 `x86_64`，镜像 `combined-efi.img.gz`
- `CONFIG_TARGET_ROOTFS_SQUASHFS=y` + `CONFIG_TARGET_IMAGES_GZIP=y` + `CONFIG_TARGET_EFI_IMAGES=y` + `ROOTFS_PARTSIZE=1024`
- **无 amlogic 打包步骤**（直接出可用镜像）
- Release artifacts：`${{ github.workspace }}/openwrt/bin/targets/x86/64/*`
- 编译周期：`'0 21 8 * *'`（北京 05:00）

### 4.3 Release Notes 格式

`ncipollo/release-action@main` 的 `body:` 内联 Markdown，含：
- 默认信息表（IP / 网关 / 密码 / 分支 / 内核 / 日期）
- 主源码最近提交（`useVersionInfo`，来自 `git show`）
- 使用说明
- MD5 校验（`${{ env.MD5 }}`）

---

## 5. Docker 本地编译

适合 Mac M 芯片（aarch64）或 Windows x86_64 本机编译，避免占用 GitHub Actions 额度。

**用法**：
```bash
./build.sh n1         # N1 (aarch64 + amlogic 打包)
./build.sh aarch64    # 仅通用 aarch64 镜像
./build.sh x86        # X86_64（需在 x86_64 宿主机运行）
```

**架构**：
- `docker/Dockerfile`：Ubuntu 22.04 + 完整 OpenWrt 编译依赖 + ccache
- `docker/docker-compose.yml`：持久化缓存卷 `cache/dl`、`cache/build_dir`、`cache/staging_dir`、`cache/ccache`；输入 `immo_diy.sh`/`KernelVersion` 只读；输出挂载 `output/`
- `docker/scripts/entrypoint.sh`：复刻 workflow 的 `.config` 生成 + 编译 + 按 `BUILD_TARGET` 分派输出（N1 调 `OldCoding/amlogic-s9xxx-openwrt` 的 `remake` 脚本打包）

> 二次编译利用 ccache + 缓存卷，通常 10–40 分钟（首次 1.5–3 小时）。同一 Dockerfile 两平台通用（Mac 原生 aarch64，x86 Windows 原生 x86_64）。

---

## 6. 安全 CVE 信息注入（方案）

用户希望在 Release Notes 中加入当前编译版本修复的安全漏洞。

### 6.1 OpenWrt 版本安全修复 — 可行

数据源：`https://openwrt.org/releases/25.12/notes-25.12.5`（结构化 **Security fixes** 章节，含 CVE 编号 + 严重等级 + 按组件分类）。

**实现思路**（在 workflow 编译完成后新增步骤）：
1. 从固件产物 `/etc/openwrt_release` 或 `.config` 读取实际版本号
2. `curl` 抓取 `openwrt.org/releases/25.12/start` 获取最新点版本号
3. 抓取 `notes-{version}` 页面，用 Python 提取 Security fixes 段落
4. 注入 Release body

> ⚠️ ImmortalWrt `master` 默认报告 `SNAPSHOT`，不等于具体 25.12.x。建议**固定引用最新 25.12.x 稳定版 notes** 并标注「参考」，因 ImmortalWrt master 通常已含这些修复。

### 6.2 内核 CVE — 有限可行

- N1 内核 `6.12.y` → 打包时解析为最新（如 6.12.94）
- X86 内核来自 OpenWrt 源码
- kernel.org `ChangeLog-6.12.94` 是**原始 git commit 记录，无 CVE 标注**
- **推荐**：直接复用 OpenWrt release notes 中的内核安全段落（已说明「含上游 6.12.88→6.12.94 安全修复」+ 引用 CVE-2026-43500），附 kernel.org ChangeLog 链接

详见 `references/security-notes.md`。

---

## 7. 已知坑与修复（历史血泪）

| # | 问题 | 根因 | 修复 |
|---|------|------|------|
| 1 | sync-upstream.yml YAML 语法错误 | `sed` 插入破坏结构 | 改用 Python 脚本 `sync_immo_diy.py` |
| 2 | X86 Release 报 403 | 缺 `permissions: contents: write` | workflow 加 `permissions: contents: write` |
| 3 | N1 打包 cp 失败 | 路径/产物名不匹配 | 用 `*rootfs.tar.gz` glob + `OPENWRT_ARMSR` |
| 4 | N1 打包 Action 下载内核失败 | 旧 `ophub/flippy` 已不可用 | 切 `OldCoding/amlogic-s9xxx-openwrt@main`，`env→with` + `kernel_repo` |
| 5 | X86 artifact 路径告警 | `with:` 块 `$GITHUB_WORKSPACE` 不展开 | 改 `${{ github.workspace }}` |
| 6 | aarch64 `.img.gz` 未生成 | `CONFIG_TARGET_IMAGES_GZIP=y` 被注释 | 取消注释启用 |
| 7 | **X86 固件无插件** | immo_diy.sh clone 了但 `.config` 未加 `CONFIG_PACKAGE_*=y` | 补全插件 CONFIG 块 |
| 8 | **samba4 编译失败** | samba4-libs 依赖 ICU `.so` 未装到 staging_dir，APK 严格检查失败 | 移除 samba4 + wsdd2，改用 rclone WebDAV |
| 9 | 内核 `6.18.y` 不存在 | 打包仓库无该系列 → 404 | `KernelVersion` 改为 `6.12.y` |
| 10 | 编译失败无详细日志 | 多线程错误被淹没 | 失败步骤自动 `make -j1 V=s` |
| 11 | **N1 armsr 编译失败 (out of space)** | build-n1.yml 的 armsr 段缺 `CONFIG_TARGET_ROOTFS_PARTSIZE`，默认 160MB 装不下全部插件，`make_ext4fs` 报 `failed to allocate ... out of space` → `root.ext4` Error 1 | build-n1.yml 与 docker/entrypoint.sh 的 armsr 段补 `CONFIG_TARGET_ROOTFS_PARTSIZE=1024`（X86 段原本已有） |
| 12 | **nftables 编译失败 → 整个编译中断 (Patch failed)** | `immo_diy.sh` 调用的第三方 turboacc 脚本（`mufeng05/turboacc` 的 `add_turboacc.sh` 第 128 行）会把 **lede 旧版** `100-nftables-add-fullcone-expression-support.patch` 拷进 `package/network/utils/nftables/patches/`；而 ImmortalWrt master 的 nftables 已升级到 **1.1.6**，旧补丁 hunk 全部失配（`statement.h` / `netlink_delinearize.c` / `parser_bison.y` 3of4 / `scanner.l` / `statement.c`）→ `Patch failed` → nftables `.prepared` 失败 → `world` Error 2 | 在 `immo_diy.sh` 执行 `add_turboacc.sh` **之后**加 `rm -f package/network/utils/nftables/patches/100-nftables-add-fullcone-expression-support.patch`。依据：ImmortalWrt **自带** `002-nftables-add-fullcone`（适配 1.1.6，应用成功），fullcone NAT 不依赖被删的补丁；turboacc 其余能力（SFE 加速、内核 netfilter 补丁、libnftnl fullcone）不受影响。**N1 与 X86 共用 immo_diy.sh，两者都会受影响** |
| 13 | **打包阶段失败 `ERROR: unable to select packages: geo2txt`** | 上游 `sbwml/luci-app-mosdns`(v5) 已用 **geo2txt 取代 v2dat**：仓库顶层不再有 `v2dat` 目录（继续导出会报 `Subdirectory v2dat not found`），而 `luci-app-mosdns` **依赖 `geo2txt`**；我们仍在导出已不存在的 `v2dat`，导致 `geo2txt` 包从未被编译 → APK 阶段 `unable to select packages: geo2txt (no such package)`，`required by: luci-app-mosdns-1.7.14-r1[geo2txt]` → `package/Makefile:164: package/install` Error 3 → 编译失败。**注意：此失败发生在编译已完成之后的 rootfs 打包阶段（不是编译阶段），N1 与 X86 均相同** | `immo_diy.sh`：把 `svn_export "v5" "v2dat" "package/v2dat" "https://github.com/sbwml/luci-app-mosdns"` 改为 `svn_export "v5" "geo2txt" "package/geo2txt" "https://github.com/sbwml/luci-app-mosdns"`。`sync_immo_diy.py`：同步时加保护（v2dat→geo2txt 替换 + 若上游删行则兜底补一行），避免半月同步把 `v2dat` 带回来 |

---

## 8. 常用任务（操作手册）

### 8.1 新增插件
1. `immo_diy.sh`：在「添加第三方软件源」区 `git clone` / `svn_export` 源码
2. workflow（build-n1.yml / build-x86.yml）或 `docker/scripts/entrypoint.sh`：在「第三方插件」`cat >> .config` 块加 `CONFIG_PACKAGE_luci-app-xxx=y`
3. **两处都要改**（N1 和 X86 分别维护）

### 8.2 修改默认 IP / 旁路由
编辑 `immo_diy.sh` 的 `files/etc/uci-defaults/99-set-default-ip`。注意 `sync-upstream.yml` 同步会**保留**此块（Python 脚本检测到 `99-set-default-ip` 则原样保留，否则追加）。

### 8.3 修改内核版本
编辑 `KernelVersion`（`6.12.y`）。可用系列参考 [ophub/kernel releases](https://github.com/ophub/kernel/releases)。**确认目标系列在 `OldCoding/openwrt_packit_arm` 中存在**，否则打包 404。

### 8.4 切换编译周期
编辑 workflow 的 `schedule.cron`：
- 每月 9 号 N1：`'0 20 8 * *'`（北京 04:00）
- 每月 9 号 X86：`'0 21 8 * *'`（北京 05:00）

### 8.5 提交到 GitHub 并触发
```bash
git add -A && git commit -m "..." && git push origin main
gh workflow run build-n1.yml --repo <owner>/N1-Build
gh workflow run build-x86.yml --repo <owner>/N1-Build
```
提交作者用 `AI助手`（非个人名）。

---

## 9. 跨平台注意

- **WorkBuddy / Codex / Hermes**：优先用 `gh` CLI 做 GitHub 操作；无 `gh` 时回退 Git HTTPS + token
- 任何修改后**必须校验**：YAML 语法、Bash 语法（`bash -n immo_diy.sh`）、Python 语法（`python3 -m py_compile`）
- `with:` 块只认 `${{ }}` 表达式，shell 变量 `$XXX` 不展开（见坑 #5）

---

## 10. 参考文件

- `references/workflow-templates.md` — 完整 workflow YAML 模板（与真实文件同步）
- `references/immo-diy-template.sh` — immo_diy.sh 模板
- `references/security-notes.md` — 安全 CVE 信息获取方案
- `scripts/sync_immo_diy.py` — 上游同步脚本（Python）

---

## 11. 给 AI Agent 的提示

1. 本项目 **ImmortalWrt master ≠ OpenWrt 稳定版**，版本号可能是 SNAPSHOT。
2. 插件「源码 clone」和「编译进固件」是**两件独立的事**，缺一不可。
3. 任何涉及 `immo_diy.sh` 的改动都要考虑 `sync-upstream.yml` 每半月会覆盖它——保留块用 `99-set-default-ip` 标记。
4. N1 与 X86 的 `.config` / entrypoint 配置**分开维护**，改一处要同步另一处。
5. 编译失败先看 Actions 日志里的 `make -j1 V=s` 输出，优先怀疑：依赖缺失（APK 严格）、插件源码 URL 失效、磁盘空间。
