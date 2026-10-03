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

# 晶晨宝盒(luci-app-amlogic) 在线更新必须指向本人仓库 Mircc/N1-Build。
# 上游默认把更新地址指向第三方仓库 OldCoding/openwrt_packit_arm，
# 若不同步覆盖，用户点"在线更新"会拉到别人发布的固件。
# 后缀保持 .img.gz；内核本仓库不发布，仍用 ophub/kernel（该 option 未列出，不受影响）。
AMLOGIC_SED_BLOCK = r"""sed -i "\|amlogic_firmware_repo|s|'.*'|'https://github.com/Mircc/N1-Build'|" package/luci-app-amlogic/root/etc/config/amlogic
sed -i "\|amlogic_firmware_tag|s|'.*'|'N1-ImmortalWrt'|" package/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|breakingbadboy/OpenWrt|Mircc/N1-Build|g" package/luci-app-amlogic/luasrc/model/cbi/amlogic/amlogic_config.lua"""

# turboacc 注入的 lede 旧版 nftables fullcone 补丁，必须与 ImmortalWrt master 的
# nftables 1.1.6 隔离（hunk 全部失配 -> "Patch failed" -> nftables 编译失败 -> 整个编译中断）。
# fullcone 已由 ImmortalWrt 自带 002-nftables-add-fullcone 补丁提供，删除无副作用。
TURBOACC_PATCH_RM = "rm -f package/network/utils/nftables/patches/100-nftables-add-fullcone-expression-support.patch"

# 需要在 feeds 中移除以避免版本冲突的目录（配合上面的本地克隆）
LOCAL_EXTRA_RM = """rm -rf feeds/luci/applications/luci-app-homeproxy"""

# 上游 Tokisaki-Galaxy/luci-app-tailscale-community 的 JS bug：
#   htdocs/luci-static/resources/view/tailscale.js 使用了变量 lastDevicesStatus，
#   但全文件从未声明（只有 `let map;`），而文件首行是 'use strict'。
#   严格模式下给未声明变量赋值会直接抛 ReferenceError，结果是打开 LuCI 的
#   Tailscale 页面就报 "lastDevicesStatus is not defined"，状态轮询与设备列表刷新全断。
#   修法：在 `let map;` 后补一行 `let lastDevicesStatus;`。
TAILSCALE_EXPORT_MARKER = 'svn_export "master" "luci-app-tailscale-community"'
TAILSCALE_JS_FIX = (
    'sed -i "s|^let map;$|let map;\\nlet lastDevicesStatus;|" '
    'package/luci-app-tailscale/htdocs/luci-static/resources/view/tailscale.js'
)


def ensure_tailscale_js_fix(content):
    """幂等地确保 tailscale.js 的未声明变量修复存在（缺则补在导出行之后）。"""
    if TAILSCALE_JS_FIX in content:
        print("tailscale.js undeclared-variable fix already present")
        return content

    if TAILSCALE_EXPORT_MARKER not in content:
        print("WARNING: tailscale export line not found, JS fix skipped")
        return content

    lines = content.splitlines()
    for idx, line in enumerate(lines):
        if TAILSCALE_EXPORT_MARKER in line:
            lines[idx + 1:idx + 1] = [
                '# 修复上游 bug: tailscale.js 用了 lastDevicesStatus 但从未声明, 文件又是 \'use strict\',',
                '# 严格模式下给未声明变量赋值直接抛 ReferenceError -> 打开页面即报',
                '# "lastDevicesStatus is not defined"。补一行声明即可。',
                TAILSCALE_JS_FIX,
            ]
            print("Re-added tailscale.js undeclared-variable fix (avoid 'lastDevicesStatus is not defined')")
            break
    return '\n'.join(lines)

# 安全加固块的 golden source 与边界标记。
# 加固块内联在 immo_diy.sh 末尾，而 immo_diy.sh 每次半月同步会被上游整体覆盖，
# 一旦缺失管理面就会静默退回 HTTP 明文 + SSH 密码登录（最难察觉的一类故障）。
# 因此这里与 TURBOACC_PATCH_RM / AMLOGIC_SED_BLOCK 同样处理：
# 缺失则追加，存在则按 golden source 刷新，保证修复永远跟着同步一起分发。
SECURITY_GOLDEN = "security/immo_diy-security.sh"
SECURITY_START = "# ============ SECURITY_HARDENING_BLOCK_START ============"
SECURITY_END = "# ============ SECURITY_HARDENING_BLOCK_END ============"

