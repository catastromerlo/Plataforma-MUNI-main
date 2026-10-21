# AGENTS.md — Guía de Desarrollo para Agentes de IA (OpenCode)

Este documento contiene la arquitectura, las directivas de trabajo, los principios de seguridad y los comandos de prueba requeridos para desarrollar y mantener la **Plataforma MUNI (Sistema Catastral de Villa de Merlo)**.

---

## 1. Descripción General del Proyecto

* **Propósito**: Visor web geográfico e interactivo de las parcelas catastrales de la Municipalidad de Villa de Merlo (San Luis).
* **Funcionalidades principales**: Consulta interactiva de fichas catastrales en vivo, búsqueda por padrón o nomenclatura, filtros combinados por superficie, estado de edificación y zonificación, e impresión de planchetas catastrales y certificados de libre de deuda.

---

## 2. Arquitectura y Stack Tecnológico

* **Frontend**: Aplicación web en JavaScript Vanilla, HTML5 y CSS3 construida sobre la librería de mapas **Leaflet**.
* **Backend**: API REST en **Node.js** con **Express** y el conector `mssql` para comunicación con la base de datos.
* **Base de Datos**: Microsoft SQL Server ubicado en la red municipal con acceso de solo lectura mediante las vistas principales:
  * `VI_GIS_CATASTRO_PADRON` — Datos de la parcela.
  * `VI_CPAR_PROPIETARIOS` — Titulares (múltiples por parcela).
  * `VI_CPAR_FRENTES` — Zonificación.
  * `VI_GIS_ININ_CONTRIBUYENTES` — Estado de cuenta e información del contribuyente.
  * `VI_GIS_CATASTRO_COMERCIO` — Rubros, nomenclaturas y cuentas de comercios.
* **Datos Espaciales**: Capas GeoJSON almacenadas en `web/datos/` en el sistema geodésico **WGS84 (EPSG:4326)**.

---

## 3. Reglas de Oro y Principios de Trabajo

1. **Separación entre Geometría y Atributos**:
   * La forma de las parcelas proviene **exclusivamente** de los archivos GeoJSON (`web/datos/`).
   * Todos los atributos alfanuméricos (superficie, titularidad, deuda, edificación y zonificación) se consultan **en vivo** desde la base de datos municipal.
2. **Seguridad de la Base de Datos Municipal**:
   * La base de datos de SQL Server **nunca** se expone directamente a Internet.
   * El acceso remoto desde fuera de la red municipal se realiza exponiendo únicamente la API/visor mediante un túnel seguro con Cloudflare Access (`cloudflared`) y autenticación de correo.
3. **Preservación de Documentación Administrativa**:
   * La plantilla del **Libre de Deuda del Juzgado de Faltas** se basa en un modelo oficial municipal (`LIBRE__DEUDA__DE__FALTAS.docx`); la redacción de su texto tiene valor administrativo y no debe alterarse de forma arbitraria.
4. **Verificación de Equivalencia e Integridad**:
   * Antes y después de modificar `web/js/app.js` o las consultas en `servidor/server.js`, es obligatorio ejecutar los scripts de verificación de integridad.
5. **Separación obligatoria entre pruebas y producción**:
   * La instalación productiva de GitHub y su actualizador deben conservar el puerto `8002` y el servicio `VisorCatastralMerlo`.
   * La copia de pruebas `C:\Prueba-GIS\Plataforma-MUNI-main` usa el puerto `8003` y el servicio `VisorCatastralMerloPrueba`. Esos valores son exclusivamente locales: nunca incluirlos en un commit o push a `main`.
   * Antes de confirmar cambios, revisar el diff preparado de `INICIAR.bat`, `INSTALAR.bat`, `servidor/server.js`, `servidor/.env.example` y `herramientas/servicio-*.ps1`. Verificar que la configuración publicada siga apuntando a `8002` y al servicio productivo. No copiar la configuración local de pruebas al repositorio de producción.

---

## 4. Estructura del Repositorio

