#!/bin/bash

# 球探社开发环境启动脚本
echo "🏆 球探社 - 开发环境启动脚本"
echo "================================"

# 检查依赖
echo "📋 检查环境依赖..."

# 检查 Deno
if ! command -v deno &> /dev/null; then
    echo "❌ Deno 未安装，请先安装 Deno"
    echo "💡 安装命令: curl -fsSL https://deno.land/install.sh | sh"
    exit 1
fi

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装，请先安装 Flutter"
    echo "💡 请访问 https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "✅ 环境依赖检查通过"

# 创建日志目录
mkdir -p logs

# 函数：启动后端服务
start_backend() {
    echo "🚀 启动后端服务..."
    cd backend
    
    # 检查环境变量文件
    if [ ! -f ".env" ]; then
        echo "⚠️ 创建默认环境变量文件..."
        cp .env.example .env 2>/dev/null || echo "PORT=8000" > .env
    fi
    
    # 启动后端
    echo "📡 Deno后端服务启动中..."
    deno task dev > ../logs/backend.log 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > ../logs/backend.pid
    
    # 等待服务启动
    sleep 3
    
    # 检查服务是否启动成功
    if curl -s http://localhost:8000/health > /dev/null; then
        echo "✅ 后端服务启动成功 (PID: $BACKEND_PID)"
        echo "🌐 API地址: http://localhost:8000"
        echo "📖 API文档: http://localhost:8000/api"
    else
        echo "❌ 后端服务启动失败，请检查日志: logs/backend.log"
        return 1
    fi
    
    cd ..
}

# 函数：启动前端服务
start_frontend() {
    echo "🎨 启动前端服务..."
    
    # 检查依赖
    if [ ! -d "build" ]; then
        echo "📦 安装Flutter依赖..."
        flutter pub get
    fi
    
    # 启动前端
    echo "📱 Flutter前端服务启动中..."
    flutter run -d web-server --web-port=3000 > logs/frontend.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > logs/frontend.pid
    
    sleep 5
    echo "✅ 前端服务启动成功 (PID: $FRONTEND_PID)"
    echo "🌐 前端地址: http://localhost:3000"
}

# 函数：停止所有服务
stop_services() {
    echo "🛑 停止所有服务..."
    
    if [ -f "logs/backend.pid" ]; then
        BACKEND_PID=$(cat logs/backend.pid)
        kill $BACKEND_PID 2>/dev/null && echo "✅ 后端服务已停止"
        rm logs/backend.pid
    fi
    
    if [ -f "logs/frontend.pid" ]; then
        FRONTEND_PID=$(cat logs/frontend.pid)
        kill $FRONTEND_PID 2>/dev/null && echo "✅ 前端服务已停止"
        rm logs/frontend.pid
    fi
    
    # 清理可能残留的进程
    pkill -f "deno.*mod.ts" 2>/dev/null
    pkill -f "flutter.*run" 2>/dev/null
}

# 信号处理
trap stop_services EXIT

# 参数处理
case "$1" in
    "backend")
        start_backend
        echo "📡 仅后端模式运行，按 Ctrl+C 停止"
        wait
        ;;
    "frontend")
        start_frontend
        echo "📱 仅前端模式运行，按 Ctrl+C 停止"
        wait
        ;;
    "stop")
        stop_services
        exit 0
        ;;
    *)
        # 默认启动全部服务
        echo "🔄 启动全部服务..."
        start_backend
        if [ $? -eq 0 ]; then
            start_frontend
            echo ""
            echo "🎉 球探社开发环境启动完成！"
            echo "📡 后端API: http://localhost:8000"
            echo "📱 前端界面: http://localhost:3000"
            echo "📋 查看日志: tail -f logs/backend.log 或 logs/frontend.log"
            echo "🛑 停止服务: ./dev-start.sh stop 或 Ctrl+C"
            echo ""
            echo "⌛ 保持服务运行中，按 Ctrl+C 停止..."
            wait
        fi
        ;;
esac 