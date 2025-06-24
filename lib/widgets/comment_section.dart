import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../services/comment_service.dart';

class CommentSection extends ConsumerStatefulWidget {
  final String? articleId;
  final String? matchId;

  const CommentSection({
    super.key,
    this.articleId,
    this.matchId,
  });

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final notifier = ref.read(commentProvider({
        'articleId': widget.articleId,
        'matchId': widget.matchId,
      }).notifier);
      notifier.loadMore();
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(commentProvider({
        'articleId': widget.articleId,
        'matchId': widget.matchId,
      }).notifier);

      await notifier.createComment(_commentController.text.trim());
      _commentController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('评论发表成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发表评论失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentProvider({
      'articleId': widget.articleId,
      'matchId': widget.matchId,
    }));

    return Column(
      children: [
        // 评论输入框
        _buildCommentInput(),
        const Divider(height: 1),

        // 评论列表
        Expanded(
          child: commentsAsync.when(
            data: (comments) => _buildCommentList(comments),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _buildErrorWidget(error),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: '写下你的看法...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _isLoading ? null : _submitComment,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发表'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentList(List<Comment> comments) {
    if (comments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('还没有评论，来发表第一条吧！'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final notifier = ref.read(commentProvider({
          'articleId': widget.articleId,
          'matchId': widget.matchId,
        }).notifier);
        await notifier.loadComments(refresh: true);
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: comments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final comment = comments[index];
          return CommentCard(
            comment: comment,
            onLike: () => _handleLike(comment.id),
            onDislike: () => _handleDislike(comment.id),
            onReply: () => _handleReply(comment),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('加载评论失败: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final notifier = ref.read(commentProvider({
                'articleId': widget.articleId,
                'matchId': widget.matchId,
              }).notifier);
              notifier.loadComments(refresh: true);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLike(String commentId) async {
    try {
      final notifier = ref.read(commentProvider({
        'articleId': widget.articleId,
        'matchId': widget.matchId,
      }).notifier);
      await notifier.likeComment(commentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  Future<void> _handleDislike(String commentId) async {
    try {
      final notifier = ref.read(commentProvider({
        'articleId': widget.articleId,
        'matchId': widget.matchId,
      }).notifier);
      await notifier.dislikeComment(commentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  void _handleReply(Comment comment) {
    // TODO: 实现回复功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('回复功能即将上线')),
    );
  }
}

class CommentCard extends StatelessWidget {
  final Comment comment;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onReply;

  const CommentCard({
    super.key,
    required this.comment,
    this.onLike,
    this.onDislike,
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    comment.user?.nickname?.substring(0, 1) ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.user?.nickname ?? '匿名用户',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (comment.user?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: Colors.blue[600],
                            ),
                          ],
                        ],
                      ),
                      Text(
                        comment.timeAgoText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 评论内容
            Text(
              comment.content,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            // 操作按钮
            Row(
              children: [
                _buildActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: comment.likes.toString(),
                  onTap: onLike,
                  color: Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.thumb_down_outlined,
                  label: comment.dislikes.toString(),
                  onTap: onDislike,
                  color: Colors.red,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: Icons.reply_outlined,
                  label: '回复',
                  onTap: onReply,
                  color: Colors.grey,
                ),
              ],
            ),

            // 回复列表
            if (comment.hasReplies) ...[
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(left: 32),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: comment.replies!.map((reply) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CommentCard(
                        comment: reply,
                        onLike: () {}, // TODO: 实现回复点赞
                        onDislike: () {}, // TODO: 实现回复踩
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
