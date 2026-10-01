#!/usr/bin/env python3
"""
同步 OldCoding/openwrt_packit_arm 的 immo_diy.sh
保留本地的默认网络配置块（LAN 通过 DHCP 自动获取 IP）
"""
import os
import sys
import subprocess
import tempfile

UPSTREAM_URL = "https://raw.githubusercontent.com/OldCoding/openwrt_packit_arm/refs/heads/main/immo_diy.sh"
LOCAL_FILE = "immo_diy.sh"

def run_cmd(cmd, check=True):
    """运行 shell 命令"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"ERROR: {cmd}")
        print(result.stderr)
        sys.exit(1)
    return result

def download_upstream():
    """下载上游 immo_diy.sh"""
    tmp_file = "/tmp/upstream_immo_diy.sh"
    print(f"Downloading {UPSTREAM_URL}...")
    result = run_cmd(f"curl -sL {UPSTREAM_URL} -o {tmp_file}", check=False)
    
    # 检查文件是否有效
    if not os.path.exists(tmp_file) or os.path.getsize(tmp_file) == 0:
        print("ERROR: Downloaded file is empty")
        sys.exit(1)
    
    with open(tmp_file, 'r') as f:
        content = f.read()
    
    # 检查是否包含关键内容
    if 'svn_export' not in content and 'git clone' not in content:
        print("ERROR: Upstream file doesn't look like immo_diy.sh")
        sys.exit(1)
    
    print(f"Downloaded successfully ({len(content)} bytes)")
    return tmp_file

def get_default_ip_block():
    """返回默认IP配置块的内容"""
    return '''

# ===== 设置默认网络配置 (请勿删除) =====
echo "===== 设置默认网络配置 ====="
mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-set-default-ip << 'EOF'
#!/bin/sh
# LAN 通过 DHCP 自动获取 IP (自适应网络环境, 不再固定 IP)
uci set network.lan.proto='dhcp'
uci -q delete network.lan.ipaddr
uci -q delete network.lan.netmask
uci -q delete network.lan.gateway
uci -q delete network.lan.dns
uci commit network
# 设置系统主机名 (便于通过 http://OpenWrt-N1 访问, 无需知道 IP)
uci set system.@system[0].hostname='OpenWrt-N1'
uci commit system
# 本设备作为 DHCP 客户端, 从主路由自动获取 IP
# 不在 LAN 口提供 DHCP 服务, 避免与主路由冲突
uci set dhcp.lan.ignore='1'
uci commit dhcp
uci set dhcp.lan.dhcpv6='disabled'
uci set dhcp.lan.ra='disabled'
uci commit dhcp
exit 0
EOF
chmod +x files/etc/uci-defaults/99-set-default-ip

# ===== 设置欢迎信息 =====
mkdir -p files/etc

cat > files/etc/banner << 'EOF'

  _______                        __  _______ _____
 |       |___   _____   ___  __|  ||   _   |  _  |
 |   -   |   | |     | |   |/ _  ||   |   |     |
 |_______|___| |__|__| |___|_____||___|___|__|__|
        ImmortalWrt for N1/X86
        DHCP: 自动获取 IP (由主路由分配)
        Web: http://OpenWrt-N1  (主机名访问)
        User: root  Password: password

EOF
'''

# 本地独有的插件（上游没有，但我们的 .config 依赖，必须保留）
# 缺失会导致 make defconfig 找不到包 / 固件缺少对应插件
LOCAL_EXTRA_CLONES = """git clone --depth 1 https://github.com/immortalwrt/homeproxy package/luci-app-homeproxy
git clone --depth 1 https://github.com/nikkinikki-org/OpenWrt-nikki package/OpenWrt-nikki
git clone --depth 1 https://github.com/OldCoding/luci-theme-glass package/luci-theme-glass"""

# 需要在 feeds 中移除以避免版本冲突的目录（配合上面的本地克隆）
LOCAL_EXTRA_RM = """rm -rf feeds/luci/applications/luci-app-homeproxy"""


