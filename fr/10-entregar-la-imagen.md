# Leçon 10 — Livrer l'image

Il est 17 h 20, un vendredi. Lundi à 9 h 00 commence le cours de Kubernetes de ton équipe, et l'instructeur veut que chaque personne charge dans son cluster **la même image du `revisor`**, celle que tu as déjà testée. Mardi, tu as envoyé à ton collègue Tomás la commande `docker run curso-docker-revisor:1.6.0`, et elle a fonctionné pour lui. Mercredi, tu as trouvé une petite erreur, tu as reconstruit l'image et tu l'as poussée de nouveau avec le même tag, `1.6.0`, parce que « c'est la même version, j'ai juste corrigé un détail ». Aujourd'hui, vendredi, Tomás t'écrit : « chez moi, le rapport sort différemment du tien ». Vous avez tous les deux une image qui porte exactement le même nom. Tu vérifies, et ni l'un ni l'autre ne sait dire laquelle des deux est la bonne. Et ce n'est pas tout : la personne qui veille sur la sécurité de l'équipe pose trois questions auxquelles tu ne sais pas répondre avec certitude. Que contient cette image ? Avec quoi a-t-elle été construite, et d'où vient chaque composant ? A-t-elle un composant affecté par une faille connue ? Il est 17 h 34. Tomás utilise un processeur différent du tien, donc tu n'es même pas sûr que l'image que tu as construite sur ta machine *fonctionne* sur la sienne. La question n'est plus de savoir comment on construit une image, mais **comment on livre une image pour que celui qui la reçoit sache exactement laquelle c'est, ce qu'elle contient, d'où elle vient et sur quelles machines elle tourne**. Cette leçon existe pour que, lundi, au lieu de « je te l'ai envoyée, je crois que c'est la bonne », tu puisses dire : « voici son digest, voici sa nomenclature logicielle, voici l'analyse du jour, et il y a un binaire pour chaque processeur, avec la preuve que celui de `amd64` démarre ».

**Durée :** 2 × 45 min

**Ce que tu construis :** la livraison de l'image du `revisor`, version 1.6.0, en cinq mouvements. Un registre local qui n'écoute que sur `127.0.0.1`. Un `Dockerfile` qui compile le même binaire pour deux processeurs (`linux/amd64` et `linux/arm64`) sans émulation. Une publication de cette image avec sa **nomenclature logicielle** (SBOM) et sa **provenance**, que tu peux lire avec une commande. Une analyse de vulnérabilités avec Trivy, faite sans donner à Trivy le *socket* de Docker. Et le pont vers le cours suivant : l'image chargée dans un cluster `kind` avec `kind load docker-image`, et un pod qui démarre sans essayer de télécharger quoi que ce soit.

**Ce que tu apprends :** ce qu'est un registre et comment se compose une référence d'image ; la différence entre un **tag**, qui peut être déplacé, et un ***digest***, qui ne le peut pas ; ce qu'est un index d'images et pourquoi un même tag peut apporter plusieurs processeurs ; les trois façons de construire pour plusieurs plateformes et pourquoi on utilise ici la compilation croisée ; ce que sont les attestations, et comment lire une SBOM et une provenance (modes `min` et `max`, et ce que `max` expose) ; ce qu'on peut attendre, et ce qu'on ne peut pas attendre, d'une reconstruction « identique » ; comment récupérer une image **par digest** et l'exécuter durcie ; comment analyser avec Trivy, ce qu'est un seuil et pourquoi `UNKNOWN` compte aussi dans le code de sortie ; comment accepter un constat par écrit ou le résoudre en renouvelant la base ; et comment amener l'image dans un cluster `kind` sans registre.

