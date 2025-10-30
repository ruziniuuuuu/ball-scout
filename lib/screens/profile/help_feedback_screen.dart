import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/theme.dart';

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帮助与反馈'),
      ),
      body: ListView(
        children: [
          // 常见问题
          _buildSection(
            context,
            title: '常见问题',
            children: [
              _buildFAQItem(
                context,
                question: '如何收藏新闻？',
                answer: '在新闻详情页面，点击右上角的收藏按钮即可收藏新闻。',
              ),
              _buildFAQItem(
                context,
                question: '如何查看阅读历史？',
                answer: '在个人中心页面，点击"阅读历史"即可查看您阅读过的所有新闻。',
              ),
              _buildFAQItem(
                context,
                question: '如何关注球队？',
                answer: '在个人中心页面，点击"关注球队"，然后选择您想关注的球队即可。',
              ),
              _buildFAQItem(
                context,
                question: '如何关闭推送通知？',
                answer: '在个人中心页面，点击"消息通知"，可以关闭各种类型的推送通知。',
              ),
            ],
          ),

          // 使用指南
          _buildSection(
            context,
            title: '使用指南',
            children: [
              _buildGuideItem(
                context,
                icon: Icons.article_outlined,
                title: '浏览新闻',
                description: '在新闻页面可以浏览最新的足球新闻，支持分类筛选和搜索功能。',
              ),
              _buildGuideItem(
                context,
                icon: Icons.sports_soccer,
                title: '查看赛程',
                description: '在赛事页面可以查看当天的比赛安排，支持查看不同日期的比赛。',
              ),
              _buildGuideItem(
                context,
                icon: Icons.comment_outlined,
                title: '参与讨论',
                description: '在新闻详情页面可以查看和发表评论，与其他球迷互动交流。',
              ),
            ],
          ),

          // 反馈渠道
          _buildSection(
            context,
            title: '反馈渠道',
            children: [
              _buildActionItem(
                context,
                icon: Icons.email_outlined,
                title: '发送邮件',
                subtitle: 'feedback@ballscout.com',
                onTap: () async {
                  final Uri emailUri = Uri(
                    scheme: 'mailto',
                    path: 'feedback@ballscout.com',
                    query: 'subject=用户反馈',
                  );
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('无法打开邮件应用')),
                    );
                  }
                },
              ),
              _buildActionItem(
                context,
                icon: Icons.bug_report_outlined,
                title: '问题反馈',
                subtitle: '报告Bug或提出建议',
                onTap: () => _showFeedbackDialog(context),
              ),
              _buildActionItem(
                context,
                icon: Icons.star_outline,
                title: '评价应用',
                subtitle: '在应用商店给我们评分',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('即将跳转到应用商店')),
                  );
                },
              ),
            ],
          ),

          // 关于
          _buildSection(
            context,
            title: '关于',
            children: [
              _buildInfoItem(
                context,
                label: '版本号',
                value: '1.0.0',
              ),
              _buildInfoItem(
                context,
                label: '更新时间',
                value: '2024-01-01',
              ),
              _buildInfoItem(
                context,
                label: '版权信息',
                value: '© 2024 球探社',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: children.map((child) {
              final index = children.indexOf(child);
              return Column(
                children: [
                  if (index > 0) const Divider(height: 1),
                  child,
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQItem(
    BuildContext context, {
    required String question,
    required String answer,
  }) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryGreen),
      title: Text(title),
      subtitle: Text(description),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryGreen),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(
          color: Colors.grey[600],
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('问题反馈'),
        content: TextField(
          controller: feedbackController,
          decoration: const InputDecoration(
            hintText: '请描述您遇到的问题或建议...',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (feedbackController.text.trim().isNotEmpty) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('感谢您的反馈！我们会认真处理。'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                // 这里可以发送反馈到服务器
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('提交'),
          ),
        ],
      ),
    );
  }
}

