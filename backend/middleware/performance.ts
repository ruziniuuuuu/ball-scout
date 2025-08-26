/**
 * 性能优化中间件
 *
 * 提供多种性能优化功能：
 * - 响应压缩
 * - 缓存控制
 * - ETag支持
 * - 响应时间监控
 * - 内存使用监控
 * - 请求合并
 */

import { Context, Next } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { RedisManager } from '../shared/db.ts';

export interface PerformanceConfig {
  compression: {
    enabled: boolean;
    threshold: number; // 最小压缩大小
    level: number; // 压缩级别 1-9
  };
  cache: {
    staticAssets: {
      maxAge: number; // 缓存时间（秒）
      extensions: string[];
    };
    api: {
      defaultMaxAge: number;
      routes: Record<string, number>;
    };
  };
  monitoring: {
    enabled: boolean;
    slowRequestThreshold: number; // 慢请求阈值（毫秒）
  };
}

export interface PerformanceMetrics {
  requestCount: number;
  averageResponseTime: number;
  slowRequestCount: number;
  cacheHitRate: number;
  memoryUsage: {
    rss: number;
    heapTotal: number;
    heapUsed: number;
    external: number;
  };
}

export class PerformanceMiddleware {
  private redis: RedisManager;
  private config: PerformanceConfig;
  private requestTimes: number[] = [];
  private slowRequestCount = 0;
  private totalRequestCount = 0;
  private cacheHits = 0;
  private cacheMisses = 0;

  constructor(redis: RedisManager, config: PerformanceConfig) {
    this.redis = redis;
    this.config = config;
    this.startPeriodicMetricsCollection();
  }

  /**
   * 响应压缩中间件
   */
  compressionMiddleware() {
    return async (ctx: Context, next: Next) => {
      if (!this.config.compression.enabled) {
        await next();
        return;
      }

      const acceptEncoding = ctx.request.headers.get('Accept-Encoding') || '';
      const supportsGzip = acceptEncoding.includes('gzip');

      if (!supportsGzip) {
        await next();
        return;
      }

      await next();

      const contentType = ctx.response.headers.get('Content-Type') || '';
      const contentLength = ctx.response.headers.get('Content-Length');
      const shouldCompress = this.shouldCompressResponse(
        contentType,
        contentLength,
      );

      if (shouldCompress && ctx.response.body) {
        try {
          const body = await this.getResponseBody(ctx.response.body);
          if (body.length >= this.config.compression.threshold) {
            const compressed = await this.compressGzip(body);

            ctx.response.body = compressed;
            ctx.response.headers.set('Content-Encoding', 'gzip');
            ctx.response.headers.set(
              'Content-Length',
              compressed.length.toString(),
            );
            ctx.response.headers.delete('ETag'); // 删除ETag因为内容已更改
          }
        } catch (error) {
          console.error('响应压缩失败:', error);
          // 压缩失败时继续发送原始响应
        }
      }
    };
  }

  /**
   * 缓存控制中间件
   */
  cacheControlMiddleware() {
    return async (ctx: Context, next: Next) => {
      const path = ctx.request.url.pathname;
      const method = ctx.request.method;

      // 只对GET请求应用缓存
      if (method !== 'GET') {
        await next();
        return;
      }

      // 检查是否有缓存的响应
      const cacheKey = this.generateCacheKey(path, ctx.request.url.search);
      const cachedResponse = await this.getCachedResponse(cacheKey);

      if (cachedResponse) {
        this.cacheHits++;
        ctx.response.body = cachedResponse.body;
        ctx.response.status = cachedResponse.status;

        // 设置缓存头
        for (const [key, value] of Object.entries(cachedResponse.headers)) {
          ctx.response.headers.set(key, value);
        }

        ctx.response.headers.set('X-Cache', 'HIT');
        return;
      }

      this.cacheMisses++;
      await next();

      // 缓存响应（如果适合）
      const shouldCache = this.shouldCacheResponse(ctx);
      if (shouldCache) {
        await this.cacheResponse(cacheKey, ctx);
      }

      // 设置缓存控制头
      this.setCacheControlHeaders(ctx, path);
    };
  }

  /**
   * ETag支持中间件
   */
  etagMiddleware() {
    return async (ctx: Context, next: Next) => {
      await next();

      if (ctx.request.method !== 'GET' || !ctx.response.body) {
        return;
      }

      try {
        const body = await this.getResponseBody(ctx.response.body);
        const etag = await this.generateETag(body);

        ctx.response.headers.set('ETag', etag);

        // 检查客户端ETag
        const clientETag = ctx.request.headers.get('If-None-Match');
        if (clientETag === etag) {
          ctx.response.status = 304;
          ctx.response.body = null;
        }
      } catch (error) {
        console.error('ETag处理失败:', error);
      }
    };
  }

