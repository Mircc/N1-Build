#!/bin/bash
# immo_diy.sh — N1-Build 第三方软件源 + 默认网络配置
# 由 GitHub Actions / Docker entrypoint 调用（cd openwrt 后执行）
# 注意：此脚本只 clone 源码，必须在 .config 里加 CONFIG_PACKAGE_*=y 才会编译进固件

# ===== 0. 缓存根目录（避免重复 clone）=====
DL_CACHE="/tmp/openwrt_pkg_cache"
[ -d "$DL_CACHE" ] || mkdir -p "$DL_CACHE"

# svn_export：用 git 缓存整仓，再拷需要的子目录（GitHub 禁用 SVN）
svn_export() {
    local BRANCH=$1 SUB_DIR=$2 TARGET_DIR=$3 REPO_URL=$4
    local REPO_IDENTIFIER=$(echo "$REPO_URL" | sed 's|https://github.com/||' | tr '/' '-')
    local CACHE_NAME="${REPO_IDENTIFIER}-${BRANCH}"
    local LOCAL_REPO_DIR="$DL_CACHE/$CACHE_NAME"
    if [ ! -d "$LOCAL_REPO_DIR" ]; then
        git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$LOCAL_REPO_DIR" >/dev/null 2>&1
    fi
    [ -d "$TARGET_DIR" ] || mkdir -p "$TARGET_DIR"
    if [ -d "$LOCAL_REPO_DIR/$SUB_DIR" ]; then
        cp -af "$LOCAL_REPO_DIR/$SUB_DIR/." "$TARGET_DIR/"
        rm -rf "$TARGET_DIR/.git"
    else
        echo "Error: $SUB_DIR not found in $REPO_URL"; return 1
    fi
}

# ===== 1. 删除官方 feeds 中与三方源冲突的包（必须先删）=====
rm -rf feeds/luci/applications/luci-app-adguardhome
rm -rf feeds/luci/applications/luci-app-dockerman
rm -rf feeds/luci/applications/luci-app-homeproxy
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-filebrowser
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/utils/docker
rm -rf feeds/packages/utils/dockerd
rm -rf feeds/packages/utils/containerd
rm -rf feeds/packages/utils/runc
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-design

# ===== 2. 克隆三方源 =====
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon feeds/luci/themes/luci-theme-argon
git clone --depth 1 https://github.com/zykfork/luci-app-pushbot package/luci-app-pushbot
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth 1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata
git clone --depth 1 https://github.com/fw876/helloworld package/helloworld
git clone --depth 1 https://github.com/Mircc/luci-app-adguardhome package/adguardhome
git clone --depth 1 https://github.com/sbwml/luci-app-openlist2 package/openlist
git clone --depth 1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/openwrt-passwall-packages
git clone --depth 1 https://github.com/Mircc/luci-app-filebrowser package/luci-app-filebrowser
git clone --depth 1 https://github.com/Mircc/luci-theme-glass package/luci-theme-glass
git clone --depth 1 https://github.com/sbwml/luci-app-dockerman feeds/luci/applications/luci-app-dockerman
git clone --depth 1 https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy
git clone --depth 1 https://github.com/Mircc/OpenWrt-qBittorrent-Enhanced-Edition package/openwrt-qbee
git clone --depth 1 https://github.com/sbwml/packages_utils_docker feeds/packages/utils/docker
git clone --depth 1 https://github.com/sbwml/packages_utils_dockerd feeds/packages/utils/dockerd
git clone --depth 1 https://github.com/sbwml/packages_utils_containerd feeds/packages/utils/containerd
git clone --depth 1 https://github.com/sbwml/packages_utils_runc feeds/packages/utils/runc
svn_export "master" "luci-app-tailscale-community" "package/luci-app-tailscale" "https://github.com/Tokisaki-Galaxy/luci-app-tailscale-community"
svn_export "main" "luci-app-passwall2" "package/luci-app-passwall2" "https://github.com/Openwrt-Passwall/openwrt-passwall2"
svn_export "main" "luci-app-passwall" "package/luci-app-passwall" "https://github.com/Openwrt-Passwall/openwrt-passwall"
svn_export "dev" "luci-app-openclash" "package/luci-app-openclash" "https://github.com/vernesong/OpenClash"
svn_export "main" "luci-app-amlogic" "package/luci-app-amlogic" "https://github.com/ophup/luci-app-amlogic"
svn_export "v5" "luci-app-mosdns" "package/luci-app-mosdns" "https://github.com/sbwml/luci-app-mosdns"
svn_export "v5" "mosdns" "package/mosdns" "https://github.com/sbwml/luci-app-mosdns"

# 扁平化仓库处理
mv ./package/openlist/* ./package/ && rm -rf ./package/openlist
mv ./package/adguardhome/* ./package/ && rm -rf ./package/adguardhome
mv ./package/openwrt-qbee/* ./package/ && rm -rf ./package/openwrt-qbee

# ===== 3. 安装插件 =====
./scripts/feeds update -i
./scripts/feeds install -a

# ===== 4. 默认网络配置 (LAN DHCP 自动获取) =====
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/99-set-default-ip << 'INNER_EOF'
#!/bin/sh
# LAN 通过 DHCP 自动获取 IP (自适应网络环境, 不再固定 IP)
uci set network.lan.proto='dhcp'
uci -q delete network.lan.ipaddr
uci -q delete network.lan.netmask
uci -q delete network.lan.gateway
uci -q delete network.lan.dns
uci commit network
# 本机作 DHCP 客户端获取 IP, 不在 LAN 口提供服务(避免与主路由冲突)
uci set dhcp.lan.ignore='1'
uci set dhcp.lan.ra='disabled'
uci set dhcp.lan.dhcpv6='disabled'
uci commit dhcp
uci set system.@system[0].hostname='OpenWrt-N1'
uci commit system
exit 0
INNER_EOF
chmod +x files/etc/uci-defaults/99-set-default-ip

# ===== 5. 欢迎信息 =====
mkdir -p files/etc
cat > files/etc/banner << 'BANNER_EOF'

  _______                        __  _______ _____
 |       |___   _____   ___  __|  ||   _   |  _  |
 |   -   |   | |     | |   |/ _  ||   |   |     |
 |_______|___| |__|__| |___|_____||___|___|__|__|
        ImmortalWrt for N1/X86
        DHCP: 自动获取 IP (由主路由分配)
        Web: http://OpenWrt-N1  (主机名访问)
        User: root  Password: password

BANNER_EOF

# ===== 6. 个性化（按需调整）=====
sed -i "s|services|nas|g" package/luci-app-openlist2/root/usr/share/luci/menu.d/luci-app-openlist2.json 2>/dev/null || true
sed -i "s|services|vpn|g" package/luci-app-tailscale/root/usr/share/luci/menu.d/luci-app-tailscale-community.json 2>/dev/null || true
# NTP 服务器
cd package
sed -i "s|\'time1\.apple\.com\'|\'0\.openwrt\.pool\.ntp\.org\'|g" base-files/files/bin/config_generate
sed -i "s|\'time1\.google\.com\'|\'1\.openwrt\.pool\.ntp\.org\'|g" base-files/files/bin/config_generate
sed -i "s|\'time\.cloudflare\.com\'|\'2\.openwrt\.pool\.ntp\.org\'|g" base-files/files/bin/config_generate
sed -i "s|\'pool\.ntp\.org\'|\'3\.openwrt\.pool\.ntp\.org\'|g" base-files/files/bin/config_generate
cd ..

echo "===== immo_diy.sh completed ====="
