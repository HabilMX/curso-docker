# Lección 2 — Contenedores en el día a día

Faltan doce minutos para la demostración y el servicio no arranca. Tecleas el mismo comando que ayer funcionó y Docker te contesta con una línea en inglés que termina en `port is already allocated`. Lo intentas otra vez y ahora el mensaje es otro: `The container name ... is already in use`. Alguien a tu lado sugiere reiniciar la computadora. Antes de hacerlo, corres `docker ps -a` y la pantalla se llena: contenedores de la semana pasada, unos detenidos, otros todavía corriendo, uno de ellos publicado en el puerto 9000 **para cualquiera que esté en la misma red inalámbrica de la cafetería** donde trabajaste el martes. Nadie lo hizo con mala intención. Simplemente nadie aprendió a arrancar, mirar, detener y borrar contenedores con orden. Te quedan diez minutos, y esta lección es lo que hubieras necesitado saber.

**Tiempo:** 2 × 45 min

**Qué construyes:** el servicio de prueba del curso corriendo en un contenedor, con su puerto publicado solo para tu equipo y con límites de memoria, CPU y procesos; lo consultas en sus tres modos (sano, lento y caído), lees su bitácora, lo inspeccionas, lo detienes y lo borras. Al final no queda ningún contenedor del curso en tu equipo; la imagen `curso-docker-prueba:1.0.0`, en cambio, se queda, porque las lecciones siguientes vuelven a usarla.

**Qué aprendes:** los comandos del día a día —`run`, `ps`, `logs`, `exec`, `inspect`, `stats`, `stop`, `start` y `rm`—; qué significa publicar un puerto y por qué en este curso siempre se publica en `127.0.0.1`; cómo poner límites de memoria, CPU y procesos y cómo comprobar que quedaron puestos; el ciclo de vida de un contenedor (creado, corriendo, detenido, borrado); y cómo limpiar solo lo tuyo sin tocar lo de nadie más.

**De dónde vienes.** De la [Lección 0](00-que-es-un-contenedor.md) traes el mapa: un contenedor es un proceso aislado, la imagen es la plantilla y el contenedor la copia viva, y el cliente `docker` le pide todo al daemon por un *socket*. De la [Lección 1](01-instalacion.md) traes Docker instalado en tu Mint y tu usuario en el grupo `docker`, sabiendo que eso equivale a `root`. También necesitas el repositorio del curso en tu equipo: de él vas a usar la carpeta `programas/servicio-prueba/`, que trae el servicio de prueba ya escrito y con su `Dockerfile` hecho. No necesitas saber Go ni saber leer ese `Dockerfile` todavía.

**Qué no hace esta lección.** No escribe ningún `Dockerfile`: el del servicio de prueba se usa tal como viene, y aprender a leerlo es trabajo de las Lecciones 3 a 5. No toca todavía al `revisor`, el proyecto principal del curso, porque para correrlo primero hay que empaquetarlo, y eso empieza en la [Lección 3](03-primer-dockerfile.md). Tampoco explica volúmenes ni redes entre contenedores; aquí cada contenedor vive solo y se habla con él desde tu equipo.

**Sobre las corridas.** Las salidas de esta lección se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual de Linux con Ubuntu 24.04.4 (la misma base de Linux Mint 22), procesador ARM de 64 bits. Los guiones se corrieron **dentro de esa máquina virtual**, con Docker 29.2.1 (cliente y daemon, API 1.53). El cliente de la Mac era la 29.8.2, la versión con la que se planeó el curso, y la más reciente publicada ese día era la 29.9.2, del 20 de octubre de 2026, según las [notas de versión oficiales](https://docs.docker.com/engine/release-notes/29/). Tres avisos sobre cómo se corrió. **Primero:** en esa máquina se escribían al mismo tiempo varias lecciones del curso, así que, para no chocar, las corridas usaron nombres con un prefijo propio (`curso-docker-l02-` en vez de `curso-docker-`) y los puertos 18020 y 18021 en vez de 9000 y 9001. En las salidas que lees aquí, y en los archivos `.salida.txt` de los programas, se devolvieron los nombres y puertos que tú vas a usar, y se reacomodaron los espacios de las tablas, porque el ancho de cada columna depende del nombre más largo; nada más se tocó. Es una excepción a la regla del curso de no editar una salida, y se tomó a propósito: correr los guiones con los nombres reales en esa máquina compartida habría sido peligroso, no solo incómodo, porque el `trap` de cada guion borra `curso-docker-prueba` al salir, y ese contenedor podía ser el de otra lección corriendo en ese momento. En tu Mint no hay nadie más, y los guiones corren tal como están escritos. **Segundo:** la salida de `fig02_01.sh` es la de la primera construcción, cuando la imagen todavía no existía; la imagen base de Go ya estaba descargada, así que la construcción de la sección 2.1 no muestra descargas; en tu primera vez vas a ver primero la descarga de las dos imágenes base, la de Go y la mínima, y tardará más. **Tercero:** lo que cambia en tu Mint es la arquitectura (`amd64` en vez de `arm64` si tu procesador es Intel o AMD), los identificadores, los tiempos y la memoria total que reporta `docker stats`. Las soluciones de los ejercicios que citan una salida también se comprobaron en esa máquina, con el mismo prefijo. Los programas están en [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia), cada uno con su salida guardada al lado.

## Al terminar vas a poder

- Construir la imagen del servicio de prueba con un solo comando y encontrarla con `docker image ls`.
- Arrancar un contenedor en segundo plano con nombre, puerto publicado en `127.0.0.1` y límites de memoria, CPU y procesos, y explicar cada opción del comando.
- Listar tus contenedores con `docker ps`, filtrarlos por nombre y elegir qué columnas mostrar.
- Leer la bitácora de un contenedor con `docker logs`, completa o solo sus últimos renglones, y ejecutar un programa dentro de él con `docker exec`.
- Comprobar con `docker inspect` y `docker stats` que los límites quedaron puestos, y con `ss` en qué interfaces escucha tu equipo.
- Leer y resolver los dos errores de todos los días: nombre repetido y puerto ocupado.
- Detener, volver a arrancar y borrar contenedores, y dejar tu equipo sin ningún contenedor `curso-docker-` al terminar.

## El porqué antes del cómo

En la Lección 0 viste contenedores desde dentro, para entender qué son. Ahora toca lo contrario: usarlos todos los días sin pensar en espacios de nombres ni en grupos de control. Y aquí aparece un problema que no tiene nada de técnico y que hace más daño que muchos errores del núcleo: **el desorden**.

Un contenedor es muy fácil de crear. Basta un `docker run`. Y, como no hace ruido, es muy fácil de olvidar. Al cabo de una semana de pruebas tienes contenedores detenidos que ocupan disco, contenedores corriendo que ocupan memoria y puertos, y nombres que ya no puedes reusar. Lo peor no es el disco: es que alguno de ellos quedó escuchando en todas las interfaces de red de tu equipo, y tú no lo sabes. La escena del principio no la causó un error raro; la causaron tres costumbres que nadie corrigió: publicar puertos sin decir dónde, correr sin límites y no limpiar.

Esta lección te da el juego completo de comandos para manejar un contenedor de principio a fin, y junto con cada comando, la costumbre que evita el desorden. Lo vas a hacer con el **servicio de prueba** del curso, un servidor HTTP muy pequeño que falla a propósito. Tiene tres modos: en modo **sano** contesta `200` de inmediato; en modo **lento** tarda tres segundos y luego contesta `200`; en modo **caído** contesta `503`, el código de HTTP para «servicio no disponible». Y el modo se cambia en caliente, sin reiniciarlo, con una petición `POST`. Ese servicio va a ser, a lo largo del curso, el blanco que el `revisor` vigila; aquí te sirve de práctica segura, y todo lo que hagas con él lo vas a repetir con el `revisor`: cuando lo empaquetes en la Lección 3, lo vas a arrancar con este mismo tipo de comando, cambiando el nombre, la imagen y el puerto 8080. Y te sirve para ver una idea que el curso repite: **que un contenedor diga «corriendo» no quiere decir que el servicio esté sano**.

La lección va en este orden:

1. **Construir la imagen** del servicio de prueba (2.1), primero equivocándote.
2. **Arrancar** un contenedor y entender cada parte del comando (2.2).
3. **Mirarlo**: `ps` (2.3), consultarlo (2.4) y leer su bitácora con `logs` (2.5).
4. **Entrar**, o intentarlo, con `exec` (2.6).
5. **Inspeccionarlo** con `inspect` y `stats` (2.7).
6. **Los puertos**: `127.0.0.1` contra todas las interfaces (2.8), y **los límites** (2.9).
7. **El ciclo de vida**: detener, volver a arrancar y borrar (2.10), y **no dejar basura** (2.11).

Este es el comando al que vas a llegar. Al terminar la lección, cada palabra va a tener una razón:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

## Los conceptos

### 2.1 Construir la imagen del servicio de prueba

#### 2.1.1 Primero, el error

Para correr un contenedor necesitas una imagen. Antes de construirla, vale la pena ver qué pasa si te la saltas, porque es un error que vas a ver muchas veces en tu vida: alguien te pasa un comando, lo pegas y la imagen no existe en tu equipo. `fig02_01.sh` hace justo eso, y después construye la imagen:

```bash
#!/usr/bin/env bash
# fig02_01.sh — Correr una imagen que todavía no existe, y después construirla.
# Primero el error (la imagen no está en tu equipo ni en Docker Hub); luego el
# único comando que necesitas para construir el servicio de prueba.
set -uo pipefail
cd "$(dirname "$0")/.."          # la carpeta programas/, donde está servicio-prueba/
IMAGEN=curso-docker-prueba:1.0.0
# Si la imagen ya existía, el bloque 1 no falla y SÍ crea un contenedor: se borra al salir.
trap 'docker rm -f curso-docker-prueba >/dev/null 2>&1 || true' EXIT

echo "== 1. Correr la imagen antes de construirla"
docker run -d --name curso-docker-prueba "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Construirla: un solo comando"
docker build -t "$IMAGEN" servicio-prueba
echo "código de salida: $?"

echo
echo "== 3. La imagen ya está en tu equipo"
docker image ls "$IMAGEN"

echo
echo "== 4. Y el intento fallido no dejó contenedores"
docker ps -a --filter name=curso-docker-prueba --format '{{.Names}} {{.Status}}' | wc -l
```

El guion usa `set -uo pipefail` y no `set -euo pipefail` como los de la Lección 0: le quitamos la `-e` a propósito, porque el primer comando **debe** fallar y queremos que el guion siga. `cd "$(dirname "$0")/.."` se mueve a la carpeta `programas/`, que es donde está `servicio-prueba/`, sin importar desde dónde corras el guion. Y el `trap ... EXIT` deja programado borrar el contenedor al salir: la primera vez no hay nada que borrar, pero si corres el guion con la imagen ya construida, el bloque 1 ya no falla, crea el contenedor y el `trap` lo quita. Esta es la primera parte de la salida:

```text
$ ./fig02_01.sh
== 1. Correr la imagen antes de construirla
Unable to find image 'curso-docker-prueba:1.0.0' locally
docker: Error response from daemon: pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'

Run 'docker run --help' for more information
código de salida: 125
```

Se lee en dos tiempos. La primera línea dice que la imagen no está **en tu equipo** (*locally*). Eso no es todavía un error: cuando `docker run` no encuentra una imagen, la busca en un registro, que por omisión es Docker Hub. La documentación lo explica con la opción `--pull`, cuyo valor por omisión es `missing`: descarga la imagen solo si no está ya en tu equipo ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). La segunda línea es el error de verdad: Docker Hub no tiene un repositorio público llamado `curso-docker-prueba` y no le diste credenciales, así que le negó la descarga. El mensaje no puede saber cuál de las dos cosas pasa —que no existe o que es privado—, por eso dice las dos.

