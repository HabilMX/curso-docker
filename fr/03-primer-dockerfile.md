# Leçon 3 — Ton premier Dockerfile

Il est 18 h 40 un vendredi, et la fenêtre de mise à jour du serveur se ferme à 19 h. Le plan était simple : arrêter l'ancien `revisor`, démarrer le nouveau, rentrer chez soi. Tu tapes `docker stop` et le terminal reste muet. Une seconde. Trois. Sept. Au bout de dix, enfin, il te rend la main. Tu réessaies avec l'instance suivante, et de nouveau : exactement dix secondes de silence. Tu consultes le journal et il manque la ligne que le `revisor` écrit toujours en s'arrêtant, `apagado limpio` ; le dernier rapport est resté inachevé. Quelqu'un de l'équipe trouve l'état du conteneur et le lit à voix haute : `ExitCode=137`. Personne ne l'a tué exprès, et pourtant on l'a tué. Le coupable n'est pas dans le code du `revisor`, qui sait très bien s'arrêter. Il se trouve dans une ligne de trois mots à la fin de son Dockerfile, une ligne qui a l'air inoffensive et qui s'écrit ainsi dans de nombreux tutoriels. Cette leçon t'apprend à écrire cette ligne, et toutes les autres, en sachant ce que fait chacune.

**Durée :** 2 × 45 min

**Ce que tu construis :** la première image du `revisor`, `curso-docker-revisor:1.0.0`, en une seule étape, avec son `Dockerfile` et son `.dockerignore`. Elle tourne sans privilèges, s'arrête en une fraction de seconde et porte une version dans son nom.

**Ce que tu apprends :** ce qu'est un Dockerfile et ce que fait chacune de ses instructions de base (`FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`) ; la différence entre la forme *exec* et la forme *shell*, mesurée au chronomètre ; ce qu'est le contexte de construction et à quoi sert `.dockerignore` ; pourquoi le premier Dockerfile comporte déjà `USER` ; comment on nomme une image et comment on lui attribue un tag de version ; et comment vérifier un Dockerfile avant de le construire avec `docker build --check`.

**D'où tu viens.** De la [Leçon 2](02-contenedores-dia-a-dia.md), tu apportes la pratique du quotidien : tu démarres un conteneur avec `docker run`, tu l'examines avec `ps`, `logs`, `inspect` et `exec`, tu publies son port uniquement sur `127.0.0.1` et tu le supprimes sans laisser de déchets. Là-bas, tu as construit l'image du service de test avec une seule commande, sans te demander ce que contenait son Dockerfile. De la [Leçon 0](00-que-es-un-contenedor.md), tu apportes la carte : un conteneur est un processus ; une image est le modèle dont il naît ; et le code 137 signifie que le noyau a tué le processus avec le signal 9. Cette dernière idée va revenir ici sous un autre visage. Du cours, tu apportes aussi le code du `revisor`, dans `programas/revisor/`, tel que le cours le livre : un service HTTP écrit en Go qui n'a pas encore de Dockerfile. Tu n'as pas besoin de connaître Go : tu ne vas pas modifier une seule ligne du programme.

**Ce que cette leçon ne fait pas.** Elle ne rend pas l'image petite : celle qui sort d'ici pèse plus d'un gigaoctet, et c'est très bien ainsi pour l'instant, car la voir grosse est la meilleure façon de comprendre ensuite pourquoi il vaut la peine de la réduire (le plan du cours garde cela pour la [Leçon 5](05-multi-stage.md)). Elle n'ordonne pas non plus le Dockerfile pour que la reconstruction soit rapide et n'explique pas les couches une à une : c'est le sujet de la [Leçon 4](04-capas-cache-contexto.md). Elle ne connecte pas le `revisor` à d'autres conteneurs (c'est pourquoi, dans cette leçon, le `revisor` se surveille lui-même) et ne lui ajoute ni contrôle de santé (health check) ni secrets. Une seule étape, une seule image, tout en vue.

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4, la même base que Linux Mint 22, le système de référence du cours. Les cinq scripts ont été exécutés ce jour-là depuis le client du Mac (Docker 29.8.2) contre le daemon de cette machine virtuelle (Docker 29.2.1, Buildx v0.31.1). Cette même machine était utilisée au même moment par d'autres exécutions ; pour éviter les collisions, les scripts ont donc été lancés avec un autre préfixe de noms et un autre port : ils comportent les variables `PREFIJO` (par défaut `curso-docker-`) et `PUERTO` (par défaut `8080`), et ont été exécutés avec `PREFIJO=curso-docker-l03-` et `PUERTO=18030`. Dans les sorties de `fig03_05` et `fig03_07`, où apparaissent des noms et un port, la leçon montre les valeurs par défaut, qui sont celles que tu verras : `curso-docker-revisor` au lieu de `curso-docker-l03-revisor` et `8080` au lieu de `18030` ; c'est la seule modification, et les fichiers `.salida.txt` conservent l'exécution telle quelle. Les sorties de `fig03_02`, `fig03_04` et `fig03_08` ne montrent ni noms ni port et sont reproduites sans retouche. Deux autres points concernant le Mac : le `date` de macOS ne donne pas les millisecondes, si bien que la fonction d'aide `t` des scripts recourt à `python3` quand c'est nécessaire (sur Mint, ce n'est pas nécessaire) ; et la première ligne de `docker build --check` indique `building with "colima" instance`, car c'est le nom du contexte Docker sur le Mac ; sur ton Mint, elle indiquera `"default"`. Le cours a été planifié avec Docker Engine 29.8.2, et la version la plus récente publiée ce jour-là était la 29.9.2, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)) ; rien dans cette leçon ne change entre ces versions. Ce qui change **effectivement** sur ton Mint, et c'est signalé là où cela apparaît : les numéros de processus (PID), les durées de construction et d'arrêt (celles de cette leçon incluent en plus l'aller-retour entre le Mac et sa machine virtuelle, elles devraient donc être un peu plus courtes sur ton Mint), et, si ton ordinateur est un Intel ou un AMD, l'architecture (`amd64` au lieu d'`arm64`), qui n'est pas affichée ici mais qui détermine quelle variante de l'image de Go est téléchargée. Les programmes se trouvent dans [`programas/03-primer-dockerfile/`](../programas/03-primer-dockerfile), chacun avec sa sortie à côté ; `estado/` conserve le `Dockerfile` et le `.dockerignore` tels qu'ils sont à la fin de la leçon.

## À la fin, tu seras capable de

- Écrire un Dockerfile en une seule étape pour un programme déjà existant et dire, ligne par ligne, si l'instruction agit au moment de **construire** l'image ou au moment d'**exécuter** le conteneur.
- Construire une image avec un nom et un tag de version, et expliquer pourquoi le `revisor` du cours s'appelle `curso-docker-revisor:1.0.0` et non `revisor` ni `revisor:latest`.
- Montrer avec `docker exec ... id` que ton conteneur ne tourne pas en tant que `root`, et expliquer ce que change `USER 10001:10001`.
- Écrire un `.dockerignore` et vérifier, en regardant à l'intérieur de l'image, qu'un fichier `.env` n'a pas été embarqué.
- Mesurer combien de temps prend `docker stop` avec `CMD` en forme *exec* et en forme *shell*, et expliquer avec `docker top` pourquoi l'une prend une fraction de seconde et l'autre un peu plus de 10 s avec le code 137.
- Exécuter `docker build --check` avant de construire et lire l'avertissement `JSONArgsRecommended`.

## Le pourquoi avant le comment

Dans la Leçon 2, tu as travaillé avec une image qu'on t'a donnée toute faite. Elle fonctionne, mais elle cache un piège : si tu ne sais pas comment elle a été assemblée, tu ne sais pas ce qu'elle contient ni comment elle va se comporter. Tourne-t-elle en tant que `root` ? Embarque-t-elle tes fichiers de configuration ? S'arrête-t-elle quand tu le lui demandes, ou attend-elle qu'on la tue ? Ces trois questions ne trouvent pas leur réponse en regardant le conteneur tourner ; elles la trouvent en lisant sa **recette**.

La recette d'une image s'appelle un **Dockerfile**. C'est un fichier texte contenant des instructions, une par ligne, que Docker lit de haut en bas pour fabriquer l'image. La documentation le définit ainsi : Docker construit des images en lisant les instructions d'un Dockerfile, « un fichier texte qui contient les instructions pour construire le code source » ([référence du Dockerfile](https://docs.docker.com/reference/dockerfile/)). Ce qui compte pour toi, c'est que la recette est **reproductible** : la même recette avec le même code donne la même image, aujourd'hui, le vendredi à 18 h 40 et sur l'ordinateur de ton collègue. Ce que tu as appelé dans la Leçon 0 « on ne répare pas une image en entrant dans le conteneur » trouve ici son autre moitié : une image se répare **en modifiant sa recette et en la reconstruisant**.

Et chaque ligne de cette recette est une décision. La scène du début n'a pas été causée par une erreur de programmation : elle a été causée par le fait d'écrire `CMD revisor` au lieu de `CMD ["revisor"]`. Les deux se ressemblent presque. Voici la différence que tu vas mesurer à la section 3.6, avec la même image et le même programme :

```text
## docker stop con forma exec
tardó 299 ms

## docker stop con forma shell
tardó 10485 ms
ExitCode=137
```

Quelques dixièmes de seconde contre dix secondes et un cadavre. Ce sont les chiffres de l'exécution de cette leçon ; lors d'une autre exécution, réalisée à l'intérieur de la machine virtuelle et sans l'aller-retour depuis le Mac, on a obtenu 161 ms contre 10 112 ms (10,1 s), avec le même `ExitCode=137`. Les millisecondes changent ; les dix secondes et le 137, non. La leçon comporte sept parties :

