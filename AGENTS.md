# AGENTS.md — Contrato Técnico del Proyecto Ecommerce Microservices

> Única fuente de verdad sobre el comportamiento esperado del agente y las reglas del proyecto.
> Versión inicial generada mediante bootstrap de contexto real del código.

---

## Rol del Agente

Actúas como **arquitecto de software senior** con enfoque en:
- Calidad, mantenibilidad, seguridad y escalabilidad
- Fidelidad al código real (no al ideal teórico)
- Detección proactiva de riesgos antes de implementar

---

## Regla Fundamental: Preguntar Antes de Asumir

**SIEMPRE** detén la ejecución y formula preguntas concretas cuando encuentres:

1. Patrones contradictorios entre servicios
2. Manejo de datos sensibles sin protección clara
3. Conceptos de negocio ambiguos
4. Configuraciones críticas con impacto desconocido
5. Cambios que afecten múltiples microservicios

Usa el formato definido en `.agents/questions-log.md`.

---

## Sistema de Routing por Skills

Antes de cualquier trabajo creativo o no trivial, consulta las skills disponibles:

| Tarea | Skill a consultar |
|---|---|
| Implementar autenticación/autorización | `skills/api-gateway-auth.md` |
| Publicar/consumir eventos RabbitMQ | `skills/event-driven-outbox.md` |
| Agregar dominio o entidad de negocio | `skills/ddd-architecture.md` |
| Configurar nueva base de datos | `skills/multi-db-strategy.md` |
| Agregar observabilidad | `skills/observability-stack.md` |
| Comunicación entre servicios | `skills/security-service-mesh.md` |
| Trabajo creativo / nuevas features | skill `brainstorming` (global) |

---

## Estructura del Proyecto

```
ecommerce/
├── AGENTS.md                          # Este archivo
├── docker-compose-dev.yml             # Entorno completo de desarrollo
├── docker-compose-prod.yml            # Entorno de producción (pendiente)
├── .agents/
│   ├── analysis-summary.md            # Resumen ejecutivo del bootstrap
│   ├── questions-log.md               # Registro de decisiones y ambigüedades
│   ├── checkpoints/                   # Estados de análisis
│   └── skills/                        # Patrones documentados y validados
│
├── ecommerce-api-gateway/             # Express 5 + http-proxy-middleware  [Puerto 3000]
│   └── src/
│       ├── middleware/                # auth, rate-limit, cookie, request-id, logger
│       ├── routes/proxy.routes.ts     # Definición de proxies por servicio
│       ├── config/config.ts           # Validación de env vars al arranque
│       └── utils/                     # logger (Winston), custom helpers
│
├── ecommerce-auth-service/            # NestJS + TypeORM + MySQL  [Puerto 3010]
│   └── src/
│       ├── auth/                      # Login, signup, validateToken, guards
│       ├── services/                  # UsersService (CRUD sobre MySQL)
│       └── roles/                     # Role enum + RolesGuard
│
├── ecommerce-users-service/           # NestJS  [Puerto 3011 — LEGACY/TRANSITIONAL]
│   └── src/users/                    # Servicio siendo reemplazado por serverless
│
├── serverless-users-service/          # AWS Lambda + DynamoDB + SQS  [Offline: 4000]
│   └── src/
│       ├── functions/users/           # Handlers Lambda por operación
│       ├── services/users.service.ts  # Lógica de negocio
│       ├── repositories/              # DynamoDB access via AWS SDK v3
│       └── infrastructure/messaging/  # SQS publisher (UserCreated event)
│
├── ecommerce-inventory-service/       # Express 5 + TypeORM + PostgreSQL  [Puerto 3011]
│   └── src/
│       ├── application/               # Commands (CQRS), Queries, Events consumer
│       ├── domain/product/            # Modelo de dominio + IInventoryRepository
│       └── infrastructure/            # TypeORM repo, RabbitMQ consumer bootstrap
│
├── ecommerce-order-product-service/   # Express 5 + Prisma + PostgreSQL  [Puerto 3600]
│   └── src/
│       ├── domain/                    # DDD: customer, order, product (app/domain/infra)
│       ├── shared/                    # UoW, EventBus, RabbitMQ publisher, logger
│       └── generated/prisma/          # Cliente Prisma generado
│
├── localstack/                        # LocalStack para emulación AWS local
└── observability/                     # OTel Collector, Tempo, Prometheus, Grafana, Loki
```

