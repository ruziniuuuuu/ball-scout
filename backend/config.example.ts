// 环境变量配置示例
// 复制此文件为 config.ts 并填入实际值

export const config = {
  // 服务端口
  port: parseInt(Deno.env.get('PORT') || '8000'),
  
  // 运行环境
  env: Deno.env.get('NODE_ENV') || 'development',
  
  // 数据库配置
  database: {
    host: Deno.env.get('DB_HOST') || 'localhost',
    port: parseInt(Deno.env.get('DB_PORT') || '5432'),
    database: Deno.env.get('DB_NAME') || 'ball_scout',
    username: Deno.env.get('DB_USER') || 'postgres',
    password: Deno.env.get('DB_PASSWORD') || 'password',
  },
  
  // Redis配置
  redis: {
    host: Deno.env.get('REDIS_HOST') || 'localhost',
    port: parseInt(Deno.env.get('REDIS_PORT') || '6379'),
    password: Deno.env.get('REDIS_PASSWORD'),
  },
  
  // JWT配置
  jwt: {
    secret: Deno.env.get('JWT_SECRET') || 'your-secret-key',
    expiresIn: '7d',
  },
  
  // 🤖 AI翻译服务配置
  translation: {
    // DeepSeek API (主力翻译)
    deepseek: {
      apiKey: Deno.env.get('DEEPSEEK_API_KEY'), // 从环境变量获取
      model: 'deepseek-chat',
      maxTokens: 4000,
      temperature: 0.1,
      baseUrl: 'https://api.deepseek.com/v1/chat/completions',
    },
    
    // Claude API (备选翻译)
    claude: {
      apiKey: Deno.env.get('CLAUDE_API_KEY'),
      model: 'claude-3-5-sonnet-20241022',
      maxTokens: 4000,
      temperature: 0.1,
    },
    
    // OpenAI API (辅助翻译)
    openai: {
      apiKey: Deno.env.get('OPENAI_API_KEY'),
      model: 'gpt-4',
      maxTokens: 3000,
      temperature: 0.1,
    },
    
    // 通义千问 (本地化支持)
    qwen: {
      apiKey: Deno.env.get('QWEN_API_KEY'),
      model: 'qwen-plus',
      endpoint: 'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation',
    },
    
    // 缓存配置
    cache: {
      ttl: 24 * 60 * 60 * 1000, // 24小时
      maxSize: 10000, // 最大缓存条目数
    },
  },
  
  // 新闻聚合配置
  news: {
    sources: {
      bbc: {
        apiKey: Deno.env.get('BBC_API_KEY'),
        endpoint: 'https://api.bbc.co.uk/sport',
      },
      espn: {
        apiKey: Deno.env.get('ESPN_API_KEY'),
        endpoint: 'https://api.espn.com/v1/sports/soccer',
      },
      goal: {
        apiKey: Deno.env.get('GOAL_API_KEY'),
        endpoint: 'https://api.goal.com',
      },
    },
    
    // 爬虫配置
    crawler: {
      userAgent: 'BallScout/1.0 (+https://ballscout.com/bot)',
      timeout: 10000,
      retries: 3,
      rateLimit: 100, // 每分钟请求数
    },
  },
  
  // 体育数据API
  sports: {
    sofascore: {
      apiKey: Deno.env.get('SOFASCORE_API_KEY'),
      endpoint: 'https://api.sofascore.com/api/v1',
    },
    
    sportradar: {
      apiKey: Deno.env.get('SPORTRADAR_API_KEY'),
      endpoint: 'https://api.sportradar.us/soccer',
    },
  },
  
  // 推送通知
  push: {
    firebase: {
      serverKey: Deno.env.get('FIREBASE_SERVER_KEY'),
      projectId: Deno.env.get('FIREBASE_PROJECT_ID'),
    },
    
    apns: {
      keyId: Deno.env.get('APNS_KEY_ID'),
      teamId: Deno.env.get('APNS_TEAM_ID'),
      bundleId: 'com.ballscout.app',
    },
  },
  
  // 文件存储
  storage: {
    type: Deno.env.get('STORAGE_TYPE') || 'local', // local | s3 | aliyun
    
    local: {
      uploadPath: './uploads',
      publicPath: '/uploads',
    },
    
    s3: {
      accessKey: Deno.env.get('AWS_ACCESS_KEY_ID'),
      secretKey: Deno.env.get('AWS_SECRET_ACCESS_KEY'),
      region: Deno.env.get('AWS_REGION') || 'us-east-1',
      bucket: Deno.env.get('S3_BUCKET'),
    },
  },
  
  // 日志配置
  logging: {
    level: Deno.env.get('LOG_LEVEL') || 'INFO',
    format: 'json',
    outputs: ['console', 'file'],
  },
  
  // CORS配置
  cors: {
    origin: Deno.env.get('CORS_ORIGIN') || 'http://localhost:3000',
    credentials: true,
  },
  
  // 监控配置
  monitoring: {
    sentry: {
      dsn: Deno.env.get('SENTRY_DSN'),
    },
    
    prometheus: {
      enabled: Deno.env.get('PROMETHEUS_ENABLED') === 'true',
      port: parseInt(Deno.env.get('PROMETHEUS_PORT') || '9090'),
    },
  },
};

// 配置验证
export function validateConfig() {
  const requiredEnvVars = [
    'DB_PASSWORD',
    'JWT_SECRET',
  ];
  
  const missingVars = requiredEnvVars.filter(
    varName => !Deno.env.get(varName)
  );
  
  if (missingVars.length > 0) {
    console.error('❌ 缺少必需的环境变量:', missingVars.join(', '));
    console.error('💡 请检查 .env 文件或环境变量设置');
    Deno.exit(1);
  }
  
  // 翻译服务警告
  if (!Deno.env.get('DEEPSEEK_API_KEY') && !Deno.env.get('CLAUDE_API_KEY') && !Deno.env.get('OPENAI_API_KEY')) {
    console.warn('⚠️ 未配置翻译API密钥，翻译功能将不可用');
  } else if (Deno.env.get('DEEPSEEK_API_KEY')) {
    console.log('✅ DeepSeek API已配置（主力翻译服务）');
  }
  
  console.log('✅ 配置验证通过');
} 