  /**
   * 响应时间监控中间件
   */
  responseTimeMiddleware() {
    return async (ctx: Context, next: Next) => {
      const startTime = Date.now();

      await next();

      const endTime = Date.now();
      const responseTime = endTime - startTime;

      // 设置响应时间头
      ctx.response.headers.set('X-Response-Time', `${responseTime}ms`);

      // 收集性能指标
      if (this.config.monitoring.enabled) {
        this.collectPerformanceMetrics(responseTime);
      }

      // 记录慢请求
      if (responseTime > this.config.monitoring.slowRequestThreshold) {
        this.slowRequestCount++;
        await this.logSlowRequest(ctx, responseTime);
      }
    };
  }

  /**
   * 内存监控中间件
   */
  memoryMonitoringMiddleware() {
    return async (ctx: Context, next: Next) => {
      const beforeMemory = this.getMemoryUsage();

      await next();

      const afterMemory = this.getMemoryUsage();
      const memoryDiff = afterMemory.heapUsed - beforeMemory.heapUsed;

      // 如果内存增长过多，记录警告
      if (memoryDiff > 50 * 1024 * 1024) { // 50MB
        console.warn(
          `⚠️  内存使用增长较大: ${
            Math.round(memoryDiff / 1024 / 1024)
          }MB for ${ctx.request.url.pathname}`,
        );
      }

      // 定期触发垃圾回收（在生产环境中谨慎使用）
      if (afterMemory.heapUsed > 500 * 1024 * 1024) { // 500MB
        if (typeof globalThis.gc === 'function') {
          globalThis.gc();
        }
      }
    };
  }

  /**
   * 请求合并中间件（防止重复请求）
   */
  requestDeduplicationMiddleware() {
    const pendingRequests = new Map<string, Promise<any>>();

    return async (ctx: Context, next: Next) => {
      // 只对GET请求进行去重
      if (ctx.request.method !== 'GET') {
        await next();
        return;
      }

      const requestKey = this.generateRequestKey(ctx);

      // 检查是否有正在处理的相同请求
      if (pendingRequests.has(requestKey)) {
        console.log(`🔄 请求合并: ${requestKey}`);

        try {
          const result = await pendingRequests.get(requestKey);
          ctx.response.body = result.body;
          ctx.response.status = result.status;

          for (const [key, value] of Object.entries(result.headers)) {
            ctx.response.headers.set(key, value);
          }

          ctx.response.headers.set('X-Request-Deduped', 'true');
          return;
        } catch (error) {
          // 如果合并的请求失败，继续处理当前请求
          console.warn('请求合并失败:', error);
        }
      }

      // 创建新的请求Promise
      const requestPromise = (async () => {
        try {
          await next();

          return {
            body: ctx.response.body,
            status: ctx.response.status,
            headers: Object.fromEntries(ctx.response.headers.entries()),
          };
        } finally {
          pendingRequests.delete(requestKey);
        }
      })();

      pendingRequests.set(requestKey, requestPromise);
      await requestPromise;
    };
  }

  /**
   * API响应优化中间件
   */
  apiOptimizationMiddleware() {
    return async (ctx: Context, next: Next) => {
      // 只对API路径应用优化
      if (!ctx.request.url.pathname.startsWith('/api/')) {
        await next();
        return;
      }

      // 设置优化的响应头
      ctx.response.headers.set('X-Content-Type-Options', 'nosniff');
      ctx.response.headers.set('X-Frame-Options', 'DENY');

      await next();

      // 优化JSON响应
      if (ctx.response.body && this.isJsonResponse(ctx)) {
        try {
          const body = await this.getResponseBody(ctx.response.body);
          const optimizedBody = this.optimizeJsonResponse(JSON.parse(body));
          ctx.response.body = JSON.stringify(optimizedBody);
        } catch (error) {
          console.error('JSON响应优化失败:', error);
        }
      }
    };
  }

  /**
   * 静态资源优化中间件
   */
  staticAssetOptimizationMiddleware() {
    return async (ctx: Context, next: Next) => {
      const path = ctx.request.url.pathname;
      const extension = this.getFileExtension(path);

      if (!this.config.cache.staticAssets.extensions.includes(extension)) {
        await next();
        return;
      }

      // 设置静态资源缓存头
      const maxAge = this.config.cache.staticAssets.maxAge;
      ctx.response.headers.set('Cache-Control', `public, max-age=${maxAge}`);
      ctx.response.headers.set(
        'Expires',
        new Date(Date.now() + maxAge * 1000).toUTCString(),
      );

      await next();
    };
  }

