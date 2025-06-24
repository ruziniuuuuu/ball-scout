-- 球探社数据库初始化脚本
-- PostgreSQL 数据库设置

-- 创建数据库（如果不存在）
-- 注意：需要在 postgres 数据库中运行这个命令
-- CREATE DATABASE ball_scout;

-- 连接到 ball_scout 数据库后执行以下脚本

-- 启用 UUID 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 清理现有表（开发环境）
DROP TABLE IF EXISTS comments CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS news_articles CASCADE;
DROP TABLE IF EXISTS teams CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar VARCHAR(500),
    nickname VARCHAR(100),
    role VARCHAR(20) DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator')),
    preferences JSONB DEFAULT '{}',
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 球队表
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    league VARCHAR(100),
    country VARCHAR(50),
    logo_url VARCHAR(500),
    founded_year INTEGER,
    stadium VARCHAR(200),
    website VARCHAR(500),
    social_media JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 新闻文章表
CREATE TABLE news_articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(500) NOT NULL,
    content TEXT,
    summary TEXT,
    source VARCHAR(100) NOT NULL,
    author VARCHAR(100),
    published_at TIMESTAMP,
    category VARCHAR(50) NOT NULL CHECK (category IN ('news', 'transfer', 'match', 'analysis', 'interview', 'rumor')),
    language VARCHAR(10) DEFAULT 'en',
    translation_zh TEXT,
    tags TEXT[] DEFAULT '{}',
    image_url VARCHAR(500),
    read_count INTEGER DEFAULT 0,
    sentiment_score DECIMAL(3,2),
    reliability INTEGER DEFAULT 5 CHECK (reliability BETWEEN 1 AND 10),
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 比赛表
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    home_team_id UUID REFERENCES teams(id),
    away_team_id UUID REFERENCES teams(id),
    home_score INTEGER,
    away_score INTEGER,
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'finished', 'postponed', 'cancelled')),
    kickoff_time TIMESTAMP NOT NULL,
    venue VARCHAR(200),
    league VARCHAR(100),
    season VARCHAR(20),
    matchweek INTEGER,
    weather JSONB,
    statistics JSONB DEFAULT '{}',
    events JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 评论表
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    article_id UUID REFERENCES news_articles(id) ON DELETE CASCADE,
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    parent_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    likes INTEGER DEFAULT 0,
    dislikes INTEGER DEFAULT 0,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- 确保评论要么关联文章，要么关联比赛
    CONSTRAINT comment_target_check CHECK (
        (article_id IS NOT NULL AND match_id IS NULL) OR
        (article_id IS NULL AND match_id IS NOT NULL)
    )
);

-- 用户收藏表
CREATE TABLE user_favorites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    article_id UUID REFERENCES news_articles(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, article_id)
);

-- 阅读历史表
CREATE TABLE reading_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    article_id UUID REFERENCES news_articles(id) ON DELETE CASCADE,
    read_duration INTEGER DEFAULT 0, -- 阅读时长(秒)
    read_percentage INTEGER DEFAULT 0, -- 阅读进度(%)
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, article_id)
);

-- 创建索引以优化查询性能
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_created_at ON users(created_at);

CREATE INDEX idx_news_articles_category ON news_articles(category);
CREATE INDEX idx_news_articles_published_at ON news_articles(published_at DESC);
CREATE INDEX idx_news_articles_source ON news_articles(source);
CREATE INDEX idx_news_articles_featured ON news_articles(is_featured);

CREATE INDEX idx_matches_kickoff_time ON matches(kickoff_time);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_league ON matches(league);

