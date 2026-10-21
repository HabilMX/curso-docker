# Leçon 5 — Multi-stage : des gigaoctets aux mégaoctets

Il est 7 h 50 du matin et l'agence ouvre à 9 h. Le `revisor` doit être installé avant cette heure-là sur le serveur du local technique, relié au reste du monde par une liaison modeste. Tu lances le téléchargement de l'image et la barre avance au compte-gouttes : l'image pèse 1,32 Go. Pendant que tu attends, un message arrive de la personne de la sécurité qui contrôle chaque installation : « Avant de la démarrer, tu peux m'expliquer pourquoi cette image embarque `gcc`, `git`, `curl`, `apt-get` et un *shell* ? Le `revisor` est un seul programme. Si quelqu'un parvient à s'introduire dans ce conteneur, tu lui laisses un atelier complet : de quoi télécharger des outils, de quoi les compiler et de quoi les exécuter. » Tu as quarante minutes et deux problèmes qui semblent distincts : l'image est énorme et l'image est dangereuse. Cette leçon t'apprend que c'est le même problème, et qu'il se règle avec un seul Dockerfile mieux écrit : l'image qui sort d'ici pèse 16,1 Mo, n'a pas de *shell* et ne tourne pas en tant que `root`.

**Durée :** 2 × 45 min

**Ce que tu construis :** l'image finale du `revisor`, `curso-docker-revisor:1.2.0` : un Dockerfile en quatre étapes qui compile et teste dans une grosse image et livre dans une image minimale, avec la base figée par version et par *digest*. Elle pèse 16,1 Mo, n'a ni *shell* ni compilateur et tourne avec l'utilisateur sans privilèges 65532.

**Ce que tu apprends :** ce qu'est une construction en plusieurs étapes (*multi-stage build*) et comment on fait passer des fichiers d'une étape à l'autre avec `COPY --from` ; comment placer les tests à l'intérieur de la construction pour qu'un test en échec l'arrête, et l'erreur silencieuse qui les contourne ; ce qu'est une image de base minimale sans *shell* (*distroless*) et ce que cela change pour l'exploiter ; ce qu'est un *digest* et pourquoi on fige la base avec lui en plus du tag ; et pourquoi un binaire qui n'est pas statique ne démarre pas dans une image minimale, avec le message exact que tu vas voir.

**D'où tu viens.** De la [Leçon 4](04-capas-cache-contexto.md), tu apportes l'image `curso-docker-revisor:1.1.0` : le même `revisor` que dans la Leçon 3, mais avec le Dockerfile ordonné pour le cache (d'abord `go.mod`, ensuite le code) et avec le cache de compilation de Go dans un montage qui ne reste pas dans l'image. Tu sais lire `docker history`, tu sais ce qu'est une couche et ce qui voyage dans le contexte. Tu apportes aussi un chiffre noté dans ton journal de bord : cette image pèse **1,32 Go**. De la [Leçon 3](03-primer-dockerfile.md), tu apportes `USER`, la forme *exec* et le dossier `~/curso-docker/revisor`, où vit ton projet. Et de la [Leçon 2](02-contenedores-dia-a-dia.md), tu apportes un souvenir : tu as essayé d'entrer avec `docker exec` dans le service de test et il n'y avait pas de `sh`. Ici, tu vas comprendre pourquoi, et tu vas faire la même chose au `revisor`.

**Ce que cette leçon ne fait pas.** Elle ne touche pas au code du `revisor` et ne lui ajoute pas de fonctionnalités : le programme est le même que dans les Leçons 3 et 4. Elle n'attribue pas de version au binaire (c'est pourquoi `revisor version` affiche encore `desarrollo` ; la version et la configuration relèvent de la [Leçon 6](06-configuracion-y-secretos.md)). Elle ne lui ajoute pas de `HEALTHCHECK` et ne durcit pas son exécution (*hardening* : système de fichiers en lecture seule, capacités retirées) : c'est la Leçon 7. Et elle ne construit pas pour plusieurs plateformes et n'analyse pas les vulnérabilités : c'est la Leçon 10. Ici, le travail est unique : que ce qui est **livré** soit uniquement ce qui est **nécessaire pour tourner**.

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4, la même base que Linux Mint 22, le système de référence du cours. Les scripts ont été exécutés **à l'intérieur** de cette machine virtuelle, avec Docker 29.2.1 (client et daemon) et Buildx v0.31.1. Le cours a été planifié avec Docker Engine 29.8.2, et la version la plus récente publiée ce jour-là était la 29.9.2, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)) ; rien dans cette leçon ne change entre ces versions. Cette même machine était utilisée au même moment par d'autres exécutions du cours ; pour éviter les collisions, chaque script a donc été lancé avec un autre préfixe de noms et un autre port, grâce aux variables `PREFIJO` et `PUERTO` que tous comportent, et la sortie a été enregistrée en passant par un `sed` qui rétablit les noms du cours. La commande a été, pour chaque figure : `PREFIJO=curso-docker-l05- PUERTO=18050 ./fig05_NN.sh 2>&1 | sed -e 's/curso-docker-l05-/curso-docker-/g' -e 's/127\.0\.0\.1:18050/127.0.0.1:8080/g'`. Tu n'as besoin de rien de tout cela : sans variables, les scripts utilisent les noms et le port du cours, et ce qu'ils affichent est ce que tu vois ici. Ce qui change **effectivement** sur ton Mint, et c'est signalé là où cela apparaît : les numéros de processus (PID), les durées, les dates des fichiers et, si ton ordinateur est un Intel ou un AMD, l'architecture : là où il est écrit ici `arm64` ou `aarch64`, chez toi il sera écrit `amd64` ou `x86_64`, et les tailles peuvent varier de quelques mégaoctets. Les programmes se trouvent dans [`programas/05-multi-stage/`](../programas/05-multi-stage), chacun avec sa sortie à côté ; `inicio/` conserve le `Dockerfile` et le `.dockerignore` avec lesquels se termine la Leçon 4, et `estado/`, ceux qui restent à la fin de celle-ci.

## À la fin, tu seras capable de

- Expliquer, avec les chiffres de ta propre image, pourquoi une image en une seule étape pèse plus d'un gigaoctet alors que le programme qu'elle contient pèse moins de dix mégaoctets.
- Écrire un Dockerfile en plusieurs étapes nommées (`FROM ... AS`), faire passer un fichier d'une étape à l'autre avec `COPY --from` et construire seulement jusqu'à une étape avec `--target`.
- Placer les tests à l'intérieur de la construction de sorte qu'un test en échec l'arrête, et démontrer par une exécution pourquoi l'étape du binaire doit partir de l'étape de tests et non de celle de compilation.
- Montrer avec `docker exec`, `docker inspect` et `docker top` que l'image finale n'a pas de *shell* et ne tourne pas en tant que `root`, et lister tous ses fichiers sans y entrer.
- Figer une image de base par tag et par *digest*, et dire ce que garantit chacun.
- Lire le message `exec /revisor: no such file or directory`, expliquer quel est le fichier qui manque et corriger le problème avec `CGO_ENABLED=0`.

## Le pourquoi avant le comment

Dans la Leçon 3, tu as construit le `revisor` en une seule étape : tu es parti de l'image de Go, tu as copié le code, tu as compilé et tu as indiqué à Docker quoi exécuter. Cela fonctionne, et c'était la bonne façon de commencer, car tout était en vue. Mais cette recette a un défaut de conception qu'aucun réordonnancement ne corrige : **l'image qui sert à construire et l'image qui est livrée sont la même**. Tout ce qui a été nécessaire pour compiler — le compilateur de Go, celui de C, un Debian complet avec son gestionnaire de paquets, les outils réseau — reste dans l'image qui part sur le serveur, même si le `revisor` n'utilise rien de tout cela à l'exécution.

Cela coûte à trois endroits à la fois, et la scène du début les réunit :

1. **En temps et en disque.** Chaque serveur qui fait tourner le `revisor` télécharge et stocke plus d'un gigaoctet. Sur une liaison lente, c'est la différence entre arriver ou non à 9 h.
2. **En sécurité.** Chaque programme qui voyage dans l'image est quelque chose qu'un intrus peut utiliser. Un conteneur avec un *shell*, `curl` et un compilateur épargne presque tout le travail à celui qui y entre. Un conteneur qui ne contient que le `revisor` ne lui laisse rien pour continuer.
3. **En bruit.** Un scanner de vulnérabilités examine tous les paquets de l'image. Si l'image embarque deux cents paquets Debian que le `revisor` ne touche jamais, le rapport se remplit de résultats sans importance et cache ceux qui comptent. Le projet d'images minimales de Google le dit lui-même : une image débarrassée du superflu « améliore le rapport signal sur bruit des scanners » ([distroless](https://github.com/GoogleContainerTools/distroless)).

La solution que tu vas construire sépare les deux tâches : une grosse image pour **construire et tester**, qui ne quitte jamais ton ordinateur, et une image minimale pour **exécuter**, qui est celle que l'on livre. Les deux sont décrites dans le même Dockerfile, et le passage de l'une à l'autre tient en une seule ligne : copier le binaire. La documentation de Docker le résume en une phrase : avec les constructions en plusieurs étapes, « tu peux copier sélectivement des artefacts d'une étape à une autre, en laissant derrière toi tout ce que tu ne veux pas dans l'image finale » ([Docker, « Multi-stage builds »](https://docs.docker.com/build/building/multi-stage/)).

La leçon comporte huit parties, dans cet ordre :

1. **Ce qu'il y a dans 1,32 Go** (5.1) : mesurer avant de réduire.
2. **L'idée des étapes** (5.2) : `FROM ... AS`, `COPY --from` et `--target`.
3. **Le Dockerfile en quatre étapes** (5.3), ligne par ligne.
4. **Construire et mesurer** (5.4) : de 1,32 Go à 16,1 Mo.
5. **Les tests à l'intérieur de la construction** (5.5), avec l'erreur silencieuse de cette leçon.
6. **La base minimale** (5.6) : sans *shell* et sans `root`.
7. **Version et *digest*** (5.7) : figer la base pour de vrai.
8. **Le binaire qui ne démarre pas** (5.8), l'erreur principale de la leçon.

Avec cette destination en tête, voici ce que tu vas voir à la section 5.4, quand tu mettras côte à côte l'image avec laquelle tu arrives et celle que tu construis ici :

```text
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB
```

## Les concepts

### 5.1 Ce qu'il y a dans 1,32 Go

#### 5.1.1 Mesurer avant de réduire

Avant de modifier une seule ligne, il vaut la peine de savoir ce qu'il y a dans l'image et quelle part de ce poids revient au `revisor`. Réduire sans mesurer, c'est deviner. Le programme `fig05_01.sh` construit l'image de la Leçon 4 depuis `inicio/` et lui pose trois questions : combien pèse le `revisor`, quels autres outils voyagent avec lui et combien occupent les dossiers les plus lourds :

```bash
#!/usr/bin/env bash
# fig05_01.sh — Qué hay dentro de la imagen con la que termina la Lección 4.
# La construye desde inicio/ (el Dockerfile y el .dockerignore de la Lección 4),
# mide su tamaño y busca adentro lo que el revisor necesita para correr y lo que
# no. Borra lo que crea al salir.
set -euo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/inicio/Dockerfile" "$AQUI/inicio/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

titulo() { printf '\n## %s\n' "$*"; }
# muestra: imprime el comando con «$ » y lo ejecuta (salida y error juntos)
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
IMAGEN="${PREFIJO}revisor:1.1.0"
MIRAR="docker run --rm --name ${PREFIJO}mirar $IMAGEN"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "La imagen de la Lección 4"
muestra "docker build -q -t $IMAGEN . >/dev/null && docker image ls $IMAGEN --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Lo único que el revisor necesita para correr"
muestra "$MIRAR ls -lh /usr/local/bin/revisor"

titulo "Lo demás que viaja con él"
muestra "$MIRAR sh -c 'for p in sh bash apt-get gcc go git curl; do printf \"%-8s %s\n\" \$p \"\$(command -v \$p || echo no-esta)\"; done'"
muestra "$MIRAR du -sh /usr/local/go /usr/lib /usr/bin /usr/share"
muestra "$MIRAR sh -c 'dpkg-query -W | wc -l'"
muestra "$MIRAR id"
```

