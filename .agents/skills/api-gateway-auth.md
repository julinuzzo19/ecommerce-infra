---
name: api-gateway-auth
description: Autenticación centralizada en el API Gateway con refresh token, Redis cache distribuido, cookie HttpOnly, propagación de contexto de usuario via headers y rate limiting diferenciado
category: security
priority: critical
applies_to:
  - ecommerce-api-gateway/src/middleware/auth.middleware.ts
  - ecommerce-api-gateway/src/utils/auth.cache.ts
  - ecommerce-api-gateway/src/config/redis.ts
  - ecommerce-api-gateway/src/routes/proxy.routes.ts
  - ecommerce-auth-service/src/auth/auth.controller.ts
  - ecommerce-auth-service/src/auth/auth.service.ts
  - ecommerce-auth-service/src/auth/refresh-token.entity.ts
last_validated: 2026-03-11
conflicts_with: []
requires_human_approval: true
---

# Skill: API Gateway Auth

## Descripción

El API Gateway actúa como punto único de entrada y autoridad de autenticación. Valida tokens JWT delegando al Auth Service, cachea la validación en **Redis distribuido**, y soporta renovación automática via **refresh token con rotación y detección de robo**.

---

## Flujo completo de autenticación

### Login
```
POST /auth/login
← Set-Cookie: access_token=JWT; HttpOnly; Secure; SameSite=Strict             (cookie: 30d, JWT: 15min)
← Set-Cookie: refresh_token=UUID; HttpOnly; Secure; SameSite=Strict; Path=/auth/refresh  (7 días)
```
El refresh token se guarda hasheado (SHA-256) en tabla MySQL `refresh_token`.

### Request normal (access token vigente)
```
Request entrante
  ├── cookieToHeaderMiddleware: lee cookie access_token → Authorization: Bearer <jwt>
  ├── authMiddleware:
  │   ├── x-gateway-secret correcto → isInternalService = true → next()
  │   └── Authorization: Bearer <jwt>
  │       ├── Hit Redis (key: token:<jwt>, TTL: 5min) → set headers → next()
  │       └── Miss Redis → axios.get auth-service/auth/validate (timeout: 5s)
  │           ├── valid: true → setex Redis 5min → set headers → next()
  │           └── valid: false → 401
```

### Renovación (access token expirado)
```
POST /auth/refresh  (cookie refresh_token se envía automáticamente por Path=/auth/refresh)
Auth Service:
  1. SHA-256(raw_token) → busca en DB
  2. ¿revoked? → revocar familia entera → 401 (detección de robo)
  3. ¿expirado? → revocar → 401
  4. revokeById(actual) + generateRefreshToken(mismo familyId)
  5. signAsync(nuevo JWT)
← Set-Cookie: access_token=JWT nuevo
← Set-Cookie: refresh_token=UUID nuevo
```

### Logout
```
GET /auth/logout
Auth Service: revokeRefreshToken(raw) → revocado en DB
← clearCookie(access_token)
← clearCookie(refresh_token)
```

---

## Headers Propagados a Microservicios

```typescript
req.headers['x-user-id']        = user.id;
req.headers['x-user-email']     = user.email;
req.headers['x-user-role']      = user.role;
req.headers['x-gateway-secret'] = config.security.gatewaySecret;
```

---

## Redis Cache (distribuido)

```
Archivos:
  ecommerce-api-gateway/src/config/redis.ts       — cliente ioredis con backoff
  ecommerce-api-gateway/src/utils/auth.cache.ts   — getCachedUser / setCachedUser
```

- `lazyConnect: true` — no conecta al instanciar, se dispara en `server.ts`
- `retryStrategy`: backoff exponencial + jitter (±10%), techo 30s, max 10 intentos
- Eventos de ciclo de vida logueados: connect, ready, error, close, reconnecting, end
- Fallback silencioso: si Redis no responde, llama al Auth Service directamente

