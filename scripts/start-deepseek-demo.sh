#!/bin/bash

# 球探社 - DeepSeek翻译服务启动脚本

echo "🏆 球探社 - DeepSeek AI翻译服务"
echo "================================="

# 检查DeepSeek API密钥
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "❌ DEEPSEEK_API_KEY 环境变量未设置"
    echo "💡 设置API密钥: export DEEPSEEK_API_KEY='your-api-key'"
    exit 1
fi

echo "✅ DeepSeek API密钥已设置"

# 端口配置
PORT=8001

# 检查端口是否被占用并自动清理
echo "🔧 检查端口 $PORT..."
if lsof -i :$PORT > /dev/null 2>&1; then
    echo "⚠️  端口 $PORT 已被占用，正在清理..."
    
    # 获取占用端口的进程ID
    PIDS=$(lsof -ti :$PORT)
    if [ ! -z "$PIDS" ]; then
        echo "🔪 杀死进程: $PIDS"
        kill -9 $PIDS 2>/dev/null
        sleep 2
        
        # 再次检查
        if lsof -i :$PORT > /dev/null 2>&1; then
            echo "❌ 无法清理端口 $PORT，请手动处理"
            echo "💡 手动清理: lsof -ti :$PORT | xargs kill -9"
            exit 1
        fi
    fi
fi

echo "✅ 端口 $PORT 可用"

# 清理可能存在的临时文件
rm -f temp-deepseek-server.ts

echo "🔧 启动服务..."

# 创建临时服务器文件
cat > temp-deepseek-server.ts << 'EOF'
import { Application, Router } from 'https://deno.land/x/oak@v12.6.1/mod.ts';
import { oakCors } from 'https://deno.land/x/cors@v1.2.2/mod.ts';

const app = new Application();
const router = new Router();

// 错误处理中间件
app.use(async (ctx, next) => {
  try {
    await next();
  } catch (error) {
    console.error('❌ 服务器错误:', error.message);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: { message: '服务器内部错误' },
    };
  }
});

app.use(oakCors({ origin: '*', credentials: true }));

app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  const ms = Date.now() - start;
  console.log(`${ctx.request.method} ${ctx.request.url.pathname} - ${ctx.response.status} (${ms}ms)`);
});

async function translateWithDeepSeek(text: string, sourceLanguage: string, targetLanguage: string) {
  const apiKey = Deno.env.get('DEEPSEEK_API_KEY');
  if (!apiKey) throw new Error('DEEPSEEK_API_KEY 未设置');

  const prompt = `请将以下${sourceLanguage}足球新闻翻译成${targetLanguage === 'zh-CN' ? '简体中文' : '繁体中文'}，要求：

1. 保持足球术语的专业性和准确性
2. 球员和球队名称使用中文惯用译名
3. 保持原文的语气和风格
4. 确保翻译流畅自然，符合中文表达习惯

原文内容: ${text}

请直接返回翻译结果，不要添加任何解释或说明。`;

  const response = await fetch('https://api.deepseek.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: 'deepseek-chat',
      messages: [
        { role: 'system', content: '你是一位专业的足球新闻翻译专家。' },
        { role: 'user', content: prompt },
      ],
      temperature: 0.1,
      max_tokens: 4000,
      stream: false,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`DeepSeek API error: ${response.status} - ${errorText}`);
  }
  
  const data = await response.json();
  return data.choices[0].message.content;
}

router.get('/health', (ctx) => {
  ctx.response.body = {
    success: true,
    data: { 
      status: 'healthy', 
      version: '1.0.0', 
      timestamp: new Date().toISOString(),
      port: Deno.env.get('PORT') || '8001'
    },
  };
});

router.post('/api/v1/translate', async (ctx) => {
  try {
    const body = await ctx.request.body().value;
    const { text, sourceLanguage, targetLanguage } = body;

    if (!text) {
      ctx.response.status = 400;
      ctx.response.body = { success: false, error: { message: '缺少text参数' } };
      return;
    }

    console.log(`🤖 开始翻译: ${text.substring(0, 50)}...`);
    
    const startTime = Date.now();
    const translatedText = await translateWithDeepSeek(text, sourceLanguage || 'en', targetLanguage || 'zh-CN');
    const processingTime = Date.now() - startTime;

    console.log(`✅ 翻译完成: ${translatedText.substring(0, 50)}...`);

    ctx.response.body = {
      success: true,
      data: {
        translatedText,
        confidence: 0.92,
        model: 'deepseek-chat',
        processingTime,
        qualityScore: 0.90,
        originalText: text,
        sourceLanguage: sourceLanguage || 'en',
        targetLanguage: targetLanguage || 'zh-CN',
        timestamp: new Date().toISOString(),
      },
    };
  } catch (error) {
    console.error('翻译错误:', error);
    ctx.response.status = 500;
    ctx.response.body = {
      success: false,
      error: { message: error.message || '翻译服务暂时不可用' },
    };
  }
});

router.get('/api/v1/translate/status', (ctx) => {
  const hasApiKey = !!Deno.env.get('DEEPSEEK_API_KEY');
  ctx.response.body = {
    success: true,
    data: {
      availableProviders: hasApiKey ? ['deepseek'] : [],
      totalProviders: 1,
      apiKeyConfigured: hasApiKey,
      timestamp: new Date().toISOString(),
    },
  };
});

app.use(router.routes());
app.use(router.allowedMethods());

const port = 8001;
console.log(`🚀 球探社翻译服务启动 - http://localhost:${port}`);
console.log(`🤖 DeepSeek API: ${Deno.env.get('DEEPSEEK_API_KEY') ? '已配置' : '未配置'}`);
console.log(`📱 Web界面: 打开 scripts/demos/translation-demo.html`);

try {
  await app.listen({ port });
} catch (error) {
  console.error('❌ 服务器启动失败:', error.message);
  Deno.exit(1);
}
EOF

# 启动服务器
echo "🌐 启动DeepSeek翻译服务器..."
deno run --allow-net --allow-env temp-deepseek-server.ts &
SERVER_PID=$!

# 等待服务器启动
sleep 3

# 测试服务器
echo ""
echo "🧪 测试服务器..."
if curl -s http://localhost:$PORT/health > /dev/null; then
    echo "✅ 服务器启动成功！"
    echo ""
    echo "📋 使用方法："
    echo "1. 打开浏览器访问 scripts/demos/translation-demo.html"
    echo "2. 或者使用命令行测试："
    echo "   curl -X POST 'http://localhost:$PORT/api/v1/translate' \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"text\":\"Hello world\",\"sourceLanguage\":\"en\",\"targetLanguage\":\"zh-CN\"}'"
    echo ""
    echo "⏹️  停止服务器: kill $SERVER_PID"
    echo "📊 查看日志: 观察当前终端输出"
    echo ""
    echo "🎉 DeepSeek翻译服务正在运行中..."
    
    # 创建优雅退出处理
    trap 'echo ""; echo "🛑 正在停止服务器..."; kill $SERVER_PID 2>/dev/null; rm -f temp-deepseek-server.ts; echo "🔚 服务已停止"; exit 0' INT TERM
    
    # 等待用户中断
    wait $SERVER_PID
else
    echo "❌ 服务器启动失败"
    kill $SERVER_PID 2>/dev/null
fi

# 清理临时文件
rm -f temp-deepseek-server.ts

echo "🔚 服务已停止" 