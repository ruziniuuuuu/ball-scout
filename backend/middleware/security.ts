/**
 * 安全中间件
 *
 * 提供多层安全防护：
 * - 速率限制
 * - CORS安全
 * - XSS防护
 * - CSRF防护
 * - 请求验证
 * - IP黑名单
 */

import { Context, Next } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { RedisManager } from '../shared/db.ts';
import { createErrorResponse } from '../shared/response.ts';

export interface RateLimitConfig {
  windowMs: number; // 时间窗口（毫秒）
  max: number; // 最大请求数
  message: string; // 限制消息
  skipSuccessfulRequests?: boolean;
  skipFailedRequests?: boolean;
}

export interface SecurityConfig {
  rateLimit: {
    global: RateLimitConfig;
    auth: RateLimitConfig;
    api: RateLimitConfig;
  };
  cors: {
    allowedOrigins: string[];
    allowedMethods: string[];
    allowedHeaders: string[];
    credentials: boolean;
  };
  csrf: {
    secret: string;
    cookieName: string;
  };
  blacklist: {
    ips: string[];
    userAgents: string[];
  };
}

export class SecurityMiddleware {
  private redis: RedisManager;
  private config: SecurityConfig;
  private ipBlacklist = new Set<string>();
  private userAgentBlacklist = new Set<string>();

  constructor(redis: RedisManager, config: SecurityConfig) {
    this.redis = redis;
    this.config = config;
    this.initializeBlacklists();
  }

  /**
   * 初始化黑名单
   */
  private initializeBlacklists() {
    this.config.blacklist.ips.forEach((ip) => this.ipBlacklist.add(ip));
    this.config.blacklist.userAgents.forEach((ua) =>
      this.userAgentBlacklist.add(ua)
    );
  }

  /**
   * 通用速率限制中间件
   */
  createRateLimitMiddleware(config: RateLimitConfig) {
    return async (ctx: Context, next: Next) => {
      const clientIp = this.getClientIp(ctx);
      const key = `rate_limit:${clientIp}:${ctx.request.url.pathname}`;

      try {
        const currentCount = await this.redis.get(key);
        const requestCount = currentCount ? parseInt(currentCount) : 0;

        if (requestCount >= config.max) {
          ctx.response.status = 429;
          ctx.response.headers.set('X-RateLimit-Limit', config.max.toString());
          ctx.response.headers.set('X-RateLimit-Remaining', '0');
          ctx.response.headers.set('X-RateLimit-Reset', Date.now().toString());
          ctx.response.body = createErrorResponse(
            config.message,
            'RATE_LIMIT_EXCEEDED',
          );
          return;
        }

        // 继续处理请求
        await next();

        // 检查是否应该计数这个请求
        const shouldCount = this.shouldCountRequest(ctx, config);
        if (shouldCount) {
          if (requestCount === 0) {
            await this.redis.setex(
              key,
              Math.floor(config.windowMs / 1000),
              '1',
            );
          } else {
            await this.redis.incr(key);
          }
        }

        // 设置响应头
        const remaining = Math.max(
          0,
          config.max - requestCount - (shouldCount ? 1 : 0),
        );
        ctx.response.headers.set('X-RateLimit-Limit', config.max.toString());
        ctx.response.headers.set('X-RateLimit-Remaining', remaining.toString());
      } catch (error) {
        console.error('Rate limit middleware error:', error);
        await next(); // 发生错误时不阻止请求
      }
    };
  }

  /**
   * IP黑名单检查中间件
   */
  blacklistMiddleware() {
    return async (ctx: Context, next: Next) => {
      const clientIp = this.getClientIp(ctx);
      const userAgent = ctx.request.headers.get('User-Agent') || '';

      // 检查IP黑名单
      if (this.ipBlacklist.has(clientIp)) {
        console.warn(`🚫 阻止黑名单IP访问: ${clientIp}`);
        ctx.response.status = 403;
        ctx.response.body = createErrorResponse('访问被拒绝', 'IP_BLACKLISTED');
        return;
      }

      // 检查User-Agent黑名单
      for (const blockedUA of this.userAgentBlacklist) {
        if (userAgent.includes(blockedUA)) {
          console.warn(`🚫 阻止黑名单User-Agent访问: ${userAgent}`);
          ctx.response.status = 403;
          ctx.response.body = createErrorResponse(
            '访问被拒绝',
            'USER_AGENT_BLACKLISTED',
          );
          return;
        }
      }

      await next();
    };
  }

