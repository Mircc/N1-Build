# ==========================================================================
# 安全加固块 —— 追加到 immo_diy.sh 中 `./scripts/feeds install -a` 之后
#
# 覆盖风险: 明文 HTTP 嗅探凭据 / 目录列举 / SSH 暴露 / Samba 匿名会话 /
#           登录无速率限制 / DNS 全网信任点无防护 / DHCP 换 IP 导致证书失效
#
# .config 需要: CONFIG_PACKAGE_luci-ssl=y
#               CONFIG_PACKAGE_uhttpd-mod-tls=y
#               CONFIG_PACKAGE_libustream-openssl=y
#               CONFIG_PACKAGE_openssl-util=y      # 证书自动重签依赖
# ==========================================================================
mkdir -p files/etc/uci-defaults files/etc/dropbear files/etc/uhttpd files/usr/sbin

# ---- 1. 内置私有 CA（用于 DHCP 换 IP 后重新签发服务器证书）---------------
cat > files/etc/uhttpd/ca.crt <<'EOF_SECURITY_CACRT'
-----BEGIN CERTIFICATE-----
MIIDAjCCAeqgAwIBAgIJAIlXuoM/3CMrMA0GCSqGSIb3DQEBCwUAMC4xGjAYBgNV
BAMMEUhvbWVMYWItUm91dGVyLUNBMRAwDgYDVQQKDAdIb21lTGFiMB4XDTI2MTAw
MjAzMjEwMVoXDTM2MDkyOTAzMjEwMVowLjEaMBgGA1UEAwwRSG9tZUxhYi1Sb3V0
ZXItQ0ExEDAOBgNVBAoMB0hvbWVMYWIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
ggEKAoIBAQDDzOopGgviHwZFUkrkXmlVK8rKLHVjVGZcPFWz7BUYqcOuXzqKGeEm
ewkLL1MqgzhJVqgdnL1aom5avuinhf8hVJrMapQZ4kVQdweCVOA3uiVOnVXhie9K
oK5ysxG7yltOAZcU2MjZ9uXj9oIavJa99vbnzSCVg1PZBSNUvCAkqW08WRFU+Nqe
BaPbBeiBvnmg6E6C34xB4le3DtkiYlEERvnPTWuYFyaCC0rJpK3Wh3Xl7KX8FRNw
cuzeNKprCnXiQwXAW2ayXT5l3HKd7IBjpRX0YialbpiuU2Cezo6XLoHY+1BJ5yMg
4jYclci5crrEBeVYaAkv21OA7Gd5NQC7AgMBAAGjIzAhMA8GA1UdEwEB/wQFMAMB
Af8wDgYDVR0PAQH/BAQDAgEGMA0GCSqGSIb3DQEBCwUAA4IBAQCfdGgPEOFG1Dh8
oAHlo1dWbE/VvofBsnhoCZ5AH5IXt9c0VwqsH0eWdxmcq4sOOb9uaCHbO0p4LPOo
apLVNBUJP2dKm2+gpn53EEL5lOEV+uQb/ZYvR+n73IhLLRuRB0VFrWgqO18NM3xd
aR5wvAI0O10PTLxKza4lTv4+rn1t6OO9K5/DwECLmIg5FJtrVndFiX7B8oXyXRwl
Ix4HNHjwjyOVQrGC3/6ce5loVYXSNp9mhZ/GINqf7QmT0uSn5cLFeol3KSBLXmO1
G2K6B0m6kLG872jGu0qZqqBOwu+LgXBaJ/6a+eTWpZ9Bep+vWmyc94DWXwX+dsRB
2l34Qg/S
-----END CERTIFICATE-----
EOF_SECURITY_CACRT

