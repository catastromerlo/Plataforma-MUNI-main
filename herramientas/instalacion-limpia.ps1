# =============================================================================
#  VISOR CATASTRAL - VILLA DE MERLO
#  Instalacion limpia en una carpeta, de una sola vez
# -----------------------------------------------------------------------------
#  QUE HACE
#    Descarga la ultima version, la instala en la carpeta indicada, instala los
#    componentes, abre la ventana de configuracion de la base, deja el visor
#    instalado como Servicio de Windows (si esta consola es de administrador;
#    si no, queda para hacerlo despues) y crea un acceso directo en el
#    escritorio. Al final avisa si quedaron copias viejas del programa dando
#    vueltas.
#
#  POR QUE
#    Bajar el ZIP y descomprimir a mano deja una carpeta nueva cada vez. Con
#    varias copias iguales es facil actualizar una y ejecutar otra, y entonces
#    los arreglos "no aparecen" aunque esten aplicados. Este camino instala en
#    un lugar definido y deja un unico acceso directo, para que no haya de
#    donde equivocarse.
#
#  USO
#    powershell -ExecutionPolicy Bypass -File instalacion-limpia.ps1
#    powershell -ExecutionPolicy Bypass -File instalacion-limpia.ps1 -Destino "C:\OtraCarpeta"
# =============================================================================

param(
    [string]$Destino = "C:\VisorCatastral"
)

$ErrorActionPreference = "Stop"
$origen = "https://github.com/catastromerlo/Plataforma-MUNI-main/archive/refs/heads/main.zip"

Write-Host ""
Write-Host "  ============================================================"
Write-Host "   VISOR CATASTRAL - VILLA DE MERLO"
Write-Host "   Instalacion limpia"
Write-Host "  ============================================================"
Write-Host ""
Write-Host "   Se va a instalar en:"
Write-Host "   $Destino"
Write-Host ""

# --- Node.js -----------------------------------------------------------------
Write-Host "  [1/7] Verificando Node.js..."
$node = Get-Command node -EA SilentlyContinue
if (-not $node) {
    Write-Host ""
    Write-Host "  Node.js no esta instalado en esta computadora."
    Write-Host "  Se baja gratis de https://nodejs.org (version LTS),"
    Write-Host "  se instala con las opciones por defecto, y se vuelve a"
    Write-Host "  ejecutar este script."
    Write-Host ""
    exit 1
}
Write-Host "        $(node --version) encontrado."

# --- Configuracion existente, si la hubiera ----------------------------------
# Si ya habia una instalacion ahi, se conserva su configuracion: es lo unico
# que no se puede volver a generar solo.
$envGuardado = $null
$envPrevio = Join-Path $Destino "servidor\.env"
if (Test-Path $envPrevio) {
    $envGuardado = Get-Content $envPrevio -Raw
    Write-Host "        Se encontro una configuracion anterior: se conserva."
}

# --- Descarga ----------------------------------------------------------------
Write-Host "  [2/7] Descargando la ultima version..."
$temporal = Join-Path $env:TEMP ("visor-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $temporal -Force | Out-Null
$zip = Join-Path $temporal "programa.zip"

try {
    # TLS 1.2 explicito: en equipos con configuracion antigua la descarga desde
    # GitHub falla sin explicar el motivo.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $origen -OutFile $zip -UseBasicParsing
    Write-Host "        Descargada."

    Write-Host "  [3/7] Instalando los archivos..."
    Expand-Archive -Path $zip -DestinationPath $temporal -Force
    $contenido = Get-ChildItem -Path $temporal -Directory | Select-Object -First 1
    if (-not $contenido) { throw "El archivo descargado no tiene el contenido esperado." }

    New-Item -ItemType Directory -Path $Destino -Force | Out-Null
    Copy-Item -Path (Join-Path $contenido.FullName "*") -Destination $Destino -Recurse -Force
    Write-Host "        Instalados."

    # Devolver la configuracion anterior
    if ($envGuardado) {
        $sinBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText((Join-Path $Destino "servidor\.env"), $envGuardado, $sinBom)
        Write-Host "        Configuracion anterior restaurada."
    }

} finally {
    if (Test-Path $temporal) { Remove-Item $temporal -Recurse -Force -EA SilentlyContinue }
}

# --- Componentes -------------------------------------------------------------
Write-Host "  [4/7] Instalando componentes (puede tardar unos minutos)..."
Push-Location (Join-Path $Destino "servidor")
try {
    & npm install --no-audit --no-fund 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "npm install fallo" }
    Write-Host "        Instalados."
} catch {
    Write-Host ""
    Write-Host "        No se pudieron instalar los componentes."
    Write-Host "        La causa mas comun es que la computadora no tenga"
    Write-Host "        salida a internet. Se bajan una sola vez."
    Write-Host ""
} finally {
    Pop-Location
}

