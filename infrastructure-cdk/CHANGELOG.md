# Changelog - Infrastructure CDK

Registro de cambios y mejoras en la infraestructura.

## [1.0.0] - 2026-02-20

### ✨ Added

#### Proyecto AWS CDK
- **Creado proyecto AWS CDK** para provisionar infraestructura de manera declarativa
- Estructura TypeScript completa con tsconfig y configuración de CDK
- Stack `UsersServiceStack` con todos los recursos necesarios

#### Recursos de Infraestructura
- **DynamoDB Table**: `users-service-db-{stage}`
  - Partition Key: `id` (String)
  - Global Secondary Index: `EmailIndex` para búsquedas por email
  - Billing mode: PAY_PER_REQUEST (on-demand)
  - Encryption at rest con AWS managed keys
  - Point-in-time recovery en producción
  - Deletion protection en producción

- **SQS Queue**: `user-created-queue-{stage}`
  - Visibility timeout: 30 segundos
  - Message retention: 4 días
  - Dead Letter Queue configurada
  - Encryption at rest
  - Max receive count: 3 (antes de ir a DLQ)

- **SQS Dead Letter Queue**: `user-created-dlq-{stage}`
  - Message retention: 14 días
  - Para investigación de mensajes fallidos

#### LocalStack Integration
- **docker-compose.localstack.yml**: Compose dedicado para LocalStack
  - LocalStack 3.0 con servicios: DynamoDB, SQS, CloudFormation, STS, IAM, S3
  - Persistencia habilitada en `infrastructure-cdk/.localstack/`
  - Health check configurado
  - Debug mode habilitado

#### Scripts de Automatización
- **start-dev-environment.ps1** (PowerShell para Windows)
  - Levanta LocalStack
  - Levanta microservicios (opcional)
  - Instala dependencias de CDK
  - Hace bootstrap de CDK
  - Despliega infraestructura
  - Muestra resumen de servicios

- **start-dev-environment.sh** (Bash para Linux/macOS)
  - Funcionalidad equivalente al script PowerShell
  - Colores en terminal
  - Wait loops para esperar servicios

- **stop-dev-environment.ps1** (PowerShell)
  - Detiene servicios de manera ordenada
  - Opción `--clean` para eliminar volúmenes

- **stop-dev-environment.sh** (Bash)
  - Funcionalidad equivalente al script PowerShell

#### Makefile
- **Makefile**: Simplifica comandos comunes
  - `make start`: Inicia todo el entorno
  - `make stop`: Detiene todo
  - `make logs`: Ver logs de servicios
  - `make cdk-diff`: Ver cambios de infraestructura
  - `make cdk-deploy`: Desplegar infraestructura
  - `make aws-tables`: Listar tablas en LocalStack
  - `make test-health`: Verificar health de servicios
  - `make urls`: Mostrar todas las URLs

#### Documentación
- **README.md**: Documentación completa del proyecto CDK
  - Comandos principales
  - Comparación vs scripts imperativos
  - Integración con Serverless Framework
  - Multi-ambiente (dev/staging/prod)
  - Testing con LocalStack
  - Troubleshooting

- **WINDOWS-SETUP.md**: Guía específica para Windows
  - Instalación de requisitos
  - Configuración de AWS CLI
  - Troubleshooting Windows-specific
  - Tips y trucos para PowerShell

- **QUICKSTART.md**: Guía de inicio rápido
  - URLs de servicios
  - Comandos útiles
  - Verificación de funcionamiento
  - Flujo de trabajo típico

- **.env.example**: Template de variables de entorno
  - AWS_REGION, AWS_ACCOUNT_ID, STAGE
  - Configuración para LocalStack

#### Configuración
- **cdk.json**: Configuración de AWS CDK
  - Feature flags habilitados
  - Watch configuration
  - Context para diferentes ambientes

- **.gitignore**: Ignora archivos generados
  - `cdk.out/`
  - `node_modules/`
  - `.localstack/` (datos persistentes)
  - Archivos de build

