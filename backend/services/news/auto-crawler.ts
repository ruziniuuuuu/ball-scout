/**
 * 自动化新闻爬取和翻译服务
 * 定时获取最新足球新闻并自动翻译为中文
 */

import { NewsAggregator, ProcessedNewsItem } from './aggregator.ts';
import { translationService } from '../translation/service.ts';
import { cron } from '../../deps.ts';
import { config } from '../../config.ts';

export interface AutoCrawlerConfig {
  interval: number; // 爬取间隔（分钟）
  maxNewsPerRun: number; // 每次运行最大处理新闻数
  enableTranslation: boolean; // 是否启用自动翻译
  saveToDatabase: boolean; // 是否保存到数据库
  generateStatic: boolean; // 是否生成静态页面
}

export class AutoNewsCrawler {
  private aggregator: NewsAggregator;
  private isRunning = false;
  private lastRunTime: Date | null = null;
  private cronJob: any = null;
  private config: AutoCrawlerConfig;
  private processedNewsCache = new Set<string>(); // 防重复处理

  constructor(config?: Partial<AutoCrawlerConfig>) {
    this.aggregator = new NewsAggregator();
    this.config = {
      interval: 30, // 默认30分钟
      maxNewsPerRun: 50,
      enableTranslation: true,
      saveToDatabase: true,
      generateStatic: true,
      ...config,
    };
  }

  /**
   * 启动自动化爬取服务
   */
  async start(): Promise<void> {
    if (this.isRunning) {
      console.log('⚠️ 自动爬取服务已在运行中');
      return;
    }

    console.log('🚀 启动自动化新闻爬取服务...');
    console.log(`📅 爬取间隔: 每${this.config.interval}分钟`);
    console.log(`🌐 翻译服务: ${this.config.enableTranslation ? '已启用' : '已禁用'}`);

    this.isRunning = true;

    // 立即执行一次
    await this.runCrawl();

    // 设置定时任务
    this.cronJob = cron(`*/${this.config.interval} * * * *`, () => {
      this.runCrawl().catch(error => {
        console.error('❌ 定时爬取任务执行失败:', error);
      });
    });

    console.log('✅ 自动化爬取服务已启动');
  }

  /**
   * 停止自动化爬取服务
   */
  stop(): void {
    if (!this.isRunning) {
      console.log('⚠️ 自动爬取服务未在运行');
      return;
    }

    console.log('🛑 停止自动化新闻爬取服务...');
    
    if (this.cronJob) {
      this.cronJob.stop();
      this.cronJob = null;
    }

    this.isRunning = false;
    console.log('✅ 自动化爬取服务已停止');
  }

  /**
   * 执行单次爬取任务
   */
  private async runCrawl(): Promise<void> {
    const startTime = Date.now();
    console.log(`\n🔄 开始执行新闻爬取任务 - ${new Date().toLocaleString()}`);

    try {
      // 1. 获取最新新闻
      console.log('📡 正在获取最新新闻...');
      const allNews = await this.aggregator.fetchAllNews();
      
      if (allNews.length === 0) {
        console.log('⚠️ 未获取到新闻，跳过本次任务');
        return;
      }

      // 2. 过滤新的新闻（避免重复处理）
      const newNews = allNews.filter(news => !this.processedNewsCache.has(news.id));
      
      if (newNews.length === 0) {
        console.log('✅ 无新的新闻需要处理');
        return;
      }

      console.log(`📊 获取到 ${allNews.length} 条新闻，其中 ${newNews.length} 条为新新闻`);

      // 3. 限制处理数量
      const newsToProcess = newNews.slice(0, this.config.maxNewsPerRun);
      
      // 4. 翻译新闻
      if (this.config.enableTranslation) {
        console.log('🤖 开始翻译新闻...');
        await this.translateNews(newsToProcess);
      }

      // 5. 保存到数据库
      if (this.config.saveToDatabase) {
        console.log('💾 保存新闻到数据库...');
        await this.saveToDatabase(newsToProcess);
      }

      // 6. 生成静态页面
      if (this.config.generateStatic) {
        console.log('📄 生成静态页面...');
        await this.generateStaticPages(newsToProcess);
      }

      // 7. 更新缓存
      newsToProcess.forEach(news => {
        this.processedNewsCache.add(news.id);
      });

      // 清理过期缓存（保留最近1000条）
      if (this.processedNewsCache.size > 1000) {
        const cacheArray = Array.from(this.processedNewsCache);
        this.processedNewsCache.clear();
        cacheArray.slice(-800).forEach(id => this.processedNewsCache.add(id));
      }

      this.lastRunTime = new Date();
      const duration = (Date.now() - startTime) / 1000;
      
      console.log(`✅ 爬取任务完成！`);
      console.log(`📊 处理了 ${newsToProcess.length} 条新闻，耗时 ${duration.toFixed(2)}s`);

    } catch (error) {
      console.error('❌ 爬取任务执行失败:', error);
    }
  }

