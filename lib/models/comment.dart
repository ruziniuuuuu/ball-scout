import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'comment.g.dart';

@JsonSerializable()
class Comment {
  final String id;
  final String userId;
  final String? articleId; // 新闻文章ID
  final String? matchId;   // 比赛ID
  final String content;
  final String? parentId;  // 父评论ID，用于回复
  final int likes;
  final int dislikes;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // 用户信息 (从API返回时包含)
  final User? user;
  
  // 回复列表 (从API返回时可能包含)
  final List<Comment>? replies;

  const Comment({
    required this.id,
    required this.userId,
    this.articleId,
    this.matchId,
    required this.content,
    this.parentId,
    this.likes = 0,
    this.dislikes = 0,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.replies,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => _$CommentFromJson(json);
  Map<String, dynamic> toJson() => _$CommentToJson(this);

  Comment copyWith({
    String? id,
    String? userId,
    String? articleId,
    String? matchId,
    String? content,
    String? parentId,
    int? likes,
    int? dislikes,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    User? user,
    List<Comment>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      articleId: articleId ?? this.articleId,
      matchId: matchId ?? this.matchId,
      content: content ?? this.content,
      parentId: parentId ?? this.parentId,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      user: user ?? this.user,
      replies: replies ?? this.replies,
    );
  }

  // 是否是顶级评论
  bool get isTopLevel => parentId == null;

  // 是否是回复
  bool get isReply => parentId != null;

  // 获取时间显示文字
  String get timeAgoText {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 获取点赞比率
  double get likeRatio {
    final total = likes + dislikes;
    if (total == 0) return 0.0;
    return likes / total;
  }

  // 获取净点赞数
  int get netLikes => likes - dislikes;

  // 是否有回复
  bool get hasReplies => replies != null && replies!.isNotEmpty;

  // 回复数量
  int get replyCount => replies?.length ?? 0;
}

// 评论创建请求
@JsonSerializable()
class CreateCommentRequest {
  final String? articleId;
  final String? matchId;
  final String content;
  final String? parentId;

  const CreateCommentRequest({
    this.articleId,
    this.matchId,
    required this.content,
    this.parentId,
  });

  factory CreateCommentRequest.fromJson(Map<String, dynamic> json) => 
      _$CreateCommentRequestFromJson(json);
  Map<String, dynamic> toJson() => _$CreateCommentRequestToJson(this);
}

// 评论响应
@JsonSerializable()
class CommentResponse {
  final bool success;
  final List<Comment> data;
  final CommentMetadata meta;

  const CommentResponse({
    required this.success,
    required this.data,
    required this.meta,
  });

  factory CommentResponse.fromJson(Map<String, dynamic> json) => 
      _$CommentResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CommentResponseToJson(this);
}

// 评论元数据
@JsonSerializable()
class CommentMetadata {
  final int total;
  final int page;
  final int limit;
  final String timestamp;

  const CommentMetadata({
    required this.total,
    required this.page,
    required this.limit,
    required this.timestamp,
  });

  factory CommentMetadata.fromJson(Map<String, dynamic> json) => 
      _$CommentMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$CommentMetadataToJson(this);
}

// 评论排序方式
enum CommentSortType {
  newest,  // 最新
  oldest,  // 最早
  hottest, // 最热（点赞数）
}

extension CommentSortTypeExtension on CommentSortType {
  String get displayName {
    switch (this) {
      case CommentSortType.newest:
        return '最新';
      case CommentSortType.oldest:
        return '最早';
      case CommentSortType.hottest:
        return '最热';
    }
  }

  String get apiValue {
    switch (this) {
      case CommentSortType.newest:
        return 'newest';
      case CommentSortType.oldest:
        return 'oldest';
      case CommentSortType.hottest:
        return 'hottest';
    }
  }
} 