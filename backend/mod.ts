import { Application, Router } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { oakCors } from 'https://deno.land/x/cors@v1.2.2/mod.ts';
import { config, validateConfig } from './config.ts';
import {
  DatabaseManager,
  initializeDatabase,
  RedisManager,
} from './shared/db.ts';
import { errorHandler } from './shared/errors.ts';
import { logger } from './shared/logger.ts';

// 引入各个服务路由
import enhancedNewsRouter from './services/news/enhanced-router.ts';
import {
  aiNewsService,
  type AiNewsListOptions,
} from './services/news/ai-service.ts';
import { userRouter } from './services/user/router.ts';
import communityRouter from './services/community/router.ts';
import translationRouter from './services/translation/router.ts';
import { crawlerRouter } from './services/news/crawler-router.ts';
import { analyticsRouter } from './routes/analytics.ts';

// 验证配置
validateConfig();

// 创建应用实例
const app = new Application();
const router = new Router();

// 初始化数据库连接
const dbManager = new DatabaseManager(config.database);
const redisManager = new RedisManager(config.redis);

// 统一错误处理中间件（放在最前面）
app.use(errorHandler);

// 数据库连接中间件
app.use(async (ctx, next) => {
  ctx.state.db = dbManager;
  ctx.state.redis = redisManager;
  await next();
});

// 请求日志中间件
app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  const duration = Date.now() - start;
  
  logger.logRequest(
    ctx.request.method,
    ctx.request.url.pathname,
    ctx.response.status,
    duration,
    {
      query: Object.fromEntries(ctx.request.url.searchParams),
    },
  );
});

// CORS中间件
app.use(oakCors({
  origin: config.cors.origin,
  credentials: config.cors.credentials,
}));

// 健康检查
router.get('/health', (ctx) => {
  ctx.response.body = {
    success: true,
    data: {
      status: 'healthy',
      version: '1.5.0',
      environment: config.env,
      timestamp: new Date().toISOString(),
      services: {
        database: 'connected',
        redis: 'connected',
      },
    },
  };
});

// API文档
router.get('/api', (ctx) => {
  ctx.response.body = {
    success: true,
    data: {
      title: '球探社 API v1.5',
      description: '提供足球新闻、比赛数据、用户认证和社区功能的RESTful API',
      version: '1.5.0',
      endpoints: {
        news: {
          'GET /api/v1/news': '获取新闻列表',
          'GET /api/v1/news/:id': '获取新闻详情',
          'GET /api/v1/news/search': '搜索新闻',
        },
        matches: {
          'GET /api/v1/matches': '获取比赛列表',
          'GET /api/v1/matches/:id': '获取比赛详情',
        },
        auth: {
          'POST /api/v1/auth/login': '用户登录',
          'POST /api/v1/auth/register': '用户注册',
          'GET /api/v1/auth/profile': '获取用户信息',
        },
        community: {
          'GET /api/v1/comments': '获取评论列表',
          'POST /api/v1/comments': '发表评论',
          'PUT /api/v1/comments/:id/like': '点赞评论',
        },
        translation: {
          'POST /api/v1/translate': 'AI翻译服务',
          'GET /api/v1/translate/status': '翻译服务状态',
        },
        analytics: {
          'POST /api/v1/analytics/track': '记录用户行为',
          'GET /api/v1/analytics/content/:id': '获取内容分析',
          'GET /api/v1/analytics/trending': '获取热门趋势',
          'GET /api/v1/analytics/user/insights': '获取用户洞察',
          'GET /api/v1/analytics/dashboard': '获取分析仪表板',
          'GET /api/v1/analytics/system/metrics': '获取系统指标（管理员）',
        },
      },
    },
  };
});

// 注册路由
app.use(router.routes());
app.use(router.allowedMethods());

// 注册服务路由
app.use(enhancedNewsRouter.routes());
app.use(enhancedNewsRouter.allowedMethods());

