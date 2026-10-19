@echo off
REM ============================================================================
REM  VISOR CATASTRAL - VILLA DE MERLO
REM  Detiene el servicio de Windows SIN desinstalarlo. Util para editar
REM  archivos del programa a mano, o antes de mover la carpeta.
REM
REM  El visor deja de responder en su puerto mientras este detenido.
REM  Para levantarlo de nuevo: services.msc (boton derecho sobre el servicio
REM  -> Iniciar), o como administrador: net start VisorCatastralMerlo
REM
REM  Requiere permisos de administrador: click derecho sobre este archivo ->
REM  "Ejecutar como administrador".
REM ============================================================================

title Detener el servicio del Visor Catastral - Villa de Merlo
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  ESTE PASO NECESITA PERMISOS DE ADMINISTRADOR.
    echo.
    echo  Cerrar esta ventana y volver a hacer click derecho sobre
    echo  SERVICIO-DETENER.bat, eligiendo "Ejecutar como administrador".
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "herramientas\servicio-detener.ps1"

echo.
pause
