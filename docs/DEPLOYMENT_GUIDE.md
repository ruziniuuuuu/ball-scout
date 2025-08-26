# 球探社部署指南

## 部署架构概述

球探社采用现代化的微服务架构，支持多种部署方式：

- **开发环境**: Docker Compose + 本地开发服务器
- **测试环境**: Kubernetes + CI/CD 自动部署
- **生产环境**: 云服务 + CDN + 负载均衡

## 环境要求

### 服务器要求

- **CPU**: 最小2核，推荐4核
- **内存**: 最小4GB，推荐8GB
- **存储**: 最小50GB SSD
- **网络**: 稳定的互联网连接

### 软件要求

- Docker 20.10+
- Docker Compose 2.0+
- Node.js 18+ (用于构建工具)
- Git

## Docker部署

### 1. 准备环境文件

创建生产环境配置文件：

```bash
# 复制环境配置模板
cp backend/config.example.env backend/.env.production

# 编辑配置文件
nano backend/.env.production
```

配置示例：
```env
# 数据库配置
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=ball_scout
DATABASE_USER=postgres
DATABASE_PASSWORD=your_secure_password

# Redis配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# JWT密钥
JWT_SECRET=your_very_secure_jwt_secret_here

# AI服务API密钥
DEEPSEEK_API_KEY=your_deepseek_api_key
CLAUDE_API_KEY=your_claude_api_key
OPENAI_API_KEY=your_openai_api_key

# 应用配置
NODE_ENV=production
PORT=8000
CORS_ORIGIN=https://your-domain.com
```

### 2. 构建和启动服务

```bash
# 构建所有服务
make docker-build

# 启动生产环境
docker-compose -f docker-compose.prod.yml up -d

# 检查服务状态
docker-compose -f docker-compose.prod.yml ps
```

### 3. 初始化数据库

```bash
# 执行数据库迁移
docker-compose -f docker-compose.prod.yml exec backend deno run --allow-all scripts/migrate.ts

# 导入初始数据（可选）
docker-compose -f docker-compose.prod.yml exec backend deno run --allow-all scripts/seed.ts
```

## Kubernetes部署

### 1. 准备Kubernetes清单文件

创建命名空间：
```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ball-scout
```

配置ConfigMap：
```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ball-scout-config
  namespace: ball-scout
data:
  NODE_ENV: "production"
  PORT: "8000"
  DATABASE_HOST: "postgres-service"
  REDIS_HOST: "redis-service"
```

配置Secret：
```yaml
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ball-scout-secrets
  namespace: ball-scout
type: Opaque
data:
  database-password: <base64-encoded-password>
  jwt-secret: <base64-encoded-jwt-secret>
  deepseek-api-key: <base64-encoded-api-key>
```

### 2. 部署应用服务

后端服务部署：
```yaml
# k8s/backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ball-scout-backend
  namespace: ball-scout
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ball-scout-backend
  template:
    metadata:
      labels:
        app: ball-scout-backend
    spec:
      containers:
      - name: backend
        image: ball-scout-backend:latest
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: ball-scout-config
        - secretRef:
            name: ball-scout-secrets
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

前端服务部署：
```yaml
# k8s/frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ball-scout-frontend
  namespace: ball-scout
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ball-scout-frontend
  template:
    metadata:
      labels:
        app: ball-scout-frontend
    spec:
      containers:
      - name: frontend
        image: ball-scout-frontend:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

### 3. 配置服务和Ingress

```yaml
# k8s/services.yaml
apiVersion: v1
kind: Service
metadata:
  name: ball-scout-backend-service
  namespace: ball-scout
spec:
  selector:
    app: ball-scout-backend
  ports:
  - port: 8000
    targetPort: 8000
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: ball-scout-frontend-service
  namespace: ball-scout
spec:
  selector:
    app: ball-scout-frontend
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ball-scout-ingress
  namespace: ball-scout
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - ball-scout.app
    - api.ball-scout.app
    secretName: ball-scout-tls
  rules:
  - host: ball-scout.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ball-scout-frontend-service
            port:
              number: 80
  - host: api.ball-scout.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ball-scout-backend-service
            port:
              number: 8000
```

### 4. 部署到Kubernetes

```bash
# 应用所有配置
kubectl apply -f k8s/

# 检查部署状态
kubectl get pods -n ball-scout
kubectl get services -n ball-scout
kubectl get ingress -n ball-scout

# 查看日志
kubectl logs -n ball-scout -l app=ball-scout-backend
```

## 云服务部署

### AWS ECS部署

1. **创建ECR仓库**
```bash
aws ecr create-repository --repository-name ball-scout-backend
aws ecr create-repository --repository-name ball-scout-frontend
```

2. **构建并推送镜像**
```bash
# 获取登录token
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-west-2.amazonaws.com

# 构建镜像
docker build -t ball-scout-backend backend/
docker build -t ball-scout-frontend .

# 打标签
docker tag ball-scout-backend:latest 123456789012.dkr.ecr.us-west-2.amazonaws.com/ball-scout-backend:latest
docker tag ball-scout-frontend:latest 123456789012.dkr.ecr.us-west-2.amazonaws.com/ball-scout-frontend:latest

# 推送镜像
docker push 123456789012.dkr.ecr.us-west-2.amazonaws.com/ball-scout-backend:latest
docker push 123456789012.dkr.ecr.us-west-2.amazonaws.com/ball-scout-frontend:latest
```

