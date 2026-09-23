@echo off
REM ============================================================================
REM  VISOR CATASTRAL - VILLA DE MERLO
REM  Uso diario: doble clic aca y listo.
REM
REM  Si el visor esta instalado como Servicio de Windows (ver INSTALAR.bat),
REM  este archivo solo abre el navegador: el servidor ya esta corriendo en
REM  segundo plano, y esta ventana se puede cerrar enseguida.
REM
REM  Si NO esta instalado como servicio (o si estuviera instalado pero
REM  detenido), funciona como respaldo manual: deja el servidor corriendo en
REM  esta ventana y abre el visor en el navegador. Esa ventana negra tiene
REM  que quedar ABIERTA mientras se usa asi: si se cierra, el visor deja de
REM  funcionar.
REM
REM  Puerto fijo: 8002. Antes este archivo probaba varios puertos para no
REM  molestar a un visor catastral anterior que ya no esta en uso; sin ese
REM  visor, no hace falta.
REM ============================================================================

title Visor Catastral - Villa de Merlo
cd /d "%~dp0"
setlocal enabledelayedexpansion

set "PUERTO=8002"

echo.
echo  ============================================================
echo   VISOR CATASTRAL - VILLA DE MERLO
echo  ============================================================
echo.

REM --- Si esta instalado como Servicio de Windows, usar eso directamente -----
sc query "VisorCatastralMerlo" >nul 2>nul
if not errorlevel 1 (
    sc query "VisorCatastralMerlo" | findstr /i "RUNNING" >nul 2>nul
    if not errorlevel 1 (
        echo  El visor corre como servicio de Windows. Abriendo el navegador...
        echo.
        call :abrirNavegador
        echo  Listo. Esta ventana se puede cerrar: el servidor sigue corriendo solo.
        echo.
        timeout /t 5 /nobreak >nul
        exit /b 0
    ) else (
        echo  AVISO: el visor esta instalado como servicio pero no esta en marcha
        echo  ahora mismo. Se abre igual en modo manual por esta vez. Convendria
        echo  avisar a quien administra el sistema para que revise el servicio.
        echo.
    )
)

REM --- Modo manual: la ventana queda abierta mientras se usa el visor --------
color 0A

where node >nul 2>nul
if errorlevel 1 (
    echo  ERROR: Node.js no esta instalado.
    echo  Ejecutar primero INSTALAR.bat
    echo.
    pause
    exit /b 1
)

if not exist "servidor\node_modules" (
    echo  ERROR: faltan los componentes del sistema.
    echo  Ejecutar primero INSTALAR.bat
    echo.
    pause
    exit /b 1
)

if not exist "servidor\.env" (
    echo  ERROR: falta la configuracion de la base de datos.
    echo  Ejecutar primero INSTALAR.bat
    echo.
    pause
    exit /b 1
)

set "PORT=!PUERTO!"
echo  Iniciando el visor en el puerto !PUERTO!...
echo.

call :abrirNavegador 4

echo  ------------------------------------------------------------
echo   El visor se abre solo en el navegador.
echo   Si no se abre, entrar a:  http://localhost:!PUERTO!
echo.
echo   DEJAR ESTA VENTANA ABIERTA mientras se use el visor.
echo   Para cerrarlo: cerrar esta ventana.
echo  ------------------------------------------------------------
echo.

cd servidor
node server.js

REM  Si llega aca es porque el servidor se detuvo o fallo al arrancar.
echo.
echo  ============================================================
echo   El visor se detuvo.
echo.
echo   Si fue un error, el motivo figura arriba. Las causas mas
echo   comunes son que el puerto !PUERTO! ya este en uso (por
echo   ejemplo, si el servicio de Windows arranco mientras tanto)
echo   o que este visor ya este abierto en otra ventana.
echo  ============================================================
echo.
pause
exit /b 0

REM ============================================================================
REM  SUBRUTINA: buscar y abrir Chrome (o el navegador predeterminado)
REM ----------------------------------------------------------------------------
REM  Recibe un argumento opcional: cuantos segundos esperar antes de abrir.
REM  En el modo servicio no hace falta esperar (ya esta corriendo). En modo
REM  manual se le da tiempo al servidor para levantar antes de abrir.
REM ============================================================================
:abrirNavegador
set "ESPERA=%~1"
if not defined ESPERA set "ESPERA=0"

set "CHROME="
for %%r in (
    "%ProgramFiles%\Google\Chrome\Application\chrome.exe"
    "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
    "%LocalAppData%\Google\Chrome\Application\chrome.exe"
) do (
    if not defined CHROME if exist "%%~r" set "CHROME=%%~r"
)
if not defined CHROME (
    for /f "skip=2 tokens=2,*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" /ve 2^>nul') do (
        if not defined CHROME if exist "%%~b" set "CHROME=%%~b"
    )
)
if not defined CHROME (
    for /f "skip=2 tokens=2,*" %%a in ('reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe" /ve 2^>nul') do (
        if not defined CHROME if exist "%%~b" set "CHROME=%%~b"
    )
)

if defined CHROME (
    echo  Navegador: Google Chrome
) else (
    echo  Navegador: el predeterminado de Windows ^(no se encontro Chrome^)
)
echo.

if defined CHROME (
    start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds %ESPERA%; Start-Process '!CHROME!' 'http://localhost:!PUERTO!'"
) else (
    start "" /b cmd /c "%SystemRoot%\System32\timeout.exe /t %ESPERA% /nobreak >nul & start http://localhost:!PUERTO!"
)
exit /b 0
