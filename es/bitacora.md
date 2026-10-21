# Bitácora

Esto es tuyo. Es lo que vuelve el curso *tu* curso.

**Qué anotar:** lo que no entendiste a la primera · el mensaje de error que no supiste leer · lo que creías de los contenedores y resultó distinto · lo que te sorprendió · los números que mediste (tamaños, tiempos).

**Por qué importa:** en dos semanas no vas a recordar qué te costó. Y lo que te costó es exactamente lo que hay que repasar.

---

## Lección 0 — Qué es un contenedor y qué NO es

_fecha:_

- Lo que creía que era un contenedor:
- Con mis palabras, la diferencia entre imagen y contenedor:
- Lo que me sorprendió:

## Lección 1 — Instalar Docker en tu Linux Mint

_fecha:_

- Versiones que me salieron (`docker version`, `docker compose version`):
- El error de permisos que provoqué a propósito y cómo lo leí:
- ¿Tenía paquetes en conflicto? Cuáles:

## Lección 2 — Contenedores en el día a día

_fecha:_

- Un contenedor que dejé corriendo sin darme cuenta:
- Qué cambia entre `-p 8080:8080` y `-p 127.0.0.1:8080:8080` (lo comprobé con `ss -ltn`):

## Lección 3 — Tu primer Dockerfile

_fecha:_

- Tamaño de `curso-docker-revisor:1.0.0`: ____ GB
- Lo que me avisó `docker build --check`:
- Cuánto tarda `docker stop` con la forma *shell* y con la forma *exec*: ____ s y ____ s

## Lección 4 — Capas, caché y contexto

_fecha:_

- Reconstrucción antes de reordenar: ____ s → después: ____ s
- Tamaño del contexto con y sin `.dockerignore`:
- La capa más pesada de mi imagen (`docker history`):

## Lección 5 — Multi-stage: de gigabytes a megabytes

_fecha:_

- Tamaño antes: ____ → después: ____
- El error de «no such file or directory» que vi con el binario no estático y por qué:
- Qué fijé de la base: versión, *digest* o las dos:

## Lección 6 — Configuración y secretos

_fecha:_

- Un secreto que puse en `ENV` y dónde lo encontré después:
- Cómo se lo pasé al `revisor` de la forma correcta:

## Lección 7 — Salud y ciclo de vida

_fecha:_

- Estados que vi en el healthcheck (`starting`, `healthy`, `unhealthy`) y qué los provocó:
- Qué rompió cuando puse el sistema de archivos en solo lectura y cómo lo resolví:
- Capacidades que el `revisor` no necesitaba:

## Lección 8 — Volúmenes y redes

_fecha:_

- Lo que desapareció cuando monté un volumen sobre un directorio con contenido:
- El permiso que me negó escribir en el volumen y cómo lo arreglé sin volver a `root`:
- Nombre con el que el `revisor` encontró al otro contenedor:

## Lección 9 — Compose: el sistema completo

_fecha:_

- Qué pasó cuando quité la condición `service_healthy`:
- Qué diferencias encontré entre mi `compose.yaml` y el que generó `docker init`:

## Lección 10 — Entregar la imagen

_fecha:_

- Vulnerabilidades que encontró el escaneo y cuáles me importan de verdad:
- La etiqueta y el *digest* de mi imagen final:
- Lo que me falta para llevarla a Kubernetes:

---

## Lo que quiero construir después

_La lista de cosas que se te ocurran mientras avanzas. Es la mejor señal de que el curso funcionó._

-
