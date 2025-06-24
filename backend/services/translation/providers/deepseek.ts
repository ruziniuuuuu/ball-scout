import { TranslationRequest, TranslationResult, SupportedModel } from '../types.ts';

export class DeepSeekTranslationProvider {
  private apiKey: string;
  private baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  
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
          'Authorization': `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          model: 'deepseek-chat',
          messages: [
            {
              role: 'system',
              content: '你是一位专业的足球新闻翻译专家，擅长将各种语言的足球新闻准确翻译成中文。',
            },
            {
              role: 'user',
              content: prompt,
            },
          ],
          temperature: 0.1, // 低温度确保一致性
          max_tokens: 4000,
          stream: false,
        }),
      });

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`DeepSeek API error: ${response.status} - ${errorText}`);
      }

      const data = await response.json();
      const translatedText = data.choices[0].message.content;
      const processingTime = Date.now() - startTime;

      // 评估翻译质量
      const qualityScore = this.evaluateTranslationQuality(
        request.text,
        translatedText,
        request.domain
      );

      return {
        translatedText,
        confidence: 0.92, // DeepSeek在中文翻译方面有较高置信度
        model: 'deepseek-chat',
        processingTime,
        qualityScore,
        originalText: request.text,
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      console.error('DeepSeek translation error:', error);
      throw error;
    }
  }

  private buildFootballTranslationPrompt(request: TranslationRequest): string {
    const { text, sourceLanguage, targetLanguage, domain } = request;
    
    return `请将以下${sourceLanguage}足球新闻翻译成${targetLanguage === 'zh-CN' ? '简体中文' : '繁体中文'}，要求：

1. 保持足球术语的专业性和准确性
2. 球员和球队名称使用中文惯用译名（如：Messi→梅西，Real Madrid→皇家马德里，Bayern Munich→拜仁慕尼黑）
3. 保持原文的语气和风格
4. 确保翻译流畅自然，符合中文表达习惯
5. 对于专业足球术语要特别注意准确性

常用术语对照：
- Transfer/Signing → 转会/签约
- Hat-trick → 帽子戏法
- Own goal → 乌龙球
- Penalty → 点球/罚球
- Free kick → 任意球
- Corner kick → 角球
- Yellow card → 黄牌
- Red card → 红牌
- Offside → 越位
- VAR → 视频助理裁判
- Clean sheet → 零封
- Assist → 助攻
- Debut → 首秀
- Loan → 租借

联赛名称对照：
- Premier League → 英超
- La Liga → 西甲
- Serie A → 意甲
- Bundesliga → 德甲
- Champions League → 欧冠
- Europa League → 欧联杯

原文内容: ${text}

请直接返回翻译结果，不要添加任何解释或说明。`;
  }

  private evaluateTranslationQuality(
    originalText: string,
    translatedText: string,
    domain: string
  ): number {
    // 翻译质量评估算法
    let score = 0.85; // DeepSeek的基础分数

    // 检查是否包含足球相关术语
    const footballTerms = [
      '足球', '球员', '球队', '比赛', '联赛', '转会', '进球', '助攻', 
      '射门', '传球', '防守', '进攻', '教练', '裁判', '球场', '赛季',
      '英超', '西甲', '意甲', '德甲', '欧冠', '欧联杯', '世界杯'
    ];
    
    const hasFootballTerms = footballTerms.some(term => 
      translatedText.includes(term)
    );
    
    if (hasFootballTerms) {
      score += 0.1;
    }

    // 检查译文是否包含常见的球员/球队中文译名
    const commonNames = [
      '梅西', 'C罗', '内马尔', '姆巴佩', '哈兰德', '贝林厄姆',
      '皇马', '巴萨', '曼联', '曼城', '利物浦', '阿森纳', '切尔西',
      '拜仁', '多特', 'PSG', '国米', '米兰', '尤文'
    ];
    
    const hasKnownNames = commonNames.some(name => 
      translatedText.includes(name)
    );
    
    if (hasKnownNames) {
      score += 0.05;
    }

    // 检查长度合理性（译文不应该过短或过长）
    const lengthRatio = translatedText.length / originalText.length;
    if (lengthRatio >= 0.4 && lengthRatio <= 2.5) {
      score += 0.05;
    } else {
      score -= 0.1;
    }

    // 检查是否有明显的翻译错误标识
    const errorIndicators = ['[翻译错误]', '[无法翻译]', '???', '***'];
    const hasErrors = errorIndicators.some(indicator => 
      translatedText.includes(indicator)
    );
    
    if (hasErrors) {
      score -= 0.3;
    }

    return Math.min(Math.max(score, 0.0), 1.0);
  }

  // 获取支持的模型列表
  static getSupportedModels(): SupportedModel[] {
    return [
      {
        id: 'deepseek-chat',
        name: 'DeepSeek Chat',
        maxTokens: 32768,
        costPer1kTokens: 0.001, // DeepSeek的优势：低成本
        languages: ['en', 'zh-CN', 'zh-TW', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko'],
        specialties: ['football', 'sports', 'news', 'general'],
      },
    ];
  }
} 