# 「回到源码根目录」保护（已知坑 #16）：
# 上游脚本 `cd package` 后一路钻进 luci-app-openclash/root/etc/openclash/core
# 且从不返回；此后所有 files/ 写入若用相对路径，都会落进那个子目录，
# 最终被打成固件的 /etc/openclash/core/files/etc/... —— 编译不报错、却不执行。
# 后果是 DHCP 自适应、主机名、全部安全加固统统静默失效。
OPENWRT_ROOT_DEF = 'OPENWRT_ROOT="$(pwd)"'
OPENCLASH_CORE_MARKER = 'curl -sfL -o ./meta.tar.gz "$CORE_MATE"'


def ensure_root_cd(content):
    """幂等地确保：源码根路径被记录，且 openclash 段结束后回到根目录。

    - 缺任一者 -> 补回（被上游同步抹掉时自动恢复）
    - 都已存在 -> 原样返回（不重复叠加）
    """
    lines = content.splitlines()
    changed = False

    # 1) 顶部记录源码根绝对路径
    if OPENWRT_ROOT_DEF not in content:
        insert_at = 0
        for idx, line in enumerate(lines):
            if line.startswith('#!'):
                insert_at = idx + 1
                break
        lines[insert_at:insert_at] = [
            '',
            '# 记录 OpenWrt 源码根目录(绝对路径)',
            '# 下方 `cd package` 之后会一路 cd 进 luci-app-openclash 的子目录且不再返回,',
            '# 之后所有 files/ 相关写入若用相对路径就会落到',
            '#   package/luci-app-openclash/root/etc/openclash/core/files/...',
            '# 而不会被打进固件的 /etc (见 SKILL.md 已知坑 #16)。',
            '# 因此在深入子目录后用 cd "$OPENWRT_ROOT" 回到源码根。',
            OPENWRT_ROOT_DEF,
        ]
        content = '\n'.join(lines)
        lines = content.splitlines()
        changed = True

    # 2) openclash core 处理完毕后必须回到源码根
    cd_back = 'cd "$OPENWRT_ROOT" || exit 1'
    if OPENCLASH_CORE_MARKER in content and cd_back not in content:
        lines = content.splitlines()
        for idx, line in enumerate(lines):
            if OPENCLASH_CORE_MARKER in line:
                insert_at = idx + 1
                # 跨过 core 段收尾行（tar 解压 / chmod / rm）
                while insert_at < len(lines) and lines[insert_at].strip().startswith(('chmod', 'rm ')):
                    insert_at += 1
                lines[insert_at:insert_at] = [
                    '',
                    '# 回到源码根目录, 否则下方 files/ 会被写进 openclash 的 core 目录而不是固件的 /etc',
                    cd_back,
                    'echo "[immo_diy] 已回到源码根目录: $(pwd)"',
                ]
                content = '\n'.join(lines)
                changed = True
                break

    if changed:
        print("Re-added 'cd to source root' guard (without it files/ lands inside a package dir)")
    else:
        print("'cd to source root' guard already present")
    return content


