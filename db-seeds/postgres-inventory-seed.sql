-- ============================================
-- Seed script para PostgreSQL (Inventory Service)
-- Base de datos: inventory_db
-- Tabla: products
-- ============================================

-- Limpiar datos existentes (solo en desarrollo)
TRUNCATE TABLE products CASCADE;

-- Insertar productos con stock
-- Los SKUs coinciden con los productos en order_product_db para consistencia

INSERT INTO products (id, sku, stock_available, stock_reserved) VALUES
(gen_random_uuid(), 'LAPTOP-DELL-XPS15', 25, 3),
(gen_random_uuid(), 'PHONE-IPHONE-14PRO', 50, 5),
(gen_random_uuid(), 'HEADPHONES-SONY-WH1000XM5', 100, 10),
(gen_random_uuid(), 'KEYBOARD-LOGITECH-MX', 75, 2),
(gen_random_uuid(), 'MOUSE-LOGITECH-MX3', 80, 4),
(gen_random_uuid(), 'MONITOR-DELL-U2720Q', 30, 1),
(gen_random_uuid(), 'WEBCAM-LOGITECH-C920', 120, 8),
(gen_random_uuid(), 'TABLET-IPAD-AIR', 40, 6),
(gen_random_uuid(), 'SPEAKER-SONOS-ONE', 60, 0),
(gen_random_uuid(), 'CHARGER-ANKER-65W', 200, 15);

-- Verificar inserción
SELECT
    COUNT(*) as total_products,
    SUM(stock_available) as total_stock_available,
    SUM(stock_reserved) as total_stock_reserved,
    'Inventory seeded successfully' as message
FROM products;

-- Mostrar resumen de productos
SELECT
    sku,
    stock_available,
    stock_reserved,
    (stock_available + stock_reserved) as total_stock
FROM products
ORDER BY sku;
