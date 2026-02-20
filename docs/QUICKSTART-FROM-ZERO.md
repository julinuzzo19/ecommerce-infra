# 🚀 Quickstart - Desde Cero

Guía completa para levantar el entorno de desarrollo desde 0.

---

## ✅ Pre-requisitos

- **Docker Desktop** corriendo
- **Node.js 20+** instalado
- **AWS CLI** (opcional, para verificar recursos)
- **Make** (opcional, pero recomendado)

---

## 🎯 Flujo Completo Automatizado

### **Opción 1: Un Solo Comando (Recomendado)**

```bash
make start
```

**Qué hace:**
1. ✅ Levanta **LocalStack** (AWS emulado localmente)
2. ✅ Levanta todos los **microservicios** (Gateway, Auth, Users, Inventory, Order-Product)
3. ✅ Levanta **bases de datos** (MySQL, PostgreSQL, DynamoDB)
4. ✅ Levanta **infraestructura** (RabbitMQ, Grafana, Prometheus, Tempo, Loki)
5. ✅ Ejecuta **migraciones** automáticamente (TypeORM + Prisma)
6. ✅ Despliega **tabla DynamoDB** vía AWS CDK en LocalStack
7. ✅ **Puebla bases de datos** con datos de prueba (users, productos, órdenes)

**Tiempo estimado:** 2-3 minutos

---

### **Opción 2: Paso a Paso Manual**

Si prefieres ver cada paso:

```bash
# 1. Levantar LocalStack
docker-compose -f docker-compose.localstack.yml up -d

# 2. Levantar microservicios
docker-compose -f docker-compose-dev.yml up -d

# 3. Esperar a que todo esté listo (1-2 minutos)
sleep 60

# 4. Desplegar infraestructura con CDK
cd infrastructure-cdk
npm install
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_ENDPOINT_URL=http://localhost:4566
export STAGE=dev
npm run deploy -- --require-approval never
cd ..

# 5. Poblar bases de datos
make seed-all
```

---

## 📊 ¿Qué Datos se Crean?

Después de ejecutar `make start`, tendrás:

### **👥 Usuarios (5)**

Todos con contraseña: `password123`

| Email | Role | UUID |
|-------|------|------|
| john.doe@example.com | USER | 550e8400-e29b-41d4-a716-446655440001 |
| jane.smith@example.com | USER | 550e8400-e29b-41d4-a716-446655440002 |
| admin@example.com | ADMIN | 550e8400-e29b-41d4-a716-446655440003 |
| alice.johnson@example.com | USER | 550e8400-e29b-41d4-a716-446655440004 |
| bob.williams@example.com | USER | 550e8400-e29b-41d4-a716-446655440005 |

### **📦 Productos (10)**

| SKU | Nombre | Precio | Stock Disponible |
|-----|--------|--------|------------------|
| LAPTOP-DELL-XPS15 | Dell XPS 15 | $1,499.99 | 25 |
| PHONE-IPHONE-14PRO | iPhone 14 Pro | $999.99 | 50 |
| HEADPHONES-SONY-WH1000XM5 | Sony WH-1000XM5 | $399.99 | 100 |
| ... | ... | ... | ... |

### **📝 Órdenes (6)**

- 2 PENDING
- 2 PAID
- 1 SHIPPED
- 1 CANCELLED

---

## 🧪 Verificar que Todo Funciona

### **1. Health Check de Servicios**

```bash
make test-health
```

O manualmente:

```bash
curl http://localhost:3000/health  # API Gateway
curl http://localhost:3010/health  # Auth Service
curl http://localhost:3011/health  # Inventory Service
curl http://localhost:3012/health  # Users Service
curl http://localhost:3600/health  # Order-Product Service
```

### **2. Login y Obtener JWT**

```bash
curl -X POST http://localhost:3010/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john.doe@example.com",
    "password": "password123"
  }'
```

**Respuesta esperada:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": "550e8400-e29b-41d4-a716-446655440001"
}
```

### **3. Verificar Datos en Bases de Datos**

```bash
# MySQL (Auth Credentials)
docker exec -it ecommerce-users-db mysql -uuser -puser users_db \
  -e "SELECT userId, email FROM auth_credentials LIMIT 5;"

# DynamoDB (Users)
aws --endpoint-url=http://localhost:4566 dynamodb scan \
  --table-name users-service-db --max-items 5

# PostgreSQL Inventory
docker exec -it ecommerce-inventory-db psql -U root -d inventory_db \
  -c "SELECT sku, stock_available FROM products LIMIT 5;"

# PostgreSQL Order-Product
docker exec -it ecommerce-order-product-db psql -U root -d order_product_db \
  -c "SELECT \"orderNumber\", status FROM orders;"
