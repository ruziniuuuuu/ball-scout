import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/match.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

// 比赛详情Provider
final matchDetailProvider = FutureProvider.family<Match, String>((ref, matchId) async {
  final apiService = ref.read(apiServiceProvider);
  return await apiService.getMatchDetail(matchId);
});

class MatchDetailScreen extends ConsumerStatefulWidget {
  final String matchId;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
  });

  @override
  ConsumerState<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends ConsumerState<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchAsync = ref.watch(matchDetailProvider(widget.matchId));

    return Scaffold(
      body: matchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorView(error),
        data: (match) => _buildMatchDetail(context, match),
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('比赛详情'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('加载失败', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(error.toString(), style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(matchDetailProvider(widget.matchId)),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchDetail(BuildContext context, Match match) {
    return CustomScrollView(
      slivers: [
        // 自定义AppBar
        SliverAppBar(
          expandedHeight: 280.0,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildMatchHeader(match),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareMatch(match),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(matchDetailProvider(widget.matchId)),
            ),
          ],
        ),

        // Tab导航
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '概览'),
                Tab(text: '事件'),
                Tab(text: '统计'),
              ],
              labelColor: AppTheme.primaryGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryGreen,
            ),
          ),
        ),

        // Tab内容
        SliverFillRemaining(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(match),
              _buildEventsTab(match),
              _buildStatsTab(match),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchHeader(Match match) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryGreen,
            AppTheme.primaryGreen.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 比赛状态
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(match.status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  match.statusDisplayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 球队对阵
              Row(
                children: [
                  // 主队
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(match.homeTeamLogo, 60),
                        const SizedBox(height: 12),
                        Text(
                          match.homeTeam,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // 比分
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          match.scoreDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          match.competition,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 客队
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(match.awayTeamLogo, 60),
                        const SizedBox(height: 12),
                        Text(
                          match.awayTeam,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 比赛时间和场地
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatMatchTime(match.matchTime),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  if (match.venue.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      match.venue,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Match match) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 比赛信息卡片
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '比赛信息',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('比赛状态', match.statusDisplayText),
                  _buildInfoRow('比赛时间', _formatMatchTime(match.matchTime)),
                  if (match.venue.isNotEmpty)
                    _buildInfoRow('比赛场地', match.venue),
                  _buildInfoRow('赛事', match.competition),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 近期比赛事件
          if (match.events.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '关键事件',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...match.events.take(5).map((event) => _buildEventItem(event)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEventsTab(Match match) {
    final events = match.events;
    
    if (events.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无比赛事件', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildDetailedEventItem(event);
      },
    );
  }

  Widget _buildStatsTab(Match match) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 比分统计
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '比分统计',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('进球数', '${match.homeScore ?? 0}', '${match.awayScore ?? 0}'),
                  _buildStatRow('角球', '7', '3'),
                  _buildStatRow('黄牌', '2', '1'),
                  _buildStatRow('红牌', '0', '0'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 数据统计
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '技术统计',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('控球率', '62%', '38%'),
                  _buildStatRow('射门次数', '12', '8'),
                  _buildStatRow('射正次数', '6', '3'),
                  _buildStatRow('传球成功率', '85%', '78%'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(String logoUrl, double size) {
    if (logoUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.sports_soccer,
          color: Colors.white,
          size: size * 0.5,
        ),
      );
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundImage: NetworkImage(logoUrl),
      backgroundColor: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(MatchEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                event.eventIcon,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.eventDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "${event.minute}'",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedEventItem(MatchEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getEventColor(event.type),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              event.eventIcon,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        title: Text(event.eventDescription),
        subtitle: Text('${event.minute}分钟 · ${event.team == 'home' ? '主队' : '客队'}'),
        trailing: Text(
          "${event.minute}'",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String homeValue, String awayValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              homeValue,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              awayValue,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'live':
        return Colors.red;
      case 'finished':
        return Colors.green;
      case 'scheduled':
        return Colors.blue;
      case 'postponed':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'goal':
        return Colors.green.withOpacity(0.1);
      case 'yellow_card':
        return Colors.yellow.withOpacity(0.1);
      case 'red_card':
        return Colors.red.withOpacity(0.1);
      case 'substitution':
        return Colors.blue.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  String _formatMatchTime(DateTime matchTime) {
    return '${matchTime.year}年${matchTime.month}月${matchTime.day}日 '
        '${matchTime.hour.toString().padLeft(2, '0')}:'
        '${matchTime.minute.toString().padLeft(2, '0')}';
  }

  void _shareMatch(Match match) {
    Share.share(
      '${match.homeTeam} vs ${match.awayTeam}\n'
      '${match.scoreDisplay}\n'
      '${match.competition} · ${_formatMatchTime(match.matchTime)}\n\n'
      '来自球探社',
      subject: '${match.homeTeam} vs ${match.awayTeam}',
    );
  }
}

// TabBar委托类
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}