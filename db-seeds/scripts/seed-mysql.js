#!/usr/bin/env node

/**
 * Seed script para MySQL (Auth Service)
 * Ejecuta el archivo SQL mysql-auth-seed.sql
 */

const mysql = require("mysql2/promise");
const fs = require("fs");
const path = require("path");

// Configuración
const config = {
  host: process.env.MYSQL_HOST || "localhost",
  port: process.env.MYSQL_PORT || 3307,
  user: process.env.MYSQL_USER || "root",
  password: process.env.MYSQL_PASSWORD || "root",
  database: process.env.MYSQL_DATABASE || "users_db",
  multipleStatements: true,
};

async function seedMySQL() {
  console.log("\n🌱 Seeding MySQL (Auth Service)...");
  console.log(`📍 Host: ${config.host}:${config.port}`);
  console.log(`📦 Database: ${config.database}\n`);

  let connection;

  try {
    // Conectar a MySQL
    connection = await mysql.createConnection(config);
    console.log("✅ Connected to MySQL");

    // Leer archivo SQL
    const sqlPath = path.join(__dirname, "..", "mysql-auth-seed.sql");
    const sql = fs.readFileSync(sqlPath, "utf8");

    // Ejecutar SQL
    console.log("📄 Executing SQL seed script...");
    const [results] = await connection.query(sql);

    console.log("✅ MySQL seed completed successfully!");

    // Mostrar resultados si hay
    if (Array.isArray(results)) {
      const lastResult = results[results.length - 1];
      if (Array.isArray(lastResult) && lastResult.length > 0) {
        console.log("\n📊 Summary:");
        console.table(lastResult);
      }
    }
  } catch (error) {
    console.error("❌ Error seeding MySQL:", error.message);
    throw error;
  } finally {
    if (connection) {
      await connection.end();
      console.log("🔌 MySQL connection closed\n");
    }
  }
}

// Ejecutar seed
seedMySQL()
  .then(() => {
    console.log("🎉 MySQL seed completed!\n");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ MySQL seed failed:", error);
    process.exit(1);
  });
