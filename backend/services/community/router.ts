import { Router } from 'https://deno.land/x/oak@v12.6.1/mod.ts';

const router = new Router();

// 模拟评论数据
const mockComments = [
  {
    id: '1',
    userId: 'user1',
    articleId: '1',
    matchId: null,
    content: '这个转会真是太意外了！皇马这次动作真快。',
    parentId: null,
    likes: 25,
    dislikes: 2,
    isDeleted: false,
    createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    updatedAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
    user: {
      id: 'user1',
      username: 'football_fan_88',
      email: 'fan88@example.com',
      avatar: '',
      nickname: '足球迷88',
      isVerified: false,
      createdAt: new Date().toISOString(),
      preferences: {
        favoriteTeams: ['皇马'],
        favoriteLeagues: ['西甲'],
        language: 'zh-CN',
        theme: 'light'
      }
    },
    replies: [
      {
        id: '2',
        userId: 'user2',
        articleId: '1',
        matchId: null,
        content: '同意！这个价格在当今市场算是合理的。',
        parentId: '1',
        likes: 8,
        dislikes: 1,
        isDeleted: false,
        createdAt: new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString(),
        updatedAt: new Date(Date.now() - 1 * 60 * 60 * 1000).toISOString(),
        user: {
          id: 'user2',
          username: 'madrid_lover',
          email: 'madrid@example.com',
          avatar: '',
          nickname: '皇马忠粉',
          isVerified: true,
          createdAt: new Date().toISOString(),
          preferences: {
            favoriteTeams: ['皇马'],
            favoriteLeagues: ['西甲', '欧冠'],
            language: 'zh-CN',
            theme: 'dark'
          }
        },
        replies: []
      }
    ]
  },
  {
    id: '3',
    userId: 'user3',
    articleId: '1',
    matchId: null,
    content: '希望这个小将能适应皇马的节奏，期待他的表现！💪',
    parentId: null,
    likes: 15,
    dislikes: 0,
    isDeleted: false,
    createdAt: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
    updatedAt: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
    user: {
      id: 'user3',
      username: 'brazil_scout',
      email: 'scout@example.com',
      avatar: '',
      nickname: '巴西球探',
      isVerified: true,
      createdAt: new Date().toISOString(),
      preferences: {
        favoriteTeams: ['皇马', '巴西国家队'],
        favoriteLeagues: ['西甲', '巴甲'],
        language: 'zh-CN',
        theme: 'light'
      }
    },
    replies: []
  }
];

// 获取评论列表
router.get('/api/v1/comments', (ctx) => {
  const articleId = ctx.request.url.searchParams.get('articleId');
  const matchId = ctx.request.url.searchParams.get('matchId');
  const sortType = ctx.request.url.searchParams.get('sort') || 'newest';
  const page = parseInt(ctx.request.url.searchParams.get('page') || '1');
  const limit = parseInt(ctx.request.url.searchParams.get('limit') || '20');

  // 过滤评论
  let filteredComments = mockComments;
  if (articleId) {
    filteredComments = mockComments.filter(c => c.articleId === articleId);
  }
  if (matchId) {
    filteredComments = mockComments.filter(c => c.matchId === matchId);
  }

  // 排序
  switch (sortType) {
    case 'newest':
      filteredComments.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
      break;
    case 'oldest':
      filteredComments.sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
      break;
    case 'hottest':
      filteredComments.sort((a, b) => (b.likes - b.dislikes) - (a.likes - a.dislikes));
      break;
  }

  // 分页
  const startIndex = (page - 1) * limit;
  const endIndex = startIndex + limit;
  const paginatedComments = filteredComments.slice(startIndex, endIndex);

  ctx.response.body = {
    success: true,
    data: paginatedComments,
    meta: {
      total: filteredComments.length,
      page,
      limit,
      timestamp: new Date().toISOString(),
    },
  };
});

// 发表评论
router.post('/api/v1/comments', async (ctx) => {
  try {
    const body = await ctx.request.body().value;
    const { articleId, matchId, content, parentId } = body;

    // 模拟创建评论
    const newComment = {
      id: `comment_${Date.now()}`,
      userId: 'current_user',
      articleId: articleId || null,
      matchId: matchId || null,
      content,
      parentId: parentId || null,
      likes: 0,
      dislikes: 0,
      isDeleted: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      user: {
        id: 'current_user',
        username: 'current_user',
        email: 'user@example.com',
        avatar: '',
        nickname: '当前用户',
        isVerified: false,
        createdAt: new Date().toISOString(),
        preferences: {
          favoriteTeams: [],
          favoriteLeagues: [],
          language: 'zh-CN',
          theme: 'light'
        }
      },
      replies: []
    };

    // 添加到模拟数据中
    mockComments.unshift(newComment);

    ctx.response.body = {
      success: true,
      data: newComment,
      message: '评论发表成功'
    };
  } catch (error) {
    ctx.response.status = 400;
    ctx.response.body = {
      success: false,
      error: {
        code: 'INVALID_REQUEST',
        message: '请求参数无效'
      }
    };
  }
});

// 点赞评论
router.post('/api/v1/comments/:commentId/like', (ctx) => {
  const commentId = ctx.params.commentId;
  const comment = mockComments.find(c => c.id === commentId);

  if (!comment) {
    ctx.response.status = 404;
    ctx.response.body = {
      success: false,
      error: {
        code: 'COMMENT_NOT_FOUND',
        message: '评论不存在'
      }
    };
    return;
  }

  // 模拟点赞
  comment.likes += 1;

  ctx.response.body = {
    success: true,
    data: {
      commentId,
      likes: comment.likes,
      dislikes: comment.dislikes
    },
    message: '点赞成功'
  };
});

// 取消点赞评论
router.delete('/api/v1/comments/:commentId/like', (ctx) => {
  const commentId = ctx.params.commentId;
  const comment = mockComments.find(c => c.id === commentId);

  if (!comment) {
    ctx.response.status = 404;
    ctx.response.body = {
      success: false,
      error: {
        code: 'COMMENT_NOT_FOUND',
        message: '评论不存在'
      }
    };
    return;
  }

  // 模拟取消点赞
  comment.likes = Math.max(0, comment.likes - 1);

  ctx.response.body = {
    success: true,
    data: {
      commentId,
      likes: comment.likes,
      dislikes: comment.dislikes
    },
    message: '取消点赞成功'
  };
});

// 踩评论
router.post('/api/v1/comments/:commentId/dislike', (ctx) => {
  const commentId = ctx.params.commentId;
  const comment = mockComments.find(c => c.id === commentId);

  if (!comment) {
    ctx.response.status = 404;
    ctx.response.body = {
      success: false,
      error: {
        code: 'COMMENT_NOT_FOUND',
        message: '评论不存在'
      }
    };
    return;
  }

  // 模拟踩
  comment.dislikes += 1;

  ctx.response.body = {
    success: true,
    data: {
      commentId,
      likes: comment.likes,
      dislikes: comment.dislikes
    },
    message: '操作成功'
  };
});

// 删除评论
router.delete('/api/v1/comments/:commentId', (ctx) => {
  const commentId = ctx.params.commentId;
  const comment = mockComments.find(c => c.id === commentId);

  if (!comment) {
    ctx.response.status = 404;
    ctx.response.body = {
      success: false,
      error: {
        code: 'COMMENT_NOT_FOUND',
        message: '评论不存在'
      }
    };
    return;
  }

  // 软删除
  comment.isDeleted = true;
  comment.content = '该评论已被删除';

  ctx.response.body = {
    success: true,
    message: '评论删除成功'
  };
});

export default router; 