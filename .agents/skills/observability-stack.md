---
name: observability-stack
description: Stack de observabilidad completo — OpenTelemetry Collector, Grafana Tempo (traces), Prometheus (métricas), Grafana (visualización), Loki + Promtail (logs)
category: config
priority: medium
applies_to:
  - observability/
  - docker-compose-dev.yml
last_validated: 2026-02-11
conflicts_with: []
requires_human_approval: false
---

# Skill: Observability Stack

## Descripción

Stack de observabilidad completo configurado para desarrollo local con docker-compose. Basado en el stack Grafana (Tempo + Loki + Prometheus + Grafana) con OpenTelemetry como pipeline de ingesta.

---

## Componentes y Puertos

| Componente | Imagen | Puerto | Función |
|---|---|---|---|
| OTel Collector | `otel/opentelemetry-collector-contrib:0.91.0` | 4317 (gRPC), 4318 (HTTP), 8888 (métricas) | Recibe traces de servicios y los enruta |
| Grafana Tempo | `grafana/tempo:2.3.1` | 3200 | Almacena y consulta distributed traces |
| Prometheus | `prom/prometheus:v2.48.0` | 9090 | Scraping y almacenamiento de métricas |
| Grafana | `grafana/grafana:10.2.3` | 3001 | Visualización (dashboards, alertas) |
| Loki | `grafana/loki:3.0.0` | 3100 | Almacenamiento de logs |
| Promtail | `grafana/promtail:3.0.0` | — | Recolección de logs desde Docker |

---

## Arquitectura del Pipeline

```
Servicios Node.js
  → OTLP HTTP (puerto 4318) → OTel Collector
                               ├── traces  → Tempo (puerto 3200)
                               └── métricas → Prometheus (scraping 9090)

Docker logs
  → Promtail (lee /var/run/docker.sock)
  → Loki (puerto 3100)

Grafana
  ├── Datasource: Tempo  (traces)
  ├── Datasource: Prometheus (métricas)
  └── Datasource: Loki (logs)
```

---

## Configuración de Acceso

- **Grafana UI:** http://localhost:3001
  - Usuario: `admin` / Contraseña: `admin`
  - Acceso anónimo habilitado como Admin (solo dev — NUNCA en prod)
- **Prometheus UI:** http://localhost:9090
- **RabbitMQ Management UI:** http://localhost:15672 (user/password)

---

## Estado de Instrumentación por Servicio

| Servicio | OTel | Winston/Logger | New Relic |
|---|---|---|---|
| API Gateway | Pendiente | Winston ✓ | — |
| Auth Service | Pendiente | Winston (nest-winston) ✓ | — |
| Users Service | Pendiente | console.log | — |
| Inventory Service | Pendiente | Winston ✓ | — |
| Order-Product Service | Pendiente implementación | Winston ✓ | ✓ (newrelic@13.4.0) |

> **TODO.md**: "TERMINAR DE IMPLEMENTAR observabilidad en el resto de proyectos"

---

## Cómo Instrumentar un Servicio con OTel

### 1. Instalar dependencias
```bash
npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node
npm install @opentelemetry/exporter-trace-otlp-http
```

### 2. Configurar el SDK (antes del primer import de la app)
```typescript
// src/instrumentation.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4318/v1/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});
sdk.start();
```

### 3. Variables de entorno necesarias
```env
OTEL_SERVICE_NAME=nombre-del-servicio
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
```

---

## Logging Estructurado

Todos los servicios deben usar logs estructurados (JSON en prod, colorizado en dev) con Winston:

```typescript
// Patrón de log estructurado
logger.info('Order created', {
  orderId: order.id,
  customerId: order.customerId,
  requestId: req.headers['x-request-id'],
  duration: `${Date.now() - startTime}ms`,
});
```

El `requestId` propagado via header `x-request-id` permite correlacionar logs entre servicios.

---

## Grafana Provisioning

```
observability/grafana/provisioning/
├── datasources/   # Datasources auto-configurados (Tempo, Prometheus, Loki)
└── dashboards/    # Dashboards auto-cargados
```

> **TODO**: Diseñar dashboard en Grafana (pendiente según TODO.md)

---

## Reglas para Agentes

1. El OTel Collector debe estar levantado antes que los microservicios (`depends_on: otel-collector`)
2. Los logs de producción deben ser JSON estructurado — no usar `console.log` en producción
3. Incluir `x-request-id` en todos los logs para correlación entre servicios
4. No exponer Grafana con auth anónimo en producción (cambiar `GF_AUTH_ANONYMOUS_ENABLED`)
5. No modificar archivos de configuración en `observability/` sin entender el impacto en el pipeline

---

## Update History

| Date | Change | Author |
|---|---|---|
| 2026-02-11 | Creación inicial por bootstrap | Agent |
