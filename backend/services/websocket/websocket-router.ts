/**
 * WebSocket 路由处理
 *
 * 处理WebSocket连接请求和升级
 */

import { Router } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { Context } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { WebSocketService } from './websocket-server.ts';
import { DatabaseManager, RedisManager } from '../../shared/db.ts';
import {
  createErrorResponse,
  createSuccessResponse,
} from '../../shared/response.ts';

export class WebSocketRouter {
  private router: Router;
  private wsService: WebSocketService;

  constructor(db: DatabaseManager, redis: RedisManager) {
    this.router = new Router();
    this.wsService = new WebSocketService(db, redis);
    this.setupRoutes();
  }

  private setupRoutes() {
    // WebSocket升级端点
    this.router.get('/ws', async (ctx: Context) => {
      try {
        // 检查是否支持WebSocket升级
        const upgrade = ctx.request.headers.get('upgrade');
        if (upgrade !== 'websocket') {
          ctx.response.status = 400;
          ctx.response.body = createErrorResponse('WebSocket升级请求无效');
          return;
        }

        // 执行WebSocket升级
        const { socket, response } = Deno.upgradeWebSocket(ctx.request.raw);

        // 设置WebSocket事件处理
        socket.onopen = () => {
          console.log('WebSocket连接已建立');
        };

        socket.onmessage = async (event) => {
          try {
            await this.wsService.handleMessage(event);
          } catch (error) {
            console.error('WebSocket消息处理失败:', error);
          }
        };

        socket.onclose = (event) => {
          console.log(`WebSocket连接已关闭: ${event.code} ${event.reason}`);
        };

        socket.onerror = (error) => {
          console.error('WebSocket错误:', error);
        };

        ctx.respond(response);
      } catch (error) {
        console.error('WebSocket升级失败:', error);
        ctx.response.status = 500;
        ctx.response.body = createErrorResponse('WebSocket升级失败');
      }
    });

    // 获取WebSocket统计信息（管理员接口）
    this.router.get('/api/v1/ws/stats', async (ctx: Context) => {
      try {
        // 这里应该添加管理员权限检查
        const stats = this.wsService.getStats();

        ctx.response.body = createSuccessResponse({
          ...stats,
          uptime: process.uptime ? process.uptime() : 0,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        console.error('获取WebSocket统计失败:', error);
        ctx.response.status = 500;
        ctx.response.body = createErrorResponse('获取统计信息失败');
      }
    });

    // 手动推送比赛更新（管理员接口）
    this.router.post('/api/v1/ws/push-match-update', async (ctx: Context) => {
      try {
        const body = await ctx.request.body({ type: 'json' }).value;
        const { matchId, homeScore, awayScore, status, events } = body;

        if (!matchId) {
          ctx.response.status = 400;
          ctx.response.body = createErrorResponse('matchId是必需的');
          return;
        }

        await this.wsService.pushMatchUpdate({
          matchId,
          homeScore: homeScore || 0,
          awayScore: awayScore || 0,
          status: status || 'live',
          events: events || [],
        });

        ctx.response.body = createSuccessResponse(null, '比赛更新已推送');
      } catch (error) {
        console.error('推送比赛更新失败:', error);
        ctx.response.status = 500;
        ctx.response.body = createErrorResponse('推送比赛更新失败');
      }
    });

    // 推送评论更新
    this.router.post('/api/v1/ws/push-comment-update', async (ctx: Context) => {
      try {
        const body = await ctx.request.body({ type: 'json' }).value;
        const { articleId, comment } = body;

        if (!articleId || !comment) {
          ctx.response.status = 400;
          ctx.response.body = createErrorResponse('articleId和comment是必需的');
          return;
        }

        await this.wsService.pushCommentUpdate({
          articleId,
          comment,
        });

        ctx.response.body = createSuccessResponse(null, '评论更新已推送');
      } catch (error) {
        console.error('推送评论更新失败:', error);
        ctx.response.status = 500;
        ctx.response.body = createErrorResponse('推送评论更新失败');
      }
    });

    // 推送用户通知
    this.router.post('/api/v1/ws/push-notification', async (ctx: Context) => {
      try {
        const body = await ctx.request.body({ type: 'json' }).value;
        const { userId, notification } = body;

        if (!userId || !notification) {
          ctx.response.status = 400;
          ctx.response.body = createErrorResponse(
            'userId和notification是必需的',
          );
          return;
        }

        await this.wsService.pushNotification(userId, notification);

        ctx.response.body = createSuccessResponse(null, '通知已推送');
      } catch (error) {
        console.error('推送通知失败:', error);
        ctx.response.status = 500;
        ctx.response.body = createErrorResponse('推送通知失败');
      }
    });

    // 获取活跃频道列表
    this.router.get('/api/v1/ws/channels', async (ctx: Context) => {
      try {
        const stats = this.wsService.getStats();

        ctx.response.body = createSuccessResponse({
          channels: stats.channels,
          totalChannels: stats.totalChannels,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        console.error('获取频道列表失败:', error);
        ctx.response.status = 500;
        ctx.response.body = createErrorResponse('获取频道列表失败');
      }
    });

    // WebSocket健康检查
    this.router.get('/api/v1/ws/health', async (ctx: Context) => {
      try {
        const stats = this.wsService.getStats();
        const isHealthy = stats.totalConnections >= 0; // 基本健康检查

        ctx.response.status = isHealthy ? 200 : 503;
        ctx.response.body = {
          success: isHealthy,
          data: {
            status: isHealthy ? 'healthy' : 'unhealthy',
            connections: stats.totalConnections,
            channels: stats.totalChannels,
            timestamp: new Date().toISOString(),
          },
        };
      } catch (error) {
        console.error('WebSocket健康检查失败:', error);
        ctx.response.status = 503;
        ctx.response.body = createErrorResponse('健康检查失败');
      }
    });
  }

  getRouter(): Router {
    return this.router;
  }

  getWebSocketService(): WebSocketService {
    return this.wsService;
  }

  async close(): Promise<void> {
    await this.wsService.close();
  }
}
