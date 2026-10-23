# Lección 9 — Compose: el sistema completo

Es jueves, 5:40 de la tarde. Mañana a las 9:00 entra una practicante nueva al equipo y su primera tarea es levantar el `revisor` en su computadora para ver cómo trabaja. Le mandaste por chat lo que tú usas: seis comandos de la Lección 8, copiados de tu historial. Dos redes, un volumen, dos `docker run` de tres y cinco renglones, un `docker network connect`. A las 5:52 te responde con una captura: el `revisor` dice `FALLA` para el servicio de prueba, con un `no such host`. Revisas los comandos que copió y encuentras el problema: se saltó el `docker network connect`, el último, porque pensó que era opcional. Le explicas. A las 6:05 manda otra captura: ahora sale `OK`, pero el contenedor del `revisor` no tiene `--read-only` ni `--cap-drop ALL`, porque copió el `docker run` de la Lección 3, que estaba más arriba en el mismo chat. Y mañana tu jefe quiere que el reporte muestre tres servicios a la vez, uno sano, uno lento y uno caído, para enseñarlo en la junta. Eso son cuatro contenedores, con su orden de arranque, y alguien tendrá que acordarse de todo. Son las 6:10. La pregunta ya no es cómo se corre un contenedor, sino **cómo se escribe un sistema entero de forma que nadie tenga que acordarse de nada**. Esta lección existe para que mañana le mandes un solo archivo y un solo comando, y que lo que levante sea exactamente lo que tú probaste, endurecido, con su token fuera del archivo y con el reporte en su lugar.

**Tiempo:** 2 × 45 min

**Qué construyes:** un `compose.yaml` en tu carpeta `revisor/` que describe el sistema completo: el `revisor`, construido desde su Dockerfile, y tres copias del servicio de prueba (sana, lenta y caída) para que el reporte muestre `OK`, `LENTO` y `FALLA` sin tocar nada a mano. Las dos redes de la Lección 8 (una normal y una interna sin salida), el volumen del reporte, el token como secreto de Compose y todas las opciones de seguridad de las Lecciones 2 a 8, escritas una sola vez. Con `docker compose up -d --build` el sistema se levanta desde cero; con `docker compose down`, se apaga sin perder el reporte.

**Qué aprendes:** qué es Compose y qué es un proyecto; cómo se traduce cada opción de `docker run` a una clave del archivo; `docker compose config` para validar y para ver lo que Compose entendió; `up`, `ps`, `logs`, `stop` y `down`, y por qué pedir `up` dos veces no hace nada la segunda; cómo nombra Compose sus contenedores, redes y volúmenes; `depends_on` con `service_healthy` y por qué «arrancado» no es «listo»; los secretos de Compose y la trampa de sus permisos; las anclas de YAML y los campos `x-` para no repetir; `pull_policy: never`; el error de tres servicios que construyen la misma imagen y el de `--wait` con un servicio que falla a propósito; y qué es `docker init` y por qué no lo usamos.

**De dónde vienes.** De la [Lección 8](08-volumenes-y-redes.md) traes el estado final que esta lección pasa a un archivo: la imagen `curso-docker-revisor:1.5.0`, que guarda su reporte en `/datos` por omisión y trae esa carpeta con dueño `65532`; el volumen del reporte; la red normal por donde se publica el puerto y la red interna sin salida donde vive el servicio de prueba. De la [Lección 7](07-salud-y-ciclo-de-vida.md) traes las opciones endurecidas (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`, límites), la política de reinicio `unless-stopped` y una promesa: usar la salud para ordenar el arranque de varios servicios. De la [Lección 6](06-configuracion-y-secretos.md) traes el token en `secretos/revisor_token.txt`, con permisos `644` (un permiso que solo vale para un token de mentira: en 9.8.3 mides quién puede leerlo y en 9.8.4 lo cierras), y otra promesa: los secretos de Compose. Y de la [Lección 2](02-contenedores-dia-a-dia.md), la imagen `curso-docker-prueba:1.0.0` y la costumbre de publicar puertos solo en `127.0.0.1`. Tu carpeta tiene `revisor/` (con su `Dockerfile`, su `.dockerignore` y `secretos/`) y, al lado, `servicio-prueba/`.

**Qué no hace esta lección.** No cambia el Dockerfile: la imagen es la misma 1.5.0 de la Lección 8, solo que ahora la construye Compose. No enseña Docker Swarm ni los campos de `deploy` que solo tienen sentido en un clúster: este curso trabaja en un equipo, y el paso a varios equipos es el curso de Kubernetes. No usa perfiles, archivos de anulación (`compose.override.yaml`) ni `include`: son útiles cuando un proyecto crece, y con un solo archivo se aprende primero lo que todos ellos combinan. No usa `docker compose watch` ni montajes de código para desarrollo, porque el `revisor` aquí se entrega, no se programa. Y no publica la imagen en ningún registro: eso es la [Lección 10](10-entregar-la-imagen.md).

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4, la misma base de Linux Mint 22, el sistema de referencia del curso, con núcleo 6.8 y procesador `arm64`. Los guiones se corrieron **dentro** de esa máquina virtual, con Docker 29.2.1 (cliente y daemon), **Docker Compose v5.0.2** y Buildx v0.31.1, y con su carpeta de trabajo en el disco propio de Linux; eso importa en la sección 9.10, que trata de permisos de un archivo, porque las carpetas compartidas entre la Mac y la máquina virtual mienten con ellos. En tu Mint no existe ese problema. El curso se planeó con Docker Engine 29.8.2 y Compose v5.6.0 (medidas el 7 de octubre), y la versión más reciente de Engine publicada el día de las corridas era la 29.9.2, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)); no esperamos que nada de esta lección cambie entre esas versiones, pero las salidas se midieron con Compose v5.0.2: si tu versión da otro texto en un error, compáralo por su sentido. Comprueba las tuyas con `docker version` y `docker compose version`. **Los nombres.** Para no tocar lo tuyo, los guiones usan un proyecto de Compose propio, `curso-docker-fig09`, y sus propias imágenes, `curso-docker-revisor:fig09` y `curso-docker-prueba:fig09`; así nunca tocan tu proyecto `curso-docker`, tu `curso-docker-revisor:1.5.0` ni tu `curso-docker-prueba:1.0.0`, y al salir borran solo lo que crearon. Por eso en las salidas los contenedores se llaman `curso-docker-fig09-revisor-1` y no `curso-docker-revisor-1`, que es como se van a llamar en tu carpeta (la sección 9.4 explica de dónde sale cada parte del nombre). Además, como en la misma máquina corrían otras lecciones, los guiones se lanzaron con otro prefijo y otro puerto (las variables `PREFIJO` y `PUERTO` que traen); una función `nombres`, a la vista en cada guion, vuelve a escribir ese prefijo como `curso-docker-` y el puerto como `8080`, y con los valores por omisión no cambia nada. Lo que **sí** cambia de una corrida a otra, y se avisa donde aparece: los tiempos de la tabla del `revisor` (tapados con `<t>`, y por eso a veces la columna queda un espacio más a la izquierda o a la derecha), los segundos de `Up N`, el número del archivo temporal del reporte (`<n>`), las fechas, el orden de algunos eventos que ocurren a la vez, el servicio que nombra un error de validación y, en 9.11, en qué intentos y en cuál de los tres servicios ocurre el choque. Los programas están en [`programas/09-compose/`](../programas/09-compose), cada uno con su salida al lado, y `estado/` guarda los archivos del proyecto tal como quedan al terminar.

## Al terminar vas a poder

- Traducir los comandos `docker run`, `docker network create` y `docker volume create` de la Lección 8 a un `compose.yaml` sin `version:`, y explicar qué clave corresponde a cada opción.
- Validar el archivo con `docker compose config --quiet` y leer en `docker compose config` la forma larga de lo que escribiste corto.
- Levantar, mirar y apagar el sistema con `up -d --build`, `ps`, `logs`, `stop` y `down`, y predecir qué contenedores recrea Compose cuando cambias el archivo.
- Provocar y explicar el `500` de `read-only file system` cuando el `revisor` endurecido no tiene nada montado en `/datos`.
- Ordenar el arranque con `depends_on` y `condition: service_healthy`, y explicar por qué el `revisor` espera solo a la copia sana.
- Entregar el token como secreto de Compose, comprobar que no aparece en `docker inspect` ni en `docker compose config`, y diagnosticar el `permission denied` de un archivo en `600`.
- Medir quién puede leer el archivo del token con `644`, `600` y `640` (con `ls -l`, `stat` y una cuenta sin privilegios), y dejarlo con el permiso mínimo que aún deja trabajar al `revisor`.
- Reconocer el choque de tres servicios que construyen la misma etiqueta y el fallo de `up --wait` con un servicio caído a propósito, y elegir la alternativa correcta.

## El porqué antes del cómo

Lo que hiciste en la Lección 8 funciona, y es justo como debe aprenderse: cada pieza con su comando, para ver qué aporta. Pero tiene tres problemas que aparecen el día que alguien más lo usa, o el día que tú mismo lo usas tres semanas después.

El primero es que **el sistema vive en tu historial**. Seis comandos, en un orden que importa, con opciones que nadie escribe igual dos veces. La escena del principio no es exagerada: basta saltarse un `docker network connect` para que el `revisor` no encuentre al servicio de prueba, y basta copiar el `docker run` equivocado para perder el endurecimiento de la Lección 7 sin que nada avise. Un servicio que depende de que alguien recuerde seis comandos depende, en realidad, de la memoria de esa persona.

El segundo es que **el orden se hace a mano**. Las redes antes que los contenedores, el volumen antes que el `revisor`, el servicio de prueba antes que quien lo revisa. Y al apagar, al revés: primero los contenedores, porque una red o un volumen en uso no se borran. En la Lección 8 tú hacías ese orden; con cuatro contenedores en lugar de dos, y con uno que debe esperar a que otro esté **sano** y no solo corriendo, el orden ya no cabe en la cabeza.

El tercero es que **no hay forma de saber qué está corriendo comparado con lo que debería**. Si mañana cambias el modo de un servicio de prueba, ¿qué contenedores tienes que borrar y volver a crear? Con `docker run` la respuesta la das tú. Lo ideal es que una herramienta compare lo que pediste con lo que existe y toque solo lo que cambió.

Compose resuelve las tres cosas con una idea: **describir el sistema en un archivo, y dejar que una herramienta lo haga existir**. Su documentación lo define como «una herramienta para definir y ejecutar aplicaciones de varios contenedores» ([Docker, «Docker Compose»](https://docs.docker.com/compose/)). El archivo, `compose.yaml`, dice qué servicios hay, en qué redes viven, qué volúmenes y qué secretos usan, y con qué opciones corren. El comando `docker compose up` lee el archivo, compara con lo que ya existe y crea, recrea o deja en paz lo necesario, en el orden correcto. El archivo se guarda junto al código, se revisa como el código y se le manda a la practicante en lugar de seis comandos.

Con ese destino en mente, esto es lo que vas a tener al final, en la sección 9.9: el sistema completo levantado con un comando, y el reporte del `revisor` mostrando los tres comportamientos del servicio de prueba sin que hayas tocado nada a mano:

```text
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200
```

(Es el bloque 3 de `fig09_05.sh`; los espacios antes de `<t>` cambian con el tiempo que se tapó.) Esa tabla es la primera de las metas del curso: «`docker compose up` levanta todo desde cero y el reporte muestra el servicio de prueba caído como `FALLA`».

## Los conceptos

### 9.1 Qué es Compose, y qué es un proyecto

#### 9.1.1 Un *plugin*, un archivo, una especificación

Compose llega con la instalación de la Lección 1: el paquete `docker-compose-plugin` agrega el subcomando `docker compose` (con espacio). No es un programa aparte que tengas que instalar con `pip` ni un binario que descargues a mano; es una extensión del cliente `docker`, y por eso su versión se pregunta con `docker compose version`.

El archivo se llama `compose.yaml`. La documentación dice que la ruta por omisión es `compose.yaml` («preferida») o `compose.yml` en la carpeta de trabajo, y que Compose también acepta `docker-compose.yaml` y `docker-compose.yml` «por compatibilidad con versiones anteriores» ([Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/)). Este curso usa el nombre preferido.

Lo que va dentro del archivo no lo inventa Docker cada año: lo define la **especificación de Compose**, un documento público que describe cada clave y qué significa ([especificación de Compose](https://docs.docker.com/reference/compose-file/)). Los elementos de arriba que vas a usar hoy son cinco: `name`, `services`, `networks`, `volumes` y `secrets`. Hay otros que esta lección no usa: `configs` (archivos de configuración que no son secretos; el `revisor` se configura por variables y no lo necesita), `include` (para unir varios archivos) y `models` (que, según la especificación, «declara los modelos de IA que usa tu aplicación de Compose», [especificación, `models`](https://docs.docker.com/reference/compose-file/models/)); y `version`, que ya es obsoleto (9.2.3). La documentación los presenta así: los componentes de una aplicación «se definen como servicios», los servicios «se comunican entre sí a través de redes», y «guardan y comparten datos persistentes en volúmenes» ([Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/)).

#### 9.1.2 Un servicio no es un contenedor

Aquí está la primera idea nueva, y conviene no pasarla rápido. En la Lección 8 creabas **contenedores**: `curso-docker-revisor`, `curso-docker-prueba`. En Compose describes **servicios**: `revisor`, `prueba`. Un servicio es la receta («corre esta imagen, con estas opciones, en estas redes»); el contenedor es lo que sale de aplicar la receta. Normalmente un servicio da un contenedor, pero la diferencia importa por dos razones que vas a ver en la lección. Una: el nombre que conviene usar para encontrarlo por DNS es el del **servicio** (`prueba`), no el del contenedor. El nombre del contenedor también resuelve dentro de la red (se comprobó), pero lleva el nombre del proyecto y un número de réplica, que cambian de una carpeta a otra. Dos: cuando cambias la receta, Compose tira el contenedor viejo y crea uno nuevo; el servicio sigue siendo el mismo.

#### 9.1.3 El proyecto: el apellido de todo

Un **proyecto** es, según la documentación, «un despliegue individual de una especificación de aplicación» ([Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/)). En la práctica, es el nombre que Compose pone delante de todo lo que crea, para saber qué es suyo. El `compose.yaml` del curso empieza con `name: curso-docker`, y por eso todo lo que crea lleva ese nombre: contenedores, redes y volúmenes. Si no lo escribes, Compose usa el nombre de la carpeta donde está el archivo, que en tu caso sería `revisor`: un apellido demasiado genérico para que lo reconozcas entre otros proyectos.

El nombre del proyecto se puede fijar de cinco formas, y la documentación dice cuál gana: primero la opción `-p` de la línea de comandos; luego la variable de entorno `COMPOSE_PROJECT_NAME`; luego el `name:` del archivo; luego el nombre de la carpeta del archivo; y al final el nombre de la carpeta actual. Solo admite «letras minúsculas, dígitos decimales, guiones y guiones bajos» ([Docker, «Specify a project name»](https://docs.docker.com/compose/how-tos/project-name/)). Esa misma página dice para qué sirve: «Compose usa un nombre de proyecto para aislar los entornos entre sí». Los guiones de esta lección se aprovechan de eso: fijan `COMPOSE_PROJECT_NAME=curso-docker-fig09`, que le gana al `name:` del archivo, y así su corrida nunca se mezcla con tu proyecto `curso-docker`, aunque el archivo sea el mismo.

### 9.2 Del `docker run` al archivo

#### 9.2.1 El estado final de la Lección 8, escrito una vez

Lo concreto primero. Este es el estado final de la Lección 8, el de la sección 8.10.3, en un archivo. Guárdalo en tu carpeta `revisor/` con el nombre `compose.yaml`:

```yaml
# fig09_01.compose.yaml — Lección 9, primer paso: el estado final de la
# Lección 8 (sección 8.10.3), escrito en un archivo en vez de en seis comandos.
# Un solo servicio de prueba, sin token. Va en tu carpeta revisor/ como compose.yaml.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: "prueba http://prueba:9000/ 2s"
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      - prueba
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

  prueba:
    build: ../servicio-prueba
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}
```

Léelo de abajo hacia arriba, que es como Compose lo construye. Al final están las **redes** y el **volumen**: `publica`, `interna` (con `internal: true`, la `--internal` de la Lección 8) y `reportes`. Las llaves vacías `{}` dicen «con las opciones por omisión»: una red `bridge` y un volumen local. Arriba están los dos **servicios**. Cada servicio lista sus redes por el nombre corto (`publica`, `interna`) y monta el volumen por el nombre corto (`reportes:/datos`); Compose les pone el apellido del proyecto al crearlos. El servicio de prueba solo está en la `interna`; el `revisor`, en las dos. Exactamente como en 8.10.3, pero sin el paso del `docker network connect` que se le olvidó a la practicante: aquí no hay pasos, hay una descripción.

#### 9.2.2 Cada opción, su clave

Casi cada opción de `docker run` tiene una clave con un nombre parecido. Esta tabla es la que vas a usar para traducir cualquier comando de las lecciones anteriores:

| `docker run` | `compose.yaml` | Nota |
|---|---|---|
| `curso-docker-revisor:1.5.0` (la imagen) | `image:` | con `build:` al lado, es el nombre que recibe la imagen construida |
| `docker build --build-arg VERSION=1.5.0 .` | `build: { context: ., args: { VERSION: "1.5.0" } }` | Compose construye antes de crear el contenedor |
| `-e REVISOR_SERVICIOS=…` | `environment:` | como mapa (`CLAVE: valor`), sin comillas que lleguen al valor |
| `-p 127.0.0.1:8080:8080` | `ports: ["127.0.0.1:8080:8080"]` | la dirección `127.0.0.1` se escribe igual que en la Lección 2 |
| `-v curso-docker-reportes:/datos` | `volumes: [reportes:/datos]` + `volumes:` arriba | el volumen se declara una vez en el nivel superior |
| `--network …` y `docker network connect …` | `networks: [publica, interna]` + `networks:` arriba | todas las redes del servicio en una lista |
| `--read-only` | `read_only: true` | |
| `--cap-drop ALL` | `cap_drop: [ALL]` | |
| `--security-opt no-new-privileges` | `security_opt: ["no-new-privileges:true"]` | |
| `--init` | `init: true` | |
| `--memory 64m`, `--cpus 0.5`, `--pids-limit 50` | `mem_limit: 64m`, `cpus: 0.5`, `pids_limit: 50` | |
| `--restart unless-stopped` | `restart: unless-stopped` | aparece en el archivo final (9.9) |
| `--name curso-docker-revisor` | (nada) | el nombre lo pone Compose: proyecto, servicio y número |

La referencia de los servicios describe cada una con la misma intención que conociste en la Lección 7: `read_only` crea el contenedor «con un sistema de archivos de solo lectura»; `init` corre «un proceso init (PID 1) dentro del contenedor que reenvía señales y recoge procesos»; `cpus` define cuántas CPU, «potencialmente virtuales», se le asignan; y `pids_limit` ajusta el límite de procesos ([referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/)). No hay magia nueva: son las mismas opciones del daemon, escritas en otro lugar.

Hay dos claves de la tabla que merecen una frase más. La primera, `security_opt`: la referencia dice que las opciones booleanas como `no-new-privileges` se pueden escribir de tres formas equivalentes (`no-new-privileges`, `no-new-privileges=true` y `no-new-privileges:true`). El curso usa la última porque es la que menos dudas deja. La segunda, `depends_on: [prueba]`: no tiene equivalente en `docker run`, porque ordenar contenedores era trabajo tuyo. Le dice a Compose que el `revisor` se crea y arranca después de `prueba`. Más adelante (9.7) vas a ver que «después» no significa «cuando ya está listo».

#### 9.2.3 Sin `version:`

El archivo no empieza con `version: "3.8"` ni nada parecido, y no es descuido. La especificación dice que el elemento `version` existe solo por compatibilidad, que «es solo informativo» y que si lo usas vas a recibir «un aviso de que es obsoleto» ([especificación, `version` y `name`](https://docs.docker.com/reference/compose-file/version-and-name/)). Lo vas a ver en casi todos los tutoriales de hace unos años, porque el Compose antiguo lo exigía para saber qué claves aceptar. El de hoy aplica la especificación vigente en la versión que tengas instalada y no necesita ese campo. Si lo encuentras, bórralo.

### 9.3 Validar y leer lo que Compose entendió

#### 9.3.1 `docker compose config`

Antes de levantar nada, conviene saber si el archivo es válido y si Compose entendió lo que querías decir. Para eso existe `docker compose config`, que según su referencia «muestra el modelo de datos real que se aplicará en Docker Engine»: resuelve las variables y «expande la notación corta a la forma canónica» ([referencia de `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/)). Tres opciones lo hacen útil en el día a día: `--quiet` solo valida y no imprime nada (si el archivo está mal, el error sale y el código no es 0); `--services` lista los servicios, uno por renglón; y `--volumes`, los volúmenes.

