/**
 * WebSocket 实时通信服务
 *
 * 提供实时功能：
 * - 比赛实时更新
 * - 评论实时同步
 * - 用户状态同步
 * - 系统通知推送
 */

import {
  WebSocket,
  WebSocketServer,
} from 'https://deno.land/x/websocket@v0.1.4/mod.ts';
import { DatabaseManager } from '../../shared/db.ts';
import { RedisManager } from '../../shared/db.ts';

export interface WebSocketMessage {
  type: string;
  data: any;
  timestamp: string;
  userId?: string;
  channel?: string;
}

export interface ClientConnection {
  id: string;
  ws: WebSocket;
  userId?: string;
  channels: Set<string>;
  lastActivity: Date;
  metadata: Record<string, any>;
}

export interface LiveMatchUpdate {
  matchId: string;
  homeScore: number;
  awayScore: number;
  status: string;
  minute?: number;
  events: LiveEvent[];
}

export interface LiveEvent {
  id: string;
  type: 'goal' | 'card' | 'substitution' | 'penalty' | 'var' | 'injury';
  minute: number;
  playerName: string;
  teamSide: 'home' | 'away';
  description: string;
  isKeyEvent: boolean;
}

export interface CommentUpdate {
  articleId: string;
  comment: {
    id: string;
    content: string;
    author: {
      id: string;
      username: string;
      avatar: string;
    };
    createdAt: string;
    parentId?: string;
  };
}

export class WebSocketService {
  private clients = new Map<string, ClientConnection>();
  private channels = new Map<string, Set<string>>(); // channel -> client IDs
  private db: DatabaseManager;
  private redis: RedisManager;
  private heartbeatInterval: number;
  private cleanupInterval: number;

  constructor(db: DatabaseManager, redis: RedisManager) {
    this.db = db;
    this.redis = redis;
    this.heartbeatInterval = setInterval(() => this.heartbeat(), 30000); // 30秒心跳
    this.cleanupInterval = setInterval(() => this.cleanup(), 60000); // 1分钟清理
  }

  /**
   * 处理新的WebSocket连接
   */
  async handleConnection(ws: WebSocket, request: Request): Promise<void> {
    const clientId = crypto.randomUUID();
    const url = new URL(request.url);
    const token = url.searchParams.get('token');

    let userId: string | undefined;

    // 验证token获取用户信息
    if (token) {
      try {
        userId = await this.validateToken(token);
      } catch (error) {
        console.warn('WebSocket token validation failed:', error);
      }
    }

    const client: ClientConnection = {
      id: clientId,
      ws,
      userId,
      channels: new Set(),
      lastActivity: new Date(),
      metadata: {
        connectedAt: new Date().toISOString(),
        userAgent: request.headers.get('User-Agent'),
      },
    };

    this.clients.set(clientId, client);

    console.log(
      `🔌 WebSocket客户端已连接: ${clientId} ${
        userId ? `(用户: ${userId})` : '(匿名)'
      }`,
    );

    // 发送连接确认
    await this.sendToClient(clientId, {
      type: 'connection_established',
      data: {
        clientId,
        userId,
        serverTime: new Date().toISOString(),
      },
      timestamp: new Date().toISOString(),
    });

    // 设置消息处理
    for await (const message of ws) {
      if (typeof message === 'string') {
        try {
          const data = JSON.parse(message);
          await this.handleMessage(clientId, data);
        } catch (error) {
          console.error('WebSocket消息解析失败:', error);
          await this.sendError(
            clientId,
            'INVALID_MESSAGE_FORMAT',
            '消息格式无效',
          );
        }
      }
    }

    // 连接断开清理
    this.handleDisconnection(clientId);
  }

