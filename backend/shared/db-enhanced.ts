/**
 * 数据库操作增强工具
 * 
 * 提供参数验证、事务管理、查询优化等功能
 */

import type { Client } from '../deps.ts';
import { DatabaseManager } from './db.ts';
import { DatabaseError, ValidationError } from './errors.ts';

/**
 * 查询选项
 */
export interface QueryOptions {
  limit?: number;
  offset?: number;
  orderBy?: string;
  orderDirection?: 'ASC' | 'DESC';
  where?: Record<string, unknown>;
}

/**
 * 分页结果
 */
export interface PaginatedResult<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  hasMore: boolean;
}

/**
 * 数据库查询构建器
 */
export class QueryBuilder {
  private table: string;
  private selectFields: string[] = ['*'];
  private whereConditions: string[] = [];
  private params: unknown[] = [];
  private paramIndex = 1;
  private orderByField?: string;
  private orderDirection: 'ASC' | 'DESC' = 'DESC';
  private limitValue?: number;
  private offsetValue?: number;

  constructor(table: string) {
    this.table = table;
  }

  /**
   * 选择字段
   */
  select(fields: string[]): this {
    this.selectFields = fields;
    return this;
  }

  /**
   * 添加WHERE条件
   */
  where(field: string, operator: string, value: unknown): this {
    const paramName = `$${this.paramIndex++}`;
    this.whereConditions.push(`${field} ${operator} ${paramName}`);
    this.params.push(value);
    return this;
  }

  /**
   * 添加等于条件
   */
  whereEqual(field: string, value: unknown): this {
    return this.where(field, '=', value);
  }

  /**
   * 添加IN条件
   */
  whereIn(field: string, values: unknown[]): this {
    if (values.length === 0) {
      return this;
    }
    const paramNames = values.map(() => `$${this.paramIndex++}`).join(', ');
    this.whereConditions.push(`${field} IN (${paramNames})`);
    this.params.push(...values);
    return this;
  }

  /**
   * 添加LIKE条件
   */
  whereLike(field: string, value: string): this {
    return this.where(field, 'ILIKE', `%${value}%`);
  }

  /**
   * 排序
   */
  orderBy(field: string, direction: 'ASC' | 'DESC' = 'DESC'): this {
    this.orderByField = field;
    this.orderDirection = direction;
    return this;
  }

  /**
   * 限制数量
   */
  limit(count: number): this {
    if (count <= 0 || count > 1000) {
      throw new ValidationError('Limit must be between 1 and 1000');
    }
    this.limitValue = count;
    return this;
  }

  /**
   * 偏移量
   */
  offset(count: number): this {
    if (count < 0) {
      throw new ValidationError('Offset must be >= 0');
    }
    this.offsetValue = count;
    return this;
  }

  /**
   * 构建SQL查询
   */
  build(): { sql: string; params: unknown[] } {
    let sql = `SELECT ${this.selectFields.join(', ')} FROM ${this.table}`;

    if (this.whereConditions.length > 0) {
      sql += ` WHERE ${this.whereConditions.join(' AND ')}`;
    }

    if (this.orderByField) {
      sql += ` ORDER BY ${this.orderByField} ${this.orderDirection}`;
    }

    if (this.limitValue !== undefined) {
      sql += ` LIMIT $${this.paramIndex++}`;
      this.params.push(this.limitValue);
    }

    if (this.offsetValue !== undefined) {
      sql += ` OFFSET $${this.paramIndex++}`;
      this.params.push(this.offsetValue);
    }

    return { sql, params: this.params };
  }
}

/**
 * 数据库操作增强类
 */
export class EnhancedDatabaseManager {
  constructor(private db: DatabaseManager) {}

  /**
   * 安全查询 - 带参数验证和错误处理
   */
  async safeQuery<T = unknown>(
    sql: string,
    params?: unknown[],
  ): Promise<T[]> {
    try {
      // 参数验证
      if (params) {
        this.validateParams(params);
      }

      const result = await this.db.query(sql, params);
      return result.rows as T[];
    } catch (error) {
      throw new DatabaseError(
        `查询执行失败: ${error instanceof Error ? error.message : String(error)}`,
        error instanceof Error ? error : undefined,
        { sql, params },
      );
    }
  }

  /**
   * 查询单条记录
   */
  async findOne<T = unknown>(
    sql: string,
    params?: unknown[],
  ): Promise<T | null> {
    const results = await this.safeQuery<T>(sql, params);
    return results.length > 0 ? results[0] : null;
  }