# --- Configuracion de la base ------------------------------------------------
Write-Host "  [5/7] Configuracion de la base de datos..."
if (Test-Path (Join-Path $Destino "servidor\.env")) {
    Write-Host "        Ya hay una configuracion cargada."
    Write-Host "        Para cambiarla: CONFIGURAR.bat en la carpeta instalada."
} else {
    Write-Host "        Se abre la ventana para cargar los datos de conexion."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Destino "herramientas\configurar.ps1")
}

# --- Servicio de Windows ------------------------------------------------------
# Mejor esfuerzo: servicio-instalar.ps1 chequea por su cuenta si esta consola
# es de administrador. Si no lo es, lo dice el solo y no instala nada; este
# script sigue igual, el visor queda usable con el acceso directo (modo
# manual) y se puede instalar el servicio mas tarde con INSTALAR.bat.
Write-Host "  [6/7] Instalando el visor como servicio de Windows..."
# Se acota ErrorActionPreference solo para esta llamada: invocar un .exe
# (aca, un powershell.exe anidado) bajo "Stop" corta el script entero si ese
# proceso llega a escribir algo en su salida de error, aunque no sea una
# falla real. Ya paso con nssm.exe (ver servicio-instalar.ps1) y es la misma
# trampa.
$prefAnterior = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Destino "herramientas\servicio-instalar.ps1")
$servicioOk = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $prefAnterior
if (-not $servicioOk) {
    Write-Host ""
    Write-Host "        No quedo instalado como servicio (el motivo figura arriba;"
    Write-Host "        el mas comun es que esta consola no sea de administrador)."
    Write-Host "        El visor se puede usar igual con el acceso directo."
    Write-Host "        Para instalarlo despues: INSTALAR.bat en"
    Write-Host "        $Destino, con click derecho -> Ejecutar como administrador."
    Write-Host ""
}

# --- Acceso directo ----------------------------------------------------------
Write-Host "  [7/7] Acceso directo en el escritorio..."
try {
    $enlace = Join-Path ([Environment]::GetFolderPath('Desktop')) "Visor Catastral.lnk"
    $shell  = New-Object -ComObject WScript.Shell
    $acceso = $shell.CreateShortcut($enlace)
    $acceso.TargetPath       = Join-Path $Destino "INICIAR.bat"
    $acceso.WorkingDirectory = $Destino
    $acceso.Description      = "Visor Catastral - Villa de Merlo"
    $acceso.Save()
    Write-Host "        Creado: 'Visor Catastral'"
} catch {
    Write-Host "        No se pudo crear: $($_.Exception.Message)"
}

# --- Copias viejas -----------------------------------------------------------
# El motivo por el que existe este script: avisar de lo que quedo dando vueltas.
Write-Host ""
Write-Host "  Buscando otras copias del programa..."
$otras = @()
foreach ($lugar in @("C:\", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Documents")) {
    if (-not (Test-Path $lugar)) { continue }
    Get-ChildItem -Path $lugar -Filter "INICIAR.bat" -Recurse -Depth 4 -EA SilentlyContinue |
        ForEach-Object {
            $d = $_.DirectoryName
            if ($d -ne $Destino) { $otras += $d }
        }
}
$otras = $otras | Sort-Object -Unique

$version = "desconocida"
$rutaVer = Join-Path $Destino "VERSION.txt"
if (Test-Path $rutaVer) { $version = (Get-Content $rutaVer -Raw).Trim() }

Write-Host ""
Write-Host "  ============================================================"
Write-Host "   INSTALADO - version $version"
Write-Host "  ============================================================"
Write-Host ""
Write-Host "   Carpeta: $Destino"
if ($servicioOk) {
    Write-Host "   El visor arranca solo con la computadora, en:"
    Write-Host "   http://localhost:8002"
} else {
    Write-Host "   Para usar el visor: el acceso directo del escritorio"
    Write-Host "   (http://localhost:8002, mientras esa ventana este abierta)."
}
Write-Host ""

if ($otras.Count -gt 0) {
    Write-Host "   Hay $($otras.Count) instalacion(es) mas en esta computadora:"
    Write-Host ""
    foreach ($o in $otras) { Write-Host "     $o" }
    Write-Host ""
    Write-Host "   Conviene borrarlas una vez confirmado que esta instalacion"
    Write-Host "   anda bien: el visor usa siempre el puerto fijo 8002, asi que si"
    Write-Host "   alguna vez se abre una de esas por error, compite por ese puerto"
    Write-Host "   con esta."
    if ($servicioOk) {
        Write-Host ""
        Write-Host "   El servicio de Windows ya quedo apuntando a $Destino. Las"
        Write-Host "   otras carpetas no le hacen nada al servicio con solo existir,"
        Write-Host "   pero mejor ordenarlas para no confundirse."
    }
}
Write-Host ""
Write-Host "  ============================================================"
Write-Host ""