def apply_local_customizations(content):
    """应用本地定制：
    1) 移除我们明确不需要的插件（上游仍包含，但用户已要求删除）
    2) 补回上游没有、但本地 .config 依赖的插件克隆
    """
    unwanted = ('kodexplorer', 'ddns-go')
    kept_lines = []
    removed_lines = []

    for line in content.splitlines():
        stripped = line.strip()
        is_fetch = stripped.startswith('git clone') or stripped.startswith('svn_export')
        if is_fetch and any(keyword in line for keyword in unwanted):
            removed_lines.append(stripped)
            continue
        kept_lines.append(line)

    if removed_lines:
        print("Removed unwanted plugins (local customization):")
        for item in removed_lines:
            print(f"  - {item}")
    else:
        print("No unwanted plugins found to remove")

    result = '\n'.join(kept_lines)

    # 统一 tailscale 目录命名：上游导出为 package/luci-app-tailscale-community，
    # 但目录名决定编译产物包名，本地 .config 使用 CONFIG_PACKAGE_luci-app-tailscale=y。
    # 此处改回本地命名，避免同步后 tailscale 配置失配导致插件丢失。
    # 注意：只改目标目录（第3个参数），不改仓库内子目录名（第2个参数）。
    result = result.replace('"package/luci-app-tailscale-community"', '"package/luci-app-tailscale"')
    result = result.replace('package/luci-app-tailscale-community/root/', 'package/luci-app-tailscale/root/')

    # 上游 sbwml/luci-app-mosdns (v5) 已用 geo2txt 取代 v2dat:
    # 仓库顶层不再有 v2dat 目录（导出必然报 "Subdirectory v2dat not found"），
    # 而 luci-app-mosdns 依赖 geo2txt；若不导出 geo2txt，打包阶段会报
    # "unable to select packages: geo2txt (no such package)" 导致整个编译失败。
    v2dat_line = 'svn_export "v5" "v2dat" "package/v2dat" "https://github.com/sbwml/luci-app-mosdns"'
    geo2txt_line = 'svn_export "v5" "geo2txt" "package/geo2txt" "https://github.com/sbwml/luci-app-mosdns"'
    if v2dat_line in result:
        result = result.replace(v2dat_line, geo2txt_line)
        print("Replaced v2dat -> geo2txt (upstream mosdns renamed the tool)")
    elif 'geo2txt' not in result and 'sbwml/luci-app-mosdns' in result:
        # 兜底：上游若已删除该导出行，则在 luci-app-mosdns 导出后补一行
        lines = result.splitlines()
        for idx, line in enumerate(lines):
            if 'svn_export' in line and 'sbwml/luci-app-mosdns' in line and 'luci-app-mosdns"' in line:
                lines.insert(idx + 1, geo2txt_line)
                print("Added missing geo2txt export (not present upstream)")
                break
        result = '\n'.join(lines)

    # 补回本地独有插件：插入到 feeds install 之前（克隆必须早于 install）
    missing = [name for name in ('luci-theme-glass', 'homeproxy', 'OpenWrt-nikki')
               if name not in result]
    if missing:
        print(f"Re-adding local-only plugins missing upstream: {', '.join(missing)}")
        marker = './scripts/feeds install -a'
        block = LOCAL_EXTRA_RM + '\n' + LOCAL_EXTRA_CLONES
        if marker in result:
            result = result.replace(marker, block + '\n\n' + marker, 1)
        else:
            result = result.rstrip() + '\n\n' + block + '\n'
    else:
        print("All local-only plugins already present")

    return result + '\n'


def merge_files(upstream_file):
    """合并上游文件和本地默认IP配置（含旁路由模式）"""
    # 读取上游文件
    with open(upstream_file, 'r') as f:
        upstream_content = f.read()
    
    # 以旁路由配置为标志：缺失则说明上游未带我们的网络配置，需要追加
    if 'dhcp.lan.ignore' in upstream_content:
        print("Upstream already has 旁路由 config, using as-is")
        merged_content = upstream_content
    else:
        # 追加默认IP + 旁路由配置块到文件末尾
        merged_content = upstream_content.rstrip() + get_default_ip_block() + '\n'
        print("Merged: upstream content + default IP/旁路由 block")

    # 应用本地定制（移除不需要的插件）
    merged_content = apply_local_customizations(merged_content)
    
    # 写回本地文件
    with open(LOCAL_FILE, 'w') as f:
        f.write(merged_content)

def check_changes():
    """检查是否有变更"""
    result = run_cmd(f"git diff --quiet {LOCAL_FILE}", check=False)
    if result.returncode == 0:
        print("No changes detected")
        return False
    else:
        print("Changes detected:")
        run_cmd(f"git diff {LOCAL_FILE}")
        return True

def main():
    print("=== Syncing immo_diy.sh from upstream ===")
    
    # 1. 下载上游文件
    upstream_file = download_upstream()
    
    # 2. 合并文件
    merge_files(upstream_file)
    
    # 3. 检查变更
    if check_changes():
        print("=== Done: changes need to be committed ===")
        sys.exit(0)  # 退出码 0 = 有变更（workflow 会 commit）
    else:
        print("=== Done: no changes ===")
        sys.exit(78)  # 退出码 78 = 无变更（workflow 会跳过 commit）

if __name__ == "__main__":
    main()
