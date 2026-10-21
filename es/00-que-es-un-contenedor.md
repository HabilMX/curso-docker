# Lección 0 — Qué es un contenedor y qué NO es

Son las 2:14 de la madrugada y suena la alerta: el servidor de pruebas dejó de responder. Entras como puedes y lo primero que ves es que la base de datos, que vivía en ese mismo equipo, ya no está corriendo. El registro del sistema dice que el núcleo la mató por falta de memoria. Alguien en el chat del equipo escribe, convencido: «No puede ser el `revisor`, ese corre en un contenedor; está aislado, es como una máquina aparte». Diez minutos después aparece el culpable: el contenedor del `revisor`, sin ningún límite, se había comido la memoria de todo el equipo hasta que el núcleo tuvo que escoger a quién matar, y escogió a la base de datos. Nadie mintió. Lo que pasó es que esa persona tenía una idea equivocada de lo que es un contenedor, y esa idea costó una noche. Esta lección existe para que tú no la tengas.

**Tiempo:** 90 min

**Qué construyes:** nada todavía. Es una lección de lectura: aquí se arma el mapa mental con el que el resto del curso se vuelve predecible. Trae nueve programas cortos para que veas con tus ojos lo que la lección afirma.

**Qué aprendes:** que un contenedor es un proceso aislado y no una máquina virtual; con qué piezas del núcleo de Linux se construye ese aislamiento (espacios de nombres y grupos de control); la diferencia entre una imagen y un contenedor; que Docker son dos programas, un cliente y un daemon; y qué comparte un contenedor con el equipo anfitrión y por qué eso decide la seguridad.

**De dónde vienes.** No traes nada de este curso: todavía no instalas Docker. Traes, eso sí, lo que el curso da por sabido: usas una terminal con soltura, sabes qué es un proceso (un programa que está corriendo) y qué es un servidor HTTP. Quizá ya escribiste el `revisor` en el curso de Go, Rust o TypeScript de esta casa. Si no, basta con esto: es un programa que consulta una lista de servicios a la vez y entrega un reporte de cuáles están arriba, cuáles lentos y cuáles caídos. Lo que probablemente no traes es una idea precisa de qué es un contenedor por dentro, y esa idea es la que vas a necesitar cada vez que algo falle.

**Qué no hace esta lección.** No instala nada (eso es la [Lección 1](01-instalacion.md)) y no enseña los comandos de Docker uno por uno (eso empieza en la [Lección 2](02-contenedores-dia-a-dia.md)). Los programas de esta lección son guiones de *bash* de diez a treinta renglones que llaman a `docker` y a herramientas normales de Linux como `ps` y `uname`. No hace falta que entiendas cada opción todavía, aunque cada una se explica: lo que importa es lo que **imprimen**. Se corren después de la Lección 1, cuando ya tengas Docker.

