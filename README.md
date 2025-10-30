# 速达足球 (Soda Soccer Radar)
打造面向中文球迷的专业足球资讯聚合平台。

## 项目简介
速达足球聚合全球足球媒体资讯，整合翻译、分类、社区互动与数据分析能力，为用户提供可信、实时、无广告的足球内容体验。

## 核心功能
- 全球媒体聚合与筛选
- AI 翻译及术语优化
- 新闻、比赛与转会分类
- 评论互动与圈子社区
- 数据统计与趋势分析

## 技术栈
- 前端：Flutter (Dart)
- 后端：Deno + TypeScript
- 数据库：PostgreSQL, Redis
- AI 服务：DeepSeek、Claude、GPT-4、通义千问
- 部署：Docker, Kubernetes

## 项目结构
```
soda/
├── lib/           # Flutter 客户端
├── backend/       # Deno 服务
├── docs/          # 项目文档
├── scripts/       # 辅助脚本
└── README.md
```

## 快速开始
```
# 克隆项目
 git clone <repository-url>
 cd soda

# 安装依赖
 flutter pub get

# 启动后端
 cd backend
 deno task dev

# 启动客户端
 cd ..
 flutter run
```

后端默认监听 `8080` 端口，可通过设置环境变量 `PORT=<自定义端口>` 覆盖。

## 开发路线
- MVP：新闻聚合、翻译、用户认证、评论互动
- 强化阶段：推荐引擎、数据可视化、社区极速具
- 体验阶段：离线阅读、多端同步、会员体系

## 贡献指南
欢迎提交 Issue 或 Pull Request，重大改动请先沟通需求。

## 许可证
项目采用 MIT 许可证，详见 `LICENSE`。 