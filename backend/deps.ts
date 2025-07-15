// Web框架
export { Application, Router } from "https://deno.land/x/oak@v12.6.1/mod.ts";
export type { Context } from "https://deno.land/x/oak@v12.6.1/mod.ts";

// 中间件
export { oakCors } from "https://deno.land/x/cors@v1.2.2/mod.ts";

// 数据库
export { Client } from "https://deno.land/x/postgres@v0.17.0/mod.ts";
export type { ClientOptions } from "https://deno.land/x/postgres@v0.17.0/mod.ts";
export { connect } from "https://deno.land/x/redis@v0.31.0/mod.ts";

// 验证和加密 - 先简化，移除bcrypt
export { create, verify, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";
export type { Header, Payload } from "https://deno.land/x/djwt@v3.0.1/mod.ts";

// 简单的密码哈希函数（开发阶段使用）
export async function hashPassword(password: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(password + 'salt');
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

export async function verifyPassword(password: string, hashValue: string): Promise<boolean> {
  const passwordHash = await hashPassword(password);
  return passwordHash === hashValue;
}

// 数据验证
export { z } from "https://deno.land/x/zod@v3.22.4/mod.ts";

// 环境变量
export { load } from "https://deno.land/std@0.208.0/dotenv/mod.ts";

// 日志
export * as log from "https://deno.land/std@0.208.0/log/mod.ts";

// UUID生成
export { v4 as generateUuid } from "https://deno.land/std@0.208.0/uuid/mod.ts";

// 时间处理
export { format, parse } from "https://deno.land/std@0.208.0/datetime/mod.ts";

// XML解析库
export { parse as parseXml } from "https://deno.land/x/xml@2.1.1/mod.ts";

// HTML解析库
export { DOMParser } from "https://deno.land/x/deno_dom@v0.1.43/deno-dom-wasm.ts";

// HTTP客户端工具函数
export async function fetchWithTimeout(
  input: string | URL | Request,
  init?: RequestInit & { timeout?: number }
): Promise<Response> {
  const { timeout = 8000, ...options } = init || {};
  
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeout);
  
  try {
    const response = await fetch(input, {
      ...options,
      signal: controller.signal,
    });
    clearTimeout(timeoutId);
    return response;
  } catch (error) {
    clearTimeout(timeoutId);
    throw error;
  }
}

// Cron任务调度库
export { cron } from "https://deno.land/x/deno_cron@v1.0.0/cron.ts"; 