El código de salida **125** también tiene significado. La documentación de Docker reserva tres códigos: 125 quiere decir que el error es del propio daemon de Docker; 126, que el comando del contenedor no se pudo invocar; y 127, que el comando del contenedor no se encontró. Cualquier otro número es el código con el que terminó el programa de dentro ([Docker, «Running containers»](https://docs.docker.com/engine/containers/run/)). Aquí el contenedor ni siquiera llegó a existir: falló Docker, no el servicio. Vas a ver un 127 en la sección 2.6.

> [!NOTE]
> 🔧 **Observación de ingeniería 2.1**
> El orden de búsqueda tiene una consecuencia de seguridad. Si te equivocas al escribir el nombre de una imagen tuya y por casualidad existe una imagen pública con ese nombre, Docker la va a descargar y a correr sin preguntarte. El riesgo está sobre todo en los nombres que llevan usuario u organización, como `alguien/imagen`, porque en esos espacios cualquiera puede publicar; un nombre de una sola parte, como el de este curso, se busca entre las imágenes oficiales de Docker Hub. Por eso conviene que los nombres de tus imágenes locales sean inconfundibles; el prefijo `curso-docker-` de este curso cumple ese papel, además del de poder limpiar lo tuyo con un filtro (2.11).

#### 2.1.2 Un solo comando para construirla

El servicio de prueba se entrega con su receta escrita: el archivo `programas/servicio-prueba/Dockerfile`. Construirlo es un solo comando:

```bash
docker build -t curso-docker-prueba:1.0.0 servicio-prueba
```

Tiene dos partes. `-t curso-docker-prueba:1.0.0` le pone **nombre y etiqueta** a la imagen que resulte: el nombre es `curso-docker-prueba` y la etiqueta, lo que va después de los dos puntos, es `1.0.0`. Y `servicio-prueba`, al final, es la carpeta que Docker usa como **contexto**: ahí busca el `Dockerfile` y de ahí toma los archivos que la receta pide copiar. La Lección 4 se dedica entera al contexto; aquí basta saber que es una carpeta.

La salida de la construcción es larga; esta es la parte central (el archivo completo está en `fig02_01.salida.txt`):

```text
== 2. Construirla: un solo comando
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 836B done
#1 DONE 0.0s
[…]
#6 [1/4] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#6 resolve docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c 0.0s done
#6 DONE 0.0s
[…]
#12 [compilacion 4/4] RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/servicio-prueba .
#12 DONE 32.9s

#13 [stage-1 2/2] COPY --from=compilacion /out/servicio-prueba /servicio-prueba
#13 DONE 0.1s

#14 exporting to image
[…]
#14 naming to docker.io/library/curso-docker-prueba:1.0.0 done
#14 unpacking to docker.io/library/curso-docker-prueba:1.0.0 0.1s done
#14 DONE 0.5s
código de salida: 0
```

No hace falta entender cada renglón hoy, pero sí tres cosas. La construcción va en **pasos numerados** (`#1`, `#2`…) y cada uno dice cuánto tardó: el más largo, 32.9 segundos, es el que compila el programa en Go dentro de una imagen que trae el compilador. Al final aparece `naming to docker.io/library/curso-docker-prueba:1.0.0`: el nombre corto que diste es, completo, el de una imagen de Docker Hub en la biblioteca oficial (`library`), aunque nunca vaya a subirse a ningún lado; así nombra Docker a todo lo que no trae un registro escrito. Y el código de salida es **0**: todo salió bien. Las Lecciones 3, 4 y 5 te enseñan a leer este archivo renglón por renglón.

#### 2.1.3 Encontrar la imagen

```text
== 3. La imagen ya está en tu equipo
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE                       ID             DISK USAGE   CONTENT SIZE   EXTRA
curso-docker-prueba:1.0.0   06306fe8744c   15.1MB       3.37MB

== 4. Y el intento fallido no dejó contenedores
0
```

Si vienes de tutoriales viejos, esta tabla te va a parecer distinta. Desde la versión 29.0, `docker image ls` muestra una vista nueva por omisión, «como `--tree`, pero plegada», y esconde las imágenes sin etiqueta salvo que pidas `--all` ([notas de versión de Docker Engine 29](https://docs.docker.com/engine/release-notes/29/)). La página de referencia del comando todavía muestra las columnas anteriores (`REPOSITORY`, `TAG`, `IMAGE ID`, `CREATED`, `SIZE`) ([docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/)), así que no te extrañe si tu salida y un tutorial no coinciden. El aviso `WARNING` de la primera línea te lo dice el propio Docker: esta vista es para leerla una persona; si vas a procesar la salida con un guion, usa `--format`, que es lo que hace el resto de la lección.

La columna que usa este curso para hablar del tamaño de una imagen es **DISK USAGE**: 15.1 MB es lo que ocupa la imagen en tu disco. La columna **CONTENT SIZE** es más chica; todo indica que cuenta el contenido de la imagen comprimido, tal como viaja por la red, pero la documentación de referencia todavía no la describe, así que en este curso no la usamos para nada. Con un formato propio se obtiene directamente el tamaño:

```bash
docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

En la salida de las corridas del curso, ese comando imprimió `curso-docker-prueba:1.0.0 15.1MB`.

El bloque 4 confirma algo que importa para la limpieza: el `docker run` fallido de la sección 2.1.1 **no dejó contenedor**. Como no había imagen, no había de dónde crearlo. En la sección 2.8 vas a ver un error que sí deja uno.

### 2.2 Arrancar un contenedor

#### 2.2.1 El comando, opción por opción

Con la imagen lista, el comando de esta lección:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Léelo de izquierda a derecha. Cada opción responde una pregunta que, si no contestas, Docker contesta por ti, y casi nunca como te conviene:

| Opción | Pregunta que contesta | Lo que pasa si no la pones |
|---|---|---|
| `-d` | ¿me devuelves la terminal? | el contenedor se queda pegado a tu terminal; si la cierras o aprietas Ctrl+C, le llega la señal |
| `--name curso-docker-prueba` | ¿cómo se llama? | Docker inventa un nombre al azar, como `busy_goldwasser`, que no vas a recordar |
| `-p 127.0.0.1:9000:9000` | ¿quién puede hablarle, y por qué puerto? | ninguna otra máquina, y tú solo por la dirección interna del contenedor, no por `127.0.0.1`; y si pones `-p 9000:9000` sin dirección, **cualquiera en tu red** |
| `--memory 64m` | ¿cuánta memoria puede usar? | toda la de tu equipo |
| `--cpus 0.5` | ¿cuánta CPU? | toda |
| `--pids-limit 50` | ¿cuántos procesos puede crear? | los que quiera |
| `curso-docker-prueba:1.0.0` | ¿de qué imagen? | (obligatorio) |

`-d` es la forma corta de `--detach`: según la documentación, corre el contenedor en segundo plano e imprime su identificador ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Sin `-d`, la salida del servicio aparece en tu terminal y la terminal se queda ocupada hasta que el contenedor termine. Eso a veces sirve para una prueba rápida; para un servidor, casi nunca.

`--name` le da un nombre. La documentación dice que, si no lo das, el daemon genera uno al azar ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Un nombre propio sirve para dos cosas: para escribir `docker logs curso-docker-prueba` en vez de copiar un identificador de 64 caracteres, y para que el nombre te recuerde de quién es el contenedor. Pero tiene una consecuencia: **en un mismo daemon no puede haber dos contenedores con el mismo nombre**, ni siquiera si uno está detenido. Es el primer error de la escena, y lo provocas en la sección 2.8.

`-p` es la forma corta de `--publish`, y tiene tres partes separadas por dos puntos: `dirección:puerto-del-anfitrión:puerto-del-contenedor`. `127.0.0.1:9000:9000` quiere decir «en mi equipo, solo en la dirección `127.0.0.1` y en el puerto 9000, recibe conexiones y pásalas al puerto 9000 del contenedor». Los dos números no tienen que ser iguales: con `127.0.0.1:18000:9000`, tú le hablarías por el 18000 y el servicio seguiría escuchando en su 9000. Recuerda de la Lección 0 que cada contenedor tiene su propia red. Sin `-p`, su puerto 9000 solo se alcanza desde la red interna de Docker: desde los otros contenedores de esa red y desde tu propio equipo, si usas la dirección interna del contenedor; la documentación lo dice así: los puertos de los contenedores en las redes de tipo puente son accesibles desde el anfitrión aunque no se publiquen ([Docker, «Port publishing and mapping»](https://docs.docker.com/engine/network/port-publishing/)). Lo que no se alcanza sin `-p` es el puerto desde `127.0.0.1` de tu equipo ni desde ninguna otra máquina. La sección 2.8 se dedica a la dirección, que es la parte más importante.

`--memory`, `--cpus` y `--pids-limit` son el presupuesto que la Lección 0 te enseñó a leer en `/sys/fs/cgroup`. La sección 2.9 explica por qué estos números.

#### 2.2.2 Arrancarlo y esperar a que conteste

`fig02_02.sh` arranca el contenedor y hace con él lo que harías en un día normal. Este es el guion completo; su salida se reparte en las secciones 2.2 a 2.5:

```bash
#!/usr/bin/env bash
# fig02_02.sh — El servicio de prueba corriendo: arrancar, listar, consultar y leer su bitácora.
# Puerto publicado solo en 127.0.0.1 y con límites de memoria, CPU y procesos.
set -euo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Arrancar en segundo plano"
docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
# Esperar a que conteste (máximo 10 s), en vez de dormir un número fijo.
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo
echo "== 2. Lo que está corriendo"
docker ps --filter name="$NOMBRE" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== 3. Consultarlo en sus tres modos"
curl -s http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/caido
curl -s -w 'código HTTP: %{http_code}\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/lento
curl -s -w 'código HTTP: %{http_code} en %{time_total} s\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/sano
curl -s http://127.0.0.1:9000/modo

echo
echo "== 4. Su bitácora completa"
docker logs "$NOMBRE"

echo
echo "== 5. Solo los dos últimos renglones"
docker logs --tail 2 "$NOMBRE"
```

```text
$ ./fig02_02.sh
== 1. Arrancar en segundo plano
c516467655b6
```

Lo único que imprime `docker run -d` es el **identificador** del contenedor, un número hexadecimal de 64 caracteres; el guion lo recorta a los primeros 12 con `cut -c1-12`, que es como Docker lo muestra en casi todos lados. Cambia en cada corrida. Que aparezca quiere decir que el contenedor se creó y se le pidió arrancar; **no** quiere decir que el servicio de dentro ya esté atendiendo.

Por eso el renglón siguiente del guion es un ciclo: intenta una petición con `curl` cada medio segundo, hasta veinte veces, y sale en cuanto una contesta bien. `curl -f` hace que `curl` falle si el servidor responde con un error, `-s` lo calla y `-o /dev/null` tira la respuesta. Es mejor que un `sleep 3` fijo por dos razones: en una computadora rápida no esperas de más, y en una lenta no avanzas antes de tiempo. Vas a ver este patrón en todos los guiones del curso que le hablan al servicio; donde no se le habla, no hace falta esperar.

El `trap ... EXIT` de arriba es la misma costumbre de la Lección 0: pase lo que pase, al salir el guion borra su contenedor. En los guiones de esta lección lo verás siempre, porque la sección 2.11 lo vuelve regla.

### 2.3 Ver lo que está corriendo: `docker ps`

```text
== 2. Lo que está corriendo
NAMES                 IMAGE                       STATUS                            PORTS
curso-docker-prueba   curso-docker-prueba:1.0.0   Up 2 seconds (health: starting)   127.0.0.1:9000->9000/tcp
```

`docker ps` lista los contenedores. Por omisión muestra solo **los que están corriendo**; con `-a` (`--all`) muestra también los detenidos ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). Esa diferencia es la que esconde la basura: un contenedor detenido no aparece en `docker ps`, pero sigue existiendo, ocupa disco y retiene su nombre.

El guion usa dos opciones que vale la pena aprender desde ya. `--filter name=curso-docker-prueba` deja solo los contenedores cuyo nombre contiene ese texto; la documentación dice que el filtro `name` coincide con «todo o parte» del nombre ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). Y `--format 'table ...'` elige las columnas: `{{.Names}}`, `{{.Image}}`, `{{.Status}}` y `{{.Ports}}` son campos, y la palabra `table` al principio pide encabezados y columnas alineadas. Lo que va entre llaves dobles es una plantilla del lenguaje Go; no necesitas saber Go para usarla, solo los nombres de los campos, que la página del comando lista. Hay otros filtros útiles; el de estado, por ejemplo, acepta `created`, `restarting`, `running`, `removing`, `paused`, `exited` y `dead` ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)).

Las columnas, una por una:

- **NAMES** es el nombre que le diste.
- **IMAGE**, la imagen de la que nació.
- **STATUS** dice `Up 2 seconds`: está corriendo desde hace dos segundos. Y trae algo más, `(health: starting)`, que merece un párrafo propio.
- **PORTS** dice `127.0.0.1:9000->9000/tcp`: el puerto 9000 de tu equipo, solo en `127.0.0.1`, lleva al 9000 del contenedor, por TCP.

El `(health: starting)` aparece porque el `Dockerfile` del servicio de prueba trae una instrucción `HEALTHCHECK`: le dice a Docker que, cada cinco segundos, corra dentro del contenedor el subcomando `servicio-prueba healthcheck`, que pregunta al propio servicio si contesta bien. Mientras no termina la primera revisión, el estado es `starting`; después será `healthy` o `unhealthy`. Hoy no lo vas a usar más que para leerlo; cómo se escribe una revisión de salud y qué hace Docker con ella es tema de la Lección 7. Pero fíjate desde ahora en que **`Up` y la salud son dos cosas distintas**: `Up` dice que el proceso existe; la salud dice si atiende. La sección siguiente lo muestra.

### 2.4 Hablar con el servicio

```text
== 3. Consultarlo en sus tres modos
sano
modo: caido
caido
código HTTP: 503
modo: lento
lento
código HTTP: 200 en 3.081298 s
modo: sano
modo: sano
```

Lee cada par de renglones como pregunta y respuesta:

1. `GET /` en modo sano contesta `sano`.
2. `POST /modo/caido` cambia el modo y confirma `modo: caido`. Desde ese instante, `GET /` contesta el texto `caido` con el código **503**. La opción `-w` de `curl` imprime datos de la petición después de la respuesta; aquí, el código HTTP.
3. `POST /modo/lento` y el siguiente `GET /` tarda **3.08 segundos** en contestar `lento` con un 200. Los tres segundos son el retardo del modo lento; lo de más es el viaje de ida y vuelta. Ese número cambia un poco en cada corrida; en otra corrida del curso salió 3.003 segundos.
4. `POST /modo/sano` lo regresa a la normalidad, y `GET /modo` lo confirma.

Ahora la pregunta que importa. Mientras el servicio contestaba `503`, ¿qué decía `docker ps`? Decía `Up`. Para Docker, el contenedor estaba perfecto: el proceso existía y no había terminado. Para cualquiera que lo usara, estaba caído. **Docker no sabe lo que contesta tu servicio**, salvo que se lo enseñes con una revisión de salud. Es el criterio que el curso repite en cada lección: un contenedor corriendo no es un servicio sano. El `revisor`, el proyecto que vas a empaquetar desde la Lección 3, existe exactamente para hacer esa pregunta desde fuera.

### 2.5 La bitácora: `docker logs`

```text
== 4. Su bitácora completa
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: modo cambiado a caido
servicio-prueba: GET / en modo caido
servicio-prueba: modo cambiado a lento
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano

== 5. Solo los dos últimos renglones
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano
```

Todo lo que el programa principal del contenedor escribe en su **salida estándar** y en su **salida de errores** —lo que en tu terminal verías con `printf` o con `echo`— lo guarda Docker, y `docker logs` te lo devuelve. La documentación lo describe así: el comando entrega los registros que existen en el momento de ejecutarlo, y con `--follow` sigue transmitiendo lo nuevo que salga del `STDOUT` y el `STDERR` del contenedor ([docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/)).

Fíjate que la bitácora cuenta la historia completa de la sección anterior, en orden: el arranque, las dos primeras peticiones (la del ciclo de espera y la tuya), cada cambio de modo y cada petición con su modo. Las peticiones a `/modo` no dejan rastro porque el servicio no las anota; un programa solo deja en la bitácora lo que su autor decidió escribir. Y un aviso: la revisión de salud de la imagen (2.3) también hace un `GET /` cada cinco segundos, y cada una deja su renglón. Esta corrida duró menos de cinco segundos, así que no aparece ninguna; en un contenedor que lleva rato corriendo vas a ver renglones `GET / en modo …` que tú no pediste. Los pidió Docker.

Las opciones que vas a usar a diario, todas de la [página del comando](https://docs.docker.com/reference/cli/docker/container/logs/):

| Opción | Qué hace |
|---|---|
| `--tail N` (o `-n N`) | solo los últimos N renglones; por omisión, todos |
| `--follow` (o `-f`) | se queda escuchando y te muestra lo nuevo conforme llega; sales con Ctrl+C |
| `--since 10m` | solo lo de los últimos diez minutos; también acepta una fecha y hora |
| `--timestamps` (o `-t`) | antepone a cada renglón la hora en que Docker lo recibió |

`--tail` importa más de lo que parece. Un servicio que lleva semanas corriendo puede tener millones de renglones, y un `docker logs` sin límites te llena la terminal. La costumbre buena es `docker logs --tail 50 <nombre>` primero, y `-f` si quieres seguir mirando.

Dos avisos que te van a ahorrar sustos. **La bitácora sobrevive a `docker stop`, pero no a `docker rm`:** vive con el contenedor, así que la puedes leer después de detenerlo (lo vas a ver en 2.10) y desaparece cuando lo borras. Si un contenedor murió de forma rara, **léele la bitácora antes de borrarlo**. Y **`docker logs` solo ve lo que el programa principal escribe en sus dos salidas**: si el programa escribe su bitácora en un archivo dentro del contenedor, `docker logs` no la ve. Por eso los programas pensados para contenedores, como el servicio de prueba y el `revisor`, escriben todo en la salida estándar.

### 2.6 Entrar al contenedor: `docker exec`

#### 2.6.1 La imagen no trae shell

En los tutoriales verás mucho este comando: `docker exec -it <nombre> sh`, «para meterte al contenedor». `docker exec` ejecuta un programa **dentro** de un contenedor que ya está corriendo; `-i` mantiene abierta la entrada estándar y `-t` le asigna una terminal, para poder escribir comandos ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)). Pruébalo con el servicio de prueba, que es lo que hace `fig02_03.sh` (sin `-it`, porque un guion no tiene a nadie escribiendo):

```bash
#!/usr/bin/env bash
# fig02_03.sh — exec: ejecutar un programa dentro de un contenedor que ya corre.
# La imagen del servicio de prueba no trae shell: se ve el error y lo que sí funciona.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Pedir un shell"
docker exec "$NOMBRE" sh
echo "código de salida: $?"

echo
echo "== 2. Ejecutar un programa que la imagen SÍ trae"
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 3. Lo mismo, con el servicio en modo caído"
curl -s -X POST http://127.0.0.1:9000/modo/caido >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 4. exec en un contenedor detenido"
docker stop "$NOMBRE" >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"
```

```text
$ ./fig02_03.sh
== 1. Pedir un shell
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
código de salida: 127

== 2. Ejecutar un programa que la imagen SÍ trae
sano
código de salida: 0

== 3. Lo mismo, con el servicio en modo caído
no sano: GET / respondió 503
código de salida: 1

== 4. exec en un contenedor detenido
Error response from daemon: container 78614f9ea0da425237a13924f63235bf6a1e45629efd4000d3764b5c54e23dcb is not running
código de salida: 1
```

El primer bloque es el error. Léelo de derecha a izquierda, que es como se leen casi todos los errores de Docker: la causa está al final. `exec: "sh": executable file not found in $PATH` dice que no existe ningún programa llamado `sh` en las carpetas donde se buscan los programas. Lo de antes, `OCI runtime exec failed`, dice quién lo descubrió: `runc`, el programa que crea los procesos de los contenedores (lo conociste en la Lección 0). Y el código **127**, como viste en 2.1.1, es el que Docker reserva para «el comando no se encontró».

No es una falla del contenedor: es una decisión de diseño. La imagen del servicio de prueba se construyó sobre una base mínima, de las llamadas *distroless*, que **solo trae el programa y lo indispensable para que corra**: no trae `sh`, ni `ls`, ni `cat`, ni gestor de paquetes. Eso tiene un precio, que acabas de pagar: no puedes «meterte» a curiosear. Y tiene una ganancia, que la Lección 5 aprovecha para el `revisor`: si alguien lograra ejecutar algo dentro de ese contenedor, no encontraría herramientas con las cuales seguir. Una imagen sin shell es una imagen con menos con qué atacar.

#### 2.6.2 Lo que sí se puede hacer

El segundo bloque muestra que `exec` funciona perfectamente con un programa que la imagen **sí** trae: el propio `/servicio-prueba`, con su subcomando `healthcheck`. El programa le pregunta al servicio que corre a su lado si contesta, imprime `sano` y sale con 0. El tercer bloque repite la pregunta con el servicio en modo caído: `no sano: GET / respondió 503`, y sale con 1. Ese subcomando es el mismo que la instrucción `HEALTHCHECK` corre cada cinco segundos; lo acabas de correr a mano. Fíjate que aquí el código no es 127 sino 1: el programa sí se encontró y sí corrió; simplemente contestó «no».

Dos reglas de `exec` que vienen de su documentación ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)):

- **Solo funciona mientras el proceso principal del contenedor corre.** Es el cuarto bloque: con el contenedor detenido, el daemon contesta `container ... is not running`. Para ver qué le pasó a un contenedor detenido no se usa `exec`, se usan `logs` e `inspect`.
- **El comando tiene que ser un ejecutable**, no una línea de shell. `docker exec <nombre> "echo hola && ls"` no funciona; si la imagen tiene shell, se escribe `docker exec <nombre> sh -c 'echo hola && ls'`.

Cuando la imagen sí trae shell, como la `alpine:3.24.2` de la Lección 0, el famoso comando funciona y te deja escribiendo dentro:

```bash
docker run -d --name curso-docker-dormilon --memory 16m --cpus 0.25 --pids-limit 20 \
  alpine:3.24.2 sleep 300
docker exec -it curso-docker-dormilon sh
```

Úsalo para **mirar**, nunca para **arreglar**. Lo aprendiste en la Lección 0: lo que cambies ahí dentro vive en la capa del contenedor y se va con él. Y borra el contenedor al terminar: `docker rm -f curso-docker-dormilon`.

### 2.7 Lo que Docker sabe de un contenedor: `inspect` y `stats`

#### 2.7.1 `docker inspect` con una plantilla

`docker inspect` devuelve «información de bajo nivel» sobre un objeto de Docker ([docker inspect](https://docs.docker.com/reference/cli/docker/inspect/)): todo lo que el daemon sabe de él, en JSON. Es mucho. `fig02_04.sh` lo usa con plantillas para sacar solo lo que importa, y compara el contenedor con límites contra uno igual sin límites:

```bash
#!/usr/bin/env bash
# fig02_04.sh — inspect y stats: lo que Docker sabe de un contenedor, con y sin límites.
set -euo pipefail
CON=curso-docker-prueba
SIN=curso-docker-sin-limites
trap 'docker rm -f "$CON" "$SIN" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CON" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name "$SIN" curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

FORMATO='{{.Name}}: memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}'

echo "== 1. inspect, con una plantilla: solo los campos que me importan"
docker inspect --format "$FORMATO" "$CON" "$SIN"

echo
echo "== 2. inspect: estado, puerto publicado y comando principal"
docker inspect --format 'estado={{.State.Status}} pid1={{.Config.Entrypoint}} puertos={{json .HostConfig.PortBindings}}' "$CON"

echo
echo "== 3. stats: lo que gastan ahora mismo, contra su límite"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.PIDs}}' "$CON" "$SIN"

echo
echo "== 4. Cuántos renglones trae inspect completo"
docker inspect "$CON" | wc -l
```

```text
$ ./fig02_04.sh
== 1. inspect, con una plantilla: solo los campos que me importan
/curso-docker-prueba: memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532
/curso-docker-sin-limites: memoria=0 cpus(nano)=0 pids=<no value> usuario=65532:65532

== 2. inspect: estado, puerto publicado y comando principal
estado=running pid1=[/servicio-prueba] puertos={"9000/tcp":[{"HostIp":"127.0.0.1","HostPort":"9000"}]}

== 3. stats: lo que gastan ahora mismo, contra su límite
NAME                       MEM USAGE / LIMIT     PIDS
curso-docker-prueba        1.59MiB / 64MiB       8
curso-docker-sin-limites   1.496MiB / 15.59GiB   7

== 4. Cuántos renglones trae inspect completo
224
```

Todo el primer bloque es estable: estos números salen iguales en tu Mint. Léelos:

- `memoria=67108864` son 64 × 1024 × 1024 bytes: los 64 MiB que pediste, el mismo número que la Lección 0 leyó en `memory.max`.
- `cpus(nano)=500000000`: Docker guarda la CPU en milmillonésimas de CPU; 500 millones son media CPU.
- `pids=50`, el tope de procesos.
- `usuario=65532:65532`: el servicio **no corre como `root`**. Lo decidió la imagen, con una instrucción `USER` que la Lección 3 te enseña a escribir. Compáralo con el `sleep` de la Lección 0, que corría como usuario 0.

Y el renglón del contenedor sin límites dice `memoria=0`, `cpus(nano)=0` y `pids=<no value>`. En este campo, **cero no quiere decir «nada de memoria»: quiere decir «sin límite»**. Es la forma en que Docker guarda «no me pediste nada». `<no value>` es lo que imprime la plantilla cuando el campo ni siquiera existe. Cuando revises un contenedor ajeno, un cero aquí es una señal de alarma, no de tranquilidad.

El nombre sale con una diagonal adelante, `/curso-docker-prueba`. No es un error tuyo: así guarda Docker los nombres internamente, y por eso el mensaje del nombre repetido de la sección 2.8 también la lleva.

El segundo bloque muestra otros tres campos. `.State.Status` es el estado (`running`). `.Config.Entrypoint` es el programa que la imagen arranca como proceso principal. Y `{{json .HostConfig.PortBindings}}` usa la función `json` de las plantillas para imprimir un campo compuesto tal cual: el puerto 9000 del contenedor está atado a la dirección `127.0.0.1`, puerto 9000, de tu equipo.

El cuarto bloque explica por qué se usan plantillas: el `inspect` completo de este contenedor, que es de los sencillos, tiene **224 renglones**. Leerlo entero es útil una vez, para saber qué hay. Para preguntar algo concreto, plantilla.

#### 2.7.2 `docker stats`: lo que gasta ahora mismo

`inspect` dice cuáles son los límites; `docker stats` dice **cuánto se está gastando**. Por omisión es una pantalla que se actualiza sola, como `top`; con `--no-stream` toma una sola lectura y termina, que es lo que necesita un guion ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)). La columna **MEM USAGE / LIMIT** muestra la memoria que el contenedor usa contra la que tiene permitida, y **PIDS** cuántos procesos e hilos ha creado ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)).

El servicio de prueba usa entre 1 y 2 MiB y tiene unos cuantos hilos (8 en esta corrida, 6 en otra; el número varía). Lo importante es la columna del límite. Con límites dice `64MiB`. Sin límites dice `15.59GiB`, que es **toda la memoria de la máquina** donde se corrió (la máquina virtual de Colima). En tu Mint, ese número será la memoria de tu computadora. Es la escena de la Lección 0 vista desde Docker: un contenedor sin límite tiene como límite el equipo entero.

### 2.8 Los puertos: `127.0.0.1` contra todas las interfaces

#### 2.8.1 Qué significa la dirección

Tu computadora tiene varias **interfaces de red**, que son como puertas por las que entran conexiones: la de la red inalámbrica, quizá la del cable, y una especial que se llama ***loopback***, con la dirección `127.0.0.1`. La de *loopback* no lleva a ningún lado fuera de tu equipo: lo que entra por ahí solo puede venir de tu propia computadora.

Cuando publicas un puerto sin dirección, con `-p 9000:9000`, Docker lo publica **en todas las interfaces**. La documentación lo dice sin rodeos: si no das una dirección, el daemon publica los puertos en todas las direcciones del anfitrión, `0.0.0.0` y `[::]`, y advierte en un recuadro que «publicar puertos de un contenedor es inseguro por omisión», porque el puerto queda al alcance no solo del anfitrión sino «del mundo exterior» ([Docker, «Port publishing and mapping»](https://docs.docker.com/engine/network/port-publishing/)). Con `127.0.0.1` delante, «solo el anfitrión puede acceder» al puerto publicado (misma fuente). Eso vale desde Docker 28: la misma página advierte que, en versiones anteriores a la 28.0.0, los equipos del mismo segmento de red podían llegar a los puertos publicados en `127.0.0.1`. Es una razón más para instalar Docker desde el repositorio oficial, como en la Lección 1, y no una versión vieja.

`fig02_05.sh` arranca dos copias del servicio, una de cada forma, y le pregunta a Docker y al sistema operativo dónde quedaron:

```bash
#!/usr/bin/env bash
# fig02_05.sh — Publicar en 127.0.0.1 contra publicar en todas las interfaces.
# Se corre en el anfitrión (tu Mint): ss lista los puertos en los que escucha el equipo.
set -euo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-abierto >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name curso-docker-abierto -p 9001:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for p in 9000 9001; do
  for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.5; done
done

echo "== 1. Lo que dice docker port"
echo "-- curso-docker-prueba:"; docker port curso-docker-prueba
echo "-- curso-docker-abierto:"; docker port curso-docker-abierto

echo
echo "== 2. Lo que dice el sistema operativo: dónde escucha el equipo"
ss -ltn | grep -E ':900[01] ' | awk '{print $4}' | sort
```

```text
$ ./fig02_05.sh
== 1. Lo que dice docker port
-- curso-docker-prueba:
9000/tcp -> 127.0.0.1:9000
-- curso-docker-abierto:
9000/tcp -> 0.0.0.0:9001
9000/tcp -> [::]:9001

== 2. Lo que dice el sistema operativo: dónde escucha el equipo
0.0.0.0:9001
127.0.0.1:9000
[::]:9001
```

`docker port` muestra, para un contenedor, qué puerto suyo va a qué dirección y puerto de tu equipo. `ss -ltn` es una herramienta normal de Linux que lista los puertos donde el equipo escucha conexiones TCP (`-l` escuchando, `-t` TCP, `-n` con números en vez de nombres); el `grep` deja solo los renglones de los puertos 9000 y 9001, y el `awk` se queda con la columna de la dirección.

Las dos fuentes dicen lo mismo. El contenedor publicado bien escucha **solo** en `127.0.0.1:9000`. El otro escucha en `0.0.0.0:9001`, que en lenguaje de redes quiere decir «en todas las direcciones IPv4 de este equipo», y en `[::]:9001`, lo mismo para IPv6. Si tu Mint está conectado a la red de una cafetería, de una universidad o de una oficina, cualquiera en esa red puede escribir la dirección de tu computadora y el puerto 9001 y hablar con tu contenedor. El servicio de prueba es inofensivo; una base de datos de pruebas con contraseña de ejemplo, no.

#### 2.8.2 El cortafuegos no te salva

Quizá pienses que para eso tienes un cortafuegos. En Mint, el cortafuegos de escritorio es `ufw`. Aquí está la trampa: **los puertos que publica Docker pasan por encima de las reglas de `ufw`**. La referencia de `docker run` lo advierte: los puertos publicados en todas las interfaces quedan accesibles desde fuera aunque `ufw` esté configurado para bloquearlos, porque Docker administra sus propias reglas de filtrado de paquetes ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). La guía de cortafuegos de Docker explica el mecanismo: el tráfico de un contenedor «se desvía antes de pasar por la configuración de `ufw`» y los paquetes se enrutan «antes de que las reglas del cortafuegos se puedan aplicar» ([Docker, «Packet filtering and firewalls»](https://docs.docker.com/engine/network/packet-filtering-firewalls/)).

No lo midas en tu red sin permiso. Basta con saberlo y con la conclusión: **la protección está en el `-p`, no en el cortafuegos**. Por eso en este curso todos los puertos se publican con `127.0.0.1:` delante, y el único que no lo lleva es el `9001` de este guion, que existe para que lo veas y se borra al terminar.

> [!NOTE]
> 🔧 **Observación de ingeniería 2.2**
> Un puerto publicado de más no avisa. No hay ningún mensaje que diga «este contenedor quedó abierto a tu red». La única forma de saberlo es preguntar: `docker ps` en la columna PORTS (busca `0.0.0.0` o `[::]`) o `ss -ltn` en el equipo. Hazlo una costumbre cada vez que te conectes a una red que no es la tuya.

### 2.9 Los límites: memoria, CPU y procesos

La Lección 0 te mostró qué hacen los límites por dentro: Docker escribe un número en un archivo del núcleo y el núcleo lo hace cumplir. Aquí la pregunta es práctica: **qué números poner**.

La documentación de Docker es clara sobre lo que pasa si no pones ninguno: un contenedor «no tiene restricciones de recursos» y usa todo lo que el planificador del núcleo le deje; y cuando el equipo se queda sin memoria, el núcleo empieza a matar procesos, cualquier proceso, incluido el propio Docker, y eso «puede tumbar el sistema entero si se mata al proceso equivocado» ([Docker, «Resource constraints»](https://docs.docker.com/engine/containers/resource_constraints/)). Los tres límites del comando de esta lección:

**`--memory 64m`.** El servicio de prueba usa entre 1 y 2 MiB (lo mediste en 2.7.2). 64 MiB le dan un margen de más de treinta veces. La regla general es esa: **mide primero, y pon un límite holgado por encima de lo medido**, no por debajo. Si el programa pasa el límite, el núcleo lo mata dentro de su propio grupo, como viste en la Lección 0 (código 137 y `OOMKilled=true`), y nadie más en tu equipo se entera. La documentación fija un mínimo de 6 MB para esta opción ([Docker, «Resource constraints»](https://docs.docker.com/engine/containers/resource_constraints/)).

**`--cpus 0.5`.** Media CPU. Un servicio que solo contesta peticiones pequeñas no necesita más, y si entra en un ciclo infinito por un error, se come media CPU y no toda. La documentación lo explica con su propio ejemplo: en un equipo con dos CPU, `--cpus="1.5"` le garantiza al contenedor como máximo una CPU y media ([Docker, «Resource constraints»](https://docs.docker.com/engine/containers/resource_constraints/)). A diferencia de la memoria, pasarse de la CPU no mata a nadie: el núcleo simplemente le da menos tiempo, y el programa va más lento.

**`--pids-limit 50`.** Ajusta el tope de procesos del contenedor; con `-1` se quita ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Este límite protege de algo muy concreto: un programa que, por error o por un ataque, crea procesos sin parar. Sin tope, puede llenar la tabla de procesos del equipo y dejarte sin poder abrir ni una terminal. El servicio tenía 8 (2.7.2); 50 le sobra.

Fíjate que los tres límites van **desde el primer contenedor**, no «cuando el servicio esté en producción». La Lección 0 lo dijo con la escena de la base de datos: el límite no es para el día normal, es para el día malo, y el día malo no avisa.

### 2.10 El ciclo de vida: detener, volver a arrancar y borrar

#### 2.10.1 Los estados

Un contenedor pasa por estados, y cada comando lo mueve de uno a otro:

| Estado | Cómo llega ahí | Qué se ve en `docker ps -a` |
|---|---|---|
| creado (`created`) | `docker create`, o un `docker run` que no pudo arrancar | `Created` |
| corriendo (`running`) | `docker run` o `docker start` | `Up …` |
| detenido (`exited`) | `docker stop`, o el programa principal terminó solo | `Exited (código) …` |
| borrado | `docker rm` | ya no aparece |

Lo más importante de la tabla es la diferencia entre **detenido** y **borrado**. Un contenedor detenido no corre, pero existe: conserva su capa de escritura, su bitácora, su configuración y su nombre. Se puede volver a arrancar. Un contenedor borrado ya no existe, y con él se van su capa y su bitácora.

`fig02_07.sh` recorre el ciclo completo y termina con la revisión de limpieza:

```bash
#!/usr/bin/env bash
# fig02_07.sh — El ciclo de vida completo y la limpieza: stop, start, rm y --rm.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" curso-docker-efimero >/dev/null 2>&1 || true' EXIT
ms() { date +%s%3N; }

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Borrar un contenedor que está corriendo, sin -f"
docker rm "$NOMBRE"
echo "código de salida: $?"

echo
echo "== 2. Detenerlo, midiendo cuánto tarda"
inicio=$(ms); docker stop "$NOMBRE" >/dev/null; fin=$(ms)
echo "docker stop tardó $(( fin - inicio )) ms"
docker ps -a --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'
docker logs --tail 2 "$NOMBRE"

echo
echo "== 3. Detenido no es borrado: vuelve a arrancar con start"
docker start "$NOMBRE" >/dev/null
docker ps --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'

echo
echo "== 4. Ahora sí: borrarlo"
docker stop "$NOMBRE" >/dev/null
docker rm "$NOMBRE"

echo
echo "== 5. Un contenedor con --rm se borra solo al terminar"
# Lo que va después de la imagen reemplaza al comando por omisión: aquí, en vez
# de servir, el programa corre su subcomando healthcheck y termina.
docker run --rm --name curso-docker-efimero curso-docker-prueba:1.0.0 healthcheck
echo "código de salida: $?"
docker ps -a --filter name=curso-docker-efimero --format '{{.Names}}' | wc -l

echo
echo "== 6. La revisión final: ningún contenedor del curso"
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

```text
$ ./fig02_07.sh
== 1. Borrar un contenedor que está corriendo, sin -f
Error response from daemon: cannot remove container "curso-docker-prueba": container is running: stop the container before removing or force remove
código de salida: 1

== 2. Detenerlo, midiendo cuánto tarda
docker stop tardó 242 ms
curso-docker-prueba Exited (0) Less than a second ago
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando

== 3. Detenido no es borrado: vuelve a arrancar con start
curso-docker-prueba Up Less than a second (health: starting)

== 4. Ahora sí: borrarlo
curso-docker-prueba

== 5. Un contenedor con --rm se borra solo al terminar
no sano: Get "http://127.0.0.1:9000/": dial tcp 127.0.0.1:9000: connect: connection refused
código de salida: 1
0

== 6. La revisión final: ningún contenedor del curso
0
```

Los tiempos cambian en cada corrida; todo lo demás sale igual.

#### 2.10.2 `docker rm` no borra lo que corre

El primer bloque es una protección: Docker no te deja borrar un contenedor que está corriendo. El mensaje te da las dos salidas: detenerlo antes (*stop the container before removing*) o forzar el borrado (*force remove*). Forzar es `docker rm -f`, y la documentación dice qué hace: le manda `SIGKILL` al proceso principal y luego borra el contenedor ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)). `SIGKILL` es la señal 9, la que la Lección 0 te enseñó a reconocer en el código 137: no se puede atrapar, así que el programa no tiene oportunidad de cerrar nada. Para un contenedor de prueba que vas a tirar, está bien, y los `trap` de estos guiones lo usan. Para un servicio con datos, primero `stop`.

