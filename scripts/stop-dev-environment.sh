#!/bin/bash
set -e

# ============================================
# CONFIGURACIÓN
# ============================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
COLOR_SUCCESS="\033[0;32m"
COLOR_INFO="\033[0;36m"
COLOR_WARNING="\033[0;33m"
COLOR_RESET="\033[0m"

# Flags
CLEAN=false
ONLY_LOCALSTACK=false

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

# ============================================
# PROCESAR ARGUMENTOS
# ============================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN=true
            shift
            ;;
        --only-localstack)
            ONLY_LOCALSTACK=true
            shift
            ;;
        -h|--help)
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --clean              Elimina volúmenes de Docker (pérdida de datos)"
            echo "  --only-localstack    Solo detiene LocalStack"
            echo "  -h, --help           Muestra esta ayuda"
            exit 0
            ;;
        *)
            print_warning "Argumento desconocido: $1"
            shift
            ;;
    esac
done

# ============================================
# DETENER SERVICIOS
# ============================================

cd "$PROJECT_ROOT"

if [ "$ONLY_LOCALSTACK" = false ]; then
    print_step "Deteniendo microservicios"

    if [ "$CLEAN" = true ]; then
        print_warning "Modo CLEAN activado - Se eliminarán todos los volúmenes"
        docker-compose -f docker-compose-dev.yml down -v
    else
        docker-compose -f docker-compose-dev.yml down
    fi

    print_success "Microservicios detenidos"
fi

print_step "Deteniendo LocalStack"

if [ "$CLEAN" = true ]; then
    docker-compose -f docker-compose.localstack.yml down -v
else
    docker-compose -f docker-compose.localstack.yml down
fi

print_success "LocalStack detenido"

# ============================================
# RESUMEN
# ============================================

echo ""
echo -e "${COLOR_SUCCESS}🛑 Entorno de desarrollo detenido${COLOR_RESET}"

if [ "$CLEAN" = true ]; then
    echo ""
    print_warning "Se han eliminado todos los volúmenes (datos perdidos)"
    print_info "La próxima vez que inicies el entorno, será desde cero"
else
    echo ""
    print_info "Los volúmenes se han preservado"
    print_info "La próxima vez que inicies el entorno, los datos estarán intactos"
fi

echo ""
