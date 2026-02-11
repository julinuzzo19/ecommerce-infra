# Analysis Summary — Ecommerce Microservices Bootstrap

**Date:** 2026-02-11
**Phase:** Bootstrap completo (Fases 1 y 2)
**Status:** Contrato técnico inicial generado

---

## Resumen Ejecutivo

Sistema de e-commerce distribuido basado en microservicios Node.js/TypeScript. Arquitectura híbrida que combina servicios tradicionales containerizados (Docker) con funciones serverless (AWS Lambda). El proyecto está en desarrollo activo con deuda técnica identificada en puntos críticos de consistencia de datos.

---

## Microservicios Identificados

| Servicio | Framework | BD | Puerto | Estado |
|---|---|---|---|---|
| API Gateway | Express 5 | — | 3000 | Funcional |
| Auth Service | NestJS 10 | MySQL 8 | 3010 | Funcional |
| Users Service (legacy) | NestJS 10 | MySQL 8 | — | En transición |
| Users Service (nuevo) | Lambda + Serverless 4 | DynamoDB | 4000 (offline) | En desarrollo |
| Inventory Service | Express 5 | PostgreSQL 15 | 3011 | Funcional |
| Order-Product Service | Express 5 + Prisma | PostgreSQL 15 | 3600 | Funcional |

---

## Patrones Arquitectónicos Detectados

### 1. DDD (Domain-Driven Design)
**Evidencia real:** `ecommerce-order-product-service/src/domain/`
- Estructura `application / domain / infrastructure` por entidad
- Value Objects: `CustomId`, `Address`, `Email`, `ProductCategory`
- Excepciones tipadas por capa: `DomainException` → `ApplicationException`
- Unit of Work con Prisma Interactive Transactions
- Repositorios con interfaces abstractas

**Parcialmente aplicado en:** `ecommerce-inventory-service/src/` (CQRS commands/queries, pero sin Value Objects)

**No aplicado en:** `ecommerce-auth-service` (estructura NestJS estándar sin DDD)

### 2. CQRS (Command Query Responsibility Segregation)
**Evidencia real:** `ecommerce-inventory-service/src/application/`
- `commands/` para operaciones de escritura (CreateInventoryProduct, DecreaseStock, ReleaseStock)
- `queries/` para operaciones de lectura (GetProductInventory, GetStockAvailableOrder)
- Sin separación de base de datos read/write (misma PostgreSQL)

### 3. Outbox Pattern (INCOMPLETO)
**Evidencia real:** `schema.prisma` tiene modelo `Outbox` con campos `published`, `publishedAt`
**Problema crítico:** El `CreateOrUpdateOrderUseCase` publica el evento RabbitMQ directamente dentro de la transacción Prisma, sin usar el Outbox table como relay.
- Riesgo: si RabbitMQ falla durante la transacción, el mensaje se pierde aunque la orden se persista.
- Riesgo contrario: si la transacción falla después de publicar, el evento ya salió sin orden persistida.

### 4. Event-Driven Architecture
**Publisher:** `OrderEventPublisher` → exchange `orders` (topic), routing keys `order.created`, `order.cancelled`
**Consumer:** `OrderEventConsumer` → routing key `order.#` (todos los eventos de orden)
**Formato:** JSON serializado, `persistent: true`, `contentType: application/json`

### 5. API Gateway Pattern
**Implementación real:**
- Proxy reverso con `http-proxy-middleware`
- Autenticación centralizada por Bearer token
- Caché de tokens en memoria (Map, 5 min TTL) — no distribuida
- Rate limiting diferenciado: auth (20 req/15min), protegido (300 req/1min)
- Propagación de contexto de usuario via headers (`x-user-id`, `x-user-email`, `x-user-role`)
- Header `x-gateway-secret` para identificar requests internas

### 6. Serverless con Serverless Framework v4
**Stack:** AWS Lambda + DynamoDB + SQS + API Gateway HTTP
**Desarrollo local:** serverless-offline + DynamoDB local (Docker)
**Build:** ESBuild (bundle: true, target: node20, arm64)
**CORS:** Wildcard `*` — riesgo de seguridad para producción

---

## Stack de Observabilidad

Completamente configurado en docker-compose-dev.yml:
- **OpenTelemetry Collector** → recolecta traces de todos los servicios
- **Grafana Tempo** → almacena y consulta distributed traces
- **Prometheus** → métricas (scraping configurado)
- **Grafana** → visualización (dashboard pendiente de diseño)
- **Loki + Promtail** → agregación de logs desde Docker

