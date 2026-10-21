# Leçon 0 — Ce qu'est un conteneur et ce qu'il n'est PAS

Il est 2 h 14 du matin et l'alerte sonne : le serveur de test a cessé de répondre. Tu te connectes comme tu peux et la première chose que tu vois, c'est que la base de données, qui vivait sur cette même machine, ne tourne plus. Le journal du système dit que le noyau l'a tuée faute de mémoire. Quelqu'un, dans le salon de discussion de l'équipe, écrit, tout convaincu : « Ça ne peut pas être le `revisor`, lui il tourne dans un conteneur ; il est isolé, c'est comme une machine à part. » Dix minutes plus tard, le coupable apparaît : le conteneur du `revisor`, sans aucune limite, avait avalé la mémoire de toute la machine jusqu'à ce que le noyau doive choisir qui tuer, et il a choisi la base de données. Personne n'a menti. Ce qui s'est passé, c'est que cette personne se faisait une idée fausse de ce qu'est un conteneur, et cette idée a coûté une nuit. Cette leçon existe pour que tu ne l'aies pas.

**Durée :** 90 min

**Ce que tu construis :** rien pour l'instant. C'est une leçon de lecture : on y dresse la carte mentale grâce à laquelle le reste du cours devient prévisible. Elle apporte neuf petits programmes pour que tu voies de tes yeux ce que la leçon affirme.

**Ce que tu apprends :** qu'un conteneur est un processus isolé et non une machine virtuelle ; avec quelles pièces du noyau Linux on construit cet isolement (les espaces de noms et les groupes de contrôle) ; la différence entre une image et un conteneur ; que Docker, ce sont deux programmes, un client et un daemon ; et ce qu'un conteneur partage avec la machine hôte, et pourquoi cela décide de la sécurité.

**D'où tu viens.** Tu n'apportes rien de ce cours : tu n'as pas encore installé Docker. Tu apportes, en revanche, ce que le cours considère comme acquis : tu utilises un terminal avec aisance, tu sais ce qu'est un processus (un programme qui est en train de s'exécuter) et ce qu'est un serveur HTTP. Peut-être as-tu déjà écrit le `revisor` dans le cours de Go, de Rust ou de TypeScript de Hábil. Sinon, ceci suffit : c'est un programme qui interroge une liste de services en même temps et rend un rapport disant lesquels sont en ligne, lesquels sont lents et lesquels sont hors service. Ce que tu n'apportes probablement pas, c'est une idée précise de ce qu'est un conteneur à l'intérieur, et c'est cette idée qu'il te faudra chaque fois que quelque chose échouera.

**Ce que cette leçon ne fait pas.** Elle n'installe rien (c'est la [Leçon 1](01-instalacion.md)) et n'enseigne pas les commandes de Docker une par une (cela commence à la [Leçon 2](02-contenedores-dia-a-dia.md)). Les programmes de cette leçon sont des scripts *bash* de dix à trente lignes qui appellent `docker` et des outils Linux ordinaires comme `ps` et `uname`. Il n'est pas nécessaire que tu comprennes chaque option pour l'instant, même si chacune est expliquée : ce qui compte, c'est ce qu'ils **impriment**. On les exécute après la Leçon 1, quand tu auras Docker.

