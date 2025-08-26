import { Router } from '../../deps.ts';
import { NewsAggregator, ProcessedNewsItem } from './aggregator.ts';
import { TranslationService } from '../translation/service.ts';
import { TranslationRequest } from '../translation/types.ts';

const enhancedNewsRouter = new Router();
const newsAggregator = new NewsAggregator();
const translationService = new TranslationService();

// 获取新闻列表（增强版）
enhancedNewsRouter.get('/api/v1/news/enhanced', async (ctx) => {
  try {
    const query = ctx.request.url.searchParams;
    const category = query.get('category') || 'all';
    const page = parseInt(query.get('page') || '1');
    const limit = parseInt(query.get('limit') || '20');
    const language = query.get('language') || 'zh-CN';
    const translate = query.get('translate') === 'true';

    console.log(
      `📰 获取增强新闻列表: category=${category}, page=${page}, limit=${limit}, translate=${translate}`,
    );

    // 获取聚合新闻
    const allNews = await newsAggregator.fetchAllNews();

    // 按分类筛选
    let filteredNews = allNews;
    if (category !== 'all') {
      filteredNews = allNews.filter((news) => news.category === category);
    }

    // 分页
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    const paginatedNews = filteredNews.slice(startIndex, endIndex);

    // 翻译处理
    let finalNews = paginatedNews;
    if (translate && language === 'zh-CN') {
      console.log(`🌍 开始翻译 ${paginatedNews.length} 条新闻...`);

      const translationPromises = paginatedNews.map(async (news) => {
        try {
          // 只翻译英文内容
          if (news.originalLanguage === 'en' && !news.isTranslated) {
            const titleRequest: TranslationRequest = {
              text: news.title,
              sourceLanguage: 'en',
              targetLanguage: 'zh-CN',
              domain: 'football',
              priority: 'medium',
            };

            const summaryRequest: TranslationRequest = {
              text: news.summary,
              sourceLanguage: 'en',
              targetLanguage: 'zh-CN',
              domain: 'football',
              priority: 'medium',
            };

            const [titleResult, summaryResult] = await Promise.all([
              translationService.translate(titleRequest),
              translationService.translate(summaryRequest),
            ]);

            return {
              ...news,
              title: titleResult.translatedText,
              summary: summaryResult.translatedText,
              originalTitle: news.title,
              originalSummary: news.summary,
              isTranslated: true,
              translationProvider: titleResult.model,
              language: 'zh-CN',
            };
          }

          return news;
        } catch (error) {
          console.error(`翻译新闻失败 (${news.id}):`, error);
          return news; // 返回原始新闻
        }
      });

      finalNews = await Promise.all(translationPromises);
    }

    // 响应数据
    ctx.response.body = {
      success: true,
      data: finalNews,
      meta: {
        total: filteredNews.length,
        page: page,
        limit: limit,
        hasMore: endIndex < filteredNews.length,
        category: category,
        language: language,
        translated: translate,
        sources: [...new Set(finalNews.map((n) => n.sourceName))],
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('获取增强新闻列表失败:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'ENHANCED_NEWS_FETCH_ERROR',
        message: '获取新闻列表失败，请稍后重试',
      },
    };
  }
});

// 获取新闻详情（增强版）
enhancedNewsRouter.get('/api/v1/news/enhanced/:id', async (ctx) => {
  try {
    const newsId = ctx.params.id;
    const translate = ctx.request.url.searchParams.get('translate') === 'true';
    const language = ctx.request.url.searchParams.get('language') || 'zh-CN';

    console.log(`📖 获取增强新闻详情: ${newsId}, translate=${translate}`);

    // 获取所有新闻（在实际项目中应该有缓存或数据库查询）
    const allNews = await newsAggregator.fetchAllNews();
    const news = allNews.find((n) => n.id === newsId);

    if (!news) {
      ctx.response.status = 404;
      ctx.response.body = {
        success: false,
        error: {
          code: 'NEWS_NOT_FOUND',
          message: '新闻不存在',
        },
      };
      return;
    }

    let finalNews = news;

    // 翻译处理
    if (
      translate && language === 'zh-CN' && news.originalLanguage === 'en' &&
      !news.isTranslated
    ) {
      try {
        console.log(`🌍 翻译新闻详情: ${newsId}`);

        const requests: TranslationRequest[] = [
          {
            text: news.title,
            sourceLanguage: 'en',
            targetLanguage: 'zh-CN',
            domain: 'football',
            priority: 'high', // 详情页优先级更高
          },
          {
            text: news.summary,
            sourceLanguage: 'en',
            targetLanguage: 'zh-CN',
            domain: 'football',
            priority: 'high',
          },
          {
            text: news.content,
            sourceLanguage: 'en',
            targetLanguage: 'zh-CN',
            domain: 'football',
            priority: 'high',
          },
        ];

        const [titleResult, summaryResult, contentResult] = await Promise.all([
          translationService.translate(requests[0]),
          translationService.translate(requests[1]),
          translationService.translate(requests[2]),
        ]);

        finalNews = {
          ...news,
          title: titleResult.translatedText,
          summary: summaryResult.translatedText,
          content: contentResult.translatedText,
          originalTitle: news.title,
          originalSummary: news.summary,
          originalContent: news.content,
          isTranslated: true,
          translationProvider: titleResult.model,
          language: 'zh-CN',
          translationQuality:
            (titleResult.qualityScore + summaryResult.qualityScore +
              contentResult.qualityScore) / 3,
        };
      } catch (error) {
        console.error(`翻译新闻详情失败 (${newsId}):`, error);
        // 继续返回原始新闻
      }
    }

    // 增加阅读计数（模拟）
    finalNews.readCount += 1;

    ctx.response.body = {
      success: true,
      data: finalNews,
      meta: {
        translated: translate && finalNews.isTranslated,
        language: language,
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('获取增强新闻详情失败:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'ENHANCED_NEWS_DETAIL_ERROR',
        message: '获取新闻详情失败，请稍后重试',
      },
    };
  }
});

// 搜索新闻（增强版）
enhancedNewsRouter.get('/api/v1/news/enhanced/search', async (ctx) => {
  try {
    const query = ctx.request.url.searchParams;
    const keyword = query.get('q') || '';
    const category = query.get('category') || 'all';
    const page = parseInt(query.get('page') || '1');
    const limit = parseInt(query.get('limit') || '20');
    const translate = query.get('translate') === 'true';

    if (!keyword.trim()) {
      ctx.response.body = {
        success: true,
        data: [],
        meta: {
          total: 0,
          keyword: '',
          message: '请输入搜索关键词',
        },
      };
      return;
    }

    console.log(`🔍 增强搜索新闻: "${keyword}", category=${category}`);

    // 获取所有新闻
    const allNews = await newsAggregator.fetchAllNews();

    // 搜索过滤
    const searchResults = allNews.filter((news) => {
      const matchesKeyword =
        news.title.toLowerCase().includes(keyword.toLowerCase()) ||
        news.summary.toLowerCase().includes(keyword.toLowerCase()) ||
        news.content.toLowerCase().includes(keyword.toLowerCase()) ||
        news.tags.some((tag) =>
          tag.toLowerCase().includes(keyword.toLowerCase())
        ) ||
        news.entities.players.some((player) =>
          player.toLowerCase().includes(keyword.toLowerCase())
        ) ||
        news.entities.teams.some((team) =>
          team.toLowerCase().includes(keyword.toLowerCase())
        );

      const matchesCategory = category === 'all' || news.category === category;

      return matchesKeyword && matchesCategory;
    });

    // 按相关性排序（增强算法）
    searchResults.sort((a, b) => {
      const aRelevance = calculateRelevanceScore(a, keyword);
      const bRelevance = calculateRelevanceScore(b, keyword);

      if (aRelevance !== bRelevance) {
        return bRelevance - aRelevance;
      }

      return new Date(b.publishedAt).getTime() -
        new Date(a.publishedAt).getTime();
    });

    // 分页
    const startIndex = (page - 1) * limit;
    const endIndex = startIndex + limit;
    let paginatedResults = searchResults.slice(startIndex, endIndex);

    // 翻译处理
    if (translate) {
      const translationPromises = paginatedResults.map(async (news) => {
        if (news.originalLanguage === 'en' && !news.isTranslated) {
          try {
            const titleRequest: TranslationRequest = {
              text: news.title,
              sourceLanguage: 'en',
              targetLanguage: 'zh-CN',
              domain: 'football',
              priority: 'low', // 搜索结果优先级较低
            };

            const titleResult = await translationService.translate(
              titleRequest,
            );
            return {
              ...news,
              title: titleResult.translatedText,
              originalTitle: news.title,
              isTranslated: true,
              translationProvider: titleResult.model,
            };
          } catch (error) {
            console.error(`搜索结果翻译失败:`, error);
            return news;
          }
        }
        return news;
      });

      paginatedResults = await Promise.all(translationPromises);
    }

    ctx.response.body = {
      success: true,
      data: paginatedResults,
      meta: {
        total: searchResults.length,
        page: page,
        limit: limit,
        hasMore: endIndex < searchResults.length,
        keyword: keyword,
        category: category,
        translated: translate,
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('增强搜索新闻失败:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'ENHANCED_NEWS_SEARCH_ERROR',
        message: '搜索失败，请稍后重试',
      },
    };
  }
});

// 获取热门新闻（增强版）
enhancedNewsRouter.get('/api/v1/news/enhanced/trending', async (ctx) => {
  try {
    const limit = parseInt(ctx.request.url.searchParams.get('limit') || '10');
    const translate = ctx.request.url.searchParams.get('translate') === 'true';

    console.log(`🔥 获取增强热门新闻，限制: ${limit}`);

    // 获取所有新闻
    const allNews = await newsAggregator.fetchAllNews();

    // 按热度排序（增强算法）
    const trendingNews = allNews
      .sort((a, b) => {
        const scoreA = calculateTrendingScore(a);
        const scoreB = calculateTrendingScore(b);
        return scoreB - scoreA;
      })
      .slice(0, limit);

    // 翻译处理
    let finalNews = trendingNews;
    if (translate) {
      const translationPromises = trendingNews.map(async (news) => {
        if (news.originalLanguage === 'en' && !news.isTranslated) {
          try {
            const titleRequest: TranslationRequest = {
              text: news.title,
              sourceLanguage: 'en',
              targetLanguage: 'zh-CN',
              domain: 'football',
              priority: 'medium',
            };

            const titleResult = await translationService.translate(
              titleRequest,
            );
            return {
              ...news,
              title: titleResult.translatedText,
              originalTitle: news.title,
              isTranslated: true,
              translationProvider: titleResult.model,
            };
          } catch (error) {
            console.error(`热门新闻翻译失败:`, error);
            return news;
          }
        }
        return news;
      });

      finalNews = await Promise.all(translationPromises);
    }

    ctx.response.body = {
      success: true,
      data: finalNews,
      meta: {
        total: finalNews.length,
        limit: limit,
        algorithm: 'enhanced trending score',
        translated: translate,
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('获取增强热门新闻失败:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'ENHANCED_TRENDING_NEWS_ERROR',
        message: '获取热门新闻失败，请稍后重试',
      },
    };
  }
});

// 新闻统计（增强版）
enhancedNewsRouter.get('/api/v1/news/enhanced/stats', async (ctx) => {
  try {
    const allNews = await newsAggregator.fetchAllNews();

    const stats = {
      total: allNews.length,
      byCategory: {} as Record<string, number>,
      bySource: {} as Record<string, number>,
      byLanguage: {} as Record<string, number>,
      translated: allNews.filter((n) => n.isTranslated).length,
      last24Hours: allNews.filter((n) =>
        new Date(n.publishedAt).getTime() > Date.now() - 24 * 60 * 60 * 1000
      ).length,
      totalReadCount: allNews.reduce((sum, n) =>
        sum + n.readCount, 0),
      averageCredibility: allNews.reduce((sum, n) =>
        sum + n.credibilityScore, 0) / allNews.length,
      averageImportance: allNews.reduce((sum, n) =>
        sum + n.importanceScore, 0) / allNews.length,
      sentimentDistribution: {
        positive: allNews.filter((n) =>
          n.sentiment === 'positive'
        ).length,
        negative: allNews.filter((n) => n.sentiment === 'negative').length,
        neutral: allNews.filter((n) => n.sentiment === 'neutral').length,
      },
    };

    // 按分类统计
    allNews.forEach((news) => {
      stats.byCategory[news.category] = (stats.byCategory[news.category] || 0) +
        1;
    });

    // 按来源统计
    allNews.forEach((news) => {
      stats.bySource[news.sourceName] = (stats.bySource[news.sourceName] || 0) +
        1;
    });

    // 按语言统计
    allNews.forEach((news) => {
      stats.byLanguage[news.language] = (stats.byLanguage[news.language] || 0) +
        1;
    });

    ctx.response.body = {
      success: true,
      data: stats,
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('获取增强新闻统计失败:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'ENHANCED_NEWS_STATS_ERROR',
        message: '获取新闻统计失败，请稍后重试',
      },
    };
  }
});

// 获取新闻源状态
enhancedNewsRouter.get('/api/v1/news/enhanced/sources', async (ctx) => {
  try {
    const sourceStats = await getNewsSourceStats();

    ctx.response.body = {
      success: true,
      data: sourceStats,
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('获取新闻源状态失败:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'NEWS_SOURCES_ERROR',
        message: '获取新闻源状态失败',
      },
    };
  }
});

// 辅助函数：计算相关性分数
function calculateRelevanceScore(
  news: ProcessedNewsItem,
  keyword: string,
): number {
  const lowerKeyword = keyword.toLowerCase();
  let score = 0;

  // 标题匹配（权重最高）
  if (news.title.toLowerCase().includes(lowerKeyword)) {
    score += 10;
  }

  // 摘要匹配
  if (news.summary.toLowerCase().includes(lowerKeyword)) {
    score += 5;
  }

  // 标签匹配
  if (news.tags.some((tag) => tag.toLowerCase().includes(lowerKeyword))) {
    score += 3;
  }

  // 实体匹配
  if (
    news.entities.players.some((player) =>
      player.toLowerCase().includes(lowerKeyword)
    )
  ) {
    score += 8; // 球员匹配权重高
  }

  if (
    news.entities.teams.some((team) =>
      team.toLowerCase().includes(lowerKeyword)
    )
  ) {
    score += 8; // 球队匹配权重高
  }

  if (
    news.entities.leagues.some((league) =>
      league.toLowerCase().includes(lowerKeyword)
    )
  ) {
    score += 6;
  }

  // 内容匹配（权重较低）
  if (news.content.toLowerCase().includes(lowerKeyword)) {
    score += 2;
  }

  return score;
}

// 辅助函数：计算热度分数
function calculateTrendingScore(news: ProcessedNewsItem): number {
  const now = Date.now();
  const publishTime = new Date(news.publishedAt).getTime();
  const hoursSincePublish = (now - publishTime) / (1000 * 60 * 60);

  // 时间衰减因子（24小时内权重最高）
  const timeDecay = Math.max(0, (24 - hoursSincePublish) / 24);

  // 综合评分
  const score = news.importanceScore * 0.3 +
    news.credibilityScore * 0.2 +
    (news.readCount / 100) * 0.2 +
    timeDecay * 0.3;

  return score;
}

// 辅助函数：获取新闻源统计
async function getNewsSourceStats() {
  try {
    const allNews = await newsAggregator.fetchAllNews();
    const sourceStats = new Map();

    allNews.forEach((news) => {
      if (!sourceStats.has(news.sourceId)) {
        sourceStats.set(news.sourceId, {
          id: news.sourceId,
          name: news.sourceName,
          total: 0,
          last24Hours: 0,
          avgCredibility: 0,
          avgImportance: 0,
          translated: 0,
        });
      }

      const stats = sourceStats.get(news.sourceId);
      stats.total += 1;

      // 最近24小时
      if (
        new Date(news.publishedAt).getTime() > Date.now() - 24 * 60 * 60 * 1000
      ) {
        stats.last24Hours += 1;
      }

      // 翻译统计
      if (news.isTranslated) {
        stats.translated += 1;
      }

      // 更新平均值
      stats.avgCredibility =
        (stats.avgCredibility * (stats.total - 1) + news.credibilityScore) /
        stats.total;
      stats.avgImportance =
        (stats.avgImportance * (stats.total - 1) + news.importanceScore) /
        stats.total;
    });

    return Array.from(sourceStats.values());
  } catch (error) {
    console.error('获取新闻源统计失败:', error);
    return [];
  }
}

export default enhancedNewsRouter;
