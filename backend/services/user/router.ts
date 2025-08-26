import { Router } from '../../deps.ts';
import { ApiResponse, ServiceError, User } from '../../shared/types.ts';
import {
  create,
  getNumericDate,
  hashPassword,
  verify,
  verifyPassword,
  z,
} from '../../deps.ts';

export const userRouter = new Router();

// JWT密钥
const jwtKey = await crypto.subtle.importKey(
  'raw',
  new TextEncoder().encode('your-secret-key'),
  { name: 'HMAC', hash: 'SHA-256' },
  false,
  ['sign', 'verify'],
);

// 数据验证schemas
const registerSchema = z.object({
  username: z.string().min(3).max(50),
  email: z.string().email(),
  password: z.string().min(6).max(128),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6).max(128),
});

// POST /api/v1/auth/register - 用户注册
userRouter.post('/api/v1/auth/register', async (ctx) => {
  try {
    const body = await ctx.request.body().value;
    const userData = registerSchema.parse(body);

    const { username, email, password } = userData;
    const db = ctx.state.db;

    // 检查用户是否已存在
    const existingUser = await db.query(
      'SELECT id FROM users WHERE email = $1 OR username = $2',
      [email, username],
    );

    if (existingUser.rows.length > 0) {
      throw new ServiceError('USER_EXISTS', '用户名或邮箱已存在', 409);
    }

    // 加密密码
    const passwordHash = await hashPassword(password);

    // 插入新用户
    const result = await db.query(
      `INSERT INTO users (username, email, password_hash, preferences) 
       VALUES ($1, $2, $3, $4) 
       RETURNING id, username, email, avatar, role, preferences, created_at`,
      [
        username,
        email,
        passwordHash,
        JSON.stringify({
          favoriteTeams: [],
          favoriteLeagues: [],
          language: 'zh',
          notificationSettings: {
            news: true,
            matches: true,
            transfers: true,
          },
        }),
      ],
    );

    const user = result.rows[0];

    // 生成JWT token
    const payload = {
      sub: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      exp: getNumericDate(60 * 60 * 24 * 7), // 7天过期
    };

    const token = await create({ alg: 'HS256', typ: 'JWT' }, payload, jwtKey);

    const response: ApiResponse<{ user: User; token: string }> = {
      success: true,
      data: {
        user: {
          ...user,
          preferences: JSON.parse(user.preferences),
        },
        token,
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.status = 201;
    ctx.response.body = response;
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new ServiceError(
        'VALIDATION_ERROR',
        '请求数据无效',
        400,
        error.errors,
      );
    }
    throw error;
  }
});

// POST /api/v1/auth/login - 用户登录
userRouter.post('/api/v1/auth/login', async (ctx) => {
  try {
    const body = await ctx.request.body().value;
    const loginData = loginSchema.parse(body);

    const { email, password } = loginData;
    const db = ctx.state.db;

    // 查找用户
    const result = await db.query(
      `SELECT id, username, email, password_hash, avatar, role, preferences, created_at 
       FROM users WHERE email = $1`,
      [email],
    );

    if (result.rows.length === 0) {
      throw new ServiceError('INVALID_CREDENTIALS', '邮箱或密码错误', 401);
    }

    const user = result.rows[0];

    // 验证密码
    const isValidPassword = await verifyPassword(password, user.password_hash);
    if (!isValidPassword) {
      throw new ServiceError('INVALID_CREDENTIALS', '邮箱或密码错误', 401);
    }

    // 生成JWT token
    const payload = {
      sub: user.id,
      username: user.username,
      email: user.email,
      role: user.role,
      exp: getNumericDate(60 * 60 * 24 * 7), // 7天过期
    };

    const token = await create({ alg: 'HS256', typ: 'JWT' }, payload, jwtKey);

    // 更新最后登录时间
    await db.query(
      'UPDATE users SET updated_at = NOW() WHERE id = $1',
      [user.id],
    );

    const response: ApiResponse<{ user: User; token: string }> = {
      success: true,
      data: {
        user: {
          id: user.id,
          username: user.username,
          email: user.email,
          avatar: user.avatar,
          role: user.role,
          preferences: JSON.parse(user.preferences),
          createdAt: user.created_at,
          updatedAt: new Date(),
        },
        token,
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.body = response;
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new ServiceError(
        'VALIDATION_ERROR',
        '请求数据无效',
        400,
        error.errors,
      );
    }
    throw error;
  }
});

// 认证中间件
async function authMiddleware(ctx: any, next: () => Promise<unknown>) {
  try {
    const authorization = ctx.request.headers.get('Authorization');
    if (!authorization || !authorization.startsWith('Bearer ')) {
      throw new ServiceError('UNAUTHORIZED', '缺少认证信息', 401);
    }

    const token = authorization.substring(7);
    const payload = await verify(token, jwtKey);

    ctx.state.user = payload;
    await next();
  } catch (error) {
    throw new ServiceError('UNAUTHORIZED', '认证失败', 401);
  }
}

// GET /api/v1/auth/profile - 获取用户资料
userRouter.get('/api/v1/auth/profile', authMiddleware, async (ctx) => {
  try {
    const userId = ctx.state.user.sub;
    const db = ctx.state.db;

    const result = await db.query(
      `SELECT id, username, email, avatar, role, preferences, created_at, updated_at 
       FROM users WHERE id = $1`,
      [userId],
    );

    if (result.rows.length === 0) {
      throw new ServiceError('USER_NOT_FOUND', '用户不存在', 404);
    }

    const user = result.rows[0];

    const response: ApiResponse<User> = {
      success: true,
      data: {
        ...user,
        preferences: JSON.parse(user.preferences),
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.body = response;
  } catch (error) {
    throw error;
  }
});

// PUT /api/v1/auth/profile - 更新用户资料
userRouter.put('/api/v1/auth/profile', authMiddleware, async (ctx) => {
  try {
    const userId = ctx.state.user.sub;
    const body = await ctx.request.body().value;

    const updateSchema = z.object({
      username: z.string().min(3).max(50).optional(),
      avatar: z.string().url().optional(),
      preferences: z.object({
        favoriteTeams: z.array(z.string()).optional(),
        favoriteLeagues: z.array(z.string()).optional(),
        language: z.enum(['zh', 'en']).optional(),
        notificationSettings: z.object({
          news: z.boolean().optional(),
          matches: z.boolean().optional(),
          transfers: z.boolean().optional(),
        }).optional(),
      }).optional(),
    });

    const updateData = updateSchema.parse(body);
    const db = ctx.state.db;

    // 构建更新语句
    const updateFields: string[] = [];
    const values: unknown[] = [];
    let paramIndex = 1;

    if (updateData.username) {
      updateFields.push(`username = $${paramIndex++}`);
      values.push(updateData.username);
    }

    if (updateData.avatar) {
      updateFields.push(`avatar = $${paramIndex++}`);
      values.push(updateData.avatar);
    }

    if (updateData.preferences) {
      updateFields.push(`preferences = $${paramIndex++}`);
      values.push(JSON.stringify(updateData.preferences));
    }

    updateFields.push(`updated_at = NOW()`);
    values.push(userId);

    const sql = `
      UPDATE users 
      SET ${updateFields.join(', ')}
      WHERE id = $${paramIndex}
      RETURNING id, username, email, avatar, role, preferences, created_at, updated_at
    `;

    const result = await db.query(sql, values);

    if (result.rows.length === 0) {
      throw new ServiceError('USER_NOT_FOUND', '用户不存在', 404);
    }

    const user = result.rows[0];

    const response: ApiResponse<User> = {
      success: true,
      data: {
        ...user,
        preferences: JSON.parse(user.preferences),
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };

    ctx.response.body = response;
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw new ServiceError(
        'VALIDATION_ERROR',
        '请求数据无效',
        400,
        error.errors,
      );
    }
    throw error;
  }
});