**Sobre las corridas.** Las salidas de esta lección se obtuvieron el 21 de octubre de 2026 en una Mac con [Colima](https://github.com/abiosoft/colima), que levanta una máquina virtual de Linux para poder correr contenedores. Esa máquina virtual tiene Ubuntu 24.04.4, que es la misma base de Linux Mint 22, así que **los guiones se corrieron dentro de ella** y es ahí donde aparece el «anfitrión» en las salidas: en tu Mint, el anfitrión es tu propia computadora y los mismos comandos funcionan sin cambios. La versión de Docker dentro de esa máquina era la 29.2.1 (cliente y daemon). El curso se planeó con la 29.8.2 y, el día de esta corrida, la más reciente publicada era la 29.9.2, del 20 de octubre de 2026, según las [notas de versión oficiales](https://docs.docker.com/engine/release-notes/29/). Nada de lo que muestra esta lección cambia entre esas versiones; la Lección 1 te enseña a ver la tuya. Lo que **sí** cambia entre una corrida y otra, y se avisa donde ocurre: los números de proceso (PID), los números de los espacios de nombres, los tiempos y, si tu computadora es de procesador Intel o AMD, la palabra `arm64`, que en la tuya dirá `amd64`. Los programas están en [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor), en el repositorio del curso, cada uno con su salida guardada al lado.

## Al terminar vas a poder

- Mostrar con `ps` que un contenedor que corre es un proceso más del equipo anfitrión, y encontrar su número de proceso desde fuera.
- Explicar con un ejemplo por qué un contenedor no es una máquina virtual, usando la palabra *núcleo*.
- Nombrar los espacios de nombres que Docker aísla y los dos que, por omisión, no aísla.
- Leer en `/sys/fs/cgroup` los límites de memoria, CPU y procesos de un contenedor, y decir qué pasa cuando no hay ninguno.
- Distinguir una imagen de un contenedor, y predecir qué le pasa a un archivo escrito dentro de un contenedor cuando ese contenedor se borra.
- Explicar qué hacen el cliente `docker` y el daemon `dockerd`, y por dónde se hablan.
- Decir qué comparte un contenedor con el anfitrión y por qué eso convierte a «root dentro del contenedor» en un asunto de seguridad.

## El porqué antes del cómo

Imagina que terminas el `revisor` y alguien te pide que lo pongas a correr en un servidor. Lo más directo es copiar el ejecutable y lanzarlo. Funciona, hasta que deja de funcionar: el servidor tiene otra versión de alguna biblioteca, o el puerto 8080 ya lo usa otro programa, o el `revisor` tiene un error que lo hace consumir memoria sin parar y se lleva entre las patas a todo lo demás que corre ahí. Y cuando por fin descubres que en tu máquina sí funcionaba, la frase «en mi máquina sí funciona» ya no le sirve a nadie.

Los contenedores nacieron para resolver eso: entregar un programa **junto con todo lo que necesita para correr**, y correrlo **apartado** de los demás, con límites. Eso es verdad y es muy útil. El problema empieza cuando esa descripción se convierte en una imagen mental equivocada: «un contenedor es una computadora chiquita dentro de la mía». Con esa imagen, la escena del principio es imposible: ¿cómo va a matar una computadora chiquita a un programa de la grande? Con la imagen correcta, la escena es obvia.

La imagen correcta es esta, y es la que la propia documentación de Docker usa: un contenedor es un **proceso aislado** ([Docker, «What is a container?»](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)). No es otra computadora. Es un programa que corre en **tu** computadora, sobre **tu** núcleo de Linux, al que el núcleo le pone paredes (para que no vea lo que no debe) y un presupuesto (para que no gaste lo que no debe). Si las paredes están bien puestas, el proceso cree que está solo. Si no hay presupuesto, puede gastar todo.

La lección tiene siete partes, en este orden:

1. **Un contenedor es un proceso** (0.1): lo miras desde dentro y desde fuera.
2. **No es una máquina virtual** (0.2): el núcleo compartido y lo que eso implica.
3. **Las paredes: espacios de nombres** (0.3).
4. **El presupuesto: grupos de control** (0.4), con el error de esta lección.
5. **Imagen contra contenedor** (0.5).
6. **El cliente y el daemon** (0.6).
7. **Lo que se comparte y la seguridad** (0.7), y un poco de historia para ubicarte (0.8).

Con ese destino en mente, esto es lo que verás en la sección 0.4, cuando un contenedor con un límite de memoria intente pasarse de él. Es lo que le faltó al contenedor de la escena:

```text
voy a comer memoria...
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

## Los conceptos

### 0.1 Un contenedor es un proceso

#### 0.1.1 Mirarlo desde dentro y desde fuera

La forma más rápida de quitarse la idea de la «computadora chiquita» es arrancar un contenedor y buscarlo con las herramientas de siempre. El programa `fig00_01.sh` arranca un contenedor que no hace nada más que dormir cinco minutos (`sleep 300`), lo mira desde dentro, lo mira desde fuera y lo borra al terminar:

```bash
#!/usr/bin/env bash
# fig00_01.sh — Un contenedor es un proceso del equipo anfitrión.
# Arranca un contenedor que solo duerme, lo mira desde dentro y desde fuera,
# y lo borra al final.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-dormilon
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null

echo "== 1. Desde DENTRO del contenedor: todos sus procesos"
docker exec "$NOMBRE" ps -o pid,user,args

echo
echo "== 2. Desde FUERA: el mismo proceso, visto por Docker"
PID_ANFITRION=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
echo "PID en el anfitrión: $PID_ANFITRION"

echo
echo "== 3. Desde FUERA: el mismo proceso, visto por el sistema operativo"
ps -o pid,ppid,user,args -p "$PID_ANFITRION"

echo
echo "== 4. Quién es su padre en el anfitrión"
PPID_ANFITRION=$(ps -o ppid= -p "$PID_ANFITRION" | tr -d ' ')
ps -o pid,user,comm -p "$PPID_ANFITRION"
```

```text
$ ./fig00_01.sh
== 1. Desde DENTRO del contenedor: todos sus procesos
PID   USER     COMMAND
    1 root     sleep 300
    7 root     ps -o pid,user,args

== 2. Desde FUERA: el mismo proceso, visto por Docker
PID en el anfitrión: 836426

== 3. Desde FUERA: el mismo proceso, visto por el sistema operativo
    PID    PPID USER     COMMAND
 836426  836402 root     sleep 300

== 4. Quién es su padre en el anfitrión
    PID USER     COMMAND
 836402 root     containerd-shim
```

Los números `836426` y `836402` cambian en cada corrida; todo lo demás sale igual. Antes de leer la salida, los renglones que importan del guion. `set -euo pipefail` hace que el guion se detenga ante el primer error, en vez de seguir como si nada. `trap ... EXIT` deja programado que, pase lo que pase, al salir se borre el contenedor: así no queda basura en tu equipo, una costumbre que la Lección 2 vuelve regla. `docker run -d` arranca el contenedor «en segundo plano» (*detached*) y le pone un nombre con `--name`; todos los nombres de este curso empiezan con `curso-docker-` para que sepas de un vistazo qué es tuyo. `docker exec` ejecuta un comando **dentro** de un contenedor que ya está corriendo, y `docker inspect` pregunta datos de un contenedor; aquí, su número de proceso en el anfitrión.

Ahora la salida, bloque por bloque:

1. **Desde dentro**, el contenedor ve solo dos procesos: `sleep 300`, que tiene el número **1**, y el `ps` que acabas de lanzar. No ve tu navegador, ni tu terminal, ni nada de lo que corre en tu equipo. Desde su punto de vista, él es el primer proceso del sistema.
2. **Desde fuera**, Docker te dice que ese mismo proceso tiene el número 836426 en el anfitrión.
3. Y **el sistema operativo del anfitrión** lo confirma con un `ps` normal, el mismo que usarías para cualquier otro programa: ahí está `sleep 300`, corriendo como `root`. No hay otra computadora. Hay un proceso más en la lista de tu equipo.
4. Su padre es `containerd-shim`, un pequeño programa que Docker pone a cuidar a cada contenedor. (El nombre completo es `containerd-shim-runc-v2`; `ps` lo recorta porque el campo `comm` solo guarda 15 caracteres.)

🔑 **Lee eso otra vez: el mismo proceso tiene dos números.** Dentro es el 1; fuera es el 836426. No son dos procesos: es uno solo, visto desde dos lugares. Que tenga dos números es la primera pista de cómo funciona el aislamiento, y la sección 0.3 la explica.

#### 0.1.2 Qué significa que sea un proceso

Que un contenedor sea un proceso no es un detalle técnico; tiene consecuencias que vas a sentir todo el curso:

- **Arranca en milisegundos**, porque arrancar un proceso es rápido. No hay sistema operativo que encender.
- **Se muere como un proceso.** Si el programa principal termina, el contenedor termina. Si el núcleo lo mata, el contenedor muere. En la Lección 7 vas a ver que eso incluye las señales: `docker stop` le manda a ese proceso número 1 la misma señal que mandarías con `kill`.
- **Gasta como un proceso.** Usa la memoria y la CPU de tu equipo, de la misma bolsa que todos los demás programas. Si nadie le pone límite, no tiene límite.
- **Lo ves con tus herramientas de siempre.** `ps`, `top` y el monitor del sistema lo muestran. Eso es útil para diagnosticar y es una advertencia: quien tiene poder sobre los procesos del anfitrión tiene poder sobre los contenedores.

> [!NOTE]
> 🔧 **Observación de ingeniería 0.1**
> Una buena imagen mental se reconoce porque predice. Con «es una computadora chiquita», no puedes predecir que el contenedor aparezca en `ps` del anfitrión. Con «es un proceso aislado», lo predices antes de correr el programa. A lo largo del curso, cuando algo te sorprenda, pregúntate primero qué haría un proceso normal en esa situación.

### 0.2 No es una máquina virtual

#### 0.2.1 Dos distribuciones, un solo núcleo

Una **máquina virtual** es un programa que imita una computadora completa: un procesador, memoria, disco y tarjeta de red de mentira. Dentro de esa computadora de mentira arranca un sistema operativo entero, **con su propio núcleo**. Por eso en una máquina virtual puedes correr Windows sobre Linux o Linux sobre una Mac.

El **núcleo** (*kernel*) es la parte del sistema operativo que manda sobre el hardware: reparte la memoria, decide qué proceso usa la CPU en cada instante, habla con el disco y la red. Todo lo demás —el *shell*, `ls`, el gestor de paquetes, las bibliotecas— corre encima de él y le pide las cosas. A eso de encima se le suele llamar el **espacio de usuario**.

Un contenedor no trae núcleo. Trae solo espacio de usuario. Lo prueba `fig00_02.sh`, que pregunta la distribución y la versión del núcleo en el anfitrión y en dos contenedores de distribuciones distintas:

```bash
#!/usr/bin/env bash
# fig00_02.sh — Dos imágenes de dos distribuciones distintas, un solo núcleo.
set -euo pipefail
ALPINE=alpine:3.24.2
DEBIAN=debian:13.7-slim

distro() { grep '^PRETTY_NAME=' "$1" | cut -d= -f2 | tr -d '"'; }

echo "== El anfitrión"
echo "distribución: $(distro /etc/os-release)"
echo "núcleo:       $(uname -r)"

for IMAGEN in "$ALPINE" "$DEBIAN"; do
  echo
  echo "== Un contenedor de $IMAGEN"
  docker run --rm --name curso-docker-distro "$IMAGEN" sh -c '
    echo "distribución: $(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d "\"")"
    echo "núcleo:       $(uname -r)"'
done
```

```text
$ ./fig00_02.sh
== El anfitrión
distribución: Ubuntu 24.04.4 LTS
núcleo:       6.8.0-100-generic

== Un contenedor de alpine:3.24.2
distribución: Alpine Linux v3.24
núcleo:       6.8.0-100-generic

== Un contenedor de debian:13.7-slim
distribución: Debian GNU/Linux 13 (trixie)
núcleo:       6.8.0-100-generic
```

En tu Mint, la primera línea dirá `Linux Mint 22...` y el núcleo será el de tu equipo; lo que importa es que **los tres números de núcleo serán iguales entre sí**. El archivo `/etc/os-release` es donde cada distribución escribe su nombre, y `uname -r` pregunta al núcleo su versión. La opción `--rm` le pide a Docker que borre el contenedor en cuanto termine.

Mira lo que pasó. Dentro del contenedor de Alpine, el archivo dice que estás en Alpine 3.24. Dentro del de Debian, que estás en Debian 13. Pero cuando le preguntas **al núcleo**, los tres contestan lo mismo: `6.8.0-100-generic`, el del anfitrión. Los archivos son de Alpine o de Debian; el núcleo es uno solo, compartido. Es exactamente lo que dice la documentación: «si corres varios contenedores, todos comparten el mismo núcleo» ([Docker, «What is a container?»](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)).

De aquí sale una regla que conviene grabarse: **una «imagen de Debian» no es Debian**. Es el espacio de usuario de Debian —sus programas, sus bibliotecas, su gestor de paquetes— corriendo sobre el núcleo que tú tengas. Casi siempre eso basta, porque la interfaz del núcleo de Linux cambia muy poco entre versiones. Pero si un programa necesita una función de un núcleo más nuevo que el tuyo, la imagen no se la va a traer.

#### 0.2.2 La prueba al revés: por qué una Mac necesita una máquina virtual

Si un contenedor de Linux necesita un núcleo de Linux, ¿qué pasa en una computadora que no tiene uno? Pasa lo que viste en «Sobre las corridas»: hay que conseguirle uno. En macOS, Colima levanta una máquina virtual de Linux y dentro de ella corre Docker. Docker Desktop, la aplicación de escritorio de Docker, hace lo mismo con su propia máquina virtual: según su documentación, «el daemon de Docker y los contenedores corren en una máquina virtual ligera de Linux administrada por Docker» ([Docker Desktop, permisos en Mac](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/)).

Esa máquina virtual no es un accidente; es la confirmación de todo lo anterior. Si los contenedores trajeran su propio núcleo, no la necesitarían. Tu Mint no la necesita: el núcleo de Linux ya está ahí, y los contenedores corren directo sobre él. Ese es uno de los motivos por los que el curso usa Linux como sistema de referencia: lo que ves es lo que hay, sin una capa en medio.

#### 0.2.3 La comparación completa

| | Máquina virtual | Contenedor |
|---|---|---|
| Qué es | una computadora imitada por software | un proceso con paredes y presupuesto |
| Núcleo | el suyo propio | el del anfitrión, compartido |
| Qué arranca | un sistema operativo completo | un programa |
| Tiempo de arranque | segundos a minutos | milisegundos |
| Puede correr otro sistema operativo | sí (Windows sobre Linux, por ejemplo) | no: un contenedor de Linux necesita un núcleo de Linux |
| Qué la separa del anfitrión | el hipervisor, que imita hardware | el núcleo, que pone las paredes |
| Si algo escapa del aislamiento | llega a la máquina imitada | llega al núcleo que comparten todos |

La última fila es la que importa para la seguridad, y la retomamos en 0.7.

Sobre el tiempo de arranque, no hace falta creerlo: se mide. `fig00_09.sh` crea, corre y borra un contenedor que no hace nada (`true` es un programa que termina de inmediato), cinco veces seguidas:

```bash
#!/usr/bin/env bash
# fig00_09.sh — Cuánto tarda en nacer, trabajar y morir un contenedor.
# Cinco veces seguidas, con una imagen que ya está descargada.
set -euo pipefail
IMAGEN=alpine:3.24.2
for i in 1 2 3 4 5; do
  inicio=$(date +%s%N)
  docker run --rm --name curso-docker-rapido "$IMAGEN" true
  fin=$(date +%s%N)
  echo "corrida $i: $(( (fin - inicio) / 1000000 )) ms"