  /**
   * CORS安全中间件
   */
  corsSecurityMiddleware() {
    return async (ctx: Context, next: Next) => {
      const origin = ctx.request.headers.get('Origin');
      const method = ctx.request.method;

      // 预检请求处理
      if (method === 'OPTIONS') {
        if (origin && this.isAllowedOrigin(origin)) {
          ctx.response.headers.set('Access-Control-Allow-Origin', origin);
          ctx.response.headers.set(
            'Access-Control-Allow-Methods',
            this.config.cors.allowedMethods.join(', '),
          );
          ctx.response.headers.set(
            'Access-Control-Allow-Headers',
            this.config.cors.allowedHeaders.join(', '),
          );
          ctx.response.headers.set(
            'Access-Control-Allow-Credentials',
            this.config.cors.credentials.toString(),
          );
          ctx.response.headers.set('Access-Control-Max-Age', '3600');
          ctx.response.status = 204;
          return;
        } else {
          ctx.response.status = 403;
          ctx.response.body = createErrorResponse(
            'CORS政策不允许此来源',
            'CORS_BLOCKED',
          );
          return;
        }
      }

      // 常规请求CORS处理
      if (origin && this.isAllowedOrigin(origin)) {
        ctx.response.headers.set('Access-Control-Allow-Origin', origin);
        if (this.config.cors.credentials) {
          ctx.response.headers.set('Access-Control-Allow-Credentials', 'true');
        }
      }

      await next();
    };
  }

  /**
   * XSS防护中间件
   */
  xssProtectionMiddleware() {
    return async (ctx: Context, next: Next) => {
      // 设置XSS防护头
      ctx.response.headers.set('X-XSS-Protection', '1; mode=block');
      ctx.response.headers.set('X-Content-Type-Options', 'nosniff');
      ctx.response.headers.set('X-Frame-Options', 'DENY');
      ctx.response.headers.set(
        'Referrer-Policy',
        'strict-origin-when-cross-origin',
      );

      // CSP策略
      const csp = [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: https:",
        "connect-src 'self' wss: ws:",
        "font-src 'self'",
        "object-src 'none'",
        "media-src 'self'",
        "frame-src 'none'",
      ].join('; ');

      ctx.response.headers.set('Content-Security-Policy', csp);

      await next();
    };
  }

  /**
   * 请求大小限制中间件
   */
  requestSizeLimitMiddleware(maxSize: number = 10 * 1024 * 1024) { // 默认10MB
    return async (ctx: Context, next: Next) => {
      const contentLength = ctx.request.headers.get('Content-Length');

      if (contentLength && parseInt(contentLength) > maxSize) {
        ctx.response.status = 413;
        ctx.response.body = createErrorResponse(
          `请求体太大，最大允许 ${Math.floor(maxSize / 1024 / 1024)}MB`,
          'PAYLOAD_TOO_LARGE',
        );
        return;
      }

      await next();
    };
  }

