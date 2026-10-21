# Leçon 4 — Couches, cache et contexte

Il est 11 h 20 du matin et, à midi, il y a une démonstration avec l'équipe qui va utiliser le `revisor`. Il reste un détail : le tableau du rapport affiche une colonne décalée d'un espace. C'est une modification d'une ligne. Tu la fais, tu construis l'image et tu attends. Treize secondes. Tu testes, ce n'est pas encore ça, tu corriges à nouveau. Treize de plus. Et encore treize. Au cinquième tour, tu te rends compte que tu as passé plus de temps à regarder le terminal compiler qu'à réfléchir au problème, et que chaque construction compile **tout** le programme depuis zéro, alors que tu n'as touché qu'un seul fichier. Pendant ce temps, ta collègue, qui travaille sur sa propre copie du projet, demande pourquoi sa construction indique avoir « envoyé » 62 Mo alors que le code du `revisor` pèse quelques kilo-octets. Dans sa copie, quelqu'un a supprimé le `.dockerignore`, et le dossier contient une sauvegarde et l'historique de Git. Les deux questions ont la même réponse, et elle ne se trouve pas dans le code du `revisor` : elle se trouve dans l'ordre de quatre lignes du Dockerfile et dans un fichier qui s'appelle `.dockerignore`. À la fin de cette leçon, cette même modification d'une ligne se reconstruit en moins de deux secondes.

**Durée :** 2 × 45 min

**Ce que tu construis :** la même image que dans la Leçon 3, désormais en tant que `curso-docker-revisor:1.1.0`, avec un Dockerfile réordonné pour tirer parti du cache, un montage de cache pour la compilation de Go et un `.dockerignore` plus complet. Elle fait exactement la même chose que la `1.0.0` ; elle se reconstruit en quelques secondes et sa couche de compilation pèse 100 Mo de moins.

**Ce que tu apprends :** qu'une image est une pile de couches et comment les voir avec `docker history` ; comment le constructeur décide si une couche sort du cache ou doit être refaite ; pourquoi l'**ordre** des instructions détermine ce qui est reconstruit ; comment lire une construction avec `--progress=plain` ; ce qu'est un montage de cache (`RUN --mount=type=cache`) et pourquoi son contenu ne reste pas dans l'image ; et ce qui voyage dans le contexte de construction et ce qui ne voyage pas.

**D'où tu viens.** De la [Leçon 3](03-primer-dockerfile.md), tu apportes ton premier Dockerfile : une seule étape sur `golang:1.27.3-trixie`, un `COPY . .` qui embarque tout le projet, un `RUN go build`, `USER 10001:10001` et `CMD ["revisor"]` en forme *exec*. Tu apportes aussi son `.dockerignore` de cinq lignes et l'image `curso-docker-revisor:1.0.0`, de 1,45 Go. Là-bas, on a dit en passant que tout copier d'un coup rend la reconstruction lente ; ici, tu vas le mesurer et le corriger. De la [Leçon 0](00-que-es-un-contenedor.md), tu apportes l'idée qu'une image est faite de **couches** en lecture seule. Jusqu'ici, c'était une phrase ; dans cette leçon, tu vas les compter une à une.

**Ce que cette leçon ne fait pas.** Elle ne réduit pas vraiment l'image : 1,32 Go reste énorme, car l'image embarque encore le compilateur Go et tout un Debian. Séparer la compilation de l'image finale est le sujet de la [Leçon 5](05-multi-stage.md). Elle ne touche pas non plus au code du `revisor`, ni à sa configuration, ni à ses secrets. Et elle n'enseigne pas à « télécharger les dépendances dans une couche à part », une astuce très courante dans les tutoriels de Go, car le `revisor` n'a pas de dépendances externes : il n'utilise que la bibliothèque standard. Ce qu'il a, en revanche, et en quantité, c'est de la **compilation**, et c'est ce cache-là que l'on enseigne ici. La section 4.8 te dit comment reconnaître l'autre astuce quand tu la verras.

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4, la même base que Linux Mint 22, le système de référence du cours. Les scripts ont été exécutés **à l'intérieur** de cette machine virtuelle, avec Docker 29.2.1 (client et daemon) et Buildx v0.31.1. Le cours a été planifié avec Docker Engine 29.8.2, et la version la plus récente publiée ce jour-là était la 29.9.2, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)) ; rien de ce qu'enseigne cette leçon ne change entre ces versions. Trois remarques sur ces exécutions. Premièrement : la machine était occupée par d'autres constructions au même moment, si bien que les **durées** sont bruitées ; ce qui se maintient d'une exécution à l'autre, c'est la **différence** entre un Dockerfile et l'autre, pas les millisecondes exactes. Deuxièmement : sur cette même machine, on rédigeait d'autres leçons du cours, qui créent des images portant les mêmes noms (`curso-docker-revisor:1.0.0`, `:1.1.0`). Pour ne rien leur supprimer ni écraser un de leurs tags, les scripts de cette leçon ont été lancés avec un autre préfixe de noms, grâce à la variable `PREFIJO` qu'ils comportent, et le préfixe a été ramené à celui du cours **dans la commande elle-même**, au vu de tous : la première ligne de chaque sortie enregistrée indique exactement comment elle a été exécutée, par exemple `PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'`. Sur ton ordinateur, `./fig04_03.sh` tout court affiche la même chose sans ce `sed`. C'est la seule exception à « s'exécute tel quel », et elle n'existe qu'à cause de la machine partagée. Troisièmement : le Mac des exécutions n'a pas Go 1.27.3 installé ; c'est pourquoi l'erreur de Go de la Solution 3 a été mesurée à l'intérieur de l'image `golang:1.27.3-trixie`. Ce qui change **effectivement** sur ton Mint : les durées, les identifiants du cache et, si ton ordinateur est un Intel ou un AMD, la variante de l'image de Go qui est téléchargée (`amd64` au lieu d'`arm64`), même si le *digest* que tu verras sur la ligne du `FROM` est le même, car c'est celui de l'index des plateformes. Les programmes se trouvent dans [`programas/04-capas-cache-contexto/`](../programas/04-capas-cache-contexto), chacun avec sa sortie à côté, et `estado/` conserve le `Dockerfile`, le `.dockerignore` et le `Dockerfile.leccion3` (la copie de celui de la Leçon 3, uniquement pour comparer) tels qu'ils sont à la fin de la leçon.

## À la fin, tu seras capable de

- Lister avec `docker history` les couches d'une image et dire lesquelles ajoutent des fichiers et lesquelles seulement des informations.
- Prédire, avant de construire, quelles étapes d'un Dockerfile sortiront du cache après une modification, et le vérifier avec `--progress=plain`.
- Réordonner un Dockerfile pour qu'une modification du code ne répète pas les étapes qui n'en dépendent pas.
- Ajouter un montage de cache à un `RUN` de compilation et montrer que son contenu vit dans le constructeur et non dans l'image.
- Mesurer avec un fichier de 50 Mo ce qui voyage dans le contexte de construction, avec et sans `.dockerignore`.
- Supprimer uniquement ton cache de compilation, sans toucher à celui des autres projets de la même machine.

## Le pourquoi avant le comment

Construire une image, c'est répéter une recette. La première fois, chaque étape est réellement exécutée : on télécharge la base, on copie les fichiers, on compile. La deuxième fois, presque tout est identique à la première : la même base, le même `go.mod`, presque le même code. Il serait absurde de tout refaire. C'est pourquoi le constructeur conserve le résultat de chaque étape et, la fois suivante, si rien de ce qu'utilise cette étape n'a changé, il **réutilise** le résultat au lieu de la refaire. C'est ce qu'on appelle le **cache de construction**.

Le problème, c'est que le cache a des règles, et ce ne sont pas celles qu'on imagine. Ce n'est pas « réutilise ce qui n'a pas changé ». C'est « réutilise **jusqu'à** la première étape qui a changé, et à partir de là, refais tout ». Cette différence, c'est la scène du début. Dans le Dockerfile de la Leçon 3, le code entre avec un seul `COPY . .` et, à la ligne suivante, on compile. N'importe quelle modification, même un commentaire, change ce `COPY`, et comme le `RUN go build` vient après, la compilation complète est refaite. Avec le Dockerfile de cette leçon, la même modification se reconstruit ainsi (tu vas le mesurer à la section 4.5) :

```text
## 3. Cambio un comentario en internal/reporte/tabla.go
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
...
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
```

De treize secondes à moins de deux, avec le même code, la même modification et la même image résultante. Sur une machine moins occupée ou dans un projet plus grand, la différence augmente. Et la deuxième question de la scène, celle des 62 Mo, est l'autre face de la même médaille : le constructeur a aussi besoin de savoir **quels fichiers** il peut utiliser, et si tu les lui envoies tous, il les envoie tous.

La leçon comporte huit parties :

1. **Une image est une pile de couches** (4.1) : les voir avec `docker history`.
2. **Comment le cache décide** (4.2) : les règles, avec le Dockerfile de la Leçon 3 comme contre-exemple.
3. **L'ordre compte** (4.3) : le nouveau Dockerfile, ligne par ligne.
4. **Le cache qui n'est pas une couche** (4.4) : `RUN --mount=type=cache`.
5. **Mesurer** (4.5) : le chronomètre et `--progress=plain`.
6. **Ce qui voyage dans le contexte** (4.6), avec l'erreur de la leçon.
7. **Vérifier avant de construire** (4.7).
8. **Ce que tu verras dans d'autres projets** (4.8).

## Les concepts

### 4.1 Une image est une pile de couches

#### 4.1.1 Une couche par étape

La documentation de Docker définit une couche ainsi : « chaque couche d'une image contient un ensemble de modifications du système de fichiers : ajouts, suppressions ou modifications », et explique que c'est utile parce que cela « permet de réutiliser des couches entre images » ([Docker, « Understanding the image layers »](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/)). Et la page sur le cache de construction relie les couches à ta recette : « chaque instruction de ce Dockerfile se traduit par une couche de ton image finale » ([Docker, « Docker build cache »](https://docs.docker.com/build/cache/)).

Dans la Leçon 0, tu as vu la conséquence des couches pour les conteneurs : chaque conteneur ajoute sa propre couche, au-dessus, où il écrit. Ici, c'est l'autre moitié qui compte : comment s'empilent les couches du dessous quand tu **construis**. `FROM` n'ajoute pas de couche propre : il place en dessous toutes les couches de l'image de base. Ensuite, chaque `COPY` et chaque `RUN` laisse une couche avec les fichiers qu'il a ajoutés ou modifiés, et `WORKDIR` en laisse aussi une, petite, quand il doit créer le dossier. Les instructions qui se contentent de noter quelque chose, comme `USER`, `EXPOSE` et `CMD`, laissent une ligne dans l'historique, mais de zéro octet : elles ajoutent des informations à la configuration, pas des fichiers.

#### 4.1.2 Les voir avec `docker history`

`docker history` affiche « l'historique d'une image », une ligne par étape, de la plus récente à la plus ancienne ([`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/)). Avec `--format`, tu choisis les colonnes à afficher : `.Size` est la taille qu'a ajoutée cette étape et `.CreatedBy`, la commande qui l'a créée. Voici l'historique de l'image de la Leçon 3, tiré de `fig04_03.sh` (le script complet apparaît en 4.5 ; ici, on ne regarde que sa section 5) :

