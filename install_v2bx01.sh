#!/bin/sh

# ========================================
# V2bX 一键安装脚本
# 面板: XBoard | 协议: VLESS+REALITY
# 内核: sing-box | 系统: Debian/Ubuntu/Alpine
# ========================================

# 面板配置
API_HOST="https://01d.dklineo.top"
API_KEY="DUxkfXbXZyr6DaF3qaZsVBev"
NODE_ID=45

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] $1${NC}"; }
err() { echo -e "${RED}[$(date '+%H:%M:%S')] $1${NC}"; exit 1; }

# 检查root
[ "$(id -u)" -ne 0 ] && err "请用root权限运行此脚本"

log "========== 开始安装 V2bX =========="

# 1. 检测系统并安装依赖
log "检测系统类型..."
if [ -f /etc/alpine-release ]; then
    OS="alpine"
    log "检测到 Alpine Linux"
    apk update
    apk add --no-cache curl wget unzip bash
elif [ -f /etc/debian_version ]; then
    OS="debian"
    log "检测到 Debian/Ubuntu"
    apt-get update -y
    apt-get install -y curl wget unzip
elif [ -f /etc/redhat-release ]; then
    OS="centos"
    log "检测到 CentOS/RHEL"
    yum install -y curl wget unzip
else
    err "不支持的操作系统"
fi

# 2. 禁用IPv6（解决REALITY dest无法连接问题）
log "禁用IPv6..."
if [ "$OS" = "alpine" ]; then
    # Alpine 通过 sysctl.conf
    mkdir -p /etc/sysctl.d
    cat >> /etc/sysctl.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
    sysctl -p 2>/dev/null || true
else
    cat >> /etc/sysctl.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
    sysctl -p
fi

# 3. 安装V2bX
log "安装 V2bX..."
bash <(curl -Ls https://raw.githubusercontent.com/V2bX-org/V2bX/master/install.sh)

# 4. 写入主配置
log "写入主配置 config.json..."
mkdir -p /etc/V2bX
cat > /etc/V2bX/config.json << EOF
{
    "Log": {
        "Level": "error",
        "Output": ""
    },
    "Cores": [
    {
        "Type": "sing",
        "Log": {
            "Level": "error",
            "Timestamp": true
        },
        "NTP": {
            "Enable": false,
            "Server": "time.apple.com",
            "ServerPort": 0
        },
        "OriginalPath": "/etc/V2bX/sing_origin.json"
    }],
    "Nodes": [{
        "Core": "sing",
        "ApiHost": "${API_HOST}",
        "ApiKey": "${API_KEY}",
        "NodeID": ${NODE_ID},
        "NodeType": "vless",
        "Timeout": 30,
        "ListenIP": "0.0.0.0",
        "SendIP": "0.0.0.0",
        "DeviceOnlineMinTraffic": 200,
        "MinReportTraffic": 0,
        "TCPFastOpen": true,
        "SniffEnabled": true,
        "CertConfig": {
            "CertMode": "none",
            "RejectUnknownSni": false,
            "CertDomain": "example.com",
            "CertFile": "/etc/V2bX/fullchain.cer",
            "KeyFile": "/etc/V2bX/cert.key",
            "Email": "v2bx@github.com",
            "Provider": "cloudflare",
            "DNSEnv": {
                "EnvName": "env1"
            }
        }
    }]
}
EOF

# 5. 写入sing_origin.json
log "写入 sing_origin.json..."
cat > /etc/V2bX/sing_origin.json << EOF
{
  "dns": {
    "servers": [
      {
        "tag": "cf",
        "address": "1.1.1.1"
      }
    ],
    "strategy": "ipv4_only"
  },
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct",
      "domain_resolver": {
        "server": "cf",
        "strategy": "ipv4_only"
      }
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_is_private": true,
        "outbound": "block"
      },
      {
        "domain_regex": [
            "(api|ps|sv|offnavi|newvector|ulog.imap|newloc)(.map|).(baidu|n.shifen).com",
            "(.+.|^)(360|so).(cn|com)",
            "(Subject|HELO|SMTP)",
            "(torrent|.torrent|peer_id=|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=)",
            "(^.@)(guerrillamail|guerrillamailblock|sharklasers|grr|pokemail|spam4|bccto|chacuo|027168).(info|biz|com|de|net|org|me|la)",
            "(.?)(xunlei|sandai|Thunder|XLLiveUD)(.)",
            "(..||)(dafahao|mingjinglive|botanwang|minghui|dongtaiwang|falunaz|epochtimes|ntdtv|falundafa|falungong|wujieliulan|zhengjian).(org|com|net)",
            "(ed2k|.torrent|peer_id=|announce|info_hash|get_peers|find_node|BitTorrent|announce_peer|announce.php?passkey=|magnet:|xunlei|sandai|Thunder|XLLiveUD|bt_key)",
            "(.+.|^)(360).(cn|com|net)",
            "(.*.||)(guanjia.qq.com|qqpcmgr|QQPCMGR)",
            "(.*.||)(rising|kingsoft|duba|xindubawukong|jinshanduba).(com|net|org)",
            "(.*.||)(netvigator|torproject).(com|cn|net|org)",
            "(..||)(visa|mycard|gash|beanfun|bank).",
            "(.*.||)(gov|12377|12315|talk.news.pts.org|creaders|zhuichaguoji|efcc.org|cyberpolice|aboluowang|tuidang|epochtimes|zhengjian|110.qq|mingjingnews|inmediahk|xinsheng|breakgfw|chengmingmag|jinpianwang|qi-gong|mhradio|edoors|renminbao|soundofhope|xizang-zhiye|bannedbook|ntdtv|12321|secretchina|dajiyuan|boxun|chinadigitaltimes|dwnews|huaglad|oneplusnews|epochweekly|cn.rfi).(cn|com|org|net|club|net|fr|tw|hk|eu|info|me)",
            "(.*.||)(miaozhen|cnzz|talkingdata|umeng).(cn|com)",
            "(.*.||)(mycard).(com|tw)",
            "(.*.||)(gash).(com|tw)",
            "(.bank.)",
            "(.*.||)(pincong).(rocks)",
            "(.*.||)(taobao).(com)",
            "(.*.||)(laomoe|jiyou|ssss|lolicp|vv1234|0z|4321q|868123|ksweb|mm126).(com|cloud|fun|cn|gs|xyz|cc)",
            "(flows|miaoko).(pages).(dev)"
        ],
        "outbound": "block"
      },
      {
        "outbound": "direct",
        "network": ["udp","tcp"]
      }
    ]
  },
  "experimental": {
    "cache_file": {
      "enabled": true
    }
  }
}
EOF

# 6. 启动V2bX
log "启动 V2bX 服务..."
if [ "$OS" = "alpine" ]; then
    rc-update add V2bX default 2>/dev/null || true
    rc-service V2bX restart 2>/dev/null || V2bX restart 2>/dev/null || true
else
    systemctl enable V2bX
    systemctl restart V2bX
fi

# 7. 检查运行状态
sleep 3
if pgrep -x "V2bX" > /dev/null; then
    log "========== 安装完成 =========="
    log "V2bX 运行正常 ✓"
    log "面板地址: ${API_HOST}"
    log "节点ID: ${NODE_ID}"
    echo ""
    warn "查看日志: journalctl -u V2bX -f  或  rc-service V2bX status"
else
    err "V2bX 启动失败，请检查日志"
fi
