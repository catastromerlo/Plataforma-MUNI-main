# =============================================================================
#  VISOR CATASTRAL - VILLA DE MERLO
#  Encontrar las copias del programa que hay en esta computadora
# -----------------------------------------------------------------------------
#  POR QUE EXISTE
#    Cada vez que se baja el ZIP y se descomprime queda una carpeta nueva. Con
#    el tiempo se juntan varias, todas con el mismo aspecto, y es facil
#    actualizar una y seguir ejecutando otra. El sintoma es desconcertante: se
#    actualiza, se instala, y "sigue todo igual", porque efectivamente sigue
#    corriendo la copia vieja.
#
#    Este script las busca todas y dice cual conviene conservar y cuales se
#    pueden borrar.
#
#  NO BORRA NADA. Solo informa: borrar carpetas es decision de quien las mira.
# =============================================================================

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "  ============================================================"
Write-Host "   COPIAS DEL VISOR EN ESTA COMPUTADORA"
Write-Host "  ============================================================"
Write-Host ""
Write-Host "  Buscando... (puede tardar un minuto)"
Write-Host ""

# Se busca INICIAR.bat, que solo existe en una instalacion del visor.
$lugares = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads",
             "$env:USERPROFILE\Documents", "$env:USERPROFILE\OneDrive", "C:\")
$encontradas = @()

foreach ($lugar in $lugares) {
    if (-not (Test-Path $lugar)) { continue }
    Get-ChildItem -Path $lugar -Filter "INICIAR.bat" -Recurse -Depth 4 -EA SilentlyContinue |
        ForEach-Object { $encontradas += $_.DirectoryName }
}

# Tambien las carpetas tipicas que deja descomprimir el ZIP
foreach ($lugar in $lugares) {
    if (-not (Test-Path $lugar)) { continue }
    Get-ChildItem -Path $lugar -Directory -Recurse -Depth 3 -EA SilentlyContinue |
        Where-Object { $_.Name -match "Plataforma-MUNI|VisorCatastral|VISUALIZADOR" } |
        ForEach-Object { if (Test-Path (Join-Path $_.FullName "INICIAR.bat")) { $encontradas += $_.FullName } }
}

$encontradas = $encontradas | Sort-Object -Unique

if ($encontradas.Count -eq 0) {
    Write-Host "  No se encontro ninguna instalacion."
    Write-Host ""
    exit 0
}

