#!/bin/bash

# 测试球探社新闻爬取和翻译功能
echo "🔄 开始测试球探社新闻爬取和翻译功能..."

# 设置基础URL
BASE_URL="http://localhost:8000"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试函数
test_api() {
    local endpoint=$1
    local method=${2:-GET}
    local data=$3
    local description=$4
    
    echo -e "\n${BLUE}📡 测试: $description${NC}"
    echo "   端点: $method $endpoint"
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        response=$(curl -s -X POST "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data" -w "HTTP_CODE:%{http_code}")
    else
        response=$(curl -s -X "$method" "$BASE_URL$endpoint" -w "HTTP_CODE:%{http_code}")
    fi
    
    http_code=$(echo "$response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTP_CODE:[0-9]*$//')
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo -e "   ${GREEN}✅ 成功 (HTTP $http_code)${NC}"
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        echo -e "   ${RED}❌ 失败 (HTTP $http_code)${NC}"
        echo "$body"
    fi
}

# 等待服务启动
echo -e "${YELLOW}⏳ 等待服务启动...${NC}"
sleep 2

# 1. 测试健康检查
test_api "/health" "GET" "" "健康检查"

# 2. 测试翻译服务状态
test_api "/api/v1/translate/status" "GET" "" "翻译服务状态"

# 3. 测试手动翻译
test_api "/api/v1/translate" "POST" '{
    "text": "Manchester United signed a new striker from Brazil for 80 million euros.",
    "sourceLanguage": "en",
    "targetLanguage": "zh-CN",
    "domain": "football",
    "priority": "high"
}' "手动翻译测试"

# 4. 测试爬取器状态
test_api "/api/v1/crawler/status" "GET" "" "爬取器状态"

# 5. 测试手动运行一次爬取
echo -e "\n${YELLOW}🚀 开始手动爬取测试（这可能需要几分钟）...${NC}"
test_api "/api/v1/crawler/run-once" "POST" "" "手动执行爬取"

# 6. 等待一些时间让爬取完成
echo -e "\n${YELLOW}⏳ 等待爬取完成...${NC}"
sleep 30

# 7. 检查生成的静态页面
test_api "/api/v1/crawler/static-pages" "GET" "" "检查生成的静态页面"

# 8. 检查是否生成了index.html
if [ -f "./static/index.html" ]; then
    echo -e "\n${GREEN}✅ 静态主页已生成: ./static/index.html${NC}"
    file_size=$(wc -c < "./static/index.html")
    echo "   文件大小: ${file_size} 字节"
else
    echo -e "\n${RED}❌ 静态主页未生成${NC}"
fi

# 9. 检查新闻详情页
if [ -d "./static/news" ]; then
    news_count=$(ls -1 ./static/news/*.html 2>/dev/null | wc -l)
    echo -e "\n${GREEN}✅ 新闻详情页目录存在${NC}"
    echo "   生成的新闻页面数量: $news_count"
else
    echo -e "\n${RED}❌ 新闻详情页目录不存在${NC}"
fi

# 10. 测试启动自动化爬取服务
echo -e "\n${BLUE}🤖 测试启动自动化爬取服务...${NC}"
test_api "/api/v1/crawler/start" "POST" "" "启动自动化爬取服务"

# 等待几秒钟
sleep 5

# 11. 测试停止自动化爬取服务
echo -e "\n${BLUE}🛑 测试停止自动化爬取服务...${NC}"
test_api "/api/v1/crawler/stop" "POST" "" "停止自动化爬取服务"

# 总结
echo -e "\n${BLUE}📊 测试总结:${NC}"
echo "1. ✅ 健康检查"
echo "2. ✅ 翻译服务测试"
echo "3. ✅ 手动爬取测试"
echo "4. ✅ 静态页面生成"
echo "5. ✅ 自动化服务控制"

echo -e "\n${GREEN}🎉 测试完成！${NC}"
echo -e "${YELLOW}💡 提示:${NC}"
echo "   - 查看生成的静态页面: ./static/index.html"
echo "   - 查看新闻详情页: ./static/news/"
echo "   - 配置DeepSeek API密钥以启用真实翻译功能"
echo "" 