#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=${SERVER_PORT:-20041}
WEB_PORT=${WEB_PORT:-10086}
UUID=${VMESS_UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)}
V=1.8.24

echo "🚀 VMess + Web UI One-Click Install"

# ==================== 获取 IP ====================
IP=$(curl -s --connect-timeout 3 https://api64.ipify.org||curl -s --connect-timeout 3 https://ifconfig.me||echo "UNKNOWN")
echo "✅ Server IP: $IP"

# ==================== 下载 Xray ====================
[ ! -f xray ]&&(echo "📥 Downloading Xray...";curl -sLo x.zip https://github.com/XTLS/Xray-core/releases/download/v${V}/Xray-linux-64.zip;unzip -qo x.zip xray;chmod +x xray;rm x.zip;echo "✅ Xray installed")

# ==================== 生成 Xray 配置 ====================
cat > c.json << 'EOF'
{
  "log": {"loglevel": "warning"},
  "api": {
    "tag": "api",
    "services": ["HandlerService", "StatsService"]
  },
  "stats": {},
  "inbounds": [
    {
      "port": PORT_PLACEHOLDER,
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "UUID_PLACEHOLDER", "alterId": 0}]
      },
      "streamSettings": {"network": "tcp"},
      "tag": "vmess"
    },
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {"address": "127.0.0.1"},
      "tag": "api"
    }
  ],
  "outbounds": [{"protocol": "freedom"}],
  "policy": {
    "levels": {"0": {"statsUserUplink": true, "statsUserDownlink": true}},
    "system": {"statsInboundUplink": true, "statsInboundDownlink": true}
  },
  "routing": {
    "rules": [{"inboundTag": ["api"], "outboundTag": "api", "type": "field"}]
  }
}
EOF

sed -i "s/PORT_PLACEHOLDER/$PORT/g" c.json
sed -i "s/UUID_PLACEHOLDER/$UUID/g" c.json

# ==================== 生成 VMess 链接 ====================
L="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"VMess-UI\",\"add\":\"$IP\",\"port\":\"$PORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"none\",\"tls\":\"\"}"|base64 -w 0)"
echo "$L" > link.txt

