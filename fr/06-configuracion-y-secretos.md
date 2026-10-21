# Leçon 6 — Configuration et secrets

Il est 18 h 40 un jeudi, et l'équipe veut livrer le `revisor` à 19 h. Il reste un détail : l'environnement de test a besoin d'une autre liste de services et d'un autre token. Quelqu'un propose la solution rapide : « Je change le token dans le Dockerfile, je reconstruis et je la pousse ; ça prend cinq minutes. » Il le fait, et l'image part sur le registre partagé. À 18 h 52, un collègue d'une autre équipe demande sur le chat, en toute innocence, pourquoi l'image du `revisor` contient une variable `REVISOR_TOKEN` dont la valeur ressemble à un mot de passe. Il n'a eu besoin d'entrer sur aucun serveur ni de forcer quoi que ce soit : un `docker inspect` sur une image qu'il avait le droit de télécharger lui a suffi. Désormais, il faut considérer le token comme compromis, en générer un autre et découvrir qui d'autre a téléchargé l'image. La livraison de 19 h n'aura pas lieu. Cette leçon existe pour que cette conversation n'ait jamais lieu : l'image ne contient ni la configuration d'un environnement ni ses secrets, et tu vas vérifier de tes propres yeux ce qui reste à l'intérieur.

**Durée :** 90 min

**Ce que tu construis :** le `revisor` configuré sans reconstruire. L'image `curso-docker-revisor:1.3.0` porte, gravée en elle, sa version, qui n'est pas secrète, et rien d'autre provenant d'un quelconque environnement. La liste des services arrive au moment d'exécuter le conteneur, par des variables d'environnement ou par un fichier de variables. Le token d'accès arrive sous la forme d'un fichier en lecture seule, jamais sous la forme d'une variable. Et le modèle pour utiliser un secret **pendant la construction** est prêt dans le Dockerfile, sans laisser de trace dans l'image.

**Ce que tu apprends :** ce qui relève de la configuration et ce qui relève du secret ; `ARG` contre `ENV` (quand chacun existe et où il reste écrit) ; `-e` et `--env-file` ; les labels OCI avec la version ; les secrets de construction (build secrets) avec `--mount=type=secret` et `--secret` ; les secrets d'exécution par fichier, et pourquoi pas par variable ; et, surtout, à **regarder** avec `docker history` et `docker inspect` ce qui voyage à l'intérieur d'une image.

**D'où tu viens.** De la [Leçon 5](05-multi-stage.md), où le `revisor` a fini dans une image à quatre étapes, `curso-docker-revisor:1.2.0`, de 16,1 Mo, sans *shell*, sans compilateur et avec l'utilisateur `65532`. Cette image a un trou que tu as peut-être remarqué : sa sous-commande `version` affiche `desarrollo`, parce que personne ne lui a dit quelle version elle est. De la [Leçon 3](03-primer-dockerfile.md), tu apportes aussi le `.dockerignore` qui laisse de côté `.env` et `secretos/`, et de la [Leçon 2](02-contenedores-dia-a-dia.md), l'habitude de publier les ports uniquement sur `127.0.0.1`. Et de la Leçon 3 encore, l'erreur de démarrer le `revisor` sans `REVISOR_SERVICIOS` : aujourd'hui, tu vas voir pourquoi cette variable n'a pas sa place dans le Dockerfile.

**Ce que cette leçon ne fait pas.** Elle n'explique pas les montages en profondeur : le token arrive avec un `--mount type=bind` d'un seul fichier, et pour l'instant il suffit de savoir qu'il place un fichier de l'ordinateur à l'intérieur du conteneur. La [Leçon 8](08-volumenes-y-redes.md) explique les montages en entier. Elle n'utilise pas non plus les secrets de Compose, qui sont la façon confortable de faire la même chose et arrivent dans la [Leçon 9](09-compose.md). Elle n'enseigne pas les gestionnaires de secrets externes (coffres-forts, services cloud) : ce cours travaille sur ton ordinateur, et ce que tu apprends ici est la partie dont ces gestionnaires ont aussi besoin, à savoir que le secret arrive sous forme de fichier et ne reste pas dans l'image. Et tu n'as pas besoin d'avoir des modules Go privés : le `revisor` n'en utilise pas, et le secret de construction s'enseigne avec une valeur factice.

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4, la même base que Linux Mint 22, le système de référence du cours. Les scripts ont été exécutés **à l'intérieur** de cette machine virtuelle, avec Docker 29.2.1 (client et daemon) et Buildx v0.31.1, et avec leur dossier de travail sur le disque propre de Linux. Ce dernier point compte dans cette leçon : les dossiers partagés entre le Mac et la machine virtuelle mentent sur les permissions (un fichier avec les permissions `600` se lit tout de même depuis un conteneur d'un autre utilisateur), et la section 6.5 porte justement sur les permissions. Sur ton Mint, ce problème n'existe pas. Pour éviter les collisions avec d'autres exécutions qui utilisaient la même machine, les scripts ont été lancés avec un autre préfixe de noms et d'autres ports (les variables `PREFIJO` et `PUERTO` qu'ils comportent) ; aucun nom de conteneur ni d'image, ni le port de l'ordinateur, n'apparaît dans leurs sorties, donc ce que tu vois est exactement ce qu'ils ont affiché. Avec leurs valeurs par défaut, les scripts utilisent des noms auxiliaires propres qui contiennent `fig06` (l'image `curso-docker-revisor:fig06`, le conteneur `curso-docker-revisor-fig06`) : ainsi, ils ne touchent jamais ton image `curso-docker-revisor:1.3.0` ni ton conteneur `curso-docker-revisor`, et en sortant ils suppriment uniquement ce qu'ils ont créé. Le cours a été planifié avec Docker Engine 29.8.2, et la version la plus récente publiée ce jour-là était la 29.9.2, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)) ; rien dans cette leçon ne change entre ces versions. Ce qui change **effectivement** d'une exécution à l'autre, et c'est signalé là où cela apparaît : les durées du tableau du `revisor` (masquées par `<t>` dans le script lui-même), les durées et la date des lignes de construction, et le mot `arm64` dans l'historique de l'image, qui indique `amd64` sur un ordinateur Intel ou AMD. Les programmes se trouvent dans [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos), chacun avec sa sortie à côté, et `estado/` conserve les fichiers du projet tels qu'ils sont à la fin.

## À la fin, tu seras capable de

- Classer une donnée du `revisor` comme code, configuration ou secret, et dire où chacune doit vivre.
- Expliquer la différence entre `ARG` et `ENV` en disant quand chacun existe et où il reste écrit, et le vérifier avec `docker history` et `docker image inspect`.
- Exécuter la même image avec deux configurations différentes, avec `-e` et avec `--env-file`, sans reconstruire.
- Trouver un secret laissé dans une image par `ARG` ou par `ENV`, et lire l'avertissement `SecretsUsedInArgOrEnv` de `docker build --check`.
- Fournir le token du `revisor` sous forme de fichier en lecture seule, et corriger l'erreur `permission denied` qui apparaît en le faisant.
- Utiliser un secret pendant la construction avec `--secret` et démontrer qu'il n'est pas resté dans l'image.

## Le pourquoi avant le comment

Jusqu'à la Leçon 5, tout ce dont le `revisor` avait besoin pour tourner venait de l'image ou de quelques `-e` écrits à la volée. Cela fonctionnait parce qu'il n'y avait qu'un seul environnement : ton ordinateur. Dès qu'un deuxième environnement apparaît (test, production, l'ordinateur d'un collègue), la question de cette leçon apparaît aussi : **qu'est-ce qui change d'un environnement à l'autre, et où l'écrit-on ?**

