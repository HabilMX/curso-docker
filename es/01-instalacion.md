# Lección 1 — Instalar Docker en tu Linux Mint

Son las 9:40 de un lunes y la demostración con el equipo es a las 11. Te toca enseñar el `revisor` corriendo en un contenedor, y en tu Linux Mint todavía no hay Docker. Abres el primer tutorial que aparece, copias cinco comandos, y el cuarto te contesta en rojo: `E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.` Pruebas otro tutorial; ese instala un paquete llamado `docker.io` desde la tienda de software, y parece que funciona, hasta que `docker compose` dice que no existe. A las 10:25 encuentras un tercer tutorial que te recomienda, para quitarte el `permission denied` que ahora te sale en cada comando, darle permisos `777` al archivo del *socket*. Funciona. Y acabas de abrirle la puerta de `root` de tu computadora a cualquier programa que corra en ella. Ninguno de los tres tutoriales te dijo por qué pasaba cada cosa. Esta lección hace la instalación una sola vez, en orden, con cada error provocado a propósito y explicado, para que la próxima vez te tome veinte minutos y no una mañana.

**Tiempo:** 90 min

**Qué construyes:** el entorno del curso. Docker Engine instalado en tu Linux Mint desde el repositorio oficial de Docker, tu usuario en el grupo `docker` sabiendo lo que eso significa, y tu primer contenedor, `hello-world`. Trae ocho programas cortos en [`programas/01-instalacion/`](../programas/01-instalacion): cinco solo leen y comprueban (`fig01_01.sh`, `fig01_05.sh`, `fig01_06.sh`, `fig01_07.sh` y `fig01_08.sh`; los de comprobación descargan, a lo más, una imagen de prueba), uno quita los paquetes en conflicto si los tienes (`fig01_02.sh`) y dos sí cambian tu equipo, porque escriben la fuente de `apt` del repositorio de Docker (`fig01_03.sh` y `fig01_04.sh`). La lección te avisa antes de cada uno de los tres.

**Antes de empezar: trae el repositorio del curso.** Los programas de esta lección y de las siguientes viven en la carpeta `programas/` del repositorio del curso. Si todavía no lo tienes en tu Mint, descárgalo desde la página del curso (o clónalo con `git clone` desde la dirección que ahí se indique) y entra a `programas/01-instalacion/`: los guiones se corren desde esa carpeta. Ya traen permiso de ejecución, así que `./fig01_01.sh` basta; si prefieres no depender de ese permiso, `bash fig01_01.sh` hace lo mismo.

**Qué aprendes:** qué piezas instalas y para qué sirve cada una; por qué Linux Mint no es una plataforma oficial de Docker y qué hacer al respecto (la palabra clave es `UBUNTU_CODENAME`); quitar los paquetes que chocan con los oficiales; cómo se agrega un repositorio a `apt` con su llave; cómo comprobar que la instalación funciona; y por qué entrar al grupo `docker` equivale a tener `root`.

**De dónde vienes.** De la [Lección 0](00-que-es-un-contenedor.md) traes el mapa: un contenedor es un proceso aislado que corre sobre el núcleo de tu equipo; Docker son dos programas, el cliente `docker` y el daemon `dockerd`, que se hablan por un *socket* de UNIX en `/var/run/docker.sock`; y el daemon corre como `root`. Esta lección instala esas piezas y te hace mirar de frente la última frase. Del curso, en general, se da por sabido que usas una terminal con soltura y que sabes qué es `sudo`. No hace falta que hayas usado `apt` más allá de `apt install`: lo que necesitas de él se explica aquí.