```

### **4. Verificar Infraestructura AWS (LocalStack)**

```bash
# Ver tabla DynamoDB creada por CDK
make aws-tables

# Ver colas SQS creadas por CDK
make aws-queues

# Ver salud de LocalStack
make aws-health
```

---

## 🌐 URLs de Servicios

### **Microservicios**
- API Gateway: http://localhost:3000
- Auth Service: http://localhost:3010
- Users Service: http://localhost:3012
- Inventory Service: http://localhost:3011
- Order-Product Service: http://localhost:3600

### **Infraestructura**
- LocalStack: http://localhost:4566
- LocalStack Health: http://localhost:4566/_localstack/health

### **Observabilidad**
- Grafana: http://localhost:3001 (admin/admin)
- Prometheus: http://localhost:9090
- RabbitMQ: http://localhost:15672 (user/password)

### **Bases de Datos**
- MySQL (Auth): `localhost:3307` (user/user)
- DynamoDB Local: http://localhost:8000
- PostgreSQL (Inventory): `localhost:5434` (root/root)
- PostgreSQL (Order-Product): `localhost:5432` (root/root)

---

## 🔄 Comandos Útiles

```bash
# Levantar todo
make start

# Parar todo
make stop

# Limpiar volúmenes (CUIDADO: borra datos)
make clean

# Re-poblar datos de prueba
make seed-all

# Ver logs
make logs

# Ver estado de servicios
make status

# Ver todas las URLs
make urls

# Ver logs de un servicio específico
make logs-api-gateway
make logs-auth
make logs-users
```

---

## 🐛 Troubleshooting

### **Error: "Docker no está corriendo"**

**Solución:** Inicia Docker Desktop y espera a que esté completamente listo.

---

### **Error: "Connection refused" en seeds**

**Causa:** Las bases de datos aún no están completamente listas.

**Solución:**
```bash
# Esperar 30 segundos y re-ejecutar seeds
sleep 30
make seed-all
```

---

### **Error: "Table doesn't exist" en DynamoDB**

**Causa:** El CDK no se desplegó correctamente.

**Solución:**
```bash
# Verificar que LocalStack esté corriendo
docker ps | grep localstack

# Re-desplegar CDK
make cdk-deploy
```

---

### **Los servicios no levantan (healthcheck failing)**

**Solución:** Verificar logs del servicio problemático:

```bash
# Ver logs
make logs-auth
make logs-inventory

# O Docker logs directo
docker logs ecommerce-auth-service
```

Revisa que las variables de entorno en `.env.prod` estén correctas.

---

### **Error: "Port already in use"**

**Causa:** Otro proceso está usando el puerto.

**Solución:**
```bash
# Ver qué proceso usa el puerto (ejemplo: 3000)
lsof -i :3000

# O en Windows
netstat -ano | findstr :3000

# Matar el proceso o cambiar el puerto en .env.prod
```

---

## 📚 Archivos `.env` Relevantes

El `docker-compose-dev.yml` lee estos archivos:

| Servicio | Archivo |
|----------|---------|
| API Gateway | `ecommerce-api-gateway/.env.prod` |
| Auth Service | `ecommerce-auth-service/.env.prod` |
| Users Service | `serverless-users-service/.env.docker` |
| Inventory Service | `ecommerce-inventory-service/.env.prod` |
| Order-Product Service | `ecommerce-order-product-service/.env.prod` |

**Importante:** Los archivos `.env.prod` y `.env.docker` ya existen con valores por defecto funcionales. No necesitas crear nada.

---

## 🎓 Próximos Pasos

Después de levantar el entorno:

1. **Probar el flujo completo:**
   - Login → Obtener JWT → Crear orden → Verificar stock

2. **Explorar Grafana:**
   - http://localhost:3001 → Ver dashboards, traces, logs

3. **Ver mensajes en RabbitMQ:**
   - http://localhost:15672 → Exchange `orders`, queues de inventory

4. **Consultar DynamoDB:**
   ```bash
   make aws-tables
   aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name users-service-db
   ```

5. **Modificar código:**
   - Los servicios tienen hot-reload activado
   - Cambia código en `src/` y se reinicia automáticamente

---

## ⚠️ Importante

### **Seeds Destructivos**

Ejecutar `make seed-all` **borra todos los datos** existentes y re-inserta los datos de prueba.

### **Solo para Desarrollo**

Este setup está optimizado para desarrollo local. **NUNCA** uses estas configuraciones en producción:
- Credenciales hardcodeadas
- Secrets sin rotación
- Sin TLS/SSL
- Seeds con `TRUNCATE`

---

**¿Listo?**

```bash
make start
```

🎉 **¡Y en 2-3 minutos tienes un entorno completo listo para desarrollar!**
