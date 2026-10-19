<#
============================================================================
 VISOR CATASTRAL - VILLA DE MERLO
 Instala el visor como Servicio de Windows (via NSSM), para que arranque
 solo al prender la computadora, sin depender de dejar una ventana abierta.

 Que hace:
   1. Busca NSSM en herramientas\nssm\. Si no esta, lo descarga (una sola
      vez; necesita internet solo esa primera vez, igual que INSTALAR.bat
      con npm install).
   2. Crea (o actualiza, si ya existe) el servicio "VisorCatastralMerlo".
   3. Lo deja escuchando SIEMPRE en el puerto indicado (8002 por defecto),
      sin importar lo que diga servidor\.env. El .env sigue usandose para
      todo lo demas (conexion a la base, limites, etc.).
   4. Lo configura para reiniciarse solo si Node se cae, y para arrancar
      con la computadora (inicio automatico retrasado, asi le da tiempo a
      la red antes de intentar conectarse a la base).
   5. Guarda los logs del servicio en servidor\logs\.

 Se puede volver a ejecutar cuando haga falta: si el servicio ya existe,
 lo reconfigura en vez de duplicarlo.

 Requiere permisos de administrador.
============================================================================
#>

param(
    [int]$Puerto = 8002,
    [string]$NombreServicio = "VisorCatastralMerlo"
)

# No se usa $ErrorActionPreference = "Stop": con eso, cualquier texto que un
# programa nativo (como nssm.exe) escriba en su salida de error se convierte
# en una excepcion que corta el script. "nssm status" devuelve un codigo de
# salida distinto de cero, y a veces tambien un mensaje por stderr ("Can't
# open service!"), cuando el servicio TODAVIA no existe: es el resultado
# normal la primera vez que se instala, no una falla real. El script decide
# que hacer mirando $LASTEXITCODE a mano (mas abajo), no dejando que
# PowerShell lo convierta en excepcion.
$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false

$raiz        = Split-Path -Parent $PSScriptRoot
$dirServidor = Join-Path $raiz "servidor"
$dirNssm     = Join-Path $PSScriptRoot "nssm"
$dirLogs     = Join-Path $dirServidor "logs"

function Salir-Error($mensaje) {
    Write-Host ""
    Write-Host "ERROR: $mensaje" -ForegroundColor Red
    Write-Host ""
    exit 1
}

# --- Permisos de administrador ----------------------------------------------
$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Salir-Error "Este paso necesita permisos de administrador. Cerrar esta ventana, click derecho sobre INSTALAR.bat y elegir 'Ejecutar como administrador'."
}

# --- Verificaciones previas: que INSTALAR.bat ya se haya corrido -----------
if (-not (Test-Path (Join-Path $dirServidor "server.js"))) {
    Salir-Error "No se encuentra servidor\server.js. Ejecutar este script desde la carpeta del programa."
}
if (-not (Test-Path (Join-Path $dirServidor "node_modules"))) {
    Salir-Error "Faltan los componentes del servidor. Ejecutar primero INSTALAR.bat."
}
if (-not (Test-Path (Join-Path $dirServidor ".env"))) {
    Salir-Error "Falta la configuracion de la base de datos. Ejecutar primero INSTALAR.bat o CONFIGURAR.bat."
}

$nodePath = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $nodePath) {
    Salir-Error "No se encuentra Node.js. Ejecutar primero INSTALAR.bat."
}

# --- Paso 1: conseguir NSSM -------------------------------------------------
$arq     = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
$nssmExe = Join-Path $dirNssm "$arq\nssm.exe"

