<#
============================================================================
 VISOR CATASTRAL - VILLA DE MERLO
 Quita el servicio de Windows instalado con servicio-instalar.ps1.

 Despues de esto, el visor vuelve a necesitar INICIAR.bat para abrirse (el
 servicio deja de existir, pero los archivos del programa no se tocan).

 Requiere permisos de administrador.
============================================================================
#>

param(
    [string]$NombreServicio = "VisorCatastralMerlo"
)

# Ver el comentario equivalente en servicio-instalar.ps1: con
# ErrorActionPreference = "Stop", cualquier texto que nssm.exe escriba en su
# salida de error corta el script, aunque sea un resultado normal (por
# ejemplo, "el servicio no existe" cuando ya se desinstalo antes).
$ErrorActionPreference = "Continue"
$PSNativeCommandUseErrorActionPreference = $false

$dirNssm = Join-Path $PSScriptRoot "nssm"
$arq     = if ([Environment]::Is64BitOperatingSystem) { "win64" } else { "win32" }
$nssmExe = Join-Path $dirNssm "$arq\nssm.exe"

$esAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host ""
    Write-Host "ERROR: este paso necesita permisos de administrador." -ForegroundColor Red
    Write-Host "Click derecho sobre SERVICIO-DESINSTALAR.bat -> Ejecutar como administrador."
    Write-Host ""
    exit 1
}

if (-not (Test-Path $nssmExe)) {
    Write-Host ""
    Write-Host "No se encuentra NSSM en esta carpeta." -ForegroundColor Yellow
    Write-Host "Si el servicio '$NombreServicio' existe igual, sacarlo a mano desde services.msc"
    Write-Host "(boton derecho sobre el servicio -> Detener, y despues desde una consola:"
    Write-Host "  sc.exe delete $NombreServicio )"
    Write-Host ""
    exit 1
}

& $nssmExe status $NombreServicio *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "El servicio '$NombreServicio' no esta instalado. No hay nada que hacer."
    Write-Host ""
    exit 0
}

& $nssmExe stop $NombreServicio   | Out-Null
& $nssmExe remove $NombreServicio confirm | Out-Null

Write-Host ""
Write-Host "Listo. El servicio se quito de esta computadora." -ForegroundColor Green
Write-Host "El visor vuelve a necesitar INICIAR.bat (doble clic) para abrirse."
Write-Host ""
