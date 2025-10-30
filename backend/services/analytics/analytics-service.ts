/**
 * 速达足球分析服务
 *
 * 提供数据分析和统计功能：
 * - 用户行为分析
 * - 内容热度分析
 * - 趋势预测
 * - 性能监控
 */

import { DatabaseManager } from '../../shared/db.ts';
import { RedisManager } from '../../shared/db.ts';

export interface UserBehavior {
  userId: string;
  action: 'view' | 'like' | 'comment' | 'share' | 'search';
  targetType: 'news' | 'match' | 'user';
  targetId: string;
  timestamp: Date;
  metadata?: Record<string, unknown>;
}

export interface ContentAnalytics {
  contentId: string;
  contentType: 'news' | 'match';
  views: number;
  uniqueViews: number;
  likes: number;
  comments: number;
  shares: number;
  avgReadTime: number; // 秒
  engagementRate: number;
  lastUpdated: Date;
}

export interface TrendingItem {
  id: string;
  type: 'news' | 'match' | 'keyword';
  title: string;
  score: number;
  growth: number; // 增长率
  timeWindow: '1h' | '6h' | '24h' | '7d';
}

export interface UserInsights {
  userId: string;
  preferences: {
    favoriteCategories: string[];
    favoriteTeams: string[];
    readingTime: 'morning' | 'afternoon' | 'evening' | 'night';
    contentLanguage: string;
  };
  engagement: {
    totalViews: number;
    avgSessionDuration: number;
    returnVisits: number;
    lastActive: Date;
  };
  recommendations: string[];
}

export class AnalyticsService {
  private db: DatabaseManager;
  private redis: RedisManager;

  constructor(db: DatabaseManager, redis: RedisManager) {
    this.db = db;
    this.redis = redis;
  }

  /**
   * 记录用户行为
   */
  async trackUserBehavior(behavior: UserBehavior): Promise<void> {
    try {
      // 存储到数据库
      await this.db.query(
        `
        INSERT INTO user_behaviors (
          user_id, action, target_type, target_id, timestamp, metadata
        ) VALUES ($1, $2, $3, $4, $5, $6)
      `,
        [
          behavior.userId,
          behavior.action,
          behavior.targetType,
          behavior.targetId,
          behavior.timestamp,
          JSON.stringify(behavior.metadata || {}),
        ],
      );

      // 更新Redis缓存中的实时统计
      await this.updateRealTimeStats(behavior);

      console.log(
        `📊 用户行为已记录: ${behavior.userId} ${behavior.action} ${behavior.targetType}:${behavior.targetId}`,
      );
    } catch (error) {
      console.error('记录用户行为失败:', error);
      throw error;
    }
  }

