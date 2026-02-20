#!/bin/bash
set -e

# ============================================
# CONFIGURACIÓN
# ============================================

# Directorio raíz del proyecto (un nivel arriba de scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CDK_DIR="$PROJECT_ROOT/infrastructure-cdk"

# Colores
COLOR_SUCCESS="\033[0;32m"
COLOR_INFO="\033[0;36m"
COLOR_WARNING="\033[0;33m"
COLOR_ERROR="\033[0;31m"
COLOR_RESET="\033[0m"

# Flags
SKIP_CDK=false
ONLY_INFRASTRUCTURE=false
BUILD=false

# ============================================
# FUNCIONES AUXILIARES
# ============================================

print_step() {
    echo -e "\n${COLOR_INFO}========================================${COLOR_RESET}"
    echo -e "${COLOR_INFO}  $1${COLOR_RESET}"
    echo -e "${COLOR_INFO}========================================${COLOR_RESET}\n"
}

print_success() {
    echo -e "${COLOR_SUCCESS}✅ $1${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_INFO}ℹ️  $1${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_WARNING}⚠️  $1${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_ERROR}❌ $1${COLOR_RESET}"
}

wait_for_service() {
    local service_name=$1
    local url=$2
    local max_retries=${3:-30}
    local retry_delay=${4:-2}

    print_info "Esperando a que $service_name esté listo..."

    for ((i=1; i<=max_retries; i++)); do
        if curl -sf "$url" > /dev/null 2>&1; then
            print_success "$service_name está listo!"
            return 0
        fi
        echo -n "."
        sleep "$retry_delay"
    done

    print_warning "$service_name no respondió después de $max_retries intentos"
    return 1
}

# ============================================
# PROCESAR ARGUMENTOS
# ============================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-cdk)
            SKIP_CDK=true
            shift
            ;;
        --only-infrastructure)
            ONLY_INFRASTRUCTURE=true
            shift
            ;;
        --build)
            BUILD=true
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --skip-cdk              No ejecuta pasos de CDK"
            echo "  --only-infrastructure   Solo levanta LocalStack y CDK"
            echo "  --build                 Reconstruye las imágenes de Docker"
            echo "  -h, --help              Muestra esta ayuda"
            exit 0
            ;;
        *)
            print_error "Argumento desconocido: $1"
            exit 1
            ;;
    esac
done

# ============================================
# VALIDACIONES PREVIAS
# ============================================

print_step "Validando requisitos previos"

# Verificar Docker
if ! docker info > /dev/null 2>&1; then
    print_error "Docker no está corriendo. Por favor inicia Docker."
    exit 1
fi
print_success "Docker está corriendo"

# Verificar Node.js
if ! command -v node > /dev/null 2>&1; then
    print_error "Node.js no está instalado. Instala Node.js 20+ desde https://nodejs.org"
    exit 1
fi
NODE_VERSION=$(node --version)
print_success "Node.js instalado: $NODE_VERSION"

# Verificar npm
if ! command -v npm > /dev/null 2>&1; then
    print_error "npm no está disponible"
    exit 1
fi
NPM_VERSION=$(npm --version)
print_success "npm instalado: v$NPM_VERSION"

# ============================================
# PASO 1: LEVANTAR LOCALSTACK
# ============================================

print_step "Paso 1: Levantando LocalStack"

cd "$PROJECT_ROOT"

BUILD_FLAG=""
if [ "$BUILD" = true ]; then
    BUILD_FLAG="--build"
fi

print_info "Ejecutando: docker-compose -f docker-compose.localstack.yml up -d $BUILD_FLAG"
docker-compose -f docker-compose.localstack.yml up -d $BUILD_FLAG

print_success "LocalStack iniciado"

# Esperar a que LocalStack esté listo
if ! wait_for_service "LocalStack" "http://localhost:4566/_localstack/health" 30; then
    print_error "LocalStack no está respondiendo. Verifica los logs con: docker logs ecommerce-localstack"
    exit 1
fi

# ============================================
# PASO 2: LEVANTAR SERVICIOS (OPCIONAL)
# ============================================

