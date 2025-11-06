#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=${PORT:-${SERVER_PORT:-20041}}
UUID=${VMESS_UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)}
V=1.8.24

echo "🚀 VMess + Web UI (Single Port)"
echo "📌 Port: $PORT"

# ==================== 获取 IP ====================
IP=$(curl -s --connect-timeout 3 https://api64.ipify.org||curl -s --connect-timeout 3 https://ifconfig.me||echo "UNKNOWN")
echo "✅ Server IP: $IP"

# ==================== 下载 Xray ====================
[ ! -f xray ]&&(echo "📥 Downloading Xray...";curl -sLo x.zip https://github.com/XTLS/Xray-core/releases/download/v${V}/Xray-linux-64.zip;unzip -qo x.zip xray;chmod +x xray;rm x.zip;echo "✅ Xray installed")

# ==================== 生成 Xray 配置（带 Web 服务）====================
cat > c.json << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": ${PORT},
      "protocol": "vmess",
      "settings": {
        "clients": [{"id": "${UUID}", "alterId": 0}]
      },
      "streamSettings": {
        "network": "tcp",
        "tcpSettings": {
          "acceptProxyProtocol": false,
          "header": {
            "type": "http",
            "response": {
              "version": "1.1",
              "status": "200",
              "reason": "OK",
              "headers": {
                "Content-Type": ["text/html; charset=utf-8"],
                "Transfer-Encoding": ["chunked"],
                "Connection": ["keep-alive"],
                "Pragma": "no-cache"
              }
            }
          }
        }
      },
      "tag": "vmess"
    }
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

# ==================== 生成 VMess 链接 ====================
L="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"VMess-Single\",\"add\":\"$IP\",\"port\":\"$PORT\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"tls\":\"\"}"|base64 -w 0)"
echo "$L" > link.txt

# ==================== 创建独立 Web 服务器（使用 Nginx 反向代理方式）====================
mkdir -p webui