**Clave Redis:** `token:<jwt>` → JSON del UserInfo
**TTL:** 300 segundos (5 minutos)

---

## Refresh Token — Entidad DB (MySQL)

```
Tabla: refresh_token (TypeORM auto-sync en dev)
Archivo: ecommerce-auth-service/src/auth/refresh-token.entity.ts
```

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | uuid PK | Identificador del registro |
| `userId` | uuid | Usuario dueño del token |
| `tokenHash` | string | SHA-256 del token opaco — nunca se persiste el raw |
| `familyId` | uuid | Agrupa tokens de una misma sesión |
| `expiresAt` | Date | 7 días desde emisión |
| `revoked` | boolean | Default false |

**Detección de robo:** si se intenta usar un token con `revoked: true` → se revoca toda la familia (`familyId`) → logout forzado de todos los dispositivos de esa sesión.

---

## Configuración de Cookies

```typescript
// access_token
{ httpOnly: true, secure: prod, sameSite: 'strict', maxAge: 30días }
// El JWT interno expira en JWT_EXPIRES_IN (default: 15m)

// refresh_token
{ httpOnly: true, secure: prod, sameSite: 'strict', maxAge: 7días, path: '/auth/refresh' }
// Path restringido: la cookie solo se envía al endpoint de renovación
```

---

## Variables de Entorno Requeridas

| Variable | Servicio | Descripción |
|---|---|---|
| `REDIS_HOST` | Gateway | Host Redis (docker: `redis`) |
| `REDIS_PORT` | Gateway | Puerto Redis (default: `6379`) |
| `JWT_EXPIRES_IN` | Auth | TTL del access token (default: `15m`) |
| `JWT_SECRET` | Auth | Secreto para firmar JWT |
| `GATEWAY_SECRET` | Ambos | Secreto compartido comunicación interna |

---

## Rutas y Protección

| Ruta | Auth | Rate Limit |
|---|---|---|
| `GET /health` | Pública | — |
| `/auth/*` | Pública | authRateLimiter (20/15min) |
| `/ecommerce/*` | authMiddleware | protectedRateLimiter (300/1min) |
| `/inventory/*` | authMiddleware | protectedRateLimiter (300/1min) |
| `/users/*` | **DESHABILITADO** | **DESHABILITADO** |

> **ADVERTENCIA**: Las rutas `/users/*` tienen `authMiddleware` y `protectedRateLimiter` comentados.

---

## Reglas para Agentes

1. **Nunca exponer** `x-gateway-secret` ni `tokenHash` en logs o respuestas
2. **Siempre propagar** los 4 headers de contexto en autenticación exitosa
3. Los microservicios NO deben validar JWT — solo leer los headers del Gateway
4. El refresh token se hashea antes de guardar — nunca persistir el raw token
5. Si se rota el refresh token, siempre mantener el mismo `familyId`
6. Redis es opcional — el gateway arranca en modo degradado si no responde
7. Si se añade una nueva ruta protegida: `authMiddleware` + `protectedRateLimiter`
8. Antes de modificar el flujo de autenticación, requerir aprobación humana

---

## Manejo de Errores

| Condición | Código |
|---|---|
| Auth Service no disponible (ECONNREFUSED) | 503 |
| Timeout Auth Service (>5s) | 504 |
| Token inválido o expirado | 401 |
| Refresh token reutilizado (posible robo) | 401 + revocación familia |
| Refresh token no proporcionado | 401 |

---

## Comandos Makefile

```bash
make redis-cli    # [83] Shell interactivo Redis
make redis-flush  # [84] Limpiar caché tokens (invalida sesiones activas)
```

---

## Update History

| Date | Change | Author |
|---|---|---|
| 2026-02-11 | Creación inicial por bootstrap | Agent |
| 2026-03-11 | Refresh token + Redis distribuido + cookie HttpOnly + retries/backoff | Agent |