cat > files/etc/uhttpd/ca.key <<'EOF_SECURITY_CAKEY'
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAw8zqKRoL4h8GRVJK5F5pVSvKyix1Y1RmXDxVs+wVGKnDrl86
ihnhJnsJCy9TKoM4SVaoHZy9WqJuWr7op4X/IVSazGqUGeJFUHcHglTgN7olTp1V
4YnvSqCucrMRu8pbTgGXFNjI2fbl4/aCGryWvfb2580glYNT2QUjVLwgJKltPFkR
VPjangWj2wXogb55oOhOgt+MQeJXtw7ZImJRBEb5z01rmBcmggtKyaSt1od15eyl
/BUTcHLs3jSqawp14kMFwFtmsl0+ZdxyneyAY6UV9GImpW6YrlNgns6Oly6B2PtQ
SecjIOI2HJXIuXK6xAXlWGgJL9tTgOxneTUAuwIDAQABAoIBAQCP0AqNddwUkcUB
VZg8dDvZmviv1kfCVVN5m7c3F8fG/aoEgV114dxFb0kNNg1XxFmrRELmvSE3WObF
MEOiCAGEcafhTMbK3C8dEtApIj4tsEOGonlZ1v4zSiHXjT8RN2gou3JElZWwwm/I
KF8XVD1D+gkP6NJt/q+vTt7MdgEF60IVZcBTTDuuvXHKDMyiQ3cZhP+yxJuprsGI
WkPB67gTwxtkKAXNOoB7p6JvD6wEYplCp5lNx3Wc7GRQl/eta6vAnL8PMitOiC/X
/y/TUOHlyxlTFU6uNhYlPcqJfA8eHIQ9m8n6a4vw3qeoX2P/KgQio/lr0gUds8/J
A0Fp1xHBAoGBAO4eezYeGihcVetGg5IjwQnFR+EZ/q7+rWFZ2az4qUBa6Vhyo0N0
xgrN95rD1o9D73KGZqHG3uqSLw3I8W6dF2tPZlGb60XhgJG85if925qEj1DxmW69
AKA1k5RINBqOR00kwETycUl7uuIP/ElW1N5+iMD0BTTAdNPcx7/n/xPfAoGBANKA
6jTwQvuiATyPlM8z/xbISfeZyJQtaRBzGUhvE2wjdMeoSyQRciLcaPXOJMT90UAO
+qgm6Xk266quqUH80UDh3hwE3LwwyPESvKR4J2tuRMmod0aWwhqIjjDLJQXUK09I
t2inoWIx1v+ZsAYYCzqdLQGXKvY3322Tcu0wKQ6lAoGALhIntKjOVtDGrubNvhC8
4K8S4TKuXB1aXmOMAjN6S8FLNJm5jOujBaQkLAWIFeAHDBmE8fgQWUI/aGNgkw5B
4blTCqcoNjUTMx9hSIuNWbAcKoUUMqDO5jB3hVETA7BTi1F5Ad4GnTkbR3HgVjA+
r22799k+yJ4T/InS/AZfC/ECgYAEGtt2WNEVkx0vDyW5vKvWx+UZXPhaW2BXH8d4
cCIS08YtNozwkR6Gq4GoeXKiHMj91Mzyhn+7C2UhGPLYBJQYDc+FAFtFmDXy7Yic
NHOgVrAktpJM4Be86LjNHskEChUmIKbi9ZHiFlK4/Ug/diyR4grEoywFTSWgP2XY
Vj4WuQKBgHdb5nQezWZaORaEpI3sXXeMB1pxj+Thb9K+gAg39DozO7yOGr+e4oRu
puFeXvKZTxz3XhjftkI+MyWDWaVlpEKKKO9zb13YgTV+zf/4NcMmL2D6LTxXyqCu
15OthLMwVhzjMp/BWDmbtq4/hlFn/+mNWPquAv0WKTAS9Z82RhkL
-----END RSA PRIVATE KEY-----
EOF_SECURITY_CAKEY

