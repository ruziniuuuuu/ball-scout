/**
 * 统一错误处理系统
 * 
 * 提供统一的错误类型定义、错误处理和错误响应格式
 */

import type { Context } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { createErrorResponse } from './response.ts';
import { logger } from './logger.ts';

/**
 * 错误代码枚举
 */
export enum ErrorCode {
  // 通用错误 (1xxx)
  INTERNAL_ERROR = 'INTERNAL_ERROR',
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  NOT_FOUND = 'NOT_FOUND',
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  BAD_REQUEST = 'BAD_REQUEST',
  
  // 数据库错误 (2xxx)
  DATABASE_ERROR = 'DATABASE_ERROR',
  DATABASE_CONNECTION_ERROR = 'DATABASE_CONNECTION_ERROR',
  DATABASE_QUERY_ERROR = 'DATABASE_QUERY_ERROR',
  DATABASE_TRANSACTION_ERROR = 'DATABASE_TRANSACTION_ERROR',
  
  // 业务逻辑错误 (3xxx)
  USER_NOT_FOUND = 'USER_NOT_FOUND',
  USER_ALREADY_EXISTS = 'USER_ALREADY_EXISTS',
  INVALID_CREDENTIALS = 'INVALID_CREDENTIALS',
  NEWS_NOT_FOUND = 'NEWS_NOT_FOUND',
  MATCH_NOT_FOUND = 'MATCH_NOT_FOUND',
  COMMENT_NOT_FOUND = 'COMMENT_NOT_FOUND',
  
  // 外部服务错误 (4xxx)
  TRANSLATION_ERROR = 'TRANSLATION_ERROR',
  TRANSLATION_PROVIDER_ERROR = 'TRANSLATION_PROVIDER_ERROR',
  EXTERNAL_API_ERROR = 'EXTERNAL_API_ERROR',
  
  // 速率限制错误 (5xxx)
  RATE_LIMIT_EXCEEDED = 'RATE_LIMIT_EXCEEDED',
}

/**
 * 应用错误类
 */
export class AppError extends Error {
  constructor(
    public code: ErrorCode,
    message: string,
    public statusCode: number = 500,
    public details?: unknown,
    public cause?: Error,
  ) {
    super(message);
    this.name = 'AppError';
    
    // 保持错误堆栈
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, AppError);
    }
  }

  /**
   * 转换为JSON格式
   */
  toJSON() {
    return {
      code: this.code,
      message: this.message,
      details: this.details,
      ...(this.cause && { cause: this.cause.message }),
    };
  }
}

/**
 * 验证错误类
 */
export class ValidationError extends AppError {
  constructor(message: string, details?: unknown) {
    super(ErrorCode.VALIDATION_ERROR, message, 400, details);
    this.name = 'ValidationError';
  }
}

/**
 * 未找到错误类
 */
export class NotFoundError extends AppError {
  constructor(resource: string, id?: string) {
    super(
      ErrorCode.NOT_FOUND,
      id ? `${resource} with id ${id} not found` : `${resource} not found`,
      404,
      { resource, id },
    );
    this.name = 'NotFoundError';
  }
}

/**
 * 未授权错误类
 */
export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized access') {
    super(ErrorCode.UNAUTHORIZED, message, 401);
    this.name = 'UnauthorizedError';
  }
}

/**
 * 禁止访问错误类
 */
export class ForbiddenError extends AppError {
  constructor(message = 'Forbidden access') {
    super(ErrorCode.FORBIDDEN, message, 403);
    this.name = 'ForbiddenError';
  }
}

/**
 * 数据库错误类
 */
export class DatabaseError extends AppError {
  constructor(message: string, cause?: Error, details?: unknown) {
    super(ErrorCode.DATABASE_ERROR, message, 500, details, cause);
    this.name = 'DatabaseError';
  }
}

/**
 * 错误处理中间件
 */
export async function errorHandler(ctx: Context, next: () => Promise<unknown>) {
  try {
    await next();
  } catch (error) {
    logger.error(
      `请求处理错误: ${ctx.request.method} ${ctx.request.url.pathname}`,
      error instanceof Error ? error : new Error(String(error)),
      {
        url: ctx.request.url.toString(),
        method: ctx.request.method,
        statusCode: error instanceof AppError ? error.statusCode : 500,
      },
    );

    // 处理已知错误类型
    if (error instanceof AppError) {
      ctx.response.status = error.statusCode;
      ctx.response.body = createErrorResponse(
        error.message,
        error.code,
        error.details,
      );
      return;
    }

    // 处理验证错误（Zod等）
    if (error?.name === 'ZodError') {
      ctx.response.status = 400;
      ctx.response.body = createErrorResponse(
        '请求参数验证失败',
        ErrorCode.VALIDATION_ERROR,
        error.issues || error,
      );
      return;
    }

    // 处理数据库错误
    if (error?.message?.includes('duplicate key') ||
        error?.code === '23505') {
      ctx.response.status = 409;
      ctx.response.body = createErrorResponse(
        '资源已存在',
        ErrorCode.USER_ALREADY_EXISTS,
        { constraint: error.constraint },
      );
      return;
    }

    // 处理未知错误
    const isProduction = Deno.env.get('ENV') === 'production';
    ctx.response.status = 500;
    ctx.response.body = createErrorResponse(
      isProduction ? '服务器内部错误' : (error as Error).message,
      ErrorCode.INTERNAL_ERROR,
      isProduction ? undefined : {
        stack: error instanceof Error ? error.stack : undefined,
        name: error?.name,
      },
    );
  }
}

/**
 * 错误响应格式化工具
 */
export function formatErrorResponse(error: unknown): {
  code: string;
  message: string;
  statusCode: number;
  details?: unknown;
} {
  if (error instanceof AppError) {
    return {
      code: error.code,
      message: error.message,
      statusCode: error.statusCode,
      details: error.details,
    };
  }

  if (error instanceof Error) {
    return {
      code: ErrorCode.INTERNAL_ERROR,
      message: error.message,
      statusCode: 500,
    };
  }

  return {
    code: ErrorCode.INTERNAL_ERROR,
    message: '未知错误',
    statusCode: 500,
  };
}

