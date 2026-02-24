#!/bin/bash

# ============================================
# Master Seed Script
# Ejecuta todos los seeds en el orden correcto
# ============================================

set -e  # Exit on error

# Colores
COLOR_SUCCESS="\033[0;32m"
COLOR_INFO="\033[0;36m"
COLOR_ERROR="\033[0;31m"
COLOR_RESET="\033[0m"

print_header() {
    echo -e "\n${COLOR_INFO}========================================${COLOR_RESET}"
    echo -e "${COLOR_INFO}  $1${COLOR_RESET}"
    echo -e "${COLOR_INFO}========================================${COLOR_RESET}\n"
}

print_success() {
    echo -e "${COLOR_SUCCESS}✅ $1${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_ERROR}❌ $1${COLOR_RESET}"
}

# Cambiar al directorio del script
cd "$(dirname "$0")"

print_header "🌱 Ecommerce Database Seeding"

# Verificar que las bases de datos estén disponibles
echo "🔍 Verificando conectividad de bases de datos..."

# MySQL
if ! nc -z localhost 3307 2>/dev/null; then
    print_error "MySQL no está disponible en localhost:3307"
    print_error "Asegúrate de que docker-compose esté corriendo"
    exit 1
fi
print_success "MySQL disponible"

# PostgreSQL Inventory
if ! nc -z localhost 5434 2>/dev/null; then
    print_error "PostgreSQL (Inventory) no está disponible en localhost:5434"
    exit 1
fi
print_success "PostgreSQL (Inventory) disponible"

# PostgreSQL Order-Product
if ! nc -z localhost 5432 2>/dev/null; then
    print_error "PostgreSQL (Order-Product) no está disponible en localhost:5432"
    exit 1
fi
print_success "PostgreSQL (Order-Product) disponible"

# DynamoDB
if ! curl -s http://localhost:4566 > /dev/null 2>&1; then
    print_error "DynamoDB Local no está disponible en http://localhost:4566"
    exit 1
fi
print_success "DynamoDB Local disponible"

echo ""

# Instalar dependencias si no existen
if [ ! -d "node_modules" ]; then
    print_header "📦 Instalando dependencias"
    npm install
fi

# Ejecutar seeds en orden
print_header "1️⃣  Seeding MySQL (Auth Credentials)"
npm run seed:mysql

print_header "2️⃣  Seeding DynamoDB (Users)"
npm run seed:dynamodb

print_header "3️⃣  Seeding PostgreSQL (Inventory)"
npm run seed:inventory

print_header "4️⃣  Seeding PostgreSQL (Order-Product)"
npm run seed:orders

# Resumen final
print_header "✨ Resumen de Seeding"

echo -e "${COLOR_SUCCESS}Todas las bases de datos han sido pobladas exitosamente!${COLOR_RESET}\n"

echo "📊 Datos insertados:"
echo "  • MySQL (Auth):        5 usuarios con credenciales"
echo "  • DynamoDB (Users):    5 usuarios con perfiles"
echo "  • PostgreSQL (Inv):    10 productos con stock"
echo "  • PostgreSQL (Orders): 10 productos, 5 clientes, 6 órdenes"
echo ""

echo "🔐 Credenciales de prueba (todos usan password: password123):"
echo "  • john.doe@example.com    (USER)"
echo "  • jane.smith@example.com  (USER)"
echo "  • admin@example.com       (ADMIN)"
echo "  • alice.johnson@example.com (USER)"
echo "  • bob.williams@example.com  (USER)"
echo ""

echo "💡 Puedes verificar los datos con:"
echo "  • MySQL:     docker exec -it ecommerce-users-db mysql -uroot -proot users_db"
echo "  • DynamoDB:  aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name users-service-db"
echo "  • Inventory: docker exec -it ecommerce-inventory-db psql -U root -d inventory_db"
echo "  • Orders:    docker exec -it ecommerce-order-product-db psql -U root -d order_product_db"
echo ""

print_success "Seeding completado! 🎉"
