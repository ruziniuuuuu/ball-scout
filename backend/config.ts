// 球探社 - 生产配置文件
// 从环境变量加载敏感信息，提供合理的默认值

export const config = {
  // 服务端口
  port: parseInt(Deno.env.get('PORT') || '8000'),
  
  // 运行环境
  env: (Deno.env.get('NODE_ENV') || 'development') as 'development' | 'staging' | 'production',
  
  // 数据库配置
  database: {
    host: Deno.env.get('DB_HOST') || 'localhost',
    port: parseInt(Deno.env.get('DB_PORT') || '5432'),
    database: Deno.env.get('DB_NAME') || 'ball_scout',
    username: Deno.env.get('DB_USER') || 'postgres',
    password: Deno.env.get('DB_PASSWORD') || 'ballscout123',
  },
  
  // Redis配置
  redis: {
    host: Deno.env.get('REDIS_HOST') || 'localhost',
    port: parseInt(Deno.env.get('REDIS_PORT') || '6379'),
    password: Deno.env.get('REDIS_PASSWORD'),
  },
  
  // JWT配置
  jwt: {
    secret: Deno.env.get('JWT_SECRET') || 'ballscout-jwt-secret-key-2024',
    expiresIn: '7d',
  },
  
  // 🤖 AI翻译服务配置
  translation: {
    // Claude API (主力翻译)
    claude: {
      apiKey: Deno.env.get('CLAUDE_API_KEY'),
      model: 'claude-3-5-sonnet-20241022',
      maxTokens: 4000,
      temperature: 0.1,
    },
    
    // OpenAI API (备选翻译)
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
      maxSize: 10000,
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
      rateLimit: 100,
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
  
  // CORS配置
  cors: {
    origin: Deno.env.get('CORS_ORIGIN') || 'http://localhost:3000',
    credentials: true,
  },
  
  // 日志配置
  logging: {
    level: Deno.env.get('LOG_LEVEL') || 'INFO',
    format: 'json',
    outputs: ['console', 'file'],
  },
};

// 配置验证
export function validateConfig() {
  const requiredEnvVars = ['DB_PASSWORD', 'JWT_SECRET'];
  
  const missingVars = requiredEnvVars.filter(
    varName => !Deno.env.get(varName)
  );
  
  if (missingVars.length > 0) {
    console.warn('⚠️  部分环境变量未设置，使用默认值:', missingVars.join(', '));
    console.warn('💡 建议在生产环境中设置这些环境变量以确保安全性');
  }
  
  // AI翻译服务提醒
  if (!Deno.env.get('CLAUDE_API_KEY') && !Deno.env.get('OPENAI_API_KEY')) {
    console.warn('⚠️  未配置AI翻译API密钥，翻译功能将使用模拟数据');
  }
  
  console.log('✅ 配置验证完成');
}

// 导出类型定义
export type Config = typeof config; 