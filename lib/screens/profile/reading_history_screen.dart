import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/reading_history.dart';
import '../../services/reading_history_service.dart';
import '../../utils/theme.dart';

// 阅读统计Provider
final readingStatsProvider = FutureProvider<ReadingStats>((ref) async {
  final service = ref.read(readingHistoryServiceProvider);
  return await service.getReadingStats();
});

class ReadingHistoryScreen extends ConsumerWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyList = ref.watch(readingHistoryProvider);
    final statsAsync = ref.watch(readingStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('阅读历史'),
        actions: [
          if (historyList.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'clear':
                    _showClearDialog(context, ref);
                    break;
                  case 'stats':
                    _showStatsDialog(context, statsAsync);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'stats',
                  child: Row(
                    children: [
                      Icon(Icons.analytics_outlined),
                      SizedBox(width: 8),
                      Text('阅读统计'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.red),
                      SizedBox(width: 8),
                      Text('清空历史', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // 统计卡片
          _buildStatsCard(statsAsync),
          
          // 历史列表
          Expanded(
            child: historyList.isEmpty
                ? _buildEmptyState(context)
                : _buildHistoryList(context, ref, historyList),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(AsyncValue<ReadingStats> statsAsync) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: statsAsync.when(
            loading: () => const Center(
              child: SizedBox(
                height: 40,
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => const Text('统计加载失败'),
            data: (stats) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.analytics,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '阅读统计',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('今日阅读', '${stats.todayCount}篇'),
                    ),
                    Expanded(
                      child: _buildStatItem('本周阅读', '${stats.weekCount}篇'),
                    ),
                    Expanded(
                      child: _buildStatItem('总计', '${stats.totalCount}篇'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem('阅读时长', stats.totalDurationDescription),
                    ),
                    Expanded(
                      child: _buildStatItem('最爱分类', stats.mostReadCategoryDisplayName),
                    ),
                    const Expanded(child: SizedBox()), // 占位
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 24),
          Text(
            '还没有阅读记录',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '快去阅读一些新闻吧！',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, WidgetRef ref, List<ReadingHistory> histories) {
    // 按日期分组
    final groupedHistories = _groupHistoriesByDate(histories);
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedHistories.length,
      itemBuilder: (context, index) {
        final group = groupedHistories[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                group['date'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            // 该日期的历史记录
            ...(group['histories'] as List<ReadingHistory>).map((history) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildHistoryCard(context, ref, history),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildHistoryCard(BuildContext context, WidgetRef ref, ReadingHistory history) {
    return Dismissible(
      key: Key(history.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showRemoveDialog(context, history.news.title);
      },
      onDismissed: (direction) {
        ref.read(readingHistoryProvider.notifier).removeHistory(history.news.id);
        // 刷新统计数据
        ref.invalidate(readingStatsProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除《${history.news.title}》的阅读记录'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // 跳转到新闻详情页
            context.go('/news/${history.news.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 新闻标题
                Text(
                  history.news.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // 新闻摘要
                Text(
                  history.news.summary,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                
                // 底部信息
                Row(
                  children: [
                    // 分类标签
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(history.news.category),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        history.news.categoryDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // 阅读进度
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        history.progressDescription,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    
                    // 阅读时间
                    Text(
                      _formatTime(history.readAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupHistoriesByDate(List<ReadingHistory> histories) {
    final Map<String, List<ReadingHistory>> grouped = {};
    
    for (final history in histories) {
      final dateKey = _formatDateGroup(history.readAt);
      grouped[dateKey] ??= [];
      grouped[dateKey]!.add(history);
    }
    
    return grouped.entries.map((entry) => {
      'date': entry.key,
      'histories': entry.value,
    }).toList();
  }

  String _formatDateGroup(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);
    
    if (targetDate == today) {
      return '今天';
    } else if (targetDate == yesterday) {
      return '昨天';
    } else if (now.year == date.year) {
      return '${date.month}月${date.day}日';
    } else {
      return '${date.year}年${date.month}月${date.day}日';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'transfer':
        return const Color(0xFFFF6B35);
      case 'match':
        return const Color(0xFF007BFF);
      case 'news':
        return const Color(0xFF00C851);
      case 'analysis':
        return const Color(0xFFAA66CC);
      default:
        return const Color(0xFF7F8C8D);
    }
  }

  Future<bool?> _showRemoveDialog(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定要删除《$title》的阅读记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有阅读历史吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(readingHistoryProvider.notifier).clearHistory();
              ref.invalidate(readingStatsProvider);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清空所有阅读历史'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(BuildContext context, AsyncValue<ReadingStats> statsAsync) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text('详细统计'),
          ],
        ),
        content: statsAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => const Text('统计加载失败'),
          data: (stats) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailStatRow('总阅读文章', '${stats.totalCount} 篇'),
              _buildDetailStatRow('今日阅读', '${stats.todayCount} 篇'),
              _buildDetailStatRow('本周阅读', '${stats.weekCount} 篇'),
              _buildDetailStatRow('累计时长', stats.totalDurationDescription),
              _buildDetailStatRow('最爱分类', stats.mostReadCategoryDisplayName),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
} 