- **.npmrc**: Configuración de npm
  - Desactiva package-lock.json
  - Versiones exactas

#### CloudFormation Outputs
- `UsersTableName`: Nombre de tabla DynamoDB
- `UsersTableArn`: ARN de tabla DynamoDB
- `UserCreatedQueueUrl`: URL de cola SQS
- `UserCreatedQueueArn`: ARN de cola SQS
- `UserCreatedDLQUrl`: URL de Dead Letter Queue

#### Tags
- Tags automáticos en todos los recursos:
  - `Project`: EcommerceMicroservices
  - `ManagedBy`: AWS-CDK
  - `Environment`: dev/staging/prod
  - `Service`: users-service
  - `ResourceType`: database/messaging

### 🔄 Changed

#### Proyecto Principal
- Actualizado `.gitignore` para incluir exclusiones de LocalStack
- Eliminado directorio `localstack/` (ahora se usa docker-compose.localstack.yml)

### 🗑️ Deprecated

#### Scripts Manuales (Ahora reemplazados por CDK)
- `serverless-users-service/scripts/dynamodb/init-users-table.js`
  - ❌ Creación imperativa de tabla DynamoDB
  - ✅ Reemplazado por CDK declarativo

- Creación manual de colas SQS en código
  - ❌ `container.ts` creaba colas en runtime
  - ✅ Ahora se crean con CDK antes del deployment

### 📈 Advantages over Previous Approach

#### Idempotencia
- **Antes**: Script fallaba si la tabla ya existía
- **Ahora**: CDK actualiza recursos existentes automáticamente

#### Change Management
- **Antes**: No se podía ver qué cambiaría antes de aplicar
- **Ahora**: `cdk diff` muestra cambios antes de aplicar

#### Rollback
- **Antes**: Rollback manual en caso de error
- **Ahora**: CloudFormation hace rollback automático

#### Multi-Ambiente
- **Antes**: Código duplicado para cada ambiente
- **Ahora**: Variable `STAGE` reutiliza el mismo stack

#### State Management
- **Antes**: Sin tracking de estado
- **Ahora**: CloudFormation trackea todos los recursos

#### Security
- **Antes**: Permisos hardcodeados en código
- **Ahora**: IAM roles y policies gestionados por CDK

### 🔒 Security Improvements

- Encryption at rest habilitada en DynamoDB y SQS
- Deletion protection en producción
- Point-in-time recovery en producción
- Dead Letter Queue para no perder mensajes
- IAM roles con least privilege (generados por CDK)
- No hay credenciales hardcodeadas

### 🚀 Performance

- LocalStack 3.0 con eager service loading
- Persistencia de datos entre reinicios
- Connection pooling en cliente SQS (singleton)

### 📊 Observability

- CloudWatch logs integration (automático con CDK)
- Tags para cost tracking
- CloudFormation events para auditoría

## [Unreleased] - Próximas mejoras

### 🔮 Planned

- [ ] Stack para Inventory Service (PostgreSQL RDS)
- [ ] Stack para Order-Product Service (PostgreSQL RDS)
- [ ] Stack para RabbitMQ (Amazon MQ)
- [ ] CI/CD pipeline con GitHub Actions
- [ ] CloudWatch Alarms y SNS notifications
- [ ] X-Ray tracing integration
- [ ] Multi-region deployment
- [ ] DynamoDB Global Tables
- [ ] Backup automation con AWS Backup
- [ ] Secrets management con AWS Secrets Manager

### 🤔 Considering

- [ ] Terraform backend para CDK (Terraform CDK)
- [ ] Pulumi como alternativa a CDK
- [ ] ECS Fargate para servicios containerizados
- [ ] API Gateway + Lambda authorizers
- [ ] EventBridge para event routing
- [ ] Step Functions para orchestration

---

**Mantenido por**: Equipo de infraestructura
**Última actualización**: 2026-02-20
