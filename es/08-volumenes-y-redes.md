# Lección 8 — Volúmenes y redes

Es lunes, 9:05 de la mañana. A las 10:00 hay una revisión con el área de operaciones y te pidieron llevar el último reporte del `revisor`: qué servicios fallaron durante el fin de semana. El viernes en la noche alguien actualizó el contenedor como se hace siempre: `docker rm -f`, `docker run` con la imagen nueva, y a casa. Abres la terminal, buscas el reporte y no está. No está en el contenedor nuevo, que acaba de nacer, y el viejo ya no existe. Mientras lo asimilas, notas otra cosa: el contenedor nuevo dice `FALLA` para el servicio de prueba, con un mensaje que no habías visto: `lookup curso-docker-prueba ... no such host`. El servicio de prueba está corriendo, `docker ps` lo muestra, `curl` desde tu equipo le llega. Pero el `revisor` jura que no existe. Son las 9:12. Tienes dos problemas que parecen distintos y son la misma pregunta: **¿dónde vive lo que un contenedor necesita conservar, y por dónde encuentra a los demás?** Esta lección existe para que puedas contestarla antes de las diez: el reporte se guarda en un lugar que sobrevive al contenedor, con el dueño correcto, y los contenedores se encuentran por nombre en una red que tú defines, con la parte que no necesita internet encerrada en una red sin salida.

**Tiempo:** 2 × 45 min

**Qué construyes:** el reporte que sobrevive y dos contenedores que se hablan. La imagen `curso-docker-revisor:1.5.0` trae una carpeta `/datos` que pertenece al usuario sin privilegios `65532` y guarda ahí su reporte por omisión. Un volumen con nombre, `curso-docker-reportes`, se monta en esa carpeta y conserva el reporte aunque borres el contenedor. El servicio de prueba vive **solo** en una red interna, `curso-docker-interna`, sin salida a internet; el `revisor` vive en una red definida por ti, `curso-docker-red`, por donde se publica su puerto, y se conecta además a la interna para revisar al servicio de prueba por su nombre.

**Qué aprendes:** dónde escribe un contenedor y por qué eso se pierde; los tres tipos de montaje (volúmenes con nombre, *bind mounts* y `tmpfs`) y cuándo usar cada uno; `-v` contra `--mount`; quién es el dueño de los archivos cuando el proceso no es `root`, y cómo arreglarlo desde la imagen y no con `root`; qué pasa con el contenido de una carpeta cuando montas algo encima (a veces se copia, a veces se tapa); la red por omisión y por qué ahí no hay nombres; las redes definidas por el usuario y su DNS interno; y las redes internas, sin salida.

**De dónde vienes.** De la [Lección 7](07-salud-y-ciclo-de-vida.md) traes la imagen `curso-docker-revisor:1.4.0`, con su `HEALTHCHECK` y su `STOPSIGNAL`, y la forma de correrla endurecida: sistema de archivos de solo lectura, sin capacidades, sin escalada de privilegios, con `--init` y con límites. También traes una promesa: en la Lección 7 el reporte se guardaba en un `tmpfs`, que muere con el contenedor, y quedó pendiente darle un lugar que dure. De la [Lección 6](06-configuracion-y-secretos.md) traes el montaje de un archivo suelto (el token en `/run/secrets/`), usado sin explicarlo a fondo, y el error de permisos con el usuario `65532`: hoy ese mismo error vuelve, en una carpeta entera. De la [Lección 2](02-contenedores-dia-a-dia.md) traes la imagen `curso-docker-prueba:1.0.0` y la costumbre de publicar puertos solo en `127.0.0.1`. Y de la [Lección 3](03-primer-dockerfile.md), una frase que hoy cobra sentido: el `revisor` se revisaba a sí mismo «porque todavía no hay red entre contenedores».

**Qué no hace esta lección.** No usa Compose: todo se hace con `docker volume`, `docker network` y `docker run`, para que veas cada pieza; la [Lección 9](09-compose.md) escribe lo mismo en un `compose.yaml`. No enseña controladores de volúmenes remotos (almacenamiento en red, en la nube) ni redes que cruzan varias máquinas (*overlay*): este curso trabaja en un solo equipo, y lo que aprendes aquí (el dueño de los archivos, el DNS por nombre, la red sin salida) es lo que esas otras herramientas también necesitan. No usa la red `host` más que para decir por qué no se usa. Y no respalda ni restaura volúmenes con herramientas especiales: el reporte se lee con un contenedor ayudante, que es la forma de mirar dentro de un volumen que sirve en cualquier equipo.

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4, la misma base de Linux Mint 22, el sistema de referencia del curso, con núcleo 6.8 y procesador `arm64`. Los guiones se corrieron **dentro** de esa máquina virtual, con Docker 29.2.1 (cliente y daemon) y Buildx v0.31.1, y con su carpeta de trabajo en el disco propio de Linux. Eso importa mucho en esta lección, que trata de dueños y permisos: las carpetas compartidas entre la Mac y la máquina virtual mienten con ellos, y ningún ejemplo de dueños se midió en una de esas carpetas. En tu Mint no existe ese problema. Dos diferencias que vas a ver con tus ojos: en la máquina virtual el usuario que corrió los guiones es el `501`, con grupo `1000`, así que donde la salida dice `501:1000` tu Mint dirá casi seguro `1000:1000`, el primer usuario que se crea al instalar; y las fechas de los `ls -l` están en la hora de la máquina virtual, que es la del meridiano de Greenwich. Para no chocar con otras corridas que usaban la misma máquina, los guiones se lanzaron con otro prefijo de nombres y otro puerto (las variables `PREFIJO` y `PUERTO` que traen). Como en esta lección los nombres de redes, volúmenes y contenedores **sí** aparecen en las salidas (el DNS los usa), los guiones que muestran nombres traen una función `nombres` que, a la vista, vuelve a escribir ese prefijo como `curso-docker-`; con el prefijo por omisión no cambia nada, así que lo que ves es lo que vas a ver tú. Con sus valores por omisión, los guiones usan nombres de apoyo propios que llevan `fig08` (la imagen `curso-docker-revisor:fig08`, y `:fig08-l7`, la 1.4.0 que construye `fig08_02.sh`; el contenedor `curso-docker-revisor-fig08`, el volumen `curso-docker-reportes-fig08`, las redes `curso-docker-red-fig08` y `curso-docker-interna-fig08`): así nunca tocan tu imagen `curso-docker-revisor:1.5.0`, tu contenedor `curso-docker-revisor`, tu volumen `curso-docker-reportes` ni tus redes, y al salir borran solo lo que crearon. Por la misma razón publican su puerto, por omisión, en `127.0.0.1:8081`, no en el `8080` de tu `revisor`: así los puedes correr con tu estado final arriba (si el `8081` lo tienes ocupado, pásales otro, por ejemplo `PUERTO=8082 ./fig08_03.sh`; el puerto no aparece en las salidas). Usan, sin modificarlas, dos imágenes que ya tienes: `curso-docker-prueba:1.0.0`, de la Lección 2, y `alpine:3.24.2`, un contenedor ayudante con *shell* para mirar volúmenes y redes, porque las dos imágenes del curso no tienen *shell*. El curso se planeó con Docker Engine 29.8.2, y la más reciente publicada ese día era la 29.9.2, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)); nada de esta lección cambia entre esas versiones. Lo que **sí** cambia de una corrida a otra, y se avisa donde aparece: los tiempos de la tabla del `revisor` (tapados con `<t>`), el número del archivo temporal del reporte (tapado con `<n>`), las direcciones IP de los contenedores y la del DNS de tu equipo (tapadas con `<IP>` y `<DNS del anfitrión>`), los identificadores de contenedor (`<id>`) y las fechas. Todo se tapa en el propio guion, a la vista, nunca editando la salida. Los programas están en [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes), cada uno con su salida al lado, y `estado/` guarda los archivos del proyecto tal como quedan al terminar.

## Al terminar vas a poder

- Explicar por qué lo que un contenedor escribe en su propio sistema de archivos se pierde con `docker rm`, y elegir entre un volumen con nombre, un *bind mount* y un `tmpfs` para cada dato del `revisor`.
- Provocar y diagnosticar el `permission denied` de un volumen nuevo con un proceso sin privilegios, y arreglarlo en la imagen con `COPY --chown`, sin correr como `root`.
- Demostrar que el reporte sobrevive a `docker rm` leyéndolo desde un contenedor ayudante.
- Predecir qué le pasa al contenido de una carpeta cuando montas encima un volumen nuevo, un volumen con datos o un *bind mount*, y explicar la diferencia entre `-v` y `--mount` cuando la carpeta del equipo no existe.
- Correr el `revisor` con un *bind mount* de una carpeta tuya, arreglando el dueño con `--user`, y montar de solo lectura lo que el contenedor no debe cambiar.
- Mostrar que en la red por omisión un contenedor no encuentra a otro por su nombre, y que en una red definida por el usuario sí, leyendo qué servidor DNS usa cada uno.
- Encerrar el servicio de prueba en una red interna sin salida a internet y conectar el `revisor` a las dos redes, sin reiniciarlo.

## El porqué antes del cómo

Hasta ahora cada contenedor del curso ha sido una isla desechable. Lo creabas, le preguntabas algo, lo borrabas. Eso estuvo bien para aprender, porque un contenedor desechable no puede guardar sorpresas. Pero un servicio de verdad tiene dos necesidades que una isla no cubre.

