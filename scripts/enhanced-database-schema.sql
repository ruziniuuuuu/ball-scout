-- 球探社数据库增强版本
-- 在基础数据库之上增加分析、翻译、实时功能等支持
-- PostgreSQL 数据库增强设置

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- 模糊搜索支持
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- GIN索引支持

-- ================================
-- 用户行为分析表
-- ================================
CREATE TABLE user_behaviors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('view', 'like', 'comment', 'share', 'search', 'click')),
    target_type VARCHAR(20) NOT NULL CHECK (target_type IN ('news', 'match', 'user', 'comment')),
    target_id UUID NOT NULL,
    timestamp TIMESTAMP DEFAULT NOW(),
    session_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    referrer VARCHAR(500),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- 用户行为分析索引
CREATE INDEX idx_user_behaviors_user_id ON user_behaviors(user_id);
CREATE INDEX idx_user_behaviors_action ON user_behaviors(action);
CREATE INDEX idx_user_behaviors_target_type_id ON user_behaviors(target_type, target_id);
CREATE INDEX idx_user_behaviors_timestamp ON user_behaviors(timestamp DESC);
CREATE INDEX idx_user_behaviors_session_id ON user_behaviors(session_id);

-- ================================
-- 翻译缓存表
-- ================================
CREATE TABLE translation_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_text TEXT NOT NULL,
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    translated_text TEXT NOT NULL,
    provider VARCHAR(50) NOT NULL, -- deepseek, claude, openai
    model VARCHAR(100) NOT NULL,
    confidence DECIMAL(3,2) DEFAULT 0.85,
    quality_score DECIMAL(3,2) DEFAULT 0.85,
    cache_hit_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP DEFAULT (NOW() + INTERVAL '30 days'),
    
    -- 唯一约束确保相同内容不重复缓存
    UNIQUE(source_text, source_language, target_language)
);

-- 翻译缓存索引
CREATE INDEX idx_translation_cache_lookup ON translation_cache(source_text, source_language, target_language);
CREATE INDEX idx_translation_cache_expires_at ON translation_cache(expires_at);
CREATE INDEX idx_translation_cache_provider ON translation_cache(provider);
CREATE INDEX idx_translation_cache_created_at ON translation_cache(created_at DESC);

-- ================================
-- 新闻来源配置表
-- ================================
CREATE TABLE news_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    base_url VARCHAR(500) NOT NULL,
    rss_feed VARCHAR(500),
    api_endpoint VARCHAR(500),
    country VARCHAR(50),
    language VARCHAR(10) DEFAULT 'en',
    category VARCHAR(50), -- sports, football, general
    reliability_score INTEGER DEFAULT 7 CHECK (reliability_score BETWEEN 1 AND 10),
    crawl_frequency INTEGER DEFAULT 3600, -- 秒
    is_active BOOLEAN DEFAULT TRUE,
    last_crawled_at TIMESTAMP,
    crawl_config JSONB DEFAULT '{}',
    rate_limit JSONB DEFAULT '{"requests_per_hour": 100}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(name)
);

-- 新闻来源索引
CREATE INDEX idx_news_sources_active ON news_sources(is_active);
CREATE INDEX idx_news_sources_country ON news_sources(country);
CREATE INDEX idx_news_sources_last_crawled ON news_sources(last_crawled_at);

-- ================================
-- 内容标签系统
-- ================================
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL,
    name_zh VARCHAR(50),
    category VARCHAR(30) DEFAULT 'general',
    color VARCHAR(7) DEFAULT '#3B82F6', -- 十六进制颜色
    usage_count INTEGER DEFAULT 0,
    is_trending BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(name)
);

-- 文章标签关联表
CREATE TABLE article_tags (
    article_id UUID REFERENCES news_articles(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    relevance_score DECIMAL(3,2) DEFAULT 0.50,
    created_at TIMESTAMP DEFAULT NOW(),
    
    PRIMARY KEY(article_id, tag_id)
);

-- 标签索引
CREATE INDEX idx_tags_category ON tags(category);
CREATE INDEX idx_tags_trending ON tags(is_trending);
CREATE INDEX idx_tags_usage_count ON tags(usage_count DESC);
CREATE INDEX idx_article_tags_relevance ON article_tags(relevance_score DESC);

-- ================================
-- 用户通知系统
-- ================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    type VARCHAR(30) NOT NULL CHECK (type IN ('news', 'match', 'system', 'social', 'achievement')),
    action_url VARCHAR(500),
    is_read BOOLEAN DEFAULT FALSE,
    priority VARCHAR(10) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    metadata JSONB DEFAULT '{}',
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 通知索引
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);
CREATE INDEX idx_notifications_type ON notifications(type);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX idx_notifications_expires_at ON notifications(expires_at);

