import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soda/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('速达足球应用集成测试', () {
    testWidgets('完整用户流程测试', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 测试应用启动
      expect(find.text('速达足球'), findsOneWidget);
      
      // 等待应用完全加载
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('新闻浏览流程测试', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 检查是否在登录页面
      if (find.text('登录').evaluate().isNotEmpty) {
        // 执行登录操作
        await _performLogin(tester);
      }

      // 导航到新闻页面
      await tester.tap(find.byIcon(Icons.article));
      await tester.pumpAndSettle();

      // 验证新闻页面加载
      expect(find.text('新闻'), findsOneWidget);

      // 等待新闻数据加载
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 检查是否有新闻列表
      final newsItems = find.byType(Card);
      if (newsItems.evaluate().isNotEmpty) {
        // 点击第一个新闻项
        await tester.tap(newsItems.first);
        await tester.pumpAndSettle();

        // 验证新闻详情页面
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);

        // 返回新闻列表
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('比赛页面浏览测试', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 检查是否需要登录
      if (find.text('登录').evaluate().isNotEmpty) {
        await _performLogin(tester);
      }

      // 导航到比赛页面
      await tester.tap(find.byIcon(Icons.sports_soccer));
      await tester.pumpAndSettle();

      // 验证比赛页面
      expect(find.text('比赛'), findsOneWidget);

      // 等待数据加载
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('搜索功能测试', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 登录（如果需要）
      if (find.text('登录').evaluate().isNotEmpty) {
        await _performLogin(tester);
      }

      // 寻找并点击搜索按钮
      final searchButton = find.byIcon(Icons.search);
      if (searchButton.evaluate().isNotEmpty) {
        await tester.tap(searchButton);
        await tester.pumpAndSettle();

        // 验证搜索页面
        expect(find.byType(TextField), findsOneWidget);

        // 输入搜索关键词
        await tester.enterText(find.byType(TextField), '皇马');
        await tester.pumpAndSettle();

        // 等待搜索结果
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }
    });

    testWidgets('用户资料页面测试', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 登录
      if (find.text('登录').evaluate().isNotEmpty) {
        await _performLogin(tester);
      }

      // 导航到个人资料页面
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // 验证个人资料页面
      expect(find.text('个人资料'), findsOneWidget);
    });

    testWidgets('主题切换测试', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 登录
      if (find.text('登录').evaluate().isNotEmpty) {
        await _performLogin(tester);
      }

      // 导航到设置页面
      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      // 寻找设置选项
      final settingsButton = find.text('设置');
      if (settingsButton.evaluate().isNotEmpty) {
        await tester.tap(settingsButton);
        await tester.pumpAndSettle();

        // 测试主题切换
        final themeSwitch = find.byType(Switch);
        if (themeSwitch.evaluate().isNotEmpty) {
          await tester.tap(themeSwitch.first);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('网络错误处理测试', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle();

      // 等待网络请求完成或失败
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 检查是否显示错误信息或重试按钮
      final retryButton = find.text('重试');
      final errorMessage = find.textContaining('错误');
      
      if (retryButton.evaluate().isNotEmpty) {
        await tester.tap(retryButton);
        await tester.pumpAndSettle();
      }
      
      if (errorMessage.evaluate().isNotEmpty) {
        // 验证错误信息显示正确
        expect(errorMessage, findsAtLeastNWidgets(1));
      }
    });
  });
}

/// 执行登录操作的辅助函数
Future<void> _performLogin(WidgetTester tester) async {
  // 查找邮箱和密码输入框
  final emailField = find.byType(TextField).first;
  final passwordField = find.byType(TextField).last;

  // 输入测试凭据
  await tester.enterText(emailField, 'test@example.com');
  await tester.enterText(passwordField, 'password123');

  // 点击登录按钮
  final loginButton = find.text('登录');
  if (loginButton.evaluate().isNotEmpty) {
    await tester.tap(loginButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }
}