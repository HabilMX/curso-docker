# Lección 5 — Multi-stage: de gigabytes a megabytes

Son las 7:50 de la mañana y la sucursal abre a las 9. El `revisor` tiene que quedar instalado antes de esa hora en el servidor del cuarto de comunicaciones, que se conecta al resto del mundo por un enlace modesto. Lanzas la descarga de la imagen y la barra avanza a ritmo de gotero: la imagen pesa 1.32 GB. Mientras esperas, llega un mensaje de la persona de seguridad que revisa cada instalación: «Antes de que la arranques, ¿me explicas por qué esa imagen trae `gcc`, `git`, `curl`, `apt-get` y un *shell*? El `revisor` es un solo programa. Si alguien logra meterse a ese contenedor, le estás dejando un taller completo: con qué descargar herramientas, con qué compilarlas y con qué ejecutarlas». Tienes cuarenta minutos y dos problemas que parecen distintos: la imagen es enorme y la imagen es peligrosa. Esta lección te enseña que son el mismo problema, y que se arregla con un solo Dockerfile mejor escrito: la imagen que sale de aquí pesa 16.1 MB, no tiene *shell* y no corre como `root`.

**Tiempo:** 2 × 45 min

**Qué construyes:** la imagen final del `revisor`, `curso-docker-revisor:1.2.0`: un Dockerfile de cuatro etapas que compila y prueba en una imagen grande y entrega en una mínima, con la base fijada por versión y por *digest*. Pesa 16.1 MB, no tiene *shell* ni compilador y corre con el usuario sin privilegios 65532.

**Qué aprendes:** qué es una construcción en varias etapas (*multi-stage*) y cómo se pasan archivos de una etapa a otra con `COPY --from`; cómo poner las pruebas dentro de la construcción para que una prueba rota la detenga, y el error silencioso que la salta; qué es una imagen base mínima sin *shell* (*distroless*) y qué cambia al operarla; qué es un *digest* y por qué se fija la base con él además de con la etiqueta; y por qué un binario que no es estático no arranca en una imagen mínima, con el mensaje exacto que vas a ver.

**De dónde vienes.** De la [Lección 4](04-capas-cache-contexto.md) traes la imagen `curso-docker-revisor:1.1.0`: el mismo `revisor` de la Lección 3, pero con el Dockerfile ordenado para la caché (primero `go.mod`, después el código) y con la caché de compilación de Go en un montaje que no queda dentro de la imagen. Sabes leer `docker history`, sabes qué es una capa y qué viaja en el contexto. Traes también un número anotado en tu bitácora: esa imagen pesa **1.32 GB**. De la [Lección 3](03-primer-dockerfile.md) traes `USER`, la forma *exec* y la carpeta `~/curso-docker/revisor`, donde vive tu proyecto. Y de la [Lección 2](02-contenedores-dia-a-dia.md) traes un recuerdo: intentaste entrar con `docker exec` al servicio de prueba y no había `sh`. Aquí vas a entender por qué, y vas a hacerle lo mismo al `revisor`.

**Qué no hace esta lección.** No toca el código del `revisor` ni le agrega funciones: el programa es el mismo de las Lecciones 3 y 4. No le pone versión al binario (por eso `revisor version` todavía dice `desarrollo`; la versión y la configuración son de la [Lección 6](06-configuracion-y-secretos.md)). No le agrega `HEALTHCHECK` ni lo endurece al correr (sistema de archivos de solo lectura, capacidades fuera): eso es la Lección 7. Y no construye para varias plataformas ni escanea vulnerabilidades: eso es la Lección 10. Aquí el trabajo es uno solo: que lo que se **entrega** sea solo lo que se **necesita para correr**.

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4, la misma base de Linux Mint 22, el sistema de referencia del curso. Los guiones se corrieron **dentro** de esa máquina virtual, con Docker 29.2.1 (cliente y daemon) y Buildx v0.31.1. El curso se planeó con Docker Engine 29.8.2, y la versión más reciente publicada ese día era la 29.9.2, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)); nada de esta lección cambia entre esas versiones. La misma máquina la usaban al mismo tiempo otras corridas del curso, así que, para no chocar, cada guion se lanzó con otro prefijo de nombres y otro puerto, con las variables `PREFIJO` y `PUERTO` que todos traen, y la salida se guardó pasando por un `sed` que devuelve los nombres del curso. El comando fue, para cada figura: `PREFIJO=curso-docker-l05- PUERTO=18050 ./fig05_NN.sh 2>&1 | sed -e 's/curso-docker-l05-/curso-docker-/g' -e 's/127\.0\.0\.1:18050/127.0.0.1:8080/g'`. Tú no necesitas nada de eso: sin variables, los guiones usan los nombres y el puerto del curso, y lo que imprimen es lo que ves aquí. Lo que **sí** cambia en tu Mint, y se avisa donde aparece: los números de proceso (PID), los tiempos, las fechas de los archivos y, si tu equipo es Intel o AMD, la arquitectura: donde aquí dice `arm64` o `aarch64`, en el tuyo dirá `amd64` o `x86_64`, y los tamaños pueden variar unos megabytes. Los programas están en [`programas/05-multi-stage/`](../programas/05-multi-stage), cada uno con su salida al lado; `inicio/` guarda el `Dockerfile` y el `.dockerignore` con los que termina la Lección 4, y `estado/`, los que quedan al terminar esta.

## Al terminar vas a poder

- Explicar, con los números de tu propia imagen, por qué una imagen de una sola etapa pesa más de un gigabyte cuando el programa que lleva pesa menos de diez megabytes.
- Escribir un Dockerfile de varias etapas con nombre (`FROM ... AS`), pasar un archivo de una etapa a otra con `COPY --from` y construir solo hasta una etapa con `--target`.
- Poner las pruebas dentro de la construcción de modo que una prueba rota la detenga, y demostrar con una corrida por qué la etapa del binario debe salir de la etapa de pruebas y no de la de compilación.
- Mostrar con `docker exec`, `docker inspect` y `docker top` que la imagen final no tiene *shell* y no corre como `root`, y listar todos sus archivos sin entrar a ella.
- Fijar una imagen base por etiqueta y por *digest*, y decir qué garantiza cada una.
- Leer el mensaje `exec /revisor: no such file or directory`, explicar qué archivo es el que falta y arreglarlo con `CGO_ENABLED=0`.

## El porqué antes del cómo

En la Lección 3 construiste el `revisor` en una sola etapa: partiste de la imagen de Go, copiaste el código, compilaste y le dijiste a Docker qué correr. Funciona, y era la forma correcta de empezar porque todo estaba a la vista. Pero esa receta tiene un defecto de diseño que ningún ajuste de orden arregla: **la imagen que sirve para construir y la imagen que se entrega son la misma**. Todo lo que hizo falta para compilar —el compilador de Go, el de C, Debian completo con su gestor de paquetes, las herramientas de red— se queda dentro de la imagen que va al servidor, aunque el `revisor` no use nada de eso al correr.

Eso cuesta en tres lugares a la vez, y la escena del principio los junta:

1. **En tiempo y en disco.** Cada servidor que corra el `revisor` descarga y guarda más de un gigabyte. En un enlace lento, eso es la diferencia entre llegar o no llegar a las 9.
2. **En seguridad.** Cada programa que viaja en la imagen es algo que un intruso puede usar. Un contenedor con *shell*, `curl` y un compilador le ahorra a quien entra casi todo el trabajo. Un contenedor que solo tiene el `revisor` no le deja nada con qué seguir.
3. **En ruido.** Un escáner de vulnerabilidades revisa todos los paquetes de la imagen. Si la imagen trae doscientos paquetes de Debian que el `revisor` nunca toca, el reporte se llena de hallazgos que no importan y esconde los que sí. El propio proyecto de las imágenes mínimas de Google lo dice así: una imagen sin lo que sobra «mejora la relación señal-ruido de los escáneres» ([distroless](https://github.com/GoogleContainerTools/distroless)).

La solución que vas a construir separa los dos trabajos: una imagen grande para **construir y probar**, que nunca sale de tu equipo, y una imagen mínima para **correr**, que es la que se entrega. Las dos se describen en el mismo Dockerfile, y el paso de una a otra es un solo renglón: copiar el binario. La documentación de Docker lo resume en una frase: con las construcciones en varias etapas «puedes copiar selectivamente artefactos de una etapa a otra, dejando atrás todo lo que no quieres en la imagen final» ([Docker, «Multi-stage builds»](https://docs.docker.com/build/building/multi-stage/)).

La lección tiene ocho partes, en este orden:

1. **Lo que hay dentro de 1.32 GB** (5.1): medir antes de achicar.
2. **La idea de las etapas** (5.2): `FROM ... AS`, `COPY --from` y `--target`.
3. **El Dockerfile de cuatro etapas** (5.3), renglón por renglón.
4. **Construir y medir** (5.4): de 1.32 GB a 16.1 MB.
5. **Las pruebas dentro de la construcción** (5.5), con el error silencioso de esta lección.
6. **La base mínima** (5.6): sin *shell* y sin `root`.
7. **Versión y *digest*** (5.7): fijar la base de verdad.
8. **El binario que no arranca** (5.8), el error principal de la lección.

Con ese destino en mente, esto es lo que vas a ver en la sección 5.4, cuando pongas lado a lado la imagen con la que llegas y la que construyes aquí:

```text
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB
```

## Los conceptos

### 5.1 Lo que hay dentro de 1.32 GB

#### 5.1.1 Medir antes de achicar

Antes de cambiar una sola línea, conviene saber qué hay en la imagen y qué parte de ese peso es el `revisor`. Achicar sin medir es adivinar. El programa `fig05_01.sh` construye la imagen de la Lección 4 desde `inicio/` y le pregunta tres cosas: cuánto pesa el `revisor`, qué otras herramientas viajan con él y cuánto ocupan las carpetas más pesadas:

```bash
#!/usr/bin/env bash
# fig05_01.sh — Qué hay dentro de la imagen con la que termina la Lección 4.
# La construye desde inicio/ (el Dockerfile y el .dockerignore de la Lección 4),
# mide su tamaño y busca adentro lo que el revisor necesita para correr y lo que
# no. Borra lo que crea al salir.
set -euo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/inicio/Dockerfile" "$AQUI/inicio/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

titulo() { printf '\n## %s\n' "$*"; }
# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
IMAGEN="${PREFIJO}revisor:1.1.0"
MIRAR="docker run --rm --name ${PREFIJO}mirar $IMAGEN"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "La imagen de la Lección 4"
muestra "docker build -q -t $IMAGEN . >/dev/null && docker image ls $IMAGEN --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Lo único que el revisor necesita para correr"
muestra "$MIRAR ls -lh /usr/local/bin/revisor"

titulo "Lo demás que viaja con él"
muestra "$MIRAR sh -c 'for p in sh bash apt-get gcc go git curl; do printf \"%-8s %s\n\" \$p \"\$(command -v \$p || echo no-esta)\"; done'"
muestra "$MIRAR du -sh /usr/local/go /usr/lib /usr/bin /usr/share"
muestra "$MIRAR sh -c 'dpkg-query -W | wc -l'"
muestra "$MIRAR id"
```

Antes de la salida, los renglones nuevos del guion. La estructura es la misma de los guiones de la Lección 3: se arma el proyecto en una carpeta temporal (`mktemp -d`) con el código que entrega el curso más los archivos de la lección, se definen las ayudas `titulo` y `muestra` (que imprime cada comando con `$ ` delante antes de ejecutarlo, para que sepas qué produjo cada renglón), y un `trap ... EXIT` borra la imagen y la carpeta al salir. El `sed` del principio cambia el nombre de la caché de compilación solo si cambias el `PREFIJO`; con el valor por omisión, no cambia nada. `MIRAR` es una abreviatura para no repetir `docker run --rm --name ... imagen` en cada pregunta.

```text
$ ./fig05_01.sh

## La imagen de la Lección 4
$ docker build -q -t curso-docker-revisor:1.1.0 . >/dev/null && docker image ls curso-docker-revisor:1.1.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB

## Lo único que el revisor necesita para correr
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 ls -lh /usr/local/bin/revisor
-rwxr-xr-x 1 root root 9.5M Oct 21 08:46 /usr/local/bin/revisor

## Lo demás que viaja con él
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'for p in sh bash apt-get gcc go git curl; do printf "%-8s %s\n" $p "$(command -v $p || echo no-esta)"; done'
sh       /usr/bin/sh
bash     /usr/bin/bash
apt-get  /usr/bin/apt-get
gcc      /usr/bin/gcc
go       /usr/local/go/bin/go
git      /usr/bin/git
curl     /usr/bin/curl
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 du -sh /usr/local/go /usr/lib /usr/bin /usr/share
277M	/usr/local/go
276M	/usr/lib
120M	/usr/bin
140M	/usr/share
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'dpkg-query -W | wc -l'
208
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 id
uid=10001 gid=10001 groups=10001
```

La fecha y la hora del archivo cambian en cada construcción; en un equipo Intel o AMD los tamaños pueden variar unos megabytes. Lo demás sale igual.

#### 5.1.2 Leer los números

Pon los números en una sola frase y el problema se ve solo: **el `revisor` pesa unos 10 MB y viaja en una imagen de 1.32 GB**. Menos del uno por ciento de lo que se descarga es el programa que vas a correr. El 99 % restante es equipaje:

- **El compilador de Go**, en `/usr/local/go`: 277 MB. (`ls -lh` y `du -sh` cuentan en potencias de 1024: el `9.5M` del `revisor` son 9.5 MiB, unos 10 MB; `docker image ls` cuenta en potencias de 1000.) Hizo falta para compilar; al correr, el `revisor` no lo usa ni una vez.
- **Un Debian casi completo**: 208 paquetes instalados (`dpkg-query -W` lista uno por renglón y `wc -l` los cuenta), con sus bibliotecas en `/usr/lib` y sus programas en `/usr/bin`.
- **Las herramientas que preocupaban a la persona de seguridad de la escena**: un *shell* (`sh` y `bash`), un gestor de paquetes (`apt-get`), un compilador de C (`gcc`), `git` y `curl`. Cada una está ahí por una buena razón para **construir**: la imagen oficial de Go las trae para que compilar funcione con casi cualquier proyecto. Para **correr** el `revisor`, ninguna.

La última línea es un buen recordatorio de que la Lección 3 no fue en vano: la imagen corre con el usuario `10001`, no con `root`. Pero ese usuario tiene a la mano `curl` para descargar lo que quiera y `sh` para ejecutarlo. Sin privilegios, sí; desarmado, no.

Fíjate también en lo que **no** está en la lista: nada de esto se arregla borrando archivos. Si agregas al Dockerfile un `RUN rm -rf /usr/local/go`, la imagen no baja ni un byte: la Lección 4 te enseñó que cada instrucción agrega una capa encima de las anteriores, y que lo que una capa borra sigue guardado en la capa de abajo. Borrar en una capa nueva solo esconde. Para que el compilador no viaje, la imagen final tiene que **nacer sin él**.

> [!NOTE]
> 🔧 **Observación de ingeniería 5.1**
> Mide antes de optimizar, y mide la proporción, no solo el total. «La imagen pesa 1.32 GB» invita a buscar dónde recortar. «El programa es menos del 1 % de la imagen» te dice que no hay nada que recortar: hay que cambiar de imagen.

### 5.2 La idea de las etapas

#### 5.2.1 Varios `FROM` en un mismo Dockerfile

Hasta ahora cada Dockerfile tenía un solo `FROM`, y todo lo que venía después se apilaba sobre esa base. La idea central de esta lección es que **un Dockerfile puede tener varios `FROM`**. Cada `FROM` empieza una **etapa** nueva, desde cero, con su propia base. La referencia del Dockerfile lo dice así: `FROM` «puede aparecer varias veces en un mismo Dockerfile» para crear varias imágenes o para usar una etapa como dependencia de otra ([referencia del Dockerfile, `FROM`](https://docs.docker.com/reference/dockerfile/#from)).

Lo que hace útil esa idea son tres piezas, que vas a ver en un fragmento de cuatro renglones antes del Dockerfile completo:

```dockerfile
FROM golang:1.27.3-trixie AS compilacion
RUN ... go build -o /out/revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=compilacion /out/revisor /revisor
```

Este bloque es un fragmento para leer, no un programa: le faltan renglones para construirse. Lo que muestra:

1. **El nombre de la etapa.** `AS compilacion`, al final del `FROM`, le pone nombre a la etapa. La documentación recomienda nombrarlas así, en lugar de referirse a ellas por número ([Docker, «Name your build stages»](https://docs.docker.com/build/building/multi-stage/#name-your-build-stages)). Un nombre sobrevive a que alguien agregue o quite etapas; un número no.
2. **La copia entre etapas.** `COPY --from=compilacion` copia un archivo **desde otra etapa**, no desde el contexto. La referencia aclara que `--from` acepta una etapa, una imagen o un contexto con nombre ([referencia, `COPY --from`](https://docs.docker.com/reference/dockerfile/#copy---from)). Aquí, la etapa de compilación deja el binario en `/out/revisor` y la última etapa lo recoge.
3. **La imagen que sale.** La imagen que construye `docker build` es la de la **última** etapa. Todo lo que pasó en las anteriores —el compilador, el código fuente, la caché— se queda atrás. Esa es la frase de la documentación: copiar lo que quieres y dejar atrás lo que no.

Si vienes de programar, una comparación ayuda: una etapa es como una función que devuelve un valor. La etapa de compilación «devuelve» un archivo; la etapa final solo recibe ese archivo, no las variables locales con que se calculó.

#### 5.2.2 Construir hasta una etapa: `--target`

La segunda herramienta es poder construir **solo hasta** una etapa. `docker build --target pruebas` construye la etapa llamada `pruebas` (y las que esa necesite) y se detiene ahí; la imagen que resulta es la de esa etapa, no la final ([Docker, «Stop at a specific build stage»](https://docs.docker.com/build/building/multi-stage/#stop-at-a-specific-build-stage); en la referencia de la línea de comandos, `--target` es «la etapa de construcción a construir», [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)). Sirve para dos cosas que vas a usar en esta lección: correr solo las pruebas, y mirar por dentro una etapa intermedia que sí tiene herramientas.

#### 5.2.3 Lo que BuildKit construye y lo que no

La tercera pieza es la menos conocida y la que más sorpresas da. El constructor de Docker, BuildKit, no construye todas las etapas del archivo en orden: **construye solo las etapas de las que depende la etapa que pediste**. La documentación lo dice sin rodeos: «BuildKit solo construye las etapas de las que depende la etapa objetivo» ([Docker, «Differences between legacy builder and BuildKit»](https://docs.docker.com/build/building/multi-stage/#differences-between-legacy-builder-and-buildkit)). Una etapa que nadie necesita, no corre.

Eso es una ventaja (no se pierde tiempo en lo que no hace falta) y una trampa, que vas a provocar en 5.5: si las pruebas viven en una etapa de la que la imagen final no depende, BuildKit no las corre, y la construcción sale verde con una prueba rota adentro. Guarda esa frase; es la clave del error silencioso de esta lección.

### 5.3 El Dockerfile de cuatro etapas, renglón por renglón

#### 5.3.1 La receta completa

Este es el Dockerfile con el que termina la lección. Reemplaza al de la Lección 4 en tu carpeta, y el `.dockerignore` no cambia:

```dockerfile
# syntax=docker/dockerfile:1
# fig05_02.Dockerfile — Lección 5: multi-stage: compilar y probar en una imagen grande, entregar en una mínima.

# --- Etapa 1: el código, sobre la imagen de Go (fijada por versión Y por digest) ---
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

# --- Etapa 2: las pruebas. Si fallan, la construcción se detiene aquí ---
FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

# --- Etapa 3: el binario, estático (CGO_ENABLED=0), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

Son cuatro etapas encadenadas, y cada una tiene un solo trabajo:

| Etapa | Parte de | Su trabajo | ¿Viaja en la imagen final? |
|---|---|---|---|
| `compilacion` | la imagen oficial de Go | tener el código listo para compilar | no |
| `pruebas` | `compilacion` | correr `go test ./...` | no |
| `binario` | `pruebas` | producir `/out/revisor`, estático | solo ese archivo |
| `final` | *distroless* `static`, sin *shell* | correr el `revisor` | es la imagen final |

Los nombres de las etapas son los del curso y se repiten en las lecciones que siguen: `compilacion`, `pruebas`, `binario` y `final`. Van sin acento a propósito, porque son identificadores que vas a teclear en `--target` y en `COPY --from`.

#### 5.3.2 Cada renglón en su momento

**La etapa `compilacion`.** Es casi la mitad de arriba del Dockerfile de la Lección 4: la misma base, el mismo `WORKDIR /src` y los mismos tres `COPY` en el orden que la caché agradece (primero `go.mod`, que casi nunca cambia; después el código). Lo único nuevo está en el `FROM`: después de la etiqueta `1.27.3-trixie` viene `@sha256:6041…`, el *digest*, y al final `AS compilacion`. El *digest* tiene sección propia (5.7). Esta etapa no compila nada todavía: solo deja el código en su lugar, para que las dos siguientes partan de él.

**La etapa `pruebas`.** `FROM compilacion AS pruebas` dice «empieza donde terminó `compilacion`». Es la primera vez que ves un `FROM` que no nombra una imagen de internet sino una etapa del mismo archivo. Su único `RUN` corre `go test ./...`, las pruebas de los cinco paquetes del `revisor`, con el mismo montaje de caché de la Lección 4 (el `id=curso-docker-go-build` es el mismo, así que las dos etapas comparten la caché de compilación de Go). Si una prueba falla, `go test` sale con un código distinto de cero, el `RUN` falla y la construcción se detiene: no hay imagen.

**La etapa `binario`.** `FROM pruebas AS binario` es el renglón más importante del archivo, aunque parezca un detalle. Dice que el binario se compila **sobre** la etapa de pruebas, no sobre la de compilación. Por 5.2.3 ya sabes por qué importa: como la etapa final copia desde `binario`, y `binario` sale de `pruebas`, BuildKit está obligado a correr las pruebas para llegar a la imagen final. Si `binario` saliera de `compilacion`, las pruebas quedarían fuera del camino y nadie las correría. Lo vas a medir en 5.5.

El `RUN` de esta etapa trae tres cosas nuevas en el comando de Go:

- **`CGO_ENABLED=0`** pide un binario **estático**: uno que no depende de bibliotecas del sistema para arrancar. Es la pieza que hace posible la etapa final, y quitarla es el error principal de la lección (5.8).
- **`-trimpath`** quita del binario las rutas de la máquina donde se compiló (aquí, `/src`): en su lugar quedan los nombres de los módulos ([`go help build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies)). Así el binario no depende de en qué carpeta lo compilaste ni la revela.
- **`-ldflags="-s -w"`** le pasa dos opciones al enlazador de Go: `-s` «omite la tabla de símbolos y la información de depuración», y `-w` «omite la tabla de símbolos DWARF» ([cmd/link](https://pkg.go.dev/cmd/link)). Eso es lo que usarías con un depurador; un servicio en producción no lo necesita, y quitarlo hace el archivo más chico. (`-s` ya implica `-w`, según esa misma documentación; se escriben las dos por costumbre, y así las vas a ver en casi todos los Dockerfile de Go.) Compara: el binario de la Lección 4 medía 9.5 MiB según `ls -lh`, unos 10 MB; este va a medir 6.68 MB (6,684,832 bytes). Parte de la diferencia es `-s -w`, y parte es que ya no lleva el código de *cgo* (5.8).

El binario queda en `/out/revisor`, una carpeta que solo existe para eso: tener un lugar fijo y limpio de donde la etapa final lo recoja.

**La etapa `final`.** Empieza desde cero sobre `gcr.io/distroless/static-debian13:nonroot`, fijada por *digest*. De todo lo anterior, solo trae un archivo: `COPY --from=binario /out/revisor /revisor`. Después:

- `USER 65532:65532` es el usuario `nonroot` que la propia imagen *distroless* trae en su `/etc/passwd`; lo vas a ver con tus ojos en 5.4. Desde aquí, el curso deja el `10001` de las imágenes de una etapa y usa el `65532`, porque es el que la base ya conoce.
- `EXPOSE 8080` sigue siendo solo una anotación, igual que en la Lección 3.
- **`ENTRYPOINT ["/revisor"]`** reemplaza al `CMD ["revisor"]` de las lecciones anteriores. La diferencia es práctica. La referencia lo explica: los argumentos que escribes después del nombre de la imagen en `docker run` «se agregan después de todos los elementos» de un `ENTRYPOINT` en forma *exec*, y en cambio «reemplazan todo lo que diga `CMD`» ([referencia, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). Con `ENTRYPOINT`, `docker run curso-docker-revisor:1.2.0 version` ejecuta `/revisor version`: la imagen se comporta como el programa, y sus subcomandos (`version`, y en la Lección 7 `healthcheck`) se piden igual que en la terminal. Con el `CMD` de antes, ese `version` habría reemplazado al programa entero y Docker habría intentado ejecutar un archivo llamado `version`. Sigue en forma *exec*, por todo lo que mediste en la Lección 3. Y la ruta va completa, `/revisor`, porque el archivo está en la raíz del sistema de archivos, `/`, que no es ninguna de las carpetas donde el `PATH` de la imagen busca programas.

#### 5.3.3 En tu carpeta

Los guiones del curso trabajan en carpetas temporales y borran lo que crean; tu proyecto vive en `~/curso-docker/revisor` desde la Lección 3. Desde la raíz del repositorio del curso, pon ahí el Dockerfile de esta lección y construye la imagen que vas a conservar:

```bash
cp programas/05-multi-stage/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q -t curso-docker-revisor:1.2.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

El `.dockerignore` de la Lección 4 se queda como está. La imagen `1.1.0` también puede quedarse, para que compares; cuando ya no la quieras, `docker rmi curso-docker-revisor:1.1.0`.

### 5.4 Construir y medir

#### 5.4.1 La construcción, etapa por etapa

`fig05_03.sh` construye las dos imágenes —la de la Lección 4, para comparar, y la de esta— y le hace a la nueva cinco preguntas: qué pasos de qué etapa corrieron, cuánto pesa, de qué capas está hecha, de dónde sale su tamaño y qué archivos trae:

```bash
#!/usr/bin/env bash
# fig05_03.sh — Construir el revisor en cuatro etapas y medir lo que se entrega.
# Construye la imagen de la Lección 4 (para comparar) y la de esta lección,
# muestra qué etapas corrieron, compara tamaños, lee las capas y lista los
# archivos de la imagen final. Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/inicio/Dockerfile" "$TRABAJO/revisor/Dockerfile.leccion4"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.leccion4 && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

VIEJA="${PREFIJO}revisor:1.1.0"
NUEVA="${PREFIJO}revisor:1.2.0"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$VIEJA" "$NUEVA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

docker build -q -t "$VIEJA" -f Dockerfile.leccion4 . >/dev/null

titulo "Construir: qué pasos de qué etapa corrieron"
muestra "docker build --progress=plain -t $NUEVA . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[\$0]++'"

titulo "Antes y después"
muestra "docker image ls --filter reference='${PREFIJO}revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Las capas de la imagen nueva"
muestra "docker history $NUEVA --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90"

titulo "De dónde salen los 16.1 MB"
muestra "docker history $NUEVA --format '{{.Size}}' --human=false | awk '{s+=\$1} END {print \"suma de las capas desempacadas:\", s, \"bytes\"}'"
muestra "docker image inspect $NUEVA --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'"

titulo "Todos los archivos de la imagen nueva"
docker create --name "${PREFIJO}mirar" "$NUEVA" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -v '/\$' | wc -l"
muestra "docker export ${PREFIJO}mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo"
muestra "docker export ${PREFIJO}mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |\$)|/?(revisor|passwd)\$' || echo '(nada más)'"
muestra "docker export ${PREFIJO}mirar | tar -xO etc/passwd"
```

El archivo del repositorio trae las ayudas completas; aquí se resumen en un comentario para no repetirlas. Dos herramientas nuevas: `grep -oE` imprime solo el pedazo de cada renglón que coincide con el patrón (aquí, el número de paso, la etapa y los primeros 60 caracteres de la instrucción), y `awk '!visto[$0]++'` quita los renglones repetidos sin cambiar el orden.

```text
$ ./fig05_03.sh

## Construir: qué pasos de qué etapa corrieron
$ docker build --progress=plain -t curso-docker-revisor:1.2.0 . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[$0]++'
#7 [final 1/2] FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757
#8 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
#10 [compilacion 3/5] COPY go.mod ./
#11 [compilacion 4/5] COPY cmd/ cmd/
#12 [compilacion 5/5] COPY internal/ internal/
#13 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#15 [compilacion 2/5] WORKDIR /src
#16 [final 2/2] COPY --from=binario /out/revisor /revisor

## Antes y después
$ docker image ls --filter reference='curso-docker-revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB

## Las capas de la imagen nueva
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
319kB	bazel build //common:cacerts_debian13_arm64_…
16.4kB	bazel build //common:os_release_debian13
12.3kB	bazel build //static:nsswitch
8.19kB	bazel build //common:tmp
12.3kB	bazel build //common:group
16.4kB	bazel build //common:home
12.3kB	bazel build //common:passwd
4.1kB	bazel build //common:rootfs
160kB	bazel build @trixie//media-types/arm64:data_…
2.15MB	bazel build @trixie//tzdata-legacy/arm64:dat…
2.24MB	bazel build @trixie//tzdata/arm64:data_statu…
86kB	bazel build @trixie//netbase/arm64:data_stat…
741kB	bazel build @trixie//base-files/arm64:data_s…

## De dónde salen los 16.1 MB
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}' --human=false | awk '{s+=$1} END {print "suma de las capas desempacadas:", s, "bytes"}'
suma de las capas desempacadas: 12468224 bytes
$ docker image inspect curso-docker-revisor:1.2.0 --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'
capas comprimidas (las que se descargan): 3679492 bytes

## Todos los archivos de la imagen nueva
$ docker export curso-docker-mirar | tar -t | grep -v '/$' | wc -l
1301
$ docker export curso-docker-mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo
.dockerenv bin boot dev etc home lib proc revisor root run sbin sys tmp usr var 
$ docker export curso-docker-mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |$)|/?(revisor|passwd)$' || echo '(nada más)'
-rw-r--r-- 0/0             149 1969-12-31 18:00 etc/passwd
-rwxr-xr-x 0/0         6684832 2026-10-21 01:55 revisor
$ docker export curso-docker-mirar | tar -xO etc/passwd
root:x:0:0:root:/root:/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin
```

Cambian en cada corrida: los números de paso (`#7`, `#8`…) y su orden, la fecha del archivo `revisor`, y en un equipo Intel o AMD la palabra `arm64` de las capas y los tamaños, por unos kilobytes o megabytes. Lo estable: las cuatro etapas, los dos tamaños en su orden de magnitud, que la suma de las dos cifras de bytes da el tamaño de `docker image ls`, la lista de carpetas y el contenido de `/etc/passwd`.

#### 5.4.2 Leer la construcción

El primer bloque muestra los pasos con su etapa entre corchetes: `[compilacion 4/5]` es el cuarto de los cinco pasos de la etapa `compilacion`. Aparecen las cuatro etapas, y dos detalles enseñan cómo trabaja BuildKit:

- **El orden no es el del archivo.** El `FROM` de la etapa `final` aparece primero (`#7`), antes que todo lo de `compilacion`, y el `WORKDIR` (`[compilacion 2/5]`) sale casi al final, después de los `COPY`. BuildKit arma un grafo con lo que depende de qué y corre en paralelo lo que puede: descargar la base mínima no tiene que esperar a que se copie el código. La etapa final solo espera a `binario` en su segundo paso, el `COPY --from`.
- **Los números de paso no son los de la etapa.** `#13` es un número de BuildKit para esta construcción; `[pruebas 1/1]` es la posición dentro de la etapa. Si corres el guion dos veces, los primeros pueden cambiar y el orden también; las etiquetas entre corchetes, no. (En otra corrida de esta misma lección, con más cosas ya en la caché, BuildKit ni siquiera imprimió los pasos 1 y 2 de `compilacion`; por eso no conviene contar renglones de esta salida, sino leer qué etapas aparecen.)

#### 5.4.3 Leer los tamaños

El segundo bloque es el que justifica la lección: **de 1.32 GB a 16.1 MB**, unas ochenta veces menos. La imagen nueva cabe diecisiete veces en lo que antes ocupaba solo el compilador de Go (277 MB en `/usr/local/go`, en 5.1). Y el tercer bloque, `docker history`, dice qué hay dentro: la capa grande es `COPY /out/revisor /revisor`, de **6.69 MB**, el binario; las demás son de la base *distroless* y suman unos 5.8 MB, la más grande de 2.24 MB (las zonas horarias, `tzdata`). Las capas de la base dicen `bazel build`: es la herramienta con la que Google construye esas imágenes, y en su historial no hay ni un `RUN apt-get`, porque no se armaron instalando paquetes con un gestor. Compara con la Lección 4, donde `docker history` mostraba capas de 290 MB, 281 MB y 208 MB.

Si sumas esas capas a mano, no te dan 16.1 MB, y vale la pena saber por qué antes de que te confunda. El cuarto bloque las suma por ti: **12,468,224 bytes**, unos 12.5 MB. Faltan 3.6 MB. Y la segunda consulta de ese bloque los encuentra: `docker image inspect` reporta **3,679,492 bytes**, y 12,468,224 + 3,679,492 = 16,147,716 bytes, los 16.1 MB de `docker image ls`. La explicación está en cómo guarda las imágenes Docker Engine 29, con el almacén de containerd: según su documentación, ese almacén «guarda las imágenes en formato comprimido y sin comprimir»: conserva las capas comprimidas tal como llegaron del registro **y además** las desempaca en el disco ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)). El número de `docker image ls` cuenta las dos copias; `docker history` cuenta solo las capas desempacadas, y `docker image inspect`, en esta máquina, la parte comprimida, que es lo que se descarga. Para lo que importa en esta lección no cambia nada: compara siempre imágenes con el **mismo** comando, y las dos cifras de `docker image ls` (1.32 GB y 16.1 MB) se midieron igual.

Una pregunta natural es dónde quedaron las etapas `compilacion`, `pruebas` y `binario`. Quedaron en la caché de construcción de tu equipo, que es lo que hace rápida la siguiente construcción, pero **no son parte de la imagen**: `docker history` de `1.2.0` no tiene ni una capa de ellas. Lo único que cruzó de un lado a otro es el archivo que nombra el `COPY --from`.

#### 5.4.4 Mirar adentro sin entrar

La última parte del guion responde la pregunta de la escena: ¿qué hay en esta imagen? Como no tiene *shell* (lo vas a comprobar en 5.6), no puedes entrar a mirar con `docker exec`. Pero sí puedes pedirle a Docker que te dé sus archivos. `docker create` crea un contenedor de la imagen **sin arrancarlo**, y `docker export` saca todo el sistema de archivos de ese contenedor como un archivo `tar`, que `tar -t` lista sin descomprimir. Es la forma de inspeccionar una imagen mínima desde fuera.

Lo que dice:

- **1,301 archivos** en total (`grep -v '/$'` quita las carpetas de la cuenta). Parece mucho, hasta que miras qué son: casi todos son las zonas horarias y los certificados de las autoridades de internet, que un servicio que consulta otros por HTTPS necesita.
- **Las carpetas de primer nivel** son las de cualquier Linux (`bin`, `etc`, `usr`, `var`…), más `revisor` y `.dockerenv`, un archivo vacío que Docker agrega a todo contenedor. Que exista una carpeta `bin` no significa que haya programas dentro.
- **La búsqueda de *shells*** pedía, en cualquier carpeta, un archivo llamado `sh`, `bash`, `dash`, `ash` o `busybox`, además de `revisor` y `passwd` como control: si el patrón estuviera mal escrito, tampoco saldrían esos dos. Salieron los dos de control y ningún *shell*. No hay *shell*, y en 5.6 lo confirmas de otra forma: intentando ejecutarlo. El `revisor` mide 6,684,832 bytes, los 6.69 MB de la capa.
- **La fecha de `/etc/passwd`**, `1969-12-31 18:00`, es la fecha cero del reloj de Unix (el 1 de enero de 1970 en tiempo universal) vista en la zona horaria de la máquina de las corridas. Los archivos de la base llevan esa fecha a propósito: así dos construcciones de la misma base dan exactamente los mismos bytes. El `revisor`, en cambio, lleva la fecha en que se compiló. La que ves aquí es de la madrugada de ese mismo día: el binario salió de la caché de construcción, porque nada de lo que lo produce había cambiado desde la corrida anterior en esa máquina. En la tuya verás otra fecha.
- **El contenido de `/etc/passwd`** tiene tres usuarios, y el tercero es el que usa la etapa final: `nonroot`, con número **65532**. Ahí está la razón del `USER 65532:65532`. Fíjate además en la última columna de los tres: `/sbin/nologin`. Ni siquiera `root` tiene un *shell* asignado.

> [!NOTE]
> 🔧 **Observación de ingeniería 5.2**
> La imagen final no se «limpió»: nació sin lo que sobraba. Es la diferencia entre ordenar un cuarto y mudarse a uno vacío llevando solo una maleta. Lo primero se deshace con el tiempo; lo segundo empieza limpio cada vez que construyes.

### 5.5 Las pruebas dentro de la construcción

#### 5.5.1 Correr solo las pruebas

Que las pruebas vivan en su propia etapa permite correrlas **solas**, sin construir la imagen final. `fig05_04.sh` construye hasta la etapa `pruebas`, obligándola a correr aunque esté en la caché, y mide la imagen intermedia que resulta:

```bash
#!/usr/bin/env bash
# fig05_04.sh — La etapa de pruebas, sola: construye solo hasta «pruebas»,
# obligándola a correr de nuevo, y mide la imagen intermedia que queda.
# Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

PRUEBAS="${PREFIJO}revisor:pruebas"
trap 'docker rmi -f "$PRUEBAS" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Solo hasta la etapa de pruebas"
muestra "docker build --target pruebas --no-cache-filter pruebas --progress=plain -t $PRUEBAS . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[\$0]++'"

titulo "La imagen intermedia: sirve para probar, no para entregar"
muestra "docker image ls $PRUEBAS --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

`--no-cache-filter pruebas` le dice a BuildKit que no use la caché para esa etapa ([docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)): sin eso, como nada cambió, las pruebas saldrían de la caché y no verías ni un renglón de `go test`.

```text
$ ./fig05_04.sh

## Solo hasta la etapa de pruebas
$ docker build --target pruebas --no-cache-filter pruebas --progress=plain -t curso-docker-revisor:pruebas . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[$0]++'
#6 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#8 [compilacion 3/5] COPY go.mod ./
#9 [compilacion 4/5] COPY cmd/ cmd/
#10 [compilacion 2/5] WORKDIR /src
#11 [compilacion 5/5] COPY internal/ internal/
#12 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     go test ./...
#12 15.92 ok  	github.com/habil/revisor/cmd/revisor	0.008s
#12 15.92 ok  	github.com/habil/revisor/internal/config	0.005s
#12 15.92 ok  	github.com/habil/revisor/internal/reporte	0.004s
#12 16.06 ok  	github.com/habil/revisor/internal/revisar	0.141s
#12 16.06 ok  	github.com/habil/revisor/internal/servicio	0.003s

## La imagen intermedia: sirve para probar, no para entregar
$ docker image ls curso-docker-revisor:pruebas --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:pruebas 1.31GB
```

Cambian los números de paso, los segundos de la tercera columna (`15.92` son los segundos desde que empezó ese paso) y los tiempos de cada paquete. Lo estable: los cinco paquetes con `ok`.

Tres cosas que leer aquí. La primera: **solo corrieron `compilacion` y `pruebas`**. No hay ni un renglón de `binario` ni de `final`: es la regla de 5.2.3 en acción, BuildKit construyó solo lo que la etapa pedida necesitaba. La segunda: los cinco paquetes del `revisor` pasaron sus pruebas **dentro** de la construcción, con el mismo compilador de la imagen fijada; no depende de que tengas Go instalado en tu equipo, ni de qué versión. La tercera: la imagen `pruebas` pesa **1.31 GB**. Sirve para probar y para mirar, nunca para entregar. Por eso es una etapa y no la imagen final.

#### 5.5.2 Una prueba rota detiene la construcción... si está en el camino

Ahora el error de esta sección, y su versión silenciosa. `fig05_05.sh` agrega una prueba que falla a propósito, `rota_test.go`, y construye dos veces: con el Dockerfile de la lección y con una variante que cambia **un solo renglón**, para que la etapa `binario` salga de `compilacion` en vez de `pruebas`:

```bash
#!/usr/bin/env bash
# fig05_05.sh — Una prueba rota detiene la construcción... si el Dockerfile la
# pone en el camino. Agrega una prueba que falla a propósito y construye dos
# veces: con el Dockerfile de la lección y con una variante donde la etapa
# «binario» sale de «compilacion» en vez de «pruebas». Borra lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# La variante equivocada: un solo renglón distinto.
sed 's/^FROM pruebas AS binario/FROM compilacion AS binario/' Dockerfile > Dockerfile.salta-pruebas

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

ROTA="${PREFIJO}revisor:rota"
trap 'docker rmi -f "$ROTA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

cat > cmd/revisor/rota_test.go <<'GO'
package main

import "testing"

func TestRotaAProposito(t *testing.T) { t.Fatal("esta prueba falla a propósito") }
GO

titulo "Con el Dockerfile de la lección"
muestra "docker build --progress=plain -t $ROTA . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit \${PIPESTATUS[0]})"
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Con la variante: binario sale de compilacion"
muestra "diff Dockerfile Dockerfile.salta-pruebas"
muestra "docker build --progress=plain -t $ROTA -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo \"construcción: código \${PIPESTATUS[0]}\""
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

El guion usa `set -uo pipefail`, sin `-e`, porque debe seguir después del fallo que provoca. `${PIPESTATUS[0]}` es una variable de *bash* que guarda el código de salida del **primer** comando de la tubería anterior, el `docker build`, y no el del `grep` que filtra su salida; `(exit N)` lo devuelve para que la ayuda `muestra` lo anote.

```text
$ ./fig05_05.sh

## Con el Dockerfile de la lección
$ docker build --progress=plain -t curso-docker-revisor:rota . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit ${PIPESTATUS[0]})
#14 1.127     rota_test.go:5: esta prueba falla a propósito
#14 1.127 FAIL
#14 1.127 FAIL	github.com/habil/revisor/cmd/revisor	0.008s
#14 1.128 FAIL
1.127     rota_test.go:5: esta prueba falla a propósito
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1
[código de salida: 1]
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'

## Con la variante: binario sale de compilacion
$ diff Dockerfile Dockerfile.salta-pruebas
17c17
< FROM pruebas AS binario
---
> FROM compilacion AS binario
[código de salida: 1]
$ docker build --progress=plain -t curso-docker-revisor:rota -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo "construcción: código ${PIPESTATUS[0]}"
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
construcción: código 0
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:rota 16.1MB
```

Cambian los números de paso y los segundos. El `[código de salida: 1]` después del `diff` no es un error: `diff` sale con 1 cuando encuentra diferencias, que es justo lo que se le pidió mostrar.

**La primera mitad es el comportamiento que quieres.** (El renglón de la prueba sale dos veces: la primera, con `#14`, es la salida del paso mientras corre; la segunda, sin número, es el resumen que BuildKit repite justo antes del `ERROR` con las últimas líneas del paso que falló.) La prueba falla, `go test` imprime `FAIL` con el archivo y el renglón (`rota_test.go:5`) y el mensaje, y BuildKit detiene todo con un `ERROR` que dice qué proceso falló y con qué código: `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. La construcción sale con 1 y, lo más importante, el segundo comando no imprime nada: **la imagen `rota` no existe**. Un código con una prueba rota no produce imagen. Si tu servidor de construcción publica lo que construye, esto es lo que impide publicar algo roto.

**La segunda mitad es el error silencioso.** El `diff` confirma que la variante cambia un solo renglón: `binario` sale de `compilacion`. La prueba rota sigue ahí. Y la construcción termina con **código 0** y una imagen de 16.1 MB. No hay `FAIL` ni `ERROR` porque **las pruebas nunca corrieron**: el filtro buscaba renglones de `pruebas` y de `binario`, y solo aparece `binario` (dos veces, porque BuildKit volvió a imprimir el encabezado del paso al terminarlo). La etapa `pruebas` sigue escrita en el archivo, pero la etapa final copia de `binario`, `binario` sale de `compilacion`, y nadie en el camino necesita `pruebas`. Por la regla de 5.2.3, BuildKit no la construye.

Es el peor tipo de error: no avisa. El Dockerfile *se ve* bien, tiene una etapa de pruebas con su comentario, y quien lo revisa de pasada cree que las pruebas protegen la imagen. Por eso el `FROM pruebas AS binario` no es un detalle de estilo: es lo que convierte a las pruebas en una condición para que exista la imagen.

> [!NOTE]
> 🔧 **Observación de ingeniería 5.3**
> Una verificación que puede saltarse sin que nadie se entere no es una verificación. La forma de saber si una compuerta funciona es la de esta sección: rómpela a propósito y comprueba que detiene la construcción. Una construcción verde no demuestra que las pruebas pasaron; puede demostrar solo que no corrieron.

### 5.6 La base mínima: sin *shell* y sin `root`

#### 5.6.1 Qué es *distroless*

La etapa final parte de `gcr.io/distroless/static-debian13`. *Distroless* es una familia de imágenes base que publica Google, y su nombre ya explica la idea: «sin distribución». Su documentación lo dice así: contienen «solo tu aplicación y sus dependencias de ejecución», y no traen «gestores de paquetes, *shells* ni ningún otro programa que esperarías encontrar en una distribución normal de Linux» ([distroless](https://github.com/GoogleContainerTools/distroless)).

La familia tiene varias variantes, según lo que el programa necesite para correr: `base`, `cc`, y otras con el entorno de Python, Java o Node.js ya instalado. La que usa el `revisor` es la más pequeña de todas, **`static`**: para programas que ya traen todo dentro y no dependen de nada del sistema. Su documentación la da como «alrededor de 2 MiB». Tus mediciones no dan ese número, y conviene decirlo: en las capas de 5.4 la viste ocupar unos 5.8 MB ya desempacada, y su versión comprimida para `arm64`, la que se descarga, suma 855,334 bytes en sus trece capas (medido el mismo día con `docker buildx imagetools inspect --raw` sobre el *digest* de `arm64` de 5.7). La documentación no dice cómo midió sus 2 MiB, así que tómalo como un orden de magnitud: unos pocos megabytes, contra los cientos de una base con distribución completa. De los 5.8 MB desempacados, casi 4.4 MB son las zonas horarias (`tzdata` y `tzdata-legacy`). Trae lo mínimo que un programa estático todavía necesita del mundo: los certificados de las autoridades (para hablar HTTPS), las zonas horarias, `/etc/passwd` con sus tres usuarios y una carpeta `/tmp`. Son las capas que viste en 5.4.

El nombre completo tiene tres partes que conviene leer una por una:

- `static`: la variante, para binarios estáticos.
- `debian13`: de qué versión de Debian salen los pocos archivos que trae (certificados, zonas horarias). La documentación recomienda escribir siempre la versión de Debian en el nombre, para que tu construcción no cambie de base sin aviso el día que salga la siguiente.
- `:nonroot`: la etiqueta. *Distroless* publica pocas etiquetas, que son nombres y no versiones: `latest`, `nonroot`, `debug` y `debug-nonroot`, y las mismas con un sufijo de arquitectura, como `nonroot-arm64` ([distroless](https://github.com/GoogleContainerTools/distroless)); ninguna lleva versión. `nonroot` es la misma imagen, pero configurada para correr con el usuario `nonroot` en lugar de `root`. Las variantes `debug` traen un *shell* mínimo para depurar; no son para producción.

#### 5.6.2 Correrla

`fig05_06.sh` corre la imagen mínima de las dos formas en que el `revisor` se usa —como programa que hace una cosa y termina, y como servicio— y comprueba lo que prometió la lección:

```bash
#!/usr/bin/env bash
# fig05_06.sh — Correr la imagen mínima: su versión, su salud, su reporte, que
# no tiene shell, que no es root y cuánto tarda en detenerse. Borra lo que crea.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# PUERTO: el puerto del equipo donde se publica el revisor, siempre en 127.0.0.1.
PUERTO="${PUERTO:-8080}"

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

IMAGEN="${PREFIJO}revisor:1.2.0"
NOMBRE="${PREFIJO}revisor"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1; docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT
docker build -q -t "$IMAGEN" . >/dev/null

titulo "Un subcomando, sin servidor"
muestra "docker run --rm --name ${PREFIJO}version $IMAGEN version"

titulo "Como servicio"
muestra "docker run -d --name $NOMBRE -p 127.0.0.1:$PUERTO:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' $IMAGEN >/dev/null"
esperar_http "http://127.0.0.1:$PUERTO/salud"
muestra "curl -s http://127.0.0.1:$PUERTO/salud; echo"
muestra "curl -s 'http://127.0.0.1:$PUERTO/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"

titulo "Sin shell y sin root"
muestra "docker exec $NOMBRE sh"
muestra "docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' $NOMBRE"
muestra "docker top $NOMBRE -o pid,user,args"

titulo "Detenerlo"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' $NOMBRE"
muestra "docker logs $NOMBRE"
```

Igual que en la Lección 3, el `revisor` se revisa a sí mismo (`propio http://127.0.0.1:8080/salud`) porque todavía no lo conectas con otros contenedores; eso es la Lección 8. El `sed` del reporte tapa, a la vista, el tiempo de respuesta, que cambia en cada corrida.

```text
$ ./fig05_06.sh

## Un subcomando, sin servidor
$ docker run --rm --name curso-docker-version curso-docker-revisor:1.2.0 version
desarrollo

## Como servicio
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud; echo
{"estado":"vivo","version":"desarrollo"}

$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <tiempo>  200

## Sin shell y sin root
$ docker exec curso-docker-revisor sh
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
[código de salida: 127]
$ docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' curso-docker-revisor
User=65532:65532 Entrypoint=[/revisor] Cmd=[]
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
1451351             65532               /revisor

## Detenerlo
docker stop tardó 298 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor
ExitCode=0
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 8ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Cambian el PID (`1451351`), el tiempo de `docker stop`, el tiempo de `/api/estados` en el registro y cuántas veces aparece `GET /salud` (depende de cuántos intentos hizo el guion mientras esperaba a que el servicio respondiera). Lo demás sale igual.

#### 5.6.3 Leer la corrida

- **`version` funcionó como subcomando.** `docker run ... curso-docker-revisor:1.2.0 version` ejecutó `/revisor version`, gracias al `ENTRYPOINT`. Imprime `desarrollo` porque el binario todavía no lleva versión grabada; la Lección 6 se la pone.
- **Como servicio, hace lo mismo que antes.** `/salud` responde, el reporte en tabla dice `OK`. La imagen bajó ochenta veces y el comportamiento no cambió en nada: todo lo que se quitó era, de verdad, equipaje.
- **No hay *shell*.** `docker exec curso-docker-revisor sh` falla con el mismo mensaje que viste con el servicio de prueba en la Lección 2: `exec: "sh": executable file not found in $PATH`, código 127. Ahora sabes por qué: la base es *distroless* y `sh` no existe. Para la escena del principio, esta es la respuesta: quien lograra ejecutar algo dentro de este contenedor no encontraría ni un *shell*, ni `curl`, ni un compilador.
- **No es `root`.** `docker inspect` dice `User=65532:65532`, y `docker top`, que mira el proceso desde el anfitrión, lo confirma: el proceso es del usuario 65532. También dice `Entrypoint=[/revisor] Cmd=[]`: el programa lo fija el `ENTRYPOINT`, y no hay argumentos por omisión.
- **Se apaga bien.** `docker stop` tardó 298 ms, el código fue 0 y el registro termina con `recibí terminated, apagando` y `apagado limpio`: la forma *exec* hace que la señal le llegue al `revisor`, que es el proceso número 1. Fíjate en que en la columna `COMMAND` de `docker top` está solo `/revisor`, sin un `/bin/sh -c` delante: ni siquiera podría haberlo, porque no hay *shell*.

#### 5.6.4 Lo que cuesta no tener *shell*

Una imagen sin *shell* tiene un precio, y conviene decirlo: **no puedes entrar a curiosear**. No hay `ls`, `cat`, `ps` ni `sh`. Cuando algo falle, las herramientas que te quedan son las de fuera, y son suficientes:

- `docker logs`, para lo que el programa escribe;
- `docker inspect`, para la configuración y el estado;
- `docker top`, para ver el proceso desde el anfitrión;
- `docker export` con `tar`, para ver los archivos, como en 5.4.4;
- y la etapa `binario` construida con `--target`, que sí tiene todas las herramientas, para examinar el programa por dentro. La vas a usar en 5.8.

Lo que **no** se hace es cambiar la base final por una con *shell* «para poder depurar». Si de verdad necesitas un *shell* junto al proceso, existen herramientas para conectarle uno desde fuera, temporalmente, sin meterlo en la imagen; este curso no las necesita.

### 5.7 Versión y *digest* de la base

#### 5.7.1 Una etiqueta es un apodo que se mueve

En la Lección 3 viste que una etiqueta como `1.27.3-trixie` es más específica que `latest`, y que aun así puede cambiar: quien publica la imagen puede volver a subirla. La guía de buenas prácticas de Docker lo dice con todas sus letras: «las etiquetas de imagen son mutables, lo que significa que quien publica puede actualizar una etiqueta para que apunte a una imagen nueva» ([buenas prácticas, fijar la versión de la base](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Para *distroless* el asunto es todavía más claro: su etiqueta `nonroot` no tiene versión, así que **por definición** apunta a lo último que se publicó. Escribir solo `static-debian13:nonroot` es, en la práctica, escribir `latest`.

#### 5.7.2 Qué es un *digest*

Un ***digest*** es la huella digital del contenido de una imagen: se calcula pasando sus bytes por una función de resumen, SHA-256, y se escribe `sha256:` seguido de 64 caracteres hexadecimales. La especificación de imágenes de la OCI lo define como un «identificador de contenido» que «identifica el contenido de forma única», calculado con una función de resumen resistente a colisiones ([OCI, descriptores](https://github.com/opencontainers/image-spec/blob/main/descriptor.md)). La consecuencia práctica es la que importa: **si cambia un solo byte de la imagen, cambia el *digest***. Un *digest* no se puede mover a otra imagen, porque es la imagen.

`fig05_09.sh` pregunta al registro qué *digest* tienen hoy las dos bases del Dockerfile, sin construir ni crear nada:

```bash
#!/usr/bin/env bash
# fig05_09.sh — Etiqueta contra digest: qué hay detrás de las dos bases.
# Solo consulta el registro y la copia local; no construye ni crea nada.
set -euo pipefail

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "La base de compilación: la etiqueta y el digest que hoy le corresponde"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'"
muestra "docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie"

titulo "La base final: distroless no publica versiones, solo nombres"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'"
```

`docker buildx imagetools inspect` le pregunta al registro qué hay detrás de un nombre, sin descargar la imagen. `docker image inspect` con `.RepoDigests` dice de qué *digest* vino la copia que ya tienes en tu equipo.

```text
$ ./fig05_09.sh

## La base de compilación: la etiqueta y el digest que hoy le corresponde
$ docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'
Name:      docker.io/library/golang:1.27.3-trixie
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
$ docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'
  Platform:    linux/amd64
  Platform:    linux/arm64/v8
$ docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie
golang@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c

## La base final: distroless no publica versiones, solo nombres
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'
Name:      gcr.io/distroless/static-debian13:nonroot
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a
  Platform:  linux/amd64
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:6964c30f0122730c54f70f8f51a777490f85d077d25da672830c43968c14993e
  Platform:  linux/arm64/v8
```

Esta salida es la del 21 de octubre de 2026. **Es la que más puede cambiar de toda la lección**, y no por tu equipo: el día que Google publique una base nueva con la etiqueta `nonroot`, el `Digest` de la cuarta consulta será otro. El de `golang:1.27.3-trixie` también puede cambiar si quien la publica la reconstruye. Y si nunca descargaste la imagen de Go, la tercera consulta falla porque no tienes copia local.

#### 5.7.3 Leer la salida

- **El `MediaType` dice `image.index`.** Lo que hay detrás de esas etiquetas no es una imagen sino un **índice**: una lista de imágenes, una por plataforma. Por eso la segunda y la quinta consulta encuentran una entrada para `linux/amd64` y otra para `linux/arm64/v8`, cada una con su propio *digest*. El *digest* que escribe el Dockerfile es el **del índice**: con él, la misma línea sirve en tu Mint de procesador Intel o AMD y en la máquina ARM de estas corridas, y Docker escoge la imagen de tu plataforma dentro del índice.
- **Los dos *digest* del Dockerfile coinciden con los de ese día**: `6041…` para Go y `5167…` para *distroless*. La copia local de Go vino de ese mismo *digest*.
- **Si escribes el *digest* de una plataforma** (por ejemplo, el `6964…` de `arm64`) en lugar del del índice, la base queda atada a esa arquitectura: quien construya en otra ya no recibe la base de la suya. Es un error fácil de cometer si copias el *digest* del renglón equivocado.

#### 5.7.4 Etiqueta **y** *digest*

El Dockerfile escribe las dos cosas juntas: `golang:1.27.3-trixie@sha256:6041…`. La sintaxis la permite la referencia: `FROM <imagen>[@<digest>] [AS <nombre>]` ([referencia, `FROM`](https://docs.docker.com/reference/dockerfile/#from)). Cuando hay *digest*, el que manda es el *digest*: Docker baja exactamente esos bytes, diga lo que diga hoy la etiqueta. Entonces, ¿para qué la etiqueta? Para las personas: `@sha256:6041…` no le dice a nadie qué versión de Go es; `1.27.3-trixie` sí. La etiqueta documenta; el *digest* garantiza.

La guía de buenas prácticas explica la garantía y también su precio. La garantía: con el *digest*, «tienes la garantía de usar siempre la misma versión de la imagen, aunque quien publica reemplace la etiqueta con una imagen nueva». El precio: un *digest* fijado **no se actualiza solo**, así que tampoco te llegan solas las correcciones de seguridad de la base ([buenas prácticas](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Fijar no es olvidarse: es decidir cuándo cambias de base, revisándolo, en lugar de que cambie sin aviso en medio de una construcción. La misma guía menciona herramientas que abren solicitudes de cambio automáticas cuando sale un *digest* nuevo. Y la Lección 10 te enseña a escanear la base fijada para saber cuándo toca renovarla.

> [!NOTE]
> 🔧 **Observación de ingeniería 5.4**
> Una construcción reproducible es la que da el mismo resultado hoy y dentro de tres meses con el mismo código. Sin *digest*, el mismo Dockerfile puede producir dos imágenes distintas sin que nadie haya tocado nada, y el día que algo falle no podrás saber si fue tu cambio o el de la base.

### 5.8 El binario que no arranca

#### 5.8.1 Provocarlo

Esta es la parte de la lección donde todo se ve bien y nada funciona. `fig05_07.Dockerfile` es el Dockerfile de la lección con **un solo cambio**: el `RUN` de la etapa `binario` no dice `CGO_ENABLED=0`:

```dockerfile
# syntax=docker/dockerfile:1
# fig05_07.Dockerfile — Lección 5: el error a propósito: el mismo Dockerfile SIN CGO_ENABLED=0.

# --- Etapa 1: el código, sobre la imagen de Go (fijada por versión Y por digest) ---
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

# --- Etapa 2: las pruebas. Si fallan, la construcción se detiene aquí ---
FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

# --- Etapa 3: el binario, estático (CGO_ENABLED=0), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

El comentario de la etapa 3 sigue diciendo «estático», a propósito: así se ven estos errores en la vida real, con un comentario que ya no dice la verdad. `fig05_08.sh` construye esa imagen, la corre y después examina los dos binarios, el de esta imagen y el de la lección, desde la etapa `binario`, que sí tiene herramientas:

```bash
#!/usr/bin/env bash
# fig05_08.sh — El error de esta lección: el binario que no es estático.
# Construye la imagen de fig05_07.Dockerfile (sin CGO_ENABLED=0), la corre, y
# después mira los dos binarios del revisor por dentro, el de esa imagen y el
# de la lección. Borra lo que crea al salir.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig05_07.Dockerfile" "$TRABAJO/revisor/Dockerfile.dinamico"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.dinamico && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

DINAMICO="${PREFIJO}revisor:dinamico"
B_DIN="${PREFIJO}revisor:binario-dinamico"
B_EST="${PREFIJO}revisor:binario-estatico"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$DINAMICO" "$B_DIN" "$B_EST" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construye sin error... y no arranca"
muestra "docker build -q -t $DINAMICO -f Dockerfile.dinamico . >/dev/null; echo \"construcción: código \$?\""
muestra "docker run --rm --name ${PREFIJO}dinamico $DINAMICO version"

titulo "Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)"
docker build -q --target binario -t "$B_DIN" -f Dockerfile.dinamico . >/dev/null
docker build -q --target binario -t "$B_EST" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mirar $B_DIN sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'"
muestra "docker run --rm --name ${PREFIJO}mirar $B_EST sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo \"(sin intérprete)\"'"

titulo "¿Está ese intérprete en la imagen final?"
docker create --name "${PREFIJO}mirar" "$DINAMICO" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -E 'ld-linux|libc\\.so' || echo '(no está)'"
```

`ldd` es una herramienta de Linux que lista las bibliotecas compartidas que un programa necesita para arrancar. `readelf -l` muestra los encabezados de un ejecutable de Linux (formato ELF), y entre ellos el renglón que dice qué programa tiene que cargarlo. Las dos existen en la imagen de Go, no en *distroless*: por eso se usan desde la etapa `binario`, construida con `--target`.

```text
$ ./fig05_08.sh

## Construye sin error... y no arranca
$ docker build -q -t curso-docker-revisor:dinamico -f Dockerfile.dinamico . >/dev/null; echo "construcción: código $?"
construcción: código 0
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]

## Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-dinamico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'
	linux-vdso.so.1 (0x0000fd7da7955000)
	libc.so.6 => /lib/aarch64-linux-gnu/libc.so.6 (0x0000fd7da7750000)
	/lib/ld-linux-aarch64.so.1 (0x0000fd7da7910000)
      [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-estatico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo "(sin intérprete)"'
	not a dynamic executable
(sin intérprete)

## ¿Está ese intérprete en la imagen final?
$ docker export curso-docker-mirar | tar -t | grep -E 'ld-linux|libc\.so' || echo '(no está)'
(no está)
```

Cambian las direcciones entre paréntesis (`0x0000fd7d…`), que son distintas en cada ejecución. En un equipo Intel o AMD, las rutas dicen `x86_64` en vez de `aarch64`: el intérprete es `/lib64/ld-linux-x86-64.so.2` y la biblioteca está en `/lib/x86_64-linux-gnu/`. El mensaje del error y el código 255 salen igual.

#### 5.8.2 Leer el error

La construcción salió con **código 0**: nada en el Dockerfile está mal escrito, las pruebas pasaron y el binario se compiló. El error aparece hasta **correr**: `exec /revisor: no such file or directory`, con código 255. Ese código no lo puso el `revisor`, que nunca llegó a ejecutarse: la falla ocurrió al intentar arrancarlo.

El mensaje es de los más confusos que vas a ver en Docker, porque **el archivo `/revisor` sí existe**: lo copió el `COPY --from`, y en 5.4 lo viste en la lista de archivos de la imagen. Lo que no existe es **otro** archivo, y la segunda parte de la salida dice cuál:

- `ldd` del binario de esta imagen lista tres cosas que necesita del sistema: `libc.so.6`, la biblioteca de C de Debian, y `/lib/ld-linux-aarch64.so.1`, el **cargador dinámico** (`linux-vdso.so.1` la pone el propio núcleo y no es un archivo). `readelf` lo confirma con un renglón explícito: `Requesting program interpreter: /lib/ld-linux-aarch64.so.1`, «pido como intérprete del programa a `/lib/ld-linux-aarch64.so.1`».
- El binario de la lección, en cambio, es `not a dynamic executable` y no pide intérprete: es **estático**, trae todo lo que necesita dentro.
- Y la última consulta busca el cargador y la biblioteca de C en la imagen final: `(no está)`. La base `static` no los trae, porque es para programas estáticos.

El manual de Linux explica la cadena. Un programa dinámico no arranca solo: el núcleo lee en el propio ejecutable cuál es su cargador, el que está «guardado en la sección `.interp` del programa», y lo ejecuta para que este busque y cargue «los objetos compartidos (bibliotecas compartidas) que necesita» ([ld.so(8)](https://man7.org/linux/man-pages/man8/ld.so.8.html)). Si ese cargador no existe, la llamada del sistema que arranca programas, `execve`, falla con el error `ENOENT`, que el manual describe así: «la ruta, o un intérprete de *script* o de ELF, no existe» ([execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html)). `ENOENT` es justamente el error que se imprime como `no such file or directory`. El mensaje no miente; solo no dice **qué** archivo falta, y el que falta no es el que nombra.

#### 5.8.3 Por qué Go hizo un binario dinámico

Go es famoso por producir binarios que no dependen de nada, y es cierto casi siempre. La excepción es *cgo*, el mecanismo con el que un programa de Go llama a código en C. La documentación de Go dice que *cgo* «está activado por omisión en las compilaciones nativas, en los sistemas donde se espera que funcione», y que se apaga con la variable `CGO_ENABLED=0` ([cmd/cgo](https://pkg.go.dev/cmd/cgo)). La imagen de Go trae un compilador de C (lo viste en 5.1: `gcc`), así que ahí *cgo* está encendido.

¿Y para qué querría el `revisor` código en C, si no tiene ni una línea de C? Por la red. El `revisor` usa el paquete `net` de la biblioteca estándar, para su servidor y para consultar otros servicios. Ese paquete trae dos formas de convertir un nombre en una dirección: una escrita en Go puro y otra que llama a las funciones de la biblioteca de C del sistema. Normalmente usa la de Go, pero bajo ciertas configuraciones del sistema usa la de C ([paquete net, «Name Resolution»](https://pkg.go.dev/net#hdr-Name_Resolution)). Para poder elegir al correr, cuando *cgo* está disponible el binario lleva las dos, y eso es lo que viste con `ldd` en 5.8.1: la dependencia de `libc.so.6` y del cargador. Con `CGO_ENABLED=0`, Go usa solo su implementación propia y el binario queda estático.

El arreglo, entonces, es el de la etapa `binario` de la lección: `CGO_ENABLED=0` delante del `go build`. No hace falta cambiar de base ni copiar bibliotecas a mano.

> [!NOTE]
> 🔧 **Observación de ingeniería 5.5**
> Una construcción verde no garantiza una imagen que arranca. Entre construir y correr hay un acuerdo implícito entre el binario y la base: lo que uno pide, la otra tiene que tenerlo. Por eso cada imagen nueva se **corre** antes de darla por buena, aunque sea con un subcomando tan simple como `version`.

### 5.9 Lo que vas a encontrar en tutoriales viejos

Las construcciones en varias etapas llegaron a Docker en la versión 17.05, del 4 de mayo de 2017: las notas de esa versión anuncian «soporte para construcciones en varias etapas» y, en la misma lista, la opción para indicar la etapa objetivo ([notas de Docker Engine 17.05](https://docs.docker.com/engine/release-notes/17.05/)). Antes de eso, el problema de esta lección se resolvía con trucos que todavía vas a ver en repositorios viejos:

- **El «patrón del constructor» con dos Dockerfiles.** Un `Dockerfile.build` construía una imagen con el compilador; un guion de *shell* creaba un contenedor de esa imagen, sacaba el binario con `docker cp` y luego construía una segunda imagen con otro Dockerfile. Funcionaba, pero eran tres pasos que había que mantener sincronizados a mano. Una sola construcción con varias etapas hace lo mismo.
- **`RUN` encadenados con `&&` que instalan, compilan y borran en un solo renglón**, para que lo borrado no quede en ninguna capa. Era la forma de ahorrar espacio con una sola etapa; sigue siendo menos eficaz que no meter el compilador en la imagen final.
- **`FROM scratch`.** `scratch` es una imagen vacía, sin un solo archivo. Un binario estático puede correr ahí, y muchos tutoriales lo hacen. Le falta lo que *distroless* `static` sí trae: certificados para HTTPS, zonas horarias y un `/etc/passwd` con un usuario sin privilegios. Para el `revisor`, que consulta servicios y no debe correr como `root`, la base del curso ahorra tener que agregar esas piezas a mano.
- **`FROM alpine` como base final «porque es chiquita».** Alpine es pequeña, pero trae *shell* y gestor de paquetes, y usa otra biblioteca de C (musl) distinta de la de Debian: un binario dinámico compilado en la imagen de Go de Debian no arranca en ella, por la misma razón de 5.8.
- **`COPY --from=0`**, con número en vez de nombre. Funciona, pero se rompe en silencio el día que alguien agrega una etapa al principio.

## El error que vas a ver

Esta lección tiene un error principal y uno que no se ve.

**El error principal: `exec /revisor: no such file or directory`.** Es el de `fig05_08.sh`:

```text
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]
```

Se lee así: el contenedor no pudo **arrancar** el programa, y el programa nunca se ejecutó (por eso no imprimió nada propio). Lo traicionero es que el archivo que nombra sí existe. Lo que falta es lo que ese archivo necesita para arrancar: su cargador dinámico y las bibliotecas que pide. Cuando veas este mensaje con una base mínima, la secuencia es:

1. Construye la etapa del binario con `--target` y mira el programa con `ldd` y `readelf -l`. Si dice `not a dynamic executable`, el problema es otro (revisa la ruta del `ENTRYPOINT`). Si lista bibliotecas y un intérprete, encontraste la causa.
2. Arréglalo en la compilación: para Go, `CGO_ENABLED=0`. Si un programa de verdad necesita la biblioteca de C, la base correcta es una que la traiga, no la variante `static`: *distroless* tiene variantes más completas, como `base` y `cc`, y su documentación dice qué trae cada una.
3. Lo que **no** se hace es copiar bibliotecas sueltas a la imagen final hasta que arranque, ni cambiar la base por una con *shell* «para que funcione». El primero es frágil y el segundo deshace la lección.

**El error que no se ve: la etapa de pruebas que nadie corre.** Es la segunda mitad de `fig05_05.sh`: con `FROM compilacion AS binario`, una prueba rota no detiene la construcción, porque BuildKit no construye una etapa de la que la imagen final no depende. No hay mensaje que leer; el síntoma es justamente que **no hay** `FAIL`. La única forma de encontrarlo es la de esa figura: agrega una prueba rota a propósito y comprueba que la construcción falla con `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. Si termina con código 0, revisa de qué etapa sale tu etapa del binario.

## El hábito de seguridad de la lección

**Entregar solo lo que se necesita para correr, sobre una base mínima, fijada y sin `root`.** La imagen final no tiene *shell*, ni gestor de paquetes, ni compilador, ni `curl`; corre con el usuario 65532; y su base está fijada por *digest*. Este hábito evita tres accidentes concretos. El primero es el de la escena: quien logre ejecutar algo dentro del contenedor —por un error del programa, por ejemplo— no encuentra herramientas con qué descargar, compilar ni ejecutar nada más; tiene que traerlo todo, y sin *shell* ni siquiera tiene con qué ejecutarlo. El segundo es la base que cambia sola: sin *digest*, una construcción de mañana puede traer una base distinta a la de hoy sin que nadie lo decida. El tercero es el ruido: un escáner que revisa 16 MB con unos cuantos paquetes te dice algo que puedes leer; uno que revisa 1.32 GB con doscientos paquetes de Debian, no. Que la imagen además baje ochenta veces de tamaño es la consecuencia, no el objetivo.

## Lo que se hace mal

**Achicar la imagen borrando archivos con `RUN rm`.** Lo borrado sigue en la capa de abajo; la imagen no baja. Lo que no debe viajar se queda en otra etapa.

**Entregar la imagen de una sola etapa «porque funciona».** Funciona igual que la de 16 MB, y lleva un taller completo para quien entre. Que corra no es el criterio; el criterio es qué más lleva.

**Sacar el binario de la etapa de compilación y dejar las pruebas en una etapa aparte que nadie necesita.** Se ve como si hubiera pruebas, y no las hay (5.5). El binario sale **de** la etapa de pruebas.

**Fijar la base solo por etiqueta, o usar la etiqueta `nonroot` de *distroless* sin *digest*.** Es usar `latest` con otro nombre. Etiqueta para leer, *digest* para garantizar.

**Copiar el *digest* de una plataforma en lugar del del índice.** La base queda atada a una sola arquitectura, y quien construya en otra no recibe la que le corresponde. El *digest* que va en el `FROM` es el de la línea `Digest:` de arriba, la del índice.

**Cambiar la base final por una con *shell* «para poder depurar».** Se depura desde fuera (`logs`, `inspect`, `top`, `export`) y desde la etapa de construcción con `--target`; la imagen que se entrega no carga herramientas por si acaso.

**Usar `CMD` donde la imagen es un programa con subcomandos.** Con `CMD ["revisor"]`, `docker run imagen version` reemplaza al programa entero. Con `ENTRYPOINT ["/revisor"]`, se agrega como argumento.

**Dar por buena una imagen porque se construyó.** El binario dinámico de 5.8 se construye sin un solo error. Una imagen se da por buena cuando **corre**.

## Ejercicios

Hazlos en orden. Antes de cada uno, escribe en tu [bitácora](bitacora.md) lo que crees que va a pasar; compararlo después es la mitad del aprendizaje. Si corres algo, al terminar borra lo que creaste: todo lleva el prefijo `curso-docker-`.

### Ejercicio 1 — ¿Qué etapas corren?

Con el Dockerfile de la lección (fig05_02), y suponiendo que la caché está vacía, di qué etapas construye BuildKit en cada caso:

1. `docker build -t curso-docker-revisor:1.2.0 .`
2. `docker build --target pruebas -t curso-docker-revisor:pruebas .`
3. `docker build --target compilacion -t curso-docker-revisor:compilacion .`
4. Con la variante de `fig05_05.sh` (`FROM compilacion AS binario`): `docker build -t curso-docker-revisor:1.2.0 .`

Y una pregunta más: en el caso 2, ¿la imagen que resulta tiene el binario `/out/revisor`?

### Ejercicio 2 — Arregla el Dockerfile ajeno

Un compañero te pasa este Dockerfile «de varias etapas» para el `revisor`. Encuentra **seis** problemas que causan un accidente, di cuál causa cada uno y escribe la versión corregida. (Hay además dos detalles de estilo que vale la pena corregir; no cuentan entre los seis.)

```dockerfile
FROM golang:latest
WORKDIR /src
COPY . .
RUN go test ./...

FROM golang:latest
WORKDIR /src
COPY . .
RUN go build -o /revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=1 /revisor /revisor
CMD ["/revisor"]
```

Pista: uno de los seis es el error principal de la lección y otro es el error que no se ve.

### Ejercicio 3 — El `FROM` correcto

Con la salida de `fig05_09.sh` a la vista, escribe el `FROM` de la etapa final para estos tres casos, y di cuál de los tres es el correcto para el curso:

1. Solo por etiqueta.
2. Por etiqueta y por el *digest* que sirve en cualquier plataforma.
3. Por etiqueta y por el *digest* de tu plataforma, si tu Mint es Intel o AMD.

¿Qué pasa con el caso 3 si un compañero con una computadora ARM construye tu Dockerfile?

### Ejercicio 4 — Tu imagen, medida (proyecto)

En tu carpeta `~/curso-docker/revisor`, con la imagen `curso-docker-revisor:1.2.0` que construiste en 5.3.3, comprueba sin mirar la lección:

1. Su tamaño, comparado con el de la `1.1.0` que anotaste en la Lección 4. Anota los dos en tu bitácora.
2. Que no tiene *shell*.
3. Que no corre como `root`, de dos formas distintas: una que lea la configuración de la imagen y otra que mire el proceso desde el anfitrión.
4. Que el binario de tu imagen es estático, sin entrar a la imagen final.

El ejercicio se autocorrige: terminaste cuando tienes cuatro comandos cuyas salidas dicen, respectivamente, unos 16 MB, `executable file not found`, `65532` (dos veces) y `not a dynamic executable`.

## Soluciones

### Solución 1

1. Las cuatro: `final` copia de `binario`, `binario` sale de `pruebas` y `pruebas` sale de `compilacion`. Es la cadena que obliga a correr las pruebas. Lo viste en el primer bloque de `fig05_03.sh`.
2. `compilacion` y `pruebas`, y nada más. Es exactamente lo que mostró `fig05_04.sh`: ni un renglón de `binario` ni de `final`.
3. Solo `compilacion`.
4. `compilacion`, `binario` y `final`. **`pruebas` no corre**, porque nadie en el camino de la etapa final la necesita: es la segunda mitad de `fig05_05.sh`, que terminó con código 0 y una imagen, con una prueba rota adentro.

La pregunta extra: **no**. La etapa `pruebas` solo corre `go test`; el binario se produce en la etapa `binario`, que viene después y no se construyó. La imagen `pruebas` tiene el código fuente y el compilador, por eso pesa 1.31 GB.

### Solución 2

1. **`golang:latest`.** La base puede cambiar en cualquier construcción, y con ella la versión de Go: el mismo código compila distinto de un día a otro. Va `golang:1.27.3-trixie@sha256:…`.
2. **La etapa del binario no sale de la de pruebas.** Es un `FROM golang:latest` aparte, así que la etapa de pruebas no está en el camino de la final y BuildKit **no la corre**: una prueba rota no detiene nada (el error que no se ve, 5.5). La etapa del binario debe salir de la de pruebas.
3. **Falta `CGO_ENABLED=0`.** El binario sale dinámico y en *distroless* `static` falla con `exec /revisor: no such file or directory` (el error principal, 5.8).
4. **`COPY --from=1` con número.** El día que alguien agregue o quite una etapa al principio, el número apunta a otra etapa y se copia lo que no es, sin aviso. Con nombres (`COPY --from=binario`), no pasa.
5. **La base final sin *digest*.** La etiqueta `nonroot` sin *digest* es `latest` con otro nombre: la base puede cambiar sin que nadie lo decida (5.7).
6. **`CMD` en vez de `ENTRYPOINT`.** Con `CMD ["/revisor"]`, `docker run imagen version` reemplaza al programa entero y Docker intenta ejecutar un archivo llamado `version`, que no existe (5.3.2).

Los dos detalles de estilo: el `COPY . .` repetido en dos etapas (copia dos veces todo el contexto; con una etapa `compilacion` común basta una vez, y con `COPY` selectivos, como en la Lección 4) y el `USER` implícito (la base `nonroot` ya corre como 65532, porque su configuración dice `"User": "65532"`, pero escribir `USER 65532:65532` deja la intención a la vista de quien lee el Dockerfile).

La versión corregida es el Dockerfile de la lección, `fig05_02.Dockerfile`.

### Solución 3

1. `FROM gcr.io/distroless/static-debian13:nonroot AS final`
2. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final`
3. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a AS final`

El correcto es el 2: el *digest* del índice, el de la línea `Digest:`, que sirve en `amd64` y en `arm64`. Con el 3, la base queda atada a la imagen de `linux/amd64`: en la computadora ARM de tu compañero, Docker ya no puede escoger la base de su plataforma dentro del índice, porque el `FROM` no nombra el índice sino una sola de sus imágenes, y su imagen final terminaría con una base de otra arquitectura que la de su binario. Esta lección no corrió ese caso; lo que importa es que con el *digest* del índice la pregunta ni siquiera aparece. Los *digest* de esta solución son los del 21 de octubre de 2026; si `fig05_09.sh` te muestra otros, usa los tuyos y anota en la bitácora que la base cambió.

### Solución 4

Una forma de hacerlo:

```bash
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0
docker exec curso-docker-revisor sh
docker inspect --format '{{.Config.User}}' curso-docker-revisor
docker top curso-docker-revisor -o pid,user,args
docker build -q --target binario -t curso-docker-revisor:binario .
docker run --rm curso-docker-revisor:binario ldd /out/revisor
docker rm -f curso-docker-revisor && docker rmi curso-docker-revisor:binario
```

Las salidas esperadas son las de la lección: `16.1MB` (unos megabytes más o menos en Intel o AMD) contra `1.32GB`; el error `exec: "sh": executable file not found in $PATH` con código 127; `65532:65532` en `inspect` y `65532` en la columna `USER` de `top`; y `not a dynamic executable` en `ldd` (como en `fig05_08.sh`). Si en el último paso `ldd` lista `libc.so.6`, tu Dockerfile perdió el `CGO_ENABLED=0`.

## Cómo sé que lo logré

Marca cada punto solo si puedes hacerlo **sin volver a ver el texto**:

- [ ] `docker image ls curso-docker-revisor` muestra la etiqueta `1.2.0` con unos **16 MB**, y anotaste en tu bitácora el antes y el después (en la corrida de esta lección, 1.32 GB → 16.1 MB).
- [ ] `docker run --rm curso-docker-revisor:1.2.0 version` imprime `desarrollo`.
- [ ] `docker exec` con `sh` sobre un contenedor de tu imagen falla con `executable file not found in $PATH`, y `docker top` muestra el proceso con el usuario `65532`.
- [ ] Agregaste una prueba rota a tu carpeta, `docker build -t curso-docker-revisor:rota .` falló con `exit code: 1` y `docker image ls curso-docker-revisor:rota` no muestra nada; después borraste la prueba.
- [ ] Explicas por qué `FROM pruebas AS binario` y no `FROM compilacion AS binario`, con la frase de BuildKit sobre qué etapas construye.
- [ ] Explicas qué archivo falta cuando aparece `exec /revisor: no such file or directory`, y cómo lo confirmas con `ldd` o `readelf` desde la etapa `binario`.
- [ ] Dices qué garantiza la etiqueta, qué garantiza el *digest* y por qué el *digest* del `FROM` es el del índice.
- [ ] Corriste los guiones de [`programas/05-multi-stage/`](../programas/05-multi-stage) y tus salidas coinciden con las de esta lección en lo que cada sección marca como estable. Lo que no se compara: los números de paso, los PID, los tiempos, las fechas, las direcciones de `ldd`, la arquitectura, los tamaños en unos megabytes, y los *digest* de `fig05_09.sh` si la base se publicó de nuevo. Y al terminar, `docker ps -a --filter name=curso-docker-` no muestra contenedores de esta lección.

## Resumen

Responde sin mirar la lección:

1. ¿Por qué la imagen de la Lección 4 pesaba 1.32 GB si el `revisor` pesaba 9.5 MB? ¿Por qué borrar el compilador con un `RUN rm` no la achica?
2. ¿Qué es una etapa? ¿Qué hacen `AS`, `COPY --from` y `--target`?
3. ¿Qué etapas construye BuildKit cuando pides la imagen final? ¿Qué consecuencia tiene eso para la etapa de pruebas?
4. ¿Qué trae y qué no trae la base *distroless* `static`? ¿Qué herramientas te quedan para depurar una imagen sin *shell*?
5. ¿Por qué el Dockerfile usa `ENTRYPOINT ["/revisor"]` en lugar de `CMD ["revisor"]`?
6. ¿Qué es un *digest*? ¿Por qué se escriben la etiqueta y el *digest* juntos, y qué precio tiene fijar la base?
7. ¿Qué significa `exec /revisor: no such file or directory` cuando el archivo sí existe? ¿Qué hace `CGO_ENABLED=0`?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [Docker, «Multi-stage builds»](https://docs.docker.com/build/building/multi-stage/): varios `FROM`, copiar selectivamente entre etapas, nombrar las etapas, `--target`, y que BuildKit solo construye las etapas de las que depende la etapa objetivo.
- [Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/): que el almacén de containerd guarda cada capa comprimida y desempacada, lo que explica el tamaño de `docker image ls`.
- [Docker, buenas prácticas de construcción](https://docs.docker.com/build/building/best-practices/): las etapas para reducir el tamaño, la base mínima, las etiquetas mutables y la fijación por *digest* con su precio.
- [Referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/): la sintaxis `FROM <imagen>[@<digest>] [AS <nombre>]`, `COPY --from` y cómo `ENTRYPOINT` y `CMD` reciben los argumentos de `docker run`.
- [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/): las opciones `--target` y `--no-cache-filter`.
- [Docker Engine 17.05, notas de versión](https://docs.docker.com/engine/release-notes/17.05/): la llegada de las construcciones en varias etapas y de la etapa objetivo, el 4 de mayo de 2017.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones y fechas de «Sobre las corridas».
- [distroless (GoogleContainerTools)](https://github.com/GoogleContainerTools/distroless): qué traen y qué no traen las imágenes *distroless*, el tamaño de `static-debian13`, sus etiquetas y la recomendación de nombrar la versión de Debian.
- [golang en Docker Hub](https://hub.docker.com/_/golang): la etiqueta `1.27.3-trixie` y sus alias.
- [OCI Image Specification, descriptores](https://github.com/opencontainers/image-spec/blob/main/descriptor.md): qué es un *digest* y por qué identifica el contenido.
- [cmd/cgo](https://pkg.go.dev/cmd/cgo): cuándo *cgo* está activado y cómo se apaga con `CGO_ENABLED=0`.
- [Paquete net de Go, «Name Resolution»](https://pkg.go.dev/net#hdr-Name_Resolution): las dos formas de resolver nombres, la de Go puro y la que usa la biblioteca de C.
- [cmd/link](https://pkg.go.dev/cmd/link): las opciones `-s` y `-w` del enlazador, y que `-s` implica `-w`.
- [cmd/go, `go build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies): la opción `-trimpath`.
- [ld.so(8), manual de Linux](https://man7.org/linux/man-pages/man8/ld.so.8.html): el cargador dinámico y la sección `.interp`.
- [execve(2), manual de Linux](https://man7.org/linux/man-pages/man2/execve.2.html): el error `ENOENT` cuando falta el intérprete de un ELF.
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **binario dinámico** | ejecutable que necesita bibliotecas del sistema y un cargador para arrancar |
| **binario estático** | ejecutable que trae dentro todo lo que necesita; no depende de bibliotecas del sistema |
| **cargador dinámico** | programa (`ld-linux…`) que arranca un binario dinámico y le carga sus bibliotecas |
| ***cgo*** | mecanismo con el que un programa de Go llama a código en C; se apaga con `CGO_ENABLED=0` |
| ***digest*** | huella SHA-256 del contenido de una imagen o de un índice; si cambia un byte, cambia la huella |
| ***distroless*** | familia de imágenes base mínimas, sin *shell* ni gestor de paquetes |
| **etapa** (*stage*) | cada parte de un Dockerfile que empieza con un `FROM`; solo la última es la imagen que se entrega |
| **etapa objetivo** (*target*) | la etapa hasta la que se construye con `--target` |
| **índice** (*image index*) | lista de imágenes de un mismo nombre, una por plataforma |
| ***multi-stage*** | construcción en varias etapas dentro de un mismo Dockerfile |

---

**Siguiente:** [Lección 6 — Configuración y secretos](06-configuracion-y-secretos.md)