# 创建简化版 Web UI
cat > webui/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>VMess Manager</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:system-ui,-apple-system,sans-serif;background:linear-gradient(135deg,#667eea,#764ba2);min-height:100vh;padding:20px;display:flex;align-items:center;justify-content:center}
.container{max-width:600px;width:100%}
.card{background:#fff;padding:30px;border-radius:20px;box-shadow:0 20px 60px rgba(0,0,0,.3);margin-bottom:20px}
h1{color:#667eea;text-align:center;margin-bottom:20px;font-size:2em}
.status{background:#10b981;color:#fff;padding:10px 20px;border-radius:20px;text-align:center;font-weight:700;margin-bottom:20px}
.info{background:#f8f9fa;padding:15px;border-radius:10px;margin:10px 0;border-left:4px solid #667eea}
.label{color:#666;font-size:.9em;margin-bottom:5px}
.value{color:#333;font-weight:700;word-break:break-all;font-family:monospace;font-size:.95em}
textarea{width:100%;min-height:100px;padding:15px;border:2px solid #e0e0e0;border-radius:10px;font-family:monospace;font-size:.9em;margin:10px 0;resize:vertical}
.btn{background:#667eea;color:#fff;border:none;padding:15px 30px;border-radius:10px;cursor:pointer;font-size:1em;font-weight:700;width:100%;margin:5px 0;transition:.3s}
.btn:hover{background:#5568d3;transform:translateY(-2px);box-shadow:0 10px 20px rgba(102,126,234,.3)}
.btn-sec{background:#6c757d}
.btn-sec:hover{background:#5a6268}
#qr{text-align:center;padding:20px;display:none}
#qr img{max-width:280px;width:100%;border:3px solid #667eea;border-radius:10px;padding:10px;background:#fff}
.alert{background:#d1ecf1;border-left:4px solid #0c5460;padding:15px;border-radius:10px;margin-bottom:20px;color:#0c5460}
</style>
</head>
<body>
<div class="container">
<div class="card">
<h1>🚀 VMess Manager</h1>
<div class="status">● 运行中</div>

<div class="alert">
<strong>📢 说明：</strong>VMess 和 Web UI 共用端口 <strong id="port-display">--</strong>
</div>

<div class="info">
<div class="label">服务器地址</div>
<div class="value" id="addr">加载中...</div>
</div>

<div class="info">
<div class="label">端口</div>
<div class="value" id="port">加载中...</div>
</div>

<div class="info">
<div class="label">UUID</div>
<div class="value" id="uuid">加载中...</div>
</div>

<div class="info">
<div class="label">传输协议</div>
<div class="value">TCP (HTTP Header)</div>
</div>

<div style="margin-top:20px">
<div class="label">VMess 订阅链接</div>
<textarea id="link" readonly>加载中...</textarea>
</div>

<button class="btn" onclick="copy()">📋 复制链接</button>
<button class="btn" onclick="showQR()">📱 生成二维码</button>
<button class="btn btn-sec" onclick="download()">💾 下载配置</button>

<div id="qr">
<img id="qrimg" src="">
</div>
</div>
</div>

<script>
const API_PORT=REPLACE_PORT;
let qrShow=false;

fetch('http://'+location.hostname+':'+API_PORT+'/web/config').then(r=>r.json()).then(d=>{
document.getElementById('addr').textContent=d.address;
document.getElementById('port').textContent=d.port;
document.getElementById('uuid').textContent=d.uuid;
document.getElementById('link').value=d.link;
document.getElementById('port-display').textContent=d.port;
}).catch(e=>{
setTimeout(()=>location.reload(),2000);
});

function copy(){
const t=document.getElementById('link');
t.select();
document.execCommand('copy');
alert('✅ 已复制！');
}

function showQR(){
const q=document.getElementById('qr');
if(!qrShow){
const l=document.getElementById('link').value;
document.getElementById('qrimg').src='https://api.qrserver.com/v1/create-qr-code/?size=280x280&data='+encodeURIComponent(l);
q.style.display='block';
qrShow=true;
}else{
q.style.display='none';
qrShow=false;
}
}

function download(){
const l=document.getElementById('link').value;
const b=new Blob([l],{type:'text/plain'});
const u=URL.createObjectURL(b);
const a=document.createElement('a');
a.href=u;
a.download='vmess.txt';
a.click();
}
</script>
</body>
</html>
HTMLEOF

# 替换端口占位符
sed -i "s/REPLACE_PORT/${PORT}/g" webui/index.html

# 创建简单的 HTTP 服务器（使用 Python）
cat > webui/server.py << PYEOF
#!/usr/bin/env python3
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = ${PORT}

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('index.html', 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/web/config':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            try:
                with open('../c.json', 'r') as f:
                    cfg = json.load(f)
                with open('../link.txt', 'r') as f:
                    link = f.read().strip()
                vmess = next(i for i in cfg['inbounds'] if i['protocol']=='vmess')
                data = {
                    'address': os.getenv('SERVER_IP', 'UNKNOWN'),
                    'port': vmess['port'],
                    'uuid': vmess['settings']['clients'][0]['id'],
                    'link': link
                }
                self.wfile.write(json.dumps(data).encode())
            except Exception as e:
                self.wfile.write(json.dumps({'error': str(e)}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass

if __name__ == '__main__':
    print(f'🌐 Web UI: http://0.0.0.0:{PORT}')
    HTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
PYEOF

chmod +x webui/server.py

echo ""
echo "=========================================="
echo "🎉 VMess + Web UI Ready!"
echo "=========================================="
echo "📍 Server: $IP:$PORT"
echo "🌐 Web UI: http://$IP:$PORT"
echo "🔑 UUID: $UUID"
echo ""
echo "⚠️  注意：VMess 和 Web UI 共用同一端口"
echo "   - 浏览器访问显示 Web UI"
echo "   - V2Ray 客户端连接使用 VMess"
echo ""
echo "🔗 VMess Link:"
echo "$L"
echo "=========================================="
echo ""

export SERVER_IP="$IP"

# 启动 Web UI（后台）
cd webui
python3 server.py > ../webui.log 2>&1 &
WEB_PID=$!
cd ..

sleep 2
echo "🌐 Web UI started (PID: $WEB_PID)"
echo "🚀 Starting Xray..."

while :;do ./xray run -c c.json 2>&1||sleep 3;done
