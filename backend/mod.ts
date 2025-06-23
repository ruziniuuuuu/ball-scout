import { Application, Router, oakCors, load, log } from './deps.ts';

// 加载环境变量
await load({ export: true });

// 应用配置
const config = {
  port: parseInt(Deno.env.get('PORT') || '8000'),
  env: Deno.env.get('NODE_ENV') || 'development',
};

// 初始化日志
await log.setup({
  handlers: {
    console: new log.handlers.ConsoleHandler('DEBUG'),
  },
  loggers: {
    default: {
      level: 'DEBUG',
      handlers: ['console'],
    },
  },
});

const logger = log.getLogger();

// 创建Oak应用
const app = new Application();

// 全局错误处理
app.use(async (ctx, next) => {
  try {
    await next();
  } catch (error) {
    logger.error('请求处理错误:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: config.env === 'production' ? '服务器内部错误' : error.message,
      },
    };
  }
});

// CORS中间件
app.use(oakCors({
  origin: true,
  credentials: true,
}));

// 请求日志中间件
app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  const duration = Date.now() - start;
  logger.info(`${ctx.request.method} ${ctx.request.url.pathname} - ${ctx.response.status} - ${duration}ms`);
});

// 创建基础路由
const router = new Router();

// 健康检查
router.get('/health', (ctx) => {
  ctx.response.body = {
    success: true,
    data: {
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
      message: '球探社后端服务运行正常 ⚽',
    },
  };
});

// 测试API - 获取模拟新闻数据
router.get('/api/v1/news', (ctx) => {
  const mockNews = [
    {
      id: '1',
      title: '皇马签下新星前锋',
      summary: '皇马官方宣布签下年仅19岁的巴西新星前锋...',
      source: 'ESPN',
      category: 'transfer',
      publishedAt: new Date().toISOString(),
      readCount: 1205,
    },
    {
      id: '2', 
      title: '欧冠八强对阵出炉',
      summary: '2024年欧冠八强抽签结果公布，精彩对决即将上演...',
      source: 'UEFA',
      category: 'match',
      publishedAt: new Date().toISOString(),
      readCount: 2350,
    },
    {
      id: '3',
      title: 'C罗创造新纪录',
      summary: '葡萄牙巨星C罗在昨晚的比赛中再次创造历史...',
      source: 'Goal.com',
      category: 'news',
      publishedAt: new Date().toISOString(),
      readCount: 5678,
    },
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

// 测试API - 用户注册
router.post('/api/v1/auth/register', async (ctx) => {
  const body = await ctx.request.body().value;
  
  ctx.response.status = 201;
  ctx.response.body = {
    success: true,
    data: {
      user: {
        id: crypto.randomUUID(),
        username: body.username || '测试用户',
        email: body.email || 'test@example.com',
      },
      token: 'mock-jwt-token',
    },
    meta: {
      timestamp: new Date().toISOString(),
    },
  };
});

// API文档
router.get('/api', (ctx) => {
  ctx.response.body = {
    message: '🏆 球探社 API 文档',
    version: '1.0.0',
    endpoints: {
      'GET /health': '健康检查',
      'GET /api/v1/news': '获取新闻列表',
      'POST /api/v1/auth/register': '用户注册',
    },
    example: {
      news: 'curl http://localhost:8000/api/v1/news',
      register: 'curl -X POST http://localhost:8000/api/v1/auth/register -H "Content-Type: application/json" -d \'{"username":"test","email":"test@example.com","password":"123456"}\'',
    },
  };
});

// 注册路由
app.use(router.routes());
app.use(router.allowedMethods());

// 404处理
app.use((ctx) => {
  ctx.response.status = 404;
  ctx.response.body = {
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: '请求的资源不存在',
    },
  };
});

// 启动应用
async function startServer() {
  try {
    logger.info(`🚀 球探社后端服务启动成功`);
    logger.info(`🌐 服务地址: http://localhost:${config.port}`);
    logger.info(`📖 API文档: http://localhost:${config.port}/api`);
    logger.info(`💚 健康检查: http://localhost:${config.port}/health`);
    logger.info(`🛠️ 运行环境: ${config.env}`);
    
    await app.listen({ port: config.port });
  } catch (error) {
    logger.error('服务启动失败:', error);
    Deno.exit(1);
  }
}

// 优雅关闭处理
function setupGracefulShutdown() {
  const shutdown = async () => {
    logger.info('正在关闭服务...');
    logger.info('服务已关闭');
    Deno.exit(0);
  };

  // 监听终止信号
  Deno.addSignalListener('SIGINT', shutdown);
  Deno.addSignalListener('SIGTERM', shutdown);
}

// 启动应用
if (import.meta.main) {
  setupGracefulShutdown();
  await startServer();
} 