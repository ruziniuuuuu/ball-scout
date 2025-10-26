import type { RecordToAny } from './types.ts';

export interface ApiError {
  code: string;
  message: string;
  details?: unknown;
}

export interface ResponseMeta extends Record<string, unknown> {
  timestamp: string;
}

export interface ApiResponse<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
  error?: ApiError;
  meta?: ResponseMeta;
}

const buildMeta = (meta?: Record<string, unknown>): ResponseMeta => ({
  timestamp: new Date().toISOString(),
  ...(meta ?? {}),
});

export function createSuccessResponse<T>(
  data?: T,
  message?: string,
  meta?: Record<string, unknown>,
): ApiResponse<T> {
  return {
    success: true,
    message,
    data,
    meta: buildMeta(meta),
  };
}

export function createErrorResponse(
  message: string,
  code = 'ERROR',
  details?: unknown,
  meta?: Record<string, unknown>,
): ApiResponse<never> {
  return {
    success: false,
    error: {
      code,
      message,
      details,
    },
    meta: buildMeta(meta),
  };
}

export interface PaginationInfo {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
}

export function createPaginatedResponse<T>(
  items: T[],
  total: number,
  page: number,
  limit: number,
  meta?: Record<string, unknown>,
): ApiResponse<{ items: T[]; pagination: PaginationInfo }> {
  const safeLimit = Math.max(limit, 1);
  const totalPages = Math.ceil(total / safeLimit);

  return {
    success: true,
    data: {
      items,
      pagination: {
        total,
        page,
        limit: safeLimit,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
    },
    meta: buildMeta(meta),
  };
}