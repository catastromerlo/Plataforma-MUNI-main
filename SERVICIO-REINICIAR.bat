@echo off
REM ============================================================================
REM  VISOR CATASTRAL - VILLA DE MERLO
REM  Reinicia el servicio de Windows sin cambiar su configuracion.
REM
REM  Requiere permisos de administrador: click derecho sobre este archivo ->
REM  "Ejecutar como administrador".
REM ============================================================================

title Reiniciar el servicio del Visor Catastral - Villa de Merlo
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  ESTE PASO NECESITA PERMISOS DE ADMINISTRADOR.
    echo.
    echo  Cerrar esta ventana y volver a hacer click derecho sobre
    echo  SERVICIO-REINICIAR.bat, eligiendo "Ejecutar como administrador".
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $servicio = Get-Service -Name 'VisorCatastralMerlo' -ErrorAction Stop; Restart-Service -Name $servicio.Name -ErrorAction Stop; (Get-Service -Name $servicio.Name).WaitForStatus('Running', [TimeSpan]::FromSeconds(30)); $respuesta = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8002/version' -TimeoutSec 20; if ($respuesta.StatusCode -ne 200) { throw 'El servicio inicio, pero el visor no respondio correctamente.' }; Write-Host ('Listo. Version en ejecucion: ' + $respuesta.Content.Trim()) -ForegroundColor Green; exit 0 } catch { Write-Host ('No se pudo reiniciar o verificar el visor: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
    echo.
    echo  No se pudo reiniciar el servicio.
    echo  Comprueba en services.msc que exista VisorCatastralMerlo.
    echo.
    pause
    exit /b 1
)

echo.
pause
