import { Application, Router } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { oakCors } from 'https://deno.land/x/cors@v1.2.2/mod.ts';
import { config, validateConfig } from './config.ts';
import { DatabaseManager, RedisManager, initializeDatabase } from './shared/db.ts';

// 引入各个服务路由
import enhancedNewsRouter from './services/news/enhanced-router.ts';
import { userRouter } from './services/user/router.ts';
import communityRouter from './services/community/router.ts';
import translationRouter from './services/translation/router.ts';

// 验证配置
validateConfig();

// 创建应用实例
const app = new Application();
const router = new Router();

// 初始化数据库连接
const dbManager = new DatabaseManager(config.database);
const redisManager = new RedisManager(config.redis);

// 错误处理中间件
app.use(async (ctx, next) => {
  try {
    await next();
  } catch (error) {
    console.error('❌ 服务器错误:', error);
    
    ctx.response.status = error.statusCode || 500;
    ctx.response.body = {
      success: false,
      error: {
        code: error.code || 'INTERNAL_ERROR',
        message: config.env === 'production' ? '服务器内部错误' : (error as Error).message,
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  }
});

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
  const ms = Date.now() - start;
  console.log(`${ctx.request.method} ${ctx.request.url.pathname} - ${ctx.response.status} (${ms}ms)`);
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

// 兼容旧的模拟API接口
router.get('/api/v1/news', (ctx) => {
  const mockNews = [
    {
      id: '1',
      title: '皇马签下新星前锋',
      summary: '皇马官方宣布签下年仅19岁的巴西新星前锋，转会费高达8000万欧元。这位年轻球员在上赛季表现出色，被誉为下一个巴西传奇。',
      source: 'ESPN',
      category: 'transfer',
      publishedAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      readCount: 1205,
      imageUrl: null,
      content: '皇马官方宣布签下年仅19岁的巴西新星前锋...',
    },
    {
      id: '2', 
      title: '欧冠八强对阵出炉',
      summary: '2024年欧冠八强抽签结果公布，精彩对决即将上演。曼城对阵巴萨，皇马遭遇拜仁，这些经典对决让球迷期待不已。',
      source: 'UEFA',
      category: 'match',
      publishedAt: new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString(),
      readCount: 2350,
      imageUrl: null,
      content: '2024年欧冠八强抽签结果公布...',
    },
    {
      id: '3',
      title: 'C罗创造新纪录',
      summary: '葡萄牙巨星C罗在昨晚的比赛中再次创造历史，成为首位在5届欧洲杯中都有进球的球员。这一纪录彰显了他的持久性和伟大性。',
      source: 'Goal.com',
      category: 'news',
      publishedAt: new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString(),
      readCount: 5678,
      imageUrl: null,
      content: '葡萄牙巨星C罗在昨晚的比赛中再次创造历史...',
    },
    {
      id: '4',
      title: '梅西状态分析：年龄不是问题',
      summary: '尽管已经37岁，梅西在迈阿密国际的表现依然出色。专家分析认为，他的球技和视野没有丝毫衰退迹象。',
      source: '体坛周报',
      category: 'analysis',
      publishedAt: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(),
      readCount: 3421,
      imageUrl: null,
      content: '尽管已经37岁，梅西在迈阿密国际的表现依然出色...',
    },
    {
      id: '5',
      title: '英超积分榜更新',
      summary: '英超第30轮战罢，曼城继续领跑积分榜，阿森纳紧随其后。利物浦和切尔西之间的争夺也异常激烈。',
      source: 'BBC Sport',
      category: 'match',
      publishedAt: new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString(),
      readCount: 1876,
      imageUrl: null,
      content: '英超第30轮战罢，曼城继续领跑积分榜...',
    }
  ];

  ctx.response.body = {
    success: true,
    data: mockNews,
    meta: {
      total: mockNews.length,
      timestamp: new Date().toISOString(),
    },
  };
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
      matchTime: new Date(targetDate.getTime() + 2 * 60 * 60 * 1000).toISOString(),
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
          description: '点球破门'
        },
        {
          id: '2',
          type: 'goal',
          minute: 45,
          player: '梅西',
          team: 'away',
          description: '任意球直接破门'
        },
        {
          id: '3',
          type: 'goal',
          minute: 78,
          player: '维尼修斯',
          team: 'home',
          description: '反击破门'
        }
      ]
    },
    {
      id: '2',
      homeTeam: '曼城',
      awayTeam: '利物浦',
      homeTeamLogo: '',
      awayTeamLogo: '',
      homeScore: 1,
      awayScore: 1,
      matchTime: new Date(targetDate.getTime() + 4 * 60 * 60 * 1000).toISOString(),
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
          description: '近距离推射'
        },
        {
          id: '5',
          type: 'goal',
          minute: 56,
          player: '萨拉赫',
          team: 'away',
          description: '单刀破门'
        }
      ]
    },
    {
      id: '3',
      homeTeam: '拜仁慕尼黑',
      awayTeam: '多特蒙德',
      homeTeamLogo: '',
      awayTeamLogo: '',
      homeScore: null,
      awayScore: null,
      matchTime: new Date(targetDate.getTime() + 6 * 60 * 60 * 1000).toISOString(),
      status: 'scheduled',
      competition: '德甲',
      venue: '安联球场',
      minute: null,
      events: []
    },
    {
      id: '4',
      homeTeam: 'AC米兰',
      awayTeam: '国际米兰',
      homeTeamLogo: '',
      awayTeamLogo: '',
      homeScore: null,
      awayScore: null,
      matchTime: new Date(targetDate.getTime() + 24 * 60 * 60 * 1000).toISOString(),
      status: 'scheduled',
      competition: '意甲',
      venue: '圣西罗球场',
      minute: null,
      events: []
    }
  ];

  // 根据日期筛选比赛
  const filteredMatches = mockMatches.filter(match => {
    const matchDate = new Date(match.matchTime);
    return matchDate.toDateString() === targetDate.toDateString();
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
        description: '点球破门'
      },
      {
        id: '2',
        type: 'goal',
        minute: 45,
        player: '梅西',
        team: 'away',
        description: '任意球直接破门'
      },
      {
        id: '3',
        type: 'goal',
        minute: 78,
        player: '维尼修斯',
        team: 'home',
        description: '反击破门'
      }
    ]
  };

  ctx.response.body = {
    success: true,
    data: matchDetail,
  };
});