  /**
   * 数据库查询优化中间件
   */
  databaseOptimizationMiddleware() {
    return async (ctx: Context, next: Next) => {
      // 为数据库查询添加优化提示
      ctx.state.dbOptimization = {
        useReadReplica: ctx.request.method === 'GET',
        enableQueryCache: true,
        connectionTimeout: 5000,
      };

      await next();
    };
  }

  /**
   * 判断是否应该压缩响应
   */
  private shouldCompressResponse(
    contentType: string,
    contentLength: string | null,
  ): boolean {
    // 检查内容类型
    const compressibleTypes = [
      'application/json',
      'application/javascript',
      'application/xml',
      'text/html',
      'text/css',
      'text/plain',
      'text/xml',
    ];

    const isCompressible = compressibleTypes.some((type) =>
      contentType.includes(type)
    );
    if (!isCompressible) return false;

    // 检查内容长度
    if (contentLength) {
      const length = parseInt(contentLength);
      return length >= this.config.compression.threshold;
    }

    return true;
  }

  /**
   * Gzip压缩
   */
  private async compressGzip(data: Uint8Array): Promise<Uint8Array> {
    const stream = new CompressionStream('gzip');
    const writer = stream.writable.getWriter();
    const reader = stream.readable.getReader();

    await writer.write(data);
    await writer.close();

    const chunks: Uint8Array[] = [];
    let done = false;

    while (!done) {
      const { value, done: streamDone } = await reader.read();
      done = streamDone;
      if (value) chunks.push(value);
    }

    const totalLength = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
    const compressed = new Uint8Array(totalLength);
    let offset = 0;

    for (const chunk of chunks) {
      compressed.set(chunk, offset);
      offset += chunk.length;
    }

    return compressed;
  }

  /**
   * 生成缓存键
   */
  private generateCacheKey(path: string, query: string): string {
    return `cache:response:${path}${query}`;
  }

  /**
   * 获取缓存的响应
   */
  private async getCachedResponse(key: string): Promise<any> {
    try {
      const cached = await this.redis.get(key);
      return cached ? JSON.parse(cached) : null;
    } catch {
      return null;
    }
  }

  /**
   * 缓存响应
   */
  private async cacheResponse(key: string, ctx: Context): Promise<void> {
    try {
      const response = {
        body: await this.getResponseBody(ctx.response.body),
        status: ctx.response.status,
        headers: Object.fromEntries(ctx.response.headers.entries()),
      };

      const ttl = this.getCacheTtl(ctx.request.url.pathname);
      await this.redis.setex(key, ttl, JSON.stringify(response));
    } catch (error) {
      console.error('缓存响应失败:', error);
    }
  }

  /**
   * 判断是否应该缓存响应
   */
  private shouldCacheResponse(ctx: Context): boolean {
    // 只缓存成功的GET请求
    if (ctx.request.method !== 'GET' || ctx.response.status !== 200) {
      return false;
    }

    // 检查是否有禁止缓存的头
    const cacheControl = ctx.response.headers.get('Cache-Control');
    if (cacheControl && cacheControl.includes('no-cache')) {
      return false;
    }

    return true;
  }

  /**
   * 设置缓存控制头
   */
  private setCacheControlHeaders(ctx: Context, path: string): void {
    const extension = this.getFileExtension(path);

    if (this.config.cache.staticAssets.extensions.includes(extension)) {
      const maxAge = this.config.cache.staticAssets.maxAge;
      ctx.response.headers.set('Cache-Control', `public, max-age=${maxAge}`);
    } else if (path.startsWith('/api/')) {
      const maxAge = this.getCacheTtl(path);
      ctx.response.headers.set('Cache-Control', `private, max-age=${maxAge}`);
    }

    ctx.response.headers.set('X-Cache', 'MISS');
  }

  /**
   * 获取缓存TTL
   */
  private getCacheTtl(path: string): number {
    // 检查特定路径的缓存配置
    for (const [route, ttl] of Object.entries(this.config.cache.api.routes)) {
      if (path.includes(route)) {
        return ttl;
      }
    }

    return this.config.cache.api.defaultMaxAge;
  }

  /**
   * 生成ETag
   */
  private async generateETag(data: Uint8Array): Promise<string> {
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const hashHex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join(
      '',
    );
    return `"${hashHex.substring(0, 16)}"`;
  }

  /**
   * 生成请求键
   */
  private generateRequestKey(ctx: Context): string {
    return `${ctx.request.method}:${ctx.request.url.pathname}${ctx.request.url.search}`;
  }

  /**
   * 获取响应体
   */
  private async getResponseBody(body: any): Promise<Uint8Array> {
    if (!body) return new Uint8Array();

    if (typeof body === 'string') {
      return new TextEncoder().encode(body);
    }

    if (body instanceof Uint8Array) {
      return body;
    }

    if (typeof body === 'object') {
      return new TextEncoder().encode(JSON.stringify(body));
    }

    return new TextEncoder().encode(String(body));
  }

