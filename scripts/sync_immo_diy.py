#!/usr/bin/env python3
"""
同步 OldCoding/openwrt_packit_arm 的 immo_diy.sh
保留本地的默认IP配置块（192.168.50.200）
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
# 设置默认LAN IP
uci set network.lan.ipaddr='192.168.50.200'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.50.1'
uci set network.lan.dns='192.168.50.1'
uci commit network
# 设置系统主机名
uci set system.@system[0].hostname='OpenWrt-N1'
uci commit system
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
        Default IP: 192.168.50.200
        User: root  Password: password

EOF
'''

def merge_files(upstream_file):
    """合并上游文件和本地默认IP配置"""
    # 读取上游文件
    with open(upstream_file, 'r') as f:
        upstream_content = f.read()
    
    # 检查上游文件是否已有我们的默认IP配置块
    if '99-set-default-ip' in upstream_content:
        print("Upstream already has default IP block, using as-is")
        merged_content = upstream_content
    else:
        # 追加默认IP配置块到文件末尾
        merged_content = upstream_content.rstrip() + get_default_ip_block() + '\n'
        print("Merged: upstream content + default IP block")
    
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