La primera es **guardar algo que dure más que él**. El `revisor` escribe un reporte; ese reporte es justo lo que alguien va a pedir el lunes. Y un contenedor está hecho para ser reemplazado: cada actualización, cada cambio de configuración, cada reinicio de la máquina con `--rm` termina en un contenedor nuevo. La documentación de Docker lo dice sin rodeos: lo que se escribe en la capa del contenedor «no persiste cuando el contenedor se destruye», y además «puede ser difícil sacar los datos del contenedor si otro proceso los necesita» ([Docker, «Storage»](https://docs.docker.com/engine/storage/)). Si el reporte vive dentro del contenedor, vive lo que vive el contenedor. Y desde la Lección 7 el problema es más directo todavía: el sistema de archivos del `revisor` es de **solo lectura**. No es que el reporte se vaya a perder; es que ni siquiera se puede escribir. Hace falta un lugar escribible, fuera del contenedor, que el `revisor` pueda usar sin dejar de ser de solo lectura.

La segunda es **hablar con otros contenedores**. El `revisor` existe para revisar servicios, y hasta hoy solo se ha revisado a sí mismo (`propio http://127.0.0.1:8080/salud`), porque dentro de un contenedor `127.0.0.1` es el propio contenedor. Para revisar al servicio de prueba necesita llegar a otro contenedor. Podría usar su dirección IP, pero las direcciones las reparte Docker al arrancar y cambian; nadie quiere escribir una dirección en `REVISOR_SERVICIOS` que deja de valer en el siguiente reinicio. Lo que quieres es lo que hace cualquier programa en internet: usar un **nombre**. Y en cuanto los contenedores se hablan, aparece la pregunta de seguridad de la lección: si el servicio de prueba solo existe para que el `revisor` lo consulte, ¿por qué habría de poder salir a internet?

Así que la lección tiene dos mitades, y las dos siguen el mismo camino: primero el error, después el arreglo.

1. **Almacenamiento** (8.1 a 8.7): dónde escribe un contenedor, los tres tipos de montaje, el error de dueño que vas a encontrar con un usuario sin privilegios y su arreglo en la imagen, qué pasa con lo que ya había en la carpeta, y el `tmpfs` para lo que no debe durar.
2. **Redes** (8.8 a 8.11): la red por omisión, que no tiene nombres; la red que defines tú, que sí; y la red interna, que no tiene salida.

Con ese destino en mente, esto es lo que vas a tener al final, en la sección 8.10: el servicio de prueba en una red sin salida, el `revisor` en las dos, encontrándolo por nombre, y un contenedor que intenta salir a internet desde la red interna y no puede ni resolver el nombre del sitio:

```text
== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
```

## Los conceptos

### 8.1 Dónde escribe un contenedor

#### 8.1.1 La capa escribible, y por qué no sirve para guardar

En la Lección 4 viste que una imagen es una pila de capas de solo lectura. Cuando Docker crea un contenedor, le pone encima **una capa más, escribible y propia de ese contenedor**. Todo lo que el proceso escribe (un archivo nuevo, un archivo modificado, un archivo borrado) queda en esa capa; las de la imagen no se tocan, y por eso cien contenedores pueden salir de la misma imagen sin pisarse.

Esa capa tiene tres problemas para guardar un reporte:

- **Muere con el contenedor.** `docker rm` la borra. `docker run --rm` la borra al salir. Una actualización que reemplaza el contenedor la tira.
- **Es difícil sacar algo de ella.** Está en algún lugar del almacén interno de Docker, con una ruta que no es para ti. Otro contenedor no la puede leer.
- **En el `revisor` endurecido no existe para escribir.** Con `--read-only`, la capa escribible no acepta escrituras. Es justo lo que querías en la Lección 7: quien tome control del proceso no puede escribir en el disco. Pero el propio `revisor` tampoco.

La salida es **montar** algo encima de una carpeta del contenedor: un lugar escribible que no forma parte de la capa del contenedor, que tiene su propio ciclo de vida y que se monta solo donde hace falta. El resto del sistema de archivos sigue de solo lectura.

#### 8.1.2 Los tres tipos de montaje

Docker ofrece tres tipos de montaje que te interesan aquí (hay otros dos que no vas a usar: las tuberías con nombre, solo de Windows, y los montajes de imagen, que ponen el contenido de otra imagen dentro del contenedor y requieren el almacén de imágenes de containerd). La documentación los presenta así ([Docker, «Storage»](https://docs.docker.com/engine/storage/)):

| Tipo | Qué es | Dónde viven los datos | Cuánto duran | Para qué |
|---|---|---|---|---|
| **Volumen** (con nombre) | almacenamiento «administrado por el daemon de Docker» | en una carpeta del almacén de Docker, que tú no tocas | hasta que borres el volumen, aunque borres todos los contenedores | datos del servicio que deben durar: el reporte |
| ***Bind mount*** | «un vínculo directo» entre una ruta del equipo y una del contenedor | en una carpeta tuya, donde tú digas | lo que dure esa carpeta | archivos que tú y el contenedor deben ver: código en desarrollo, un archivo de configuración, el token de la Lección 6 |
| **`tmpfs`** | archivos «directamente en la memoria» del equipo | en la memoria | hasta que el contenedor se detenga | temporales que no deben durar ni tocar el disco |

La misma página da la recomendación corta: los volúmenes son para el almacenamiento de largo plazo; los *bind mounts*, «cuando necesitas acceder a los archivos tanto desde el contenedor como desde el equipo»; y los `tmpfs`, «solo cuando los datos no necesitan persistir más allá de la sesión del contenedor». En el `revisor` eso se traduce en una regla sencilla: **el reporte va en un volumen**. Los *bind mounts* ya los usaste para el token y los vas a usar hoy para entender el problema de los dueños; el `tmpfs`, para lo que no debe sobrevivir.

#### 8.1.3 Dos formas de escribir lo mismo: `-v` y `--mount`

Docker acepta dos sintaxis para montar, y las vas a ver en todos lados:

- **`-v origen:destino[:opciones]`** (o `--volume`). Corta. Si el origen es un nombre (`curso-docker-reportes`), es un volumen; si es una ruta absoluta (`/home/tu/reportes`), es un *bind mount*. Las opciones van al final, separadas por comas: `ro` para solo lectura, por ejemplo.
- **`--mount type=…,src=…,dst=…[,opciones]`**. Larga, con nombres en cada campo: `type=volume`, `type=bind` o `type=tmpfs`, y después `src` (el origen), `dst` (el destino), `readonly`, y las opciones propias de cada tipo.

La documentación de volúmenes dice que, «en general, se prefiere `--mount`», porque «es más explícito y admite todas las opciones disponibles» ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). `--mount` admite todas las opciones de cada tipo de montaje; `-v` solo algunas. Para un volumen, `-v` admite dos: `ro` (solo lectura) y la de no copiar el contenido de la imagen, que verás en 8.5. Esa segunda tiene una trampa medida: la página de volúmenes la llama `volume-nocopy` también con `-v`, pero Docker 29.2.1 rechaza ese nombre con `invalid mode: volume-nocopy`; con `-v` se escribe `nocopy` (`-v vol:/datos:nocopy`), y con `--mount`, `volume-nocopy`. Lo ves en `fig08_09.sh`, la solución del Ejercicio 4. Y hay una diferencia de comportamiento que importa: cuando la carpeta del equipo **no existe**, `-v` la crea y `--mount`, por omisión, se niega (8.5). Este curso usa `-v` para los volúmenes con nombre, porque es lo que vas a leer en la mayoría de los ejemplos y es igual de claro (`-v curso-docker-reportes:/datos` no deja dudas), y `--mount` para los *bind mounts* y los `tmpfs`, donde su precisión evita errores.

### 8.2 Volúmenes con nombre

#### 8.2.1 Crear, mirar, borrar

Un volumen se crea con `docker volume create <nombre>`, se lista con `docker volume ls`, se mira con `docker volume inspect` y se borra con `docker volume rm`. Si montas en un `docker run` un volumen que no existe, Docker lo crea en ese momento; aun así, crearlo antes con su nombre deja claro que es algo que tú decidiste tener, no un efecto secundario.

Los volúmenes del controlador por omisión, `local`, viven en una carpeta del equipo dentro del almacén de Docker: la documentación muestra la ruta `/var/lib/docker/volumes/<nombre>/_data` ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). Esa carpeta es de Docker y de `root`. Puedes verla con `sudo`, pero no es para tocarla a mano: para mirar dentro de un volumen, el curso usa un **contenedor ayudante**, un `alpine` desechable que monta el volumen de solo lectura y corre `ls` o `cat`. Funciona igual en Mint, en una Mac o en un servidor, no necesita `sudo` y no hay forma de que estropee los datos.

Un volumen **no se borra** con el contenedor. Esa es su razón de existir. Ni `docker rm`, ni `docker rm -f`, ni `docker stop` lo tocan. La única excepción son los volúmenes **anónimos** (los que se crean sin nombre, por ejemplo con `-v /datos` sin origen): la documentación dice que esos se destruyen con el contenedor solo si lo creaste con `--rm` ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). Un volumen con nombre vive hasta que tú lo borres con `docker volume rm`. Por eso el curso siempre les pone nombre, y con el prefijo `curso-docker-`: un volumen anónimo es un identificador de 64 caracteres que nadie recuerda de quién es, y que acaba ocupando disco para siempre.

### 8.3 El error: un volumen nuevo sobre una carpeta que la imagen no trae

#### 8.3.1 Provocarlo

Con lo anterior, el plan parece obvio: crear un volumen, montarlo en `/datos`, decirle al `revisor` que guarde ahí su reporte con `REVISOR_REPORTE=/datos/reporte.json`. El guion `fig08_02.sh` hace exactamente eso con la imagen de la Lección 7, endurecida como la dejaste:

```bash
#!/usr/bin/env bash
# fig08_02.sh — El error: un volumen nuevo sobre una carpeta que la imagen NO trae.
# Construye el revisor de la Lección 7 (la 1.4.0, sin /datos), le monta un volumen
# con nombre recién creado en /datos y le pide guardar su reporte ahí.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.4.0,
# tu contenedor curso-docker-revisor ni tu volumen curso-docker-reportes, y al
# salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08-l7"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$NOMBRE-mira" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + el Dockerfile de la Lección 7.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/../07-salud-y-ciclo-de-vida/estado/Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
# Con el prefijo por omisión esto no cambia nada.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. ¿La imagen de la Lección 7 trae una carpeta /datos?"
docker create --name "$NOMBRE-mira" "$IMAGEN" >/dev/null
docker export "$NOMBRE-mira" | tar -tv --numeric-owner | grep -c ' datos/' || true
docker rm "$NOMBRE-mira" >/dev/null

echo
echo "== 2. Un volumen con nombre, nuevo y vacío"
docker volume create "$VOLUMEN" | nombres
docker volume inspect --format 'Driver={{.Driver}} Mountpoint={{.Mountpoint}}' "$VOLUMEN" | nombres

echo
echo "== 3. El revisor de la Lección 7, endurecido, con el volumen en /datos"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -v "$VOLUMEN":/datos -e REVISOR_REPORTE=/datos/reporte.json \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"

echo
echo "== 4. ¿De quién es /datos? Lo mira un contenedor ayudante, de solo lectura"
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
echo "-- y el revisor corre como:"
docker inspect --format '{{.Config.User}}' "$NOMBRE"
```

```text
$ ./fig08_02.sh
== 1. ¿La imagen de la Lección 7 trae una carpeta /datos?
0

== 2. Un volumen con nombre, nuevo y vacío
curso-docker-reportes-fig08
Driver=local Mountpoint=/var/lib/docker/volumes/curso-docker-reportes-fig08/_data

== 3. El revisor de la Lección 7, endurecido, con el volumen en /datos
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
-- /salud no escribe nada, así que sigue contestando:
{"estado":"vivo","version":"1.4.0"}
 [200]

== 4. ¿De quién es /datos? Lo mira un contenedor ayudante, de solo lectura
drwxr-xr-x    2 0        0             4096 Oct 21 09:58 /datos
-- y el revisor corre como:
65532:65532
```

Los renglones nuevos del guion, antes de leer la salida. `docker create` crea un contenedor sin arrancarlo, y `docker export` saca su sistema de archivos completo como un archivo `tar`; `tar -tv` lo lista sin desempacarlo, y `--numeric-owner` muestra los dueños como números. Es la forma de mirar **qué carpetas trae una imagen** que no tiene *shell* para correr `ls`. `docker volume inspect` muestra lo que Docker sabe de un volumen. Y `-v "$VOLUMEN":/datos:ro` en el ayudante monta el volumen de solo lectura: el ayudante solo mira.

Ahora la salida, bloque por bloque:

1. **La imagen de la Lección 7 no trae `/datos`.** El conteo de renglones del `tar` que terminan en ` datos/` es `0`. Nadie la creó: en la Lección 7 el reporte iba a `/tmp`.
2. **El volumen es nuevo y vacío.** Su controlador es `local` y vive en `/var/lib/docker/volumes/curso-docker-reportes-fig08/_data`, la ruta que dice la documentación.
3. **El `revisor` arranca, responde `/salud` y falla al guardar.** `/api/estados` contesta `500` con `permission denied` al abrir el archivo temporal del reporte. (Recuerda de la Lección 3 que el `revisor` escribe primero un archivo temporal en la misma carpeta y luego lo renombra: por eso el error menciona `.reporte-<n>.tmp` y no `reporte.json`.) `/salud` sigue en `200`, porque no escribe nada; y como el `HEALTHCHECK` usa `/salud`, Docker diría que este contenedor está `healthy`. Corriendo, sano para Docker, y sin poder hacer su trabajo: el segundo criterio del curso, otra vez.
4. **La carpeta es de `root`.** El ayudante muestra `/datos` con dueño `0` y grupo `0`, permisos `drwxr-xr-x`: solo el dueño escribe. Y el `revisor` corre como `65532:65532`.

#### 8.3.2 Por qué pasa

Cuando montas un volumen en una ruta que la imagen no trae, Docker tiene que crear ese punto de montaje, y el volumen nuevo nace con una carpeta raíz que pertenece a `root`. Nadie le dijo otra cosa. Mientras el proceso del contenedor fue `root` (como en tantos tutoriales), esto no se notaba: `root` escribe donde quiere. Pero el `revisor` dejó de ser `root` en la Lección 3, y un usuario sin privilegios no se salta los permisos de nadie. Así que el núcleo hace lo que haría con cualquier usuario de tu equipo que intenta escribir en una carpeta ajena: niega.

Es el mismo error de la Lección 6 con el archivo del token, en otra forma. Allá el archivo era tuyo y el proceso, `65532`; aquí la carpeta es de `root` y el proceso, `65532`. La pregunta que lo resuelve es la misma: **¿quién es el dueño, y con qué usuario corre el proceso?**

Hay tres arreglos que vas a ver en internet, y solo uno es bueno:

- **Correr como `root`** (`--user 0`). Funciona y deshace el trabajo de cinco lecciones. No.
- **Cambiar el dueño del volumen desde fuera**, con un contenedor ayudante que corra `chown 65532:65532 /datos` antes de arrancar el `revisor`. Funciona, pero es un paso más que alguien tiene que recordar en cada equipo, y un contenedor que corre como `root` solo para eso.
- **Que la imagen traiga la carpeta, con el dueño correcto.** Es el arreglo de esta lección, y funciona por una regla de los volúmenes que se explica en 8.4.

### 8.4 El arreglo: la imagen trae `/datos`, del usuario correcto

#### 8.4.1 La regla que lo hace posible

La documentación de volúmenes describe lo que pasa cuando montas un volumen **vacío** en una carpeta del contenedor que **ya tiene** archivos o carpetas: «esos archivos o carpetas se propagan (se copian) al volumen» ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). La documentación habla del contenido; lo que no dice, y vas a medir en 8.4.3, es que la copia lleva también el dueño y los permisos de la carpeta de la imagen. Si la imagen trae `/datos` con dueño `65532`, un volumen nuevo montado ahí nace con dueño `65532`. El arreglo, entonces, no está en el `docker run`: está en el Dockerfile.