  /**
   * 可疑活动检测中间件
   */
  suspiciousActivityMiddleware() {
    return async (ctx: Context, next: Next) => {
      const clientIp = this.getClientIp(ctx);
      const userAgent = ctx.request.headers.get('User-Agent') || '';
      const url = ctx.request.url.pathname;
      const method = ctx.request.method;

      // 检测SQL注入尝试
      const sqlInjectionPatterns = [
        /union.*select/i,
        /select.*from/i,
        /drop.*table/i,
        /insert.*into/i,
        /update.*set/i,
        /delete.*from/i,
        /'.*or.*1=1/i,
        /\';.*--/i,
      ];

      const queryString = ctx.request.url.search;
      const isSqlInjectionAttempt = sqlInjectionPatterns.some((pattern) =>
        pattern.test(queryString) || pattern.test(url)
      );

      if (isSqlInjectionAttempt) {
        console.warn(`🚨 检测到SQL注入尝试: ${clientIp} ${method} ${url}`);
        await this.logSuspiciousActivity(clientIp, 'sql_injection', url);

        ctx.response.status = 400;
        ctx.response.body = createErrorResponse('请求无效', 'INVALID_REQUEST');
        return;
      }

      // 检测路径遍历尝试
      if (url.includes('../') || url.includes('..\\')) {
        console.warn(`🚨 检测到路径遍历尝试: ${clientIp} ${url}`);
        await this.logSuspiciousActivity(clientIp, 'path_traversal', url);

        ctx.response.status = 403;
        ctx.response.body = createErrorResponse('访问被拒绝', 'ACCESS_DENIED');
        return;
      }

      // 检测常见扫描工具
      const scannerUserAgents = [
        'nmap',
        'nikto',
        'sqlmap',
        'masscan',
        'zap',
        'burp',
        'acunetix',
      ];

      const isScannerUserAgent = scannerUserAgents.some((scanner) =>
        userAgent.toLowerCase().includes(scanner)
      );

      if (isScannerUserAgent) {
        console.warn(`🚨 检测到扫描工具: ${clientIp} ${userAgent}`);
        await this.logSuspiciousActivity(
          clientIp,
          'scanner_detected',
          userAgent,
        );
        await this.addToTemporaryBlacklist(clientIp, 3600); // 临时加入黑名单1小时

        ctx.response.status = 403;
        ctx.response.body = createErrorResponse(
          '访问被拒绝',
          'SCANNER_DETECTED',
        );
        return;
      }

      await next();
    };
  }

  /**
   * API密钥验证中间件
   */
  apiKeyMiddleware(requiredApiKey?: string) {
    return async (ctx: Context, next: Next) => {
      // 仅对API路径进行验证
      if (!ctx.request.url.pathname.startsWith('/api/')) {
        await next();
        return;
      }

      const apiKey = ctx.request.headers.get('X-API-Key') ||
        ctx.request.url.searchParams.get('api_key');

      if (requiredApiKey && apiKey !== requiredApiKey) {
        ctx.response.status = 401;
        ctx.response.body = createErrorResponse(
          'API密钥无效',
          'INVALID_API_KEY',
        );
        return;
      }

      await next();
    };
  }

  /**
   * 请求日志中间件
   */
  requestLoggingMiddleware() {
    return async (ctx: Context, next: Next) => {
      const startTime = Date.now();
      const clientIp = this.getClientIp(ctx);
      const userAgent = ctx.request.headers.get('User-Agent') || '';
      const method = ctx.request.method;
      const url = ctx.request.url.pathname + ctx.request.url.search;

      await next();

      const endTime = Date.now();
      const responseTime = endTime - startTime;
      const statusCode = ctx.response.status || 200;

      // 记录访问日志
      console.log(
        `${
          new Date().toISOString()
        } ${clientIp} "${method} ${url}" ${statusCode} ${responseTime}ms`,
      );

      // 异常状态码记录到Redis
      if (statusCode >= 400) {
        await this.logErrorRequest(
          clientIp,
          method,
          url,
          statusCode,
          responseTime,
        );
      }

      // 记录到数据库（异步，不阻塞响应）
      this.logRequestToDatabase(
        clientIp,
        method,
        url,
        statusCode,
        responseTime,
        userAgent,
      )
        .catch((error) => console.error('记录请求日志失败:', error));
    };
  }

  /**
   * 获取客户端IP
   */
  private getClientIp(ctx: Context): string {
    // 检查代理头
    const xForwardedFor = ctx.request.headers.get('X-Forwarded-For');
    if (xForwardedFor) {
      return xForwardedFor.split(',')[0].trim();
    }

    const xRealIp = ctx.request.headers.get('X-Real-IP');
    if (xRealIp) {
      return xRealIp;
    }

    // 从连接信息获取（如果可用）
    return ctx.request.ip || 'unknown';
  }