  /**
   * 处理客户端消息
   */
  private async handleMessage(clientId: string, message: any): Promise<void> {
    const client = this.clients.get(clientId);
    if (!client) return;

    client.lastActivity = new Date();

    try {
      switch (message.type) {
        case 'join_channel':
          await this.handleJoinChannel(clientId, message.data);
          break;
        case 'leave_channel':
          await this.handleLeaveChannel(clientId, message.data);
          break;
        case 'ping':
          await this.handlePing(clientId);
          break;
        case 'subscribe_match':
          await this.handleSubscribeMatch(clientId, message.data);
          break;
        case 'subscribe_comments':
          await this.handleSubscribeComments(clientId, message.data);
          break;
        case 'send_typing':
          await this.handleTyping(clientId, message.data);
          break;
        default:
          console.warn('未知WebSocket消息类型:', message.type);
          await this.sendError(
            clientId,
            'UNKNOWN_MESSAGE_TYPE',
            '未知消息类型',
          );
      }
    } catch (error) {
      console.error('处理WebSocket消息失败:', error);
      await this.sendError(
        clientId,
        'MESSAGE_PROCESSING_ERROR',
        '消息处理失败',
      );
    }
  }

  /**
   * 处理加入频道
   */
  private async handleJoinChannel(
    clientId: string,
    data: { channel: string },
  ): Promise<void> {
    const client = this.clients.get(clientId);
    if (!client || !data.channel) return;

    const channelName = data.channel;

    // 验证频道权限
    if (!await this.validateChannelAccess(client.userId, channelName)) {
      await this.sendError(
        clientId,
        'CHANNEL_ACCESS_DENIED',
        '没有访问该频道的权限',
      );
      return;
    }

    // 加入频道
    client.channels.add(channelName);

    if (!this.channels.has(channelName)) {
      this.channels.set(channelName, new Set());
    }
    this.channels.get(channelName)!.add(clientId);

    console.log(`📻 客户端 ${clientId} 加入频道: ${channelName}`);

    await this.sendToClient(clientId, {
      type: 'channel_joined',
      data: { channel: channelName },
      timestamp: new Date().toISOString(),
    });

    // 广播用户加入信息（如果是聊天频道）
    if (channelName.startsWith('chat:')) {
      await this.broadcastToChannel(channelName, {
        type: 'user_joined',
        data: {
          userId: client.userId,
          channel: channelName,
        },
        timestamp: new Date().toISOString(),
      }, clientId);
    }
  }