#### 8.4.2 El Dockerfile de esta lección

Este es el Dockerfile con el que termina la lección. Es el de la Lección 7 con tres cambios, marcados abajo:

```dockerfile
# syntax=docker/dockerfile:1
# fig08_01.Dockerfile — Lección 8: la imagen trae la carpeta /datos, con el dueño
# correcto, para que un volumen nuevo herede ese dueño. Parte de la Lección 7.

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
      -o /out/revisor ./cmd/revisor \
 && mkdir -p /out/datos

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
ARG VERSION=desarrollo
LABEL org.opencontainers.image.title="revisor" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://www.habil.mx/es/cursos/docker/"
# ENV solo para valores por omisión que NO son secretos.
ENV REVISOR_PUERTO=8080 \
    REVISOR_REPORTE=/datos/reporte.json
COPY --from=binario /out/revisor /revisor
# La carpeta de datos, del usuario sin privilegios. Un volumen con nombre que se
# monte aquí por primera vez copia este dueño.
COPY --from=binario --chown=65532:65532 /out/datos /datos
USER 65532:65532
EXPOSE 8080
# La salud la revisa el propio binario: la imagen no tiene shell ni curl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/revisor", "healthcheck"]
# Señal de apagado explícita (es la de omisión; escribirla documenta la intención).
STOPSIGNAL SIGTERM
ENTRYPOINT ["/revisor"]
```

Los tres cambios:

1. **`&& mkdir -p /out/datos` en la etapa `binario`.** Crea una carpeta vacía junto al binario. Se crea en la etapa de compilación porque la imagen final, *distroless*, no tiene *shell* ni `mkdir`: no hay con qué crear una carpeta ahí. Se agrega al mismo `RUN` que compila para no sumar una capa más a esa etapa; da igual en la imagen final, que solo recibe lo que se copia.
2. **`COPY --from=binario --chown=65532:65532 /out/datos /datos` en la etapa `final`.** Copia esa carpeta vacía a `/datos` y le pone dueño y grupo `65532`. Según la referencia del Dockerfile, `--chown` «fija el dueño de los archivos copiados», y sin esa opción quedan con usuario y grupo `0` ([referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/)). Se usan números y no nombres porque la imagen final no tiene por qué saber quién es `nonroot`; el número es lo que el núcleo compara.
3. **`REVISOR_REPORTE=/datos/reporte.json` en el `ENV`.** El valor por omisión de dónde se guarda el reporte. Es configuración, no secreto (Lección 6), y sirve en cualquier ambiente, porque la carpeta la trae la imagen. Quien corra la imagen sin decir nada guarda en `/datos`, y si monta ahí un volumen, el reporte dura.

Ese tercer cambio tiene una consecuencia que conviene ver antes de que te sorprenda. La imagen 1.5.0 **espera** que `/datos` sea escribible. Si la corres con `--read-only` y **sin** volumen, como en la Lección 7, `/api/estados` vuelve a fallar, ahora con `read-only file system`. Lo vas a ver en el bloque 6 de `fig08_03.sh`, en 8.4.3.

No es un defecto: es la imagen diciéndote dónde guarda. Desde esta lección, el `revisor` endurecido **siempre** se corre con un volumen en `/datos`. Lo vas a ver en todos los guiones que siguen, incluidos los de redes, y en el `compose.yaml` de la Lección 9.

#### 8.4.3 Verlo funcionar, y verlo sobrevivir

El guion `fig08_03.sh` construye la imagen 1.5.0, mira su `/datos`, le monta un volumen nuevo y después borra el contenedor para ver qué queda:

```bash
#!/usr/bin/env bash
# fig08_03.sh — El arreglo: la imagen 1.5.0 trae /datos del usuario 65532, y un
# volumen nuevo copia ese dueño. Después, el reporte sobrevive a docker rm, y un
# volumen en uso no se deja borrar.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0,
# tu contenedor curso-docker-revisor ni tu volumen curso-docker-reportes, y al
# salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$NOMBRE-mira" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# Los identificadores de contenedor cambian en cada corrida: se tapan a la vista.
tapar_id() { sed -E 's/[0-9a-f]{64}/<id>/g'; }
revisor() {
  docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
    -v "$VOLUMEN":/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
}

echo "== 1. Construir la 1.5.0 y mirar /datos dentro de la imagen"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN" | grep REVISOR
docker create --name "$NOMBRE-mira" "$IMAGEN" >/dev/null
docker export "$NOMBRE-mira" | tar -tv --numeric-owner | grep ' datos/' | awk '{print $1, $2, $NF}'
docker rm "$NOMBRE-mira" >/dev/null

echo
echo "== 2. Un volumen nuevo, montado en /datos: hereda el dueño de la imagen"
docker volume create "$VOLUMEN" >/dev/null
revisor
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -ln /datos

echo
echo "== 3. Un volumen en uso no se deja borrar"
salida=$(docker volume rm "$VOLUMEN" 2>&1) && rc=0 || rc=$?
echo "$salida" | nombres | tapar_id
echo "[código de salida: $rc]"

echo
echo "== 4. Borrar el contenedor: el volumen se queda, y el reporte con él"
docker rm -f "$NOMBRE" >/dev/null
echo "contenedores con ese nombre: $(docker ps -a --filter "name=^${NOMBRE}\$" --format '{{.Names}}' | wc -l)"
docker volume ls --filter "name=^${VOLUMEN}\$" --format 'volumen: {{.Name}} ({{.Driver}})' | nombres
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" cat /datos/reporte.json

echo
echo "== 5. Un contenedor nuevo con el mismo volumen sigue donde iba el otro"
revisor
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -ln /datos | awk 'NR>1 {print $1, $3, $4, $NF}'
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE" | nombres
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. La 1.5.0 endurecida SIN volumen en /datos: la raíz es de solo lectura"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'
```

```text
$ ./fig08_03.sh
== 1. Construir la 1.5.0 y mirar /datos dentro de la imagen
tamaño: 16.2MB
REVISOR_PUERTO=8080
REVISOR_REPORTE=/datos/reporte.json
drwxr-xr-x 65532/65532 datos/

== 2. Un volumen nuevo, montado en /datos: hereda el dueño de la imagen
/api/estados: [200]
drwxr-xr-x    2 65532    65532         4096 Oct 21 13:10 /datos
total 4
-rw-------    1 65532    65532           92 Oct 21 13:10 reporte.json

== 3. Un volumen en uso no se deja borrar
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
[código de salida: 1]

== 4. Borrar el contenedor: el volumen se queda, y el reporte con él
contenedores con ese nombre: 0
volumen: curso-docker-reportes-fig08 (local)
[
  {
    "servicio": "propio",
    "ok": true,
    "codigo": 200,
    "tiempo_ms": 1
  }
]

== 5. Un contenedor nuevo con el mismo volumen sigue donde iba el otro
-rw------- 65532 65532 reporte.json
/api/estados: [200]
volume curso-docker-reportes-fig08 -> /datos (escribible: true)

== 6. La 1.5.0 endurecida SIN volumen en /datos: la raíz es de solo lectura
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Bloque por bloque:

1. **La imagen pesa 16.2 MB**; la 1.4.0 de la Lección 7 medía 16.1 MB. Una carpeta vacía casi no pesa: la diferencia es de redondeo. Su entorno trae los dos valores por omisión, `REVISOR_PUERTO=8080` y `REVISOR_REPORTE=/datos/reporte.json`. Y el `tar` de su sistema de archivos ya muestra `datos/` con dueño `65532/65532`.
2. **El volumen nuevo heredó el dueño.** `/api/estados` responde `200`. El ayudante muestra `/datos` con dueño `65532`, no `0`: es la copia de 8.4.1. Dentro está `reporte.json`, de `65532`, con permisos `-rw-------`: solo su dueño lo lee y lo escribe. (Ese `600` lo decide el `revisor`: crea el archivo temporal con la función `os.CreateTemp` de Go, que usa esos permisos, y después lo renombra. El ayudante lo puede leer porque corre como `root`.) El número de bytes depende de cuántos servicios revise.
3. **Un volumen en uso no se deja borrar.** `docker volume rm` sale con código `1` y te dice quién lo está usando: `volume is in use`, con el identificador del contenedor entre corchetes. Es una protección: no puedes quitarle el piso a un contenedor que está escribiendo.
4. **El contenedor se va; el volumen y el reporte se quedan.** Después de `docker rm -f`, no hay ningún contenedor con ese nombre, el volumen sigue en la lista y el ayudante lee el reporte completo: un servicio, `propio`, sano, con código `200` (el tiempo cambia en cada corrida). Esto es lo que faltaba la mañana del lunes.
5. **Un contenedor nuevo retoma el volumen.** El `revisor` nace otra vez, encuentra el reporte anterior en su lugar, lo reemplaza con la siguiente revisión (`200`) y `docker inspect` muestra el montaje: `volume curso-docker-reportes-fig08 -> /datos (escribible: true)`. El sistema de archivos del contenedor sigue siendo de solo lectura; `/datos` es la única excepción, y tiene nombre.
6. **Sin el volumen, la 1.5.0 endurecida no puede guardar.** Es la consecuencia de 8.4.2: `read-only file system` y `500`. La imagen ya dice dónde guarda; quien la corre con `--read-only` tiene que darle ese lugar.

#### 8.4.4 En tu carpeta

Tu proyecto vive en `~/curso-docker/revisor` desde la Lección 3. Desde la raíz del repositorio del curso, pon ahí el Dockerfile de esta lección, construye la imagen que vas a conservar y crea tu volumen:

```bash
cp programas/08-volumenes-y-redes/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.5.0 -t curso-docker-revisor:1.5.0 .
docker volume create curso-docker-reportes
```

El `.dockerignore` y la carpeta `secretos/` no cambian. Antes de seguir, repite a mano el error y el arreglo con tus propios nombres: corre `curso-docker-revisor:1.4.0` con un volumen recién creado en `/datos` y `-e REVISOR_REPORTE=/datos/reporte.json`, y mira el `500`; bórralo junto con ese volumen; y corre `curso-docker-revisor:1.5.0` con `curso-docker-reportes`. Lo único que cambia respecto a los guiones son los nombres. Los guiones de esta lección no tocan nada de esto: usan nombres de apoyo con `fig08` y borran solo lo suyo.

### 8.5 Copiar contra tapar: lo que ya había en la carpeta

#### 8.5.1 Cuatro casos que conviene no confundir

La regla de 8.4.1 tiene condiciones, y casi todos los sustos con montajes salen de olvidarlas. Cuando montas algo sobre una carpeta del contenedor que ya tiene contenido, pasa una de estas cosas:

| Lo que montas | Lo que ve el contenedor | Lo que le pasa al contenido de la imagen |
|---|---|---|
| un volumen **nuevo y vacío** | el contenido de la imagen | se **copia** al volumen, con dueños y permisos |
| un volumen nuevo con `volume-nocopy` | una carpeta vacía | no se copia; queda tapado |
| un volumen **que ya tiene datos** | lo que hay en el volumen | queda **tapado**; no se copia nada |
| un ***bind mount*** | lo que hay en la carpeta del equipo | queda **tapado**; no se copia nada |

«Tapado» es la palabra de la documentación: si montas un volumen con datos donde ya había archivos, «los archivos previos quedan ocultos por el montaje» ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)); con un *bind mount*, «el contenido existente de la carpeta queda oculto» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). No se borran: siguen en la capa de la imagen, debajo, y reaparecen si corres un contenedor sin el montaje. Pero mientras el montaje esté, el contenedor no los ve.

Fíjate en la tercera fila, porque tiene una consecuencia práctica: la copia ocurre **solo la primera vez**, cuando el volumen está vacío. Si el volumen `curso-docker-reportes` se creó con la imagen 1.5.0 y mañana una imagen 1.6.0 trae algo distinto en `/datos`, el volumen no se actualiza: ya tiene datos, así que gana el volumen. Para un reporte eso es exactamente lo que quieres (los datos del servicio no deben cambiar porque cambió la imagen). Para quien guarda en un volumen archivos que deberían venir de la imagen, es una fuente clásica de «actualicé y sigue igual».

#### 8.5.2 Verlo con un contenedor ayudante

El guion `fig08_04.sh` muestra los cuatro casos con el `alpine` ayudante, sobre su carpeta `/etc/apk`, que trae cinco entradas. Al final prueba la diferencia entre `-v` y `--mount` con una carpeta del equipo que no existe:

```bash
#!/usr/bin/env bash
# fig08_04.sh — Copiar contra tapar. Un volumen NUEVO montado sobre una carpeta
# con contenido recibe una copia de ese contenido; un bind mount, en cambio, la
# tapa. Y la diferencia entre -v y --mount cuando la carpeta del equipo no existe.
# No construye nada: usa el contenedor ayudante alpine:3.24.2.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus volúmenes del curso, y al
# salir borra solo lo que creó.
TRABAJO="$(mktemp -d)"
VOLUMEN="${PREFIJO}copia-fig08"
VOLUMEN_SIN_COPIA="${PREFIJO}sin-copia-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker volume rm "$VOLUMEN" "$VOLUMEN_SIN_COPIA" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT
cd "$TRABAJO"
# La ruta de la carpeta temporal cambia en cada corrida: se escribe como «.».
tapar_ruta() { sed "s#$TRABAJO#.#g"; }