**Parcialmente instrumentado:** solo `ecommerce-order-product-service` tiene New Relic APM.
**Pendiente:** instrumentación OTel en el resto de servicios.

---

## Riesgos Críticos Detectados

### CRÍTICO — Consistencia de eventos (ver Q001 en questions-log.md)
El evento RabbitMQ se publica **dentro** de la transacción Prisma en `CreateOrUpdateOrderUseCase.ts:47-56`. El modelo `Outbox` existe en el schema pero no se usa. Esto viola la atomicidad: el evento puede publicarse sin que la transacción se confirme, o perderse si RabbitMQ no está disponible.

**Archivo:** `ecommerce-order-product-service/src/domain/order/application/CreateOrUpdateOrderUseCase.ts:43-57`

### CRÍTICO — Bug en gateway middleware de Inventory
En `ecommerce-inventory-service/src/infrastructure/middlewares/gatewayMiddleware.ts:20`, el código responde 403 pero NO hace `return` antes de llamar `next()`. Cualquier request con secret incorrecto continúa procesándose después de enviar la respuesta de error.

**Archivo:** `ecommerce-inventory-service/src/infrastructure/middlewares/gatewayMiddleware.ts:20-24`

### ALTO — Token cache no distribuida
El gateway cachea tokens JWT en `Map<string, TokenCacheEntry>` en memoria del proceso. Con múltiples instancias del gateway, un token revocado en Auth Service sigue siendo válido en instancias que lo tienen cacheado.

**Archivo:** `ecommerce-api-gateway/src/middleware/auth.middleware.ts:30`

### ALTO — `prisma db push --accept-data-loss` en docker-compose
El servicio `ecommerce-order-product-service` usa `prisma db push --accept-data-loss` al iniciar en dev. Esto puede destruir datos sin advertencia.

**Archivo:** `docker-compose-dev.yml:185`

### MEDIO — `/users` sin autenticación en Gateway
Las rutas `authMiddleware` y `protectedRateLimiter` están comentadas en el proxy `/users`.

**Archivo:** `ecommerce-api-gateway/src/routes/proxy.routes.ts:88-90`

### MEDIO — Credenciales débiles en docker-compose
Bases de datos usan `root:root` y RabbitMQ usa `user:password`. Aceptable solo para desarrollo, pero debe asegurarse que el `.env.prod` no los replique.

### MEDIO — CORS wildcard en serverless-users-service
`serverless.yml:49` usa `allowedOrigins: ["*"]` — inaceptable en producción.

### BAJO — Rol hardcodeado en Auth Service
`auth.service.ts:62`: `role: 'USER'` — ignora el enum `Role` importado. No impacta actualmente porque solo hay un rol, pero es un risk de mantenibilidad.

---

## Decisiones Arquitectónicas Observadas

1. **Separación de Auth y Users**: Auth Service gestiona credenciales y JWT; Users Service gestiona datos del perfil. Comunicación HTTP síncrona entre ellos.

2. **Migración en curso**: `ecommerce-users-service` (NestJS+MySQL) siendo reemplazado por `serverless-users-service` (Lambda+DynamoDB). El docker-compose ya apunta al serverless.

3. **No hay service discovery**: URLs hardcodeadas via variables de entorno en el Gateway.

4. **No hay circuit breaker**: Fallos en Auth Service o Inventory Service propagan errores directamente.

5. **Outbox model existe pero no está integrado**: El schema Prisma tiene la tabla `outbox`, señal de que el patrón está planificado pero no implementado.

---

## Archivos Clave de Referencia

| Archivo | Importancia |
|---|---|
| `RESUME.md` | Arquitectura documentada manualmente |
| `docker-compose-dev.yml` | Fuente de verdad del entorno completo |
| `ecommerce-api-gateway/src/middleware/auth.middleware.ts` | Flujo de autenticación central |
| `ecommerce-api-gateway/src/routes/proxy.routes.ts` | Routing del gateway |
| `ecommerce-order-product-service/src/domain/order/application/CreateOrUpdateOrderUseCase.ts` | Flujo crítico de creación de orden |
| `ecommerce-order-product-service/src/shared/infrastructure/db/prisma/schema.prisma` | Schema de BD del servicio más complejo |
| `serverless-users-service/serverless.yml` | Configuración Lambda/DynamoDB |
| `observability/otel-collector-config.yml` | Pipeline de observabilidad |
