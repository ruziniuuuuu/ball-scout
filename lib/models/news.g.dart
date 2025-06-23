// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

News _$NewsFromJson(Map<String, dynamic> json) => News(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      source: json['source'] as String,
      category: json['category'] as String,
      publishedAt: json['publishedAt'] as String,
      readCount: (json['readCount'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      content: json['content'] as String?,
    );

Map<String, dynamic> _$NewsToJson(News instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'summary': instance.summary,
      'source': instance.source,
      'category': instance.category,
      'publishedAt': instance.publishedAt,
      'readCount': instance.readCount,
      'imageUrl': instance.imageUrl,
      'content': instance.content,
    };

NewsResponse _$NewsResponseFromJson(Map<String, dynamic> json) => NewsResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>)
          .map((e) => News.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: NewsMetadata.fromJson(json['meta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$NewsResponseToJson(NewsResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'meta': instance.meta,
    };

NewsMetadata _$NewsMetadataFromJson(Map<String, dynamic> json) => NewsMetadata(
      total: (json['total'] as num).toInt(),
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$NewsMetadataToJson(NewsMetadata instance) =>
    <String, dynamic>{
      'total': instance.total,
      'timestamp': instance.timestamp,
    };
