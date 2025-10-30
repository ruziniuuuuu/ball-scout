import { NewsAggregator, ProcessedNewsItem } from './aggregator.ts';
import { translationService } from '../translation/service.ts';
import type {
  TranslationRequest,
  TranslationResult,
} from '../translation/types.ts';

export interface AiNewsListOptions {
  page?: number;
  limit?: number;
  category?: ProcessedNewsItem['category'] | 'all';
  language?: string;
  translate?: boolean;
  sources?: string[];
  sentiment?: ProcessedNewsItem['sentiment'] | 'all';
  minCredibility?: number;
  minImportance?: number;
  sortBy?: 'publishedAt' | 'importance' | 'credibility';
  sortOrder?: 'asc' | 'desc';
}

export interface AiNewsSearchOptions extends AiNewsListOptions {
  keyword: string;
  tags?: string[];
}

export interface AiNewsListItem {
  id: string;
  title: string;
  summary: string;
  source: string;
  sourceId: string;
  category: ProcessedNewsItem['category'];
  publishedAt: string;
  readCount: number;
  imageUrl?: string;
  language: string;
  url: string;
  sentiment: ProcessedNewsItem['sentiment'];
  tags: string[];
  aiMeta: {
    originalLanguage: string;
    isTranslated: boolean;
    translationProvider?: string;
    translationQuality?: number;
    credibilityScore: number;
    importanceScore: number;
    entities: ProcessedNewsItem['entities'];
  };
}

export interface AiNewsDetail extends AiNewsListItem {
  content: string;
  originalTitle?: string;
  originalSummary?: string;
  originalContent?: string;
  translatedContent?: string;
}

export interface AiNewsListMeta {
  page: number;
  limit: number;
  total: number;
  hasMore: boolean;
  translated: boolean;
  language: string;
  category?: string;
  sources?: string[];
  sortBy: NonNullable<AiNewsListOptions['sortBy']>;
  sortOrder: NonNullable<AiNewsListOptions['sortOrder']>;
  timestamp: string;
}

export interface AiNewsListResponse {
  items: AiNewsListItem[];
  meta: AiNewsListMeta;
}

export interface AiNewsTrendingOptions {
  limit?: number;
  translate?: boolean;
  language?: string;
}

export interface AiNewsStats {
  total: number;
  last24Hours: number;
  translated: number;
  averageCredibility: number;
  averageImportance: number;
  sentimentDistribution: Record<ProcessedNewsItem['sentiment'], number>;
  byCategory: Record<string, number>;
  bySource: Record<string, number>;
  byLanguage: Record<string, number>;
  timestamp: string;
}

export interface AiNewsSourceStats {
  id: string;
  name: string;
  total: number;
  last24Hours: number;
  avgCredibility: number;
  avgImportance: number;
  translated: number;
}

interface TranslationMemoryEntry {
  title?: string;
  summary?: string;
  content?: string;
  provider?: string;
  quality?: number;
  originalTitle?: string;
  originalSummary?: string;
  originalContent?: string;
  updatedAt: string;
}

export class AiNewsService {
  private aggregator = new NewsAggregator();
  private translationMemory = new Map<string, Map<string, TranslationMemoryEntry>>();
  private readCountCache = new Map<string, number>();
  private detailCache = new Map<string, { item: AiNewsDetail; expiresAt: number }>();
  private allNewsCache: { items: ProcessedNewsItem[]; expiresAt: number } | null = null;

  private readonly listCacheTTL = 5 * 60 * 1000; // 5 minutes
  private readonly detailCacheTTL = 10 * 60 * 1000; // 10 minutes

  async getNewsList(options: AiNewsListOptions = {}): Promise<AiNewsListResponse> {
    const {
      page = 1,
      limit = 20,
      category = 'all',
      language = 'zh-CN',
      translate = true,
      sources,
      sentiment = 'all',
      minCredibility = 0,
      minImportance = 0,
      sortBy = 'publishedAt',
      sortOrder = 'desc',
    } = options;

    const allNews = await this.getAllNews();

    const filtered = this.filterNews(allNews, {
      category,
      sources,
      sentiment,
      minCredibility,
      minImportance,
    });

    const sorted = this.sortNews(filtered, sortBy, sortOrder);

    const start = (page - 1) * limit;
    const end = start + limit;
    const pageItems = sorted.slice(start, end);

    const localizedItems = translate
      ? await this.localizeNewsList(pageItems, language)
      : pageItems;

    const data = localizedItems.map((item) => this.toListItem(item));

    return {
      items: data,
      meta: {
        page,
        limit,
        total: filtered.length,
        hasMore: end < filtered.length,
        translated: translate,
        language,
        category: category === 'all' ? undefined : category,
        sources,
        sortBy,
        sortOrder,
        timestamp: new Date().toISOString(),
      },
    };
  }