La réponse classique vient d'un guide très cité, *The Twelve-Factor App*, qui définit la configuration d'une application comme « tout ce qui est susceptible de varier entre les déploiements » ([12factor.net, « Config »](https://12factor.net/config)). Dans le `revisor`, cela correspond à la liste des services qu'il surveille, au port, au chemin du rapport et au token. Ce qui **ne** varie **pas**, c'est le code et la version : la `1.3.0` est la `1.3.0` partout. Le même guide propose un test simple pour savoir si la séparation est bonne : pourrais-tu publier ton code en open source à l'instant même sans exposer aucun identifiant ? Ce cours est ouvert, donc le test n'a rien d'hypothétique : le Dockerfile du `revisor` est publié, et c'est pourquoi il ne peut contenir rien que tu ne veuilles pas voir lu par le monde entier.

Avec les images, la question a une dimension de plus. Une image n'est pas seulement un fichier qui s'exécute ; c'est un paquet qui **voyage** : on la pousse sur un registre, on la télécharge sur d'autres machines, on la conserve dans des caches, on la copie vers un cluster. Tout ce que tu y mets, quiconque peut la télécharger le reçoit. Et une image conserve plus qu'il n'y paraît : en plus des fichiers de ses couches, elle conserve sa **configuration** (l'environnement, l'utilisateur, les labels) et son **historique** (l'instruction qui a créé chaque couche, avec les valeurs qu'elle avait). La documentation de Docker le dit sans détour : les arguments de construction et les variables d'environnement « ne conviennent pas pour transmettre des secrets à ta construction », car ils « persistent dans l'image finale » ([Docker, « Build secrets »](https://docs.docker.com/build/building/secrets/)).

Cette leçon fait donc trois choses, dans cet ordre :

1. **Sortir la configuration de l'image** (6.1 à 6.3) : l'image porte sa version et des valeurs par défaut qui ne sont pas secrètes ; le reste arrive à l'exécution.
2. **Voir de tes yeux ce qui se passe quand un secret entre dans l'image** (6.4) : tu vas l'y mettre exprès, avec des valeurs factices, et tu vas le retrouver.
3. **Bien faire les choses** (6.5 et 6.6) : le secret d'exécution sous forme de fichier en lecture seule, et le secret de construction sous forme de montage qui dure le temps d'un `RUN`.

Avec cette destination en tête, voici ce que tu verras à la section 6.4, en fouillant une image mal faite. La valeur factice est là, dans l'historique, même si le `RUN` lui-même a supprimé le fichier qui la contenait :

```text
== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

## Les concepts

### 6.1 Code, configuration et secret : trois choses distinctes

#### 6.1.1 Classer ce dont le `revisor` a besoin

Avant d'écrire une seule ligne, il vaut la peine de nommer chaque donnée. Il y a trois catégories :

| Catégorie | Ce que c'est | Dans le `revisor` | Où elle vit |
|---|---|---|---|
| **Code** | ce que fait le programme ; identique dans tous les environnements | le binaire, compilé en version `1.3.0` | à l'intérieur de l'image |
| **Configuration** | ce qui change d'un environnement à l'autre et n'est pas secret | `REVISOR_SERVICIOS`, `REVISOR_PUERTO`, `REVISOR_REPORTE` | hors de l'image ; arrive à l'exécution |
| **Secret** | une configuration que quelqu'un peut utiliser contre toi si elle fuit | le token de `/api/estados` ; un identifiant pour télécharger des modules privés | hors de l'image **et** hors des variables d'environnement ; arrive sous forme de fichier |

Deux données méritent un commentaire. Le **port** relève de la configuration, mais il a une valeur par défaut raisonnable (`8080`) qui n'est pas secrète, et c'est pourquoi l'image le déclare avec `ENV` : cela sert de documentation et de valeur par défaut, et n'importe quel environnement peut le changer. La **version** ne relève pas de la configuration : elle ne change pas d'un environnement à l'autre, elle décrit le code. C'est pourquoi on la grave à la construction et on ne la demande pas à l'exécution.

Le secret a sa propre catégorie parce qu'il remplit les deux conditions : il change d'un environnement à l'autre (le token de test n'est pas celui de production) et sa valeur ne doit pas rester visible. C'est cette seconde condition qui écarte les variables d'environnement, comme tu le verras en 6.5.

#### 6.1.2 Les secrets de ce cours sont factices, et ils le disent

Tous les secrets qui apparaissent dans cette leçon sont **inventés pour l'exercice** et l'annoncent dans leur propre valeur : `curso-docker-token-de-mentira-7f3a9c`, `curso-docker-modulos-de-mentira-41be`. Ils n'ouvrent rien. Ils vivent dans le dossier `secretos/` du projet, que le cours publie exprès pour que tu puisses tout exécuter. Dans un vrai projet, ce dossier n'est **jamais** publié : il figure dans le `.gitignore` et dans le `.dockerignore`, et ses valeurs viennent de l'endroit où ton équipe conserve ses identifiants.

Le `.dockerignore` que tu apportes des leçons 3 et 4 l'exclut déjà, avec `.env` et les `Dockerfile*` :

```text
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

Cela signifie qu'aucun `COPY` ne peut glisser par accident un fichier de `secretos/` dans l'image : il n'atteint même pas le daemon. C'est le premier point d'entrée fermé, et le moins coûteux. Cette leçon ferme les trois autres : l'historique, la configuration de l'image et la configuration du conteneur.

### 6.2 `ARG` contre `ENV`

#### 6.2.1 Deux instructions qui se ressemblent sans se ressembler

Les deux instructions définissent des variables avec un nom et une valeur, et les deux s'utilisent avec `${NOMBRE}` à l'intérieur du Dockerfile. Ce qui les sépare, c'est **quand elles existent** :

- **`ARG`** déclare un **argument de construction**. Il n'existe que pendant la construction de l'image, et sa valeur peut être modifiée de l'extérieur avec `docker build --build-arg NOMBRE=valor`. Les conteneurs qui naissent de l'image ne le reçoivent pas. La documentation le résume ainsi : les arguments de construction « ne sont ni accessibles ni présents dans les conteneurs » créés à partir de l'image, mais leurs valeurs « peuvent persister dans les métadonnées de l'image », dans les attestations de provenance et **dans l'historique** ([Docker, « Build variables »](https://docs.docker.com/build/building/variables/)).
- **`ENV`** définit une **variable d'environnement** qui existe pendant la construction et que, de plus, l'image transmet à chaque conteneur qui naît d'elle : « les variables d'environnement définies avec `ENV` persistent quand un conteneur est exécuté à partir de l'image », et on peut les voir avec `docker inspect` et les modifier avec `docker run --env` ([référence du Dockerfile](https://docs.docker.com/reference/dockerfile/)).

En une ligne : `ARG` est une donnée pour **construire** ; `ENV` est une donnée pour **exécuter**. Et aucun des deux n'est une cachette : les deux laissent leur valeur écrite dans l'image, l'un dans l'historique et l'autre dans la configuration.

Il y a un détail de portée qui déroute tout le monde la première fois. Un `ARG` est valable **dans l'étape où il est déclaré** (et dans les étapes qui en dérivent). Dans un Dockerfile à plusieurs étapes, si l'étape `final` a aussi besoin de la valeur, elle le déclare de nouveau. C'est ce que fait le Dockerfile de cette leçon avec `VERSION`.

#### 6.2.2 Le Dockerfile de cette leçon

Voici le Dockerfile avec lequel se termine la leçon. C'est celui de la Leçon 5 avec quatre modifications, et chacune est expliquée plus bas :

```dockerfile
# syntax=docker/dockerfile:1
# fig06_01.Dockerfile — Lección 6: la imagen no lleva configuración de un ambiente ni secretos.
# Lo único que se le fija al construir es su VERSIÓN, que no es secreta.

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
ENTRYPOINT ["/revisor"]
```

Les quatre modifications, dans l'ordre où elles apparaissent :

1. **`ARG VERSION=desarrollo` dans l'étape `binario`.** Déclare l'argument avec une valeur par défaut. Si tu construis sans `--build-arg`, il vaut `desarrollo`, ce qui est exactement ce qu'affichait le `revisor` dans la Leçon 5 ; ainsi, rien ne casse pour qui construit sans connaître cet argument.
2. **`-X main.version=${VERSION}` dans `go build`.** C'est une option de l'éditeur de liens de Go qui remplace, à la compilation, la valeur d'une variable texte du programme ([cmd/link](https://pkg.go.dev/cmd/link)). Le `revisor` a une variable `version` dans son paquet `main` qui vaut `desarrollo` si personne n'y touche. Avec cette option, le numéro reste **à l'intérieur du binaire**, le seul endroit où il ne peut ni se perdre ni être contredit.
3. **`--mount=type=secret,...,required=false`** dans ce même `RUN`. C'est le secret de construction ; il a sa propre section, la 6.6. Pour l'instant, il suffit de savoir que, comme il est facultatif, la construction fonctionne de la même façon avec ou sans lui.
4. **Dans l'étape `final` : `ARG VERSION` de nouveau, `LABEL` et `ENV`.** L'`ARG` est répété parce que chaque étape a sa propre portée (6.2.1). Avec lui, `LABEL` attache à l'image trois **labels** dont les noms viennent d'un standard, celui de l'*Open Container Initiative* : `org.opencontainers.image.title` est le « titre lisible » de l'image, `org.opencontainers.image.version` est la « version du logiciel empaqueté » et `org.opencontainers.image.source` est l'« URL permettant d'obtenir le code source » à partir duquel l'image est construite ([OCI, annotations prédéfinies](https://github.com/opencontainers/image-spec/blob/main/annotations.md)). Ici, elle pointe vers la page du cours, qui est l'adresse publique que ce cours garantit ; dans ton propre projet, mets-y l'adresse du dépôt, qui est ce que demande la spécification. Tout outil qui sait lire ces labels (un registre, un scanner, la Leçon 10) sait ce qu'est l'image sans l'exécuter. Et `ENV REVISOR_PUERTO=8080` laisse la valeur par défaut du port visible pour quiconque inspecte l'image.

Remarque ce qu'il n'y a **pas** : ni `REVISOR_SERVICIOS`, ni `REVISOR_TOKEN`, ni `REVISOR_TOKEN_ARCHIVO`. L'image ne sait pas dans quel environnement elle va tourner, et c'est ainsi que ce doit être.

#### 6.2.3 Construire et regarder où chaque chose est restée

Le script `fig06_02.sh` construit l'image avec `--build-arg VERSION=1.3.0`, puis lui demande, sans exécuter le serveur, ce qu'elle contient :

```bash
#!/usr/bin/env bash
# fig06_02.sh — Construir el revisor con su versión como ARG y mirar dónde quedó.
# Construye curso-docker-revisor:1.3.0 con fig06_01.Dockerfile y pregunta a la
# imagen qué trae: la versión, las etiquetas, el entorno y el historial.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

echo "== 1. Construir, pasando la versión como argumento de construcción"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'

echo
echo "== 2. La versión, grabada dentro del binario"
docker run --rm --name "${PREFIJO}revisor-fig06-version" "$IMAGEN" version

echo
echo "== 3. Las etiquetas OCI de la imagen"
docker image inspect --format '{{range $k, $v := .Config.Labels}}{{$k}} = {{$v}}{{println}}{{end}}' "$IMAGEN"

echo "== 4. El entorno que la imagen entrega a cada contenedor (ENV)"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN"

echo "== 5. El historial de la imagen final, de arriba (lo último) hacia abajo"
docker history --format '{{.Size}}	{{.CreatedBy}}' "$IMAGEN" | head -8
```

```text
$ ./fig06_02.sh
== 1. Construir, pasando la versión como argumento de construcción
tamaño: 16.1MB

== 2. La versión, grabada dentro del binario
1.3.0

== 3. Las etiquetas OCI de la imagen
org.opencontainers.image.source = https://www.habil.mx/es/cursos/docker/
org.opencontainers.image.title = revisor
org.opencontainers.image.version = 1.3.0

== 4. El entorno que la imagen entrega a cada contenedor (ENV)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
REVISOR_PUERTO=8080

== 5. El historial de la imagen final, de arriba (lo último) hacia abajo
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
0B	ENV REVISOR_PUERTO=8080
0B	LABEL org.opencontainers.image.title=revisor…
0B	ARG VERSION=1.3.0
319kB	bazel build //common:cacerts_debian13_arm64_…
```

Cinq blocs, cinq endroits différents où vit l'information d'une image :

1. **La taille n'a pas changé** : 16,1 Mo, comme la `1.2.0`. Les labels, l'`ENV` et l'`ARG` ne pèsent rien : ce sont des métadonnées, pas des fichiers.
2. **La version est dans le binaire.** La sous-commande `version` affiche `1.3.0`. C'est la même que renvoie `GET /salud` et la même que le `revisor` écrit au démarrage (`revisor 1.3.0 escuchando en :8080`), comme tu le verras en 6.5.
3. **Les labels OCI** se trouvent dans la configuration de l'image et se lisent avec `docker image inspect`, sans rien exécuter. Le modèle `{{range $k, $v := .Config.Labels}}` parcourt la table des labels ; `docker` les trie par nom.
4. **L'environnement** que recevra chaque conteneur : deux variables qu'apporte la base *distroless* (`PATH` et `SSL_CERT_FILE`, le chemin des certificats de confiance) et la nôtre, `REVISOR_PUERTO=8080`. Regarde bien ce qui **manque** : `VERSION`. L'`ARG` n'est pas passé dans l'environnement. Aucun conteneur ne va le recevoir.
5. **L'historique**, du plus récent au plus ancien. Chaque ligne est une instruction de l'étape `final` (les autres étapes n'y sont pas : elles ne font pas partie de l'image livrée, comme tu l'as vu dans la Leçon 5). Celles qui ne créent pas de fichiers pèsent `0B`. Le `…` est `docker history` qui tronque les lignes longues ; avec `--no-trunc`, on les voit en entier. Et voici maintenant la ligne qui compte pour le reste de la leçon : **`ARG VERSION=1.3.0`**. La valeur de l'argument est écrite dans l'historique, visible par quiconque possède l'image. Pour une version, c'est parfait : elle n'est pas secrète, et cela aide même. Pour un token, ce serait une fuite. Garde cette image en tête ; en 6.4, tu vas la voir avec une valeur qui ne devrait pas s'y trouver.

La dernière ligne (`bazel build //common:cacerts_debian13_arm64_…`) est une couche de la base *distroless* : ses auteurs la construisent avec un outil appelé Bazel, et l'historique l'enregistre. Sur ton Mint avec un processeur Intel ou AMD, elle indique `amd64` là où elle indique ici `arm64`.

#### 6.2.4 Dans ton dossier

Les scripts du cours travaillent dans des dossiers temporaires et suppriment ce qu'ils créent ; ton projet vit dans `~/curso-docker/revisor` depuis la Leçon 3. Depuis la racine du dépôt du cours, place-y le Dockerfile de cette leçon et le dossier de secrets factices, et construis l'image que tu vas conserver :

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cp -R programas/06-configuracion-y-secretos/estado/secretos ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 -t curso-docker-revisor:1.3.0 .
docker run --rm curso-docker-revisor:1.3.0 version
```

La dernière commande doit afficher `1.3.0`. Le `.dockerignore` ne change pas : il exclut déjà `secretos/`. Dans `estado/`, il y a aussi `Dockerfile.malo`, la mauvaise recette de 6.4. Copie-la aussi, car « Comment je sais que j'ai réussi » te demande de refaire cette expérience ; le `.dockerignore` (qui exclut `Dockerfile*`) l'empêche de voyager dans le contexte. Et quand tu arriveras en 6.6, reconstruis ton image avec le secret de construction, pour vérifier qu'il ne laisse pas de trace :

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile.malo ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt -t curso-docker-revisor:1.3.0 .
```

Les scripts de cette leçon ne touchent à rien de tout cela : ils utilisent des noms auxiliaires avec `fig06` et ne suppriment que ce qui leur appartient.

### 6.3 Configurer sans reconstruire

#### 6.3.1 `-e` et `--env-file`

L'image ne sait plus quels services surveiller. On le lui dit **à l'exécution**, et il y a deux façons de le faire :

- **`-e NOMBRE=valor`** (ou `--env`), une par variable, sur la même ligne que `docker run`. C'est ce que tu utilises depuis la Leçon 2. Si tu écris seulement `-e NOMBRE`, sans valeur, Docker prend la valeur que cette variable a dans ton terminal et la transmet ; si elle n'existe pas dans ton terminal, le conteneur ne la reçoit pas ([référence de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).
- **`--env-file fichier`** : un fichier texte avec un `NOMBRE=valor` par ligne. Les lignes qui **commencent** par `#` sont des commentaires ; un `#` au milieu d'une ligne fait partie de la valeur. Une ligne avec seulement `NOMBRE`, sans `=`, prend la valeur de ton terminal, comme `-e NOMBRE`. Cela permet de garder la configuration de chaque environnement dans son propre fichier (`pruebas.env`, `local.env`) plutôt que dans une commande de trois lignes dont personne ne se souvient.

Les deux façons peuvent se combiner, et toutes deux l'emportent sur ce que dit l'`ENV` de l'image. C'est le sens d'une valeur par défaut : être là jusqu'à ce que quelqu'un dise autre chose.

#### 6.3.2 La même image, trois configurations

Le script `fig06_03.sh` construit `curso-docker-revisor:1.3.0` une seule fois et l'exécute trois fois avec des configurations différentes. La première contient une erreur volontaire :

```bash
#!/usr/bin/env bash
# fig06_03.sh — Configurar sin reconstruir: la MISMA imagen, tres configuraciones.
# Una variable mal escrita, una lista por -e y otra lista por --env-file.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# La tabla del revisor, con el tiempo tapado: es lo único que cambia entre corridas.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
}

echo "== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS"
rc=0
docker run --name "$NOMBRE" -e REVISOR_SERVICIO='propio http://127.0.0.1:8080/salud' "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. La configuración por -e: un solo servicio"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla
IMAGEN_1=$(docker inspect --format '{{.Image}}' "$NOMBRE")
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Otra configuración, desde un archivo con --env-file"
cat > revisor.env <<'FIN'
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
FIN
cat revisor.env
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --env-file revisor.env "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR

echo "== 5. ¿Las dos corridas usaron la misma imagen?"
IMAGEN_2=$(docker inspect --format '{{.Image}}' "$NOMBRE")
[ "$IMAGEN_1" = "$IMAGEN_2" ] && echo "sí: el mismo identificador de imagen en las dos" || echo "no: son imágenes distintas"
```

```text
$ ./fig06_03.sh
== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]

== 2. La configuración por -e: un solo servicio
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 3. Otra configuración, desde un archivo con --env-file
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
SERVICIO     ESTADO    TIEMPO  DETALLE
inexistente  FALLA         <t>  no responde: Get "http://127.0.0.1:9/": dial tcp 127.0.0.1:9: connect: connection refused
propio       OK            <t>  200

== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
REVISOR_PUERTO=8080
== 5. ¿Las dos corridas usaron la misma imagen?
sí: el mismo identificador de imagen en las dos
```

Avant de lire la sortie, voici les nouvelles lignes du script. La fonction `tabla` demande le rapport sous forme de tableau et masque le temps de réponse par `<t>`, parce que c'est la seule chose qui change d'une exécution à l'autre ; elle le masque **dans la commande elle-même**, à la vue de tous, et non en retouchant la sortie. Le service `propio` est le `revisor` qui se surveille lui-même : à l'intérieur du conteneur, `127.0.0.1:8080` est le conteneur lui-même, pas ton ordinateur. Et le service `inexistente` pointe vers le port 9, où rien n'écoute ; il est là pour que tu voies un échec.

Maintenant la sortie, bloc par bloc :

1. **Une lettre en moins.** `REVISOR_SERVICIO` n'est pas une variable que le `revisor` connaît, il l'ignore donc en silence, comme tout programme ignore les variables qu'il ne lit pas. Pour lui, `REVISOR_SERVICIOS` n'existe tout simplement pas, et il refuse de démarrer avec le code 1. C'est la même erreur que dans la Leçon 3, mais tu sais maintenant pourquoi elle est si fréquente : Docker ne valide pas les noms de variables ; il n'a aucun moyen de savoir lesquelles ton programme lit. C'est le programme qui valide, et c'est pourquoi il est bon que le `revisor` échoue bruyamment et avec un exemple, au lieu de démarrer avec une liste vide en faisant comme si tout allait bien.
2. **Avec `-e`, un service.** Le rapport contient une ligne, `propio`, opérationnel.
3. **Avec `--env-file`, deux services.** Le fichier contient un commentaire et une variable. Remarque que la valeur **n'a pas de guillemets** : dans un fichier de `docker run --env-file`, tout ce qui suit le `=` est la valeur, guillemets compris. C'est un piège classique, et l'Exercice 3 te le fait rencontrer. Attention en appliquant cette règle à la Leçon 9 : l'`env_file` de Compose est un autre lecteur, et lui **retire** les guillemets ([référence des services de Compose](https://docs.docker.com/reference/compose-file/services/)). Mesuré avec Compose v5.0.2 : la même ligne avec guillemets est arrivée dans le conteneur sous la forme `REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud`, sans eux. Même type de fichier, deux lecteurs, deux résultats. Le tableau a maintenant deux lignes : `inexistente` avec `FALLA` et la cause exacte, et `propio` avec `OK`.
4. **Ce qu'a reçu le conteneur**, c'est la somme de ce qu'apporte l'image (`REVISOR_PUERTO=8080`, par son `ENV`) et de ce qui est arrivé à l'exécution (`REVISOR_SERVICIOS`, depuis le fichier). Le `grep REVISOR` laisse de côté `PATH` et `SSL_CERT_FILE`, qui sont aussi présents.
5. **La même image.** Le script a conservé l'identifiant d'image du premier conteneur et l'a comparé à celui du second : ils sont identiques. Deux comportements différents, zéro reconstruction. C'est tout l'intérêt de séparer la configuration.

#### 6.3.3 Ce que cela t'apporte

Séparer la configuration de l'image n'est pas une question de style. Cela a trois conséquences pratiques. La première : **l'image que tu as testée est celle que tu livres**. Si, pour passer du test à la production, tu devais reconstruire avec une autre configuration, l'image de production serait une image que personne n'a testée. La deuxième : **changer la configuration prend quelques secondes**, le temps que met un conteneur à démarrer, et non le temps d'une construction. La troisième : **l'image peut être publiée**, car elle ne contient rien d'aucun environnement. Ces trois conséquences réunies sont ce qui permet, dans la Leçon 10, de publier une seule image et de l'emmener vers Kubernetes.

### 6.4 À ne PAS faire : regarder de tes yeux ce qui reste dans l'image

#### 6.4.1 La mauvaise recette

Pour apprendre à trouver un secret dans une image, le mieux est d'en cacher un et de le chercher. Ce Dockerfile fait les deux choses que la leçon interdit. Il n'a qu'une seule étape, comme dans la Leçon 4, pour que tout reste visible :

```dockerfile
# syntax=docker/dockerfile:1
# fig06_04.Dockerfile — Lección 6: ASÍ NO. Dos formas de dejar un secreto dentro de la imagen.
# (Una sola etapa, como en la Lección 4, para que todo quede a la vista.)
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/
# Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
# aunque el RUN borre el archivo al final.
ARG TOKEN_MODULOS
RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
 && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
 && rm /root/.netrc
# Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
USER 10001:10001
CMD ["revisor"]
```

Les deux erreurs imitent des cas réels :

- **Mal 1** est ce que fait quelqu'un qui a besoin d'un identifiant pour télécharger des dépendances privées. Go, comme beaucoup d'outils, lit les identifiants dans un fichier `.netrc` situé dans le dossier de l'utilisateur : une ligne `machine <serveur> password <secret>`. La recette écrit le fichier avec la valeur d'un `ARG`, compile et le supprime **dans le même `RUN`**. Son auteur savait qu'un fichier supprimé dans un `RUN` ultérieur reste dans la couche précédente, et c'est pourquoi il a tout fait en une seule fois. Cela semble prudent. Cela ne suffit pas. (Le serveur est `ejemplo.invalid`, un domaine réservé qui n'existe pas sur Internet.)
- **Mal 2** est le raccourci de la scène du début : le token du `revisor` en `ENV`, pour qu'il « soit déjà configuré ».

#### 6.4.2 Le chercher

Le script `fig06_05.sh` construit cette recette en lui passant le token de modules factice, puis cherche les deux secrets là où quiconque possède l'image peut chercher :

```bash
#!/usr/bin/env bash
# fig06_05.sh — ASÍ NO: dos secretos (de mentira) que quedan dentro de la imagen.
# Construye fig06_04.Dockerfile y busca los secretos donde cualquiera que tenga
# la imagen los puede buscar: el historial y la configuración.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
MALO="${PREFIJO}revisor:fig06-malo"
CADENA="${PREFIJO}revisor:fig06-cadena"
trap 'docker rmi -f "$MALO" "$CADENA" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_04.Dockerfile" "$TRABAJO/Dockerfile.malo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Construir pasando el token de módulos (de mentira) por ARG"
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" \
  -f Dockerfile.malo -t "$MALO" . >/dev/null && echo "construida"

echo
echo "== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" --user 0 "$MALO" ls -A /root

echo
echo "== 3. Pero el historial guardó el valor del ARG, en dos renglones"
docker history --no-trunc --format '{{.CreatedBy}}' "$MALO" | grep 'TOKEN_MODULOS='

echo
echo "== 4. Y la configuración de la imagen trae el token de ejecución"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$MALO" | grep TOKEN

echo "== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$MALO" printenv REVISOR_TOKEN

echo
echo "== 6. docker build --check lo habría dicho antes de construir"
rc=0
docker build --check -f Dockerfile.malo . 2>&1 || rc=$?
echo "[código de salida: $rc]"

echo
echo "== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use"
cat > Dockerfile.cadena <<'FIN'
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS base
ARG TOKEN_MODULOS
RUN echo "paso 1: no uso ningún argumento"
FROM base AS hija
ARG VERSION=desarrollo
RUN echo "paso 2: tampoco"
FIN
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" --build-arg VERSION=1.3.0 \
  -f Dockerfile.cadena -t "$CADENA" . >/dev/null
docker history --no-trunc --format '{{.CreatedBy}}' "$CADENA" | head -4
```

```text
$ ./fig06_05.sh
== 1. Construir pasando el token de módulos (de mentira) por ARG
construida

== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está
.bashrc
.cache
.config
.profile

== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be

== 4. Y la configuración de la imagen trae el token de ejecución
REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo
curso-docker-token-de-mentira-en-env

== 6. docker build --check lo habría dicho antes de construir
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile.malo
#1 transferring dockerfile: 892B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.1s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#4 DONE 0.0s

#5 [internal] load .dockerignore
#5 transferring context: 155B done
#5 DONE 0.0s
Check complete, 2 warnings have been found!

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
Dockerfile.malo:11
--------------------
   9 |     # Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
  10 |     # aunque el RUN borre el archivo al final.
  11 | >>> ARG TOKEN_MODULOS
  12 |     RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
  13 |      && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
--------------------

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "REVISOR_TOKEN")
Dockerfile.malo:16
--------------------
  14 |      && rm /root/.netrc
  15 |     # Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
  16 | >>> ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
  17 |     USER 10001:10001
  18 |     CMD ["revisor"]
--------------------
[código de salida: 1]

== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use
RUN |2 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be VERSION=1.3.0 /bin/sh -c echo "paso 2: tampoco" # buildkit
ARG VERSION=1.3.0
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "paso 1: no uso ningún argumento" # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

#### 6.4.3 Lire ce que tu as trouvé

1. **Le fichier n'est plus là.** À l'intérieur de l'image, `/root` contient les fichiers habituels de la base et les caches laissés par `go build` (`.cache`, `.config`), mais pas `.netrc`. Le script utilise `--user 0` uniquement pour pouvoir regarder dans `/root`, qui n'est pas lisible pour l'utilisateur `10001` de l'image. Si tu t'arrêtais ici, tu dirais que la recette a fonctionné.
2. **L'historique l'a, deux fois.** Une ligne est l'instruction elle-même, `ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`, avec la valeur qu'elle a reçue. L'autre est le `RUN`, qui commence par `|1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`. Ce `|1` est un **décompte** : « à cette étape, il y avait 1 argument de construction » ; ensuite viennent tous les arguments, avec leur valeur. Supprimer le fichier n'a pas supprimé la valeur, parce que la valeur n'a jamais été seulement dans le fichier. C'est le même mécanisme qui, en 6.2.3, a laissé `ARG VERSION=1.3.0` en clair ; la seule différence est ce que tu as mis dans l'argument.
3. **La configuration contient le token d'exécution**, comme dans la scène du début : `REVISOR_TOKEN=curso-docker-token-de-mentira-en-env`.
4. **Et chaque conteneur le reçoit.** `printenv` l'affiche depuis l'intérieur sans que personne ne le lui ait passé à l'exécution : il vient de l'image.
5. **`docker build --check` l'avait signalé**, sans rien construire. Il vérifie le Dockerfile avec les règles de BuildKit et, pour chaque problème trouvé, il te donne le nom de la règle (`SecretsUsedInArgOrEnv`), un lien vers son explication, l'instruction qui l'a déclenchée (`ARG "TOKEN_MODULOS"`, `ENV "REVISOR_TOKEN"`), le fichier et la ligne, et l'extrait du Dockerfile avec une flèche `>>>`. Il se termine avec le code 1 quand il trouve quelque chose, ce qui permet d'arrêter un processus automatisé. La règle s'appuie sur le **nom** de la variable : la documentation dit qu'elle signale les clés qui « indiquent qu'elles contiennent des données sensibles », sans en donner la liste ([Docker, règle `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/)) ; ici, `TOKEN` l'a déclenchée, et dans l'Exercice 4 tu vas voir un nom en espagnol qui passe sans avertissement. C'est pourquoi c'est un filet de sécurité et non une garantie. Si tu veux qu'un `docker build` normal (pas seulement le `--check`) s'arrête au moindre avertissement, la directive `# check=error=true`, sur la ligne qui suit le `# syntax=`, le fait ([Docker, « Build checks »](https://docs.docker.com/build/checks/)). Les lignes qui commencent par `#0`… `#5` sont le travail préalable de BuildKit pour pouvoir lire le Dockerfile ; on peut les ignorer.
6. **Un `ARG` contamine chaque `RUN` qui le suit.** Le dernier bloc utilise une recette à deux étapes, écrite dans le script lui-même, où **aucun** `RUN` ne mentionne les arguments. Pourtant, le `RUN` de l'étape `base` porte `|1 TOKEN_MODULOS=…`, et celui de l'étape `hija`, qui dérive de `base` et a en plus déclaré `VERSION`, porte `|2 TOKEN_MODULOS=… VERSION=1.3.0`. BuildKit note dans chaque `RUN` tous les arguments déclarés dans son étape et dans l'étape dont elle dérive, qu'il les utilise ou non. Un token dans un `ARG` ne laisse pas une trace : il en laisse une pour chaque `RUN` ultérieur.

Ce qui compte dans cette expérience, c'est la façon de chercher, car c'est celle que tu vas utiliser sur tes propres images :

```bash
docker history --no-trunc --format '{{.CreatedBy}}' <imagen>
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>
```

Deux commandes, aucune permission spéciale, aucun outil supplémentaire. Quiconque peut télécharger ton image peut les exécuter. Et si un secret est déjà arrivé dans une image publiée, aucune commande ne peut réparer cela : le secret est considéré comme compromis et on le **change** dans le service qui l'a émis. Supprimer l'image du registre ne la dépublie pas des machines et des caches qui l'ont déjà téléchargée.

### 6.5 Le secret d'exécution : un fichier, pas une variable

#### 6.5.1 Pourquoi pas une variable d'environnement, même si elle arrive à l'exécution

Sortir le token du Dockerfile et le passer avec `-e REVISOR_TOKEN=...` à l'exécution vaut mieux que de le laisser dans l'image : il ne voyage plus vers le registre. Mais ce n'est pas suffisant, pour deux raisons que la documentation de Compose résume ainsi : les variables d'environnement « sont souvent accessibles à tous les processus, et il peut être difficile d'en suivre l'accès », et elles « peuvent aussi être affichées dans les journaux lors du débogage d'erreurs, à ton insu » ([Docker, « Secrets in Compose »](https://docs.docker.com/compose/how-tos/use-secrets/)). À cela s'ajoute un point propre à Docker : la configuration du **conteneur** conserve son environnement complet, et quiconque peut utiliser `docker inspect` sur cet ordinateur le lit. Et depuis la Leçon 1, tu sais qui peut utiliser `docker` : le groupe `docker`, qui équivaut à `root`. Il existe une trace de plus, qui n'a rien à voir avec Docker : si tu écris la valeur littérale dans le terminal (`-e REVISOR_TOKEN=abc…`, et c'est la même chose pour `--build-arg`), elle reste dans l'historique de ton *shell* et, pendant que la commande tourne, dans la liste des processus de ton ordinateur. C'est pourquoi les scripts de cette leçon n'écrivent jamais une valeur : ils la lisent depuis le fichier avec `$(cat secretos/…)`.

Le `revisor` accepte les deux façons, mais ne les traite pas de la même manière. `REVISOR_TOKEN` fonctionne et affiche un avertissement. `REVISOR_TOKEN_ARCHIVO` reçoit le **chemin** d'un fichier et y lit le token ; si les deux sont présentes, c'est le fichier qui l'emporte. La convention pour le chemin est `/run/secrets/<nom>` : c'est là que Compose place ses secrets et là que BuildKit place par défaut ceux de construction, comme tu le verras en 6.6.

#### 6.5.2 Les deux façons, et l'erreur que tu vas rencontrer en premier

Le script `fig06_06.sh` teste les deux façons et, entre les deux, déclenche l'erreur la plus fréquente de la bonne façon. Il utilise le fichier factice `secretos/revisor_token.txt`, qui contient `curso-docker-token-de-mentira-7f3a9c` :

```bash
#!/usr/bin/env bash
# fig06_06.sh — El secreto de EJECUCIÓN: por variable de entorno (se ve) y por
# archivo (no se ve), con el error de permisos que vas a encontrar primero.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
SERVICIOS='propio http://127.0.0.1:8080/salud'

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}

echo "== 1. El token por -e: funciona, pero queda a la vista"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  -e REVISOR_TOKEN="$(cat secretos/revisor_token.txt)" "$IMAGEN" >/dev/null
sleep 1
echo "-- lo que dice el revisor al arrancar:"
docker logs "$NOMBRE" 2>&1
echo "-- lo que ve cualquiera con docker inspect:"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep TOKEN
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El token por archivo, con permisos 600"
chmod 600 secretos/revisor_token.txt
stat -c '%a %n' secretos/revisor_token.txt
rc=0
timeout 20 docker run --name "$NOMBRE" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El token por archivo, con permisos 644 y montado de solo lectura"
chmod 644 secretos/revisor_token.txt
stat -c '%a %n' secretos/revisor_token.txt
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
echo "-- /salud no pide token:"
curl -s "http://127.0.0.1:$PUERTO/salud"; echo
echo "-- /api/estados sin token:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- /api/estados con el token:"
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" \
  "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'

echo
echo "== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR
docker inspect --format '{{range .Mounts}}{{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
```

```text
$ ./fig06_06.sh
== 1. El token por -e: funciona, pero queda a la vista
-- lo que dice el revisor al arrancar:
revisor: aviso: el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer; usa REVISOR_TOKEN_ARCHIVO
revisor 1.3.0 escuchando en :8080 (1 servicio(s))
-- lo que ve cualquiera con docker inspect:
REVISOR_TOKEN=curso-docker-token-de-mentira-7f3a9c

== 2. El token por archivo, con permisos 600
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]

== 3. El token por archivo, con permisos 644 y montado de solo lectura
644 secretos/revisor_token.txt
-- /salud no pide token:
{"estado":"vivo","version":"1.3.0"}

-- /api/estados sin token:
{"error":"falta el token o no es válido"}
 [401]
-- /api/estados con el token:
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_PUERTO=8080
/run/secrets/revisor_token (escribible: false)
```

#### 6.5.3 Lire l'exécution

1. **Par variable, ça fonctionne et ça se voit.** Le `revisor` démarre, mais la première chose qu'il écrit dans son journal est un avertissement : `el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer`. Et `docker inspect` le confirme, avec le token complet. Il n'a pas été nécessaire d'entrer dans le conteneur ni d'avoir l'image : il a suffi de pouvoir parler au daemon. (La version `1.3.0` dans le message de démarrage est celle que tu as gravée en 6.2.)
2. **Par fichier, avec `600`, il ne démarre pas.** C'est l'erreur de la leçon. Le fichier sur ton ordinateur appartient à ton utilisateur et a les permissions `600` : seul son propriétaire peut le lire. Une fois monté, le conteneur voit **le même fichier**, avec le même propriétaire (un numéro d'utilisateur) et les mêmes permissions ; un montage ne copie ni ne traduit rien. Et à l'intérieur du conteneur, le `revisor` tourne en tant qu'utilisateur `65532`, qui n'est pas le propriétaire. Le noyau fait ce qu'il ferait avec n'importe quel autre utilisateur de ton ordinateur : `permission denied`. C'est la conséquence directe de quelque chose que tu as vu dans la Leçon 0 : avec l'installation normale de la Leçon 1, les numéros d'utilisateur à l'intérieur et à l'extérieur sont les mêmes. (Avec Docker sans `root` ou avec le remappage des utilisateurs, le numéro intérieur est traduit en un autre à l'extérieur, et le diagnostic avec `ls -ln` change.) Remarque aussi que le `revisor` **ne démarre pas à moitié** : si tu lui as dit qu'il existe un fichier de token et qu'il ne peut pas le lire, il préfère mourir avec le code 1 plutôt que de rester à l'écoute sans protection.
3. **Avec `644`, ça fonctionne.** `644` donne la lecture à tout le monde ; l'utilisateur `65532` peut maintenant le lire. `/salud` répond sans token (c'est pour que le contrôle de santé puisse se faire, Leçon 7), et `/api/estados` répond `401` sans token et le tableau avec. La sortie contient une ligne vide après le JSON de `/salud` : c'est l'`echo` du script, qui ajoute un saut de ligne à celui que le `revisor` a déjà envoyé. Et l'ordre des variables dans le `docker inspect` du bloc 4 peut varier d'une exécution à l'autre ; ce qui compte, c'est lesquelles sont présentes.
4. **`docker inspect` ne montre plus le secret.** Il montre `REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token`, un chemin, qui ne sert à rien sans le fichier. Et le montage apparaît comme `escribible: false` : l'option `readonly` empêche le conteneur de modifier le fichier de l'ordinateur, même s'il en avait la permission.

#### 6.5.4 Un `644`, n'est-ce pas dangereux ?

C'est la bonne question, et la réponse honnête est « cela dépend de qui d'autre utilise ton ordinateur ». `644` signifie que **n'importe quel utilisateur de ton ordinateur** peut lire le fichier. Sur un ordinateur personnel où tu es seul, le risque est faible, et c'est pourquoi le cours l'utilise. Sur un serveur partagé, cela ne convient pas. Il existe deux meilleures corrections, et toutes deux s'attaquent à la même cause (le propriétaire, pas la permission) :

- **Que le fichier appartienne à l'utilisateur du conteneur** : `sudo chown 65532:65532 secretos/revisor_token.txt` et le laisser en `600` ou `400`. Ainsi, seuls cet utilisateur et `root` peuvent le lire. Le prix à payer est que ton utilisateur ne peut plus le lire sans `sudo`.
- **Qu'un orchestrateur le fournisse, avec une réserve importante.** Les secrets de Compose (Leçon 9) placent le fichier dans `/run/secrets/`, mais quand le secret provient d'un **fichier**, Compose le monte tel quel, comme le `--mount` de cette leçon : le propriétaire et les permissions restent ceux du fichier de ton ordinateur. Sa référence le dit : avec un fichier comme source, Compose utilise en coulisse un montage qui ne permet pas de changer le propriétaire, et les attributs `uid`, `gid` et `mode` « sont ignorés en silence » ; ils ne fonctionnent que lorsque le secret provient d'une variable d'environnement ([référence des services de Compose](https://docs.docker.com/reference/compose-file/services/)). Nous l'avons mesuré avec Compose v5.0.2 : le fichier en `600`, avec `uid: "65532"`, `gid: "65532"` et `mode: 0400` déclarés dans le `compose.yaml`, a donné exactement le même `permission denied` qu'en 6.5.2, et avec `644` il a démarré. C'est pourquoi la Leçon 9 utilise aussi `644`. Kubernetes, lui, monte ses secrets avec les permissions que tu déclares, mais cela relève du cours de Kubernetes.

Ce qui n'est **pas** une correction : passer le `USER` de l'image à `root` « pour qu'il puisse lire ». Cela échange un problème de permissions contre un problème de sécurité, et défait le travail des leçons 3 et 5.

### 6.6 Le secret de construction : un montage qui dure le temps d'un `RUN`

#### 6.6.1 Quand en a-t-on besoin

Parfois, le secret ne sert pas à exécuter, mais à **construire** : des identifiants pour télécharger des modules Go privés, des paquets d'un dépôt privé npm ou Maven, un certificat pour accéder à un serveur interne de dépendances. Le `revisor` n'a pas de dépendances externes, il n'en a donc pas besoin aujourd'hui, mais le modèle reste dans son Dockerfile pour le jour où il en aura besoin.

BuildKit fournit un outil conçu pour cela : le **montage de secret**. Dans le Dockerfile, un `RUN` demande le secret avec `--mount=type=secret,id=<nom>` ; à la construction, tu le lui fournis avec `docker build --secret id=<nom>,src=<fichier>` (ou `env=<VARIABLE>`, si tu l'as dans une variable de ton terminal). D'après la documentation, le montage rend le secret disponible « temporairement à l'intérieur du conteneur de construction, pendant l'instruction » ([Docker, « Build secrets »](https://docs.docker.com/build/building/secrets/)). Les options qu'utilise le `revisor`, avec leurs valeurs par défaut d'après la [référence du Dockerfile](https://docs.docker.com/reference/dockerfile/) :

| Option | Ce qu'elle fait | Par défaut |
|---|---|---|
| `id` | le nom sous lequel `--secret` le fournit | le nom du fichier de `target` |
| `target` | l'endroit où le fichier apparaît pendant le `RUN` | `/run/secrets/<id>` |
| `required` | si elle vaut `true`, l'instruction échoue quand on ne lui fournit pas le secret | `false` |
| `mode` | permissions du fichier | `0400` |
| `uid`, `gid` | propriétaire du fichier | `0` (`root`) |
| `env` | au lieu d'un fichier (ou en plus), place le secret dans une variable d'environnement qui n'existe **que pendant ce `RUN`** | sans valeur : fichier uniquement |

Attention aux deux `env`. Dans `docker build --secret id=x,env=MI_VAR`, `env` indique **depuis quelle variable de ton terminal** le secret est lu. Dans `--mount=type=secret,id=x,env=TOKEN`, il indique **sous quel nom le `RUN` le voit**. Cette seconde variable n'est pas un `ENV` : elle naît et meurt avec l'instruction, et ne reste ni dans l'image ni dans l'historique. C'est la forme qu'utilise la documentation elle-même dans l'exemple correct de la règle `SecretsUsedInArgOrEnv`, et celle qui convient quand l'outil lit son identifiant dans une variable et non dans un fichier. Une « variable d'environnement » n'est pas mauvaise en soi ; ce qui est mauvais, c'est qu'elle reste écrite là où l'image voyage ou là où n'importe qui peut la lire.

Le `revisor` utilise `target=/root/.netrc` parce que c'est là que Go cherche ses identifiants, et `required=false` parce que ce cours n'a pas de modules privés : ainsi, sa construction fonctionne avec et sans `--secret`.

#### 6.6.2 Le voir apparaître et disparaître

Pour voir le montage en action, il faut un `RUN` qui fasse quelque chose de visible avec le secret. Ce Dockerfile de démonstration le reçoit, compte ses octets et liste le fichier, **sans afficher la valeur**. Il utilise `required=true` pour que tu puisses voir l'erreur qui survient quand on l'oublie :

```dockerfile
# syntax=docker/dockerfile:1
# fig06_07.Dockerfile — Lección 6: dónde vive un secreto de construcción.
# Solo para mirar: un RUN que recibe el secreto, lo cuenta y no lo imprime.
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
RUN --mount=type=secret,id=netrc,target=/root/.netrc,required=true \
    echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes" \
 && ls -l /root/.netrc
```

Le script `fig06_08.sh` le construit deux fois (sans et avec le secret), regarde ce qui est resté et finit en construisant le vrai `revisor` avec `--secret` :

```bash
#!/usr/bin/env bash
# fig06_08.sh — El secreto de CONSTRUCCIÓN con --secret: está durante el RUN y
# en ningún otro lado. Primero el error de olvidarlo; después, el revisor real.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
DEMO="${PREFIJO}revisor:fig06-demo-secreto"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$DEMO" "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp "$AQUI/fig06_07.Dockerfile" "$TRABAJO/Dockerfile.demo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Olvidar --secret cuando el Dockerfile dice required=true"
rc=0
docker build --no-cache --progress=plain -f Dockerfile.demo -t "$DEMO" . > salida-1.txt 2>&1 || rc=$?
grep -E '^ERROR' salida-1.txt
echo "[código de salida: $rc]"

echo
echo "== 2. Con --secret: el RUN lo recibe"
docker build --no-cache --progress=plain --secret id=netrc,src=secretos/token_modulos.txt \
  -f Dockerfile.demo -t "$DEMO" . 2>&1 | grep -E 'durante el RUN|/root/.netrc$' | grep -v '^#[0-9]* \[' 

echo
echo "== 3. Terminado el RUN, ¿qué quedó en /root?"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$DEMO" ls -lA /root

echo
echo "== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | head -1
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | grep -c 'modulos-de-mentira' || true

echo
echo "== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)"
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt \
  -t "$IMAGEN" . >/dev/null && echo "construida"
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$IMAGEN" | grep -c 'modulos-de-mentira' || true
```

```text
$ ./fig06_08.sh
== 1. Olvidar --secret cuando el Dockerfile dice required=true
ERROR: failed to build: failed to solve: secret netrc: not found
[código de salida: 1]

== 2. Con --secret: el RUN lo recibe
#7 0.092 durante el RUN: /root/.netrc existe y mide 37 bytes
#7 0.093 -r-------- 1 root root 37 Oct 21 09:17 /root/.netrc

== 3. Terminado el RUN, ¿qué quedó en /root?
total 8
-rw-r--r-- 1 root root 607 Jul 17 17:05 .bashrc
-rw-r--r-- 1 root root 132 Jul 17 17:05 .profile

== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción
RUN /bin/sh -c echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes"  && ls -l /root/.netrc # buildkit
-- renglones del historial con el valor del secreto:
0

== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)
construida
-- renglones del historial con el valor del secreto:
0
```

Les nouvelles options du script : `--no-cache` oblige à exécuter le `RUN` même s'il y a du cache, pour qu'il affiche quelque chose ; `--progress=plain` affiche la sortie de chaque étape en texte brut, au lieu de la vue qui se redessine dans le terminal. Chaque ligne de cette sortie commence par le numéro de l'étape (`#7`) et les secondes écoulées depuis son début ; ces nombres et la date du fichier changent à chaque exécution (la date est à l'heure de la machine virtuelle, qui est celle du méridien de Greenwich). Les `|| true` de la fin sont là parce que `grep -c` se termine avec le code 1 quand il compte zéro, et ici le zéro est justement ce que nous voulons voir.

Et la sortie :

1. **Oublier le secret** avec `required=true` arrête la construction avec un message court : `secret netrc: not found`. C'est ce que tu veux quand le secret est indispensable : une erreur claire à la construction, et non une compilation qui échoue trois étapes plus loin avec un « non autorisé » que personne ne comprend. Le `revisor` utilise `required=false` parce que, pour lui, le secret est facultatif.
2. **Avec `--secret`, le `RUN` le voit** : un fichier de 37 octets (36 caractères de la valeur factice plus le saut de ligne), avec les permissions `-r--------` (le `0400` par défaut) et le propriétaire `root`, l'utilisateur sous lequel tourne ce `RUN`.
3. **Une fois le `RUN` terminé, il n'est plus là.** `/root` ne contient que les fichiers de la base. Contrairement au `rm` de 6.4, ici personne n'a eu à supprimer quoi que ce soit : le fichier n'a jamais été écrit dans la couche ; il a été monté par-dessus, comme un prêt, et restitué à la fin de l'instruction.
4. **L'historique note l'instruction et rien d'autre.** Ni la valeur, ni même les options `--mount`. Le nombre de lignes contenant la valeur du secret est `0`.
5. **Le vrai `revisor`**, construit avec son secret facultatif : `0` également.

Mets cette sortie à côté de celle de 6.4. Avec `ARG`, la valeur est restée écrite alors que le fichier avait été supprimé. Avec `--secret`, la valeur n'a jamais été écrite.

#### 6.6.3 Les cinq chemins, réunis

Tu as vu chaque mécanisme fonctionner séparément. Ce tableau les réunit, car la question que tu vas te poser dans ton propre projet est toujours la même : par où entre cette donnée, et où reste-t-elle écrite ?

| Mécanisme | Quand il existe | Comment on le fournit | Où il reste écrit | Convient-il aux secrets ? |
|---|---|---|---|---|
| `ARG` | uniquement à la construction | `docker build --build-arg` | dans l'historique, sur sa propre ligne et dans chaque `RUN` ultérieur de l'étape (6.4) ; dans la provenance en mode `max` (6.7) | non |
| `ENV` | à la construction et dans chaque conteneur | le Dockerfile ; on le change avec `-e` | dans la configuration de l'image (`docker image inspect`) | non |
| `-e` / `--env-file` | à l'exécution | `docker run` | dans la configuration du conteneur (`docker inspect`) | non |
| `--mount=type=secret` | uniquement pendant un `RUN` | `docker build --secret` | nulle part (6.6.2) | oui, de construction |
| fichier dans `/run/secrets/` | à l'exécution | montage en lecture seule | `docker inspect` montre le chemin, pas la valeur (6.5) | oui, d'exécution |

Les trois premières lignes sont pour la configuration ; les deux dernières, pour les secrets. Si une donnée sensible se trouve dans l'une des trois premières, elle est déjà écrite quelque part où une autre personne peut la lire.

#### 6.6.4 Pourquoi il ne se glisse pas par le cache

Un doute raisonnable : si le secret change, le cache de BuildKit relance-t-il le `RUN` ? Non. La documentation le dit ainsi : « le contenu des build secrets ne fait pas partie du cache », et « changer la valeur d'un secret n'invalide pas le cache » ; ce qui compte, ce sont ses propriétés, comme l'`id` et le chemin du montage ([Docker, « Build cache invalidation »](https://docs.docker.com/build/cache/invalidation/)). La documentation n'explique pas pourquoi ; l'important en pratique est de savoir que la valeur ne compte pas pour le cache, et que l'`id` et le chemin du montage comptent. Si tu changes le secret et que tu as besoin que le `RUN` se répète, la documentation propose de passer en plus un argument de construction quelconque que tu changes en même temps (les arguments, eux, invalident le cache), ou tu peux le forcer avec `--no-cache`, comme l'a fait le script. C'est un petit inconvénient en échange du fait que la valeur n'apparaît dans aucun journal de la construction.

### 6.7 Ce que tu trouveras dans les anciens tutoriels

- **`ARG` pour des tokens npm, GitHub ou d'un registre privé**, avec le commentaire « ne t'inquiète pas, on le supprime à la fin du `RUN` ». Tu as vu en 6.4 que la valeur reste dans l'historique. Les montages de secret existent depuis que BuildKit les a introduits, et ce sont la voie documentée.
- **Construire en plusieurs étapes « pour que l'`ARG` n'arrive pas dans l'image finale ».** Il est vrai que l'historique de l'image livrée ne montre que l'étape finale (tu l'as vu en 6.2.3), mais les valeurs peuvent aussi rester dans les **attestations de provenance**, l'enregistrement de la façon dont l'image a été construite, que la Leçon 10 lui attache. En mode minimal, celui qui est utilisé par défaut, les valeurs des arguments ne sont pas incluses ; avec `--provenance=mode=max`, celui qu'utilise la Leçon 10, la documentation avertit que ce mode « expose les valeurs des arguments de construction », de toutes les étapes ([Docker, provenance SLSA](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). Cela aide, mais ce n'est pas la solution.
- **`docker run -e PASSWORD=...` dans les instructions d'une image.** Beaucoup d'images populaires acceptent des secrets par variable parce que c'est le plus simple à documenter, et beaucoup proposent aussi une variante `_FILE` qui lit depuis un fichier, comme le `REVISOR_TOKEN_ARCHIVO` du `revisor`. Quand la variante par fichier existe, utilise-la.
- **« Écraser » (squash) les couches pour faire disparaître les secrets.** Certains vieux guides proposent de fusionner toutes les couches en une seule. Même si cela retirait un fichier d'une couche intermédiaire, cela ne touche pas la configuration de l'image : un `ENV` contenant un token y reste, comme tu l'as vu en 6.4. La voie actuelle est que le secret n'entre jamais.

## L'erreur que tu vas voir

Cette leçon comporte une erreur principale et deux secondaires. Les trois sont déjà apparues.

**L'erreur principale : le fichier du secret que le conteneur ne peut pas lire.** C'est celle de `fig06_06.sh` :

```text
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]
```

Elle se lit de droite à gauche. `permission denied`, c'est le noyau qui le dit : le processus n'a pas la permission d'ouvrir ce fichier. `open /run/secrets/revisor_token` indique quel fichier, avec le chemin **à l'intérieur** du conteneur ; le chemin sur l'ordinateur est celui du montage. Et `leyendo el token de REVISOR_TOKEN_ARCHIVO` est ajouté par le `revisor` pour que tu saches ce qu'il était en train de faire. La question qui résout le problème est « qui est le propriétaire du fichier, et sous quel utilisateur tourne le conteneur ? ». La première réponse est donnée par `ls -ln` sur ton ordinateur ; la seconde, par `docker inspect --format '{{.Config.User}}'` sur l'image (`65532:65532`). S'ils ne coïncident pas et que les permissions sont `600`, voilà le résultat. Corrections : `644` sur un ordinateur personnel, ou le bon propriétaire (6.5.4). Ce qui n'est pas une correction : exécuter en tant que `root`.

**L'erreur secondaire : le secret de construction qui n'est pas arrivé.**

```text
ERROR: failed to build: failed to solve: secret netrc: not found
```

Tu la vois quand le Dockerfile demande un secret avec `required=true` et que le `docker build` ne contient pas `--secret id=netrc,...`. La correction consiste à l'ajouter. Si tu as bien écrit `--secret` mais avec un autre `id` (par exemple, `id=nettrc`), tu es dans le même cas : le `RUN` a demandé le secret `netrc` et personne ne le lui a fourni, alors vérifie que les deux `id` coïncident lettre pour lettre. Avec `required=false`, comme dans le `revisor`, il n'y a pas d'erreur : le `RUN` s'exécute sans le fichier.

**L'avertissement que tu dois traiter comme une erreur : `SecretsUsedInArgOrEnv`.**

```text
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
```

C'est un avertissement, pas une erreur : un `docker build` normal l'affiche et construit quand même. C'est pourquoi il est facile de l'ignorer. Avec `docker build --check`, le résultat est le code 1, et c'est ainsi qu'il convient de l'exécuter : avant chaque construction destinée à être publiée. N'oublie pas qu'il ne regarde que les noms : l'absence d'avertissement ne prouve pas qu'il n'y a pas de secrets.

## L'habitude de sécurité de la leçon

**Les secrets ne passent ni par `ARG` ni par `ENV`, et on vérifie avec `docker history` et `docker inspect` qu'ils ne sont pas restés.** L'habitude a deux moitiés, et c'est la seconde qu'on oublie. La première est la règle : le secret de construction entre avec `--secret`, celui d'exécution sous forme de fichier en lecture seule dans `/run/secrets/`. La seconde est la vérification : avant de publier une image, tu fouilles son historique complet et sa configuration, avec les deux commandes de 6.4.3, et tu ne trouves rien. Cette habitude évite l'accident de la scène du début (un token publié sur un registre auquel ont accès plus de personnes que tu ne le crois) et un autre, plus silencieux : un token passé par `-e` qui finit dans un journal d'erreurs, sur l'écran partagé d'une visioconférence ou dans la sortie d'un `docker inspect` que quelqu'un a collée dans un chat pour demander de l'aide.

## Ce qui se fait de travers

**Reconstruire l'image pour changer d'environnement.** Si l'image de production est différente de celle de test, celle de production, personne ne l'a testée. Une image, plusieurs configurations.

**Mettre la configuration d'un environnement dans l'`ENV` du Dockerfile.** `ENV` sert aux valeurs par défaut valables partout, comme le port. Une liste de services de test dans l'`ENV` oblige à reconstruire pour la production, et reste dans l'image pour toujours.

**Passer un secret par `ARG` et le supprimer « dans le même `RUN` ».** Le fichier disparaît ; la valeur reste dans l'historique (6.4). La prudence de tout faire dans un seul `RUN` protège contre une autre erreur que celle qui se produit réellement.

**Passer le token par `-e` parce qu'« il n'est plus dans l'image ».** Il ne voyage plus vers le registre, mais il reste dans la configuration du conteneur, visible par quiconque a accès à `docker`, et dans l'environnement de tous les processus enfants.

**Corriger `permission denied` avec `--user root` ou `chmod 777`.** Le premier défait le durcissement (hardening) de l'image ; le second rend le fichier modifiable par tous les utilisateurs de l'ordinateur. Le problème est le propriétaire ; corrige-le à cet endroit.

**Versionner le dossier des secrets dans le dépôt.** Ce cours le fait exprès et avec des valeurs factices. Ton projet, non : `secretos/` va dans `.gitignore` et dans `.dockerignore` dès le premier jour.

**Se fier au fait que `docker build --check` n'a rien dit.** Il vérifie les noms, pas les valeurs. Une variable `X` contenant un token passe sans encombre.

**Copier le secret monté vers un autre chemin.** Le montage ne laisse pas de trace, mais ce que le `RUN` écrit, si : si un `cp /run/secrets/…` ou un outil enregistre l'identifiant dans sa propre configuration (un `.npmrc`, un fichier d'identifiants), cette copie reste dans la couche comme n'importe quel autre fichier. Le secret se lit dans le `RUN` et ne s'écrit nulle part.

**Afficher un secret « juste pour déboguer ».** Un `RUN cat /run/secrets/...` ou un `echo $TOKEN` laisse la valeur dans la sortie de la construction ou dans les journaux du conteneur, qui sont conservés et partagés. Pour savoir si un secret est arrivé, compte ses octets, comme l'a fait `fig06_07.Dockerfile`.

## Exercices

Fais-les dans l'ordre. Avant d'exécuter chacun, écris dans ton [journal de bord](bitacora.md) ce que tu penses qu'il va se passer ; comparer ensuite représente la moitié de l'apprentissage. À la fin, supprime ce que tu as créé : tout porte le préfixe `curso-docker-`.

### Exercice 1 — Code, configuration ou secret ?

Classe chaque donnée dans l'une des trois catégories de 6.1.1 et dis où elle doit vivre (à l'intérieur de l'image, dans `ENV` comme valeur par défaut, par `-e`/`--env-file`, ou sous forme de fichier dans `/run/secrets/`) :

1. La version `1.3.0` du `revisor`.
2. La liste des services que surveille l'environnement de test.
3. Le token qui protège `/api/estados` en production.
4. Le port `8080`.
5. Le chemin où le `revisor` enregistre son rapport (`REVISOR_REPORTE`).
6. Un identifiant pour télécharger des modules Go privés à la compilation.

### Exercice 2 — Sans `--build-arg` (projet)

Dans ton dossier `~/curso-docker/revisor`, avec le Dockerfile de cette leçon, construis une image **sans** `--build-arg` et avec le tag `curso-docker-revisor:sin-version`. Avant de construire, prédis ce que vont indiquer ces trois éléments, puis vérifie-le :

1. `docker run --rm curso-docker-revisor:sin-version version`
2. Le label `org.opencontainers.image.version` de l'image.
3. La ligne `ARG` de son `docker history`.

L'exercice est autocorrectif : si tes trois prédictions coïncident avec ce que tu vois, tu as compris d'où vient la valeur d'un `ARG`. À la fin, `docker rmi curso-docker-revisor:sin-version`.

### Exercice 3 — Les guillemets du fichier de variables

Crée un fichier `comillas.env` avec cette unique ligne, guillemets compris :

```text
REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"
```

Avant de l'exécuter, prédis : le `revisor` démarre-t-il ou refuse-t-il ? S'il démarre, que va indiquer son tableau ? Ensuite, exécute-le avec `docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --env-file comillas.env curso-docker-revisor:1.3.0`, demande le tableau avec `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` et lis avec `docker inspect` quelle valeur il a reçue exactement. Corrige le fichier pour que le service soit `OK`. À la fin, `docker rm -f curso-docker-revisor`.

### Exercice 4 — Trouve la fuite

Un collègue te passe cette recette et jure qu'elle « ne laisse rien parce que le secret est supprimé ». Sans la construire, dis **où** resterait chacune des deux valeurs sensibles et avec quelle commande tu la trouverais. Ensuite, réécris la partie du secret de construction avec un montage de secret, et dis quelle option de `docker build` le fournit :

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
ARG CLAVE_REGISTRO
ENV API_KEY=valor-de-mentira-para-el-ejercicio
RUN echo "${CLAVE_REGISTRO}" > /tmp/clave && go env -w GOPRIVATE=ejemplo.invalid && rm /tmp/clave
```

Question bonus : laquelle des deux variables `docker build --check` aurait-il signalée, et laquelle non ? Réfléchis à la façon dont la règle décide.

## Solutions

### Solution 1

1. **Code.** À l'intérieur de l'image : gravée dans le binaire avec `-X main.version` et dans le label OCI. Elle ne change pas d'un environnement à l'autre.
2. **Configuration.** Par `-e` ou `--env-file` à l'exécution. Elle change d'un environnement à l'autre et n'est pas secrète.
3. **Secret.** Sous forme de fichier en lecture seule dans `/run/secrets/revisor_token`, avec `REVISOR_TOKEN_ARCHIVO` pointant vers lui. Jamais dans `ENV` ni par `-e`.
4. **Configuration avec valeur par défaut.** `ENV REVISOR_PUERTO=8080` dans l'image ; n'importe quel environnement la change avec `-e`.
5. **Configuration.** Par `-e` ou `--env-file`. (La Leçon 8 lui donne une valeur par défaut à l'intérieur de l'image, quand il existera un dossier `/datos` préparé pour cela.)
6. **Secret de construction.** Avec `--mount=type=secret` dans le `RUN` qui en a besoin, fourni avec `docker build --secret`. Jamais dans `ARG`.

### Solution 2

Mesuré avec le même ordinateur et la même version de Docker que la leçon :

1. `desarrollo`. Sans `--build-arg`, `VERSION` prend la valeur par défaut de sa déclaration, `ARG VERSION=desarrollo`, et c'est ce que `-X main.version` grave dans le binaire.
2. `desarrollo` également, parce que l'étape `final` déclare son propre `ARG VERSION=desarrollo` et que le label l'utilise.
3. `ARG VERSION=desarrollo`. L'historique note la valeur qu'avait l'argument **lors de cette construction**, que ce soit celle de `--build-arg` ou celle de la déclaration. C'est exactement pour cela qu'un secret ne peut pas y aller.

### Solution 3

Mesuré avec le même ordinateur et la même version de Docker que la leçon. Le `revisor` **démarre** (`revisor 1.3.0 escuchando en :8080 (1 servicio(s))`), mais le tableau indique :

```text
SERVICIO  ESTADO    TIEMPO  DETALLE
"propio   FALLA        1ms  codigo 404
```

La durée change à chaque exécution. Les guillemets sont arrivés comme partie de la valeur : `docker inspect` montre `REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"`. Le `revisor` a lu un service qui s'appelle `"propio` (avec le guillemet) et dont l'adresse est `http://127.0.0.1:8080/salud"` (avec le guillemet à la fin) ; ce chemin n'existe pas et le serveur renvoie `404`. C'est le pire type d'erreur de configuration : elle n'empêche pas le démarrage, elle donne seulement un résultat faux. La correction consiste à retirer les guillemets : dans un fichier de `--env-file`, tout ce qui suit le `=` est la valeur, telle quelle. (Dans le terminal, en revanche, on met des guillemets, car c'est le *shell* qui les interprète et ils n'arrivent pas au conteneur. Et dans l'`env_file` de Compose, Leçon 9, on peut aussi les utiliser, car ce lecteur-là les retire.)

### Solution 4

- `CLAVE_REGISTRO` reste **dans l'historique**, sur la ligne du `RUN`, sous la forme `|1 CLAVE_REGISTRO=<valor> /bin/sh -c ...`. On la trouve avec `docker history --no-trunc --format '{{.CreatedBy}}' <imagen>`. Le `rm /tmp/clave` ne l'empêche pas, comme en 6.4.
- `API_KEY` reste **dans la configuration de l'image** et dans l'environnement de chaque conteneur. On la trouve avec `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>`.

La réécriture du secret de construction :

```dockerfile
RUN --mount=type=secret,id=clave_registro,target=/root/.netrc,required=true \
    go env -w GOPRIVATE=ejemplo.invalid && go mod download
```

Ici, le secret est **utilisé** : `go mod download` télécharge les modules privés et, pour accéder au serveur, lit l'identifiant dans `/root/.netrc`, qui n'existe que pendant ce `RUN` (le fichier de secret contiendrait la ligne `machine ejemplo.invalid password …`, comme en 6.4). Si l'outil dont tu as besoin lit son identifiant dans une variable et non dans un fichier, tu remplaces `target=…` par `env=CLAVE_REGISTRO`, et la variable n'existe que pendant ce `RUN` (6.6.1). On le fournit avec `docker build --secret id=clave_registro,src=<fichier> .` (ou `env=<VARIABLE>` de ton terminal). Pas d'`ARG`, pas de fichier à supprimer, et aucune ligne de l'historique avec la valeur. Et `API_KEY` sort du Dockerfile : si le programme en a besoin à l'exécution, elle arrive sous forme de fichier.

Question bonus : la règle décide selon le **nom** de la variable. Mesuré avec le même ordinateur et la même version de Docker que la leçon, `docker build --check .` sur la recette se termine avec le code 1 et un seul avertissement :

```text
Check complete, 1 warning has been found!
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "API_KEY")
```

`API_KEY` a le type de nom que la règle recherche. `CLAVE_REGISTRO`, en espagnol, passe sans avertissement, et c'est justement la valeur qui finit dans l'historique. La leçon qui compte : l'avertissement est un filet, pas un cadenas.

## Comment je sais que j'ai réussi

Coche chaque point uniquement si tu sais le faire **sans revenir au texte** :

- [ ] Dans ton dossier, `docker run --rm curso-docker-revisor:1.3.0 version` affiche `1.3.0`, et `docker image inspect` montre le label `org.opencontainers.image.version = 1.3.0`.
- [ ] `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.3.0` montre `REVISOR_PUERTO=8080` et aucune autre variable `REVISOR_*`.
- [ ] Tu exécutes la même image avec deux listes de services différentes, l'une par `-e` et l'autre par `--env-file`, sans reconstruire.
- [ ] Tu expliques en une minute la différence entre `ARG` et `ENV` en utilisant les mots *construire*, *exécuter*, *historique* et *configuration*.
- [ ] Tu construis `Dockerfile.malo` et tu trouves les deux secrets factices avec deux commandes ; et `docker build --check -f Dockerfile.malo .` te donne les deux avertissements et le code 1.
- [ ] Le `revisor` démarre avec `REVISOR_TOKEN_ARCHIVO` et un fichier monté en lecture seule ; `/api/estados` répond `401` sans token et le tableau avec ; et le `docker inspect` du conteneur ne montre pas la valeur du token.
- [ ] Tu provoques le `permission denied` avec `chmod 600` et tu expliques pourquoi il se produit en utilisant les mots *propriétaire* et `65532`.
- [ ] `docker history --no-trunc --format '{{.CreatedBy}}' curso-docker-revisor:1.3.0 | grep -c 'modulos-de-mentira'` donne `0` après avoir construit avec `--secret`.
- [ ] Tu exécutes les scripts de [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos) et tes sorties coïncident avec celles de cette leçon, à l'exception des durées, des numéros d'étape de la construction, de la date du fichier de `fig06_08.sh`, de l'ordre des variables dans `docker inspect` et de l'architecture dans l'historique. Et à la fin, `docker ps -a --filter name=curso-docker-` n'affiche aucun conteneur de cette leçon.

## Résumé

Réponds sans regarder la leçon :

1. Qu'est-ce que la configuration, selon *The Twelve-Factor App*, et quel test propose-t-il pour savoir si tu l'as bien séparée ?
2. Quand un `ARG` existe-t-il, et quand un `ENV` ? Où la valeur de chacun reste-t-elle écrite ?
3. Pourquoi le Dockerfile du `revisor` déclare-t-il `ARG VERSION` deux fois ?
4. Quelle différence y a-t-il entre `-e` et `--env-file`, et qu'arrive-t-il aux guillemets dans un fichier de variables ?
5. Pourquoi supprimer un fichier dans le même `RUN` ne protège-t-il pas un secret arrivé par `ARG` ?
6. Que vérifie `docker build --check` avec la règle `SecretsUsedInArgOrEnv`, et que ne peut-il pas voir ?
7. Pourquoi un token passé par `-e` reste-t-il une mauvaise idée même s'il n'est pas dans l'image ?
8. Pourquoi un fichier de secret avec les permissions `600` donne-t-il `permission denied` à l'intérieur du conteneur, et quelles sont les bonnes corrections ?
9. Que fait `--mount=type=secret`, où le fichier apparaît-il par défaut et que signifie `required` ?

## Sources

Toutes consultées le 21 octobre 2026.

- [The Twelve-Factor App, « Config »](https://12factor.net/config) : la définition de la configuration comme ce qui varie entre les déploiements, le test consistant à publier le code en open source et la configuration dans des variables d'environnement.
- [Docker, « Build variables »](https://docs.docker.com/build/building/variables/) : `ARG` contre `ENV`, le fait que les arguments n'arrivent pas dans les conteneurs mais peuvent persister dans les métadonnées, l'historique et les attestations, la portée par étape et l'avertissement sur les secrets.
- [Docker, « Build secrets »](https://docs.docker.com/build/building/secrets/) : pourquoi les arguments et les variables d'environnement ne conviennent pas aux secrets, le montage de secret, son chemin par défaut `/run/secrets/<id>`, `target` et les formes `src` et `env` de `--secret`.
- [Référence du Dockerfile](https://docs.docker.com/reference/dockerfile/) : les options de `RUN --mount=type=secret` (`id`, `target`, `required`, `mode`) et leurs valeurs par défaut, `LABEL` et sa lecture avec `docker image inspect`, et le fait que `ENV` persiste dans les conteneurs et se modifie avec `docker run --env`.
- [Docker, « Build cache invalidation »](https://docs.docker.com/build/cache/invalidation/) : le fait que le contenu d'un secret ne fait pas partie du cache et comment forcer la répétition de l'étape.
- [Référence des services de Compose](https://docs.docker.com/reference/compose-file/services/) : le fait qu'avec un fichier comme source, les attributs `uid`, `gid` et `mode` d'un secret sont ignorés, et la façon dont l'`env_file` lit les guillemets.
- [Docker, provenance SLSA](https://docs.docker.com/build/metadata/attestations/slsa-provenance/) : le fait que le mode minimal, celui par défaut, n'inclut pas les valeurs des arguments et que le mode `max` les expose.
- [Docker, « Build checks »](https://docs.docker.com/build/checks/) : la directive `# check=error=true`.
- [Docker, règle `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/) : ce que signale la règle et l'exemple correct avec des montages de secret.
- [Référence de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/) : `-e`, `-e` sans valeur et le format de `--env-file` avec ses commentaires.
- [Docker, « Secrets in Compose »](https://docs.docker.com/compose/how-tos/use-secrets/) : pourquoi les variables d'environnement ne sont pas un bon endroit pour les secrets et le chemin `/run/secrets/<nom>`.
- [OCI Image Specification, annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md) : les définitions de `org.opencontainers.image.title`, `.version` et `.source`.
- [cmd/link](https://pkg.go.dev/cmd/link) : l'option `-X` de l'éditeur de liens de Go, qui fixe la valeur d'une variable texte à la compilation.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions et les dates de « À propos des exécutions ».
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **argument de construction** (`ARG`) | variable qui n'existe que pendant la construction de l'image ; on la modifie avec `--build-arg` et sa valeur reste dans l'historique |
| **configuration** | ce qui change d'un environnement à l'autre ; arrive à l'exécution, ne va pas dans l'image |
| **label** (`LABEL`) | paire nom-valeur attachée à l'image comme métadonnée ; se lit avec `docker image inspect` |
| **labels OCI** | labels aux noms standard (`org.opencontainers.image.*`) que n'importe quel outil comprend |
| **historique** (*history*) | la liste des instructions qui ont créé l'image, avec leurs valeurs ; se lit avec `docker history` |
| **montage de secret** | fichier que BuildKit met à la disposition d'un seul `RUN` et qui ne reste dans aucune couche |
| **secret** | configuration que quelqu'un peut utiliser contre toi si elle fuit : tokens, mots de passe, identifiants |
| **secret de construction** (*build secret*) | celui dont on a besoin pour construire l'image ; se fournit avec `docker build --secret` |
| **secret d'exécution** | celui dont le programme a besoin à l'exécution ; se fournit sous forme de fichier dans `/run/secrets/` |
| **variable d'environnement** (`ENV`, `-e`) | paire nom-valeur que reçoit un processus au démarrage ; visible dans `docker inspect` |

---

**Suivante :** [Leçon 7 — Contrôle de santé et cycle de vie](07-salud-y-ciclo-de-vida.md)
