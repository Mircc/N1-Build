# OpenWrt N1 & X86 自动编译仓库

基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 源码，使用 GitHub Actions 自动编译 N1 (s905d) 和 X86_64 固件。

## ✨ 特性

- ✅ 自动每月9号编译 (北京时间 X86 01:00 / N1 05:00，错开避免资源竞争)
- ✅ 手动触发编译 (`workflow_dispatch`)
- ✅ N1 和 X86 分开编译，互不干扰
- ✅ 自动打包 N1 固件 (使用 amlogic 内核)
- ✅ X86 直接输出 EFI 镜像
- ✅ Release 自动生成，包含 IP、密码、更新日志
- ✅ 自动清理旧 Release (保留最新 10 个)
- ✅ 自适应网络（LAN 通过 DHCP 自动获取 IP，无需固定 IP）

## 📋 默认信息

| 项目 | 值 |
|------|-----|
| 默认 IP | DHCP 自动获取（由主路由分配） |
| 主机名 | `OpenWrt-N1` |
| 网关 / DNS | 由主路由自动下发 |
| Web 访问 | `http://OpenWrt-N1` |
| 默认用户 | `root` |
| 默认密码 | `password` |
| 源码分支 | `master` (基于 OpenWrt 25.12) |

## 📦 Integrated LuCI Plugins

### Utilities
- `luci-app-commands`
- `luci-app-ttyd`
- `luci-app-ramfree`
- `luci-app-autoreboot`
- `luci-app-filebrowser`
- `luci-app-netdata`
- `luci-app-pushbot`

### Network / Proxy
- `luci-app-passwall`
- `luci-app-passwall2`
- `luci-app-openclash`
- `luci-app-homeproxy`
- `luci-app-mosdns`
- `luci-app-adguardhome`
- `luci-app-tailscale`
- `luci-app-ddns`

### Download / File
- `luci-app-aria2`
- `luci-app-qbittorrent`
- `luci-app-openlist2`
- `rclone`

### Docker
- `luci-app-dockerman`

### N1 Only (aarch64)
- `luci-app-amlogic`
- `luci-app-oxidns`

### Themes
- `luci-theme-argon`
- `luci-app-argon-config`
- `luci-theme-design`
- `luci-theme-glass`

## 🚀 使用方法

### 1. 创建你的 GitHub 仓库

```bash
# 在 GitHub 上创建名为 N1-Build 的空仓库（不要勾选初始化）
# 然后本地执行：
git init
git add .
git commit -m "Initial commit: N1 & X86 ImmortalWrt auto build"
git branch -M main
git remote add origin https://github.com/Mircc/N1-Build.git
git push -u origin main
```

### 2. 启用 GitHub Actions

进入你的仓库 → Settings → Actions → General → 选择 "Allow all actions and reusable workflows" → Save。

### 3. 触发编译

- **自动**：每月9号北京时间 01:00 (X86) / 05:00 (N1) 自动触发
- **手动**：进入 Actions 页面 → 选择对应 Workflow → 点击 "Run workflow"

### 4. 下载固件

编译完成后，进入仓库 [Releases](https://github.com/Mircc/N1-Build/releases) 页面下载。

## 📝 N1 刷机说明

1. 下载 Releases 中的 `*.img.gz`，解压得到 `.img` 文件
2. 使用 [晶晨宝盒](https://github.com/ophub/amlogic-s9xxx-openwrt) 或 USB Burning Tool 刷入
3. 接入网络后自动获取 IP，浏览器访问 `http://OpenWrt-N1`（主机名无法解析时，到主路由后台查看分配的 IP）

## 💻 X86 使用说明

1. 下载 Releases 中的 `*combined-efi.img.gz`，解压得到 `.img` 文件
2. 使用 Rufus 或 balenaEtcher 写入 U 盘或 SSD
3. 从 U 盘/SSD 启动
4. 自动获取 IP 后访问 `http://OpenWrt-N1`（或到主路由查看分配的 IP）

## ⚙️ 自定义

### 修改插件

编辑 `.github/workflows/build-n1.yml` 或 `build-x86.yml` 中的 `.config` 生成部分，添加/删除 `CONFIG_PACKAGE_luci-app-xxx=y` 行。

### 修改默认网络

编辑 `immo_diy.sh` 中的 `files/etc/uci-defaults/99-set-default-ip` 部分。
当前为**DHCP 自适应模式**：LAN 作为 DHCP 客户端自动获取 IP（`network.lan.proto='dhcp'`），不再固定 IP；同时本机不在 LAN 口提供 DHCP 服务（`dhcp.lan.ignore=1`），避免与主路由冲突。

> ⚠️ 改这里务必同时改 `scripts/sync_immo_diy.py` 里的同一份模板，否则半月一次的上游同步会把旧配置覆盖回来。

想改回固定 IP：把该块换成 `uci set network.lan.proto='static'` 并补上 ipaddr/netmask/gateway/dns；想让本机给下挂设备分配 IP（作主路由）：把 `dhcp.lan.ignore` 改为 `'0'`。

### 修改内核版本

编辑 `KernelVersion` 文件，支持的内核版本参考 [ophub/kernel releases](https://github.com/ophub/kernel/releases)。

## 📄 参考

- 源码：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt)
- N1打包：[OldCoding/amlogic-s9xxx-openwrt](https://github.com/OldCoding/amlogic-s9xxx-openwrt)
- 参考配置：[OldCoding/openwrt_packit_arm](https://github.com/OldCoding/openwrt_packit_arm)

## ⚠️ 免责声明

本项目仅供学习交流使用，刷机有风险，操作需谨慎！