#### 2.10.3 `docker stop`: la señal y el plazo

`docker stop` es la forma educada. La documentación dice que le manda al proceso principal la señal `SIGTERM` (salvo que la imagen o el contenedor configuren otra), espera un plazo —por omisión, **10 segundos** en Linux— y, si el contenedor sigue vivo, lo mata con `SIGKILL`. El plazo se cambia con `--timeout` ([docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/)).

El segundo bloque muestra que el servicio de prueba se apaga bien. `docker stop` tardó **242 ms**, mucho menos que los 10 segundos del plazo (en otra corrida del curso tardó 120 ms, y en otra, 199). El estado es `Exited (0)`: el programa terminó por su cuenta y con código 0, que en Linux es «todo bien». Y la bitácora, que sigue ahí después de detenerlo, muestra por qué: `recibí terminated, apagando`. El servicio está escrito para atender `SIGTERM` (*terminated* es como Go nombra esa señal): la recibe, deja de aceptar peticiones y sale. Si el programa ignorara la señal, verías `docker stop` tardar 10 segundos y el estado `Exited (137)`. Por qué un programa a veces no recibe la señal, aunque esté escrito para atenderla, es un problema real con nombre propio, el del proceso número 1, y la Lección 7 lo trata.

#### 2.10.4 `docker start`: detenido no es borrado