if [ "$ONLY_INFRASTRUCTURE" = false ]; then
    print_step "Paso 2: Levantando microservicios"

    print_info "Ejecutando: docker-compose -f docker-compose-dev.yml up -d $BUILD_FLAG"
    docker-compose -f docker-compose-dev.yml up -d $BUILD_FLAG

    print_success "Microservicios iniciados"

    print_info "Esperando a que los servicios estén saludables (esto puede tomar 1-2 minutos)..."
    sleep 10
else
    print_info "Saltando inicio de microservicios (modo solo infraestructura)"
fi

# ============================================
# PASO 3: INSTALAR DEPENDENCIAS CDK
# ============================================

if [ "$SKIP_CDK" = false ]; then
    print_step "Paso 3: Instalando dependencias de CDK"

    cd "$CDK_DIR"

    if [ ! -d "node_modules" ]; then
        print_info "Instalando dependencias de npm..."
        npm install
        print_success "Dependencias instaladas"
    else
        print_success "Dependencias ya instaladas"
    fi
fi

# ============================================
# PASO 4: CREAR INFRAESTRUCTURA AWS
# ============================================
# Para desarrollo local (LocalStack): usa script directo de AWS CLI
# Para producción (AWS real): usa AWS CDK

if [ "$SKIP_CDK" = false ]; then
    # Determinar entorno
    STAGE="${STAGE:-dev}"

    if [ "$STAGE" = "dev" ] || [ "$STAGE" = "local" ]; then
        # ====================================
        # DESARROLLO LOCAL - LocalStack
        # ====================================
        print_step "Paso 4: Creando tabla DynamoDB en LocalStack"

        export AWS_REGION=us-east-1
        export AWS_ACCESS_KEY_ID=test
        export AWS_SECRET_ACCESS_KEY=test
        export AWS_ENDPOINT_URL=http://localhost:4566

        print_info "Entorno: DESARROLLO LOCAL (LocalStack)"
        print_info "Método: AWS CLI directo (más simple que CDK para LocalStack)"
        echo ""
        print_warning "⚠️  CDK NO se ejecuta en desarrollo local"
        print_info "    Para producción: export STAGE=prod && ./scripts/start-dev-environment.sh"
        echo ""

        # Ejecutar script de creación de tabla
        if "$CDK_DIR/scripts/create-dynamodb-table.sh"; then
            print_success "Tabla DynamoDB lista en LocalStack"
        else
            print_error "Error creando tabla DynamoDB"
            exit 1
        fi
    else
        # ====================================
        # PRODUCCIÓN - AWS Real
        # ====================================
        print_step "Paso 4: Desplegando infraestructura con AWS CDK"

        export AWS_REGION="${AWS_REGION:-us-east-1}"
        export CDK_DEFAULT_ACCOUNT="${AWS_ACCOUNT_ID:-}"
        export CDK_DEFAULT_REGION="$AWS_REGION"

        print_info "Entorno: PRODUCCIÓN (AWS Real)"
        print_info "Método: AWS CDK (Infrastructure as Code)"
        print_info "Stage: $STAGE"
        print_info "Región: $AWS_REGION"
        echo ""

        # Verificar credenciales de AWS
        if [ -z "$AWS_ACCOUNT_ID" ]; then
            print_warning "AWS_ACCOUNT_ID no está definido"
            print_info "Intentando obtener de AWS CLI..."
            AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

            if [ -z "$AWS_ACCOUNT_ID" ]; then
                print_error "No se pudo obtener AWS Account ID"
                print_error "Configura tus credenciales: aws configure"
                exit 1
            fi

            export CDK_DEFAULT_ACCOUNT="$AWS_ACCOUNT_ID"
            print_success "AWS Account ID: $AWS_ACCOUNT_ID"
        fi

        cd "$CDK_DIR"

        # Bootstrap CDK (solo si es necesario)
        print_info "Verificando bootstrap de CDK..."
        if ! aws cloudformation describe-stacks --stack-name CDKToolkit >/dev/null 2>&1; then
            print_warning "CDK no está bootstrapped en esta cuenta/región"
            echo ""
            read -p "¿Deseas ejecutar CDK bootstrap ahora? (y/N): " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Ejecutando CDK bootstrap..."
                npm run bootstrap
                print_success "Bootstrap completado"
            else
                print_error "Bootstrap cancelado - no se puede continuar sin bootstrap"
                exit 1
            fi
        else
            print_success "CDK ya está bootstrapped"
        fi

        # Deploy con CDK
        echo ""
        print_info "Ejecutando CDK diff..."
        npm run diff || print_warning "No hay cambios o primera vez"

        echo ""
        read -p "¿Deseas desplegar la infraestructura a AWS? (y/N): " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Desplegando stack UsersServiceStack..."
            npm run deploy -- --require-approval never
            print_success "Infraestructura desplegada exitosamente en AWS"
        else
            print_info "Deployment cancelado por el usuario"
        fi

        cd "$PROJECT_ROOT"
    fi