El guion `fig09_02.sh` toma tu primer `compose.yaml` y lo pasa por todo el ciclo: validar, leer, levantar, volver a pedir y apagar. Es el primer guion de la lección, así que aquí va completo; los siguientes repiten el mismo arranque (los nombres de apoyo, la carpeta de trabajo y las funciones `muestra`, `eventos`, `esperar` y `tabla`) y en la lección solo se muestra la parte que cambia:

```bash
#!/usr/bin/env bash
# fig09_02.sh — El primer compose.yaml (fig09_01): validarlo, leer lo que Compose
# entiende, levantarlo, pedir el reporte, volver a pedir «up» y apagarlo.
# Construye sus propias imágenes de apoyo; no usa ni toca las tuyas.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig09»: el proyecto de Compose se llama curso-docker-fig09
# y las imágenes curso-docker-revisor:fig09 y curso-docker-prueba:fig09. Así el
# guion nunca toca tu proyecto curso-docker, tu curso-docker-revisor:1.5.0 ni tu
# curso-docker-prueba:1.0.0, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig09.XXXXXX")"
export COMPOSE_PROJECT_NAME="${PREFIJO}fig09"   # gana sobre el «name:» del archivo
trap 'cd "$TRABAJO/revisor" 2>/dev/null && docker compose down --volumes --remove-orphans >/dev/null 2>&1
      docker rmi -f "${PREFIJO}revisor:fig09" "${PREFIJO}prueba:fig09" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso, el estado de la Lección 8 (con el
# token de la Lección 6) y el compose.yaml de fig09_01.compose.yaml, con los nombres de apoyo
# y el puerto del guion.
mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
cp -R "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$AQUI/estado/secretos" "$TRABAJO/revisor/"
chmod 644 "$TRABAJO/revisor/secretos/revisor_token.txt"   # 644: solo porque el token es de mentira (9.8.4)
sed -e "s/curso-docker-revisor:1.5.0/${PREFIJO}revisor:fig09/" \
    -e "s/curso-docker-prueba:1.0.0/${PREFIJO}prueba:fig09/" \
    -e "s/127.0.0.1:8080:8080/127.0.0.1:${PUERTO}:8080/" \
    "$AQUI/fig09_01.compose.yaml" > "$TRABAJO/revisor/compose.yaml"
cd "$TRABAJO/revisor"
TOKEN="$(cat secretos/revisor_token.txt)"   # se lee del archivo; nunca se escribe

# Si corres el guion con otro PREFIJO o PUERTO, la salida se escribe con los del
# curso. Con los valores por omisión esto no cambia nada.
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/127.0.0.1:${PUERTO}->/127.0.0.1:8080->/g" \
                -e "s/127.0.0.1:${PUERTO}\//127.0.0.1:8080\//g" -e "s/published: \"${PUERTO}\"/published: \"8080\"/"; }
# muestra COMANDO: lo imprime con «$ », lo corre y dice el código si no fue 0
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# eventos: de lo que imprime Compose, solo los renglones «Objeto nombre Estado»
eventos() { grep -E '^ *(Image|Network|Volume|Container) ' | sed -E 's/^ +//; s/ +$//'; }
# esperar SERVICIO ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar() {
  for _ in $(seq 60); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "${COMPOSE_PROJECT_NAME}-$1-1" 2>/dev/null)" = "$2" ] && return 0
    sleep 1
  done
  echo "($1 no llegó a $2)"; return 1
}
# tabla: el reporte en forma de tabla, con el token y con los tiempos tapados
tabla() { curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'; }

echo "== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config --volumes"

echo
echo "== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto"
muestra "docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'"
muestra "docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'"

echo
echo "== 3. Levantarlo todo"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s 'http://127.0.0.1:${PUERTO}/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'"

echo
echo "== 4. Pedir «up» otra vez, sin cambiar nada"
muestra "docker compose up -d 2>&1 | eventos"

echo
echo "== 5. Apagar: down borra contenedores y redes; el volumen se queda"
muestra "docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
```

Y su salida:

```text
$ ./fig09_02.sh
== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba
revisor
$ docker compose config --volumes
reportes

== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto
$ docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'
    depends_on:
      prueba:
        condition: service_started
        required: true
    environment:
      REVISOR_SERVICIOS: prueba http://prueba:9000/ 2s
--
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 8080
        published: "8080"
        protocol: tcp
--
    volumes:
      - type: volume
        source: reportes
        target: /datos
        volume: {}
networks:
$ docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'
  prueba:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  revisor:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  interna:
    internal: true
  publica:
  reportes:

== 3. Levantarlo todo
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-prueba:fig09 Built
Image curso-docker-revisor:fig09 Built
Network curso-docker-fig09_interna Created
Network curso-docker-fig09_publica Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-1 Started
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200

== 4. Pedir «up» otra vez, sin cambiar nada
$ docker compose up -d 2>&1 | eventos
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Running

== 5. Apagar: down borra contenedores y redes; el volumen se queda
$ docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'
Container curso-docker-fig09-revisor-1 Stopped
Container curso-docker-fig09-revisor-1 Removed
Container curso-docker-fig09-prueba-1 Stopped
Container curso-docker-fig09-prueba-1 Removed
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
```

#### 9.3.2 Leer los bloques 1 y 2

1. **Válido, con dos servicios y un volumen.** `config --quiet` no imprime nada si el archivo está bien; el `echo` del guion lo dice por él. Fíjate en que `prueba` sale antes que `revisor`, aunque en el archivo lo escribiste después. Compose no lista por el orden en que escribiste: primero salen las dependencias y al final quien depende de ellas, y eso lo decide `depends_on`. (Lo vas a ver más claro en 9.9, con cuatro servicios: las tres copias del servicio de prueba primero, entre ellas en orden alfabético, y el `revisor` al final. Lo que sí varía de una corrida a otra es el orden de los eventos de `up`, porque varias cosas ocurren a la vez.)
2. **La forma larga.** Aquí está lo que de verdad le interesa saber a quien revisa un archivo ajeno. Tu `depends_on: [prueba]` se volvió `condition: service_started` y `required: true`: la forma corta es la forma larga con los valores por omisión. Tu `"127.0.0.1:8080:8080"` se volvió un bloque con `host_ip: 127.0.0.1`, `target: 8080` (el puerto del contenedor) y `published: "8080"` (el de tu equipo): si alguna vez dudas de cuál número es cuál, `config` te lo dice con nombres. Tu `reportes:/datos` se volvió `type: volume`, `source: reportes`, `target: /datos`. Y en el segundo comando, `mem_limit: 64m` aparece como `"67108864"`, que son 64 × 1024 × 1024 bytes, el mismo número que `docker inspect` te mostró en la Lección 2. `config` es la mejor herramienta para revisar un `compose.yaml` que no escribiste: no te dice lo que el autor quiso, te dice lo que va a pasar.

Una costumbre que conviene adoptar desde hoy: **cada vez que edites el archivo, corre `docker compose config --quiet` antes de `up`**. Un error de sangría en YAML cambia el significado sin dar error de sintaxis (una clave que quedó dentro del servicio equivocado, por ejemplo), y `config` es donde lo ves antes de que el contenedor arranque con otra configuración.

### 9.4 Levantar, mirar y apagar

#### 9.4.1 `up`: crear lo que falta, en orden

