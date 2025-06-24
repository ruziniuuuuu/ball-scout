/**
 * 新闻聚合服务
 * 集成多个真实新闻源，提供统一的新闻数据接口
 */

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
    baseUrl: 'https://feeds.marca.com/marca/rss/futbol/primera-division/rss.xml',
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
      const response = await fetch(source.baseUrl);
      const xmlText = await response.text();
      
      // 简单的RSS解析（实际项目中应使用专门的XML解析库）
      const items = this.parseRSSItems(xmlText);
      
      return items.map(item => ({
        title: item.title,
        description: item.description,
        content: item.description, // RSS通常只有摘要
        url: item.link,
        publishedAt: item.pubDate,
        author: 'BBC Sport',
        imageUrl: item.image,
        category: this.categorizeNews(item.title, item.description),
        language: 'en',
        sourceId: source.id,
      }));
    } catch (error) {
      console.error('BBC RSS解析失败:', error);
      return [];
    }
  }

  /**
   * 从ESPN RSS获取新闻
   */
  private async fetchFromESPNRSS(source: NewsSource): Promise<RawNewsItem[]> {
    // 类似BBC的实现
    return [];
  }

  /**
   * 从Goal.com RSS获取新闻
   */
  private async fetchFromGoalRSS(source: NewsSource): Promise<RawNewsItem[]> {
    // 类似实现
    return [];
  }

  /**
   * 从Sky Sports RSS获取新闻
   */
  private async fetchFromSkyRSS(source: NewsSource): Promise<RawNewsItem[]> {
    // 类似实现
    return [];
  }

  /**
   * 从Marca RSS获取新闻
   */
  private async fetchFromMarcaRSS(source: NewsSource): Promise<RawNewsItem[]> {
    // 类似实现，西班牙语内容
    return [];
  }

  /**
   * 简单的RSS解析
   */
  private parseRSSItems(xmlText: string): any[] {
    const items: any[] = [];
    
    // 这里应该使用专门的XML解析库，比如 fast-xml-parser
    // 为了演示，我们使用简单的正则表达式
    const itemRegex = /<item>(.*?)<\/item>/gs;
    const matches = xmlText.matchAll(itemRegex);
    
    for (const match of matches) {
      const itemXml = match[1];
      const item = {
        title: this.extractTagContent(itemXml, 'title'),
        description: this.extractTagContent(itemXml, 'description'),
        link: this.extractTagContent(itemXml, 'link'),
        pubDate: this.extractTagContent(itemXml, 'pubDate'),
        image: this.extractTagContent(itemXml, 'enclosure') || this.extractTagContent(itemXml, 'media:thumbnail'),
      };
      items.push(item);
    }
    
    return items;
  }

  /**
   * 提取XML标签内容
   */
  private extractTagContent(xml: string, tagName: string): string {
    const regex = new RegExp(`<${tagName}[^>]*>(.*?)<\/${tagName}>`, 's');
    const match = xml.match(regex);
    return match ? match[1].trim() : '';
  }

  /**
   * 新闻分类
   */
  private categorizeNews(title: string, description: string): string {
    const text = (title + ' ' + description).toLowerCase();
    
    if (text.includes('transfer') || text.includes('签约') || text.includes('转会')) {
      return 'transfer';
    }
    if (text.includes('match') || text.includes('vs') || text.includes('比赛')) {
      return 'match';
    }
    if (text.includes('injury') || text.includes('injured') || text.includes('伤病')) {
      return 'injury';
    }
    if (text.includes('rumor') || text.includes('传言') || text.includes('据悉')) {
      return 'rumor';
    }
    if (text.includes('analysis') || text.includes('分析') || text.includes('review')) {
      return 'analysis';
    }
    
    return 'news';
  }

  /**
   * 处理原始新闻数据
   */
  private async processRawNews(rawNews: RawNewsItem[], source: NewsSource): Promise<ProcessedNewsItem[]> {
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
    const hash = btoa(raw.url + raw.title).replace(/[^a-zA-Z0-9]/g, '').substring(0, 16);
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
    if (text.includes('messi') || text.includes('ronaldo') || text.includes('梅西') || text.includes('C罗')) score += 2;
    if (text.includes('champions league') || text.includes('世界杯') || text.includes('欧冠')) score += 2;
    if (text.includes('real madrid') || text.includes('barcelona') || text.includes('皇马') || text.includes('巴萨')) score += 1;
    if (text.includes('transfer') || text.includes('转会')) score += 1;
    if (text.includes('injury') || text.includes('伤病')) score += 1;

    return Math.min(score, 5);
  }

  /**
   * 提取实体
   */
  private extractEntities(text: string): ProcessedNewsItem['entities'] {
    // 这里应该使用NLP库，暂时使用简单的关键词匹配
    const teams = ['Real Madrid', 'Barcelona', 'Manchester United', 'Liverpool', 'Arsenal', 'Chelsea', 'Manchester City', 'Bayern Munich', 'PSG', 'Juventus'];
    const players = ['Messi', 'Ronaldo', 'Mbappé', 'Haaland', 'Benzema', 'Lewandowski'];
    const leagues = ['Premier League', 'La Liga', 'Serie A', 'Bundesliga', 'Champions League'];

    return {
      teams: teams.filter(team => text.toLowerCase().includes(team.toLowerCase())),
      players: players.filter(player => text.toLowerCase().includes(player.toLowerCase())),
      leagues: leagues.filter(league => text.toLowerCase().includes(league.toLowerCase())),
      competitions: [],
    };
  }

  /**
   * 分析情感
   */
  private analyzeSentiment(text: string): 'positive' | 'negative' | 'neutral' {
    const positiveWords = ['great', 'excellent', 'amazing', 'victory', 'win', 'success'];
    const negativeWords = ['terrible', 'awful', 'loss', 'injury', 'defeat', 'crisis'];

    const lowerText = text.toLowerCase();
    const positiveCount = positiveWords.filter(word => lowerText.includes(word)).length;
    const negativeCount = negativeWords.filter(word => lowerText.includes(word)).length;

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
  private deduplicateAndRank(allNews: ProcessedNewsItem[]): ProcessedNewsItem[] {
    // 按标题相似度去重
    const uniqueNews = new Map<string, ProcessedNewsItem>();
    
    for (const news of allNews) {
      const key = this.generateDeduplicationKey(news.title);
      
      if (!uniqueNews.has(key) || 
          uniqueNews.get(key)!.credibilityScore < news.credibilityScore) {
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
        
        return new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime(); // 新的在前
      });
  }

  /**
   * 生成去重键
   */
  private generateDeduplicationKey(title: string): string {
    return title.toLowerCase()
      .replace(/[^a-zA-Z0-9\s]/g, '')
      .split(' ')
      .filter(word => word.length > 3)
      .slice(0, 5)
      .join('_');
  }
} 