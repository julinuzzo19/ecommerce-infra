# 📊 Database Seeds - Resumen Ejecutivo

## 🎯 **Qué se ha creado**

Sistema completo de seedding para todas las bases de datos del proyecto con datos coherentes y relacionados entre sí.

## 📂 **Estructura Creada**

```
db-seeds/
├── master-data.json                     # ⭐ Fuente única de verdad
│   ├── users (5)                        # Usuarios con UUIDs fijos
│   └── products (10)                    # Productos con SKUs únicos
│
├── mysql-auth-seed.sql                  # SQL para auth_credentials
├── dynamodb-users-seed.js               # Script Node.js para DynamoDB
├── postgres-inventory-seed.sql          # SQL para productos + stock
├── postgres-order-product-seed.sql      # SQL completo (products, customers, orders, items)
│
├── scripts/
│   ├── seed-mysql.js                    # Ejecutor MySQL
│   ├── seed-inventory.js                # Ejecutor Inventory
│   └── seed-orders.js                   # Ejecutor Order-Product
│
├── seed-all.sh                          # 🚀 Script maestro
├── package.json                         # Dependencias + npm scripts
├── README.md                            # Documentación completa
└── .gitignore
```

## 🔗 **Coherencia de Datos**

### **UUIDs de Usuarios** (Consistentes entre MySQL y DynamoDB)

```
550e8400-e29b-41d4-a716-446655440001 → john.doe@example.com
550e8400-e29b-41d4-a716-446655440002 → jane.smith@example.com
550e8400-e29b-41d4-a716-446655440003 → admin@example.com
550e8400-e29b-41d4-a716-446655440004 → alice.johnson@example.com
550e8400-e29b-41d4-a716-446655440005 → bob.williams@example.com
```

- **MySQL `auth_credentials`**: Almacena credenciales con `userId`
- **DynamoDB `users`**: Almacena perfiles con mismo `id`
- **PostgreSQL `customers`**: Usa mismos UUIDs como `id`

### **SKUs de Productos** (Consistentes entre Inventory y Order-Product)

```
LAPTOP-DELL-XPS15
PHONE-IPHONE-14PRO
HEADPHONES-SONY-WH1000XM5
KEYBOARD-LOGITECH-MX
... (10 productos totales)
```

- **Inventory `products`**: SKU + stock_available + stock_reserved
- **Order-Product `products`**: SKU + nombre + descripción + precio + categoría

## 📊 **Datos por Base de Datos**

| Base de Datos | Tabla(s) | Registros | Descripción |
|---------------|----------|-----------|-------------|
| **MySQL** (users_db) | auth_credentials | 5 | Hashes de contraseñas (scrypt) |
| **DynamoDB** (users-service-db) | users | 5 | Perfiles de usuario (name, email, role, avatar) |
| **PostgreSQL** (inventory_db) | products | 10 | Stock disponible y reservado por SKU |
| **PostgreSQL** (order_product_db) | products | 10 | Catálogo completo de productos |
| | addresses | 5 | Direcciones de entrega |
| | customers | 5 | Clientes (mismo UUID que users) |
| | orders | 6 | Órdenes (PENDING, PAID, SHIPPED, CANCELLED) |
| | order_items | 13 | Items de cada orden |

## 🚀 **Cómo Usar**

### **Opción 1: Makefile** (Más simple)

```bash
make seed-all
```

### **Opción 2: Script directo**

```bash
cd db-seeds
./seed-all.sh
```

### **Opción 3: Seeds individuales**

```bash
make seed-mysql       # Solo MySQL
make seed-dynamodb    # Solo DynamoDB
make seed-inventory   # Solo Inventory
make seed-orders      # Solo Order-Product
```

## ✅ **Verificación Automática**

El script `seed-all.sh` incluye:

- ✅ Verificación de conectividad de bases de datos antes de empezar
- ✅ Instalación automática de dependencias npm
- ✅ Ejecución en orden correcto (respeta foreign keys)
- ✅ Resumen final con estadísticas

## 🔐 **Credenciales de Prueba**

Todos los usuarios usan la contraseña: **`password123`**

```bash
# Login con Auth Service
curl -X POST http://localhost:3010/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "john.doe@example.com", "password": "password123"}'
```

## 📈 **Datos de Negocio Insertados**

### **Estadísticas de Órdenes**

- **Total de órdenes**: 6
- **Por status**:
  - PENDING: 2
  - PAID: 2
  - SHIPPED: 1
  - CANCELLED: 1

### **Top 3 Productos Más Vendidos**

1. iPhone 14 Pro (2 unidades)
2. Webcam Logitech (2 unidades)
3. Charger Anker (3 unidades)

### **Stock Total**

- **Stock disponible**: 780 unidades
- **Stock reservado**: 54 unidades
- **Stock total**: 834 unidades

## 🧪 **Testing con los Datos**

```bash
# 1. Login y obtener JWT
TOKEN=$(curl -s -X POST http://localhost:3010/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "john.doe@example.com", "password": "password123"}' | jq -r '.token')

# 2. Obtener perfil de usuario
curl http://localhost:3012/users/550e8400-e29b-41d4-a716-446655440001 \
  -H "Authorization: Bearer $TOKEN"

# 3. Verificar stock
curl http://localhost:3011/inventory/check?sku=LAPTOP-DELL-XPS15

# 4. Crear orden
curl -X POST http://localhost:3600/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "550e8400-e29b-41d4-a716-446655440001",
    "items": [{"sku": "LAPTOP-DELL-XPS15", "quantity": 1}]
  }'
```

## 🔄 **Re-seeding**

Los scripts usan `TRUNCATE TABLE` para limpiar antes de insertar, así que puedes re-ejecutar cuantas veces quieras:

```bash
make seed-all
```

**⚠️ IMPORTANTE**: Esto eliminará TODOS los datos existentes en las tablas.

## 📚 **Integración con el Proyecto**

### **Makefile**

Se han agregado nuevos targets:

```makefile
make seed-all        # Todos los seeds
make seed-mysql      # Solo MySQL
make seed-dynamodb   # Solo DynamoDB
make seed-inventory  # Solo Inventory
make seed-orders     # Solo Order-Product
```

### **Flujo de Trabajo Típico**

```bash
# 1. Iniciar entorno
make start

# 2. Esperar a que servicios estén listos
sleep 30

# 3. Poblar bases de datos
make seed-all

# 4. Empezar a desarrollar/testear
curl http://localhost:3000/health
```

## 🎯 **Próximos Pasos Sugeridos**

1. ✅ Ejecutar `make seed-all` para poblar las bases de datos
2. ✅ Verificar que los datos se insertaron correctamente
3. ✅ Probar flujos end-to-end:
   - Login → Obtener perfil → Crear orden → Verificar stock
4. ✅ Verificar que los eventos de RabbitMQ se publiquen cuando se crean órdenes
5. ✅ Monitorear en Grafana las métricas de los servicios

## 🐛 **Troubleshooting Común**

### **"Connection refused"**

```bash
# Levantar servicios primero
make start
```

### **"Table doesn't exist"**

```bash
# Las migraciones deben ejecutarse primero
docker-compose -f docker-compose-dev.yml restart
```

### **"Cannot find module"**

```bash
cd db-seeds
npm install
```

---

**¿Listo para comenzar?**

```bash
make start     # Levanta todo
make seed-all  # Puebla las bases de datos
```

🎉 **¡Y tienes un entorno completo con datos de prueba!**