done
```

```text
$ ./fig00_09.sh
corrida 1: 136 ms
corrida 2: 154 ms
corrida 3: 431 ms
corrida 4: 347 ms
corrida 5: 507 ms
```

Estos números cambian siempre: dependen de tu equipo y de qué más esté haciendo en ese momento. En otra corrida en la misma máquina salieron entre 135 y 194 ms. Lo estable es el orden de magnitud: **décimas de segundo**, para crear el contenedor, arrancar el proceso, esperarlo y borrar todo. Una máquina virtual tarda eso solo en empezar a cargar su núcleo.

### 0.3 Las paredes: espacios de nombres

#### 0.3.1 Qué es un espacio de nombres

Volvamos a la pista de 0.1: el mismo proceso es el número 1 dentro y el 836426 fuera. ¿Cómo puede un proceso tener dos números? Porque el núcleo de Linux tiene una función llamada **espacios de nombres** (*namespaces*). Un espacio de nombres es una «vista» privada de algún recurso del sistema. Los procesos que están dentro de un espacio de nombres ven su propia versión de ese recurso, y no ven la de los demás.

Docker lo dice sin rodeos: usa «una tecnología llamada *namespaces* para dar el espacio de trabajo aislado que se llama contenedor» ([Docker, «What is Docker?»](https://docs.docker.com/get-started/docker-overview/)). Hay ocho tipos, y cada uno aísla una cosa distinta. La lista viene del manual de Linux ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)):

| Tipo | Nombre en `/proc` | Qué aísla | Qué se ve en un contenedor |
|---|---|---|---|
| PID | `pid` | los números de proceso | su programa es el número 1 y no ve los procesos del anfitrión |
| Mount | `mnt` | los puntos de montaje | ve su propio árbol de archivos, el de la imagen, y no el tuyo |
| Network | `net` | interfaces, direcciones, puertos | tiene su propia red y su propio puerto 8080 |
| UTS | `uts` | el nombre del equipo | tiene su propio *hostname* |
| IPC | `ipc` | la comunicación entre procesos por memoria compartida | no se cruza con la de otros programas |
| Cgroup | `cgroup` | la raíz de los grupos de control | ve su propio grupo como si fuera la raíz (0.4) |
| User | `user` | los números de usuario y grupo | **por omisión, no se aísla** |
| Time | `time` | ciertos relojes del sistema | **por omisión, no se aísla** |

La fila de Network explica algo que vas a usar desde la Lección 2: dos contenedores pueden escuchar en el puerto 8080 al mismo tiempo sin pelearse, porque cada uno tiene su propia red. La de Mount explica por qué el contenedor de Debian veía archivos de Debian aunque tu equipo sea Mint.

#### 0.3.2 Verlo con tus ojos

Cada proceso de Linux tiene una carpeta `/proc/<número>/ns/` con un enlace por cada tipo de espacio de nombres. Lo que contiene ese enlace es el tipo y un número, por ejemplo `pid:[4026531836]`. El manual lo explica así: si dos procesos están en el mismo espacio de nombres, ese número es el mismo ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)). Entonces basta comparar números. Eso hace `fig00_03.sh`, que lee los ocho enlaces del anfitrión y de un contenedor y los pone lado a lado:

```bash
#!/usr/bin/env bash
# fig00_03.sh — Los espacios de nombres (namespaces) del anfitrión y de un contenedor.
# Si el número entre corchetes coincide, los dos procesos comparten ese espacio.
set -euo pipefail
IMAGEN=alpine:3.24.2
TIPOS="cgroup ipc mnt net pid time user uts"

LISTA='for n in '"$TIPOS"'; do echo "$n $(readlink /proc/self/ns/$n)"; done'

ANFITRION=$(sh -c "$LISTA")
CONTENEDOR=$(docker run --rm --name curso-docker-ns "$IMAGEN" sh -c "$LISTA")

printf '%-7s %-20s %-20s %s\n' TIPO ANFITRION CONTENEDOR ¿IGUAL?
for n in $TIPOS; do
  a=$(echo "$ANFITRION"  | awk -v t="$n" '$1==t {print $2}')
  c=$(echo "$CONTENEDOR" | awk -v t="$n" '$1==t {print $2}')
  if [ "$a" = "$c" ]; then igual="sí, compartido"; else igual="no, aislado"; fi
  printf '%-7s %-20s %-20s %s\n' "$n" "${a#*:}" "${c#*:}" "$igual"
done
```

```text
$ ./fig00_03.sh
TIPO    ANFITRION            CONTENEDOR           ¿IGUAL?
cgroup  [4026531835]         [4026532382]         no, aislado
ipc     [4026531839]         [4026532379]         no, aislado
mnt     [4026531841]         [4026532377]         no, aislado
net     [4026531840]         [4026532383]         no, aislado
pid     [4026531836]         [4026532380]         no, aislado
time    [4026531834]         [4026531834]         sí, compartido
user    [4026531837]         [4026531837]         sí, compartido
uts     [4026531838]         [4026532378]         no, aislado
```

Los números entre corchetes cambian de un equipo a otro y los del contenedor cambian en cada corrida; la columna `¿IGUAL?` sale igual siempre que uses la configuración por omisión de Docker. `/proc/self` es un atajo que siempre apunta al proceso que lo lee, y `readlink` muestra a dónde apunta un enlace.

Seis paredes y dos huecos. El contenedor tiene sus propios procesos, su propio árbol de archivos, su propia red, su propio nombre de equipo, su propia memoria compartida y su propia vista de los grupos de control. Pero comparte con el anfitrión los relojes (`time`) y, sobre todo, **los usuarios** (`user`). Que el espacio de usuarios sea el mismo significa que el número de usuario 0, `root`, es **el mismo `root`** dentro y fuera. Ya lo viste en 0.1: el `sleep 300` aparecía en el anfitrión como de `root`. Docker soporta aislar también los usuarios, pero no lo hace por omisión ([Docker Engine security](https://docs.docker.com/engine/security/)). Todo esto vale para Docker en su modo normal, el que instala la Lección 1: el daemon corre como `root` y sin remapeo de usuarios. Hay dos modos que cambian la historia. Con [`userns-remap`](https://docs.docker.com/engine/security/userns-remap/), el `root` de dentro es en el anfitrión un número de usuario alto y sin privilegios; en [modo *rootless*](https://docs.docker.com/engine/security/rootless/), el daemon y sus contenedores corren dentro de un espacio de usuarios sin privilegios. En los dos, la fila `user` de la tabla diría «no, aislado». La máquina de estas corridas usa el modo normal: `docker info --format '{{.SecurityOptions}}'` imprimió `[name=apparmor name=seccomp,profile=builtin name=cgroupns]`, sin `rootless` ni `userns`, y así puedes revisar el tuyo. Esa es la mitad de la historia de seguridad de 0.7.

> [!NOTE]
> 🔧 **Observación de ingeniería 0.2**
> Un espacio de nombres **esconde**; no **limita**. Que el contenedor no vea los procesos del anfitrión no le impide gastar toda su memoria. Lo primero es trabajo de los espacios de nombres; lo segundo, de los grupos de control. La escena del principio es la confusión entre las dos cosas.

### 0.4 El presupuesto: grupos de control

#### 0.4.1 Qué es un grupo de control

Los **grupos de control** (*control groups*, casi siempre abreviados *cgroups*) son la otra mitad del trabajo. Son un mecanismo del núcleo para acomodar procesos en grupos y repartir entre esos grupos los recursos del sistema —memoria, CPU, número de procesos, lectura y escritura de disco— de forma controlada ([documentación del núcleo, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). La guía de seguridad de Docker lo resume en una frase: los grupos de control «implementan la contabilidad y el límite de recursos» ([Docker Engine security](https://docs.docker.com/engine/security/)).

Cada contenedor vive en su propio grupo. El núcleo lleva la cuenta de cuánto gasta ese grupo y, si tiene un límite, no lo deja pasar de ahí. Los límites se pueden leer como archivos de texto en `/sys/fs/cgroup`. Tres de ellos van a aparecer en todo el curso:

- `memory.max`: cuánta memoria puede usar el grupo. Si llega a ese límite y no puede liberar nada, el núcleo llama al «asesino por falta de memoria» (*OOM killer*) **dentro de ese grupo** ([cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)).
- `cpu.max`: dos números, «cuánto tiempo» y «cada cuánto». Por omisión vale `max 100000`, que significa sin tope en cada periodo de 100,000 microsegundos (una décima de segundo).
- `pids.max`: cuántos procesos puede tener el grupo como máximo.

#### 0.4.2 Sin límite no hay límite

Lo más importante de esta sección es lo que Docker hace **si no le pides nada**. La documentación es explícita: «por omisión, un contenedor no tiene restricciones de recursos» y puede usar todo lo que el planificador del núcleo le deje ([Docker, «Resource constraints»](https://docs.docker.com/engine/containers/resource_constraints/)). `fig00_04.sh` lee los tres archivos en un contenedor sin límites y en otro con límites:

```bash
#!/usr/bin/env bash
# fig00_04.sh — Los grupos de control (cgroups): lo que el núcleo deja gastar.
# Primero sin límites, después con límites de memoria, CPU y procesos.
set -euo pipefail
IMAGEN=alpine:3.24.2
LEER='for f in memory.max cpu.max pids.max; do printf "%-11s %s\n" "$f" "$(cat /sys/fs/cgroup/$f)"; done'

