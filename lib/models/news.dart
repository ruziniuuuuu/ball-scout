import 'package:json_annotation/json_annotation.dart';

part 'news.g.dart';

@JsonSerializable()
class News {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String category;
  final String publishedAt;
  final int readCount;
  final String? imageUrl;
  final String? content;

  const News({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.category,
    required this.publishedAt,
    required this.readCount,
    this.imageUrl,
    this.content,
  });

  factory News.fromJson(Map<String, dynamic> json) => _$NewsFromJson(json);
  Map<String, dynamic> toJson() => _$NewsToJson(this);

  News copyWith({
    String? id,
    String? title,
    String? summary,
    String? source,
    String? category,
    String? publishedAt,
    int? readCount,
    String? imageUrl,
    String? content,
  }) {
    return News(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      source: source ?? this.source,
      category: category ?? this.category,
      publishedAt: publishedAt ?? this.publishedAt,
      readCount: readCount ?? this.readCount,
      imageUrl: imageUrl ?? this.imageUrl,
      content: content ?? this.content,
    );
  }

  // 获取新闻分类显示名称
  String get categoryDisplayName {
    switch (category) {
      case 'transfer':
        return '转会';
      case 'match':
        return '比赛';
      case 'news':
        return '新闻';
      case 'analysis':
        return '分析';
      default:
        return '其他';
    }
  }

  // 获取分类颜色
  String get categoryColor {
    switch (category) {
      case 'transfer':
        return '#FF6B35'; // 橙色
      case 'match':
        return '#007BFF'; // 蓝色
      case 'news':
        return '#00C851'; // 绿色
      case 'analysis':
        return '#AA66CC'; // 紫色
      default:
        return '#7F8C8D'; // 灰色
    }
  }

  // 获取相对时间显示文字
  String get timeAgoText {
    try {
      final publishTime = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(publishTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}天前';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}小时前';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}分钟前';
      } else {
        return '刚刚';
      }
    } catch (e) {
      return '未知时间';
    }
  }
}

@JsonSerializable()
class NewsResponse {
  final bool success;
  final List<News> data;
  final NewsMetadata meta;

  const NewsResponse({
    required this.success,
    required this.data,
    required this.meta,
  });

  factory NewsResponse.fromJson(Map<String, dynamic> json) =>
      _$NewsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$NewsResponseToJson(this);
}

@JsonSerializable()
class NewsMetadata {
  final int total;
  final String timestamp;

  const NewsMetadata({
    required this.total,
    required this.timestamp,
  });

  factory NewsMetadata.fromJson(Map<String, dynamic> json) =>
      _$NewsMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$NewsMetadataToJson(this);
}
