# 🚀 Quick Start - Entorno de Desarrollo

Guía rápida para levantar todo el entorno de desarrollo del proyecto Ecommerce Microservices.

## 📋 Requisitos Previos

- **Docker Desktop** instalado y corriendo
- **Node.js 20+** instalado
- **PowerShell 7+** (pwsh) para Windows
- **Git** (opcional, para clonar el repositorio)

## ⚡ Inicio Rápido (Windows)

### Opción 1: Script Automatizado (Recomendado)

```powershell
# Ejecutar desde la raíz del proyecto
.\start-dev-environment.ps1
```

Este script hace **TODO** automáticamente:
1. ✅ Levanta LocalStack (emulador de AWS)
2. ✅ Levanta todos los microservicios
3. ✅ Levanta bases de datos (MySQL, PostgreSQL, DynamoDB Local)
4. ✅ Levanta observabilidad (Grafana, Prometheus, Tempo, Loki)
5. ✅ Hace bootstrap de AWS CDK
6. ✅ Despliega infraestructura (DynamoDB, SQS)

### Opción 2: Solo Infraestructura (LocalStack + CDK)

Si solo quieres probar la infraestructura sin levantar todos los servicios:

```powershell
.\start-dev-environment.ps1 -OnlyInfrastructure
```

### Opción 3: Solo Docker (Sin CDK)

Si solo quieres levantar los contenedores:

```powershell
.\start-dev-environment.ps1 -SkipCDK
```

### Opción 4: Reconstruir Imágenes

Si cambiaste un Dockerfile y necesitas rebuild:

```powershell
.\start-dev-environment.ps1 -Build
```

## 🛑 Detener el Entorno

### Detener preservando datos

```powershell
.\stop-dev-environment.ps1
```

### Detener y limpiar todo (⚠️ Pérdida de datos)

```powershell
.\stop-dev-environment.ps1 -Clean
```

### Solo detener LocalStack

```powershell
.\stop-dev-environment.ps1 -OnlyLocalStack
```

## 🌐 URLs de Servicios

Una vez iniciado, puedes acceder a:

### 🚀 Microservicios

| Servicio | URL | Descripción |
|----------|-----|-------------|
| API Gateway | http://localhost:3000 | Punto de entrada principal |
| Auth Service | http://localhost:3010 | Autenticación y JWT |
| Users Service | http://localhost:3012 | Gestión de usuarios (serverless) |
| Inventory Service | http://localhost:3011 | Gestión de inventario (CQRS) |
| Order-Product | http://localhost:3600 | Gestión de órdenes (DDD) |

### 💾 Bases de Datos

| Base de Datos | Host | Puerto | Usuario | Password |
|---------------|------|--------|---------|----------|
| MySQL (Auth) | localhost | 3307 | root | root |
| DynamoDB Local | localhost | 8000 | - | - |
| PostgreSQL (Inventory) | localhost | 5434 | root | root |
| PostgreSQL (Order) | localhost | 5432 | root | root |

### 📊 Observabilidad

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Grafana | http://localhost:3001 | admin / admin |
| Prometheus | http://localhost:9090 | - |
| RabbitMQ Management | http://localhost:15672 | user / password |

### 🔧 Infraestructura

| Servicio | URL | Descripción |
|----------|-----|-------------|
| LocalStack | http://localhost:4566 | Emulador de AWS |
| LocalStack Health | http://localhost:4566/_localstack/health | Estado de LocalStack |

## 🔍 Verificar que Todo Funciona

### 1. Verificar LocalStack

```powershell
curl http://localhost:4566/_localstack/health
```

Deberías ver un JSON con el estado de los servicios AWS emulados.

### 2. Verificar DynamoDB en LocalStack

```powershell
# Listar tablas DynamoDB
aws --endpoint-url=http://localhost:4566 dynamodb list-tables

# Deberías ver la tabla creada por CDK
```

### 3. Verificar SQS en LocalStack

```powershell
# Listar colas SQS
aws --endpoint-url=http://localhost:4566 sqs list-queues
```

### 4. Verificar Microservicios

```powershell
# Health check de todos los servicios
curl http://localhost:3000/health  # API Gateway
curl http://localhost:3010/health  # Auth Service
curl http://localhost:3012/health  # Users Service
curl http://localhost:3011/health  # Inventory Service
curl http://localhost:3600/health  # Order-Product Service
```

## 🛠️ Comandos Útiles

