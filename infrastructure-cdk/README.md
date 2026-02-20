# Ecommerce Infrastructure - AWS CDK

Infraestructura como código (IaC) para el proyecto Ecommerce Microservices usando AWS CDK.

## 🎯 Objetivo

Este proyecto provisiona de manera **declarativa** e **idempotente** toda la infraestructura AWS necesaria para los servicios serverless, reemplazando scripts imperativos como:

- ❌ `serverless-users-service/scripts/dynamodb/init-users-table.js` (creación manual imperativa)
- ❌ Creación de colas SQS en el código del container DI (runtime)

## 🏗️ Recursos Provisionados

### Users Service Stack

- **DynamoDB Table**: `users-service-db-{stage}`
  - Partition Key: `id` (String)
  - Global Secondary Index: `EmailIndex` (permite búsquedas por email)
  - Billing: PAY_PER_REQUEST (on-demand)
  - Encryption: AWS Managed Keys
  - Point-in-time recovery (solo en prod)

- **SQS Queue**: `user-created-queue-{stage}`
  - Visibility timeout: 30 segundos
  - Retention: 4 días
  - Dead Letter Queue configurada (3 reintentos)
  - Encryption at rest

- **SQS Dead Letter Queue**: `user-created-dlq-{stage}`
  - Retention: 14 días
  - Para investigar mensajes fallidos

## 📦 Stack Tecnológico

- **AWS CDK**: v2.150.0
- **TypeScript**: v5.3.3
- **Node.js**: v20.x
- **CloudFormation**: (generado automáticamente por CDK)

## 🚀 Instalación

```bash
cd infrastructure-cdk
npm install
```

## 🔧 Comandos Principales

### 1. Bootstrap (solo primera vez por cuenta/región)

Prepara tu cuenta AWS para usar CDK:

```bash
npm run bootstrap
```

Esto crea un bucket S3 y otros recursos necesarios para que CDK funcione.

### 2. Ver cambios antes de aplicar (diff)

```bash
npm run diff
```

Muestra qué recursos se crearán, modificarán o eliminarán.

### 3. Generar CloudFormation template (synth)

```bash
npm run synth
```

Genera el template de CloudFormation en `cdk.out/`.

### 4. Desplegar infraestructura

**Ambiente de desarrollo:**
```bash
STAGE=dev npm run deploy
```

**Ambiente de producción:**
```bash
STAGE=prod npm run deploy
```

**Todos los stacks:**
```bash
npm run deploy:all
```

### 5. Destruir infraestructura

```bash
STAGE=dev npm run destroy
```

⚠️ **CUIDADO**: En producción, los recursos con `deletionProtection` no se eliminarán.

## 🔐 Configuración de AWS Credentials

CDK usa las credenciales configuradas en AWS CLI:

```bash
# Opción 1: Configurar perfil
aws configure --profile ecommerce

# Opción 2: Variables de entorno
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_REGION=us-east-1
```

## 📊 Outputs del Stack

Después del deployment, CDK genera outputs que puedes usar en otros servicios:

```bash
# Ver outputs
aws cloudformation describe-stacks \
  --stack-name UsersServiceStack \
  --query 'Stacks[0].Outputs'
```

Outputs disponibles:
- `UsersTableName`: Nombre de la tabla DynamoDB
- `UsersTableArn`: ARN de la tabla
- `UserCreatedQueueUrl`: URL de la cola SQS principal
- `UserCreatedQueueArn`: ARN de la cola
- `UserCreatedDLQUrl`: URL de la DLQ

## 🔗 Integración con Serverless Framework

Después de deployar con CDK, actualiza las variables de entorno en `serverless.yml`:

```yaml
provider:
  environment:
    USERS_TABLE: ${cf:UsersServiceStack-dev.UsersTableName}
    USER_CREATED_QUEUE_URL: ${cf:UsersServiceStack-dev.UserCreatedQueueUrl}
```

O usa variables de entorno:

```bash
export USERS_TABLE=$(aws cloudformation describe-stacks \
  --stack-name UsersServiceStack \
  --query 'Stacks[0].Outputs[?OutputKey==`UsersTableName`].OutputValue' \
  --output text)
```

## 🏷️ Ambientes (Stages)

El proyecto soporta múltiples ambientes mediante la variable `STAGE`:

- **dev** (default): Sin deletion protection, sin point-in-time recovery
- **prod**: Con deletion protection, point-in-time recovery habilitado

```bash
# Desarrollo
STAGE=dev npm run deploy

# Staging
STAGE=staging npm run deploy

# Producción
STAGE=prod npm run deploy
```

Cada ambiente crea recursos con nombres únicos: `users-service-db-dev`, `users-service-db-prod`, etc.