if (-not (Test-Path $nssmExe)) {
    Write-Host "  Descargando NSSM (una sola vez)..."
    New-Item -ItemType Directory -Force -Path $dirNssm | Out-Null
    $zip = Join-Path $env:TEMP "nssm.zip"
    try {
        Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile $zip -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $zip -DestinationPath $dirNssm -Force -ErrorAction Stop
        New-Item -ItemType Directory -Force -Path (Join-Path $dirNssm "win64") -ErrorAction Stop | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $dirNssm "win32") -ErrorAction Stop | Out-Null
        Copy-Item (Join-Path $dirNssm "nssm-2.24\win64\nssm.exe") (Join-Path $dirNssm "win64\nssm.exe") -Force -ErrorAction Stop
        Copy-Item (Join-Path $dirNssm "nssm-2.24\win32\nssm.exe") (Join-Path $dirNssm "win32\nssm.exe") -Force -ErrorAction Stop
        Remove-Item (Join-Path $dirNssm "nssm-2.24") -Recurse -Force -ErrorAction Stop
        Remove-Item $zip -Force -ErrorAction Stop
    } catch {
        Salir-Error "No se pudo descargar NSSM. Verificar la conexion a internet, o copiar nssm.exe a mano en herramientas\nssm\$arq\nssm.exe (se consigue en nssm.cc)."
    }
}

if (-not (Test-Path $nssmExe)) {
    Salir-Error "NSSM no quedo disponible en $nssmExe"
}

New-Item -ItemType Directory -Force -Path $dirLogs | Out-Null

# --- Paso 2: crear o actualizar el servicio ---------------------------------
& $nssmExe status $NombreServicio *> $null
$yaExiste = ($LASTEXITCODE -eq 0)

if ($yaExiste) {
    Write-Host "  El servicio ya existe. Actualizando configuracion..."
    & $nssmExe stop $NombreServicio | Out-Null
} else {
    Write-Host "  Creando el servicio..."
    & $nssmExe install $NombreServicio $nodePath "server.js"
}

& $nssmExe set $NombreServicio AppDirectory $dirServidor
& $nssmExe set $NombreServicio AppParameters "server.js"
& $nssmExe set $NombreServicio DisplayName "Visor Catastral - Villa de Merlo"
& $nssmExe set $NombreServicio Description "Sirve el Visor Catastral (mapa + fichas de parcelas) en http://localhost:$Puerto/. Instalado con NSSM."
& $nssmExe set $NombreServicio Start SERVICE_DELAYED_AUTO_START
& $nssmExe set $NombreServicio AppEnvironmentExtra "PORT=$Puerto"
& $nssmExe set $NombreServicio AppStdout (Join-Path $dirLogs "servicio.log")
& $nssmExe set $NombreServicio AppStderr (Join-Path $dirLogs "servicio-error.log")
& $nssmExe set $NombreServicio AppRotateFiles 1
& $nssmExe set $NombreServicio AppRotateOnline 1
& $nssmExe set $NombreServicio AppRotateBytes 10485760
& $nssmExe set $NombreServicio AppExit Default Restart
& $nssmExe set $NombreServicio AppRestartDelay 5000

& $nssmExe start $NombreServicio | Out-Null
Start-Sleep -Seconds 2
$estado = & $nssmExe status $NombreServicio

Write-Host ""
if ($estado -match "SERVICE_RUNNING") {
    Write-Host "  Listo. El servicio quedo instalado y esta corriendo." -ForegroundColor Green
    Write-Host "  A partir de ahora el visor abre solo, con la computadora, en:"
    Write-Host "      http://localhost:$Puerto/"
    Write-Host ""
    Write-Host "  Ya no hace falta INICIAR.bat ni dejar ninguna ventana abierta."
    Write-Host "  (INICIAR.bat sigue funcionando igual, como respaldo manual si el"
    Write-Host "   servicio estuviera detenido.)"
    Write-Host ""
    exit 0
} else {
    Write-Host "  El servicio quedo instalado pero no arranco. Estado: $estado" -ForegroundColor Yellow
    Write-Host "  Revisar servidor\logs\servicio-error.log para el detalle."
    Write-Host ""
    exit 1
}