Avant la sortie, les nouvelles lignes du script. La structure est la même que celle des scripts de la Leçon 3 : on assemble le projet dans un dossier temporaire (`mktemp -d`) avec le code que livre le cours plus les fichiers de la leçon, on définit les fonctions d'aide `titulo` et `muestra` (qui affiche chaque commande précédée de `$ ` avant de l'exécuter, pour que tu saches ce qui a produit chaque ligne), et un `trap ... EXIT` supprime l'image et le dossier à la sortie. Le `sed` du début ne change le nom du cache de compilation que si tu changes `PREFIJO` ; avec la valeur par défaut, il ne change rien. `MIRAR` est une abréviation pour ne pas répéter `docker run --rm --name ... image` à chaque question.

```text
$ ./fig05_01.sh

## La imagen de la Lección 4
$ docker build -q -t curso-docker-revisor:1.1.0 . >/dev/null && docker image ls curso-docker-revisor:1.1.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB

## Lo único que el revisor necesita para correr
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 ls -lh /usr/local/bin/revisor
-rwxr-xr-x 1 root root 9.5M Oct 21 08:46 /usr/local/bin/revisor

## Lo demás que viaja con él
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'for p in sh bash apt-get gcc go git curl; do printf "%-8s %s\n" $p "$(command -v $p || echo no-esta)"; done'
sh       /usr/bin/sh
bash     /usr/bin/bash
apt-get  /usr/bin/apt-get
gcc      /usr/bin/gcc
go       /usr/local/go/bin/go
git      /usr/bin/git
curl     /usr/bin/curl
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 du -sh /usr/local/go /usr/lib /usr/bin /usr/share
277M	/usr/local/go
276M	/usr/lib
120M	/usr/bin
140M	/usr/share
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'dpkg-query -W | wc -l'
208
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 id
uid=10001 gid=10001 groups=10001
```

La date et l'heure du fichier changent à chaque construction ; sur un ordinateur Intel ou AMD, les tailles peuvent varier de quelques mégaoctets. Le reste sort à l'identique.

#### 5.1.2 Lire les chiffres

Mets les chiffres dans une seule phrase et le problème saute aux yeux : **le `revisor` pèse environ 10 Mo et voyage dans une image de 1,32 Go**. Moins d'un pour cent de ce qui est téléchargé est le programme que tu vas exécuter. Les 99 % restants sont des bagages :

- **Le compilateur de Go**, dans `/usr/local/go` : 277 Mo. (`ls -lh` et `du -sh` comptent en puissances de 1024 : le `9.5M` du `revisor` correspond à 9,5 Mio, environ 10 Mo ; `docker image ls` compte en puissances de 1000.) Il a été nécessaire pour compiler ; à l'exécution, le `revisor` ne l'utilise pas une seule fois.
- **Un Debian presque complet** : 208 paquets installés (`dpkg-query -W` en liste un par ligne et `wc -l` les compte), avec leurs bibliothèques dans `/usr/lib` et leurs programmes dans `/usr/bin`.
- **Les outils qui inquiétaient la personne de la sécurité dans la scène** : un *shell* (`sh` et `bash`), un gestionnaire de paquets (`apt-get`), un compilateur C (`gcc`), `git` et `curl`. Chacun est là pour une bonne raison quand il s'agit de **construire** : l'image officielle de Go les embarque pour que la compilation fonctionne avec presque n'importe quel projet. Pour **exécuter** le `revisor`, aucun.

La dernière ligne rappelle utilement que la Leçon 3 n'a pas été vaine : l'image tourne avec l'utilisateur `10001`, pas avec `root`. Mais cet utilisateur a sous la main `curl` pour télécharger ce qu'il veut et `sh` pour l'exécuter. Sans privilèges, oui ; désarmé, non.

Remarque aussi ce qui **n'est pas** dans la liste : rien de tout cela ne se règle en supprimant des fichiers. Si tu ajoutes au Dockerfile un `RUN rm -rf /usr/local/go`, l'image ne perd pas un seul octet : la Leçon 4 t'a appris que chaque instruction ajoute une couche au-dessus des précédentes, et que ce qu'une couche supprime reste stocké dans la couche du dessous. Supprimer dans une nouvelle couche ne fait que masquer. Pour que le compilateur ne voyage pas, l'image finale doit **naître sans lui**.

> [!NOTE]
> 🔧 **Observation de génie logiciel 5.1**
> Mesure avant d'optimiser, et mesure la proportion, pas seulement le total. « L'image pèse 1,32 Go » invite à chercher où rogner. « Le programme représente moins de 1 % de l'image » te dit qu'il n'y a rien à rogner : il faut changer d'image.

### 5.2 L'idée des étapes

#### 5.2.1 Plusieurs `FROM` dans un même Dockerfile

Jusqu'ici, chaque Dockerfile n'avait qu'un seul `FROM`, et tout ce qui suivait s'empilait sur cette base. L'idée centrale de cette leçon est qu'**un Dockerfile peut avoir plusieurs `FROM`**. Chaque `FROM` commence une nouvelle **étape** (*stage*), à partir de zéro, avec sa propre base. La référence du Dockerfile le formule ainsi : `FROM` « peut apparaître plusieurs fois dans un même Dockerfile » pour créer plusieurs images ou pour utiliser une étape comme dépendance d'une autre ([référence du Dockerfile, `FROM`](https://docs.docker.com/reference/dockerfile/#from)).

Ce qui rend cette idée utile, ce sont trois éléments, que tu vas voir dans un fragment de quatre lignes avant le Dockerfile complet :

```dockerfile
FROM golang:1.27.3-trixie AS compilacion
RUN ... go build -o /out/revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=compilacion /out/revisor /revisor
```

Ce bloc est un fragment à lire, pas un programme : il lui manque des lignes pour être construit. Ce qu'il montre :

1. **Le nom de l'étape.** `AS compilacion`, à la fin du `FROM`, donne un nom à l'étape. La documentation recommande de les nommer ainsi, au lieu d'y faire référence par leur numéro ([Docker, « Name your build stages »](https://docs.docker.com/build/building/multi-stage/#name-your-build-stages)). Un nom survit au fait que quelqu'un ajoute ou retire des étapes ; un numéro, non.
2. **La copie entre étapes.** `COPY --from=compilacion` copie un fichier **depuis une autre étape**, et non depuis le contexte. La référence précise que `--from` accepte une étape, une image ou un contexte nommé ([référence, `COPY --from`](https://docs.docker.com/reference/dockerfile/#copy---from)). Ici, l'étape de compilation dépose le binaire dans `/out/revisor` et la dernière étape le récupère.
3. **L'image qui en sort.** L'image que construit `docker build` est celle de la **dernière** étape. Tout ce qui s'est passé dans les précédentes — le compilateur, le code source, le cache — reste derrière. C'est la phrase de la documentation : copier ce que tu veux et laisser derrière ce que tu ne veux pas.

Si tu viens de la programmation, une comparaison aide : une étape est comme une fonction qui renvoie une valeur. L'étape de compilation « renvoie » un fichier ; l'étape finale ne reçoit que ce fichier, pas les variables locales qui ont servi à le calculer.

#### 5.2.2 Construire jusqu'à une étape : `--target`

Le deuxième outil, c'est la possibilité de construire **seulement jusqu'à** une étape. `docker build --target pruebas` construit l'étape nommée `pruebas` (et celles dont elle a besoin) et s'arrête là ; l'image obtenue est celle de cette étape, pas l'image finale ([Docker, « Stop at a specific build stage »](https://docs.docker.com/build/building/multi-stage/#stop-at-a-specific-build-stage) ; dans la référence de la ligne de commande, `--target` est « l'étape de construction à construire », [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)). Cela sert à deux choses que tu vas utiliser dans cette leçon : exécuter seulement les tests, et regarder à l'intérieur d'une étape intermédiaire qui, elle, dispose d'outils.

#### 5.2.3 Ce que BuildKit construit et ce qu'il ne construit pas

Le troisième élément est le moins connu et celui qui réserve le plus de surprises. Le constructeur de Docker, BuildKit, ne construit pas toutes les étapes du fichier dans l'ordre : **il construit seulement les étapes dont dépend l'étape que tu as demandée**. La documentation le dit sans détour : « BuildKit ne construit que les étapes dont dépend l'étape cible » ([Docker, « Differences between legacy builder and BuildKit »](https://docs.docker.com/build/building/multi-stage/#differences-between-legacy-builder-and-buildkit)). Une étape dont personne n'a besoin ne s'exécute pas.

C'est un avantage (on ne perd pas de temps sur ce qui n'est pas nécessaire) et un piège, que tu vas déclencher en 5.5 : si les tests vivent dans une étape dont l'image finale ne dépend pas, BuildKit ne les exécute pas, et la construction passe au vert avec un test en échec à l'intérieur. Retiens cette phrase ; c'est la clé de l'erreur silencieuse de cette leçon.

### 5.3 Le Dockerfile en quatre étapes, ligne par ligne

#### 5.3.1 La recette complète

Voici le Dockerfile avec lequel se termine la leçon. Il remplace celui de la Leçon 4 dans ton dossier, et le `.dockerignore` ne change pas :

```dockerfile
# syntax=docker/dockerfile:1
# fig05_02.Dockerfile — Lección 5: multi-stage: compilar y probar en una imagen grande, entregar en una mínima.

# --- Etapa 1: el código, sobre la imagen de Go (fijada por versión Y por digest) ---
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

# --- Etapa 2: las pruebas. Si fallan, la construcción se detiene aquí ---
FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

# --- Etapa 3: el binario, estático (CGO_ENABLED=0), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

Ce sont quatre étapes enchaînées, et chacune n'a qu'une seule tâche :

| Étape | Part de | Sa tâche | Voyage-t-elle dans l'image finale ? |
|---|---|---|---|
| `compilacion` | l'image officielle de Go | avoir le code prêt à compiler | non |
| `pruebas` | `compilacion` | exécuter `go test ./...` | non |
| `binario` | `pruebas` | produire `/out/revisor`, statique | seulement ce fichier |
| `final` | *distroless* `static`, sans *shell* | exécuter le `revisor` | c'est l'image finale |

Les noms des étapes sont ceux du cours et se répètent dans les leçons suivantes : `compilacion`, `pruebas`, `binario` et `final`. Ils sont écrits sans accent exprès, car ce sont des identifiants que tu vas taper dans `--target` et dans `COPY --from`.

#### 5.3.2 Chaque ligne à son moment

**L'étape `compilacion`.** C'est presque la moitié supérieure du Dockerfile de la Leçon 4 : la même base, le même `WORKDIR /src` et les trois mêmes `COPY` dans l'ordre qui profite au cache (d'abord `go.mod`, qui ne change presque jamais ; ensuite le code). La seule nouveauté est dans le `FROM` : après le tag `1.27.3-trixie` vient `@sha256:6041…`, le *digest*, et à la fin `AS compilacion`. Le *digest* a sa propre section (5.7). Cette étape ne compile encore rien : elle se contente de mettre le code en place, pour que les deux suivantes partent de là.

**L'étape `pruebas`.** `FROM compilacion AS pruebas` signifie « commence là où `compilacion` s'est arrêtée ». C'est la première fois que tu vois un `FROM` qui ne nomme pas une image d'Internet mais une étape du même fichier. Son unique `RUN` exécute `go test ./...`, les tests des cinq paquets du `revisor`, avec le même montage de cache que dans la Leçon 4 (l'`id=curso-docker-go-build` est le même, si bien que les deux étapes partagent le cache de compilation de Go). Si un test échoue, `go test` se termine avec un code différent de zéro, le `RUN` échoue et la construction s'arrête : pas d'image.

**L'étape `binario`.** `FROM pruebas AS binario` est la ligne la plus importante du fichier, même si elle ressemble à un détail. Elle indique que le binaire est compilé **par-dessus** l'étape de tests, et non par-dessus celle de compilation. Grâce à 5.2.3, tu sais déjà pourquoi c'est important : comme l'étape finale copie depuis `binario`, et que `binario` part de `pruebas`, BuildKit est obligé d'exécuter les tests pour arriver à l'image finale. Si `binario` partait de `compilacion`, les tests resteraient en dehors du chemin et personne ne les exécuterait. Tu vas le mesurer en 5.5.

Le `RUN` de cette étape apporte trois nouveautés dans la commande Go :

- **`CGO_ENABLED=0`** demande un binaire **statique** : un binaire qui ne dépend pas des bibliothèques du système pour démarrer. C'est l'élément qui rend possible l'étape finale, et le retirer constitue l'erreur principale de la leçon (5.8).
- **`-trimpath`** retire du binaire les chemins de la machine où il a été compilé (ici, `/src`) : à leur place restent les noms des modules ([`go help build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies)). Ainsi, le binaire ne dépend pas du dossier dans lequel tu l'as compilé et ne le révèle pas.
- **`-ldflags="-s -w"`** transmet deux options à l'éditeur de liens de Go : `-s` « omet la table des symboles et les informations de débogage », et `-w` « omet la table des symboles DWARF » ([cmd/link](https://pkg.go.dev/cmd/link)). C'est ce que tu utiliserais avec un débogueur ; un service en production n'en a pas besoin, et le retirer rend le fichier plus petit. (`-s` implique déjà `-w`, selon cette même documentation ; on écrit les deux par habitude, et c'est ainsi que tu les verras dans presque tous les Dockerfile de Go.) Compare : le binaire de la Leçon 4 mesurait 9,5 Mio selon `ls -lh`, environ 10 Mo ; celui-ci va mesurer 6,68 Mo (6 684 832 octets). Une partie de la différence vient de `-s -w`, et une autre du fait qu'il n'embarque plus le code de *cgo* (5.8).