app.use(userRouter.routes());
app.use(userRouter.allowedMethods());

app.use(communityRouter.routes());
app.use(communityRouter.allowedMethods());

app.use(translationRouter.routes());
app.use(translationRouter.allowedMethods());

app.use(crawlerRouter.routes());
app.use(crawlerRouter.allowedMethods());

app.use(analyticsRouter.routes());
app.use(analyticsRouter.allowedMethods());

router.get('/api/v1/news', async (ctx) => {
  try {
    const params = ctx.request.url.searchParams;
    const page = clampNumber(parseInt(params.get('page') || '1', 10), 1, 1000);
    const limit = clampNumber(parseInt(params.get('limit') || '20', 10), 1, 100);
    const category = mapCategory((params.get('category') || 'all').toLowerCase());
    const language = params.get('language') || 'zh-CN';
    const translate = params.get('translate') !== 'false';

    const { items, meta } = await aiNewsService.getNewsList({
      page,
      limit,
      category,
      language,
      translate,
    });

    const payload = items.map((item) => ({
      id: item.id,
      title: item.title,
      summary: item.summary,
      source: item.source,
      category: item.category,
      publishedAt: item.publishedAt,
      readCount: item.readCount,
      imageUrl: item.imageUrl,
      content: undefined,
      aiMeta: item.aiMeta,
    }));

    ctx.response.body = {
      success: true,
      data: payload,
      meta: {
        total: meta.total,
        timestamp: meta.timestamp,
      },
    };
  } catch (error) {
    console.error('获取AI新闻列表失败:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'AI_NEWS_LIST_ERROR',
        message: '获取新闻失败，请稍后再试',
      },
    };
  }
});

// 获取比赛列表
router.get('/api/v1/matches', (ctx) => {
  const queryDate = ctx.request.url.searchParams.get('date');
  const targetDate = queryDate ? new Date(queryDate) : new Date();

  const mockMatches = [
    {
      id: '1',
      homeTeam: '皇家马德里',
      awayTeam: '巴塞罗那',
      homeTeamLogo: '',
      awayTeamLogo: '',
      homeScore: 2,
      awayScore: 1,
      matchTime: new Date(targetDate.getTime() + 2 * 60 * 60 * 1000)
        .toISOString(),
      status: 'finished',
      competition: '西甲',
      venue: '伯纳乌球场',
      minute: null,
      events: [
        {
          id: '1',
          type: 'goal',
          minute: 23,
          player: '本泽马',
          team: 'home',
          description: '点球破门',
        },
        {
          id: '2',
          type: 'goal',
          minute: 45,
          player: '梅西',
          team: 'away',
          description: '任意球直接破门',
        },
        {
          id: '3',
          type: 'goal',
          minute: 78,
          player: '维尼修斯',
          team: 'home',
          description: '反击破门',
        },
      ],
    },
    {
      id: '2',
      homeTeam: '曼城',
      awayTeam: '利物浦',
      homeTeamLogo: '',
      awayTeamLogo: '',
      homeScore: 1,
      awayScore: 1,
      matchTime: new Date(targetDate.getTime() + 4 * 60 * 60 * 1000)
        .toISOString(),
      status: 'live',
      competition: '英超',
      venue: '伊蒂哈德球场',
      minute: 67,
      events: [
        {
          id: '4',
          type: 'goal',
          minute: 12,
          player: '哈兰德',
          team: 'home',
          description: '近距离推射',
        },
        {
          id: '5',
          type: 'goal',
          minute: 56,
          player: '萨拉赫',
          team: 'away',
          description: '单刀破门',
        },
      ],
    },
    {
      id: '3',
      homeTeam: '拜仁慕尼黑',
      awayTeam: '多特蒙德',
      homeTeamLogo: '',
      awayTeamLogo: '',
      homeScore: null,
      awayScore: null,
      matchTime: new Date(targetDate.getTime() + 6 * 60 * 60 * 1000)
        .toISOString(),
      status: 'scheduled',
      competition: '德甲',
      venue: '安联球场',
      minute: null,
      events: [],
    },
    {
      id: '4',
      homeTeam: 'AC米兰',
      awayTeam: '国际米兰',
      homeTeamLogo: '',
      awayTeamLogo: '',
      homeScore: null,
      awayScore: null,
      matchTime: new Date(targetDate.getTime() + 24 * 60 * 60 * 1000)
        .toISOString(),
      status: 'scheduled',
      competition: '意甲',
      venue: '圣西罗球场',
      minute: null,
      events: [],
    },
  ];

  // 根据日期筛选比赛 - 需要匹配日期（忽略时间）
  const filteredMatches = mockMatches.filter((match) => {
    const matchDate = new Date(match.matchTime);
    const targetDateOnly = new Date(targetDate.getFullYear(), targetDate.getMonth(), targetDate.getDate());
    const matchDateOnly = new Date(matchDate.getFullYear(), matchDate.getMonth(), matchDate.getDate());
    return matchDateOnly.getTime() === targetDateOnly.getTime();
  });

  ctx.response.body = {
    success: true,
    data: filteredMatches,
    meta: {
      total: filteredMatches.length,
      timestamp: new Date().toISOString(),
      date: targetDate.toISOString().split('T')[0],
    },
  };
});

