# 🚀 Despliegue a Producción con AWS CDK

Guía para desplegar la infraestructura a AWS real usando AWS CDK.

---

## ⚠️ Importante

**Este proceso es SOLO para AWS real (producción/staging).**

Para desarrollo local, usa `make start` (que usa LocalStack + AWS CLI directo).

---

## 📋 Pre-requisitos

### 1. **AWS CLI Configurado**

```bash
# Instalar AWS CLI v2
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Configurar credenciales
aws configure

# Verificar que funciona
aws sts get-caller-identity
```

### 2. **Node.js 20+**

```bash
node --version  # Debe ser v20 o superior
```

### 3. **Cuenta AWS con Permisos**

Necesitas permisos para:
- CloudFormation
- DynamoDB
- SQS
- IAM (para crear roles)
- S3 (para assets de CDK)

---

## 🎯 Flujo de Despliegue

### **Opción 1: Script Automatizado** (Recomendado)

```bash
# 1. Configurar entorno
export AWS_PROFILE=production        # O el profile que uses
export AWS_REGION=us-east-1
export STAGE=prod
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 2. Ejecutar script
./scripts/start-dev-environment.sh
```

El script detectará que `STAGE=prod` y:
1. ✅ Verificará tus credenciales de AWS
2. ✅ Hará bootstrap de CDK (si es primera vez)
3. ✅ Mostrará un diff de los cambios
4. ✅ Pedirá confirmación antes de desplegar
5. ✅ Desplegará el stack `UsersServiceStack`

---

### **Opción 2: Manual (Paso a Paso)**

```bash
# 1. Ir al directorio de CDK
cd infrastructure-cdk

# 2. Instalar dependencias
npm install

# 3. Configurar variables de entorno
export AWS_REGION=us-east-1
export AWS_PROFILE=production
export STAGE=prod

# 4. Bootstrap CDK (solo primera vez por cuenta/región)
npm run bootstrap

# 5. Ver cambios que se aplicarán
npm run diff

# 6. Desplegar
npm run deploy

# 7. Ver outputs (URLs de recursos creados)
aws cloudformation describe-stacks \
  --stack-name UsersServiceStack \
  --query 'Stacks[0].Outputs'
```

---

## 🏗️ Recursos que se Crearán

### **Stack: UsersServiceStack**

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| **DynamoDB Table** | `users-service-db` | Tabla de usuarios con GSI por email |
| **SQS Queue** | `user-created-queue-prod` | Cola para eventos de usuario creado |
| **SQS DLQ** | `user-created-dlq-prod` | Dead Letter Queue para mensajes fallidos |

---

## 📊 Verificar Recursos Creados

```bash
# Ver tabla DynamoDB
aws dynamodb describe-table --table-name users-service-db

# Ver colas SQS
aws sqs list-queues

# Ver stack de CloudFormation
aws cloudformation describe-stacks --stack-name UsersServiceStack

# Ver outputs del stack
aws cloudformation describe-stacks \
  --stack-name UsersServiceStack \
  --query 'Stacks[0].Outputs'
```

---

## 🔄 Actualizar Infraestructura

```bash
# 1. Modificar código en lib/users-service-stack.ts

# 2. Ver cambios
cd infrastructure-cdk
npm run diff

# 3. Desplegar cambios
npm run deploy
```

**CDK automáticamente:**
- ✅ Detecta qué recursos cambiaron
- ✅ Crea un changeset
- ✅ Aplica cambios sin downtime (cuando es posible)
- ✅ Hace rollback si algo falla

---

## 🗑️ Destruir Infraestructura

⚠️ **CUIDADO: Esto eliminará todos los recursos**

```bash
cd infrastructure-cdk

# Ver qué se eliminará
npm run synth

# Destruir stack
npm run destroy
```

**Nota:** Las tablas con `removalPolicy: RETAIN` (producción) NO se eliminarán automáticamente.

---

## 🌍 Múltiples Ambientes

### **Staging**

```bash
export STAGE=staging
export AWS_REGION=us-east-1

cd infrastructure-cdk
npm run deploy
```

Esto creará:
- `users-service-db-staging`
- `user-created-queue-staging`
- `user-created-dlq-staging`

### **Producción**

```bash
export STAGE=prod
export AWS_REGION=us-east-1

cd infrastructure-cdk
npm run deploy
```

Esto creará:
- `users-service-db` (nombre fijo para compatibilidad)
- `user-created-queue-prod`
- `user-created-dlq-prod`

---

## 🔐 Mejores Prácticas

### 1. **Usar AWS Profiles**

```bash
# ~/.aws/config
[profile production]
region = us-east-1
output = json

[profile staging]
region = us-east-1
output = json

# Uso
export AWS_PROFILE=production
npm run deploy
```

### 2. **Usar CI/CD**

```yaml
# .github/workflows/deploy-infrastructure.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure-cdk/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: 20

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Install dependencies
        run: cd infrastructure-cdk && npm install

      - name: Deploy with CDK
        run: cd infrastructure-cdk && npm run deploy -- --require-approval never
```

### 3. **Validar Antes de Desplegar**

```bash
# Sintetizar CloudFormation template
npm run synth

# Validar sintaxis
npm run build

# Ver diff
npm run diff

# Solo entonces, deploy
npm run deploy
```

---

## 🐛 Troubleshooting

### **Error: "CDK not bootstrapped"**

```bash
# Bootstrap en tu cuenta/región
cd infrastructure-cdk
npm run bootstrap
```

### **Error: "Insufficient permissions"**

Necesitas permisos de IAM para CloudFormation, DynamoDB, SQS, S3.

Pide a tu admin de AWS que te otorgue el policy `PowerUserAccess` o similar.

### **Error: "Stack already exists"**

Si ya desplegaste antes y quieres re-desplegar:

```bash
# Ver diferencias
npm run diff

# Desplegar cambios
npm run deploy
```

---

## 📚 Más Información

- [AWS CDK Docs](https://docs.aws.amazon.com/cdk/)
- [CDK Best Practices](https://docs.aws.amazon.com/cdk/v2/guide/best-practices.html)
- [DynamoDB Pricing](https://aws.amazon.com/dynamodb/pricing/)
- [SQS Pricing](https://aws.amazon.com/sqs/pricing/)

---

## ✅ Checklist de Despliegue

Antes de desplegar a producción:

- [ ] AWS CLI configurado con credenciales de producción
- [ ] `STAGE=prod` y `AWS_REGION` configurados
- [ ] Bootstrap de CDK ejecutado en la cuenta/región
- [ ] `npm run diff` revisado (entiendes los cambios)
- [ ] Backup de datos existentes (si hay)
- [ ] Plan de rollback definido
- [ ] Monitoreo configurado (CloudWatch)
- [ ] Presupuesto de AWS configurado (para evitar sorpresas)

---

**¿Listo para desplegar?**

```bash
export STAGE=prod
export AWS_REGION=us-east-1
./scripts/start-dev-environment.sh
```

🚀 **¡Éxito!**