CREATE INDEX idx_comments_article_id ON comments(article_id);
CREATE INDEX idx_comments_match_id ON comments(match_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_created_at ON comments(created_at DESC);

CREATE INDEX idx_user_favorites_user_id ON user_favorites(user_id);
CREATE INDEX idx_reading_history_user_id ON reading_history(user_id);

-- 插入示例数据

-- 示例用户
INSERT INTO users (username, email, password_hash, nickname, preferences) VALUES 
('admin', 'admin@ballscout.com', '$2b$10$example_hash', '管理员', '{"favoriteTeams": ["皇马", "巴萨"], "language": "zh-CN"}'),
('football_fan', 'fan@example.com', '$2b$10$example_hash', '足球迷', '{"favoriteTeams": ["曼城"], "language": "zh-CN"}');

-- 示例球队
INSERT INTO teams (name, name_en, league, country, founded_year, stadium) VALUES 
('皇家马德里', 'Real Madrid', '西甲', '西班牙', 1902, '伯纳乌球场'),
('巴塞罗那', 'FC Barcelona', '西甲', '西班牙', 1899, '诺坎普球场'),
('曼城', 'Manchester City', '英超', '英格兰', 1880, '伊蒂哈德球场'),
('利物浦', 'Liverpool FC', '英超', '英格兰', 1892, '安菲尔德球场');

-- 示例新闻
INSERT INTO news_articles (title, summary, content, source, category, published_at, tags, reliability) VALUES 
(
    '皇马签下新星前锋',
    '皇马官方宣布签下年仅19岁的巴西新星前锋，转会费高达8000万欧元。',
    '皇家马德里俱乐部今日官方宣布，成功签下年仅19岁的巴西前锋新星，转会费高达8000万欧元，合同期至2029年。这位年轻球员身高1米85，司职中锋，也可胜任边锋位置。',
    'ESPN',
    'transfer',
    NOW() - INTERVAL '2 hours',
    ARRAY['皇马', '转会', '巴西', '前锋'],
    9
),
(
    'C罗创造新纪录',
    '葡萄牙巨星C罗在昨晚的比赛中再次创造历史，成为首位在5届欧洲杯中都有进球的球员。',
    '葡萄牙巨星C罗在昨晚的比赛中再次创造历史，成为首位在5届欧洲杯中都有进球的球员。这一纪录彰显了他的持久性和伟大性，即使在39岁的年龄，他依然保持着惊人的竞技状态。',
    'Goal.com',
    'news',
    NOW() - INTERVAL '6 hours',
    ARRAY['C罗', '纪录', '欧洲杯'],
    10
);

-- 示例比赛
INSERT INTO matches (home_team_id, away_team_id, home_score, away_score, status, kickoff_time, league, venue) 
SELECT 
    (SELECT id FROM teams WHERE name = '皇家马德里'),
    (SELECT id FROM teams WHERE name = '巴塞罗那'),
    2, 1, 'finished',
    NOW() - INTERVAL '2 hours',
    '西甲',
    '伯纳乌球场';

-- 触发器：自动更新 updated_at 字段
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON teams FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_news_articles_updated_at BEFORE UPDATE ON news_articles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_matches_updated_at BEFORE UPDATE ON matches FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_comments_updated_at BEFORE UPDATE ON comments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 创建视图：文章统计信息
CREATE VIEW article_stats AS
SELECT 
    na.id,
    na.title,
    na.read_count,
    COUNT(c.id) as comment_count,
    COUNT(uf.id) as favorite_count
FROM news_articles na
LEFT JOIN comments c ON na.id = c.article_id AND c.is_deleted = FALSE
LEFT JOIN user_favorites uf ON na.id = uf.article_id
GROUP BY na.id, na.title, na.read_count;

COMMENT ON DATABASE ball_scout IS '球探社 - 足球资讯聚合平台数据库';
COMMENT ON TABLE users IS '用户表';
COMMENT ON TABLE teams IS '球队表';  
COMMENT ON TABLE news_articles IS '新闻文章表';
COMMENT ON TABLE matches IS '比赛表';
COMMENT ON TABLE comments IS '评论表';
COMMENT ON TABLE user_favorites IS '用户收藏表';
COMMENT ON TABLE reading_history IS '阅读历史表';

-- 完成提示
SELECT '✅ 球探社数据库初始化完成！' as message; 