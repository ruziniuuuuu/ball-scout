import 'package:json_annotation/json_annotation.dart';
import 'news.dart';

part 'reading_history.g.dart';

@JsonSerializable()
class ReadingHistory {
  final String id;
  final News news;
  final DateTime readAt;
  final int duration; // 阅读时长（秒）
  final double progress; // 阅读进度 0.0-1.0

  const ReadingHistory({
    required this.id,
    required this.news,
    required this.readAt,
    this.duration = 0,
    this.progress = 0.0,
  });

  factory ReadingHistory.fromJson(Map<String, dynamic> json) => _$ReadingHistoryFromJson(json);
  Map<String, dynamic> toJson() => _$ReadingHistoryToJson(this);

  ReadingHistory copyWith({
    String? id,
    News? news,
    DateTime? readAt,
    int? duration,
    double? progress,
  }) {
    return ReadingHistory(
      id: id ?? this.id,
      news: news ?? this.news,
      readAt: readAt ?? this.readAt,
      duration: duration ?? this.duration,
      progress: progress ?? this.progress,
    );
  }

  // 获取阅读时间描述
  String get readTimeDescription {
    final now = DateTime.now();
    final difference = now.difference(readAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前阅读';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前阅读';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前阅读';
    } else {
      return '刚刚阅读';
    }
  }

  // 获取阅读进度描述
  String get progressDescription {
    if (progress >= 1.0) {
      return '已读完';
    } else if (progress >= 0.8) {
      return '读了大部分';
    } else if (progress >= 0.5) {
      return '读了一半';
    } else if (progress > 0) {
      return '读了开头';
    } else {
      return '刚开始读';
    }
  }

  // 创建阅读历史记录
  static ReadingHistory create(News news, {int duration = 0, double progress = 0.0}) {
    return ReadingHistory(
      id: '${news.id}_${DateTime.now().millisecondsSinceEpoch}',
      news: news,
      readAt: DateTime.now(),
      duration: duration,
      progress: progress,
    );
  }
} 