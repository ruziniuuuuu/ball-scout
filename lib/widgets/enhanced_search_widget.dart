import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/news.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'loading_states.dart' as loading_states;

/// 增强版搜索组件
/// 
/// 特性：
/// - 实时搜索建议
/// - 搜索历史记录
/// - 热门搜索词
/// - 高级筛选选项
/// - 搜索结果高亮
class EnhancedSearchWidget extends ConsumerStatefulWidget {
  const EnhancedSearchWidget({super.key});

  @override
  ConsumerState<EnhancedSearchWidget> createState() => _EnhancedSearchWidgetState();
}

class _EnhancedSearchWidgetState extends ConsumerState<EnhancedSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  String _currentQuery = '';
  bool _showSuggestions = false;
  String _selectedCategory = 'all';
  String _selectedSource = 'all';
  DateTimeRange? _selectedDateRange;

  // 搜索历史记录
  final List<String> _searchHistory = [
    '皇马',
    '欧冠',
    '转会',
    'C罗',
    '巴萨',
  ];

  // 热门搜索词
  final List<String> _hotSearches = [
    '世界杯',
    '英超',
    '梅西',
    '转会窗口',
    '欧冠决赛',
    '中超',
    '亚洲杯',
    '女足世界杯',
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus;
      });
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
    return Scaffold(
      body: Column(
        children: [
          _buildSearchHeader(context),
          if (_showSuggestions && _currentQuery.isEmpty)
            _buildSearchSuggestions(context)
          else if (_showSuggestions && _currentQuery.isNotEmpty)
            _buildRealTimeSuggestions(context)
          else
            _buildSearchResults(context),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      setState(() {
                        _currentQuery = value;
                      });
                      _performSearch(value);
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _addToHistory(value);
                        _performSearch(value);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '搜索新闻、球队、球员...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _currentQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _currentQuery = '';
                                });
                              },
                              icon: const Icon(Icons.clear, color: Colors.grey),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _showFilterDialog(context),
                icon: const Icon(Icons.tune, color: Colors.white),
              ),
            ],
          ),
          if (_hasActiveFilters())
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: _buildActiveFilters(context),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_searchHistory.isNotEmpty) ...[
            _buildSectionTitle('搜索历史', Icons.history),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchHistory.map((query) => _buildSearchChip(
                query,
                onTap: () => _selectSearchQuery(query),
                onDelete: () => _removeFromHistory(query),
              )).toList(),
            ),
            const SizedBox(height: 24),
          ],
          _buildSectionTitle('热门搜索', Icons.whatshot),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hotSearches.map((query) => _buildSearchChip(
              query,
              onTap: () => _selectSearchQuery(query),
              isHot: true,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeSuggestions(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.white,
      child: ListView.builder(
        itemCount: _getSearchSuggestions().length,
        itemBuilder: (context, index) {
          final suggestion = _getSearchSuggestions()[index];
          return ListTile(
            leading: const Icon(Icons.search, color: Colors.grey),
            title: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: _highlightSearchText(suggestion, _currentQuery),
              ),
            ),
            onTap: () => _selectSearchQuery(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_currentQuery.isEmpty) {
      return const Expanded(
        child: loading_states.EmptyStateWidget(
          icon: Icons.search,
          title: '开始搜索',
          message: '输入关键词搜索新闻内容',
        ),
      );
    }

    final searchResultsAsync = ref.watch(searchResultsProvider(_currentQuery));

    return Expanded(
      child: searchResultsAsync.when(
        loading: () => const loading_states.LoadingWidget(message: '搜索中...'),
        error: (error, stack) => loading_states.ErrorWidget(
          message: '搜索失败，请重试',
          onRetry: () => ref.refresh(searchResultsProvider(_currentQuery)),
        ),
        data: (results) {
          if (results.isEmpty) {
            return loading_states.EmptyStateWidget(
              icon: Icons.search_off,
              title: '没有找到结果',
              message: '尝试使用其他关键词搜索',
              actionLabel: '清空搜索',
              onAction: () {
                _searchController.clear();
                setState(() {
                  _currentQuery = '';
                });
              },
            );
          }

          return Column(
            children: [
              _buildResultStats(context, results.length),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    return _buildSearchResultItem(context, results[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchChip(
    String text, {
    required VoidCallback onTap,
    VoidCallback? onDelete,
    bool isHot = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isHot 
              ? AppTheme.accentOrange.withValues(alpha: 0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHot 
                ? AppTheme.accentOrange.withValues(alpha: 0.3)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isHot) ...[
              Icon(
                Icons.local_fire_department,
                size: 14,
                color: AppTheme.accentOrange,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isHot ? AppTheme.accentOrange : Colors.grey.shade700,
                fontWeight: isHot ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilters(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        if (_selectedCategory != 'all')
          _buildFilterChip('分类: ${_getCategoryName(_selectedCategory)}'),
        if (_selectedSource != 'all')
          _buildFilterChip('来源: $_selectedSource'),
        if (_selectedDateRange != null)
          _buildFilterChip('时间: ${_formatDateRange(_selectedDateRange!)}'),
      ],
    );
  }

  Widget _buildFilterChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildResultStats(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            '找到 $count 条关于 "$_currentQuery" 的结果',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(BuildContext context, News news) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: news.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  news.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                ),
              )
            : _buildPlaceholderImage(),
      ),
      title: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          children: _highlightSearchText(news.title, _currentQuery),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
              children: _highlightSearchText(news.summary, _currentQuery),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getCategoryColor(news.category),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  news.categoryDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                news.source,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
              const Spacer(),
              Text(
                news.timeAgoText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        // 导航到新闻详情页
        Navigator.of(context).pushNamed('/news/${news.id}');
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGreen.withValues(alpha: 0.3),
            AppTheme.primaryGreen.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Icon(
        Icons.sports_soccer,
        color: AppTheme.primaryGreen,
        size: 24,
      ),
    );
  }

  List<String> _getSearchSuggestions() {
    if (_currentQuery.isEmpty) return [];
    
    // 实际项目中这里应该调用API获取搜索建议
    final allSuggestions = [..._hotSearches, ..._searchHistory];
    return allSuggestions
        .where((s) => s.toLowerCase().contains(_currentQuery.toLowerCase()))
        .take(5)
        .toList();
  }

  List<TextSpan> _highlightSearchText(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final List<TextSpan> spans = [];
    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    
    int start = 0;
    int index = lowercaseText.indexOf(lowercaseQuery, start);
    
    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: TextStyle(
          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + query.length;
      index = lowercaseText.indexOf(lowercaseQuery, start);
    }
    
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    
    return spans;
  }

  void _selectSearchQuery(String query) {
    _searchController.text = query;
    setState(() {
      _currentQuery = query;
      _showSuggestions = false;
    });
    _searchFocusNode.unfocus();
    _addToHistory(query);
    _performSearch(query);
  }

  void _performSearch(String query) {
    if (query.isNotEmpty) {
      ref.refresh(searchResultsProvider(query));
    }
  }

  void _addToHistory(String query) {
    if (query.isNotEmpty && !_searchHistory.contains(query)) {
      setState(() {
        _searchHistory.insert(0, query);
        if (_searchHistory.length > 10) {
          _searchHistory.removeLast();
        }
      });
      // 实际项目中这里应该持久化搜索历史
    }
  }

  void _removeFromHistory(String query) {
    setState(() {
      _searchHistory.remove(query);
    });
  }

  bool _hasActiveFilters() {
    return _selectedCategory != 'all' ||
           _selectedSource != 'all' ||
           _selectedDateRange != null;
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'news': return '新闻';
      case 'transfer': return '转会';
      case 'match': return '比赛';
      case 'analysis': return '分析';
      default: return '全部';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'transfer': return AppTheme.accentOrange;
      case 'match': return AppTheme.techBlue;
      case 'news': return AppTheme.primaryGreen;
      case 'analysis': return Colors.purple;
      default: return AppTheme.mediumGray;
    }
  }

  String _formatDateRange(DateTimeRange range) {
    final start = '${range.start.month}/${range.start.day}';
    final end = '${range.end.month}/${range.end.day}';
    return '$start-$end';
  }

  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '筛选条件',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 这里可以添加具体的筛选选项
            const Text('筛选功能开发中...'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 搜索结果Provider
final searchResultsProvider = FutureProvider.family<List<News>, String>((ref, query) async {
  if (query.isEmpty) return [];
  
  final apiService = ref.read(apiServiceProvider);
  // 这里应该调用实际的搜索API
  await Future.delayed(const Duration(seconds: 1)); // 模拟网络延迟
  
  // 返回模拟的搜索结果
  final allNews = await apiService.getNews();
  return allNews.data
      .where((news) => 
        news.title.toLowerCase().contains(query.toLowerCase()) ||
        news.summary.toLowerCase().contains(query.toLowerCase())
      )
      .toList();
});