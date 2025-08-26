import { Client, ClientOptions, connect } from '../deps.ts';
import { DatabaseConfig } from './types.ts';

// PostgreSQL数据库连接管理
export class DatabaseManager {
  private client: Client | null = null;
  private config: ClientOptions;

  constructor(config: DatabaseConfig) {
    this.config = {
      hostname: config.host,
      port: config.port,
      database: config.database,
      user: config.username,
      password: config.password,
    };
  }

  async connect(): Promise<void> {
    try {
      this.client = new Client(this.config);
      await this.client.connect();
      console.log('✅ PostgreSQL数据库连接成功');
    } catch (error) {
      console.error('❌ PostgreSQL数据库连接失败:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.end();
      this.client = null;
      console.log('📴 PostgreSQL数据库连接已关闭');
    }
  }

  getClient(): Client {
    if (!this.client) {
      throw new Error('数据库连接尚未建立，请先调用connect()方法');
    }
    return this.client;
  }

  async query(sql: string, params?: unknown[]): Promise<any> {
    const client = this.getClient();
    return await client.queryObject(sql, params);
  }

  async transaction<T>(callback: (client: Client) => Promise<T>): Promise<T> {
    const client = this.getClient();
    await client.queryObject('BEGIN');

    try {
      const result = await callback(client);
      await client.queryObject('COMMIT');
      return result;
    } catch (error) {
      await client.queryObject('ROLLBACK');
      throw error;
    }
  }
}

// Redis缓存连接管理
export class RedisManager {
  private redis: any = null;
  private config: {
    hostname: string;
    port: number;
    password?: string;
  };

  constructor(config: { host: string; port: number; password?: string }) {
    this.config = {
      hostname: config.host,
      port: config.port,
      password: config.password,
    };
  }

  async connect(): Promise<void> {
    try {
      this.redis = await connect(this.config);
      console.log('✅ Redis缓存连接成功');
    } catch (error) {
      console.error('❌ Redis缓存连接失败:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.redis) {
      this.redis.close();
      this.redis = null;
      console.log('📴 Redis缓存连接已关闭');
    }
  }

  getClient() {
    if (!this.redis) {
      throw new Error('Redis连接尚未建立，请先调用connect()方法');
    }
    return this.redis;
  }

  async get(key: string): Promise<string | null> {
    const client = this.getClient();
    return await client.get(key);
  }

  async set(key: string, value: string, ttl?: number): Promise<void> {
    const client = this.getClient();
    if (ttl) {
      await client.setex(key, ttl, value);
    } else {
      await client.set(key, value);
    }
  }

  async del(key: string): Promise<void> {
    const client = this.getClient();
    await client.del(key);
  }

  async exists(key: string): Promise<boolean> {
    const client = this.getClient();
    const result = await client.exists(key);
    return result === 1;
  }
}

// 数据库初始化脚本
export const initializeDatabase = async (
  db: DatabaseManager,
): Promise<void> => {
  const schemas = [
    // 用户表
    `CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      username VARCHAR(50) UNIQUE NOT NULL,
      email VARCHAR(255) UNIQUE NOT NULL,
      password_hash VARCHAR(255) NOT NULL,
      avatar VARCHAR(500),
      role VARCHAR(20) DEFAULT 'user',
      preferences JSONB DEFAULT '{}',
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )`,

    // 球队表
    `CREATE TABLE IF NOT EXISTS teams (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      name VARCHAR(100) NOT NULL,
      name_en VARCHAR(100),
      league VARCHAR(100),
      country VARCHAR(50),
      logo_url VARCHAR(500),
      founded_year INTEGER,
      stadium VARCHAR(200),
      website VARCHAR(500),
      social_media JSONB DEFAULT '{}',
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )`,

    // 新闻文章表
    `CREATE TABLE IF NOT EXISTS news_articles (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      title VARCHAR(500) NOT NULL,
      content TEXT,
      summary TEXT,
      source VARCHAR(100) NOT NULL,
      author VARCHAR(100),
      published_at TIMESTAMP,
      category VARCHAR(50) NOT NULL,
      language VARCHAR(10) DEFAULT 'en',
      translation_zh TEXT,
      tags TEXT[] DEFAULT '{}',
      image_url VARCHAR(500),
      read_count INTEGER DEFAULT 0,
      sentiment_score DECIMAL(3,2),
      reliability INTEGER DEFAULT 5,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )`,

    // 比赛表
    `CREATE TABLE IF NOT EXISTS matches (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      home_team_id UUID REFERENCES teams(id),
      away_team_id UUID REFERENCES teams(id),
      home_score INTEGER,
      away_score INTEGER,
      status VARCHAR(20) DEFAULT 'scheduled',
      kickoff_time TIMESTAMP NOT NULL,
      venue VARCHAR(200),
      league VARCHAR(100),
      season VARCHAR(20),
      matchweek INTEGER,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )`,

    // 评论表
    `CREATE TABLE IF NOT EXISTS comments (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id UUID REFERENCES users(id) ON DELETE CASCADE,
      article_id UUID REFERENCES news_articles(id) ON DELETE CASCADE,
      match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
      content TEXT NOT NULL,
      parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
      likes INTEGER DEFAULT 0,
      dislikes INTEGER DEFAULT 0,
      is_deleted BOOLEAN DEFAULT FALSE,
      created_at TIMESTAMP DEFAULT NOW(),
      updated_at TIMESTAMP DEFAULT NOW()
    )`,

    // 创建索引
    `CREATE INDEX IF NOT EXISTS idx_news_articles_category ON news_articles(category)`,
    `CREATE INDEX IF NOT EXISTS idx_news_articles_published_at ON news_articles(published_at DESC)`,
    `CREATE INDEX IF NOT EXISTS idx_matches_kickoff_time ON matches(kickoff_time)`,
    `CREATE INDEX IF NOT EXISTS idx_comments_article_id ON comments(article_id)`,
    `CREATE INDEX IF NOT EXISTS idx_comments_user_id ON comments(user_id)`,
  ];

  console.log('🚀 开始初始化数据库...');

  for (const schema of schemas) {
    try {
      await db.query(schema);
    } catch (error) {
      console.error('❌ 数据库初始化失败:', error);
      throw error;
    }
  }

  console.log('✅ 数据库初始化完成');
};
