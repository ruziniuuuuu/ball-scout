import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';

// 通知设置Provider
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettings {
  final bool pushEnabled;
  final bool newsEnabled;
  final bool matchEnabled;
  final bool transferEnabled;
  final bool commentsEnabled;

  const NotificationSettings({
    this.pushEnabled = true,
    this.newsEnabled = true,
    this.matchEnabled = true,
    this.transferEnabled = true,
    this.commentsEnabled = true,
  });

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? newsEnabled,
    bool? matchEnabled,
    bool? transferEnabled,
    bool? commentsEnabled,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      newsEnabled: newsEnabled ?? this.newsEnabled,
      matchEnabled: matchEnabled ?? this.matchEnabled,
      transferEnabled: transferEnabled ?? this.transferEnabled,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  static const String _settingsKey = 'notification_settings';

  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      pushEnabled: prefs.getBool('${_settingsKey}_push') ?? true,
      newsEnabled: prefs.getBool('${_settingsKey}_news') ?? true,
      matchEnabled: prefs.getBool('${_settingsKey}_match') ?? true,
      transferEnabled: prefs.getBool('${_settingsKey}_transfer') ?? true,
      commentsEnabled: prefs.getBool('${_settingsKey}_comments') ?? true,
    );
  }

  Future<void> updatePushEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_settingsKey}_push', value);
    state = state.copyWith(pushEnabled: value);
  }

  Future<void> updateNewsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_settingsKey}_news', value);
    state = state.copyWith(newsEnabled: value);
  }

  Future<void> updateMatchEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_settingsKey}_match', value);
    state = state.copyWith(matchEnabled: value);
  }

  Future<void> updateTransferEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_settingsKey}_transfer', value);
    state = state.copyWith(transferEnabled: value);
  }

  Future<void> updateCommentsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_settingsKey}_comments', value);
    state = state.copyWith(commentsEnabled: value);
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息通知'),
      ),
      body: ListView(
        children: [
          // 推送开关
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.notifications_active,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          '推送通知',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: settings.pushEnabled,
                        onChanged: (value) {
                          ref.read(notificationSettingsProvider.notifier)
                              .updatePushEnabled(value);
                        },
                      ),
                    ],
                  ),
                ),
                if (!settings.pushEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      '关闭后，您将不会收到任何推送通知',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 通知类型设置
          if (settings.pushEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                '通知类型',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildNotificationItem(
                    context,
                    ref,
                    icon: Icons.article_outlined,
                    title: '新闻推送',
                    subtitle: '重要新闻和最新资讯',
                    value: settings.newsEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier)
                          .updateNewsEnabled(value);
                    },
                  ),
                  const Divider(height: 1),
                  _buildNotificationItem(
                    context,
                    ref,
                    icon: Icons.sports_soccer,
                    title: '比赛提醒',
                    subtitle: '关注球队的比赛开始提醒',
                    value: settings.matchEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier)
                          .updateMatchEnabled(value);
                    },
                  ),
                  const Divider(height: 1),
                  _buildNotificationItem(
                    context,
                    ref,
                    icon: Icons.swap_horiz,
                    title: '转会动态',
                    subtitle: '重要转会消息和传闻',
                    value: settings.transferEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier)
                          .updateTransferEnabled(value);
                    },
                  ),
                  const Divider(height: 1),
                  _buildNotificationItem(
                    context,
                    ref,
                    icon: Icons.comment_outlined,
                    title: '评论回复',
                    subtitle: '收到评论和回复时通知',
                    value: settings.commentsEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier)
                          .updateCommentsEnabled(value);
                    },
                  ),
                ],
              ),
            ),
          ],

          // 提示信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '您可以在系统设置中管理应用的通知权限',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryGreen),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

