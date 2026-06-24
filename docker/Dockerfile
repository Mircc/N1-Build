#
# N1-Build 本地编译环境
# 基于 Ubuntu 22.04，包含完整 OpenWrt 编译依赖
#
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# ===== 安装 OpenWrt 编译全部依赖 =====
# 来自 ophub/ubuntu2204-make-openwrt-depends
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ack antlr3 aria2 asciidoc autoconf automake autopoint \
    binutils bison btrfs-progs build-essential bzip2 ca-certificates \
    ccache cmake coreutils cpio curl device-tree-compiler \
    fastjar flex g++-multilib gawk gcc-multilib gettext git git-core \
    gperf gzip haveged help2man intltool jq libc6-dev-i386 \
    libelf-dev libfuse-dev libglib2.0-dev libgmp3-dev libltdl-dev \
    libmpc-dev libmpfr-dev libncurses5-dev libncursesw5-dev \
    libpython3-dev libreadline-dev libssl-dev libtool libz-dev \
    lrzsz mkisofs msmtp nano ninja-build ntpdate p7zip p7zip-full \
    patch pigz pkgconf python2.7 python3 python3-pip \
    python3-pyelftools python3-setuptools qemu-utils rsync scons \
    squashfs-tools swig tar texinfo uglifyjs unzip upx upx-ucl \
    vim wget xmlto xsltproc xxd xz-utils yasm zip zlib1g-dev zstd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===== ccache 加速重复编译 =====
ENV CCACHE_DIR=/root/.ccache
ENV CCACHE_MAXSIZE=20G
ENV PATH="/usr/lib/ccache:$PATH"

WORKDIR /workdir

CMD ["/workdir/scripts/entrypoint.sh"]