Le binaire est déposé dans `/out/revisor`, un dossier qui n'existe que pour cela : disposer d'un emplacement fixe et propre où l'étape finale vient le récupérer.

**L'étape `final`.** Elle part de zéro sur `gcr.io/distroless/static-debian13:nonroot`, figée par *digest*. De tout ce qui précède, elle n'apporte qu'un fichier : `COPY --from=binario /out/revisor /revisor`. Ensuite :

- `USER 65532:65532` est l'utilisateur `nonroot` que l'image *distroless* elle-même déclare dans son `/etc/passwd` ; tu le verras de tes propres yeux en 5.4. À partir d'ici, le cours abandonne le `10001` des images en une seule étape et utilise le `65532`, car c'est celui que la base connaît déjà.
- `EXPOSE 8080` reste une simple annotation, comme dans la Leçon 3.
- **`ENTRYPOINT ["/revisor"]`** remplace le `CMD ["revisor"]` des leçons précédentes. La différence est pratique. La référence l'explique : les arguments que tu écris après le nom de l'image dans `docker run` « sont ajoutés après tous les éléments » d'un `ENTRYPOINT` en forme *exec*, alors qu'ils « remplacent tout ce qui est indiqué dans `CMD` » ([référence, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). Avec `ENTRYPOINT`, `docker run curso-docker-revisor:1.2.0 version` exécute `/revisor version` : l'image se comporte comme le programme, et ses sous-commandes (`version`, et dans la Leçon 7 `healthcheck`) s'appellent comme dans le terminal. Avec le `CMD` d'avant, ce `version` aurait remplacé tout le programme et Docker aurait tenté d'exécuter un fichier nommé `version`. Il reste en forme *exec*, pour tout ce que tu as mesuré dans la Leçon 3. Et le chemin est complet, `/revisor`, car le fichier se trouve à la racine du système de fichiers, `/`, qui ne fait partie d'aucun des dossiers dans lesquels le `PATH` de l'image cherche les programmes.

#### 5.3.3 Dans ton dossier

Les scripts du cours travaillent dans des dossiers temporaires et suppriment ce qu'ils créent ; ton projet vit dans `~/curso-docker/revisor` depuis la Leçon 3. Depuis la racine du dépôt du cours, place-y le Dockerfile de cette leçon et construis l'image que tu vas conserver :

```bash
cp programas/05-multi-stage/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q -t curso-docker-revisor:1.2.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

Le `.dockerignore` de la Leçon 4 reste tel quel. L'image `1.1.0` peut rester elle aussi, pour que tu compares ; quand tu n'en voudras plus, `docker rmi curso-docker-revisor:1.1.0`.

### 5.4 Construire et mesurer

#### 5.4.1 La construction, étape par étape

`fig05_03.sh` construit les deux images — celle de la Leçon 4, pour comparer, et celle de cette leçon — et pose cinq questions à la nouvelle : quelles opérations de quelle étape se sont exécutées, combien elle pèse, de quelles couches elle est faite, d'où vient sa taille et quels fichiers elle contient :

```bash
#!/usr/bin/env bash
# fig05_03.sh — Construir el revisor en cuatro etapas y medir lo que se entrega.
# Construye la imagen de la Lección 4 (para comparar) y la de esta lección,
# muestra qué etapas corrieron, compara tamaños, lee las capas y lista los
# archivos de la imagen final. Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/inicio/Dockerfile" "$TRABAJO/revisor/Dockerfile.leccion4"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.leccion4 && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

VIEJA="${PREFIJO}revisor:1.1.0"
NUEVA="${PREFIJO}revisor:1.2.0"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$VIEJA" "$NUEVA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

docker build -q -t "$VIEJA" -f Dockerfile.leccion4 . >/dev/null

titulo "Construir: qué pasos de qué etapa corrieron"
muestra "docker build --progress=plain -t $NUEVA . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[\$0]++'"

titulo "Antes y después"
muestra "docker image ls --filter reference='${PREFIJO}revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Las capas de la imagen nueva"
muestra "docker history $NUEVA --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90"

titulo "De dónde salen los 16.1 MB"
muestra "docker history $NUEVA --format '{{.Size}}' --human=false | awk '{s+=\$1} END {print \"suma de las capas desempacadas:\", s, \"bytes\"}'"
muestra "docker image inspect $NUEVA --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'"

titulo "Todos los archivos de la imagen nueva"
docker create --name "${PREFIJO}mirar" "$NUEVA" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -v '/\$' | wc -l"
muestra "docker export ${PREFIJO}mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo"
muestra "docker export ${PREFIJO}mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |\$)|/?(revisor|passwd)\$' || echo '(nada más)'"
muestra "docker export ${PREFIJO}mirar | tar -xO etc/passwd"
```

Le fichier du dépôt contient les fonctions d'aide complètes ; ici, elles sont résumées dans un commentaire pour ne pas les répéter. Deux nouveaux outils : `grep -oE` n'affiche que le morceau de chaque ligne qui correspond au motif (ici, le numéro d'opération, l'étape et les 60 premiers caractères de l'instruction), et `awk '!visto[$0]++'` supprime les lignes répétées sans changer l'ordre.

```text
$ ./fig05_03.sh

## Construir: qué pasos de qué etapa corrieron
$ docker build --progress=plain -t curso-docker-revisor:1.2.0 . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[$0]++'
#7 [final 1/2] FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757
#8 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
#10 [compilacion 3/5] COPY go.mod ./
#11 [compilacion 4/5] COPY cmd/ cmd/
#12 [compilacion 5/5] COPY internal/ internal/
#13 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#15 [compilacion 2/5] WORKDIR /src
#16 [final 2/2] COPY --from=binario /out/revisor /revisor

## Antes y después
$ docker image ls --filter reference='curso-docker-revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB

## Las capas de la imagen nueva
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
319kB	bazel build //common:cacerts_debian13_arm64_…
16.4kB	bazel build //common:os_release_debian13
12.3kB	bazel build //static:nsswitch
8.19kB	bazel build //common:tmp
12.3kB	bazel build //common:group
16.4kB	bazel build //common:home
12.3kB	bazel build //common:passwd
4.1kB	bazel build //common:rootfs
160kB	bazel build @trixie//media-types/arm64:data_…
2.15MB	bazel build @trixie//tzdata-legacy/arm64:dat…
2.24MB	bazel build @trixie//tzdata/arm64:data_statu…
86kB	bazel build @trixie//netbase/arm64:data_stat…
741kB	bazel build @trixie//base-files/arm64:data_s…

## De dónde salen los 16.1 MB
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}' --human=false | awk '{s+=$1} END {print "suma de las capas desempacadas:", s, "bytes"}'
suma de las capas desempacadas: 12468224 bytes
$ docker image inspect curso-docker-revisor:1.2.0 --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'
capas comprimidas (las que se descargan): 3679492 bytes

## Todos los archivos de la imagen nueva
$ docker export curso-docker-mirar | tar -t | grep -v '/$' | wc -l
1301
$ docker export curso-docker-mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo
.dockerenv bin boot dev etc home lib proc revisor root run sbin sys tmp usr var 
$ docker export curso-docker-mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |$)|/?(revisor|passwd)$' || echo '(nada más)'
-rw-r--r-- 0/0             149 1969-12-31 18:00 etc/passwd
-rwxr-xr-x 0/0         6684832 2026-10-21 01:55 revisor
$ docker export curso-docker-mirar | tar -xO etc/passwd
root:x:0:0:root:/root:/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin
```

Ce qui change à chaque exécution : les numéros d'opération (`#7`, `#8`…) et leur ordre, la date du fichier `revisor` et, sur un ordinateur Intel ou AMD, le mot `arm64` des couches et les tailles, de quelques kilooctets ou mégaoctets. Ce qui est stable : les quatre étapes, les deux tailles dans leur ordre de grandeur, le fait que la somme des deux chiffres en octets donne la taille de `docker image ls`, la liste des dossiers et le contenu de `/etc/passwd`.

#### 5.4.2 Lire la construction

Le premier bloc montre les opérations avec leur étape entre crochets : `[compilacion 4/5]` est la quatrième des cinq opérations de l'étape `compilacion`. Les quatre étapes apparaissent, et deux détails montrent comment travaille BuildKit :

- **L'ordre n'est pas celui du fichier.** Le `FROM` de l'étape `final` apparaît en premier (`#7`), avant tout ce qui concerne `compilacion`, et le `WORKDIR` (`[compilacion 2/5]`) sort presque à la fin, après les `COPY`. BuildKit construit un graphe de ce qui dépend de quoi et exécute en parallèle ce qu'il peut : télécharger la base minimale n'a pas à attendre que le code soit copié. L'étape finale n'attend `binario` qu'à sa deuxième opération, le `COPY --from`.
- **Les numéros d'opération ne sont pas ceux de l'étape.** `#13` est un numéro attribué par BuildKit pour cette construction ; `[pruebas 1/1]` est la position à l'intérieur de l'étape. Si tu exécutes le script deux fois, les premiers peuvent changer, et l'ordre aussi ; les étiquettes entre crochets, non. (Lors d'une autre exécution de cette même leçon, avec davantage d'éléments déjà dans le cache, BuildKit n'a même pas affiché les opérations 1 et 2 de `compilacion` ; c'est pourquoi il vaut mieux ne pas compter les lignes de cette sortie, mais lire quelles étapes apparaissent.)

#### 5.4.3 Lire les tailles

Le deuxième bloc est celui qui justifie la leçon : **de 1,32 Go à 16,1 Mo**, environ quatre-vingts fois moins. La nouvelle image tient dix-sept fois dans ce qu'occupait auparavant le seul compilateur de Go (277 Mo dans `/usr/local/go`, en 5.1). Et le troisième bloc, `docker history`, indique ce qu'il y a dedans : la grosse couche est `COPY /out/revisor /revisor`, de **6,69 Mo**, le binaire ; les autres viennent de la base *distroless* et totalisent environ 5,8 Mo, la plus grosse faisant 2,24 Mo (les fuseaux horaires, `tzdata`). Les couches de la base indiquent `bazel build` : c'est l'outil avec lequel Google construit ces images, et leur historique ne contient pas un seul `RUN apt-get`, car elles n'ont pas été assemblées en installant des paquets avec un gestionnaire. Compare avec la Leçon 4, où `docker history` montrait des couches de 290 Mo, 281 Mo et 208 Mo.

