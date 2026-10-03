# ==========================================================================
# 安全加固块 —— 追加到 immo_diy.sh 中 `./scripts/feeds install -a` 之后
#
# 覆盖风险: 明文 HTTP 嗅探凭据 / 目录列举 / SSH 暴露 / Samba 匿名会话 /
#           登录无速率限制 / DNS 全网信任点无防护 / DHCP 换 IP 导致证书失效
#
# .config 需要: CONFIG_PACKAGE_luci-ssl=y
#               CONFIG_PACKAGE_libustream-openssl=y
#               CONFIG_PACKAGE_openssl-util=y      # 证书自动重签依赖
#
# 注意: 新版 ImmortalWrt 已移除 uhttpd-mod-tls 包, TLS 直接编译进 uhttpd 本体,
#       所以不要再写 CONFIG_PACKAGE_uhttpd-mod-tls=y —— 它会被 make defconfig
#       静默丢弃(无害但误导), HTTPS 能力由上述三个包保证。
#
# 路径前提: 本块必须运行在 OpenWrt 源码根目录 —— files/ 才会被打进固件的 /etc。
#           如果上层脚本此前 cd 进了子目录(见 SKILL.md 已知坑 #16), 后果是这些
#           加固文件会落到某个包的 root/ 子目录里, 编译不报错但永不生效。
# ==========================================================================
[ -n "$OPENWRT_ROOT" ] || OPENWRT_ROOT="$(pwd)"
cd "$OPENWRT_ROOT" || exit 1

mkdir -p files/etc/uci-defaults files/etc/dropbear files/etc/uhttpd files/usr/sbin

# ---- 1+2. 证书资产 —— 编译期不再固化任何私钥 -------------------------
# 设计要点:
#   固件镜像与公开仓库里都不再存 CA 私钥/服务器私钥。改为设备首次启动时
#   在本机生成, 落到 overlay 的 /etc/uhttpd/ (chmod 600) —— 每台设备的密钥
#   都不同, 攻击者即便拿到公开仓库里的固件也提取不到任何私钥。
#   uhttpd-cert-sync 的重签逻辑保持不变, 只是改用它本机生成的 CA,
#   因此 DHCP 换 IP 后的证书自适应能力完全保留。
#
#   cert-bootstrap 的序号必须是 97: 要保证它在 98(cert-sync hook) 与
#   99(security-hardening) 之前跑完 —— 否则加固脚本做 -s 检查时证书还没生成,
#   HTTPS 会被判定为"缺证书"而跳过。
cat > files/etc/uci-defaults/97-zz-cert-bootstrap <<'EOF_SECURITY_BOOTSTRAP'
#!/bin/sh
# ==============================================================================
#  首次启动: 现场生成私有 CA + uhttpd 服务器证书
#  路径: files/etc/uci-defaults/97-zz-cert-bootstrap
#  私钥只存本机, 不写入固件镜像, 不进公开仓库
# ==============================================================================
LOG=/root/security-hardening.log
DIR_=/etc/uhttpd

mkdir -p "$DIR_" 2>/dev/null || exit 0

# 没有 openssl 就直接放弃, 绝不改动/破坏现有证书
command -v openssl >/dev/null 2>&1 || {
    echo "[SKIP] cert-bootstrap: 无 openssl, 保持现有配置" >>"$LOG"; exit 0; }

# ---- 1. 私有 CA: 不存在才生成, 存在则复用(保证 IP 重签时始终是同一个 CA) --
if [ ! -s "$DIR_/ca.key" ] || [ ! -s "$DIR_/ca.crt" ]; then
    openssl ecparam -genkey -name prime256v1 -out "$DIR_/ca.key" 2>/dev/null
    openssl req -x509 -new -key "$DIR_/ca.key" -sha256 -days 3650 \
        -subj "/CN=HomeLab-Router-CA/O=HomeLab" \
        -out "$DIR_/ca.crt" 2>/dev/null
    echo "[OK] cert-bootstrap: 已生成本机私有 CA (ECDSA prime256v1)" >>"$LOG"
fi