---

## Stack Tecnológico Real

| Componente | Tecnología |
|---|---|
| API Gateway | Node.js + Express 5 + TypeScript |
| Auth Service | NestJS 10 + TypeORM + MySQL 8 |
| Users Service (nuevo) | AWS Lambda + Serverless Framework 4 + DynamoDB |
| Inventory Service | Express 5 + TypeORM 0.3 + PostgreSQL 15 |
| Order-Product Service | Express 5 + Prisma 7 + PostgreSQL 15 |
| Message Broker | RabbitMQ 3 (topic exchange `orders`) |
| Observabilidad | OpenTelemetry + Tempo + Prometheus + Grafana + Loki |
| Monitoreo APM | New Relic (solo order-product service) |
| Serverless local | serverless-offline + DynamoDB local |

---

## Flujos Críticos del Sistema

### 1. Autenticación de Usuario
```
Cliente → Gateway (Bearer token)
  → axios.get auth-service/auth/validate
  → token válido → set headers (x-user-id, x-user-email, x-user-role, x-gateway-secret)
  → proxy a servicio destino
  [Caché en memoria: 5 min, no distribuida]
```

### 2. Creación de Orden
```
Cliente → Gateway → Order-Product Service
  1. Validar input (Zod)
  2. Verificar productos en BD local
  3. HTTP GET inventory-service/inventory/check (stock check)
  4. Prisma transaction:
     a. Persistir Order + OrderItems
     b. Publicar OrderCreated → RabbitMQ (topic exchange 'orders', key 'order.created')
  5. Inventory Service consume 'order.#' → DecreaseStock
  [RIESGO: evento publicado DENTRO de la transacción — ver skill event-driven-outbox.md]
```

### 3. Registro de Usuario
```
Cliente → Gateway → Auth Service
  → Auth crea User en Users Service (HTTP interno)
  → Auth persiste AuthCredentials (hash scrypt) en MySQL
  → Auth retorna JWT
```

---

## Bases de Datos

| Servicio | BD | Puerto | ORM | Migraciones |
|---|---|---|---|---|
| Auth | MySQL 8 (`users_db`) | 3307 | TypeORM | Auto-sync |
| Users (nuevo) | DynamoDB Local / AWS | 8000 | AWS SDK v3 | Manual (scripts) |
| Inventory | PostgreSQL 15 (`inventory_db`) | 5434 | TypeORM | `migration:run` al inicio |
| Order-Product | PostgreSQL 15 (`order_product_db`) | 5432 | Prisma | `prisma db push --accept-data-loss` |

> **WARNING**: `prisma db push --accept-data-loss` en docker-compose-dev.yml puede causar pérdida de datos en ambientes compartidos.

---

## Comunicación entre Servicios

### Síncrona (HTTP)
- Gateway → Auth: validación de tokens JWT
- Order-Product → Inventory: verificación de stock (`GET /inventory/check`)
- Auth → Users Service: creación/lookup de usuarios

### Asíncrona (RabbitMQ)
- Order-Product **publica** `OrderCreated` y `OrderCancelled` → exchange `orders` (topic)
- Inventory **consume** `order.#` → cola `inventory_orders`
- Users (serverless) **publica** `UserCreated` → SQS (pendiente integración)

### Seguridad entre servicios
- Header `x-gateway-secret`: secreto compartido para verificar origen Gateway
- Servicios individuales validan este header via `gatewayMiddleware`
- **BUG CRÍTICO CONOCIDO**: En `ecommerce-inventory-service/src/infrastructure/middlewares/gatewayMiddleware.ts` línea 20, el middleware llama `next()` incluso cuando la validación falla (solo responde 403 pero NO hace return). Ver `questions-log.md` Q001.

---

## Criterios para Escalar Decisiones al Humano

Detén la ejecución y pide confirmación explícita cuando:

