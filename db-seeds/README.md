# 🌱 Database Seeds - Ecommerce Microservices

Scripts de inicialización de bases de datos con datos de prueba coherentes entre todos los servicios.

## 📋 **Qué hace esto**

Puebla todas las bases de datos del proyecto con datos ficticios pero coherentes:

- **MySQL (Auth Service)**: Credenciales de autenticación
- **DynamoDB (Users Service)**: Perfiles de usuario
- **PostgreSQL (Inventory)**: Productos con stock disponible y reservado
- **PostgreSQL (Order-Product)**: Productos, clientes, direcciones, órdenes y order items

**Importante**: Los UUIDs de usuarios son consistentes entre MySQL y DynamoDB, y los SKUs de productos son consistentes entre Inventory y Order-Product.

## 🚀 **Uso Rápido**

### Opción 1: Script Todo-en-Uno (Recomendado)

```bash
cd db-seeds
./seed-all.sh
```

Este script:
1. ✅ Verifica que todas las bases de datos estén disponibles
2. ✅ Instala dependencias de npm si es necesario
3. ✅ Ejecuta todos los seeds en el orden correcto
4. ✅ Muestra un resumen de lo insertado

### Opción 2: Seeds Individuales

```bash
cd db-seeds
npm install

# MySQL (Auth)
npm run seed:mysql

# DynamoDB (Users)
npm run seed:dynamodb

# PostgreSQL (Inventory)
npm run seed:inventory

# PostgreSQL (Order-Product)
npm run seed:orders
```

## 📊 **Datos Insertados**

### 👥 Usuarios (5)

Todos usan la contraseña: `password123`

| Email | Nombre | Role | UUID |
|-------|--------|------|------|
| john.doe@example.com | John Doe | USER | 550e8400-e29b-41d4-a716-446655440001 |
| jane.smith@example.com | Jane Smith | USER | 550e8400-e29b-41d4-a716-446655440002 |
| admin@example.com | Admin User | ADMIN | 550e8400-e29b-41d4-a716-446655440003 |
| alice.johnson@example.com | Alice Johnson | USER | 550e8400-e29b-41d4-a716-446655440004 |
| bob.williams@example.com | Bob Williams | USER | 550e8400-e29b-41d4-a716-446655440005 |

### 📦 Productos (10)

| SKU | Nombre | Precio | Stock Disponible | Stock Reservado |
|-----|--------|--------|------------------|-----------------|
| LAPTOP-DELL-XPS15 | Dell XPS 15 | $1,499.99 | 25 | 3 |
| PHONE-IPHONE-14PRO | iPhone 14 Pro | $999.99 | 50 | 5 |
| HEADPHONES-SONY-WH1000XM5 | Sony WH-1000XM5 | $399.99 | 100 | 10 |
| KEYBOARD-LOGITECH-MX | Logitech MX Keys | $99.99 | 75 | 2 |
| MOUSE-LOGITECH-MX3 | Logitech MX Master 3 | $99.99 | 80 | 4 |
| MONITOR-DELL-U2720Q | Dell UltraSharp 27 4K | $599.99 | 30 | 1 |
| WEBCAM-LOGITECH-C920 | Logitech C920 HD Pro | $79.99 | 120 | 8 |
| TABLET-IPAD-AIR | iPad Air | $599.99 | 40 | 6 |
| SPEAKER-SONOS-ONE | Sonos One | $199.99 | 60 | 0 |
| CHARGER-ANKER-65W | Anker 65W USB-C Charger | $49.99 | 200 | 15 |

### 📝 Órdenes (6)

| Order Number | Cliente | Status | Items | Total |
|--------------|---------|--------|-------|-------|
| ORD-2024-001 | John Doe | PAID | 2 (Laptop, Mouse) | $1,599.98 |
| ORD-2024-002 | Jane Smith | SHIPPED | 2 (iPhone, Headphones) | $1,399.98 |
| ORD-2024-003 | John Doe | PENDING | 3 (Monitor, Keyboard, Webcam x2) | $859.96 |
| ORD-2024-004 | Alice Johnson | PAID | 2 (iPad, Charger x3) | $749.96 |
| ORD-2024-005 | Bob Williams | PENDING | 1 (Speaker) | $199.99 |
| ORD-2024-006 | Jane Smith | CANCELLED | 1 (iPhone) | $999.99 |

## 🔧 **Configuración**

### Variables de Entorno

Puedes customizar las conexiones con variables de entorno:

```bash
# MySQL
export MYSQL_HOST=localhost
export MYSQL_PORT=3307
export MYSQL_USER=root
export MYSQL_PASSWORD=root
export MYSQL_DATABASE=users_db

# DynamoDB
export DYNAMODB_ENDPOINT=http://localhost:8000
export USERS_TABLE=users-service-db
export AWS_REGION=us-east-1

# PostgreSQL Inventory
export POSTGRES_INVENTORY_HOST=localhost
export POSTGRES_INVENTORY_PORT=5434
export POSTGRES_INVENTORY_USER=root
export POSTGRES_INVENTORY_PASSWORD=root
export POSTGRES_INVENTORY_DATABASE=inventory_db

# PostgreSQL Order-Product
export POSTGRES_ORDER_HOST=localhost
export POSTGRES_ORDER_PORT=5432
export POSTGRES_ORDER_USER=root
export POSTGRES_ORDER_PASSWORD=root
export POSTGRES_ORDER_DATABASE=order_product_db
```

## 📂 **Estructura de Archivos**

