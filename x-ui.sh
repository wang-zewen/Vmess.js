#!/bin/bash
set -e

PORT=${SERVER_PORT:-20041}
UUID=${VMESS_UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)}
V=1.8.24

echo "🚀 VMess One-Click Install"

IP=$(curl -s --connect-timeout 3 https://api64.ipify.org||curl -s --connect-timeout 3 https://ifconfig.me||echo "UNKNOWN")
echo "✅ IP: $IP"

[ ! -f xray ]&&(echo "📥 Downloading Xray...";curl -sLo x.zip https://github.com/XTLS/Xray-core/releases/download/v${V}/Xray-linux-64.zip;unzip -qo x.zip xray;chmod +x xray;rm x.zip)

echo "{\"log\":{\"loglevel\":\"warning\"},\"inbounds\":[{\"port\":$PORT,\"protocol\":\"vmess\",\"settings\":{\"clients\":[{\"id\":\"$UUID\",\"alterId\":0}]},\"streamSettings\":{\"network\":\"tcp\"}}],\"outbounds\":[{\"protocol\":\"freedom\"}]}">c.json

L="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"VMess\",\"add\":\"$IP\",\"port\":\"$PORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"tls\":\"\"}"|base64 -w 0)"

echo ""
echo "=========================================="
echo "🎉 VMess Ready!"
echo "=========================================="
echo "📍 $IP:$PORT"
echo "🔑 $UUID"
echo ""
echo "🔗 VMess Link:"
echo "$L"
echo "=========================================="

while :;do ./xray run -c c.json 2>&1||sleep 3;done
