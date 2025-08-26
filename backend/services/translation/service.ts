import {
  TranslationProvider,
  TranslationRequest,
  TranslationResult,
} from './types.ts';
import { DeepSeekTranslationProvider } from './providers/deepseek.ts';
import { ClaudeTranslationProvider } from './providers/claude.ts';
import { OpenAITranslationProvider } from './providers/openai.ts';
import { translationCache } from './cache.ts';

export class TranslationService {
  private providers: Map<string, any> = new Map();
  private fallbackChain: string[] = ['deepseek', 'claude', 'openai'];

  constructor() {
    this.initializeProviders();
  }

  private initializeProviders() {
    // 从环境变量获取API密钥
    const deepseekKey = Deno.env.get('DEEPSEEK_API_KEY');
    const claudeKey = Deno.env.get('CLAUDE_API_KEY');
    const openaiKey = Deno.env.get('OPENAI_API_KEY');

    if (deepseekKey) {
      this.providers.set(
        'deepseek',
        new DeepSeekTranslationProvider(deepseekKey),
      );
    }

    if (claudeKey) {
      this.providers.set('claude', new ClaudeTranslationProvider(claudeKey));
    }

    if (openaiKey) {
      this.providers.set('openai', new OpenAITranslationProvider(openaiKey));
    }
  }

  /**
   * 智能翻译 - 根据优先级和可用性选择最佳提供商
   */
  async translate(request: TranslationRequest): Promise<TranslationResult> {
    // 1. 检查缓存
    const cached = await translationCache.get(
      request.text,
      request.sourceLanguage,
      request.targetLanguage,
    );

    if (cached) {
      console.log(`✅ 缓存命中: ${request.text.substring(0, 50)}...`);
      return {
        translatedText: cached.translatedText,
        confidence: 0.99, // 缓存结果高置信度
        model: 'cache',
        processingTime: 0,
        qualityScore: 1.0,
        originalText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: new Date().toISOString(),
      };
    }

    // 2. 根据优先级选择提供商
    const selectedProvider = this.selectProvider(request);

    if (!selectedProvider) {
      throw new Error('没有可用的翻译提供商');
    }

    try {
      console.log(`🤖 使用 ${selectedProvider} 进行翻译...`);
      const provider = this.providers.get(selectedProvider);
      const result = await provider.translate(request);

      // 3. 质量检查
      if (result.qualityScore < 0.6) {
        console.warn(
          `⚠️ 翻译质量较低 (${result.qualityScore})，尝试备选提供商...`,
        );
        return await this.fallbackTranslate(request, selectedProvider);
      }

      // 4. 保存到缓存
      await translationCache.set(
        request.text,
        result.translatedText,
        request.sourceLanguage,
        request.targetLanguage,
      );

      console.log(
        `✅ 翻译完成: ${result.model}, 质量: ${result.qualityScore.toFixed(2)}`,
      );
      return result;
    } catch (error) {
      console.error(`❌ ${selectedProvider} 翻译失败:`, error);
      return await this.fallbackTranslate(request, selectedProvider);
    }
  }

  /**
   * 选择最佳翻译提供商
   */
  private selectProvider(request: TranslationRequest): string | null {
    // 高优先级任务优先使用DeepSeek（主力）
    if (request.priority === 'high' && this.providers.has('deepseek')) {
      return 'deepseek';
    }

    // 一般任务按可用性选择（DeepSeek优先）
    for (const provider of this.fallbackChain) {
      if (this.providers.has(provider)) {
        return provider;
      }
    }

    return null;
  }

  /**
   * 备选翻译（当主要提供商失败时）
   */
  private async fallbackTranslate(
    request: TranslationRequest,
    failedProvider: string,
  ): Promise<TranslationResult> {
    const availableProviders = this.fallbackChain.filter(
      (p) => p !== failedProvider && this.providers.has(p),
    );

    for (const providerName of availableProviders) {
      try {
        console.log(`🔄 备选翻译提供商: ${providerName}`);
        const provider = this.providers.get(providerName);
        const result = await provider.translate(request);

        // 保存到缓存
        await translationCache.set(
          request.text,
          result.translatedText,
          request.sourceLanguage,
          request.targetLanguage,
        );

        return result;
      } catch (error) {
        console.error(`❌ 备选提供商 ${providerName} 也失败:`, error);
        continue;
      }
    }

    throw new Error('所有翻译提供商都不可用');
  }

  /**
   * 批量翻译
   */
  async batchTranslate(
    requests: TranslationRequest[],
  ): Promise<TranslationResult[]> {
    const results: TranslationResult[] = [];
    const batchSize = 5; // 并发控制

    for (let i = 0; i < requests.length; i += batchSize) {
      const batch = requests.slice(i, i + batchSize);
      const batchResults = await Promise.allSettled(
        batch.map((request) => this.translate(request)),
      );

      for (const result of batchResults) {
        if (result.status === 'fulfilled') {
          results.push(result.value);
        } else {
          console.error('批量翻译错误:', result.reason);
          // 添加错误占位结果
          results.push({
            translatedText: '翻译失败',
            confidence: 0,
            model: 'error',
            processingTime: 0,
            qualityScore: 0,
            originalText: '',
            sourceLanguage: '',
            targetLanguage: '',
            timestamp: new Date().toISOString(),
          });
        }
      }
    }

    return results;
  }

  /**
   * 获取服务状态
   */
  getStatus() {
    const availableProviders = Array.from(this.providers.keys());
    const cacheStats = translationCache.getStats();

    return {
      availableProviders,
      totalProviders: this.providers.size,
      fallbackChain: this.fallbackChain,
      cache: cacheStats,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * 预热缓存（可用于常用术语）
   */
  async warmupCache() {
    const commonFootballTerms = [
      { en: 'Goal', zh: '进球' },
      { en: 'Penalty', zh: '点球' },
      { en: 'Free kick', zh: '任意球' },
      { en: 'Corner kick', zh: '角球' },
      { en: 'Yellow card', zh: '黄牌' },
      { en: 'Red card', zh: '红牌' },
      { en: 'Offside', zh: '越位' },
      { en: 'Hat-trick', zh: '帽子戏法' },
      { en: 'Own goal', zh: '乌龙球' },
      { en: 'VAR', zh: '视频助理裁判' },
    ];

    console.log('🔥 开始预热翻译缓存...');

    for (const term of commonFootballTerms) {
      await translationCache.set(
        term.en,
        term.zh,
        'en',
        'zh-CN',
        7 * 24 * 60 * 60 * 1000, // 7天TTL
      );
    }

    console.log(
      `✅ 缓存预热完成，已添加 ${commonFootballTerms.length} 个常用术语`,
    );
  }
}

// 全局翻译服务实例
export const translationService = new TranslationService();
