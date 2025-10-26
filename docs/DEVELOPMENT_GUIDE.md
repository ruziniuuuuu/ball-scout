# 🏆 球探社 v1.5 开发指南

## 🎯 项目概述

球探社是一个现代化的足球资讯聚合平台，采用 Flutter 前端 + Deno 后端 + PostgreSQL 数据库的架构。

### 技术栈
- **前端**: Flutter 3.16+ (Dart)
- **后端**: Deno 1.40+ (TypeScript)
- **数据库**: PostgreSQL 15 + Redis 7
- **容器化**: Docker + Docker Compose

## 🚀 快速开始

### 1. 环境准备

```bash
# 检查必要工具
deno --version    # >= 1.40.0
flutter --version # >= 3.16.0
docker --version  # >= 20.10.0
```

### 2. 项目克隆与设置

```bash
git clone <repository-url>
cd ball-scout

# 给脚本添加执行权限
chmod +x scripts/start-dev.sh
```

### 3. 启动开发环境

#### 方式1：Docker 一键启动（推荐）
```bash
# 启动数据库服务
./scripts/start-dev.sh db

# 单独启动后端
./scripts/start-dev.sh backend

# 单独启动前端
./scripts/start-dev.sh frontend

# 停止所有服务
./scripts/start-dev.sh stop
```

#### 方式2：手动启动
```bash
# 1. 启动数据库
docker-compose -f docker-compose.dev.yml up postgres redis -d

# 2. 启动后端（新终端）
cd backend
deno task dev

# 3. 启动前端（新终端）
flutter run -d web-server --web-port=3000
```

### 4. 访问地址

- 🌐 **前端应用**: http://localhost:3000
- 📡 **后端API**: http://localhost:8080
- 📖 **API文档**: http://localhost:8080/api
- 💚 **健康检查**: http://localhost:8080/health
- 🗄️ **数据库**: localhost:5432 (用户: postgres, 密码: ballscout123)

## 🔧 开发流程

### 数据库操作

```bash
# 连接数据库
psql -h localhost -p 5432 -U postgres -d ball_scout

# 查看表结构
\dt

# 重置数据库
psql -h localhost -p 5432 -U postgres -d ball_scout -f scripts/setup-database.sql
```

### 后端开发

```bash
cd backend

# 启动开发服务器（热重载）
deno task dev

# 运行测试
deno task test

# 代码格式化
deno task fmt

# 代码检查
deno task lint
```

### 前端开发

```bash
# 获取依赖
flutter pub get

# 运行Web应用
flutter run -d web-server --web-port=3000

# 运行Android应用
flutter run -d android

# 构建Web版本
flutter build web

# 运行测试
flutter test
```

## 📱 移动端开发

### Android 打包

```bash
# 1. 构建APK
flutter build apk --release

# 2. 构建App Bundle
flutter build appbundle --release

# 3. 安装到设备
flutter install
```

### iOS 打包

```bash
# 1. 构建iOS应用
flutter build ios --release

# 2. 打开Xcode项目
open ios/Runner.xcworkspace
```

## 🤖 AI翻译集成

### 配置API密钥

在 `backend/.env` 文件中配置：

```bash
# Claude API (推荐)
CLAUDE_API_KEY=sk-ant-api03-...

# OpenAI API (备选)
OPENAI_API_KEY=sk-...

# 通义千问 (中文优化)
QWEN_API_KEY=sk-...
```

### 测试翻译服务

```bash
curl -X POST http://localhost:8000/api/v1/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Real Madrid signed a new striker",
    "sourceLanguage": "en",
    "targetLanguage": "zh-CN",
    "domain": "football"
  }'
```

## 📰 新闻聚合配置

### 添加新闻源

在 `backend/services/news/aggregator.ts` 中添加新的新闻源：

```typescript
const newSource: NewsSource = {
  id: 'example_news',
  name: 'Example News',
  baseUrl: 'https://api.example.com',
  apiKey: process.env.EXAMPLE_API_KEY,
  rateLimit: 100
};
```

### 测试新闻API

```bash
# 获取新闻列表
curl http://localhost:8000/api/v1/news

# 获取特定分类新闻
curl "http://localhost:8000/api/v1/news?category=transfer"

# 搜索新闻
curl "http://localhost:8000/api/v1/news/search?q=皇马"
```

## 🔐 用户认证

### JWT Token管理

```typescript
// 设置token
localStorage.setItem('auth_token', 'your-jwt-token');

// 使用token发起请求
const response = await fetch('/api/v1/protected', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

### 测试认证API

```bash
# 用户注册
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","password":"123456"}'

# 用户登录
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"123456"}'
```

## 📊 监控和调试

### 日志查看

```bash
# 后端日志
tail -f logs/backend.log

# 数据库日志
docker logs ballscout-postgres

# Redis日志
docker logs ballscout-redis
```

### 性能监控

```bash
# API响应时间测试
curl -w "@curl-format.txt" -s -o /dev/null http://localhost:8000/api/v1/news

# 数据库性能分析
EXPLAIN ANALYZE SELECT * FROM news_articles WHERE category = 'transfer';
```

## 🐛 常见问题

### 1. 数据库连接失败
```bash
# 检查数据库状态
docker ps | grep postgres

# 重启数据库
docker-compose -f docker-compose.dev.yml restart postgres
```

### 2. Deno权限错误
```bash
# 确保启动时包含必要权限
deno run --allow-net --allow-read --allow-env mod.ts
```

### 3. Flutter Web热重载问题
```bash
# 清理缓存重新启动
flutter clean
flutter pub get
flutter run -d web-server --web-port=3000
```

## 🔄 Git工作流

### 分支管理
- `main`: 生产分支
- `develop`: 开发分支
- `feature/*`: 功能分支
- `hotfix/*`: 热修复分支

### 提交规范
```bash
git commit -m "feat(news): 添加新闻搜索功能"
git commit -m "fix(auth): 修复登录状态丢失问题"
git commit -m "docs(readme): 更新安装指南"
```

## 📚 相关文档

- [项目状态报告](../PROJECT_STATUS.md)
- [API文档](http://localhost:8000/api)
- [Flutter官方文档](https://flutter.dev/docs)
- [Deno官方文档](https://deno.land/manual)
- [PostgreSQL文档](https://www.postgresql.org/docs/)

## 🆘 获取帮助

1. 查看现有 [Issues](https://github.com/your-repo/issues)
2. 创建新的 Issue 描述问题
3. 在开发群组中提问
4. 参考官方技术文档

---

🎉 **开始你的球探社开发之旅吧！** 