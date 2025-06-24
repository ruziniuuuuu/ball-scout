import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/news.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../services/reading_history_service.dart';
import '../../widgets/comment_section.dart';
import 'favorites_screen.dart';

// 新闻详情Provider
final newsDetailProvider =
    FutureProvider.family<News, String>((ref, newsId) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getNewsDetail(newsId);
  return response;
});

// 收藏状态Provider
final favoriteProvider = Provider.family<bool, String>((ref, newsId) {
  final favorites = ref.watch(favoritesProvider);
  return favorites.any((news) => news.id == newsId);
});

class NewsDetailWithCommentsScreen extends ConsumerStatefulWidget {
  final String newsId;

  const NewsDetailWithCommentsScreen({
    super.key,
    required this.newsId,
  });

  @override
  ConsumerState<NewsDetailWithCommentsScreen> createState() =>
      _NewsDetailWithCommentsScreenState();
}

class _NewsDetailWithCommentsScreenState
    extends ConsumerState<NewsDetailWithCommentsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _enterTime;
  bool _hasRecordedRead = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _enterTime = DateTime.now();
  }

  @override
  void dispose() {
    // 计算阅读时长并更新进度
    if (_hasRecordedRead) {
      final duration = DateTime.now().difference(_enterTime).inSeconds;
      final progress = (duration / 60).clamp(0.0, 1.0);

      ref.read(readingHistoryProvider.notifier).updateProgress(
            widget.newsId,
            progress,
            duration,
          );
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newsDetailAsync = ref.watch(newsDetailProvider(widget.newsId));
    final isFavorite = ref.watch(favoriteProvider(widget.newsId));

    return Scaffold(
      body: newsDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorView(context, ref),
        data: (news) {
          // 记录阅读历史
          if (!_hasRecordedRead) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _recordReadingHistory(news);
            });
            _hasRecordedRead = true;
          }
          return _buildNewsContent(context, ref, news, isFavorite);
        },
      ),
    );
  }

  void _recordReadingHistory(News news) {
    ref.read(readingHistoryProvider.notifier).addNewsRead(
          news,
          duration: 0,
          progress: 0.1,
        );
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('新闻详情')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.invalidate(newsDetailProvider(widget.newsId)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsContent(
      BuildContext context, WidgetRef ref, News news, bool isFavorite) {
    return Scaffold(
      appBar: AppBar(
        title: Text(news.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareNews(news),
          ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : null,
            ),
            onPressed: () => _toggleFavorite(context, ref, news, isFavorite),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.article),
              text: '新闻',
            ),
            Tab(
              icon: Icon(Icons.comment),
              text: '评论',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 新闻内容Tab
          _buildNewsTab(context, ref, news, isFavorite),
          // 评论Tab
          CommentSection(articleId: widget.newsId),
        ],
      ),
    );
  }

  Widget _buildNewsTab(
      BuildContext context, WidgetRef ref, News news, bool isFavorite) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 新闻标题
          Text(
            news.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 16),

          // 新闻元信息
          _buildNewsMetaInfo(context, news),
          const SizedBox(height: 16),

          // 新闻摘要
          if (news.summary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Text(
                news.summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 新闻图片
          if (news.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                news.imageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image_not_supported, size: 50),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // 新闻正文
          if (news.content != null) ...[
            Text(
              '正文内容',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildNewsText(context, news.content!),
          ],

          const SizedBox(height: 32),

          // 操作按钮
          _buildActionButtons(context, ref, news, isFavorite),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNewsMetaInfo(BuildContext context, News news) {
    return Row(
      children: [
        // 分类标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getCategoryColor(news.category),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            news.categoryDisplayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 来源
        Icon(Icons.article, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          news.source,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
        ),
        const Spacer(),

        // 发布时间
        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          news.timeAgoText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildNewsText(BuildContext context, String content) {
    // 简单的HTML内容解析和显示
    final plainText = content
        .replaceAll(RegExp(r'<[^>]*>'), '') // 移除HTML标签
        .replaceAll('&nbsp;', ' ')
        .trim();

    return Text(
      plainText,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            height: 1.6,
            fontSize: 16,
          ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, WidgetRef ref, News news, bool isFavorite) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareNews(news),
            icon: const Icon(Icons.share),
            label: const Text('分享'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _toggleFavorite(context, ref, news, isFavorite),
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            label: Text(isFavorite ? '已收藏' : '收藏'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFavorite ? Colors.red : AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
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

  void _shareNews(News news) {
    Share.share(
      '${news.title}\n\n${news.summary}\n\n来自球探社',
      subject: news.title,
    );
  }

  void _toggleFavorite(
      BuildContext context, WidgetRef ref, News news, bool isFavorite) {
    if (isFavorite) {
      ref.read(favoritesProvider.notifier).removeFavorite(news.id);
      _showSnackBar(context, '取消收藏');
    } else {
      ref.read(favoritesProvider.notifier).addFavorite(news);
      _showSnackBar(context, '已收藏');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
