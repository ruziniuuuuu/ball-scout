import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/match.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

// 选中的日期Provider
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// 赛程列表Provider
final matchesProvider = FutureProvider<List<Match>>((ref) async {
  final apiService = ref.read(apiServiceProvider);
  final selectedDate = ref.watch(selectedDateProvider);
  final response = await apiService.getMatches(date: selectedDate);
  return response.data;
});

class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchesProvider);
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('赛事'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(matchesProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 日期选择器
          _buildDateSelector(context, ref, selectedDate),
          
          // 比赛列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(matchesProvider);
              },
              child: matchesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => _buildErrorView(context, ref, error),
                data: (matches) => _buildMatchesList(context, matches),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, WidgetRef ref, DateTime selectedDate) {
    final now = DateTime.now();
    
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 7, // 显示7天
        itemBuilder: (context, index) {
          final date = now.add(Duration(days: index - 3)); // 前3天到后3天
          final isSelected = _isSameDay(date, selectedDate);
          final isToday = _isSameDay(date, now);
          
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                ref.read(selectedDateProvider.notifier).state = date;
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 70,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppTheme.primaryGreen 
                      : isToday 
                          ? AppTheme.primaryGreen.withOpacity(0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected 
                        ? AppTheme.primaryGreen 
                        : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isToday ? '今天' : _getWeekdayName(date.weekday),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected 
                            ? Colors.white 
                            : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.month}/${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        color: isSelected 
                            ? Colors.white 
                            : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchesList(BuildContext context, List<Match> matches) {
    if (matches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 24),
            Text(
              '当天暂无比赛',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '选择其他日期查看比赛',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // 按赛事分组
    final groupedMatches = _groupMatchesByCompetition(matches);
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedMatches.length,
      itemBuilder: (context, index) {
        final group = groupedMatches[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 赛事标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    group['competition'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 该赛事的比赛
            ...(group['matches'] as List<Match>).map((match) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MatchCard(match: match),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildErrorView(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(matchesProvider);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupMatchesByCompetition(List<Match> matches) {
    final Map<String, List<Match>> grouped = {};
    
    for (final match in matches) {
      grouped[match.competition] ??= [];
      grouped[match.competition]!.add(match);
    }
    
    return grouped.entries.map((entry) => {
      'competition': entry.key,
      'matches': entry.value,
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays[weekday - 1];
  }
}

class MatchCard extends StatelessWidget {
  final Match match;

  const MatchCard({
    super.key,
    required this.match,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: 跳转到比赛详情页
          context.go('/match/${match.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 比赛时间和状态
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    match.statusDisplayText,
                    style: TextStyle(
                      fontSize: 12,
                      color: match.isLive 
                          ? Colors.red 
                          : Colors.grey[600],
                      fontWeight: match.isLive 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (match.isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 主要内容：球队 vs 球队
              Row(
                children: [
                  // 主队
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(match.homeTeamLogo),
                        const SizedBox(height: 8),
                        Text(
                          match.homeTeam,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // 比分/VS
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          match.scoreDisplay,
                          style: TextStyle(
                            fontSize: match.scoreDisplay == 'VS' ? 16 : 24,
                            fontWeight: FontWeight.bold,
                            color: match.isLive 
                                ? Colors.red 
                                : AppTheme.primaryGreen,
                          ),
                        ),
                        if (match.venue.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            match.venue,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // 客队
                  Expanded(
                    child: Column(
                      children: [
                        _buildTeamLogo(match.awayTeamLogo),
                        const SizedBox(height: 8),
                        Text(
                          match.awayTeam,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // 比赛事件（进球、黄牌等）
              if (match.events.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildMatchEvents(match.events),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamLogo(String logoUrl) {
    if (logoUrl.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.sports_soccer,
          color: Colors.grey,
          size: 24,
        ),
      );
    }
    
    return CircleAvatar(
      radius: 24,
      backgroundImage: NetworkImage(logoUrl),
      backgroundColor: Colors.grey[200],
      onBackgroundImageError: (error, stackTrace) {
        // 处理图片加载错误
      },
      child: const Icon(
        Icons.sports_soccer,
        color: Colors.grey,
        size: 24,
      ),
    );
  }

  Widget _buildMatchEvents(List<MatchEvent> events) {
    // 只显示前3个重要事件
    final displayEvents = events.take(3).toList();
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: displayEvents.map((event) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(
                  event.eventIcon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  "${event.minute}' ${event.eventDescription}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
} 