  /**
   * 翻译新闻内容
   */
  private async translateNews(newsList: ProcessedNewsItem[]): Promise<void> {
    const needsTranslation = newsList.filter(news => 
      news.originalLanguage !== 'zh' && !news.isTranslated
    );

    if (needsTranslation.length === 0) {
      console.log('✅ 无需翻译的新闻');
      return;
    }

    console.log(`🌐 需要翻译 ${needsTranslation.length} 条新闻`);

    // 批量处理翻译
    const batchSize = 5; // 控制并发数量
    
    for (let i = 0; i < needsTranslation.length; i += batchSize) {
      const batch = needsTranslation.slice(i, i + batchSize);
      const promises = batch.map(news => this.translateSingleNews(news));
      
      await Promise.allSettled(promises);
      
      // 防止API频率限制
      if (i + batchSize < needsTranslation.length) {
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }

    console.log('✅ 翻译任务完成');
  }

  /**
   * 翻译单条新闻
   */
  private async translateSingleNews(news: ProcessedNewsItem): Promise<void> {
    try {
      // 翻译标题
      const titleTranslation = await translationService.translate({
        text: news.title,
        sourceLanguage: news.originalLanguage,
        targetLanguage: 'zh-CN',
        domain: 'football',
        priority: news.importanceScore >= 4 ? 'high' : 'medium',
      });

      // 翻译摘要
      const summaryTranslation = await translationService.translate({
        text: news.summary,
        sourceLanguage: news.originalLanguage,
        targetLanguage: 'zh-CN',
        domain: 'football',
        priority: news.importanceScore >= 4 ? 'high' : 'medium',
      });

      // 翻译内容
      const contentTranslation = await translationService.translate({
        text: news.content,
        sourceLanguage: news.originalLanguage,
        targetLanguage: 'zh-CN',
        domain: 'football',
        priority: news.importanceScore >= 4 ? 'high' : 'medium',
      });

      // 更新新闻对象
      news.title = titleTranslation.translatedText;
      news.summary = summaryTranslation.translatedText;
      news.translatedContent = contentTranslation.translatedText;
      news.isTranslated = true;
      news.translationProvider = titleTranslation.model;
      news.language = 'zh-CN';

      console.log(`✅ 翻译完成: ${news.title.substring(0, 50)}...`);

    } catch (error) {
      console.error(`❌ 翻译失败: ${news.title.substring(0, 50)}...`, error);
      // 翻译失败时保留原文
      news.translatedContent = news.content;
      news.isTranslated = false;
    }
  }

  /**
   * 保存新闻到数据库（模拟实现）
   */
  private async saveToDatabase(newsList: ProcessedNewsItem[]): Promise<void> {
    // 这里应该实现真正的数据库保存逻辑
    // 暂时只是日志输出
    console.log(`📊 模拟保存 ${newsList.length} 条新闻到数据库`);
    
    for (const news of newsList) {
      console.log(`💾 [${news.category}] ${news.title.substring(0, 50)}...`);
    }
  }

  /**
   * 生成静态页面
   */
  private async generateStaticPages(newsList: ProcessedNewsItem[]): Promise<void> {
    // 这里将实现静态页面生成逻辑
    console.log(`📄 准备生成 ${newsList.length} 条新闻的静态页面`);
    
    // 创建静态页面目录
    try {
      await Deno.mkdir('./static/news', { recursive: true });
    } catch (error) {
      // 目录可能已存在
    }

    // 生成主页
    await this.generateMainPage(newsList);
    
    // 生成新闻详情页
    for (const news of newsList) {
      await this.generateNewsPage(news);
    }

    console.log('✅ 静态页面生成完成');
  }

  /**
   * 生成主页HTML
   */
  private async generateMainPage(newsList: ProcessedNewsItem[]): Promise<void> {
    const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>球探社 - 最新足球资讯</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 40px; }
        .news-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .news-card { background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .news-image { width: 100%; height: 200px; object-fit: cover; }
        .news-content { padding: 20px; }
        .news-title { font-size: 18px; font-weight: bold; margin-bottom: 10px; color: #333; }
        .news-summary { color: #666; line-height: 1.5; margin-bottom: 15px; }
        .news-meta { display: flex; justify-content: space-between; align-items: center; color: #999; font-size: 14px; }
        .category { background: #007bff; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
        .update-time { text-align: center; margin-top: 40px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚽ 球探社</h1>
            <p>全球足球资讯，AI智能翻译</p>
        </div>
        
        <div class="news-grid">
            ${newsList.map(news => `
                <article class="news-card">
                    ${news.imageUrl ? `<img src="${news.imageUrl}" alt="${news.title}" class="news-image">` : ''}
                    <div class="news-content">
                        <h2 class="news-title">${news.title}</h2>
                        <p class="news-summary">${news.summary}</p>
                        <div class="news-meta">
                            <span class="category">${this.getCategoryName(news.category)}</span>
                            <span>${news.sourceName}</span>
                            <span>${new Date(news.publishedAt).toLocaleDateString('zh-CN')}</span>
                        </div>
                    </div>
                </article>
            `).join('')}
        </div>
        
        <div class="update-time">
            <p>最后更新: ${new Date().toLocaleString('zh-CN')}</p>
            <p>由 DeepSeek AI 提供翻译支持</p>
        </div>
    </div>
</body>
</html>`;

    await Deno.writeTextFile('./static/index.html', html);
    console.log('📄 主页生成完成: ./static/index.html');
  }

  /**
   * 生成新闻详情页
   */
  private async generateNewsPage(news: ProcessedNewsItem): Promise<void> {
    const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${news.title} - 球探社</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .back-link { color: #007bff; text-decoration: none; margin-bottom: 20px; display: inline-block; }
        .news-header { margin-bottom: 30px; }
        .news-title { font-size: 28px; font-weight: bold; margin-bottom: 15px; color: #333; }
        .news-meta { color: #666; margin-bottom: 20px; }
        .news-image { width: 100%; max-height: 400px; object-fit: cover; border-radius: 8px; margin-bottom: 30px; }
        .news-content { line-height: 1.8; color: #333; }
        .tags { margin-top: 30px; }
        .tag { background: #e9ecef; color: #495057; padding: 4px 8px; border-radius: 4px; font-size: 12px; margin-right: 8px; }
        .source-info { margin-top: 40px; padding-top: 20px; border-top: 1px solid #eee; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <a href="../index.html" class="back-link">← 返回首页</a>
        
        <div class="news-header">
            <h1 class="news-title">${news.title}</h1>
            <div class="news-meta">
                <span>${news.sourceName}</span> • 
                <span>${new Date(news.publishedAt).toLocaleString('zh-CN')}</span> • 
                <span>${this.getCategoryName(news.category)}</span>
            </div>
        </div>
        
        ${news.imageUrl ? `<img src="${news.imageUrl}" alt="${news.title}" class="news-image">` : ''}
        
        <div class="news-content">
            ${news.translatedContent || news.content}
        </div>
        
        ${news.tags.length > 0 ? `
            <div class="tags">
                ${news.tags.map(tag => `<span class="tag">${tag}</span>`).join('')}
            </div>
        ` : ''}
        
        <div class="source-info">
            <p>原文链接: <a href="${news.url}" target="_blank">${news.url}</a></p>
            ${news.isTranslated ? `<p>翻译提供者: ${news.translationProvider}</p>` : ''}
            <p>置信度评分: ${news.credibilityScore.toFixed(2)} | 重要性评分: ${news.importanceScore}/5</p>
        </div>
    </div>
</body>
</html>`;

    const filename = `${news.id}.html`;
    await Deno.writeTextFile(`./static/news/${filename}`, html);
  }

  /**
   * 获取分类中文名称
   */
  private getCategoryName(category: string): string {
    const categoryMap: Record<string, string> = {
      transfer: '转会',
      match: '比赛',
      news: '新闻',
      analysis: '分析',
      rumor: '传言',
      injury: '伤病',
    };
    return categoryMap[category] || category;
  }

  /**
   * 获取服务状态
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      lastRunTime: this.lastRunTime,
      config: this.config,
      processedCount: this.processedNewsCache.size,
      translationServiceStatus: translationService.getStatus(),
    };
  }
}

// 创建全局实例
export const autoNewsCrawler = new AutoNewsCrawler(); 