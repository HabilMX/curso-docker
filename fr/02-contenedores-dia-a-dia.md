# Leçon 2 — Les conteneurs au quotidien

Il reste douze minutes avant la démonstration et le service ne démarre pas. Tu tapes la même commande qui fonctionnait hier et Docker te répond par une ligne en anglais se terminant par `port is already allocated`. Tu réessaies et maintenant le message est différent : `The container name ... is already in use`. Quelqu'un à tes côtés suggère de redémarrer l'ordinateur. Avant de le faire, tu lances `docker ps -a` et l'écran se remplit : des conteneurs de la semaine dernière, certains arrêtés, d'autres tournant encore, l'un d'eux publié sur le port 9000 **pour quiconque se trouve sur le même réseau sans fil du café** où tu as travaillé mardi. Personne ne l'a fait par malveillance. Simplement, personne n'a appris à démarrer, examiner, arrêter et supprimer des conteneurs avec méthode. Il te reste dix minutes, et cette leçon est ce qu'il t'aurait fallu savoir.

**Durée :** 2 × 45 min

**Ce que tu construis :** le service de test du cours qui tourne dans un conteneur, avec son port publié uniquement pour ta machine et avec des limites de mémoire, de CPU et de processus ; tu l'interroges dans ses trois modes (sain, lent et en panne), tu lis son journal, tu l'inspectes, tu l'arrêtes et tu le supprimes. À la fin, il ne reste aucun conteneur du cours sur ta machine ; l'image `curso-docker-prueba:1.0.0`, en revanche, reste, car les leçons suivantes l'utilisent à nouveau.

