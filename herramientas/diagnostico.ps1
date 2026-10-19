# =============================================================================
#  VISOR CATASTRAL - VILLA DE MERLO
#  Informe de diagnostico
# -----------------------------------------------------------------------------
#  Genera un informe con el estado real de ESTA instalacion: que version tiene,
#  desde que carpeta se ejecuta, que contienen los archivos, si el visor esta
#  corriendo (como Servicio de Windows o abierto a mano) y si los servidores
#  de mapas responden desde esta red.
#
#  Sirve para dejar de adivinar. Cuando algo "sigue sin andar" despues de
#  actualizar, las causas posibles son varias -carpeta equivocada, archivos a
#  medio reemplazar, un bloqueo de red- y desde afuera no hay forma de saber
#  cual es. Este informe lo dice.
#
#  El resultado se guarda en un archivo de texto y se abre solo.
# =============================================================================

$carpeta = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$raiz    = Split-Path -Parent $carpeta
$salida  = Join-Path $raiz "INFORME-DIAGNOSTICO.txt"
$lineas  = @()

function Agregar($texto) { $script:lineas += $texto }

# El informe se arma completo en memoria y recien se muestra al final. Sin
# estos avisos, la ventana queda negra y en blanco todo el tiempo que tarda
# (revisar el disco y probar los servidores de mapas puede llevar uno o dos
# minutos), y no hay forma de saber si esta trabajando o si se colgo.
function Avance($texto) { Write-Host "  $texto" }
Write-Host ""
Avance "Generando el informe. Puede tardar uno o dos minutos: se revisa el"
Avance "disco en busca de copias del programa y se prueban los mapas."
Write-Host ""

Agregar "============================================================"
Agregar " INFORME DE DIAGNOSTICO - VISOR CATASTRAL"
Agregar " Generado el $(Get-Date -Format 'dd/MM/yyyy HH:mm')"
Agregar "============================================================"
Agregar ""

# --- 1. Que instalacion es esta ----------------------------------------------
Avance "[1/5] Identificando esta instalacion..."
Agregar "1. ESTA INSTALACION"
Agregar "   Carpeta: $raiz"

$rutaVersion = Join-Path $raiz "VERSION.txt"
$version = if (Test-Path $rutaVersion) { (Get-Content $rutaVersion -Raw).Trim() } else { "NO EXISTE el archivo VERSION.txt" }
Agregar "   Version: $version"
Agregar ""

# --- 2. Contenido real de los archivos ---------------------------------------
# No alcanza con mirar la version: si alguien reemplazo unos archivos y otros
# no, la version puede ser nueva y el codigo viejo. Se revisa el contenido.
Avance "[2/5] Revisando el contenido de los archivos..."
Agregar "2. QUE CONTIENEN LOS ARCHIVOS"

function Revisar($ruta, $marca, $descripcion) {
    $completa = Join-Path $raiz $ruta
    if (-not (Test-Path $completa)) {
        Agregar "   [FALTA]   $ruta"
        return
    }
    $texto = Get-Content $completa -Raw -EA SilentlyContinue
    $fecha = (Get-Item $completa).LastWriteTime.ToString('dd/MM/yyyy HH:mm')
    $tiene = $texto -match [regex]::Escape($marca)
    $estado = if ($tiene) { "SI " } else { "NO " }
    Agregar "   $estado  $descripcion   ($ruta, $fecha)"
}

Revisar "web\js\app.js"      "basemaps.cartocdn"      "mapa de calles nuevo (CARTO)"
Revisar "web\js\app.js"      "PROPORCION_MARCO_MAPA"  "plancheta nueva"
Revisar "web\js\app.js"      "tabla-titulares"        "plancheta con varios titulares"
Revisar "web\index.html"     "__VERSION__"            "version visible en el visor"
Revisar "servidor\server.js" "index: false"           "version automatica de archivos"
Revisar "servidor\server.js" "strict-origin"          "politica de referencia"
Agregar ""

# --- 3. Hay mas de una instalacion? ------------------------------------------
# La causa mas comun de "actualice y sigue igual" es que se actualizo una
# carpeta y se ejecuta otra.
Avance "[3/5] Buscando otras copias del programa en el disco (puede tardar)..."
Agregar "3. OTRAS COPIAS DEL PROGRAMA EN ESTA COMPUTADORA"
$encontradas = @()
foreach ($base in @("C:\", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Documents")) {
    if (-not (Test-Path $base)) { continue }
    try {
        Get-ChildItem -Path $base -Filter "INICIAR.bat" -Recurse -Depth 3 -EA SilentlyContinue |
            ForEach-Object { $encontradas += $_.DirectoryName }
    } catch { }
}
$encontradas = $encontradas | Sort-Object -Unique
if ($encontradas.Count -le 1) {
    Agregar "   Solo esta instalacion. Bien."
} else {
    Agregar "   ATENCION: hay $($encontradas.Count) copias del programa."
    Agregar "   Si se actualiza una y se ejecuta otra, los cambios no aparecen."
    foreach ($e in $encontradas) {
        $v = Join-Path $e "VERSION.txt"
        $ver = if (Test-Path $v) { (Get-Content $v -Raw).Trim() } else { "sin version" }
        $marca = if ($e -eq $raiz) { "  <-- ESTA" } else { "" }
        Agregar "     [$ver]  $e$marca"
    }
}
Agregar ""

# --- 4. El servidor esta corriendo? ------------------------------------------
# El visor usa siempre el puerto 8002, tanto si corre como Servicio de Windows
# (lo normal, lo deja instalado INSTALAR.bat) como si alguien lo abrio a mano
# con INICIAR.bat. Por eso se miran dos cosas por separado: el servicio, y si
# el puerto responde. La combinacion de las dos dice que esta pasando.
Avance "[4/5] Revisando el servidor..."
Agregar "4. SERVIDOR"
$puerto = 8002
$nombreServicio = "VisorCatastralMerlo"

