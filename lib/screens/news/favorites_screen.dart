import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/news.dart';


// 收藏新闻Provider
final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<News>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<News>> {
  FavoritesNotifier() : super([]) {
    _loadFavorites();
  }

  static const String _favoritesKey = 'favorite_news';

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
    
    final favorites = favoritesJson
        .map((json) => News.fromJson(Map<String, dynamic>.from(
            Uri.decodeFull(json).split('&').asMap().map((key, value) {
              final parts = value.split('=');
              return MapEntry(parts[0], parts[1]);
            }))))
        .toList();
    
    state = favorites;
  }

  Future<void> addFavorite(News news) async {
    if (state.any((item) => item.id == news.id)) return;
    
    final newFavorites = [...state, news];
    state = newFavorites;
    await _saveFavorites();
  }

  Future<void> removeFavorite(String newsId) async {
    final newFavorites = state.where((news) => news.id != newsId).toList();
    state = newFavorites;
    await _saveFavorites();
  }

  Future<void> clearFavorites() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoritesKey);
  }

  bool isFavorite(String newsId) {
    return state.any((news) => news.id == newsId);
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = state.map((news) {
      // 简化的序列化方式
      return Uri.encodeFull(
        'id=${news.id}&title=${news.title}&summary=${news.summary}&source=${news.source}&category=${news.category}&publishedAt=${news.publishedAt}&readCount=${news.readCount}'
      );
    }).toList();
    
    await prefs.setStringList(_favoritesKey, favoritesJson);
  }
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () => _showClearDialog(context, ref),
            ),
        ],
      ),
      body: favorites.isEmpty
          ? _buildEmptyState()
          : _buildFavoritesList(favorites, ref),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 24),
          Text(
            '还没有收藏的新闻',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '快去收藏一些感兴趣的新闻吧！',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(List<News> favorites, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final news = favorites[index];
        return Dismissible(
          key: Key(news.id),
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
            return await _showRemoveDialog(context, news.title);
          },
          onDismissed: (direction) {
            ref.read(favoritesProvider.notifier).removeFavorite(news.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已取消收藏《${news.title}》'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
          child: _buildFavoriteCard(news),
        );
      },
    );
  }

  Widget _buildFavoriteCard(News news) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 分类标签
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
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // 收藏时间（这里简化为发布时间）
                Text(
                  _formatDate(news.publishedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // 新闻标题
            Text(
              news.title,
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
              news.summary,
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
                Icon(
                  Icons.article,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  news.source,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.visibility,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '${news.readCount}',
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}天前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}小时前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}分钟前';
      } else {
        return '刚刚';
      }
    } catch (e) {
      return dateString;
    }
  }

  Future<bool?> _showRemoveDialog(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('确定要取消收藏《$title》吗？'),
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
        title: const Text('清空收藏'),
        content: const Text('确定要清空所有收藏的新闻吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(favoritesProvider.notifier).clearFavorites();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已清空所有收藏'),
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
} 