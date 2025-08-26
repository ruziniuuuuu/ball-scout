import {
  SupportedModel,
  TranslationRequest,
  TranslationResult,
} from '../types.ts';

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
              content:
                '你是一位专业的足球新闻翻译专家，精通足球术语和中文表达。',
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

    return `你是一位专业的足球新闻翻译专家。请将以下${sourceLanguage}足球新闻准确翻译成${
      targetLanguage === 'zh-CN' ? '简体中文' : '繁体中文'
    }。

翻译要求：
1. 保持足球术语的专业性和准确性
2. 使用正确的球员和球队中文译名
3. 保持原文的语气和风格
4. 确保翻译流畅自然，符合中文表达习惯
5. 对于专业足球术语要特别注意准确性

重要术语对照：
足球术语：
- Transfer/Signing → 转会/签约
- Hat-trick → 帽子戏法
- Own goal → 乌龙球
- Penalty → 点球
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

常见球员译名：
- Messi → 梅西
- Ronaldo → C罗/罗纳尔多
- Neymar → 内马尔
- Mbappé → 姆巴佩
- Haaland → 哈兰德
- Bellingham → 贝林厄姆

球队译名：
- Real Madrid → 皇家马德里/皇马
- Barcelona → 巴塞罗那/巴萨
- Manchester United → 曼联
- Manchester City → 曼城
- Liverpool → 利物浦
- Arsenal → 阿森纳
- Chelsea → 切尔西
- Bayern Munich → 拜仁慕尼黑/拜仁
- Borussia Dortmund → 多特蒙德/多特
- Paris Saint-Germain → 巴黎圣日耳曼/PSG

联赛译名：
- Premier League → 英超
- La Liga → 西甲
- Serie A → 意甲
- Bundesliga → 德甲
- Champions League → 欧冠
- Europa League → 欧联杯

原文内容：${text}

请直接返回翻译结果，不要添加任何解释。`;
  }

  private evaluateQuality(
    originalText: string,
    translatedText: string,
  ): number {
    // OpenAI翻译质量评估算法
    let score = 0.88; // OpenAI的基础分数

    // 检查是否包含足球相关术语
    const footballTerms = [
      '足球',
      '球员',
      '球队',
      '比赛',
      '联赛',
      '转会',
      '进球',
      '助攻',
      '射门',
      '传球',
      '防守',
      '进攻',
      '教练',
      '裁判',
      '球场',
      '赛季',
      '英超',
      '西甲',
      '意甲',
      '德甲',
      '欧冠',
      '欧联杯',
      '世界杯',
    ];

    const hasFootballTerms = footballTerms.some((term) =>
      translatedText.includes(term)
    );

    if (hasFootballTerms) {
      score += 0.07;
    }

    // 检查译文是否包含常见的球员/球队中文译名
    const commonNames = [
      '梅西',
      'C罗',
      '内马尔',
      '姆巴佩',
      '哈兰德',
      '贝林厄姆',
      '皇马',
      '巴萨',
      '曼联',
      '曼城',
      '利物浦',
      '阿森纳',
      '切尔西',
      '拜仁',
      '多特',
      'PSG',
      '国米',
      '米兰',
      '尤文',
    ];

    const hasKnownNames = commonNames.some((name) =>
      translatedText.includes(name)
    );

    if (hasKnownNames) {
      score += 0.03;
    }

    // 检查长度合理性
    const lengthRatio = translatedText.length / originalText.length;
    if (lengthRatio >= 0.5 && lengthRatio <= 2.0) {
      score += 0.02;
    } else {
      score -= 0.05;
    }

    // 检查是否有明显的翻译错误
    const errorIndicators = ['[翻译错误]', '[无法翻译]', '???', '***', 'ERROR'];
    const hasErrors = errorIndicators.some((indicator) =>
      translatedText.toLowerCase().includes(indicator.toLowerCase())
    );

    if (hasErrors) {
      score -= 0.15;
    }

    return Math.min(Math.max(score, 0.0), 1.0);
  }

  // 获取支持的模型列表
  static getSupportedModels(): SupportedModel[] {
    return [
      {
        id: 'gpt-4',
        name: 'GPT-4',
        maxTokens: 8192,
        costPer1kTokens: 0.03,
        languages: [
          'en',
          'zh-CN',
          'zh-TW',
          'es',
          'fr',
          'de',
          'it',
          'pt',
          'ja',
          'ko',
        ],
        specialties: ['general', 'news', 'sports', 'football'],
      },
      {
        id: 'gpt-4-turbo',
        name: 'GPT-4 Turbo',
        maxTokens: 128000,
        costPer1kTokens: 0.01,
        languages: [
          'en',
          'zh-CN',
          'zh-TW',
          'es',
          'fr',
          'de',
          'it',
          'pt',
          'ja',
          'ko',
        ],
        specialties: ['general', 'news', 'sports', 'football'],
      },
    ];
  }
}