echo "== Sin límites (lo que Docker hace si no le pides nada)"
docker run --rm --name curso-docker-sin-limites "$IMAGEN" sh -c "$LEER"

echo
echo "== Con --memory 64m --cpus 0.5 --pids-limit 50"
docker run --rm --name curso-docker-con-limites \
  --memory 64m --cpus 0.5 --pids-limit 50 \
  "$IMAGEN" sh -c "$LEER"
```

```text
$ ./fig00_04.sh
== Sin límites (lo que Docker hace si no le pides nada)
memory.max  max
cpu.max     max 100000
pids.max    max

== Con --memory 64m --cpus 0.5 --pids-limit 50
memory.max  67108864
cpu.max     50000 100000
pids.max    50
```

Esta salida es estable, con dos condiciones. La primera, la versión 2 de los grupos de control, que es la que tiene Ubuntu 24.04, la base de Mint 22 (la máquina de estas corridas la reporta: `stat -fc %T /sys/fs/cgroup` imprime `cgroup2fs`). La segunda, que estén encendidos los *controladores* `memory`, `cpu` y `pids`, que son las piezas del núcleo que llevan cada cuenta: en la versión 2 se encienden uno por uno, y un archivo como `memory.max` solo aparece en un grupo si su controlador está encendido ([documentación del núcleo, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). En una instalación normal de Mint lo están; para comprobarlo, `cat /sys/fs/cgroup/cgroup.controllers` debe incluir esas tres palabras (en la máquina de estas corridas imprimió `cpuset cpu io memory hugetlb pids rdma misc`). Si falta alguna, Docker puede avisarlo con un `WARNING` al final de `docker info` ([Docker, restricciones de recursos](https://docs.docker.com/engine/containers/resource_constraints/)), el archivo correspondiente no existe dentro del contenedor y tu salida no se parecerá a esta. Sin límites, los tres archivos dicen `max`: el contenedor puede usar toda la memoria del equipo, toda la CPU y crear todos los procesos que quiera. Ese era el contenedor de la escena.

Con límites, cada opción de `docker run` se convierte en un número que el núcleo hace cumplir:

- `--memory 64m` se volvió `67108864`, que son 64 × 1024 × 1024 bytes: 64 MiB exactos.
- `--cpus 0.5` se volvió `50000 100000`: en cada décima de segundo, el grupo puede usar la CPU durante la mitad, 50,000 microsegundos. Es media CPU.
- `--pids-limit 50` se volvió `50`.

Fíjate en la cadena de responsabilidades. Tú escribes una opción en `docker run`; Docker la traduce y la escribe en un archivo del núcleo; el núcleo es quien la aplica. Docker no vigila al contenedor: el que vigila es el núcleo. Por eso el límite funciona aunque el programa de dentro sea malicioso o esté descompuesto.

#### 0.4.3 Lo que pasa cuando se alcanza el límite

Un límite que nunca se toca no enseña nada. `fig00_05.sh` arranca un contenedor con 32 MiB de memoria y sin espacio de intercambio (*swap*), y le pide algo que no puede cumplir: `tail /dev/zero` lee un archivo infinito de ceros buscando el final de la última línea, y como nunca llega un salto de línea, guarda todo en memoria sin parar:

```bash
#!/usr/bin/env bash
# fig00_05.sh — El error de esta lección: el núcleo mata al proceso que pasa su límite.
# El contenedor intenta llenar la memoria; tiene un tope de 32 MiB y sin swap.
set -uo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-gloton
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run --name "$NOMBRE" --memory 32m --memory-swap 32m \
  "$IMAGEN" sh -c 'echo "voy a comer memoria..."; tail /dev/zero'
echo "código de salida: $?"

echo
echo "== Lo que Docker anotó"
docker inspect --format 'OOMKilled={{.State.OOMKilled}}  ExitCode={{.State.ExitCode}}' "$NOMBRE"
```

```text
$ ./fig00_05.sh
voy a comer memoria...
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

Esta salida es estable. Aquí no se usa `--rm`, a propósito: si Docker borrara el contenedor al terminar, no podrías preguntarle después qué le pasó. `--memory-swap 32m` fija el total de memoria más intercambio en el mismo valor que la memoria, o sea, cero de intercambio; sin eso, el proceso tardaría más en morir porque primero llenaría el disco de intercambio.

