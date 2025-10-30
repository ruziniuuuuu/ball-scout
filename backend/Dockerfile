# 速达足球后端 Dockerfile
# 基于 Deno 官方镜像

FROM denoland/deno:1.44.0

# 设置工作目录
WORKDIR /app

# 复制依赖文件
COPY deps.ts .
COPY deno.json .

# 缓存依赖
RUN deno cache deps.ts

# 复制源代码
COPY . .

# 缓存应用代码
RUN deno cache mod.ts

# 创建日志目录
RUN mkdir -p logs

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD deno run --allow-net https://deno.land/std@0.208.0/http/http_status.ts || exit 1

# 启动命令
CMD ["run", "--allow-net", "--allow-read", "--allow-env", "mod.ts"] 