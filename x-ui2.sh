#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

# ==================== 配置 ====================
XUI_PORT=${XUI_PORT:-${PORT:-54321}}
XUI_USER=${XUI_USER:-admin}
XUI_PASS=${XUI_PASS:-admin}

echo -e "${green}========================================${plain}"
echo -e "${green}🚀 x-ui 免 Root 安装脚本2${plain}"
echo -e "${green}========================================${plain}"
echo ""

# ==================== 检测架构 ====================
arch=$(arch)
if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${yellow}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo -e "${green}架构: ${arch}${plain}"

# ==================== 设置安装目录 ====================
INSTALL_DIR="$HOME/x-ui"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo -e "${yellow}📍 安装目录: ${INSTALL_DIR}${plain}"

# ==================== 获取服务器 IP ====================
echo -e "${yellow}🌐 获取服务器 IP...${plain}"
SERVER_IP=$(curl -s --connect-timeout 3 https://api64.ipify.org 2>/dev/null || \
            curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null || \
            echo "127.0.0.1")
echo -e "${green}✅ 服务器 IP: ${SERVER_IP}${plain}"

# ==================== 停止旧进程 ====================
pkill -f "x-ui" 2>/dev/null || true
sleep 1

# ==================== 备份旧数据 ====================
if [ -d "x-ui/db" ]; then
    echo -e "${yellow}📦 备份旧数据...${plain}"
    cp -r x-ui/db db_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
fi

# ==================== 清理旧文件 ====================
rm -rf x-ui bin *.tar.gz 2>/dev/null || true

# ==================== 下载 x-ui ====================
echo -e "${yellow}📥 正在下载 x-ui...${plain}"

# 获取最新版本
last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/x-ui/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [[ ! -n "$last_version" ]]; then
    echo -e "${yellow}⚠️  GitHub API 失败，使用固定版本 v2.3.10${plain}"
    last_version="2.3.10"
fi

echo -e "${green}检测到 x-ui 版本：${last_version}${plain}"

# 下载
download_url="https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
echo -e "${yellow}📥 下载地址: ${download_url}${plain}"

wget -q --show-progress --no-check-certificate -O x-ui.tar.gz ${download_url}

if [[ $? -ne 0 ]]; then
    echo -e "${red}❌ 下载失败，尝试备用源...${plain}"
    download_url="https://ghproxy.com/https://github.com/vaxilu/x-ui/releases/download/${last_version}/x-ui-linux-${arch}.tar.gz"
    wget -q --show-progress --no-check-certificate -O x-ui.tar.gz ${download_url}
    
    if [[ $? -ne 0 ]]; then
        echo -e "${red}❌ 下载失败，请检查网络连接${plain}"
        exit 1
    fi
fi

echo -e "${green}✅ 下载完成${plain}"

# ==================== 解压并检查结构 ====================
echo -e "${yellow}📦 解压文件...${plain}"

# 解压到当前目录
tar -zxf x-ui.tar.gz

if [[ $? -ne 0 ]]; then
    echo -e "${red}❌ 解压失败${plain}"
    exit 1
fi

# 检查解压后的结构
echo -e "${yellow}🔍 检查解压结构...${plain}"
ls -la

# 查找 x-ui 可执行文件
if [ -f "x-ui/x-ui" ]; then
    echo -e "${green}✅ 找到标准结构: x-ui/x-ui${plain}"
    XUI_DIR="x-ui"
