import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/auth/login_screen.dart';
import 'screens/news/news_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'utils/theme.dart';
import 'services/auth_service.dart';
import 'widgets/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Hive
  await Hive.initFlutter();
  
  runApp(
    const ProviderScope(
      child: BallScoutApp(),
    ),
  );
}

class BallScoutApp extends ConsumerWidget {
  const BallScoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            // 检查是否是登录页面
            if (state.matchedLocation == '/login') {
              return child;
            }
            // 其他页面使用底部导航栏包装
            return MainNavigation(child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeTab(),
              ),
            ),
            GoRoute(
              path: '/news',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: NewsScreen(),
              ),
            ),
            GoRoute(
              path: '/news/:id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return NewsDetailScreen(newsId: id);
              },
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ProfileScreen(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
      ],
      redirect: (context, state) {
        final authService = ref.read(authServiceProvider);
        final isLoggedIn = authService.isLoggedIn;
        final isGoingToLogin = state.matchedLocation == '/login';

        // 如果未登录且不是去登录页面，则重定向到登录页面
        if (!isLoggedIn && !isGoingToLogin) {
          return '/login';
        }

        // 如果已登录且在登录页面，则重定向到首页
        if (isLoggedIn && isGoingToLogin) {
          return '/';
        }

        return null;
      },
    );

    return MaterialApp.router(
      title: '球探社',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: const Locale('zh', 'CN'),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 标签页组件
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('球探社'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: 实现搜索功能
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 64,
              color: AppTheme.primaryGreen,
            ),
            SizedBox(height: 16),
            Text(
              '欢迎来到球探社',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '发现真正的足球世界',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsDetailScreen extends StatelessWidget {
  final String newsId;

  const NewsDetailScreen({
    super.key,
    required this.newsId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新闻详情'),
      ),
      body: Center(
        child: Text('新闻详情页面: $newsId'),
      ),
    );
  }
} 