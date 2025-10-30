import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../utils/theme.dart';

// 关注球队Provider
final followedTeamsProvider = StateNotifierProvider<FollowedTeamsNotifier, List<Team>>((ref) {
  return FollowedTeamsNotifier();
});

class Team {
  final String id;
  final String name;
  final String logo;
  final String league;

  const Team({
    required this.id,
    required this.name,
    required this.logo,
    required this.league,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logo': logo,
    'league': league,
  };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
    id: json['id'] as String,
    name: json['name'] as String,
    logo: json['logo'] as String,
    league: json['league'] as String,
  );
}

class FollowedTeamsNotifier extends StateNotifier<List<Team>> {
  static const String _teamsKey = 'followed_teams';

  FollowedTeamsNotifier() : super([]) {
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final teamsJson = prefs.getStringList(_teamsKey) ?? [];
    
    state = teamsJson
        .map((json) => Team.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> addTeam(Team team) async {
    if (state.any((t) => t.id == team.id)) return;
    
    final newTeams = [...state, team];
    state = newTeams;
    await _saveTeams();
  }

  Future<void> removeTeam(String teamId) async {
    final newTeams = state.where((team) => team.id != teamId).toList();
    state = newTeams;
    await _saveTeams();
  }

  Future<void> _saveTeams() async {
    final prefs = await SharedPreferences.getInstance();
    final teamsJson = state.map((team) => jsonEncode(team.toJson())).toList();
    await prefs.setStringList(_teamsKey, teamsJson);
  }

  bool isFollowing(String teamId) {
    return state.any((team) => team.id == teamId);
  }
}

class FollowedTeamsScreen extends ConsumerWidget {
  const FollowedTeamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(followedTeamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('关注球队'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTeamDialog(context, ref),
          ),
        ],
      ),
      body: teams.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildTeamsList(context, ref, teams),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_soccer_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            '还没有关注的球队',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '关注您喜欢的球队，获取专属推送',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddTeamDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加关注'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsList(BuildContext context, WidgetRef ref, List<Team> teams) {
    // 按联赛分组
    final groupedTeams = <String, List<Team>>{};
    for (final team in teams) {
      groupedTeams[team.league] ??= [];
      groupedTeams[team.league]!.add(team);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedTeams.length,
      itemBuilder: (context, index) {
        final league = groupedTeams.keys.elementAt(index);
        final leagueTeams = groupedTeams[league]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                league,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...leagueTeams.map((team) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: team.logo.isNotEmpty
                        ? Image.network(
                            team.logo,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.sports_soccer);
                            },
                          )
                        : const Icon(Icons.sports_soccer),
                  ),
                  title: Text(team.name),
                  subtitle: Text(team.league),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      ref.read(followedTeamsProvider.notifier).removeTeam(team.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已取消关注 ${team.name}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  void _showAddTeamDialog(BuildContext context, WidgetRef ref) {
    // 预设的常见球队列表
    final presetTeams = [
      Team(id: '1', name: '皇家马德里', logo: '', league: '西甲'),
      Team(id: '2', name: '巴塞罗那', logo: '', league: '西甲'),
      Team(id: '3', name: '曼城', logo: '', league: '英超'),
      Team(id: '4', name: '利物浦', logo: '', league: '英超'),
      Team(id: '5', name: '拜仁慕尼黑', logo: '', league: '德甲'),
      Team(id: '6', name: 'AC米兰', logo: '', league: '意甲'),
      Team(id: '7', name: '国际米兰', logo: '', league: '意甲'),
      Team(id: '8', name: '巴黎圣日耳曼', logo: '', league: '法甲'),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加关注球队'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: presetTeams.length,
            itemBuilder: (context, index) {
              final team = presetTeams[index];
              final isFollowing = ref.read(followedTeamsProvider.notifier).isFollowing(team.id);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: const Icon(Icons.sports_soccer),
                ),
                title: Text(team.name),
                subtitle: Text(team.league),
                trailing: isFollowing
                    ? const Icon(Icons.check, color: AppTheme.primaryGreen)
                    : const Icon(Icons.add),
                onTap: isFollowing
                    ? null
                    : () {
                        ref.read(followedTeamsProvider.notifier).addTeam(team);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已关注 ${team.name}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
              );
            },
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
}

