# Leçon 7 — Contrôle de santé et cycle de vie

Il est 23 h 15 un vendredi soir, et la fenêtre de maintenance ferme à 23 h 30. Le plan est simple : mettre à jour le serveur où tourne le `revisor` avec dix-neuf autres conteneurs, le redémarrer et rentrer chez soi. Quelqu'un les arrête un par un, avec une boucle `for … docker stop`, et le terminal reste suspendu. Dix secondes. Dix autres. Dix autres encore. Trois minutes plus tard, la boucle se termine, et presque tous les conteneurs sont marqués `Exited (137)`, ce qui signifie « on les a tués ». Le serveur redémarre à 23 h 24 et tout affiche `Up`. À 23 h 26, le tableau de supervision est toujours au rouge : l'un des services est « en marche » mais répond `503` à tout, et le conteneur qui en dépendait redémarre en boucle, un peu plus tard à chaque fois. Personne ne sait si les conteneurs morts avec le code 137 ont eu le temps d'enregistrer ce qu'ils étaient en train d'écrire. Il reste quatre minutes, et la question est toujours la même : qu'est-ce qui tourne, qu'est-ce qui est en bonne santé, et qu'est-ce qui fait semblant ? Cette leçon existe pour que tu puisses y répondre en quelques secondes : un conteneur qui dit comment il va, qui meurt dans l'ordre quand on le lui demande et qui, tant qu'il vit, ne peut pas faire plus que ce dont il a besoin.

**Durée :** 2 × 45 min

**Ce que tu construis :** un conteneur qui dit comment il va et qui meurt proprement. L'image `curso-docker-revisor:1.4.0` embarque son propre contrôle de santé (health check, `HEALTHCHECK`), réalisé avec le même binaire et sans `curl`, et déclare son signal d'arrêt (`STOPSIGNAL`). Et le conteneur s'exécute durci (hardening) : système de fichiers en lecture seule, sans aucune capacité de `root`, sans pouvoir obtenir de nouveaux privilèges, avec un minuscule *init* comme processus numéro 1, avec des limites et avec une politique de redémarrage. Ces options sont celles que la Leçon 9 transpose dans Compose.

**Ce que tu apprends :** ce qu'est un signal, pourquoi le processus numéro 1 d'un conteneur est spécial et comment lire les codes `0`, `1`, `137` et `143` ; le délai de `docker stop` et comment le modifier ; ce que fait `--init` et ce qu'est un zombie ; `HEALTHCHECK` sans `curl` et la différence entre « en marche » et « en bonne santé » ; les quatre politiques de redémarrage et ce qu'elles **ne** font **pas** ; `--read-only` avec un `tmpfs` là où il le faut ; `--cap-drop ALL` ; et `no-new-privileges`, avec un programme *setuid* qui le démontre.

**D'où tu viens.** De la [Leçon 6](06-configuracion-y-secretos.md), tu apportes l'image `curso-docker-revisor:1.3.0` : multi-étape, 16,1 Mo, sans *shell*, avec l'utilisateur `65532`, sa version gravée et rien provenant d'un quelconque environnement. De la [Leçon 3](03-primer-dockerfile.md), tu apportes une mesure qui ne s'oublie pas : avec un `CMD` en forme *shell*, `docker stop` a mis plus de dix secondes et le conteneur est mort avec le code `137`, parce que le signal n'est jamais arrivé jusqu'au `revisor`. De la [Leçon 2](02-contenedores-dia-a-dia.md), tu apportes le `(health: starting)` que tu as vu sur le service de test sans savoir encore d'où il sortait, et l'habitude de fixer des limites de mémoire, de CPU et de processus. Et de la [Leçon 0](00-que-es-un-contenedor.md), tu apportes l'idée centrale : un conteneur est un processus de ton ordinateur, avec le même noyau, et le `root` de l'intérieur possède quatorze capacités que tu vas lui retirer aujourd'hui.

**Ce que cette leçon ne fait pas.** Elle n'explique pas les montages en profondeur : le `tmpfs` de la section 7.7 sert ici pour un seul dossier, et la [Leçon 8](08-volumenes-y-redes.md) explique en entier les volumes, les *bind mounts* et les `tmpfs`. Elle n'utilise pas la santé pour ordonner le démarrage de plusieurs services (`depends_on` avec `service_healthy`) : cela relève de la [Leçon 9](09-compose.md). Elle ne touche ni aux profils *seccomp* ni à AppArmor, ni à Docker sans `root` : ce sont des couches que Docker applique déjà par défaut ou qui exigent une autre installation, et ce cours s'en tient aux options que n'importe qui peut écrire dans un `docker run`. Et elle ne redémarre pas le daemon Docker pour comparer `unless-stopped` à `always` : cela arrêterait tous les conteneurs de l'ordinateur, et la différence s'explique avec la documentation.

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4, la même base que Linux Mint 22, le système de référence du cours, avec le noyau 6.8 et un processeur `arm64`. Les scripts ont été exécutés **à l'intérieur** de cette machine virtuelle, avec Docker 29.2.1 (client et daemon), et avec leur dossier de travail sur le disque propre de Linux. Pour éviter les collisions avec d'autres exécutions qui utilisaient la même machine, les scripts ont été lancés avec un autre préfixe de noms et d'autres ports (les variables `PREFIJO` et `PUERTO` qu'ils comportent) ; aucun nom de conteneur ni d'image, ni le port de l'ordinateur, n'apparaît dans leurs sorties, donc ce que tu vois est exactement ce qu'ils ont affiché. Avec leurs valeurs par défaut, les scripts utilisent des noms auxiliaires propres qui contiennent `fig07` (l'image `curso-docker-revisor:fig07`, le conteneur `curso-docker-revisor-fig07`) : ainsi, ils ne touchent jamais ton image `curso-docker-revisor:1.4.0` ni ton conteneur `curso-docker-revisor`, et en sortant ils suppriment uniquement ce qu'ils ont créé. Le cours a été planifié avec Docker Engine 29.8.2, et la version la plus récente publiée ce jour-là était la 29.9.2, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)) ; rien dans cette leçon ne change entre ces versions. Ce qui change **effectivement** d'une exécution à l'autre, et c'est signalé là où cela apparaît : les numéros de processus (masqués par `<pid>` dans le script lui-même ; les scripts qui les utilisent s'arrêtent si le conteneur ne tourne pas, parce qu'un numéro `0` désignerait des processus de ton ordinateur), les millisecondes de chaque `docker stop` et de chaque redémarrage, les secondes de `Up` et le numéro du fichier temporaire du rapport (masqué par `<n>`). La machine virtuelle était partagée avec d'autres travaux, et lors de certaines exécutions elle était chargée : c'est pourquoi certains temps sont ressortis plus longs que d'autres, et là où cela compte, on le dit. Les scripts publient sur les ports 8080 (`fig07_03.sh` et `fig07_06.sh`) et 9000 (`fig07_04.sh`) de ton ordinateur : si ton `curso-docker-revisor` ou ton `curso-docker-prueba` tournent, supprime-les avant, ou lance le script avec un autre port, par exemple `PUERTO=18080 ./fig07_03.sh` ; sinon, le script s'arrête avec `port is already allocated`. Un script, `fig07_05.sh`, utilise `sudo` une fois, pour tuer un processus depuis l'extérieur comme le ferait le noyau ; sur ton Mint, il te demandera ton mot de passe. Les programmes se trouvent dans [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida), chacun avec sa sortie à côté, et `estado/` conserve les fichiers du projet tels qu'ils sont à la fin.

## À la fin, tu seras capable de

- Lire le code de sortie d'un conteneur (`0`, `1`, `137`, `143`) et dire quel signal l'a terminé, ou s'il s'est terminé de lui-même.
- Expliquer pourquoi un programme qui meurt avec `SIGTERM` dans ton terminal ignore le même signal quand il est le processus numéro 1 d'un conteneur, et corriger cela avec `--init`.
- Mesurer combien de temps met `docker stop` et modifier son délai et son signal avec `-t`, `--stop-timeout`, `STOPSIGNAL` et `--stop-signal`.
- Écrire un `HEALTHCHECK` en forme *exec* pour une image sans *shell* ni `curl`, et lire la santé d'un conteneur avec `docker ps` et `docker inspect`.
- Choisir une politique de redémarrage pour un service et prédire ce que fait Docker quand le processus meurt de lui-même, quand tu l'arrêtes toi-même et quand il est `unhealthy`.
- Exécuter le `revisor` avec `--read-only`, `--cap-drop ALL` et `--security-opt no-new-privileges`, et vérifier dans `/proc` que le noyau applique bien les trois.

## Le pourquoi avant le comment

Jusqu'ici, tu as traité le conteneur comme quelque chose qui démarre. Cette leçon s'occupe de tout le reste : de la façon dont il **meurt**, de la façon dont il dit **s'il va bien** tant qu'il vit, et de **ce qu'il peut faire** pendant ce temps. Ce sont trois questions distinctes, et les trois sont apparues dans la scène du début.

La première est celle de l'arrêt. Un conteneur ne s'arrête pas comme une machine : Docker envoie un **signal** à son processus principal et attend. Si le processus prend en charge le signal, il termine ce qu'il était en train de faire et sort ; sinon, à l'expiration du délai, Docker le tue. Tu l'as déjà vu dans la Leçon 3 avec la forme *shell*. La nouveauté, c'est qu'il ne suffit pas d'écrire correctement le `CMD` : certains programmes, lorsqu'ils sont le processus numéro 1, ne reçoivent pas le signal même en forme *exec*, et la leçon t'en montre un, mesure ce que cela coûte et le corrige.

La deuxième est la santé. Pour Docker, un conteneur est `Up` tant que son processus existe. Il ne sait pas si ce processus répond, s'il répond correctement ou s'il est resté coincé à attendre quelque chose qui n'arrivera jamais. Le README du cours le pose comme l'un de ses deux critères : **un conteneur « en marche » n'est pas un service en bonne santé**. Un contrôle de santé (health check) est le moyen pour le conteneur de dire à Docker, de l'intérieur, la différence. Et l'image du `revisor` n'a ni `curl` ni *shell*, donc le contrôle doit venir d'ailleurs.

La troisième est le pouvoir. Un conteneur qui fonctionne bien peut quand même être la porte d'entrée d'une attaque : si quelqu'un trouve une faille dans le programme, il hérite de tout ce que le processus peut faire. Les leçons 3 et 5 lui ont déjà retiré `root` et le *shell*. Ici, on lui retire trois choses de plus : la possibilité d'écrire dans son propre système de fichiers, les capacités de `root` qu'il n'utilise pas et la possibilité d'obtenir de nouveaux privilèges en exécutant un autre programme.

