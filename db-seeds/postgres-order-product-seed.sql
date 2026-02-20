-- ============================================
-- Seed script para PostgreSQL (Order-Product Service)
-- Base de datos: order_product_db
-- Tablas: products, addresses, customers, orders, order_items
-- ============================================

-- Limpiar datos existentes (solo en desarrollo)
-- Importante: el orden importa debido a las foreign keys
TRUNCATE TABLE order_items CASCADE;
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE customers CASCADE;
TRUNCATE TABLE addresses CASCADE;
TRUNCATE TABLE products CASCADE;

-- ============================================
-- 1. PRODUCTS
-- ============================================
INSERT INTO products (id, sku, name, description, price, category, "isActive", "createdAt", "updatedAt") VALUES
('d0e8f8a0-0001-4000-8000-000000000001', 'LAPTOP-DELL-XPS15', 'Dell XPS 15', 'High-performance laptop with 15.6 inch 4K display, Intel i7, 16GB RAM, 512GB SSD', 1499.99, 'Electronics', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000002', 'PHONE-IPHONE-14PRO', 'iPhone 14 Pro', 'Apple iPhone 14 Pro with A16 Bionic chip, 6.1 inch Super Retina XDR display, 128GB', 999.99, 'Electronics', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000003', 'HEADPHONES-SONY-WH1000XM5', 'Sony WH-1000XM5', 'Industry-leading noise canceling wireless headphones', 399.99, 'Electronics', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000004', 'KEYBOARD-LOGITECH-MX', 'Logitech MX Keys', 'Advanced wireless illuminated keyboard', 99.99, 'Accessories', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000005', 'MOUSE-LOGITECH-MX3', 'Logitech MX Master 3', 'Advanced wireless mouse', 99.99, 'Accessories', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000006', 'MONITOR-DELL-U2720Q', 'Dell UltraSharp 27 4K', '27-inch 4K USB-C monitor', 599.99, 'Electronics', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000007', 'WEBCAM-LOGITECH-C920', 'Logitech C920 HD Pro', 'Full HD 1080p webcam', 79.99, 'Accessories', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000008', 'TABLET-IPAD-AIR', 'iPad Air', 'Apple iPad Air with M1 chip, 10.9 inch Liquid Retina display, 64GB', 599.99, 'Electronics', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-000000000009', 'SPEAKER-SONOS-ONE', 'Sonos One', 'Smart speaker with voice control', 199.99, 'Electronics', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
('d0e8f8a0-0001-4000-8000-00000000000a', 'CHARGER-ANKER-65W', 'Anker 65W USB-C Charger', 'Fast charging USB-C charger', 49.99, 'Accessories', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

-- ============================================
-- 2. ADDRESSES
-- ============================================
INSERT INTO addresses (id, street, city, state, "zipCode", country, "createdAt") VALUES
('a0e8f8a0-0001-4000-8000-000000000001', '123 Main St', 'New York', 'NY', '10001', 'USA', CURRENT_TIMESTAMP),
('a0e8f8a0-0001-4000-8000-000000000002', '456 Oak Ave', 'Los Angeles', 'CA', '90001', 'USA', CURRENT_TIMESTAMP),
('a0e8f8a0-0001-4000-8000-000000000003', '789 Pine Rd', 'Chicago', 'IL', '60601', 'USA', CURRENT_TIMESTAMP),
('a0e8f8a0-0001-4000-8000-000000000004', '321 Elm Blvd', 'Houston', 'TX', '77001', 'USA', CURRENT_TIMESTAMP),
('a0e8f8a0-0001-4000-8000-000000000005', '654 Maple Dr', 'Phoenix', 'AZ', '85001', 'USA', CURRENT_TIMESTAMP);

-- ============================================
-- 3. CUSTOMERS
-- ============================================
-- IMPORTANTE: Los IDs coinciden con los userId de auth_credentials y DynamoDB users
INSERT INTO customers (id, name, email, "phoneNumber", "isActive", "addressId", "createdAt") VALUES
('550e8400-e29b-41d4-a716-446655440001', 'John Doe', 'john.doe@example.com', '+1-555-0101', true, 'a0e8f8a0-0001-4000-8000-000000000001', CURRENT_TIMESTAMP),
('550e8400-e29b-41d4-a716-446655440002', 'Jane Smith', 'jane.smith@example.com', '+1-555-0102', true, 'a0e8f8a0-0001-4000-8000-000000000002', CURRENT_TIMESTAMP),
('550e8400-e29b-41d4-a716-446655440003', 'Admin User', 'admin@example.com', '+1-555-0103', true, 'a0e8f8a0-0001-4000-8000-000000000003', CURRENT_TIMESTAMP),
('550e8400-e29b-41d4-a716-446655440004', 'Alice Johnson', 'alice.johnson@example.com', '+1-555-0104', true, 'a0e8f8a0-0001-4000-8000-000000000004', CURRENT_TIMESTAMP),
('550e8400-e29b-41d4-a716-446655440005', 'Bob Williams', 'bob.williams@example.com', '+1-555-0105', true, 'a0e8f8a0-0001-4000-8000-000000000005', CURRENT_TIMESTAMP);

-- ============================================
-- 4. ORDERS
-- ============================================
INSERT INTO orders (id, "orderNumber", status, "customerId", "createdAt", "updatedAt") VALUES
('o0e8f8a0-0001-4000-8000-000000000001', 'ORD-2024-001', 'PAID', '550e8400-e29b-41d4-a716-446655440001', CURRENT_TIMESTAMP - INTERVAL '5 days', CURRENT_TIMESTAMP - INTERVAL '5 days'),
('o0e8f8a0-0001-4000-8000-000000000002', 'ORD-2024-002', 'SHIPPED', '550e8400-e29b-41d4-a716-446655440002', CURRENT_TIMESTAMP - INTERVAL '4 days', CURRENT_TIMESTAMP - INTERVAL '3 days'),
('o0e8f8a0-0001-4000-8000-000000000003', 'ORD-2024-003', 'PENDING', '550e8400-e29b-41d4-a716-446655440001', CURRENT_TIMESTAMP - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
('o0e8f8a0-0001-4000-8000-000000000004', 'ORD-2024-004', 'PAID', '550e8400-e29b-41d4-a716-446655440004', CURRENT_TIMESTAMP - INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '1 day'),
('o0e8f8a0-0001-4000-8000-000000000005', 'ORD-2024-005', 'PENDING', '550e8400-e29b-41d4-a716-446655440005', CURRENT_TIMESTAMP - INTERVAL '3 hours', CURRENT_TIMESTAMP - INTERVAL '3 hours'),
('o0e8f8a0-0001-4000-8000-000000000006', 'ORD-2024-006', 'CANCELLED', '550e8400-e29b-41d4-a716-446655440002', CURRENT_TIMESTAMP - INTERVAL '7 days', CURRENT_TIMESTAMP - INTERVAL '6 days');

-- ============================================
-- 5. ORDER ITEMS
-- ============================================
-- Orden 1: John Doe - Laptop + Mouse
INSERT INTO order_items (id, quantity, price, "orderNumber", sku) VALUES
(gen_random_uuid(), 1, 1499.99, 'ORD-2024-001', 'LAPTOP-DELL-XPS15'),
(gen_random_uuid(), 1, 99.99, 'ORD-2024-001', 'MOUSE-LOGITECH-MX3');

-- Orden 2: Jane Smith - iPhone + Headphones
INSERT INTO order_items (id, quantity, price, "orderNumber", sku) VALUES
(gen_random_uuid(), 1, 999.99, 'ORD-2024-002', 'PHONE-IPHONE-14PRO'),
(gen_random_uuid(), 1, 399.99, 'ORD-2024-002', 'HEADPHONES-SONY-WH1000XM5');

-- Orden 3: John Doe - Monitor + Keyboard + Webcam
INSERT INTO order_items (id, quantity, price, "orderNumber", sku) VALUES
(gen_random_uuid(), 1, 599.99, 'ORD-2024-003', 'MONITOR-DELL-U2720Q'),
(gen_random_uuid(), 1, 99.99, 'ORD-2024-003', 'KEYBOARD-LOGITECH-MX'),
(gen_random_uuid(), 2, 79.99, 'ORD-2024-003', 'WEBCAM-LOGITECH-C920');

-- Orden 4: Alice Johnson - iPad + Charger
INSERT INTO order_items (id, quantity, price, "orderNumber", sku) VALUES
(gen_random_uuid(), 1, 599.99, 'ORD-2024-004', 'TABLET-IPAD-AIR'),
(gen_random_uuid(), 3, 49.99, 'ORD-2024-004', 'CHARGER-ANKER-65W');

-- Orden 5: Bob Williams - Speaker
INSERT INTO order_items (id, quantity, price, "orderNumber", sku) VALUES
(gen_random_uuid(), 1, 199.99, 'ORD-2024-005', 'SPEAKER-SONOS-ONE');

-- Orden 6: Jane Smith - iPhone (CANCELADA)
INSERT INTO order_items (id, quantity, price, "orderNumber", sku) VALUES
(gen_random_uuid(), 1, 999.99, 'ORD-2024-006', 'PHONE-IPHONE-14PRO');

-- ============================================
-- VERIFICACIÓN Y RESUMEN
-- ============================================

-- Resumen de datos insertados
SELECT
    (SELECT COUNT(*) FROM products) as total_products,
    (SELECT COUNT(*) FROM addresses) as total_addresses,
    (SELECT COUNT(*) FROM customers) as total_customers,
    (SELECT COUNT(*) FROM orders) as total_orders,
    (SELECT COUNT(*) FROM order_items) as total_order_items,
    'Order-Product DB seeded successfully' as message;

-- Resumen de órdenes por status
SELECT
    status,
    COUNT(*) as count,
    SUM((SELECT SUM(quantity * price) FROM order_items WHERE order_items."orderNumber" = orders."orderNumber")) as total_amount
FROM orders
GROUP BY status
ORDER BY status;

-- Top 5 productos más vendidos
SELECT
    p.name,
    p.sku,
    SUM(oi.quantity) as total_sold,
    SUM(oi.quantity * oi.price) as total_revenue
FROM order_items oi
JOIN products p ON oi.sku = p.sku
JOIN orders o ON oi."orderNumber" = o."orderNumber"
WHERE o.status != 'CANCELLED'
GROUP BY p.id, p.name, p.sku
ORDER BY total_sold DESC
LIMIT 5;

-- Verificar integridad de foreign keys
SELECT
    'All foreign keys are valid' as message
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi
    LEFT JOIN products p ON oi.sku = p.sku
    WHERE p.sku IS NULL
)
AND NOT EXISTS (
    SELECT 1 FROM order_items oi
    LEFT JOIN orders o ON oi."orderNumber" = o."orderNumber"
    WHERE o."orderNumber" IS NULL
)
AND NOT EXISTS (
    SELECT 1 FROM orders o
    LEFT JOIN customers c ON o."customerId" = c.id
    WHERE c.id IS NULL
)
AND NOT EXISTS (
    SELECT 1 FROM customers c
    LEFT JOIN addresses a ON c."addressId" = a.id
    WHERE a.id IS NULL
);
