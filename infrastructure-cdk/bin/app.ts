#!/usr/bin/env node
import "source-map-support/register";
import * as cdk from "aws-cdk-lib";
import { UsersServiceStack } from "../lib/users-service-stack";

/**
 * AWS CDK App - Entry point para toda la infraestructura
 *
 * Este archivo instancia todos los stacks necesarios para el proyecto.
 * Cada stack representa un conjunto lógico de recursos relacionados.
 */

const app = new cdk.App();

/**
 * Stack del servicio de usuarios (Serverless)
 *
 * Provisiona:
 * - Tabla DynamoDB con GSI para email
 * - Cola SQS para eventos UserCreated
 * - Dead Letter Queue (DLQ) para manejo de fallos
 * - Outputs para integración con Serverless Framework
 */
new UsersServiceStack(app, "UsersServiceStack", {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT || process.env.AWS_ACCOUNT_ID,
    region: process.env.CDK_DEFAULT_REGION || process.env.AWS_REGION || "us-east-1",
  },

  // Tags comunes para todos los recursos
  tags: {
    Project: "EcommerceMicroservices",
    ManagedBy: "AWS-CDK",
    Environment: process.env.STAGE || "dev",
  },

  description: "Infrastructure for serverless users service - DynamoDB + SQS",
});

// Synthesize el CloudFormation template
app.synth();