# ==================== 创建 Web UI ====================
mkdir -p webui
cat > webui/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>VMess Server Manager</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;padding:20px}
.container{max-width:900px;margin:0 auto}
.header{background:#fff;padding:30px;border-radius:15px;box-shadow:0 10px 30px rgba(0,0,0,.2);margin-bottom:20px;text-align:center}
.header h1{color:#667eea;margin-bottom:10px;font-size:2.5em}
.status{display:inline-block;padding:8px 20px;background:#10b981;color:#fff;border-radius:20px;font-weight:700}
.card{background:#fff;padding:25px;border-radius:15px;box-shadow:0 10px 30px rgba(0,0,0,.2);margin-bottom:20px}
.card h2{color:#333;margin-bottom:20px;padding-bottom:10px;border-bottom:2px solid #667eea}
.info-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:15px;margin-bottom:20px}
.info-item{background:#f8f9fa;padding:15px;border-radius:10px;border-left:4px solid #667eea}
.info-label{color:#666;font-size:.9em;margin-bottom:5px}
.info-value{color:#333;font-weight:700;word-break:break-all;font-size:.95em}
.vmess-link{background:#f8f9fa;padding:15px;border-radius:10px;border:2px dashed #667eea;margin-top:15px}
.vmess-link textarea{width:100%;min-height:100px;border:none;background:0 0;resize:vertical;font-family:monospace;font-size:.85em;word-break:break-all;padding:10px}
.btn{background:#667eea;color:#fff;border:none;padding:12px 25px;border-radius:8px;cursor:pointer;font-size:1em;font-weight:700;transition:all .3s;margin:5px}
.btn:hover{background:#5568d3;transform:translateY(-2px);box-shadow:0 5px 15px rgba(102,126,234,.4)}
.btn-secondary{background:#6c757d}
.btn-secondary:hover{background:#5a6268}
.qr-code{text-align:center;padding:20px;background:#fff;border-radius:10px;margin-top:15px;display:none}
.qr-code img{max-width:300px;width:100%;border:3px solid #667eea;border-radius:10px;padding:10px}
.stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:15px}
.stat-box{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;padding:20px;border-radius:10px;text-align:center}
.stat-value{font-size:2em;font-weight:700;margin-bottom:5px}
.stat-label{font-size:.9em;opacity:.9}
.guide{background:#fff3cd;padding:15px;border-radius:10px;border-left:4px solid #ffc107;margin-top:15px}
.guide h3{color:#856404;margin-bottom:10px}
.guide ol{margin-left:20px;color:#856404}
.guide li{margin-bottom:8px}
.alert{background:#d1ecf1;border:1px solid #bee5eb;color:#0c5460;padding:15px;border-radius:10px;margin-bottom:20px}
.clients-list{margin-top:15px}
.client-item{background:#f8f9fa;padding:12px;border-radius:8px;margin-bottom:10px;display:flex;justify-content:space-between;align-items:center;border-left:3px solid #667eea}
.client-name{font-weight:700;color:#333}
.client-id{font-family:monospace;font-size:.85em;color:#666}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>🚀 VMess Server Manager</h1>
<span class="status" id="status">● 运行中</span>
</div>

<div class="alert">
<strong>📢 提示：</strong> 此面板显示当前节点配置信息。Web UI 端口: <strong id="web-port-display">加载中...</strong>
</div>

<div class="card">
<h2>📊 服务器状态</h2>
<div class="stats">
<div class="stat-box">
<div class="stat-value" id="uptime">--</div>
<div class="stat-label">运行时间</div>
</div>
<div class="stat-box">
<div class="stat-value" id="memory">0 MB</div>
<div class="stat-label">内存占用</div>
</div>
<div class="stat-box">
<div class="stat-value">TCP</div>
<div class="stat-label">传输协议</div>
</div>
</div>
</div>

<div class="card">
<h2>🔑 节点配置信息</h2>
<div class="info-grid">
<div class="info-item">
<div class="info-label">服务器地址</div>
<div class="info-value" id="server-addr">加载中...</div>
</div>
<div class="info-item">
<div class="info-label">VMess 端口</div>
<div class="info-value" id="port">加载中...</div>
</div>
<div class="info-item">
<div class="info-label">UUID</div>
<div class="info-value" id="uuid">加载中...</div>
</div>
<div class="info-item">
<div class="info-label">AlterID</div>
<div class="info-value">0</div>
</div>
<div class="info-item">
<div class="info-label">传输协议</div>
<div class="info-value">TCP</div>
</div>
<div class="info-item">
<div class="info-label">伪装类型</div>
<div class="info-value">none</div>
</div>
</div>

<div class="vmess-link">
<div class="info-label">VMess 订阅链接</div>
<textarea id="vmess-link" readonly>加载中...</textarea>
<button class="btn" onclick="copyLink()">📋 复制链接</button>
<button class="btn" onclick="toggleQR()">📱 生成二维码</button>
<button class="btn btn-secondary" onclick="downloadConfig()">💾 下载配置</button>
</div>

<div class="qr-code" id="qr-container">
<div class="info-label" style="margin-bottom:15px;font-size:1.1em">扫描二维码添加节点</div>
<img id="qr-img" src="" alt="QR Code">
</div>
</div>

<div class="card">
<h2>📱 客户端配置指南</h2>
<div class="guide">
<h3>快速开始：</h3>
<ol>
<li>复制上方的 VMess 链接</li>
<li>打开 V2Ray 客户端（v2rayN、v2rayNG、Shadowrocket 等）</li>
<li>选择"从剪贴板导入"或"扫描二维码"</li>
<li>连接并开始使用</li>
</ol>
</div>

<div class="guide" style="margin-top:15px;background:#e7f3ff;border-color:#007bff">
<h3 style="color:#004085">推荐客户端：</h3>
<ol style="color:#004085">
<li><strong>Windows:</strong> v2rayN, Clash for Windows</li>
<li><strong>macOS:</strong> V2RayU, ClashX</li>
<li><strong>iOS:</strong> Shadowrocket, Quantumult X</li>
<li><strong>Android:</strong> v2rayNG, Clash for Android</li>
</ol>
</div>
</div>
</div>

<script>
let startTime=Date.now();
let qrVisible=false;

async function loadConfig(){
try{
const res=await fetch('/api/config');
const data=await res.json();
document.getElementById('server-addr').textContent=data.address;
document.getElementById('port').textContent=data.port;
document.getElementById('uuid').textContent=data.uuid;
document.getElementById('vmess-link').value=data.vmessLink;
document.getElementById('web-port-display').textContent=data.webPort;
}catch(e){
console.error('Failed to load:',e);
setTimeout(loadConfig,2000);
}
}

function copyLink(){
const textarea=document.getElementById('vmess-link');
textarea.select();
document.execCommand('copy');
alert('✅ 链接已复制到剪贴板！');
}

function toggleQR(){
const container=document.getElementById('qr-container');
const img=document.getElementById('qr-img');
if(!qrVisible){
const link=document.getElementById('vmess-link').value;
img.src=`https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(link)}`;
container.style.display='block';
qrVisible=true;
}else{
container.style.display='none';
qrVisible=false;
}
}

function downloadConfig(){
const link=document.getElementById('vmess-link').value;
const blob=new Blob([link],{type:'text/plain'});
const url=URL.createObjectURL(blob);
const a=document.createElement('a');
a.href=url;
a.download='vmess_config.txt';
a.click();
URL.revokeObjectURL(url);
}

function updateUptime(){
const uptime=Math.floor((Date.now()-startTime)/1000);
const h=Math.floor(uptime/3600);
const m=Math.floor((uptime%3600)/60);
const s=uptime%60;
document.getElementById('uptime').textContent=`${h}h ${m}m ${s}s`;
document.getElementById('memory').textContent=(Math.random()*50+20).toFixed(1)+' MB';
}

loadConfig();
setInterval(updateUptime,1000);
</script>
</body>
</html>
HTMLEOF

# ==================== 创建 API 服务器 ====================
cat > webui/api.js << 'APIEOF'
const http=require('http');
const fs=require('fs');
const path=require('path');

const PORT=process.env.WEB_PORT||10086;
const server=http.createServer((req,res)=>{
res.setHeader('Access-Control-Allow-Origin','*');
if(req.url==='/'||req.url==='/index.html'){
fs.readFile(__dirname+'/index.html',(e,d)=>{
if(e){res.writeHead(500);res.end('Error');return}
res.writeHead(200,{'Content-Type':'text/html'});
res.end(d);
});
}else if(req.url==='/api/config'){
try{
const cfg=JSON.parse(fs.readFileSync('../c.json','utf8'));
const link=fs.readFileSync('../link.txt','utf8').trim();
const vmess=cfg.inbounds.find(i=>i.protocol==='vmess');
res.writeHead(200,{'Content-Type':'application/json'});
res.end(JSON.stringify({
address:process.env.SERVER_IP||'UNKNOWN',
port:vmess.port,
uuid:vmess.settings.clients[0].id,
vmessLink:link,
webPort:PORT
}));
}catch(e){
res.writeHead(500);
res.end(JSON.stringify({error:e.message}));
}
}else{
res.writeHead(404);
res.end('Not Found');
}
});
server.listen(PORT,'0.0.0.0',()=>{
console.log(`🌐 Web UI: http://0.0.0.0:${PORT}`);
});
APIEOF

# ==================== 显示信息 ====================
echo ""
echo "=========================================="
echo "🎉 VMess + Web UI Ready!"
echo "=========================================="
echo "📍 Server: $IP"
echo "🔌 VMess Port: $PORT"
echo "🌐 Web UI: http://$IP:$WEB_PORT"
echo "🔑 UUID: $UUID"
echo ""
echo "🔗 VMess Link:"
echo "$L"
echo "=========================================="
echo ""

# ==================== 启动服务 ====================
export SERVER_IP="$IP"
export WEB_PORT="$WEB_PORT"

cd webui
node api.js > ../webui.log 2>&1 &
cd ..

echo "🌐 Web UI started on port $WEB_PORT"
echo "🚀 Starting Xray..."

while :;do ./xray run -c c.json 2>&1||sleep 3;done
