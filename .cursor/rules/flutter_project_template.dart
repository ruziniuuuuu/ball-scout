// Flutter项目模板 - 球探社App

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. 主应用入口
class BallScoutApp extends ConsumerWidget {
  const BallScoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '球探社',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRouter.config,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

// 2. 状态管理示例 - 新闻列表
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return NewsRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    cacheManager: ref.watch(cacheManagerProvider),
  );
});

final newsListProvider = FutureProvider.autoDispose
    .family<List<NewsArticle>, NewsFilter>((ref, filter) async {
  final repository = ref.watch(newsRepositoryProvider);
  return repository.getNews(filter);
});

// 3. UI组件示例 - 新闻卡片
class NewsCard extends ConsumerWidget {
  final NewsArticle article;
  
  const NewsCard({super.key, required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => context.push('/news/${article.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                article.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // 元信息
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(article.publishedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  SourceBadge(source: article.source),
                ],
              ),
              
              // 内容预览
              if (article.summary.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  article.summary,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }
}

// 4. 数据模型示例
@freezed
class NewsArticle with _$NewsArticle {
  const factory NewsArticle({
    required String id,
    required String title,
    required String content,
    required String summary,
    required String source,
    required DateTime publishedAt,
    required NewsCategory category,
    @Default([]) List<String> tags,
    @Default(0) int likes,
    @Default(0) int comments,
  }) = _NewsArticle;

  factory NewsArticle.fromJson(Map<String, dynamic> json) =>
      _$NewsArticleFromJson(json);
}

enum NewsCategory {
  transfer,    // 转会
  match,       // 比赛
  injury,      // 伤病
  rumor,       // 传言
  interview,   // 采访
  analysis,    // 分析
}

// 5. Repository模式示例
abstract class NewsRepository {
  Future<List<NewsArticle>> getNews(NewsFilter filter);
  Future<NewsArticle> getNewsById(String id);
  Future<void> likeNews(String id);
}

class NewsRepositoryImpl implements NewsRepository {
  final ApiClient _apiClient;
  final CacheManager _cacheManager;

  NewsRepositoryImpl({
    required ApiClient apiClient,
    required CacheManager cacheManager,
  }) : _apiClient = apiClient, _cacheManager = cacheManager;

  @override
  Future<List<NewsArticle>> getNews(NewsFilter filter) async {
    // 首先检查缓存
    final cacheKey = 'news_${filter.hashCode}';
    final cached = await _cacheManager.get(cacheKey);
    
    if (cached != null && !_isCacheExpired(cached)) {
      return (cached['data'] as List)
          .map((json) => NewsArticle.fromJson(json))
          .toList();
    }

    // 从API获取数据
    final response = await _apiClient.get('/api/v1/news', queryParameters: {
      'category': filter.category?.name,
      'page': filter.page,
      'limit': filter.limit,
    });

    final articles = (response.data['articles'] as List)
        .map((json) => NewsArticle.fromJson(json))
        .toList();

    // 缓存结果
    await _cacheManager.set(cacheKey, {
      'data': articles.map((a) => a.toJson()).toList(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    return articles;
  }

  bool _isCacheExpired(Map<String, dynamic> cached) {
    final timestamp = cached['timestamp'] as int;
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime).inMinutes > 5; // 5分钟过期
  }
} 