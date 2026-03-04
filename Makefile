# Makefile para Ecommerce Microservices Project
# Simplifica comandos comunes de desarrollo

.PHONY: help start stop clean logs status cdk-diff cdk-deploy cdk-destroy test test-health lint typecheck verify preflight check-tools db-users db-inventory db-orders aws-scan-users open debug-gateway debug-auth debug-inventory debug-orders stop-debug-gateway stop-debug-auth stop-debug-inventory stop-debug-orders
.PHONY: 1 20 21 22 23 24 30 31 32 33 34 35 36 40 41 42 43 44 45 46 50 51 52 53 54 60 61 62 63 64 70 71 72 73 74 80 81 82 90 100 101 102 103 104 105 106 107 110 111 112 113 114 115 116 117 118 119 120 121 122 123

# Variables
COMPOSE_DEV := docker compose -f docker-compose-dev.yml
COMPOSE_DEBUG := docker compose -f docker-compose-dev.yml -f docker-compose.debug.yml
COMPOSE_LOCALSTACK := docker compose -f docker-compose.localstack.yml
CDK_DIR := infrastructure-cdk
SERVICES := ecommerce-api-gateway ecommerce-auth-service serverless-users-service ecommerce-inventory-service ecommerce-order-product-service

# Color output
COLOR_RESET := \033[0m
COLOR_INFO := \033[0;36m
COLOR_SUCCESS := \033[0;32m

define run_npm_script_all
	@set -e; \
	for svc in $(SERVICES); do \
		if [ -f "$$svc/package.json" ]; then \
			echo "$(COLOR_INFO)==> $$svc: npm run $(1)$(COLOR_RESET)"; \
			npm --prefix "$$svc" run $(1) --if-present; \
		fi; \
	done
endef

##@ General

help: ## [1] Muestra esta ayuda
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(COLOR_INFO)Uso:$(COLOR_RESET)\n  make $(COLOR_INFO)<target>$(COLOR_RESET)\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  $(COLOR_INFO)%-22s$(COLOR_RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(COLOR_SUCCESS)%s$(COLOR_RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


##@ Utilidades

shell-api-gateway: ## [20] Abre shell en API Gateway container
	@docker exec -it ecommerce-api-gateway sh

shell-auth: ## [21] Abre shell en Auth Service container
	@docker exec -it ecommerce-auth-service sh

shell-localstack: ## [22] Abre shell en LocalStack container
	@docker exec -it ecommerce-localstack sh

prune: ## [23] Limpia recursos de Docker no utilizados
	@docker system prune -f
	@docker volume prune -f

urls: ## [24] Muestra todas las URLs de servicios
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


##@ Desarrollo

start: ## [30] Inicia todo el entorno de desarrollo (LocalStack + servicios + CDK)
	@echo "$(COLOR_INFO)🚀 Iniciando entorno de desarrollo completo...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh

start-infra: ## [31] Inicia solo infraestructura (LocalStack + CDK)
	@echo "$(COLOR_INFO)🏗️  Iniciando solo infraestructura...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh --only-infrastructure

start-services: ## [32] Inicia solo los microservicios (sin CDK)
	@echo "$(COLOR_INFO)🚀 Iniciando microservicios...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh --skip-cdk

start-build: ## [33] Inicia el entorno reconstruyendo imágenes
	@echo "$(COLOR_INFO)🔨 Reconstruyendo e iniciando entorno...$(COLOR_RESET)"
	@./scripts/start-dev-environment.sh --build

stop: ## [34] Detiene todos los servicios
	@echo "$(COLOR_INFO)🛑 Deteniendo entorno de desarrollo...$(COLOR_RESET)"
	@./scripts/stop-dev-environment.sh

clean: ## [35] Detiene servicios y elimina volúmenes (⚠️ pérdida de datos)
	@echo "$(COLOR_INFO)🧹 Limpiando entorno completo...$(COLOR_RESET)"
	@./scripts/stop-dev-environment.sh --clean

restart: stop start ## [36] Reinicia todo el entorno


##@ Testing

test-health: ## [40] Verifica el health de todos los microservicios
	@echo "$(COLOR_INFO)🏥 Verificando health de servicios...$(COLOR_RESET)\n"
	@echo "API Gateway:"; curl -s http://localhost:3000/health | jq '.' || echo "❌ No disponible"
	@echo "\nAuth Service:"; curl -s http://localhost:3010/health | jq '.' || echo "❌ No disponible"
	@echo "\nUsers Service:"; curl -s http://localhost:3012/health | jq '.' || echo "❌ No disponible"
	@echo "\nInventory Service:"; curl -s http://localhost:3011/health | jq '.' || echo "❌ No disponible"
	@echo "\nOrder-Product Service:"; curl -s http://localhost:3600/health | jq '.' || echo "❌ No disponible"

lint: ## [41] Ejecuta lint en todos los microservicios (si existe script)
	$(call run_npm_script_all,lint)

test: ## [42] Ejecuta tests en todos los microservicios (si existe script)
	$(call run_npm_script_all,test)

typecheck: ## [43] Ejecuta typecheck en todos los microservicios (si existe script)
	$(call run_npm_script_all,typecheck)
	$(call run_npm_script_all,type-check)

verify: lint typecheck test ## [44] Ejecuta verificación completa (lint + typecheck + test)
	@echo "$(COLOR_SUCCESS)✅ verify completado$(COLOR_RESET)"

check-tools: ## [45] Verifica herramientas base requeridas
	@command -v node >/dev/null || (echo "❌ node no instalado" && exit 1)
	@command -v npm >/dev/null || (echo "❌ npm no instalado" && exit 1)
	@command -v docker >/dev/null || (echo "❌ docker no instalado" && exit 1)
	@docker compose version >/dev/null || (echo "❌ docker compose (v2) no disponible" && exit 1)
	@echo "$(COLOR_SUCCESS)✅ herramientas base OK$(COLOR_RESET)"

preflight: check-tools verify ## [46] Ejecuta validaciones previas al trabajo
	@echo "$(COLOR_SUCCESS)✅ preflight completado$(COLOR_RESET)"


##@ CDK

cdk-install: ## [50] Instala dependencias de CDK
	@cd $(CDK_DIR) && npm install

cdk-diff: ## [51] Muestra diferencias de infraestructura
	@cd $(CDK_DIR) && \
		export AWS_REGION=us-east-1 && \
		export AWS_ACCESS_KEY_ID=test && \
		export AWS_SECRET_ACCESS_KEY=test && \
		export AWS_ENDPOINT_URL=http://localhost:4566 && \
		export STAGE=dev && \
		npm run diff

cdk-deploy: ## [52] Despliega infraestructura con CDK
	@cd $(CDK_DIR) && \
		export AWS_REGION=us-east-1 && \
		export AWS_ACCESS_KEY_ID=test && \
		export AWS_SECRET_ACCESS_KEY=test && \
		export AWS_ENDPOINT_URL=http://localhost:4566 && \
		export STAGE=dev && \
		npm run deploy

cdk-destroy: ## [53] Destruye la infraestructura desplegada
	@cd $(CDK_DIR) && \
		export AWS_REGION=us-east-1 && \
		export AWS_ACCESS_KEY_ID=test && \
		export AWS_SECRET_ACCESS_KEY=test && \
		export AWS_ENDPOINT_URL=http://localhost:4566 && \
		export STAGE=dev && \
		npm run destroy

cdk-synth: ## [54] Genera el template de CloudFormation
	@cd $(CDK_DIR) && npm run synth

##@ AWS LocalStack

aws-tables: ## [60] Lista las tablas DynamoDB en LocalStack
	@aws --endpoint-url=http://localhost:4566 dynamodb list-tables

aws-queues: ## [61] Lista las colas SQS en LocalStack
	@aws --endpoint-url=http://localhost:4566 sqs list-queues

aws-buckets: ## [62] Lista los buckets S3 en LocalStack
	@aws --endpoint-url=http://localhost:4566 s3 ls

aws-health: ## [63] Verifica el estado de LocalStack
	@curl -s http://localhost:4566/_localstack/health | jq '.'

aws-scan-users: ## [64] Scan DynamoDB tabla users-service-db
	@aws --endpoint-url=http://localhost:4566 dynamodb scan \
		--table-name users-service-db \
		--projection-expression "id, email, #n, #r" \
		--expression-attribute-names '{"#n":"name","#r":"role"}' \
		| jq '.Items[] | {id: .id.S, email: .email.S, name: .name.S, role: .role.S}'



##@ Database Seeds

seed-all: ## [70] Ejecuta todos los seeds de bases de datos
	@echo "$(COLOR_INFO)🌱 Seeding all databases...$(COLOR_RESET)"
	@cd db-seeds && ./seed-all.sh

seed-mysql: ## [71] Seed solo MySQL (Auth)
	@cd db-seeds && npm run seed:mysql

seed-dynamodb: ## [72] Seed solo DynamoDB (Users)
	@cd db-seeds && npm run seed:dynamodb

seed-inventory: ## [73] Seed solo PostgreSQL Inventory
	@cd db-seeds && npm run seed:inventory

seed-orders: ## [74] Seed solo PostgreSQL Order-Product
	@cd db-seeds && npm run seed:orders

##@ Bases de Datos

db-users: ## [80] MySQL shell (Auth Service, puerto 3307)
	@docker exec -it ecommerce-users-db mysql -u user -puser users_db

db-inventory: ## [81] psql shell (Inventory Service, puerto 5434)
	@docker exec -it ecommerce-inventory-db psql -U root -d inventory_db

db-orders: ## [82] psql shell (Order-Product Service, puerto 5432)
	@docker exec -it -e PGOPTIONS="--search_path=app" ecommerce-order-product-db psql -U root -d order_product_db


##@ VSCode

open: ## [90] Abre cada microservicio en ventana VSCode separada
	@echo "$(COLOR_INFO)💻 Abriendo proyectos en VSCode...$(COLOR_RESET)"
	@echo "$(COLOR_INFO)   Nota: acepta el permiso 'Allow' en VSCode para ejecutar tasks automáticas$(COLOR_RESET)"
	@code --new-window $(CURDIR)/ecommerce-api-gateway
	@sleep 1
	@code --new-window $(CURDIR)/ecommerce-auth-service
	@sleep 1
	@code --new-window $(CURDIR)/serverless-users-service
	@sleep 1
	@code --new-window $(CURDIR)/ecommerce-inventory-service
	@sleep 1
	@code --new-window $(CURDIR)/ecommerce-order-product-service
	@echo "$(COLOR_SUCCESS)✅ 5 ventanas VSCode abiertas — cada una lanzará sus logs de Docker automáticamente$(COLOR_RESET)"



##@ Debug (VSCode attach — puerto 9229)

debug-gateway: ## [100] Debug API Gateway (puerto 9229) — adjuntar VSCode
	@echo "$(COLOR_INFO)🐛 Iniciando API Gateway en modo debug (puerto 9229)...$(COLOR_RESET)"
	@$(COMPOSE_DEBUG) up ecommerce-api-gateway

debug-auth: ## [101] Debug Auth Service (puerto 9230) — adjuntar VSCode
	@echo "$(COLOR_INFO)🐛 Iniciando Auth Service en modo debug (puerto 9230)...$(COLOR_RESET)"
	@$(COMPOSE_DEBUG) up ecommerce-auth-service

debug-inventory: ## [102] Debug Inventory Service (puerto 9232) — adjuntar VSCode
	@echo "$(COLOR_INFO)🐛 Iniciando Inventory Service en modo debug (puerto 9232)...$(COLOR_RESET)"
	@$(COMPOSE_DEBUG) up ecommerce-inventory-service

debug-orders: ## [103] Debug Order-Product Service (puerto 9233) — adjuntar VSCode
	@echo "$(COLOR_INFO)🐛 Iniciando Order-Product Service en modo debug (puerto 9233)...$(COLOR_RESET)"
	@$(COMPOSE_DEBUG) up ecommerce-order-product-service

stop-debug-gateway: ## [104] Detiene debug — API Gateway vuelve a modo dev
	@echo "$(COLOR_INFO)🔄 Volviendo API Gateway a modo dev...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --force-recreate ecommerce-api-gateway
	@docker logs -f ecommerce-api-gateway

stop-debug-auth: ## [105] Detiene debug — Auth Service vuelve a modo dev
	@echo "$(COLOR_INFO)🔄 Volviendo Auth Service a modo dev...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --force-recreate ecommerce-auth-service
	@docker logs -f ecommerce-auth-service

stop-debug-inventory: ## [106] Detiene debug — Inventory Service vuelve a modo dev
	@echo "$(COLOR_INFO)🔄 Volviendo Inventory Service a modo dev...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --force-recreate ecommerce-inventory-service
	@docker logs -f ecommerce-inventory-service

stop-debug-orders: ## [107] Detiene debug — Order-Product Service vuelve a modo dev
	@echo "$(COLOR_INFO)🔄 Volviendo Order-Product Service a modo dev...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --force-recreate ecommerce-order-product-service
	@docker logs -f ecommerce-order-product-service


##@ Docker

logs: ## [110] Muestra logs de todos los servicios
	@$(COMPOSE_DEV) logs -f

rb-gateway: ## [111] Rebuild + restart API Gateway
	@echo "$(COLOR_INFO)🔨 Rebuilding API Gateway...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-api-gateway
	@docker logs -f ecommerce-api-gateway

rb-auth: ## [112] Rebuild + restart Auth Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Auth Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-auth-service
	@docker logs -f ecommerce-auth-service

rb-users: ## [113] Rebuild + restart Users Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Users Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-users-service
	@docker logs -f ecommerce-users-service

rb-inventory: ## [114] Rebuild + restart Inventory Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Inventory Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-inventory-service
	@docker logs -f ecommerce-inventory-service

rb-orders: ## [115] Rebuild + restart Order-Product Service
	@echo "$(COLOR_INFO)🔨 Rebuilding Order-Product Service...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate ecommerce-order-product-service
	@docker logs -f ecommerce-order-product-service

rb-all: ## [116] Rebuild + restart todos los microservicios
	@echo "$(COLOR_INFO)🔨 Rebuilding todos los servicios...$(COLOR_RESET)"
	@$(COMPOSE_DEV) up -d --build --force-recreate

logs-gateway: ## [117] Logs del API Gateway
	@docker logs -f ecommerce-api-gateway

logs-auth: ## [118] Logs del Auth Service
	@docker logs -f ecommerce-auth-service

logs-users: ## [119] Logs del Users Service
	@docker logs -f ecommerce-users-service

logs-inventory: ## [120] Logs del Inventory Service
	@docker logs -f ecommerce-inventory-service

logs-orders: ## [121] Logs del Order-Product Service
	@docker logs -f ecommerce-order-product-service

logs-localstack: ## [122] Logs de LocalStack
	@docker logs -f ecommerce-localstack

status: ## [123] Muestra el estado de todos los servicios
	@echo "$(COLOR_SUCCESS)📊 Estado de servicios:$(COLOR_RESET)\n"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep ecommerce || echo "No hay servicios corriendo"


1: help
20: shell-api-gateway
21: shell-auth
22: shell-localstack
23: prune
24: urls
30: start
31: start-infra
32: start-services
33: start-build
34: stop
35: clean
36: restart
40: test-health
41: lint
42: test
43: typecheck
44: verify
45: check-tools
46: preflight
50: cdk-install
51: cdk-diff
52: cdk-deploy
53: cdk-destroy
54: cdk-synth
60: aws-tables
61: aws-queues
62: aws-buckets
63: aws-health
64: aws-scan-users
70: seed-all
71: seed-mysql
72: seed-dynamodb
73: seed-inventory
74: seed-orders
80: db-users
81: db-inventory
82: db-orders
90: open
100: debug-gateway
101: debug-auth
102: debug-inventory
103: debug-orders
104: stop-debug-gateway
105: stop-debug-auth
106: stop-debug-inventory
107: stop-debug-orders
110: logs
111: rb-gateway
112: rb-auth
113: rb-users
114: rb-inventory
115: rb-orders
116: rb-all
117: logs-gateway
118: logs-auth
119: logs-users
120: logs-inventory
121: logs-orders
122: logs-localstack
123: status