3. **创建ECS任务定义和服务**
```json
{
  "family": "ball-scout-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "ball-scout-backend",
      "image": "123456789012.dkr.ecr.us-west-2.amazonaws.com/ball-scout-backend:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-west-2:123456789012:secret:ball-scout/database:password::"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/ball-scout-backend",
          "awslogs-region": "us-west-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

## 监控和日志

### 1. 设置监控

使用Prometheus + Grafana监控应用：

```yaml
# monitoring/prometheus-config.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'ball-scout-backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'
    
  - job_name: 'ball-scout-frontend'
    static_configs:
      - targets: ['frontend:80']
```

### 2. 日志聚合

使用ELK Stack聚合日志：

```yaml
# logging/filebeat.yml
filebeat.inputs:
- type: docker
  containers.ids:
  - "*"
  processors:
  - add_docker_metadata: ~

output.elasticsearch:
  hosts: ["elasticsearch:9200"]

setup.kibana:
  host: "kibana:5601"
```

### 3. 健康检查

应用内健康检查端点：

```typescript
// backend/src/health.ts
export async function healthCheck(): Promise<HealthStatus> {
  const checks = await Promise.allSettled([
    checkDatabase(),
    checkRedis(),
    checkExternalAPIs(),
  ]);

  return {
    status: checks.every(check => check.status === 'fulfilled') ? 'healthy' : 'unhealthy',
    timestamp: new Date().toISOString(),
    services: {
      database: checks[0].status === 'fulfilled' ? 'up' : 'down',
      redis: checks[1].status === 'fulfilled' ? 'up' : 'down',
      externalAPIs: checks[2].status === 'fulfilled' ? 'up' : 'down',
    },
    version: '1.5.0',
  };
}
```

## SSL证书配置

### 使用Let's Encrypt

```bash
# 安装certbot
sudo apt-get install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d ball-scout.app -d api.ball-scout.app

# 设置自动续期
sudo crontab -e
# 添加: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Nginx配置

```nginx
# /etc/nginx/sites-available/ball-scout
server {
    listen 80;
    server_name ball-scout.app;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ball-scout.app;
    
    ssl_certificate /etc/letsencrypt/live/ball-scout.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ball-scout.app/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 443 ssl http2;
    server_name api.ball-scout.app;
    
    ssl_certificate /etc/letsencrypt/live/ball-scout.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ball-scout.app/privkey.pem;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # API特定配置
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
}
```

## 备份和恢复

### 数据库备份

```bash
# 创建备份脚本
#!/bin/bash
# scripts/backup-db.sh

BACKUP_DIR="/backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="ball_scout_backup_${DATE}.sql"

mkdir -p $BACKUP_DIR

docker-compose exec postgres pg_dump -U postgres ball_scout > "${BACKUP_DIR}/${BACKUP_FILE}"

# 压缩备份文件
gzip "${BACKUP_DIR}/${BACKUP_FILE}"

# 删除7天前的备份
find $BACKUP_DIR -name "*.sql.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
```

### 数据恢复

```bash
# 恢复数据库
#!/bin/bash
# scripts/restore-db.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.sql.gz>"
    exit 1
fi

# 解压备份文件
gunzip -c $BACKUP_FILE > /tmp/restore.sql

# 停止应用服务
docker-compose stop backend frontend

# 恢复数据库
docker-compose exec postgres psql -U postgres -d ball_scout < /tmp/restore.sql

# 重启服务
docker-compose start backend frontend

echo "Database restore completed"
```

## 性能优化

### 1. 数据库优化

```sql
-- 创建索引
CREATE INDEX idx_news_published_at ON news_articles(published_at);
CREATE INDEX idx_news_category ON news_articles(category);
CREATE INDEX idx_comments_news_id ON comments(news_id);

-- 配置连接池
-- postgresql.conf
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
```

### 2. Redis缓存配置

```redis
# redis.conf
maxmemory 512mb
maxmemory-policy allkeys-lru
timeout 300
save 900 1
save 300 10
save 60 10000
```

### 3. 应用层优化

```typescript
// 连接池配置
const dbConfig = {
  host: 'localhost',
  port: 5432,
  database: 'ball_scout',
  user: 'postgres',
  password: 'password',
  max: 20, // 最大连接数
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
};
```

## 故障排除

### 常见问题

1. **数据库连接失败**
```bash
# 检查数据库状态
docker-compose logs postgres

# 测试连接
docker-compose exec postgres psql -U postgres -d ball_scout -c "\l"
```

2. **内存不足**
```bash
# 检查内存使用
docker stats

# 增加swap空间
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

3. **SSL证书问题**
```bash
# 检查证书有效期
sudo certbot certificates

# 手动续期
sudo certbot renew --force-renewal
```

### 日志查看

```bash
# 应用日志
docker-compose logs -f backend
docker-compose logs -f frontend

# 系统日志
sudo journalctl -u docker
sudo tail -f /var/log/nginx/error.log
```

## 扩展部署

### 水平扩展

```yaml
# docker-compose.scale.yml
version: '3.8'
services:
  backend:
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.50'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
```

### 负载均衡

```nginx
# nginx.conf
upstream backend_pool {
    server backend1:8000;
    server backend2:8000;
    server backend3:8000;
}

server {
    location /api {
        proxy_pass http://backend_pool;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

通过遵循这个部署指南，可以确保球探社应用在各种环境中稳定运行。记住定期更新依赖、监控系统状态，并保持良好的备份策略。