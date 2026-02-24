#!/usr/bin/env node

/**
 * Seed script para DynamoDB (Users Service)
 * Tabla: users-service-db
 *
 * Este script inserta usuarios de prueba en DynamoDB
 * manteniendo coherencia con los UUIDs de MySQL auth_credentials
 */

const {
  DynamoDBClient,
  BatchWriteItemCommand,
} = require("@aws-sdk/client-dynamodb");
const { marshall } = require("@aws-sdk/util-dynamodb");
const fs = require("fs");
const path = require("path");

// Configuración
const region = process.env.REGION || process.env.AWS_REGION || "us-east-1";
const endpoint = process.env.DYNAMODB_ENDPOINT || "http://localhost:4566";
const tableName = process.env.USERS_TABLE || "users-service-db";

const clientConfig = {
  region,
  ...(endpoint ? { endpoint } : {}),
  ...(endpoint
    ? {
        credentials: { accessKeyId: "local", secretAccessKey: "local" },
      }
    : {}),
};

const dynamodb = new DynamoDBClient(clientConfig);

// Cargar datos maestros
const masterDataPath = path.join(__dirname, "master-data.json");
const masterData = JSON.parse(fs.readFileSync(masterDataPath, "utf8"));

async function seedUsers() {
  console.log(`\n🌱 Seeding users to DynamoDB table: ${tableName}`);
  console.log(`📍 Endpoint: ${endpoint}\n`);

  const users = masterData.users.map((user) => ({
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    avatar: user.avatar,
  }));

  // DynamoDB BatchWriteItem tiene límite de 25 items
  const chunks = [];
  for (let i = 0; i < users.length; i += 25) {
    chunks.push(users.slice(i, i + 25));
  }

  for (const [index, chunk] of chunks.entries()) {
    console.log(`📦 Processing batch ${index + 1}/${chunks.length}...`);

    const putRequests = chunk.map((user) => ({
      PutRequest: {
        Item: marshall(user),
      },
    }));

    try {
      await dynamodb.send(
        new BatchWriteItemCommand({
          RequestItems: {
            [tableName]: putRequests,
          },
        })
      );

      console.log(`✅ Batch ${index + 1} inserted successfully`);
    } catch (error) {
      console.error(`❌ Error inserting batch ${index + 1}:`, error.message);
      throw error;
    }
  }

  console.log(`\n✨ Successfully seeded ${users.length} users to DynamoDB!`);
  console.log(`\n📋 User summary:`);
  users.forEach((user) => {
    console.log(
      `  • ${user.name} (${user.email}) - Role: ${user.role} - ID: ${user.id}`
    );
  });
}

// Ejecutar seed
seedUsers()
  .then(() => {
    console.log("\n🎉 Seed completed successfully!\n");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Seed failed:", error);
    process.exit(1);
  });