```text
$ docker history curso-docker-revisor:1.0.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
110MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
115kB	COPY . . # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
```

Cette sortie est stable sur une machine `arm64` ; en `amd64`, les tailles peuvent différer légèrement. Le `head -7` garde les sept premières lignes et le `cut -c1-70` coupe chaque ligne à 70 caractères pour qu'elle tienne ; le `…` vient de Docker, qui tronque aussi les commandes longues (avec `--no-trunc`, il ne le fait pas).

Lis-la de bas en haut, qui est l'ordre dans lequel elle a été construite :

- `WORKDIR /go` **n'est pas à toi**. C'est la dernière étape de l'image de Go. Si tu retires le `head -7`, une douzaine de lignes supplémentaires apparaissent en dessous, toutes de `golang:1.27.3-trixie` : lors de l'exécution de référence du cours, la plus grosse était une couche de 290 Mo avec l'installation de Go et, plus bas, plusieurs de 281, 208 et 156 Mo avec le Debian de base. Ton image **commence** là où se termine celle de Go.
- `WORKDIR /src`, 8,19 ko : ta première étape. Elle crée le dossier.
- `COPY . . # buildkit`, 115 ko : tout le projet. Le commentaire `# buildkit` indique que la couche a été créée par BuildKit, le constructeur que tu as découvert dans la Leçon 3.
- `RUN /bin/sh -c go build ...`, **110 Mo**. Remarque : le `RUN` s'exécute avec `/bin/sh -c`, car dans le Dockerfile il est en forme *shell*. Pour un `RUN`, c'est très bien ; la règle de la forme *exec* concernait `CMD` et `ENTRYPOINT`.
- `USER`, `EXPOSE`, `CMD` : zéro octet. Seulement des informations.

Voici maintenant la question qui ouvre cette leçon : le `revisor` compilé pèse environ 10 Mo. Que sont les 100 Mo restants de cette couche ? La réponse se trouve à la section 4.4, et c'est la raison pour laquelle la nouvelle image pèse moins.

> [!NOTE]
> 🔧 **Observation de génie logiciel 4.1**
> Une couche ne se supprime jamais depuis le dessus. Si un `RUN` crée un fichier de 100 Mo et que le `RUN` suivant le supprime, l'image pèse toujours ces 100 Mo : la seconde couche se contente de noter « ce fichier n'est plus visible ». Ce qui entre dans une couche reste dans l'image. C'est pourquoi ce qui ne doit pas être dans l'image s'évite **avant** qu'il n'entre, on ne le nettoie pas après.

### 4.2 Comment le cache décide

#### 4.2.1 Les trois règles

La documentation du cache les explique sur deux pages, et elles tiennent en trois règles :

