# Lección 7 — Salud y ciclo de vida

Son las 11:15 de la noche del viernes y la ventana de mantenimiento cierra a las 11:30. El plan es sencillo: actualizar el servidor donde corre el `revisor` y otros diecinueve contenedores, reiniciarlo y volver a casa. Alguien los detiene uno por uno, con un ciclo `for … docker stop`, y la terminal se queda pensando. Diez segundos. Otros diez. Otros diez. Tres minutos después termina, y casi todos quedaron marcados con un `Exited (137)`, que significa «lo mataron». El servidor vuelve a arrancar a las 11:24 y todo dice `Up`. A las 11:26, el tablero de monitoreo sigue en rojo: uno de los servicios está «arriba» pero contesta `503` a todo, y el contenedor que dependía de él se reinicia una y otra vez, cada vez un poco más tarde. Nadie sabe si los contenedores que murieron con 137 alcanzaron a guardar lo que estaban escribiendo. Quedan cuatro minutos y la pregunta es la de siempre: ¿qué está corriendo, qué está sano, y qué está fingiendo? Esta lección existe para que puedas contestarla en segundos: un contenedor que dice cómo está, que muere en orden cuando se lo pides y que, mientras vive, no puede hacer más de lo que necesita.

**Tiempo:** 2 × 45 min

**Qué construyes:** un contenedor que dice cómo está y muere bien. La imagen `curso-docker-revisor:1.4.0` trae su propia revisión de salud (`HEALTHCHECK`), hecha con el mismo binario y sin `curl`, y declara su señal de apagado (`STOPSIGNAL`). Y el contenedor corre endurecido: sistema de archivos de solo lectura, sin ninguna capacidad de `root`, sin poder ganar privilegios nuevos, con un *init* diminuto como proceso número 1, con límites y con una política de reinicio. Esas opciones son las que la Lección 9 pasa a Compose.

**Qué aprendes:** qué es una señal, por qué el proceso número 1 de un contenedor es especial y cómo leer los códigos `0`, `1`, `137` y `143`; el plazo de `docker stop` y cómo cambiarlo; qué hace `--init` y qué es un zombi; `HEALTHCHECK` sin `curl` y la diferencia entre «corriendo» y «sano»; las cuatro políticas de reinicio y lo que **no** hacen; `--read-only` con un `tmpfs` donde hace falta; `--cap-drop ALL`; y `no-new-privileges`, con un programa *setuid* que lo demuestra.

**De dónde vienes.** De la [Lección 6](06-configuracion-y-secretos.md) traes la imagen `curso-docker-revisor:1.3.0`: multi-etapa, 16.1 MB, sin *shell*, con el usuario `65532`, su versión grabada y nada de ningún ambiente. De la [Lección 3](03-primer-dockerfile.md) traes una medición que no se olvida: con `CMD` en forma *shell*, `docker stop` tardó más de diez segundos y el contenedor murió con `137`, porque la señal nunca le llegó al `revisor`. De la [Lección 2](02-contenedores-dia-a-dia.md) traes el `(health: starting)` que viste en el servicio de prueba sin saber todavía de dónde salía, y la costumbre de poner límites de memoria, CPU y procesos. Y de la [Lección 0](00-que-es-un-contenedor.md) traes la idea central: un contenedor es un proceso de tu equipo, con el mismo núcleo, y el `root` de dentro tiene catorce capacidades que hoy le vas a quitar.

**Qué no hace esta lección.** No explica a fondo los montajes: el `tmpfs` de la sección 7.7 se usa aquí para una sola carpeta, y la [Lección 8](08-volumenes-y-redes.md) explica volúmenes, *bind mounts* y `tmpfs` completos. No usa la salud para ordenar el arranque de varios servicios (`depends_on` con `service_healthy`): eso es la [Lección 9](09-compose.md). No toca perfiles de *seccomp* ni de AppArmor, ni Docker sin `root`: son capas que Docker ya pone por omisión o que requieren otra instalación, y este curso se queda con las opciones que cualquiera puede escribir en un `docker run`. Y no reinicia el daemon de Docker para probar `unless-stopped` contra `always`: eso apagaría todos los contenedores del equipo, y la diferencia se explica con la documentación.

**Sobre las corridas.** Todas las salidas son reales y se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual con Ubuntu 24.04.4, la misma base de Linux Mint 22, el sistema de referencia del curso, con núcleo 6.8 y procesador `arm64`. Los guiones se corrieron **dentro** de esa máquina virtual, con Docker 29.2.1 (cliente y daemon), y con su carpeta de trabajo en el disco propio de Linux. Para no chocar con otras corridas que usaban la misma máquina, los guiones se lanzaron con otro prefijo de nombres y otros puertos (las variables `PREFIJO` y `PUERTO` que traen); ningún nombre de contenedor ni de imagen, ni el puerto del equipo, aparece en sus salidas, así que lo que ves es exactamente lo que imprimieron. Con sus valores por omisión, los guiones usan nombres de apoyo propios que llevan `fig07` (la imagen `curso-docker-revisor:fig07`, el contenedor `curso-docker-revisor-fig07`): así nunca tocan tu imagen `curso-docker-revisor:1.4.0` ni tu contenedor `curso-docker-revisor`, y al salir borran solo lo que crearon. El curso se planeó con Docker Engine 29.8.2, y la más reciente publicada ese día era la 29.9.2, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)); nada de esta lección cambia entre esas versiones. Lo que **sí** cambia de una corrida a otra, y se avisa donde aparece: los números de proceso (tapados con `<pid>` en el propio guion; los guiones que los usan se detienen si el contenedor no está corriendo, porque un número `0` apuntaría a procesos de tu equipo), los milisegundos de cada `docker stop` y de cada reinicio, los segundos de `Up` y el número del archivo temporal del reporte (tapado con `<n>`). La máquina virtual era compartida con otros trabajos, y en algunas corridas estaba cargada: por eso unos tiempos salieron más largos que otros, y donde importa se dice. Los guiones publican en los puertos 8080 (`fig07_03.sh` y `fig07_06.sh`) y 9000 (`fig07_04.sh`) de tu equipo: si tu `curso-docker-revisor` o tu `curso-docker-prueba` están corriendo, bórralos antes o lanza el guion con otro puerto, por ejemplo `PUERTO=18080 ./fig07_03.sh`; si no, el guion se detiene con `port is already allocated`. Un guion, `fig07_05.sh`, usa `sudo` una vez, para matar un proceso desde fuera como lo haría el núcleo; en tu Mint te va a pedir tu contraseña. Los programas están en [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida), cada uno con su salida al lado, y `estado/` guarda los archivos del proyecto tal como quedan al terminar.

## Al terminar vas a poder

- Leer el código de salida de un contenedor (`0`, `1`, `137`, `143`) y decir qué señal lo terminó o si terminó solo.
- Explicar por qué un programa que muere con `SIGTERM` en tu terminal ignora la misma señal cuando es el proceso número 1 de un contenedor, y arreglarlo con `--init`.
- Medir cuánto tarda `docker stop` y cambiar su plazo y su señal con `-t`, `--stop-timeout`, `STOPSIGNAL` y `--stop-signal`.
- Escribir un `HEALTHCHECK` en forma *exec* para una imagen sin *shell* ni `curl`, y leer la salud de un contenedor con `docker ps` y `docker inspect`.
- Elegir una política de reinicio para un servicio y predecir qué hace Docker cuando el proceso muere solo, cuando lo detienes tú y cuando está `unhealthy`.
- Correr el `revisor` con `--read-only`, `--cap-drop ALL` y `--security-opt no-new-privileges`, y comprobar en `/proc` que el núcleo aplica las tres cosas.

## El porqué antes del cómo

Hasta ahora has tratado al contenedor como algo que arranca. Esta lección se ocupa de todo lo demás: de cómo **muere**, de cómo dice **si está bien** mientras vive y de **qué puede hacer** mientras tanto. Son tres preguntas distintas, y las tres aparecieron en la escena del principio.

La primera es la del apagado. Un contenedor no se apaga como una máquina: Docker le manda una **señal** a su proceso principal y espera. Si el proceso atiende la señal, termina lo que estaba haciendo y sale; si no, al vencer el plazo Docker lo mata. Ya lo viste en la Lección 3 con la forma *shell*. Lo nuevo es que no basta con escribir bien el `CMD`: hay programas que, siendo el proceso número 1, no reciben la señal aunque estén en forma *exec*, y la lección te muestra uno, mide cuánto cuesta y lo arregla.

La segunda es la salud. Para Docker, un contenedor está `Up` mientras su proceso exista. No sabe si ese proceso contesta, si contesta bien o si se quedó atorado esperando algo que nunca va a llegar. El README del curso lo pone como uno de sus dos criterios: **un contenedor «corriendo» no es un servicio sano**. Una revisión de salud es la forma de que el contenedor, desde dentro, le diga a Docker la diferencia. Y la imagen del `revisor` no tiene `curl`, ni *shell*, así que la revisión tiene que salir de otro lado.

La tercera es el poder. Un contenedor que funciona bien igual puede ser el punto de entrada de un ataque: si alguien encuentra una falla en el programa, hereda todo lo que el proceso puede hacer. Las lecciones 3 y 5 ya le quitaron `root` y el *shell*. Aquí se quitan tres cosas más: la posibilidad de escribir en su propio sistema de archivos, las capacidades de `root` que no usa y la posibilidad de ganar privilegios nuevos al ejecutar otro programa.

Con ese destino en mente, esto es lo que verás en la sección 7.10, cuando las tres respuestas se junten. El `revisor` corre con todo lo de la lección, el núcleo confirma que no tiene ninguna capacidad y que no puede ganar privilegios, y aun así se apaga en orden en un par de décimas de segundo:

```text
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
```

## Los conceptos

### 7.1 El proceso número 1 y las señales

#### 7.1.1 Qué es una señal

Una **señal** es un aviso corto que el núcleo de Linux le entrega a un proceso. No lleva datos: solo un número, que dice qué pasó o qué se le pide. Cuando presionas `Ctrl+C` en la terminal, el núcleo le manda al programa la señal `SIGINT`; cuando un administrador escribe `kill <pid>`, le manda `SIGTERM`. El manual de Linux las lista con su número y su **acción por omisión**, que es lo que pasa si el programa no hizo nada especial para atenderlas ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)):

| Señal | Número | Qué pide | Acción por omisión |
|---|---|---|---|
| `SIGINT` | 2 | interrupción desde el teclado (`Ctrl+C`) | terminar |
| `SIGKILL` | 9 | morir, ya | terminar; **no se puede atrapar, bloquear ni ignorar** |
| `SIGTERM` | 15 | terminar, por favor | terminar |

Un programa puede **instalar un manejador** para una señal: una función que se ejecuta cuando la señal llega, en lugar de la acción por omisión. Eso es lo que hace el `revisor`: pide al núcleo que le avise de `SIGTERM` y de `SIGINT`, y cuando llega una deja de aceptar peticiones nuevas, espera hasta cinco segundos a que terminen las que estaban en curso y sale con código 0. Es lo que llevas viendo desde la Lección 3 en sus registros: `recibí terminated, apagando` y `apagado limpio`. Sobre `SIGKILL` no hay manejador posible; el manual lo dice con todas sus letras: «`SIGKILL` y `SIGSTOP` no se pueden atrapar, bloquear ni ignorar».

#### 7.1.2 Cómo se lee el final de un contenedor

Cuando un proceso termina, deja un **código de salida**. Si terminó solo, es el número que el programa eligió: `0` para «todo bien», cualquier otro para «algo falló» (el `revisor` usa `1` cuando le falta configuración). Si lo terminó una señal, la convención de los *shells*, que Docker sigue, es **128 más el número de la señal**. De ahí salen los dos números que más vas a ver:

| Código | Cómo se lee |
|---|---|
| `0` | terminó solo y bien; con el `revisor`, después de un apagado en orden |
| `1` | terminó solo, con un error del propio programa |
| `137` | 128 + 9: lo mató `SIGKILL`; nadie le preguntó |
| `143` | 128 + 15: lo terminó `SIGTERM` con la acción por omisión, sin manejador |

