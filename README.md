# OpenWrt N1 & X86 自动编译仓库

基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 源码，使用 GitHub Actions 自动编译 N1 (s905d) 和 X86_64 固件。

## ✨ 特性

- ✅ 自动每月9号编译 (北京时间 04:00 / 05:00)
- ✅ 手动触发编译 (`workflow_dispatch`)
- ✅ N1 和 X86 分开编译，互不干扰
- ✅ 自动打包 N1 固件 (使用 amlogic 内核)
- ✅ X86 直接输出 EFI 镜像
- ✅ Release 自动生成，包含 IP、密码、更新日志
- ✅ 自动清理旧 Release (保留最新 10 个)
- ✅ 旁路由模式（DHCP 已关闭，由主路由分配 IP）

## 📋 默认信息

| 项目 | 值 |
|------|-----|
| 默认 IP | `192.168.50.200` |
| 子网掩码 | `255.255.255.0` |
| 网关 | `192.168.50.1` |
| DNS | `192.168.50.1` |
| 默认用户 | `root` |
| 默认密码 | `password` |
| 源码分支 | `master` (基于 OpenWrt 25.12) |

## 📦 已集成 LuCI 插件

### 基础工具
- `luci-app-commands` - 命令执行
- `luci-app-ttyd` - Web终端
- `luci-app-ramfree` - 内存释放
- `luci-app-autoreboot` - 定时重启
- `luci-app-filebrowser` - 文件浏览器
- `luci-app-netdata` - 系统监控
- `luci-app-pushbot` - 全能推送

### 网络/代理
- `luci-app-passwall` - 代理工具1
- `luci-app-passwall2` - 代理工具2
- `luci-app-openclash` - Clash客户端
- `luci-app-homeproxy` - HomeProxy代理
- `luci-app-mosdns` - MosDNS分流
- `luci-app-adguardhome` - AdGuard Home去广告
- `luci-app-tailscale` - Tailscale组网
- `luci-app-ddns` - 动态DNS

### 下载/文件服务
- `luci-app-aria2` - Aria2下载
- `luci-app-qbittorrent` - qBittorrent增强版
- `luci-app-openlist2` - OpenList文件列表
- `rclone` - 云存储同步工具

### Docker
- `luci-app-dockerman` - Docker管理

### N1 专用
- `luci-app-amlogic` - 晶晨宝盒固件管理

### 主题
- `luci-theme-argon` + `luci-app-argon-config` - Argon主题
- `luci-theme-design` - Design主题
- `luci-theme-glass` - Glass主题

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

- **自动**：每月9号北京时间 04:00 (N1) / 05:00 (X86) 自动触发
- **手动**：进入 Actions 页面 → 选择对应 Workflow → 点击 "Run workflow"

### 4. 下载固件

编译完成后，进入仓库 [Releases](https://github.com/Mircc/N1-Build/releases) 页面下载。

## 📝 N1 刷机说明

1. 下载 Releases 中的 `*.img.gz`，解压得到 `.img` 文件
2. 使用 [晶晨宝盒](https://github.com/ophub/amlogic-s9xxx-openwrt) 或 USB Burning Tool 刷入
3. 首次启动后访问 `http://192.168.50.200`

## 💻 X86 使用说明

1. 下载 Releases 中的 `*combined-efi.img.gz`，解压得到 `.img` 文件
2. 使用 Rufus 或 balenaEtcher 写入 U 盘或 SSD
3. 从 U 盘/SSD 启动
4. 访问 `http://192.168.50.200`

## ⚙️ 自定义

### 修改插件

编辑 `.github/workflows/build-n1.yml` 或 `build-x86.yml` 中的 `.config` 生成部分，添加/删除 `CONFIG_PACKAGE_luci-app-xxx=y` 行。

### 修改默认网络

编辑 `immo_diy.sh` 中的 `files/etc/uci-defaults/99-set-default-ip` 部分。
当前为**旁路由模式**：DHCP 已关闭（`dhcp.lan.ignore=1`），由主路由负责 IP 分配。
如需恢复 DHCP，注释掉 `uci set dhcp.lan.ignore='1'` 相关行即可。

### 修改内核版本

编辑 `KernelVersion` 文件，支持的内核版本参考 [ophub/kernel releases](https://github.com/ophub/kernel/releases)。

## 📄 参考

- 源码：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt)
- N1打包：[OldCoding/amlogic-s9xxx-openwrt](https://github.com/OldCoding/amlogic-s9xxx-openwrt)
- 参考配置：[OldCoding/openwrt_packit_arm](https://github.com/OldCoding/openwrt_packit_arm)

## ⚠️ 免责声明

本项目仅供学习交流使用，刷机有风险，操作需谨慎！
