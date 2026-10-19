<#
============================================================================
 VISOR CATASTRAL - VILLA DE MERLO
 Detiene el servicio de Windows SIN desinstalarlo (a diferencia de
 servicio-desinstalar.ps1). Util para editar archivos del programa a mano,
 o antes de mover la carpeta a otra ubicacion.

 El visor deja de responder en su puerto mientras el servicio este
 detenido. Para volver a levantarlo: services.msc (boton derecho
 sobre el servicio -> Iniciar) o, como administrador, net start VisorCatastralMerlo

 Si lo que se quiere es MOVER LA CARPETA a otro lugar: no alcanza con
 pararlo y volver a arrancarlo desde aca. Despues de moverla, hay que
 volver a correr INSTALAR.bat (como administrador) desde la ubicacion nueva:
 como ya detecta que el servicio existe, lo reconfigura con la ruta correcta.

 Requiere permisos de administrador.
============================================================================
#>

param(
    [string]$NombreServicio = "VisorCatastralMerlo"
)

# No se usa $ErrorActionPreference = "Stop": nssm.exe puede escribir texto en
# su salida de error (por ejemplo, si el servicio ya estuviera detenido), y
# con "Stop" eso cortaria el script como si fuera una falla real.
$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false

$dirNssm = Join-Path $PSScriptRoot "nssm"
$arq     = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
$nssmExe = Join-Path $dirNssm "$arq\nssm.exe"

if (-not (Test-Path $nssmExe)) {
    Write-Host ""
    Write-Host "No se encuentra NSSM en esta carpeta." -ForegroundColor Yellow
    Write-Host "Si el servicio esta instalado, se puede parar igual desde"
    Write-Host "services.msc (boton derecho sobre el servicio -> Detener)."
    Write-Host ""
    exit 1
}

& $nssmExe status $NombreServicio *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "El servicio '$NombreServicio' no esta instalado. No hay nada que parar."
    Write-Host ""
    exit 0
}

& $nssmExe stop $NombreServicio | Out-Null
Start-Sleep -Seconds 1
$estado = & $nssmExe status $NombreServicio

Write-Host ""
if ($estado -match "SERVICE_STOPPED") {
    Write-Host "Listo. El servicio esta detenido." -ForegroundColor Green
    Write-Host "El visor no responde en su puerto mientras este parado."
    Write-Host "Para volver a levantarlo: services.msc, o como administrador:"
    Write-Host "  net start VisorCatastralMerlo"
} else {
    Write-Host "El servicio quedo en estado: $estado" -ForegroundColor Yellow
}
Write-Host ""
