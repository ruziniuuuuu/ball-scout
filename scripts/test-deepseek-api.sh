#!/bin/bash

# 球探社 - DeepSeek API测试脚本
# 用于验证DeepSeek翻译服务的配置和功能

echo "🤖 球探社 - DeepSeek API测试"
echo "================================"

# 检查环境变量
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "❌ 错误: 未设置 DEEPSEEK_API_KEY 环境变量"
    echo "💡 请先设置: export DEEPSEEK_API_KEY='your-api-key'"
    exit 1
fi

echo "✅ DEEPSEEK_API_KEY 已设置"

# 测试DeepSeek API连接
echo ""
echo "📡 测试DeepSeek API连接..."

curl -X POST "https://api.deepseek.com/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {
        "role": "system",
        "content": "你是一位专业的足球新闻翻译专家。"
      },
      {
        "role": "user", 
        "content": "请将以下英文足球新闻翻译成中文：Lionel Messi scored a spectacular goal in the Champions League match against Real Madrid."
      }
    ],
    "temperature": 0.1,
    "max_tokens": 200
  }' \
  --silent \
  --write-out "\n HTTP状态码: %{http_code}\n" \
  | jq '.'

echo ""
echo "🧪 如果看到翻译结果，说明DeepSeek API配置成功！"
echo ""
echo "📋 接下来的步骤："
echo "1. 在 backend/.env 文件中添加: DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY"
echo "2. 重启后端服务: cd backend && deno task dev"
echo "3. 访问翻译状态: curl http://localhost:8000/api/v1/translate/status"

# 测试后端翻译服务 (如果后端正在运行)
echo ""
echo "🔧 测试后端翻译服务..."

if curl --output /dev/null --silent --head --fail "http://localhost:8000/health"; then
    echo "✅ 后端服务运行中，测试翻译接口..."
    
    curl -X POST "http://localhost:8000/api/v1/translate" \
      -H "Content-Type: application/json" \
      -d '{
        "text": "Lionel Messi scored a hat-trick in the Champions League final.",
        "sourceLanguage": "en",
        "targetLanguage": "zh-CN",
        "domain": "football",
        "priority": "high"
      }' \
      --silent | jq '.'
else
    echo "⚠️ 后端服务未运行，跳过接口测试"
    echo "💡 启动后端: cd backend && deno task dev"
fi

echo ""
echo "�� DeepSeek API测试完成！" 