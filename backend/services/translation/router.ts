import { Router } from '../../deps.ts';
import { z } from 'https://deno.land/x/zod@v3.22.4/mod.ts';
import { translationService } from './service.ts';
import { TranslationRequest } from './types.ts';

const translationRouter = new Router();

// 数据验证Schema
const translateSchema = z.object({
  text: z.string().min(1).max(10000),
  sourceLanguage: z.string().min(2).max(10),
  targetLanguage: z.enum(['zh-CN', 'zh-TW']),
  domain: z.enum(['football', 'sports', 'news']).default('football'),
  priority: z.enum(['high', 'medium', 'low']).default('medium'),
});

const batchTranslateSchema = z.object({
  requests: z.array(translateSchema).min(1).max(20),
});

// POST /api/v1/translate - 单个文本翻译
translationRouter.post('/api/v1/translate', async (ctx) => {
  try {
    const body = await ctx.request.body().value;
    const requestData = translateSchema.parse(body);

    const request: TranslationRequest = {
      text: requestData.text,
      sourceLanguage: requestData.sourceLanguage,
      targetLanguage: requestData.targetLanguage,
      domain: requestData.domain,
      priority: requestData.priority,
    };

    const result = await translationService.translate(request);

    ctx.response.body = {
      success: true,
      data: result,
      meta: {
        timestamp: new Date().toISOString(),
        requestId: crypto.randomUUID(),
      },
    };
  } catch (error) {
    console.error('翻译错误:', error);
    
    ctx.response.status = error instanceof z.ZodError ? 400 : 500;
    ctx.response.body = {
      success: false,
      error: {
        code: error instanceof z.ZodError ? 'VALIDATION_ERROR' : 'TRANSLATION_ERROR',
        message: error instanceof z.ZodError 
          ? '请求参数无效' 
          : (error as Error).message || '翻译服务暂时不可用',
        details: error instanceof z.ZodError ? error.errors : undefined,
      },
    };
  }
});

// POST /api/v1/translate/batch - 批量翻译
translationRouter.post('/api/v1/translate/batch', async (ctx) => {
  try {
    const body = await ctx.request.body().value;
    const { requests } = batchTranslateSchema.parse(body);

    const translationRequests: TranslationRequest[] = requests.map(req => ({
      text: req.text,
      sourceLanguage: req.sourceLanguage,
      targetLanguage: req.targetLanguage,
      domain: req.domain,
      priority: req.priority,
    }));

    const results = await translationService.batchTranslate(translationRequests);

    ctx.response.body = {
      success: true,
      data: results,
      meta: {
        total: results.length,
        successful: results.filter(r => r.confidence > 0).length,
        failed: results.filter(r => r.confidence === 0).length,
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('批量翻译错误:', error);
    
    ctx.response.status = error instanceof z.ZodError ? 400 : 500;
    ctx.response.body = {
      success: false,
      error: {
        code: error instanceof z.ZodError ? 'VALIDATION_ERROR' : 'BATCH_TRANSLATION_ERROR',
        message: error instanceof z.ZodError 
          ? '请求参数无效' 
          : '批量翻译服务暂时不可用',
        details: error instanceof z.ZodError ? error.errors : undefined,
      },
    };
  }
});

// GET /api/v1/translate/status - 获取翻译服务状态
translationRouter.get('/api/v1/translate/status', (ctx) => {
  try {
    const status = translationService.getStatus();
    
    ctx.response.body = {
      success: true,
      data: status,
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('获取状态错误:', error);
    
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'STATUS_ERROR',
        message: '无法获取服务状态',
      },
    };
  }
});

// POST /api/v1/translate/warmup - 预热缓存（管理员功能）
translationRouter.post('/api/v1/translate/warmup', async (ctx) => {
  try {
    await translationService.warmupCache();
    
    ctx.response.body = {
      success: true,
      data: {
        message: '缓存预热完成',
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('缓存预热错误:', error);
    
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'WARMUP_ERROR',
        message: '缓存预热失败',
      },
    };
  }
});

// GET /api/v1/translate/health - 翻译服务健康检查
translationRouter.get('/api/v1/translate/health', async (ctx) => {
  try {
    // 测试翻译一个简单句子
    const testRequest: TranslationRequest = {
      text: 'Hello',
      sourceLanguage: 'en',
      targetLanguage: 'zh-CN',
      domain: 'football',
      priority: 'low',
    };

    const startTime = Date.now();
    const result = await translationService.translate(testRequest);
    const responseTime = Date.now() - startTime;

    const isHealthy = result.confidence > 0.5;

    ctx.response.status = isHealthy ? 200 : 503;
    ctx.response.body = {
      success: isHealthy,
      data: {
        status: isHealthy ? 'healthy' : 'unhealthy',
        responseTime,
        providers: translationService.getStatus().availableProviders,
        testResult: {
          input: testRequest.text,
          output: result.translatedText,
          confidence: result.confidence,
          model: result.model,
        },
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('健康检查错误:', error);
    
    ctx.response.status = 503;
    ctx.response.body = {
      success: false,
      data: {
        status: 'unhealthy',
        error: (error as Error).message,
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  }
});

export default translationRouter; 