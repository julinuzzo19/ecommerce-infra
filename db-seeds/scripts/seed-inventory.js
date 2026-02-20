#!/usr/bin/env node

/**
 * Seed script para PostgreSQL (Inventory Service)
 * Ejecuta el archivo SQL postgres-inventory-seed.sql
 */

const { Client } = require("pg");
const fs = require("fs");
const path = require("path");

// Configuración
const config = {
  host: process.env.POSTGRES_INVENTORY_HOST || "localhost",
  port: process.env.POSTGRES_INVENTORY_PORT || 5434,
  user: process.env.POSTGRES_INVENTORY_USER || "root",
  password: process.env.POSTGRES_INVENTORY_PASSWORD || "root",
  database: process.env.POSTGRES_INVENTORY_DATABASE || "inventory_db",
};

async function seedInventory() {
  console.log("\n🌱 Seeding PostgreSQL (Inventory Service)...");
  console.log(`📍 Host: ${config.host}:${config.port}`);
  console.log(`📦 Database: ${config.database}\n`);

  const client = new Client(config);

  try {
    // Conectar a PostgreSQL
    await client.connect();
    console.log("✅ Connected to PostgreSQL (Inventory)");

    // Leer archivo SQL
    const sqlPath = path.join(__dirname, "..", "postgres-inventory-seed.sql");
    const sql = fs.readFileSync(sqlPath, "utf8");

    // Ejecutar SQL
    console.log("📄 Executing SQL seed script...");
    const result = await client.query(sql);

    console.log("✅ Inventory seed completed successfully!");

    // Mostrar resumen si hay
    if (result.rows && result.rows.length > 0) {
      console.log("\n📊 Summary:");
      console.table(result.rows);
    }
  } catch (error) {
    console.error("❌ Error seeding Inventory:", error.message);
    throw error;
  } finally {
    await client.end();
    console.log("🔌 PostgreSQL connection closed\n");
  }
}

// Ejecutar seed
seedInventory()
  .then(() => {
    console.log("🎉 Inventory seed completed!\n");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Inventory seed failed:", error);
    process.exit(1);
  });