# ---- 2. CA 签发的服务器证书（10 年，SAN 含 IP 与多个主机名）-------------
cat > files/etc/uhttpd/uhttpd.crt <<'EOF_SECURITY_CERT'
-----BEGIN CERTIFICATE-----
MIIDUzCCAjugAwIBAgIJAKyD0egdnftvMA0GCSqGSIb3DQEBCwUAMC4xGjAYBgNV
BAMMEUhvbWVMYWItUm91dGVyLUNBMRAwDgYDVQQKDAdIb21lTGFiMB4XDTI2MTAw
MjAzMjExMFoXDTM2MDkyOTAzMjExMFowJzETMBEGA1UEAwwKT3BlbldydC1OMTEQ
MA4GA1UECgwHSG9tZUxhYjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
ALz3OU8xVcrn2eZzytjECDj/BPcKiG3iY5w6pVjPM0IIlB7nIGHvszE5mimXsZg4
mhiaiUz6rFNYoLBs1bD9y8EXWHsPFnXnAXt8fEtnLNHxl5HxW15B+dnVmxSIl6m6
nHdwbbj+0t3Hk85PZWJ31UaMftOmDXluE4lOncapsVZpBYwv7+0u/guhKNXbTBfw
F83bIal0NEoy3vElsd8fzPU/8YCkheIyoIR2TpcmfjeSrDWp5ssc1vnpa5BpE++G
qwn+N43Gq9r4byTiBTBlUkeQzo04L+Q9JbPSKDjc2Ye+RAsXjxomN+m0bJ3xde7n
jWMpWIZcO7rOQr0QF/y7De8CAwEAAaN7MHkwVwYDVR0RBFAwTocEwKgyyIcEfwAA
AYIKT3BlbldydC1OMYIQT3BlbldydC1OMS5sb2NhbIILb3BlbndydC5sYW6CCnJv
dXRlci5sYW6CCWxvY2FsaG9zdDATBgNVHSUEDDAKBggrBgEFBQcDATAJBgNVHRME
AjAAMA0GCSqGSIb3DQEBCwUAA4IBAQCq/F2R7JKx790n9vIpJv5dJtR7bzUzIhEK
EBpdL8HTVizjEK5c49STsqP/b/IlayYPV1LZYUA/cmidB/pTTq0NwicRU6Q4Hfpa
/7dam6X7MLp4YfVeBOjaP45Rjm0fq2ebEG8Vvb4G2wZmNVD+a0UoI0Ah+VxY65zQ
f0yASVmyYHvi5i9yeqsTygVyl4z9nxqWF0xBkWlDavLGc2bXELdeUeGJa1ltc9NH
teQ3YcdW93yPgUgGzK52Q/gQvSdMOCT5+POn/zy/DJ7/0sHjDi0bEypVXEnKZiZ/
M9M/gBt1XjC1Ea/85Tq6BkCjOD2Obe8wUdq8S8FsCwgxDfwMpPkS
-----END CERTIFICATE-----
EOF_SECURITY_CERT