  /**
   * 获取内容分析数据
   */
  async getContentAnalytics(
    contentId: string,
    timeRange = '7d',
  ): Promise<ContentAnalytics | null> {
    try {
      const result = await this.db.query(
        `
        SELECT 
          content_id,
          content_type,
          SUM(CASE WHEN action = 'view' THEN 1 ELSE 0 END) as views,
          COUNT(DISTINCT CASE WHEN action = 'view' THEN user_id END) as unique_views,
          SUM(CASE WHEN action = 'like' THEN 1 ELSE 0 END) as likes,
          SUM(CASE WHEN action = 'comment' THEN 1 ELSE 0 END) as comments,
          SUM(CASE WHEN action = 'share' THEN 1 ELSE 0 END) as shares,
          AVG(
            CASE 
              WHEN action = 'view' AND metadata->>'readTime' IS NOT NULL 
              THEN (metadata->>'readTime')::numeric 
            END
          ) as avg_read_time
        FROM user_behaviors 
        WHERE target_id = $1 
          AND timestamp >= NOW() - INTERVAL '${timeRange}'
        GROUP BY content_id, content_type
      `,
        [contentId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      const row = result.rows[0];
      const views = parseInt(row.views) || 0;
      const uniqueViews = parseInt(row.unique_views) || 0;
      const likes = parseInt(row.likes) || 0;
      const comments = parseInt(row.comments) || 0;
      const shares = parseInt(row.shares) || 0;

      // 计算参与度
      const engagementRate = views > 0
        ? (likes + comments + shares) / views
        : 0;

      return {
        contentId,
        contentType: row.content_type,
        views,
        uniqueViews,
        likes,
        comments,
        shares,
        avgReadTime: parseFloat(row.avg_read_time) || 0,
        engagementRate,
        lastUpdated: new Date(),
      };
    } catch (error) {
      console.error('获取内容分析失败:', error);
      return null;
    }
  }

  /**
   * 获取热门趋势
   */
  async getTrending(
    timeWindow: '1h' | '6h' | '24h' | '7d' = '24h',
    limit = 10,
  ): Promise<TrendingItem[]> {
    try {
      // 从Redis获取实时热门数据
      const cacheKey = `trending:${timeWindow}`;
      const cached = await this.redis.get(cacheKey);

      if (cached) {
        return JSON.parse(cached).slice(0, limit);
      }

      // 计算趋势分数
      const interval = this.getTimeInterval(timeWindow);
      const result = await this.db.query(
        `
        WITH trending_data AS (
          SELECT 
            target_id,
            target_type,
            COUNT(*) as activity_count,
            COUNT(DISTINCT user_id) as unique_users,
            MAX(timestamp) as last_activity
          FROM user_behaviors 
          WHERE timestamp >= NOW() - INTERVAL '${interval}'
          GROUP BY target_id, target_type
        ),
        content_info AS (
          SELECT 
            id,
            title,
            'news' as type
          FROM news_articles
          UNION ALL
          SELECT 
            id,
            CONCAT(home_team, ' vs ', away_team) as title,
            'match' as type
          FROM matches
        )
        SELECT 
          td.target_id as id,
          td.target_type as type,
          ci.title,
          (td.activity_count * 0.6 + td.unique_users * 0.4) as score,
          td.last_activity
        FROM trending_data td
        JOIN content_info ci ON td.target_id = ci.id AND td.target_type = ci.type
        ORDER BY score DESC
        LIMIT $1
      `,
        [limit],
      );

      const trending: TrendingItem[] = result.rows.map((row) => ({
        id: row.id,
        type: row.type,
        title: row.title,
        score: parseFloat(row.score),
        growth: 0, // 需要与之前时间段对比计算
        timeWindow,
      }));

      // 缓存结果5分钟
      await this.redis.setex(cacheKey, 300, JSON.stringify(trending));

      return trending;
    } catch (error) {
      console.error('获取热门趋势失败:', error);
      return [];
    }
  }

  /**
   * 获取用户洞察
   */
  async getUserInsights(userId: string): Promise<UserInsights | null> {
    try {
      // 获取用户偏好
      const preferencesResult = await this.db.query(
        `
        WITH user_categories AS (
          SELECT 
            JSON_EXTRACT_PATH_TEXT(metadata, 'category') as category,
            COUNT(*) as count
          FROM user_behaviors 
          WHERE user_id = $1 
            AND action = 'view' 
            AND target_type = 'news'
            AND JSON_EXTRACT_PATH_TEXT(metadata, 'category') IS NOT NULL
          GROUP BY category
          ORDER BY count DESC
          LIMIT 5
        ),
        user_teams AS (
          SELECT 
            JSON_EXTRACT_PATH_TEXT(metadata, 'team') as team,
            COUNT(*) as count
          FROM user_behaviors 
          WHERE user_id = $1 
            AND JSON_EXTRACT_PATH_TEXT(metadata, 'team') IS NOT NULL
          GROUP BY team
          ORDER BY count DESC
          LIMIT 5
        ),
        reading_time AS (
          SELECT 
            CASE 
              WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 6 AND 11 THEN 'morning'
              WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 12 AND 17 THEN 'afternoon'  
              WHEN EXTRACT(HOUR FROM timestamp) BETWEEN 18 AND 22 THEN 'evening'
              ELSE 'night'
            END as time_period,
            COUNT(*) as count
          FROM user_behaviors 
          WHERE user_id = $1 AND action = 'view'
          GROUP BY time_period
          ORDER BY count DESC
          LIMIT 1
        )
        SELECT 
          COALESCE(
            JSON_AGG(DISTINCT uc.category) FILTER (WHERE uc.category IS NOT NULL), 
            '[]'
          ) as favorite_categories,
          COALESCE(
            JSON_AGG(DISTINCT ut.team) FILTER (WHERE ut.team IS NOT NULL), 
            '[]'
          ) as favorite_teams,
          COALESCE(rt.time_period, 'evening') as reading_time
        FROM user_categories uc
        FULL OUTER JOIN user_teams ut ON true
        FULL OUTER JOIN reading_time rt ON true
      `,
        [userId],
      );

      // 获取参与度数据
      const engagementResult = await this.db.query(
        `
        SELECT 
          COUNT(DISTINCT CASE WHEN action = 'view' THEN target_id END) as total_views,
          COUNT(DISTINCT DATE(timestamp)) as active_days,
          MAX(timestamp) as last_active
        FROM user_behaviors 
        WHERE user_id = $1
      `,
        [userId],
      );

      if (
        preferencesResult.rows.length === 0 ||
        engagementResult.rows.length === 0
      ) {
        return null;
      }

      const prefRow = preferencesResult.rows[0];
      const engRow = engagementResult.rows[0];

      const insights: UserInsights = {
        userId,
        preferences: {
          favoriteCategories: JSON.parse(prefRow.favorite_categories || '[]'),
          favoriteTeams: JSON.parse(prefRow.favorite_teams || '[]'),
          readingTime: prefRow.reading_time,
          contentLanguage: 'zh-CN', // 默认中文
        },
        engagement: {
          totalViews: parseInt(engRow.total_views) || 0,
          avgSessionDuration: 0, // 需要额外计算
          returnVisits: parseInt(engRow.active_days) || 0,
          lastActive: new Date(engRow.last_active || Date.now()),
        },
        recommendations: [], // 基于偏好生成推荐
      };

      // 生成个性化推荐
      insights.recommendations = await this.generateRecommendations(insights);

      return insights;
    } catch (error) {
      console.error('获取用户洞察失败:', error);
      return null;
    }
  }

  /**
   * 获取系统性能指标
   */
  async getSystemMetrics(): Promise<{
    api: {
      totalRequests: number;
      avgResponseTime: number;
      errorRate: number;
    };
    content: {
      totalNews: number;
      translatedNews: number;
      dailyViews: number;
    };
    users: {
      totalUsers: number;
      activeUsers: number;
      newUsers: number;
    };
  }> {
    try {
      // API指标（从Redis获取）
      const apiMetrics = await this.getApiMetrics();

      // 内容指标
      const contentResult = await this.db.query(`
        SELECT 
          COUNT(*) as total_news,
          SUM(CASE WHEN translation_zh IS NOT NULL THEN 1 ELSE 0 END) as translated_news
        FROM news_articles
      `);

      const viewsResult = await this.db.query(`
        SELECT COUNT(*) as daily_views
        FROM user_behaviors 
        WHERE action = 'view' 
          AND timestamp >= CURRENT_DATE
      `);

      // 用户指标
      const usersResult = await this.db.query(`
        SELECT 
          COUNT(*) as total_users,
          COUNT(CASE WHEN last_active >= CURRENT_DATE - INTERVAL '7 days' THEN 1 END) as active_users,
          COUNT(CASE WHEN created_at >= CURRENT_DATE - INTERVAL '1 day' THEN 1 END) as new_users
        FROM users
      `);

      return {
        api: apiMetrics,
        content: {
          totalNews: parseInt(contentResult.rows[0]?.total_news) || 0,
          translatedNews: parseInt(contentResult.rows[0]?.translated_news) || 0,
          dailyViews: parseInt(viewsResult.rows[0]?.daily_views) || 0,
        },
        users: {
          totalUsers: parseInt(usersResult.rows[0]?.total_users) || 0,
          activeUsers: parseInt(usersResult.rows[0]?.active_users) || 0,
          newUsers: parseInt(usersResult.rows[0]?.new_users) || 0,
        },
      };
    } catch (error) {
      console.error('获取系统指标失败:', error);
      throw error;
    }
  }

  /**
   * 更新实时统计
   */
  private async updateRealTimeStats(behavior: UserBehavior): Promise<void> {
    const key =
      `stats:${behavior.targetType}:${behavior.targetId}:${behavior.action}`;
    await this.redis.incr(key);
    await this.redis.expire(key, 86400); // 24小时过期
  }

  /**
   * 获取时间间隔字符串
   */
  private getTimeInterval(timeWindow: string): string {
    switch (timeWindow) {
      case '1h':
        return '1 hour';
      case '6h':
        return '6 hours';
      case '24h':
        return '1 day';
      case '7d':
        return '7 days';
      default:
        return '1 day';
    }
  }

  /**
   * 获取API指标
   */
  private async getApiMetrics(): Promise<{
    totalRequests: number;
    avgResponseTime: number;
    errorRate: number;
  }> {
    try {
      const requests = parseInt(
        await this.redis.get('api:requests:today') || '0',
      );
      const responseTimeSum = parseInt(
        await this.redis.get('api:response_time:sum:today') || '0',
      );
      const errors = parseInt(await this.redis.get('api:errors:today') || '0');

      return {
        totalRequests: requests,
        avgResponseTime: requests > 0 ? responseTimeSum / requests : 0,
        errorRate: requests > 0 ? errors / requests : 0,
      };
    } catch (error) {
      return {
        totalRequests: 0,
        avgResponseTime: 0,
        errorRate: 0,
      };
    }
  }

  /**
   * 生成个性化推荐
   */
  private async generateRecommendations(
    insights: UserInsights,
  ): Promise<string[]> {
    const recommendations: string[] = [];

    // 基于偏好分类推荐
    if (insights.preferences.favoriteCategories.length > 0) {
      const categoryResult = await this.db.query(
        `
        SELECT id FROM news_articles 
        WHERE category = ANY($1)
          AND published_at >= NOW() - INTERVAL '3 days'
        ORDER BY read_count DESC, published_at DESC
        LIMIT 5
      `,
        [insights.preferences.favoriteCategories],
      );

      recommendations.push(...categoryResult.rows.map((row) => row.id));
    }

    // 基于喜欢的球队推荐
    if (insights.preferences.favoriteTeams.length > 0) {
      const teamResult = await this.db.query(
        `
        SELECT id FROM news_articles 
        WHERE tags && $1
          AND published_at >= NOW() - INTERVAL '3 days'
        ORDER BY importance_score DESC, published_at DESC
        LIMIT 3
      `,
        [insights.preferences.favoriteTeams],
      );

      recommendations.push(...teamResult.rows.map((row) => row.id));
    }

    // 去重并限制数量
    return [...new Set(recommendations)].slice(0, 10);
  }
}