echo "== 1. La carpeta /etc/apk de la imagen, sin montar nada"
docker run --rm "$AYUDANTE" ls /etc/apk

echo
echo "== 2. Un volumen NUEVO montado ahí: el contenedor ve lo mismo..."
docker run --rm -v "$VOLUMEN":/etc/apk "$AYUDANTE" ls /etc/apk
echo "-- ...porque Docker copió el contenido al volumen. Míralo montado en otra ruta:"
docker run --rm -v "$VOLUMEN":/mirar:ro "$AYUDANTE" ls /mirar

echo
echo "== 3. Lo mismo con volume-nocopy: el volumen se queda vacío"
docker run --rm --mount type=volume,src="$VOLUMEN_SIN_COPIA",dst=/etc/apk,volume-nocopy \
  "$AYUDANTE" ls /etc/apk | wc -l

echo
echo "== 4. Un bind mount de una carpeta vacía del equipo: tapa lo de la imagen"
mkdir vacia
docker run --rm --mount type=bind,src="$TRABAJO/vacia",dst=/etc/apk "$AYUDANTE" ls /etc/apk | wc -l
echo "-- y en el equipo, la carpeta sigue vacía: no se copió nada en ningún sentido"
ls vacia | wc -l

echo
echo "== 5. -v con una carpeta del equipo que NO existe: Docker la crea... como root"
docker run --rm -v "$TRABAJO/no-existia":/datos "$AYUDANTE" true
stat -c '%U:%G %n' no-existia

echo
echo "== 6. --mount con una carpeta que no existe: se niega"
docker run --rm --mount type=bind,src="$TRABAJO/tampoco-existe",dst=/datos "$AYUDANTE" true 2>&1 | tapar_ruta
echo "[código de salida: ${PIPESTATUS[0]}]"
```

```text
$ ./fig08_04.sh
== 1. La carpeta /etc/apk de la imagen, sin montar nada
arch
keys
protected_paths.d
repositories
world

== 2. Un volumen NUEVO montado ahí: el contenedor ve lo mismo...
arch
keys
protected_paths.d
repositories
world
-- ...porque Docker copió el contenido al volumen. Míralo montado en otra ruta:
arch
keys
protected_paths.d
repositories
world

== 3. Lo mismo con volume-nocopy: el volumen se queda vacío
0

== 4. Un bind mount de una carpeta vacía del equipo: tapa lo de la imagen
0
-- y en el equipo, la carpeta sigue vacía: no se copió nada en ningún sentido
0

== 5. -v con una carpeta del equipo que NO existe: Docker la crea... como root
root:root no-existia

== 6. --mount con una carpeta que no existe: se niega
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe

Run 'docker run --help' for more information
[código de salida: 125]
```

Bloque por bloque:

1. **Sin montaje**, `/etc/apk` tiene cinco entradas: `arch`, `keys`, `protected_paths.d`, `repositories` y `world`.
2. **Con un volumen nuevo**, el contenedor ve las mismas cinco. Y no es que vea las de la imagen «a través» del volumen: montado en otra ruta (`/mirar`), en un contenedor distinto, el volumen las tiene. Docker las copió al montarlo por primera vez.
3. **Con `volume-nocopy`**, cero entradas. La opción le dice a Docker que no copie aunque el volumen esté vacío ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)); con `-v` también existe, pero se escribe `nocopy` (8.1.3). Si alguna vez la ves en un `docker run` del `revisor`, ya sabes qué va a pasar: el volumen nace con su carpeta de `root`, como en 8.3, y vuelve el `permission denied`. Lo vas a comprobar en el Ejercicio 4.
4. **Con un *bind mount* de una carpeta vacía**, cero entradas: lo de la imagen quedó tapado. Y la carpeta del equipo sigue vacía: un *bind mount* no copia nada en ningún sentido. El contenedor ve **tu carpeta**, tal cual, y nada más.
5. **`-v` con una ruta del equipo que no existe**: el contenedor arranca sin quejarse, y en tu equipo aparece la carpeta `no-existia`... con dueño `root:root`. La creó el daemon, que corre como `root`. La documentación lo dice así: con `-v`, «Docker crea la carpeta en el equipo por ti» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). Lo que no dice tan alto es el dueño, y es lo que muerde: un error de dedo en la ruta te deja una carpeta de `root` en tu proyecto, un contenedor escribiendo en el lugar equivocado y, si el proceso no es `root`, otro `permission denied`.
6. **`--mount` con una ruta que no existe**: se niega. `invalid mount config for type "bind": bind source path does not exist`, con código `125`, el que usa `docker run` cuando el error es del propio Docker y no del programa. Es el comportamiento que quieres: un error de dedo se ve en el acto. (La ruta aparece como `./tampoco-existe` porque el guion tapa la carpeta temporal, que cambia en cada corrida.) Es el comportamiento por omisión: `--mount` también puede crear la carpeta si se lo pides con la opción `bind-create-src`, que según la documentación «crea automáticamente la carpeta de origen en el equipo si no existe» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). Este curso no la usa, porque lo que busca es justo que el error de dedo se vea. Por eso usa `--mount` para los *bind mounts*.

### 8.6 *Bind mounts* y el dueño de los archivos

#### 8.6.1 Cuándo un *bind mount* y no un volumen

Un *bind mount* sirve cuando tú, desde tu equipo, necesitas ver o poner los archivos sin pasar por Docker: el código de un programa mientras lo desarrollas, un archivo de configuración que editas a mano, el token de la Lección 6, o un reporte que otra herramienta de tu equipo va a recoger. El precio es que el contenedor escribe **directamente en tu sistema de archivos**. La documentación lo advierte: con un *bind mount* «puedes cambiar el sistema de archivos del equipo desde procesos que corren en un contenedor», y los *bind mounts* tienen, por omisión, «acceso de escritura a los archivos del equipo» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). Por eso, cuando el contenedor solo necesita leer, el montaje va con `readonly`, como el token.

#### 8.6.2 El mismo error, por el lado contrario

Con un volumen, la carpeta era de `root` y el arreglo fue que la imagen trajera la suya. Con un *bind mount* eso no sirve: el contenedor ve **tu** carpeta, con **tu** dueño, y lo que la imagen traiga en `/datos` queda tapado (8.5). Así que el choque vuelve, ahora entre tu usuario y el `65532`. El guion `fig08_05.sh` lo provoca y lo arregla sin `root`:

```bash
#!/usr/bin/env bash
# fig08_05.sh — Bind mount: la carpeta es tuya, el proceso es 65532. Primero el
# error de permisos; después el arreglo sin root (correr con TU usuario); y al
# final el mismo montaje de solo lectura.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los dueños y los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
SERVICIOS='propio http://127.0.0.1:8080/salud'
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. Una carpeta tuya en el equipo"
mkdir reportes
stat -c '%u:%g %a %n' reportes
echo "tu usuario: $(id -u):$(id -g)"

echo
echo "== 2. Montada en /datos con un bind mount; el revisor corre como 65532"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El arreglo sin root: correr el contenedor con TU usuario"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- el reporte, visto desde el equipo, sin docker ni sudo:"
stat -c '%u:%g %a %n' reportes/reporte.json
head -c 60 reportes/reporte.json | tr -d '\n '; echo " …"
echo "-- lo que anotó Docker:"
docker inspect --format 'User={{.Config.User}}{{range .Mounts}} | {{.Type}} -> {{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 4. El mismo bind mount, de solo lectura"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos,readonly \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
```

```text
$ ./fig08_05.sh
== 1. Una carpeta tuya en el equipo
501:1000 775 reportes
tu usuario: 501:1000

== 2. Montada en /datos con un bind mount; el revisor corre como 65532
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]

