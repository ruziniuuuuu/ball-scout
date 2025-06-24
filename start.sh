#!/bin/bash

# 🏆 球探社项目启动脚本 v2.0
# 增强版启动脚本，支持翻译服务和环境检查

echo "🏆 欢迎使用球探社 (BallScout)"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 检查必要工具
check_requirements() {
    echo "🔍 检查运行环境..."
    
    # 检查Flutter
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ Flutter未安装，请先安装Flutter${NC}"
        exit 1
    fi
    
    # 检查Deno
    if ! command -v deno &> /dev/null; then
        echo -e "${RED}❌ Deno未安装，请先安装Deno${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 环境检查通过${NC}"
}

# 检查代理设置
check_proxy() {
    if [ ! -z "$http_proxy" ] || [ ! -z "$HTTP_PROXY" ]; then
        echo -e "${YELLOW}⚠️  检测到HTTP代理设置: $http_proxy${NC}"
        echo -e "${YELLOW}💡 如果遇到localhost连接问题，请考虑临时禁用代理${NC}"
        
        # 为curl添加noproxy设置
        export no_proxy="localhost,127.0.0.1"
        export NO_PROXY="localhost,127.0.0.1"
    fi
}

# 启动后端服务
start_backend() {
    echo "🚀 启动后端服务..."
    cd backend
    
    # 检查依赖
    echo "📦 检查后端依赖..."
    deno check mod.ts
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 后端代码检查失败${NC}"
        exit 1
    fi
    
    # 启动服务
    echo "🌐 启动Deno后端服务器..."
    deno task dev &
    BACKEND_PID=$!
    
    # 等待后端启动
    echo "⏳ 等待后端服务启动..."
    sleep 3
    
    # 检查后端健康状态
    for i in {1..10}; do
        if curl --noproxy localhost -s http://localhost:8000/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 后端服务启动成功${NC}"
            break
        fi
        if [ $i -eq 10 ]; then
            echo -e "${RED}❌ 后端服务启动失败${NC}"
            kill $BACKEND_PID 2>/dev/null
            exit 1
        fi
        echo "等待后端启动... ($i/10)"
        sleep 2
    done
    
    # 检查翻译服务状态
    echo "🤖 检查翻译服务状态..."
    TRANSLATION_STATUS=$(curl --noproxy localhost -s http://localhost:8000/api/v1/translate/status | jq -r '.data.availableProviders | length')
    if [ "$TRANSLATION_STATUS" = "0" ]; then
        echo -e "${YELLOW}⚠️  翻译服务未配置API密钥${NC}"
        echo -e "${YELLOW}💡 请在.env文件中配置CLAUDE_API_KEY或OPENAI_API_KEY${NC}"
    else
        echo -e "${GREEN}✅ 翻译服务配置正常${NC}"
    fi
    
    cd ..
}

# 启动前端服务
start_frontend() {
    echo "📱 启动前端服务..."
    
    # 生成代码
    echo "🔧 生成Flutter代码..."
    flutter packages pub run build_runner build --delete-conflicting-outputs
    
    # 启动Flutter
    echo "🌐 启动Flutter Web服务器..."
    flutter run -d web-server --web-port=3000 &
    FRONTEND_PID=$!
    
    # 等待前端启动
    echo "⏳ 等待前端服务启动..."
    sleep 5
    
    echo -e "${GREEN}✅ 前端服务启动成功${NC}"
}

# 显示服务信息
show_info() {
    echo ""
    echo "🎉 球探社服务启动完成！"
    echo "=========================================="
    echo -e "${BLUE}🌐 前端地址:${NC} http://localhost:3000"
    echo -e "${BLUE}📡 后端地址:${NC} http://localhost:8000"
    echo -e "${BLUE}📖 API文档:${NC} http://localhost:8000/api"
    echo -e "${BLUE}💚 健康检查:${NC} http://localhost:8000/health"
    echo -e "${BLUE}🤖 翻译状态:${NC} http://localhost:8000/api/v1/translate/status"
    echo ""
    echo -e "${YELLOW}💡 提示:${NC}"
    echo "• 前端支持热重载，修改代码会自动刷新"
    echo "• 后端支持文件监听，修改代码会自动重启"
    echo "• 按 Ctrl+C 停止所有服务"
    echo ""
    echo "🏆 开始您的足球资讯之旅吧！"
}

# 清理函数
cleanup() {
    echo ""
    echo "🛑 正在停止服务..."
    kill $BACKEND_PID 2>/dev/null
    kill $FRONTEND_PID 2>/dev/null
    echo "✅ 所有服务已停止"
    exit 0
}

# 主执行流程
main() {
    # 设置信号处理
    trap cleanup SIGINT SIGTERM
    
    # 执行检查和启动
    check_requirements
    check_proxy
    start_backend
    start_frontend
    show_info
    
    # 保持脚本运行
    echo "🔄 服务运行中，按 Ctrl+C 停止..."
    wait
}

# 运行主函数
main 