`docker compose up` es el comando central. Su referencia lo resume en una línea: «construye, (re)crea, arranca y se conecta a los contenedores de un servicio» ([referencia de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Con `-d` («modo separado») deja los contenedores en segundo plano y te devuelve la terminal; con `--build`, construye las imágenes antes de arrancar, aunque ya existan.

El bloque 3 de `fig09_02.sh` muestra lo que hizo, en el orden en que lo hizo. Primero las **dos imágenes**, `Built`. Después las **redes**, `curso-docker-fig09_interna` y `curso-docker-fig09_publica`, y el **volumen**, `curso-docker-fig09_reportes`. Después los **contenedores**: `Created` los dos, y `Started` primero `prueba` y luego `revisor`, porque el `revisor` depende de él. Es el orden que en la Lección 8 hacías a mano, ahora decidido por el archivo. (El guion quita del listado los renglones intermedios, como `Building`, `Creating` o `Starting`, para que se lean los resultados; en tu terminal los vas a ver todos.)

#### 9.4.2 Cómo se llaman las cosas

Mira los nombres con cuidado, porque los vas a escribir en `docker inspect`, en `docker logs` y en el ayudante de `alpine`:

- **Contenedores**: `<proyecto>-<servicio>-<número>`. En la salida, `curso-docker-fig09-revisor-1`; en tu carpeta, con `name: curso-docker`, `curso-docker-revisor-1`. El número existe porque un servicio puede tener varias réplicas; aquí siempre es `1`.
- **Redes y volúmenes**: `<proyecto>_<nombre>`, con guion bajo. `curso-docker-fig09_interna`, `curso-docker-fig09_reportes`; en tu carpeta, `curso-docker_interna` y `curso-docker_reportes`.

Como el proyecto empieza con `curso-docker`, todo sigue teniendo el prefijo del curso, y la costumbre de la Lección 2 (poder borrar lo del curso sin tocar lo demás) se mantiene. Además, Compose pone en cada cosa que crea la etiqueta `com.docker.compose.project=<proyecto>`. Es la forma limpia de preguntar «qué es de este proyecto», y el bloque 5 la usa: `docker volume ls --filter label=com.docker.compose.project=…`.

Y una pregunta que seguramente te estás haciendo: si el contenedor se llama `curso-docker-fig09-prueba-1`, ¿por qué el `revisor` lo busca como `http://prueba:9000/`? Porque en las redes de un proyecto, cada contenedor se registra en el DNS integrado (el `127.0.0.11` de la Lección 8) con el nombre de su **servicio** y también con el suyo propio; en una prueba aparte, los dos nombres resolvieron a la misma dirección. El del servicio es el que conviene escribir, porque es el único que no depende del proyecto ni del número de réplica. La documentación lo explica con su ejemplo: el contenedor del servicio `web` se une a la red «con el nombre `web`» ([Docker, «Networking in Compose»](https://docs.docker.com/compose/how-tos/networking/)). Eso te permite escribir `REVISOR_SERVICIOS` sin saber cómo se va a llamar el proyecto: el mismo archivo funciona en tu carpeta, en la de la practicante y en el guion.

La misma página dice qué pasa si no declaras redes: Compose crea **una** red, `<proyecto>_default`, y conecta ahí a todos los servicios. Tu archivo declara las suyas, y por eso en la salida no hay ninguna `_default`. No es un detalle: con la red por omisión de Compose, el servicio de prueba tendría salida a internet, y la Lección 8 decidió que no la necesita.

#### 9.4.3 `ps`: lo que hay, y cómo está

`docker compose ps` es el `docker ps` del proyecto: solo muestra sus contenedores. El bloque 3 lo usa con un formato propio (nombre, estado y puertos) y tapa los segundos de `Up` con `Up N`. Los dos están `(healthy)`, porque las dos imágenes traen su `HEALTHCHECK` desde las Lecciones 2 y 7, y el puerto del `revisor` está en `127.0.0.1:8080`. El servicio de prueba no publica nada: no lo necesita, el `revisor` le habla por la red interna. Y la tabla del `revisor` dice `prueba OK`.

#### 9.4.4 Pedir `up` otra vez: no pasa nada, y eso es lo bueno

El bloque 4 vuelve a correr `docker compose up -d`, sin cambiar nada. Compose responde `Running` para los dos y no toca ninguno. Esta es la diferencia más importante con un guion de `docker run`: un guion repetido intenta crear de nuevo y choca con el nombre repetido de la Lección 2. Compose, en cambio, **compara** lo que pides con lo que hay. La referencia de `up` lo dice así: si la configuración o la imagen de un servicio cambiaron, Compose «toma los cambios deteniendo y recreando los contenedores», y conserva los volúmenes montados ([referencia de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Si nada cambió, nada se toca. Por eso `docker compose up -d` es seguro de repetir: es la forma de decir «que exista esto», no «crea esto».

#### 9.4.5 `down`: el volumen se queda

El bloque 5 apaga con `docker compose down`. Detiene y borra los contenedores (primero el `revisor`, que depende de `prueba`; Compose apaga en el orden inverso de las dependencias) y borra las redes. Y el volumen **se queda**: `docker volume ls` lo sigue mostrando. La referencia de `down` lista lo que borra por omisión: los contenedores de los servicios, las redes de la sección `networks` y la red por omisión si se usó ([referencia de `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/)). Los volúmenes con nombre no están en esa lista; para borrarlos hay que pedirlo con `--volumes`, que borra «los volúmenes con nombre declarados en la sección `volumes`». Es la decisión correcta: apagar el sistema no debería costarte el reporte. En 9.12 lo vas a ver sobrevivir.

### 9.5 El error: el `revisor` endurecido sin nada en `/datos`

#### 9.5.1 Provocarlo

Desde la imagen 1.5.0 de la Lección 8, el `revisor` guarda su reporte en `/datos/reporte.json` **por omisión**: la imagen trae `REVISOR_REPORTE=/datos/reporte.json` en su `ENV`. Y el `compose.yaml` lo corre con `read_only: true`. ¿Qué pasa si alguien, al pasar el archivo en limpio, borra el renglón del volumen porque «el reporte no lo usamos»? El guion `fig09_03.sh` lo hace a la vista, con `sed`, y muestra la diferencia con `diff` antes de levantar. La parte del guion que cambia respecto de `fig09_02.sh`:

```bash
cp compose.yaml compose.bueno.yaml

echo "== 1. Sin el volumen en /datos"
# Borra el renglón «volumes:» del revisor y el que le sigue («- reportes:/datos»).
sed -i '/^    volumes:$/{N;d;}' compose.yaml
muestra "diff compose.bueno.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'"

echo
echo "== 2. Con el volumen: Compose recrea SOLO el revisor"
cp compose.bueno.yaml compose.yaml
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'"
esperar revisor healthy
muestra "curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
```

```text
$ ./fig09_03.sh
== 1. Sin el volumen en /datos
$ diff compose.bueno.yaml compose.yaml
19,20d18
<     volumes:
<       - reportes:/datos
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]

== 2. Con el volumen: Compose recrea SOLO el revisor
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Recreate
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
```

#### 9.5.2 Leerlo

1. **El `diff`** muestra los dos renglones que faltan (y sale con `1`, que en `diff` significa «hay diferencias», no «falló»). El archivo sigue siendo válido: un servicio sin volúmenes es perfectamente legal, y por eso `config --quiet` no te salvaría aquí. El contenedor arranca y llega a `(healthy)`, porque `/salud` no escribe nada. Docker está contento.
2. **Pero el reporte da `500`**: `open /datos/.reporte-<n>.tmp: read-only file system`. Es el error de la sección 7.7 de la Lección 7, en otra carpeta: el `revisor` intenta crear su archivo temporal en `/datos`, y `/datos` es parte del sistema de archivos del contenedor, que es de solo lectura. No hay nada montado encima que acepte escrituras. Fíjate en que el `revisor` no se cae ni finge: contesta `500` con la causa exacta. Es el segundo criterio del curso funcionando: el contenedor está `healthy` y el servicio no hace lo que debe.
3. **El arreglo**, devolver los dos renglones, y la segunda lección de Compose del día. `up -d` crea el volumen que ahora sí se usa (`Volume … Created`), deja el servicio de prueba como estaba (`Running`) y **recrea solo el `revisor`** (`Recreate`, `Recreated`, `Started`), porque su configuración cambió. El reporte vuelve a `200`.

La regla que te llevas: **con `read_only: true`, cada carpeta donde el programa escribe necesita algo montado encima**. En el `revisor` es una sola, `/datos`, y el archivo del curso siempre la monta. Si algún día cambias `REVISOR_REPORTE` a otra ruta, esa ruta también necesita su volumen (o su `tmpfs`, si no debe durar).

### 9.6 Tres copias del servicio de prueba sin escribir tres veces lo mismo

#### 9.6.1 Por qué tres

Con un solo servicio de prueba, el reporte siempre dice `OK`, a menos que cambies su modo a mano con `POST /modo/caido`. Pero el servicio de prueba vive en una red interna y no publica puerto: para cambiarle el modo tendrías que entrar por otro lado. Hay una forma mejor de enseñar los tres comportamientos a la vez, y es la que pidió el jefe de la escena: **tres contenedores de la misma imagen, cada uno arrancado en un modo distinto** con `PRUEBA_MODO`. Así el reporte muestra `OK`, `LENTO` y `FALLA` en cuanto el sistema arranca, sin tocar nada.

Tres servicios casi iguales significan el mismo bloque de opciones endurecidas escrito tres veces, y un bloque repetido es un bloque que algún día alguien cambia en dos de las tres copias. Compose tiene dos herramientas para eso, y se usan juntas.

#### 9.6.2 Campos `x-` y anclas de YAML

La primera es una regla de Compose: los campos de primer nivel que empiezan con `x-` se ignoran. La documentación lo dice tal cual: «Compose ignora cualquier campo que empiece con `x-`», y es «la única excepción» en la que ignora en silencio un campo que no reconoce; sirven para «modularizar configuraciones que quieres reutilizar» ([especificación, extensiones](https://docs.docker.com/reference/compose-file/extension/)).

La segunda no es de Compose sino de YAML: las **anclas** y los **alias**. Un ancla se pone con `&nombre` delante de un bloque; un alias, `*nombre`, se refiere a ese bloque; y la clave de mezcla `<<: *nombre` copia las claves del bloque dentro de otro mapa, donde puedes agregar o reemplazar las que quieras. La documentación de Compose avisa de dos detalles: la mezcla «solo aplica a mapas, y no se puede usar con secuencias», y cuando se usan fragmentos, las variables de entorno van como mapa (`CLAVE: valor`) y no como lista (`- CLAVE=valor`) ([especificación, fragmentos](https://docs.docker.com/reference/compose-file/fragments/)). Por eso todo el `environment` del curso está escrito como mapa.

Juntas se ven así, en un fragmento del archivo final:

```yaml
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true

services:
  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento
```

`x-prueba` no es un servicio (Compose lo ignora), pero su contenido existe para YAML con el ancla `&prueba`. `prueba-lento` copia todo ese bloque con `<<: *prueba` y agrega su `environment`. El bloque 1 de `fig09_05.sh`, más abajo, te lo demuestra pidiéndole a `config` el servicio `prueba-lento`: aparecen `image`, `pull_policy`, `read_only`, `mem_limit` y `networks`, que no están escritos en el servicio sino en el ancla.

#### 9.6.3 Quién construye, y `pull_policy: never`

Queda una decisión: ¿quién construye la imagen `curso-docker-prueba:1.0.0`? Si el ancla llevara `build: ../servicio-prueba`, las tres copias la heredarían, y Compose lanzaría **tres construcciones a la vez de la misma etiqueta**. Eso choca, y en 9.11 lo vas a provocar. El archivo final hace otra cosa: solo `prueba-sano` lleva `build`. Las otras dos usan la imagen que construye la primera.

Y para que esas dos no salgan a buscarla a internet, el ancla lleva `pull_policy: never`. La referencia lo define así: con `never`, Compose «no descarga la imagen de un registro y se basa en la imagen guardada en la plataforma» ([referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/)). ¿Qué pasa sin esa línea? Lo vas a medir en el bloque 2 de `fig09_07.sh` (sección 9.11): en una máquina donde la imagen aún no existe, Compose primero va a buscarla a Docker Hub por cada servicio que no la construye, recibe dos veces el `pull access denied` de la Lección 2, y entonces, como otro servicio del proyecto sí la construye, sigue adelante, la construye y levanta todo. Funciona, pero hace consultas a internet que no necesitas, llena la salida de errores que no lo son, y deja el resultado en manos de lo que alguien haya publicado con ese nombre. Con `pull_policy: never`, el nombre de la imagen deja de ser una pregunta a internet y se vuelve una referencia a algo que tú construiste.

Una consecuencia que conviene saber: como solo `prueba-sano` construye, pedir un servicio suelto en un equipo donde la imagen aún no existe (por ejemplo, `docker compose up prueba-lento` recién clonado el proyecto) no tiene quién la construya. En una prueba aparte con una imagen inexistente y `pull_policy: never`, Compose terminó con código `1` y el mensaje `No such image`. Levanta el proyecto completo con `docker compose up -d --build`, o construye primero con `docker compose build prueba-sano`.

### 9.7 «Arrancado» no es «listo»: `depends_on` con condición

#### 9.7.1 Lo que `depends_on` hace por omisión

En el primer archivo escribiste `depends_on: [prueba]`, y `config` te enseñó que eso es `condition: service_started`. La documentación es muy clara sobre lo que significa: «Al arrancar, Compose no espera a que un contenedor esté "listo", solo a que esté corriendo» ([Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/)). Es la misma confusión de la Lección 7 llevada al orden de arranque: el proceso existe, pero quizá todavía no atiende.

#### 9.7.2 Las tres condiciones

La forma larga de `depends_on` acepta tres condiciones ([referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/)):

| Condición | Compose espera a que la dependencia… |
|---|---|
| `service_started` | esté corriendo (es lo que hace la forma corta) |
| `service_healthy` | esté «sana», según su `healthcheck` |
| `service_completed_successfully` | termine con éxito (para tareas de un solo uso, como preparar algo antes) |

La de esta lección es `service_healthy`: «Compose espera a que pasen las revisiones de salud de las dependencias marcadas con `service_healthy`» ([Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/)). Para eso la dependencia necesita una revisión de salud, y el servicio de prueba la trae en su imagen desde la Lección 2 (cada 5 s, con 2 reintentos). Es la promesa de la Lección 7: la salud no reinicia nada, pero alguien la usa. Hoy la usa Compose.

#### 9.7.3 Por qué el `revisor` espera solo a la sana

Aquí está la decisión más fina del archivo, y merece leerse despacio. El `revisor` depende de las tres copias, pero **no** con la misma condición:

```yaml
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
```

Piensa qué pasaría si las tres fueran `service_healthy`. `prueba-caido` responde `503` siempre: su revisión de salud **nunca** pasa, así que Compose esperaría a que Docker la declare `unhealthy` (con 2 reintentos cada 5 s, unos diez segundos) y entonces se rendiría: en una prueba aparte con una dependencia que siempre falla (revisión cada 2 s, 2 reintentos), `docker compose up -d` terminó a los 5 s con código `1` y el mensaje `dependency failed to start: container ... is unhealthy`, y el servicio que dependía de ella quedó en `Created`, sin arrancar. Es el mismo error que verás en 9.11.3. El resultado es el mismo: el `revisor` nunca arrancaría. Y `prueba-lento` tampoco: su revisión exige respuesta en menos de 2 segundos, y en modo lento tarda 3. Los servicios que fallan a propósito no pueden ser sanos, porque fallar es su trabajo. Lo que el `revisor` necesita es que **existan** (para que su nombre esté en el DNS) y que al menos uno esté listo para que el primer reporte tenga algo que decir. Por eso: la sana, `service_healthy`; las otras, `service_started`.

Esa es la regla general, y la vas a usar en todos tus proyectos: **`service_healthy` para lo que tu servicio necesita sano para arrancar (una base de datos, por ejemplo), y `service_started` para lo que solo necesita que exista**. Y una advertencia honesta: `depends_on` solo ordena el **arranque**. Si una dependencia se cae una hora después, Compose no detiene ni reinicia al que dependía de ella. El `revisor` lo maneja bien porque su trabajo es justamente reportar a quien no responde.

### 9.8 Secretos de Compose

#### 9.8.1 Qué son y dónde aparecen

En la Lección 6 montaste el token con un `--mount type=bind` de un solo archivo, en `/run/secrets/revisor_token`, y dijiste a dónde apuntaba con `REVISOR_TOKEN_ARCHIVO`. Compose tiene un elemento para eso. Su documentación define un secreto como «cualquier dato, como una contraseña, un certificado o una clave de API» que no debería viajar sin protección, y dice dónde aparece: los secretos «se montan como un archivo en `/run/secrets/<nombre_del_secreto>` dentro del contenedor» ([Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/)). Por eso el `revisor` usa esa ruta desde la Lección 6: es la convención de Compose.

Se declaran en dos lugares, como las redes y los volúmenes. Arriba, de dónde sale:

```yaml
secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

Y en el servicio, quién lo recibe:

```yaml
    secrets:
      - revisor_token
```

Esa segunda parte importa: «los servicios solo pueden acceder a los secretos cuando se les concede explícitamente con un atributo `secrets`» ([Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/)). Las tres copias del servicio de prueba no lo reciben, y por eso no lo ven. El valor nunca se escribe en el archivo: el `compose.yaml` dice **dónde** está el token, no **cuál** es. Así el archivo puede ir al repositorio y `secretos/` no: son dos archivos de exclusión, uno por destino. El `.dockerignore` lo deja fuera de la imagen (ya lo hace desde la Lección 6) y el `.gitignore` lo deja fuera del repositorio (9.8.4). El material de este curso sí lleva su carpeta `secretos/` dentro del repositorio, a propósito, porque su token es de mentira; la tuya, con un token de verdad, no.

#### 9.8.2 La trampa: los permisos son los del archivo

Lo siguiente es lo más importante de esta sección, porque es un error que la documentación explica en una nota y que casi nadie lee. La forma larga de un secreto en el servicio acepta `uid`, `gid` y `mode`, y parecen la solución perfecta: «que el archivo dentro del contenedor sea del usuario 65532, con permiso `0400`». Pero **cuando el secreto sale de un archivo, Compose los ignora**. La referencia lo dice así: con un archivo como fuente, Compose usa por debajo un montaje que no permite cambiar el dueño, «y estos atributos se ignoran en silencio»; solo funcionan cuando el secreto sale de una variable de entorno ([referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/)).

En la práctica, eso quiere decir que el secreto de Compose es **el mismo montaje de la Lección 6**, con el dueño y los permisos que el archivo tenga en tu equipo. Si el archivo está en `600`, solo tu usuario lo lee; el `revisor` corre como `65532`; el resultado es `permission denied` y el `revisor` sale con código 1. Si está en `644`, lo lee. Lo vas a provocar en 9.10, con `uid`, `gid` y `mode` declarados, para que veas que no cambian nada. Por eso el curso usa la forma corta (`- revisor_token`): escribir `uid`, `gid` y `mode` con un secreto de archivo no sirve más que para dar una falsa sensación de seguridad.

La consecuencia práctica es que **el permiso del archivo en tu equipo es una decisión de seguridad que tomas tú**, no Compose. `644` hace que el `revisor` arranque, pero también deja leer el token a cualquier otra cuenta de tu equipo. Las dos secciones que siguen lo miden y muestran la forma segura; la sección 6.5.4 de la Lección 6 dice lo mismo, con otras palabras.

#### 9.8.3 Medir quién puede leer el token

Un permiso como `644` son tres cifras, una por cada grupo de personas: el **dueño** del archivo, el **grupo** del archivo y **todos los demás**. Cada cifra suma `4` (leer), `2` (escribir) y `1` (ejecutar). Así, `644` es «el dueño lee y escribe (`6 = 4 + 2`), el grupo lee (`4`) y todos los demás leen (`4`)». «Todos los demás» no es una forma de decir «tú»: es **cualquier cuenta de tu equipo**, la de otra persona que tenga sesión abierta en un servidor compartido, la de un servicio que corre con su propio usuario, o la de un programa que alguien logró hacer correr como otro usuario. Con `600` solo el dueño lo lee, y con `640` lo leen el dueño y el grupo, y nadie más.

Se comprueba con dos comandos. `ls -l secretos/` muestra los permisos en letras: `-rw-r--r--` es `644`, `-rw-------` es `600` y `-rw-r-----` es `640`. Y `stat -c '%a %U:%G' secretos/revisor_token.txt` los muestra en número, junto con el dueño y el grupo. Cuando el número de un dueño no corresponde a ninguna cuenta de tu equipo (el `65532` del `revisor` no es una cuenta), `stat` escribe `UNKNOWN`; para ver el número, pídelo con `%u:%g` o usa `ls -ln`.

Pero mirar los permisos no es lo mismo que **probarlos**. El guion `fig09_11.sh` hace las dos cosas y en cada caso pregunta lo mismo: ¿lo lee otro usuario sin privilegios?, ¿lo lees tú?, ¿lo lee el `revisor`, que corre como `65532`? Para «otro usuario» usa `sudo -u nobody`: `nobody` es una cuenta sin privilegios que viene en todo Linux, y sirve para hacerse pasar por cualquier otro usuario. Antes de cada `Permission denied` de `nobody` hay un control: `sudo -u nobody stat` demuestra que `nobody` **sí llega hasta el archivo** (la carpeta está abierta), de modo que si el `cat` siguiente falla es por el permiso del archivo y no por otra cosa. (En la máquina de pruebas, la carpeta personal está en `750`, y eso solo frena a quien intente entrar en ella; no cuentes con eso: el proyecto puede estar en otra ruta, o alguien puede abrir la carpeta algún día.) El guion necesita `sudo`, para hacerse pasar por `nobody` y para cambiar el dueño del archivo. Los casos 3 y 4 siguen **tal cual** las opciones B y A de 9.8.4, partiendo del `644` con el que llegas de la Lección 6. La parte que cambia, con el archivo del token de mentira:

```bash
# La cuenta sin privilegios: «nobody» existe en todo Linux y sirve para hacerse
# pasar por «otro usuario cualquiera de tu equipo». El nombre de tu usuario y de tu
# grupo se tapa con sed, porque depende del equipo.
SUBE="docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
PS_REV="docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
STAT="stat -c '%a %U:%G' secretos/revisor_token.txt"
TAPA_TODO="sed -E 's/ .*/ <tu usuario>:<tu grupo>/'"
TAPA_DUENO="sed -E 's/ [^:]+:/ <tu usuario>:/'"
# El control de cada negativa: «nobody» sí llega hasta el archivo (la carpeta está
# abierta); si el cat siguiente falla, es por el permiso del archivo.
CONTROL="sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt"
OTRO="sudo -u nobody cat secretos/revisor_token.txt"

echo "== 1. Permisos 644, dueño tu usuario"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "$PS_REV"

echo
echo "== 2. Permisos 600, dueño tu usuario"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
sleep 4
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "[ \"\$(docker inspect --format '{{.RestartCount}}' ${COMPOSE_PROJECT_NAME}-revisor-1)\" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'"

echo
echo "== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala"
muestra "chmod 644 secretos/revisor_token.txt"   # el estado con el que llegas de la Lección 6
muestra "chmod 600 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "$STAT"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "sudo cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"   # el archivo vuelve a ser tuyo
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chgrp +65532 secretos/revisor_token.txt"
muestra "chmod 640 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_DUENO"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 5. Lo mismo, más la carpeta secretos/ cerrada con 700"
muestra "chmod 700 secretos"
muestra "stat -c '%a' secretos"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"
muestra "chmod 755 secretos"

echo
echo "== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"

echo
echo "== 7. ¿El grupo 65532 es de alguien en este equipo?"
muestra "getent group 65532"
```

```text
$ ./fig09_11.sh
== 1. Permisos 644, dueño tu usuario
$ chmod 644 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
644 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)

== 2. Permisos 600, dueño tu usuario
$ chmod 600 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
600 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ [ "$(docker inspect --format '{{.RestartCount}}' curso-docker-fig09-revisor-1)" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'
el revisor se reinició: no pudo leer su token

== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala
$ chmod 644 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt
600 UNKNOWN:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt
600 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ sudo cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200

== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chgrp +65532 secretos/revisor_token.txt
$ chmod 640 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ [^:]+:/ <tu usuario>:/'
640 <tu usuario>:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'
640 <tu uid>:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
640 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA       <t>  codigo 503
lento     LENTO     <t>  200
sano      OK          <t>  200

== 5. Lo mismo, más la carpeta secretos/ cerrada con 700
$ chmod 700 secretos
$ stat -c '%a' secretos
700
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
$ chmod 755 secretos

== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
chmod: changing permissions of 'secretos/revisor_token.txt': Operation not permitted
[código de salida: 1]
$ stat -c '%a %u:%g' secretos/revisor_token.txt
644 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c

== 7. ¿El grupo 65532 es de alguien en este equipo?
$ getent group 65532
[código de salida: 2]
```

Resumen de lo que mostró, caso por caso:

| Permisos y dueño | ¿Lo lee otro usuario? | ¿Lo lees tú? | ¿Lo lee el `revisor`? |
|---|---|---|---|
| `644`, tu usuario | **sí** | sí | sí |
| `600`, tu usuario | no | sí | **no** (`permission denied`) |
| `600`, dueño `65532` (opción B) | no | no, salvo con `sudo` | sí |
| `640`, tu usuario, grupo `65532` (opción A) | no | sí | sí |

1. **`644`: lo lee cualquiera.** El primer bloque es el hallazgo: `sudo -u nobody cat` imprime el token completo. El `revisor` arranca sano, y por eso `644` parece «la solución»: funciona. Pero funciona porque abre el archivo a todos, no solo al `revisor`.
2. **`600` de tu usuario: se cierra, y también se cierra al `revisor`.** `nobody` recibe `Permission denied`, pero el `revisor` también: es el error de la Lección 6 y de 9.10. El archivo es de tu usuario, el `revisor` es el usuario `65532`, y para el núcleo el `revisor` es «otro usuario» como `nobody`. El renglón `se reinició` confirma que el `revisor` entra y sale en un bucle.
3. **`600` con dueño `65532` (opción B): cerrado a todos, menos al `revisor`.** Solo el dueño del archivo (el `revisor`) y `root` pueden leerlo. `nobody` recibe `Permission denied`, y tú también, porque ya no eres el dueño; para verlo o cambiarlo necesitas `sudo cat`. El `revisor` llega a `(healthy)` y la tabla sale con el token. El precio: tu comodidad. Y el `UNKNOWN:UNKNOWN` del primer `stat` no es un error: el número `65532` no tiene nombre de cuenta en tu equipo. Fíjate en el **orden**: primero `chmod 600` y después `sudo chown`.
4. **`640` con grupo `65532` (opción A): la salida cómoda.** Tú sigues siendo el dueño (lo lees y lo editas sin `sudo`), y el **grupo** del archivo es el `65532`. El `revisor` corre como `65532:65532` (usuario y grupo, que vienen de la imagen: `docker inspect --format '{{.Config.User}}'`), así que para el núcleo entra por la cifra del grupo. `nobody` no está en ese grupo y no lee nada. Es el permiso mínimo que deja trabajar a las dos partes. Vale lo mismo que en la Lección 6: los números de dentro y de fuera deben ser los mismos (instalación normal de la Lección 1). Con Docker sin `root` o con remapeo de usuarios, el `65532` de dentro corresponde fuera a otro número (el inicio de tu rango en `/etc/subuid` y `/etc/subgid` más 65532; ese inicio cambia de una instalación a otra, y se lee en esos archivos. Como ejemplo, la [documentación de `userns-remap`](https://docs.docker.com/engine/security/userns-remap/) cuenta que, con un rango que empieza en `231072`, el `231073` es el usuario `1` de dentro; el `231072` es solo el valor de ese ejemplo), y esta receta no aplica tal cual: el `revisor` dará `permission denied`, y no hay fuga, pero tampoco hay solución rápida; el diagnóstico es el de `ls -ln` de la Lección 6.
5. **La carpeta `secretos/` en `700` no estorba.** El bloque 5 la cierra (`chmod 700 secretos`) y el `revisor` se recrea y sigue `(healthy)`: el montaje de un solo archivo lo establece el daemon, no tu usuario. Cierra la carpeta además del archivo: quien no puede entrar en ella ni siquiera ve que el token existe.
6. **El orden equivocado deja el token abierto.** El bloque 6 hace la opción B al revés: `sudo chown 65532:65532` primero y `chmod 600` después. El `chmod` falla con `Operation not permitted`, porque ya no eres el dueño y el núcleo solo deja cambiar los permisos al dueño (o a `root`). El archivo se queda en `644`, ahora de `65532`, y `nobody` imprime el token. Siempre se **cierra primero y se regala después**, y se comprueba al final.
7. **El grupo `65532` no es exclusivo del `revisor`.** Es el usuario y grupo `nonroot` de las imágenes *distroless* (la imagen final del `revisor` es `gcr.io/distroless/static-debian13:nonroot`) y de las de Chainguard, así que cualquier contenedor de esas imágenes al que montes este archivo lo lee por la cifra del grupo. Y si en tu equipo existiera un grupo real con ese número, sus miembros también. Por eso el último bloque pregunta `getent group 65532`: si no imprime nada (como aquí, con código de salida 2), el número no es de nadie en tu equipo.

Lo que ningún permiso impide: `root` lee todo, y quien pueda hablarle al daemon de Docker (el grupo `docker` de la Lección 1) puede montar tu carpeta en un contenedor y leerla. Por eso se cuida quién está en ese grupo; es otro motivo para no regalar el archivo a «todos los demás».

#### 9.8.4 La forma segura en tu carpeta

Hay dos formas de dejar el archivo cerrado, de la más cómoda a la más estricta. Las dos dejan leer al `revisor` y dejan fuera a los demás. **Elige una**; no las apliques seguidas.

**Opción A**: tú eres el dueño y el grupo del `revisor` puede leer.

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt
chmod 640 secretos/revisor_token.txt
```

El `+` le dice a `chgrp` que `65532` es un número de grupo y no un nombre (sin el `+`, también lo toma como número si no existe un grupo con ese nombre).

**Opción B**: el dueño es el propio `revisor`. Tú necesitas `sudo` para leerlo.

```bash
cd revisor
chmod 600 secretos/revisor_token.txt               # primero se cierra, mientras aún eres el dueño
sudo chown 65532:65532 secretos/revisor_token.txt  # después se regala; ya no podrás cambiarlo sin sudo
```

El orden importa: si regalas primero, el `chmod` falla y el archivo se queda como estaba (bloque 6 de 9.8.3).

Sea cual sea la que elijas, **compruébalo siempre**:

```bash
ls -l secretos/revisor_token.txt
stat -c '%a %U:%G' secretos/revisor_token.txt
sudo -u nobody cat secretos/revisor_token.txt   # debe decir: Permission denied
chmod 700 secretos                              # y cierra también la carpeta
```

Después, `docker compose up -d --force-recreate revisor` (cambiar el permiso de un archivo no es un cambio de configuración para Compose, y el `revisor` solo lee su token al arrancar).

**Las copias también cuentan.** Cada copia del token nace con sus propios permisos: un `cp` sin `-p` deja el archivo a tu nombre, con tu grupo y tu `umask`; y la copia de respaldo de un editor (`revisor_token.txt~`), el respaldo de tu carpeta personal o una copia a una memoria USB o a la nube no conservan el `640`. Revísalas con el mismo `stat`, o no las hagas.

**Para crear un secreto nuevo**, que nazca cerrado en vez de abrirse y cerrarse después. Mira tu `umask` con `umask`: es la «resta» de permisos que el sistema aplica a todo archivo nuevo. En Ubuntu y Linux Mint suele valer `0002` (medido en la máquina de pruebas, Ubuntu 24.04), y un archivo nuevo sale en `664`: lo lee cualquiera, igual que con `644`. El `644` que viste en la Lección 6 no lo puso el `umask`: lo puso el `chmod` del curso. Dos formas de crear un archivo cerrado:

```bash
install -m 600 /dev/null secretos/token.txt                              # crea el archivo vacío, ya en 600
(umask 077; read -rs VALOR; printf '%s' "$VALOR" > secretos/token2.txt)  # pegas el valor sin que se vea
```

Tres advertencias. Las dos formas son para un archivo que **no existe todavía**: si ya existe, `umask` no le cambia el permiso (ciérralo con `chmod 600`) e `install` lo reemplaza por uno vacío, sin avisar. Las dos lo dejan en `600` **a tu nombre**, que es el caso 2 de 9.8.3: el `revisor` todavía no lo puede leer, así que termina con la opción A o la B. Y **no escribas el valor en la línea de comandos** (`VALOR=... ` o `echo ... >`): queda en el historial de tu terminal; por eso el ejemplo usa `read -rs`, o pégalo desde un editor.

**¿Y cuándo sí `644`?** Solo en una situación: un token de mentira, en una computadora que es solo tuya, para una práctica. Los guiones de esta lección lo usan dentro de una carpeta temporal que se borra al terminar, y por eso lo dejan en `644`. Tres advertencias, sin letra chica:

- **El token del curso es ficticio** (`curso-docker-token-de-mentira-7f3a9c`); no abre nada.
- **`644` deja que cualquier cuenta local lo lea**, como acabas de medir.
- **Nunca uses `644` con un secreto real**: ni en tu laptop, ni en un servidor, ni «un ratito mientras pruebo».

Y la otra mitad de la higiene del secreto: **que no llegue al repositorio**. En tu proyecto, `secretos/` va en el `.gitignore` desde el primer día, y se comprueba:

```bash
echo 'secretos/' >> .gitignore
git check-ignore -v secretos/revisor_token.txt
```

```text
.gitignore:1:secretos/	secretos/revisor_token.txt
```

Si `git check-ignore` no imprime nada, el archivo **no** está ignorado. (Una excepción: si `git` ya sigue el archivo desde antes de que lo ignoraras, el `.gitignore` no lo suelta; se retira con `git rm --cached` y el token ya publicado se da por perdido y se cambia, igual que en la Lección 6.) Lo de Compose que ya viste en 9.8.1 queda así: el `compose.yaml` dice dónde está el token, el `.gitignore` lo mantiene fuera del repositorio, el `.dockerignore` lo mantiene fuera de la imagen, y el permiso del archivo lo mantiene fuera del alcance del resto de tu equipo.

### 9.9 El archivo final

#### 9.9.1 Todo junto

Este es el `compose.yaml` con el que terminas la lección. Reemplaza el primero en tu carpeta `revisor/`; es el mismo que guarda `estado/compose.yaml`:

```yaml
# fig09_04.compose.yaml — el compose.yaml final de la Lección 9. Va en tu carpeta
# revisor/ como compose.yaml (es el mismo que guarda estado/compose.yaml).
#
# Lección 9 — el sistema completo: el revisor y tres copias del servicio de
# prueba (sana, lenta y caída), con todo lo que se endureció en las lecciones 2 a 8.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

# Lo común a las tres copias del servicio de prueba, escrito una sola vez.
# Compose ignora los campos que empiezan con «x-»; sirven para anclas de YAML.
# Solo prueba-sano lleva «build»: si las tres construyeran la misma etiqueta a la
# vez, chocarían («image ... already exists»). Las otras dos usan la imagen que
# construye la primera y nunca la buscan en internet (pull_policy: never).
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  init: true
  mem_limit: 32m
  cpus: 0.25
  pids_limit: 20

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: >-
        sano http://prueba-sano:9000/ 2s,
        lento http://prueba-lento:9000/ 5s,
        caido http://prueba-caido:9000/ 2s
      REVISOR_TOKEN_ARCHIVO: /run/secrets/revisor_token
    secrets:
      - revisor_token
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
    restart: unless-stopped

  prueba-sano:
    <<: *prueba
    build: ../servicio-prueba
    environment:
      PRUEBA_MODO: sano

  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento

  prueba-caido:
    <<: *prueba
    environment:
      PRUEBA_MODO: caido

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}

secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

Lo que cambió respecto del primero, servicio por servicio:

- **`x-prueba`**: el bloque común de las tres copias (9.6), con las mismas opciones endurecidas que el `revisor`, `init: true` incluido. Llevan límites más chicos (32 MB y un cuarto de CPU), porque no hacen casi nada.
- **`revisor`**: tres servicios en `REVISOR_SERVICIOS`, el token como secreto con `REVISOR_TOKEN_ARCHIVO` apuntando a `/run/secrets/revisor_token`, `depends_on` con sus condiciones (9.7), y `restart: unless-stopped`, la política que la Lección 7 eligió para el `revisor`.
- **`prueba-sano`, `prueba-lento`, `prueba-caido`**: el ancla más su modo. Solo la sana construye.
- **Arriba**: las mismas redes y el mismo volumen, más el secreto.

Un detalle de YAML en `REVISOR_SERVICIOS`: el `>-` es un **bloque plegado**. YAML junta los tres renglones en uno, con un espacio donde había saltos de línea, y el `-` quita el salto del final. Así cada servicio queda en su propio renglón del archivo, fácil de leer y de cambiar, y el `revisor` recibe una sola cadena separada por comas, que es lo que espera. El bloque 5 de la siguiente corrida te enseña el valor tal como llegó al contenedor.

#### 9.9.2 Verlo funcionar

El guion `fig09_05.sh` lo levanta desde cero y lo revisa por dentro. La parte que cambia:

```bash
echo "== 1. Validar"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'"

echo
echo "== 2. Levantar todo desde cero"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 3. El reporte: sin token, 401; con token, la tabla"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
muestra "tabla"

echo
echo "== 4. Lo que creó Compose, todo con el nombre del proyecto"
muestra "docker network ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}} interna={{.Internal}}' | sort"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 5. El token no está a la vista"
muestra "docker inspect ${COMPOSE_PROJECT_NAME}-revisor-1 | grep -c \"\$TOKEN\""
muestra "docker compose config | grep -c \"\$TOKEN\""
muestra "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1 | grep REVISOR_"
muestra "docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
```

```text
$ ./fig09_05.sh
== 1. Validar
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba-caido
prueba-lento
prueba-sano
revisor
$ docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'
      PRUEBA_MODO: lento
    image: curso-docker-prueba:fig09
    mem_limit: "33554432"
    networks:
    pull_policy: never
    read_only: true

== 2. Levantar todo desde cero
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-revisor:fig09 Built
Image curso-docker-prueba:fig09 Built
Network curso-docker-fig09_publica Created
Network curso-docker-fig09_interna Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-caido-1 Created
Container curso-docker-fig09-prueba-sano-1 Created
Container curso-docker-fig09-prueba-lento-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-caido-1 Started
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-sano-1 Waiting
Container curso-docker-fig09-prueba-sano-1 Healthy
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-caido-1 | Up N (unhealthy) | 9000/tcp
curso-docker-fig09-prueba-lento-1 | Up N (health: starting) | 9000/tcp
curso-docker-fig09-prueba-sano-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp

== 3. El reporte: sin token, 401; con token, la tabla
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados
{"error":"falta el token o no es válido"}
 [401]
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200

== 4. Lo que creó Compose, todo con el nombre del proyecto
$ docker network ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}} interna={{.Internal}}' | sort
curso-docker-fig09_interna interna=true
curso-docker-fig09_publica interna=false
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' curso-docker-fig09-revisor-1
ReadonlyRootfs=true CapDrop=[ALL] Init=true Memory=67108864 User=65532:65532 Restart=unless-stopped

== 5. El token no está a la vista
$ docker inspect curso-docker-fig09-revisor-1 | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker compose config | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-fig09-revisor-1 | grep REVISOR_
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_SERVICIOS=sano http://prueba-sano:9000/ 2s, lento http://prueba-lento:9000/ 5s, caido http://prueba-caido:9000/ 2s
REVISOR_PUERTO=8080
REVISOR_REPORTE=/datos/reporte.json
$ docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true
volume /datos ro=false
```

#### 9.9.3 Leer la corrida

1. **Validar.** Cuatro servicios. Y el servicio `prueba-lento`, leído por `config`, trae `image`, `pull_policy: never`, `read_only`, `mem_limit` (32 MB, en bytes) y `networks`, que vinieron del ancla. El ancla funciona.
2. **Levantar.** Fíjate en el orden de los eventos, que es el centro de esta lección. Se construyen las dos imágenes (solo dos, aunque haya cuatro servicios), se crean redes, volumen y los cuatro contenedores. Arrancan las tres copias del servicio de prueba. Y entonces aparece `prueba-sano-1 Waiting` y `prueba-sano-1 Healthy`: Compose **esperó** a que la sana pasara su revisión de salud, y solo después arrancó el `revisor`. Es `service_healthy` funcionando. El orden en que arrancan las tres copias puede cambiar de una corrida a otra, porque arrancan a la vez.
3. **`ps`.** El estado de salud cuenta la historia completa: `prueba-caido` está `(unhealthy)`, que es su trabajo; `prueba-lento` está `(health: starting)` y va a terminar `unhealthy` (tarda 3 s y su revisión exige menos de 2); `prueba-sano` y el `revisor`, `(healthy)`. Cuatro contenedores `Up`, y solo dos sanos: el segundo criterio del curso, en una sola tabla.
4. **El reporte.** Sin token, `401` con el mensaje del `revisor`: el secreto llegó y el `revisor` lo está exigiendo. Con el token, la tabla con los tres estados: `FALLA` con `codigo 503`, `LENTO` (respondió `200`, pero en más de un segundo) y `OK`. Esa es la meta del curso.
5. **Lo que creó Compose.** Dos redes, la interna con `interna=true`; un volumen; y el `revisor` con todo el endurecimiento de la Lección 7 aplicado por el daemon: sistema de archivos de solo lectura, `CapDrop=[ALL]`, `Init=true`, 64 MB, usuario `65532:65532` (que viene de la imagen) y la política de reinicio.
6. **El token no está a la vista.** `grep -c` cuenta cero veces el valor del token en todo `docker inspect` y en todo `docker compose config` (el `[código de salida: 1]` es de `grep`, que sale con 1 cuando no encuentra nada: aquí, eso es la buena noticia). El entorno del contenedor tiene `REVISOR_TOKEN_ARCHIVO`, que es una **ruta**, no un valor. Y los montajes muestran lo que es por dentro un secreto de archivo: un `bind` de solo lectura (`ro=true`) en `/run/secrets/revisor_token`, junto al `volume` de `/datos`. La tercera meta del curso («ningún secreto aparece en `docker history`, en `docker inspect` ni en las variables de entorno del contenedor») se cumple, en su parte de ejecución, con el sistema completo.

#### 9.9.4 En tu carpeta

Con el archivo final en `revisor/compose.yaml`, `servicio-prueba/` al lado y `secretos/revisor_token.txt` con permisos `640` y grupo `65532` (9.8.4):

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt   # el grupo del revisor puede leerlo...
chmod 640 secretos/revisor_token.txt          # ...y ningún otro usuario (9.8.4)
docker compose config --quiet && echo 'compose.yaml válido'
docker compose up -d --build
docker compose ps
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" 'http://127.0.0.1:8080/api/estados?formato=tabla'
```

Una nota sobre ese `curl`: mientras corre, el token va en su línea de comandos y cualquier cuenta lo puede ver con `ps`, aunque el archivo esté en `640`. Con el token de mentira no importa; con uno real, pásalo desde un archivo de cabeceras (`curl -H @cabeceras.txt`, que debe tener sus propios permisos cerrados).

Los guiones de esta lección usan `644` en una carpeta temporal, con el token de mentira; tu carpeta no lo necesita. Con `644`, cualquier usuario de tu computadora puede leer el token (9.8.3), y en un servidor compartido eso no se acepta: el arreglo es el grupo o el dueño correcto (sección 6.5.4 de la Lección 6), no abrirlo a todos.

Los nombres serán `curso-docker-revisor-1`, `curso-docker-prueba-sano-1` y así, con redes `curso-docker_publica` y `curso-docker_interna` y el volumen `curso-docker_reportes`. Si la Lección 8 te dejó corriendo `curso-docker-revisor` con el puerto 8080, apágalo antes (`docker rm -f curso-docker-revisor curso-docker-prueba`), o el `up` chocará con el puerto ocupado de la Lección 2. Y si conservaste el volumen `curso-docker-reportes` de la Lección 8, no estorba: el de Compose es otro, `curso-docker_reportes`, con guion bajo.

### 9.10 El error que más te va a costar: el secreto en `600`

#### 9.10.1 Provocarlo con `uid`, `gid` y `mode` escritos

El guion `fig09_06.sh` toma el archivo final, cambia el secreto a la forma larga con `uid: "65532"`, `gid: "65532"` y `mode: 0400` (lo que «debería» arreglar el permiso), pone el archivo del token en `600` y levanta. Después lo arregla con `644`, que es lo que sus guiones usan en su carpeta temporal con el token de mentira (en tu carpeta, el arreglo es el de 9.8.4). La parte que cambia:

```bash
cp compose.yaml compose.final.yaml

echo "== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600"
python3 - <<'PY'
s = open("compose.yaml").read()
s = s.replace("""    secrets:
      - revisor_token
""", """    secrets:
      - source: revisor_token
        uid: "65532"
        gid: "65532"
        mode: 0400
""")
open("compose.yaml", "w").write(s)
PY
chmod 600 secretos/revisor_token.txt
muestra "diff compose.final.yaml compose.yaml"
muestra "stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
sleep 3
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/run/secrets/revisor_token\"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)"
cp compose.final.yaml compose.yaml
chmod 644 secretos/revisor_token.txt   # 644: solo porque el token es de mentira (9.8.4)
muestra "stat -c '%a %n' secretos/revisor_token.txt"
muestra "docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "tabla"
```

```text
$ ./fig09_06.sh
== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600
$ diff compose.final.yaml compose.yaml
41c41,44
<       - revisor_token
---
>       - source: revisor_token
>         uid: "65532"
>         gid: "65532"
>         mode: 0400
[código de salida: 1]
$ stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'
600 <tu usuario> secretos/revisor_token.txt
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker inspect --format '{{range .Mounts}}{{if eq .Destination "/run/secrets/revisor_token"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true

== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)
$ stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.10.2 Leerlo

1. **El `diff`** muestra la forma larga, y `stat` muestra el archivo en `600`, de tu usuario (el número se tapa porque depende del equipo).
2. **`Started`.** Compose dice que el `revisor` arrancó, y es verdad: el proceso arrancó. Pero los registros cuentan el resto: `leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied`. El `revisor` no pudo leer su token y prefirió morir con código 1 antes que quedar escuchando sin protección (Lección 6). El `sort -u` del guion junta los renglones repetidos, porque el mensaje sale una vez por cada intento.
3. **`Status=restarting ExitCode=1`.** ¿Intentos? Sí: el archivo final lleva `restart: unless-stopped`, así que el daemon lo vuelve a arrancar cada vez que muere, con esperas cada vez más largas, y cada vez muere igual. Esto es lo que vas a ver en un sistema real cuando un secreto tiene mal los permisos: un contenedor que entra y sale, y un `docker compose ps` que dice `Restarting`. La política de reinicio atiende la muerte del proceso, como viste en la Lección 7; no puede arreglar su causa.
4. **El montaje.** El secreto es un `bind` de solo lectura, con todo y `uid`, `gid` y `mode` declarados. Los tres atributos no hicieron nada. Es exactamente lo que dice la referencia, medido.
5. **El arreglo del guion**: `644` y el archivo de la lección, con la forma corta. Es el arreglo más corto, no el mejor: abre el token a todo el equipo (9.8.3). En tu carpeta usa el de 9.8.4. `--force-recreate revisor` le pide a Compose recrear ese servicio aunque su configuración sea la misma que la del contenedor que existe; aquí hace falta porque lo único que cambió fue el permiso de un archivo en tu equipo, y eso Compose no lo compara. El `revisor` llega a `(healthy)` y la tabla vuelve.

Si esto te pasa en tu carpeta: `ls -l secretos/`, y si dice `-rw-------`, dale lectura **solo** al grupo del `revisor` (`sudo chgrp +65532 secretos/revisor_token.txt` y `chmod 640 secretos/revisor_token.txt`, 9.8.4) y `docker compose up -d --force-recreate revisor`. `chmod 644` también lo arregla, pero deja el token a la vista de todo tu equipo: solo con un token de mentira. Lo que **no** es un arreglo: quitar el `USER` de la imagen o poner `user: "0"` en el servicio para que `root` lo lea. Eso cambia un problema de permisos de un archivo por un contenedor entero corriendo como `root`.

### 9.11 Dos errores de Compose que conviene conocer antes

El guion `fig09_07.sh` provoca los dos errores propios de este archivo y mide lo que pasa sin `pull_policy: never` (la pregunta que quedó abierta en 9.6.3). La parte que cambia:

```bash
cp compose.yaml compose.final.yaml

echo "== 1. Las tres copias del servicio de prueba con «build»"
# Pone «build» en el ancla común (las tres copias la heredan) y quita la de prueba-sano.
sed -i -e 's|^  image: \(.*prueba:fig09\)$|  build: ../servicio-prueba\n  image: \1|' \
       -e '/^    build: ..\/servicio-prueba$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
# Es una carrera: a veces una de las tres termina antes de que empiecen las otras
# y no choca. Por eso se intenta cinco veces, borrando la etiqueta entre una y otra.
for i in 1 2 3 4 5; do
  docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1
  echo "-- intento $i"
  muestra "docker compose build >build.log 2>&1; echo \"build salió con \$?\"; grep -h '^target' build.log || true"
done
docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1

echo
echo "== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir"
cp compose.final.yaml compose.yaml
sed -i '/^  pull_policy: never$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'"
docker compose down --remove-orphans >/dev/null 2>&1

echo
echo "== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar"
cp compose.final.yaml compose.yaml
docker compose build >/dev/null 2>&1
inicio=$(date +%s)
muestra "docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1"
echo "(tardó $(( $(date +%s) - inicio )) s)"
muestra "docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1"
muestra "docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 4. Lo que sí funciona: up -d y esperar la salud del revisor"
esperar revisor healthy && echo "revisor: healthy"
muestra "tabla"
```

```text
$ ./fig09_07.sh
== 1. Las tres copias del servicio de prueba con «build»
$ diff compose.final.yaml compose.yaml
15a16
>   build: ../servicio-prueba
67d67
<     build: ../servicio-prueba
[código de salida: 1]
-- intento 1
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 2
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0
-- intento 3
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 4
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-lento: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 5
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0

== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir
$ diff compose.final.yaml compose.yaml
17d16
<   pull_policy: never
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Building
Image curso-docker-prueba:fig09 Built

== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar
$ docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
(tardó 11 s)
$ docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (health: starting)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)

== 4. Lo que sí funciona: up -d y esperar la salud del revisor
revisor: healthy
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.11.1 Tres construcciones de la misma etiqueta

Con `build` en el ancla, los tres servicios de prueba construyen la misma imagen con el mismo nombre, y Compose lanza las tres construcciones **a la vez**. Las tres terminan con la misma imagen y las tres intentan ponerle el mismo nombre al final; la que llega después encuentra el nombre ocupado: `target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists`, y `build` sale con `1`. Fíjate en dos cosas. La primera: el servicio que reporta el choque puede ser cualquiera de los tres, según cuál termine después; en esta corrida fue `prueba-sano` en los intentos 1 y 3, y `prueba-lento` en el 4. La segunda: en los intentos 2 y 5 **no** chocó, y `build` salió con `0`. Es una carrera, y a veces se gana: en esta corrida falló en 3 de 5 intentos. Un error que aparece «a veces» es peor que uno que aparece siempre, porque te hace creer que lo arreglaste cuando solo tuviste suerte.

La causa es de diseño, no de suerte: **una imagen se construye una vez y se usa muchas**. Por eso el archivo final pone `build` en un solo servicio y `pull_policy: never` en los otros dos (9.6.3). En tu terminal, el mensaje completo viene precedido de los pasos de BuildKit; busca el renglón que empieza con `target`, que te dice en qué servicio falló.

#### 9.11.2 Sin `pull_policy: never`

El bloque 2 quita la línea `pull_policy: never` del ancla (el `diff` lo muestra) y levanta con la imagen del servicio de prueba todavía sin construir (el bloque 1 la borró al final). Los eventos de la imagen cuentan lo que dijimos en 9.6.3: dos `Pulling` y dos `Error pull access denied`, uno por cada servicio que **no** construye la imagen (`prueba-lento` y `prueba-caido`) y que, sin `never`, primero la buscan en Docker Hub. Después, `Building` y `Built`: Compose ve que otro servicio del proyecto construye esa misma imagen, deja pasar el error y sigue. El sistema arranca igual. Por eso `pull_policy: never` no es para que funcione, sino para que **no pregunte**: sin la línea, el arranque depende de que en Docker Hub no exista algo con ese nombre, y llena tu terminal de errores que tienes que aprender a ignorar, que es la peor costumbre que se puede tener frente a un error.

#### 9.11.3 `--wait` con un servicio que falla a propósito

`docker compose up --wait` existe para guiones y para integración continua: según su referencia, espera a que los servicios estén «corriendo o sanos», e implica el modo separado; `--wait-timeout` fija cuántos segundos esperar como máximo ([referencia de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Suena perfecto para esperar al `revisor`, pero mira el bloque 3: `container curso-docker-fig09-prueba-caido-1 is unhealthy`, código `1`, en once segundos según el propio guion (`tardó 11 s`). `--wait` espera a **todos** los servicios con revisión de salud, y `prueba-caido` no va a estar sano nunca; en cuanto Docker lo marca `unhealthy`, `--wait` se rinde. Y nombrar solo al `revisor` (`up --wait revisor`) da el mismo error: para levantar el `revisor`, Compose levanta sus dependencias, y espera también por ellas.

Fíjate en el `ps` de después: el sistema quedó **arriba** y funcionando, con el `revisor` `(healthy)`. `--wait` no deshizo nada; solo reportó con un código distinto de 0 que no todo está sano. En un sistema de verdad eso es justo lo que quieres saber. En éste, donde un servicio está caído a propósito, el curso usa `up -d` y después espera la salud del **`revisor`** con `docker inspect`, que es lo que hace la función `esperar` de los guiones. El bloque 4 lo demuestra, y la tabla sale completa.

### 9.12 El ciclo de vida: cambiar, apagar, conservar

El guion `fig09_08.sh` levanta el sistema final, pide un reporte para que haya algo guardado, y después recorre lo que vas a hacer todos los días. La parte que cambia:

```bash
cp compose.yaml compose.final.yaml
docker compose up -d --build >/dev/null 2>&1
esperar revisor healthy
curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados"

echo "== 1. Cambiar un servicio: prueba-caido pasa a modo sano"
sed -i '/^  prueba-caido:/,/^[a-z]/s/PRUEBA_MODO: caido/PRUEBA_MODO: sano/' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'"
esperar prueba-caido healthy
muestra "tabla"
cp compose.final.yaml compose.yaml
docker compose up -d >/dev/null 2>&1

echo
echo "== 2. down sin --volumes: el reporte sigue ahí, en su volumen"
muestra "docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker run --rm -v ${COMPOSE_PROJECT_NAME}_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'"
docker compose up -d >/dev/null 2>&1
esperar revisor healthy

echo
echo "== 3. Apagado ordenado"
inicio=$(date +%s%3N); docker compose stop revisor >/dev/null 2>&1; fin=$(date +%s%3N)
echo "docker compose stop revisor tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker compose logs --no-log-prefix revisor | tail -2"

echo
echo "== 4. down --volumes: ahora sí, también el reporte"
muestra "docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}' | wc -l"
```

```text
$ ./fig09_08.sh
== 1. Cambiar un servicio: prueba-caido pasa a modo sano
$ diff compose.final.yaml compose.yaml
79c79
<       PRUEBA_MODO: caido
---
>       PRUEBA_MODO: sano
[código de salida: 1]
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-prueba-caido-1 Recreate
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-caido-1 Started
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     OK            <t>  200
lento     LENTO     <t>  200
sano      OK            <t>  200

== 2. down sin --volumes: el reporte sigue ahí, en su volumen
$ docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker run --rm -v curso-docker-fig09_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'
total 4
-rw-------    1 65532    65532          269 <fecha> reporte.json

== 3. Apagado ordenado
docker compose stop revisor tardó 203 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
ExitCode=0
$ docker compose logs --no-log-prefix revisor | tail -2
revisor: recibí terminated, apagando
revisor: apagado limpio

== 4. down --volumes: ahora sí, también el reporte
$ docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Volume curso-docker-fig09_reportes Removed
Network curso-docker-fig09_publica Removed
Network curso-docker-fig09_interna Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}' | wc -l
0
```

1. **Cambiar un servicio.** El archivo pasa `prueba-caido` a modo sano y se pide `up -d`. Compose deja tres contenedores en `Running` y **recrea solo `prueba-caido`**. Ni siquiera el `revisor`, que depende de él, se toca: su configuración no cambió, y su `depends_on` no pide reiniciarse cuando una dependencia cambia (existe la opción `restart: true` dentro de `depends_on` para eso; la documentación la describe para un servicio que debe reconectarse cuando su base de datos se recrea, y el `revisor` no la necesita porque abre una conexión nueva en cada revisión) ([Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/)). La siguiente tabla dice `caido OK 200`: el nombre del servicio sigue siendo `caido`, pero ahora responde sano. Es el modelo de Compose en un ejemplo: describes el estado que quieres, y la herramienta calcula el cambio mínimo. El guion devuelve el archivo a su forma final antes de seguir.
2. **`down` sin `--volumes`.** Se borran contenedores y redes; el volumen sigue en `docker volume ls`. El ayudante de `alpine` de la Lección 8 lo lee de solo lectura y ahí está `reporte.json`, de `65532`, con sus permisos `600` (el `revisor` lo crea así: el reporte es de quien lo escribe). Cuando el guion vuelve a pedir `up -d`, el `revisor` nuevo monta el mismo volumen. Es la quinta meta del curso, «el reporte sobrevive», ahora con el sistema completo.
3. **Apagado ordenado.** `docker compose stop revisor` tarda menos de un segundo (en esta corrida, 203 ms) y el `revisor` termina con `ExitCode=0`. Sus registros lo cuentan: `recibí terminated, apagando` y `apagado limpio`. `stop` usa por debajo el mismo `SIGTERM` y el mismo plazo de 10 s de `docker stop` de la Lección 7; `init: true` y el manejador del `revisor` hacen el resto.
4. **`down --volumes`.** Ahora sí se va el volumen, y con él el reporte. Úsalo cuando de verdad quieras empezar de cero, sabiendo que no tiene papelera.

### 9.13 ¿Y `docker init`?

El plan del curso pedía comparar tu archivo con el que genera `docker init`, un comando que crea un `Dockerfile`, un `.dockerignore`, un `compose.yaml` y un `README.Docker.md` a partir de una plantilla por lenguaje (Go, Python, Node, Java, Rust y otros) ([referencia de `docker init`](https://docs.docker.com/reference/cli/docker/init/)). La primera frase de esa misma página es la que importa aquí: «Docker Desktop proporciona el comando `docker init`». No es parte de Docker Engine, que es lo que instalaste en tu Mint en la Lección 1. El guion `fig09_09.sh` lo comprueba (no crea nada, así que no necesita el arranque de los demás):

```bash
#!/usr/bin/env bash
# fig09_09.sh — docker init es una función de Docker Desktop: en Docker Engine,
# el que instalaste en la Lección 1, el comando no existe. No crea nada.
set -uo pipefail
echo "\$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
echo "\$ docker compose version"
docker compose version
echo "\$ docker init"
docker init 2>&1
echo "[código de salida: $?]"
```

```text
$ ./fig09_09.sh
$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
Cliente: 29.2.1  Daemon: 29.2.1
$ docker compose version
Docker Compose version v5.0.2
$ docker init
docker: unknown command: docker init

Run 'docker --help' for more information
[código de salida: 1]
```

Así que el curso no depende de él, y la comparación se hace con lo que la documentación oficial muestra. La guía de Docker para poner en contenedor una aplicación de Python arranca con este `compose.yaml` de un solo servicio (aquí sin sus comentarios de encabezado) ([Docker, «Containerize a Python application»](https://docs.docker.com/guides/python/containerize/)):

```yaml
services:
  server:
    build:
      context: .
    ports:
      - 8000:8000
```

Es un buen punto de partida, y un archivo muy distinto del tuyo. El Ejercicio 4 te pide encontrar las diferencias, una por una, y decir qué lección del curso explica cada una. Un generador te ahorra escribir; no te ahorra entender lo que escribió. Si algún día usas `docker init` en un equipo con Docker Desktop, lee su `compose.yaml` con `docker compose config` y pásalo por la lista del hábito de seguridad de esta lección antes de usarlo.

### 9.14 Lo que vas a encontrar en tutoriales viejos

- **`docker-compose`, con guion.** Es Compose «V1», un programa aparte escrito en Python. Docker lo declara retirado: «Compose v1 ya no se mantiene, y los usuarios deben migrar a Compose v2» ([Docker, «Retired features»](https://docs.docker.com/retired/)). Hoy es `docker compose`, con espacio. Si un tutorial dice `docker-compose up`, tradúcelo.
- **Nombres de contenedor con guion bajo**, como `proyecto_web_1`. Eran los de V1. El anuncio de Compose V2 lo dice así: los nombres de contenedor «ahora usan guiones como separadores en lugar de guiones bajos», y si un guion depende de esos nombres, se va a romper; por eso recomienda, en general, no depender de los nombres de los contenedores ([Docker, «Announcing Compose V2 General Availability»](https://www.docker.com/blog/announcing-compose-v2-general-availability/)). Si un guion viejo busca `curso-docker_revisor_1` (el nombre que tendría en V1 el `curso-docker-revisor-1` de esta lección), no lo va a encontrar.
- **`version: "3.8"`** (o `"2"`, o `"3"`) al principio del archivo. Obsoleto; solo produce un aviso (9.2.3).
- **`docker-compose.yml`** como nombre de archivo. Todavía se acepta por compatibilidad, pero el preferido es `compose.yaml`.
- **`links:`** dentro de un servicio. Es el `--link` de la Lección 8 en forma de clave; en las redes de un proyecto, los servicios ya se encuentran por nombre.
- **El token en `environment:`**, o en un archivo `.env` que se usa para llenar `environment`. Funciona, y es lo que la Lección 6 te enseñó a no hacer: queda en `docker inspect`. Para eso existen los `secrets`.

## El error que vas a ver

Esta lección tiene tres errores principales. Todos aparecieron ya, y cada uno se distingue por dónde lo ves.

**En el reporte: `read-only file system` en `/datos`.**

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

El contenedor está `healthy` y el reporte falla. Se lee de derecha a izquierda, como los de las Lecciones 7 y 8: `read-only file system` lo dice el núcleo; `/datos/.reporte-<n>.tmp` dice que el problema es la carpeta `/datos`; y el `500` lo pone el `revisor`, que no finge. La pregunta que lo resuelve es: «¿qué está montado en `/datos`?». La respuesta la da `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' <contenedor>`. Si `/datos` no aparece, falta el volumen en el servicio. Arreglo: `volumes: [reportes:/datos]` en el servicio y `reportes: {}` arriba, y `docker compose up -d` (recrea solo el `revisor`). Lo que no es un arreglo: `read_only: false`.

**En los registros: `permission denied` en `/run/secrets/`.**

```text
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
```

Y en `docker compose ps`, un `revisor` que dice `Restarting`. `Started` en la salida de `up` no te va a avisar: el proceso sí arrancó, y murió después. Se diagnostica con `docker compose logs revisor` y `ls -l secretos/`. Si el archivo está en `600`, el usuario `65532` del contenedor no lo puede leer, y `uid`, `gid` y `mode` en el `compose.yaml` no lo cambian, porque con un secreto de archivo Compose los ignora. Arreglo: que el grupo del archivo sea `65532` y el permiso `640` (`sudo chgrp +65532 secretos/revisor_token.txt` y `chmod 640 secretos/revisor_token.txt`), o que el dueño sea `65532` con `600`, y `docker compose up -d --force-recreate revisor`. `chmod 644` también lo arregla, pero abre el token a todo el equipo: solo con un token de mentira (9.8.4).

**En el comando: `--wait` que no termina bien.**

```text
container curso-docker-fig09-prueba-caido-1 is unhealthy
```

(En tu carpeta, `curso-docker-prueba-caido-1`.) Código `1`, aunque nombres solo al `revisor`. No es un fallo del sistema: es `--wait` esperando también a un servicio que no puede estar sano. En este proyecto, `up -d` y esperar la salud del `revisor`. En un proyecto sin servicios que fallen a propósito, ese mensaje sí es una alarma: te dice exactamente qué contenedor revisar.

**Y uno secundario, al construir**:

```text
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
```

(En tu carpeta la etiqueta será la tuya, `curso-docker-prueba:1.0.0`, y el servicio puede ser cualquiera de los tres.) Varios servicios con `build` y la misma `image`. Aparece a veces, no siempre: en la corrida de 9.11, en 3 de 5 intentos. Arreglo: `build` en un solo servicio, `pull_policy: never` en los demás.

## El hábito de seguridad de la lección

**El `compose.yaml` nace con todo lo anterior, y sus secretos viven fuera del archivo.** Es el hábito que el README del curso le asigna a esta lección, y se comprueba con una lista que puedes pasarle a cualquier `compose.yaml`, tuyo o ajeno, leyendo su `docker compose config`:

- Cada puerto publicado lleva `host_ip: 127.0.0.1` (Lección 2), y lo que no necesita puerto no lo publica.
- Cada servicio lleva `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges` e `init: true` (Lección 7), y límites de memoria, CPU y procesos (Lección 2).
- Las imágenes llevan versión, nunca `latest` (Lección 3), y las que construyes tú no se buscan en internet (`pull_policy: never`).
- Lo que escribe, escribe en un volumen con nombre montado justo donde hace falta (Lección 8).
- Lo que no necesita internet vive en una red `internal: true`, y no hay `network_mode: host` (Lección 8).
- Ningún valor secreto en `environment`, en `build.args` ni en el propio archivo: los secretos van en `secrets:`, desde archivos que no se suben al repositorio, y `grep` del valor en `docker compose config` y en `docker inspect` da cero (Lección 6 y esta).

El accidente que evita es el de la escena: que el sistema que corre no sea el que probaste. Un archivo endurecido una vez se endurece para todos los que lo usen; seis comandos endurecidos dependen de que nadie copie el equivocado.

## Lo que se hace mal

**Escribir `version:` arriba del archivo.** Es obsoleto y solo produce un aviso. Y casi siempre delata que el resto del archivo se copió de un tutorial viejo: revísalo con más cuidado.

**Puertos sin `127.0.0.1`.** `"8080:8080"` en un `compose.yaml` es el `-p 8080:8080` de la Lección 2: el puerto abierto a toda tu red. Es lo primero que se pierde al copiar un ejemplo.

**Quitar `read_only` «porque falla».** Si falla, el programa escribe en algún lugar que no previste. Encuentra cuál (el error te lo dice) y monta ahí un volumen o un `tmpfs`.

**`depends_on` sin condición para algo que debe estar listo.** La forma corta solo espera a que el contenedor corra. Si tu servicio necesita a otro sano, `condition: service_healthy`, y que ese otro tenga su revisión de salud.

**`service_healthy` para todo.** Con un servicio que nunca va a estar sano, el que depende de él nunca arranca. Pide salud solo a lo que la necesita.

**El token en `environment:` o en un `.env`.** Queda en `docker inspect` para cualquiera del grupo `docker`. Para eso existe `secrets:`.

**Confiar en `uid`, `gid` y `mode` de un secreto de archivo.** Compose los ignora en silencio. El permiso es el del archivo en tu equipo.

**`build` en varios servicios con la misma `image`.** Una carrera que gana «casi siempre» la otra. Construye en uno y usa la imagen en los demás.

**`docker compose down --volumes` por costumbre.** Borra el reporte. Úsalo cuando quieras empezar de cero, no para apagar.

**Borrar a mano con `docker rm` lo que creó Compose.** Funciona, pero Compose ya no sabe en qué quedó todo. Lo que se crea con Compose se apaga con `docker compose stop` o `docker compose down`.

**Dos proyectos con el mismo nombre.** Dos `compose.yaml` con `name: curso-docker`, aunque estén en carpetas distintas, se pisan entre sí: Compose cree que los contenedores de uno son del otro. Un proyecto, un nombre.

## Ejercicios

Hazlos en orden. Antes de correr cada uno, escribe en tu [bitácora](bitacora.md) lo que crees que va a pasar; compararlo después es la mitad del aprendizaje. Al terminar, deja tu proyecto con el archivo final y apágalo con `docker compose down` (sin `--volumes`, si quieres conservar el reporte).

### Ejercicio 1 — Traduce un `docker run`

Este es el comando del servicio de prueba de la Lección 8, sección 8.10.3:

```text
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Escribe el servicio de Compose equivalente, llamado `prueba`, sin mirar `fig09_01.compose.yaml`. Después di: ¿qué opción del comando **no** tiene clave en tu servicio, y por qué? ¿Qué tendría que existir en el archivo, fuera del servicio, para que tu `networks` funcione?

### Ejercicio 2 — ¿Qué recrea Compose?

Con el sistema final arriba, predice, para cada cambio por separado, qué contenedores dirán `Running` y cuáles `Recreated` en el siguiente `docker compose up -d`. Después compruébalo y vuelve el archivo a su forma final antes del siguiente:

1. Cambias el tiempo de `lento` en `REVISOR_SERVICIOS` de `5s` a `4s`.
2. Cambias `mem_limit: 32m` por `mem_limit: 24m` en el ancla `x-prueba`.
3. No cambias el archivo, pero haces `chmod 600 secretos/revisor_token.txt`.

Pregunta extra: en el caso 3, ¿qué tendrías que hacer para ver el error de 9.10, y qué comando lo deshace?

### Ejercicio 3 — Diagnostica sin correr

Una compañera te manda esto, copiado de su terminal (es el bloque «Ejercicio 3» de `fig09_10.sh`, así que los nombres son los de apoyo y el número del archivo temporal está tapado). El `revisor` dice `healthy` y, sin embargo, su reporte no funciona:

```text
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

1. ¿Los `(unhealthy)` de `prueba-caido` y `prueba-lento` son el problema? ¿Por qué?
2. ¿Qué renglones le faltan con toda seguridad a su `compose.yaml`? ¿Con qué comando lo comprobarías sin abrir el archivo?
3. ¿Qué te dice que el token **sí** está bien?

### Ejercicio 4 — Tu archivo contra el de la guía

Toma el `compose.yaml` de la guía oficial de Python de la sección 9.13 y haz una lista de **todo** lo que tu archivo final tiene y ese no, aplicado al servicio `server`. Para cada diferencia, di qué lección del curso la explica y qué riesgo cierra. Después responde: ¿hay algo en el archivo de la guía que **no** tendrías que cambiar?

## Soluciones

Las soluciones que dicen «medido» salen del guion `fig09_10.sh`, que hace cada cambio a la vista con `sed`, lo comprueba y lo deshace. Su salida completa:

```text
$ ./fig09_10.sh
== Ejercicio 1. Un servicio en una red que no está declarada arriba
$ docker compose config --quiet
service "prueba-lento" refers to undefined network otra: invalid compose project
[código de salida: 1]

== Ejercicio 2.1. lento: de 5s a 4s en REVISOR_SERVICIOS
$ cambios
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started

== Ejercicio 2.2. mem_limit: de 32m a 24m en el ancla x-prueba
$ docker compose config | grep mem_limit
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "67108864"
  mem_limit: 24m
$ cambios
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-prueba-sano-1 Recreated
Container curso-docker-fig09-prueba-lento-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-caido-1 Started

== Ejercicio 2.3. Sin cambiar el archivo: chmod 600 al token
$ cambios
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Running
$ tabla | head -2
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
$ docker compose restart revisor 2>&1 | eventos | grep -v Restarting
Container curso-docker-fig09-revisor-1 Started
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 Started'
Container curso-docker-fig09-revisor-1 Started
revisor: healthy

== Ejercicio 3. El revisor sin volumen en /datos, con los cuatro servicios
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
$ docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes
[código de salida: 1]
$ docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-fig09-revisor-1
/run/secrets/revisor_token 
```

### Solución 1

```yaml
  prueba:
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
```

Es el servicio de `fig09_01.compose.yaml`, salvo el `build` (que el comando de la Lección 8 no traía, porque la imagen ya existía). La opción sin clave es `--name curso-docker-prueba`: el nombre del contenedor lo pone Compose (`curso-docker-prueba-1` en tu carpeta), y los demás lo encuentran por el nombre del **servicio**, `prueba`. `-d` tampoco tiene clave: es una opción del comando (`docker compose up -d`), no del servicio. Para que `networks: [interna]` funcione, la red tiene que estar declarada arriba, en `networks:`; si no, el archivo no es válido. Y para que siga siendo la red sin salida de la Lección 8, esa declaración lleva `internal: true`. Medido: con el ancla apuntando a una red `otra` que no existe arriba, `docker compose config --quiet` responde `service "prueba-lento" refers to undefined network otra: invalid compose project` y sale con `1` (nombra a una de las tres copias que heredan el ancla; puede ser otra en tu corrida). Es el tipo de error que `config` atrapa antes de crear nada.

### Solución 2

Medido (bloques «Ejercicio 2» de `fig09_10.sh`):

1. **Solo el `revisor` se recrea.** `REVISOR_SERVICIOS` es parte de su configuración; los servicios de prueba no cambian y dicen `Running`. Es lo mismo que viste en el bloque 2 de `fig09_03.sh`, con otro cambio.
2. **Se recrean las tres copias del servicio de prueba**, y el `revisor` queda en `Running`. Para Compose, lo que cuenta es el resultado de copiar el ancla en los tres servicios, así que cambiar el ancla es cambiar los tres. `docker compose config | grep mem_limit` lo confirma antes de levantar: tres veces `25165824` (24 MB en bytes) y una `67108864` (el `revisor`). El último renglón, `mem_limit: 24m` sin comillas y con menos sangría, es el propio `x-prueba`: `config` conserva los campos `x-` en su salida, aunque no los use para crear nada.
3. **Nada se recrea**: los cuatro en `Running`, y la tabla sigue saliendo. El permiso de un archivo de tu equipo no es parte de la configuración que Compose compara, y el `revisor` ya leyó su token al arrancar, así que sigue funcionando. Para ver el error de 9.10 hay que obligarlo a arrancar de nuevo: `docker compose restart revisor` dice `Started`, y tres segundos después `docker inspect` dice `Status=restarting ExitCode=1`. Lo deshaces devolviendo el permiso anterior (en la carpeta temporal del guion, `644` con el token de mentira; en la tuya, el `640` con grupo `65532` de 9.8.4) seguido de `docker compose up -d --force-recreate revisor`, el mismo comando de 9.10. La lección de este caso: un error de permisos puede estar **dormido** días, hasta el siguiente reinicio.

### Solución 3

1. **No.** Están `unhealthy` porque fallan a propósito: el caído responde `503` y el lento tarda 3 s cuando su revisión exige menos de 2. Es lo esperado, y por eso el `revisor` solo pide `service_healthy` a la sana. El `revisor` está `healthy` porque `/salud` no escribe nada.
2. Le falta el volumen del `revisor` en `/datos`: los dos renglones `volumes:` y `- reportes:/datos` del servicio. Es el bloque 1 de `fig09_03.sh`. Lo compruebas sin abrir el archivo con `docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes`, que no encuentra nada y sale con `1`; o, sobre el contenedor, con `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-revisor-1`, que muestra `/run/secrets/revisor_token` y no muestra `/datos`. Las dos cosas están en la salida de `fig09_10.sh`.
3. Que la respuesta **no** es `401`. Con el token equivocado o ausente, el `revisor` contesta `{"error":"falta el token o no es válido"}` antes de intentar nada. Aquí pasó esa revisión y falló al guardar. Y si el archivo del token estuviera en `600`, el `revisor` ni siquiera estaría `Up`: estaría reiniciándose (9.10).

### Solución 4

Lo que tu archivo tiene y el de la guía no, en el servicio:

- **`127.0.0.1` en el puerto** (Lección 2). `8000:8000` publica en todas las interfaces de tu equipo; cualquiera de tu red llega al servicio.
- **`image:` con nombre y versión** (Lección 3). Sin ella, el nombre de la imagen lo decide Compose y no dice qué versión corre.
- **`read_only`, `cap_drop`, `no-new-privileges` e `init`** (Lección 7). Sin ellos, quien tome control del proceso puede escribir en el disco del contenedor, usar las capacidades de `root` que Docker deja por omisión y ganar privilegios con un programa *setuid*; y un programa que no sabe ser el proceso 1 no se apaga bien.
- **Límites de memoria, CPU y procesos** (Lección 2). Sin ellos, un error del programa puede tomar todo el equipo.
- **`restart`** (Lección 7). Sin política, si el proceso muere se queda muerto.
- **Redes propias, con la interna sin salida** (Lección 8). La guía usa la red por omisión del proyecto, con salida a internet para todos.
- **Un volumen con nombre donde escribe** (Lección 8). En ese ejemplo no hace falta porque la aplicación no guarda nada; el día que guarde, lo necesitará.
- **`secrets:`** (Lección 6 y esta). La guía de la que sale el ejemplo agrega más adelante una base de datos con su contraseña como secreto: el patrón es el mismo.

Lo que no cambiarías: `build` con `context: .`, que es exactamente lo que hace tu `revisor`, y la ausencia de `version:`. Y una aclaración justa: la etapa final del Dockerfile de esa guía corre sin `root` por omisión, según dice la propia página, así que el `USER` de la Lección 3 está resuelto en su Dockerfile, no en el `compose.yaml`. Un archivo generado no es malo: es un punto de partida, y tu trabajo es llevarlo hasta aquí.

## Cómo sé que lo logré

Marca cada punto solo si puedes hacerlo **sin volver a ver el texto**:

- [ ] En tu carpeta `revisor/`, `docker compose config --quiet && echo 'compose.yaml válido'` imprime `compose.yaml válido`, y `grep -c '^version' compose.yaml` da `0`.
- [ ] `docker compose up -d --build` levanta los cuatro servicios desde cero, `docker compose ps` muestra `curso-docker-revisor-1` en `(healthy)` con `127.0.0.1:8080->8080/tcp`, y en los eventos de `up` aparece `prueba-sano-1 Healthy` **antes** de `revisor-1 Started`.
- [ ] La tabla del `revisor`, pedida con el token, muestra `caido FALLA`, `lento LENTO` y `sano OK`, sin que hayas cambiado ningún modo a mano.
- [ ] `docker inspect curso-docker-revisor-1 | grep -c "$(cat secretos/revisor_token.txt)"` da `0`, y lo mismo con `docker compose config`.
- [ ] Explicas por qué el `revisor` espera con `service_healthy` solo a `prueba-sano`, usando las palabras *salud*, *503* y *2 segundos*.
- [ ] Provocas el `read-only file system` quitando el volumen de `/datos`, y el `permission denied` del secreto con `chmod 600`, y explicas por qué `uid`, `gid` y `mode` no lo evitan.
- [ ] Con `stat -c '%a %U:%G'` y `sudo -u nobody cat` compruebas que tu `secretos/revisor_token.txt` **no** lo lee otra cuenta, y que el `revisor` sí (`640` con grupo `65532`, o `600` con dueño `65532`); y `git check-ignore -v secretos/revisor_token.txt` dice que el `.gitignore` de tu proyecto lo cubre.
- [ ] Después de `docker compose down` (sin `--volumes`), `docker run --rm -v curso-docker_reportes:/datos:ro alpine:3.24.2 ls -ln /datos` muestra `reporte.json` de `65532`.
- [ ] `docker compose stop revisor` tarda menos de un segundo y deja `ExitCode=0`.
- [ ] Corres los guiones de [`programas/09-compose/`](../programas/09-compose) (con tu proyecto apagado, o con otro puerto: `PUERTO=18080 ./fig09_05.sh`; la función `nombres` reescribe el puerto en la salida) y tus salidas coinciden con las de esta lección, salvo los tiempos, las fechas, el número del archivo temporal, el orden de los eventos simultáneos, el servicio que nombra el error del Ejercicio 1 y los intentos y servicios del choque de 9.11. Y al terminar, `docker ps -a --filter name=fig09`, `docker volume ls --filter name=fig09` y `docker network ls --filter name=fig09` no muestran nada.

## Resumen

Responde sin mirar la lección:

1. ¿Qué diferencia hay entre un servicio y un contenedor, y qué nombre usan los demás contenedores para encontrar uno?
2. ¿De dónde sale el nombre de un proyecto, en qué orden se decide, y cómo se ve en los nombres de contenedores, redes y volúmenes?
3. ¿Qué hace `docker compose config`, y qué te enseñó sobre `depends_on: [prueba]` y sobre `"127.0.0.1:8080:8080"`?
4. ¿Por qué pedir `docker compose up -d` dos veces no hace nada la segunda vez, y qué hace cuando cambias un servicio?
5. ¿Por qué el `revisor` con `read_only: true` necesita siempre algo montado en `/datos`?
6. ¿Para qué sirven juntos un campo `x-` y un ancla de YAML?
7. ¿Qué diferencia hay entre `service_started` y `service_healthy`, y por qué no se puede pedir `service_healthy` a `prueba-caido`?
8. ¿Dónde aparece un secreto de Compose dentro del contenedor, y por qué un archivo en `600` da `permission denied` aunque declares `uid`, `gid` y `mode`? ¿Quién puede leer el mismo archivo con `644`, y cómo lo dejas para que lo lean el `revisor` y tú, pero nadie más?
9. ¿Por qué solo un servicio de prueba lleva `build`, y qué hace `pull_policy: never` en los otros dos?
10. ¿Qué borra `docker compose down`, qué agrega `--volumes`, y por qué `up --wait` falla en este proyecto aunque todo funcione?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [Docker, «Docker Compose»](https://docs.docker.com/compose/): qué es Compose.
- [Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/): el nombre `compose.yaml` (preferido) y los nombres heredados; qué es un proyecto; servicios, redes, volúmenes, configuraciones y secretos.
- [Especificación de Compose](https://docs.docker.com/reference/compose-file/): el documento que define las claves del archivo y sus elementos de primer nivel.
- [Especificación, `version` y `name`](https://docs.docker.com/reference/compose-file/version-and-name/): que `version` es solo informativo y produce un aviso de obsoleto; `name` como nombre del proyecto.
- [Referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/): `depends_on` y sus tres condiciones; `pull_policy: never`; `read_only`, `cap_drop`, `security_opt` y las tres formas de `no-new-privileges`; `init`; `mem_limit`, `cpus`, `pids_limit`; `restart`; `image` junto a `build`; la forma larga de `secrets` y que con un archivo como fuente `uid`, `gid` y `mode` se ignoran en silencio.
- [Especificación, extensiones](https://docs.docker.com/reference/compose-file/extension/): que Compose ignora los campos que empiezan con `x-` y que sirven para reutilizar configuración.
- [Especificación, fragmentos](https://docs.docker.com/reference/compose-file/fragments/): anclas, alias y la clave de mezcla `<<`; que la mezcla solo aplica a mapas; `environment` como mapa al usar fragmentos.
- [Docker, «Specify a project name»](https://docs.docker.com/compose/how-tos/project-name/): el orden en que se decide el nombre del proyecto, los caracteres que admite y que sirve para aislar entornos.
- [Docker, «Networking in Compose»](https://docs.docker.com/compose/how-tos/networking/): la red `<proyecto>_default`, el nombre de servicio en el DNS y las redes propias con `networks`.
- [Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/): que Compose no espera a que un contenedor esté listo, solo corriendo; `service_healthy`; el orden de borrado por dependencias; `restart: true` dentro de `depends_on`.
- [Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/): qué es un secreto, la ruta `/run/secrets/<nombre>`, que Docker crea un montaje (`bind mount`) en esa ruta, que el acceso se controla con los permisos normales del sistema de archivos y que solo lo recibe el servicio al que se le concede.
- [Especificación, `secrets` de primer nivel](https://docs.docker.com/reference/compose-file/secrets/): que el secreto se crea con el contenido del archivo de `file` (o con una variable de entorno de `environment`).
- [Referencia de `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/): que muestra el modelo que se aplicará, en forma canónica; `--quiet`, `--services`, `--volumes`.
- [Referencia de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/): qué hace `up`; que recrea al cambiar configuración o imagen y conserva los volúmenes; `-d`, `--build`, `--wait`, `--wait-timeout`, `--no-recreate`.
- [Referencia de `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/): qué borra por omisión y qué agrega `--volumes`.
- [Referencia de `docker init`](https://docs.docker.com/reference/cli/docker/init/): que lo proporciona Docker Desktop, los archivos que crea y sus plantillas.
- [Docker, «Containerize a Python application»](https://docs.docker.com/guides/python/containerize/): el `compose.yaml` de un servicio usado en 9.13 y el Ejercicio 4.
- [Docker, «Retired features»](https://docs.docker.com/retired/): que Compose v1 ya no se mantiene y hay que migrar a Compose v2.
- [Docker, «Announcing Compose V2 General Availability»](https://www.docker.com/blog/announcing-compose-v2-general-availability/): el cambio de guion bajo a guion en los nombres de los contenedores y la advertencia de no depender de ellos.
- [Especificación, `models`](https://docs.docker.com/reference/compose-file/models/): el elemento de primer nivel para modelos de IA, mencionado en 9.1.1.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones y fechas de «Sobre las corridas».
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **ancla y alias** (YAML) | `&nombre` marca un bloque; `*nombre` se refiere a él; `<<: *nombre` copia sus claves dentro de otro mapa |
| **bloque plegado** (YAML) | `>-`: junta varios renglones en uno, con espacios, y quita el salto final |
| **campo `x-`** | campo de primer nivel que Compose ignora; se usa para guardar bloques reutilizables |
| **Compose** | la herramienta (`docker compose`) que lee un `compose.yaml` y crea, recrea o borra lo necesario para que exista lo que describe |
| **`depends_on`** | orden de arranque entre servicios, con una condición: `service_started`, `service_healthy` o `service_completed_successfully` |
| **forma canónica** | la versión larga y completa del archivo, con todos los valores por omisión escritos; la muestra `docker compose config` |
| **proyecto** | un despliegue de un `compose.yaml`; su nombre va delante de todo lo que Compose crea |
| **secreto de Compose** | archivo que Compose monta de solo lectura en `/run/secrets/<nombre>`, solo en los servicios que lo piden |
| **servicio** | la receta de un contenedor en el `compose.yaml`; su nombre es el que se usa en el DNS del proyecto |

---

**Siguiente:** [Lección 10 — Entregar la imagen](10-entregar-la-imagen.md)
