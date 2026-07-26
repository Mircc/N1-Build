#!/usr/bin/env python3
"""
Sync immo_diy.sh from OldCoding/openwrt_packit_arm upstream.
Preserves local default IP configuration block (192.168.50.200).
"""
import os
import sys
import subprocess
import tempfile

UPSTREAM_URL = "https://raw.githubusercontent.com/OldCoding/openwrt_packit_arm/refs/heads/main/immo_diy.sh"
LOCAL_FILE = "immo_diy.sh"

def run_cmd(cmd, check=True):
    """Run shell command."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"ERROR: {cmd}")
        print(result.stderr)
        sys.exit(1)
    return result

def download_upstream():
    """Download upstream immo_diy.sh."""
    tmp_file = "/tmp/upstream_immo_diy.sh"
    print(f"Downloading {UPSTREAM_URL}...")
    result = run_cmd(f"curl -sL {UPSTREAM_URL} -o {tmp_file}", check=False)
    
    # Check if file is valid
    if not os.path.exists(tmp_file) or os.path.getsize(tmp_file) == 0:
        print("ERROR: Downloaded file is empty")
        sys.exit(1)
    
    with open(tmp_file, 'r') as f:
        content = f.read()
    
    # Check if file contains expected content
    if 'svn_export' not in content and 'git clone' not in content:
        print("ERROR: Upstream file doesn't look like immo_diy.sh")
        sys.exit(1)
    
    print(f"Downloaded successfully ({len(content)} bytes)")
    return tmp_file

def get_default_ip_block():
    """Return default IP configuration block content."""
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
    """Merge upstream file with local default IP configuration."""
    # Read upstream file
    with open(upstream_file, 'r') as f:
        upstream_content = f.read()
    
    # Check if upstream file already has our default IP config block
    if '99-set-default-ip' in upstream_content:
        print("Upstream already has default IP block, using as-is")
        merged_content = upstream_content
    else:
        # Append default IP config block to end of file
        merged_content = upstream_content.rstrip() + get_default_ip_block() + '\n'
        print("Merged: upstream content + default IP block")
    
    # Write back to local file
    with open(LOCAL_FILE, 'w') as f:
        f.write(merged_content)

def check_changes():
    """Check if there are any changes."""
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
    
    # 1. Download upstream file
    upstream_file = download_upstream()
    
    # 2. Merge files
    merge_files(upstream_file)
    
    # 3. Check for changes
    if check_changes():
        print("=== Done: changes need to be committed ===")
        sys.exit(0)  # Exit code 0 = changes detected (workflow will commit)
    else:
        print("=== Done: no changes ===")
        sys.exit(78)  # Exit code 78 = no changes (workflow will skip commit)

if __name__ == "__main__":
    main()
