// 环境变量配置示例
// 复制此文件为 .env 并填入实际值

export const exampleConfig = {
  // 应用配置
  PORT: '8000',
  NODE_ENV: 'development',

  // 数据库配置
  DB_HOST: 'localhost',
  DB_PORT: '5432',
  DB_NAME: 'ball_scout',
  DB_USER: 'postgres',
  DB_PASSWORD: 'password',

  // Redis配置
  REDIS_HOST: 'localhost',
  REDIS_PORT: '6379',
  REDIS_PASSWORD: '',

  // JWT配置
  JWT_SECRET: 'your-super-secret-jwt-key-change-this-in-production',
  JWT_EXPIRES_IN: '7d',

  // AI API配置
  OPENAI_API_KEY: 'your-openai-api-key',
  CLAUDE_API_KEY: 'your-claude-api-key',
  TONGYI_API_KEY: 'your-tongyi-api-key',

  // 外部API配置
  SPORTRADAR_API_KEY: 'your-sportradar-api-key',
  ESPN_API_KEY: 'your-espn-api-key',
  TWITTER_API_KEY: 'your-twitter-api-key',
  TWITTER_API_SECRET: 'your-twitter-api-secret',

  // 日志配置
  LOG_LEVEL: 'DEBUG',
}; 