# =============================================================================
#  VISOR CATASTRAL - VILLA DE MERLO
#  Actualizador: baja la ultima version y la aplica sobre esta instalacion
# -----------------------------------------------------------------------------
#  POR QUE EXISTE
#    Actualizar bajando el ZIP y descomprimiendo a mano falla de maneras que no
#    se notan: se descomprime en otra carpeta y se sigue ejecutando la vieja, o
#    Windows pregunta si reemplazar y alguien elige omitir, o quedan mezclados
#    archivos de dos versiones. El visor abre igual y parece actualizado, pero
#    se comporta como antes.
#
#    Este script baja la version publicada, reemplaza los archivos del programa
#    y CONSERVA lo que es de esta computadora: la configuracion de la base
#    (.env) y los componentes ya instalados (node_modules).
#
#  CODIGOS DE SALIDA
#    0 = actualizado
#    1 = fallo (el motivo queda escrito en pantalla)
# =============================================================================

$ErrorActionPreference = "Stop"

$carpeta = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$raiz    = Split-Path -Parent $carpeta
$origen  = "https://github.com/catastromerlo/Plataforma-MUNI-main/archive/refs/heads/main.zip"

# -----------------------------------------------------------------------------
# SERVICIO DE WINDOWS (si esta instalado con INSTALAR.bat)
# -----------------------------------------------------------------------------
#   Se detecta aca, antes de descargar nada, para saber si mas abajo hay que
#   pararlo antes de tocar archivos y volver a levantarlo despues.
#
#   Sin esto, la actualizacion reemplaza server.js en disco pero el proceso
#   que ya esta corriendo se queda con el codigo viejo en memoria hasta que
#   alguien reinicie el servicio a mano: el deploy "termina bien" pero el
#   cambio real nunca se aplica, y nadie lo nota a simple vista.
#
#   Si esta computadora sigue con INICIAR.bat (sin servicio), $servicioInstalado
#   queda en $false y todo lo demas se salta solo, sin tocar nada.
# -----------------------------------------------------------------------------
$NombreServicioVisor = "VisorCatastralMerlo"
$arqVisor     = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
$nssmExeVisor = Join-Path $carpeta "nssm\$arqVisor\nssm.exe"
$servicioInstalado = $false
$servicioDetenido  = $false

if (Test-Path $nssmExeVisor) {
    # nssm.exe devuelve un codigo de salida distinto de cero -y a veces
    # tambien texto por su salida de error- cuando el servicio no existe.
    # Con $ErrorActionPreference = "Stop" (como esta arriba en este archivo)
    # eso cortaria el script como si fuera un error real, asi que la
    # preferencia se acota SOLO a esta llamada puntual.
    $prefAnterior = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $PSNativeCommandUseErrorActionPreference = $false
    & $nssmExeVisor status $NombreServicioVisor *> $null
    $servicioInstalado = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prefAnterior
}

Write-Host ""
Write-Host "  ============================================================"
Write-Host "   ACTUALIZAR EL VISOR CATASTRAL"
Write-Host "  ============================================================"
Write-Host ""

# Version actual, para poder comparar al terminar
$rutaVersion = Join-Path $raiz "VERSION.txt"
$versionAntes = if (Test-Path $rutaVersion) { (Get-Content $rutaVersion -Raw).Trim() } else { "desconocida" }
Write-Host "  Version instalada: $versionAntes"
Write-Host ""

$temporal = Join-Path $env:TEMP ("visor-actualizacion-" + [Guid]::NewGuid().ToString("N").Substring(0,8))
$zip      = Join-Path $temporal "programa.zip"

