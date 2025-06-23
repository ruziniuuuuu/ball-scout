import 'package:json_annotation/json_annotation.dart';

part 'match.g.dart';

@JsonSerializable()
class Match {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String homeTeamLogo;
  final String awayTeamLogo;
  final int? homeScore;
  final int? awayScore;
  final DateTime matchTime;
  final String status; // scheduled, live, finished, postponed
  final String competition;
  final String venue;
  final int? minute; // 比赛进行的分钟数
  final List<MatchEvent> events;

  const Match({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamLogo = '',
    this.awayTeamLogo = '',
    this.homeScore,
    this.awayScore,
    required this.matchTime,
    required this.status,
    required this.competition,
    this.venue = '',
    this.minute,
    this.events = const [],
  });

  factory Match.fromJson(Map<String, dynamic> json) => _$MatchFromJson(json);
  Map<String, dynamic> toJson() => _$MatchToJson(this);

  Match copyWith({
    String? id,
    String? homeTeam,
    String? awayTeam,
    String? homeTeamLogo,
    String? awayTeamLogo,
    int? homeScore,
    int? awayScore,
    DateTime? matchTime,
    String? status,
    String? competition,
    String? venue,
    int? minute,
    List<MatchEvent>? events,
  }) {
    return Match(
      id: id ?? this.id,
      homeTeam: homeTeam ?? this.homeTeam,
      awayTeam: awayTeam ?? this.awayTeam,
      homeTeamLogo: homeTeamLogo ?? this.homeTeamLogo,
      awayTeamLogo: awayTeamLogo ?? this.awayTeamLogo,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      matchTime: matchTime ?? this.matchTime,
      status: status ?? this.status,
      competition: competition ?? this.competition,
      venue: venue ?? this.venue,
      minute: minute ?? this.minute,
      events: events ?? this.events,
    );
  }

  // 获取比赛状态显示文本
  String get statusDisplayText {
    switch (status) {
      case 'scheduled':
        return _formatMatchTime();
      case 'live':
        return minute != null ? "$minute'" : '进行中';
      case 'finished':
        return '已结束';
      case 'postponed':
        return '推迟';
      default:
        return status;
    }
  }

  // 获取比分显示文本
  String get scoreDisplay {
    if (homeScore != null && awayScore != null) {
      return '$homeScore : $awayScore';
    }
    return 'VS';
  }

  // 是否是实时比赛
  bool get isLive => status == 'live';

  // 是否已结束
  bool get isFinished => status == 'finished';

  // 是否未开始
  bool get isScheduled => status == 'scheduled';

  // 获取胜者（仅当比赛结束时）
  String? get winner {
    if (!isFinished || homeScore == null || awayScore == null) {
      return null;
    }
    if (homeScore! > awayScore!) {
      return homeTeam;
    } else if (awayScore! > homeScore!) {
      return awayTeam;
    }
    return null; // 平局
  }

  // 是否是平局
  bool get isDraw {
    return isFinished && 
           homeScore != null && 
           awayScore != null && 
           homeScore == awayScore;
  }

  String _formatMatchTime() {
    final now = DateTime.now();
    final difference = matchTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${matchTime.month}月${matchTime.day}日 ${_formatTime(matchTime)}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时后';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟后';
    } else {
      return '即将开始';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

@JsonSerializable()
class MatchEvent {
  final String id;
  final String type; // goal, card, substitution
  final int minute;
  final String player;
  final String team; // home or away
  final String? description;

  const MatchEvent({
    required this.id,
    required this.type,
    required this.minute,
    required this.player,
    required this.team,
    this.description,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) => _$MatchEventFromJson(json);
  Map<String, dynamic> toJson() => _$MatchEventToJson(this);

  // 获取事件图标
  String get eventIcon {
    switch (type) {
      case 'goal':
        return '⚽';
      case 'yellow_card':
        return '🟨';
      case 'red_card':
        return '🟥';
      case 'substitution':
        return '🔄';
      default:
        return '📝';
    }
  }

  // 获取事件描述
  String get eventDescription {
    switch (type) {
      case 'goal':
        return '$player 进球';
      case 'yellow_card':
        return '$player 黄牌';
      case 'red_card':
        return '$player 红牌';
      case 'substitution':
        return description ?? '$player 换人';
      default:
        return description ?? '';
    }
  }
}

@JsonSerializable()
class MatchResponse {
  final bool success;
  final List<Match> data;
  final MatchMetadata meta;

  const MatchResponse({
    required this.success,
    required this.data,
    required this.meta,
  });

  factory MatchResponse.fromJson(Map<String, dynamic> json) => _$MatchResponseFromJson(json);
  Map<String, dynamic> toJson() => _$MatchResponseToJson(this);
}

@JsonSerializable()
class MatchMetadata {
  final int total;
  final String timestamp;
  final String? date; // 查询的日期

  const MatchMetadata({
    required this.total,
    required this.timestamp,
    this.date,
  });

  factory MatchMetadata.fromJson(Map<String, dynamic> json) => _$MatchMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$MatchMetadataToJson(this);
} 