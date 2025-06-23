#!/bin/bash

echo "🚀 启动球探社项目"

# 临时禁用代理设置，避免本地开发时的代理问题
echo "🔧 临时禁用代理设置..."
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY

# 启动后端服务
echo "📡 启动后端服务..."
cd backend
nohup deno run --allow-net --allow-read --allow-env mod.ts > backend.log 2>&1 &
BACKEND_PID=$!
cd ..

# 等待后端服务启动
echo "⏳ 等待后端服务启动..."
sleep 3

# 检查后端服务是否成功启动
if curl --noproxy localhost --connect-timeout 3 -s http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ 后端服务启动成功"
else
    echo "❌ 后端服务启动失败，请检查 backend/backend.log 文件"
fi

# 启动前端服务（使用web-server模式，避免Chrome代理问题）
echo "📱 启动前端服务..."
flutter run -d web-server --web-port=3000 &
FRONTEND_PID=$!

echo "✅ 项目启动完成!"
echo "🌐 前端地址: http://localhost:3000"
echo "📡 后端地址: http://localhost:8000"
echo "📖 API文档: http://localhost:8000/api"
echo ""
echo "💡 提示：如果前端无法访问后端，请在浏览器中手动访问 http://localhost:3000"
echo ""

# 等待用户输入来停止服务
echo "按 Ctrl+C 或 Enter 键停止服务..."
read

# 停止服务
echo "🛑 停止服务..."
kill $BACKEND_PID 2>/dev/null
kill $FRONTEND_PID 2>/dev/null

# 清理后端日志文件（可选）
# rm -f backend/backend.log

echo "✅ 服务已停止" 