1. **Pour `COPY` et `ADD`, ce sont les fichiers qui comptent, sauf leur date.** La documentation indique que le constructeur « calcule une somme de contrôle du cache à partir des métadonnées des fichiers » et que le cache est invalidé « si les métadonnées de l'un des fichiers concernés ont changé ». En pratique, ce que tu vas mesurer dans l'Exercice 1 : changer le contenu d'un fichier l'invalide, changer seulement sa date, non. La documentation le formule ainsi : la date de modification ne compte **pas** ; « si seul le `mtime` des fichiers copiés a changé, le cache n'est pas invalidé » ([Docker, « Build cache invalidation »](https://docs.docker.com/build/cache/invalidation/)).
2. **Pour `RUN`, seul compte le texte de la commande.** En dehors d'`ADD` et de `COPY`, la vérification du cache ne regarde pas les fichiers ; « seule la chaîne de la commande est utilisée pour trouver une correspondance » (même page). Un `RUN go build` déjà exécuté avec la même couche en dessous sort du cache même si, à l'extérieur, une nouvelle version de quelque chose est sortie.
3. **Dès que quelque chose est invalidé, tout ce qui suit est refait.** « Si une couche change, toutes les couches qui viennent après sont aussi affectées. Même si elles ne devaient rien construire de différent, elles doivent tout de même être réexécutées » ([Docker, « Docker build cache »](https://docs.docker.com/build/cache/)). La page sur l'invalidation dit la même chose : une fois le cache invalidé, les commandes suivantes génèrent de nouvelles images et le cache n'est pas utilisé.

La troisième règle est celle qui compte pour l'ordre. Le cache n'est pas une carte de « ce qui a changé » ; c'est une chaîne. Chaque maillon dépend de celui du dessus. Si l'un se brise, tous ceux du dessous se brisent.

#### 4.2.2 Le Dockerfile de la Leçon 3, à la lumière des règles

Relis le Dockerfile de la Leçon 3 avec les trois règles en main :

```dockerfile
FROM golang:1.27.3-trixie
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

(C'est un extrait : le fichier complet est `estado/Dockerfile.leccion3`, identique à celui de la Leçon 3.) Le `COPY . .` dépend de **tous** les fichiers du contexte. Tu modifies un commentaire dans `internal/reporte/tabla.go` : règle 1, le contenu a changé, le `COPY` est invalidé. Règle 3 : le `RUN go build` vient après, il est donc refait. Et comme le `RUN` démarre dans une nouvelle couche, sans rien de la compilation précédente, Go compile **tout** depuis zéro : ton programme, chaque paquet d'`internal/` et chaque paquet de la bibliothèque standard qu'il utilise.

Voici ce qu'a vu `fig04_03.sh` (section 3), dans le format qu'explique 4.5 :

```text
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 10.1s RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

`CACHED` veut dire « sorti du cache » ; `DONE` avec une durée, « réellement exécuté ». Le `WORKDIR` est sorti du cache ; le `COPY` et la compilation ont été refaits. L'étape 1, le `FROM`, indique toujours `DONE 0.0s` : le constructeur confirme qu'il dispose de l'image de base, déjà téléchargée, et ne fait rien de plus.

### 4.3 L'ordre compte

#### 4.3.1 Le Dockerfile de la leçon

Le guide d'optimisation de Docker le dit en une ligne : « les étapes qui changent souvent devraient se trouver vers la fin du Dockerfile » ([Docker, « Optimize cache usage »](https://docs.docker.com/build/cache/optimize/)). Pour le `revisor`, cela donne ce Dockerfile. Il remplace celui de la Leçon 3, à la racine du projet, et s'appelle `Dockerfile` :

```dockerfile
# syntax=docker/dockerfile:1
# fig04_01.Dockerfile — Lección 4: la misma imagen que la 3, ordenada para la caché.
FROM golang:1.27.3-trixie

WORKDIR /src

# Primero lo que casi nunca cambia (la descripción del módulo)...
COPY go.mod ./
# ...después el código, que cambia en cada edición.
COPY cmd/ cmd/
COPY internal/ internal/

# La caché de compilación de Go vive en un montaje de caché: sobrevive entre
# construcciones, acelera la siguiente y NO queda dentro de la imagen.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -o /usr/local/bin/revisor ./cmd/revisor

USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

Par rapport à celui de la Leçon 3, deux choses changent : le `COPY . .` a été divisé en trois, et le `RUN` a gagné une option `--mount`. Le reste est identique, ligne par ligne, et l'image résultante fait la même chose.

#### 4.3.2 Les trois `COPY`

**`COPY go.mod ./`.** Le fichier `go.mod` décrit le module : son nom et la version de Go qu'il demande. Dans le `revisor`, il compte deux lignes et ne change presque jamais. Le copier en premier, seul, crée une couche qui survit à n'importe quelle modification du code. Dans un projet avec des dépendances, c'est ici qu'iraient aussi `go.sum` et l'étape de téléchargement (4.8) ; dans le `revisor`, le bénéfice est faible, mais l'habitude est la même : ce qui change le moins, le plus haut.

**`COPY cmd/ cmd/` et `COPY internal/ internal/`.** Le code, en deux couches. `cmd/revisor/` est le serveur HTTP ; `internal/`, ce sont les paquets qui viennent du cours de Go (configuration, requête, rapport). Les séparer ne change pas grand-chose à la vitesse, mais cela rend plus clair dans `docker history` quelle partie a changé, et l'ordre suit la règle : `internal/`, qui change davantage pendant que tu développes le rapport, reste en dessous.

Remarque un effet de bord qui vaut de l'or et que l'on mesure en 4.6 : avec des `COPY` sélectifs, **seuls ces trois chemins** peuvent entrer dans l'image. Un `.env` oublié dans le dossier n'entre pas même si le `.dockerignore` l'oublie, car aucun `COPY` ne le demande. Le `.dockerignore` reste obligatoire, mais il n'est plus la seule barrière.

#### 4.3.3 La même modification, avec le nouvel ordre

Voici maintenant le même commentaire dans `tabla.go`, avec ce Dockerfile. C'est la section 3 de `fig04_03.sh`, seconde moitié :

```text
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.8s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

Les règles, encore une fois. `go.mod` n'a pas changé : cache. `cmd/` n'a pas changé : cache. `internal/` a changé : il est refait et, par la règle 3, le `RUN` aussi. Jusqu'ici, l'ordre t'a fait gagner peu, car la compilation est toujours refaite. Mais regarde la durée du `RUN` : **0,8 seconde**, contre 10,1 avec l'ancien Dockerfile. La compilation a été refaite et, pourtant, elle n'a presque rien compilé. Ce n'est pas l'ordre qui a fait cela. C'est le `--mount`, et c'est la section qui suit.

Avant de continuer, la preuve que la nouvelle image fait la même chose que l'ancienne. La section 7 de `fig04_03.sh` exécute la `1.1.0` comme dans la Leçon 3, avec le `revisor` qui se surveille lui-même, et interroge son endpoint de contrôle de santé depuis l'intérieur du conteneur (l'image de Go embarque `curl` ; ainsi, il n'est pas nécessaire de publier un port) :

```text
## 7. La imagen nueva hace lo mismo que la vieja
$ docker exec curso-docker-revisor curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
```

Comme la `1.0.0`. Le `"desarrollo"` est toujours là, car la version n'est pas encore gravée dans le programme ; cela arrive dans la Leçon 6.

### 4.4 Le cache qui n'est pas une couche : `RUN --mount=type=cache`

#### 4.4.1 Go a déjà son propre cache

Le compilateur Go ne compile pas deux fois la même chose s'il peut l'éviter. Sa documentation le dit ainsi : « la commande `go` met en cache les résultats de compilation pour les réutiliser lors de compilations futures », et par défaut elle les conserve dans un dossier nommé `go-build` à l'intérieur du dossier de cache de l'utilisateur ([documentation de `go`, « Build and test caching »](https://pkg.go.dev/cmd/go#hdr-Build_and_test_caching)). Sous Linux, pour l'utilisateur `root`, ce dossier est `/root/.cache/go-build`. Si tu modifies un fichier d'`internal/reporte`, Go ne recompile que ce paquet et ceux qui en dépendent, et prend le reste dans le cache.

Sur ton ordinateur, ce cache fonctionne tout seul. Dans une construction Docker, non : chaque `RUN` démarre sur la couche que lui a laissée l'étape précédente, et dans le Dockerfile de la Leçon 3 cette couche ne contient pas de cache de Go, car le `COPY` vient d'être refait. Pire encore : ce que Go écrit dans `/root/.cache/go-build` pendant le `RUN` **reste dans la couche du `RUN`**. Ce sont les 100 Mo en trop de 4.1.2.

#### 4.4.2 Le montage de cache

`RUN --mount` permet de « créer des montages de système de fichiers auxquels la construction peut accéder », et le type `cache` permet au « conteneur de construction de mettre en cache des dossiers de compilateurs et de gestionnaires de paquets » ([référence du Dockerfile, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache)). Le guide d'optimisation complète le tableau : un montage de cache est « un emplacement de cache persistant » pour les constructions ; le cache s'accumule d'une construction à l'autre et se partage entre plusieurs d'entre elles ([Docker, « Optimize cache usage »](https://docs.docker.com/build/cache/optimize/)).

Autrement dit : pendant ce `RUN`, le dossier `/root/.cache/go-build` ne fait pas partie de la couche. C'est un dossier que le **constructeur** conserve à part et remonte à chaque construction. Go y trouve ce qu'il a compilé la fois précédente, et ce qu'il y écrit ne finit pas dans l'image.

Les options qu'utilise le `revisor` :

- **`type=cache`** : le type de montage.
- **`target=/root/.cache/go-build`** : l'endroit où apparaît le dossier à l'intérieur du `RUN`. C'est le dossier par défaut du cache de Go, si bien que Go l'utilise sans rien configurer. Le guide de Docker utilise ce même chemin dans son exemple pour Go.
- **`id=curso-docker-go-build`** : le nom du cache. La référence indique qu'il est facultatif et qu'il sert à « identifier des caches distincts » ; si tu ne le fournis pas, il vaut la même chose que `target`. Plus bas, tu verras pourquoi il vaut mieux le fournir.

Il existe d'autres options (`sharing`, `mode`, `uid`…), et la référence les liste ; le `revisor` n'en a pas besoin. Une remarque : le montage est utilisé à la construction, quand l'utilisateur est encore `root` ; le `USER 10001:10001` vient après et ne l'affecte pas.

#### 4.4.3 Le cache vit dans le constructeur, pas dans l'image

Les affirmations se vérifient. La section 6 de `fig04_03.sh` cherche le cache aux deux endroits où il pourrait se trouver :

```text
## 6. La caché de compilación vive en el constructor, no en la imagen
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID                           RECLAIMABLE   SIZE      LAST ACCESSED
xq0we4j0a5g4a98ftg4xaezzc*   true          99.59MB   1 second ago
$ docker buildx du --verbose --filter 'description~=curso-docker-fig04-go-build' | grep -E '^(Description|Type):'
Description:  cached mount /root/.cache/go-build from exec /bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor with id "/curso-docker-fig04-go-build"
Type:         exec.cachemount
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.1.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
du: cannot access '/root/.cache/go-build': No such file or directory
[código de salida: 1]
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.0.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
95M	/root/.cache/go-build
```

L'identifiant de la première ligne et le « 1 second ago » changent ; les tailles peuvent varier de quelques mégaoctets. `docker buildx du` affiche ce qu'occupe le constructeur sur le disque (*disk usage*), et `--filter description~=...` garde les entrées dont la description contient ce texte. Avec `--verbose`, il affiche chaque entrée complète ; le `grep` garde sa description et son type, dont tu auras besoin en 4.4.5. Les deux `docker run` entrent dans chaque image en tant que `root` (`--user 0`, uniquement pour pouvoir lire `/root`) et mesurent le dossier.

Trois lignes, trois faits :

1. **Dans le constructeur**, il y a un cache de 99,59 Mo, de type `exec.cachemount` (montage de cache), avec l'`id` du script. C'est là que se trouve ce qu'a compilé Go.
2. **Dans l'image `1.1.0`**, le dossier n'existe même pas. Le cache n'a pas voyagé.
3. **Dans l'image `1.0.0`**, celle de la Leçon 3, le dossier pèse 95 Mo. C'est là qu'étaient les 100 Mo en trop.

Et pourquoi le script utilise-t-il `curso-docker-fig04-go-build` et non le `curso-docker-go-build` du Dockerfile ? Parce que le script change l'`id` en assemblant sa copie du projet, pour avoir un cache **à lui seul**, partir réellement à froid et pouvoir le supprimer à la fin sans toucher à celui de ton projet. C'est la même idée que tu verras en 4.4.5.

Et la section 5 du même script le confirme depuis les images :

```text
$ docker history curso-docker-revisor:1.1.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
10MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
77.8kB	COPY internal/ internal/ # buildkit
41kB	COPY cmd/ cmd/ # buildkit
12.3kB	COPY go.mod ./ # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
$ docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^curso-docker-revisor:1\.[01]\.0 '
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.0.0 1.45GB
$ for i in curso-docker-revisor:1.0.0 curso-docker-revisor:1.1.0; do docker image inspect --format "$i {{.Size}}" $i; done
curso-docker-revisor:1.0.0 337298513
curso-docker-revisor:1.1.0 314341606
```

Le `RUN` est passé de 110 Mo à **10 Mo** : désormais, la couche ne contient que l'exécutable. Les trois couches de code totalisent la même chose que le `COPY . .` d'avant, réparti. Voilà le chiffre solide : **la couche a perdu 100 Mo**, sans rien retirer dont le `revisor` ait besoin.

Les deux autres lignes comptent la taille de l'image de deux façons, et il vaut mieux ne pas les confondre. `docker image inspect` donne la taille du **contenu**, compressé tel qu'il est stocké et transféré : 337,3 Mo contre 314,3 Mo, soit 23 Mo de moins. `docker image ls` donne 1,45 Go contre 1,32 Go, environ 130 Mo de moins. La différence entre les deux façons vient du magasin d'images de Docker Engine 29 qui, selon sa documentation, stocke les images « au format compressé et non compressé » ([Docker, « containerd image store »](https://docs.docker.com/engine/storage/containerd/)). Les 130 Mo concordent avec cette explication : environ 100 Mo de la couche non compressée plus environ 23 Mo compressés, avec l'arrondi des gigaoctets. Cette somme est un calcul de notre part, pas une règle de la documentation ; ce qui est sûr, c'est la couche de `docker history`. C'est un gain que tu ne cherchais pas, et il est arrivé en faisant bien ce que tu cherchais.

> [!NOTE]
> 🔧 **Observation de génie logiciel 4.2**
> Il y a deux caches, et il vaut mieux ne pas les confondre. Le **cache de couches** décide si une étape est refaite ou non : c'est tout ou rien. Le **montage de cache** fait que, quand une étape est refaite, elle l'est à peu de frais. L'ordre du Dockerfile agit sur le premier ; le `--mount`, sur le second. Avec les deux ensemble, le `RUN go build` n'est presque jamais sauté, mais il ne coûte presque jamais rien.

#### 4.4.4 Les deux caches sont indépendants

Un détail qui va t'éviter une confusion : ce sont deux choses distinctes, et elles se gèrent séparément. `--no-cache` demande au constructeur de ne pas utiliser le cache de **couches** ; pour qu'une mesure à froid soit honnête, la section 1 de `fig04_03.sh` supprime en plus son **montage** avant de commencer, avec son propre `id` (4.4.5). Et inversement : une étape qui sort du cache de couches n'exécute pas son `RUN`, elle ne lit donc ni ne remplit le montage. Si tu construis une fois avec tout dans le cache de couches, le montage reste aussi vide ou aussi plein qu'il l'était.

#### 4.4.5 Un `id` propre, et pourquoi jamais une suppression large

Le montage de cache occupe de l'espace disque, et un jour tu voudras le supprimer. La commande est `docker buildx prune`, qui supprime du cache du constructeur, et son option `--filter` permet de choisir quoi supprimer : par ancienneté (`until`), par type (`type`, et l'un des types est `exec.cachemount`, justement celui des montages) ou par un texte de la description (`description`) ([`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/)). Tu as déjà vu en 4.4.3 à quoi ressemble la description d'un montage de cache : `cached mount /root/.cache/go-build from exec … with id "/curso-docker-fig04-go-build"`. L'`id` apparaît à la fin, après une barre oblique et entre guillemets. C'est pour cela que l'`id` compte : c'est le repère qui te permet de trouver **ton** cache et uniquement le tien.

Voici le danger. Un filtre large, comme `description~=go-build`, attrape le cache de compilation de **n'importe quel** projet Go de la machine qui utilise le chemin par défaut. Ce n'est pas hypothétique : sur la machine de ces exécutions, pendant la rédaction de cette leçon, `docker buildx du --filter 'description~=go-build'` a trouvé deux entrées, celle de cette leçon et celle d'un autre projet qui construisait au même moment. Un `prune` avec ce filtre aurait supprimé le cache de l'autre, et sa construction suivante aurait été lente sans que personne ne sache pourquoi. Sur une machine partagée (un serveur de construction, l'ordinateur d'une équipe, ou le tien avec plusieurs projets), une suppression large revient à supprimer ce qui appartient aux autres.

La règle de ce cours a deux parties :

1. **À chaque projet son `id`.** Le `revisor` utilise `curso-docker-go-build`. Si demain tu empaquettes un autre projet Go, tu lui en donnes un autre. Sans `id`, tous les projets qui utilisent `target=/root/.cache/go-build` partagent le même cache, car l'`id` par défaut est le chemin.
2. **Supprimer avec l'`id` complet et le type.** C'est ainsi que le font les scripts de cette leçon en sortant :

```bash
docker buildx prune -f --filter type=exec.cachemount \
  --filter "description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]"
```

Le `type=exec.cachemount` limite la suppression aux montages de cache. Le `~=` compare avec une expression régulière, et le `[^a-z0-9-]` de chaque côté (« n'importe quel caractère qui n'est ni une lettre minuscule, ni un chiffre, ni un tiret ») exige que l'`id` apparaisse **en entier** : dans la description, ce qui entoure l'`id`, ce sont la barre oblique avant et le guillemet après, et les deux satisfont la condition. Ainsi, un `id` plus long qui le contient, comme `curso-docker-fig04-go-build-viejo`, n'est pas supprimé par accident. Pourquoi ne pas écrire directement la barre oblique et les guillemets dans le filtre ? Parce qu'avec la version de Buildx de ces exécutions (v0.31.1), un filtre contenant des espaces, des guillemets ou `/` n'a rien trouvé : cela a été mesuré avec `docker buildx du` avant de l'utiliser. C'est une bonne habitude : **teste un filtre avec `du`, qui ne fait que regarder, avant de l'utiliser avec `prune`, qui supprime.**

Une suppression qui ne signale pas qu'elle n'a rien supprimé ne prouve rien ; c'est pourquoi la section 8 de `fig04_03.sh` supprime au vu de tous, puis cherche à nouveau :

```text
## 8. Borro SOLO mi caché de compilación y compruebo que ya no está
$ docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]' | tail -1
Total:	99.59MB
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID        RECLAIMABLE   SIZE      LAST ACCESSED
```

Le `prune` indique ce qu'il a libéré (`Total: 99.59MB`, le même cache que dans la section 6), et le `du` suivant ne trouve plus rien : il ne reste que l'en-tête du tableau. Pour ton projet, la même commande avec `curso-docker-go-build` supprime le cache du `revisor` et rien d'autre ; la construction suivante sera lente une fois et le remplira à nouveau.

### 4.5 Mesurer : le chronomètre et `--progress=plain`

#### 4.5.1 Voir ce que fait le constructeur

Quand tu construis dans un terminal, BuildKit dessine un affichage qui se redessine et se colore. C'est bien pour regarder, mais on ne peut ni l'enregistrer ni y chercher. L'option `--progress` détermine le format. Selon la référence de `docker buildx build`, la valeur par défaut est `auto`, qui utilise le mode `tty` (l'interactif, « avec couleur et redessin ») si la sortie est un terminal, et `plain` sinon ; `plain` « affiche la progression de la construction en texte brut » ([`docker buildx build`, `--progress`](https://docs.docker.com/reference/cli/docker/buildx/build/#progress)). Sur un serveur de construction, où il n'y a pas de terminal, tu vois toujours `plain` ; il vaut donc mieux savoir le lire.

Le texte brut a cette forme : chaque étape est un numéro précédé de `#`. Apparaît d'abord la ligne qui la nomme, comme `#10 [5/6] COPY internal/ internal/`, puis les lignes de ce qu'elle a fait, toutes avec le même numéro. Une étape se termine normalement par l'une de deux lignes : `#10 CACHED`, si elle est sortie du cache, ou `#10 DONE 0.5s`, si elle a été exécutée, avec sa durée. Si elle échoue, elle se termine par `#10 ERROR: …`, comme tu le verras en 4.6.2. Les étapes `[internal]` sont celles que le constructeur fait de lui-même : lire le Dockerfile, le `.dockerignore`, le contexte.

#### 4.5.2 Le script de la mesure

`fig04_03.sh` construit les deux Dockerfile dans quatre situations, chronomètre chaque construction et résume le journal de `--progress=plain` dans un tableau d'étapes. C'est le script le plus long de la leçon, et ses sections 5 à 8 sont celles que tu as déjà vues en 4.1.2, 4.3.3, 4.4.3 et 4.4.5 :

```bash
#!/usr/bin/env bash
# fig04_03.sh — Capas y caché: el Dockerfile de la Lección 3 contra el de la
# Lección 4. Construye los dos en frío, otra vez sin cambios y después de
# cambiar un archivo; cronometra cada construcción, muestra qué pasos salieron
# de la caché (--progress=plain) y compara las capas con docker history.
# Borra al salir sus imágenes y su caché de compilación.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L3="${PREFIJO}revisor:1.0.0"
L4="${PREFIJO}revisor:1.1.0"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

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
# construir ETIQUETA DOCKERFILE [opciones...]: construye con --progress=plain,
# guarda el registro en ../construccion.log e imprime cuánto tardó
construir() {
  local etiqueta="$1" archivo="$2" inicio fin; shift 2
  inicio=$(t)
  docker build --progress=plain "$@" -t "$etiqueta" -f "$archivo" . > ../construccion.log 2>&1
  fin=$(t)
  echo "$etiqueta ($archivo${*:+ $*}): $(( fin - inicio )) ms"
}
# pasos: de ../construccion.log, cada paso [n/m] con su estado final
pasos() {
  awk '
    /^#[0-9]+ \[([a-z0-9-]+ )?[0-9]+\/[0-9]+\]/ {
      if (!($1 in paso)) {
        l=$0; sub(/^#[0-9]+ \[([a-z0-9-]+ )?/, "", l); split(l, p, "/"); i=p[1]+0
        sub(/^[0-9]+\/[0-9]+\] /, "", l); sub(/--mount=[^ ]+ +/, "", l); paso[$1]=i; nombre[i]=l; if (i > k) k=i
      }
    }
    /^#[0-9]+ (CACHED|DONE)/ { if ($1 in paso) estado[paso[$1]]=$2 ($2=="DONE" ? " " $3 : "") }
    END { for (i=1; i<=k; i++) printf "  paso %d  %-10s %s\n", i, estado[i], substr(nombre[i], 1, 60) }
  ' ../construccion.log
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rm -f "${PREFIJO}revisor" >/dev/null 2>&1; docker rmi -f "$L3" "$L4" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "1. En frío: sin caché de capas y con la caché de compilación vacía"
borrar_cache
construir "$L3" Dockerfile.leccion3 --no-cache
pasos
construir "$L4" Dockerfile --no-cache
pasos

titulo "2. Otra vez, sin cambiar nada"
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "3. Cambio un comentario en internal/reporte/tabla.go"
echo "// cambio de prueba $(date +%s)" >> internal/reporte/tabla.go
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "4. Cambio un archivo que el .dockerignore deja fuera"
echo "notas de trabajo $(date +%s)" > NOTAS.md
construir "$L4" Dockerfile
pasos

titulo "5. Las capas de cada imagen: solo los pasos de la receta"
muestra "docker history $L3 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70"
muestra "docker history $L4 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70"
muestra "docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^${PREFIJO}revisor:1\.[01]\.0 '"
muestra "for i in $L3 $L4; do docker image inspect --format \"\$i {{.Size}}\" \$i; done"

titulo "6. La caché de compilación vive en el constructor, no en la imagen"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
muestra "docker buildx du --verbose --filter 'description~=${CACHE_ID}' | grep -E '^(Description|Type):'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L4 sh -c 'du -sh /root/.cache/go-build 2>&1'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L3 sh -c 'du -sh /root/.cache/go-build 2>&1'"

titulo "7. La imagen nueva hace lo mismo que la vieja"
docker run -d --name "${PREFIJO}revisor" -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$L4" >/dev/null
for _ in $(seq 40); do docker exec "${PREFIJO}revisor" curl -fsS -o /dev/null http://127.0.0.1:8080/salud 2>/dev/null && break; sleep 0.5; done
muestra "docker exec ${PREFIJO}revisor curl -s http://127.0.0.1:8080/salud"
docker rm -f "${PREFIJO}revisor" >/dev/null

titulo "8. Borro SOLO mi caché de compilación y compruebo que ya no está"
muestra "docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]' | tail -1"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
```

Les fonctions d'aide du début sont celles de la Leçon 3 (`titulo`, `muestra`, `t`), plus trois nouvelles. `construir` construit avec `--progress=plain`, enregistre le journal dans un fichier et chronomètre. `pasos` est un petit programme `awk` qui lit ce journal et, pour chaque étape numérotée `[n/m]`, affiche son numéro, son nom et son état final ; il retire du nom l'option `--mount=...` pour que la ligne tienne, et numérote lui-même les étapes car, quand une autre construction partage des étapes identiques sur la même machine, BuildKit peut afficher le numéro d'étape de l'autre. `borrar_cache` est celle de 4.4.5.

Trois détails de plus. La modification contient l'heure (`$(date +%s)`) pour être différente à chaque exécution : si tu écrivais toujours le même texte, la deuxième fois que tu exécuterais le script, ce contenu serait déjà dans le cache de couches, et la « modification » sortirait `CACHED`. (C'est arrivé à l'auteur de cette leçon dans une première version du script, et c'est une bonne illustration du fait que le cache se souvient des contenus, pas des moments.) La section 7 utilise `docker exec ... curl` pour parler au `revisor` depuis l'intérieur de son conteneur, sans publier de ports. Et le script, comme ceux de la Leçon 3, supprime en sortant les images qu'il a créées ; si tu veux conserver la `1.1.0`, construis-la ensuite dans ton projet avec `docker build -t curso-docker-revisor:1.1.0 .`.

#### 4.5.3 Les chiffres

Les sections 1 et 2 de la sortie :

```text
$ PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## 1. En frío: sin caché de capas y con la caché de compilación vacía
curso-docker-revisor:1.0.0 (Dockerfile.leccion3 --no-cache): 9909 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 7.1s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile --no-cache): 12207 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 10.5s RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## 2. Otra vez, sin cambiar nada
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 1176 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY . .
  paso 4  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile): 628 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

Les durées changent à chaque exécution ; la séquence de `CACHED` et de `DONE` est stable. (Le `WORKDIR /src` sort `CACHED` même avec `--no-cache`. C'est un détail de la façon dont BuildKit traite cette étape, qui n'ajoute pas de fichiers du contexte et n'exécute rien, et cela ne change pas ce qui compte : les `COPY` et le `RUN` ont bien été refaits.)

**À froid**, les deux compilent tout depuis zéro. Les durées de cette exécution (9,9 et 12,2 s) dépendent surtout du bruit de la machine : lors d'exécutions précédentes du même script, avec les mêmes constructions et la machine plus ou moins occupée, on a obtenu 12,5 contre 7,1 s, 18,6 contre 10,5 s et 20,2 contre 23,0 s, l'un l'emportant parfois, l'autre parfois. Ce qui est stable, c'est l'ordre de grandeur : **dix à vingt secondes**, le coût de tout compiler. Aucun ordre ne supprime ce coût : la première construction se paie toujours.

**Sans modification**, les deux sortent entièrement du cache en moins d'une seconde. Pas de différence ici non plus : le cache fonctionne aussi bien avec les deux Dockerfile quand rien n'a changé.

La différence apparaît dans la section 3, **avec une modification**, celle que tu as vue en 4.2.2 et 4.3.3 : 13,0 s contre 1,8 s, et le `RUN` en 10,1 s contre 0,8 s. Et c'est le cas qui compte, car c'est celui de tous les jours : tu modifies quelque chose et tu reconstruis.

La section 4 se termine par un cas qui fait le lien avec la suite :

```text
## 4. Cambio un archivo que el .dockerignore deja fuera
curso-docker-revisor:1.1.0 (Dockerfile): 790 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

On a ajouté un `NOTAS.md` au dossier et tout est sorti du cache. Le fichier n'est même pas arrivé au constructeur : le `.dockerignore` l'a laissé de côté (4.6). Ce qui ne voyage pas ne peut rien invalider.

> [!NOTE]
> 🔧 **Observation de génie logiciel 4.3**
> Une durée de construction seule, sans le tableau des étapes, ne te dit rien d'utile : tu ne sais pas si c'était lent parce que cela a compilé, parce que cela a téléchargé ou parce que la machine était occupée. Quand une construction prend plus de temps que prévu, la première question n'est pas « combien de temps a-t-elle pris ? », mais « quelle étape a été refaite, et pourquoi ? ». `--progress=plain` te donne cette réponse étape par étape.

### 4.6 Ce qui voyage dans le contexte

#### 4.6.1 BuildKit ne demande que ce dont il a besoin

Dans la Leçon 3, tu as vu que le contexte est le dossier que tu donnes à `docker build` et que le `.dockerignore` indique ce qui ne voyage pas. Il manque une pièce : **BuildKit n'envoie pas tout le contexte**. Parmi les améliorations que sa documentation liste par rapport à l'ancien constructeur, il y en a deux que tu vas voir tout de suite : « transférer de façon incrémentale uniquement les fichiers modifiés de ton contexte entre les constructions » et « détecter et ignorer le transfert des fichiers inutilisés de ton contexte » ([Docker, « BuildKit »](https://docs.docker.com/build/buildkit/)).

`fig04_04.sh` le mesure. Il place dans le dossier du projet une sauvegarde de 50 Mo et un faux dossier `.git` de 10 Mo, et construit trois fois :

```bash
#!/usr/bin/env bash
# fig04_04.sh — Qué viaja en el contexto. Siembra en la carpeta un respaldo de
# 50 MB y una carpeta .git falsa de 10 MB, y construye tres veces:
#   1) Dockerfile de esta lección (COPY selectivos), con .dockerignore;
#   2) Dockerfile de la Lección 3 (COPY . .), con .dockerignore;
#   3) Dockerfile de la Lección 3, SIN .dockerignore: falla a propósito.
# Borra al salir lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L4="${PREFIJO}revisor:1.1.0"
CON="${PREFIJO}revisor:con-ignore"
SIN="${PREFIJO}revisor:sin-ignore"

cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rmi -f "$L4" "$CON" "$SIN" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB"
head -c 52428800 /dev/urandom > respaldo.tar
mkdir -p .git && head -c 10485760 /dev/urandom > .git/objeto-falso
muestra "for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size \$f; done"

titulo "1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore"
muestra "docker build --progress=plain -t $L4 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore"
muestra "docker build --progress=plain -t $CON -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "3. Dockerfile de la Lección 3, SIN .dockerignore"
mv .dockerignore dockerignore.apartado
muestra "docker build --progress=plain -t $SIN -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"
grep -E -A4 '^#[0-9]+ ERROR|error obtaining' ../construccion.log | head -8
mv dockerignore.apartado .dockerignore
```

`head -c 52428800 /dev/urandom` écrit 50 Mo d'octets aléatoires : un fichier qui pèse autant qu'une vraie sauvegarde et qui ne peut pas être compressé. `du -sh --apparent-size` mesure la taille de chaque élément. De chaque construction, le script enregistre le journal et cherche la ligne `transferring context`, qui indique combien le client a envoyé au constructeur. Il utilise `set -uo pipefail`, sans `-e`, car la troisième construction échoue volontairement et le script doit continuer. Les trois constructions utilisent trois tags distincts (`1.1.0`, `con-ignore` et `sin-ignore`) pour que l'on puisse lire dans la sortie à quoi correspond chacune.

```text
$ PREFIJO=curso-docker-l04- ./fig04_04.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB
$ for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size $f; done
50M	respaldo.tar
10M	.git
15K	cmd
27K	internal
41	go.mod
61M	.

## 1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:1.1.0 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 42.80kB done

## 2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:con-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 1.00kB done
```

Les numéros d'étape (`#7`) et les durées peuvent changer ; les tailles transférées sont stables si tu exécutes le script tel quel.

Le dossier pèse **61 Mo**, et le code, environ 42 ko. Lors de la première construction, **42,80 ko** ont voyagé : le code et rien d'autre. Lors de la deuxième, **1,00 ko** a voyagé, alors que le Dockerfile de la Leçon 3 demande tout avec `COPY . .`. Les deux phrases de la documentation expliquent les deux chiffres :

- **« Ignorer ce qui n'est pas utilisé »** : lors de la première, la sauvegarde et le `.git` n'ont pas voyagé, pour deux raisons à la fois. Le `.dockerignore` les exclut et, en plus, les `COPY` ne demandent que `go.mod`, `cmd/` et `internal/`.
- **« Uniquement ce qui a changé »** : lors de la deuxième, le code était déjà du côté du constructeur depuis la première, et il n'avait pas changé. Seules les différences ont été envoyées. C'est pourquoi le chiffre de la ligne `transferring context` dépend de ce que tu as construit avant dans ce même dossier : la première fois, il envoie le code ; les suivantes, presque rien.

#### 4.6.2 Sans `.dockerignore` : l'erreur de la leçon

La troisième construction est celle du Dockerfile de la Leçon 3, avec `COPY . .`, **sans** `.dockerignore` :

```text
## 3. Dockerfile de la Lección 3, SIN .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:sin-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 1
#6 transferring context: 62.93MB 0.1s done
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
------
 > [4/4] RUN go build -o /usr/local/bin/revisor ./cmd/revisor:
0.344 error obtaining VCS status: exit status 128
0.344 	Use -buildvcs=false to disable VCS stamping.
------
```

Les numéros d'étape et les durées (`0.344`, `0.1s`) changent ; le reste est stable.

Deux choses se sont produites. La première, celle que tu attendais : **62,93 Mo** ont voyagé, la sauvegarde, le `.git` et le code. Ce sont les 62 Mo de la scène : ceux d'un dossier sans `.dockerignore`, avec une sauvegarde et l'historique de Git. Sur ton ordinateur, c'est une seconde ; sur un serveur de construction qui envoie le contexte par le réseau, à chaque construction, cela se remarque. Et ce qui voyage avec `COPY . .` finit à l'intérieur de l'image, comme le `.env` de la Leçon 3.

La seconde est la surprise : **la construction a échoué**, et pas à cause de Docker. Le `.git` est arrivé dans `/src` à l'intérieur de l'image, et Go, en compilant, l'a vu. Par défaut, Go tente de graver dans l'exécutable les informations du contrôle de version (quel *commit*, s'il y avait des modifications non enregistrées), et il le fait quand le paquet principal, son module et le dossier courant se trouvent dans le même dépôt ([documentation de `go`, option `-buildvcs`](https://pkg.go.dev/cmd/go#hdr-Build_flags)). Pour cela, il a appelé l'outil de contrôle de version et, comme le `.git` était faux, l'outil a échoué : `exit status 128`. Go s'est arrêté et a suggéré `-buildvcs=false`.

Tu verras cette erreur dans la vraie vie avec un vrai `.git` mais incomplet, ou dans une image où l'outil `git` ne peut pas lire le dépôt. Et avec un dépôt complet et sain, la construction n'échoue pas, mais elle fait pire sans prévenir : elle grave des informations de ton dépôt dans l'exécutable, et le contenu de l'image dépend de la présence de modifications non enregistrées dans ton dossier.

#### 4.6.3 Le `.dockerignore` de la leçon

La correction n'est pas `-buildvcs=false`. C'est que le `.git` ne voyage pas. Voici le `.dockerignore` avec lequel se termine la leçon ; il remplace celui de la Leçon 3 :

```text
# fig04_02.dockerignore
# Lo que nunca viaja al daemon al construir.
.git
.env
*.tar
*.md
Dockerfile*
.dockerignore
compose.yaml
secretos/
```

Les cinq lignes de la Leçon 3 sont toujours là, avec leur raison d'être. On en ajoute trois :

- **`*.md`** : les notes, le `README.md`, le journal de bord. Le `revisor` n'a besoin d'aucun fichier Markdown pour être compilé, et tu as déjà vu dans la section 4 de `fig04_03.sh` qu'avec cette ligne, modifier tes notes n'invalide rien.
- **`compose.yaml`** : le fichier qui décrit le système complet et que tu écriras dans la Leçon 9. Il décrit comment l'image **s'exécute** ; il n'a rien à faire **à l'intérieur** de celle-ci.
- **`secretos/`** : le dossier où, à partir de la Leçon 6, vivront les fichiers contenant des tokens factices. On l'exclut dès aujourd'hui, avant qu'il n'existe, pour la même raison que, dans la Leçon 3, on a exclu le `.env` avant qu'il y en ait un : le jour où quelqu'un créera ce dossier, le `.dockerignore` l'attendra déjà.

Avec ce fichier et les `COPY` sélectifs, il y a deux barrières entre ton dossier et l'image : ce que le `.dockerignore` laisse voyager et, parmi cela, uniquement ce qu'un `COPY` demande.

> [!NOTE]
> 🔧 **Observation de génie logiciel 4.4**
> Les `COPY` sélectifs donnent l'impression que le `.dockerignore` est inutile : lors de la construction 1, rien de superflu n'a voyagé. Ne t'y fie pas. Le jour où quelqu'un ajoutera un `COPY . .` (par précipitation, ou pour copier un nouveau fichier), la seule barrière restante sera le `.dockerignore`. Les défenses qui s'appuient l'une sur l'autre s'écrivent toutes les deux.

### 4.7 Vérifier avant de construire

L'habitude de la Leçon 3 ne se perd pas parce que le Dockerfile a changé. `fig04_06.sh` vérifie le nouveau Dockerfile avec `docker build --check`, qui exécute les vérifications sans rien construire ([Docker, « Build checks »](https://docs.docker.com/build/checks/)) :

```bash
#!/usr/bin/env bash
# fig04_06.sh — Revisar el Dockerfile de la lección antes de construir, como en
# la Lección 3. No construye nada ni crea contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
docker build --check . 2>&1 | tail -1
```

```text
$ ./fig04_06.sh
Check complete, no warnings found.
```

Cette sortie est stable. Le `tail -1` ne garde que le verdict ; sans lui, tu verrais les mêmes étapes `[internal]` que dans la Leçon 3. Le `RUN --mount` ne gêne pas la vérification : c'est une syntaxe en vigueur du Dockerfile, et la ligne `# syntax=docker/dockerfile:1` du début garantit que le constructeur la comprend.

### 4.8 Ce que tu verras dans d'autres projets

- **`COPY go.mod go.sum ./` suivi de `RUN go mod download`.** C'est l'astuce la plus célèbre pour les projets Go avec des dépendances : les télécharger dans une couche qui n'est refaite que lorsque la liste change. C'est une bonne idée **quand il y a des dépendances**. Le `revisor` n'en a aucune (c'est pourquoi il n'a pas de `go.sum`), si bien que cette couche n'aurait rien à télécharger. Si tu empaquettes un projet avec des dépendances, ce couple de lignes se place exactement là où se trouve ici `COPY go.mod ./`, et le guide de Docker utilise en plus un second montage de cache, `target=/go/pkg/mod`, pour les modules téléchargés ([Docker, « Optimize cache usage »](https://docs.docker.com/build/cache/optimize/)).
- **Tout dans un seul `RUN` géant avec `&&`.** C'est logique pour installer des paquets et nettoyer dans la même couche (rappelle-toi l'Observation 4.1 : ce qu'on supprime dans une autre couche continue de peser). Ce ne l'est pas pour mélanger des étapes qui changent à des rythmes différents.
- **`DOCKER_BUILDKIT=0`.** Active le constructeur antérieur à BuildKit (le *legacy builder*), qui n'a ni montages de cache ni les transferts incrémentaux de 4.6. BuildKit est le constructeur par défaut de Docker Engine ([Docker, « BuildKit »](https://docs.docker.com/build/buildkit/)) ; si un tutoriel te demande de le désactiver, méfie-toi du tutoriel. Ne le confonds pas avec `docker builder`, qui n'est que le groupe de commandes pour administrer les constructions, comme `docker builder prune` ([`docker builder`](https://docs.docker.com/reference/cli/docker/builder/)).
- **`docker system prune -a` ou `docker builder prune -a` « pour libérer de l'espace ».** Ils suppriment le cache de **tous** les projets de la machine. Tu sais déjà pourquoi non (4.4.5).

## L'erreur que tu vas voir

Cette leçon comporte une erreur principale et un symptôme qui ne produit pas d'erreur mais coûte du temps.

**1. Le `.git` qui casse la compilation.**

```text
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Elle se lit de haut en bas : Go a tenté d'obtenir l'état du contrôle de version (*VCS status*), l'outil a échoué avec le code 128, et Go te suggère de ne pas graver ces informations. La dernière ligne vient de Docker : le `RUN` s'est terminé avec le code 1 et la construction s'est arrêtée. La cause n'est presque jamais dans ton code : c'est qu'un `.git` est arrivé dans l'image. Vérifie dans cet ordre : le `.dockerignore` est-il à la racine du contexte, à côté du `Dockerfile` ? Contient-il `.git` ? Y a-t-il un `COPY . .` dans le Dockerfile ? La correction consiste à ce que le `.git` ne voyage pas. `-buildvcs=false` supprime aussi l'erreur, mais laisse le `.git` voyager et entrer dans l'image : c'est couper l'alarme sans éteindre le feu.

**2. Tout se reconstruit alors que tu as peu changé.** Il n'y a pas de message d'erreur ; il n'y a que de l'attente. On le diagnostique avec `--progress=plain` : cherche la **première** étape qui indique `DONE` au lieu de `CACHED` après le `FROM`. C'est l'étape dont le contenu a changé, et tout ce qui suit a été refait par la règle 3. Si cette première étape est un `COPY . .`, tu connais déjà la correction (4.3). Si c'est un `COPY` d'un fichier que tu n'as pas touché, cherche ce qui a changé d'autre dans ce chemin : un fichier généré, des notes, une sauvegarde. Ce qui ne doit pas invalider le cache ne doit pas non plus voyager : cela va dans le `.dockerignore`.

## L'habitude de sécurité de la leçon

**Le contexte de construction n'embarque ni `.git`, ni `.env`, ni sauvegardes, ni secrets, et la vérification du Dockerfile s'exécute toujours.** L'habitude évite deux accidents. Le premier est celui de 4.6 : un `.git`, un `.env` ou une sauvegarde qui voyagent vers un serveur de construction et, avec un `COPY . .`, restent dans une image qui est ensuite publiée. Le `.git`, de plus, peut conserver des secrets que quelqu'un a effacés du code mais pas de l'historique. Le second est plus silencieux : le cache de compilation avec l'`id` d'un autre projet, ou une suppression large qui emporte celui de tout le monde. Un `id` propre et une suppression avec l'`id` complet maintiennent chaque projet dans son couloir.

Et un bonus de sécurité qu'apporte le montage de cache : ce que le compilateur laisse dans son cache ne reste pas dans l'image. Moins de fichiers à l'intérieur, c'est moins de surface, et moins de choses à expliquer le jour où quelqu'un examinera ce que contient ton image.

## Ce qui se fait de travers

**`COPY . .` puis compiler.** N'importe quelle modification, même un commentaire ou une note, refait la compilation complète. Copie d'abord ce qui change peu et à la fin ce qui change beaucoup.

**Compter sur le cache pour « se rendre compte » de ce qui a changé.** Le cache est une chaîne : elle se brise au premier maillon qui change et tout ce qui suit est refait. L'ordre du Dockerfile est ton outil pour que ce maillon se trouve le plus bas possible.

**Supprimer le cache de compilation avec `rm -rf` à la fin du `RUN`.** Cela réduit la couche, mais jette aussi ce qui accélère la construction suivante. Le montage de cache donne les deux : la couche petite et le cache vivant.

**Utiliser `-buildvcs=false` pour supprimer l'erreur du `.git`.** Cela supprime le symptôme et laisse le `.git` dans l'image.

**Ne mesurer que la durée totale.** Un chiffre sans le tableau des étapes ne dit pas ce qui a été refait. `--progress=plain`, si.

**Utiliser l'`id` par défaut ou un `id` générique pour le montage de cache.** Des projets différents finissent par partager, et par s'écraser mutuellement, le même cache.

**Nettoyer avec `prune -a` ou avec un filtre large.** Cela emporte le cache des autres projets de la même machine. On supprime avec le type et l'`id` complet.

**Retirer des lignes du `.dockerignore` parce qu'« avec des `COPY` sélectifs, ce n'est plus nécessaire ».** C'est nécessaire le jour où quelqu'un réécrit `COPY . .`.

## Exercices

Fais-les dans l'ordre et écris ta prédiction dans ton [journal de bord](bitacora.md) avant d'exécuter chacun. À la fin, supprime ce que tu as créé : tout porte le préfixe `curso-docker-`, et le cache de compilation des exercices se supprime avec la commande de 4.4.5 et son propre `id`.

### Exercice 1 — Prédis le cache

Avec le Dockerfile de la leçon et une construction précédente dans le cache, prédis pour chaque modification quelles étapes indiqueront `CACHED` et lesquelles `DONE`. Fais-le au crayon, en utilisant les trois règles de 4.2.1, puis vérifie-le avec `fig04_05.sh`, qui applique les quatre modifications l'une après l'autre :

a) Tu changes seulement la date d'`internal/reporte/tabla.go` avec `touch`, sans toucher à son contenu.
b) Tu ajoutes un commentaire à la fin de `cmd/revisor/main.go`.
c) Tu ajoutes un commentaire à la fin de `go.mod`.
d) Tu ajoutes un commentaire (`# ...`) à la fin du `Dockerfile`.

Et une question de plus : dans le cas c, t'attends-tu à ce que le `RUN go build` prenne beaucoup ou peu de temps ? Pourquoi ?

### Exercice 2 — Le `.dockerignore` comme seule barrière (projet)

Copie `programas/revisor/` dans un dossier à toi et mets-y le `.dockerignore` de la leçon et, en tant que `Dockerfile.leccion3`, le Dockerfile de la Leçon 3, celui du `COPY . .`. Volontairement : avec `COPY . .`, le `.dockerignore` est la seule barrière. Construis une fois `curso-docker-revisor:1.0.0-ej2` avec `-f Dockerfile.leccion3 --progress=plain` et note la ligne `transferring context`. Ensuite, crée dans le dossier un `README.md`, un dossier `secretos/` contenant un fichier `token.txt` factice et un fichier `datos.json` de 5 Mo (`head -c 5242880 /dev/urandom > datos.json`). Avant de reconstruire, prédis lesquels des trois voyagent. Reconstruis et regarde à nouveau la ligne. Ensuite, ajoute au `.dockerignore` ce qu'il faut et reconstruis une troisième fois. L'exercice s'autocorrige : tu as terminé quand le contexte transféré revient à quelques kilo-octets et que `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src` n'affiche que `cmd`, `go.mod` et `internal`. À la fin, `docker rmi curso-docker-revisor:1.0.0-ej2` et supprime le dossier.

### Exercice 3 — Corrige l'ordre

Un collègue a écrit ce Dockerfile pour le `revisor`. Il fonctionne, mais chaque modification du code refait tout :

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
WORKDIR /src
COPY internal/ internal/
COPY cmd/ cmd/
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
COPY go.mod ./
USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

1. Avant de construire : cette construction fonctionne-t-elle ou échoue-t-elle ? Pense à ce dont `go build` a besoin pour compiler un module.
2. Trouve les problèmes d'ordre et de cache, et écris la version corrigée.
3. Construis ta version deux fois, la seconde après avoir modifié un commentaire dans `internal/reporte/tabla.go`, et vérifie avec `--progress=plain` que `COPY go.mod ./` et `COPY cmd/ cmd/` indiquent `CACHED`.

### Exercice 4 — Explique-le à ta collègue

Ta collègue de la scène te demande : « Si maintenant le `RUN go build` indique `DONE` chaque fois que je modifie du code, qu'est-ce qu'on gagne avec le `--mount` ? Il est toujours refait ». Réponds-lui en cinq phrases au maximum, en utilisant les mots *cache de couches*, *montage de cache*, *constructeur* et *image*.

## Solutions

### Solution 1

La sortie réelle de `fig04_05.sh` :

```text
$ PREFIJO=curso-docker-l04- ./fig04_05.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## a) Solo cambia la fecha de un archivo (touch), no su contenido
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## b) Un comentario nuevo en cmd/revisor/main.go
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.4s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## c) Un comentario nuevo en go.mod
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.3s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## d) Un comentario nuevo en el Dockerfile
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

a) **Tout `CACHED`.** La date de modification ne compte pas pour le cache (règle 1) ; seul le contenu compte.
b) **À partir de `COPY cmd/` et en dessous.** `cmd/` a changé ; `internal/` non, mais il vient après, il est donc refait par la règle 3 (c'est pourquoi il indique `DONE` alors qu'il n'a rien de différent) ; et le `RUN` aussi.
c) **À partir de `COPY go.mod` et en dessous : tout.** `go.mod` est le premier `COPY`, si bien qu'une modification à cet endroit invalide toute la chaîne. C'est pourquoi on ne place en premier que ce qui ne change presque jamais.
d) **Tout `CACHED`.** Le cache se calcule par instruction, et un commentaire n'est pas une instruction : aucune étape n'a changé. (Une modification d'une instruction, en revanche, invalide bien cette étape et celles du dessous.)

La question supplémentaire : dans le cas c, le `RUN` est refait, mais il prend **peu** de temps (0,3 s lors de cette exécution), car le montage de cache contient déjà tous les paquets compilés et un commentaire dans `go.mod` ne change pas ce que Go doit compiler. Le cache de couches a dit « refais l'étape » ; le cache de Go a dit « mais il n'y a presque rien à faire ». Si tes durées sont différentes, c'est normal ; ce qui doit correspondre, c'est la colonne des `CACHED` et des `DONE`.

### Solution 2

Lors de la deuxième construction, c'est **`datos.json`** qui voyage, et la ligne `transferring context` le trahit : elle passe de quelques kilo-octets à environ 5 Mo. `README.md` ne voyage pas (`*.md` l'exclut), pas plus que `secretos/` (il a sa ligne). Avec `COPY . .`, `datos.json` entre en plus dans l'image : `ls -A /src` l'affiche. La correction est une ligne de plus dans le `.dockerignore` : `datos.json`, ou `*.json` si le `revisor` n'a besoin d'aucun JSON pour être compilé, ce qui est le cas. Avec cela, la troisième construction transfère de nouveau quelques kilo-octets et `/src` ne contient plus que `cmd`, `go.mod` et `internal`. Si le chiffre ne baisse pas, vérifie que le `.dockerignore` se trouve à la racine du contexte, à côté des Dockerfile.

Remarque qu'avec le Dockerfile de la leçon, celui des `COPY` sélectifs, `datos.json` n'aurait pas voyagé même sans cette ligne, car aucun `COPY` ne le demande. C'est l'Observation 4.4 en action : avec `COPY . .`, le `.dockerignore` est la seule barrière ; avec des `COPY` sélectifs, c'est la seconde. Écris-le quand même.

### Solution 3

1. **Elle échoue.** `go build` a besoin du `go.mod` pour savoir quel module il compile, et dans ce Dockerfile le `go.mod` arrive **après** le `RUN`. Compiler sans `go.mod` donne cette erreur, mesurée à l'intérieur de l'image `golang:1.27.3-trixie` avec un paquet `main` minimal dans `cmd/revisor` : `go: go.mod file not found in current directory or any parent directory; see 'go help modules'`. Dans la construction, tu la verras avec le format d'un `RUN` qui échoue, comme en 4.6.2.
2. Les problèmes : `go.mod` vient après le `RUN` (erreur) et devrait venir en premier (cache) ; `internal/` vient avant `cmd/`, à l'inverse de l'ordre de la leçon (moins grave, mais celui qui change le plus doit être en dessous) ; et le `RUN` n'a pas de montage de cache, si bien que chaque modification compile depuis zéro. La version corrigée est `fig04_01.Dockerfile`.
3. Avec la version corrigée, après la modification de `tabla.go`, le tableau indique `CACHED` pour `WORKDIR`, `COPY go.mod ./` et `COPY cmd/ cmd/`, et `DONE` pour `COPY internal/ internal/` et pour le `RUN`, comme en 4.3.3.

### Solution 4

Une réponse possible : « Le **cache de couches** décide si une étape est refaite et, comme le code a changé, le `RUN go build` est refait : rien ne l'empêche. Ce que fait le **montage de cache**, c'est que, quand l'étape est refaite, Go y trouve tout ce qu'il a compilé la fois précédente et ne recompile que le paquet que tu as touché. Ce cache, c'est le **constructeur** qui le conserve, à part, et il n'entre pas dans l'**image**. C'est pourquoi le `RUN` est passé de 10,1 à 0,8 seconde, et la couche de la compilation pèse 100 Mo de moins. L'étape est refaite, oui, mais presque gratuitement ».

## Comment je sais que j'ai réussi

Coche chaque point uniquement si tu l'as vérifié sur ton ordinateur :

- [ ] `docker build --check .` avec le Dockerfile de la leçon se termine par `Check complete, no warnings found.`
- [ ] `docker history curso-docker-revisor:1.1.0` affiche trois couches `COPY` séparées et un `RUN` d'environ 10 Mo.
- [ ] `docker image ls curso-docker-revisor` affiche la `1.1.0` plus légère que la `1.0.0` (lors de ces exécutions, 1,32 Go contre 1,45 Go).
- [ ] Après avoir modifié un commentaire dans `internal/`, `--progress=plain` affiche `CACHED` pour `COPY go.mod ./` et pour `COPY cmd/ cmd/`, et le `RUN` prend moins de deux ou trois secondes.
- [ ] Ajouter ou modifier un fichier `.md` dans le dossier n'invalide aucune étape.
- [ ] Avec un gros fichier dans le dossier, la ligne `transferring context` reste en kilo-octets.
- [ ] Tu sais lire l'erreur `error obtaining VCS status` et tu la corriges avec le `.dockerignore`, pas avec `-buildvcs=false`.
- [ ] Tu as supprimé ton cache de compilation avec `docker buildx prune` en filtrant par `type=exec.cachemount` et par l'`id` complet, et `docker buildx du --filter 'description~=curso-docker-go-build'` ne l'affiche plus.
- [ ] À la fin, `docker ps -a --filter name=curso-docker-` n'affiche rien, et des images du `revisor` il ne reste que celle que tu veux conserver.

## Résumé

Réponds sans regarder la leçon :

1. Qu'est-ce qu'une couche ? Quelles instructions ajoutent des fichiers et lesquelles seulement des informations ? Avec quelle commande les vois-tu ?
2. Que regarde le cache pour décider si un `COPY` est refait ? Et pour un `RUN` ? La date d'un fichier compte-t-elle ?
3. Qu'arrive-t-il aux étapes du dessous quand l'une d'elles est invalidée ? Quelle conséquence cela a-t-il sur l'ordre du Dockerfile ?
4. Que fait `RUN --mount=type=cache` ? Où vit ce cache et pourquoi ne reste-t-il pas dans l'image ?
5. À quoi sert l'`id` d'un montage de cache, et pourquoi un `prune` avec un filtre large est-il dangereux ?
6. Que signifient `CACHED` et `DONE` dans `--progress=plain` ? Quand vois-tu `plain` sans l'avoir demandé ?
7. Quels fichiers le client envoie-t-il au constructeur ? Pourquoi la deuxième construction transfère-t-elle moins que la première ?
8. Quelle est la cause de l'erreur `error obtaining VCS status` et quelle est la bonne correction ?

## Sources

Toutes consultées le 21 octobre 2026.

- [Docker, « Docker build cache »](https://docs.docker.com/build/cache/) : une couche par instruction et l'invalidation en chaîne.
- [Docker, « Build cache invalidation »](https://docs.docker.com/build/cache/invalidation/) : les règles pour `COPY`, `ADD` et `RUN`, et le fait que la date de modification ne compte pas.
- [Docker, « Optimize cache usage »](https://docs.docker.com/build/cache/optimize/) : l'ordre des couches, le contexte réduit, les montages de cache et leur exemple pour Go.
- [Référence du Dockerfile, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache) : les options `id`, `target`, `sharing` et les autres, et l'`id` par défaut.
- [Docker, « Understanding the image layers »](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/) : ce qu'est une couche et pourquoi elle se réutilise.
- [`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/) : la commande, `--format` et `--no-trunc`.
- [`docker buildx build`, option `--progress`](https://docs.docker.com/reference/cli/docker/buildx/build/#progress) : les modes `auto`, `tty`, `plain`, `quiet` et `rawjson`.
- [`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/) : les filtres `until`, `id`, `description` et `type`, avec le type `exec.cachemount`.
- [Docker, « BuildKit »](https://docs.docker.com/build/buildkit/) : le transfert incrémental du contexte et l'omission des fichiers inutilisés.
- [`docker builder`](https://docs.docker.com/reference/cli/docker/builder/) : le groupe de commandes pour administrer les constructions.
- [Docker, « containerd image store »](https://docs.docker.com/engine/storage/containerd/) : le fait que le magasin stocke les images compressées et non compressées.
- [Docker, « Build checks »](https://docs.docker.com/build/checks/) : `docker build --check`.
- [Documentation de la commande `go`](https://pkg.go.dev/cmd/go) : le cache de compilation (« Build and test caching ») et l'option `-buildvcs`.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions citées dans « À propos des exécutions ».
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **cache de construction** | les résultats d'étapes précédentes que le constructeur conserve pour ne pas les refaire |
| **cache de couches** | la partie du cache qui décide si une étape entière est refaite ou sort toute faite |
| **couche** (*layer*) | l'ensemble des modifications de fichiers que laisse une étape du Dockerfile |
| **`CACHED`** | dans `--progress=plain`, l'étape est sortie du cache |
| **contexte de construction** | les fichiers que la construction peut utiliser ; BuildKit ne transfère que ceux qui sont demandés et ceux qui ont changé |
| **`DONE`** | dans `--progress=plain`, l'étape a été réellement exécutée, avec sa durée |
| **invalider** | faire qu'une étape ne puisse plus sortir du cache parce que quelque chose de ce qu'elle utilise a changé |
| **montage de cache** | dossier que le constructeur conserve à part et monte dans un `RUN` ; son contenu ne reste pas dans l'image |
| **`--progress=plain`** | le format texte brut d'une construction, étape par étape |
| **VCS** (*version control system*) | le système de contrôle de version, comme Git |

---

**Suivante :** [Leçon 5 — Multi-stage : des gigaoctets aux mégaoctets](05-multi-stage.md)
