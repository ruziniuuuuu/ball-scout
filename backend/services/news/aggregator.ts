/**
 * 新闻聚合服务
 * 集成多个真实新闻源，提供统一的新闻数据接口
 */

import { DOMParser, fetchWithTimeout, parseXml } from '../../deps.ts';

export interface NewsSource {
  id: string;
  name: string;
  baseUrl: string;
  apiKey?: string;
  rateLimit: number; // 每分钟请求数限制
}

export interface RawNewsItem {
  title: string;
  description: string;
  content: string;
  url: string;
  publishedAt: string;
  author?: string;
  imageUrl?: string;
  category?: string;
  language: 'en' | 'zh' | 'es' | 'fr';
  sourceId: string;
}

export interface ProcessedNewsItem {
  id: string;
  title: string;
  summary: string;
  content: string;
  originalContent?: string;
  translatedContent?: string;
  url: string;
  publishedAt: string;
  author?: string;
  imageUrl?: string;
  category: 'transfer' | 'match' | 'news' | 'analysis' | 'rumor' | 'injury';
  subCategory?: string;
  language: string;
  originalLanguage: string;
  sourceId: string;
  sourceName: string;
  credibilityScore: number; // 0-1，基于来源可信度
  importanceScore: number; // 1-5，内容重要性评分
  readCount: number;
  entities: {
    players: string[];
    teams: string[];
    leagues: string[];
    competitions: string[];
  };
  sentiment: 'positive' | 'negative' | 'neutral';
  tags: string[];
  isTranslated: boolean;
  translationProvider?: string;
  createdAt: string;
  updatedAt: string;
}

/**
 * 新闻源配置
 */
export const NEWS_SOURCES: NewsSource[] = [
  {
    id: 'bbc_sport',
    name: 'BBC Sport',
    baseUrl: 'https://feeds.bbci.co.uk/sport/football/rss.xml',
    rateLimit: 60, // BBC RSS 没有严格限制
  },
  {
    id: 'espn_soccer',
    name: 'ESPN Soccer',
    baseUrl: 'https://www.espn.com/soccer/rss',
    rateLimit: 100,
  },
  {
    id: 'goal_com',
    name: 'Goal.com',
    baseUrl: 'https://www.goal.com/feeds/news',
    rateLimit: 120,
  },
  {
    id: 'sky_sports',
    name: 'Sky Sports Football',
    baseUrl: 'https://www.skysports.com/rss/football',
    rateLimit: 100,
  },
  {
    id: 'marca',
    name: 'Marca',
    baseUrl:
      'https://feeds.marca.com/marca/rss/futbol/primera-division/rss.xml',
    rateLimit: 80,
  },
];

/**
 * 新闻聚合器类
 */
export class NewsAggregator {
  private cache = new Map<string, ProcessedNewsItem[]>();
  private lastFetchTime = new Map<string, number>();
  private rateLimitCounters = new Map<string, number>();

  constructor() {
    // 每分钟重置速率限制计数器
    setInterval(() => {
      this.rateLimitCounters.clear();
    }, 60 * 1000);
  }

  /**
   * 从所有新闻源获取最新新闻
   */
  async fetchAllNews(): Promise<ProcessedNewsItem[]> {
    const allNews: ProcessedNewsItem[] = [];

    for (const source of NEWS_SOURCES) {
      try {
        const newsItems = await this.fetchFromSource(source);
        allNews.push(...newsItems);
      } catch (error) {
        console.error(`从 ${source.name} 获取新闻失败:`, error);
      }
    }

    // 按发布时间排序，去重，评分
    const processedNews = this.deduplicateAndRank(allNews);

    return processedNews;
  }

