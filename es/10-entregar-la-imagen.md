# Lección 10 — Entregar la imagen

Es viernes, 5:20 de la tarde. El lunes a las 9:00 empieza el curso de Kubernetes de tu equipo y el instructor quiere que cada persona lleve a su clúster **la misma imagen del `revisor`**, la que tú ya probaste. El martes le mandaste a tu compañero Tomás el comando `docker run curso-docker-revisor:1.6.0` y le funcionó. El miércoles encontraste un error pequeño, reconstruiste la imagen y la volviste a empujar con la misma etiqueta, `1.6.0`, porque «es la misma versión, solo corregí un detalle». Hoy, viernes, Tomás te escribe: «a mí el reporte me sale distinto al tuyo». Los dos tienen una imagen que se llama exactamente igual. Revisas y ninguno de los dos sabe decir cuál de las dos es la buena. Y no es lo único: la persona que cuida la seguridad del equipo pregunta tres cosas que no sabes contestar con certeza. ¿Qué lleva dentro esa imagen? ¿Con qué se construyó y de dónde salió cada pieza? ¿Tiene algún componente con una falla conocida? Son las 5:34. Tomás usa un procesador distinto al tuyo, así que ni siquiera estás seguro de que la imagen que construiste en tu equipo *sirva* en el suyo. La pregunta ya no es cómo se construye una imagen, sino **cómo se entrega una imagen para que quien la reciba sepa exactamente cuál es, qué trae, de dónde viene y en qué equipos corre**. Esta lección existe para que el lunes, en lugar de «ya te la mandé, creo que es la buena», puedas decir: «aquí está su digest, aquí su lista de materiales, aquí el escaneo de hoy, y hay un binario para cada procesador, con la prueba de que el de `amd64` arranca».

**Tiempo:** 2 × 45 min

**Qué construyes:** la entrega de la imagen del `revisor`, versión 1.6.0, en cinco movimientos. Un registro local que escucha solo en `127.0.0.1`. Un `Dockerfile` que compila el mismo binario para dos procesadores (`linux/amd64` y `linux/arm64`) sin emulación. Una publicación de esa imagen con su **lista de materiales** (SBOM) y su **procedencia**, que puedes leer con un comando. Un escaneo de vulnerabilidades con Trivy, hecho sin darle a Trivy el *socket* de Docker. Y el puente al curso siguiente: la imagen cargada en un clúster `kind` con `kind load docker-image`, y un pod que arranca sin intentar descargar nada.

**Qué aprendes:** qué es un registro y cómo se compone una referencia de imagen; la diferencia entre una **etiqueta**, que se puede mover, y un ***digest***, que no; qué es un índice de imágenes y por qué una misma etiqueta puede traer varios procesadores; las tres maneras de construir para varias plataformas y por qué aquí se usa la compilación cruzada; qué son las atestaciones, y cómo leer un SBOM y una procedencia (modos `min` y `max`, y lo que `max` expone); qué se puede esperar y qué no de un reconstruido «idéntico»; cómo traer una imagen **por digest** y correrla endurecida; cómo escanear con Trivy, qué es un umbral y por qué `UNKNOWN` también cuenta para el código de salida; cómo aceptar un hallazgo por escrito o resolverlo renovando la base; y cómo llevar la imagen a un clúster `kind` sin registro.

