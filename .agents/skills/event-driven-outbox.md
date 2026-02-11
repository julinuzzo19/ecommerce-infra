---
name: event-driven-outbox
description: Patrón de publicación de eventos con RabbitMQ, estado actual de consistencia, y el Outbox Pattern pendiente de implementación completa
category: architecture
priority: critical
applies_to:
  - ecommerce-order-product-service/src/domain/order/application/events/OrderEventPublisher.ts
  - ecommerce-order-product-service/src/shared/infrastructure/events/
  - ecommerce-order-product-service/src/shared/infrastructure/db/prisma/schema.prisma
  - ecommerce-order-product-service/src/domain/order/application/CreateOrUpdateOrderUseCase.ts
  - ecommerce-inventory-service/src/application/events/OrderEventConsumer.ts
last_validated: 2026-02-11
conflicts_with: []
requires_human_approval: true
---

# Skill: Event-Driven con Outbox Pattern

## Descripción

Comunicación asíncrona entre microservicios usando RabbitMQ con exchange tipo `topic`. El Outbox Pattern está parcialmente preparado (tabla en schema) pero NO completamente implementado.

---

## Configuración RabbitMQ (Estado Real)

### Exchange
```
Nombre:  orders
Tipo:    topic
Durable: true
```

### Routing Keys
```typescript
// ecommerce-order-product-service/src/shared/application/events/types/events.ts
ORDER_CREATED  = 'order.created'
ORDER_CANCELLED = 'order.cancelled'
```

### Queues
```
inventory_orders → binding: order.# (recibe TODOS los eventos de orden)
```

---

## Implementación Actual (Publisher)

```typescript
// BaseEventPublisher.ts
this.channel.publish(this.exchangeName, routingKey, buffer, {
  persistent: true,       // Mensajes sobreviven restart de RabbitMQ
  contentType: 'application/json',
  timestamp: Date.now(),
});
```

```typescript
// CreateOrUpdateOrderUseCase.ts:43-57 — PATRÓN ACTUAL (riesgoso)
await this.unitOfWork.execute(async (tx) => {
  await this.orderRepository.save(order, tx);           // Persiste orden
  await this.orderPublisher.publishOrderCreated({...}); // Publica evento
  // Si publishOrderCreated lanza excepción:
  //   - La transacción hace rollback ✓
  //   - El evento puede haber sido enviado a RabbitMQ ya ✗ (duplicado)
  // Si la transacción hace commit pero RabbitMQ está caído:
  //   - La orden está guardada ✓
  //   - El evento nunca llega a Inventory ✗ (stock no se descuenta)
});
```

---

## Estado del Outbox Pattern

### Lo que existe (schema.prisma)
```prisma
model Outbox {
  id            Int       @id @default(autoincrement())
  aggregateType String    // Ej: "Order"
  aggregateId   String    // UUID de la orden
  eventType     String    // Ej: "order.created"
  payload       Json      // Evento completo
  metadata      Json?
  createdAt     DateTime  @default(now())
  publishedAt   DateTime?
  published     Boolean   @default(false)
  @@index([published, createdAt])
}
```

### Lo que falta (no implementado)
1. **Guardar en Outbox** dentro de la transacción (en lugar de publicar directamente)
2. **Outbox Relay / Poller**: proceso que lee registros `published=false` y los publica a RabbitMQ
3. **Marcar como publicado** después de confirmar publicación
4. **Idempotencia en el consumer**: evitar procesar el mismo evento dos veces

---

## Patrón Correcto a Implementar (Referencia)

```typescript
// Dentro de la transacción — GUARDAR en Outbox, no publicar directamente
await this.unitOfWork.execute(async (tx) => {
  await this.orderRepository.save(order, tx);
  await this.outboxRepository.save({
    aggregateType: 'Order',
    aggregateId: order.id.value,
    eventType: 'order.created',
    payload: { orderId, products, createdAt },
    published: false,
  }, tx);
});
// Fuera de la transacción: un worker/scheduler lee el Outbox y publica
```

---

## Consumer (Inventory Service)

```typescript
// OrderEventConsumer.ts
protected exchangeName = EXCHANGES.ORDERS;
protected queueName    = QUEUES.INVENTORY_ORDERS;
protected routingKeys  = ['order.#'];  // Recibe created Y cancelled
protected exchangeType = 'topic';

protected parseMessage(msg): OrderCreatedEvent | OrderCancelledEvent {
  return JSON.parse(msg.content.toString());
}
```

**Comportamiento por tipo de evento:**
- `order.created` → `DecreaseStockUseCaseCommand`
- `order.cancelled` → `ReleaseStockUseCaseCommand` (implementado pero falta integrar en consumer)

---

## Eventos Definidos

```typescript
// types/events.ts
interface OrderCreatedEvent {
  type: 'order.created';
  orderId: string;
  createdAt: string;     // ISO string
  products: Array<{ sku: string; quantity: number }>;
}

interface OrderCancelledEvent {
  type: 'order.cancelled';
  orderId: string;
}
```

---

## Reglas para Agentes

1. **NUNCA** publicar un evento RabbitMQ directamente dentro de una transacción DB sin el Outbox Pattern implementado
2. Al implementar el Outbox Relay, usar polling con límite de batch (ej: 100 registros)
3. Los consumers deben ser **idempotentes** — verificar si el evento ya fue procesado
4. Routing key `order.#` captura todos los subtipos — los consumers deben validar el tipo del evento
5. `persistent: true` es obligatorio para mensajes que afectan inventario
6. Ante cambios en exchange name, routing keys o queue names: requiere aprobación humana (ver AGENTS.md criterios de escalación)

---

## Preguntas Pendientes

- Ver Q002 en `questions-log.md` para decisión sobre prioridad de implementación

---

## Update History

| Date | Change | Author |
|---|---|---|
| 2026-02-11 | Creación inicial por bootstrap | Agent |