-- ================================
-- 用户关注系统
-- ================================
CREATE TABLE user_follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
    following_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- 球队关注表
CREATE TABLE team_follows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    notification_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, team_id)
);

-- 关注系统索引
CREATE INDEX idx_user_follows_follower_id ON user_follows(follower_id);
CREATE INDEX idx_user_follows_following_id ON user_follows(following_id);
CREATE INDEX idx_team_follows_user_id ON team_follows(user_id);
CREATE INDEX idx_team_follows_team_id ON team_follows(team_id);

-- ================================
-- API访问统计表
-- ================================
CREATE TABLE api_access_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    endpoint VARCHAR(200) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INTEGER NOT NULL,
    response_time INTEGER, -- 毫秒
    ip_address INET,
    user_agent TEXT,
    request_size INTEGER,
    response_size INTEGER,
    error_message TEXT,
    timestamp TIMESTAMP DEFAULT NOW()
);

-- API访问日志索引
CREATE INDEX idx_api_access_logs_timestamp ON api_access_logs(timestamp DESC);
CREATE INDEX idx_api_access_logs_endpoint ON api_access_logs(endpoint);
CREATE INDEX idx_api_access_logs_status_code ON api_access_logs(status_code);
CREATE INDEX idx_api_access_logs_user_id ON api_access_logs(user_id);

-- ================================
-- 系统配置表
-- ================================
CREATE TABLE system_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value TEXT,
    description TEXT,
    config_type VARCHAR(20) DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'json')),
    is_public BOOLEAN DEFAULT FALSE,
    category VARCHAR(50) DEFAULT 'general',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 系统配置索引
CREATE INDEX idx_system_config_category ON system_config(category);
CREATE INDEX idx_system_config_is_public ON system_config(is_public);

-- ================================
-- 内容搜索表（全文搜索优化）
-- ================================
CREATE TABLE search_index (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('news', 'team', 'player')),
    content_id UUID NOT NULL,
    title TEXT NOT NULL,
    content TEXT,
    keywords TEXT[],
    search_vector tsvector,
    language VARCHAR(10) DEFAULT 'english',
    boost_score DECIMAL(3,2) DEFAULT 1.0,
    last_indexed_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(content_type, content_id)
);

-- 搜索索引
CREATE INDEX idx_search_index_content_type ON search_index(content_type);
CREATE INDEX idx_search_index_content_id ON search_index(content_id);
CREATE INDEX idx_search_index_search_vector ON search_index USING GIN(search_vector);
CREATE INDEX idx_search_index_keywords ON search_index USING GIN(keywords);

-- ================================
-- 实时事件表
-- ================================
CREATE TABLE live_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE,
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN ('goal', 'card', 'substitution', 'penalty', 'var', 'injury')),
    minute INTEGER,
    player_name VARCHAR(100),
    team_side VARCHAR(10) CHECK (team_side IN ('home', 'away')),
    description TEXT,
    metadata JSONB DEFAULT '{}',
    is_key_event BOOLEAN DEFAULT FALSE,
    timestamp TIMESTAMP DEFAULT NOW()
);

-- 实时事件索引
CREATE INDEX idx_live_events_match_id ON live_events(match_id);
CREATE INDEX idx_live_events_event_type ON live_events(event_type);
CREATE INDEX idx_live_events_timestamp ON live_events(timestamp DESC);
CREATE INDEX idx_live_events_is_key ON live_events(is_key_event);

-- ================================
-- 用户会话表
-- ================================
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    refresh_token VARCHAR(255) NOT NULL UNIQUE,
    device_info JSONB DEFAULT '{}',
    ip_address INET,
    last_activity TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CHECK (expires_at > created_at)
);

-- 会话索引
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_session_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_last_activity ON user_sessions(last_activity);

-- ================================
-- 增强的触发器和函数
-- ================================

