import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/news.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import 'news_screen.dart';

// 搜索历史Provider
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

// 搜索结果Provider
final searchResultProvider = StateNotifierProvider.family<SearchResultNotifier, AsyncValue<List<News>>, String>((ref, query) {
  return SearchResultNotifier(ref.read(apiServiceProvider));
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  static const String _historyKey = 'search_history';
  static const int _maxHistoryItems = 10;

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    state = history;
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final newHistory = List<String>.from(state);
    newHistory.remove(query); // 移除重复项
    newHistory.insert(0, query); // 添加到开头
    
    // 限制历史记录数量
    if (newHistory.length > _maxHistoryItems) {
      newHistory.removeRange(_maxHistoryItems, newHistory.length);
    }
    
    state = newHistory;
    
    // 保存到本地
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, newHistory);
  }

  Future<void> removeSearch(String query) async {
    final newHistory = List<String>.from(state);
    newHistory.remove(query);
    state = newHistory;
    
    // 保存到本地
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, newHistory);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}

class SearchResultNotifier extends StateNotifier<AsyncValue<List<News>>> {
  final ApiService _apiService;

  SearchResultNotifier(this._apiService) : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    
    try {
      // 这里调用搜索API（暂时使用模拟数据）
      await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
      
      // 模拟搜索结果
      final mockResults = await _getMockSearchResults(query);
      state = AsyncValue.data(mockResults);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<List<News>> _getMockSearchResults(String query) async {
    // 模拟搜索结果（实际应该调用后端搜索API）
    final allNews = [
      News(
        id: 'search_1',
        title: '皇马签下新星前锋：$query 相关报道',
        summary: '皇马官方宣布签下年仅19岁的巴西新星前锋，转会费高达8000万欧元。',
        source: 'ESPN',
        category: 'transfer',
        publishedAt: DateTime.now().toIso8601String(),
        readCount: 1205,
      ),
      News(
        id: 'search_2',
        title: '欧冠八强对阵：关于 $query 的分析',
        summary: '2024年欧冠八强抽签结果公布，精彩对决即将上演。',
        source: 'UEFA',
        category: 'match',
        publishedAt: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        readCount: 2350,
      ),
    ];
    
    return allNews;
  }
}

class NewsSearchScreen extends ConsumerStatefulWidget {
  const NewsSearchScreen({super.key});

  @override
  ConsumerState<NewsSearchScreen> createState() => _NewsSearchScreenState();
}

class _NewsSearchScreenState extends ConsumerState<NewsSearchScreen> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchHistory = ref.watch(searchHistoryProvider);
    final searchResult = _currentQuery.isEmpty 
        ? const AsyncValue.data(<News>[])
        : ref.watch(searchResultProvider(_currentQuery));

    return Scaffold(
      appBar: AppBar(
        title: _buildSearchBar(),
        titleSpacing: 0,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 搜索建议和历史
          if (_currentQuery.isEmpty) ...[
            Expanded(child: _buildSearchHistory(searchHistory)),
          ] else ...[
            // 搜索结果
            Expanded(child: _buildSearchResults(searchResult)),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: const InputDecoration(
          hintText: '搜索新闻...',
          prefixIcon: Icon(Icons.search, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          setState(() {
            _currentQuery = value.trim();
          });
          
          if (_currentQuery.isNotEmpty) {
            // 延迟搜索，避免频繁调用
            Future.delayed(const Duration(milliseconds: 300), () {
              if (_currentQuery == value.trim()) {
                ref.read(searchResultProvider(_currentQuery).notifier).search(_currentQuery);
              }
            });
          }
        },
        onSubmitted: (value) {
          _performSearch(value);
        },
      ),
    );
  }

  Widget _buildSearchHistory(List<String> history) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '搜索足球新闻',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '输入关键词搜索相关新闻',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  _showClearHistoryDialog();
                },
                child: const Text('清空'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(query),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    ref.read(searchHistoryProvider.notifier).removeSearch(query);
                  },
                ),
                onTap: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(AsyncValue<List<News>> searchResult) {
    return searchResult.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
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
            const Text('搜索失败'),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(searchResultProvider(_currentQuery).notifier).search(_currentQuery);
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
      data: (news) {
        if (news.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '没有找到相关新闻',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '试试其他关键词',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '搜索结果 (${news.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: news.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final newsItem = news[index];
                  return NewsCard(news: newsItem);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) return;
    
    setState(() {
      _currentQuery = query.trim();
    });
    
    // 添加到搜索历史
    ref.read(searchHistoryProvider.notifier).addSearch(query.trim());
    
    // 执行搜索
    ref.read(searchResultProvider(_currentQuery).notifier).search(_currentQuery);
    
    // 隐藏键盘
    _searchFocusNode.unfocus();
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空搜索历史'),
        content: const Text('确定要清空所有搜索历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(searchHistoryProvider.notifier).clearHistory();
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
} 