  async getNewsDetail(
    id: string,
    options: Partial<Pick<AiNewsListOptions, 'translate' | 'language'>> = {},
  ): Promise<AiNewsDetail> {
    const { translate = true, language = 'zh-CN' } = options;

    const cachedDetail = this.detailCache.get(id);
    if (cachedDetail && cachedDetail.expiresAt > Date.now()) {
      if (!translate || cachedDetail.item.language === language) {
        return cachedDetail.item;
      }
    }

    const allNews = await this.getAllNews();
    const target = allNews.find((item) => item.id === id);

    if (!target) {
      throw new Error('新闻不存在');
    }

    const localized = translate
      ? await this.localizeNewsDetail(target, language)
      : target;

    const detail = this.toDetail(localized);
    this.incrementReadCount(id);

    this.detailCache.set(id, {
      item: detail,
      expiresAt: Date.now() + this.detailCacheTTL,
    });

    return detail;
  }

  async searchNews(options: AiNewsSearchOptions): Promise<AiNewsListResponse> {
    const {
      keyword,
      tags,
      page = 1,
      limit = 20,
      translate = true,
      language = 'zh-CN',
      sortBy = 'publishedAt',
      sortOrder = 'desc',
    } = options;

    const normalizedKeyword = keyword.trim().toLowerCase();
    if (!normalizedKeyword) {
      return {
        items: [],
        meta: {
          page,
          limit,
          total: 0,
          hasMore: false,
          translated: translate,
          language,
          sortBy,
          sortOrder,
          timestamp: new Date().toISOString(),
        },
      };
    }

    const allNews = await this.getAllNews();
    const filtered = this.filterNews(allNews, options);

    const matched = filtered
      .map((item) => ({ item, score: this.calculateRelevanceScore(item, normalizedKeyword, tags) }))
      .filter((entry) => entry.score > 0)
      .sort((a, b) => b.score - a.score)
      .map((entry) => entry.item);

    const start = (page - 1) * limit;
    const end = start + limit;
    const pageItems = matched.slice(start, end);

    const localizedItems = translate
      ? await this.localizeNewsList(pageItems, language)
      : pageItems;

    return {
      items: localizedItems.map((item) => this.toListItem(item)),
      meta: {
        page,
        limit,
        total: matched.length,
        hasMore: end < matched.length,
        translated: translate,
        language,
        category: options.category === 'all' ? undefined : options.category,
        sources: options.sources,
        sortBy,
        sortOrder,
        timestamp: new Date().toISOString(),
      },
    };
  }

  async getTrendingNews(
    options: AiNewsTrendingOptions = {},
  ): Promise<AiNewsListItem[]> {
    const { limit = 10, translate = true, language = 'zh-CN' } = options;
    const allNews = await this.getAllNews();

    const ranked = [...allNews]
      .sort((a, b) => this.calculateTrendingScore(b) - this.calculateTrendingScore(a))
      .slice(0, limit);

    const localized = translate
      ? await this.localizeNewsList(ranked, language)
      : ranked;

    return localized.map((item) => this.toListItem(item));
  }

  async getStats(): Promise<AiNewsStats> {
    const allNews = await this.getAllNews();

    const stats: AiNewsStats = {
      total: allNews.length,
      last24Hours: 0,
      translated: 0,
      averageCredibility: 0,
      averageImportance: 0,
      sentimentDistribution: {
        positive: 0,
        negative: 0,
        neutral: 0,
      },
      byCategory: {},
      bySource: {},
      byLanguage: {},
      timestamp: new Date().toISOString(),
    };

    if (allNews.length === 0) {
      return stats;
    }

    let credibilitySum = 0;
    let importanceSum = 0;

    for (const item of allNews) {
      credibilitySum += item.credibilityScore;
      importanceSum += item.importanceScore;

      stats.sentimentDistribution[item.sentiment] += 1;
      stats.byCategory[item.category] = (stats.byCategory[item.category] || 0) + 1;
      stats.bySource[item.sourceName] = (stats.bySource[item.sourceName] || 0) + 1;
      stats.byLanguage[item.language] = (stats.byLanguage[item.language] || 0) + 1;

      if (item.isTranslated) {
        stats.translated += 1;
      }

      if (new Date(item.publishedAt).getTime() > Date.now() - 24 * 60 * 60 * 1000) {
        stats.last24Hours += 1;
      }
    }

    stats.averageCredibility = credibilitySum / allNews.length;
    stats.averageImportance = importanceSum / allNews.length;

    return stats;
  }