Avec cette destination en tête, voici ce que tu verras à la section 7.10, quand les trois réponses se rejoindront. Le `revisor` s'exécute avec tout ce que contient la leçon, le noyau confirme qu'il n'a aucune capacité et qu'il ne peut pas obtenir de privilèges, et malgré tout il s'arrête dans l'ordre en quelques dixièmes de seconde :

```text
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
```

## Les concepts

### 7.1 Le processus numéro 1 et les signaux

#### 7.1.1 Ce qu'est un signal

Un **signal** est un court avertissement que le noyau de Linux remet à un processus. Il ne transporte aucune donnée : seulement un numéro, qui dit ce qui s'est passé ou ce qu'on demande. Quand tu appuies sur `Ctrl+C` dans le terminal, le noyau envoie au programme le signal `SIGINT` ; quand un administrateur écrit `kill <pid>`, il envoie `SIGTERM`. Le manuel de Linux les liste avec leur numéro et leur **action par défaut**, c'est-à-dire ce qui se passe si le programme n'a rien fait de spécial pour les prendre en charge ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)) :

| Signal | Numéro | Ce qu'il demande | Action par défaut |
|---|---|---|---|
| `SIGINT` | 2 | interruption depuis le clavier (`Ctrl+C`) | terminer |
| `SIGKILL` | 9 | mourir, tout de suite | terminer ; **ne peut être ni intercepté, ni bloqué, ni ignoré** |
| `SIGTERM` | 15 | terminer, s'il te plaît | terminer |

Un programme peut **installer un gestionnaire** (handler) pour un signal : une fonction qui s'exécute quand le signal arrive, à la place de l'action par défaut. C'est ce que fait le `revisor` : il demande au noyau de le prévenir de `SIGTERM` et de `SIGINT`, et quand l'un des deux arrive, il cesse d'accepter de nouvelles requêtes, attend jusqu'à cinq secondes que celles en cours se terminent et sort avec le code 0. C'est ce que tu vois depuis la Leçon 3 dans ses journaux : `recibí terminated, apagando` et `apagado limpio`. Pour `SIGKILL`, aucun gestionnaire n'est possible ; le manuel le dit en toutes lettres : « `SIGKILL` et `SIGSTOP` ne peuvent être ni interceptés, ni bloqués, ni ignorés ».

#### 7.1.2 Comment se lit la fin d'un conteneur

Quand un processus se termine, il laisse un **code de sortie**. S'il s'est terminé de lui-même, c'est le numéro que le programme a choisi : `0` pour « tout va bien », n'importe quel autre pour « quelque chose a échoué » (le `revisor` utilise `1` quand il lui manque de la configuration). S'il a été terminé par un signal, la convention des *shells*, que Docker suit, est **128 plus le numéro du signal**. De là viennent les deux numéros que tu verras le plus :

| Code | Comment se lit-il |
|---|---|
| `0` | terminé de lui-même et correctement ; avec le `revisor`, après un arrêt dans l'ordre |
| `1` | terminé de lui-même, avec une erreur du programme lui-même |
| `137` | 128 + 9 : tué par `SIGKILL` ; personne ne lui a rien demandé |
| `143` | 128 + 15 : terminé par `SIGTERM` avec l'action par défaut, sans gestionnaire |

Remarque la différence entre `0` et `143`. Les deux sont des arrêts demandés avec `SIGTERM` ; dans le premier cas, le programme a pris le signal en charge et est sorti de lui-même ; dans le second, le noyau l'a terminé parce que le programme n'avait pas de gestionnaire. Les deux sont raisonnables. Celui qui doit t'inquiéter, c'est `137` lors d'un arrêt normal : cela signifie que le délai est écoulé et que Docker a dû tuer le processus.

#### 7.1.3 Pourquoi le numéro 1 est spécial

Dans la Leçon 0, tu as vu qu'à l'intérieur d'un conteneur le programme principal est le processus numéro 1. Ce numéro a un traitement spécial sous Linux, que le manuel des espaces de noms de processus décrit ainsi : au processus « *init* » d'un espace de noms, on ne peut envoyer que les signaux **pour lesquels il a établi un gestionnaire** ; les autres ne lui font rien. Et il y a une exception : `SIGKILL` et `SIGSTOP` « sont remis de force quand ils viennent d'un espace de noms ancêtre » ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). La référence de `docker run` le résume en une phrase : un processus qui s'exécute en tant que PID 1 « ignore tout signal dont l'action est celle par défaut » ([référence de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).

Lis-le calmement, car c'est le cœur de cette section. Un programme qui **n'a pas** installé de gestionnaire pour `SIGTERM` meurt avec ce signal dans ton terminal, parce que l'action par défaut est de terminer. Le même programme, étant le numéro 1 d'un conteneur, ne meurt **pas** : l'action par défaut ne s'applique plus. Cette protection a du sens pour l'*init* d'une machine, qui ne devrait jamais mourir par accident ; dans un conteneur, l'*init* est ton programme, et cette protection devient un problème.

#### 7.1.4 Le mesurer avec un programme qui ne sait pas s'arrêter

Le `revisor` installe bien son gestionnaire, il ne permet donc pas de voir le problème. Pour le voir, il faut un programme qui ne l'installe pas, et il y en a un dans toutes les images Debian : `sleep`, qui se contente d'attendre le nombre de secondes demandé. Le script `fig07_02.sh` ne construit rien ; il utilise l'image Go que tu as déjà depuis la Leçon 3 :

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

Le script contient de nouvelles lignes. La fonction `detener` mesure combien de temps met `docker stop` et lit le code de sortie avec `docker inspect`, comme tu l'as fait dans la Leçon 3. Le `sed` qui suit `docker top` masque les numéros de processus avec `<pid>` et `<ppid>`, parce qu'ils changent à chaque exécution. Et le `grep` du bloc 1 lit un fichier qui n'appartient pas au conteneur mais au noyau : `/proc/<numéro>/status`, l'état d'un processus vu depuis ton ordinateur. `docker inspect --format '{{.State.Pid}}'` donne le numéro que ce processus a **sur ton ordinateur**, qui n'est pas 1 ; le 1 est le numéro qu'il a à l'intérieur.

Voyons maintenant les blocs 1 à 3 ; les autres se lisent en 7.3.

