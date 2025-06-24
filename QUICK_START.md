# 🏆 球探社 v1.5 快速启动指南

## 🚀 一键启动

```bash
# 启动完整开发环境（推荐）
./scripts/start-dev.sh full

# 停止所有服务
./scripts/start-dev.sh stop
```

## 📋 服务地址

启动成功后，您可以访问以下服务：

- **🌐 前端测试页面**: http://localhost:3000
- **📡 后端API**: http://localhost:8000
- **📚 API文档**: http://localhost:8000/api
- **💚 健康检查**: http://localhost:8000/health
- **🗄️ PostgreSQL**: localhost:5432
- **🔴 Redis**: localhost:6379

## 🔧 解决代理问题

启动脚本已自动处理代理设置。如果仍有问题，请手动执行：

```bash
# 临时清除代理
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY all_proxy ALL_PROXY

# 然后访问服务
curl http://localhost:3000
curl http://localhost:8000/health
```

## 📱 前端测试页面功能

访问 http://localhost:3000 可以：

- ✅ 验证前端服务状态
- 🧪 测试后端API连接
- 📰 测试新闻API (`/api/v1/news`)
- ⚽ 测试比赛API (`/api/v1/matches`)
- 🔗 访问API文档和健康检查

## 🛠️ 单独启动服务

```bash
# 仅启动数据库
./scripts/start-dev.sh db

# 仅启动后端
./scripts/start-dev.sh backend

# 仅启动前端
./scripts/start-dev.sh frontend
```

## 🐛 故障排除

### 端口被占用
```bash
# 查看端口占用
lsof -i :3000
lsof -i :8000

# 停止服务
./scripts/start-dev.sh stop
```

### 代理问题
如果无法访问本地服务，请确保代理设置已清除：
```bash
env | grep -i proxy
```

### Docker 问题
```bash
# 查看容器状态
docker-compose -f docker-compose.dev.yml ps

# 查看日志
docker logs ballscout-backend
docker logs ballscout-postgres
docker logs ballscout-redis
```

## 🎯 下一步

1. 访问 http://localhost:3000 验证环境
2. 测试API功能
3. 开始开发你的功能！

---

**球探社开发团队** © 2024 