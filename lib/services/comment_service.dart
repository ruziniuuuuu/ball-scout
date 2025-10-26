import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/comment.dart';
import 'api_config.dart';

class CommentService {
  late final Dio _dio;

  CommentService() {
    final apiBase = ApiConfig.join('/api/v1/');
    _dio = Dio(BaseOptions(
      baseUrl: apiBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
  }

  // 获取评论列表
  Future<CommentResponse> getComments({
    String? articleId,
    String? matchId,
    CommentSortType sortType = CommentSortType.newest,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get('/comments', queryParameters: {
        if (articleId != null) 'articleId': articleId,
        if (matchId != null) 'matchId': matchId,
        'sort': sortType.apiValue,
        'page': page,
        'limit': limit,
      });

      if (response.statusCode == 200) {
        return CommentResponse.fromJson(response.data);
      } else {
        throw Exception('获取评论失败');
      }
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  // 发表评论
  Future<Comment> createComment({
    String? articleId,
    String? matchId,
    required String content,
    String? parentId,
  }) async {
    try {
      final response = await _dio.post('/comments', data: {
        if (articleId != null) 'articleId': articleId,
        if (matchId != null) 'matchId': matchId,
        'content': content,
        if (parentId != null) 'parentId': parentId,
      });

      if (response.statusCode == 200) {
        return Comment.fromJson(response.data['data']);
      } else {
        throw Exception('发表评论失败');
      }
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  // 点赞评论
  Future<Map<String, int>> likeComment(String commentId) async {
    try {
      final response = await _dio.post('/comments/$commentId/like');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        return {
          'likes': data['likes'],
          'dislikes': data['dislikes'],
        };
      } else {
        throw Exception('点赞失败');
      }
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  // 取消点赞评论
  Future<Map<String, int>> unlikeComment(String commentId) async {
    try {
      final response = await _dio.delete('/comments/$commentId/like');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        return {
          'likes': data['likes'],
          'dislikes': data['dislikes'],
        };
      } else {
        throw Exception('取消点赞失败');
      }
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  // 踩评论
  Future<Map<String, int>> dislikeComment(String commentId) async {
    try {
      final response = await _dio.post('/comments/$commentId/dislike');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        return {
          'likes': data['likes'],
          'dislikes': data['dislikes'],
        };
      } else {
        throw Exception('操作失败');
      }
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }

  // 删除评论
  Future<void> deleteComment(String commentId) async {
    try {
      final response = await _dio.delete('/comments/$commentId');

      if (response.statusCode != 200) {
        throw Exception('删除评论失败');
      }
    } catch (e) {
      throw Exception('网络请求失败: $e');
    }
  }
}

// Provider
final commentServiceProvider = Provider<CommentService>((ref) {
  return CommentService();
});

// 评论状态管理
class CommentNotifier extends StateNotifier<AsyncValue<List<Comment>>> {
  CommentNotifier(this._commentService, this._articleId, this._matchId)
      : super(const AsyncValue.loading()) {
    loadComments();
  }

  final CommentService _commentService;
  final String? _articleId;
  final String? _matchId;
  CommentSortType _sortType = CommentSortType.newest;
  int _currentPage = 1;
  bool _hasMore = true;

  CommentSortType get sortType => _sortType;

  Future<void> loadComments({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      state = const AsyncValue.loading();
    }

    try {
      final response = await _commentService.getComments(
        articleId: _articleId,
        matchId: _matchId,
        sortType: _sortType,
        page: _currentPage,
      );

      if (refresh || _currentPage == 1) {
        state = AsyncValue.data(response.data);
      } else {
        state.whenData((currentComments) {
          final newComments = [...currentComments, ...response.data];
          state = AsyncValue.data(newComments);
        });
      }

      _hasMore = response.data.length >= 20; // 假设每页20条
      _currentPage++;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> loadMore() async {
    if (_hasMore && !state.isLoading) {
      await loadComments();
    }
  }

  Future<void> createComment(String content, {String? parentId}) async {
    try {
      await _commentService.createComment(
        articleId: _articleId,
        matchId: _matchId,
        content: content,
        parentId: parentId,
      );
      // 刷新评论列表
      await loadComments(refresh: true);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> likeComment(String commentId) async {
    try {
      final result = await _commentService.likeComment(commentId);
      _updateCommentLikes(commentId, result['likes']!, result['dislikes']!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> unlikeComment(String commentId) async {
    try {
      final result = await _commentService.unlikeComment(commentId);
      _updateCommentLikes(commentId, result['likes']!, result['dislikes']!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> dislikeComment(String commentId) async {
    try {
      final result = await _commentService.dislikeComment(commentId);
      _updateCommentLikes(commentId, result['likes']!, result['dislikes']!);
    } catch (e) {
      rethrow;
    }
  }

  void _updateCommentLikes(String commentId, int likes, int dislikes) {
    state.whenData((comments) {
      final updatedComments = comments.map((comment) {
        if (comment.id == commentId) {
          return comment.copyWith(likes: likes, dislikes: dislikes);
        }
        // 也要检查回复
        if (comment.hasReplies) {
          final updatedReplies = comment.replies!.map((reply) {
            if (reply.id == commentId) {
              return reply.copyWith(likes: likes, dislikes: dislikes);
            }
            return reply;
          }).toList();
          return comment.copyWith(replies: updatedReplies);
        }
        return comment;
      }).toList();
      state = AsyncValue.data(updatedComments);
    });
  }

  void changeSortType(CommentSortType newSortType) {
    if (_sortType != newSortType) {
      _sortType = newSortType;
      loadComments(refresh: true);
    }
  }
}

// Provider工厂函数
final commentProvider = StateNotifierProvider.family<CommentNotifier,
    AsyncValue<List<Comment>>, Map<String, String?>>((ref, params) {
  final commentService = ref.watch(commentServiceProvider);
  return CommentNotifier(
    commentService,
    params['articleId'],
    params['matchId'],
  );
});
