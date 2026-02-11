---
name: ddd-architecture
description: Estructura DDD con capas application/domain/infrastructure, Value Objects, Use Cases, repositorios con interfaz, y Unit of Work en ecommerce-order-product-service
category: architecture
priority: high
applies_to:
  - ecommerce-order-product-service/src/domain/
  - ecommerce-order-product-service/src/shared/domain/
  - ecommerce-inventory-service/src/application/
  - ecommerce-inventory-service/src/domain/
last_validated: 2026-02-11
conflicts_with: []
requires_human_approval: false
---

# Skill: DDD Architecture

## Descripción

El servicio `ecommerce-order-product-service` implementa DDD completo. El `ecommerce-inventory-service` implementa CQRS sin Value Objects completos. Seguir estos patrones al agregar o modificar entidades.

---

## Estructura de Capas (order-product-service)

```
src/domain/[entity]/
├── application/           # Casos de uso, DTOs, validación, eventos
│   ├── [Action]UseCase.ts
│   ├── [Action]Schema.ts  # Validación Zod
│   ├── dtos/
│   ├── events/
│   └── exceptions/
├── domain/                # Entidades, interfaces de repositorio, Value Objects
│   ├── [Entity].ts        # Clase de dominio con lógica de negocio
│   ├── I[Entity].ts       # Interface de la entidad
│   ├── I[Entity]Repository.ts
│   ├── value-objects/
│   ├── types/
│   └── exceptions/
└── infrastructure/        # Repositorios concretos, controllers, routes, mappers
    ├── [entity].controller.ts
    ├── [entity].routes.ts
    ├── repository/[entity]PrismaRepository.ts
    └── mappers/[Entity]Mapper.ts
```

---

## Value Objects Existentes

```typescript
// shared/domain/value-objects/
CustomId.ts     // UUID wrapper con validación
Email.ts        // Email con validación de formato
Address.ts      // Dirección con calle, ciudad, estado, zip, país

// domain/product/domain/value-objects/
ProductCategory.ts  // Enum de categorías válidas
```

**Patrón para crear Value Objects:**
```typescript
export class CustomId {
  private readonly _value: string;

  constructor(value: string) {
    if (!isValidUUID(value)) {
      throw new ValidationError('Invalid UUID format');
    }
    this._value = value;
  }

  get value(): string { return this._value; }
}
```

---

## Jerarquía de Excepciones

```
BaseError
└── DomainException           # shared/domain/exceptions/DomainException.ts
    └── CustomerDomainException
    └── OrderDomainException
    └── ProductDomainException
└── ApplicationException      # shared/application/exceptions/ApplicationException.ts
    └── OrderApplicationException
    └── ProductApplicationException
└── ValidationError           # shared/domain/exceptions/ValidationError.ts
```

**Regla:** Los Use Cases solo propagan excepciones tipadas de su propio dominio. Excepciones inesperadas se convierten a `[Entity]ApplicationException.useCaseError(...)`.

---

## Patrón de Use Case

```typescript
export class CreateOrUpdateOrderUseCase {
  constructor(
    private readonly orderRepository: IOrderRepository,
    private readonly productRepository: IProductRepository,
    private readonly orderPublisher: OrderEventPublisher,
    private readonly inventoryService: IInventoryService,
    private readonly unitOfWork: IUnitOfWork,
  ) {}

  public async execute(data: CreateOrUpdateOrderDTO): Promise<string> {
    // 1. Validar con Zod schema
    // 2. Operaciones de solo lectura ANTES de la transacción
    // 3. Transacción para escrituras
    // 4. Publicar eventos (idealmente en Outbox — ver skill event-driven-outbox.md)
    // 5. Capturar y convertir excepciones inesperadas
  }
}
```

---

## Unit of Work (Prisma)

```typescript
// shared/infrastructure/database/PrismaUnitOfWork.ts
await this.unitOfWork.execute(async (tx) => {
  // tx es un PrismaClient sin métodos de conexión
  await this.orderRepository.save(order, tx);
  // tx se pasa al repositorio para que use la misma transacción
});
```

Los repositorios deben aceptar un `tx` opcional para operar dentro de la transacción.

---

## CQRS en Inventory Service

```
src/application/
├── commands/           # Operaciones de escritura
│   ├── CreateInventoryProductCommand/
│   ├── decreaseStockUseCase/
│   └── releaseStockUseCase/
└── queries/            # Operaciones de lectura
    ├── GetProductInventoryUseCase/
    └── GetStockAvailableOrderUseCase/
```

**Diferencia con order-product:** No usa Value Objects ni jerarquía de excepciones DDD. Los commands/queries son más simples (clases con `dto` + `params` + clase principal).

---

## Mappers

Los mappers convierten entre capas:
```typescript
// infrastructure/mappers/OrderMapper.ts
static toDomain(prismaOrder: PrismaOrder): Order { ... }
static toPrisma(order: Order): PrismaOrderCreateInput { ... }
static toDTO(order: Order): OrderResponseDTO { ... }
```

---

## Reglas para Agentes

1. Al agregar una entidad nueva: seguir la estructura `application/domain/infrastructure` completa
2. Crear Value Objects para cualquier campo con restricciones de dominio (email, UUID, moneda)
3. Las interfaces de repositorio van en `domain/`, las implementaciones en `infrastructure/`
4. Los Use Cases no importan nada de `infrastructure/` — solo interfaces
5. La validación de entrada se hace con Zod en la capa `application/` (no en controllers)
6. Los controllers solo orquestan: parsean request → llaman Use Case → devuelven response
7. No usar `any` en el dominio; usar tipos explícitos o `unknown` con guards

---

## Update History

| Date | Change | Author |
|---|---|---|
| 2026-02-11 | Creación inicial por bootstrap | Agent |