**D'où tu viens.** De la [Leçon 9](09-compose.md), tu apportes le système complet dans un `compose.yaml` et l'état de la [Leçon 8](08-volumenes-y-redes.md) : une image de moins de vingt mégaoctets, sans shell, sans `root`, qui enregistre son rapport dans `/datos`, un dossier qui appartient à l'utilisateur `65532`. De la [Leçon 7](07-salud-y-ciclo-de-vida.md), le durcissement avec lequel on l'exécute (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`). De la [Leçon 5](05-multi-stage.md), l'habitude de figer la base par version et par *digest* : aujourd'hui, tu vas voir ce que coûte cette habitude et comment on la paie. De la [Leçon 2](02-contenedores-dia-a-dia.md), publier les ports uniquement sur `127.0.0.1` et ne pas donner le *socket* de Docker à un conteneur : cette habitude décide de la façon dont tu analyses dans cette leçon. Ton dossier contient `revisor/` avec son `Dockerfile`, son `.dockerignore` et `secretos/`, et, à côté, `servicio-prueba/`.

**Ce que cette leçon ne fait pas.** Elle ne publie rien dans un registre public : ni Docker Hub, ni un autre. Tout se passe dans un registre que tu démarres toi-même, sur ta machine, accessible uniquement depuis ta machine, et qui est supprimé à la fin. Elle ne met pas en place un registre de production : cela demande TLS et un contrôle d'accès, et la documentation du registre lui-même l'exige (la section 10.1.1 la cite). Elle ne signe pas les images : une signature cryptographique répond à la question « qui l'a publiée ? », et la leçon s'en tient aux questions « laquelle est-ce ? », « qu'apporte-t-elle ? » et « comment a-t-elle été faite ? ». Elle ne promet pas qu'une image analysée soit une image sûre : l'analyse vérifie ce que ses bases de données connaissent **aujourd'hui**, et la section 10.10 explique ce que signifie un « 0 » et ce qu'il ne signifie pas. Elle ne modifie pas le `compose.yaml` de la leçon précédente, qui construit toujours la 1.5.0 : la 1.6.0 de cette leçon est l'image livrée au cours suivant, et la seule différence avec la 1.5.0 est le `Dockerfile` qui compile pour deux processeurs. Et elle ne déploie rien dans Kubernetes : le dernier mouvement amène seulement l'image jusqu'à la porte du cluster et vérifie que le pod démarre ; le reste, c'est l'objet du [cours de Kubernetes avec kind](https://www.habil.mx/fr/cours/kubernetes/) de Hábil.

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026. Voici ce que tu dois savoir sur leur provenance, pour les comparer aux tiennes :

- **La machine.** Un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4 (la même base que Linux Mint 22, le système de référence du cours), un noyau 6.8 et un processeur `arm64`. Les scripts de registre, de construction et d'analyse ont été exécutés **à l'intérieur** de cette machine virtuelle, avec Docker 29.2.1 (client et daemon), Buildx v0.31.1 et BuildKit v0.27.1. L'étape de `kind` (section 10.11) a été exécutée **sur le Mac**, où se trouvent `kind` v0.33.0 et `kubectl` v1.37.1, contre le même daemon.
- **Les versions du cours.** Il a été planifié avec Docker Engine 29.8.2 (mesurée le 7 octobre), et le jour des exécutions, la plus récente publiée était la 29.9.2, du 20 octobre ([notes de version](https://docs.docker.com/engine/release-notes/29/)). Une installation d'aujourd'hui apporte donc un Buildx et un BuildKit plus récents que ceux de ces exécutions : si un texte d'erreur ou une version d'outil diffère, compare-le par son sens, et vérifie les tiens avec `docker version` et `docker buildx version`. Le scanner est **Trivy 0.76.0**, publié le 14 octobre 2026 ([notes de version](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)) ; le registre est l'image officielle `registry:3.1.2`.
- **Le magasin d'images.** Le Docker de cette machine utilise le magasin de *containerd* (`docker info` indique `Storage Driver: overlayfs` avec `driver-type: io.containerd.snapshotter.v1`), dont la section 10.1.4 explique pourquoi il importe et comment le vérifier sur ta machine.
- **L'émulation.** Sur cette machine, **compiler Go émulé pour `amd64` n'a pas fonctionné** (la section 10.4 montre l'échec et ce qu'il signifie), alors que **démarrer** le binaire `amd64` déjà compilé a bien fonctionné (section 10.9.2). Sur ton Mint avec un processeur `amd64`, la plateforme étrangère serait `arm64` et peut te donner un autre résultat.
- **Les noms.** Pour ne pas toucher à ce qui est à toi, les scripts utilisent des noms d'appoint (le registre `curso-docker-registro-fig10`, l'image `curso-docker-revisor:fig10`, le volume `curso-docker-trivy-cache-fig10`, le cluster `curso-docker-puente-fig10`), construisent avec un tag à eux et, en sortant, suppriment **par nom**, jamais par identifiant ; ceux qui publient un port vérifient avant de démarrer qu'il est libre et, s'il ne l'est pas (par exemple parce que tu as déjà ton registre), s'arrêtent au lieu de pousser vers un registre qui n'est pas le leur : `fig10_02.sh` vérifie le 5000 et le 8080 ; `fig10_04.sh`, `fig10_08.sh` et `fig10_09.sh` vérifient seulement le 5000, qui est le seul qu'ils publient ; `fig10_00.sh`, `fig10_05.sh`, `fig10_06.sh` et `fig10_07.sh` ne publient aucun port fixe et n'en vérifient aucun. Cette exécution les a de plus lancés avec le préfixe `curso-docker-l10-` et les ports 18100 et 18101, parce que d'autres leçons tournaient sur la même machine ; une fonction `nombres`, visible dans chaque script, réécrit ce préfixe en `curso-docker-` et les ports en `5000` et `8080`. Avec les valeurs par défaut, elle ne change rien. Dans ton dossier, le registre s'appellera `curso-docker-registro` et l'image `curso-docker-revisor:1.6.0`.
- **Ce qui change d'une exécution à l'autre**, et c'est signalé là où cela apparaît : les *digests* (ils dépendent de l'heure de construction), les durées (une seconde, soixante-cinq : elles dépendent de ce qu'il y avait dans le cache), les tailles de fichier en dixièmes de mégaoctet, les dates de la base de données de Trivy, les versions des outils qui signent la SBOM (`syft` et BuildKit, dans le champ `creators`), le nombre de paquets de la SBOM et les messages exacts de l'émulation qui échoue.

Les programmes se trouvent dans [`programas/10-entregar-la-imagen/`](../programas/10-entregar-la-imagen), chacun avec sa sortie à côté, et `estado/` conserve les fichiers du projet tels qu'ils sont à la fin.

## À la fin, tu seras capable de

- Démarrer un registre local uniquement sur `127.0.0.1`, y publier une image et lister son contenu avec `curl` contre son API.
- Expliquer, avec une mesure à toi, pourquoi un tag n'identifie pas une image et un *digest* si, puis récupérer et exécuter une image **par digest**.
- Convertir le `Dockerfile` de la Leçon 8 en un `Dockerfile` qui compile pour `linux/amd64` et `linux/arm64` sans émulation, et vérifier pour quel processeur chaque binaire a été produit en lisant ses octets.
- Publier un index de deux plateformes avec SBOM et provenance en mode `max`, et lire avec `docker buildx imagetools inspect` les paquets qu'il contient, avec quoi il a été construit, et quelles données du constructeur restent exposées.
- Analyser l'image avec Trivy à partir d'un fichier produit par `docker save`, sans monter le *socket* de Docker, et lire le résultat avec son seuil et son code de sortie.
- Trancher sur un constat : l'accepter par écrit dans un `.trivyignore`, avec la raison et la date, ou le résoudre en renouvelant le *digest* de la base, puis vérifier le résultat.
- Charger l'image dans un cluster `kind` avec `kind load docker-image` et expliquer pourquoi le pod démarre avec `imagePullPolicy: Never`.

## Le pourquoi avant le comment

Jusqu'à présent, l'image vivait là où tu la construisais : dans le magasin d'images de ton propre Docker. Tant qu'il en est ainsi, « l'image » reste une affaire entre toi et ton équipe. La livrer, c'est la sortir de là, et dès qu'elle sort, quatre problèmes apparaissent qui n'existaient pas.

Le premier est **le nom qui ment**. La scène du début n'est pas une étourderie rare : c'est la conséquence directe du fait que `curso-docker-revisor:1.6.0` est un *tag*, une étiquette collée sur une image, et qu'une étiquette peut se décoller et se recoller sur une autre. Celui qui reçoit le nom ne reçoit aucune garantie. Il nous faut un moyen de désigner *cette* image et non « celle qui porte cette étiquette en ce moment ». Ce moyen existe, il s'appelle *digest*, et tu vas le mesurer dans la section 10.3.

Le deuxième est **le processeur**. Une image contient un binaire déjà compilé, et un binaire compilé pour `arm64` (le Mac de la scène, et beaucoup de serveurs dans le cloud) ne tourne pas sur `amd64` (le Mint de ton collègue, et la plupart des serveurs). L'image de la Leçon 8 a été construite pour le processeur de celui qui l'a construite, et rien de plus. La livrer à une autre équipe exige de pouvoir dire « en voici une pour chaque processeur, sous le même nom ». Et la construire deux fois comporte son propre risque : si l'une des deux constructions tourne émulée, elle peut être extrêmement lente ou, comme tu le verras, ne pas fonctionner du tout.

Le troisième est **la boîte noire**. Une image est un fichier que quelqu'un te passe et que tu vas exécuter avec des permissions sur ta machine puis, plus tard, dans un cluster partagé. Avant de l'exécuter, on veut savoir ce qu'elle contient (nomenclature logicielle), d'où vient chaque composant et avec quelles instructions elle a été assemblée (provenance), et si l'un de ses composants a une faille publique connue (analyse). Il n'est pas nécessaire de se méfier de qui que ce soit pour demander ces trois choses : les demander est la façon normale de travailler quand quelque chose va tourner là où cela compte.

Le quatrième est **la porte d'entrée du cluster**. Dans le cours suivant, le `revisor` doit arriver dans un cluster. Un cluster ne voit pas le magasin d'images de ton Docker : il a le sien. Il faut décider comment l'image y arrive, et dans un laboratoire local, la réponse tient en une ligne (`kind load docker-image`), avec un piège que tu vas provoquer exprès pour le lire.

Qu'il ne s'agisse pas d'une exagération de manuel pour le troisième problème, un cas public le montre. Le 1er avril 2021, un client de Codecov, un service de couverture de tests, a remarqué que le *script* qu'il téléchargeait depuis l'entreprise pour envoyer ses résultats n'avait pas la même somme de contrôle (*shasum*) que celle publiée sur GitHub. Il a donné l'alerte, et l'entreprise a découvert que quelqu'un avait modifié ce *script* sans autorisation depuis le 31 janvier : la ligne altérée envoyait à un serveur étranger l'environnement complet des machines d'intégration continue où il tournait, avec les identifiants qui pouvaient s'y trouver. L'entreprise a recommandé, entre autres, de renouveler les identifiants de quiconque l'aurait utilisé sans valider la somme ([Codecov, « Bash Uploader Security Update »](https://about.codecov.io/security-update/)). Ce n'était pas une image de conteneur, c'était un *script*, mais le mécanisme qui l'a trahi est exactement celui de cette leçon : **comparer l'empreinte de ce que tu as reçu avec l'empreinte de ce qui a été publié**. Celui qui comparait la somme avec celle publiée sur GitHub pouvait détecter l'altération ; le client qui l'a fait l'a signalée le 1er avril, deux mois après le début des altérations, et les utilisateurs touchés ont été prévenus le 15 avril. Un *digest* sert comme cette somme, avec une condition que le cas laisse voir : l'empreinte doit arriver par un canal différent de celui de ce qu'on télécharge. La somme de Codecov était sur GitHub et le *script* était servi depuis un autre site. Il en va de même avec les images : c'est toi qui passes le *digest* à Tomás par ton canal, et il ne le prend pas dans le même registre que celui qui lui sert l'image.

Cette leçon résout les quatre avec des outils que tu as déjà. Presque tout est fait par `docker buildx`, qui vient avec l'installation de la Leçon 1. Un registre est un programme comme un autre, et c'est pourquoi on le démarre dans un conteneur. Le seul programme nouveau est Trivy, et il tourne lui aussi dans un conteneur, avec l'habitude de la Leçon 2 : on ne lui donne pas le *socket* de Docker. Avec cette destination en tête, voici ce que tu auras à la fin de la section 10.9 : l'image publiée, récupérée de nouveau **par son digest**, comme le ferait une machine qui ne l'a pas construite (le script supprime d'abord les copies locales laissées par la construction et le vérifie), en cours d'exécution, durcie :

```text
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

(C'est la fin de `fig10_02.sh`. Le conteneur a été créé avec la référence `…@sha256:…` : plus avec un tag.) Et voici l'objectif du cours qui revient à cette leçon, le sixième du README : l'image publiée est référencée par *digest*, passe l'analyse de Trivy avec le seuil que tu as fixé et se charge dans un cluster `kind` sans une seule erreur de téléchargement.

## Les concepts

### 10.1 Ce qu'est un registre et comment on lit le nom d'une image

#### 10.1.1 Un registre est un serveur d'images

Un **registre** (en anglais *registry*) est un service qui stocke des images et les remet à qui les demande. Tu l'as utilisé sans y penser : chaque fois qu'un `FROM golang:1.27.3-trixie` ou un `docker pull` a ramené quelque chose d'internet, un registre a répondu. Le service parle un protocole HTTP standard, et c'est la raison pour laquelle cette leçon peut en démarrer un à toi avec un conteneur et lui parler avec `curl`. Le projet open source qui l'implémente s'appelle *Distribution*, et son image officielle s'appelle `registry`. Sa documentation le présente avec une commande d'une ligne pour le démarrer (`docker run -d -p 5000:5000 --restart=always --name registry registry:3`) et avec un avertissement qu'il vaut mieux lire en entier : les premiers exemples sont « adaptés uniquement aux tests », et « un registre prêt pour la production doit être protégé par TLS et, idéalement, utiliser un mécanisme de contrôle d'accès » ([Distribution, « Deploy a registry server »](https://distribution.github.io/distribution/about/deploying/)). C'est pourquoi, dans cette leçon, le registre vit sur `127.0.0.1` et est supprimé à la fin. Si un jour tu publies vers d'autres machines, tu auras besoin de TLS, et c'est un sujet d'infrastructure que ce cours ne couvre pas.

#### 10.1.2 Les parties d'une référence

Une **référence** à une image est le texte que tu donnes à Docker pour en désigner une. Elle comporte jusqu'à quatre parties, et presque toute erreur du type « mon image est introuvable » vient d'une partie mal écrite :

```text
localhost:5000 / curso-docker-revisor : 1.6.0
    registre         dépôt                 tag

localhost:5000 / curso-docker-revisor @ sha256:59e431fa44c7…
    registre         dépôt                 digest
```

- Le **registre** est l'endroit où elle se trouve : un nom de machine avec un port facultatif. Si tu n'en écris aucun, Docker suppose Docker Hub. Dans cette leçon, c'est toujours `localhost:5000`.
- Le **dépôt** (*repository*) est le nom de l'image dans le registre : `curso-docker-revisor`. Un dépôt conserve toutes les versions d'une image.
- Le **tag** est un nom lisible pour une version : `1.6.0`. C'est, comme le dit la documentation de Kubernetes, quelque chose qui peut changer : « les tags peuvent être déplacés pour pointer vers d'autres images, mais les *digests* sont fixes » ([Kubernetes, « Images »](https://kubernetes.io/docs/concepts/containers/images/)).
- Le ***digest*** est une empreinte du contenu, au format `sha256:` suivi de soixante-quatre caractères hexadécimaux. La même page le définit ainsi : « les *digests* sont des hachages du contenu de l'image, et ils sont immuables ».

Quand une référence porte un tag **et** un *digest* à la fois, la page de Kubernetes est explicite sur celui qui l'emporte : « seul le *digest* sera utilisé pour le téléchargement ». Le tag reste un commentaire pour les humains. C'est la raison pour laquelle, plus tard, dans un manifeste ou dans un `compose.yaml` où il importe de savoir ce qui s'exécute, il convient d'écrire `dépôt:1.6.0@sha256:…` : toi, tu lis la version, et la machine vérifie le contenu.

#### 10.1.3 Ce qu'un registre stocke vraiment

Avant de démarrer le registre, il faut savoir ce que tu vas lui envoyer, parce que cela change la façon de lire les sorties de la leçon. Un registre ne stocke pas des « images » isolées ; il stocke des **manifestes** et des **blobs**. Un *blob* est un fichier anonyme identifié par son *digest* (une couche compressée, ou le fichier de configuration de l'image). Un **manifeste** est un petit document au format JSON qui liste les blobs qui forment une image. Et au-dessus des manifestes peut se trouver un **index** (*image index*) : selon la spécification de l'Open Container Initiative, c'est « un manifeste de plus haut niveau qui pointe vers des manifestes d'image spécifiques », avec un champ obligatoire `manifests` qui est « une liste de manifestes pour des plateformes spécifiques », et chaque entrée peut porter un objet `platform` avec l'architecture (`architecture`, avec les noms de `GOARCH` de Go) et le système d'exploitation (`os`, avec ceux de `GOOS`) ([OCI, « Image Index »](https://github.com/opencontainers/image-spec/blob/main/image-index.md)). En termes de tous les jours : un **tag** pointe vers un **index** ; l'index dit « pour `amd64`, regarde ce manifeste, pour `arm64`, regarde celui-là » ; chaque manifeste liste ses couches. Quand tu fais un `docker pull` sur une machine `amd64`, Docker lit l'index, choisit l'entrée qui correspond à son processeur et ne télécharge que celle-là. Cette structure, tu vas la voir imprimée, pour de vrai, dans la section 10.5.

Et il existe un troisième type d'entrée dans l'index, qui n'est pas une image mais un *document sur* une image : les **attestations**. Elles sont expliquées en 10.6.

#### 10.1.4 Avant de commencer : le magasin d'images de ton Docker

Presque tout ce qui suit (publier un index de deux plateformes avec des attestations, enregistrer une plateforme avec `docker save --platform`, voir l'arborescence avec `docker image ls --tree`) dépend d'un détail de ton installation : quel **magasin d'images** utilise ton Docker. Docker 29 en a deux : le classique, avec des pilotes comme `overlay2`, et celui de *containerd*. La documentation dit que celui de *containerd* est le stockage par défaut de Docker Engine 29.0 et des versions suivantes **dans les nouvelles installations**, et que si tu viens d'une version antérieure, ton daemon « continue d'utiliser les pilotes hérités (`overlay2`) jusqu'à ce que tu actives » celui de *containerd* ; parmi ses avantages, elle énumère le stockage local d'images de plusieurs plateformes et le travail avec des images qui portent des attestations ([Docker, « containerd image store »](https://docs.docker.com/engine/storage/containerd/)). Vérifie-le ainsi :

```bash
docker info -f '{{ .DriverStatus }}'
```

Sur la machine des exécutions, la réponse a été `[[driver-type io.containerd.snapshotter.v1]]` (c'est le bloc 1 de `fig10_00.sh`, avec sa sortie à côté), ce que la documentation dit voir apparaître quand le magasin de *containerd* est actif. Si, sur ta machine, cette ligne n'apparaît pas (tu verras quelque chose avec `overlay2`), la même page indique de l'activer en ajoutant `{"features": {"containerd-snapshotter": true}}` à `/etc/docker/daemon.json` et en redémarrant le daemon avec `sudo systemctl restart docker`. Un avertissement honnête : cette leçon **n'a pas testé** ses commandes avec le magasin classique, donc si tu le gardes, les étapes des sections 10.5 et 10.9 peuvent échouer ou donner une autre sortie ; active celui de *containerd* avant de continuer.

### 10.2 Un registre local, uniquement sur `127.0.0.1`

#### 10.2.1 Le démarrer

C'est un conteneur comme un autre, avec l'habitude de la Leçon 2 : le port est publié **uniquement sur `127.0.0.1`**, pour que personne d'autre sur ton réseau ne puisse lui pousser ni lui demander quoi que ce soit. La première partie de `fig10_02.sh` fait exactement cela, attend qu'il réponde et lui demande quels dépôts il contient :

```text
$ ./fig10_02.sh
== 1. Un registro local, publicado solo en 127.0.0.1
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba
$ curl -s http://127.0.0.1:5000/v2/_catalog
{"repositories":[]}
$ docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'
{"/var/lib/registry":{}}
```

Lis-le ligne par ligne. `-p 127.0.0.1:5000:5000` dit « le port 5000 de ma machine, uniquement par l'adresse `127.0.0.1`, mène au port 5000 du conteneur ». L'image est figée sur `registry:3.1.2`, une version précise et non `registry:3` ni `latest`, pour la même raison que chaque image de ce cours : dans six mois, le tag flottant apporterait autre chose. Le `>/dev/null` cache le long identifiant qu'imprime `docker run -d`, et le `echo` confirme que la commande s'est bien terminée. Ensuite, `/v2/_catalog` est un point de l'API standard des registres qui liste les dépôts, et `/v2/` tout seul est la façon de demander « es-tu vivant et parles-tu le protocole ? » (les scripts l'utilisent pour attendre qu'il démarre). La réponse `{"repositories":[]}` est celle d'un registre tout juste né : le JSON est valide, le tableau est vide. Il n'a rien parce que tu ne lui as encore rien poussé.

Un détail de nettoyage qu'il faut connaître : l'image `registry` déclare un volume dans `/var/lib/registry` (on peut le vérifier avec `docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'`, qui répond `{"/var/lib/registry":{}}`). Comme dans la Leçon 8 nous ne l'avons pas nommé, Docker en crée un **anonyme**, et un `docker rm` tout court le laisse orphelin sur le disque. C'est pourquoi les scripts suppriment le registre avec `docker rm -f -v` : le `-v` emporte le volume anonyme avec le conteneur. C'est le même genre de déchet que la Leçon 2 t'a appris à ne pas laisser.

#### 10.2.2 Publier sans TLS, et pourquoi c'est possible ici

Tu auras remarqué que pousser vers `localhost:5000` ne demande ni certificat ni mot de passe. Ce qui **a été mesuré**, c'est cela : le `docker push` de la section suivante fonctionne contre `localhost:5000` sans rien configurer. Pourquoi est-ce possible ? Parce que la documentation du daemon dit que les registres locaux, « dont l'adresse IP tombe dans la plage `127.0.0.0/8`, sont automatiquement marqués comme non sécurisés » (c'est-à-dire qu'ils sont autorisés en HTTP sans TLS), et ajoute qu'« il n'est pas recommandé de compter là-dessus, car cela peut changer à l'avenir » ([Docker, référence de `dockerd`](https://docs.docker.com/reference/cli/dockerd/)). C'est une exception de laboratoire, et non une invitation à copier cette habitude : la documentation du registre dit que sans TLS on ne doit le faire que « pour des tests », et que, pour que le registre soit accessible depuis d'autres machines, il faut d'abord le protéger avec TLS. Un registre qui écoute sur `0.0.0.0` sans TLS ni authentification est une porte ouverte pour que n'importe qui sur ton réseau change ce que tes serveurs téléchargent. Dans ce cours, il reste sur `127.0.0.1`.

### 10.3 Tag contre *digest* : la mesure de la scène

#### 10.3.1 Provoquer le problème du vendredi

La scène du début peut se reproduire en deux minutes, et il vaut la peine de le faire de tes propres mains, parce que c'est l'une de ces idées auxquelles on croit beaucoup plus quand on les mesure. Le script `fig10_02.sh` construit l'image deux fois avec le **même tag** et des versions différentes, la pousse les deux fois, et demande à la fin au registre ce que renvoie chaque référence. Pour que cela fonctionne, il te faut le `Dockerfile` de cette leçon, expliqué en 10.4 ; pour l'instant, il suffit de savoir qu'il construit la même image que la Leçon 8 et qu'il accepte `--build-arg VERSION=…`, comme toujours. Les lignes qui comptent :

```text
== 2. Construir la 1.6.0 y publicarla con la etiqueta fig10
$ docker build -q --build-arg VERSION=1.6.0 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c"
$ curl -s http://127.0.0.1:5000/v2/_catalog; curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"repositories":["curso-docker-revisor"]}
{"name":"curso-docker-revisor","tags":["fig10"]}

== 3. Otra construcción (VERSION=1.6.1) con la MISMA etiqueta
$ docker build -q --build-arg VERSION=1.6.1 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:f60d25f0809179fefc1966ea14609f73dd6caf3db196e40db52d7b55dc7f42a1"
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["fig10"]}
```

Allons-y par étapes. Dans le bloc 2, `docker build -q` construit en silence (le `-q` évite les dizaines de lignes du processus) et renvoie l'identifiant de l'image, que le script écarte avec `>/dev/null` ; si le `build` réussit, `docker push -q` prend le relais, pousse l'image vers le registre et, avec `-q`, n'imprime que la référence poussée. Remarque le `-t localhost:5000/curso-docker-revisor:fig10` : pour pousser vers *ton* registre, le nom de l'image doit **commencer** par l'adresse du registre. C'est la règle qui explique presque tous les « push access denied » et « repository does not exist » des débutants : sans le préfixe, Docker suppose que tu veux pousser vers Docker Hub. Ensuite, `imagetools inspect` avec `--format '{{json .Manifest.Digest}}'` demande au **registre** (pas à ton Docker local) quel est le *digest* de ce qui se trouve derrière ce tag : `sha256:59e431fa…`. Et la liste des tags du dépôt, `tags/list`, n'en indique qu'un : `fig10`.

Dans le bloc 3, on recommence avec `VERSION=1.6.1`. Regarde la sortie : **la liste des tags reste unique, `fig10`**, mais le *digest* n'est plus `59e431fa…` : c'est `f60d25f0…`. Le tag s'est déplacé d'une image à l'autre, sans prévenir, sans erreur, sans aucun message pour alerter qui que ce soit. Le registre a fait exactement ce qu'on lui demandait. Ce qui s'est perdu, c'est la garantie que tu croyais avoir en disant « la 1.6.0 ».

#### 10.3.2 Interroger chaque référence

Voici maintenant l'épreuve du feu : que reçoit celui qui demande par tag, et que reçoit celui qui demande par *digest* ? Le bloc 4 regarde quelle copie locale la construction a laissée (avec `docker image ls`), la supprime, regarde de nouveau (pour qu'il ne reste que ce que dit le registre) et récupère les deux :

```text
== 4. Lo que trae cada referencia
(la copia local que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
(y después de borrarla)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor:fig10 && docker run --rm localhost:5000/curso-docker-revisor:fig10 version
localhost:5000/curso-docker-revisor:fig10
1.6.1
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c && docker run --rm localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c version
localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c
1.6.0
```

L'image possède la sous-commande `version` depuis la Leçon 3 : elle imprime la version qui a été gravée à la compilation. Celui qui a demandé `:fig10` a reçu **1.6.1**, le dernier poussé. Celui qui a demandé le *digest* de la première construction a reçu **1.6.0**, ce que *cette* référence renvoie tant qu'elle existe dans le registre. Les deux sont saines, aucune n'est « fausse » : ce sont deux images différentes, et le tag est une étiquette qui est passée de l'une à l'autre. Avec cela, la scène du vendredi a une explication et une solution : si Tomás et toi aviez utilisé la référence avec *digest*, ou si tu avais publié chaque correction avec un nouveau tag (`1.6.1`), il n'y aurait rien eu à discuter.

Trois nuances pour ne pas en tirer trop de conclusions. **Une :** le *digest* n'est pas « plus sûr » en soi. Ce qu'il apporte, c'est l'*immuabilité de la référence* : ce que tu demandes par *digest*, soit tu le reçois à l'identique, soit tu ne le reçois pas. Il ne dit rien sur la présence de failles dans l'image ; c'est ce que vérifie l'analyse. **Deux :** celui qui publie peut supprimer un *digest* du registre ; le `pull` échoue alors au lieu de ramener autre chose, ce qui est exactement le comportement voulu. **Trois :** le *digest* d'un index est différent de celui de chaque manifeste de plateforme qu'il contient (dans cet exercice, `imagetools inspect` a montré celui d'une image à plateforme unique ; les deux niveaux se voient en 10.5). Jusqu'ici, tu n'as travaillé qu'avec une plateforme ; en 10.5, tu verras les deux niveaux.

La règle pratique qui en ressort tient en une ligne : **le tag est fait pour que les personnes se parlent ; le *digest* est fait pour que les machines vérifient**. Publie un nouveau tag pour chaque construction que tu vas livrer et ne réutilise pas une version déjà publiée. Et quand une machine doit exécuter exactement ce que tu as testé, donne-lui le *digest*. La documentation des bonnes pratiques de Docker le dit de la même façon pour les bases : figer l'image par *digest* donne la garantie que « tu utiliseras toujours la même version de l'image, même si celui qui la publie remplace le tag par une nouvelle image » ([Docker, « Building best practices », section sur les bases figées](https://docs.docker.com/build/building/best-practices/)). C'est ce qu'a fait la Leçon 5 avec la base du `revisor`, et aujourd'hui tu l'appliques à l'image du `revisor` elle-même.

### 10.4 Un seul `Dockerfile` pour deux processeurs

#### 10.4.1 Le problème : un binaire appartient à un processeur

Le `revisor` est écrit en Go et compile en un binaire statique. Tu sais déjà ce que « statique » signifie (Leçon 5) : il apporte tout ce dont il a besoin et ne demande aucune bibliothèque du système. Mais cela reste du code machine pour **un** processeur. Deux familles dominent aujourd'hui : `amd64` (aussi appelée x86-64, celle de la plupart des serveurs et des machines sous Linux Mint) et `arm64` (aussi appelée AArch64, celle des Mac avec puce Apple et de nombreux serveurs dans le cloud). Docker les nomme `linux/amd64` et `linux/arm64` : système d'exploitation, barre oblique, architecture. Le nom de l'architecture est le même que celui qu'utilise Go, et c'est la raison pour laquelle le `Dockerfile` suivant peut passer directement un nom de Docker au compilateur.

Pour construire une image qui fonctionne sur les deux, la documentation de Docker énumère trois stratégies ([Docker, « Multi-platform builds »](https://docs.docker.com/build/building/multi-platform/)) : l'**émulation** avec QEMU ; un constructeur avec **plusieurs nœuds natifs** (une machine de chaque architecture) ; et la **compilation croisée** (*cross-compilation*) avec des étapes. À propos de la première, la même page prévient que l'émulation « peut être bien plus lente que les constructions natives », surtout pour des tâches de calcul intensif comme la compilation, et recommande des nœuds natifs ou la compilation croisée « si possible ». Avec un compilateur comme celui de Go, la troisième est possible et c'est la meilleure. Tu vas maintenant mesurer pourquoi.

#### 10.4.2 Essayer l'émulation (et constater qu'elle ne fonctionne pas)

Le script `fig10_03.sh` prend le `Dockerfile` de la Leçon 8, **sans y toucher**, et demande à Docker une image pour `linux/amd64` depuis une machine `arm64`. Docker accepte : dans `docker buildx inspect`, `linux/amd64` apparaît parmi les plateformes qu'il sait exécuter, parce qu'il apporte QEMU pour simuler ce processeur. Voici ce qui s'est passé sur cette machine :

```text
$ ./fig10_03.sh
== 1. Este equipo y lo que su constructor sabe correr
$ uname -m
aarch64
$ docker buildx inspect | grep -E '^Platforms:'
Platforms:        linux/arm64, linux/amd64, linux/amd64/v2, linux/386

== 2. El Dockerfile de la Lección 8, para linux/amd64: todo corre emulado (QEMU)
$ docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada.log 2>&1; echo "construcción: código $?"
construcción: código 1
(tardó 0 s)
$ { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110
fatal error: fault
$ grep -E '^ERROR' emulada.log
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
(el mismo intento, dos veces más, para ver si el fallo es siempre el mismo)
$ for n in 2 3; do docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada-$n.log 2>&1; echo "intento $n: código $?"; { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada-$n.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110; done
intento 2: código 1
fatal error: found pointer to free object
intento 3: código 1
fatal error: fault
```

Lis-le calmement, car il contient deux leçons. `uname -m` indique `aarch64`, le nom long d'`arm64` : c'est une machine `arm64`, et la liste des plateformes confirme que son constructeur sait en exécuter quatre, dont trois étrangères à son processeur (`amd64`, `amd64/v2` et `386`), grâce à l'émulation. La commande de construction comporte `--no-cache` (pour que rien ne soit réutilisé d'une exécution précédente) et `-o type=local,dest=salida-emulada`, qui, au lieu de créer une image, **dépose les fichiers finaux dans un dossier** : ici, cela sert à vérifier le résultat sans remplir le magasin d'images. On demande `--platform linux/amd64`.

Le résultat : la construction **échoue**, avec le code 1, presque instantanément (le script a marqué 0 s). Le message est un `fatal error` du programme Go lui-même, et la dernière ligne dit où il s'est déclenché : à l'étape `go test ./...`, celle de l'étape de tests de la Leçon 5, qui, en échouant avec `exit code: 2`, arrête tout. Pour savoir si l'échec est constant ou un hasard, le script répète la tentative deux fois de plus. Les trois tentatives de cette exécution ont donné des **messages différents** (`fault`, `found pointer to free object` et de nouveau `fault`), et lors d'exécutions antérieures du même script, j'en ai vu deux autres, `found bad pointer in Go heap` et `wirep: already in go`, qui n'ont pas été conservés dans les fichiers. Ce sont tous des messages qu'imprime le ramasse-miettes ou l'ordonnanceur de Go quand quelque chose qu'il attendait de la machine ne se produit pas : ce n'est pas une erreur de ton `Dockerfile` ni du code du `revisor`. Ce qui désigne l'émulation, c'est que le même `Dockerfile`, avec le même code, compile bien sur le processeur natif et avec la compilation croisée (10.4.3). **Ce qui a été mesuré, c'est l'échec, pas sa cause**, et rien ne garantit qu'il t'arrivera : sur ton Mint avec `amd64` émulant `arm64`, le comportement peut être différent, et avec d'autres versions de QEMU aussi. Ce que tu peux retenir comme règle, c'est ce que dit la documentation : l'émulation est la dernière option, pas la première, et un échec différent à chaque tentative est la signature d'une émulation qui ne parvient pas à reproduire correctement le processeur. Formulé comme une condition mesurée et sans promesse : **sur un Mac avec puce Apple, avec Colima, la compilation émulée de Go pour `amd64` a échoué aux trois tentatives de l'exécution conservée, et aux exécutions précédentes de ce même script** ; si quelque chose de semblable t'arrive, n'insiste pas et ne cherche pas à réparer l'émulation : compile sur le processeur natif et laisse Go produire le binaire de l'autre plateforme (compilation croisée), ce qui est la suite et ce qui a été mesuré avec succès (code 0, 65 secondes, un binaire par plateforme). La documentation de Docker mentionne aussi une autre issue, un constructeur avec des nœuds natifs de chaque architecture, que cette leçon n'a pas testée.

#### 10.4.3 La compilation croisée : trois changements

L'idée est simple. La compilation (qui est le gros du travail) tourne **sur le processeur natif de celui qui construit**, et seul le *résultat* est étiqueté pour un autre processeur. Pour cela, le `Dockerfile` change à trois endroits. Avant de le remplacer, sauvegarde celui de la Leçon 8 avec `cp Dockerfile Dockerfile.leccion8`. Voici le fichier complet, `fig10_01.Dockerfile`, qui s'appelle `Dockerfile` dans ton dossier :

```dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
# arquitectura por sí mismo, así que las etapas de compilación corren en la
# plataforma de quien construye ($BUILDPLATFORM) y solo cambia el destino del binario.

FROM --platform=$BUILDPLATFORM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
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
# Las pone BuildKit solo: la plataforma para la que se está construyendo.
ARG TARGETOS TARGETARCH
# Un secreto de CONSTRUCCIÓN (por ejemplo, credenciales para módulos privados)
# se monta solo durante este RUN y no queda en ninguna capa. Este curso no usa
# módulos privados: el montaje es opcional (required=false) y queda como patrón.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    --mount=type=secret,id=netrc,target=/root/.netrc,required=false \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" \
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

C'est le `Dockerfile` de la Leçon 8 avec **trois lignes de code différentes** (plus un nouveau commentaire qui les explique et les commentaires d'en-tête) ; si tu compares les deux fichiers avec `diff`, le code ne change qu'ici :

1. `FROM --platform=$BUILDPLATFORM golang:…`. `BUILDPLATFORM` est une variable que BuildKit définit toute seule : la plateforme de la machine qui construit (ici, `linux/arm64`). Avec cette option, l'étape de compilation **tourne en natif**, quelle que soit la plateforme de l'image finale. La documentation la nomme avec `TARGETPLATFORM`, `TARGETOS` et `TARGETARCH` parmi les arguments de construction prédéfinis ([Docker, « Multi-platform builds »](https://docs.docker.com/build/building/multi-platform/)).
2. `ARG TARGETOS TARGETARCH`. Déclare, dans l'étape `binario`, que l'on veut utiliser le système d'exploitation et l'architecture de **destination**. BuildKit les renseigne seul (`linux` et `amd64`, ou `linux` et `arm64`, selon la plateforme en cours d'assemblage) ; les déclarer avec `ARG` est ce qui les rend visibles dans le `RUN`.
3. `GOOS=$TARGETOS GOARCH=$TARGETARCH` devant `go build`. Ce sont les variables avec lesquelles le compilateur Go décide pour quel système et quel processeur il génère le binaire, et les noms d'architecture de Docker (`amd64`, `arm64`) coïncident avec ceux de Go, tout comme ceux de la spécification de l'index de la section 10.1.3. Avec `CGO_ENABLED=0` (qui y était déjà), le binaire est statique et n'a pas besoin d'un compilateur C pour l'autre processeur.

Et une chose qui ne change **pas**, à dessein : l'étape `final` (`FROM gcr.io/distroless/…`) ne comporte pas `--platform`. Cette étape-là doit bien être de la plateforme de destination, parce que c'est l'image qui va être livrée ; BuildKit choisit seul la bonne variante de la base distroless pour chaque plateforme, et cette base est publiée pour les deux. Les deux étapes de compilation (`compilacion` et `pruebas`) tournent en natif **une seule fois**, sur le processeur de celui qui construit. Cela a une limite qu'il faut dire : les tests de Go valident le **code** sur ce processeur ; ils n'exécutent pas le binaire de l'autre plateforme. Pour un service en Go pur, c'est raisonnable, mais le binaire `amd64` ne se vérifie vraiment qu'en l'exécutant sur un `amd64`. En 10.9.2, tu l'exécutes.

#### 10.4.4 Mesurer la compilation croisée

Le bloc 3 de `fig10_03.sh` construit avec ce `Dockerfile` pour **les deux plateformes** à la fois :

```text
== 3. fig10_01.Dockerfile, para las DOS plataformas: compila cruzado
$ docker buildx build --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-cruzada cruzada > cruzada.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 65 s)
$ grep -oE '\[linux/[a-z0-9>-]+ (pruebas|binario) [0-9]/[0-9]\]' cruzada.log | sort -u
[linux/arm64 binario 1/1]
[linux/arm64 pruebas 1/1]
[linux/arm64->amd64 binario 1/1]
$ ls salida-cruzada
linux_amd64
linux_arm64
$ maquina salida-cruzada/linux_amd64/revisor; maquina salida-cruzada/linux_arm64/revisor
salida-cruzada/linux_amd64/revisor: 3e 00 = x86-64 (amd64)
salida-cruzada/linux_arm64/revisor: b7 00 = AArch64 (arm64)
```

Le code de sortie est 0 : **ça a fonctionné**, et avec `--no-cache`, sans astuce. Cela a pris 65 secondes parce que tout a été compilé depuis zéro (avec le cache de Go des leçons précédentes, ce serait beaucoup moins ; la section 10.5 le fait en quelques secondes). Le plus intéressant se trouve dans le `grep`. Les lignes que BuildKit imprime à l'exécution de chaque étape portent entre crochets **la plateforme sur laquelle** l'étape s'exécute, et ce que l'on voit est : `[linux/arm64 pruebas 1/1]`, les tests ont tourné sur `arm64`, la plateforme native. `[linux/arm64 binario 1/1]`, le binaire d'`arm64` a été compilé sur `arm64`. Et `[linux/arm64->amd64 binario 1/1]` : le binaire d'**`amd64`** a été compilé *sur* `arm64` (la flèche dit « d'ici vers là-bas »). Aucune étape de la construction ne s'est exécutée sur `amd64`, pas même en émulation. C'est la preuve que l'erreur de la section précédente n'a pas eu à être résolue en réparant QEMU, mais en le contournant.

La dernière partie de la sortie est la vérification qui compte : chaque fichier est-il vraiment destiné au processeur qu'il annonce ? `ls` montre un dossier par plateforme. Et la fonction `maquina` du script **lit les octets** : l'en-tête d'un exécutable Linux (format ELF) stocke dans les octets 18 et 19 le champ `e_machine`, qui identifie le processeur de destination, et `od -An -tx1 -j18 -N2` les imprime en hexadécimal. `3e 00` est la marque de x86-64 et `b7 00` celle d'AArch64. Autrement dit, tu ne te fies pas au nom du dossier : tu as regardé l'intérieur du fichier. (Si tu veux la table complète des codes, elle se trouve dans la spécification du format ELF ; les deux que tu utilises ici peuvent être vérifiés sur n'importe quelle machine avec la commande `file` de ton Mint, qui les écrit en plus avec leur nom.)

**Quand cette technique ne suffit pas.** La compilation croisée fonctionne parce que Go sait générer du code pour une autre architecture sans l'aide de personne. Si ton service dépendait d'une bibliothèque C (avec `CGO_ENABLED=1`), ou si l'étape de construction devait *exécuter* des programmes du processeur de destination (installer des paquets avec `apt` dans une base `amd64`, par exemple), la compilation croisée ne suffirait pas et tu reviendrais à l'émulation ou aux nœuds natifs. Ce n'est pas le cas du `revisor`, et c'est l'une des raisons pour lesquelles le cours a choisi un service écrit en Go.

### 10.5 Construire pour deux plateformes et publier l'index

#### 10.5.1 La commande complète

Tu as le `Dockerfile` et un registre. Il manque la commande qui construit pour les deux plateformes, joint la nomenclature logicielle et la provenance, et pousse le tout. Elle est longue ; on la lit par morceaux :

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VERSION=1.6.0 \
  --sbom=true \
  --provenance=mode=max \
  -t localhost:5000/curso-docker-revisor:1.6.0 \
  --push .
```

- `docker buildx build` est le constructeur moderne de Docker (BuildKit). Aujourd'hui, `docker build` est un alias de `docker buildx build` ([Docker, « docker build »](https://docs.docker.com/reference/cli/docker/build-legacy/)), donc les deux font la même chose ; pour publier plusieurs plateformes, il faut BuildKit et une destination qui sait stocker des index (un registre avec `--push`, ou le magasin de *containerd*).
- `--platform linux/amd64,linux/arm64` demande **une image par plateforme**, séparées par une virgule.
- `--build-arg VERSION=1.6.0` est le même argument que dans les leçons précédentes ; il est gravé dans le binaire et dans le label `org.opencontainers.image.version`.
- `--sbom=true` ajoute la **nomenclature logicielle** (section 10.6) et `--provenance=mode=max` la **provenance** dans son mode le plus détaillé (section 10.7).
- `-t …:1.6.0` est la référence, qui commence par l'adresse de ton registre, comme en 10.3.
- `--push` est la différence qu'il faut comprendre. Quand tu construis pour **une** plateforme, l'image atterrit dans ton magasin local. Une image de **plusieurs** plateformes est un index, et le magasin classique de Docker ne sait pas stocker d'index, si bien que, historiquement, `buildx` exigeait de les envoyer directement à un registre. Avec le magasin de *containerd* (celui de cette machine, voir « À propos des exécutions »), on peut désormais stocker localement des images de plusieurs plateformes et avec des attestations ([Docker, « containerd image store »](https://docs.docker.com/engine/storage/containerd/)), mais la commande de livraison fait de toute façon ce que tu veux : construire et publier en une seule étape. Un avertissement mesuré : avec ce magasin, `--push` **laisse aussi l'image sur ta machine** (la section 10.9.1 le montre avec `docker image ls`), si bien que cette copie locale existe et qu'il ne faut pas la confondre avec celle qui est publiée.

La documentation de Docker décrit ainsi les attestations : celles que tu joins avec `--sbom` et `--provenance` sont stockées « sous la forme d'un manifeste dans l'index de l'image », et leurs données sont conservées « sous forme de blobs JSON » ([Docker, « Build attestations »](https://docs.docker.com/build/metadata/attestations/)). Tu vas le voir de tes propres yeux dans quelques lignes.

Le bloc 2 du script `fig10_04.sh` l'exécute et extrait du journal de construction les lignes où BuildKit indique ce qu'il a écrit :

```text
$ ./fig10_04.sh
== 1. Registro local
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba

== 2. Construir para dos plataformas, con SBOM y procedencia max, y publicar
$ docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . > ../construccion.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 1 s)
$ grep -E 'exporting (manifest|attestation manifest|manifest list) sha256' ../construccion.log | sed -E 's/^#[0-9]+ //; s/ done$//; s/ [0-9.]+s$//' | sort -u
exporting attestation manifest sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
exporting attestation manifest sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
exporting manifest list sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
exporting manifest sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
exporting manifest sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

(Ici, le tag est `fig10` au lieu de `1.6.0`, à cause des noms d'appoint.) Le code est 0 et cela a pris **une seconde** : il n'a pas compilé depuis zéro parce que le cache de Go et les couches de la construction précédente ont été réutilisés ; la section 10.4 a mesuré les 65 secondes de la construction à froid. Le `grep` cherche les lignes où BuildKit signale ce qu'il a *exporté*, et il en sort cinq, qui se lisent ainsi : deux **manifestes** (un par plateforme, `b99bf1ad…` et `959af91e…`), deux **manifestes d'attestation** (un par plateforme également) et une **manifest list**, qui est l'ancien nom de l'index et qui a le *digest* `a4246c5f…`. La ligne qu'il faut retenir est la dernière, l'index : **c'est le *digest* qui représente « la 1.6.0 » en entier**, toutes les plateformes et toutes les attestations.

#### 10.5.2 Lire l'index

Le bloc 3 demande maintenant au registre ce que le tag est devenu. C'est le résultat le plus important de la section :

```text
== 3. El índice que quedó en el registro
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10
Name:      localhost:5000/curso-docker-revisor:fig10
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
           
Manifests: 
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.digest: sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
    vnd.docker.reference.type:   attestation-manifest
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.type:   attestation-manifest
    vnd.docker.reference.digest: sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

Ligne par ligne. `docker buildx imagetools inspect` est l'outil pour voir, **dans le registre**, ce qui se trouve derrière une référence ; sa documentation le décrit comme montrant « les détails d'une image dans le registre » ([Docker, `buildx imagetools inspect`](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/)). C'est une lecture à distance : il n'est pas nécessaire que l'image soit sur ta machine.

- `MediaType: application/vnd.oci.image.index.v1+json` dit que ce qui se trouve derrière le tag est un **index** au format OCI (celui de 10.1.3), et non une image isolée.
- `Digest: sha256:a4246c5f…` est le *digest* de l'index : le même numéro que la ligne `exporting manifest list` de la section précédente. Ce que l'on écrit après le `@` pour identifier « la 1.6.0 », c'est cela.
- Ensuite, `Manifests` liste **quatre entrées**, pas deux. Les deux premières sont les images : `Platform: linux/amd64` avec son *digest* `b99bf1ad…` et `Platform: linux/arm64` avec `959af91e…`. Chacune est un manifeste d'image (`…image.manifest.v1+json`) avec ses couches. Ce sont les *digests* que Docker regarde quand, sur une machine `amd64`, il résout le tag : il choisit l'entrée dont la plateforme coïncide avec celle de la machine (sur un `amd64`, c'est la première).
- Les deux autres portent `Platform: unknown/unknown`. Ce ne sont pas des images que quelqu'un peut exécuter : ce sont les **attestations**. L'annotation `vnd.docker.reference.type: attestation-manifest` le dit, et `vnd.docker.reference.digest` indique **quelle image elles décrivent**. Remarque que `d6939a71…` pointe vers `b99bf1ad…` (celle d'`amd64`) et que `d062f35e…` pointe vers `959af91e…` (celle d'`arm64`) : chaque plateforme a son propre document. Cette annotation est le fil qui relie un document à son image, et c'est ce qui permet à `imagetools inspect --format '{{index .SBOM "linux/amd64"}}'` de trouver la bonne SBOM.

Une conséquence qu'il faut noter dès maintenant pour la comprendre en 10.9 : les attestations **voyagent à l'intérieur de l'index**, ce n'est pas un fichier à part. Celui qui récupère l'image par le *digest* de l'index récupère, ou peut demander, ses attestations ; celui qui travaille avec un manifeste de plateforme isolé ne les voit pas.

### 10.6 La nomenclature logicielle (SBOM)

#### 10.6.1 Ce que c'est et à quoi elle sert

Une **nomenclature logicielle** (*Software Bill of Materials*, SBOM) est, selon la documentation de Docker, la « liste des artefacts logiciels qu'une image contient, ou qui ont servi à la construire » ([Docker, « Build attestations »](https://docs.docker.com/build/metadata/attestations/)). C'est l'équivalent de la liste d'ingrédients d'un emballage. Sa valeur apparaît le jour où une faille publique sort dans une bibliothèque : sans liste, la question « ce que j'ai en cours d'exécution utilise-t-il cette bibliothèque ? » oblige à ouvrir chaque image ; avec une liste, c'est une recherche. Et c'est la même liste qu'utilisent les scanners pour décider quoi vérifier.

Le format qu'écrit `--sbom=true` dans ce Docker est **SPDX**, « un standard ouvert pour communiquer des informations de nomenclature logicielle » ([SPDX, « Overview »](https://spdx.dev/about/overview/)). Les deux lignes à la fin de la sortie suivante le vérifient : la version du format et les outils qui ont écrit le document.

#### 10.6.2 La lire

Le bloc 4 de `fig10_04.sh` demande au registre la SBOM de `linux/amd64` et la parcourt avec un modèle Go (`--format '{{…}}'`) :

```text
== 4. La lista de materiales (SBOM) de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .SBOM "linux/amd64").SPDX.packages}}{{.name}} {{.versionInfo}}{{println}}{{end}}' | sort
base-files 13.8+deb13u7
ca-certificates 20250419
github.com/habil/revisor UNKNOWN
media-types 13.0.0
netbase 6.5
sbom <no value>
stdlib go1.27.3
tzdata 2026c-0+deb13u1
tzdata-legacy 2026c-0+deb13u1
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .SBOM "linux/amd64").SPDX.spdxVersion}} {{(index .SBOM "linux/amd64").SPDX.creationInfo.creators}}'; echo
SPDX-2.3 [Organization: Anchore, Inc Tool: syft-v1.51.0 Tool: buildkit-v0.27.1]
```

Le modèle : `.SBOM` est la table des SBOM par plateforme ; `index .SBOM "linux/amd64"` prend celle de cette plateforme (la documentation de la commande explique que `index` sert justement à choisir une plateforme dans les images multiplateformes) ; `.SPDX.packages` est la liste des paquets du document SPDX ; et `{{.name}} {{.versionInfo}}` imprime le nom et la version de chacun, un paquet par ligne. Le `| sort` les trie. Il y a **neuf** lignes, et chacune raconte une histoire de l'image :

- `base-files`, `media-types`, `netbase`, `tzdata`, `tzdata-legacy` et `ca-certificates` sont les paquets Debian qu'apporte la base distroless. Certaines versions portent le suffixe `+deb13u7`, qui est la révision de ce paquet dans Debian 13. `tzdata` est la base de données des fuseaux horaires (`2026c`) ; `ca-certificates` est la liste des autorités de confiance qui permet à un programme de vérifier les certificats HTTPS (le `revisor` en a besoin pour interroger des services en `https`). Sans shell ni gestionnaire de paquets, le peu qu'il y a dans l'image, c'est cela. Remarque la version de `ca-certificates` : `20250419`. Tu y reviendras en 10.10.
- `stdlib go1.27.3` est la bibliothèque standard de Go avec laquelle le binaire a été compilé. Ce n'est pas un paquet Debian, mais ce que le langage laisse dans chaque programme qu'il génère : c'est pourquoi la version du compilateur (celle de l'étape `golang:1.27.3-trixie`) apparaît dans la liste, et pourquoi un scanner peut dire « cette image contient Go 1.27.3 » sans l'exécuter.
- `github.com/habil/revisor UNKNOWN` est le programme lui-même : son module Go, avec la version `UNKNOWN` (le scanner n'a trouvé aucune version à lire ; la leçon n'a pas cherché pourquoi).
- `sbom <no value>` est une ligne étrange, et mieux vaut le dire à voix haute : il n'a pas l'air d'un paquet de l'image ; c'est un élément sans version que le générateur ajoute au document (la leçon n'a pas cherché son origine), et le modèle imprime `<no value>` quand le champ manque. Nous l'avons laissé dans la sortie exprès pour qu'il ne t'effraie pas quand tu le verras.

Et la dernière commande répond à la question « qui a écrit cela ? » : format `SPDX-2.3`, produit par **Syft** (d'Anchore, version 1.51.0) via BuildKit v0.27.1. Ce n'est pas ton `Dockerfile` qui l'a écrit, et personne ne l'a tapé : BuildKit lance un scanner de contenu *à l'intérieur* de la construction (dans la provenance de la section suivante, tu le verras comme un « matériau » de plus, `buildkit-syft-scanner`), lit l'image terminée et note ce qu'il reconnaît. Cela a une limite qu'il faut connaître : **une SBOM générée ainsi décrit ce que le scanner reconnaît**, et il reconnaît les paquets système et les modules des langages connus. Un fichier que tu as copié à la main dans l'image sans qu'aucun gestionnaire de paquets l'enregistre n'apparaît pas. La liste est un bon inventaire, pas une preuve qu'il n'y a rien d'autre.

### 10.7 La provenance : avec quoi elle a été construite

#### 10.7.1 Ce que c'est

La SBOM dit **ce qu'il y a** à l'intérieur. La **provenance** (*provenance*) dit **comment cela a été fait**. Le standard SLSA la définit comme des « informations vérifiables sur des artefacts logiciels qui décrivent où, quand et comment quelque chose a été produit » ([SLSA, « Provenance »](https://slsa.dev/spec/v1.0/provenance)). Pour une image Docker, cela comprend : quel constructeur l'a assemblée, pour quelle plateforme, quelles images de base il a utilisées (avec leur *digest*), quels arguments il a reçus, et à quelle heure il a commencé et fini.

#### 10.7.2 La lire

Le bloc 5 demande trois choses sur la provenance de `linux/amd64` :

```text
== 5. La procedencia de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format 'tipo: {{(index .Provenance "linux/amd64").SLSA.buildType}}{{println}}construida EN: {{(index .Provenance "linux/amd64").SLSA.invocation.environment.platform}}'; echo
tipo: https://mobyproject.org/buildkit@v1
construida EN: linux/arm64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .Provenance "linux/amd64").SLSA.materials}}{{.uri}}{{println}}{{end}}' | cut -c1-100
pkg:docker/docker/buildkit-syft-scanner@stable-1?platform=linux%2Farm64
pkg:docker/docker/dockerfile@1
pkg:docker/golang@1.27.3-trixie?digest=sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965
pkg:docker/gcr.io/distroless/static-debian13@nonroot?digest=sha256:516757106de35205efb70b91ba03f6f12
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json (index .Provenance "linux/amd64").SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
```

- `tipo: https://mobyproject.org/buildkit@v1` est le type de construction : « ceci a été assemblé par BuildKit, dans le format de provenance que BuildKit définit ». Ce n'est qu'un identifiant.
- `construida EN: linux/arm64` est **un second témoignage de la compilation croisée** : c'est BuildKit qui l'a écrit, pas toi. C'est une déclaration du constructeur, sans signature : elle confirme ce que tu as déjà mesuré, mais ne remplace pas une vérification indépendante. Tu as demandé la provenance de l'image `linux/amd64` et le document dit qu'elle a été construite *sur* `linux/arm64`. C'est exactement ce qu'a mesuré la section 10.4 : l'image d'`amd64` a été construite sur une machine `arm64`, sans émuler.
- Les **matériaux** (*materials*) sont tout ce qui est entré dans la construction, avec leur identifiant de paquet (`pkg:docker/…`, au format *purl*, un standard pour nommer les paquets) et, quand il existe, leur *digest*. Il y en a quatre : le scanner de SBOM (`buildkit-syft-scanner`), le frontend de Dockerfile (`dockerfile@1`, ce que demandait la première ligne `# syntax=docker/dockerfile:1`), l'image de compilation (`golang@1.27.3-trixie`, avec le *digest* `604106…` fixé par la Leçon 5) et la base finale (`gcr.io/distroless/static-debian13@nonroot`, avec `516757…`). Les `cut -c1-100` de la commande tronquent les lignes pour qu'elles tiennent ; le *digest* complet figure dans le document. Ces deux *digests* sont ceux de ton `Dockerfile` : la provenance est une seconde lecture, écrite par BuildKit, qui atteste que ce qui a été utilisé est ce qui avait été fixé (sans signature : quiconque a la permission de pousser vers le registre pourrait en joindre une autre).
- Les arguments (`args`) sont ce que le constructeur a reçu : `build-arg:VERSION: 1.6.0`, la commande de frontend et sa source.

Une précision sur les noms de champ que tu viens de lire (`invocation`, `materials`, `metadata`) : par défaut, Docker écrit la provenance dans la version 0.2 du schéma SLSA, et la 1.0 s'active avec `version=v1` (par exemple, `--provenance=mode=max,version=v1`) ([Docker, « SLSA provenance »](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). Avec `version=v1`, les champs changent de place et les modèles de cette section ne fonctionneraient pas tels quels ; cette leçon ne l'a pas mesuré.

#### 10.7.3 `min` contre `max` : l'avertissement

Nous avons mis `--provenance=mode=max`. Il existe deux modes, et la différence n'est pas une question de goût. La documentation dit que `min` est celui qui est ajouté **par défaut** aux images, qu'il comprend « les horodatages, le frontend, les matériaux, le dépôt et la révision de la source, la plateforme de construction et la reproductibilité », et que « les valeurs des arguments de construction, les identités des secrets et les métadonnées riches des couches ne sont **pas** incluses dans `mode=min` », ce qui le rend « sûr pour toutes les constructions ». Le mode `max` « inclut tout ce que comprend `min` » et ajoute la définition interne de la construction (LLB), **une copie du Dockerfile encodée en base64** et des cartes de source qui relient les étapes aux couches. Et il comporte un avertissement qu'il faut lire en entier : `max` **expose les valeurs des arguments de construction** ; si tu passes des identifiants en `--build-arg`, il faut réécrire la construction pour utiliser des montages de secrets, parce que « les montages de secrets ne fuient pas hors de la construction et ne sont jamais inclus dans les attestations de provenance » ([Docker, « SLSA provenance »](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)).

C'est le genre d'avertissement auquel on croit davantage quand on le voit. Le bloc 6 construit l'image d'`arm64` deux fois, une dans chaque mode, **en lui passant exprès un argument que le `Dockerfile` ne déclare même pas** : `NOTA=curso-docker-nota-de-mentira`. Le nom dit que c'est une fausse valeur : c'est un texte inventé pour l'exercice, et c'est ce que représenterait n'importe quelle valeur que quelqu'un passerait par erreur dans un `--build-arg`. Les deux constructions sont identiques, sauf le mode de provenance (le script les répète dans une boucle avec `mode=min` et `mode=max`) :

```bash
docker buildx build -q --platform linux/arm64 \
  --build-arg VERSION=1.6.0 --build-arg NOTA=curso-docker-nota-de-mentira \
  --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10-max --push .
```

Ensuite, il demande au registre ce que chacune a conservé :

```text
== 6. Modo min contra modo max, con un argumento que el Dockerfile ni declara
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: (no aparecen)
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:NOTA": "curso-docker-nota-de-mentira",
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildConfig', 'buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: [{'id': 'netrc', 'optional': True}]
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys,base64; d=json.load(sys.stdin); i=d["metadata"]["https://mobyproject.org/buildkit@v1#metadata"]["source"]["infos"][0]; print(i["filename"]); print("\n".join(base64.b64decode(i["data"]).decode().splitlines()[:3]))'
Dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
```

Ce que l'on voit en comparant :

1. **Les arguments.** Dans `min`, il n'y a que `cmdline` et `source` : **ni `VERSION` ni `NOTA`**. Dans `max`, les deux apparaissent avec leur valeur, y compris la « fausse note ». C'est ce que décrit l'avertissement : ce que quelqu'un passe par `--build-arg` reste écrit, lisible, dans un document qui voyage avec l'image et que quiconque peut récupérer l'image peut lire. Si cette note avait été un token, le token serait là.
2. **Les champs.** `min` a cinq champs (`buildType`, `builder`, `invocation`, `materials`, `metadata`) ; `max` ajoute `buildConfig`, qui est la définition interne des étapes.
3. **Les secrets.** Dans `min`, `(no aparecen)` : même leur identité n'y figure pas. Dans `max` apparaît `[{'id': 'netrc', 'optional': True}]` : le **nom** du secret de construction (`--mount=type=secret,id=netrc`) et le fait qu'il est facultatif (`required=false`, rappelle-toi le `Dockerfile`), **mais pas son contenu**. C'est le comportement que promet la documentation : le montage de secrets ne laisse pas fuir la valeur ; il garde en revanche la trace que la construction a demandé un secret de ce nom.
4. **Le `Dockerfile` complet.** La dernière commande décode la copie en base64 que `max` conserve et montre ses premières lignes : c'est le `Dockerfile` qui a été utilisé, avec ses commentaires, à la vue de quiconque. Si ton `Dockerfile` contenait un commentaire avec quelque chose qui ne doit pas se savoir, il apparaîtrait ici.

La décision qui s'en dégage et que le cours adopte : **on publie avec `mode=max` parce que la provenance complète est ce qui rend la livraison utile, et on garde l'origine propre** : aucun secret ne passe par `ARG`, ni par `ENV`, ni par `--build-arg` (l'habitude de la Leçon 6), et quand la construction en a besoin d'un, il entre par `--mount=type=secret`. Ainsi, `max` n'expose pas de secrets, mais il publie bien le `Dockerfile` complet et les valeurs de tous les `--build-arg` : vérifie les deux avant de publier. Si tu travailles dans une équipe où tu ne peux pas le garantir, `min` est le mode sûr, et la documentation elle-même le dit. Ce qui n'est **pas** acceptable, c'est d'utiliser `max` sans savoir que cette différence existe.

### 10.8 « Identique » ne veut pas dire « égal » : ce qui change à la reconstruction

Une question naturelle après avoir parlé de *digests* : si je construis deux fois la même version, avec le même `Dockerfile` et le même code, est-ce que j'obtiens le même *digest* ? Tu t'attendrais à ce que oui. Ce que l'on mesure est autre chose, et mieux vaut le savoir avant de promettre la « reproductibilité » à qui que ce soit. Le bloc 7 reconstruit à l'identique (avec cache) et compare :

```text
== 7. Otra construcción idéntica: ¿qué digest cambia?
$ docker buildx build -q --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
antes:   índice sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:04c19cbec864dd3ff9ccf5d71d676244acecd31ae1e1d9c363006bfac903c571"
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
arm64 sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .Provenance "linux/amd64").SLSA.metadata.buildStartedOn}}'; echo
2026-10-21T18:18:15.739444508-06:00
```

Le *digest* de l'**index** a changé : de `a4246c5f…` à `04c19cbe…`. Mais ceux de **chaque plateforme** (avec `--raw`, le JSON brut de l'index, filtré sur les entrées Linux) sont **les mêmes** : `b99bf1ad…` pour `amd64` et `959af91e…` pour `arm64`. Pourquoi celui de l'index a-t-il changé ? Parce que l'index inclut, parmi ses entrées, les attestations, et que la provenance contient l'heure à laquelle la construction a commencé (la dernière commande l'affiche : `buildStartedOn`). Une autre heure, un autre document de provenance, un autre *digest* d'attestation, un autre index. Les images elles-mêmes n'ont pas changé d'un seul bit. Conséquence pratique : **deux livraisons de la même chose peuvent avoir des index différents**, et si tu fixes par le *digest* de l'index, tu fixes aussi cette heure. C'est correct (cela identifie *cette* livraison), mais ce n'est pas ce que beaucoup de gens imaginent en lisant « le *digest* est l'empreinte du contenu ».

Le bloc 8 répète la construction avec `--no-cache`, qui oblige à refaire chaque étape :

```text
== 8. Y otra más, ahora SIN caché (--no-cache): ¿siguen iguales los de cada plataforma?
$ docker buildx build -q --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:37dd082fe87a0b2779067a9098dab82e3c7d53e9924fa668d41638d8602dccfd
arm64 sha256:d9875545824d329af2bc6c206f52acc80145926a0cff399591bc1b4d6876e0c3
```

Maintenant, ceux de chaque plateforme ont **eux aussi** changé (`37dd082f…` et `d9875545…`). Sans cache, rien n'est réutilisé, et l'image obtenue a un *digest* différent même si le code, le `Dockerfile` et la version sont les mêmes. **Ce qui a été mesuré, c'est le fait ; la cause n'a pas été étudiée** (le plus probable est un horodatage enregistré dans la configuration ou dans les couches, mais cette leçon ne l'a pas vérifié, et tu ne dois pas le lire comme une donnée établie). La leçon pratique est sobre : **on ne promet à personne que reconstruire redonne le même *digest***. Ce que l'on promet est le contraire, et c'est plus utile : *ce* digest, une fois publié, identifie *cette* image tant qu'elle existe dans le registre. Si la source doit être reproductible au bit près, c'est un autre sujet (celui des constructions reproductibles), que cette leçon ne résout ni ne promet.

### 10.9 La récupérer par *digest* et l'exécuter comme il se doit

#### 10.9.1 Comme sur une machine qui ne l'a jamais construite

Publier ne sert à rien si tu ne vérifies pas que l'image peut être *reçue*. L'épreuve honnête se fait comme si tu étais Tomás : une machine qui n'a pas l'image, qui ne connaît que le registre et un *digest*. (Un avis pour ne pas confondre les chiffres : les *digests* de `fig10_02.sh`, d'une seule plateforme, et ceux de `fig10_04.sh`, un index de deux, sont ceux d'images différentes, et c'est pourquoi ils ne coïncident pas.) Dans le bloc 9 de `fig10_04.sh`, avant de télécharger quoi que ce soit, le script **supprime les copies locales** laissées par la construction (avec le magasin de *containerd*, même avec `--push`, l'image reste aussi sur ta machine) et le vérifie avec `docker image ls` avant et après, pour que la seule chose qui existe soit ce que dit le registre. Ensuite, on la récupère par *digest* :

```text
== 9. Traerla por digest, no por etiqueta
(copias locales de localhost:5000/curso-docker-revisor que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10-min
localhost:5000/curso-docker-revisor:fig10-max
(y después de borrarlas)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker run --rm localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version
1.6.0
$ docker image inspect --format '{{json .RepoDigests}}' localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52; echo
["localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52"]
```

(Le *digest* de ce bloc est celui de l'index resté dans le registre après la dernière construction du script ; il change à chaque exécution.) Le `docker pull -q` avec `@sha256:…` a téléchargé **uniquement ce qui correspond à ce processeur**. `docker run … version` imprime `1.6.0` : la version qui a été gravée à la compilation. Et `RepoDigests` est le champ d'une image locale qui conserve **de quel registre et avec quel *digest* elle vient** : c'est la preuve que la copie locale n'est pas une construction à toi mais un téléchargement, et c'est ce qui permet, des mois plus tard, de demander « ce qui tourne là, d'où vient-il ? ».

Il faut dire ce qui est censé se produire ici, même si la sortie ne l'imprime pas. La spécification de distribution de l'Open Container Initiative, le document qui définit comment les clients parlent aux registres, dit que les clients « DEVRAIENT vérifier que le corps de la réponse correspond au *digest* demandé » (dans l'original, « SHOULD verify that the response body matches the requested digest » ; [OCI, « Distribution Specification »](https://github.com/opencontainers/distribution-spec/blob/main/spec.md)). C'est une recommandation faite aux clients, et cette leçon ne l'a pas mesurée avec une image altérée exprès ; ce que tu as, c'est la règle pratique : demander par *digest*, c'est demander quelque chose qui peut être vérifié, et une référence avec *digest* qui ne correspond pas doit être un échec et non « une autre image ».

#### 10.9.2 Ce qui a été téléchargé, et ce qui ne l'a pas été

Le bloc 10 montre quelque chose qui surprend la première fois : des deux plateformes de l'index, ta machine en a téléchargé une.

```text
== 10. Lo que bajó a este equipo: solo su plataforma
$ docker image ls --tree localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 2>/dev/null | sed -E 's/@sha256:([0-9a-f]{12})[0-9a-f]+/@sha256:\1…/'
IMAGE                                                                                                              ID             DISK USAGE   CONTENT SIZE   EXTRA
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8…   6956d5334dc8       16.8MB         4.34MB        
├─ linux/amd64                                                                                                     37dd082fe87a           0B             0B        
└─ linux/arm64                                                                                                     d9875545824d       16.2MB         3.68MB        

$ docker save --platform linux/arm64 -o ../propia.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/arm64'
guardada: linux/arm64
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
Error response from daemon: no suitable export target found: image with reference localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 was found but does not provide the specified platform (linux/amd64)
[código de salida: 1]
```

Et le bloc 11, qui récupère l'autre plateforme et essaie de l'exécuter :

```text
== 11. Traer la OTRA plataforma, guardarla y probar a correrla (linux/amd64)
$ docker pull -q --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/amd64'
guardada: linux/amd64
$ docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version 2>&1 | head -3
1.6.0
```

`docker image ls --tree` est la vue qui montre l'index et ses plateformes. Elle se lit ainsi : en haut, la référence avec le *digest* de l'index ; en dessous, une ligne par plateforme avec son propre identifiant. La colonne `DISK USAGE` donne la clé : `linux/arm64` occupe **16.2 MB** sur le disque (l'image du `revisor` : la même taille que celle mesurée par les leçons 8 et 9, 16.2 MB) et `linux/amd64` occupe `0B`. Elle figure dans la liste parce que l'index la mentionne, mais **ses couches n'ont pas été téléchargées**. C'est efficace (personne ne télécharge ce qu'il ne va pas exécuter), et cela a une conséquence pratique que la dernière commande provoque exprès : `docker save --platform linux/arm64` fonctionne, et `docker save --platform linux/amd64` échoue avec `no suitable export target found … does not provide the specified platform`. La documentation de `docker image save` dit exactement cela : `--platform` n'enregistre que les plateformes indiquées, et « une erreur est produite si la plateforme donnée n'est pas présente dans le magasin d'images local » ([Docker, `docker image save`](https://docs.docker.com/reference/cli/docker/image/save/)). La morale de l'erreur : **si tu as besoin du fichier de l'autre plateforme, tu dois d'abord la récupérer** ; enregistrer ne la télécharge pas. Le bloc 11 le fait, et répond au passage à la question que la section 10.4 avait laissée ouverte : le binaire de l'autre plateforme démarre-t-il vraiment ?

Le bloc 11 de la sortie ci-dessus se lit ainsi. `docker pull -q --platform linux/amd64 …@sha256:…` télécharge les couches de la plateforme qui manquait (la référence est la même ; `--platform` choisit l'entrée de l'index). Une fois celle-ci dans le magasin, le même `docker save --platform linux/amd64` qui avait échoué répond maintenant `guardada: linux/amd64`. Et la dernière commande, `docker run --rm --platform linux/amd64 … version`, imprime `1.6.0` : **le binaire d'`amd64` a démarré et a répondu**. Il faut dire dans quelles conditions cela a été mesuré, pour ne pas trop promettre : cette machine est `arm64`, donc ce binaire a tourné **émulé** par QEMU ; c'est une preuve que le fichier est un exécutable `amd64` valide qui démarre, pas une preuve de la façon dont il se comporte sur un vrai `amd64`, et démarrer un petit binaire statique est une exigence bien moindre que compiler avec Go (ce que l'émulation n'a pas supporté en 10.4.2).

**Si ta machine est `amd64` (comme ton Mint), c'est la vérification qui te revient**, et c'est celle qui compte vraiment : la même commande, `docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:… version`, tourne maintenant en natif. Si ta machine est `arm64`, la plateforme « de l'autre » est `linux/amd64` et la sortie ci-dessus est celle que tu dois obtenir. Dans les deux cas, le résultat attendu est `1.6.0`.

Cela compte immédiatement, parce que l'analyse de la section suivante se fait sur un `docker save`, et elle analyse **une** plateforme. Un index de deux plateformes s'analyse en deux passes. Dans cette leçon, le script analyse celle du processeur de ta propre machine, et cette limitation est dite à voix haute en 10.10.

#### 10.9.3 L'exécuter durcie : monter `/datos` de nouveau

L'image de la Leçon 8 enregistre son rapport dans `/datos`, et depuis la Leçon 7 on l'exécute avec `--read-only` : le système de fichiers du conteneur est en lecture seule. Cela a une conséquence que tu as déjà mesurée dans la Leçon 8 et que l'on revoit ici, avec l'image **récupérée par *digest***, comme la recevrait une autre personne : si tu ne montes rien dans `/datos`, le `revisor` sain ne peut pas enregistrer son rapport. Le bloc 5 de `fig10_02.sh` exécute l'image avec toutes les mesures et **sans volume** :

```text
== 5. La de digest, endurecida como en la Lección 8: sin nada en /datos
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

La première commande crée le conteneur avec les mesures des leçons 7 et 8 (`--read-only`, `--cap-drop ALL`, `--security-opt no-new-privileges`, `--init`) et la référence **par *digest*** ; le `>/dev/null && echo` ne fait que cacher l'identifiant et confirmer que tout s'est bien terminé. Ensuite, `/salud` répond `vivo` et `1.6.0` : le processus a démarré et l'image est celle que tu as demandée. Puis `/api/estados` répond `500` avec un message qui se lit de droite à gauche, comme dans les leçons 6 et 8 : `read-only file system` est dit par le noyau (on ne peut pas écrire là), `open /datos/.reporte-<n>.tmp` dit quel fichier (le fichier temporaire que le `revisor` écrit avant de le renommer) et `no pude guardar el reporte` est ajouté par le `revisor`, qui préfère répondre `500` plutôt que de faire semblant que tout s'est bien passé. Ce n'est pas un défaut de l'image livrée : c'est le système en lecture seule qui fonctionne comme demandé. La solution est la même que d'habitude, **monter quelque chose d'inscriptible dans `/datos`** :

```text
== 6. La misma, con un volumen en /datos (un contenedor no recibe un volumen después: se borra y se crea otro)
$ docker rm -f curso-docker-revisor-fig10 >/dev/null && echo 'contenedor anterior borrado'
contenedor anterior borrado
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -v curso-docker-reportes-fig10:/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

Un conteneur ne peut pas recevoir un volume après sa création : c'est pourquoi le bloc 6 commence par supprimer le précédent (`docker rm -f`) et en crée un autre avec la même recette plus `-v curso-docker-reportes-fig10:/datos` (le volume d'appoint du script ; dans ton dossier : `--name curso-docker-revisor` et `-v curso-docker-reportes:/datos`, le volume de la Leçon 8). Cette fois, `/api/estados` répond `200`. Et la dernière ligne est la clôture de ce que promettait la section « Le pourquoi avant le comment » : `docker inspect` dit que le conteneur a été créé **avec une référence par *digest***. Rien dans son histoire ne dépend du fait qu'un tag continue de pointer là où il pointait. Rappelle-toi que le nouveau volume hérite du propriétaire `65532` du dossier que l'image apporte (Leçon 8) ; c'est pourquoi il n'y a ici besoin ni de `--user` ni de `chmod`.

Une remarque sur `-e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud'` : c'est le service que le `revisor` interroge. Ici, c'est **lui-même**, sur son propre `/salud`, pour que le test ne dépende d'aucun autre conteneur. C'est une façon de tester l'image isolée, et c'est la même que celle qu'utilise le pod de `kind` de la section 10.11.

### 10.10 Analyser ce que l'on livre avec Trivy

#### 10.10.1 Ce que fait un scanner, et ce qu'il ne fait pas

Un **scanner de vulnérabilités** prend la liste de ce qu'il y a dans une image (paquets du système, modules de langage, le binaire Go lui-même) et la compare avec des **bases de données de failles connues**. Chaque faille publique a un identifiant (un numéro CVE, ou celui de la distribution, comme les *DSA* de Debian), une gravité et, parfois, une version corrigée. **Trivy** est un scanner open source, créé par Aqua Security, qui fonctionne comme un programme en ligne de commande, et tu l'utilises ici à partir de son image officielle `aquasec/trivy:0.76.0`, publiée le 14 octobre 2026 ([notes de la version 0.76.0](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)).

Deux avertissements d'emblée. Le premier : **un scanner répond à « quels problèmes *connus* cela a-t-il *aujourd'hui* ? »**. Il ne répond pas à « est-ce sûr ? ». Un résultat de zéro constat signifie « aucune faille parmi celles que ma base de données connaît, aujourd'hui, dans les paquets que j'ai reconnus » ; demain, ce peut n'être plus zéro sans que l'image ait changé, parce qu'une nouvelle faille sera publiée. Le second : la qualité du résultat dépend de la fraîcheur de sa base de données, et c'est pourquoi le bloc 6 de `fig10_05.sh` la mesure.

#### 10.10.2 L'erreur : lui demander l'image par son nom

Pour cet exercice, on part d'une image locale au nom simple : le bloc 1 de `fig10_05.sh` la construit avec `docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 .` (dans ton dossier, `curso-docker-revisor:1.6.0`), et `docker image ls` confirme ses 16.2 MB. Le premier réflexe est la commande courte : `trivy image mon-image`. Comme Trivy tourne dans un conteneur et que l'image est dans ton Docker, il ne la trouve pas. Il en sort une longue erreur, avec une leçon précieuse. Le bloc 2 de `fig10_05.sh` la provoque et la filtre :

```text
== 2. El error: pedirle a Trivy la imagen por su nombre, sin socket
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 image --quiet curso-docker-revisor:fig10 2>&1 | grep -oE 'unable to find the specified image.*|^\s+\* [a-z]+ error: .*' | cut -c1-120
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]: 4 erro
	* docker error: unable to inspect the image (curso-docker-revisor:fig10): failed to connect to the docker API at un
	* containerd error: containerd socket not found: /run/containerd/containerd.sock
	* podman error: unable to initialize Podman client: no podman socket found: stat podman/podman.sock: no such file or di
	* remote error: GET https://index.docker.io/v2/library/curso-docker-revisor/manifests/fig10: UNAUTHORIZED: authenti
[código de salida: 1]
```

Lecture. La commande monte un volume (`-v curso-docker-trivy-cache-fig10:/root/.cache`) où Trivy conserve sa base de données pour ne pas la télécharger à chaque exécution, et lance `image --quiet curso-docker-revisor:fig10`. Le `grep -oE` ne conserve que la ligne de l'erreur principale et les quatre tentatives échouées ; le `cut` tronque chacune à 120 caractères. Le message dit que Trivy a **cherché l'image à quatre endroits**, dans cet ordre : `docker` (en parlant au daemon par son *socket*), `containerd`, `podman` et `remote` (un registre). C'est le même ordre que documente Trivy : il cherche « d'abord dans le moteur Docker local, puis dans *containerd*, *podman* et, enfin, dans un registre de conteneurs » ([Trivy, « Container Image »](https://trivy.dev/latest/docs/target/container_image/)). À chaque endroit, il a échoué : le *socket* de Docker n'est pas dans le conteneur (`failed to connect to the docker API`), il n'y a ni `containerd` ni `podman`, et, en dernier recours, il a essayé de télécharger `curso-docker-revisor` depuis Docker Hub, où elle n'existe pas (`UNAUTHORIZED`).

La solution « de tutoriel » à la première erreur est de monter le *socket* de Docker dans le conteneur de Trivy (`-v /var/run/docker.sock:/var/run/docker.sock`). **Ne le fais pas.** C'est ce que la Leçon 2 t'a appris à ne pas faire : qui possède le *socket* de Docker contrôle Docker, et donc contrôle ta machine avec les permissions de `root`. Le donner à un conteneur pour qu'il « lise » une image, c'est donner la clé de tout à un programme qui, de surcroît, télécharge des données d'internet à chaque exécution. Le bon chemin donne le même résultat sans rien donner : **enregistrer l'image dans un fichier, et donner le fichier à Trivy**.

#### 10.10.3 Enregistrer et analyser le fichier

Trivy accepte les images enregistrées : sa documentation le dit, avec l'exemple d'un `docker save` suivi de `trivy image --input archivo.tar` ([Trivy, « Container Image »](https://trivy.dev/latest/docs/target/container_image/)), et la référence de la commande décrit `--input` comme le « chemin d'un fichier d'entrée au lieu d'un nom d'image » ([Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)). Le bloc 3 fait les deux :

```text
== 3. Guardar la imagen en un archivo y escanear el archivo
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --severity HIGH,CRITICAL --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#'

Report Summary

┌──────────────────────────────────────────┬──────────┬─────────────────┬─────────┐
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ revisor                                  │ gobinary │        0        │    -    │
└──────────────────────────────────────────┴──────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)
```

La première commande enregistre l'image dans un fichier `.tar` de 3.6 MB, **uniquement pour ta plateforme** (`--platform linux/arm64` ; sur ton Mint, ce serait `linux/amd64`). Les 3.6 MB sont l'image compressée ; les 16.2 MB qu'affichait `docker image ls` sont décompressés. La seconde commande, par morceaux :

- `docker run --rm` lance Trivy et le supprime à la fin ; `-v curso-docker-trivy-cache-fig10:/root/.cache` est le cache de la base de données (dans ton dossier, `-v curso-docker-trivy-cache:/root/.cache`), dans un **volume nommé** pour qu'il survive entre les exécutions et puisse être supprimé à la fin.
- `-v "$PWD":/trabajo:ro` monte ton dossier actuel dans `/trabajo`, en **lecture seule** (`:ro`) : Trivy peut lire le `.tar`, pas écrire dans ton dossier. C'est le moindre privilège appliqué au scanner.
- `image --quiet --input /trabajo/revisor-1.6.0.tar` demande d'analyser le fichier, sans la barre de progression.
- `--severity HIGH,CRITICAL` fixe le **seuil** : il ne signale que les failles graves et critiques. La documentation sur le filtrage l'illustre avec exactement cette option ([Trivy, « Filtering »](https://trivy.dev/latest/docs/configuration/filtering/)).
- `--exit-code 1` indique à Trivy quel code de sortie renvoyer « quand il trouve des problèmes de sécurité » (c'est ainsi que la référence de la commande le décrit). Par défaut, il sort avec 0 même s'il trouve des choses (le bloc 4b le mesure) ; avec `1`, un script ou un *pipeline* peut **échouer** s'il y a des constats. C'est l'astuce qui transforme un rapport en barrière.
- `sin_fechas` et le `sed` ne sont là que pour la présentation dans le script : le premier retire les avis horodatés que Trivy imprime au début de la ligne (pour que la sortie puisse être comparée d'une exécution à l'autre) et le second raccourcit `/trabajo/` en `./`. Tu n'en as pas besoin quand tu exécutes la commande toi-même.

Le tableau se lit de haut en bas. `Report Summary` est l'en-tête ; chaque ligne est une **cible** analysée. La première est `./revisor-1.6.0.tar (debian 13.7)`, de type `debian` : les paquets système de la base, avec **0** constat. La seconde est `revisor`, de type `gobinary` : Trivy a reconnu qu'il y a un binaire Go dans le fichier, a lu les modules qu'il porte gravés et les a vérifiés aussi, avec **0** constat. La colonne `Secrets` indique `-`. Trivy cherche par défaut les vulnérabilités et les secrets (la référence de `trivy image` donne `vuln,secret` comme valeur de `--scanners`), mais pour les secrets, il n'enregistre que les constats, si bien que la documentation précise que le `-` de cette colonne signifie « aucun constat » et ne distingue pas entre « on n'a pas cherché » et « on a cherché et il n'y avait rien » ([Trivy, « Reporting »](https://trivy.dev/latest/docs/configuration/reporting/)). Une raison de plus de ne pas lire un zéro comme une garantie. Et le `0` de la légende dit `Clean (no security findings detected)` : « propre, aucun constat de sécurité détecté ». Avec le seuil `HIGH,CRITICAL`, le code de sortie a été 0, et c'est pourquoi le script n'imprime pas `[código de salida: …]`. Remarque le mot de la légende : *detected*. C'est la nuance de l'avertissement précédent.

#### 10.10.4 Le seuil décide de ce que tu vois, et `UNKNOWN` compte aussi

Voici maintenant la même image, **sans** `--severity`, avec le même `--exit-code 1`. Le bloc 4 l'analyse avec toutes les gravités et filtre le résultat pour ne garder que les tableaux :

```text
== 4. El mismo archivo, con todas las severidades y el mismo --exit-code 1
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#' | grep -E 'Total|│' 
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
│ revisor                                  │ gobinary │        0        │    -    │
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
│     Library     │ Vulnerability │ Severity │ Status │ Installed Version │  Fixed Version   │               Title               │
│ ca-certificates │ DSA-6572-1    │ UNKNOWN  │ fixed  │ 20250419          │ 20250419+deb13u1 │ ca-certificates - security update │
[código de salida: 1]
```

Il apparaît **un constat** que le seuil précédent cachait. Il faut lire chaque colonne du dernier tableau : `Library` est le paquet (`ca-certificates`, celui de la nomenclature logicielle de 10.6) ; `Vulnerability` est l'identifiant (`DSA-6572-1`, un *Debian Security Advisory*, avis de sécurité de Debian) ; `Severity` est `UNKNOWN`, inconnue ; `Status` est `fixed`, corrigée ; `Installed Version` est `20250419`, celle qu'a l'image ; `Fixed Version` est `20250419+deb13u1`, la version de Debian qui corrige déjà la faille ; et `Title` est le titre de l'avis. Une ligne résume : `Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)`. Les catégories sont au nombre de cinq, et Trivy les liste ainsi dans son résumé : `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` ([Trivy, « Reporting »](https://trivy.dev/latest/docs/configuration/reporting/)). Quatre vont de la moins grave à la plus grave ; `UNKNOWN` n'est pas « moins grave que `LOW` » : c'est « non classé ». La documentation de Trivy dit qu'elle est utilisée quand aucune source n'a attribué de gravité au constat (« si aucun fournisseur n'a de sévérité, `UNKNOWN` sera utilisée » ; [Trivy, « Vulnerability »](https://trivy.dev/latest/docs/scanner/vulnerability/)). C'est pourquoi on ne l'écarte pas sans l'avoir examinée.

Trois leçons dans ce bloc :

1. **Le seuil est une décision à toi, pas un détail.** Avec `HIGH,CRITICAL`, l'image « passe » ; avec toutes les gravités, elle a un constat. Aucune des deux n'est un mensonge, mais elles répondent à des questions différentes. Choisis le seuil avant de regarder le résultat, et écris-le (dans le *pipeline*, dans le README du projet) pour que personne ne l'ajuste ensuite afin que ça passe au vert.
2. **`UNKNOWN` compte.** Le constat est de gravité `UNKNOWN`, et pourtant `--exit-code 1` a renvoyé **1** (la ligne `[código de salida: 1]`). Autrement dit : sans `--severity`, même ce que le scanner ne sait pas classer fait échouer ta barrière. Si tu préfères que l'inconnu n'échoue pas, déclare-le avec `--severity` en listant les gravités qui t'importent. Ce qui n'est pas souhaitable, c'est de ne pas le savoir.
3. **Un constat `fixed` est exploitable.** L'état `fixed` et la colonne `Fixed Version` disent qu'il existe une version corrigée. La solution n'est pas de l'oublier ni d'éteindre le scanner : c'est de mettre à jour le paquet. La façon de mettre à jour un paquet d'une base distroless que tu as figée par *digest* est l'objet de la section 10.12.

Et le contraste qui explique à quoi sert `--exit-code`. Le bloc 4b exécute **la même analyse sans cette option** et demande le code de sortie de Trivy lui-même avec `echo "código de Trivy: $?"` :

```text
== 4b. Lo mismo, sin --exit-code: ¿con qué código sale Trivy por omisión?
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 0
```

Même constat (`Total: 1`) et code **0**. Sans `--exit-code`, Trivy informe mais n'échoue pas : un script qui se contente de le lancer continuerait avec un constat grave sans s'en apercevoir. Cela a été mesuré, pas supposé : une analyse dans un *pipeline* sans `--exit-code` est un ornement qui dit « bien » même s'il y a des constats. C'est le même genre de piège que tu connais déjà des leçons précédentes : le code de sortie est ce que lit la machine, et il faut vérifier qu'il change vraiment quand il le faut.

#### 10.10.5 `--ignore-unfixed` : une intuition qui tourne mal

Il existe une option qui ressemble à une solution de facilité : `--ignore-unfixed`, que la référence de la commande décrit comme « n'afficher que les vulnérabilités corrigées » (*display only fixed vulnerabilities*, [Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)) et que la page des filtres présente comme le moyen d'« ignorer toutes les vulnérabilités sans correctif » (*skip all unfixed vulnerabilities*, [Trivy, « Filtering »](https://trivy.dev/latest/docs/configuration/filtering/)). L'intuition dit : « ignorons ce qui n'a pas de correctif, pour que n'échoue que ce que je peux corriger ». Le bloc 5 la teste, et il faut bien lire le nom :

```text
== 5. ¿Y si se ignora lo que no tiene arreglo?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignore-unfixed --exit-code 1 2>&1 | sin_fechas | grep -E '^Total'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
[código de salida: 1]
```

Le même constat reste, et le code 1 aussi. Et ce n'est pas une erreur de Trivy : `--ignore-unfixed` cache ce qui **n'a pas** de version corrigée, et ce constat **en a une** (`fixed`, `20250419+deb13u1`). L'option fait ce qu'elle dit ; ce qu'elle ne fait pas, c'est résoudre ton problème, parce que ton problème est de ceux qui ont un correctif. C'est un bon exemple de la raison pour laquelle on teste une option au lieu de supposer ce qu'elle fait d'après son nom.

#### 10.10.6 De quand date ce qu'il sait ?

Le dernier bloc répond à une question qui devrait accompagner toute analyse : contre quelle date a-t-on comparé ?

```text
== 6. ¿De cuándo es la base de datos de vulnerabilidades?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 version 2>&1 | sin_fechas
Version: 0.76.0
Vulnerability DB:
  Version: 2
  UpdatedAt: 2026-10-21 19:18:22.876313144 +0000 UTC
  NextUpdate: 2026-10-22 19:18:22.876312904 +0000 UTC
  DownloadedAt: 2026-10-22 00:17:14.540681058 +0000 UTC
```

`trivy version` imprime la version du programme et les données de sa base de données : quand la dernière version a été **publiée** (`UpdatedAt` : 21 octobre, 19:18 UTC), quand la suivante est attendue (`NextUpdate` : un jour plus tard) et quand elle a été **téléchargée** dans ton cache (`DownloadedAt`). Les trois lignes de la fin sont celles que tu conserves à côté du résultat de l'analyse : un « 0 constat » sans date de base de données est une donnée sans âge, et les données sans âge pourrissent.

Deux limites de l'analyse faite ainsi, que la leçon a déjà laissé voir et qui se rejoignent maintenant. Une : tu as analysé **une plateforme**, celle de ta machine ; l'`amd64` de l'index n'a pas été vérifié. Pour une vraie livraison, on répète le `docker save --platform` et l'analyse pour chaque plateforme publiée. Deux : le scanner vérifie ce qu'il y a *dans* l'image ; il ne vérifie ni ton `Dockerfile` ni tes permissions d'exécution (cela, c'est ce qu'ont couvert `docker build --check` dans la Leçon 3 et les mesures des leçons 7 et 8). C'est une couche de défense, pas la défense.

### 10.11 Le pont vers Kubernetes : `kind load docker-image`

#### 10.11.1 Pourquoi le cluster ne voit pas ton image

Le cours suivant, celui de Kubernetes avec `kind`, prend l'image avec laquelle tu sors d'ici. `kind` (*Kubernetes IN Docker*) démarre un cluster Kubernetes dans des conteneurs Docker : chaque « nœud » du cluster est un conteneur. Cela a une conséquence surprenante : même si le nœud tourne dans ton Docker, **il a son propre magasin d'images** à l'intérieur. Ce que tu as construit avec `docker build` vit dans le magasin de ton Docker, et le nœud ne le voit pas. Un pod qui demande `curso-docker-revisor:1.6.0` essaierait de la télécharger depuis un registre, et cette image n'existe que sur ta machine.

Il y a deux façons de résoudre cela : publier l'image dans un registre que le cluster peut atteindre, ou **la charger directement dans les nœuds**. Dans un laboratoire local, la seconde est la plus courte, et c'est celle qu'utilise cette leçon. La documentation de `kind` la présente ainsi : « tu peux charger une ou plusieurs images dans ton cluster `kind` » avec `kind load docker-image mon-app:latest`, et si le cluster a un nom, il faut l'indiquer avec `--name` ([kind, « Quick Start »](https://kind.sigs.k8s.io/docs/user/quick-start/)). La même page contient un avertissement avec deux conditions qui sont justement ce que tu vas voir : « la politique de téléchargement par défaut de Kubernetes est `IfNotPresent`, sauf si le tag est `:latest` ou n'est pas écrit » ; pour que les images chargées fonctionnent comme tu l'attends, **n'utilise pas le tag `:latest`** et/ou spécifie `imagePullPolicy: IfNotPresent` ou `imagePullPolicy: Never` dans ton conteneur.

La politique `Never` est celle qu'utilise le test. La documentation de Kubernetes la définit ainsi : « le kubelet n'essaie pas de télécharger l'image. Si l'image est déjà présente localement, le kubelet essaie de démarrer le conteneur ; sinon, le démarrage échoue » ([Kubernetes, « Images »](https://kubernetes.io/docs/concepts/containers/images/)). Pour un test, c'est la politique idéale, parce qu'elle aide à ne pas masquer les problèmes de transport : si l'image n'est pas arrivée sur le nœud, le pod ne démarre pas et le dit, au lieu d'essayer de la télécharger d'internet et de traîner (ou, pire, de télécharger *une autre* image du même nom). Une limite : si le nœud avait déjà une vieille image avec ce même tag, `Never` la démarrerait sans prévenir ; c'est pourquoi, en test, on utilise un cluster neuf ou une nouvelle version.

#### 10.11.2 Installer `kind` et `kubectl`

Jusqu'ici, tout s'est fait avec Docker. Cette étape demande deux programmes de plus que tu n'as **pas** installés dans les leçons précédentes : `kind` et `kubectl`. Si ta machine est le Linux Mint du cours, installe-les avec les guides officiels, avec la version figée (celles de ce cours, mesurées le 21 octobre 2026). `kind` se télécharge comme un binaire ([kind, « Quick Start »](https://kind.sigs.k8s.io/docs/user/quick-start/)) ; `kubectl`, depuis `dl.k8s.io`, avec une vérification de sa somme `sha256` ([Kubernetes, « Install and Set Up kubectl on Linux »](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)) :

```bash
# kind v0.33.0 (elige la línea de tu procesador; `uname -m` dice x86_64 o aarch64)
[ "$(uname -m)" = x86_64 ]  && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
[ "$(uname -m)" = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl v1.37.1
ARQ=amd64; [ "$(uname -m)" = aarch64 ] && ARQ=arm64
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl"
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

Les deux premières lignes de `kind` sont celles du guide officiel : chacune ne s'exécute que si ton processeur est celui qu'elle indique, si bien que sur ta machine, exactement une s'exécute. La ligne `sha256sum --check` est celle qui protège le téléchargement : elle doit répondre `kubectl: OK` ; si elle répond `FAILED`, supprime le fichier et télécharge-le de nouveau. `sudo install -o root -g root -m 0755` copie le programme dans `/usr/local/bin` avec le propriétaire `root` et la permission d'exécution, ce qui est la façon qu'indique le guide. La séquence de téléchargement et de vérification a été testée dans la machine virtuelle des exécutions (Ubuntu 24.04, `arm64`), avec le script `fig10_00.sh` (blocs 2 et 3, avec leur sortie à côté), sans l'installation dans `/usr/local/bin` pour ne pas modifier le système, et a répondu :

```text
$ ./kind version
kind v0.33.0 go1.26.7 linux/arm64
$ echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
kubectl: OK
$ ./kubectl version --client
Client Version: v1.37.1
Kustomize Version: v5.8.1
```

(La version de Go avec laquelle `kind` a été compilé change selon la plateforme où tu l'exécutes : sur le Mac des exécutions, il a dit `go1.27.0 darwin/arm64`.) Vérifie ton installation avec `kind version` et `kubectl version --client`.

#### 10.11.3 Le cluster et l'image

Le script `fig10_06.sh` s'exécute sur le **Mac** (pas dans la machine virtuelle) parce que c'est là que vivent `kind` et `kubectl` ; ils parlent au même daemon Docker. Il a un détail qu'il faut expliquer avant de lire la sortie : il utilise un fichier de configuration de `kubectl` **à lui et temporaire** (`export KUBECONFIG=…` dans le script). Ainsi, le cluster qu'il crée ne modifie ni ton contexte `kubectl` ni ton fichier `~/.kube/config`. **Sur ta machine, en suivant la leçon, tu veux le contraire :** que `kind` change ton contexte vers le nouveau cluster, et c'est pourquoi les commandes ci-dessous ne comportent pas `KUBECONFIG`. Malgré cela, et c'est une habitude qui vaut la peine dès aujourd'hui, **avant chaque commande `kubectl`, vérifie dans quel cluster tu te trouves** avec `kubectl config current-context` : un `kubectl delete` dans le mauvais contexte est le genre d'erreur qu'on ne défait pas.

Les premières sections du script :

```text
$ ./fig10_06.sh
== 1. Versiones
$ kind version
kind v0.33.0 go1.27.0 darwin/arm64
$ kubectl version --client | head -1
Client Version: v1.37.1

== 2. La imagen, para la plataforma de este equipo
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker image ls curso-docker-revisor:fig10 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:fig10 16.2MB

== 3. Un clúster kind de un nodo
$ kind create cluster --name curso-docker-puente-fig10 --wait 120s 2>&1 | grep -E '^Creating|Ready after|Set kubectl context' | sed -E 's/Ready after [0-9]+s/Ready after Ns/; s/ +[^ -~]+//g'
Creating cluster "curso-docker-puente-fig10" ...
 Ready after Ns
Set kubectl context to "kind-curso-docker-puente-fig10"
$ kubectl config current-context
kind-curso-docker-puente-fig10
```

Les versions sont celles du cours : `kind` v0.33.0, qui utilise par défaut l'image de nœud `kindest/node:v1.37.0`, c'est-à-dire Kubernetes 1.37.0 ([kind, notes de la v0.33.0](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0)), et `kubectl` v1.37.1. Ensuite, `docker build` construit l'image **pour la plateforme de cette machine** (ici `arm64`). Dans ton dossier, la commande est `docker build --build-arg VERSION=1.6.0 -t curso-docker-revisor:1.6.0 .`, qui laisse l'image dans ton Docker avec le nom qu'utilisera le cours suivant ; le script utilise le tag d'appoint `fig10`. `docker build` tout court construit pour la plateforme native et laisse le résultat dans le magasin local, ce qui est justement ce que `kind load` va lire. Elle pèse 16.2 MB. `kind create cluster --name … --wait 120s` crée le cluster d'un nœud et attend jusqu'à deux minutes qu'il soit prêt ; le `grep` et le `sed` du script ne gardent que les trois lignes qui comptent (le reste, ce sont des indicateurs de progression avec des symboles), et la durée réelle (`Ready after Ns`) est masquée parce qu'elle change d'une exécution à l'autre. `kind` a fini par fixer le contexte : `kubectl config current-context` répond `kind-curso-docker-puente-fig10`. Le contexte que `kind` crée s'appelle `kind-` plus le nom du cluster (c'est ainsi qu'il est sorti à l'exécution), si bien que le préfixe du cours (`curso-docker-`) se transmet jusqu'au nom de ton contexte.

#### 10.11.4 Provoquer l'erreur avant la solution

Le concret d'abord : demande le pod **avant** de charger l'image et lis ce qu'il dit. Voici le bloc 4 :

```text
== 4. El error: el pod ANTES de cargar la imagen
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
$ kubectl get events --field-selector involvedObject.name=revisor,reason=ErrImageNeverPull -o custom-columns=MENSAJE:.message | head -2 | cut -c1-110
MENSAJE
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
```

`kubectl run revisor --image=… --image-pull-policy=Never --port=8080 --env=…` crée un pod avec un conteneur. `--image-pull-policy=Never` est la politique vue plus haut ; `--port=8080` déclare le port qu'il écoute ; `--env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'` est la même variable que dans les sections précédentes (le `revisor` s'interroge lui-même, pour que le test ne dépende d'aucun autre pod). Ensuite, `kubectl get pod … -o custom-columns=…` imprime un tableau avec les colonnes que tu choisis, avec leurs chemins dans l'objet du pod : l'état (`phase`) est `Pending` et la raison d'attente (`waiting.reason`) est **`ErrImageNeverPull`**. Le nom raconte déjà l'histoire : erreur d'image, avec la politique `Never`, qui n'a pas essayé de la télécharger. L'événement le confirme par une phrase complète : `Container image "…" is not present with pull policy of Never` : l'image n'est pas présente et la politique interdit de la télécharger. Voilà l'erreur : le nœud n'a pas l'image. Rien n'est cassé dans l'image ni dans le pod ; il manque l'étape qui l'amène jusque-là. Avant de continuer, le script supprime le pod en échec (`kubectl delete pod revisor --wait=true`), parce qu'un pod ne change pas sa politique tout seul et que repartir de zéro est plus propre.

#### 10.11.5 Charger l'image et redemander le pod

```text
== 5. Cargar la imagen en el nodo (sin registro) y volver a pedir el pod
$ kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10" with ID "sha256:0c8af76b8a5fbea25ddafedf41bc49ad9ec5f7144117559da98afbd1da0d2eaa" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10                dda2fbcae183b       3.68MB
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=90s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image,REINICIOS:.status.containerStatuses[0].restartCount
NOMBRE    ESTADO    IMAGEN                           REINICIOS
revisor   Running   curso-docker-revisor:fig10   0
$ kubectl logs revisor
revisor 1.6.0 escuchando en :8080 (1 servicio(s))
$ kubectl get events --field-selector involvedObject.name=revisor -o custom-columns=RAZON:.reason,MENSAJE:.message | cut -c1-110
RAZON               MENSAJE
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
ErrImageNeverPull   Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
Failed              Error: ErrImageNeverPull
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
Pulled              Container image "curso-docker-revisor:fig10" already present on machine and can be acc
Created             Container created
Started             Container started
```

`kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10` lit l'image dans ton Docker et la copie vers le nœud. Il imprime une seule ligne, qui se lit ainsi : l'image portant cet identifiant (`ID "sha256:0c8af76b…"`) **n'était pas encore présente sur le nœud** `curso-docker-puente-fig10-control-plane`, et il est en train de la charger. (Cet identifiant est celui de l'image locale, pas un *digest* de registre.) Vient ensuite la vérification qu'il ne faut pas sauter : demander au **nœud** quelles images il possède, avec `docker exec <nœud> crictl images` (`crictl` est l'outil en ligne de commande du runtime de conteneurs qui se trouve dans le nœud ; le nœud de `kind` est un conteneur Docker, c'est pourquoi `docker exec` y entre). Le `grep` garde l'en-tête et les lignes du `revisor`. Apparaît `docker.io/library/curso-docker-revisor`, tag `fig10`, 3.68 MB : l'image **est bien sur le nœud**, avec le nom complet que Kubernetes donne à un nom court. Cette ligne est la preuve que le chargement a fonctionné, et elle vaut mieux que de se fier au message `loading...`, comme tu le verras en 10.11.6. Ensuite, le même `kubectl run` qu'avant, et maintenant :

- `kubectl wait --for=condition=Ready pod/revisor --timeout=90s` attend jusqu'à 90 secondes que le pod soit prêt ; la réponse `condition met` est la condition remplie.
- Le tableau du pod indique `Running` avec l'image `curso-docker-revisor:fig10` et **0 redémarrage**.
- `kubectl logs revisor` montre ce que le `revisor` imprime au démarrage : `revisor 1.6.0 escuchando en :8080 (1 servicio(s))`. C'est la même ligne que dans la Leçon 3. La version `1.6.0` confirme que c'est l'image que tu as construite qui tourne.
- Les événements sont la preuve que le pont a fonctionné sans rien télécharger. Les trois premières lignes viennent de la tentative échouée d'avant (`ErrImageNeverPull`, `Failed`). Ensuite, le nouveau pod : `Scheduled` (affecté au nœud), puis `Pulled` avec le message **`Container image "…" already present on machine`** : « l'image est déjà présente sur la machine ». Même si l'événement s'appelle `Pulled` (téléchargée), le texte dit qu'il n'y a pas eu de téléchargement : il l'a trouvée déjà sur le nœud, où `kind load` l'avait déposée. Le message sort tronqué par le `cut -c1-110` du script (`…and can be acc`, de « and can be accessed by the container »). Puis `Created` et `Started`.

Cette phrase, `already present on machine`, est la preuve que recherche l'objectif 6 du cours : **le pod a démarré sans aucune tentative de téléchargement**. Quand le cours de Kubernetes commencera, tu répéteras ce pont avec `curso-docker-revisor:1.6.0` et le cluster `curso-docker-puente`.

Pour laisser propre ce que tu as fait sur ta machine (ton cluster, pas celui d'un script) : `kind delete cluster --name curso-docker-puente`. Il supprime le cluster et retire son contexte de ta configuration ; l'image de ton Docker n'est pas touchée.

#### 10.11.6 Si l'image n'est pas de ta construction : celle qui vient d'un registre

Il y a un cas que le cours suivant peut rencontrer : l'image, tu ne la construis pas sur ta machine, tu la **télécharges depuis le registre** par son *digest*, comme en 10.9. Il serait naturel de penser que `kind load docker-image` l'accepte avec cette même référence. Cela a été mesuré, et ce n'est pas le cas. Le script `fig10_09.sh` publie un index de deux plateformes, le télécharge par *digest* sur le Mac, crée le cluster et essaie trois chemins :

```text
== 3. Cargar la imagen traída del registro, por su referencia con digest
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB

== 4. Guardarla con docker save y cargar el archivo
$ docker save --platform linux/arm64 -o revisor.tar localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 && du -h revisor.tar | cut -f1
3.5M
$ kind load image-archive revisor.tar --name curso-docker-puente-fig10

== 5. ¿Qué nombres tiene la imagen dentro del nodo?
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120 | sed -E 's/([0-9a-f]{12})[0-9a-f]{52}/\1…/g'
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB

== 6. Pedir el pod con la MISMA referencia con digest, sin descarga
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
```

Et les deux chemins restants (les blocs 7 et 8) :

```text
== 7. Una etiqueta local sobre la misma imagen, y cargar esa etiqueta
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
$ docker tag localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 curso-docker-revisor:fig10-registro
$ kind load docker-image curso-docker-revisor:fig10-registro --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10-registro" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
$ kubectl run revisor --image=curso-docker-revisor:fig10-registro --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image
NOMBRE    ESTADO    IMAGEN
revisor   Running   curso-docker-revisor:fig10-registro
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace

== 8. Traer solo el manifiesto de la plataforma (no el índice) y cargarlo
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" with ID "sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
```

Cela se lit ainsi. **Chemin 1, charger la référence avec *digest* (bloc 3).** `kind load` imprime `not yet present on node … loading...` et ne donne aucune erreur. Ensuite, le script demande au nœud quelles images il possède, avec `crictl` (l'outil en ligne de commande du runtime de conteneurs qui se trouve dans le nœud), et le filtre laisse passer les lignes avec `revisor` **et celles qui n'ont pas de nom** (`<none>`). **Il n'y a aucune image nommée `revisor`, mais il y en a une sans nom :** `docker.io/library/import-2026-10-22`, tag `<none>`, 3.68 MB. L'image **est bien arrivée sur le nœud, sans le nom que lui demande le pod.** Le `import-` suivi de la date est le nom de remplissage que `ctr images import` (la commande avec laquelle `kind` importe, d'après les signalements cités plus bas) donne à ce qu'il importe sans référence propre ([containerd, `ctr images import`](https://github.com/containerd/containerd/blob/main/cmd/ctr/commands/images/import.go)) ; la date est celle de l'horloge du nœud, qui est en UTC, et c'est pourquoi elle indique 22 alors que les exécutions ont eu lieu le 21 à Mexico. **Chemin 2, enregistrer avec `docker save --platform` et charger le fichier avec `kind load image-archive` (bloc 4) :** la commande se termine sans erreur et sans sortie ; le bloc 5 montre la même ligne de 3.68 MB et une seconde, sans nom, de 2.32 kB (on n'a pas cherché ce qu'elle contient). Le bloc 6 en est la conséquence : un pod qui demande la référence avec *digest* reste en `Pending` avec `ErrImageNeverPull`, parce que le nœud n'a aucune image portant ce nom, même si son contenu y est. **Chemin 3, un tag local (bloc 7) :** `docker tag <référence avec digest> curso-docker-revisor:fig10-registro` donne un nom local à l'image téléchargée, `kind load docker-image` de ce tag dépose l'image sur le nœud **avec un nom** (`crictl` l'affiche comme `docker.io/library/curso-docker-revisor`, avec le tag `fig10-registro` et 3.68 MB ; la ligne sans nom de 3.68 MB n'y est plus, parce que c'était la même image : le même identifiant, `011d6bb2f3c70`) et le pod démarre : `Running`. Deux observations. Une : le nœud écrit le nom complet, `docker.io/library/…`, mais le pod qui demande `curso-docker-revisor:fig10-registro` le trouve, parce que Kubernetes complète le nom court de la même manière. Deux : **charger la référence du manifeste de la plateforme** (le bloc 8, qui télécharge `…@sha256:7d76…`, le manifeste d'`arm64` au lieu de l'index) n'a pas fonctionné non plus : le pod attend de nouveau avec `ErrImageNeverPull`. Le problème n'est donc pas l'index multiplateforme, mais la référence avec *digest*.

La règle pratique : **`kind load` fonctionne avec un nom accompagné d'un tag ; avec une référence par *digest*, il répond « loading » et ne laisse pas sur le nœud une image que le pod puisse trouver par cette référence.** Si ton image vient d'un registre, donne-lui d'abord un tag local avec `docker tag` et charge celui-là. **La source, dite avec exactitude.** Il n'existe pas de page de `kind` qui décrive ce cas tel quel (charger par une référence avec *digest* et ne recevoir aucune erreur). Ce qui existe dans le dépôt de `kind`, ce sont des signalements voisins, de même origine : avec Docker 29 et son magasin de *containerd*, `docker save` conserve l'index complet d'une image multiplateforme même si seules les couches de la tienne ont été téléchargées, et `kind load` (qui importe avec `ctr images import --all-platforms --digests`) échoue avec `content digest … not found`. Les mainteneurs l'attribuent au fait que `docker save` « a introduit des changements incompatibles lorsqu'on utilise le stockage reposant sur *containerd* » et indiquent comme issue rapide de ne pas utiliser ce magasin ([kind, issue #4066, « kind unable to load images with docker 29 »](https://github.com/kubernetes-sigs/kind/issues/4066), fermée comme doublon de l'issue épinglée, toujours ouverte, [#3795](https://github.com/kubernetes-sigs/kind/issues/3795) ; et [#4224](https://github.com/kubernetes-sigs/kind/issues/4224), qui répète l'erreur sur un Mac à processeur Apple avec OrbStack et a été résolue en important avec `ctr` sans `--all-platforms`). La différence avec ce qu'a mesuré cette leçon, c'est le symptôme : ici, **il n'y a pas eu d'erreur**, et l'image est arrivée sur le nœud **sans nom** (`<none>`), si bien que le pod ne la trouve pas. Pour ce symptôme précis : **mesuré, sans source officielle.** On n'a pas non plus cherché pourquoi le tag local laisse l'image avec un nom (hypothèse non mesurée : l'image du tag a été téléchargée avec les seules couches de ta plateforme, et le nom court change ce que `kind` exporte). C'est pourquoi la règle pratique est de toujours vérifier avec `crictl images`, en regardant aussi les lignes `<none>`. (C'est l'avertissement le plus lourd de conséquences pour le cours suivant : la commande confortable échoue en silence, et le symptôme, `ErrImageNeverPull`, apparaît plus tard, dans le pod.)

### 10.12 La base figée vieillit : renouveler le *digest*

Il reste le constat de 10.10 : `ca-certificates`, version `20250419`, avec un correctif disponible en `20250419+deb13u1`. D'où vient cette vieille version ? De la **base** de l'image, `gcr.io/distroless/static-debian13:nonroot`, qui depuis la Leçon 5 est figée par *digest* : `@sha256:516757106de35…`. Figer par *digest* t'a donné exactement ce que tu cherchais : que la base ne change pas sous tes pieds. Et l'autre face de la même chose, c'est que **la base ne reçoit pas non plus de correctifs toute seule**. La documentation de Docker le dit en toutes lettres : figer sur un *digest* revient à « renoncer à recevoir automatiquement les correctifs de sécurité, ce qui est probablement quelque chose que tu veux recevoir », et il est « fastidieux » de chercher et d'écrire le nouveau *digest* ; elle recommande d'automatiser la vérification, avec Docker Scout (qui signale si ta base figée n'est plus la version en vigueur) ou avec Dependabot (qui ouvre des demandes de modification programmées pour mettre à jour les tags et les *digests*) ([Docker, « Building best practices »](https://docs.docker.com/build/building/best-practices/)).

Ce qui importe ici, c'est la procédure, qui est courte et peut se faire manuellement : (1) demander au registre de la base vers quel *digest* pointe aujourd'hui le tag ; (2) changer le *digest* dans le `Dockerfile` ; (3) reconstruire ; (4) analyser de nouveau ; (5) tester de nouveau. Les Exercices 2 et 4 le font avec des mesures. Un avant-goût qu'il faut dire avec précision, parce qu'il est facile de s'y perdre : ce qui a bougé le jour des exécutions, c'est **le tag** `nonroot`, pas ton *digest*. À neuf heures du matin, heure de Mexico, ce tag pointait déjà vers `sha256:d62067879de8…`, alors que le `Dockerfile` fige `sha256:516757106de3…` ; et le *digest* figé **existe toujours et pointe toujours vers la même image qu'avant** (l'Exercice 2 le vérifie en le demandant par son *digest*). C'est ce que promettait le fait de figer : que la base ne change pas sans que tu l'aies décidé. La conséquence est l'autre face de la même médaille : les correctifs que Debian publie n'arrivent que lorsque tu changes le *digest*. La décision de cette leçon est de rester sur la base figée, parce que toutes les sorties que tu lis ont été mesurées avec elle, et de présenter le renouvellement pour ce qu'il est, **un acte délibéré** (l'Exercice 4 le fait et mesure que l'analyse passe à 0 constat). L'image `1.6.0` que livre le cours conserve sa base figée et son constat documenté. Dans un vrai projet, ce que tu fais, c'est renouveler exprès, avec une nouvelle version.

Il y a une frontière à ne pas franchir : **on ne renouvelle pas pour renouveler.** Une nouvelle base est un changement : elle peut apporter une bibliothèque différente, elle peut changer le comportement de quelque chose. C'est pourquoi la procédure se termine par les tests du `revisor` (que l'étape `pruebas` de ton `Dockerfile` exécute déjà à la construction) et par une nouvelle exécution de l'image. Et cela se fait dans une construction avec une **nouvelle version** (`1.6.1`), selon la règle de 10.3 : on ne réutilise pas un tag publié.

## L'erreur que tu vas voir

Cette leçon comporte six messages qu'il faut savoir reconnaître, un par outil (deux concernent le pont vers Kubernetes, le 1 et le 6). Tous sont déjà apparus ; ils sont réunis ici pour que tu les retrouves vite.

**1. Le pod qui ne démarre pas : `ErrImageNeverPull`.** C'est celui de `fig10_06.sh` :

```text
revisor   Pending   ErrImageNeverPull
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
```

Il se lit de droite à gauche, comme ceux des leçons précédentes. « With pull policy of Never » dit que la politique interdit de télécharger ; « is not present » dit que le nœud n'a pas l'image. Les deux ensemble signifient : personne ne l'a chargée. On résout avec `kind load docker-image <image> --name <cluster>`, en vérifiant que le nom et le tag sont **exactement** ceux du pod. Si tu la charges et que cela échoue encore, c'est souvent un tag différent : vérifie avec `kubectl get pod revisor -o custom-columns=IMAGEN:.spec.containers[0].image` quel nom demande le pod (c'est la même colonne `IMAGEN` que tu as déjà utilisée).

**2. Trivy qui ne trouve pas l'image.**

```text
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]
```

Cela veut dire qu'il a cherché à ces quatre endroits et ne l'a pas trouvée. La solution n'est pas de lui donner le *socket* de Docker : c'est d'enregistrer l'image avec `docker save` et d'analyser le fichier avec `--input`.

**3. `docker save` avec une plateforme que tu n'as pas.**

```text
Error response from daemon: no suitable export target found: image with reference … was found but does not provide the specified platform (linux/amd64)
```

L'image existe dans ton magasin, mais cette plateforme n'a jamais été téléchargée. La solution : récupérer d'abord cette plateforme avec `docker pull --platform linux/amd64 <référence>` et enregistrer de nouveau (le bloc 11 de `fig10_04.sh` l'a mesuré : après le `pull`, le `save` répond `guardada: linux/amd64`).

**4. La construction émulée qui plante.**

```text
fatal error: fault
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
```

Cela coïncide avec l'émulation et non avec ton code : le même `Dockerfile` compile bien sur le processeur natif et avec la compilation croisée. On le résout en évitant l'émulation : compilation croisée avec `--platform=$BUILDPLATFORM` dans les étapes de compilation et `GOOS=$TARGETOS GOARCH=$TARGETARCH` dans `go build`.

**5. Le `500` du rapport avec `read-only file system`.** C'est celui de la Leçon 8, qui réapparaît avec l'image récupérée par *digest* :

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

L'image est bonne et le système en lecture seule fonctionne : il manque un volume monté dans `/datos`.

**6. `kind load` qui dit « loading » et ne charge pas.** C'est celui de 10.11.6 : en chargeant une image téléchargée depuis un registre par une référence avec *digest*, `kind` ne donne pas d'erreur et ne laisse pas sur le nœud une image que le pod puisse trouver par cette référence (elle arrive sans nom, comme `<none>`), et le pod reste en `Pending` avec `ErrImageNeverPull`. On le résout en lui donnant d'abord un tag local avec `docker tag` et en chargeant ce tag ; pour vérifier qu'elle est arrivée, `docker exec <nœud> crictl images` doit afficher l'image avec le nom que demande le pod.

## L'habitude de sécurité de la leçon

Cette leçon installe quatre habitudes, et les quatre ont été pratiquées avec des mesures :

- **Ce qui s'exécute est référencé par *digest*.** Un tag bouge et un *digest* ne bouge pas ; l'accident que cela évite est celui de la scène (deux personnes avec le « même » nom et des contenus différents) et l'attaque que cela complique est celle qui remplace dans le registre une image à laquelle d'autres font déjà confiance par son nom. Mesuré en 10.3.
- **Ce qui est publié apporte sa nomenclature logicielle et sa provenance, et la provenance est publiée propre.** `mode=max` expose les valeurs des arguments de construction, donc aucun secret ne voyage par `--build-arg` : il entre par `--mount=type=secret`. Mesuré en 10.7.
- **On analyse sans donner le *socket* de Docker à personne.** `docker save`, `--input`, dossier monté en `:ro`. L'accident que cela évite est de confier le contrôle du daemon à un outil qui télécharge des données d'internet. Mesuré en 10.10.
- **L'analyse a un seuil écrit et une date de base de données.** Un « zéro » sans seuil et sans date n'est pas une donnée. Mesuré en 10.10.4 et 10.10.6.

## Ce qui se fait de travers

- **Réutiliser un tag publié** (« c'est la même version, j'ai juste corrigé un détail »). C'est l'erreur de la scène. Chaque construction livrée porte un nouveau tag ; si quelque chose est corrigé, c'est la `1.6.1`.
- **Publier `latest`.** Kubernetes la traite différemment (sa politique par défaut change avec ce tag, et la documentation de `kind` demande de ne pas l'utiliser avec des images chargées), et elle ne dit pas de quelle version il s'agit. Le tag `latest` n'est pas un nom de version : c'est un nom quelconque qui, par convention, se déplace.
- **Donner le *socket* de Docker à Trivy** (ou à n'importe quel conteneur) « pour qu'il lise l'image ». Qui possède le *socket* contrôle le daemon, et avec lui la machine. On le résout avec `docker save` et `--input`.
- **Analyser une seule fois et l'oublier.** La base de données de failles change chaque jour. Un résultat vaut avec sa date, et une livraison est analysée de nouveau avant d'être utilisée.
- **Fixer le seuil après avoir vu le résultat.** Si l'analyse échoue et que tu abaisses le seuil jusqu'à ce qu'elle passe, l'analyse ne sert plus à rien. Le seuil s'écrit avant.
- **Ignorer un constat sans raison ni date d'expiration.** Un `.trivyignore` avec des identifiants isolés est une liste de problèmes que quelqu'un a décidé de taire sans laisser la raison. Chaque ligne porte un commentaire avec la raison et un `exp:` avec la date à laquelle l'avis expire (Exercice 3).
- **Figer la base par *digest* et ne plus jamais la regarder.** Le fait de figer protège des changements inattendus, et aussi des correctifs attendus. On programme une vérification (Docker Scout, Dependabot ou une tâche à toi).
- **Passer des secrets par `--build-arg` et publier avec `mode=max`.** Les valeurs restent écrites dans la provenance qui voyage avec l'image. Les secrets de construction entrent par `--mount=type=secret`.
- **Construire pour une autre plateforme par émulation quand on peut compiler en croisé.** Plus lent, et sur cette machine, cela n'a même pas fonctionné.
- **Un registre sur `0.0.0.0:5000` sans TLS ni authentification.** N'importe qui sur ton réseau peut pousser ou télécharger. On le publie sur `127.0.0.1`, ou on met TLS et un contrôle d'accès.
- **Envoyer une image par chat sous forme de fichier `.tar`.** Celui qui la reçoit ne sait ni de qui elle vient ni ce qu'elle contient. On la publie dans un registre et on partage le *digest*.
- **Prendre « analysée » pour « sûre ».** L'analyse vérifie ce que ses bases de données connaissent aujourd'hui dans les paquets qu'elle reconnaît. C'est une couche de vérification, pas une garantie.
- **Charger avec `kind load` une image au tag `latest` et s'attendre à ce que le pod ne la télécharge pas.** Avec ce tag, la politique par défaut est autre. Écris `imagePullPolicy` ou utilise un tag de version.

## Exercices

Les quatre ont leur solution mesurée plus bas, avec le script qui l'a produite. Essaie chacun avant de la regarder.

### Exercice 1 — Deux tags, un *digest*

Tu as la `1.6.0` publiée dans ton registre local. Tu veux que celui qui demande `1.6` (la « ligne » 1.6, sans le dernier numéro) reçoive **exactement la même image** que celui qui demande `1.6.0`, sans rien reconstruire. Ajoute le tag `1.6` à l'image déjà publiée, vérifie avec le registre qu'il y a maintenant deux tags, et démontre avec `imagetools inspect` que les deux ont le même *digest*. Indice : `docker buildx imagetools create -t <destination> <origine>` crée un nouveau tag à partir d'une référence qui se trouve déjà dans le registre.

### Exercice 2 — Quel *digest* a la base aujourd'hui ?

Ton `Dockerfile` fige la base `gcr.io/distroless/static-debian13:nonroot` par *digest*. Détermine (a) les douze premiers caractères du *digest* qu'apporte ton `Dockerfile` et (b) ceux du *digest* vers lequel pointe aujourd'hui ce même tag dans le registre de Google. Décide en une phrase si ta base est à jour. Indice : `docker buildx imagetools inspect` sert aussi pour les images d'autres registres.

### Exercice 3 — Accepter un constat par écrit

Trivy a signalé `DSA-6572-1` (`UNKNOWN`) dans `ca-certificates`. Suppose que tu ne peux pas renouveler la base aujourd'hui. Écris un fichier `.trivyignore` qui accepte **ce** constat, avec un commentaire qui donne la raison et un `exp:` qui fixe la date d'expiration, et démontre quatre choses : sans le fichier, Trivy sort avec le code 1 ; avec le fichier, il sort avec 0 ; si le fichier ignore **un autre** identifiant, il sort de nouveau avec 1 (le fichier ne tait que ce qu'il dit, pas tout) ; et si l'`exp:` est déjà passé, le constat revient et Trivy sort de nouveau avec 1.

### Exercice 4 — Renouveler la base et analyser de nouveau

Change dans ton `Dockerfile` le *digest* de la base pour celui que tu as déterminé à l'Exercice 2 (b), reconstruis l'image, vérifie qu'elle affiche toujours `1.6.0` avec `version`, enregistre de nouveau l'image avec `docker save` et analyse de nouveau **avec toutes les gravités** et avec `--exit-code 1`. Qu'est-ce qui a changé dans le résultat ? Écris la réponse dans ton journal de bord avec la date : sans la date, le résultat ne sert à rien.

## Solutions

### Solution 1

C'est la première partie de `fig10_08.sh`. Avec la `1.6.0` déjà poussée, `imagetools create` crée le nouveau tag directement dans le registre, à partir d'une référence qui s'y trouve déjà. Le résultat, comme tu vas le voir, est un autre nom pour le même index.

```text
$ ./fig10_08.sh
== Ejercicio 1. Dos etiquetas, un digest
$ docker buildx imagetools create -t localhost:5000/curso-docker-revisor:1.6 localhost:5000/curso-docker-revisor:1.6.0 >/dev/null 2>&1 && echo 'etiqueta 1.6 creada'
etiqueta 1.6 creada
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["1.6","1.6.0"]}
$ for t in 1.6.0 1.6; do docker buildx imagetools inspect localhost:5000/curso-docker-revisor:$t --format '{{json .Manifest.Digest}}'; echo; done
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
```

Cela se lit ainsi. `create -t …:1.6 …:1.6.0` dit « crée le tag `1.6` en pointant vers ce qu'est aujourd'hui `1.6.0` » ; le `>/dev/null 2>&1` cache sa sortie de progression et le `&& echo` confirme que tout s'est bien terminé. La liste des tags en contient désormais deux, `1.6` et `1.6.0`. Et la boucle demande, pour chaque tag, le *digest* de l'index : les deux lignes sont **identiques** (`125ba52e…`). Deux noms, une image. C'est ce que l'on attend d'un tag qui suit la ligne 1.6 : un nom mobile et lisible qui, à cet instant, désigne la même chose que le tag fixe. Le revers, que tu connais déjà : le `1.6` est un tag qui, lui, **se déplace** (quand tu publieras la `1.6.1`, tu le ferais pointer vers elle), donc il sert aux humains et jamais à vérifier.

### Solution 2

Elle se trouve dans `fig10_07.sh`. La première commande extrait du `Dockerfile` les douze premiers caractères du *digest* qu'il fige ; la seconde demande au registre de Google celui du tag `nonroot` et en coupe le début :

```text
$ ./fig10_07.sh
== Ejercicio 2. ¿Qué digest tiene HOY la etiqueta nonroot de la base?
$ grep -oE 'static-debian13:nonroot@sha256:[0-9a-f]{12}' Dockerfile
static-debian13:nonroot@sha256:516757106de3
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:d62067879de8
(y el digest que fija el Dockerfile, ¿sigue existiendo en el registro?)
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:516757106de3
```

Le `Dockerfile` fige `516757106de3…` ; le registre dit aujourd'hui `d62067879de8…`. **Ils ne coïncident pas : le tag ne pointe plus vers ce que ton `Dockerfile` a figé.** Et la troisième ligne de la sortie l'éclaire : demander à Google le *digest* figé (`…nonroot@sha256:516757106de3…`) répond avec ce même *digest* ; il ne s'est ni déplacé ni volatilisé. Ce qui a changé, c'est la destination du tag. Le `grep -oE` avec ce motif n'imprime que ce qui correspond (`-o`) à une expression régulière étendue (`-E`) qui demande la chaîne `static-debian13:nonroot@sha256:` plus douze caractères hexadécimaux. Le `cut -c2-20` retire le guillemet initial de la sortie JSON et garde les 19 premiers caractères, c'est-à-dire `sha256:` plus douze. Que le tag ait changé de destination ne dit pas que le nouveau est meilleur ni que l'ancien est dangereux : cela dit qu'**il y a quelque chose à examiner**. C'est la matière de l'Exercice 4. (Cette mesure date du 21 octobre ; si tu la répètes un autre jour, elle peut donner un autre résultat, et c'est normal : c'est la raison pour laquelle on mesure.)

### Solution 3

Également dans `fig10_07.sh`. Le fichier, avec sa raison et sa date, et les trois exécutions :

```text
== Ejercicio 3. Aceptar el hallazgo por escrito, con razón y fecha
$ cat .trivyignore
# ca-certificates 20250419 en la base distroless fijada por digest.
# Debian ya lo corrigió (20250419+deb13u1); el arreglo llega al renovar el
# digest de la base (Ejercicio 4). Mientras tanto se acepta, por escrito.
# Revisado el 21-oct-2026. Borrar esta línea al renovar la base.
DSA-6572-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(el mismo archivo, con un identificador que NO es el del hallazgo)
$ sed -i.orig 's/^DSA-6572-1$/DSA-0000-1/' .trivyignore && tail -1 .trivyignore
DSA-0000-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1

== Ejercicio 3 (continuación). La fecha que Trivy SÍ hace cumplir: exp:
$ sed -i.orig 's/^DSA-0000-1$/DSA-6572-1 exp:2026-11-21/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-11-21
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(la misma línea, con una fecha que ya pasó)
$ sed -i.orig 's/exp:2026-11-21/exp:2026-01-01/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-01-01
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
```

Lis-le en trois temps. **Sans** fichier : le tableau compte 1 constat, il y a `Total: 1` et le code est **1**. **Avec** `--ignorefile /trabajo/.trivyignore` : le tableau compte **0** pour la base, il n'y a plus de ligne `Total`, et le code est **0**. Et à la troisième exécution, le script a remplacé l'identifiant du fichier par un identifiant inventé (`DSA-0000-1`) : le vrai constat revient, `Total: 1`, code **1**. C'est pourquoi la solution complète comporte la troisième exécution : elle démontre que le fichier n'est pas un interrupteur général mais une liste d'identifiants précis. Dans le format du fichier, les lignes qui commencent par `#` sont des commentaires et chaque identifiant figure seul sur sa ligne ([Trivy, « Filtering »](https://trivy.dev/latest/docs/configuration/filtering/)). Un commentaire avec une date n'oblige personne à réexaminer le constat ; ce qui fait respecter une date, c'est le champ `exp:` que cette même documentation montre dans ses exemples (`CVE-2019-14697 exp:2023-01-01`). La seconde partie de la solution, « continuación », le mesure avec l'identifiant de cet exercice : avec `DSA-6572-1 exp:2026-11-21` (une date future), Trivy sort avec le code **0** ; avec `exp:2026-01-01` (une date déjà passée), le constat **revient** et le code est **1**. Autrement dit, l'acceptation expire d'elle-même. Les identifiants `DSA-…` n'apparaissent pas dans les exemples de la documentation ; la mesure montre qu'ils fonctionnent comme les `CVE-…`. La pratique recommandable est de combiner les deux : le commentaire avec la raison et `exp:` avec la date de révision. L'option `--ignorefile` pointe vers le chemin du fichier *à l'intérieur du conteneur* (`/trabajo/.trivyignore`, parce que `/trabajo` est ton dossier monté), pas vers celui de ta machine ; la référence de la commande indique que, par défaut, l'option vaut `.trivyignore`, c'est-à-dire un fichier de ce nom dans le dossier courant. Et le commentaire : ce n'est pas de la décoration. C'est ce qui permet que, dans deux mois, quelqu'un, toi compris, sache **pourquoi** cette ligne est là et quand il faut décider de nouveau.

### Solution 4

La seconde partie de `fig10_08.sh`. Elle détermine le *digest* en vigueur du tag, l'écrit dans le `Dockerfile` avec `sed`, reconstruit, vérifie la version, enregistre et analyse :

```text
== Ejercicio 4. Renovar el digest de la base y volver a escanear
$ diff Dockerfile.viejo Dockerfile | cut -c1-120 | sed -E 's/sha256:([0-9a-f]{12})[0-9a-f]+/sha256:\1…/'; true
32c32
< FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de3…
---
> FROM gcr.io/distroless/static-debian13:nonroot@sha256:d62067879de8…
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker run --rm curso-docker-revisor:fig10 version
1.6.0
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
```

Le `diff` montre que **seule la ligne 32 change**, celle du `FROM` final, et seulement le *digest*. La construction réussit (et avec elle les tests Go de l'étape `pruebas`), `version` affiche toujours `1.6.0`, et l'analyse avec **toutes les gravités** donne maintenant **0 constat dans la base et le code 0**. Autrement dit : ce que le scanner voyait dans `ca-certificates` a disparu au renouvellement de la base, sans rien éteindre ni taire aucun avis. Deux nuances pour ton journal de bord. Une : **ce qui est mesuré, c'est le résultat, pas la cause** : on n'a pas ouvert la liste des paquets de la nouvelle base pour vérifier quelle version de `ca-certificates` elle apporte ; l'analyse dit qu'il n'y a plus de constat, et c'est avec cela qu'on décide. Deux : on a analysé une plateforme, celle de cette machine. Pour une vraie livraison, tu répéterais l'analyse avec l'autre (le bloc 11 de 10.9.2 la laisse enregistrée). Et la livraison serait publiée avec **un nouveau tag** (`1.6.1`), selon la règle de 10.3, et non par-dessus la `1.6.0`.

## Comment je sais que j'ai réussi

Vérifie chaque point avec une commande, pas de mémoire :

1. **Le registre n'écoute que sur `127.0.0.1`.** `docker port curso-docker-registro` répond `5000/tcp -> 127.0.0.1:5000` et rien avec `0.0.0.0`.
2. **L'image publiée est un index de deux plateformes.** `docker buildx imagetools inspect localhost:5000/curso-docker-revisor:1.6.0` montre `application/vnd.oci.image.index.v1+json` et des entrées `linux/amd64` et `linux/arm64`, plus deux de type `attestation-manifest`.
3. **Tu sais lire sa nomenclature logicielle et sa provenance, et ton Docker utilise le magasin de *containerd*.** `docker info -f '{{ .DriverStatus }}'` inclut `io.containerd.snapshotter.v1`. Avec les modèles de 10.6 et 10.7, tu obtiens les neuf paquets de la liste et la ligne `construida EN`.
4. **Tu peux démontrer qu'un tag bouge et qu'un *digest* ne bouge pas.** Tu répètes la mesure de 10.3 et tu vois deux *digests* différents sous le même tag.
5. **Elle tourne par *digest*, sur les deux plateformes.** Sur ta machine `amd64`, `docker run --rm --platform linux/amd64 <référence> version` répond `1.6.0`.
6. **Elle tourne durcie :** `docker run … --read-only --cap-drop ALL --security-opt no-new-privileges --init -v <volume>:/datos localhost:5000/curso-docker-revisor@sha256:…` répond `{"estado":"vivo","version":"1.6.0"}` sur `/salud`, et `docker inspect --format '{{.Config.Image}}' <conteneur>` montre une référence avec `@sha256:`.
7. **L'analyse a un seuil écrit, un code de sortie et une date.** Tu exécutes Trivy avec `--input`, sans le *socket* de Docker, et tu conserves à côté du résultat la sortie de `trivy version` avec la date de la base.
8. **Le pod démarre sans rien télécharger.** `kubectl get events` montre `already present on machine` et `kubectl get pod revisor` indique `Running` avec `0` redémarrage.
9. **Tu as laissé ta machine propre.** En suivant le nettoyage de la section « Clôture du cours », `docker ps -a`, `docker volume ls` et `kind get clusters` ne montrent plus le registre, les conteneurs d'appoint, le cache de Trivy ni le cluster de cette leçon ; il ne reste que ton image `curso-docker-revisor:1.6.0`, celle qu'utilisera le cours suivant.

## Résumé

- Un **tag** est une étiquette qui peut être déplacée ; un ***digest*** est une empreinte du contenu qui ne bouge pas. On publie avec un nouveau tag par livraison et on vérifie par *digest*.
- Un tag pointe vers un **index** ; l'index pointe vers un manifeste par plateforme et vers un manifeste d'attestation par plateforme.
- Pour livrer à deux processeurs sans émulation, on **compile en croisé** : `--platform=$BUILDPLATFORM` dans les étapes de compilation et `GOOS=$TARGETOS GOARCH=$TARGETARCH` dans `go build`. Sur cette machine, l'émulation a échoué.
- `--sbom=true` ajoute la nomenclature logicielle (SPDX, écrite par Syft) ; `--provenance=mode=max` ajoute la provenance complète, qui **expose les valeurs des arguments de construction** ; `mode=min` non.
- Reconstruire « à l'identique » ne garantit pas le même *digest* : avec cache, celui de l'index a changé ; sans cache, celui de chaque plateforme.
- Seule la plateforme qui correspond est téléchargée ; `docker save --platform` échoue si cette plateforme n'a pas été téléchargée.
- Trivy s'exécute **sans le *socket*** : `docker save` et `--input`, avec le dossier en `:ro`. Le seuil, c'est toi qui le fixes, `UNKNOWN` compte si tu ne déclares pas `--severity`, et sans `--exit-code`, Trivy sort avec 0 même s'il trouve des choses.
- Un constat qui a un correctif se résout en renouvelant la base ou, en attendant, s'accepte **par écrit** dans un `.trivyignore` avec la raison et la date. Figer par *digest* a le coût de renouveler exprès.
- `kind load docker-image` amène l'image jusqu'aux nœuds ; avec `imagePullPolicy: Never`, le pod ne démarre que si elle est arrivée, et l'événement `already present on machine` le prouve. Avec une image téléchargée depuis un registre, on la charge par un **tag local** : avec une référence par *digest*, `kind` ne donne pas d'erreur et ne laisse pas sur le nœud une image que le pod puisse trouver par cette référence.
- Le binaire de l'autre plateforme se vérifie en l'exécutant : `docker run --rm --platform linux/amd64 <référence> version` (ici, il a tourné émulé ; sur ton `amd64`, en natif).

## Clôture du cours : comment tu sais que tu as terminé

Le README du cours promet qu'il ne se termine pas quand on lit la leçon 10, mais quand ton projet remplit six conditions. Avec cette leçon, les six ont une façon d'être vérifiées, et chacune a été mesurée dans la leçon qui l'installe :

1. **`docker compose up` démarre tout à partir de zéro** et le rapport montre le service de test en panne comme `FALLA` (Leçon 9).
2. **L'image finale pèse des dizaines de mégaoctets** — 16.2 MB dans les exécutions des leçons 8 à 10 —, sans shell ni compilateur, et ne tourne pas en `root` (Leçons 5 et 8).
3. **Aucun secret n'apparaît** dans `docker history`, dans `docker inspect` ni dans l'environnement (Leçon 6).
4. **`docker stop` se termine en quelques secondes** (dans les leçons 3, 5, 7 et 9, on a mesuré entre 137 et 321 millisecondes avec la forme *exec*) et `docker ps` distingue `(healthy)` de `(unhealthy)` (Leçon 7).
5. **Le rapport survit à `docker rm`** et le `revisor` retrouve l'autre conteneur par son nom (Leçon 8).
6. **L'image publiée est référencée par *digest*, passe l'analyse avec le seuil que tu as fixé** et se charge dans un cluster `kind` **sans une seule erreur de téléchargement** (cette leçon).

Il y a une phrase qu'il faut dire avec précision, parce qu'il est facile de l'exagérer : ton image sort de ce cours **avec son analyse vérifiée**, ni « sûre » ni « approuvée ». Elle a un seuil écrit, une date de base de données et un constat connu, avec sa raison et le chemin pour le résoudre. C'est cela, travailler avec rigueur : non pas qu'il n'y ait pas de constats, mais que tu saches lesquels il y a, de quand ils datent et ce que tu vas en faire. Le [cours de Kubernetes avec kind](https://www.habil.mx/fr/cours/kubernetes/) reprend à partir d'ici : l'image `curso-docker-revisor:1.6.0`, avec le pont de `kind load docker-image` que tu as déjà parcouru.

Avant de fermer le journal de bord, arrête et supprime ce que tu as démarré dans cette leçon et qui t'appartient, avec les noms que tu as donnés, un par un (sans `docker system prune` ni `docker volume prune`, qui emporteraient ce qui appartient à d'autres). Regarde d'abord ce qu'il y a avec `docker ps -a`, `docker images` et `docker volume ls`, et ne supprime que ce que tu reconnais :

```bash
docker rm -f -v curso-docker-registro curso-docker-revisor   # el registro (con su volumen anónimo) y el contenedor de 10.9
docker images --digests --format '{{.Repository}}@{{.Digest}}' | grep '^localhost:5000/curso-docker-revisor@' | xargs -r docker rmi   # lo traído por digest
docker volume rm curso-docker-trivy-cache   # la caché de Trivy de 10.10
kind delete cluster --name curso-docker-puente
```

(Le volume `curso-docker-reportes` n'est **pas** supprimé ici : c'est celui de la Leçon 8, il conserve les rapports que tu as déjà générés et se nettoie, si tu veux, à la clôture de cette leçon-là. Ton image locale `curso-docker-revisor:1.6.0`, celle que tu construis en 10.11.3, reste : le cours suivant l'utilise. Le `rmi` ci-dessus supprime par nom les copies téléchargées par *digest*, jamais par identifiant.)

## Sources

Toutes ont été consultées le 21 octobre 2026.

- Docker, « Build attestations » (SBOM et provenance) : <https://docs.docker.com/build/metadata/attestations/>
- Docker, « SLSA provenance » (modes `min` et `max`) : <https://docs.docker.com/build/metadata/attestations/slsa-provenance/>
- Docker, « Multi-platform builds » : <https://docs.docker.com/build/building/multi-platform/>
- Docker, `docker buildx imagetools inspect` : <https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/>
- Docker, `docker image save` : <https://docs.docker.com/reference/cli/docker/image/save/>
- Docker, référence de `dockerd` (registres locaux marqués comme non sécurisés) : <https://docs.docker.com/reference/cli/dockerd/>
- Docker, « containerd image store » : <https://docs.docker.com/engine/storage/containerd/>
- Docker, « Building best practices » (base figée par *digest*) : <https://docs.docker.com/build/building/best-practices/>
- Docker, notes de version de Docker Engine 29 (29.2.1 du 2 février 2026, avec BuildKit v0.27.1) : <https://docs.docker.com/engine/release-notes/29/>
- Distribution (registre), « Deploy a registry server » : <https://distribution.github.io/distribution/about/deploying/>
- Distribution, notes de la version 3.1.2 : <https://github.com/distribution/distribution/releases/tag/v3.1.2>
- Open Container Initiative, « Distribution Specification » : <https://github.com/opencontainers/distribution-spec/blob/main/spec.md>
- Open Container Initiative, « Image Index » : <https://github.com/opencontainers/image-spec/blob/main/image-index.md>
- Trivy, « Container Image » (`--input`, ordre des sources) : <https://trivy.dev/latest/docs/target/container_image/>
- Trivy, « Filtering » (`--severity`, `--ignore-unfixed`, `.trivyignore`) : <https://trivy.dev/latest/docs/configuration/filtering/>
- Trivy, « Vulnerability » (quand `UNKNOWN` est utilisée) : <https://trivy.dev/latest/docs/scanner/vulnerability/>
- Trivy, « Reporting » (tableau et niveaux) : <https://trivy.dev/latest/docs/configuration/reporting/>
- Trivy, référence de `trivy image` (`--exit-code`, `--input`, `--ignorefile`) : <https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/>
- Trivy, notes de la version 0.76.0 (14 octobre 2026) : <https://github.com/aquasecurity/trivy/releases/tag/v0.76.0>
- kind, « Quick Start » (`kind load docker-image`) : <https://kind.sigs.k8s.io/docs/user/quick-start/>
- kind, notes de la version 0.33.0 (nœud `kindest/node:v1.37.0`) : <https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0>
- Kubernetes, « Install and Set Up kubectl on Linux » : <https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/>
- Kubernetes, « Images » (`imagePullPolicy`, *digests*, `:latest`) : <https://kubernetes.io/docs/concepts/containers/images/>
- SPDX, « Overview » : <https://spdx.dev/about/overview/>
- SLSA, « Provenance » (v1.0) : <https://slsa.dev/spec/v1.0/provenance>
- Codecov, « Bash Uploader Security Update » (le cas de la somme de contrôle) : <https://about.codecov.io/security-update/>

### Termes de cette leçon

- **Registre** (*registry*) : service qui stocke des images et les remet par une API HTTP standard.
- **Dépôt** (*repository*) : le nom d'une image dans un registre ; il conserve toutes ses versions.
- **Référence** : le texte qui désigne une image : registre, dépôt et tag ou *digest*.
- **Tag** : nom lisible et déplaçable d'une version d'une image.
- ***Digest*** : empreinte `sha256:` du contenu d'un manifeste ou d'un blob ; elle ne change pas.
- **Manifeste** : document JSON qui liste les couches et la configuration d'une image.
- **Index** (*image index*) : manifeste qui pointe vers plusieurs manifestes, un par plateforme, et vers les attestations.
- **Plateforme** : système d'exploitation plus architecture de processeur, comme `linux/arm64`.
- **Émulation (QEMU)** : simuler un autre processeur par logiciel ; lente et, sur cette machine, instable.
- **Compilation croisée** (*cross-compilation*) : compiler sur un processeur un binaire pour un autre, sans rien exécuter d'étranger.
- **Attestation** : document sur une image qui voyage dans son index ; ici, la SBOM et la provenance.
- **SBOM** : nomenclature logicielle ; ce que contient l'image.
- **SPDX** : standard ouvert pour les nomenclatures logicielles.
- **Provenance** (*provenance*) : comment, où et avec quoi l'image a été construite.
- **SLSA** : cadre et format pour décrire la provenance.
- **Vulnérabilité** : faille de sécurité publique, avec un identifiant (CVE, DSA…) et une gravité.
- **Seuil** : gravité minimale qui compte comme constat dans ton analyse.
- **Code de sortie** : nombre qu'un programme renvoie en se terminant ; 0 signifie le succès.
- **`.trivyignore`** : fichier contenant les identifiants des constats que tu acceptes.
- **`kind load docker-image`** : copie une image du Docker local vers les nœuds d'un cluster `kind`.
- **`imagePullPolicy: Never`** : politique de Kubernetes qui interdit de télécharger l'image.