$servicio = Get-Service -Name $nombreServicio -ErrorAction SilentlyContinue
$estado   = if ($servicio) { [string]$servicio.Status } else { "" }
if ($servicio) {
    Agregar "   Servicio de Windows: instalado, estado $estado"
} else {
    Agregar "   Servicio de Windows: NO instalado en esta computadora"
}

$responde = $false
try {
    $r = Invoke-WebRequest -Uri "http://localhost:$puerto/health" -UseBasicParsing -TimeoutSec 3
    $responde = $true
    Agregar "   Puerto ${puerto}: responde en http://localhost:$puerto"
    Agregar "   $($r.Content)"
} catch {
    Agregar "   Puerto ${puerto}: no responde"
}

Agregar ""
if ($servicio -and $estado -eq "Running" -and $responde) {
    Agregar "   Diagnostico: todo en orden. El visor corre como servicio y responde."
} elseif ($servicio -and $estado -eq "Running") {
    Agregar "   Diagnostico: el servicio figura en marcha pero el puerto $puerto no"
    Agregar "   responde. Puede estar arrancando todavia (esperar un minuto y repetir"
    Agregar "   el diagnostico) o haberse trabado: ver el final de servicio-error.log"
    Agregar "   mas abajo."
} elseif ($servicio -and $responde) {
    Agregar "   Diagnostico: el visor responde, pero NO por el servicio (que esta"
    Agregar "   $estado): alguien lo abrio a mano con INICIAR.bat. Funciona mientras esa"
    Agregar "   ventana negra siga abierta. Para dejarlo fijo: cerrar esa ventana e"
    Agregar "   iniciar el servicio (services.msc, o net start $nombreServicio como"
    Agregar "   administrador)."
} elseif ($servicio) {
    Agregar "   Diagnostico: el servicio esta $estado y nada responde en el puerto $puerto."
    Agregar "   Para levantarlo: services.msc -> Visor Catastral - Villa de Merlo ->"
    Agregar "   Iniciar, o desde una consola como administrador:"
    Agregar "       net start $nombreServicio"
    Agregar "   Mientras tanto se puede usar INICIAR.bat (modo manual)."
} elseif ($responde) {
    Agregar "   Diagnostico: el visor responde, abierto a mano con INICIAR.bat (sin"
    Agregar "   servicio). Funciona mientras esa ventana negra siga abierta. Para que"
    Agregar "   arranque solo con la computadora: INSTALAR.bat como administrador."
} else {
    Agregar "   Diagnostico: el visor no esta corriendo en este momento."
    Agregar "   Abrir INICIAR.bat, o correr INSTALAR.bat como administrador para dejarlo"
    Agregar "   instalado como servicio (arranca solo con la computadora)."
}

# Si el servicio existe pero el puerto no responde, el motivo casi siempre esta
# en el final del registro de errores del servicio.
if ($servicio -and -not $responde) {
    $logError = Join-Path $raiz "servidor\logs\servicio-error.log"
    if (Test-Path $logError) {
        Agregar ""
        Agregar "   Ultimas lineas de servidor\logs\servicio-error.log:"
        Get-Content $logError -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object { Agregar "     $_" }
    }
}
Agregar ""

# --- 5. Los servidores de mapas responden desde esta red? --------------------
# Un firewall municipal puede dejar pasar unos dominios y bloquear otros.
Avance "[5/5] Probando los servidores de mapas (tarda si la red los bloquea)..."
Agregar "5. SERVIDORES DE MAPAS (desde esta red)"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Las teselas de prueba caen sobre Villa de Merlo. Ninguno de estos servicios
# pide clave ni cuenta: si alguno FALLA, es que esta red no lo deja salir.
$mapas = [ordered]@{
    "Esri (calles, el que usa primero)"  = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/13/4872/2616"
    "CARTO (calles, primer respaldo)"    = "https://a.basemaps.cartocdn.com/rastertiles/voyager/13/2616/4872.png"
    "OpenStreetMap (ultimo respaldo)"    = "https://a.tile.openstreetmap.org/13/2616/4872.png"
    "Esri (topografia)"                  = "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/13/4872/2616"
    "Google (satelital)"                 = "https://mt1.google.com/vt/lyrs=s&x=2616&y=4872&z=13"
}
$callesOk = $false
foreach ($m in $mapas.GetEnumerator()) {
    try {
        $res = Invoke-WebRequest -Uri $m.Value -UseBasicParsing -TimeoutSec 10
        Agregar "   OK ($($res.StatusCode))   $($m.Key)"
        if ($m.Key -like "*calles*") { $callesOk = $true }
    } catch {
        $codigo = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { "sin respuesta" }
        Agregar "   FALLA ($codigo)   $($m.Key)"
    }
}
if (-not $callesOk) {
    Agregar ""
    Agregar "   >>> Ningun mapa de calles responde desde esta red."
    Agregar "       Por eso el mapa se ve gris. NO falta ninguna clave ni licencia:"
    Agregar "       hay que pedirle a sistemas que permita el acceso a"
    Agregar "       server.arcgisonline.com"
    Agregar "       Las parcelas, los filtros y las planchetas funcionan igual:"
    Agregar "       salen de archivos de esta misma computadora."
}
Agregar ""

Agregar "============================================================"
Agregar " Pasar este archivo completo para poder ver que esta pasando."
Agregar "============================================================"

$lineas | Set-Content -Path $salida -Encoding UTF8
$lineas | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "  Informe guardado en:"
Write-Host "  $salida"
Write-Host ""

Start-Process notepad $salida