// 获取单个比赛详情
router.get('/api/v1/matches/:id', (ctx) => {
  const id = ctx.params.id;

  // 模拟比赛详情数据
  const matchDetail = {
    id,
    homeTeam: '皇家马德里',
    awayTeam: '巴塞罗那',
    homeTeamLogo: '',
    awayTeamLogo: '',
    homeScore: 2,
    awayScore: 1,
    matchTime: new Date().toISOString(),
    status: 'finished',
    competition: '西甲',
    venue: '伯纳乌球场',
    minute: null,
    events: [
      {
        id: '1',
        type: 'goal',
        minute: 23,
        player: '本泽马',
        team: 'home',
        description: '点球破门',
      },
      {
        id: '2',
        type: 'goal',
        minute: 45,
        player: '梅西',
        team: 'away',
        description: '任意球直接破门',
      },
      {
        id: '3',
        type: 'goal',
        minute: 78,
        player: '维尼修斯',
        team: 'home',
        description: '反击破门',
      },
    ],
  };

  ctx.response.body = {
    success: true,
    data: matchDetail,
  };
});

// 获取单个新闻详情
router.get('/api/v1/news/:id', async (ctx) => {
  try {
    const id = ctx.params.id;
    if (!id) {
      ctx.response.status = 400;
      ctx.response.body = {
        success: false,
        error: {
          code: 'MISSING_ID',
          message: '缺少新闻ID',
        },
      };
      return;
    }

    const params = ctx.request.url.searchParams;
    const translate = params.get('translate') !== 'false';
    const language = params.get('language') || 'zh-CN';

    const detail = await aiNewsService.getNewsDetail(id, {
      translate,
      language,
    });

    ctx.response.body = {
      success: true,
      data: {
        id: detail.id,
        title: detail.title,
        summary: detail.summary,
        source: detail.source,
        category: detail.category,
        publishedAt: detail.publishedAt,
        readCount: detail.readCount,
        imageUrl: detail.imageUrl,
        content: detail.content,
        aiMeta: detail.aiMeta,
        originalTitle: detail.originalTitle,
        originalSummary: detail.originalSummary,
        originalContent: detail.originalContent,
        translatedContent: detail.translatedContent,
      },
      meta: {
        translated: translate && detail.aiMeta.isTranslated,
        language,
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : '未知错误';
    const notFound = message.includes('不存在');

    ctx.response.status = notFound ? 404 : 500;
    ctx.response.body = {
      success: false,
      error: {
        code: notFound ? 'NEWS_NOT_FOUND' : 'AI_NEWS_DETAIL_ERROR',
        message: notFound
          ? '未找到指定新闻'
          : '获取新闻详情失败，请稍后再试',
      },
    };
  }
});

// 用户登录API
router.post('/api/v1/auth/login', async (ctx) => {
  const body = await ctx.request.body().value;

  // 简单的模拟登录验证
  if (body.email && body.password) {
    // 模拟验证过程
    await new Promise((resolve) => setTimeout(resolve, 500));

    ctx.response.status = 200;
    ctx.response.body = {
      success: true,
      data: {
        user: {
          id: crypto.randomUUID(),
          username: body.email.split('@')[0],
          email: body.email,
          avatar: null,
          nickname: body.email.split('@')[0],
          level: 1,
          createdAt: new Date().toISOString(),
        },
        token: 'mock-jwt-token-' + Date.now(),
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } else {
    ctx.response.status = 400;
    ctx.response.body = {
      success: false,
      error: {
        code: 'INVALID_CREDENTIALS',
        message: '邮箱或密码不能为空',
      },
    };
  }
});

// 测试API - 用户注册
router.post('/api/v1/auth/register', async (ctx) => {
  const body = await ctx.request.body().value;

  // 简单的模拟注册验证
  if (body.username && body.email && body.password) {
    // 模拟注册过程
    await new Promise((resolve) => setTimeout(resolve, 800));

    ctx.response.status = 201;
    ctx.response.body = {
      success: true,
      data: {
        user: {
          id: crypto.randomUUID(),
          username: body.username,
          email: body.email,
          avatar: null,
          nickname: body.username,
          level: 1,
          createdAt: new Date().toISOString(),
        },
        token: 'mock-jwt-token-' + Date.now(),
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } else {
    ctx.response.status = 400;
    ctx.response.body = {
      success: false,
      error: {
        code: 'INVALID_INPUT',
        message: '用户名、邮箱和密码都不能为空',
      },
    };
  }
});

function clampNumber(value: number, min: number, max: number): number {
  if (Number.isNaN(value)) return min;
  return Math.max(min, Math.min(max, value));
}

function mapCategory(value: string): AiNewsListOptions['category'] {
  const allowed: Array<AiNewsListOptions['category']> = [
    'all',
    'news',
    'transfer',
    'match',
    'analysis',
    'rumor',
    'injury',
  ];

  return allowed.includes(value as AiNewsListOptions['category'])
    ? value as AiNewsListOptions['category']
    : 'all';
}

// 启动服务器
async function startServer() {
  try {
    // 连接数据库
    logger.info('正在连接数据库...');
    await dbManager.connect();

    // 初始化数据库表结构
    logger.info('正在初始化数据库...');
    await initializeDatabase(dbManager);

    // 连接Redis（可选）
    try {
      logger.info('正在连接Redis...');
      await redisManager.connect();
    } catch (error) {
      logger.warn('Redis连接失败，继续使用内存缓存', {
        error: error instanceof Error ? error.message : String(error),
      });
    }

    // 启动HTTP服务器
    logger.info('启动球探社后端服务...', {
      environment: config.env,
      port: config.port,
    });

    await app.listen({ port: config.port });
  } catch (error) {
    logger.error('服务启动失败', error instanceof Error ? error : new Error(String(error)));
    Deno.exit(1);
  }
}

// 优雅关闭
async function gracefulShutdown() {
  logger.info('正在关闭服务...');

  try {
    await dbManager.disconnect();
    await redisManager.disconnect();
    logger.info('服务已安全关闭');
  } catch (error) {
    logger.error('关闭服务时出错', error instanceof Error ? error : new Error(String(error)));
  }

  Deno.exit(0);
}

// 监听关闭信号
Deno.addSignalListener('SIGTERM', gracefulShutdown);
Deno.addSignalListener('SIGINT', gracefulShutdown);

// 启动服务
if (import.meta.main) {
  await startServer();
}
