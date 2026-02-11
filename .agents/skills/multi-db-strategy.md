---
name: multi-db-strategy
description: Estrategia multi-base de datos del proyecto — MySQL con TypeORM (auth), PostgreSQL con TypeORM (inventory), PostgreSQL con Prisma (order-product), DynamoDB con AWS SDK v3 (serverless-users)
category: data
priority: high
applies_to:
  - ecommerce-auth-service/src/
  - ecommerce-inventory-service/src/shared/infrastructure/db/
  - ecommerce-order-product-service/src/shared/infrastructure/db/prisma/
  - serverless-users-service/src/shared/database/
last_validated: 2026-02-11
conflicts_with: []
requires_human_approval: true
---

# Skill: Multi-Database Strategy

## Descripción

Cada microservicio tiene su propia base de datos aislada (Database-per-Service pattern). Diferentes ORMs y motores según las necesidades de cada servicio.

---

## Mapa de Bases de Datos

| Servicio | Motor | Puerto (dev) | ORM / SDK | Esquema |
|---|---|---|---|---|
| Auth Service | MySQL 8 | 3307 | TypeORM 0.3 | `users_db` |
| Inventory Service | PostgreSQL 15 | 5434 | TypeORM 0.3 | `inventory_db` |
| Order-Product Service | PostgreSQL 15 | 5432 | Prisma 7 | `order_product_db` |
| Users Service (nuevo) | DynamoDB Local / AWS | 8000 | AWS SDK v3 | Tabla `users-service-db` |

---

## Auth Service — TypeORM + MySQL

**Configuración:** Via `@nestjs/typeorm` en `AppModule`
**Entidades:** `AuthCredentials`, `User` (en `services/`)
**Auto-sync:** NestJS TypeORM con `synchronize` (verificar si está en `true` — riesgo en prod)

**Patrón de uso:**
```typescript
@InjectRepository(AuthCredentials)
private authCredentialsRepository: Repository<AuthCredentials>
```

---

## Inventory Service — TypeORM + PostgreSQL

**Configuración:** `src/shared/infrastructure/db/typeorm.config.ts`
**Migraciones:** TypeORM CLI, ejecutadas al inicio del contenedor
```bash
npm run migration:run  # docker-compose-dev.yml:142
```

**Comandos disponibles:**
```bash
npm run migration:generate  # Generar migración desde entidades
npm run migration:create    # Crear migración vacía
npm run migration:run       # Aplicar migraciones pendientes
npm run migration:revert    # Revertir última migración
```

**Entidades:** `Product` (en `infrastructure/entities/product.entity.ts`)

---

## Order-Product Service — Prisma 7 + PostgreSQL

**Schema:** `src/shared/infrastructure/db/prisma/schema.prisma`
**Cliente generado:** `src/generated/prisma/` (NO editar manualmente)
**Proveedor:** `@prisma/adapter-pg` (adaptador nativo PostgreSQL)

**Modelos:** `Product`, `Customer`, `Address`, `Order`, `OrderItem`, `Outbox`

**Comandos:**
```bash
npm run prisma:generate       # Regenerar cliente TypeScript
npm run prisma:migrate:dev    # Crear y aplicar migración en dev
npm run prisma:migrate:prod   # Solo aplicar migraciones en prod
npm run prisma:db:push        # Push schema sin migración (DEV ONLY)
npm run prisma:migrate:reset  # Reset completo con pérdida de datos
```

> **ADVERTENCIA CRÍTICA**: `docker-compose-dev.yml:185` usa `prisma db push --accept-data-loss`. Esto puede eliminar columnas o tablas sin confirmación. Nunca usar en producción.

**Para producción usar:**
```bash
npm run prisma:migrate:prod  # prisma migrate deploy
```

**Singleton del cliente:**
```typescript
// shared/infrastructure/db/prisma/prisma.client.ts
// PrismaClient se instancia una sola vez y se reutiliza
```

---

## Users Service (Serverless) — DynamoDB + AWS SDK v3

**Tabla:** `users-service-db` (configurable via `USERS_TABLE` env)
**Índice secundario:** `email-index` (GSI para búsqueda por email)

**Setup local:**
```bash
npm run dynamodb:up    # Levanta DynamoDB Local en Docker
npm run dynamodb:wait  # Espera a que esté disponible
npm run dynamodb:init  # Crea la tabla (script en scripts/dynamodb/)
```

**Patron de acceso:**
```typescript
// shared/database/dynamodb.client.ts
// repositories/users.repository.ts — usa AWS SDK v3 DynamoDBDocumentClient
```

**SQS:** `infrastructure/messaging/SQSMessagePublisher.ts` — publica `UserCreated` event

---

## Reglas para Agentes

1. **Nunca** hacer queries cross-service a la BD de otro microservicio
2. **Auth Service**: al hacer cambios en entidades TypeORM, verificar si `synchronize: true` está activo (ver app.module.ts)
3. **Inventory**: siempre generar migración con `migration:generate` antes de un cambio de schema — no usar `synchronize: true` en producción
4. **Order-Product**: para cambios de schema, crear migración con `prisma:migrate:dev` — NUNCA usar `prisma db push` en producción
5. **DynamoDB**: la tabla debe ser creada manualmente antes del primer despliegue (scripts/dynamodb/init-users-table.js)
6. Cualquier cambio en schema que afecte datos existentes requiere aprobación humana (ver AGENTS.md)

---

## Decisiones Pendientes

- Ver Q003 en `questions-log.md` sobre el estado de la migración users-service → serverless-users-service

---

## Update History

| Date | Change | Author |
|---|---|---|
| 2026-02-11 | Creación inicial por bootstrap | Agent |