  async getSourceStats(): Promise<AiNewsSourceStats[]> {
    const allNews = await this.getAllNews();
    const sourceMap = new Map<string, AiNewsSourceStats>();

    for (const item of allNews) {
      if (!sourceMap.has(item.sourceId)) {
        sourceMap.set(item.sourceId, {
          id: item.sourceId,
          name: item.sourceName,
          total: 0,
          last24Hours: 0,
          avgCredibility: 0,
          avgImportance: 0,
          translated: 0,
        });
      }

      const stats = sourceMap.get(item.sourceId)!;
      stats.total += 1;

      if (item.isTranslated) {
        stats.translated += 1;
      }

      if (new Date(item.publishedAt).getTime() > Date.now() - 24 * 60 * 60 * 1000) {
        stats.last24Hours += 1;
      }

      stats.avgCredibility =
        (stats.avgCredibility * (stats.total - 1) + item.credibilityScore) /
        stats.total;

      stats.avgImportance =
        (stats.avgImportance * (stats.total - 1) + item.importanceScore) /
        stats.total;
    }

    return Array.from(sourceMap.values()).sort((a, b) => b.total - a.total);
  }

  private async getAllNews(): Promise<ProcessedNewsItem[]> {
    if (this.allNewsCache && this.allNewsCache.expiresAt > Date.now()) {
      return this.allNewsCache.items;
    }

    const items = await this.aggregator.fetchAllNews();
    this.allNewsCache = {
      items,
      expiresAt: Date.now() + this.listCacheTTL,
    };

    return items;
  }

  private filterNews(
    items: ProcessedNewsItem[],
    options: Partial<AiNewsListOptions>,
  ): ProcessedNewsItem[] {
    const {
      category = 'all',
      sources,
      sentiment = 'all',
      minCredibility = 0,
      minImportance = 0,
    } = options;

    return items.filter((item) => {
      if (category !== 'all' && item.category !== category) {
        return false;
      }

      if (sources && sources.length > 0 && !sources.includes(item.sourceId)) {
        return false;
      }

      if (sentiment !== 'all' && item.sentiment !== sentiment) {
        return false;
      }

      if (item.credibilityScore < minCredibility) {
        return false;
      }

      if (item.importanceScore < minImportance) {
        return false;
      }

      return true;
    });
  }

  private sortNews(
    items: ProcessedNewsItem[],
    sortBy: NonNullable<AiNewsListOptions['sortBy']>,
    sortOrder: NonNullable<AiNewsListOptions['sortOrder']>,
  ): ProcessedNewsItem[] {
    const sorted = [...items];

    sorted.sort((a, b) => {
      let compareValue = 0;

      switch (sortBy) {
        case 'importance':
          compareValue = a.importanceScore - b.importanceScore;
          break;
        case 'credibility':
          compareValue = a.credibilityScore - b.credibilityScore;
          break;
        case 'publishedAt':
        default:
          compareValue =
            new Date(a.publishedAt).getTime() - new Date(b.publishedAt).getTime();
          break;
      }

      return sortOrder === 'asc' ? compareValue : -compareValue;
    });

    return sorted;
  }

  private async localizeNewsList(
    items: ProcessedNewsItem[],
    language: string,
  ): Promise<ProcessedNewsItem[]> {
    const localized: ProcessedNewsItem[] = [];

    for (const item of items) {
      localized.push(await this.translateForList(item, language));
    }

    return localized;
  }

  private async localizeNewsDetail(
    item: ProcessedNewsItem,
    language: string,
  ): Promise<ProcessedNewsItem> {
    const localized = await this.translateForDetail(item, language);
    this.incrementReadCount(localized.id);
    return this.withReadCount(localized);
  }

  private async translateForList(
    item: ProcessedNewsItem,
    targetLanguage: string,
  ): Promise<ProcessedNewsItem> {
    if (!this.shouldTranslate(item, targetLanguage)) {
      return this.withReadCount(item);
    }

    const memory = this.getTranslationMemory(item.id, targetLanguage);
    if (memory.title && memory.summary) {
      return this.applyTranslationMemory(item, targetLanguage, memory);
    }

    const priority = item.importanceScore >= 4 ? 'high' : 'medium';

    const originalTitle = item.title;
    const originalSummary = item.summary;

    const [titleResult, summaryResult] = await Promise.all([
      this.translateText({
        text: item.title,
        sourceLanguage: item.originalLanguage,
        targetLanguage,
        priority,
      }),
      this.translateText({
        text: item.summary,
        sourceLanguage: item.originalLanguage,
        targetLanguage,
        priority,
      }),
    ]);

    this.setTranslationMemory(item.id, targetLanguage, {
      title: titleResult.translatedText,
      summary: summaryResult.translatedText,
      provider: titleResult.model,
      quality: (titleResult.qualityScore + summaryResult.qualityScore) / 2,
      originalTitle,
      originalSummary,
      updatedAt: new Date().toISOString(),
    });

    return this.withReadCount({
      ...item,
      title: titleResult.translatedText,
      summary: summaryResult.translatedText,
      language: targetLanguage,
      isTranslated: true,
      translationProvider: titleResult.model,
      translatedContent: item.translatedContent,
    });
  }

