#!/bin/bash

# 球探社生产环境部署脚本
# 自动化部署、健康检查、回滚等功能

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_DIR}/.env.production"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.production.yml"
BACKUP_DIR="${PROJECT_DIR}/backups"
LOG_FILE="${PROJECT_DIR}/deploy.log"

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

# 显示帮助信息
show_help() {
    cat << EOF
球探社部署脚本

用法: $0 [选项] [命令]

命令:
  deploy      完整部署（默认）
  update      更新服务
  rollback    回滚到上一版本
  backup      备份数据
  restore     恢复数据
  logs        查看日志
  status      查看服务状态
  cleanup     清理旧资源

选项:
  -h, --help              显示此帮助信息
  -e, --env FILE          指定环境变量文件 (默认: .env.production)
  -f, --force             强制执行，跳过确认
  -v, --verbose           详细输出
  --no-backup             部署时跳过备份
  --dry-run               试运行，不实际执行

示例:
  $0 deploy                 # 完整部署
  $0 update --no-backup     # 更新服务但跳过备份
  $0 rollback               # 回滚到上一版本
  $0 backup                 # 手动备份
  $0 logs backend           # 查看后端日志
EOF
}

# 检查依赖
check_dependencies() {
    log "检查系统依赖..."
    
    local deps=("docker" "docker-compose" "curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "未找到依赖: $dep。请先安装 $dep。"
        fi
    done
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        error "Docker 未运行。请启动 Docker。"
    fi
    
    log "依赖检查完成 ✓"
}

# 加载环境变量
load_env() {
    if [ -f "$ENV_FILE" ]; then
        log "加载环境变量: $ENV_FILE"
        set -a
        source "$ENV_FILE"
        set +a
    else
        warn "环境变量文件不存在: $ENV_FILE"
        info "创建环境变量模板..."
        create_env_template
    fi
}

# 创建环境变量模板
create_env_template() {
    cat > "$ENV_FILE" << EOF
# 球探社生产环境配置

# 数据库配置
DB_USER=ballscout
DB_PASSWORD=your_secure_password_here
DB_PORT=5432

# Redis配置
REDIS_PASSWORD=your_redis_password_here
REDIS_PORT=6379

# API密钥
DEEPSEEK_API_KEY=your_deepseek_api_key
CLAUDE_API_KEY=your_claude_api_key
OPENAI_API_KEY=your_openai_api_key

# JWT配置
JWT_SECRET=your_jwt_secret_key_at_least_32_chars

# 服务端口
BACKEND_PORT=8000
FRONTEND_PORT=3000
HTTP_PORT=80
HTTPS_PORT=443

# URL配置
FRONTEND_URL=https://your-domain.com
BACKEND_URL=https://api.your-domain.com

# 监控配置
PROMETHEUS_PORT=9090
GRAFANA_PORT=3001
GRAFANA_USER=admin
GRAFANA_PASSWORD=your_grafana_password

# 性能配置
LOG_LEVEL=info
RATE_LIMIT_MAX=1000
RATE_LIMIT_WINDOW=900000
EOF
    
    error "请编辑 $ENV_FILE 并设置正确的配置值，然后重新运行部署脚本。"
}

# 验证配置
validate_config() {
    log "验证配置..."
    
    local required_vars=(
        "DB_PASSWORD"
        "REDIS_PASSWORD" 
        "JWT_SECRET"
        "DEEPSEEK_API_KEY"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            error "必需的环境变量未设置: $var"
        fi
        
        # 检查密码强度
        if [[ "$var" == *"PASSWORD"* ]] || [[ "$var" == *"SECRET"* ]]; then
            if [ ${#!var} -lt 12 ]; then
                error "$var 长度至少需要12个字符"
            fi
        fi
    done
    
    # 检查JWT密钥长度
    if [ ${#JWT_SECRET} -lt 32 ]; then
        error "JWT_SECRET 长度至少需要32个字符"
    fi
    
    log "配置验证完成 ✓"
}

# 创建必要目录
create_directories() {
    log "创建必要目录..."
    
    local dirs=(
        "$BACKUP_DIR"
        "${PROJECT_DIR}/ssl"
        "${PROJECT_DIR}/config"
        "${PROJECT_DIR}/monitoring"
        "${PROJECT_DIR}/logs"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log "创建目录: $dir"
        fi
    done
}

# 备份数据库
backup_database() {
    if [ "$NO_BACKUP" = true ]; then
        log "跳过数据库备份"
        return 0
    fi
    
    log "开始数据库备份..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/ballscout_${timestamp}.sql"
    
    # 确保备份目录存在
    mkdir -p "$BACKUP_DIR"
    
    # 检查PostgreSQL容器是否运行
    if docker-compose -f "$COMPOSE_FILE" ps postgres | grep -q "Up"; then
        log "备份PostgreSQL数据库..."
        docker-compose -f "$COMPOSE_FILE" exec -T postgres pg_dump \
            -U "${DB_USER:-ballscout}" \
            -d ball_scout \
            --clean \
            --if-exists \
            --create > "$backup_file"
        
        if [ $? -eq 0 ]; then
            log "数据库备份完成: $backup_file"
            
            # 压缩备份文件
            gzip "$backup_file"
            log "备份文件已压缩: ${backup_file}.gz"
            
            # 清理旧备份（保留最近7天）
            find "$BACKUP_DIR" -name "ballscout_*.sql.gz" -mtime +7 -delete
            log "清理了7天前的旧备份文件"
        else
            error "数据库备份失败"
        fi
    else
        warn "PostgreSQL容器未运行，跳过备份"
    fi
}

# 构建镜像
build_images() {
    log "构建Docker镜像..."
    
    # 构建后端镜像
    log "构建后端镜像..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache backend
    
    # 构建前端镜像
    log "构建前端镜像..."
    docker-compose -f "$COMPOSE_FILE" build --no-cache frontend
    
    log "镜像构建完成 ✓"
}

# 部署服务
deploy_services() {
    log "开始部署服务..."
    
    # 启动基础设施服务
    log "启动数据库服务..."
    docker-compose -f "$COMPOSE_FILE" up -d postgres redis
    
    # 等待数据库就绪
    log "等待数据库服务就绪..."
    wait_for_service "postgres" "5432"
    wait_for_service "redis" "6379"
    
    # 启动应用服务
    log "启动应用服务..."
    docker-compose -f "$COMPOSE_FILE" up -d backend frontend
    
    # 等待应用服务就绪
    log "等待应用服务就绪..."
    wait_for_service "backend" "8000"
    wait_for_service "frontend" "3000"
    
    # 启动反向代理
    log "启动Nginx反向代理..."
    docker-compose -f "$COMPOSE_FILE" up -d nginx
    
    # 启动监控服务（可选）
    if [ "$ENABLE_MONITORING" = true ]; then
        log "启动监控服务..."
        docker-compose -f "$COMPOSE_FILE" up -d prometheus grafana
    fi
    
    log "服务部署完成 ✓"
}

# 等待服务就绪
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    log "等待 $service 服务就绪 (端口 $port)..."
    
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" exec -T "$service" nc -z localhost "$port" 2>/dev/null; then
            log "$service 服务已就绪"
            return 0
        fi
        
        log "等待 $service... ($attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    error "$service 服务启动超时"
}

# 健康检查
health_check() {
    log "执行健康检查..."
    
    local services=("backend" "frontend" "postgres" "redis")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! docker-compose -f "$COMPOSE_FILE" ps "$service" | grep -q "Up (healthy)"; then
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log "所有服务健康检查通过 ✓"
        return 0
    else
        error "以下服务健康检查失败: ${failed_services[*]}"
    fi
}

# 运行集成测试
run_tests() {
    log "运行集成测试..."
    
    # API健康检查
    local backend_url="http://localhost:${BACKEND_PORT:-8000}"
    if curl -f -s "$backend_url/health" > /dev/null; then
        log "后端API健康检查通过 ✓"
    else
        error "后端API健康检查失败"
    fi
    
    # 前端健康检查
    local frontend_url="http://localhost:${FRONTEND_PORT:-3000}"
    if curl -f -s "$frontend_url" > /dev/null; then
        log "前端健康检查通过 ✓"
    else
        error "前端健康检查失败"
    fi
    
    # 数据库连接测试
    if docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U "${DB_USER:-ballscout}" -d ball_scout -c "SELECT 1;" > /dev/null; then
        log "数据库连接测试通过 ✓"
    else
        error "数据库连接测试失败"
    fi
    
    # Redis连接测试
    if docker-compose -f "$COMPOSE_FILE" exec -T redis redis-cli ping > /dev/null; then
        log "Redis连接测试通过 ✓"
    else
        error "Redis连接测试失败"
    fi
    
    log "集成测试完成 ✓"
}

# 显示部署信息
show_deployment_info() {
    log "=== 🎉 部署完成 ==="
    log ""
    log "访问地址:"
    log "  前端应用: http://localhost:${FRONTEND_PORT:-3000}"
    log "  后端API:  http://localhost:${BACKEND_PORT:-8000}"
    log "  API文档:  http://localhost:${BACKEND_PORT:-8000}/api"
    log ""
    
    if [ "$ENABLE_MONITORING" = true ]; then
        log "监控面板:"
        log "  Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
        log "  Grafana:    http://localhost:${GRAFANA_PORT:-3001}"
        log "              用户名: ${GRAFANA_USER:-admin}"
        log ""
    fi
    
    log "有用的命令:"
    log "  查看服务状态: docker-compose -f $COMPOSE_FILE ps"
    log "  查看日志:     docker-compose -f $COMPOSE_FILE logs -f [service]"
    log "  停止服务:     docker-compose -f $COMPOSE_FILE down"
    log "  更新服务:     $0 update"
    log ""
    log "日志文件: $LOG_FILE"
    log "备份目录: $BACKUP_DIR"
}

# 回滚部署
rollback_deployment() {
    log "开始回滚部署..."
    
    # 找到最新的备份文件
    local latest_backup=$(find "$BACKUP_DIR" -name "ballscout_*.sql.gz" | sort | tail -1)
    
    if [ -z "$latest_backup" ]; then
        error "未找到备份文件，无法回滚"
    fi
    
    log "使用备份文件进行回滚: $latest_backup"
    
    if [ "$FORCE" != true ]; then
        read -p "确认要回滚到备份 $latest_backup 吗? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "回滚已取消"
            exit 0
        fi
    fi
    
    # 停止当前服务
    log "停止当前服务..."
    docker-compose -f "$COMPOSE_FILE" down
    
    # 恢复数据库
    log "恢复数据库..."
    docker-compose -f "$COMPOSE_FILE" up -d postgres
    wait_for_service "postgres" "5432"
    
    # 解压并恢复备份
    gunzip -c "$latest_backup" | docker-compose -f "$COMPOSE_FILE" exec -T postgres psql -U "${DB_USER:-ballscout}" -d ball_scout
    
    # 重新启动服务
    log "重新启动服务..."
    deploy_services
    
    log "回滚完成 ✓"
}

# 主函数
main() {
    local command="deploy"
    local FORCE=false
    local NO_BACKUP=false
    local DRY_RUN=false
    local VERBOSE=false
    local ENABLE_MONITORING=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -e|--env)
                ENV_FILE="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --no-backup)
                NO_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            --enable-monitoring)
                ENABLE_MONITORING=true
                shift
                ;;
            deploy|update|rollback|backup|restore|logs|status|cleanup)
                command="$1"
                shift
                ;;
            *)
                error "未知选项: $1"
                ;;
        esac
    done
    
    # 创建日志文件
    touch "$LOG_FILE"
    
    log "球探社部署脚本开始执行"
    log "命令: $command"
    log "项目目录: $PROJECT_DIR"
    log "环境文件: $ENV_FILE"
    
    # 执行基础检查
    check_dependencies
    load_env
    validate_config
    create_directories
    
    # 根据命令执行相应操作
    case $command in
        deploy)
            if [ "$FORCE" != true ]; then
                read -p "确认要部署到生产环境吗? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log "部署已取消"
                    exit 0
                fi
            fi
            
            backup_database
            build_images
            deploy_services
            health_check
            run_tests
            show_deployment_info
            ;;
        update)
            backup_database
            log "拉取最新代码..."
            git pull origin main
            build_images
            log "重启服务..."
            docker-compose -f "$COMPOSE_FILE" up -d --force-recreate
            health_check
            log "服务更新完成 ✓"
            ;;
        rollback)
            rollback_deployment
            ;;
        backup)
            backup_database
            ;;
        logs)
            docker-compose -f "$COMPOSE_FILE" logs -f "${2:-}"
            ;;
        status)
            docker-compose -f "$COMPOSE_FILE" ps
            ;;
        cleanup)
            log "清理未使用的Docker资源..."
            docker system prune -f
            docker volume prune -f
            log "清理完成 ✓"
            ;;
        *)
            error "未知命令: $command"
            ;;
    esac
}

# 捕获信号处理
cleanup_on_exit() {
    log "部署脚本退出，清理临时资源..."
    # 在这里添加清理逻辑
}

trap cleanup_on_exit EXIT

# 运行主函数
main "$@"