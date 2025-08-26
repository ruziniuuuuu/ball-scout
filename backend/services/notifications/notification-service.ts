/**
 * 通知服务
 *
 * 提供多种通知功能：
 * - 系统通知
 * - 比赛更新通知
 * - 评论回复通知
 * - 关注更新通知
 * - 推送通知管理
 */

import { DatabaseManager } from '../../shared/db.ts';
import { RedisManager } from '../../shared/db.ts';

export interface Notification {
  id: string;
  userId: string;
  title: string;
  content: string;
  type: 'news' | 'match' | 'system' | 'social' | 'achievement';
  actionUrl?: string;
  isRead: boolean;
  priority: 'low' | 'normal' | 'high' | 'urgent';
  metadata: Record<string, any>;
  expiresAt?: Date;
  createdAt: Date;
}

export interface NotificationTemplate {
  id: string;
  name: string;
  title: string;
  content: string;
  type: string;
  variables: string[];
  isActive: boolean;
}

export interface PushSubscription {
  userId: string;
  endpoint: string;
  auth: string;
  p256dh: string;
  userAgent?: string;
  isActive: boolean;
  createdAt: Date;
}

export class NotificationService {
  private db: DatabaseManager;
  private redis: RedisManager;
  private templates = new Map<string, NotificationTemplate>();

  constructor(db: DatabaseManager, redis: RedisManager) {
    this.db = db;
    this.redis = redis;
    this.initializeTemplates();
  }

  /**
   * 初始化通知模板
   */
  private initializeTemplates() {
    const templates: NotificationTemplate[] = [
      {
        id: 'match_goal',
        name: '比赛进球通知',
        title: '⚽ {{homeTeam}} vs {{awayTeam}} - 进球！',
        content:
          '{{playerName}} 在第 {{minute}} 分钟为 {{teamName}} 打入一球！当前比分 {{homeScore}}:{{awayScore}}',
        type: 'match',
        variables: [
          'homeTeam',
          'awayTeam',
          'playerName',
          'minute',
          'teamName',
          'homeScore',
          'awayScore',
        ],
        isActive: true,
      },
      {
        id: 'match_card',
        name: '比赛红黄牌通知',
        title: '{{cardType}} {{homeTeam}} vs {{awayTeam}}',
        content: '{{playerName}} 在第 {{minute}} 分钟收到{{cardType}}',
        type: 'match',
        variables: ['cardType', 'homeTeam', 'awayTeam', 'playerName', 'minute'],
        isActive: true,
      },
      {
        id: 'comment_reply',
        name: '评论回复通知',
        title: '💬 有人回复了你的评论',
        content:
          '{{username}} 回复了你在《{{articleTitle}}》的评论：{{replyContent}}',
        type: 'social',
        variables: ['username', 'articleTitle', 'replyContent'],
        isActive: true,
      },
      {
        id: 'news_breaking',
        name: '重要新闻通知',
        title: '📰 重要新闻',
        content: '{{title}}',
        type: 'news',
        variables: ['title', 'summary'],
        isActive: true,
      },
      {
        id: 'team_follow',
        name: '关注球队更新',
        title: '🔔 {{teamName}} 有新动态',
        content: '{{content}}',
        type: 'news',
        variables: ['teamName', 'content'],
        isActive: true,
      },
      {
        id: 'user_achievement',
        name: '用户成就通知',
        title: '🏆 恭喜解锁新成就！',
        content: '你获得了「{{achievementName}}」成就！{{description}}',
        type: 'achievement',
        variables: ['achievementName', 'description'],
        isActive: true,
      },
    ];

    templates.forEach((template) => {
      this.templates.set(template.id, template);
    });
  }

  /**
   * 创建通知
   */
  async createNotification(
    userId: string,
    title: string,
    content: string,
    type: Notification['type'],
    options: {
      actionUrl?: string;
      priority?: Notification['priority'];
      metadata?: Record<string, any>;
      expiresAt?: Date;
    } = {},
  ): Promise<string> {
    const notificationId = crypto.randomUUID();

    try {
      await this.db.query(
        `
        INSERT INTO notifications (
          id, user_id, title, content, type, action_url, 
          priority, metadata, expires_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      `,
        [
          notificationId,
          userId,
          title,
          content,
          type,
          options.actionUrl || null,
          options.priority || 'normal',
          JSON.stringify(options.metadata || {}),
          options.expiresAt || null,
        ],
      );

      // 缓存最新通知
      await this.cacheUserNotification(userId, notificationId);

      console.log(`📬 为用户 ${userId} 创建通知: ${title}`);

      return notificationId;
    } catch (error) {
      console.error('创建通知失败:', error);
      throw error;
    }
  }