  private async translateForDetail(
    item: ProcessedNewsItem,
    targetLanguage: string,
  ): Promise<ProcessedNewsItem> {
    if (!this.shouldTranslate(item, targetLanguage)) {
      return this.withReadCount(item);
    }

    const memory = this.getTranslationMemory(item.id, targetLanguage);

    if (memory.title && memory.summary && memory.content) {
      return this.applyTranslationMemory(item, targetLanguage, memory);
    }

    const priority = item.importanceScore >= 4 ? 'high' : 'medium';

    const originalTitle = item.title;
    const originalSummary = item.summary;
    const originalContent = item.content;

    const translationRequests: TranslationRequest[] = [
      {
        text: item.title,
        sourceLanguage: item.originalLanguage,
        targetLanguage,
        priority,
        domain: 'football',
      },
      {
        text: item.summary,
        sourceLanguage: item.originalLanguage,
        targetLanguage,
        priority,
        domain: 'football',
      },
      {
        text: item.content,
        sourceLanguage: item.originalLanguage,
        targetLanguage,
        priority,
        domain: 'football',
      },
    ];

    const [titleResult, summaryResult, contentResult] = await Promise.all(
      translationRequests.map((request) => this.translateText(request)),
    );

    this.setTranslationMemory(item.id, targetLanguage, {
      title: titleResult.translatedText,
      summary: summaryResult.translatedText,
      content: contentResult.translatedText,
      provider: titleResult.model,
      quality:
        (titleResult.qualityScore + summaryResult.qualityScore + contentResult.qualityScore) /
        3,
      originalTitle,
      originalSummary,
      originalContent,
      updatedAt: new Date().toISOString(),
    });

    return this.withReadCount({
      ...item,
      title: titleResult.translatedText,
      summary: summaryResult.translatedText,
      content: contentResult.translatedText,
      translatedContent: contentResult.translatedText,
      language: targetLanguage,
      isTranslated: true,
      translationProvider: titleResult.model,
    });
  }

  private shouldTranslate(item: ProcessedNewsItem, targetLanguage: string): boolean {
    if (!targetLanguage) {
      return false;
    }

    const normalizedTarget = targetLanguage.toLowerCase();
    const normalizedCurrent = item.language.toLowerCase();

    if (normalizedTarget === normalizedCurrent) {
      return false;
    }

    if (normalizedTarget.startsWith(item.originalLanguage.toLowerCase())) {
      return false;
    }

    return true;
  }

  private getTranslationMemory(
    id: string,
    language: string,
  ): TranslationMemoryEntry {
    const languageKey = language.toLowerCase();
    if (!this.translationMemory.has(id)) {
      this.translationMemory.set(id, new Map());
    }

    const memoryMap = this.translationMemory.get(id)!;
    const existing = memoryMap.get(languageKey);

    if (existing) {
      return existing;
    }

    const fresh: TranslationMemoryEntry = {
      updatedAt: new Date().toISOString(),
    };
    memoryMap.set(languageKey, fresh);
    return fresh;
  }

  private setTranslationMemory(
    id: string,
    language: string,
    entry: TranslationMemoryEntry,
  ): void {
    const languageKey = language.toLowerCase();
    if (!this.translationMemory.has(id)) {
      this.translationMemory.set(id, new Map());
    }

    this.translationMemory.get(id)!.set(languageKey, entry);
  }

  private applyTranslationMemory(
    item: ProcessedNewsItem,
    targetLanguage: string,
    memory: TranslationMemoryEntry,
  ): ProcessedNewsItem {
    return this.withReadCount({
      ...item,
      title: memory.title ?? item.title,
      summary: memory.summary ?? item.summary,
      content: memory.content ?? item.content,
      translatedContent: memory.content ?? item.translatedContent,
      language: targetLanguage,
      isTranslated: true,
      translationProvider: memory.provider,
    });
  }

