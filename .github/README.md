# 🚀 球探社 GitHub Actions CI/CD

这个目录包含了球探社项目的GitHub Actions工作流配置，提供完整的CI/CD支持。

## 📋 工作流概览

### 1. 🔍 PR检查 (`pr-check.yml`)
**触发条件**: Pull Request创建或更新
**用途**: 快速检查代码质量，确保PR可以安全合并

**包含步骤**:
- ✅ 代码格式检查 (Flutter & Deno)
- 🔍 静态代码分析
- 🧪 单元测试
- 🏗️ 构建验证
- 📊 PR变更分析

### 2. 🚀 完整CI/CD (`ci-cd.yml`)
**触发条件**: 
- Push到 `main` 或 `develop` 分支
- 手动触发 (workflow_dispatch)
- 创建release tag

**包含步骤**:
- 🔍 代码质量检查
- 🧪 完整测试套件
- 🌐 Web应用构建
- 🤖 Android APK/AAB构建
- 🍎 iOS应用构建 (macOS runner)
- 🖥️ macOS应用构建
- 📦 GitHub Pages部署
- 🐳 Docker镜像构建
- 🏷️ 自动Release创建

## 🛠️ 使用说明

### 基本工作流

1. **开发阶段**: 创建Pull Request时自动运行PR检查
2. **合并阶段**: 合并到main分支时运行完整CI/CD
3. **发布阶段**: 创建版本标签时自动创建Release

### 手动触发部署

可以通过GitHub界面手动触发部署：

1. 前往 Actions 页面
2. 选择 "球探社 CI/CD Pipeline"
3. 点击 "Run workflow"
4. 选择部署环境 (staging/production)

### 版本发布

创建新版本的步骤：

```bash
# 创建并推送版本标签
git tag v1.2.0
git push origin v1.2.0
```

这将自动触发：
- 完整的构建流程
- 创建GitHub Release
- 上传构建产物 (APK, AAB等)

## 🔧 配置要求

### GitHub仓库设置

1. **启用GitHub Pages**:
   - Settings → Pages
   - Source: GitHub Actions

2. **配置Repository Secrets** (如需Docker部署):
   ```
   DOCKER_USERNAME: your-docker-username
   DOCKER_PASSWORD: your-docker-password
   ```

3. **分支保护** (推荐):
   - 要求PR检查通过才能合并
   - 要求代码审查

### 本地开发环境

确保本地环境符合要求：

```bash
# Flutter版本
flutter --version  # 应为 3.32.4

# Deno版本  
deno --version     # 应为 2.0.0

# 代码格式化
flutter format lib/
cd backend && deno fmt
```

## 📦 构建产物

### Web应用
- 📍 部署地址: `https://yourusername.github.io/ball-scout`
- 🔄 自动更新: 每次push到main分支

### 移动应用
- 🤖 Android APK: Actions Artifacts
- 🤖 Android AAB: Actions Artifacts  
- 🍎 iOS App: Actions Artifacts (需要macOS签名)

### Docker镜像
- 🐳 镜像地址: `yourusername/ball-scout:latest`
- 📦 多平台支持: linux/amd64, linux/arm64

## 🔍 监控和调试

### 查看构建状态
- GitHub仓库主页会显示workflow状态徽章
- Actions页面可查看详细执行日志

### 常见问题解决

1. **依赖缓存问题**:
   ```bash
   # 清理Flutter缓存
   flutter clean
   flutter pub get
   
   # 清理Deno缓存
   deno cache --reload backend/mod.ts
   ```

2. **构建失败**:
   - 检查Flutter/Deno版本是否匹配
   - 确保代码通过本地格式化检查
   - 查看Actions日志获取具体错误信息

3. **部署问题**:
   - 确认GitHub Pages已启用
   - 检查仓库权限设置
   - 验证Secrets配置正确

## 📊 性能优化

### 缓存策略
- Flutter依赖缓存: 30天
- Deno模块缓存: 自动
- Docker层缓存: GitHub Actions cache

### 并行执行
- PR检查: 快速并行验证
- 构建任务: 按平台并行执行
- 测试任务: Flutter/Deno独立运行

## 🔐 安全考虑

- 使用官方Actions (actions/*, subosito/*, denoland/*)
- Secrets通过GitHub加密存储
- 分支保护规则防止未经检查的代码合并
- 依赖项固定版本号避免供应链攻击

## 📈 扩展建议

### 未来可添加的功能

1. **代码质量评分**: SonarCloud集成
2. **性能测试**: Web Vitals监控
3. **自动化测试**: E2E测试集成
4. **安全扫描**: CodeQL代码安全分析
5. **依赖更新**: Dependabot自动PR
6. **多环境部署**: Staging/Production环境隔离

### 通知集成

```yaml
# 可添加到workflow中
- name: Slack通知
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

💡 **提示**: 第一次运行可能需要较长时间，后续运行会因为缓存而更快。如有问题，请查看Actions日志或创建Issue。 