# 🤖 球探社自动化新闻爬取和翻译功能指南

## 📋 功能概述

球探社现已实现了完整的自动化新闻爬取和翻译功能，可以：

- ✅ **自动爬取** 全球主要足球媒体RSS源（BBC Sport、ESPN、Goal.com、Sky Sports、Marca）
- ✅ **AI智能翻译** 使用DeepSeek等大模型将英文/西班牙文新闻翻译为中文
- ✅ **静态页面生成** 自动生成美观的HTML页面展示翻译后的新闻
- ✅ **定时任务** 支持定时自动化执行爬取和翻译流程
- ✅ **API管理** 提供完整的REST API来管理爬取器

## 🚀 快速开始

### 1. 配置DeepSeek API密钥

```bash
# 复制配置文件
cp backend/config.example.env backend/.env

# 编辑配置文件，添加DeepSeek API密钥
# DEEPSEEK_API_KEY=sk-your-deepseek-api-key-here
```

### 2. 启动后端服务

```bash
cd backend
deno run --allow-all mod.ts
```

### 3. 测试功能

```bash
# 运行自动化测试脚本
./scripts/test-news-crawler.sh
```

## 🔧 API 使用说明

### 基础端点

- 基础URL: `http://localhost:8000`
- 所有响应格式: JSON

### 爬取器管理API

#### 获取爬取器状态
```bash
GET /api/v1/crawler/status
```

#### 启动自动化爬取服务
```bash
POST /api/v1/crawler/start
```

#### 停止自动化爬取服务
```bash
POST /api/v1/crawler/stop
```

#### 手动执行一次爬取
```bash
POST /api/v1/crawler/run-once
```

#### 获取生成的静态页面列表
```bash
GET /api/v1/crawler/static-pages
```

### 翻译服务API

#### 手动翻译
```bash
POST /api/v1/translate
Content-Type: application/json

{
  "text": "Manchester United signed a new striker",
  "sourceLanguage": "en",
  "targetLanguage": "zh-CN",
  "domain": "football",
  "priority": "high"
}
```

#### 翻译服务状态
```bash
GET /api/v1/translate/status
```

## 📄 生成的静态页面

### 主页
- 位置: `./static/index.html`
- 内容: 最新翻译的足球新闻列表
- 样式: 现代化响应式设计

### 新闻详情页
- 位置: `./static/news/{news_id}.html`
- 内容: 完整的新闻内容（中文翻译版）
- 功能: 包含原文链接、翻译信息等

## ⚙️ 配置选项

### 爬取器配置

```typescript
interface AutoCrawlerConfig {
  interval: number;           // 爬取间隔（分钟），默认30
  maxNewsPerRun: number;      // 每次最大处理新闻数，默认50
  enableTranslation: boolean; // 是否启用翻译，默认true
  saveToDatabase: boolean;    // 是否保存到数据库，默认true
  generateStatic: boolean;    // 是否生成静态页面，默认true
}
```

### 翻译优先级

- `high`: 重要新闻（重要性评分≥4）
- `medium`: 一般新闻
- `low`: 普通新闻

## 🌐 支持的新闻源

| 新闻源 | 语言 | RSS地址 | 状态 |
|---------|------|---------|------|
| BBC Sport | 英文 | https://feeds.bbci.co.uk/sport/football/rss.xml | ✅ |
| ESPN Soccer | 英文 | https://www.espn.com/soccer/rss | ✅ |
| Goal.com | 英文 | https://www.goal.com/feeds/news | ✅ |
| Sky Sports | 英文 | https://www.skysports.com/rss/football | ✅ |
| Marca | 西班牙文 | https://feeds.marca.com/marca/rss/futbol/primera-division/rss.xml | ✅ |

## 🤖 支持的AI翻译服务

| 服务商 | 优先级 | 成本 | 质量 | 状态 |
|---------|--------|------|------|------|
| DeepSeek | 🥇 主力 | 极低 | 高 | ✅ |
| Claude | 🥈 备选 | 中等 | 极高 | ✅ |
| OpenAI | 🥉 备选 | 高 | 高 | ✅ |
| 通义千问 | 辅助 | 低 | 中高 | ✅ |

## 📊 功能特性

### 智能内容分析
- ✅ 自动分类（转会、比赛、新闻、分析、传言、伤病）
- ✅ 实体提取（球员、球队、联赛名称）
- ✅ 情感分析（积极、消极、中性）
- ✅ 重要性评分（1-5分）
- ✅ 可信度评分（基于新闻源）

### 翻译质量保证
- ✅ 足球术语专业词典
- ✅ 球员球队中文译名标准化
- ✅ 多级质量评估
- ✅ 自动重试机制
- ✅ 缓存避免重复翻译

### 静态页面优化
- ✅ 响应式设计
- ✅ 移动端适配
- ✅ SEO友好
- ✅ 快速加载
- ✅ 美观的UI设计

## 🔍 使用示例

### 1. 启动自动化服务并查看状态

```bash
# 启动服务
curl -X POST http://localhost:8000/api/v1/crawler/start

# 查看状态
curl http://localhost:8000/api/v1/crawler/status
```

### 2. 手动测试翻译功能

```bash
curl -X POST http://localhost:8000/api/v1/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Real Madrid signed Kylian Mbappé from PSG",
    "sourceLanguage": "en", 
    "targetLanguage": "zh-CN",
    "domain": "football",
    "priority": "high"
  }'
```

### 3. 运行一次性爬取任务

```bash
# 手动触发爬取
curl -X POST http://localhost:8000/api/v1/crawler/run-once

# 检查生成的页面
curl http://localhost:8000/api/v1/crawler/static-pages
```

## 🚨 注意事项

1. **API密钥**: 确保配置了DeepSeek API密钥以启用真实翻译功能
2. **网络连接**: 需要稳定的网络连接访问国外新闻源
3. **存储空间**: 静态页面和图片会占用一定存储空间
4. **API限制**: 注意AI服务的API调用频率限制
5. **RSS可用性**: 某些RSS源可能因网络问题偶尔不可用

## 📈 性能优化

- ✅ **并发控制**: 批量翻译时控制并发数量
- ✅ **缓存机制**: 避免重复翻译相同内容
- ✅ **错误重试**: 智能重试失败的请求
- ✅ **资源限制**: 控制每次处理的新闻数量
- ✅ **定时优化**: 合理设置爬取间隔

## 🔧 故障排除

### 常见问题

1. **翻译失败**: 检查API密钥配置
2. **RSS解析失败**: 检查网络连接
3. **静态页面未生成**: 确保有写入权限
4. **服务无法启动**: 检查端口占用

### 日志查看

服务运行时会输出详细日志，包括：
- 📡 RSS获取状态
- 🤖 翻译进度
- 📄 页面生成结果
- ❌ 错误信息

## 🎯 下一步计划

- [ ] 数据库存储集成
- [ ] 更多新闻源支持
- [ ] 图片本地化存储
- [ ] 新闻去重优化
- [ ] 用户订阅功能
- [ ] 移动端优化

---

**享受智能化的足球新闻体验！⚽🤖** 