// API响应类型
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };
  meta?: {
    page?: number;
    limit?: number;
    total?: number;
    timestamp: string;
  };
}

// 错误类型
export class ServiceError extends Error {
  constructor(
    public code: string,
    message: string,
    public statusCode: number = 500,
    public details?: unknown,
  ) {
    super(message);
    this.name = 'ServiceError';
  }
}

// 用户相关类型
export interface User {
  id: string;
  username: string;
  email: string;
  avatar?: string;
  role: 'user' | 'admin' | 'moderator';
  preferences: UserPreferences;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserPreferences {
  favoriteTeams: string[];
  favoriteLeagues: string[];
  language: 'zh' | 'en';
  notificationSettings: {
    news: boolean;
    matches: boolean;
    transfers: boolean;
  };
}

// 新闻相关类型
export interface NewsArticle {
  id: string;
  title: string;
  content: string;
  summary?: string;
  source: string;
  author?: string;
  publishedAt: Date;
  category: NewsCategory;
  language: string;
  translationZh?: string;
  tags: string[];
  imageUrl?: string;
  readCount: number;
  sentimentScore?: number;
  reliability: number;
  createdAt: Date;
  updatedAt: Date;
}

export type NewsCategory =
  | 'news'
  | 'transfer'
  | 'match'
  | 'analysis'
  | 'interview'
  | 'rumor';

// 球队相关类型
export interface Team {
  id: string;
  name: string;
  nameEn: string;
  league: string;
  country: string;
  logoUrl?: string;
  foundedYear?: number;
  stadium?: string;
  website?: string;
  socialMedia: {
    twitter?: string;
    instagram?: string;
    facebook?: string;
  };
  createdAt: Date;
  updatedAt: Date;
}

// 比赛相关类型
export interface Match {
  id: string;
  homeTeam: Team;
  awayTeam: Team;
  homeScore?: number;
  awayScore?: number;
  status: MatchStatus;
  kickoffTime: Date;
  venue?: string;
  league: string;
  season: string;
  matchweek?: number;
  createdAt: Date;
  updatedAt: Date;
}

export type MatchStatus =
  | 'scheduled'
  | 'live'
  | 'halftime'
  | 'finished'
  | 'cancelled'
  | 'postponed';

// 评论相关类型
export interface Comment {
  id: string;
  userId: string;
  articleId?: string;
  matchId?: string;
  content: string;
  parentId?: string; // 用于回复
  likes: number;
  dislikes: number;
  isDeleted: boolean;
  createdAt: Date;
  updatedAt: Date;
}

// 数据库配置类型
export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  username: string;
  password: string;
}

// JWT配置类型
export interface JwtConfig {
  secret: string;
  expiresIn: string;
}

// 应用配置类型
export interface AppConfig {
  port: number;
  env: 'development' | 'staging' | 'production';
  database: DatabaseConfig;
  jwt: JwtConfig;
  redis: {
    host: string;
    port: number;
    password?: string;
  };
  ai: {
    openaiApiKey?: string;
    claudeApiKey?: string;
    tongYiApiKey?: string;
  };
}

export type RecordOf<T> = Record<string, T>;