def ensure_security_block(content):
    """幂等地确保安全加固块存在且与 golden source 一致。

    - 上游同步抹掉了整段 -> 从 golden source 追加回文件末尾
    - 已存在           -> 按 golden source 刷新标记之间的内容（修复/更新随同步自动生效）
    - golden 缺失      -> 只告警不阻断（避免同步任务因缺文件而整体失败）
    """
    try:
        with open(SECURITY_GOLDEN, 'r') as f:
            golden = f.read().rstrip('\n')
    except IOError:
        print(f"WARNING: golden source {SECURITY_GOLDEN} not found, security block skipped")
        return content

    if SECURITY_START in content and SECURITY_END in content:
        head, rest = content.split(SECURITY_START, 1)
        _old_block, tail = rest.split(SECURITY_END, 1)
        new_content = head + SECURITY_START + '\n' + golden + '\n' + SECURITY_END + tail
        if new_content == content:
            print("Security hardening block already up to date")
        else:
            print("Security hardening block refreshed from golden source")
        return new_content

    print("Re-added security hardening block (was missing/wiped by upstream sync)")
    return content.rstrip('\n') + '\n\n' + SECURITY_START + '\n' + golden + '\n' + SECURITY_END + '\n'


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

    # 补回 turboacc 的 nftables 补丁清理命令:
    # add_turboacc.sh 执行时会把 lede 针对旧版 nftables 写的 fullcone 补丁拷进源码树,
    # 该补丁与 ImmortalWrt master 的 nftables 1.1.6 不兼容 -> hunk 全部失配 ->
    # "Patch failed" -> nftables 编译失败 -> 整个编译中断 (N1 与 X86 均受影响)。
    # 该命令必须在 bash add_turboacc.sh 之后执行，且需在上游同步后存活。
    if TURBOACC_PATCH_RM not in result and 'add_turboacc.sh' in result:
        lines = result.splitlines()
        for idx, line in enumerate(lines):
            if 'bash add_turboacc.sh' in line and not line.strip().startswith('#'):
                insert_at = idx + 1
                # 跳过紧随的注释行（如被注释的备选 URL），插到它们之后
                while insert_at < len(lines) and lines[insert_at].strip().startswith('#'):
                    insert_at += 1
                block = [
                    '',
                    '# 移除 turboacc 注入的 lede 旧版 nftables fullcone 补丁:',
                    '# 该补丁针对旧版 nftables, 与 ImmortalWrt master 的 nftables 1.1.6 不兼容,',
                    '# 会导致 hunk 全部失配 -> "Patch failed" -> nftables 编译失败 -> 整个编译中断.',
                    '# fullcone NAT 已由 ImmortalWrt 自带的 002-nftables-add-fullcone 补丁提供,',
                    '# 移除此重复且过时的补丁不影响 fullcone 功能, 仅保留 turboacc 其余能力.',
                    TURBOACC_PATCH_RM,
                ]
                lines[insert_at:insert_at] = block
                print("Re-added turboacc nftables patch cleanup (must survive sync)")
                break
        result = '\n'.join(lines)
    elif TURBOACC_PATCH_RM in result:
        print("turboacc nftables patch cleanup already present")
    else:
        print("WARNING: add_turboacc.sh not found upstream, skipped patch cleanup")

    # 晶晨宝盒(luci-app-amlogic) 在线更新地址必须指向本人仓库。
    # 上游默认用 6 行 sed 把地址指向第三方仓库 OldCoding/openwrt_packit_arm，
    # 同步若不覆盖，用户点"在线更新"会拉到别人发布的固件。
    old_amlogic_markers = ('breakingbadboy', 'openwrt_packit_arm')
    if 'Mircc/N1-Build' not in result and 'package/luci-app-amlogic' in result:
        lines = result.splitlines()
        new_lines = []
        insert_at = None
        replaced = 0
        for line in lines:
            stripped = line.strip()
            is_old_amlogic_sed = (
                stripped.startswith('sed -i')
                and ('amlogic_config.lua' in line
                     or 'package/luci-app-amlogic/root/etc/config/amlogic' in line)
                and any(marker in line for marker in old_amlogic_markers)
            )
            if is_old_amlogic_sed:
                if insert_at is None:
                    insert_at = len(new_lines)
                replaced += 1
                continue
            new_lines.append(line)
        if replaced:
            new_lines[insert_at:insert_at] = AMLOGIC_SED_BLOCK.splitlines()
            result = '\n'.join(new_lines)
            print(f"Redirected luci-app-amlogic to Mircc/N1-Build (replaced {replaced} upstream sed lines)")
        else:
            print("WARNING: upstream amlogic sed lines not recognized, redirection skipped")
    elif 'Mircc/N1-Build' in result:
        print("luci-app-amlogic already points to Mircc/N1-Build")

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

    # 先确保「回到源码根」，否则下面补的 files/ 内容会落进 package 子目录
    result = ensure_root_cd(result)
    result = ensure_tailscale_js_fix(result)

    # 安全加固块必须与上面的定制一起在同步后存活（缺失 = 管理面退回明文 HTTP）
    result = ensure_security_block(result)

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
