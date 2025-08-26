/**
 * 翻译服务类型定义
 */

export interface TranslationRequest {
  text: string;
  sourceLanguage: string;
  targetLanguage: string;
  domain?: 'football' | 'general';
  priority?: 'high' | 'medium' | 'low';
  context?: string;
  style?: 'formal' | 'casual' | 'concise' | 'detailed';
  maxLength?: number;
  provider?: string;
}

export interface TranslationResult {
  translatedText: string;
  confidence: number;
  model: string;
  processingTime: number;
  qualityScore: number;
  originalText: string;
  sourceLanguage: string;
  targetLanguage: string;
  timestamp: string;
  provider?: string;
  metadata?: Record<string, any>;
}

export interface TranslationProvider {
  translate(request: TranslationRequest): Promise<TranslationResult>;
  isAvailable(): boolean;
  getStatus(): ProviderStatus;
}

export interface ProviderStatus {
  available: boolean;
  rateLimit?: {
    remaining: number;
    resetTime: number;
  };
  lastError?: string;
  performance?: {
    averageResponseTime: number;
    successRate: number;
  };
}

export interface CacheEntry {
  translatedText: string;
  sourceLanguage: string;
  targetLanguage: string;
  timestamp: number;
  provider: string;
  qualityScore: number;
}

export interface FootballTerms {
  getTermMappings(): Map<string, string>;
  getProtectedTerms(): string[];
  getTeamMappings(): Map<string, string>;
  getPlayerMappings(): Map<string, string>;
  getCompetitionMappings(): Map<string, string>;
  replaceTerms(text: string): string;
  detectFootballEntities(text: string): {
    teams: string[];
    players: string[];
    competitions: string[];
    terms: string[];
  };
  generateContextPrompt(text: string): string;
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

export interface SupportedModel {
  id: string;
  name: string;
  maxTokens: number;
  costPer1kTokens: number;
  languages: string[];
  specialties: string[];
}

export const SUPPORTED_MODELS = {
  CLAUDE_SONNET: 'claude-3.5-sonnet',
  GPT4: 'gpt-4',
  DEEPSEEK_CHAT: 'deepseek-chat',
  GPT4_TURBO: 'gpt-4-turbo',
} as const;

export type SupportedModelId =
  typeof SUPPORTED_MODELS[keyof typeof SUPPORTED_MODELS];
