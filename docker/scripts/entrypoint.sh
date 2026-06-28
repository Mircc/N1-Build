#!/bin/bash
set -e

# ============================================================
#  N1-Build 本地编译入口脚本
#  环境变量 BUILD_TARGET 控制编译目标:
#    n1      - 编译 aarch64 + amlogic S905D 打包
#    aarch64 - 编译通用 aarch64 镜像（跳过 amlogic 打包）
#    x86     - 编译 X86_64 固件
# ============================================================

TARGET="${BUILD_TARGET:-n1}"
NCPU="$(nproc)"

echo "============================================"
echo "  N1-Build Local Compile"
echo "  Target: ${TARGET}"
echo "  CPUs:   ${NCPU}"
echo "============================================"

# ============================================================
# 1. 克隆源码
# ============================================================
echo ">>> [1/8] Cloning ImmortalWrt source..."
if [ ! -d /workdir/openwrt/.git ]; then
    git clone --depth 1 https://github.com/immortalwrt/immortalwrt -b master /workdir/openwrt
else
    echo "Source already cloned, skipping."
fi

cd /workdir/openwrt
SOURCE_INFO=$(git show -s --date=short --format="Author: %an | date: %cd | commit: %s")
echo "Source: ${SOURCE_INFO}"

# ============================================================
# 2. 更新 feeds + 运行 immo_diy.sh
# ============================================================
echo ">>> [2/8] Updating feeds..."
./scripts/feeds update -a

echo ">>> [3/8] Running immo_diy.sh..."
chmod +x /workdir/immo_diy.sh
bash /workdir/immo_diy.sh

# ============================================================
# 4. 生成 .config
# ============================================================
echo ">>> [4/8] Generating .config for target: ${TARGET}..."
rm -f ./.config*
touch ./.config

# ----- 目标平台配置 -----
if [ "${TARGET}" = "x86" ]; then
    cat >> .config <<'X86_EOF'
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_DEVICE_generic=y
CONFIG_TARGET_ARCH_PACKAGES="x86_64"
CONFIG_DEFAULT_TARGET_OPTIMIZATION="-Os -pipe -march=nehalem"
CONFIG_CPU_TYPE="nehalem"
X86_EOF

    cat >> .config <<'X86_IMG_EOF'
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_IMAGES_GZIP=y
CONFIG_TARGET_EFI_IMAGES=y
CONFIG_TARGET_KERNEL_PARTSIZE=64
CONFIG_TARGET_ROOTFS_PARTSIZE=1024
X86_IMG_EOF

else
    # aarch64 (N1 & generic)
    cat >> .config <<'ARM_EOF'
CONFIG_TARGET_armsr=y
CONFIG_TARGET_armsr_armv8=y
CONFIG_TARGET_armsr_armv8_DEVICE_generic=y
CONFIG_TARGET_ARCH_PACKAGES="aarch64_generic"
CONFIG_DEFAULT_TARGET_OPTIMIZATION="-Os -pipe -mcpu=generic"
CONFIG_CPU_TYPE="generic"
ARM_EOF

    cat >> .config <<'ARM_IMG_EOF'
# CONFIG_TARGET_ROOTFS_INITRAMFS is not set
CONFIG_EXTERNAL_CPIO=""
# CONFIG_TARGET_ROOTFS_CPIOGZ is not set
CONFIG_TARGET_ROOTFS_TARGZ=y
CONFIG_TARGET_UBIFS_FREE_SPACE_FIXUP=y
CONFIG_TARGET_UBIFS_JOURNAL_SIZE=""
CONFIG_TARGET_IMAGES_GZIP=y
# CONFIG_TARGET_ROOTFS_PERSIST_VAR is not set
ARM_IMG_EOF
fi

# ----- 通用配置 (USB / IPv6 / 主题 / 软件包) -----
cat >> .config <<'COMMON_EOF'
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb-dwc2=y
CONFIG_PACKAGE_kmod-usb-dwc3=y
CONFIG_PACKAGE_kmod-usb-ehci=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-extras=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y
CONFIG_PACKAGE_kmod-usb-xhci-hcd=y
CONFIG_PACKAGE_kmod-usb-ohci=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y

CONFIG_PACKAGE_dnsmasq_full_dhcpv6=y
CONFIG_PACKAGE_ip6tables-extra=y
CONFIG_PACKAGE_ip6tables-mod-nat=y
CONFIG_PACKAGE_ipv6helper=y

CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_luci-theme-design=y
CONFIG_PACKAGE_luci-theme-glass=y

CONFIG_PACKAGE_php8=y
CONFIG_PHP8_LIBXML=y
CONFIG_PHP8_DOM=y
CONFIG_PHP8_GETTEXT=y
CONFIG_PHP8_INTL=y
CONFIG_PHP8_SYSTEMTZDATA=y
CONFIG_PACKAGE_perl=y
CONFIG_PACKAGE_perl-http-date=y
CONFIG_PACKAGE_perlbase-file=y
CONFIG_PACKAGE_perlbase-getopt=y
CONFIG_PACKAGE_perlbase-time=y
CONFIG_PACKAGE_perlbase-unicode=y
CONFIG_PACKAGE_perlbase-utf8=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_attr=y
CONFIG_PACKAGE_btrfs-progs=y
CONFIG_BTRFS_PROGS_ZSTD=y
CONFIG_PACKAGE_chattr=y
CONFIG_PACKAGE_dosfstools=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_f2fsck=y
CONFIG_PACKAGE_lsattr=y
CONFIG_PACKAGE_mkf2fs=y
CONFIG_PACKAGE_xfs-fsck=y
CONFIG_PACKAGE_xfs-mkfs=y
CONFIG_PACKAGE_bsdtar=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_gawk=y
CONFIG_PACKAGE_getopt=y
CONFIG_PACKAGE_losetup=y
CONFIG_PACKAGE_tar=y
CONFIG_PACKAGE_uuidgen=y
COMMON_EOF

# ----- N1/aarch64 额外软件包 -----
if [ "${TARGET}" != "x86" ]; then
    cat >> .config <<'ARM_PKG_EOF'
CONFIG_PACKAGE_autocore-arm=y
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_libsensors=y
CONFIG_PACKAGE_ariang=y
CONFIG_PACKAGE_bind-host=y
CONFIG_PACKAGE_default-settings-chn=y
CONFIG_PACKAGE_ca-certificates=y
CONFIG_PACKAGE_lsof=y
CONFIG_PACKAGE_acpid=y
CONFIG_PACKAGE_hostapd-common=y
CONFIG_PACKAGE_kmod-sched-red=y
CONFIG_PACKAGE_smartmontools-drivedb=y
CONFIG_PACKAGE_pigz=y
CONFIG_PACKAGE_iw=y
ARM_PKG_EOF
fi

# ----- X86 额外: 网络驱动 + 软件包 -----
if [ "${TARGET}" = "x86" ]; then
    cat >> .config <<'X86_NET_EOF'
CONFIG_PACKAGE_kmod-igb=y
CONFIG_PACKAGE_kmod-igc=y
CONFIG_PACKAGE_kmod-e1000=y
CONFIG_PACKAGE_kmod-e1000e=y
CONFIG_PACKAGE_kmod-ixgbe=y
CONFIG_PACKAGE_kmod-r8169=y
CONFIG_PACKAGE_kmod-mii=y
X86_NET_EOF

    cat >> .config <<'X86_PKG_EOF'
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_libsensors=y
CONFIG_PACKAGE_ariang=y
CONFIG_PACKAGE_bind-host=y
CONFIG_PACKAGE_default-settings-chn=y
CONFIG_PACKAGE_ca-certificates=y
CONFIG_PACKAGE_lsof=y
CONFIG_PACKAGE_pigz=y
CONFIG_PACKAGE_iw=y
X86_PKG_EOF
fi

# ----- 第三方插件（所有平台通用） -----
cat >> .config <<'PLUGINS_EOF'
CONFIG_PACKAGE_luci-app-passwall=y
CONFIG_PACKAGE_luci-app-passwall2=y
CONFIG_PACKAGE_luci-app-openclash=y
CONFIG_PACKAGE_luci-app-mosdns=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_luci-app-filebrowser=y
CONFIG_PACKAGE_luci-app-netdata=y
CONFIG_PACKAGE_luci-app-pushbot=y
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-app-openlist2=y
CONFIG_PACKAGE_luci-app-qbittorrent=y
CONFIG_PACKAGE_qbittorrent-ee=y
CONFIG_PACKAGE_rclone=y
PLUGINS_EOF

# ----- N1/aarch64 专用: amlogic 固件管理 -----
if [ "${TARGET}" != "x86" ]; then
    cat >> .config <<'AMLOGIC_EOF'