# ---- 2. 服务器私钥 -------------------------------------------------------
if [ ! -s "$DIR_/uhttpd.key" ]; then
    openssl ecparam -genkey -name prime256v1 -out "$DIR_/uhttpd.key" 2>/dev/null
fi

chmod 600 "$DIR_/ca.key" "$DIR_/uhttpd.key" 2>/dev/null

# ---- 3. 用本机 CA 签发服务器证书 -----------------------------------------
# SAN 先只放主机名; 当前 LAN IP 随后由 uhttpd-cert-sync 检测并补签
if [ ! -s "$DIR_/uhttpd.crt" ]; then
    openssl req -new -key "$DIR_/uhttpd.key" \
        -subj "/CN=OpenWrt-N1/O=HomeLab" -out /tmp/.bootstrap.csr 2>/dev/null
    {
        echo "subjectAltName=DNS:OpenWrt-N1,DNS:OpenWrt-N1.local,DNS:openwrt.lan,DNS:router.lan,DNS:localhost"
        echo "extendedKeyUsage=serverAuth"
        echo "basicConstraints=CA:FALSE"
    } > /tmp/.bootstrap.ext
    openssl x509 -req -in /tmp/.bootstrap.csr \
        -CA "$DIR_/ca.crt" -CAkey "$DIR_/ca.key" -CAcreateserial \
        -out "$DIR_/uhttpd.crt" -days 3650 -sha256 -extfile /tmp/.bootstrap.ext 2>/dev/null
    rm -f /tmp/.bootstrap.csr /tmp/.bootstrap.ext
    echo "[OK] cert-bootstrap: 已签发服务器证书" >>"$LOG"
fi

exit 0
EOF_SECURITY_BOOTSTRAP
chmod +x files/etc/uci-defaults/97-zz-cert-bootstrap

# ---- 3. 证书自动同步（开机检测 IP 变化则重签）---------------------------
cat > files/usr/sbin/uhttpd-cert-sync <<'EOF_SECURITY_CERTSYNC'
#!/bin/sh
# ==============================================================================
#  uhttpd 证书 ↔ 当前 LAN IP 自动同步
#  路径: /usr/sbin/uhttpd-cert-sync
#  触发: /etc/rc.local（网络就绪后），每次开机检查一次
#
#  解决的问题:
#    X.509 不支持 IP 通配符，预置证书只能写死某个 IP。
#    设备改为 DHCP 自动获取后，访问新 IP 会出现名称校验失败
#    (ERR_CERT_COMMON_NAME_INVALID)。本脚本用固件内置的私有 CA，
#    按当前实际 IP 重新签发服务器证书 —— 客户端只要信任过 CA 一次，
#    之后 IP 怎么变都不用再手动信任。
# ==============================================================================

CA_CRT=/etc/uhttpd/ca.crt
CA_KEY=/etc/uhttpd/ca.key
SRV_KEY=/etc/uhttpd/uhttpd.key
SRV_CRT=/etc/uhttpd/uhttpd.crt
LOG=/root/security-hardening.log

# 前置检查：缺任何一样都不动，绝不把现有证书搞坏
[ -s "$CA_CRT" ] && [ -s "$CA_KEY" ] && [ -s "$SRV_KEY" ] || exit 0
command -v openssl >/dev/null 2>&1 || exit 0

