# 球探社测试指南

## 测试策略概述

本项目采用多层次的测试策略，确保代码质量和系统稳定性。

## 前端测试 (Flutter)

### 测试类型

1. **单元测试 (Unit Tests)**
   - 测试业务逻辑函数
   - 测试数据模型
   - 测试服务类

2. **Widget测试 (Widget Tests)**
   - 测试UI组件行为
   - 测试用户交互
   - 测试状态管理

3. **集成测试 (Integration Tests)**
   - 端到端用户流程
   - API集成测试

### 测试框架和工具

- `flutter_test`: Flutter官方测试框架
- `mockito`: Mock对象生成
- `integration_test`: 集成测试
- `golden_toolkit`: UI快照测试

### 运行测试

```bash
# 运行所有单元测试和Widget测试
flutter test

# 运行特定测试文件
flutter test test/models/news_test.dart

# 生成测试覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# 运行集成测试
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
```

### 测试文件结构

```
test/
├── models/                 # 数据模型测试
│   ├── news_test.dart
│   ├── user_test.dart
│   └── match_test.dart
├── services/              # 服务类测试
│   ├── api_service_test.dart
│   ├── auth_service_test.dart
│   └── translation_service_test.dart
├── widgets/               # Widget测试
│   ├── news_card_test.dart
│   ├── comment_section_test.dart
│   └── navigation_test.dart
├── screens/               # 屏幕测试
│   ├── news_screen_test.dart
│   ├── login_screen_test.dart
│   └── profile_screen_test.dart
└── integration_test/      # 集成测试
    ├── app_test.dart
    ├── auth_flow_test.dart
    └── news_flow_test.dart
```

## 后端测试 (Deno)

### 测试类型

1. **单元测试**
   - 测试服务函数
   - 测试数据处理逻辑
   - 测试工具函数

2. **API测试**
   - 测试HTTP接口
   - 测试请求/响应格式
   - 测试认证授权

3. **数据库测试**
   - 测试数据库操作
   - 测试数据完整性
   - 测试事务处理

### 测试框架

- Deno内置测试框架
- `@std/testing/asserts`: 断言库
- `@std/testing/mock`: Mock工具
- SuperTest风格的API测试

### 运行测试

```bash
# 进入后端目录
cd backend

# 运行所有测试
deno task test

# 运行特定测试文件
deno test services/news/news_service_test.ts

# 运行测试并生成覆盖率报告
deno test --coverage=coverage

# 查看覆盖率报告
deno coverage coverage --html
```

### 测试文件结构

```
backend/tests/
├── unit/                  # 单元测试
│   ├── services/
│   │   ├── news_service_test.ts
│   │   ├── translation_service_test.ts
│   │   └── user_service_test.ts
│   └── utils/
│       ├── validation_test.ts
│       └── helpers_test.ts
├── api/                   # API测试
│   ├── news_api_test.ts
│   ├── auth_api_test.ts
│   ├── matches_api_test.ts
│   └── translation_api_test.ts
├── integration/           # 集成测试
│   ├── news_flow_test.ts
│   ├── user_auth_test.ts
│   └── translation_flow_test.ts
└── fixtures/              # 测试数据
    ├── news_data.json
    ├── user_data.json
    └── match_data.json
```

## 测试数据管理

### 测试数据库

使用独立的测试数据库，避免污染开发数据：

```typescript
// backend/tests/setup.ts
export async function setupTestDatabase() {
  const testDb = new DatabaseManager({
    ...config.database,
    database: 'ball_scout_test'
  });
  
  await testDb.connect();
  await initializeDatabase(testDb);
  return testDb;
}
```

### Mock数据

```typescript
// backend/tests/fixtures/news_data.ts
export const mockNewsData = [
  {
    id: 'test-news-1',
    title: '测试新闻标题',
    content: '测试新闻内容',
    source: 'Test Source',
    category: 'news' as NewsCategory,
    publishedAt: new Date('2024-01-01'),
    readCount: 100
  }
];
```

## 性能测试

### 前端性能测试

```bash
# Flutter性能分析
flutter run --profile
flutter run --release
```

### 后端性能测试

使用Apache Bench或类似工具：

```bash
# 并发测试
ab -n 1000 -c 10 http://localhost:8000/api/v1/news

# 压力测试
wrk -t12 -c400 -d30s http://localhost:8000/api/v1/news
```

## 测试最佳实践

### 通用原则

1. **测试命名规范**
   ```dart
   // Good
   test('should return news list when API call succeeds', () {});
   
   // Bad
   test('news test', () {});
   ```

2. **AAA模式 (Arrange-Act-Assert)**
   ```dart
   test('should calculate time ago correctly', () {
     // Arrange
     final news = News(publishedAt: '2024-01-01T10:00:00Z');
     
     // Act
     final result = news.timeAgoText;
     
     // Assert
     expect(result, contains('天前'));
   });
   ```

3. **测试隔离**
   - 每个测试应该独立运行
   - 不依赖其他测试的结果
   - 使用setUp和tearDown清理状态

### Flutter测试最佳实践

```dart
// Widget测试示例
testWidgets('NewsCard displays news information correctly', (tester) async {
  // Arrange
  const news = News(
    id: '1',
    title: 'Test News',
    source: 'Test Source',
    // ... other properties
  );

  // Act
  await tester.pumpWidget(
    MaterialApp(
      home: NewsCard(news: news),
    ),
  );

  // Assert
  expect(find.text('Test News'), findsOneWidget);
  expect(find.text('Test Source'), findsOneWidget);
});
```

### Deno测试最佳实践

```typescript
// API测试示例
Deno.test('GET /api/v1/news returns news list', async () => {
  // Arrange
  const app = createTestApp();
  
  // Act
  const response = await supertest(app)
    .get('/api/v1/news')
    .expect(200);
  
  // Assert
  assertEquals(response.body.success, true);
  assert(Array.isArray(response.body.data));
});
```

## 持续集成测试

### GitHub Actions配置

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  flutter-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3

  deno-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: denoland/setup-deno@v1
      - run: cd backend && deno task test
      - run: cd backend && deno task lint
```

## 测试覆盖率目标

- **总体覆盖率**: 目标80%以上
- **关键业务逻辑**: 目标95%以上
- **API接口**: 目标90%以上
- **UI组件**: 目标75%以上

## 测试维护

### 定期任务

1. **每周**: 检查测试覆盖率报告
2. **每月**: 更新测试数据和Mock对象
3. **每季度**: 评估测试策略和工具选择

### 测试重构

当代码重构时，同步更新相关测试：

1. 保持测试与代码同步
2. 移除过时的测试
3. 添加新功能的测试
4. 优化慢速测试

通过遵循这些测试指南，我们可以确保球探社项目的高质量和稳定性。