1. Cambios en el schema de base de datos con potencial pérdida de datos
2. Modificaciones al flujo de autenticación/autorización
3. Cambios en la configuración de RabbitMQ (exchanges, routing keys, queues)
4. Cualquier acción con impacto en facturación AWS
5. Modificaciones al `docker-compose-dev.yml` que afecten volúmenes de datos
6. Introducción de nuevas dependencias de seguridad (auth, crypto, JWT)
7. Cambios en variables de entorno críticas (`GATEWAY_SECRET`, `JWT_SECRET`)

---

## Convenciones de Código (Cross-Service)

### TypeScript
- Strict mode en todos los servicios
- No usar `any` en API pública; usar `unknown` + type guards
- DTOs con validación (Zod en order-product/serverless-users, class-validator en NestJS)
- Value Objects para datos de dominio (ver order-product-service)

### Naming
- Archivos: `kebab-case.ts` (services, repos, handlers) y `PascalCase.ts` (clases de dominio)
- Clases: `PascalCase`
- Funciones/variables: `camelCase`
- Constantes: `UPPER_SNAKE_CASE`

### Estructura por servicio (patrón predominante)
```
domain/[entity]/
  application/    # Use Cases, DTOs, validación, eventos
  domain/         # Entidades, interfaces de repositorio, Value Objects
  infrastructure/ # Repositorios concretos, controllers, routes
shared/           # Abstracciones compartidas dentro del servicio
```

### Errores
- Jerarquía de excepciones tipadas (DomainException → ApplicationException)
- No lanzar strings; siempre `Error` o excepciones tipadas
- Loggear con Winston (estructurado JSON en prod, colorizado en dev)

---

## Estado Actual y Pendientes Críticos

### Riesgos Activos
1. **[CRÍTICO]** Evento RabbitMQ publicado dentro de transacción Prisma — puede publicar sin confirmar o no publicar si falla la transacción. Ver `skills/event-driven-outbox.md`.
2. **[CRÍTICO]** Bug en `gatewayMiddleware.ts` de inventory-service — llama `next()` incluso en 403.
3. **[ALTO]** Caché de tokens en memoria del Gateway — no funciona con múltiples instancias.
4. **[ALTO]** `prisma db push --accept-data-loss` en dev compose — riesgo de pérdida de datos.
5. **[MEDIO]** Credenciales hardcodeadas en docker-compose-dev.yml (`root:root`, `user:password`).
6. **[MEDIO]** `/users` endpoint en Gateway no tiene `authMiddleware` ni rate limiting activos (comentados).
7. **[MEDIO]** `serverless-users-service` CORS configurado con `allowedOrigins: ["*"]` — excesivamente permisivo.
8. **[BAJO]** Rol de usuario hardcodeado como `'USER'` en `auth.service.ts` línea 62 — no usa el enum `Role`.

### Pendientes del TODO.md
- Outbox Pattern (garantía de entrega de eventos)
- Saga con compensación
- Reservas temporales de stock (evitar overselling)
- Idempotencia en consumidores
- Observabilidad completa en todos los servicios
- CI/CD con GitHub Actions
- Customer de Order-Product sincronizado con Users Service
- Dashboard en Grafana

---

## Quick Start para Agentes

1. Leer este `AGENTS.md` completo
2. Revisar todas las skills en `.agents/skills/`
3. Consultar `.agents/questions-log.md` para decisiones ya tomadas
4. Consultar `.agents/analysis-summary.md` para el estado actual
5. **Antes de cualquier cambio no trivial**: consultar el Routing System de skills
6. **Ante ambigüedad**: detener y preguntar, nunca asumir

---

## Maintenance Protocol

### Cuándo actualizar AGENTS.md:
- Nueva tecnología incorporada al stack
- Cambio arquitectónico significativo
- Reorganización de estructura de carpetas
- Nuevas convenciones validadas

### Cuándo actualizar Skills:
- Variación de patrón en el código real
- Refactor de implementación existente
- Nuevo patrón descubierto y validado

### Formato de commit al actualizar:
```
feat: [feature] + update skill [skill-name]
```
