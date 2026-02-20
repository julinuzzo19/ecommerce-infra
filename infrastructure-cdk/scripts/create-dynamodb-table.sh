#!/bin/bash
set -e

# ============================================
# Script para crear tabla DynamoDB en LocalStack
# Alternativa simple a CDK para desarrollo local
# ============================================

ENDPOINT_URL="${AWS_ENDPOINT_URL:-http://localhost:4566}"
TABLE_NAME="users-service-db"
REGION="${AWS_REGION:-us-east-1}"

echo "🔧 Creando tabla DynamoDB en LocalStack..."
echo "   Endpoint: $ENDPOINT_URL"
echo "   Tabla: $TABLE_NAME"
echo "   Región: $REGION"
echo ""

# Verificar si la tabla ya existe
if aws --endpoint-url="$ENDPOINT_URL" dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
    echo "✅ La tabla '$TABLE_NAME' ya existe"

    # Mostrar información de la tabla
    aws --endpoint-url="$ENDPOINT_URL" dynamodb describe-table \
        --table-name "$TABLE_NAME" \
        --query 'Table.[TableName,TableStatus,ItemCount,GlobalSecondaryIndexes[0].IndexName]' \
        --output table

    exit 0
fi

echo "📝 Creando tabla '$TABLE_NAME'..."

# Crear tabla DynamoDB con el mismo esquema que el CDK Stack
aws --endpoint-url="$ENDPOINT_URL" dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
        AttributeName=email,AttributeType=S \
    --key-schema \
        AttributeName=id,KeyType=HASH \
    --global-secondary-indexes \
        "[{
            \"IndexName\": \"EmailIndex\",
            \"KeySchema\": [{\"AttributeName\":\"email\",\"KeyType\":\"HASH\"}],
            \"Projection\": {\"ProjectionType\":\"ALL\"},
            \"ProvisionedThroughput\": {\"ReadCapacityUnits\":5,\"WriteCapacityUnits\":5}
        }]" \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION" \
    --output json > /dev/null

echo ""
echo "✅ Tabla '$TABLE_NAME' creada exitosamente!"
echo ""

# Verificar que la tabla esté activa
echo "⏳ Esperando a que la tabla esté activa..."
aws --endpoint-url="$ENDPOINT_URL" dynamodb wait table-exists --table-name "$TABLE_NAME"

echo "✅ Tabla activa y lista para usar"
echo ""

# Mostrar detalles de la tabla
echo "📊 Detalles de la tabla:"
aws --endpoint-url="$ENDPOINT_URL" dynamodb describe-table \
    --table-name "$TABLE_NAME" \
    --query 'Table.{Name:TableName,Status:TableStatus,Keys:KeySchema,GSI:GlobalSecondaryIndexes[0].IndexName}' \
    --output table

echo ""
echo "🎉 ¡Listo! Ahora puedes usar la tabla '$TABLE_NAME' en LocalStack"
