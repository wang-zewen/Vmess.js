# VMess Server - One-Click Deployment 🚀

一键部署 VMess 服务器到 WispByte、Render、Railway 等平台。

## ✨ 特性

- 🚀 一键部署，无需复杂配置
- 🔐 自动生成 UUID 和配置
- 📱 自动生成 VMess 订阅链接
- 🔄 自动重启保活
- 💻 支持多平台部署
- 🆓 完全免费开源

## 🎯 支持平台

- [WispByte](https://console.wispbyte.com/)
- [Render](https://render.com/)
- [Railway](https://railway.app/)
- [Heroku](https://heroku.com/)
- 任何支持 Node.js 的 PaaS 平台

## 📦 快速部署

### 方式 1: WispByte 一键部署

1. Fork 本仓库
2. 访问 [WispByte Console](https://console.wispbyte.com/)
3. 创建新应用，选择 "Import from GitHub"
4. 选择 fork 的仓库
5. 添加环境变量（可选）：
```
   VMESS_UUID=your-custom-uuid
   SERVER_NAME=My-VMess-Server
```
6. 点击部署

### 方式 2: Render 一键部署

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

1. 点击上方按钮
2. 填写服务名称
3. 等待部署完成

### 方式 3: Railway 一键部署

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template)

1. 点击上方按钮
2. 连接 GitHub 账号
3. 等待部署完成

### 方式 4: 手动部署
```bash
# 克隆仓库
git clone https://github.com/yourusername/vmess-wispbyte.git
cd vmess-wispbyte

# 安装依赖（无依赖，跳过）
npm install

# 设置环境变量（可选）
export VMESS_UUID="your-uuid"
export PORT=8080

# 启动服务
npm start
```

## 🔧 环境变量配置

| 变量名 | 说明 | 默认值 | 必填 |
|--------|------|--------|------|
| `PORT` | 服务端口 | 8080 | ❌ |
| `VMESS_UUID` | VMess UUID | 自动生成 | ❌ |
| `SERVER_NAME` | 服务器名称 | VMess-Server | ❌ |
| `SERVER_IP` | 服务器地址 | 自动检测 | ❌ |
| `ENABLE_HEALTH_CHECK` | 启用健康检查 | false | ❌ |

## 📱 获取连接信息

部署成功后，有以下方式获取 VMess 链接：

### 方法 1: 查看日志
在平台的日志界面查看输出的 VMess 链接

### 方法 2: 访问 /link 端点
```bash
curl https://your-app-url.com/link
```

### 方法 3: 查看健康检查
```bash
curl https://your-app-url.com/health
```

## 🎯 客户端配置

复制生成的 VMess 链接，导入到以下客户端：

### Windows
- [v2rayN](https://github.com/2dust/v2rayN)
- [Clash for Windows](https://github.com/Fndroid/clash_for_windows_pkg)

### macOS
- [V2rayU](https://github.com/yanue/V2rayU)
- [ClashX](https://github.com/yichengchen/clashX)

### iOS
- Shadowrocket
- Quantumult X

### Android
- [v2rayNG](https://github.com/2dust/v2rayNG)
- [Clash for Android](https://github.com/Kr328/ClashForAndroid)

## 🔒 安全建议

1. **自定义 UUID**: 部署时设置 `VMESS_UUID` 环境变量
2. **定期更换**: 建议定期更换 UUID
3. **限制访问**: 如果平台支持，配置防火墙规则
4. **监控流量**: 定期检查流量使用情况

## 🐛 故障排除

### 问题 1: 无法连接
- 检查服务器地址是否正确
- 确认端口是否开放
- 查看应用日志

### 问题 2: 下载 Xray 失败
- 检查网络连接
- 可以手动下载 Xray 并上传到项目

### 问题 3: 服务自动停止
- 检查平台是否有空闲超时限制
- 启用健康检查保活

## 📝 许可证

MIT License

## ⚠️ 免责声明

本项目仅供学习交流使用，请遵守当地法律法规。使用本项目所产生的一切后果由使用者自行承担。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📧 联系方式

如有问题，请提交 [Issue](https://github.com/yourusername/vmess-wispbyte/issues)