CONFIG_PACKAGE_luci-app-amlogic=y
AMLOGIC_EOF
fi

sed -i 's/^[ \t]*//g' ./.config
make defconfig

# ============================================================
# 5. 下载软件包源码
# ============================================================
echo ">>> [5/8] Downloading packages..."
make download -j8 2>&1 | tail -20
find dl -size -1024c -exec rm -f {} \; 2>/dev/null || true

# ============================================================
# 6. 编译
# ============================================================
echo ">>> [6/8] Compiling firmware (${NCPU} threads)..."
make -j${NCPU} 2>&1 | tee /workdir/output/build.log

echo "Compilation finished successfully!"

# ============================================================
# 7. 整理输出文件
# ============================================================
echo ">>> [7/8] Organizing output files..."
cp -f .config /workdir/output/config.txt

# 打包 packages
cd bin/packages
tar -zcf /workdir/output/Packages.tar.gz ./*
cd /workdir/openwrt

# ============================================================
# 8. 按目标处理输出
# ============================================================
echo ">>> [8/8] Finalizing output for target: ${TARGET}..."

OUTDIR="/workdir/output"
mkdir -p "${OUTDIR}"

case "${TARGET}" in
    n1)
        # ----- N1: amlogic 打包 -----
        echo ">>> Packaging for N1 (s905d)..."
        PACK_DIR="/workdir/amlogic-pack"
        if [ ! -d "${PACK_DIR}/.git" ]; then
            git clone --depth 1 https://github.com/OldCoding/amlogic-s9xxx-openwrt "${PACK_DIR}"
        fi
        cd "${PACK_DIR}"

        # 复制 rootfs
        mkdir -p openwrt-armsr openwrt/out
        cp -v /workdir/openwrt/bin/targets/*/*/*rootfs.tar.gz openwrt-armsr/

        # 运行打包
        KERNEL_VER=$(cat /workdir/KernelVersion)
        echo "Kernel version: ${KERNEL_VER}"
        ./remake -b s905d \
                 -r OldCoding/openwrt_packit_arm \
                 -u stable \
                 -k "${KERNEL_VER}" \
                 -a true \
                 -n Mircc

        # 复制 N1 产物
        cp -rv openwrt/out/* "${OUTDIR}/"
        echo ">>> N1 output:"
        ls -lh "${OUTDIR}/"

        # ----- 通用 aarch64 镜像也一起输出 -----
        echo ">>> Copying generic aarch64 images..."
        cp -v /workdir/openwrt/bin/targets/armsr/armv8/*.img.gz "${OUTDIR}/" 2>/dev/null || echo "(no .img.gz found)"
        ;;

    aarch64)
        # ----- 只输出通用 aarch64 镜像 -----
        echo ">>> Copying generic aarch64 images..."
        AARCH_DIR="/workdir/openwrt/bin/targets/armsr/armv8"
        if ls ${AARCH_DIR}/*.img.gz 1>/dev/null 2>&1; then
            cp -v ${AARCH_DIR}/*.img.gz "${OUTDIR}/"
            cp -v ${AARCH_DIR}/*rootfs.tar.gz "${OUTDIR}/" 2>/dev/null || true
        else
            echo "No .img.gz files found at ${AARCH_DIR}"
        fi
        echo ">>> aarch64 output:"
        ls -lh "${OUTDIR}/"
        ;;

    x86)
        # ----- X86_64 输出 -----
        echo ">>> Copying X86_64 images..."
        X86_DIR="/workdir/openwrt/bin/targets/x86/64"
        if ls ${X86_DIR}/*.img.gz 1>/dev/null 2>&1; then
            cp -v ${X86_DIR}/*.img.gz "${OUTDIR}/"
        fi
        if ls ${X86_DIR}/*.vmdk 1>/dev/null 2>&1; then
            cp -v ${X86_DIR}/*.vmdk "${OUTDIR}/" 2>/dev/null || true
        fi
        # 计算 MD5
        cd "${OUTDIR}"
        md5sum *.gz > sha256sums.txt 2>/dev/null || true
        echo ">>> X86 output:"
        ls -lh "${OUTDIR}/"
        ;;
esac

# ============================================================
# 完成
# ============================================================
echo ""
echo "============================================"
echo "  BUILD COMPLETE"
echo "  Output: ./output/"
echo "============================================"
ls -lh "${OUTDIR}/"