El tercer bloque arranca otra vez el mismo contenedor con `docker start`. No hace falta repetir las opciones: el nombre, el puerto y los límites quedaron guardados en el contenedor. `docker start` sirve para continuar algo que detuviste; para cambiar una opción (otro puerto, otro límite) hay que borrar el contenedor y crear uno nuevo con `docker run`. El cuarto bloque hace la limpieza en orden: `stop` y luego `rm`, que imprime el nombre de lo que borró.

#### 2.10.5 `--rm`: contenedores que se borran solos

Para los contenedores que solo corren una tarea y terminan existe `--rm`: según la documentación, borra el contenedor, y sus volúmenes anónimos, automáticamente cuando termina (los volúmenes son tema de la Lección 8) ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). El quinto bloque lo usa con un detalle nuevo: después del nombre de la imagen va la palabra `healthcheck`. **Lo que escribes después de la imagen se le pasa al programa principal**, y aquí convierte al servicio en su propio cliente: en vez de servir, corre la revisión de salud y termina. Como dentro de ese contenedor nadie está sirviendo en el puerto 9000, la revisión falla con `connection refused` y código 1. Y el `0` de después dice que el contenedor ya no existe: `--rm` lo borró.

Un detalle medido al escribir esta lección: con `docker run -d --rm`, el borrado ocurre **un instante después** de que el contenedor se detiene, y no antes de que `docker stop` regrese. En una primera versión de este guion, que hacía `docker stop` de un contenedor `-d --rm` y contaba enseguida, el conteo dio `1`: el contenedor detenido seguía ahí unos milisegundos. Por eso el guion usa la forma sin `-d`, en la que `docker run` no regresa hasta que el contenedor terminó y se borró. Si alguna vez un guion tuyo cuenta contenedores justo después de detener uno con `--rm`, ya sabes de dónde sale el número de más.

