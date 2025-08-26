import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../services/api_service.dart';

/// 增强的评论服务
/// 
/// 提供完整的评论功能，包括：
/// - 获取评论列表
/// - 发布评论和回复
/// - 点赞/取消点赞
/// - 删除评论
/// - 评论搜索和排序
class EnhancedCommentService {
  final ApiService _apiService;
  
  EnhancedCommentService(this._apiService);

  /// 获取评论列表
  Future<List<Comment>> getComments(String contentId, {
    CommentContentType type = CommentContentType.article,
    int page = 1,
    int limit = 20,
    CommentSortType sort = CommentSortType.newest,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'sort': sort.apiValue,
      };

      String endpoint;
      switch (type) {
        case CommentContentType.article:
          endpoint = '/api/v1/news/$contentId/comments';
          break;
        case CommentContentType.match:
          endpoint = '/api/v1/matches/$contentId/comments';
          break;
      }

      // 模拟API调用（实际项目中应该调用真实API）
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 返回模拟数据
      return _generateMockComments(contentId);
    } catch (e) {
      throw Exception('获取评论失败: $e');
    }
  }

  /// 添加评论
  Future<Comment> addComment({
    required String contentId,
    required CommentContentType contentType,
    required String content,
    String? parentId,
  }) async {
    try {
      final request = CreateCommentRequest(
        articleId: contentType == CommentContentType.article ? contentId : null,
        matchId: contentType == CommentContentType.match ? contentId : null,
        content: content,
        parentId: parentId,
      );

      // 模拟API调用
      await Future.delayed(const Duration(milliseconds: 800));
      
      // 返回新创建的评论
      return _createMockComment(contentId, content, parentId);
    } catch (e) {
      throw Exception('发布评论失败: $e');
    }
  }

  /// 切换点赞状态
  Future<bool> toggleLike(String commentId) async {
    try {
      // 模拟API调用
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 返回新的点赞状态
      return true; // 简化实现，实际应该返回真实状态
    } catch (e) {
      throw Exception('操作失败: $e');
    }
  }

  /// 删除评论
  Future<void> deleteComment(String commentId) async {
    try {
      // 模拟API调用
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 实际实现中应该调用删除API
    } catch (e) {
      throw Exception('删除评论失败: $e');
    }
  }

  /// 举报评论
  Future<void> reportComment(String commentId, String reason) async {
    try {
      // 模拟API调用
      await Future.delayed(const Duration(milliseconds: 400));
      
      // 实际实现中应该调用举报API
    } catch (e) {
      throw Exception('举报失败: $e');
    }
  }

  /// 搜索评论
  Future<List<Comment>> searchComments(String query, {
    String? contentId,
    CommentContentType? contentType,
  }) async {
    try {
      // 模拟API调用
      await Future.delayed(const Duration(milliseconds: 600));
      
      // 返回搜索结果（简化实现）
      return _generateMockComments(contentId ?? 'search');
    } catch (e) {
      throw Exception('搜索失败: $e');
    }
  }

  /// 生成模拟评论数据
  List<Comment> _generateMockComments(String contentId) {
    final now = DateTime.now();
    
    return [
      Comment(
        id: '1',
        userId: 'user1',
        articleId: contentId,
        content: '这是一条精彩的评论！写得很好，分析很到位。',
        likes: 15,
        dislikes: 2,
        isDeleted: false,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        isLiked: false,
        user: _createMockUser('张三', 'user1'),
        replies: [
          Comment(
            id: '1-1',
            userId: 'user2',
            articleId: contentId,
            content: '同意楼主的观点！',
            parentId: '1',
            likes: 5,
            dislikes: 0,
            isDeleted: false,
            createdAt: now.subtract(const Duration(hours: 1)),
            updatedAt: now.subtract(const Duration(hours: 1)),
            isLiked: true,
            user: _createMockUser('李四', 'user2'),
          ),
        ],
      ),
      Comment(
        id: '2',
        userId: 'user3',
        articleId: contentId,
        content: '很有见地的分析，学到了！👍',
        likes: 8,
        dislikes: 1,
        isDeleted: false,
        createdAt: now.subtract(const Duration(minutes: 30)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        isLiked: false,
        user: _createMockUser('王五', 'user3'),
      ),
      Comment(
        id: '3',
        userId: 'user4',
        articleId: contentId,
        content: '期待看到更多这样的深度内容。作者辛苦了！',
        likes: 12,
        dislikes: 0,
        isDeleted: false,
        createdAt: now.subtract(const Duration(minutes: 15)),
        updatedAt: now.subtract(const Duration(minutes: 15)),
        isLiked: true,
        user: _createMockUser('足球迷', 'user4'),
      ),
    ];
  }

  /// 创建模拟用户
  _createMockUser(String username, String userId) {
    return {
      'id': userId,
      'username': username,
      'email': '$userId@example.com',
      'avatar': null,
      'nickname': username,
      'level': 1,
      'isVerified': false,
      'createdAt': DateTime.now().subtract(const Duration(days: 30)),
    };
  }

  /// 创建模拟评论
  Comment _createMockComment(String contentId, String content, String? parentId) {
    final now = DateTime.now();
    final commentId = 'comment_${now.millisecondsSinceEpoch}';
    
    return Comment(
      id: commentId,
      userId: 'current_user',
      articleId: contentId,
      content: content,
      parentId: parentId,
      likes: 0,
      dislikes: 0,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
      isLiked: false,
      user: _createMockUser('我', 'current_user'),
    );
  }
}

// 评论服务Provider
final enhancedCommentServiceProvider = Provider<EnhancedCommentService>((ref) {
  final apiService = ref.read(apiServiceProvider);
  return EnhancedCommentService(apiService);
});

// 评论列表Provider
final commentsProvider = FutureProvider.family<List<Comment>, String>((ref, contentId) async {
  final commentService = ref.read(enhancedCommentServiceProvider);
  return await commentService.getComments(contentId);
});

// 评论数量Provider
final commentCountProvider = Provider.family<int, String>((ref, contentId) {
  final commentsAsync = ref.watch(commentsProvider(contentId));
  return commentsAsync.maybeWhen(
    data: (comments) => comments.length,
    orElse: () => 0,
  );
});

// 热门评论Provider
final hotCommentsProvider = FutureProvider.family<List<Comment>, String>((ref, contentId) async {
  final commentService = ref.read(enhancedCommentServiceProvider);
  return await commentService.getComments(
    contentId,
    sort: CommentSortType.hottest,
    limit: 3, // 只获取前3条热门评论
  );
});