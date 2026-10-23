# Leçon 8 — Volumes et réseaux

Il est lundi, 9 h 05. À 10 h, il y a une réunion avec le service des opérations et on t'a demandé d'apporter le dernier rapport du `revisor` : quels services ont échoué pendant le week-end. Vendredi soir, quelqu'un a mis à jour le conteneur comme on le fait toujours : `docker rm -f`, `docker run` avec la nouvelle image, et retour à la maison. Tu ouvres le terminal, tu cherches le rapport, et il n'est pas là. Il n'est pas dans le nouveau conteneur, qui vient de naître, et l'ancien n'existe plus. Pendant que tu digères la nouvelle, tu remarques autre chose : le nouveau conteneur affiche `FALLA` pour le service de test, avec un message que tu n'avais jamais vu : `lookup curso-docker-prueba ... no such host`. Le service de test tourne, `docker ps` le montre, et `curl` l'atteint depuis ton ordinateur. Mais le `revisor` jure qu'il n'existe pas. Il est 9 h 12. Tu as deux problèmes qui semblent différents et qui sont la même question : **où vit ce qu'un conteneur doit conserver, et par où retrouve-t-il les autres ?** Cette leçon existe pour que tu puisses y répondre avant dix heures : le rapport est enregistré à un endroit qui survit au conteneur, avec le bon propriétaire, et les conteneurs se retrouvent par leur nom dans un réseau que tu définis, la partie qui n'a pas besoin d'internet étant enfermée dans un réseau sans sortie.

**Durée :** 2 × 45 min

**Ce que tu construis :** le rapport qui survit et deux conteneurs qui se parlent. L'image `curso-docker-revisor:1.5.0` apporte un dossier `/datos` qui appartient à l'utilisateur sans privilèges `65532` et y enregistre son rapport par défaut. Un volume nommé, `curso-docker-reportes`, est monté sur ce dossier et conserve le rapport même si tu supprimes le conteneur. Le service de test vit **uniquement** dans un réseau interne, `curso-docker-interna`, sans sortie vers internet ; le `revisor` vit dans un réseau que tu as défini, `curso-docker-red`, par où il expose son port, et il se connecte en plus au réseau interne pour vérifier le service de test par son nom.

**Ce que tu apprends :** où écrit un conteneur et pourquoi cela se perd ; les trois types de montage (volumes nommés, *bind mounts* et `tmpfs`) et quand utiliser chacun ; `-v` contre `--mount` ; qui est le propriétaire des fichiers quand le processus n'est pas `root`, et comment le corriger depuis l'image plutôt qu'avec `root` ; ce qui arrive au contenu d'un dossier quand tu montes quelque chose par-dessus (parfois il est copié, parfois il est masqué) ; le réseau par défaut et pourquoi il n'y a pas de noms ; les réseaux définis par l'utilisateur et leur DNS interne ; et les réseaux internes, sans sortie.

**D'où tu viens.** De la [Leçon 7](07-salud-y-ciclo-de-vida.md), tu apportes l'image `curso-docker-revisor:1.4.0`, avec son `HEALTHCHECK` et son `STOPSIGNAL`, et la façon de l'exécuter durcie : système de fichiers en lecture seule, sans capacités, sans élévation de privilèges, avec `--init` et avec des limites. Tu apportes aussi une promesse : dans la Leçon 7, le rapport était enregistré dans un `tmpfs`, qui meurt avec le conteneur, et il restait à lui trouver un endroit qui dure. De la [Leçon 6](06-configuracion-y-secretos.md), tu apportes le montage d'un fichier isolé (le token dans `/run/secrets/`), utilisé sans être expliqué en profondeur, et l'erreur de permissions avec l'utilisateur `65532` : aujourd'hui, cette même erreur revient, sur un dossier entier. De la [Leçon 2](02-contenedores-dia-a-dia.md), tu apportes l'image `curso-docker-prueba:1.0.0` et l'habitude de publier les ports uniquement sur `127.0.0.1`. Et de la [Leçon 3](03-primer-dockerfile.md), une phrase qui prend aujourd'hui tout son sens : le `revisor` se vérifiait lui-même « parce qu'il n'y a pas encore de réseau entre les conteneurs ».

**Ce que cette leçon ne fait pas.** Elle n'utilise pas Compose : tout se fait avec `docker volume`, `docker network` et `docker run`, pour que tu voies chaque pièce ; la [Leçon 9](09-compose.md) écrit la même chose dans un `compose.yaml`. Elle n'enseigne ni les pilotes de volumes distants (stockage en réseau, dans le cloud) ni les réseaux qui traversent plusieurs machines (*overlay*) : ce cours travaille sur un seul ordinateur, et ce que tu apprends ici (le propriétaire des fichiers, le DNS par nom, le réseau sans sortie) est aussi ce dont ces autres outils ont besoin. Elle n'utilise le réseau `host` que pour dire pourquoi on ne l'utilise pas. Et elle ne sauvegarde ni ne restaure les volumes avec des outils spéciaux : le rapport se lit avec un conteneur auxiliaire, qui est la façon de regarder à l'intérieur d'un volume et qui marche sur n'importe quel ordinateur.

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4, la même base que Linux Mint 22, le système de référence du cours, avec un noyau 6.8 et un processeur `arm64`. Les scripts ont été exécutés **à l'intérieur** de cette machine virtuelle, avec Docker 29.2.1 (client et daemon) et Buildx v0.31.1, et avec leur dossier de travail sur le disque propre de Linux. Cela compte beaucoup dans cette leçon, qui traite de propriétaires et de permissions : les dossiers partagés entre le Mac et la machine virtuelle mentent à ce sujet, et aucun exemple de propriétaire n'a été mesuré dans l'un de ces dossiers. Sur ton Mint, ce problème n'existe pas. Deux différences que tu verras de tes propres yeux : dans la machine virtuelle, l'utilisateur qui a exécuté les scripts est le `501`, avec le groupe `1000`, donc là où la sortie indique `501:1000`, ton Mint indiquera presque sûrement `1000:1000`, le premier utilisateur créé à l'installation ; et les dates des `ls -l` sont à l'heure de la machine virtuelle, qui est celle du méridien de Greenwich. Pour éviter les collisions avec d'autres exécutions qui utilisaient la même machine, les scripts ont été lancés avec un autre préfixe de noms et un autre port (les variables `PREFIJO` et `PUERTO` qu'ils comportent). Comme, dans cette leçon, les noms de réseaux, de volumes et de conteneurs apparaissent **bel et bien** dans les sorties (le DNS les utilise), les scripts qui affichent des noms comportent une fonction `nombres` qui, à la vue de tous, réécrit ce préfixe en `curso-docker-` ; avec le préfixe par défaut, rien ne change, donc ce que tu vois est ce que tu verras. Avec leurs valeurs par défaut, les scripts utilisent des noms auxiliaires propres qui contiennent `fig08` (l'image `curso-docker-revisor:fig08`, et `:fig08-l7`, la 1.4.0 que construit `fig08_02.sh` ; le conteneur `curso-docker-revisor-fig08`, le volume `curso-docker-reportes-fig08`, les réseaux `curso-docker-red-fig08` et `curso-docker-interna-fig08`) : ainsi, ils ne touchent jamais ton image `curso-docker-revisor:1.5.0`, ton conteneur `curso-docker-revisor`, ton volume `curso-docker-reportes` ni tes réseaux, et en sortant ils ne suppriment que ce qu'ils ont créé. Pour la même raison, ils publient leur port, par défaut, sur `127.0.0.1:8081`, et non sur le `8080` de ton `revisor` : tu peux donc les exécuter alors que ton état final est démarré (si tu as déjà le `8081` occupé, passe-leur-en un autre, par exemple `PUERTO=8082 ./fig08_03.sh` ; le port n'apparaît pas dans les sorties). Ils utilisent, sans les modifier, deux images que tu as déjà : `curso-docker-prueba:1.0.0`, de la Leçon 2, et `alpine:3.24.2`, un conteneur auxiliaire avec *shell* pour regarder les volumes et les réseaux, parce que les deux images du cours n'ont pas de *shell*. Le cours a été planifié avec Docker Engine 29.8.2, et la version la plus récente publiée ce jour-là était la 29.9.2, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)) ; rien dans cette leçon ne change entre ces versions. Ce qui change **effectivement** d'une exécution à l'autre, et c'est signalé là où cela apparaît : les durées du tableau du `revisor` (masquées par `<t>`), le numéro du fichier temporaire du rapport (masqué par `<n>`), les adresses IP des conteneurs et celle du DNS de ton ordinateur (masquées par `<IP>` et `<DNS del anfitrión>`), les identifiants de conteneur (`<id>`) et les dates. Tout est masqué dans le script lui-même, à la vue de tous, jamais en retouchant la sortie. Les programmes se trouvent dans [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes), chacun avec sa sortie à côté, et `estado/` conserve les fichiers du projet tels qu'ils sont à la fin.

## À la fin, tu seras capable de

- Expliquer pourquoi ce qu'un conteneur écrit dans son propre système de fichiers se perd avec `docker rm`, et choisir entre un volume nommé, un *bind mount* et un `tmpfs` pour chaque donnée du `revisor`.
- Provoquer et diagnostiquer le `permission denied` d'un nouveau volume avec un processus sans privilèges, et le corriger dans l'image avec `COPY --chown`, sans exécuter en tant que `root`.
- Démontrer que le rapport survit à `docker rm` en le lisant depuis un conteneur auxiliaire.
- Prédire ce qui arrive au contenu d'un dossier quand tu montes par-dessus un nouveau volume, un volume contenant des données ou un *bind mount*, et expliquer la différence entre `-v` et `--mount` quand le dossier de l'ordinateur n'existe pas.
- Exécuter le `revisor` avec un *bind mount* d'un dossier à toi, en corrigeant le propriétaire avec `--user`, et monter en lecture seule ce que le conteneur ne doit pas modifier.
- Montrer que, dans le réseau par défaut, un conteneur ne trouve pas un autre par son nom, et que dans un réseau défini par l'utilisateur il le trouve, en lisant quel serveur DNS utilise chacun.
- Enfermer le service de test dans un réseau interne sans sortie vers internet et connecter le `revisor` aux deux réseaux, sans le redémarrer.

## Le pourquoi avant le comment

Jusqu'ici, chaque conteneur du cours a été une île jetable. Tu le créais, tu lui posais une question, tu le supprimais. C'était bien pour apprendre, parce qu'un conteneur jetable ne peut pas garder de surprises. Mais un vrai service a deux besoins qu'une île ne couvre pas.