```
Plataforma-MUNI/
├── INSTALAR.bat             # Instalador automatizado del servicio en Windows
├── INICIAR.bat              # Lanzador del servicio y apertura en el navegador
├── CONFIGURAR.bat           # Interfaz de configuración de credenciales de SQL Server
├── ACTUALIZAR.bat           # Actualizador del código preservando credenciales (.env)
├── DIAGNOSTICO.bat          # Generador de informes sobre el estado del sistema
├── VERSION.txt              # Control de versión actual
├── web/                     # Frontend estático del sistema
│   ├── index.html           # Estructura del maquetado UI
│   ├── css/app.css          # Estilos visuales
│   ├── js/config.js         # Dirección base de la API
│   ├── js/app.js            # Lógica del mapa, fichas e impresiones
│   └── datos/               # Archivos GeoJSON con los polígonos
├── servidor/                # Backend API Express
│   ├── server.js            # API REST y consultas SQL Server
│   ├── .env                 # Variables de entorno (no versionado)
│   └── .env.example         # Plantilla de configuración de entorno
├── herramientas/            # Utilidades de prueba, auditoría y optimización
│   ├── probar-conexion.js   # Verificación de conexión a SQL Server y sus vistas
│   ├── revisar-plano.js     # Control de calidad y consistencia de GeoJSON
│   ├── optimizar-datos.js   # Limpieza de atributos pesados en GeoJSON
│   ├── comparar-datos.js    # Verificación de integridad tras optimizar datos
│   ├── verificar-equivalencia.js # Pruebas de regresión para consistencia de datos
│   └── verificar-funcionalidad.js # Chequeo de consistencia entre UI y lógica
└── docs/                    # Guías de documentación técnica y operativa
    ├── instalacion-en-la-muni.md # Manual de instalación sin conocimientos de programación
    ├── actualizar-el-plano.md    # Guía para cargar parcelas o planos nuevos
    ├── acceso-remoto.md         # Configuración del túnel de Cloudflare
    └── conexion-con-la-base.md    # Detalle de vistas y mapeo de campos SQL
```

---

## 5. Comandos de Prueba y Mantenimiento

### Puesta en Marcha del Backend
```bash
cd servidor
npm install
node server.js
```

### Verificación de la Base de Datos
Probar credenciales y comprobar la existencia de las vistas requeridas:
```bash
node herramientas/probar-conexion.js
```

### Testing de Regresión e Integridad
Comprobar que un refactor en el código no cambie los resultados devueltos para las parcelas:
```bash
node herramientas/verificar-equivalencia.js
```
Verificar que la interfaz web no tenga llamadas a funciones o elementos rotos:
```bash
node herramientas/verificar-funcionalidad.js
```

### Gestión y Auditoría de Planos GeoJSON
Auditar un plano nuevo para detectar polígonos rotos, coordenadas incorrectas o faltantes de padrón:
```bash
node herramientas/revisar-plano.js "C:\ruta\PlanoNuevo.json"
```
Comparar el plano GeoJSON con la base municipal para identificar parcelas no dibujadas:
```bash
node herramientas/revisar-plano.js "C:\ruta\PlanoNuevo.json" --comparar
```
Optimizar el tamaño de los GeoJSON reduciendo campos innecesarios:
```bash
node herramientas/optimizar-datos.js
node herramientas/comparar-datos.js
```

---

## 6. Variables de Entorno y Configuración

* **`MODO_DEMO` (`servidor/.env`)**:
  * Puesto en `true`, activa respuestas con datos inventados solo cuando no hay conexión con SQL Server (para desarrollo fuera de la red municipal).
  * Debe permanecer en `false` en los servidores municipales de producción.
* **`HOST` (`servidor/.env`)**:
  * Se establece en `127.0.0.1` si la API se expone a través de un túnel de Cloudflare para limitar la escucha únicamente al puerto local.
* **`API_BASE` (`web/js/config.js`)**:
  * Define el origen o dominio desde el cual el cliente web consume los servicios REST.

---

## 7. Guía para Incorporar Nuevas Capas o Parcelas

1. **Requisitos del GeoJSON**:
   * Proyección geográfica obligatoria: **WGS84 (EPSG:4326)**.
   * Atributos clave obligatorios por polígono: `NRO_RENTA` (padrón) y `NOMENCLA` (nomenclatura catastral de 22 dígitos).
2. **Registro en el Sistema**:
   * Guardar el archivo en `web/datos/`.
   * Actualizar la referencia del archivo en el objeto `PLANO` dentro de `web/js/app.js`.