### 2.11 No dejar basura

#### 2.11.1 Solo lo tuyo

El sexto bloque de `fig02_07.sh` es la revisión que vas a hacer al final de cada lección del curso:

```bash
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

`-a` incluye los detenidos, que son los que se olvidan. El filtro `name=^curso-docker-` deja solo los contenedores cuyo nombre **empieza** con `curso-docker-`: el `^` marca el principio del nombre. La documentación solo dice que el filtro coincide con todo o parte del nombre, así que se midió al escribir esta lección: en un equipo con diez contenedores cuyos nombres llevaban `dev-` en medio, `--filter name=dev-` encontró los diez y `--filter name='^dev'` no encontró ninguno. Sin el `^`, un filtro por `curso-docker-` también atraparía a un contenedor llamado, por ejemplo, `viejo-curso-docker-x`. Y `wc -l` cuenta renglones. Si sale `0`, no dejaste nada.

Para **borrar** todo lo tuyo de un golpe, la misma lista sirve de entrada a `docker rm -f`:

```bash
docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f
```

`-q` pide solo los identificadores ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)), `xargs` los pasa como argumentos al comando siguiente, y `-r` hace que `xargs` no corra nada si la lista está vacía.

Este es el motivo de fondo de la regla del curso de que **todo lo que creas empiece con `curso-docker-`**: te permite limpiar solo lo tuyo sin tocar nada más del equipo.

#### 2.11.2 El comando que no debes usar a ciegas

Tarde o temprano vas a leer en un tutorial `docker container prune`. Hace exactamente lo que dice su documentación: «borra **todos** los contenedores detenidos» ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). Todos: los tuyos, los de otros proyectos que tengas en el mismo equipo y los de cualquier herramienta que use Docker por debajo. Un contenedor detenido puede ser la base de datos de otro proyecto que dejaste apagada a propósito, con su configuración guardada en el contenedor. `prune` no pregunta de quién es; pregunta una sola vez «¿estás seguro?», y con `--force` ni eso. Admite filtros por etiqueta y por antigüedad, pero no por nombre ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). La propia documentación de `docker rm` lo recomienda para borrar todos los detenidos ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)); está bien en una máquina dedicada a una sola cosa. En la tuya, prefiere el filtro por nombre: borra lo que sabes que es tuyo. Lo mismo vale para sus parientes `docker system prune` y `docker volume prune`, que borran todavía más.

> [!NOTE]
> 🔧 **Observación de ingeniería 2.3**
> Limpiar no es un paso que se hace «al final, si da tiempo». En los guiones de esta lección, la limpieza se programa **antes** de crear nada, con `trap ... EXIT`, para que ocurra aunque el guion falle a la mitad. Es la misma idea en tu trabajo diario: decide cómo vas a borrar algo en el momento en que lo creas, no después.

## El error que vas a ver

Son dos, los de la escena del principio, y los dos los provoca `fig02_06.sh`:

```bash
#!/usr/bin/env bash
# fig02_06.sh — Los dos errores de todos los días: nombre repetido y puerto ocupado.
# Ojo con el segundo: el contenedor que falla SÍ queda creado.
set -uo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-otro >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null

