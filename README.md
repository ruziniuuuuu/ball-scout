# 🏆 球探社 (BallScout)

> 打造中国最纯净的足球资讯聚合平台

## 📖 项目简介

球探社是一款革命性的足球媒体聚合App，致力于解决现有平台的痛点：
- ❌ 广告过多影响用户体验
- ❌ 信息源虚假不全面  
- ❌ 缺乏第一手权威资讯

### 🎯 核心功能
1. **全球媒体聚合** - 从世界各大足球媒体获取第一手资讯
2. **智能翻译** - AI驱动的多语言翻译，专业足球术语优化
3. **内容分类** - 自动分类新闻、赛事、转会、数据分析
4. **社区互动** - 评论区、球队圈子、用户讨论
5. **数据可视化** - 参考SofaScore的数据展示方式

## 🛠️ 技术栈

- **前端**: Flutter (Dart) - 跨平台开发
- **后端**: Deno + TypeScript - 现代化安全的运行时，内置TypeScript支持
- **数据库**: PostgreSQL + Redis
- **AI集成**: DeepSeek、Claude、GPT-4、通义千问
- **部署**: Docker + Kubernetes

## 📁 项目结构

```
ball-scout/
├── .cursor/rules/           # Cursor AI 规则配置
│   ├── project-overview.mdc      # 项目概述（始终应用）
│   ├── flutter-standards.mdc     # Flutter开发标准
│   ├── backend-services.mdc      # 后端服务规范
│   ├── ai-integration.mdc        # AI集成和翻译
│   ├── ignore-files.mdc          # 文件忽略规则
│   └── flutter_project_template.dart # 代码模板
├── lib/                     # Flutter 应用代码
├── backend/                 # 后端服务
├── docs/                    # 项目文档
└── README.md               # 项目说明
```

## 🤖 Cursor Rules 说明

本项目使用最新的Cursor Rules格式（MDC），提供智能的AI开发辅助：

### 规则类型
- **Always Apply** (`project-overview.mdc`) - 始终提供项目上下文
- **Auto Attached** (`flutter-standards.mdc`) - Flutter文件自动应用
- **Manual** - 可通过 `@ruleName` 手动调用

### 使用方法
1. 规则会根据你正在编辑的文件自动生效
2. 手动调用: 在聊天中输入 `@flutter-standards` 
3. 查看所有规则: Cursor Settings > Rules

## 🚀 开始开发

### 环境要求
- Flutter 3.16+
- Dart 3.2+
- Deno 1.38+

### 快速开始
```bash
# 克隆项目
git clone <repository-url>
cd ball-scout

# 初始化Flutter项目
flutter create --org com.ballscout .
flutter pub get

# 启动后端服务 (Deno)
cd backend
deno task dev

# 启动Flutter应用
cd ..
flutter run
```

## 📱 产品和市场建议

### 🎯 产品命名策略
**主要推荐**: "球探社" (BallScout)
- **优势**: 专业感强，易记忆，体现探索精神
- **英文名**: BallScout - 国际化友好
- **域名**: ballscout.cn / ballscout.app
- **Slogan**: "发现真正的足球世界"

**备选方案**:
- "足球雷达" (FootballRadar) - 强调信息捕捉
- "绿茵速递" (GreenExpress) - 突出快速传递
- "球迷基地" (FanBase) - 强调社区属性

### 🎨 Logo设计建议
- **主色调**: 足球绿 + 科技蓝的组合
- **核心元素**: 足球 + 雷达/望远镜图标
- **设计风格**: 简约现代，避免过度复杂
- **适配性**: 确保在各种尺寸下清晰可见

### 📱 目标用户画像
**核心用户群体**:
- **年龄**: 18-35岁足球爱好者
- **地域**: 一线二线城市为主，逐步下沉
- **特征**: 关注国际足球，英语基础较好，愿意为优质内容付费
- **痛点**: 厌倦广告干扰，渴望权威真实信息

**用户分层策略**:
- **轻度用户**: 关注热门新闻和比赛结果
- **重度用户**: 深度分析、数据统计、转会传言
- **核心用户**: 社区活跃，内容创作，意见领袖

### 🚀 上线和推广策略

**冷启动阶段**:
1. **内容为王**: 先积累优质独家内容
2. **KOL合作**: 与足球博主、解说员合作
3. **社群运营**: 微信群、QQ群精准推广
4. **差异化定位**: 主打"无广告+权威"

**增长策略**:
1. **ASO优化**: App Store/应用宝关键词优化
2. **内容营销**: 微博、抖音足球话题参与
3. **事件营销**: 世界杯、欧洲杯等大赛期间重点推广
4. **用户推荐**: 邀请机制+积分体系

**渠道建议**:
- **主渠道**: 应用宝、华为、小米、OPPO、VIVO
- **次要渠道**: App Store、豌豆荚、360手机助手
- **社交渠道**: 微信朋友圈、微博、抖音、小红书

### 💰 商业化路径
**Phase 1 - 免费获客**:
- 免费核心功能，建立用户基础
- 通过优质内容获得用户信任

**Phase 2 - 会员体系**:
- **基础版**: 免费，有限功能
- **高级版**: 月费19.9元，无广告+独家内容
- **专业版**: 月费49.9元，数据分析+专家解读

**Phase 3 - 生态变现**:
- 足球装备电商
- 赛事门票代理
- 球迷旅游服务
- 品牌合作推广

### 🏆 竞争优势构建
1. **技术优势**: AI翻译+智能分类，提供最快最准的资讯
2. **内容优势**: 全球一手资源，专业编译团队
3. **体验优势**: 零广告打扰，纯净阅读环境
4. **社区优势**: 高质量讨论，深度球迷互动

## 📈 开发路线图

### Phase 1 - MVP (3个月)
- [ ] 基础UI框架搭建
- [ ] 新闻聚合功能
- [ ] 基础翻译服务
- [ ] 用户注册登录

### Phase 2 - 核心功能 (3个月)  
- [ ] 智能分类系统
- [ ] 社区功能
- [ ] 个性化推荐
- [ ] 数据可视化

### Phase 3 - 增强体验 (3个月)
- [ ] 高级AI功能
- [ ] 离线阅读
- [ ] 多平台同步
- [ ] 商业化功能

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🙏 致谢

- 感谢所有为足球媒体行业做出贡献的开发者
- 参考了SofaScore的优秀数据展示设计
- 借鉴了懂球帝的社区功能理念 