  /**
   * 使用模板创建通知
   */
  async createNotificationFromTemplate(
    templateId: string,
    userId: string,
    variables: Record<string, string>,
    options: {
      actionUrl?: string;
      priority?: Notification['priority'];
      metadata?: Record<string, any>;
      expiresAt?: Date;
    } = {},
  ): Promise<string> {
    const template = this.templates.get(templateId);
    if (!template || !template.isActive) {
      throw new Error(`通知模板 ${templateId} 不存在或已禁用`);
    }

    // 替换模板变量
    let title = template.title;
    let content = template.content;

    for (const [key, value] of Object.entries(variables)) {
      const placeholder = `{{${key}}}`;
      title = title.replace(new RegExp(placeholder, 'g'), value);
      content = content.replace(new RegExp(placeholder, 'g'), value);
    }

    return await this.createNotification(
      userId,
      title,
      content,
      template.type as Notification['type'],
      {
        ...options,
        metadata: {
          ...options.metadata,
          templateId,
          variables,
        },
      },
    );
  }

  /**
   * 批量创建通知
   */
  async createBulkNotifications(
    userIds: string[],
    title: string,
    content: string,
    type: Notification['type'],
    options: {
      actionUrl?: string;
      priority?: Notification['priority'];
      metadata?: Record<string, any>;
      expiresAt?: Date;
    } = {},
  ): Promise<string[]> {
    const notificationIds: string[] = [];
    const batchSize = 100; // 批处理大小

    for (let i = 0; i < userIds.length; i += batchSize) {
      const batch = userIds.slice(i, i + batchSize);
      const promises = batch.map((userId) =>
        this.createNotification(userId, title, content, type, options)
      );

      const results = await Promise.allSettled(promises);
      results.forEach((result) => {
        if (result.status === 'fulfilled') {
          notificationIds.push(result.value);
        }
      });
    }

    console.log(
      `📬 批量创建通知完成: ${notificationIds.length}/${userIds.length}`,
    );
    return notificationIds;
  }

  /**
   * 获取用户通知列表
   */
  async getUserNotifications(
    userId: string,
    options: {
      limit?: number;
      offset?: number;
      unreadOnly?: boolean;
      type?: string;
    } = {},
  ): Promise<{
    notifications: Notification[];
    total: number;
    unreadCount: number;
  }> {
    const limit = options.limit || 20;
    const offset = options.offset || 0;

    let whereClause = 'WHERE user_id = $1';
    const queryParams: any[] = [userId];
    let paramIndex = 2;

    if (options.unreadOnly) {
      whereClause += ` AND is_read = false`;
    }

    if (options.type) {
      whereClause += ` AND type = $${paramIndex}`;
      queryParams.push(options.type);
      paramIndex++;
    }

    // 获取通知列表
    const notificationsResult = await this.db.query(
      `
      SELECT * FROM notifications 
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `,
      [...queryParams, limit, offset],
    );

    // 获取总数
    const totalResult = await this.db.query(
      `
      SELECT COUNT(*) as total FROM notifications ${whereClause}
    `,
      queryParams,
    );

    // 获取未读数量
    const unreadResult = await this.db.query(
      `
      SELECT COUNT(*) as unread_count FROM notifications 
      WHERE user_id = $1 AND is_read = false
    `,
      [userId],
    );

    const notifications: Notification[] = notificationsResult.rows.map(
      (row) => ({
        id: row.id,
        userId: row.user_id,
        title: row.title,
        content: row.content,
        type: row.type,
        actionUrl: row.action_url,
        isRead: row.is_read,
        priority: row.priority,
        metadata: row.metadata || {},
        expiresAt: row.expires_at ? new Date(row.expires_at) : undefined,
        createdAt: new Date(row.created_at),
      }),
    );

    return {
      notifications,
      total: parseInt(totalResult.rows[0].total),
      unreadCount: parseInt(unreadResult.rows[0].unread_count),
    };
  }