echo "== 1. Otro contenedor con el MISMO nombre"
docker run -d --name curso-docker-prueba curso-docker-prueba:1.0.0
echo "código de salida: $?"

echo
echo "== 2. Otro contenedor en el MISMO puerto"
docker run -d --name curso-docker-otro -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. ¿Qué quedó?"
docker ps -a --filter name='^curso-docker-' --format 'table {{.Names}}\t{{.Status}}'
```

```text
$ ./fig02_06.sh
== 1. Otro contenedor con el MISMO nombre
docker: Error response from daemon: Conflict. The container name "/curso-docker-prueba" is already in use by container "c0117bd0d82f44831263964f4f0c3e80262188eee2be39287f270aef5b82cc4d". You have to remove (or rename) that container to be able to reuse that name.

Run 'docker run --help' for more information
código de salida: 125

== 2. Otro contenedor en el MISMO puerto
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint curso-docker-otro (482400ed3eb7fd3dab4753f6c5bf95038ed4b93f2b80fd70c3ac301e5f8059c2): Bind for 127.0.0.1:9000 failed: port is already allocated

Run 'docker run --help' for more information
1dad19130213
código de salida: 125

== 3. ¿Qué quedó?
NAMES                 STATUS
curso-docker-otro     Created
curso-docker-prueba   Up Less than a second (health: starting)
```

Los identificadores largos cambian en cada corrida; los mensajes y los códigos salen iguales. `${PIPESTATUS[0]}` es una variable de *bash* que guarda el código de salida del **primer** comando de una tubería; hace falta porque `$?` daría el del `cut`.

**El nombre repetido.** El mensaje dice todo: hay un conflicto (*Conflict*), el nombre `/curso-docker-prueba` ya lo usa el contenedor de tal identificador, y para reusar el nombre tienes que borrar o renombrar ese contenedor. Código **125**: falló Docker, no el servicio. Lo traicionero es que el contenedor que tiene el nombre **puede estar detenido**: no aparece en `docker ps`, solo en `docker ps -a`. El arreglo, en orden de preferencia: si el viejo ya no sirve, `docker rm` (o `docker rm -f` si corre); si lo quieres conservar, `docker rename <viejo> <nuevo>`; o usa otro nombre para el nuevo.

**El puerto ocupado.** Se lee de derecha a izquierda: la causa es `port is already allocated`, el puerto ya está tomado; el intento fue `Bind for 127.0.0.1:9000`, atarse a esa dirección y ese puerto; y quien lo intentaba era la configuración de red del contenedor `curso-docker-otro`. Otra vez **125**. Para saber quién tiene el puerto, `docker ps` en la columna PORTS; si no es un contenedor, `ss -ltnp` te dice qué programa del equipo lo está usando (la `p` pide el proceso; para ver procesos de otros usuarios hace falta `sudo`). El arreglo: detener al que lo tiene, o publicar el tuyo en otro puerto del anfitrión (`-p 127.0.0.1:9002:9000`), que no cambia nada dentro del contenedor.

**Y el detalle que nadie te cuenta.** Fíjate en el `1dad19130213` que aparece después del error del puerto: es el identificador de un contenedor. `docker run -d` lo imprimió porque **el contenedor sí se creó**; lo que falló fue arrancarlo. El tercer bloque lo confirma: `curso-docker-otro` quedó en estado `Created`. No corre, no gasta memoria, pero **retiene su nombre**. Si corriges el puerto y repites el comando con el mismo nombre, el siguiente error que vas a ver es el del nombre repetido, y vas a pensar que Docker se volvió loco. No: son dos errores encadenados. Después de un «puerto ocupado», borra el contenedor que quedó: `docker rm curso-docker-otro`. Y no intentes rescatarlo con `docker start` cuando el puerto se libere: el ejercicio 1 te muestra qué pasa.

El error del nombre repetido con un contenedor **detenido** y el del puerto con su contenedor fantasma son, juntos, la escena del principio. Con `docker ps -a` y el filtro de 2.11, salen en diez segundos.

## El hábito de seguridad de la lección

**Puertos publicados solo en `127.0.0.1`, límites desde el primer contenedor, y nunca `--privileged` ni el *socket* de Docker dentro de un contenedor.**

Los dos primeros ya los practicaste. Publicar en `127.0.0.1` evita que un contenedor de pruebas quede al alcance de cualquiera en tu red, y el cortafuegos no te cubre (2.8). Los límites evitan que un error en un contenedor tumbe a los demás programas de tu equipo (2.9).

El tercero se dice aquí porque en los tutoriales del día a día vas a encontrar comandos que lo violan, y conviene reconocerlos antes de pegarlos. La Lección 0 te enseñó que `--privileged` le da al contenedor todas las capacidades y acceso a los dispositivos del anfitrión ([Docker, «Running containers»](https://docs.docker.com/engine/containers/run/)): casi no queda pared. Y te enseñó que el daemon corre como `root` y que solo usuarios de confianza deben poder controlarlo ([Docker Engine security](https://docs.docker.com/engine/security/)), al punto de que el grupo `docker` equivale a `root` ([Docker, pasos posteriores a la instalación en Linux](https://docs.docker.com/engine/install/linux-postinstall/)). Montar el *socket* dentro de un contenedor —en los tutoriales se ve como `-v /var/run/docker.sock:/var/run/docker.sock`— le da a ese contenedor exactamente ese poder: puede pedirle al daemon que cree otro contenedor con la carpeta raíz de tu equipo montada, como `root`. Si un comando que vas a copiar trae cualquiera de las dos cosas, detente y pregúntate si de verdad lo necesitas. En este curso, nunca.

## Lo que se hace mal

**Publicar puertos sin dirección, «porque así viene en el ejemplo».** `-p 9000:9000` publica en todas las interfaces, y `ufw` no lo detiene. Escribe siempre `-p 127.0.0.1:9000:9000`, y cuando de verdad necesites que otra máquina llegue al contenedor, decídelo a propósito.

**Correr sin límites «porque es solo una prueba».** Las pruebas son justamente donde el programa tiene errores. `--memory`, `--cpus` y `--pids-limit` cuestan una línea.

**Leer `Up` como «está funcionando».** `Up` dice que el proceso existe. Lo viste en 2.4: el servicio contestaba `503` y Docker seguía diciendo `Up`. Para saber si atiende, pregúntale al servicio.

**Mirar solo `docker ps`.** Sin `-a` no ves los detenidos, que son los que retienen nombres y disco. Para revisar tu equipo, `docker ps -a`.

**Usar `docker exec` para arreglar.** Lo que cambies se va con el contenedor. Además, en las imágenes mínimas, como la del servicio de prueba, ni siquiera hay shell, y está bien que no lo haya.

**`docker rm -f` como reflejo.** Mata con `SIGKILL`, sin dejar que el programa cierre lo que tenga abierto. Para lo que tiene datos, primero `docker stop`.

**Borrar un contenedor que falló sin leer su bitácora.** La bitácora se va con él. Primero `docker logs --tail 50`, después `rm`.

**Limpiar con `prune` en un equipo compartido.** Borra lo de todos. Filtra por tu prefijo.

**Dejar el contenedor fantasma del puerto ocupado.** Queda en `Created` con su nombre tomado; bórralo antes de reintentar.

## Ejercicios

Los ejercicios 1 y 4 son de razonamiento; el 2 y el 3 se hacen en tu Mint. Escribe tus predicciones en la [bitácora](bitacora.md) antes de ver las soluciones.

### Ejercicio 1 — Predice `docker ps -a`

Partes de un equipo sin contenedores `curso-docker-`. Corres esto, en orden:

```bash
docker run -d --name curso-docker-a -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-b -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker stop curso-docker-a
docker run --rm --name curso-docker-c curso-docker-prueba:1.0.0 healthcheck
```

A estos comandos se les quitaron los límites para que quepan en la página y se lea mejor la secuencia; en tu equipo, agrégales `--memory 64m --cpus 0.5 --pids-limit 50`, que no cambian la respuesta.

1. ¿Cuáles de los cuatro comandos terminan con error, y con qué código?
2. ¿Qué contenedores aparecen en `docker ps -a --filter name=^curso-docker-`, y en qué estado?
3. Si ahora corres `docker start curso-docker-b`, ¿arranca? ¿Por qué?
4. ¿Qué dos comandos dejan el equipo limpio?

### Ejercicio 2 — Otro puerto, otro presupuesto

Arranca el servicio de prueba con estas condiciones: nombre `curso-docker-ejercicio`, que tú le hables por el puerto **9002** de tu equipo (solo desde tu equipo), y con **32 MiB** de memoria, un cuarto de CPU y 20 procesos como máximo. Después:

1. Comprueba con `curl` que contesta `sano` en el puerto 9002.
2. Predice qué van a decir `memoria=` y `cpus(nano)=` con la plantilla de `fig02_04.sh`, y compruébalo.
3. Predice qué dirá `docker stats --no-stream` en la columna del límite de memoria.
4. Ponlo en modo caído y comprueba que `docker ps` sigue diciendo `Up`.
5. Déjalo todo limpio.

### Ejercicio 3 — La bitácora como evidencia (proyecto)

Imagina que el `revisor` reportó a las 10:04 que el servicio de prueba estaba caído, y tú quieres saberlo sin depender del `revisor`. Arranca el servicio de prueba, hazle tres peticiones en modo sano, cámbialo a caído, hazle dos peticiones más y regrésalo a sano. Después, usando **solo** `docker logs` y sus opciones:

1. Muestra solo los últimos tres renglones.
2. Muestra la bitácora con la hora de cada renglón.
3. Muestra solo lo del último minuto.
4. Detén el contenedor y demuestra que la bitácora sigue ahí. Bórralo y demuestra que ya no.

### Ejercicio 4 — Explícaselo a quien lo hizo

Tu compañero de la escena del principio te dice: «Yo tengo `ufw` activo, así que publicar con `-p 9000:9000` no tiene nada de malo». En cinco frases como máximo, explícale por qué sí, y qué debió escribir. Usa las palabras *interfaz*, *127.0.0.1* y *cortafuegos*.

## Soluciones

### Solución 1

1. Falla el **segundo**: el puerto 9000 de `127.0.0.1` ya lo tiene `curso-docker-a`; termina con `port is already allocated` y código 125. El cuarto **no** es un error de Docker, pero sí termina con código **1**: el subcomando `healthcheck` no encuentra a nadie sirviendo dentro de ese contenedor (`connection refused`), igual que en el bloque 5 de `fig02_07.sh`.
2. Dos: `curso-docker-a` en `Exited (0)`, porque lo detuviste y el servicio se apaga bien con `SIGTERM`; y `curso-docker-b` en `Created`, el contenedor fantasma del puerto ocupado. `curso-docker-c` no aparece: tenía `--rm`, y `docker run` sin `-d` no regresa hasta que lo borró.
3. **Arranca, pero sin su puerto**, y esta es la respuesta que casi nadie predice. Se midió al escribir la lección, con Docker 29.2.1: `docker start curso-docker-b` terminó con código 0 y `docker ps` lo mostró `Up`, pero la columna PORTS salió **vacía**, `docker port` no imprimió nada y `curl` a `127.0.0.1:9000` no obtuvo respuesta. `docker inspect` mostraba la diferencia: en `.HostConfig.PortBindings` seguía pedido el `127.0.0.1:9000`, pero en `.NetworkSettings.Ports`, lo que de verdad quedó conectado, no había nada. Si predijiste «arranca y usa el 9000, que ya quedó libre», tu razonamiento era el lógico; el contenedor fantasma simplemente no se comporta así. Es una razón más para la regla de «El error que vas a ver»: después de un puerto ocupado, **borra** el contenedor que quedó en `Created` y créalo de nuevo con `docker run`, en vez de rescatarlo con `docker start`.
4. Uno para borrar y otro para comprobar: `docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f` y después `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l`, que debe imprimir `0`.

Los puntos 1, 2 y 3 se comprobaron corriendo esta misma secuencia en la máquina de las corridas.

### Solución 2

```bash
docker run -d --name curso-docker-ejercicio -p 127.0.0.1:9002:9000 \
  --memory 32m --cpus 0.25 --pids-limit 20 curso-docker-prueba:1.0.0