elif [ -f "x-ui" ]; then
    echo -e "${green}✅ 找到扁平结构: ./x-ui${plain}"
    XUI_DIR="."
    # 创建标准目录结构
    mkdir -p x-ui/bin
    mv x-ui x-ui/
    [ -d "bin" ] && mv bin/* x-ui/bin/ 2>/dev/null || true
    [ -f "xray-linux-${arch}" ] && mv xray-linux-${arch} x-ui/bin/ 2>/dev/null || true
    XUI_DIR="x-ui"
else
    echo -e "${red}❌ 未找到 x-ui 可执行文件${plain}"
    echo -e "${yellow}当前目录内容：${plain}"
    find . -name "x-ui" -o -name "xray*"
    exit 1
fi

# 进入 x-ui 目录
cd "$XUI_DIR"

# 设置权限
chmod +x x-ui 2>/dev/null || true
chmod +x bin/xray-linux-${arch} 2>/dev/null || true

# 如果 bin 目录中的 xray 名字不对，重命名
if [ -d "bin" ]; then
    cd bin
    for f in xray*; do
        if [ -f "$f" ] && [ "$f" != "xray-linux-${arch}" ]; then
            mv "$f" "xray-linux-${arch}" 2>/dev/null || true
        fi
    done
    chmod +x xray-linux-${arch} 2>/dev/null || true
    cd ..
fi

echo -e "${green}✅ 解压完成${plain}"

# ==================== 创建数据库目录 ====================
mkdir -p db

# 恢复备份的数据库
if [ -d "../db_backup_"* ]; then
    LATEST_BACKUP=$(ls -td ../db_backup_* | head -1)
    if [ -d "$LATEST_BACKUP" ]; then
        echo -e "${yellow}📦 恢复数据库备份...${plain}"
        cp -r "$LATEST_BACKUP"/* db/ 2>/dev/null || true
        echo -e "${green}✅ 数据库已恢复${plain}"
    fi
fi

# ==================== 创建启动脚本 ====================
cat > ../start.sh << STARTEOF
#!/bin/bash
cd "\$(dirname "\$0")/x-ui"

export XUI_BIN_FOLDER="\$(pwd)/bin"
export XUI_DB_FOLDER="\$(pwd)/db"
export XUI_LOG_FOLDER="\$(pwd)"

echo "=========================================="
echo "🚀 x-ui 面板启动中..."
echo "=========================================="
echo "📍 端口: ${XUI_PORT}"
echo "🌐 访问: http://${SERVER_IP}:${XUI_PORT}"
echo "👤 用户: ${XUI_USER}"
echo "🔑 密码: ${XUI_PASS}"
echo "=========================================="
echo ""

# 首次运行时设置用户名密码和端口
if [ ! -f "db/x-ui.db" ] || [ ! -s "db/x-ui.db" ]; then
    echo "🔧 首次运行，正在初始化..."
    
    # 启动 x-ui 让它创建数据库
    timeout 5 ./x-ui > /dev/null 2>&1 || true
    sleep 2
    
    # 设置用户名密码
    if [ -f "db/x-ui.db" ]; then
        ./x-ui setting -username "${XUI_USER}" -password "${XUI_PASS}" 2>/dev/null || echo "⚠️  请手动设置用户名密码"
        ./x-ui setting -port ${XUI_PORT} 2>/dev/null || echo "⚠️  请手动设置端口"
        echo "✅ 初始化完成"
    fi
fi

# 启动主进程
echo "🚀 x-ui 正在运行..."
echo "📝 按 Ctrl+C 停止"
echo ""

while true; do
    ./x-ui
    echo ""
    echo "⚠️  x-ui 已停止，5秒后自动重启..."
    sleep 5
done
STARTEOF

chmod +x ../start.sh

# ==================== 创建管理脚本 ====================
cat > ../x-ui.sh << 'MGMTEOF'
#!/bin/bash

XUI_DIR="$HOME/x-ui/x-ui"

case "$1" in
    start)
        cd "$HOME/x-ui"
        nohup bash start.sh > xui.log 2>&1 &
        echo "✅ x-ui 已后台启动"
        echo "📝 查看日志: tail -f $HOME/x-ui/xui.log"
        ;;
    stop)
        pkill -f "x-ui/x-ui"
        echo "✅ x-ui 已停止"
        ;;
    restart)
        pkill -f "x-ui/x-ui"
        sleep 2
        cd "$HOME/x-ui"
        nohup bash start.sh > xui.log 2>&1 &
        echo "✅ x-ui 已重启"
        ;;
    status)
        if pgrep -f "x-ui/x-ui" > /dev/null; then
            echo "✅ x-ui 正在运行"
            echo "进程ID: $(pgrep -f 'x-ui/x-ui')"
        else
            echo "❌ x-ui 未运行"
        fi
        ;;
    log)
        tail -f "$HOME/x-ui/xui.log" 2>/dev/null || tail -f "$HOME/x-ui/x-ui/x-ui.log"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|log}"
        echo ""
        echo "  start   - 后台启动 x-ui"
        echo "  stop    - 停止 x-ui"
        echo "  restart - 重启 x-ui"
        echo "  status  - 查看状态"
        echo "  log     - 查看日志"
        exit 1
        ;;
esac
MGMTEOF

chmod +x ../x-ui.sh

# ==================== 清理 ====================
cd "$INSTALL_DIR"
rm -f x-ui.tar.gz

# ==================== 保存配置信息 ====================
cat > x-ui-info.txt << EOF
========================================
x-ui 安装信息
========================================
版本: ${last_version}
安装目录: ${INSTALL_DIR}
访问地址: http://${SERVER_IP}:${XUI_PORT}
默认用户: ${XUI_USER}
默认密码: ${XUI_PASS}

========================================
管理命令
========================================
前台启动: cd ${INSTALL_DIR} && bash start.sh
后台启动: ${INSTALL_DIR}/x-ui.sh start
停止服务: ${INSTALL_DIR}/x-ui.sh stop
重启服务: ${INSTALL_DIR}/x-ui.sh restart
查看状态: ${INSTALL_DIR}/x-ui.sh status
查看日志: ${INSTALL_DIR}/x-ui.sh log

或直接操作:
启动: cd ${INSTALL_DIR} && bash start.sh
停止: pkill -f x-ui
日志: tail -f ${INSTALL_DIR}/xui.log

========================================
重要提示
========================================
1. 首次登录后请立即修改密码
2. 确保端口 ${XUI_PORT} 已开放
3. 数据库位置: ${INSTALL_DIR}/x-ui/db/x-ui.db

========================================
EOF

# ==================== 显示完成信息 ====================
echo ""
echo -e "${green}========================================${plain}"
echo -e "${green}🎉 x-ui v${last_version} 安装完成！${plain}"
echo -e "${green}========================================${plain}"
echo ""
echo -e "${yellow}📍 安装目录:${plain} ${INSTALL_DIR}"
echo -e "${yellow}🌐 访问地址:${plain} http://${SERVER_IP}:${XUI_PORT}"
echo -e "${yellow}👤 默认用户:${plain} ${XUI_USER}"
echo -e "${yellow}🔑 默认密码:${plain} ${XUI_PASS}"
echo ""
echo -e "${green}========================================${plain}"
echo -e "${yellow}🚀 启动命令:${plain}"
echo ""
echo -e "   前台运行: cd ${INSTALL_DIR} && bash start.sh"
echo -e "   后台运行: ${INSTALL_DIR}/x-ui.sh start"
echo ""
echo -e "${yellow}📝 查看配置:${plain}"
echo -e "   cat ${INSTALL_DIR}/x-ui-info.txt"
echo ""
echo -e "${green}========================================${plain}"
echo ""

# ==================== 询问是否立即启动 ====================
read -p "是否立即启动 x-ui? [y/n]: " START_NOW

if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${green}🚀 正在启动 x-ui...${plain}"
    echo ""
    cd "$INSTALL_DIR"
    bash start.sh
else
    echo ""
    echo -e "${yellow}稍后手动启动:${plain}"
    echo -e "   cd ${INSTALL_DIR} && bash start.sh"
    echo -e "   或"
    echo -e "   ${INSTALL_DIR}/x-ui.sh start"
    echo ""
fi
