# Lección 4 — Capas, caché y contexto

Son las 11:20 de la mañana y a las 12 hay demostración con el área que va a usar el `revisor`. Falta un detalle: la tabla del reporte imprime una columna un espacio corrida. Es un cambio de una línea. Lo haces, construyes la imagen y esperas. Trece segundos. Pruebas, no quedó, corriges otra vez. Otros trece. Y otros trece. A la quinta vuelta te das cuenta de que pasaste más tiempo mirando la terminal compilar que pensando en el problema, y de que cada construcción compila **todo** el programa desde cero, aunque solo tocaste un archivo. Mientras tanto, tu compañera, que trabaja en su propia copia del proyecto, pregunta por qué su construcción dice que «subió» 62 MB si el código del `revisor` pesa unos cuantos kilobytes. En su copia alguien borró el `.dockerignore`, y en la carpeta hay un respaldo y la historia de Git. Las dos preguntas tienen la misma respuesta, y no está en el código del `revisor`: está en el orden de cuatro renglones del Dockerfile y en un archivo que se llama `.dockerignore`. Al final de esta lección, ese mismo cambio de una línea se reconstruye en menos de dos segundos.

**Tiempo:** 2 × 45 min

**Qué construyes:** la misma imagen de la Lección 3, ahora como `curso-docker-revisor:1.1.0`, con un Dockerfile reordenado para aprovechar la caché, un montaje de caché para la compilación de Go y un `.dockerignore` más completo. Hace exactamente lo mismo que la `1.0.0`; se reconstruye en segundos y su capa de compilación pesa 100 MB menos.

**Qué aprendes:** que una imagen es una pila de capas y cómo verlas con `docker history`; cómo decide el constructor si una capa sale de la caché o se vuelve a hacer; por qué el **orden** de las instrucciones decide cuánto se reconstruye; cómo leer una construcción con `--progress=plain`; qué es un montaje de caché (`RUN --mount=type=cache`) y por qué su contenido no queda en la imagen; y qué viaja en el contexto de construcción y qué no.

**De dónde vienes.** De la [Lección 3](03-primer-dockerfile.md) traes tu primer Dockerfile: una sola etapa sobre `golang:1.27.3-trixie`, un `COPY . .` que mete todo el proyecto, un `RUN go build`, `USER 10001:10001` y `CMD ["revisor"]` en forma *exec*. Traes también su `.dockerignore` de cinco renglones y la imagen `curso-docker-revisor:1.0.0`, de 1.45 GB. Allá se dijo, de pasada, que copiar todo de golpe hace lenta la reconstrucción; aquí lo vas a medir y a arreglar. De la [Lección 0](00-que-es-un-contenedor.md) traes la idea de que una imagen está hecha de **capas** de solo lectura. Hasta ahora era una frase; en esta lección las vas a contar una por una.

**Qué no hace esta lección.** No achica la imagen de verdad: 1.32 GB sigue siendo enorme, porque la imagen todavía trae el compilador de Go y todo un Debian. Separar la compilación de la imagen final es el tema de la [Lección 5](05-multi-stage.md). Tampoco toca el código del `revisor`, ni su configuración, ni sus secretos. Y no enseña a «descargar las dependencias en una capa aparte», un truco muy común en los tutoriales de Go, porque el `revisor` no tiene dependencias externas: solo usa la biblioteca estándar. Lo que sí tiene, y mucho, es **compilación**, y esa es la caché que se enseña aquí. La sección 4.8 te dice cómo reconocer el otro truco cuando lo veas.

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4, la misma base de Linux Mint 22, el sistema de referencia del curso. Los guiones se corrieron **dentro** de esa máquina virtual, con Docker 29.2.1 (cliente y daemon) y Buildx v0.31.1. El curso se planeó con Docker Engine 29.8.2, y la versión más reciente publicada ese día era la 29.9.2, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)); nada de lo que enseña esta lección cambia entre esas versiones. Tres avisos sobre estas corridas. Primero: la máquina estaba ocupada con otras construcciones al mismo tiempo, así que los **tiempos** tienen ruido; lo que se mantiene en todas las corridas es la **diferencia** entre un Dockerfile y otro, no los milisegundos exactos. Segundo: en esa misma máquina se estaban escribiendo otras lecciones del curso, que crean imágenes con los mismos nombres (`curso-docker-revisor:1.0.0`, `:1.1.0`). Para no borrarles nada ni pisarles una etiqueta, los guiones de esta lección se lanzaron con otro prefijo de nombres, gracias a la variable `PREFIJO` que traen, y el prefijo se devolvió al normal del curso **en el propio comando**, a la vista: el primer renglón de cada salida guardada dice exactamente cómo se corrió, por ejemplo `PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'`. En tu equipo, `./fig04_03.sh` a secas imprime lo mismo sin ese `sed`. Es la única excepción a «se corre tal cual», y existe solo por la máquina compartida. Tercero: la Mac de las corridas no tiene Go 1.27.3 instalado; por eso el error de Go de la Solución 3 se midió dentro de la imagen `golang:1.27.3-trixie`. Lo que **sí** cambia en tu Mint: los tiempos, los identificadores de la caché y, si tu equipo es Intel o AMD, la variante de la imagen de Go que se descarga (`amd64` en vez de `arm64`), aunque el *digest* que verás en la línea del `FROM` es el mismo porque es el del índice de plataformas. Los programas están en [`programas/04-capas-cache-contexto/`](../programas/04-capas-cache-contexto), cada uno con su salida al lado, y `estado/` guarda el `Dockerfile`, el `.dockerignore` y el `Dockerfile.leccion3` (la copia del de la Lección 3, solo para comparar) tal como quedan al terminar.

## Al terminar vas a poder

- Listar con `docker history` las capas de una imagen y decir cuáles agregan archivos y cuáles solo datos.
- Predecir, antes de construir, qué pasos de un Dockerfile saldrán de la caché después de un cambio, y comprobarlo con `--progress=plain`.
- Reordenar un Dockerfile para que un cambio en el código no repita los pasos que no dependen de él.
- Agregar un montaje de caché a un `RUN` de compilación y mostrar que su contenido vive en el constructor y no en la imagen.
- Medir con un archivo de 50 MB qué viaja en el contexto de construcción, con y sin `.dockerignore`.
- Borrar solo tu caché de compilación, sin tocar la de otros proyectos de la misma máquina.

## El porqué antes del cómo

Construir una imagen es repetir una receta. La primera vez, cada paso se hace de verdad: se descarga la base, se copian los archivos, se compila. La segunda vez, casi todo es igual que la primera: la misma base, el mismo `go.mod`, casi el mismo código. Sería absurdo repetirlo todo. Por eso el constructor guarda el resultado de cada paso y, la siguiente vez, si nada de lo que ese paso usa ha cambiado, **reutiliza** el resultado en lugar de repetirlo. A eso se le llama la **caché de construcción**.

El problema es que la caché tiene reglas, y no son las que uno supone. No es «reutiliza lo que no cambió». Es «reutiliza **hasta** el primer paso que cambió, y de ahí para abajo repite todo». Esa diferencia es la escena del principio. En el Dockerfile de la Lección 3, el código entra con un solo `COPY . .` y en el siguiente renglón se compila. Cualquier cambio, aunque sea un comentario, cambia ese `COPY`, y como el `RUN go build` viene después, se repite la compilación completa. Con el Dockerfile de esta lección, el mismo cambio se reconstruye así (lo vas a medir en la sección 4.5):

```text
## 3. Cambio un comentario en internal/reporte/tabla.go
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
...
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
```

De trece segundos a menos de dos, con el mismo código, el mismo cambio y la misma imagen resultante. En una máquina menos ocupada o en un proyecto más grande, la diferencia crece. Y la segunda pregunta de la escena, la de los 62 MB, es la otra cara de la misma moneda: el constructor también necesita saber **qué archivos** puede usar, y si se los mandas todos, los manda todos.

La lección tiene ocho partes:

1. **Una imagen es una pila de capas** (4.1): verlas con `docker history`.
2. **Cómo decide la caché** (4.2): las reglas, con el Dockerfile de la Lección 3 como mal ejemplo.
3. **El orden importa** (4.3): el Dockerfile nuevo, renglón por renglón.
4. **La caché que no es capa** (4.4): `RUN --mount=type=cache`.
5. **Medir** (4.5): el cronómetro y `--progress=plain`.
6. **Qué viaja en el contexto** (4.6), con el error de la lección.
7. **Revisar antes de construir** (4.7).
8. **Lo que vas a ver en otros proyectos** (4.8).