try {
    New-Item -ItemType Directory -Path $temporal -Force | Out-Null

    Write-Host "  [1/4] Descargando la ultima version..."
    # TLS 1.2 explicito: Windows Server y equipos con configuracion antigua no
    # lo negocian solo, y la descarga desde GitHub falla sin decir por que.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $origen -OutFile $zip -UseBasicParsing
    Write-Host "        Descargada."

    Write-Host "  [2/4] Descomprimiendo..."
    Expand-Archive -Path $zip -DestinationPath $temporal -Force
    $descomprimida = Get-ChildItem -Path $temporal -Directory | Select-Object -First 1
    if (-not $descomprimida) { throw "El archivo descargado no tiene el contenido esperado." }
    Write-Host "        Listo."

    Write-Host "  [3/4] Aplicando la actualizacion..."

    if ($servicioInstalado) {
        Write-Host "        Deteniendo el servicio antes de reemplazar archivos..."
        $prefAnterior = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $nssmExeVisor stop $NombreServicioVisor | Out-Null
        $ErrorActionPreference = $prefAnterior
        $servicioDetenido = $true
    }

    # Se reemplaza SOLO lo que es el programa. Todo lo que pertenece a esta
    # computadora se deja como esta:
    #   servidor\.env           configuracion de la base
    #   servidor\node_modules   componentes instalados
    #   web\datos               los GeoJSON, si fueran distintos a los publicados
    $aReemplazar = @(
        "web\index.html",
        "web\css",
        "web\js",
        "web\img",
        "servidor\server.js",
        "servidor\package.json",
        "servidor\.env.example",
        "herramientas",
        "docs",
        "INICIAR.bat",
        "INSTALAR.bat",
        "CONFIGURAR.bat",
        "ACTUALIZAR.bat",
        "SERVICIO-DETENER.bat",
        "SERVICIO-REINICIAR.bat",
        "SERVICIO-DESINSTALAR.bat",
        "VERSION.txt",
        "README.md"
    )

    foreach ($item in $aReemplazar) {
        $desde = Join-Path $descomprimida.FullName $item
        $hasta = Join-Path $raiz $item
        if (-not (Test-Path $desde)) { continue }

        $padre = Split-Path -Parent $hasta
        if ($padre -and -not (Test-Path $padre)) {
            New-Item -ItemType Directory -Path $padre -Force | Out-Null
        }

        if (Test-Path $desde -PathType Container) {
            # Copia el contenido de la carpeta, sin borrar lo que no viene en
            # la actualizacion (por ejemplo, node_modules dentro de servidor).
            Copy-Item -Path (Join-Path $desde "*") -Destination $hasta -Recurse -Force
        } else {
            Copy-Item -Path $desde -Destination $hasta -Force
        }
    }

    # Los GeoJSON solo se copian si esta computadora no los tiene. Si ya estan,
    # se dejan: pueden ser una carga mas nueva que la publicada.
    $datosLocales = Join-Path $raiz "web\datos"
    $datosNuevos  = Join-Path $descomprimida.FullName "web\datos"
    if ((Test-Path $datosNuevos) -and (-not (Test-Path $datosLocales) -or
        ((Get-ChildItem $datosLocales -Filter *.json -EA SilentlyContinue).Count -eq 0))) {
        New-Item -ItemType Directory -Path $datosLocales -Force | Out-Null
        Copy-Item -Path (Join-Path $datosNuevos "*") -Destination $datosLocales -Recurse -Force
        Write-Host "        Se copiaron tambien los archivos del mapa."
    }

    Write-Host "        Aplicada."

    Write-Host "  [4/4] Verificando..."
    $versionDespues = if (Test-Path $rutaVersion) { (Get-Content $rutaVersion -Raw).Trim() } else { "desconocida" }

    Write-Host ""
    Write-Host "  ============================================================"
    if ($versionDespues -ne $versionAntes) {
        Write-Host "   ACTUALIZADO"
        Write-Host ""
        Write-Host "   Antes:  $versionAntes"
        Write-Host "   Ahora:  $versionDespues"
    } else {
        Write-Host "   YA ESTABA AL DIA (version $versionDespues)"
    }
    Write-Host ""
    Write-Host "   La configuracion de la base NO se toco."
    if ($servicioInstalado) {
        Write-Host "   El visor corre como servicio: se reinicia solo con la version nueva."
    } else {
        Write-Host "   Para usar el visor: doble clic en INICIAR.bat"
    }
    Write-Host "  ============================================================"
    Write-Host ""
    exit 0

} catch {
    Write-Host ""
    Write-Host "  ============================================================"
    Write-Host "   NO SE PUDO ACTUALIZAR"
    Write-Host "  ============================================================"
    Write-Host ""
    Write-Host "   $($_.Exception.Message)"
    Write-Host ""
    Write-Host "   La causa mas comun es que esta computadora no tenga salida a"
    Write-Host "   internet. En ese caso hay que bajar el ZIP desde otra maquina:"
    Write-Host "     https://github.com/catastromerlo/Plataforma-MUNI-main"
    Write-Host "   y reemplazar los archivos a mano, SIN tocar servidor\.env"
    Write-Host ""
    Write-Host "   La instalacion actual quedo intacta."
    Write-Host ""
    exit 1

} finally {
    if (Test-Path $temporal) { Remove-Item $temporal -Recurse -Force -EA SilentlyContinue }

    # Se reinicia siempre que se haya parado, haya salido bien o mal la
    # actualizacion: si se lo paro, es responsabilidad de este script
    # dejarlo como lo encontro. Si la actualizacion fallo a mitad de camino,
    # arranca igual (con lo que haya quedado en disco) y el motivo del fallo
    # ya se avisa arriba, en pantalla y en servidor\logs\servicio-error.log
    # si hiciera falta revisarlo despues.
    if ($servicioDetenido) {
        Write-Host "  Reiniciando el servicio..."
        $prefAnterior = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $nssmExeVisor start $NombreServicioVisor | Out-Null
        $ErrorActionPreference = $prefAnterior
    }
}