**De dónde vienes.** De la [Lección 9](09-compose.md) traes el sistema completo en un `compose.yaml` y el estado de la [Lección 8](08-volumenes-y-redes.md): una imagen de menos de veinte megabytes, sin shell, sin `root`, que guarda su reporte en `/datos`, carpeta que es del usuario `65532`. De la [Lección 7](07-salud-y-ciclo-de-vida.md), el endurecimiento con el que se corre (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`). De la [Lección 5](05-multi-stage.md), la costumbre de fijar la base por versión y por *digest*: hoy vas a ver qué cuesta esa costumbre y cómo se paga. De la [Lección 2](02-contenedores-dia-a-dia.md), publicar puertos solo en `127.0.0.1` y no darle el *socket* de Docker a un contenedor: ese hábito decide cómo escaneas en esta lección. Tu carpeta tiene `revisor/` con su `Dockerfile`, su `.dockerignore` y `secretos/`, y al lado `servicio-prueba/`.

**Qué no hace esta lección.** No publica nada en un registro público: ni Docker Hub, ni otro. Todo ocurre en un registro que levantas tú, en tu máquina, accesible solo desde tu máquina, y que se borra al terminar. No monta un registro de producción: eso necesita TLS y control de acceso, y la documentación del propio registro lo exige (la sección 10.1.1 lo cita). No firma imágenes: una firma criptográfica responde a la pregunta «¿quién la publicó?», y la lección se queda en las preguntas «¿cuál es?», «¿qué trae?» y «¿cómo se hizo?». No promete que una imagen escaneada sea una imagen segura: el escaneo revisa lo que sus bases de datos conocen **hoy**, y la sección 10.10 explica qué significa un «0» y qué no. No cambia el `compose.yaml` de la lección anterior, que sigue construyendo la 1.5.0: la 1.6.0 de esta lección es la imagen que se entrega al curso siguiente, y la única diferencia con la 1.5.0 es el `Dockerfile` que compila para dos procesadores. Y no despliega nada en Kubernetes: el último movimiento solo lleva la imagen hasta la puerta del clúster y comprueba que el pod arranca; el resto es el [curso de Kubernetes con kind](https://www.habil.mx/es/cursos/kubernetes/) de esta casa.

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026. Esto es lo que necesitas saber de dónde salieron, para comparar con las tuyas:

- **La máquina.** Una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4 (la misma base de Linux Mint 22, el sistema de referencia del curso), núcleo 6.8 y procesador `arm64`. Los guiones de registro, construcción y escaneo se corrieron **dentro** de esa máquina virtual, con Docker 29.2.1 (cliente y daemon), Buildx v0.31.1 y BuildKit v0.27.1. El paso de `kind` (sección 10.11) se corrió **en la Mac**, donde viven `kind` v0.33.0 y `kubectl` v1.37.1, contra el mismo daemon.
- **Las versiones del curso.** Se planeó con Docker Engine 29.8.2 (medido el 7 de octubre), y el día de las corridas la más reciente publicada era la 29.9.2, del 20 de octubre ([notas de versión](https://docs.docker.com/engine/release-notes/29/)). Una instalación de hoy trae por tanto un Buildx y un BuildKit más nuevos que los de estas corridas: si un texto de error o una versión de herramienta difiere, compáralo por su sentido, y comprueba las tuyas con `docker version` y `docker buildx version`. El escáner es **Trivy 0.76.0**, publicado el 14 de octubre de 2026 ([notas de la versión](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)); el registro es la imagen oficial `registry:3.1.2`.
- **El almacén de imágenes.** El Docker de esta máquina usa el almacén de *containerd* (`docker info` dice `Storage Driver: overlayfs` con `driver-type: io.containerd.snapshotter.v1`), del que la sección 10.1.4 explica por qué importa y cómo comprobarlo en tu equipo.
- **La emulación.** En esta máquina, **compilar con Go emulado para `amd64` no funcionó** (la sección 10.4 muestra el fallo y lo que significa), mientras que **arrancar** el binario `amd64` ya compilado sí funcionó (sección 10.9.2). En tu Mint con procesador `amd64`, la plataforma ajena sería `arm64` y puede darte otro resultado.
- **Los nombres.** Para no tocar lo tuyo, los guiones usan nombres de apoyo (el registro `curso-docker-registro-fig10`, la imagen `curso-docker-revisor:fig10`, el volumen `curso-docker-trivy-cache-fig10`, el clúster `curso-docker-puente-fig10`), construyen con una etiqueta propia y al salir borran **por nombre**, nunca por identificador; los que publican un puerto comprueban antes de arrancar que esté libre y, si no lo está (por ejemplo porque ya tienes tu registro), se detienen en vez de empujar a un registro que no es el suyo: `fig10_02.sh` comprueba el 5000 y el 8080; `fig10_04.sh`, `fig10_08.sh` y `fig10_09.sh` comprueban solo el 5000, que es el único que publican; `fig10_00.sh`, `fig10_05.sh`, `fig10_06.sh` y `fig10_07.sh` no publican ningún puerto fijo y no comprueban ninguno. Esta corrida los lanzó además con el prefijo `curso-docker-l10-` y los puertos 18100 y 18101 porque en la misma máquina trabajaban otras lecciones; una función `nombres`, a la vista en cada guion, vuelve a escribir ese prefijo como `curso-docker-` y los puertos como `5000` y `8080`. Con los valores por omisión no cambia nada. En tu carpeta, el registro se llamará `curso-docker-registro` y la imagen `curso-docker-revisor:1.6.0`.
- **Lo que cambia de una corrida a otra**, y se avisa donde aparece: los *digests* (dependen de la hora de construcción), los tiempos (un segundo, sesenta y cinco: dependen de qué había en caché), los tamaños de archivo en décimas de megabyte, las fechas de la base de datos de Trivy, las versiones de las herramientas que firman el SBOM (`syft` y BuildKit, en el campo `creators`), el número de paquetes del SBOM y los mensajes exactos de la emulación fallida.

Los programas están en [`programas/10-entregar-la-imagen/`](../programas/10-entregar-la-imagen), cada uno con su salida al lado, y `estado/` guarda los archivos del proyecto tal como quedan al terminar.

## Al terminar vas a poder

- Levantar un registro local solo en `127.0.0.1`, publicar en él una imagen y listar lo que contiene con `curl` contra su API.
- Explicar, con una medición tuya, por qué una etiqueta no identifica una imagen y un *digest* sí, y traer y correr una imagen **por digest**.
- Convertir el `Dockerfile` de la Lección 8 en uno que compila para `linux/amd64` y `linux/arm64` sin emulación, y comprobar para qué procesador quedó cada binario leyendo sus bytes.
- Publicar un índice de dos plataformas con SBOM y procedencia en modo `max`, y leer con `docker buildx imagetools inspect` los paquetes que contiene, con qué se construyó, y qué datos del constructor quedan expuestos.
- Escanear la imagen con Trivy a partir de un archivo de `docker save`, sin montar el *socket* de Docker, y leer el resultado con su umbral y su código de salida.
- Decidir un hallazgo: aceptarlo por escrito en un `.trivyignore`, con razón y fecha, o resolverlo renovando el *digest* de la base, y comprobar el resultado.
- Cargar la imagen en un clúster `kind` con `kind load docker-image` y explicar por qué el pod arranca con `imagePullPolicy: Never`.

## El porqué antes del cómo

Hasta ahora la imagen vivía donde la construías: en el almacén de imágenes de tu propio Docker. Mientras sea así, «la imagen» es un asunto entre tú y tu equipo. Entregarla es sacarla de ahí, y en cuanto sale aparecen cuatro problemas que no existían.

El primero es **el nombre que miente**. La escena del principio no es un descuido raro: es la consecuencia directa de que `curso-docker-revisor:1.6.0` sea una *etiqueta*, un letrero pegado a una imagen, y que un letrero se pueda despegar y pegar en otra. Quien recibe el nombre no recibe garantía de nada. Necesitamos una forma de referirnos a *esa* imagen y no a «la que en este momento tenga este letrero». Esa forma existe, se llama *digest*, y la vas a medir en la sección 10.3.

El segundo es **el procesador**. Una imagen contiene un binario ya compilado, y un binario compilado para `arm64` (la Mac de la escena, y muchos servidores en la nube) no corre en `amd64` (el Mint de tu compañero, y la mayoría de los servidores). La imagen de la Lección 8 se construyó para el procesador de quien la construyó, y nada más. Entregarla a otro equipo exige poder decir «aquí hay una para cada procesador, bajo el mismo nombre». Y construirla dos veces tiene su propio riesgo: si una de las dos construcciones corre emulada, puede ser lentísima o, como verás, no funcionar.

El tercero es **la caja negra**. Una imagen es un archivo que alguien te pasa y que vas a ejecutar con permisos en tu equipo y, más adelante, en un clúster compartido. Antes de ejecutarla se quiere saber qué lleva dentro (lista de materiales), de dónde salió cada pieza y con qué instrucciones se armó (procedencia), y si alguna de sus piezas tiene una falla pública conocida (escaneo). No hace falta desconfiar de nadie para pedir esas tres cosas: pedirlas es la forma normal de trabajar cuando algo va a correr donde importa.

El cuarto es **la puerta de entrada al clúster**. En el curso siguiente, el `revisor` tiene que llegar a un clúster. Un clúster no ve el almacén de imágenes de tu Docker: tiene el suyo. Hay que decidir cómo llega la imagen hasta ahí, y en un laboratorio local la respuesta es una sola línea (`kind load docker-image`), con una trampa que vas a provocar a propósito para leerla.

Que el tercer problema no es una exageración de manual lo muestra un caso público. El 1 de abril de 2021, un cliente de Codecov, un servicio de cobertura de pruebas, notó que el *script* que descargaba de la empresa para subir sus resultados no tenía la misma suma de verificación (*shasum*) que la publicada en GitHub. Avisó, y la empresa descubrió que alguien había modificado ese *script* sin autorización desde el 31 de enero: la línea alterada enviaba a un servidor ajeno el entorno completo de las máquinas de integración continua donde corría, con las credenciales que hubiera ahí. La empresa recomendó, entre otras cosas, rotar las credenciales de quien lo hubiera usado sin validar la suma ([Codecov, «Bash Uploader Security Update»](https://about.codecov.io/security-update/)). No era una imagen de contenedor, era un *script*, pero el mecanismo que lo delató es exactamente el de esta lección: **comparar la huella de lo que recibiste con la huella de lo que se publicó**. Quien comparaba la suma contra la publicada en GitHub podía detectar la alteración; el cliente que lo hizo la reportó el 1 de abril, dos meses después de que empezaran las alteraciones, y los usuarios afectados recibieron aviso el 15 de abril. Un *digest* sirve igual que esa suma, con una condición que el caso deja ver: la huella tiene que llegar por un canal distinto al de lo que se descarga. La suma de Codecov estaba en GitHub y el *script* se servía desde otro sitio. Con las imágenes pasa lo mismo: el *digest* te lo pasas tú a Tomás por tu canal, y no lo toma él del mismo registro que le sirve la imagen.

Esta lección resuelve los cuatro con herramientas que ya traes. Casi todo lo hace `docker buildx`, que viene con la instalación de la Lección 1. Un registro es un programa más, y por eso se levanta en un contenedor. El único programa nuevo es Trivy, y también corre en un contenedor, con el hábito de la Lección 2: no se le da el *socket* de Docker. Con ese destino en mente, esto es lo que vas a tener al final de la sección 10.9: la imagen publicada, tomada de vuelta **por su digest**, como lo haría una máquina que no la construyó (el guion borra antes las copias locales que dejó la construcción y lo comprueba), corriendo endurecida:

```text
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

(Es el final de `fig10_02.sh`. El contenedor se creó con la referencia `…@sha256:…`: ya no con una etiqueta.) Y esta es la meta del curso que le toca a esta lección, la sexta del README: la imagen publicada se referencia por *digest*, pasa el escaneo de Trivy con el umbral que fijaste y se carga en un clúster `kind` sin un solo error de descarga.

## Los conceptos

### 10.1 Qué es un registro y cómo se lee el nombre de una imagen

#### 10.1.1 Un registro es un servidor de imágenes

Un **registro** (en inglés *registry*) es un servicio que guarda imágenes y las entrega a quien las pide. Lo has usado sin pensarlo: cada vez que un `FROM golang:1.27.3-trixie` o un `docker pull` trajo algo de internet, un registro respondió. El servicio habla un protocolo HTTP estándar, y esa es la razón por la que esta lección puede levantar uno propio con un contenedor y hablarle con `curl`. El proyecto que lo implementa, de código abierto, se llama *Distribution*, y su imagen oficial se llama `registry`. Su documentación lo presenta con un comando de una línea para levantarlo (`docker run -d -p 5000:5000 --restart=always --name registry registry:3`) y con una advertencia que conviene leer completa: los primeros ejemplos son «apropiados solo para pruebas», y «un registro listo para producción debe estar protegido por TLS y, idealmente, usar algún mecanismo de control de acceso» ([Distribution, «Deploy a registry server»](https://distribution.github.io/distribution/about/deploying/)). Por eso en esta lección el registro vive en `127.0.0.1` y se borra al terminar. Si algún día publicas hacia otras máquinas, necesitarás TLS, y eso es un tema de infraestructura que este curso no cubre.

#### 10.1.2 Las partes de una referencia

Una **referencia** a una imagen es el texto que le dices a Docker para señalar una. Tiene hasta cuatro partes, y casi todo error de «no encuentra mi imagen» es una parte mal escrita:

```text
localhost:5000 / curso-docker-revisor : 1.6.0
   registro        repositorio         etiqueta

localhost:5000 / curso-docker-revisor @ sha256:59e431fa44c7…
   registro        repositorio         digest
```

- El **registro** es dónde está: un nombre de máquina con un puerto opcional. Si no escribes ninguno, Docker supone Docker Hub. En esta lección es siempre `localhost:5000`.
- El **repositorio** es el nombre de la imagen dentro del registro: `curso-docker-revisor`. Un repositorio guarda todas las versiones de una imagen.
- La **etiqueta** (*tag*) es un nombre legible para una versión: `1.6.0`. Es, como dice la documentación de Kubernetes, algo que puede cambiar: «las etiquetas pueden moverse para apuntar a otras imágenes, pero los *digests* son fijos» ([Kubernetes, «Images»](https://kubernetes.io/docs/concepts/containers/images/)).
- El ***digest*** es una huella del contenido, con el formato `sha256:` seguido de sesenta y cuatro caracteres hexadecimales. La misma página lo define así: «los *digests* son hashes del contenido de la imagen, y son inmutables».

Cuando una referencia trae etiqueta **y** *digest* a la vez, la página de Kubernetes es explícita sobre cuál manda: «solo se usará el *digest* para descargar». La etiqueta queda como comentario para humanos. Esa es la razón de que más adelante, en un manifiesto o en un `compose.yaml` donde importa saber qué se ejecuta, convenga escribir `repositorio:1.6.0@sha256:…`: tú lees la versión y la máquina verifica el contenido.

#### 10.1.3 Lo que un registro guarda de verdad

Antes de levantar el registro conviene saber qué le vas a mandar, porque cambia cómo se leen las salidas de la lección. Un registro no guarda «imágenes» sueltas; guarda **manifiestos** y **blobs**. Un *blob* es un archivo anónimo identificado por su *digest* (una capa comprimida, o el archivo de configuración de la imagen). Un **manifiesto** es un documento pequeño en formato JSON que lista los blobs que forman una imagen. Y por encima de los manifiestos puede haber un **índice** (*image index*): según la especificación de la Open Container Initiative, es «un manifiesto de nivel más alto que apunta a manifiestos de imagen específicos», con un campo obligatorio `manifests` que es «una lista de manifiestos para plataformas específicas», y cada entrada puede traer un objeto `platform` con la arquitectura (`architecture`, con los nombres de `GOARCH` de Go) y el sistema operativo (`os`, con los de `GOOS`) ([OCI, «Image Index»](https://github.com/opencontainers/image-spec/blob/main/image-index.md)). Dicho en la vida diaria: una **etiqueta** apunta a un **índice**; el índice dice «para `amd64` mira este manifiesto, para `arm64` mira aquel»; cada manifiesto lista sus capas. Cuando haces `docker pull` en un equipo `amd64`, Docker lee el índice, elige la entrada que corresponde a su procesador y baja solo esa. Esa estructura es la que vas a ver impresa, de verdad, en la sección 10.5.

Y hay un tercer tipo de entrada en el índice, que no es una imagen sino un *documento sobre* una imagen: las **atestaciones**. Se explican en 10.6.

#### 10.1.4 Antes de empezar: el almacén de imágenes de tu Docker

Casi todo lo que sigue (publicar un índice de dos plataformas con atestaciones, guardar una plataforma con `docker save --platform`, ver el árbol con `docker image ls --tree`) depende de un detalle de tu instalación: qué **almacén de imágenes** usa tu Docker. Docker 29 tiene dos: el clásico, con controladores como `overlay2`, y el de *containerd*. La documentación dice que el de *containerd* es el almacenamiento por omisión de Docker Engine 29.0 y posteriores **en instalaciones nuevas**, y que si vienes de una versión anterior tu daemon «sigue usando los controladores heredados (`overlay2`) hasta que actives» el de *containerd*; entre sus ventajas enumera guardar localmente imágenes de varias plataformas y trabajar con imágenes que traen atestaciones ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)). Compruébalo así:

```bash
docker info -f '{{ .DriverStatus }}'
```

En la máquina de las corridas respondió `[[driver-type io.containerd.snapshotter.v1]]` (es el bloque 1 de `fig10_00.sh`, con su salida al lado), que es lo que la documentación dice que aparece con el almacén de *containerd* activo. Si en tu equipo no aparece esa línea (verás algo con `overlay2`), la misma página indica activarlo agregando `{"features": {"containerd-snapshotter": true}}` a `/etc/docker/daemon.json` y reiniciando el daemon con `sudo systemctl restart docker`. Una advertencia honesta: esta lección **no probó** sus comandos con el almacén clásico, así que si te quedas con él, los pasos de las secciones 10.5 y 10.9 pueden fallar o dar otra salida; activa el de *containerd* antes de seguir.

### 10.2 Un registro local, solo en `127.0.0.1`

#### 10.2.1 Levantarlo

Es un contenedor como cualquiera, con el hábito de la Lección 2: el puerto se publica **solo en `127.0.0.1`**, para que nadie más en tu red pueda empujarle ni pedirle nada. La primera parte de `fig10_02.sh` hace exactamente eso, espera a que responda y le pregunta qué repositorios tiene:

```text
$ ./fig10_02.sh
== 1. Un registro local, publicado solo en 127.0.0.1
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba
$ curl -s http://127.0.0.1:5000/v2/_catalog
{"repositories":[]}
$ docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'
{"/var/lib/registry":{}}
```

Léelo renglón por renglón. `-p 127.0.0.1:5000:5000` dice «el puerto 5000 de mi máquina, solo por la dirección `127.0.0.1`, lleva al puerto 5000 del contenedor». La imagen se fija en `registry:3.1.2`, una versión concreta y no `registry:3` ni `latest`, por la misma razón que cada imagen de este curso: dentro de seis meses la etiqueta flotante traería otra cosa. El `>/dev/null` esconde el identificador largo que imprime `docker run -d`, y el `echo` confirma que el comando terminó bien. Después, `/v2/_catalog` es un punto de la API estándar de los registros que lista los repositorios, y `/v2/` a secas es la forma de preguntar «¿estás vivo y hablas el protocolo?» (los guiones lo usan para esperar a que arranque). La respuesta `{"repositories":[]}` es la de un registro recién nacido: el JSON es válido, el arreglo está vacío. No tiene nada porque todavía no le has empujado nada.

Un detalle de limpieza que conviene conocer: la imagen `registry` declara un volumen en `/var/lib/registry` (se puede comprobar con `docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'`, que responde `{"/var/lib/registry":{}}`). Como en la Lección 8 no lo nombramos, Docker crea uno **anónimo**, y un `docker rm` a secas lo deja huérfano en el disco. Por eso los guiones borran el registro con `docker rm -f -v`: la `-v` se lleva el volumen anónimo junto con el contenedor. Es el mismo tipo de basura que la Lección 2 te enseñó a no dejar.

#### 10.2.2 Publicar sin TLS, y por qué aquí se puede

Habrás notado que empujar a `localhost:5000` no pide certificados ni contraseña. Lo que **se midió** es eso: el `docker push` de la siguiente sección funciona contra `localhost:5000` sin configurar nada. ¿Por qué se puede? Porque la documentación del daemon dice que los registros locales, «cuya dirección IP cae en el rango `127.0.0.0/8`, se marcan automáticamente como inseguros» (es decir, se permiten por HTTP sin TLS), y añade que «no se recomienda depender de eso, porque puede cambiar en el futuro» ([Docker, referencia de `dockerd`](https://docs.docker.com/reference/cli/dockerd/)). Es una excepción de laboratorio, y no es una invitación a copiar la costumbre: la documentación del registro dice que sin TLS solo se debe hacer «para pruebas», y que para que el registro sea accesible desde otras máquinas hay que protegerlo con TLS primero. Un registro que escucha en `0.0.0.0` sin TLS ni autenticación es una puerta abierta a que cualquiera en tu red cambie lo que tus servidores descargan. En este curso se queda en `127.0.0.1`.

### 10.3 Etiqueta contra *digest*: la medición de la escena

#### 10.3.1 Provocar el problema del viernes

La escena del principio se puede reproducir en dos minutos, y conviene hacerlo con tus manos porque es una de esas ideas que se creen mucho más cuando se miden. El guion `fig10_02.sh` construye la imagen dos veces con la **misma etiqueta** y versiones distintas, la empuja las dos veces, y al final le pregunta al registro qué trae cada referencia. Para que esto funcione necesitas el `Dockerfile` de esta lección, que se explica en 10.4; por ahora basta saber que construye la misma imagen de la Lección 8 y que acepta `--build-arg VERSION=…`, como siempre. Los renglones que importan:

```text
== 2. Construir la 1.6.0 y publicarla con la etiqueta fig10
$ docker build -q --build-arg VERSION=1.6.0 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c"
$ curl -s http://127.0.0.1:5000/v2/_catalog; curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"repositories":["curso-docker-revisor"]}
{"name":"curso-docker-revisor","tags":["fig10"]}

== 3. Otra construcción (VERSION=1.6.1) con la MISMA etiqueta
$ docker build -q --build-arg VERSION=1.6.1 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:f60d25f0809179fefc1966ea14609f73dd6caf3db196e40db52d7b55dc7f42a1"
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["fig10"]}
```

Vamos por partes. En el bloque 2, `docker build -q` construye en silencio (la `-q` evita las decenas de renglones del proceso) y devuelve el identificador de la imagen, que el guion descarta con `>/dev/null`; si el `build` sale bien, entra el `docker push -q`, que empuja la imagen al registro y, con `-q`, solo imprime la referencia empujada. Fíjate en el `-t localhost:5000/curso-docker-revisor:fig10`: para empujar a *tu* registro, el nombre de la imagen tiene que **empezar** con la dirección del registro. Es la regla que explica casi todos los «push access denied» y «repository does not exist» de los principiantes: sin el prefijo, Docker supone que quieres empujar a Docker Hub. Después `imagetools inspect` con `--format '{{json .Manifest.Digest}}'` le pregunta al **registro** (no a tu Docker local) cuál es el *digest* de lo que hay detrás de esa etiqueta: `sha256:59e431fa…`. Y la lista de etiquetas del repositorio, `tags/list`, dice una sola: `fig10`.

En el bloque 3 se repite con `VERSION=1.6.1`. Mira la salida: **la lista de etiquetas sigue siendo una sola, `fig10`**, pero el *digest* ya no es `59e431fa…` sino `f60d25f0…`. La etiqueta se movió de una imagen a otra, sin avisar, sin error, sin ningún mensaje que alerte a nadie. El registro hizo exactamente lo que se le pidió. Lo que se perdió es la garantía que tú creías tener al decir «la 1.6.0».

#### 10.3.2 Preguntar por cada referencia

Ahora la prueba del fuego: ¿qué trae quien pide por etiqueta, y qué trae quien pide por *digest*? El bloque 4 mira qué copia local dejó la construcción (con `docker image ls`), la borra, vuelve a mirar (para que lo único que quede sea lo que dice el registro) y trae las dos:

```text
== 4. Lo que trae cada referencia
(la copia local que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
(y después de borrarla)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor:fig10 && docker run --rm localhost:5000/curso-docker-revisor:fig10 version
localhost:5000/curso-docker-revisor:fig10
1.6.1
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c && docker run --rm localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c version
localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c
1.6.0
```

La imagen trae el subcomando `version` desde la Lección 3: imprime la versión que se le grabó al compilar. Quien pidió `:fig10` recibió **1.6.1**, lo último que se empujó. Quien pidió el *digest* de la primera construcción recibió **1.6.0**, que es lo que *esa* referencia entrega, mientras exista en el registro. Los dos están sanos, ninguno está «mal»: son dos imágenes distintas y la etiqueta es un letrero que se pasó de una a la otra. Con esto, la escena del viernes tiene explicación y tiene arreglo: si tú y Tomás hubieran usado la referencia con *digest*, o si hubieras publicado cada corrección con una etiqueta nueva (`1.6.1`), no habría habido nada que discutir.

Tres matices para no sacar conclusiones de más. **Uno:** el *digest* no es «más seguro» por sí mismo. Lo que da es *inmutabilidad de referencia*: lo que pidas por *digest* o lo recibes idéntico o no lo recibes. No dice nada sobre si la imagen tiene fallas; eso es lo que revisa el escaneo. **Dos:** quien publica puede borrar un *digest* del registro; entonces el `pull` falla en vez de traer otra cosa, que es justo el comportamiento deseado. **Tres:** el *digest* de un índice es distinto al de cada manifiesto de plataforma que contiene (en este ejercicio, `imagetools inspect` mostró el de una imagen de una sola plataforma; los dos niveles se ven en 10.5). Hasta aquí solo trabajaste con una plataforma; en 10.5 vas a ver los dos niveles.

La regla práctica que sale de aquí se puede decir en una línea: **la etiqueta es para que las personas hablen; el *digest* es para que las máquinas verifiquen**. Publica una etiqueta nueva por cada construcción que vayas a entregar y no reutilices una versión ya publicada. Y cuando una máquina tenga que ejecutar exactamente lo que probaste, dale el *digest*. La documentación de buenas prácticas de Docker lo dice igual para las bases: fijar la imagen por *digest* da la garantía de que «siempre usarás la misma versión de la imagen, aunque quien la publica reemplace la etiqueta con una imagen nueva» ([Docker, «Building best practices», sección de bases fijadas](https://docs.docker.com/build/building/best-practices/)). Es lo que hizo la Lección 5 con la base del `revisor`, y hoy lo aplicas a la imagen del `revisor` misma.

### 10.4 Un solo `Dockerfile` para dos procesadores

#### 10.4.1 El problema: un binario es de un procesador

El `revisor` está escrito en Go y compila a un binario estático. «Estático» ya sabes lo que significa (Lección 5): trae todo lo que necesita y no pide librerías del sistema. Pero sigue siendo código máquina de **un** procesador. Dos familias dominan hoy: `amd64` (también llamada x86-64, la de la mayoría de los servidores y de los equipos con Linux Mint) y `arm64` (también llamada AArch64, la de las Mac con chip propio de Apple y de muchos servidores en la nube). Docker las nombra `linux/amd64` y `linux/arm64`: sistema operativo, diagonal, arquitectura. El nombre de la arquitectura es el mismo que usa Go, y es la razón por la que el siguiente `Dockerfile` puede pasar un nombre de Docker directo al compilador.

Para construir una imagen que sirva en las dos, la documentación de Docker enumera tres estrategias ([Docker, «Multi-platform builds»](https://docs.docker.com/build/building/multi-platform/)): **emulación** con QEMU; un constructor con **varios nodos nativos** (una máquina de cada arquitectura); y **compilación cruzada** (*cross-compilation*) con etapas. Sobre la primera, la misma página advierte que la emulación «puede ser mucho más lenta que las construcciones nativas», sobre todo en tareas de cómputo intensivo como compilar, y recomienda nodos nativos o compilación cruzada «si es posible». Con un compilador como el de Go, la tercera es posible y es la mejor. Ahora vas a medir por qué.

#### 10.4.2 Probar la emulación (y que no te funcione)

El guion `fig10_03.sh` toma el `Dockerfile` de la Lección 8, **sin tocarlo**, y le pide a Docker una imagen para `linux/amd64` desde una máquina `arm64`. Docker acepta: en `docker buildx inspect` aparece `linux/amd64` entre las plataformas que sabe correr, porque trae QEMU para fingir ese procesador. Esto es lo que ocurrió en esta máquina:

```text
$ ./fig10_03.sh
== 1. Este equipo y lo que su constructor sabe correr
$ uname -m
aarch64
$ docker buildx inspect | grep -E '^Platforms:'
Platforms:        linux/arm64, linux/amd64, linux/amd64/v2, linux/386

== 2. El Dockerfile de la Lección 8, para linux/amd64: todo corre emulado (QEMU)
$ docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada.log 2>&1; echo "construcción: código $?"
construcción: código 1
(tardó 0 s)
$ { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110
fatal error: fault
$ grep -E '^ERROR' emulada.log
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
(el mismo intento, dos veces más, para ver si el fallo es siempre el mismo)
$ for n in 2 3; do docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada-$n.log 2>&1; echo "intento $n: código $?"; { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada-$n.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110; done
intento 2: código 1
fatal error: found pointer to free object
intento 3: código 1
fatal error: fault
```

Léelo con calma, porque tiene dos lecciones. `uname -m` dice `aarch64`, el nombre largo de `arm64`: es una máquina `arm64`, y la lista de plataformas confirma que su constructor sabe correr cuatro, tres de ellas ajenas a su procesador (`amd64`, `amd64/v2` y `386`), gracias a la emulación. El comando de construcción lleva `--no-cache` (para que nada se reutilice de una corrida anterior) y `-o type=local,dest=salida-emulada`, que en vez de crear una imagen **deja los archivos finales en una carpeta**: aquí sirve para comprobar el resultado sin llenar el almacén de imágenes. Se pide `--platform linux/amd64`.

El resultado: la construcción **falla**, con código 1, casi al instante (el guion marcó 0 s). El mensaje es un `fatal error` del propio programa de Go, y la última línea dice dónde se disparó: en el paso `go test ./...`, el de la etapa de pruebas de la Lección 5, que al fallar con `exit code: 2` detiene todo. Para saber si es un fallo constante o una casualidad, el guion repite el intento dos veces más. Salieron **mensajes distintos** en los tres intentos de esta corrida (`fault`, `found pointer to free object` y otra vez `fault`), y en corridas anteriores del mismo guion vi otros dos, `found bad pointer in Go heap` y `wirep: already in go`, que no quedaron guardados en los archivos. Todos son mensajes que imprime el recolector de memoria o el planificador de Go cuando algo que esperaba de la máquina no ocurre: no son un error de tu `Dockerfile` ni del código del `revisor`. Lo que apunta a la emulación es que el mismo `Dockerfile`, con el mismo código, compila bien en el procesador nativo y con compilación cruzada (10.4.3). **Lo que se midió es el fallo, no su causa**, y no es una garantía de que a ti te falle: en tu Mint con `amd64` emulando `arm64` el comportamiento puede ser otro, y con otras versiones de QEMU, también. Lo que sí puedes tomar como regla es lo que dice la documentación: la emulación es la última opción, no la primera, y un fallo distinto en cada intento es la firma de una emulación que no logra reproducir bien al procesador. Dicho como condición medida y sin promesas: **en un Mac con chip de Apple, con Colima, la compilación emulada de Go para `amd64` falló en los tres intentos de la corrida guardada, y en las corridas anteriores de este mismo guion**; si te pasa algo parecido, no insistas ni busques arreglar la emulación: compila en el procesador nativo y deja que Go genere el binario de la otra plataforma (compilación cruzada), que es lo que sigue y lo que sí se midió con éxito (código 0, 65 segundos, un binario por plataforma). La documentación de Docker menciona además otra salida, un constructor con nodos nativos de cada arquitectura, que esta lección no probó.

#### 10.4.3 La compilación cruzada: tres cambios

La idea es sencilla. La compilación (que es el trabajo pesado) corre **en el procesador nativo de quien construye**, y solo el *resultado* se etiqueta para otro procesador. Para eso el `Dockerfile` cambia en tres lugares. Antes de sustituirlo, guarda el de la Lección 8 con `cp Dockerfile Dockerfile.leccion8`. Este es el archivo completo, `fig10_01.Dockerfile`, que en tu carpeta se llama `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
# arquitectura por sí mismo, así que las etapas de compilación corren en la
# plataforma de quien construye ($BUILDPLATFORM) y solo cambia el destino del binario.

FROM --platform=$BUILDPLATFORM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
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
# Las pone BuildKit solo: la plataforma para la que se está construyendo.
ARG TARGETOS TARGETARCH
# Un secreto de CONSTRUCCIÓN (por ejemplo, credenciales para módulos privados)
# se monta solo durante este RUN y no queda en ninguna capa. Este curso no usa
# módulos privados: el montaje es opcional (required=false) y queda como patrón.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    --mount=type=secret,id=netrc,target=/root/.netrc,required=false \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" \
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

Es el `Dockerfile` de la Lección 8 con **tres líneas de código distintas** (más un comentario nuevo que las explica y los comentarios de la cabecera); si comparas con `diff` los dos archivos, el código solo cambia aquí:

1. `FROM --platform=$BUILDPLATFORM golang:…`. `BUILDPLATFORM` es una variable que BuildKit define sola: la plataforma de la máquina que está construyendo (aquí, `linux/arm64`). Con esta opción la etapa de compilación **corre nativa**, sin importar para qué plataforma sea la imagen final. La documentación lo nombra junto con `TARGETPLATFORM`, `TARGETOS` y `TARGETARCH` como argumentos predefinidos de construcción ([Docker, «Multi-platform builds»](https://docs.docker.com/build/building/multi-platform/)).
2. `ARG TARGETOS TARGETARCH`. Declara, dentro de la etapa `binario`, que se quiere usar el sistema operativo y la arquitectura de **destino**. BuildKit los pone solos (`linux` y `amd64`, o `linux` y `arm64`, según la plataforma que se esté armando); declararlos con `ARG` es lo que los vuelve visibles en el `RUN`.
3. `GOOS=$TARGETOS GOARCH=$TARGETARCH` delante de `go build`. Son las variables con las que el compilador de Go decide para qué sistema y procesador genera el binario, y los nombres de arquitectura de Docker (`amd64`, `arm64`) coinciden con los de Go, igual que los de la especificación del índice de la sección 10.1.3. Con `CGO_ENABLED=0` (que ya estaba) el binario es estático y no necesita un compilador de C del otro procesador.

Y una cosa que **no** cambia, a propósito: la etapa `final` (`FROM gcr.io/distroless/…`) no lleva `--platform`. Esa etapa sí tiene que ser de la plataforma de destino, porque es la imagen que se va a entregar; BuildKit elige solo la variante correcta de la base distroless para cada plataforma, y esa base está publicada para ambas. Las dos etapas de compilación (`compilacion` y `pruebas`) corren nativas **una sola vez**, en el procesador de quien construye. Eso tiene un límite que conviene decir: las pruebas de Go validan el **código** en ese procesador; no ejecutan el binario de la otra plataforma. Para un servicio en Go puro es razonable, pero el binario `amd64` solo se verifica de verdad ejecutándolo en un `amd64`. En 10.9.2 lo ejecutas.

#### 10.4.4 Medir la compilación cruzada

El bloque 3 de `fig10_03.sh` construye con ese `Dockerfile` para **las dos plataformas** a la vez:

```text
== 3. fig10_01.Dockerfile, para las DOS plataformas: compila cruzado
$ docker buildx build --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-cruzada cruzada > cruzada.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 65 s)
$ grep -oE '\[linux/[a-z0-9>-]+ (pruebas|binario) [0-9]/[0-9]\]' cruzada.log | sort -u
[linux/arm64 binario 1/1]
[linux/arm64 pruebas 1/1]
[linux/arm64->amd64 binario 1/1]
$ ls salida-cruzada
linux_amd64
linux_arm64
$ maquina salida-cruzada/linux_amd64/revisor; maquina salida-cruzada/linux_arm64/revisor
salida-cruzada/linux_amd64/revisor: 3e 00 = x86-64 (amd64)
salida-cruzada/linux_arm64/revisor: b7 00 = AArch64 (arm64)
```

El código de salida es 0: **funcionó**, y con `--no-cache`, sin trampa. Tardó 65 segundos porque compiló desde cero (con la caché de Go de las lecciones anteriores, sería mucho menos; la sección 10.5 lo hace en segundos). Lo más interesante está en el `grep`. Los renglones que BuildKit imprime al ejecutar cada paso llevan entre corchetes **la plataforma en la que se ejecuta** el paso, y lo que se ve es: `[linux/arm64 pruebas 1/1]`, las pruebas corrieron en `arm64`, la nativa. `[linux/arm64 binario 1/1]`, el binario de `arm64` se compiló en `arm64`. Y `[linux/arm64->amd64 binario 1/1]`: el binario de **`amd64`** se compiló *en* `arm64` (la flecha dice «de aquí hacia allá»). Ningún paso de la construcción se ejecutó en `amd64`, ni siquiera emulado. Es la prueba de que el error de la sección anterior no se tuvo que resolver arreglando QEMU, sino evitándolo.

La última parte de la salida es la comprobación que importa: ¿de verdad cada archivo es para el procesador que dice? `ls` muestra una carpeta por plataforma. Y la función `maquina` del guion **lee los bytes**: una cabecera de un ejecutable de Linux (formato ELF) guarda en los bytes 18 y 19 el campo `e_machine`, que identifica el procesador de destino, y `od -An -tx1 -j18 -N2` los imprime en hexadecimal. `3e 00` es la marca de x86-64 y `b7 00` la de AArch64. Es decir, no confías en el nombre de la carpeta: miraste el interior del archivo. (Si quieres la tabla completa de códigos, está en la especificación del formato ELF; los dos que usas aquí se pueden comprobar en cualquier máquina con el comando `file` de tu Mint, que además los escribe con nombre.)

**Cuándo esta técnica no alcanza.** La compilación cruzada funciona porque Go sabe generar código para otra arquitectura sin ayuda de nadie. Si tu servicio dependiera de una librería de C (con `CGO_ENABLED=1`), o si el paso de construcción tuviera que *ejecutar* programas del procesador de destino (instalar paquetes con `apt` dentro de una base `amd64`, por ejemplo), la compilación cruzada no basta y volverías a la emulación o a los nodos nativos. Esto no es el caso del `revisor`, y es una de las razones por las que el curso eligió un servicio escrito en Go.

### 10.5 Construir para dos plataformas y publicar el índice

#### 10.5.1 El comando completo

Ya tienes el `Dockerfile` y un registro. Falta el comando que construye para las dos plataformas, adjunta la lista de materiales y la procedencia, y lo empuja todo. Es largo; se lee por piezas:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VERSION=1.6.0 \
  --sbom=true \
  --provenance=mode=max \
  -t localhost:5000/curso-docker-revisor:1.6.0 \
  --push .
```

- `docker buildx build` es el constructor moderno de Docker (BuildKit). Hoy `docker build` es un alias de `docker buildx build` ([Docker, «docker build»](https://docs.docker.com/reference/cli/docker/build-legacy/)), así que los dos hacen lo mismo; para publicar varias plataformas lo que hace falta es BuildKit y un destino que guarde índices (un registro con `--push`, o el almacén de *containerd*).
- `--platform linux/amd64,linux/arm64` pide **una imagen por plataforma**, separadas por coma.
- `--build-arg VERSION=1.6.0` es el mismo argumento de las lecciones anteriores; queda grabado en el binario y en la etiqueta `org.opencontainers.image.version`.
- `--sbom=true` agrega la **lista de materiales** (sección 10.6) y `--provenance=mode=max` la **procedencia** en su modo más detallado (sección 10.7).
- `-t …:1.6.0` es la referencia, que empieza con la dirección de tu registro, como en 10.3.
- `--push` es la diferencia que hay que entender. Cuando construyes para **una** plataforma, la imagen cae en tu almacén local. Una imagen de **varias** plataformas es un índice, y el almacén clásico de Docker no sabe guardar índices, así que históricamente `buildx` exigía mandarlas directo a un registro. Con el almacén de *containerd* (el de esta máquina, ver «Sobre las corridas») ya se pueden guardar localmente imágenes de varias plataformas y con atestaciones ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)), pero el comando de entrega hace lo que quieres de todos modos: construir y publicar en un solo paso. Una advertencia medida: con ese almacén, `--push` **también deja la imagen en tu equipo** (la sección 10.9.1 lo muestra con `docker image ls`), así que esa copia local existe y conviene no confundirla con la publicada.

La documentación de Docker describe las atestaciones así: las que adjuntas con `--sbom` y `--provenance` quedan «como un manifiesto en el índice de la imagen», y sus datos se guardan «como blobs JSON» ([Docker, «Build attestations»](https://docs.docker.com/build/metadata/attestations/)). Lo vas a ver con tus ojos en unas líneas.

El bloque 2 del guion `fig10_04.sh` lo corre y extrae de la bitácora de construcción los renglones donde BuildKit dice qué escribió:

```text
$ ./fig10_04.sh
== 1. Registro local
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba

== 2. Construir para dos plataformas, con SBOM y procedencia max, y publicar
$ docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . > ../construccion.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 1 s)
$ grep -E 'exporting (manifest|attestation manifest|manifest list) sha256' ../construccion.log | sed -E 's/^#[0-9]+ //; s/ done$//; s/ [0-9.]+s$//' | sort -u
exporting attestation manifest sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
exporting attestation manifest sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
exporting manifest list sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
exporting manifest sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
exporting manifest sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

(Aquí la etiqueta es `fig10` en vez de `1.6.0`, por los nombres de apoyo.) El código es 0 y tardó **un segundo**: ya no compiló desde cero porque la caché de Go y las capas de la construcción anterior se reutilizaron; la sección 10.4 midió los 65 segundos de la construcción en frío. El `grep` busca los renglones donde BuildKit informa lo que *exportó*, y salen cinco, que se leen así: dos **manifiestos** (uno por plataforma, `b99bf1ad…` y `959af91e…`), dos **manifiestos de atestación** (uno por plataforma también) y un **manifest list**, que es el nombre antiguo del índice y que tiene el *digest* `a4246c5f…`. La línea que te toca recordar es esa última, el índice: **es el *digest* que representa «la 1.6.0» completa**, todas las plataformas y todas las atestaciones.

#### 10.5.2 Leer el índice

Ahora el bloque 3 pregunta al registro cómo quedó la etiqueta. Es el resultado más importante de la sección:

```text
== 3. El índice que quedó en el registro
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10
Name:      localhost:5000/curso-docker-revisor:fig10
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
           
Manifests: 
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.digest: sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
    vnd.docker.reference.type:   attestation-manifest
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.type:   attestation-manifest
    vnd.docker.reference.digest: sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

Renglón por renglón. `docker buildx imagetools inspect` es la herramienta para ver, **en el registro**, lo que hay detrás de una referencia; su documentación la describe como mostrar «los detalles de una imagen en el registro» ([Docker, `buildx imagetools inspect`](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/)). Es una lectura remota: no necesita que la imagen esté en tu máquina.

- `MediaType: application/vnd.oci.image.index.v1+json` dice que lo que hay detrás de la etiqueta es un **índice** en formato OCI (el de 10.1.3), no una imagen suelta.
- `Digest: sha256:a4246c5f…` es el *digest* del índice: el mismo número del renglón `exporting manifest list` de la sección anterior. Lo que se escriba después de `@` para identificar «la 1.6.0» es esto.
- Después, `Manifests` lista **cuatro entradas**, no dos. Las dos primeras son las imágenes: `Platform: linux/amd64` con su *digest* `b99bf1ad…` y `Platform: linux/arm64` con `959af91e…`. Cada una es un manifiesto de imagen (`…image.manifest.v1+json`) con sus capas. Esos son los *digests* que Docker mira cuando, en un equipo `amd64`, resuelve la etiqueta: elige la entrada cuya plataforma coincide con la del equipo (en un `amd64`, resulta ser la primera).
- Las otras dos tienen `Platform: unknown/unknown`. No son imágenes que alguien pueda correr: son las **atestaciones**. La anotación `vnd.docker.reference.type: attestation-manifest` lo dice, y `vnd.docker.reference.digest` señala **a cuál imagen describen**. Mira que `d6939a71…` apunta a `b99bf1ad…` (la de `amd64`) y `d062f35e…` apunta a `959af91e…` (la de `arm64`): cada plataforma tiene su propio documento. Esa anotación es el hilo que une un documento con su imagen, y es lo que permite que `imagetools inspect --format '{{index .SBOM "linux/amd64"}}'` encuentre el SBOM correcto.

Una consecuencia que conviene notar ahora para entenderla en 10.9: las atestaciones **viajan dentro del índice**, no son un archivo aparte. Quien traiga la imagen por el *digest* del índice trae, o puede pedir, sus atestaciones; quien trabaje con un manifiesto de plataforma suelto, no las ve.

### 10.6 La lista de materiales (SBOM)

#### 10.6.1 Qué es y para qué sirve

Una **lista de materiales de software** (*Software Bill of Materials*, SBOM) es, según la documentación de Docker, la «lista de artefactos de software que una imagen contiene, o que se usaron para construirla» ([Docker, «Build attestations»](https://docs.docker.com/build/metadata/attestations/)). Es el equivalente a la lista de ingredientes de un empaque. Su valor aparece el día que sale una falla pública en una librería: sin lista, la pregunta «¿lo que tengo corriendo usa esa librería?» obliga a abrir cada imagen; con lista, es una búsqueda. Y es la misma lista que usan los escáneres para decidir qué revisar.

El formato que escribe `--sbom=true` en este Docker es **SPDX**, «un estándar abierto para comunicar información de listas de materiales de software» ([SPDX, «Overview»](https://spdx.dev/about/overview/)). Los dos renglones del final de la salida siguiente lo comprueban: la versión del formato y qué herramientas escribieron el documento.

#### 10.6.2 Leerla

El bloque 4 de `fig10_04.sh` pide al registro el SBOM de `linux/amd64` y lo recorre con una plantilla de Go (`--format '{{…}}'`):

```text
== 4. La lista de materiales (SBOM) de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .SBOM "linux/amd64").SPDX.packages}}{{.name}} {{.versionInfo}}{{println}}{{end}}' | sort
base-files 13.8+deb13u7
ca-certificates 20250419
github.com/habil/revisor UNKNOWN
media-types 13.0.0
netbase 6.5
sbom <no value>
stdlib go1.27.3
tzdata 2026c-0+deb13u1
tzdata-legacy 2026c-0+deb13u1
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .SBOM "linux/amd64").SPDX.spdxVersion}} {{(index .SBOM "linux/amd64").SPDX.creationInfo.creators}}'; echo
SPDX-2.3 [Organization: Anchore, Inc Tool: syft-v1.51.0 Tool: buildkit-v0.27.1]
```

La plantilla: `.SBOM` es el mapa de SBOMs por plataforma; `index .SBOM "linux/amd64"` toma el de esa plataforma (la documentación del comando explica que `index` sirve justamente para elegir una plataforma en imágenes multiplataforma); `.SPDX.packages` es la lista de paquetes del documento SPDX; y `{{.name}} {{.versionInfo}}` imprime el nombre y la versión de cada uno, un paquete por renglón. El `| sort` los ordena. Son **nueve** renglones, y cada uno cuenta una historia de la imagen:

- `base-files`, `media-types`, `netbase`, `tzdata`, `tzdata-legacy` y `ca-certificates` son los paquetes de Debian que trae la base distroless. Algunas versiones llevan el sufijo `+deb13u7`, que es la revisión de ese paquete en Debian 13. `tzdata` es la base de datos de zonas horarias (`2026c`); `ca-certificates` es la lista de autoridades de confianza que permite a un programa verificar certificados HTTPS (el `revisor` la necesita para consultar servicios por `https`). Sin shell ni gestor de paquetes, lo poco que hay en la imagen es esto. Fíjate en la versión de `ca-certificates`: `20250419`. Vas a volver a ella en 10.10.
- `stdlib go1.27.3` es la biblioteca estándar de Go con la que se compiló el binario. No es un paquete de Debian sino lo que el lenguaje deja dentro de cada programa que genera: por eso la versión del compilador (la de la etapa `golang:1.27.3-trixie`) aparece en la lista, y por eso un escáner puede decir «esta imagen trae Go 1.27.3» sin ejecutarla.
- `github.com/habil/revisor UNKNOWN` es el propio programa: su módulo de Go, con versión `UNKNOWN` (el escáner no encontró una versión que leer; la lección no investigó por qué).
- `sbom <no value>` es un renglón raro, y vale la pena decirlo en voz alta: no se ve como un paquete de la imagen: es un elemento sin versión que el generador agrega al documento (la lección no investigó su origen), y la plantilla imprime `<no value>` cuando el campo falta. Lo dejamos en la salida a propósito para que no te asuste cuando lo veas.

Y el último comando responde a la pregunta «¿quién escribió esto?»: formato `SPDX-2.3`, hecho por **Syft** (de Anchore, versión 1.51.0) a través de BuildKit v0.27.1. No lo escribió tu `Dockerfile` ni lo tecleó nadie: BuildKit lanza un escáner de contenido *dentro* de la construcción (en la procedencia de la sección siguiente lo vas a ver como un «material» más, `buildkit-syft-scanner`), lee la imagen terminada y anota lo que reconoce. Eso tiene un límite que conviene saber: **un SBOM generado así describe lo que el escáner reconoce**, y reconoce paquetes de sistema y módulos de lenguajes conocidos. Un archivo que copiaste a mano a la imagen sin que ningún gestor de paquetes lo registre no aparece. La lista es un buen inventario, no una prueba de que no hay nada más.

### 10.7 La procedencia: con qué se construyó

#### 10.7.1 Qué es

El SBOM dice **qué** hay dentro. La **procedencia** (*provenance*) dice **cómo se hizo**. El estándar SLSA la define como «información verificable sobre artefactos de software que describe dónde, cuándo y cómo se produjo algo» ([SLSA, «Provenance»](https://slsa.dev/spec/v1.0/provenance)). Para una imagen de Docker, eso incluye: qué constructor la armó, para qué plataforma, qué imágenes base usó (con su *digest*), qué argumentos recibió, y a qué hora empezó y terminó.

#### 10.7.2 Leerla

El bloque 5 pide tres cosas de la procedencia de `linux/amd64`:

```text
== 5. La procedencia de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format 'tipo: {{(index .Provenance "linux/amd64").SLSA.buildType}}{{println}}construida EN: {{(index .Provenance "linux/amd64").SLSA.invocation.environment.platform}}'; echo
tipo: https://mobyproject.org/buildkit@v1
construida EN: linux/arm64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .Provenance "linux/amd64").SLSA.materials}}{{.uri}}{{println}}{{end}}' | cut -c1-100
pkg:docker/docker/buildkit-syft-scanner@stable-1?platform=linux%2Farm64
pkg:docker/docker/dockerfile@1
pkg:docker/golang@1.27.3-trixie?digest=sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965
pkg:docker/gcr.io/distroless/static-debian13@nonroot?digest=sha256:516757106de35205efb70b91ba03f6f12
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json (index .Provenance "linux/amd64").SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
```

- `tipo: https://mobyproject.org/buildkit@v1` es el tipo de construcción: «esto lo armó BuildKit, en el formato de procedencia que BuildKit define». Es solo un identificador.
- `construida EN: linux/arm64` es **un segundo testimonio de la compilación cruzada**: lo escribió BuildKit, no tú. Es una declaración del constructor, sin firma: confirma lo que ya mediste, pero no sustituye una verificación independiente. Pediste la procedencia de la imagen `linux/amd64` y el documento dice que se construyó *en* `linux/arm64`. Es exactamente lo que midió la sección 10.4: la imagen de `amd64` se construyó en una máquina `arm64`, sin emular.
- Los **materiales** son todo lo que entró a la construcción, con su identificador de paquete (`pkg:docker/…`, en formato *purl*, un estándar para nombrar paquetes) y, cuando hay, su *digest*. Aparecen cuatro: el escáner de SBOM (`buildkit-syft-scanner`), el frontend de Dockerfile (`dockerfile@1`, que es lo que pedía la primera línea `# syntax=docker/dockerfile:1`), la imagen de compilación (`golang@1.27.3-trixie`, con el *digest* `604106…` que fijó la Lección 5) y la base final (`gcr.io/distroless/static-debian13@nonroot`, con `516757…`). Los `cut -c1-100` del comando recortan los renglones para que quepan; el *digest* completo está en el documento. Esos dos *digests* son los de tu `Dockerfile`: la procedencia es una segunda lectura, escrita por BuildKit, de que lo que se usó fue lo que se fijó (sin firma: cualquiera con permiso de empujar al registro podría adjuntar otra).
- Los argumentos (`args`) son lo que recibió el constructor: `build-arg:VERSION: 1.6.0`, el comando de frontend y su fuente.

Una precisión sobre los nombres de campo que acabas de leer (`invocation`, `materials`, `metadata`): Docker escribe por omisión la procedencia en la versión 0.2 del esquema SLSA, y la 1.0 se activa con `version=v1` (por ejemplo, `--provenance=mode=max,version=v1`) ([Docker, «SLSA provenance»](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). Con `version=v1` los campos cambian de lugar y las plantillas de esta sección no funcionarían tal cual; esta lección no la midió.

#### 10.7.3 `min` contra `max`: la advertencia

Pusimos `--provenance=mode=max`. Hay dos modos, y la diferencia no es de gusto. La documentación dice que `min` es el que se agrega **por omisión** a las imágenes, que incluye «marcas de tiempo, el frontend, los materiales, el repositorio y la revisión de la fuente, la plataforma de construcción y reproducibilidad», y que «los valores de los argumentos de construcción, las identidades de los secretos y los metadatos ricos de capas **no** se incluyen en `mode=min`», por lo que «es seguro para todas las construcciones». El modo `max` «incluye todo lo de `min`» y agrega la definición interna de la construcción (LLB), **una copia del Dockerfile codificada en base64** y mapas de fuente que enlazan pasos con capas. Y trae una advertencia que hay que leer entera: `max` **expone los valores de los argumentos de construcción**; si estás pasando credenciales como `--build-arg`, hay que reescribir la construcción para usar montajes de secretos, porque «los montajes de secretos no se filtran fuera de la construcción y nunca se incluyen en las atestaciones de procedencia» ([Docker, «SLSA provenance»](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)).

Es el tipo de advertencia que se cree más cuando se ve. El bloque 6 construye la imagen de `arm64` dos veces, una en cada modo, **pasándole a propósito un argumento que el `Dockerfile` ni siquiera declara**: `NOTA=curso-docker-nota-de-mentira`. El nombre dice que es de mentira: es un texto inventado para el ejercicio, y es lo que representaría cualquier valor que alguien pase por error en un `--build-arg`. Las dos construcciones son idénticas salvo el modo de procedencia (el guion las repite en un ciclo con `mode=min` y `mode=max`):

```bash
docker buildx build -q --platform linux/arm64 \
  --build-arg VERSION=1.6.0 --build-arg NOTA=curso-docker-nota-de-mentira \
  --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10-max --push .
```

Después le pregunta al registro qué guardó cada una:

```text
== 6. Modo min contra modo max, con un argumento que el Dockerfile ni declara
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: (no aparecen)
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:NOTA": "curso-docker-nota-de-mentira",
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildConfig', 'buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: [{'id': 'netrc', 'optional': True}]
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys,base64; d=json.load(sys.stdin); i=d["metadata"]["https://mobyproject.org/buildkit@v1#metadata"]["source"]["infos"][0]; print(i["filename"]); print("\n".join(base64.b64decode(i["data"]).decode().splitlines()[:3]))'
Dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
```

Lo que se ve, comparando:

1. **Los argumentos.** En `min` solo están `cmdline` y `source`: **ni `VERSION` ni `NOTA`**. En `max` aparecen los dos con su valor, incluida la «nota de mentira». Eso es lo que la advertencia describe: lo que alguien pase por `--build-arg` queda escrito, legible, en un documento que viaja con la imagen y que cualquiera que pueda traer la imagen puede leer. Si esa nota hubiera sido un token, el token estaría ahí.
2. **Los campos.** `min` tiene cinco campos (`buildType`, `builder`, `invocation`, `materials`, `metadata`); `max` agrega `buildConfig`, que es la definición interna de los pasos.
3. **Los secretos.** En `min`, `(no aparecen)`: no hay ni su identidad. En `max` aparece `[{'id': 'netrc', 'optional': True}]`: el **nombre** del secreto de construcción (`--mount=type=secret,id=netrc`) y que es opcional (`required=false`, recuerda el `Dockerfile`), **pero no su contenido**. Es el comportamiento que promete la documentación: el montaje de secretos no filtra el valor; sí deja constancia de que el construido pidió un secreto llamado así.
4. **El `Dockerfile` completo.** El último comando decodifica la copia en base64 que `max` guarda y muestra sus primeros renglones: es el `Dockerfile` que se usó, con sus comentarios, a la vista de cualquiera. Si tu `Dockerfile` tuviera un comentario con algo que no debe saberse, saldría aquí.

La decisión que se desprende y que el curso adopta: **se publica con `mode=max` porque la procedencia completa es lo que hace útil la entrega, y se mantiene limpio el origen**: ningún secreto pasa por `ARG`, ni por `ENV`, ni por `--build-arg` (el hábito de la Lección 6), y cuando la construcción necesita uno, entra por `--mount=type=secret`. Con eso `max` no expone secretos, pero sí publica el `Dockerfile` completo y los valores de todos los `--build-arg`: revisa ambos antes de publicar. Si trabajas en un equipo donde no puedes garantizarlo, `min` es el modo seguro, y la propia documentación lo dice. Lo que **no** es aceptable es usar `max` sin saber que existe esa diferencia.

### 10.8 «Idéntica» no es «igual»: qué cambia al reconstruir

Una pregunta natural después de hablar de *digests*: si construyo dos veces la misma versión, con el mismo `Dockerfile` y el mismo código, ¿obtengo el mismo *digest*? Esperarías que sí. Lo que se mide es otra cosa, y conviene saberlo antes de prometerle a nadie «reproducibilidad». El bloque 7 reconstruye idéntico (con caché) y compara:

```text
== 7. Otra construcción idéntica: ¿qué digest cambia?
$ docker buildx build -q --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
antes:   índice sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:04c19cbec864dd3ff9ccf5d71d676244acecd31ae1e1d9c363006bfac903c571"
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
arm64 sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .Provenance "linux/amd64").SLSA.metadata.buildStartedOn}}'; echo
2026-10-21T18:18:15.739444508-06:00
```

El *digest* del **índice** cambió: de `a4246c5f…` a `04c19cbe…`. Pero los de **cada plataforma** (con `--raw`, el JSON crudo del índice, filtrado a las entradas de Linux) son **los mismos**: `b99bf1ad…` para `amd64` y `959af91e…` para `arm64`. ¿Por qué cambió el del índice? Porque el índice incluye, entre sus entradas, las atestaciones, y la procedencia lleva dentro la hora en que empezó la construcción (el último comando la muestra: `buildStartedOn`). Otra hora, otro documento de procedencia, otro *digest* de atestación, otro índice. Las imágenes en sí no cambiaron ni un bit. Consecuencia práctica: **dos entregas de lo mismo pueden tener índices distintos**, y si fijas por el *digest* del índice, fijas también esa hora. Es lo correcto (identifica *esta* entrega), pero no es lo que mucha gente imagina al leer «el *digest* es la huella del contenido».

El bloque 8 repite la construcción con `--no-cache`, que obliga a rehacer cada paso:

```text
== 8. Y otra más, ahora SIN caché (--no-cache): ¿siguen iguales los de cada plataforma?
$ docker buildx build -q --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:37dd082fe87a0b2779067a9098dab82e3c7d53e9924fa668d41638d8602dccfd
arm64 sha256:d9875545824d329af2bc6c206f52acc80145926a0cff399591bc1b4d6876e0c3
```

Ahora **también** cambiaron los de cada plataforma (`37dd082f…` y `d9875545…`). Sin caché, nada se reutiliza, y la imagen resultante tiene un *digest* distinto aunque el código, el `Dockerfile` y la versión sean los mismos. **Lo que se midió es el hecho; la causa no se investigó** (lo más probable es alguna marca de tiempo guardada en la configuración o en las capas, pero esta lección no lo verificó, y no vas a leerlo como un dato). La lección práctica es sobria: **no se le promete a nadie que reconstruir devuelve el mismo *digest***. Lo que se promete es lo contrario y más útil: *este* digest, una vez publicado, identifica *esa* imagen mientras exista en el registro. Si la fuente tiene que ser reproducible bit a bit, eso es otro tema (el de las construcciones reproducibles), que esta lección no resuelve ni promete.

### 10.9 Traerla por *digest* y correrla como se debe

#### 10.9.1 Como en un equipo que nunca la construyó

Publicar no sirve de nada si no compruebas que la imagen se puede *recibir*. La prueba honesta se hace como si fueras Tomás: una máquina que no tiene la imagen, que solo conoce el registro y un *digest*. (Un aviso para no confundir los números: los *digests* de `fig10_02.sh`, de una sola plataforma, y los de `fig10_04.sh`, un índice de dos, son de imágenes distintas y por eso no coinciden.) En el bloque 9 de `fig10_04.sh`, antes de bajar nada, el guion **borra las copias locales** que dejó la construcción (con el almacén de *containerd*, aun con `--push` la imagen se queda también en tu equipo) y lo comprueba con `docker image ls` antes y después, para que lo único que exista sea lo que dice el registro. Después se trae por *digest*:

```text
== 9. Traerla por digest, no por etiqueta
(copias locales de localhost:5000/curso-docker-revisor que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10-min
localhost:5000/curso-docker-revisor:fig10-max
(y después de borrarlas)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker run --rm localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version
1.6.0
$ docker image inspect --format '{{json .RepoDigests}}' localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52; echo
["localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52"]
```

(El *digest* de este bloque es el del índice que quedó en el registro tras la última construcción del guion; cambia en cada corrida.) El `docker pull -q` con `@sha256:…` descargó **solo lo que corresponde a este procesador**. `docker run … version` imprime `1.6.0`: la versión que se grabó al compilar. Y `RepoDigests` es el campo de una imagen local que guarda **de qué registro y con qué *digest* vino**: es la constancia de que la copia local no es una construcción propia sino una descarga, y es lo que permite, meses después, preguntar «¿esto que corre de dónde salió?».

Conviene decir qué se espera que ocurra aquí aunque la salida no lo imprima. La especificación de distribución de la Open Container Initiative, el documento que define cómo hablan los clientes con los registros, dice que los clientes «DEBERÍAN verificar que el cuerpo de la respuesta coincide con el *digest* pedido» (en el original, «SHOULD verify that the response body matches the requested digest»; [OCI, «Distribution Specification»](https://github.com/opencontainers/distribution-spec/blob/main/spec.md)). Es una recomendación a los clientes y esta lección no la midió con una imagen alterada a propósito; lo que sí tienes es la regla práctica: pedir por *digest* es pedir algo que se puede comprobar, y una referencia con *digest* que no coincide debe ser un fallo y no «otra imagen».

#### 10.9.2 Lo que bajó, y lo que no

El bloque 10 enseña algo que sorprende la primera vez: de las dos plataformas del índice, tu equipo bajó una.

```text
== 10. Lo que bajó a este equipo: solo su plataforma
$ docker image ls --tree localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 2>/dev/null | sed -E 's/@sha256:([0-9a-f]{12})[0-9a-f]+/@sha256:\1…/'
IMAGE                                                                                                              ID             DISK USAGE   CONTENT SIZE   EXTRA
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8…   6956d5334dc8       16.8MB         4.34MB        
├─ linux/amd64                                                                                                     37dd082fe87a           0B             0B        
└─ linux/arm64                                                                                                     d9875545824d       16.2MB         3.68MB        

$ docker save --platform linux/arm64 -o ../propia.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/arm64'
guardada: linux/arm64
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
Error response from daemon: no suitable export target found: image with reference localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 was found but does not provide the specified platform (linux/amd64)
[código de salida: 1]
```

Y el bloque 11, que trae la otra plataforma y prueba a correrla:

```text
== 11. Traer la OTRA plataforma, guardarla y probar a correrla (linux/amd64)
$ docker pull -q --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/amd64'
guardada: linux/amd64
$ docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version 2>&1 | head -3
1.6.0
```

`docker image ls --tree` es la vista que muestra el índice y sus plataformas. Se lee así: arriba, la referencia con el *digest* del índice; debajo, una fila por plataforma con su propio identificador. La columna `DISK USAGE` da la clave: `linux/arm64` ocupa **16.2 MB** en disco (la imagen del `revisor`: el mismo tamaño que midieron las lecciones 8 y 9, 16.2 MB) y `linux/amd64` ocupa `0B`. Está en la lista porque el índice la menciona, pero **sus capas no se bajaron**. Es eficiente (nadie descarga lo que no va a ejecutar), y tiene una consecuencia práctica que el último comando provoca a propósito: `docker save --platform linux/arm64` funciona, y `docker save --platform linux/amd64` falla con `no suitable export target found … does not provide the specified platform`. La documentación de `docker image save` dice exactamente eso: `--platform` guarda solo las plataformas indicadas, y «se produce un error si la plataforma dada no está presente en el almacén de imágenes local» ([Docker, `docker image save`](https://docs.docker.com/reference/cli/docker/image/save/)). La moraleja del error: **si necesitas el archivo de la otra plataforma, tienes que traerla primero**; guardar no la descarga. El bloque 11 lo hace, y de paso responde la pregunta que dejó abierta la sección 10.4: ¿el binario de la otra plataforma arranca de verdad?

El bloque 11 de la salida de arriba lee así. `docker pull -q --platform linux/amd64 …@sha256:…` baja las capas de la plataforma que faltaba (la referencia es la misma; `--platform` elige la entrada del índice). Con ella en el almacén, el mismo `docker save --platform linux/amd64` que había fallado ahora responde `guardada: linux/amd64`. Y el último comando, `docker run --rm --platform linux/amd64 … version`, imprime `1.6.0`: **el binario de `amd64` arrancó y contestó**. Hay que decir en qué condiciones se midió, para no prometer de más: esta máquina es `arm64`, así que ese binario corrió **emulado** por QEMU; es una prueba de que el archivo es un ejecutable `amd64` válido que arranca, no una prueba de cómo se comporta en un `amd64` real, y arrancar un binario estático pequeño es una exigencia mucho menor que compilar con Go (que fue lo que la emulación no aguantó en 10.4.2).

**Si tu equipo es `amd64` (como tu Mint), esta es la comprobación que te toca a ti**, y es la que de verdad cuenta: el mismo comando, `docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:… version`, ahora corre nativo. Si tu equipo es `arm64`, la plataforma «de la otra» es `linux/amd64` y la salida de arriba es la que debes obtener. En los dos casos el resultado esperado es `1.6.0`.

Esto importa de inmediato, porque el escaneo de la siguiente sección se hace sobre un `docker save`, y escanea **una** plataforma. Un índice de dos plataformas se escanea en dos pasadas. En esta lección el guion escanea la de tu propio procesador, y esa limitación se dice en voz alta en 10.10.

#### 10.9.3 Correrla endurecida: montar `/datos` otra vez

La imagen de la Lección 8 guarda su reporte en `/datos`, y desde la Lección 7 se corre con `--read-only`: el sistema de archivos del contenedor es de solo lectura. Eso tiene una consecuencia que ya mediste en la Lección 8 y que aquí se vuelve a ver, con la imagen **traída por *digest***, como la recibiría otra persona: si no montas nada en `/datos`, el `revisor` sano no puede guardar su reporte. El bloque 5 de `fig10_02.sh` corre la imagen con todas las medidas y **sin volumen**:

```text
== 5. La de digest, endurecida como en la Lección 8: sin nada en /datos
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

El primer comando crea el contenedor con las medidas de las lecciones 7 y 8 (`--read-only`, `--cap-drop ALL`, `--security-opt no-new-privileges`, `--init`) y la referencia **por *digest***; el `>/dev/null && echo` solo esconde el identificador y confirma que terminó bien. Luego, `/salud` contesta `vivo` y `1.6.0`: el proceso arrancó y la imagen es la que pediste. Después, `/api/estados` contesta `500` con un mensaje que se lee de derecha a izquierda, como en las lecciones 6 y 8: `read-only file system` lo dice el núcleo (no se puede escribir ahí), `open /datos/.reporte-<n>.tmp` dice qué archivo (el temporal que el `revisor` escribe antes de renombrarlo) y `no pude guardar el reporte` lo agrega el `revisor`, que prefiere contestar `500` a fingir que todo salió bien. No es un defecto de la imagen entregada: es el sistema de solo lectura funcionando como se pidió. El arreglo es el de siempre, **montar algo escribible en `/datos`**:

```text
== 6. La misma, con un volumen en /datos (un contenedor no recibe un volumen después: se borra y se crea otro)
$ docker rm -f curso-docker-revisor-fig10 >/dev/null && echo 'contenedor anterior borrado'
contenedor anterior borrado
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -v curso-docker-reportes-fig10:/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

Un contenedor no puede recibir un volumen después de creado: por eso el bloque 6 empieza borrando el anterior (`docker rm -f`) y crea otro con la misma receta más `-v curso-docker-reportes-fig10:/datos` (el volumen de apoyo del guion; en tu carpeta: `--name curso-docker-revisor` y `-v curso-docker-reportes:/datos`, el volumen de la Lección 8). Esta vez `/api/estados` responde `200`. Y el último renglón es el cierre de lo que prometía la sección «El porqué antes del cómo»: `docker inspect` dice que el contenedor se creó **con una referencia por *digest***. Nada en su historia depende de que una etiqueta siga apuntando donde apuntaba. Recuerda que el volumen nuevo hereda el dueño `65532` de la carpeta que la imagen trae (Lección 8); por eso aquí no hace falta `--user` ni `chmod`.

Una observación sobre `-e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud'`: es el servicio que el `revisor` consulta. Aquí es **él mismo**, a su propio `/salud`, para que la prueba no dependa de ningún otro contenedor. Es una forma de probar la imagen aislada, y el mismo que usa el pod de `kind` de la sección 10.11.

### 10.10 Escanear lo que se entrega con Trivy

#### 10.10.1 Qué hace un escáner, y qué no

Un **escáner de vulnerabilidades** toma la lista de lo que hay dentro de una imagen (paquetes del sistema, módulos de lenguaje, el propio binario de Go) y la compara con **bases de datos de fallas conocidas**. Cada falla pública tiene un identificador (un número CVE, o el de la distribución, como los *DSA* de Debian), una gravedad y, a veces, una versión corregida. **Trivy** es un escáner de código abierto, hecho por Aqua Security, que corre como un programa de línea de comandos, y aquí lo usas desde su imagen oficial `aquasec/trivy:0.76.0`, publicada el 14 de octubre de 2026 ([notas de la versión 0.76.0](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)).

Dos advertencias de entrada. La primera: **un escáner contesta «¿qué problemas *conocidos* tiene esto *hoy*?»**. No contesta «¿es seguro?». Un resultado de cero hallazgos significa «ninguna falla de las que mi base de datos conoce, hoy, en los paquetes que reconocí»; mañana puede dejar de ser cero sin que la imagen cambie, porque se publicará una falla nueva. La segunda: la calidad del resultado depende de la frescura de su base de datos, y por eso el bloque 6 de `fig10_05.sh` la mide.

#### 10.10.2 El error: pedirle la imagen por su nombre

Para este ejercicio parte de una imagen local con nombre sencillo: el bloque 1 de `fig10_05.sh` la construye con `docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 .` (en tu carpeta, `curso-docker-revisor:1.6.0`), y `docker image ls` confirma sus 16.2 MB. El primer instinto es el comando corto: `trivy image mi-imagen`. Como Trivy corre dentro de un contenedor, y la imagen está en tu Docker, no la encuentra. Sale un error largo con una lección valiosa. El bloque 2 de `fig10_05.sh` lo provoca y lo filtra:

```text
== 2. El error: pedirle a Trivy la imagen por su nombre, sin socket
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 image --quiet curso-docker-revisor:fig10 2>&1 | grep -oE 'unable to find the specified image.*|^\s+\* [a-z]+ error: .*' | cut -c1-120
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]: 4 erro
	* docker error: unable to inspect the image (curso-docker-revisor:fig10): failed to connect to the docker API at un
	* containerd error: containerd socket not found: /run/containerd/containerd.sock
	* podman error: unable to initialize Podman client: no podman socket found: stat podman/podman.sock: no such file or di
	* remote error: GET https://index.docker.io/v2/library/curso-docker-revisor/manifests/fig10: UNAUTHORIZED: authenti
[código de salida: 1]
```

Lectura. El comando monta un volumen (`-v curso-docker-trivy-cache-fig10:/root/.cache`) donde Trivy guarda su base de datos para no bajarla en cada ejecución, y lanza `image --quiet curso-docker-revisor:fig10`. El `grep -oE` conserva solo el renglón del error principal y los cuatro intentos fallidos; el `cut` recorta cada uno a 120 caracteres. El mensaje dice que Trivy **buscó la imagen en cuatro lugares**, en este orden: `docker` (hablando con el daemon por su *socket*), `containerd`, `podman` y `remote` (un registro). Es el mismo orden que documenta Trivy: busca «primero en el motor de Docker local, luego en *containerd*, *podman* y, al final, en un registro de contenedores» ([Trivy, «Container Image»](https://trivy.dev/latest/docs/target/container_image/)). En cada uno falló: el *socket* de Docker no está dentro del contenedor (`failed to connect to the docker API`), no hay `containerd` ni `podman`, y como último recurso intentó bajar `curso-docker-revisor` de Docker Hub, donde no existe (`UNAUTHORIZED`).

El arreglo «de tutorial» para el primer error es montar el *socket* de Docker dentro del contenedor de Trivy (`-v /var/run/docker.sock:/var/run/docker.sock`). **No lo hagas.** Es lo que la Lección 2 te enseñó a no hacer: quien tiene el *socket* de Docker controla Docker, y por lo tanto controla tu máquina con los permisos de `root`. Dárselo a un contenedor para que «lea» una imagen es darle la llave de todo a un programa que, además, descarga datos de internet cada vez que corre. El camino correcto da el mismo resultado sin darle nada: **guardar la imagen en un archivo, y darle a Trivy el archivo**.

#### 10.10.3 Guardar y escanear el archivo

Trivy acepta imágenes guardadas: su documentación lo dice, con el ejemplo de `docker save` seguido de `trivy image --input archivo.tar` ([Trivy, «Container Image»](https://trivy.dev/latest/docs/target/container_image/)), y la referencia del comando describe `--input` como la «ruta de un archivo de entrada en vez de un nombre de imagen» ([Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)). El bloque 3 hace las dos cosas:

```text
== 3. Guardar la imagen en un archivo y escanear el archivo
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --severity HIGH,CRITICAL --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#'

Report Summary

┌──────────────────────────────────────────┬──────────┬─────────────────┬─────────┐
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ revisor                                  │ gobinary │        0        │    -    │
└──────────────────────────────────────────┴──────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)
```

El primer comando guarda la imagen en un archivo `.tar` de 3.6 MB, **solo de tu plataforma** (`--platform linux/arm64`; en tu Mint sería `linux/amd64`). Los 3.6 MB son la imagen comprimida; los 16.2 MB que mostraba `docker image ls` son descomprimidos. El segundo comando, con piezas:

- `docker run --rm` lanza Trivy y lo borra al terminar; `-v curso-docker-trivy-cache-fig10:/root/.cache` es la caché de la base de datos (en tu carpeta, `-v curso-docker-trivy-cache:/root/.cache`), en un **volumen con nombre** para que sobreviva entre corridas y se pueda borrar al final.
- `-v "$PWD":/trabajo:ro` monta tu carpeta actual en `/trabajo`, **solo lectura** (`:ro`): Trivy puede leer el `.tar`, no escribir en tu carpeta. Es el mínimo privilegio aplicado al escáner.
- `image --quiet --input /trabajo/revisor-1.6.0.tar` pide escanear el archivo, sin la barra de progreso.
- `--severity HIGH,CRITICAL` fija el **umbral**: solo reporta las fallas graves y críticas. La documentación de filtrado lo ilustra con exactamente esta opción ([Trivy, «Filtering»](https://trivy.dev/latest/docs/configuration/filtering/)).
- `--exit-code 1` le dice a Trivy qué código de salida devolver «cuando encuentre problemas de seguridad» (así lo describe la referencia del comando). Por omisión sale con 0 aunque encuentre cosas (el bloque 4b lo mide); con `1`, un guion o un *pipeline* puede **fallar** si hay hallazgos. Ese es el truco que convierte un reporte en una puerta.
- El `sin_fechas` y el `sed` son de presentación en el guion: el primero quita los avisos con marca de hora que Trivy imprime al principio del renglón (para que la salida se pueda comparar entre corridas) y el segundo acorta `/trabajo/` a `./`. No los necesitas al correr el comando tú.

La tabla se lee de arriba abajo. `Report Summary` es el encabezado; cada fila es un **objetivo** escaneado. El primero es `./revisor-1.6.0.tar (debian 13.7)`, de tipo `debian`: los paquetes del sistema de la base, con **0** hallazgos. El segundo es `revisor`, de tipo `gobinary`: Trivy reconoció que dentro del archivo hay un binario de Go, leyó los módulos que lleva grabados y los revisó también, con **0** hallazgos. La columna `Secrets` dice `-`. Trivy busca vulnerabilidades y secretos por omisión (la referencia de `trivy image` da `vuln,secret` como valor de `--scanners`), pero para los secretos solo registra hallazgos, así que la documentación aclara que el `-` de esa columna significa «sin hallazgos» y no distingue entre «no se buscó» y «se buscó y no había nada» ([Trivy, «Reporting»](https://trivy.dev/latest/docs/configuration/reporting/)). Otra razón para no leer un cero como garantía. Y el `0` de la leyenda dice `Clean (no security findings detected)`: «limpio, sin hallazgos de seguridad detectados». Con el umbral `HIGH,CRITICAL`, el código de salida fue 0, y por eso el guion no imprime `[código de salida: …]`. Fíjate en la palabra de la leyenda: *detected*. Es el matiz de la advertencia anterior.

#### 10.10.4 El umbral decide qué ves, y `UNKNOWN` también cuenta

Ahora la misma imagen, **sin** `--severity`, con los mismos `--exit-code 1`. El bloque 4 la escanea con todas las gravedades y filtra el resultado para dejar las tablas:

```text
== 4. El mismo archivo, con todas las severidades y el mismo --exit-code 1
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#' | grep -E 'Total|│' 
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
│ revisor                                  │ gobinary │        0        │    -    │
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
│     Library     │ Vulnerability │ Severity │ Status │ Installed Version │  Fixed Version   │               Title               │
│ ca-certificates │ DSA-6572-1    │ UNKNOWN  │ fixed  │ 20250419          │ 20250419+deb13u1 │ ca-certificates - security update │
[código de salida: 1]
```

Aparece **un hallazgo** que el umbral anterior escondía. Hay que leer cada columna de la última tabla: `Library` es el paquete (`ca-certificates`, el de la lista de materiales de 10.6); `Vulnerability` es el identificador (`DSA-6572-1`, una *Debian Security Advisory*, aviso de seguridad de Debian); `Severity` es `UNKNOWN`, desconocida; `Status` es `fixed`, arreglada; `Installed Version` es `20250419`, la que tiene la imagen; `Fixed Version` es `20250419+deb13u1`, la versión de Debian que ya corrige la falla; y `Title` es el título del aviso. Una línea resume: `Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)`. Las categorías son cinco y así las lista Trivy en su resumen: `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` ([Trivy, «Reporting»](https://trivy.dev/latest/docs/configuration/reporting/)). Cuatro van de menor a mayor gravedad; `UNKNOWN` no es «menos grave que `LOW`»: es «sin clasificar». La documentación de Trivy dice que se usa cuando ninguna fuente le dio una gravedad al hallazgo («si ningún proveedor tiene una severidad, se usará `UNKNOWN`»; [Trivy, «Vulnerability»](https://trivy.dev/latest/docs/scanner/vulnerability/)). Por eso no se descarta sin mirarlo.

Tres lecciones en este bloque:

1. **El umbral es una decisión tuya, no un detalle.** Con `HIGH,CRITICAL` la imagen «pasa»; con todas las gravedades tiene un hallazgo. Ninguna de las dos es mentira, pero responden preguntas distintas. Elige el umbral antes de mirar el resultado, y escríbelo (en el *pipeline*, en el README del proyecto) para que nadie lo ajuste después para que salga verde.
2. **`UNKNOWN` cuenta.** El hallazgo es de gravedad `UNKNOWN`, y aun así `--exit-code 1` devolvió **1** (la línea `[código de salida: 1]`). Es decir: sin `--severity`, hasta lo que el escáner no sabe clasificar rompe tu puerta. Si prefieres que lo desconocido no falle, decláralo con `--severity` listando las gravedades que sí te importan. Lo que no conviene es no saberlo.
3. **Un hallazgo `fixed` es accionable.** El estado `fixed` y la columna `Fixed Version` dicen que hay una versión corregida. El arreglo no es olvidarlo ni apagar el escáner: es actualizar el paquete. Cómo se actualiza un paquete de una base distroless que fijaste por *digest* es el tema de la sección 10.12.

Y el contraste que explica para qué sirve `--exit-code`. El bloque 4b corre **el mismo escaneo sin esa opción** y pide el código de salida del propio Trivy con `echo "código de Trivy: $?"`:

```text
== 4b. Lo mismo, sin --exit-code: ¿con qué código sale Trivy por omisión?
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 0
```

Mismo hallazgo (`Total: 1`) y código **0**. Sin `--exit-code`, Trivy informa pero no falla: un guion que solo lo lanza seguiría adelante con un hallazgo grave sin enterarse. Se midió, no se supone: un escaneo en un *pipeline* sin `--exit-code` es un adorno que dice «bien» aunque haya hallazgos. Es el mismo tipo de trampa que ya conoces de las lecciones anteriores: el código de salida es lo que lee la máquina, y hay que comprobar que de verdad cambia cuando debe.

#### 10.10.5 `--ignore-unfixed`: una intuición que sale mal

Hay una opción que parece la salida fácil: `--ignore-unfixed`, que la referencia del comando describe como «mostrar solo las vulnerabilidades arregladas» (*display only fixed vulnerabilities*, [Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)) y que la página de filtros presenta como la forma de «omitir todas las vulnerabilidades sin arreglo» (*skip all unfixed vulnerabilities*, [Trivy, «Filtering»](https://trivy.dev/latest/docs/configuration/filtering/)). La intuición dice: «ignoremos lo que no tiene arreglo, para que solo falle lo que sí puedo arreglar». El bloque 5 la prueba, y hay que leer bien el nombre:

```text
== 5. ¿Y si se ignora lo que no tiene arreglo?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignore-unfixed --exit-code 1 2>&1 | sin_fechas | grep -E '^Total'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
[código de salida: 1]
```

Sigue el mismo hallazgo y sigue el código 1. Y no es un error de Trivy: `--ignore-unfixed` esconde lo que **no tiene** versión corregida, y este hallazgo **sí la tiene** (`fixed`, `20250419+deb13u1`). La opción hace lo que dice; lo que no hace es resolver tu problema, porque tu problema es de los que sí tienen arreglo. Es un buen ejemplo de por qué se prueba una opción en lugar de asumir lo que hace por su nombre.

#### 10.10.6 ¿De cuándo es lo que sabe?

El último bloque contesta una pregunta que debería acompañar a todo escaneo: ¿contra qué fecha se comparó?

```text
== 6. ¿De cuándo es la base de datos de vulnerabilidades?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 version 2>&1 | sin_fechas
Version: 0.76.0
Vulnerability DB:
  Version: 2
  UpdatedAt: 2026-10-21 19:18:22.876313144 +0000 UTC
  NextUpdate: 2026-10-22 19:18:22.876312904 +0000 UTC
  DownloadedAt: 2026-10-22 00:17:14.540681058 +0000 UTC
```

`trivy version` imprime la versión del programa y los datos de su base de datos: cuándo se **publicó** la última versión (`UpdatedAt`: 21 de octubre, 19:18 UTC), cuándo se espera la siguiente (`NextUpdate`: un día después) y cuándo se **descargó** a tu caché (`DownloadedAt`). Los tres renglones del final son los que guardas junto al resultado del escaneo: un «0 hallazgos» sin fecha de base de datos es un dato sin edad, y los datos sin edad se pudren.

Dos límites del escaneo hecho así, que la lección ya dejó ver y ahora se juntan. Uno: escaneaste **una plataforma**, la de tu equipo; el `amd64` del índice no se revisó. Para una entrega real, se repite el `docker save --platform` y el escaneo por cada plataforma publicada. Dos: el escáner revisa lo que hay *dentro* de la imagen; no revisa tu `Dockerfile` ni tus permisos de ejecución (eso lo cubrieron `docker build --check` en la Lección 3 y las medidas de las lecciones 7 y 8). Es una capa de defensa, no la defensa.

### 10.11 El puente a Kubernetes: `kind load docker-image`

#### 10.11.1 Por qué el clúster no ve tu imagen

El curso siguiente, el de Kubernetes con `kind`, toma la imagen con la que sales de aquí. `kind` (*Kubernetes IN Docker*) levanta un clúster de Kubernetes dentro de contenedores de Docker: cada «nodo» del clúster es un contenedor. Eso tiene una consecuencia que sorprende: aunque el nodo corre en tu Docker, **tiene su propio almacén de imágenes** adentro. Lo que tú construiste con `docker build` vive en el almacén de tu Docker, y el nodo no lo ve. Un pod que pida `curso-docker-revisor:1.6.0` intentaría bajarla de un registro, y esa imagen está solo en tu máquina.

Hay dos formas de resolverlo: publicar la imagen en un registro que el clúster pueda alcanzar, o **cargarla directamente en los nodos**. En un laboratorio local, la segunda es la corta, y es la que usa esta lección. La documentación de `kind` la presenta así: «puedes cargar una o más imágenes en tu clúster de `kind`» con `kind load docker-image mi-app:latest`, y si el clúster tiene nombre, hay que indicarlo con `--name` ([kind, «Quick Start»](https://kind.sigs.k8s.io/docs/user/quick-start/)). La misma página trae una advertencia con dos condiciones que son justo lo que vas a ver: «la política de descarga por omisión de Kubernetes es `IfNotPresent`, salvo que la etiqueta sea `:latest` o no se escriba»; para que las imágenes cargadas funcionen como esperas, **no uses la etiqueta `:latest`** y/o especifica `imagePullPolicy: IfNotPresent` o `imagePullPolicy: Never` en tu contenedor.

La política `Never` es la que usa la prueba. La documentación de Kubernetes la define así: «el kubelet no intenta descargar la imagen. Si la imagen ya está presente localmente, el kubelet intenta iniciar el contenedor; si no, el arranque falla» ([Kubernetes, «Images»](https://kubernetes.io/docs/concepts/containers/images/)). Para una prueba es la política ideal, porque ayuda a no ocultar problemas de transporte: si la imagen no llegó al nodo, el pod no arranca y lo dice, en vez de intentar descargarla de internet y tardar (o, peor, descargar *otra* imagen con el mismo nombre). Un límite: si el nodo ya tuviera una imagen vieja con esa misma etiqueta, `Never` la arrancaría sin avisar; por eso en pruebas se usa un clúster nuevo o una versión nueva.

#### 10.11.2 Instalar `kind` y `kubectl`

Hasta ahora todo se hizo con Docker. Este paso necesita dos programas más que **no** instalaste en las lecciones anteriores: `kind` y `kubectl`. Si tu equipo es el Linux Mint del curso, instálalos con las guías oficiales, con la versión fijada (las de este curso, medidas el 21 de octubre de 2026). `kind` se descarga como un binario ([kind, «Quick Start»](https://kind.sigs.k8s.io/docs/user/quick-start/)); `kubectl`, desde `dl.k8s.io`, con una comprobación de su suma `sha256` ([Kubernetes, «Install and Set Up kubectl on Linux»](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)):

```bash
# kind v0.33.0 (elige la línea de tu procesador; `uname -m` dice x86_64 o aarch64)
[ "$(uname -m)" = x86_64 ]  && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
[ "$(uname -m)" = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl v1.37.1
ARQ=amd64; [ "$(uname -m)" = aarch64 ] && ARQ=arm64
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl"
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Las dos primeras líneas de `kind` son las de la guía oficial: cada una se ejecuta solo si tu procesador es el que dice, así que en tu equipo corre exactamente una. La línea de `sha256sum --check` es la que protege la descarga: debe responder `kubectl: OK`; si responde `FAILED`, borra el archivo y descárgalo otra vez. `sudo install -o root -g root -m 0755` copia el programa a `/usr/local/bin` con dueño `root` y permiso de ejecución, que es la forma que indica la guía. Se probó la secuencia de descarga y verificación dentro de la máquina virtual de las corridas (Ubuntu 24.04, `arm64`), con el guion `fig10_00.sh` (bloques 2 y 3, con su salida al lado), sin la instalación en `/usr/local/bin` para no cambiar el sistema, y respondió:

```text
$ ./kind version
kind v0.33.0 go1.26.7 linux/arm64
$ echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
kubectl: OK
$ ./kubectl version --client
Client Version: v1.37.1
Kustomize Version: v5.8.1
```

(La versión de Go con la que se compiló `kind` cambia según la plataforma donde lo ejecutes: en la Mac de las corridas dijo `go1.27.0 darwin/arm64`.) Comprueba tu instalación con `kind version` y `kubectl version --client`.

#### 10.11.3 El clúster y la imagen

El guion `fig10_06.sh` se corre en la **Mac** (no dentro de la máquina virtual) porque allí viven `kind` y `kubectl`; hablan con el mismo daemon de Docker. Tiene un detalle que conviene explicar antes de leer la salida: usa un archivo de configuración de `kubectl` **propio y temporal** (`export KUBECONFIG=…` dentro del guion). Así el clúster que crea no modifica tu contexto de `kubectl` ni tu archivo `~/.kube/config`. **En tu equipo, al seguir la lección, quieres lo contrario:** que `kind` cambie tu contexto al clúster nuevo, y por eso los comandos de abajo no llevan `KUBECONFIG`. Aun así, y es una costumbre que vale la pena desde hoy, **antes de cada comando de `kubectl` comprueba en qué clúster estás** con `kubectl config current-context`: un `kubectl delete` en el contexto equivocado es la clase de error que no se deshace.

Las primeras secciones del guion:

```text
$ ./fig10_06.sh
== 1. Versiones
$ kind version
kind v0.33.0 go1.27.0 darwin/arm64
$ kubectl version --client | head -1
Client Version: v1.37.1

== 2. La imagen, para la plataforma de este equipo
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker image ls curso-docker-revisor:fig10 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:fig10 16.2MB

== 3. Un clúster kind de un nodo
$ kind create cluster --name curso-docker-puente-fig10 --wait 120s 2>&1 | grep -E '^Creating|Ready after|Set kubectl context' | sed -E 's/Ready after [0-9]+s/Ready after Ns/; s/ +[^ -~]+//g'
Creating cluster "curso-docker-puente-fig10" ...
 Ready after Ns
Set kubectl context to "kind-curso-docker-puente-fig10"
$ kubectl config current-context
kind-curso-docker-puente-fig10
```

Las versiones son las del curso: `kind` v0.33.0, que por omisión usa la imagen de nodo `kindest/node:v1.37.0`, es decir Kubernetes 1.37.0 ([kind, notas de la v0.33.0](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0)), y `kubectl` v1.37.1. Después, `docker build` construye la imagen **para la plataforma de este equipo** (aquí `arm64`). En tu carpeta, el comando es `docker build --build-arg VERSION=1.6.0 -t curso-docker-revisor:1.6.0 .`, que deja la imagen en tu Docker con el nombre que usará el curso siguiente; el guion usa la etiqueta de apoyo `fig10`. `docker build` a secas construye para la plataforma nativa y deja el resultado en el almacén local, que es justo lo que `kind load` va a leer. Pesa 16.2 MB. `kind create cluster --name … --wait 120s` crea el clúster de un nodo y espera hasta dos minutos a que esté listo; el `grep` y el `sed` del guion dejan solo los tres renglones que importan (el resto son indicadores de progreso con símbolos), y la hora real (`Ready after Ns`) se tapa porque cambia de corrida en corrida. `kind` terminó fijando el contexto: `kubectl config current-context` responde `kind-curso-docker-puente-fig10`. El contexto que `kind` crea se llama `kind-` más el nombre del clúster (así salió en la corrida), así que el prefijo del curso (`curso-docker-`) se hereda hasta el nombre de tu contexto.

#### 10.11.4 Provocar el error antes de la solución

Lo concreto primero: pide el pod **antes** de cargar la imagen y lee lo que dice. Este es el bloque 4:

```text
== 4. El error: el pod ANTES de cargar la imagen
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
$ kubectl get events --field-selector involvedObject.name=revisor,reason=ErrImageNeverPull -o custom-columns=MENSAJE:.message | head -2 | cut -c1-110
MENSAJE
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
```

`kubectl run revisor --image=… --image-pull-policy=Never --port=8080 --env=…` crea un pod con un contenedor. `--image-pull-policy=Never` es la política de arriba; `--port=8080` declara el puerto que escucha; `--env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'` es la misma variable de las secciones anteriores (el `revisor` se consulta a sí mismo, para que la prueba no dependa de otro pod). Después, `kubectl get pod … -o custom-columns=…` imprime una tabla con las columnas que tú eliges, con sus rutas dentro del objeto del pod: el estado (`phase`) es `Pending` y la razón de espera (`waiting.reason`) es **`ErrImageNeverPull`**. El nombre ya cuenta la historia: error de imagen, con la política `Never`, que no intentó descargarla. El evento lo confirma con una frase completa: `Container image "…" is not present with pull policy of Never`: la imagen no está presente y la política prohíbe descargarla. Ese es el error: el nodo no tiene la imagen. No hay nada roto en la imagen ni en el pod; falta el paso que la lleve hasta allá. Antes de seguir, el guion borra el pod fallido (`kubectl delete pod revisor --wait=true`), porque un pod no cambia su política por sí solo y empezar de cero es más limpio.

#### 10.11.5 Cargar la imagen y volver a pedir el pod

```text
== 5. Cargar la imagen en el nodo (sin registro) y volver a pedir el pod
$ kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10" with ID "sha256:0c8af76b8a5fbea25ddafedf41bc49ad9ec5f7144117559da98afbd1da0d2eaa" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10                dda2fbcae183b       3.68MB
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=90s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image,REINICIOS:.status.containerStatuses[0].restartCount
NOMBRE    ESTADO    IMAGEN                           REINICIOS
revisor   Running   curso-docker-revisor:fig10   0
$ kubectl logs revisor
revisor 1.6.0 escuchando en :8080 (1 servicio(s))
$ kubectl get events --field-selector involvedObject.name=revisor -o custom-columns=RAZON:.reason,MENSAJE:.message | cut -c1-110
RAZON               MENSAJE
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
ErrImageNeverPull   Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
Failed              Error: ErrImageNeverPull
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
Pulled              Container image "curso-docker-revisor:fig10" already present on machine and can be acc
Created             Container created
Started             Container started
```

`kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10` lee la imagen de tu Docker y la copia al nodo. Imprime una sola línea, que se lee: la imagen con ese identificador (`ID "sha256:0c8af76b…"`) **todavía no estaba presente en el nodo** `curso-docker-puente-fig10-control-plane`, y la está cargando. (Ese identificador es el de la imagen local, no un *digest* de registro.) A continuación viene la comprobación que no hay que saltarse: preguntarle al **nodo** qué imágenes tiene, con `docker exec <nodo> crictl images` (`crictl` es la herramienta de línea de comandos del runtime de contenedores que viene dentro del nodo; el nodo de `kind` es un contenedor de Docker, por eso `docker exec` entra a él). El `grep` deja el encabezado y las filas del `revisor`. Aparece `docker.io/library/curso-docker-revisor`, etiqueta `fig10`, 3.68 MB: la imagen **sí está en el nodo**, con el nombre completo que Kubernetes le da a un nombre corto. Esa fila es la evidencia de que la carga funcionó, y es mejor que fiarse del mensaje `loading...`, como vas a ver en 10.11.6. Después, el mismo `kubectl run` de antes, y ahora:

- `kubectl wait --for=condition=Ready pod/revisor --timeout=90s` espera hasta 90 segundos a que el pod esté listo; la respuesta `condition met` es la condición cumplida.
- La tabla del pod dice `Running` con la imagen `curso-docker-revisor:fig10` y **0 reinicios**.
- `kubectl logs revisor` muestra lo que el `revisor` imprime al arrancar: `revisor 1.6.0 escuchando en :8080 (1 servicio(s))`. Es el mismo renglón de la Lección 3. La versión `1.6.0` confirma que corre la imagen que construiste.
- Los eventos son la prueba de que el puente funcionó sin descargar nada. Los tres primeros renglones son del intento fallido de antes (`ErrImageNeverPull`, `Failed`). Después, el pod nuevo: `Scheduled` (asignado al nodo), y luego `Pulled` con el mensaje **`Container image "…" already present on machine`**: «la imagen ya está presente en la máquina». Aunque el evento se llame `Pulled` (descargada), el texto dice que no hubo descarga: la encontró ya en el nodo, donde `kind load` la dejó. El mensaje sale recortado por el `cut -c1-110` del guion (`…and can be acc`, de «and can be accessed by the container»). Después `Created` y `Started`.

Esa frase, `already present on machine`, es la prueba que busca la meta 6 del curso: **el pod arrancó sin ningún intento de descarga**. Cuando el curso de Kubernetes empiece, vas a repetir este puente con `curso-docker-revisor:1.6.0` y el clúster `curso-docker-puente`.

Para dejar limpio lo que hiciste en tu equipo (tu clúster, no el de un guion): `kind delete cluster --name curso-docker-puente`. Borra el clúster y quita su contexto de tu configuración; la imagen de tu Docker no se toca.

#### 10.11.6 Si la imagen no la construiste tú: la que viene de un registro

Hay un caso que el siguiente curso puede encontrar: la imagen no la construyes en tu equipo sino que la **bajas del registro** por su *digest*, como en 10.9. Sería natural pensar que `kind load docker-image` la acepta con esa misma referencia. Se midió, y no es así. El guion `fig10_09.sh` publica un índice de dos plataformas, lo baja por *digest* a la Mac, crea el clúster y prueba tres caminos:

```text
== 3. Cargar la imagen traída del registro, por su referencia con digest
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB

== 4. Guardarla con docker save y cargar el archivo
$ docker save --platform linux/arm64 -o revisor.tar localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 && du -h revisor.tar | cut -f1
3.5M
$ kind load image-archive revisor.tar --name curso-docker-puente-fig10

== 5. ¿Qué nombres tiene la imagen dentro del nodo?
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120 | sed -E 's/([0-9a-f]{12})[0-9a-f]{52}/\1…/g'
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB

== 6. Pedir el pod con la MISMA referencia con digest, sin descarga
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
```

Y los dos caminos restantes (el bloque 7 y el 8):

```text
== 7. Una etiqueta local sobre la misma imagen, y cargar esa etiqueta
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
$ docker tag localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 curso-docker-revisor:fig10-registro
$ kind load docker-image curso-docker-revisor:fig10-registro --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10-registro" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
$ kubectl run revisor --image=curso-docker-revisor:fig10-registro --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image
NOMBRE    ESTADO    IMAGEN
revisor   Running   curso-docker-revisor:fig10-registro
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace

== 8. Traer solo el manifiesto de la plataforma (no el índice) y cargarlo
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" with ID "sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
```

Se lee así. **Camino 1, cargar la referencia con *digest* (bloque 3).** `kind load` imprime `not yet present on node … loading...` y no da ningún error. Después el guion le pregunta al nodo qué imágenes tiene, con `crictl` (la herramienta de línea de comandos del runtime de contenedores que viene dentro del nodo), y el filtro deja pasar las filas con `revisor` **y las que no tienen nombre** (`<none>`). **No hay ninguna imagen llamada `revisor`, pero sí una sin nombre:** `docker.io/library/import-2026-10-22`, etiqueta `<none>`, 3.68 MB. La imagen **sí llegó al nodo, sin el nombre que le pide el pod.** El `import-` seguido de la fecha es el nombre de relleno que `ctr images import` (el comando con el que `kind` importa, según los reportes que se citan abajo) le da a lo que importa sin una referencia propia ([containerd, `ctr images import`](https://github.com/containerd/containerd/blob/main/cmd/ctr/commands/images/import.go)); la fecha es la del reloj del nodo, que va en UTC, y por eso dice 22 aunque las corridas fueran el 21 en la Ciudad de México. **Camino 2, guardar con `docker save --platform` y cargar el archivo con `kind load image-archive` (bloque 4):** el comando termina sin error y sin salida; el bloque 5 muestra la misma fila de 3.68 MB y una segunda sin nombre de 2.32 kB (no se investigó qué contiene). El bloque 6 es la consecuencia: un pod que pide la referencia con *digest* se queda en `Pending` con `ErrImageNeverPull`, porque en el nodo no hay ninguna imagen con ese nombre aunque su contenido esté. **Camino 3, una etiqueta local (bloque 7):** `docker tag <referencia con digest> curso-docker-revisor:fig10-registro` le pone un nombre local a la imagen bajada, `kind load docker-image` de esa etiqueta deja la imagen en el nodo **con nombre** (`crictl` la muestra como `docker.io/library/curso-docker-revisor`, con la etiqueta `fig10-registro` y 3.68 MB; la fila sin nombre de 3.68 MB ya no está, porque era la misma imagen: el mismo identificador, `011d6bb2f3c70`) y el pod arranca: `Running`. Dos observaciones. Una: el nodo escribe el nombre completo, `docker.io/library/…`, pero el pod que pide `curso-docker-revisor:fig10-registro` lo encuentra, porque Kubernetes completa el nombre corto de la misma manera. Dos: **cargar la referencia del manifiesto de la plataforma** (el bloque 8, que baja `…@sha256:7d76…`, el manifiesto de `arm64` en lugar del índice) tampoco funcionó: el pod vuelve a esperar con `ErrImageNeverPull`. Así que el problema no es el índice de varias plataformas sino la referencia con *digest*.

La regla práctica: **`kind load` funciona con un nombre con etiqueta; con una referencia con *digest* responde «loading» y no deja en el nodo una imagen que el pod pueda encontrar por esa referencia.** Si tu imagen viene de un registro, ponle primero una etiqueta local con `docker tag` y carga esa. **La fuente, dicha con exactitud.** No hay una página de `kind` que describa este caso tal cual (cargar por una referencia con *digest* y no recibir ningún error). Lo que sí existe en el repositorio de `kind` son reportes vecinos, del mismo origen: con Docker 29 y su almacén de *containerd*, `docker save` conserva el índice completo de una imagen de varias plataformas aunque solo se hayan bajado las capas de la tuya, y `kind load` (que importa con `ctr images import --all-platforms --digests`) falla con `content digest … not found`. Los mantenedores lo atribuyen a que `docker save` «hizo cambios que rompen compatibilidad cuando se usa el almacenamiento respaldado por *containerd*» y apuntan como salida corta a no usar ese almacén ([kind, issue #4066, «kind unable to load images with docker 29»](https://github.com/kubernetes-sigs/kind/issues/4066), cerrado como duplicado del issue fijado, y todavía abierto, [#3795](https://github.com/kubernetes-sigs/kind/issues/3795); y [#4224](https://github.com/kubernetes-sigs/kind/issues/4224), que repite el error en una Mac con procesador Apple y OrbStack y se resolvió importando con `ctr` sin `--all-platforms`). La diferencia con lo que midió esta lección es el síntoma: aquí **no hubo error**, y la imagen llegó al nodo **sin nombre** (`<none>`), por lo que el pod no la encuentra. Para ese síntoma exacto: **medido, sin fuente oficial.** Tampoco se investigó por qué la etiqueta local sí deja la imagen con nombre (hipótesis sin medir: la imagen de la etiqueta se bajó solo con las capas de tu plataforma y el nombre corto cambia lo que `kind` exporta). Por eso la regla práctica es comprobar siempre con `crictl images`, mirando también las filas `<none>`. (Es el aviso de mayor consecuencia para el curso siguiente: el comando cómodo falla en silencio, y el síntoma, `ErrImageNeverPull`, aparece después, en el pod.)

### 10.12 La base fijada envejece: renovar el *digest*

Queda pendiente el hallazgo de 10.10: `ca-certificates`, versión `20250419`, con arreglo disponible en `20250419+deb13u1`. ¿De dónde sale esa versión vieja? De la **base** de la imagen, `gcr.io/distroless/static-debian13:nonroot`, que desde la Lección 5 está fijada por *digest*: `@sha256:516757106de35…`. Fijar por *digest* te dio exactamente lo que buscabas, que la base no cambie bajo tus pies. Y la otra cara de lo mismo es que **la base tampoco recibe correcciones por sí sola**. La documentación de Docker lo dice con todas las letras: fijar a un *digest* implica «optar por no recibir correcciones de seguridad automáticas, lo cual probablemente es algo que quieres recibir», y que es «tedioso» buscar y escribir el *digest* nuevo; recomienda automatizar la revisión, con Docker Scout (que reporta si tu base fijada ya no es la vigente) o con Dependabot (que abre solicitudes de cambio programadas para actualizar etiquetas y *digests*) ([Docker, «Building best practices»](https://docs.docker.com/build/building/best-practices/)).

Lo que importa aquí es el procedimiento, que es corto y se puede hacer a mano: (1) preguntar al registro de la base a qué *digest* apunta hoy la etiqueta; (2) cambiar el *digest* en el `Dockerfile`; (3) reconstruir; (4) volver a escanear; (5) volver a probar. Los Ejercicios 2 y 4 lo hacen con mediciones. Un adelanto que conviene decir con precisión, porque es fácil enredarlo: lo que se movió el día de las corridas fue **la etiqueta** `nonroot`, no tu *digest*. A las nueve de la mañana, hora de la Ciudad de México, esa etiqueta ya apuntaba a `sha256:d62067879de8…`, mientras que el `Dockerfile` fija `sha256:516757106de3…`; y el *digest* fijado **sigue existiendo y sigue apuntando a la misma imagen de siempre** (el Ejercicio 2 lo comprueba pidiéndolo por su *digest*). Eso es lo que prometía fijar: que la base no cambie sin que tú lo decidas. La consecuencia es la otra cara de la misma moneda: los arreglos que Debian publica llegan solo cuando tú cambias el *digest*. La decisión de esta lección es quedarse con la base fijada, porque todas las salidas que lees se midieron con ella, y presentar la renovación como lo que es, **un acto deliberado** (el Ejercicio 4 la hace y mide que el escaneo pasa a 0 hallazgos). La imagen `1.6.0` que entrega el curso conserva su base fijada y su hallazgo documentado. En un proyecto real, lo que haces es renovar a propósito, con una versión nueva.

Hay una frontera que no se debe cruzar: **no renuevas por renovar.** Una base nueva es un cambio: puede traer una librería distinta, puede cambiar el comportamiento de algo. Por eso el procedimiento termina con las pruebas del `revisor` (que ya corre la etapa `pruebas` de tu `Dockerfile` al construir) y con volver a correr la imagen. Y se hace en una construcción con **versión nueva** (`1.6.1`), por la regla de 10.3: no se reutiliza una etiqueta publicada.

## El error que vas a ver

Esta lección tiene seis mensajes que conviene reconocer, uno por herramienta (dos son del puente a Kubernetes, el 1 y el 6). Todos aparecieron ya; aquí se juntan para que los encuentres rápido.

**1. El pod que no arranca: `ErrImageNeverPull`.** Es el de `fig10_06.sh`:

```text
revisor   Pending   ErrImageNeverPull
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
```

Se lee de derecha a izquierda como los de las lecciones anteriores. «With pull policy of Never» dice que la política prohíbe descargar; «is not present» dice que el nodo no tiene la imagen. Los dos juntos significan: nadie la cargó. Se resuelve con `kind load docker-image <imagen> --name <clúster>`, comprobando que el nombre y la etiqueta sean **exactamente** los del pod. Si la cargas y sigue fallando, suele ser una etiqueta distinta: revisa con `kubectl get pod revisor -o custom-columns=IMAGEN:.spec.containers[0].image` qué nombre pide el pod (es la misma columna `IMAGEN` que ya usaste).

**2. Trivy que no encuentra la imagen.**

```text
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]
```

Quiere decir que buscó en esos cuatro lugares y no la halló. El arreglo no es darle el *socket* de Docker: es guardar la imagen con `docker save` y escanear el archivo con `--input`.

**3. `docker save` con una plataforma que no tienes.**

```text
Error response from daemon: no suitable export target found: image with reference … was found but does not provide the specified platform (linux/amd64)
```

La imagen existe en tu almacén, pero esa plataforma nunca se descargó. El arreglo: traer primero esa plataforma con `docker pull --platform linux/amd64 <referencia>` y volver a guardar (el bloque 11 de `fig10_04.sh` lo midió: después del `pull`, el `save` responde `guardada: linux/amd64`).

**4. La construcción emulada que revienta.**

```text
fatal error: fault
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
```

Coincide con la emulación y no con tu código: el mismo `Dockerfile` compila bien en el procesador nativo y con compilación cruzada. Se resuelve evitando la emulación: compilación cruzada con `--platform=$BUILDPLATFORM` en las etapas de compilación y `GOOS=$TARGETOS GOARCH=$TARGETARCH` en `go build`.

**5. El `500` del reporte con `read-only file system`.** Es el de la Lección 8, que reaparece con la imagen traída por *digest*:

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

La imagen está bien y el sistema de solo lectura funciona: falta montar un volumen en `/datos`.

**6. `kind load` que dice «loading» y no carga.** Es el de 10.11.6: al cargar una imagen bajada de un registro por una referencia con *digest*, `kind` no da error y no deja en el nodo una imagen que el pod pueda encontrar por esa referencia (llega sin nombre, como `<none>`), y el pod se queda en `Pending` con `ErrImageNeverPull`. Se resuelve poniéndole antes una etiqueta local con `docker tag` y cargando esa etiqueta; para comprobar que llegó, `docker exec <nodo> crictl images` debe mostrar la imagen con el nombre que pide el pod.

## El hábito de seguridad de la lección

Esta lección instala cuatro costumbres, y las cuatro se practicaron con mediciones:

- **Lo que se ejecuta se referencia por *digest*.** Una etiqueta se mueve y un *digest* no; el accidente que evita es el de la escena (dos personas con el «mismo» nombre y contenidos distintos) y el ataque que dificulta es el de reemplazar en el registro una imagen que otros ya confían por nombre. Medido en 10.3.
- **Lo que se publica trae su lista de materiales y su procedencia, y la procedencia se publica limpia.** `mode=max` expone los valores de los argumentos de construcción, así que ningún secreto viaja por `--build-arg`: entra por `--mount=type=secret`. Medido en 10.7.
- **Se escanea sin darle el *socket* de Docker a nadie.** `docker save`, `--input`, carpeta montada en `:ro`. El accidente que evita es dar el control del daemon a una herramienta que descarga datos de internet. Medido en 10.10.
- **El escaneo tiene un umbral escrito y una fecha de base de datos.** Un «cero» sin umbral y sin fecha no es un dato. Medido en 10.10.4 y 10.10.6.

## Lo que se hace mal

- **Reutilizar una etiqueta publicada** («es la misma versión, solo corregí algo»). Es el error de la escena. Cada construcción que se entrega lleva una etiqueta nueva; si algo se corrige, es la `1.6.1`.
- **Publicar `latest`.** Kubernetes la trata distinto (su política por omisión cambia con esa etiqueta, y la documentación de `kind` pide no usarla con imágenes cargadas), y no dice qué versión es. La etiqueta `latest` no es un nombre de versión: es un nombre cualquiera que por convención se mueve.
- **Dar el *socket* de Docker a Trivy** (o a cualquier contenedor) «para que lea la imagen». Quien tiene el *socket* controla el daemon, y con él la máquina. Se resuelve con `docker save` y `--input`.
- **Escanear una sola vez y olvidarse.** La base de datos de fallas cambia a diario. Un resultado vale con su fecha, y una entrega se escanea de nuevo antes de usarla.
- **Fijar el umbral después de ver el resultado.** Si el escaneo falla y bajas el umbral hasta que pase, el escaneo dejó de servir. El umbral se escribe antes.
- **Ignorar un hallazgo sin razón ni fecha de caducidad.** Un `.trivyignore` con identificadores sueltos es una lista de problemas que alguien decidió callar sin dejar por qué. Cada línea lleva un comentario con la razón y un `exp:` con la fecha en que el aviso caduca (Ejercicio 3).
- **Fijar la base por *digest* y no volver a mirarla.** La fijación protege de cambios inesperados, y también de correcciones esperadas. Se programa una revisión (Docker Scout, Dependabot o una tarea tuya).
- **Pasar secretos por `--build-arg` y publicar con `mode=max`.** Los valores quedan escritos en la procedencia que viaja con la imagen. Los secretos de construcción entran por `--mount=type=secret`.
- **Construir para otra plataforma por emulación cuando se puede compilar cruzado.** Más lento, y en esta máquina ni siquiera funcionó.
- **Un registro en `0.0.0.0:5000` sin TLS ni autenticación.** Cualquiera en tu red puede empujar o bajar. Se publica en `127.0.0.1`, o se pone TLS y control de acceso.
- **Mandar una imagen por chat como archivo `.tar`.** Quien la recibe no sabe de quién es ni qué lleva. Se publica en un registro y se comparte el *digest*.
- **Tomar «escaneada» por «segura».** El escaneo revisa lo que sus bases de datos conocen hoy en los paquetes que reconoce. Es una capa de revisión, no una garantía.
- **Cargar con `kind load` una imagen con etiqueta `latest` y esperar que el pod no la descargue.** Con esa etiqueta la política por omisión es otra. Escribe `imagePullPolicy` o usa una etiqueta de versión.

## Ejercicios

Los cuatro tienen su solución medida más abajo, con el guion que la produjo. Intenta cada uno antes de mirarla.

### Ejercicio 1 — Dos etiquetas, un *digest*

Tienes publicada la `1.6.0` en tu registro local. Quieres que quien pida `1.6` (la «línea» 1.6, sin el último número) reciba **exactamente la misma imagen** que quien pide `1.6.0`, sin reconstruir nada. Agrega la etiqueta `1.6` a la imagen ya publicada, comprueba con el registro que ahora hay dos etiquetas, y demuestra con `imagetools inspect` que las dos tienen el mismo *digest*. Pista: `docker buildx imagetools create -t <destino> <origen>` crea una etiqueta nueva a partir de una referencia que ya está en el registro.

### Ejercicio 2 — ¿Qué *digest* tiene hoy la base?

Tu `Dockerfile` fija la base `gcr.io/distroless/static-debian13:nonroot` por *digest*. Averigua (a) los primeros doce caracteres del *digest* que trae tu `Dockerfile` y (b) los del *digest* al que apunta hoy esa misma etiqueta en el registro de Google. Decide con una frase si tu base está al día. Pista: `docker buildx imagetools inspect` también sirve para imágenes de otros registros.

### Ejercicio 3 — Aceptar un hallazgo por escrito

Trivy reportó `DSA-6572-1` (`UNKNOWN`) en `ca-certificates`. Supón que no puedes renovar la base hoy. Escribe un archivo `.trivyignore` que acepte **ese** hallazgo, con un comentario que diga la razón y con un `exp:` que ponga la fecha de caducidad, y demuestra cuatro cosas: sin el archivo, Trivy sale con código 1; con el archivo, sale con 0; si el archivo ignora **otro** identificador, vuelve a salir con 1 (el archivo calla solo lo que dice, no todo); y si el `exp:` ya pasó, el hallazgo vuelve y Trivy sale con 1 otra vez.

### Ejercicio 4 — Renovar la base y volver a escanear

Cambia en tu `Dockerfile` el *digest* de la base por el que averiguaste en el Ejercicio 2 (b), reconstruye la imagen, comprueba que sigue diciendo `1.6.0` con `version`, vuelve a guardar la imagen con `docker save` y vuelve a escanear **con todas las gravedades** y con `--exit-code 1`. ¿Qué cambió en el resultado? Escribe la respuesta en tu bitácora con la fecha: sin la fecha, el resultado no sirve.

## Soluciones

### Solución 1

Es la primera parte de `fig10_08.sh`. Con la `1.6.0` ya empujada, `imagetools create` crea la etiqueta nueva directamente en el registro, a partir de una referencia que ya está allí. El resultado, como vas a ver, es otro nombre para el mismo índice.

```text
$ ./fig10_08.sh
== Ejercicio 1. Dos etiquetas, un digest
$ docker buildx imagetools create -t localhost:5000/curso-docker-revisor:1.6 localhost:5000/curso-docker-revisor:1.6.0 >/dev/null 2>&1 && echo 'etiqueta 1.6 creada'
etiqueta 1.6 creada
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["1.6","1.6.0"]}
$ for t in 1.6.0 1.6; do docker buildx imagetools inspect localhost:5000/curso-docker-revisor:$t --format '{{json .Manifest.Digest}}'; echo; done
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
```

Se lee así. `create -t …:1.6 …:1.6.0` dice «crea la etiqueta `1.6` apuntando a lo que hoy es `1.6.0`»; el `>/dev/null 2>&1` esconde su salida de progreso y el `&& echo` confirma que terminó bien. La lista de etiquetas ya trae dos, `1.6` y `1.6.0`. Y el ciclo pregunta, para cada etiqueta, el *digest* del índice: los dos renglones son **idénticos** (`125ba52e…`). Dos nombres, una imagen. Eso es lo que se espera de una etiqueta que sigue la línea 1.6: un nombre móvil y legible que, en este instante, señala lo mismo que la fija. La contraparte, que ya sabes: la `1.6` es una etiqueta que **sí se mueve** (cuando publiques la `1.6.1`, la apuntarías a ella), así que sirve para humanos y nunca para verificar.

### Solución 2

Está en `fig10_07.sh`. El primer comando extrae del `Dockerfile` los doce primeros caracteres del *digest* que fija; el segundo pregunta al registro de Google el de la etiqueta `nonroot` y recorta el comienzo:

```text
$ ./fig10_07.sh
== Ejercicio 2. ¿Qué digest tiene HOY la etiqueta nonroot de la base?
$ grep -oE 'static-debian13:nonroot@sha256:[0-9a-f]{12}' Dockerfile
static-debian13:nonroot@sha256:516757106de3
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:d62067879de8
(y el digest que fija el Dockerfile, ¿sigue existiendo en el registro?)
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:516757106de3
```

El `Dockerfile` fija `516757106de3…`; el registro dice hoy `d62067879de8…`. **No coinciden: la etiqueta ya no apunta a lo que tu `Dockerfile` fijó.** Y la tercera línea de la salida lo aclara: pedir a Google el *digest* fijado (`…nonroot@sha256:516757106de3…`) responde con ese mismo *digest*; no se movió ni desapareció. El que cambió es el destino de la etiqueta. El `grep -oE` con ese patrón imprime solo lo que coincide (`-o`) con una expresión regular extendida (`-E`) que pide la cadena `static-debian13:nonroot@sha256:` más doce caracteres hexadecimales. El `cut -c2-20` quita la comilla inicial de la salida JSON y deja los primeros 19 caracteres, es decir `sha256:` más doce. Que la etiqueta haya cambiado de destino no dice que lo nuevo sea mejor ni que lo viejo sea peligroso: dice que **hay algo que mirar**. Es el insumo del Ejercicio 4. (Esta medición es del 21 de octubre; si la repites otro día, te puede dar otro resultado, y eso es normal: es la razón de que se mida.)

### Solución 3

También en `fig10_07.sh`. El archivo, con su razón y su fecha, y las tres corridas:

```text
== Ejercicio 3. Aceptar el hallazgo por escrito, con razón y fecha
$ cat .trivyignore
# ca-certificates 20250419 en la base distroless fijada por digest.
# Debian ya lo corrigió (20250419+deb13u1); el arreglo llega al renovar el
# digest de la base (Ejercicio 4). Mientras tanto se acepta, por escrito.
# Revisado el 21-oct-2026. Borrar esta línea al renovar la base.
DSA-6572-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(el mismo archivo, con un identificador que NO es el del hallazgo)
$ sed -i.orig 's/^DSA-6572-1$/DSA-0000-1/' .trivyignore && tail -1 .trivyignore
DSA-0000-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1

== Ejercicio 3 (continuación). La fecha que Trivy SÍ hace cumplir: exp:
$ sed -i.orig 's/^DSA-0000-1$/DSA-6572-1 exp:2026-11-21/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-11-21
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(la misma línea, con una fecha que ya pasó)
$ sed -i.orig 's/exp:2026-11-21/exp:2026-01-01/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-01-01
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
```

Léelo en tres tiempos. **Sin** archivo: la tabla cuenta 1 hallazgo, hay `Total: 1` y el código es **1**. **Con** `--ignorefile /trabajo/.trivyignore`: la tabla cuenta **0** para la base, ya no hay línea `Total`, y el código es **0**. Y en la tercera corrida el guion cambió el identificador del archivo por uno inventado (`DSA-0000-1`): el hallazgo real vuelve, `Total: 1`, código **1**. Por eso la solución completa tiene la tercera corrida: demuestra que el archivo no es un interruptor general sino una lista de identificadores concretos. En el formato del archivo, las líneas que empiezan con `#` son comentarios y cada identificador va solo en su renglón ([Trivy, «Filtering»](https://trivy.dev/latest/docs/configuration/filtering/)). Un comentario con una fecha no obliga a nadie a volver a mirar el hallazgo; lo que sí hace cumplir una fecha es el campo `exp:` que esa misma documentación muestra en sus ejemplos (`CVE-2019-14697 exp:2023-01-01`). La segunda parte de la solución, «continuación», lo mide con el identificador de este ejercicio: con `DSA-6572-1 exp:2026-11-21` (una fecha futura) Trivy sale con código **0**; con `exp:2026-01-01` (una fecha ya pasada) el hallazgo **vuelve** y el código es **1**. Es decir, la aceptación caduca sola. Los identificadores `DSA-…` no aparecen en los ejemplos de la documentación; la medición muestra que funcionan igual que los `CVE-…`. La práctica recomendable es combinar las dos cosas: el comentario con la razón y `exp:` con la fecha de revisión. La opción `--ignorefile` apunta a la ruta del archivo *dentro del contenedor* (`/trabajo/.trivyignore`, porque `/trabajo` es tu carpeta montada), no a la de tu equipo; la referencia del comando indica que, por omisión, la opción vale `.trivyignore`, es decir, un archivo con ese nombre en la carpeta actual. Y el comentario: no es adorno. Es lo que permite que dentro de dos meses alguien, tú incluido, sepa **por qué** esa línea está ahí y cuándo se debe volver a decidir.

### Solución 4

La segunda parte de `fig10_08.sh`. Averigua el *digest* vigente de la etiqueta, lo escribe en el `Dockerfile` con `sed`, reconstruye, comprueba la versión, guarda y escanea:

```text
== Ejercicio 4. Renovar el digest de la base y volver a escanear
$ diff Dockerfile.viejo Dockerfile | cut -c1-120 | sed -E 's/sha256:([0-9a-f]{12})[0-9a-f]+/sha256:\1…/'; true
32c32
< FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de3…
---
> FROM gcr.io/distroless/static-debian13:nonroot@sha256:d62067879de8…
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker run --rm curso-docker-revisor:fig10 version
1.6.0
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
```

El `diff` muestra que **solo cambia la línea 32**, la del `FROM` final, y solo el *digest*. La construcción pasa (con ella, las pruebas de Go de la etapa `pruebas`), `version` sigue diciendo `1.6.0`, y el escaneo con **todas las gravedades** ahora da **0 hallazgos en la base y código 0**. Es decir: lo que el escáner veía en `ca-certificates` desapareció al renovar la base, sin apagar nada ni callar ningún aviso. Dos matices para tu bitácora. Uno: **lo medido es el resultado, no la causa**: no se abrió la lista de paquetes de la base nueva para comprobar qué versión de `ca-certificates` trae; el escaneo dice que ya no hay hallazgo, y con eso se decide. Dos: se escaneó una plataforma, la de este equipo. Para una entrega real, repetirías el escaneo con la otra (el bloque 11 de 10.9.2 la deja guardada). Y la entrega se publicaría con **una etiqueta nueva** (`1.6.1`), según la regla de 10.3, no encima de la `1.6.0`.

## Cómo sé que lo logré

Comprueba cada punto con un comando, no con la memoria:

1. **El registro escucha solo en `127.0.0.1`.** `docker port curso-docker-registro` responde `5000/tcp -> 127.0.0.1:5000` y nada con `0.0.0.0`.
2. **La imagen publicada es un índice de dos plataformas.** `docker buildx imagetools inspect localhost:5000/curso-docker-revisor:1.6.0` muestra `application/vnd.oci.image.index.v1+json` y entradas `linux/amd64` y `linux/arm64`, más dos de tipo `attestation-manifest`.
3. **Sabes leer su lista de materiales y su procedencia, y tu Docker usa el almacén de *containerd*.** `docker info -f '{{ .DriverStatus }}'` incluye `io.containerd.snapshotter.v1`. Con las plantillas de 10.6 y 10.7 obtienes los nueve paquetes de la lista y el renglón `construida EN`.
4. **Puedes demostrar que una etiqueta se mueve y un *digest* no.** Repites la medición de 10.3 y ves dos *digests* distintos bajo la misma etiqueta.
5. **Corre por *digest*, en las dos plataformas, y endurecida.** En tu equipo `amd64`, `docker run --rm --platform linux/amd64 <referencia> version` responde `1.6.0`.
6. **Corre endurecida:** `docker run … --read-only --cap-drop ALL --security-opt no-new-privileges --init -v <volumen>:/datos localhost:5000/curso-docker-revisor@sha256:…` responde `{"estado":"vivo","version":"1.6.0"}` en `/salud`, y `docker inspect --format '{{.Config.Image}}' <contenedor>` muestra una referencia con `@sha256:`.
7. **El escaneo tiene un umbral escrito, un código de salida y una fecha.** Corres Trivy con `--input`, sin el *socket* de Docker, y guardas junto al resultado la salida de `trivy version` con la fecha de la base.
8. **El pod arranca sin descargar nada.** `kubectl get events` muestra `already present on machine` y `kubectl get pod revisor` dice `Running` con `0` reinicios.
9. **Dejaste tu máquina limpia.** Siguiendo la limpieza de la sección «Cierre del curso», `docker ps -a`, `docker volume ls` y `kind get clusters` ya no muestran el registro, los contenedores de apoyo, la caché de Trivy ni el clúster de esta lección; solo se queda tu imagen `curso-docker-revisor:1.6.0`, que es la que usará el curso siguiente.

## Resumen

- Una **etiqueta** es un letrero que se puede mover; un ***digest*** es una huella del contenido que no se mueve. Se publica con una etiqueta nueva por entrega y se verifica por *digest*.
- Una etiqueta apunta a un **índice**; el índice apunta a un manifiesto por plataforma y a un manifiesto de atestación por plataforma.
- Para entregar a dos procesadores sin emulación se **compila cruzado**: `--platform=$BUILDPLATFORM` en las etapas de compilación y `GOOS=$TARGETOS GOARCH=$TARGETARCH` en `go build`. En esta máquina la emulación falló.
- `--sbom=true` agrega la lista de materiales (SPDX, escrita por Syft); `--provenance=mode=max` agrega la procedencia completa, que **expone los valores de los argumentos de construcción**; `mode=min` no.
- Reconstruir «idéntico» no garantiza el mismo *digest*: con caché cambió el del índice; sin caché, el de cada plataforma.
- Se baja solo la plataforma que corresponde; `docker save --platform` falla si esa plataforma no se bajó.
- Trivy se corre **sin el *socket***: `docker save` y `--input`, con la carpeta en `:ro`. El umbral lo fijas tú, `UNKNOWN` cuenta si no declaras `--severity`, y sin `--exit-code` Trivy sale con 0 aunque encuentre cosas.
- Un hallazgo con arreglo se resuelve renovando la base o, mientras tanto, se acepta **por escrito** en un `.trivyignore` con razón y fecha. Fijar por *digest* tiene el costo de renovar a propósito.
- `kind load docker-image` lleva la imagen a los nodos; con `imagePullPolicy: Never`, el pod arranca solo si llegó, y el evento `already present on machine` lo prueba. Con una imagen bajada de un registro, se carga por una **etiqueta local**: con una referencia con *digest* `kind` no da error y no deja en el nodo una imagen que el pod pueda encontrar por esa referencia.
- El binario de la otra plataforma se verifica ejecutándolo: `docker run --rm --platform linux/amd64 <referencia> version` (aquí corrió emulado; en tu `amd64`, nativo).

## Cierre del curso: cómo sabes que terminaste

El README del curso promete que no se acaba al leer la lección 10 sino cuando tu proyecto cumple seis cosas. Con esta lección, las seis tienen cómo comprobarse, y cada una se midió en la lección que la instala:

1. **`docker compose up` levanta todo desde cero** y el reporte muestra el servicio de prueba caído como `FALLA` (Lección 9).
2. **La imagen final pesa decenas de megabytes** —16.2 MB en las corridas de las lecciones 8 a 10—, sin shell ni compilador, y no corre como `root` (Lecciones 5 y 8).
3. **Ningún secreto aparece** en `docker history`, en `docker inspect` ni en el entorno (Lección 6).
4. **`docker stop` termina en pocos segundos** (en las lecciones 3, 5, 7 y 9 se midieron entre 137 y 321 milisegundos con la forma *exec*) y `docker ps` distingue `(healthy)` de `(unhealthy)` (Lección 7).
5. **El reporte sobrevive a `docker rm`** y el `revisor` encuentra al otro contenedor por su nombre (Lección 8).
6. **La imagen publicada se referencia por *digest*, pasa el escaneo con el umbral que fijaste** y se carga en un clúster `kind` **sin un solo error de descarga** (esta lección).

Hay una frase que conviene decir con precisión, porque es fácil exagerarla: tu imagen sale de este curso **con su escaneo revisado**, no «segura» ni «aprobada». Tiene un umbral escrito, una fecha de base de datos y un hallazgo conocido, con su razón y con el camino para resolverlo. Eso es lo que significa trabajar con rigor: no que no haya hallazgos, sino que sepas cuáles hay, de cuándo son y qué vas a hacer con ellos. El [curso de Kubernetes con kind](https://www.habil.mx/es/cursos/kubernetes/) toma desde aquí: la imagen `curso-docker-revisor:1.6.0`, con el puente de `kind load docker-image` que ya recorriste.

Antes de cerrar la bitácora, apaga y borra lo que levantaste en esta lección y que sea tuyo, con los nombres que tú le diste, uno por uno (sin `docker system prune` ni `docker volume prune`, que se llevarían lo ajeno). Primero mira qué hay con `docker ps -a`, `docker images` y `docker volume ls`, y borra solo lo que reconozcas:

```bash
docker rm -f -v curso-docker-registro curso-docker-revisor   # el registro (con su volumen anónimo) y el contenedor de 10.9
docker images --digests --format '{{.Repository}}@{{.Digest}}' | grep '^localhost:5000/curso-docker-revisor@' | xargs -r docker rmi   # lo traído por digest
docker volume rm curso-docker-trivy-cache   # la caché de Trivy de 10.10
kind delete cluster --name curso-docker-puente
```

(El volumen `curso-docker-reportes` **no** se borra aquí: es el de la Lección 8, guarda los reportes que ya generaste y se limpia, si quieres, al cerrar esa lección. Tu imagen local `curso-docker-revisor:1.6.0`, la que construyes en 10.11.3, se queda: la usa el curso siguiente. El `rmi` de arriba borra por nombre las copias bajadas por *digest*, nunca por identificador.)

## Fuentes

Todas se consultaron el 21 de octubre de 2026.

- Docker, «Build attestations» (SBOM y procedencia): <https://docs.docker.com/build/metadata/attestations/>
- Docker, «SLSA provenance» (modos `min` y `max`): <https://docs.docker.com/build/metadata/attestations/slsa-provenance/>
- Docker, «Multi-platform builds»: <https://docs.docker.com/build/building/multi-platform/>
- Docker, `docker buildx imagetools inspect`: <https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/>
- Docker, `docker image save`: <https://docs.docker.com/reference/cli/docker/image/save/>
- Docker, referencia de `dockerd` (registros locales marcados como inseguros): <https://docs.docker.com/reference/cli/dockerd/>
- Docker, «containerd image store»: <https://docs.docker.com/engine/storage/containerd/>
- Docker, «Building best practices» (base fijada por *digest*): <https://docs.docker.com/build/building/best-practices/>
- Docker, notas de versión de Docker Engine 29 (29.2.1 del 2 de febrero de 2026, con BuildKit v0.27.1): <https://docs.docker.com/engine/release-notes/29/>
- Distribution (registro), «Deploy a registry server»: <https://distribution.github.io/distribution/about/deploying/>
- Distribution, notas de la versión 3.1.2: <https://github.com/distribution/distribution/releases/tag/v3.1.2>
- Open Container Initiative, «Distribution Specification»: <https://github.com/opencontainers/distribution-spec/blob/main/spec.md>
- Open Container Initiative, «Image Index»: <https://github.com/opencontainers/image-spec/blob/main/image-index.md>
- Trivy, «Container Image» (`--input`, orden de fuentes): <https://trivy.dev/latest/docs/target/container_image/>
- Trivy, «Filtering» (`--severity`, `--ignore-unfixed`, `.trivyignore`): <https://trivy.dev/latest/docs/configuration/filtering/>
- Trivy, «Vulnerability» (cuándo se usa `UNKNOWN`): <https://trivy.dev/latest/docs/scanner/vulnerability/>
- Trivy, «Reporting» (tabla y niveles): <https://trivy.dev/latest/docs/configuration/reporting/>
- Trivy, referencia de `trivy image` (`--exit-code`, `--input`, `--ignorefile`): <https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/>
- Trivy, notas de la versión 0.76.0 (14 de octubre de 2026): <https://github.com/aquasecurity/trivy/releases/tag/v0.76.0>
- kind, «Quick Start» (`kind load docker-image`): <https://kind.sigs.k8s.io/docs/user/quick-start/>
- kind, notas de la versión 0.33.0 (nodo `kindest/node:v1.37.0`): <https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0>
- Kubernetes, «Install and Set Up kubectl on Linux»: <https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/>
- Kubernetes, «Images» (`imagePullPolicy`, *digests*, `:latest`): <https://kubernetes.io/docs/concepts/containers/images/>
- SPDX, «Overview»: <https://spdx.dev/about/overview/>
- SLSA, «Provenance» (v1.0): <https://slsa.dev/spec/v1.0/provenance>
- Codecov, «Bash Uploader Security Update» (el caso de la suma de verificación): <https://about.codecov.io/security-update/>

### Términos de esta lección

- **Registro** (*registry*): servicio que guarda imágenes y las entrega por una API HTTP estándar.
- **Repositorio**: el nombre de una imagen dentro de un registro; guarda todas sus versiones.
- **Referencia**: el texto que señala una imagen: registro, repositorio y etiqueta o *digest*.
- **Etiqueta** (*tag*): nombre legible y movible de una versión de una imagen.
- ***Digest***: huella `sha256:` del contenido de un manifiesto o un blob; no cambia.
- **Manifiesto**: documento JSON que lista las capas y la configuración de una imagen.
- **Índice** (*image index*): manifiesto que apunta a varios manifiestos, uno por plataforma, y a las atestaciones.
- **Plataforma**: sistema operativo más arquitectura de procesador, como `linux/arm64`.
- **Emulación (QEMU)**: fingir otro procesador por software; lenta y, en esta máquina, inestable.
- **Compilación cruzada** (*cross-compilation*): compilar en un procesador un binario para otro, sin ejecutar nada ajeno.
- **Atestación**: documento sobre una imagen que viaja en su índice; aquí, el SBOM y la procedencia.
- **SBOM**: lista de materiales de software; qué trae dentro la imagen.
- **SPDX**: estándar abierto para listas de materiales.
- **Procedencia** (*provenance*): cómo, dónde y con qué se construyó la imagen.
- **SLSA**: marco y formato para describir la procedencia.
- **Vulnerabilidad**: falla de seguridad pública, con un identificador (CVE, DSA…) y una gravedad.
- **Umbral**: gravedad mínima que cuenta como hallazgo en tu escaneo.
- **Código de salida**: número que un programa devuelve al terminar; 0 es éxito.
- **`.trivyignore`**: archivo con los identificadores de hallazgos que aceptas.
- **`kind load docker-image`**: copia una imagen del Docker local a los nodos de un clúster `kind`.
- **`imagePullPolicy: Never`**: política de Kubernetes que prohíbe descargar la imagen.
