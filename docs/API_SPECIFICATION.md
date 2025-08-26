# 球探社 API 规范文档 v1.5

## 概述

球探社 API 提供足球新闻、比赛数据、用户认证和社区功能的完整RESTful API接口。

**基础信息**
- API版本: v1.5
- 基础URL: `http://localhost:8000/api/v1`
- 响应格式: JSON
- 字符编码: UTF-8

## 认证

### JWT Token 认证
所有需要用户身份验证的接口都需要在请求头中包含JWT token：

```
Authorization: Bearer {your-jwt-token}
```

## 统一响应格式

### 成功响应
```json
{
  "success": true,
  "data": "具体数据内容",
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "timestamp": "2024-01-20T10:30:00.000Z"
  }
}
```

### 错误响应
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "错误描述",
    "details": "详细错误信息(可选)"
  },
  "meta": {
    "timestamp": "2024-01-20T10:30:00.000Z"
  }
}
```

## 新闻相关接口

### 获取新闻列表

**接口地址**: `GET /news`

**查询参数**:
| 参数 | 类型 | 必选 | 默认值 | 说明 |
|------|------|------|--------|------|
| page | int | 否 | 1 | 页码 |
| limit | int | 否 | 20 | 每页数量 |
| category | string | 否 | - | 新闻分类 (news/transfer/match/analysis) |
| source | string | 否 | - | 新闻来源 |
| language | string | 否 | - | 语言 |

**响应示例**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "title": "新闻标题",
      "summary": "新闻摘要",
      "source": "ESPN",
      "category": "transfer",
      "publishedAt": "2024-01-20T10:00:00.000Z",
      "readCount": 1250,
      "imageUrl": "https://example.com/image.jpg"
    }
  ],
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "timestamp": "2024-01-20T10:30:00.000Z"
  }
}
```

### 获取新闻详情

**接口地址**: `GET /news/{id}`

**路径参数**:
| 参数 | 类型 | 必选 | 说明 |
|------|------|------|------|
| id | string | 是 | 新闻ID |

**响应示例**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "title": "新闻标题",
    "content": "完整新闻内容(HTML)",
    "summary": "新闻摘要",
    "source": "ESPN",
    "author": "记者名字",
    "publishedAt": "2024-01-20T10:00:00.000Z",
    "category": "transfer",
    "tags": ["皇马", "转会", "巴西"],
    "readCount": 1250,
    "imageUrl": "https://example.com/image.jpg"
  }
}
```

## 比赛相关接口

### 获取比赛列表

**接口地址**: `GET /matches`

**查询参数**:
| 参数 | 类型 | 必选 | 默认值 | 说明 |
|------|------|------|--------|------|
| date | string | 否 | 今天 | 日期 (YYYY-MM-DD) |
| competition | string | 否 | - | 比赛联赛 |
| status | string | 否 | - | 比赛状态 (scheduled/live/finished) |

**响应示例**:
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "homeTeam": "皇家马德里",
      "awayTeam": "巴塞罗那",
      "homeScore": 2,
      "awayScore": 1,
      "status": "finished",
      "matchTime": "2024-01-20T20:00:00.000Z",
      "competition": "西甲",
      "venue": "伯纳乌球场"
    }
  ]
}
```

### 获取比赛详情

**接口地址**: `GET /matches/{id}`

**响应示例**:
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "homeTeam": "皇家马德里",
    "awayTeam": "巴塞罗那",
    "homeScore": 2,
    "awayScore": 1,
    "status": "finished",
    "matchTime": "2024-01-20T20:00:00.000Z",
    "competition": "西甲",
    "venue": "伯纳乌球场",
    "events": [
      {
        "id": "uuid",
        "type": "goal",
        "minute": 23,
        "player": "本泽马",
        "team": "home",
        "description": "点球破门"
      }
    ]
  }
}
```

## 用户认证接口

### 用户注册

**接口地址**: `POST /auth/register`

**请求体**:
```json
{
  "username": "用户名",
  "email": "邮箱",
  "password": "密码"
}
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "username": "用户名",
      "email": "邮箱",
      "createdAt": "2024-01-20T10:00:00.000Z"
    },
    "token": "jwt-token"
  }
}
```

### 用户登录

**接口地址**: `POST /auth/login`

**请求体**:
```json
{
  "email": "邮箱",
  "password": "密码"
}
```

### 获取用户信息

**接口地址**: `GET /auth/profile`

**需要认证**: ✅

## 翻译服务接口

### AI翻译

**接口地址**: `POST /translate`

**请求体**:
```json
{
  "text": "要翻译的文本",
  "from": "en",
  "to": "zh",
  "context": "football"
}
```

**响应示例**:
```json
{
  "success": true,
  "data": {
    "translatedText": "翻译结果",
    "provider": "deepseek",
    "confidence": 0.95
  }
}
```

## 错误码说明

| 错误码 | HTTP状态码 | 说明 |
|--------|-----------|------|
| VALIDATION_ERROR | 400 | 请求参数验证失败 |
| UNAUTHORIZED | 401 | 未授权访问 |
| FORBIDDEN | 403 | 权限不足 |
| NOT_FOUND | 404 | 资源不存在 |
| INTERNAL_ERROR | 500 | 服务器内部错误 |
| SERVICE_UNAVAILABLE | 503 | 服务暂时不可用 |

## 限流策略

- 匿名用户: 每分钟100次请求
- 认证用户: 每分钟1000次请求
- 特定接口（如翻译）: 每分钟10次请求

## SDK和工具

### Flutter SDK
项目已集成Flutter SDK，位于`lib/services/api_service.dart`

### 测试工具
```bash
# API健康检查
curl http://localhost:8000/health

# 获取新闻列表
curl http://localhost:8000/api/v1/news

# 用户登录
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

## 版本历史

- v1.5.0: 增加AI翻译功能，优化新闻爬取
- v1.0.0: 基础功能发布