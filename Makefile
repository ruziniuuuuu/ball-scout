# 速达足球开发工具 Makefile

# 颜色定义
BLUE=\033[0;34m
GREEN=\033[0;32m
YELLOW=\033[1;33m
RED=\033[0;31m
NC=\033[0m # No Color

# 项目信息
PROJECT_NAME=soda
FRONTEND_DIR=.
BACKEND_DIR=backend

# 默认目标
.PHONY: help
help: ## 显示帮助信息
	@echo "$(BLUE)速达足球开发工具$(NC)"
	@echo ""
	@echo "可用命令："
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'

# 环境设置
.PHONY: setup
setup: ## 设置开发环境
	@echo "$(BLUE)设置速达足球开发环境...$(NC)"
	@echo "检查依赖..."
	@which flutter > /dev/null || (echo "$(RED)Flutter未安装$(NC)" && exit 1)
	@which deno > /dev/null || (echo "$(RED)Deno未安装$(NC)" && exit 1)
	@which docker > /dev/null || (echo "$(RED)Docker未安装$(NC)" && exit 1)
	@echo "$(GREEN)依赖检查完成$(NC)"
	$(MAKE) deps

.PHONY: deps
deps: ## 安装项目依赖
	@echo "$(BLUE)安装Flutter依赖...$(NC)"
	flutter pub get
	@echo "$(BLUE)安装Deno依赖...$(NC)"
	cd $(BACKEND_DIR) && deno cache deps.ts
	@echo "$(GREEN)依赖安装完成$(NC)"

# 开发服务器
.PHONY: dev
dev: ## 启动完整开发环境
	@echo "$(BLUE)启动速达足球开发环境...$(NC)"
	@echo "启动数据库服务..."
	docker-compose -f docker-compose.dev.yml up -d postgres redis
	@echo "等待数据库就绪..."
	@sleep 5
	@echo "$(GREEN)开发环境已启动$(NC)"
	@echo "请在不同终端中运行："
	@echo "  $(YELLOW)make dev-backend$(NC)  # 启动后端服务"
	@echo "  $(YELLOW)make dev-frontend$(NC) # 启动前端服务"

.PHONY: dev-frontend
dev-frontend: ## 启动前端开发服务器
	@echo "$(BLUE)启动Flutter前端服务器...$(NC)"
	flutter run -d web-server --web-port=3000 --web-hostname=0.0.0.0

.PHONY: dev-backend
dev-backend: ## 启动后端开发服务器
	@echo "$(BLUE)启动Deno后端服务器...$(NC)"
	cd $(BACKEND_DIR) && deno task dev

.PHONY: dev-stop
dev-stop: ## 停止开发环境
	@echo "$(BLUE)停止开发环境...$(NC)"
	docker-compose -f docker-compose.dev.yml down
	@pkill -f "flutter run" || true
	@pkill -f "deno.*dev" || true
	@echo "$(GREEN)开发环境已停止$(NC)"

# 代码质量
.PHONY: lint
lint: ## 运行代码检查
	@echo "$(BLUE)检查Flutter代码...$(NC)"
	flutter analyze
	@echo "$(BLUE)检查Deno代码...$(NC)"
	cd $(BACKEND_DIR) && deno lint
	@echo "$(GREEN)代码检查完成$(NC)"

.PHONY: format
format: ## 格式化代码
	@echo "$(BLUE)格式化Flutter代码...$(NC)"
	flutter format .
	@echo "$(BLUE)格式化Deno代码...$(NC)"
	cd $(BACKEND_DIR) && deno fmt
	@echo "$(GREEN)代码格式化完成$(NC)"

.PHONY: format-check
format-check: ## 检查代码格式
	@echo "$(BLUE)检查Flutter代码格式...$(NC)"
	flutter format --dry-run --set-exit-if-changed .
	@echo "$(BLUE)检查Deno代码格式...$(NC)"
	cd $(BACKEND_DIR) && deno fmt --check
	@echo "$(GREEN)代码格式检查完成$(NC)"

# 测试
.PHONY: test
test: ## 运行所有测试
	$(MAKE) test-frontend
	$(MAKE) test-backend

.PHONY: test-frontend
test-frontend: ## 运行Flutter测试
	@echo "$(BLUE)运行Flutter测试...$(NC)"
	flutter test --coverage --reporter=github
	@echo "$(GREEN)Flutter测试完成$(NC)"

.PHONY: test-backend
test-backend: ## 运行Deno测试
	@echo "$(BLUE)运行Deno测试...$(NC)"
	cd $(BACKEND_DIR) && deno task test --coverage=coverage
	@echo "$(GREEN)Deno测试完成$(NC)"

.PHONY: test-integration
test-integration: ## 运行集成测试
	@echo "$(BLUE)运行集成测试...$(NC)"
	@echo "确保开发环境正在运行..."
	flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
	@echo "$(GREEN)集成测试完成$(NC)"

.PHONY: test-coverage
test-coverage: ## 生成测试覆盖率报告
	@echo "$(BLUE)生成测试覆盖率报告...$(NC)"
	flutter test --coverage
	genhtml coverage/lcov.info -o coverage/html --title "速达足球前端测试覆盖率"
	cd $(BACKEND_DIR) && deno task test --coverage=coverage
	cd $(BACKEND_DIR) && deno coverage coverage --html
	@echo "$(GREEN)覆盖率报告已生成$(NC)"
	@echo "前端覆盖率报告: $(YELLOW)coverage/html/index.html$(NC)"
	@echo "后端覆盖率报告: $(YELLOW)backend/coverage/html/index.html$(NC)"

# 构建
.PHONY: build
build: ## 构建生产版本
	$(MAKE) build-frontend
	$(MAKE) build-backend

.PHONY: build-frontend
build-frontend: ## 构建Flutter应用
	@echo "$(BLUE)构建Flutter Web应用...$(NC)"
	flutter build web --release
	@echo "$(BLUE)构建Flutter Android应用...$(NC)"
	flutter build apk --release
	@echo "$(GREEN)Flutter应用构建完成$(NC)"

.PHONY: build-backend
build-backend: ## 编译Deno后端
	@echo "$(BLUE)编译Deno后端...$(NC)"
	cd $(BACKEND_DIR) && deno compile --allow-net --allow-read --allow-env --output ../build/soda-backend mod.ts
	@echo "$(GREEN)后端编译完成$(NC)"

# 代码生成
.PHONY: generate
generate: ## 生成代码
	@echo "$(BLUE)生成Flutter代码...$(NC)"
	flutter packages pub run build_runner build --delete-conflicting-outputs
	@echo "$(GREEN)代码生成完成$(NC)"

.PHONY: generate-watch
generate-watch: ## 监听文件变化并生成代码
	@echo "$(BLUE)启动代码生成监听...$(NC)"
	flutter packages pub run build_runner watch --delete-conflicting-outputs

# Docker
.PHONY: docker-build
docker-build: ## 构建Docker镜像
	@echo "$(BLUE)构建Docker镜像...$(NC)"
	docker build -t $(PROJECT_NAME)-frontend:latest .
	docker build -t $(PROJECT_NAME)-backend:latest $(BACKEND_DIR)
	@echo "$(GREEN)Docker镜像构建完成$(NC)"

.PHONY: docker-run
docker-run: ## 运行Docker容器
	@echo "$(BLUE)启动Docker容器...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)Docker容器已启动$(NC)"
	@echo "前端访问地址: $(YELLOW)http://localhost:3000$(NC)"
	@echo "后端API地址: $(YELLOW)http://localhost:8000$(NC)"

.PHONY: docker-stop
docker-stop: ## 停止Docker容器
	@echo "$(BLUE)停止Docker容器...$(NC)"
	docker-compose down
	@echo "$(GREEN)Docker容器已停止$(NC)"

.PHONY: docker-logs
docker-logs: ## 查看Docker容器日志
	docker-compose logs -f

# 数据库
.PHONY: db-setup
db-setup: ## 设置数据库
	@echo "$(BLUE)设置数据库...$(NC)"
	docker-compose -f docker-compose.dev.yml up -d postgres
	@sleep 5
	@echo "初始化数据库结构..."
	@docker exec -i $$(docker-compose -f docker-compose.dev.yml ps -q postgres) psql -U postgres -d soda < scripts/setup-database.sql
	@echo "$(GREEN)数据库设置完成$(NC)"

.PHONY: db-reset
db-reset: ## 重置数据库
	@echo "$(BLUE)重置数据库...$(NC)"
	docker-compose -f docker-compose.dev.yml down postgres
	docker volume rm soda_postgres_data || true
	$(MAKE) db-setup
	@echo "$(GREEN)数据库重置完成$(NC)"

.PHONY: db-shell
db-shell: ## 进入数据库Shell
	@echo "$(BLUE)进入数据库Shell...$(NC)"
	docker exec -it $$(docker-compose -f docker-compose.dev.yml ps -q postgres) psql -U postgres -d soda

# 实用工具
.PHONY: clean
clean: ## 清理构建产物
	@echo "$(BLUE)清理构建产物...$(NC)"
	flutter clean
	rm -rf build/
	rm -rf coverage/
	rm -rf $(BACKEND_DIR)/coverage/
	@echo "$(GREEN)清理完成$(NC)"

.PHONY: doctor
doctor: ## 检查开发环境状态
	@echo "$(BLUE)检查开发环境状态...$(NC)"
	@echo "Flutter环境:"
	flutter doctor -v
	@echo ""
	@echo "Deno环境:"
	deno --version
	@echo ""
	@echo "Docker环境:"
	docker --version
	docker-compose --version
	@echo "$(GREEN)环境检查完成$(NC)"

.PHONY: logs
logs: ## 查看应用日志
	@echo "$(BLUE)查看应用日志...$(NC)"
	@echo "后端日志:"
	@tail -f $(BACKEND_DIR)/backend.log 2>/dev/null || echo "后端日志文件不存在"
	@echo ""
	@echo "前端日志:"
	@tail -f logs/frontend.log 2>/dev/null || echo "前端日志文件不存在"

.PHONY: api-test
api-test: ## 测试API接口
	@echo "$(BLUE)测试API接口...$(NC)"
	@./scripts/test-api.sh

.PHONY: update-deps
update-deps: ## 更新依赖
	@echo "$(BLUE)更新Flutter依赖...$(NC)"
	flutter pub upgrade
	@echo "$(BLUE)更新Deno依赖...$(NC)"
	cd $(BACKEND_DIR) && deno cache --reload deps.ts
	@echo "$(GREEN)依赖更新完成$(NC)"

# Git hooks
.PHONY: install-hooks
install-hooks: ## 安装Git hooks
	@echo "$(BLUE)安装Git hooks...$(NC)"
	@cp scripts/pre-commit .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@cp scripts/pre-push .git/hooks/pre-push
	@chmod +x .git/hooks/pre-push
	@echo "$(GREEN)Git hooks安装完成$(NC)"

# 部署相关
.PHONY: deploy-staging
deploy-staging: ## 部署到staging环境
	@echo "$(BLUE)部署到staging环境...$(NC)"
	@echo "$(YELLOW)请确保通过所有测试$(NC)"
	$(MAKE) test
	$(MAKE) build
	@echo "$(GREEN)准备完成，执行部署...$(NC)"
	# 这里添加实际的部署脚本

.PHONY: deploy-production
deploy-production: ## 部署到生产环境
	@echo "$(BLUE)部署到生产环境...$(NC)"
	@echo "$(RED)警告: 即将部署到生产环境!$(NC)"
	@read -p "确认继续? (y/N): " confirm && [ "$$confirm" = "y" ]
	$(MAKE) test
	$(MAKE) build
	@echo "$(GREEN)准备完成，执行部署...$(NC)"
	# 这里添加实际的部署脚本

# 监控和性能
.PHONY: perf-test
perf-test: ## 运行性能测试
	@echo "$(BLUE)运行性能测试...$(NC)"
	@echo "测试后端API性能..."
	@ab -n 1000 -c 10 http://localhost:8000/api/v1/news || echo "Apache Bench 未安装，跳过API性能测试"
	@echo "$(GREEN)性能测试完成$(NC)"

# 帮助信息
.PHONY: info
info: ## 显示项目信息
	@echo "$(BLUE)速达足球项目信息$(NC)"
	@echo ""
	@echo "项目名称: $(PROJECT_NAME)"
	@echo "前端技术: Flutter"
	@echo "后端技术: Deno + TypeScript"
	@echo "数据库: PostgreSQL + Redis"
	@echo ""
	@echo "开发服务器地址:"
	@echo "  前端: http://localhost:3000"
	@echo "  后端: http://localhost:8000"
	@echo "  API文档: http://localhost:8000/api"
	@echo ""
	@echo "有用的命令:"
	@echo "  $(YELLOW)make setup$(NC)     - 初始化开发环境"
	@echo "  $(YELLOW)make dev$(NC)       - 启动开发环境"
	@echo "  $(YELLOW)make test$(NC)      - 运行所有测试"
	@echo "  $(YELLOW)make build$(NC)     - 构建生产版本"