/**
 * 分析服务API路由
 *
 * 提供数据分析相关的RESTful API接口：
 * - 用户行为跟踪
 * - 内容分析统计
 * - 热门趋势获取
 * - 用户洞察分析
 * - 系统性能监控
 */

import { Router } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { Context } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import {
  AnalyticsService,
  UserBehavior,
} from '../services/analytics/analytics-service.ts';
import { DatabaseManager } from '../shared/db.ts';
import { RedisManager } from '../shared/db.ts';
import {
  createErrorResponse,
  createSuccessResponse,
} from '../shared/response.ts';
import { requireAuth } from '../middleware/auth.ts';

const router = new Router({ prefix: '/api/v1/analytics' });

// 初始化分析服务
const db = new DatabaseManager();
const redis = new RedisManager();
const analyticsService = new AnalyticsService(db, redis);

/**
 * POST /api/v1/analytics/track
 * 记录用户行为
 */
router.post('/track', requireAuth, async (ctx: Context) => {
  try {
    const user = ctx.state.user;
    const body = await ctx.request.body({ type: 'json' }).value;

    const { action, targetType, targetId, metadata } = body;

    // 验证必需字段
    if (!action || !targetType || !targetId) {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse(
        '缺少必需的字段: action, targetType, targetId',
      );
      return;
    }

    // 验证字段值
    const validActions = ['view', 'like', 'comment', 'share', 'search'];
    const validTargetTypes = ['news', 'match', 'user'];

    if (!validActions.includes(action)) {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse(
        `无效的action值，支持: ${validActions.join(', ')}`,
      );
      return;
    }

    if (!validTargetTypes.includes(targetType)) {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse(
        `无效的targetType值，支持: ${validTargetTypes.join(', ')}`,
      );
      return;
    }

    const behavior: UserBehavior = {
      userId: user.id,
      action,
      targetType,
      targetId,
      timestamp: new Date(),
      metadata: metadata || {},
    };

    await analyticsService.trackUserBehavior(behavior);

    ctx.response.status = 201;
    ctx.response.body = createSuccessResponse(null, '行为记录成功');
  } catch (error) {
    console.error('记录用户行为失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

/**
 * GET /api/v1/analytics/content/:contentId
 * 获取内容分析数据
 */
router.get('/content/:contentId', requireAuth, async (ctx: Context) => {
  try {
    const { contentId } = ctx.params;
    const timeRange = ctx.request.url.searchParams.get('timeRange') || '7d';

    // 验证时间范围
    const validTimeRanges = ['1h', '6h', '24h', '7d', '30d'];
    if (!validTimeRanges.includes(timeRange)) {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse(
        `无效的时间范围，支持: ${validTimeRanges.join(', ')}`,
      );
      return;
    }

    const analytics = await analyticsService.getContentAnalytics(
      contentId,
      timeRange,
    );

    if (!analytics) {
      ctx.response.status = 404;
      ctx.response.body = createErrorResponse('未找到该内容的分析数据');
      return;
    }

    ctx.response.body = createSuccessResponse(analytics);
  } catch (error) {
    console.error('获取内容分析失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

/**
 * GET /api/v1/analytics/trending
 * 获取热门趋势
 */
router.get('/trending', async (ctx: Context) => {
  try {
    const timeWindow = ctx.request.url.searchParams.get('timeWindow') || '24h';
    const limit = parseInt(ctx.request.url.searchParams.get('limit') || '10');

    // 验证参数
    const validTimeWindows = ['1h', '6h', '24h', '7d'];
    if (!validTimeWindows.includes(timeWindow)) {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse(
        `无效的时间窗口，支持: ${validTimeWindows.join(', ')}`,
      );
      return;
    }

    if (limit < 1 || limit > 50) {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse('限制数量必须在1-50之间');
      return;
    }

    const trending = await analyticsService.getTrending(
      timeWindow as any,
      limit,
    );

    ctx.response.body = createSuccessResponse({
      trending,
      timeWindow,
      count: trending.length,
    });
  } catch (error) {
    console.error('获取热门趋势失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

/**
 * GET /api/v1/analytics/user/insights
 * 获取当前用户的个人洞察
 */
router.get('/user/insights', requireAuth, async (ctx: Context) => {
  try {
    const user = ctx.state.user;
    const insights = await analyticsService.getUserInsights(user.id);

    if (!insights) {
      ctx.response.status = 404;
      ctx.response.body = createErrorResponse(
        '未找到用户洞察数据，可能是新用户',
      );
      return;
    }

    ctx.response.body = createSuccessResponse(insights);
  } catch (error) {
    console.error('获取用户洞察失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

/**
 * GET /api/v1/analytics/user/:userId/insights
 * 获取指定用户的洞察（管理员功能）
 */
router.get('/user/:userId/insights', requireAuth, async (ctx: Context) => {
  try {
    const user = ctx.state.user;
    const { userId } = ctx.params;

    // 检查权限：只有管理员或用户本人可以查看
    if (user.role !== 'admin' && user.id !== userId) {
      ctx.response.status = 403;
      ctx.response.body = createErrorResponse('没有权限访问该用户的洞察数据');
      return;
    }

    const insights = await analyticsService.getUserInsights(userId);

    if (!insights) {
      ctx.response.status = 404;
      ctx.response.body = createErrorResponse('未找到用户洞察数据');
      return;
    }

    ctx.response.body = createSuccessResponse(insights);
  } catch (error) {
    console.error('获取指定用户洞察失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

/**
 * GET /api/v1/analytics/system/metrics
 * 获取系统性能指标（管理员功能）
 */
router.get('/system/metrics', requireAuth, async (ctx: Context) => {
  try {
    const user = ctx.state.user;

    // 只有管理员可以查看系统指标
    if (user.role !== 'admin') {
      ctx.response.status = 403;
      ctx.response.body = createErrorResponse('需要管理员权限');
      return;
    }

    const metrics = await analyticsService.getSystemMetrics();

    ctx.response.body = createSuccessResponse({
      ...metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error('获取系统指标失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

/**
 * GET /api/v1/analytics/dashboard
 * 获取分析仪表板数据
 */
router.get('/dashboard', requireAuth, async (ctx: Context) => {
  try {
    const user = ctx.state.user;
    const timeWindow = ctx.request.url.searchParams.get('timeWindow') || '24h';

    // 并行获取多项数据
    const [trending, userInsights, systemMetrics] = await Promise.allSettled([
      analyticsService.getTrending(timeWindow as any, 5),
      analyticsService.getUserInsights(user.id),
      user.role === 'admin'
        ? analyticsService.getSystemMetrics()
        : Promise.resolve(null),
    ]);

    const dashboardData: any = {
      timeWindow,
      trending: trending.status === 'fulfilled' ? trending.value : [],
      userInsights: userInsights.status === 'fulfilled'
        ? userInsights.value
        : null,
    };

    // 管理员可以看到系统指标
    if (user.role === 'admin' && systemMetrics.status === 'fulfilled') {
      dashboardData.systemMetrics = systemMetrics.value;
    }

    ctx.response.body = createSuccessResponse(dashboardData);
  } catch (error) {
    console.error('获取分析仪表板失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

/**
 * GET /api/v1/analytics/export
 * 导出分析数据（管理员功能）
 */
router.get('/export', requireAuth, async (ctx: Context) => {
  try {
    const user = ctx.state.user;

    if (user.role !== 'admin') {
      ctx.response.status = 403;
      ctx.response.body = createErrorResponse('需要管理员权限');
      return;
    }

    const format = ctx.request.url.searchParams.get('format') || 'json';
    const startDate = ctx.request.url.searchParams.get('startDate');
    const endDate = ctx.request.url.searchParams.get('endDate');

    if (!startDate || !endDate) {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse('需要提供开始和结束日期');
      return;
    }

    // 这里可以实现数据导出逻辑
    // 目前返回基本的分析数据
    const metrics = await analyticsService.getSystemMetrics();
    const trending = await analyticsService.getTrending('7d', 20);

    const exportData = {
      exportTime: new Date().toISOString(),
      dateRange: { startDate, endDate },
      systemMetrics: metrics,
      trending,
      format,
    };

    if (format === 'csv') {
      // 可以实现CSV格式导出
      ctx.response.headers.set('Content-Type', 'text/csv');
      ctx.response.headers.set(
        'Content-Disposition',
        `attachment; filename="analytics-${Date.now()}.csv"`,
      );
      // 这里需要实现CSV转换逻辑
    } else {
      ctx.response.headers.set('Content-Type', 'application/json');
      ctx.response.headers.set(
        'Content-Disposition',
        `attachment; filename="analytics-${Date.now()}.json"`,
      );
    }

    ctx.response.body = format === 'csv'
      ? 'CSV export not implemented yet'
      : JSON.stringify(exportData, null, 2);
  } catch (error) {
    console.error('导出分析数据失败:', error);
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse('服务器内部错误');
  }
});

export { router as analyticsRouter };