**À propos des exécutions.** Les sorties de cette leçon ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle Linux pour pouvoir exécuter des conteneurs. Cette machine virtuelle a Ubuntu 24.04.4, qui est la même base que Linux Mint 22, donc **les scripts ont été exécutés à l'intérieur de celle-ci** et c'est là qu'apparaît l'« hôte » dans les sorties : sur ton Mint, l'hôte est ton propre ordinateur et les mêmes commandes fonctionnent sans changement. La version de Docker dans cette machine était la 29.2.1 (client et daemon). Le cours a été planifié avec la 29.8.2 et, le jour de cette exécution, la plus récente publiée était la 29.9.2, du 20 octobre 2026, d'après les [notes de version officielles](https://docs.docker.com/engine/release-notes/29/). Rien de ce que montre cette leçon ne change entre ces versions ; la Leçon 1 t'apprend à voir la tienne. Ce qui change, **en revanche**, d'une exécution à l'autre, et c'est signalé là où cela se produit : les numéros de processus (PID), les numéros des espaces de noms, les durées et, si ton ordinateur a un processeur Intel ou AMD, le mot `arm64`, qui dira `amd64` chez toi. Les programmes se trouvent dans [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor), dans le dépôt du cours, chacun avec sa sortie enregistrée à côté.

## À la fin, tu seras capable de

- Montrer avec `ps` qu'un conteneur qui tourne est un processus de plus de la machine hôte, et trouver son numéro de processus depuis l'extérieur.
- Expliquer avec un exemple pourquoi un conteneur n'est pas une machine virtuelle, en employant le mot *noyau*.
- Nommer les espaces de noms que Docker isole et les deux qu'il n'isole pas par défaut.
- Lire dans `/sys/fs/cgroup` les limites de mémoire, de CPU et de processus d'un conteneur, et dire ce qui se passe quand il n'y en a aucune.
- Distinguer une image d'un conteneur, et prédire ce qui arrive à un fichier écrit à l'intérieur d'un conteneur quand ce conteneur est supprimé.
- Expliquer ce que font le client `docker` et le daemon `dockerd`, et par où ils se parlent.
- Dire ce qu'un conteneur partage avec l'hôte et pourquoi cela fait de « root dans le conteneur » une affaire de sécurité.

## Le pourquoi avant le comment

Imagine que tu termines le `revisor` et que quelqu'un te demande de le faire tourner sur un serveur. Le plus direct est de copier l'exécutable et de le lancer. Cela marche, jusqu'au jour où cela ne marche plus : le serveur a une autre version d'une bibliothèque, ou le port 8080 est déjà pris par un autre programme, ou le `revisor` a un défaut qui lui fait consommer de la mémoire sans arrêt et qui emporte avec lui tout le reste de ce qui tourne là. Et quand tu découvres enfin que sur ta machine, ça fonctionnait, la phrase « sur ma machine, ça marche » ne sert plus à personne.

Les conteneurs sont nés pour résoudre cela : livrer un programme **avec tout ce dont il a besoin pour s'exécuter**, et l'exécuter **à l'écart** des autres, avec des limites. C'est vrai et c'est très utile. Le problème commence quand cette description se transforme en une image mentale fausse : « un conteneur est un petit ordinateur à l'intérieur du mien ». Avec cette image, la scène du début est impossible : comment un petit ordinateur pourrait-il tuer un programme du grand ? Avec la bonne image, la scène est évidente.

La bonne image est celle-ci, et c'est celle qu'emploie la documentation de Docker elle-même : un conteneur est un **processus isolé** ([Docker, « What is a container? »](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)). Ce n'est pas un autre ordinateur. C'est un programme qui s'exécute sur **ton** ordinateur, sur **ton** noyau Linux, auquel le noyau met des murs (pour qu'il ne voie pas ce qu'il ne doit pas voir) et un budget (pour qu'il ne dépense pas ce qu'il ne doit pas dépenser). Si les murs sont bien posés, le processus croit être seul. S'il n'y a pas de budget, il peut tout dépenser.

La leçon comporte sept parties, dans cet ordre :

1. **Un conteneur est un processus** (0.1) : tu le regardes de l'intérieur et de l'extérieur.
2. **Ce n'est pas une machine virtuelle** (0.2) : le noyau partagé et ce que cela implique.
3. **Les murs : les espaces de noms** (0.3).
4. **Le budget : les groupes de contrôle** (0.4), avec l'erreur de cette leçon.
5. **Image contre conteneur** (0.5).
6. **Le client et le daemon** (0.6).
7. **Ce qui est partagé et la sécurité** (0.7), et un peu d'histoire pour te repérer (0.8).

Avec cet objectif en tête, voici ce que tu verras à la section 0.4, quand un conteneur doté d'une limite de mémoire essaiera de la dépasser. C'est ce qui a manqué au conteneur de la scène :

```text
voy a comer memoria...
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

## Les concepts

### 0.1 Un conteneur est un processus

#### 0.1.1 Le regarder de l'intérieur et de l'extérieur

Le moyen le plus rapide de se débarrasser de l'idée du « petit ordinateur » est de démarrer un conteneur et de le chercher avec les outils habituels. Le programme `fig00_01.sh` démarre un conteneur qui ne fait rien d'autre que dormir cinq minutes (`sleep 300`), le regarde de l'intérieur, le regarde de l'extérieur et le supprime à la fin :

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

Les nombres `836426` et `836402` changent à chaque exécution ; tout le reste reste identique. Avant de lire la sortie, voici les lignes du script qui comptent. `set -euo pipefail` fait que le script s'arrête à la première erreur, au lieu de continuer comme si de rien n'était. `trap ... EXIT` programme que, quoi qu'il arrive, le conteneur soit supprimé à la sortie : ainsi il ne reste pas de déchets sur ta machine, une habitude que la Leçon 2 érige en règle. `docker run -d` démarre le conteneur « en arrière-plan » (*detached*) et lui donne un nom avec `--name` ; tous les noms de ce cours commencent par `curso-docker-` pour que tu saches d'un coup d'œil ce qui est à toi. `docker exec` exécute une commande **à l'intérieur** d'un conteneur déjà en marche, et `docker inspect` interroge les données d'un conteneur ; ici, son numéro de processus sur l'hôte.

Maintenant la sortie, bloc par bloc :

1. **De l'intérieur**, le conteneur ne voit que deux processus : `sleep 300`, qui a le numéro **1**, et le `ps` que tu viens de lancer. Il ne voit ni ton navigateur, ni ton terminal, ni rien de ce qui tourne sur ta machine. De son point de vue, il est le premier processus du système.
2. **De l'extérieur**, Docker te dit que ce même processus a le numéro 836426 sur l'hôte.
3. Et **le système d'exploitation de l'hôte** le confirme avec un `ps` ordinaire, le même que tu utiliserais pour n'importe quel autre programme : `sleep 300` est là, qui s'exécute en tant que `root`. Il n'y a pas d'autre ordinateur. Il y a un processus de plus dans la liste de ta machine.
4. Son parent est `containerd-shim`, un petit programme que Docker charge de surveiller chaque conteneur. (Le nom complet est `containerd-shim-runc-v2` ; `ps` le raccourcit parce que le champ `comm` ne garde que 15 caractères.)

🔑 **Relis cela : le même processus a deux numéros.** À l'intérieur, c'est le 1 ; à l'extérieur, c'est le 836426. Ce ne sont pas deux processus : c'en est un seul, vu depuis deux endroits. Qu'il ait deux numéros est le premier indice du fonctionnement de l'isolement, et la section 0.3 l'explique.

#### 0.1.2 Ce que signifie être un processus

Qu'un conteneur soit un processus n'est pas un détail technique ; cela a des conséquences que tu sentiras tout au long du cours :

- **Il démarre en millisecondes**, parce que démarrer un processus est rapide. Il n'y a pas de système d'exploitation à allumer.
- **Il meurt comme un processus.** Si le programme principal se termine, le conteneur se termine. Si le noyau le tue, le conteneur meurt. À la Leçon 7, tu verras que cela inclut les signaux : `docker stop` envoie à ce processus numéro 1 le même signal que tu enverrais avec `kill`.
- **Il dépense comme un processus.** Il utilise la mémoire et le CPU de ta machine, puisés dans la même réserve que tous les autres programmes. Si personne ne lui met de limite, il n'a pas de limite.
- **Tu le vois avec tes outils habituels.** `ps`, `top` et le moniteur système le montrent. C'est utile pour diagnostiquer, et c'est un avertissement : qui a pouvoir sur les processus de l'hôte a pouvoir sur les conteneurs.

> [!NOTE]
> 🔧 **Observation de génie logiciel 0.1**
> Une bonne image mentale se reconnaît à ce qu'elle prédit. Avec « c'est un petit ordinateur », tu ne peux pas prédire que le conteneur apparaisse dans le `ps` de l'hôte. Avec « c'est un processus isolé », tu le prédis avant d'exécuter le programme. Tout au long du cours, quand quelque chose te surprendra, demande-toi d'abord ce que ferait un processus ordinaire dans cette situation.

### 0.2 Ce n'est pas une machine virtuelle

#### 0.2.1 Deux distributions, un seul noyau

Une **machine virtuelle** est un programme qui imite un ordinateur complet : un processeur, de la mémoire, un disque et une carte réseau factices. À l'intérieur de cet ordinateur factice démarre un système d'exploitation entier, **avec son propre noyau**. C'est pourquoi, dans une machine virtuelle, tu peux faire tourner Windows sur Linux ou Linux sur un Mac.

Le **noyau** (*kernel*) est la partie du système d'exploitation qui commande le matériel : il répartit la mémoire, décide quel processus utilise le CPU à chaque instant, parle au disque et au réseau. Tout le reste — le *shell*, `ls`, le gestionnaire de paquets, les bibliothèques — s'exécute par-dessus et lui demande les choses. On appelle souvent ce qui est au-dessus l'**espace utilisateur**.

Un conteneur n'apporte pas de noyau. Il n'apporte que de l'espace utilisateur. C'est ce que prouve `fig00_02.sh`, qui demande la distribution et la version du noyau sur l'hôte et dans deux conteneurs de distributions différentes :

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

Sur ton Mint, la première ligne dira `Linux Mint 22...` et le noyau sera celui de ta machine ; ce qui compte, c'est que **les trois numéros de noyau seront identiques entre eux**. Le fichier `/etc/os-release` est l'endroit où chaque distribution écrit son nom, et `uname -r` demande sa version au noyau. L'option `--rm` demande à Docker de supprimer le conteneur dès qu'il se termine.

Regarde ce qui s'est passé. Dans le conteneur Alpine, le fichier dit que tu es sur Alpine 3.24. Dans celui de Debian, que tu es sur Debian 13. Mais quand tu poses la question **au noyau**, les trois répondent la même chose : `6.8.0-100-generic`, celui de l'hôte. Les fichiers sont ceux d'Alpine ou de Debian ; le noyau est unique, partagé. C'est exactement ce que dit la documentation : « si tu exécutes plusieurs conteneurs, ils partagent tous le même noyau » ([Docker, « What is a container? »](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)).

De là découle une règle à bien retenir : **une « image de Debian » n'est pas Debian**. C'est l'espace utilisateur de Debian — ses programmes, ses bibliothèques, son gestionnaire de paquets — qui s'exécute sur le noyau que tu as. Presque toujours cela suffit, parce que l'interface du noyau Linux change très peu d'une version à l'autre. Mais si un programme a besoin d'une fonction d'un noyau plus récent que le tien, l'image ne la lui apportera pas.

#### 0.2.2 La preuve par l'envers : pourquoi un Mac a besoin d'une machine virtuelle

Si un conteneur Linux a besoin d'un noyau Linux, que se passe-t-il sur un ordinateur qui n'en a pas ? Il se passe ce que tu as vu dans « À propos des exécutions » : il faut lui en procurer un. Sur macOS, Colima démarre une machine virtuelle Linux et Docker tourne à l'intérieur. Docker Desktop, l'application de bureau de Docker, fait la même chose avec sa propre machine virtuelle : d'après sa documentation, « le daemon Docker et les conteneurs s'exécutent dans une machine virtuelle Linux légère gérée par Docker » ([Docker Desktop, permissions sur Mac](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/)).

Cette machine virtuelle n'est pas un accident ; c'est la confirmation de tout ce qui précède. Si les conteneurs apportaient leur propre noyau, ils n'en auraient pas besoin. Ton Mint n'en a pas besoin : le noyau Linux est déjà là, et les conteneurs s'exécutent directement dessus. C'est l'une des raisons pour lesquelles le cours prend Linux comme système de référence : ce que tu vois est ce qu'il y a, sans couche intermédiaire.

#### 0.2.3 La comparaison complète

| | Machine virtuelle | Conteneur |
|---|---|---|
| Ce que c'est | un ordinateur imité par un logiciel | un processus avec des murs et un budget |
| Noyau | le sien | celui de l'hôte, partagé |
| Ce qui démarre | un système d'exploitation complet | un programme |
| Temps de démarrage | de quelques secondes à quelques minutes | millisecondes |
| Peut faire tourner un autre système d'exploitation | oui (Windows sur Linux, par exemple) | non : un conteneur Linux a besoin d'un noyau Linux |
| Ce qui la sépare de l'hôte | l'hyperviseur, qui imite du matériel | le noyau, qui pose les murs |
| Si quelque chose échappe à l'isolement | cela arrive dans la machine imitée | cela arrive dans le noyau que tous partagent |

La dernière ligne est celle qui compte pour la sécurité, et nous la reprenons en 0.7.

Quant au temps de démarrage, inutile de le croire : on le mesure. `fig00_09.sh` crée, exécute et supprime un conteneur qui ne fait rien (`true` est un programme qui se termine immédiatement), cinq fois de suite :

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

Ces nombres changent toujours : ils dépendent de ta machine et de ce qu'elle fait d'autre à ce moment-là. Lors d'une autre exécution sur la même machine, ils étaient compris entre 135 et 194 ms. Ce qui est stable, c'est l'ordre de grandeur : **des dixièmes de seconde**, pour créer le conteneur, démarrer le processus, l'attendre et tout supprimer. Une machine virtuelle met cela rien que pour commencer à charger son noyau.

### 0.3 Les murs : les espaces de noms

#### 0.3.1 Ce qu'est un espace de noms

Revenons à l'indice de 0.1 : le même processus est le numéro 1 à l'intérieur et le 836426 à l'extérieur. Comment un processus peut-il avoir deux numéros ? Parce que le noyau Linux possède une fonction appelée **espaces de noms** (*namespaces*). Un espace de noms est une « vue » privée d'une ressource du système. Les processus qui se trouvent dans un espace de noms voient leur propre version de cette ressource, et ne voient pas celle des autres.

Docker le dit sans détour : il utilise « une technologie appelée *namespaces* pour fournir l'espace de travail isolé que l'on appelle conteneur » ([Docker, « What is Docker? »](https://docs.docker.com/get-started/docker-overview/)). Il y en a huit types, et chacun isole une chose différente. La liste vient du manuel de Linux ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)) :

| Type | Nom dans `/proc` | Ce qu'il isole | Ce qu'on voit dans un conteneur |
|---|---|---|---|
| PID | `pid` | les numéros de processus | son programme est le numéro 1 et il ne voit pas les processus de l'hôte |
| Mount | `mnt` | les points de montage | il voit son propre arbre de fichiers, celui de l'image, et non le tien |
| Network | `net` | interfaces, adresses, ports | il a son propre réseau et son propre port 8080 |
| UTS | `uts` | le nom de la machine | il a son propre *hostname* |
| IPC | `ipc` | la communication entre processus par mémoire partagée | elle ne se mélange pas à celle des autres programmes |
| Cgroup | `cgroup` | la racine des groupes de contrôle | il voit son propre groupe comme s'il était la racine (0.4) |
| User | `user` | les numéros d'utilisateur et de groupe | **par défaut, il n'est pas isolé** |
| Time | `time` | certaines horloges du système | **par défaut, il n'est pas isolé** |

La ligne Network explique quelque chose que tu utiliseras dès la Leçon 2 : deux conteneurs peuvent écouter sur le port 8080 en même temps sans conflit, parce que chacun a son propre réseau. Celle de Mount explique pourquoi le conteneur Debian voyait des fichiers Debian alors que ta machine est un Mint.

#### 0.3.2 Le voir de tes yeux

Chaque processus Linux a un dossier `/proc/<numéro>/ns/` avec un lien pour chaque type d'espace de noms. Ce que contient ce lien, c'est le type et un nombre, par exemple `pid:[4026531836]`. Le manuel l'explique ainsi : si deux processus sont dans le même espace de noms, ce nombre est le même ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)). Il suffit donc de comparer des nombres. C'est ce que fait `fig00_03.sh`, qui lit les huit liens de l'hôte et d'un conteneur et les met côte à côte :

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

Les nombres entre crochets changent d'une machine à l'autre et ceux du conteneur changent à chaque exécution ; la colonne `¿IGUAL?` reste toujours la même tant que tu utilises la configuration par défaut de Docker. `/proc/self` est un raccourci qui pointe toujours vers le processus qui le lit, et `readlink` montre où pointe un lien.

Six murs et deux trous. Le conteneur a ses propres processus, son propre arbre de fichiers, son propre réseau, son propre nom de machine, sa propre mémoire partagée et sa propre vue des groupes de contrôle. Mais il partage avec l'hôte les horloges (`time`) et, surtout, **les utilisateurs** (`user`). Que l'espace des utilisateurs soit le même signifie que le numéro d'utilisateur 0, `root`, est **le même `root`** à l'intérieur et à l'extérieur. Tu l'as déjà vu en 0.1 : le `sleep 300` apparaissait sur l'hôte comme appartenant à `root`. Docker sait aussi isoler les utilisateurs, mais ne le fait pas par défaut ([Docker Engine security](https://docs.docker.com/engine/security/)). Tout cela vaut pour Docker dans son mode normal, celui qu'installe la Leçon 1 : le daemon s'exécute en tant que `root` et sans remappage des utilisateurs. Deux modes changent l'histoire. Avec [`userns-remap`](https://docs.docker.com/engine/security/userns-remap/), le `root` de l'intérieur est, sur l'hôte, un numéro d'utilisateur élevé et sans privilèges ; en [mode *rootless*](https://docs.docker.com/engine/security/rootless/), le daemon et ses conteneurs s'exécutent dans un espace d'utilisateurs sans privilèges. Dans les deux, la ligne `user` du tableau dirait « non, isolé ». La machine de ces exécutions utilise le mode normal : `docker info --format '{{.SecurityOptions}}'` a imprimé `[name=apparmor name=seccomp,profile=builtin name=cgroupns]`, sans `rootless` ni `userns`, et tu peux ainsi vérifier le tien. C'est la moitié de l'histoire de sécurité de 0.7.

> [!NOTE]
> 🔧 **Observation de génie logiciel 0.2**
> Un espace de noms **cache** ; il ne **limite** pas. Que le conteneur ne voie pas les processus de l'hôte ne l'empêche pas de dépenser toute sa mémoire. Le premier est le travail des espaces de noms ; le second, celui des groupes de contrôle. La scène du début est la confusion entre les deux.

### 0.4 Le budget : les groupes de contrôle

#### 0.4.1 Ce qu'est un groupe de contrôle

Les **groupes de contrôle** (*control groups*, presque toujours abrégés *cgroups*) sont l'autre moitié du travail. Ce sont un mécanisme du noyau pour ranger les processus en groupes et répartir entre ces groupes les ressources du système — mémoire, CPU, nombre de processus, lecture et écriture sur disque — de façon contrôlée ([documentation du noyau, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). Le guide de sécurité de Docker le résume en une phrase : les groupes de contrôle « implémentent la comptabilité et la limitation des ressources » ([Docker Engine security](https://docs.docker.com/engine/security/)).

Chaque conteneur vit dans son propre groupe. Le noyau tient le compte de ce que dépense ce groupe et, s'il a une limite, ne le laisse pas la dépasser. Les limites peuvent se lire comme des fichiers texte dans `/sys/fs/cgroup`. Trois d'entre elles reviendront tout au long du cours :

- `memory.max` : combien de mémoire le groupe peut utiliser. S'il atteint cette limite et ne peut rien libérer, le noyau appelle le « tueur de processus en cas de manque de mémoire » (*OOM killer*) **à l'intérieur de ce groupe** ([cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)).
- `cpu.max` : deux nombres, « combien de temps » et « sur quelle période ». Par défaut, il vaut `max 100000`, ce qui signifie sans plafond dans chaque période de 100 000 microsecondes (un dixième de seconde).
- `pids.max` : combien de processus le groupe peut avoir au maximum.

#### 0.4.2 Sans limite, pas de limite

Le plus important de cette section, c'est ce que Docker fait **si tu ne lui demandes rien**. La documentation est explicite : « par défaut, un conteneur n'a aucune restriction de ressources » et peut utiliser tout ce que l'ordonnanceur du noyau lui laisse ([Docker, « Resource constraints »](https://docs.docker.com/engine/containers/resource_constraints/)). `fig00_04.sh` lit les trois fichiers dans un conteneur sans limites et dans un autre avec limites :

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

Cette sortie est stable, à deux conditions. La première, la version 2 des groupes de contrôle, qui est celle d'Ubuntu 24.04, la base de Mint 22 (la machine de ces exécutions la signale : `stat -fc %T /sys/fs/cgroup` imprime `cgroup2fs`). La seconde, que les *contrôleurs* `memory`, `cpu` et `pids` soient activés, ces pièces du noyau qui tiennent chaque compte : dans la version 2, ils s'activent un par un, et un fichier comme `memory.max` n'apparaît dans un groupe que si son contrôleur est activé ([documentation du noyau, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). Dans une installation normale de Mint, ils le sont ; pour le vérifier, `cat /sys/fs/cgroup/cgroup.controllers` doit inclure ces trois mots (sur la machine de ces exécutions, il a imprimé `cpuset cpu io memory hugetlb pids rdma misc`). S'il en manque un, Docker peut le signaler par un `WARNING` à la fin de `docker info` ([Docker, restrictions de ressources](https://docs.docker.com/engine/containers/resource_constraints/)), le fichier correspondant n'existe pas dans le conteneur et ta sortie ne ressemblera pas à celle-ci. Sans limites, les trois fichiers disent `max` : le conteneur peut utiliser toute la mémoire de la machine, tout le CPU et créer autant de processus qu'il veut. C'était le conteneur de la scène.

Avec des limites, chaque option de `docker run` devient un nombre que le noyau fait respecter :

- `--memory 64m` est devenu `67108864`, soit 64 × 1024 × 1024 octets : exactement 64 Mio.
- `--cpus 0.5` est devenu `50000 100000` : à chaque dixième de seconde, le groupe peut utiliser le CPU pendant la moitié, 50 000 microsecondes. C'est un demi-CPU.
- `--pids-limit 50` est devenu `50`.

Remarque la chaîne des responsabilités. Toi, tu écris une option dans `docker run` ; Docker la traduit et l'écrit dans un fichier du noyau ; le noyau est celui qui l'applique. Docker ne surveille pas le conteneur : c'est le noyau qui surveille. C'est pourquoi la limite fonctionne même si le programme à l'intérieur est malveillant ou détraqué.

#### 0.4.3 Ce qui se passe quand la limite est atteinte

Une limite que l'on ne touche jamais n'enseigne rien. `fig00_05.sh` démarre un conteneur avec 32 Mio de mémoire et sans espace d'échange (*swap*), et lui demande quelque chose qu'il ne peut pas tenir : `tail /dev/zero` lit un fichier infini de zéros en cherchant la fin de la dernière ligne, et comme aucun saut de ligne n'arrive jamais, il garde tout en mémoire sans s'arrêter :

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

Cette sortie est stable. Ici on n'utilise pas `--rm`, exprès : si Docker supprimait le conteneur à la fin, tu ne pourrais pas lui demander ensuite ce qui lui est arrivé. `--memory-swap 32m` fixe le total de mémoire plus échange à la même valeur que la mémoire, c'est-à-dire zéro échange ; sans cela, le processus mettrait plus longtemps à mourir parce qu'il commencerait par remplir le disque d'échange.

Le conteneur a imprimé son message, a commencé à manger de la mémoire et, en atteignant 32 Mio, le noyau l'a tué. Personne d'autre sur la machine ne s'en est aperçu : la base de données de la scène, si elle avait été là, serait restée en vie. Le nombre **137** est la convention pour dire « ce processus est mort à cause d'un signal » : c'est 128 plus le numéro du signal, et le signal 9 est `KILL`, celui qu'on ne peut ni intercepter ni ignorer. La convention n'a pas été inventée par Docker : c'est celle du *shell*, dont le manuel dit que, lorsqu'une commande se termine par le signal N, *bash* utilise 128+N comme code de sortie ([manuel de Bash](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html)) ; tu peux le vérifier dans n'importe quel *bash* : `bash -c 'kill -9 $$'; echo $?` imprime `137`. Docker note le même nombre dans `ExitCode`, et `docker run` le renvoie tel quel, parce que tout code autre que 125, 126 et 127 est celui de la commande du conteneur ([Docker, codes de sortie](https://docs.docker.com/engine/containers/run/)). Et `OOMKilled=true`, c'est Docker qui confirme que c'était par manque de mémoire. La section « L'erreur que tu vas voir » te dit comment lire cela quand cela apparaîtra sans que tu l'aies provoqué.

Tu peux maintenant réécrire la scène avec précision. Le conteneur du `revisor` était dans son propre espace de noms — il ne voyait pas la base de données —, mais dans un groupe de contrôle sans limite — il puisait dans la même réserve. Quand la réserve s'est épuisée, le noyau a dû tuer quelqu'un **dans toute la machine**, pas seulement dans le groupe du conteneur, et il en a choisi un autre. Avec `--memory`, le tueur aurait agi **à l'intérieur du groupe** du `revisor`, et seul le `revisor` serait mort. La Leçon 2 met des limites dès le premier conteneur pour cette raison.

### 0.5 Image contre conteneur

#### 0.5.1 Le modèle et la copie vivante

Jusqu'ici, tu as employé deux mots comme s'ils étaient interchangeables, et ils ne le sont pas. La documentation de Docker les définit ainsi : une **image** est « un modèle en lecture seule avec des instructions pour créer un conteneur », et un **conteneur** est « une instance exécutable d'une image » ([Docker, « What is Docker? »](https://docs.docker.com/get-started/docker-overview/)).

Une comparaison qui aide, si tu viens de la programmation : l'image est comme un exécutable sur disque et le conteneur est comme le processus qui s'exécute à partir de lui. Du même exécutable, tu peux lancer dix processus ; de la même image, tu peux créer dix conteneurs. Si le processus écrit quelque chose dans sa mémoire, l'exécutable sur disque ne change pas.

La pièce qui manque, c'est l'endroit où un conteneur écrit quand il crée un fichier. La réponse, d'après la documentation du stockage de Docker : une image est faite de **couches** en lecture seule, et quand on crée un conteneur, on lui ajoute par-dessus une fine couche **dans laquelle on peut écrire**, appelée la couche du conteneur. Tout ce que le conteneur modifie va dans cette couche. Plusieurs conteneurs peuvent partager la même image, chacun avec sa propre couche. Et quand le conteneur est supprimé, sa couche est supprimée avec lui, tandis que l'image du dessous « reste inchangée » ([Docker, « Storage drivers »](https://docs.docker.com/engine/storage/drivers/)).

#### 0.5.2 Le voir de tes yeux

`fig00_06.sh` crée deux conteneurs de la même image, écrit un fichier dans l'un, regarde si l'autre le voit, demande ce qui a changé dans chacun et, à la fin, supprime le premier :

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

L'identifiant `294b683cb724` est celui de l'image `alpine:3.24.2` pour processeurs ARM 64 bits ; sur une machine Intel ou AMD, ce sera un autre, mais ce sera **le même au début et à la fin** de l'exécution, et c'est cela qui compte. `docker diff` montre ce qu'un conteneur a changé par rapport à son image : `A` signifie ajouté (*added*) et `C`, modifié (*changed*) ; le dossier `/tmp` apparaît comme modifié parce qu'il contient désormais quelque chose de nouveau.

Lis la sortie comme une histoire en quatre moments :

1. L'image a un identifiant, une empreinte de son contenu.
2. Le conteneur un écrit `/tmp/nota.txt` et le lit sans problème. Le conteneur deux, fait **de la même image**, ne l'a pas : chacun écrit dans sa propre couche.
3. `docker diff` le confirme : le un a ajouté un fichier ; le deux n'a rien changé.
4. On supprime le conteneur un. L'image a **le même identifiant** : rien de ce qu'a fait le conteneur ne l'a touchée. Et un nouveau conteneur de cette image n'a pas la note non plus. Le fichier est parti avec le conteneur.

Les conséquences pour le reste du cours sont au nombre de deux, et toutes deux sont importantes. La première : **ce qu'on écrit à l'intérieur d'un conteneur est jetable**. Si le `revisor` enregistre son rapport dans le conteneur et que quelqu'un le supprime, le rapport s'en va. C'est pour cela que la Leçon 8 existe, avec les volumes. La seconde : **une image ne se répare pas en entrant dans le conteneur**. Si tu entres avec `docker exec` pour corriger quelque chose, tu corriges cette copie vivante, pas le modèle ; le prochain conteneur naît sans ta correction. Les images se modifient en les reconstruisant à partir de leur recette, le `Dockerfile`, que tu apprends à la Leçon 3.

### 0.6 Le client et le daemon

#### 0.6.1 Deux programmes, pas un

Quand tu écris `docker run`, on dirait qu'un seul programme fait tout. Ce n'est pas le cas. Docker utilise une architecture **client-serveur** : le programme `docker` que tu tapes n'est qu'un **client**, et le vrai travail est fait par un **daemon** appelé `dockerd`, un programme qui tourne en arrière-plan en permanence. Selon la documentation, le daemon « écoute les requêtes de l'API Docker et gère les objets Docker » — images, conteneurs, réseaux et volumes —, et client et daemon se parlent « à l'aide d'une API REST, par des *sockets* UNIX ou une interface réseau » ([Docker, « What is Docker? »](https://docs.docker.com/get-started/docker-overview/)).

Un ***socket* UNIX** est un fichier spécial qui permet à deux programmes de la même machine de s'envoyer des messages. Celui du daemon Docker se trouve, par défaut, dans `/var/run/docker.sock`. Et tu as déjà vu à qui revient la création des conteneurs : le `containerd-shim` qui est apparu comme parent du `sleep` en 0.1 fait partie de la chaîne que le daemon met en route. Toi, tu demandes au client ; le client demande au daemon ; le daemon, avec l'aide d'autres pièces, demande au noyau les espaces de noms et les groupes de contrôle.

`fig00_07.sh` montre les deux moitiés et ce qui se passe quand le client ne trouve pas le daemon :

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

Chez toi, les versions changent et, si c'est un Intel ou un AMD, il dira `amd64`. `docker context inspect` montre vers quel daemon pointe le client, et la variable d'environnement `DOCKER_HOST` sert à le pointer vers un autre ; ici, exprès, vers un qui n'existe pas.

Trois choses que l'on apprend de cette sortie :

1. **`docker version` rapporte deux versions**, parce que ce sont deux programmes. Presque toujours elles coïncident, mais ce n'est pas obligatoire : sur le Mac de ces exécutions, le client de macOS était la 29.8.2 et le daemon de la machine virtuelle, la 29.2.1. Quand une commande se comporte bizarrement, la première question est de savoir laquelle des deux versions la provoque.
2. **Le client et le daemon se parlent par le *socket***. C'est une porte, et qui peut l'ouvrir commande le daemon.
3. **Sans daemon, le client ne sert à rien.** Le message dit exactement cela : il n'a pas pu se connecter à l'API Docker à ce chemin ; vérifie que le chemin est correct et que le daemon est en marche. Sur ton Mint, tu verras ce message avec le chemin `/var/run/docker.sock` le jour où le service Docker sera arrêté.

#### 0.6.2 Pourquoi c'est important de le savoir

Cela ressemble à une curiosité d'architecture et ce n'en est pas une. Le daemon s'exécute en tant que `root` : le guide de sécurité dit qu'il « nécessite des privilèges de `root` », sauf si tu actives le mode *rootless*, et que c'est pourquoi « seuls des utilisateurs de confiance » doivent pouvoir le contrôler ([Docker Engine security](https://docs.docker.com/engine/security/)). Si tu peux demander des choses au daemon, tu peux lui demander de créer un conteneur avec le dossier racine de ta machine monté à l'intérieur, et il le fera en tant que `root`. C'est pourquoi la documentation d'installation avertit que le groupe `docker` « accorde à l'utilisateur des privilèges équivalents à ceux de `root` » ([Docker, étapes post-installation sur Linux](https://docs.docker.com/engine/install/linux-postinstall/)). La Leçon 1 te met dans ce groupe et te fait regarder la conséquence en face. Et la Leçon 2 t'interdit, avec ce même argument, de monter le *socket* du daemon à l'intérieur d'un conteneur : cela donnerait au conteneur la clé de ta machine.

### 0.7 Ce qui est partagé et pourquoi cela décide de la sécurité

#### 0.7.1 Root à l'intérieur est root à l'extérieur

Tu as maintenant réuni toutes les pièces pour la question la plus sérieuse de la leçon : à quel point un conteneur est-il séparé de l'hôte ? `fig00_08.sh` demande qui est l'utilisateur à l'intérieur, à qui appartient le processus vu de l'extérieur et quels pouvoirs il a :

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

Cette sortie est stable avec la configuration par défaut de Docker. La dernière ligne dépend du nombre de capacités que connaît ton noyau ; avec un noyau de la série 6.8, elle est identique.

Les deux premiers blocs disent la même chose des deux côtés : à l'intérieur du conteneur, tu es l'utilisateur 0, `root`, et à l'extérieur ce processus appartient **aussi** à l'utilisateur 0. Ce n'est pas un `root` factice qui porte le même nom : comme l'espace de noms des utilisateurs n'a pas été isolé (0.3), c'est le même numéro d'utilisateur pour le même noyau. Si ce processus parvenait à sortir de ses murs — par un défaut du noyau, par un dossier de l'hôte monté sans précaution, par le *socket* du daemon —, il arriverait sur l'hôte en tant que `root`.

#### 0.7.2 Un root rogné : les capacités

Alors, un conteneur est-il aussi dangereux qu'un programme qui s'exécute en tant que `root` sur ta machine ? Pas tout à fait, et le troisième bloc explique pourquoi. Linux divise les pouvoirs de `root` en unités séparées appelées **capacités** (*capabilities*), que l'on peut activer et désactiver une par une ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Changer le propriétaire d'un fichier en est une ; ouvrir un port inférieur à 1024, une autre ; charger des modules dans le noyau, une autre encore.

La ligne `CapEff` de `/proc/<pid>/status` dit quelles capacités un processus a activées, sous forme de masque de bits en hexadécimal. Le processus 1 de l'hôte, qui est un vrai `root`, a `000001ffffffffff` : les 41 capacités que connaît ce noyau, toutes activées. Le `root` du conteneur a `00000000a80425fb`, soit **14**. Quand on décode ce masque avec l'outil `capsh` de l'hôte, on obtient exactement les quatorze que la documentation de Docker liste comme autorisées par défaut : `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `FSETID`, `KILL`, `SETGID`, `SETUID`, `SETPCAP`, `NET_BIND_SERVICE`, `NET_RAW`, `SYS_CHROOT`, `MKNOD`, `AUDIT_WRITE` et `SETFCAP` ([Docker, « Running containers »](https://docs.docker.com/engine/containers/run/)). Docker utilise une liste de ce qui est permis, non de ce qui est interdit : il retire tout et ne laisse que cela ([Docker Engine security](https://docs.docker.com/engine/security/)). Et avec `--cap-drop ALL`, tu peux lui retirer même ces quatorze, comme le montre la deuxième ligne ; la Leçon 7 t'apprend à retirer celles que le `revisor` n'utilise pas.

L'option inverse existe et il faut la reconnaître pour ne pas l'utiliser : `--privileged` « donne toutes les capacités au conteneur » et en plus l'accès à tous les périphériques de l'hôte ([Docker, « Running containers »](https://docs.docker.com/engine/containers/run/)). Avec elle, il ne reste presque plus de mur.

#### 0.7.3 La carte de ce qui est partagé

| Ce que le conteneur a en propre, par défaut | Ce qu'il partage avec l'hôte, par défaut |
|---|---|
| ses processus et leurs numéros de processus | **le noyau**, le même pour tous les conteneurs |
| son arbre de fichiers (celui de son image et sa couche) | **les utilisateurs** : `root` à l'intérieur est l'utilisateur 0 à l'extérieur |
| son réseau, ses ports, son nom de machine | les horloges du système |
| sa vue des groupes de contrôle | **la mémoire, le CPU et le disque**, si tu ne mets pas de limites |
| | **ce que tu y montes ou lui publies** : dossiers, ports, le *socket* |

La colonne de droite est la liste de ce dont tu dois prendre soin. Chaque leçon du cours en referme une partie : la 2 met des limites et ne publie des ports que sur `127.0.0.1` ; la 3 cesse d'utiliser `root` avec `USER` ; la 7 retire des capacités et met le système de fichiers en lecture seule ; la 8 veille à ce qui est monté. Ce n'est pas de la paranoïa : c'est la différence entre un processus avec des murs et un processus avec des murs en papier.

> [!NOTE]
> 🔧 **Observation de génie logiciel 0.3**
> Dans une machine virtuelle, pour s'échapper, il faut briser l'hyperviseur, qui imite un matériel simple. Dans un conteneur, pour s'échapper, il suffit de trouver un défaut dans le noyau, qui est énorme et que tous les conteneurs partagent. C'est pourquoi les conteneurs se durcissent avec plusieurs couches à la fois (sans `root`, sans capacités superflues, avec des limites) et qu'on ne se fie pas à une seule.

### 0.8 D'où tout cela vient

Rien de ce qui précède n'a été inventé par Docker. Les pièces sont celles du noyau Linux et sont arrivées peu à peu. Le guide de sécurité de Docker le raconte : les espaces de noms sont entrés dans le noyau entre les versions 2.6.15 et 2.6.26, cette dernière de juillet 2008, et les groupes de contrôle ont commencé en 2006 et ont été intégrés dans la version 2.6.24 ([Docker Engine security](https://docs.docker.com/engine/security/)). Pendant des années, des outils les ont utilisés, mais ils étaient difficiles à manier.

Ce qui a changé en 2013, c'est la **manière de les utiliser**. Le 15 mars de cette année-là, lors d'une conférence éclair de cinq minutes à PyCon, Solomon Hykes a raconté que, dans son entreprise, ils utilisaient des conteneurs Linux, que c'était compliqué et que c'est pourquoi ils n'en avaient pas parlé, « jusqu'à maintenant : Docker » ([PyCon US 2013, « The future of Linux Containers »](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html)). Docker a réuni les pièces du noyau avec deux idées à lui : un format d'image que l'on peut partager et des commandes que tout le monde comprend.

Deux ans plus tard, le 22 juin 2015, Docker, CoreOS et d'autres entreprises ont fondé l'**Open Container Initiative** (OCI), et Docker lui a fait don de son format et de son programme pour créer des conteneurs, `runc` ([OCI, « About »](https://opencontainers.org/about/overview/)). Aujourd'hui, l'OCI maintient trois spécifications : celle de l'environnement d'exécution, celle du format d'image et celle de la distribution. Pour toi, cela signifie quelque chose de pratique : l'image que tu construiras dans ce cours n'est pas « une image Docker » enfermée dans Docker, c'est une image OCI, et c'est pourquoi le cluster Kubernetes du cours suivant peut l'exécuter sans Docker. Au passage, `runc` est le programme qui apparaît à la fin du nom `containerd-shim-runc-v2` que tu as vu en 0.1.

### 0.9 Ce qui vient dans le reste du cours

Avec la carte de cette leçon, chaque leçon suivante est une pièce dont tu sais déjà où elle va :

- La **Leçon 1** installe le client, le daemon et les pièces intermédiaires sur ton Mint.
- La **Leçon 2** manipule des processus isolés : les démarrer, les observer, leur donner un budget (0.4) et les supprimer.
- Les **Leçons 3, 4 et 5** construisent l'**image** du `revisor` (0.5) : sa recette, ses couches et comment la rendre petite.
- La **Leçon 6** sépare la configuration et les secrets de l'image.
- La **Leçon 7** s'occupe du processus numéro 1 (0.1) et de la réduction de ses pouvoirs (0.7).
- La **Leçon 8** règle le fait que la couche du conteneur soit jetable (0.5) et relie les conteneurs par le réseau (0.3).
- La **Leçon 9** décrit tout cela dans un fichier, et la **10** livre l'image OCI (0.8) prête pour Kubernetes.

## L'erreur que tu vas voir

Cette leçon a une erreur principale, celle du conteneur que le noyau tue, et une secondaire, celle du client sans daemon. Les deux viennent de sections précédentes.

**L'erreur principale : le code 137 et `OOMKilled=true`.** C'est celle de `fig00_05.sh` :

```text
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

Cela se lit ainsi : le processus ne s'est pas terminé de lui-même ; il a été tué par le signal 9 (`137 = 128 + 9`), et Docker a noté que la cause était le manque de mémoire. Le piège, c'est que dans la vraie vie le conteneur **ne te prévient pas** : il n'imprime rien, il disparaît tout simplement, et s'il a une politique de redémarrage, il repart et remeurt encore et encore. Quand tu vois un 137, la première question est `docker inspect --format '{{.State.OOMKilled}}' <conteneur>`. S'il dit `true`, il y a deux remèdes possibles, selon le cas : relever la limite de mémoire, si le programme a vraiment besoin de plus ; ou corriger le programme, s'il dépense trop. Ce qu'on **ne** fait **pas**, c'est retirer la limite « pour qu'il ne meure pas » : cela ne règle rien, cela change seulement qui meurt, comme dans la scène.

**L'erreur secondaire : le client qui ne trouve pas le daemon.**

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

Cela se lit de gauche à droite : le client n'a pas pu se connecter à l'API Docker à ce chemin ; il te suggère de vérifier le chemin et que le daemon est en marche ; et à la fin vient la cause technique, à savoir que le fichier du *socket* n'existe pas. Sur ton Mint, avec le chemin `/var/run/docker.sock`, cela signifie presque toujours que le service Docker est arrêté. Si, au lieu de `no such file or directory`, il dit `permission denied`, le daemon est bien là, mais ton utilisateur n'a pas la permission de lui parler : c'est l'affaire de la Leçon 1.

## L'habitude de sécurité de la leçon

**Savoir ce qu'un conteneur partage avec la machine, et ne pas se fier à ce qu'il n'isole pas.** Le conteneur partage le noyau, les utilisateurs et, si tu ne lui mets pas de limites, la mémoire et le CPU. Cette habitude évite deux accidents concrets. Le premier est celui de la scène : un conteneur sans limite qui fait planter d'autres programmes de la même machine. Le second est plus grave : traiter un conteneur comme s'il était une machine à part et lui donner des choses de l'hôte — le *socket* du daemon, le dossier racine monté, `--privileged` — en pensant que « à l'intérieur, il ne peut rien arriver ». À l'intérieur tourne un processus `root` de ton propre noyau. Tout ce que tu lui donnes, tu le donnes à ce processus.

## Ce qu'on fait de travers

**Dire « c'est comme une machine virtuelle légère ».** C'est la phrase la plus répétée et celle qui fait le plus de mal, parce qu'elle conduit à attendre un isolement qui n'existe pas. Un conteneur est un processus isolé ; une machine virtuelle est un ordinateur imité. Ils se ressemblent par ce qu'on voit de l'extérieur et diffèrent par ce qui compte quand quelque chose échoue.

**Exécuter des conteneurs sans limites « parce que sur ma machine il y a de la mémoire en trop ».** Par défaut, il n'y a pas de limite, et ce qui est en trop aujourd'hui ne l'est plus le jour où le programme a un défaut. La limite n'est pas pour le cas normal ; elle est pour le mauvais jour.

**Entrer dans le conteneur pour « réparer » quelque chose.** Ce que tu changes avec `docker exec` vit dans la couche du conteneur et s'en va avec lui. La correction se fait dans la recette de l'image, que l'on reconstruit.

**Garder des données importantes à l'intérieur du conteneur.** Pour la même raison : la couche du conteneur est jetable. Les données qui doivent survivre vont dans des volumes (Leçon 8).

**Supposer que `root` à l'intérieur est inoffensif.** C'est l'utilisateur 0 du même noyau, avec 14 capacités activées. Moins que le `root` de l'hôte, mais bien plus qu'un utilisateur ordinaire. Dès la Leçon 3, le `revisor` ne s'exécute plus en tant que `root`.

**Croire qu'une image d'Ubuntu ou de Debian apporte ce système d'exploitation complet.** Elle apporte son espace utilisateur. Le noyau est le tien. Si ton noyau ne prend pas en charge quelque chose, l'image non plus.

**Confondre le client avec le daemon.** Quand une commande échoue, savoir si le problème est dans le client (version, configuration, `DOCKER_HOST`) ou dans le daemon (arrêté, sans permissions, autre version) épargne des heures à chercher au mauvais endroit.

## Exercices

Les exercices de cette leçon n'ont pas besoin de Docker pour y répondre : le premier et le quatrième sont des exercices de raisonnement, et le deuxième et le troisième se répondent **avant** d'exécuter quoi que ce soit et se vérifient après la Leçon 1. Écris tes prédictions dans le [journal de bord](bitacora.md) avant de voir les solutions ; les comparer est la moitié de l'apprentissage.

### Exercice 1 — La nuit du `revisor` (projet)

Reviens à la scène du début. Réponds avec tes propres mots, en employant ce que tu as appris :

1. Pourquoi le conteneur du `revisor` ne « voyait »-il pas la base de données, mais a-t-il pu la tuer ?
2. Quelle option de `docker run` aurait évité la mort de la base de données, et qui serait mort à sa place ?
3. Si, à ce moment-là, tu avais exécuté `docker inspect` sur le conteneur du `revisor`, que t'attendrais-tu à voir dans `OOMKilled` ? Réfléchis bien : qui a tué qui ?

### Exercice 2 — Pareil ou différent ?

Pour chaque paire, prédis si la valeur est **identique** ou **différente**. Suppose la configuration par défaut de Docker.

1. `uname -r` sur ton Mint et dans un conteneur de `debian:13.7-slim`.
2. `cat /etc/os-release` sur ton Mint et dans ce même conteneur.
3. `readlink /proc/self/ns/net` sur ton Mint et dans un conteneur.
4. `readlink /proc/self/ns/user` sur ton Mint et dans un conteneur.
5. Le numéro de processus du programme principal vu depuis l'intérieur du conteneur, et vu depuis l'hôte.
6. L'identifiant d'une image avant et après la suppression d'un conteneur qui a écrit des fichiers.

### Exercice 3 — Prédis le `memory.max`

Prédis quel nombre apparaît dans `/sys/fs/cgroup/memory.max` à l'intérieur de chacun de ces conteneurs, puis vérifie-le en changeant les options de `fig00_04.sh` :

1. `docker run --rm alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
2. `docker run --rm --memory 128m alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
3. `docker run --rm --memory 1g alpine:3.24.2 cat /sys/fs/cgroup/memory.max`

Et une pour le CPU : que dira `cpu.max` avec `--cpus 1.5` ?

### Exercice 4 — Explique-le en cinq phrases

Un collègue te dit : « J'ai installé Docker pour avoir une machine virtuelle Ubuntu dans mon Mint. » Explique-lui en cinq phrases au maximum ce qu'il a en réalité, en employant les mots *processus*, *noyau*, *espace de noms*, *groupe de contrôle* et *image*. Sans regarder la leçon.

## Solutions

### Solution 1

1. Parce que le conteneur se trouvait dans ses propres **espaces de noms** : avec celui des processus (`pid`), il ne voyait pas les processus de l'hôte, la base de données parmi eux. Mais voir et dépenser sont deux choses différentes : sans limite dans son **groupe de contrôle**, il dépensait dans la même mémoire que toute la machine. Quand elle s'est épuisée, le noyau a dû tuer quelqu'un dans tout le système, et il a choisi la base de données.
2. `--memory` (par exemple `--memory 256m`, le nombre dépend de ce dont le `revisor` a réellement besoin). Avec cette limite, en atteignant le plafond, le noyau aurait agi **à l'intérieur du groupe** du conteneur, et celui qui serait mort, c'est le `revisor` lui-même, avec le code 137 et `OOMKilled=true`. La base de données ne s'en serait même pas aperçue.
3. Le plus probable est `false`. Sans limite propre, le conteneur n'a pas atteint un plafond de **son** groupe : ce qui s'est épuisé, c'est la mémoire de toute la machine, et le noyau a tué la base de données, qui n'est pas un conteneur. Le `revisor` est resté en vie. C'est justement ce qui rend la scène trompeuse : le coupable n'a pas la marque, c'est la victime qui l'a (et dans le journal du système, pas dans Docker).

### Solution 2

1. **Pareil.** Le noyau est unique, partagé (fig00_02).
2. **Différent.** Le fichier vient de l'image, qui apporte l'espace utilisateur de Debian (fig00_02).
3. **Différent.** Le réseau est isolé : chaque conteneur a son espace de noms `net` (fig00_03).
4. **Pareil.** Par défaut, Docker n'isole pas les utilisateurs (fig00_03). C'est pourquoi `root` à l'intérieur est l'utilisateur 0 à l'extérieur (fig00_08).
5. **Différent.** À l'intérieur, c'est le 1 ; à l'extérieur, un numéro quelconque, comme le 836426 de fig00_01. C'est le même processus vu depuis deux espaces de noms de processus.
6. **Pareil.** Ce que le conteneur a écrit vivait dans sa couche propre et est parti avec lui ; l'image n'a pas changé (fig00_06).

Si tu t'es trompé sur le 4, c'est la plus courante et la plus importante : c'est la raison de tout le bloc de sécurité du cours.

### Solution 3

Valeurs vérifiées avec la même machine et la même version de Docker que la leçon :

1. `max` : sans `--memory`, il n'y a pas de limite.
2. `134217728`, soit 128 × 1024 × 1024.
3. `1073741824`, soit 1024 × 1024 × 1024. Docker interprète le `g` comme des gibioctets (puissances de 1024), de même que le `m` comme des mébioctets.

Avec `--cpus 1.5`, `cpu.max` dit `150000 100000` : dans chaque période de 100 000 microsecondes, le groupe peut utiliser 150 000 microsecondes de CPU, réparties entre les cœurs du processeur. Un CPU et demi.

### Solution 4

Une réponse possible : « Tu n'as pas une machine virtuelle ; tu as un programme qui crée des **processus** isolés. Ces processus s'exécutent sur le **noyau** de ton Mint, le même pour tous, et c'est pourquoi ils démarrent en dixièmes de seconde. Les **espaces de noms** leur mettent des murs pour qu'ils voient leurs propres processus, fichiers et réseau, et les **groupes de contrôle** leur mettent un budget de mémoire et de CPU, si toi tu le leur demandes. Le "Ubuntu" vient de l'**image** : elle apporte les programmes et les bibliothèques d'Ubuntu, mais pas son noyau. Et comme l'utilisateur `root` de l'intérieur est le même numéro d'utilisateur que celui de l'extérieur, il faut le traiter avec précaution. »

## Comment savoir que j'y suis arrivé

Il n'y a rien à construire dans cette leçon, donc la liste mêle compréhension et, après la Leçon 1, vérification. Coche chaque point seulement si tu peux le faire **sans revoir le texte** :

- [ ] Tu expliques en une minute pourquoi un conteneur n'est pas une machine virtuelle, et le mot *noyau* apparaît dans ton explication.
- [ ] Tu nommes les six espaces de noms que Docker isole par défaut et les deux qu'il n'isole pas.
- [ ] Tu dis ce que contiennent `memory.max` et `cpu.max` sans limites, et ce que signifie `50000 100000`.
- [ ] Tu expliques ce que signifient le code 137 et `OOMKilled=true`, et ce qu'il ne faut **pas** faire quand ils apparaissent.
- [ ] Tu expliques ce qui arrive à un fichier écrit dans un conteneur quand ce conteneur est supprimé, et pourquoi l'image ne change pas.
- [ ] Tu dessines le chemin de `docker run` : client → *socket* → daemon → noyau.
- [ ] Tu dis pourquoi le groupe `docker` équivaut à `root`.
- [ ] Après la Leçon 1, tu exécutes les neuf scripts de [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor) et tes sorties correspondent à celles de cette leçon pour ce que chaque section signale comme stable. Ce qui ne se compare pas, parce que cela change d'une machine ou d'une exécution à l'autre : les numéros de processus, les numéros des espaces de noms, les durées, les versions et l'architecture ; et si ton Docker tourne en mode *rootless* ou avec remappage des utilisateurs, ou s'il lui manque un contrôleur des groupes de contrôle, les différences que 0.3 et 0.4.2 t'ont dit d'attendre. Et à la fin, `docker ps -a --filter name=curso-docker-` n'affiche rien : tu n'as pas laissé de déchets.
- [ ] Tu as noté dans ton journal de bord ce que tu croyais qu'était un conteneur avant cette leçon.

## Résumé

Réponds sans regarder la leçon :

1. Qu'est-ce qu'un conteneur, en trois mots ? Pourquoi apparaît-il dans le `ps` de l'hôte ?
2. Qu'a une machine virtuelle qu'un conteneur n'a pas ? Pourquoi un Mac a-t-il besoin d'une machine virtuelle pour exécuter des conteneurs Linux ?
3. Que fait un espace de noms ? Donne trois exemples de ce qu'il isole.
4. Que fait un groupe de contrôle ? Quelle limite a un conteneur si tu ne lui en demandes aucune ?
5. Que signifient le 137 et `OOMKilled=true` ?
6. Qu'est-ce qu'une image et qu'est-ce qu'un conteneur ? Où un conteneur écrit-il ses fichiers et qu'advient-il d'eux quand on le supprime ?
7. Que font le client `docker` et le daemon `dockerd`, et par où se parlent-ils ?
8. Pourquoi `root` à l'intérieur d'un conteneur est-il une affaire de sécurité, et qu'est-ce qui le rogne ?

## Sources

Toutes consultées le 21 octobre 2026.

- [Docker, « What is a container? »](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/) : la définition du conteneur comme processus isolé et la comparaison avec les machines virtuelles.
- [Docker, « What is Docker? »](https://docs.docker.com/get-started/docker-overview/) : l'architecture client-serveur, le daemon, les définitions d'image et de conteneur, et l'usage des espaces de noms.
- [Docker Engine security](https://docs.docker.com/engine/security/) : espaces de noms, groupes de contrôle, la surface d'attaque du daemon, les capacités et les espaces de noms d'utilisateur ; aussi les dates de 0.8.
- [Docker, « Resource constraints »](https://docs.docker.com/engine/containers/resource_constraints/) : qu'un conteneur n'a pas de limites par défaut, et les options `--memory`, `--memory-swap` et `--cpus`.
- [Docker, « Running containers »](https://docs.docker.com/engine/containers/run/) : les quatorze capacités autorisées par défaut et ce que fait `--privileged`.
- [Docker, « Storage drivers »](https://docs.docker.com/engine/storage/drivers/) : les couches en lecture seule et la couche du conteneur.
- [Docker, étapes post-installation sur Linux](https://docs.docker.com/engine/install/linux-postinstall/) : l'avertissement sur le groupe `docker`.
- [Docker Desktop, permissions sur Mac](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/) : la machine virtuelle Linux de Docker Desktop.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions et dates de « À propos des exécutions ».
- [namespaces(7), manuel de Linux](https://man7.org/linux/man-pages/man7/namespaces.7.html) : les huit types d'espaces de noms et les liens de `/proc/<pid>/ns`.
- [capabilities(7), manuel de Linux](https://man7.org/linux/man-pages/man7/capabilities.7.html) : processus privilégiés et capacités.
- [Control Group v2, documentation du noyau Linux](https://docs.kernel.org/admin-guide/cgroup-v2.html) : `memory.max`, `cpu.max` et `pids.max`.
- [Open Container Initiative, « About »](https://opencontainers.org/about/overview/) : la fondation de l'OCI et ses trois spécifications.
- [PyCon US 2013, « The future of Linux Containers »](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html) : la conférence où Docker a été présenté.
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **hôte** (*host*) | la machine où s'exécutent les conteneurs ; dans le cours, ton Linux Mint |
| **couche** (*layer*) | chacune des parties en lecture seule d'une image ; le conteneur ajoute une couche propre où écrire |
| **capacité** (*capability*) | chacun des pouvoirs en lesquels Linux divise l'utilisateur `root` |
| **client** | le programme `docker` que tu tapes ; il envoie des requêtes au daemon |
| **conteneur** | un processus isolé créé à partir d'une image |
| **daemon** | programme qui tourne en arrière-plan ; celui de Docker s'appelle `dockerd` |
| **espace de noms** (*namespace*) | vue privée d'une ressource du système (processus, réseau, fichiers...) |
| **espace utilisateur** | tout ce qui s'exécute au-dessus du noyau : programmes, bibliothèques, *shell* |
| **groupe de contrôle** (*cgroup*) | mécanisme du noyau qui compte et limite les ressources d'un groupe de processus |
| **image** | modèle en lecture seule à partir duquel on crée des conteneurs |
| **machine virtuelle** | un ordinateur imité par un logiciel, avec son propre noyau |
| **noyau** (*kernel*) | la partie du système d'exploitation qui commande le matériel |
| **OCI** | *Open Container Initiative*, le standard ouvert des images et des conteneurs |
| **OOM killer** | la partie du noyau qui tue des processus quand la mémoire est épuisée |
| ***socket* UNIX** | fichier spécial par lequel deux programmes de la même machine s'envoient des messages |

---

**Suivante :** [Leçon 1 — Installer Docker sur ton Linux Mint](01-instalacion.md)