**Qué no hace esta lección.** No enseña los comandos de Docker uno por uno: eso es tema de la [Lección 2](02-contenedores-dia-a-dia.md). No instala Docker Desktop, la aplicación de escritorio de Docker, y en 1.1 se dice por qué. No instala Docker en modo *rootless* (sin `root`), aunque en 1.9 se explica qué es y cuándo convendría. El `revisor` todavía no aparece: esta lección prepara el equipo donde va a correr, y empaquetarlo empieza en la Lección 3. Y no cubre otras distribuciones: si usas Ubuntu, Debian o Fedora, la [documentación oficial](https://docs.docker.com/engine/install/) tiene una guía para cada una, y lo que aprendes aquí te sirve para leerla.

**Sobre las corridas.** Esta lección es distinta de las demás en un punto, y conviene decirlo antes que nada: **la instalación en sí no se corrió en un Linux Mint**, porque el equipo donde se escribió el curso es una Mac. Para no darte salidas inventadas, cada bloque de salida de esta lección dice de dónde viene, con una de estas tres etiquetas:

| Etiqueta | Qué significa |
|---|---|
| **Corrida real · Mint simulado** | Se corrió de verdad, el 21 de octubre de 2026, en un contenedor de Ubuntu 24.04 para `amd64` (la base de Mint 22, en la arquitectura de un equipo Intel o AMD) al que se le puso el archivo `/etc/os-release` **de Linux Mint 22.3**, sacado del paquete oficial `base-files` del [repositorio de Linux Mint](http://packages.linuxmint.com/) (versión `13ubuntu10mint22.3.0`; la copia está en `programas/01-instalacion/os-release-mint-22.3.txt`). Ese archivo es lo único que distingue a Mint en los pasos de la instalación, y por eso la simulación es fiel en lo que importa. Lo que **no** es igual: el contenedor no tiene los repositorios propios de Mint, así que tus `apt update` mostrarán además renglones de `packages.linuxmint.com`; y los paquetes que ya trae un escritorio completo (`curl`, por ejemplo) en el contenedor hubo que instalarlos. Antes de correr los guiones se le instaló `sudo` al contenedor, que tu Mint ya trae. |
| **Corrida real · máquina virtual** | Se corrió de verdad, el mismo día, en la máquina virtual Ubuntu 24.04.4 (arm64) que [Colima](https://github.com/abiosoft/colima) levanta en la Mac. En esa máquina, Docker 29.2.1 está instalado **con los mismos paquetes oficiales** que instalas tú (`docker-ce`, `containerd.io` y compañía, desde `download.docker.com`), así que las comprobaciones de después de instalar se ven igual. Lo que cambia en tu equipo: las versiones, y `arm64` dirá `amd64`. |
| **De la documentación** | No se corrió: es el texto de la [guía oficial de instalación para Ubuntu](https://docs.docker.com/engine/install/ubuntu/) o de los [pasos posteriores a la instalación](https://docs.docker.com/engine/install/linux-postinstall/), consultadas el 21 de octubre de 2026. Se usa solo donde no había forma honesta de correrlo. |

Las versiones: el curso se planeó con Docker Engine 29.8.2 y Compose v5.6.0 (medidas el 7 de octubre de 2026). El día de estas corridas, el repositorio oficial ofrecía la **29.9.2**, del 20 de octubre de 2026 ([notas de versión](https://docs.docker.com/engine/release-notes/29/)), con Compose 5.6.0 y Buildx 0.38.1, y eso es lo que instalarías tú ese día; la máquina virtual de las corridas tenía la 29.2.1. Nada de lo que enseña esta lección depende de la diferencia entre esas versiones: cambian los números que ves, no los pasos ni los mensajes que aprendes a leer; donde un texto se midió con una versión concreta, se dice. En 1.7 aprendes a ver la tuya. Los programas están en [`programas/01-instalacion/`](../programas/01-instalacion), cada uno con su salida guardada al lado.

## Al terminar vas a poder

- Leer `/etc/os-release` y decir qué nombre en clave de Ubuntu le corresponde a tu Mint, y por qué ese y no el de Mint.
- Quitar los paquetes que chocan con Docker Engine y explicar por qué chocan.
- Agregar el repositorio oficial de Docker a `apt`, explicando para qué sirve cada renglón, incluida la llave.
- Instalar los cinco paquetes de Docker Engine y nombrar qué hace cada uno.
- Comprobar, con un guion de seis bloques, que el servicio corre y arrancará solo, qué versión tienes y que puedes crear un contenedor.
- Encontrar y quitar los restos que un tutorial anterior dejó en `apt`, antes de que te hagan fallar la instalación con un error que parece el de siempre.
- Leer el error `permission denied while trying to connect to the docker API` y arreglarlo metiendo a tu usuario en el grupo `docker`.
- Demostrar con un comando por qué el grupo `docker` equivale a `root`, y nombrar dos alternativas.

## El porqué antes del cómo

Instalar un programa en Linux suele ser una línea: `sudo apt install algo`. Con Docker se puede hacer así —tu Mint ofrece un paquete llamado `docker.io`— y la guía oficial de Docker te pide justo lo contrario: **quitarlo**. ¿Por qué tanta ceremonia?

Porque hay dos fuentes de paquetes de Docker y no son iguales. La primera es tu distribución: Ubuntu (y por lo tanto Mint) empaqueta Docker con sus propios nombres, a su propio ritmo, y con frecuencia en una versión que se queda atrás. La segunda es Docker, la empresa, que publica sus paquetes en su propio repositorio, `download.docker.com`, con cada versión que publica: la 29.9.2, del 20 de octubre de 2026, ya estaba ahí el día 21 (1.5.3 lo muestra). La guía oficial llama «no oficiales» a los primeros y te pide los segundos ([Docker, instalar en Ubuntu](https://docs.docker.com/engine/install/ubuntu/)). Este curso usa los oficiales por una razón práctica: todo lo que enseña —el *plugin* de Compose, el constructor Buildx, las versiones que se mencionan— está medido con ellos, y lo que leas en la documentación de Docker se refiere a ellos.

La segunda razón para la ceremonia es Mint mismo. Mint está hecho sobre Ubuntu, pero no es Ubuntu, y Docker no lo soporta oficialmente. Eso no significa que no funcione: significa que, en un punto exacto de la instalación, tienes que decirle a `apt` que se comporte como si fueras Ubuntu. Es un solo renglón, y es el que rompió el primer tutorial de la escena.

Y la tercera es la seguridad. Al terminar de instalar, el daemon corre como `root` y escucha en un *socket*. Quien pueda escribir en ese *socket* manda sobre el daemon, y quien manda sobre el daemon manda sobre tu equipo. Por eso la instalación termina con una decisión que tomas tú, sabiendo lo que decides: quién puede hablarle al daemon.

La lección va en el orden en que harías la instalación:

1. **Qué vas a instalar** (1.1).
2. **Mint no es Ubuntu: el nombre en clave** (1.2).
3. **Antes de instalar: el cortafuegos** (1.3).
4. **Quitar lo que choca** (1.4).
5. **El repositorio oficial**, con el error de Mint provocado y arreglado (1.5).
6. **Instalar los paquetes** (1.6) y **comprobar** (1.7).
7. **El grupo `docker`** (1.8) y **por qué equivale a `root`** (1.9).
8. **Actualizar y desinstalar** (1.10).

Con ese destino en mente, esto es lo que vas a ver al final de 1.7, cuando todo esté en su lugar (corrida real · máquina virtual):

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

## Los conceptos

### 1.1 Qué vas a instalar

#### 1.1.1 Las cinco piezas

La guía oficial instala cinco paquetes con un solo comando. Conviene saber qué es cada uno antes de instalarlos, porque cada uno corresponde a una pieza del mapa de la Lección 0:

| Paquete | Qué trae | En el mapa de la Lección 0 |
|---|---|---|
| `docker-ce` | el daemon, `dockerd` (*CE* es *Community Edition*, la edición gratuita y abierta) | el servidor que hace el trabajo |
| `docker-ce-cli` | el cliente, el comando `docker` que tecleas | el cliente |
| `containerd.io` | `containerd`, que administra los contenedores por debajo del daemon, y `runc`, que los crea | la cadena que termina en el `containerd-shim-runc-v2` que viste como padre de un contenedor |
| `docker-buildx-plugin` | Buildx, el constructor de imágenes | lo usarás cuando escribas tu primer Dockerfile |
| `docker-compose-plugin` | Compose, que levanta varios contenedores desde un archivo | el subcomando `docker compose` |

Los dos últimos son *plugins*: no son programas que llames por su nombre, sino subcomandos que se agregan al cliente. Por eso se escribe `docker compose`, con espacio, y no `docker-compose`, con guion. El de guion es el Compose viejo, un programa aparte, y su paquete está en la lista de los que hay que quitar (1.4).

Fíjate en el nombre `containerd.io`. Docker Engine necesita `containerd` y `runc`, y tu distribución también los ofrece con esos nombres. La guía oficial lo explica: Docker los empaqueta juntos en uno solo, `containerd.io`, y si instalaste antes los de tu distribución, hay que quitarlos para que no choquen ([Docker, instalar en Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

#### 1.1.2 Lo que no vas a instalar, y por qué

**Docker Desktop.** Es una aplicación de escritorio de Docker que existe también para Linux, y la guía la presenta como «la forma más fácil y rápida de empezar». El curso no la usa por una razón que ya conoces: según su propia documentación, «Docker Desktop en Linux corre una máquina virtual» ([Docker Desktop para Linux](https://docs.docker.com/desktop/setup/install/linux/)). Recuerda 0.2: el motivo para usar Linux como sistema de referencia es que los contenedores corren directo sobre tu núcleo, sin una capa en medio. Docker Desktop vuelve a poner esa capa. Si un día lo instalas, sabrás por qué `ps` en tu Mint no muestra los procesos de los contenedores: están dentro de otra máquina.

**El guion de conveniencia.** Docker publica en `get.docker.com` un guion que detecta tu distribución y lo instala todo de un jalón. La guía dice que «no se recomienda para ambientes de producción», que instala dependencias y recomendaciones sin preguntar, que no deja elegir casi nada y que no está hecho para actualizar una instalación existente ([Docker, guion de conveniencia](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)). Hay otra razón, más simple: en un curso, un guion que lo hace todo te quita justo lo que vienes a aprender. Si lo encuentras en un tutorial, ya sabes qué es.

**El modo *rootless*.** Es una forma de correr el daemon sin `root`. Lo verás en 1.9, como alternativa; el curso usa el modo normal, que es lo que instala la guía y lo que encontrarás en casi cualquier servidor.

### 1.2 Mint no es Ubuntu: el nombre en clave

#### 1.2.1 Qué dice Docker de Mint

La guía oficial para Ubuntu enumera las versiones que soporta: 26.10, 26.04, 24.04 y 22.04, todas de 64 bits. Y debajo trae esta nota: «la instalación en distribuciones derivadas de Ubuntu, como Linux Mint, no tiene soporte oficial (aunque puede funcionar)» ([Docker, instalar en Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

«Sin soporte oficial» tiene un significado preciso: Docker no prueba sus paquetes en Mint y no publica una carpeta para Mint en su repositorio. Lo que sí hay es una carpeta para cada versión de Ubuntu. Y Mint 22 está construido sobre los paquetes de Ubuntu 24.04. La propia página de descargas de Linux Mint lo dice en la columna «Package base»: Mint 22, 22.1, 22.2 y 22.3 tienen como base «Ubuntu Noble», con soporte hasta abril de 2029 ([Linux Mint, todas las versiones](https://www.linuxmint.com/download_all.php)). *Noble* es el nombre en clave de Ubuntu 24.04. Entonces el truco es este: en Mint 22 usas los paquetes de Docker **para Ubuntu Noble**, porque son los que corresponden a las bibliotecas que tiene tu sistema.

#### 1.2.2 El archivo que lo dice todo: `/etc/os-release`

Cada distribución de Linux describe quién es en un archivo de texto, `/etc/os-release`. Es un archivo de variables de *shell*: renglones con `NOMBRE=valor`, que cualquier guion puede cargar. `fig01_01.sh` lo lee y te dice qué nombre en clave te toca. No cambia nada en tu equipo; solo lee:

```bash
#!/usr/bin/env bash
# fig01_01.sh — ¿Qué sistema tengo y qué nombre en clave le toca en el
# repositorio de Docker? Solo lee archivos de configuración (os-release): no
# cambia nada en tu equipo.
# Uso: ./fig01_01.sh            (lee /etc/os-release, el de tu sistema)
#      ./fig01_01.sh ARCHIVO    (lee otro archivo con el mismo formato)
set -euo pipefail
ARCHIVO="${1:-/etc/os-release}"

# os-release es un archivo de variables de shell: «.» lo carga en este guion, y
# cargar es EJECUTAR: pásale solo archivos os-release (puras asignaciones).
. "$ARCHIVO"

echo "== Lo que dice $ARCHIVO"
echo "NAME=$NAME"
echo "VERSION=${VERSION:-}"
echo "ID=$ID  ID_LIKE=${ID_LIKE:-}"
echo "VERSION_CODENAME=${VERSION_CODENAME:-(vacío)}"
echo "UBUNTU_CODENAME=${UBUNTU_CODENAME:-(no existe)}"
echo "DEBIAN_CODENAME=${DEBIAN_CODENAME:-(no existe)}"

echo
echo "== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)"
echo "Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}"

echo
echo "== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)"
dpkg --print-architecture
```

Corrida real · Mint simulado:

```text
$ ./fig01_01.sh
== Lo que dice /etc/os-release
NAME=Linux Mint
VERSION=22.3 (Zena)
ID=linuxmint  ID_LIKE=ubuntu debian
VERSION_CODENAME=zena
UBUNTU_CODENAME=noble
DEBIAN_CODENAME=(no existe)

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: noble

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
amd64
```

En tu equipo, si tienes Mint 22, 22.1 o 22.2, `VERSION` y `VERSION_CODENAME` dirán `wilma`, `xia` o `zara`; todo lo demás sale igual. Antes de leer la salida, los renglones del guion que no son obvios. El punto solo (`. "$ARCHIVO"`) carga el archivo en el guion, igual que `source`: después de esa línea, `$NAME` o `$UBUNTU_CODENAME` tienen los valores del archivo. Y cargar quiere decir **ejecutar**: cualquier comando que hubiera en ese archivo correría ([manual de Bash, `source`](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html)). `/etc/os-release` son puras asignaciones y es inofensivo, pero como el guion acepta cualquier archivo como argumento, pásale solo archivos `os-release`. `${VERSION:-}` quiere decir «el valor de `VERSION`, o nada si no existe»; sin eso, `set -u` detendría el guion al encontrar una variable que no está. Y `dpkg --print-architecture` pregunta al gestor de paquetes para qué procesador está hecho tu sistema; como pregunta a tu sistema y no al archivo, si le pasas otro `os-release` como argumento, ese último bloque sigue mostrando la arquitectura de tu propio equipo.

Ahora la salida, que tiene la clave de toda la lección:

1. **Mint dice que es Mint.** `NAME=Linux Mint`, `ID=linuxmint`. Si un programa pregunta «¿eres Ubuntu?» mirando `ID`, la respuesta es no.
2. **Pero dice de quién desciende.** `ID_LIKE=ubuntu debian` significa «me parezco a Ubuntu, y Ubuntu se parece a Debian».
3. **Hay dos nombres en clave.** `VERSION_CODENAME=zena` es el de Mint 22.3. `UBUNTU_CODENAME=noble` es el de la versión de Ubuntu sobre la que está hecho. El segundo existe justo para casos como este. (`DEBIAN_CODENAME` no existe en Mint ni en Ubuntu; en 1.2.3 verás quién la trae.)
4. **La regla de la guía oficial elige el correcto.** La expresión `${UBUNTU_CODENAME:-$VERSION_CODENAME}` se lee «usa `UBUNTU_CODENAME` si existe; si no, `VERSION_CODENAME`». En Mint existe, y sale `noble`. En un Ubuntu de verdad, las dos variables valen lo mismo, así que da igual cuál se use. Esa expresión es, letra por letra, la que trae la guía oficial en el renglón `Suites` del repositorio (1.5).
5. **La arquitectura es `amd64`**, la de los procesadores Intel y AMD de 64 bits, que es la de casi cualquier computadora con Mint. Es el valor que va en el campo `Architectures` del repositorio.

Para que veas la otra cara, este es el mismo guion en la máquina virtual de las corridas, que es un Ubuntu de verdad (corrida real · máquina virtual; está en `fig01_01.salida-ubuntu.txt`):

```text
$ ./fig01_01.sh
== Lo que dice /etc/os-release
NAME=Ubuntu
VERSION=24.04.4 LTS (Noble Numbat)
ID=ubuntu  ID_LIKE=debian
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
DEBIAN_CODENAME=(no existe)

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: noble

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
arm64
```

En Ubuntu, los dos nombres en clave coinciden. En Mint, no. Toda la diferencia de instalar en Mint cabe en esas dos líneas.

#### 1.2.3 ¿Y si tienes LMDE?

Linux Mint tiene una segunda edición, **LMDE** (*Linux Mint Debian Edition*), que no está hecha sobre Ubuntu sino sobre Debian. La página de descargas de Mint lista LMDE 7, «Gigi», con base «Debian Trixie» ([Linux Mint, todas las versiones](https://www.linuxmint.com/download_all.php)). Si tu equipo tiene LMDE, esta lección te sirve en todo menos en el repositorio: tienes que seguir la [guía oficial para Debian](https://docs.docker.com/engine/install/debian/), que usa `https://download.docker.com/linux/debian` (también para la llave: `…/linux/debian/gpg`).

En su renglón `Suites`, la guía de Debian usa `$VERSION_CODENAME`, que en LMDE 7 vale `gigi`, un nombre que Docker no tiene: es el mismo error de 1.5.2 en versión Debian. La guía solo dice que en una distribución derivada puede que tengas que sustituir el nombre en clave por el de la versión de Debian que le corresponde. No hace falta escribirlo a mano: LMDE trae en su `/etc/os-release` una variable hecha para esto, `DEBIAN_CODENAME`, igual que Mint trae `UBUNTU_CODENAME`. Así lo dice el `os-release` del paquete oficial `base-files` de LMDE 7 (versión `13.8+lmde1`, del [repositorio de Linux Mint](http://packages.linuxmint.com/); la copia está en `programas/01-instalacion/os-release-lmde-7.txt`). El renglón queda así:

```text
Suites: $(. /etc/os-release && echo "${DEBIAN_CODENAME:-$VERSION_CODENAME}")
```

Es un fragmento, no un programa: va en el lugar del renglón `Suites` del bloque de la guía de Debian. Para saber cuál edición tienes, `fig01_01.sh` te lo dice: `ID` vale `linuxmint` en las dos, pero en LMDE `NAME=LMDE`, `ID_LIKE=debian`, sin `ubuntu`, y aparece `DEBIAN_CODENAME`.

> [!WARNING]
> Si tienes LMDE, **no corras `fig01_03.sh` ni `fig01_04.sh`**: los dos apuntan al repositorio de Ubuntu, y `fig01_04.sh` escribiría `Suites: gigi` contra él y te dejaría `apt update` fallando. Sigue la guía de Debian (incluida su propia lista de paquetes en conflicto) con el renglón `Suites` de arriba, y retoma la lección en 1.7. En las comprobaciones, donde diga `noble`, tú verás `trixie`, y en las versiones de los paquetes, `debian.13~trixie`.

> [!NOTE]
> 🔧 **Observación de ingeniería 1.1**
> «Sin soporte oficial» no es «no funciona», ni tampoco «funciona igual». Es «nadie más que tú va a comprobar que funcione». Cuando uses algo fuera de lo que el proveedor soporta, apunta exactamente qué hiciste distinto (aquí: un nombre en clave) para que, si algo falla, sepas por dónde empezar.

### 1.3 Antes de instalar: el cortafuegos

La guía oficial abre con una advertencia de seguridad, antes de cualquier comando, y conviene leerla antes de instalar y no el día que te muerde: si usas **ufw** o **firewalld** para administrar tu cortafuegos, «cuando expones los puertos de un contenedor con Docker, esos puertos se saltan las reglas de tu cortafuegos» ([Docker, instalar en Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

*ufw* (*Uncomplicated Firewall*) es la herramienta de cortafuegos que trae Ubuntu, y que puedes tener activa en tu Mint. La página de Docker sobre cortafuegos explica el mecanismo: cuando publicas un puerto de un contenedor, el tráfico se desvía en la tabla `nat` del núcleo, **antes** de llegar a las cadenas `INPUT` y `OUTPUT` que usa ufw; los paquetes se enrutan antes de que las reglas del cortafuegos se puedan aplicar, «ignorando en la práctica tu configuración» ([Docker, filtrado de paquetes y cortafuegos](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw)).

Qué significa en la práctica: si tienes `ufw deny 8080` y corres un contenedor que publica el puerto 8080 en todas las interfaces, ese puerto queda abierto a tu red. ufw no se entera. Por eso en este curso, cuando publiques puertos, se publican solo en `127.0.0.1`, la dirección que solo tu propio equipo puede alcanzar: no depende del cortafuegos para estar cerrado, porque nunca se abre a la red. Está previsto que la Lección 2 lo muestre con un puerto abierto a propósito.

La misma advertencia trae un segundo punto, más técnico: Docker solo es compatible con `iptables-nft` e `iptables-legacy`, y las reglas de cortafuegos escritas directamente con `nft` no tienen soporte en un sistema con Docker. Si administras reglas a mano, se escriben con `iptables` o `ip6tables` y se ponen en la cadena `DOCKER-USER`. Si no sabes de qué habla este párrafo, lo más probable es que no te afecte: es para quien ya tiene un cortafuegos escrito a mano.

### 1.4 Quitar lo que choca

#### 1.4.1 Los paquetes en conflicto

Antes de instalar los paquetes oficiales hay que quitar los no oficiales, porque los dos juegos traen archivos con los mismos nombres (el comando `docker`, el daemon, `containerd`) y `apt` no puede tener los dos a la vez. La guía da la lista exacta ([Docker, instalar en Ubuntu](https://docs.docker.com/engine/install/ubuntu/)):

| Paquete | Qué es |
|---|---|
| `docker.io` | el Docker que empaqueta Ubuntu |
| `docker-compose` | el Compose viejo, el programa con guion |
| `docker-compose-v2` | el Compose nuevo, empaquetado por Ubuntu |
| `docker-doc` | la documentación del paquete de Ubuntu |
| `docker-buildx` | Buildx, empaquetado por Ubuntu |
| `podman-docker` | un imitador: hace que el comando `docker` llame a Podman, otra herramienta de contenedores |
| `containerd`, `runc` | las versiones de Ubuntu de lo que `containerd.io` trae junto |

Si nunca instalaste nada de Docker, lo más probable es que no tengas ninguno. La guía lo advierte: «`apt` puede reportar que no tienes ninguno de estos paquetes instalados».

#### 1.4.2 El comando, pieza por pieza

`fig01_02.sh` primero pregunta cuáles tienes y después corre el comando de la guía, copiado tal cual:

```bash
#!/usr/bin/env bash
# fig01_02.sh — Quitar los paquetes que chocan con los oficiales de Docker.
# El segundo comando es, letra por letra, el de la guía oficial de Ubuntu.
set -uo pipefail
PAQUETES="docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc"

echo "== ¿Cuáles de los paquetes en conflicto tienes instalados?"
dpkg --get-selections $PAQUETES

echo
echo "== El comando de la guía oficial (quita los que encontró)"
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc | cut -f1)
echo "código de salida: $?"
```

Corrida real · Mint simulado (el sistema recién instalado, sin nada de Docker):

```text
$ ./fig01_02.sh
== ¿Cuáles de los paquetes en conflicto tienes instalados?
dpkg: no packages found matching docker.io
dpkg: no packages found matching docker-compose
dpkg: no packages found matching docker-compose-v2
dpkg: no packages found matching docker-doc
dpkg: no packages found matching docker-buildx
dpkg: no packages found matching podman-docker
dpkg: no packages found matching containerd
dpkg: no packages found matching runc

== El comando de la guía oficial (quita los que encontró)
dpkg: no packages found matching docker.io
…
dpkg: no packages found matching runc

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Reading package lists...
Building dependency tree...
Reading state information...
0 upgraded, 0 newly installed, 0 to remove and 3 not upgraded.
código de salida: 0
```

El `…` sustituye seis renglones idénticos a los de arriba; la salida completa está en `fig01_02.salida.txt`. El número de paquetes por actualizar (`3 not upgraded`) depende de tu equipo.

El comando de la guía se lee de dentro hacia fuera:

1. `dpkg --get-selections <paquetes>` pregunta a `dpkg`, el gestor de paquetes de bajo nivel, por cada paquete de la lista. Por los que están instalados escribe un renglón con el nombre, un tabulador y la palabra `install`. Por los que no, se queja en la salida de errores: `no packages found matching …`. Esas quejas no son un problema; son la respuesta «no lo tienes».
2. `| cut -f1` se queda con la primera columna de cada renglón, es decir, solo los nombres.
3. `$( … )` pone esos nombres en la línea de comandos de `sudo apt remove`.

Así, `apt remove` recibe solo los paquetes que **sí** tienes. Si no tienes ninguno, recibe una lista vacía y dice `0 to remove`. Si tuvieras, por ejemplo, `docker.io`, te mostraría qué va a quitar y te preguntaría si continúas: lee la lista antes de contestar que sí.

El aviso `WARNING: apt does not have a stable CLI interface` sale porque, en esa corrida, la salida de `apt` no iba a una terminal sino a un archivo: así se guardaron las salidas del curso. `apt` es la herramienta para personas, y avisa que su formato puede cambiar cuando lo que lee su salida es otro programa. Si corres el guion en tu terminal no lo verás, y en cambio verás `Done` al final de `Reading package lists...` y barras de progreso. Para guiones existe `apt-get`, que es estable; en 1.5.3 lo usamos.

#### 1.4.3 Lo que `apt remove` no quita

La guía advierte algo que importa si alguna vez tuviste Docker: las imágenes, contenedores, volúmenes y redes que viven en `/var/lib/docker/` **no se borran** al desinstalar. Desinstalar el paquete quita los programas; los datos se quedan. Si quieres empezar de cero de verdad, 1.10 dice cómo. Si no, los nuevos paquetes encontrarán esos datos y los usarán.

#### 1.4.4 Lo que un tutorial anterior pudo dejar

Quitar los paquetes no quita lo que otro tutorial escribió en `apt`. La escena del principio describe a alguien que ya probó cinco comandos de otra guía; si te pasó algo parecido, es probable que tengas un `docker.list` con el nombre de Mint (`zena`), una llave en `/usr/share/keyrings/` o `/etc/apt/keyrings/`, o una llave en el llavero viejo de `apt-key`. `apt` lee **todos** los archivos de `/etc/apt/sources.list.d/`, y un `docker.list` viejo sigue pidiendo `zena` aunque en 1.5.3 escribas bien `docker.sources`: el síntoma es el mismo error de 1.5.2, con la causa equivocada, y concluyes que «el arreglo no funcionó» ([sources.list(5)](https://manpages.debian.org/trixie/apt/sources.list.5.en.html); la desinstalación oficial borra la fuente y la llave como un paso aparte).

`fig01_08.sh` busca esos restos. Solo lee, así que corre sin miedo en cualquier equipo:

```bash
#!/usr/bin/env bash
# fig01_08.sh — ¿Te dejó otro tutorial restos de Docker en apt?
# Solo lee: no cambia nada en tu equipo. Córrelo ANTES de fig01_03.sh.
set -uo pipefail

echo "== 1. Archivos de apt que apuntan a download.docker.com"
grep -rl download.docker.com /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null \
  || echo "(ninguno)"

echo
echo "== 2. Llaves de Docker sueltas en las carpetas de llaves"
ls -l /etc/apt/keyrings/ /usr/share/keyrings/ 2>/dev/null | grep -i docker \
  || echo "(ninguna)"

echo
echo "== 3. Llaves de Docker en el llavero viejo (apt-key)"
apt-key list 2>/dev/null | grep -i -B1 -A1 docker \
  || echo "(ninguna)"
```

Si no tocaste Docker antes, la salida es esta (corrida real · Mint simulado; está en `fig01_08.salida-limpio.txt`):

```text
$ ./fig01_08.sh
== 1. Archivos de apt que apuntan a download.docker.com
(ninguno)

== 2. Llaves de Docker sueltas en las carpetas de llaves
(ninguna)

== 3. Llaves de Docker en el llavero viejo (apt-key)
(ninguna)
```

Para ver el caso contrario se preparó, a mano, el equipo de alguien que siguió un tutorial viejo: una llave en `/usr/share/keyrings/docker-archive-keyring.gpg`, la misma llave agregada con `apt-key add` y un `docker.list` de un renglón con `zena`. Es un escenario armado, no un equipo real, y la salida es esta (corrida real · Mint simulado; está en `fig01_08.salida.txt`; la fecha de la llave cambia):

```text
$ ./fig01_08.sh
== 1. Archivos de apt que apuntan a download.docker.com
/etc/apt/sources.list.d/docker.list

== 2. Llaves de Docker sueltas en las carpetas de llaves
-rw-r--r-- 1 root root 2760 Oct 21 15:05 docker-archive-keyring.gpg

== 3. Llaves de Docker en el llavero viejo (apt-key)
      9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid           [ unknown] Docker Release (CE deb) <docker@docker.com>
sub   rsa4096 2017-02-22 [S]
```

Se lee así: el bloque 1 enseña qué archivos apuntan a Docker (aquí, el `docker.list` viejo); el 2, las llaves que quedaron sueltas; el 3, la que se agregó al llavero común. Con ese equipo se escribió después el `docker.sources` bueno de 1.5.3 (`Suites: noble`) **sin** borrar el `docker.list`, y se corrió `apt-get update`. Lo que pasó depende de qué decía el `docker.list` (está todo en `fig01_08.efectos-esperado.txt`):

| El `docker.list` viejo decía | Qué pasó con `apt update` |
|---|---|
| `zena` | el mismo error de 1.5.2: `E: The repository '… zena Release' does not have a Release file.`, código 100, aunque el `docker.sources` ya estaba bien |
| `noble`, con **otra** llave | un error distinto: `E: Conflicting values set for option Signed-By regarding source …/ubuntu/ noble`, y `E: The list of sources could not be read.` |
| `noble`, con la **misma** llave | no falla, pero avisa: `W: Target Packages … is configured multiple times in …/docker.list:1 and …/docker.sources:1` |

Con el `docker.list` borrado (`sudo rm /etc/apt/sources.list.d/docker.list`), `apt update` volvió a salir limpio (`Hit … noble InRelease`, código 0). Entonces: si `fig01_08.sh` muestra un `docker.list` u otro archivo que apunte a `download.docker.com`, bórralo con `sudo rm` antes de seguir. Las llaves viejas (`docker.gpg`, `docker-archive-keyring.gpg`) estorban menos, pero bórralas también, para que la única llave de Docker en tu equipo sea la de 1.5.1. Si el tutorial usó `apt-key add`, `sudo apt-key list` te la mostró en el bloque 3; se quita con `sudo apt-key del` y los últimos ocho caracteres de su huella (aquí, `0EBF CD88`). Ojo: el manual marca también `list` como en desuso y `del` como «casi» en desuso (solo hace excepción de `del` en los guiones de mantenimiento de paquetes). Aquí no se usan para agregar nada, solo para limpiar a mano lo que otro dejó, y no hay otra forma de hacerlo con el llavero común.


### 1.5 El repositorio oficial

#### 1.5.1 Qué es un repositorio de `apt`

`apt` no descarga programas de cualquier lugar: los descarga de una lista de **repositorios**, servidores que publican paquetes con un índice firmado. Tu Mint ya trae los de Ubuntu y los de Mint. Agregar el de Docker son dos cosas:

- **La llave.** Docker firma su índice con una llave criptográfica. `apt` necesita la parte pública de esa llave para comprobar que lo que descarga viene de Docker y nadie lo cambió en el camino.
- **La fuente.** Un archivo en `/etc/apt/sources.list.d/` que le dice a `apt` dónde está el repositorio, qué parte de él te corresponde y con qué llave se comprueba.

Esta es la parte de la guía oficial, completa (de la documentación). **No la teclees todavía**: en esta lección la vas a ejecutar en dos tiempos. `fig01_03.sh` hace la parte de la llave igual que la guía y escribe la fuente con el error de Mint; `fig01_04.sh` reescribe la fuente bien. Si prefieres no provocar el error en tu equipo, teclea este bloque tal cual y salta la sección 1.5.2. En 1.5.3 puedes correr `fig01_04.sh` de todos modos: escribe el mismo archivo que acabas de escribir y te muestra de dónde saldría `docker-ce`, que es lo que vuelve a usar el Ejercicio 3:

```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

Renglón por renglón:

- `sudo apt update` refresca los índices de los repositorios que ya tienes, para que el siguiente `apt install` encuentre las versiones al día.
- `ca-certificates` trae los certificados de las autoridades que firman los sitios HTTPS, y `curl` descarga archivos. En un Mint de escritorio casi seguro ya los tienes; pedirlos no hace daño.
- `install -m 0755 -d /etc/apt/keyrings` crea la carpeta donde viven las llaves de repositorios externos, con permisos `0755`: el dueño (`root`) escribe, todos leen.
- `curl -fsSL … -o /etc/apt/keyrings/docker.asc` descarga la llave pública de Docker. `-f` hace que falle si el servidor responde con error, en vez de guardar una página de error como si fuera la llave; `-s` y `-S` lo callan salvo en los errores; `-L` sigue redirecciones.
- `chmod a+r` hace que todos puedan leer la llave, porque `apt` la lee con un usuario sin privilegios.
- `sudo tee … <<EOF` escribe el archivo de la fuente. Se usa `tee` con `sudo` porque una redirección `>` la hace tu *shell*, que no es `root`, y no podría escribir en `/etc`. Lo que va entre `<<EOF` y `EOF` es el contenido, y las `$( … )` se sustituyen **antes** de escribirlo.

El archivo `docker.sources` está en el formato **deb822**: un campo por renglón, con nombre. El manual de `apt` lo describe junto al formato viejo, de un solo renglón (`deb [opciones] url versión componente`), y dice que la intención es que deb822 sea poco a poco el formato por omisión ([sources.list(5)](https://manpages.debian.org/trixie/apt/sources.list.5.en.html)). Vas a ver tutoriales con un archivo `docker.list` de un renglón: es la forma anterior, que el mismo manual marca en desuso («this format is deprecated and may eventually be removed, but not before 2029»). Funciona; lo nuevo se escribe en deb822. Los campos:

| Campo | Valor | Qué significa |
|---|---|---|
| `Types` | `deb` | paquetes ya compilados (no código fuente) |
| `URIs` | `https://download.docker.com/linux/ubuntu` | dónde está el repositorio; nota el `ubuntu` al final |
| `Suites` | el nombre en clave | la versión de Ubuntu cuyos paquetes quieres; **aquí está el asunto de Mint** |
| `Components` | `stable` | solo versiones estables, no de prueba |
| `Architectures` | `amd64` en tu Mint | para qué procesador |
| `Signed-By` | `/etc/apt/keyrings/docker.asc` | con qué llave se comprueba **este** repositorio, y solo este |

Ese último campo merece una línea más. Antes, las llaves de repositorios externos se agregaban con `apt-key` a un llavero común, y una llave servía para comprobar **cualquier** repositorio: la de Docker podría haber firmado un paquete que dijera venir de Ubuntu. `apt-key` está en desuso: el manual de la versión de `apt` de Ubuntu 24.04, la base de Mint 22, dice que estará disponible por última vez en Debian 12 y Ubuntu 24.04 ([apt-key(8), Ubuntu noble](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html)). Tu Mint 22 todavía lo trae, y por eso un tutorial viejo con `apt-key add` parece funcionar: funciona, pero deja la llave de Docker valiendo para todos tus repositorios. Con `Signed-By`, la llave de Docker solo vale para el repositorio de Docker. Si un tutorial te dice `apt-key add`, es de antes de que se adoptara `Signed-By`, y no lo sigas.

#### 1.5.2 El error de Mint, provocado

Ahora el error de la escena, a propósito. `fig01_03.sh` es el mismo paso de la guía con **una sola diferencia que importa**: en `Suites` usa `VERSION_CODENAME` en vez de `${UBUNTU_CODENAME:-$VERSION_CODENAME}` (además lleva `-y` en `apt install`, para no preguntar). Así lo escriben muchas guías viejas para Ubuntu, con `$VERSION_CODENAME` o con `$(lsb_release -cs)`, que en Mint también contesta el nombre de Mint (lo saca de `DISTRIB_CODENAME` en `/etc/lsb-release`); y así lo escribe la guía oficial **para Debian**, que no tiene el problema porque Debian no tiene `UBUNTU_CODENAME` ([Docker, instalar en Debian](https://docs.docker.com/engine/install/debian/)). Quien copia de la guía equivocada, en Mint, cae aquí.

```bash
#!/usr/bin/env bash
# fig01_03.sh — EL ERROR DE MINT, provocado a propósito.
# Es el paso 1 de la guía oficial con UNA diferencia que importa: «Suites» sale de
# VERSION_CODENAME (el nombre en clave de Mint) en vez de UBUNTU_CODENAME.
# (Además lleva -y en «apt install», para no preguntar.)
# Así lo escriben muchas guías viejas y la guía oficial de Debian.
set -uo pipefail

# Igual que la guía oficial: la llave con la que apt comprueba los paquetes.
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# La diferencia está en la línea Suites.
sudo tee /etc/apt/sources.list.d/docker.sources <<FIN
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
FIN

echo
echo "== apt update con ese repositorio"
sudo apt update
echo "código de salida: $?"
```

Corrida real · Mint simulado. Es la salida desde el renglón que escribe `tee` hasta el final; antes van los de `apt update` y la instalación de `curl`, que están completos en `fig01_03.error-esperado.txt`:

```text
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: zena
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc

== apt update con ese repositorio

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Ign:1 https://download.docker.com/linux/ubuntu zena InRelease
Err:2 https://download.docker.com/linux/ubuntu zena Release
  404  Not Found [IP: 3.161.44.57 443]
Hit:3 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:4 http://archive.ubuntu.com/ubuntu noble InRelease
Hit:5 http://archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:6 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Reading package lists...
E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.
código de salida: 100
```

La dirección IP entre corchetes es la del servidor de Docker que contestó y cambia de una corrida a otra. Los renglones `Hit:` son los repositorios de Ubuntu, que sí responden; el orden en que aparecen puede variar. Lo demás es estable, salvo el nombre en clave si tu Mint no es el 22.3. En tu terminal verás además renglones `Hit:` de los repositorios de Mint.

Se lee de arriba abajo:

1. `tee` muestra lo que escribió, y ahí está el problema a la vista: `Suites: zena`.
2. `apt update` le pide al servidor de Docker el índice de la versión `zena` de Ubuntu. Primero busca `InRelease` (el índice con la firma adentro) y lo ignora (`Ign`) porque no está; después busca `Release` y el servidor contesta **404**, «no encontrado».
3. El error final lo dice en palabras: el repositorio `… zena Release` no tiene un archivo `Release`. Traducido: **no existe una versión de Ubuntu llamada `zena`**. Y es cierto: `zena` es Mint.
4. `apt` sale con código 100, su código de error general.

Un detalle que engaña: la llave sí se descargó bien y el servidor sí respondió. No es un problema de red, ni de permisos, ni de la llave. Es un nombre mal puesto en un archivo de texto.

#### 1.5.3 El arreglo

Se arregla reescribiendo la fuente con la línea de la guía oficial. `fig01_04.sh` lo hace (no vuelve a descargar la llave: usa la que dejó `fig01_03.sh` en `/etc/apt/keyrings/docker.asc`; sin ella, `apt update` fallaría por la llave que no está), refresca los índices y, en vez de instalar, pregunta: ¿de dónde saldría `docker-ce` y en qué versión?

```bash
#!/usr/bin/env bash
# fig01_04.sh — El arreglo: el repositorio de Docker con el nombre en clave de
# Ubuntu, como lo escribe la guía oficial. Después pregunta qué versión se
# instalaría y SIMULA la instalación (apt-get -s no instala nada).
set -euo pipefail

# Letra por letra, la línea Suites de la guía oficial de Ubuntu:
# UBUNTU_CODENAME si existe (Mint, Ubuntu) y, si no, VERSION_CODENAME.
sudo tee /etc/apt/sources.list.d/docker.sources <<FIN
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
FIN

echo
echo "== apt update"
sudo apt update

echo
echo "== ¿De dónde saldría docker-ce, y en qué versión?"
apt-cache policy docker-ce | sed -n 1,6p

echo
echo "== Las versiones más recientes que ofrece el repositorio"
apt list --all-versions docker-ce 2>/dev/null | grep docker-ce | sed -n 1,3p

echo
echo "== Simulación: los paquetes de Docker que instalaría el comando de la guía"
SIMULACION=$(apt-get install -s docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
echo "$SIMULACION" | grep -E '^Inst (docker-|containerd)' | cut -d' ' -f2,3 | tr -d '('
echo "paquetes en total, contando dependencias: $(echo "$SIMULACION" | grep -c '^Inst')"
```

Corrida real · Mint simulado:

```text
$ ./fig01_04.sh
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc

== apt update

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Hit:2 https://download.docker.com/linux/ubuntu noble InRelease
Hit:3 http://archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:4 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:5 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Reading package lists...
Building dependency tree...
Reading state information...
3 packages can be upgraded. Run 'apt list --upgradable' to see them.

== ¿De dónde saldría docker-ce, y en qué versión?
docker-ce:
  Installed: (none)
  Candidate: 5:29.9.2-1~ubuntu.24.04~noble
  Version table:
     5:29.9.2-1~ubuntu.24.04~noble 500
        500 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages

== Las versiones más recientes que ofrece el repositorio
docker-ce/noble 5:29.9.2-1~ubuntu.24.04~noble amd64
docker-ce/noble 5:29.9.1-1~ubuntu.24.04~noble amd64
docker-ce/noble 5:29.9.0-1~ubuntu.24.04~noble amd64

== Simulación: los paquetes de Docker que instalaría el comando de la guía
containerd.io 2.4.2-3~ubuntu.24.04~noble
docker-ce-cli 5:29.9.2-1~ubuntu.24.04~noble
docker-ce 5:29.9.2-1~ubuntu.24.04~noble
docker-buildx-plugin 0.38.1-1~ubuntu.24.04~noble
docker-ce-rootless-extras 5:29.9.2-1~ubuntu.24.04~noble
docker-compose-plugin 5.6.0-1~ubuntu.24.04~noble
paquetes en total, contando dependencias: 96
```

Cambian en tu equipo: las versiones (las de este bloque son las del 21 de octubre de 2026), el número de paquetes por actualizar y, sobre todo, el total de la última línea. El contenedor de la simulación es un Ubuntu mínimo, casi vacío, y le faltan decenas de piezas que tu Mint de escritorio ya tiene (`systemd`, `perl`, `git`…); en tu equipo el total será mucho menor. Y estos renglones de `apt update` son de la **segunda** vez que corrió el guion, con los índices ya descargados (`Hit`). La primera vez, los renglones de Docker no salen como `Hit` sino como `Get`, porque los índices se descargan por primera vez: primero el índice `InRelease` de `noble` y después la lista de paquetes de `noble/stable` para tu arquitectura (un ejemplo real está en `fig01_08.efectos-esperado.txt`).

Lo que dice la salida:

1. **`Suites: noble`**. La misma Mint, ahora con el nombre de Ubuntu.
2. **`apt update` ya no se queja**, y entre los repositorios aparece `https://download.docker.com/linux/ubuntu noble`.
3. **`apt-cache policy`** contesta la pregunta «si instalo `docker-ce`, ¿qué versión y de dónde?». `Installed: (none)`: no lo tienes. `Candidate`: la versión que se instalaría. Y en la tabla, el origen: `download.docker.com`, `noble/stable`. Si en lugar de eso vieras un origen de `archive.ubuntu.com`, algo salió mal: no existe un `docker-ce` en Ubuntu, pero sí un `docker.io`, y por eso conviene revisar de dónde sale cada cosa antes de instalar.
4. **El número de versión** se lee así: `5:` es la «época», un contador que solo sirve para que `apt` ordene bien las versiones; `29.9.2` es la versión de Docker; `-1~ubuntu.24.04~noble` dice para qué distribución se empaquetó.
5. **La simulación** muestra seis paquetes de Docker, no cinco. El sexto, `docker-ce-rootless-extras`, no lo pediste: lo trae `apt` como *recomendación* de `docker-ce`. Son las herramientas del modo *rootless* (1.9); no estorban.

`apt-get install -s` (de *simulate*) calcula todo lo que haría una instalación y lo imprime en renglones `Inst`, sin tocar nada. Es una buena costumbre antes de cualquier instalación grande: ver qué va a entrar.

### 1.6 Instalar los paquetes

Con el repositorio en su lugar, la instalación es un solo comando (de la documentación):

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

`apt` te mostrará la lista de paquetes, cuánto va a descargar y cuánto espacio usará, y te preguntará si continúas. La salida de este comando **no se pega aquí** porque no se corrió en un Mint de verdad, y en tu equipo depende de lo que ya tengas instalado. Lo que debes buscar en ella: que entre los paquetes nuevos estén los seis de la simulación de arriba, y que al final no haya renglones que empiecen con `E:`.

**Fijar una versión.** El comando de arriba instala la más reciente. Si necesitas una versión exacta —para que tu equipo coincida con un servidor, por ejemplo—, la guía da la receta (de la documentación):

```bash
apt list --all-versions docker-ce
VERSION_STRING=5:29.8.2-1~ubuntu.24.04~noble
sudo apt install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
```

El primer comando lista las versiones disponibles, como hizo `fig01_04.sh`. El segundo guarda en una variable la que quieres, con su número completo, época incluida. El tercero instala `docker-ce` y `docker-ce-cli` en esa versión exacta: `paquete=versión` es la forma de `apt` de pedir una versión precisa. La 29.8.2 del ejemplo es justo la versión con la que se planeó este curso; no hace falta que la fijes para seguirlo.

**Ojo: pedir una versión no la congela.** `paquete=versión` solo manda en esa instalación. El día que corras `sudo apt upgrade`, `apt` verá que el repositorio tiene una versión más nueva de `docker-ce` y la instalará. Si de verdad quieres que no cambie, márcala como retenida (*hold*) y suéltala cuando decidas actualizar (la guía de Docker no lo dice; es del manual de [`apt-mark`](https://manpages.ubuntu.com/manpages/noble/man8/apt-mark.8.html)):

```bash
sudo apt-mark hold docker-ce docker-ce-cli
sudo apt-mark unhold docker-ce docker-ce-cli
```

**Lo que hace la instalación además de copiar archivos.** En Debian y Ubuntu, el servicio de Docker se configura para arrancar solo, ahora y cada vez que enciendas el equipo: los pasos posteriores a la instalación lo dicen, «en Debian y Ubuntu, el servicio de Docker arranca al iniciar el sistema por omisión» ([Docker, pasos posteriores](https://docs.docker.com/engine/install/linux-postinstall/)). Y se crea el grupo `docker`, vacío. Las dos cosas las compruebas en 1.7 y en 1.8.

### 1.7 Comprobar

#### 1.7.1 Lo que pide la guía

La guía oficial verifica con `sudo docker run hello-world`; `sudo systemctl status docker` va en una nota, justo después del comando de instalación, con `sudo systemctl start docker` por si no corre. Las dos juntas (de la documentación):

```bash
sudo systemctl status docker
sudo docker run hello-world
```

`systemctl status docker` pregunta a *systemd*, el programa que arranca y vigila los servicios del sistema, cómo está el servicio `docker`. Si no estuviera corriendo, la guía dice que lo arranques con `sudo systemctl start docker`. Y `sudo docker run hello-world` crea tu primer contenedor. Nota el `sudo` en los dos: recién instalado, tu usuario todavía no puede hablarle al daemon. Eso se arregla en 1.8, y por eso las comprobaciones de este curso se hacen sin `sudo`, después.

#### 1.7.2 Las comprobaciones del curso

`fig01_05.sh` junta todo lo que quieres saber de una instalación recién hecha. Córrelo **después** de 1.8, sin `sudo`:

```bash
#!/usr/bin/env bash
# fig01_05.sh — Las comprobaciones al terminar la instalación.
# Córrelo SIN sudo, después de entrar al grupo docker (sección 1.8).
set -uo pipefail

echo "== 1. El servicio: ¿corre ahora y arrancará con el equipo?"
systemctl is-active docker
systemctl is-enabled docker

echo
echo "== 2. Los cinco paquetes instalados"
dpkg-query -W -f='${Package} ${Version}\n' \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo
echo "== 3. Versiones"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}  API: {{.Server.APIVersion}}'
docker compose version
docker buildx version | cut -d' ' -f1,2

echo
echo "== 4. El primer contenedor"
docker run --rm --name curso-docker-hola hello-world

echo
echo "== 5. El socket: dueño root, grupo docker"
ls -l /var/run/docker.sock | awk '{print $1, $3, $4, $NF}'

echo
echo "== 6. Basura: contenedores curso-docker- que quedaron"
docker ps -a --filter name=curso-docker- --format '{{.Names}}' | wc -l
```

Corrida real · máquina virtual:

```text
$ ./fig01_05.sh
== 1. El servicio: ¿corre ahora y arrancará con el equipo?
active
enabled

== 2. Los cinco paquetes instalados
containerd.io 2.2.1-1~ubuntu.24.04~noble
docker-buildx-plugin 0.31.1-1~ubuntu.24.04~noble
docker-ce 5:29.2.1-1~ubuntu.24.04~noble
docker-ce-cli 5:29.2.1-1~ubuntu.24.04~noble
docker-compose-plugin 5.0.2-1~ubuntu.24.04~noble

== 3. Versiones
Cliente: 29.2.1  Daemon: 29.2.1  API: 1.53
Docker Compose version v5.0.2
github.com/docker/buildx v0.31.1

== 4. El primer contenedor
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
58dee6a49ef1: Pulling fs layer
c3bdf82c34d1: Download complete
58dee6a49ef1: Download complete
58dee6a49ef1: Pull complete
Digest: sha256:11a3eb1597e864c51b3f56733cb2e8a90bf0c284bfc05f9444d81c558bc848aa
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/


== 5. El socket: dueño root, grupo docker
srw-rw---- root docker /var/run/docker.sock

== 6. Basura: contenedores curso-docker- que quedaron
0
```

Qué cambia en tu equipo: las versiones (si instalaste el 21 de octubre de 2026, verías 29.9.2, Compose v5.6.0 y Buildx v0.38.1), los identificadores de capa y el *digest* de la imagen, y `(arm64v8)`, que en tu equipo dirá `(amd64)`. Si ya habías corrido `hello-world` antes, no verás el bloque de descarga: la imagen ya está en tu equipo.

Bloque por bloque:

1. **`active` y `enabled`.** `is-active` contesta si el servicio corre **ahora**; `is-enabled`, si arrancará **solo** la próxima vez que enciendas el equipo. Son preguntas distintas y conviene hacer las dos: un servicio puede estar corriendo porque lo arrancaste a mano y no volver después de reiniciar.
2. **Los cinco paquetes**, cada uno con su versión y el sufijo `ubuntu.24.04~noble`, que dice que vienen del repositorio oficial para Noble. `dpkg-query -W` pregunta por paquetes instalados con el formato que le pidas.
3. **Las versiones.** `docker version` reporta dos, la del cliente y la del daemon, porque son dos programas (Lección 0, sección 0.6). `API: 1.53` es la versión del idioma en que se hablan. `docker compose version` y `docker buildx version` confirman que los dos *plugins* están en su lugar: si `docker compose` contestara `docker: unknown command: docker compose`, faltaría `docker-compose-plugin` (así responde el cliente a un subcomando que no conoce; medido con el cliente 29.8.2 de la Mac de las corridas, `docker noexiste` imprime `docker: unknown command: docker noexiste`, y está en `fig01_05.unknown-command.txt`).
4. **El primer contenedor.** El daemon no encontró la imagen `hello-world` en tu equipo (`Unable to find image … locally`), la descargó de Docker Hub, creó un contenedor, lo corrió y, como pediste `--rm`, lo borró al terminar. El texto que imprime el contenedor describe, en cuatro pasos, el camino del mapa de la Lección 0: el cliente le habla al daemon, el daemon descarga la imagen, crea un contenedor y te devuelve su salida. `hello-world` es la única imagen de este curso que se usa sin versión fija (`latest`), porque es la única que no publica etiquetas con número de versión: sus etiquetas son `latest` y `linux` (la misma imagen) y variantes para Windows (`nanoserver-…`), que aquí no sirven ([Docker Hub](https://hub.docker.com/_/hello-world)).
5. **El *socket*.** `srw-rw----`: la `s` dice que es un *socket*; `rw-` para el dueño, `root`; `rw-` para el grupo, `docker`; y `---` para todos los demás. Esa última columna de guiones es la que hace que un usuario fuera del grupo no pueda hablarle al daemon (1.8).
6. **Cero contenedores del curso.** `--rm` hizo su trabajo. Todos los nombres de este curso empiezan con `curso-docker-` para que puedas encontrar y borrar lo tuyo sin tocar nada más; es una costumbre que conviene tener desde el primer contenedor.

### 1.8 El grupo `docker`

#### 1.8.1 El error de permisos

Recién instalado Docker, si tecleas `docker ps` sin `sudo`, vas a ver el error de esta sección. `fig01_06.sh` lo provoca sin sacarte del grupo: usa al usuario `nobody`, que existe en prácticamente cualquier distribución (Mint y Ubuntu lo traen) y no pertenece a ningún grupo útil. El `sudo` del guion sirve solo para cambiar de usuario, no para darle permisos a `nobody`: justamente por eso el guion sigue funcionando como demostración aunque tú ya estés en el grupo `docker`:

```bash
#!/usr/bin/env bash
# fig01_06.sh — El error de permisos: un usuario que NO está en el grupo docker.
# Usa al usuario «nobody», que existe en prácticamente toda distribución (Mint y
# Ubuntu lo traen) y no pertenece a ningún
# grupo útil, para mostrar el error sin tener que sacarte a ti del grupo.
set -uo pipefail

echo "== ¿En qué grupos está nobody?"
id -nG nobody

echo
echo "== nobody intenta hablarle al daemon"
sudo -u nobody docker ps
echo "código de salida: $?"

echo
echo "== ¿Y tú? ¿Estás en el grupo docker?"
if id -nG | tr ' ' '\n' | grep -qx docker; then echo "sí"; else echo "no"; fi
```

Corrida real · máquina virtual:

```text
$ ./fig01_06.sh
== ¿En qué grupos está nobody?
nogroup

== nobody intenta hablarle al daemon
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
código de salida: 1

== ¿Y tú? ¿Estás en el grupo docker?
sí
```

Esta salida es estable. La última línea dirá `no` si todavía no hiciste lo de 1.8.2, y ese es el estado en el que tú vas a ver el error con tu propio usuario.

`sudo -u nobody` corre el comando como el usuario `nobody`. Ese usuario solo está en el grupo `nogroup`, así que, ante el *socket* `srw-rw---- root docker`, cae en la tercera columna: sin permiso de nada. El mensaje se lee igual que el de la Lección 0, con otra causa al final: el cliente **sí** encontró el *socket* en `/var/run/docker.sock` (el daemon está ahí), pero no tiene permiso de abrirlo. Compáralo con el `no such file or directory` de la Lección 0, que significaba «no hay daemon en esa ruta». Dos causas distintas, dos arreglos distintos: aquí no sirve reiniciar el servicio.

#### 1.8.2 Entrar al grupo

Hay tres formas de quitarte el error, y conviene conocerlas antes de escoger:

1. **Usar `sudo docker` siempre.** Funciona y no da ningún permiso nuevo, pero es incómodo, y los archivos de configuración del cliente acaban siendo de `root` (lo ves en 1.8.3).
2. **Entrar al grupo `docker`.** Es lo que hace casi todo el mundo y lo que hace este curso. Desde ese momento, cualquier programa que corra como tú puede hablarle al daemon.
3. **El grupo bajo demanda**, con contraseña (1.9.3).

La forma 2 son tres pasos (de la documentación):

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

- `groupadd docker` crea el grupo. La guía avisa que en algunas distribuciones el paquete ya lo crea al instalar; en Ubuntu y en Mint es así, y el comando te dirá `groupadd: group 'docker' already exists`. No es un error de verdad: el grupo ya estaba.
- `usermod -aG docker $USER` te agrega al grupo. La `-a` (*append*) es importante: sin ella, `-G` **reemplaza** todos tus grupos suplementarios por `docker`: te quedarías solo con tu grupo principal y `docker`, y fuera de `sudo`, entre otros. `$USER` es tu nombre de usuario.
- El cambio no aplica a las sesiones que ya tienes abiertas, porque los grupos de un proceso se fijan al iniciar sesión. La guía pide **cerrar sesión y volver a entrar** (y, si tu Linux corre en una máquina virtual, quizá reiniciarla). `newgrp docker` es el atajo: abre un *shell* nuevo con el grupo ya aplicado, solo en esa terminal. Tiene tres límites que conviene conocer: no llega a las otras pestañas de terminal ni a los programas gráficos que ya tenías abiertos (un editor con terminal integrada, por ejemplo), así que ahí seguirás viendo `permission denied`; si tecleas `exit` vuelves al *shell* anterior, donde el grupo no está activo; y el grupo `docker` pasa a ser el grupo principal de ese *shell*, por lo que los archivos que crees ahí quedarán con `docker` como grupo. Para que el cambio valga en todo tu entorno, cierra la sesión y vuelve a entrar.

Después, `id -nG` debe incluir la palabra `docker`, y `docker run hello-world` debe funcionar sin `sudo`. Ese es el momento de correr `fig01_05.sh`.

#### 1.8.3 El error de después: `config.json`

Si antes de entrar al grupo corriste comandos con `sudo docker`, puede que veas esto al usar `docker` sin `sudo` (de la documentación; `user` es tu usuario):

```text
WARNING: Error loading config file: /home/user/.docker/config.json -
stat /home/user/.docker/config.json: permission denied
```

El cliente guarda su configuración en la carpeta `.docker` de tu directorio personal. Cuando lo corriste con `sudo`, esa carpeta se creó con dueño `root`, y ahora tú no puedes leerla. La guía da dos arreglos: borrar `~/.docker/` (se vuelve a crear sola, pero pierdes la configuración que tuviera), o devolverte la carpeta:

```bash
sudo chown -R "$USER":"$USER" "$HOME/.docker"
sudo chmod -R g+rwx "$HOME/.docker"
```

La guía los escribe con `-R` al final y con la ruta `/home/$USER/.docker` en el primero; aquí van con la opción antes de los argumentos (el orden que pide el estándar POSIX) y con `$HOME` en los dos, para que funcionen también si tu carpeta personal no está bajo `/home`.

Es un buen ejemplo de por qué `sudo docker` no es tan inocente: no da más poder que el grupo, pero deja rastros de `root` donde no deberían estar.

### 1.9 Por qué el grupo `docker` equivale a `root`

#### 1.9.1 La advertencia

Los pasos posteriores a la instalación ponen esta advertencia justo antes de los comandos de 1.8.2: «el grupo `docker` otorga privilegios de nivel `root` al usuario» ([Docker, pasos posteriores](https://docs.docker.com/engine/install/linux-postinstall/)). Y la guía de seguridad explica por qué: el daemon necesita `root` y Docker te deja compartir una carpeta del anfitrión con un contenedor «sin limitar los derechos de acceso del contenedor»; puedes arrancar un contenedor en el que `/host` sea la carpeta `/` de tu equipo, «y el contenedor puede alterar el sistema de archivos de tu anfitrión sin ninguna restricción» ([Docker Engine security](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)).

Una advertencia se olvida; una demostración, no. Por eso este curso no te pide creerla.

#### 1.9.2 Verlo con tus ojos

`/etc/shadow` es el archivo donde Linux guarda las contraseñas cifradas de los usuarios. Solo `root` y el grupo `shadow` pueden leerlo (permisos `0640`); tú, como usuario normal, no. `fig01_07.sh` intenta leerlo dos veces: primero como tú, sin `sudo`; después, pidiéndoselo al daemon de Docker. Para no imprimir nada secreto, solo cuenta los renglones y muestra el primer **nombre** de usuario:

```bash
#!/usr/bin/env bash
# fig01_07.sh — Por qué el grupo docker equivale a root.
# Córrelo SIN sudo, como tu usuario normal (que ya está en el grupo docker).
# Lee /etc/shadow, el archivo de contraseñas cifradas que solo root y el grupo shadow pueden leer,
# y solo imprime cuántos renglones tiene y el primer NOMBRE de usuario: nada secreto.
set -uo pipefail
IMAGEN=debian:13.7-slim

echo "== 1. Tú, sin sudo, intentas leer /etc/shadow"
ls -l /etc/shadow | awk '{print $1, $3, $4, $NF}'
cat /etc/shadow > /dev/null
echo "código de salida: $?"

echo
echo "== 2. Lo mismo, pero se lo pides al daemon de Docker"
docker run --rm --name curso-docker-llave -v /etc:/anfitrion-etc:ro "$IMAGEN" sh -c '
  id
  echo "renglones de /etc/shadow que pude leer: $(wc -l < /anfitrion-etc/shadow)"
  echo "primer usuario de la lista: $(cut -d: -f1 /anfitrion-etc/shadow | head -1)"'
echo "código de salida: $?"
```

Corrida real · máquina virtual:

```text
$ ./fig01_07.sh
== 1. Tú, sin sudo, intentas leer /etc/shadow
-rw-r----- root shadow /etc/shadow
cat: /etc/shadow: Permission denied
código de salida: 1

== 2. Lo mismo, pero se lo pides al daemon de Docker
Unable to find image 'debian:13.7-slim' locally
13.7-slim: Pulling from library/debian
ddc0c1e36a67: Pulling fs layer
d449c469d06c: Download complete
ddc0c1e36a67: Download complete
ddc0c1e36a67: Pull complete
Digest: sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad
Status: Downloaded newer image for debian:13.7-slim
uid=0(root) gid=0(root) groups=0(root)
renglones de /etc/shadow que pude leer: 26
primer usuario de la lista: root
código de salida: 0
```

Cambian en tu equipo: el número de renglones (uno por usuario de tu sistema), los identificadores de la descarga y el bloque de descarga entero si ya tenías la imagen. Lo demás es estable.

Lee las dos mitades juntas:

1. **Como tú, el sistema te dice que no.** `/etc/shadow` es de `root` y del grupo `shadow`, y los demás no tienen ningún permiso (`---`). `cat` falla con `Permission denied`, como debe ser.
2. **Pidiéndoselo al daemon, te dice que sí.** `-v /etc:/anfitrion-etc:ro` monta la carpeta `/etc` de tu equipo dentro del contenedor, en `/anfitrion-etc`. Dentro, el proceso es `uid=0(root)`, y como el espacio de nombres de usuarios no se aísla por omisión (Lección 0, sección 0.3), es el **mismo** usuario 0 de tu equipo. Lee el archivo sin problema: 26 renglones, empezando por el de `root`.

No usaste `sudo`. No escribiste ninguna contraseña. Bastó con estar en el grupo `docker`. Y el `:ro` del montaje (solo lectura) no te protege a ti: la restricción la pusiste tú, y nada te impedía quitarla y montar `/` completo con permiso de escritura. (Sí es una protección real contra un proceso que ya corre dentro del contenedor y no puede cambiar cómo se montó; lo que no frena es a quien tiene el mando del daemon.) Eso es lo que significa «equivale a `root`»: no que el grupo `docker` tenga un permiso especial, sino que le da acceso a un programa que corre como `root` y que hace lo que le pidas.

La misma lógica explica las otras dos prohibiciones de la escena. Darle permisos `777` al *socket* es meter a **todos** los usuarios y programas del equipo en el grupo `docker` sin preguntarles. Y montar el *socket* dentro de un contenedor es darle esa llave a lo que corra dentro.

#### 1.9.3 Las alternativas

La documentación ofrece tres caminos para quien no quiere ese poder siempre disponible:

- **`sudo docker`**, cada vez. El poder es el mismo, pero hay que pedirlo con contraseña, y queda registrado.
- **El grupo bajo demanda.** Tu usuario se queda **fuera** del grupo `docker`, se le pone una contraseña al grupo (`sudo gpasswd docker`) y, cuando necesitas Docker, abres un *shell* con `newgrp docker` y escribes esa contraseña. La guía dice para qué sirve y para qué no: reduce el acceso «ambiental» al *socket*, porque solo lo tienen los programas que lances desde ese *shell*, pero no reduce los privilegios una vez concedido el acceso, y «no es una frontera de seguridad» contra código malicioso que ya corre como tu usuario ([Docker, pasos posteriores](https://docs.docker.com/engine/install/linux-postinstall/#access-the-docker-group-on-demand)).
- **El modo *rootless*.** El daemon y los contenedores corren dentro de un espacio de nombres de usuarios, sin privilegios de `root`, para mitigar posibles vulnerabilidades del daemon y del entorno de ejecución ([Docker, modo *rootless*](https://docs.docker.com/engine/security/rootless/)). Es la única de las tres que cambia el fondo del asunto. Tiene sus propios requisitos y limitaciones, y algunos detalles que este curso enseña se verían distintos en él, por eso no es el camino del curso.

El curso usa el grupo, en un equipo que es tuyo y donde tú eres quien decide qué corre. La regla que importa: **meter a alguien al grupo `docker` es darle `root`**. Si no le darías la contraseña de `root` a una persona o a un programa, tampoco lo metas al grupo.

> [!NOTE]
> 🔧 **Observación de ingeniería 1.2**
> La pregunta útil no es «¿este permiso es peligroso?», sino «¿qué puedo hacer **a través** de este permiso?». El grupo `docker` no dice `root` en ningún lado; el camino a `root` pasa por un intermediario que sí lo es. Muchos problemas de seguridad tienen esa forma: un permiso modesto que abre la puerta a alguien con más poder.

### 1.10 Actualizar y desinstalar

**Actualizar.** Como Docker vive en un repositorio de `apt`, se actualiza igual que todo lo demás: `sudo apt update` y `sudo apt upgrade`, o repitiendo el comando de 1.6 con la versión nueva que quieras ([Docker, instalar en Ubuntu](https://docs.docker.com/engine/install/ubuntu/#upgrade-docker-engine)).

**Desinstalar.** Son tres pasos, y cada uno quita una cosa distinta (de la documentación):

```bash
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm /etc/apt/sources.list.d/docker.sources
sudo rm /etc/apt/keyrings/docker.asc
```

El primero quita los programas (`purge`, a diferencia de `remove`, quita también su configuración). Nota que la lista incluye `docker-ce-rootless-extras`, el sexto paquete que viste en la simulación de 1.5.3. El segundo par **borra todas tus imágenes, contenedores y volúmenes**, que el primero dejó intactos: es irreversible, así que antes de correrlo asegúrate de que no hay nada ahí que quieras conservar. El tercer par quita la fuente y la llave, para que `apt` deje de consultar el repositorio de Docker. La guía agrega que los archivos de configuración que hayas editado a mano hay que borrarlos a mano. El caso típico es `/etc/docker/daemon.json`, si algún día lo creaste para cambiar la configuración del daemon: `purge` no lo toca, y si reinstalas Docker "desde cero", el daemon nuevo lo lee y hereda esa configuración. Revisa con `ls /etc/docker` y borra a mano lo que ya no quieras.

## El error que vas a ver

Esta lección tiene dos errores principales, los dos provocados en sus secciones, y uno secundario que ya conoces.

**El error de Mint: «does not have a Release file».** Es el de `fig01_03.sh` (1.5.2):

```text
Err:2 https://download.docker.com/linux/ubuntu zena Release
  404  Not Found [IP: 3.161.44.57 443]
E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.
```

Se lee así: `apt` pidió al repositorio de Docker la versión `zena` y el servidor contestó que no existe (404). La palabra que importa es la que está entre la dirección y `Release`: si ahí aparece un nombre de Mint (`wilma`, `xia`, `zara`, `zena`), el problema es el renglón `Suites` de `/etc/apt/sources.list.d/docker.sources`. Se arregla reescribiendo ese archivo con la línea de la guía oficial, que usa `UBUNTU_CODENAME` (1.5.3), y corriendo `sudo apt update` otra vez. Si ya lo reescribiste y el error persiste **con el nombre de Mint**, hay otro archivo apuntando al repositorio: `./fig01_08.sh` te dice cuál (1.4.4). Si en lugar del nombre de Mint aparece `noble` y aun así falla, el problema es otro (la red, la URL mal escrita, o un `docker.list` viejo con otra llave, 1.4.4); y si aparece el nombre de una versión de Ubuntu que Docker no soporta, revisa la lista de 1.2.1.

**El error de permisos: «permission denied while trying to connect to the docker API».** Es el de `fig01_06.sh` (1.8.1):

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

Se lee así: el daemon **sí** está (el *socket* existe), pero tu usuario no tiene permiso de abrir el *socket*. Se arregla con `sudo usermod -aG docker $USER` y cerrando sesión (1.8.2), **sabiendo lo que eso significa** (1.9). Lo que no se hace: `chmod 666` o `777` sobre el *socket*, que se lo abre a todos los usuarios del equipo. Además, el *socket* lo vuelve a crear *systemd* (la unidad `docker.socket`) con sus permisos de siempre, `root:docker` y `0660`, cada vez que arranca el equipo, así que el «arreglo» desaparece en el siguiente reinicio, y la tentación es repetirlo.

**El error secundario: el daemon no está.** Lo viste en la Lección 0, provocado con una ruta de prueba (corrida real de esa lección):

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

En tu Mint, con el servicio detenido, la ruta será `/var/run/docker.sock` y el resto del mensaje, el mismo. Ahora puedes diagnosticarlo de punta a punta: `systemctl is-active docker` te dice si el servicio corre; si no, `sudo systemctl start docker` lo arranca, y `sudo journalctl -u docker` te muestra el registro del servicio para saber por qué se detuvo. Si `is-enabled` dice `disabled`, el servicio no arrancará solo al encender el equipo: `sudo systemctl enable docker` lo arregla.

## El hábito de seguridad de la lección

**El grupo `docker` equivale a `root`: se concede sabiéndolo, y solo a quien le darías `root`.** Este hábito evita dos accidentes concretos. El primero es el de la escena: «arreglar» el error de permisos abriendo el *socket* a todos, con lo que cualquier programa del equipo —incluido uno que descargaste sin revisar— puede pedirle al daemon que monte tu disco. El segundo es más silencioso: meter al grupo, «para que no batalle», a otra persona o a una cuenta de servicio que solo necesitaba ver unos registros. En los dos casos el daño no se nota hasta que alguien lo usa.

Junto con ese hábito va otro, más chico, que esta lección también instala: **la llave de un repositorio vale solo para ese repositorio** (`Signed-By`), y nada que te pida `apt-key` o un guion descargado y corrido sin leer entra a tu equipo.

## Lo que se hace mal

**Instalar `docker.io` «porque es más fácil».** Es el paquete de tu distribución, no el de Docker: otra versión, otro ritmo de actualizaciones, y los *plugins* con otros nombres. Si lo tienes y además instalas los oficiales, chocan. Este curso está medido con los oficiales.

**Copiar la guía de instalación de Debian, o una guía vieja, en Mint.** Usan `VERSION_CODENAME`, que en Mint es el nombre de Mint. El resultado es el error de 1.5.2.

**Escribir `noble` a mano «porque funciona».** Funciona hoy, pero ata el comando a una sola versión: si se lo pasas a alguien con Mint 21 (`jammy`), o lo vuelves a correr el día que tu Mint cambie de base de Ubuntu, escribe un nombre equivocado. La expresión de la guía saca el valor de `/etc/os-release` en el momento de correrla. Ojo: en los dos casos el archivo guarda el nombre ya resuelto; si un día cambias de versión de Mint, lo que se repite es el comando de 1.5.3, no se edita el archivo a ojo.

**`chmod 777 /var/run/docker.sock`.** Le da a todo el equipo lo que el grupo `docker` da a sus miembros: `root`. Y ni siquiera dura, porque *systemd* recrea el *socket* al arrancar el equipo.

**Meter a cualquiera al grupo `docker`.** Es darle `root` (1.9).

**Usar `apt-key add`.** Está en desuso (tu Mint 22 aún lo trae, por eso parece funcionar), y pone la llave en un llavero que vale para todos los repositorios.

**Correr el guion de `get.docker.com` sin leerlo.** La propia guía pide revisar los guiones descargados antes de correrlos, y no lo recomienda para producción. Un guion que se descarga y se corre con `sudo` tiene `root` en tu equipo, igual que el grupo `docker`.

**Olvidar `-a` en `usermod -aG`.** `usermod -G docker` reemplaza tus grupos suplementarios por `docker`: te deja con tu grupo principal y `docker`, y fuera de `sudo`.

**Dar por terminada la instalación sin comprobarla.** Que `apt` no haya dado error no dice que el servicio corra, ni que arranque solo, ni que tu usuario pueda usarlo. Las comprobaciones de `fig01_05.sh` toman dos segundos.

## Ejercicios

Escribe tus respuestas y tus predicciones en la [bitácora](bitacora.md) antes de ver las soluciones.

### Ejercicio 1 — Lee tu `os-release` (proyecto)

Corre `fig01_01.sh` en tu Mint. Antes de correrlo, predice qué dirán `VERSION_CODENAME`, `UBUNTU_CODENAME` y `Suites`. Después contesta: si un compañero tiene LMDE 7, ¿qué dirían esas tres líneas en su equipo, qué guía de instalación le toca y qué nombre en clave va en su `Suites`? Pista: corre `./fig01_01.sh os-release-lmde-7.txt` dentro de `programas/01-instalacion/` y busca una variable que Mint no tiene. El último bloque mostrará la arquitectura de tu equipo, no la de él.

### Ejercicio 2 — Diagnostica sin correr nada

Un compañero te manda tres mensajes de error, uno por día. Son los errores de esta lección tal como los vería él, con el nombre de su versión de Mint y la ruta del *socket* de su equipo. Para cada uno, di cuál es la causa y qué comando o cambio la arregla:

1. `E: The repository 'https://download.docker.com/linux/ubuntu xia Release' does not have a Release file.`
2. `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`
3. `failed to connect to the docker API at unix:///var/run/docker.sock; check if the path is correct and if the daemon is running: dial unix /var/run/docker.sock: connect: no such file or directory`

### Ejercicio 3 — ¿De dónde sale cada cosa?

Sin instalar nada nuevo, corre estos dos comandos en tu Mint (ya con Docker instalado) y contesta las preguntas:

```bash
apt-cache policy docker-ce docker.io | grep -E '^[a-z]|Installed|Candidate'
cat /etc/apt/sources.list.d/docker.sources
```

1. ¿Qué versión de `docker-ce` tienes instalada, y cuál se instalaría si actualizaras?
2. ¿Tienes `docker.io` instalado? ¿Lo ofrece algún repositorio?
3. ¿Qué dice el renglón `Suites` y por qué?

### Ejercicio 4 — La llave del daemon

Sin correrlo, contesta: si en `fig01_07.sh` cambiaras `-v /etc:/anfitrion-etc:ro` por `-v /:/anfitrion` (sin `:ro`), ¿qué podría hacer el contenedor? Nombra una cosa concreta que podría cambiar en tu equipo. Después explica en dos frases por qué `chmod 777 /var/run/docker.sock` es peor que meter a tu usuario al grupo `docker`.

## Soluciones

### Solución 1

En un Mint 22.x: `VERSION_CODENAME` dice el nombre de tu Mint (`wilma`, `xia`, `zara` o `zena`), `UBUNTU_CODENAME` dice `noble` y `Suites` dice `noble`, porque la regla `${UBUNTU_CODENAME:-$VERSION_CODENAME}` prefiere la primera variable cuando existe. Si tu `Suites` dijo otra cosa, revisa que tengas Mint 22 y no una versión anterior: Mint 21 está hecho sobre Ubuntu Jammy y te diría `jammy`, que también es una versión soportada.

En LMDE 7, `VERSION_CODENAME=gigi`, `UBUNTU_CODENAME` sale `(no existe)` y por eso `Suites: gigi`, un nombre que Docker no tiene. Pero su `os-release` trae `DEBIAN_CODENAME=trixie`, la variable que Mint no tiene, y es la que va en el renglón `Suites` de la guía de Debian: `${DEBIAN_CODENAME:-$VERSION_CODENAME}` (1.2.3). Esta es la salida de la pista (corrida real · máquina virtual, por eso `arm64`; está en `fig01_01.salida-lmde.txt`):

```text
$ ./fig01_01.sh os-release-lmde-7.txt
== Lo que dice os-release-lmde-7.txt
NAME=LMDE
VERSION=7 (gigi)
ID=linuxmint  ID_LIKE=debian
VERSION_CODENAME=gigi
UBUNTU_CODENAME=(no existe)
DEBIAN_CODENAME=trixie

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: gigi

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
arm64
```

### Solución 2

1. **El nombre en clave de Mint en el repositorio.** `xia` es Mint 22.1. El renglón `Suites` de `/etc/apt/sources.list.d/docker.sources` tiene el nombre de Mint; se reescribe el archivo con la línea de la guía oficial (`${UBUNTU_CODENAME:-$VERSION_CODENAME}`) y se corre `sudo apt update` (1.5.3).
2. **El usuario no está en el grupo `docker`.** El daemon corre; falta permiso para el *socket*. `sudo usermod -aG docker $USER`, cerrar sesión y volver a entrar (o `newgrp docker`), sabiendo que eso equivale a darle `root` (1.8 y 1.9).
3. **El daemon no está corriendo.** No hay *socket* en esa ruta. `systemctl is-active docker` lo confirma; `sudo systemctl start docker` lo arranca, `sudo journalctl -u docker` dice por qué se había detenido y `sudo systemctl enable docker` lo deja arrancando solo.

Si confundiste el 2 con el 3, vuelve a leer el final de cada mensaje: `permission denied` contra `no such file or directory`. En estos dos mensajes del cliente de Docker, la causa está en las últimas palabras; no es una regla general (hay trazas que ponen el origen al principio), así que acostúmbrate a preguntarte quién habla y cuál es la condición exacta que falló.

### Solución 3

1. En el bloque de `docker-ce`, `Installed` es la versión que tienes y `Candidate` la que se instalaría con `sudo apt upgrade`. Si son iguales, estás al día.
2. Si seguiste la lección, `docker.io` dirá `Installed: (none)`. Su `Candidate` probablemente muestre una versión: el paquete existe en los repositorios de Ubuntu que usa tu Mint, aunque no lo instales. Esa es la razón por la que conviene saber de dónde sale cada paquete.
3. `Suites: noble`, porque la expresión de la guía tomó el `UBUNTU_CODENAME` de tu `/etc/os-release`: el repositorio de Docker tiene carpetas por versión de Ubuntu, no por versión de Mint.

### Solución 4

Con `/` montado con escritura, el contenedor, como `root`, podría cambiar cualquier archivo de tu equipo: por ejemplo, agregar un usuario nuevo con permisos de administrador editando `/etc/passwd` y `/etc/sudoers`, borrar `/etc/shadow` o reemplazar un programa de `/usr/bin` por otro. Es la frase de la guía de seguridad: el contenedor «puede alterar el sistema de archivos de tu anfitrión sin ninguna restricción».

`chmod 777` es peor porque no le da ese poder solo a tu usuario, sino a **todos** los usuarios y programas del equipo, sin que ninguno tenga que estar en un grupo ni lo sepa. Y además no dura: *systemd* recrea el *socket* con sus permisos al reiniciar el equipo, así que quien lo usa se acostumbra a repetirlo.

## Cómo sé que lo logré

Marca cada punto solo si se cumple en **tu** equipo:

- [ ] `fig01_01.sh` muestra `Suites: noble` (o, en LMDE, sabes por qué no y qué guía te toca).
- [ ] `cat /etc/apt/sources.list.d/docker.sources` muestra el formato de seis campos de 1.5.1, con `Suites: noble` (en LMDE, `trixie` y la URL de `linux/debian`) y `Signed-By: /etc/apt/keyrings/docker.asc`, y `sudo apt update` no muestra ningún renglón `E:`.
- [ ] `systemctl is-active docker` imprime `active` y `systemctl is-enabled docker` imprime `enabled`.
- [ ] `id -nG` incluye `docker`, y `docker version` sin `sudo` muestra la versión del cliente **y** la del daemon.
- [ ] `fig01_05.sh`, sin `sudo`, termina con `Hello from Docker!` en el bloque 4, `srw-rw---- root docker /var/run/docker.sock` en el bloque 5 y `0` en el bloque 6. Lo que no se compara, porque cambia: las versiones, los identificadores y el *digest* de la descarga, y la arquitectura entre paréntesis.
- [ ] `fig01_06.sh` imprime el `permission denied` para `nobody` y `sí` para ti.
- [ ] `fig01_07.sh` imprime `Permission denied` en el bloque 1 y `uid=0(root)` en el bloque 2, y puedes explicar en voz alta por qué.
- [ ] Al terminar, `docker ps -a --filter name=curso-docker-` no muestra nada. Dos imágenes sí se quedan, `hello-world` y `debian:13.7-slim`; no estorban, y en la Lección 2 aprendes a verlas (`docker image ls`) y a borrarlas.
- [ ] Anotaste en tu bitácora qué versión de Docker instalaste y en qué fecha.

## Resumen

Responde sin mirar la lección:

1. ¿Por qué el curso instala los paquetes de `download.docker.com` y no `docker.io`?
2. ¿Qué dice `/etc/os-release` en Mint que no dice en Ubuntu, y por qué importa para instalar Docker?
3. ¿Qué hace la expresión `${UBUNTU_CODENAME:-$VERSION_CODENAME}`?
4. ¿Qué cinco paquetes instala la guía, y qué pieza del mapa de la Lección 0 es cada uno?
5. ¿Para qué sirve el campo `Signed-By`, y qué problema tenía `apt-key`?
6. ¿Qué significa «does not have a Release file» al agregar el repositorio en Mint?
7. ¿Cuál es la diferencia entre `permission denied` y `no such file or directory` al hablarle al daemon?
8. ¿Por qué el grupo `docker` equivale a `root`, y qué alternativas hay?
9. ¿Por qué ufw no protege los puertos que publica Docker, y qué hace este curso al respecto?

## Fuentes

Todas consultadas el 21 de octubre de 2026.

- [Docker, «Install Docker Engine on Ubuntu»](https://docs.docker.com/engine/install/ubuntu/): las versiones de Ubuntu soportadas, la nota sobre Linux Mint, la advertencia del cortafuegos, los paquetes en conflicto, el repositorio con su llave, los cinco paquetes, cómo fijar una versión, el guion de conveniencia, las comprobaciones, la actualización y la desinstalación.
- [Docker, «Install Docker Engine on Debian»](https://docs.docker.com/engine/install/debian/): el renglón `Suites` con `VERSION_CODENAME` y la nota para distribuciones derivadas (LMDE).
- [Docker, «Linux post-installation steps for Docker Engine»](https://docs.docker.com/engine/install/linux-postinstall/): el grupo `docker`, la advertencia de que equivale a `root`, el error de `config.json`, el grupo bajo demanda con contraseña y el arranque del servicio con *systemd*.
- [Docker Engine security, «Docker daemon attack surface»](https://docs.docker.com/engine/security/#docker-daemon-attack-surface): por qué quien controla el daemon controla el anfitrión.
- [Docker, «Packet filtering and firewalls»](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw): por qué los puertos publicados se saltan ufw.
- [Docker, «Rootless mode»](https://docs.docker.com/engine/security/rootless/): qué es el modo sin `root`.
- [Docker Desktop para Linux](https://docs.docker.com/desktop/setup/install/linux/): que Docker Desktop en Linux corre una máquina virtual.
- [Docker Engine 29, notas de versión](https://docs.docker.com/engine/release-notes/29/): la versión 29.9.2 y su fecha.
- [Linux Mint, todas las versiones](https://www.linuxmint.com/download_all.php): las versiones de Mint 22, su base Ubuntu Noble y LMDE 7 sobre Debian Trixie.
- [Repositorio de paquetes de Linux Mint](http://packages.linuxmint.com/): el paquete `base-files` `13ubuntu10mint22.3.0`, de donde sale el `/etc/os-release` de Mint 22.3 usado en las corridas.
- [sources.list(5), manual de `apt`](https://manpages.debian.org/trixie/apt/sources.list.5.en.html): los formatos de un renglón y deb822.
- [apt-key(8), manual de `apt` en Ubuntu 24.04](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html): `apt-key` en desuso y hasta qué versión estará disponible.
- [Colima](https://github.com/abiosoft/colima): la máquina virtual de las corridas.

### Términos de esta lección

| | |
|---|---|
| **`apt`** | el gestor de paquetes de Mint, Ubuntu y Debian; descarga e instala paquetes desde repositorios |
| **deb822** | el formato de los archivos `.sources` de `apt`: un campo con nombre por renglón |
| **`dpkg`** | el gestor de paquetes de bajo nivel, sobre el que trabaja `apt` |
| **grupo `docker`** | el grupo de Linux cuyos miembros pueden hablarle al daemon sin `sudo`; equivale a `root` |
| **LMDE** | *Linux Mint Debian Edition*, la edición de Mint hecha sobre Debian y no sobre Ubuntu |
| **llave (de repositorio)** | la parte pública de una llave criptográfica con la que `apt` comprueba que los paquetes vienen de quien dicen |
| **nombre en clave** | el nombre corto de una versión de una distribución: `noble` para Ubuntu 24.04, `zena` para Mint 22.3 |
| ***plugin*** | un programa que se agrega al cliente `docker` como subcomando: `docker compose`, `docker buildx` |
| **repositorio** | un servidor que publica paquetes con un índice firmado |
| ***rootless*** | modo en el que el daemon y los contenedores corren sin privilegios de `root` |
| ***systemd*** | el programa que arranca y vigila los servicios del sistema; se maneja con `systemctl` |
| **ufw** | *Uncomplicated Firewall*, la herramienta de cortafuegos de Ubuntu |

---

**Anterior:** [Lección 0 — Qué es un contenedor y qué NO es](00-que-es-un-contenedor.md) · **Siguiente:** [Lección 2 — Contenedores en el día a día](02-contenedores-dia-a-dia.md)
