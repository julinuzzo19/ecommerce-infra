#!/usr/bin/env node

/**
 * Seed script para PostgreSQL (Order-Product Service)
 * Ejecuta el archivo SQL postgres-order-product-seed.sql
 */

const { Client } = require("pg");
const fs = require("fs");
const path = require("path");

// Configuración
const config = {
  host: process.env.POSTGRES_ORDER_HOST || "localhost",
  port: process.env.POSTGRES_ORDER_PORT || 5432,
  user: process.env.POSTGRES_ORDER_USER || "root",
  password: process.env.POSTGRES_ORDER_PASSWORD || "root",
  database: process.env.POSTGRES_ORDER_DATABASE || "order_product_db",
};

async function seedOrders() {
  console.log("\n🌱 Seeding PostgreSQL (Order-Product Service)...");
  console.log(`📍 Host: ${config.host}:${config.port}`);
  console.log(`📦 Database: ${config.database}\n`);

  const client = new Client(config);

  try {
    // Conectar a PostgreSQL
    await client.connect();
    console.log("✅ Connected to PostgreSQL (Order-Product)");

    // Leer archivo SQL
    const sqlPath = path.join(
      __dirname,
      "..",
      "postgres-order-product-seed.sql"
    );
    const sql = fs.readFileSync(sqlPath, "utf8");

    // Ejecutar SQL
    console.log("📄 Executing SQL seed script...");
    await client.query(sql);

    console.log("✅ Order-Product seed completed successfully!");
  } catch (error) {
    console.error("❌ Error seeding Order-Product:", error.message);
    throw error;
  } finally {
    await client.end();
    console.log("🔌 PostgreSQL connection closed\n");
  }
}

// Ejecutar seed
seedOrders()
  .then(() => {
    console.log("🎉 Order-Product seed completed!\n");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Order-Product seed failed:", error);
    process.exit(1);
  });
