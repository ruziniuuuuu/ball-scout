import { assertEquals, assertExists } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import { Application } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { superoak } from 'https://deno.land/x/superoak@4.7.0/mod.ts';
import { NewsArticle, ApiResponse } from '../../shared/types.ts';

// 模拟数据
const mockNewsData: Partial<NewsArticle>[] = [
  {
    id: 'news-1',
    title: '测试新闻标题1',
    summary: '测试新闻摘要1',
    source: '测试来源1',
    category: 'news',
    publishedAt: new Date('2024-01-20T10:00:00Z'),
    readCount: 100,
    language: 'zh',
  },
  {
    id: 'news-2',
    title: '测试新闻标题2',
    summary: '测试新闻摘要2',
    source: '测试来源2',
    category: 'transfer',
    publishedAt: new Date('2024-01-20T11:00:00Z'),
    readCount: 200,
    language: 'zh',
  },
];

// 创建测试应用
function createTestApp(): Application {
  const app = new Application();
  
  // 添加测试路由
  app.use(async (ctx, next) => {
    // 模拟数据库连接
    ctx.state.db = {
      query: async (sql: string, params: unknown[]) => {
        // 模拟数据库查询
        if (sql.includes('SELECT COUNT(*)')) {
          return { rows: [{ total: mockNewsData.length }] };
        }
        if (sql.includes('FROM news_articles')) {
          return { rows: mockNewsData };
        }
        return { rows: [] };
      }
    };
    await next();
  });

  return app;
}

