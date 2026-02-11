---
name: security-service-mesh
description: Seguridad en la comunicación entre microservicios — x-gateway-secret, headers de contexto de usuario, validación de origen, y bug conocido en gatewayMiddleware de inventory
category: security
priority: critical
applies_to:
  - ecommerce-api-gateway/src/middleware/auth.middleware.ts
  - ecommerce-inventory-service/src/infrastructure/middlewares/gatewayMiddleware.ts
  - ecommerce-order-product-service/src/shared/infrastructure/external-services/
last_validated: 2026-02-11
conflicts_with: []
requires_human_approval: true
---

# Skill: Security Service Mesh

## Descripción

Los microservicios no son accesibles directamente desde internet (solo via API Gateway en el diseño correcto). La autenticación entre servicios usa un secreto compartido via header `x-gateway-secret`.

---

## Modelo de Seguridad

```
Internet
  └── API Gateway (:3000)  [único punto de entrada]
        ├── Valida JWT del usuario (auth.middleware.ts)
        ├── Inyecta headers de contexto
        └── Inyecta x-gateway-secret
              ├── Auth Service (:3010)    [no valida x-gateway-secret actualmente]
              ├── Inventory Service (:3011) [valida x-gateway-secret — con BUG]
              ├── Order-Product Service (:3600) [pendiente validar]
              └── Users Service (Lambda) [sin middleware de validación]
```

---

## Headers de Seguridad Propagados

| Header | Descripción | Fuente |
|---|---|---|
| `x-gateway-secret` | Secreto compartido para verificar origen | Gateway (config.security.gatewaySecret) |
| `x-user-id` | ID del usuario autenticado | JWT payload.sub |
| `x-user-email` | Email del usuario autenticado | JWT payload.email |
| `x-user-role` | Rol del usuario autenticado | JWT payload.role |
| `x-request-id` | ID único de la request para trazabilidad | requestIdMiddleware |

---

## Bug Crítico en gatewayMiddleware (Inventory Service)

**Archivo:** `ecommerce-inventory-service/src/infrastructure/middlewares/gatewayMiddleware.ts:20`

```typescript
// CÓDIGO ACTUAL CON BUG
export const gatewayDetectionMiddleware = (req, res, next) => {
  const gatewayHeader = req.headers['x-gateway-secret'];

  if (gatewayHeader !== gatewaySecretEnv) {
    res.status(403).json({ message: 'Forbidden: Invalid gateway secret' });
    // ← FALTA return aquí
  }

  next(); // ← Se ejecuta incluso cuando falla la validación
};
```

**Consecuencia:** Una request con secret incorrecto recibe 403 en el body pero el middleware continúa. Express puede lanzar "Cannot set headers after they are sent" y la request puede ser procesada parcialmente.

**Fix correcto:**
```typescript
export const gatewayDetectionMiddleware = (req, res, next) => {
  const gatewayHeader = req.headers['x-gateway-secret'];

  if (gatewayHeader !== GATEWAY_SECRET) {
    res.status(403).json({ message: 'Forbidden: Invalid gateway secret' });
    return;  // ← Detener ejecución aquí
  }

  next();
};
```

> **Ver Q001 en questions-log.md** para aprobación antes de aplicar el fix.

---

## Cómo Leer el Contexto del Usuario en un Servicio

```typescript
// En cualquier controller downstream
const userId    = req.headers['x-user-id'] as string;
const userEmail = req.headers['x-user-email'] as string;
const userRole  = req.headers['x-user-role'] as string;

// Verificar que viene del Gateway (no directamente)
const fromGateway = req.headers['x-gateway-secret'] === GATEWAY_SECRET;
```

---

## Rate Limiting (API Gateway)

```typescript
// auth routes (/auth/*)
windowMs: 15 * 60 * 1000   // 15 minutos
maxRequests: 20

// protected routes (/ecommerce/*, /inventory/*)
windowMs: 60 * 1000         // 1 minuto
maxRequests: 300
```

El rate limiting usa IP como key por defecto (`customKeyGenerator.ts`).

---

## Headers de Seguridad HTTP (Helmet)

API Gateway usa `helmet@8.1.0` (Express 5). Cabeceras establecidas:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Strict-Transport-Security`
- `Content-Security-Policy`
- `X-XSS-Protection` (legacy)

También usa `stripSensitiveResponseHeaders` para limpiar headers sensibles de respuestas proxiadas (implementado en `utils/stripSensitiveResponseHeaders.ts`).

---

## Riesgos de Seguridad Activos

| Riesgo | Severidad | Estado |
|---|---|---|
| Bug gatewayMiddleware sin return | Crítico | Pendiente fix (Q001) |
| /users sin authMiddleware | Alto | Comentado intencionalmente — verificar |
| Token cache en memoria (no revocable distribuido) | Alto | Conocido |
| CORS wildcard en serverless-users | Medio | Pendiente resolución (Q004) |
| Credenciales dev en docker-compose | Medio | Aceptable para dev |
| Rol hardcodeado como 'USER' | Bajo | Refactor pendiente |

---

## Reglas para Agentes

1. **NUNCA** exponer secretos (`GATEWAY_SECRET`, `JWT_SECRET`) en logs, respuestas o commits
2. Los servicios deben rechazar requests sin `x-gateway-secret` válido (una vez corregido el bug)
3. No mover rutas de protegidas a públicas sin aprobación explícita
4. No cambiar el valor de `GATEWAY_SECRET` sin coordinar todos los servicios simultáneamente
5. Los headers `x-user-*` son de confianza solo porque vienen del Gateway; NO confiar si llegan directamente de un cliente externo
6. Al agregar un nuevo microservicio, implementar `gatewayMiddleware` correctamente desde el inicio

---

## Update History

| Date | Change | Author |
|---|---|---|
| 2026-02-11 | Creación inicial por bootstrap. Bug gatewayMiddleware documentado. | Agent |