  /**
   * 从特定新闻源获取新闻
   */
  async fetchFromSource(source: NewsSource): Promise<ProcessedNewsItem[]> {
    // 检查速率限制
    const currentCount = this.rateLimitCounters.get(source.id) || 0;
    if (currentCount >= source.rateLimit) {
      console.warn(`${source.name} 达到速率限制，跳过此次请求`);
      return this.cache.get(source.id) || [];
    }

    // 检查缓存（10分钟内不重复请求）
    const lastFetch = this.lastFetchTime.get(source.id) || 0;
    const now = Date.now();
    if (now - lastFetch < 10 * 60 * 1000) {
      return this.cache.get(source.id) || [];
    }

    try {
      console.log(`正在从 ${source.name} 获取新闻...`);

      // 更新速率限制计数器
      this.rateLimitCounters.set(source.id, currentCount + 1);
      this.lastFetchTime.set(source.id, now);

      let rawNews: RawNewsItem[] = [];

      // 根据不同源使用不同的获取策略
      switch (source.id) {
        case 'bbc_sport':
          rawNews = await this.fetchFromBBCRSS(source);
          break;
        case 'espn_soccer':
          rawNews = await this.fetchFromESPNRSS(source);
          break;
        case 'goal_com':
          rawNews = await this.fetchFromGoalRSS(source);
          break;
        case 'sky_sports':
          rawNews = await this.fetchFromSkyRSS(source);
          break;
        case 'marca':
          rawNews = await this.fetchFromMarcaRSS(source);
          break;
        default:
          console.warn(`未知的新闻源: ${source.id}`);
          return [];
      }

      // 处理原始新闻数据
      const processedNews = await this.processRawNews(rawNews, source);

      // 缓存结果
      this.cache.set(source.id, processedNews);

      console.log(`从 ${source.name} 获取了 ${processedNews.length} 条新闻`);
      return processedNews;
    } catch (error) {
      console.error(`从 ${source.name} 获取新闻时出错:`, error);
      return this.cache.get(source.id) || [];
    }
  }

