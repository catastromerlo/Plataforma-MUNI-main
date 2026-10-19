@echo off
REM ============================================================================
REM  VISOR CATASTRAL - VILLA DE MERLO
REM  Quita el servicio de Windows instalado con INSTALAR.bat.
REM
REM  No borra el programa: solo hace que deje de arrancar solo con la
REM  computadora. Despues de esto, para usar el visor hace falta volver a
REM  INICIAR.bat.
REM
REM  Requiere permisos de administrador: click derecho sobre este archivo ->
REM  "Ejecutar como administrador".
REM ============================================================================

title Quitar el servicio del Visor Catastral - Villa de Merlo
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
    echo.
    echo  ESTE PASO NECESITA PERMISOS DE ADMINISTRADOR.
    echo.
    echo  Cerrar esta ventana y volver a hacer click derecho sobre
    echo  SERVICIO-DESINSTALAR.bat, eligiendo "Ejecutar como administrador".
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "herramientas\servicio-desinstalar.ps1"

echo.
pause
