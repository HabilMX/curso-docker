# Lección 3 — Tu primer Dockerfile

Son las 6:40 de la tarde de un viernes y la ventana para actualizar el servidor cierra a las 7. El plan era sencillo: detener el `revisor` viejo, arrancar el nuevo, irse a casa. Tecleas `docker stop` y la terminal se queda callada. Un segundo. Tres. Siete. A los diez, por fin, regresa. Lo intentas con la siguiente copia y otra vez: exactamente diez segundos de silencio. Revisas los registros y falta el renglón que el `revisor` siempre escribe al apagarse, `apagado limpio`; el último reporte quedó a medias. Alguien del equipo encuentra el estado del contenedor y lee en voz alta: `ExitCode=137`. Nadie lo mató a propósito, y sin embargo lo mataron. El culpable no está en el código del `revisor`, que sabe apagarse bien. Está en un renglón de tres palabras al final de su Dockerfile, uno que se ve inofensivo y que se escribe así en muchos tutoriales. Esta lección te enseña a escribir ese renglón, y todos los demás, sabiendo lo que hace cada uno.

**Tiempo:** 2 × 45 min

**Qué construyes:** la primera imagen del `revisor`, `curso-docker-revisor:1.0.0`, en una sola etapa, con su `Dockerfile` y su `.dockerignore`. Corre sin privilegios, se apaga en una fracción de segundo y lleva una versión en el nombre.

**Qué aprendes:** qué es un Dockerfile y qué hace cada una de sus instrucciones básicas (`FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`); la diferencia entre la forma *exec* y la forma *shell*, medida con un cronómetro; qué es el contexto de construcción y para qué sirve `.dockerignore`; por qué el primer Dockerfile ya trae `USER`; cómo se nombra y se etiqueta una imagen con versión; y cómo revisar un Dockerfile antes de construirlo con `docker build --check`.

**De dónde vienes.** De la [Lección 2](02-contenedores-dia-a-dia.md) traes la mano para el día a día: arrancas un contenedor con `docker run`, lo miras con `ps`, `logs`, `inspect` y `exec`, publicas su puerto solo en `127.0.0.1` y lo borras sin dejar basura. Allá construiste la imagen del servicio de prueba con un solo comando, sin preguntarte qué había en su Dockerfile. De la [Lección 0](00-que-es-un-contenedor.md) traes el mapa: un contenedor es un proceso; una imagen es la plantilla de la que nace; y el código 137 significa que el núcleo mató al proceso con la señal 9. Esa última idea va a regresar aquí con otra cara. Del curso traes también el código del `revisor`, en `programas/revisor/`, tal como el curso lo entrega: un servicio HTTP escrito en Go que todavía no tiene Dockerfile. No necesitas saber Go: no vas a cambiar ni un renglón del programa.

**Qué no hace esta lección.** No hace pequeña la imagen: la que sale de aquí pesa más de un gigabyte, y está bien que así sea por ahora, porque verla grande es la mejor forma de entender después por qué conviene achicarla (el plan del curso deja eso para la [Lección 5](05-multi-stage.md)). Tampoco ordena el Dockerfile para que la reconstrucción sea rápida ni explica las capas una por una: eso es materia de la [Lección 4](04-capas-cache-contexto.md). No conecta el `revisor` con otros contenedores (por eso, en esta lección, el `revisor` se revisa a sí mismo) y no le pone salud ni secretos. Una sola etapa, una sola imagen, todo a la vista.

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4, la misma base de Linux Mint 22, el sistema de referencia del curso. Los guiones se corrieron **dentro de esa máquina virtual**, con Docker 29.2.1 y Buildx v0.31.1 (la primera línea de `docker build --check` dice `building with "default" instance`, como dirá en tu Mint). Esa misma máquina la usaban al mismo tiempo otras corridas, y estaba muy cargada, así que, para no chocar, los guiones se lanzaron con otro prefijo de nombres y otro puerto: traen las variables `PREFIJO` (por omisión `curso-docker-`) y `PUERTO` (por omisión `8080`), y se corrieron con `PREFIJO=curso-docker-l03-` y `PUERTO=18030`. En las salidas donde aparecen nombres y puerto, la lección muestra los valores por omisión, que son los que vas a ver tú: `curso-docker-revisor` en lugar de `curso-docker-l03-revisor` y `8080` en lugar de `18030` (y el ancho de las tablas, que depende del nombre más largo, se dejó como salió); ese es el único cambio, y los archivos `.salida.txt` guardan la corrida tal cual. Lo que no cambia con las variables, porque ocurre dentro del contenedor, sale tal cual: el `8080` del puerto interno. Los programas son ocho: los guiones `fig03_02`, `fig03_04`, `fig03_05`, `fig03_07` y `fig03_08` de siempre, más `fig03_09` (la carpeta «En tu carpeta» de 3.6.1, armada en una carpeta temporal y con la etiqueta `1.0.0-carpeta`, para no tocar la tuya), `fig03_12` (los dos Dockerfile con defectos de los ejercicios, `fig03_10.Dockerfile` y `fig03_11.Dockerfile`) y `fig03_13` (hasta dónde alcanza un patrón de `.dockerignore`). La ayuda `t` de los guiones recurre a `python3` cuando el `date` del sistema no da milisegundos, como el de macOS; en Mint y en la máquina virtual no hace falta. Los tiempos de esta lección (construcción, apagado) salieron con la máquina cargada, así que en tu Mint deberían ser menores o parecidos; los 10 segundos de la forma *shell* no dependen de la carga. El curso se planeó con Docker Engine 29.8.2, y la versión más reciente publicada ese día era la 29.9.2, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)); nada de esta lección cambia entre esas versiones. Lo que **sí** cambia en tu Mint, y se avisa donde aparece: los números de proceso (PID), los tiempos, y, si tu equipo es Intel o AMD, la arquitectura (`amd64` en vez de `arm64`), que aquí no se imprime pero sí decide qué variante de la imagen de Go se descarga. Los programas están en [`programas/03-primer-dockerfile/`](../programas/03-primer-dockerfile), cada uno con su salida al lado; `estado/` guarda el `Dockerfile` y el `.dockerignore` tal como quedan al terminar.

## Al terminar vas a poder

- Escribir un Dockerfile de una sola etapa para un programa ya hecho y decir, renglón por renglón, si esa instrucción actúa al **construir** la imagen o al **correr** el contenedor.
- Construir una imagen con un nombre y una etiqueta de versión, y explicar por qué el `revisor` del curso se llama `curso-docker-revisor:1.0.0` y no `revisor` ni `revisor:latest`.
- Mostrar con `docker exec ... id` que tu contenedor no corre como `root`, y explicar qué cambia `USER 10001:10001`.
- Escribir un `.dockerignore` y comprobar, mirando dentro de la imagen, que un archivo `.env` no viajó.
- Medir cuánto tarda `docker stop` con `CMD` en forma *exec* y en forma *shell*, y explicar con `docker top` por qué una tarda una fracción de segundo y la otra poco más de 10 s con código 137.
- Correr `docker build --check` antes de construir y leer el aviso `JSONArgsRecommended`.

## El porqué antes del cómo

En la Lección 2 trabajaste con una imagen que te dieron hecha. Funciona, pero tiene una trampa: si no sabes cómo se armó, no sabes qué trae ni cómo se va a portar. ¿Corre como `root`? ¿Se lleva adentro tus archivos de configuración? ¿Se apaga cuando se lo pides o espera a que la maten? Esas tres preguntas no se contestan mirando el contenedor corriendo; se contestan leyendo su **receta**.

