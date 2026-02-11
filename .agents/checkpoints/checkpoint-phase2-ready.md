# Checkpoint — Fase 2: Bootstrap Completo, Listo para Implementación

**Date:** 2026-02-11
**Status:** Listo para continuar

---

## Estado del Bootstrap

- [x] AGENTS.md generado en raíz del proyecto
- [x] analysis-summary.md completo
- [x] questions-log.md — 5 preguntas **todas resueltas** (✅)
- [x] 6 skills generadas y validadas
- [x] Checkpoint fase 1

---

## Decisiones Tomadas (questions-log.md)

| Q    | Decisión                                                                                                 |
| ---- | -------------------------------------------------------------------------------------------------------- |
| Q001 | Fix mínimo en `gatewayMiddleware.ts` — agregar `return` después del 403                                  |
| Q002 | Implementar Outbox Pattern completo con worker poller en order-product-service                           |
| Q003 | `ecommerce-users-service` (NestJS legacy) puede eliminarse — serverless es el definitivo                 |
| Q004 | CORS no aplica en prod — serverless-users-service solo recibe llamadas internas                          |
| Q005 | Customer en Order-Product es proyección local, sincronizado via evento `UserCreated` desde Users Service |

---

## Tareas Listas para Implementar (priorizadas)

### PRIORIDAD ALTA

#### T002 — Implementar Outbox Pattern en order-product-service

- **Archivos a modificar:**
  - `src/domain/order/application/CreateOrUpdateOrderUseCase.ts` — reemplazar publish directo por save en Outbox
  - `src/domain/order/application/events/OrderEventPublisher.ts` — puede quedar para el worker
- **Archivos a crear:**
  - `src/shared/infrastructure/outbox/OutboxRepository.ts`
  - `src/shared/infrastructure/outbox/OutboxWorker.ts` — poller que lee `published=false` y publica a RabbitMQ
  - `src/shared/infrastructure/outbox/OutboxScheduler.ts` — scheduler del worker (setInterval o cron)
- **Skill:** `event-driven-outbox.md`
- **Impacto:** Consistencia garantizada entre orden persistida y evento publicado

#### T003 — Flujo UserCreated → Customer en Order-Product

- **Contexto:** Users Service ya tiene `SQSMessagePublisher` para publicar `UserCreated`
- **Lo que falta:**
  1. Order-Product debe consumir el evento `UserCreated` (desde SQS o via RabbitMQ si se migra)
  2. Al recibir el evento, ejecutar `CreateCustomerUseCase` automáticamente
- **Decisión pendiente:** ¿El evento `UserCreated` llega via SQS (AWS) o se migra a RabbitMQ para uniformidad?
- **Skill:** `event-driven-outbox.md`, `ddd-architecture.md`

### PRIORIDAD MEDIA

#### T004 — Deprecar ecommerce-users-service legacy

- Verificar que Auth Service apunta al serverless-users-service (no al legacy)
- Eliminar o archivar `ecommerce-users-service/`

#### T005 — CORS en serverless-users-service para producción

- Remover configuración CORS o restringir a `stage != prod` en `serverless.yml`

---

## Contexto Técnico Clave

### Flujo de autenticación actual

```
POST /auth/signup → API Gateway → Auth Service
  → Auth llama a Users Service (HTTP) para crear user
  → Auth guarda AuthCredentials (scrypt hash)
  → Auth retorna JWT
```

### Flujo de orden actual (con problema)

```
POST /ecommerce/orders → API Gateway (auth) → Order-Product Service
  → Valida productos en BD local
  → HTTP GET inventory-service/inventory/check (stock check)
  → Prisma transaction {
      save(order)
      publishOrderCreated() ← PROBLEMA: dentro de transacción
    }
  → Inventory Service consume OrderCreated → DecreaseStock
```

### Flujo de orden objetivo (con Outbox)

```
POST /ecommerce/orders → API Gateway (auth) → Order-Product Service
  → Valida productos en BD local
  → HTTP GET inventory-service/inventory/check (stock check)
  → Prisma transaction {
      save(order)
      save(outbox_entry, published=false) ← SOLO ESTO
    }
  → OutboxWorker (proceso independiente):
      poll outbox WHERE published=false
      → publishOrderCreated() → RabbitMQ
      → UPDATE outbox SET published=true
  → Inventory Service consume OrderCreated → DecreaseStock
```

### Evento UserCreated (flujo objetivo Q005)

```
POST /auth/signup → Users Service crea user
  → Users Service publica UserCreated (SQS actualmente)
  → Order-Product consume UserCreated
  → CreateCustomerUseCase(userId, name, email, address)
  → Customer disponible para crear órdenes
```

---

## Skills Disponibles

| Archivo                                   | Cubre                                                  |
| ----------------------------------------- | ------------------------------------------------------ |
| `.agents/skills/api-gateway-auth.md`      | Auth centralizada, token cache, rate limiting, headers |
| `.agents/skills/event-driven-outbox.md`   | RabbitMQ, Outbox Pattern, implementación pendiente     |
| `.agents/skills/ddd-architecture.md`      | DDD completo, Value Objects, Use Cases, UoW            |
| `.agents/skills/multi-db-strategy.md`     | MySQL/PostgreSQL/DynamoDB, ORMs, migraciones           |
| `.agents/skills/observability-stack.md`   | OTel, Prometheus, Grafana, Loki                        |
| `.agents/skills/security-service-mesh.md` | x-gateway-secret, headers de contexto, bug conocido    |

---

## Para Retomar en Nuevo Chat

1. Leer `AGENTS.md` (raíz del proyecto)
2. Leer este checkpoint
3. Revisar `questions-log.md` — todas las decisiones ya están registradas
4. T002
5. Consultar la skill correspondiente antes de implementar