  /**
   * 检查是否为允许的来源
   */
  private isAllowedOrigin(origin: string): boolean {
    return this.config.cors.allowedOrigins.includes('*') ||
      this.config.cors.allowedOrigins.includes(origin);
  }

  /**
   * 判断是否应该计数请求
   */
  private shouldCountRequest(ctx: Context, config: RateLimitConfig): boolean {
    const statusCode = ctx.response.status || 200;

    if (config.skipSuccessfulRequests && statusCode < 400) {
      return false;
    }

    if (config.skipFailedRequests && statusCode >= 400) {
      return false;
    }

    return true;
  }

  /**
   * 记录可疑活动
   */
  private async logSuspiciousActivity(
    ip: string,
    activityType: string,
    details: string,
  ): Promise<void> {
    try {
      const key = `suspicious_activity:${ip}:${activityType}`;
      const data = {
        ip,
        activityType,
        details,
        timestamp: new Date().toISOString(),
      };

      await this.redis.lpush(key, JSON.stringify(data));
      await this.redis.ltrim(key, 0, 99); // 保留最新100条
      await this.redis.expire(key, 86400); // 24小时过期
    } catch (error) {
      console.error('记录可疑活动失败:', error);
    }
  }

  /**
   * 添加到临时黑名单
   */
  private async addToTemporaryBlacklist(
    ip: string,
    ttl: number,
  ): Promise<void> {
    try {
      const key = `temp_blacklist:${ip}`;
      await this.redis.setex(key, ttl, '1');
      this.ipBlacklist.add(ip);

      // 设置自动清除
      setTimeout(() => {
        this.ipBlacklist.delete(ip);
      }, ttl * 1000);
    } catch (error) {
      console.error('添加临时黑名单失败:', error);
    }
  }

  /**
   * 记录错误请求
   */
  private async logErrorRequest(
    ip: string,
    method: string,
    url: string,
    statusCode: number,
    responseTime: number,
  ): Promise<void> {
    try {
      const key = `error_requests:${ip}`;
      const data = {
        method,
        url,
        statusCode,
        responseTime,
        timestamp: new Date().toISOString(),
      };

      await this.redis.lpush(key, JSON.stringify(data));
      await this.redis.ltrim(key, 0, 49); // 保留最新50条
      await this.redis.expire(key, 86400); // 24小时过期
    } catch (error) {
      console.error('记录错误请求失败:', error);
    }
  }

  /**
   * 记录请求到数据库
   */
  private async logRequestToDatabase(
    ip: string,
    method: string,
    url: string,
    statusCode: number,
    responseTime: number,
    userAgent: string,
  ): Promise<void> {
    // 这里应该有数据库连接，但为了避免循环依赖，暂时省略
    // 实际实现中应该通过依赖注入获得数据库连接
  }

  /**
   * 获取安全统计信息
   */
  async getSecurityStats(): Promise<{
    blockedIPs: number;
    rateLimitHits: number;
    suspiciousActivities: number;
    corsBlocks: number;
  }> {
    try {
      const [blockedIPs, rateLimitHits, suspiciousActivities, corsBlocks] =
        await Promise.all([
          this.redis.keys('temp_blacklist:*'),
          this.redis.keys('rate_limit:*'),
          this.redis.keys('suspicious_activity:*'),
          this.redis.get('cors_blocks_today') || '0',
        ]);

      return {
        blockedIPs: blockedIPs.length,
        rateLimitHits: rateLimitHits.length,
        suspiciousActivities: suspiciousActivities.length,
        corsBlocks: parseInt(corsBlocks as string),
      };
    } catch (error) {
      console.error('获取安全统计失败:', error);
      return {
        blockedIPs: 0,
        rateLimitHits: 0,
        suspiciousActivities: 0,
        corsBlocks: 0,
      };
    }
  }
}
