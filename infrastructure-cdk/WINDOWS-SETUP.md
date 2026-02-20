# 🪟 Setup para Windows - AWS CDK + LocalStack

Guía específica para configurar y usar AWS CDK con LocalStack en Windows.

## 📋 Requisitos

- **Windows 10/11** con WSL2
- **Docker Desktop** con WSL2 backend
- **PowerShell 7+** (pwsh)
- **Node.js 20+** instalado en Windows
- **AWS CLI v2** (opcional pero recomendado)

## 🚀 Instalación de Requisitos

### 1. Instalar PowerShell 7+

```powershell
# Desde PowerShell como administrador
winget install --id Microsoft.Powershell --source winget
```

O descarga desde: https://github.com/PowerShell/PowerShell/releases

### 2. Instalar Docker Desktop

Descarga e instala desde: https://www.docker.com/products/docker-desktop

**Importante**: Asegúrate de habilitar WSL2 backend en la configuración.

### 3. Instalar Node.js 20+

```powershell
# Con winget
winget install OpenJS.NodeJS.LTS

# O descarga desde: https://nodejs.org
```

### 4. Instalar AWS CLI (opcional)

```powershell
# Descargar e instalar
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
```

O usa Chocolatey:
```powershell
choco install awscli
```

## 🎯 Inicio Rápido

### Opción 1: Script Automatizado (Recomendado)

Abre **PowerShell 7** (pwsh) en la raíz del proyecto:

```powershell
# Permitir ejecución de scripts (solo primera vez)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Ejecutar el script
.\start-dev-environment.ps1
```

### Opción 2: Comandos Manuales

```powershell
# 1. Levantar LocalStack
docker-compose -f docker-compose.localstack.yml up -d

# 2. Esperar a que esté listo
curl http://localhost:4566/_localstack/health

# 3. Ir a CDK
cd infrastructure-cdk

# 4. Instalar dependencias
npm install

# 5. Configurar variables de entorno
$env:AWS_REGION="us-east-1"
$env:AWS_ACCESS_KEY_ID="test"
$env:AWS_SECRET_ACCESS_KEY="test"
$env:AWS_ENDPOINT_URL="http://localhost:4566"
$env:STAGE="dev"

# 6. Bootstrap CDK
npm run bootstrap

# 7. Ver diferencias
npm run diff

# 8. Desplegar
npm run deploy
```

## 🔧 Configuración de AWS CLI para LocalStack

### Crear perfil LocalStack

Edita `%USERPROFILE%\.aws\config`:

```ini
[profile localstack]
region = us-east-1
output = json
```

Edita `%USERPROFILE%\.aws\credentials`:

```ini
[localstack]
aws_access_key_id = test
aws_secret_access_key = test
```

### Usar con LocalStack

```powershell
# Opción 1: Con endpoint-url
aws --endpoint-url=http://localhost:4566 dynamodb list-tables

# Opción 2: Con perfil y endpoint
aws --profile localstack --endpoint-url=http://localhost:4566 dynamodb list-tables

# Opción 3: Crear alias (agregar a $PROFILE)
function awslocal {
    aws --endpoint-url=http://localhost:4566 @args
}

# Uso del alias
awslocal dynamodb list-tables
awslocal sqs list-queues
```

### Agregar alias permanente

Edita tu perfil de PowerShell:

```powershell
# Abrir perfil
notepad $PROFILE

# Agregar al archivo
function awslocal {
    aws --endpoint-url=http://localhost:4566 @args
}
```

## 🐛 Troubleshooting Windows-Specific

### Error: "docker: command not found"

**Causa**: Docker Desktop no está en el PATH o no está corriendo.

**Solución**:
1. Reinicia Docker Desktop
2. Verifica que esté corriendo: `docker version`
3. Si no está en PATH, agrega: `C:\Program Files\Docker\Docker\resources\bin`

### Error: "Cannot load npm module"

**Causa**: npm usa paths de Linux en scripts.

**Solución**: Usa PowerShell 7 (pwsh), no Windows PowerShell 5.1.

### Error: "Execution policy"

**Causa**: PowerShell bloquea la ejecución de scripts por defecto.

**Solución**:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Error: "Port already in use"

**Causa**: Otro proceso está usando el puerto.

**Solución**:
```powershell
# Ver qué proceso usa el puerto 4566
netstat -ano | findstr :4566

# Matar el proceso (reemplaza <PID>)
taskkill /PID <PID> /F
```

### LocalStack no persiste datos

**Causa**: Ruta de volumen de Docker no tiene permisos.