Si tu additionnes ces couches manuellement, tu n'obtiens pas 16,1 Mo, et il vaut la peine de savoir pourquoi avant que cela ne t'embrouille. Le quatrième bloc les additionne pour toi : **12 468 224 octets**, environ 12,5 Mo. Il manque 3,6 Mo. Et la deuxième requête de ce bloc les retrouve : `docker image inspect` indique **3 679 492 octets**, et 12 468 224 + 3 679 492 = 16 147 716 octets, les 16,1 Mo de `docker image ls`. L'explication tient à la façon dont Docker Engine 29 stocke les images, avec le magasin d'images de containerd : selon sa documentation, ce magasin « stocke les images au format compressé et non compressé » : il conserve les couches compressées telles qu'elles sont arrivées du registre **et en plus** les décompresse sur le disque ([Docker, « containerd image store »](https://docs.docker.com/engine/storage/containerd/)). Le chiffre de `docker image ls` compte les deux copies ; `docker history` ne compte que les couches décompressées, et `docker image inspect`, sur cette machine, la partie compressée, qui est ce qui se télécharge. Pour ce qui compte dans cette leçon, cela ne change rien : compare toujours des images avec la **même** commande, et les deux chiffres de `docker image ls` (1,32 Go et 16,1 Mo) ont été mesurés de la même façon.

Une question naturelle : où sont passées les étapes `compilacion`, `pruebas` et `binario` ? Elles sont restées dans le cache de construction de ton ordinateur, ce qui rend la construction suivante rapide, mais **elles ne font pas partie de l'image** : le `docker history` de `1.2.0` n'en contient pas une seule couche. La seule chose qui est passée d'un côté à l'autre est le fichier que nomme le `COPY --from`.

#### 5.4.4 Regarder à l'intérieur sans entrer

La dernière partie du script répond à la question de la scène : qu'y a-t-il dans cette image ? Comme elle n'a pas de *shell* (tu vas le vérifier en 5.6), tu ne peux pas entrer regarder avec `docker exec`. Mais tu peux demander à Docker de te donner ses fichiers. `docker create` crée un conteneur à partir de l'image **sans le démarrer**, et `docker export` extrait tout le système de fichiers de ce conteneur sous forme d'archive `tar`, que `tar -t` liste sans la décompresser. C'est la façon d'inspecter une image minimale depuis l'extérieur.

Ce que cela dit :

- **1 301 fichiers** au total (`grep -v '/$'` retire les dossiers du décompte). Cela paraît beaucoup, jusqu'à ce que tu regardes ce que c'est : presque tous sont les fuseaux horaires et les certificats des autorités de certification d'Internet, dont un service qui en interroge d'autres en HTTPS a besoin.
- **Les dossiers de premier niveau** sont ceux de n'importe quel Linux (`bin`, `etc`, `usr`, `var`…), plus `revisor` et `.dockerenv`, un fichier vide que Docker ajoute à tout conteneur. L'existence d'un dossier `bin` ne signifie pas qu'il contient des programmes.
- **La recherche de *shells*** demandait, dans n'importe quel dossier, un fichier nommé `sh`, `bash`, `dash`, `ash` ou `busybox`, en plus de `revisor` et `passwd` comme témoins : si le motif était mal écrit, ces deux-là n'apparaîtraient pas non plus. Les deux témoins sont sortis, et aucun *shell*. Il n'y a pas de *shell*, et en 5.6 tu le confirmes d'une autre manière : en essayant de l'exécuter. Le `revisor` mesure 6 684 832 octets, les 6,69 Mo de la couche.
- **La date de `/etc/passwd`**, `1969-12-31 18:00`, est la date zéro de l'horloge Unix (le 1er janvier 1970 en temps universel) vue dans le fuseau horaire de la machine des exécutions. Les fichiers de la base portent cette date exprès : ainsi, deux constructions de la même base donnent exactement les mêmes octets. Le `revisor`, en revanche, porte la date à laquelle il a été compilé. Celle que tu vois ici est du petit matin de ce même jour : le binaire est sorti du cache de construction, car rien de ce qui le produit n'avait changé depuis l'exécution précédente sur cette machine. Sur la tienne, tu verras une autre date.
- **Le contenu de `/etc/passwd`** comporte trois utilisateurs, et le troisième est celui qu'utilise l'étape finale : `nonroot`, avec le numéro **65532**. Voilà la raison du `USER 65532:65532`. Remarque en outre la dernière colonne des trois : `/sbin/nologin`. Même `root` n'a pas de *shell* attribué.

> [!NOTE]
> 🔧 **Observation de génie logiciel 5.2**
> L'image finale n'a pas été « nettoyée » : elle est née sans le superflu. C'est la différence entre ranger une chambre et emménager dans une chambre vide avec une seule valise. La première se défait avec le temps ; la seconde repart propre à chaque construction.

### 5.5 Les tests à l'intérieur de la construction

#### 5.5.1 Exécuter seulement les tests

Le fait que les tests vivent dans leur propre étape permet de les exécuter **seuls**, sans construire l'image finale. `fig05_04.sh` construit jusqu'à l'étape `pruebas`, en l'obligeant à s'exécuter même si elle est dans le cache, et mesure l'image intermédiaire qui en résulte :

```bash
#!/usr/bin/env bash
# fig05_04.sh — La etapa de pruebas, sola: construye solo hasta «pruebas»,
# obligándola a correr de nuevo, y mide la imagen intermedia que queda.
# Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

PRUEBAS="${PREFIJO}revisor:pruebas"
trap 'docker rmi -f "$PRUEBAS" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Solo hasta la etapa de pruebas"
muestra "docker build --target pruebas --no-cache-filter pruebas --progress=plain -t $PRUEBAS . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[\$0]++'"

titulo "La imagen intermedia: sirve para probar, no para entregar"
muestra "docker image ls $PRUEBAS --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

`--no-cache-filter pruebas` indique à BuildKit de ne pas utiliser le cache pour cette étape ([docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)) : sans cela, comme rien n'a changé, les tests sortiraient du cache et tu ne verrais pas une seule ligne de `go test`.

```text
$ ./fig05_04.sh

## Solo hasta la etapa de pruebas
$ docker build --target pruebas --no-cache-filter pruebas --progress=plain -t curso-docker-revisor:pruebas . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[$0]++'
#6 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#8 [compilacion 3/5] COPY go.mod ./
#9 [compilacion 4/5] COPY cmd/ cmd/
#10 [compilacion 2/5] WORKDIR /src
#11 [compilacion 5/5] COPY internal/ internal/
#12 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     go test ./...
#12 15.92 ok  	github.com/habil/revisor/cmd/revisor	0.008s
#12 15.92 ok  	github.com/habil/revisor/internal/config	0.005s
#12 15.92 ok  	github.com/habil/revisor/internal/reporte	0.004s
#12 16.06 ok  	github.com/habil/revisor/internal/revisar	0.141s
#12 16.06 ok  	github.com/habil/revisor/internal/servicio	0.003s

## La imagen intermedia: sirve para probar, no para entregar
$ docker image ls curso-docker-revisor:pruebas --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:pruebas 1.31GB
```

Ce qui change : les numéros d'opération, les secondes de la troisième colonne (`15.92` correspond aux secondes écoulées depuis le début de cette opération) et les durées de chaque paquet. Ce qui est stable : les cinq paquets avec `ok`.

Trois choses à lire ici. La première : **seules `compilacion` et `pruebas` se sont exécutées**. Il n'y a pas une seule ligne de `binario` ni de `final` : c'est la règle de 5.2.3 en action, BuildKit n'a construit que ce dont l'étape demandée avait besoin. La deuxième : les cinq paquets du `revisor` ont passé leurs tests **à l'intérieur** de la construction, avec le même compilateur que l'image figée ; cela ne dépend pas du fait que Go soit installé sur ton ordinateur, ni de sa version. La troisième : l'image `pruebas` pèse **1,31 Go**. Elle sert à tester et à regarder, jamais à livrer. C'est pourquoi c'est une étape et non l'image finale.

#### 5.5.2 Un test en échec arrête la construction... s'il est sur le chemin

Voici maintenant l'erreur de cette section, et sa version silencieuse. `fig05_05.sh` ajoute un test qui échoue exprès, `rota_test.go`, et construit deux fois : avec le Dockerfile de la leçon et avec une variante qui modifie **une seule ligne**, pour que l'étape `binario` parte de `compilacion` au lieu de `pruebas` :

```bash
#!/usr/bin/env bash
# fig05_05.sh — Una prueba rota detiene la construcción... si el Dockerfile la
# pone en el camino. Agrega una prueba que falla a propósito y construye dos
# veces: con el Dockerfile de la lección y con una variante donde la etapa
# «binario» sale de «compilacion» en vez de «pruebas». Borra lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# La variante equivocada: un solo renglón distinto.
sed 's/^FROM pruebas AS binario/FROM compilacion AS binario/' Dockerfile > Dockerfile.salta-pruebas

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

ROTA="${PREFIJO}revisor:rota"
trap 'docker rmi -f "$ROTA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

cat > cmd/revisor/rota_test.go <<'GO'
package main

import "testing"

func TestRotaAProposito(t *testing.T) { t.Fatal("esta prueba falla a propósito") }
GO

titulo "Con el Dockerfile de la lección"
muestra "docker build --progress=plain -t $ROTA . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit \${PIPESTATUS[0]})"
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Con la variante: binario sale de compilacion"
muestra "diff Dockerfile Dockerfile.salta-pruebas"
muestra "docker build --progress=plain -t $ROTA -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo \"construcción: código \${PIPESTATUS[0]}\""
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

Le script utilise `set -uo pipefail`, sans `-e`, car il doit continuer après l'échec qu'il provoque. `${PIPESTATUS[0]}` est une variable de *bash* qui conserve le code de sortie de la **première** commande du pipeline précédent, le `docker build`, et non celui du `grep` qui filtre sa sortie ; `(exit N)` le renvoie pour que la fonction d'aide `muestra` le note.

```text
$ ./fig05_05.sh

## Con el Dockerfile de la lección
$ docker build --progress=plain -t curso-docker-revisor:rota . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit ${PIPESTATUS[0]})
#14 1.127     rota_test.go:5: esta prueba falla a propósito
#14 1.127 FAIL
#14 1.127 FAIL	github.com/habil/revisor/cmd/revisor	0.008s
#14 1.128 FAIL
1.127     rota_test.go:5: esta prueba falla a propósito
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1
[código de salida: 1]
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'

## Con la variante: binario sale de compilacion
$ diff Dockerfile Dockerfile.salta-pruebas
17c17
< FROM pruebas AS binario
---
> FROM compilacion AS binario
[código de salida: 1]
$ docker build --progress=plain -t curso-docker-revisor:rota -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo "construcción: código ${PIPESTATUS[0]}"
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
construcción: código 0
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:rota 16.1MB
```

Ce qui change : les numéros d'opération et les secondes. Le `[código de salida: 1]` après le `diff` n'est pas une erreur : `diff` se termine avec 1 quand il trouve des différences, ce qui est précisément ce qu'on lui a demandé de montrer.

