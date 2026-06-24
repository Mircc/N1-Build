# Docker 本地编译环境

在本地机器上用 Docker 编译 N1 / aarch64 / X86_64 的 ImmortalWrt 固件。

## 前置要求

- [Docker](https://www.docker.com/) 已安装并运行
- [Docker Compose](https://docs.docker.com/compose/) (Docker Desktop 自带)
- 60GB+ 可用磁盘空间（首次编译需要下载大量依赖）

## 快速开始

```bash
# 编译 N1 固件 (s905d)
./build.sh n1

# 编译通用 aarch64 镜像
./build.sh aarch64

# 编译 X86_64 固件
./build.sh x86
```

## 三个编译目标

| 命令 | 产物 | 适用设备 |
|------|------|----------|
| `./build.sh n1` | N1 盒刷镜像 + aarch64 通用镜像 | Phicomm N1、S905D 设备 |
| `./build.sh aarch64` | 仅 aarch64 通用镜像 | ARM 服务器、ARM 虚拟机 |
| `./build.sh x86` | X86_64 EFI 镜像 + VMDK | 标准 PC、虚拟机 |

## 架构兼容性

Docker 自动适配宿主机架构，无需手动切换：

| 宿主机 | 编译 n1 / aarch64 | 编译 x86 |
|---------|-------------------|----------|
| Mac (Apple Silicon) | ✅ 原生 aarch64，全速 | ⚠️ QEMU 模拟，较慢 |
| Windows / Linux (x86_64) | ⚠️ QEMU 模拟，较慢 | ✅ 原生 x86_64，全速 |

## 缓存机制

首次编译完成后，以下目录会保留在本地，后续编译大幅加速：

```
cache/
├── dl/           # 源码包下载
├── build_dir/    # 中间编译产物
├── staging_dir/  # 工具链 + 系统库
└── ccache/       # GCC 缓存
```

- **首次编译**：~2 小时（需编译全部包和工具链）
- **二次编译**：10~40 分钟（仅增量变更的包重新编译）

## 产物目录

编译完成后，所有固件文件输出到 `output/`：

```
output/
├── build.log              # 完整编译日志
├── config.txt             # 最终 .config 配置
├── Packages.tar.gz        # 所有软件包归档
├── *-s905d-*.img.gz       # N1 固件镜像
├── *generic-efi.img.gz    # aarch64 通用镜像
└── sha256sums.txt         # X86 校验文件
```

## 自定义配置

### 修改默认 IP 和密码

编辑 `immo_diy.sh`，找到 `uci set network.lan.ipaddr` 所在行修改。

### 修改插件列表

编辑 `docker/scripts/entrypoint.sh`，在 `.config` 配置段添加或删除 `CONFIG_PACKAGE_*` 条目。

### 修改内核版本

编辑 `KernelVersion` 文件，写入所需的内核版本号（如 `6.6.y`、`6.12.y`）。

## 清理

```bash
# 清理所有编译缓存（下次将重新全量编译）
rm -rf cache/

# 清理产物
rm -rf output/*

# 清理 Docker 镜像（重新构建容器环境）
docker compose -f docker/docker-compose.yml down --rmi all
```

## 常见问题

**Q: 编译中途失败怎么重试？**

直接重新运行 `./build.sh n1`，已编译的部分从缓存恢复，从失败处继续。

**Q: 磁盘空间不足怎么办？**

```bash
# 先清理缓存
rm -rf cache/
# 清理 Docker 无用数据
docker system prune -af
```

**Q: 如何在 x86 Windows 上编译 N1？**

可以编译，但会通过 QEMU 模拟 aarch64 指令，速度较慢。建议在 M 芯片 Mac 上编译 N1/aarch64，在 x86 机器上编译 X86。

**Q: Mac 首次编译 x86 很慢怎么办？**

正常现象。x86_64 在 Apple Silicon 上需要 QEMU 翻译每条指令，性能损失约 30-50%。x86 固件建议在 x86 机器上编译。
