// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Comment _$CommentFromJson(Map<String, dynamic> json) => Comment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      articleId: json['articleId'] as String?,
      matchId: json['matchId'] as String?,
      content: json['content'] as String,
      parentId: json['parentId'] as String?,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      dislikes: (json['dislikes'] as num?)?.toInt() ?? 0,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      user: json['user'] == null
          ? null
          : User.fromJson(json['user'] as Map<String, dynamic>),
      replies: (json['replies'] as List<dynamic>?)
          ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CommentToJson(Comment instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'articleId': instance.articleId,
      'matchId': instance.matchId,
      'content': instance.content,
      'parentId': instance.parentId,
      'likes': instance.likes,
      'dislikes': instance.dislikes,
      'isDeleted': instance.isDeleted,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'user': instance.user,
      'replies': instance.replies,
    };

CreateCommentRequest _$CreateCommentRequestFromJson(
        Map<String, dynamic> json) =>
    CreateCommentRequest(
      articleId: json['articleId'] as String?,
      matchId: json['matchId'] as String?,
      content: json['content'] as String,
      parentId: json['parentId'] as String?,
    );

Map<String, dynamic> _$CreateCommentRequestToJson(
        CreateCommentRequest instance) =>
    <String, dynamic>{
      'articleId': instance.articleId,
      'matchId': instance.matchId,
      'content': instance.content,
      'parentId': instance.parentId,
    };

CommentResponse _$CommentResponseFromJson(Map<String, dynamic> json) =>
    CommentResponse(
      success: json['success'] as bool,
      data: (json['data'] as List<dynamic>)
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: CommentMetadata.fromJson(json['meta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CommentResponseToJson(CommentResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'data': instance.data,
      'meta': instance.meta,
    };

CommentMetadata _$CommentMetadataFromJson(Map<String, dynamic> json) =>
    CommentMetadata(
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      timestamp: json['timestamp'] as String,
    );

Map<String, dynamic> _$CommentMetadataToJson(CommentMetadata instance) =>
    <String, dynamic>{
      'total': instance.total,
      'page': instance.page,
      'limit': instance.limit,
      'timestamp': instance.timestamp,
    };