**La première moitié est le comportement que tu veux.** (La ligne du test apparaît deux fois : la première, avec `#14`, est la sortie de l'opération pendant qu'elle s'exécute ; la seconde, sans numéro, est le résumé que BuildKit répète juste avant l'`ERROR` avec les dernières lignes de l'opération qui a échoué.) Le test échoue, `go test` affiche `FAIL` avec le fichier et la ligne (`rota_test.go:5`) ainsi que le message, et BuildKit arrête tout avec une `ERROR` qui indique quel processus a échoué et avec quel code : `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. La construction se termine avec 1 et, surtout, la deuxième commande n'affiche rien : **l'image `rota` n'existe pas**. Un code avec un test en échec ne produit pas d'image. Si ton serveur de construction publie ce qu'il construit, c'est ce qui empêche de publier quelque chose de cassé.

**La seconde moitié est l'erreur silencieuse.** Le `diff` confirme que la variante ne modifie qu'une seule ligne : `binario` part de `compilacion`. Le test en échec est toujours là. Et la construction se termine avec le **code 0** et une image de 16,1 Mo. Il n'y a ni `FAIL` ni `ERROR` parce que **les tests ne se sont jamais exécutés** : le filtre cherchait des lignes de `pruebas` et de `binario`, et seul `binario` apparaît (deux fois, car BuildKit a réaffiché l'en-tête de l'opération en la terminant). L'étape `pruebas` est toujours écrite dans le fichier, mais l'étape finale copie depuis `binario`, `binario` part de `compilacion`, et personne sur le chemin n'a besoin de `pruebas`. En vertu de la règle de 5.2.3, BuildKit ne la construit pas.

C'est le pire type d'erreur : elle ne prévient pas. Le Dockerfile *a l'air* correct, il comporte une étape de tests avec son commentaire, et qui le relit en diagonale croit que les tests protègent l'image. C'est pourquoi le `FROM pruebas AS binario` n'est pas un détail de style : c'est ce qui fait des tests une condition de l'existence de l'image.

> [!NOTE]
> 🔧 **Observation de génie logiciel 5.3**
> Une vérification qui peut être sautée sans que personne ne s'en aperçoive n'est pas une vérification. La façon de savoir si un point de contrôle fonctionne est celle de cette section : casse-le exprès et vérifie qu'il arrête la construction. Une construction au vert ne démontre pas que les tests ont réussi ; elle peut seulement démontrer qu'ils ne se sont pas exécutés.

### 5.6 La base minimale : sans *shell* et sans `root`

#### 5.6.1 Ce qu'est *distroless*

L'étape finale part de `gcr.io/distroless/static-debian13`. *Distroless* est une famille d'images de base publiée par Google, et son nom explique déjà l'idée : « sans distribution ». Sa documentation le formule ainsi : elles contiennent « uniquement ton application et ses dépendances d'exécution », et n'embarquent pas « de gestionnaires de paquets, de *shells* ni aucun autre programme que tu t'attendrais à trouver dans une distribution Linux standard » ([distroless](https://github.com/GoogleContainerTools/distroless)).

La famille comporte plusieurs variantes, selon ce dont le programme a besoin pour tourner : `base`, `cc`, et d'autres avec l'environnement Python, Java ou Node.js déjà installé. Celle qu'utilise le `revisor` est la plus petite de toutes, **`static`** : pour les programmes qui embarquent déjà tout et ne dépendent de rien du système. Sa documentation l'annonce à « environ 2 Mio ». Tes mesures ne donnent pas ce chiffre, et il vaut la peine de le dire : dans les couches de 5.4, tu l'as vue occuper environ 5,8 Mo une fois décompressée, et sa version compressée pour `arm64`, celle qui se télécharge, totalise 855 334 octets sur ses treize couches (mesuré le même jour avec `docker buildx imagetools inspect --raw` sur le *digest* `arm64` de 5.7). La documentation ne dit pas comment elle a mesuré ses 2 Mio, prends-le donc comme un ordre de grandeur : quelques mégaoctets, contre des centaines pour une base avec une distribution complète. Sur les 5,8 Mo décompressés, près de 4,4 Mo sont les fuseaux horaires (`tzdata` et `tzdata-legacy`). Elle contient le minimum dont un programme statique a encore besoin du monde extérieur : les certificats des autorités de certification (pour parler HTTPS), les fuseaux horaires, `/etc/passwd` avec ses trois utilisateurs et un dossier `/tmp`. Ce sont les couches que tu as vues en 5.4.

Le nom complet comporte trois parties qu'il vaut la peine de lire une à une :

- `static` : la variante, pour les binaires statiques.
- `debian13` : la version de Debian dont proviennent les quelques fichiers qu'elle contient (certificats, fuseaux horaires). La documentation recommande de toujours écrire la version de Debian dans le nom, pour que ta construction ne change pas de base sans prévenir le jour où sortira la suivante.
- `:nonroot` : le tag. *Distroless* publie peu de tags, qui sont des noms et non des versions : `latest`, `nonroot`, `debug` et `debug-nonroot`, ainsi que les mêmes avec un suffixe d'architecture, comme `nonroot-arm64` ([distroless](https://github.com/GoogleContainerTools/distroless)) ; aucun ne porte de version. `nonroot` est la même image, mais configurée pour tourner avec l'utilisateur `nonroot` au lieu de `root`. Les variantes `debug` embarquent un *shell* minimal pour déboguer ; elles ne sont pas faites pour la production.

#### 5.6.2 L'exécuter

`fig05_06.sh` exécute l'image minimale des deux façons dont le `revisor` est utilisé — comme programme qui fait une chose puis se termine, et comme service — et vérifie ce que la leçon a promis :

```bash
#!/usr/bin/env bash
# fig05_06.sh — Correr la imagen mínima: su versión, su salud, su reporte, que
# no tiene shell, que no es root y cuánto tarda en detenerse. Borra lo que crea.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# PUERTO: el puerto del equipo donde se publica el revisor, siempre en 127.0.0.1.
PUERTO="${PUERTO:-8080}"

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

IMAGEN="${PREFIJO}revisor:1.2.0"
NOMBRE="${PREFIJO}revisor"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1; docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT
docker build -q -t "$IMAGEN" . >/dev/null

titulo "Un subcomando, sin servidor"
muestra "docker run --rm --name ${PREFIJO}version $IMAGEN version"

titulo "Como servicio"
muestra "docker run -d --name $NOMBRE -p 127.0.0.1:$PUERTO:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' $IMAGEN >/dev/null"
esperar_http "http://127.0.0.1:$PUERTO/salud"
muestra "curl -s http://127.0.0.1:$PUERTO/salud; echo"
muestra "curl -s 'http://127.0.0.1:$PUERTO/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"

titulo "Sin shell y sin root"
muestra "docker exec $NOMBRE sh"
muestra "docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' $NOMBRE"
muestra "docker top $NOMBRE -o pid,user,args"

titulo "Detenerlo"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' $NOMBRE"
muestra "docker logs $NOMBRE"
```

Comme dans la Leçon 3, le `revisor` se surveille lui-même (`propio http://127.0.0.1:8080/salud`) parce que tu ne le connectes pas encore à d'autres conteneurs ; c'est l'objet de la Leçon 8. Le `sed` du rapport masque, à l'affichage, le temps de réponse, qui change à chaque exécution.

```text
$ ./fig05_06.sh

## Un subcomando, sin servidor
$ docker run --rm --name curso-docker-version curso-docker-revisor:1.2.0 version
desarrollo

## Como servicio
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud; echo
{"estado":"vivo","version":"desarrollo"}

$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <tiempo>  200

## Sin shell y sin root
$ docker exec curso-docker-revisor sh
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
[código de salida: 127]
$ docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' curso-docker-revisor
User=65532:65532 Entrypoint=[/revisor] Cmd=[]
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
1451351             65532               /revisor

## Detenerlo
docker stop tardó 298 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor
ExitCode=0
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 8ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Ce qui change : le PID (`1451351`), la durée de `docker stop`, la durée de `/api/estados` dans le journal et le nombre de fois où apparaît `GET /salud` (cela dépend du nombre de tentatives qu'a faites le script en attendant que le service réponde). Le reste sort à l'identique.

#### 5.6.3 Lire l'exécution

- **`version` a fonctionné comme sous-commande.** `docker run ... curso-docker-revisor:1.2.0 version` a exécuté `/revisor version`, grâce à l'`ENTRYPOINT`. Il affiche `desarrollo` parce que le binaire ne porte pas encore de version gravée ; la Leçon 6 la lui ajoute.
- **En tant que service, il fait la même chose qu'avant.** `/salud` répond, le rapport en tableau indique `OK`. L'image a été divisée par quatre-vingts et le comportement n'a changé en rien : tout ce qui a été retiré était, réellement, des bagages.
- **Il n'y a pas de *shell*.** `docker exec curso-docker-revisor sh` échoue avec le même message que celui que tu as vu avec le service de test dans la Leçon 2 : `exec: "sh": executable file not found in $PATH`, code 127. Tu sais maintenant pourquoi : la base est *distroless* et `sh` n'existe pas. Pour la scène du début, voici la réponse : quiconque parviendrait à exécuter quelque chose dans ce conteneur n'y trouverait ni *shell*, ni `curl`, ni compilateur.
- **Ce n'est pas `root`.** `docker inspect` indique `User=65532:65532`, et `docker top`, qui regarde le processus depuis l'hôte, le confirme : le processus appartient à l'utilisateur 65532. Il indique aussi `Entrypoint=[/revisor] Cmd=[]` : le programme est fixé par l'`ENTRYPOINT`, et il n'y a pas d'arguments par défaut.
- **Il s'arrête proprement.** `docker stop` a pris 298 ms, le code a été 0 et le journal se termine par `recibí terminated, apagando` et `apagado limpio` : la forme *exec* fait que le signal parvient au `revisor`, qui est le processus numéro 1. Remarque que dans la colonne `COMMAND` de `docker top` figure seulement `/revisor`, sans `/bin/sh -c` devant : il ne pourrait même pas y en avoir, puisqu'il n'y a pas de *shell*.

#### 5.6.4 Ce que coûte l'absence de *shell*

Une image sans *shell* a un prix, et il vaut la peine de le dire : **tu ne peux pas entrer fouiller**. Il n'y a ni `ls`, ni `cat`, ni `ps`, ni `sh`. Quand quelque chose échoue, les outils qui te restent sont ceux de l'extérieur, et ils suffisent :

- `docker logs`, pour ce que le programme écrit ;
- `docker inspect`, pour la configuration et l'état ;
- `docker top`, pour voir le processus depuis l'hôte ;
- `docker export` avec `tar`, pour voir les fichiers, comme en 5.4.4 ;
- et l'étape `binario` construite avec `--target`, qui dispose de tous les outils, pour examiner le programme de l'intérieur. Tu vas l'utiliser en 5.8.

Ce qui **ne** se fait **pas**, c'est remplacer la base finale par une base avec *shell* « pour pouvoir déboguer ». Si tu as vraiment besoin d'un *shell* à côté du processus, il existe des outils pour lui en connecter un depuis l'extérieur, temporairement, sans l'intégrer à l'image ; ce cours n'en a pas besoin.

### 5.7 Version et *digest* de la base

#### 5.7.1 Un tag est un alias qui bouge

Dans la Leçon 3, tu as vu qu'un tag comme `1.27.3-trixie` est plus spécifique que `latest`, et que malgré tout il peut changer : l'éditeur de l'image peut la republier. Le guide des bonnes pratiques de Docker le dit en toutes lettres : « les tags d'image sont mutables, ce qui signifie qu'un éditeur peut mettre à jour un tag pour qu'il pointe vers une nouvelle image » ([bonnes pratiques, figer la version de la base](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Pour *distroless*, la question est encore plus claire : son tag `nonroot` n'a pas de version, il pointe donc **par définition** vers la dernière publication. Écrire seulement `static-debian13:nonroot` revient, en pratique, à écrire `latest`.

#### 5.7.2 Ce qu'est un *digest*

Un ***digest*** est l'empreinte du contenu d'une image : on le calcule en faisant passer ses octets par une fonction de hachage, SHA-256, et il s'écrit `sha256:` suivi de 64 caractères hexadécimaux. La spécification des images de l'OCI le définit comme un « identifiant de contenu » qui « identifie le contenu de manière unique », calculé avec une fonction de hachage résistante aux collisions ([OCI, descripteurs](https://github.com/opencontainers/image-spec/blob/main/descriptor.md)). La conséquence pratique est celle qui compte : **si un seul octet de l'image change, le *digest* change**. Un *digest* ne peut pas être déplacé vers une autre image, car il est l'image.

`fig05_09.sh` demande au registre quel *digest* ont aujourd'hui les deux bases du Dockerfile, sans rien construire ni créer :

```bash
#!/usr/bin/env bash
# fig05_09.sh — Etiqueta contra digest: qué hay detrás de las dos bases.
# Solo consulta el registro y la copia local; no construye ni crea nada.
set -euo pipefail

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "La base de compilación: la etiqueta y el digest que hoy le corresponde"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'"
muestra "docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie"

titulo "La base final: distroless no publica versiones, solo nombres"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'"
```

`docker buildx imagetools inspect` demande au registre ce qu'il y a derrière un nom, sans télécharger l'image. `docker image inspect` avec `.RepoDigests` indique de quel *digest* provient la copie que tu as déjà sur ton ordinateur.

```text
$ ./fig05_09.sh

## La base de compilación: la etiqueta y el digest que hoy le corresponde
$ docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'
Name:      docker.io/library/golang:1.27.3-trixie
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
$ docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'
  Platform:    linux/amd64
  Platform:    linux/arm64/v8
$ docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie
golang@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c

## La base final: distroless no publica versiones, solo nombres
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'
Name:      gcr.io/distroless/static-debian13:nonroot
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a
  Platform:  linux/amd64
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:6964c30f0122730c54f70f8f51a777490f85d077d25da672830c43968c14993e
  Platform:  linux/arm64/v8
```

Cette sortie est celle du 21 octobre 2026. **C'est celle qui peut le plus changer dans toute la leçon**, et pas à cause de ton ordinateur : le jour où Google publiera une nouvelle base avec le tag `nonroot`, le `Digest` de la quatrième requête sera différent. Celui de `golang:1.27.3-trixie` peut aussi changer si son éditeur la reconstruit. Et si tu n'as jamais téléchargé l'image de Go, la troisième requête échoue parce que tu n'en as pas de copie locale.

#### 5.7.3 Lire la sortie

- **Le `MediaType` indique `image.index`.** Ce qu'il y a derrière ces tags n'est pas une image mais un **index** : une liste d'images, une par plateforme. C'est pourquoi la deuxième et la cinquième requête trouvent une entrée pour `linux/amd64` et une autre pour `linux/arm64/v8`, chacune avec son propre *digest*. Le *digest* qu'écrit le Dockerfile est **celui de l'index** : avec lui, la même ligne fonctionne sur ton Mint à processeur Intel ou AMD et sur la machine ARM de ces exécutions, et Docker choisit l'image de ta plateforme dans l'index.
- **Les deux *digest* du Dockerfile coïncident avec ceux de ce jour-là** : `6041…` pour Go et `5167…` pour *distroless*. La copie locale de Go provenait de ce même *digest*.
- **Si tu écris le *digest* d'une plateforme** (par exemple, le `6964…` d'`arm64`) au lieu de celui de l'index, la base reste liée à cette architecture : qui construit sur une autre ne reçoit plus la base de la sienne. C'est une erreur facile à commettre si tu copies le *digest* de la mauvaise ligne.

#### 5.7.4 Tag **et** *digest*

Le Dockerfile écrit les deux ensemble : `golang:1.27.3-trixie@sha256:6041…`. La syntaxe est permise par la référence : `FROM <image>[@<digest>] [AS <nom>]` ([référence, `FROM`](https://docs.docker.com/reference/dockerfile/#from)). Quand il y a un *digest*, c'est le *digest* qui commande : Docker télécharge exactement ces octets, quoi qu'indique le tag aujourd'hui. Alors, à quoi sert le tag ? Aux personnes : `@sha256:6041…` ne dit à personne de quelle version de Go il s'agit ; `1.27.3-trixie`, si. Le tag documente ; le *digest* garantit.

Le guide des bonnes pratiques explique la garantie et aussi son prix. La garantie : avec le *digest*, « tu as la garantie de toujours utiliser la même version de l'image, même si l'éditeur remplace le tag par une nouvelle image ». Le prix : un *digest* figé **ne se met pas à jour tout seul**, si bien que les correctifs de sécurité de la base ne t'arrivent pas tout seuls non plus ([bonnes pratiques](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Figer n'est pas oublier : c'est décider quand tu changes de base, en le vérifiant, au lieu qu'elle change sans prévenir au milieu d'une construction. Le même guide mentionne des outils qui ouvrent des pull requests automatiques quand un nouveau *digest* sort. Et la Leçon 10 t'apprend à analyser la base figée pour savoir quand il est temps de la renouveler.

> [!NOTE]
> 🔧 **Observation de génie logiciel 5.4**
> Une construction reproductible est celle qui donne le même résultat aujourd'hui et dans trois mois avec le même code. Sans *digest*, le même Dockerfile peut produire deux images différentes sans que personne n'ait touché à rien, et le jour où quelque chose échoue, tu ne pourras pas savoir si c'est ton changement ou celui de la base.

### 5.8 Le binaire qui ne démarre pas

#### 5.8.1 Le provoquer

Voici la partie de la leçon où tout a l'air correct et où rien ne fonctionne. `fig05_07.Dockerfile` est le Dockerfile de la leçon avec **une seule modification** : le `RUN` de l'étape `binario` ne comporte pas `CGO_ENABLED=0` :

```dockerfile
# syntax=docker/dockerfile:1
# fig05_07.Dockerfile — Lección 5: el error a propósito: el mismo Dockerfile SIN CGO_ENABLED=0.

# --- Etapa 1: el código, sobre la imagen de Go (fijada por versión Y por digest) ---
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

# --- Etapa 2: las pruebas. Si fallan, la construcción se detiene aquí ---
FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

# --- Etapa 3: el binario, estático (CGO_ENABLED=0), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

Le commentaire de l'étape 3 dit toujours « statique », exprès : c'est ainsi que se présentent ces erreurs dans la vraie vie, avec un commentaire qui ne dit plus la vérité. `fig05_08.sh` construit cette image, l'exécute, puis examine les deux binaires, celui de cette image et celui de la leçon, depuis l'étape `binario`, qui dispose d'outils :

```bash
#!/usr/bin/env bash
# fig05_08.sh — El error de esta lección: el binario que no es estático.
# Construye la imagen de fig05_07.Dockerfile (sin CGO_ENABLED=0), la corre, y
# después mira los dos binarios del revisor por dentro, el de esa imagen y el
# de la lección. Borra lo que crea al salir.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig05_07.Dockerfile" "$TRABAJO/revisor/Dockerfile.dinamico"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.dinamico && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

DINAMICO="${PREFIJO}revisor:dinamico"
B_DIN="${PREFIJO}revisor:binario-dinamico"
B_EST="${PREFIJO}revisor:binario-estatico"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$DINAMICO" "$B_DIN" "$B_EST" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construye sin error... y no arranca"
muestra "docker build -q -t $DINAMICO -f Dockerfile.dinamico . >/dev/null; echo \"construcción: código \$?\""
muestra "docker run --rm --name ${PREFIJO}dinamico $DINAMICO version"

titulo "Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)"
docker build -q --target binario -t "$B_DIN" -f Dockerfile.dinamico . >/dev/null
docker build -q --target binario -t "$B_EST" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mirar $B_DIN sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'"
muestra "docker run --rm --name ${PREFIJO}mirar $B_EST sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo \"(sin intérprete)\"'"

titulo "¿Está ese intérprete en la imagen final?"
docker create --name "${PREFIJO}mirar" "$DINAMICO" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -E 'ld-linux|libc\\.so' || echo '(no está)'"
```

`ldd` est un outil Linux qui liste les bibliothèques partagées dont un programme a besoin pour démarrer. `readelf -l` affiche les en-têtes d'un exécutable Linux (format ELF), et parmi eux la ligne qui indique quel programme doit le charger. Les deux existent dans l'image de Go, pas dans *distroless* : c'est pourquoi on les utilise depuis l'étape `binario`, construite avec `--target`.

```text
$ ./fig05_08.sh

## Construye sin error... y no arranca
$ docker build -q -t curso-docker-revisor:dinamico -f Dockerfile.dinamico . >/dev/null; echo "construcción: código $?"
construcción: código 0
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]

## Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-dinamico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'
	linux-vdso.so.1 (0x0000fd7da7955000)
	libc.so.6 => /lib/aarch64-linux-gnu/libc.so.6 (0x0000fd7da7750000)
	/lib/ld-linux-aarch64.so.1 (0x0000fd7da7910000)
      [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-estatico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo "(sin intérprete)"'
	not a dynamic executable
(sin intérprete)

## ¿Está ese intérprete en la imagen final?
$ docker export curso-docker-mirar | tar -t | grep -E 'ld-linux|libc\.so' || echo '(no está)'
(no está)
```

Ce qui change : les adresses entre parenthèses (`0x0000fd7d…`), qui sont différentes à chaque exécution. Sur un ordinateur Intel ou AMD, les chemins indiquent `x86_64` au lieu d'`aarch64` : l'interpréteur est `/lib64/ld-linux-x86-64.so.2` et la bibliothèque se trouve dans `/lib/x86_64-linux-gnu/`. Le message d'erreur et le code 255 sortent à l'identique.

#### 5.8.2 Lire l'erreur

La construction s'est terminée avec le **code 0** : rien dans le Dockerfile n'est mal écrit, les tests ont réussi et le binaire a été compilé. L'erreur n'apparaît qu'à l'**exécution** : `exec /revisor: no such file or directory`, avec le code 255. Ce code n'a pas été posé par le `revisor`, qui n'a jamais pu s'exécuter : l'échec s'est produit en tentant de le démarrer.

Le message est l'un des plus déroutants que tu verras dans Docker, car **le fichier `/revisor` existe bel et bien** : le `COPY --from` l'a copié, et en 5.4 tu l'as vu dans la liste des fichiers de l'image. Ce qui n'existe pas, c'est un **autre** fichier, et la deuxième partie de la sortie dit lequel :

- `ldd` sur le binaire de cette image liste trois choses dont il a besoin du système : `libc.so.6`, la bibliothèque C de Debian, et `/lib/ld-linux-aarch64.so.1`, le **chargeur dynamique** (`linux-vdso.so.1` est fournie par le noyau lui-même et n'est pas un fichier). `readelf` le confirme par une ligne explicite : `Requesting program interpreter: /lib/ld-linux-aarch64.so.1`, « je demande `/lib/ld-linux-aarch64.so.1` comme interpréteur du programme ».
- Le binaire de la leçon, en revanche, est `not a dynamic executable` et ne demande pas d'interpréteur : il est **statique**, il embarque tout ce dont il a besoin.
- Et la dernière requête cherche le chargeur et la bibliothèque C dans l'image finale : `(no está)`. La base `static` ne les contient pas, car elle est faite pour les programmes statiques.

Le manuel de Linux explique la chaîne. Un programme dynamique ne démarre pas seul : le noyau lit dans l'exécutable lui-même quel est son chargeur, celui qui est « stocké dans la section `.interp` du programme », et l'exécute pour que celui-ci trouve et charge « les objets partagés (bibliothèques partagées) dont il a besoin » ([ld.so(8)](https://man7.org/linux/man-pages/man8/ld.so.8.html)). Si ce chargeur n'existe pas, l'appel système qui démarre les programmes, `execve`, échoue avec l'erreur `ENOENT`, que le manuel décrit ainsi : « le chemin, ou un interpréteur de *script* ou d'ELF, n'existe pas » ([execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html)). `ENOENT` est précisément l'erreur qui s'affiche sous la forme `no such file or directory`. Le message ne ment pas ; il ne dit simplement pas **quel** fichier manque, et celui qui manque n'est pas celui qu'il nomme.

#### 5.8.3 Pourquoi Go a produit un binaire dynamique

Go est réputé pour produire des binaires qui ne dépendent de rien, et c'est vrai presque toujours. L'exception est *cgo*, le mécanisme par lequel un programme Go appelle du code C. La documentation de Go indique que *cgo* « est activé par défaut pour les compilations natives, sur les systèmes où il est censé fonctionner », et qu'on le désactive avec la variable `CGO_ENABLED=0` ([cmd/cgo](https://pkg.go.dev/cmd/cgo)). L'image de Go embarque un compilateur C (tu l'as vu en 5.1 : `gcc`), si bien que *cgo* y est activé.

Et pourquoi le `revisor` voudrait-il du code C, alors qu'il n'a pas une seule ligne de C ? À cause du réseau. Le `revisor` utilise le paquet `net` de la bibliothèque standard, pour son serveur et pour interroger d'autres services. Ce paquet propose deux façons de convertir un nom en adresse : l'une écrite en Go pur et l'autre qui appelle les fonctions de la bibliothèque C du système. Normalement il utilise celle de Go, mais dans certaines configurations du système il utilise celle de C ([paquet net, « Name Resolution »](https://pkg.go.dev/net#hdr-Name_Resolution)). Pour pouvoir choisir à l'exécution, quand *cgo* est disponible, le binaire embarque les deux, et c'est ce que tu as vu avec `ldd` en 5.8.1 : la dépendance à `libc.so.6` et au chargeur. Avec `CGO_ENABLED=0`, Go n'utilise que sa propre implémentation et le binaire est statique.

La correction est donc celle de l'étape `binario` de la leçon : `CGO_ENABLED=0` devant le `go build`. Inutile de changer de base ou de copier des bibliothèques manuellement.

> [!NOTE]
> 🔧 **Observation de génie logiciel 5.5**
> Une construction au vert ne garantit pas une image qui démarre. Entre construire et exécuter, il existe un accord implicite entre le binaire et la base : ce que l'un demande, l'autre doit l'avoir. C'est pourquoi chaque nouvelle image est **exécutée** avant d'être jugée bonne, ne serait-ce qu'avec une sous-commande aussi simple que `version`.

### 5.9 Ce que tu rencontreras dans les vieux tutoriels

Les constructions en plusieurs étapes sont arrivées dans Docker avec la version 17.05, du 4 mai 2017 : les notes de cette version annoncent la « prise en charge des constructions multi-étapes » et, dans la même liste, l'option permettant d'indiquer l'étape cible ([notes de Docker Engine 17.05](https://docs.docker.com/engine/release-notes/17.05/)). Avant cela, le problème de cette leçon se résolvait avec des astuces que tu verras encore dans de vieux dépôts :

- **Le « builder pattern » avec deux Dockerfile.** Un `Dockerfile.build` construisait une image avec le compilateur ; un script *shell* créait un conteneur à partir de cette image, en extrayait le binaire avec `docker cp`, puis construisait une seconde image avec un autre Dockerfile. Cela fonctionnait, mais c'étaient trois étapes qu'il fallait garder synchronisées manuellement. Une seule construction en plusieurs étapes fait la même chose.
- **Des `RUN` enchaînés avec `&&` qui installent, compilent et suppriment en une seule ligne**, pour que ce qui est supprimé ne reste dans aucune couche. C'était la façon d'économiser de l'espace avec une seule étape ; cela reste moins efficace que de ne pas mettre le compilateur dans l'image finale.
- **`FROM scratch`.** `scratch` est une image vide, sans un seul fichier. Un binaire statique peut y tourner, et de nombreux tutoriels le font. Il lui manque ce que *distroless* `static` contient : des certificats pour HTTPS, les fuseaux horaires et un `/etc/passwd` avec un utilisateur sans privilèges. Pour le `revisor`, qui interroge des services et ne doit pas tourner en tant que `root`, la base du cours évite d'avoir à ajouter ces éléments manuellement.
- **`FROM alpine` comme base finale « parce qu'elle est toute petite ».** Alpine est petite, mais elle embarque un *shell* et un gestionnaire de paquets, et elle utilise une autre bibliothèque C (musl), différente de celle de Debian : un binaire dynamique compilé dans l'image Go de Debian n'y démarre pas, pour la même raison qu'en 5.8.
- **`COPY --from=0`**, avec un numéro au lieu d'un nom. Cela fonctionne, mais cela se casse silencieusement le jour où quelqu'un ajoute une étape au début.

## L'erreur que tu vas voir

Cette leçon comporte une erreur principale et une erreur qui ne se voit pas.

**L'erreur principale : `exec /revisor: no such file or directory`.** C'est celle de `fig05_08.sh` :

```text
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]
```

Elle se lit ainsi : le conteneur n'a pas pu **démarrer** le programme, et le programme ne s'est jamais exécuté (c'est pourquoi il n'a rien affiché de lui-même). Le piège, c'est que le fichier qu'elle nomme existe bel et bien. Ce qui manque, c'est ce dont ce fichier a besoin pour démarrer : son chargeur dynamique et les bibliothèques qu'il demande. Quand tu vois ce message avec une base minimale, la marche à suivre est la suivante :

1. Construis l'étape du binaire avec `--target` et examine le programme avec `ldd` et `readelf -l`. S'il indique `not a dynamic executable`, le problème est ailleurs (vérifie le chemin de l'`ENTRYPOINT`). S'il liste des bibliothèques et un interpréteur, tu as trouvé la cause.
2. Corrige-le à la compilation : pour Go, `CGO_ENABLED=0`. Si un programme a réellement besoin de la bibliothèque C, la bonne base est une base qui la fournit, pas la variante `static` : *distroless* propose des variantes plus complètes, comme `base` et `cc`, et sa documentation indique ce que contient chacune.
3. Ce qui **ne** se fait **pas**, c'est copier des bibliothèques isolées dans l'image finale jusqu'à ce qu'elle démarre, ni remplacer la base par une base avec *shell* « pour que ça marche ». La première solution est fragile et la seconde défait la leçon.

**L'erreur qui ne se voit pas : l'étape de tests que personne n'exécute.** C'est la seconde moitié de `fig05_05.sh` : avec `FROM compilacion AS binario`, un test en échec n'arrête pas la construction, car BuildKit ne construit pas une étape dont l'image finale ne dépend pas. Il n'y a pas de message à lire ; le symptôme est justement qu'il n'y a **pas** de `FAIL`. La seule façon de la trouver est celle de cette figure : ajoute un test en échec exprès et vérifie que la construction échoue avec `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. Si elle se termine avec le code 0, vérifie de quelle étape part ton étape du binaire.

## L'habitude de sécurité de la leçon

**Livrer uniquement ce qui est nécessaire pour tourner, sur une base minimale, figée et sans `root`.** L'image finale n'a ni *shell*, ni gestionnaire de paquets, ni compilateur, ni `curl` ; elle tourne avec l'utilisateur 65532 ; et sa base est figée par *digest*. Cette habitude évite trois accidents concrets. Le premier est celui de la scène : quiconque parvient à exécuter quelque chose dans le conteneur — à cause d'une erreur du programme, par exemple — ne trouve pas d'outils pour télécharger, compiler ni exécuter quoi que ce soit d'autre ; il doit tout apporter, et sans *shell* il n'a même pas de quoi l'exécuter. Le deuxième est la base qui change toute seule : sans *digest*, une construction de demain peut embarquer une base différente de celle d'aujourd'hui sans que personne ne l'ait décidé. Le troisième est le bruit : un scanner qui examine 16 Mo avec quelques paquets te dit quelque chose que tu peux lire ; un scanner qui examine 1,32 Go avec deux cents paquets Debian, non. Que l'image soit en plus quatre-vingts fois plus petite est la conséquence, pas l'objectif.

## Ce qui se fait de travers

**Réduire l'image en supprimant des fichiers avec `RUN rm`.** Ce qui est supprimé reste dans la couche du dessous ; l'image ne diminue pas. Ce qui ne doit pas voyager reste dans une autre étape.

**Livrer l'image en une seule étape « parce qu'elle fonctionne ».** Elle fonctionne aussi bien que celle de 16 Mo, et elle transporte un atelier complet pour qui y entre. Qu'elle tourne n'est pas le critère ; le critère, c'est ce qu'elle transporte d'autre.

**Faire partir le binaire de l'étape de compilation et laisser les tests dans une étape à part dont personne n'a besoin.** On dirait qu'il y a des tests, et il n'y en a pas (5.5). Le binaire part **de** l'étape de tests.

**Figer la base uniquement par tag, ou utiliser le tag `nonroot` de *distroless* sans *digest*.** C'est utiliser `latest` sous un autre nom. Le tag pour lire, le *digest* pour garantir.

**Copier le *digest* d'une plateforme au lieu de celui de l'index.** La base reste liée à une seule architecture, et qui construit sur une autre ne reçoit pas celle qui lui correspond. Le *digest* qui va dans le `FROM` est celui de la ligne `Digest:` du haut, celle de l'index.

**Remplacer la base finale par une base avec *shell* « pour pouvoir déboguer ».** On débogue depuis l'extérieur (`logs`, `inspect`, `top`, `export`) et depuis l'étape de construction avec `--target` ; l'image livrée n'emporte pas d'outils au cas où.

**Utiliser `CMD` quand l'image est un programme avec des sous-commandes.** Avec `CMD ["revisor"]`, `docker run image version` remplace tout le programme. Avec `ENTRYPOINT ["/revisor"]`, il s'ajoute comme argument.

**Juger une image bonne parce qu'elle s'est construite.** Le binaire dynamique de 5.8 se construit sans une seule erreur. Une image est jugée bonne quand elle **tourne**.

## Exercices

Fais-les dans l'ordre. Avant chacun, écris dans ton [journal de bord](bitacora.md) ce que tu penses qu'il va se passer ; comparer ensuite représente la moitié de l'apprentissage. Si tu exécutes quelque chose, supprime à la fin ce que tu as créé : tout porte le préfixe `curso-docker-`.

### Exercice 1 — Quelles étapes s'exécutent ?

Avec le Dockerfile de la leçon (fig05_02), et en supposant que le cache est vide, indique quelles étapes BuildKit construit dans chaque cas :

1. `docker build -t curso-docker-revisor:1.2.0 .`
2. `docker build --target pruebas -t curso-docker-revisor:pruebas .`
3. `docker build --target compilacion -t curso-docker-revisor:compilacion .`
4. Avec la variante de `fig05_05.sh` (`FROM compilacion AS binario`) : `docker build -t curso-docker-revisor:1.2.0 .`

Et une question de plus : dans le cas 2, l'image obtenue contient-elle le binaire `/out/revisor` ?

### Exercice 2 — Corrige le Dockerfile d'un autre

Un collègue te transmet ce Dockerfile « en plusieurs étapes » pour le `revisor`. Trouve **six** problèmes qui provoquent un accident, dis lequel provoque chacun et écris la version corrigée. (Il y a en plus deux détails de style qui méritent d'être corrigés ; ils ne comptent pas parmi les six.)

```dockerfile
FROM golang:latest
WORKDIR /src
COPY . .
RUN go test ./...

FROM golang:latest
WORKDIR /src
COPY . .
RUN go build -o /revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=1 /revisor /revisor
CMD ["/revisor"]
```

Indice : l'un des six est l'erreur principale de la leçon et un autre est l'erreur qui ne se voit pas.

### Exercice 3 — Le bon `FROM`

Avec la sortie de `fig05_09.sh` sous les yeux, écris le `FROM` de l'étape finale pour ces trois cas, et dis lequel des trois est le bon pour le cours :

1. Uniquement par tag.
2. Par tag et par le *digest* qui fonctionne sur n'importe quelle plateforme.
3. Par tag et par le *digest* de ta plateforme, si ton Mint tourne sur Intel ou AMD.

Que se passe-t-il dans le cas 3 si un collègue doté d'un ordinateur ARM construit ton Dockerfile ?

### Exercice 4 — Ton image, mesurée (projet)

Dans ton dossier `~/curso-docker/revisor`, avec l'image `curso-docker-revisor:1.2.0` que tu as construite en 5.3.3, vérifie sans regarder la leçon :

1. Sa taille, comparée à celle de la `1.1.0` que tu as notée dans la Leçon 4. Note les deux dans ton journal de bord.
2. Qu'elle n'a pas de *shell*.
3. Qu'elle ne tourne pas en tant que `root`, de deux façons différentes : l'une qui lit la configuration de l'image et l'autre qui regarde le processus depuis l'hôte.
4. Que le binaire de ton image est statique, sans entrer dans l'image finale.

L'exercice est autocorrectif : tu as terminé quand tu as quatre commandes dont les sorties indiquent, respectivement, environ 16 Mo, `executable file not found`, `65532` (deux fois) et `not a dynamic executable`.

## Solutions

### Solution 1

1. Les quatre : `final` copie depuis `binario`, `binario` part de `pruebas` et `pruebas` part de `compilacion`. C'est la chaîne qui oblige à exécuter les tests. Tu l'as vu dans le premier bloc de `fig05_03.sh`.
2. `compilacion` et `pruebas`, et rien d'autre. C'est exactement ce qu'a montré `fig05_04.sh` : pas une seule ligne de `binario` ni de `final`.
3. Seulement `compilacion`.
4. `compilacion`, `binario` et `final`. **`pruebas` ne s'exécute pas**, car personne sur le chemin de l'étape finale n'en a besoin : c'est la seconde moitié de `fig05_05.sh`, qui s'est terminée avec le code 0 et une image, avec un test en échec à l'intérieur.

La question supplémentaire : **non**. L'étape `pruebas` ne fait qu'exécuter `go test` ; le binaire est produit dans l'étape `binario`, qui vient après et n'a pas été construite. L'image `pruebas` contient le code source et le compilateur, c'est pourquoi elle pèse 1,31 Go.

### Solution 2

1. **`golang:latest`.** La base peut changer à n'importe quelle construction, et avec elle la version de Go : le même code se compile différemment d'un jour à l'autre. Il faut `golang:1.27.3-trixie@sha256:…`.
2. **L'étape du binaire ne part pas de celle des tests.** C'est un `FROM golang:latest` séparé, si bien que l'étape de tests n'est pas sur le chemin de la finale et que BuildKit **ne l'exécute pas** : un test en échec n'arrête rien (l'erreur qui ne se voit pas, 5.5). L'étape du binaire doit partir de celle des tests.
3. **Il manque `CGO_ENABLED=0`.** Le binaire sort dynamique et, dans *distroless* `static`, il échoue avec `exec /revisor: no such file or directory` (l'erreur principale, 5.8).
4. **`COPY --from=1` avec un numéro.** Le jour où quelqu'un ajoute ou retire une étape au début, le numéro pointe vers une autre étape et c'est la mauvaise chose qui est copiée, sans prévenir. Avec des noms (`COPY --from=binario`), cela n'arrive pas.
5. **La base finale sans *digest*.** Le tag `nonroot` sans *digest*, c'est `latest` sous un autre nom : la base peut changer sans que personne ne l'ait décidé (5.7).
6. **`CMD` au lieu d'`ENTRYPOINT`.** Avec `CMD ["/revisor"]`, `docker run image version` remplace tout le programme et Docker tente d'exécuter un fichier nommé `version`, qui n'existe pas (5.3.2).

Les deux détails de style : le `COPY . .` répété dans deux étapes (il copie deux fois tout le contexte ; avec une étape `compilacion` commune, une seule fois suffit, et avec des `COPY` sélectifs, comme dans la Leçon 4) et le `USER` implicite (la base `nonroot` tourne déjà en tant que 65532, car sa configuration indique `"User": "65532"`, mais écrire `USER 65532:65532` rend l'intention visible à qui lit le Dockerfile).

La version corrigée est le Dockerfile de la leçon, `fig05_02.Dockerfile`.

### Solution 3

1. `FROM gcr.io/distroless/static-debian13:nonroot AS final`
2. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final`
3. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a AS final`

Le bon est le 2 : le *digest* de l'index, celui de la ligne `Digest:`, qui fonctionne en `amd64` et en `arm64`. Avec le 3, la base reste liée à l'image `linux/amd64` : sur l'ordinateur ARM de ton collègue, Docker ne peut plus choisir la base de sa plateforme dans l'index, car le `FROM` ne nomme pas l'index mais une seule de ses images, et son image finale se retrouverait avec une base d'une autre architecture que celle de son binaire. Cette leçon n'a pas exécuté ce cas ; ce qui compte, c'est qu'avec le *digest* de l'index, la question ne se pose même pas. Les *digest* de cette solution sont ceux du 21 octobre 2026 ; si `fig05_09.sh` t'en montre d'autres, utilise les tiens et note dans ton journal de bord que la base a changé.

### Solution 4

Une façon de procéder :

```bash
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0
docker exec curso-docker-revisor sh
docker inspect --format '{{.Config.User}}' curso-docker-revisor
docker top curso-docker-revisor -o pid,user,args
docker build -q --target binario -t curso-docker-revisor:binario .
docker run --rm curso-docker-revisor:binario ldd /out/revisor
docker rm -f curso-docker-revisor && docker rmi curso-docker-revisor:binario
```

Les sorties attendues sont celles de la leçon : `16.1MB` (quelques mégaoctets de plus ou de moins sur Intel ou AMD) contre `1.32GB` ; l'erreur `exec: "sh": executable file not found in $PATH` avec le code 127 ; `65532:65532` dans `inspect` et `65532` dans la colonne `USER` de `top` ; et `not a dynamic executable` dans `ldd` (comme dans `fig05_08.sh`). Si, à la dernière étape, `ldd` liste `libc.so.6`, ton Dockerfile a perdu le `CGO_ENABLED=0`.

## Comment je sais que j'ai réussi

Coche chaque point uniquement si tu peux le faire **sans revenir au texte** :

- [ ] `docker image ls curso-docker-revisor` affiche le tag `1.2.0` avec environ **16 Mo**, et tu as noté dans ton journal de bord l'avant et l'après (dans l'exécution de cette leçon, 1,32 Go → 16,1 Mo).
- [ ] `docker run --rm curso-docker-revisor:1.2.0 version` affiche `desarrollo`.
- [ ] `docker exec` avec `sh` sur un conteneur de ton image échoue avec `executable file not found in $PATH`, et `docker top` affiche le processus avec l'utilisateur `65532`.
- [ ] Tu as ajouté un test en échec dans ton dossier, `docker build -t curso-docker-revisor:rota .` a échoué avec `exit code: 1` et `docker image ls curso-docker-revisor:rota` n'affiche rien ; ensuite, tu as supprimé le test.
- [ ] Tu expliques pourquoi `FROM pruebas AS binario` et non `FROM compilacion AS binario`, avec la phrase de BuildKit sur les étapes qu'il construit.
- [ ] Tu expliques quel fichier manque quand apparaît `exec /revisor: no such file or directory`, et comment tu le confirmes avec `ldd` ou `readelf` depuis l'étape `binario`.
- [ ] Tu dis ce que garantit le tag, ce que garantit le *digest* et pourquoi le *digest* du `FROM` est celui de l'index.
- [ ] Tu as exécuté les scripts de [`programas/05-multi-stage/`](../programas/05-multi-stage) et tes sorties coïncident avec celles de cette leçon pour ce que chaque section signale comme stable. Ce qui ne se compare pas : les numéros d'opération, les PID, les durées, les dates, les adresses de `ldd`, l'architecture, les tailles à quelques mégaoctets près, et les *digest* de `fig05_09.sh` si la base a été republiée. Et à la fin, `docker ps -a --filter name=curso-docker-` n'affiche aucun conteneur de cette leçon.

## Résumé

Réponds sans regarder la leçon :

1. Pourquoi l'image de la Leçon 4 pesait-elle 1,32 Go alors que le `revisor` pesait 9,5 Mo ? Pourquoi supprimer le compilateur avec un `RUN rm` ne la réduit-il pas ?
2. Qu'est-ce qu'une étape ? Que font `AS`, `COPY --from` et `--target` ?
3. Quelles étapes BuildKit construit-il quand tu demandes l'image finale ? Quelle conséquence cela a-t-il pour l'étape de tests ?
4. Que contient et que ne contient pas la base *distroless* `static` ? Quels outils te restent pour déboguer une image sans *shell* ?
5. Pourquoi le Dockerfile utilise-t-il `ENTRYPOINT ["/revisor"]` au lieu de `CMD ["revisor"]` ?
6. Qu'est-ce qu'un *digest* ? Pourquoi écrit-on le tag et le *digest* ensemble, et quel est le prix de figer la base ?
7. Que signifie `exec /revisor: no such file or directory` quand le fichier existe bel et bien ? Que fait `CGO_ENABLED=0` ?

## Sources

Toutes consultées le 21 octobre 2026.

- [Docker, « Multi-stage builds »](https://docs.docker.com/build/building/multi-stage/) : plusieurs `FROM`, copier sélectivement entre étapes, nommer les étapes, `--target`, et le fait que BuildKit ne construit que les étapes dont dépend l'étape cible.
- [Docker, « containerd image store »](https://docs.docker.com/engine/storage/containerd/) : le fait que le magasin d'images de containerd conserve chaque couche compressée et décompressée, ce qui explique la taille de `docker image ls`.
- [Docker, bonnes pratiques pour construire des images](https://docs.docker.com/build/building/best-practices/) : les étapes pour réduire la taille, la base minimale, les tags mutables et le figeage par *digest* avec son prix.
- [Référence du Dockerfile](https://docs.docker.com/reference/dockerfile/) : la syntaxe `FROM <image>[@<digest>] [AS <nom>]`, `COPY --from` et la façon dont `ENTRYPOINT` et `CMD` reçoivent les arguments de `docker run`.
- [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/) : les options `--target` et `--no-cache-filter`.
- [Docker Engine 17.05, notes de version](https://docs.docker.com/engine/release-notes/17.05/) : l'arrivée des constructions en plusieurs étapes et de l'étape cible, le 4 mai 2017.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions et dates citées dans « À propos des exécutions ».
- [distroless (GoogleContainerTools)](https://github.com/GoogleContainerTools/distroless) : ce que contiennent et ne contiennent pas les images *distroless*, la taille de `static-debian13`, ses tags et la recommandation de nommer la version de Debian.
- [golang sur Docker Hub](https://hub.docker.com/_/golang) : le tag `1.27.3-trixie` et ses alias.
- [OCI Image Specification, descripteurs](https://github.com/opencontainers/image-spec/blob/main/descriptor.md) : ce qu'est un *digest* et pourquoi il identifie le contenu.
- [cmd/cgo](https://pkg.go.dev/cmd/cgo) : quand *cgo* est activé et comment on le désactive avec `CGO_ENABLED=0`.
- [Paquet net de Go, « Name Resolution »](https://pkg.go.dev/net#hdr-Name_Resolution) : les deux façons de résoudre les noms, celle en Go pur et celle qui utilise la bibliothèque C.
- [cmd/link](https://pkg.go.dev/cmd/link) : les options `-s` et `-w` de l'éditeur de liens, et le fait que `-s` implique `-w`.
- [cmd/go, `go build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies) : l'option `-trimpath`.
- [ld.so(8), manuel de Linux](https://man7.org/linux/man-pages/man8/ld.so.8.html) : le chargeur dynamique et la section `.interp`.
- [execve(2), manuel de Linux](https://man7.org/linux/man-pages/man2/execve.2.html) : l'erreur `ENOENT` quand l'interpréteur d'un ELF est absent.
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **binaire dynamique** | exécutable qui a besoin de bibliothèques du système et d'un chargeur pour démarrer |
| **binaire statique** | exécutable qui embarque tout ce dont il a besoin ; ne dépend pas des bibliothèques du système |
| **chargeur dynamique** | programme (`ld-linux…`) qui démarre un binaire dynamique et charge ses bibliothèques |
| ***cgo*** | mécanisme par lequel un programme Go appelle du code C ; se désactive avec `CGO_ENABLED=0` |
| ***digest*** | empreinte SHA-256 du contenu d'une image ou d'un index ; si un octet change, l'empreinte change |
| ***distroless*** | famille d'images de base minimales, sans *shell* ni gestionnaire de paquets |
| **étape** (*stage*) | chaque partie d'un Dockerfile qui commence par un `FROM` ; seule la dernière est l'image livrée |
| **étape cible** (*target*) | l'étape jusqu'à laquelle on construit avec `--target` |
| **index** (*image index*) | liste d'images portant un même nom, une par plateforme |
| ***multi-stage*** | construction en plusieurs étapes dans un même Dockerfile |

---

**Suivante :** [Leçon 6 — Configuration et secrets](06-configuracion-y-secretos.md)