**Solución**:
1. Abre Docker Desktop
2. Ve a Settings → Resources → File Sharing
3. Agrega la ruta del proyecto
4. Reinicia Docker Desktop

### CDK falla con "Unable to resolve AWS account"

**Causa**: Variables de entorno no están configuradas.

**Solución**:
```powershell
# Configurar variables
$env:AWS_REGION="us-east-1"
$env:AWS_ACCESS_KEY_ID="test"
$env:AWS_SECRET_ACCESS_KEY="test"
$env:AWS_ENDPOINT_URL="http://localhost:4566"
$env:STAGE="dev"

# Verificar
echo $env:AWS_REGION
```

## 📁 Estructura de Archivos en Windows

```
C:\Users\<tu-usuario>\ecommerce\
├── infrastructure-cdk\
│   ├── .localstack\              # Datos persistentes de LocalStack
│   ├── bin\app.ts                # Entry point de CDK
│   ├── lib\users-service-stack.ts
│   └── package.json
├── docker-compose.localstack.yml
├── docker-compose-dev.yml
├── start-dev-environment.ps1     # 🪟 Script para Windows
├── stop-dev-environment.ps1      # 🪟 Script para Windows
└── QUICKSTART.md
```

## 🎨 Customización del Script PowerShell

### Variables de Entorno Personalizadas

Crea un archivo `.env.local` en `infrastructure-cdk/`:

```env
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=000000000000
STAGE=dev
```

Luego modifica el script para cargar este archivo:

```powershell
# En start-dev-environment.ps1, agregar al inicio:
if (Test-Path "$CDK_DIR\.env.local") {
    Get-Content "$CDK_DIR\.env.local" | ForEach-Object {
        $key, $value = $_ -split '=', 2
        Set-Item -Path "env:$key" -Value $value
    }
}
```

## 🔗 Recursos Adicionales

### Enlaces Útiles

- [PowerShell 7 Docs](https://docs.microsoft.com/en-us/powershell/scripting/overview)
- [Docker Desktop WSL2](https://docs.docker.com/desktop/windows/wsl/)
- [AWS CDK Windows](https://docs.aws.amazon.com/cdk/v2/guide/work-with-cdk-windows.html)
- [LocalStack Docs](https://docs.localstack.cloud/getting-started/installation/)

### Comandos PowerShell Útiles

```powershell
# Ver variables de entorno
Get-ChildItem Env: | Where-Object { $_.Name -like "AWS_*" }

# Limpiar variables de entorno
Remove-Item Env:AWS_ENDPOINT_URL
Remove-Item Env:AWS_ACCESS_KEY_ID
Remove-Item Env:AWS_SECRET_ACCESS_KEY

# Ver contenedores Docker
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Ver logs en tiempo real
docker logs -f ecommerce-localstack

# Ejecutar comando en contenedor
docker exec -it ecommerce-localstack sh
```

## ✅ Checklist de Verificación

Después de la instalación, verifica que todo funcione:

- [ ] Docker Desktop está corriendo
- [ ] PowerShell 7+ está instalado: `pwsh --version`
- [ ] Node.js 20+ está instalado: `node --version`
- [ ] npm funciona: `npm --version`
- [ ] Docker funciona: `docker version`
- [ ] LocalStack levanta: `docker-compose -f docker-compose.localstack.yml up -d`
- [ ] LocalStack responde: `curl http://localhost:4566/_localstack/health`
- [ ] AWS CLI funciona (opcional): `aws --version`
- [ ] CDK se puede instalar: `cd infrastructure-cdk && npm install`
- [ ] CDK synth funciona: `npm run synth`

## 🎓 Tips y Trucos

### Alias útiles en PowerShell

Agrega a tu `$PROFILE`:

```powershell
# Alias para CDK con LocalStack
function cdk-local {
    $env:AWS_ENDPOINT_URL="http://localhost:4566"
    $env:AWS_REGION="us-east-1"
    $env:AWS_ACCESS_KEY_ID="test"
    $env:AWS_SECRET_ACCESS_KEY="test"
    npm run $args
}

# Uso
cdk-local diff
cdk-local deploy
```

### Debugging

```powershell
# Ver variables de entorno CDK
$env:DEBUG="aws-cdk:*"

# Ver logs detallados de LocalStack
docker logs -f --tail=100 ecommerce-localstack

# Ver qué recursos existen en LocalStack
awslocal dynamodb list-tables
awslocal sqs list-queues
awslocal s3 ls
```

---

**¿Problemas?** Abre un issue o consulta [QUICKSTART.md](../QUICKSTART.md)
