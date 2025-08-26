import { TranslationCache } from './types.ts';

export class TranslationCacheService {
  private cache = new Map<string, TranslationCache>();
  private readonly maxCacheSize = 10000;
  private readonly defaultTTL = 24 * 60 * 60 * 1000; // 24小时

  /**
   * 生成缓存键
   */
  private generateCacheKey(
    text: string,
    sourceLanguage: string,
    targetLanguage: string,
  ): string {
    const content = `${sourceLanguage}-${targetLanguage}-${text}`;
    // 简单的哈希函数（生产环境应使用更强的哈希算法）
    let hash = 0;
    for (let i = 0; i < content.length; i++) {
      const char = content.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // 转换为32位整数
    }
    return Math.abs(hash).toString(36);
  }

  /**
   * 获取缓存
   */
  async get(
    text: string,
    sourceLanguage: string,
    targetLanguage: string,
  ): Promise<TranslationCache | null> {
    const key = this.generateCacheKey(text, sourceLanguage, targetLanguage);
    const cached = this.cache.get(key);

    if (!cached) {
      return null;
    }

    // 检查是否过期
    if (new Date(cached.expiresAt) < new Date()) {
      this.cache.delete(key);
      return null;
    }

    // 增加命中次数
    cached.hitCount++;
    this.cache.set(key, cached);

    return cached;
  }

  /**
   * 设置缓存
   */
  async set(
    text: string,
    translatedText: string,
    sourceLanguage: string,
    targetLanguage: string,
    ttl?: number,
  ): Promise<void> {
    const key = this.generateCacheKey(text, sourceLanguage, targetLanguage);
    const expiresAt = new Date(Date.now() + (ttl || this.defaultTTL));

    const cacheEntry: TranslationCache = {
      key,
      text,
      translatedText,
      sourceLanguage,
      targetLanguage,
      createdAt: new Date().toISOString(),
      expiresAt: expiresAt.toISOString(),
      hitCount: 0,
    };

    // 如果缓存已满，删除最久未使用的条目
    if (this.cache.size >= this.maxCacheSize) {
      this.evictLeastRecentlyUsed();
    }

    this.cache.set(key, cacheEntry);
  }

  /**
   * 清理过期缓存
   */
  async cleanup(): Promise<void> {
    const now = new Date();
    const expiredKeys: string[] = [];

    for (const [key, entry] of this.cache.entries()) {
      if (new Date(entry.expiresAt) < now) {
        expiredKeys.push(key);
      }
    }

    for (const key of expiredKeys) {
      this.cache.delete(key);
    }
  }

  /**
   * 删除最久未使用的缓存项
   */
  private evictLeastRecentlyUsed(): void {
    let oldestKey: string | null = null;
    let oldestTime = Date.now();

    for (const [key, entry] of this.cache.entries()) {
      const createdTime = new Date(entry.createdAt).getTime();
      if (createdTime < oldestTime) {
        oldestTime = createdTime;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      this.cache.delete(oldestKey);
    }
  }

  /**
   * 获取缓存统计信息
   */
  getStats() {
    const totalEntries = this.cache.size;
    let totalHits = 0;
    let totalSize = 0;

    for (const entry of this.cache.values()) {
      totalHits += entry.hitCount;
      totalSize += entry.text.length + entry.translatedText.length;
    }

    return {
      totalEntries,
      totalHits,
      totalSize,
      maxSize: this.maxCacheSize,
      hitRate: totalEntries > 0 ? totalHits / totalEntries : 0,
    };
  }

  /**
   * 清空所有缓存
   */
  clear(): void {
    this.cache.clear();
  }
}

// 全局缓存实例
export const translationCache = new TranslationCacheService();