El contenedor imprimió su mensaje, empezó a comer memoria y, al llegar a 32 MiB, el núcleo lo mató. Nadie más en el equipo se enteró: la base de datos de la escena, si hubiera estado ahí, seguiría viva. El número **137** es la convención para decir «este proceso murió por una señal»: es 128 más el número de la señal, y la señal 9 es `KILL`, la que no se puede atrapar ni ignorar. La convención no la inventó Docker: es la del *shell*, cuyo manual dice que, cuando un comando termina por la señal N, *bash* usa 128+N como código de salida ([manual de Bash](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html)); puedes comprobarlo en cualquier *bash*: `bash -c 'kill -9 $$'; echo $?` imprime `137`. Docker anota el mismo número en `ExitCode`, y `docker run` lo devuelve tal cual, porque cualquier código distinto de 125, 126 y 127 es el del comando del contenedor ([Docker, códigos de salida](https://docs.docker.com/engine/containers/run/)). Y `OOMKilled=true` es Docker confirmando que fue por falta de memoria. La sección «El error que vas a ver» te dice cómo leer esto cuando aparezca sin que lo hayas provocado.

Ahora puedes reescribir la escena con precisión. El contenedor del `revisor` estaba en su propio espacio de nombres —no veía a la base de datos—, pero en un grupo de control sin límite —gastaba de la misma bolsa—. Cuando la bolsa se vació, el núcleo tuvo que matar a alguien **en todo el equipo**, no solo en el grupo del contenedor, y escogió a otro. Con `--memory`, el asesino habría actuado **dentro del grupo** del `revisor`, y solo el `revisor` habría muerto. La Lección 2 pone límites desde el primer contenedor por esta razón.

### 0.5 Imagen contra contenedor

#### 0.5.1 La plantilla y la copia viva

Hasta aquí has usado dos palabras como si fueran intercambiables, y no lo son. La documentación de Docker las define así: una **imagen** es «una plantilla de solo lectura con instrucciones para crear un contenedor», y un **contenedor** es «una instancia ejecutable de una imagen» ([Docker, «What is Docker?»](https://docs.docker.com/get-started/docker-overview/)).

Una comparación que ayuda, si vienes de programar: la imagen es como un ejecutable en disco y el contenedor es como el proceso que corre a partir de él. Del mismo ejecutable puedes lanzar diez procesos; de la misma imagen puedes crear diez contenedores. Si el proceso escribe algo en su memoria, el ejecutable en disco no cambia.

La pieza que falta es dónde escribe un contenedor cuando crea un archivo. La respuesta, según la documentación del almacenamiento de Docker: una imagen está hecha de **capas** de solo lectura, y al crear un contenedor se le agrega encima una capa delgada **en la que sí se puede escribir**, llamada la capa del contenedor. Todo lo que el contenedor cambia va a esa capa. Varios contenedores pueden compartir la misma imagen, cada uno con su capa propia. Y cuando el contenedor se borra, su capa se borra con él, mientras que la imagen de abajo «sigue sin cambios» ([Docker, «Storage drivers»](https://docs.docker.com/engine/storage/drivers/)).

#### 0.5.2 Verlo con tus ojos

`fig00_06.sh` crea dos contenedores de la misma imagen, escribe un archivo en uno, mira si el otro lo ve, pregunta qué cambió en cada uno y, al final, borra el primero:

```bash
#!/usr/bin/env bash
# fig00_06.sh — Imagen contra contenedor: una plantilla, dos copias vivas.
set -euo pipefail
IMAGEN=alpine:3.24.2
A=curso-docker-uno
B=curso-docker-dos
trap 'docker rm -f "$A" "$B" >/dev/null 2>&1 || true' EXIT

echo "== La imagen antes de empezar"
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22

docker run -d --name "$A" "$IMAGEN" sleep 300 >/dev/null
docker run -d --name "$B" "$IMAGEN" sleep 300 >/dev/null

echo
echo "== Escribo un archivo en el contenedor uno"
docker exec "$A" sh -c 'echo "hola desde uno" > /tmp/nota.txt && cat /tmp/nota.txt'

echo
echo "== ¿Lo ve el contenedor dos?"
docker exec "$B" cat /tmp/nota.txt || echo "(el contenedor dos no tiene ese archivo)"

echo
echo "== Lo que cambió en cada contenedor respecto de su imagen (docker diff)"
echo "-- uno:"; docker diff "$A"
echo "-- dos:"; docker diff "$B"; echo "(nada)"

echo
echo "== Borro el contenedor uno y miro la imagen otra vez"
docker rm -f "$A" >/dev/null
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22
docker run --rm --name curso-docker-tres "$IMAGEN" sh -c 'cat /tmp/nota.txt 2>&1 || true'
```

```text
$ ./fig00_06.sh
== La imagen antes de empezar
id=sha256:294b683cb724

== Escribo un archivo en el contenedor uno
hola desde uno

== ¿Lo ve el contenedor dos?
cat: can't open '/tmp/nota.txt': No such file or directory
(el contenedor dos no tiene ese archivo)

== Lo que cambió en cada contenedor respecto de su imagen (docker diff)
-- uno:
C /tmp
A /tmp/nota.txt
-- dos:
(nada)

== Borro el contenedor uno y miro la imagen otra vez
id=sha256:294b683cb724
cat: can't open '/tmp/nota.txt': No such file or directory
```

El identificador `294b683cb724` es el de la imagen `alpine:3.24.2` para procesadores ARM de 64 bits; en un equipo Intel o AMD será otro, pero será **el mismo al principio y al final** de la corrida, que es lo que importa. `docker diff` muestra qué cambió un contenedor respecto de su imagen: `A` significa agregado (*added*) y `C`, cambiado (*changed*); la carpeta `/tmp` aparece como cambiada porque ahora contiene algo nuevo.

Lee la salida como una historia de cuatro momentos:

1. La imagen tiene un identificador, una huella de su contenido.
2. El contenedor uno escribe `/tmp/nota.txt` y lo lee sin problema. El contenedor dos, hecho **de la misma imagen**, no lo tiene: cada uno escribe en su propia capa.
3. `docker diff` lo confirma: el uno agregó un archivo; el dos no cambió nada.
4. Se borra el contenedor uno. La imagen tiene **el mismo identificador**: nada de lo que hizo el contenedor la tocó. Y un contenedor nuevo de esa imagen tampoco tiene la nota. El archivo se fue con el contenedor.

Las consecuencias para el resto del curso son dos y las dos son importantes. La primera: **lo que se escribe dentro de un contenedor es desechable**. Si el `revisor` guarda su reporte dentro del contenedor y alguien lo borra, el reporte se va. Por eso existe la Lección 8, con los volúmenes. La segunda: **una imagen no se arregla entrando al contenedor**. Si entras con `docker exec` a corregir algo, corriges esa copia viva, no la plantilla; el próximo contenedor nace sin tu arreglo. Las imágenes se cambian reconstruyéndolas desde su receta, el `Dockerfile`, que es lo que aprendes en la Lección 3.

### 0.6 El cliente y el daemon

#### 0.6.1 Dos programas, no uno

Cuando escribes `docker run`, parece que un solo programa hace todo. No es así. Docker usa una arquitectura **cliente-servidor**: el programa `docker` que tecleas es solo un **cliente**, y el trabajo de verdad lo hace un **daemon** llamado `dockerd`, un programa que corre en segundo plano todo el tiempo. Según la documentación, el daemon «escucha las peticiones de la API de Docker y administra los objetos de Docker» —imágenes, contenedores, redes y volúmenes—, y cliente y daemon se hablan «usando una API REST, sobre *sockets* de UNIX o una interfaz de red» ([Docker, «What is Docker?»](https://docs.docker.com/get-started/docker-overview/)).

Un ***socket* de UNIX** es un archivo especial que sirve para que dos programas del mismo equipo se manden mensajes. El del daemon de Docker está, por omisión, en `/var/run/docker.sock`. Y ya viste a quién le toca crear los contenedores: el `containerd-shim` que apareció como padre del `sleep` en 0.1 es parte de la cadena que el daemon pone en marcha. Tú le pides al cliente; el cliente le pide al daemon; el daemon, con ayuda de otras piezas, le pide al núcleo los espacios de nombres y los grupos de control.

`fig00_07.sh` muestra las dos mitades y qué pasa cuando el cliente no encuentra al daemon:

```bash
#!/usr/bin/env bash
# fig00_07.sh — El cliente y el daemon son dos programas distintos.
set -uo pipefail

echo "== Las dos versiones: la del cliente y la del daemon"
docker version --format 'cliente: {{.Client.Version}} ({{.Client.Os}}/{{.Client.Arch}})
daemon:  {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'

echo
echo "== Por dónde habla el cliente con el daemon"
docker context inspect --format '{{.Endpoints.docker.Host}}'

echo
echo "== El cliente apuntando a un daemon que no existe"
DOCKER_HOST=unix:///tmp/curso-docker-no-hay-daemon.sock docker ps
echo "código de salida: $?"
```

```text
$ ./fig00_07.sh
== Las dos versiones: la del cliente y la del daemon
cliente: 29.2.1 (linux/arm64)
daemon:  29.2.1 (linux/arm64)

== Por dónde habla el cliente con el daemon
unix:///var/run/docker.sock

== El cliente apuntando a un daemon que no existe
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
código de salida: 1
```

En tu equipo cambian las versiones y, si es Intel o AMD, dirá `amd64`. `docker context inspect` muestra a qué daemon apunta el cliente, y la variable de entorno `DOCKER_HOST` sirve para apuntarlo a otro; aquí, a propósito, a uno que no existe.

Tres cosas que se aprenden de esta salida:

1. **`docker version` reporta dos versiones**, porque son dos programas. Casi siempre coinciden, pero no tienen por qué: en la Mac de estas corridas, el cliente de macOS era la 29.8.2 y el daemon de la máquina virtual, la 29.2.1. Cuando un comando se porta raro, la primera pregunta es cuál de las dos versiones lo está causando.
2. **El cliente y el daemon se hablan por el *socket***. Es una puerta, y quien pueda abrirla manda sobre el daemon.
3. **Sin daemon, el cliente no sirve para nada.** El mensaje dice exactamente eso: no pudo conectarse a la API de Docker en esa ruta; revisa que la ruta sea correcta y que el daemon esté corriendo. En tu Mint vas a ver este mensaje con la ruta `/var/run/docker.sock` el día que el servicio de Docker esté detenido.

#### 0.6.2 Por qué importa saberlo

Parece una curiosidad de arquitectura y no lo es. El daemon corre como `root`: la guía de seguridad dice que «requiere privilegios de `root`», salvo que actives el modo *rootless*, y que por eso «solo usuarios de confianza» deben poder controlarlo ([Docker Engine security](https://docs.docker.com/engine/security/)). Si puedes pedirle cosas al daemon, puedes pedirle que cree un contenedor con la carpeta raíz de tu equipo montada adentro, y lo hará como `root`. Por eso la documentación de instalación advierte que el grupo `docker` «otorga privilegios equivalentes a los de `root`» al usuario ([Docker, pasos posteriores a la instalación en Linux](https://docs.docker.com/engine/install/linux-postinstall/)). La Lección 1 te pone en ese grupo y te hace mirar la consecuencia de frente. Y la Lección 2 te prohíbe, con este mismo argumento, montar el *socket* del daemon dentro de un contenedor: eso le daría al contenedor la llave de tu equipo.

### 0.7 Lo que se comparte y por qué decide la seguridad

#### 0.7.1 Root dentro es root fuera

Ya juntaste todas las piezas para la pregunta más seria de la lección: ¿qué tan separado está un contenedor del anfitrión? `fig00_08.sh` pregunta quién es el usuario dentro, de quién es el proceso visto desde fuera y qué poderes tiene:

```bash
#!/usr/bin/env bash
# fig00_08.sh — Lo que el contenedor comparte con el anfitrión: el usuario y el núcleo.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-quien
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== Dentro del contenedor, ¿quién soy?"
docker run --rm --name curso-docker-id "$IMAGEN" id

echo
echo "== Y desde el anfitrión, ¿de quién es ese proceso?"
docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null
PID=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
ps -o uid,user,args -p "$PID"

echo
echo "== Las capacidades efectivas de ese root (máscara en hexadecimal)"
echo "$(docker run --rm --name curso-docker-cap1 "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, por omisión"
echo "$(docker run --rm --name curso-docker-cap2 --cap-drop ALL "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, con --cap-drop ALL"
echo "$(grep CapEff /proc/1/status | cut -f2)  proceso 1 del anfitrión (root)"
```

```text
$ ./fig00_08.sh
== Dentro del contenedor, ¿quién soy?
uid=0(root) gid=0(root) groups=0(root),0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)

== Y desde el anfitrión, ¿de quién es ese proceso?
  UID USER     COMMAND
    0 root     sleep 300

== Las capacidades efectivas de ese root (máscara en hexadecimal)
00000000a80425fb  contenedor, por omisión
0000000000000000  contenedor, con --cap-drop ALL
000001ffffffffff  proceso 1 del anfitrión (root)
```

Esta salida es estable con la configuración por omisión de Docker. La última línea depende de cuántas capacidades conozca tu núcleo; con uno de la serie 6.8 sale igual.

Los dos primeros bloques dicen lo mismo desde los dos lados: dentro del contenedor eres el usuario 0, `root`, y fuera ese proceso **también** es del usuario 0. No es un `root` de juguete con el mismo nombre: como el espacio de nombres de usuarios no se aisló (0.3), es el mismo número de usuario para el mismo núcleo. Si ese proceso lograra salirse de sus paredes —por un error del núcleo, por una carpeta del anfitrión montada sin cuidado, por el *socket* del daemon—, llegaría al anfitrión como `root`.

#### 0.7.2 Un root recortado: las capacidades

Entonces, ¿un contenedor es tan peligroso como un programa que corre como `root` en tu equipo? No del todo, y el tercer bloque explica por qué. Linux divide los poderes de `root` en unidades separadas llamadas **capacidades** (*capabilities*), que se pueden encender y apagar una por una ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Cambiar el dueño de un archivo es una; abrir un puerto menor a 1024, otra; cargar módulos en el núcleo, otra.

La línea `CapEff` de `/proc/<pid>/status` dice qué capacidades tiene encendidas un proceso, como una máscara de bits en hexadecimal. El proceso 1 del anfitrión, que es `root` de verdad, tiene `000001ffffffffff`: las 41 capacidades que conoce este núcleo, todas encendidas. El `root` del contenedor tiene `00000000a80425fb`, que son **14**. Al decodificar esa máscara con la herramienta `capsh` del anfitrión salen exactamente las catorce que la documentación de Docker lista como permitidas por omisión: `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `FSETID`, `KILL`, `SETGID`, `SETUID`, `SETPCAP`, `NET_BIND_SERVICE`, `NET_RAW`, `SYS_CHROOT`, `MKNOD`, `AUDIT_WRITE` y `SETFCAP` ([Docker, «Running containers»](https://docs.docker.com/engine/containers/run/)). Docker usa una lista de lo permitido, no de lo prohibido: quita todo y deja solo eso ([Docker Engine security](https://docs.docker.com/engine/security/)). Y con `--cap-drop ALL` puedes quitarle incluso esas catorce, como muestra la segunda línea; la Lección 7 te enseña a quitar las que el `revisor` no usa.

La opción contraria existe y conviene reconocerla para no usarla: `--privileged` «le da todas las capacidades al contenedor» y además acceso a todos los dispositivos del anfitrión ([Docker, «Running containers»](https://docs.docker.com/engine/containers/run/)). Con ella, casi no queda pared.

#### 0.7.3 El mapa de lo compartido

| Lo que el contenedor tiene propio, por omisión | Lo que comparte con el anfitrión, por omisión |
|---|---|
| sus procesos y sus números de proceso | **el núcleo**, el mismo para todos los contenedores |
| su árbol de archivos (el de su imagen y su capa) | **los usuarios**: `root` dentro es el usuario 0 fuera |
| su red, sus puertos, su nombre de equipo | los relojes del sistema |
| su vista de los grupos de control | **la memoria, la CPU y el disco**, si no le pones límites |
| | **lo que tú le montes o le publiques**: carpetas, puertos, el *socket* |

La columna de la derecha es la lista de lo que tienes que cuidar. Cada lección del curso cierra una parte: la 2 pone límites y publica puertos solo en `127.0.0.1`; la 3 deja de usar `root` con `USER`; la 7 quita capacidades y pone el sistema de archivos en solo lectura; la 8 cuida lo que se monta. No es paranoia: es la diferencia entre un proceso con paredes y un proceso con paredes de papel.

> [!NOTE]
> 🔧 **Observación de ingeniería 0.3**
> En una máquina virtual, para escapar hay que romper el hipervisor, que imita un hardware sencillo. En un contenedor, para escapar basta encontrar un error en el núcleo, que es enorme y que todos los contenedores comparten. Por eso los contenedores se endurecen con varias capas a la vez (sin `root`, sin capacidades sobrantes, con límites) y no se confía en una sola.

### 0.8 De dónde salió todo esto

Nada de lo anterior lo inventó Docker. Las piezas son del núcleo de Linux y llegaron poco a poco. La guía de seguridad de Docker lo cuenta: los espacios de nombres entraron al núcleo entre las versiones 2.6.15 y 2.6.26, esta última de julio de 2008, y los grupos de control empezaron en 2006 y se integraron en la versión 2.6.24 ([Docker Engine security](https://docs.docker.com/engine/security/)). Durante años hubo herramientas que los usaban, pero eran difíciles de manejar.

Lo que cambió en 2013 fue la **forma de usarlos**. El 15 de marzo de ese año, en una charla relámpago de cinco minutos en la conferencia PyCon, Solomon Hykes contó que en su empresa usaban contenedores de Linux, que era complicado y que por eso no lo habían platicado, «hasta ahora: Docker» ([PyCon US 2013, «The future of Linux Containers»](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html)). Docker juntó las piezas del núcleo con dos ideas propias: un formato de imagen que se puede compartir y unos comandos que cualquiera entiende.

Dos años después, el 22 de junio de 2015, Docker, CoreOS y otras empresas fundaron la **Open Container Initiative** (OCI), y Docker le donó su formato y su programa para crear contenedores, `runc` ([OCI, «About»](https://opencontainers.org/about/overview/)). Hoy la OCI mantiene tres especificaciones: la del entorno de ejecución, la del formato de imagen y la de distribución. Para ti eso significa algo práctico: la imagen que construyas en este curso no es «una imagen de Docker» encerrada en Docker, es una imagen OCI, y por eso el clúster de Kubernetes del curso siguiente la puede correr sin Docker. Por cierto, `runc` es el programa que aparece al final del nombre `containerd-shim-runc-v2` que viste en 0.1.

### 0.9 Lo que viene en el resto del curso

Con el mapa de esta lección, cada lección siguiente es una pieza que ya sabes dónde va:

- La **Lección 1** instala el cliente, el daemon y las piezas de en medio en tu Mint.
- La **Lección 2** maneja procesos aislados: arrancarlos, mirarlos, ponerles presupuesto (0.4) y borrarlos.
- Las **Lecciones 3, 4 y 5** construyen la **imagen** del `revisor` (0.5): su receta, sus capas y cómo hacerla pequeña.
- La **Lección 6** separa la configuración y los secretos de la imagen.
- La **Lección 7** se ocupa del proceso número 1 (0.1) y de recortar sus poderes (0.7).
- La **Lección 8** resuelve que la capa del contenedor sea desechable (0.5) y conecta contenedores por red (0.3).
- La **Lección 9** describe todo eso en un archivo, y la **10** entrega la imagen OCI (0.8) lista para Kubernetes.

## El error que vas a ver

Esta lección tiene un error principal, el del contenedor que el núcleo mata, y uno secundario, el del cliente sin daemon. Los dos vienen de secciones anteriores.

**El error principal: el código 137 y `OOMKilled=true`.** Es el de `fig00_05.sh`:

```text
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

Se lee así: el proceso no terminó por su cuenta; lo mató la señal 9 (`137 = 128 + 9`), y Docker anotó que la causa fue la falta de memoria. Lo traicionero es que en la vida real el contenedor **no te avisa**: no imprime nada, simplemente desaparece, y si tiene una política de reinicio vuelve a arrancar y a morir una y otra vez. Cuando veas un 137, la primera pregunta es `docker inspect --format '{{.State.OOMKilled}}' <contenedor>`. Si dice `true`, hay dos arreglos posibles, según el caso: subir el límite de memoria, si el programa de verdad necesita más; o corregir el programa, si está gastando de más. Lo que **no** se hace es quitar el límite «para que no se muera»: eso no lo arregla, solo cambia quién muere, como en la escena.

**El error secundario: el cliente que no encuentra al daemon.**

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

Se lee de izquierda a derecha: el cliente no se pudo conectar a la API de Docker en esa ruta; te sugiere revisar la ruta y que el daemon esté corriendo; y al final viene la causa técnica, que el archivo del *socket* no existe. En tu Mint, con la ruta `/var/run/docker.sock`, casi siempre significa que el servicio de Docker está detenido. Si en lugar de `no such file or directory` dice `permission denied`, el daemon sí está, pero tu usuario no tiene permiso de hablarle: eso es asunto de la Lección 1.

## El hábito de seguridad de la lección

**Saber qué comparte un contenedor con el equipo, y no confiar en lo que no aísla.** El contenedor comparte el núcleo, los usuarios y, si no le pones límites, la memoria y la CPU. Este hábito evita dos accidentes concretos. El primero es el de la escena: un contenedor sin límite que tumba a otros programas del mismo equipo. El segundo es más grave: tratar a un contenedor como si fuera una máquina aparte y darle cosas del anfitrión —el *socket* del daemon, la carpeta raíz montada, `--privileged`— pensando que «adentro no pasa nada». Adentro corre un proceso de `root` de tu propio núcleo. Todo lo que le des, se lo das a ese proceso.

## Lo que se hace mal

**Decir «es como una máquina virtual ligera».** Es la frase más repetida y la que más daño hace, porque lleva a esperar un aislamiento que no existe. Un contenedor es un proceso aislado; una máquina virtual es una computadora imitada. Se parecen en lo que se ve desde fuera y se diferencian en lo que importa cuando algo falla.

**Correr contenedores sin límites «porque en mi equipo sobra memoria».** Por omisión no hay límite, y lo que sobra hoy no sobra el día que el programa tiene un error. El límite no es para el caso normal; es para el día malo.

**Entrar al contenedor a «arreglar» algo.** Lo que cambies con `docker exec` vive en la capa del contenedor y se va con él. La corrección se hace en la receta de la imagen y se reconstruye.

**Guardar datos importantes dentro del contenedor.** Por la misma razón: la capa del contenedor es desechable. Los datos que deben sobrevivir van en volúmenes (Lección 8).

**Suponer que `root` dentro es inofensivo.** Es el usuario 0 del mismo núcleo, con 14 capacidades encendidas. Menos que el `root` del anfitrión, pero mucho más que un usuario normal. Desde la Lección 3, el `revisor` no corre como `root`.

**Creer que una imagen de Ubuntu o de Debian trae ese sistema operativo completo.** Trae su espacio de usuario. El núcleo es el tuyo. Si tu núcleo no soporta algo, la imagen tampoco.

**Confundir el cliente con el daemon.** Cuando un comando falla, saber si el problema está en el cliente (versión, configuración, `DOCKER_HOST`) o en el daemon (detenido, sin permisos, otra versión) ahorra horas de buscar en el lugar equivocado.

## Ejercicios

Los ejercicios de esta lección no necesitan Docker para contestarse: el primero y el cuarto son de razonamiento, y el segundo y el tercero se contestan **antes** de correr nada y se comprueban después de la Lección 1. Escribe tus predicciones en la [bitácora](bitacora.md) antes de ver las soluciones; compararlas es la mitad del aprendizaje.

### Ejercicio 1 — La noche del `revisor` (proyecto)

Vuelve a la escena del principio. Contesta con tus palabras, usando lo que aprendiste:

1. ¿Por qué el contenedor del `revisor` no «veía» a la base de datos, pero sí pudo matarla?
2. ¿Qué opción de `docker run` habría evitado que muriera la base de datos, y quién habría muerto en su lugar?
3. Si en ese momento hubieras corrido `docker inspect` sobre el contenedor del `revisor`, ¿qué esperarías ver en `OOMKilled`? Piensa bien: ¿quién mató a quién?

### Ejercicio 2 — ¿Igual o distinto?

Para cada pareja, predice si el valor sale **igual** o **distinto**. Supón la configuración por omisión de Docker.

1. `uname -r` en tu Mint y dentro de un contenedor de `debian:13.7-slim`.
2. `cat /etc/os-release` en tu Mint y dentro de ese mismo contenedor.
3. `readlink /proc/self/ns/net` en tu Mint y dentro de un contenedor.
4. `readlink /proc/self/ns/user` en tu Mint y dentro de un contenedor.
5. El número de proceso del programa principal visto dentro del contenedor, y visto desde el anfitrión.
6. El identificador de una imagen antes y después de borrar un contenedor que escribió archivos.

### Ejercicio 3 — Predice el `memory.max`

Predice qué número aparece en `/sys/fs/cgroup/memory.max` dentro de cada uno de estos contenedores, y luego compruébalo cambiando las opciones de `fig00_04.sh`:

1. `docker run --rm alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
2. `docker run --rm --memory 128m alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
3. `docker run --rm --memory 1g alpine:3.24.2 cat /sys/fs/cgroup/memory.max`

Y una de CPU: ¿qué dirá `cpu.max` con `--cpus 1.5`?

### Ejercicio 4 — Explícalo en cinco frases

Un compañero te dice: «Instalé Docker para tener una máquina virtual de Ubuntu dentro de mi Mint». Explícale en cinco frases como máximo qué es lo que tiene en realidad, usando las palabras *proceso*, *núcleo*, *espacio de nombres*, *grupo de control* e *imagen*. Sin mirar la lección.

## Soluciones

### Solución 1

1. Porque el contenedor estaba en sus propios **espacios de nombres**: con el de procesos (`pid`) no veía los procesos del anfitrión, la base de datos entre ellos. Pero ver y gastar son cosas distintas: sin un límite en su **grupo de control**, gastaba de la misma memoria que todo el equipo. Cuando se acabó, el núcleo tuvo que matar a alguien en todo el sistema, y escogió a la base de datos.
2. `--memory` (por ejemplo, `--memory 256m`, el número depende de cuánto necesita de verdad el `revisor`). Con ese límite, al llegar al tope el núcleo habría actuado **dentro del grupo** del contenedor, y el que habría muerto es el propio `revisor`, con código 137 y `OOMKilled=true`. La base de datos ni se habría enterado.
3. Lo más probable es `false`. Sin límite propio, el contenedor no llegó a un tope de **su** grupo: lo que se agotó fue la memoria de todo el equipo, y el núcleo mató a la base de datos, que no es un contenedor. El `revisor` siguió vivo. Es justo lo que hace engañosa la escena: el culpable no tiene la marca, la tiene la víctima (y en el registro del sistema, no en Docker).

### Solución 2

1. **Igual.** El núcleo es uno solo, compartido (fig00_02).
2. **Distinto.** El archivo viene de la imagen, que trae el espacio de usuario de Debian (fig00_02).
3. **Distinto.** La red está aislada: cada contenedor tiene su espacio de nombres `net` (fig00_03).
4. **Igual.** Por omisión, Docker no aísla los usuarios (fig00_03). Por eso `root` dentro es el usuario 0 fuera (fig00_08).
5. **Distinto.** Dentro es el 1; fuera, un número cualquiera, como el 836426 de fig00_01. Es el mismo proceso visto desde dos espacios de nombres de procesos.
6. **Igual.** Lo que el contenedor escribió vivía en su capa propia y se fue con él; la imagen no cambió (fig00_06).

Si fallaste en el 4, es el más común y el más importante: es la razón de todo el bloque de seguridad del curso.

### Solución 3

Valores comprobados con el mismo equipo y la misma versión de Docker de la lección:

1. `max`: sin `--memory` no hay límite.
2. `134217728`, que es 128 × 1024 × 1024.
3. `1073741824`, que es 1024 × 1024 × 1024. Docker interpreta la `g` como gibibytes (potencias de 1024), igual que la `m` como mebibytes.

Con `--cpus 1.5`, `cpu.max` dice `150000 100000`: en cada periodo de 100,000 microsegundos, el grupo puede usar 150,000 microsegundos de CPU, repartidos entre los núcleos del procesador. Una CPU y media.

### Solución 4

Una respuesta posible: «No tienes una máquina virtual; tienes un programa que crea **procesos** aislados. Esos procesos corren sobre el **núcleo** de tu Mint, el mismo para todos, y por eso arrancan en décimas de segundo. Los **espacios de nombres** les ponen paredes para que vean sus propios procesos, archivos y red, y los **grupos de control** les ponen un presupuesto de memoria y CPU, si tú se lo pides. Lo de "Ubuntu" viene de la **imagen**: trae los programas y bibliotecas de Ubuntu, pero no su núcleo. Y como el usuario `root` de adentro es el mismo número de usuario que el de afuera, hay que tratarlo con cuidado».

## Cómo sé que lo logré

No hay nada que construir en esta lección, así que la lista mezcla comprensión y, después de la Lección 1, comprobación. Marca cada punto solo si puedes hacerlo **sin volver a ver el texto**:

- [ ] Explicas en un minuto por qué un contenedor no es una máquina virtual, y la palabra *núcleo* aparece en tu explicación.
- [ ] Nombras los seis espacios de nombres que Docker aísla por omisión y los dos que no.
- [ ] Dices qué contienen `memory.max` y `cpu.max` sin límites, y qué significa `50000 100000`.
- [ ] Explicas qué significan el código 137 y `OOMKilled=true`, y qué **no** hay que hacer cuando aparecen.
- [ ] Explicas qué le pasa a un archivo escrito dentro de un contenedor cuando ese contenedor se borra, y por qué la imagen no cambia.
- [ ] Dibujas el camino de `docker run`: cliente → *socket* → daemon → núcleo.
- [ ] Dices por qué el grupo `docker` equivale a `root`.
- [ ] Después de la Lección 1, corres los nueve guiones de [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor) y tus salidas coinciden con las de esta lección en lo que cada sección marca como estable. Lo que no se compara, porque cambia de un equipo o de una corrida a otra: los números de proceso, los números de los espacios de nombres, los tiempos, las versiones y la arquitectura; y si tu Docker corre en modo *rootless* o con remapeo de usuarios, o le falta algún controlador de los grupos de control, las diferencias que 0.3 y 0.4.2 te dijeron que esperaras. Y al terminar, `docker ps -a --filter name=curso-docker-` no muestra nada: no dejaste basura.
- [ ] Anotaste en tu bitácora qué creías que era un contenedor antes de esta lección.

## Resumen

Responde sin mirar la lección:

1. ¿Qué es un contenedor, en tres palabras? ¿Por qué aparece en el `ps` del anfitrión?
2. ¿Qué tiene una máquina virtual que un contenedor no tiene? ¿Por qué una Mac necesita una máquina virtual para correr contenedores de Linux?
3. ¿Qué hace un espacio de nombres? Da tres ejemplos de lo que aísla.
4. ¿Qué hace un grupo de control? ¿Qué límite tiene un contenedor si no le pides ninguno?
5. ¿Qué significan el 137 y `OOMKilled=true`?
6. ¿Qué es una imagen y qué es un contenedor? ¿Dónde escribe un contenedor sus archivos y qué les pasa al borrarlo?
7. ¿Qué hacen el cliente `docker` y el daemon `dockerd`, y por dónde se hablan?
8. ¿Por qué `root` dentro de un contenedor es un asunto de seguridad, y qué lo recorta?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [Docker, «What is a container?»](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/): la definición de contenedor como proceso aislado y la comparación con las máquinas virtuales.
- [Docker, «What is Docker?»](https://docs.docker.com/get-started/docker-overview/): la arquitectura cliente-servidor, el daemon, las definiciones de imagen y contenedor, y el uso de los espacios de nombres.
- [Docker Engine security](https://docs.docker.com/engine/security/): espacios de nombres, grupos de control, la superficie de ataque del daemon, las capacidades y los espacios de nombres de usuario; también las fechas de 0.8.
- [Docker, «Resource constraints»](https://docs.docker.com/engine/containers/resource_constraints/): que un contenedor no tiene límites por omisión, y las opciones `--memory`, `--memory-swap` y `--cpus`.
- [Docker, «Running containers»](https://docs.docker.com/engine/containers/run/): las catorce capacidades permitidas por omisión y lo que hace `--privileged`.
- [Docker, «Storage drivers»](https://docs.docker.com/engine/storage/drivers/): las capas de solo lectura y la capa del contenedor.
- [Docker, pasos posteriores a la instalación en Linux](https://docs.docker.com/engine/install/linux-postinstall/): la advertencia sobre el grupo `docker`.
- [Docker Desktop, permisos en Mac](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/): la máquina virtual de Linux de Docker Desktop.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): las versiones y fechas de «Sobre las corridas».
- [namespaces(7), manual de Linux](https://man7.org/linux/man-pages/man7/namespaces.7.html): los ocho tipos de espacios de nombres y los enlaces de `/proc/<pid>/ns`.
- [capabilities(7), manual de Linux](https://man7.org/linux/man-pages/man7/capabilities.7.html): procesos privilegiados y capacidades.
- [Control Group v2, documentación del núcleo de Linux](https://docs.kernel.org/admin-guide/cgroup-v2.html): `memory.max`, `cpu.max` y `pids.max`.
- [Open Container Initiative, «About»](https://opencontainers.org/about/overview/): la fundación de la OCI y sus tres especificaciones.
- [PyCon US 2013, «The future of Linux Containers»](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html): la charla en la que se presentó Docker.
- [Colima](https://github.com/abiosoft/colima): la herramienta con la que se corrieron los programas en macOS.

### Términos de esta lección

| | |
|---|---|
| **anfitrión** (*host*) | el equipo donde corren los contenedores; en el curso, tu Linux Mint |
| **capa** (*layer*) | cada una de las partes de solo lectura de una imagen; el contenedor agrega una capa propia donde escribir |
| **capacidad** (*capability*) | cada uno de los poderes en que Linux divide al usuario `root` |
| **cliente** | el programa `docker` que tecleas; manda peticiones al daemon |
| **contenedor** | un proceso aislado creado a partir de una imagen |
| **daemon** | programa que corre en segundo plano; el de Docker se llama `dockerd` |
| **espacio de nombres** (*namespace*) | vista privada de un recurso del sistema (procesos, red, archivos...) |
| **espacio de usuario** | todo lo que corre encima del núcleo: programas, bibliotecas, *shell* |
| **grupo de control** (*cgroup*) | mecanismo del núcleo que cuenta y limita los recursos de un grupo de procesos |
| **imagen** | plantilla de solo lectura de la que se crean contenedores |
| **máquina virtual** | una computadora imitada por software, con su propio núcleo |
| **núcleo** (*kernel*) | la parte del sistema operativo que manda sobre el hardware |
| **OCI** | *Open Container Initiative*, el estándar abierto de imágenes y contenedores |
| **OOM killer** | la parte del núcleo que mata procesos cuando se acaba la memoria |
| ***socket* de UNIX** | archivo especial por el que dos programas del mismo equipo se mandan mensajes |

---

**Siguiente:** [Lección 1 — Instalar Docker en tu Linux Mint](01-instalacion.md)