Deno.test('News API Tests', async (t) => {
  const app = createTestApp();

  await t.step('GET /api/v1/news - should return news list', async () => {
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news')
      .expect(200);

    const body: ApiResponse<NewsArticle[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
    assertEquals(Array.isArray(body.data), true);
    assertExists(body.meta);
    assertEquals(typeof body.meta.timestamp, 'string');
  });

  await t.step('GET /api/v1/news - should handle pagination parameters', async () => {
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news?page=2&limit=10')
      .expect(200);

    const body: ApiResponse<NewsArticle[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.meta);
    assertEquals(body.meta.page, 2);
    assertEquals(body.meta.limit, 10);
  });

  await t.step('GET /api/v1/news - should filter by category', async () => {
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news?category=transfer')
      .expect(200);

    const body: ApiResponse<NewsArticle[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
    
    // 验证所有返回的新闻都是指定分类
    body.data?.forEach(news => {
      assertEquals(news.category, 'transfer');
    });
  });

  await t.step('GET /api/v1/news - should filter by source', async () => {
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news?source=ESPN')
      .expect(200);

    const body: ApiResponse<NewsArticle[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
  });

  await t.step('GET /api/v1/news - should handle invalid parameters', async () => {
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news?page=invalid&limit=invalid')
      .expect(400);

    const body = response.body;
    assertEquals(body.success, false);
    assertExists(body.error);
    assertEquals(body.error.code, 'VALIDATION_ERROR');
  });

  await t.step('GET /api/v1/news/:id - should return news detail', async () => {
    const newsId = 'news-1';
    const request = await superoak(app);
    const response = await request
      .get(`/api/v1/news/${newsId}`)
      .expect(200);

    const body: ApiResponse<NewsArticle> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
    assertEquals(body.data.id, newsId);
    assertExists(body.data.content); // 详情应该包含完整内容
  });

  await t.step('GET /api/v1/news/:id - should handle missing news', async () => {
    const newsId = 'non-existent-id';
    const request = await superoak(app);
    const response = await request
      .get(`/api/v1/news/${newsId}`)
      .expect(404);

    const body = response.body;
    assertEquals(body.success, false);
    assertExists(body.error);
    assertEquals(body.error.code, 'NOT_FOUND');
  });

  await t.step('GET /api/v1/news/:id - should increment read count', async () => {
    const newsId = 'news-1';
    const request = await superoak(app);
    
    // 第一次获取新闻详情
    const response1 = await request
      .get(`/api/v1/news/${newsId}`)
      .expect(200);
    
    const initialReadCount = response1.body.data.readCount;
    
    // 第二次获取新闻详情
    const response2 = await request
      .get(`/api/v1/news/${newsId}`)
      .expect(200);
    
    const updatedReadCount = response2.body.data.readCount;
    
    // 验证阅读计数增加
    assertEquals(updatedReadCount, initialReadCount + 1);
  });

  await t.step('GET /api/v1/news/trending - should return trending news', async () => {
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news/trending')
      .expect(200);

    const body: ApiResponse<NewsArticle[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
    assertEquals(Array.isArray(body.data), true);
    
    // 验证结果按阅读量排序（假设mock数据已经按阅读量排序）
    if (body.data.length > 1) {
      for (let i = 1; i < body.data.length; i++) {
        assertEquals(
          body.data[i - 1].readCount >= body.data[i].readCount,
          true,
          'Trending news should be sorted by read count descending'
        );
      }
    }
  });

  await t.step('GET /api/v1/news/trending - should respect limit parameter', async () => {
    const limit = 5;
    const request = await superoak(app);
    const response = await request
      .get(`/api/v1/news/trending?limit=${limit}`)
      .expect(200);

    const body: ApiResponse<NewsArticle[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
    assertEquals(body.data.length <= limit, true);
  });

  await t.step('GET /api/v1/news/categories - should return category statistics', async () => {
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news/categories')
      .expect(200);

    const body: ApiResponse<{ category: string; count: number }[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
    assertEquals(Array.isArray(body.data), true);
    
    // 验证每个分类统计都有必要字段
    body.data?.forEach(stat => {
      assertExists(stat.category);
      assertEquals(typeof stat.count, 'number');
      assertEquals(stat.count >= 0, true);
    });
  });
});

Deno.test('News API Error Handling Tests', async (t) => {
  await t.step('should handle database connection errors', async () => {
    const app = new Application();
    
    // 模拟数据库连接失败
    app.use(async (ctx, next) => {
      ctx.state.db = {
        query: async () => {
          throw new Error('Database connection failed');
        }
      };
      await next();
    });

    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news')
      .expect(500);

    const body = response.body;
    assertEquals(body.success, false);
    assertExists(body.error);
  });

  await t.step('should handle SQL injection attempts', async () => {
    const app = createTestApp();
    const maliciousCategoryParam = "'; DROP TABLE news_articles; --";
    
    const request = await superoak(app);
    const response = await request
      .get(`/api/v1/news?category=${encodeURIComponent(maliciousCategoryParam)}`)
      .expect(400); // 应该被参数验证拦截

    const body = response.body;
    assertEquals(body.success, false);
    assertExists(body.error);
  });

  await t.step('should validate category parameter values', async () => {
    const app = createTestApp();
    const invalidCategory = 'invalid-category';
    
    const request = await superoak(app);
    const response = await request
      .get(`/api/v1/news?category=${invalidCategory}`)
      .expect(400);

    const body = response.body;
    assertEquals(body.success, false);
    assertEquals(body.error?.code, 'VALIDATION_ERROR');
  });

  await t.step('should handle extremely large page numbers', async () => {
    const app = createTestApp();
    const largePage = Number.MAX_SAFE_INTEGER;
    
    const request = await superoak(app);
    const response = await request
      .get(`/api/v1/news?page=${largePage}`)
      .expect(400);

    const body = response.body;
    assertEquals(body.success, false);
    assertExists(body.error);
  });

  await t.step('should handle negative page numbers', async () => {
    const app = createTestApp();
    
    const request = await superoak(app);
    const response = await request
      .get('/api/v1/news?page=-1&limit=-10')
      .expect(400);

    const body = response.body;
    assertEquals(body.success, false);
    assertEquals(body.error?.code, 'VALIDATION_ERROR');
  });
});

Deno.test('News API Performance Tests', async (t) => {
  await t.step('should handle concurrent requests', async () => {
    const app = createTestApp();
    const concurrentRequests = 10;
    
    const promises = Array.from({ length: concurrentRequests }, () => {
      return superoak(app).get('/api/v1/news').expect(200);
    });

    const responses = await Promise.all(promises);
    
    // 验证所有请求都成功返回
    responses.forEach(response => {
      assertEquals(response.body.success, true);
    });
  });

  await t.step('should respond within reasonable time', async () => {
    const app = createTestApp();
    const startTime = Date.now();
    
    const request = await superoak(app);
    await request.get('/api/v1/news').expect(200);
    
    const responseTime = Date.now() - startTime;
    
    // 验证响应时间在合理范围内（这里设置为1秒）
    assertEquals(responseTime < 1000, true, `Response time ${responseTime}ms is too slow`);
  });
});

Deno.test('News API Integration Tests', async (t) => {
  await t.step('should maintain data consistency across operations', async () => {
    const app = createTestApp();
    const request = await superoak(app);
    
    // 获取新闻列表
    const listResponse = await request.get('/api/v1/news').expect(200);
    const newsList = listResponse.body.data;
    
    if (newsList && newsList.length > 0) {
      const firstNews = newsList[0];
      
      // 获取该新闻的详情
      const detailResponse = await request
        .get(`/api/v1/news/${firstNews.id}`)
        .expect(200);
      
      const newsDetail = detailResponse.body.data;
      
      // 验证数据一致性
      assertEquals(newsDetail.id, firstNews.id);
      assertEquals(newsDetail.title, firstNews.title);
      assertEquals(newsDetail.source, firstNews.source);
      assertEquals(newsDetail.category, firstNews.category);
    }
  });

  await t.step('should handle complex filtering scenarios', async () => {
    const app = createTestApp();
    const request = await superoak(app);
    
    // 组合多个过滤条件
    const response = await request
      .get('/api/v1/news?category=transfer&source=ESPN&page=1&limit=5')
      .expect(200);

    const body: ApiResponse<NewsArticle[]> = response.body;
    
    assertEquals(body.success, true);
    assertExists(body.data);
    assertEquals(body.meta?.page, 1);
    assertEquals(body.meta?.limit, 5);
    
    // 验证返回的数据符合过滤条件
    body.data?.forEach(news => {
      assertEquals(news.category, 'transfer');
    });
  });
});