cat > files/etc/uhttpd/uhttpd.key <<'EOF_SECURITY_KEY'
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAvPc5TzFVyufZ5nPK2MQIOP8E9wqIbeJjnDqlWM8zQgiUHucg
Ye+zMTmaKZexmDiaGJqJTPqsU1igsGzVsP3LwRdYew8WdecBe3x8S2cs0fGXkfFb
XkH52dWbFIiXqbqcd3BtuP7S3ceTzk9lYnfVRox+06YNeW4TiU6dxqmxVmkFjC/v
7S7+C6Eo1dtMF/AXzdshqXQ0SjLe8SWx3x/M9T/xgKSF4jKghHZOlyZ+N5KsNanm
yxzW+elrkGkT74arCf43jcar2vhvJOIFMGVSR5DOjTgv5D0ls9IoONzZh75ECxeP
GiY36bRsnfF17ueNYylYhlw7us5CvRAX/LsN7wIDAQABAoIBAAVKes1P2VIcGcrN
FTHqkzxdT5tHLTi+bQGT1stcydege909pXd4ibDoJvvhJnTXqODletCv+CFBSwaF
lZomEQ1wBOc1LfDRLgZyHtzRn7ylIhRRCLjj6gYCaBw0EuMKuZTSjg/u+qKBEw9k
w7b1GgCmsGpmrNvojB19GQfV+oQr0jq0enzfT1/c8/lSgUMIQ3W1FBB947s+2M9+
ZExSxzPz+EQgXB+DRW7va6p9LpPhIVHDejr5E1MDbBCEsUrRvzXukb34y531FvJK
lz1XRHOsxMMoLUYAPKQ7bTI6Rey+ZBSlZ+XCBavgzBoTkBIWtDlHFAQEhGvy7Ibx
mcmNjVkCgYEA9Yy6IOkUcIGf4liA4xVM19PC3bINMaR8bpCMgTU83suYKZ6ThKPk
7HeuMhDpMCU7r4ovzkYtd7HxHWLZFwXgl8zoGF3StYBaUHb2EYhjpImnibUzfUgJ
Qk6yK2clEit/hd27pHx0dyYqAYjeJi3nk2plzJDiaqn+B35tx3EBwcUCgYEAxQID
Gtw7cVWA8wZI49ff3i9P9i4Ytt/ya5YkT2U8s3d6RSYzAqf/Kr5l0BX0nHeqG2By
+0yH0IzsS/RCB03zW/fH5wdrlFAyA2v/jG3CpjdkrIKB6s7GAS9DyCICiNuSwIsu
XEsdrGjLSwND1yB0s80OJLVd2ny+3ab4JogwUCMCgYEAn3jlDSizGJpm/zahhlm4
DVe/cAIKJZqBIcGJLwUnYj7xtN4DSpqyu4zCuktXVuhnigsCH0JelyUexgoDmbs8
cPooJmMQzMXuYeHQz/Q3Wo34HCxto0jcko7PkfasEc/kQ0mNazdU4GkN0O9V74/S
nV/1e1UBZ2q9y5olq+jNzk0CgYByXk6rIzsm+jpX20gpbUM7W0ASbIRQdgXny0vd
A6qPjUbgKeLnIdwSVmIIwRY2V4nbRsy5cp5NxeHP3kcOsoQa2eelCTu86CmArwu1
3Gpp0DKTq1f8lnmAao3w+z15ce7p9GK/laPuWQ/bxlN16hOV5e7WBKwtkMnFJ49b
3ygc/QKBgQDybrD+e+mWht+ogsUKuqNXuWTU4ZmBVMVDt9oznjhInSUi/WZ0FeAe
+aSYBvri8+WYQfphTOMnwLOan7VCILqMyhvUIVji1TeE1DIMYmqZ5Kl2KrukEZBv
qgEZJ45y+n/yYEk5lCHxzVJA44/pJry8AM3tjEI13MovB88LYPdSww==
-----END RSA PRIVATE KEY-----
EOF_SECURITY_KEY
chmod 600 files/etc/uhttpd/uhttpd.key files/etc/uhttpd/ca.key

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
    # SSH: 每源 IP 每分钟最多 8 个新连接
    uci set firewall.ssh_rate_accept=rule
    uci set firewall.ssh_rate_accept.name='Sec-SSH-RateLimit'
    uci set firewall.ssh_rate_accept.src='lan'
    uci set firewall.ssh_rate_accept.proto='tcp'
    uci set firewall.ssh_rate_accept.dest_port='22'
    uci set firewall.ssh_rate_accept.limit='8/minute'
    uci set firewall.ssh_rate_accept.target='ACCEPT'

    uci set firewall.ssh_rate_drop=rule
    uci set firewall.ssh_rate_drop.name='Sec-SSH-RateDrop'
    uci set firewall.ssh_rate_drop.src='lan'
    uci set firewall.ssh_rate_drop.proto='tcp'
    uci set firewall.ssh_rate_drop.dest_port='22'
    uci set firewall.ssh_rate_drop.target='DROP'

    # LuCI + ttyd: 每源 IP 每分钟最多 30 个新连接
    uci set firewall.web_rate_accept=rule
    uci set firewall.web_rate_accept.name='Sec-LuCI-RateLimit'
    uci set firewall.web_rate_accept.src='lan'
    uci set firewall.web_rate_accept.proto='tcp'
    uci set firewall.web_rate_accept.dest_port='80 443 7681'
    uci set firewall.web_rate_accept.limit='30/minute'
    uci set firewall.web_rate_accept.target='ACCEPT'

    uci set firewall.web_rate_drop=rule
    uci set firewall.web_rate_drop.name='Sec-LuCI-RateDrop'
    uci set firewall.web_rate_drop.src='lan'
    uci set firewall.web_rate_drop.proto='tcp'
    uci set firewall.web_rate_drop.dest_port='80 443 7681'
    uci set firewall.web_rate_drop.target='DROP'

    echo "[OK] firewall: 登录限速已写入 (SSH 8/min, LuCI+ttyd 30/min)"
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