La receta de una imagen se llama **Dockerfile**. Es un archivo de texto con instrucciones, una por renglón, que Docker lee de arriba hacia abajo para fabricar la imagen. La documentación lo define así: Docker construye imágenes leyendo las instrucciones de un Dockerfile, «un archivo de texto que contiene las instrucciones para construir el código fuente» ([Docker, «Dockerfile overview»](https://docs.docker.com/build/concepts/dockerfile/)); y su referencia lo describe como un documento de texto con todos los comandos que un usuario podría ejecutar en la línea de comandos para ensamblar una imagen ([referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/)). Lo importante para ti es que la receta es **repetible**: describe el mismo proceso en tu equipo, en el de tu compañero y en el servidor, y por eso una imagen se arregla cambiando su receta y reconstruyendo, no entrando al contenedor. (Que dos construcciones den una imagen *idéntica* exige además fijar la base por su huella, como harás en la Lección 5; con una etiqueta, la base puede cambiar debajo de ti, como verás en 3.3.1.) Lo que en la Lección 0 llamaste «una imagen no se arregla entrando al contenedor» tiene aquí su otra mitad: una imagen se arregla **cambiando su receta y reconstruyendo**.

Y cada renglón de esa receta es una decisión. La escena del principio no la causó un error de programación: la causó escribir `CMD revisor` en lugar de `CMD ["revisor"]`. Se ven casi iguales. Esta es la diferencia que vas a medir en la sección 3.7, con la misma imagen y el mismo programa:

```text
## docker stop con forma exec
tardó 562 ms

## docker stop con forma shell
tardó 10365 ms
ExitCode=137
```

Unas décimas de segundo contra diez segundos y un cadáver. Esos son los números de la corrida de esta lección. Los milisegundos cambian (esa máquina estaba muy cargada); los diez segundos y el 137, no. La lección tiene siete partes:

1. **Qué es construir** (3.1): la receta, el contexto y quién hace el trabajo.
2. **El Dockerfile del `revisor`, renglón por renglón** (3.2).
3. **El nombre y la etiqueta** (3.3): por qué `curso-docker-revisor:1.0.0`.
4. **`USER`: no correr como `root`** (3.4).
5. **El contexto y `.dockerignore`** (3.5), con un secreto de mentira que se cuela.
6. **Construir, fallar y correr** (3.6), y la **forma *exec* contra la forma *shell*** (3.7), con el cronómetro.
7. **Revisar antes de construir** (3.8) y lo viejo que vas a encontrar en tutoriales (3.9).

## Los conceptos

### 3.1 Qué es construir una imagen

#### 3.1.1 La receta, los ingredientes y la cocina

Construir una imagen tiene tres piezas, y conviene separarlas desde el principio porque cada una falla de forma distinta:

- **La receta**: el Dockerfile.
- **Los ingredientes**: los archivos que la receta puede usar. Se llaman el **contexto de construcción**, y casi siempre son el contenido de una carpeta. En el comando `docker build .`, el punto final es esa carpeta: «el contexto es esta carpeta en la que estoy».
- **La cocina**: el constructor, que en Docker se llama **BuildKit** y forma parte del daemon. Recuerda la Lección 0: el cliente `docker` no hace el trabajo; se lo pide al daemon. Al construir, el cliente le manda la receta y los ingredientes que la receta pide, y el daemon cocina.

La documentación de construcción lo dice con estas mismas piezas: el contexto es el conjunto de archivos a los que la construcción tiene acceso, y las instrucciones del Dockerfile solo pueden tomar archivos de ahí ([Docker, «Build context»](https://docs.docker.com/build/concepts/context/)). Esto tiene una consecuencia práctica que vas a usar en 3.5: **lo que no está en el contexto no puede entrar a la imagen**, y lo que está en el contexto puede entrar aunque tú no lo quieras.

#### 3.1.2 Dos momentos: construir y correr

Hay una idea que ordena todo lo demás de esta lección: un Dockerfile describe **dos momentos distintos**.

1. **Al construir** (`docker build`): Docker parte de una imagen base, copia archivos y ejecuta comandos. Lo que resulta queda guardado en la imagen. Esto pasa una vez, en tu equipo o en un servidor de construcción.
2. **Al correr** (`docker run`): Docker crea un contenedor a partir de esa imagen y arranca **un** proceso. Esto pasa cada vez que alguien corre la imagen, en cualquier equipo.

Algunas instrucciones actúan en el primer momento y otras solo dejan **anotado** qué hacer en el segundo. Si confundes los dos momentos, escribes cosas como un `RUN` que intenta arrancar el servidor (se ejecutaría al construir, se quedaría esperando y la construcción nunca terminaría) o esperas que un `EXPOSE` abra un puerto (solo lo anota). La tabla de 3.2.2 separa cada instrucción por momento.

### 3.2 El Dockerfile del `revisor`, renglón por renglón

#### 3.2.1 La receta completa

Este es el Dockerfile con el que termina la lección. Va en la raíz del proyecto del `revisor`, junto a `go.mod`, y se llama exactamente `Dockerfile`, sin extensión, que es el nombre que `docker build` busca por omisión:

```dockerfile
# syntax=docker/dockerfile:1
# fig03_01.Dockerfile — Lección 3: el primer Dockerfile del revisor: una sola etapa.
FROM golang:1.27.3-trixie

WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor

# Un usuario sin privilegios, por número: la imagen no necesita tenerlo en /etc/passwd.
USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

Doce renglones, de los cuales siete son instrucciones. Vamos uno por uno.

**`# syntax=docker/dockerfile:1`.** Parece un comentario, y para casi todo el archivo lo es, pero en el primer renglón es una **directiva**: le dice a BuildKit qué versión de la sintaxis del Dockerfile usar. La referencia lo explica así: sirve para «declarar la versión de la sintaxis del Dockerfile que se usará para la construcción», y permite usar funciones nuevas sin actualizar Docker ([referencia del Dockerfile, *syntax*](https://docs.docker.com/reference/dockerfile/#syntax)). El `1` significa «la versión 1 más reciente». Por eso, en las salidas de construcción vas a ver que Docker resuelve primero `docker.io/docker/dockerfile:1`: va por el intérprete de la receta antes de leerla. Todos los Dockerfile del curso empiezan con este renglón.

**`FROM golang:1.27.3-trixie`.** Toda imagen parte de otra (la única excepción es la imagen vacía `scratch`, que no vas a necesitar en este curso). `FROM` dice cuál es la **imagen base**: aquí, la oficial de Go en su versión 1.27.3, construida sobre Debian 13, cuyo nombre en clave es *trixie*. El `revisor` está escrito en Go y para compilarlo hace falta el compilador de Go; esta imagen lo trae, junto con todo un Debian. Docker Hub lista esa etiqueta entre las vigentes de la imagen de Go, y aclara que nombres como *bookworm* o *trixie* son los nombres en clave de las versiones de Debian sobre las que está hecha ([golang en Docker Hub](https://hub.docker.com/_/golang)).

**`WORKDIR /src`.** Fija la carpeta de trabajo dentro de la imagen: todo lo que venga después (`COPY`, `RUN`, `CMD`) ocurre ahí. Si la carpeta no existe, Docker la crea ([referencia, `WORKDIR`](https://docs.docker.com/reference/dockerfile/#workdir)). Es mejor que escribir `RUN cd /src`, que no sirve: cada `RUN` arranca de nuevo y el `cd` se pierde al terminar ese renglón.

**`COPY . .`.** Copia del contexto (el primer punto) a la carpeta de trabajo de la imagen (el segundo punto, que aquí es `/src`). Es la única puerta por la que tus archivos entran a la imagen. Copiar **todo** es lo más sencillo y lo más peligroso: entra todo lo que esté en el contexto. Por eso existe el `.dockerignore` de 3.5. (Copiar todo de golpe también hace lenta la reconstrucción; el plan del curso lo trata en la Lección 4.)

**`RUN go build -o /usr/local/bin/revisor ./cmd/revisor`.** Ejecuta un comando **al construir** y guarda el resultado en la imagen. Aquí compila el `revisor` y deja el ejecutable en `/usr/local/bin/revisor`, una carpeta que ya está en la variable `PATH` de la imagen. Por eso más abajo basta con escribir `revisor`, sin ruta.

**`USER 10001:10001`.** Desde aquí, y sobre todo al correr, el proceso usa el usuario 10001 y el grupo 10001 en lugar de `root`. Tiene sección propia, la 3.4.

**`EXPOSE 8080`.** Anota que el programa escucha en el puerto 8080. Solo lo anota: la referencia es clara en que `EXPOSE` «en realidad no publica el puerto»; para publicarlo hace falta `-p` al correr ([referencia, `EXPOSE`](https://docs.docker.com/reference/dockerfile/#expose)). Sirve como documentación para quien lea la imagen y para herramientas que la consultan. El puerto se publica, como aprendiste en la Lección 2, con `-p 127.0.0.1:8080:8080`.

**`CMD ["revisor"]`.** Anota qué proceso arrancar **al correr** el contenedor. Solo puede haber uno efectivo: si escribes varios `CMD`, gana el último ([referencia, `CMD`](https://docs.docker.com/reference/dockerfile/#cmd)). Y es un valor por omisión: si a `docker run` le pasas un comando después del nombre de la imagen, ese comando reemplaza al `CMD` ([Docker, «Running containers»](https://docs.docker.com/engine/containers/run/)). Los corchetes y las comillas no son decoración: son la forma *exec*, el tema de 3.7.

#### 3.2.2 Cada instrucción en su momento

| Instrucción | Cuándo actúa | Qué deja en la imagen |
|---|---|---|
| `FROM` | al construir | todo el contenido de la imagen base |
| `WORKDIR` | al construir, y anota la carpeta para correr | la carpeta, y el dato de dónde arrancar |
| `COPY` | al construir | los archivos copiados |
| `RUN` | al construir | lo que el comando escribió en disco |
| `USER` | anota para correr (y para los `RUN` que vengan después) | el dato del usuario |
| `EXPOSE` | solo anota | el dato del puerto; no abre nada |
| `CMD` | solo anota | el comando que arrancará cada contenedor |

Lee la tercera columna con cuidado: las tres últimas instrucciones no agregan archivos, agregan **datos** a la configuración de la imagen. Los vas a poder leer con `docker inspect` y, más adelante, en el historial de la imagen. Ten presente que el orden importa: un `USER` que va antes de un `RUN` hace que ese `RUN` se ejecute con ese usuario. Por eso aquí `USER` va después de compilar: la compilación necesita escribir en carpetas de `root`, el servidor no.

> [!NOTE]
> 🔧 **Observación de ingeniería 3.1**
> Para cada renglón de un Dockerfile, pregúntate: «¿esto pasa una vez, cuando construyo, o cada vez, cuando alguien corre?». Lo que pasa al construir puede ser lento y pesado, porque se paga una sola vez. Lo que pasa al correr tiene que ser rápido y mínimo, porque se paga en cada arranque, y en un mal día, en cada reinicio.

### 3.3 El nombre y la etiqueta

#### 3.3.1 Las partes de un nombre

Cuando construyes, le pones nombre a la imagen con `-t`. El nombre completo de una imagen tiene esta forma, según la documentación de `docker image tag`: `[ANFITRIÓN[:PUERTO]/]ESPACIO/REPOSITORIO[:ETIQUETA]` ([`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/)). En la práctica casi todo se puede omitir: `golang:1.27.3-trixie` no escribe ni el registro ni el espacio, porque Docker completa `docker.io/library/` (el espacio `library` es el de las imágenes oficiales; ya viste ese nombre completo en la Lección 2, en `naming to docker.io/library/…`). Para una imagen que solo vive en tu equipo, basta con dos partes:

- el **repositorio**, que dice qué es: `curso-docker-revisor`;
- la **etiqueta** (*tag*), después de los dos puntos, que dice cuál de sus versiones: `1.0.0`.

La misma documentación dice algo que conviene subrayar: «si no se da una etiqueta, Docker usa `latest`». Es decir, `latest` **no** significa «la más nueva». Significa «no le pusieron etiqueta». Una imagen construida hace dos años sin etiqueta se llama `latest` igual que una de hoy. En la escena del principio, si las imágenes se hubieran llamado `revisor:latest`, ni siquiera podrías saber cuál versión estaba corriendo cuando empezó el problema.

Las etiquetas, además, son **apodos que se mueven**. Mira la línea de la imagen base en Docker Hub: el mismo contenido lleva al mismo tiempo las etiquetas `1.27.3-trixie`, `1.27-trixie`, `1-trixie` y `trixie` ([golang en Docker Hub](https://hub.docker.com/_/golang)). Cuando salga Go 1.27.4, `1.27-trixie` pasará a apuntar a otra cosa y `1.27.3-trixie` se quedará donde está. Por eso el `FROM` de esta lección usa la etiqueta más específica que hay. Ni siquiera esa es una garantía absoluta, porque quien publica puede volver a subir una etiqueta: la guía de buenas prácticas advierte que «las etiquetas de imagen son mutables» y que para fijar una versión de verdad hay que usar su huella (*digest*) ([buenas prácticas](https://docs.docker.com/build/building/best-practices/)). El plan del curso deja ese paso para la Lección 5; aquí basta con no usar `latest`.

#### 3.3.2 Por qué `curso-docker-revisor` y no `revisor`

El plan del curso, en su tabla de lecciones, ya dice que aquí construyes `curso-docker-revisor:1.x.0` y no `revisor`. Vale la pena detenerse en ese prefijo, porque es una lección por sí misma: **el prefijo del curso**.

Desde la Lección 0, todo lo que el curso crea en tu equipo empieza con `curso-docker-`: los contenedores, las redes, los volúmenes y, desde ahora, las imágenes. Ese prefijo hace tres cosas por ti:

1. **Evita choques.** `revisor` es un nombre que cualquiera usaría. Si en tu equipo ya existe una imagen `revisor:1.0.0` de otro proyecto (de otro curso de esta casa, por ejemplo), tu `docker build -t revisor:1.0.0` le quita el nombre sin preguntar: la imagen vieja se queda sin etiqueta y la nueva toma su lugar. No es hipotético: en la máquina donde se corrió esta lección ya había una imagen llamada `revisor:1.0.0`, de otro proyecto, que no tiene nada que ver con este Dockerfile. Con el prefijo, las dos conviven.
2. **Permite limpiar solo lo tuyo.** Los filtros de Docker trabajan por nombre. `docker ps -a --filter name=curso-docker-` te lista solo los contenedores del curso, y `docker image ls --filter reference='curso-docker-*'` solo sus imágenes (la forma que la [referencia de `docker image ls`](https://docs.docker.com/reference/cli/docker/image/ls/) describe para los comodines). Borrar «todo lo del curso» se vuelve un comando seguro, que no toca las bases de datos ni las imágenes de otros proyectos que tengas en el mismo equipo.
3. **Dice de dónde vino.** Dentro de seis meses, cuando hagas limpieza y encuentres `curso-docker-revisor:1.0.0`, sabrás qué es sin investigar.

La regla de versiones del `revisor` en este curso es sencilla: cada vez que una lección cambia la imagen, sube la versión. Esta es la `1.0.0`: la primera que funciona completa. Cuando cambie el Dockerfile, no se reutiliza la etiqueta; se crea otra.

> [!NOTE]
> 🔧 **Observación de ingeniería 3.2**
> Un nombre de imagen es una promesa: «esto es tal cosa, en tal versión». `latest` no promete nada, y un nombre sin prefijo promete algo que otro proyecto también puede estar prometiendo. Los dos errores se pagan el día que necesitas saber qué está corriendo, que suele ser el peor día para averiguarlo.

### 3.4 `USER`: el primer Dockerfile ya no corre como `root`

#### 3.4.1 Lo que pasa si no dices nada

En la Lección 0 viste que `root` dentro de un contenedor es el usuario 0 del mismo núcleo, con catorce capacidades encendidas. Ahora la pregunta concreta: si tu Dockerfile no dice nada sobre el usuario, ¿con quién corre el `revisor`? Depende de la imagen base. `fig03_02.sh` le pregunta a la imagen de Go:

```bash
#!/usr/bin/env bash
# fig03_02.sh — Sin USER, la imagen base corre como root.
# Pregunta con qué usuario arranca la imagen de Go que usa el revisor, y compara
# con un usuario sin privilegios elegido por número.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
IMAGEN=golang:1.27.3-trixie
docker pull -q "$IMAGEN" >/dev/null

echo "== 1. Lo que la imagen base declara como usuario (vacío = root)"
docker image inspect --format 'User="{{.Config.User}}"' "$IMAGEN"

echo
echo "== 2. Quién soy dentro, sin decir nada"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" id

echo
echo "== 3. Quién soy dentro, con el usuario 10001:10001"
docker run --rm --name "${PREFIJO}quien" --user 10001:10001 "$IMAGEN" id

echo
echo "== 4. ¿Existe ese usuario en /etc/passwd de la imagen?"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" \
  sh -c 'grep -q ":10001:" /etc/passwd && echo "sí está" || echo "no está"'

echo
echo "== 5. ¿Puede ese usuario abrir un puerto bajo? (primer puerto sin privilegios)"
docker run --rm --name "${PREFIJO}quien" --user 10001:10001 "$IMAGEN" \
  cat /proc/sys/net/ipv4/ip_unprivileged_port_start

echo
echo "== 6. Lo mismo con la red del anfitrión (--network host)"
docker run --rm --name "${PREFIJO}quien" --network host --user 10001:10001 "$IMAGEN" \
  cat /proc/sys/net/ipv4/ip_unprivileged_port_start

echo
echo "== 7. Y el valor del propio anfitrión (sin contenedor)"
cat /proc/sys/net/ipv4/ip_unprivileged_port_start
```

```text
$ ./fig03_02.sh
== 1. Lo que la imagen base declara como usuario (vacío = root)
User=""

== 2. Quién soy dentro, sin decir nada
uid=0(root) gid=0(root) groups=0(root)

== 3. Quién soy dentro, con el usuario 10001:10001
uid=10001 gid=10001 groups=10001

== 4. ¿Existe ese usuario en /etc/passwd de la imagen?
no está

== 5. ¿Puede ese usuario abrir un puerto bajo? (primer puerto sin privilegios)
0

== 6. Lo mismo con la red del anfitrión (--network host)
0

== 7. Y el valor del propio anfitrión (sin contenedor)
0
```

Esta salida es estable. La primera vez, `docker pull` descarga la imagen de Go, que pesa cientos de megabytes; ten paciencia. `--user` hace al correr lo mismo que `USER` hace en el Dockerfile, y aquí sirve para probar el usuario sin construir nada.

Léela de arriba abajo. La imagen base declara un usuario vacío, y vacío quiere decir `root`: el bloque 2 lo confirma, con `uid=0(root)`. Un Dockerfile que parte de `golang` y no dice nada hereda eso, y el `revisor` atendería peticiones de la red como el usuario 0 de tu núcleo. Con el usuario 10001, el bloque 3 dice `uid=10001 gid=10001`, **sin nombre entre paréntesis**. Y el bloque 4 explica por qué: ese usuario no existe en el `/etc/passwd` de la imagen.

#### 3.4.2 Un número basta

Eso es correcto, y es a propósito. Para el núcleo, un usuario es un número; el nombre es una comodidad que vive en `/etc/passwd`. La referencia de `USER` acepta un nombre o un número, con la forma `USER <UID>[:<GID>]` ([referencia, `USER`](https://docs.docker.com/reference/dockerfile/#user)), y escribir los dos números tiene dos ventajas. La primera: no hace falta crear el usuario en la imagen. Eso le basta al `revisor`, que no pregunta por su nombre ni por su carpeta personal; un programa que sí lo haga se encontrará con que su carpeta personal es `/`, donde no puede escribir (es lo que verás en la Solución 1). Para esos casos se crea el usuario en la imagen, o se usa una base que ya lo traiga, como el `nonroot` de la Lección 5. La segunda: el grupo queda fijo; si das un usuario sin grupo y ese usuario no tiene grupo principal, la referencia avisa que el proceso corre con el grupo de `root`. Con `10001:10001` no hay sorpresa.

¿Por qué 10001? Porque está lejos de los números que usan las distribuciones para sus propios usuarios y para las personas del equipo (en Mint, tu usuario suele ser el 1000). Un número alto y propio reduce la posibilidad de que el proceso del contenedor coincida con un usuario real del anfitrión.

La guía de buenas prácticas lo pide sin rodeos: «si un servicio puede correr sin privilegios, usa `USER` para cambiar a un usuario que no sea `root`» ([buenas prácticas, `USER`](https://docs.docker.com/build/building/best-practices/#user)). El `revisor` no necesita nada de `root`: escucha en el 8080, un puerto alto, y no escribe en carpetas del sistema. (Los puertos menores que 1024 son los que, en Linux, piden `root` o una capacidad especial; el primero que no la pide está en `net.ipv4.ip_unprivileged_port_start`, que por omisión vale 1024 y es un valor **por espacio de nombres de red** ([documentación del núcleo](https://docs.kernel.org/networking/ip-sysctl.html)). Dentro de un contenedor de Docker con red propia, ese valor viene en 0: el bloque 5 de `fig03_02.sh` lo midió y dio `0`, que quiere decir que cualquier puerto se puede abrir sin privilegios. Pero eso no es una ley: con `--network host` el contenedor comparte la red del anfitrión y ve **el valor del anfitrión**. En la máquina de esta lección ese valor también es 0 (la máquina virtual lo fija así), de modo que los bloques 5, 6 y 7 dan `0` y no distinguen los casos; en un Mint recién instalado deberías ver `0` en el 5 y `1024` en el 6 y el 7. Esa diferencia no se midió aquí.) Así que desde el primer Dockerfile corre como 10001. El plan del curso lo dice así: la seguridad no es una lección, es una costumbre.

### 3.5 El contexto y `.dockerignore`

#### 3.5.1 Lo que viaja termina adentro

Ahora el ingrediente peligroso: `COPY . .`. Copia **todo** el contexto. En un proyecto real, la carpeta tiene más que código: un `.git` con la historia, un `.env` con contraseñas para probar en tu equipo, un respaldo `.tar` que dejaste ahí la semana pasada. `fig03_04.sh` construye el `revisor` con el Dockerfile de esta lección y un archivo `.env` **de mentira** en la carpeta, primero sin `.dockerignore` y luego con uno, y mira qué quedó en `/src` dentro de la imagen:

```bash
#!/usr/bin/env bash
# fig03_04.sh — Lo que viaja en el contexto acaba dentro de la imagen.
# Construye el revisor con un archivo .env de mentira en la carpeta: primero SIN
# .dockerignore y después CON el de fig03_03. Mira qué quedó en /src cada vez.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
SIN="${PREFIJO}revisor:1.0.0-sin-ignore"
CON="${PREFIJO}revisor:1.0.0-con-ignore"
trap 'docker rmi -f "$SIN" "$CON" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + el Dockerfile de la lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/fig03_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
# Un secreto DE MENTIRA, como el que cualquiera deja en la carpeta del proyecto.
echo 'REVISOR_TOKEN=curso-docker-env-de-mentira-3c1d' > .env

echo "== 1. SIN .dockerignore: lo que hay en /src dentro de la imagen"
docker build -q -t "$SIN" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$SIN" ls -A /src
echo "-- y el .env, leído desde la imagen:"
docker run --rm --name "${PREFIJO}mira" "$SIN" cat /src/.env

echo
echo "== 2. CON .dockerignore: lo que hay en /src dentro de la imagen"
cp "$AQUI/fig03_03.dockerignore" .dockerignore
docker build -q -t "$CON" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$CON" ls -A /src
```

```text
$ ./fig03_04.sh
== 1. SIN .dockerignore: lo que hay en /src dentro de la imagen
.env
Dockerfile
cmd
go.mod
internal
-- y el .env, leído desde la imagen:
REVISOR_TOKEN=curso-docker-env-de-mentira-3c1d

== 2. CON .dockerignore: lo que hay en /src dentro de la imagen
cmd
go.mod
internal
```

Esta salida es estable. El guion trabaja en una carpeta temporal (`mktemp -d`) para no ensuciar `programas/revisor/`, que es el código que el curso entrega y que no se edita, y borra sus dos imágenes al salir. `docker build -q` construye en silencio (*quiet*); `ls -A` lista también los archivos que empiezan con punto. Las dos construcciones tardan lo mismo que una normal, porque cada una compila de nuevo: en la corrida de esta lección, el guion completo tardó poco más de un minuto, con la imagen base ya descargada.

Mira el primer bloque. El `.env` entró a la imagen y se lee con un `cat`. Cualquiera que tenga la imagen —tu compañero, el servidor, un registro público si algún día la subes— tiene también ese secreto. Y no hace falta correr la imagen para sacarlo: basta con guardarla en un archivo y abrirlo. Entró también el propio `Dockerfile`, que no sirve de nada adentro. En el segundo bloque, con el `.dockerignore`, `/src` tiene solo lo que el programa necesita para compilarse: `cmd`, `go.mod` e `internal`.

#### 3.5.2 El `.dockerignore` de la lección

Este es el archivo. Se llama exactamente `.dockerignore`, con el punto, y va en la raíz del contexto, junto al `Dockerfile`:

```text
# fig03_03.dockerignore
# Lo que no entra a la imagen. (El Dockerfile y este archivo sí viajan al
# constructor porque los necesita, pero COPY no los mete en la imagen.)
.git
.env
*.tar
Dockerfile*
.dockerignore
```

Cada renglón es un patrón, parecido a los comodines del *shell*; los renglones con `#` son comentarios ([Docker, «Build context», archivos `.dockerignore`](https://docs.docker.com/build/concepts/context/#dockerignore-files)). La documentación dice dónde se busca: el cliente busca un archivo llamado `.dockerignore` «en la carpeta raíz del contexto». Cada renglón tiene su porqué:

- **`.git`**: la historia completa del proyecto. Puede pesar mucho más que el código y puede guardar secretos que alguien borró del código pero no de la historia.
- **`.env`**: el lugar donde la gente guarda contraseñas para probar en su equipo. Es justo el archivo de la figura.
- **`*.tar`**: respaldos y archivos exportados que se quedan en la carpeta sin que nadie se acuerde. Ojo con el alcance: este patrón solo alcanza a los `.tar` de la raíz del contexto; uno dentro de una subcarpeta sigue viajando. Se comprobó con `fig03_13.sh` (abajo). Para excluirlos en cualquier nivel, el patrón es `**/*.tar`.
- **`Dockerfile*` y `.dockerignore`**: la receta no tiene por qué estar dentro del plato. ¿Y entonces cómo construye Docker, si excluyes el Dockerfile? La documentación responde: esos dos archivos «se envían de todos modos al constructor, porque los necesita para construir»; lo que el patrón impide es que `COPY` los meta en la imagen. El asterisco de `Dockerfile*` alcanza también al `Dockerfile.forma-shell` de 3.7.

`fig03_13.sh` lo mide con un `.tar` en la raíz y otro en `respaldos/`, y lista los que llegaron a la imagen:

```bash
#!/usr/bin/env bash
# fig03_13.sh — Dónde alcanza un patrón de .dockerignore: «*.tar» contra «**/*.tar».
# Construye una imagen mínima con un .tar en la raíz y otro en una subcarpeta, y
# lista los .tar que llegaron adentro. Borra lo que crea.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}ctx:1.0.0-tar"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT
cd "$TRABAJO"
mkdir respaldos
touch raiz.tar respaldos/enero.tar
printf 'FROM golang:1.27.3-trixie\nCOPY . /ctx\n' > Dockerfile

muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

echo '*.tar' > .dockerignore
echo "## .dockerignore con: *.tar"
docker build -q -t "$IMAGEN" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mira $IMAGEN find /ctx -name '*.tar'"

echo
echo '**/*.tar' > .dockerignore
echo "## .dockerignore con: **/*.tar"
docker build -q -t "$IMAGEN" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mira $IMAGEN find /ctx -name '*.tar'"
```

```text
$ ./fig03_13.sh
## .dockerignore con: *.tar
$ docker run --rm --name curso-docker-mira curso-docker-ctx:1.0.0-tar find /ctx -name '*.tar'
/ctx/respaldos/enero.tar

## .dockerignore con: **/*.tar
$ docker run --rm --name curso-docker-mira curso-docker-ctx:1.0.0-tar find /ctx -name '*.tar'
```

Con `*.tar`, el de la raíz se quedó fuera y `respaldos/enero.tar` entró a la imagen; con `**/*.tar`, ninguno. Esta salida es estable.

Un detalle de lectura: un renglón que empieza con `!` hace una excepción («esto sí, aunque un patrón anterior lo excluya»), y cuando varios patrones coinciden con un archivo, gana el último. No lo necesitas hoy, pero lo vas a ver en proyectos ajenos.

> [!NOTE]
> 🔧 **Observación de ingeniería 3.3**
> `.dockerignore` es una lista de lo que **no** viaja. Eso significa que todo lo que olvides poner, viaja. Por eso el primer Dockerfile de un proyecto ya lleva su `.dockerignore`, aunque hoy la carpeta esté limpia: la carpeta no va a seguir limpia, y el día que alguien deje un `.env` ahí, el archivo ya lo estará esperando.

### 3.6 Construir, fallar y correr

#### 3.6.1 Construir

Con el `Dockerfile` y el `.dockerignore` en la carpeta del `revisor`, la construcción es un solo comando. `fig03_05.sh` arma el proyecto en una carpeta temporal, construye, provoca el primer error, corre el servicio bien, lo consulta y lo detiene:

```bash
#!/usr/bin/env bash
# fig03_05.sh — Construir el revisor, verlo fallar sin configuración, correrlo
# bien y detenerlo. CMD en forma exec. Borra lo que crea al salir.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
LIMITES="--memory 64m --cpus 0.5 --pids-limit 50"   # los tres límites de la Lección 2
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'docker rm -f ${PREFIJO}revisor >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0 >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construir y medir"
muestra "docker build -q -t ${PREFIJO}revisor:1.0.0 . >/dev/null && docker image ls ${PREFIJO}revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "El error: arrancar sin configuración"
muestra "docker run --name ${PREFIJO}revisor ${LIMITES} ${PREFIJO}revisor:1.0.0"
muestra "docker ps -a --filter name=${PREFIJO}revisor --format '{{.Names}} {{.Status}}'"
docker rm ${PREFIJO}revisor >/dev/null

titulo "Correrlo bien"
muestra "docker run -d --name ${PREFIJO}revisor -p 127.0.0.1:${PUERTO}:8080 ${LIMITES} -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0 >/dev/null"
esperar_http "http://127.0.0.1:${PUERTO}/salud"
muestra "curl -s http://127.0.0.1:${PUERTO}/salud"
muestra "curl -s 'http://127.0.0.1:${PUERTO}/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"
muestra "docker exec ${PREFIJO}revisor id"
muestra "docker top ${PREFIJO}revisor -o pid,user,args"

titulo "docker stop con forma exec"
inicio=$(t); docker stop ${PREFIJO}revisor >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker logs ${PREFIJO}revisor"
```

El guion es largo por las ayudas del principio, que vas a reconocer en los siguientes: `muestra` imprime cada comando con un `$` delante antes de ejecutarlo, para que en la salida sepas qué produjo qué, y si el comando falla, anota su código de salida en lugar de detener el guion; `t` da la hora en milisegundos para cronometrar; `esperar_http` pregunta por la salud del servicio hasta que contesta, porque un contenedor recién arrancado tarda un instante en escuchar. La primera parte de la salida:

```text
## Construir y medir
$ docker build -q -t curso-docker-revisor:1.0.0 . >/dev/null && docker image ls curso-docker-revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

**1.45 GB.** El `revisor` compilado es un solo archivo de pocos megabytes; todo lo demás es lo que trae la imagen base: un Debian completo, el compilador de Go y sus herramientas, más lo que la compilación dejó en la imagen. Nada de eso se necesita para **correr** el `revisor`, solo para **construirlo**. Anota el número en tu bitácora: es el punto de partida, y el plan del curso le dedica la Lección 5 a bajarlo. En tu equipo el número puede variar un poco según la arquitectura.

#### En tu carpeta: la imagen que se queda

Los guiones del curso trabajan en carpetas temporales y **borran lo que crean** al salir: sirven para ver y medir, no para dejarte nada. Tu proyecto, en cambio, tiene que quedarse, porque la Lección 4 parte de él. Desde la raíz del repositorio del curso, arma tu carpeta y construye la imagen que vas a conservar:

```bash
mkdir -p ~/curso-docker/revisor
cp -R programas/revisor/. ~/curso-docker/revisor/
cp programas/03-primer-dockerfile/estado/Dockerfile \
   programas/03-primer-dockerfile/estado/.dockerignore ~/curso-docker/revisor/
cd ~/curso-docker/revisor
ls -A
docker build -q -t curso-docker-revisor:1.0.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

```text
$ ls -A
.dockerignore
Dockerfile
cmd
go.mod
internal
$ docker build -q -t curso-docker-revisor:1.0.0 .
sha256:1eb7de835928…
$ docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

El `sha256:…` que imprime `docker build -q` es el identificador de la imagen en tu equipo y cambia en cada construcción; aquí se recortó. (La huella que sirve para fijar una base, la de 3.3.1, es la que publica el registro; la Lección 5 la usa.) Esta salida es la de `fig03_09.sh`, que hace estos mismos comandos en una carpeta temporal y con la etiqueta `curso-docker-revisor:1.0.0-carpeta` (y el prefijo de corrida de «Sobre las corridas»), para no tocar la tuya; aquí se muestra con la etiqueta que tú vas a usar, y está guardada tal cual en `fig03_09.salida.txt`. El orden en que `ls -A` lista los archivos puede variar con el idioma de tu sistema. El `cp -R programas/revisor/. …` copia el *contenido* de la carpeta, así que repetirlo no anida un `revisor/revisor`. Este es `fig03_09.sh`, por si quieres ver cómo se armó la corrida:

```bash
#!/usr/bin/env bash
# fig03_09.sh — «En tu carpeta»: armar la carpeta del revisor y construir la imagen
# que se queda. Aquí se hace en una carpeta temporal y con la etiqueta 1.0.0-carpeta,
# para no tocar tu ~/curso-docker ni tu curso-docker-revisor:1.0.0. Borra lo que crea.
set -euo pipefail
# Nombres por omisión: los del curso. Se pueden cambiar para no chocar con otra
# corrida en el mismo equipo (PREFIJO=... ./fig03_09.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:1.0.0-carpeta"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

# Los comandos del bloque de la lección, desde la raíz del repositorio del curso;
# la carpeta ~/curso-docker es aquí una carpeta temporal.
cd "$AQUI/../.."
mkdir -p "$TRABAJO/curso-docker/revisor"
cp -R programas/revisor/. "$TRABAJO/curso-docker/revisor/"
cp programas/03-primer-dockerfile/estado/Dockerfile \
   programas/03-primer-dockerfile/estado/.dockerignore "$TRABAJO/curso-docker/revisor/"
cd "$TRABAJO/curso-docker/revisor"

muestra "ls -A"
muestra "docker build -q -t $IMAGEN ."
muestra "docker image ls ${PREFIJO}revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

Desde ahora, cuando la lección diga «en la carpeta del `revisor`», es `~/curso-docker/revisor`, y **esta** `curso-docker-revisor:1.0.0` es la que se queda en tu equipo al terminar. Los comandos de 3.6.2 y 3.6.3 los puedes teclear tal cual ahí, con una precaución que se dice en cada uno: el nombre `curso-docker-revisor` solo puede tenerlo un contenedor a la vez.

#### 3.6.2 El primer error: arrancar sin configuración

```text
## El error: arrancar sin configuración
$ docker run --name curso-docker-revisor --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-revisor:1.0.0
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]
$ docker ps -a --filter name=curso-docker-revisor --format '{{.Names}} {{.Status}}'
curso-docker-revisor Exited (1) Less than a second ago
```

La imagen está bien; el contenedor arrancó y el `revisor` se negó a trabajar. El `revisor` se configura con variables de entorno, y la única obligatoria es `REVISOR_SERVICIOS`, la lista de servicios que debe revisar. Sin ella, imprime qué le falta, con un ejemplo, y sale con código 1. `docker ps -a` lo muestra como `Exited (1)`: el proceso terminó solo, con un error propio. Compáralo con el 137 de la Lección 0: allá alguien mató al proceso; aquí el proceso decidió irse. Saber leer esa diferencia te ahorra buscar el problema en el lugar equivocado. Fíjate también en que el contenedor quedó creado aunque terminó: el guion lo borra con `docker rm` antes de seguir, porque el nombre está ocupado. Si tecleas los comandos tú, haz lo mismo antes de pasar a 3.6.3: `docker rm curso-docker-revisor`.

#### 3.6.3 Correrlo bien

```text
## Correrlo bien
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --memory 64m --cpus 0.5 --pids-limit 50 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.0.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <tiempo>  200
$ docker exec curso-docker-revisor id
uid=10001 gid=10001 groups=10001
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
2246176             10001               revisor
```

El número de proceso cambia en cada corrida; todo lo demás es estable, salvo el tiempo de la tabla: el `sed` del comando está ahí para taparlo cuando sale en milisegundos, y en esta corrida salió así, por lo que ves `<tiempo>` (en otra corrida puede salir `0s`, y entonces no hay nada que tapar).

`-p 127.0.0.1:8080:8080` y los tres límites (`--memory 64m --cpus 0.5 --pids-limit 50`) son los hábitos de la Lección 2, puestos desde el primer contenedor del `revisor`: el puerto solo para tu equipo y un tope de memoria, CPU y procesos. Esos números son los de la Lección 2, no una medida del `revisor`; si más adelante hace falta más, se mide y se sube. `-e` pasa una variable de entorno al contenedor. Aquí el `revisor` se revisa **a sí mismo**: la lista tiene un solo servicio, `propio`, que apunta a su propia salud. Es una forma de comprobar que todo funciona sin otro contenedor, porque conectar contenedores entre sí es tema de redes y el plan del curso lo deja para la Lección 8. La tabla dice `OK` y `200`.

`/salud` responde `"version":"desarrollo"`. No es un error: la imagen se construyó sin grabarle una versión al programa, y el `revisor` está hecho para delatarlo así. Ojo con la diferencia: la **imagen** tiene la etiqueta `1.0.0`, pero el **programa** de adentro no sabe en qué versión está. Son dos cosas distintas, y unirlas es tarea de una lección posterior.

Ahora las dos últimas líneas, que son las importantes de esta sección. `docker exec ... id` dice `uid=10001`: el `USER` del Dockerfile funcionó. Y `docker top`, que lista los procesos de un contenedor vistos desde el anfitrión, muestra **un solo proceso**: `revisor`, del usuario 10001. Ese renglón solo es la forma *exec* funcionando. Guárdalo en la memoria, porque en la siguiente sección vas a ver uno con **dos** renglones. Cuando termines de probar: `docker stop curso-docker-revisor && docker rm curso-docker-revisor`, para que el nombre quede libre y `docker ps -a` limpio.

### 3.7 Forma *exec* contra forma *shell*

#### 3.7.1 Dos formas de escribir lo mismo

`CMD` (y también `RUN` y `ENTRYPOINT`, la instrucción hermana de `CMD` que fija el programa principal de la imagen y que vas a usar desde la Lección 5) se puede escribir de dos maneras ([referencia del Dockerfile, formas *shell* y *exec*](https://docs.docker.com/reference/dockerfile/#shell-and-exec-form)):

- **Forma *exec***: una lista en formato JSON, con corchetes y comillas dobles: `CMD ["revisor"]`. Docker arranca ese programa directamente, sin nada en medio.
- **Forma *shell***: un texto normal: `CMD revisor`. Docker lo envuelve en un *shell*; en Linux, en `/bin/sh -c "revisor"`. La referencia lo dice así: a diferencia de la forma *exec*, las instrucciones en forma *shell* «siempre usan un *shell*».

La forma *shell* existe por algo: con un *shell* en medio puedes usar variables (`$HOME`), tuberías (`|`) y encadenar comandos (`&&`). Por eso en los `RUN` se usa mucho y está bien usarla. El problema aparece cuando la usas para el proceso **principal** del contenedor, el que arranca `CMD`.

Para verlo, la lección trae una copia del Dockerfile en la que solo cambia el último renglón. Existe únicamente para comparar:

```dockerfile
# syntax=docker/dockerfile:1
# fig03_06.Dockerfile — Lección 3: la MISMA imagen, pero con CMD en forma shell. Existe solo para
# comparar: así NO se escribe.
FROM golang:1.27.3-trixie
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
USER 10001:10001
EXPOSE 8080
CMD revisor
```

En el proyecto se guarda como `Dockerfile.forma-shell`, y se construye con `docker build -f Dockerfile.forma-shell`: la opción `-f` le dice a Docker qué receta usar cuando no es la que se llama `Dockerfile`.

#### 3.7.2 La medición

Primero, la mitad que ya viste: el final de `fig03_05.sh`, que detiene el contenedor con forma *exec* y muestra sus registros:

```text
## docker stop con forma exec
tardó 562 ms
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 1ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Los tiempos (562 ms, y los `0s` y `1ms` de cada petición) cambian en cada corrida; la secuencia de renglones es estable, aunque el número de `GET /salud` depende de cuántas veces preguntó `esperar_http` antes de que el servicio contestara. Las dos líneas finales son las que importan: el `revisor` **recibió** la señal (`terminated` es el nombre que Go le da a `SIGTERM`), terminó lo que estaba haciendo y se despidió. Todo en 562 milisegundos en esta corrida, con la máquina muy cargada.

Ahora la otra mitad. `fig03_07.sh` construye la imagen con forma *shell*, la corre con la misma configuración, mira sus procesos y la detiene:

```bash
#!/usr/bin/env bash
# fig03_07.sh — La MISMA imagen con CMD en forma shell: quién es el PID 1,
# cuánto tarda docker stop y con qué código muere. Borra lo que crea al salir.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
LIMITES="--memory 64m --cpus 0.5 --pids-limit 50"   # los tres límites de la Lección 2
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'docker rm -f ${PREFIJO}revisor-shell >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0-shell >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "docker stop con forma shell"
docker build -q -t ${PREFIJO}revisor:1.0.0-shell -f Dockerfile.forma-shell . >/dev/null
docker run -d --name ${PREFIJO}revisor-shell ${LIMITES} -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0-shell >/dev/null
sleep 1
muestra "docker top ${PREFIJO}revisor-shell -o pid,user,args"
inicio=$(t); docker stop ${PREFIJO}revisor-shell >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${PREFIJO}revisor-shell"
muestra "docker logs ${PREFIJO}revisor-shell"
```

Las ayudas del principio son las mismas de `fig03_05.sh`. La etiqueta `1.0.0-shell` y el nombre `curso-docker-revisor-shell` son de apoyo: viven solo lo que dura el guion.

```text
## docker stop con forma shell
$ docker top curso-docker-revisor-shell -o pid,user,args
PID                 USER                COMMAND
2254874             10001               /bin/sh -c revisor
2254924             10001               revisor
tardó 10365 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor-shell
ExitCode=137
$ docker logs curso-docker-revisor-shell
revisor desarrollo escuchando en :8080 (1 servicio(s))
```

Los números de proceso cambian; el tiempo cambia en unos cientos de milisegundos, pero siempre queda **un poco arriba de 10 segundos**; `ExitCode=137` y el registro de un solo renglón son estables. Es la escena del principio, completa.

#### 3.7.3 Qué pasó: la señal que no llegó

Pon las dos salidas de `docker top` una junto a la otra. Con forma *exec* había **un** proceso, `revisor`. Con forma *shell* hay **dos**: `/bin/sh -c revisor` y, como hijo suyo, `revisor`. El *shell* arrancó primero, así que el *shell* es el proceso número 1 del contenedor (recuerda la Lección 0: dentro del contenedor, el programa principal es el 1). El `revisor` quedó como un hijo suyo.

Ahora, la cadena de `docker stop`, según su documentación: le manda al proceso principal del contenedor la señal `SIGTERM`, espera un plazo que por omisión es de **10 segundos** en Linux, y si el proceso sigue vivo, le manda `SIGKILL` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)). El «proceso principal» es el número 1. Con forma *exec*, el número 1 es el `revisor`, que está escrito para atender `SIGTERM`: lo recibe, se apaga en orden y sale. Con forma *shell*, el número 1 es `/bin/sh`.

Aquí se juntan dos hechos. El primero: el *shell* no reenvía la señal a su hijo. La explicación de la regla `JSONArgsRecommended` lo dice textual: con forma *shell*, el programa «corre como proceso hijo de un *shell*, que no pasa las señales» ([Docker, `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/)). La referencia del Dockerfile lo dice de la forma *shell* de `ENTRYPOINT` con todas sus letras: el ejecutable «no será el PID 1 del contenedor y no recibirá señales de Unix» ([referencia, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). El segundo hecho es del núcleo y es más sutil: el proceso número 1 de un espacio de nombres de procesos es especial. `docker stop` manda la señal desde fuera del contenedor, desde el espacio de nombres del anfitrión, que es el «ancestro» del contenedor. Para ese caso, el manual de Linux dice que al proceso número 1 solo le llegan las señales para las que estableció un manejador, y que `SIGKILL` y `SIGSTOP` son la excepción: esas dos «se entregan a la fuerza» cuando vienen de un espacio de nombres ancestro ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). El *shell* no instaló un manejador para `SIGTERM`, así que la señal ni siquiera lo mata a él: se pierde.

Con eso, la salida se lee sola:

1. `docker stop` manda `SIGTERM` al número 1, el *shell*. Se pierde. El `revisor`, abajo, nunca se entera.
2. Pasan 10 segundos. Ese es casi todo el tiempo que mediste: 10,365 ms son los 10,000 del plazo más lo que tardan Docker y el núcleo (con la máquina cargada).
3. `docker stop` manda `SIGKILL`, que, según el manual de señales, «no se puede atrapar, bloquear ni ignorar» ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)). Mueren el *shell* y el `revisor` de golpe.
4. Docker anota `ExitCode=137`. Ya lo sabes leer desde la Lección 0: 128 más 9, y 9 es el número de `SIGKILL`.
5. El registro tiene un solo renglón. No dice `recibí terminated` porque el `revisor` no recibió nada, y no dice `apagado limpio` porque no se apagó: lo mataron a mitad de lo que hacía. Si en ese instante estaba escribiendo un reporte, el reporte quedó a medias.

Fíjate en que el código del `revisor` es exactamente el mismo en las dos imágenes. Sabe apagarse: lo demostró en unas décimas de segundo. Lo que cambió es que, con un *shell* en medio, la señal nunca le llegó. Y no conviene averiguar cómo se porta el *shell* de cada imagen base: con la forma *exec* no hay *shell* en medio y la pregunta desaparece.

Las Lecciones 0 y 2 te dejaron este problema anotado para más adelante. Aquí viste la mitad que depende del Dockerfile: la forma *exec* pone a tu programa como proceso número 1. La Lección 7 trae la otra mitad: qué obligaciones tiene ese proceso número 1 con los procesos que crea (`--init`), cómo cambiar la señal con `STOPSIGNAL` y cómo medir el apagado junto con la salud.

> [!NOTE]
> 🔧 **Observación de ingeniería 3.4**
> Diez segundos parecen poco. Multiplícalos: una actualización que detiene veinte contenedores uno tras otro pierde más de tres minutos esperando, y en cada uno se corta lo que estaba haciendo. Y el 137 contamina tus alarmas: si cada apagado normal termina en 137, el día que un contenedor muera de verdad por falta de memoria, con el mismo 137, nadie lo va a notar.

#### 3.7.4 Cuándo sí hace falta un *shell*

A veces el arranque necesita algo que solo un *shell* da, como leer una variable. La misma página de la regla da dos salidas que siguen siendo honestas: escribir un pequeño guion de arranque y llamarlo en forma *exec*, o declarar el *shell* a propósito con la instrucción `SHELL`. En los dos casos el programa vuelve a ser hijo de un *shell* y la señal vuelve a ser tu responsabilidad, por ejemplo con `exec` al final del guion, que reemplaza al *shell* por tu programa. El `revisor` no necesita nada de eso: lee sus variables él mismo. La regla práctica de este curso queda así: **`CMD` y `ENTRYPOINT`, siempre en forma *exec***.

### 3.8 Revisar antes de construir: `docker build --check`

Lo que acabas de medir con un cronómetro, Docker lo puede detectar leyendo la receta, sin construir nada. `docker build --check` corre las **revisiones de construcción** (*build checks*): reglas que buscan errores comunes en el Dockerfile. La documentación dice que, en lugar de ejecutar los pasos de construcción, el comando «solo corre las revisiones y reporta lo que encuentra», y que existen desde la versión 1.8 de la sintaxis del Dockerfile y Buildx 0.15.0 ([Docker, «Build checks»](https://docs.docker.com/build/checks/)). Tu Docker trae una versión mucho más nueva. `fig03_08.sh` revisa los dos Dockerfile de la lección:

```bash
#!/usr/bin/env bash
# fig03_08.sh — Revisar los dos Dockerfile ANTES de construir, con
# docker build --check. No construye nada ni crea contenedores.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'rm -rf "$TRABAJO"' EXIT

titulo "Revisar el Dockerfile antes de construir"
muestra "docker build --check ."
muestra "docker build --check -f Dockerfile.forma-shell ."
```

El primero, el bueno:

```text
## Revisar el Dockerfile antes de construir
$ docker build --check .
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 372B 0.0s done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.0s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie
#4 DONE 0.2s

#5 [internal] load .dockerignore
#5 transferring context: 231B done
#5 DONE 0.0s
Check complete, no warnings found.
```

Los tiempos y el *digest* largo después de `dockerfile:1@sha256:` cambian (ese *digest* es la versión exacta del intérprete de la sintaxis que Docker usó ese día); también cambian el tamaño en bytes de `transferring dockerfile` y de `transferring context`, que dependen de los comentarios de los archivos. Lo estable es la secuencia de pasos y la última línea. Los pasos numerados son lo que BuildKit hizo: cargar la receta (`#1`), resolver el intérprete que pide el renglón `# syntax` (`#2` y `#3`), preguntar por los datos de la imagen base sin descargarla completa (`#4`) y leer el `.dockerignore` (`#5`). No hubo `COPY` ni `RUN`: nada se construyó. Y al final, `Check complete, no warnings found.`

El segundo, el de la forma *shell*:

```text
$ docker build --check -f Dockerfile.forma-shell .
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile.forma-shell
#1 transferring dockerfile: 355B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.1s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie
#4 DONE 0.1s

#5 [internal] load .dockerignore
#5 transferring context: 231B done
#5 DONE 0.0s
Check complete, 1 warning has been found!

WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
--------------------
   8 |     USER 10001:10001
   9 |     EXPOSE 8080
  10 | >>> CMD revisor
  11 |     
--------------------
[código de salida: 1]
```

Ahí está la escena del principio, encontrada antes de construir. El aviso tiene cuatro partes. El nombre de la regla, `JSONArgsRecommended`, con la dirección de su explicación. La frase: «se recomiendan argumentos JSON en `CMD` para evitar comportamientos no deseados relacionados con las señales del sistema operativo». El lugar exacto: `Dockerfile.forma-shell:10`. Y el renglón señalado con `>>>`. Además, el comando sale con **código 1**: la documentación aclara que, a diferencia de una construcción normal, con `--check` cualquier violación hace que el comando termine con un código distinto de cero. Eso es lo que lo vuelve útil en un servidor de construcción: un aviso detiene el proceso en vez de perderse en la pantalla.

Una construcción **normal** (`docker build` sin `--check`) también corre estas revisiones y muestra el mismo aviso, pero termina con éxito y construye la imagen de todos modos. Es fácil no verlo entre cientos de renglones. Por eso el hábito es correr `--check` antes, a propósito. Y si quieres que ninguna construcción pase con avisos, el Dockerfile puede declararlo en su segundo renglón, justo después de `# syntax`, con `# check=error=true`: así el aviso detiene también un `docker build` normal ([Docker, «Build checks»](https://docs.docker.com/build/checks/)).

### 3.9 Lo que vas a encontrar en tutoriales viejos

Vas a leer Dockerfiles de otros, y algunos traen cosas que este curso no usa. Conviene reconocerlas:

- **`MAINTAINER nombre`.** Declaraba al autor de la imagen. Está en desuso: la referencia indica que `LABEL` es «una versión mucho más flexible» y que se use en su lugar, por ejemplo `LABEL org.opencontainers.image.authors="..."` ([referencia, `MAINTAINER`](https://docs.docker.com/reference/dockerfile/#maintainer-deprecated)).
- **`ADD` para copiar archivos locales.** `ADD` hace más que `COPY`: también descarga de internet y descomprime. Esa magia sorprende. La guía de buenas prácticas usa `COPY` para copiar y reserva `ADD` para cuando de verdad necesitas traer algo remoto ([buenas prácticas, `ADD` o `COPY`](https://docs.docker.com/build/building/best-practices/#add-or-copy)). En este curso no hace falta `ADD`.
- **`FROM algo:latest` o `FROM algo` sin etiqueta.** Ya sabes por qué no (3.3).
- **`CMD comando` y `ENTRYPOINT comando` en forma *shell*.** Ya sabes medir por qué no (3.7).
- **Instalar `sudo` en la imagen.** La guía lo desaconseja por su comportamiento impredecible con las terminales y con el reenvío de señales. Si algo necesita `root` al construir, va antes del `USER`; al correr, no debería necesitarlo.

## El error que vas a ver

Esta lección tiene tres errores, de menor a mayor gravedad. Los tres los provocaste ya.

**1. El aviso de `docker build --check`.**

```text
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
```

Se lee así: hay una regla que no se cumple (`JSONArgsRecommended`); su explicación está en la dirección; y el renglón 10 de `Dockerfile.forma-shell` es el culpable. Se arregla cambiando `CMD revisor` por `CMD ["revisor"]`. Si de verdad necesitas un *shell* al arrancar, mira 3.7.4. Lo que no se hace es ignorar el aviso porque «la imagen se construyó bien»: se construye bien y se apaga mal.

**2. El contenedor que sale con 1 al arrancar.**

```text
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
curso-docker-revisor Exited (1) Less than a second ago
```

Se lee así: el contenedor arrancó, el programa leyó su configuración, no encontró algo obligatorio y salió por su cuenta con 1. No es un problema de la imagen ni de Docker. La primera pregunta ante un `Exited (1)` recién arrancado siempre es `docker logs <contenedor>`: ahí casi siempre está la causa, escrita por el propio programa. Se arregla pasando la variable con `-e`.

**3. El `docker stop` de 10 segundos y el código 137.**

```text
tardó 10365 ms
ExitCode=137
```

Se lee así: el proceso principal no atendió `SIGTERM`, se acabó el plazo y Docker lo mató con `SIGKILL` (137 = 128 + 9). Antes de culpar al programa, mira `docker top <contenedor>`: si el primer renglón es `/bin/sh -c ...`, la señal se quedó en el *shell*. Se arregla con `CMD` en forma *exec*. Hay otras causas posibles de un 137 —la falta de memoria de la Lección 0 es la otra grande, y se distingue porque `docker inspect` dice `OOMKilled=true`—, pero cuando el tiempo de `docker stop` es justo el plazo, la sospecha principal es esta. Lo que **no** se hace es subir el plazo de `docker stop` para que «alcance»: un plazo más largo solo alarga la espera, porque la señal sigue sin llegar.

## El hábito de seguridad de la lección

**El primer Dockerfile ya trae `USER`, `.dockerignore` y una etiqueta con versión.** Los tres son baratos el día uno y caros de agregar después, cuando ya hay contenedores corriendo y gente que depende de ellos.

- **`USER 10001:10001`** evita que un error en el `revisor` —o en cualquier biblioteca que use— le dé a quien lo explote el usuario 0 de tu núcleo. Lo comprobaste con `docker exec ... id`.
- **`.dockerignore`** evita el accidente de 3.5: un `.env`, una llave o la historia de `.git` metidos en una imagen que luego viaja a otros equipos. Lo comprobaste mirando `/src` dentro de la imagen.
- **La etiqueta con versión y el prefijo** evitan correr «lo que sea que se llame así»: sabes qué imagen corre y la borras sin tocar lo de otros.

## Lo que se hace mal

**Escribir `CMD` en forma *shell* «porque es más fácil de leer».** Se lee más fácil y se apaga peor: 10 segundos de espera y un 137 en cada `docker stop`. La forma *exec* son dos corchetes y unas comillas.

**Usar `latest`, o no poner etiqueta, que es lo mismo.** `latest` no quiere decir «la más nueva»; quiere decir «sin etiqueta». El día del problema no vas a saber qué versión corría.

**Nombrar la imagen con un nombre genérico como `revisor` o `app`.** Choca con imágenes de otros proyectos en el mismo equipo y les quita el nombre sin avisar.

**Dejar el Dockerfile sin `USER` porque «es solo para probar».** Lo que es para probar suele terminar en producción con el mismo Dockerfile. Cuesta un renglón.

**`COPY . .` sin `.dockerignore`.** Todo lo de la carpeta viaja y queda en la imagen, incluidos los archivos que nadie recuerda haber dejado ahí.

**Usar `RUN` para arrancar el servicio.** `RUN` se ejecuta al construir: la construcción se quedaría esperando al servidor para siempre. Lo que se ejecuta al correr va en `CMD`.

**Creer que `EXPOSE` publica el puerto.** Solo lo anota. Sin `-p` al correr, nadie de fuera llega. Y con `-p`, el puerto se publica en `127.0.0.1`, como aprendiste en la Lección 2.

**Ignorar los avisos de la construcción.** Una construcción normal muestra el aviso de `JSONArgsRecommended` y termina con éxito. Correr `docker build --check` antes convierte el aviso en un error que no se puede pasar por alto.

## Ejercicios

Hazlos en orden. Antes de correr cada uno, escribe en tu [bitácora](bitacora.md) lo que crees que va a pasar; compararlo después es la mitad del aprendizaje. Al terminar, borra lo que creaste: todo lleva el prefijo `curso-docker-`.

### Ejercicio 1 — ¿Al construir o al correr?

Sin mirar la tabla de 3.2.2, clasifica cada renglón: ¿actúa **al construir**, solo **anota algo para correr**, o las dos cosas?

1. `FROM golang:1.27.3-trixie`
2. `COPY . .`
3. `RUN go build -o /usr/local/bin/revisor ./cmd/revisor`
4. `USER 10001:10001`
5. `EXPOSE 8080`
6. `CMD ["revisor"]`

Y una pregunta de trampa: si cambias el orden y pones `USER 10001:10001` **antes** del `RUN go build`, ¿con qué usuario se ejecuta la compilación?

### Ejercicio 2 — Tu propio `.dockerignore` (proyecto)

Trabaja en tu carpeta `~/curso-docker/revisor` (la del bloque «En tu carpeta» de 3.6.1). Aparta un momento el `.dockerignore` de la lección con `mv .dockerignore ../dockerignore-leccion3` y crea ahí tres cosas: un archivo `.env` con un secreto de mentira, un archivo `notas.md` y una carpeta `secretos/` con un archivo adentro. Construye `curso-docker-revisor:1.0.0-ej2` y lista `/src` dentro de la imagen con `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src`. Después escribe un `.dockerignore` nuevo que deje fuera las tres cosas, además de todo lo que excluía el de la lección (lo tienes en `../dockerignore-leccion3`), reconstruye con la misma etiqueta y vuelve a listar. El ejercicio se autocorrige: terminaste cuando `/src` muestra exactamente `cmd`, `go.mod` e `internal`. Al final, `docker rmi curso-docker-revisor:1.0.0-ej2`. Tu `.dockerignore` ampliado se puede quedar: excluye todo lo que excluía el de la lección y algo más, así que tu `curso-docker-revisor:1.0.0` no cambia.

### Ejercicio 3 — El cronómetro en tu equipo

Corre `fig03_05.sh` y `fig03_07.sh` en tu Mint (después de la Lección 1 y con la imagen de Go descargada). Anota en tu bitácora, en la línea que la Lección 3 trae para eso, los dos tiempos de `docker stop`.

Un aviso antes de correrlos: `fig03_05.sh` construye y, al salir, borra una imagen llamada `curso-docker-revisor:1.0.0`, el mismo nombre que la tuya de 3.6.1. Para que no se la lleve, córrelo con otro prefijo, que es para lo que existe la variable: `PREFIJO=curso-docker-ej3- ./fig03_05.sh`. En tu salida vas a leer `curso-docker-ej3-revisor` donde la lección dice `curso-docker-revisor`; sigue empezando con `curso-docker-`, así que la limpieza del curso lo alcanza. Si ya lo corriste sin el prefijo y tu imagen desapareció, vuelve a `~/curso-docker/revisor` y reconstrúyela con `docker build -q -t curso-docker-revisor:1.0.0 .`: tarda segundos, porque todo sale de la caché.

Antes de correrlos, predice:

1. ¿Cuál de los dos tiempos va a cambiar más de una corrida a otra, y cuál va a quedar casi igual?
2. ¿Qué número va a salir en `ExitCode` en la forma *shell*? ¿Y qué número esperarías en la forma *exec*, sabiendo que el `revisor` está escrito para terminar con 0 después de un apagado limpio? Compruébalo agregando, después del `docker stop` de `fig03_05.sh`, un `docker inspect --format 'ExitCode={{.State.ExitCode}}' "${PREFIJO}revisor"` (con el prefijo de arriba, el contenedor se llama `curso-docker-ej3-revisor`).

### Ejercicio 4 — Arregla el Dockerfile ajeno

Un compañero te pasa este Dockerfile para el `revisor`. Encuentra **seis** problemas, cinco en el archivo y uno que falta junto a él; di qué accidente puede causar cada uno y escribe la versión corregida. Después comprueba la tuya con `docker build --check`: tiene que decir `Check complete, no warnings found.`

```dockerfile
# ASÍ NO — seis problemas a propósito (Ejercicio 4 de la Lección 3).
FROM golang
MAINTAINER alguien@ejemplo.invalid
COPY . /src
RUN cd /src && go build -o /usr/local/bin/revisor ./cmd/revisor
EXPOSE 8080
CMD revisor
```

Pista: `docker build --check` encuentra dos de los seis; los otros cuatro los tienes que encontrar tú.

## Soluciones

### Solución 1

1. **Al construir.** Trae todo el contenido de la imagen base.
2. **Al construir.** Copia los archivos del contexto a la imagen.
3. **Al construir.** Compila y deja el ejecutable en la imagen. No se vuelve a ejecutar al correr.
4. **Las dos cosas.** Anota el usuario con el que correrá el contenedor, y además afecta a los `RUN` que vengan después en el Dockerfile.
5. **Solo anota.** No publica nada (3.2).
6. **Solo anota** el proceso que arrancará cada contenedor.

La pregunta de trampa: con el usuario **10001**, porque `USER` cambia el usuario de todo lo que viene después, también al construir. Y la compilación falla. Go intenta crear su caché en la carpeta personal del usuario y, como el 10001 no existe en `/etc/passwd`, esa carpeta es `/`, donde no puede escribir. Medido en la máquina de esta lección con `fig03_12.sh`, que construye con `docker build --progress=plain` el `fig03_11.Dockerfile` (el de la lección, con `USER` antes del `RUN`); el `#10` y el `0.204` son el número de paso y los segundos, y cambian, y entre los dos renglones de abajo el resto de la salida está en `fig03_12.salida.txt`:

```text
#10 0.204 failed to initialize build cache at /.cache/go-build: mkdir /.cache: permission denied
ERROR: failed to build: failed to solve: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Aunque la caché funcionara, tampoco podría escribir en `/usr/local/bin`. Por eso `USER` va después de compilar.

Este es el Dockerfile con el `USER` movido (`fig03_11.Dockerfile`), que existe solo para ver el fallo:

```dockerfile
# syntax=docker/dockerfile:1
# fig03_11.Dockerfile — Lección 3: el Dockerfile de la lección con USER ANTES del RUN.
# Existe solo para ver fallar la compilación (Solución 1): así NO se escribe.
FROM golang:1.27.3-trixie

WORKDIR /src
COPY . .
USER 10001:10001
RUN go build -o /usr/local/bin/revisor ./cmd/revisor

EXPOSE 8080
CMD ["revisor"]
```

Y este es `fig03_12.sh`, que lo construye y, de paso, revisa con `docker build --check` el Dockerfile ajeno del Ejercicio 4 (`fig03_10.Dockerfile`, el mismo de arriba):

```bash
#!/usr/bin/env bash
# fig03_12.sh — Los dos Dockerfile con defectos de la lección: el del Ejercicio 4,
# revisado con docker build --check, y el de la Solución 1 (USER antes del RUN),
# que falla al compilar. No deja imágenes ni contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los dos Dockerfile con defectos.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_10.Dockerfile" "$TRABAJO/revisor/Dockerfile.ajeno"
cp "$AQUI/fig03_11.Dockerfile" "$TRABAJO/revisor/Dockerfile.user-antes"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "Ejercicio 4: el Dockerfile ajeno, revisado antes de construir"
muestra "docker build --check -f Dockerfile.ajeno ."

titulo "Solución 1: USER antes del RUN, la compilación falla"
muestra "docker build --progress=plain -f Dockerfile.user-antes ."
```

### Solución 2

Un `.dockerignore` que cumple:

```text
.git
.env
*.tar
*.md
secretos/
Dockerfile*
.dockerignore
```

Con él, `ls -A /src` dentro de la imagen muestra solo `cmd`, `go.mod` e `internal`, igual que el segundo bloque de `fig03_04.sh`. Si en tu lista aparece todavía `notas.md` o `secretos`, revisa que el patrón esté bien escrito y que el archivo `.dockerignore` esté en la raíz del contexto, junto al `Dockerfile`, y no en una subcarpeta. Si aparece `.dockerignore` o `Dockerfile`, te faltaron los dos últimos renglones. Una variante también válida es `*.md` cambiado por `notas.md`: excluye solo ese archivo. La de arriba es más previsora, porque el `revisor` no necesita ningún `.md` para compilarse.

### Solución 3

1. El tiempo de la forma *exec* cambia más de una corrida a otra (decenas o cientos de milisegundos, según lo ocupado que esté tu equipo); el de la forma *shell* queda casi igual, siempre un poco arriba de 10,000 ms, porque casi todo es el plazo fijo de `docker stop`.
2. En la forma *shell*, `ExitCode=137`, como en `fig03_07.sh`. En la forma *exec*, `ExitCode=0`: el `revisor` recibe `SIGTERM`, escribe `apagado limpio` y su código termina con 0. Si tu corrida da otro número, mira `docker logs`: si no aparece `apagado limpio`, la señal no llegó, y la primera sospecha es que tu Dockerfile tiene la forma *shell*.

### Solución 4

Los cinco problemas del archivo:

1. **`FROM golang` sin etiqueta**, que es `golang:latest`: cada construcción puede usar otra versión de Go. Corrección: `FROM golang:1.27.3-trixie`.
2. **`MAINTAINER`**, en desuso. Corrección: quitarlo, o usar `LABEL org.opencontainers.image.authors="..."`.
3. **`RUN cd /src && ...` en vez de `WORKDIR`.** Funciona en ese renglón, pero el `cd` se pierde después, y el contenedor arranca en `/`. Corrección: `WORKDIR /src` y `COPY . .`.
4. **Sin `USER`**: el `revisor` correría como `root`. Corrección: `USER 10001:10001` después de compilar.
5. **`CMD revisor` en forma *shell***: 10 segundos y 137 en cada `docker stop`. Corrección: `CMD ["revisor"]`. Es justo lo que señala `docker build --check`.

Y el sexto, el que no está en el archivo: **falta el `.dockerignore`**, y con `COPY . /src` todo el contexto entra a la imagen. La versión corregida es el `fig03_01.Dockerfile` de esta lección más el `fig03_03.dockerignore`.

`docker build --check` sobre el Dockerfile original (`fig03_10.Dockerfile`, que `fig03_12.sh` revisa) encuentra dos de los seis. Medido en la máquina de esta lección (se muestran solo los renglones de los avisos; la salida completa está en `fig03_12.salida.txt`):

```text
Check complete, 2 warnings have been found!
WARNING: MaintainerDeprecated - https://docs.docker.com/go/dockerfile/rule/maintainer-deprecated/
Maintainer instruction is deprecated in favor of using label
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
```

`MaintainerDeprecated` es el problema 2: la regla dice que `MAINTAINER` está en desuso y que se use una etiqueta (`LABEL`) en su lugar ([Docker, `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/)). `JSONArgsRecommended` es el problema 5. Los otros cuatro (`latest`, el `cd`, la falta de `USER` y la del `.dockerignore`) no los detecta ninguna regla de las que corrieron aquí: por eso `--check` ayuda pero no sustituye a leer la receta. Tu versión tiene que decir `Check complete, no warnings found.`

## Cómo sé que lo logré

Marca cada punto solo si lo comprobaste en tu equipo:

- [ ] `docker build --check .` en `~/curso-docker/revisor` termina con `Check complete, no warnings found.` y código 0.
- [ ] `docker image ls 'curso-docker-revisor'` muestra `curso-docker-revisor` con la etiqueta `1.0.0`, y anotaste su tamaño en la bitácora (en la corrida de esta lección, 1.45 GB).
- [ ] Sin `REVISOR_SERVICIOS`, el contenedor queda `Exited (1)` y `docker logs` dice qué falta.
- [ ] Con la variable, `curl -s http://127.0.0.1:8080/salud` responde `{"estado":"vivo","version":"desarrollo"}`.
- [ ] `docker exec curso-docker-revisor id` dice `uid=10001 gid=10001 groups=10001`.
- [ ] `docker top curso-docker-revisor -o pid,user,args` muestra **un solo** proceso, `revisor`.
- [ ] `docker stop curso-docker-revisor` tarda menos de un segundo y `docker logs` termina con `revisor: apagado limpio`.
- [ ] Con la imagen de forma *shell* mediste los 10 segundos y el 137, y puedes explicar con `docker top` por qué.
- [ ] Dentro de la imagen, `ls -A /src` no muestra `.env`, `.git` ni `Dockerfile`.
- [ ] Al terminar, `docker ps -a --filter name=curso-docker-revisor` no muestra nada, y `docker image ls 'curso-docker-revisor'` muestra solo `curso-docker-revisor:1.0.0`, la que construiste en tu carpeta y que usa la Lección 4.

## Resumen

Responde sin mirar la lección:

1. ¿Qué es un Dockerfile, qué es el contexto y quién hace el trabajo de construir?
2. ¿Qué instrucciones actúan al construir y cuáles solo anotan algo para correr?
3. ¿Qué significa de verdad la etiqueta `latest`? ¿Por qué la imagen del curso se llama `curso-docker-revisor:1.0.0` y no `revisor:1.0.0`?
4. ¿Con qué usuario corre una imagen si nadie escribió `USER`? ¿Por qué basta un número?
5. ¿Qué hace `.dockerignore` y qué pasa con un `.env` si no lo tienes?
6. ¿Qué diferencia hay entre `CMD ["revisor"]` y `CMD revisor`? ¿Qué muestra `docker top` en cada caso?
7. ¿Por qué con la forma *shell* `docker stop` tarda 10 segundos y deja 137? ¿Qué es el 137?
8. ¿Qué hace `docker build --check` y con qué código sale si encuentra algo?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [Docker, «Dockerfile overview»](https://docs.docker.com/build/concepts/dockerfile/): qué es un Dockerfile.
- [Referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/): las instrucciones `FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`, `ENTRYPOINT` y `MAINTAINER`; las formas *shell* y *exec*; la directiva `syntax`.
- [Docker, «Build context»](https://docs.docker.com/build/concepts/context/): el contexto de construcción y los archivos `.dockerignore`.
- [Docker, «Build checks»](https://docs.docker.com/build/checks/): `docker build --check`, su código de salida y las versiones mínimas.
- [Docker, regla `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/): el aviso sobre `MAINTAINER` del ejercicio 4.
- [Docker, regla `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/): por qué la forma *shell* no pasa las señales, y las dos alternativas cuando hace falta un *shell*.
- [Docker, buenas prácticas para construir imágenes](https://docs.docker.com/build/building/best-practices/): `USER`, `sudo`, `ADD` contra `COPY`, etiquetas mutables y `.dockerignore`.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, el plazo de 10 segundos y `SIGKILL`.
- [`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/): las partes del nombre de una imagen y la etiqueta `latest` por omisión.
- [Docker, «Running containers»](https://docs.docker.com/engine/containers/run/): reemplazar el `CMD` desde `docker run`.
- [golang en Docker Hub](https://hub.docker.com/_/golang): la etiqueta `1.27.3-trixie` y sus apodos, y el significado de *trixie*.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones de «Sobre las corridas».
- [Linux kernel, «IP Sysctl»](https://docs.kernel.org/networking/ip-sysctl.html): `ip_unprivileged_port_start`, por espacio de nombres y con valor 1024 por omisión.
- [`docker image ls`](https://docs.docker.com/reference/cli/docker/image/ls/): el filtro `reference` con comodines.
- [pid_namespaces(7), manual de Linux](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html): las señales que puede recibir el proceso número 1 de un espacio de nombres.
- [signal(7), manual de Linux](https://man7.org/linux/man-pages/man7/signal.7.html): los números de `SIGTERM` (15) y `SIGKILL` (9), y que `SIGKILL` no se puede atrapar.
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **BuildKit** | el constructor de imágenes que usa Docker; forma parte del daemon |
| **contexto de construcción** | los archivos que la construcción puede usar; casi siempre, una carpeta |
| **Dockerfile** | la receta de texto con la que se construye una imagen |
| **`.dockerignore`** | la lista de lo que no viaja en el contexto ni puede entrar a la imagen |
| **`ENTRYPOINT`** | instrucción que fija el programa principal del contenedor; `CMD` le da argumentos por omisión; la usas desde la Lección 5 |
| **etiqueta** (*tag*) | la parte del nombre de una imagen después de los dos puntos; dice qué versión es |
| **forma *exec*** | instrucción escrita como lista JSON: `CMD ["revisor"]`; arranca el programa sin *shell* |
| **forma *shell*** | instrucción escrita como texto: `CMD revisor`; la envuelve `/bin/sh -c` |
| **imagen base** | la imagen de la que parte otra, la del `FROM` |
| **`latest`** | la etiqueta que Docker pone cuando no se da ninguna; no significa «la más nueva» |
| **PID 1** | el primer proceso de un contenedor; el que recibe la señal de `docker stop` |
| **revisión de construcción** (*build check*) | regla que busca errores comunes en un Dockerfile sin construirlo |
| **`SIGTERM`** | la señal 15: «termina, por favor»; la que manda primero `docker stop` |
| **`SIGKILL`** | la señal 9: muerte inmediata; no se puede atrapar; deja el código 137 |

---

**Siguiente:** [Lección 4 — Capas, caché y contexto](04-capas-cache-contexto.md)
