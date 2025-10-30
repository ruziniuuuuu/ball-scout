import { Router } from '../../deps.ts';
import {
  aiNewsService,
  type AiNewsListOptions,
} from './ai-service.ts';

const enhancedNewsRouter = new Router();

enhancedNewsRouter.get('/api/v1/news/enhanced', async (ctx) => {
  try {
    const options = parseListOptions(ctx.request.url.searchParams);
    const { items, meta } = await aiNewsService.getNewsList(options);

    ctx.response.body = {
      success: true,
      data: items,
      meta,
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

enhancedNewsRouter.get('/api/v1/news/enhanced/:id', async (ctx) => {
  try {
    const id = ctx.params.id;
    if (!id) {
      ctx.response.status = 400;
      ctx.response.body = {
        success: false,
        error: {
          code: 'MISSING_ID',
          message: '缺少新闻ID',
        },
      };
      return;
    }

    const query = ctx.request.url.searchParams;
    const translate = query.get('translate') !== 'false';
    const language = query.get('language') || 'zh-CN';

    const detail = await aiNewsService.getNewsDetail(id, { translate, language });

    ctx.response.body = {
      success: true,
      data: detail,
      meta: {
        translated: translate && detail.aiMeta.isTranslated,
        language,
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

enhancedNewsRouter.get('/api/v1/news/enhanced/search', async (ctx) => {
  try {
    const query = ctx.request.url.searchParams;
    const keyword = query.get('q') || query.get('keyword') || '';
    const tags = query.get('tags')?.split(',').map((tag) => tag.trim()).filter(Boolean);
    const options: AiNewsListOptions = parseListOptions(query);

    const { items, meta } = await aiNewsService.searchNews({
      ...options,
      keyword,
      tags,
    });

    ctx.response.body = {
      success: true,
      data: items,
      meta: {
        ...meta,
        keyword,
        tags,
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

enhancedNewsRouter.get('/api/v1/news/enhanced/trending', async (ctx) => {
  try {
    const query = ctx.request.url.searchParams;
    const limit = clampNumber(parseInt(query.get('limit') || '10', 10), 1, 50);
    const translate = query.get('translate') !== 'false';
    const language = query.get('language') || 'zh-CN';

    const data = await aiNewsService.getTrendingNews({ limit, translate, language });

    ctx.response.body = {
      success: true,
      data,
      meta: {
        total: data.length,
        limit,
        translated: translate,
        language,
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

enhancedNewsRouter.get('/api/v1/news/enhanced/stats', async (ctx) => {
  try {
    const stats = await aiNewsService.getStats();
    ctx.response.body = {
      success: true,
      data: stats,
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

enhancedNewsRouter.get('/api/v1/news/enhanced/sources', async (ctx) => {
  try {
    const sources = await aiNewsService.getSourceStats();
    ctx.response.body = {
      success: true,
      data: sources,
      meta: {
        total: sources.length,
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

function parseListOptions(search: URLSearchParams): AiNewsListOptions {
  const page = clampNumber(parseInt(search.get('page') || '1', 10), 1, 1000);
  const limit = clampNumber(parseInt(search.get('limit') || '20', 10), 1, 100);
  const translate = search.get('translate') !== 'false';
  const language = search.get('language') || 'zh-CN';
  const categoryParam = search.get('category') || 'all';
  const sentimentParam = search.get('sentiment') || 'all';
  const sources = search.get('sources')?.split(',').map((source) => source.trim()).filter(Boolean);
  const minCredibility = parseFloat(search.get('minCredibility') || '0');
  const minImportance = parseFloat(search.get('minImportance') || '0');
  const sortByParam = search.get('sortBy') || 'publishedAt';
  const sortOrderParam = search.get('sortOrder') || 'desc';

  const category = mapCategory(categoryParam);
  const sentiment = mapSentiment(sentimentParam);
  const sortBy = mapSortBy(sortByParam);
  const sortOrder = mapSortOrder(sortOrderParam);

  return {
    page,
    limit,
    translate,
    language,
    category,
    sentiment,
    sources,
    minCredibility: Number.isNaN(minCredibility) ? 0 : minCredibility,
    minImportance: Number.isNaN(minImportance) ? 0 : minImportance,
    sortBy,
    sortOrder,
  };
}

function mapCategory(value: string): AiNewsListOptions['category'] {
  const allowed: Array<AiNewsListOptions['category']> = [
    'all',
    'news',
    'transfer',
    'match',
    'analysis',
    'rumor',
    'injury',
  ];

  const lowered = value.toLowerCase();
  return allowed.includes(lowered as AiNewsListOptions['category'])
    ? lowered as AiNewsListOptions['category']
    : 'all';
}

function mapSentiment(
  value: string,
): AiNewsListOptions['sentiment'] {
  const allowed: Array<AiNewsListOptions['sentiment']> = [
    'all',
    'positive',
    'negative',
    'neutral',
  ];
  const lowered = value.toLowerCase();
  return allowed.includes(lowered as AiNewsListOptions['sentiment'])
    ? lowered as AiNewsListOptions['sentiment']
    : 'all';
}

function mapSortBy(value: string): NonNullable<AiNewsListOptions['sortBy']> {
  const allowed: Array<NonNullable<AiNewsListOptions['sortBy']>> = [
    'publishedAt',
    'importance',
    'credibility',
  ];
  const lowered = value.toLowerCase();
  return allowed.includes(lowered as NonNullable<AiNewsListOptions['sortBy']>)
    ? lowered as NonNullable<AiNewsListOptions['sortBy']>
    : 'publishedAt';
}

function mapSortOrder(
  value: string,
): NonNullable<AiNewsListOptions['sortOrder']> {
  const allowed: Array<NonNullable<AiNewsListOptions['sortOrder']>> = [
    'asc',
    'desc',
  ];
  const lowered = value.toLowerCase();
  return allowed.includes(lowered as NonNullable<AiNewsListOptions['sortOrder']>)
    ? lowered as NonNullable<AiNewsListOptions['sortOrder']>
    : 'desc';
}

function clampNumber(value: number, min: number, max: number): number {
  if (Number.isNaN(value)) return min;
  return Math.max(min, Math.min(max, value));
}

export default enhancedNewsRouter;
