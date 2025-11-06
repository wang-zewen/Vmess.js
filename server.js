const { spawn } = require('child_process');
const fs = require('fs');
const https = require('https');
const http = require('http');

// ==================== 配置 ====================
const PORT = process.env.PORT || process.env.SERVER_PORT || 8080;
const UUID = process.env.VMESS_UUID || generateUUID();
const XRAY_VERSION = '1.8.24';
const XRAY_URL = `https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip`;
const SERVER_NAME = process.env.SERVER_NAME || 'VMess-Server';

// ==================== 工具函数 ====================
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

function log(emoji, message) {
  console.log(`${emoji} [${new Date().toISOString()}] ${message}`);
}

// 下载文件
async function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    log('📥', `Downloading from ${url}`);
    https.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } }, (response) => {
      // 处理重定向
      if (response.statusCode === 302 || response.statusCode === 301) {
        return downloadFile(response.headers.location, dest).then(resolve).catch(reject);
      }
      
      if (response.statusCode !== 200) {
        reject(new Error(`HTTP ${response.statusCode}`));
        return;
      }

      const file = fs.createWriteStream(dest);
      let downloaded = 0;
      const total = parseInt(response.headers['content-length'], 10);

      response.on('data', (chunk) => {
        downloaded += chunk.length;
        const percent = ((downloaded / total) * 100).toFixed(1);
        process.stdout.write(`\r📦 Progress: ${percent}%`);
      });

      response.pipe(file);
      
      file.on('finish', () => {
        file.close();
        console.log('\n✅ Download complete');
        resolve();
      });

      file.on('error', (err) => {
        fs.unlink(dest, () => {});
        reject(err);
      });
    }).on('error', reject);
  });
}

// 解压文件
function unzip(zipPath, targetFile) {
  return new Promise((resolve, reject) => {
    log('📦', 'Extracting Xray...');
    const unzip = spawn('unzip', ['-o', zipPath, targetFile], {
      stdio: 'pipe'
    });
    
    unzip.on('close', (code) => {
      if (code === 0) {
        log('✅', 'Extraction complete');
        resolve();
      } else {
        reject(new Error(`Unzip failed with code ${code}`));
      }
    });

    unzip.on('error', reject);
  });
}

// 生成配置文件
function generateConfig() {
  const config = {
    log: {
      loglevel: "warning"
    },
    inbounds: [
      {
        port: parseInt(PORT),
        protocol: "vmess",
        settings: {
          clients: [
            {
              id: UUID,
              alterId: 0
            }
          ],
          disableInsecureEncryption: false
        },
        streamSettings: {
          network: "tcp",
          security: "none",
          tcpSettings: {
            header: {
              type: "none"
            }
          }
        },
        sniffing: {
          enabled: true,
          destOverride: ["http", "tls"]
        }
      }
    ],
    outbounds: [
      {
        protocol: "freedom",
        settings: {},
        tag: "direct"
      },
      {
        protocol: "blackhole",
        settings: {},
        tag: "block"
      }
    ],
    routing: {
      rules: [
        {
          type: "field",
          ip: ["geoip:private"],
          outboundTag: "block"
        }
      ]
    }
  };
  
  fs.writeFileSync('config.json', JSON.stringify(config, null, 2));
  log('✅', 'Config file generated');
}

// 生成 VMess 链接
function generateVMessLink() {
  // 尝试获取服务器地址
  let serverAddr = process.env.SERVER_IP || process.env.RENDER_EXTERNAL_HOSTNAME || 'localhost';
  
  const vmessConfig = {
    v: "2",
    ps: SERVER_NAME,
    add: serverAddr,
    port: PORT.toString(),
    id: UUID,
    aid: "0",
    scy: "auto",
    net: "tcp",
    type: "none",
    host: "",
    path: "",
    tls: "",
    sni: "",
    alpn: ""
  };
  
  const link = 'vmess://' + Buffer.from(JSON.stringify(vmessConfig)).toString('base64');
  
  console.log('\n' + '='.repeat(60));
  log('🎉', 'VMess Server Started Successfully!');
  console.log('='.repeat(60));
  console.log('\n📋 Connection Information:');
  console.log(`   Address: ${serverAddr}`);
  console.log(`   Port: ${PORT}`);
  console.log(`   UUID: ${UUID}`);
  console.log(`   AlterID: 0`);
  console.log(`   Network: TCP`);
  console.log(`   Security: none`);
  console.log('\n🔗 VMess Link (Copy to V2Ray client):');
  console.log(`   ${link}`);
  console.log('\n' + '='.repeat(60) + '\n');
  
  // 保存链接
  fs.writeFileSync('vmess_link.txt', link);
  log('💾', 'VMess link saved to vmess_link.txt');
  
  return link;
}

// 启动 Xray
function startXray() {
  log('🚀', 'Starting Xray server...');
  
  const xray = spawn('./xray', ['run', '-c', 'config.json'], {
    stdio: 'inherit'
  });
  
  xray.on('error', (err) => {
    log('❌', `Failed to start Xray: ${err.message}`);
    process.exit(1);
  });
  
  xray.on('close', (code) => {
    log('⚠️', `Xray exited with code ${code}. Restarting in 5s...`);
    setTimeout(startXray, 5000);
  });

  // 优雅退出
  process.on('SIGTERM', () => {
    log('🛑', 'Received SIGTERM, shutting down gracefully...');
    xray.kill();
    process.exit(0);
  });

  process.on('SIGINT', () => {
    log('🛑', 'Received SIGINT, shutting down gracefully...');
    xray.kill();
    process.exit(0);
  });
}

// 创建健康检查服务器
function createHealthCheckServer() {
  const server = http.createServer((req, res) => {
    if (req.url === '/health' || req.url === '/') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        status: 'ok',
        service: 'vmess-server',
        uuid: UUID,
        port: PORT,
        timestamp: new Date().toISOString()
      }));
    } else if (req.url === '/link') {
      const link = fs.existsSync('vmess_link.txt') 
        ? fs.readFileSync('vmess_link.txt', 'utf8')
        : 'Link not generated yet';
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(link);
    } else {
      res.writeHead(404);
      res.end('Not Found');
    }
  });

  const healthPort = parseInt(PORT) + 1;
  server.listen(healthPort, () => {
    log('🏥', `Health check server running on port ${healthPort}`);
  });
}

// ==================== 主流程 ====================
async function main() {
  console.log('\n' + '='.repeat(60));
  log('🚀', 'VMess Server Initialization');
  console.log('='.repeat(60) + '\n');

  try {
    // 检查并下载 Xray
    if (!fs.existsSync('./xray')) {
      log('📥', 'Xray not found, downloading...');
      await downloadFile(XRAY_URL, 'xray.zip');
      await unzip('xray.zip', 'xray');
      fs.chmodSync('./xray', 0o755);
      
      // 清理
      if (fs.existsSync('xray.zip')) {
        fs.unlinkSync('xray.zip');
        log('🧹', 'Cleaned up zip file');
      }
    } else {
      log('✅', 'Xray binary found');
    }

    // 生成配置
    generateConfig();
    
    // 生成链接
    generateVMessLink();
    
    // 启动健康检查（可选）
    if (process.env.ENABLE_HEALTH_CHECK === 'true') {
      createHealthCheckServer();
    }
    
    // 启动 Xray
    startXray();

  } catch (err) {
    log('❌', `Fatal error: ${err.message}`);
    console.error(err);
    process.exit(1);
  }
}

// 启动
main();
