import { Client, ClientOptions, connect } from '../deps.ts';
import { DatabaseConfig } from './types.ts';
import { DatabaseError } from './errors.ts';
import { logger } from './logger.ts';

/**
 * PostgreSQL数据库连接管理
 * 
 * 提供连接池管理、查询执行、事务处理等功能
 */
export class DatabaseManager {
  private client: Client | null = null;
  private config: ClientOptions;
  private isConnected = false;

  constructor(config: DatabaseConfig) {
    this.config = {
      hostname: config.host,
      port: config.port,
      database: config.database,
      user: config.username,
      password: config.password,
      // 连接池配置
      connection: {
        attempts: 3,
        interval: 1000,
      },
    };
  }

  /**
   * 连接数据库
   */
  async connect(): Promise<void> {
    if (this.isConnected && this.client) {
      logger.warn('数据库已经连接');
      return;
    }

    try {
      this.client = new Client(this.config);
      await this.client.connect();
      this.isConnected = true;
      logger.info('PostgreSQL数据库连接成功');
    } catch (error) {
      this.isConnected = false;
      logger.error(
        'PostgreSQL数据库连接失败',
        error instanceof Error ? error : new Error(String(error)),
      );
      throw new DatabaseError(
        `数据库连接失败: ${error instanceof Error ? error.message : String(error)}`,
        error instanceof Error ? error : undefined,
      );
    }
  }

  /**
   * 断开数据库连接
   */
  async disconnect(): Promise<void> {
    if (this.client) {
      try {
        await this.client.end();
        this.isConnected = false;
        logger.info('PostgreSQL数据库连接已关闭');
      } catch (error) {
        logger.error('关闭数据库连接时出错', error instanceof Error ? error : new Error(String(error)));
      } finally {
        this.client = null;
      }
    }
  }

  /**
   * 检查连接状态
   */
  get connected(): boolean {
    return this.isConnected && this.client !== null;
  }

  /**
   * 获取数据库客户端
   */
  getClient(): Client {
    if (!this.client || !this.isConnected) {
      throw new DatabaseError('数据库连接尚未建立，请先调用connect()方法');
    }
    return this.client;
  }

  /**
   * 执行查询
   * 
   * @param sql SQL查询语句
   * @param params 查询参数（防止SQL注入）
   */
  async query(sql: string, params?: unknown[]): Promise<any> {
    if (!this.connected) {
      throw new DatabaseError('数据库未连接');
    }

    const client = this.getClient();
    
    try {
      // 参数验证
      if (params) {
        this.validateParams(params);
      }

      const startTime = Date.now();
      const result = await client.queryObject(sql, params);
      const duration = Date.now() - startTime;

      // 慢查询警告（超过1秒）
      if (duration > 1000) {
        logger.warn(`慢查询检测 (${duration}ms)`, {
          sql: sql.substring(0, 100),
        });
      } else {
        logger.logQuery(sql, duration, params);
      }

      return result;
    } catch (error) {
      logger.error('数据库查询失败', error instanceof Error ? error : new Error(String(error)), {
        sql: sql.substring(0, 200),
      });
      throw new DatabaseError(
        `查询执行失败: ${error instanceof Error ? error.message : String(error)}`,
        error instanceof Error ? error : undefined,
        { sql: sql.substring(0, 200) },
      );
    }
  }

  /**
   * 执行事务
   * 
   * @param callback 事务回调函数
   */
  async transaction<T>(callback: (client: Client) => Promise<T>): Promise<T> {
    if (!this.connected) {
      throw new DatabaseError('数据库未连接');
    }

    const client = this.getClient();
    
    try {
      await client.queryObject('BEGIN');
      const result = await callback(client);
      await client.queryObject('COMMIT');
      return result;
    } catch (error) {
      try {
        await client.queryObject('ROLLBACK');
      } catch (rollbackError) {
        logger.error('回滚事务失败', rollbackError instanceof Error ? rollbackError : new Error(String(rollbackError)));
      }
      throw new DatabaseError(
        `事务执行失败: ${error instanceof Error ? error.message : String(error)}`,
        error instanceof Error ? error : undefined,
      );
    }
  }

  /**
   * 参数验证
   */
  private validateParams(params: unknown[]): void {
    for (let i = 0; i < params.length; i++) {
      const param = params[i];
      
      // 检查字符串长度
      if (typeof param === 'string' && param.length > 100000) {
        throw new DatabaseError(`参数 ${i} 值过长 (${param.length} 字符)`);
      }
      
      // 检查数组大小
      if (Array.isArray(param) && param.length > 10000) {
        throw new DatabaseError(`参数 ${i} 数组过大 (${param.length} 元素)`);
      }
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