-- 更新updated_at触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为新表添加updated_at触发器
CREATE TRIGGER update_news_sources_updated_at BEFORE UPDATE ON news_sources FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON system_config FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 自动清理过期数据函数
CREATE OR REPLACE FUNCTION cleanup_expired_data()
RETURNS void AS $$
BEGIN
    -- 清理过期的翻译缓存
    DELETE FROM translation_cache WHERE expires_at < NOW();
    
    -- 清理过期的通知
    DELETE FROM notifications WHERE expires_at IS NOT NULL AND expires_at < NOW();
    
    -- 清理过期的用户会话
    DELETE FROM user_sessions WHERE expires_at < NOW();
    
    -- 清理旧的API访问日志（保留30天）
    DELETE FROM api_access_logs WHERE timestamp < NOW() - INTERVAL '30 days';
    
    -- 清理旧的用户行为日志（保留90天）
    DELETE FROM user_behaviors WHERE timestamp < NOW() - INTERVAL '90 days';
    
    RAISE NOTICE '过期数据清理完成';
END;
$$ LANGUAGE plpgsql;

-- 更新搜索索引函数
CREATE OR REPLACE FUNCTION update_search_index_for_article()
RETURNS TRIGGER AS $$
BEGIN
    -- 删除旧索引
    DELETE FROM search_index WHERE content_type = 'news' AND content_id = NEW.id;
    
    -- 插入新索引
    INSERT INTO search_index (content_type, content_id, title, content, search_vector)
    VALUES (
        'news',
        NEW.id,
        NEW.title,
        COALESCE(NEW.content, NEW.summary, ''),
        to_tsvector('english', NEW.title || ' ' || COALESCE(NEW.content, NEW.summary, ''))
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为新闻文章自动更新搜索索引
CREATE TRIGGER trigger_update_search_index_article
    AFTER INSERT OR UPDATE ON news_articles
    FOR EACH ROW EXECUTE FUNCTION update_search_index_for_article();

-- 标签使用量自动更新函数
CREATE OR REPLACE FUNCTION update_tag_usage_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE tags SET usage_count = usage_count + 1 WHERE id = NEW.tag_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE tags SET usage_count = GREATEST(usage_count - 1, 0) WHERE id = OLD.tag_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 标签使用量触发器
CREATE TRIGGER trigger_update_tag_usage
    AFTER INSERT OR DELETE ON article_tags
    FOR EACH ROW EXECUTE FUNCTION update_tag_usage_count();

-- ================================
-- 增强的视图
-- ================================

-- 用户统计视图
CREATE VIEW user_stats AS
SELECT 
    u.id,
    u.username,
    u.created_at,
    COUNT(DISTINCT ub.id) as total_actions,
    COUNT(DISTINCT c.id) as comment_count,
    COUNT(DISTINCT uf.id) as favorite_count,
    COUNT(DISTINCT tf.id) as following_teams_count,
    COUNT(DISTINCT followers.id) as follower_count,
    COUNT(DISTINCT following.id) as following_count
FROM users u
LEFT JOIN user_behaviors ub ON u.id = ub.user_id
LEFT JOIN comments c ON u.id = c.user_id AND c.is_deleted = FALSE
LEFT JOIN user_favorites uf ON u.id = uf.user_id
LEFT JOIN team_follows tf ON u.id = tf.user_id
LEFT JOIN user_follows followers ON u.id = followers.following_id
LEFT JOIN user_follows following ON u.id = following.follower_id
GROUP BY u.id, u.username, u.created_at;

-- 热门内容视图
CREATE VIEW trending_content AS
SELECT 
    na.id,
    na.title,
    na.category,
    na.published_at,
    na.read_count,
    COUNT(DISTINCT c.id) as comment_count,
    COUNT(DISTINCT uf.id) as favorite_count,
    COUNT(DISTINCT ub.id) as recent_views,
    -- 计算热度分数
    (
        na.read_count * 0.3 + 
        COUNT(DISTINCT c.id) * 2 + 
        COUNT(DISTINCT uf.id) * 3 + 
        COUNT(DISTINCT ub.id) * 1 +
        (EXTRACT(EPOCH FROM NOW() - na.published_at) / 3600) * -0.1  -- 时间衰减
    ) as trending_score
FROM news_articles na
LEFT JOIN comments c ON na.id = c.article_id AND c.is_deleted = FALSE
LEFT JOIN user_favorites uf ON na.id = uf.article_id
LEFT JOIN user_behaviors ub ON na.id::text = ub.target_id::text 
    AND ub.target_type = 'news' 
    AND ub.action = 'view'
    AND ub.timestamp > NOW() - INTERVAL '24 hours'
WHERE na.published_at > NOW() - INTERVAL '7 days'
GROUP BY na.id, na.title, na.category, na.published_at, na.read_count
ORDER BY trending_score DESC;

-- 系统健康状态视图
CREATE VIEW system_health AS
SELECT 
    'articles' as metric,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as daily_count,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as weekly_count
FROM news_articles
UNION ALL
SELECT 
    'users' as metric,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as daily_count,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as weekly_count
FROM users
UNION ALL
SELECT 
    'comments' as metric,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as daily_count,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as weekly_count
FROM comments
UNION ALL
SELECT 
    'behaviors' as metric,
    COUNT(*) as total_count,
    COUNT(*) FILTER (WHERE timestamp > NOW() - INTERVAL '24 hours') as daily_count,
    COUNT(*) FILTER (WHERE timestamp > NOW() - INTERVAL '7 days') as weekly_count
FROM user_behaviors;

-- ================================
-- 初始数据插入
-- ================================

-- 插入系统配置
INSERT INTO system_config (config_key, config_value, description, config_type, category) VALUES
('site_name', '球探社', '网站名称', 'string', 'general'),
('max_articles_per_page', '20', '每页最大文章数', 'number', 'pagination'),
('enable_registration', 'true', '是否允许新用户注册', 'boolean', 'user'),
('translation_cache_ttl', '2592000', '翻译缓存TTL（秒）', 'number', 'translation'),
('max_comment_depth', '3', '评论最大嵌套层数', 'number', 'comment'),
('enable_real_time', 'true', '是否启用实时功能', 'boolean', 'feature');

-- 插入新闻来源
INSERT INTO news_sources (name, base_url, country, language, reliability_score) VALUES
('BBC Sport', 'https://www.bbc.com/sport', 'UK', 'en', 9),
('ESPN FC', 'https://www.espn.com/soccer/', 'US', 'en', 8),
('Goal.com', 'https://www.goal.com', 'Global', 'en', 7),
('Sky Sports', 'https://www.skysports.com', 'UK', 'en', 8),
('Marca', 'https://www.marca.com', 'Spain', 'es', 8),
('L\'Équipe', 'https://www.lequipe.fr', 'France', 'fr', 8);

-- 插入基础标签
INSERT INTO tags (name, name_zh, category, color) VALUES
('transfer', '转会', 'news', '#10B981'),
('match', '比赛', 'sports', '#3B82F6'),
('injury', '伤病', 'news', '#EF4444'),
('goal', '进球', 'sports', '#F59E0B'),
('premier-league', '英超', 'league', '#6366F1'),
('la-liga', '西甲', 'league', '#EC4899'),
('champions-league', '欧冠', 'competition', '#8B5CF6'),
('world-cup', '世界杯', 'competition', '#F97316');

-- ================================
-- 数据库维护任务
-- ================================

-- 创建定期清理任务（需要pg_cron扩展）
-- SELECT cron.schedule('cleanup-expired-data', '0 2 * * *', 'SELECT cleanup_expired_data();');

-- 创建数据库性能分析视图
CREATE VIEW database_performance AS
SELECT 
    schemaname,
    tablename,
    attname as column_name,
    n_distinct,
    correlation,
    most_common_vals[1:5] as top_values
FROM pg_stats 
WHERE schemaname = 'public'
ORDER BY schemaname, tablename, attname;

-- ================================
-- 数据库约束和规则
-- ================================

-- 确保用户行为记录的完整性
ALTER TABLE user_behaviors ADD CONSTRAINT check_valid_target_id 
CHECK (target_id IS NOT NULL);

-- 确保翻译缓存的质量分数合理
ALTER TABLE translation_cache ADD CONSTRAINT check_valid_quality_score 
CHECK (quality_score >= 0.0 AND quality_score <= 1.0);

-- 确保通知优先级有效
ALTER TABLE notifications ADD CONSTRAINT check_valid_priority 
CHECK (priority IN ('low', 'normal', 'high', 'urgent'));

-- ================================
-- 完成消息
-- ================================
SELECT '✅ 球探社数据库增强版初始化完成！' as message,
       '🚀 新增功能：用户行为分析、翻译缓存、实时事件、通知系统、搜索优化' as features;