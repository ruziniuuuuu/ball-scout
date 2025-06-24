import { TranslationRequest, TranslationResult } from '../types.ts';

export class OpenAITranslationProvider {
  private apiKey: string;
  private baseUrl = 'https://api.openai.com/v1/chat/completions';
  
  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async translate(request: TranslationRequest): Promise<TranslationResult> {
    const startTime = Date.now();
    
    try {
      const prompt = this.buildTranslationPrompt(request);
      
      const response = await fetch(this.baseUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          model: 'gpt-4',
          messages: [
            {
              role: 'system',
              content: '你是一位专业的足球新闻翻译专家，精通足球术语和中文表达。',
            },
            {
              role: 'user',
              content: prompt,
            },
          ],
          temperature: 0.1,
          max_tokens: 3000,
        }),
      });

      if (!response.ok) {
        throw new Error(`OpenAI API error: ${response.status}`);
      }

      const data = await response.json();
      const translatedText = data.choices[0].message.content;
      const processingTime = Date.now() - startTime;

      return {
        translatedText,
        confidence: 0.90,
        model: 'gpt-4',
        processingTime,
        qualityScore: this.evaluateQuality(request.text, translatedText),
        originalText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('OpenAI translation error:', error);
      throw error;
    }
  }

  private buildTranslationPrompt(request: TranslationRequest): string {
    const { text, sourceLanguage, targetLanguage } = request;
    
    return `请将以下${sourceLanguage}足球新闻翻译成${targetLanguage === 'zh-CN' ? '简体中文' : '繁体中文'}。

要求：
1. 准确翻译足球专业术语
2. 保持原文语气和风格  
3. 使用中文惯用的球队和球员名称
4. 确保表达自然流畅

原文：${text}

翻译：`;
  }

  private evaluateQuality(originalText: string, translatedText: string): number {
    // 基础质量评估
    const lengthRatio = translatedText.length / originalText.length;
    return lengthRatio >= 0.5 && lengthRatio <= 2.0 ? 0.85 : 0.7;
  }
} 