  /**
   * 分页查询
   */
  async paginate<T = unknown>(
    table: string,
    options: QueryOptions = {},
  ): Promise<PaginatedResult<T>> {
    const {
      limit: limitOpt = 20,
      offset: offsetOpt = 0,
      orderBy = 'created_at',
      orderDirection = 'DESC',
      where = {},
    } = options;

    // 验证分页参数
    if (limitOpt <= 0 || limitOpt > 100) {
      throw new ValidationError('Limit must be between 1 and 100');
    }
    if (offsetOpt < 0) {
      throw new ValidationError('Offset must be >= 0');
    }

    const builder = new QueryBuilder(table);

    // 添加WHERE条件
    for (const [field, value] of Object.entries(where)) {
      if (value !== undefined && value !== null) {
        builder.whereEqual(field, value);
      }
    }

    // 构建查询
    const { sql, params } = builder
      .orderBy(orderBy, orderDirection)
      .limit(limitOpt)
      .offset(offsetOpt)
      .build();

    // 获取总数
    const countSql = `SELECT COUNT(*) as total FROM ${table}`;
    const countParams = builder.params.slice(0, -2); // 移除limit和offset参数

    const [items, countResult] = await Promise.all([
      this.safeQuery<T>(sql, params),
      this.safeQuery<{ total: string }>(countSql, countParams),
    ]);

    const total = parseInt(countResult[0]?.total || '0', 10);
    const page = Math.floor(offsetOpt / limitOpt) + 1;

    return {
      items,
      total,
      page,
      limit: limitOpt,
      hasMore: offsetOpt + limitOpt < total,
    };
  }

  /**
   * 插入记录
   */
  async insert<T extends Record<string, unknown>>(
    table: string,
    data: T,
  ): Promise<T> {
    const fields = Object.keys(data);
    const values = Object.values(data);
    const paramNames = fields.map((_, i) => `$${i + 1}`).join(', ');

    const sql = `
      INSERT INTO ${table} (${fields.join(', ')})
      VALUES (${paramNames})
      RETURNING *
    `;

    const result = await this.safeQuery<T>(sql, values);
    if (result.length === 0) {
      throw new DatabaseError('插入记录失败');
    }

    return result[0];
  }

  /**
   * 更新记录
   */
  async update<T extends Record<string, unknown>>(
    table: string,
    id: string,
    data: Partial<T>,
  ): Promise<T> {
    const fields = Object.keys(data);
    const values = Object.values(data);
    const updates = fields.map((field, i) => `${field} = $${i + 1}`).join(', ');

    const sql = `
      UPDATE ${table}
      SET ${updates}, updated_at = NOW()
      WHERE id = $${fields.length + 1}
      RETURNING *
    `;

    const result = await this.safeQuery<T>(sql, [...values, id]);
    if (result.length === 0) {
      throw new DatabaseError(`更新记录失败: 未找到id为 ${id} 的记录`);
    }

    return result[0];
  }

  /**
   * 删除记录（软删除）
   */
  async softDelete(table: string, id: string): Promise<boolean> {
    const sql = `
      UPDATE ${table}
      SET is_deleted = TRUE, updated_at = NOW()
      WHERE id = $1
      RETURNING id
    `;

    const result = await this.safeQuery<{ id: string }>(sql, [id]);
    return result.length > 0;
  }

  /**
   * 硬删除记录
   */
  async delete(table: string, id: string): Promise<boolean> {
    const sql = `DELETE FROM ${table} WHERE id = $1 RETURNING id`;
    const result = await this.safeQuery<{ id: string }>(sql, [id]);
    return result.length > 0;
  }

  /**
   * 事务执行
   */
  async transaction<T>(
    callback: (client: Client) => Promise<T>,
  ): Promise<T> {
    try {
      return await this.db.transaction(callback);
    } catch (error) {
      throw new DatabaseError(
        `事务执行失败: ${error instanceof Error ? error.message : String(error)}`,
        error instanceof Error ? error : undefined,
      );
    }
  }

  /**
   * 参数验证
   */
  private validateParams(params: unknown[]): void {
    for (const param of params) {
      if (typeof param === 'string' && param.length > 10000) {
        throw new ValidationError('参数值过长');
      }
      // 可以添加更多验证规则
    }
  }
}

