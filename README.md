# Curso de Docker — empaqueta un servicio y opérelo como se hace de verdad

**Por Dorian Chávez, fundador de Hábil y arquitecto de integración.**

**Cada programa de este curso trae su salida esperada y se construye y se ejecuta para comprobarla.** Lo que lees y lo que corre no pueden diferir.

> El curso se escribe primero en español. Las traducciones (inglés, francés, portugués de Brasil y búlgaro) llegan después, con su propio registro.

## Dónde está el contenido

- **[Español — el curso completo](es/README.md)** ← empieza aquí

## Para quién es

Quien ya programó algo —el `revisor` de los cursos de [Go](https://www.habil.mx/es/cursos/go/), [Rust](https://www.habil.mx/es/cursos/rust/) o [TypeScript](https://www.habil.mx/es/cursos/typescript/) de esta casa, o cualquier servicio propio— y ahora necesita **empaquetarlo, correrlo y operarlo** en contenedores sin copiar comandos a ciegas. Nivel intermedio: se supone que sabes usar una terminal y que sabes qué es un servidor HTTP; no se supone que hayas tocado Docker. No hace falta programar nada nuevo: el curso te entrega el servicio ya hecho y el trabajo es todo de empaquetado y operación.

Es el escalón previo al [**curso de Kubernetes con kind**](https://www.habil.mx/es/cursos/kubernetes/) de esta casa, que toma la imagen con la que sales de aquí y la despliega en un clúster local.

## El proyecto que crece

El **`revisor`**, el mismo de los cursos de Go, Rust y TypeScript, ahora como **servicio**: un servidor HTTP que consulta una lista de servicios **a la vez** y entrega su reporte. El servidor del `revisor` está escrito en **Go** (viene del curso de Go de esta casa) y compila a un binario estático; escucha en el puerto 8080, atiende `GET /salud` y `GET /api/estados`, se configura por variables de entorno y trae un subcomando `healthcheck` para poder vigilarse a sí mismo sin `curl`. No necesitas saber Go: el curso lo entrega y tú lo empaquetas. El curso lo trae listo, con una salud (`/salud`), un reporte (`/api/estados`) y su configuración por variables de entorno; tú lo conviertes, lección a lección, en una imagen pequeña, sin privilegios, que se apaga bien, que dice si está sano, que guarda su reporte, que se habla con otros contenedores por nombre y que se levanta completa con un solo comando junto a un servicio de prueba **que falla a propósito**.

Se repite el proyecto y no se inventa otro por la misma razón que en los otros cursos: ves el mismo problema resuelto con otra herramienta, y de esa comparación se aprende más que de empezar de nuevo. Lo que cambia es cómo se entrega, no qué hace.

## Las lecciones

Numeración única y continua: «Lección N», de la 0 a la 10.

| # | Lección | Qué construyes | Qué aprendes |
|---|---|---|---|
| 0 | Qué es un contenedor y qué NO es | nada todavía (lectura) | un contenedor es un proceso aislado, no una máquina virtual; imagen contra contenedor; el cliente y el daemon; qué comparte con el equipo anfitrión y por qué eso importa para la seguridad |
| 1 | Instalar Docker en tu Linux Mint | el entorno y tu primer contenedor | Docker Engine desde el repositorio oficial, el caso especial de Mint, quitar paquetes en conflicto, el grupo `docker` y por qué equivale a `root` |
| 2 | Contenedores en el día a día | el servicio de prueba corriendo, consultado y limpio | `run`, `ps`, `logs`, `exec`, `stop`, `rm`, `inspect`; puertos y por qué `127.0.0.1`; límites de memoria y CPU; no dejar basura |
| 3 | Tu primer Dockerfile | `curso-docker-revisor:1.x.0` en una sola etapa | instrucciones del Dockerfile, forma *exec* contra forma *shell*, `.dockerignore`, `USER`, etiquetas con versión, `docker build --check` |
| 4 | Capas, caché y contexto | la misma imagen, reconstruida en segundos | cómo se arma una imagen capa por capa, orden de las instrucciones, `--progress=plain`, `docker history`, caché de compilación (`--mount=type=cache`), qué viaja en el contexto |
| 5 | Multi-stage: de gigabytes a megabytes | la imagen final mínima y sin privilegios | etapas de compilación, de pruebas y final; base mínima sin shell; versión y *digest* de la base; el binario que no arranca por no ser estático |
| 6 | Configuración y secretos | el `revisor` configurado sin reconstruir | variables de entorno, `ARG` contra `ENV`, secretos de construcción, secretos en ejecución por archivo; ver con tus ojos qué queda dentro de la imagen |
| 7 | Salud y ciclo de vida | un contenedor que dice cómo está y muere bien | PID 1 y señales, `docker stop` y su plazo, `HEALTHCHECK` sin `curl`, políticas de reinicio, sistema de archivos de solo lectura, capacidades fuera, `no-new-privileges` |
| 8 | Volúmenes y redes | el reporte que sobrevive y dos contenedores que se hablan | volúmenes con nombre, *bind mounts*, `tmpfs`, dueño de los archivos con un usuario sin privilegios; redes definidas por el usuario, DNS por nombre, redes internas |
| 9 | Compose: el sistema completo | `compose.yaml` con el `revisor` y su servicio que falla | servicios, redes, volúmenes y secretos en un archivo; `depends_on` con `service_healthy`; `compose config`; comparar tu archivo con el de `docker init` |
| 10 | Entregar la imagen | la imagen publicada por *digest*, con su lista de materiales y su escaneo revisado, y cargada en un clúster `kind` | etiquetas y *digest*, registro local, escaneo de vulnerabilidades con Trivy, lista de materiales (SBOM) y procedencia, varias plataformas; el puente a `kind load docker-image` |

**Nombres con prefijo.** Todo lo que el curso crea en tu máquina (imágenes, contenedores, redes, volúmenes) lleva el prefijo `curso-docker-`; por eso la imagen de la lección 3 se llama `curso-docker-revisor:1.x.0` y no `revisor`. Así no choca con nada que ya tengas y puedes borrar solo lo del curso sin tocar lo demás.

Lo que la tabla promete por lección es lo que la lección trae.

## Dos criterios que atraviesan todo el curso

**La seguridad no es una lección, es una costumbre.** No hay un módulo final de seguridad: en la lección 2 publicas los puertos solo en `127.0.0.1` y pones límites; en la 3 el primer Dockerfile ya trae `USER`; en la 5 la base es mínima y fijada; en la 6 los secretos nunca pasan por `ARG` ni `ENV`; en la 7 el contenedor corre con sistema de archivos de solo lectura y sin capacidades que no usa; en la 8 las redes internas no tienen salida; en la 9 el Compose final nace con todo eso; y en la 10 escaneas lo que publicas. Un tema que se deja para el final es un tema que no se aprende.

**Un contenedor «corriendo» no es un servicio sano.** Casi todos los errores de operación de este tema nacen de confundir las dos cosas: el proceso existe, pero no atiende. Por eso el servicio de prueba falla a propósito en tres modos (sano, lento, caído) y cada lección te enseña a **distinguir lo que Docker cree de lo que de verdad pasa**.

**Solo se enseña lo vigente, y lo obsoleto se nombra para reconocerlo.** Compose es `docker compose` (el *plugin*), el archivo se llama `compose.yaml` y no lleva `version:`; `MAINTAINER` ya no se usa. Si lo vas a encontrar en un tutorial viejo, el curso te dice qué es y por qué ya no va. Y cada cifra y cada versión se fija con su fecha, porque un curso que da una versión sin fecha envejece en un trimestre.

## La plantilla de cada lección

Igual en todas:

1. **Encabezado:** «Lección N — título», tiempo (90 min o 2 × 45) y «Al terminar vas a poder…» (3 a 7 objetivos).
2. **El porqué antes del cómo:** qué problema resuelve el concepto, con un ejemplo del `revisor`.
3. **Los conceptos**, uno por sección: explicación, ejemplo mínimo ejecutable y ejemplo en el `revisor`.
4. **El error que vas a ver:** el mensaje real de Docker, qué significa y cómo se arregla. Primero se provoca, después se corrige.
5. **El hábito de seguridad de la lección:** qué se endurece aquí y qué ataque o accidente evita.
6. **Lo que se hace mal** (antipatrones), con el porqué.
7. **Ejercicios** (2 a 4), de menor a mayor, con sus **soluciones** aparte.
8. **Cómo sé que lo logré:** medible; tal comando da tal salida.
9. **Fuentes:** documentación oficial y especificaciones, con enlace.

## Versiones con las que se escribió

Medidas el 7 de octubre de 2026 en las páginas oficiales de cada proyecto: **Docker Engine 29.8.2**, **Docker Compose v5.6.0**, Linux Mint 22.x (base Ubuntu 24.04). Cada lección repite la versión que usa y la fecha, y te enseña a comprobar la tuya con `docker version`.

## Cómo se organizan los programas

Cada programa es una carpeta `programas/NN-nombre/` con lo que la lección construye (`Dockerfile`, `compose.yaml`, guiones, el servicio de prueba), una forma de correrlo de principio a fin y su salida esperada. Como algunas salidas cambian en cada corrida (identificadores, fechas, tiempos), la lección marca cuáles líneas son estables y solo esas se comparan. Los programas que a propósito fallan traen el mensaje que la lección enseña a leer. **Las lecciones son la fuente:** los programas se extraen de sus bloques de código.

## La profundidad se mide

Cada lección tiene al menos 3,000 palabras de explicación (lo que está fuera de los bloques de código), con piso de 3,000 por lección y mediana del curso de 4,000, como las de los cursos de Go, Rust y TypeScript. Se cuentan palabras y no líneas porque las líneas se inflan.

## Qué es un programa y qué es un fragmento

**No todo bloque de código de este curso es un programa completo.** Un **programa** corre solo, de principio a fin: vive en su carpeta de `programas/` y trae su corrida real (el comando y la salida). Su salida documentada se compara contra la real. Un **fragmento** es una ilustración (tres líneas de un Dockerfile para explicar una instrucción, por ejemplo) que no pretende correr por sí sola, y por eso no se verifica; se reconoce porque su bloque no está marcado como programa.

## Reglas del repositorio

- **Licencia CC BY-SA 4.0:** el material es público y se puede reusar citando la fuente.
- **Multiidioma:** `es/` es el original; las traducciones se agregan después en carpetas hermanas.
- Los secretos que aparecen en el curso son de mentira, generados para el ejercicio, y nunca de un servicio real.
- Sin emojis en los títulos de las lecciones.