# --- Desde que carpeta corre el Servicio de Windows --------------------------
# Si el visor esta instalado como servicio, NSSM guarda en el registro la ruta
# de servidor\ desde la que arranca. La copia del programa es la carpeta de
# arriba. Se necesita saberlo porque borrar esa carpeta deja al servicio sin
# poder arrancar.
$rutaServicio = $null
$claveServicio = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\VisorCatastralMerlo\Parameters" -EA SilentlyContinue
if ($claveServicio -and $claveServicio.AppDirectory) {
    $rutaServicio = Split-Path -Parent ($claveServicio.AppDirectory.TrimEnd('\'))
}

# --- Datos de cada copia -----------------------------------------------------
$copias = @()
foreach ($ruta in $encontradas) {
    $version = "sin version"
    $rutaVer = Join-Path $ruta "VERSION.txt"
    if (Test-Path $rutaVer) { $version = (Get-Content $rutaVer -Raw).Trim() }

    $tieneEnv    = Test-Path (Join-Path $ruta "servidor\.env")
    $tieneModulos = Test-Path (Join-Path $ruta "servidor\node_modules")
    $datos = (Get-ChildItem (Join-Path $ruta "web\datos") -Filter *.json -EA SilentlyContinue).Count
    if ($datos -eq 0) { $datos = (Get-ChildItem (Join-Path $ruta "VISUALIZADOR\datos") -Filter *.json -EA SilentlyContinue).Count }

    # Una copia sirve si tiene la configuracion, los componentes y los datos
    $puntaje = 0
    if ($tieneEnv)     { $puntaje += 4 }
    if ($tieneModulos) { $puntaje += 2 }
    if ($datos -gt 0)  { $puntaje += 2 }
    if ($version -ne "sin version") { $puntaje += 3 }

    $copias += [PSCustomObject]@{
        Ruta      = $ruta
        Version   = $version
        Env       = $tieneEnv
        Modulos   = $tieneModulos
        Datos     = $datos
        Fecha     = (Get-Item (Join-Path $ruta "INICIAR.bat")).LastWriteTime
        Puntaje   = $puntaje
        UsaServicio = [bool]($rutaServicio -and ($ruta -eq $rutaServicio))
    }
}

$copias = $copias | Sort-Object -Property @{Expression="Puntaje";Descending=$true}, @{Expression="Version";Descending=$true}

Write-Host "  Se encontraron $($copias.Count) copia(s):"
Write-Host ""

$n = 0
foreach ($c in $copias) {
    $n++
    if ($c.UsaServicio) {
        $etiqueta = if ($n -eq 1) { "  >>> RECOMENDADA <<<   (la usa el Servicio de Windows)" } else { "      NO BORRAR: la usa el Servicio de Windows" }
    } else {
        $etiqueta = if ($n -eq 1) { "  >>> RECOMENDADA <<<" } else { "      se puede borrar" }
    }
    Write-Host "  [$n] $etiqueta"
    Write-Host "      Carpeta : $($c.Ruta)"
    Write-Host "      Version : $($c.Version)"
    Write-Host "      Config. : $(if ($c.Env) { 'si (datos de la base cargados)' } else { 'NO' })"
    Write-Host "      Compon. : $(if ($c.Modulos) { 'si' } else { 'NO' })"
    Write-Host "      Mapas   : $(if ($c.Datos -gt 0) { "$($c.Datos) archivos" } else { 'NO' })"
    Write-Host ""
}

$mejor = $copias[0]

Write-Host "  ============================================================"
Write-Host "   QUE HACER"
Write-Host "  ============================================================"
Write-Host ""

if ($copias.Count -eq 1) {
    Write-Host "   Hay una sola instalacion. No hay nada que ordenar."
} else {
    Write-Host "   1. CONSERVAR esta:"
    Write-Host "      $($mejor.Ruta)"
    Write-Host ""
    Write-Host "   2. Actualizarla: abrir esa carpeta y ejecutar ACTUALIZAR.bat"
    Write-Host ""
    Write-Host "   3. Las demas:"
    foreach ($c in $copias[1..($copias.Count-1)]) {
        $aviso = if ($c.UsaServicio) { "   <-- LA USA EL SERVICIO, no borrar" } elseif ($c.Env) { "   <-- tiene configuracion propia" } else { "" }
        Write-Host "      $($c.Ruta)$aviso"
    }
    Write-Host ""
    Write-Host "   ANTES DE BORRAR cualquier copia, confirmar que no sea la que usa el"
    Write-Host "   Servicio de Windows (si esta instalado): el servicio queda apuntando a"
    Write-Host "   una carpeta concreta y, si se la borra, el visor deja de arrancar solo."
    if ($rutaServicio) {
        Write-Host ""
        Write-Host "   Este servicio corre desde: $rutaServicio"
        if ($rutaServicio -ne $mejor.Ruta) {
            Write-Host "   No coincide con la recomendada. Si se prefiere conservar la recomendada,"
            Write-Host "   correr INSTALAR.bat (como administrador) desde ESA carpeta antes de"
            Write-Host "   borrar la otra: reconfigura el servicio para que apunte a ella."
        }
    }
}

Write-Host ""
Write-Host "   4. Para no tener que buscar la carpeta cada vez, crear un acceso"
Write-Host "      directo en el escritorio (se ofrece abajo)."
Write-Host ""
Write-Host "  ============================================================"
Write-Host ""

# --- Acceso directo ----------------------------------------------------------
$respuesta = Read-Host "  Crear un acceso directo en el escritorio a la copia recomendada? (S/N)"
if ($respuesta -match '^[SsYy]') {
    try {
        $destino = Join-Path $mejor.Ruta "INICIAR.bat"
        $enlace  = Join-Path ([Environment]::GetFolderPath('Desktop')) "Visor Catastral.lnk"
        $shell = New-Object -ComObject WScript.Shell
        $acceso = $shell.CreateShortcut($enlace)
        $acceso.TargetPath = $destino
        $acceso.WorkingDirectory = $mejor.Ruta
        $acceso.Description = "Visor Catastral - Villa de Merlo"
        $acceso.Save()
        Write-Host ""
        Write-Host "  Acceso directo creado en el escritorio: 'Visor Catastral'"
        Write-Host "  Apunta a: $($mejor.Ruta)"
        Write-Host ""
        Write-Host "  Usar SIEMPRE ese acceso, asi no hay forma de abrir una copia vieja."
    } catch {
        Write-Host ""
        Write-Host "  No se pudo crear el acceso directo: $($_.Exception.Message)"
    }
}

Write-Host ""