  /**
   * 从BBC Sport RSS获取新闻
   */
  private async fetchFromBBCRSS(source: NewsSource): Promise<RawNewsItem[]> {
    try {
      console.log(`📡 正在获取BBC Sport RSS: ${source.baseUrl}`);
      const response = await fetchWithTimeout(source.baseUrl, {
        timeout: 15000,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const xmlText = await response.text();
      const items = this.parseRSSItems(xmlText);

      return items.map((item) => ({
        title: this.cleanText(item.title),
        description: this.cleanText(item.description),
        content: this.cleanText(item.description),
        url: item.link,
        publishedAt: item.pubDate,
        author: 'BBC Sport',
        imageUrl: item.enclosure?.url || item.image,
        category: this.categorizeNews(item.title, item.description),
        language: 'en' as const,
        sourceId: source.id,
      }));
    } catch (error) {
      console.error(`❌ BBC RSS解析失败:`, error);
      return [];
    }
  }

  /**
   * 从ESPN RSS获取新闻
   */
  private async fetchFromESPNRSS(source: NewsSource): Promise<RawNewsItem[]> {
    try {
      console.log(`📡 正在获取ESPN Soccer RSS: ${source.baseUrl}`);
      const response = await fetchWithTimeout(source.baseUrl, {
        timeout: 15000,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const xmlText = await response.text();
      const items = this.parseRSSItems(xmlText);

      return items.map((item) => ({
        title: this.cleanText(item.title),
        description: this.cleanText(item.description),
        content: this.cleanText(item.description),
        url: item.link,
        publishedAt: item.pubDate,
        author: 'ESPN Soccer',
        imageUrl: item.enclosure?.url || item.image,
        category: this.categorizeNews(item.title, item.description),
        language: 'en' as const,
        sourceId: source.id,
      }));
    } catch (error) {
      console.error(`❌ ESPN RSS解析失败:`, error);
      return [];
    }
  }

  /**
   * 从Goal.com RSS获取新闻
   */
  private async fetchFromGoalRSS(source: NewsSource): Promise<RawNewsItem[]> {
    try {
      console.log(`📡 正在获取Goal.com RSS: ${source.baseUrl}`);
      const response = await fetchWithTimeout(source.baseUrl, {
        timeout: 15000,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const xmlText = await response.text();
      const items = this.parseRSSItems(xmlText);

      return items.map((item) => ({
        title: this.cleanText(item.title),
        description: this.cleanText(item.description),
        content: this.cleanText(item.description),
        url: item.link,
        publishedAt: item.pubDate,
        author: 'Goal.com',
        imageUrl: item.enclosure?.url || item.image,
        category: this.categorizeNews(item.title, item.description),
        language: 'en' as const,
        sourceId: source.id,
      }));
    } catch (error) {
      console.error(`❌ Goal.com RSS解析失败:`, error);
      return [];
    }
  }

  /**
   * 从Sky Sports RSS获取新闻
   */
  private async fetchFromSkyRSS(source: NewsSource): Promise<RawNewsItem[]> {
    try {
      console.log(`📡 正在获取Sky Sports RSS: ${source.baseUrl}`);
      const response = await fetchWithTimeout(source.baseUrl, {
        timeout: 15000,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const xmlText = await response.text();
      const items = this.parseRSSItems(xmlText);

      return items.map((item) => ({
        title: this.cleanText(item.title),
        description: this.cleanText(item.description),
        content: this.cleanText(item.description),
        url: item.link,
        publishedAt: item.pubDate,
        author: 'Sky Sports',
        imageUrl: item.enclosure?.url || item.image,
        category: this.categorizeNews(item.title, item.description),
        language: 'en' as const,
        sourceId: source.id,
      }));
    } catch (error) {
      console.error(`❌ Sky Sports RSS解析失败:`, error);
      return [];
    }
  }

  /**
   * 从Marca RSS获取新闻（西班牙语）
   */
  private async fetchFromMarcaRSS(source: NewsSource): Promise<RawNewsItem[]> {
    try {
      console.log(`📡 正在获取Marca RSS: ${source.baseUrl}`);
      const response = await fetchWithTimeout(source.baseUrl, {
        timeout: 15000,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const xmlText = await response.text();
      const items = this.parseRSSItems(xmlText);

      return items.map((item) => ({
        title: this.cleanText(item.title),
        description: this.cleanText(item.description),
        content: this.cleanText(item.description),
        url: item.link,
        publishedAt: item.pubDate,
        author: 'Marca',
        imageUrl: item.enclosure?.url || item.image,
        category: this.categorizeNews(item.title, item.description),
        language: 'es' as const, // 西班牙语
        sourceId: source.id,
      }));
    } catch (error) {
      console.error(`❌ Marca RSS解析失败:`, error);
      return [];
    }
  }

  /**
   * 专业的RSS解析功能
   */
  private parseRSSItems(xmlText: string): any[] {
    try {
      const doc = parseXml(xmlText);
      const items: any[] = [];

      // 解析RSS 2.0格式
      const rssItems = doc.rss?.channel?.item || [];
      const feedItems = doc.feed?.entry || []; // Atom格式支持

      const allItems = Array.isArray(rssItems) ? rssItems : [rssItems];

      for (const item of allItems.filter(Boolean)) {
        const parsedItem = {
          title: this.extractTextContent(item.title),
          description: this.extractTextContent(item.description) ||
            this.extractTextContent(item.summary),
          link: this.extractTextContent(item.link) || item.link?.['@href'],
          pubDate: this.extractTextContent(item.pubDate) ||
            this.extractTextContent(item.published),
          author: this.extractTextContent(item.author) ||
            this.extractTextContent(item['dc:creator']),
          guid: this.extractTextContent(item.guid),
          category: this.extractTextContent(item.category),
          enclosure: item.enclosure
            ? {
              url: item.enclosure['@url'],
              type: item.enclosure['@type'],
              length: item.enclosure['@length'],
            }
            : null,
          image: this.extractImageUrl(item),
        };

        if (parsedItem.title && parsedItem.link) {
          items.push(parsedItem);
        }
      }

      console.log(`✅ 成功解析 ${items.length} 条RSS项目`);
      return items;
    } catch (error) {
      console.error('❌ XML解析失败，尝试DOM解析:', error);
      return this.fallbackParseRSS(xmlText);
    }
  }

  /**
   * 提取文本内容，处理CDATA等情况
   */
  private extractTextContent(element: any): string {
    if (!element) return '';

    if (typeof element === 'string') {
      return this.cleanText(element);
    }

    if (element['#text']) {
      return this.cleanText(element['#text']);
    }

    if (element['$']) {
      return this.cleanText(element['$']);
    }

    return '';
  }

  /**
   * 提取图片URL
   */
  private extractImageUrl(item: any): string | null {
    // 尝试多种可能的图片字段
    if (
      item.enclosure?.['@url'] && item.enclosure?.['@type']?.includes('image')
    ) {
      return item.enclosure['@url'];
    }

    if (item['media:thumbnail']?.['@url']) {
      return item['media:thumbnail']['@url'];
    }

    if (item['media:content']?.['@url']) {
      return item['media:content']['@url'];
    }

    // 从描述中提取图片
    const description = this.extractTextContent(item.description);
    const imgMatch = description.match(/<img[^>]+src="([^"]+)"/i);
    if (imgMatch) {
      return imgMatch[1];
    }

    return null;
  }

  /**
   * 备用RSS解析（使用DOM解析）
   */
  private fallbackParseRSS(xmlText: string): any[] {
    try {
      const parser = new DOMParser();
      const doc = parser.parseFromString(xmlText, 'text/xml');
      const items: any[] = [];

      const itemElements = doc.querySelectorAll('item');

      for (const item of itemElements) {
        const parsedItem = {
          title: item.querySelector('title')?.textContent?.trim() || '',
          description: item.querySelector('description')?.textContent?.trim() ||
            '',
          link: item.querySelector('link')?.textContent?.trim() || '',
          pubDate: item.querySelector('pubDate')?.textContent?.trim() || '',
          author: item.querySelector('author')?.textContent?.trim() || '',
          guid: item.querySelector('guid')?.textContent?.trim() || '',
          category: item.querySelector('category')?.textContent?.trim() || '',
          enclosure: null,
          image: null,
        };

        // 处理enclosure
        const enclosureEl = item.querySelector('enclosure');
        if (enclosureEl) {
          parsedItem.enclosure = {
            url: enclosureEl.getAttribute('url'),
            type: enclosureEl.getAttribute('type'),
            length: enclosureEl.getAttribute('length'),
          };
        }

        if (parsedItem.title && parsedItem.link) {
          items.push(parsedItem);
        }
      }

      console.log(`✅ DOM备用解析成功解析 ${items.length} 条RSS项目`);
      return items;
    } catch (error) {
      console.error('❌ DOM备用解析也失败:', error);
      return [];
    }
  }

  /**
   * 清理文本内容
   */
  private cleanText(text: string): string {
    if (!text) return '';

    return text
      .replace(/<!\[CDATA\[(.*?)\]\]>/gs, '$1') // 移除CDATA
      .replace(/<[^>]*>/g, '') // 移除HTML标签
      .replace(/&nbsp;/g, ' ') // 替换HTML实体
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/\s+/g, ' ') // 规范化空白字符
      .trim();
  }

  /**
   * 新闻分类
   */
  private categorizeNews(title: string, description: string): string {
    const text = (title + ' ' + description).toLowerCase();

    if (
      text.includes('transfer') || text.includes('签约') ||
      text.includes('转会')
    ) {
      return 'transfer';
    }
    if (
      text.includes('match') || text.includes('vs') || text.includes('比赛')
    ) {
      return 'match';
    }
    if (
      text.includes('injury') || text.includes('injured') ||
      text.includes('伤病')
    ) {
      return 'injury';
    }
    if (
      text.includes('rumor') || text.includes('传言') || text.includes('据悉')
    ) {
      return 'rumor';
    }
    if (
      text.includes('analysis') || text.includes('分析') ||
      text.includes('review')
    ) {
      return 'analysis';
    }

    return 'news';
  }

  /**
   * 处理原始新闻数据
   */
  private async processRawNews(
    rawNews: RawNewsItem[],
    source: NewsSource,
  ): Promise<ProcessedNewsItem[]> {
    const processedNews: ProcessedNewsItem[] = [];

    for (const raw of rawNews) {
      try {
        const processed: ProcessedNewsItem = {
          id: this.generateNewsId(raw),
          title: raw.title,
          summary: raw.description.substring(0, 200) + '...',
          content: raw.content,
          originalContent: raw.content,
          url: raw.url,
          publishedAt: this.parseDate(raw.publishedAt),
          author: raw.author,
          imageUrl: raw.imageUrl,
          category: raw.category as any || 'news',
          language: raw.language === 'en' ? 'en' : 'zh', // 暂时简化
          originalLanguage: raw.language,
          sourceId: raw.sourceId,
          sourceName: source.name,
          credibilityScore: this.calculateCredibilityScore(source),
          importanceScore: this.calculateImportanceScore(raw),
          readCount: 0,
          entities: this.extractEntities(raw.title + ' ' + raw.description),
          sentiment: this.analyzeSentiment(raw.title + ' ' + raw.description),
          tags: this.generateTags(raw),
          isTranslated: false,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        };

        processedNews.push(processed);
      } catch (error) {
        console.error('处理新闻项目时出错:', error);
      }
    }

    return processedNews;
  }

  /**
   * 生成新闻ID
   */
  private generateNewsId(raw: RawNewsItem): string {
    // 使用URL和标题生成唯一ID
    const hash = btoa(raw.url + raw.title).replace(/[^a-zA-Z0-9]/g, '')
      .substring(0, 16);
    return `news_${raw.sourceId}_${hash}`;
  }

  /**
   * 解析日期
   */
  private parseDate(dateString: string): string {
    try {
      return new Date(dateString).toISOString();
    } catch {
      return new Date().toISOString();
    }
  }

  /**
   * 计算来源可信度分数
   */
  private calculateCredibilityScore(source: NewsSource): number {
    const credibilityMap: Record<string, number> = {
      bbc_sport: 0.95,
      espn_soccer: 0.90,
      sky_sports: 0.88,
      goal_com: 0.75,
      marca: 0.80,
    };

    return credibilityMap[source.id] || 0.5;
  }

  /**
   * 计算重要性分数
   */
  private calculateImportanceScore(raw: RawNewsItem): number {
    const text = (raw.title + ' ' + raw.description).toLowerCase();
    let score = 1;

    // 根据关键词提升重要性
    if (
      text.includes('messi') || text.includes('ronaldo') ||
      text.includes('梅西') || text.includes('C罗')
    ) score += 2;
    if (
      text.includes('champions league') || text.includes('世界杯') ||
      text.includes('欧冠')
    ) score += 2;
    if (
      text.includes('real madrid') || text.includes('barcelona') ||
      text.includes('皇马') || text.includes('巴萨')
    ) score += 1;
    if (text.includes('transfer') || text.includes('转会')) score += 1;
    if (text.includes('injury') || text.includes('伤病')) score += 1;

    return Math.min(score, 5);
  }

  /**
   * 提取实体
   */
  private extractEntities(text: string): ProcessedNewsItem['entities'] {
    // 这里应该使用NLP库，暂时使用简单的关键词匹配
    const teams = [
      'Real Madrid',
      'Barcelona',
      'Manchester United',
      'Liverpool',
      'Arsenal',
      'Chelsea',
      'Manchester City',
      'Bayern Munich',
      'PSG',
      'Juventus',
    ];
    const players = [
      'Messi',
      'Ronaldo',
      'Mbappé',
      'Haaland',
      'Benzema',
      'Lewandowski',
    ];
    const leagues = [
      'Premier League',
      'La Liga',
      'Serie A',
      'Bundesliga',
      'Champions League',
    ];

    return {
      teams: teams.filter((team) =>
        text.toLowerCase().includes(team.toLowerCase())
      ),
      players: players.filter((player) =>
        text.toLowerCase().includes(player.toLowerCase())
      ),
      leagues: leagues.filter((league) =>
        text.toLowerCase().includes(league.toLowerCase())
      ),
      competitions: [],
    };
  }

  /**
   * 分析情感
   */
  private analyzeSentiment(text: string): 'positive' | 'negative' | 'neutral' {
    const positiveWords = [
      'great',
      'excellent',
      'amazing',
      'victory',
      'win',
      'success',
    ];
    const negativeWords = [
      'terrible',
      'awful',
      'loss',
      'injury',
      'defeat',
      'crisis',
    ];

    const lowerText = text.toLowerCase();
    const positiveCount =
      positiveWords.filter((word) => lowerText.includes(word)).length;
    const negativeCount =
      negativeWords.filter((word) => lowerText.includes(word)).length;

    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }

  /**
   * 生成标签
   */
  private generateTags(raw: RawNewsItem): string[] {
    const tags: string[] = [];
    const text = (raw.title + ' ' + raw.description).toLowerCase();

    if (text.includes('transfer')) tags.push('转会');
    if (text.includes('goal')) tags.push('进球');
    if (text.includes('champions league')) tags.push('欧冠');
    if (text.includes('premier league')) tags.push('英超');
    if (text.includes('la liga')) tags.push('西甲');

    return tags;
  }

  /**
   * 去重和排序
   */
  private deduplicateAndRank(
    allNews: ProcessedNewsItem[],
  ): ProcessedNewsItem[] {
    // 按标题相似度去重
    const uniqueNews = new Map<string, ProcessedNewsItem>();

    for (const news of allNews) {
      const key = this.generateDeduplicationKey(news.title);

      if (
        !uniqueNews.has(key) ||
        uniqueNews.get(key)!.credibilityScore < news.credibilityScore
      ) {
        uniqueNews.set(key, news);
      }
    }

    // 按重要性和时间排序
    return Array.from(uniqueNews.values())
      .sort((a, b) => {
        const scoreA = a.importanceScore * 0.6 + a.credibilityScore * 0.4;
        const scoreB = b.importanceScore * 0.6 + b.credibilityScore * 0.4;

        if (scoreA !== scoreB) {
          return scoreB - scoreA; // 高分在前
        }

        return new Date(b.publishedAt).getTime() -
          new Date(a.publishedAt).getTime(); // 新的在前
      });
  }

  /**
   * 生成去重键
   */
  private generateDeduplicationKey(title: string): string {
    return title.toLowerCase()
      .replace(/[^a-zA-Z0-9\s]/g, '')
      .split(' ')
      .filter((word) => word.length > 3)
      .slice(0, 5)
      .join('_');
  }
}
