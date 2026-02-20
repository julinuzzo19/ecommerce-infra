#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de inicio automatizado para el entorno de desarrollo del proyecto Ecommerce Microservices

.DESCRIPTION
    Este script automatiza el proceso completo de inicialización del entorno de desarrollo:
    1. Levanta LocalStack (emulador de AWS)
    2. Levanta todos los microservicios con docker-compose-dev.yml
    3. Espera a que los servicios estén saludables
    4. Ejecuta el bootstrap de AWS CDK contra LocalStack
    5. Despliega la infraestructura con CDK
    6. Muestra un resumen del estado de los servicios

.EXAMPLE
    .\start-dev-environment.ps1

.EXAMPLE
    .\start-dev-environment.ps1 -SkipCDK

.NOTES
    Requisitos:
    - Docker Desktop instalado y corriendo
    - Node.js 20+ instalado
    - PowerShell 7+ (pwsh)
#>

[CmdletBinding()]
param(
    # Si se especifica, no ejecuta los pasos de CDK (solo levanta Docker)
    [switch]$SkipCDK,

    # Si se especifica, no levanta los servicios (solo LocalStack y CDK)
    [switch]$OnlyInfrastructure,

    # Si se especifica, reconstruye las imágenes de Docker
    [switch]$Build
)

# ============================================
# CONFIGURACIÓN
# ============================================

$ErrorActionPreference = "Stop"
# Directorio raíz del proyecto (un nivel arriba de scripts/)
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$CDK_DIR = Join-Path $PROJECT_ROOT "infrastructure-cdk"

# Colores para output
$COLOR_SUCCESS = "Green"
$COLOR_INFO = "Cyan"
$COLOR_WARNING = "Yellow"
$COLOR_ERROR = "Red"

# ============================================
# FUNCIONES AUXILIARES
# ============================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n========================================" -ForegroundColor $COLOR_INFO
    Write-Host "  $Message" -ForegroundColor $COLOR_INFO
    Write-Host "========================================`n" -ForegroundColor $COLOR_INFO
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $COLOR_SUCCESS
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $COLOR_INFO
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor $COLOR_WARNING
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $COLOR_ERROR
}

function Test-DockerRunning {
    try {
        docker info 2>&1 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Wait-ForService {
    param(
        [string]$ServiceName,
        [string]$Url,
        [int]$MaxRetries = 30,
        [int]$RetryDelaySeconds = 2
    )

    Write-Info "Esperando a que $ServiceName esté listo..."

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $Url -Method GET -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Success "$ServiceName está listo!"
                return $true
            }
        }
        catch {
            # Servicio aún no está listo
        }

        Write-Host "." -NoNewline
        Start-Sleep -Seconds $RetryDelaySeconds
    }

    Write-Warning "$ServiceName no respondió después de $MaxRetries intentos"
    return $false
}

# ============================================
# VALIDACIONES PREVIAS
# ============================================

Write-Step "Validando requisitos previos"

# Verificar Docker
if (-not (Test-DockerRunning)) {
    Write-Error "Docker no está corriendo. Por favor inicia Docker Desktop."
    exit 1
}
Write-Success "Docker está corriendo"

# Verificar Node.js
try {
    $nodeVersion = node --version
    Write-Success "Node.js instalado: $nodeVersion"
}
catch {
    Write-Error "Node.js no está instalado. Instala Node.js 20+ desde https://nodejs.org"
    exit 1
}

# Verificar npm
try {
    $npmVersion = npm --version
    Write-Success "npm instalado: v$npmVersion"
}
catch {
    Write-Error "npm no está disponible"
    exit 1
}

# ============================================
# PASO 1: LEVANTAR LOCALSTACK
# ============================================

Write-Step "Paso 1: Levantando LocalStack"

Push-Location $PROJECT_ROOT

$buildFlag = if ($Build) { "--build" } else { "" }

Write-Info "Ejecutando: docker-compose -f docker-compose.localstack.yml up -d $buildFlag"
docker-compose -f docker-compose.localstack.yml up -d $buildFlag

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falló al levantar LocalStack"
    Pop-Location
    exit 1
}

Write-Success "LocalStack iniciado"

# Esperar a que LocalStack esté listo
if (-not (Wait-ForService -ServiceName "LocalStack" -Url "http://localhost:4566/_localstack/health" -MaxRetries 30)) {
    Write-Error "LocalStack no está respondiendo. Verifica los logs con: docker logs ecommerce-localstack"
    Pop-Location
    exit 1
}

Pop-Location

# ============================================
# PASO 2: LEVANTAR SERVICIOS (OPCIONAL)
# ============================================

if (-not $OnlyInfrastructure) {
    Write-Step "Paso 2: Levantando microservicios"

    Push-Location $PROJECT_ROOT

    Write-Info "Ejecutando: docker-compose -f docker-compose-dev.yml up -d $buildFlag"
    docker-compose -f docker-compose-dev.yml up -d $buildFlag

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falló al levantar los microservicios"
        Pop-Location
        exit 1
    }

    Write-Success "Microservicios iniciados"

    # Esperar a que servicios críticos estén listos
    Write-Info "Esperando a que los servicios estén saludables (esto puede tomar 1-2 minutos)..."
    Start-Sleep -Seconds 10

    Pop-Location
}
else {
    Write-Info "Saltando inicio de microservicios (modo solo infraestructura)"
}

# ============================================
# PASO 3: INSTALAR DEPENDENCIAS CDK
# ============================================

