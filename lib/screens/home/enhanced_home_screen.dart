import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/news.dart';
import '../../models/match.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_states.dart';
import '../../utils/theme.dart';

/// 增强版主页
///
/// 特性：
/// - 今日热门新闻
/// - 即将开始的比赛
/// - 个性化推荐
/// - 快速导航
/// - 数据统计面板
class EnhancedHomeScreen extends ConsumerStatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  ConsumerState<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends ConsumerState<EnhancedHomeScreen> {
  final PageController _bannerController = PageController();
  int _currentBannerIndex = 0;

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          _buildQuickStats(context),
          _buildHotNews(context),
          _buildUpcomingMatches(context),
          _buildRecommendations(context),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_soccer,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              '速达足球',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryGreen,
                AppTheme.primaryGreen.withValues(alpha: 0.8),
                AppTheme.techBlue.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/football_bg.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () => context.go('/search'),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => _showNotifications(context),
        ),
      ],
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日概览',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem(
                  icon: Icons.article,
                  label: '新闻',
                  value: '128',
                  color: AppTheme.primaryGreen,
                ),
                _buildStatItem(
                  icon: Icons.sports_soccer,
                  label: '比赛',
                  value: '24',
                  color: AppTheme.techBlue,
                ),
                _buildStatItem(
                  icon: Icons.trending_up,
                  label: '热度',
                  value: '92%',
                  color: AppTheme.accentOrange,
                ),
                _buildStatItem(
                  icon: Icons.visibility,
                  label: '阅读',
                  value: '15.2k',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotNews(BuildContext context) {
    final hotNewsAsync = ref.watch(hotNewsProvider);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🔥 热门新闻',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => context.go('/news'),
                  child: const Text('更多'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: hotNewsAsync.when(
                loading: () => const LoadingWidget(message: '加载热门新闻...'),
                error: (error, stack) => NetworkStateWidget(
                  onRetry: () => ref.refresh(hotNewsProvider),
                ),
                data: (news) => PageView.builder(
                  controller: _bannerController,
                  onPageChanged: (index) {
                    setState(() => _currentBannerIndex = index);
                  },
                  itemCount: news.length,
                  itemBuilder: (context, index) {
                    return _buildNewsCard(context, news[index]);
                  },
                ),
              ),
            ),
            if (hotNewsAsync.hasValue && hotNewsAsync.value!.isNotEmpty)
              _buildPageIndicator(hotNewsAsync.value!.length),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsCard(BuildContext context, News news) {
    return GestureDetector(
      onTap: () => context.go('/news/${news.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 背景图片
              Positioned.fill(
                child: news.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: news.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryGreen,
                                AppTheme.primaryGreen.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.sports_soccer,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryGreen,
                              AppTheme.primaryGreen.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
              ),
              // 渐变遮罩
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // 内容
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(news.category),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        news.categoryDisplayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      news.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          news.source,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.visibility,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatReadCount(news.readCount),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentBannerIndex == index
                  ? AppTheme.primaryGreen
                  : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingMatches(BuildContext context) {
    final upcomingMatchesAsync = ref.watch(upcomingMatchesProvider);

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⚽ 即将开始',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => context.go('/matches'),
                  child: const Text('更多'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            upcomingMatchesAsync.when(
              loading: () => const NewsCardSkeleton(),
              error: (error, stack) => NetworkStateWidget(
                onRetry: () => ref.refresh(upcomingMatchesProvider),
              ),
              data: (matches) {
                if (matches.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.sports_soccer,
                    title: '暂无比赛',
                    message: '今天没有安排比赛',
                  );
                }
                return Column(
                  children: matches
                      .take(3)
                      .map((match) => _buildMatchCard(context, match))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, Match match) {
    return GestureDetector(
      onTap: () => context.go('/match/${match.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    match.homeTeam,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.right,
                  ),
                  if (match.homeScore != null)
                    Text(
                      '${match.homeScore}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              children: [
                Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                _buildMatchStatus(match),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.awayTeam,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (match.awayScore != null)
                    Text(
                      '${match.awayScore}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchStatus(Match match) {
    Color statusColor;
    String statusText;

    switch (match.status) {
      case 'scheduled':
        statusColor = AppTheme.techBlue;
        statusText =
            '${match.matchTime.hour}:${match.matchTime.minute.toString().padLeft(2, '0')}';
        break;
      case 'live':
        statusColor = Colors.red;
        statusText = '${match.minute ?? 0}\'';
        break;
      case 'finished':
        statusColor = Colors.grey;
        statusText = '结束';
        break;
      default:
        statusColor = Colors.grey;
        statusText = '未知';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 为你推荐',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.favorite, 'label': '我的收藏', 'route': '/favorites'},
      {'icon': Icons.history, 'label': '阅读历史', 'route': '/reading-history'},
      {'icon': Icons.translate, 'label': 'AI翻译', 'route': '/translation'},
      {'icon': Icons.settings, 'label': '设置', 'route': '/settings'},
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: actions
          .map((action) => _buildActionButton(
                context,
                action['icon'] as IconData,
                action['label'] as String,
                action['route'] as String,
              ))
          .toList(),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
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
        return Colors.purple;
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

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '通知',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: EmptyStateWidget(
                icon: Icons.notifications_none,
                title: '暂无通知',
                message: '你还没有收到任何通知',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Provider定义
final hotNewsProvider = FutureProvider<List<News>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getNews(limit: 5);
  return response.data.take(3).toList();
});

final upcomingMatchesProvider = FutureProvider<List<Match>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final response = await apiService.getMatches();
  return response.data
      .where((match) => match.status == 'scheduled')
      .take(3)
      .toList();
});