```
db-seeds/
├── master-data.json                    # Datos maestros (usuarios y productos)
├── mysql-auth-seed.sql                 # Seed SQL para MySQL
├── dynamodb-users-seed.js              # Seed para DynamoDB
├── postgres-inventory-seed.sql         # Seed SQL para Inventory
├── postgres-order-product-seed.sql     # Seed SQL para Order-Product
├── scripts/
│   ├── seed-mysql.js                   # Ejecutor de seed MySQL
│   ├── seed-inventory.js               # Ejecutor de seed Inventory
│   └── seed-orders.js                  # Ejecutor de seed Orders
├── seed-all.sh                         # Script maestro (ejecuta todos)
├── package.json
└── README.md
```

## 🔍 **Verificar los Datos**

### MySQL (Auth Credentials)

```bash
# Opción 1: CLI
docker exec -it ecommerce-users-db mysql -uroot -proot users_db -e "SELECT userId, LEFT(password, 30) as password_preview FROM auth_credentials;"

# Opción 2: Shell interactiva
docker exec -it ecommerce-users-db mysql -uroot -proot users_db
```

### DynamoDB (Users)

```bash
# Listar todos los usuarios
aws --endpoint-url=http://localhost:8000 dynamodb scan --table-name users-service-db

# Buscar usuario por ID
aws --endpoint-url=http://localhost:8000 dynamodb get-item \
  --table-name users-service-db \
  --key '{"id": {"S": "550e8400-e29b-41d4-a716-446655440001"}}'
```

### PostgreSQL Inventory

```bash
# CLI
docker exec -it ecommerce-inventory-db psql -U root -d inventory_db -c "SELECT sku, stock_available, stock_reserved FROM products;"

# Shell interactiva
docker exec -it ecommerce-inventory-db psql -U root -d inventory_db
```

### PostgreSQL Order-Product

```bash
# CLI - Ver órdenes
docker exec -it ecommerce-order-product-db psql -U root -d order_product_db -c "SELECT o.\"orderNumber\", c.name, o.status, COUNT(oi.id) as items FROM orders o JOIN customers c ON o.\"customerId\" = c.id LEFT JOIN order_items oi ON o.\"orderNumber\" = oi.\"orderNumber\" GROUP BY o.id, c.name;"

# Shell interactiva
docker exec -it ecommerce-order-product-db psql -U root -d order_product_db
```

## 🧪 **Testing con los Datos**

### Hacer login con Auth Service

```bash
curl -X POST http://localhost:3010/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "password": "password123"
  }'
```

### Obtener usuario desde Users Service

```bash
curl http://localhost:3012/users/550e8400-e29b-41d4-a716-446655440001
```

### Verificar stock en Inventory

```bash
curl http://localhost:3011/inventory/check?sku=LAPTOP-DELL-XPS15
```

### Crear una orden

```bash
curl -X POST http://localhost:3600/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "550e8400-e29b-41d4-a716-446655440001",
    "items": [
      {"sku": "LAPTOP-DELL-XPS15", "quantity": 1}
    ]
  }'
```

## 🔄 **Re-seed (Limpiar y Volver a Poblar)**

Los scripts de seed automáticamente limpian las tablas antes de insertar datos (usando `TRUNCATE`).

Simplemente vuelve a ejecutar:

```bash
./seed-all.sh
```

## ⚠️ **Importante**

1. **Solo para desarrollo**: Estos scripts usan `TRUNCATE` para limpiar las tablas. ¡NUNCA los ejecutes en producción!

2. **Contraseñas**: Todas las contraseñas son `password123`. Los hashes de scrypt en el seed son ejemplos ficticios.

3. **UUIDs fijos**: Los UUIDs están hardcodeados para mantener consistencia entre servicios. En un entorno real, se generarían dinámicamente.

4. **Foreign Keys**: Los scripts respetan el orden de inserción para no violar foreign key constraints.

## 🐛 **Troubleshooting**

### Error: "Connection refused"

**Causa**: Las bases de datos no están corriendo.

**Solución**:
```bash
# Levantar todo el entorno
cd ..
docker-compose -f docker-compose-dev.yml up -d

# O usar el script de inicio
./scripts/start-dev-environment.sh
```

### Error: "Cannot find module"

**Causa**: Dependencias de npm no instaladas.

**Solución**:
```bash
cd db-seeds
npm install
```

### Error: "Table doesn't exist"

**Causa**: Las migraciones no se han ejecutado.

**Solución**: Asegúrate de que los servicios se hayan iniciado correctamente y las migraciones se hayan ejecutado:

```bash
# Reiniciar servicios
docker-compose -f docker-compose-dev.yml restart
```

### Error: "Duplicate entry" o "Unique constraint violation"

**Causa**: Los datos ya existen.

**Solución**: Los scripts usan `TRUNCATE`, así que esto no debería pasar. Si sucede, limpia manualmente:

```bash
# MySQL
docker exec -it ecommerce-users-db mysql -uroot -proot users_db -e "TRUNCATE TABLE auth_credentials;"

# PostgreSQL Inventory
docker exec -it ecommerce-inventory-db psql -U root -d inventory_db -c "TRUNCATE TABLE products CASCADE;"

# PostgreSQL Order-Product
docker exec -it ecommerce-order-product-db psql -U root -d order_product_db -c "TRUNCATE TABLE order_items, orders, customers, addresses, products CASCADE;"
```

## 📚 **Próximos Pasos**

Después de hacer el seeding:

1. Prueba los endpoints de los servicios
2. Verifica que la autenticación funcione con los usuarios seed
3. Crea órdenes de prueba
4. Verifica que los eventos de RabbitMQ se publiquen correctamente
5. Monitorea en Grafana las métricas de los servicios

---

**Happy seeding! 🌱**
