# Makefile para Ecommerce Microservices Project
# Simplifica comandos comunes de desarrollo

.PHONY: help start stop clean logs status cdk-diff cdk-deploy cdk-destroy test

# Variables
COMPOSE_DEV := docker-compose -f docker-compose-dev.yml
COMPOSE_LOCALSTACK := docker-compose -f docker-compose.localstack.yml
CDK_DIR := infrastructure-cdk

# Color output
COLOR_RESET := \033[0m
COLOR_INFO := \033[0;36m
COLOR_SUCCESS := \033[0;32m

##@ General

help: ## Muestra esta ayuda
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(COLOR_INFO)Uso:$(COLOR_RESET)\n  make $(COLOR_INFO)<target>$(COLOR_RESET)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(COLOR_INFO)%-20s$(COLOR_RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(COLOR_SUCCESS)%s$(COLOR_RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Desarrollo

start: ## Inicia todo el entorno de desarrollo (LocalStack + servicios + CDK)
	@echo "$(COLOR_INFO)🚀 Iniciando entorno de desarrollo completo...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh

start-infra: ## Inicia solo infraestructura (LocalStack + CDK)
	@echo "$(COLOR_INFO)🏗️  Iniciando solo infraestructura...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh --only-infrastructure

start-services: ## Inicia solo los microservicios (sin CDK)
	@echo "$(COLOR_INFO)🚀 Iniciando microservicios...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh --skip-cdk

start-build: ## Inicia el entorno reconstruyendo imágenes
	@echo "$(COLOR_INFO)🔨 Reconstruyendo e iniciando entorno...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh --build

stop: ## Detiene todos los servicios
	@echo "$(COLOR_INFO)🛑 Deteniendo entorno de desarrollo...$(COLOR_RESET)"
	@./scripts/stop-dev-environment.sh

clean: ## Detiene servicios y elimina volúmenes (⚠️ pérdida de datos)
	@echo "$(COLOR_INFO)🧹 Limpiando entorno completo...$(COLOR_RESET)"
	@./scripts/stop-dev-environment.sh --clean

restart: stop start ## Reinicia todo el entorno

##@ Docker

logs: ## Muestra logs de todos los servicios
	@$(COMPOSE_DEV) logs -f

rebuild-gateway: ## Rebuild + restart API Gateway (usa después de cambiar .env o dependencias)
	@echo "$(COLOR_INFO)🔨 Rebuilding API Gateway...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-api-gateway

rebuild-auth: ## Rebuild + restart Auth Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Auth Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-auth-service

rebuild-users: ## Rebuild + restart Users Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Users Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-users-service

rebuild-inventory: ## Rebuild + restart Inventory Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Inventory Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-inventory-service

rebuild-orders: ## Rebuild + restart Order-Product Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Order-Product Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-order-product-service

rebuild-all: ## Rebuild + restart todos los microservicios
	@echo "$(COLOR_INFO)🔨 Rebuilding todos los servicios...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate

logs-api-gateway: ## Logs del API Gateway
	@docker logs -f ecommerce-api-gateway

logs-auth: ## Logs del Auth Service
	@docker logs -f ecommerce-auth-service

logs-users: ## Logs del Users Service
	@docker logs -f ecommerce-users-service

logs-inventory: ## Logs del Inventory Service
	@docker logs -f ecommerce-inventory-service

logs-orders: ## Logs del Order-Product Service
	@docker logs -f ecommerce-order-product-service

logs-localstack: ## Logs de LocalStack
	@docker logs -f ecommerce-localstack

ps: ## Lista todos los contenedores corriendo
	@docker ps

status: ## Muestra el estado de todos los servicios
	@echo "$(COLOR_SUCCESS)📊 Estado de servicios:$(COLOR_RESET)\n"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep ecommerce || echo "No hay servicios corriendo"

##@ CDK

cdk-install: ## Instala dependencias de CDK
	@cd $(CDK_DIR) && npm install

cdk-diff: ## Muestra diferencias de infraestructura
	@cd $(CDK_DIR) && \
		export AWS_REGION=us-east-1 && \
		export AWS_ACCESS_KEY_ID=test && \
		export AWS_SECRET_ACCESS_KEY=test && \
		export AWS_ENDPOINT_URL=http://localhost:4566 && \
		export STAGE=dev && \
		npm run diff

cdk-deploy: ## Despliega infraestructura con CDK
	@cd $(CDK_DIR) && \
		export AWS_REGION=us-east-1 && \
		export AWS_ACCESS_KEY_ID=test && \
		export AWS_SECRET_ACCESS_KEY=test && \
		export AWS_ENDPOINT_URL=http://localhost:4566 && \
		export STAGE=dev && \
		npm run deploy

cdk-destroy: ## Destruye la infraestructura desplegada
	@cd $(CDK_DIR) && \
		export AWS_REGION=us-east-1 && \
		export AWS_ACCESS_KEY_ID=test && \
		export AWS_SECRET_ACCESS_KEY=test && \
		export AWS_ENDPOINT_URL=http://localhost:4566 && \
		export STAGE=dev && \
		npm run destroy

cdk-synth: ## Genera el template de CloudFormation
	@cd $(CDK_DIR) && npm run synth

##@ AWS LocalStack

aws-tables: ## Lista las tablas DynamoDB en LocalStack
	@aws --endpoint-url=http://localhost:4566 dynamodb list-tables

aws-queues: ## Lista las colas SQS en LocalStack
	@aws --endpoint-url=http://localhost:4566 sqs list-queues

aws-buckets: ## Lista los buckets S3 en LocalStack
	@aws --endpoint-url=http://localhost:4566 s3 ls

aws-health: ## Verifica el estado de LocalStack
	@curl -s http://localhost:4566/_localstack/health | jq '.'

##@ Database Seeds

seed-all: ## Ejecuta todos los seeds de bases de datos
	@echo "$(COLOR_INFO)🌱 Seeding all databases...$(COLOR_RESET)"
	@cd db-seeds && ./seed-all.sh

seed-mysql: ## Seed solo MySQL (Auth)
	@cd db-seeds && npm run seed:mysql

seed-dynamodb: ## Seed solo DynamoDB (Users)
	@cd db-seeds && npm run seed:dynamodb

seed-inventory: ## Seed solo PostgreSQL Inventory
	@cd db-seeds && npm run seed:inventory

seed-orders: ## Seed solo PostgreSQL Order-Product
	@cd db-seeds && npm run seed:orders

##@ Testing

test-health: ## Verifica el health de todos los microservicios
	@echo "$(COLOR_INFO)🏥 Verificando health de servicios...$(COLOR_RESET)\n"
	@echo "API Gateway:"; curl -s http://localhost:3000/health | jq '.' || echo "❌ No disponible"
	@echo "\nAuth Service:"; curl -s http://localhost:3010/health | jq '.' || echo "❌ No disponible"
	@echo "\nUsers Service:"; curl -s http://localhost:3012/health | jq '.' || echo "❌ No disponible"
	@echo "\nInventory Service:"; curl -s http://localhost:3011/health | jq '.' || echo "❌ No disponible"
	@echo "\nOrder-Product Service:"; curl -s http://localhost:3600/health | jq '.' || echo "❌ No disponible"

##@ Utilidades

shell-api-gateway: ## Abre shell en API Gateway container
	@docker exec -it ecommerce-api-gateway sh

shell-auth: ## Abre shell en Auth Service container
	@docker exec -it ecommerce-auth-service sh

shell-localstack: ## Abre shell en LocalStack container
	@docker exec -it ecommerce-localstack sh

prune: ## Limpia recursos de Docker no utilizados
	@docker system prune -f
	@docker volume prune -f

urls: ## Muestra todas las URLs de servicios
	@echo "$(COLOR_SUCCESS)🌐 URLs de Servicios:$(COLOR_RESET)\n"
	@echo "Microservicios:"
	@echo "  • API Gateway:         http://localhost:3000"
	@echo "  • Auth Service:        http://localhost:3010"
	@echo "  • Users Service:       http://localhost:3012"
	@echo "  • Inventory Service:   http://localhost:3011"
	@echo "  • Order-Product:       http://localhost:3600"
	@echo ""
	@echo "Infraestructura:"
	@echo "  • LocalStack:          http://localhost:4566"
	@echo "  • LocalStack Health:   http://localhost:4566/_localstack/health"
	@echo ""
	@echo "Observabilidad:"
	@echo "  • Grafana:             http://localhost:3001 (admin/admin)"
	@echo "  • Prometheus:          http://localhost:9090"
	@echo "  • RabbitMQ:            http://localhost:15672 (user/password)"
	@echo ""
	@echo "Bases de datos:"
	@echo "  • MySQL (Auth):        localhost:3307"
	@echo "  • DynamoDB Local:      http://localhost:8000"
	@echo "  • PostgreSQL (Inv):    localhost:5434"
	@echo "  • PostgreSQL (Order):  localhost:5432"
