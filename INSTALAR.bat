@echo off
REM ============================================================================
REM  VISOR CATASTRAL - VILLA DE MERLO
REM  Instalacion. Se corre UNA SOLA VEZ, la primera vez.
REM  Para el uso de todos los dias esta INICIAR.bat
REM ----------------------------------------------------------------------------
REM  Hace todo de punta a punta: Node.js, componentes, configuracion de la
REM  base, prueba de conexion, y deja el visor instalado como Servicio de
REM  Windows (arranca solo con la computadora, en el puerto fijo 8002).
REM
REM  Por eso necesita permisos de administrador desde el principio: click
REM  derecho sobre este archivo -> "Ejecutar como administrador".
REM ----------------------------------------------------------------------------
REM  Sin acentos a proposito: la consola de Windows los muestra mal segun la
REM  configuracion regional del equipo, y este archivo tiene que leerse bien en
REM  cualquier maquina de la Municipalidad.
REM ============================================================================

title Instalacion del Visor Catastral - Villa de Merlo
cd /d "%~dp0"
color 0F

echo.
echo  ============================================================
echo   VISOR CATASTRAL - VILLA DE MERLO
echo   Instalacion inicial
echo  ============================================================
echo.

REM --- Verificar permisos de administrador ------------------------------------
net session >nul 2>&1
if errorlevel 1 (
    echo  ESTE PASO NECESITA PERMISOS DE ADMINISTRADOR.
    echo.
    echo  Cerrar esta ventana y volver a hacer click derecho sobre
    echo  INSTALAR.bat, eligiendo "Ejecutar como administrador".
    echo.
    pause
    exit /b 1
)

REM --------------------------------------------------------------------------
REM  PASO 1: Node.js
REM --------------------------------------------------------------------------
echo  [1/5] Verificando Node.js...
where node >nul 2>nul
if errorlevel 1 (
    echo.
    echo  ERROR: Node.js no esta instalado en esta computadora.
    echo.
    echo  El visor lo necesita para funcionar. Se descarga gratis de:
    echo      https://nodejs.org
    echo.
    echo  Bajar la version "LTS", instalarla con las opciones por defecto,
    echo  y volver a ejecutar este archivo.
    echo.
    pause
    exit /b 1
)
for /f "delims=" %%v in ('node --version') do set NODEVER=%%v
echo        Node.js %NODEVER% encontrado.
echo.

REM --------------------------------------------------------------------------
REM  PASO 2: dependencias
REM --------------------------------------------------------------------------
echo  [2/5] Instalando componentes (puede tardar unos minutos)...
cd servidor
call npm install --no-audit --no-fund
if errorlevel 1 (
    echo.
    echo  ERROR: no se pudieron instalar los componentes.
    echo.
    echo  Causa mas comun: la computadora no tiene salida a internet.
    echo  Los componentes se bajan una sola vez; despues el visor funciona
    echo  sin internet, solo con la red interna de la Municipalidad.
    echo.
    echo  Si no hay internet en este equipo: copiar la carpeta
    echo  servidor\node_modules desde una computadora donde si haya.
    echo.
    cd ..
    pause
    exit /b 1
)
cd ..
echo        Componentes instalados.
echo.

REM --------------------------------------------------------------------------
REM  PASO 3: configuracion de la base de datos
REM ----------------------------------------------------------------------------
REM  Los datos se cargan en una ventana con campos, parecida al cuadro de
REM  conexion de SQL Server Management Studio: la contrasena va oculta y hay un
REM  boton para probar la conexion antes de guardar. La dibuja PowerShell con
REM  Windows Forms, que ya viene incluido en Windows.
REM --------------------------------------------------------------------------
echo  [3/5] Configuracion de la base de datos...

if exist "servidor\.env" (
    echo        Ya existe una configuracion. Se conserva.
    echo        Para cambiarla: doble clic en CONFIGURAR.bat
    goto :configurado
)

echo.
echo        Falta cargar los datos de conexion a la base municipal.
echo        Se abre una ventana para completarlos.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "herramientas\configurar.ps1"
if errorlevel 1 (
    echo.
    echo  Se cancelo la configuracion. No se guardo nada.
    echo  Volve a ejecutar este archivo cuando tengas los datos.
    echo.
    pause
    exit /b 1
)

if not exist "servidor\.env" (
    echo.
    echo  ERROR: no se pudo guardar la configuracion.
    echo  Puede ser que la carpeta este protegida contra escritura.
    echo  Probar moviendo el programa a otra carpeta, por ejemplo:
    echo      C:\VisorCatastral
    echo.
    pause
    exit /b 1
)

echo        Configuracion guardada.

:configurado
echo.

REM --------------------------------------------------------------------------
REM  PASO 4: probar la conexion
REM --------------------------------------------------------------------------
echo  [4/5] Probando la conexion con la base municipal...
echo.
node herramientas\probar-conexion.js
set RESULTADO=%errorlevel%

echo.
echo  ============================================================
if "%RESULTADO%"=="0" (
    echo   LISTO. La instalacion termino y la base responde.
    echo.
    echo   Para usar el visor, hace doble clic en INICIAR.bat
) else (
    echo   La instalacion termino, pero la base NO respondio.
    echo.
    echo   Arriba figura el motivo. Los mas comunes son:
    echo     - la computadora no esta en la red de la Municipalidad
    echo     - el usuario o la contrasena no son correctos
    echo.
    echo   El visor igual va a abrir y el mapa se va a ver, pero las
    echo   fichas de las parcelas van a salir sin datos.
    echo.
    echo   Para corregir los datos de conexion: doble clic en CONFIGURAR.bat
)
echo  ============================================================
echo.

REM --------------------------------------------------------------------------
REM  PASO 5: instalar el visor como Servicio de Windows
REM ----------------------------------------------------------------------------
REM  Se corre siempre, incluso si la base no respondio en el paso anterior:
REM  el servicio queda igual instalado y se conecta solo en cuanto la base
REM  este disponible (hay un reintento automatico cada 2 minutos en
REM  server.js para ese caso).
REM --------------------------------------------------------------------------
echo  [5/5] Instalando el visor como servicio de Windows...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "herramientas\servicio-instalar.ps1"
set RESULTADO_SERVICIO=%errorlevel%

echo.
echo  ============================================================
if "%RESULTADO_SERVICIO%"=="0" (
    echo   LISTO. El visor quedo instalado y corriendo como servicio.
    echo.
    echo   Abre solo, con la computadora, en:  http://localhost:8002/
    echo   No hace falta dejar ninguna ventana abierta.
) else (
    echo   Los pasos anteriores terminaron bien, pero el servicio de
    echo   Windows no quedo instalado o no arranco.
    echo.
    echo   El visor se puede usar igual en modo manual: doble clic en
    echo   INICIAR.bat (deja una ventana abierta mientras se usa).
    echo.
    echo   Para reintentar el servicio: volver a correr INSTALAR.bat
    echo   como administrador.
)
echo  ============================================================
echo.
pause
