# Instalar el visor catastral en una computadora de la Municipalidad

Guía para poner el visor a funcionar en un equipo de la Municipalidad. No hace
falta saber programar: son tres pasos, y el último además deja el visor
arrancando solo con la computadora, sin tener que abrir nada todos los días.

**Requisito:** la computadora tiene que estar en la red de la Municipalidad,
la misma desde donde se accede al sistema de catastro. Sin eso el mapa se ve,
pero las fichas de las parcelas salen sin datos.

---

## 1. Descargar el programa

Entrar a <https://github.com/catastromerlo/Plataforma-MUNI-main>

Botón verde **Code** → **Download ZIP**.

Se baja un archivo de unos 60 MB.

## 2. Descomprimir

Clic derecho sobre el ZIP → **Extraer todo**.

Conviene dejar la carpeta en un lugar fijo y fácil de encontrar, por ejemplo
`C:\VisorCatastral`. **No dejarla en Descargas**: si alguien vacía esa carpeta,
se borra el programa.

## 3. Instalar (una sola vez)

Entrar a la carpeta, clic derecho sobre `INSTALAR.bat` → **Ejecutar como
administrador**. (Hace falta: el último paso deja el visor instalado como
servicio de Windows, y eso requiere permisos de administrador.)

Se abre una ventana negra que va contando los pasos. Va a:

1. Verificar que Node.js esté instalado
2. Descargar los componentes que el visor necesita
3. Pedir los datos de conexión a la base
4. Probar que la conexión funcione
5. Dejar el visor instalado como servicio de Windows, arrancando solo con la
   computadora, en `http://localhost:8002`

Cuando llegue el paso 3 se abre una ventana con cuatro campos:

- **Nombre del servidor** — el equipo donde está la base, o su IP
- **Nombre de la base (opcional)** — ver más abajo
- **Nombre de usuario**
- **Contraseña** — se escribe oculta

> **Sobre el nombre de la base:** si en SQL Server Management Studio te conectás
> dejando ese campo en `<predeterminado>`, acá **dejalo vacío**. `<predeterminado>`
> no es un nombre de base: significa "usá la que corresponde a este usuario".
>
> Si se escribe un nombre de base que no existe, SQL Server responde
> **`Login failed for user`** — el mismo error que da una contraseña equivocada.
> Es de los errores más confusos que hay, porque parece un problema de
> credenciales cuando en realidad es el nombre de la base.

El botón **Probar conexión** verifica los datos antes de guardar y dice qué
falla si algo falla. Después, **Guardar**.

Si no tenés esos datos, apretá Cancelar y pedíselos a quien administre el
sistema de catastro. Se cargan una sola vez y quedan guardados.

### Si dice que falta Node.js

Es un programa gratuito que el visor necesita. Se baja de <https://nodejs.org>,
se elige la versión que dice **LTS**, y se instala aceptando todas las opciones
por defecto. Después se vuelve a ejecutar `INSTALAR.bat`.

### Si dice que no pudo instalar los componentes

Casi siempre es que la computadora no tiene salida a internet. Esos componentes
se bajan **una sola vez**; después el visor funciona sin internet, solamente con
la red interna.

Si el equipo no va a tener internet nunca, hay que copiar la carpeta
`servidor\node_modules` desde otra computadora donde sí se haya podido
instalar.

## 4. Usar el visor

Si el paso anterior instaló el servicio, no hay nada más que hacer: el visor
ya está corriendo y va a seguir arrancando solo cada vez que se prenda la
computadora, en:

```
http://localhost:8002
```

Para abrirlo, entrar a esa dirección en el navegador, o hacer doble clic en
`INICIAR.bat`: lo detecta solo y abre el navegador ahí, sin dejar ninguna
ventana que haya que mantener abierta.

> **Si el servicio no llegó a instalarse** (por ejemplo, porque `INSTALAR.bat`
> no se corrió como administrador), `INICIAR.bat` sigue sirviendo como
> respaldo manual: deja el servidor corriendo en una ventana negra que hay
> que mantener abierta mientras se usa el visor. Para instalar el servicio
> después: volver a correr `INSTALAR.bat`, esta vez como administrador.

### Acceso directo en el escritorio

Para no tener que buscar la carpeta cada vez: clic derecho sobre `INICIAR.bat`
→ **Enviar a** → **Escritorio (crear acceso directo)**. Funciona igual corra
el visor como servicio o en modo manual.

---

## Cómo saber si está funcionando bien

Buscar un padrón conocido y abrir su ficha:

- **Trae titular, superficie y número de cuenta** → funciona correctamente
- **Los campos dicen "sin dato"** → el mapa anda pero no llega a la base
- **Aparece un cartel amarillo "DATOS DE PRUEBA"** → está mostrando datos
  inventados; ver más abajo

Otra forma: entrar a <http://localhost:8002/health>. Tiene que decir
`"database": "connected"`.

---

## Problemas frecuentes

### "Los campos de la ficha salen vacíos"

El visor no está llegando a la base. Doble clic en **`CONFIGURAR.bat`**: se
abre la misma ventana de los datos de conexión, con lo que está cargado hoy, y
el botón **Probar conexión** dice exactamente qué falla. Los dos motivos más
comunes:

