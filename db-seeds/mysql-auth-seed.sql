-- ============================================
-- Seed script para MySQL (Auth Service)
-- Base de datos: users_db
-- Tabla: auth_credentials
-- ============================================

USE users_db;

-- Limpiar datos existentes (solo en desarrollo)
TRUNCATE TABLE auth_credentials;

-- Insertar credenciales de autenticación
-- Passwords hasheados con crypto.scrypt de Node.js en formato saltHex:hashHex
-- Todos usan password: "password123"

INSERT INTO auth_credentials (id, userId, password, createdAt) VALUES
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440001',
    '51a5cf5d11f22c31b936b9f0bcea4032:0955035df4d226a2c3b51af319291c487a5154fce7ec7da132e2b0e3b49ccc831149c2bc2da0db49a02c71b5a2bb749e81bd4ce241933a4686fc309dec0987c6',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440002',
    '15eff2457247a3dd0c4a0661b56c02a5:6e557ca189dae2a7058114e79ae73f764ab9e7ebdd1cb964ff034d4e993d7333795a74bffdbb7e7255ad5c719e084e78e89294c0f2c6718bd0023555d00b4237',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440003',
    'dccc29c3d5e316c2a5ffbad556a154bf:fc0f152c229de6f065d8ad5acb22a3eea5338fc89cceb135f29269c2e926cb8ae42a2f818963a1ae44ff5b7fa4ee0a5519d79e4391fde62d75252e2044d699e9',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440004',
    'ba1320b8502c41966baf0a2dde65b8d3:72359b4877b647d0687f10ed052f4611b6bff07a97b93c66477974936736310b5e27158c85d050ab492fadf09d01c28aba6a38ba9d9668bba11d8328b21d97f4',
    CURRENT_TIMESTAMP
),
(
    UUID(),
    '550e8400-e29b-41d4-a716-446655440005',
    '678765888cb4e135203d799203b2b54a:50d4d51d4b93eface9d64205de5cde0dd02f56ce18085e86581930e8fe9adf2c94f6180b69a87feaa57d4ab5cd1218455249b72e15cdb45ecf69249ca65f7ad9',
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