curl -s http://127.0.0.1:9002/
docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' curso-docker-ejercicio
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' curso-docker-ejercicio
curl -s -X POST http://127.0.0.1:9002/modo/caido
docker ps --filter name=curso-docker-ejercicio --format '{{.Names}} {{.Status}}'
docker rm -f curso-docker-ejercicio
```

1. Lo importante es el `-p 127.0.0.1:9002:9000`: el 9002 es **tuyo**, el 9000 sigue siendo el del servicio dentro del contenedor. Si escribiste `-p 127.0.0.1:9002:9002`, `curl` no obtiene respuesta, porque dentro del contenedor nadie escucha en el 9002.
2. `memoria=33554432`, que es 32 × 1024 × 1024, y `cpus(nano)=250000000`, un cuarto de mil millones: un cuarto de CPU. Son la misma cuenta de 2.7.1 con otros números.
3. La columna dirá `… / 32MiB`. Lo que va antes de la diagonal cambia; el límite no.
4. `Up`, con o sin la marca de salud. Al escribir la lección se midió: justo después de pasarlo a caído, `Up 2 seconds (health: starting)`; doce segundos después, `Up 14 seconds (unhealthy)`. Sigue diciendo `Up` aunque esté marcado como no sano. Docker se entera de la caída gracias a la revisión de salud que trae la imagen, no porque sepa por su cuenta lo que contesta el servicio.
5. `docker rm -f` está bien aquí: es un contenedor de práctica sin datos.

### Solución 3

```bash
docker run -d --name curso-docker-bitacora -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done
for i in 1 2 3; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/caido
for i in 1 2; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/sano
docker logs --tail 3 curso-docker-bitacora
docker logs --timestamps curso-docker-bitacora
docker logs --since 1m curso-docker-bitacora
docker stop curso-docker-bitacora
docker logs --tail 3 curso-docker-bitacora
docker rm curso-docker-bitacora
docker logs curso-docker-bitacora
```

1. Si pegaste el bloque de una vez, los tres últimos renglones son las dos peticiones en modo caído y el cambio a sano: `GET / en modo caido` dos veces y `modo cambiado a sano`. Si escribiste los comandos uno por uno y tardaste más de cinco segundos, entre ellos aparecen renglones `GET / en modo …` de la revisión de salud (2.5): no los pediste tú, los pidió Docker, y tu `--tail 3` va a ser distinto.
2. Con `--timestamps`, cada renglón empieza con la fecha y hora en que Docker lo recibió, en UTC (la `Z` del final lo indica), con nanosegundos: en la corrida de comprobación, `2026-10-21T08:39:45.967466997Z servicio-prueba: GET / en modo caido`. Con esa columna podrías contestar a qué hora exacta empezó la caída; recuerda convertirla a tu zona (en la Ciudad de México, resta 6 horas).
3. `--since 1m` muestra todo, si hiciste el ejercicio en menos de un minuto: el arranque, cada petición (incluida la del ciclo de espera) y cada cambio de modo, más un renglón por cada revisión de salud que haya ocurrido mientras tanto, así que el total crece con el tiempo que tardaste. Es la herramienta para «qué pasó desde las 10:00», cambiando `1m` por una hora.
4. Después de `docker stop`, la bitácora sigue ahí, y ahora su último renglón es `servicio-prueba: recibí terminated, apagando`: el apagado también quedó escrito. Después de `docker rm`, `docker logs` falla con `Error response from daemon: No such container: curso-docker-bitacora`: el contenedor ya no existe, y con él se fue su bitácora. Esa es la evidencia que perderías si borraras antes de leer.

### Solución 4

Una respuesta posible: «Sin dirección, `-p 9000:9000` publica el puerto en todas las **interfaces** de tu equipo, incluida la de la red inalámbrica, no solo en la tuya propia. Y el **cortafuegos** `ufw` no lo detiene, porque Docker escribe sus propias reglas de red y el tráfico del contenedor pasa antes de que `ufw` lo revise; la documentación de Docker lo advierte. Así que cualquiera en la red de la cafetería podía hablarle a tu contenedor. Lo que debiste escribir es `-p 127.0.0.1:9000:9000`: **127.0.0.1** es la interfaz que solo lleva a tu propio equipo. La protección está en el `-p`, no en el cortafuegos».

## Cómo sé que lo logré

Corre los siete guiones de [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia) en tu Mint, en orden (el `fig02_01.sh` construye la imagen que usan los demás; su bloque 1 solo muestra el error si la imagen todavía no existe), y compara tus salidas con las de esta lección. Lo que **no** se compara, porque cambia en cada corrida: los identificadores de contenedores e imágenes, los tiempos (`Up 2 seconds`, `3.08 s`, `242 ms`, los de la construcción), la memoria en uso que reporta `docker stats` y la memoria total de tu equipo, y `arm64` contra `amd64`. Todo lo demás debe salir igual. Marca cada punto:

- [ ] `docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'` imprime `curso-docker-prueba:1.0.0 15.1MB` (o un tamaño muy parecido en `amd64`).
- [ ] Con el servicio corriendo, `docker ps` muestra `127.0.0.1:9000->9000/tcp` en la columna PORTS, sin `0.0.0.0` ni `[::]`.
- [ ] `curl -s http://127.0.0.1:9000/` contesta `sano`; en modo caído, `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/` contesta `503`, y `docker ps` sigue diciendo `Up`.
- [ ] `docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}' curso-docker-prueba` imprime `memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532`.
- [ ] Provocaste y leíste los dos errores de `fig02_06.sh`, y sabes por qué después del segundo hay que borrar un contenedor en estado `Created`.
- [ ] `docker stop curso-docker-prueba` tarda menos de un segundo y deja `Exited (0)`; la bitácora termina en `recibí terminated, apagando`.
- [ ] Explicas, sin mirar, la diferencia entre detenido y borrado, y qué se pierde con cada uno.
- [ ] Al terminar, `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l` imprime `0`, y la imagen `curso-docker-prueba:1.0.0` **sigue** en `docker image ls`: la vas a necesitar.
- [ ] Anotaste en tu bitácora qué cambia entre `-p 9000:9000` y `-p 127.0.0.1:9000:9000`, comprobado con `ss -ltn`.