if (-not $SkipCDK) {
    Write-Step "Paso 3: Instalando dependencias de CDK"

    Push-Location $CDK_DIR

    if (-not (Test-Path "node_modules")) {
        Write-Info "Instalando dependencias de npm..."
        npm install

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Falló la instalación de dependencias de CDK"
            Pop-Location
            exit 1
        }

        Write-Success "Dependencias instaladas"
    }
    else {
        Write-Success "Dependencias ya instaladas"
    }

    Pop-Location
}

# ============================================
# PASO 4: BOOTSTRAP CDK (SI ES NECESARIO)
# ============================================

if (-not $SkipCDK) {
    Write-Step "Paso 4: Bootstrap de AWS CDK en LocalStack"

    Push-Location $CDK_DIR

    # Configurar variables de entorno para LocalStack
    $env:AWS_REGION = "us-east-1"
    $env:AWS_ACCESS_KEY_ID = "test"
    $env:AWS_SECRET_ACCESS_KEY = "test"
    $env:AWS_ENDPOINT_URL = "http://localhost:4566"
    $env:STAGE = "dev"

    Write-Info "Ejecutando CDK bootstrap contra LocalStack..."
    Write-Info "Endpoint: http://localhost:4566"

    # Ejecutar bootstrap (puede fallar si ya está hecho, es normal)
    npm run bootstrap 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Bootstrap completado exitosamente"
    }
    else {
        Write-Warning "Bootstrap falló o ya estaba hecho (esto es normal si ya corriste el script antes)"
    }

    Pop-Location
}

# ============================================
# PASO 5: DESPLEGAR INFRAESTRUCTURA CON CDK
# ============================================

if (-not $SkipCDK) {
    Write-Step "Paso 5: Desplegando infraestructura con CDK"

    Push-Location $CDK_DIR

    # Variables de entorno ya están configuradas del paso anterior

    Write-Info "Ejecutando CDK diff para ver cambios..."
    npm run diff

    Write-Host "`n"
    $response = Read-Host "¿Deseas desplegar la infraestructura? (y/N)"

    if ($response -eq "y" -or $response -eq "Y") {
        Write-Info "Desplegando stack..."
        npm run deploy -- --require-approval never

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Infraestructura desplegada exitosamente"
        }
        else {
            Write-Error "Falló el deployment de CDK"
            Pop-Location
            exit 1
        }
    }
    else {
        Write-Info "Deployment cancelado por el usuario"
    }

    Pop-Location
}

# ============================================
# RESUMEN FINAL
# ============================================

Write-Step "Resumen del entorno"

Write-Host ""
Write-Host "🎉 Entorno de desarrollo iniciado exitosamente!" -ForegroundColor $COLOR_SUCCESS
Write-Host ""

Write-Host "📦 SERVICIOS DE INFRAESTRUCTURA:" -ForegroundColor $COLOR_INFO
Write-Host "  • LocalStack:          http://localhost:4566" -ForegroundColor White
Write-Host "  • LocalStack Health:   http://localhost:4566/_localstack/health" -ForegroundColor White

if (-not $OnlyInfrastructure) {
    Write-Host ""
    Write-Host "🚀 MICROSERVICIOS:" -ForegroundColor $COLOR_INFO
    Write-Host "  • API Gateway:         http://localhost:3000" -ForegroundColor White
    Write-Host "  • Auth Service:        http://localhost:3010" -ForegroundColor White
    Write-Host "  • Users Service:       http://localhost:3012" -ForegroundColor White
    Write-Host "  • Inventory Service:   http://localhost:3011" -ForegroundColor White
    Write-Host "  • Order-Product:       http://localhost:3600" -ForegroundColor White

    Write-Host ""
    Write-Host "💾 BASES DE DATOS:" -ForegroundColor $COLOR_INFO
    Write-Host "  • MySQL (Users):       localhost:3307" -ForegroundColor White
    Write-Host "  • DynamoDB Local:      http://localhost:8000" -ForegroundColor White
    Write-Host "  • PostgreSQL (Inv):    localhost:5434" -ForegroundColor White
    Write-Host "  • PostgreSQL (Order):  localhost:5432" -ForegroundColor White

    Write-Host ""
    Write-Host "📊 OBSERVABILIDAD:" -ForegroundColor $COLOR_INFO
    Write-Host "  • Grafana:             http://localhost:3001 (admin/admin)" -ForegroundColor White
    Write-Host "  • Prometheus:          http://localhost:9090" -ForegroundColor White
    Write-Host "  • RabbitMQ Management: http://localhost:15672 (user/password)" -ForegroundColor White
}

Write-Host ""
Write-Host "🛠️  COMANDOS ÚTILES:" -ForegroundColor $COLOR_INFO
Write-Host "  • Ver logs LocalStack:     docker logs -f ecommerce-localstack" -ForegroundColor White
Write-Host "  • Ver todos los logs:      docker-compose -f docker-compose-dev.yml logs -f" -ForegroundColor White
Write-Host "  • Detener todo:            docker-compose -f docker-compose-dev.yml down && docker-compose -f docker-compose.localstack.yml down" -ForegroundColor White
Write-Host "  • Ver recursos LocalStack: aws --endpoint-url=http://localhost:4566 dynamodb list-tables" -ForegroundColor White

Write-Host ""
Write-Host "✨ Para más información, consulta el README.md en infrastructure-cdk/" -ForegroundColor $COLOR_SUCCESS
Write-Host ""