### Docker

```powershell
# Ver logs de todos los servicios
docker-compose -f docker-compose-dev.yml logs -f

# Ver logs de un servicio específico
docker logs -f ecommerce-api-gateway
docker logs -f ecommerce-localstack

# Ver contenedores corriendo
docker ps

# Ver recursos de Docker
docker stats
```

### AWS CLI con LocalStack

```powershell
# Configurar alias para usar LocalStack fácilmente
function awslocal { aws --endpoint-url=http://localhost:4566 $args }

# Listar tablas DynamoDB
awslocal dynamodb list-tables

# Describir una tabla
awslocal dynamodb describe-table --table-name users-service-db-dev

# Listar colas SQS
awslocal sqs list-queues

# Listar buckets S3 (si CDK los crea)
awslocal s3 ls
```

### CDK

```powershell
cd infrastructure-cdk

# Ver diferencias con lo desplegado
npm run diff

# Desplegar cambios
npm run deploy

# Ver el template de CloudFormation generado
npm run synth

# Destruir toda la infraestructura
npm run destroy
```

## 🐛 Troubleshooting

### Error: "Docker no está corriendo"

**Solución**: Inicia Docker Desktop y espera a que esté completamente iniciado.

### Error: "Puerto ya en uso"

**Solución**: Detén otros servicios que estén usando los puertos:

```powershell
# Windows: Ver qué proceso usa el puerto 3000
netstat -ano | findstr :3000

# Matar el proceso (reemplaza PID)
taskkill /PID <PID> /F
```

### LocalStack no responde

**Solución**:

```powershell
# Ver logs de LocalStack
docker logs -f ecommerce-localstack

# Reiniciar LocalStack
docker-compose -f docker-compose.localstack.yml restart

# Si sigue fallando, limpiar y reiniciar
docker-compose -f docker-compose.localstack.yml down -v
.\start-dev-environment.ps1 -OnlyInfrastructure
```

### CDK falla al hacer bootstrap

**Solución**:

```powershell
# Asegúrate de que LocalStack esté corriendo
curl http://localhost:4566/_localstack/health

# Limpia la caché de CDK
cd infrastructure-cdk
Remove-Item -Recurse -Force cdk.out -ErrorAction SilentlyContinue

# Intenta de nuevo
npm run bootstrap
```

### Los microservicios no arrancan

**Solución**:

```powershell
# Ver logs para identificar el problema
docker-compose -f docker-compose-dev.yml logs

# Reconstruir imágenes
.\start-dev-environment.ps1 -Build
```

## 🔄 Flujo de Trabajo Típico

### Desarrollo día a día

```powershell
# Mañana: Iniciar entorno
.\start-dev-environment.ps1

# Desarrollar...
# Hacer cambios en el código
# Los servicios se recargan automáticamente (hot reload)

# Ver logs mientras desarrollas
docker-compose -f docker-compose-dev.yml logs -f <servicio>

# Noche: Detener entorno (preserva datos)
.\stop-dev-environment.ps1
```

### Cambios en infraestructura

```powershell
# 1. Hacer cambios en infrastructure-cdk/lib/*

# 2. Ver qué cambiaría
cd infrastructure-cdk
npm run diff

# 3. Desplegar cambios
npm run deploy

# 4. Verificar que funcionó
awslocal dynamodb list-tables
```

### Reset completo (empezar de cero)

```powershell
# Detener y limpiar TODO
.\stop-dev-environment.ps1 -Clean

# Reiniciar desde cero
.\start-dev-environment.ps1 -Build
```

## 📚 Próximos Pasos

1. **Leer la documentación del proyecto**: [AGENTS.md](./AGENTS.md)
2. **Explorar los skills disponibles**: `.agents/skills/`
3. **Revisar la arquitectura**: `.agents/analysis-summary.md`
4. **Ver preguntas pendientes**: `.agents/questions-log.md`
5. **Entender CDK**: [infrastructure-cdk/README.md](./infrastructure-cdk/README.md)

## 🆘 Ayuda

Si tienes problemas:

1. Consulta la sección **Troubleshooting** arriba
2. Revisa los logs: `docker-compose -f docker-compose-dev.yml logs`
3. Consulta [AGENTS.md](./AGENTS.md) para el contrato técnico del proyecto
4. Revisa el [README de CDK](./infrastructure-cdk/README.md) para temas de infraestructura

---

**Happy coding! 🚀**