  /**
   * 获取文件扩展名
   */
  private getFileExtension(path: string): string {
    const lastDot = path.lastIndexOf('.');
    return lastDot >= 0 ? path.substring(lastDot + 1).toLowerCase() : '';
  }

  /**
   * 判断是否为JSON响应
   */
  private isJsonResponse(ctx: Context): boolean {
    const contentType = ctx.response.headers.get('Content-Type') || '';
    return contentType.includes('application/json');
  }

  /**
   * 优化JSON响应
   */
  private optimizeJsonResponse(data: any): any {
    // 移除null值和空数组/对象
    if (Array.isArray(data)) {
      return data.filter((item) => item != null).map((item) =>
        this.optimizeJsonResponse(item)
      );
    }

    if (typeof data === 'object' && data !== null) {
      const optimized: any = {};
      for (const [key, value] of Object.entries(data)) {
        if (value != null) {
          if (Array.isArray(value) && value.length === 0) {
            continue; // 跳过空数组
          }
          if (typeof value === 'object' && Object.keys(value).length === 0) {
            continue; // 跳过空对象
          }
          optimized[key] = this.optimizeJsonResponse(value);
        }
      }
      return optimized;
    }

    return data;
  }

  /**
   * 收集性能指标
   */
  private collectPerformanceMetrics(responseTime: number): void {
    this.totalRequestCount++;
    this.requestTimes.push(responseTime);

    // 保持数组大小在合理范围内
    if (this.requestTimes.length > 1000) {
      this.requestTimes = this.requestTimes.slice(-1000);
    }
  }

  /**
   * 记录慢请求
   */
  private async logSlowRequest(
    ctx: Context,
    responseTime: number,
  ): Promise<void> {
    const logData = {
      method: ctx.request.method,
      url: ctx.request.url.pathname,
      responseTime,
      timestamp: new Date().toISOString(),
      userAgent: ctx.request.headers.get('User-Agent'),
    };

    try {
      await this.redis.lpush('slow_requests', JSON.stringify(logData));
      await this.redis.ltrim('slow_requests', 0, 99); // 保留最新100条
      await this.redis.expire('slow_requests', 86400); // 24小时过期
    } catch (error) {
      console.error('记录慢请求失败:', error);
    }

    console.warn(
      `🐌 慢请求: ${ctx.request.method} ${ctx.request.url.pathname} - ${responseTime}ms`,
    );
  }

  /**
   * 获取内存使用情况
   */
  private getMemoryUsage() {
    return Deno.memoryUsage();
  }

  /**
   * 开始周期性指标收集
   */
  private startPeriodicMetricsCollection(): void {
    setInterval(async () => {
      const metrics = this.getPerformanceMetrics();
      await this.storeMetrics(metrics);
    }, 60000); // 每分钟收集一次
  }

  /**
   * 存储性能指标
   */
  private async storeMetrics(metrics: PerformanceMetrics): Promise<void> {
    try {
      const key = `performance_metrics:${Date.now()}`;
      await this.redis.setex(key, 3600, JSON.stringify(metrics)); // 1小时TTL

      // 清理旧指标
      const keys = await this.redis.keys('performance_metrics:*');
      if (keys.length > 60) { // 保留最近60个指标点
        const sortedKeys = keys.sort();
        const keysToDelete = sortedKeys.slice(0, keys.length - 60);
        if (keysToDelete.length > 0) {
          await this.redis.del(...keysToDelete);
        }
      }
    } catch (error) {
      console.error('存储性能指标失败:', error);
    }
  }

  /**
   * 获取性能指标
   */
  getPerformanceMetrics(): PerformanceMetrics {
    const averageResponseTime = this.requestTimes.length > 0
      ? this.requestTimes.reduce((sum, time) => sum + time, 0) /
        this.requestTimes.length
      : 0;

    const cacheHitRate = (this.cacheHits + this.cacheMisses) > 0
      ? this.cacheHits / (this.cacheHits + this.cacheMisses)
      : 0;

    return {
      requestCount: this.totalRequestCount,
      averageResponseTime: Math.round(averageResponseTime),
      slowRequestCount: this.slowRequestCount,
      cacheHitRate: Math.round(cacheHitRate * 100) / 100,
      memoryUsage: this.getMemoryUsage(),
    };
  }

  /**
   * 重置性能计数器
   */
  resetCounters(): void {
    this.requestTimes = [];
    this.slowRequestCount = 0;
    this.totalRequestCount = 0;
    this.cacheHits = 0;
    this.cacheMisses = 0;
  }
}
