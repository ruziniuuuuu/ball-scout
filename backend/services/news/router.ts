import { Router } from '../../deps.ts';
import { ApiResponse, NewsArticle, ServiceError } from '../../shared/types.ts';
import { z } from '../../deps.ts';

export const newsRouter = new Router();

// 数据验证schemas
const newsQuerySchema = z.object({
  page: z.string().optional().transform((val) => parseInt(val || '1')),
  limit: z.string().optional().transform((val) => parseInt(val || '20')),
  category: z.enum([
    'news',
    'transfer',
    'match',
    'analysis',
    'interview',
    'rumor',
  ]).optional(),
  source: z.string().optional(),
  language: z.string().optional(),
});

// GET /api/v1/news - 获取新闻列表
newsRouter.get('/api/v1/news', async (ctx) => {
  try {
    const queryParams = ctx.request.url.searchParams;
    const params = newsQuerySchema.parse(Object.fromEntries(queryParams));

    const { page, limit, category, source, language } = params;
    const offset = (page - 1) * limit;

    // 构建SQL查询
    let sql = `
      SELECT id, title, summary, source, author, published_at, category, 
             language, image_url, read_count, sentiment_score, reliability,
             created_at, updated_at
      FROM news_articles 
      WHERE 1=1
    `;
    const queryParams: unknown[] = [];
    let paramIndex = 1;

    if (category) {
      sql += ` AND category = $${paramIndex++}`;
      queryParams.push(category);
    }

    if (source) {
      sql += ` AND source ILIKE $${paramIndex++}`;
      queryParams.push(`%${source}%`);
    }

    if (language) {
      sql += ` AND language = $${paramIndex++}`;
      queryParams.push(language);
    }

    sql +=
      ` ORDER BY published_at DESC LIMIT $${paramIndex++} OFFSET $${paramIndex++}`;
    queryParams.push(limit, offset);

    // 获取总数
    let countSql = `SELECT COUNT(*) as total FROM news_articles WHERE 1=1`;
    const countParams: unknown[] = [];
    let countParamIndex = 1;

    if (category) {
      countSql += ` AND category = $${countParamIndex++}`;
      countParams.push(category);
    }

    if (source) {
      countSql += ` AND source ILIKE $${countParamIndex++}`;
      countParams.push(`%${source}%`);
    }

    if (language) {
      countSql += ` AND language = $${countParamIndex++}`;
      countParams.push(language);
    }

    const db = ctx.state.db;
    const [articlesResult, countResult] = await Promise.all([
      db.query(sql, queryParams),
      db.query(countSql, countParams),
    ]);

    const articles = articlesResult.rows;
    const total = parseInt(countResult.rows[0].total);

    const response: ApiResponse<NewsArticle[]> = {
      success: true,
      data: articles,
      meta: {
        page,
        limit,
        total,
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.body = response;
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new ServiceError(
        'VALIDATION_ERROR',
        '请求参数无效',
        400,
        error.errors,
      );
    }
    throw error;
  }
});

// GET /api/v1/news/:id - 获取新闻详情
newsRouter.get('/api/v1/news/:id', async (ctx) => {
  try {
    const { id } = ctx.params;

    if (!id) {
      throw new ServiceError('MISSING_PARAMETER', '缺少新闻ID', 400);
    }

    const db = ctx.state.db;

    // 获取新闻详情
    const sql = `
      SELECT id, title, content, summary, source, author, published_at, 
             category, language, translation_zh, tags, image_url, 
             read_count, sentiment_score, reliability, created_at, updated_at
      FROM news_articles 
      WHERE id = $1
    `;

    const result = await db.query(sql, [id]);

    if (result.rows.length === 0) {
      throw new ServiceError('NOT_FOUND', '新闻不存在', 404);
    }

    const article = result.rows[0];

    // 增加阅读计数
    await db.query(
      'UPDATE news_articles SET read_count = read_count + 1 WHERE id = $1',
      [id],
    );

    const response: ApiResponse<NewsArticle> = {
      success: true,
      data: article,
      meta: {
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.body = response;
  } catch (error) {
    throw error;
  }
});

// GET /api/v1/news/trending - 获取热门新闻
newsRouter.get('/api/v1/news/trending', async (ctx) => {
  try {
    const queryParams = ctx.request.url.searchParams;
    const limit = parseInt(queryParams.get('limit') || '10');

    const db = ctx.state.db;

    // 获取最近24小时内阅读量最高的新闻
    const sql = `
      SELECT id, title, summary, source, author, published_at, category, 
             language, image_url, read_count, sentiment_score, reliability,
             created_at, updated_at
      FROM news_articles 
      WHERE published_at >= NOW() - INTERVAL '24 hours'
      ORDER BY read_count DESC, published_at DESC
      LIMIT $1
    `;

    const result = await db.query(sql, [limit]);

    const response: ApiResponse<NewsArticle[]> = {
      success: true,
      data: result.rows,
      meta: {
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.body = response;
  } catch (error) {
    throw error;
  }
});

// GET /api/v1/news/categories - 获取新闻分类统计
newsRouter.get('/api/v1/news/categories', async (ctx) => {
  try {
    const db = ctx.state.db;

    const sql = `
      SELECT category, COUNT(*) as count
      FROM news_articles 
      WHERE published_at >= NOW() - INTERVAL '7 days'
      GROUP BY category
      ORDER BY count DESC
    `;

    const result = await db.query(sql);

    const response: ApiResponse<{ category: string; count: number }[]> = {
      success: true,
      data: result.rows,
      meta: {
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.body = response;
  } catch (error) {
    throw error;
  }
});