  /**
   * 标记通知为已读
   */
  async markAsRead(notificationId: string, userId: string): Promise<boolean> {
    try {
      const result = await this.db.query(
        `
        UPDATE notifications 
        SET is_read = true 
        WHERE id = $1 AND user_id = $2 AND is_read = false
      `,
        [notificationId, userId],
      );

      if (result.rowCount && result.rowCount > 0) {
        // 更新缓存
        await this.updateUserNotificationCache(userId);
        return true;
      }
      return false;
    } catch (error) {
      console.error('标记通知已读失败:', error);
      return false;
    }
  }

  /**
   * 批量标记通知为已读
   */
  async markMultipleAsRead(
    notificationIds: string[],
    userId: string,
  ): Promise<number> {
    try {
      const result = await this.db.query(
        `
        UPDATE notifications 
        SET is_read = true 
        WHERE id = ANY($1) AND user_id = $2 AND is_read = false
      `,
        [notificationIds, userId],
      );

      const updatedCount = result.rowCount || 0;
      if (updatedCount > 0) {
        await this.updateUserNotificationCache(userId);
      }

      return updatedCount;
    } catch (error) {
      console.error('批量标记通知已读失败:', error);
      return 0;
    }
  }

  /**
   * 标记所有通知为已读
   */
  async markAllAsRead(userId: string): Promise<number> {
    try {
      const result = await this.db.query(
        `
        UPDATE notifications 
        SET is_read = true 
        WHERE user_id = $1 AND is_read = false
      `,
        [userId],
      );

      const updatedCount = result.rowCount || 0;
      if (updatedCount > 0) {
        await this.updateUserNotificationCache(userId);
      }

      return updatedCount;
    } catch (error) {
      console.error('标记所有通知已读失败:', error);
      return 0;
    }
  }

  /**
   * 删除通知
   */
  async deleteNotification(
    notificationId: string,
    userId: string,
  ): Promise<boolean> {
    try {
      const result = await this.db.query(
        `
        DELETE FROM notifications 
        WHERE id = $1 AND user_id = $2
      `,
        [notificationId, userId],
      );

      if (result.rowCount && result.rowCount > 0) {
        await this.updateUserNotificationCache(userId);
        return true;
      }
      return false;
    } catch (error) {
      console.error('删除通知失败:', error);
      return false;
    }
  }

  /**
   * 创建比赛事件通知
   */
  async createMatchEventNotification(
    matchId: string,
    eventType: string,
    eventData: Record<string, any>,
  ): Promise<void> {
    try {
      // 获取关注相关球队的用户
      const followersResult = await this.db.query(
        `
        SELECT DISTINCT tf.user_id
        FROM team_follows tf
        JOIN matches m ON tf.team_id IN (m.home_team_id, m.away_team_id)
        WHERE m.id = $1 AND tf.notification_enabled = true
      `,
        [matchId],
      );

      if (followersResult.rows.length === 0) return;

      const userIds = followersResult.rows.map((row) => row.user_id);
      let templateId: string;

      // 根据事件类型选择模板
      switch (eventType) {
        case 'goal':
          templateId = 'match_goal';
          break;
        case 'card':
          templateId = 'match_card';
          break;
        default:
          return; // 不支持的事件类型
      }

      // 批量创建通知
      const promises = userIds.map((userId) =>
        this.createNotificationFromTemplate(templateId, userId, eventData, {
          actionUrl: `/match/${matchId}`,
          priority: 'high',
          metadata: { matchId, eventType },
        })
      );

      await Promise.allSettled(promises);

      console.log(
        `📬 为 ${userIds.length} 个用户创建比赛事件通知: ${eventType}`,
      );
    } catch (error) {
      console.error('创建比赛事件通知失败:', error);
    }
  }

  /**
   * 创建评论回复通知
   */
  async createCommentReplyNotification(
    originalCommentUserId: string,
    replyData: {
      username: string;
      articleTitle: string;
      articleId: string;
      replyContent: string;
      commentId: string;
    },
  ): Promise<void> {
    try {
      await this.createNotificationFromTemplate(
        'comment_reply',
        originalCommentUserId,
        replyData,
        {
          actionUrl:
            `/article/${replyData.articleId}#comment-${replyData.commentId}`,
          priority: 'normal',
          metadata: {
            articleId: replyData.articleId,
            commentId: replyData.commentId,
          },
        },
      );
    } catch (error) {
      console.error('创建评论回复通知失败:', error);
    }
  }

