import { Application, Router, oakCors, load, log } from './deps.ts';
import { DatabaseManager, RedisManager, initializeDatabase } from './shared/db.ts';
import { AppConfig, ServiceError } from './shared/types.ts';

// 导入服务路由
import { newsRouter } from './services/news/router.ts';
import { userRouter } from './services/user/router.ts';

// 加载环境变量
await load({ export: true });

// 应用配置
const config: AppConfig = {
  port: parseInt(Deno.env.get('PORT') || '8000'),
  env: (Deno.env.get('NODE_ENV') || 'development') as 'development' | 'staging' | 'production',
  database: {
    host: Deno.env.get('DB_HOST') || 'localhost',
    port: parseInt(Deno.env.get('DB_PORT') || '5432'),
    database: Deno.env.get('DB_NAME') || 'ball_scout',
    username: Deno.env.get('DB_USER') || 'postgres',
    password: Deno.env.get('DB_PASSWORD') || 'password',
  },
  jwt: {
    secret: Deno.env.get('JWT_SECRET') || 'your-secret-key',
    expiresIn: Deno.env.get('JWT_EXPIRES_IN') || '7d',
  },
  redis: {
    host: Deno.env.get('REDIS_HOST') || 'localhost',
    port: parseInt(Deno.env.get('REDIS_PORT') || '6379'),
    password: Deno.env.get('REDIS_PASSWORD'),
  },
  ai: {
    openaiApiKey: Deno.env.get('OPENAI_API_KEY'),
    claudeApiKey: Deno.env.get('CLAUDE_API_KEY'),
    tongYiApiKey: Deno.env.get('TONGYI_API_KEY'),
  },
};

// 初始化日志
await log.setup({
  handlers: {
    console: new log.handlers.ConsoleHandler('DEBUG'),
  },
  loggers: {
    default: {
      level: config.env === 'production' ? 'INFO' : 'DEBUG',
      handlers: ['console'],
    },
  },
});

const logger = log.getLogger();

// 初始化数据库连接
const db = new DatabaseManager(config.database);
const redis = new RedisManager(config.redis);

// 创建Oak应用
const app = new Application();

// 全局错误处理
app.use(async (ctx, next) => {
  try {
    await next();
  } catch (error) {
    logger.error('请求处理错误:', error);
    
    if (error instanceof ServiceError) {
      ctx.response.status = error.statusCode;
      ctx.response.body = {
        success: false,
        error: {
          code: error.code,
          message: error.message,
          details: error.details,
        },
      };
    } else {
      ctx.response.status = 500;
      ctx.response.body = {
        success: false,
        error: {
          code: 'INTERNAL_SERVER_ERROR',
          message: config.env === 'production' ? '服务器内部错误' : error.message,
        },
      };
    }
  }
});

// CORS中间件
app.use(oakCors({
  origin: config.env === 'production' 
    ? ['https://ballscout.app', 'https://www.ballscout.app']
    : true,
  credentials: true,
}));

// 请求日志中间件
app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  const duration = Date.now() - start;
  logger.info(`${ctx.request.method} ${ctx.request.url.pathname} - ${ctx.response.status} - ${duration}ms`);
});

// 健康检查
const healthRouter = new Router();
healthRouter.get('/health', (ctx) => {
  ctx.response.body = {
    success: true,
    data: {
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: '1.0.0',
    },
  };
});

// 注册路由
app.use(healthRouter.routes());
app.use(healthRouter.allowedMethods());

// 将数据库连接添加到上下文
app.use(async (ctx, next) => {
  ctx.state.db = db;
  ctx.state.redis = redis;
  ctx.state.config = config;
  await next();
});

// 注册业务路由
app.use(newsRouter.routes());
app.use(newsRouter.allowedMethods());
app.use(userRouter.routes());
app.use(userRouter.allowedMethods());

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
    // 连接数据库
    await db.connect();
    await redis.connect();
    
    // 初始化数据库表
    await initializeDatabase(db);
    
    // 启动HTTP服务器
    logger.info(`🚀 球探社后端服务启动成功`);
    logger.info(`🌐 服务地址: http://localhost:${config.port}`);
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
    await db.disconnect();
    await redis.disconnect();
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