Fíjate en la diferencia entre `0` y `143`. Los dos son apagados pedidos con `SIGTERM`; en el primero, el programa atendió la señal y salió por su cuenta; en el segundo, el núcleo lo terminó porque el programa no tenía manejador. Los dos son razonables. El que debe preocuparte es `137` en un apagado normal: significa que se acabó el plazo y Docker tuvo que matar.

#### 7.1.3 Por qué el número 1 es especial

En la Lección 0 viste que dentro de un contenedor el programa principal es el proceso número 1. Ese número tiene un trato especial en Linux, que el manual de los espacios de nombres de procesos describe así: al proceso «*init*» de un espacio de nombres solo se le pueden mandar las señales **para las que estableció un manejador**; las demás no le hacen nada. Y hay una excepción: `SIGKILL` y `SIGSTOP` «se entregan a la fuerza cuando vienen de un espacio de nombres ancestro» ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). La referencia de `docker run` lo resume en una frase: un proceso que corre como PID 1 «ignora cualquier señal cuya acción sea la de omisión» ([referencia de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).

Léelo con calma, porque es el centro de esta sección. Un programa que **no** instaló un manejador para `SIGTERM` muere con ella en tu terminal, porque la acción por omisión es terminar. El mismo programa, siendo el número 1 de un contenedor, **no** muere: la acción por omisión ya no se aplica. La protección tiene sentido para el *init* de una máquina, que nunca debería morir por accidente; en un contenedor, el *init* es tu programa, y esa protección se vuelve un problema.

#### 7.1.4 Medirlo con un programa que no sabe apagarse

El `revisor` sí instala su manejador, así que no sirve para ver el problema. Para verlo hace falta un programa que no lo instale, y hay uno en todas las imágenes de Debian: `sleep`, que solo espera los segundos que le pidas. El guion `fig07_02.sh` no construye nada; usa la imagen de Go que ya tienes desde la Lección 3:

```bash
#!/usr/bin/env bash
# fig07_02.sh — El proceso número 1 y las señales, con un programa que NO sabe
# apagarse: sleep. Mide cuánto tarda docker stop, con qué código muere el
# contenedor, qué cambia con -t y con --init, y quién recoge a los zombis.
# No construye nada: usa la imagen de Go que ya bajaste para el revisor.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor
# ni tu imagen curso-docker-revisor:1.4.0, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}fig07-sleep"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
# detener [opciones de docker stop]: detiene el contenedor, mide y dice cómo murió
detener() {
  local inicio fin
  inicio=$(t); docker stop "$@" "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop${*:+ $*} tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
  docker rm -f "$NOMBRE" >/dev/null
}

echo "== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
PID1=$(pid_de "$NOMBRE")
grep -E '^SigCgt' "/proc/$PID1/status"
detener

echo
echo "== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
detener -t 2

echo
echo "== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM"
sleep 300 & HIJO=$!
kill -TERM "$HIJO"; rc=0; wait "$HIJO" || rc=$?
echo "sleep en el equipo murió con código $rc"

echo
echo "== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep"
docker run -d --init --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
detener

echo
echo "== 5. Zombis: un hijo huérfano termina y nadie lo recoge"
# El subshell lanza «sleep 1» y se va; ese sleep queda huérfano y el núcleo se
# lo entrega al proceso 1. Después, exec convierte al shell en «sleep 300».
docker run -d --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- docker top:"
docker top "$NOMBRE" -o pid,stat,args | sed -E 's/^ *[0-9]+ /<pid> /'
echo "-- ps en el equipo, hijos del proceso 1 del contenedor:"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. Lo mismo con --init: el init recoge al huérfano"
docker run -d --init --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
```

```text
$ ./fig07_02.sh
== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM
PID                 PPID                COMMAND
<pid> <ppid>             sleep 300
SigCgt:	0000000000000000
docker stop tardó 11315 ms; ExitCode=137

== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)
docker stop -t 2 tardó 2707 ms; ExitCode=137

== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM
sleep en el equipo murió con código 143

== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep
PID                 PPID                COMMAND
<pid> <ppid>             /sbin/docker-init -- sleep 300
<pid> <ppid>             sleep 300
docker stop tardó 251 ms; ExitCode=143

== 5. Zombis: un hijo huérfano termina y nadie lo recoge
-- docker top:
PID                 STAT                COMMAND
<pid>             Ss                  sleep 300
-- ps en el equipo, hijos del proceso 1 del contenedor:
STAT COMMAND
Z    [sleep] <defunct>

== 6. Lo mismo con --init: el init recoge al huérfano
-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):
STAT COMMAND
S    sleep 300
```

Hay renglones nuevos en el guion. La función `detener` mide cuánto tarda `docker stop` y lee el código de salida con `docker inspect`, como hiciste en la Lección 3. El `sed` que sigue a `docker top` tapa los números de proceso con `<pid>` y `<ppid>`, porque cambian en cada corrida. Y el `grep` del bloque 1 lee un archivo que no es del contenedor sino del núcleo: `/proc/<número>/status`, el estado de un proceso visto desde tu equipo. `docker inspect --format '{{.State.Pid}}'` da el número que ese proceso tiene **en tu equipo**, que no es 1; el 1 es el número que tiene dentro.

Ahora los bloques 1 a 3; los demás se leen en 7.3.

1. **`sleep` es el número 1 y no atiende nada.** `docker top` muestra un solo proceso, `sleep 300`. El renglón `SigCgt` dice qué señales tiene **atrapadas** el proceso, es decir, para cuáles instaló un manejador, como una máscara de bits en hexadecimal: cada bit encendido es una señal. Todo en cero: ninguna. Y `docker stop` tardó **11,315 ms** y dejó `ExitCode=137` (en una corrida con la máquina menos cargada, 10,097 ms: el plazo son los 10,000, y el resto es Docker y la carga del equipo). La secuencia es la de la Lección 3: `SIGTERM` al número 1, que la ignora porque no tiene manejador; diez segundos de espera; `SIGKILL`, que llega a la fuerza.
2. **El plazo se puede cambiar.** Con `docker stop -t 2`, el mismo `sleep` murió en **2,707 ms**, también con `137` (2,124 en la corrida menos cargada). El plazo cambió; el final, no. Acortar el plazo no arregla nada: solo hace que maten antes.
3. **Fuera del contenedor, el mismo programa sí muere.** El guion lanza `sleep 300` en tu propio equipo, le manda `SIGTERM` con `kill` y lee su código: `143`, que es 128 + 15. Mismo programa, misma señal, ningún manejador: en tu equipo `sleep` es un proceso cualquiera y la acción por omisión se aplica; en el contenedor era el número 1 y no.

Compara este bloque 1 con la forma *shell* de la Lección 3. Allí el número 1 era `/bin/sh` y el `revisor` estaba debajo; aquí no hay *shell* en medio, el `CMD` es *exec* y aun así pasa lo mismo. La forma *exec* garantiza que tu programa sea el número 1; **no** garantiza que tu programa sepa serlo.

> [!NOTE]
> 🔧 **Observación de ingeniería 7.1**
> Muchos programas no instalan manejadores porque en una máquina normal no les hace falta: la acción por omisión de `SIGTERM` ya los termina. Guiones de *shell*, herramientas de línea de comandos, servidores escritos con prisa. Cuando los metes a un contenedor como número 1, cada `docker stop` les cuesta el plazo completo. Antes de decidir nada, mira la línea `SigCgt` de tu proceso: si el bit de `SIGTERM` (el valor `4000` en hexadecimal) está apagado, ese programa necesita ayuda.

### 7.2 El plazo de `docker stop`, y quién decide la señal

#### 7.2.1 Lo que hace `docker stop`, paso a paso

La documentación lo describe así: el proceso principal del contenedor «recibe `SIGTERM` y, después de un periodo de gracia, `SIGKILL`». Si el contenedor no tiene configurada otra señal, se usa `SIGTERM`. El plazo «lo determina el daemon» y es de **10 segundos** para contenedores de Linux (30 para los de Windows); con `-t` o `--timeout` lo cambias para esa llamada, y con `-t -1` Docker espera para siempre ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

Hay tres lugares donde se puede cambiar el comportamiento, y conviene saber cuál gana:

| Dónde | Qué cambia | Alcance |
|---|---|---|
| `STOPSIGNAL` en el Dockerfile | la señal que manda `docker stop` | todos los contenedores de esa imagen |
| `docker run --stop-signal` | la señal, para ese contenedor | gana sobre la de la imagen |
| `docker run --stop-timeout` | el plazo, para ese contenedor | queda guardado en el contenedor |
| `docker stop -t N` / `-s SEÑAL` | plazo y señal, para esa llamada | gana sobre todo lo anterior |

La referencia del Dockerfile precisa que `STOPSIGNAL` solo vale para las señales que manda Docker (`docker stop` y el propio daemon); un `Ctrl+C` en una terminal conectada al contenedor sigue mandando `SIGINT` directo al proceso ([referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/)). Si no pasas `--stop-signal` al correr ni `-s` al detener, Docker usa el `STOPSIGNAL` de la imagen, y si la imagen no declara ninguno, `SIGTERM` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

Y está `docker kill`, que no espera: manda una señal y ya. Sin `-s`, la señal es `SIGKILL` ([`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/)). Sirve cuando algo está colgado y no hay nada que salvar; no es la forma normal de apagar.

#### 7.2.2 `STOPSIGNAL` en el `revisor`

El Dockerfile de esta lección declara `STOPSIGNAL SIGTERM`. Es la señal por omisión, así que no cambia el comportamiento; el comentario del Dockerfile lo dice: escribirla documenta la intención. Quien lea la imagen, o quien la inspeccione con `docker image inspect --format '{{.Config.StopSignal}}'`, sabe qué señal espera el programa sin abrir su código. Hay programas que esperan otra (algunos servidores web hacen un apagado ordenado con `SIGQUIT` y uno brusco con `SIGTERM`); ahí `STOPSIGNAL` deja de ser documentación y se vuelve necesario.

#### 7.2.3 Por qué el `revisor` espera cinco segundos y no diez

El código del `revisor` tiene una constante, `PlazoApagado`, de cinco segundos: es lo que espera a las peticiones en curso antes de rendirse. Su comentario explica el número: es menor que los diez de `docker stop` «para que el proceso termine solo y no lo maten». Es la regla que conviene seguir con cualquier servicio: **tu plazo interno de apagado tiene que caber en el plazo de quien te apaga**. Si tu programa necesita veinte segundos para vaciar una cola, súbele el plazo al contenedor con `--stop-timeout 30`; no esperes que Docker adivine.

### 7.3 `--init`: un *init* diminuto para el número 1

#### 7.3.1 Qué hace

Si el programa no sabe ser el número 1, la salida limpia es no ponerlo de número 1. `docker run --init` arranca primero un programa pequeño, `docker-init`, que se vuelve el número 1 y arranca tu programa como su hijo. La referencia de `docker run` dice que un proceso *init* asegura que «las responsabilidades usuales de un sistema *init*, como recoger procesos zombis, se cumplan dentro del contenedor», y que ese `docker-init`, incluido en la instalación normal, está hecho con [tini](https://github.com/krallin/tini). El propio proyecto de tini se describe como un *init* mínimo que arranca un solo hijo y espera a que termine «recogiendo zombis y reenviando señales mientras tanto», y avisa que desde Docker 1.13 viene incluido en Docker, sin instalar nada en la imagen.

Son dos trabajos, y los bloques 4 a 6 de `fig07_02.sh` muestran los dos.

#### 7.3.2 El primer trabajo: reenviar señales

El bloque 4 corre el mismo `sleep 300` con `--init`. `docker top` ahora muestra dos procesos: `/sbin/docker-init -- sleep 300` y, debajo, `sleep 300`. El número 1 es `docker-init`, que sí tiene manejadores para las señales; cuando `docker stop` le manda `SIGTERM`, la reenvía a su hijo. Para el hijo, `SIGTERM` es una señal cualquiera, porque **no** es el número 1, así que la acción por omisión se aplica y muere. `docker-init` ve morir a su hijo y sale con el mismo código. Resultado: **251 ms** en lugar de 11,315 (88 ms en la corrida menos cargada), y `ExitCode=143`, el mismo 128 + 15 que diste en tu terminal en el bloque 3. Sin cambiar una línea del programa.

#### 7.3.3 El segundo trabajo: recoger zombis

Cuando un proceso termina, no desaparece del todo: queda un renglón en la tabla de procesos con su código de salida, esperando a que su padre lo lea. Mientras nadie lo lee, ese proceso es un **zombi**: no corre, no usa memoria, pero ocupa un número de proceso. Si el padre muere antes que el hijo, el núcleo le asigna al huérfano un padre nuevo: el *init* de su espacio de nombres. Así que, dentro de un contenedor, todos los huérfanos acaban como hijos del número 1, y el número 1 tiene que recogerlos.

El bloque 5 lo provoca. El contenedor corre `sh -c '(sleep 1 &); exec sleep 300'`: un *subshell* lanza `sleep 1` en segundo plano y se va, así que ese `sleep 1` queda huérfano y pasa a ser hijo del número 1; después, `exec` reemplaza al *shell* por `sleep 300`, que se vuelve el número 1. Un segundo después el huérfano termina, y su nuevo padre, `sleep 300`, no tiene idea de que debe recogerlo. Mira las dos vistas del bloque:

- **`docker top` no lo muestra.** Solo aparece `sleep 300`. `docker top` pregunta por los procesos que pertenecen al grupo de control del contenedor, y un proceso que ya terminó sale de ese grupo aunque su renglón siga en la tabla. Es una medición que vale la pena recordar: si buscas zombis, `docker top` no es la herramienta.
- **`ps` en tu equipo sí lo muestra.** Con `--ppid` le pides los hijos del número 1 del contenedor, y aparece `Z    [sleep] <defunct>`: estado `Z`, de zombi, y la palabra `defunct`, difunto.

El bloque 6 repite lo mismo con `--init`. Ahora el huérfano se lo asignan a `docker-init`, que sí sabe recoger hijos. Los hijos del número 1 son solo el *shell* convertido en `sleep 300`; del zombi, nada.

Un zombi no hace daño; miles sí. Cada uno ocupa un número de proceso, y en la Lección 2 le pusiste al contenedor `--pids-limit 50`. Un programa que lanza procesos auxiliares y no los recoge acaba, con el tiempo, sin poder lanzar ninguno más.

#### 7.3.4 ¿Y el `revisor`? Lo necesita menos de lo que parece

Seamos precisos, porque aquí es fácil exagerar. El `revisor` instala su manejador para `SIGTERM` (lo verás apagarse en menos de un segundo sin `--init` en la sección 7.4) y no lanza procesos hijos, así que no deja zombis. Hoy **no necesita** `--init`. El curso lo usa igual, por dos razones. La primera: cuesta casi nada (un proceso diminuto más, y cuatro letras). La segunda: el día que alguien cambie el programa, o lo envuelva en un guion de arranque, o le agregue una herramienta que lance procesos, la imagen sigue apagándose bien sin que nadie tenga que acordarse de esta lección. Es un seguro barato, y por eso va en las opciones endurecidas que la Lección 9 copia a Compose.

### 7.4 `HEALTHCHECK` sin `curl`

#### 7.4.1 La instrucción

`HEALTHCHECK` le dice a Docker cómo preguntarle a un contenedor si está bien. Docker corre ese comando **dentro** del contenedor cada cierto tiempo y mira su código de salida. La referencia del Dockerfile define tres valores: `0` es éxito («el contenedor está sano y listo para usarse»), `1` es «no sano» y `2` está reservado: no lo uses. Las opciones, con sus valores por omisión según la misma referencia ([referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/)):

| Opción | Qué es | Por omisión | En el `revisor` |
|---|---|---|---|
| `--interval` | cada cuánto se revisa | `30s` | `10s` |
| `--timeout` | cuánto puede tardar una revisión antes de contar como falla | `30s` | `3s` |
| `--start-period` | tiempo de arranque: las fallas aquí no cuentan | `0s` | `5s` |
| `--start-interval` | cada cuánto se revisa **durante** el tiempo de arranque | `5s` | (el de omisión) |
| `--retries` | cuántas fallas seguidas hacen falta para declararlo no sano | `3` | `3` |

Un Dockerfile solo puede tener **un** `HEALTHCHECK`; si escribes varios, vale el último. `HEALTHCHECK NONE` apaga la que herede de su imagen base. Lo que el comando escriba en su salida se guarda junto al resultado, y se lee con `docker inspect`; solo se guardan los primeros 4,096 bytes.

Con esas opciones, el contenedor pasa por tres estados de salud: `starting` mientras no hay una respuesta que cuente, `healthy` en cuanto una revisión sale con `0`, y `unhealthy` cuando se juntan tantas fallas seguidas como diga `--retries`. Cualquier éxito pone en cero la racha de fallas.

#### 7.4.2 El Dockerfile de esta lección

Es el de la Lección 6 con dos instrucciones nuevas al final:

```dockerfile
# syntax=docker/dockerfile:1
# fig07_01.Dockerfile — Lección 7: la imagen dice cómo está (HEALTHCHECK) y muere bien.
# Parte de la de la Lección 6; lo nuevo está al final.

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
# La salud la revisa el propio binario: la imagen no tiene shell ni curl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/revisor", "healthcheck"]
# Señal de apagado explícita (es la de omisión; escribirla documenta la intención).
STOPSIGNAL SIGTERM
ENTRYPOINT ["/revisor"]
```

Lo que cambió:

1. **`HEALTHCHECK ... CMD ["/revisor", "healthcheck"]`.** La revisión la hace el propio binario: el subcomando `healthcheck` del `revisor` le pregunta a su mismo proceso por `GET /salud` en `127.0.0.1`, con dos segundos de límite; si contesta `200`, imprime `sano` y sale con `0`; si no, imprime `no sano: …` y sale con `1`. Va en forma *exec*, con corchetes, como el `ENTRYPOINT`: por la misma razón de la Lección 3, y por una más que vas a ver en un momento.
2. **Los tiempos.** `--interval=10s` porque al `revisor` no le hace falta que lo vigilen cada cinco segundos, y treinta (el de omisión) es demasiado para darse cuenta de un problema. `--timeout=3s` deja holgura sobre los dos segundos que el propio subcomando se da. `--start-period=5s` le da tiempo de arrancar, y durante ese tiempo Docker pregunta cada cinco segundos (`--start-interval`), así que la primera respuesta llega rápido. `--retries=3` pide tres fallas seguidas antes de declararlo no sano: un tropiezo no basta.
3. **`STOPSIGNAL SIGTERM`**, que viste en 7.2.2.

#### 7.4.3 Por qué no `curl`

La forma más común de escribir una revisión de salud, la que vas a encontrar en casi todos los tutoriales, es `HEALTHCHECK CMD curl -f http://localhost:8080/salud || exit 1`. Tiene dos problemas en la imagen del `revisor`, y el guion de esta sección los provoca. El primero es evidente: la imagen no tiene `curl`. El segundo es más sutil: esa línea está en forma *shell*, y la forma *shell* necesita `/bin/sh`, que tampoco está. Lo mismo pasa con `docker run --health-cmd`, que es la forma de poner o cambiar la revisión al correr: lo que escribes ahí Docker lo corre con el *shell*.

La salida fácil sería agregar `curl` a la imagen. No conviene: son megabytes de una herramienta de red, con su propia historia de vulnerabilidades, metidos en la imagen que en la Lección 5 dejaste sin nada que no hiciera falta, solo para hacer una pregunta que el programa ya sabe hacer. La salida buena es la que trae el `revisor`: un subcomando del mismo binario. Cero bytes extra, y la revisión pregunta exactamente lo que el programa sabe de sí mismo. El servicio de prueba hace lo mismo con su `servicio-prueba healthcheck`, y por eso desde la Lección 2 tiene salud sin tener `curl`.

#### 7.4.4 Verlo fallar y verlo funcionar

El guion `fig07_03.sh` construye la imagen, intenta primero vigilarla con `curl` y después la corre con su propia revisión:

```bash
#!/usr/bin/env bash
# fig07_03.sh — HEALTHCHECK sin curl. Construye el revisor con fig07_01.Dockerfile,
# provoca primero el error de vigilarlo con curl (la imagen no tiene ni shell ni
# curl), lo corre con su propia revisión de salud y lo detiene midiendo el tiempo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

t() { date +%s%3N; }
# esperar_salud ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
# estado: lo que dice docker ps, sin el nombre
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
# bitacora_salud: las revisiones guardadas, una por renglón: código y salida
bitacora_salud() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{printf "%q" .Output}}{{println}}{{end}}' "$NOMBRE" | sed '/^$/d'
}
SERVICIOS='propio http://127.0.0.1:8080/salud'

echo "== 1. Construir y leer la revisión de salud que trae la imagen"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null
docker image inspect --format '{{json .Config.Healthcheck}}' "$IMAGEN"
docker image inspect --format 'StopSignal={{.Config.StopSignal}}' "$IMAGEN"

echo
echo "== 2. El error: vigilarlo con curl, como en los tutoriales"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  --health-cmd 'curl -fs http://127.0.0.1:8080/salud || exit 1' \
  --health-interval 2s --health-retries 2 --health-start-period 1ms "$IMAGEN" >/dev/null
inicio=$(t); esperar_salud unhealthy; fin=$(t)
estado
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud | tail -1
echo "-- y sin embargo, el servicio contesta:"
docker exec "$NOMBRE" /revisor healthcheck
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Con la revisión de la imagen: el propio binario se pregunta"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
estado
inicio=$(t); esperar_salud healthy; fin=$(t)
estado
echo "pasó a healthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud
docker inspect --format 'Status={{.State.Status}} Health={{.State.Health.Status}} FailingStreak={{.State.Health.FailingStreak}}' "$NOMBRE"

echo
echo "== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_03.sh
== 1. Construir y leer la revisión de salud que trae la imagen
{"Test":["CMD","/revisor","healthcheck"],"Interval":10000000000,"Timeout":3000000000,"StartPeriod":5000000000,"Retries":3}
StopSignal=SIGTERM

== 2. El error: vigilarlo con curl, como en los tutoriales
Up 4 seconds (unhealthy)
pasó a unhealthy en 5 s
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
-- y sin embargo, el servicio contesta:
sano

== 3. Con la revisión de la imagen: el propio binario se pregunta
Up 1 second (health: starting)
Up 6 seconds (healthy)
pasó a healthy en 5 s
0 "sano\n"
Status=running Health=healthy FailingStreak=0

== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM
docker stop tardó 657 ms
ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Lo nuevo del guion: `esperar_salud` pregunta cada medio segundo por `.State.Health.Status` hasta que diga lo que espera; `estado` muestra la columna `STATUS` de `docker ps` sin el nombre; y `bitacora_salud` recorre `.State.Health.Log`, la lista de las últimas revisiones que Docker guarda, con el código y la salida de cada una. El `printf "%q"` escribe la salida entre comillas y con los saltos de línea como `\n`, para que se vea exactamente qué imprimió el comando.

Bloque por bloque:

1. **La imagen trae su revisión.** `docker image inspect` la muestra en JSON: el comando en forma *exec* (`"CMD"` seguido de la lista) y los tiempos en nanosegundos (`10000000000` son diez segundos). La señal de apagado quedó anotada: `StopSignal=SIGTERM`.
2. **Con `curl`, `unhealthy`.** El guion pidió una revisión cada dos segundos y dos fallas para rendirse, y a los 5 segundos el contenedor ya estaba `(unhealthy)`: dos revisiones fallidas, a los 2 y a los 4 segundos, más lo que tarda cada una. Fíjate en `--health-start-period 1ms`. Una opción `--health-*` en `0s` **no** apaga el tiempo de arranque: para Docker, un cero significa «usa el valor de la imagen», y el contenedor conservaría los 5 segundos de arranque del Dockerfile. `1ms` es la forma de pedir un arranque casi nulo; el Ejercicio 2 te muestra la diferencia medida. La bitácora de salud dice por qué, y el código no es `1` sino **`-1`**: Docker ni siquiera pudo ejecutar la revisión. El mensaje es el de la Lección 2 cuando intentaste `docker exec ... sh`, con otra redacción: `exec: "/bin/sh": stat /bin/sh: no such file or directory`. Y lo más importante viene después: `docker exec ... /revisor healthcheck` contesta `sano`. **El servicio estaba bien; la revisión estaba rota.** Es el error más traicionero de esta lección, porque el estado `unhealthy` acusa al programa de algo que es culpa de quien escribió la revisión.
3. **Con la revisión de la imagen, `healthy` a los 5 segundos.** Primero `(health: starting)`, después `(healthy)`. Los cinco segundos son el `--start-interval`: la primera pregunta llegó al terminar el primer intervalo del arranque, y salió bien. La referencia del Dockerfile dice que la primera revisión llega tras un `--interval`, que aquí serían diez segundos; medido con Docker 29.2.1, durante el arranque Docker usa `--start-interval`, y la primera llegó a los cinco. Cuando la documentación y la medición no coinciden, gana la medición (lo vas a ver otra vez en 7.6.3). La bitácora tiene una entrada: código `0` y la salida `sano\n`. El último renglón lee lo mismo por partes: el proceso está `running`, su salud es `healthy` y la racha de fallas (`FailingStreak`) es `0`.
4. **El apagado.** Sin `--init`, el `revisor` es el número 1, pero esta vez **sí** tiene manejador. `docker stop` tardó **657 ms** en esta corrida, con la máquina cargada (161 ms en la Lección 3, 107 en una corrida anterior de este mismo guion), y el código es `0`, no `143`: el programa no murió por la señal, la atendió y salió por su cuenta. Los registros lo cuentan con sus propias palabras (el `grep -v` deja fuera los `GET /salud` de cada revisión).

#### 7.4.5 En tu carpeta

Tu proyecto vive en `~/curso-docker/revisor` desde la Lección 3. Desde la raíz del repositorio del curso, pon ahí el Dockerfile de esta lección y construye la imagen que vas a conservar:

```bash
cp programas/07-salud-y-ciclo-de-vida/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.4.0 -t curso-docker-revisor:1.4.0 .
docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0
```

El último comando tiene que imprimir el mismo JSON del bloque 1. El `.dockerignore` y la carpeta `secretos/` no cambian. `Dockerfile.malo`, el de la Lección 6, ya no lo necesitas; puedes quitarlo de tu carpeta o dejarlo, porque el `.dockerignore` impide que viaje. La imagen se corre endurecida en la sección 7.10, cuando ya sepas qué hace cada opción.

### 7.5 Corriendo no es sano

#### 7.5.1 Lo que hace Docker con la salud, y lo que no

Una revisión de salud cambia **una etiqueta**: la que ves entre paréntesis en `docker ps`. Nada más. Docker no reinicia un contenedor `unhealthy`, no le corta el tráfico y no avisa a nadie. La información está ahí para que alguien la use: tú, al mirar `docker ps`; Compose, que con `depends_on` y `condition: service_healthy` espera a que un servicio esté sano antes de arrancar el siguiente (Lección 9); un orquestador, que puede reemplazar al contenedor enfermo. Esta sección lo demuestra con el servicio de prueba, que tiene un truco que el `revisor` no tiene: cambia de modo sin reiniciarse.

#### 7.5.2 El servicio de prueba se enferma

El guion `fig07_04.sh` construye una copia del servicio de prueba, la arranca con `--restart always` (la política más insistente, que verás en 7.6) y la pasa por sus tres modos:

```bash
#!/usr/bin/env bash
# fig07_04.sh — Corriendo no es sano. El servicio de prueba, con su propio
# HEALTHCHECK (cada 5 s, 2 reintentos), pasa a modo caído y a modo lento sin
# reiniciarse: el proceso sigue vivo y Docker lo marca unhealthy. Y una política
# de reinicio NO reinicia a un contenedor por estar unhealthy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-9000}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
resumen() {
  docker inspect --format '{{.State.Status}} / {{.State.Health.Status}} / racha={{.State.Health.FailingStreak}} / reinicios={{.RestartCount}}' "$NOMBRE"
}
ultima_revision() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{end}}' "$NOMBRE" | sed '/^$/d' | tail -1
}

echo "== 1. Arranca sano, con --restart always"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:9000" --restart always "$IMAGEN" >/dev/null
esperar_salud healthy
estado

echo
echo "== 2. Modo caído: el proceso sigue vivo, pero responde 503"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/caido"
inicio=$(t); esperar_salud unhealthy; fin=$(t)
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
estado
resumen
ultima_revision

echo
echo "== 3. Diez segundos después, sigue unhealthy y nadie lo reinició"
sleep 10
resumen

echo
echo "== 4. De vuelta a sano, sin reiniciar nada"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/sano"
inicio=$(t); esperar_salud healthy; fin=$(t)
echo "volvió a healthy en $(( (fin - inicio + 500) / 1000 )) s"
resumen

echo
echo "== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/lento"
esperar_salud unhealthy
resumen
ultima_revision
echo "-- y sin embargo, contesta 200:"
curl -s -o /dev/null -w '%{http_code} en %{time_total}s\n' "http://127.0.0.1:$PUERTO/"
```

```text
$ ./fig07_04.sh
== 1. Arranca sano, con --restart always
Up 5 seconds (healthy)

== 2. Modo caído: el proceso sigue vivo, pero responde 503
modo: caido
pasó a unhealthy en 10 s
Up 15 seconds (unhealthy)
running / unhealthy / racha=2 / reinicios=0
1 no sano: GET / respondió 503

== 3. Diez segundos después, sigue unhealthy y nadie lo reinició
running / unhealthy / racha=4 / reinicios=0

== 4. De vuelta a sano, sin reiniciar nada
modo: sano
volvió a healthy en 5 s
running / healthy / racha=0 / reinicios=0

== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2
modo: lento
running / unhealthy / racha=2 / reinicios=0
1 no sano: Get "http://127.0.0.1:9000/": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
-- y sin embargo, contesta 200:
200 en 3.012887s
```

El servicio de prueba trae su propio `HEALTHCHECK` desde la Lección 2: cada 5 segundos, con 2 reintentos, y su revisión exige un `200` en menos de 2 segundos. Con eso:

1. **Arranca sano**, a los 5 segundos.
2. **En modo caído, `unhealthy` a los 10 segundos.** Dos revisiones fallidas, cinco segundos entre una y otra: son los `--retries=2` por el `--interval=5s` de su Dockerfile. Ahora mira el renglón de `resumen`: `running / unhealthy / racha=2 / reinicios=0`. El proceso **corre**; la salud dice que **no sirve**; la racha de fallas es 2; y nadie lo reinició. La última revisión explica la causa con el texto exacto de su código: `1 no sano: GET / respondió 503`.
3. **Diez segundos después, igual.** La racha subió a 4 y los reinicios siguen en 0. Ni la salud ni `--restart always` hicieron nada. Esto es lo que pasaba en la escena del principio: un contenedor `Up`, `unhealthy` y abandonado.
4. **De vuelta a sano en 5 segundos**, sin reiniciar nada: una revisión buena pone la racha en 0 y la salud en `healthy`. La salud no es un estado que se gana una vez: se recalcula en cada revisión.
5. **En modo lento, también `unhealthy`.** Y aquí está la lección más fina. El servicio contesta `200`, el código de «todo bien», pero tarda 3 segundos, y su revisión solo espera 2: `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, que es la forma en que Go dice «se acabó el tiempo esperando la respuesta». El `curl` del final lo confirma: `200 en 3.01s`. Para la revisión, un servicio que contesta tarde es un servicio que no contesta. Esa es una decisión de diseño: quien escribe la revisión decide qué significa «sano», y aquí significa «responde bien **y** a tiempo».

#### 7.5.3 Qué pregunta una buena revisión

Una revisión de salud contesta una sola pregunta: **¿este proceso puede atender?** Del `revisor`, el `/salud` responde que el servidor HTTP está vivo y atendiendo, y nada más. No revisa los servicios que el `revisor` vigila: si revisara eso, un servicio de prueba caído pondría `unhealthy` al `revisor`, que está perfectamente bien haciendo su trabajo, que es reportar la caída. Tampoco revisa si puede escribir su reporte, y en 7.7 vas a ver lo que eso significa. Una revisión que depende de otros servicios convierte la falla de uno en la falla de todos; por eso conviene que pregunte por el propio proceso y sea barata: se va a correr cada diez segundos durante toda la vida del contenedor.

### 7.6 Políticas de reinicio

#### 7.6.1 Las cuatro políticas

Una **política de reinicio** le dice al daemon qué hacer cuando el proceso de un contenedor termina. Se elige con `docker run --restart` y hay cuatro, que la documentación describe así ([Docker, «Start containers automatically»](https://docs.docker.com/engine/containers/start-containers-automatically/)):

| Política | Qué hace |
|---|---|
| `no` | no reinicia nunca; es la de omisión |
| `on-failure[:máximo]` | reinicia si el proceso sale con un código distinto de 0; con `:máximo`, solo esa cantidad de veces. No reinicia el contenedor cuando el daemon se reinicia |
| `always` | reinicia siempre que el proceso se detenga. Si lo detuviste tú, solo vuelve a arrancar cuando el daemon de Docker se reinicia o cuando tú lo arrancas |
| `unless-stopped` | como `always`, salvo que, si el contenedor estaba detenido, no vuelve a arrancar ni siquiera cuando el daemon se reinicia |

Dos detalles más de la documentación importan. Uno: si detienes un contenedor a mano, su política se ignora hasta que el daemon se reinicie o lo arranques de nuevo; así no hay forma de pelearte con Docker para apagar algo. Y dos: entre un reinicio y el siguiente, Docker espera cada vez más: el doble de la vez anterior, empezando en 100 milisegundos y con un tope de un minuto; si el contenedor logra quedarse arriba al menos 10 segundos, la espera vuelve a 100 ms ([referencia de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). Eso evita que un contenedor roto se reinicie mil veces por segundo.

#### 7.6.2 Medir lo que hace cada una

El guion `fig07_05.sh` construye el `revisor` y lo pone a morir de varias formas:

```bash
#!/usr/bin/env bash
# fig07_05.sh — Políticas de reinicio. Un revisor sin configuración muere con
# código 1 en cuanto arranca: con on-failure:3, Docker lo reintenta tres veces,
# cada vez esperando más. Y con always: qué hace Docker cuando el proceso muere
# solo, y qué hace cuando lo detienes tú. Usa sudo una vez, para matar al
# proceso desde fuera como lo haría el núcleo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}reinicios-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
resumen() {
  docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}}' "$NOMBRE"
}

echo "== 1. on-failure:3 con un revisor sin configuración"
desde=$(date +%s)
docker run -d --name "$NOMBRE" --restart on-failure:3 "$IMAGEN" >/dev/null
sleep 8
resumen
echo "-- lo que escribió en sus cuatro vidas:"
docker logs "$NOMBRE" 2>&1 | sort | uniq -c
echo "-- cuánto esperó Docker entre un arranque y el siguiente:"
docker events --since "$desde" --until "$(date +%s)" \
  --filter "container=$NOMBRE" --filter event=start --format '{{.TimeNano}}' |
  awk 'NR > 1 { printf "arranque %d: %d ms después del anterior\n", NR, ($1 - previo) / 1000000 } { previo = $1 }'
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. Sin política (no, la de omisión): muere y se queda muerto"
docker run -d --name "$NOMBRE" "$IMAGEN" >/dev/null
sleep 3
resumen
docker rm -f "$NOMBRE" >/dev/null

SERVICIOS='propio http://127.0.0.1:8080/salud'
echo
echo "== 3. --restart always con el revisor bien configurado"
docker run -d --name "$NOMBRE" --restart always -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
sleep 2
echo "-- el núcleo mata al proceso (como haría el asesino de memoria):"
PID1=$(pid_de "$NOMBRE")
sudo kill -KILL "$PID1"
sleep 3
resumen
echo "-- lo detienes tú, con docker stop:"
docker stop "$NOMBRE" >/dev/null
sleep 3
resumen
echo "-- lo vuelves a arrancar tú, y lo matas con docker kill:"
docker start "$NOMBRE" >/dev/null
sleep 2
docker kill "$NOMBRE" >/dev/null
sleep 3
resumen
```

```text
$ ./fig07_05.sh
== 1. on-failure:3 con un revisor sin configuración
Status=exited ExitCode=1 RestartCount=3
-- lo que escribió en sus cuatro vidas:
      4 revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
-- cuánto esperó Docker entre un arranque y el siguiente:
arranque 2: 181 ms después del anterior
arranque 3: 294 ms después del anterior
arranque 4: 490 ms después del anterior

== 2. Sin política (no, la de omisión): muere y se queda muerto
Status=exited ExitCode=1 RestartCount=0

== 3. --restart always con el revisor bien configurado
-- el núcleo mata al proceso (como haría el asesino de memoria):
Status=running ExitCode=0 RestartCount=1
-- lo detienes tú, con docker stop:
Status=exited ExitCode=0 RestartCount=1
-- lo vuelves a arrancar tú, y lo matas con docker kill:
Status=exited ExitCode=137 RestartCount=0
```

Lo nuevo del guion: `docker events` lista lo que el daemon le hizo a un contenedor en un intervalo de tiempo (aquí, solo los arranques, `event=start`), y `{{.TimeNano}}` da la hora exacta de cada uno en nanosegundos. El `awk` resta cada arranque del anterior y lo pasa a milisegundos. Y `sudo kill -KILL` manda `SIGKILL` al proceso del contenedor **desde fuera de Docker**, como lo haría el núcleo cuando un proceso se pasa del límite de memoria; hace falta `sudo` porque el proceso es del usuario `65532`, no del tuyo.

1. **`on-failure:3` con un `revisor` sin configuración.** Muere con `1` en cuanto arranca. Docker lo arrancó otras tres veces y se rindió: `Status=exited ExitCode=1 RestartCount=3`. Los registros son la prueba: el mismo mensaje cuatro veces, uno por vida. Y las esperas son las de la documentación, más lo que tarda en arrancar cada vez: **181, 294 y 490 ms**, que son los 100, 200 y 400 de la espera creciente, más unos 80 a 90 ms de arranque. En una corrida con la máquina cargada por otros trabajos salieron 530, 1,483 y 2,399 ms: la espera la pone Docker, pero lo que tarda cada arranque lo pone el equipo. El `revisor` no tenía arreglo (le falta una variable), y por eso un tope es buena idea: tres intentos bastan para saber que no es un tropiezo.
2. **Sin política, se queda muerto.** `RestartCount=0`. Es lo que quieres para algo que corre una vez y termina.
3. **`always` con el `revisor` bien configurado.** Tres formas de morir, tres resultados:
   - **El núcleo lo mata.** Docker lo arrancó de nuevo: `Status=running RestartCount=1`. Para eso existe la política. (`ExitCode=0` es del contenedor que está corriendo ahora; todavía no ha terminado, así que no tiene código propio.)
   - **Lo detienes tú con `docker stop`.** Se queda detenido, con `ExitCode=0` porque se apagó en orden. La política respeta tu decisión.
   - **Lo matas tú con `docker kill`.** También se queda detenido, ahora con `137`. Docker cuenta `docker kill` como una detención a mano, igual que `docker stop`, aunque el proceso muera con `SIGKILL`. Y fíjate en `RestartCount=0`: el conteo volvió a cero cuando lo arrancaste con `docker start`.

#### 7.6.3 Una frase de la documentación que conviene leer con cuidado

La página de las políticas de reinicio dice que una política «solo tiene efecto después de que un contenedor arranca con éxito», y que eso significa estar arriba «al menos 10 segundos». El bloque 1 lo contradice a primera vista: el `revisor` sin configuración no duró ni un segundo y Docker lo reinició tres veces. Lo que la medición muestra es lo que dice la referencia de `docker run`: los 10 segundos deciden cuándo la espera vuelve a 100 ms, no si se reintenta. Cuando una documentación y tu medición no coinciden, gana la medición, y anotas la versión con la que mediste: Docker 29.2.1.

#### 7.6.4 Cuál elegir para el `revisor`

`unless-stopped`. El `revisor` es un servicio que debe estar siempre arriba, así que necesita que lo reinicien si el núcleo lo mata o si el equipo se reinicia; eso descarta `no` y `on-failure`, que no lo levanta tras un reinicio del daemon. Entre `always` y `unless-stopped`, la diferencia aparece solo cuando el daemon se reinicia, por ejemplo al reiniciar el equipo: con `always`, un contenedor que habías detenido a propósito vuelve a la vida; con `unless-stopped`, se respeta que lo detuviste. Eso no se midió aquí, porque reiniciar el daemon apaga todos los contenedores del equipo; está en la tabla de la documentación. Y recuerda lo que viste en 7.5: ninguna de las cuatro reinicia un contenedor por estar `unhealthy`. Una política de reinicio atiende la muerte del proceso, no su salud.

### 7.7 Sistema de archivos de solo lectura

#### 7.7.1 Por qué

La imagen es de solo lectura desde siempre; lo que se escribe al correr va a una capa nueva, propia del contenedor, que viste en la Lección 4. `--read-only` cierra esa capa: el sistema de archivos raíz del contenedor se monta «como de solo lectura» ([referencia de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). El programa sigue pudiendo leer todo lo que la imagen trae, pero no puede crear, cambiar ni borrar ningún archivo.

La ganancia es de seguridad y de orden. De seguridad, porque quien logre controlar el proceso no puede dejar un programa propio en el disco, ni cambiar un archivo de configuración, ni reemplazar el binario. De orden, porque te obliga a saber exactamente **dónde escribe tu programa**: cada ruta escribible pasa a ser una decisión, y no un accidente.

#### 7.7.2 Provocarlo y arreglarlo

El guion `fig07_06.sh` usa la opción `REVISOR_REPORTE`, que le dice al `revisor` dónde guardar el último reporte. El `revisor` lo escribe con un archivo temporal y un cambio de nombre en la misma carpeta, para que nadie lea nunca un reporte a medias. Los bloques 1 y 2 son esta sección; el 3, la 7.10:

```bash
#!/usr/bin/env bash
# fig07_06.sh — Solo lectura y el revisor endurecido completo. Primero el error:
# con --read-only, el revisor no puede guardar su reporte. Después el arreglo,
# un tmpfs solo donde hace falta escribir. Y al final, todas las opciones de la
# lección juntas: lo que Docker anotó, lo que el núcleo aplica y cómo se apaga.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
SERVICIOS='propio http://127.0.0.1:8080/salud'
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. --read-only, y el revisor guardando su reporte en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El arreglo: un tmpfs pequeño solo en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=1m \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '[%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range $ruta, $opciones := .HostConfig.Tmpfs}}{{$ruta}} {{$opciones}}{{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Todo junto: el revisor endurecido"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
echo "-- lo que Docker anotó:"
docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecurityOpt={{.HostConfig.SecurityOpt}} Init={{.HostConfig.Init}} Restart={{.HostConfig.RestartPolicy.Name}}' "$NOMBRE"
echo "-- los procesos:"
docker top "$NOMBRE" -o pid,ppid,user,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
echo "-- lo que el núcleo aplica al revisor (el hijo de docker-init):"
PID1=$(pid_de "$NOMBRE")
HIJO=$(pgrep -P "$PID1" | head -1)
grep -E '^(CapEff|CapBnd|NoNewPrivs)' "/proc/$HIJO/status"
echo "-- docker stop:"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_06.sh
== 1. --read-only, y el revisor guardando su reporte en /tmp
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
-- /salud no escribe nada, así que sigue contestando:
{"estado":"vivo","version":"1.4.0"}
 [200]

== 2. El arreglo: un tmpfs pequeño solo en /tmp
[200]
/tmp rw,noexec,nosuid,size=1m

== 3. Todo junto: el revisor endurecido
Up 5 seconds (healthy)
-- lo que Docker anotó:
ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped
-- los procesos:
PID                 PPID                USER                COMMAND
<pid> <ppid>             65532               /sbin/docker-init -- /revisor
<pid> <ppid>             65532               /revisor
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

1. **Con `--read-only`, `500`.** El `revisor` intentó crear su archivo temporal en `/tmp` y el núcleo contestó `read-only file system`. El `revisor` no esconde el error: responde `500` y la causa exacta. El número del archivo temporal cambia en cada corrida, y el guion lo tapa con `<n>`. Y mira el renglón siguiente: **`/salud` sigue contestando `200`**. La revisión de salud diría `healthy` mientras cada consulta a `/api/estados` falla. Es lo que adelantaba 7.5.3: la salud dice si el proceso atiende, no si cada función sirve. Por eso, al endurecer un contenedor, no basta con ver que arranque y esté sano: hay que ejercer lo que hace.
2. **Con `--tmpfs /tmp`, `200`.** Un **`tmpfs`** es una carpeta que vive en la memoria del equipo: según la documentación, a diferencia de volúmenes y *bind mounts*, «es temporal y solo persiste en la memoria del anfitrión», y cuando el contenedor se detiene, lo que se escribió ahí desaparece ([Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/)). Es justo lo que necesita un archivo temporal. El sistema de archivos raíz sigue de solo lectura; solo `/tmp` acepta escritura, y con tres opciones: `noexec` impide ejecutar programas desde ahí (quien logre escribir un archivo no lo puede correr), `nosuid` hace que el bit *setuid* no tenga efecto ahí (verás qué es en 7.9) y `size=1m` le pone un tope de un megabyte. Sin `size`, el núcleo le pone de tope la mitad de la memoria del equipo, y su permiso es `1777`, escribible por cualquiera (la documentación da esos valores para `--mount type=tmpfs`; con `--tmpfs` son los mismos, porque los pone el núcleo). Además, la misma página advierte que lo que escribas ahí cuenta contra el límite de memoria del contenedor: con el `--memory 64m` de la Lección 2, un `tmpfs` sin tope podría llevar al `revisor` a su límite. El último renglón muestra cómo quedó anotado.

Este arreglo es para esta lección. En la Lección 8 el reporte se va a guardar en un volumen, porque tiene que sobrevivir al contenedor, y lo que vive en un `tmpfs` muere con él.

### 7.8 Capacidades fuera

#### 7.8.1 `root` partido en pedazos

En la Lección 0 viste que Docker no le da a `root` todo su poder: le deja catorce **capacidades**. El manual de Linux explica el concepto: Linux «divide los privilegios asociados tradicionalmente al superusuario en unidades distintas», llamadas capacidades, que se pueden encender y apagar por separado ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Algunas de las que Docker deja por omisión, con su definición del manual:

| Capacidad | Qué permite |
|---|---|
| `CAP_CHOWN` | cambiar a voluntad el usuario y el grupo dueños de un archivo |
| `CAP_DAC_OVERRIDE` | saltarse las revisiones de permisos de lectura, escritura y ejecución de archivos |
| `CAP_KILL` | saltarse las revisiones de permisos para mandar señales |
| `CAP_SETUID` | cambiar a voluntad el usuario de un proceso |
| `CAP_NET_BIND_SERVICE` | escuchar en puertos menores que 1024 |

El `revisor` corre como `65532`, que no es `root`, así que en principio no tiene ninguna. ¿Para qué quitarlas? Porque la lista con la que corre un contenedor no es solo la de su proceso: también es el **tope** de lo que cualquier proceso de ese contenedor podría llegar a tener (el *bounding set* del manual). Si alguien encuentra la forma de convertirse en `root` dentro del contenedor, hereda ese tope. Con `--cap-drop ALL`, el tope es cero: ni siquiera un `root` de dentro tiene ninguna.

#### 7.8.2 Verlo con un `root` de verdad

Para ver qué cambia hace falta un contenedor que corra como `root` y tenga herramientas, y la imagen de Go tiene las dos cosas. El guion `fig07_07.sh` no construye nada y cada contenedor se borra solo:

```bash
#!/usr/bin/env bash
# fig07_07.sh — Capacidades y no-new-privileges, vistos en un contenedor que SÍ
# tiene shell y herramientas: la imagen de Go que ya bajaste. Qué puede hacer
# root con sus 14 capacidades, qué deja de poder sin ellas, y cómo un programa
# setuid convierte a un usuario normal en root… salvo con no-new-privileges.
# No construye nada y cada contenedor se borra solo (--rm).
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombre de apoyo con «fig07»: el guion nunca toca tus contenedores del curso.
NOMBRE="${PREFIJO}fig07-caps"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# correr [opciones de docker run] -- COMANDO: corre COMANDO con sh en un contenedor desechable
correr() {
  local opciones=()
  while [ "$1" != "--" ]; do opciones+=("$1"); shift; done
  shift
  docker run --rm --name "$NOMBRE" "${opciones[@]}" "$GO" sh -c "$1" 2>&1 || echo "[código de salida: $?]"
}
# La prueba: ¿puede root regalarle un archivo a otro usuario?
REGALAR='grep CapEff /proc/self/status; touch /tmp/a && chown 10001 /tmp/a && echo "chown: hecho"'

echo "== 1. root, con las capacidades que Docker deja por omisión"
correr -- "$REGALAR"

echo
echo "== 2. El mismo root, con --cap-drop ALL"
correr --cap-drop ALL -- "$REGALAR"

echo
echo "== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta"
correr --cap-drop ALL --cap-add CHOWN -- "$REGALAR"

# La otra prueba: un usuario normal ejecuta una copia de «id» con el bit setuid.
SETUID='cp /usr/bin/id /tmp/id-suid && chmod u+s /tmp/id-suid && ls -l /tmp/id-suid | cut -d" " -f1,3
setpriv --reuid 10001 --regid 10001 --clear-groups sh -c "id; /tmp/id-suid; grep NoNewPrivs /proc/self/status"'

echo
echo "== 4. Un programa setuid de root, ejecutado por el usuario 10001"
correr -- "$SETUID"

echo
echo "== 5. Lo mismo con --security-opt no-new-privileges"
correr --security-opt no-new-privileges -- "$SETUID"

echo
echo "== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80"
correr --user 10001:10001 --cap-drop ALL -- \
  'cat /proc/sys/net/ipv4/ip_unprivileged_port_start; perl -MIO::Socket::INET -e '"'"'IO::Socket::INET->new(LocalPort => 80, Listen => 1, ReuseAddr => 1) or die "no pude: $!\n"; print "escuchando en el 80\n"'"'"
```

```text
$ ./fig07_07.sh
== 1. root, con las capacidades que Docker deja por omisión
CapEff:	00000000a80425fb
chown: hecho

== 2. El mismo root, con --cap-drop ALL
CapEff:	0000000000000000
chown: changing ownership of '/tmp/a': Operation not permitted
[código de salida: 1]

== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta
CapEff:	0000000000000001
chown: hecho

== 4. Un programa setuid de root, ejecutado por el usuario 10001
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 euid=0(root) groups=10001
NoNewPrivs:	0

== 5. Lo mismo con --security-opt no-new-privileges
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 groups=10001
NoNewPrivs:	1

== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80
0
escuchando en el 80
```

La función `correr` arma un `docker run --rm` con las opciones que le pases antes de `--` y corre el comando con `sh -c`. La prueba de los tres primeros bloques es la misma: mostrar la línea `CapEff` (las capacidades **efectivas**, las que el proceso puede usar en este momento) y regalarle un archivo al usuario `10001` con `chown`.

1. **`root` con lo de omisión.** `CapEff: 00000000a80425fb`, la misma máscara de las catorce que decodificaste en la Lección 0. `chown` funciona.
2. **`root` con `--cap-drop ALL`.** `CapEff` en cero, y `chown` falla con `Operation not permitted`, código 1. Es `root` (sigue siendo el usuario 0), pero un `root` sin capacidades no puede hacer lo que hace a `root` especial.
3. **`--cap-drop ALL --cap-add CHOWN`.** La máscara vale `1`: un solo bit, el de `CAP_CHOWN`, que es la capacidad número 0. `chown` vuelve a funcionar. Es el patrón para un programa que de verdad necesita una: quitar todas y devolver solo esa, con nombre, a la vista de quien lea el comando.

#### 7.8.3 Los puertos bajos ya no necesitan capacidad

El bloque 6 contesta una duda que vas a tener: si `CAP_NET_BIND_SERVICE` es la que deja escuchar en puertos menores que 1024, ¿un servidor web en el puerto 80 necesita conservarla? En un contenedor de Docker, no. El usuario `10001`, **sin ninguna capacidad**, abrió el puerto 80. El primer renglón explica por qué: dentro del contenedor, el ajuste del núcleo `ip_unprivileged_port_start`, que dice desde qué puerto puede escuchar un usuario sin privilegios, vale `0`. Docker lo pone así por omisión desde la versión 20.10, en cada contenedor con red propia ([moby/moby #41030](https://github.com/moby/moby/pull/41030)), y como ese ajuste vale solo para la red del contenedor, no cambia nada en tu equipo. El `revisor` escucha en el 8080 y no lo necesita de todos modos, pero así ya sabes que `--cap-drop ALL` no te obliga a mover un servicio de puerto.

### 7.9 `no-new-privileges`

#### 7.9.1 El bit *setuid*

En Linux, un archivo ejecutable puede tener encendido el bit ***setuid***: quien lo ejecute, sea quien sea, lo corre **con el usuario dueño del archivo**. Así funcionan `passwd` o `su`, que un usuario normal ejecuta y que necesitan ser `root` por un momento. El manual de capacidades lo dice del caso que importa: un programa *setuid* de `root` gana todas las capacidades, salvo las que el tope (*bounding set*) no permite ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Es una puerta legítima para subir privilegios, y por eso es la favorita de quien intenta subirlos sin permiso.

`--security-opt no-new-privileges` cierra esa puerta. Enciende en el proceso una marca del núcleo, `no_new_privs`, que la documentación del núcleo define así: con ella, `execve` (ejecutar otro programa) promete «no otorgar el privilegio de hacer nada que no se hubiera podido hacer sin esa llamada»; en concreto, «los bits *setuid* y *setgid* ya no cambian el uid ni el gid», y las capacidades de un archivo no se suman. La marca se hereda a todos los hijos y **no se puede apagar** ([Linux, «No New Privileges Flag»](https://docs.kernel.org/userspace-api/no_new_privs.html)). La referencia de `docker run` lo dice en términos prácticos: con esta opción, «los comandos que elevan privilegios, como `su` o `sudo`, ya no funcionan».

#### 7.9.2 Verlo

Los bloques 4 y 5 de `fig07_07.sh` hacen la prueba. Como `root`, el guion copia el programa `id` a `/tmp/id-suid` y le enciende el bit *setuid* (la `s` de `-rwsr-xr-x`, dueño `root`). Después, con `setpriv`, una herramienta de Debian que cambia de usuario, se vuelve el usuario `10001` y ejecuta dos veces `id`: la normal y la copia *setuid*.

4. **Sin `no-new-privileges`.** El `id` normal dice `uid=10001`. La copia dice `uid=10001 ... euid=0(root)`: el usuario **efectivo** es `root`. Un usuario cualquiera ejecutó un archivo y, mientras corre, tiene los poderes de `root`. `NoNewPrivs: 0`.
5. **Con `no-new-privileges`.** Las dos dicen `uid=10001` y nada más. El bit sigue ahí (`-rwsr-xr-x`), pero el núcleo ya no le hace caso. `NoNewPrivs: 1`.

¿Por qué importa en el `revisor`, que no tiene programas *setuid*? Por la misma razón que `--cap-drop ALL`: no es para lo que hay hoy en la imagen, sino para lo que alguien pudiera meter o encontrar mañana. Y combina con lo anterior: el `tmpfs` de `/tmp` lleva `nosuid` y `noexec`, el sistema de archivos raíz es de solo lectura y el tope de capacidades es cero. Para subir privilegios, un atacante necesitaría escribir un programa, ejecutarlo y que el bit *setuid* contara; cada una de las tres opciones le cierra un paso.

### 7.10 Todo junto: el `revisor` endurecido

#### 7.10.1 El comando

Estas son las opciones con las que el `revisor` corre desde ahora, y las que la Lección 9 escribe en el `compose.yaml`:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' \
  curso-docker-revisor:1.4.0
```

Cada renglón viene de una lección: el puerto en `127.0.0.1` y los límites, de la 2; la imagen sin `root` ni *shell*, de la 3 y la 5; la configuración por `-e`, de la 6; y el segundo renglón y la política de reinicio, de esta. No lleva `--tmpfs` porque aquí no se le pide guardar el reporte; en la Lección 8 tendrá un volumen para eso.

#### 7.10.2 Comprobarlo

El bloque 3 de `fig07_06.sh` corre exactamente esas opciones y le pregunta a cada quien lo suyo:

1. **La salud:** `(healthy)` a los 5 segundos, con todo puesto. Ninguna de las opciones le estorbó al `revisor`.
2. **Lo que Docker anotó:** `ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped`. Es lo que pediste, leído de la configuración del contenedor.
3. **Los procesos:** `docker-init` como número 1 y `/revisor` como su hijo, los dos con el usuario `65532`.
4. **Lo que el núcleo aplica**, leído de `/proc` del hijo, que es el `revisor` (el guion lo encuentra con `pgrep -P`, que busca los hijos de un proceso): `CapEff` en cero (no tiene capacidades), `CapBnd` en cero (ni podría ganarlas) y `NoNewPrivs: 1`. De los tres, `CapBnd` es el que demuestra `--cap-drop ALL`: el `revisor` corre como `65532`, y su `CapEff` estaría en cero aunque no quitaras nada; el tope, en cambio, sería el de las catorce capacidades. Esto es más que lo de Docker: es lo que el núcleo hace cumplir. Una opción mal escrita podría quedar anotada sin aplicarse; `/proc` no miente.
5. **El apagado:** `docker stop` tardó **206 ms** y el código es `0`. `docker-init` le pasó la señal al `revisor`, el `revisor` la atendió y se despidió en sus registros. Todo endurecido, y muere igual de bien que sin nada.

En tu carpeta, corre el comando de 7.10.1, espera unos segundos y comprueba con `docker ps --filter name=curso-docker-revisor` que diga `(healthy)`. Cuando lo veas `(healthy)`, bórralo con `docker rm -f curso-docker-revisor` **antes de los ejercicios**, que usan ese nombre y ese puerto; la imagen `curso-docker-revisor:1.4.0` se queda para la Lección 8.

### 7.11 Lo que vas a encontrar en tutoriales viejos

- **`HEALTHCHECK CMD curl -f http://localhost/ || exit 1`.** Funciona en imágenes que traen *shell* y `curl`, y obliga a meter las dos cosas en las que no. En la sección 7.4.4 viste cómo falla en una imagen mínima: `unhealthy` con un servicio sano. Si tu programa es un servidor, dale un subcomando de salud.
- **Instalar `tini` o `dumb-init` dentro del Dockerfile** y ponerlo en el `ENTRYPOINT`. Era necesario antes de que Docker trajera su propio *init*; hoy `--init` hace lo mismo sin tocar la imagen. Sigue teniendo sentido si la imagen va a correr en un lugar donde no puedas pedir `--init`.
- **Un guion de arranque que termina en `revisor` en vez de `exec revisor`.** Es la forma *shell* de la Lección 3 escondida en un archivo: el *shell* queda de número 1 y la señal no llega.
- **`--restart always` en todo, «para que no se caiga».** No arregla un programa roto (lo reinicia una y otra vez, cada vez más tarde) y no hace nada con uno enfermo que sigue corriendo. Además, según la documentación, un contenedor con `always` que detuviste a propósito revive cuando se reinicia el daemon.
- **`--privileged` para «quitar problemas de permisos».** Es lo contrario de esta lección: le da al contenedor todas las capacidades y acceso a los dispositivos del equipo. La referencia de `docker run` explica que, por omisión, Docker quita las capacidades más peligrosas, como `CAP_SYS_ADMIN`; `--privileged` las devuelve todas. Si un programa necesita una capacidad, `--cap-add` con su nombre.

## El error que vas a ver

Esta lección tiene un error principal y dos que aparecen con él.

**El error principal: la revisión de salud que no se puede ejecutar.** Es el de `fig07_03.sh`:

```text
Up 7 seconds (unhealthy)
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
```

Se lee así. `-1` no es un código del programa: es Docker diciendo que no pudo ni empezar la revisión. `OCI runtime exec failed` dice quién falló, el componente que ejecuta procesos dentro del contenedor. Y el final dice qué buscó y no encontró: `/bin/sh`. La revisión estaba en forma *shell* (o se pasó con `--health-cmd`, que es lo mismo) y la imagen no tiene *shell*. Se arregla con una revisión en forma *exec* que llame a un programa que la imagen sí tenga: `HEALTHCHECK CMD ["/revisor", "healthcheck"]`. Si en vez de `/bin/sh` el mensaje dice `curl`, la imagen tiene *shell* pero no `curl`; el arreglo es el mismo. Y antes de culpar al programa, pregúntale tú: `docker exec <contenedor> /revisor healthcheck`. Si contesta `sano`, el problema está en la revisión, no en el servicio.

**El que aparece con él: solo lectura.** El de `fig07_06.sh`:

```text
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
```

`read-only file system` lo dice el núcleo: el contenedor corre con `--read-only` y el programa intentó escribir. La pregunta que lo resuelve es «¿dónde escribe mi programa, y por qué?». Si es algo temporal, un `--tmpfs` en esa carpeta; si tiene que durar, un volumen (Lección 8). Lo que no es un arreglo: quitar `--read-only`.

**El código que delata un mal apagado: `137` tras `docker stop`.** Si `docker stop` tarda el plazo completo y deja `ExitCode=137`, la señal no le sirvió al proceso número 1: o es un *shell* en medio (Lección 3), o es un programa que no instaló manejador (7.1.4). Mira `docker top` para saber quién es el número 1 y `SigCgt` para saber qué atiende. Si no puedes cambiar el programa, `--init`.

## El hábito de seguridad de la lección

**El contenedor corre con el mínimo: sistema de archivos de solo lectura, cero capacidades y sin ganar privilegios, y se comprueba en `/proc` que el núcleo lo aplica.** Son tres opciones que se escriben juntas (`--read-only --cap-drop ALL --security-opt no-new-privileges`) y una comprobación que se hace una vez por imagen. Cada una le quita un paso a quien logre controlar el proceso por una falla del programa: no puede escribir en el disco, no tiene ninguno de los poderes partidos de `root` y no puede volverse `root` ejecutando un programa *setuid*. El accidente que evita no es hipotético: casi todas las formas de pasar de «controlo un proceso» a «controlo la máquina» necesitan escribir algo, usar una capacidad o subir de usuario. Y la mitad que se olvida es la segunda: no basta con escribir las opciones, hay que ver `CapBnd: 0000000000000000` (el tope: ni un `root` de dentro podría ganar capacidades) y `NoNewPrivs: 1`. `CapEff` en cero no basta como prueba: un usuario que no es `root`, como el `65532` del `revisor`, ya lo tiene en cero sin `--cap-drop ALL`. Lo que agregas después, se agrega con nombre: una carpeta escribible con `--tmpfs` o un volumen, una capacidad con `--cap-add`.

## Lo que se hace mal

**Acortar el plazo de `docker stop` para que «no tarde tanto».** Con `-t 2`, un programa que no atiende la señal muere en 2 segundos en vez de 10, pero muere igual de mal: `137`, sin terminar lo que hacía. El arreglo es que la señal llegue (`--init`, forma *exec*, un manejador), no que maten antes.

**Un plazo interno de apagado más largo que el de Docker.** Si tu programa espera 15 segundos a sus peticiones y Docker le da 10, el apagado ordenado nunca termina. Ajusta uno o el otro (`--stop-timeout`), pero que quepa.

**Confundir `Up` con «funciona».** `docker ps` dice `Up` mientras el proceso exista. Si el contenedor no tiene `HEALTHCHECK`, nadie está preguntando si atiende.

**Una revisión de salud que depende de otros servicios.** Si la salud del `revisor` dependiera de los servicios que revisa, una caída ajena lo pondría `unhealthy` a él. La revisión pregunta por el propio proceso.

**Una revisión cara.** Se corre cada pocos segundos durante toda la vida del contenedor. Una consulta a una base de datos completa, o un reporte entero, cada diez segundos, es carga que nadie pidió.

**Esperar que `--restart` cure a un contenedor `unhealthy`.** Ninguna política mira la salud. Lo viste en 7.5: racha de cuatro fallas, cero reinicios.

**Quitar `--read-only` porque «el programa necesita escribir».** El programa necesita escribir en **un** lugar. Dale ese lugar con nombre.

**`--privileged` o `--cap-add ALL` para salir del paso.** Deshace la lección entera. Si algo pide una capacidad, averigua cuál y agrega solo esa.

**Creer lo que dice `docker inspect` sin mirar `/proc`.** `docker inspect` muestra lo que pediste. `/proc/<pid>/status` muestra lo que el núcleo aplica. Normalmente coinciden; cuando no, el que manda es el núcleo.

## Ejercicios

Hazlos en orden. Antes de correr cada uno, escribe en tu [bitácora](bitacora.md) lo que crees que va a pasar; compararlo después es la mitad del aprendizaje. Al terminar, borra lo que creaste: todo lleva el prefijo `curso-docker-`.

### Ejercicio 1 — Lee el final

Sin correr nada, di qué `ExitCode` deja cada contenedor y qué tardaría aproximadamente `docker stop` cuando aplique. Usa la tabla de 7.1.2.

1. El `revisor` 1.4.0, corriendo bien, detenido con `docker stop`.
2. La imagen de Go corriendo `sleep 300`, sin `--init`, detenida con `docker stop`.
3. La misma, con `--init`, detenida con `docker stop`.
4. El `revisor` 1.4.0 sin `REVISOR_SERVICIOS`, sin política de reinicio.
5. El `revisor` 1.4.0 corriendo bien, terminado con `docker kill`.
6. Un contenedor `(unhealthy)` cuya bitácora de salud dice `-1 "OCI runtime exec failed: ..."`. ¿Qué código tiene el **contenedor**?

### Ejercicio 2 — ¿Cuánto tarda en enfermarse?

Con la imagen `curso-docker-prueba:1.0.0` de la Lección 2, predice cuánto tarda en pasar a `unhealthy` un contenedor que arranca en modo caído con estas opciones, y cuánto vale su racha de fallas en ese momento:

```bash
docker run -d --name curso-docker-prueba -e PRUEBA_MODO=caido \
  --health-interval 2s --health-retries 5 --health-start-period 1ms \
  curso-docker-prueba:1.0.0
```

Después mídelo: pregunta cada medio segundo con `docker inspect --format '{{.State.Health.Status}}' curso-docker-prueba` y cuenta los segundos desde que lo arrancaste. Las opciones `--health-*` de `docker run` cambian las de la imagen para ese contenedor. Bórralo con `docker rm -f curso-docker-prueba` y repite con `--health-start-period 0s`. Antes de correrlo, predice: ¿tarda lo mismo? Pista: lee otra vez el punto 2 de 7.4.4. Al final, `docker rm -f curso-docker-prueba`.

### Ejercicio 3 — Otra señal de apagado (proyecto)

Si el contenedor de 7.10 sigue corriendo, bórralo primero con `docker rm -f curso-docker-revisor`. Después corre tu imagen con otra señal de apagado:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --stop-signal SIGINT \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.4.0
```

Antes de detenerlo, predice tres cosas: qué dirá su registro al apagarse (`docker logs curso-docker-revisor`), con qué código terminará y qué señal mostrará `docker inspect --format '{{.Config.StopSignal}}' curso-docker-revisor`. Después detenlo con `docker stop curso-docker-revisor`, mide el tiempo con `time` y compara. Pista: mira qué señales atiende el `revisor` en 7.1.1. Pregunta extra: ¿qué pasaría con `--stop-signal SIGHUP`, una señal que el código del `revisor` no pidió? Al final, `docker rm -f curso-docker-revisor`.

### Ejercicio 4 — Endurece el servicio de prueba

Corre el servicio de prueba con las opciones endurecidas de 7.10.1 (sin el puerto y sin `-e`, que no le hacen falta):

```bash
docker run -d --name curso-docker-prueba \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  curso-docker-prueba:1.0.0
```

Antes, predice: ¿llegará a `healthy`? ¿Necesita un `--tmpfs`? ¿Quién será el número 1 y con qué usuario? ¿Con qué código terminará al detenerlo? Después compruébalo con `docker ps --filter name=curso-docker-prueba`, `docker top curso-docker-prueba -o pid,user,args`, `docker stop curso-docker-prueba`, `docker inspect --format '{{.State.ExitCode}}' curso-docker-prueba` y `docker logs curso-docker-prueba`. Al final, `docker rm -f curso-docker-prueba`.

## Soluciones

Las soluciones 2, 3 y 4 se midieron con dos guiones que hacen lo mismo que los ejercicios, con nombres de apoyo `fig07` y sin publicar puertos: `fig07_08.sh` (servicio de prueba) y `fig07_09.sh` (`revisor`).

### Solución 1

1. **`0`**, en décimas de segundo: el `revisor` atiende `SIGTERM` y sale por su cuenta (7.4.4).
2. **`137`**, en algo más de 10 segundos: `sleep` es el número 1, no tiene manejador, la señal se ignora y al final llega `SIGKILL` (7.1.4).
3. **`143`**, en décimas de segundo: `docker-init` reenvía la señal, `sleep` ya no es el número 1 y muere con la acción por omisión de `SIGTERM`, 128 + 15 (7.3.2).
4. **`1`**: el `revisor` termina solo, con su propio código de error, sin que nadie le mande nada. `docker stop` no aplica: ya está detenido.
5. **`137`**: `docker kill` manda `SIGKILL` sin esperar. Y, si tuviera política `always`, no volvería a arrancar, porque cuenta como detención a mano (7.6.2).
6. **Ninguno**, porque el contenedor sigue corriendo: `unhealthy` es una etiqueta, no una muerte. El `-1` es el código de la **revisión**, no del contenedor. Su `.State.ExitCode` vale `0` mientras corre.

### Solución 2

```bash
#!/usr/bin/env bash
# fig07_08.sh — Las soluciones de los Ejercicios 2 y 4, con el servicio de prueba:
# cuánto tarda en enfermarse con otros tiempos de salud, y cómo corre con las
# opciones endurecidas de la lección.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}

for arranque in 0s 1ms; do
  echo "== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period $arranque"
  inicio=$(t)
  docker run -d --name "$NOMBRE" -e PRUEBA_MODO=caido \
    --health-interval 2s --health-retries 5 --health-start-period "$arranque" "$IMAGEN" >/dev/null
  esperar_salud unhealthy; fin=$(t)
  echo "pasó a unhealthy a los $(( (fin - inicio) / 100 ))00 ms de arrancar"
  docker inspect --format 'racha={{.State.Health.FailingStreak}} StartPeriod={{.Config.Healthcheck.StartPeriod}}' "$NOMBRE"
  docker rm -f "$NOMBRE" >/dev/null
  echo
done

echo "== Ejercicio 4: el servicio de prueba con las opciones endurecidas"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
docker top "$NOMBRE" -o pid,user,args | sed -E 's/^ *[0-9]+ /<pid> /'
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1
```

```text
$ ./fig07_08.sh
== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 0s
pasó a unhealthy a los 13400 ms de arrancar
racha=5 StartPeriod=5s

== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 1ms
pasó a unhealthy a los 10900 ms de arrancar
racha=5 StartPeriod=1ms

== Ejercicio 4: el servicio de prueba con las opciones endurecidas
Up 5 seconds (healthy)
PID                 USER                COMMAND
<pid>             65532               /sbin/docker-init -- /servicio-prueba
<pid>             65532               /servicio-prueba
docker stop tardó 234 ms; ExitCode=0
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando
```

Con `--health-start-period 1ms`, pasó a `unhealthy` a los **10.9 segundos**, con `racha=5`. La cuenta es 5 fallas con 2 segundos entre revisiones, 10 segundos, más lo que tarda cada revisión (ejecutar un proceso dentro del contenedor no es gratis). La racha vale exactamente lo que pediste en `--health-retries`: la salud cambia justo en la falla número 5.

Con `--health-start-period 0s` tardó **13.4 segundos**, y el renglón de `docker inspect` dice por qué: `StartPeriod=5s`. Un cero en una opción `--health-*` de `docker run` no apaga nada; significa «usa el de la imagen», y el Dockerfile del servicio de prueba dice `--start-period=5s`. Durante esos 5 segundos Docker pregunta cada `--start-interval` (5 s), así que la primera revisión llegó a los 5 segundos, y las siguientes cada 2: a los 5, 7, 9, 11 y 13. La quinta falla cae a los 13. Si tu predicción fue «unos diez segundos» para el primero y «unos trece» para el segundo, entendiste la cuenta y la trampa. Los tiempos exactos cambian de una corrida a otra; las rachas, no.

### Solución 3

```bash
#!/usr/bin/env bash
# fig07_09.sh — La solución del Ejercicio 3: el revisor con otra señal de apagado.
# SIGINT, que el revisor atiende, y SIGHUP, que no pidió, sin y con --init.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

t() { date +%s%3N; }
SERVICIOS='propio http://127.0.0.1:8080/salud'

for prueba in "SIGINT" "SIGHUP" "SIGHUP --init"; do
  set -- $prueba
  echo "== --stop-signal $1 ${2:-sin --init}"
  docker run -d --name "$NOMBRE" --stop-signal "$1" ${2:-} -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
  sleep 1
  inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop tardó $(( fin - inicio )) ms"
  docker inspect --format 'ExitCode={{.State.ExitCode}} StopSignal={{.Config.StopSignal}}' "$NOMBRE"
  docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
  docker rm -f "$NOMBRE" >/dev/null
  echo
done
```

```text
$ ./fig07_09.sh
== --stop-signal SIGINT sin --init
docker stop tardó 102 ms
ExitCode=0 StopSignal=SIGINT
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí interrupt, apagando
revisor: apagado limpio

== --stop-signal SIGHUP sin --init
docker stop tardó 72 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))

== --stop-signal SIGHUP --init
docker stop tardó 87 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
```

Con `SIGINT`: `interrupt` es como Go nombra a `SIGINT`, igual que `terminated` es `SIGTERM`. El `revisor` instaló manejador para las dos, así que se apaga igual de bien con cualquiera: código `0`, en milisegundos. `--stop-signal` quedó anotado en la configuración del contenedor (`StopSignal=SIGINT`) y gana sobre el `STOPSIGNAL SIGTERM` de la imagen.

Pregunta extra, con `SIGHUP`: murió en milisegundos con `ExitCode=129` (128 + 1), sin y con `--init`, y su registro se queda en `escuchando`, sin `apagando` ni `apagado limpio`. No esperó los 10 segundos, aunque sin `--init` es el número 1, porque todo programa de Go trae de fábrica un manejador para esa señal: la documentación de Go dice que «`SIGHUP`, `SIGINT` o `SIGTERM` hacen que el programa termine» ([os/signal](https://pkg.go.dev/os/signal)). Hay manejador, así que la señal llega; pero ese manejador de fábrica termina el programa de golpe, sin el apagado en orden que el `revisor` hace solo con `SIGTERM` y `SIGINT`. Que el código salga `129` también con el `revisor` como número 1 depende de cómo el *runtime* de Go termina el programa; es lo que midió Docker 29.2.1 con Go 1.27.3. La regla práctica no cambia: la señal de apagado se elige mirando el código, y `STOPSIGNAL` la deja escrita.

### Solución 4

Es el último bloque de `fig07_08.sh`. Llega a `healthy` sin `--tmpfs`, porque el servicio de prueba no escribe ningún archivo. El número 1 es `docker-init` y su hijo es el servicio, los dos con `65532`, el usuario que fija su Dockerfile. Se detiene en décimas de segundo con `0`: atiende `SIGTERM`, como el `revisor`. Es la misma línea de opciones que la Lección 8 le pone al servicio de prueba cuando lo mete en una red interna, y por eso ahí ya no tendrás que pensarla.

## Cómo sé que lo logré

Marca cada punto solo si puedes hacerlo **sin volver a ver el texto**:

- [ ] En tu carpeta, `docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0` muestra `["CMD","/revisor","healthcheck"]` con `Interval` de diez segundos.
- [ ] Explicas en un minuto por qué `sleep 300` muere con `SIGTERM` en tu terminal y no como número 1 de un contenedor, usando las palabras *manejador*, *acción por omisión* y *número 1*.
- [ ] Mides `docker stop` de un `sleep` sin y con `--init`, y obtienes algo más de 10 segundos con `137`, y décimas de segundo con `143`.
- [ ] Ves un zombi con `ps --ppid` en tu equipo, y explicas por qué `docker top` no lo muestra.
- [ ] Pones al servicio de prueba en modo caído y lees en `docker inspect` `running / unhealthy`, la racha de fallas y la causa `GET / respondió 503`, con cero reinicios.
- [ ] Dices qué hacen `no`, `on-failure:3`, `always` y `unless-stopped` cuando el proceso muere solo, cuando lo detienes con `docker stop` y cuando se reinicia el daemon.
- [ ] Corres el `revisor` con las opciones de 7.10.1, llega a `(healthy)`, y en `/proc/<pid del revisor>/status` lees `CapBnd: 0000000000000000` y `NoNewPrivs: 1` (y explicas por qué `CapEff` en cero no prueba nada con un usuario que no es `root`).
- [ ] Provocas `read-only file system` con `REVISOR_REPORTE=/tmp/reporte.json` y lo arreglas con un `--tmpfs` de tamaño fijo, sin quitar `--read-only`.
- [ ] Corres los guiones de [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida) (con otro `PUERTO` si los tuyos están ocupados) y tus salidas coinciden con las de esta lección, salvo los milisegundos, los segundos de `Up` y de las esperas, y los números tapados. Y al terminar, `docker ps -a --filter name=curso-docker-` no muestra contenedores de esta lección.

## Resumen

Responde sin mirar la lección:

1. ¿Qué es una señal, y en qué se diferencian `SIGTERM` y `SIGKILL`?
2. ¿Cómo se lee un `ExitCode` de `137`? ¿Y uno de `143`? ¿Y uno de `0` después de `docker stop`?
3. ¿Por qué el proceso número 1 de un contenedor no muere con `SIGTERM` si no instaló un manejador?
4. ¿Qué hace `docker stop` paso a paso, y con qué opciones cambias su plazo y su señal?
5. ¿Qué dos trabajos hace `--init`, y por qué el curso lo usa con el `revisor` aunque hoy no le haga falta?
6. ¿Qué significan los códigos `0`, `1` y `2` de una revisión de salud, y qué significa `-1` en su bitácora?
7. ¿Por qué la revisión del `revisor` es un subcomando del mismo binario y no `curl`?
8. ¿Qué hace Docker con un contenedor `unhealthy`? ¿Y una política de reinicio?
9. ¿En qué se diferencian `always` y `unless-stopped`?
10. ¿Qué cambian `--read-only`, `--cap-drop ALL` y `--security-opt no-new-privileges`, y dónde compruebas que el núcleo los aplica?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html): las señales `SIGINT`, `SIGKILL` y `SIGTERM`, sus números y acciones por omisión, y que `SIGKILL` y `SIGSTOP` no se pueden atrapar, bloquear ni ignorar.
- [pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html): el proceso *init* de un espacio de nombres solo recibe las señales para las que tiene manejador, salvo `SIGKILL` y `SIGSTOP` desde un espacio ancestro; y los huérfanos pasan a ser sus hijos.
- [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html): qué son las capacidades, las definiciones de `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_KILL`, `CAP_SETUID` y `CAP_NET_BIND_SERVICE`, el tope (*bounding set*) y lo que gana un programa *setuid* de `root`.
- [Linux, «No New Privileges Flag»](https://docs.kernel.org/userspace-api/no_new_privs.html): qué hace `no_new_privs` con `execve`, los bits *setuid* y *setgid*, y que se hereda y no se puede apagar.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM` y después `SIGKILL`, el plazo de 10 segundos en Linux, `-t`, `-s` y `-t -1`.
- [`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/): que manda `SIGKILL` por omisión.
- [Referencia de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `--init` y `docker-init`, el PID 1 que ignora las señales con acción por omisión, `--stop-signal`, `--stop-timeout`, `--read-only`, `--tmpfs`, `no-new-privileges`, las opciones `--health-*`, la espera creciente entre reinicios y lo que quita Docker por omisión frente a `--privileged`.
- [Referencia del Dockerfile](https://docs.docker.com/reference/dockerfile/): `HEALTHCHECK` (opciones, valores por omisión, códigos 0, 1 y 2, uno por Dockerfile, `NONE`, 4,096 bytes de salida) y `STOPSIGNAL`.
- [Docker, «Start containers automatically»](https://docs.docker.com/engine/containers/start-containers-automatically/): las cuatro políticas de reinicio y la detención a mano.
- [Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/): que un `tmpfs` vive en memoria y desaparece con el contenedor, su tamaño máximo por omisión y su permiso `1777`.
- [tini](https://github.com/krallin/tini): el *init* mínimo detrás de `docker-init`: un solo hijo, recoger zombis y reenviar señales.
- [os/signal](https://pkg.go.dev/os/signal): que un programa de Go termina por omisión con `SIGHUP`, `SIGINT` o `SIGTERM`.
- [moby/moby #41030](https://github.com/moby/moby/pull/41030): el cambio que pone `net.ipv4.ip_unprivileged_port_start=0` por omisión en los contenedores, desde Docker 20.10.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones y fechas de «Sobre las corridas».
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **capacidad** (*capability*) | uno de los pedazos en que Linux divide el poder de `root`; se quitan con `--cap-drop` y se agregan con `--cap-add` |
| **código de salida** | el número con el que termina un proceso; 128 + *n* si lo terminó la señal *n* |
| **`HEALTHCHECK`** | instrucción que le dice a Docker cómo preguntarle a un contenedor si está sano |
| ***init*** | el proceso número 1; con `--init`, un programa diminuto que reenvía señales y recoge zombis |
| **manejador** (*handler*) | función que un programa instala para atender una señal en lugar de la acción por omisión |
| **`no-new-privileges`** | marca del núcleo que impide que un proceso gane privilegios al ejecutar otro programa |
| **plazo** (de `docker stop`) | lo que Docker espera entre `SIGTERM` y `SIGKILL`; 10 segundos por omisión |
| **política de reinicio** | lo que hace el daemon cuando el proceso de un contenedor termina |
| **señal** | aviso corto del núcleo a un proceso, identificado por un número |
| ***setuid*** | bit de un ejecutable que lo hace correr con el usuario dueño del archivo |
| **`tmpfs`** | carpeta que vive en memoria y desaparece con el contenedor |
| **zombi** | proceso que ya terminó y espera que su padre lea su código de salida |

---

**Siguiente:** [Lección 8 — Volúmenes y redes](08-volumenes-y-redes.md)
