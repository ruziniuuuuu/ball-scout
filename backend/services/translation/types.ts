// 翻译服务类型定义
export interface TranslationRequest {
  text: string;
  sourceLanguage: string;
  targetLanguage: 'zh-CN' | 'zh-TW';
  domain: 'football' | 'sports' | 'news';
  priority: 'high' | 'medium' | 'low';
}

export interface TranslationResult {
  translatedText: string;
  confidence: number; // 0-1
  model: string;
  processingTime: number;
  qualityScore: number; // 基于足球术语准确性
  originalText: string;
  sourceLanguage: string;
  targetLanguage: string;
  timestamp: string;
}

export interface TranslationProvider {
  name: string;
  apiKey: string;
  endpoint: string;
  priority: number;
  costPerToken: number;
  maxTokens: number;
  supportedLanguages: string[];
}

export interface FootballTerms {
  [key: string]: {
    zh: string;
    aliases: string[];
    category: 'player' | 'team' | 'position' | 'tactic' | 'competition';
  };
}

export interface TranslationCache {
  key: string;
  text: string;
  translatedText: string;
  sourceLanguage: string;
  targetLanguage: string;
  createdAt: string;
  expiresAt: string;
  hitCount: number;
}

export interface TranslationQuality {
  score: number;
  factors: {
    termAccuracy: number;
    fluency: number;
    consistency: number;
    contextRelevance: number;
  };
  suggestions?: string[];
}

export const SUPPORTED_MODELS = {
  CLAUDE_SONNET: 'claude-3.5-sonnet',
  GPT4: 'gpt-4',
  QWEN: 'qwen-plus',
  LLAMA: 'llama-3.1-70b',
} as const;

export type SupportedModel = typeof SUPPORTED_MODELS[keyof typeof SUPPORTED_MODELS]; 