  private async translateText(request: TranslationRequest): Promise<TranslationResult> {
    try {
      return await translationService.translate({
        domain: 'football',
        priority: request.priority ?? 'medium',
        ...request,
      });
    } catch (error) {
      console.error('翻译失败，返回原文:', error);
      return {
        translatedText: request.text,
        confidence: 0,
        model: 'fallback-original',
        processingTime: 0,
        qualityScore: 0,
        originalText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: new Date().toISOString(),
      };
    }
  }

  private toListItem(item: ProcessedNewsItem): AiNewsListItem {
    const readCount = this.getReadCount(item.id);
    const translationInfo = this.translationMemory
      .get(item.id)?.get(item.language.toLowerCase());

    return {
      id: item.id,
      title: item.title,
      summary: item.summary,
      source: item.sourceName,
      sourceId: item.sourceId,
      category: item.category,
      publishedAt: item.publishedAt,
      readCount,
      imageUrl: item.imageUrl,
      language: item.language,
      url: item.url,
      sentiment: item.sentiment,
      tags: item.tags,
      aiMeta: {
        originalLanguage: item.originalLanguage,
        isTranslated: item.isTranslated,
        translationProvider: item.translationProvider,
        translationQuality: translationInfo?.quality,
        credibilityScore: item.credibilityScore,
        importanceScore: item.importanceScore,
        entities: item.entities,
      },
    };
  }

  private toDetail(item: ProcessedNewsItem): AiNewsDetail {
    const listItem = this.toListItem(item);
    const translationInfo = this.translationMemory
      .get(item.id)?.get(item.language.toLowerCase());

    return {
      ...listItem,
      content: item.translatedContent || item.content,
      originalTitle: translationInfo?.originalTitle,
      originalSummary: translationInfo?.originalSummary,
      originalContent: item.originalContent ?? translationInfo?.originalContent,
      translatedContent: item.translatedContent,
    };
  }

  private withReadCount(item: ProcessedNewsItem): ProcessedNewsItem {
    const readCount = this.getReadCount(item.id);
    return {
      ...item,
      readCount,
    };
  }

  private getReadCount(id: string): number {
    if (this.readCountCache.has(id)) {
      return this.readCountCache.get(id)!;
    }

    const base = this.generateBaseReadCount(id);
    this.readCountCache.set(id, base);
    return base;
  }

  private incrementReadCount(id: string): void {
    const current = this.readCountCache.get(id) ?? this.generateBaseReadCount(id);
    this.readCountCache.set(id, current + 1);
  }

  private generateBaseReadCount(id: string): number {
    const hash = this.simpleHash(id);
    const base = 500 + (hash % 5000);
    return base;
  }

  private simpleHash(input: string): number {
    let hash = 0;
    for (let i = 0; i < input.length; i++) {
      const char = input.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash |= 0; // Convert to 32bit integer
    }
    return Math.abs(hash);
  }

  private calculateRelevanceScore(
    item: ProcessedNewsItem,
    keyword: string,
    tags?: string[],
  ): number {
    let score = 0;

    const lowerTitle = item.title.toLowerCase();
    const lowerSummary = item.summary.toLowerCase();
    const lowerKeyword = keyword.toLowerCase();

    if (lowerTitle.includes(lowerKeyword)) {
      score += 10;
    }

    if (lowerSummary.includes(lowerKeyword)) {
      score += 6;
    }

    if (item.tags.some((tag) => tag.toLowerCase().includes(lowerKeyword))) {
      score += 4;
    }

    if (
      item.entities.players.some((player) => player.toLowerCase().includes(lowerKeyword))
    ) {
      score += 8;
    }

    if (
      item.entities.teams.some((team) => team.toLowerCase().includes(lowerKeyword))
    ) {
      score += 8;
    }

    if (
      item.entities.leagues.some((league) => league.toLowerCase().includes(lowerKeyword))
    ) {
      score += 6;
    }

    if (tags && tags.length > 0) {
      const matchCount = tags.filter((tag) => item.tags.includes(tag)).length;
      score += matchCount * 3;
    }

    return score;
  }

  private calculateTrendingScore(item: ProcessedNewsItem): number {
    const now = Date.now();
    const publishTime = new Date(item.publishedAt).getTime();
    const hoursSincePublish = (now - publishTime) / (1000 * 60 * 60);
    const timeDecay = Math.max(0, (36 - hoursSincePublish) / 36);

    const readBoost = this.getReadCount(item.id) / 1000;
    return item.importanceScore * 0.35 +
      item.credibilityScore * 0.25 +
      timeDecay * 0.25 +
      readBoost * 0.15;
  }
}

export const aiNewsService = new AiNewsService();