// 获取单个新闻详情
router.get('/api/v1/news/:id', (ctx) => {
  const id = ctx.params.id;
  
  // 模拟新闻详情数据
  const newsDetail = {
    id,
    title: '皇马签下新星前锋',
    summary: '皇马官方宣布签下年仅19岁的巴西新星前锋，转会费高达8000万欧元。',
    source: 'ESPN',
    category: 'transfer',
    publishedAt: new Date().toISOString(),
    readCount: 1205,
    imageUrl: null,
    content: `
      <h2>皇马官宣签下巴西新星</h2>
      <p>皇家马德里俱乐部今日官方宣布，成功签下年仅19岁的巴西前锋新星，转会费高达8000万欧元，合同期至2029年。</p>
      
      <h3>球员特点</h3>
      <p>这位年轻球员身高1米85，司职中锋，也可胜任边锋位置。他拥有出色的射门技术和突破能力，被誉为巴西足球的未来之星。</p>
      
      <h3>教练评价</h3>
      <p>皇马主教练安切洛蒂表示："他是一名非常有天赋的年轻球员，我相信他会为皇马带来更多进球和胜利。"</p>
      
      <h3>转会详情</h3>
      <p>据悉，这笔转会谈判历时3个月，皇马击败了巴萨、曼城等多家豪门的竞争。球员将于下周正式加盟球队，参加新赛季的训练。</p>
    `,
  };

  ctx.response.body = {
    success: true,
    data: newsDetail,
  };
});

// 用户登录API
router.post('/api/v1/auth/login', async (ctx) => {
  const body = await ctx.request.body().value;
  
  // 简单的模拟登录验证
  if (body.email && body.password) {
    // 模拟验证过程
    await new Promise(resolve => setTimeout(resolve, 500));
    
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
    await new Promise(resolve => setTimeout(resolve, 800));
    
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

// 启动服务器
async function startServer() {
  try {
    // 连接数据库
    console.log('🔌 正在连接数据库...');
    await dbManager.connect();
    
    // 初始化数据库表结构
    console.log('🚀 正在初始化数据库...');
    await initializeDatabase(dbManager);
    
    // 连接Redis（可选）
    try {
      console.log('🔌 正在连接Redis...');
      await redisManager.connect();
    } catch (error) {
      console.warn('⚠️  Redis连接失败，继续使用内存缓存:', error.message);
    }
    
    // 启动HTTP服务器
    console.log('🚀 启动球探社后端服务...');
    console.log(`🛠️  运行环境: ${config.env}`);
    console.log(`🌐 服务地址: http://localhost:${config.port}`);
    console.log(`📡 API文档: http://localhost:${config.port}/api`);
    console.log(`💚 健康检查: http://localhost:${config.port}/health`);
    
    await app.listen({ port: config.port });
  } catch (error) {
    console.error('❌ 服务启动失败:', error);
    Deno.exit(1);
  }
}

// 优雅关闭
async function gracefulShutdown() {
  console.log('\n📴 正在关闭服务...');
  
  try {
    await dbManager.disconnect();
    await redisManager.disconnect();
    console.log('✅ 服务已安全关闭');
  } catch (error) {
    console.error('❌ 关闭服务时出错:', error);
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