import type { Context, Next } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { verify, type Payload } from '../deps.ts';
import { config } from '../config.ts';
import { createErrorResponse } from '../shared/response.ts';

const encoder = new TextEncoder();
const jwtSecretKey = await crypto.subtle.importKey(
  'raw',
  encoder.encode(config.jwt.secret),
  { name: 'HMAC', hash: 'SHA-256' },
  false,
  ['verify'],
);

export interface AuthenticatedUser extends Payload {
  id: string;
  role?: string;
}

export interface AuthState {
  user?: AuthenticatedUser;
  authToken?: string;
}

export interface AuthenticatedContext extends Context {
  state: Context['state'] & AuthState;
}

function extractToken(ctx: AuthenticatedContext): string | null {
  const authorization = ctx.request.headers.get('Authorization');
  if (authorization?.startsWith('Bearer ')) {
    return authorization.slice(7);
  }

  // 备用：支持从cookie中读取
  const token = ctx.cookies.get('auth_token');
  return token ?? null;
}

export async function requireAuth(ctx: AuthenticatedContext, next: Next) {
  const token = extractToken(ctx);

  if (!token) {
    ctx.response.status = 401;
    ctx.response.body = createErrorResponse('缺少认证信息', 'UNAUTHORIZED');
    return;
  }

  try {
    const payload = await verify(token, jwtSecretKey) as Payload;
    const subject = typeof payload.sub === 'string'
      ? payload.sub
      : (payload as Record<string, unknown>).userId as string | undefined;

    if (!subject) {
      ctx.response.status = 401;
      ctx.response.body = createErrorResponse('无效的令牌载荷', 'UNAUTHORIZED');
      return;
    }

    const user: AuthenticatedUser = {
      ...payload,
      id: subject,
      role: typeof (payload as Record<string, unknown>).role === 'string'
        ? (payload as Record<string, unknown>).role as string
        : undefined,
    };

    ctx.state.user = user;
    ctx.state.authToken = token;

    await next();
  } catch (_error) {
    ctx.response.status = 401;
    ctx.response.body = createErrorResponse('认证失败或令牌已过期', 'UNAUTHORIZED');
  }
}

export function requireAdmin(ctx: AuthenticatedContext, next: Next) {
  if (!ctx.state.user || ctx.state.user.role !== 'admin') {
    ctx.response.status = 403;
    ctx.response.body = createErrorResponse('需要管理员权限', 'FORBIDDEN');
    return Promise.resolve();
  }

  return next();
}