**Ce que tu apprends :** les commandes du quotidien — `run`, `ps`, `logs`, `exec`, `inspect`, `stats`, `stop`, `start` et `rm` — ; ce que signifie publier un port et pourquoi, dans ce cours, on publie toujours sur `127.0.0.1` ; comment fixer des limites de mémoire, de CPU et de processus et comment vérifier qu'elles ont bien été appliquées ; le cycle de vie d'un conteneur (créé, en cours d'exécution, arrêté, supprimé) ; et comment nettoyer uniquement ce qui t'appartient sans toucher à ce qui est aux autres.

**D'où tu viens.** De la [Leçon 0](00-que-es-un-contenedor.md), tu apportes la carte : un conteneur est un processus isolé, l'image est le modèle et le conteneur la copie vivante, et le client `docker` demande tout au daemon par un *socket*. De la [Leçon 1](01-instalacion.md), tu apportes Docker installé sur ton Mint et ton utilisateur dans le groupe `docker`, en sachant que cela équivaut à `root`. Tu as aussi besoin du dépôt du cours sur ta machine : tu vas y utiliser le dossier `programas/servicio-prueba/`, qui apporte le service de test déjà écrit avec son `Dockerfile` prêt. Tu n'as pas besoin de connaître Go ni de savoir lire ce `Dockerfile` pour l'instant.

**Ce que cette leçon ne fait pas.** Elle n'écrit aucun `Dockerfile` : celui du service de test est utilisé tel quel, et apprendre à le lire est le travail des Leçons 3 à 5. Elle ne touche pas encore au `revisor`, le projet principal du cours, car pour le faire tourner il faut d'abord l'empaqueter, et cela commence à la [Leçon 3](03-primer-dockerfile.md). Elle n'explique pas non plus les volumes ni les réseaux entre conteneurs ; ici, chaque conteneur vit seul et on lui parle depuis ta machine.

**À propos des exécutions.** Les sorties de cette leçon ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle Linux avec Ubuntu 24.04.4 (la même base que Linux Mint 22), sur processeur ARM 64 bits. Les scripts ont été exécutés **à l'intérieur de cette machine virtuelle**, avec Docker 29.2.1 (client et daemon, API 1.53). Le client du Mac était la 29.8.2, la version avec laquelle le cours a été planifié, et la plus récente publiée ce jour-là était la 29.9.2, du 20 octobre 2026, d'après les [notes de version officielles](https://docs.docker.com/engine/release-notes/29/). Trois avertissements sur la façon dont les exécutions ont été menées. **Premièrement :** sur cette machine, plusieurs leçons du cours étaient écrites en même temps, si bien que, pour éviter les collisions, les exécutions ont utilisé des noms avec un préfixe spécifique (`curso-docker-l02-` au lieu de `curso-docker-`) et les ports 18020 et 18021 au lieu de 9000 et 9001. Dans les sorties que tu lis ici, et dans les fichiers `.salida.txt` des programmes, on a rétabli les noms et les ports que tu vas utiliser, et on a réajusté les espacements des tableaux, car la largeur de chaque colonne dépend du nom le plus long ; rien d'autre n'a été touché. C'est une exception à la règle du cours de ne pas modifier une sortie, et elle a été prise à dessein : exécuter les scripts avec les vrais noms sur cette machine partagée aurait été dangereux, et pas seulement inconfortable, car le `trap` de chaque script supprime `curso-docker-prueba` en sortant, et ce conteneur aurait pu être celui d'une autre leçon en train de tourner à ce moment-là. Sur ton Mint, il n'y a personne d'autre, et les scripts tournent tels qu'ils sont écrits. **Deuxièmement :** la sortie de `fig02_01.sh` est celle de la première construction, quand l'image n'existait pas encore ; l'image de base de Go était déjà téléchargée, donc la construction de la section 2.1 ne montre pas de téléchargements ; lors de ta première exécution, tu verras d'abord le téléchargement des deux images de base, celle de Go et la minimale, et cela prendra plus de temps. **Troisièmement :** ce qui change sur ton Mint, c'est l'architecture (`amd64` au lieu d'`arm64` si ton processeur est un Intel ou un AMD), les identifiants, les durées et la mémoire totale rapportée par `docker stats`. Les solutions des exercices qui citent une sortie ont également été vérifiées sur cette machine, avec le même préfixe. Les programmes se trouvent dans [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia), chacun avec sa sortie enregistrée à côté.

## À la fin, tu seras capable de

- Construire l'image du service de test avec une seule commande et la trouver avec `docker image ls`.
- Démarrer un conteneur en arrière-plan avec un nom, un port publié sur `127.0.0.1` et des limites de mémoire, de CPU et de processus, et expliquer chaque option de la commande.
- Lister tes conteneurs avec `docker ps`, les filtrer par nom et choisir quelles colonnes afficher.
- Lire le journal d'un conteneur avec `docker logs`, en entier ou seulement ses dernières lignes, et exécuter un programme à l'intérieur avec `docker exec`.
- Vérifier avec `docker inspect` et `docker stats` que les limites ont bien été appliquées, et avec `ss` sur quelles interfaces écoute ta machine.
- Lire et résoudre les deux erreurs du quotidien : nom répété et port déjà occupé.
- Arrêter, redémarrer et supprimer des conteneurs, et laisser ta machine sans aucun conteneur `curso-docker-` en terminant.

## Le pourquoi avant le comment

Dans la Leçon 0, tu as vu les conteneurs de l'intérieur, pour comprendre ce qu'ils sont. Il s'agit maintenant de faire l'inverse : les utiliser tous les jours sans penser aux espaces de noms ni aux groupes de contrôle. Et ici apparaît un problème qui n'a rien de technique et qui fait plus de dégâts que bien des erreurs du noyau : **le désordre**.

Un conteneur est très facile à créer. Un simple `docker run` suffit. Et, comme il ne fait pas de bruit, il est très facile à oublier. Au bout d'une semaine de tests, tu as des conteneurs arrêtés qui occupent du disque, des conteneurs en cours d'exécution qui occupent de la mémoire et des ports, et des noms que tu ne peux plus réutiliser. Le pire n'est pas le disque : c'est que l'un d'eux est resté à l'écoute sur toutes les interfaces réseau de ta machine, sans que tu le saches. La scène du début n'a pas été causée par une erreur rare ; elle a été provoquée par trois habitudes que personne n'a corrigées : publier des ports sans préciser où, tourner sans limites et ne pas nettoyer.

Cette leçon te donne la panoplie complète de commandes pour gérer un conteneur du début à la fin, et avec chaque commande, l'habitude qui évite le désordre. Tu vas le faire avec le **service de test** du cours, un tout petit serveur HTTP conçu pour échouer exprès. Il possède trois modes : en mode **sain**, il répond `200` immédiatement ; en mode **lent**, il attend trois secondes puis répond `200` ; en mode **en panne**, il répond `503`, le code HTTP signifiant « service indisponible ». Et l'on change de mode à chaud, sans le redémarrer, à l'aide d'une requête `POST`. Ce service sera, tout au long du cours, la cible surveillée par le `revisor` ; ici, il te sert de banc d'essai sans risque, et tout ce que tu fais avec lui, tu le répéteras avec le `revisor` : quand tu l'empaqueteras dans la Leçon 3, tu le démarreras avec ce même type de commande, en changeant simplement le nom, l'image et le port 8080. Et il te sert à constater une idée que le cours martèle : **ce n'est pas parce qu'un conteneur indique « Up » que le service est sain**.

La leçon se déroule dans cet ordre :

1. **Construire l'image** du service de test (2.1), en commençant par faire une erreur.
2. **Démarrer** un conteneur et comprendre chaque partie de la commande (2.2).
3. **L'examiner** : `ps` (2.3), l'interroger (2.4) et lire son journal avec `logs` (2.5).
4. **Y entrer**, ou essayer, avec `exec` (2.6).
5. **L'inspecter** avec `inspect` et `stats` (2.7).
6. **Les ports** : `127.0.0.1` contre toutes les interfaces (2.8), et **les limites** (2.9).
7. **Le cycle de vie** : arrêter, redémarrer et supprimer (2.10), et **ne pas laisser de déchets** (2.11).

Voici la commande à laquelle tu vas aboutir. À la fin de la leçon, chaque mot aura sa justification :

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

## Les concepts

### 2.1 Construire l'image du service de test

#### 2.1.1 D'abord, l'erreur

Pour faire tourner un conteneur, il te faut une image. Avant de la construire, il vaut la peine de voir ce qui se passe si tu sautes cette étape, car c'est une erreur que tu rencontreras souvent : quelqu'un te transmet une commande, tu la colles et l'image n'existe pas sur ta machine. `fig02_01.sh` fait précisément cela, puis construit l'image :

```bash
#!/usr/bin/env bash
# fig02_01.sh — Correr una imagen que todavía no existe, y después construirla.
# Primero el error (la imagen no está en tu equipo ni en Docker Hub); luego el
# único comando que necesitas para construir el servicio de prueba.
set -uo pipefail
cd "$(dirname "$0")/.."          # la carpeta programas/, donde está servicio-prueba/
IMAGEN=curso-docker-prueba:1.0.0
# Si la imagen ya existía, el bloque 1 no falla y SÍ crea un contenedor: se borra al salir.
trap 'docker rm -f curso-docker-prueba >/dev/null 2>&1 || true' EXIT

echo "== 1. Correr la imagen antes de construirla"
docker run -d --name curso-docker-prueba "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Construirla: un solo comando"
docker build -t "$IMAGEN" servicio-prueba
echo "código de salida: $?"

echo
echo "== 3. La imagen ya está en tu equipo"
docker image ls "$IMAGEN"

echo
echo "== 4. Y el intento fallido no dejó contenedores"
docker ps -a --filter name=curso-docker-prueba --format '{{.Names}} {{.Status}}' | wc -l
```

Le script utilise `set -uo pipefail` et non `set -euo pipefail` comme ceux de la Leçon 0 : nous avons retiré le `-e` exprès, car la première commande **doit** échouer et nous voulons que le script continue. `cd "$(dirname "$0")/.."` se déplace vers le dossier `programas/`, qui est là où se trouve `servicio-prueba/`, d'où que tu lances le script. Et le `trap ... EXIT` programme la suppression du conteneur en sortant : la première fois, il n'y a rien à supprimer, mais si tu relances le script avec l'image déjà construite, le bloc 1 n'échoue plus, crée le conteneur et le `trap` l'enlève. Voici la première partie de la sortie :

```text
$ ./fig02_01.sh
== 1. Correr la imagen antes de construirla
Unable to find image 'curso-docker-prueba:1.0.0' locally
docker: Error response from daemon: pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'

Run 'docker run --help' for more information
código de salida: 125
```

Elle se lit en deux temps. La première ligne dit que l'image ne se trouve pas **sur ta machine** (*locally*). Ce n'est pas encore une erreur : quand `docker run` ne trouve pas une image, il la cherche dans un registre, qui par défaut est Docker Hub. La documentation l'explique à propos de l'option `--pull`, dont la valeur par défaut est `missing` : elle ne télécharge l'image que si elle n'est pas déjà présente sur ta machine ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). La deuxième ligne constitue la véritable erreur : Docker Hub ne possède aucun dépôt public nommé `curso-docker-prueba` et tu ne lui as pas fourni d'identifiants, si bien qu'il a refusé le téléchargement. Le message ne peut pas savoir laquelle des deux situations se présente — qu'il n'existe pas ou qu'il soit privé —, c'est pourquoi il mentionne les deux.

Le code de sortie **125** a lui aussi une signification précise. La documentation de Docker réserve trois codes : 125 signifie que l'erreur provient du daemon Docker lui-même ; 126, que la commande du conteneur n'a pas pu être invoquée ; et 127, que la commande du conteneur est introuvable. Tout autre nombre correspond au code avec lequel s'est terminé le programme à l'intérieur ([Docker, « Running containers »](https://docs.docker.com/engine/containers/run/)). Ici, le conteneur n'a même pas vu le jour : c'est Docker qui a échoué, pas le service. Tu verras un code 127 à la section 2.6.

> [!NOTE]
> 🔧 **Observation de génie logiciel 2.1**
> L'ordre de recherche a une conséquence directe sur la sécurité. Si tu te trompes en tapant le nom d'une de tes images et qu'il existe par hasard une image publique portant ce nom, Docker va la télécharger et la lancer sans te demander ton avis. Le risque se situe surtout avec les noms comportant un utilisateur ou une organisation, comme `quelquun/image`, car dans ces espaces n'importe qui peut publier ; un nom simple en une seule partie, comme celui de ce cours, est cherché parmi les images officielles de Docker Hub. C'est pourquoi il convient que les noms de tes images locales soient sans équivoque ; le préfixe `curso-docker-` de ce cours remplit ce rôle, en plus de permettre de nettoyer ce qui t'appartient à l'aide d'un filtre (2.11).

#### 2.1.2 Une seule commande pour la construire

Le service de test est livré avec sa recette rédigée : le fichier `programas/servicio-prueba/Dockerfile`. Le construire tient en une seule commande :

```bash
docker build -t curso-docker-prueba:1.0.0 servicio-prueba
```

Elle comporte deux parties. `-t curso-docker-prueba:1.0.0` attribue un **nom et un tag** à l'image résultante : le nom est `curso-docker-prueba` et le tag, ce qui suit les deux-points, est `1.0.0`. Et `servicio-prueba`, à la fin, est le dossier que Docker utilise comme **contexte** : c'est là qu'il cherche le `Dockerfile` et qu'il prend les fichiers que la recette demande de copier. La Leçon 4 est entièrement dédiée au contexte ; ici, il suffit de savoir qu'il s'agit d'un dossier.

La sortie de la construction est longue ; en voici la partie centrale (le fichier complet se trouve dans `fig02_01.salida.txt`) :

```text
== 2. Construirla: un solo comando
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 836B done
#1 DONE 0.0s
[…]
#6 [1/4] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#6 resolve docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c 0.0s done
#6 DONE 0.0s
[…]
#12 [compilacion 4/4] RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/servicio-prueba .
#12 DONE 32.9s

#13 [stage-1 2/2] COPY --from=compilacion /out/servicio-prueba /servicio-prueba
#13 DONE 0.1s

#14 exporting to image
[…]
#14 naming to docker.io/library/curso-docker-prueba:1.0.0 done
#14 unpacking to docker.io/library/curso-docker-prueba:1.0.0 0.1s done
#14 DONE 0.5s
código de salida: 0
```

Il n'est pas nécessaire de tout comprendre ligne par ligne aujourd'hui, mais retiens trois éléments. La construction progresse par **étapes numérotées** (`#1`, `#2`…) et chacune indique combien de temps elle a pris : la plus longue, 32,9 secondes, est celle qui compile le programme en Go à l'intérieur d'une image fournissant le compilateur. À la fin apparaît `naming to docker.io/library/curso-docker-prueba:1.0.0` : le nom court que tu as donné est, sous sa forme complète, celui d'une image de Docker Hub dans la bibliothèque officielle (`library`), même s'il n'est jamais question de la publier où que ce soit ; c'est ainsi que Docker nomme tout ce qui ne précise pas de registre explicite. Et le code de sortie est **0** : tout s'est bien déroulé. Les Leçons 3, 4 et 5 t'apprendront à lire ce fichier ligne par ligne.

#### 2.1.3 Trouver l'image

```text
== 3. La imagen ya está en tu equipo
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE                       ID             DISK USAGE   CONTENT SIZE   EXTRA
curso-docker-prueba:1.0.0   06306fe8744c   15.1MB       3.37MB

== 4. Y el intento fallido no dejó contenedores
0
```

Si tu as l'habitude d'anciens tutoriels, ce tableau te paraîtra inhabituel. Depuis la version 29.0, `docker image ls` présente par défaut une nouvelle vue, « comme `--tree`, mais repliée », et masque les images sans tag à moins de demander `--all` ([notes de version de Docker Engine 29](https://docs.docker.com/engine/release-notes/29/)). La page de référence de la commande montre encore les colonnes précédentes (`REPOSITORY`, `TAG`, `IMAGE ID`, `CREATED`, `SIZE`) ([docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/)), ne sois donc pas surpris si ta sortie ne correspond pas à un tutoriel. L'avertissement `WARNING` de la première ligne te l'indique directement : cette vue est pensée pour être lue par un être humain ; si tu dois traiter la sortie dans un script, utilise `--format`, comme le fait le reste de cette leçon.

La colonne qu'utilise ce cours pour désigner la taille d'une image est **DISK USAGE** : 15.1 MB est ce que l'image occupe sur ton disque. La colonne **CONTENT SIZE** est plus petite ; tout indique qu'elle compte le contenu de l'image compressé, tel qu'il transite sur le réseau, mais la documentation de référence ne la décrit pas encore, si bien que dans ce cours nous ne l'utilisons pas. Avec un format personnalisé, on obtient directement la taille :

```bash
docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

Dans la sortie des exécutions du cours, cette commande a affiché `curso-docker-prueba:1.0.0 15.1MB`.

Le bloc 4 confirme un point crucial pour le nettoyage : le `docker run` avorté de la section 2.1.1 **n'a laissé aucun conteneur**. Faute d'image, il n'y avait rien à partir de quoi le créer. À la section 2.8, tu verras une erreur qui, elle, en laisse bel et bien un.

### 2.2 Démarrer un conteneur

#### 2.2.1 La commande, option par option

L'image étant prête, voici la commande de cette leçon :

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Lis-la de gauche à droite. Chaque option répond à une question à laquelle, si tu ne réponds pas, Docker répond pour toi, et presque jamais comme cela t'arrange :

| Option | Question à laquelle elle répond | Ce qui se passe si tu ne la mets pas |
|---|---|---|
| `-d` | me rends-tu le terminal ? | le conteneur reste attaché à ton terminal ; si tu le fermes ou fais Ctrl+C, il reçoit le signal |
| `--name curso-docker-prueba` | comment s'appelle-t-il ? | Docker invente un nom au hasard, comme `busy_goldwasser`, dont tu ne te souviendras pas |
| `-p 127.0.0.1:9000:9000` | qui peut lui parler, et par quel port ? | aucune autre machine, et toi seulement par l'adresse interne du conteneur, pas par `127.0.0.1` ; et si tu mets `-p 9000:9000` sans adresse, **quiconque sur ton réseau** |
| `--memory 64m` | combien de mémoire peut-il utiliser ? | toute celle de ta machine |
| `--cpus 0.5` | combien de CPU ? | tout |
| `--pids-limit 50` | combien de processus peut-il créer ? | autant qu'il veut |
| `curso-docker-prueba:1.0.0` | à partir de quelle image ? | (obligatoire) |

`-d` est la forme courte de `--detach` : selon la documentation, cela exécute le conteneur en arrière-plan et imprime son identifiant ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Sans `-d`, la sortie du service apparaît dans ton terminal et le terminal reste monopolisé jusqu'à ce que le conteneur s'arrête. Cela peut être utile pour un test rapide ; pour un serveur, presque jamais.

`--name` lui donne un nom. La documentation indique que si tu n'en fournis pas, le daemon en génère un au hasard ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Choisir un nom explicite sert à deux choses : taper `docker logs curso-docker-prueba` au lieu de copier un identifiant de 64 caractères, et te rappeler à qui appartient le conteneur. Mais cela a une conséquence : **sur un même daemon, il ne peut pas y avoir deux conteneurs portant le même nom**, même si l'un d'eux est arrêté. C'est la première erreur de la scène initiale, et tu vas la provoquer à la section 2.8.

`-p` est la forme courte de `--publish`, et comporte trois parties séparées par des deux-points : `adresse:port-de-l-hote:port-du-conteneur`. `127.0.0.1:9000:9000` signifie « sur ma machine, uniquement sur l'adresse `127.0.0.1` et sur le port 9000, reçois les connexions et transmets-les au port 9000 du conteneur ». Les deux numéros n'ont pas à être identiques : avec `127.0.0.1:18000:9000`, tu lui parlerais par le port 18000 et le service continuerait d'écouter sur son port 9000. Rappelle-toi de la Leçon 0 que chaque conteneur a son propre réseau. Sans `-p`, son port 9000 n'est joignable que depuis le réseau interne de Docker : depuis les autres conteneurs de ce réseau et depuis ta propre machine si tu utilises l'adresse interne du conteneur ; la documentation l'énonce ainsi : les ports des conteneurs sur les réseaux de type bridge sont accessibles depuis l'hôte même s'ils ne sont pas publiés ([Docker, « Port publishing and mapping »](https://docs.docker.com/engine/network/port-publishing/)). Ce qui n'est pas joignable sans `-p`, c'est le port depuis `127.0.0.1` de ta machine ou depuis n'importe quelle autre machine. La section 2.8 est consacrée à l'adresse, qui en est la partie cruciale.

`--memory`, `--cpus` et `--pids-limit` représentent le budget que la Leçon 0 t'a appris à lire dans `/sys/fs/cgroup`. La section 2.9 explique pourquoi ces valeurs.

#### 2.2.2 Le démarrer et attendre qu'il réponde

`fig02_02.sh` démarre le conteneur et fait avec lui ce que tu ferais lors d'une journée normale. Voici le script complet ; sa sortie est répartie dans les sections 2.2 à 2.5 :

```bash
#!/usr/bin/env bash
# fig02_02.sh — El servicio de prueba corriendo: arrancar, listar, consultar y leer su bitácora.
# Puerto publicado solo en 127.0.0.1 y con límites de memoria, CPU y procesos.
set -euo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Arrancar en segundo plano"
docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
# Esperar a que conteste (máximo 10 s), en vez de dormir un número fijo.
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo
echo "== 2. Lo que está corriendo"
docker ps --filter name="$NOMBRE" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== 3. Consultarlo en sus tres modos"
curl -s http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/caido
curl -s -w 'código HTTP: %{http_code}\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/lento
curl -s -w 'código HTTP: %{http_code} en %{time_total} s\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/sano
curl -s http://127.0.0.1:9000/modo

echo
echo "== 4. Su bitácora completa"
docker logs "$NOMBRE"

echo
echo "== 5. Solo los dos últimos renglones"
docker logs --tail 2 "$NOMBRE"
```

```text
$ ./fig02_02.sh
== 1. Arrancar en segundo plano
c516467655b6
```

La seule chose qu'affiche `docker run -d` est l'**identifiant** du conteneur, un nombre hexadécimal de 64 caractères ; le script le tronque aux 12 premiers avec `cut -c1-12`, ce qui correspond à la façon dont Docker l'affiche presque partout. Il change à chaque exécution. Qu'il apparaisse signifie que le conteneur a été créé et qu'on lui a demandé de démarrer ; cela **ne signifie pas** que le service à l'intérieur est déjà prêt à répondre.

C'est pourquoi la ligne suivante du script est une boucle : elle tente une requête avec `curl` toutes les demi-secondes, jusqu'à vingt fois, et s'arrête dès que l'une d'elles répond correctement. `curl -f` fait échouer `curl` si le serveur renvoie une erreur, `-s` le rend silencieux et `-o /dev/null` jette la réponse. C'est bien supérieur à un `sleep 3` figé, pour deux raisons : sur un ordinateur rapide, tu n'attends pas inutilement, et sur une machine lente, tu ne poursuis pas prématurément. Tu retrouveras ce motif dans tous les scripts du cours qui communiquent avec le service ; là où l'on ne lui parle pas, attendre n'est pas nécessaire.

Le `trap ... EXIT` en haut du script relève du même réflexe que dans la Leçon 0 : quoi qu'il arrive, le script supprime son conteneur en se terminant. Dans les scripts de cette leçon, tu le verras systématiquement, car la section 2.11 en fait une règle incontournable.

### 2.3 Voir ce qui tourne : `docker ps`

```text
== 2. Lo que está corriendo
NAMES                 IMAGE                       STATUS                            PORTS
curso-docker-prueba   curso-docker-prueba:1.0.0   Up 2 seconds (health: starting)   127.0.0.1:9000->9000/tcp
```

`docker ps` liste les conteneurs. Par défaut, il n'affiche que **ceux qui sont en cours d'exécution** ; avec `-a` (`--all`), il montre également ceux qui sont arrêtés ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). C'est cette différence qui masque les déchets : un conteneur arrêté n'apparaît pas dans `docker ps`, mais il continue d'exister, consomme du disque et bloque son nom.

Le script emploie deux options qu'il est bon d'adopter dès maintenant. `--filter name=curso-docker-prueba` ne conserve que les conteneurs dont le nom contient cette chaîne ; la documentation précise que le filtre `name` correspond à « tout ou partie » du nom ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). Et `--format 'table ...'` choisit les colonnes : `{{.Names}}`, `{{.Image}}`, `{{.Status}}` et `{{.Ports}}` sont des champs, et le mot `table` au début demande des en-têtes et des colonnes alignées. Ce qui se trouve entre doubles accolades est un modèle du langage Go ; tu n'as pas besoin de connaître Go pour t'en servir, seulement les noms des champs répertoriés sur la page de la commande. Il existe d'autres filtres utiles ; celui d'état, par exemple, accepte `created`, `restarting`, `running`, `removing`, `paused`, `exited` et `dead` ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)).

Les colonnes, une par une :

- **NAMES** est le nom que tu lui as attribué.
- **IMAGE**, l'image dont il est issu.
- **STATUS** indique `Up 2 seconds` : il tourne depuis deux secondes. Et il comporte une mention supplémentaire, `(health: starting)`, qui mérite son propre paragraphe.
- **PORTS** indique `127.0.0.1:9000->9000/tcp` : le port 9000 de ta machine, uniquement sur `127.0.0.1`, redirige vers le port 9000 du conteneur, en TCP.

La mention `(health: starting)` apparaît parce que le `Dockerfile` du service de test comporte une instruction `HEALTHCHECK` : elle ordonne à Docker d'exécuter, toutes les cinq secondes à l'intérieur du conteneur, la sous-commande `servicio-prueba healthcheck`, qui demande au service lui-même s'il répond correctement. Tant que la première vérification n'est pas achevée, l'état reste `starting` ; ensuite, il passera à `healthy` ou `unhealthy`. Aujourd'hui, tu ne t'en serviras que pour le constater ; la façon d'écrire un contrôle de santé et ce que Docker en fait est le sujet de la Leçon 7. Mais remarque dès à présent que **`Up` et l'état de santé (health) sont deux choses distinctes** : `Up` indique que le processus existe ; l'état de santé indique s'il est en état de servir. La section suivante en fait la démonstration.

### 2.4 Parler avec le service

```text
== 3. Consultarlo en sus tres modos
sano
modo: caido
caido
código HTTP: 503
modo: lento
lento
código HTTP: 200 en 3.081298 s
modo: sano
modo: sano
```

Lis chaque paire de lignes comme une question et sa réponse :

1. `GET /` en mode sain répond `sano`.
2. `POST /modo/caido` change de mode et confirme `modo: caido`. Dès cet instant, `GET /` renvoie le texte `caido` avec le code **503**. L'option `-w` de `curl` imprime des données sur la requête après la réponse ; ici, le code HTTP.
3. `POST /modo/lento` et le `GET /` suivant prend **3,08 secondes** à répondre `lento` avec un code 200. Les trois secondes correspondent au délai du mode lent ; le reste est le temps d'aller-retour. Ce chiffre varie légèrement à chaque exécution ; lors d'une autre exécution du cours, il a affiché 3,003 secondes.
4. `POST /modo/sano` le ramène à la normale, et `GET /modo` le confirme.

Maintenant, la question essentielle. Pendant que le service répondait `503`, qu'indiquait `docker ps` ? Il indiquait `Up`. Pour Docker, le conteneur se portait à merveille : le processus existait et ne s'était pas arrêté. Pour quiconque tentait de l'utiliser, il était hors service. **Docker ignore ce que répond ton service**, à moins que tu ne le lui apprennes par un contrôle de santé. C'est le principe que le cours répète à chaque leçon : un conteneur en cours d'exécution n'est pas un service sain. Le `revisor`, le projet que tu vas empaqueter dès la Leçon 3, existe très exactement pour poser cette question depuis l'extérieur.

### 2.5 Le journal : `docker logs`

```text
== 4. Su bitácora completa
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: modo cambiado a caido
servicio-prueba: GET / en modo caido
servicio-prueba: modo cambiado a lento
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano

== 5. Solo los dos últimos renglones
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano
```

Tout ce que le programme principal du conteneur écrit sur sa **sortie standard** et sur sa **sortie d'erreurs** — ce que tu verrais dans ton terminal avec `printf` ou `echo` —, Docker le conserve, et `docker logs` te le restitue. La documentation le décrit ainsi : la commande fournit les enregistrements présents au moment de son exécution, et avec `--follow`, elle continue de diffuser en direct ce qui sort sur `STDOUT` et `STDERR` du conteneur ([docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/)).

Remarque que le journal raconte l'histoire complète de la section précédente, dans l'ordre : le démarrage, les deux premières requêtes (celle de la boucle d'attente et la tienne), chaque changement de mode et chaque requête avec son mode respectif. Les requêtes vers `/modo` ne laissent pas de trace car le service ne les consigne pas ; un programme ne laisse dans le journal que ce que son auteur a choisi d'écrire. Et un avertissement : le contrôle de santé de l'image (2.3) effectue lui aussi un `GET /` toutes les cinq secondes, et chacun laisse sa ligne. Cette exécution a duré moins de cinq secondes, si bien qu'aucune n'apparaît ; dans un conteneur qui tourne depuis un moment, tu verras des lignes `GET / en modo …` que tu n'as pas demandées. C'est Docker qui les a sollicitées.

Les options que tu utiliseras au quotidien, toutes issues de la [page de la commande](https://docs.docker.com/reference/cli/docker/container/logs/) :

| Option | Ce qu'elle fait |
|---|---|
| `--tail N` (ou `-n N`) | seulement les N dernières lignes ; par défaut, toutes |
| `--follow` (ou `-f`) | reste à l'écoute et affiche le flux au fur et à mesure ; on quitte avec Ctrl+C |
| `--since 10m` | seulement ce qui date des dix dernières minutes ; accepte aussi une date et une heure |
| `--timestamps` (ou `-t`) | préfixe chaque ligne avec l'heure à laquelle Docker l'a reçue |

`--tail` a plus d'importance qu'il n'y paraît. Un service tournant depuis des semaines peut accumuler des millions de lignes, et un `docker logs` sans restriction inondera ton terminal. La bonne pratique consiste à taper d'abord `docker logs --tail 50 <nom>`, puis `-f` si tu souhaites continuer à surveiller.

Deux mises en garde qui t'épargneront des déconvenues. **Le journal survit à `docker stop`, mais pas à `docker rm` :** il vit avec le conteneur, tu peux donc le consulter après l'avoir arrêté (tu le verras en 2.10) et il disparaît quand tu le supprimes. Si un conteneur est mort de manière inexpliquée, **lis son journal avant de le supprimer**. Et **`docker logs` ne voit que ce que le programme principal écrit sur ses deux sorties standard** : si le programme consigne ses traces dans un fichier à l'intérieur du conteneur, `docker logs` n'y a pas accès. C'est pourquoi les programmes conçus pour les conteneurs, comme le service de test et le `revisor`, écrivent tout sur la sortie standard.

### 2.6 Entrer dans le conteneur : `docker exec`

#### 2.6.1 L'image n'a pas de shell

Dans les tutoriels, tu liras souvent cette commande : `docker exec -it <nom> sh`, « pour entrer dans le conteneur ». `docker exec` exécute un programme **à l'intérieur** d'un conteneur déjà en train de tourner ; `-i` maintient l'entrée standard ouverte et `-t` lui alloue un terminal pour pouvoir taper des commandes ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)). Essaie avec le service de test, ce que fait `fig02_03.sh` (sans `-it`, car dans un script personne n'est au clavier) :

```bash
#!/usr/bin/env bash
# fig02_03.sh — exec: ejecutar un programa dentro de un contenedor que ya corre.
# La imagen del servicio de prueba no trae shell: se ve el error y lo que sí funciona.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Pedir un shell"
docker exec "$NOMBRE" sh
echo "código de salida: $?"

echo
echo "== 2. Ejecutar un programa que la imagen SÍ trae"
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 3. Lo mismo, con el servicio en modo caído"
curl -s -X POST http://127.0.0.1:9000/modo/caido >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 4. exec en un contenedor detenido"
docker stop "$NOMBRE" >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"
```

```text
$ ./fig02_03.sh
== 1. Pedir un shell
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
código de salida: 127

== 2. Ejecutar un programa que la imagen SÍ trae
sano
código de salida: 0

== 3. Lo mismo, con el servicio en modo caído
no sano: GET / respondió 503
código de salida: 1

== 4. exec en un contenedor detenido
Error response from daemon: container 78614f9ea0da425237a13924f63235bf6a1e45629efd4000d3764b5c54e23dcb is not running
código de salida: 1
```

Le premier bloc montre l'erreur. Lis-le de droite à gauche, comme se lisent presque toutes les erreurs Docker : la cause se trouve à la fin. `exec: "sh": executable file not found in $PATH` indique qu'il n'existe aucun programme nommé `sh` dans les dossiers où le système cherche les exécutables. La mention précédente, `OCI runtime exec failed`, signale qui l'a découvert : `runc`, le programme qui crée les processus des conteneurs (rencontré dans la Leçon 0). Et le code **127**, comme vu en 2.1.1, est réservé par Docker pour signifier « commande introuvable ».

Il ne s'agit pas d'un défaut du conteneur : c'est un choix délibéré d'architecture. L'image du service de test a été construite sur une base minimale, de la famille dite *distroless*, qui **n'embarque que le programme et le strict nécessaire à son fonctionnement** : elle ne contient ni `sh`, ni `ls`, ni `cat`, ni gestionnaire de paquets. Cela a un prix, que tu viens de constater : tu ne peux pas « t'y introduire » pour fureter. Mais cela apporte un gain, que la Leçon 5 met à profit pour le `revisor` : si quelqu'un parvenait à exécuter du code dans ce conteneur, il n'y trouverait aucun outil pour aller plus loin. Une image sans shell est une image offrant beaucoup moins de prise à une attaque.

#### 2.6.2 Ce que l'on peut faire

Le deuxième bloc montre qu'`exec` fonctionne parfaitement avec un programme que l'image **possède** bel et bien : `/servicio-prueba` lui-même, avec sa sous-commande `healthcheck`. Le programme interroge le service qui tourne à ses côtés pour savoir s'il répond, affiche `sano` et se termine avec 0. Le troisième bloc répète la question alors que le service est en mode en panne : `no sano: GET / respondió 503`, et se termine avec 1. Cette sous-commande est exactement celle que l'instruction `HEALTHCHECK` lance toutes les cinq secondes ; tu viens de l'exécuter manuellement. Remarque qu'ici le code n'est pas 127 mais 1 : le programme a bien été trouvé et exécuté ; il a simplement répondu « non ».

Deux règles concernant `exec` issues de sa documentation ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)) :

- **Il ne fonctionne que tant que le processus principal du conteneur est en cours d'exécution.** C'est l'objet du quatrième bloc : avec le conteneur arrêté, le daemon répond `container ... is not running`. Pour analyser ce qui est arrivé à un conteneur arrêté, on n'utilise pas `exec`, on emploie `logs` et `inspect`.
- **La commande doit être un exécutable**, et non une ligne de shell complexe. `docker exec <nom> "echo hola && ls"` ne fonctionnera pas ; si l'image dispose d'un shell, on écrira `docker exec <nom> sh -c 'echo hola && ls'`.

Quand l'image comporte effectivement un shell, comme l'image `alpine:3.24.2` de la Leçon 0, la commande classique fonctionne et te laisse la main à l'intérieur :

```bash
docker run -d --name curso-docker-dormilon --memory 16m --cpus 0.25 --pids-limit 20 \
  alpine:3.24.2 sleep 300
docker exec -it curso-docker-dormilon sh
```

Utilise-la pour **observer**, jamais pour **réparer**. Tu l'as appris dans la Leçon 0 : ce que tu modifies là-dedans réside dans la couche propre au conteneur et disparaîtra avec lui. Et supprime le conteneur quand tu as fini : `docker rm -f curso-docker-dormilon`.

### 2.7 Ce que Docker sait d'un conteneur : `inspect` et `stats`

#### 2.7.1 `docker inspect` avec un modèle

`docker inspect` renvoie des « informations de bas niveau » sur un objet Docker ([docker inspect](https://docs.docker.com/reference/cli/docker/inspect/)) : tout ce que le daemon sait à son sujet, au format JSON. C'est considérable. `fig02_04.sh` l'utilise avec des modèles pour n'extraire que ce qui compte, et compare le conteneur pourvu de limites à un conteneur équivalent sans limites :

```bash
#!/usr/bin/env bash
# fig02_04.sh — inspect y stats: lo que Docker sabe de un contenedor, con y sin límites.
set -euo pipefail
CON=curso-docker-prueba
SIN=curso-docker-sin-limites
trap 'docker rm -f "$CON" "$SIN" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CON" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name "$SIN" curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

FORMATO='{{.Name}}: memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}'

echo "== 1. inspect, con una plantilla: solo los campos que me importan"
docker inspect --format "$FORMATO" "$CON" "$SIN"

echo
echo "== 2. inspect: estado, puerto publicado y comando principal"
docker inspect --format 'estado={{.State.Status}} pid1={{.Config.Entrypoint}} puertos={{json .HostConfig.PortBindings}}' "$CON"

echo
echo "== 3. stats: lo que gastan ahora mismo, contra su límite"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.PIDs}}' "$CON" "$SIN"

echo
echo "== 4. Cuántos renglones trae inspect completo"
docker inspect "$CON" | wc -l
```

```text
$ ./fig02_04.sh
== 1. inspect, con una plantilla: solo los campos que me importan
/curso-docker-prueba: memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532
/curso-docker-sin-limites: memoria=0 cpus(nano)=0 pids=<no value> usuario=65532:65532

== 2. inspect: estado, puerto publicado y comando principal
estado=running pid1=[/servicio-prueba] puertos={"9000/tcp":[{"HostIp":"127.0.0.1","HostPort":"9000"}]}

== 3. stats: lo que gastan ahora mismo, contra su límite
NAME                       MEM USAGE / LIMIT     PIDS
curso-docker-prueba        1.59MiB / 64MiB       8
curso-docker-sin-limites   1.496MiB / 15.59GiB   7

== 4. Cuántos renglones trae inspect completo
224
```

Tout le premier bloc est stable : ces valeurs ressortent à l'identique sur ton Mint. Analyse-les :

- `memoria=67108864` correspond à 64 × 1024 × 1024 octets : les 64 Mio demandés, le même nombre que la Leçon 0 avait lu dans `memory.max`.
- `cpus(nano)=500000000` : Docker stocke le CPU en milliardièmes de CPU ; 500 millions représentent un demi-CPU.
- `pids=50`, le plafond de processus.
- `usuario=65532:65532` : le service **ne tourne pas en tant que `root`**. Cela a été défini dans l'image par une instruction `USER`, que la Leçon 3 t'apprendra à écrire. Compare cela avec le `sleep` de la Leçon 0, qui s'exécutait sous l'utilisateur 0.

Et la ligne du conteneur sans limites indique `memoria=0`, `cpus(nano)=0` et `pids=<no value>`. Dans ce champ, **zéro ne signifie pas « aucune mémoire » : cela signifie « sans limite »**. C'est la façon dont Docker enregistre « tu ne m'as rien demandé ». `<no value>` est ce qu'affiche le modèle quand le champ n'existe même pas. Lorsque tu examines un conteneur tiers, un zéro ici est un signal d'alarme, non de sérénité.

Le nom s'affiche avec une barre oblique devant, `/curso-docker-prueba`. Ce n'est pas une faute de ta part : c'est ainsi que Docker conserve les noms en interne, et c'est pourquoi le message d'erreur de nom répété de la section 2.8 la comporte également.

Le deuxième bloc présente trois autres champs. `.State.Status` est l'état (`running`). `.Config.Entrypoint` est le programme que l'image démarre comme processus principal. Et `{{json .HostConfig.PortBindings}}` utilise la fonction `json` des modèles pour afficher un champ composite brut : le port 9000 du conteneur est lié à l'adresse `127.0.0.1`, port 9000, de ta machine.

Le quatrième bloc explique pourquoi l'on recourt aux modèles : le résultat d'`inspect` complet pour ce conteneur, qui est pourtant parmi les plus simples, totalise **224 lignes**. Le lire en entier est utile une fois, pour explorer son contenu. Pour obtenir une information précise, utilise un modèle.

#### 2.7.2 `docker stats` : ce qu'il consomme en ce moment même

`inspect` indique quelles sont les limites ; `docker stats` indique **combien il consomme actuellement**. Par défaut, il s'agit d'un écran qui s'actualise en continu, comme `top` ; avec `--no-stream`, il effectue un relevé unique et s'arrête, ce qui convient à un script ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)). La colonne **MEM USAGE / LIMIT** montre la mémoire utilisée par le conteneur par rapport à celle qui lui est allouée, et **PIDS** indique combien de processus et de threads il a créés ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)).

Le service de test consomme entre 1 et 2 Mio et possède quelques threads (8 lors de cette exécution, 6 lors d'une autre ; ce nombre fluctue). L'élément crucial réside dans la colonne de la limite. Avec limites, elle affiche `64MiB`. Sans limites, elle affiche `15.59GiB`, ce qui correspond à **toute la mémoire de la machine** où l'exécution a eu lieu (la machine virtuelle de Colima). Sur ton Mint, cette valeur représentera la mémoire de ton propre ordinateur. C'est la situation de la Leçon 0 vue sous l'angle de Docker : un conteneur sans limite a pour seule limite l'ordinateur tout entier.

### 2.8 Les ports : `127.0.0.1` contre toutes les interfaces

#### 2.8.1 Ce que signifie l'adresse

Ton ordinateur dispose de plusieurs **interfaces réseau**, qui sont autant de portes par lesquelles entrent les connexions : celle du réseau sans fil, éventuellement celle du câble réseau, et une interface spéciale appelée ***loopback*** (bouclage local), associée à l'adresse `127.0.0.1`. L'interface de bouclage ne mène nulle part en dehors de ta machine : ce qui y entre ne peut provenir que de ton propre ordinateur.

Quand tu publies un port sans spécifier d'adresse, avec `-p 9000:9000`, Docker le publie **sur toutes les interfaces**. La documentation le formule sans détour : si tu ne donnes pas d'adresse, le daemon publie les ports sur toutes les adresses de l'hôte, `0.0.0.0` et `[::]`, et avertit dans un encadré que « publier les ports d'un conteneur est non sécurisé par défaut », car le port se retrouve à la portée non seulement de l'hôte mais « du monde extérieur » ([Docker, « Port publishing and mapping »](https://docs.docker.com/engine/network/port-publishing/)). Avec `127.0.0.1` devant, « seul l'hôte peut accéder » au port publié (même source). Cela s'applique depuis Docker 28 : la même page signale que, dans les versions antérieures à la 28.0.0, les machines du même segment réseau pouvaient atteindre les ports publiés sur `127.0.0.1`. C'est une raison de plus pour installer Docker depuis le dépôt officiel, comme vu dans la Leçon 1, et non une version obsolète.

`fig02_05.sh` lance deux instances du service, une sous chaque configuration, et interroge Docker et le système d'exploitation pour voir où elles se sont positionnées :

```bash
#!/usr/bin/env bash
# fig02_05.sh — Publicar en 127.0.0.1 contra publicar en todas las interfaces.
# Se corre en el anfitrión (tu Mint): ss lista los puertos en los que escucha el equipo.
set -euo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-abierto >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name curso-docker-abierto -p 9001:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for p in 9000 9001; do
  for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.5; done
done

echo "== 1. Lo que dice docker port"
echo "-- curso-docker-prueba:"; docker port curso-docker-prueba
echo "-- curso-docker-abierto:"; docker port curso-docker-abierto

echo
echo "== 2. Lo que dice el sistema operativo: dónde escucha el equipo"
ss -ltn | grep -E ':900[01] ' | awk '{print $4}' | sort
```

```text
$ ./fig02_05.sh
== 1. Lo que dice docker port
-- curso-docker-prueba:
9000/tcp -> 127.0.0.1:9000
-- curso-docker-abierto:
9000/tcp -> 0.0.0.0:9001
9000/tcp -> [::]:9001

== 2. Lo que dice el sistema operativo: dónde escucha el equipo
0.0.0.0:9001
127.0.0.1:9000
[::]:9001
```

`docker port` montre, pour un conteneur donné, quel port interne est associé à quelle adresse et quel port de ta machine. `ss -ltn` est un outil Linux standard qui liste les ports sur lesquels la machine écoute les connexions TCP (`-l` pour écoute/*listening*, `-t` pour TCP, `-n` avec des nombres au lieu des noms de services) ; le `grep` ne retient que les lignes concernant les ports 9000 et 9001, et le `awk` isole la colonne de l'adresse.

Les deux sources concordent. Le conteneur convenablement publié écoute **uniquement** sur `127.0.0.1:9000`. L'autre écoute sur `0.0.0.0:9001`, ce qui signifie en réseau « sur toutes les adresses IPv4 de cette machine », et sur `[::]:9001`, la même chose pour IPv6. Si ton Mint est connecté au réseau d'un café, d'une université ou d'un bureau, n'importe qui sur ce réseau peut saisir l'adresse de ton ordinateur, le port 9001, et communiquer avec ton conteneur. Le service de test est inoffensif ; une base de données de test avec un mot de passe par défaut ne l'est pas.

#### 2.8.2 Le pare-feu ne te sauve pas

Tu pourrais penser qu'un pare-feu est là pour te protéger. Sur Mint, le pare-feu de bureau est `ufw`. Voici le piège : **les ports publiés par Docker passent outre les règles de `ufw`**. La documentation de référence de `docker run` met en garde : les ports publiés sur toutes les interfaces restent accessibles depuis l'extérieur même si `ufw` est configuré pour les bloquer, car Docker gère ses propres règles de filtrage de paquets ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Le guide sur les pare-feux de Docker explique le mécanisme : le trafic destiné à un conteneur « est dérouté avant de passer par la configuration de `ufw` » et les paquets sont acheminés « avant que les règles du pare-feu ne puissent s'appliquer » ([Docker, « Packet filtering and firewalls »](https://docs.docker.com/engine/network/packet-filtering-firewalls/)).

Ne teste pas cela sur ton réseau sans autorisation. Il suffit d'en avoir conscience et d'en tirer la conclusion : **la sécurité réside dans le `-p`, non dans le pare-feu**. C'est pourquoi, dans ce cours, tous les ports sont publiés avec `127.0.0.1:` devant, et le seul qui en soit dépourvu est le `9001` de ce script, qui n'existe que pour que tu puisses le constater et qui est détruit dès la fin.

> [!NOTE]
> 🔧 **Observation de génie logiciel 2.2**
> Un port publié par inadvertance ne prévient pas. Aucun message ne s'affiche pour dire « ce conteneur est désormais exposé sur votre réseau ». La seule manière de s'en assurer est de vérifier : regarder la colonne PORTS de `docker ps` (y chercher `0.0.0.0` ou `[::]`) ou exécuter `ss -ltn` sur la machine. Fais-en un réflexe chaque fois que tu te connectes à un réseau qui n'est pas le tien.

### 2.9 Les limites : mémoire, CPU et processus

La Leçon 0 t'a montré le fonctionnement interne des limites : Docker écrit un nombre dans un fichier du noyau et le noyau le fait respecter. Ici, la question est pratique : **quels chiffres choisir**.

La documentation de Docker est explicite sur ce qui se produit en l'absence de limite : un conteneur « ne fait l'objet d'aucune restriction de ressources » et s'accapare tout ce que l'ordonnanceur du noyau lui accorde ; et lorsque la machine vient à manquer de mémoire, le noyau commence à tuer des processus — n'importe quel processus, y compris Docker lui-même —, ce qui « peut faire s'effondrer l'ensemble du système si le mauvais processus est éliminé » ([Docker, « Resource constraints »](https://docs.docker.com/engine/containers/resource_constraints/)). Les trois limites de la commande de cette leçon :

**`--memory 64m`.** Le service de test utilise entre 1 et 2 Mio (tu l'as mesuré en 2.7.2). Lui accorder 64 Mio lui offre une marge supérieure à trente fois son besoin. La règle générale est la suivante : **mesure d'abord, puis fixe une limite confortable au-dessus de la mesure**, jamais en dessous. Si le programme franchit cette limite, le noyau le tue au sein de son propre cgroup, comme vu dans la Leçon 0 (code 137 et `OOMKilled=true`), et personne d'autre sur ta machine n'est affecté. La documentation impose un minimum de 6 Mo pour cette option ([Docker, « Resource constraints »](https://docs.docker.com/engine/containers/resource_constraints/)).

**`--cpus 0.5`.** Un demi-CPU. Un service qui ne fait que répondre à de petites requêtes n'a besoin de rien de plus, et s'il s'enferme dans une boucle infinie à la suite d'un bogue, il consommera un demi-CPU et non la totalité. La documentation l'illustre par son propre exemple : sur une machine pourvue de deux CPU, `--cpus="1.5"` garantit au conteneur au maximum un CPU et demi ([Docker, « Resource constraints »](https://docs.docker.com/engine/containers/resource_constraints/)). À la différence de la mémoire, dépasser l'allocation de CPU ne tue personne : le noyau lui accorde simplement moins de temps d'exécution, et le programme ralentit.

**`--pids-limit 50`.** Définit le plafond de processus pour le conteneur ; avec `-1`, la limite est supprimée ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Cette limite protège d'un incident très concret : un programme qui, par erreur ou par malveillance, crée des processus en continu. Sans plafond, il peut saturer la table des processus de la machine et t'empêcher ne serait-ce que d'ouvrir un terminal. Le service en comptait 8 (2.7.2) ; 50 lui laisse une marge amplement suffisante.

Remarque que ces trois limites sont appliquées **dès le tout premier conteneur**, et non « une fois le service en production ». La Leçon 0 l'a illustré avec la mésaventure de la base de données : une limite n'est pas faite pour les jours ordinaires, elle est faite pour les jours de panne, et les pannes ne préviennent pas.

### 2.10 Le cycle de vie : arrêter, redémarrer et supprimer

#### 2.10.1 Les états

Un conteneur passe par plusieurs états, et chaque commande le fait transiter de l'un à l'autre :

| État | Comment il y parvient | Ce que l'on voit dans `docker ps -a` |
|---|---|---|
| créé (`created`) | `docker create`, ou un `docker run` qui n'a pas pu démarrer | `Created` |
| en cours d'exécution (`running`) | `docker run` ou `docker start` | `Up …` |
| arrêté (`exited`) | `docker stop`, ou le programme principal s'est terminé seul | `Exited (código) …` |
| supprimé | `docker rm` | il n'apparaît plus |

Le point essentiel de ce tableau est la distinction entre **arrêté** et **supprimé**. Un conteneur arrêté ne tourne pas, mais il existe : il conserve sa couche d'écriture, son journal, sa configuration et son nom. Il peut être redémarré. Un conteneur supprimé n'existe plus, et sa couche ainsi que son journal disparaissent avec lui.

`fig02_07.sh` parcourt le cycle complet et s'achève par le contrôle de nettoyage :

```bash
#!/usr/bin/env bash
# fig02_07.sh — El ciclo de vida completo y la limpieza: stop, start, rm y --rm.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" curso-docker-efimero >/dev/null 2>&1 || true' EXIT
ms() { date +%s%3N; }

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Borrar un contenedor que está corriendo, sin -f"
docker rm "$NOMBRE"
echo "código de salida: $?"

echo
echo "== 2. Detenerlo, midiendo cuánto tarda"
inicio=$(ms); docker stop "$NOMBRE" >/dev/null; fin=$(ms)
echo "docker stop tardó $(( fin - inicio )) ms"
docker ps -a --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'
docker logs --tail 2 "$NOMBRE"

echo
echo "== 3. Detenido no es borrado: vuelve a arrancar con start"
docker start "$NOMBRE" >/dev/null
docker ps --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'

echo
echo "== 4. Ahora sí: borrarlo"
docker stop "$NOMBRE" >/dev/null
docker rm "$NOMBRE"

echo
echo "== 5. Un contenedor con --rm se borra solo al terminar"
# Lo que va después de la imagen reemplaza al comando por omisión: aquí, en vez
# de servir, el programa corre su subcomando healthcheck y termina.
docker run --rm --name curso-docker-efimero curso-docker-prueba:1.0.0 healthcheck
echo "código de salida: $?"
docker ps -a --filter name=curso-docker-efimero --format '{{.Names}}' | wc -l

echo
echo "== 6. La revisión final: ningún contenedor del curso"
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

```text
$ ./fig02_07.sh
== 1. Borrar un contenedor que está corriendo, sin -f
Error response from daemon: cannot remove container "curso-docker-prueba": container is running: stop the container before removing or force remove
código de salida: 1

== 2. Detenerlo, midiendo cuánto tarda
docker stop tardó 242 ms
curso-docker-prueba Exited (0) Less than a second ago
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando

== 3. Detenido no es borrado: vuelve a arrancar con start
curso-docker-prueba Up Less than a second (health: starting)

== 4. Ahora sí: borrarlo
curso-docker-prueba

== 5. Un contenedor con --rm se borra solo al terminar
no sano: Get "http://127.0.0.1:9000/": dial tcp 127.0.0.1:9000: connect: connection refused
código de salida: 1
0

== 6. La revisión final: ningún contenedor del curso
0
```

Les durées varient à chaque exécution ; tout le reste sort à l'identique.

#### 2.10.2 `docker rm` ne supprime pas ce qui tourne

Le premier bloc fait office de garde-fou : Docker refuse de supprimer un conteneur en cours d'exécution. Le message t'indique les deux voies possibles : l'arrêter au préalable (*stop the container before removing*) ou forcer la suppression (*force remove*). Forcer correspond à `docker rm -f`, et la documentation précise son action : elle envoie un signal `SIGKILL` au processus principal, puis supprime le conteneur ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)). `SIGKILL` est le signal 9, celui que la Leçon 0 t'a appris à reconnaître via le code 137 : il ne peut pas être intercepté, si bien que le programme n'a aucune possibilité de fermer proprement ses fichiers ou connexions. Pour un conteneur de test jetable, cela convient, et les `trap` de ces scripts y recourent. Pour un service manipulant des données, d'abord `stop`.

#### 2.10.3 `docker stop` : le signal et le délai

`docker stop` est la manière polie. La documentation indique qu'il transmet au processus principal le signal `SIGTERM` (à moins que l'image ou le conteneur n'en configure un autre), patiente pendant un délai — fixé par défaut à **10 secondes** sous Linux — et, si le conteneur est toujours actif, l'élimine avec `SIGKILL`. Ce délai peut être modifié avec `--timeout` ([docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/)).

Le deuxième bloc prouve que le service de test s'arrête convenablement. `docker stop` n'a mis que **242 ms**, bien en dessous des 10 secondes imparties (lors d'une autre exécution du cours, il a mis 120 ms, et 199 ms sur une autre encore). L'état est `Exited (0)` : le programme s'est terminé de lui-même avec le code 0, synonyme sous Linux de fin normale sans erreur. Et le journal, qui subsiste après l'arrêt, en livre l'explication : `recibí terminated, apagando`. Le service est programmé pour intercepter `SIGTERM` (*terminated* étant le nom donné par Go à ce signal) : il le reçoit, cesse d'accepter des requêtes et se termine proprement. Si le programme ignorait ce signal, tu verrais `docker stop` patienter 10 secondes pour aboutir à l'état `Exited (137)`. La raison pour laquelle un programme ne reçoit parfois pas le signal, alors même qu'il est conçu pour le traiter, constitue un problème réel bien connu, celui du processus numéro 1, que la Leçon 7 aborde en détail.

#### 2.10.4 `docker start` : arrêté n'est pas supprimé

Le troisième bloc relance le même conteneur à l'aide de `docker start`. Inutile de réécrire les options : le nom, le port et les limites sont restés enregistrés dans le conteneur. `docker start` sert à reprendre l'exécution de ce qui avait été arrêté ; pour modifier une option (un autre port, une autre limite), il faut supprimer le conteneur et en créer un nouveau avec `docker run`. Le quatrième bloc procède au nettoyage dans les règles de l'art : `stop` puis `rm`, lequel renvoie le nom de ce qu'il a supprimé.

#### 2.10.5 `--rm` : des conteneurs qui se suppriment tout seuls

Pour les conteneurs destinés à n'exécuter qu'une tâche ponctuelle avant de s'arrêter, il existe l'option `--rm` : d'après la documentation, elle supprime automatiquement le conteneur et ses volumes anonymes dès qu'il se termine (les volumes font l'objet de la Leçon 8) ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Le cinquième bloc l'emploie avec une particularité : après le nom de l'image figure le mot `healthcheck`. **Ce qui est inscrit après l'image est transmis en argument au programme principal**, ce qui transforme ici le service en son propre client : au lieu d'écouter les requêtes, le programme exécute son contrôle d'état de santé et s'arrête. Comme personne n'écoute sur le port 9000 à l'intérieur de ce conteneur précis, la vérification échoue avec `connection refused` et renvoie le code 1. Et le `0` affiché ensuite confirme que le conteneur a déjà disparu : `--rm` l'a supprimé.

Un détail constaté lors de la rédaction de cette leçon : avec `docker run -d --rm`, la suppression intervient **une fraction de seconde après** l'arrêt du conteneur, et non avant le retour de `docker stop`. Dans une version initiale de ce script qui enchaînait `docker stop` sur un conteneur `-d --rm` et un comptage immédiat, le total affichait `1` : le conteneur arrêté subsistait encore quelques millisecondes. C'est pourquoi le script recourt à la forme sans `-d`, dans laquelle `docker run` ne rend la main qu'une fois le conteneur achevé et supprimé. Si un jour l'un de tes scripts dénombre les conteneurs immédiatement après en avoir arrêté un avec `--rm`, tu sauras d'où provient ce compte inattendu.

### 2.11 Ne pas laisser de déchets

#### 2.11.1 Rien que ce qui est à toi

Le sixième bloc de `fig02_07.sh` correspond à la vérification que tu mèneras à la fin de chaque leçon de ce cours :

```bash
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

`-a` inclut les conteneurs arrêtés, qui sont ceux que l'on a tendance à oublier. Le filtre `name=^curso-docker-` n'isole que les conteneurs dont le nom **commence** par `curso-docker-` : l'accent circonflexe `^` marque le début du nom. La documentation se bornant à indiquer que le filtre correspond à tout ou partie du nom, cela a été vérifié lors de l'écriture de cette leçon : sur une machine hébergeant dix conteneurs dont le nom comportait `dev-` au milieu, `--filter name=dev-` a trouvé les dix, tandis que `--filter name='^dev'` n'en a trouvé aucun. Sans ce `^`, un filtre sur `curso-docker-` intercepterait également un conteneur qui s'appellerait par exemple `viejo-curso-docker-x`. Et `wc -l` compte les lignes. Si le résultat est `0`, tu n'as rien laissé traîner.

Pour **supprimer** tout ce qui t'appartient d'un coup, cette même liste est passée en entrée à `docker rm -f` :

```bash
docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f
```

`-q` ne demande que les identifiants ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)), `xargs` les transmet en arguments à la commande suivante, et `-r` évite que `xargs` ne lance quoi que ce soit si la liste est vide.

Telle est la raison d'être de la règle du cours exigeant que **tout ce que tu crées commence par `curso-docker-`** : cela te permet de nettoyer exclusivement tes conteneurs sans jamais perturber le reste de la machine.

#### 2.11.2 La commande qu'il ne faut pas utiliser à l'aveugle

Tôt ou tard, tu liras dans un tutoriel la commande `docker container prune`. Elle fait exactement ce qu'annonce sa documentation : elle « supprime **tous** les conteneurs arrêtés » ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). Absolument tous : les tiens, ceux d'autres projets présents sur la même machine et ceux créés par des outils qui s'appuient sur Docker sous le capot. Un conteneur arrêté peut très bien être la base de données d'un autre projet, mise en sommeil volontairement avec toute sa configuration préservée. `prune` ne cherche pas à savoir à qui appartient quoi ; il se contente de demander une fois « êtes-vous sûr ? », et avec `--force`, même pas. Il accepte des filtres par label ou par ancienneté, mais aucun filtre par nom ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). La documentation de `docker rm` la suggère certes pour vider tous les conteneurs arrêtés ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)) ; c'est acceptable sur un serveur dédié à une tâche unique. Sur ta propre machine, privilégie le filtre par nom : supprime uniquement ce que tu sais t'appartenir. La même prudence s'impose pour ses cousines `docker system prune` et `docker volume prune`, dont l'effet destructeur est encore plus étendu.

> [!NOTE]
> 🔧 **Observation de génie logiciel 2.3**
> Nettoyer n'est pas une étape que l'on garde pour « la fin, si l'on a le temps ». Dans les scripts de cette leçon, le nettoyage est programmé **avant** de créer quoi que ce soit, au moyen de `trap ... EXIT`, afin qu'il s'exécute même si le script plante en cours de route. Adopte la même démarche dans ton travail quotidien : détermine la façon dont tu supprimeras un élément dès l'instant où tu le crées, jamais après.

## L'erreur que tu vas voir

Elles sont au nombre de deux, celles de la scène d'ouverture, et `fig02_06.sh` les provoque délibérément :

```bash
#!/usr/bin/env bash
# fig02_06.sh — Los dos errores de todos los días: nombre repetido y puerto ocupado.
# Ojo con el segundo: el contenedor que falla SÍ queda creado.
set -uo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-otro >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null

echo "== 1. Otro contenedor con el MISMO nombre"
docker run -d --name curso-docker-prueba curso-docker-prueba:1.0.0
echo "código de salida: $?"

echo
echo "== 2. Otro contenedor en el MISMO puerto"
docker run -d --name curso-docker-otro -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. ¿Qué quedó?"
docker ps -a --filter name='^curso-docker-' --format 'table {{.Names}}\t{{.Status}}'
```

```text
$ ./fig02_06.sh
== 1. Otro contenedor con el MISMO nombre
docker: Error response from daemon: Conflict. The container name "/curso-docker-prueba" is already in use by container "c0117bd0d82f44831263964f4f0c3e80262188eee2be39287f270aef5b82cc4d". You have to remove (or rename) that container to be able to reuse that name.

Run 'docker run --help' for more information
código de salida: 125

== 2. Otro contenedor en el MISMO puerto
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint curso-docker-otro (482400ed3eb7fd3dab4753f6c5bf95038ed4b93f2b80fd70c3ac301e5f8059c2): Bind for 127.0.0.1:9000 failed: port is already allocated

Run 'docker run --help' for more information
1dad19130213
código de salida: 125

== 3. ¿Qué quedó?
NAMES                 STATUS
curso-docker-otro     Created
curso-docker-prueba   Up Less than a second (health: starting)
```

Les identifiants longs changent à chaque exécution ; les messages et les codes de sortie sortent à l'identique. `${PIPESTATUS[0]}` est une variable de *bash* qui conserve le code de sortie de la **première** commande d'un tube ; elle est indispensable ici, car `$?` renverrait celui de `cut`.

**Le nom déjà utilisé.** Le message est limpide : il y a un conflit (*Conflict*), le nom `/curso-docker-prueba` est déjà attribué au conteneur portant tel identifiant, et pour réutiliser ce nom, tu dois supprimer ou renommer ce conteneur. Code **125** : c'est Docker qui a échoué, pas le service. Le piège réside dans le fait que le conteneur détenant le nom **peut être arrêté** : il n'apparaît pas dans `docker ps`, mais seulement dans `docker ps -a`. La solution, par ordre de préférence : si l'ancien ne sert plus, `docker rm` (ou `docker rm -f` s'il tourne encore) ; si tu souhaites le garder, `docker rename <ancien> <nouveau>` ; ou choisis un autre nom pour le nouveau.

**Le port déjà occupé.** Lis de droite à gauche : la cause racine est `port is already allocated`, le port est déjà pris ; la tentative était `Bind for 127.0.0.1:9000`, la liaison à cette adresse et ce port ; et l'entité qui tentait cette opération était la configuration réseau du conteneur `curso-docker-otro`. À nouveau le code **125**. Pour savoir qui détient le port, consulte la colonne PORTS de `docker ps` ; s'il ne s'agit pas d'un conteneur, `ss -ltnp` t'indiquera quel processus de ta machine l'utilise (l'option `p` demande le processus ; voir ceux des autres utilisateurs nécessite `sudo`). La solution : arrêter le processus ou conteneur qui l'occupe, ou publier le tien sur un autre port de ta machine (`-p 127.0.0.1:9002:9000`), ce qui ne change absolument rien au fonctionnement interne du conteneur.

**Et le détail dont personne ne te parle.** Remarque la mention `1dad19130213` qui apparaît après l'erreur de port : c'est l'identifiant d'un conteneur. `docker run -d` l'a imprimé parce que **le conteneur a bel et bien été créé** ; seul son démarrage a échoué. Le troisième bloc en apporte la confirmation : `curso-docker-otro` s'est retrouvé à l'état `Created`. Il ne tourne pas, ne consomme pas de mémoire, mais **il réserve son nom**. Si tu corriges le port et relances la commande avec le même nom, la prochaine erreur qui s'affichera sera celle du nom déjà utilisé, et tu croiras que Docker a perdu la tête. Pas du tout : ce sont deux erreurs en chaîne. Après une erreur « port déjà alloué », supprime immédiatement le conteneur résiduel : `docker rm curso-docker-otro`. Et ne tente pas de le ressusciter avec `docker start` une fois le port libéré : l'exercice 1 te démontre ce qui se produit alors.

L'erreur du nom en double liée à un conteneur **arrêté** et celle du port bloqué par son conteneur fantôme forment, à elles deux, le tableau de la scène initiale. Grâce à `docker ps -a` et au filtre de la section 2.11, elles se règlent en dix secondes.

## L'habitude de sécurité de la leçon

**Des ports publiés exclusivement sur `127.0.0.1`, des limites dès le premier conteneur, et jamais de `--privileged` ni de *socket* Docker monté à l'intérieur d'un conteneur.**

Tu as déjà mis en pratique les deux premières consignes. Publier sur `127.0.0.1` empêche qu'un conteneur de test ne soit accessible par quiconque partage ton réseau, et le pare-feu ne te protège en rien (2.8). Les limites évitent qu'un emballement dans un conteneur ne fasse planter les autres programmes de ta machine (2.9).

La troisième consigne est formulée ici parce que dans les tutoriels que tu croiseras au quotidien, tu trouveras des commandes qui la bafouent, et il importe de les repérer avant de les exécuter à l'aveugle. La Leçon 0 t'a enseigné que `--privileged` confère au conteneur toutes les capacités possibles ainsi que l'accès aux périphériques de l'hôte ([Docker, « Running containers »](https://docs.docker.com/engine/containers/run/)) : il n'y a pour ainsi dire plus de cloison. Et elle t'a montré que le daemon tourne en tant que `root` et que seuls des utilisateurs de confiance doivent pouvoir lui donner des ordres ([Docker Engine security](https://docs.docker.com/engine/security/)), au point que l'appartenance au groupe `docker` équivaut aux droits de `root` ([Docker, étapes post-installation sur Linux](https://docs.docker.com/engine/install/linux-postinstall/)). Monter le *socket* dans un conteneur — souvent présenté dans les tutoriels sous la forme `-v /var/run/docker.sock:/var/run/docker.sock` — donne très exactement ce pouvoir au conteneur : il peut demander au daemon de créer un autre conteneur montant le dossier racine de ta machine, avec les privilèges de `root`. Si une commande que tu t'apprêtes à copier comporte l'une ou l'autre de ces options, marque un temps d'arrêt et demande-toi si cela est véritablement indispensable. Dans ce cours, jamais.

## Ce qui se fait de travers

**Publier des ports sans spécifier d'adresse, « parce que c'est écrit comme ça dans l'exemple ».** `-p 9000:9000` publie sur toutes les interfaces réseau, et `ufw` ne le bloque pas. Écris systématiquement `-p 127.0.0.1:9000:9000`, et lorsque tu auras réellement besoin qu'une autre machine accède au conteneur, fais-en un choix délibéré et explicite.

**Exécuter sans limites « parce que ce n'est qu'un simple test ».** Les tests sont précisément l'endroit où le code contient des anomalies. `--memory`, `--cpus` et `--pids-limit` ne coûtent qu'une ligne.

**Interpréter `Up` comme « tout fonctionne ».** `Up` indique simplement que le processus existe. Tu l'as constaté en 2.4 : le service renvoyait des erreurs `503` et Docker continuait fièrement d'indiquer `Up`. Pour savoir si ton service est opérationnel, interroge le service lui-même.

**Se contenter de lancer `docker ps`.** Sans l'option `-a`, tu ne vois pas les conteneurs arrêtés, qui sont ceux qui monopolisent des noms et de l'espace disque. Pour faire le point sur ta machine, tape `docker ps -a`.

**Utiliser `docker exec` pour bricoler une réparation.** Tout ce que tu modifieras s'évaporera avec le conteneur. De plus, dans les images minimales comme celle du service de test, il n'y a même pas de shell, et c'est une excellente chose.

**Recourir à `docker rm -f` par automatisme.** Cela tue le conteneur d'un coup de `SIGKILL`, sans lui laisser la moindre chance de refermer proprement ce qu'il a d'ouvert. Pour tout ce qui manipule des données, utilise d'abord `docker stop`.

**Supprimer un conteneur en échec sans lire son journal.** Le journal disparaît avec lui. Commence toujours par `docker logs --tail 50`, puis procède au `rm`.

**Nettoyer avec `prune` sur une machine partagée.** Cela détruit les conteneurs de tout le monde. Filtre avec ton préfixe dédié.

**Laisser traîner le conteneur fantôme issu d'un conflit de port.** Il reste bloqué à l'état `Created` en retenant son nom ; supprime-le avant toute nouvelle tentative.

## Exercices

Les exercices 1 et 4 sont des exercices de réflexion ; le 2 et le 3 s'exécutent sur ton Mint. Écris tes prédictions dans ton [journal de bord](bitacora.md) avant de consulter les solutions.

### Exercice 1 — Prédire `docker ps -a`

Tu pars d'une machine exempte de tout conteneur `curso-docker-`. Tu exécutes ceci, dans l'ordre :

```bash
docker run -d --name curso-docker-a -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-b -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker stop curso-docker-a
docker run --rm --name curso-docker-c curso-docker-prueba:1.0.0 healthcheck
```

On a retiré les limites de ces commandes pour qu'elles tiennent sur la page et pour faciliter la lecture de la séquence ; sur ta machine, ajoute `--memory 64m --cpus 0.5 --pids-limit 50`, cela ne change rien aux réponses.

1. Laquelle ou lesquelles de ces quatre commandes se terminent-elles par une erreur, et avec quel code de sortie ?
2. Quels conteneurs apparaissent dans `docker ps -a --filter name=^curso-docker-`, et dans quel état ?
3. Si tu lances maintenant `docker start curso-docker-b`, démarre-t-il ? Pourquoi ?
4. Quelles deux commandes permettent de laisser la machine entièrement propre ?

### Exercice 2 — Un autre port, un autre budget

Démarre le service de test selon les conditions suivantes : nom `curso-docker-ejercicio`, tu dois pouvoir lui parler via le port **9002** de ta machine (uniquement depuis ta machine), et avec **32 Mio** de mémoire, un quart de CPU et 20 processus au maximum. Ensuite :

1. Vérifie avec `curl` qu'il répond `sano` sur le port 9002.
2. Prédis ce qu'afficheront `memoria=` et `cpus(nano)=` avec le modèle de `fig02_04.sh`, et vérifie-le.
3. Prédis ce qu'affichera `docker stats --no-stream` dans la colonne de la limite de mémoire.
4. Fais-le basculer en mode en panne et vérifie que `docker ps` continue d'afficher `Up`.
5. Nettoie tout pour laisser la machine propre.

### Exercice 3 — Le journal comme preuve (projet)

Imagine que le `revisor` a signalé à 10 h 04 que le service de test était en panne, et que tu souhaites le vérifier sans dépendre du `revisor`. Démarre le service de test, envoie-lui trois requêtes en mode sain, bascule-le en mode en panne, envoie-lui deux requêtes supplémentaires et remets-le en mode sain. Ensuite, en utilisant **uniquement** `docker logs` et ses options :

1. Affiche seulement les trois dernières lignes.
2. Affiche le journal avec l'horodatage de chaque ligne.
3. Affiche seulement ce qui s'est passé au cours de la dernière minute.
4. Arrête le conteneur et prouve que le journal est toujours présent. Supprime-le et prouve qu'il n'existe plus.

### Exercice 4 — Explique-le à celui qui l'a fait

Ton collègue de la scène du début te soutient : « Mon pare-feu `ufw` est activé, donc publier avec `-p 9000:9000` ne présente aucun problème ». En cinq phrases au maximum, explique-lui pourquoi c'est faux et ce qu'il aurait dû écrire. Utilise les termes *interface*, *127.0.0.1* et *pare-feu*.

## Solutions

### Solution 1

1. C'est la **deuxième** qui échoue : le port 9000 sur `127.0.0.1` est déjà accaparé par `curso-docker-a` ; elle se termine sur `port is already allocated` avec le code 125. La quatrième **n'est pas** une erreur de Docker, mais elle s'achève bel et bien avec le code **1** : la sous-commande `healthcheck` ne trouve personne en écoute à l'intérieur de ce conteneur (`connection refused`), exactement comme dans le bloc 5 de `fig02_07.sh`.
2. Deux conteneurs : `curso-docker-a` à l'état `Exited (0)`, car tu l'as arrêté et le service réagit proprement à `SIGTERM` ; et `curso-docker-b` à l'état `Created`, le conteneur fantôme issu du conflit de port. `curso-docker-c` n'apparaît pas : il avait l'option `--rm`, et `docker run` sans `-d` ne rend la main qu'une fois le conteneur supprimé.
3. **Il démarre, mais sans son port**, et c'est la réponse que presque personne ne prévoit. Cela a été mesuré lors de la rédaction de cette leçon avec Docker 29.2.1 : `docker start curso-docker-b` s'est terminé avec le code 0 et `docker ps` l'affichait `Up`, mais la colonne PORTS était **vide**, `docker port` ne renvoyait rien et un `curl` sur `127.0.0.1:9000` ne recevait aucune réponse. `docker inspect` mettait en lumière la divergence : dans `.HostConfig.PortBindings`, le port `127.0.0.1:9000` était toujours demandé, mais dans `.NetworkSettings.Ports`, ce qui est réellement relié, il n'y avait rien. Si tu as prédit « il démarre et prend le port 9000 désormais libre », ton raisonnement était parfaitement logique ; le conteneur fantôme ne se comporte tout simplement pas ainsi. C'est une raison supplémentaire d'appliquer la règle vue dans « L'erreur que tu vas voir » : après un incident de port déjà occupé, **supprime** le conteneur resté à l'état `Created` et recrée-le avec `docker run`, au lieu d'essayer de le sauver avec `docker start`.
4. Une commande pour supprimer et une autre pour vérifier : `docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f`, suivie de `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l`, qui doit obligatoirement renvoyer `0`.

Les points 1, 2 et 3 ont été vérifiés en exécutant cette séquence exacte sur la machine de test.

### Solution 2

```bash
docker run -d --name curso-docker-ejercicio -p 127.0.0.1:9002:9000 \
  --memory 32m --cpus 0.25 --pids-limit 20 curso-docker-prueba:1.0.0
curl -s http://127.0.0.1:9002/
docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' curso-docker-ejercicio
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' curso-docker-ejercicio
curl -s -X POST http://127.0.0.1:9002/modo/caido
docker ps --filter name=curso-docker-ejercicio --format '{{.Names}} {{.Status}}'
docker rm -f curso-docker-ejercicio
```

1. Le point essentiel est `-p 127.0.0.1:9002:9000` : 9002 est **ton** port sur l'hôte, 9000 reste celui du service à l'intérieur du conteneur. Si tu as écrit `-p 127.0.0.1:9002:9002`, `curl` ne reçoit rien, car à l'intérieur personne n'écoute sur le 9002.
2. `memoria=33554432`, soit 32 × 1024 × 1024, et `cpus(nano)=250000000`, un quart de milliard : un quart de CPU. C'est le même calcul qu'en 2.7.1 avec d'autres valeurs.
3. La colonne affichera `… / 32MiB`. La valeur située avant la barre oblique varie ; la limite, non.
4. `Up`, avec ou sans la mention d'état de santé. Cela a été mesuré lors de l'écriture de la leçon : juste après le passage en mode en panne, `Up 2 seconds (health: starting)` ; douze secondes plus tard, `Up 14 seconds (unhealthy)`. Il continue d'indiquer `Up` bien qu'étant marqué comme non sain. Docker prend connaissance de la défaillance grâce au contrôle de santé embarqué dans l'image, et non parce qu'il sait de lui-même ce que répond le service.
5. `docker rm -f` convient ici : il s'agit d'un conteneur d'exercice sans données persistantes.

### Solution 3

```bash
docker run -d --name curso-docker-bitacora -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done
for i in 1 2 3; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/caido
for i in 1 2; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/sano
docker logs --tail 3 curso-docker-bitacora
docker logs --timestamps curso-docker-bitacora
docker logs --since 1m curso-docker-bitacora
docker stop curso-docker-bitacora
docker logs --tail 3 curso-docker-bitacora
docker rm curso-docker-bitacora
docker logs curso-docker-bitacora
```

1. Si tu as collé l'ensemble du bloc d'un coup, les trois dernières lignes correspondent aux deux requêtes en mode en panne et au retour au mode sain : deux fois `GET / en modo caido` puis `modo cambiado a sano`. Si tu as tapé les commandes une à une en prenant plus de cinq secondes, des lignes `GET / en modo …` issues du contrôle de santé périodique (2.5) viendront s'intercaler : ce n'est pas toi qui les as demandées, c'est Docker, et ton `--tail 3` sera différent.
2. Avec `--timestamps`, chaque ligne débute par la date et l'heure précises de réception par Docker, en UTC (indiqué par le `Z` final), avec une précision à la nanoseconde : lors de l'exécution de validation, `2026-10-21T08:39:45.967466997Z servicio-prueba: GET / en modo caido`. Cette colonne permet de déterminer à quelle seconde exacte a débuté l'incident ; pense à convertir l'heure selon ton fuseau horaire local (à Mexico, retire 6 heures).
3. `--since 1m` affiche tout si tu as réalisé l'exercice en moins d'une minute : le démarrage, chaque requête (y compris celle de la boucle d'attente) et chaque changement de mode, plus une ligne pour chaque contrôle de santé intervenu entre-temps ; le volume augmente donc avec le temps écoulé. C'est l'outil adapté pour savoir « ce qui s'est passé depuis 10 h 00 », en remplaçant `1m` par une heure précise.
4. Après `docker stop`, le journal reste accessible, et sa dernière ligne indique désormais `servicio-prueba: recibí terminated, apagando` : l'extinction a elle aussi été enregistrée. Après `docker rm`, `docker logs` échoue en affichant `Error response from daemon: No such container: curso-docker-bitacora` : le conteneur a disparu, et son journal avec lui. Telle est la preuve irréfutable que tu perdrais si tu supprimais avant de lire.

### Solution 4

Une réponse possible : « Sans adresse explicite, `-p 9000:9000` publie le port sur toutes les **interfaces** de ta machine, y compris l'interface Wi-Fi, et pas seulement sur l'interface de bouclage (loopback). Et le **pare-feu** `ufw` ne bloque rien, car Docker installe ses propres règles réseau et le trafic destiné au conteneur est acheminé avant même que `ufw` n'ait pu l'examiner ; la documentation de Docker le précise formellement. N'importe qui sur le réseau du café pouvait donc contacter ton conteneur. Ce qu'il fallait écrire, c'est `-p 127.0.0.1:9000:9000` : **127.0.0.1** est l'interface qui ne mène qu'à ton propre ordinateur. La sécurité réside dans le `-p`, pas dans le pare-feu ».

## Comment je sais que j'ai réussi

Exécute les sept scripts de [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia) sur ton Mint, dans l'ordre (`fig02_01.sh` construit l'image utilisée par les suivants ; son bloc 1 n'affiche l'erreur que si l'image n'existe pas encore), et compare tes sorties avec celles de cette leçon. Ce qui **ne se compare pas**, parce que cela fluctue à chaque exécution : les identifiants des conteneurs et des images, les durées (`Up 2 seconds`, `3.08 s`, `242 ms`, celles de la construction), la mémoire en cours d'utilisation rapportée par `docker stats` ainsi que la mémoire totale de ta machine, et `arm64` par rapport à `amd64`. Tout le reste doit concorder. Coche chaque point :

- [ ] `docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'` affiche `curso-docker-prueba:1.0.0 15.1MB` (ou une taille très proche sur `amd64`).
- [ ] Lorsque le service tourne, `docker ps` affiche `127.0.0.1:9000->9000/tcp` dans la colonne PORTS, sans aucune mention de `0.0.0.0` ni de `[::]`.
- [ ] `curl -s http://127.0.0.1:9000/` répond `sano` ; en mode en panne, `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/` répond `503`, et `docker ps` continue d'indiquer `Up`.
- [ ] `docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}' curso-docker-prueba` affiche `memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532`.
- [ ] Tu as provoqué et décrypté les deux erreurs de `fig02_06.sh`, et tu sais pourquoi il faut supprimer un conteneur resté à l'état `Created` après la seconde.
- [ ] `docker stop curso-docker-prueba` prend moins d'une seconde et laisse le conteneur en `Exited (0)` ; le journal se termine par `recibí terminated, apagando`.
- [ ] Tu es capable d'expliquer, sans hésiter, la différence entre arrêté et supprimé, ainsi que ce qui est perdu dans chaque cas.
- [ ] En terminant, `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l` renvoie `0`, et l'image `curso-docker-prueba:1.0.0` **demeure** dans `docker image ls` : tu en auras besoin par la suite.
- [ ] Tu as consigné dans ton journal de bord ce qui change entre `-p 9000:9000` et `-p 127.0.0.1:9000:9000`, comme vérifié avec `ss -ltn`.

## Résumé

Réponds sans regarder la leçon :

1. Que signifient les codes de sortie 125, 126 et 127 de `docker run` ? Lequel as-tu rencontré en exécutant une image inexistante, et lequel en demandant `sh` dans le service de test ?
2. À quelle question répond chacune des options de la commande `docker run -d --name … -p 127.0.0.1:9000:9000 --memory 64m --cpus 0.5 --pids-limit 50 …` ?
3. Quelle est la différence entre `docker ps` et `docker ps -a`, et pourquoi est-ce crucial pour le nettoyage ?
4. Pourquoi `docker ps` peut-il indiquer `Up` pour un service qui répond `503` ?
5. Que voit `docker logs` et que ne voit-il pas ? Qu'advient-il du journal lors d'un `stop` et lors d'un `rm` ?
6. Pourquoi `docker exec … sh` échoue-t-il sur le service de test, et en quoi est-ce un avantage ?
7. Que signifie `memoria=0` dans `docker inspect` ?
8. Quelle différence y a-t-il entre publier sur `127.0.0.1` et omettre l'adresse ? Pourquoi `ufw` ne te protège-t-il pas ?
9. Que fait `docker stop`, étape par étape, et en quoi se distingue-t-il de `docker rm -f` ?
10. Comment fais-tu pour supprimer uniquement tes conteneurs, et pourquoi ne dois-tu pas employer `docker container prune` sur une machine partagée ?

## Sources

Toutes consultées le 21 octobre 2026.

- [docker container run](https://docs.docker.com/reference/cli/docker/container/run/) : `-d`, `--name`, `-p`, `--rm`, `--pids-limit`, la valeur par défaut de `--pull` et l'avertissement concernant les ports publiés sur toutes les interfaces et `ufw`.
- [Docker, « Running containers »](https://docs.docker.com/engine/containers/run/) : les codes de sortie 125, 126 et 127, et les effets de `--privileged`.
- [docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/) : `-a`, `-q`, le filtrage par nom et par état, et les champs de formatage avec `--format`.
- [docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/) : ce que fournit la commande et les options `--follow`, `--tail`, `--since` et `--timestamps`.
- [docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/) : `-i`, `-t`, le fait qu'il ne fonctionne que pendant l'exécution du processus principal et la nécessité que la commande soit un exécutable.
- [docker inspect](https://docs.docker.com/reference/cli/docker/inspect/) : les informations de bas niveau et les modèles de formatage avec `--format`.
- [docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/) : `--no-stream` ainsi que les colonnes de mémoire et de processus.
- [docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/) : `SIGTERM`, le délai par défaut de 10 secondes, `SIGKILL` et `--timeout`.
- [docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/) : `--force` avec `SIGKILL` et la recommandation d'utiliser `prune`.
- [docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/) : le fait qu'il supprime tous les conteneurs arrêtés, et ses filtres.
- [docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/) : la vue de référence de la commande.
- [Docker, « Port publishing and mapping »](https://docs.docker.com/engine/network/port-publishing/) : la publication sur toutes les adresses par défaut, l'avertissement de sécurité et la publication sur `127.0.0.1`.
- [Docker, « Packet filtering and firewalls »](https://docs.docker.com/engine/network/packet-filtering-firewalls/) : pourquoi le trafic destiné à un conteneur contourne les règles de `ufw`.
- [Docker, « Resource constraints »](https://docs.docker.com/engine/containers/resource_constraints/) : l'absence de limites par défaut, le risque d'épuisement de la mémoire, la valeur minimale de `--memory` et l'exemple de `--cpus`.
- [Docker Engine security](https://docs.docker.com/engine/security/) : le daemon s'exécutant en tant que `root` et la nécessité que seuls des utilisateurs de confiance le contrôlent.
- [Docker, étapes post-installation sur Linux](https://docs.docker.com/engine/install/linux-postinstall/) : le groupe `docker` et ses privilèges équivalents à `root`.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions et dates citées dans « À propos des exécutions », ainsi que la nouvelle présentation par défaut de `docker image ls` depuis la version 29.0.
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **journal** (*logs*) | ce que le programme principal d'un conteneur écrit sur sa sortie standard et d'erreurs ; Docker le conserve et `docker logs` te le restitue |
| **code de sortie** | le nombre avec lequel un programme se termine ; 0 signifie que « tout va bien » |
| **contexte de construction** | le dossier que `docker build` utilise pour chercher le `Dockerfile` et les fichiers que la recette copie |
| **distroless** | famille d'images de base minimales qui n'embarquent que le strict nécessaire pour exécuter un programme, sans shell |
| **état d'un conteneur** | créé, en cours d'exécution, arrêté ; supprimé signifie qu'il n'existe plus |
| **tag** | ce qui suit les deux-points dans le nom d'une image : `1.0.0` dans `curso-docker-prueba:1.0.0` |
| **interface réseau** | chaque « porte » réseau d'une machine ; `127.0.0.1` est celle qui ne mène qu'à la machine elle-même (*loopback*) |
| **publier un port** | relier un port de l'hôte à un port du conteneur, à l'aide de `-p` |
| **`SIGTERM`** | le signal par lequel on demande poliment à un programme de s'arrêter ; il peut être intercepté pour s'éteindre proprement |
| **`SIGKILL`** | le signal 9, qui tue un programme sans lui laisser la possibilité de refermer quoi que ce soit |

---

**Suivante :** [Leçon 3 — Ton premier Dockerfile](03-primer-dockerfile.md)
