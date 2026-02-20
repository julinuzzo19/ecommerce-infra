import * as cdk from "aws-cdk-lib";
import * as dynamodb from "aws-cdk-lib/aws-dynamodb";
import * as sqs from "aws-cdk-lib/aws-sqs";
import { Construct } from "constructs";

/**
 * Stack de infraestructura para el servicio de usuarios serverless
 *
 * Este stack provisiona toda la infraestructura necesaria de manera declarativa:
 * - Tabla DynamoDB con índice secundario global (GSI) para búsquedas por email
 * - Cola SQS para eventos de usuario creado
 * - Dead Letter Queue (DLQ) para manejo de mensajes fallidos
 *
 * Ventajas vs scripts imperativos:
 * ✅ Idempotente - Ejecutar múltiples veces produce el mismo resultado
 * ✅ Declarativo - Describes QUÉ quieres, no CÓMO crearlo
 * ✅ Versionado - La infraestructura está en código versionado
 * ✅ Rollback automático - Si algo falla, CloudFormation hace rollback
 * ✅ Change sets - Puedes ver los cambios antes de aplicarlos (cdk diff)
 * ✅ Reutilizable - Fácil crear múltiples ambientes (dev, staging, prod)
 */
export class UsersServiceStack extends cdk.Stack {
  // Exponer recursos públicamente para referencia entre stacks si es necesario
  public readonly usersTable: dynamodb.Table;
  public readonly userCreatedQueue: sqs.Queue;
  public readonly userCreatedDLQ: sqs.Queue;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const stage = process.env.STAGE || "dev";

    // ========================================
    // Dead Letter Queue (DLQ)
    // ========================================
    /**
     * Cola para mensajes que no pudieron ser procesados después de varios reintentos.
     * Esto evita perder mensajes y permite investigar problemas.
     */
    this.userCreatedDLQ = new sqs.Queue(this, "UserCreatedDLQ", {
      queueName: `user-created-dlq-${stage}`,
      // Retención máxima de 14 días (tiempo para investigar mensajes fallidos)
      retentionPeriod: cdk.Duration.days(14),
      // Encryption at rest usando AWS managed keys (gratis)
      encryption: sqs.QueueEncryption.SQS_MANAGED,
    });

    // ========================================
    // Cola SQS Principal
    // ========================================
    /**
     * Cola para eventos UserCreated.
     * Cuando se crea un usuario en DynamoDB, se publica un mensaje aquí.
     * Otros servicios pueden suscribirse para reaccionar al evento.
     */
    this.userCreatedQueue = new sqs.Queue(this, "UserCreatedQueue", {
      queueName: `user-created-queue-${stage}`,

      // Tiempo de visibilidad: cuánto tiempo un mensaje está "invisible" después de ser leído
      // Debería ser >= al timeout de tu Lambda consumer
      visibilityTimeout: cdk.Duration.seconds(30),

      // Retención de mensajes: 4 días por defecto
      retentionPeriod: cdk.Duration.days(4),

      // DLQ: después de 3 intentos fallidos, el mensaje va a la DLQ
      deadLetterQueue: {
        queue: this.userCreatedDLQ,
        maxReceiveCount: 3,
      },

      // Encryption at rest
      encryption: sqs.QueueEncryption.SQS_MANAGED,
    });

    // ========================================
    // Tabla DynamoDB
    // ========================================
    /**
     * Tabla principal de usuarios.
     *
     * Esquema:
     * - Partition Key: id (UUID generado por la aplicación)
     * - GSI: email (para búsquedas por email)
     *
     * Billing: PAY_PER_REQUEST (on-demand) - ideal para cargas impredecibles
     * Alternativa: PROVISIONED con auto-scaling para cargas predecibles
     */
    this.usersTable = new dynamodb.Table(this, "UsersTable", {
      tableName: `users-service-db-${stage}`,

      // Partition key (HASH)
      partitionKey: {
        name: "id",
        type: dynamodb.AttributeType.STRING,
      },

      // Billing mode: on-demand (pagas por request, no por capacidad provisionada)
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,

      // Encryption at rest con AWS managed key (gratis)
      encryption: dynamodb.TableEncryption.AWS_MANAGED,

      // Point-in-time recovery (backup continuo)
      // IMPORTANTE: Esto tiene costo adicional, evaluar según necesidades
      pointInTimeRecovery: stage === "prod",

      // Deletion protection para producción
      deletionProtection: stage === "prod",

      // Removal policy: qué hacer cuando se destruye el stack
      // RETAIN en prod, DESTROY en dev
      removalPolicy: stage === "prod"
        ? cdk.RemovalPolicy.RETAIN
        : cdk.RemovalPolicy.DESTROY,

      // Time to Live (TTL) - opcional, útil para expirar registros automáticamente
      // timeToLiveAttribute: "expiresAt",
    });

    // ========================================
    // Global Secondary Index (GSI) para email
    // ========================================
    /**
     * Índice secundario que permite buscar usuarios por email.
     *
     * En DynamoDB solo puedes hacer queries eficientes por partition key.
     * Para buscar por otros atributos necesitas un GSI.
     *
     * Proyección ALL: copia todos los atributos al índice (más storage, pero queries más rápidas)
     * Alternativa: KEYS_ONLY o INCLUDE para proyecciones parciales
     */
    this.usersTable.addGlobalSecondaryIndex({
      indexName: "EmailIndex",
      partitionKey: {
        name: "email",
        type: dynamodb.AttributeType.STRING,
      },
      // Proyección: qué atributos se copian al índice
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // ========================================
    // CloudFormation Outputs
    // ========================================
    /**
     * Outputs que puedes referenciar desde otros stacks o procesos.
     * Útil para integración con Serverless Framework o terraform.
     */

    new cdk.CfnOutput(this, "UsersTableName", {
      value: this.usersTable.tableName,
      description: "Nombre de la tabla DynamoDB de usuarios",
      exportName: `UsersTableName-${stage}`,
    });

    new cdk.CfnOutput(this, "UsersTableArn", {
      value: this.usersTable.tableArn,
      description: "ARN de la tabla DynamoDB de usuarios",
      exportName: `UsersTableArn-${stage}`,
    });

    new cdk.CfnOutput(this, "UserCreatedQueueUrl", {
      value: this.userCreatedQueue.queueUrl,
      description: "URL de la cola SQS de UserCreated",
      exportName: `UserCreatedQueueUrl-${stage}`,
    });

    new cdk.CfnOutput(this, "UserCreatedQueueArn", {
      value: this.userCreatedQueue.queueArn,
      description: "ARN de la cola SQS de UserCreated",
      exportName: `UserCreatedQueueArn-${stage}`,
    });

    new cdk.CfnOutput(this, "UserCreatedDLQUrl", {
      value: this.userCreatedDLQ.queueUrl,
      description: "URL de la DLQ de UserCreated",
      exportName: `UserCreatedDLQUrl-${stage}`,
    });

    // ========================================
    // Tags adicionales a nivel de recursos
    // ========================================
    /**
     * Tags para mejor organización y cost tracking
     */
    cdk.Tags.of(this.usersTable).add("Service", "users-service");
    cdk.Tags.of(this.usersTable).add("ResourceType", "database");

    cdk.Tags.of(this.userCreatedQueue).add("Service", "users-service");
    cdk.Tags.of(this.userCreatedQueue).add("ResourceType", "messaging");

    cdk.Tags.of(this.userCreatedDLQ).add("Service", "users-service");
    cdk.Tags.of(this.userCreatedDLQ).add("ResourceType", "messaging");
  }
}
