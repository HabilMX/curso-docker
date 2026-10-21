# Curso de Docker — empaqueta un servicio y opéralo como se hace de verdad

**Por Dorian Chávez, fundador de Hábil y arquitecto de integración.**

**Para quién es:** quien ya programó algo —el `revisor` de los cursos de [Go](https://www.habil.mx/es/cursos/go/), [Rust](https://www.habil.mx/es/cursos/rust/) o [TypeScript](https://www.habil.mx/es/cursos/typescript/) de esta casa, o un servicio propio— y necesita empaquetarlo, correrlo y operarlo en contenedores sin copiar comandos a ciegas. Nivel intermedio: se supone que usas una terminal con soltura y que sabes qué es un servidor HTTP. No se supone que hayas tocado Docker: cada concepto se explica cuando aparece, y se explica por qué existe, no solo cómo se escribe. Y no hace falta programar nada nuevo: el curso te entrega el servicio hecho.

**Qué vas a terminar sabiendo:** convertir un servicio en una imagen pequeña, sin privilegios y reproducible; correrlo con límites, con salud y con apagado ordenado; manejar su configuración y sus secretos sin dejarlos dentro de la imagen; levantar varios contenedores que se hablan por nombre con un solo comando; y leer lo que Docker te dice cuando algo falla, en vez de buscar la respuesta a ciegas.

**Dónde sigue:** este curso es el escalón previo al [curso de **Kubernetes con kind**](https://www.habil.mx/es/cursos/kubernetes/) de esta casa, que toma la imagen con la que terminas aquí y la despliega, la configura, la escala y la protege en un clúster local.

**Lo que necesitas antes de empezar:** una computadora con Linux Mint 22.x y permiso de administrador (`sudo`). La [Lección 1](01-instalacion.md) instala Docker desde cero. Si vienes del curso de Go, Rust o TypeScript, ya conoces el problema que resuelve el `revisor`; si no, la lección 0 lo presenta en dos párrafos.

## El proyecto que vas a construir

El **`revisor`**: un servidor HTTP que consulta una lista de servicios **a la vez** y entrega, por `GET /api/estados`, un reporte con el nombre, el estado y el tiempo de respuesta de cada uno; y por `GET /salud`, la respuesta corta que dice si el proceso mismo está vivo. Se configura con variables de entorno (el puerto, la lista de servicios, la ruta donde guarda el reporte y un token de acceso). El servidor del `revisor` está escrito en **Go** (viene del curso de Go de esta casa) y compila a un binario estático; escucha en el puerto 8080, atiende `GET /salud` y `GET /api/estados`, se configura por variables de entorno y trae un subcomando `healthcheck` para poder vigilarse a sí mismo sin `curl`. No necesitas saber Go: el curso lo entrega y tú lo empaquetas.

El curso te lo entrega ya hecho, junto con un **servicio de prueba que falla a propósito** en tres modos —sano, lento y caído—. Con ese par de piezas haces todo el trabajo del curso: empaquetar, endurecer, configurar, dar salud, guardar datos, conectar y entregar. Es el mismo problema de los cursos de Go, Rust y TypeScript de esta casa: ya sabes qué hace el `revisor`, así que toda tu atención se queda en lo nuevo, que es **cómo viaja y cómo se opera**.

## Las once lecciones

| Lección | | Qué construyes | Qué aprendes |
|---|---|---|---|
| 0 | [Qué es un contenedor y qué NO es](00-que-es-un-contenedor.md) | nada todavía (lectura) | un contenedor es un proceso aislado, no una máquina virtual; imagen contra contenedor; el cliente y el daemon; qué se comparte con el anfitrión y por qué eso decide la seguridad |
| 1 | [Instalar Docker en tu Linux Mint](01-instalacion.md) | el entorno y tu primer contenedor | Docker Engine desde el repositorio oficial; Mint no es plataforma oficial y qué hacer; quitar los paquetes en conflicto; el grupo `docker` equivale a `root` |
| 2 | [Contenedores en el día a día](02-contenedores-dia-a-dia.md) | el servicio de prueba corriendo, consultado y limpio | `run`, `ps`, `logs`, `exec`, `stop`, `rm`, `inspect`; publicar puertos solo en `127.0.0.1`; límites de memoria y CPU; no dejar basura |
| 3 | [Tu primer Dockerfile](03-primer-dockerfile.md) | `curso-docker-revisor:1.x.0` en una sola etapa | instrucciones del Dockerfile; forma *exec* contra forma *shell*; `.dockerignore`; `USER`; etiquetas con versión; `docker build --check` |
| 4 | [Capas, caché y contexto](04-capas-cache-contexto.md) | la misma imagen, reconstruida en segundos | cómo se arma una imagen capa por capa; el orden de las instrucciones; `--progress=plain` y `docker history`; caché de compilación (`--mount=type=cache`); qué viaja en el contexto |
| 5 | [Multi-stage: de gigabytes a megabytes](05-multi-stage.md) | la imagen final mínima y sin privilegios | etapas de compilación, de pruebas y final; base mínima sin shell; versión y *digest* de la base; el binario que no arranca por no ser estático |
| 6 | [Configuración y secretos](06-configuracion-y-secretos.md) | el `revisor` configurado sin reconstruir | variables de entorno; `ARG` contra `ENV`; secretos de construcción; secretos en ejecución por archivo; mirar con tus ojos qué queda dentro de la imagen |
| 7 | [Salud y ciclo de vida](07-salud-y-ciclo-de-vida.md) | un contenedor que dice cómo está y muere bien | PID 1 y señales; el plazo de `docker stop`; `HEALTHCHECK` sin `curl`; políticas de reinicio; sistema de archivos de solo lectura; `--cap-drop`; `no-new-privileges` |
| 8 | [Volúmenes y redes](08-volumenes-y-redes.md) | el reporte que sobrevive y dos contenedores que se hablan | volúmenes con nombre, *bind mounts* y `tmpfs`; el dueño de los archivos con un usuario sin privilegios; redes definidas por el usuario; DNS por nombre; redes internas |
| 9 | [Compose: el sistema completo](09-compose.md) | `compose.yaml` con el `revisor` y su servicio que falla | servicios, redes, volúmenes y secretos en un archivo; `depends_on` con `service_healthy`; `compose config`; comparar tu archivo con el de `docker init` |
| 10 | [Entregar la imagen](10-entregar-la-imagen.md) | la imagen publicada, verificada y lista para Kubernetes | etiquetas y *digest*; registro local; escaneo de vulnerabilidades con Trivy; lista de materiales (SBOM) y procedencia; varias plataformas; el puente a `kind load docker-image` |

**Nombres con prefijo.** Todo lo que el curso crea en tu máquina (imágenes, contenedores, redes, volúmenes) lleva el prefijo `curso-docker-`; por eso la imagen de la lección 3 se llama `curso-docker-revisor:1.x.0` y no `revisor`. Así no choca con nada que ya tengas y puedes borrar solo lo del curso sin tocar lo demás.

Al final de cada lección hay ejercicios con sus soluciones. Y la [bitácora](bitacora.md) es tuya: anota ahí lo que te costó.

## Tres criterios que atraviesan todo el curso

**La seguridad no es una lección, es una costumbre.** No hay un módulo final de seguridad. Hay un hábito por lección, y cada uno se practica en el `revisor` y no en un ejemplo aparte:

| Lección | El hábito que se instala |
|---|---|
| 0 | saber qué comparte un contenedor con el equipo (el núcleo) y qué no |
| 1 | el grupo `docker` equivale a `root`: se concede sabiéndolo |
| 2 | puertos publicados solo en `127.0.0.1`; límites de memoria y CPU; jamás `--privileged` ni el *socket* de Docker dentro de un contenedor |
| 3 | el primer Dockerfile ya trae `USER`; `.dockerignore` desde el primer día; etiquetas con versión, nunca `latest` |
| 4 | el contexto de construcción no lleva `.git`, `.env` ni claves; la herramienta de revisión del Dockerfile se corre siempre |
| 5 | base mínima y sin shell; la base se fija por versión y por *digest*; la etapa de pruebas corre antes de empaquetar |
| 6 | los secretos no pasan por `ARG` ni `ENV`; se comprueba con `docker history` y `docker inspect` que no quedaron |
| 7 | sistema de archivos de solo lectura, sin capacidades que no se usan, sin escalada de privilegios, con un `init` |
| 8 | volúmenes con el dueño correcto; redes internas; nunca la red del anfitrión |
| 9 | el `compose.yaml` final nace con todo lo anterior, y sus secretos viven fuera del archivo |
| 10 | lo que se publica se escanea, trae su lista de materiales y se referencia por *digest* |

Un tema que se deja para el final es un tema que no se aprende.

**Un contenedor «corriendo» no es un servicio sano.** Casi todos los fallos de operación de este tema nacen de confundir las dos cosas: el proceso existe, pero no atiende. El servicio de prueba falla a propósito y cada lección te enseña a distinguir **lo que Docker cree de lo que de verdad pasa**.

**Solo se enseña lo vigente, y lo obsoleto se nombra para reconocerlo.** Compose es `docker compose` (el *plugin*), el archivo se llama `compose.yaml` y no lleva `version:`; `MAINTAINER` está en desuso. Cuando algo viejo aparece en un tutorial que vas a encontrar de todos modos, el curso te dice qué es y por qué ya no va. Y cada versión se da con su fecha: las de este curso se midieron el 7 de octubre de 2026 (Docker Engine 29.8.2, Compose v5.6.0).

## Cómo sabes que terminaste

El curso no se acaba cuando leíste la lección 10, sino cuando tu proyecto cumple estas seis cosas. Las cifras son metas de diseño: se miden y se ajustan al escribir las lecciones, y cada lección repite la que le toca ya medida.

1. **`docker compose up` levanta todo desde cero** y el reporte muestra el servicio de prueba caído como `FALLA`, sin que tengas que reiniciar nada a mano.
2. **La imagen final pesa decenas de megabytes** (meta), no cientos, no trae shell ni compilador, y **no corre como `root`** (lo compruebas con `docker exec` y con `docker inspect`).
3. **Ningún secreto aparece** en `docker history`, en `docker inspect` ni en las variables de entorno del contenedor.
4. **`docker stop` termina el contenedor en pocos segundos** (meta: menos de dos), porque el proceso recibe la señal y se apaga ordenadamente; y `docker ps` muestra `(healthy)` y, al romper el servicio, `(unhealthy)`.
5. **El reporte sobrevive a `docker rm`** y el `revisor` encuentra al otro contenedor por su nombre.
6. **La imagen publicada se referencia por *digest***, pasa el escaneo de Trivy con el umbral que fijaste y se carga en un clúster `kind` sin un solo error de descarga.
