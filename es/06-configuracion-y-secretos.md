# Lección 6 — Configuración y secretos

Es jueves, 6:40 de la tarde, y el equipo quiere liberar el `revisor` a las siete. Falta un detalle: el ambiente de pruebas necesita otra lista de servicios y un token distinto. Alguien propone lo rápido: «Le cambio el token en el Dockerfile, reconstruyo y la subo; son cinco minutos». Lo hace, y la imagen sube al registro compartido. A las 6:52, un compañero de otro equipo pregunta en el chat, con toda la inocencia del mundo, por qué la imagen del `revisor` trae una variable `REVISOR_TOKEN` con un valor que parece una contraseña. No tuvo que entrar a ningún servidor ni romper nada: le bastó un `docker inspect` sobre una imagen que tenía permiso de descargar. Ahora el token hay que darlo por perdido, generar otro y averiguar quién más bajó la imagen. La liberación de las siete ya no sale. Esta lección existe para que esa conversación no ocurra: la imagen no lleva ni la configuración de un ambiente ni sus secretos, y vas a comprobar con tus propios ojos qué queda dentro de ella.

**Tiempo:** 90 min

**Qué construyes:** el `revisor` configurado sin reconstruir. La imagen `curso-docker-revisor:1.3.0` lleva grabada su versión, que no es secreta, y nada más de ningún ambiente. La lista de servicios llega al correr el contenedor, por variables de entorno o por un archivo de variables. El token de acceso llega como un archivo de solo lectura, nunca como variable. Y el patrón para usar un secreto **mientras se construye** queda listo en el Dockerfile sin dejar rastro en la imagen.

**Qué aprendes:** qué es configuración y qué es secreto; `ARG` contra `ENV` (cuándo existe cada uno y dónde queda); `-e` y `--env-file`; las etiquetas OCI con la versión; los secretos de construcción con `--mount=type=secret` y `--secret`; los secretos de ejecución por archivo y por qué no por variable; y, sobre todo, a **mirar** con `docker history` y `docker inspect` qué viaja dentro de una imagen.

**De dónde vienes.** De la [Lección 5](05-multi-stage.md), donde el `revisor` quedó en una imagen de cuatro etapas, `curso-docker-revisor:1.2.0`, de 16.1 MB, sin *shell*, sin compilador y con el usuario `65532`. Esa imagen tiene un hueco que tal vez notaste: su subcomando `version` dice `desarrollo`, porque nadie le dijo qué versión es. También traes de la [Lección 3](03-primer-dockerfile.md) el `.dockerignore` que deja fuera `.env` y `secretos/`, y de la [Lección 2](02-contenedores-dia-a-dia.md) la costumbre de publicar puertos solo en `127.0.0.1`. Y de la Lección 3, el error de arrancar el `revisor` sin `REVISOR_SERVICIOS`: hoy vas a ver por qué esa variable no va en el Dockerfile.

**Qué no hace esta lección.** No explica a fondo los montajes: el token llega con un `--mount type=bind` de un solo archivo, y por ahora basta con saber que pone un archivo del equipo dentro del contenedor. La [Lección 8](08-volumenes-y-redes.md) explica los montajes completos. Tampoco usa los secretos de Compose, que son la forma cómoda de hacer lo mismo y llegan en la [Lección 9](09-compose.md). No enseña gestores de secretos externos (bóvedas, servicios de la nube): este curso trabaja en tu equipo, y lo que aprendes aquí es la parte que esos gestores también necesitan, que el secreto llegue como archivo y no se quede en la imagen. Y no hace falta que tengas módulos privados de Go: el `revisor` no los usa, y el secreto de construcción se enseña con un valor de mentira.

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4, la misma base de Linux Mint 22, el sistema de referencia del curso. Los guiones se corrieron **dentro** de esa máquina virtual, con Docker 29.2.1 (cliente y daemon) y Buildx v0.31.1, y con su carpeta de trabajo en el disco propio de Linux. Eso último importa en esta lección: las carpetas compartidas entre la Mac y la máquina virtual mienten con los permisos (un archivo con permisos `600` se lee igual desde un contenedor de otro usuario), y la sección 6.5 trata justo de permisos. En tu Mint no existe ese problema. Para no chocar con otras corridas que usaban la misma máquina, los guiones se lanzaron con otro prefijo de nombres y otros puertos (las variables `PREFIJO` y `PUERTO` que traen); ningún nombre de contenedor ni de imagen, ni el puerto del equipo, aparece en sus salidas, así que lo que ves es exactamente lo que imprimieron. Con sus valores por omisión, los guiones usan nombres de apoyo propios que llevan `fig06` (la imagen `curso-docker-revisor:fig06`, el contenedor `curso-docker-revisor-fig06`): así nunca tocan tu imagen `curso-docker-revisor:1.3.0` ni tu contenedor `curso-docker-revisor`, y al salir borran solo lo que crearon. El curso se planeó con Docker Engine 29.8.2, y la más reciente publicada ese día era la 29.9.2, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)); nada de esta lección cambia entre esas versiones. Lo que **sí** cambia de una corrida a otra, y se avisa donde aparece: los tiempos de la tabla del `revisor` (tapados con `<t>` en el propio guion), los tiempos y la fecha de las líneas de construcción, y la palabra `arm64` en el historial de la imagen, que en un equipo Intel o AMD dice `amd64`. Los programas están en [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos), cada uno con su salida al lado, y `estado/` guarda los archivos del proyecto tal como quedan al terminar.

## Al terminar vas a poder

- Clasificar un dato del `revisor` como código, configuración o secreto, y decir dónde debe vivir cada uno.
- Explicar la diferencia entre `ARG` y `ENV` diciendo cuándo existe cada uno y dónde queda escrito, y comprobarlo con `docker history` y `docker image inspect`.
- Correr la misma imagen con dos configuraciones distintas, con `-e` y con `--env-file`, sin reconstruir.
- Encontrar un secreto dejado en una imagen por `ARG` o por `ENV`, y leer la advertencia `SecretsUsedInArgOrEnv` de `docker build --check`.
- Entregar el token del `revisor` como archivo de solo lectura, y arreglar el error `permission denied` que aparece al hacerlo.
- Usar un secreto durante la construcción con `--secret` y demostrar que no quedó en la imagen.

## El porqué antes del cómo

Hasta la Lección 5 todo lo que el `revisor` necesitaba para correr salía de la imagen o de un par de `-e` escritos al vuelo. Funcionaba porque solo había un ambiente: tu equipo. En cuanto aparece un segundo ambiente (pruebas, producción, la computadora de un compañero), aparece la pregunta de esta lección: **¿qué cambia entre un ambiente y otro, y dónde se escribe?**

