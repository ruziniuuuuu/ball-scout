import { TranslationRequest, TranslationResult, SupportedModel } from '../types.ts';

export class ClaudeTranslationProvider {
  private apiKey: string;
  private baseUrl = 'https://api.anthropic.com/v1/messages';
  
  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async translate(request: TranslationRequest): Promise<TranslationResult> {
    const startTime = Date.now();
    
    try {
      const prompt = this.buildFootballTranslationPrompt(request);
      
      const response = await fetch(this.baseUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-3-5-sonnet-20241022',
          max_tokens: 4000,
          temperature: 0.1, // 低温度确保一致性
          messages: [
            {
              role: 'user',
              content: prompt,
            },
          ],
        }),
      });

      if (!response.ok) {
        throw new Error(`Claude API error: ${response.status}`);
      }

      const data = await response.json();
      const translatedText = data.content[0].text;
      const processingTime = Date.now() - startTime;

      // 评估翻译质量
      const qualityScore = this.evaluateTranslationQuality(
        request.text,
        translatedText,
        request.domain
      );

      return {
        translatedText,
        confidence: 0.95, // Claude通常有较高置信度
        model: 'claude-3.5-sonnet',
        processingTime,
        qualityScore,
        originalText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('Claude translation error:', error);
      throw error;
    }
  }

  private buildFootballTranslationPrompt(request: TranslationRequest): string {
    const { text, sourceLanguage, targetLanguage, domain } = request;
    
    return `你是一位专业的足球新闻翻译专家。请将以下${sourceLanguage}文本翻译成${targetLanguage === 'zh-CN' ? '简体中文' : '繁体中文'}，要求：

1. 保持足球术语的专业性和准确性
2. 球员和球队名称使用中文惯用译名（如：Messi→梅西，Real Madrid→皇家马德里）
3. 保持原文的语气和风格
4. 确保翻译流畅自然，符合中文表达习惯
5. 对于专业足球术语要特别注意准确性

常用术语参考：
- Transfer → 转会
- Hat-trick → 帽子戏法
- Own goal → 乌龙球
- Penalty → 点球
- Free kick → 任意球
- Corner kick → 角球
- Yellow card → 黄牌
- Red card → 红牌
- Offside → 越位
- VAR → 视频助理裁判

原文: ${text}

请直接返回翻译结果，无需额外说明。`;
  }

  private evaluateTranslationQuality(
    originalText: string,
    translatedText: string,
    domain: string
  ): number {
    // 简单的质量评估算法
    let score = 0.8; // 基础分数

    // 检查是否包含足球相关术语
    const footballTerms = [
      '足球', '球员', '球队', '比赛', '联赛', '转会', '进球', '助攻', 
      '射门', '传球', '防守', '进攻', '教练', '裁判', '球场'
    ];
    
    const hasFootballTerms = footballTerms.some(term => 
      translatedText.includes(term)
    );
    
    if (hasFootballTerms) {
      score += 0.1;
    }

    // 检查长度合理性（译文不应该过短或过长）
    const lengthRatio = translatedText.length / originalText.length;
    if (lengthRatio >= 0.5 && lengthRatio <= 2.0) {
      score += 0.1;
    }

    return Math.min(score, 1.0);
  }
} 