Le premier est de **conserver quelque chose qui dure plus longtemps que lui**. Le `revisor` écrit un rapport ; ce rapport est exactement ce que quelqu'un va demander le lundi. Or un conteneur est fait pour être remplacé : chaque mise à jour, chaque changement de configuration, chaque redémarrage de la machine avec `--rm` aboutit à un nouveau conteneur. La documentation de Docker le dit sans détour : ce qui est écrit dans la couche du conteneur « ne persiste pas quand le conteneur est détruit », et en outre « il peut être difficile d'extraire les données du conteneur si un autre processus en a besoin » ([Docker, « Storage »](https://docs.docker.com/engine/storage/)). Si le rapport vit à l'intérieur du conteneur, il vit aussi longtemps que le conteneur. Et depuis la Leçon 7, le problème est encore plus direct : le système de fichiers du `revisor` est en **lecture seule**. Ce n'est pas que le rapport va se perdre ; c'est qu'on ne peut même pas l'écrire. Il faut un endroit accessible en écriture, hors du conteneur, que le `revisor` puisse utiliser sans cesser d'être en lecture seule.

Le second est de **parler à d'autres conteneurs**. Le `revisor` existe pour vérifier des services, et jusqu'à aujourd'hui il n'a vérifié que lui-même (`propio http://127.0.0.1:8080/salud`), parce que, à l'intérieur d'un conteneur, `127.0.0.1` est le conteneur lui-même. Pour vérifier le service de test, il doit atteindre un autre conteneur. Il pourrait utiliser son adresse IP, mais les adresses sont distribuées par Docker au démarrage et changent ; personne ne veut écrire dans `REVISOR_SERVICIOS` une adresse qui cesse d'être valable au redémarrage suivant. Ce que tu veux, c'est ce que fait n'importe quel programme sur internet : utiliser un **nom**. Et dès que les conteneurs se parlent, la question de sécurité de la leçon apparaît : si le service de test n'existe que pour que le `revisor` le consulte, pourquoi devrait-il pouvoir sortir sur internet ?

La leçon a donc deux moitiés, et toutes deux suivent le même chemin : d'abord l'erreur, ensuite la correction.

1. **Stockage** (8.1 à 8.7) : où écrit un conteneur, les trois types de montage, l'erreur de propriétaire que tu vas rencontrer avec un utilisateur sans privilèges et sa correction dans l'image, ce qui arrive à ce qui se trouvait déjà dans le dossier, et le `tmpfs` pour ce qui ne doit pas durer.
2. **Réseaux** (8.8 à 8.11) : le réseau par défaut, qui n'a pas de noms ; le réseau que tu définis, qui en a ; et le réseau interne, qui n'a pas de sortie.

Avec cette destination en tête, voici ce que tu auras à la fin, à la section 8.10 : le service de test dans un réseau sans sortie, le `revisor` dans les deux, le trouvant par son nom, et un conteneur qui tente de sortir sur internet depuis le réseau interne et ne parvient même pas à résoudre le nom du site :

```text
== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
```

## Les concepts

### 8.1 Où écrit un conteneur

#### 8.1.1 La couche accessible en écriture, et pourquoi elle ne sert pas à conserver

Dans la Leçon 4, tu as vu qu'une image est une pile de couches en lecture seule. Quand Docker crée un conteneur, il pose par-dessus **une couche de plus, accessible en écriture et propre à ce conteneur**. Tout ce que le processus écrit (un nouveau fichier, un fichier modifié, un fichier supprimé) reste dans cette couche ; celles de l'image ne sont pas touchées, et c'est pourquoi cent conteneurs peuvent sortir de la même image sans se marcher dessus.

Cette couche pose trois problèmes pour conserver un rapport :

- **Elle meurt avec le conteneur.** `docker rm` la supprime. `docker run --rm` la supprime à la sortie. Une mise à jour qui remplace le conteneur la jette.
- **Il est difficile d'en extraire quelque chose.** Elle se trouve quelque part dans le stockage interne de Docker, avec un chemin qui n'est pas fait pour toi. Un autre conteneur ne peut pas la lire.
- **Dans le `revisor` durci, elle n'existe pas pour écrire.** Avec `--read-only`, la couche accessible en écriture n'accepte aucune écriture. C'est exactement ce que tu voulais dans la Leçon 7 : celui qui prend le contrôle du processus ne peut rien écrire sur le disque. Mais le `revisor` lui-même non plus.

La solution est de **monter** quelque chose par-dessus un dossier du conteneur : un endroit accessible en écriture qui ne fait pas partie de la couche du conteneur, qui a son propre cycle de vie et qui n'est monté qu'où il le faut. Le reste du système de fichiers reste en lecture seule.

#### 8.1.2 Les trois types de montage

Docker propose trois types de montage qui t'intéressent ici (il y en a deux autres que tu n'utiliseras pas : les tubes nommés, réservés à Windows, et les montages d'image, qui placent le contenu d'une autre image dans le conteneur et exigent le magasin d'images de containerd). La documentation les présente ainsi ([Docker, « Storage »](https://docs.docker.com/engine/storage/)) :

| Type | Ce que c'est | Où vivent les données | Combien de temps elles durent | À quoi ça sert |
|---|---|---|---|---|
| **Volume** (nommé) | stockage « géré par le daemon de Docker » | dans un dossier du magasin de Docker, que tu ne touches pas | jusqu'à ce que tu supprimes le volume, même si tu supprimes tous les conteneurs | données du service qui doivent durer : le rapport |
| ***Bind mount*** | « un lien direct » entre un chemin de l'ordinateur et un chemin du conteneur | dans un dossier à toi, où tu le décides | aussi longtemps que dure ce dossier | fichiers que toi et le conteneur devez voir : du code en développement, un fichier de configuration, le token de la Leçon 6 |
| **`tmpfs`** | fichiers « directement en mémoire » de l'ordinateur | en mémoire | jusqu'à ce que le conteneur s'arrête | temporaires qui ne doivent ni durer ni toucher le disque |

La même page donne la recommandation courte : les volumes pour le stockage à long terme ; les *bind mounts*, « quand tu as besoin d'accéder aux fichiers à la fois depuis le conteneur et depuis l'ordinateur » ; et les `tmpfs`, « seulement quand les données n'ont pas besoin de persister au-delà de la session du conteneur ». Dans le `revisor`, cela se traduit par une règle simple : **le rapport va dans un volume**. Les *bind mounts*, tu les as déjà utilisés pour le token et tu vas les utiliser aujourd'hui pour comprendre le problème des propriétaires ; le `tmpfs`, pour ce qui ne doit pas survivre.

#### 8.1.3 Deux façons d'écrire la même chose : `-v` et `--mount`

Docker accepte deux syntaxes pour monter, et tu les verras partout :

- **`-v origen:destino[:opciones]`** (ou `--volume`). Courte. Si l'origine est un nom (`curso-docker-reportes`), c'est un volume ; si c'est un chemin absolu (`/home/tu/reportes`), c'est un *bind mount*. Les options vont à la fin, séparées par des virgules : `ro` pour la lecture seule, par exemple.
- **`--mount type=…,src=…,dst=…[,opciones]`**. Longue, avec des noms pour chaque champ : `type=volume`, `type=bind` ou `type=tmpfs`, puis `src` (l'origine), `dst` (la destination), `readonly`, et les options propres à chaque type.

La documentation des volumes dit qu'« en général, `--mount` est préférable », parce qu'il « est plus explicite et prend en charge toutes les options disponibles » ([Docker, « Volumes »](https://docs.docker.com/engine/storage/volumes/)). `--mount` prend en charge toutes les options de chaque type de montage ; `-v` seulement quelques-unes. Pour un volume, `-v` en admet peu : celles d'accès (`ro` et `rw`), celles d'étiquetage SELinux (`z` et `Z`, dont tu n'as pas besoin sur Mint) et celle de ne pas copier le contenu de l'image, que tu verras en 8.5. Cette seconde option comporte un piège mesuré : la page des volumes l'appelle `volume-nocopy` aussi avec `-v`, mais Docker 29.2.1 rejette ce nom avec `invalid mode: volume-nocopy` ; avec `-v` on écrit `nocopy` (`-v vol:/datos:nocopy`), et avec `--mount`, `volume-nocopy`. Tu le vois dans `fig08_09.sh`, la solution de l'Exercice 4. Et il y a une différence de comportement qui compte : quand le dossier de l'ordinateur **n'existe pas**, `-v` le crée et `--mount`, par défaut, refuse (8.5). Ce cours utilise `-v` pour les volumes nommés, parce que c'est ce que tu liras dans la plupart des exemples et que c'est tout aussi clair (`-v curso-docker-reportes:/datos` ne laisse aucun doute), et `--mount` pour les *bind mounts* et les `tmpfs`, où sa précision évite des erreurs.

### 8.2 Volumes nommés

#### 8.2.1 Créer, regarder, supprimer

Un volume se crée avec `docker volume create <nom>`, se liste avec `docker volume ls`, se regarde avec `docker volume inspect` et se supprime avec `docker volume rm`. Si tu montes dans un `docker run` un volume qui n'existe pas, Docker le crée à ce moment-là ; malgré tout, le créer avant avec son nom montre clairement que c'est quelque chose que tu as décidé d'avoir, et non un effet de bord.

Les volumes du pilote par défaut, `local`, vivent dans un dossier de l'ordinateur à l'intérieur du magasin de Docker : la documentation montre le chemin `/var/lib/docker/volumes/<nom>/_data` ([Docker, « Volumes »](https://docs.docker.com/engine/storage/volumes/)). Ce dossier appartient à Docker et à `root`. Tu peux le voir avec `sudo`, mais il n'est pas fait pour être touché manuellement : pour regarder à l'intérieur d'un volume, le cours utilise un **conteneur auxiliaire**, un `alpine` jetable qui monte le volume en lecture seule et exécute `ls` ou `cat`. Cela fonctionne de la même façon sur Mint, sur un Mac ou sur un serveur, n'a pas besoin de `sudo` et ne peut en aucun cas abîmer les données.

Un volume **n'est pas supprimé** avec le conteneur. C'est sa raison d'être. Ni `docker rm`, ni `docker rm -f`, ni `docker stop` n'y touchent. La seule exception concerne les volumes **anonymes** (ceux qui se créent sans nom, par exemple avec `-v /datos` sans origine) : la documentation dit que ceux-là ne sont détruits avec le conteneur que si tu l'as créé avec `--rm` ([Docker, « Volumes »](https://docs.docker.com/engine/storage/volumes/)). Un volume nommé vit jusqu'à ce que tu le supprimes avec `docker volume rm`. C'est pourquoi le cours leur donne toujours un nom, avec le préfixe `curso-docker-` : un volume anonyme est un identifiant de 64 caractères dont personne ne se rappelle à qui il appartient, et qui finit par occuper du disque pour toujours.

### 8.3 L'erreur : un nouveau volume sur un dossier que l'image n'apporte pas

#### 8.3.1 La provoquer

Avec ce qui précède, le plan semble évident : créer un volume, le monter sur `/datos`, dire au `revisor` d'y enregistrer son rapport avec `REVISOR_REPORTE=/datos/reporte.json`. Le script `fig08_02.sh` fait exactement cela avec l'image de la Leçon 7, durcie comme tu l'as laissée :

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

Les nouvelles lignes du script, avant de lire la sortie. `docker create` crée un conteneur sans le démarrer, et `docker export` extrait son système de fichiers complet sous forme d'archive `tar` ; `tar -tv` le liste sans le décompresser, et `--numeric-owner` affiche les propriétaires sous forme de nombres. C'est la façon de regarder **quels dossiers apporte une image** qui n'a pas de *shell* pour exécuter `ls`. `docker volume inspect` montre ce que Docker sait d'un volume. Et `-v "$VOLUMEN":/datos:ro` dans l'auxiliaire monte le volume en lecture seule : l'auxiliaire ne fait que regarder.

Maintenant la sortie, bloc par bloc :

1. **L'image de la Leçon 7 n'apporte pas `/datos`.** Le décompte des lignes du `tar` qui se terminent par ` datos/` est `0`. Personne ne l'a créé : dans la Leçon 7, le rapport allait dans `/tmp`.
2. **Le volume est nouveau et vide.** Son pilote est `local` et il vit dans `/var/lib/docker/volumes/curso-docker-reportes-fig08/_data`, le chemin indiqué par la documentation.
3. **Le `revisor` démarre, répond à `/salud` et échoue à l'enregistrement.** `/api/estados` répond `500` avec `permission denied` à l'ouverture du fichier temporaire du rapport. (Rappelle-toi, de la Leçon 3, que le `revisor` écrit d'abord un fichier temporaire dans le même dossier puis le renomme : c'est pourquoi l'erreur mentionne `.reporte-<n>.tmp` et non `reporte.json`.) `/salud` reste à `200`, parce qu'il n'écrit rien ; et comme le `HEALTHCHECK` utilise `/salud`, Docker dirait que ce conteneur est `healthy`. En marche, sain pour Docker, et incapable de faire son travail : le deuxième principe du cours, encore une fois.
4. **Le dossier appartient à `root`.** L'auxiliaire montre `/datos` avec le propriétaire `0` et le groupe `0`, permissions `drwxr-xr-x` : seul le propriétaire écrit. Et le `revisor` s'exécute en tant que `65532:65532`.

#### 8.3.2 Pourquoi cela arrive

Quand tu montes un volume sur un chemin que l'image n'apporte pas, Docker doit créer ce point de montage, et le nouveau volume naît avec un dossier racine qui appartient à `root`. Personne ne lui a dit autre chose. Tant que le processus du conteneur était `root` (comme dans tant de tutoriels), cela ne se remarquait pas : `root` écrit où il veut. Mais le `revisor` a cessé d'être `root` dans la Leçon 3, et un utilisateur sans privilèges ne contourne les permissions de personne. Le noyau fait donc ce qu'il ferait avec n'importe quel utilisateur de ton ordinateur qui tente d'écrire dans un dossier qui n'est pas à lui : il refuse.

C'est la même erreur que dans la Leçon 6 avec le fichier du token, sous une autre forme. Là-bas, le fichier était à toi et le processus, `65532` ; ici, le dossier est à `root` et le processus, `65532`. La question qui la résout est la même : **qui est le propriétaire, et avec quel utilisateur s'exécute le processus ?**

Il y a trois corrections que tu verras sur internet, et une seule est bonne :

- **Exécuter en tant que `root`** (`--user 0`). Cela marche et défait le travail de cinq leçons. Non.
- **Changer le propriétaire du volume depuis l'extérieur**, avec un conteneur auxiliaire qui exécute `chown 65532:65532 /datos` avant de démarrer le `revisor`. Cela marche, mais c'est une étape de plus que quelqu'un doit se rappeler sur chaque ordinateur, et un conteneur qui s'exécute en tant que `root` rien que pour cela.
- **Que l'image apporte le dossier, avec le bon propriétaire.** C'est la correction de cette leçon, et elle fonctionne grâce à une règle des volumes qui est expliquée en 8.4.

### 8.4 La correction : l'image apporte `/datos`, appartenant au bon utilisateur

#### 8.4.1 La règle qui la rend possible

La documentation des volumes décrit ce qui se passe quand tu montes un volume **vide** sur un dossier du conteneur qui **contient déjà** des fichiers ou des dossiers : « ces fichiers ou dossiers sont propagés (copiés) dans le volume » ([Docker, « Volumes »](https://docs.docker.com/engine/storage/volumes/)). La documentation parle du contenu ; ce qu'elle ne dit pas, et que tu vas mesurer en 8.4.3, c'est que la copie emporte aussi le propriétaire et les permissions du dossier de l'image. Si l'image apporte `/datos` avec le propriétaire `65532`, un nouveau volume monté là naît avec le propriétaire `65532`. La correction ne se trouve donc pas dans le `docker run` : elle est dans le Dockerfile.

#### 8.4.2 Le Dockerfile de cette leçon

Voici le Dockerfile avec lequel se termine la leçon. C'est celui de la Leçon 7 avec trois changements, signalés plus bas :

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

Les trois changements :

1. **`&& mkdir -p /out/datos` dans l'étape `binario`.** Crée un dossier vide à côté du binaire. Il est créé dans l'étape de compilation parce que l'image finale, *distroless*, n'a ni *shell* ni `mkdir` : on n'a rien pour y créer un dossier. Il est ajouté au même `RUN` que celui qui compile pour ne pas ajouter une couche de plus à cette étape ; cela ne change rien dans l'image finale, qui ne reçoit que ce qui est copié.
2. **`COPY --from=binario --chown=65532:65532 /out/datos /datos` dans l'étape `final`.** Copie ce dossier vide vers `/datos` et lui donne comme propriétaire et groupe `65532`. Selon la référence du Dockerfile, `--chown` « définit le propriétaire des fichiers copiés », et sans cette option ils ont pour utilisateur et groupe `0` ([référence du Dockerfile](https://docs.docker.com/reference/dockerfile/)). On utilise des nombres et non des noms parce que l'image finale n'a aucune raison de savoir qui est `nonroot` ; le nombre est ce que le noyau compare.
3. **`REVISOR_REPORTE=/datos/reporte.json` dans le `ENV`.** La valeur par défaut de l'endroit où le rapport est enregistré. C'est de la configuration, pas un secret (Leçon 6), et elle convient dans n'importe quel environnement, parce que le dossier vient avec l'image. Quiconque exécute l'image sans rien dire enregistre dans `/datos`, et s'il y monte un volume, le rapport dure.

Ce troisième changement a une conséquence qu'il vaut mieux voir avant qu'elle ne te surprenne. L'image 1.5.0 **attend** que `/datos` soit accessible en écriture. Si tu l'exécutes avec `--read-only` et **sans** volume, comme dans la Leçon 7, `/api/estados` échoue de nouveau, cette fois avec `read-only file system`. Tu le verras dans le bloc 6 de `fig08_03.sh`, en 8.4.3.

Ce n'est pas un défaut : c'est l'image qui te dit où elle enregistre. À partir de cette leçon, le `revisor` durci s'exécute avec quelque chose d'accessible en écriture monté sur `/datos` : presque toujours un volume nommé, et un *bind mount* quand un autre outil de l'équipe doit lire les rapports (8.6). Tu le verras dans tous les scripts qui suivent, y compris ceux des réseaux, et dans le `compose.yaml` de la Leçon 9.

#### 8.4.3 Le voir fonctionner, et le voir survivre

Le script `fig08_03.sh` construit l'image 1.5.0, regarde son `/datos`, lui monte un nouveau volume, puis supprime le conteneur pour voir ce qui reste :

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

Bloc par bloc :

1. **L'image pèse 16,2 Mo** ; la 1.4.0 de la Leçon 7 en faisait 16,1. Un dossier vide ne pèse presque rien : la différence est un arrondi. Son environnement apporte les deux valeurs par défaut, `REVISOR_PUERTO=8080` et `REVISOR_REPORTE=/datos/reporte.json`. Et le `tar` de son système de fichiers montre déjà `datos/` avec le propriétaire `65532/65532`.
2. **Le nouveau volume a hérité du propriétaire.** `/api/estados` répond `200`. L'auxiliaire montre `/datos` avec le propriétaire `65532`, et non `0` : c'est la copie de 8.4.1. À l'intérieur se trouve `reporte.json`, appartenant à `65532`, avec les permissions `-rw-------` : seul son propriétaire le lit et l'écrit. (Ce `600` est décidé par le `revisor` : il crée le fichier temporaire avec la fonction `os.CreateTemp` de Go, qui utilise ces permissions, puis le renomme. L'auxiliaire peut le lire parce qu'il s'exécute en tant que `root`.) Le nombre d'octets dépend du nombre de services vérifiés.
3. **Un volume en cours d'utilisation ne se laisse pas supprimer.** `docker volume rm` sort avec le code `1` et te dit qui l'utilise : `volume is in use`, avec l'identifiant du conteneur entre crochets. C'est une protection : tu ne peux pas retirer le sol sous les pieds d'un conteneur qui est en train d'écrire.
4. **Le conteneur s'en va ; le volume et le rapport restent.** Après `docker rm -f`, il n'y a aucun conteneur portant ce nom, le volume est toujours dans la liste et l'auxiliaire lit le rapport complet : un service, `propio`, en bonne santé, avec le code `200` (la durée change à chaque exécution). C'est ce qui manquait le lundi matin.
5. **Un nouveau conteneur reprend le volume.** Le `revisor` naît de nouveau, trouve le rapport précédent à sa place, le remplace par la vérification suivante (`200`) et `docker inspect` montre le montage : `volume curso-docker-reportes-fig08 -> /datos (escribible: true)`. Le système de fichiers du conteneur reste en lecture seule ; `/datos` est la seule exception, et il a un nom.
6. **Sans le volume, la 1.5.0 durcie ne peut pas enregistrer.** C'est la conséquence de 8.4.2 : `read-only file system` et `500`. L'image dit déjà où elle enregistre ; celui qui l'exécute avec `--read-only` doit lui donner cet endroit.

#### 8.4.4 Dans ton dossier

Ton projet vit dans `~/curso-docker/revisor` depuis la Leçon 3. Depuis la racine du dépôt du cours, place-y le Dockerfile de cette leçon, construis l'image que tu vas conserver et crée ton volume :

```bash
cp programas/08-volumenes-y-redes/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.5.0 -t curso-docker-revisor:1.5.0 .
docker volume create curso-docker-reportes
```

Le `.dockerignore` et le dossier `secretos/` ne changent pas. Avant de continuer, répète manuellement l'erreur et la correction avec tes propres noms : exécute `curso-docker-revisor:1.4.0` avec un volume tout juste créé sur `/datos` et `-e REVISOR_REPORTE=/datos/reporte.json`, et regarde le `500` ; supprime-le avec ce volume ; et exécute `curso-docker-revisor:1.5.0` avec `curso-docker-reportes`. La seule chose qui change par rapport aux scripts, ce sont les noms. Les scripts de cette leçon ne touchent à rien de tout cela : ils utilisent des noms auxiliaires avec `fig08` et ne suppriment que ce qui leur appartient.

### 8.5 Copier contre masquer : ce qui se trouvait déjà dans le dossier

#### 8.5.1 Quatre cas qu'il vaut mieux ne pas confondre

La règle de 8.4.1 a des conditions, et presque toutes les mauvaises surprises avec les montages viennent de les oublier. Quand tu montes quelque chose sur un dossier du conteneur qui a déjà du contenu, l'une de ces choses se produit :

| Ce que tu montes | Ce que voit le conteneur | Ce qui arrive au contenu de l'image |
|---|---|---|
| un volume **nouveau et vide** | le contenu de l'image | il est **copié** dans le volume, avec propriétaires et permissions |
| un nouveau volume avec `volume-nocopy` | un dossier vide | il n'est pas copié ; il est masqué |
| un volume **qui contient déjà des données** | ce qu'il y a dans le volume | il est **masqué** ; rien n'est copié |
| un ***bind mount*** | ce qu'il y a dans le dossier de l'ordinateur | il est **masqué** ; rien n'est copié |

« Masqué » est le mot de la documentation : si tu montes un volume contenant des données là où il y avait déjà des fichiers, « les fichiers préexistants sont masqués par le montage » ([Docker, « Volumes »](https://docs.docker.com/engine/storage/volumes/)) ; avec un *bind mount*, « le contenu existant du dossier est masqué » ([Docker, « Bind mounts »](https://docs.docker.com/engine/storage/bind-mounts/)). Ils ne sont pas supprimés : ils restent dans la couche de l'image, en dessous, et réapparaissent si tu exécutes un conteneur sans le montage. Mais tant que le montage est là, le conteneur ne les voit pas.

Remarque la troisième ligne, parce qu'elle a une conséquence pratique : la copie n'a lieu que **la première fois**, quand le volume est vide. Si le volume `curso-docker-reportes` a été créé avec l'image 1.5.0 et que demain une image 1.6.0 apporte quelque chose de différent dans `/datos`, le volume ne se met pas à jour : il contient déjà des données, donc c'est le volume qui gagne. Pour un rapport, c'est exactement ce que tu veux (les données du service ne doivent pas changer parce que l'image a changé). Pour qui conserve dans un volume des fichiers qui devraient venir de l'image, c'est une source classique du « j'ai mis à jour et rien n'a changé ».

#### 8.5.2 Le voir avec un conteneur auxiliaire

Le script `fig08_04.sh` montre les quatre cas avec l'`alpine` auxiliaire, sur son dossier `/etc/apk`, qui contient cinq entrées. À la fin, il teste la différence entre `-v` et `--mount` avec un dossier de l'ordinateur qui n'existe pas :

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

Bloc par bloc :

1. **Sans montage**, `/etc/apk` a cinq entrées : `arch`, `keys`, `protected_paths.d`, `repositories` et `world`.
2. **Avec un nouveau volume**, le conteneur voit les cinq mêmes. Et ce n'est pas qu'il voie celles de l'image « à travers » le volume : monté sur un autre chemin (`/mirar`), dans un conteneur différent, le volume les contient. Docker les a copiées lors du premier montage.
3. **Avec `volume-nocopy`**, zéro entrée. L'option dit à Docker de ne pas copier même si le volume est vide ([Docker, « Volumes »](https://docs.docker.com/engine/storage/volumes/)) ; avec `-v` elle existe aussi, mais on écrit `nocopy` (8.1.3). Si tu la vois un jour dans un `docker run` du `revisor`, tu sais déjà ce qui va se passer : le volume naît avec son dossier appartenant à `root`, comme en 8.3, et le `permission denied` revient. Tu le vérifieras dans l'Exercice 4.
4. **Avec un *bind mount* d'un dossier vide**, zéro entrée : ce qui venait de l'image a été masqué. Et le dossier de l'ordinateur reste vide : un *bind mount* ne copie rien, dans aucun sens. Le conteneur voit **ton dossier**, tel quel, et rien d'autre.
5. **`-v` avec un chemin de l'ordinateur qui n'existe pas** : le conteneur démarre sans se plaindre, et sur ton ordinateur apparaît le dossier `no-existia`... avec le propriétaire `root:root`. Il a été créé par le daemon, qui s'exécute en tant que `root`. La documentation le dit ainsi : avec `-v`, « Docker crée le dossier sur l'hôte à ta place » ([Docker, « Bind mounts »](https://docs.docker.com/engine/storage/bind-mounts/)). Ce qu'elle ne dit pas aussi fort, c'est le propriétaire, et c'est ce qui mord : une faute de frappe dans le chemin te laisse un dossier appartenant à `root` dans ton projet, un conteneur qui écrit au mauvais endroit et, si le processus n'est pas `root`, un autre `permission denied`.
6. **`--mount` avec un chemin qui n'existe pas** : il refuse. `invalid mount config for type "bind": bind source path does not exist`, avec le code `125`, celui qu'utilise `docker run` quand l'erreur vient de Docker lui-même et non du programme. C'est le comportement que tu veux : une faute de frappe se voit sur-le-champ. (Le chemin apparaît sous la forme `./tampoco-existe` parce que le script masque le dossier temporaire, qui change à chaque exécution.) C'est le comportement par défaut : `--mount` peut aussi créer le dossier si tu le demandes avec l'option `bind-create-src`, qui, selon la documentation, « crée automatiquement le dossier source sur l'hôte s'il n'existe pas » ([Docker, « Bind mounts »](https://docs.docker.com/engine/storage/bind-mounts/)). Ce cours ne l'utilise pas, parce que ce qu'il cherche, c'est justement que la faute de frappe se voie. C'est pourquoi il utilise `--mount` pour les *bind mounts*.

### 8.6 *Bind mounts* et le propriétaire des fichiers

#### 8.6.1 Quand un *bind mount* plutôt qu'un volume

Un *bind mount* convient quand toi, depuis ton ordinateur, tu as besoin de voir ou de placer les fichiers sans passer par Docker : le code d'un programme pendant que tu le développes, un fichier de configuration que tu édites manuellement, le token de la Leçon 6, ou un rapport qu'un autre outil de ton équipe va récupérer. Le prix à payer est que le conteneur écrit **directement dans ton système de fichiers**. La documentation le met en garde : avec un *bind mount*, « tu peux modifier le système de fichiers de l'hôte depuis des processus qui s'exécutent dans un conteneur », et les *bind mounts* ont, par défaut, un « accès en écriture aux fichiers de l'hôte » ([Docker, « Bind mounts »](https://docs.docker.com/engine/storage/bind-mounts/)). C'est pourquoi, quand le conteneur a seulement besoin de lire, le montage se fait avec `readonly`, comme le token.

#### 8.6.2 La même erreur, par l'autre côté

Avec un volume, le dossier appartenait à `root` et la correction a été que l'image apporte le sien. Avec un *bind mount*, cela ne sert à rien : le conteneur voit **ton** dossier, avec **ton** propriétaire, et ce que l'image apporte dans `/datos` est masqué (8.5). Le choc revient donc, cette fois entre ton utilisateur et le `65532`. Le script `fig08_05.sh` le provoque et le corrige sans `root` :

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

Bloc par bloc :

1. **Le dossier est à toi** : propriétaire `501:1000`, permissions `775` (toi et ton groupe écrivez ; les autres, non). Sur ton Mint, il indiquera `1000:1000`. Le script affiche ton utilisateur pour que tu compares.
2. **Monté sur `/datos`, `permission denied`.** Le `revisor` s'exécute en tant que `65532`, qui n'est ni le propriétaire ni dans le groupe `1000`, et pour « les autres » le dossier n'est pas accessible en écriture. Le montage ne traduit rien : à l'intérieur du conteneur, le dossier a le même propriétaire numérique qu'à l'extérieur. (Avec Docker sans `root` ou avec un remappage des utilisateurs, le nombre de l'intérieur est traduit en un autre à l'extérieur ; l'installation de la Leçon 1 ne fait pas cela.)
3. **La correction : exécuter le conteneur avec ton utilisateur.** `--user "$(id -u):$(id -g)"` remplace le `65532` de l'image par tes nombres, et maintenant le processus est le propriétaire du dossier : `200`. Et le rapport, vu depuis ton ordinateur, est à toi (`501:1000`, `600`) : tu le lis sans `docker` et sans `sudo`. Remarque ce qui n'a **pas** changé : le processus n'est toujours pas `root`, il n'a toujours pas de capacités et le système de fichiers est toujours en lecture seule. Tu as remplacé un utilisateur sans privilèges par un autre utilisateur sans privilèges, le tien. Attention : si tu exécutes la commande avec `sudo`, `$(id -u)` vaut `0` et tu t'exécuterais en tant que `root` sans t'en rendre compte. C'est pourquoi, dans la Leçon 1, tu es entré dans le groupe `docker` : ces commandes se lancent sans `sudo`. `docker inspect` le confirme : `User=501:1000`, et le montage `bind -> /datos (escribible: true)`.
4. **En lecture seule, le noyau refuse.** Avec `readonly`, le `revisor` échoue de nouveau, cette fois avec `read-only file system` : même en étant le propriétaire, il ne peut pas écrire. Pour le rapport, cela n'a pas de sens, mais c'est exactement ce que tu veux pour un fichier de configuration ou un secret : le conteneur le lit et ne peut pas le modifier.

Pourquoi pas un `chmod 777` sur le dossier ? Parce que cela laisse **n'importe quel utilisateur de ton ordinateur** y écrire, et n'importe quel conteneur avec n'importe quel utilisateur le remplir. C'est la version « dossier » du `644` de la Leçon 6, mais en pire, parce qu'ici on écrit, on ne se contente pas de lire. `--user` avec tes nombres résout le problème là où il naît : le propriétaire.

### 8.7 `tmpfs` : ce qui ne doit pas durer

#### 8.7.1 À quoi ça sert

Dans la Leçon 7, tu as utilisé `--tmpfs /tmp` pour que le `revisor` puisse écrire son rapport avec le système de fichiers en lecture seule. Cela a fonctionné, et le rapport mourait avec le conteneur. Maintenant le rapport a son volume, mais le `tmpfs` garde sa place : tout ce qu'un programme écrit et qui ne doit **pas** survivre. Des fichiers temporaires, des caches d'une seule exécution, un fichier contenant un secret déchiffré qui ne doit pas toucher le disque. La documentation le résume : contrairement aux volumes et aux *bind mounts*, un `tmpfs` « est temporaire et ne persiste que dans la mémoire de l'hôte », et « quand le conteneur s'arrête, le montage `tmpfs` est supprimé » ([Docker, « tmpfs mounts »](https://docs.docker.com/engine/storage/tmpfs/)). On ne peut pas non plus le partager entre conteneurs.

Deux valeurs par défaut de cette page qu'il convient de connaître : sans taille, la limite d'un `tmpfs` est **la moitié de la mémoire de l'ordinateur**, et sa permission est `1777`, accessible en écriture par tout le monde (avec le bit qui empêche de supprimer les fichiers des autres, le même que celui de `/tmp` sur ton Mint). Et un avertissement honnête : le noyau peut envoyer vers la mémoire d'échange (*swap*) ce qui se trouve dans un `tmpfs`, donc « en mémoire » n'est pas la garantie que cela ne touchera jamais le disque.

#### 8.7.2 Volume et `tmpfs`, côte à côte

Le script `fig08_06.sh` exécute un conteneur en lecture seule avec les deux montages, écrit dans les deux, le redémarre et regarde ce qui a survécu :

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

1. **Les deux montages et leurs options**, lus dans `/proc/mounts`, la liste que tient le noyau. `/datos` est de type `ext4` : le volume vit sur le disque de l'ordinateur. `/cache` est de type `tmpfs`, avec `size=1024k` (le `1m` que tu as demandé) et trois options que Docker lui a mises de lui-même en le montant avec `--mount` : `nosuid`, `nodev` et `noexec`. Dans la Leçon 7, tu les avais écrites manuellement avec `--tmpfs` ; avec `--mount type=tmpfs`, elles viennent toutes seules. La permission est `1777`.
2. **On écrit dans les deux et pas à la racine.** `a.txt` dans le volume, `b.txt` dans le `tmpfs` ; et `/c.txt` échoue avec `Read-only file system`, parce qu'en dehors des montages tout est en lecture seule. Trois dossiers, trois comportements, et tu as demandé chacun par son nom.
3. **Le `tmpfs` a une limite.** Écrire 2 Mo dans un `tmpfs` de 1 Mo se termine par `No space left on device`. Sans `size`, cette limite serait la moitié de la mémoire de l'ordinateur : un programme défaillant qui écrit sans arrêt pourrait occuper bien plus que ce que tu imaginais. Avec la limite, l'erreur apparaît sur-le-champ et avec un message clair.
4. **Après `docker restart`, le volume conserve `a.txt` et le `tmpfs` est vide.** Un redémarrage suffit à vider le `tmpfs` ; inutile de supprimer le conteneur.

La documentation préfère `--mount type=tmpfs` et reconnaît que `--tmpfs` « est moins verbeux » et admet davantage d'options de montage ([Docker, « tmpfs mounts »](https://docs.docker.com/engine/storage/tmpfs/)). Les deux conviennent. L'important est de lui donner une taille.

#### 8.7.3 Lequel utiliser, dans le `revisor`

| Donnée | Montage | Pourquoi |
|---|---|---|
| le rapport (`/datos/reporte.json`) | volume nommé sur `/datos` | il doit survivre au conteneur ; personne n'a besoin de l'éditer manuellement |
| le token (`/run/secrets/revisor_token`) | *bind mount* d'un fichier, `readonly` | c'est toi qui le places depuis l'extérieur ; le conteneur ne fait que le lire |
| un temporaire que le programme ne doit pas conserver | `tmpfs` avec une taille | il doit mourir avec le conteneur et ne pas occuper de disque |
| le code du programme | aucun : il va dans l'image | c'est du code, pas des données (Leçon 6) |

### 8.8 Réseaux : le réseau par défaut n'a pas de noms

#### 8.8.1 Ce qu'est un réseau Docker

Chaque conteneur a sa propre pile réseau : ses interfaces, son adresse IP, sa table de routage, son `127.0.0.1`. C'est l'un des isolements de la Leçon 0. Pour que les conteneurs se parlent, Docker les connecte à des **réseaux** : en dessous, sous Linux, un pont virtuel (*bridge*) auquel est connectée une interface de chaque conteneur, comme des câbles branchés sur un même commutateur. Le pilote par défaut s'appelle justement `bridge`.

Docker crée trois réseaux à l'installation, `bridge`, `host` et `none` (tu les vois avec `docker network ls`), et si tu ne dis rien d'autre, tout conteneur se connecte à `bridge`. C'est là qu'est resté chaque conteneur du cours jusqu'à aujourd'hui. Ce réseau a une limitation que la documentation énonce sans fard : dans le réseau par défaut, les conteneurs « ne peuvent être atteints que par adresse IP ». Plus encore : « le réseau `bridge` par défaut est considéré comme un vestige hérité de Docker et n'est pas recommandé pour la production » ([Docker, pilote `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)).

#### 8.8.2 Le voir : par le nom non, par l'IP oui

Le script `fig08_07.sh` place le `revisor` et le service de test dans le réseau par défaut, et demande au `revisor` de vérifier `http://curso-docker-prueba-fig08:9000/`. Puis il fait la même chose dans un réseau défini par l'utilisateur, et à la fin il casse le service de test depuis un autre conteneur :

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

La première moitié de la sortie, le réseau par défaut :

1. **`FALLA`, avec `no such host`.** Le message complet se lit de droite à gauche : `no such host` (le nom n'existe pas), `lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53` (la question a été posée au serveur DNS de ton ordinateur, sur le port 53, celui du DNS), `dial tcp` (il voulait ouvrir une connexion) et `Get "http://…"` (pour faire cette requête). Le serveur DNS de ton ordinateur n'a aucune idée des conteneurs qui tournent dans Docker, donc il répond la seule chose qu'il peut : ce nom n'existe pas. L'adresse réelle de ce serveur dépend de chaque réseau, et le script la masque.
2. **Les deux sont dans le même réseau**, `bridge`. Ils ne sont pas séparés : ils sont ensemble et pourtant ne se trouvent pas par leur nom.
3. **Le DNS qu'ils reçoivent est celui de l'hôte.** La documentation explique que les conteneurs du réseau par défaut reçoivent une copie du `/etc/resolv.conf` de ton ordinateur ([Docker, « Networking »](https://docs.docker.com/engine/network/)). L'auxiliaire le montre : `nameserver <DNS del anfitrión>`. Une nuance pour ton Mint : si dans ton `/etc/resolv.conf` tu vois `nameserver 127.0.0.53` (le résolveur local de *systemd*, ce qui est normal sur Mint et Ubuntu), cette adresse, à l'intérieur du conteneur, pointerait vers le conteneur lui-même, où il n'y a aucun DNS ; Docker ne la copie donc pas telle quelle, et le conteneur reçoit d'autres serveurs. La documentation de « Networking » ne détaille pas cette conversion ; pour savoir ce qu'a reçu le tien, compare avec l'auxiliaire, qui sert justement à cela.
4. **Par l'IP, en revanche, ça passe.** Le script demande à Docker l'adresse du service de test (masquée sous la forme `<IP>`) et l'auxiliaire lui fait une requête directe : `sano`. Le réseau fonctionne ; ce qui manque, ce sont les noms. Et une IP ne sert pas à configurer le `revisor`, parce qu'elle est distribuée par Docker au démarrage et peut changer au suivant.

Dans les vieux tutoriels, tu verras l'ancienne solution à ce problème, `--link`. La section 8.12 explique pourquoi elle n'a plus cours.

### 8.9 Réseaux définis par l'utilisateur : des noms offerts

#### 8.9.1 Ce qui change

Un réseau que tu crées avec `docker network create` (lui aussi avec le pilote `bridge`) se comporte différemment. La documentation liste les différences ([Docker, pilote `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)) :

- **DNS automatique** : « les réseaux *bridge* définis par l'utilisateur offrent une résolution DNS automatique entre les conteneurs ». Chaque conteneur se retrouve par son nom.
- **Meilleur isolement** : seuls les conteneurs connectés à ce réseau se parlent entre eux. Dans le réseau par défaut, en revanche, n'importe quel conteneur que quelqu'un démarre sans réfléchir se retrouve à côté des tiens.
- **Connecter et déconnecter à chaud** : un conteneur peut être connecté à un réseau défini par l'utilisateur, ou en être déconnecté, « à la volée », sans être recréé. Tu le feras en 8.10.

Le DNS est fourni par un serveur que Docker place **à l'intérieur** de chaque conteneur de ces réseaux, à l'adresse `127.0.0.11`. La documentation l'appelle le serveur DNS intégré, et explique qu'il répond pour les noms des conteneurs du réseau et transmet tout le reste aux serveurs DNS de l'ordinateur ([Docker, « Networking »](https://docs.docker.com/engine/network/)). C'est pourquoi un conteneur dans un réseau à toi résout aussi bien `curso-docker-prueba` que `www.docker.com`.

#### 8.9.2 Lire la seconde moitié de l'exécution

De retour à la sortie de `fig08_07.sh`, bloc 2 :

1. **Le réseau** : `curso-docker-red-fig08`, pilote `bridge`, `interna=false` (il a une sortie ; en 8.10 tu en créeras un qui n'en a pas).
2. **`OK`, `200`.** Le même `revisor`, avec la même configuration, trouve le service de test par son nom. Tu n'as pas changé une seule lettre de `REVISOR_SERVICIOS` : tu as changé le réseau.
3. **Le DNS est maintenant `127.0.0.11`.** L'auxiliaire, connecté au même réseau, le montre dans son `/etc/resolv.conf`, et `nslookup` l'interroge sur le nom du service de test : le serveur `127.0.0.11` répond avec son adresse (masquée).
4. **Qui est connecté** : les deux conteneurs, et personne d'autre. L'auxiliaire n'apparaît pas parce qu'il a déjà terminé (`--rm`).

Et le bloc 3, celui qui justifie tout le cours : un conteneur du même réseau envoie un `POST /modo/caido` au service de test (`modo: caido`), et la vérification suivante du `revisor` indique `FALLA`, `codigo 503`. Le service de test continue de tourner ; le `revisor`, qui le vérifie par son nom à travers le réseau, distingue ce que Docker croit (le conteneur est en marche) de ce qui se passe (il répond `503`). (La colonne `TIEMPO` de la dernière ligne sort avec une espace de trop parce que le script masque une durée d'une largeur différente ; c'est le tableau, pas une erreur.)

Une note sur le nom : le `revisor` cherche `curso-docker-prueba-fig08` parce que c'est ainsi que s'appelle le conteneur du script. Dans ton dossier, le conteneur s'appelle `curso-docker-prueba`, et `REVISOR_SERVICIOS` dit `prueba http://curso-docker-prueba:9000/ 2s`. Le nom du conteneur **est** son nom dans le réseau ; si tu le changes, tu changes son adresse.

### 8.10 Réseaux internes : sans sortie

#### 8.10.1 Pourquoi enfermer le service de test

Le service de test n'existe que pour que le `revisor` le consulte. Il n'a pas besoin de télécharger quoi que ce soit, d'appeler qui que ce soit, d'internet. Et tout ce qu'un conteneur peut atteindre, un attaquant qui le contrôle peut aussi l'atteindre : télécharger un outil, envoyer des données à l'extérieur, s'en servir comme tremplin. La réponse est un **réseau interne** : `docker network create --internal`. La référence de `docker network create` le décrit en une phrase, « restreint l'accès externe au réseau », et l'explique ainsi : les conteneurs d'un réseau interne « peuvent communiquer entre eux, mais pas avec un autre réseau, car aucune route par défaut n'est configurée et des règles de pare-feu sont mises en place pour rejeter tout le trafic vers ou depuis d'autres réseaux » ([référence de `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/)).

Le schéma est celui que la documentation elle-même donne en exemple : un réseau interne « pour communiquer avec des conteneurs qui exécutent des services internes n'ayant pas besoin d'accéder au réseau externe » ([Docker, « Networking »](https://docs.docker.com/engine/network/)). Le service de test, **uniquement** dans le réseau interne. Le `revisor`, dans le réseau normal (par où il expose son port vers ton `127.0.0.1`) **et** dans le réseau interne (par où il vérifie le service de test). Un conteneur peut se trouver dans plusieurs réseaux à la fois : il a une interface dans chacun.

#### 8.10.2 Le voir

Le script `fig08_08.sh` monte cet état, qui est l'état final de la leçon, en deux étapes, pour que tu voies ce qu'apporte chaque réseau :

```bash
#!/usr/bin/env bash
# fig08_08.sh — Red interna. El servicio de prueba vive SOLO en una red interna,
# sin salida a internet. El revisor vive en la red normal (por donde expone
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

1. **Deux réseaux**, tous deux avec le pilote `bridge` ; l'un avec `interna=true`.
2. **Le `revisor` seul dans le réseau normal ne trouve pas le service de test.** Le message dit maintenant `lookup … on 127.0.0.11:53: no such host`. Compare-le avec celui de 8.8 : là-bas, il a interrogé le DNS de ton ordinateur (réseau par défaut) ; ici, il a interrogé le DNS intégré de Docker (réseau défini par l'utilisateur), qui, lui, existe, mais ne répond que pour les noms **des réseaux du conteneur lui-même**. Le service de test est dans un autre réseau, donc pour le `revisor` il n'existe pas. C'est l'isolement de 8.9.1 qui fonctionne : être sur le même ordinateur ne suffit pas, il faut partager un réseau. Lire sur quel serveur DNS la question a été posée te dit de quel type de réseau on parle.
3. **`docker network connect` sans redémarrer.** Tu connectes le `revisor` aussi au réseau interne, à chaud, et la vérification suivante indique `OK`. `docker inspect` montre les deux réseaux du `revisor` (par ordre alphabétique, avec une espace à la fin que met le modèle). Et `docker port` confirme que le port publié reste sur `127.0.0.1` (le numéro de l'ordinateur est masqué, parce que le script le reçoit dans `PUERTO`).
4. **Depuis le réseau interne, il n'y a pas de sortie.** Un auxiliaire dans le réseau interne tente de télécharger `https://www.docker.com/` et échoue avant même d'essayer de se connecter : `wget: bad address 'www.docker.com'`, code `1`. Il ne peut même pas résoudre le nom : la requête sort du conteneur vers le DNS intégré de Docker, et un réseau interne n'a pas de sortie vers l'extérieur par laquelle cette requête pourrait atteindre un serveur de noms externe. (La documentation ne détaille pas à quel endroit exact la requête est coupée, donc la leçon n'affirme que ce qui a été mesuré : le nom n'est pas résolu et le téléchargement ne démarre même pas.) Mais le réseau interne n'est pas isolé de tout : le même auxiliaire montre sa table de routage, avec une seule ligne (le réseau interne lui-même, sans route par défaut vers l'extérieur), et malgré cela sa passerelle répond au `ping` (`1 packets received`). Depuis le réseau normal, le téléchargement fonctionne. Le réseau interne n'est pas une promesse : vers l'extérieur il n'y a pas de route, mais la passerelle est toujours là.

Une précision pour que tu n'en retiennes pas une idée de trop : « sans sortie » ne signifie pas « inatteignable depuis ton ordinateur ». La référence dit que l'hôte peut communiquer directement avec les adresses des conteneurs d'un réseau interne. Ce que le réseau interne coupe, c'est le chemin du conteneur vers **d'autres réseaux**, internet compris. Et dans l'autre sens, il y a une brèche qu'il faut connaître, celle que tu viens de mesurer : la même référence précise que « la communication avec l'adresse de la passerelle (et, par elle, avec les services de l'hôte configurés pour cela) est possible ». Un programme de ton ordinateur qui écoute sur `0.0.0.0` (toutes les interfaces), par exemple une base de données de développement, se retrouve à la portée des conteneurs du réseau interne. C'est une raison de plus pour l'habitude de la Leçon 2 : ce qui tourne sur ton ordinateur écoute sur `127.0.0.1`, pas sur toutes les interfaces. C'est pourquoi le cours publie le port du `revisor` par le réseau normal, celui qui a bien un chemin vers l'extérieur, et laisse le réseau interne uniquement pour parler au service de test.

#### 8.10.3 Dans ton dossier : l'état final

Avec ton image `curso-docker-revisor:1.5.0`, ton volume `curso-docker-reportes` et l'image `curso-docker-prueba:1.0.0` de la Leçon 2, voici les commandes de l'état final, avec les noms du cours :

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

(Si tu as déjà créé le volume en 8.4.4, le `docker volume create` ne fait que te renvoyer son nom : il ne le vide pas.) Vérifie avec `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` que le service de test sort `OK`, et avec `docker ps --filter name=curso-docker-` que les deux atteignent `(healthy)`. Le service de test porte les mêmes options de durcissement que le `revisor`, sans port et sans `-e` : c'est l'Exercice 4 de la Leçon 7, et tu sais déjà qu'il n'a besoin même pas d'un `tmpfs` parce qu'il n'écrit rien. Ces deux conteneurs, les deux réseaux et le volume sont ce que la Leçon 9 écrit dans un `compose.yaml`.

Quand tu auras terminé la leçon, supprime-les dans cet ordre (d'abord les conteneurs, parce qu'un réseau ou un volume en cours d'utilisation ne se supprime pas) : `docker rm -f curso-docker-revisor curso-docker-prueba` et `docker network rm curso-docker-red curso-docker-interna`. Le volume, si tu veux conserver le rapport, reste ; sinon, `docker volume rm curso-docker-reportes`.

### 8.11 Ce qu'on **ne** fait **pas** : le réseau de l'hôte

Un autre des réseaux que Docker crée à l'installation est `host`. Un conteneur qui s'y trouve **n'a pas de réseau propre** : selon la documentation, sa pile réseau « n'est pas isolée de l'hôte » et le conteneur « ne reçoit pas sa propre adresse IP » ([Docker, pilote `host`](https://docs.docker.com/engine/network/drivers/host/)). Il écoute directement sur les interfaces de ton ordinateur, voit tous ses ports et toutes ses connexions locales, et `-p` n'a plus d'effet : Docker l'ignore avec l'avertissement `WARNING: Published ports are discarded when using host network mode`. Ce dernier point annule d'un coup l'habitude de la Leçon 2 : tu ne décides plus si le port reste sur `127.0.0.1` ou sur toutes les interfaces ; il reste là où le programme décide d'écouter.

On l'utilise parfois « parce que ça marche comme ça » quand un conteneur ne trouve pas un autre, ou pour gagner quelques microsecondes de réseau. Ces deux raisons ont une meilleure réponse : pour trouver un autre conteneur, un réseau défini par l'utilisateur ; pour la performance, mesurer d'abord, parce que ce n'est presque jamais le réseau du conteneur qui limite. Le README du cours en fait l'habitude de cette leçon : **jamais le réseau de l'hôte**. L'habitude vaut pour des services applicatifs comme le `revisor` ; il existe des usages légitimes en infrastructure (par exemple, un agent qui mesure le réseau de l'ordinateur lui-même) qui ne sont pas le sujet de ce cours, et celui qui en a besoin sait déjà qu'il renonce volontairement à l'isolement.

### 8.12 Ce que tu trouveras dans les vieux tutoriels

- **`--link`.** L'ancienne façon pour un conteneur d'en trouver un autre par son nom dans le réseau par défaut. La documentation ne la recommande plus : les liens dans le réseau par défaut sont « obsolètes et prévus pour être supprimés dans Docker Engine 30.0 », et elle demande d'utiliser des « réseaux définis par l'utilisateur plutôt que l'option héritée `--link` » ([Docker, liens hérités](https://docs.docker.com/engine/network/links/)). Si tu la vois, traduis-la en réseau.
- **Les « conteneurs de données seules » et `--volumes-from`.** Avant l'existence des volumes nommés, on créait un conteneur qui ne tournait jamais, juste pour « avoir » un volume, et les autres le montaient avec `--volumes-from`. Aujourd'hui, le volume a son propre nom et n'a pas besoin d'un conteneur pour le porter.
- **`VOLUME /datos` dans le Dockerfile « pour que les données persistent ».** L'instruction existe et fait quelque chose : elle marque un chemin comme point de montage, et si tu ne montes rien là à l'exécution, Docker crée un volume **anonyme** initialisé avec ce que l'image contient à ce chemin ([référence du Dockerfile](https://docs.docker.com/reference/dockerfile/)). Le résultat est exactement le contraire de ce qu'on cherche : un volume sans nom pour chaque conteneur, que personne ne reconnaît et qui s'accumule. Et l'instruction ne peut pas choisir un dossier de l'ordinateur. Ce cours ne l'utilise pas : le `revisor` apporte le dossier `/datos` avec son propriétaire, et le volume nommé est décidé par celui qui exécute le conteneur.
- **`chmod -R 777` sur le dossier de données** pour « réparer les permissions ». Tu as vu en 8.3 et 8.6 que le problème est le propriétaire ; un `777` le dissimule et ouvre le dossier à n'importe qui.

## L'erreur que tu vas voir

Cette leçon a deux erreurs principales, une par moitié, et trois secondaires. Toutes sont déjà apparues.

**L'erreur principale de stockage : le nouveau volume que le processus ne peut pas écrire.** C'est celle de `fig08_02.sh` :

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
```

Elle se lit de droite à gauche, comme celle de la Leçon 6. `permission denied`, c'est le noyau qui le dit : le processus n'a pas la permission de créer un fichier à cet endroit. `open /datos/.reporte-<n>.tmp` dit de quel fichier il s'agit, avec le chemin **à l'intérieur** du conteneur : c'est le temporaire que le `revisor` écrit avant de le renommer, donc le problème, c'est le **dossier**, et non `reporte.json`. Et `no pude guardar el reporte` est ajouté par le `revisor`, qui répond en plus `500` au lieu de faire comme si tout allait bien. La question qui le résout est toujours la même : « qui est le propriétaire du dossier, et avec quel utilisateur s'exécute le processus ? ». La première réponse, c'est un auxiliaire qui te la donne (`docker run --rm -v <volume>:/datos:ro alpine:3.24.2 ls -lnd /datos`) ; la seconde, `docker inspect --format '{{.Config.User}}' <conteneur>`. Si le dossier appartient à `0` et que le processus est `65532`, c'est un volume qui est né sans dossier de l'image à copier : soit l'image n'apporte pas `/datos` (la 1.4.0), soit quelqu'un a utilisé `volume-nocopy`. La correction est que l'image apporte le dossier avec `COPY --chown` et que le volume soit nouveau. Le fait que le volume existe d'avance n'empêche pas la copie : tant qu'il est **vide**, le premier montage sur un dossier de l'image la reçoit, même si c'est toi qui l'as créé avec `docker volume create` (c'est ce que fait le bloc 2 de `fig08_03.sh`, et nous l'avons répété manuellement : un volume créé d'avance et monté auparavant avec `nocopy` a quand même reçu le dossier de `65532` quand on l'a monté ensuite avec la bonne image). Ce qui l'empêche, c'est que le volume **contienne déjà quelque chose**, par exemple un fichier qu'un processus de `root` a écrit un jour : alors c'est le volume qui gagne, le dossier reste à `root` et le `permission denied` revient. Dans ce cas, s'il n'y a rien à conserver, `docker volume rm` et laisse le `docker run` suivant le créer de nouveau.

Avec un *bind mount*, le même texte a une autre origine : le dossier est **à toi** et le processus, `65532`. Correction : `--user "$(id -u):$(id -g)"`, ou que le dossier appartienne à `65532`. Ce qui n'est pas une correction, dans aucun des deux cas : `--user 0` ou `chmod 777`.

**L'erreur principale de réseau : le nom qui n'existe pas.**

```text
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
```

`no such host` dit que le nom n'a pas pu être résolu. Ce qui diagnostique le cas, c'est **à qui la question a été posée**, juste avant le `:53` :

- **L'adresse du DNS de ton ordinateur** : le conteneur est dans le réseau par défaut, qui n'a pas de DNS de conteneurs. Correction : un réseau défini par l'utilisateur pour les deux.
- **`127.0.0.11`** : le conteneur est bien dans un réseau à toi, avec le DNS intégré de Docker, mais l'autre conteneur n'est dans **aucun de ses réseaux** (ou il s'appelle autrement, ou il ne tourne pas). Correction : `docker network connect`, ou vérifier le nom avec `docker ps`.

Ce détail transforme un message générique en diagnostic d'une ligne.

**Les secondaires :**

```text
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe
```

Un `--mount type=bind` avec un chemin de l'ordinateur qui n'existe pas (il sort avec `125` ; le chemin du message est celui que tu as écrit). C'est presque toujours une faute de frappe ou un chemin relatif au mauvais endroit. Avec `-v`, tu n'aurais pas vu cette erreur : Docker aurait créé le dossier, appartenant à `root`, et le conteneur aurait démarré avec un dossier vide.

```text
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
```

`docker volume rm` sur un volume qu'un conteneur, en marche ou arrêté, a encore monté. Supprime d'abord le conteneur (l'identifiant entre crochets te dit lequel). La même chose se produit avec `docker network rm` et un réseau auquel des conteneurs sont connectés.

```text
wget: bad address 'www.docker.com'
```

Depuis un conteneur dans un réseau interne, n'importe quel nom extérieur. Si tu le vois dans un conteneur qui **devrait** avoir une sortie, vérifie ses réseaux avec `docker inspect` : il est probablement uniquement dans un réseau interne.

## L'habitude de sécurité de la leçon

**Les données se montent avec un nom, avec le bon propriétaire et seulement là où il le faut ; les réseaux sont à toi, celui des services internes n'a pas de sortie, et celui de l'hôte ne s'utilise pas.** Ce sont trois habitudes qui s'écrivent ensemble et se vérifient ensemble. La première : le système de fichiers reste en lecture seule, et chaque dossier accessible en écriture a un nom (un volume sur `/datos`, un `tmpfs` avec une taille) ; aucun ne se répare avec `root` ni avec `777`, parce que le problème est le propriétaire et qu'il se règle dans l'image ou avec `--user`. La deuxième : chaque conteneur n'est que dans les réseaux dont il a besoin ; celui qui n'a pas besoin d'internet vit dans un réseau `--internal`, et tu le vérifies en lui demandant de sortir (`bad address`). La troisième : jamais `--network host`, qui efface d'un coup l'isolement réseau et le `127.0.0.1` de la Leçon 2. L'accident qu'on évite est concret : un service interne compromis qui ne peut rien télécharger ni rien envoyer à l'extérieur, et qui ne peut pas non plus écrire ailleurs que dans un dossier que tu as choisi.

## Ce qui se fait de travers

**Conserver des données dans la couche du conteneur.** Cela fonctionne jusqu'au premier `docker rm`, qui, dans un service, est la mise à jour suivante. Et avec `--read-only`, cela ne fonctionne même pas.

**Exécuter en tant que `root` pour que le volume accepte l'écriture.** On échange un problème de propriétaire contre un problème de sécurité, et on défait les Leçons 3, 5 et 7. L'image apporte son dossier avec `COPY --chown`.

**`chmod 777` sur un dossier de l'ordinateur.** Cela l'ouvre à tous les utilisateurs et à tous les conteneurs. La correction, c'est le propriétaire : `--user` avec tes nombres.

**`-v` avec des chemins de l'ordinateur.** Une faute de frappe crée en silence un dossier appartenant à `root`. Pour les *bind mounts*, `--mount type=bind`, qui refuse par défaut.

**Monter en lecture et écriture ce que le conteneur ne fait que lire.** Configuration, secrets, certificats : `readonly`. Un *bind mount* accessible en écriture est une porte du conteneur vers ton disque.

**Les volumes anonymes, par `VOLUME` dans le Dockerfile ou par `-v /datos` sans nom.** Ils s'accumulent sans que personne sache à qui ils sont. Donne-leur un nom, avec le préfixe du projet.

**Supprimer des volumes « au cas où ».** `docker volume rm` n'a pas de corbeille. Et `docker volume prune -a` supprime **tous** les volumes qu'aucun conteneur n'utilise, nommés ou non, y compris les données de projets arrêtés qui ne sont pas à toi (sans `-a`, `prune` ne supprime que les anonymes, selon sa [référence](https://docs.docker.com/reference/cli/docker/volume/prune/)). Supprime par nom exact.

**Écrire des adresses IP de conteneurs dans la configuration.** Elles sont distribuées par Docker et changent. Utilise des noms dans un réseau défini par l'utilisateur.

**Laisser tout dans le réseau par défaut.** Sans noms, et avec n'importe quel conteneur que quelqu'un démarre sans réfléchir dans le même réseau que les tiens. La documentation elle-même le qualifie de vestige hérité.

**Donner internet à qui n'en a pas besoin.** Un service interne avec une sortie est un tremplin. `--internal`.

**`--network host` « parce que comme ça, ça marche ».** Si un conteneur ne trouve pas un autre, la réponse est un réseau à toi, pas retirer l'isolement.

## Exercices

Fais-les dans l'ordre. Avant d'exécuter chacun, écris dans ton [journal de bord](bitacora.md) ce que tu penses qu'il va se passer ; comparer ensuite représente la moitié de l'apprentissage. À la fin, supprime ce que tu as créé : tout porte le préfixe `curso-docker-`.

### Exercice 1 — Volume, *bind mount*, `tmpfs` ou rien ?

Pour chaque donnée, choisis l'un des quatre et dis pourquoi en une phrase :

1. Une base de données de test qu'un service utilise et qui doit survivre à une mise à jour du conteneur.
2. Un fichier `config.yaml` que tu édites sur ton ordinateur et que le conteneur ne fait que lire.
3. Les fichiers de session d'un programme, qui sont régénérés à chaque démarrage.
4. Le code source d'un programme pendant que tu le développes et le testes dans un conteneur.
5. Le binaire du `revisor`.
6. Le rapport du `revisor`, qu'un autre outil de ton équipe, en dehors de Docker, va récupérer toutes les heures.

### Exercice 2 — Lis le `no such host`

Sans rien exécuter, dis quelle situation réseau a produit chaque message et avec quelle commande tu la corrigerais. Les deux viennent du `revisor`, qui cherche un conteneur qui **est bien** en marche :

```text
A) … lookup curso-docker-prueba on <DNS del anfitrión>:53: no such host
B) … lookup curso-docker-prueba on 127.0.0.11:53: no such host
```

Question bonus : dans le cas B, quelles autres causes, au nombre de deux et sans rapport avec les réseaux, donneraient exactement le même message ?

### Exercice 3 — Le rapport qui survit (projet)

Dans ton dossier, avec l'état final de 8.10.3 en marche, fais cette séquence et, **avant** chaque étape, prédis le résultat :

1. Demande le tableau une fois : `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'`.
2. Supprime le conteneur du `revisor` avec `docker rm -f curso-docker-revisor`.
3. Lis le rapport avec un auxiliaire, sans aucun `revisor` en marche.
4. Recrée le `revisor` avec la commande de 8.10.3, **sans** le `docker network connect`, et demande le tableau.
5. Avec ce `revisor` en marche, essaie `docker volume rm curso-docker-reportes`.
6. Connecte-le au réseau interne et demande de nouveau le tableau.

### Exercice 4 — `volume-nocopy`

Prédis ce qui se passe si tu exécutes l'image `curso-docker-revisor:1.5.0`, durcie, avec un **nouveau** volume monté ainsi :

```text
--mount type=volume,src=curso-docker-sin-copia,dst=/datos,volume-nocopy
```

Que répond `/api/estados` ? À qui appartient `/datos` à l'intérieur du volume ? Vérifie-le en publiant le port sur `127.0.0.1:8081` (ou en arrêtant d'abord ton `curso-docker-revisor`, qui occupe le `8080`), et dis comment cela se rapporte à l'erreur de 8.3. Question bonus : comment écrit-on la même chose avec `-v` ? À la fin, supprime le conteneur et le volume.

## Solutions

### Solution 1

1. **Volume nommé.** Il doit durer plus longtemps que le conteneur et personne n'a besoin de toucher les fichiers manuellement. C'est le cas du rapport.
2. ***Bind mount* en lecture seule.** C'est toi qui l'édites sur ton ordinateur et le conteneur ne fait que le lire ; avec `readonly`, le conteneur ne peut pas le modifier même s'il le voulait.
3. **`tmpfs` avec une taille.** Il ne doit pas survivre au conteneur, et ainsi il n'occupe pas de disque et ne laisse aucune trace.
4. ***Bind mount***. C'est toi qui l'édites et le conteneur doit voir le changement sur-le-champ. C'est l'usage que la documentation donne en exemple. (Dans un conteneur qui ne fait que l'exécuter, en lecture seule.)
5. **Rien : il va dans l'image.** C'est du code (Leçon 6). Le monter depuis l'extérieur ferait que l'image testée ne serait pas celle qui tourne.
6. ***Bind mount*** **d'un dossier à toi**, avec `--user` de tes nombres, comme en 8.6. Un outil de ton ordinateur extérieur à Docker a besoin de le lire à un chemin à toi, sans `sudo`. Avec un volume, il faudrait passer par un conteneur auxiliaire.

### Solution 2

- **A)** La question a été posée au DNS de ton ordinateur : le `revisor` est dans le **réseau par défaut**, qui n'a pas de DNS de conteneurs. Correction : créer un réseau (`docker network create curso-docker-red`) et exécuter les deux conteneurs avec `--network curso-docker-red`, ou les y connecter avec `docker network connect`.
- **B)** La question a été posée au DNS intégré (`127.0.0.11`) : le `revisor` **est bien** dans un réseau défini par l'utilisateur, mais le service de test n'est dans aucun de ses réseaux. C'est ce que tu as vu dans le bloc 2 de `fig08_08.sh`. Correction : `docker network connect <le réseau de l'autre> curso-docker-revisor` (ou connecter l'autre au réseau du `revisor`).

Question bonus : le même message sort si le nom est **mal écrit** dans `REVISOR_SERVICIOS` (le DNS ne devine pas), ou si l'autre conteneur **ne tourne pas** : le DNS intégré ne répond que pour les noms des conteneurs connectés à ce moment-là. `docker ps --filter name=curso-docker-` répond aux deux doutes.

### Solution 3

Les étapes 2 et 5 et le premier tableau de l'étape 4 ont été mesurés avec le même ordinateur et la même version de Docker que la leçon, dans les scripts `fig08_03.sh` et `fig08_08.sh` (avec le suffixe `-fig08` dans les noms) ; les autres s'en déduisent, et dans ton dossier ils doivent sortir ainsi :

1. `200`, et le tableau indique `prueba OK`.
2. Le conteneur disparaît ; le volume, non (bloc 4 de `fig08_03.sh`).
3. L'auxiliaire (`docker run --rm -v curso-docker-reportes:/datos:ro alpine:3.24.2 cat /datos/reporte.json`) doit afficher le dernier rapport, en JSON. Dans le bloc 4 de `fig08_03.sh`, le service s'appelait `propio` ; dans ton état final, il doit s'appeler `prueba`, avec `"ok": true` et `"codigo": 200`.
4. Le tableau indique `FALLA` avec `lookup curso-docker-prueba on 127.0.0.11:53: no such host`, comme dans le bloc 2 de `fig08_08.sh` : le `revisor` est dans un réseau à toi, et le service de test, dans un autre.
5. `docker volume rm` refuse : `volume is in use`, avec l'identifiant du conteneur entre crochets, et il sort avec le code `1` (bloc 3 de `fig08_03.sh`).
6. Après le `docker network connect`, `OK` (bloc 3 de `fig08_08.sh`).

### Solution 4

C'est le script `fig08_09.sh`, qui teste l'option avec `--mount` et avec `-v` :

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

C'est l'erreur de 8.3 avec la bonne image. L'image 1.5.0 apporte `/datos` appartenant à `65532`, mais `volume-nocopy` dit à Docker de ne rien copier dans le nouveau volume, et ce qui n'est pas copié inclut le propriétaire : le volume naît avec son dossier appartenant à `root`, comme quand l'image n'apportait pas le dossier (bloc 3 de `fig08_04.sh`). La leçon : la correction de 8.4 dépend de la copie au premier montage. Tout ce qui l'empêche (`volume-nocopy` au premier montage, ou un volume qui contient déjà quelque chose et qui, pour cette raison, l'emporte sur l'image) ramène le `permission denied`. Un volume qui existait déjà mais est vide ne l'empêche pas : on a mesuré qu'il reçoit quand même le dossier.

Question bonus : avec `-v`, l'option s'écrit `nocopy` (bloc 3). Le nom de `--mount` ne marche pas avec `-v` : Docker 29.2.1 le rejette avec `invalid mode: volume-nocopy` et le code `125`, même si la page des volumes le documente sous ce nom (bloc 2). C'est un bon exemple de la raison pour laquelle le cours exécute chaque commande au lieu de la copier de la documentation.

## Comment je sais que j'ai réussi

Coche chaque point uniquement si tu sais le faire **sans revenir au texte** :

- [ ] Dans ton dossier, `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.5.0` montre `REVISOR_REPORTE=/datos/reporte.json`, et `docker create` + `docker export` + `tar -tv --numeric-owner` montrent `datos/` avec le propriétaire `65532/65532`.
- [ ] Tu provoques le `permission denied` avec l'image 1.4.0 et un nouveau volume, et tu l'expliques en utilisant les mots *propriétaire*, `0` et `65532`.
- [ ] Le rapport survit à `docker rm -f curso-docker-revisor` : tu le lis avec un auxiliaire en lecture seule.
- [ ] Tu expliques avec un exemple quand le contenu d'un dossier est **copié** au montage et quand il est **masqué**, et pourquoi `--mount` est plus sûr que `-v` pour un *bind mount*.
- [ ] Tu exécutes le `revisor` avec un *bind mount* d'un dossier à toi et `--user "$(id -u):$(id -g)"`, et `stat` montre que le rapport est à toi.
- [ ] Un conteneur avec `--read-only` écrit dans un volume et dans un `tmpfs` avec `size`, et après `docker restart` le fichier du volume est toujours là et celui du `tmpfs`, non.
- [ ] Tu montres le `no such host` dans le réseau par défaut et le `OK` dans un réseau à toi, et tu dis quel serveur DNS utilise chacun (le `/etc/resolv.conf` d'un auxiliaire).
- [ ] L'état final de 8.10.3 est en marche : le service de test uniquement dans `curso-docker-interna`, le `revisor` dans les deux, le tableau en `OK`, et un auxiliaire dans le réseau interne reçoit `bad address` quand il essaie de sortir.
- [ ] Tu exécutes les scripts de [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes) et tes sorties coïncident avec celles de cette leçon, à l'exception des durées, des dates, des numéros d'utilisateur et de groupe de ton ordinateur et de ce que les scripts masquent à la vue de tous. (Les scripts publient sur le `8081`, donc ils n'entrent pas en collision avec ton `revisor` sur le `8080`.) Et à la fin, `docker ps -a --filter name=fig08`, `docker volume ls --filter name=fig08` et `docker network ls --filter name=fig08` n'affichent rien.

## Résumé

Réponds sans regarder la leçon :

1. Qu'est-ce que la couche accessible en écriture d'un conteneur, et quels trois problèmes pose-t-elle pour conserver le rapport du `revisor` ?
2. Quelle différence y a-t-il entre un volume nommé, un *bind mount* et un `tmpfs`, quant à l'endroit où vivent les données et à leur durée ?
3. Pourquoi un nouveau volume monté sur un dossier que l'image n'apporte pas donne-t-il `permission denied` avec un utilisateur sans privilèges ?
4. Que fait `COPY --chown=65532:65532`, et pourquoi la correction dépend-elle du fait que le volume soit nouveau et vide ?
5. Quand le contenu d'un dossier est-il copié et quand est-il masqué, lorsqu'on monte quelque chose par-dessus ?
6. Que fait `-v` et que fait `--mount` quand le dossier de l'ordinateur n'existe pas ?
7. Comment corriges-tu le `permission denied` d'un *bind mount* sans `root` et sans `777` ?
8. Pourquoi, dans le réseau par défaut, un conteneur ne trouve-t-il pas un autre par son nom, et qu'est-ce qui change dans un réseau défini par l'utilisateur ?
9. Qu'est-ce que `127.0.0.11`, et que t'apprend le fait de voir cette adresse dans un `no such host` ?
10. Que coupe un réseau `--internal`, que ne coupe-t-il pas, et pourquoi le port du `revisor` est-il publié par l'autre réseau ?

## Sources

Toutes consultées le 21 octobre 2026.

- [Docker, « Storage »](https://docs.docker.com/engine/storage/) : le fait que ce qui est écrit dans la couche du conteneur ne persiste pas et est difficile à extraire ; les types de montage (y compris les montages d'image) et quand utiliser chacun.
- [Docker, « Volumes »](https://docs.docker.com/engine/storage/volumes/) : la copie du contenu de l'image vers un volume vide et l'option `volume-nocopy` ; le fait qu'un volume contenant des données masque ce qui s'y trouvait ; le fait que `--mount` est préféré ; le chemin `/var/lib/docker/volumes/<nom>/_data` ; le fait que les volumes survivent au conteneur et que les anonymes sont supprimés avec `--rm`.
- [Docker, « Bind mounts »](https://docs.docker.com/engine/storage/bind-mounts/) : le fait qu'ils masquent le contenu existant ; le fait que `-v` crée le dossier et que `--mount` ne le fait pas, par défaut, avec le texte `bind source path does not exist`, et l'option `bind-create-src` ; le fait qu'ils donnent par défaut un accès en écriture à l'hôte ; l'option `readonly`.
- [Référence de `docker volume prune`](https://docs.docker.com/reference/cli/docker/volume/prune/) : le fait que, par défaut, il ne supprime que les volumes anonymes et que `-a` supprime tous ceux qui ne sont pas utilisés.
- [Docker, « tmpfs mounts »](https://docs.docker.com/engine/storage/tmpfs/) : le fait qu'un `tmpfs` vit en mémoire et disparaît à l'arrêt du conteneur ; le fait qu'il n'est pas partagé ; sa taille maximale (50 % de la mémoire) et sa permission (`1777`) par défaut ; le fait que `--mount` est préféré ; l'avertissement sur la mémoire d'échange.
- [Docker, « Networking »](https://docs.docker.com/engine/network/) : le serveur DNS intégré sur `127.0.0.11` et la transmission des requêtes externes ; le fait que les conteneurs du réseau par défaut reçoivent une copie du `/etc/resolv.conf` de l'hôte ; les réseaux internes pour les services sans accès externe.
- [Docker, pilote `bridge`](https://docs.docker.com/engine/network/drivers/bridge/) : les différences entre le réseau par défaut et ceux définis par l'utilisateur (DNS automatique, isolement, connexion à chaud) et le fait que le réseau par défaut est un vestige hérité non recommandé pour la production.
- [Référence de `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/) : l'option `--internal` et le mode interne (pas de route par défaut, trafic vers d'autres réseaux rejeté, passerelle joignable et hôte qui, lui, atteint les conteneurs).
- [Docker, pilote `host`](https://docs.docker.com/engine/network/drivers/host/) : le fait que le conteneur n'a ni réseau propre ni adresse IP et que les ports publiés sont ignorés avec un avertissement.
- [Docker, liens hérités](https://docs.docker.com/engine/network/links/) : le fait que `--link` dans le réseau par défaut est obsolète et prévu pour être supprimé dans Engine 30.0.
- [Référence du Dockerfile](https://docs.docker.com/reference/dockerfile/) : `COPY --chown` et le propriétaire `0` par défaut ; l'instruction `VOLUME` et son volume initialisé avec le contenu de l'image.
- [Référence de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/) : `-v`, `--mount`, `--tmpfs`, `--network` et `--user`.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions et les dates de « À propos des exécutions ».
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| ***bind mount*** | montage d'un dossier ou d'un fichier de l'ordinateur à l'intérieur du conteneur ; le conteneur voit exactement cela, avec son propriétaire et ses permissions |
| **couche accessible en écriture** | la couche propre à chaque conteneur, au-dessus de celles de l'image ; elle est supprimée avec le conteneur |
| **conteneur auxiliaire** | conteneur jetable (`--rm`) qui sert à regarder un volume ou un réseau ; ici, `alpine:3.24.2` |
| **DNS intégré** | serveur de noms que Docker place sur `127.0.0.11` à l'intérieur des conteneurs des réseaux définis par l'utilisateur |
| **réseau défini par l'utilisateur** | réseau créé avec `docker network create` ; fournit des noms par DNS et isole des autres conteneurs |
| **réseau interne** | réseau créé avec `--internal` ; ses conteneurs se parlent entre eux, mais ne sortent ni vers d'autres réseaux ni vers internet |
| **réseau par défaut** (`bridge`) | le réseau auquel Docker connecte un conteneur si tu n'en indiques pas un autre ; sans noms, seulement des adresses IP |
| **`tmpfs`** | montage qui vit en mémoire, avec une taille, et disparaît quand le conteneur s'arrête |
| **volume nommé** | stockage géré par Docker qui survit aux conteneurs ; il se crée, se liste et se supprime avec `docker volume` |
| **volume anonyme** | volume sans nom, créé par `VOLUME` ou par `-v /chemin` ; difficile à reconnaître et facile à oublier |

---

**Suivante :** [Leçon 9 — Compose : le système complet](09-compose.md)