La respuesta clásica viene de una guía muy citada, *The Twelve-Factor App*, que define la configuración de una aplicación como «todo lo que probablemente varía entre despliegues» ([12factor.net, «Config»](https://12factor.net/config)). En el `revisor` eso es la lista de servicios que revisa, el puerto, la ruta del reporte y el token. Lo que **no** varía es el código y la versión: la `1.3.0` es la `1.3.0` en todos lados. La misma guía propone una prueba sencilla para saber si separaste bien: ¿podrías publicar tu código como abierto en este momento sin exponer ninguna credencial? Este curso es abierto, así que la prueba no es hipotética: el Dockerfile del `revisor` está publicado, y por eso no puede llevar nada que no quieras que lea el mundo.

Con imágenes, la pregunta tiene una vuelta más. Una imagen no es solo un archivo que corre; es un paquete que **viaja**: se sube a un registro, se descarga en otras máquinas, se guarda en cachés, se copia a un clúster. Todo lo que metas en ella lo recibe cualquiera que pueda descargarla. Y una imagen guarda más de lo que parece: además de los archivos de sus capas, guarda su **configuración** (el entorno, el usuario, las etiquetas) y su **historial** (la instrucción que creó cada capa, con los valores que tenía). La documentación de Docker lo dice sin rodeos: los argumentos de construcción y las variables de entorno «no son apropiados para pasar secretos a tu construcción», porque «persisten en la imagen final» ([Docker, «Build secrets»](https://docs.docker.com/build/building/secrets/)).

Así que esta lección hace tres cosas, en este orden:

1. **Sacar la configuración de la imagen** (6.1 a 6.3): la imagen lleva su versión y valores por omisión que no son secretos; lo demás llega al correr.
2. **Ver con tus ojos qué pasa cuando un secreto entra a la imagen** (6.4): lo vas a meter a propósito, con valores de mentira, y lo vas a encontrar.
3. **Hacerlo bien** (6.5 y 6.6): el secreto de ejecución como archivo de solo lectura, y el secreto de construcción como montaje que dura lo que dura un `RUN`.

Con ese destino en mente, esto es lo que verás en la sección 6.4, al buscar dentro de una imagen mal hecha. El valor de mentira está ahí, en el historial, aunque el propio `RUN` borró el archivo que lo contenía:

```text
== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

## Los conceptos

### 6.1 Código, configuración y secreto: tres cosas distintas

#### 6.1.1 Clasificar lo que el `revisor` necesita

Antes de escribir una sola línea, conviene ponerle nombre a cada dato. Hay tres cajas:

| Caja | Qué es | En el `revisor` | Dónde vive |
|---|---|---|---|
| **Código** | lo que hace el programa; igual en todos los ambientes | el binario, compilado en la versión `1.3.0` | dentro de la imagen |
| **Configuración** | lo que cambia de un ambiente a otro y no es secreto | `REVISOR_SERVICIOS`, `REVISOR_PUERTO`, `REVISOR_REPORTE` | fuera de la imagen; llega al correr |
| **Secreto** | configuración que, si se filtra, alguien puede usar en tu contra | el token de `/api/estados`; una credencial para descargar módulos privados | fuera de la imagen **y** fuera de las variables de entorno; llega como archivo |

Dos datos merecen comentario. El **puerto** es configuración, pero tiene un valor por omisión razonable (`8080`) que no es secreto, y por eso la imagen lo trae declarado con `ENV`: sirve de documentación y de valor por omisión, y cualquier ambiente lo puede cambiar. La **versión** no es configuración: no cambia entre ambientes, describe al código. Por eso se graba al construir y no se pide al correr.

El secreto tiene su propia caja porque cumple las dos condiciones: cambia entre ambientes (el token de pruebas no es el de producción) y su valor no puede quedar a la vista. Esa segunda condición es la que descarta las variables de entorno, como verás en 6.5.

#### 6.1.2 Los secretos de este curso son de mentira, y lo dicen

Todos los secretos que aparecen en esta lección son **inventados para el ejercicio** y lo anuncian en su propio valor: `curso-docker-token-de-mentira-7f3a9c`, `curso-docker-modulos-de-mentira-41be`. No abren nada. Viven en la carpeta `secretos/` del proyecto, que el curso publica a propósito para que puedas correr todo. En un proyecto de verdad esa carpeta **nunca** se publica: va en el `.gitignore` y en el `.dockerignore`, y sus valores salen de donde tu equipo guarde las credenciales.

El `.dockerignore` que traes de las lecciones 3 y 4 ya la excluye, junto con `.env` y los `Dockerfile*`:

```text
# Lo que nunca viaja al daemon al construir.
.git
.env
*.tar
*.md
Dockerfile*
.dockerignore
compose.yaml
secretos/
```

Eso significa que ningún `COPY` puede meter por accidente un archivo de `secretos/` a la imagen: ni siquiera llega al daemon. Es la primera puerta, y la más barata. Esta lección cierra las otras tres: el historial, la configuración de la imagen y la configuración del contenedor.

### 6.2 `ARG` contra `ENV`

#### 6.2.1 Dos instrucciones que se parecen y no se parecen

Las dos instrucciones definen variables con nombre y valor, y las dos se usan con `${NOMBRE}` dentro del Dockerfile. Lo que las separa es **cuándo existen**:

- **`ARG`** declara un **argumento de construcción**. Existe solo mientras se construye la imagen, y su valor se puede cambiar desde fuera con `docker build --build-arg NOMBRE=valor`. Los contenedores que nacen de la imagen no lo reciben. La documentación lo resume así: los argumentos de construcción «no son accesibles ni están presentes en los contenedores» creados a partir de la imagen, pero sus valores «pueden persistir en los metadatos de la imagen», en las atestaciones de procedencia y **en el historial** ([Docker, «Build variables»](https://docs.docker.com/build/building/variables/)).
- **`ENV`** define una **variable de entorno** que existe durante la construcción y que, además, la imagen entrega a cada contenedor que nace de ella: «las variables de entorno definidas con `ENV` persisten cuando se corre un contenedor a partir de la imagen», y se pueden ver con `docker inspect` y cambiar con `docker run --env` ([referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/)).

Dicho en una línea: `ARG` es un dato para **construir**; `ENV` es un dato para **correr**. Y ninguno de los dos es un escondite: los dos dejan su valor escrito en la imagen, uno en el historial y el otro en la configuración.

Hay un detalle de alcance que confunde a todo el mundo la primera vez. Un `ARG` vale **en la etapa donde se declara** (y en las etapas que salen de ella). En un Dockerfile de varias etapas, si la etapa `final` también necesita el valor, lo declara otra vez. Es lo que hace el Dockerfile de esta lección con `VERSION`.

#### 6.2.2 El Dockerfile de esta lección

Este es el Dockerfile con el que termina la lección. Es el de la Lección 5 con cuatro cambios, y cada uno se explica abajo:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_01.Dockerfile — Lección 6: la imagen no lleva configuración de un ambiente ni secretos.
# Lo único que se le fija al construir es su VERSIÓN, que no es secreta.

FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

FROM pruebas AS binario
# ARG existe solo mientras se construye. Aquí se usa para grabar la versión
# dentro del binario; /salud la devuelve.
ARG VERSION=desarrollo
# Un secreto de CONSTRUCCIÓN (por ejemplo, credenciales para módulos privados)
# se monta solo durante este RUN y no queda en ninguna capa. Este curso no usa
# módulos privados: el montaje es opcional (required=false) y queda como patrón.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    --mount=type=secret,id=netrc,target=/root/.netrc,required=false \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
ARG VERSION=desarrollo
LABEL org.opencontainers.image.title="revisor" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://www.habil.mx/es/cursos/docker/"
# ENV solo para valores por omisión que NO son secretos.
ENV REVISOR_PUERTO=8080
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

Los cuatro cambios, en el orden en que aparecen:

1. **`ARG VERSION=desarrollo` en la etapa `binario`.** Declara el argumento con un valor por omisión. Si construyes sin `--build-arg`, vale `desarrollo`, que es justo lo que el `revisor` decía en la Lección 5; así nada se rompe para quien construye sin saber de este argumento.
2. **`-X main.version=${VERSION}` en `go build`.** Es una opción del enlazador de Go que reemplaza, al compilar, el valor de una variable de texto del programa ([cmd/link](https://pkg.go.dev/cmd/link)). El `revisor` tiene una variable `version` en su paquete `main` que vale `desarrollo` si nadie la toca. Con esta opción, el número queda **dentro del binario**, que es el único lugar donde no se puede perder ni contradecir.
3. **`--mount=type=secret,...,required=false`** en ese mismo `RUN`. Es el secreto de construcción; tiene su propia sección, la 6.6. Por ahora basta con saber que, como es opcional, la construcción funciona igual con o sin él.
4. **En la etapa `final`: `ARG VERSION` otra vez, `LABEL` y `ENV`.** El `ARG` se repite porque cada etapa tiene su propio alcance (6.2.1). Con él, `LABEL` pega a la imagen tres **etiquetas** (*labels*) con nombres de un estándar, el de la *Open Container Initiative*: `org.opencontainers.image.title` es el «título legible» de la imagen, `org.opencontainers.image.version` es la «versión del software empaquetado» y `org.opencontainers.image.source` es la «URL para obtener el código fuente» con el que se construye la imagen ([OCI, anotaciones predefinidas](https://github.com/opencontainers/image-spec/blob/main/annotations.md)). Aquí apunta a la página del curso, que es la dirección pública de referencia de este material; en tu propio proyecto, ponle la dirección del repositorio, que es lo que la especificación pide. Cualquier herramienta que sepa leer esas etiquetas (un registro, un escáner, la Lección 10) sabe qué es la imagen sin correrla. Y `ENV REVISOR_PUERTO=8080` deja el valor por omisión del puerto a la vista de quien inspeccione la imagen.

Fíjate en lo que **no** hay: ni `REVISOR_SERVICIOS`, ni `REVISOR_TOKEN`, ni `REVISOR_TOKEN_ARCHIVO`. La imagen no sabe en qué ambiente va a correr, y así tiene que ser.

#### 6.2.3 Construir y mirar dónde quedó cada cosa

El guion `fig06_02.sh` construye la imagen con `--build-arg VERSION=1.3.0` y después le pregunta, sin correr el servidor, qué trae:

```bash
#!/usr/bin/env bash
# fig06_02.sh — Construir el revisor con su versión como ARG y mirar dónde quedó.
# Construye curso-docker-revisor:1.3.0 con fig06_01.Dockerfile y pregunta a la
# imagen qué trae: la versión, las etiquetas, el entorno y el historial.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

echo "== 1. Construir, pasando la versión como argumento de construcción"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'

echo
echo "== 2. La versión, grabada dentro del binario"
docker run --rm --name "${PREFIJO}revisor-fig06-version" "$IMAGEN" version

echo
echo "== 3. Las etiquetas OCI de la imagen"
docker image inspect --format '{{range $k, $v := .Config.Labels}}{{$k}} = {{$v}}{{println}}{{end}}' "$IMAGEN"

echo "== 4. El entorno que la imagen entrega a cada contenedor (ENV)"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN"

echo "== 5. El historial de la imagen final, de arriba (lo último) hacia abajo"
docker history --format '{{.Size}}	{{.CreatedBy}}' "$IMAGEN" | head -8
```

```text
$ ./fig06_02.sh
== 1. Construir, pasando la versión como argumento de construcción
tamaño: 16.1MB

== 2. La versión, grabada dentro del binario
1.3.0

== 3. Las etiquetas OCI de la imagen
org.opencontainers.image.source = https://www.habil.mx/es/cursos/docker/
org.opencontainers.image.title = revisor
org.opencontainers.image.version = 1.3.0

== 4. El entorno que la imagen entrega a cada contenedor (ENV)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
REVISOR_PUERTO=8080

== 5. El historial de la imagen final, de arriba (lo último) hacia abajo
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
0B	ENV REVISOR_PUERTO=8080
0B	LABEL org.opencontainers.image.title=revisor…
0B	ARG VERSION=1.3.0
319kB	bazel build //common:cacerts_debian13_arm64_…
```

Cinco bloques, cinco lugares distintos donde vive información de una imagen:

1. **El tamaño no cambió**: 16.1 MB, igual que la `1.2.0`. Las etiquetas, el `ENV` y el `ARG` no pesan: son metadatos, no archivos.
2. **La versión está en el binario.** El subcomando `version` imprime `1.3.0`. Es la misma que devuelve `GET /salud` y la misma que el `revisor` escribe al arrancar (`revisor 1.3.0 escuchando en :8080`), como verás en 6.5.
3. **Las etiquetas OCI** están en la configuración de la imagen y se leen con `docker image inspect`, sin correr nada. La plantilla `{{range $k, $v := .Config.Labels}}` recorre el mapa de etiquetas; `docker` las ordena por nombre.
4. **El entorno** que recibirá cada contenedor: dos variables que trae la base *distroless* (`PATH` y `SSL_CERT_FILE`, la ruta de los certificados de confianza) y la nuestra, `REVISOR_PUERTO=8080`. Mira bien lo que **falta**: `VERSION`. El `ARG` no pasó al entorno. Ningún contenedor lo va a recibir.
5. **El historial**, de lo más reciente a lo más viejo. Cada renglón es una instrucción de la etapa `final` (las otras etapas no están: no forman parte de la imagen entregada, como viste en la Lección 5). Las que no crean archivos pesan `0B`. El `…` es `docker history` recortando renglones largos; con `--no-trunc` se ven completos. Y ahora el renglón que importa para el resto de la lección: **`ARG VERSION=1.3.0`**. El valor del argumento está escrito en el historial, a la vista de cualquiera que tenga la imagen. Para una versión eso está perfecto: no es secreta, y hasta ayuda. Para un token sería una fuga. Guarda esa imagen en la cabeza; en 6.4 la vas a ver con un valor que no debería estar ahí.

El último renglón (`bazel build //common:cacerts_debian13_arm64_…`) es una capa de la base *distroless*: sus autores la construyen con una herramienta llamada Bazel, y el historial lo registra. En tu Mint con procesador Intel o AMD dice `amd64` donde aquí dice `arm64`.

#### 6.2.4 En tu carpeta

Los guiones del curso trabajan en carpetas temporales y borran lo que crean; tu proyecto vive en `~/curso-docker/revisor` desde la Lección 3. Desde la raíz del repositorio del curso, pon ahí el Dockerfile de esta lección y la carpeta de secretos de mentira, y construye la imagen que vas a conservar:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cp -R programas/06-configuracion-y-secretos/estado/secretos ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 -t curso-docker-revisor:1.3.0 .
docker run --rm curso-docker-revisor:1.3.0 version
```

El último comando tiene que imprimir `1.3.0`. El `.dockerignore` no cambia: ya excluye `secretos/`. En `estado/` también está `Dockerfile.malo`, la receta equivocada de 6.4. Cópiala también, porque «Cómo sé que lo logré» te pide repetir ese experimento; el `.dockerignore` (que excluye `Dockerfile*`) impide que viaje en el contexto. Y cuando llegues a 6.6, reconstruye tu imagen con el secreto de construcción, para comprobar que no deja rastro:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile.malo ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt -t curso-docker-revisor:1.3.0 .
```

Los guiones de esta lección no tocan nada de esto: usan nombres de apoyo con `fig06` y borran solo lo suyo.

### 6.3 Configurar sin reconstruir

#### 6.3.1 `-e` y `--env-file`

La imagen ya no sabe qué servicios revisar. Eso se le dice **al correr**, y hay dos formas:

- **`-e NOMBRE=valor`** (o `--env`), una por variable, en la misma línea de `docker run`. Es lo que usaste desde la Lección 2. Si escribes solo `-e NOMBRE`, sin valor, Docker toma el valor que esa variable tenga en tu terminal y lo pasa; si en tu terminal no existe, el contenedor no la recibe ([referencia de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).
- **`--env-file archivo`**: un archivo de texto con un `NOMBRE=valor` por renglón. Los renglones que **empiezan** con `#` son comentarios; un `#` en medio del renglón es parte del valor. Un renglón con solo `NOMBRE`, sin `=`, toma el valor de tu terminal, igual que `-e NOMBRE`. Sirve para tener la configuración de cada ambiente en su propio archivo (`pruebas.env`, `local.env`) y no en un comando de tres renglones que nadie recuerda.

Las dos formas se pueden mezclar, y las dos ganan sobre lo que diga el `ENV` de la imagen. Ese es el sentido de un valor por omisión: estar ahí hasta que alguien diga otra cosa.

#### 6.3.2 La misma imagen, tres configuraciones

El guion `fig06_03.sh` construye `curso-docker-revisor:1.3.0` una vez y la corre tres veces con configuraciones distintas. La primera tiene un error a propósito:

```bash
#!/usr/bin/env bash
# fig06_03.sh — Configurar sin reconstruir: la MISMA imagen, tres configuraciones.
# Una variable mal escrita, una lista por -e y otra lista por --env-file.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# La tabla del revisor, con el tiempo tapado: es lo único que cambia entre corridas.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
}

echo "== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS"
rc=0
docker run --name "$NOMBRE" -e REVISOR_SERVICIO='propio http://127.0.0.1:8080/salud' "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. La configuración por -e: un solo servicio"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla
IMAGEN_1=$(docker inspect --format '{{.Image}}' "$NOMBRE")
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Otra configuración, desde un archivo con --env-file"
cat > revisor.env <<'FIN'
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
FIN
cat revisor.env
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --env-file revisor.env "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR

echo "== 5. ¿Las dos corridas usaron la misma imagen?"
IMAGEN_2=$(docker inspect --format '{{.Image}}' "$NOMBRE")
[ "$IMAGEN_1" = "$IMAGEN_2" ] && echo "sí: el mismo identificador de imagen en las dos" || echo "no: son imágenes distintas"
```

```text
$ ./fig06_03.sh
== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]

== 2. La configuración por -e: un solo servicio
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 3. Otra configuración, desde un archivo con --env-file
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
SERVICIO     ESTADO    TIEMPO  DETALLE
inexistente  FALLA         <t>  no responde: Get "http://127.0.0.1:9/": dial tcp 127.0.0.1:9: connect: connection refused
propio       OK            <t>  200

== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
REVISOR_PUERTO=8080
== 5. ¿Las dos corridas usaron la misma imagen?
sí: el mismo identificador de imagen en las dos
```

Antes de leer la salida, los renglones nuevos del guion. La función `tabla` pide el reporte en forma de tabla y tapa el tiempo de respuesta con `<t>`, porque es lo único que cambia entre corridas; lo tapa **en el propio comando**, a la vista, no editando la salida. El servicio `propio` es el `revisor` revisándose a sí mismo: dentro del contenedor, `127.0.0.1:8080` es el propio contenedor, no tu equipo. Y el servicio `inexistente` apunta al puerto 9, donde no escucha nada; está para que veas una falla.

Ahora la salida, bloque por bloque:

1. **Una letra de menos.** `REVISOR_SERVICIO` no es una variable que el `revisor` conozca, así que la ignora en silencio, como cualquier programa ignora las variables que no lee. Para él, `REVISOR_SERVICIOS` simplemente no existe, y se niega a arrancar con código 1. Es el mismo error que en la Lección 3, pero ahora sabes por qué es tan común: Docker no valida nombres de variables; no tiene cómo saber cuáles lee tu programa. El que valida es el programa, y por eso es bueno que el `revisor` falle fuerte y con un ejemplo, en vez de arrancar con una lista vacía y fingir que todo está bien.
2. **Con `-e`, un servicio.** El reporte trae un renglón, `propio`, sano.
3. **Con `--env-file`, dos servicios.** El archivo trae un comentario y una variable. Fíjate en que el valor **no lleva comillas**: en un archivo de `docker run --env-file`, todo lo que va después del `=` es el valor, comillas incluidas. Es una trampa clásica, y el Ejercicio 3 te la hace pisar. Cuidado al llevar esta regla a la Lección 9: el `env_file` de Compose es otro lector y **sí** quita las comillas ([referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/)). Medido con Compose v5.0.2: el mismo renglón con comillas llegó al contenedor como `REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud`, sin ellas. Mismo tipo de archivo, dos lectores, dos resultados. La tabla ahora tiene dos renglones: `inexistente` con `FALLA` y la causa exacta, y `propio` con `OK`.
4. **Lo que recibió el contenedor** es la suma de lo que trae la imagen (`REVISOR_PUERTO=8080`, por su `ENV`) y lo que llegó al correr (`REVISOR_SERVICIOS`, del archivo). El `grep REVISOR` deja fuera `PATH` y `SSL_CERT_FILE`, que también están.
5. **La misma imagen.** El guion guardó el identificador de imagen del primer contenedor y lo comparó con el del segundo: son iguales. Dos comportamientos distintos, cero reconstrucciones. Ese es todo el punto de separar la configuración.

#### 6.3.3 Lo que esto te da

Separar la configuración de la imagen no es una cuestión de estilo. Tiene tres consecuencias prácticas. La primera: **la imagen que probaste es la que entregas**. Si para pasar de pruebas a producción tuvieras que reconstruir con otra configuración, la imagen de producción sería una que nadie probó. La segunda: **cambiar la configuración cuesta segundos**, lo que tarda un contenedor en arrancar, y no lo que tarda una construcción. La tercera: **la imagen se puede publicar**, porque no lleva nada de ningún ambiente. Esas tres juntas son lo que permite, en la Lección 10, publicar una sola imagen y llevarla a Kubernetes.

### 6.4 Así NO: mirar con tus ojos qué queda dentro de la imagen

#### 6.4.1 La receta equivocada

Para aprender a encontrar un secreto en una imagen, lo mejor es esconder uno y buscarlo. Este Dockerfile hace las dos cosas que la lección prohíbe. Tiene una sola etapa, como en la Lección 4, para que todo quede a la vista:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_04.Dockerfile — Lección 6: ASÍ NO. Dos formas de dejar un secreto dentro de la imagen.
# (Una sola etapa, como en la Lección 4, para que todo quede a la vista.)
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/
# Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
# aunque el RUN borre el archivo al final.
ARG TOKEN_MODULOS
RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
 && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
 && rm /root/.netrc
# Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
USER 10001:10001
CMD ["revisor"]
```

Los dos errores imitan casos reales:

- **Mal 1** es lo que hace quien necesita una credencial para descargar dependencias privadas. Go, como muchas herramientas, lee las credenciales de un archivo `.netrc` en la carpeta del usuario: un renglón `machine <servidor> password <secreto>`. La receta escribe el archivo con el valor de un `ARG`, compila y lo borra **en el mismo `RUN`**. Quien la escribió sabía que un archivo borrado en un `RUN` posterior sigue en la capa anterior, y por eso hizo todo en uno. Parece prudente. No alcanza. (El servidor es `ejemplo.invalid`, un dominio reservado que no existe en internet.)
- **Mal 2** es el atajo de la escena del principio: el token del `revisor` como `ENV`, para que «ya venga configurado».

#### 6.4.2 Buscarlo

El guion `fig06_05.sh` construye esa receta pasándole el token de módulos de mentira y después busca los dos secretos donde cualquiera que tenga la imagen puede buscar:

```bash
#!/usr/bin/env bash
# fig06_05.sh — ASÍ NO: dos secretos (de mentira) que quedan dentro de la imagen.
# Construye fig06_04.Dockerfile y busca los secretos donde cualquiera que tenga
# la imagen los puede buscar: el historial y la configuración.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
MALO="${PREFIJO}revisor:fig06-malo"
CADENA="${PREFIJO}revisor:fig06-cadena"
trap 'docker rmi -f "$MALO" "$CADENA" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_04.Dockerfile" "$TRABAJO/Dockerfile.malo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Construir pasando el token de módulos (de mentira) por ARG"
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" \
  -f Dockerfile.malo -t "$MALO" . >/dev/null && echo "construida"

echo
echo "== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" --user 0 "$MALO" ls -A /root

echo
echo "== 3. Pero el historial guardó el valor del ARG, en dos renglones"
docker history --no-trunc --format '{{.CreatedBy}}' "$MALO" | grep 'TOKEN_MODULOS='

echo
echo "== 4. Y la configuración de la imagen trae el token de ejecución"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$MALO" | grep TOKEN

echo "== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$MALO" printenv REVISOR_TOKEN

echo
echo "== 6. docker build --check lo habría dicho antes de construir"
rc=0
docker build --check -f Dockerfile.malo . 2>&1 || rc=$?
echo "[código de salida: $rc]"

echo
echo "== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use"
cat > Dockerfile.cadena <<'FIN'
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS base
ARG TOKEN_MODULOS
RUN echo "paso 1: no uso ningún argumento"
FROM base AS hija
ARG VERSION=desarrollo
RUN echo "paso 2: tampoco"
FIN
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" --build-arg VERSION=1.3.0 \
  -f Dockerfile.cadena -t "$CADENA" . >/dev/null
docker history --no-trunc --format '{{.CreatedBy}}' "$CADENA" | head -4
```

```text
$ ./fig06_05.sh
== 1. Construir pasando el token de módulos (de mentira) por ARG
construida

== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está
.bashrc
.cache
.config
.profile

== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be

== 4. Y la configuración de la imagen trae el token de ejecución
REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo
curso-docker-token-de-mentira-en-env

== 6. docker build --check lo habría dicho antes de construir
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile.malo
#1 transferring dockerfile: 892B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.1s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#4 DONE 0.0s

#5 [internal] load .dockerignore
#5 transferring context: 155B done
#5 DONE 0.0s
Check complete, 2 warnings have been found!

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
Dockerfile.malo:11
--------------------
   9 |     # Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
  10 |     # aunque el RUN borre el archivo al final.
  11 | >>> ARG TOKEN_MODULOS
  12 |     RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
  13 |      && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
--------------------

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "REVISOR_TOKEN")
Dockerfile.malo:16
--------------------
  14 |      && rm /root/.netrc
  15 |     # Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
  16 | >>> ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
  17 |     USER 10001:10001
  18 |     CMD ["revisor"]
--------------------
[código de salida: 1]

== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use
RUN |2 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be VERSION=1.3.0 /bin/sh -c echo "paso 2: tampoco" # buildkit
ARG VERSION=1.3.0
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "paso 1: no uso ningún argumento" # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

#### 6.4.3 Leer lo que encontraste

1. **El archivo ya no está.** Dentro de la imagen, `/root` tiene los archivos de siempre de la base y las cachés que dejó `go build` (`.cache`, `.config`), pero no `.netrc`. El guion usa `--user 0` solo para poder mirar `/root`, que no es legible para el usuario `10001` de la imagen. Si te detuvieras aquí, dirías que la receta funcionó.
2. **El historial lo tiene, dos veces.** Un renglón es la propia instrucción, `ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`, con el valor que recibió. El otro es el `RUN`, que empieza con `|1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`. Ese `|1` es un **conteo**: «en este paso había 1 argumento de construcción»; a continuación vienen todos, con su valor. Borrar el archivo no borró el valor, porque el valor nunca estuvo solo en el archivo. Es el mismo mecanismo que en 6.2.3 dejó `ARG VERSION=1.3.0` a la vista; la diferencia es solo lo que pusiste en el argumento.
3. **La configuración tiene el token de ejecución**, igual que la escena del principio: `REVISOR_TOKEN=curso-docker-token-de-mentira-en-env`.
4. **Y lo recibe cada contenedor.** `printenv` lo imprime desde dentro sin que nadie se lo haya pasado al correr: viene de la imagen.
5. **`docker build --check` lo había advertido**, sin construir nada. Revisa el Dockerfile con las reglas de BuildKit y, para cada hallazgo, te dice el nombre de la regla (`SecretsUsedInArgOrEnv`), un enlace a su explicación, qué instrucción la disparó (`ARG "TOKEN_MODULOS"`, `ENV "REVISOR_TOKEN"`), el archivo y el renglón, y el pedazo del Dockerfile con una flecha `>>>`. Sale con código 1 cuando encuentra algo, así que sirve para detener un proceso automático. La regla se fija en el **nombre** de la variable: la documentación dice que señala las claves que «indican que contienen datos sensibles», sin dar la lista ([Docker, regla `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/)); aquí `TOKEN` la disparó, y en el Ejercicio 4 vas a ver un nombre en español que pasa sin advertencia. Por eso es una red de seguridad y no una garantía. Si quieres que un `docker build` normal (no solo el `--check`) se detenga ante cualquier advertencia, la directiva `# check=error=true`, en el renglón que sigue al `# syntax=`, lo hace ([Docker, «Build checks»](https://docs.docker.com/build/checks/)). Las líneas que empiezan con `#0`… `#5` son el trabajo previo de BuildKit para poder leer el Dockerfile; se pueden ignorar.
6. **Un `ARG` contamina cada `RUN` que viene después.** El último bloque usa una receta de dos etapas, escrita dentro del propio guion, donde **ningún** `RUN` menciona los argumentos. Aun así, el `RUN` de la etapa `base` lleva `|1 TOKEN_MODULOS=…`, y el de la etapa `hija`, que salió de `base` y declaró además `VERSION`, lleva `|2 TOKEN_MODULOS=… VERSION=1.3.0`. BuildKit anota en cada `RUN` todos los argumentos declarados en su etapa y en la etapa de la que sale, los use o no. Un token en un `ARG` no deja un rastro: deja uno por cada `RUN` posterior.

Lo importante de este experimento es la forma de buscar, porque es la que vas a usar en tus propias imágenes:

```bash
docker history --no-trunc --format '{{.CreatedBy}}' <imagen>
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>
```

Dos comandos, ningún permiso especial, ninguna herramienta extra. Cualquiera que pueda descargar tu imagen puede correrlos. Y si un secreto ya llegó a una imagen publicada, no hay comando que lo arregle: el secreto se da por perdido y se **cambia** en el servicio que lo emitió. Borrar la imagen del registro no lo des-publica de las máquinas y cachés que ya la descargaron.

### 6.5 El secreto de ejecución: archivo, no variable

#### 6.5.1 Por qué no una variable de entorno, aunque llegue al correr

Sacar el token del Dockerfile y pasarlo con `-e REVISOR_TOKEN=...` al correr es mejor que dejarlo en la imagen: ya no viaja al registro. Pero no es suficiente, por dos razones que la documentación de Compose resume así: las variables de entorno «suelen estar disponibles para todos los procesos, y puede ser difícil rastrear el acceso», y «también se pueden imprimir en los registros al depurar errores sin que lo sepas» ([Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/)). A eso se suma algo propio de Docker: la configuración del **contenedor** guarda su entorno completo, y cualquiera que pueda usar `docker inspect` en ese equipo lo lee. Y desde la Lección 1 sabes quién puede usar `docker`: el grupo `docker`, que equivale a `root`. Hay un rastro más, que no tiene que ver con Docker: si escribes el valor literal en la terminal (`-e REVISOR_TOKEN=abc…`, y lo mismo vale para `--build-arg`), queda en el historial de tu *shell* y, mientras el comando corre, en la lista de procesos de tu equipo. Los guiones de esta lección nunca escriben un valor a mano: lo leen del archivo con `$(cat secretos/…)`, y eso evita lo primero, que el valor quede en el historial de tu *shell*. **No evita lo segundo.** Tu *shell* sustituye el `$(cat …)` antes de lanzar `docker`, así que el valor llega a `docker` como un argumento más, y mientras el comando corre cualquiera que pueda listar procesos (`ps`, o leer `/proc/<pid>/cmdline`) lo ve igual que si lo hubieras escrito. Aquí no importa, porque los tokens de la lección son inventados. Con un secreto de verdad, la salida es no pasarlo como argumento: entregarlo como archivo montado, como hace el resto de esta lección, o, al construir, con `--secret` (6.6).

El `revisor` acepta las dos formas, pero no las trata igual. `REVISOR_TOKEN` funciona e imprime un aviso. `REVISOR_TOKEN_ARCHIVO` recibe la **ruta** de un archivo y lee el token de ahí; si están las dos, gana el archivo. La convención de la ruta es `/run/secrets/<nombre>`: es donde Compose pone sus secretos y donde BuildKit pone por omisión los de construcción, como verás en 6.6.

#### 6.5.2 Las dos formas, y el error que vas a encontrar primero

El guion `fig06_06.sh` prueba las dos formas, y en medio provoca el error más común de la forma buena. Usa el archivo de mentira `secretos/revisor_token.txt`, que contiene `curso-docker-token-de-mentira-7f3a9c`:

```bash
#!/usr/bin/env bash
# fig06_06.sh — El secreto de EJECUCIÓN: por variable de entorno (se ve) y por
# archivo (no se ve), con el error de permisos que vas a encontrar primero.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
SERVICIOS='propio http://127.0.0.1:8080/salud'

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}

echo "== 1. El token por -e: funciona, pero queda a la vista"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  -e REVISOR_TOKEN="$(cat secretos/revisor_token.txt)" "$IMAGEN" >/dev/null
sleep 1
echo "-- lo que dice el revisor al arrancar:"
docker logs "$NOMBRE" 2>&1
echo "-- lo que ve cualquiera con docker inspect:"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep TOKEN
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El token por archivo, con permisos 600"
chmod 600 secretos/revisor_token.txt
stat -c '%a %n' secretos/revisor_token.txt
rc=0
timeout 20 docker run --name "$NOMBRE" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El token por archivo, con permisos 644 y montado de solo lectura"
chmod 644 secretos/revisor_token.txt   # 644: solo porque el token es de mentira (6.5.4)
stat -c '%a %n' secretos/revisor_token.txt
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
echo "-- /salud no pide token:"
curl -s "http://127.0.0.1:$PUERTO/salud"; echo
echo "-- /api/estados sin token:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- /api/estados con el token:"
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" \
  "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'

echo
echo "== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR
docker inspect --format '{{range .Mounts}}{{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
```

```text
$ ./fig06_06.sh
== 1. El token por -e: funciona, pero queda a la vista
-- lo que dice el revisor al arrancar:
revisor: aviso: el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer; usa REVISOR_TOKEN_ARCHIVO
revisor 1.3.0 escuchando en :8080 (1 servicio(s))
-- lo que ve cualquiera con docker inspect:
REVISOR_TOKEN=curso-docker-token-de-mentira-7f3a9c

== 2. El token por archivo, con permisos 600
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]

== 3. El token por archivo, con permisos 644 y montado de solo lectura
644 secretos/revisor_token.txt
-- /salud no pide token:
{"estado":"vivo","version":"1.3.0"}

-- /api/estados sin token:
{"error":"falta el token o no es válido"}
 [401]
-- /api/estados con el token:
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_PUERTO=8080
/run/secrets/revisor_token (escribible: false)
```

#### 6.5.3 Leer la corrida

1. **Por variable, funciona y se ve.** El `revisor` arranca, pero lo primero que escribe en su registro es un aviso: `el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer`. Y `docker inspect` lo confirma, con el token completo. No hizo falta entrar al contenedor ni tener la imagen: bastó con poder hablarle al daemon. (La versión `1.3.0` en el mensaje de arranque es la que grabaste en 6.2.)
2. **Por archivo, con `600`, no arranca.** Este es el error de la lección. El archivo en tu equipo pertenece a tu usuario y tiene permisos `600`: solo su dueño lo lee. Al montarlo, el contenedor ve **el mismo archivo**, con el mismo dueño (un número de usuario) y los mismos permisos; un montaje no copia ni traduce nada. Y dentro del contenedor el `revisor` corre como el usuario `65532`, que no es el dueño. El núcleo hace lo que haría con cualquier otro usuario de tu equipo: `permission denied`. Es la consecuencia directa de algo que viste en la Lección 0: en la instalación normal de la Lección 1, los números de usuario de dentro y de fuera son los mismos. (Con Docker sin `root` o con remapeo de usuarios, el número de dentro se traduce a otro fuera, y el diagnóstico con `ls -ln` cambia.) Fíjate también en que el `revisor` **no arranca a medias**: si le dijiste que hay un archivo de token y no lo puede leer, prefiere morir con código 1 a quedar escuchando sin protección.
3. **Con `644`, funciona.** `644` le da lectura a cualquiera; ahora el usuario `65532` puede leerlo. Y no solo él: **cualquier otra cuenta de tu equipo** también (6.5.4). Aquí es un token de mentira. `/salud` responde sin token (es para que la salud se pueda vigilar, Lección 7), y `/api/estados` responde `401` sin token y la tabla con él. La salida trae un renglón en blanco después del JSON de `/salud`: es el `echo` del guion, que agrega un salto de línea al que el `revisor` ya mandó. Y el orden de las variables en `docker inspect` del bloque 4 puede variar de una corrida a otra; lo que importa es cuáles están.
4. **`docker inspect` ya no muestra el secreto.** Muestra `REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token`, una ruta, que no sirve de nada sin el archivo. Y el montaje aparece como `escribible: false`: la opción `readonly` impide que el contenedor modifique el archivo del equipo, aunque tuviera permiso.

#### 6.5.4 ¿No es peligroso un `644`?

Sí, y la respuesta corta es: **con un secreto de verdad, nunca**. `644` significa que **cualquier otra cuenta de tu equipo** puede leer el archivo: la de otra persona en un servidor compartido, la de un servicio que corre con su propio usuario, la de un programa que alguien hizo correr como otro usuario. La Lección 9 lo demuestra con una cuenta sin privilegios (`sudo -u nobody cat`, sección 9.8.3): con `644` imprime el token completo. El curso usa `644` en esta lección porque el token es de mentira (`curso-docker-token-de-mentira-7f3a9c` no abre nada) y la práctica es en tu computadora; es la forma más corta de ver que el `revisor` arranca. No la copies a un proyecto real.

Los arreglos buenos atacan la misma causa (a quién pertenece el archivo, no solo qué tan abierto está), y se comprueban con `ls -l` o con `stat -c '%a %U:%G' secretos/revisor_token.txt`:

- **Que el grupo del archivo sea el del contenedor**: `sudo chgrp +65532 secretos/revisor_token.txt` y `chmod 640 secretos/revisor_token.txt` (el `+` indica que `65532` es un número de grupo). Sigues siendo el dueño (lo lees y lo editas sin `sudo`), el `revisor` lo lee porque corre como `65532:65532`, y nadie más, salvo `root` y quien maneje Docker (9.8.3). Elige esta **o** la siguiente, no las dos.
- **Que el archivo sea del usuario del contenedor**: `chmod 600 secretos/revisor_token.txt` y **después** `sudo chown 65532:65532 secretos/revisor_token.txt`, en ese orden: cuando el dueño ya es `65532`, tu `chmod` falla con `Operation not permitted` y el archivo se queda abierto. Así solo lo leen ese usuario y `root`. El precio es que tu usuario ya no puede leerlo sin `sudo`.
- **Que un orquestador lo entregue, con una salvedad importante.** Los secretos de Compose (Lección 9) ponen el archivo en `/run/secrets/`, pero cuando el secreto sale de un **archivo**, Compose lo monta tal cual, igual que el `--mount` de esta lección: el dueño y los permisos siguen siendo los del archivo de tu equipo. Su referencia lo dice: con un archivo como fuente, Compose usa por debajo un montaje que no permite cambiar el dueño, y los atributos `uid`, `gid` y `mode` «se ignoran en silencio»; solo funcionan cuando el secreto sale de una variable de entorno ([referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/)). Lo medimos con Compose v5.0.2: el archivo en `600`, con `uid: "65532"`, `gid: "65532"` y `mode: 0400` declarados en el `compose.yaml`, dio exactamente el mismo `permission denied` de 6.5.2. Por eso la Lección 9 mide los cuatro casos (`644`, `600` tuyo, `600` de `65532` y `640` con grupo `65532`) y deja tu archivo en el último. Kubernetes sí monta sus secretos con los permisos que declares, pero eso es materia del curso de Kubernetes.

Y que el secreto no llegue al repositorio: `secretos/` va en el `.gitignore` de tu proyecto, igual que en el `.dockerignore`. Este curso sí lleva su `secretos/` en el repositorio, a propósito, porque el token es de mentira.

Lo que **no** es un arreglo: cambiar el `USER` de la imagen a `root` «para que pueda leer». Eso cambia un problema de permisos por uno de seguridad, y deshace el trabajo de las lecciones 3 y 5.

### 6.6 El secreto de construcción: un montaje que dura un `RUN`

#### 6.6.1 Cuándo hace falta

A veces el secreto no es para correr, sino para **construir**: credenciales para descargar módulos privados de Go, paquetes de un repositorio privado de npm o de Maven, un certificado para entrar a un servidor interno de dependencias. El `revisor` no tiene dependencias externas, así que hoy no lo necesita, pero el patrón queda en su Dockerfile para el día que sí.

BuildKit trae una herramienta hecha para esto: el **montaje de secreto**. En el Dockerfile, un `RUN` pide el secreto con `--mount=type=secret,id=<nombre>`; al construir, tú se lo entregas con `docker build --secret id=<nombre>,src=<archivo>` (o `env=<VARIABLE>`, si lo tienes en una variable de tu terminal). Según la documentación, el montaje deja el secreto disponible «temporalmente dentro del contenedor de construcción, durante la instrucción» ([Docker, «Build secrets»](https://docs.docker.com/build/building/secrets/)). Las opciones que usa el `revisor`, con sus valores por omisión según la [referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/):

| Opción | Qué hace | Por omisión |
|---|---|---|
| `id` | el nombre con el que `--secret` lo entrega | el nombre del archivo de `target` |
| `target` | dónde aparece el archivo durante el `RUN` | `/run/secrets/<id>` |
| `required` | si es `true`, la instrucción falla cuando no le dan el secreto | `false` |
| `mode` | permisos del archivo | `0400` |
| `uid`, `gid` | dueño del archivo | `0` (`root`) |
| `env` | en vez de un archivo (o además), pone el secreto en una variable de entorno que existe **solo durante ese `RUN`** | sin valor: solo archivo |

**Ojo con el usuario durante la construcción.** El montaje entrega el archivo con dueño `0` (`root`) y permisos `0400` por omisión. Si tu etapa de compilación ya cambió a un usuario sin privilegios con `USER`, ese usuario no podrá leer el secreto y el `RUN` fallará con `permission denied`: es la misma trampa de permisos de 6.5. Se resuelve indicando el dueño en el montaje (`uid=` y `gid=`) o relajando el modo (`mode=0444`, con el cuidado de que el secreto solo existe durante ese `RUN`). En el Dockerfile de esta lección no hace falta, porque la etapa que lo usa corre como `root`.

Ojo con las dos `env`. En `docker build --secret id=x,env=MI_VAR`, `env` dice **de qué variable de tu terminal** se lee el secreto. En `--mount=type=secret,id=x,env=TOKEN`, dice **con qué nombre lo ve el `RUN`**. Esa segunda variable no es un `ENV`: nace y muere con la instrucción, y no queda ni en la imagen ni en el historial. Es la forma que usa la propia documentación en el ejemplo correcto de la regla `SecretsUsedInArgOrEnv`, y la que conviene cuando la herramienta lee su credencial de una variable y no de un archivo. «Variable de entorno» no es mala por sí misma; lo malo es que quede escrita donde viaja la imagen o donde cualquiera la lee.

El `revisor` usa `target=/root/.netrc` porque ahí es donde Go busca sus credenciales, y `required=false` porque este curso no tiene módulos privados: así su construcción funciona con y sin `--secret`.

#### 6.6.2 Verlo aparecer y desaparecer

Para ver el montaje en acción hace falta un `RUN` que haga algo visible con el secreto. Este Dockerfile de demostración lo recibe, cuenta sus bytes y lista el archivo, **sin imprimir el valor**. Usa `required=true` para que puedas ver el error de olvidarlo:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_07.Dockerfile — Lección 6: dónde vive un secreto de construcción.
# Solo para mirar: un RUN que recibe el secreto, lo cuenta y no lo imprime.
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
RUN --mount=type=secret,id=netrc,target=/root/.netrc,required=true \
    echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes" \
 && ls -l /root/.netrc
```

El guion `fig06_08.sh` lo construye dos veces (sin y con el secreto), mira qué quedó y termina construyendo el `revisor` real con `--secret`:

```bash
#!/usr/bin/env bash
# fig06_08.sh — El secreto de CONSTRUCCIÓN con --secret: está durante el RUN y
# en ningún otro lado. Primero el error de olvidarlo; después, el revisor real.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
DEMO="${PREFIJO}revisor:fig06-demo-secreto"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$DEMO" "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp "$AQUI/fig06_07.Dockerfile" "$TRABAJO/Dockerfile.demo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Olvidar --secret cuando el Dockerfile dice required=true"
rc=0
docker build --no-cache --progress=plain -f Dockerfile.demo -t "$DEMO" . > salida-1.txt 2>&1 || rc=$?
grep -E '^ERROR' salida-1.txt
echo "[código de salida: $rc]"

echo
echo "== 2. Con --secret: el RUN lo recibe"
docker build --no-cache --progress=plain --secret id=netrc,src=secretos/token_modulos.txt \
  -f Dockerfile.demo -t "$DEMO" . 2>&1 | grep -E 'durante el RUN|/root/.netrc$' | grep -v '^#[0-9]* \[' 

echo
echo "== 3. Terminado el RUN, ¿qué quedó en /root?"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$DEMO" ls -lA /root

echo
echo "== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | head -1
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | grep -c 'modulos-de-mentira' || true

echo
echo "== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)"
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt \
  -t "$IMAGEN" . >/dev/null && echo "construida"
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$IMAGEN" | grep -c 'modulos-de-mentira' || true
```

```text
$ ./fig06_08.sh
== 1. Olvidar --secret cuando el Dockerfile dice required=true
ERROR: failed to build: failed to solve: secret netrc: not found
[código de salida: 1]

== 2. Con --secret: el RUN lo recibe
#7 0.092 durante el RUN: /root/.netrc existe y mide 37 bytes
#7 0.093 -r-------- 1 root root 37 Oct 21 09:17 /root/.netrc

== 3. Terminado el RUN, ¿qué quedó en /root?
total 8
-rw-r--r-- 1 root root 607 Jul 17 17:05 .bashrc
-rw-r--r-- 1 root root 132 Jul 17 17:05 .profile

== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción
RUN /bin/sh -c echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes"  && ls -l /root/.netrc # buildkit
-- renglones del historial con el valor del secreto:
0

== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)
construida
-- renglones del historial con el valor del secreto:
0
```

Las opciones nuevas del guion: `--no-cache` obliga a correr el `RUN` aunque haya caché, para que imprima algo; `--progress=plain` muestra la salida de cada paso como texto plano, en vez de la vista que se redibuja en la terminal. Cada renglón de esa salida empieza con el número del paso (`#7`) y los segundos desde que empezó; esos números y la fecha del archivo cambian en cada corrida (la fecha está en la hora de la máquina virtual, que es la del meridiano de Greenwich). Los `|| true` del final están porque `grep -c` sale con código 1 cuando cuenta cero, y aquí el cero es justo lo que queremos ver.

Y la salida:

1. **Olvidar el secreto** con `required=true` detiene la construcción con un mensaje corto: `secret netrc: not found`. Es lo que quieres cuando el secreto es indispensable: un error claro al construir, y no una compilación que falla tres pasos después con un «no autorizado» que nadie entiende. El `revisor` usa `required=false` porque para él el secreto es opcional.
2. **Con `--secret`, el `RUN` lo ve**: un archivo de 37 bytes (36 caracteres del valor de mentira más el salto de línea), con permisos `-r--------` (el `0400` por omisión) y dueño `root`, el usuario con el que corre ese `RUN`.
3. **Terminado el `RUN`, ya no está.** `/root` solo tiene los archivos de la base. A diferencia del `rm` de 6.4, aquí nadie tuvo que borrar nada: el archivo nunca se escribió en la capa; estuvo montado encima, como un préstamo, y se devolvió al terminar la instrucción.
4. **El historial anota la instrucción y nada más.** Ni el valor, ni siquiera las opciones `--mount`. El conteo de renglones con el valor del secreto es `0`.
5. **El `revisor` real**, construido con su secreto opcional: también `0`.

Pon esta salida al lado de la de 6.4. Con `ARG`, el valor quedó escrito aunque se borró el archivo. Con `--secret`, el valor nunca llegó a escribirse.

#### 6.6.3 Los cinco caminos, juntos

Ya viste cada mecanismo funcionando por separado. Este cuadro los junta, porque la pregunta que vas a hacerte en tu propio proyecto es siempre la misma: ¿por dónde entra este dato, y dónde queda escrito?

| Mecanismo | Cuándo existe | Cómo se entrega | Dónde queda escrito | ¿Sirve para secretos? |
|---|---|---|---|---|
| `ARG` | solo al construir | `docker build --build-arg` | en el historial, en su propio renglón y en cada `RUN` posterior de la etapa (6.4); en la procedencia en modo `max` (6.7) | no |
| `ENV` | al construir y en cada contenedor | el Dockerfile; se cambia con `-e` | en la configuración de la imagen (`docker image inspect`) | no |
| `-e` / `--env-file` | al correr | `docker run` | en la configuración del contenedor (`docker inspect`) | no |
| `--mount=type=secret` | solo durante un `RUN` | `docker build --secret` | en ningún lado (6.6.2) | sí, de construcción |
| archivo en `/run/secrets/` | al correr | montaje de solo lectura | `docker inspect` muestra la ruta, no el valor (6.5) | sí, de ejecución |

Las tres primeras filas son para configuración; las dos últimas, para secretos. Si un dato sensible está en cualquiera de las tres primeras, ya está escrito en algún lugar que otra persona puede leer.

#### 6.6.4 Por qué no se cuela por la caché

Una duda razonable: si el secreto cambia, ¿la caché de BuildKit vuelve a correr el `RUN`? No. La documentación lo dice así: «el contenido de los secretos de construcción no forma parte de la caché», y «cambiar el valor de un secreto no invalida la caché»; lo que sí cuenta son sus propiedades, como el `id` y la ruta del montaje ([Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/)). La documentación no explica el porqué; lo práctico es saber que el valor no cuenta para la caché, y que el `id` y la ruta del montaje sí. Si cambias el secreto y necesitas que el `RUN` se repita, la documentación propone pasar además un argumento de construcción cualquiera que cambies al mismo tiempo (los argumentos sí invalidan la caché), o puedes forzarlo con `--no-cache`, como hizo el guion. Es una incomodidad pequeña a cambio de que el valor no aparezca en ningún registro de la construcción.

### 6.7 Lo que vas a encontrar en tutoriales viejos

- **`ARG` para tokens de npm, de GitHub o de un registro privado**, con el comentario «no te preocupes, lo borramos al final del `RUN`». Ya viste en 6.4 que el valor queda en el historial. Los montajes de secreto existen desde que BuildKit los trajo, y son el camino documentado.
- **Construir en varias etapas «para que el `ARG` no llegue a la imagen final».** Es verdad que el historial de la imagen entregada solo muestra la etapa final (lo viste en 6.2.3), pero los valores también pueden quedar en las **atestaciones de procedencia**, el registro de cómo se construyó la imagen que la Lección 10 adjunta a ella. En el modo mínimo, el que se usa por omisión, los valores de los argumentos no se incluyen; con `--provenance=mode=max`, el que usa la Lección 10, la documentación advierte que ese modo «expone los valores de los argumentos de construcción», de todas las etapas ([Docker, procedencia SLSA](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). Ayuda, pero no es la solución.
- **`docker run -e PASSWORD=...` en las instrucciones de una imagen.** Muchas imágenes populares aceptan secretos por variable porque es lo más fácil de documentar, y muchas ofrecen además una variante `_FILE` que lee de un archivo, como el `REVISOR_TOKEN_ARCHIVO` del `revisor`. Cuando exista la variante con archivo, usa esa.
- **«Aplastar» las capas para que desaparezcan los secretos.** Algunas guías viejas proponen juntar todas las capas en una. Aunque eso quitara un archivo de una capa intermedia, no toca la configuración de la imagen: un `ENV` con un token sigue ahí, como viste en 6.4. El camino actual es que el secreto nunca entre.

## El error que vas a ver

Esta lección tiene un error principal y dos secundarios. Los tres ya aparecieron.

**El error principal: el archivo del secreto que el contenedor no puede leer.** Es el de `fig06_06.sh`:

```text
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]
```

Se lee de derecha a izquierda. `permission denied` lo dice el núcleo: el proceso no tiene permiso de abrir ese archivo. `open /run/secrets/revisor_token` dice qué archivo, con la ruta **dentro** del contenedor; la ruta del equipo es la del montaje. Y `leyendo el token de REVISOR_TOKEN_ARCHIVO` lo agrega el `revisor` para que sepas qué estaba haciendo. La pregunta que lo resuelve es «¿quién es el dueño del archivo, y con qué usuario corre el contenedor?». La primera respuesta la da `ls -ln` en tu equipo; la segunda, `docker inspect --format '{{.Config.User}}'` sobre la imagen (`65532:65532`). Si no coinciden y los permisos son `600`, este es el resultado. Arreglos: el grupo o el dueño correcto, que dejan leer al `revisor` y a nadie más (6.5.4); `644` también funciona, pero solo vale con un token de mentira. Lo que no es un arreglo: correr como `root`.

**El error secundario: el secreto de construcción que no llegó.**

```text
ERROR: failed to build: failed to solve: secret netrc: not found
```

Lo ves cuando el Dockerfile pide un secreto con `required=true` y el `docker build` no trae `--secret id=netrc,...`. El arreglo es agregarlo. Si sí escribiste `--secret` pero con otro `id` (por ejemplo, `id=nettrc`), estás en el mismo caso: el `RUN` pidió el secreto `netrc` y nadie se lo dio, así que revisa que los dos `id` coincidan letra por letra. Con `required=false`, como en el `revisor`, no hay error: el `RUN` corre sin el archivo.

**La advertencia que tienes que tratar como error: `SecretsUsedInArgOrEnv`.**

```text
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
```

Es una advertencia, no un error: un `docker build` normal la imprime y construye igual. Por eso es fácil ignorarla. Con `docker build --check` el resultado es código 1, y así conviene correrla: antes de cada construcción que vaya a publicarse. Recuerda que solo mira los nombres: una advertencia ausente no prueba que no haya secretos.

## El hábito de seguridad de la lección

**Los secretos no pasan por `ARG` ni por `ENV`, y se comprueba con `docker history` y `docker inspect` que no quedaron.** El hábito tiene dos mitades, y la segunda es la que se olvida. La primera es la regla: el secreto de construcción entra con `--secret`, el de ejecución como archivo de solo lectura en `/run/secrets/`. La segunda es la comprobación: antes de publicar una imagen, buscas en su historial completo y en su configuración, con los dos comandos de 6.4.3, y no encuentras nada. Este hábito evita el accidente de la escena del principio (un token publicado en un registro al que tienen acceso más personas de las que crees) y otro más silencioso: un token pasado por `-e` que acaba en un registro de errores, en la pantalla compartida de una videollamada o en la salida de `docker inspect` que alguien pegó en un chat para pedir ayuda.

## Lo que se hace mal

**Reconstruir la imagen para cambiar de ambiente.** Si la imagen de producción es distinta de la de pruebas, la de producción nadie la probó. Una imagen, muchas configuraciones.

**Poner la configuración de un ambiente en el `ENV` del Dockerfile.** `ENV` es para valores por omisión que sirven en cualquier lado, como el puerto. Una lista de servicios de pruebas en el `ENV` obliga a reconstruir para producción, y se queda en la imagen para siempre.

**Pasar un secreto por `ARG` y borrarlo «en el mismo `RUN`».** El archivo desaparece; el valor queda en el historial (6.4). La prudencia de hacerlo en un solo `RUN` protege contra un error distinto del que de verdad ocurre.

**Pasar el token por `-e` porque «ya no está en la imagen».** Ya no viaja al registro, pero sigue en la configuración del contenedor, a la vista de cualquiera con acceso a `docker`, y en el entorno de todos los procesos hijos.

**Arreglar `permission denied` con `--user root` o `chmod 777`.** El primero deshace el endurecimiento de la imagen; el segundo deja el archivo escribible para todo el equipo. El problema es el dueño; arréglalo ahí.

**Guardar la carpeta de secretos en el repositorio.** Este curso lo hace a propósito y con valores de mentira. Tu proyecto no: `secretos/` va en `.gitignore` y en `.dockerignore` desde el primer día.

**Confiar en que `docker build --check` no dijo nada.** Revisa nombres, no valores. Una variable `X` con un token adentro pasa limpia.

**Copiar el secreto montado a otra ruta.** El montaje no deja rastro, pero lo que el `RUN` escriba sí: si un `cp /run/secrets/…` o una herramienta guarda la credencial en su propia configuración (un `.npmrc`, un archivo de credenciales), esa copia queda en la capa como cualquier otro archivo. El secreto se lee en el `RUN` y no se escribe en ningún lado.

**Imprimir un secreto «solo para depurar».** Un `RUN cat /run/secrets/...` o un `echo $TOKEN` deja el valor en la salida de la construcción o en los registros del contenedor, que se guardan y se comparten. Para saber si un secreto llegó, cuenta sus bytes, como hizo `fig06_07.Dockerfile`.

## Ejercicios

Hazlos en orden. Antes de correr cada uno, escribe en tu [bitácora](bitacora.md) lo que crees que va a pasar; compararlo después es la mitad del aprendizaje. Al terminar, borra lo que creaste: todo lleva el prefijo `curso-docker-`.

### Ejercicio 1 — ¿Código, configuración o secreto?

Clasifica cada dato en una de las tres cajas de 6.1.1 y di dónde debe vivir (dentro de la imagen, en `ENV` como valor por omisión, por `-e`/`--env-file`, o como archivo en `/run/secrets/`):

1. La versión `1.3.0` del `revisor`.
2. La lista de servicios que revisa el ambiente de pruebas.
3. El token que protege `/api/estados` en producción.
4. El puerto `8080`.
5. La ruta donde el `revisor` guarda su reporte (`REVISOR_REPORTE`).
6. Una credencial para descargar módulos privados de Go al compilar.

### Ejercicio 2 — Sin `--build-arg` (proyecto)

En tu carpeta `~/curso-docker/revisor`, con el Dockerfile de esta lección, construye una imagen **sin** `--build-arg` y con la etiqueta `curso-docker-revisor:sin-version`. Antes de construir, predice qué van a decir estas tres cosas, y después compruébalo:

1. `docker run --rm curso-docker-revisor:sin-version version`
2. La etiqueta `org.opencontainers.image.version` de la imagen.
3. El renglón `ARG` de su `docker history`.

El ejercicio se autocorrige: si tus tres predicciones coinciden con lo que ves, entendiste de dónde sale el valor de un `ARG`. Al final, `docker rmi curso-docker-revisor:sin-version`.

### Ejercicio 3 — Las comillas del archivo de variables

Crea un archivo `comillas.env` con este único renglón, comillas incluidas:

```text
REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"
```

Antes de correrlo, predice: ¿el `revisor` arranca o se niega? Si arranca, ¿qué va a decir su tabla? Después córrelo con `docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --env-file comillas.env curso-docker-revisor:1.3.0`, pide la tabla con `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` y lee con `docker inspect` qué valor recibió exactamente. Corrige el archivo para que el servicio salga `OK`. Al final, `docker rm -f curso-docker-revisor`.

### Ejercicio 4 — Encuentra la fuga

Un compañero te pasa esta receta y jura que «no deja nada porque el secreto se borra». Sin construirla, di **dónde** quedaría cada uno de los dos valores sensibles y con qué comando lo encontrarías. Después reescribe la parte del secreto de construcción con un montaje de secreto, y di qué opción de `docker build` lo entrega:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
ARG CLAVE_REGISTRO
ENV API_KEY=valor-de-mentira-para-el-ejercicio
RUN echo "${CLAVE_REGISTRO}" > /tmp/clave && go env -w GOPRIVATE=ejemplo.invalid && rm /tmp/clave
```

Pregunta extra: ¿cuál de las dos variables habría señalado `docker build --check`, y cuál no? Piensa en cómo decide la regla.

## Soluciones

### Solución 1

1. **Código.** Dentro de la imagen: grabada en el binario con `-X main.version` y en la etiqueta OCI. No cambia entre ambientes.
2. **Configuración.** Por `-e` o `--env-file` al correr. Cambia entre ambientes y no es secreta.
3. **Secreto.** Como archivo de solo lectura en `/run/secrets/revisor_token`, con `REVISOR_TOKEN_ARCHIVO` apuntando ahí. Nunca en `ENV` ni por `-e`.
4. **Configuración con valor por omisión.** `ENV REVISOR_PUERTO=8080` en la imagen; cualquier ambiente lo cambia con `-e`.
5. **Configuración.** Por `-e` o `--env-file`. (La Lección 8 le da un valor por omisión dentro de la imagen, cuando exista una carpeta `/datos` preparada para eso.)
6. **Secreto de construcción.** Con `--mount=type=secret` en el `RUN` que lo necesita, entregado con `docker build --secret`. Nunca en `ARG`.

### Solución 2

Medido con el mismo equipo y la misma versión de Docker de la lección:

1. `desarrollo`. Sin `--build-arg`, `VERSION` toma el valor por omisión de su declaración, `ARG VERSION=desarrollo`, y eso es lo que `-X main.version` graba en el binario.
2. `desarrollo` también, porque la etapa `final` declara su propio `ARG VERSION=desarrollo` y la etiqueta lo usa.
3. `ARG VERSION=desarrollo`. El historial anota el valor que el argumento tuvo **en esa construcción**, sea el de `--build-arg` o el de la declaración. Es exactamente por lo que un secreto no puede ir ahí.

### Solución 3

Medido con el mismo equipo y la misma versión de Docker de la lección. El `revisor` **arranca** (`revisor 1.3.0 escuchando en :8080 (1 servicio(s))`), pero la tabla dice:

```text
SERVICIO  ESTADO    TIEMPO  DETALLE
"propio   FALLA        1ms  codigo 404
```

El tiempo cambia en cada corrida. Las comillas llegaron como parte del valor: `docker inspect` muestra `REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"`. El `revisor` leyó un servicio que se llama `"propio` (con la comilla) y cuya dirección es `http://127.0.0.1:8080/salud"` (con la comilla al final); esa ruta no existe y el servidor responde `404`. Es el peor tipo de error de configuración: no impide arrancar, solo da un resultado equivocado. El arreglo es quitar las comillas: en un archivo de `--env-file`, todo lo que va después del `=` es el valor, tal cual. (En la terminal sí van comillas, porque ahí las interpreta la *shell* y no llegan al contenedor. Y en el `env_file` de Compose, Lección 9, también se pueden usar, porque ese lector sí las quita.)

### Solución 4

- `CLAVE_REGISTRO` queda **en el historial**, en el renglón del `RUN`, con la forma `|1 CLAVE_REGISTRO=<valor> /bin/sh -c ...`. Se encuentra con `docker history --no-trunc --format '{{.CreatedBy}}' <imagen>`. El `rm /tmp/clave` no lo evita, igual que en 6.4.
- `API_KEY` queda **en la configuración de la imagen** y en el entorno de cada contenedor. Se encuentra con `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>`.

La reescritura del secreto de construcción:

```dockerfile
RUN --mount=type=secret,id=clave_registro,target=/root/.netrc,required=true \
    go env -w GOPRIVATE=ejemplo.invalid && go mod download
```

Aquí el secreto se **usa**: `go mod download` descarga los módulos privados y, para entrar al servidor, lee la credencial de `/root/.netrc`, que solo existe durante este `RUN` (el archivo de secreto tendría el renglón `machine ejemplo.invalid password …`, como en 6.4). Si la herramienta que necesitas lee su credencial de una variable y no de un archivo, cambias `target=…` por `env=CLAVE_REGISTRO`, y la variable existe solo durante ese `RUN` (6.6.1). Se entrega con `docker build --secret id=clave_registro,src=<archivo> .` (o `env=<VARIABLE>` de tu terminal). Sin `ARG`, sin archivo que borrar, y ningún renglón del historial con el valor. Y `API_KEY` sale del Dockerfile: si el programa la necesita al correr, llega como archivo.

Pregunta extra: la regla decide por el **nombre** de la variable. Medido con el mismo equipo y la misma versión de Docker de la lección, `docker build --check .` sobre la receta sale con código 1 y una sola advertencia:

```text
Check complete, 1 warning has been found!
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "API_KEY")
```

`API_KEY` tiene la clase de nombre que la regla busca. `CLAVE_REGISTRO`, en español, pasa sin advertencia, y es justo el valor que acaba en el historial. La lección que importa: la advertencia es una red, no un candado.

## Cómo sé que lo logré

Marca cada punto solo si puedes hacerlo **sin volver a ver el texto**:

- [ ] En tu carpeta, `docker run --rm curso-docker-revisor:1.3.0 version` imprime `1.3.0`, y `docker image inspect` muestra la etiqueta `org.opencontainers.image.version = 1.3.0`.
- [ ] `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.3.0` muestra `REVISOR_PUERTO=8080` y ninguna otra variable `REVISOR_*`.
- [ ] Corres la misma imagen con dos listas de servicios distintas, una por `-e` y otra por `--env-file`, sin reconstruir.
- [ ] Explicas en un minuto la diferencia entre `ARG` y `ENV` usando las palabras *construir*, *correr*, *historial* y *configuración*.
- [ ] Construyes `Dockerfile.malo` y encuentras los dos secretos de mentira con dos comandos; y `docker build --check -f Dockerfile.malo .` te da las dos advertencias y código 1.
- [ ] El `revisor` arranca con `REVISOR_TOKEN_ARCHIVO` y un archivo montado de solo lectura; `/api/estados` responde `401` sin token y la tabla con él; y `docker inspect` del contenedor no muestra el valor del token.
- [ ] Provocas el `permission denied` con `chmod 600` y explicas por qué ocurre usando las palabras *dueño* y `65532`.
- [ ] `docker history --no-trunc --format '{{.CreatedBy}}' curso-docker-revisor:1.3.0 | grep -c 'modulos-de-mentira'` da `0` después de construir con `--secret`.
- [ ] Corres los guiones de [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos) y tus salidas coinciden con las de esta lección, salvo los tiempos, los números de paso de la construcción, la fecha del archivo de `fig06_08.sh`, el orden de las variables en `docker inspect` y la arquitectura del historial. Y al terminar, `docker ps -a --filter name=curso-docker-` no muestra contenedores de esta lección.

## Resumen

Responde sin mirar la lección:

1. ¿Qué es configuración, según *The Twelve-Factor App*, y qué prueba propone para saber si la separaste bien?
2. ¿Cuándo existe un `ARG` y cuándo un `ENV`? ¿Dónde queda escrito el valor de cada uno?
3. ¿Por qué el Dockerfile del `revisor` declara `ARG VERSION` dos veces?
4. ¿Qué diferencia hay entre `-e` y `--env-file`, y qué pasa con las comillas en un archivo de variables?
5. ¿Por qué borrar un archivo en el mismo `RUN` no protege un secreto que llegó por `ARG`?
6. ¿Qué revisa `docker build --check` con la regla `SecretsUsedInArgOrEnv`, y qué no puede ver?
7. ¿Por qué un token por `-e` sigue siendo una mala idea aunque no esté en la imagen?
8. ¿Por qué un archivo de secreto con permisos `600` da `permission denied` dentro del contenedor, y cuáles son los arreglos buenos?
9. ¿Qué hace `--mount=type=secret`, dónde aparece el archivo por omisión y qué significa `required`?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [The Twelve-Factor App, «Config»](https://12factor.net/config): la definición de configuración como lo que varía entre despliegues, la prueba de publicar el código como abierto y la configuración en variables de entorno.
- [Docker, «Build variables»](https://docs.docker.com/build/building/variables/): `ARG` contra `ENV`, que los argumentos no llegan a los contenedores pero pueden persistir en los metadatos, el historial y las atestaciones, el alcance por etapa y la advertencia sobre secretos.
- [Docker, «Build secrets»](https://docs.docker.com/build/building/secrets/): por qué los argumentos y las variables de entorno no son apropiados para secretos, el montaje de secreto, su ruta por omisión `/run/secrets/<id>`, `target` y las formas `src` y `env` de `--secret`.
- [Referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/): las opciones de `RUN --mount=type=secret` (`id`, `target`, `required`, `mode`) y sus valores por omisión, `LABEL` y su lectura con `docker image inspect`, y que `ENV` persiste en los contenedores y se cambia con `docker run --env`.
- [Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/): que el contenido de un secreto no forma parte de la caché y cómo forzar que el paso se repita.
- [Referencia de los servicios de Compose](https://docs.docker.com/reference/compose-file/services/): que con un archivo como fuente los atributos `uid`, `gid` y `mode` de un secreto se ignoran, y cómo lee las comillas el `env_file`.
- [Docker, procedencia SLSA](https://docs.docker.com/build/metadata/attestations/slsa-provenance/): que el modo mínimo, el de por omisión, no incluye los valores de los argumentos y que el modo `max` los expone.
- [Docker, «Build checks»](https://docs.docker.com/build/checks/): la directiva `# check=error=true`.
- [Docker, regla `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/): qué reporta la regla y el ejemplo correcto con montajes de secreto.
- [Referencia de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `-e`, `-e` sin valor y el formato de `--env-file` con sus comentarios.
- [Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/): por qué las variables de entorno no son buen lugar para secretos y la ruta `/run/secrets/<nombre>`.
- [OCI Image Specification, anotaciones](https://github.com/opencontainers/image-spec/blob/main/annotations.md): las definiciones de `org.opencontainers.image.title`, `.version` y `.source`.
- [cmd/link](https://pkg.go.dev/cmd/link): la opción `-X` del enlazador de Go, que fija el valor de una variable de texto al compilar.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones y fechas de «Sobre las corridas».
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **argumento de construcción** (`ARG`) | variable que existe solo mientras se construye la imagen; se cambia con `--build-arg` y su valor queda en el historial |
| **configuración** | lo que cambia de un ambiente a otro; llega al correr, no va en la imagen |
| **etiqueta** (*label*) | par nombre-valor pegado a la imagen como metadato; se lee con `docker image inspect` |
| **etiquetas OCI** | etiquetas con nombres estándar (`org.opencontainers.image.*`) que cualquier herramienta entiende |
| **historial** (*history*) | la lista de instrucciones que crearon la imagen, con sus valores; se lee con `docker history` |
| **montaje de secreto** | archivo que BuildKit pone a disposición de un solo `RUN` y que no queda en ninguna capa |
| **secreto** | configuración que, si se filtra, alguien puede usar en tu contra: tokens, contraseñas, credenciales |
| **secreto de construcción** | el que se necesita para construir la imagen; se entrega con `docker build --secret` |
| **secreto de ejecución** | el que necesita el programa al correr; se entrega como archivo en `/run/secrets/` |
| **variable de entorno** (`ENV`, `-e`) | par nombre-valor que recibe un proceso al arrancar; visible en `docker inspect` |

---

**Siguiente:** [Lección 7 — Salud y ciclo de vida](07-salud-y-ciclo-de-vida.md)
