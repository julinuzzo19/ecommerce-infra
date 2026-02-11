---
name: api-gateway-auth
description: Patrón de autenticación centralizada en el API Gateway, token cache en memoria, propagación de contexto de usuario via headers, y rate limiting diferenciado
category: security
priority: critical
applies_to:
  - ecommerce-api-gateway/src/middleware/auth.middleware.ts
  - ecommerce-api-gateway/src/routes/proxy.routes.ts
  - ecommerce-api-gateway/src/config/config.ts
last_validated: 2026-02-11
conflicts_with: []
requires_human_approval: true
---

# Skill: API Gateway Auth

## Descripción

El API Gateway actúa como punto único de entrada y autoridad de autenticación. Valida tokens JWT delegando al Auth Service y cachea la validación para optimizar rendimiento.

---

## Implementación Real

### Flujo de Autenticación

```
Request entrante
  ├── Tiene header x-gateway-secret?
  │   ├── Sí + valor correcto → isInternalService = true → next()
  │   └── Sí + valor incorrecto → sigue al paso 2 (no rechaza aún)
  └── Tiene header Authorization: Bearer <token>?
      ├── No → 401 Unauthorized
      ├── Sí → ¿token en cache y no expirado?
      │   ├── Sí → set headers → next()
      │   └── No → axios.get auth-service/auth/validate (timeout: 5s)
      │       ├── valid: true → cache (5min) → set headers → next()
      │       └── valid: false → 401 Unauthorized
```

### Headers Propagados a Microservicios

```typescript
req.headers['x-user-id']        = user.id;
req.headers['x-user-email']     = user.email;
req.headers['x-user-role']      = user.role;
req.headers['x-gateway-secret'] = config.security.gatewaySecret;
```

Todos los microservicios downstream reciben el contexto del usuario autenticado sin necesidad de validar el JWT nuevamente.

### Token Cache

```typescript
// ecommerce-api-gateway/src/middleware/auth.middleware.ts:30
const tokenCache = new Map<string, TokenCacheEntry>();
// TTL: 5 minutos
// Limpieza: cada 60 segundos
```

**Limitación conocida:** Cache en memoria del proceso. No funciona con múltiples instancias del gateway. Para escalar horizontalmente, migrar a Redis (ver Q003 en questions-log.md).

### Rate Limiting Diferenciado

```typescript
// ecommerce-api-gateway/src/config/config.ts:54-70
auth:      { windowMs: 15min, maxRequests: 20  }  // Rutas /auth/*
protected: { windowMs: 1min,  maxRequests: 300 }  // Rutas /ecommerce/*, /inventory/*
```

### Rutas y Protección

| Ruta | Auth | Rate Limit |
|---|---|---|
| `GET /health` | Pública | — |
| `/auth/*` | Pública | authRateLimiter (20/15min) |
| `/ecommerce/*` | authMiddleware | protectedRateLimiter (300/1min) |
| `/inventory/*` | authMiddleware | protectedRateLimiter (300/1min) |
| `/users/*` | **DESHABILITADO** | **DESHABILITADO** |

> **ADVERTENCIA**: Las rutas `/users/*` tienen `authMiddleware` y `protectedRateLimiter` comentados. Ver `proxy.routes.ts:88-90`.

---

## Reglas para Agentes

1. **Nunca exponer** `x-gateway-secret` en logs o respuestas
2. **Siempre propagar** los 4 headers de contexto cuando se autentique exitosamente
3. Si se añade una nueva ruta protegida, aplicar `authMiddleware` + `protectedRateLimiter`
4. El token cache asume una sola instancia; documentar si se escala horizontalmente
5. Los microservicios NO deben validar JWT — solo leer los headers propagados por el Gateway
6. Antes de deshabilitar o modificar authMiddleware, requerir aprobación humana

---

## Manejo de Errores del Auth Service

| Condición | Código respuesta |
|---|---|
| Auth Service no disponible (ECONNREFUSED) | 503 Service Unavailable |
| Timeout (>5s) | 504 Gateway Timeout |
| Token inválido (401 del auth service) | 401 Unauthorized |
| Token inválido (válido: false en body) | 401 Unauthorized |

---

## Update History

| Date | Change | Author |
|---|---|---|
| 2026-02-11 | Creación inicial por bootstrap | Agent |
