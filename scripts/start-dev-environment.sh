#!/bin/bash
set -e

# ============================================
# CONFIGURACIÓN
# ============================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
# PASO 4: BOOTSTRAP CDK (SI ES NECESARIO)
# ============================================

if [ "$SKIP_CDK" = false ]; then
    print_step "Paso 4: Bootstrap de AWS CDK en LocalStack"

    cd "$CDK_DIR"

    # Configurar variables de entorno para LocalStack
    export AWS_REGION=us-east-1
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export AWS_ENDPOINT_URL=http://localhost:4566
    export STAGE=dev

    print_info "Ejecutando CDK bootstrap contra LocalStack..."
    print_info "Endpoint: http://localhost:4566"

    # Ejecutar bootstrap (puede fallar si ya está hecho, es normal)
    if npm run bootstrap > /dev/null 2>&1; then
        print_success "Bootstrap completado exitosamente"
    else
        print_warning "Bootstrap falló o ya estaba hecho (esto es normal si ya corriste el script antes)"
    fi
fi

# ============================================
# PASO 5: DESPLEGAR INFRAESTRUCTURA CON CDK
# ============================================

if [ "$SKIP_CDK" = false ]; then
    print_step "Paso 5: Desplegando infraestructura con CDK"

    cd "$CDK_DIR"

    print_info "Ejecutando CDK diff para ver cambios..."
    npm run diff

    echo ""
    read -p "¿Deseas desplegar la infraestructura? (y/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Desplegando stack..."
        npm run deploy -- --require-approval never
        print_success "Infraestructura desplegada exitosamente"
    else
        print_info "Deployment cancelado por el usuario"
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

echo ""
echo -e "${COLOR_INFO}🛠️  COMANDOS ÚTILES:${COLOR_RESET}"
echo "  • Ver logs LocalStack:     docker logs -f ecommerce-localstack"
echo "  • Ver todos los logs:      docker-compose -f docker-compose-dev.yml logs -f"
echo "  • Detener todo:            ./stop-dev-environment.sh"
echo "  • Ver recursos LocalStack: aws --endpoint-url=http://localhost:4566 dynamodb list-tables"

echo ""
echo -e "${COLOR_SUCCESS}✨ Para más información, consulta el README.md en infrastructure-cdk/${COLOR_RESET}"
echo ""
