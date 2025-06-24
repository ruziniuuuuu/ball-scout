#!/bin/bash

# 球探社 API 快速测试脚本
echo "🏆 球探社 API v1.5 测试"
echo "=========================="

BASE_URL="http://localhost:8000"
CURL_OPTS="--silent --noproxy localhost"

# 健康检查
echo "1. 📊 健康检查"
curl $CURL_OPTS "$BASE_URL/health" | jq '.data.status, .data.services'
echo ""

# API文档
echo "2. 📖 API文档"
curl $CURL_OPTS "$BASE_URL/api" | jq '.data.title, .data.version'
echo ""

# 新闻列表
echo "3. 📰 新闻列表（前3条）"
curl $CURL_OPTS "$BASE_URL/api/v1/news" | jq '.data[:3] | .[] | {title, source, category}'
echo ""

# 翻译服务状态
echo "4. 🤖 翻译服务状态"
curl $CURL_OPTS "$BASE_URL/api/v1/translate/status" | jq '.data.totalProviders, .data.fallbackChain'
echo ""

# 评论列表
echo "5. 💬 评论列表"
curl $CURL_OPTS "$BASE_URL/api/v1/comments?articleId=1" | jq '.meta.total'
echo ""

echo "✅ 所有主要API端点测试完成！"
echo ""
echo "🌐 访问地址："
echo "   前端: http://localhost:3000"
echo "   后端: http://localhost:8000"
echo "   API文档: http://localhost:8000/api" 