  /**
   * 创建球队新闻通知
   */
  async createTeamNewsNotification(
    teamId: string,
    newsData: {
      teamName: string;
      title: string;
      articleId: string;
    },
  ): Promise<void> {
    try {
      // 获取关注该球队的用户
      const followersResult = await this.db.query(
        `
        SELECT user_id FROM team_follows 
        WHERE team_id = $1 AND notification_enabled = true
      `,
        [teamId],
      );

      if (followersResult.rows.length === 0) return;

      const userIds = followersResult.rows.map((row) => row.user_id);

      const promises = userIds.map((userId) =>
        this.createNotificationFromTemplate(
          'team_follow',
          userId,
          {
            teamName: newsData.teamName,
            content: newsData.title,
          },
          {
            actionUrl: `/article/${newsData.articleId}`,
            priority: 'normal',
            metadata: {
              teamId,
              articleId: newsData.articleId,
            },
          },
        )
      );

      await Promise.allSettled(promises);

      console.log(
        `📬 为 ${userIds.length} 个用户创建球队新闻通知: ${newsData.teamName}`,
      );
    } catch (error) {
      console.error('创建球队新闻通知失败:', error);
    }
  }

  /**
   * 缓存用户通知
   */
  private async cacheUserNotification(
    userId: string,
    notificationId: string,
  ): Promise<void> {
    try {
      const cacheKey = `user_notifications:${userId}`;
      await this.redis.lpush(cacheKey, notificationId);
      await this.redis.ltrim(cacheKey, 0, 99); // 保留最新100条
      await this.redis.expire(cacheKey, 3600); // 1小时过期
    } catch (error) {
      console.error('缓存用户通知失败:', error);
    }
  }

  /**
   * 更新用户通知缓存
   */
  private async updateUserNotificationCache(userId: string): Promise<void> {
    try {
      const cacheKey = `user_notifications:${userId}`;
      await this.redis.del(cacheKey); // 清除缓存，下次查询时重新构建
    } catch (error) {
      console.error('更新用户通知缓存失败:', error);
    }
  }

  /**
   * 清理过期通知
   */
  async cleanupExpiredNotifications(): Promise<number> {
    try {
      const result = await this.db.query(`
        DELETE FROM notifications 
        WHERE expires_at IS NOT NULL AND expires_at < NOW()
      `);

      const deletedCount = result.rowCount || 0;
      if (deletedCount > 0) {
        console.log(`🧹 清理了 ${deletedCount} 个过期通知`);
      }

      return deletedCount;
    } catch (error) {
      console.error('清理过期通知失败:', error);
      return 0;
    }
  }

  /**
   * 获取通知统计信息
   */
  async getNotificationStats(): Promise<{
    totalNotifications: number;
    unreadNotifications: number;
    notificationsByType: Record<string, number>;
    dailyNotifications: number;
  }> {
    try {
      const [totalResult, unreadResult, typeResult, dailyResult] = await Promise
        .all([
          this.db.query('SELECT COUNT(*) as total FROM notifications'),
          this.db.query(
            'SELECT COUNT(*) as unread FROM notifications WHERE is_read = false',
          ),
          this.db.query(`
          SELECT type, COUNT(*) as count 
          FROM notifications 
          GROUP BY type
        `),
          this.db.query(`
          SELECT COUNT(*) as daily 
          FROM notifications 
          WHERE created_at >= CURRENT_DATE
        `),
        ]);

      const notificationsByType: Record<string, number> = {};
      typeResult.rows.forEach((row) => {
        notificationsByType[row.type] = parseInt(row.count);
      });

      return {
        totalNotifications: parseInt(totalResult.rows[0].total),
        unreadNotifications: parseInt(unreadResult.rows[0].unread),
        notificationsByType,
        dailyNotifications: parseInt(dailyResult.rows[0].daily),
      };
    } catch (error) {
      console.error('获取通知统计失败:', error);
      return {
        totalNotifications: 0,
        unreadNotifications: 0,
        notificationsByType: {},
        dailyNotifications: 0,
      };
    }
  }
}
