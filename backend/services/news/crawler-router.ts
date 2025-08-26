/**
 * 自动化新闻爬取器管理API
 */

import { Router } from '../../deps.ts';
import { autoNewsCrawler } from './auto-crawler.ts';

export const crawlerRouter = new Router();

// 启动自动化爬取服务
crawlerRouter.post('/api/v1/crawler/start', async (ctx) => {
  try {
    await autoNewsCrawler.start();

    ctx.response.body = {
      success: true,
      message: '自动化新闻爬取服务已启动',
      data: autoNewsCrawler.getStatus(),
    };
  } catch (error) {
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'START_FAILED',
        message: '启动爬取服务失败',
        details: error.message,
      },
    };
  }
});

// 停止自动化爬取服务
crawlerRouter.post('/api/v1/crawler/stop', (ctx) => {
  try {
    autoNewsCrawler.stop();

    ctx.response.body = {
      success: true,
      message: '自动化新闻爬取服务已停止',
      data: autoNewsCrawler.getStatus(),
    };
  } catch (error) {
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'STOP_FAILED',
        message: '停止爬取服务失败',
        details: error.message,
      },
    };
  }
});

// 获取爬取器状态
crawlerRouter.get('/api/v1/crawler/status', (ctx) => {
  ctx.response.body = {
    success: true,
    data: autoNewsCrawler.getStatus(),
    meta: {
      timestamp: new Date().toISOString(),
    },
  };
});

// 手动触发一次爬取
crawlerRouter.post('/api/v1/crawler/run-once', async (ctx) => {
  try {
    // 创建一个临时的爬取器实例来执行单次任务
    const tempCrawler = new (await import('./auto-crawler.ts')).AutoNewsCrawler(
      {
        interval: 1, // 无关紧要，因为我们只运行一次
        maxNewsPerRun: 20,
        enableTranslation: true,
        saveToDatabase: false, // 暂时不保存到数据库
        generateStatic: true,
      },
    );

    // 通过反射调用私有方法（仅用于手动触发）
    await (tempCrawler as any).runCrawl();

    ctx.response.body = {
      success: true,
      message: '手动爬取任务已完成',
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'MANUAL_RUN_FAILED',
        message: '手动爬取任务失败',
        details: error.message,
      },
    };
  }
});

// 配置爬取器参数
crawlerRouter.put('/api/v1/crawler/config', async (ctx) => {
  try {
    const body = await ctx.request.body().value;

    // 验证配置参数
    const validKeys = [
      'interval',
      'maxNewsPerRun',
      'enableTranslation',
      'saveToDatabase',
      'generateStatic',
    ];
    const config: any = {};

    for (const key of validKeys) {
      if (body[key] !== undefined) {
        config[key] = body[key];
      }
    }

    // 重新创建爬取器实例（如果需要的话）
    // 注意：这里需要停止当前服务并用新配置重启
    const wasRunning = autoNewsCrawler.getStatus().isRunning;

    if (wasRunning) {
      autoNewsCrawler.stop();
    }

    // 创建新的配置化实例
    const newCrawler = new (await import('./auto-crawler.ts')).AutoNewsCrawler(
      config,
    );

    if (wasRunning) {
      await newCrawler.start();
    }

    ctx.response.body = {
      success: true,
      message: '爬取器配置已更新',
      data: newCrawler.getStatus(),
    };
  } catch (error) {
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'CONFIG_UPDATE_FAILED',
        message: '更新配置失败',
        details: error.message,
      },
    };
  }
});

// 获取生成的静态页面列表
crawlerRouter.get('/api/v1/crawler/static-pages', async (ctx) => {
  try {
    const pages: string[] = [];

    // 检查静态目录
    try {
      for await (const dirEntry of Deno.readDir('./static')) {
        if (dirEntry.isFile && dirEntry.name.endsWith('.html')) {
          pages.push(dirEntry.name);
        }
      }

      // 检查新闻子目录
      try {
        for await (const dirEntry of Deno.readDir('./static/news')) {
          if (dirEntry.isFile && dirEntry.name.endsWith('.html')) {
            pages.push(`news/${dirEntry.name}`);
          }
        }
      } catch {
        // 新闻目录可能不存在
      }
    } catch {
      // 静态目录可能不存在
    }

    ctx.response.body = {
      success: true,
      data: {
        pages,
        count: pages.length,
        mainPage: pages.includes('index.html') ? './static/index.html' : null,
      },
      meta: {
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: {
        code: 'LIST_PAGES_FAILED',
        message: '获取静态页面列表失败',
        details: error.message,
      },
    };
  }
});