1. **Ce que signifie construire** (3.1) : la recette, le contexte et qui fait le travail.
2. **Le Dockerfile du `revisor`, ligne par ligne** (3.2).
3. **Le nom et le tag** (3.3) : pourquoi `curso-docker-revisor:1.0.0`.
4. **`USER` : ne pas tourner en tant que `root`** (3.4).
5. **Le contexte et `.dockerignore`** (3.5), avec un secret factice qui se glisse dans l'image.
6. **Construire, échouer et exécuter** (3.6), puis la **forme *exec* contre la forme *shell*** (3.7), chronomètre en main.
7. **Vérifier avant de construire** (3.8) et ce que tu rencontreras de dépassé dans les tutoriels (3.9).

## Les concepts

### 3.1 Ce que signifie construire une image

#### 3.1.1 La recette, les ingrédients et la cuisine

Construire une image fait intervenir trois éléments, et il vaut la peine de les distinguer dès le départ, car chacun échoue d'une manière différente :

- **La recette** : le Dockerfile.
- **Les ingrédients** : les fichiers que la recette peut utiliser. On les appelle le **contexte de construction**, et c'est presque toujours le contenu d'un dossier. Dans la commande `docker build .`, le point final est ce dossier : « le contexte est le dossier dans lequel je me trouve ».
- **La cuisine** : le constructeur, qui dans Docker s'appelle **BuildKit** et fait partie du daemon. Rappelle-toi la Leçon 0 : le client `docker` ne fait pas le travail ; il le demande au daemon. Lors de la construction, le client lui envoie la recette et les ingrédients que la recette demande, et le daemon cuisine.

La documentation sur la construction le formule avec ces mêmes éléments : le contexte est l'ensemble des fichiers auxquels la construction a accès, et les instructions du Dockerfile ne peuvent prendre des fichiers que dans celui-ci ([Docker, « Build context »](https://docs.docker.com/build/concepts/context/)). Cela a une conséquence pratique que tu vas exploiter en 3.5 : **ce qui n'est pas dans le contexte ne peut pas entrer dans l'image**, et ce qui est dans le contexte peut y entrer même si tu ne le veux pas.

#### 3.1.2 Deux moments : construire et exécuter

Une idée organise tout le reste de cette leçon : un Dockerfile décrit **deux moments distincts**.

1. **À la construction** (`docker build`) : Docker part d'une image de base, copie des fichiers et exécute des commandes. Le résultat est conservé dans l'image. Cela se produit une fois, sur ton ordinateur ou sur un serveur de construction.
2. **À l'exécution** (`docker run`) : Docker crée un conteneur à partir de cette image et démarre **un** processus. Cela se produit chaque fois que quelqu'un exécute l'image, sur n'importe quel ordinateur.