# ---- 1. 取当前实际 LAN IP ---------------------------------------------------
LAN_IP=$(ifstatus lan 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address' 2>/dev/null)
[ -n "$LAN_IP" ] || LAN_IP=$(uci -q get network.lan.ipaddr)
[ -n "$LAN_IP" ] || exit 0

# ---- 2. 已在 SAN 里就什么都不做 ---------------------------------------------
# tr 把 SAN 行按逗号切成多行，避免 192.168.50.20 误匹配 192.168.50.200
# sed 去掉前导空格 —— openssl 输出的 SAN 行带缩进，不处理会永远匹配不上
# （后果是每次开机都白白重签一遍证书）
if [ -s "$SRV_CRT" ] && \
   openssl x509 -in "$SRV_CRT" -noout -text 2>/dev/null | tr ',' '\n' \
     | sed 's/^[[:space:]]*//' | grep -qx "IP Address:${LAN_IP}"; then
    exit 0
fi

# ---- 3. 用内置 CA 重新签发 ---------------------------------------------------
echo "[$(date '+%F %T')] cert-sync: LAN IP 变更为 ${LAN_IP}，重新签发服务器证书" >>"$LOG"

openssl req -new -key "$SRV_KEY" -subj "/CN=OpenWrt-N1/O=HomeLab" \
    -out /tmp/.uhttpd.csr 2>/dev/null || { echo "[FAIL] cert-sync: CSR 生成失败" >>"$LOG"; exit 1; }

{
    echo "subjectAltName=IP:${LAN_IP},IP:127.0.0.1,DNS:OpenWrt-N1,DNS:OpenWrt-N1.local,DNS:openwrt.lan,DNS:router.lan,DNS:localhost"
    echo "extendedKeyUsage=serverAuth"
    echo "basicConstraints=CA:FALSE"
} > /tmp/.uhttpd.ext

openssl x509 -req -in /tmp/.uhttpd.csr \
    -CA "$CA_CRT" -CAkey "$CA_KEY" -CAcreateserial \
    -out /tmp/.uhttpd.crt -days 3650 -sha256 -extfile /tmp/.uhttpd.ext 2>/dev/null

rm -f /tmp/.uhttpd.csr /tmp/.uhttpd.ext

if [ -s /tmp/.uhttpd.crt ]; then
    mv /tmp/.uhttpd.crt "$SRV_CRT"
    /etc/init.d/uhttpd restart >/dev/null 2>&1
    echo "[OK] cert-sync: 证书已更新为 IP:${LAN_IP}" >>"$LOG"
else
    rm -f /tmp/.uhttpd.crt
    echo "[FAIL] cert-sync: 签发失败，保留原证书" >>"$LOG"
    exit 1
fi

exit 0
EOF_SECURITY_CERTSYNC
chmod +x files/usr/sbin/uhttpd-cert-sync

# ---- 4. 把它幂等地挂进 rc.local（不覆盖已有内容）------------------------
cat > files/etc/uci-defaults/98-zz-cert-sync-hook <<'EOF_SECURITY_HOOK'
#!/bin/sh
# ==============================================================================
#  把证书自动同步挂进 rc.local（幂等，不覆盖已有内容）
#  路径: files/etc/uci-defaults/98-zz-cert-sync-hook
#
#  为什么用 hook 而不是直接发 files/etc/rc.local:
#    直接下发会覆盖用户已有的自定义 rc.local。这里改为幂等插入，
#    已经挂过就跳过，插在 exit 0 之前（没有 exit 0 就追加到文件末尾）。
# ==============================================================================

[ -x /usr/sbin/uhttpd-cert-sync ] || exit 0

touch /etc/rc.local 2>/dev/null || exit 0

if grep -q 'uhttpd-cert-sync' /etc/rc.local 2>/dev/null; then
    exit 0
fi

if grep -q '^exit 0' /etc/rc.local 2>/dev/null; then
    sed -i '/^exit 0/i /usr/sbin/uhttpd-cert-sync' /etc/rc.local
else
    echo '/usr/sbin/uhttpd-cert-sync' >> /etc/rc.local
fi

chmod +x /etc/rc.local
exit 0
EOF_SECURITY_HOOK
chmod +x files/etc/uci-defaults/98-zz-cert-sync-hook

# ---- 5. SSH 公钥（私钥由管理者离线保管，不得进固件）---------------------
cat > files/etc/dropbear/authorized_keys <<'EOF_SECURITY_PUBKEY'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIu6Qu8HhOLLnEINQIEB+amG65CS5V1CSVkhFa3KQ1/G openwrt-n1-root
EOF_SECURITY_PUBKEY

# ---- 6. 首次启动加固主脚本 ----------------------------------------------
cat > files/etc/uci-defaults/99-zz-security-hardening <<'EOF_SECURITY_UCI'
#!/bin/sh
# ==============================================================================
#  ImmortalWrt / OpenWrt 编译期安全加固  —— 首次启动自动执行，成功后自我删除
#  放置路径: openwrt/files/etc/uci-defaults/99-zz-security-hardening
#
#  设计原则:
#    1. 绝不自锁 —— 缺少前置资产(密钥/证书)时自动降级为告警，不关闭原通路
#    2. 幂等     —— 命名 section，重复执行不产生重复规则
#    3. 全程留痕 —— 输出到 /root/security-hardening.log
# ==============================================================================

LOG=/root/security-hardening.log
exec >>"$LOG" 2>&1
echo "===== [$(date '+%F %T')] security-hardening start ====="

# ------------------------------------------------------------------------------
# 开关区: 不需要的项改为 0
# ------------------------------------------------------------------------------
ENABLE_HTTPS=1           # 强制 HTTPS + 关闭目录列举
ENABLE_SSH_KEYONLY=1     # SSH 仅密钥登录(需 /etc/dropbear/authorized_keys 非空)
ENABLE_TTYD_LOCKDOWN=1   # ttyd Web 终端强制走系统 login 认证
DISABLE_TTYD=0           # 1 = 彻底停用 ttyd(不用 Web 终端就设 1，最安全)
ENABLE_SAMBA_LOCKDOWN=1  # Samba 收口到 LAN、关闭 NetBIOS
DISABLE_SAMBA=0          # 1 = 彻底停用 Samba(不用 SMB 就设 1)
ENABLE_RATE_LIMIT=1      # SSH/LuCI 登录限速
ENABLE_DNS_HARDEN=1      # dnsmasq 只服务本地子网 + 防 DNS rebinding
ENABLE_FIREWALL_LOCK=1   # 管理面仅允许 LAN 段访问

# ------------------------------------------------------------------------------
# 1. uhttpd / LuCI —— 强制 HTTPS、关闭目录列举
#    修复点: 明文 HTTP 嗅探凭据(高危) / Index of 目录列举 / 指纹暴露
# ------------------------------------------------------------------------------
if [ "$ENABLE_HTTPS" = 1 ]; then
    if [ -s /etc/uhttpd/uhttpd.crt ] && [ -s /etc/uhttpd/uhttpd.key ]; then
        uci -q batch <<UCI
set uhttpd.main.listen_http='0.0.0.0:80'
set uhttpd.main.listen_https='0.0.0.0:443'
set uhttpd.main.redirect_https='1'
set uhttpd.main.cert='/etc/uhttpd/uhttpd.crt'
set uhttpd.main.key='/etc/uhttpd/uhttpd.key'
set uhttpd.main.no_dirlist='1'
set uhttpd.main.no_symlinks='1'
set uhttpd.main.script_timeout='60'
set uhttpd.main.network_timeout='30'
set uhttpd.main.http_keepalive='20'
set uhttpd.main.max_requests='50'
set uhttpd.main.tcp_keepalive='1'
UCI
        uci commit uhttpd
        echo "[OK] uhttpd: HTTPS 强制跳转 + 目录列举已关闭"
    else
        echo "[SKIP] uhttpd: 未找到 /etc/uhttpd/uhttpd.crt|key，保持 HTTP（请在编译期预置证书）"
    fi
fi

# ------------------------------------------------------------------------------
# 2. dropbear —— SSH 收口
#    修复点: 22 端口全接口暴露 + root 密码登录 + 无失败锁定
# ------------------------------------------------------------------------------
if [ "$ENABLE_SSH_KEYONLY" = 1 ]; then
    if [ -s /etc/dropbear/authorized_keys ]; then
        chmod 600 /etc/dropbear/authorized_keys
        [ -f /etc/dropbear/id_dropbear_n1 ] && rm -f /etc/dropbear/id_dropbear_n1
        uci set dropbear.@dropbear[0].PasswordAuth='off'
        uci set dropbear.@dropbear[0].RootPasswordAuth='off'
        uci set dropbear.@dropbear[0].Interface='lan'
        uci commit dropbear
        echo "[OK] dropbear: 已切换为仅密钥登录 + 仅监听 LAN"
    else
        echo "[SKIP] dropbear: authorized_keys 为空，保持密码登录（避免自锁）"
    fi
fi

# ------------------------------------------------------------------------------
# 3. ttyd —— Web 终端收口  【最高危，务必保留这段】
#    修复点: 7681 端口默认无 HTTP 认证对外开放。
#            ttyd 若以 shell 启动(而非 login)，任何人打开网页即拿到 root shell，
#            不需要任何密码。CVE-2021-34182 描述的正是这类未授权访问
#            (该 CVE 在 1.7.0 修复，但「默认不启用认证」的配置风险依旧存在)。
#    注意: ttyd 走的是明文 HTTP，不受上面 uhttpd 的 HTTPS 加固保护。
# ------------------------------------------------------------------------------
if [ -f /etc/config/ttyd ]; then
    if [ "$DISABLE_TTYD" = 1 ]; then
        /etc/init.d/ttyd stop    >/dev/null 2>&1
        /etc/init.d/ttyd disable >/dev/null 2>&1
        echo "[OK] ttyd: 已停用（7681 不再监听）"
    elif [ "$ENABLE_TTYD_LOCKDOWN" = 1 ]; then
        # 强制终端进程走系统 login —— 连接后必须输入 root 密码
        uci set ttyd.@ttyd[0].command='/bin/login'
        # 只在 LAN 监听
        uci set ttyd.@ttyd[0].interface='lan'
        uci commit ttyd
        /etc/init.d/ttyd restart >/dev/null 2>&1
        echo "[OK] ttyd: 已强制 /bin/login 认证 + 仅 LAN"
    fi
fi

# ------------------------------------------------------------------------------
# 4. Samba —— 收口或停用
#    修复点: 445 端口暴露 + Guest 匿名会话可建立
# ------------------------------------------------------------------------------
if [ -f /etc/config/samba4 ]; then
    if [ "$DISABLE_SAMBA" = 1 ]; then
        /etc/init.d/samba4 stop    >/dev/null 2>&1
        /etc/init.d/samba4 disable >/dev/null 2>&1
        echo "[OK] samba4: 已停用"
    elif [ "$ENABLE_SAMBA_LOCKDOWN" = 1 ]; then
        uci set samba4.@samba[0].interface='lan'
        uci -q delete samba4.@samba[0].disable_netbios 2>/dev/null
        uci set samba4.@samba[0].disable_netbios='1'
        uci commit samba4
        /etc/init.d/samba4 restart >/dev/null 2>&1
        echo "[OK] samba4: 已收口到 LAN"
    fi
fi

# ------------------------------------------------------------------------------
# 5. 防火墙 —— 管理面来源限制 + 登录限速
#    修复点: LuCI 无登录失败限速 / 管理面暴露给非 LAN 区域 / ttyd 明文暴露
# ------------------------------------------------------------------------------
if [ "$ENABLE_FIREWALL_LOCK" = 1 ]; then
    uci -q delete firewall.mgmt_drop_http
    uci set firewall.mgmt_drop_http=rule
    uci set firewall.mgmt_drop_http.name='Sec-Deny-Mgmt-From-WAN'
    uci set firewall.mgmt_drop_http.src='wan'
    uci set firewall.mgmt_drop_http.proto='tcp'
    uci set firewall.mgmt_drop_http.dest_port='22 80 443 445 7681'
    uci set firewall.mgmt_drop_http.target='DROP'
fi

if [ "$ENABLE_RATE_LIMIT" = 1 ]; then
    # SSH: 每源 IP 每分钟最多 30 个新连接(突发 10)
    # 注意: 初版设 8/min 实测过紧 —— 连续开几个终端/scp/rsync 就会超限被 DROP,
    #       表现为 ssh 随机 "Operation timed out", 极易被误判为网络问题。
    #       30/min 对暴力破解仍是数量级压制, 对正常使用则绰绰有余。
    uci set firewall.ssh_rate_accept=rule
    uci set firewall.ssh_rate_accept.name='Sec-SSH-RateLimit'
    uci set firewall.ssh_rate_accept.src='lan'
    uci set firewall.ssh_rate_accept.proto='tcp'
    uci set firewall.ssh_rate_accept.dest_port='22'
    uci set firewall.ssh_rate_accept.limit='30/minute'
    uci set firewall.ssh_rate_accept.limit_burst='10'
    uci set firewall.ssh_rate_accept.target='ACCEPT'

    uci set firewall.ssh_rate_drop=rule
    uci set firewall.ssh_rate_drop.name='Sec-SSH-RateDrop'
    uci set firewall.ssh_rate_drop.src='lan'
    uci set firewall.ssh_rate_drop.proto='tcp'
    uci set firewall.ssh_rate_drop.dest_port='22'
    uci set firewall.ssh_rate_drop.target='DROP'

    # LuCI + ttyd: 每源 IP 每分钟最多 120 个新连接(突发 20)
    # 网页一次刷新会开多个连接(HTTP/1.1 并发 + 跳转 HTTPS), 30/min 会明显卡顿
    uci set firewall.web_rate_accept=rule
    uci set firewall.web_rate_accept.name='Sec-LuCI-RateLimit'
    uci set firewall.web_rate_accept.src='lan'
    uci set firewall.web_rate_accept.proto='tcp'
    uci set firewall.web_rate_accept.dest_port='80 443 7681'
    uci set firewall.web_rate_accept.limit='120/minute'
    uci set firewall.web_rate_accept.limit_burst='20'
    uci set firewall.web_rate_accept.target='ACCEPT'

    uci set firewall.web_rate_drop=rule
    uci set firewall.web_rate_drop.name='Sec-LuCI-RateDrop'
    uci set firewall.web_rate_drop.src='lan'
    uci set firewall.web_rate_drop.proto='tcp'
    uci set firewall.web_rate_drop.dest_port='80 443 7681'
    uci set firewall.web_rate_drop.target='DROP'

    echo "[OK] firewall: 登录限速已写入 (SSH 30/min burst 10, LuCI+ttyd 120/min burst 20)"
fi
uci commit firewall

# ------------------------------------------------------------------------------
# 6. dnsmasq —— DNS 加固
#    修复点: 该机是全网 DNS 信任点，被控即全网劫持
#    注意: 不开 DNSSEC —— 与 Clash/PassWall Fake-IP 返回 198.18.x 冲突
# ------------------------------------------------------------------------------
if [ "$ENABLE_DNS_HARDEN" = 1 ]; then
    uci set dhcp.@dnsmasq[0].localservice='1'
    uci set dhcp.@dnsmasq[0].rebind_protection='1'
    uci set dhcp.@dnsmasq[0].domainneeded='1'
    uci set dhcp.@dnsmasq[0].cachesize='4096'
    uci commit dhcp
    echo "[OK] dnsmasq: localservice + rebind 防护已启用"
fi

# ------------------------------------------------------------------------------
# 7. 应用
# ------------------------------------------------------------------------------
/etc/init.d/firewall restart >/dev/null 2>&1
/etc/init.d/uhttpd   restart >/dev/null 2>&1
/etc/init.d/dropbear restart >/dev/null 2>&1
/etc/init.d/dnsmasq  restart >/dev/null 2>&1
[ -f /etc/init.d/samba4 ] && /etc/init.d/samba4 restart >/dev/null 2>&1
[ -f /etc/init.d/ttyd ]   && /etc/init.d/ttyd   restart >/dev/null 2>&1

echo "===== [$(date '+%F %T')] security-hardening done ====="
exit 0
EOF_SECURITY_UCI
chmod +x files/etc/uci-defaults/99-zz-security-hardening

# ---- 7. 可选: 去掉登录页版本指纹 (argon 主题 footer) -------------------
# 如需隐藏 ImmortalWrt / argon 版本标识，取消注释
# sed -i 's|<a href="https://immortalwrt.org/"[^>]*</a>||g' \
#     package/luci-theme-argon/luasrc/view/themes/argon/footer.htm 2>/dev/null

echo "[immo_diy] security hardening files installed"
# ====================== 安全加固块结束 ==================================
