// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadingHistory _$ReadingHistoryFromJson(Map<String, dynamic> json) =>
    ReadingHistory(
      id: json['id'] as String,
      news: News.fromJson(json['news'] as Map<String, dynamic>),
      readAt: DateTime.parse(json['readAt'] as String),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$ReadingHistoryToJson(ReadingHistory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'news': instance.news,
      'readAt': instance.readAt.toIso8601String(),
      'duration': instance.duration,
      'progress': instance.progress,
    };
