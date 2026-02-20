#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script para detener el entorno de desarrollo del proyecto Ecommerce Microservices

.DESCRIPTION
    Este script detiene todos los servicios de manera ordenada:
    1. Detiene los microservicios
    2. Detiene LocalStack
    3. Opcionalmente limpia volúmenes

.EXAMPLE
    .\stop-dev-environment.ps1

.EXAMPLE
    .\stop-dev-environment.ps1 -Clean

.NOTES
    El flag -Clean eliminará los volúmenes de Docker (pérdida de datos)
#>

[CmdletBinding()]
param(
    # Si se especifica, elimina los volúmenes de Docker (limpieza completa)
    [switch]$Clean,

    # Si se especifica, solo detiene LocalStack
    [switch]$OnlyLocalStack
)

$ErrorActionPreference = "Stop"
# Directorio raíz del proyecto (un nivel arriba de scripts/)
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot

# Colores
$COLOR_SUCCESS = "Green"
$COLOR_INFO = "Cyan"
$COLOR_WARNING = "Yellow"

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

# ============================================
# DETENER SERVICIOS
# ============================================

Push-Location $PROJECT_ROOT

if (-not $OnlyLocalStack) {
    Write-Step "Deteniendo microservicios"

    if ($Clean) {
        Write-Warning "Modo CLEAN activado - Se eliminarán todos los volúmenes"
        docker-compose -f docker-compose-dev.yml down -v
    }
    else {
        docker-compose -f docker-compose-dev.yml down
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Success "Microservicios detenidos"
    }
}

Write-Step "Deteniendo LocalStack"

if ($Clean) {
    docker-compose -f docker-compose.localstack.yml down -v
}
else {
    docker-compose -f docker-compose.localstack.yml down
}

if ($LASTEXITCODE -eq 0) {
    Write-Success "LocalStack detenido"
}

Pop-Location

# ============================================
# RESUMEN
# ============================================

Write-Host ""
Write-Host "🛑 Entorno de desarrollo detenido" -ForegroundColor $COLOR_SUCCESS

if ($Clean) {
    Write-Host ""
    Write-Warning "Se han eliminado todos los volúmenes (datos perdidos)"
    Write-Info "La próxima vez que inicies el entorno, será desde cero"
}
else {
    Write-Host ""
    Write-Info "Los volúmenes se han preservado"
    Write-Info "La próxima vez que inicies el entorno, los datos estarán intactos"
}

Write-Host ""
