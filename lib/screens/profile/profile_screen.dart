import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../utils/theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              context.go('/settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 用户信息卡片
            _buildUserInfoCard(context, authState),
            const SizedBox(height: 24),
            
            // 功能菜单
            _buildMenuSection(context, ref),
            const SizedBox(height: 24),
            
            // 统计信息
            _buildStatsSection(context),
            const SizedBox(height: 24),
            
            // 退出登录按钮
            _buildLogoutButton(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, AuthState authState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 头像
            CircleAvatar(
              radius: 40,
                             backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
              child: authState.user?.avatar != null
                  ? ClipOval(
                      child: Image.network(
                        authState.user!.avatar!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 40,
                            color: AppTheme.primaryGreen,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 40,
                      color: AppTheme.primaryGreen,
                    ),
            ),
            const SizedBox(height: 16),
            
            // 用户名
            Text(
              authState.user?.displayName ?? '用户',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            // 邮箱
            Text(
              authState.user?.email ?? '',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            
            // 等级标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                                 color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Lv.${authState.user?.level ?? 1} 球迷',
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, WidgetRef ref) {
    final menuItems = [
      _MenuItem(
        icon: Icons.favorite_outline,
        title: '我的收藏',
        subtitle: '收藏的新闻和文章',
        onTap: () => context.go('/favorites'),
      ),
      _MenuItem(
        icon: Icons.history,
        title: '阅读历史',
        subtitle: '查看最近阅读的内容',
        onTap: () => context.go('/reading-history'),
      ),
      _MenuItem(
        icon: Icons.notifications_none,
        title: '消息通知',
        subtitle: '管理推送和通知设置',
        onTap: () => _showComingSoon(context, '消息通知'),
      ),
      _MenuItem(
        icon: Icons.sports_soccer_outlined,
        title: '关注球队',
        subtitle: '管理关注的球队',
        onTap: () => _showComingSoon(context, '关注球队'),
      ),
      _MenuItem(
        icon: Icons.share_outlined,
        title: '分享应用',
        subtitle: '推荐给朋友',
        onTap: () => _showComingSoon(context, '分享'),
      ),
      _MenuItem(
        icon: Icons.help_outline,
        title: '帮助与反馈',
        subtitle: '使用帮助和问题反馈',
        onTap: () => _showComingSoon(context, '帮助'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '功能菜单',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: menuItems.map((item) => _buildMenuItem(item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return ListTile(
      leading: Icon(
        item.icon,
        color: AppTheme.primaryGreen,
      ),
      title: Text(item.title),
      subtitle: Text(item.subtitle),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
      onTap: item.onTap,
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '数据统计',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.article_outlined,
                title: '阅读文章',
                value: '156',
                color: AppTheme.techBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.schedule,
                title: '阅读时长',
                value: '32h',
                color: AppTheme.accentOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.favorite_outline,
                title: '收藏数',
                value: '24',
                color: Colors.pink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutDialog(context, ref),
        icon: const Icon(
          Icons.logout,
          color: Colors.red,
        ),
        label: const Text(
          '退出登录',
          style: TextStyle(color: Colors.red),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature功能开发中，敬请期待...')),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authStateProvider.notifier).logout();
            },
            child: const Text(
              '退出',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
} 