fi

# ============================================
# PASO 6: EJECUTAR SEEDS DE BASES DE DATOS
# ============================================

if [ "$ONLY_INFRASTRUCTURE" = false ]; then
    print_step "Paso 6: Poblando bases de datos con seeds"

    cd "$PROJECT_ROOT"

    # Esperar unos segundos más para asegurar que las DBs están completamente listas
    print_info "Esperando a que las bases de datos estén completamente listas..."
    sleep 15

    # Ejecutar seeds
    print_info "Ejecutando seed-all.sh..."
    if cd db-seeds && ./seed-all.sh; then
        print_success "Seeds ejecutados exitosamente"
        cd "$PROJECT_ROOT"
    else
        print_warning "Error ejecutando seeds. Puedes ejecutarlos manualmente con: make seed-all"
        cd "$PROJECT_ROOT"
    fi
fi

# ============================================
# RESUMEN FINAL
# ============================================

print_step "Resumen del entorno"

echo ""
echo -e "${COLOR_SUCCESS}🎉 Entorno de desarrollo iniciado exitosamente!${COLOR_RESET}"
echo ""

echo -e "${COLOR_INFO}📦 SERVICIOS DE INFRAESTRUCTURA:${COLOR_RESET}"
echo "  • LocalStack:          http://localhost:4566"
echo "  • LocalStack Health:   http://localhost:4566/_localstack/health"

if [ "$ONLY_INFRASTRUCTURE" = false ]; then
    echo ""
    echo -e "${COLOR_INFO}🚀 MICROSERVICIOS:${COLOR_RESET}"
    echo "  • API Gateway:         http://localhost:3000"
    echo "  • Auth Service:        http://localhost:3010"
    echo "  • Users Service:       http://localhost:3012"
    echo "  • Inventory Service:   http://localhost:3011"
    echo "  • Order-Product:       http://localhost:3600"

    echo ""
    echo -e "${COLOR_INFO}💾 BASES DE DATOS:${COLOR_RESET}"
    echo "  • MySQL (Users):       localhost:3307"
    echo "  • DynamoDB Local:      http://localhost:8000"
    echo "  • PostgreSQL (Inv):    localhost:5434"
    echo "  • PostgreSQL (Order):  localhost:5432"

    echo ""
    echo -e "${COLOR_INFO}📊 OBSERVABILIDAD:${COLOR_RESET}"
    echo "  • Grafana:             http://localhost:3001 (admin/admin)"
    echo "  • Prometheus:          http://localhost:9090"
    echo "  • RabbitMQ Management: http://localhost:15672 (user/password)"
fi

if [ "$ONLY_INFRASTRUCTURE" = false ]; then
    echo ""
    echo -e "${COLOR_INFO}🌱 DATOS DE PRUEBA:${COLOR_RESET}"
    echo "  • 5 usuarios creados (password: password123)"
    echo "  • 10 productos con stock"
    echo "  • 6 órdenes de ejemplo"
    echo ""
    echo "  Login de prueba:"
    echo "    Email: john.doe@example.com"
    echo "    Password: password123"
fi

echo ""
echo -e "${COLOR_INFO}🛠️  COMANDOS ÚTILES:${COLOR_RESET}"
echo "  • Ver logs LocalStack:     docker logs -f ecommerce-localstack"
echo "  • Ver todos los logs:      docker-compose -f docker-compose-dev.yml logs -f"
echo "  • Detener todo:            ./stop-dev-environment.sh"
echo "  • Re-poblar datos:         make seed-all"
echo "  • Ver recursos LocalStack: aws --endpoint-url=http://localhost:4566 dynamodb list-tables"

echo ""
echo -e "${COLOR_SUCCESS}✨ Para más información, consulta el README.md en infrastructure-cdk/${COLOR_RESET}"
echo ""
