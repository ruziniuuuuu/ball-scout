// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Match _$MatchFromJson(Map<String, dynamic> json) => Match(
      id: json['id'] as String,
      homeTeam: json['homeTeam'] as String,
      awayTeam: json['awayTeam'] as String,
      homeTeamLogo: json['homeTeamLogo'] as String? ?? '',
      awayTeamLogo: json['awayTeamLogo'] as String? ?? '',
      homeScore: (json['homeScore'] as num?)?.toInt(),
      awayScore: (json['awayScore'] as num?)?.toInt(),
      matchTime: DateTime.parse(json['matchTime'] as String),
      status: json['status'] as String,
      competition: json['competition'] as String,
      venue: json['venue'] as String? ?? '',
      minute: (json['minute'] as num?)?.toInt(),
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => MatchEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$MatchToJson(Match instance) => <String, dynamic>{
      'id': instance.id,
      'homeTeam': instance.homeTeam,
      'awayTeam': instance.awayTeam,
      'homeTeamLogo': instance.homeTeamLogo,
      'awayTeamLogo': instance.awayTeamLogo,
      'homeScore': instance.homeScore,
      'awayScore': instance.awayScore,
      'matchTime': instance.matchTime.toIso8601String(),
      'status': instance.status,
      'competition': instance.competition,
      'venue': instance.venue,
      'minute': instance.minute,
      'events': instance.events,
    };

MatchEvent _$MatchEventFromJson(Map<String, dynamic> json) => MatchEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      minute: (json['minute'] as num).toInt(),
      player: json['player'] as String,
      team: json['team'] as String,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$MatchEventToJson(MatchEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'minute': instance.minute,
      'player': instance.player,
      'team': instance.team,
      'description': instance.description,
    };

MatchResponse _$MatchResponseFromJson(Map<String, dynamic> json) =>
    MatchResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>)
          .map((e) => Match.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: MatchMetadata.fromJson(json['meta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MatchResponseToJson(MatchResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'meta': instance.meta,
    };

MatchMetadata _$MatchMetadataFromJson(Map<String, dynamic> json) =>
    MatchMetadata(
      total: (json['total'] as num).toInt(),
      timestamp: json['timestamp'] as String,
      date: json['date'] as String?,
    );

Map<String, dynamic> _$MatchMetadataToJson(MatchMetadata instance) =>
    <String, dynamic>{
      'total': instance.total,
      'timestamp': instance.timestamp,
      'date': instance.date,
    };
