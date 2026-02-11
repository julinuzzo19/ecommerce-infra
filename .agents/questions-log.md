# Questions Log — Decisiones y Ambigüedades

## Q002 — Outbox Table existe pero no se usa en CreateOrUpdateOrderUseCase

- **Date:** 2026-02-11
- **Phase:** Bootstrap / Data / Business Logic
- **Status:** ✅ Resolved

**Context:** `ecommerce-order-product-service`

**Encontré:**

- El schema Prisma tiene el modelo `Outbox` con campos `published`, `publishedAt`, `payload`
- El `CreateOrUpdateOrderUseCase.ts:47-56` publica el evento RabbitMQ **directamente** dentro de la transacción Prisma
- El TODO.md menciona explícitamente "Outbox Pattern (garantía de entrega)"

```typescript
// CreateOrUpdateOrderUseCase.ts:43-57
await this.unitOfWork.execute(async (tx) => {
  await this.orderRepository.save(order, tx);
  // ← RabbitMQ publish dentro de transacción: INCONSISTENCIA POTENCIAL
  await this.orderPublisher.publishOrderCreated({ ... });
});
```

**Pregunta:**
¿Cuál es la prioridad de implementar el Outbox Pattern completo?

**Opciones:**

- A) Alta prioridad: implementar ahora — guardar en Outbox dentro de la transacción y publicar con un worker/poller externo
- B) Media prioridad: crear issue/task pero mantener el código actual
- C) El comportamiento actual es aceptable para el MVP y el Outbox se implementa luego

**Answer:** Implementar worker poller (patrón correcto). La transacción solo guarda en Outbox (`published: false`). Un worker independiente lee la tabla y publica a RabbitMQ, marcando `published: true`. Garantía de entrega real.

**Impacto:**

- Afecta skill: `event-driven-outbox.md`
- Riesgo: mensajes duplicados, mensajes perdidos, inconsistencia entre orden persistida y evento publicado

---

## Q003 — Migración en curso: ecommerce-users-service → serverless-users-service

- **Date:** 2026-02-11
- **Phase:** Bootstrap / Architecture
- **Status:** ✅ Resolved

**Context:** Existe `ecommerce-users-service/` (NestJS + MySQL) y `serverless-users-service/` (Lambda + DynamoDB)

**Encontré:**

- `docker-compose-dev.yml` levanta `serverless-users-service` (no el legacy)
- El Auth Service hace HTTP a un Users Service para CRUD de usuarios
- No está claro qué URL usa el Auth Service en desarrollo: ¿el serverless-offline o el legacy?
- `ecommerce-users-service/` tiene `Dockerfile.dev` pero no está en el docker-compose actual
- TODO.md menciona "CUSTOMER DE ORDER-PRODUCT SE DEBE SINCRONIZAR CON USERS SERVICE"

**Pregunta:**
¿Cuál es el estado de la migración? ¿El `ecommerce-users-service/` legacy puede eliminarse?

**Opciones:**

- A) Legacy puede eliminarse — serverless-users-service es el definitivo
- B) Legacy sigue en uso para Auth Service; serverless es experimental
- C) Coexisten con propósitos diferentes

**Answer:** `ecommerce-users-service` (legacy NestJS + MySQL) puede eliminarse. `serverless-users-service` (Lambda + DynamoDB) es el servicio definitivo. El `ecommerce-users-service/` puede deprecarse/borrarse.

**Impacto:**

- Afecta skill: `multi-db-strategy.md`
- Riesgo: duplicación de lógica, inconsistencia de datos entre MySQL y DynamoDB

---

## Q004 — CORS wildcard en serverless-users-service para producción

- **Date:** 2026-02-11
- **Phase:** Bootstrap / Security
- **Status:** ✅ Resolved

**Context:** `serverless-users-service/serverless.yml:49`

**Encontré:**

```yaml
httpApi:
  cors:
    allowedOrigins:
      - "*"
    allowedHeaders:
      - "*"
    allowedMethods:
      - "*"
```

**Pregunta:**
¿Cuáles son los orígenes permitidos para producción?

**Opciones:**

- A) Especificar dominio del frontend en `.env.prod` y configurar por stage
- B) El servicio Users solo es accesible internamente (sin CORS necesario para prod)
- C) Mantener wildcard aceptando el riesgo (solo para etapa MVP)

**Answer:** El servicio Users solo recibe llamadas internas del API Gateway, nunca directamente del browser. CORS no aplica en producción — remover o no configurar CORS en el stage de producción.

**Impacto:**

- Afecta skill: `api-gateway-auth.md`

---

## Q005 — Customer en Order-Product Service vs Users Service: sincronización

- **Date:** 2026-02-11
- **Phase:** Bootstrap / Business Logic
- **Status:** ✅ Resolved

**Context:** `ecommerce-order-product-service/src/domain/customer/`

**Encontré:**

- El Order-Product Service tiene su propio modelo `Customer` con `CreateCustomerUseCase`
- El Users Service gestiona también datos de usuario
- No hay sincronización visible entre ambos (sin eventos, sin HTTP)
- TODO.md: "CUSTOMER DE ORDER-PRODUCT SE DEBE SINCRONIZAR CON USERS SERVICE"

**Pregunta:**
¿Cómo debe ser la sincronización? ¿El Customer en Order-Product es una proyección del User?

**Opciones:**

- A) Event-driven: Users publica `UserCreated` → Order-Product crea Customer automáticamente
- B) API call: al crear orden, Order-Product llama a Users Service para obtener datos
- C) Customer es una entidad independiente y el usuario la crea explícitamente

**Answer:** Mantener Customer en Order-Product como proyección local. El flujo correcto:

1. `POST /auth/signup` → Auth crea User en Users Service
2. Users Service publica evento `UserCreated` (via SQS ya implementado)
3. Order-Product consume `UserCreated` → ejecuta `CreateCustomerUseCase` automáticamente
4. El Customer local tiene solo los datos que el dominio de órdenes necesita (nombre, email, dirección)
5. Order-Product queda desacoplado de Users Service en el flujo de creación de órdenes

**Impacto:**

- Afecta skill: `event-driven-outbox.md`, `ddd-architecture.md`
- Requiere: Order-Product consuma el evento `UserCreated` de SQS (o RabbitMQ si se migra)