- la computadora no está en la red de la Municipalidad
- el usuario o la contraseña quedaron mal cargados

### "Aparece un cartel amarillo de datos de prueba"

El archivo `servidor\.env` tiene `MODO_DEMO=true`. Eso hace que el visor
invente datos cuando no puede conectarse, y sirve solo para pruebas.

En una computadora de la Municipalidad tiene que decir:

```
MODO_DEMO=false
```

Se corrige abriendo `servidor\.env` con el Bloc de notas. Si la configuración
se guardó desde `CONFIGURAR.bat`, ya queda en `false`.

Así, si algo falla, se nota, en lugar de quedar tapado por datos falsos.

### "El visor no arranca: dice que el puerto 8002 ya está en uso"

El visor usa siempre el puerto 8002. Si aparece este aviso es porque algo más
ya lo está usando — lo más común es que el servicio ya esté corriendo y
alguien además haya abierto `INICIAR.bat` a mano. Comprobar en `services.msc`
si **Visor Catastral - Villa de Merlo** figura en marcha: si es así, no hace
falta abrir nada más, el visor ya está disponible en
<http://localhost:8002>.

### "Se abre en Firefox y lo quiero en Chrome"

Ya abre en Chrome. `INICIAR.bat` lo busca en los lugares donde se instala
habitualmente y, si no lo encuentra ahí, en el registro de Windows. Al arrancar
avisa cuál va a usar, en el renglón `Navegador:`.

Si esa computadora no tiene Chrome instalado, abre con el navegador
predeterminado de Windows, como antes. El visor funciona igual en Firefox y en
Edge: esto es una preferencia, no un requisito.

### "El navegador no se abre solo"

Abrirlo a mano y entrar a <http://localhost:8002>. Es siempre ese número,
corra el visor como servicio o en modo manual.

### "El mapa se ve gris, no aparecen las calles"

Las parcelas se dibujan bien pero el fondo con las calles queda vacío, y arriba
del mapa aparece un cartel amarillo avisándolo.

**No falta ninguna clave ni ninguna licencia.** Los mapas de calles que usa el
visor son gratuitos y no piden cuenta de nada. Lo que pasa es que la red de la
Municipalidad no está dejando salir a los servidores que entregan esas
imágenes.

El visor prueba tres proveedores distintos al arrancar y se queda con el
primero que conteste, así que si el cartel aparece es porque ninguno de los
tres responde. Hay que pedirle a sistemas que permitan el acceso a:

```
server.arcgisonline.com
```

Con ese alcanza. Si además se puede habilitar `basemaps.cartocdn.com`, queda un
segundo proveedor de respaldo, pero no es imprescindible.

Mientras tanto el visor **se sigue pudiendo usar**: las parcelas, las
búsquedas, los filtros y las planchetas no dependen de internet, salen de
archivos que están en la propia computadora.

---

## Actualizar a una versión nueva

Doble clic en:

```
ACTUALIZAR.bat
```

Baja la última versión y la aplica sola. **No toca la configuración de la base
ni los componentes instalados**, así que al terminar el visor funciona sin
volver a configurar nada.

Si el visor está instalado como servicio, `ACTUALIZAR.bat` lo detiene antes de
reemplazar los archivos y lo vuelve a arrancar solo al terminar, ya con la
versión nueva funcionando. No hay que reiniciar nada a mano.

Al final muestra qué versión había antes y cuál quedó.

Para reiniciar el servicio manualmente —por ejemplo, después de aplicar
cambios locales—, hacer clic derecho en `SERVICIO-REINICIAR.bat` y elegir
**Ejecutar como administrador**. Al terminar muestra la versión que está
respondiendo en el puerto 8002.

### Cómo saber qué versión está corriendo

La versión aparece **abajo a la derecha del mapa**, junto al sistema de
coordenadas. También al arrancar, en la ventana negra.

Esto importa: si algo que ya se corrigió sigue fallando, casi siempre es que la
computadora está ejecutando una instalación vieja. Antes de buscar el problema
en otro lado, mirá ese número.

### Si la computadora no tiene internet

`ACTUALIZAR.bat` necesita salida a internet para bajar la versión nueva. Si el
equipo no la tiene, hay que hacerlo a mano desde otra máquina:

1. Bajar el ZIP de <https://github.com/catastromerlo/Plataforma-MUNI-main>
2. Descomprimirlo y copiar **encima** de la carpeta del visor, eligiendo
   **Reemplazar los archivos** cuando Windows pregunte
3. **No tocar `servidor\.env`**: ahí están los datos de conexión
4. Comprobar que el número de versión abajo a la derecha del mapa haya cambiado

---

## Qué NO hace este visor

Conviene que quede claro para no esperar de él algo que no hace:

- **No modifica nada.** Solo lee. No puede cambiar, borrar ni cargar datos en
  el sistema de catastro.
- **No funciona fuera de la red municipal.** El mapa se ve, los datos no.
- **No reemplaza al sistema de catastro.** Es una forma de consultarlo sobre el
  mapa.
