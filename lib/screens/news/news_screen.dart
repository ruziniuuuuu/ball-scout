import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/news.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../widgets/loading_states.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/animated_card.dart';

// 选中的新闻分类Provider
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

// 新闻列表Provider
final newsListProvider = FutureProvider<List<News>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final selectedCategory = ref.watch(selectedCategoryProvider);
  final response = await apiService.getNews(category: selectedCategory);
  return response.data;
});

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsListAsync = ref.watch(newsListProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('足球新闻'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.go('/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(newsListProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 分类筛选栏
          _buildCategoryFilter(ref, selectedCategory),
          
          // 新闻列表
          Expanded(
            child: CustomRefreshIndicator(
        onRefresh: () async {
          ref.invalidate(newsListProvider);
        },
        child: newsListAsync.when(
          loading: () => ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const NewsCardSkeleton(),
          ),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  '加载失败',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(newsListProvider);
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (newsList) {
            if (newsList.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.article_outlined,
                title: '暂无新闻',
                message: '稍后再试，或下拉刷新',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: newsList.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final news = newsList[index];
                return SlideInWidget(
                  delay: Duration(milliseconds: index * 50),
                  child: NewsCard(news: news),
                );
              },
            );
          },
        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(WidgetRef ref, String? selectedCategory) {
    const categories = [
      {'key': null, 'name': '全部', 'color': Color(0xFF2196F3)},
      {'key': 'news', 'name': '新闻', 'color': Color(0xFF00C851)},
      {'key': 'transfer', 'name': '转会', 'color': Color(0xFFFF6B35)},
      {'key': 'match', 'name': '比赛', 'color': Color(0xFF007BFF)},
      {'key': 'analysis', 'name': '分析', 'color': Color(0xFFAA66CC)},
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = selectedCategory == category['key'];
          
          return FilterChip(
            label: Text(
              category['name'] as String,
              style: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            selected: isSelected,
            onSelected: (selected) {
              ref.read(selectedCategoryProvider.notifier).state = 
                  selected ? category['key'] as String? : null;
            },
            backgroundColor: Colors.grey[100],
            selectedColor: category['color'] as Color,
            checkmarkColor: Colors.white,
          );
        },
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  final News news;

  const NewsCard({
    super.key,
    required this.news,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCard(
      onTap: () => context.go('/news/${news.id}'),
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            if (news.imageUrl != null && news.imageUrl!.isNotEmpty) ...[
              Hero(
                tag: 'news-image-${news.id}',
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: news.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey.shade300),
                    errorWidget: (context, url, error) => Container(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    news.summary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(news.category),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          news.categoryDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        news.source,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        news.timeAgoText,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatReadCount(news.readCount),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'transfer':
        return AppTheme.accentOrange;
      case 'match':
        return AppTheme.techBlue;
      case 'news':
        return AppTheme.primaryGreen;
      case 'analysis':
        return const Color(0xFFAA66CC);
      default:
        return AppTheme.mediumGray;
    }
  }

  String _formatReadCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
} 