  /**
   * 处理离开频道
   */
  private async handleLeaveChannel(
    clientId: string,
    data: { channel: string },
  ): Promise<void> {
    const client = this.clients.get(clientId);
    if (!client || !data.channel) return;

    const channelName = data.channel;

    client.channels.delete(channelName);
    this.channels.get(channelName)?.delete(clientId);

    // 如果频道没有客户端了，删除频道
    if (this.channels.get(channelName)?.size === 0) {
      this.channels.delete(channelName);
    }

    console.log(`📻 客户端 ${clientId} 离开频道: ${channelName}`);

    await this.sendToClient(clientId, {
      type: 'channel_left',
      data: { channel: channelName },
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * 处理心跳
   */
  private async handlePing(clientId: string): Promise<void> {
    await this.sendToClient(clientId, {
      type: 'pong',
      data: { serverTime: new Date().toISOString() },
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * 处理比赛订阅
   */
  private async handleSubscribeMatch(
    clientId: string,
    data: { matchId: string },
  ): Promise<void> {
    const channelName = `match:${data.matchId}`;
    await this.handleJoinChannel(clientId, { channel: channelName });

    // 发送当前比赛状态
    const matchData = await this.getCurrentMatchData(data.matchId);
    if (matchData) {
      await this.sendToClient(clientId, {
        type: 'match_state',
        data: matchData,
        timestamp: new Date().toISOString(),
      });
    }
  }

  /**
   * 处理评论订阅
   */
  private async handleSubscribeComments(
    clientId: string,
    data: { articleId: string },
  ): Promise<void> {
    const channelName = `comments:${data.articleId}`;
    await this.handleJoinChannel(clientId, { channel: channelName });
  }

  /**
   * 处理输入状态
   */
  private async handleTyping(
    clientId: string,
    data: { articleId: string; isTyping: boolean },
  ): Promise<void> {
    const client = this.clients.get(clientId);
    if (!client || !client.userId) return;

    const channelName = `comments:${data.articleId}`;

    await this.broadcastToChannel(channelName, {
      type: 'user_typing',
      data: {
        userId: client.userId,
        articleId: data.articleId,
        isTyping: data.isTyping,
      },
      timestamp: new Date().toISOString(),
    }, clientId);
  }

  /**
   * 发送消息到特定客户端
   */
  async sendToClient(
    clientId: string,
    message: WebSocketMessage,
  ): Promise<boolean> {
    const client = this.clients.get(clientId);
    if (!client || client.ws.readyState !== WebSocket.OPEN) {
      return false;
    }

    try {
      await client.ws.send(JSON.stringify(message));
      return true;
    } catch (error) {
      console.error(`发送消息到客户端 ${clientId} 失败:`, error);
      this.handleDisconnection(clientId);
      return false;
    }
  }

  /**
   * 广播消息到频道
   */
  async broadcastToChannel(
    channelName: string,
    message: WebSocketMessage,
    excludeClientId?: string,
  ): Promise<number> {
    const clientIds = this.channels.get(channelName);
    if (!clientIds) return 0;

    let sentCount = 0;
    const promises: Promise<boolean>[] = [];

    for (const clientId of clientIds) {
      if (clientId !== excludeClientId) {
        promises.push(this.sendToClient(clientId, {
          ...message,
          channel: channelName,
        }));
      }
    }

    const results = await Promise.allSettled(promises);
    results.forEach((result) => {
      if (result.status === 'fulfilled' && result.value) {
        sentCount++;
      }
    });

    console.log(
      `📡 向频道 ${channelName} 广播消息，成功发送 ${sentCount}/${results.length}`,
    );
    return sentCount;
  }

  /**
   * 推送比赛更新
   */
  async pushMatchUpdate(update: LiveMatchUpdate): Promise<void> {
    const channelName = `match:${update.matchId}`;

    // 保存到数据库
    await this.saveMatchUpdate(update);

    // 广播更新
    await this.broadcastToChannel(channelName, {
      type: 'match_update',
      data: update,
      timestamp: new Date().toISOString(),
    });

    // 如果有关键事件，推送通知
    const keyEvents = update.events.filter((event) => event.isKeyEvent);
    if (keyEvents.length > 0) {
      await this.pushMatchNotifications(update.matchId, keyEvents);
    }
  }

  /**
   * 推送评论更新
   */
  async pushCommentUpdate(update: CommentUpdate): Promise<void> {
    const channelName = `comments:${update.articleId}`;

    await this.broadcastToChannel(channelName, {
      type: 'comment_added',
      data: update,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * 推送系统通知
   */
  async pushNotification(userId: string, notification: any): Promise<void> {
    // 找到用户的所有连接
    const userClients = Array.from(this.clients.entries())
      .filter(([_, client]) => client.userId === userId)
      .map(([clientId, _]) => clientId);

    for (const clientId of userClients) {
      await this.sendToClient(clientId, {
        type: 'notification',
        data: notification,
        timestamp: new Date().toISOString(),
      });
    }
  }

  /**
   * 发送错误消息
   */
  private async sendError(
    clientId: string,
    code: string,
    message: string,
  ): Promise<void> {
    await this.sendToClient(clientId, {
      type: 'error',
      data: { code, message },
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * 验证Token
   */
  private async validateToken(token: string): Promise<string> {
    // 这里应该实现JWT token验证逻辑
    // 暂时返回模拟的用户ID
    if (token === 'mock-token') {
      return 'mock-user-id';
    }
    throw new Error('Invalid token');
  }

  /**
   * 验证频道访问权限
   */
  private async validateChannelAccess(
    userId: string | undefined,
    channel: string,
  ): Promise<boolean> {
    // 公共频道允许所有人访问
    if (
      channel.startsWith('public:') || channel.startsWith('match:') ||
      channel.startsWith('comments:')
    ) {
      return true;
    }

    // 用户特定频道需要认证
    if (channel.startsWith('user:') && userId) {
      const expectedUserId = channel.split(':')[1];
      return userId === expectedUserId;
    }

    // 管理员频道需要管理员权限
    if (channel.startsWith('admin:')) {
      return await this.isAdmin(userId);
    }

    return false;
  }

  /**
   * 检查是否为管理员
   */
  private async isAdmin(userId: string | undefined): Promise<boolean> {
    if (!userId) return false;

    try {
      const result = await this.db.query(
        'SELECT role FROM users WHERE id = $1',
        [userId],
      );
      return result.rows[0]?.role === 'admin';
    } catch {
      return false;
    }
  }

  /**
   * 获取当前比赛数据
   */
  private async getCurrentMatchData(
    matchId: string,
  ): Promise<LiveMatchUpdate | null> {
    try {
      const result = await this.db.query(
        `
        SELECT 
          m.id,
          m.home_score,
          m.away_score,
          m.status,
          ht.name as home_team,
          at.name as away_team,
          m.statistics
        FROM matches m
        LEFT JOIN teams ht ON m.home_team_id = ht.id
        LEFT JOIN teams at ON m.away_team_id = at.id
        WHERE m.id = $1
      `,
        [matchId],
      );

      if (result.rows.length === 0) return null;

      const match = result.rows[0];

      // 获取实时事件
      const eventsResult = await this.db.query(
        `
        SELECT * FROM live_events 
        WHERE match_id = $1 
        ORDER BY timestamp DESC
      `,
        [matchId],
      );

      const events: LiveEvent[] = eventsResult.rows.map((row) => ({
        id: row.id,
        type: row.event_type,
        minute: row.minute,
        playerName: row.player_name,
        teamSide: row.team_side,
        description: row.description,
        isKeyEvent: row.is_key_event,
      }));

      return {
        matchId,
        homeScore: match.home_score || 0,
        awayScore: match.away_score || 0,
        status: match.status,
        minute: match.statistics?.currentMinute,
        events,
      };
    } catch (error) {
      console.error('获取比赛数据失败:', error);
      return null;
    }
  }

  /**
   * 保存比赛更新
   */
  private async saveMatchUpdate(update: LiveMatchUpdate): Promise<void> {
    try {
      // 更新比赛分数
      await this.db.query(
        `
        UPDATE matches 
        SET home_score = $1, away_score = $2, status = $3, updated_at = NOW()
        WHERE id = $4
      `,
        [update.homeScore, update.awayScore, update.status, update.matchId],
      );

      // 保存新事件
      for (const event of update.events) {
        await this.db.query(
          `
          INSERT INTO live_events (
            id, match_id, event_type, minute, player_name, 
            team_side, description, is_key_event
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
          ON CONFLICT (id) DO UPDATE SET
            description = EXCLUDED.description,
            is_key_event = EXCLUDED.is_key_event
        `,
          [
            event.id,
            update.matchId,
            event.type,
            event.minute,
            event.playerName,
            event.teamSide,
            event.description,
            event.isKeyEvent,
          ],
        );
      }
    } catch (error) {
      console.error('保存比赛更新失败:', error);
    }
  }

  /**
   * 推送比赛通知
   */
  private async pushMatchNotifications(
    matchId: string,
    events: LiveEvent[],
  ): Promise<void> {
    // 获取关注该比赛球队的用户
    try {
      const result = await this.db.query(
        `
        SELECT DISTINCT tf.user_id
        FROM team_follows tf
        JOIN matches m ON tf.team_id IN (m.home_team_id, m.away_team_id)
        WHERE m.id = $1 AND tf.notification_enabled = true
      `,
        [matchId],
      );

      const notificationPromises = result.rows.map(async (row) => {
        for (const event of events) {
          await this.pushNotification(row.user_id, {
            title: `比赛更新`,
            content: event.description,
            type: 'match',
            matchId,
            eventType: event.type,
          });
        }
      });

      await Promise.allSettled(notificationPromises);
    } catch (error) {
      console.error('推送比赛通知失败:', error);
    }
  }

  /**
   * 心跳检测
   */
  private async heartbeat(): Promise<void> {
    const pingPromises: Promise<boolean>[] = [];

    for (const [clientId, client] of this.clients) {
      if (client.ws.readyState === WebSocket.OPEN) {
        pingPromises.push(this.sendToClient(clientId, {
          type: 'ping',
          data: { serverTime: new Date().toISOString() },
          timestamp: new Date().toISOString(),
        }));
      }
    }

    const results = await Promise.allSettled(pingPromises);
    const activeCount =
      results.filter((r) => r.status === 'fulfilled' && r.value).length;

    console.log(
      `💓 心跳检测完成，活跃连接: ${activeCount}/${this.clients.size}`,
    );
  }

  /**
   * 清理无效连接
   */
  private cleanup(): void {
    const now = new Date();
    const inactiveThreshold = 5 * 60 * 1000; // 5分钟无活动
    const clientsToRemove: string[] = [];

    for (const [clientId, client] of this.clients) {
      // 连接已关闭或长时间无活动
      if (
        client.ws.readyState !== WebSocket.OPEN ||
        (now.getTime() - client.lastActivity.getTime()) > inactiveThreshold
      ) {
        clientsToRemove.push(clientId);
      }
    }

    for (const clientId of clientsToRemove) {
      this.handleDisconnection(clientId);
    }

    if (clientsToRemove.length > 0) {
      console.log(`🧹 清理了 ${clientsToRemove.length} 个无效连接`);
    }
  }

  /**
   * 处理连接断开
   */
  private handleDisconnection(clientId: string): void {
    const client = this.clients.get(clientId);
    if (!client) return;

    // 从所有频道中移除
    for (const channelName of client.channels) {
      this.channels.get(channelName)?.delete(clientId);

      // 如果频道为空，删除频道
      if (this.channels.get(channelName)?.size === 0) {
        this.channels.delete(channelName);
      }
    }

    // 移除客户端
    this.clients.delete(clientId);

    console.log(
      `🔌 WebSocket客户端已断开: ${clientId} ${
        client.userId ? `(用户: ${client.userId})` : '(匿名)'
      }`,
    );
  }

  /**
   * 获取连接统计
   */
  getStats() {
    return {
      totalConnections: this.clients.size,
      authenticatedConnections:
        Array.from(this.clients.values()).filter((c) => c.userId).length,
      totalChannels: this.channels.size,
      channels: Object.fromEntries(
        Array.from(this.channels.entries()).map((
          [name, clients],
        ) => [name, clients.size]),
      ),
    };
  }

  /**
   * 关闭服务
   */
  async close(): Promise<void> {
    clearInterval(this.heartbeatInterval);
    clearInterval(this.cleanupInterval);

    // 通知所有客户端服务即将关闭
    const promises: Promise<boolean>[] = [];
    for (const [clientId] of this.clients) {
      promises.push(this.sendToClient(clientId, {
        type: 'server_shutdown',
        data: { message: '服务器即将关闭' },
        timestamp: new Date().toISOString(),
      }));
    }

    await Promise.allSettled(promises);

    // 关闭所有连接
    for (const [clientId, client] of this.clients) {
      try {
        await client.ws.close();
      } catch {
        // 忽略关闭错误
      }
    }

    this.clients.clear();
    this.channels.clear();

    console.log('🔌 WebSocket服务已关闭');
  }
}