## 🧪 Testing Local con LocalStack

Para testing local, usa LocalStack (ya configurado en el proyecto):

```bash
# En docker-compose-dev.yml ya está configurado LocalStack
docker-compose -f docker-compose-dev.yml up localstack

# Deploy a LocalStack
cdklocal bootstrap
cdklocal deploy
```

O usa el endpoint de LocalStack manualmente:

```bash
AWS_ENDPOINT_URL=http://localhost:4566 npm run deploy
```

## 📝 Estructura del Proyecto

```
infrastructure-cdk/
├── bin/
│   └── app.ts                 # Entry point - define los stacks
├── lib/
│   └── users-service-stack.ts # Stack del servicio de usuarios
├── cdk.out/                   # Templates generados (gitignored)
├── node_modules/
├── .gitignore
├── cdk.json                   # Configuración de CDK
├── package.json
├── tsconfig.json
└── README.md
```

## 🆚 Comparación: CDK vs Scripts Imperativos

| Aspecto | Script Manual | AWS CDK |
|---------|--------------|---------|
| **Idempotencia** | ❌ Requiere lógica custom | ✅ Built-in |
| **Rollback** | ❌ Manual | ✅ Automático |
| **Change preview** | ❌ No disponible | ✅ `cdk diff` |
| **Estado** | ❌ No trackeable | ✅ CloudFormation state |
| **Multi-ambiente** | ❌ Código duplicado | ✅ Reutilizable |
| **Seguridad** | ❌ Permisos en código | ✅ IAM policies gestionadas |
| **Versionado** | ⚠️ Parcial | ✅ Completo |

## 🔄 Migración desde Scripts Manuales

### Antes (Imperativo)

```javascript
// scripts/dynamodb/init-users-table.js
const dynamodb = new DynamoDBClient(clientConfig);
await dynamodb.send(new CreateTableCommand({...}));
```

**Problemas:**
- No es idempotente (falla si la tabla ya existe)
- No trackea cambios
- No hace rollback automático
- Difícil de versionar

### Después (Declarativo con CDK)

```typescript
// lib/users-service-stack.ts
this.usersTable = new dynamodb.Table(this, "UsersTable", {
  tableName: `users-service-db-${stage}`,
  partitionKey: { name: "id", type: dynamodb.AttributeType.STRING },
  billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
  // ... configuración declarativa
});
```

**Ventajas:**
- ✅ Idempotente por diseño
- ✅ CloudFormation trackea todos los cambios
- ✅ Rollback automático si algo falla
- ✅ `cdk diff` muestra cambios antes de aplicar

## 🛠️ Comandos Útiles

```bash
# Compilar TypeScript
npm run build

# Watch mode (recompila automáticamente)
npm run watch

# Listar todos los stacks
npm run cdk list

# Ver CloudFormation template generado
npm run synth

# Comparar con lo deployado actualmente
npm run diff

# Desplegar con confirmación manual
npm run deploy -- --require-approval never
```

## 📚 Recursos Adicionales

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [CDK API Reference](https://docs.aws.amazon.com/cdk/api/v2/)
- [CDK Workshop](https://cdkworkshop.com/)
- [AWS CDK Examples](https://github.com/aws-samples/aws-cdk-examples)

## 🐛 Troubleshooting

### Error: "CDK is not bootstrapped"

```bash
npm run bootstrap
```

### Error: "Unable to resolve AWS account"

```bash
aws configure
# O establece las variables de entorno AWS_ACCOUNT_ID y AWS_REGION
```

### Error: "Stack already exists"

Es normal. CDK actualizará el stack existente (update), no falla como los scripts imperativos.

### Ver logs de CloudFormation

```bash
aws cloudformation describe-stack-events \
  --stack-name UsersServiceStack \
  --max-items 10
```

## 🔐 Seguridad

- ✅ Encryption at rest habilitada en DynamoDB y SQS
- ✅ Deletion protection en producción
- ✅ Point-in-time recovery en producción
- ✅ Dead Letter Queue para no perder mensajes
- ✅ IAM roles con least privilege (generados por CDK)
- ✅ No hay credenciales hardcodeadas

## 📈 Próximos Pasos

1. **Agregar más stacks**:
   - Inventory Service infrastructure
   - Order-Product Service infrastructure
   - RabbitMQ en AWS (Amazon MQ)

2. **CI/CD**:
   - Integrar con GitHub Actions
   - Pipeline de deployment automático

3. **Monitoring**:
   - CloudWatch Alarms
   - SNS notifications
   - X-Ray tracing

4. **Multi-region**:
   - DynamoDB Global Tables
   - SQS cross-region

---

**Mantenido por**: Equipo de infraestructura
**Última actualización**: 2026-02-20
