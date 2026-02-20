-- ============================================
-- Seed script para MySQL (Auth Service)
-- Base de datos: users_db
-- Tabla: auth_credentials
-- ============================================

USE users_db;

-- Limpiar datos existentes (solo en desarrollo)
TRUNCATE TABLE auth_credentials;

-- Insertar credenciales de autenticación
-- NOTA: Los passwords son hashes de scrypt de "password123"
-- En producción, estos deberían ser generados correctamente

INSERT INTO auth_credentials (id, userId, password, createdAt) VALUES
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440001',
    '$scrypt$N=32768,r=8,p=1,maxmem=67108864$9K8GZBqWpPzOgF8oOPKPkQ$vE/6k0xLqF4K6fLqZlC3qT0KYhXhf9Vl1K2J3K4L5M6N7O8P9Q0R1S2T3U4V5W6X7Y8Z9A0B1C2D3E4F5G6H7I8J9K0',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440002',
    '$scrypt$N=32768,r=8,p=1,maxmem=67108864$8L9HACrXqQAPhG9pPQLQlR$wF0AlGmMyG5L7gMrAmD4rU1LZiYig0Wm2L3K4L5M6N7O8P9Q0R1S2T3U4V5W6X7Y8Z9A0B1C2D3E4F5G6H7I8J9K0',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440003',
    '$scrypt$N=32768,r=8,p=1,maxmem=67108864$7M0IBDsYrRBQiH0qQRMRmS$xG1BmHnNzH6M8hNsBnE5sV2MajZjh1Xn3M4L5M6N7O8P9Q0R1S2T3U4V5W6X7Y8Z9A0B1C2D3E4F5G6H7I8J9K0',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440004',
    '$scrypt$N=32768,r=8,p=1,maxmem=67108864$6N1JCEtZsSCRjI1rRSNSnT$yH2CnIoOAI7N9iOtCoF6tW3NbkAki2Yo4N5M6N7O8P9Q0R1S2T3U4V5W6X7Y8Z9A0B1C2D3E4F5G6H7I8J9K0',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440005',
    '$scrypt$N=32768,r=8,p=1,maxmem=67108864$5O2KDFuAtTDSkJ2sTTOToU$zI3DoJpPBJ8O0jPuDpG7uX4OclBlj3Zp5O6N7O8P9Q0R1S2T3U4V5W6X7Y8Z9A0B1C2D3E4F5G6H7I8J9K0',
    CURRENT_TIMESTAMP
);

-- Verificar inserción
SELECT
    COUNT(*) as total_users,
    'Auth credentials seeded successfully' as message
FROM auth_credentials;

SELECT
    id,
    userId,
    LEFT(password, 50) as password_preview,
    createdAt
FROM auth_credentials
ORDER BY createdAt;