## Los conceptos

### 4.1 Una imagen es una pila de capas

#### 4.1.1 Una capa por paso

La documentación de Docker define una capa así: «cada capa de una imagen contiene un conjunto de cambios al sistema de archivos: agregados, borrados o modificaciones», y explica que eso es útil porque «permite reutilizar capas entre imágenes» ([Docker, «Understanding the image layers»](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/)). Y la página de la caché de construcción conecta las capas con tu receta: «cada instrucción de este Dockerfile se traduce en una capa de tu imagen final» ([Docker, «Docker build cache»](https://docs.docker.com/build/cache/)).

En la Lección 0 viste la consecuencia de las capas para los contenedores: cada contenedor agrega una capa propia, encima, donde escribe. Aquí importa la otra mitad: cómo se apilan las capas de abajo cuando **construyes**. `FROM` no agrega una capa propia: pone debajo todas las capas de la imagen base. Después, cada `COPY` y cada `RUN` deja una capa con los archivos que agregó o cambió, y `WORKDIR` también deja una, pequeña, cuando tiene que crear la carpeta. Las instrucciones que solo anotan algo, como `USER`, `EXPOSE` y `CMD`, dejan un renglón en la historia, pero de cero bytes: agregan datos a la configuración, no archivos.

#### 4.1.2 Verlas con `docker history`

`docker history` muestra «la historia de una imagen», un renglón por paso, del más reciente al más antiguo ([`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/)). Con `--format` escoges qué columnas ver: `.Size` es el tamaño que agregó ese paso y `.CreatedBy`, el comando que lo creó. Esta es la historia de la imagen de la Lección 3, sacada de `fig04_03.sh` (el guion completo aparece en 4.5; aquí solo se mira su sección 5):

```text
$ docker history curso-docker-revisor:1.0.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
110MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
115kB	COPY . . # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
```

Esta salida es estable en una máquina `arm64`; en `amd64` los tamaños pueden diferir un poco. El `head -7` se queda con los siete renglones de arriba y el `cut -c1-70` recorta cada renglón a 70 caracteres para que quepa; la `…` es de Docker, que también recorta los comandos largos (con `--no-trunc` no lo hace).

Léela de abajo hacia arriba, que es el orden en que se construyó:

- `WORKDIR /go` **no es tuyo**. Es el último paso de la imagen de Go. Si quitas el `head -7`, debajo aparecen una docena de renglones más, todos de `golang:1.27.3-trixie`: en la corrida de referencia del curso, el más grande era una capa de 290 MB con la instalación de Go y, más abajo, varias de 281, 208 y 156 MB con el Debian de base. Tu imagen **empieza** donde termina la de Go.
- `WORKDIR /src`, 8.19 kB: tu primer paso. Crea la carpeta.
- `COPY . . # buildkit`, 115 kB: todo el proyecto. El comentario `# buildkit` dice que la capa la creó BuildKit, el constructor que conociste en la Lección 3.
- `RUN /bin/sh -c go build ...`, **110 MB**. Fíjate: el `RUN` se ejecuta con `/bin/sh -c`, porque en el Dockerfile está en forma *shell*. Para un `RUN` eso está bien; la regla de la forma *exec* era para `CMD` y `ENTRYPOINT`.
- `USER`, `EXPOSE`, `CMD`: cero bytes. Solo datos.

Ahora la pregunta que abre esta lección: el `revisor` compilado pesa unos 10 MB. ¿Qué son los otros 100 MB de esa capa? La respuesta está en la sección 4.4, y es la razón por la que la imagen nueva pesa menos.

> [!NOTE]
> 🔧 **Observación de ingeniería 4.1**
> Una capa nunca se borra desde arriba. Si un `RUN` crea un archivo de 100 MB y el siguiente `RUN` lo borra, la imagen sigue pesando esos 100 MB: la segunda capa solo anota «este archivo ya no se ve». Lo que entra en una capa se queda en la imagen. Por eso lo que no debe estar en la imagen se evita **antes** de que entre, no se limpia después.

### 4.2 Cómo decide la caché

#### 4.2.1 Las tres reglas

La documentación de la caché las explica en dos páginas, y caben en tres reglas:

1. **Para `COPY` y `ADD`, cuentan los archivos, menos su fecha.** La documentación dice que el constructor «calcula una suma de comprobación de la caché a partir de los metadatos de los archivos» y que la caché se invalida «si cambiaron los metadatos de cualquiera de los archivos involucrados». En la práctica, que vas a medir en el Ejercicio 1: cambiar el contenido de un archivo la invalida, y cambiar solo su fecha, no. La documentación lo dice así: la fecha de modificación **no** cuenta; «si solo cambió el `mtime` de los archivos copiados, la caché no se invalida» ([Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/)).
2. **Para `RUN`, cuenta solo el texto del comando.** Aparte de `ADD` y `COPY`, la revisión de la caché no mira los archivos; «solo se usa la cadena del comando para encontrar una coincidencia» (misma página). Un `RUN go build` que ya se ejecutó con la misma capa de abajo sale de la caché aunque afuera haya salido otra versión de algo.
3. **Una vez que algo se invalida, todo lo de abajo se repite.** «Si una capa cambia, todas las capas que vienen después también se ven afectadas. Aunque no fueran a construir nada distinto, de todos modos tienen que volver a correr» ([Docker, «Docker build cache»](https://docs.docker.com/build/cache/)). La página de invalidación lo dice igual: una vez invalidada la caché, los comandos siguientes generan imágenes nuevas y la caché no se usa.

La tercera regla es la que importa para el orden. La caché no es un mapa de «qué cambió»; es una cadena. Cada eslabón depende del de arriba. Si se rompe uno, se rompen todos los de abajo.

#### 4.2.2 El Dockerfile de la Lección 3, a la luz de las reglas

Repasa el Dockerfile de la Lección 3 con las tres reglas en la mano:

```dockerfile
FROM golang:1.27.3-trixie
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

(Es un fragmento: el archivo completo es `estado/Dockerfile.leccion3`, idéntico al de la Lección 3.) El `COPY . .` depende de **todos** los archivos del contexto. Cambias un comentario en `internal/reporte/tabla.go`: regla 1, el contenido cambió, el `COPY` se invalida. Regla 3: el `RUN go build` viene después, así que se repite. Y como el `RUN` arranca en una capa nueva, sin nada de la compilación anterior, Go compila **todo** desde cero: tu programa, cada paquete de `internal/` y cada paquete de la biblioteca estándar que usa.

Así lo vio `fig04_03.sh` (sección 3), en el formato que explica 4.5:

```text
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 10.1s RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

`CACHED` quiere decir «salió de la caché»; `DONE` con un tiempo, «se hizo de verdad». El `WORKDIR` salió de la caché; el `COPY` y la compilación se rehicieron. El paso 1, el `FROM`, siempre dice `DONE 0.0s`: el constructor confirma que tiene la imagen base, que ya estaba descargada, y no hace nada más.

### 4.3 El orden importa

#### 4.3.1 El Dockerfile de la lección

La guía de optimización de Docker lo dice en una línea: «los pasos que cambian seguido deberían ir cerca del final del Dockerfile» ([Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/)). Para el `revisor`, eso da este Dockerfile. Reemplaza al de la Lección 3, en la raíz del proyecto, y se llama `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# fig04_01.Dockerfile — Lección 4: la misma imagen que la 3, ordenada para la caché.
FROM golang:1.27.3-trixie

WORKDIR /src

# Primero lo que casi nunca cambia (la descripción del módulo)...
COPY go.mod ./
# ...después el código, que cambia en cada edición.
COPY cmd/ cmd/
COPY internal/ internal/

# La caché de compilación de Go vive en un montaje de caché: sobrevive entre
# construcciones, acelera la siguiente y NO queda dentro de la imagen.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -o /usr/local/bin/revisor ./cmd/revisor

USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

Comparado con el de la Lección 3, cambian dos cosas: el `COPY . .` se partió en tres, y el `RUN` ganó una opción `--mount`. Lo demás es igual, renglón por renglón, y la imagen resultante hace lo mismo.

#### 4.3.2 Los tres `COPY`

**`COPY go.mod ./`.** El archivo `go.mod` describe el módulo: su nombre y la versión de Go que pide. En el `revisor` tiene dos renglones y casi nunca cambia. Copiarlo primero, solo, crea una capa que sobrevive a cualquier cambio del código. En un proyecto con dependencias, aquí iría también `go.sum` y el paso de descarga (4.8); en el `revisor`, el beneficio es pequeño, pero el hábito es el mismo: lo que menos cambia, más arriba.

**`COPY cmd/ cmd/` y `COPY internal/ internal/`.** El código, en dos capas. `cmd/revisor/` es el servidor HTTP; `internal/` son los paquetes que vienen del curso de Go (configuración, consulta, reporte). Separarlos no cambia mucho la velocidad, pero deja más claro en `docker history` qué parte cambió, y el orden sigue la regla: `internal/`, que cambia más mientras desarrollas el reporte, queda abajo.

Fíjate en un efecto secundario que vale oro y que se mide en 4.6: con `COPY` selectivos, **solo esas tres rutas** pueden entrar a la imagen. Un `.env` olvidado en la carpeta no entra aunque el `.dockerignore` lo olvide, porque ningún `COPY` lo pide. El `.dockerignore` sigue siendo obligatorio, pero ya no es la única barrera.

#### 4.3.3 El mismo cambio, con el orden nuevo

Ahora el mismo comentario en `tabla.go`, con este Dockerfile. Es la sección 3 de `fig04_03.sh`, segunda mitad:

```text
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.8s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

Las reglas, otra vez. `go.mod` no cambió: caché. `cmd/` no cambió: caché. `internal/` sí cambió: se rehace, y por la regla 3, el `RUN` también. Hasta aquí el orden te ahorró poco, porque la compilación sigue repitiéndose. Pero mira el tiempo del `RUN`: **0.8 segundos**, contra 10.1 del Dockerfile viejo. La compilación se repitió y, sin embargo, casi no compiló nada. Eso no lo hizo el orden. Lo hizo el `--mount`, y es la sección que sigue.

Antes de seguir, la prueba de que la imagen nueva hace lo mismo que la vieja. La sección 7 de `fig04_03.sh` corre la `1.1.0` como en la Lección 3, con el `revisor` revisándose a sí mismo, y le pregunta por su salud desde dentro del contenedor (la imagen de Go trae `curl`; así no hace falta publicar un puerto):

```text
## 7. La imagen nueva hace lo mismo que la vieja
$ docker exec curso-docker-revisor curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
```

Igual que la `1.0.0`. El `"desarrollo"` sigue ahí porque la versión todavía no se graba en el programa; eso llega en la Lección 6.

### 4.4 La caché que no es una capa: `RUN --mount=type=cache`

#### 4.4.1 Go ya tiene su propia caché

El compilador de Go no compila dos veces lo mismo si puede evitarlo. Su documentación lo dice así: «el comando `go` guarda en caché los resultados de compilación para reutilizarlos en compilaciones futuras», y por omisión los guarda en una carpeta llamada `go-build` dentro de la carpeta de caché del usuario ([documentación de `go`, «Build and test caching»](https://pkg.go.dev/cmd/go#hdr-Build_and_test_caching)). En Linux, para el usuario `root`, esa carpeta es `/root/.cache/go-build`. Si cambias un archivo de `internal/reporte`, Go solo recompila ese paquete y los que dependen de él, y toma el resto de la caché.

En tu equipo, esa caché funciona sola. Dentro de una construcción de Docker, no: cada `RUN` arranca en la capa que le dejó el paso anterior, y en el Dockerfile de la Lección 3 esa capa no tiene caché de Go, porque se acaba de rehacer el `COPY`. Peor todavía: lo que Go escribe en `/root/.cache/go-build` durante el `RUN` **se queda en la capa del `RUN`**. Esos son los 100 MB que sobraban en 4.1.2.

#### 4.4.2 El montaje de caché

`RUN --mount` permite «crear montajes del sistema de archivos a los que la construcción puede acceder», y el tipo `cache` sirve para que «el contenedor de construcción guarde en caché carpetas de compiladores y gestores de paquetes» ([referencia del Dockerfile, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache)). La guía de optimización completa el cuadro: un montaje de caché es «una ubicación de caché persistente» para las construcciones; la caché se acumula entre construcciones y se comparte entre varias de ellas ([Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/)).

Traducido: durante ese `RUN`, la carpeta `/root/.cache/go-build` no es parte de la capa. Es una carpeta que el **constructor** guarda aparte y vuelve a montar en cada construcción. Go encuentra ahí lo que compiló la vez anterior, y lo que escribe ahí no termina en la imagen.

Las opciones que usa el `revisor`:

- **`type=cache`**: el tipo de montaje.
- **`target=/root/.cache/go-build`**: dónde aparece la carpeta dentro del `RUN`. Es la carpeta por omisión de la caché de Go, así que Go la usa sin configurar nada. La guía de Docker usa esta misma ruta en su ejemplo de Go.
- **`id=curso-docker-go-build`**: el nombre de la caché. La referencia dice que es opcional y sirve para «identificar cachés separadas»; si no lo das, vale lo mismo que `target`. Más abajo verás por qué conviene darlo.

Hay otras opciones (`sharing`, `mode`, `uid`…), y la referencia las lista; el `revisor` no las necesita. Una nota: el montaje se usa al construir, cuando el usuario todavía es `root`; el `USER 10001:10001` viene después y no le afecta.

#### 4.4.3 La caché vive en el constructor, no en la imagen

Las afirmaciones se comprueban. La sección 6 de `fig04_03.sh` busca la caché en los dos lugares donde podría estar:

```text
## 6. La caché de compilación vive en el constructor, no en la imagen
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID                           RECLAIMABLE   SIZE      LAST ACCESSED
xq0we4j0a5g4a98ftg4xaezzc*   true          99.59MB   1 second ago
$ docker buildx du --verbose --filter 'description~=curso-docker-fig04-go-build' | grep -E '^(Description|Type):'
Description:  cached mount /root/.cache/go-build from exec /bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor with id "/curso-docker-fig04-go-build"
Type:         exec.cachemount
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.1.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
du: cannot access '/root/.cache/go-build': No such file or directory
[código de salida: 1]
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.0.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
95M	/root/.cache/go-build
```

El identificador de la primera línea y el «1 second ago» cambian; los tamaños pueden variar unos megabytes. `docker buildx du` muestra lo que ocupa el constructor en disco (*disk usage*), y `--filter description~=...` se queda con los registros cuya descripción contiene ese texto. Con `--verbose` muestra cada registro completo; el `grep` se queda con su descripción y su tipo, que vas a necesitar en 4.4.5. Los dos `docker run` entran a cada imagen como `root` (`--user 0`, solo para poder leer `/root`) y miden la carpeta.

Tres renglones, tres hechos:

1. **En el constructor** hay una caché de 99.59 MB, de tipo `exec.cachemount` (montaje de caché), con el `id` del guion. Ahí está lo que compiló Go.
2. **En la imagen `1.1.0`**, la carpeta ni existe. La caché no viajó.
3. **En la imagen `1.0.0`**, la de la Lección 3, la carpeta pesa 95 MB. Ahí estaban los 100 MB de más.

¿Y por qué el guion usa `curso-docker-fig04-go-build` y no el `curso-docker-go-build` del Dockerfile? Porque el guion cambia el `id` al armar su copia del proyecto, para tener una caché **solo suya**, empezar de verdad en frío y poder borrarla al terminar sin tocar la de tu proyecto. Es la misma idea que verás en 4.4.5.

Y la sección 5 del mismo guion lo confirma desde las imágenes:

```text
$ docker history curso-docker-revisor:1.1.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
10MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
77.8kB	COPY internal/ internal/ # buildkit
41kB	COPY cmd/ cmd/ # buildkit
12.3kB	COPY go.mod ./ # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
$ docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^curso-docker-revisor:1\.[01]\.0 '
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.0.0 1.45GB
$ for i in curso-docker-revisor:1.0.0 curso-docker-revisor:1.1.0; do docker image inspect --format "$i {{.Size}}" $i; done
curso-docker-revisor:1.0.0 337298513
curso-docker-revisor:1.1.0 314341606
```

El `RUN` pasó de 110 MB a **10 MB**: ahora la capa tiene solo el ejecutable. Las tres capas de código suman lo mismo que el `COPY . .` de antes, repartido. Ese es el número firme: **la capa adelgazó 100 MB**, sin quitar nada que el `revisor` necesite.

Los otros dos renglones cuentan el tamaño de la imagen de dos formas, y conviene no confundirlas. `docker image inspect` da el tamaño del **contenido**, comprimido como se guarda y se transfiere: 337.3 MB contra 314.3 MB, 23 MB menos. `docker image ls` da 1.45 GB contra 1.32 GB, unos 130 MB menos. La diferencia entre las dos formas viene del almacén de imágenes de Docker Engine 29, que según su documentación guarda las imágenes «en formato comprimido y sin comprimir» ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)). Los 130 MB cuadran con esa explicación: unos 100 MB de la capa sin comprimir más unos 23 MB comprimidos, con el redondeo de los gigabytes. Esa suma es una cuenta nuestra, no una regla de la documentación; lo que sí es seguro es la capa de `docker history`. Es un ahorro que no buscabas, y llegó por hacer bien lo que sí buscabas.

> [!NOTE]
> 🔧 **Observación de ingeniería 4.2**
> Hay dos cachés y conviene no confundirlas. La **caché de capas** decide si un paso se repite o no: es todo o nada. El **montaje de caché** hace que, cuando un paso se repite, se repita barato. El orden del Dockerfile trabaja sobre la primera; el `--mount`, sobre la segunda. Con las dos juntas, el `RUN go build` casi nunca se salta, pero casi nunca cuesta.

#### 4.4.4 Las dos cachés son independientes

Un detalle que te va a ahorrar una confusión: son dos cosas aparte, y se manejan aparte. `--no-cache` le pide al constructor que no use la caché de **capas**; para que una medición en frío sea honesta, la sección 1 de `fig04_03.sh` además borra su **montaje** antes de empezar, con su propio `id` (4.4.5). Y al revés: un paso que sale de la caché de capas no ejecuta su `RUN`, así que ni lee ni llena el montaje. Si construyes una vez con todo en la caché de capas, el montaje sigue tan vacío o tan lleno como estaba.

#### 4.4.5 Un `id` propio, y por qué nunca un borrado amplio

El montaje de caché ocupa disco, y un día vas a querer borrarlo. El comando es `docker buildx prune`, que borra caché del constructor, y su opción `--filter` permite escoger qué borrar: por antigüedad (`until`), por tipo (`type`, y uno de los tipos es `exec.cachemount`, justo el de los montajes) o por un texto de la descripción (`description`) ([`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/)). Ya viste en 4.4.3 cómo es la descripción de un montaje de caché: `cached mount /root/.cache/go-build from exec … with id "/curso-docker-fig04-go-build"`. El `id` aparece al final, después de una diagonal y entre comillas. Por eso el `id` importa: es la etiqueta que te deja encontrar **tu** caché y solo la tuya.

Aquí está el peligro. Un filtro amplio, como `description~=go-build`, atrapa la caché de compilación de **cualquier** proyecto de Go de la máquina que use la ruta por omisión. No es hipotético: en la máquina de estas corridas, mientras se escribía esta lección, `docker buildx du --filter 'description~=go-build'` encontró dos registros, el de esta lección y el de otro proyecto que estaba construyendo al mismo tiempo. Un `prune` con ese filtro habría borrado la caché del otro, y su siguiente construcción habría tardado sin que nadie supiera por qué. En una máquina compartida (un servidor de construcción, la computadora de un equipo, o la tuya con varios proyectos), un borrado amplio es borrar lo de otros.

La regla de este curso tiene dos partes:

1. **Cada proyecto, su `id`.** El `revisor` usa `curso-docker-go-build`. Si mañana empaquetas otro proyecto de Go, le das otro. Sin `id`, todos los proyectos que usen `target=/root/.cache/go-build` comparten la misma caché, porque el `id` por omisión es la ruta.
2. **Borrar con el `id` completo y el tipo.** Así lo hacen los guiones de esta lección al salir:

```bash
docker buildx prune -f --filter type=exec.cachemount \
  --filter "description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]"
```

El `type=exec.cachemount` limita el borrado a montajes de caché. El `~=` compara con una expresión regular, y el `[^a-z0-9-]` de cada lado («cualquier carácter que no sea letra minúscula, número ni guion») exige que el `id` aparezca **completo**: en la descripción, lo que rodea al `id` son la diagonal de antes y la comilla de después, y las dos cumplen. Así, un `id` más largo que lo contenga, como `curso-docker-fig04-go-build-viejo`, no se borra por accidente. ¿Por qué no escribir directamente la diagonal y las comillas en el filtro? Porque con la versión de Buildx de estas corridas (v0.31.1), un filtro con espacios, comillas o `/` no encontró nada: se midió con `docker buildx du` antes de usarlo. Es una buena costumbre: **prueba un filtro con `du`, que solo mira, antes de usarlo con `prune`, que borra.**

Un borrado que no avisa si no borró nada no demuestra nada, así que la sección 8 de `fig04_03.sh` borra a la vista y luego vuelve a buscar:

```text
## 8. Borro SOLO mi caché de compilación y compruebo que ya no está
$ docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]' | tail -1
Total:	99.59MB
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID        RECLAIMABLE   SIZE      LAST ACCESSED
```

El `prune` reporta lo que liberó (`Total: 99.59MB`, la misma caché de la sección 6), y el `du` siguiente ya no encuentra nada: solo queda el encabezado de la tabla. Para tu proyecto, el mismo comando con `curso-docker-go-build` borra la caché del `revisor` y nada más; la siguiente construcción será lenta una vez y volverá a llenarla.

### 4.5 Medir: el cronómetro y `--progress=plain`

#### 4.5.1 Ver lo que hace el constructor

Cuando construyes en una terminal, BuildKit dibuja una pantalla que se redibuja y se colorea. Está bien para mirar, pero no se puede guardar ni buscar en ella. La opción `--progress` decide el formato. Según la referencia de `docker buildx build`, el valor por omisión es `auto`, que usa el modo `tty` (el interactivo, «con color y redibujado») si la salida es una terminal, y `plain` si no; `plain` «imprime el progreso de la construcción en texto plano» ([`docker buildx build`, `--progress`](https://docs.docker.com/reference/cli/docker/buildx/build/#progress)). En un servidor de construcción, donde no hay terminal, siempre ves `plain`, así que conviene saber leerlo.

El texto plano tiene esta forma: cada paso es un número con `#` delante. Primero aparece el renglón que lo nombra, como `#10 [5/6] COPY internal/ internal/`, y después los renglones de lo que hizo, todos con el mismo número. Un paso termina normalmente con uno de dos renglones: `#10 CACHED`, si salió de la caché, o `#10 DONE 0.5s`, si se hizo, con su tiempo. Si falla, termina con `#10 ERROR: …`, como verás en 4.6.2. Los pasos `[internal]` son los que el constructor hace por su cuenta: leer el Dockerfile, el `.dockerignore`, el contexto.

#### 4.5.2 El guion de la medición

`fig04_03.sh` construye los dos Dockerfile en cuatro situaciones, cronometra cada construcción y resume el registro de `--progress=plain` en una tabla de pasos. Es el guion más largo de la lección, y sus secciones 5 a 8 son las que ya viste en 4.1.2, 4.3.3, 4.4.3 y 4.4.5:

```bash
#!/usr/bin/env bash
# fig04_03.sh — Capas y caché: el Dockerfile de la Lección 3 contra el de la
# Lección 4. Construye los dos en frío, otra vez sin cambios y después de
# cambiar un archivo; cronometra cada construcción, muestra qué pasos salieron
# de la caché (--progress=plain) y compara las capas con docker history.
# Borra al salir sus imágenes y su caché de compilación.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L3="${PREFIJO}revisor:1.0.0"
L4="${PREFIJO}revisor:1.1.0"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

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
# construir ETIQUETA DOCKERFILE [opciones...]: construye con --progress=plain,
# guarda el registro en ../construccion.log e imprime cuánto tardó
construir() {
  local etiqueta="$1" archivo="$2" inicio fin; shift 2
  inicio=$(t)
  docker build --progress=plain "$@" -t "$etiqueta" -f "$archivo" . > ../construccion.log 2>&1
  fin=$(t)
  echo "$etiqueta ($archivo${*:+ $*}): $(( fin - inicio )) ms"
}
# pasos: de ../construccion.log, cada paso [n/m] con su estado final
pasos() {
  awk '
    /^#[0-9]+ \[([a-z0-9-]+ )?[0-9]+\/[0-9]+\]/ {
      if (!($1 in paso)) {
        l=$0; sub(/^#[0-9]+ \[([a-z0-9-]+ )?/, "", l); split(l, p, "/"); i=p[1]+0
        sub(/^[0-9]+\/[0-9]+\] /, "", l); sub(/--mount=[^ ]+ +/, "", l); paso[$1]=i; nombre[i]=l; if (i > k) k=i
      }
    }
    /^#[0-9]+ (CACHED|DONE)/ { if ($1 in paso) estado[paso[$1]]=$2 ($2=="DONE" ? " " $3 : "") }
    END { for (i=1; i<=k; i++) printf "  paso %d  %-10s %s\n", i, estado[i], substr(nombre[i], 1, 60) }
  ' ../construccion.log
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rm -f "${PREFIJO}revisor" >/dev/null 2>&1; docker rmi -f "$L3" "$L4" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "1. En frío: sin caché de capas y con la caché de compilación vacía"
borrar_cache
construir "$L3" Dockerfile.leccion3 --no-cache
pasos
construir "$L4" Dockerfile --no-cache
pasos

titulo "2. Otra vez, sin cambiar nada"
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "3. Cambio un comentario en internal/reporte/tabla.go"
echo "// cambio de prueba $(date +%s)" >> internal/reporte/tabla.go
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "4. Cambio un archivo que el .dockerignore deja fuera"
echo "notas de trabajo $(date +%s)" > NOTAS.md
construir "$L4" Dockerfile
pasos

titulo "5. Las capas de cada imagen: solo los pasos de la receta"
muestra "docker history $L3 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70"
muestra "docker history $L4 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70"
muestra "docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^${PREFIJO}revisor:1\.[01]\.0 '"
muestra "for i in $L3 $L4; do docker image inspect --format \"\$i {{.Size}}\" \$i; done"

titulo "6. La caché de compilación vive en el constructor, no en la imagen"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
muestra "docker buildx du --verbose --filter 'description~=${CACHE_ID}' | grep -E '^(Description|Type):'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L4 sh -c 'du -sh /root/.cache/go-build 2>&1'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L3 sh -c 'du -sh /root/.cache/go-build 2>&1'"

titulo "7. La imagen nueva hace lo mismo que la vieja"
docker run -d --name "${PREFIJO}revisor" -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$L4" >/dev/null
for _ in $(seq 40); do docker exec "${PREFIJO}revisor" curl -fsS -o /dev/null http://127.0.0.1:8080/salud 2>/dev/null && break; sleep 0.5; done
muestra "docker exec ${PREFIJO}revisor curl -s http://127.0.0.1:8080/salud"
docker rm -f "${PREFIJO}revisor" >/dev/null

titulo "8. Borro SOLO mi caché de compilación y compruebo que ya no está"
muestra "docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]' | tail -1"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
```

Las ayudas del principio son las de la Lección 3 (`titulo`, `muestra`, `t`), más tres nuevas. `construir` construye con `--progress=plain`, guarda el registro en un archivo y cronometra. `pasos` es un pequeño programa de `awk` que lee ese registro y, para cada paso numerado `[n/m]`, imprime su número, su nombre y su estado final; quita del nombre la opción `--mount=...` para que el renglón quepa, y numera los pasos él mismo porque, cuando otra construcción comparte pasos idénticos en la misma máquina, BuildKit puede mostrar el número de paso de la otra. `borrar_cache` es la de 4.4.5.

Tres detalles más. El cambio lleva la hora (`$(date +%s)`) para que sea distinto en cada corrida: si escribieras siempre el mismo texto, la segunda vez que corrieras el guion ese contenido ya estaría en la caché de capas, y el «cambio» saldría `CACHED`. (Le pasó a quien escribe esta lección en una primera versión del guion, y es una buena muestra de que la caché recuerda contenidos, no momentos.) La sección 7 usa `docker exec ... curl` para hablar con el `revisor` desde dentro de su contenedor, sin publicar puertos. Y el guion, igual que los de la Lección 3, borra al salir las imágenes que creó; si quieres conservar la `1.1.0`, constrúyela después en tu proyecto con `docker build -t curso-docker-revisor:1.1.0 .`.

#### 4.5.3 Los números

Las secciones 1 y 2 de la salida:

```text
$ PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## 1. En frío: sin caché de capas y con la caché de compilación vacía
curso-docker-revisor:1.0.0 (Dockerfile.leccion3 --no-cache): 9909 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 7.1s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile --no-cache): 12207 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 10.5s RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## 2. Otra vez, sin cambiar nada
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 1176 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY . .
  paso 4  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile): 628 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

Los tiempos cambian en cada corrida; la secuencia de `CACHED` y `DONE` es estable. (El `WORKDIR /src` sale `CACHED` aun con `--no-cache`. Es un detalle de cómo BuildKit trata ese paso, que no agrega archivos del contexto ni ejecuta nada, y no cambia lo que importa: los `COPY` y el `RUN` sí se rehicieron.)

**En frío** los dos compilan todo desde cero. Los tiempos de esta corrida (9.9 y 12.2 s) dependen sobre todo del ruido de la máquina: en corridas anteriores del mismo guion, con las mismas construcciones y la máquina más o menos ocupada, salieron 12.5 contra 7.1 s, 18.6 contra 10.5 s y 20.2 contra 23.0 s, a veces ganando uno y a veces el otro. Lo estable es el orden de magnitud: **diez a veinte segundos**, el costo de compilar todo. Ese costo no lo quita ningún orden: la primera construcción siempre se paga.

**Sin cambios**, los dos salen enteros de la caché en menos de un segundo. Tampoco hay diferencia aquí: la caché funciona igual de bien con los dos Dockerfile cuando nada cambió.

La diferencia aparece en la sección 3, **con un cambio**, que es la que viste en 4.2.2 y 4.3.3: 13.0 s contra 1.8 s, y el `RUN` en 10.1 s contra 0.8 s. Y ese es el caso que importa, porque es el de todos los días: cambias algo y vuelves a construir.

La sección 4 cierra con un caso que conecta con lo que viene:

```text
## 4. Cambio un archivo que el .dockerignore deja fuera
curso-docker-revisor:1.1.0 (Dockerfile): 790 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

Se agregó un `NOTAS.md` a la carpeta y todo salió de la caché. El archivo ni siquiera llegó al constructor: el `.dockerignore` lo dejó fuera (4.6). Lo que no viaja no puede invalidar nada.

> [!NOTE]
> 🔧 **Observación de ingeniería 4.3**
> Un tiempo de construcción solo, sin la tabla de pasos, no te dice nada útil: no sabes si fue lento porque compiló, porque descargó o porque la máquina estaba ocupada. Cuando una construcción tarda más de lo que esperas, la primera pregunta no es «¿cuánto tardó?», sino «¿qué paso se rehízo, y por qué?». `--progress=plain` te da esa respuesta paso por paso.

### 4.6 Qué viaja en el contexto

#### 4.6.1 BuildKit solo pide lo que necesita

En la Lección 3 viste que el contexto es la carpeta que le das a `docker build` y que el `.dockerignore` dice qué no viaja. Falta una pieza: **BuildKit no manda todo el contexto**. Entre las mejoras que su documentación lista sobre el constructor anterior están dos que vas a ver ahora mismo: «transferir de forma incremental solo los archivos que cambiaron en tu contexto entre construcciones» y «detectar y saltarse la transferencia de archivos que no se usan en tu contexto» ([Docker, «BuildKit»](https://docs.docker.com/build/buildkit/)).

`fig04_04.sh` lo mide. Siembra en la carpeta del proyecto un respaldo de 50 MB y una carpeta `.git` falsa de 10 MB, y construye tres veces:

```bash
#!/usr/bin/env bash
# fig04_04.sh — Qué viaja en el contexto. Siembra en la carpeta un respaldo de
# 50 MB y una carpeta .git falsa de 10 MB, y construye tres veces:
#   1) Dockerfile de esta lección (COPY selectivos), con .dockerignore;
#   2) Dockerfile de la Lección 3 (COPY . .), con .dockerignore;
#   3) Dockerfile de la Lección 3, SIN .dockerignore: falla a propósito.
# Borra al salir lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L4="${PREFIJO}revisor:1.1.0"
CON="${PREFIJO}revisor:con-ignore"
SIN="${PREFIJO}revisor:sin-ignore"

cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rmi -f "$L4" "$CON" "$SIN" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB"
head -c 52428800 /dev/urandom > respaldo.tar
mkdir -p .git && head -c 10485760 /dev/urandom > .git/objeto-falso
muestra "for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size \$f; done"

titulo "1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore"
muestra "docker build --progress=plain -t $L4 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore"
muestra "docker build --progress=plain -t $CON -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "3. Dockerfile de la Lección 3, SIN .dockerignore"
mv .dockerignore dockerignore.apartado
muestra "docker build --progress=plain -t $SIN -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"
grep -E -A4 '^#[0-9]+ ERROR|error obtaining' ../construccion.log | head -8
mv dockerignore.apartado .dockerignore
```

`head -c 52428800 /dev/urandom` escribe 50 MB de bytes al azar: un archivo que pesa como un respaldo real y que no se puede comprimir. `du -sh --apparent-size` mide el tamaño de cada cosa. De cada construcción, el guion guarda el registro y busca el renglón `transferring context`, que dice cuánto mandó el cliente al constructor. Es `set -uo pipefail`, sin `-e`, porque la tercera construcción falla a propósito y el guion tiene que seguir. Las tres construcciones usan tres etiquetas distintas (`1.1.0`, `con-ignore` y `sin-ignore`) para que en la salida se lea qué es cada una.

```text
$ PREFIJO=curso-docker-l04- ./fig04_04.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB
$ for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size $f; done
50M	respaldo.tar
10M	.git
15K	cmd
27K	internal
41	go.mod
61M	.

## 1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:1.1.0 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 42.80kB done

## 2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:con-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 1.00kB done
```

Los números de paso (`#7`) y los tiempos pueden cambiar; los tamaños transferidos son estables si corres el guion tal cual.

La carpeta pesa **61 MB**, y el código, unos 42 kB. En la primera construcción viajaron **42.80 kB**: el código y nada más. En la segunda viajó **1.00 kB**, aunque el Dockerfile de la Lección 3 pide todo con `COPY . .`. Las dos frases de la documentación explican los dos números:

- **«Saltarse lo que no se usa»**: en la primera, el respaldo y el `.git` no viajaron por dos razones a la vez. El `.dockerignore` los excluye, y además los `COPY` solo piden `go.mod`, `cmd/` e `internal/`.
- **«Solo lo que cambió»**: en la segunda, el código ya estaba del lado del constructor desde la primera, y no había cambiado. Solo se mandaron diferencias. Por eso el número del renglón `transferring context` depende de lo que construiste antes en esa misma carpeta: la primera vez manda el código; las siguientes, casi nada.

#### 4.6.2 Sin `.dockerignore`: el error de la lección

La tercera construcción es la del Dockerfile de la Lección 3, con `COPY . .`, **sin** `.dockerignore`:

```text
## 3. Dockerfile de la Lección 3, SIN .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:sin-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 1
#6 transferring context: 62.93MB 0.1s done
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
------
 > [4/4] RUN go build -o /usr/local/bin/revisor ./cmd/revisor:
0.344 error obtaining VCS status: exit status 128
0.344 	Use -buildvcs=false to disable VCS stamping.
------
```

Los números de paso y los tiempos (`0.344`, `0.1s`) cambian; el resto es estable.

Dos cosas pasaron. La primera, la que esperabas: viajaron **62.93 MB**, el respaldo, el `.git` y el código. Son los 62 MB de la escena: los de una carpeta sin `.dockerignore`, con un respaldo y la historia de Git. En tu equipo es un segundo; en un servidor de construcción que manda el contexto por la red, en cada construcción, se nota. Y lo que viaja con `COPY . .` termina dentro de la imagen, como el `.env` de la Lección 3.

La segunda es la sorpresa: **la construcción falló**, y no por Docker. El `.git` llegó a `/src` dentro de la imagen, y Go, al compilar, lo vio. Por omisión, Go intenta grabar en el ejecutable la información del control de versiones (qué *commit*, si había cambios sin guardar), y lo hace cuando el paquete principal, su módulo y la carpeta actual están en el mismo repositorio ([documentación de `go`, opción `-buildvcs`](https://pkg.go.dev/cmd/go#hdr-Build_flags)). Para eso llamó a la herramienta de control de versiones, y como el `.git` era falso, la herramienta falló: `exit status 128`. Go se detuvo y sugirió `-buildvcs=false`.

Este error lo vas a ver en la vida real con un `.git` de verdad pero incompleto, o en una imagen donde la herramienta `git` no puede leer el repositorio. Y con un repositorio completo y sano, no falla, pero hace algo peor sin avisar: graba datos de tu repositorio en el ejecutable, y el contenido de la imagen depende de si había cambios sin guardar en tu carpeta.

#### 4.6.3 El `.dockerignore` de la lección

El arreglo no es `-buildvcs=false`. Es que el `.git` no viaje. Este es el `.dockerignore` con el que termina la lección; reemplaza al de la Lección 3:

```text
# fig04_02.dockerignore
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

Los cinco renglones de la Lección 3 siguen ahí, con su porqué. Se agregan tres:

- **`*.md`**: las notas, el `README.md`, la bitácora. El `revisor` no necesita ningún archivo Markdown para compilarse, y ya viste en la sección 4 de `fig04_03.sh` que, con esta línea, editar tus notas no invalida nada.
- **`compose.yaml`**: el archivo que describe el sistema completo y que escribirás en la Lección 9. Describe cómo se **corre** la imagen; no tiene nada que hacer **dentro** de ella.
- **`secretos/`**: la carpeta donde, a partir de la Lección 6, vivirán los archivos con tokens de mentira. Se excluye desde hoy, antes de que exista, por la misma razón que en la Lección 3 se excluyó el `.env` antes de que hubiera uno: el día que alguien cree esa carpeta, el `.dockerignore` ya la estará esperando.

Con este archivo y los `COPY` selectivos, hay dos barreras entre tu carpeta y la imagen: lo que el `.dockerignore` deja viajar, y de eso, solo lo que algún `COPY` pide.

> [!NOTE]
> 🔧 **Observación de ingeniería 4.4**
> Los `COPY` selectivos hacen que el `.dockerignore` parezca innecesario: en la construcción 1 no viajó nada de más. No te confíes. El día que alguien agregue un `COPY . .` (por prisa, o para copiar un archivo nuevo), la única barrera que queda es el `.dockerignore`. Las defensas que se apoyan una en otra se escriben las dos.

### 4.7 Revisar antes de construir

El hábito de la Lección 3 no se pierde porque el Dockerfile haya cambiado. `fig04_06.sh` revisa el Dockerfile nuevo con `docker build --check`, que corre las revisiones sin construir nada ([Docker, «Build checks»](https://docs.docker.com/build/checks/)):

```bash
#!/usr/bin/env bash
# fig04_06.sh — Revisar el Dockerfile de la lección antes de construir, como en
# la Lección 3. No construye nada ni crea contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
docker build --check . 2>&1 | tail -1
```

```text
$ ./fig04_06.sh
Check complete, no warnings found.
```

Esta salida es estable. El `tail -1` deja solo el veredicto; sin él verías los mismos pasos `[internal]` que en la Lección 3. El `RUN --mount` no le molesta a la revisión: es sintaxis vigente del Dockerfile, y el renglón `# syntax=docker/dockerfile:1` del principio garantiza que el constructor la entienda.

### 4.8 Lo que vas a ver en otros proyectos

- **`COPY go.mod go.sum ./` seguido de `RUN go mod download`.** Es el truco más famoso para proyectos de Go con dependencias: descargarlas en una capa que solo se rehace cuando cambia la lista. Es buena idea **cuando hay dependencias**. El `revisor` no tiene ninguna (por eso no tiene `go.sum`), así que esa capa no tendría nada que descargar. Si empaquetas un proyecto con dependencias, ese par de renglones va justo donde aquí está `COPY go.mod ./`, y la guía de Docker usa además un segundo montaje de caché, `target=/go/pkg/mod`, para los módulos descargados ([Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/)).
- **Todo en un solo `RUN` gigante con `&&`.** Tiene sentido para instalar paquetes y limpiar en la misma capa (recuerda la Observación 4.1: lo que se borra en otra capa sigue pesando). No lo tiene para mezclar pasos que cambian a ritmos distintos.
- **`DOCKER_BUILDKIT=0`.** Activa el constructor anterior a BuildKit (el *legacy builder*), que no tiene montajes de caché ni las transferencias incrementales de 4.6. BuildKit es el constructor por omisión de Docker Engine ([Docker, «BuildKit»](https://docs.docker.com/build/buildkit/)); si un tutorial te pide apagarlo, desconfía del tutorial. No lo confundas con `docker builder`, que es solo el grupo de comandos para administrar construcciones, como `docker builder prune` ([`docker builder`](https://docs.docker.com/reference/cli/docker/builder/)).
- **`docker system prune -a` o `docker builder prune -a` «para liberar espacio».** Borran la caché de **todos** los proyectos de la máquina. Ya sabes por qué no (4.4.5).

## El error que vas a ver

Esta lección tiene un error principal y un síntoma que no da error pero cuesta tiempo.

**1. El `.git` que rompe la compilación.**

```text
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Se lee de arriba abajo: Go intentó obtener el estado del control de versiones (*VCS status*), la herramienta falló con el código 128, y Go te sugiere no grabar esa información. El último renglón es de Docker: el `RUN` terminó con código 1 y la construcción se detuvo. La causa casi nunca está en tu código: es que un `.git` llegó a la imagen. Revisa en este orden: ¿el `.dockerignore` está en la raíz del contexto, junto al `Dockerfile`? ¿Dice `.git`? ¿Hay un `COPY . .` en el Dockerfile? El arreglo es que el `.git` no viaje. `-buildvcs=false` también quita el error, pero deja el `.git` viajando y entrando a la imagen: es apagar la alarma sin apagar el fuego.

**2. Todo se reconstruye aunque cambiaste poco.** No hay mensaje de error; solo hay espera. Se diagnostica con `--progress=plain`: busca el **primer** paso que dice `DONE` en lugar de `CACHED` después del `FROM`. Ese es el paso cuyo contenido cambió, y todo lo de abajo se repitió por la regla 3. Si ese primer paso es un `COPY . .`, ya sabes el arreglo (4.3). Si es un `COPY` de un archivo que no tocaste, busca qué más cambió en esa ruta: un archivo generado, unas notas, un respaldo. Lo que no debe invalidar la caché tampoco debe viajar: va al `.dockerignore`.

## El hábito de seguridad de la lección

**El contexto de construcción no lleva `.git`, `.env`, respaldos ni secretos, y la revisión del Dockerfile se corre siempre.** El hábito evita dos accidentes. El primero es el de 4.6: un `.git`, un `.env` o un respaldo que viajan a un servidor de construcción y, con un `COPY . .`, se quedan dentro de una imagen que luego se publica. El `.git`, además, puede guardar secretos que alguien borró del código pero no de la historia. El segundo es más silencioso: la caché de compilación con el `id` de otro proyecto, o un borrado amplio que se lleva la de todos. Un `id` propio y un borrado con el `id` completo mantienen cada proyecto en su carril.

Y un bono de seguridad que trae el montaje de caché: lo que el compilador deja en su caché no queda en la imagen. Menos archivos dentro es menos superficie, y menos cosas que explicar el día que alguien revise qué trae tu imagen.

## Lo que se hace mal

**`COPY . .` y luego compilar.** Cualquier cambio, aunque sea un comentario o una nota, repite la compilación completa. Copia primero lo que cambia poco y al final lo que cambia mucho.

**Confiar en que la caché «se da cuenta» de qué cambió.** La caché es una cadena: se rompe en el primer eslabón que cambia y todo lo de abajo se repite. El orden del Dockerfile es tu herramienta para que ese eslabón quede lo más abajo posible.

**Borrar la caché de compilación con `rm -rf` al final del `RUN`.** Achica la capa, pero también tira lo que acelera la siguiente construcción. El montaje de caché da las dos cosas: la capa pequeña y la caché viva.

**Usar `-buildvcs=false` para quitar el error del `.git`.** Quita el síntoma y deja el `.git` dentro de la imagen.

**Medir solo el tiempo total.** Un número sin la tabla de pasos no dice qué se rehízo. `--progress=plain` sí.

**Usar el `id` por omisión o un `id` genérico para el montaje de caché.** Proyectos distintos terminan compartiendo, y pisándose, la misma caché.

**Limpiar con `prune -a` o con un filtro amplio.** Se lleva la caché de otros proyectos de la misma máquina. Se borra con el tipo y el `id` completo.

**Quitar líneas del `.dockerignore` porque «con `COPY` selectivos ya no hace falta».** Hace falta el día que alguien vuelva a escribir `COPY . .`.

## Ejercicios

Hazlos en orden y escribe tu predicción en la [bitácora](bitacora.md) antes de correr cada uno. Al terminar, borra lo que creaste: todo lleva el prefijo `curso-docker-`, y la caché de compilación de los ejercicios se borra con el comando de 4.4.5 y su propio `id`.

### Ejercicio 1 — Predice la caché

Con el Dockerfile de la lección y una construcción previa en la caché, predice para cada cambio qué pasos dirán `CACHED` y cuáles `DONE`. Hazlo con lápiz, usando las tres reglas de 4.2.1, y después compruébalo con `fig04_05.sh`, que aplica los cuatro cambios uno tras otro:

a) Solo cambias la fecha de `internal/reporte/tabla.go` con `touch`, sin tocar su contenido.
b) Agregas un comentario al final de `cmd/revisor/main.go`.
c) Agregas un comentario al final de `go.mod`.
d) Agregas un comentario (`# ...`) al final del `Dockerfile`.

Y una pregunta más: en el caso c, ¿esperas que el `RUN go build` tarde mucho o poco? ¿Por qué?

### Ejercicio 2 — El `.dockerignore` como única barrera (proyecto)

Copia `programas/revisor/` a una carpeta tuya y ponle el `.dockerignore` de la lección y, como `Dockerfile.leccion3`, el Dockerfile de la Lección 3, el del `COPY . .`. A propósito: con `COPY . .`, el `.dockerignore` es la única barrera. Construye una vez `curso-docker-revisor:1.0.0-ej2` con `-f Dockerfile.leccion3 --progress=plain` y anota el renglón `transferring context`. Después crea en la carpeta un `README.md`, una carpeta `secretos/` con un archivo `token.txt` de mentira y un archivo `datos.json` de 5 MB (`head -c 5242880 /dev/urandom > datos.json`). Antes de reconstruir, predice cuáles de los tres viajan. Reconstruye y mira el renglón otra vez. Después agrega al `.dockerignore` lo que haga falta y reconstruye una tercera vez. El ejercicio se autocorrige: terminaste cuando el contexto transferido vuelve a ser de unos pocos kilobytes y `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src` muestra solo `cmd`, `go.mod` e `internal`. Al final, `docker rmi curso-docker-revisor:1.0.0-ej2` y borra la carpeta.

### Ejercicio 3 — Arregla el orden

Un compañero escribió este Dockerfile para el `revisor`. Funciona, pero cada cambio en el código repite todo:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
WORKDIR /src
COPY internal/ internal/
COPY cmd/ cmd/
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
COPY go.mod ./
USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

1. Antes de construir: ¿esta construcción funciona o falla? Piensa qué necesita `go build` para compilar un módulo.
2. Encuentra los problemas de orden y de caché, y escribe la versión corregida.
3. Construye tu versión dos veces, la segunda tras cambiar un comentario en `internal/reporte/tabla.go`, y comprueba con `--progress=plain` que `COPY go.mod ./` y `COPY cmd/ cmd/` dicen `CACHED`.

### Ejercicio 4 — Explícaselo a tu compañera

Tu compañera de la escena te pregunta: «Si ahora el `RUN go build` dice `DONE` cada vez que cambio código, ¿qué ganamos con el `--mount`? Sigue repitiéndose». Contéstale en cinco frases como máximo, usando las palabras *caché de capas*, *montaje de caché*, *constructor* e *imagen*.

## Soluciones

### Solución 1

La salida real de `fig04_05.sh`:

```text
$ PREFIJO=curso-docker-l04- ./fig04_05.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## a) Solo cambia la fecha de un archivo (touch), no su contenido
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## b) Un comentario nuevo en cmd/revisor/main.go
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.4s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## c) Un comentario nuevo en go.mod
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.3s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## d) Un comentario nuevo en el Dockerfile
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

a) **Todo `CACHED`.** La fecha de modificación no cuenta para la caché (regla 1); solo el contenido.
b) **Desde `COPY cmd/` para abajo.** `cmd/` cambió; `internal/` no, pero viene después, así que se repite por la regla 3 (por eso dice `DONE` aunque no tenga nada distinto); y el `RUN` también.
c) **Desde `COPY go.mod` para abajo: todo.** `go.mod` es el primer `COPY`, así que un cambio ahí invalida toda la cadena. Por eso va primero solo lo que casi nunca cambia.
d) **Todo `CACHED`.** La caché se calcula por instrucción, y un comentario no es una instrucción: ningún paso cambió. (Un cambio en una instrucción, en cambio, sí invalida ese paso y los de abajo.)

La pregunta extra: en el caso c el `RUN` se repite, pero tarda **poco** (0.3 s en esta corrida), porque el montaje de caché ya tiene compilados todos los paquetes y un comentario en `go.mod` no cambia lo que Go tiene que compilar. La caché de capas dijo «repite el paso»; la caché de Go dijo «pero no hay casi nada que hacer». Si tus tiempos salen distintos, está bien; lo que debe coincidir es la columna de `CACHED` y `DONE`.

### Solución 2

En la segunda construcción viaja **`datos.json`**, y el renglón `transferring context` lo delata: pasa de kilobytes a unos 5 MB. `README.md` no viaja (lo excluye `*.md`) ni `secretos/` (tiene su renglón). Con `COPY . .`, `datos.json` además entra a la imagen: `ls -A /src` lo muestra. El arreglo es un renglón más en el `.dockerignore`: `datos.json`, o `*.json` si el `revisor` no necesita ningún JSON para compilarse, que es el caso. Con eso, la tercera construcción vuelve a transferir unos pocos kilobytes y `/src` queda con `cmd`, `go.mod` e `internal`. Si el número no baja, revisa que el `.dockerignore` esté en la raíz del contexto, junto a los Dockerfile.

Fíjate en que con el Dockerfile de la lección, el de los `COPY` selectivos, `datos.json` no habría viajado ni sin ese renglón, porque ningún `COPY` lo pide. Es la Observación 4.4 en acción: con `COPY . .`, el `.dockerignore` es la única barrera; con `COPY` selectivos, es la segunda. Escríbelo igual.

### Solución 3

1. **Falla.** `go build` necesita el `go.mod` para saber qué módulo está compilando, y en este Dockerfile el `go.mod` llega **después** del `RUN`. Compilar sin `go.mod` da este error, medido dentro de la imagen `golang:1.27.3-trixie` con un paquete `main` mínimo en `cmd/revisor`: `go: go.mod file not found in current directory or any parent directory; see 'go help modules'`. Dentro de la construcción lo verás con el formato de un `RUN` que falla, como en 4.6.2.
2. Los problemas: `go.mod` va después del `RUN` (error) y debería ir primero (caché); `internal/` va antes que `cmd/`, al revés del orden de la lección (menos grave, pero el que cambia más debe ir abajo); y el `RUN` no tiene montaje de caché, así que cada cambio compila desde cero. La versión corregida es `fig04_01.Dockerfile`.
3. Con la versión corregida, tras el cambio en `tabla.go`, la tabla dice `CACHED` en `WORKDIR`, `COPY go.mod ./` y `COPY cmd/ cmd/`, y `DONE` en `COPY internal/ internal/` y en el `RUN`, como en 4.3.3.

### Solución 4

Una respuesta posible: «La **caché de capas** decide si un paso se repite, y como el código cambió, el `RUN go build` se repite: eso no lo evita nada. Lo que hace el **montaje de caché** es que, cuando se repite, Go encuentra ahí todo lo que compiló la vez anterior y solo recompila el paquete que tocaste. Esa caché la guarda el **constructor**, aparte, y no entra a la **imagen**. Por eso el `RUN` pasó de 10.1 a 0.8 segundos, y la capa de la compilación pesa 100 MB menos. Se repite, sí, pero casi gratis».

## Cómo sé que lo logré

Marca cada punto solo si lo comprobaste en tu equipo:

- [ ] `docker build --check .` con el Dockerfile de la lección termina con `Check complete, no warnings found.`
- [ ] `docker history curso-docker-revisor:1.1.0` muestra tres capas `COPY` separadas y un `RUN` de unos 10 MB.
- [ ] `docker image ls curso-docker-revisor` muestra la `1.1.0` más ligera que la `1.0.0` (en estas corridas, 1.32 GB contra 1.45 GB).
- [ ] Después de cambiar un comentario en `internal/`, `--progress=plain` muestra `CACHED` en `COPY go.mod ./` y en `COPY cmd/ cmd/`, y el `RUN` tarda menos de un par de segundos.
- [ ] Agregar o editar un archivo `.md` en la carpeta no invalida ningún paso.
- [ ] Con un archivo grande en la carpeta, el renglón `transferring context` sigue en kilobytes.
- [ ] Sabes leer el error `error obtaining VCS status` y lo arreglas con el `.dockerignore`, no con `-buildvcs=false`.
- [ ] Borraste tu caché de compilación con `docker buildx prune` filtrando por `type=exec.cachemount` y por el `id` completo, y `docker buildx du --filter 'description~=curso-docker-go-build'` ya no la muestra.
- [ ] Al terminar, `docker ps -a --filter name=curso-docker-` no muestra nada, y de las imágenes del `revisor` solo queda la que quieras conservar.

## Resumen

Responde sin mirar la lección:

1. ¿Qué es una capa? ¿Qué instrucciones agregan archivos y cuáles solo datos? ¿Con qué comando las ves?
2. ¿Qué mira la caché para decidir si un `COPY` se repite? ¿Y para un `RUN`? ¿Cuenta la fecha de un archivo?
3. ¿Qué pasa con los pasos de abajo cuando uno se invalida? ¿Qué consecuencia tiene eso para el orden del Dockerfile?
4. ¿Qué hace `RUN --mount=type=cache`? ¿Dónde vive esa caché y por qué no queda en la imagen?
5. ¿Para qué sirve el `id` de un montaje de caché, y por qué es peligroso un `prune` con un filtro amplio?
6. ¿Qué significan `CACHED` y `DONE` en `--progress=plain`? ¿Cuándo ves `plain` aunque no lo pidas?
7. ¿Qué archivos manda el cliente al constructor? ¿Por qué la segunda construcción transfiere menos que la primera?
8. ¿Qué causa el error `error obtaining VCS status` y cuál es el arreglo correcto?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [Docker, «Docker build cache»](https://docs.docker.com/build/cache/): una capa por instrucción y la invalidación en cadena.
- [Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/): las reglas para `COPY`, `ADD` y `RUN`, y que la fecha de modificación no cuenta.
- [Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/): el orden de las capas, el contexto pequeño, los montajes de caché y su ejemplo para Go.
- [Referencia del Dockerfile, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache): las opciones `id`, `target`, `sharing` y las demás, y el `id` por omisión.
- [Docker, «Understanding the image layers»](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/): qué es una capa y por qué se reutiliza.
- [`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/): el comando, `--format` y `--no-trunc`.
- [`docker buildx build`, opción `--progress`](https://docs.docker.com/reference/cli/docker/buildx/build/#progress): los modos `auto`, `tty`, `plain`, `quiet` y `rawjson`.
- [`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/): los filtros `until`, `id`, `description` y `type`, con el tipo `exec.cachemount`.
- [Docker, «BuildKit»](https://docs.docker.com/build/buildkit/): la transferencia incremental del contexto y el salto de los archivos que no se usan.
- [`docker builder`](https://docs.docker.com/reference/cli/docker/builder/): el grupo de comandos para administrar construcciones.
- [Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/): que el almacén guarda las imágenes comprimidas y sin comprimir.
- [Docker, «Build checks»](https://docs.docker.com/build/checks/): `docker build --check`.
- [Documentación del comando `go`](https://pkg.go.dev/cmd/go): la caché de compilación («Build and test caching») y la opción `-buildvcs`.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones de «Sobre las corridas».
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **caché de construcción** | los resultados de pasos anteriores que el constructor guarda para no repetirlos |
| **caché de capas** | la parte de la caché que decide si un paso entero se repite o sale ya hecho |
| **capa** (*layer*) | el conjunto de cambios de archivos que deja un paso del Dockerfile |
| **`CACHED`** | en `--progress=plain`, el paso salió de la caché |
| **contexto de construcción** | los archivos que la construcción puede usar; BuildKit solo transfiere los que se piden y los que cambiaron |
| **`DONE`** | en `--progress=plain`, el paso se hizo de verdad, con su tiempo |
| **invalidar** | que un paso ya no pueda salir de la caché porque algo de lo que usa cambió |
| **montaje de caché** | carpeta que el constructor guarda aparte y monta en un `RUN`; su contenido no queda en la imagen |
| **`--progress=plain`** | el formato de texto plano de una construcción, paso por paso |
| **VCS** (*version control system*) | el sistema de control de versiones, como Git |

---

**Siguiente:** [Lección 5 — Multi-stage: de gigabytes a megabytes](05-multi-stage.md)