1. **`sleep` est le numéro 1 et ne prend rien en charge.** `docker top` montre un seul processus, `sleep 300`. La ligne `SigCgt` indique quels signaux le processus a **interceptés**, c'est-à-dire pour lesquels il a installé un gestionnaire, sous forme de masque de bits en hexadécimal : chaque bit à 1 est un signal. Tout à zéro : aucun. Et `docker stop` a mis **11 315 ms** et a laissé `ExitCode=137` (lors d'une exécution avec la machine moins chargée, 10 097 ms : le délai est de 10 000, et le reste, c'est Docker et la charge de l'ordinateur). La séquence est celle de la Leçon 3 : `SIGTERM` au numéro 1, qui l'ignore parce qu'il n'a pas de gestionnaire ; dix secondes d'attente ; `SIGKILL`, qui arrive de force.
2. **Le délai peut être modifié.** Avec `docker stop -t 2`, le même `sleep` est mort en **2 707 ms**, lui aussi avec `137` (2 124 lors de l'exécution la moins chargée). Le délai a changé ; la fin, non. Raccourcir le délai ne règle rien : cela ne fait que tuer plus tôt.
3. **En dehors du conteneur, le même programme meurt bien.** Le script lance `sleep 300` sur ton propre ordinateur, lui envoie `SIGTERM` avec `kill` et lit son code : `143`, soit 128 + 15. Même programme, même signal, aucun gestionnaire : sur ton ordinateur, `sleep` est un processus quelconque et l'action par défaut s'applique ; dans le conteneur, il était le numéro 1 et ce n'était pas le cas.

Compare ce bloc 1 avec la forme *shell* de la Leçon 3. Là, le numéro 1 était `/bin/sh` et le `revisor` se trouvait en dessous ; ici, il n'y a pas de *shell* au milieu, le `CMD` est en forme *exec* et pourtant la même chose se produit. La forme *exec* fait que Docker lance ton programme directement, sans *shell* au milieu, et c'est pourquoi il devient le numéro 1 ; elle **n**'assure **pas** que ton programme sache se comporter comme tel.

> [!NOTE]
> 🔧 **Observation de génie logiciel 7.1**
> Beaucoup de programmes n'installent pas de gestionnaires parce que, sur une machine normale, ils n'en ont pas besoin : l'action par défaut de `SIGTERM` suffit à les terminer. Scripts de *shell*, outils en ligne de commande, serveurs écrits à la va-vite. Quand tu les mets dans un conteneur comme numéro 1, chaque `docker stop` leur coûte le délai complet. Avant de décider quoi que ce soit, regarde la ligne `SigCgt` de ton processus : si le bit de `SIGTERM` (la valeur `4000` en hexadécimal) est à zéro, ce programme a besoin d'aide.

### 7.2 Le délai de `docker stop`, et qui décide du signal

#### 7.2.1 Ce que fait `docker stop`, pas à pas

La documentation le décrit ainsi : le processus principal du conteneur « reçoit `SIGTERM` et, après une période de grâce, `SIGKILL` ». Si le conteneur n'a pas d'autre signal configuré, c'est `SIGTERM` qui est utilisé. Le délai « est déterminé par le daemon » et il est de **10 secondes** pour les conteneurs Linux (30 pour ceux de Windows) ; avec `-t` ou `--timeout`, tu le modifies pour cet appel, et avec `-t -1`, Docker attend indéfiniment ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

Il y a trois endroits où l'on peut modifier le comportement, et il faut savoir lequel l'emporte :

| Où | Ce qui change | Portée |
|---|---|---|
| `STOPSIGNAL` dans le Dockerfile | le signal qu'envoie `docker stop` | tous les conteneurs de cette image |
| `docker run --stop-signal` | le signal, pour ce conteneur | l'emporte sur celui de l'image |
| `docker run --stop-timeout` | le délai, pour ce conteneur | reste enregistré dans le conteneur |
| `docker stop -t N` / `-s SIGNAL` | délai et signal, pour cet appel | l'emporte sur tout ce qui précède |

La référence du Dockerfile précise que `STOPSIGNAL` ne vaut que pour les signaux qu'envoie Docker (`docker stop` et le daemon lui-même) ; un `Ctrl+C` dans un terminal connecté au conteneur continue d'envoyer `SIGINT` directement au processus ([référence du Dockerfile](https://docs.docker.com/reference/dockerfile/)). Si tu ne passes ni `--stop-signal` à l'exécution ni `-s` à l'arrêt, Docker utilise le `STOPSIGNAL` de l'image, et si l'image n'en déclare aucun, `SIGTERM` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

Et il y a `docker kill`, qui n'attend pas : il envoie un signal, c'est tout. Sans `-s`, le signal est `SIGKILL` ([`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/)). Il sert quand quelque chose est bloqué et qu'il n'y a rien à sauver ; ce n'est pas la façon normale d'arrêter.

#### 7.2.2 `STOPSIGNAL` dans le `revisor`

Le Dockerfile de cette leçon déclare `STOPSIGNAL SIGTERM`. C'est le signal par défaut, donc cela ne change pas le comportement ; le commentaire du Dockerfile le dit : l'écrire documente l'intention. Celui qui lit l'image, ou qui l'inspecte avec `docker image inspect --format '{{.Config.StopSignal}}'`, sait quel signal le programme attend sans ouvrir son code. Certains programmes en attendent un autre (quelques serveurs web font un arrêt ordonné avec `SIGQUIT` et un arrêt brutal avec `SIGTERM`) ; là, `STOPSIGNAL` cesse d'être de la documentation et devient nécessaire.

#### 7.2.3 Pourquoi le `revisor` attend cinq secondes et non dix

Le code du `revisor` contient une constante, `PlazoApagado`, de cinq secondes : c'est le temps qu'il attend les requêtes en cours avant de renoncer. Son commentaire explique ce nombre : il est inférieur aux dix secondes de `docker stop` « pour que le processus se termine de lui-même et qu'on ne le tue pas ». C'est la règle qu'il convient de suivre avec n'importe quel service : **ton délai interne d'arrêt doit tenir dans le délai de celui qui t'arrête**. Si ton programme a besoin de vingt secondes pour vider une file, augmente le délai du conteneur avec `--stop-timeout 30` ; n'attends pas que Docker devine.

### 7.3 `--init` : un minuscule *init* pour le numéro 1

#### 7.3.1 Ce qu'il fait

Si le programme ne sait pas être le numéro 1, la solution propre est de ne pas le mettre en numéro 1. `docker run --init` démarre d'abord un petit programme, `docker-init`, qui devient le numéro 1 et démarre ton programme comme son enfant. La référence de `docker run` dit qu'un processus *init* garantit que « les responsabilités habituelles d'un système *init*, comme la récupération des processus zombies, soient remplies à l'intérieur du conteneur », et que ce `docker-init`, inclus dans l'installation normale, est fabriqué avec [tini](https://github.com/krallin/tini). Le projet tini lui-même se décrit comme un *init* minimal qui démarre un seul enfant et attend qu'il se termine, « en récupérant les zombies et en retransmettant les signaux pendant ce temps », et précise que depuis Docker 1.13 il est inclus dans Docker, sans rien installer dans l'image.

Ce sont deux tâches, et les blocs 4 à 6 de `fig07_02.sh` montrent les deux.

#### 7.3.2 La première tâche : retransmettre les signaux

Le bloc 4 exécute le même `sleep 300` avec `--init`. `docker top` montre maintenant deux processus : `/sbin/docker-init -- sleep 300` et, en dessous, `sleep 300`. Le numéro 1 est `docker-init`, qui, lui, a des gestionnaires pour les signaux ; quand `docker stop` lui envoie `SIGTERM`, il le retransmet à son enfant. Pour l'enfant, `SIGTERM` est un signal quelconque, parce qu'il n'est **pas** le numéro 1, donc l'action par défaut s'applique et il meurt. `docker-init` voit mourir son enfant et sort avec le même code. Résultat : **251 ms** au lieu de 11 315 (88 ms lors de l'exécution la moins chargée), et `ExitCode=143`, le même 128 + 15 que celui que tu as obtenu dans ton terminal au bloc 3. Sans changer une ligne du programme.

#### 7.3.3 La deuxième tâche : récupérer les zombies

Quand un processus se termine, il ne disparaît pas tout à fait : il reste une ligne dans la table des processus avec son code de sortie, en attendant que son parent la lise. Tant que personne ne la lit, ce processus est un **zombie** : il ne tourne pas, n'utilise pas de mémoire, mais occupe un numéro de processus. Si le parent meurt avant l'enfant, le noyau attribue à l'orphelin un nouveau parent : l'*init* de son espace de noms. Ainsi, à l'intérieur d'un conteneur, tous les orphelins finissent comme enfants du numéro 1, et le numéro 1 doit les récupérer.

Le bloc 5 le provoque. Le conteneur exécute `sh -c '(sleep 1 &); exec sleep 300'` : un *sous-shell* lance `sleep 1` en arrière-plan et s'en va, si bien que ce `sleep 1` devient orphelin et passe enfant du numéro 1 ; ensuite, `exec` remplace le *shell* par `sleep 300`, qui devient le numéro 1. Une seconde plus tard, l'orphelin se termine, et son nouveau parent, `sleep 300`, ne sait pas qu'il doit le récupérer. Regarde les deux vues du bloc :

- **`docker top` ne le montre pas.** Seul `sleep 300` apparaît. `docker top` interroge les processus qui appartiennent au groupe de contrôle du conteneur, et un processus déjà terminé sort de ce groupe même si sa ligne reste dans la table. C'est une mesure qui vaut la peine d'être retenue : si tu cherches des zombies, `docker top` n'est pas le bon outil.
- **`ps` sur ton ordinateur le montre.** Avec `--ppid`, tu demandes les enfants du numéro 1 du conteneur, et il apparaît `Z    [sleep] <defunct>` : état `Z`, pour zombie, et le mot `defunct`, défunt.

Le bloc 6 répète la même chose avec `--init`. Cette fois, l'orphelin est attribué à `docker-init`, qui sait récupérer ses enfants. Les enfants du numéro 1 sont uniquement le *shell* devenu `sleep 300` ; du zombie, aucune trace.

Un zombie ne fait pas de mal ; des milliers, si. Chacun occupe un numéro de processus, et dans la Leçon 2, tu as mis `--pids-limit 50` au conteneur. Un programme qui lance des processus auxiliaires sans les récupérer finit, avec le temps, par ne plus pouvoir en lancer aucun.

#### 7.3.4 Et le `revisor` ? Il en a moins besoin qu'il n'y paraît

Soyons précis, car il est facile d'exagérer ici. Le `revisor` installe son gestionnaire pour `SIGTERM` (tu le verras s'arrêter en moins d'une seconde sans `--init` à la section 7.4) et ne lance pas de processus enfants, donc il ne laisse pas de zombies. Aujourd'hui, il n'a **pas besoin** de `--init`. Le cours l'utilise quand même, pour deux raisons. La première : cela ne coûte presque rien (un tout petit processus de plus, et quatre lettres). La seconde : le jour où quelqu'un modifiera le programme, ou l'enveloppera dans un script de démarrage, ou lui ajoutera un outil qui lance des processus, l'image continuera de s'arrêter correctement sans que personne ait besoin de se souvenir de cette leçon. C'est une assurance bon marché, et c'est pourquoi elle figure parmi les options durcies que la Leçon 9 recopie dans Compose.

### 7.4 `HEALTHCHECK` sans `curl`

#### 7.4.1 L'instruction

`HEALTHCHECK` indique à Docker comment demander à un conteneur s'il va bien. Docker exécute cette commande **à l'intérieur** du conteneur à intervalles réguliers et regarde son code de sortie. La référence du Dockerfile définit trois valeurs : `0` est le succès (« le conteneur est en bonne santé et prêt à être utilisé »), `1` signifie « en mauvaise santé » et `2` est réservé : ne l'utilise pas. Les options, avec leurs valeurs par défaut d'après la même référence ([référence du Dockerfile](https://docs.docker.com/reference/dockerfile/)) :

| Option | Ce que c'est | Par défaut | Dans le `revisor` |
|---|---|---|---|
| `--interval` | tous les combien de temps on contrôle | `30s` | `10s` |
| `--timeout` | combien de temps un contrôle peut durer avant de compter comme un échec | `30s` | `3s` |
| `--start-period` | temps de démarrage : les échecs pendant cette période ne comptent pas | `0s` | `5s` |
| `--start-interval` | tous les combien de temps on contrôle **pendant** le temps de démarrage | `5s` | (celui par défaut) |
| `--retries` | combien d'échecs consécutifs il faut pour le déclarer en mauvaise santé | `3` | `3` |

Un Dockerfile ne peut avoir qu'**un seul** `HEALTHCHECK` ; si tu en écris plusieurs, c'est le dernier qui compte. `HEALTHCHECK NONE` désactive celui dont il hériterait de son image de base. Ce que la commande écrit dans sa sortie est conservé avec le résultat et se lit avec `docker inspect` ; seuls les 4 096 premiers octets sont conservés.

Avec ces options, le conteneur passe par trois états de santé : `starting` tant qu'il n'y a pas de réponse qui compte, `healthy` dès qu'un contrôle sort avec `0`, et `unhealthy` quand s'accumulent autant d'échecs consécutifs que l'indique `--retries`. Tout succès remet à zéro la série d'échecs.

#### 7.4.2 Le Dockerfile de cette leçon

C'est celui de la Leçon 6 avec deux nouvelles instructions à la fin :

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

Ce qui a changé :

1. **`HEALTHCHECK ... CMD ["/revisor", "healthcheck"]`.** Le contrôle est fait par le binaire lui-même : la sous-commande `healthcheck` du `revisor` interroge son propre processus avec `GET /salud` sur `127.0.0.1`, avec deux secondes de limite ; s'il répond `200`, elle affiche `sano` et sort avec `0` ; sinon, elle affiche `no sano: …` et sort avec `1`. Elle est en forme *exec*, avec des crochets, comme l'`ENTRYPOINT` : pour la même raison que dans la Leçon 3, et pour une de plus que tu vas voir dans un instant.
2. **Les durées.** `--interval=10s` parce que le `revisor` n'a pas besoin d'être surveillé toutes les cinq secondes, et que trente (la valeur par défaut) est trop long pour remarquer un problème. `--timeout=3s` laisse de la marge par rapport aux deux secondes que la sous-commande se donne elle-même. `--start-period=5s` lui laisse le temps de démarrer, et pendant ce temps Docker interroge toutes les cinq secondes (`--start-interval`), si bien que la première réponse arrive vite. `--retries=3` exige trois échecs consécutifs avant de le déclarer en mauvaise santé : un faux pas ne suffit pas.
3. **`STOPSIGNAL SIGTERM`**, que tu as vu en 7.2.2.

#### 7.4.3 Pourquoi pas `curl`

La façon la plus courante d'écrire un contrôle de santé, celle que tu trouveras dans presque tous les tutoriels, est `HEALTHCHECK CMD curl -f http://localhost:8080/salud || exit 1`. Elle pose deux problèmes dans l'image du `revisor`, et le script de cette section les provoque. Le premier est évident : l'image n'a pas de `curl`. Le second est plus subtil : cette ligne est en forme *shell*, et la forme *shell* a besoin de `/bin/sh`, qui n'est pas là non plus. Il en va de même pour `docker run --health-cmd`, qui est la façon de définir ou de modifier le contrôle à l'exécution : ce que tu écris là, Docker l'exécute avec le *shell*.

La solution facile serait d'ajouter `curl` à l'image. Ce n'est pas souhaitable : ce sont des mégaoctets d'un outil réseau, avec sa propre histoire de vulnérabilités, fourrés dans l'image que tu as dépouillée dans la Leçon 5 de tout ce qui n'était pas nécessaire, uniquement pour poser une question que le programme sait déjà poser. La bonne solution est celle qu'apporte le `revisor` : une sous-commande du même binaire. Zéro octet en plus, et le contrôle demande exactement ce que le programme sait de lui-même. Le service de test fait de même avec son `servicio-prueba healthcheck`, et c'est pourquoi, depuis la Leçon 2, il a une santé sans avoir `curl`.

#### 7.4.4 Le voir échouer et le voir fonctionner

Le script `fig07_03.sh` construit l'image, essaie d'abord de la surveiller avec `curl`, puis l'exécute avec son propre contrôle :

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

Ce qu'il y a de nouveau dans le script : `esperar_salud` interroge toutes les demi-secondes `.State.Health.Status` jusqu'à ce qu'il indique ce qu'on attend ; `estado` affiche la colonne `STATUS` de `docker ps` sans le nom ; et `bitacora_salud` parcourt `.State.Health.Log`, la liste des derniers contrôles que Docker conserve, avec le code et la sortie de chacun. Le `printf "%q"` écrit la sortie entre guillemets et avec les sauts de ligne sous la forme `\n`, pour que l'on voie exactement ce que la commande a affiché.

Bloc par bloc :

1. **L'image embarque son contrôle.** `docker image inspect` l'affiche en JSON : la commande en forme *exec* (`"CMD"` suivi de la liste) et les durées en nanosecondes (`10000000000` font dix secondes). Le signal d'arrêt est consigné : `StopSignal=SIGTERM`.
2. **Avec `curl`, `unhealthy`.** Le script a demandé un contrôle toutes les deux secondes et deux échecs pour abandonner, et au bout de 5 secondes le conteneur était déjà `(unhealthy)` : deux contrôles échoués, à 2 et à 4 secondes, plus le temps que prend chacun. Remarque `--health-start-period 1ms`. Une option `--health-*` à `0s` **ne désactive pas** le temps de démarrage : pour Docker, un zéro signifie « utilise la valeur de l'image », et le conteneur conserverait les 5 secondes de démarrage du Dockerfile. `1ms` est la façon de demander un démarrage quasi nul ; l'Exercice 2 te montre la différence mesurée. Le journal de santé dit pourquoi, et le code n'est pas `1` mais **`-1`** : Docker n'a même pas pu exécuter le contrôle. Le message est celui de la Leçon 2 quand tu as essayé `docker exec ... sh`, avec une autre formulation : `exec: "/bin/sh": stat /bin/sh: no such file or directory`. Et le plus important vient après : `docker exec ... /revisor healthcheck` répond `sano`. **Le service allait bien ; c'était le contrôle qui était cassé.** C'est l'erreur la plus traîtresse de cette leçon, parce que l'état `unhealthy` accuse le programme d'une chose qui est la faute de celui qui a écrit le contrôle.
3. **Avec le contrôle de l'image, `healthy` au bout de 5 secondes.** D'abord `(health: starting)`, puis `(healthy)`. Les cinq secondes correspondent au `--start-interval` : la première question est arrivée à la fin du premier intervalle de démarrage, et s'est bien passée. La référence du Dockerfile dit que le premier contrôle arrive après un `--interval`, qui serait ici de dix secondes ; mesuré avec Docker 29.2.1, pendant le démarrage Docker utilise `--start-interval`, et le premier est arrivé au bout de cinq. Quand la documentation et la mesure ne coïncident pas, la mesure l'emporte (tu le reverras en 7.6.3). Le journal a une entrée : code `0` et la sortie `sano\n`. La dernière ligne lit la même chose par morceaux : le processus est `running`, sa santé est `healthy` et la série d'échecs (`FailingStreak`) est `0`.
4. **L'arrêt.** Sans `--init`, le `revisor` est le numéro 1, mais cette fois il **a** un gestionnaire. `docker stop` a mis **657 ms** lors de cette exécution, avec la machine chargée (562 ms dans la Leçon 3, d'après sa sortie enregistrée), et le code est `0`, pas `143` : le programme n'est pas mort à cause du signal, il l'a pris en charge et est sorti de lui-même. Les journaux le racontent avec leurs propres mots (le `grep -v` écarte les `GET /salud` de chaque contrôle).

#### 7.4.5 Dans ton dossier

Ton projet vit dans `~/curso-docker/revisor` depuis la Leçon 3. Depuis la racine du dépôt du cours, place-y le Dockerfile de cette leçon et construis l'image que tu vas conserver :

```bash
cp programas/07-salud-y-ciclo-de-vida/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.4.0 -t curso-docker-revisor:1.4.0 .
docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0
```

La dernière commande doit afficher le même JSON que le bloc 1. Le `.dockerignore` et le dossier `secretos/` ne changent pas. `Dockerfile.malo`, celui de la Leçon 6, tu n'en as plus besoin ; tu peux l'enlever de ton dossier ou le laisser, car le `.dockerignore` l'empêche de voyager. L'image s'exécute en mode durci à la section 7.10, quand tu sauras ce que fait chaque option.

### 7.5 « En marche » ne veut pas dire en bonne santé

#### 7.5.1 Ce que fait Docker de la santé, et ce qu'il ne fait pas

Un contrôle de santé change **une étiquette** : celle que tu vois entre parenthèses dans `docker ps`. Rien de plus. Docker ne redémarre pas un conteneur `unhealthy`, ne lui coupe pas le trafic et ne prévient personne. L'information est là pour que quelqu'un l'utilise : toi, en regardant `docker ps` ; Compose, qui avec `depends_on` et `condition: service_healthy` attend qu'un service soit en bonne santé avant de démarrer le suivant (Leçon 9) ; un orchestrateur, qui peut remplacer le conteneur malade. Cette section le démontre avec le service de test, qui a une astuce que le `revisor` n'a pas : il change de mode sans redémarrer.

#### 7.5.2 Le service de test tombe malade

Le script `fig07_04.sh` construit une copie du service de test, le démarre avec `--restart always` (la politique la plus insistante, que tu verras en 7.6) et lui fait traverser ses trois modes :

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

Le service de test embarque son propre `HEALTHCHECK` depuis la Leçon 2 : toutes les 5 secondes, avec 2 nouvelles tentatives, et son contrôle exige un `200` en moins de 2 secondes. Avec cela :

1. **Il démarre en bonne santé**, au bout de 5 secondes.
2. **En mode « caído » (en panne), `unhealthy` au bout de 10 secondes.** Deux contrôles échoués, cinq secondes entre l'un et l'autre : ce sont les `--retries=2` multipliés par l'`--interval=5s` de son Dockerfile. Regarde maintenant la ligne de `resumen` : `running / unhealthy / racha=2 / reinicios=0`. Le processus **tourne** ; la santé dit qu'il **ne sert à rien** ; la série d'échecs est de 2 ; et personne ne l'a redémarré. Le dernier contrôle explique la cause avec le texte exact de son code : `1 no sano: GET / respondió 503`.
3. **Dix secondes plus tard, pareil.** La série est montée à 4 et les redémarrages restent à 0. Ni la santé ni `--restart always` n'ont rien fait. C'est ce qui se passait dans la scène du début : un conteneur `Up`, `unhealthy` et abandonné.
4. **De retour en bonne santé en 5 secondes**, sans rien redémarrer : un bon contrôle remet la série à 0 et la santé à `healthy`. La santé n'est pas un état qui se gagne une fois : elle se recalcule à chaque contrôle.
5. **En mode « lento » (lent), `unhealthy` aussi.** Et c'est là que se trouve la leçon la plus fine. Le service répond `200`, le code du « tout va bien », mais il met 3 secondes, et son contrôle n'en attend que 2 : `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, c'est la façon dont Go dit « le temps d'attente de la réponse est écoulé ». Le `curl` final le confirme : `200 en 3.01s`. Pour le contrôle, un service qui répond en retard est un service qui ne répond pas. C'est une décision de conception : celui qui écrit le contrôle décide de ce que signifie « en bonne santé », et ici cela signifie « répond correctement **et** à temps ».

#### 7.5.3 Ce que demande un bon contrôle

Un contrôle de santé répond à une seule question : **ce processus peut-il servir des requêtes ?** Pour le `revisor`, `/salud` répond que le serveur HTTP est vivant et à l'écoute, et rien de plus. Il ne contrôle pas les services que le `revisor` surveille : s'il le faisait, un service de test en panne mettrait le `revisor` en `unhealthy`, alors qu'il va parfaitement bien et fait son travail, qui est de signaler la panne. Il ne contrôle pas non plus s'il peut écrire son rapport, et en 7.7 tu verras ce que cela signifie. Un contrôle qui dépend d'autres services transforme la défaillance d'un seul en défaillance de tous ; c'est pourquoi il convient qu'il interroge le processus lui-même et qu'il soit peu coûteux : il sera exécuté toutes les dix secondes pendant toute la vie du conteneur.

### 7.6 Politiques de redémarrage

#### 7.6.1 Les quatre politiques

Une **politique de redémarrage** indique au daemon ce qu'il faut faire quand le processus d'un conteneur se termine. Elle se choisit avec `docker run --restart` et il y en a quatre, que la documentation décrit ainsi ([Docker, « Start containers automatically »](https://docs.docker.com/engine/containers/start-containers-automatically/)) :

| Politique | Ce qu'elle fait |
|---|---|
| `no` | ne redémarre jamais ; c'est celle par défaut |
| `on-failure[:maximum]` | redémarre si le processus sort avec un code différent de 0 ; avec `:maximum`, seulement ce nombre de fois. Ne redémarre pas le conteneur quand le daemon redémarre |
| `always` | redémarre chaque fois que le processus s'arrête. Si c'est toi qui l'as arrêté, il ne redémarre que lorsque le daemon Docker redémarre ou lorsque tu le démarres |
| `unless-stopped` | comme `always`, sauf que, si le conteneur était arrêté, il ne redémarre pas, même quand le daemon redémarre |

Deux autres détails de la documentation comptent. Un : si tu arrêtes un conteneur manuellement, sa politique est ignorée jusqu'à ce que le daemon redémarre ou que tu le redémarres ; il n'y a donc aucun moyen de te battre avec Docker pour arrêter quelque chose. Et deux : entre un redémarrage et le suivant, Docker attend de plus en plus longtemps : le double de la fois précédente, en commençant à 100 millisecondes et avec un plafond d'une minute ; si le conteneur parvient à rester en marche au moins 10 secondes, l'attente revient à 100 ms ([référence de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). Cela évite qu'un conteneur cassé redémarre mille fois par seconde.

#### 7.6.2 Mesurer ce que fait chacune

Le script `fig07_05.sh` construit le `revisor` et le fait mourir de plusieurs façons :

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

Ce qu'il y a de nouveau dans le script : `docker events` liste ce que le daemon a fait à un conteneur sur un intervalle de temps (ici, seulement les démarrages, `event=start`), et `{{.TimeNano}}` donne l'heure exacte de chacun en nanosecondes. Le `awk` soustrait chaque démarrage du précédent et le convertit en millisecondes. Et `sudo kill -KILL` envoie `SIGKILL` au processus du conteneur **depuis l'extérieur de Docker**, comme le ferait le noyau quand un processus dépasse sa limite de mémoire ; `sudo` est nécessaire parce que le processus appartient à l'utilisateur `65532`, pas au tien.

1. **`on-failure:3` avec un `revisor` sans configuration.** Il meurt avec `1` dès qu'il démarre. Docker l'a redémarré trois fois de plus puis a abandonné : `Status=exited ExitCode=1 RestartCount=3`. Les journaux en sont la preuve : le même message quatre fois, un par vie. Et les attentes sont celles de la documentation, plus le temps que met chaque démarrage : **181, 294 et 490 ms**, soit les 100, 200 et 400 de l'attente croissante, plus environ 80 à 90 ms de démarrage. Lors d'une exécution avec la machine chargée par d'autres travaux, on a obtenu 530, 1 483 et 2 399 ms : l'attente, c'est Docker qui la fixe, mais ce que dure chaque démarrage, c'est l'ordinateur qui le fixe. Le `revisor` n'avait pas de remède (il lui manque une variable), et c'est pourquoi un plafond est une bonne idée : trois tentatives suffisent pour savoir que ce n'est pas un faux pas.
2. **Sans politique, il reste mort.** `RestartCount=0`. C'est ce que tu veux pour quelque chose qui s'exécute une fois et se termine.
3. **`always` avec le `revisor` bien configuré.** Trois façons de mourir, trois résultats :
   - **Le noyau le tue.** Docker l'a redémarré : `Status=running RestartCount=1`. C'est pour cela que la politique existe. (`ExitCode=0` appartient au conteneur qui tourne maintenant ; il n'est pas encore terminé, donc il n'a pas de code propre.)
   - **Tu l'arrêtes avec `docker stop`.** Il reste arrêté, avec `ExitCode=0` parce qu'il s'est arrêté dans l'ordre. La politique respecte ta décision.
   - **Tu le tues avec `docker kill`.** Il reste aussi arrêté, cette fois avec `137`. Docker compte `docker kill` comme un arrêt manuel, tout comme `docker stop`, même si le processus meurt avec `SIGKILL`. Et remarque `RestartCount=0` : le compteur est revenu à zéro quand tu l'as démarré avec `docker start`.

#### 7.6.3 Une phrase de la documentation qu'il faut lire avec prudence

La page des politiques de redémarrage dit qu'une politique « ne prend effet qu'après le démarrage réussi d'un conteneur », et que cela signifie être en marche « au moins 10 secondes ». Le bloc 1 la contredit à première vue : le `revisor` sans configuration n'a pas tenu une seconde et Docker l'a redémarré trois fois. Ce que la mesure montre, c'est ce que dit la référence de `docker run` : les 10 secondes décident du moment où l'attente revient à 100 ms, pas de la décision de réessayer. Quand une documentation et ta mesure ne coïncident pas, la mesure l'emporte, et tu notes la version avec laquelle tu as mesuré : Docker 29.2.1.

#### 7.6.4 Laquelle choisir pour le `revisor`

`unless-stopped`. Le `revisor` est un service qui doit toujours être en marche, il a donc besoin qu'on le redémarre si le noyau le tue ou si l'ordinateur redémarre ; cela écarte `no` et `on-failure`, qui ne le relève pas après un redémarrage du daemon. Entre `always` et `unless-stopped`, la différence n'apparaît que quand le daemon redémarre, par exemple au redémarrage de l'ordinateur : avec `always`, un conteneur que tu avais arrêté exprès revient à la vie ; avec `unless-stopped`, on respecte le fait que tu l'as arrêté. Cela n'a pas été mesuré ici, parce que redémarrer le daemon arrête tous les conteneurs de l'ordinateur ; c'est dans le tableau de la documentation. Et rappelle-toi ce que tu as vu en 7.5 : aucune des quatre ne redémarre un conteneur parce qu'il est `unhealthy`. Une politique de redémarrage s'occupe de la mort du processus, pas de sa santé.

### 7.7 Système de fichiers en lecture seule

#### 7.7.1 Pourquoi

L'image est en lecture seule depuis toujours ; ce qui s'écrit à l'exécution va dans une nouvelle couche, propre au conteneur, que tu as vue dans la Leçon 4. `--read-only` ferme cette couche : le système de fichiers racine du conteneur est monté « en lecture seule » ([référence de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). Le programme peut toujours lire tout ce qu'apporte l'image, mais il ne peut créer, modifier ni supprimer aucun fichier.

Le gain est de sécurité et d'ordre. De sécurité, parce que celui qui parvient à prendre le contrôle du processus ne peut pas déposer un programme à lui sur le disque, ni modifier un fichier de configuration, ni remplacer le binaire. D'ordre, parce que cela t'oblige à savoir exactement **où ton programme écrit** : chaque chemin accessible en écriture devient une décision, et non un accident.

#### 7.7.2 Le provoquer et le corriger

Le script `fig07_06.sh` utilise l'option `REVISOR_REPORTE`, qui indique au `revisor` où enregistrer le dernier rapport. Le `revisor` l'écrit avec un fichier temporaire et un renommage dans le même dossier, pour que personne ne lise jamais un rapport à moitié écrit. Les blocs 1 et 2 relèvent de cette section ; le 3, de la 7.10 :

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

1. **Avec `--read-only`, `500`.** Le `revisor` a essayé de créer son fichier temporaire dans `/tmp` et le noyau a répondu `read-only file system`. Le `revisor` ne cache pas l'erreur : il renvoie `500` et la cause exacte. Le numéro du fichier temporaire change à chaque exécution, et le script le masque avec `<n>`. Et regarde la ligne suivante : **`/salud` continue de répondre `200`**. Le contrôle de santé dirait `healthy` alors que chaque requête vers `/api/estados` échoue. C'est ce qu'annonçait 7.5.3 : la santé dit si le processus sert des requêtes, pas si chaque fonction marche. C'est pourquoi, quand on durcit un conteneur, il ne suffit pas de voir qu'il démarre et qu'il est en bonne santé : il faut exercer ce qu'il fait.
2. **Avec `--tmpfs /tmp`, `200`.** Un **`tmpfs`** est un dossier qui vit dans la mémoire de l'ordinateur : selon la documentation, à la différence des volumes et des *bind mounts*, « il est temporaire et ne persiste que dans la mémoire de l'hôte », et quand le conteneur s'arrête, ce qui y a été écrit disparaît ([Docker, « tmpfs mounts »](https://docs.docker.com/engine/storage/tmpfs/)). C'est exactement ce dont a besoin un fichier temporaire. Le système de fichiers racine reste en lecture seule ; seul `/tmp` accepte l'écriture, et avec trois options : `noexec` empêche d'y exécuter des programmes (celui qui parvient à y écrire un fichier ne peut pas l'exécuter), `nosuid` fait que le bit *setuid* n'y a aucun effet (tu verras ce que c'est en 7.9) et `size=1m` lui impose un plafond d'un mégaoctet. Sans `size`, le noyau lui donne pour plafond la moitié de la mémoire de l'ordinateur, et ses permissions sont `1777`, accessible en écriture à tout le monde (la documentation donne ces valeurs pour `--mount type=tmpfs` ; avec `--tmpfs`, ce sont les mêmes, parce que c'est le noyau qui les fixe). De plus, la même page avertit que ce que tu y écris compte dans la limite de mémoire du conteneur : avec le `--memory 64m` de la Leçon 2, un `tmpfs` sans plafond pourrait amener le `revisor` à sa limite. La dernière ligne montre comment cela a été consigné.

Cette correction vaut pour cette leçon. Dans la Leçon 8, le rapport sera enregistré dans un volume, parce qu'il doit survivre au conteneur, et ce qui vit dans un `tmpfs` meurt avec lui.

### 7.8 Capacités retirées

#### 7.8.1 `root` découpé en morceaux

Dans la Leçon 0, tu as vu que Docker ne donne pas à `root` tout son pouvoir : il lui laisse quatorze **capacités**. Le manuel de Linux explique le concept : Linux « divise les privilèges traditionnellement associés au superutilisateur en unités distinctes », appelées capacités, qui peuvent être activées et désactivées séparément ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Quelques-unes de celles que Docker laisse par défaut, avec leur définition du manuel :

| Capacité | Ce qu'elle permet |
|---|---|
| `CAP_CHOWN` | changer à volonté l'utilisateur et le groupe propriétaires d'un fichier |
| `CAP_DAC_OVERRIDE` | contourner les contrôles de permissions de lecture, d'écriture et d'exécution des fichiers |
| `CAP_KILL` | contourner les contrôles de permissions pour envoyer des signaux |
| `CAP_SETUID` | changer à volonté l'utilisateur d'un processus |
| `CAP_NET_BIND_SERVICE` | écouter sur des ports inférieurs à 1024 |

Le `revisor` s'exécute en tant que `65532`, qui n'est pas `root`, donc en principe il n'en a aucune. Pourquoi alors les retirer ? Parce que la liste avec laquelle s'exécute un conteneur n'est pas seulement celle de son processus : c'est aussi le **plafond** de ce que n'importe quel processus de ce conteneur pourrait finir par avoir (le *bounding set* du manuel). Si quelqu'un trouve le moyen de devenir `root` à l'intérieur du conteneur, il hérite de ce plafond. Avec `--cap-drop ALL`, le plafond est zéro : même un `root` de l'intérieur n'en a aucune.

#### 7.8.2 Le voir avec un vrai `root`

Pour voir ce qui change, il faut un conteneur qui s'exécute en tant que `root` et qui dispose d'outils, et l'image Go a les deux. Le script `fig07_07.sh` ne construit rien et chaque conteneur se supprime tout seul :

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

La fonction `correr` assemble un `docker run --rm` avec les options que tu lui passes avant `--` et exécute la commande avec `sh -c`. Le test des trois premiers blocs est le même : afficher la ligne `CapEff` (les capacités **effectives**, celles que le processus peut utiliser à cet instant) et céder un fichier à l'utilisateur `10001` avec `chown`.

1. **`root` avec les valeurs par défaut.** `CapEff: 00000000a80425fb`, le même masque des quatorze que tu as décodé dans la Leçon 0. `chown` fonctionne.
2. **`root` avec `--cap-drop ALL`.** `CapEff` à zéro, et `chown` échoue avec `Operation not permitted`, code 1. C'est `root` (c'est toujours l'utilisateur 0), mais un `root` sans capacités ne peut pas faire ce qui rend `root` spécial.
3. **`--cap-drop ALL --cap-add CHOWN`.** Le masque vaut `1` : un seul bit, celui de `CAP_CHOWN`, qui est la capacité numéro 0. `chown` refonctionne. C'est le modèle pour un programme qui a réellement besoin d'une capacité : les retirer toutes et ne rendre que celle-là, nommément, à la vue de celui qui lira la commande.

#### 7.8.3 Les ports bas n'ont plus besoin de capacité

Le bloc 6 répond à un doute que tu vas avoir : si `CAP_NET_BIND_SERVICE` est celle qui permet d'écouter sur des ports inférieurs à 1024, un serveur web sur le port 80 doit-il la conserver ? Dans un conteneur Docker, non. L'utilisateur `10001`, **sans aucune capacité**, a ouvert le port 80. La première ligne explique pourquoi : à l'intérieur du conteneur, le paramètre du noyau `ip_unprivileged_port_start`, qui indique à partir de quel port un utilisateur sans privilèges peut écouter, vaut `0`. Docker le fixe ainsi par défaut depuis la version 20.10, dans chaque conteneur ayant son propre réseau ([moby/moby #41030](https://github.com/moby/moby/pull/41030)), et comme ce paramètre ne vaut que pour le réseau du conteneur, il ne change rien sur ton ordinateur. Le `revisor` écoute sur le 8080 et n'en a de toute façon pas besoin, mais tu sais ainsi que `--cap-drop ALL` ne t'oblige pas à changer un service de port.

### 7.9 `no-new-privileges`

#### 7.9.1 Le bit *setuid*

Sous Linux, un fichier exécutable peut avoir le bit ***setuid*** activé : celui qui l'exécute, quel qu'il soit, l'exécute **avec l'utilisateur propriétaire du fichier**. C'est ainsi que fonctionnent `passwd` ou `su`, qu'un utilisateur normal exécute et qui ont besoin d'être `root` un instant. Le manuel des capacités le dit pour le cas qui compte : un programme *setuid* de `root` obtient toutes les capacités, sauf celles que le plafond (*bounding set*) n'autorise pas ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). C'est une porte légitime pour élever ses privilèges, et c'est pourquoi c'est la favorite de celui qui tente de les élever sans autorisation.

`--security-opt no-new-privileges` ferme cette porte. Elle active dans le processus un marqueur du noyau, `no_new_privs`, que la documentation du noyau définit ainsi : avec lui, `execve` (exécuter un autre programme) promet de « ne pas accorder le privilège de faire quoi que ce soit qui n'aurait pas été possible sans cet appel » ; concrètement, « les bits *setuid* et *setgid* ne changent plus l'uid ni le gid », et les capacités d'un fichier ne s'ajoutent pas. Le marqueur est hérité par tous les enfants et **ne peut pas être désactivé** ([Linux, « No New Privileges Flag »](https://docs.kernel.org/userspace-api/no_new_privs.html)). La référence de `docker run` le dit en termes pratiques : avec cette option, « les commandes qui élèvent les privilèges, comme `su` ou `sudo`, ne fonctionnent plus ».

#### 7.9.2 Le voir

Les blocs 4 et 5 de `fig07_07.sh` font le test. En tant que `root`, le script copie le programme `id` vers `/tmp/id-suid` et lui active le bit *setuid* (le `s` de `-rwsr-xr-x`, propriétaire `root`). Ensuite, avec `setpriv`, un outil de Debian qui change d'utilisateur, il devient l'utilisateur `10001` et exécute `id` deux fois : la version normale et la copie *setuid*.

4. **Sans `no-new-privileges`.** Le `id` normal dit `uid=10001`. La copie dit `uid=10001 ... euid=0(root)` : l'utilisateur **effectif** est `root`. Un utilisateur quelconque a exécuté un fichier et, pendant qu'il tourne, il a les pouvoirs de `root`. `NoNewPrivs: 0`.
5. **Avec `no-new-privileges`.** Les deux disent `uid=10001` et rien de plus. Le bit est toujours là (`-rwsr-xr-x`), mais le noyau n'en tient plus compte. `NoNewPrivs: 1`.

Pourquoi est-ce important pour le `revisor`, qui n'a aucun programme *setuid* ? Pour la même raison que `--cap-drop ALL` : ce n'est pas pour ce qu'il y a aujourd'hui dans l'image, mais pour ce que quelqu'un pourrait y mettre ou y trouver demain. Et cela se combine avec ce qui précède : le `tmpfs` de `/tmp` porte `nosuid` et `noexec`, le système de fichiers racine est en lecture seule et le plafond de capacités est zéro. Pour élever ses privilèges, un attaquant devrait écrire un programme, l'exécuter et faire en sorte que le bit *setuid* compte ; chacune des trois options lui ferme une étape.

### 7.10 Tout ensemble : le `revisor` durci

#### 7.10.1 La commande

Voici les options avec lesquelles le `revisor` s'exécute désormais. La Leçon 9 les écrit dans le `compose.yaml` avec leurs équivalents YAML (`read_only: true`, `cap_drop: [ALL]`, `security_opt`, `init: true`), et non comme options de ligne de commande :

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' \
  curso-docker-revisor:1.4.0
```

Chaque ligne vient d'une leçon : le port sur `127.0.0.1` et les limites, de la 2 ; l'image sans `root` ni *shell*, de la 3 et de la 5 ; la configuration par `-e`, de la 6 ; et la deuxième ligne et la politique de redémarrage, de celle-ci. Il n'y a pas de `--tmpfs` parce qu'ici on ne lui demande pas d'enregistrer le rapport ; dans la Leçon 8, il aura un volume pour cela.

Ces options réduisent beaucoup ce qu'un intrus peut faire, mais elles ne remplacent rien d'autre : un programme qui a réellement besoin d'une capacité précise ou d'écrire à un endroit précis demande `--cap-add` ou un volume, un par un, et le reste de la défense (quel code s'exécute, ce qu'on y monte) reste ton travail.

#### 7.10.2 Le vérifier

Le bloc 3 de `fig07_06.sh` exécute exactement ces options et demande à chacun ce qui le concerne :

1. **La santé :** `(healthy)` au bout de 5 secondes, avec tout activé. Aucune des options n'a gêné le `revisor`.
2. **Ce que Docker a consigné :** `ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped`. C'est ce que tu as demandé, lu dans la configuration du conteneur.
3. **Les processus :** `docker-init` comme numéro 1 et `/revisor` comme son enfant, tous deux avec l'utilisateur `65532`.
4. **Ce que le noyau applique**, lu dans le `/proc` de l'enfant, qui est le `revisor` (le script le trouve avec `pgrep -P`, qui cherche les enfants d'un processus) : `CapEff` à zéro (il n'a pas de capacités), `CapBnd` à zéro (il ne pourrait même pas en gagner) et `NoNewPrivs: 1`. Des trois, `CapBnd` est celui qui démontre `--cap-drop ALL` : le `revisor` s'exécute en tant que `65532`, et son `CapEff` serait à zéro même si tu ne retirais rien ; le plafond, en revanche, serait celui des quatorze capacités. C'est plus que ce que dit Docker : c'est ce que le noyau fait respecter. Une option mal écrite pourrait être consignée sans être appliquée ; `/proc` ne ment pas.
5. **L'arrêt :** `docker stop` a mis **206 ms** et le code est `0`. `docker-init` a transmis le signal au `revisor`, le `revisor` l'a pris en charge et a pris congé dans ses journaux. Tout est durci, et il meurt aussi bien que sans rien.

Dans ton dossier, exécute la commande de 7.10.1, attends quelques secondes et vérifie avec `docker ps --filter name=curso-docker-revisor` qu'elle affiche `(healthy)`. Quand tu le vois `(healthy)`, supprime-le avec `docker rm -f curso-docker-revisor` **avant les exercices**, qui utilisent ce nom et ce port ; l'image `curso-docker-revisor:1.4.0` reste pour la Leçon 8.

### 7.11 Ce que tu trouveras dans les vieux tutoriels

- **`HEALTHCHECK CMD curl -f http://localhost/ || exit 1`.** Cela fonctionne dans les images qui embarquent un *shell* et `curl`, et cela oblige à mettre les deux dans celles où il ne faut pas. À la section 7.4.4, tu as vu comment cela échoue dans une image minimale : `unhealthy` avec un service en bonne santé. Si ton programme est un serveur, donne-lui une sous-commande de santé.
- **Installer `tini` ou `dumb-init` dans le Dockerfile** et le mettre dans l'`ENTRYPOINT`. C'était nécessaire avant que Docker n'embarque son propre *init* ; aujourd'hui `--init` fait la même chose sans toucher à l'image. Cela a encore du sens si l'image doit s'exécuter dans un endroit où tu ne peux pas demander `--init`.
- **Un script de démarrage qui se termine par `revisor` au lieu de `exec revisor`.** C'est la forme *shell* de la Leçon 3 cachée dans un fichier : le *shell* reste numéro 1 et le signal n'arrive pas.
- **`--restart always` partout, « pour que ça ne plante pas ».** Cela ne répare pas un programme cassé (il le redémarre en boucle, de plus en plus tard) et ne fait rien avec un programme malade qui continue de tourner. De plus, d'après la documentation, un conteneur avec `always` que tu as arrêté exprès revient à la vie au redémarrage du daemon.
- **`--privileged` pour « supprimer les problèmes de permissions ».** C'est le contraire de cette leçon : cela donne au conteneur toutes les capacités et l'accès aux périphériques de l'ordinateur. La référence de `docker run` explique que, par défaut, Docker retire les capacités les plus dangereuses, comme `CAP_SYS_ADMIN` ; `--privileged` les rend toutes. Si un programme a besoin d'une capacité, `--cap-add` avec son nom.

## L'erreur que tu vas voir

Cette leçon comporte une erreur principale et deux secondaires.

**L'erreur principale : le contrôle de santé qui ne peut pas s'exécuter.** C'est celle de `fig07_03.sh` :

```text
Up 4 seconds (unhealthy)
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
```

Voici comment la lire. `-1` n'est pas un code du programme : c'est Docker qui dit qu'il n'a même pas pu commencer le contrôle. `OCI runtime exec failed` dit qui a échoué, le composant qui exécute des processus à l'intérieur du conteneur. Et la fin dit ce qu'il a cherché sans le trouver : `/bin/sh`. Le contrôle était en forme *shell* (ou il a été passé avec `--health-cmd`, ce qui revient au même) et l'image n'a pas de *shell*. On le corrige avec un contrôle en forme *exec* qui appelle un programme que l'image possède bien : `HEALTHCHECK CMD ["/revisor", "healthcheck"]`. Si, à la place de `/bin/sh`, le message dit `curl`, l'image a un *shell* mais pas `curl` ; la correction est la même. Et avant d'accuser le programme, interroge-le toi-même : `docker exec <conteneur> /revisor healthcheck`. S'il répond `sano`, le problème est dans le contrôle, pas dans le service.

**La secondaire : lecture seule.** Celle de `fig07_06.sh` :

```text
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
```

`read-only file system`, c'est le noyau qui le dit : le conteneur s'exécute avec `--read-only` et le programme a essayé d'écrire. La question qui le résout est « où mon programme écrit-il, et pourquoi ? ». Si c'est quelque chose de temporaire, un `--tmpfs` sur ce dossier ; si cela doit durer, un volume (Leçon 8). Ce qui n'est pas une solution : retirer `--read-only`.

**Le code qui trahit un mauvais arrêt : `137` après `docker stop`.** Si `docker stop` met le délai complet et laisse `ExitCode=137`, le signal n'a pas servi au processus numéro 1 : soit il y a un *shell* au milieu (Leçon 3), soit c'est un programme qui n'a pas installé de gestionnaire (7.1.4). Regarde `docker top` pour savoir qui est le numéro 1 et `SigCgt` pour savoir ce qu'il prend en charge. Si tu ne peux pas modifier le programme, `--init`.

## L'habitude de sécurité de la leçon

**Le conteneur s'exécute avec le minimum : système de fichiers en lecture seule, zéro capacité et sans obtenir de privilèges, et l'on vérifie dans `/proc` que le noyau l'applique.** Ce sont trois options qui s'écrivent ensemble (`--read-only --cap-drop ALL --security-opt no-new-privileges`) et une vérification que l'on fait une fois par image. Chacune retire une étape à celui qui parvient à prendre le contrôle du processus par une faille du programme : il ne peut pas écrire sur le disque, il n'a aucun des pouvoirs découpés de `root` et il ne peut pas devenir `root` en exécutant un programme *setuid*. L'accident que cela évite n'est pas hypothétique : presque toutes les façons de passer de « je contrôle un processus » à « je contrôle la machine » exigent d'écrire quelque chose, d'utiliser une capacité ou de changer d'utilisateur vers le haut. Et la moitié que l'on oublie est la seconde : il ne suffit pas d'écrire les options, il faut voir `CapBnd: 0000000000000000` (le plafond : même un `root` de l'intérieur ne pourrait gagner aucune capacité) et `NoNewPrivs: 1`. `CapEff` à zéro ne suffit pas comme preuve : un utilisateur qui n'est pas `root`, comme le `65532` du `revisor`, l'a déjà à zéro sans `--cap-drop ALL`. Ce que tu ajoutes ensuite, tu l'ajoutes nommément : un dossier accessible en écriture avec `--tmpfs` ou un volume, une capacité avec `--cap-add`.

## Ce qui se fait de travers

**Raccourcir le délai de `docker stop` pour que « ça ne prenne pas autant de temps ».** Avec `-t 2`, un programme qui ne prend pas le signal en charge meurt en 2 secondes au lieu de 10, mais il meurt tout aussi mal : `137`, sans avoir terminé ce qu'il faisait. La solution est que le signal arrive (`--init`, forme *exec*, un gestionnaire), pas qu'on tue plus tôt.

**Un délai interne d'arrêt plus long que celui de Docker.** Si ton programme attend ses requêtes pendant 15 secondes et que Docker lui en laisse 10, l'arrêt ordonné ne se termine jamais. Ajuste l'un ou l'autre (`--stop-timeout`), mais fais en sorte que cela tienne.

**Confondre `Up` avec « ça marche ».** `docker ps` affiche `Up` tant que le processus existe. Si le conteneur n'a pas de `HEALTHCHECK`, personne ne demande s'il sert des requêtes.

**Un contrôle de santé qui dépend d'autres services.** Si la santé du `revisor` dépendait des services qu'il surveille, une panne extérieure le mettrait `unhealthy`, lui. Le contrôle interroge le processus lui-même.

**Un contrôle coûteux.** Il est exécuté toutes les quelques secondes pendant toute la vie du conteneur. Une requête complète à une base de données, ou un rapport entier, toutes les dix secondes, c'est une charge que personne n'a demandée.

**Attendre que `--restart` guérisse un conteneur `unhealthy`.** Aucune politique ne regarde la santé. Tu l'as vu en 7.5 : série de quatre échecs, zéro redémarrage.

**Retirer `--read-only` parce que « le programme a besoin d'écrire ».** Le programme a besoin d'écrire à **un** endroit. Donne-lui cet endroit, nommément.

**`--privileged` ou `--cap-add ALL` pour se dépanner.** Cela défait toute la leçon. Si quelque chose demande une capacité, trouve laquelle et ajoute seulement celle-là.

**Croire ce que dit `docker inspect` sans regarder `/proc`.** `docker inspect` montre ce que tu as demandé. `/proc/<pid>/status` montre ce que le noyau applique. Normalement, les deux coïncident ; quand ce n'est pas le cas, c'est le noyau qui commande.

## Exercices

Fais-les dans l'ordre. Avant d'exécuter chacun, écris dans ton [journal de bord](bitacora.md) ce que tu penses qu'il va se passer ; comparer ensuite représente la moitié de l'apprentissage. À la fin, supprime ce que tu as créé : tout porte le préfixe `curso-docker-`.

### Exercice 1 — Lis la fin

Sans rien exécuter, dis quel `ExitCode` laisse chaque conteneur et combien de temps mettrait à peu près `docker stop` quand cela s'applique. Utilise le tableau de 7.1.2.

1. Le `revisor` 1.4.0, qui tourne bien, arrêté avec `docker stop`.
2. L'image Go qui exécute `sleep 300`, sans `--init`, arrêtée avec `docker stop`.
3. La même, avec `--init`, arrêtée avec `docker stop`.
4. Le `revisor` 1.4.0 sans `REVISOR_SERVICIOS`, sans politique de redémarrage.
5. Le `revisor` 1.4.0 qui tourne bien, terminé avec `docker kill`.
6. Un conteneur `(unhealthy)` dont le journal de santé dit `-1 "OCI runtime exec failed: ..."`. Quel code a le **conteneur** ?

### Exercice 2 — Combien de temps met-il à tomber malade ?

Avec l'image `curso-docker-prueba:1.0.0` de la Leçon 2, prédis combien de temps met à passer en `unhealthy` un conteneur qui démarre en mode « caído » (en panne) avec ces options, et combien vaut sa série d'échecs à ce moment-là :

```bash
docker run -d --name curso-docker-prueba -e PRUEBA_MODO=caido \
  --health-interval 2s --health-retries 5 --health-start-period 1ms \
  curso-docker-prueba:1.0.0
```

Ensuite, mesure-le : interroge toutes les demi-secondes avec `docker inspect --format '{{.State.Health.Status}}' curso-docker-prueba` et compte les secondes depuis son démarrage. Les options `--health-*` de `docker run` remplacent celles de l'image pour ce conteneur. Supprime-le avec `docker rm -f curso-docker-prueba` et recommence avec `--health-start-period 0s`. Avant de l'exécuter, prédis : cela prend-il le même temps ? Indice : relis le point 2 de 7.4.4. À la fin, `docker rm -f curso-docker-prueba`.

### Exercice 3 — Un autre signal d'arrêt (projet)

Si le conteneur de 7.10 tourne encore, supprime-le d'abord avec `docker rm -f curso-docker-revisor`. Ensuite, exécute ton image avec un autre signal d'arrêt :

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --stop-signal SIGINT \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.4.0
```

Avant de l'arrêter, prédis trois choses : ce que dira son journal à l'arrêt (`docker logs curso-docker-revisor`), avec quel code il se terminera et quel signal affichera `docker inspect --format '{{.Config.StopSignal}}' curso-docker-revisor`. Ensuite, arrête-le avec `docker stop curso-docker-revisor`, mesure le temps avec `time` et compare. Indice : regarde quels signaux le `revisor` prend en charge en 7.1.1. Question supplémentaire : que se passerait-il avec `--stop-signal SIGHUP`, un signal que le code du `revisor` n'a pas demandé ? À la fin, `docker rm -f curso-docker-revisor`.

### Exercice 4 — Durcis le service de test

Exécute le service de test avec les options durcies de 7.10.1 (sans le port et sans `-e`, dont il n'a pas besoin) :

```bash
docker run -d --name curso-docker-prueba \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  curso-docker-prueba:1.0.0
```

Avant, prédis : atteindra-t-il `healthy` ? A-t-il besoin d'un `--tmpfs` ? Qui sera le numéro 1 et avec quel utilisateur ? Avec quel code se terminera-t-il à l'arrêt ? Ensuite, vérifie avec `docker ps --filter name=curso-docker-prueba`, `docker top curso-docker-prueba -o pid,user,args`, `docker stop curso-docker-prueba`, `docker inspect --format '{{.State.ExitCode}}' curso-docker-prueba` et `docker logs curso-docker-prueba`. À la fin, `docker rm -f curso-docker-prueba`.

## Solutions

Les solutions 2, 3 et 4 ont été mesurées avec deux scripts qui font la même chose que les exercices, avec des noms auxiliaires `fig07` et sans publier de ports : `fig07_08.sh` (service de test) et `fig07_09.sh` (`revisor`).

### Solution 1

1. **`0`**, en dixièmes de seconde : le `revisor` prend `SIGTERM` en charge et sort de lui-même (7.4.4).
2. **`137`**, en un peu plus de 10 secondes : `sleep` est le numéro 1, il n'a pas de gestionnaire, le signal est ignoré et `SIGKILL` arrive à la fin (7.1.4).
3. **`143`**, en dixièmes de seconde : `docker-init` retransmet le signal, `sleep` n'est plus le numéro 1 et meurt avec l'action par défaut de `SIGTERM`, 128 + 15 (7.3.2).
4. **`1`** : le `revisor` se termine de lui-même, avec son propre code d'erreur, sans que personne ne lui envoie quoi que ce soit. `docker stop` ne s'applique pas : il est déjà arrêté.
5. **`137`** : `docker kill` envoie `SIGKILL` sans attendre. Et, s'il avait la politique `always`, il ne redémarrerait pas, parce que cela compte comme un arrêt manuel (7.6.2).
6. **Aucun**, parce que le conteneur tourne toujours : `unhealthy` est une étiquette, pas une mort. Le `-1` est le code du **contrôle**, pas du conteneur. Son `.State.ExitCode` vaut `0` tant qu'il tourne.

### Solution 2

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

Avec `--health-start-period 1ms`, il est passé en `unhealthy` au bout de **10,9 secondes**, avec `racha=5`. Le calcul : 5 échecs avec 2 secondes entre les contrôles, 10 secondes, plus le temps que prend chaque contrôle (exécuter un processus à l'intérieur du conteneur n'est pas gratuit). La série vaut exactement ce que tu as demandé dans `--health-retries` : la santé change juste au 5e échec.

Avec `--health-start-period 0s`, il a mis **13,4 secondes**, et la ligne de `docker inspect` dit pourquoi : `StartPeriod=5s`. Un zéro dans une option `--health-*` de `docker run` ne désactive rien ; il signifie « utilise celui de l'image », et le Dockerfile du service de test dit `--start-period=5s`. Pendant ces 5 secondes, Docker interroge toutes les `--start-interval` (5 s), donc le premier contrôle est arrivé à 5 secondes, et les suivants toutes les 2 : à 5, 7, 9, 11 et 13. Le cinquième échec tombe à 13. Si ta prédiction était « environ dix secondes » pour le premier et « environ treize » pour le second, tu as compris le calcul et le piège. Les temps exacts changent d'une exécution à l'autre ; les séries, non.

### Solution 3

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

Avec `SIGINT` : `interrupt` est la façon dont Go nomme `SIGINT`, tout comme `terminated` est `SIGTERM`. Le `revisor` a installé un gestionnaire pour les deux, il s'arrête donc aussi bien avec l'un qu'avec l'autre : code `0`, en millisecondes. `--stop-signal` est consigné dans la configuration du conteneur (`StopSignal=SIGINT`) et l'emporte sur le `STOPSIGNAL SIGTERM` de l'image.

Question supplémentaire, avec `SIGHUP` : il est mort en millisecondes avec `ExitCode=129` (128 + 1), sans et avec `--init`, et son journal s'arrête à `escuchando`, sans `apagando` ni `apagado limpio`. Il n'a pas attendu les 10 secondes, bien que sans `--init` il soit le numéro 1, parce que tout programme Go embarque d'origine un gestionnaire pour ce signal : la documentation de Go dit que « `SIGHUP`, `SIGINT` ou `SIGTERM` font que le programme se termine » ([os/signal](https://pkg.go.dev/os/signal)). Il y a un gestionnaire, donc le signal arrive ; mais ce gestionnaire d'origine termine le programme d'un coup, sans l'arrêt ordonné que le `revisor` ne fait qu'avec `SIGTERM` et `SIGINT`. Que le code soit `129` aussi avec le `revisor` comme numéro 1 dépend de la façon dont le *runtime* de Go termine le programme ; c'est ce que Docker 29.2.1 a mesuré avec Go 1.27.3. La règle pratique ne change pas : le signal d'arrêt se choisit en regardant le code, et `STOPSIGNAL` le laisse écrit.

### Solution 4

C'est le dernier bloc de `fig07_08.sh`. Il atteint `healthy` sans `--tmpfs`, parce que le service de test n'écrit aucun fichier. Le numéro 1 est `docker-init` et son enfant est le service, tous deux avec `65532`, l'utilisateur que fixe son Dockerfile. Il s'arrête en dixièmes de seconde avec `0` : il prend `SIGTERM` en charge, comme le `revisor`. C'est la même ligne d'options que la Leçon 8 applique au service de test quand elle le place dans un réseau interne, et c'est pourquoi tu n'auras plus à y réfléchir là-bas.

## Comment je sais que j'ai réussi

Coche chaque point seulement si tu peux le faire **sans relire le texte** :

- [ ] Dans ton dossier, `docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0` affiche `["CMD","/revisor","healthcheck"]` avec un `Interval` de dix secondes.
- [ ] Tu expliques en une minute pourquoi `sleep 300` meurt avec `SIGTERM` dans ton terminal et pas comme numéro 1 d'un conteneur, en utilisant les mots *gestionnaire*, *action par défaut* et *numéro 1*.
- [ ] Tu mesures `docker stop` d'un `sleep` sans et avec `--init`, et tu obtiens un peu plus de 10 secondes avec `137`, et des dixièmes de seconde avec `143`.
- [ ] Tu vois un zombie avec `ps --ppid` sur ton ordinateur, et tu expliques pourquoi `docker top` ne le montre pas.
- [ ] Tu mets le service de test en mode « caído » et tu lis dans `docker inspect` `running / unhealthy`, la série d'échecs et la cause `GET / respondió 503`, avec zéro redémarrage.
- [ ] Tu dis ce que font `no`, `on-failure:3`, `always` et `unless-stopped` quand le processus meurt de lui-même, quand tu l'arrêtes avec `docker stop` et quand le daemon redémarre.
- [ ] Tu exécutes le `revisor` avec les options de 7.10.1, il atteint `(healthy)`, et dans `/proc/<pid du revisor>/status` tu lis `CapBnd: 0000000000000000` et `NoNewPrivs: 1` (et tu expliques pourquoi `CapEff` à zéro ne prouve rien avec un utilisateur qui n'est pas `root`).
- [ ] Tu provoques `read-only file system` avec `REVISOR_REPORTE=/tmp/reporte.json` et tu le corriges avec un `--tmpfs` de taille fixe, sans retirer `--read-only`.
- [ ] Tu exécutes les scripts de [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida) (avec un autre `PUERTO` si les tiens sont occupés) et tes sorties coïncident avec celles de cette leçon, sauf les millisecondes, les secondes de `Up` et des attentes, et les numéros masqués. Et à la fin, `docker ps -a --filter name=curso-docker-` n'affiche aucun conteneur de cette leçon.

## Résumé

Réponds sans regarder la leçon :

1. Qu'est-ce qu'un signal, et en quoi `SIGTERM` et `SIGKILL` diffèrent-ils ?
2. Comment se lit un `ExitCode` de `137` ? Et un de `143` ? Et un de `0` après `docker stop` ?
3. Pourquoi le processus numéro 1 d'un conteneur ne meurt-il pas avec `SIGTERM` s'il n'a pas installé de gestionnaire ?
4. Que fait `docker stop` pas à pas, et avec quelles options modifies-tu son délai et son signal ?
5. Quelles deux tâches accomplit `--init`, et pourquoi le cours l'utilise-t-il avec le `revisor` alors qu'il n'en a pas besoin aujourd'hui ?
6. Que signifient les codes `0`, `1` et `2` d'un contrôle de santé, et que signifie `-1` dans son journal ?
7. Pourquoi le contrôle du `revisor` est-il une sous-commande du même binaire et non `curl` ?
8. Que fait Docker d'un conteneur `unhealthy` ? Et une politique de redémarrage ?
9. En quoi `always` et `unless-stopped` diffèrent-ils ?
10. Que changent `--read-only`, `--cap-drop ALL` et `--security-opt no-new-privileges`, et où vérifies-tu que le noyau les applique ?

## Sources

Toutes consultées le 21 octobre 2026.

- [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html) : les signaux `SIGINT`, `SIGKILL` et `SIGTERM`, leurs numéros et leurs actions par défaut, et le fait que `SIGKILL` et `SIGSTOP` ne peuvent être ni interceptés, ni bloqués, ni ignorés.
- [pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html) : le processus *init* d'un espace de noms ne reçoit que les signaux pour lesquels il a un gestionnaire, sauf `SIGKILL` et `SIGSTOP` venant d'un espace ancêtre ; et les orphelins deviennent ses enfants.
- [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html) : ce que sont les capacités, les définitions de `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_KILL`, `CAP_SETUID` et `CAP_NET_BIND_SERVICE`, le plafond (*bounding set*) et ce que gagne un programme *setuid* de `root`.
- [Linux, « No New Privileges Flag »](https://docs.kernel.org/userspace-api/no_new_privs.html) : ce que fait `no_new_privs` avec `execve`, les bits *setuid* et *setgid*, et le fait qu'il est hérité et ne peut pas être désactivé.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/) : `SIGTERM` puis `SIGKILL`, le délai de 10 secondes sous Linux, `-t`, `-s` et `-t -1`.
- [`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/) : le fait qu'il envoie `SIGKILL` par défaut.
- [Référence de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/) : `--init` et `docker-init`, le PID 1 qui ignore les signaux à action par défaut, `--stop-signal`, `--stop-timeout`, `--read-only`, `--tmpfs`, `no-new-privileges`, les options `--health-*`, l'attente croissante entre les redémarrages et ce que Docker retire par défaut face à `--privileged`.
- [Référence du Dockerfile](https://docs.docker.com/reference/dockerfile/) : `HEALTHCHECK` (options, valeurs par défaut, codes 0, 1 et 2, un par Dockerfile, `NONE`, 4 096 octets de sortie) et `STOPSIGNAL`.
- [Docker, « Start containers automatically »](https://docs.docker.com/engine/containers/start-containers-automatically/) : les quatre politiques de redémarrage et l'arrêt manuel.
- [Docker, « tmpfs mounts »](https://docs.docker.com/engine/storage/tmpfs/) : le fait qu'un `tmpfs` vit en mémoire et disparaît avec le conteneur, sa taille maximale par défaut et sa permission `1777`.
- [tini](https://github.com/krallin/tini) : l'*init* minimal derrière `docker-init` : un seul enfant, récupérer les zombies et retransmettre les signaux.
- [os/signal](https://pkg.go.dev/os/signal) : le fait qu'un programme Go se termine par défaut avec `SIGHUP`, `SIGINT` ou `SIGTERM`.
- [moby/moby #41030](https://github.com/moby/moby/pull/41030) : le changement qui fixe `net.ipv4.ip_unprivileged_port_start=0` par défaut dans les conteneurs, depuis Docker 20.10.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions et les dates de « À propos des exécutions ».
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **capacité** (*capability*) | l'un des morceaux en lesquels Linux divise le pouvoir de `root` ; on les retire avec `--cap-drop` et on les ajoute avec `--cap-add` |
| **code de sortie** | le numéro avec lequel se termine un processus ; 128 + *n* s'il a été terminé par le signal *n* |
| **`HEALTHCHECK`** | instruction qui indique à Docker comment demander à un conteneur s'il est en bonne santé |
| ***init*** | le processus numéro 1 ; avec `--init`, un minuscule programme qui retransmet les signaux et récupère les zombies |
| **gestionnaire** (*handler*) | fonction qu'un programme installe pour prendre en charge un signal à la place de l'action par défaut |
| **`no-new-privileges`** | marqueur du noyau qui empêche un processus d'obtenir des privilèges en exécutant un autre programme |
| **délai** (de `docker stop`) | ce que Docker attend entre `SIGTERM` et `SIGKILL` ; 10 secondes par défaut |
| **politique de redémarrage** | ce que fait le daemon quand le processus d'un conteneur se termine |
| **signal** | court avertissement du noyau à un processus, identifié par un numéro |
| ***setuid*** | bit d'un exécutable qui le fait s'exécuter avec l'utilisateur propriétaire du fichier |
| **`tmpfs`** | dossier qui vit en mémoire et disparaît avec le conteneur |
| **zombie** | processus déjà terminé qui attend que son parent lise son code de sortie |

---

**Suivante :** [Leçon 8 — Volumes et réseaux](08-volumenes-y-redes.md)
