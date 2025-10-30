import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/theme_service.dart';
import '../../utils/theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);
    final fontSizeNotifier = ref.read(fontSizeProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 外观设置
          _buildSectionHeader('外观设置'),
          Card(
            child: Column(
              children: [
                // 主题模式
                ListTile(
                  leading: Icon(
                    themeModeNotifier.themeModeIcon,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('主题模式'),
                  subtitle: Text(themeModeNotifier.themeModeDisplayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showThemeModeDialog(context, ref, themeMode),
                ),
                const Divider(height: 1),

                // 字体大小
                ListTile(
                  leading: const Icon(
                    Icons.text_fields,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('字体大小'),
                  subtitle: Text(
                      '${fontSizeNotifier.fontSizeDisplayName} (${fontSizeNotifier.fontSizePercentage})'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showFontSizeDialog(context, ref, fontSize),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 通知设置
          _buildSectionHeader('通知设置'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.notifications,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('推送通知'),
                  subtitle: const Text('接收新闻和比赛提醒'),
                  value: true, // TODO: 从设置中读取
                  onChanged: (value) {
                    // TODO: 保存通知设置
                    _showComingSoon(context, '通知设置');
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.sports_soccer,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('比赛提醒'),
                  subtitle: const Text('关注球队的比赛开始提醒'),
                  value: true, // TODO: 从设置中读取
                  onChanged: (value) {
                    _showComingSoon(context, '比赛提醒');
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.article,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('新闻推荐'),
                  subtitle: const Text('推送感兴趣的新闻'),
                  value: false, // TODO: 从设置中读取
                  onChanged: (value) {
                    _showComingSoon(context, '新闻推荐');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 阅读设置
          _buildSectionHeader('阅读设置'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.wifi_off,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('离线阅读'),
                  subtitle: const Text('自动下载文章以便离线阅读'),
                  value: false, // TODO: 从设置中读取
                  onChanged: (value) {
                    _showComingSoon(context, '离线阅读');
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.save,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('自动保存历史'),
                  subtitle: const Text('自动记录阅读历史'),
                  value: true, // TODO: 从设置中读取
                  onChanged: (value) {
                    _showComingSoon(context, '阅读历史设置');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 其他设置
          _buildSectionHeader('其他'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('清除缓存'),
                  subtitle: const Text('清理应用缓存数据'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showClearCacheDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('关于速达足球'),
                  subtitle: const Text('版本信息和开发团队'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAboutDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.feedback_outlined,
                    color: AppTheme.primaryGreen,
                  ),
                  title: const Text('意见反馈'),
                  subtitle: const Text('帮助我们改进应用'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showComingSoon(context, '意见反馈'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }

  void _showThemeModeDialog(
      BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            String title;
            IconData icon;
            switch (mode) {
              case ThemeMode.light:
                title = '明亮模式';
                icon = Icons.light_mode;
                break;
              case ThemeMode.dark:
                title = '深色模式';
                icon = Icons.dark_mode;
                break;
              case ThemeMode.system:
                title = '跟随系统';
                icon = Icons.settings_brightness;
                break;
            }

            return RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                  Text(title),
                ],
              ),
              value: mode,
              groupValue: currentMode,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).setThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFontSizeDialog(
      BuildContext context, WidgetRef ref, double currentSize) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('调整字体大小'),
        content: StatefulBuilder(
          builder: (context, setState) {
            double tempSize = currentSize;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 字体大小预览
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '这是预览文字',
                    style: TextStyle(
                      fontSize: 16 * tempSize,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 字体大小滑块
                Row(
                  children: [
                    const Text('小', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: tempSize,
                        min: 0.8,
                        max: 1.5,
                        divisions: 7,
                        activeColor: AppTheme.primaryGreen,
                        onChanged: (value) {
                          setState(() {
                            tempSize = value;
                          });
                        },
                      ),
                    ),
                    const Text('大', style: TextStyle(fontSize: 18)),
                  ],
                ),

                Text(
                  '${(tempSize * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(fontSizeProvider.notifier).resetFontSize();
              Navigator.of(context).pop();
            },
            child: const Text('重置'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text('确定要清除所有缓存数据吗？这将删除已下载的图片和临时文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: 实现清除缓存逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存清除完成')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '速达足球',
      applicationVersion: '1.2.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.sports_soccer,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text('速达足球是一个现代化的足球资讯聚合平台，为您提供最新的足球新闻、比赛信息和社区交流功能。'),
        const SizedBox(height: 16),
        const Text('开发团队致力于为足球爱好者打造最好的阅读体验。'),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature功能开发中，敬请期待...')),
    );
  }
}