== 3. El arreglo sin root: correr el contenedor con TU usuario
/api/estados: [200]
-- el reporte, visto desde el equipo, sin docker ni sudo:
501:1000 600 reportes/reporte.json
[{"servicio":"propio","ok":true,"codigo" …
-- lo que anotó Docker:
User=501:1000 | bind -> /datos (escribible: true)

== 4. El mismo bind mount, de solo lectura
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Bloque por bloque:

1. **La carpeta es tuya**: dueño `501:1000`, permisos `775` (tú y tu grupo escriben; los demás, no). En tu Mint dirá `1000:1000`. El guion imprime tu usuario para que lo compares.
2. **Montada en `/datos`, `permission denied`.** El `revisor` corre como `65532`, que no es el dueño ni está en el grupo `1000`, y para «los demás» la carpeta no es escribible. El montaje no traduce nada: dentro del contenedor la carpeta tiene el mismo dueño numérico que fuera. (Con Docker sin `root` o con remapeo de usuarios, el número de dentro se traduce a otro fuera; la instalación de la Lección 1 no hace eso.)
3. **El arreglo: correr el contenedor con tu usuario.** `--user "$(id -u):$(id -g)"` reemplaza al `65532` de la imagen por tus números, y ahora el proceso es el dueño de la carpeta: `200`. Y el reporte, visto desde tu equipo, es tuyo (`501:1000`, `600`): lo lees sin `docker` y sin `sudo`. Fíjate en lo que **no** cambió: el proceso sigue sin ser `root`, sigue sin capacidades y el sistema de archivos sigue de solo lectura. Cambiaste un usuario sin privilegios por otro usuario sin privilegios, el tuyo. Ojo: si corres el comando con `sudo`, `$(id -u)` vale `0` y estarías corriendo como `root` sin darte cuenta. Por eso en la Lección 1 entraste al grupo `docker`: estos comandos van sin `sudo`. `docker inspect` lo confirma: `User=501:1000`, y el montaje `bind -> /datos (escribible: true)`.
4. **De solo lectura, el núcleo se niega.** Con `readonly`, el `revisor` vuelve a fallar, ahora con `read-only file system`: ni siendo el dueño puede escribir. Para el reporte no tiene sentido, pero es exactamente lo que quieres para un archivo de configuración o un secreto: el contenedor lo lee y no lo puede cambiar.

¿Por qué no `chmod 777` a la carpeta? Porque deja que **cualquier usuario de tu equipo** escriba ahí, y que cualquier contenedor con cualquier usuario la llene. Es la versión de carpeta del `644` de la Lección 6, pero peor, porque aquí se escribe, no solo se lee. `--user` con tus números resuelve el problema donde nace: el dueño.

### 8.7 `tmpfs`: lo que no debe durar

#### 8.7.1 Para qué

En la Lección 7 usaste `--tmpfs /tmp` para que el `revisor` pudiera escribir su reporte con el sistema de archivos de solo lectura. Funcionó, y el reporte moría con el contenedor. Ahora el reporte tiene su volumen, pero el `tmpfs` sigue teniendo un lugar: todo lo que un programa escribe y **no** debe sobrevivir. Archivos temporales, cachés de una sola corrida, un archivo con un secreto descifrado que no debe tocar el disco. La documentación lo resume: a diferencia de volúmenes y *bind mounts*, un `tmpfs` «es temporal y solo persiste en la memoria del equipo», y «cuando el contenedor se detiene, el montaje `tmpfs` se elimina» ([Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/)). Tampoco se puede compartir entre contenedores.

Dos valores por omisión de esa página que conviene saber: sin tamaño, el tope de un `tmpfs` es **la mitad de la memoria del equipo**, y su permiso es `1777`, escribible por cualquiera (con el bit que impide borrar archivos ajenos, el mismo de `/tmp` en tu Mint). Y una advertencia honesta: el núcleo puede mandar a la memoria de intercambio (*swap*) lo que hay en un `tmpfs`, así que «en memoria» no es garantía de que nunca toque el disco.

#### 8.7.2 Volumen y `tmpfs`, lado a lado

El guion `fig08_06.sh` corre un contenedor de solo lectura con los dos montajes, escribe en ambos, lo reinicia y mira qué sobrevivió:

```bash
#!/usr/bin/env bash
# fig08_06.sh — tmpfs contra volumen. Un contenedor de solo lectura con dos
# lugares escribibles: un volumen en /datos y un tmpfs de 1 MB en /cache. Escribe
# en los dos, se reinicia, y se ve qué sobrevivió. También el tope del tmpfs.
# No construye nada: usa el contenedor ayudante alpine:3.24.2.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores ni tus
# volúmenes del curso, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}ayudante-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true' EXIT
# en COMANDO: corre COMANDO con sh dentro del contenedor y avisa si falló
en() { docker exec "$NOMBRE" sh -c "$1" 2>&1 || echo "[código de salida: $?]"; }

echo "== 1. Solo lectura, con un volumen en /datos y un tmpfs en /cache"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --mount type=volume,src="$VOLUMEN",dst=/datos \
  --mount type=tmpfs,dst=/cache,tmpfs-size=1m \
  "$AYUDANTE" sleep 300 >/dev/null
echo "-- dónde está montado cada uno, de qué tipo y con qué opciones:"
en 'awk "\$2 == \"/datos\" || \$2 == \"/cache\" {print \$2, \$3, \$4}" /proc/mounts'
en 'stat -c "%a %n" /cache'

echo
echo "== 2. Escribir en los dos, y en la raíz"
en 'echo reporte > /datos/a.txt && echo temporal > /cache/b.txt && ls /datos /cache'
en 'echo hola > /c.txt'

echo
echo "== 3. El tmpfs tiene tope: 2 MB no caben en 1 MB"
en 'dd if=/dev/zero of=/cache/grande bs=1k count=2000 2>&1 | head -1'
en 'rm -f /cache/grande'

echo
echo "== 4. Reiniciar el contenedor"
docker restart -t 2 "$NOMBRE" >/dev/null
en 'ls /datos; echo "-- /cache tiene $(ls /cache | wc -l) archivos"'
```

```text
$ ./fig08_06.sh
== 1. Solo lectura, con un volumen en /datos y un tmpfs en /cache
-- dónde está montado cada uno, de qué tipo y con qué opciones:
/cache tmpfs rw,nosuid,nodev,noexec,relatime,size=1024k,inode64
/datos ext4 rw,relatime,discard,errors=remount-ro,commit=30
1777 /cache

== 2. Escribir en los dos, y en la raíz
/cache:
b.txt

/datos:
a.txt
sh: can't create /c.txt: Read-only file system
[código de salida: 1]

== 3. El tmpfs tiene tope: 2 MB no caben en 1 MB
dd: error writing '/cache/grande': No space left on device

== 4. Reiniciar el contenedor
a.txt
-- /cache tiene 0 archivos
```

1. **Los dos montajes y sus opciones**, leídos de `/proc/mounts`, la lista que lleva el núcleo. `/datos` es `ext4`: el volumen vive en el disco del equipo. `/cache` es `tmpfs`, con `size=1024k` (el `1m` que pediste) y tres opciones que Docker le puso por su cuenta al montarlo con `--mount`: `nosuid`, `nodev` y `noexec`. En la Lección 7 las escribiste a mano con `--tmpfs`; con `--mount type=tmpfs` vienen solas. El permiso es `1777`.
2. **Se escribe en los dos y no en la raíz.** `a.txt` en el volumen, `b.txt` en el `tmpfs`; y `/c.txt` falla con `Read-only file system`, porque fuera de los montajes todo es de solo lectura. Tres carpetas, tres comportamientos, y cada uno lo pediste por nombre.
3. **El `tmpfs` tiene tope.** Escribir 2 MB en un `tmpfs` de 1 MB termina en `No space left on device`. Sin `size`, ese tope sería la mitad de la memoria del equipo: un programa con un error que escribe sin parar podría ocupar mucho más de lo que imaginabas. Con el tope, el error aparece en el acto y con un mensaje claro.
4. **Después de `docker restart`, el volumen conserva `a.txt` y el `tmpfs` está vacío.** Un reinicio basta para borrar el `tmpfs`; no hace falta borrar el contenedor.

La documentación prefiere `--mount type=tmpfs` y reconoce que `--tmpfs` «es menos verboso» y admite más opciones de montaje ([Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/)). Las dos sirven. Lo importante es ponerle tamaño.

#### 8.7.3 Cuál usar, en el `revisor`

| Dato | Montaje | Por qué |
|---|---|---|
| el reporte (`/datos/reporte.json`) | volumen con nombre en `/datos` | tiene que sobrevivir al contenedor; nadie necesita editarlo a mano |
| el token (`/run/secrets/revisor_token`) | *bind mount* de un archivo, `readonly` | lo pones tú desde fuera; el contenedor solo lo lee |
| un temporal que el programa no deba conservar | `tmpfs` con tamaño | debe morir con el contenedor y no ocupar disco |
| el código del programa | ninguno: va en la imagen | es código, no datos (Lección 6) |

### 8.8 Redes: la red por omisión no tiene nombres

#### 8.8.1 Qué es una red de Docker

Cada contenedor tiene su propia pila de red: sus interfaces, su dirección IP, su tabla de rutas, su `127.0.0.1`. Es uno de los aislamientos de la Lección 0. Para que los contenedores se hablen, Docker los conecta a **redes**: por debajo, en Linux, un puente virtual (*bridge*) al que se conecta una interfaz de cada contenedor, como cables a un mismo conmutador. El controlador por omisión se llama justamente `bridge`.

Docker crea tres redes al instalarse, `bridge`, `host` y `none` (las ves con `docker network ls`), y si no dices otra cosa, todo contenedor se conecta a `bridge`. Ahí ha estado cada contenedor del curso hasta hoy. Esa red tiene una limitación que la documentación dice sin adornos: en la red por omisión, los contenedores «solo se pueden alcanzar por dirección IP». Más todavía: «la red `bridge` por omisión se considera un detalle heredado de Docker y no se recomienda para producción» ([Docker, controlador `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)).

#### 8.8.2 Verlo: por nombre no, por IP sí

El guion `fig08_07.sh` pone al `revisor` y al servicio de prueba en la red por omisión, y le pide al `revisor` revisar `http://curso-docker-prueba-fig08:9000/`. Después hace lo mismo en una red definida por el usuario, y al final rompe el servicio de prueba desde otro contenedor:

```bash
#!/usr/bin/env bash
# fig08_07.sh — Redes. En la red por omisión, el revisor no encuentra al servicio
# de prueba por su nombre (por IP sí). En una red definida por el usuario, sí lo
# encuentra, porque ahí hay un DNS. Y al romper el servicio, el reporte lo ve.
# Usa tu imagen curso-docker-prueba:1.0.0 (de la Lección 2) sin modificarla.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores, tus redes
# ni tus imágenes del curso, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
PRUEBA="${PREFIJO}prueba-fig08"
RED="${PREFIJO}red-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
IMAGEN_PRUEBA=curso-docker-prueba:1.0.0
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null 2>&1 || true
      docker network rm "$RED" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

docker image inspect "$IMAGEN_PRUEBA" >/dev/null 2>&1 \
  || { echo "falta $IMAGEN_PRUEBA: constrúyela como en la Lección 2"; exit 1; }
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# Lo que depende de cada equipo se tapa a la vista: los tiempos de la tabla, la
# dirección del DNS del anfitrión y las direcciones IP de los contenedores.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" \
    | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /; s/on [0-9.]+:53/on <DNS del anfitrión>:53/' | nombres
}
tapar_ip() { sed -E 's/(^|[^0-9])(10|172|192)\.[0-9]+\.[0-9]+\.[0-9]+/\1<IP>/g'; }
revisor() {  # revisor [opciones de red]
  docker run -d --name "$NOMBRE" "$@" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO -v "$VOLUMEN":/datos \
    -e REVISOR_SERVICIOS="prueba http://$PRUEBA:9000/ 2s" "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
}

echo "== 1. Los dos en la red por omisión (bridge): por nombre, no"
docker run -d --name "$PRUEBA" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
revisor
tabla
echo "-- la red de cada uno:"
docker inspect --format '{{.Name}}: {{range $red, $v := .NetworkSettings.Networks}}{{$red}}{{end}}' "$NOMBRE" "$PRUEBA" | nombres
echo "-- el DNS que reciben los contenedores de esa red es el del anfitrión:"
docker run --rm "$AYUDANTE" grep nameserver /etc/resolv.conf | sed -E 's/[0-9.]+$/<DNS del anfitrión>/' | head -1
echo "-- por IP, en cambio, sí llega:"
IP=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PRUEBA")
echo "IP del servicio de prueba: $IP" | tapar_ip
docker run --rm "$AYUDANTE" wget -qO- "http://$IP:9000/"
docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null

echo
echo "== 2. Una red definida por el usuario"
docker network create "$RED" >/dev/null
docker network inspect --format '{{.Name}} driver={{.Driver}} interna={{.Internal}}' "$RED" | nombres
docker run -d --name "$PRUEBA" --network "$RED" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
revisor --network "$RED"
tabla
echo "-- en esta red, el DNS es el que Docker pone dentro de cada contenedor:"
docker run --rm --network "$RED" "$AYUDANTE" grep nameserver /etc/resolv.conf
docker run --rm --network "$RED" "$AYUDANTE" nslookup "$PRUEBA" 2>&1 \
  | grep -E '^(Server|Name|Address)' | nombres | tapar_ip
echo "-- quién está conectado a la red:"
docker network inspect --format '{{range .Containers}}{{.Name}}{{println}}{{end}}' "$RED" | sed '/^$/d' | sort | nombres

echo
echo "== 3. Romper el servicio de prueba desde otro contenedor de la misma red"
docker run --rm --network "$RED" "$AYUDANTE" wget -qO- --post-data= "http://$PRUEBA:9000/modo/caido"
tabla
```

```text
$ ./fig08_07.sh
== 1. Los dos en la red por omisión (bridge): por nombre, no
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
-- la red de cada uno:
/curso-docker-revisor-fig08: bridge
/curso-docker-prueba-fig08: bridge
-- el DNS que reciben los contenedores de esa red es el del anfitrión:
nameserver <DNS del anfitrión>
-- por IP, en cambio, sí llega:
IP del servicio de prueba: <IP>
sano

== 2. Una red definida por el usuario
curso-docker-red-fig08 driver=bridge interna=false
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
-- en esta red, el DNS es el que Docker pone dentro de cada contenedor:
nameserver 127.0.0.11
Server:		127.0.0.11
Address:	127.0.0.11:53
Name:	curso-docker-prueba-fig08
Address: <IP>
-- quién está conectado a la red:
curso-docker-prueba-fig08
curso-docker-revisor-fig08

== 3. Romper el servicio de prueba desde otro contenedor de la misma red
modo: caido
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA         <t>  codigo 503
```

La primera mitad de la salida, la red por omisión:

1. **`FALLA`, con `no such host`.** El mensaje completo se lee de derecha a izquierda: `no such host` (el nombre no existe), `lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53` (se lo preguntó al servidor DNS de tu equipo, en el puerto 53, el de DNS), `dial tcp` (quería abrir una conexión) y `Get "http://…"` (para hacer esta petición). El servidor DNS de tu equipo no tiene idea de qué contenedores corren en Docker, así que contesta lo único que puede: ese nombre no existe. La dirección real de ese servidor depende de cada red, y el guion la tapa.
2. **Los dos están en la misma red**, `bridge`. No es que estén separados: están juntos y aun así no se encuentran por nombre.
3. **El DNS que reciben es el del anfitrión.** La documentación explica que los contenedores de la red por omisión reciben una copia del `/etc/resolv.conf` de tu equipo ([Docker, «Networking»](https://docs.docker.com/engine/network/)). El ayudante lo muestra: `nameserver <DNS del anfitrión>`.
4. **Por IP, sí llega.** El guion le pregunta a Docker la dirección del servicio de prueba (tapada como `<IP>`) y el ayudante le hace una petición directa: `sano`. La red funciona; lo que falta son los nombres. Y una IP no sirve para configurar el `revisor`, porque la reparte Docker al arrancar y puede cambiar en el siguiente.

En los tutoriales viejos vas a ver la solución de antes para esto, `--link`. La sección 8.12 explica por qué ya no.

### 8.9 Redes definidas por el usuario: nombres gratis

#### 8.9.1 Qué cambia

Una red que creas con `docker network create` (también con el controlador `bridge`) se comporta distinto. La documentación lista las diferencias ([Docker, controlador `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)):

- **DNS automático**: «las redes *bridge* definidas por el usuario dan resolución DNS automática entre contenedores». Cada contenedor se encuentra por su nombre.
- **Mejor aislamiento**: solo los contenedores conectados a esa red se hablan entre sí. En la red por omisión, en cambio, cualquier contenedor que alguien arranque sin pensar queda junto a los tuyos.
- **Conectar y desconectar en caliente**: un contenedor se puede conectar a una red definida por el usuario, o desconectar, «sobre la marcha», sin recrearlo. Lo vas a hacer en 8.10.

El DNS lo da un servidor que Docker pone **dentro** de cada contenedor de esas redes, en la dirección `127.0.0.11`. La documentación lo llama el servidor DNS integrado, y explica que contesta los nombres de los contenedores de la red y reenvía todo lo demás a los servidores DNS del equipo ([Docker, «Networking»](https://docs.docker.com/engine/network/)). Por eso un contenedor en una red tuya resuelve tanto `curso-docker-prueba` como `www.docker.com`.

#### 8.9.2 Leer la segunda mitad de la corrida

De vuelta a la salida de `fig08_07.sh`, bloque 2:

1. **La red**: `curso-docker-red-fig08`, controlador `bridge`, `interna=false` (tiene salida; en 8.10 crearás una que no).
2. **`OK`, `200`.** El mismo `revisor`, con la misma configuración, encuentra al servicio de prueba por su nombre. No cambiaste ni una letra de `REVISOR_SERVICIOS`: cambiaste la red.
3. **El DNS ahora es `127.0.0.11`.** El ayudante, conectado a la misma red, lo muestra en su `/etc/resolv.conf`, y `nslookup` le pregunta por el nombre del servicio de prueba: el servidor `127.0.0.11` contesta con su dirección (tapada).
4. **Quién está conectado**: los dos contenedores, y nadie más. El ayudante no aparece porque ya terminó (`--rm`).

Y el bloque 3, el que justifica todo el curso: un contenedor de la misma red le hace `POST /modo/caido` al servicio de prueba (`modo: caido`), y la siguiente revisión del `revisor` dice `FALLA`, `codigo 503`. El servicio de prueba sigue corriendo; el `revisor`, que lo revisa por nombre a través de la red, distingue lo que Docker cree (el contenedor está arriba) de lo que pasa (contesta `503`). (La columna `TIEMPO` del último renglón sale con un espacio de más porque el guion tapa un tiempo de un ancho distinto; es la tabla, no un error.)

Una nota sobre el nombre: el `revisor` busca `curso-docker-prueba-fig08` porque así se llama el contenedor del guion. En tu carpeta el contenedor se llama `curso-docker-prueba`, y `REVISOR_SERVICIOS` dice `prueba http://curso-docker-prueba:9000/ 2s`. El nombre del contenedor **es** su nombre en la red; si lo cambias, cambias su dirección.

### 8.10 Redes internas: sin salida

#### 8.10.1 Por qué encerrar al servicio de prueba

El servicio de prueba solo existe para que el `revisor` lo consulte. No necesita descargar nada, no necesita llamar a nadie, no necesita internet. Y todo lo que un contenedor puede alcanzar es algo que un atacante que lo controle también puede alcanzar: descargar una herramienta, mandar datos fuera, usarlo de trampolín. La respuesta es una **red interna**: `docker network create --internal`. La referencia de `docker network create` la describe en una frase, «restringe el acceso externo a la red», y la explica así: los contenedores de una red interna «se pueden comunicar entre sí, pero no con ninguna otra red, porque no se configura una ruta por omisión y se ponen reglas de cortafuegos que descartan todo el tráfico hacia o desde otras redes» ([referencia de `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/)).

El diseño es el que la propia documentación usa de ejemplo: una red interna «para comunicarse con contenedores que corren servicios internos que no necesitan acceso a la red externa» ([Docker, «Networking»](https://docs.docker.com/engine/network/)). El servicio de prueba, **solo** en la interna. El `revisor`, en la red normal (por donde se publica su puerto hacia tu `127.0.0.1`) **y** en la interna (por donde revisa al servicio de prueba). Un contenedor puede estar en varias redes a la vez: tiene una interfaz en cada una.

#### 8.10.2 Verlo

El guion `fig08_08.sh` arma ese estado, que es el estado final de la lección, en dos pasos, para que veas qué aporta cada red:

```bash
#!/usr/bin/env bash
# fig08_08.sh — Red interna. El servicio de prueba vive SOLO en una red interna,
# sin salida a internet. El revisor vive en la red normal (por donde se publica
# su puerto) y se conecta además a la interna. Es el estado final de la lección.
# Usa tu imagen curso-docker-prueba:1.0.0 (de la Lección 2) sin modificarla.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores, tus redes,
# tus volúmenes ni tus imágenes del curso, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
PRUEBA="${PREFIJO}prueba-fig08"
RED="${PREFIJO}red-fig08"
INTERNA="${PREFIJO}interna-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
IMAGEN_PRUEBA=curso-docker-prueba:1.0.0
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null 2>&1 || true
      docker network rm "$RED" "$INTERNA" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

docker image inspect "$IMAGEN_PRUEBA" >/dev/null 2>&1 \
  || { echo "falta $IMAGEN_PRUEBA: constrúyela como en la Lección 2"; exit 1; }
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null || exit 1

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" \
    | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /' | nombres
}

echo "== 1. Dos redes: la normal y la interna"
docker network create "$RED" >/dev/null
docker network create --internal "$INTERNA" >/dev/null
docker network inspect --format '{{.Name}} driver={{.Driver}} interna={{.Internal}}' "$RED" "$INTERNA" | nombres

echo
echo "== 2. El servicio de prueba, solo en la interna; el revisor, solo en la normal"
docker run -d --name "$PRUEBA" --network "$INTERNA" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
docker run -d --name "$NOMBRE" --network "$RED" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -v "$VOLUMEN":/datos -e REVISOR_SERVICIOS="prueba http://$PRUEBA:9000/ 2s" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 3. Conectar el revisor también a la interna, sin reiniciarlo"
docker network connect "$INTERNA" "$NOMBRE"
tabla
docker inspect --format '{{range $red, $v := .NetworkSettings.Networks}}{{$red}} {{end}}' "$NOMBRE" | nombres
echo "-- el puerto publicado sigue en 127.0.0.1:"
docker port "$NOMBRE" | sed "s/:$PUERTO\$/:<puerto>/"

echo
echo "== 4. Desde la red interna no hay salida a internet"
docker run --rm --network "$INTERNA" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/
echo "[código de salida: $?]"
echo "-- pero la puerta de enlace de la red interna sí contesta:"
PUERTA=$(docker network inspect --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' "$INTERNA")
docker run --rm --network "$INTERNA" "$AYUDANTE" sh -c "ip route; ping -c 1 -W 2 $PUERTA | grep -E 'packets'" \
  | sed -E 's/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?/<IP>\1/g'
echo "-- desde la red normal, sí:"
docker run --rm --network "$RED" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/ \
  && echo "desde la red normal sí hay salida"
```

```text
$ ./fig08_08.sh
== 1. Dos redes: la normal y la interna
curso-docker-red-fig08 driver=bridge interna=false
curso-docker-interna-fig08 driver=bridge interna=true

== 2. El servicio de prueba, solo en la interna; el revisor, solo en la normal
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on 127.0.0.11:53: no such host

== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 
-- el puerto publicado sigue en 127.0.0.1:
8080/tcp -> 127.0.0.1:<puerto>

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
-- pero la puerta de enlace de la red interna sí contesta:
<IP>/16 dev eth0 scope link  src <IP> 
1 packets transmitted, 1 packets received, 0% packet loss
-- desde la red normal, sí:
desde la red normal sí hay salida
```

1. **Dos redes**, las dos con controlador `bridge`; una con `interna=true`.
2. **El `revisor` solo en la red normal no encuentra al servicio de prueba.** Ahora el mensaje dice `lookup … on 127.0.0.11:53: no such host`. Compáralo con el de 8.8: allá preguntó al DNS de tu equipo (red por omisión); aquí preguntó al DNS integrado de Docker (red definida por el usuario), que sí existe, pero solo contesta los nombres de **las redes del propio contenedor**. El servicio de prueba está en otra red, así que para el `revisor` no existe. Es el aislamiento de 8.9.1 funcionando: estar en el mismo equipo no basta, hay que compartir red. Leer en qué servidor DNS se hizo la pregunta te dice de qué tipo de red estás hablando.
3. **`docker network connect` sin reiniciar.** Conectas el `revisor` también a la interna, en caliente, y la siguiente revisión dice `OK`. `docker inspect` muestra las dos redes del `revisor` (en orden alfabético, con un espacio al final que pone la plantilla). Y `docker port` confirma que el puerto publicado sigue en `127.0.0.1` (el número del equipo se tapa, porque el guion lo recibe en `PUERTO`).
4. **Desde la red interna no hay salida.** Un ayudante en la interna intenta descargar `https://www.docker.com/` y falla antes de intentar conectarse: `wget: bad address 'www.docker.com'`, código `1`. Ni siquiera puede resolver el nombre: sin ruta hacia otras redes, la consulta no tiene a qué servidor DNS de fuera llegar. Pero la red interna no está aislada de todo: el mismo ayudante muestra su tabla de rutas, con un solo renglón (la red interna misma, sin ruta por omisión hacia fuera), y aun así su puerta de enlace contesta al `ping` (`1 packets received`). Desde la red normal, la descarga funciona. La red interna no es una promesa: hacia fuera no hay ruta, pero la puerta de enlace sigue ahí.

Una aclaración para que no te lleves una idea de más: «sin salida» no significa «inalcanzable desde tu equipo». La referencia dice que el equipo puede comunicarse directamente con las direcciones de los contenedores de una red interna. Lo que la red interna corta es el camino del contenedor hacia **otras redes**, internet incluida. Y en el otro sentido hay una rendija que conviene conocer, la que acabas de medir: la misma referencia aclara que «la comunicación con la dirección de la puerta de enlace (y, con ella, con los servicios del equipo configurados para eso) es posible». Un programa de tu equipo que escuche en `0.0.0.0` (todas las interfaces), por ejemplo una base de datos de desarrollo, queda al alcance de los contenedores de la red interna. Es otra razón para el hábito de la Lección 2: lo que corre en tu equipo escucha en `127.0.0.1`, no en todas las interfaces. Por eso el curso publica el puerto del `revisor` por la red normal, la que sí tiene camino hacia fuera, y deja la interna solo para hablar con el servicio de prueba.

#### 8.10.3 En tu carpeta: el estado final

Con tu imagen `curso-docker-revisor:1.5.0`, tu volumen `curso-docker-reportes` y la imagen `curso-docker-prueba:1.0.0` de la Lección 2, estos son los comandos del estado final, con los nombres del curso:

```bash
docker network create curso-docker-red
docker network create --internal curso-docker-interna
docker volume create curso-docker-reportes
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-revisor --network curso-docker-red -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 \
  -v curso-docker-reportes:/datos \
  -e REVISOR_SERVICIOS='prueba http://curso-docker-prueba:9000/ 2s' curso-docker-revisor:1.5.0
docker network connect curso-docker-interna curso-docker-revisor
```

(Si ya creaste el volumen en 8.4.4, el `docker volume create` solo te devuelve su nombre: no lo vacía.) Comprueba con `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` que el servicio de prueba sale `OK`, y con `docker ps --filter name=curso-docker-` que los dos llegan a `(healthy)`. El servicio de prueba lleva las mismas opciones endurecidas que el `revisor`, sin puerto y sin `-e`: es el Ejercicio 4 de la Lección 7, y ya sabes que no necesita ni un `tmpfs` porque no escribe nada. Estos dos contenedores, las dos redes y el volumen son lo que la Lección 9 escribe en un `compose.yaml`.

Cuando termines la lección, bórralos en este orden (primero los contenedores, porque una red o un volumen en uso no se borran): `docker rm -f curso-docker-revisor curso-docker-prueba` y `docker network rm curso-docker-red curso-docker-interna`. El volumen, si quieres conservar el reporte, se queda; si no, `docker volume rm curso-docker-reportes`.

### 8.11 Lo que **no** se hace: la red del anfitrión

Otra de las redes que Docker crea al instalarse es `host`. Un contenedor en ella **no tiene red propia**: según la documentación, su pila de red «no está aislada del equipo» y el contenedor «no recibe su propia dirección IP» ([Docker, controlador `host`](https://docs.docker.com/engine/network/drivers/host/)). Escucha directamente en las interfaces de tu equipo, ve todos sus puertos y todas sus conexiones locales, y `-p` deja de tener efecto: Docker lo ignora con el aviso `WARNING: Published ports are discarded when using host network mode`. Eso último anula de un golpe el hábito de la Lección 2: ya no decides si el puerto queda en `127.0.0.1` o en todas las interfaces; queda donde el programa decida escuchar.

Se usa a veces «porque así funciona» cuando un contenedor no encuentra a otro, o para ganar unos microsegundos de red. Las dos razones tienen mejor respuesta: para encontrar a otro contenedor, una red definida por el usuario; para el rendimiento, medir primero, porque casi nunca es la red del contenedor lo que limita. El README del curso lo pone como hábito de esta lección: **nunca la red del anfitrión**.

### 8.12 Lo que vas a encontrar en tutoriales viejos

- **`--link`.** La forma antigua de que un contenedor encontrara a otro por nombre en la red por omisión. La documentación ya no la recomienda: los enlaces en la red por omisión están «obsoletos y programados para eliminarse en Docker Engine 30.0», y pide usar «redes definidas por el usuario en lugar de la bandera heredada `--link`» ([Docker, enlaces heredados](https://docs.docker.com/engine/network/links/)). Si la ves, tradúcela a una red.
- **«Contenedores de solo datos» y `--volumes-from`.** Antes de que existieran los volúmenes con nombre, se creaba un contenedor que nunca corría solo para «tener» un volumen, y los demás lo montaban con `--volumes-from`. Hoy el volumen tiene nombre propio y no necesita un contenedor que lo sostenga.
- **`VOLUME /datos` en el Dockerfile «para que los datos persistan».** La instrucción existe y hace algo: marca una ruta como punto de montaje, y si al correr no montas nada ahí, Docker crea un volumen **anónimo** que se inicializa con lo que la imagen tenga en esa ruta ([referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/)). El resultado es justo lo contrario de lo que se busca: un volumen sin nombre por cada contenedor, que nadie reconoce y que se acumula. Y la instrucción no puede elegir una carpeta del equipo. Este curso no la usa: el `revisor` trae la carpeta `/datos` con su dueño, y el volumen con nombre lo decide quien corre el contenedor.
- **`chmod -R 777` sobre la carpeta de datos** para «arreglar los permisos». Ya viste en 8.3 y 8.6 que el problema es el dueño; un `777` lo esconde y abre la carpeta a cualquiera.

## El error que vas a ver

Esta lección tiene dos errores principales, uno por mitad, y tres secundarios. Todos aparecieron ya.

**El error principal de almacenamiento: el volumen nuevo que el proceso no puede escribir.** Es el de `fig08_02.sh`:

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
```

Se lee de derecha a izquierda, como el de la Lección 6. `permission denied` lo dice el núcleo: el proceso no tiene permiso de crear un archivo ahí. `open /datos/.reporte-<n>.tmp` dice qué archivo, con la ruta **dentro** del contenedor: es el temporal que el `revisor` escribe antes de renombrarlo, así que el problema es la **carpeta**, no `reporte.json`. Y `no pude guardar el reporte` lo agrega el `revisor`, que además contesta `500` en vez de fingir que todo está bien. La pregunta que lo resuelve es la de siempre: «¿quién es el dueño de la carpeta, y con qué usuario corre el proceso?». La primera respuesta te la da un ayudante (`docker run --rm -v <volumen>:/datos:ro alpine:3.24.2 ls -lnd /datos`); la segunda, `docker inspect --format '{{.Config.User}}' <contenedor>`. Si la carpeta es de `0` y el proceso es `65532`, es un volumen que nació sin una carpeta de la imagen que copiar: o la imagen no trae `/datos` (la 1.4.0), o alguien usó `volume-nocopy`. El arreglo es que la imagen traiga la carpeta con `COPY --chown` y que el volumen sea nuevo. Si el volumen ya existía, vacío y de `root`, la copia no va a ocurrir aunque cambies la imagen: bórralo (está vacío) y deja que el siguiente `docker run` lo cree.

Con un *bind mount* el mismo texto tiene otro origen: la carpeta es **tuya** y el proceso, `65532`. Arreglo: `--user "$(id -u):$(id -g)"`, o que la carpeta sea del `65532`. Lo que no es un arreglo, en ninguno de los dos casos: `--user 0` o `chmod 777`.

**El error principal de redes: el nombre que no existe.**

```text
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
```

`no such host` dice que el nombre no se pudo resolver. Lo que diagnostica el caso es **a quién se le preguntó**, justo antes del `:53`:

- **La dirección del DNS de tu equipo**: el contenedor está en la red por omisión, que no tiene DNS de contenedores. Arreglo: una red definida por el usuario para los dos.
- **`127.0.0.11`**: el contenedor sí está en una red tuya, con el DNS integrado de Docker, pero el otro contenedor no está en **ninguna de sus redes** (o se llama distinto, o no está corriendo). Arreglo: `docker network connect`, o revisar el nombre con `docker ps`.

Ese detalle convierte un mensaje genérico en un diagnóstico de un renglón.

**Los secundarios:**

```text
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe
```

Un `--mount type=bind` con una ruta del equipo que no existe (sale con `125`; la ruta del mensaje es la que escribiste). Casi siempre es un error de dedo o una ruta relativa al lugar equivocado. Con `-v` no habrías visto este error: Docker habría creado la carpeta, de `root`, y el contenedor habría arrancado con una carpeta vacía.

```text
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
```

`docker volume rm` sobre un volumen que algún contenedor, corriendo o detenido, todavía tiene montado. Borra primero el contenedor (el identificador entre corchetes te dice cuál). Lo mismo pasa con `docker network rm` y una red con contenedores conectados.

```text
wget: bad address 'www.docker.com'
```

Desde un contenedor en una red interna, cualquier nombre de fuera. Si lo ves en un contenedor que **sí** debería tener salida, revisa sus redes con `docker inspect`: probablemente solo está en una interna.

## El hábito de seguridad de la lección

**Los datos se montan con nombre, con el dueño correcto y solo donde hacen falta; las redes son tuyas, la de los servicios internos no tiene salida, y la del anfitrión no se usa.** Son tres costumbres que se escriben juntas y se comprueban juntas. La primera: el sistema de archivos sigue de solo lectura, y cada carpeta escribible tiene nombre (un volumen en `/datos`, un `tmpfs` con tamaño); ninguna se arregla con `root` ni con `777`, porque el problema es el dueño y se arregla en la imagen o con `--user`. La segunda: cada contenedor está solo en las redes que necesita; el que no necesita internet vive en una red `--internal`, y lo compruebas pidiéndole que salga (`bad address`). La tercera: nunca `--network host`, que borra de golpe el aislamiento de red y el `127.0.0.1` de la Lección 2. El accidente que evita es concreto: un servicio interno comprometido que no puede descargar nada ni mandar nada fuera, y que tampoco puede escribir más que en una carpeta que tú elegiste.

## Lo que se hace mal

**Guardar datos en la capa del contenedor.** Funciona hasta el primer `docker rm`, que en un servicio es la siguiente actualización. Y con `--read-only` ni siquiera funciona.

**Correr como `root` para que el volumen se deje escribir.** Cambia un problema de dueño por uno de seguridad, y deshace las Lecciones 3, 5 y 7. La imagen trae su carpeta con `COPY --chown`.

**`chmod 777` a una carpeta del equipo.** La abre a todos los usuarios y a todos los contenedores. El arreglo es el dueño: `--user` con tus números.

**`-v` con rutas del equipo.** Un error de dedo crea una carpeta de `root` en silencio. Para *bind mounts*, `--mount type=bind`, que por omisión se niega.

**Montar de lectura y escritura lo que el contenedor solo lee.** Configuración, secretos, certificados: `readonly`. Un *bind mount* escribible es una puerta del contenedor a tu disco.

**Volúmenes anónimos, por `VOLUME` en el Dockerfile o por `-v /datos` sin nombre.** Se acumulan sin que nadie sepa de quién son. Ponles nombre, con el prefijo del proyecto.

**Borrar volúmenes «por si acaso».** `docker volume rm` no tiene papelera. Y `docker volume prune -a` borra **todos** los volúmenes que ningún contenedor use, con nombre o sin él, incluidos los datos de proyectos detenidos que no son tuyos (sin `-a`, `prune` solo borra los anónimos, según su [referencia](https://docs.docker.com/reference/cli/docker/volume/prune/)). Borra por nombre exacto.

**Escribir direcciones IP de contenedores en la configuración.** Las reparte Docker y cambian. Usa nombres en una red definida por el usuario.

**Dejar todo en la red por omisión.** Sin nombres, y con cualquier contenedor que alguien arranque sin pensar en la misma red que los tuyos. La documentación misma la llama un detalle heredado.

**Dar internet a quien no la necesita.** Un servicio interno con salida es un trampolín. `--internal`.

**`--network host` «porque así sí funciona».** Si un contenedor no encuentra a otro, la respuesta es una red tuya, no quitar el aislamiento.

## Ejercicios

Hazlos en orden. Antes de correr cada uno, escribe en tu [bitácora](bitacora.md) lo que crees que va a pasar; compararlo después es la mitad del aprendizaje. Al terminar, borra lo que creaste: todo lleva el prefijo `curso-docker-`.

### Ejercicio 1 — ¿Volumen, *bind mount*, `tmpfs` o nada?

Para cada dato, elige uno de los cuatro y di por qué en una frase:

1. Una base de datos de prueba que un servicio usa y que debe sobrevivir a una actualización del contenedor.
2. Un archivo `config.yaml` que tú editas en tu equipo y que el contenedor solo lee.
3. Los archivos de sesión de un programa, que se regeneran en cada arranque.
4. El código fuente de un programa mientras lo desarrollas y lo pruebas en un contenedor.
5. El binario del `revisor`.
6. El reporte del `revisor`, que otra herramienta de tu equipo, fuera de Docker, va a recoger cada hora.

### Ejercicio 2 — Lee el `no such host`

Sin correr nada, di qué situación de red produjo cada mensaje y con qué comando la arreglarías. Los dos son del `revisor`, buscando a un contenedor que **sí** está corriendo:

```text
A) … lookup curso-docker-prueba on <DNS del anfitrión>:53: no such host
B) … lookup curso-docker-prueba on 127.0.0.11:53: no such host
```

Pregunta extra: en el caso B, ¿qué otras dos causas, que no tienen que ver con las redes, darían exactamente el mismo mensaje?

### Ejercicio 3 — El reporte que sobrevive (proyecto)

En tu carpeta, con el estado final de 8.10.3 corriendo, haz esta secuencia y, **antes** de cada paso, predice el resultado:

1. Pide `/api/estados` una vez.
2. Borra el contenedor del `revisor` con `docker rm -f curso-docker-revisor`.
3. Lee el reporte con un ayudante, sin ningún `revisor` corriendo.
4. Vuelve a crear el `revisor` con el comando de 8.10.3, **sin** el `docker network connect`, y pide la tabla.
5. Con ese `revisor` corriendo, intenta `docker volume rm curso-docker-reportes`.
6. Conéctalo a la interna y pide la tabla otra vez.

### Ejercicio 4 — `volume-nocopy`

Predice qué pasa si corres la imagen `curso-docker-revisor:1.5.0`, endurecida, con un volumen **nuevo** montado así:

```text
--mount type=volume,src=curso-docker-sin-copia,dst=/datos,volume-nocopy
```

¿Qué responde `/api/estados`? ¿De quién es `/datos` dentro del volumen? Compruébalo publicando el puerto en `127.0.0.1:8081` (o deteniendo antes tu `curso-docker-revisor`, que ocupa el `8080`), y di cómo se relaciona con el error de 8.3. Pregunta extra: ¿cómo se escribe lo mismo con `-v`? Al final borra el contenedor y el volumen.

## Soluciones

### Solución 1

1. **Volumen con nombre.** Debe durar más que el contenedor y nadie necesita tocar los archivos a mano. Es el caso del reporte.
2. ***Bind mount* de solo lectura.** Lo editas tú en tu equipo y el contenedor solo lo lee; con `readonly`, el contenedor no puede cambiarlo aunque quiera.
3. **`tmpfs` con tamaño.** No debe sobrevivir al contenedor, y así tampoco ocupa disco ni deja rastro.
4. ***Bind mount***. Tú lo editas y el contenedor tiene que ver el cambio en el acto. Es el uso que la documentación pone de ejemplo. (En un contenedor que solo lo ejecuta, de solo lectura.)
5. **Nada: va en la imagen.** Es código (Lección 6). Montarlo desde fuera haría que la imagen probada no fuera la que corre.
6. ***Bind mount*** **de una carpeta tuya**, con `--user` de tus números, como en 8.6. Una herramienta de tu equipo fuera de Docker necesita leerlo en una ruta tuya, sin `sudo`. Con un volumen tendría que pasar por un contenedor ayudante.

### Solución 2

- **A)** Se le preguntó al DNS de tu equipo: el `revisor` está en la **red por omisión**, que no tiene DNS de contenedores. Arreglo: crear una red (`docker network create curso-docker-red`) y correr los dos contenedores con `--network curso-docker-red`, o conectarlos a ella con `docker network connect`.
- **B)** Se le preguntó al DNS integrado (`127.0.0.11`): el `revisor` **sí** está en una red definida por el usuario, pero el servicio de prueba no está en ninguna de sus redes. Es lo que viste en el bloque 2 de `fig08_08.sh`. Arreglo: `docker network connect <la red del otro> curso-docker-revisor` (o conectar al otro a la red del `revisor`).

Pregunta extra: el mismo mensaje sale si el nombre está **mal escrito** en `REVISOR_SERVICIOS` (el DNS no adivina), o si el otro contenedor **no está corriendo**: el DNS integrado solo contesta los nombres de los contenedores conectados en ese momento. `docker ps --filter name=curso-docker-` responde las dos dudas.

### Solución 3

Los pasos 2, 5 y la primera tabla del 4 están medidos con el mismo equipo y la misma versión de Docker de la lección, en los guiones `fig08_03.sh` y `fig08_08.sh` (con el sufijo `-fig08` en los nombres); los demás se deducen de ellos, y en tu carpeta deben salir así:

1. `200`, y la tabla dice `prueba OK`.
2. El contenedor desaparece; el volumen no (bloque 4 de `fig08_03.sh`).
3. El ayudante (`docker run --rm -v curso-docker-reportes:/datos:ro alpine:3.24.2 cat /datos/reporte.json`) debe imprimir el último reporte, en JSON. En el bloque 4 de `fig08_03.sh` el servicio se llamaba `propio`; en tu estado final debe llamarse `prueba`, con `"ok": true` y `"codigo": 200`.
4. La tabla dice `FALLA` con `lookup curso-docker-prueba on 127.0.0.11:53: no such host`, como en el bloque 2 de `fig08_08.sh`: el `revisor` está en una red tuya, y el servicio de prueba, en otra.
5. `docker volume rm` se niega: `volume is in use`, con el identificador del contenedor entre corchetes, y sale con código `1` (bloque 3 de `fig08_03.sh`).
6. Después del `docker network connect`, `OK` (bloque 3 de `fig08_08.sh`).

### Solución 4

Es el guion `fig08_09.sh`, que prueba la opción con `--mount` y con `-v`:

```bash
#!/usr/bin/env bash
# fig08_09.sh — Solución del Ejercicio 4: volume-nocopy. La imagen 1.5.0 trae
# /datos de 65532, pero si el volumen nuevo se monta con volume-nocopy, Docker no
# copia nada (ni el dueño) y vuelve el permission denied. Se prueba con --mount
# y con -v, que también admite la opción, pero con OTRO nombre: nocopy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0,
# tu contenedor curso-docker-revisor ni tus volúmenes, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}sin-copia-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
probar() {  # probar OPCIÓN-DE-MONTAJE…: corre el revisor con un volumen nuevo y mira /datos
  docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO "$@" \
    -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
  curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'
  docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
  docker rm -f "$NOMBRE" >/dev/null
  docker volume rm "$VOLUMEN" >/dev/null
}

echo "== 1. Con --mount …,volume-nocopy"
probar --mount type=volume,src="$VOLUMEN",dst=/datos,volume-nocopy

echo
echo "== 2. Con -v, el nombre de --mount no sirve"
salida=$(docker run --rm -v "$VOLUMEN":/datos:volume-nocopy "$IMAGEN" version 2>&1) && rc=0 || rc=$?
echo "$salida" | sed '/^$/d'
echo "[código de salida: $rc]"
docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true

echo
echo "== 3. Con -v …:nocopy"
probar -v "$VOLUMEN":/datos:nocopy
```

```text
$ ./fig08_09.sh
== 1. Con --mount …,volume-nocopy
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
drwxr-xr-x    2 0        0             4096 Oct 21 13:11 /datos

== 2. Con -v, el nombre de --mount no sirve
docker: Error response from daemon: invalid mode: volume-nocopy
Run 'docker run --help' for more information
[código de salida: 125]

== 3. Con -v …:nocopy
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
drwxr-xr-x    2 0        0             4096 Oct 21 13:11 /datos
```

Es el error de 8.3 con la imagen buena. La imagen 1.5.0 trae `/datos` de `65532`, pero `volume-nocopy` le dice a Docker que no copie nada al volumen nuevo, y lo que no se copia incluye el dueño: el volumen nace con su carpeta de `root`, como cuando la imagen no traía la carpeta (bloque 3 de `fig08_04.sh`). La lección: el arreglo de 8.4 depende de la copia al primer montaje. Cualquier cosa que la impida (`volume-nocopy`, o un volumen que ya existía vacío y de `root`) trae de vuelta el `permission denied`.

Pregunta extra: con `-v`, la opción se escribe `nocopy` (bloque 3). El nombre de `--mount` no sirve con `-v`: Docker 29.2.1 lo rechaza con `invalid mode: volume-nocopy` y código `125`, aunque la página de volúmenes lo documente con ese nombre (bloque 2). Es un buen ejemplo de por qué el curso corre cada comando en vez de copiarlo de la documentación.

## Cómo sé que lo logré

Marca cada punto solo si puedes hacerlo **sin volver a ver el texto**:

- [ ] En tu carpeta, `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.5.0` muestra `REVISOR_REPORTE=/datos/reporte.json`, y `docker create` + `docker export` + `tar -tv --numeric-owner` muestran `datos/` con dueño `65532/65532`.
- [ ] Provocas el `permission denied` con la imagen 1.4.0 y un volumen nuevo, y lo explicas usando las palabras *dueño*, `0` y `65532`.
- [ ] El reporte sobrevive a `docker rm -f curso-docker-revisor`: lo lees con un ayudante de solo lectura.
- [ ] Explicas con un ejemplo cuándo el contenido de una carpeta se **copia** al montar y cuándo se **tapa**, y por qué `--mount` es más seguro que `-v` para un *bind mount*.
- [ ] Corres el `revisor` con un *bind mount* de una carpeta tuya y `--user "$(id -u):$(id -g)"`, y `stat` muestra que el reporte es tuyo.
- [ ] Un contenedor con `--read-only` escribe en un volumen y en un `tmpfs` con `size`, y después de `docker restart` el archivo del volumen sigue y el del `tmpfs`, no.
- [ ] Muestras el `no such host` en la red por omisión y el `OK` en una red tuya, y dices qué servidor DNS usa cada una (`/etc/resolv.conf` de un ayudante).
- [ ] El estado final de 8.10.3 está corriendo: el servicio de prueba solo en `curso-docker-interna`, el `revisor` en las dos, la tabla en `OK`, y un ayudante en la red interna recibe `bad address` al intentar salir.
- [ ] Corres los guiones de [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes) y tus salidas coinciden con las de esta lección, salvo los tiempos, las fechas, los números de usuario y grupo de tu equipo y lo que los guiones tapan a la vista. (Los guiones publican en el `8081`, así que no chocan con tu `revisor` en el `8080`.) Y al terminar, `docker ps -a --filter name=fig08`, `docker volume ls --filter name=fig08` y `docker network ls --filter name=fig08` no muestran nada.

## Resumen

Responde sin mirar la lección:

1. ¿Qué es la capa escribible de un contenedor, y qué tres problemas tiene para guardar el reporte del `revisor`?
2. ¿Qué diferencia hay entre un volumen con nombre, un *bind mount* y un `tmpfs`, en dónde viven los datos y cuánto duran?
3. ¿Por qué un volumen nuevo montado en una carpeta que la imagen no trae da `permission denied` con un usuario sin privilegios?
4. ¿Qué hace `COPY --chown=65532:65532`, y por qué el arreglo depende de que el volumen sea nuevo y vacío?
5. ¿Cuándo se copia y cuándo se tapa el contenido de una carpeta al montar algo encima?
6. ¿Qué hace `-v` y qué hace `--mount` cuando la carpeta del equipo no existe?
7. ¿Cómo arreglas el `permission denied` de un *bind mount* sin `root` y sin `777`?
8. ¿Por qué en la red por omisión un contenedor no encuentra a otro por nombre, y qué cambia en una red definida por el usuario?
9. ¿Qué es `127.0.0.11`, y qué te dice ver esa dirección en un `no such host`?
10. ¿Qué corta una red `--internal`, qué no corta, y por qué el puerto del `revisor` se publica por la otra red?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [Docker, «Storage»](https://docs.docker.com/engine/storage/): que lo escrito en la capa del contenedor no persiste y es difícil de sacar; los tipos de montaje (incluidos los montajes de imagen) y cuándo usar cada uno.
- [Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/): la copia del contenido de la imagen a un volumen vacío y la opción `volume-nocopy`; que un volumen con datos tapa lo que había; que se prefiere `--mount`; la ruta `/var/lib/docker/volumes/<nombre>/_data`; que los volúmenes sobreviven al contenedor y los anónimos se borran con `--rm`.
- [Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/): que tapan el contenido existente; que `-v` crea la carpeta y `--mount` no, por omisión, con el texto `bind source path does not exist`, y la opción `bind-create-src`; que dan acceso de escritura al equipo por omisión; la opción `readonly`.
- [Referencia de `docker volume prune`](https://docs.docker.com/reference/cli/docker/volume/prune/): que por omisión solo borra los volúmenes anónimos y que `-a` borra todos los que no estén en uso.
- [Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/): que un `tmpfs` vive en memoria y desaparece al detenerse el contenedor; que no se comparte; su tamaño máximo (50 % de la memoria) y su permiso (`1777`) por omisión; que se prefiere `--mount`; la advertencia sobre la memoria de intercambio.
- [Docker, «Networking»](https://docs.docker.com/engine/network/): el servidor DNS integrado en `127.0.0.11` y el reenvío de consultas externas; que los contenedores de la red por omisión reciben una copia del `/etc/resolv.conf` del equipo; las redes internas para servicios sin acceso externo.
- [Docker, controlador `bridge`](https://docs.docker.com/engine/network/drivers/bridge/): las diferencias entre la red por omisión y las definidas por el usuario (DNS automático, aislamiento, conectar en caliente) y que la red por omisión es un detalle heredado no recomendado para producción.
- [Referencia de `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/): la opción `--internal` y el modo interno (sin ruta por omisión, tráfico hacia otras redes descartado, la puerta de enlace alcanzable y el equipo que sí alcanza a los contenedores).
- [Docker, controlador `host`](https://docs.docker.com/engine/network/drivers/host/): que el contenedor no tiene red propia ni dirección IP y que los puertos publicados se descartan con un aviso.
- [Docker, enlaces heredados](https://docs.docker.com/engine/network/links/): que `--link` en la red por omisión está obsoleto y programado para eliminarse en Engine 30.0.
- [Referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/): `COPY --chown` y el dueño `0` por omisión; la instrucción `VOLUME` y su volumen inicializado con el contenido de la imagen.
- [Referencia de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `-v`, `--mount`, `--tmpfs`, `--network` y `--user`.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones y fechas de «Sobre las corridas».
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| ***bind mount*** | montaje de una carpeta o un archivo del equipo dentro del contenedor; el contenedor ve exactamente eso, con su dueño y sus permisos |
| **capa escribible** | la capa propia de cada contenedor, encima de las de la imagen; se borra con el contenedor |
| **contenedor ayudante** | contenedor desechable (`--rm`) que se usa para mirar un volumen o una red; aquí, `alpine:3.24.2` |
| **DNS integrado** | servidor de nombres que Docker pone en `127.0.0.11` dentro de los contenedores de las redes definidas por el usuario |
| **red definida por el usuario** | red creada con `docker network create`; da nombres por DNS y aísla de los demás contenedores |
| **red interna** | red creada con `--internal`; sus contenedores se hablan entre sí, pero no salen a otras redes ni a internet |
| **red por omisión** (`bridge`) | la red a la que Docker conecta un contenedor si no dices otra; sin nombres, solo direcciones IP |
| **`tmpfs`** | montaje que vive en memoria, con tamaño, y desaparece cuando el contenedor se detiene |
| **volumen con nombre** | almacenamiento administrado por Docker que sobrevive a los contenedores; se crea, se lista y se borra con `docker volume` |
| **volumen anónimo** | volumen sin nombre, creado por `VOLUME` o por `-v /ruta`; difícil de reconocer y fácil de olvidar |

---

**Siguiente:** [Lección 9 — Compose: el sistema completo](09-compose.md)