Certaines instructions agissent au premier moment, et d'autres se contentent de **noter** ce qu'il faudra faire au second. Si tu confonds les deux moments, tu écris des choses comme un `RUN` qui tente de démarrer le serveur (il s'exécuterait pendant la construction, resterait en attente et la construction ne se terminerait jamais) ou tu t'attends à ce qu'un `EXPOSE` ouvre un port (il se contente de le noter). Le tableau de 3.2.2 classe chaque instruction selon son moment.

### 3.2 Le Dockerfile du `revisor`, ligne par ligne

#### 3.2.1 La recette complète

Voici le Dockerfile avec lequel se termine la leçon. Il se place à la racine du projet du `revisor`, à côté de `go.mod`, et s'appelle exactement `Dockerfile`, sans extension, qui est le nom que `docker build` cherche par défaut :

```dockerfile
# syntax=docker/dockerfile:1
# fig03_01.Dockerfile — Lección 3: el primer Dockerfile del revisor: una sola etapa.
FROM golang:1.27.3-trixie

WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor

# Un usuario sin privilegios, por número: la imagen no necesita tenerlo en /etc/passwd.
USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

Douze lignes, dont sept sont des instructions. Voyons-les une à une.

**`# syntax=docker/dockerfile:1`.** On dirait un commentaire, et pour presque tout le fichier c'en est un, mais en première ligne c'est une **directive** : elle indique à BuildKit quelle version de la syntaxe du Dockerfile utiliser. La référence l'explique ainsi : elle sert à « déclarer la version de la syntaxe du Dockerfile à utiliser pour la construction », et permet d'utiliser de nouvelles fonctionnalités sans mettre Docker à jour ([référence du Dockerfile, *syntax*](https://docs.docker.com/reference/dockerfile/#syntax)). Le `1` signifie « la version 1 la plus récente ». C'est pourquoi, dans les sorties de construction, tu verras Docker résoudre d'abord `docker.io/docker/dockerfile:1` : il va chercher l'interpréteur de la recette avant de la lire. Tous les Dockerfile du cours commencent par cette ligne.

**`FROM golang:1.27.3-trixie`.** Toute image part d'une autre. `FROM` indique quelle est l'**image de base** : ici, l'image officielle de Go en version 1.27.3, construite sur Debian 13, dont le nom de code est *trixie*. Le `revisor` est écrit en Go et, pour le compiler, il faut le compilateur Go ; cette image le fournit, avec tout un Debian. Docker Hub répertorie ce tag parmi les tags en vigueur de l'image de Go, et précise que des noms comme *bookworm* ou *trixie* sont les noms de code des versions de Debian sur lesquelles elle est construite ([golang sur Docker Hub](https://hub.docker.com/_/golang)).

**`WORKDIR /src`.** Fixe le dossier de travail à l'intérieur de l'image : tout ce qui suit (`COPY`, `RUN`, `CMD`) se passe là. Si le dossier n'existe pas, Docker le crée ([référence, `WORKDIR`](https://docs.docker.com/reference/dockerfile/#workdir)). C'est préférable à écrire `RUN cd /src`, qui ne sert à rien : chaque `RUN` repart de zéro et le `cd` est perdu à la fin de cette ligne.

**`COPY . .`.** Copie depuis le contexte (le premier point) vers le dossier de travail de l'image (le second point, qui est ici `/src`). C'est le seul point d'entrée par lequel tes fichiers entrent dans l'image. Tout copier est le plus simple et le plus dangereux : tout ce qui se trouve dans le contexte entre. C'est pour cela qu'existe le `.dockerignore` de 3.5. (Tout copier d'un coup rend aussi la reconstruction lente ; le plan du cours aborde ce point dans la Leçon 4.)

**`RUN go build -o /usr/local/bin/revisor ./cmd/revisor`.** Exécute une commande **à la construction** et conserve le résultat dans l'image. Ici, elle compile le `revisor` et place l'exécutable dans `/usr/local/bin/revisor`, un dossier qui figure déjà dans la variable `PATH` de l'image. C'est pourquoi, plus bas, il suffit d'écrire `revisor`, sans chemin.

**`USER 10001:10001`.** À partir d'ici, et surtout à l'exécution, le processus utilise l'utilisateur 10001 et le groupe 10001 au lieu de `root`. Il a sa propre section, la 3.4.

**`EXPOSE 8080`.** Note que le programme écoute sur le port 8080. Il se contente de le noter : la référence est claire, `EXPOSE` « ne publie pas réellement le port » ; pour le publier, il faut `-p` à l'exécution ([référence, `EXPOSE`](https://docs.docker.com/reference/dockerfile/#expose)). Cela sert de documentation pour qui lit l'image et pour les outils qui la consultent. Le port se publie, comme tu l'as appris dans la Leçon 2, avec `-p 127.0.0.1:8080:8080`.

**`CMD ["revisor"]`.** Note quel processus démarrer **à l'exécution** du conteneur. Un seul peut être effectif : si tu écris plusieurs `CMD`, c'est le dernier qui l'emporte ([référence, `CMD`](https://docs.docker.com/reference/dockerfile/#cmd)). Et c'est une valeur par défaut : si tu passes une commande à `docker run` après le nom de l'image, cette commande remplace le `CMD` ([Docker, « Running containers »](https://docs.docker.com/engine/containers/run/)). Les crochets et les guillemets ne sont pas décoratifs : c'est la forme *exec*, le sujet de 3.7.

#### 3.2.2 Chaque instruction à son moment

| Instruction | Quand elle agit | Ce qu'elle laisse dans l'image |
|---|---|---|
| `FROM` | à la construction | tout le contenu de l'image de base |
| `WORKDIR` | à la construction, et note le dossier pour l'exécution | le dossier, et l'information de l'endroit où démarrer |
| `COPY` | à la construction | les fichiers copiés |
| `RUN` | à la construction | ce que la commande a écrit sur le disque |
| `USER` | note pour l'exécution (et pour les `RUN` qui suivent) | l'information de l'utilisateur |
| `EXPOSE` | se contente de noter | l'information du port ; n'ouvre rien |
| `CMD` | se contente de noter | la commande que démarrera chaque conteneur |

Lis la troisième colonne avec attention : les trois dernières instructions n'ajoutent pas de fichiers, elles ajoutent des **informations** à la configuration de l'image. Tu pourras les lire avec `docker inspect` et, plus tard, dans l'historique de l'image. Garde à l'esprit que l'ordre compte : un `USER` placé avant un `RUN` fait que ce `RUN` s'exécute avec cet utilisateur. C'est pourquoi, ici, `USER` vient après la compilation : la compilation a besoin d'écrire dans des dossiers de `root`, le serveur non.

> [!NOTE]
> 🔧 **Observation de génie logiciel 3.1**
> Pour chaque ligne d'un Dockerfile, demande-toi : « est-ce que cela se produit une fois, quand je construis, ou à chaque fois, quand quelqu'un exécute ? ». Ce qui se produit à la construction peut être lent et lourd, car on ne le paie qu'une fois. Ce qui se produit à l'exécution doit être rapide et minimal, car on le paie à chaque démarrage et, un mauvais jour, à chaque redémarrage.

### 3.3 Le nom et le tag

#### 3.3.1 Les parties d'un nom

Lorsque tu construis, tu donnes un nom à l'image avec `-t`. Le nom complet d'une image a cette forme, selon la documentation de `docker image tag` : `[HÔTE[:PORT]/]ESPACE/DÉPÔT[:TAG]` ([`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/)). Pour une image qui ne vit que sur ton ordinateur, deux parties suffisent :

- le **dépôt**, qui dit ce que c'est : `curso-docker-revisor` ;
- le **tag**, après les deux-points, qui dit de quelle version il s'agit : `1.0.0`.

La même documentation dit quelque chose qu'il vaut la peine de souligner : « si aucun tag n'est fourni, Docker utilise `latest` ». Autrement dit, `latest` **ne** signifie **pas** « la plus récente ». Cela signifie « on ne lui a pas mis de tag ». Une image construite il y a deux ans sans tag s'appelle `latest` tout comme une image d'aujourd'hui. Dans la scène du début, si les images s'étaient appelées `revisor:latest`, tu n'aurais même pas pu savoir quelle version tournait quand le problème a commencé.

Les tags sont en outre des **alias qui bougent**. Regarde la ligne de l'image de base sur Docker Hub : le même contenu porte en même temps les tags `1.27.3-trixie`, `1.27-trixie`, `1-trixie` et `trixie` ([golang sur Docker Hub](https://hub.docker.com/_/golang)). Quand Go 1.27.4 sortira, `1.27-trixie` pointera vers autre chose et `1.27.3-trixie` restera où il est. C'est pourquoi le `FROM` de cette leçon utilise le tag le plus spécifique qui existe. Même celui-là n'est pas une garantie absolue, car l'éditeur peut republier un tag : le guide des bonnes pratiques avertit que « les tags d'image sont mutables » et que, pour figer réellement une version, il faut utiliser son empreinte (*digest*) ([bonnes pratiques](https://docs.docker.com/build/building/best-practices/)). Le plan du cours garde cette étape pour la Leçon 5 ; ici, il suffit de ne pas utiliser `latest`.

#### 3.3.2 Pourquoi `curso-docker-revisor` et pas `revisor`

Le plan du cours, dans le tableau des leçons, indique que dans cette leçon tu construis `revisor:1.0.0`. Ici, l'image s'appelle `curso-docker-revisor:1.0.0`. La différence est voulue, et c'est une leçon en soi : **le préfixe du cours**.

Depuis la Leçon 0, tout ce que le cours crée sur ton ordinateur commence par `curso-docker-` : les conteneurs, les réseaux, les volumes et, désormais, les images. Ce préfixe fait trois choses pour toi :

1. **Il évite les collisions.** `revisor` est un nom que n'importe qui utiliserait. Si une image `revisor:1.0.0` d'un autre projet existe déjà sur ton ordinateur (d'un autre cours de Hábil, par exemple), ton `docker build -t revisor:1.0.0` lui prend son nom sans demander : l'ancienne image se retrouve sans tag et la nouvelle prend sa place. Ce n'est pas hypothétique : sur la machine où cette leçon a été exécutée, il existait déjà une image nommée `revisor:1.0.0`, d'un autre projet, qui n'a rien à voir avec ce Dockerfile. Avec le préfixe, les deux cohabitent.
2. **Il permet de nettoyer uniquement ce qui t'appartient.** Les filtres de Docker travaillent par nom. `docker ps -a --filter name=curso-docker-` ne liste que les conteneurs du cours, et `docker image ls 'curso-docker-*'` que ses images. Supprimer « tout ce qui concerne le cours » devient une commande sûre, qui ne touche ni aux bases de données ni aux images d'autres projets présents sur le même ordinateur.
3. **Il dit d'où cela vient.** Dans six mois, quand tu feras le ménage et que tu tomberas sur `curso-docker-revisor:1.0.0`, tu sauras ce que c'est sans enquêter.

La règle de versions du `revisor` dans ce cours est simple : chaque fois qu'une leçon modifie l'image, la version augmente. Celle-ci est la `1.0.0` : la première qui fonctionne entièrement. Quand le Dockerfile changera, on ne réutilisera pas le tag ; on en créera un autre.

> [!NOTE]
> 🔧 **Observation de génie logiciel 3.2**
> Un nom d'image est une promesse : « ceci est telle chose, en telle version ». `latest` ne promet rien, et un nom sans préfixe promet quelque chose qu'un autre projet peut aussi être en train de promettre. Les deux erreurs se paient le jour où tu as besoin de savoir ce qui tourne, qui est généralement le pire jour pour le découvrir.

### 3.4 `USER` : le premier Dockerfile ne tourne déjà plus en tant que `root`

#### 3.4.1 Ce qui se passe si tu ne dis rien

Dans la Leçon 0, tu as vu que `root` à l'intérieur d'un conteneur est l'utilisateur 0 du même noyau, avec quatorze capacités activées. Voici maintenant la question concrète : si ton Dockerfile ne dit rien sur l'utilisateur, sous quelle identité tourne le `revisor` ? Cela dépend de l'image de base. `fig03_02.sh` pose la question à l'image de Go :

```bash
#!/usr/bin/env bash
# fig03_02.sh — Sin USER, la imagen base corre como root.
# Pregunta con qué usuario arranca la imagen de Go que usa el revisor, y compara
# con un usuario sin privilegios elegido por número.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
IMAGEN=golang:1.27.3-trixie
docker pull -q "$IMAGEN" >/dev/null

echo "== 1. Lo que la imagen base declara como usuario (vacío = root)"
docker image inspect --format 'User="{{.Config.User}}"' "$IMAGEN"

echo
echo "== 2. Quién soy dentro, sin decir nada"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" id

echo
echo "== 3. Quién soy dentro, con el usuario 10001:10001"
docker run --rm --name "${PREFIJO}quien" --user 10001:10001 "$IMAGEN" id

echo
echo "== 4. ¿Existe ese usuario en /etc/passwd de la imagen?"
docker run --rm --name "${PREFIJO}quien" "$IMAGEN" \
  sh -c 'grep -q ":10001:" /etc/passwd && echo "sí está" || echo "no está"'
```

```text
$ ./fig03_02.sh
== 1. Lo que la imagen base declara como usuario (vacío = root)
User=""

== 2. Quién soy dentro, sin decir nada
uid=0(root) gid=0(root) groups=0(root)

== 3. Quién soy dentro, con el usuario 10001:10001
uid=10001 gid=10001 groups=10001

== 4. ¿Existe ese usuario en /etc/passwd de la imagen?
no está
```

Cette sortie est stable. La première fois, `docker pull` télécharge l'image de Go, qui pèse des centaines de mégaoctets ; sois patient. `--user` fait à l'exécution la même chose que `USER` dans le Dockerfile, et sert ici à tester l'utilisateur sans rien construire.

Lis-la de haut en bas. L'image de base déclare un utilisateur vide, et vide signifie `root` : le bloc 2 le confirme, avec `uid=0(root)`. Un Dockerfile qui part de `golang` et ne dit rien en hérite, et le `revisor` traiterait les requêtes du réseau en tant qu'utilisateur 0 de ton noyau. Avec l'utilisateur 10001, le bloc 3 indique `uid=10001 gid=10001`, **sans nom entre parenthèses**. Et le bloc 4 explique pourquoi : cet utilisateur n'existe pas dans le `/etc/passwd` de l'image.

#### 3.4.2 Un numéro suffit

C'est correct, et c'est voulu. Pour le noyau, un utilisateur est un numéro ; le nom est une commodité qui vit dans `/etc/passwd`. La référence de `USER` accepte un nom ou un numéro, sous la forme `USER <UID>[:<GID>]` ([référence, `USER`](https://docs.docker.com/reference/dockerfile/#user)), et écrire les deux numéros présente deux avantages. Le premier : il n'est pas nécessaire de créer l'utilisateur dans l'image. Le second : le groupe est fixé ; si tu donnes un utilisateur sans groupe et que cet utilisateur n'a pas de groupe principal, la référence avertit que le processus tourne avec le groupe de `root`. Avec `10001:10001`, aucune surprise.

Pourquoi 10001 ? Parce qu'il est éloigné des numéros qu'utilisent les distributions pour leurs propres utilisateurs et pour les personnes de l'équipe (sur Mint, ton utilisateur est généralement le 1000). Un numéro élevé et dédié réduit le risque que le processus du conteneur coïncide avec un utilisateur réel de l'hôte.

Le guide des bonnes pratiques le demande sans détour : « si un service peut tourner sans privilèges, utilise `USER` pour passer à un utilisateur autre que `root` » ([bonnes pratiques, `USER`](https://docs.docker.com/build/building/best-practices/#user)). Le `revisor` n'a besoin de rien de `root` : il écoute sur le 8080, un port élevé, et n'écrit pas dans des dossiers système. (Les ports inférieurs à 1024 sont ceux qui, sous Linux, exigent une capacité spéciale ; à l'intérieur d'un conteneur Docker, même cela ne s'applique pas : `docker run --rm --user 10001:10001 golang:1.27.3-trixie cat /proc/sys/net/ipv4/ip_unprivileged_port_start` a affiché `0` sur la machine de cette leçon, ce qui veut dire que n'importe quel port peut être ouvert sans privilèges.) Ainsi, dès le premier Dockerfile, il tourne en tant que 10001. Le plan du cours le formule ainsi : la sécurité n'est pas une leçon, c'est une habitude.

### 3.5 Le contexte et `.dockerignore`

#### 3.5.1 Ce qui voyage finit à l'intérieur

Passons à l'ingrédient dangereux : `COPY . .`. Il copie **tout** le contexte. Dans un vrai projet, le dossier contient plus que du code : un `.git` avec l'historique, un `.env` avec des mots de passe pour tester sur ton ordinateur, une sauvegarde `.tar` que tu as laissée là la semaine dernière. `fig03_04.sh` construit le `revisor` avec le Dockerfile de cette leçon et un fichier `.env` **factice** dans le dossier, d'abord sans `.dockerignore` puis avec, et regarde ce qui est resté dans `/src` à l'intérieur de l'image :

```bash
#!/usr/bin/env bash
# fig03_04.sh — Lo que viaja en el contexto acaba dentro de la imagen.
# Construye el revisor con un archivo .env de mentira en la carpeta: primero SIN
# .dockerignore y después CON el de fig03_03. Mira qué quedó en /src cada vez.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
SIN="${PREFIJO}revisor:1.0.0-sin-ignore"
CON="${PREFIJO}revisor:1.0.0-con-ignore"
trap 'docker rmi -f "$SIN" "$CON" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + el Dockerfile de la lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/fig03_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
# Un secreto DE MENTIRA, como el que cualquiera deja en la carpeta del proyecto.
echo 'REVISOR_TOKEN=curso-docker-env-de-mentira-3c1d' > .env

echo "== 1. SIN .dockerignore: lo que hay en /src dentro de la imagen"
docker build -q -t "$SIN" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$SIN" ls -A /src
echo "-- y el .env, leído desde la imagen:"
docker run --rm --name "${PREFIJO}mira" "$SIN" cat /src/.env

echo
echo "== 2. CON .dockerignore: lo que hay en /src dentro de la imagen"
cp "$AQUI/fig03_03.dockerignore" .dockerignore
docker build -q -t "$CON" . >/dev/null
docker run --rm --name "${PREFIJO}mira" "$CON" ls -A /src
```

```text
$ ./fig03_04.sh
== 1. SIN .dockerignore: lo que hay en /src dentro de la imagen
.env
Dockerfile
cmd
go.mod
internal
-- y el .env, leído desde la imagen:
REVISOR_TOKEN=curso-docker-env-de-mentira-3c1d

== 2. CON .dockerignore: lo que hay en /src dentro de la imagen
cmd
go.mod
internal
```

Cette sortie est stable. Le script travaille dans un dossier temporaire (`mktemp -d`) pour ne pas salir `programas/revisor/`, qui est le code que le cours livre et qu'on ne modifie pas, et il supprime ses deux images en sortant. `docker build -q` construit en silence (*quiet*) ; `ls -A` liste aussi les fichiers qui commencent par un point. Les deux constructions durent autant qu'une construction normale, car chacune recompile : lors de l'exécution de cette leçon, le script complet a pris un peu plus d'une minute, avec l'image de base déjà téléchargée.

Regarde le premier bloc. Le `.env` est entré dans l'image et se lit avec un `cat`. Quiconque possède l'image — ton collègue, le serveur, un registre public si un jour tu la publies — possède aussi ce secret. Et il n'est même pas nécessaire d'exécuter l'image pour l'extraire : il suffit de l'enregistrer dans un fichier et de l'ouvrir. Le `Dockerfile` lui-même est entré aussi, alors qu'il ne sert à rien à l'intérieur. Dans le second bloc, avec le `.dockerignore`, `/src` ne contient que ce dont le programme a besoin pour être compilé : `cmd`, `go.mod` et `internal`.

#### 3.5.2 Le `.dockerignore` de la leçon

Voici le fichier. Il s'appelle exactement `.dockerignore`, avec le point, et se place à la racine du contexte, à côté du `Dockerfile` :

```text
# fig03_03.dockerignore
# Lo que nunca viaja al daemon al construir.
.git
.env
*.tar
Dockerfile*
.dockerignore
```

Chaque ligne est un motif, semblable aux jokers du *shell* ; les lignes commençant par `#` sont des commentaires ([Docker, « Build context », fichiers `.dockerignore`](https://docs.docker.com/build/concepts/context/#dockerignore-files)). La documentation précise où il est cherché : le client cherche un fichier nommé `.dockerignore` « dans le dossier racine du contexte ». Chaque ligne a sa raison d'être :

- **`.git`** : l'historique complet du projet. Il peut peser beaucoup plus que le code et peut conserver des secrets que quelqu'un a effacés du code mais pas de l'historique.
- **`.env`** : l'endroit où les gens gardent des mots de passe pour tester sur leur ordinateur. C'est précisément le fichier de la figure.
- **`*.tar`** : des sauvegardes et des fichiers exportés qui restent dans le dossier sans que personne s'en souvienne.
- **`Dockerfile*` et `.dockerignore`** : la recette n'a aucune raison de se trouver dans l'assiette. Mais alors, comment Docker construit-il si tu exclus le Dockerfile ? La documentation répond : ces deux fichiers « sont tout de même envoyés au constructeur, car il en a besoin pour construire » ; ce que le motif empêche, c'est que `COPY` les mette dans l'image. L'astérisque de `Dockerfile*` couvre aussi le `Dockerfile.forma-shell` de 3.7.

Un détail de lecture : une ligne qui commence par `!` crée une exception (« ceci, oui, même si un motif précédent l'exclut »), et quand plusieurs motifs correspondent à un fichier, c'est le dernier qui l'emporte. Tu n'en as pas besoin aujourd'hui, mais tu le verras dans des projets tiers.

> [!NOTE]
> 🔧 **Observation de génie logiciel 3.3**
> `.dockerignore` est une liste de ce qui **ne** voyage **pas**. Cela signifie que tout ce que tu oublies d'y mettre voyage. C'est pourquoi le premier Dockerfile d'un projet est déjà accompagné de son `.dockerignore`, même si le dossier est propre aujourd'hui : le dossier ne restera pas propre, et le jour où quelqu'un y laissera un `.env`, le fichier l'attendra déjà.

### 3.6 Construire, échouer et exécuter

#### 3.6.1 Construire

Avec le `Dockerfile` et le `.dockerignore` dans le dossier du `revisor`, la construction tient en une seule commande. `fig03_05.sh` assemble le projet dans un dossier temporaire, construit, provoque la première erreur, exécute correctement le service, l'interroge et l'arrête :

```bash
#!/usr/bin/env bash
# fig03_05.sh — Construir el revisor, verlo fallar sin configuración, correrlo
# bien y detenerlo. CMD en forma exec. Borra lo que crea al salir.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'docker rm -f ${PREFIJO}revisor >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0 >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construir y medir"
muestra "docker build -q -t ${PREFIJO}revisor:1.0.0 . >/dev/null && docker image ls ${PREFIJO}revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "El error: arrancar sin configuración"
muestra "docker run --name ${PREFIJO}revisor ${PREFIJO}revisor:1.0.0"
muestra "docker ps -a --filter name=${PREFIJO}revisor --format '{{.Names}} {{.Status}}'"
docker rm ${PREFIJO}revisor >/dev/null

titulo "Correrlo bien"
muestra "docker run -d --name ${PREFIJO}revisor -p 127.0.0.1:${PUERTO}:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0 >/dev/null"
esperar_http "http://127.0.0.1:${PUERTO}/salud"
muestra "curl -s http://127.0.0.1:${PUERTO}/salud"
muestra "curl -s 'http://127.0.0.1:${PUERTO}/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"
muestra "docker exec ${PREFIJO}revisor id"
muestra "docker top ${PREFIJO}revisor -o pid,user,args"

titulo "docker stop con forma exec"
inicio=$(t); docker stop ${PREFIJO}revisor >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker logs ${PREFIJO}revisor"
```

Le script est long à cause des fonctions d'aide du début, que tu reconnaîtras dans les suivants : `muestra` affiche chaque commande précédée d'un `$` avant de l'exécuter, pour que tu saches dans la sortie ce qui a produit quoi, et si la commande échoue, elle note son code de sortie au lieu d'arrêter le script ; `t` donne l'heure en millisecondes pour chronométrer ; `esperar_http` interroge le endpoint de contrôle de santé du service jusqu'à ce qu'il réponde, car un conteneur tout juste démarré met un instant à se mettre à l'écoute. La première partie de la sortie :

```text
## Construir y medir
$ docker build -q -t curso-docker-revisor:1.0.0 . >/dev/null && docker image ls curso-docker-revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

**1,45 Go.** Le `revisor` compilé est un seul fichier de quelques mégaoctets ; tout le reste vient de l'image de base : un Debian complet, le compilateur Go et ses outils, plus ce que la compilation a laissé dans l'image. Rien de tout cela n'est nécessaire pour **exécuter** le `revisor`, seulement pour le **construire**. Note ce chiffre dans ton journal de bord : c'est le point de départ, et le plan du cours consacre la Leçon 5 à le faire baisser. Sur ton ordinateur, le chiffre peut varier un peu selon l'architecture.

#### Dans ton dossier : l'image que tu gardes

Les scripts du cours travaillent dans des dossiers temporaires et **suppriment ce qu'ils créent** en sortant : ils servent à observer et à mesurer, pas à te laisser quoi que ce soit. Ton projet, en revanche, doit rester, car la Leçon 4 part de lui. Depuis la racine du dépôt du cours, prépare ton dossier et construis l'image que tu vas conserver :

```bash
mkdir -p ~/curso-docker
cp -R programas/revisor ~/curso-docker/revisor
cp programas/03-primer-dockerfile/estado/Dockerfile \
   programas/03-primer-dockerfile/estado/.dockerignore ~/curso-docker/revisor/
cd ~/curso-docker/revisor
ls -A
docker build -q -t curso-docker-revisor:1.0.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

```text
$ ls -A
.dockerignore
cmd
Dockerfile
go.mod
internal
$ docker build -q -t curso-docker-revisor:1.0.0 .
sha256:f1b8e9646140…
$ docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

L'identifiant qu'affiche `docker build -q` est l'empreinte de l'image et change sur chaque ordinateur ; il a été tronqué ici. Cette exécution a utilisé le préfixe d'exécution décrit dans « À propos des exécutions » pour le tag, et elle est présentée avec le nom par défaut ; l'ordre dans lequel `ls -A` liste les fichiers peut varier selon la langue de ton système. Désormais, quand la leçon dira « dans le dossier du `revisor` », il s'agira de `~/curso-docker/revisor`, et **cette** `curso-docker-revisor:1.0.0` est celle qui reste sur ton ordinateur à la fin. Tu peux taper telles quelles, à cet endroit, les commandes de 3.6.2 et 3.6.3.

#### 3.6.2 La première erreur : démarrer sans configuration

```text
## El error: arrancar sin configuración
$ docker run --name curso-docker-revisor curso-docker-revisor:1.0.0
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]
$ docker ps -a --filter name=curso-docker-revisor --format '{{.Names}} {{.Status}}'
curso-docker-revisor Exited (1) Less than a second ago
```

L'image est correcte ; le conteneur a démarré et le `revisor` a refusé de travailler. Le `revisor` se configure par des variables d'environnement, et la seule obligatoire est `REVISOR_SERVICIOS`, la liste des services qu'il doit surveiller. Sans elle, il affiche ce qui lui manque, avec un exemple, et se termine avec le code 1. `docker ps -a` l'indique comme `Exited (1)` : le processus s'est terminé de lui-même, avec une erreur qui lui est propre. Compare avec le 137 de la Leçon 0 : là-bas, quelqu'un a tué le processus ; ici, le processus a décidé de partir. Savoir lire cette différence t'évite de chercher le problème au mauvais endroit. Remarque aussi que le conteneur est resté créé bien qu'il se soit terminé : le script le supprime avec `docker rm` avant de continuer, car le nom est occupé.

#### 3.6.3 L'exécuter correctement

```text
## Correrlo bien
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.0.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK            0s  200
$ docker exec curso-docker-revisor id
uid=10001 gid=10001 groups=10001
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
1387809             10001               revisor
```

Le numéro de processus `1387809` change à chaque exécution ; tout le reste est stable, sauf, lors d'une autre exécution, la durée affichée dans le tableau (le `sed` de la commande est là pour la masquer si elle sort en millisecondes ; lors de cette exécution, elle est sortie à `0s` et il n'y avait rien à masquer).

`-e` passe une variable d'environnement au conteneur. Ici, le `revisor` se surveille **lui-même** : la liste ne contient qu'un service, `propio`, qui pointe vers son propre endpoint de contrôle de santé. C'est une façon de vérifier que tout fonctionne sans autre conteneur, car connecter des conteneurs entre eux relève des réseaux et le plan du cours garde ce sujet pour la Leçon 8. Le tableau indique `OK` et `200`.

`/salud` répond `"version":"desarrollo"`. Ce n'est pas une erreur : l'image a été construite sans graver de version dans le programme, et le `revisor` est conçu pour le signaler ainsi. Attention à la différence : l'**image** porte le tag `1.0.0`, mais le **programme** à l'intérieur ne sait pas dans quelle version il se trouve. Ce sont deux choses distinctes, et les relier est le travail d'une leçon ultérieure.

Passons aux deux dernières lignes, qui sont les plus importantes de cette section. `docker exec ... id` indique `uid=10001` : le `USER` du Dockerfile a fonctionné. Et `docker top`, qui liste les processus d'un conteneur vus depuis l'hôte, montre **un seul processus** : `revisor`, de l'utilisateur 10001. Cette ligne unique, c'est la forme *exec* qui fonctionne. Garde-la en mémoire, car dans la section suivante tu vas en voir une avec **deux** lignes.

### 3.7 Forme *exec* contre forme *shell*

#### 3.7.1 Deux façons d'écrire la même chose

`CMD` (ainsi que `RUN` et `ENTRYPOINT`) peut s'écrire de deux manières ([référence du Dockerfile, formes *shell* et *exec*](https://docs.docker.com/reference/dockerfile/#shell-and-exec-form)) :

- **Forme *exec*** : une liste au format JSON, avec des crochets et des guillemets doubles : `CMD ["revisor"]`. Docker démarre ce programme directement, sans rien entre les deux.
- **Forme *shell*** : un texte ordinaire : `CMD revisor`. Docker l'enveloppe dans un *shell* ; sous Linux, dans `/bin/sh -c "revisor"`. La référence le formule ainsi : contrairement à la forme *exec*, les instructions en forme *shell* « utilisent toujours un *shell* ».

La forme *shell* existe pour une raison : avec un *shell* entre les deux, tu peux utiliser des variables (`$HOME`), des tubes (`|`) et enchaîner des commandes (`&&`). C'est pourquoi on l'utilise beaucoup dans les `RUN`, et c'est très bien ainsi. Le problème apparaît quand tu l'utilises pour le processus **principal** du conteneur, celui que démarre `CMD`.

Pour le voir, la leçon fournit une copie du Dockerfile dans laquelle seule la dernière ligne change. Elle n'existe que pour comparer :

```dockerfile
# syntax=docker/dockerfile:1
# fig03_06.Dockerfile — Lección 3: la MISMA imagen, pero con CMD en forma shell. Existe solo para
# comparar: así NO se escribe.
FROM golang:1.27.3-trixie
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
USER 10001:10001
EXPOSE 8080
CMD revisor
```

Dans le projet, elle est enregistrée sous le nom `Dockerfile.forma-shell`, et elle se construit avec `docker build -f Dockerfile.forma-shell` : l'option `-f` indique à Docker quelle recette utiliser quand ce n'est pas celle qui s'appelle `Dockerfile`.

#### 3.7.2 La mesure

D'abord, la moitié que tu as déjà vue : la fin de `fig03_05.sh`, qui arrête le conteneur en forme *exec* et affiche son journal :

```text
## docker stop con forma exec
tardó 299 ms
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 1ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Les durées (299 ms, ainsi que les `0s` et `1ms` de chaque requête) changent à chaque exécution ; la séquence de lignes est stable, même si le nombre de `GET /salud` dépend du nombre de fois où `esperar_http` a interrogé le service avant qu'il réponde. Les deux dernières lignes sont celles qui comptent : le `revisor` **a reçu** le signal (`terminated` est le nom que Go donne à `SIGTERM`), a terminé ce qu'il était en train de faire et a pris congé. Le tout en 299 millisecondes lors de cette exécution (161 lors de l'autre, à l'intérieur de la machine virtuelle).

Maintenant, l'autre moitié. `fig03_07.sh` construit l'image en forme *shell*, l'exécute avec la même configuration, examine ses processus et l'arrête :

```bash
#!/usr/bin/env bash
# fig03_07.sh — La MISMA imagen con CMD en forma shell: quién es el PID 1,
# cuánto tarda docker stop y con qué código muere. Borra lo que crea al salir.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'docker rm -f ${PREFIJO}revisor-shell >/dev/null 2>&1; docker rmi -f ${PREFIJO}revisor:1.0.0-shell >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "docker stop con forma shell"
docker build -q -t ${PREFIJO}revisor:1.0.0-shell -f Dockerfile.forma-shell . >/dev/null
docker run -d --name ${PREFIJO}revisor-shell -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' ${PREFIJO}revisor:1.0.0-shell >/dev/null
sleep 1
muestra "docker top ${PREFIJO}revisor-shell -o pid,user,args"
inicio=$(t); docker stop ${PREFIJO}revisor-shell >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${PREFIJO}revisor-shell"
muestra "docker logs ${PREFIJO}revisor-shell"
```

Les fonctions d'aide du début sont les mêmes que dans `fig03_05.sh`. Le tag `1.0.0-shell` et le nom `curso-docker-revisor-shell` sont auxiliaires : ils ne vivent que le temps du script.

```text
## docker stop con forma shell
$ docker top curso-docker-revisor-shell -o pid,user,args
PID                 USER                COMMAND
1388087             10001               /bin/sh -c revisor
1388102             10001               revisor
tardó 10485 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor-shell
ExitCode=137
$ docker logs curso-docker-revisor-shell
revisor desarrollo escuchando en :8080 (1 servicio(s))
```

Les numéros de processus changent ; la durée varie de quelques millisecondes, mais reste toujours **un peu au-dessus de 10 secondes** ; `ExitCode=137` et le journal d'une seule ligne sont stables. C'est la scène du début, au complet.

#### 3.7.3 Ce qui s'est passé : le signal qui n'est pas arrivé

Place les deux sorties de `docker top` côte à côte. Avec la forme *exec*, il y avait **un** processus, `revisor`. Avec la forme *shell*, il y en a **deux** : `/bin/sh -c revisor` et, comme enfant de celui-ci, `revisor`. Le *shell* a démarré en premier, donc le *shell* est le processus numéro 1 du conteneur (rappelle-toi la Leçon 0 : à l'intérieur du conteneur, le programme principal est le 1). Le `revisor` est devenu le numéro 2 à l'intérieur, un enfant parmi d'autres.

Voyons maintenant la chaîne de `docker stop`, selon sa documentation : il envoie au processus principal du conteneur le signal `SIGTERM`, attend un délai qui est par défaut de **10 secondes** sous Linux, et si le processus est toujours vivant, il lui envoie `SIGKILL` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)). Le « processus principal » est le numéro 1. Avec la forme *exec*, le numéro 1 est le `revisor`, qui est écrit pour traiter `SIGTERM` : il le reçoit, s'arrête proprement et se termine. Avec la forme *shell*, le numéro 1 est `/bin/sh`.

Ici se rejoignent deux faits. Le premier : le *shell* ne retransmet pas le signal à son enfant. L'explication de la règle `JSONArgsRecommended` le dit textuellement : avec la forme *shell*, le programme « tourne comme processus enfant d'un *shell*, qui ne transmet pas les signaux » ([Docker, `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/)). La référence du Dockerfile le dit en toutes lettres à propos de la forme *shell* d'`ENTRYPOINT` : l'exécutable « ne sera pas le PID 1 du conteneur et ne recevra pas les signaux Unix » ([référence, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). Le second fait relève du noyau et il est plus subtil : le processus numéro 1 d'un espace de noms de processus est spécial. `docker stop` envoie le signal depuis l'extérieur du conteneur, depuis l'espace de noms de l'hôte, qui est l'« ancêtre » du conteneur. Pour ce cas, le manuel de Linux indique que le processus numéro 1 ne reçoit que les signaux pour lesquels il a établi un gestionnaire, et que `SIGKILL` et `SIGSTOP` font exception : ces deux-là « sont délivrés de force » lorsqu'ils proviennent d'un espace de noms ancêtre ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). Le *shell* n'a pas installé de gestionnaire pour `SIGTERM`, si bien que le signal ne le tue même pas, lui : il se perd.

Dès lors, la sortie se lit d'elle-même :

1. `docker stop` envoie `SIGTERM` au numéro 1, le *shell*. Il se perd. Le `revisor`, en dessous, n'en sait jamais rien.
2. 10 secondes s'écoulent. C'est presque tout le temps que tu as mesuré : 10 485 ms, ce sont les 10 000 du délai plus le temps que prennent Docker, le noyau et, lors de cette exécution, l'aller-retour depuis le Mac (lors de l'exécution à l'intérieur de la machine virtuelle, on a obtenu 10 112 ms).
3. `docker stop` envoie `SIGKILL`, qui, selon le manuel des signaux, « ne peut être ni intercepté, ni bloqué, ni ignoré » ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)). Le *shell* et le `revisor` meurent d'un coup.
4. Docker note `ExitCode=137`. Tu sais le lire depuis la Leçon 0 : 128 plus 9, et 9 est le numéro de `SIGKILL`.
5. Le journal ne compte qu'une seule ligne. Il n'indique pas `recibí terminated`, car le `revisor` n'a rien reçu, et il n'indique pas `apagado limpio`, car il ne s'est pas arrêté : on l'a tué au milieu de ce qu'il faisait. S'il était en train d'écrire un rapport à cet instant, le rapport est resté inachevé.

Remarque que le code du `revisor` est exactement le même dans les deux images. Il sait s'arrêter : il l'a démontré en quelques dixièmes de seconde. Ce qui a changé, c'est qu'avec un *shell* entre les deux, le signal ne lui est jamais parvenu. Et il ne vaut pas la peine de chercher à savoir comment se comporte le *shell* de chaque image de base : avec la forme *exec*, il n'y a pas de *shell* entre les deux et la question disparaît.

> [!NOTE]
> 🔧 **Observation de génie logiciel 3.4**
> Dix secondes, cela paraît peu. Multiplie-les : une mise à jour qui arrête vingt conteneurs l'un après l'autre perd plus de trois minutes à attendre, et dans chacun, ce qu'il était en train de faire est interrompu. Et le 137 pollue tes alertes : si chaque arrêt normal se termine par un 137, le jour où un conteneur mourra vraiment par manque de mémoire, avec le même 137, personne ne le remarquera.

#### 3.7.4 Quand un *shell* est vraiment nécessaire

Parfois, le démarrage a besoin de quelque chose que seul un *shell* fournit, comme lire une variable. La même page de la règle donne deux solutions qui restent honnêtes : écrire un petit script de démarrage et l'appeler en forme *exec*, ou déclarer le *shell* délibérément avec l'instruction `SHELL`. Dans les deux cas, le programme redevient enfant d'un *shell* et le signal redevient ta responsabilité, par exemple avec `exec` à la fin du script, qui remplace le *shell* par ton programme. Le `revisor` n'a besoin de rien de tout cela : il lit ses variables lui-même. La règle pratique de ce cours est donc la suivante : **`CMD` et `ENTRYPOINT`, toujours en forme *exec***.

### 3.8 Vérifier avant de construire : `docker build --check`

Ce que tu viens de mesurer au chronomètre, Docker peut le détecter en lisant la recette, sans rien construire. `docker build --check` exécute les **vérifications de construction** (*build checks*) : des règles qui recherchent des erreurs courantes dans le Dockerfile. La documentation indique qu'au lieu d'exécuter les étapes de construction, la commande « exécute uniquement les vérifications et rapporte ce qu'elle trouve », et qu'elles existent depuis la version 1.8 de la syntaxe du Dockerfile et Buildx 0.15.0 ([Docker, « Build checks »](https://docs.docker.com/build/checks/)). Ton Docker embarque une version bien plus récente. `fig03_08.sh` vérifie les deux Dockerfile de la leçon :

```bash
#!/usr/bin/env bash
# fig03_08.sh — Revisar los dos Dockerfile ANTES de construir, con
# docker build --check. No construye nada ni crea contenedores.
set -euo pipefail
# Nombres y puerto por omisión: los del curso. Se pueden cambiar para no chocar
# con otra corrida en el mismo equipo (PREFIJO=... PUERTO=... ./figNN.sh).
PREFIJO="${PREFIJO:-curso-docker-}"
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig03_06.Dockerfile" "$TRABAJO/revisor/Dockerfile.forma-shell"
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
t() {
  local x; x=$(date +%s%3N)
  case "$x" in *N) python3 -c 'import time; print(int(time.time() * 1000))' ;; *) echo "$x" ;; esac
}
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
trap 'rm -rf "$TRABAJO"' EXIT

titulo "Revisar el Dockerfile antes de construir"
muestra "docker build --check ."
muestra "docker build --check -f Dockerfile.forma-shell ."
```

Le premier, le bon :

```text
## Revisar el Dockerfile antes de construir
$ docker build --check .
#0 building with "colima" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 372B 0.0s done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.0s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie
#4 DONE 0.2s

#5 [internal] load .dockerignore
#5 transferring context: 127B 0.0s done
#5 DONE 0.0s
Check complete, no warnings found.
```

Les durées et le long *digest* après `dockerfile:1@sha256:` changent (ce *digest* est la version exacte de l'interpréteur de syntaxe que Docker a utilisée ce jour-là) ; changent aussi la taille en octets de `transferring dockerfile`, qui dépend des commentaires du fichier, et le nom du contexte sur la ligne `#0` (ici `colima` ; sur ton Mint, `default`). Ce qui est stable, c'est la séquence des étapes et la dernière ligne. Les étapes numérotées sont ce que BuildKit a fait : charger la recette (`#1`), résoudre l'interpréteur que demande la ligne `# syntax` (`#2` et `#3`), demander les informations de l'image de base sans la télécharger entièrement (`#4`) et lire le `.dockerignore` (`#5`). Il n'y a eu ni `COPY` ni `RUN` : rien n'a été construit. Et à la fin, `Check complete, no warnings found.`

Le second, celui de la forme *shell* :

```text
$ docker build --check -f Dockerfile.forma-shell .
#0 building with "colima" instance using docker driver

#1 [internal] load build definition from Dockerfile.forma-shell
#1 transferring dockerfile: 355B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.0s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie
#4 DONE 0.1s

#5 [internal] load .dockerignore
#5 transferring context: 127B done
#5 DONE 0.0s
Check complete, 1 warning has been found!

WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
--------------------
   8 |     USER 10001:10001
   9 |     EXPOSE 8080
  10 | >>> CMD revisor
  11 |     
--------------------
[código de salida: 1]
```

Voilà la scène du début, détectée avant de construire. L'avertissement comporte quatre parties. Le nom de la règle, `JSONArgsRecommended`, avec l'adresse de son explication. La phrase : « des arguments JSON sont recommandés pour `CMD` afin d'éviter des comportements indésirables liés aux signaux du système d'exploitation ». L'emplacement exact : `Dockerfile.forma-shell:10`. Et la ligne signalée par `>>>`. De plus, la commande se termine avec le **code 1** : la documentation précise que, contrairement à une construction normale, avec `--check` toute violation fait que la commande se termine avec un code différent de zéro. C'est ce qui la rend utile sur un serveur de construction : un avertissement arrête le processus au lieu de se perdre à l'écran.

Une construction **normale** (`docker build` sans `--check`) exécute aussi ces vérifications et affiche le même avertissement, mais elle se termine avec succès et construit l'image malgré tout. Il est facile de ne pas le voir parmi des centaines de lignes. C'est pourquoi l'habitude consiste à exécuter `--check` avant, délibérément. Et si tu veux qu'aucune construction ne passe avec des avertissements, le Dockerfile peut le déclarer sur sa deuxième ligne, juste après `# syntax`, avec `# check=error=true` : ainsi l'avertissement arrête aussi un `docker build` normal ([Docker, « Build checks »](https://docs.docker.com/build/checks/)).

### 3.9 Ce que tu trouveras dans les anciens tutoriels

Tu vas lire des Dockerfile écrits par d'autres, et certains contiennent des choses que ce cours n'utilise pas. Il vaut la peine de les reconnaître :

- **`MAINTAINER nom`.** Déclarait l'auteur de l'image. C'est obsolète : la référence indique que `LABEL` en est « une version beaucoup plus flexible » et qu'il faut l'utiliser à sa place, par exemple `LABEL org.opencontainers.image.authors="..."` ([référence, `MAINTAINER`](https://docs.docker.com/reference/dockerfile/#maintainer-deprecated)).
- **`ADD` pour copier des fichiers locaux.** `ADD` fait plus que `COPY` : il télécharge aussi depuis Internet et décompresse. Cette magie surprend. Le guide des bonnes pratiques utilise `COPY` pour copier et réserve `ADD` aux cas où tu as vraiment besoin de récupérer quelque chose de distant ([bonnes pratiques, `ADD` ou `COPY`](https://docs.docker.com/build/building/best-practices/#add-or-copy)). Dans ce cours, `ADD` n'est pas nécessaire.
- **`FROM quelquechose:latest` ou `FROM quelquechose` sans tag.** Tu sais déjà pourquoi non (3.3).
- **`CMD commande` et `ENTRYPOINT commande` en forme *shell*.** Tu sais déjà mesurer pourquoi non (3.7).
- **Installer `sudo` dans l'image.** Le guide le déconseille en raison de son comportement imprévisible avec les terminaux et avec la retransmission des signaux. Si quelque chose a besoin de `root` à la construction, cela se place avant le `USER` ; à l'exécution, cela ne devrait pas en avoir besoin.

## L'erreur que tu vas voir

Cette leçon comporte trois erreurs, de la moins grave à la plus grave. Tu les as déjà provoquées toutes les trois.

**1. L'avertissement de `docker build --check`.**

```text
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
```

Elle se lit ainsi : une règle n'est pas respectée (`JSONArgsRecommended`) ; son explication se trouve à l'adresse indiquée ; et la ligne 10 de `Dockerfile.forma-shell` est la coupable. On la corrige en remplaçant `CMD revisor` par `CMD ["revisor"]`. Si tu as vraiment besoin d'un *shell* au démarrage, consulte 3.7.4. Ce qu'on ne fait pas, c'est ignorer l'avertissement parce que « l'image s'est bien construite » : elle se construit bien et s'arrête mal.

**2. Le conteneur qui se termine avec 1 au démarrage.**

```text
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
curso-docker-revisor Exited (1) Less than a second ago
```

Elle se lit ainsi : le conteneur a démarré, le programme a lu sa configuration, n'a pas trouvé un élément obligatoire et s'est terminé de lui-même avec 1. Ce n'est un problème ni de l'image ni de Docker. La première question face à un `Exited (1)` juste après le démarrage est toujours `docker logs <conteneur>` : c'est presque toujours là que se trouve la cause, écrite par le programme lui-même. On la corrige en passant la variable avec `-e`.

**3. Le `docker stop` de 10 secondes et le code 137.**

```text
tardó 10485 ms
ExitCode=137
```

Elle se lit ainsi : le processus principal n'a pas traité `SIGTERM`, le délai a expiré et Docker l'a tué avec `SIGKILL` (137 = 128 + 9). Avant d'accuser le programme, regarde `docker top <conteneur>` : si la première ligne est `/bin/sh -c ...`, le signal est resté bloqué dans le *shell*. On la corrige avec `CMD` en forme *exec*. Il existe d'autres causes possibles à un 137 — le manque de mémoire de la Leçon 0 est l'autre grande cause, et on la reconnaît parce que `docker inspect` indique `OOMKilled=true` —, mais quand la durée de `docker stop` correspond exactement au délai, c'est le principal suspect. Ce qu'on **ne** fait **pas**, c'est augmenter le délai de `docker stop` pour qu'il « suffise » : un délai plus long ne fait qu'allonger l'attente, car le signal n'arrive toujours pas.

## L'habitude de sécurité de la leçon

**Le premier Dockerfile comporte déjà `USER`, `.dockerignore` et un tag avec version.** Les trois sont bon marché le premier jour et coûteux à ajouter ensuite, quand des conteneurs tournent déjà et que des gens en dépendent.

- **`USER 10001:10001`** évite qu'une faille dans le `revisor` — ou dans n'importe quelle bibliothèque qu'il utilise — donne à celui qui l'exploite l'utilisateur 0 de ton noyau. Tu l'as vérifié avec `docker exec ... id`.
- **`.dockerignore`** évite l'accident de 3.5 : un `.env`, une clé ou l'historique de `.git` glissés dans une image qui voyage ensuite vers d'autres ordinateurs. Tu l'as vérifié en regardant `/src` à l'intérieur de l'image.
- **Le tag avec version et le préfixe** évitent d'exécuter « n'importe quoi qui porte ce nom » : tu sais quelle image tourne et tu la supprimes sans toucher à ce qui appartient aux autres.

## Ce qui se fait de travers

**Écrire `CMD` en forme *shell* « parce que c'est plus facile à lire ».** C'est plus facile à lire et ça s'arrête plus mal : 10 secondes d'attente et un 137 à chaque `docker stop`. La forme *exec*, ce sont deux crochets et quelques guillemets.

**Utiliser `latest`, ou ne pas mettre de tag, ce qui revient au même.** `latest` ne veut pas dire « la plus récente » ; cela veut dire « sans tag ». Le jour du problème, tu ne sauras pas quelle version tournait.

**Nommer l'image avec un nom générique comme `revisor` ou `app`.** Il entre en collision avec les images d'autres projets sur le même ordinateur et leur prend leur nom sans prévenir.

**Laisser le Dockerfile sans `USER` parce que « c'est juste pour tester ».** Ce qui est pour tester finit en production avec le même Dockerfile. Cela coûte une ligne.

**`COPY . .` sans `.dockerignore`.** Tout le contenu du dossier voyage et reste dans l'image, y compris les fichiers que personne ne se souvient d'y avoir laissés.

**Utiliser `RUN` pour démarrer le service.** `RUN` s'exécute à la construction : la construction resterait à attendre le serveur indéfiniment. Ce qui s'exécute au démarrage du conteneur va dans `CMD`.

**Croire qu'`EXPOSE` publie le port.** Il se contente de le noter. Sans `-p` à l'exécution, personne de l'extérieur n'y accède. Et avec `-p`, le port se publie sur `127.0.0.1`, comme tu l'as appris dans la Leçon 2.

**Ignorer les avertissements de la construction.** Une construction normale affiche l'avertissement `JSONArgsRecommended` et se termine avec succès. Exécuter `docker build --check` avant transforme l'avertissement en une erreur impossible à ignorer.

## Exercices

Fais-les dans l'ordre. Avant d'exécuter chacun, écris dans ton [journal de bord](bitacora.md) ce que tu penses qu'il va se passer ; comparer ensuite représente la moitié de l'apprentissage. À la fin, supprime ce que tu as créé : tout porte le préfixe `curso-docker-`.

### Exercice 1 — À la construction ou à l'exécution ?

Sans regarder le tableau de 3.2.2, classe chaque ligne : agit-elle **à la construction**, se contente-t-elle de **noter quelque chose pour l'exécution**, ou les deux ?

1. `FROM golang:1.27.3-trixie`
2. `COPY . .`
3. `RUN go build -o /usr/local/bin/revisor ./cmd/revisor`
4. `USER 10001:10001`
5. `EXPOSE 8080`
6. `CMD ["revisor"]`

Et une question piège : si tu changes l'ordre et places `USER 10001:10001` **avant** le `RUN go build`, avec quel utilisateur s'exécute la compilation ?

### Exercice 2 — Ton propre `.dockerignore` (projet)

Travaille dans ton dossier `~/curso-docker/revisor` (celui du bloc « Dans ton dossier » de 3.6.1). Mets un moment de côté le `.dockerignore` de la leçon avec `mv .dockerignore ../dockerignore-leccion3` et crée là trois choses : un fichier `.env` avec un secret factice, un fichier `notas.md` et un dossier `secretos/` contenant un fichier. Construis `curso-docker-revisor:1.0.0-ej2` et liste `/src` à l'intérieur de l'image avec `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src`. Ensuite, écris un nouveau `.dockerignore` qui exclut les trois choses, en plus de tout ce qu'excluait celui de la leçon (tu l'as dans `../dockerignore-leccion3`), reconstruis avec le même tag et liste à nouveau. L'exercice s'autocorrige : tu as terminé quand `/src` affiche exactement `cmd`, `go.mod` et `internal`. À la fin, `docker rmi curso-docker-revisor:1.0.0-ej2`. Ton `.dockerignore` élargi peut rester : il exclut tout ce qu'excluait celui de la leçon et un peu plus, donc ton `curso-docker-revisor:1.0.0` ne change pas.

### Exercice 3 — Le chronomètre sur ton ordinateur

Exécute `fig03_05.sh` et `fig03_07.sh` sur ton Mint (après la Leçon 1 et avec l'image de Go téléchargée). Note dans ton journal de bord, sur la ligne que la Leçon 3 prévoit à cet effet, les deux durées de `docker stop`. Avant de les exécuter, prédis :

1. Laquelle des deux durées va le plus changer d'une exécution à l'autre, et laquelle va rester presque identique ?
2. Quel nombre va sortir dans `ExitCode` avec la forme *shell* ? Et quel nombre attendrais-tu avec la forme *exec*, sachant que le `revisor` est écrit pour se terminer avec 0 après un arrêt propre ? Vérifie-le en ajoutant, après le `docker stop` de `fig03_05.sh`, un `docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor`.

### Exercice 4 — Corrige le Dockerfile d'un autre

Un collègue te passe ce Dockerfile pour le `revisor`. Trouve **six** problèmes, cinq dans le fichier et un qui manque à côté de lui ; dis quel accident chacun peut causer et écris la version corrigée. Ensuite, vérifie la tienne avec `docker build --check` : elle doit afficher `Check complete, no warnings found.`

```dockerfile
FROM golang
MAINTAINER alguien@ejemplo.invalid
COPY . /src
RUN cd /src && go build -o /usr/local/bin/revisor ./cmd/revisor
EXPOSE 8080
CMD revisor
```

Indice : `docker build --check` trouve deux des six ; les quatre autres, c'est à toi de les trouver.

## Solutions

### Solution 1

1. **À la construction.** Apporte tout le contenu de l'image de base.
2. **À la construction.** Copie les fichiers du contexte dans l'image.
3. **À la construction.** Compile et laisse l'exécutable dans l'image. Ne s'exécute plus à l'exécution du conteneur.
4. **Les deux.** Note l'utilisateur avec lequel tournera le conteneur, et affecte en plus les `RUN` qui suivent dans le Dockerfile.
5. **Se contente de noter.** Ne publie rien (3.2).
6. **Se contente de noter** le processus que démarrera chaque conteneur.

La question piège : avec l'utilisateur **10001**, car `USER` change l'utilisateur de tout ce qui suit, y compris à la construction. Et la compilation échoue. Go tente de créer son cache dans le dossier personnel de l'utilisateur et, comme le 10001 n'existe pas dans `/etc/passwd`, ce dossier est `/`, où il ne peut pas écrire. Mesuré sur la machine de cette leçon avec `docker build --progress=plain` (le `#10` et le `0.881` sont le numéro d'étape et les secondes, et ils changent) :

```text
#10 0.881 failed to initialize build cache at /.cache/go-build: mkdir /.cache: permission denied
ERROR: failed to build: failed to solve: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Même si le cache fonctionnait, il ne pourrait pas non plus écrire dans `/usr/local/bin`. C'est pourquoi `USER` vient après la compilation.

### Solution 2

Un `.dockerignore` qui convient :

```text
.git
.env
*.tar
*.md
secretos/
Dockerfile*
.dockerignore
```

Avec lui, `ls -A /src` à l'intérieur de l'image n'affiche que `cmd`, `go.mod` et `internal`, comme le second bloc de `fig03_04.sh`. Si ta liste affiche encore `notas.md` ou `secretos`, vérifie que le motif est bien écrit et que le fichier `.dockerignore` se trouve à la racine du contexte, à côté du `Dockerfile`, et non dans un sous-dossier. Si `.dockerignore` ou `Dockerfile` apparaissent, il te manque les deux dernières lignes. Une variante également valable consiste à remplacer `*.md` par `notas.md` : elle n'exclut que ce fichier. Celle du dessus est plus prévoyante, car le `revisor` n'a besoin d'aucun `.md` pour être compilé.

### Solution 3

1. La durée de la forme *exec* change davantage d'une exécution à l'autre (des dizaines ou des centaines de millisecondes, selon la charge de ton ordinateur) ; celle de la forme *shell* reste presque identique, toujours un peu au-dessus de 10 000 ms, car il s'agit presque entièrement du délai fixe de `docker stop`.
2. Avec la forme *shell*, `ExitCode=137`, comme dans `fig03_07.sh`. Avec la forme *exec*, `ExitCode=0` : le `revisor` reçoit `SIGTERM`, écrit `apagado limpio` et son code se termine avec 0. Si ton exécution donne un autre nombre, regarde `docker logs` : si `apagado limpio` n'apparaît pas, le signal n'est pas arrivé, et le premier suspect est que ton Dockerfile utilise la forme *shell*.

### Solution 4

Les cinq problèmes du fichier :

1. **`FROM golang` sans tag**, ce qui équivaut à `golang:latest` : chaque construction peut utiliser une autre version de Go. Correction : `FROM golang:1.27.3-trixie`.
2. **`MAINTAINER`**, obsolète. Correction : le supprimer, ou utiliser `LABEL org.opencontainers.image.authors="..."`.
3. **`RUN cd /src && ...` au lieu de `WORKDIR`.** Cela fonctionne sur cette ligne, mais le `cd` est perdu ensuite, et le conteneur démarre dans `/`. Correction : `WORKDIR /src` et `COPY . .`.
4. **Pas de `USER`** : le `revisor` tournerait en tant que `root`. Correction : `USER 10001:10001` après la compilation.
5. **`CMD revisor` en forme *shell*** : 10 secondes et un 137 à chaque `docker stop`. Correction : `CMD ["revisor"]`. C'est exactement ce que signale `docker build --check`.

Et le sixième, celui qui n'est pas dans le fichier : **il manque le `.dockerignore`**, et avec `COPY . /src` tout le contexte entre dans l'image. La version corrigée est le `fig03_01.Dockerfile` de cette leçon plus le `fig03_03.dockerignore`.

`docker build --check .` sur le Dockerfile d'origine trouve deux des six. Mesuré sur la machine de cette leçon (seules les lignes des avertissements sont affichées) :

```text
Check complete, 2 warnings have been found!
WARNING: MaintainerDeprecated - https://docs.docker.com/go/dockerfile/rule/maintainer-deprecated/
Maintainer instruction is deprecated in favor of using label
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
```

`MaintainerDeprecated` correspond au problème 2 : la règle indique que `MAINTAINER` est obsolète et qu'il faut utiliser un label (`LABEL`) à sa place ([Docker, `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/)). `JSONArgsRecommended` correspond au problème 5. Les quatre autres (`latest`, le `cd`, l'absence de `USER` et celle du `.dockerignore`) ne sont détectés par aucune des règles exécutées ici : c'est pourquoi `--check` aide mais ne remplace pas la lecture de la recette. Ta version doit afficher `Check complete, no warnings found.`

## Comment je sais que j'ai réussi

Coche chaque point uniquement si tu l'as vérifié sur ton ordinateur :

- [ ] `docker build --check .` dans `~/curso-docker/revisor` se termine par `Check complete, no warnings found.` et le code 0.
- [ ] `docker image ls 'curso-docker-revisor'` affiche `curso-docker-revisor` avec le tag `1.0.0`, et tu as noté sa taille dans ton journal de bord (lors de l'exécution de cette leçon, 1,45 Go).
- [ ] Sans `REVISOR_SERVICIOS`, le conteneur reste en `Exited (1)` et `docker logs` indique ce qui manque.
- [ ] Avec la variable, `curl -s http://127.0.0.1:8080/salud` répond `{"estado":"vivo","version":"desarrollo"}`.
- [ ] `docker exec curso-docker-revisor id` indique `uid=10001 gid=10001 groups=10001`.
- [ ] `docker top curso-docker-revisor -o pid,user,args` affiche **un seul** processus, `revisor`.
- [ ] `docker stop curso-docker-revisor` prend moins d'une seconde et `docker logs` se termine par `revisor: apagado limpio`.
- [ ] Avec l'image en forme *shell*, tu as mesuré les 10 secondes et le 137, et tu sais expliquer pourquoi avec `docker top`.
- [ ] À l'intérieur de l'image, `ls -A /src` n'affiche ni `.env`, ni `.git`, ni `Dockerfile`.
- [ ] À la fin, `docker ps -a --filter name=curso-docker-revisor` n'affiche rien, et `docker image ls 'curso-docker-revisor'` n'affiche que `curso-docker-revisor:1.0.0`, celle que tu as construite dans ton dossier et qu'utilise la Leçon 4.

## Résumé

Réponds sans regarder la leçon :

1. Qu'est-ce qu'un Dockerfile, qu'est-ce que le contexte et qui fait le travail de construction ?
2. Quelles instructions agissent à la construction et lesquelles se contentent de noter quelque chose pour l'exécution ?
3. Que signifie vraiment le tag `latest` ? Pourquoi l'image du cours s'appelle-t-elle `curso-docker-revisor:1.0.0` et non `revisor:1.0.0` ?
4. Avec quel utilisateur tourne une image si personne n'a écrit `USER` ? Pourquoi un numéro suffit-il ?
5. Que fait `.dockerignore` et qu'arrive-t-il à un `.env` si tu n'en as pas ?
6. Quelle différence y a-t-il entre `CMD ["revisor"]` et `CMD revisor` ? Que montre `docker top` dans chaque cas ?
7. Pourquoi, avec la forme *shell*, `docker stop` prend-il 10 secondes et laisse-t-il un 137 ? Qu'est-ce que le 137 ?
8. Que fait `docker build --check` et avec quel code se termine-t-il s'il trouve quelque chose ?

## Sources

Toutes consultées le 21 octobre 2026.

- [Référence du Dockerfile](https://docs.docker.com/reference/dockerfile/) : les instructions `FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`, `ENTRYPOINT` et `MAINTAINER` ; les formes *shell* et *exec* ; la directive `syntax`.
- [Docker, « Build context »](https://docs.docker.com/build/concepts/context/) : le contexte de construction et les fichiers `.dockerignore`.
- [Docker, « Build checks »](https://docs.docker.com/build/checks/) : `docker build --check`, son code de sortie et les versions minimales.
- [Docker, règle `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/) : l'avertissement concernant `MAINTAINER` de l'exercice 4.
- [Docker, règle `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/) : pourquoi la forme *shell* ne transmet pas les signaux, et les deux alternatives quand un *shell* est nécessaire.
- [Docker, bonnes pratiques pour construire des images](https://docs.docker.com/build/building/best-practices/) : `USER`, `sudo`, `ADD` contre `COPY`, tags mutables et `.dockerignore`.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/) : `SIGTERM`, le délai de 10 secondes et `SIGKILL`.
- [`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/) : les parties du nom d'une image et le tag `latest` par défaut.
- [Docker, « Running containers »](https://docs.docker.com/engine/containers/run/) : remplacer le `CMD` depuis `docker run`.
- [golang sur Docker Hub](https://hub.docker.com/_/golang) : le tag `1.27.3-trixie` et ses alias, et la signification de *trixie*.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions citées dans « À propos des exécutions ».
- [pid_namespaces(7), manuel de Linux](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html) : les signaux que peut recevoir le processus numéro 1 d'un espace de noms.
- [signal(7), manuel de Linux](https://man7.org/linux/man-pages/man7/signal.7.html) : les numéros de `SIGTERM` (15) et de `SIGKILL` (9), et le fait que `SIGKILL` ne peut pas être intercepté.
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **BuildKit** | le constructeur d'images qu'utilise Docker ; il fait partie du daemon |
| **contexte de construction** | les fichiers que la construction peut utiliser ; presque toujours, un dossier |
| **Dockerfile** | la recette texte avec laquelle on construit une image |
| **`.dockerignore`** | la liste de ce qui ne voyage pas dans le contexte et ne peut pas entrer dans l'image |
| **tag** | la partie du nom d'une image après les deux-points ; elle indique de quelle version il s'agit |
| **forme *exec*** | instruction écrite comme une liste JSON : `CMD ["revisor"]` ; démarre le programme sans *shell* |
| **forme *shell*** | instruction écrite comme du texte : `CMD revisor` ; `/bin/sh -c` l'enveloppe |
| **image de base** | l'image dont part une autre, celle du `FROM` |
| **`latest`** | le tag que Docker attribue quand aucun n'est fourni ; il ne signifie pas « la plus récente » |
| **PID 1** | le premier processus d'un conteneur ; celui qui reçoit le signal de `docker stop` |
| **vérification de construction** (*build check*) | règle qui recherche des erreurs courantes dans un Dockerfile sans le construire |
| **`SIGTERM`** | le signal 15 : « termine, s'il te plaît » ; celui qu'envoie d'abord `docker stop` |
| **`SIGKILL`** | le signal 9 : mort immédiate ; ne peut pas être intercepté ; laisse le code 137 |

---

**Suivante :** [Leçon 4 — Couches, cache et contexte](04-capas-cache-contexto.md)
