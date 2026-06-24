#!/bin/bash
# ============================================================
#  N1-Build 本地编译入口
#
#  用法:
#    ./build.sh n1        编译 N1 固件 (aarch64 + amlogic 打包)
#    ./build.sh aarch64   编译通用 aarch64 镜像
#    ./build.sh x86       编译 X86_64 固件
#
#  前提:
#    已安装 Docker + docker compose
#
#  输出:
#    output/   - 固件文件
#    cache/    - 编译缓存（自动持久化）
# ============================================================

set -e

TARGET="${1:-n1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/docker"

# 确保缓存和输出目录存在
mkdir -p "${SCRIPT_DIR}/cache/dl"
mkdir -p "${SCRIPT_DIR}/cache/build_dir"
mkdir -p "${SCRIPT_DIR}/cache/staging_dir"
mkdir -p "${SCRIPT_DIR}/cache/ccache"
mkdir -p "${SCRIPT_DIR}/output"

echo "============================================"
echo "  N1-Build: ${TARGET}"
echo "============================================"

case "${TARGET}" in
    n1|aarch64|x86)
        ;;
    *)
        echo "错误: 未知目标 '${TARGET}'，可用: n1 | aarch64 | x86"
        exit 1
        ;;
esac

cd "${DOCKER_DIR}"
BUILD_TARGET="${TARGET}" docker compose up --build

echo ""
echo "Done! 产物在: ${SCRIPT_DIR}/output/"