## Resumen

Responde sin mirar la lección:

1. ¿Qué significan los códigos de salida 125, 126 y 127 de `docker run`? ¿Cuál viste al correr una imagen que no existía, y cuál al pedir `sh` en el servicio de prueba?
2. ¿Qué pregunta contesta cada opción del comando `docker run -d --name … -p 127.0.0.1:9000:9000 --memory 64m --cpus 0.5 --pids-limit 50 …`?
3. ¿Qué diferencia hay entre `docker ps` y `docker ps -a`, y por qué importa para la limpieza?
4. ¿Por qué `docker ps` puede decir `Up` de un servicio que contesta `503`?
5. ¿Qué ve `docker logs` y qué no ve? ¿Qué le pasa a la bitácora con `stop` y con `rm`?
6. ¿Por qué falla `docker exec … sh` en el servicio de prueba, y por qué eso es bueno?
7. ¿Qué quiere decir `memoria=0` en `docker inspect`?
8. ¿Qué diferencia hay entre publicar en `127.0.0.1` y no poner dirección? ¿Por qué `ufw` no te protege?
9. ¿Qué hace `docker stop`, paso a paso, y en qué se distingue de `docker rm -f`?
10. ¿Cómo borras solo tus contenedores, y por qué no usas `docker container prune` en un equipo compartido?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [docker container run](https://docs.docker.com/reference/cli/docker/container/run/): `-d`, `--name`, `-p`, `--rm`, `--pids-limit`, el valor por omisión de `--pull` y la advertencia sobre los puertos publicados en todas las interfaces y `ufw`.
- [Docker, «Running containers»](https://docs.docker.com/engine/containers/run/): los códigos de salida 125, 126 y 127, y lo que hace `--privileged`.
- [docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/): `-a`, `-q`, el filtro por nombre y por estado, y los campos de `--format`.
- [docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/): qué entrega el comando y las opciones `--follow`, `--tail`, `--since` y `--timestamps`.
- [docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/): `-i`, `-t`, que solo funciona mientras corre el proceso principal y que el comando debe ser un ejecutable.
- [docker inspect](https://docs.docker.com/reference/cli/docker/inspect/): la información de bajo nivel y las plantillas con `--format`.
- [docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/): `--no-stream` y las columnas de memoria y procesos.
- [docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, el plazo de 10 segundos, `SIGKILL` y `--timeout`.
- [docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/): `--force` con `SIGKILL` y la recomendación de `prune`.
- [docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/): que borra todos los contenedores detenidos, y sus filtros.
- [docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/): la vista de referencia del comando.
- [Docker, «Port publishing and mapping»](https://docs.docker.com/engine/network/port-publishing/): la publicación en todas las direcciones por omisión, la advertencia de inseguridad y la publicación en `127.0.0.1`.
- [Docker, «Packet filtering and firewalls»](https://docs.docker.com/engine/network/packet-filtering-firewalls/): por qué el tráfico de un contenedor no pasa por las reglas de `ufw`.
- [Docker, «Resource constraints»](https://docs.docker.com/engine/containers/resource_constraints/): que no hay límites por omisión, el riesgo de quedarse sin memoria, el mínimo de `--memory` y el ejemplo de `--cpus`.
- [Docker Engine security](https://docs.docker.com/engine/security/): el daemon como `root` y por qué solo usuarios de confianza deben controlarlo.
- [Docker, pasos posteriores a la instalación en Linux](https://docs.docker.com/engine/install/linux-postinstall/): el grupo `docker` y sus privilegios equivalentes a `root`.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones y fechas de «Sobre las corridas» y la vista nueva de `docker image ls` desde la 29.0.
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **bitácora** (*logs*) | lo que el programa principal de un contenedor escribe en su salida estándar y de errores; la guarda Docker y la muestra `docker logs` |
| **código de salida** | el número con que termina un programa; 0 es «todo bien» |
| **contexto de construcción** | la carpeta que `docker build` usa para buscar el `Dockerfile` y los archivos que la receta copia |
| **distroless** | familia de imágenes base mínimas que solo traen lo indispensable para que corra un programa, sin shell |
| **estado de un contenedor** | creado, corriendo, detenido; borrado es que ya no existe |
| **etiqueta** (*tag*) | lo que va después de los dos puntos en el nombre de una imagen: `1.0.0` en `curso-docker-prueba:1.0.0` |
| **interfaz de red** | cada «puerta» de red de un equipo; `127.0.0.1` es la que solo lleva al propio equipo (*loopback*) |
| **publicar un puerto** | conectar un puerto del anfitrión con un puerto del contenedor, con `-p` |
| **`SIGTERM`** | la señal con la que se le pide a un programa que termine; se puede atender para apagarse en orden |
| **`SIGKILL`** | la señal 9, que mata un programa sin darle oportunidad de cerrar nada |

---

**Siguiente:** [Lección 3 — Tu primer Dockerfile](03-primer-dockerfile.md)
