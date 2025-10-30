/**
 * 日志系统
 * 
 * 提供分级日志记录、格式化输出、日志文件管理等功能
 */

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
}

export interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: Date;
  context?: Record<string, unknown>;
  error?: Error;
}

/**
 * 日志管理器
 */
export class Logger {
  private minLevel: LogLevel;
  private context: Record<string, unknown> = {};

  constructor(minLevel: LogLevel = LogLevel.INFO) {
    this.minLevel = minLevel;
  }

  /**
   * 设置上下文信息
   */
  setContext(context: Record<string, unknown>): void {
    this.context = { ...this.context, ...context };
  }

  /**
   * 清除上下文
   */
  clearContext(): void {
    this.context = {};
  }

  /**
   * 记录日志
   */
  private log(
    level: LogLevel,
    message: string,
    context?: Record<string, unknown>,
    error?: Error,
  ): void {
    if (level < this.minLevel) {
      return;
    }

    const entry: LogEntry = {
      level,
      message,
      timestamp: new Date(),
      context: { ...this.context, ...context },
      error,
    };

    this.formatAndOutput(entry);
  }

  /**
   * 格式化并输出日志
   */
  private formatAndOutput(entry: LogEntry): void {
    const levelStr = LogLevel[entry.level].padEnd(5);
    const timestamp = entry.timestamp.toISOString();
    const contextStr = Object.keys(entry.context || {}).length > 0
      ? JSON.stringify(entry.context)
      : '';

    const emoji = this.getLevelEmoji(entry.level);
    const message = `${emoji} [${timestamp}] ${levelStr} ${entry.message}`;

    if (entry.error) {
      console.error(message, contextStr, entry.error);
    } else if (entry.level === LogLevel.ERROR) {
      console.error(message, contextStr);
    } else if (entry.level === LogLevel.WARN) {
      console.warn(message, contextStr);
    } else {
      console.log(message, contextStr);
    }
  }

  /**
   * 获取日志级别的表情符号
   */
  private getLevelEmoji(level: LogLevel): string {
    switch (level) {
      case LogLevel.DEBUG:
        return '🔍';
      case LogLevel.INFO:
        return 'ℹ️';
      case LogLevel.WARN:
        return '⚠️';
      case LogLevel.ERROR:
        return '❌';
      default:
        return '📝';
    }
  }

  /**
   * 调试日志
   */
  debug(message: string, context?: Record<string, unknown>): void {
    this.log(LogLevel.DEBUG, message, context);
  }

  /**
   * 信息日志
   */
  info(message: string, context?: Record<string, unknown>): void {
    this.log(LogLevel.INFO, message, context);
  }

  /**
   * 警告日志
   */
  warn(message: string, context?: Record<string, unknown>): void {
    this.log(LogLevel.WARN, message, context);
  }

  /**
   * 错误日志
   */
  error(
    message: string,
    error?: Error,
    context?: Record<string, unknown>,
  ): void {
    this.log(LogLevel.ERROR, message, context, error);
  }

  /**
   * 记录请求日志
   */
  logRequest(
    method: string,
    path: string,
    statusCode: number,
    duration: number,
    context?: Record<string, unknown>,
  ): void {
    const level = statusCode >= 500
      ? LogLevel.ERROR
      : statusCode >= 400
      ? LogLevel.WARN
      : LogLevel.INFO;

    this.log(
      level,
      `${method} ${path} - ${statusCode} (${duration}ms)`,
      context,
    );
  }

  /**
   * 记录数据库查询
   */
  logQuery(sql: string, duration: number, params?: unknown[]): void {
    const level = duration > 1000 ? LogLevel.WARN : LogLevel.DEBUG;
    this.log(
      level,
      `数据库查询 (${duration}ms)`,
      {
        sql: sql.substring(0, 200),
        params: params?.slice(0, 5), // 只记录前5个参数
      },
    );
  }
}

// 默认日志实例
export const logger = new Logger(
  Deno.env.get('LOG_LEVEL') === 'DEBUG'
    ? LogLevel.DEBUG
    : Deno.env.get('ENV') === 'production'
    ? LogLevel.INFO
    : LogLevel.DEBUG,
);

