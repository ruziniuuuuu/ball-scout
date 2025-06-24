#!/bin/bash

# 球探社 v1.5 开发环境快速启动
echo "🏆 球探社 v1.5 开发环境启动中..."

# 临时清除代理设置，避免影响本地服务访问
echo "🔧 临时清除代理设置..."
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset all_proxy
unset ALL_PROXY
echo "✅ 代理设置已清除"

# 检查端口函数
check_port() {
  local port=$1
  local service=$2
  if lsof -i :$port > /dev/null 2>&1; then
    echo "⚠️  端口 $port 已被占用 ($service)"
    echo "   使用 'lsof -i :$port' 查看占用进程"
    echo "   使用 './scripts/start-dev.sh stop' 停止服务"
    return 1
  fi
  return 0
}

# 检查命令行参数
case "$1" in
  "db")
    echo "🗄️ 启动数据库服务..."
    docker-compose -f docker-compose.dev.yml up postgres redis -d
    echo "✅ 数据库服务已启动"
    echo "📡 PostgreSQL: localhost:5432"
    echo "🔴 Redis: localhost:6379"
    ;;
  "backend")
    echo "🚀 启动后端服务..."
    cd backend && deno task dev
    ;;
  "frontend")
    echo "📱 启动球探社 Flutter 前端..."
    if command -v flutter &> /dev/null; then
      echo "使用 Flutter 启动 Web 应用..."
      flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0
    else
      echo "❌ 未找到 Flutter，请安装 Flutter SDK"
      echo "💡 临时使用测试页面..."
      if command -v python3 &> /dev/null; then
        echo "使用 Python3 启动测试页面..."
        cd web && python3 -m http.server 3000
      else
        echo "❌ 未找到 Python，无法启动服务"
        exit 1
      fi
    fi
    ;;
  "full")
    echo "🚀 启动完整开发环境..."
    
    # 启动后端服务
    docker-compose -f docker-compose.dev.yml up -d
    
    # 等待后端服务启动
    echo "⏳ 等待后端服务启动..."
    sleep 5
    
    # 测试后端连接
    echo "🧪 测试后端连接..."
    if curl -s --connect-timeout 5 http://localhost:8000/health > /dev/null; then
      echo "✅ 后端服务正常运行"
    else
      echo "⚠️  后端服务可能需要更多时间启动"
    fi
    
    # 启动前端服务
    echo "📱 启动球探社 Flutter 前端..."
    if command -v flutter &> /dev/null; then
      echo "使用 Flutter 启动 Web 应用..."
      echo "⚠️  注意：Flutter 应用将在前台运行，需要等待编译完成"
      echo "💡 应用启动后可在浏览器访问：http://localhost:3000"
      echo ""
      # 启动Flutter应用（在前台运行以便用户交互）
      flutter run -d web-server --web-port=3000 --web-hostname=localhost
    else
      echo "⚠️  未找到 Flutter，启动测试页面..."
      if command -v python3 &> /dev/null; then
        echo "使用 Python3 启动测试页面..."
        cd web && nohup python3 -m http.server 3000 > ../logs/frontend.log 2>&1 &
        FRONTEND_PID=$!
        cd ..
        echo $FRONTEND_PID > logs/frontend.pid
      else
        echo "⚠️  未找到 Python，跳过前端服务启动"
      fi
    fi
    
    # Flutter应用启动完成后会在前台运行，无需额外输出
    # 如果Flutter未安装，则会输出相关信息
    if command -v flutter &> /dev/null; then
      echo "🌐 球探社 Flutter 应用: http://localhost:3000"
      echo "📡 后端API: http://localhost:8000" 
      echo "🗄️ 数据库: localhost:5432"
      echo ""
      echo "💡 提示："
      echo "  - Flutter 应用支持热重载 (按 r 键)"
      echo "  - 如需重启应用请按 R 键"
      echo "  - 按 q 键退出 Flutter 应用"
      echo "  - 使用 './scripts/start-dev.sh stop' 停止所有服务"
    else
      echo "🌐 前端测试页面: http://localhost:3000"
      echo "📡 后端API: http://localhost:8000" 
      echo "🗄️ 数据库: localhost:5432"
      echo ""
      echo "💡 提示："
      echo "  - 前端测试页面包含API测试功能"
      echo "  - 如果无法访问，请检查防火墙设置"
      echo "  - 使用 './scripts/start-dev.sh stop' 停止所有服务"
    fi
    ;;
  "stop")
    echo "🛑 停止所有服务..."
    
    # 停止Docker服务
    docker-compose -f docker-compose.dev.yml down
    
    # 停止前端服务
    if [ -f "logs/frontend.pid" ]; then
      FRONTEND_PID=$(cat logs/frontend.pid)
      if ps -p $FRONTEND_PID > /dev/null 2>&1; then
        echo "停止前端服务 (PID: $FRONTEND_PID)..."
        kill $FRONTEND_PID
        rm logs/frontend.pid
        echo "✅ 前端服务已停止"
      else
        echo "前端服务已停止"
        rm logs/frontend.pid
      fi
    fi
    
    echo "✅ 所有服务已停止"
    ;;
  *)
    echo "使用方法:"
    echo "  ./scripts/start-dev.sh db       - 仅启动数据库"
    echo "  ./scripts/start-dev.sh backend  - 仅启动后端"
    echo "  ./scripts/start-dev.sh frontend - 仅启动前端"
    echo "  ./scripts/start-dev.sh full     - 启动完整环境"
    echo "  ./scripts/start-dev.sh stop     - 停止所有服务"
    ;;
esac 