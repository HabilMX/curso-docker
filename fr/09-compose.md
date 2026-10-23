# Leçon 9 — Compose : le système complet

Il est 17 h 40, un jeudi. Demain à 9 h 00, une nouvelle stagiaire rejoint l'équipe, et sa première tâche est de démarrer le `revisor` sur son ordinateur pour voir comment il fonctionne. Tu lui as envoyé par chat ce que tu utilises toi-même : six commandes de la Leçon 8, copiées depuis ton historique. Deux réseaux, un volume, deux `docker run` de trois et cinq lignes, un `docker network connect`. À 17 h 52, elle te répond avec une capture d'écran : le `revisor` affiche `FALLA` pour le service de test, avec un `no such host`. Tu vérifies les commandes qu'elle a copiées et tu trouves le problème : elle a sauté le `docker network connect`, le dernier, parce qu'elle l'a cru facultatif. Tu lui expliques. À 18 h 05, elle envoie une autre capture : cette fois, c'est `OK`, mais le conteneur du `revisor` n'a ni `--read-only` ni `--cap-drop ALL`, parce qu'elle a copié le `docker run` de la Leçon 3, qui se trouvait plus haut dans la même conversation. Et demain, ton chef veut que le rapport montre trois services à la fois, un sain, un lent et un en panne, pour le présenter en réunion. Cela fait quatre conteneurs, avec leur ordre de démarrage, et quelqu'un devra se souvenir de tout. Il est 18 h 10. La question n'est plus de savoir comment on exécute un conteneur, mais **comment on écrit un système entier de façon que personne n'ait à se souvenir de quoi que ce soit**. Cette leçon existe pour que, demain, tu envoies un seul fichier et une seule commande, et que ce qui démarre soit exactement ce que tu as testé : durci, avec son token hors du fichier et avec le rapport à sa place.

**Durée :** 2 × 45 min

**Ce que tu construis :** un `compose.yaml` dans ton dossier `revisor/` qui décrit le système complet : le `revisor`, construit à partir de son Dockerfile, et trois copies du service de test (saine, lente et en panne) pour que le rapport affiche `OK`, `LENTO` et `FALLA` sans rien toucher manuellement. Les deux réseaux de la Leçon 8 (un normal et un interne sans sortie), le volume du rapport, le token sous forme de secret Compose et toutes les options de sécurité des Leçons 2 à 8, écrites une seule fois. Avec `docker compose up -d --build`, le système démarre à partir de zéro ; avec `docker compose down`, il s'arrête sans perdre le rapport.

**Ce que tu apprends :** ce qu'est Compose et ce qu'est un projet ; comment chaque option de `docker run` se traduit en une clé du fichier ; `docker compose config` pour valider et pour voir ce que Compose a compris ; `up`, `ps`, `logs`, `stop` et `down`, et pourquoi demander `up` deux fois ne fait rien la seconde fois ; comment Compose nomme ses conteneurs, ses réseaux et ses volumes ; `depends_on` avec `service_healthy` et pourquoi « démarré » ne veut pas dire « prêt » ; les secrets Compose et le piège de leurs permissions ; les ancres YAML et les champs `x-` pour ne pas se répéter ; `pull_policy: never` ; l'erreur de trois services qui construisent la même image et celle de `--wait` avec un service qui échoue volontairement ; et ce qu'est `docker init` et pourquoi nous ne l'utilisons pas.

**D'où tu viens.** De la [Leçon 8](08-volumenes-y-redes.md), tu apportes l'état final que cette leçon transpose dans un fichier : l'image `curso-docker-revisor:1.5.0`, qui enregistre son rapport dans `/datos` par défaut et dont ce dossier appartient à `65532` ; le volume du rapport ; le réseau normal par lequel le port est publié et le réseau interne sans sortie où vit le service de test. De la [Leçon 7](07-salud-y-ciclo-de-vida.md), tu apportes les options de durcissement (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`, limites), la politique de redémarrage `unless-stopped` et une promesse : utiliser la santé pour ordonner le démarrage de plusieurs services. De la [Leçon 6](06-configuracion-y-secretos.md), tu apportes le token dans `secretos/revisor_token.txt`, avec les permissions `644` (une permission qui ne vaut que pour un token factice : en 9.8.3, tu mesures qui peut le lire et en 9.8.4, tu le verrouilles), et une autre promesse : les secrets Compose. Et de la [Leçon 2](02-contenedores-dia-a-dia.md), l'image `curso-docker-prueba:1.0.0` et l'habitude de publier les ports uniquement sur `127.0.0.1`. Ton dossier contient `revisor/` (avec son `Dockerfile`, son `.dockerignore` et `secretos/`) et, à côté, `servicio-prueba/`.

**Ce que cette leçon ne fait pas.** Elle ne modifie pas le Dockerfile : l'image est la même 1.5.0 que dans la Leçon 8, simplement construite maintenant par Compose. Elle n'enseigne ni Docker Swarm ni les champs de `deploy` qui n'ont de sens que dans un cluster : ce cours travaille sur une seule machine, et le passage à plusieurs machines est l'objet du cours sur Kubernetes. Elle n'utilise ni profils, ni fichiers de surcharge (`compose.override.yaml`), ni `include` : ils sont utiles quand un projet grandit, et avec un seul fichier on apprend d'abord ce que tous combinent. Elle n'utilise pas `docker compose watch` ni les montages de code pour le développement, parce qu'ici le `revisor` est livré, pas programmé. Et elle ne publie l'image dans aucun registre : c'est l'objet de la [Leçon 10](10-entregar-la-imagen.md).

**À propos des exécutions.** Toutes les sorties sont réelles et ont été obtenues le 21 octobre 2026 sur un Mac avec [Colima](https://github.com/abiosoft/colima), qui démarre une machine virtuelle avec Ubuntu 24.04.4, la même base que Linux Mint 22, le système de référence du cours, avec un noyau 6.8 et un processeur `arm64`. Les scripts ont été exécutés **à l'intérieur** de cette machine virtuelle, avec Docker 29.2.1 (client et daemon), **Docker Compose v5.0.2** et Buildx v0.31.1, et avec leur dossier de travail sur le disque propre de Linux ; cela compte dans la section 9.10, qui traite des permissions d'un fichier, car les dossiers partagés entre le Mac et la machine virtuelle mentent sur ces permissions. Sur ton Mint, ce problème n'existe pas. Le cours a été planifié avec Docker Engine 29.8.2 et Compose v5.6.0 (mesurées le 7 octobre), et la version la plus récente d'Engine publiée le jour des exécutions était la 29.9.2, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)) ; nous ne nous attendons pas à ce que quoi que ce soit change dans cette leçon entre ces versions, mais les sorties ont été mesurées avec Compose v5.0.2 : si ta version donne un autre texte pour une erreur, compare-le par son sens. Vérifie les tiennes avec `docker version` et `docker compose version`. **Les noms.** Pour ne pas toucher à ce qui est à toi, les scripts utilisent un projet Compose à eux, `curso-docker-fig09`, et leurs propres images, `curso-docker-revisor:fig09` et `curso-docker-prueba:fig09` ; ainsi, ils ne touchent jamais ton projet `curso-docker`, ton `curso-docker-revisor:1.5.0` ni ton `curso-docker-prueba:1.0.0`, et en sortant ils ne suppriment que ce qu'ils ont créé. C'est pourquoi, dans les sorties, les conteneurs s'appellent `curso-docker-fig09-revisor-1` et non `curso-docker-revisor-1`, qui est le nom qu'ils auront dans ton dossier (la section 9.4 explique d'où vient chaque partie du nom). De plus, comme d'autres leçons tournaient sur la même machine, les scripts ont été lancés avec un autre préfixe et un autre port (les variables `PREFIJO` et `PUERTO` qu'ils comportent) ; une fonction `nombres`, visible dans chaque script, réécrit ce préfixe en `curso-docker-` et le port en `8080`, et avec les valeurs par défaut, elle ne change rien. Ce qui change **effectivement** d'une exécution à l'autre, et c'est signalé là où cela apparaît : les durées du tableau du `revisor` (masquées par `<t>`, ce qui explique que la colonne se décale parfois d'un espace vers la gauche ou vers la droite), les secondes de `Up N`, le numéro du fichier temporaire du rapport (`<n>`), les dates, l'ordre de certains événements qui se produisent en même temps, le service que nomme une erreur de validation et, en 9.11, à quelles tentatives et sur lequel des trois services se produit la collision. Les programmes se trouvent dans [`programas/09-compose/`](../programas/09-compose), chacun avec sa sortie à côté, et `estado/` conserve les fichiers du projet tels qu'ils sont à la fin.

## À la fin, tu seras capable de

- Traduire les commandes `docker run`, `docker network create` et `docker volume create` de la Leçon 8 en un `compose.yaml` sans `version:`, et expliquer quelle clé correspond à chaque option.
- Valider le fichier avec `docker compose config --quiet` et lire dans `docker compose config` la forme longue de ce que tu as écrit sous forme courte.
- Démarrer, observer et arrêter le système avec `up -d --build`, `ps`, `logs`, `stop` et `down`, et prédire quels conteneurs Compose recrée quand tu modifies le fichier.
- Provoquer et expliquer l'erreur `500` de `read-only file system` quand le `revisor` durci n'a rien de monté dans `/datos`.
- Ordonner le démarrage avec `depends_on` et `condition: service_healthy`, et expliquer pourquoi le `revisor` n'attend que la copie saine.
- Fournir le token sous forme de secret Compose, vérifier qu'il n'apparaît ni dans `docker inspect` ni dans `docker compose config`, et diagnostiquer le `permission denied` d'un fichier en `600`.
- Mesurer qui peut lire le fichier du token avec `644`, `600` et `640` (avec `ls -l`, `stat` et un compte sans privilèges), et le laisser avec la permission minimale qui permet encore au `revisor` de travailler.
- Reconnaître la collision de trois services qui construisent le même tag et l'échec de `up --wait` avec un service volontairement en panne, et choisir la bonne alternative.

## Le pourquoi avant le comment

Ce que tu as fait dans la Leçon 8 fonctionne, et c'est exactement ainsi qu'il faut apprendre : chaque pièce avec sa commande, pour voir ce qu'elle apporte. Mais cela pose trois problèmes qui apparaissent le jour où quelqu'un d'autre l'utilise, ou le jour où tu l'utilises toi-même trois semaines plus tard.

Le premier est que **le système vit dans ton historique**. Six commandes, dans un ordre qui compte, avec des options que personne n'écrit deux fois de la même façon. La scène du début n'est pas exagérée : il suffit de sauter un `docker network connect` pour que le `revisor` ne trouve pas le service de test, et il suffit de copier le mauvais `docker run` pour perdre le durcissement de la Leçon 7 sans que rien ne prévienne. Un service qui dépend de la capacité de quelqu'un à se rappeler six commandes dépend, en réalité, de la mémoire de cette personne.

Le deuxième est que **l'ordre se gère manuellement**. Les réseaux avant les conteneurs, le volume avant le `revisor`, le service de test avant celui qui le contrôle. Et à l'arrêt, l'inverse : d'abord les conteneurs, parce qu'un réseau ou un volume en cours d'utilisation ne se supprime pas. Dans la Leçon 8, c'est toi qui faisais cet ordre ; avec quatre conteneurs au lieu de deux, et dont l'un doit attendre qu'un autre soit **sain** et pas seulement en cours d'exécution, l'ordre ne tient plus dans la tête.

Le troisième est qu'**il n'y a aucun moyen de savoir ce qui tourne par rapport à ce qui devrait tourner**. Si demain tu changes le mode d'un service de test, quels conteneurs dois-tu supprimer et recréer ? Avec `docker run`, c'est toi qui donnes la réponse. L'idéal est qu'un outil compare ce que tu as demandé avec ce qui existe et ne touche que ce qui a changé.

Compose résout les trois problèmes avec une seule idée : **décrire le système dans un fichier, et laisser un outil le faire exister**. Sa documentation le définit comme « un outil pour définir et exécuter des applications multi-conteneurs » ([Docker, « Docker Compose »](https://docs.docker.com/compose/)). Le fichier, `compose.yaml`, dit quels services existent, sur quels réseaux ils vivent, quels volumes et quels secrets ils utilisent, et avec quelles options ils s'exécutent. La commande `docker compose up` lit le fichier, le compare avec ce qui existe déjà, puis crée, recrée ou laisse tranquille ce qu'il faut, dans le bon ordre. Le fichier se conserve à côté du code, se relit comme du code et s'envoie à la stagiaire à la place de six commandes.

Avec cette destination en tête, voici ce que tu auras à la fin, dans la section 9.9 : le système complet démarré avec une seule commande, et le rapport du `revisor` montrant les trois comportements du service de test sans que tu aies rien touché manuellement :

```text
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200
```

(C'est le bloc 3 de `fig09_05.sh` ; les espaces avant `<t>` changent avec la durée qui a été masquée.) Ce tableau est le premier des objectifs du cours : « `docker compose up` démarre tout à partir de zéro et le rapport montre le service de test en panne comme `FALLA` ».

## Les concepts

### 9.1 Ce qu'est Compose, et ce qu'est un projet

#### 9.1.1 Un *plugin*, un fichier, une spécification

Compose arrive avec l'installation de la Leçon 1 : le paquet `docker-compose-plugin` ajoute la sous-commande `docker compose` (avec une espace). Ce n'est pas un programme distinct que tu devrais installer avec `pip` ni un binaire à télécharger manuellement ; c'est une extension du client `docker`, et c'est pourquoi sa version se demande avec `docker compose version`.

Le fichier s'appelle `compose.yaml`. La documentation dit que le chemin par défaut est `compose.yaml` (« préféré ») ou `compose.yml` dans le dossier de travail, et que Compose accepte aussi `docker-compose.yaml` et `docker-compose.yml` « pour la rétrocompatibilité avec les versions antérieures » ([Docker, « How Compose works »](https://docs.docker.com/compose/intro/compose-application-model/)). Ce cours utilise le nom préféré.

Ce qui figure dans le fichier, Docker ne l'invente pas chaque année : c'est défini par la **spécification Compose**, un document public qui décrit chaque clé et ce qu'elle signifie ([spécification Compose](https://docs.docker.com/reference/compose-file/)). Les éléments de premier niveau que tu vas utiliser aujourd'hui sont au nombre de cinq : `name`, `services`, `networks`, `volumes` et `secrets`. Il en existe d'autres que cette leçon n'utilise pas : `configs` (des fichiers de configuration qui ne sont pas des secrets ; le `revisor` se configure par variables et n'en a pas besoin), `include` (pour réunir plusieurs fichiers) et `models` (qui, selon la spécification, « déclare les modèles d'IA que ton application Compose utilise », [spécification, `models`](https://docs.docker.com/reference/compose-file/models/)) ; et `version`, qui est désormais obsolète (9.2.3). La documentation les présente ainsi : les composants d'une application « sont définis comme des services », les services « communiquent entre eux par des réseaux » et « stockent et partagent des données persistantes dans des volumes » ([Docker, « How Compose works »](https://docs.docker.com/compose/intro/compose-application-model/)).

#### 9.1.2 Un service n'est pas un conteneur

Voici la première idée nouvelle, et il vaut mieux ne pas la survoler. Dans la Leçon 8, tu créais des **conteneurs** : `curso-docker-revisor`, `curso-docker-prueba`. Dans Compose, tu décris des **services** : `revisor`, `prueba`. Un service est la recette (« exécute cette image, avec ces options, sur ces réseaux ») ; le conteneur est ce qui sort de l'application de la recette. Normalement, un service donne un conteneur, mais la différence compte pour deux raisons que tu verras dans la leçon. Première raison : le nom qu'il convient d'utiliser pour le trouver par DNS est celui du **service** (`prueba`), pas celui du conteneur. Le nom du conteneur se résout aussi à l'intérieur du réseau (c'est vérifié), mais il porte le nom du projet et un numéro de réplique, qui changent d'un dossier à l'autre. Deuxième raison : quand tu modifies la recette, Compose jette l'ancien conteneur et en crée un nouveau ; le service, lui, reste le même.

#### 9.1.3 Le projet : le nom de famille de tout

Un **projet** est, selon la documentation, « un déploiement individuel d'une spécification d'application » ([Docker, « How Compose works »](https://docs.docker.com/compose/intro/compose-application-model/)). En pratique, c'est le nom que Compose place devant tout ce qu'il crée, pour savoir ce qui lui appartient. Le `compose.yaml` du cours commence par `name: curso-docker`, et c'est pourquoi tout ce qu'il crée porte ce nom : conteneurs, réseaux et volumes. Si tu ne l'écris pas, Compose utilise le nom du dossier où se trouve le fichier, qui serait chez toi `revisor` : un nom de famille trop générique pour que tu le reconnaisses parmi d'autres projets.

Le nom du projet peut être fixé de cinq façons, et la documentation dit laquelle l'emporte : d'abord l'option `-p` de la ligne de commande ; puis la variable d'environnement `COMPOSE_PROJECT_NAME` ; puis le `name:` du fichier ; puis le nom du dossier du fichier ; et enfin le nom du dossier courant. Il n'admet que des « lettres minuscules, des chiffres décimaux, des tirets et des tirets bas » ([Docker, « Specify a project name »](https://docs.docker.com/compose/how-tos/project-name/)). Cette même page dit à quoi cela sert : « Compose utilise un nom de projet pour isoler les environnements les uns des autres ». Les scripts de cette leçon en profitent : ils fixent `COMPOSE_PROJECT_NAME=curso-docker-fig09`, qui l'emporte sur le `name:` du fichier, et ainsi leur exécution ne se mélange jamais avec ton projet `curso-docker`, même si le fichier est le même.

### 9.2 Du `docker run` au fichier

#### 9.2.1 L'état final de la Leçon 8, écrit une fois

Le concret d'abord. Voici l'état final de la Leçon 8, celui de la section 8.10.3, dans un fichier. Enregistre-le dans ton dossier `revisor/` sous le nom `compose.yaml` :

```yaml
# fig09_01.compose.yaml — Lección 9, primer paso: el estado final de la
# Lección 8 (sección 8.10.3), escrito en un archivo en vez de en seis comandos.
# Un solo servicio de prueba, sin token. Va en tu carpeta revisor/ como compose.yaml.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: "prueba http://prueba:9000/ 2s"
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      - prueba
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

  prueba:
    build: ../servicio-prueba
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}
```

Lis-le de bas en haut, ce qui est la façon dont Compose le construit. Tout en bas se trouvent les **réseaux** et le **volume** : `publica`, `interna` (avec `internal: true`, le `--internal` de la Leçon 8) et `reportes`. Les accolades vides `{}` disent « avec les options par défaut » : un réseau `bridge` et un volume local. Au-dessus se trouvent les deux **services**. Chaque service liste ses réseaux par leur nom court (`publica`, `interna`) et monte le volume par son nom court (`reportes:/datos`) ; Compose leur ajoute le nom de famille du projet à la création. Le service de test n'est que sur le réseau `interna` ; le `revisor`, sur les deux. Exactement comme en 8.10.3, mais sans l'étape du `docker network connect` que la stagiaire a oubliée : ici, il n'y a pas d'étapes, il y a une description.

#### 9.2.2 Chaque option, sa clé

Presque chaque option de `docker run` a une clé au nom proche. Ce tableau est celui que tu utiliseras pour traduire n'importe quelle commande des leçons précédentes :

| `docker run` | `compose.yaml` | Remarque |
|---|---|---|
| `curso-docker-revisor:1.5.0` (l'image) | `image:` | avec `build:` à côté, c'est le nom que reçoit l'image construite |
| `docker build --build-arg VERSION=1.5.0 .` | `build: { context: ., args: { VERSION: "1.5.0" } }` | Compose construit avant de créer le conteneur |
| `-e REVISOR_SERVICIOS=…` | `environment:` | sous forme de map (`CLÉ: valeur`), sans guillemets qui atteignent la valeur |
| `-p 127.0.0.1:8080:8080` | `ports: ["127.0.0.1:8080:8080"]` | l'adresse `127.0.0.1` s'écrit comme dans la Leçon 2 |
| `-v curso-docker-reportes:/datos` | `volumes: [reportes:/datos]` + `volumes:` en haut | le volume se déclare une fois au niveau supérieur |
| `--network …` et `docker network connect …` | `networks: [publica, interna]` + `networks:` en haut | tous les réseaux du service dans une liste |
| `--read-only` | `read_only: true` | |
| `--cap-drop ALL` | `cap_drop: [ALL]` | |
| `--security-opt no-new-privileges` | `security_opt: ["no-new-privileges:true"]` | |
| `--init` | `init: true` | |
| `--memory 64m`, `--cpus 0.5`, `--pids-limit 50` | `mem_limit: 64m`, `cpus: 0.5`, `pids_limit: 50` | |
| `--restart unless-stopped` | `restart: unless-stopped` | apparaît dans le fichier final (9.9) |
| `--name curso-docker-revisor` | (rien) | le nom est attribué par Compose : projet, service et numéro |

La référence des services décrit chacune avec la même intention que celle que tu as rencontrée dans la Leçon 7 : `read_only` crée le conteneur « avec un système de fichiers en lecture seule » ; `init` exécute « un processus init (PID 1) dans le conteneur qui transmet les signaux et récupère les processus » ; `cpus` définit combien de CPU, « potentiellement virtuels », lui sont alloués ; et `pids_limit` ajuste la limite de processus ([référence des services Compose](https://docs.docker.com/reference/compose-file/services/)). Il n'y a pas de nouvelle magie : ce sont les mêmes options du daemon, écrites ailleurs.

Deux clés du tableau méritent une phrase de plus. La première, `security_opt` : la référence dit que les options booléennes comme `no-new-privileges` peuvent s'écrire de trois façons équivalentes (`no-new-privileges`, `no-new-privileges=true` et `no-new-privileges:true`). Le cours utilise la dernière parce que c'est celle qui laisse le moins de doute. La seconde, `depends_on: [prueba]` : elle n'a pas d'équivalent dans `docker run`, parce que l'ordre des conteneurs était ton travail. Elle dit à Compose que le `revisor` est créé et démarré après `prueba`. Plus loin (9.7), tu verras que « après » ne veut pas dire « quand il est déjà prêt ».

#### 9.2.3 Sans `version:`

Le fichier ne commence ni par `version: "3.8"` ni par rien de semblable, et ce n'est pas un oubli. La spécification dit que l'élément `version` n'existe que pour la compatibilité, qu'il « est purement informatif » et que, si tu l'utilises, tu recevras « un avertissement d'obsolescence » ([spécification, `version` et `name`](https://docs.docker.com/reference/compose-file/version-and-name/)). Tu le verras dans presque tous les tutoriels d'il y a quelques années, parce que l'ancien Compose l'exigeait pour savoir quelles clés accepter. Celui d'aujourd'hui applique la spécification en vigueur dans la version que tu as installée et n'a pas besoin de ce champ. Si tu le rencontres, supprime-le.

### 9.3 Valider et lire ce que Compose a compris

#### 9.3.1 `docker compose config`

Avant de démarrer quoi que ce soit, il vaut mieux savoir si le fichier est valide et si Compose a compris ce que tu voulais dire. C'est à cela que sert `docker compose config`, qui, selon sa référence, « affiche le modèle de données réel qui sera appliqué à Docker Engine » : il résout les variables et « développe la notation courte vers la forme canonique » ([référence de `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/)). Trois options le rendent utile au quotidien : `--quiet` se contente de valider et n'affiche rien (si le fichier est incorrect, l'erreur s'affiche et le code n'est pas 0) ; `--services` liste les services, un par ligne ; et `--volumes`, les volumes.

Le script `fig09_02.sh` prend ton premier `compose.yaml` et lui fait parcourir tout le cycle : valider, lire, démarrer, redemander et arrêter. C'est le premier script de la leçon, donc le voici en entier ; les suivants répètent le même début (les noms auxiliaires, le dossier de travail et les fonctions `muestra`, `eventos`, `esperar` et `tabla`) et, dans la leçon, on ne montre que la partie qui change :

```bash
#!/usr/bin/env bash
# fig09_02.sh — El primer compose.yaml (fig09_01): validarlo, leer lo que Compose
# entiende, levantarlo, pedir el reporte, volver a pedir «up» y apagarlo.
# Construye sus propias imágenes de apoyo; no usa ni toca las tuyas.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig09»: el proyecto de Compose se llama curso-docker-fig09
# y las imágenes curso-docker-revisor:fig09 y curso-docker-prueba:fig09. Así el
# guion nunca toca tu proyecto curso-docker, tu curso-docker-revisor:1.5.0 ni tu
# curso-docker-prueba:1.0.0, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig09.XXXXXX")"
export COMPOSE_PROJECT_NAME="${PREFIJO}fig09"   # gana sobre el «name:» del archivo
trap 'cd "$TRABAJO/revisor" 2>/dev/null && docker compose down --volumes --remove-orphans >/dev/null 2>&1
      docker rmi -f "${PREFIJO}revisor:fig09" "${PREFIJO}prueba:fig09" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso, el estado de la Lección 8 (con el
# token de la Lección 6) y el compose.yaml de fig09_01.compose.yaml, con los nombres de apoyo
# y el puerto del guion.
mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
cp -R "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$AQUI/estado/secretos" "$TRABAJO/revisor/"
chmod 644 "$TRABAJO/revisor/secretos/revisor_token.txt"   # 644: solo porque el token es de mentira (9.8.4)
sed -e "s/curso-docker-revisor:1.5.0/${PREFIJO}revisor:fig09/" \
    -e "s/curso-docker-prueba:1.0.0/${PREFIJO}prueba:fig09/" \
    -e "s/127.0.0.1:8080:8080/127.0.0.1:${PUERTO}:8080/" \
    "$AQUI/fig09_01.compose.yaml" > "$TRABAJO/revisor/compose.yaml"
cd "$TRABAJO/revisor"
TOKEN="$(cat secretos/revisor_token.txt)"   # se lee del archivo; nunca se escribe

# Si corres el guion con otro PREFIJO o PUERTO, la salida se escribe con los del
# curso. Con los valores por omisión esto no cambia nada.
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/127.0.0.1:${PUERTO}->/127.0.0.1:8080->/g" \
                -e "s/127.0.0.1:${PUERTO}\//127.0.0.1:8080\//g" -e "s/published: \"${PUERTO}\"/published: \"8080\"/"; }
# muestra COMANDO: lo imprime con «$ », lo corre y dice el código si no fue 0
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# eventos: de lo que imprime Compose, solo los renglones «Objeto nombre Estado»
eventos() { grep -E '^ *(Image|Network|Volume|Container) ' | sed -E 's/^ +//; s/ +$//'; }
# esperar SERVICIO ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar() {
  for _ in $(seq 60); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "${COMPOSE_PROJECT_NAME}-$1-1" 2>/dev/null)" = "$2" ] && return 0
    sleep 1
  done
  echo "($1 no llegó a $2)"; return 1
}
# tabla: el reporte en forma de tabla, con el token y con los tiempos tapados
tabla() { curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'; }

echo "== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config --volumes"

echo
echo "== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto"
muestra "docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'"
muestra "docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'"

echo
echo "== 3. Levantarlo todo"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s 'http://127.0.0.1:${PUERTO}/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'"

echo
echo "== 4. Pedir «up» otra vez, sin cambiar nada"
muestra "docker compose up -d 2>&1 | eventos"

echo
echo "== 5. Apagar: down borra contenedores y redes; el volumen se queda"
muestra "docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
```

Et sa sortie :

```text
$ ./fig09_02.sh
== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba
revisor
$ docker compose config --volumes
reportes

== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto
$ docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'
    depends_on:
      prueba:
        condition: service_started
        required: true
    environment:
      REVISOR_SERVICIOS: prueba http://prueba:9000/ 2s
--
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 8080
        published: "8080"
        protocol: tcp
--
    volumes:
      - type: volume
        source: reportes
        target: /datos
        volume: {}
networks:
$ docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'
  prueba:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  revisor:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  interna:
    internal: true
  publica:
  reportes:

== 3. Levantarlo todo
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-prueba:fig09 Built
Image curso-docker-revisor:fig09 Built
Network curso-docker-fig09_interna Created
Network curso-docker-fig09_publica Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-1 Started
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200

== 4. Pedir «up» otra vez, sin cambiar nada
$ docker compose up -d 2>&1 | eventos
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Running

== 5. Apagar: down borra contenedores y redes; el volumen se queda
$ docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'
Container curso-docker-fig09-revisor-1 Stopped
Container curso-docker-fig09-revisor-1 Removed
Container curso-docker-fig09-prueba-1 Stopped
Container curso-docker-fig09-prueba-1 Removed
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
```

#### 9.3.2 Lire les blocs 1 et 2

1. **Valide, avec deux services et un volume.** `config --quiet` n'affiche rien si le fichier est correct ; le `echo` du script le dit à sa place. Remarque que `prueba` sort avant `revisor`, alors que dans le fichier tu l'as écrit après. Compose ne liste pas dans l'ordre où tu as écrit : les dépendances sortent d'abord et, à la fin, celui qui en dépend, et c'est `depends_on` qui décide cela. (Tu le verras plus clairement en 9.9, avec quatre services : les trois copies du service de test d'abord, entre elles dans l'ordre alphabétique, et le `revisor` à la fin. Ce qui varie en revanche d'une exécution à l'autre, c'est l'ordre des événements de `up`, parce que plusieurs choses se produisent en même temps.)
2. **La forme longue.** Voici ce qui intéresse vraiment quiconque relit le fichier d'un autre. Ton `depends_on: [prueba]` est devenu `condition: service_started` et `required: true` : la forme courte est la forme longue avec les valeurs par défaut. Ton `"127.0.0.1:8080:8080"` est devenu un bloc avec `host_ip: 127.0.0.1`, `target: 8080` (le port du conteneur) et `published: "8080"` (celui de ta machine) : si jamais tu doutes de quel numéro est lequel, `config` te le dit avec des noms. Ton `reportes:/datos` est devenu `type: volume`, `source: reportes`, `target: /datos`. Et dans la deuxième commande, `mem_limit: 64m` apparaît sous la forme `"67108864"`, soit 64 × 1024 × 1024 octets, le même nombre que `docker inspect` t'a montré dans la Leçon 2. `config` est le meilleur outil pour relire un `compose.yaml` que tu n'as pas écrit : il ne te dit pas ce que l'auteur a voulu, il te dit ce qui va se passer.

Une habitude qu'il convient d'adopter dès aujourd'hui : **chaque fois que tu modifies le fichier, exécute `docker compose config --quiet` avant `up`**. Une erreur d'indentation en YAML change le sens sans produire d'erreur de syntaxe (une clé qui se retrouve dans le mauvais service, par exemple), et `config` est l'endroit où tu le vois avant que le conteneur ne démarre avec une autre configuration.

### 9.4 Démarrer, observer et arrêter

#### 9.4.1 `up` : créer ce qui manque, dans l'ordre

`docker compose up` est la commande centrale. Sa référence la résume en une ligne : « construit, (re)crée, démarre et s'attache aux conteneurs d'un service » ([référence de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Avec `-d` (« mode détaché »), elle laisse les conteneurs en arrière-plan et te rend le terminal ; avec `--build`, elle construit les images avant de démarrer, même si elles existent déjà.

Le bloc 3 de `fig09_02.sh` montre ce qu'elle a fait, dans l'ordre où elle l'a fait. D'abord les **deux images**, `Built`. Ensuite les **réseaux**, `curso-docker-fig09_interna` et `curso-docker-fig09_publica`, et le **volume**, `curso-docker-fig09_reportes`. Ensuite les **conteneurs** : `Created` pour les deux, puis `Started` d'abord pour `prueba` et ensuite pour `revisor`, parce que le `revisor` dépend de lui. C'est l'ordre que, dans la Leçon 8, tu suivais manuellement, désormais décidé par le fichier. (Le script retire de l'affichage les lignes intermédiaires, comme `Building`, `Creating` ou `Starting`, pour que les résultats se lisent ; dans ton terminal, tu les verras toutes.)

#### 9.4.2 Comment les choses s'appellent

Regarde bien les noms, parce que tu vas les écrire dans `docker inspect`, dans `docker logs` et dans le conteneur auxiliaire `alpine` :

- **Conteneurs** : `<projet>-<service>-<numéro>`. Dans la sortie, `curso-docker-fig09-revisor-1` ; dans ton dossier, avec `name: curso-docker`, `curso-docker-revisor-1`. Le numéro existe parce qu'un service peut avoir plusieurs répliques ; ici, c'est toujours `1`.
- **Réseaux et volumes** : `<projet>_<nom>`, avec un tiret bas. `curso-docker-fig09_interna`, `curso-docker-fig09_reportes` ; dans ton dossier, `curso-docker_interna` et `curso-docker_reportes`.

Comme le projet commence par `curso-docker`, tout conserve le préfixe du cours, et l'habitude de la Leçon 2 (pouvoir supprimer ce qui appartient au cours sans toucher au reste) est maintenue. De plus, Compose place sur chaque chose qu'il crée le label `com.docker.compose.project=<projet>`. C'est la façon propre de demander « qu'est-ce qui appartient à ce projet », et le bloc 5 l'utilise : `docker volume ls --filter label=com.docker.compose.project=…`.

Et une question que tu te poses sûrement : si le conteneur s'appelle `curso-docker-fig09-prueba-1`, pourquoi le `revisor` le cherche-t-il sous le nom `http://prueba:9000/` ? Parce que, dans les réseaux d'un projet, chaque conteneur s'enregistre dans le DNS intégré (le `127.0.0.11` de la Leçon 8) sous le nom de son **service** et aussi sous son nom propre ; lors d'un test à part, les deux noms se sont résolus vers la même adresse. Celui du service est celui qu'il convient d'écrire, parce que c'est le seul qui ne dépende ni du projet ni du numéro de réplique. La documentation l'explique avec son exemple : le conteneur du service `web` rejoint le réseau « sous le nom `web` » ([Docker, « Networking in Compose »](https://docs.docker.com/compose/how-tos/networking/)). Cela te permet d'écrire `REVISOR_SERVICIOS` sans savoir comment le projet va s'appeler : le même fichier fonctionne dans ton dossier, dans celui de la stagiaire et dans le script.

La même page dit ce qui se passe si tu ne déclares pas de réseaux : Compose en crée **un**, `<projet>_default`, et y connecte tous les services. Ton fichier déclare les siens, et c'est pourquoi aucun `_default` n'apparaît dans la sortie. Ce n'est pas un détail : avec le réseau par défaut de Compose, le service de test aurait un accès à internet, et la Leçon 8 a décidé qu'il n'en a pas besoin.

#### 9.4.3 `ps` : ce qui existe, et dans quel état

`docker compose ps` est le `docker ps` du projet : il ne montre que ses conteneurs. Le bloc 3 l'utilise avec un format personnalisé (nom, état et ports) et masque les secondes de `Up` par `Up N`. Les deux sont `(healthy)`, parce que les deux images apportent leur `HEALTHCHECK` depuis les Leçons 2 et 7, et le port du `revisor` est sur `127.0.0.1:8080`. Le service de test ne publie rien : il n'en a pas besoin, le `revisor` lui parle par le réseau interne. Et le tableau du `revisor` dit `prueba OK`.

#### 9.4.4 Demander `up` à nouveau : il ne se passe rien, et c'est tant mieux

Le bloc 4 relance `docker compose up -d`, sans rien changer. Compose répond `Running` pour les deux et n'en touche aucun. C'est la différence la plus importante avec un script de `docker run` : un script répété essaie de recréer et se heurte au nom en double de la Leçon 2. Compose, lui, **compare** ce que tu demandes avec ce qui existe. La référence de `up` le dit ainsi : si la configuration ou l'image d'un service ont changé, Compose « prend en compte les changements en arrêtant et en recréant les conteneurs », et conserve les volumes montés ([référence de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Si rien n'a changé, rien n'est touché. C'est pourquoi `docker compose up -d` se répète sans danger : c'est la façon de dire « que ceci existe », et non « crée ceci ».

#### 9.4.5 `down` : le volume reste

Le bloc 5 arrête avec `docker compose down`. Il arrête et supprime les conteneurs (d'abord le `revisor`, qui dépend de `prueba` ; Compose arrête dans l'ordre inverse des dépendances) et supprime les réseaux. Et le volume **reste** : `docker volume ls` le montre toujours. La référence de `down` liste ce qu'il supprime par défaut : les conteneurs des services, les réseaux de la section `networks` et le réseau par défaut s'il a été utilisé ([référence de `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/)). Les volumes nommés ne figurent pas dans cette liste ; pour les supprimer, il faut le demander avec `--volumes`, qui supprime « les volumes nommés déclarés dans la section `volumes` ». C'est la bonne décision : arrêter le système ne devrait pas te coûter le rapport. En 9.12, tu le verras survivre.

### 9.5 L'erreur : le `revisor` durci sans rien dans `/datos`

#### 9.5.1 La provoquer

Depuis l'image 1.5.0 de la Leçon 8, le `revisor` enregistre son rapport dans `/datos/reporte.json` **par défaut** : l'image apporte `REVISOR_REPORTE=/datos/reporte.json` dans son `ENV`. Et le `compose.yaml` l'exécute avec `read_only: true`. Que se passe-t-il si quelqu'un, en mettant le fichier au propre, supprime la ligne du volume parce que « nous n'utilisons pas le rapport » ? Le script `fig09_03.sh` le fait sous tes yeux, avec `sed`, et montre la différence avec `diff` avant de démarrer. La partie du script qui change par rapport à `fig09_02.sh` :

```bash
cp compose.yaml compose.bueno.yaml

echo "== 1. Sin el volumen en /datos"
# Borra el renglón «volumes:» del revisor y el que le sigue («- reportes:/datos»).
sed -i '/^    volumes:$/{N;d;}' compose.yaml
muestra "diff compose.bueno.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'"

echo
echo "== 2. Con el volumen: Compose recrea SOLO el revisor"
cp compose.bueno.yaml compose.yaml
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'"
esperar revisor healthy
muestra "curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
```

```text
$ ./fig09_03.sh
== 1. Sin el volumen en /datos
$ diff compose.bueno.yaml compose.yaml
19,20d18
<     volumes:
<       - reportes:/datos
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]

== 2. Con el volumen: Compose recrea SOLO el revisor
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Recreate
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
```

#### 9.5.2 Le lire

1. **Le `diff`** montre les deux lignes manquantes (et se termine avec `1`, ce qui, pour `diff`, signifie « il y a des différences », pas « il a échoué »). Le fichier reste valide : un service sans volumes est parfaitement légal, et c'est pourquoi `config --quiet` ne te sauverait pas ici. Le conteneur démarre et arrive à `(healthy)`, parce que `/salud` n'écrit rien. Docker est content.
2. **Mais le rapport renvoie `500`** : `open /datos/.reporte-<n>.tmp: read-only file system`. C'est l'erreur de la section 7.7 de la Leçon 7, dans un autre dossier : le `revisor` essaie de créer son fichier temporaire dans `/datos`, et `/datos` fait partie du système de fichiers du conteneur, qui est en lecture seule. Rien n'est monté par-dessus qui accepte les écritures. Remarque que le `revisor` ne plante pas et ne fait pas semblant : il répond `500` avec la cause exacte. C'est le deuxième principe du cours à l'œuvre : le conteneur est `healthy` et le service ne fait pas ce qu'il doit.
3. **La correction**, remettre les deux lignes, et la deuxième leçon de Compose du jour. `up -d` crée le volume qui est maintenant utilisé (`Volume … Created`), laisse le service de test comme il était (`Running`) et **recrée uniquement le `revisor`** (`Recreate`, `Recreated`, `Started`), parce que sa configuration a changé. Le rapport redevient `200`.

La règle à retenir : **avec `read_only: true`, chaque dossier où le programme écrit a besoin de quelque chose de monté par-dessus**. Dans le `revisor`, il n'y en a qu'un, `/datos`, et le fichier du cours le monte toujours. Si un jour tu changes `REVISOR_REPORTE` vers un autre chemin, ce chemin a lui aussi besoin de son volume (ou de son `tmpfs`, s'il n'a pas besoin de durer).

### 9.6 Trois copies du service de test sans écrire trois fois la même chose

#### 9.6.1 Pourquoi trois

Avec un seul service de test, le rapport dit toujours `OK`, à moins que tu ne changes son mode manuellement avec `POST /modo/caido`. Mais le service de test vit sur un réseau interne et ne publie aucun port : pour changer son mode, il te faudrait entrer par un autre côté. Il existe une meilleure façon de montrer les trois comportements à la fois, et c'est celle que demandait le chef de la scène : **trois conteneurs de la même image, chacun démarré dans un mode différent** avec `PRUEBA_MODO`. Ainsi, le rapport affiche `OK`, `LENTO` et `FALLA` dès que le système démarre, sans rien toucher.

Trois services presque identiques, cela signifie le même bloc d'options de durcissement écrit trois fois, et un bloc répété est un bloc que quelqu'un finira par modifier dans deux des trois copies. Compose a deux outils pour cela, et on les utilise ensemble.

#### 9.6.2 Champs `x-` et ancres YAML

Le premier est une règle de Compose : les champs de premier niveau qui commencent par `x-` sont ignorés. La documentation le dit tel quel : « Compose ignore tout champ qui commence par `x-` », et c'est « la seule exception » où il ignore en silence un champ qu'il ne reconnaît pas ; ils servent à « modulariser des configurations que tu veux réutiliser » ([spécification, extensions](https://docs.docker.com/reference/compose-file/extension/)).

Le second n'est pas de Compose mais de YAML : les **ancres** et les **alias**. Une ancre se place avec `&nom` devant un bloc ; un alias, `*nom`, renvoie à ce bloc ; et la clé de fusion `<<: *nom` copie les clés du bloc dans un autre mapping, où tu peux ajouter ou remplacer celles que tu veux. La documentation de Compose signale deux détails : la fusion « ne s'applique qu'aux mappings, et ne peut pas être utilisée avec des séquences », et, quand on utilise des fragments, les variables d'environnement s'écrivent sous forme de map (`CLÉ: valeur`) et non de liste (`- CLÉ=valeur`) ([spécification, fragments](https://docs.docker.com/reference/compose-file/fragments/)). C'est pourquoi tout l'`environment` du cours est écrit sous forme de map.

Ensemble, cela donne ceci, dans un extrait du fichier final :

```yaml
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true

services:
  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento
```

`x-prueba` n'est pas un service (Compose l'ignore), mais son contenu existe pour YAML grâce à l'ancre `&prueba`. `prueba-lento` copie tout ce bloc avec `<<: *prueba` et y ajoute son `environment`. Le bloc 1 de `fig09_05.sh`, plus bas, te le démontre en demandant à `config` le service `prueba-lento` : apparaissent `image`, `pull_policy`, `read_only`, `mem_limit` et `networks`, qui ne sont pas écrits dans le service mais dans l'ancre.

#### 9.6.3 Qui construit, et `pull_policy: never`

Il reste une décision : qui construit l'image `curso-docker-prueba:1.0.0` ? Si l'ancre portait `build: ../servicio-prueba`, les trois copies en hériteraient, et Compose lancerait **trois constructions simultanées du même tag**. Cela provoque une collision, et en 9.11 tu vas la déclencher. Le fichier final fait autrement : seul `prueba-sano` porte `build`. Les deux autres utilisent l'image que construit le premier.

Et pour que ces deux-là n'aillent pas la chercher sur internet, l'ancre porte `pull_policy: never`. La référence le définit ainsi : avec `never`, Compose « ne télécharge pas l'image depuis un registre et s'appuie sur l'image stockée sur la plateforme » ([référence des services Compose](https://docs.docker.com/reference/compose-file/services/)). Que se passe-t-il sans cette ligne ? Tu le mesureras dans le bloc 2 de `fig09_07.sh` (section 9.11) : sur une machine où l'image n'existe pas encore, Compose va d'abord la chercher sur Docker Hub pour chaque service qui ne la construit pas, reçoit deux fois le `pull access denied` de la Leçon 2, puis, comme un autre service du projet la construit, continue, la construit et démarre tout. Ça marche, mais cela fait des requêtes à internet dont tu n'as pas besoin, remplit la sortie d'erreurs qui n'en sont pas, et laisse le résultat entre les mains de ce que quelqu'un aurait publié sous ce nom. Avec `pull_policy: never`, le nom de l'image cesse d'être une question posée à internet et devient une référence à quelque chose que tu as construit.

Une conséquence à connaître : comme seul `prueba-sano` construit, demander un service isolé sur une machine où l'image n'existe pas encore (par exemple, `docker compose up prueba-lento` juste après avoir cloné le projet) ne trouve personne pour la construire. Lors d'un test à part avec une image inexistante et `pull_policy: never`, Compose s'est terminé avec le code `1` et le message `No such image`. Démarre le projet complet avec `docker compose up -d --build`, ou construis d'abord avec `docker compose build prueba-sano`.

### 9.7 « Démarré » ne veut pas dire « prêt » : `depends_on` avec condition

#### 9.7.1 Ce que fait `depends_on` par défaut

Dans le premier fichier, tu as écrit `depends_on: [prueba]`, et `config` t'a montré que cela équivaut à `condition: service_started`. La documentation est très claire sur ce que cela signifie : « Au démarrage, Compose n'attend pas qu'un conteneur soit "prêt", seulement qu'il soit en cours d'exécution » ([Docker, « Control startup order »](https://docs.docker.com/compose/how-tos/startup-order/)). C'est la même confusion que dans la Leçon 7, transposée à l'ordre de démarrage : le processus existe, mais il ne répond peut-être pas encore.

#### 9.7.2 Les trois conditions

La forme longue de `depends_on` accepte trois conditions ([référence des services Compose](https://docs.docker.com/reference/compose-file/services/)) :

| Condition | Compose attend que la dépendance… |
|---|---|
| `service_started` | soit en cours d'exécution (c'est ce que fait la forme courte) |
| `service_healthy` | soit « saine », selon son `healthcheck` |
| `service_completed_successfully` | se termine avec succès (pour les tâches ponctuelles, comme préparer quelque chose au préalable) |

Celle de cette leçon est `service_healthy` : « Compose attend que les contrôles de santé des dépendances marquées `service_healthy` réussissent » ([Docker, « Control startup order »](https://docs.docker.com/compose/how-tos/startup-order/)). Pour cela, la dépendance a besoin d'un contrôle de santé (health check), et le service de test en apporte un dans son image depuis la Leçon 2 (toutes les 5 s, avec 2 nouvelles tentatives). C'est la promesse de la Leçon 7 : la santé ne redémarre rien, mais quelqu'un l'utilise. Aujourd'hui, c'est Compose qui l'utilise.

#### 9.7.3 Pourquoi le `revisor` n'attend que la copie saine

Voici la décision la plus fine du fichier, et elle mérite d'être lue lentement. Le `revisor` dépend des trois copies, mais **pas** avec la même condition :

```yaml
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
```

Imagine ce qui se passerait si les trois étaient `service_healthy`. `prueba-caido` répond toujours `503` : son contrôle de santé ne réussit **jamais**, donc Compose attendrait que Docker la déclare `unhealthy` (avec 2 nouvelles tentatives toutes les 5 s, environ dix secondes) puis abandonnerait : lors d'un test à part avec une dépendance qui échoue toujours (contrôle toutes les 2 s, 2 nouvelles tentatives), `docker compose up -d` s'est terminé au bout de 5 s avec le code `1` et le message `dependency failed to start: container ... is unhealthy`, et le service qui en dépendait est resté à `Created`, sans démarrer. C'est la même erreur que tu verras en 9.11.3. Le résultat est le même : le `revisor` ne démarrerait jamais. Et `prueba-lento` non plus : son contrôle exige une réponse en moins de 2 secondes, et en mode lent elle en prend 3. Les services qui échouent volontairement ne peuvent pas être sains, parce qu'échouer est leur travail. Ce dont le `revisor` a besoin, c'est qu'ils **existent** (pour que leur nom soit dans le DNS) et qu'au moins un soit prêt pour que le premier rapport ait quelque chose à dire. D'où : la saine, `service_healthy` ; les autres, `service_started`.

C'est la règle générale, et tu l'utiliseras dans tous tes projets : **`service_healthy` pour ce dont ton service a besoin en bonne santé pour démarrer (une base de données, par exemple), et `service_started` pour ce dont il a seulement besoin qu'il existe**. Et un avertissement honnête : `depends_on` n'ordonne que le **démarrage**. Si une dépendance tombe en panne une heure plus tard, Compose n'arrête ni ne redémarre celui qui en dépendait. Le `revisor` le gère bien parce que son travail est précisément de signaler ce qui ne répond pas.

### 9.8 Les secrets Compose

#### 9.8.1 Ce qu'ils sont et où ils apparaissent

Dans la Leçon 6, tu as monté le token avec un `--mount type=bind` d'un seul fichier, sur `/run/secrets/revisor_token`, et tu as indiqué où il se trouvait avec `REVISOR_TOKEN_ARCHIVO`. Compose a un élément pour cela. Sa documentation définit un secret comme « toute donnée, comme un mot de passe, un certificat ou une clé d'API » qui ne devrait pas circuler sans protection, et dit où il apparaît : les secrets « sont montés sous forme de fichier dans `/run/secrets/<nom_du_secret>` à l'intérieur du conteneur » ([Docker, « Secrets in Compose »](https://docs.docker.com/compose/how-tos/use-secrets/)). C'est pourquoi le `revisor` utilise ce chemin depuis la Leçon 6 : c'est la convention de Compose.

Ils se déclarent à deux endroits, comme les réseaux et les volumes. En haut, d'où il vient :

```yaml
secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

Et dans le service, qui le reçoit :

```yaml
    secrets:
      - revisor_token
```

Cette seconde partie compte : « les services ne peuvent accéder aux secrets que lorsque cela leur est explicitement accordé par un attribut `secrets` » ([Docker, « Secrets in Compose »](https://docs.docker.com/compose/how-tos/use-secrets/)). Les trois copies du service de test ne le reçoivent pas, et c'est pourquoi elles ne le voient pas. La valeur n'est jamais écrite dans le fichier : le `compose.yaml` dit **où** se trouve le token, pas **quel** il est. Ainsi, le fichier peut aller dans le dépôt et `secretos/` non : ce sont deux fichiers d'exclusion, un par destination. Le `.dockerignore` le laisse hors de l'image (c'est déjà le cas depuis la Leçon 6) et le `.gitignore` le laisse hors du dépôt (9.8.4). Le matériel de ce cours, lui, inclut bien son dossier `secretos/` dans le dépôt, exprès, parce que son token est factice ; le tien, avec un vrai token, non.

#### 9.8.2 Le piège : les permissions sont celles du fichier

Ce qui suit est le point le plus important de cette section, parce que c'est une erreur que la documentation explique dans une note et que presque personne ne lit. La forme longue d'un secret dans le service accepte `uid`, `gid` et `mode`, et ils ressemblent à la solution parfaite : « que le fichier dans le conteneur appartienne à l'utilisateur 65532, avec la permission `0400` ». Mais **quand le secret provient d'un fichier, Compose les ignore**. La référence le dit ainsi : avec un fichier comme source, Compose utilise en interne un montage qui ne permet pas de changer le propriétaire, « et ces attributs sont ignorés en silence » ; ils ne fonctionnent que lorsque le secret provient d'une variable d'environnement ([référence des services Compose](https://docs.docker.com/reference/compose-file/services/)).

En pratique, cela veut dire que le secret Compose est **le même montage que dans la Leçon 6**, avec le propriétaire et les permissions que le fichier a sur ta machine. Si le fichier est en `600`, seul ton utilisateur le lit ; le `revisor` s'exécute en tant que `65532` ; le résultat est `permission denied` et le `revisor` se termine avec le code 1. S'il est en `644`, il le lit. Tu vas le provoquer en 9.10, avec `uid`, `gid` et `mode` déclarés, pour que tu voies qu'ils ne changent rien. C'est pourquoi le cours utilise la forme courte (`- revisor_token`) : écrire `uid`, `gid` et `mode` avec un secret provenant d'un fichier ne sert qu'à donner une fausse impression de sécurité.

La conséquence pratique est que **la permission du fichier sur ta machine est une décision de sécurité que tu prends toi-même**, pas Compose. `644` fait démarrer le `revisor`, mais laisse aussi n'importe quel autre compte de ta machine lire le token. Les deux sections qui suivent le mesurent et montrent la forme sûre ; la section 6.5.4 de la Leçon 6 dit la même chose, avec d'autres mots.

#### 9.8.3 Mesurer qui peut lire le token

Une permission comme `644` se compose de trois chiffres, un pour chaque groupe de personnes : le **propriétaire** du fichier, le **groupe** du fichier et **tous les autres**. Chaque chiffre additionne `4` (lire), `2` (écrire) et `1` (exécuter). Ainsi, `644` signifie « le propriétaire lit et écrit (`6 = 4 + 2`), le groupe lit (`4`) et tous les autres lisent (`4`) ». « Tous les autres » n'est pas une façon de dire « toi » : c'est **n'importe quel compte de ta machine**, celui d'une autre personne qui a une session ouverte sur un serveur partagé, celui d'un service qui s'exécute avec son propre utilisateur, ou celui d'un programme que quelqu'un a réussi à faire tourner sous un autre utilisateur. Avec `600`, seul le propriétaire le lit, et avec `640`, le propriétaire et le groupe le lisent, et personne d'autre.

Cela se vérifie avec deux commandes. `ls -l secretos/` affiche les permissions en lettres : `-rw-r--r--` est `644`, `-rw-------` est `600` et `-rw-r-----` est `640`. Et `stat -c '%a %U:%G' secretos/revisor_token.txt` les affiche en nombre, avec le propriétaire et le groupe. Quand le numéro d'un propriétaire ne correspond à aucun compte de ta machine (le `65532` du `revisor` n'est pas un compte), `stat` écrit `UNKNOWN` ; pour voir le numéro, demande-le avec `%u:%g` ou utilise `ls -ln`.

Mais regarder les permissions n'est pas la même chose que les **tester**. Le script `fig09_11.sh` fait les deux et, dans chaque cas, pose la même question : un autre utilisateur sans privilèges le lit-il ? Toi, le lis-tu ? Le `revisor`, qui s'exécute en tant que `65532`, le lit-il ? Pour « un autre utilisateur », il utilise `sudo -u nobody` : `nobody` est un compte sans privilèges qui existe dans tout Linux, et qui sert à se faire passer pour n'importe quel autre utilisateur. Avant chaque `Permission denied` de `nobody`, il y a un contrôle : `sudo -u nobody stat` démontre que `nobody` **atteint bien le fichier** (le dossier est ouvert), de sorte que si le `cat` suivant échoue, c'est à cause de la permission du fichier et non d'autre chose. (Sur la machine de test, le dossier personnel est en `750`, et cela ne freine que celui qui essaie d'y entrer ; n'y compte pas : le projet peut se trouver à un autre endroit, ou quelqu'un peut ouvrir le dossier un jour.) Le script a besoin de `sudo`, pour se faire passer pour `nobody` et pour changer le propriétaire du fichier. Les cas 3 et 4 suivent **tels quels** les options B et A de 9.8.4, en partant du `644` avec lequel tu arrives de la Leçon 6. La partie qui change, avec le fichier du token factice :

```bash
# La cuenta sin privilegios: «nobody» existe en todo Linux y sirve para hacerse
# pasar por «otro usuario cualquiera de tu equipo». El nombre de tu usuario y de tu
# grupo se tapa con sed, porque depende del equipo.
SUBE="docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
PS_REV="docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
STAT="stat -c '%a %U:%G' secretos/revisor_token.txt"
TAPA_TODO="sed -E 's/ .*/ <tu usuario>:<tu grupo>/'"
TAPA_DUENO="sed -E 's/ [^:]+:/ <tu usuario>:/'"
# El control de cada negativa: «nobody» sí llega hasta el archivo (la carpeta está
# abierta); si el cat siguiente falla, es por el permiso del archivo.
CONTROL="sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt"
OTRO="sudo -u nobody cat secretos/revisor_token.txt"

echo "== 1. Permisos 644, dueño tu usuario"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "$PS_REV"

echo
echo "== 2. Permisos 600, dueño tu usuario"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
sleep 4
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "[ \"\$(docker inspect --format '{{.RestartCount}}' ${COMPOSE_PROJECT_NAME}-revisor-1)\" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'"

echo
echo "== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala"
muestra "chmod 644 secretos/revisor_token.txt"   # el estado con el que llegas de la Lección 6
muestra "chmod 600 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "$STAT"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "sudo cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"   # el archivo vuelve a ser tuyo
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chgrp +65532 secretos/revisor_token.txt"
muestra "chmod 640 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_DUENO"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 5. Lo mismo, más la carpeta secretos/ cerrada con 700"
muestra "chmod 700 secretos"
muestra "stat -c '%a' secretos"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"
muestra "chmod 755 secretos"

echo
echo "== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"

echo
echo "== 7. ¿El grupo 65532 es de alguien en este equipo?"
muestra "getent group 65532"
```

```text
$ ./fig09_11.sh
== 1. Permisos 644, dueño tu usuario
$ chmod 644 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
644 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)

== 2. Permisos 600, dueño tu usuario
$ chmod 600 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
600 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ [ "$(docker inspect --format '{{.RestartCount}}' curso-docker-fig09-revisor-1)" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'
el revisor se reinició: no pudo leer su token

== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala
$ chmod 644 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt
600 UNKNOWN:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt
600 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ sudo cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200

== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chgrp +65532 secretos/revisor_token.txt
$ chmod 640 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ [^:]+:/ <tu usuario>:/'
640 <tu usuario>:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'
640 <tu uid>:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
640 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA       <t>  codigo 503
lento     LENTO     <t>  200
sano      OK          <t>  200

== 5. Lo mismo, más la carpeta secretos/ cerrada con 700
$ chmod 700 secretos
$ stat -c '%a' secretos
700
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
$ chmod 755 secretos

== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
chmod: changing permissions of 'secretos/revisor_token.txt': Operation not permitted
[código de salida: 1]
$ stat -c '%a %u:%g' secretos/revisor_token.txt
644 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c

== 7. ¿El grupo 65532 es de alguien en este equipo?
$ getent group 65532
[código de salida: 2]
```

Résumé de ce qui a été montré, cas par cas :

| Permissions et propriétaire | Un autre utilisateur le lit-il ? | Toi, le lis-tu ? | Le `revisor` le lit-il ? |
|---|---|---|---|
| `644`, ton utilisateur | **oui** | oui | oui |
| `600`, ton utilisateur | non | oui | **non** (`permission denied`) |
| `600`, propriétaire `65532` (option B) | non | non, sauf avec `sudo` | oui |
| `640`, ton utilisateur, groupe `65532` (option A) | non | oui | oui |

1. **`644` : n'importe qui le lit.** Le premier bloc est la découverte : `sudo -u nobody cat` affiche le token en entier. Le `revisor` démarre sain, et c'est pourquoi `644` ressemble à « la solution » : ça marche. Mais ça marche parce que le fichier est ouvert à tous, pas seulement au `revisor`.
2. **`600` de ton utilisateur : on ferme, et on ferme aussi au `revisor`.** `nobody` reçoit `Permission denied`, mais le `revisor` aussi : c'est l'erreur de la Leçon 6 et de 9.10. Le fichier appartient à ton utilisateur, le `revisor` est l'utilisateur `65532`, et pour le noyau, le `revisor` est « un autre utilisateur » comme `nobody`. La ligne `se reinició` confirme que le `revisor` entre et sort en boucle.
3. **`600` avec le propriétaire `65532` (option B) : fermé à tous, sauf au `revisor`.** Seul le propriétaire du fichier (le `revisor`) et `root` peuvent le lire. `nobody` reçoit `Permission denied`, et toi aussi, parce que tu n'es plus le propriétaire ; pour le voir ou le modifier, tu as besoin de `sudo cat`. Le `revisor` arrive à `(healthy)` et le tableau s'affiche avec le token. Le prix : ton confort. Et le `UNKNOWN:UNKNOWN` du premier `stat` n'est pas une erreur : le numéro `65532` n'a pas de nom de compte sur ta machine. Remarque l'**ordre** : d'abord `chmod 600`, puis `sudo chown`.
4. **`640` avec le groupe `65532` (option A) : la sortie confortable.** Tu restes le propriétaire (tu le lis et le modifies sans `sudo`), et le **groupe** du fichier est `65532`. Le `revisor` s'exécute en tant que `65532:65532` (utilisateur et groupe, qui viennent de l'image : `docker inspect --format '{{.Config.User}}'`), donc pour le noyau il entre par le chiffre du groupe. `nobody` n'est pas dans ce groupe et ne lit rien. C'est la permission minimale qui permet aux deux parties de travailler. Il en va comme dans la Leçon 6 : les numéros de l'intérieur et de l'extérieur doivent être les mêmes (installation normale de la Leçon 1). Avec Docker sans `root` ou avec remappage des utilisateurs, le `65532` de l'intérieur correspond à l'extérieur à un autre numéro (le début de ta plage dans `/etc/subuid` et `/etc/subgid` plus 65532 ; ce début change d'une installation à l'autre, et se lit dans ces fichiers. À titre d'exemple, la [documentation de `userns-remap`](https://docs.docker.com/engine/security/userns-remap/) explique qu'avec une plage commençant à `231072`, le `231073` est l'utilisateur `1` de l'intérieur ; le `231072` n'est que la valeur de cet exemple), et cette recette ne s'applique pas telle quelle : le `revisor` donnera `permission denied`, et il n'y a pas de fuite, mais pas non plus de solution rapide ; le diagnostic est celui de `ls -ln` de la Leçon 6.
5. **Le dossier `secretos/` en `700` ne gêne pas.** Le bloc 5 le ferme (`chmod 700 secretos`) et le `revisor` est recréé et reste `(healthy)` : le montage d'un seul fichier est établi par le daemon, pas par ton utilisateur. Ferme le dossier en plus du fichier : celui qui ne peut pas y entrer ne voit même pas que le token existe.
6. **Le mauvais ordre laisse le token ouvert.** Le bloc 6 fait l'option B à l'envers : `sudo chown 65532:65532` d'abord et `chmod 600` ensuite. Le `chmod` échoue avec `Operation not permitted`, parce que tu n'es plus le propriétaire et que le noyau ne laisse changer les permissions qu'au propriétaire (ou à `root`). Le fichier reste en `644`, désormais à `65532`, et `nobody` affiche le token. On **ferme toujours d'abord et on cède ensuite**, et on vérifie à la fin.
7. **Le groupe `65532` n'est pas exclusif au `revisor`.** C'est l'utilisateur et le groupe `nonroot` des images *distroless* (l'image finale du `revisor` est `gcr.io/distroless/static-debian13:nonroot`) et de celles de Chainguard ; ainsi, tout conteneur de ces images dans lequel tu montes ce fichier le lit par le chiffre du groupe. Et si, sur ta machine, il existait un vrai groupe portant ce numéro, ses membres le liraient aussi. C'est pourquoi le dernier bloc demande `getent group 65532` : s'il n'affiche rien (comme ici, avec le code de sortie 2), le numéro n'appartient à personne sur ta machine.

Ce qu'aucune permission n'empêche : `root` lit tout, et quiconque peut parler au daemon Docker (le groupe `docker` de la Leçon 1) peut monter ton dossier dans un conteneur et le lire. C'est pourquoi on surveille qui appartient à ce groupe ; c'est une autre raison de ne pas offrir le fichier à « tous les autres ».

#### 9.8.4 La forme sûre dans ton dossier

Il y a deux façons de laisser le fichier fermé, de la plus confortable à la plus stricte. Les deux laissent lire le `revisor` et laissent les autres dehors. **Choisis-en une** ; ne les applique pas à la suite.

**Option A** : tu es le propriétaire et le groupe du `revisor` peut lire.

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt
chmod 640 secretos/revisor_token.txt
```

Le `+` dit à `chgrp` que `65532` est un numéro de groupe et non un nom (sans le `+`, il le prend aussi comme un numéro s'il n'existe pas de groupe portant ce nom).

**Option B** : le propriétaire est le `revisor` lui-même. Tu as besoin de `sudo` pour le lire.

```bash
cd revisor
chmod 600 secretos/revisor_token.txt               # primero se cierra, mientras aún eres el dueño
sudo chown 65532:65532 secretos/revisor_token.txt  # después se regala; ya no podrás cambiarlo sin sudo
```

L'ordre compte : si tu cèdes d'abord, le `chmod` échoue et le fichier reste comme il était (bloc 6 de 9.8.3).

Quelle que soit celle que tu choisis, **vérifie toujours** :

```bash
ls -l secretos/revisor_token.txt
stat -c '%a %U:%G' secretos/revisor_token.txt
sudo -u nobody cat secretos/revisor_token.txt   # debe decir: Permission denied
chmod 700 secretos                              # y cierra también la carpeta
```

Ensuite, `docker compose up -d --force-recreate revisor` (changer la permission d'un fichier n'est pas un changement de configuration pour Compose, et le `revisor` ne lit son token qu'au démarrage).

**Les copies comptent aussi.** Chaque copie du token naît avec ses propres permissions : un `cp` sans `-p` laisse le fichier à ton nom, avec ton groupe et ton `umask` ; et la copie de sauvegarde d'un éditeur (`revisor_token.txt~`), la sauvegarde de ton dossier personnel ou une copie sur une clé USB ou dans le cloud ne conservent pas le `640`. Vérifie-les avec le même `stat`, ou ne les fais pas.

**Pour créer un nouveau secret**, fais en sorte qu'il naisse fermé au lieu de l'ouvrir puis le fermer ensuite. Regarde ton `umask` avec `umask` : c'est la « soustraction » de permissions que le système applique à tout nouveau fichier. Sous Ubuntu et Linux Mint, il vaut en général `0002` (mesuré sur la machine de test, Ubuntu 24.04), et un nouveau fichier sort en `664` : n'importe qui le lit, comme avec `644`. Le `644` que tu as vu dans la Leçon 6 n'a pas été posé par l'`umask` : il l'a été par le `chmod` du cours. Deux façons de créer un fichier fermé :

```bash
install -m 600 /dev/null secretos/token.txt                              # crea el archivo vacío, ya en 600
(umask 077; read -rs VALOR; printf '%s' "$VALOR" > secretos/token2.txt)  # pegas el valor sin que se vea
```

Trois avertissements. Les deux façons sont destinées à un fichier qui **n'existe pas encore** : s'il existe déjà, `umask` ne change pas sa permission (ferme-le avec `chmod 600`) et `install` le remplace par un fichier vide, sans prévenir. Les deux le laissent en `600` **à ton nom**, ce qui est le cas 2 de 9.8.3 : le `revisor` ne peut pas encore le lire, donc termine avec l'option A ou la B. Et **n'écris pas la valeur dans la ligne de commande** (`VALOR=... ` ou `echo ... >`) : elle reste dans l'historique de ton terminal ; c'est pourquoi l'exemple utilise `read -rs`, ou colle-la depuis un éditeur.

**Et quand `644` est-il acceptable ?** Dans une seule situation : un token factice, sur un ordinateur qui n'est qu'à toi, pour un exercice. Les scripts de cette leçon l'utilisent dans un dossier temporaire supprimé à la fin, et c'est pourquoi ils le laissent en `644`. Trois avertissements, sans clause en petits caractères :

- **Le token du cours est fictif** (`curso-docker-token-de-mentira-7f3a9c`) ; il n'ouvre rien.
- **`644` permet à n'importe quel compte local de le lire**, comme tu viens de le mesurer.
- **N'utilise jamais `644` avec un vrai secret** : ni sur ton portable, ni sur un serveur, ni « juste un instant pendant que je teste ».

Et l'autre moitié de l'hygiène du secret : **qu'il n'arrive pas dans le dépôt**. Dans ton projet, `secretos/` va dans le `.gitignore` dès le premier jour, et cela se vérifie :

```bash
echo 'secretos/' >> .gitignore
git check-ignore -v secretos/revisor_token.txt
```

```text
.gitignore:1:secretos/	secretos/revisor_token.txt
```

Si `git check-ignore` n'affiche rien, le fichier n'est **pas** ignoré. (Une exception : si `git` suit déjà le fichier avant que tu ne l'ignores, le `.gitignore` ne le lâche pas ; on le retire avec `git rm --cached` et le token déjà publié est considéré comme perdu et se change, comme dans la Leçon 6.) Ce que tu as vu de Compose en 9.8.1 se résume ainsi : le `compose.yaml` dit où se trouve le token, le `.gitignore` le maintient hors du dépôt, le `.dockerignore` le maintient hors de l'image, et la permission du fichier le maintient hors de portée du reste de ta machine.

### 9.9 Le fichier final

#### 9.9.1 Tout ensemble

Voici le `compose.yaml` avec lequel tu termines la leçon. Il remplace le premier dans ton dossier `revisor/` ; c'est le même que celui que conserve `estado/compose.yaml` :

```yaml
# fig09_04.compose.yaml — el compose.yaml final de la Lección 9. Va en tu carpeta
# revisor/ como compose.yaml (es el mismo que guarda estado/compose.yaml).
#
# Lección 9 — el sistema completo: el revisor y tres copias del servicio de
# prueba (sana, lenta y caída), con todo lo que se endureció en las lecciones 2 a 8.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

# Lo común a las tres copias del servicio de prueba, escrito una sola vez.
# Compose ignora los campos que empiezan con «x-»; sirven para anclas de YAML.
# Solo prueba-sano lleva «build»: si las tres construyeran la misma etiqueta a la
# vez, chocarían («image ... already exists»). Las otras dos usan la imagen que
# construye la primera y nunca la buscan en internet (pull_policy: never).
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  init: true
  mem_limit: 32m
  cpus: 0.25
  pids_limit: 20

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: >-
        sano http://prueba-sano:9000/ 2s,
        lento http://prueba-lento:9000/ 5s,
        caido http://prueba-caido:9000/ 2s
      REVISOR_TOKEN_ARCHIVO: /run/secrets/revisor_token
    secrets:
      - revisor_token
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
    restart: unless-stopped

  prueba-sano:
    <<: *prueba
    build: ../servicio-prueba
    environment:
      PRUEBA_MODO: sano

  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento

  prueba-caido:
    <<: *prueba
    environment:
      PRUEBA_MODO: caido

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}

secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

Ce qui a changé par rapport au premier, service par service :

- **`x-prueba`** : le bloc commun des trois copies (9.6), avec les mêmes options durcies que le `revisor`, `init: true` compris. Elles ont des limites plus petites (32 Mo et un quart de CPU), parce qu'elles ne font presque rien.
- **`revisor`** : trois services dans `REVISOR_SERVICIOS`, le token sous forme de secret avec `REVISOR_TOKEN_ARCHIVO` pointant vers `/run/secrets/revisor_token`, `depends_on` avec ses conditions (9.7), et `restart: unless-stopped`, la politique que la Leçon 7 a choisie pour le `revisor`.
- **`prueba-sano`, `prueba-lento`, `prueba-caido`** : l'ancre plus leur mode. Seule la saine construit.
- **En haut** : les mêmes réseaux et le même volume, plus le secret.

Un détail de YAML dans `REVISOR_SERVICIOS` : le `>-` est un **bloc replié**. YAML réunit les trois lignes en une seule, avec une espace là où il y avait des sauts de ligne, et le `-` supprime le saut final. Ainsi, chaque service reste sur sa propre ligne dans le fichier, facile à lire et à modifier, et le `revisor` reçoit une seule chaîne séparée par des virgules, ce qu'il attend. Le bloc 5 de l'exécution suivante te montre la valeur telle qu'elle est arrivée dans le conteneur.

#### 9.9.2 Le voir fonctionner

Le script `fig09_05.sh` le démarre à partir de zéro et l'inspecte de l'intérieur. La partie qui change :

```bash
echo "== 1. Validar"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'"

echo
echo "== 2. Levantar todo desde cero"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 3. El reporte: sin token, 401; con token, la tabla"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
muestra "tabla"

echo
echo "== 4. Lo que creó Compose, todo con el nombre del proyecto"
muestra "docker network ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}} interna={{.Internal}}' | sort"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 5. El token no está a la vista"
muestra "docker inspect ${COMPOSE_PROJECT_NAME}-revisor-1 | grep -c \"\$TOKEN\""
muestra "docker compose config | grep -c \"\$TOKEN\""
muestra "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1 | grep REVISOR_"
muestra "docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
```

```text
$ ./fig09_05.sh
== 1. Validar
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba-caido
prueba-lento
prueba-sano
revisor
$ docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'
      PRUEBA_MODO: lento
    image: curso-docker-prueba:fig09
    mem_limit: "33554432"
    networks:
    pull_policy: never
    read_only: true

== 2. Levantar todo desde cero
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-revisor:fig09 Built
Image curso-docker-prueba:fig09 Built
Network curso-docker-fig09_publica Created
Network curso-docker-fig09_interna Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-caido-1 Created
Container curso-docker-fig09-prueba-sano-1 Created
Container curso-docker-fig09-prueba-lento-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-caido-1 Started
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-sano-1 Waiting
Container curso-docker-fig09-prueba-sano-1 Healthy
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-caido-1 | Up N (unhealthy) | 9000/tcp
curso-docker-fig09-prueba-lento-1 | Up N (health: starting) | 9000/tcp
curso-docker-fig09-prueba-sano-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp

== 3. El reporte: sin token, 401; con token, la tabla
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados
{"error":"falta el token o no es válido"}
 [401]
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200

== 4. Lo que creó Compose, todo con el nombre del proyecto
$ docker network ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}} interna={{.Internal}}' | sort
curso-docker-fig09_interna interna=true
curso-docker-fig09_publica interna=false
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' curso-docker-fig09-revisor-1
ReadonlyRootfs=true CapDrop=[ALL] Init=true Memory=67108864 User=65532:65532 Restart=unless-stopped

== 5. El token no está a la vista
$ docker inspect curso-docker-fig09-revisor-1 | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker compose config | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-fig09-revisor-1 | grep REVISOR_
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_SERVICIOS=sano http://prueba-sano:9000/ 2s, lento http://prueba-lento:9000/ 5s, caido http://prueba-caido:9000/ 2s
REVISOR_PUERTO=8080
REVISOR_REPORTE=/datos/reporte.json
$ docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true
volume /datos ro=false
```

#### 9.9.3 Lire l'exécution

1. **Valider.** Quatre services. Et le service `prueba-lento`, lu par `config`, apporte `image`, `pull_policy: never`, `read_only`, `mem_limit` (32 Mo, en octets) et `networks`, qui viennent de l'ancre. L'ancre fonctionne.
2. **Démarrer.** Remarque l'ordre des événements, qui est le cœur de cette leçon. Les deux images sont construites (seulement deux, bien qu'il y ait quatre services), les réseaux, le volume et les quatre conteneurs sont créés. Les trois copies du service de test démarrent. Et alors apparaissent `prueba-sano-1 Waiting` et `prueba-sano-1 Healthy` : Compose a **attendu** que la saine réussisse son contrôle de santé, et c'est seulement ensuite qu'il a démarré le `revisor`. C'est `service_healthy` qui fonctionne. L'ordre dans lequel les trois copies démarrent peut changer d'une exécution à l'autre, parce qu'elles démarrent en même temps.
3. **`ps`.** L'état de santé raconte toute l'histoire : `prueba-caido` est `(unhealthy)`, ce qui est son travail ; `prueba-lento` est `(health: starting)` et finira `unhealthy` (elle met 3 s et son contrôle exige moins de 2) ; `prueba-sano` et le `revisor` sont `(healthy)`. Quatre conteneurs `Up`, et seulement deux sains : le deuxième principe du cours, dans un seul tableau.
4. **Le rapport.** Sans token, `401` avec le message du `revisor` : le secret est arrivé et le `revisor` l'exige. Avec le token, le tableau avec les trois états : `FALLA` avec `codigo 503`, `LENTO` (elle a répondu `200`, mais en plus d'une seconde) et `OK`. C'est l'objectif du cours.
5. **Ce que Compose a créé.** Deux réseaux, l'interne avec `interna=true` ; un volume ; et le `revisor` avec tout le durcissement de la Leçon 7 appliqué par le daemon : système de fichiers en lecture seule, `CapDrop=[ALL]`, `Init=true`, 64 Mo, utilisateur `65532:65532` (qui vient de l'image) et la politique de redémarrage.
6. **Le token n'est pas visible.** `grep -c` compte zéro occurrence de la valeur du token dans tout `docker inspect` et dans tout `docker compose config` (le `[código de salida: 1]` vient de `grep`, qui se termine avec 1 quand il ne trouve rien : ici, c'est la bonne nouvelle). L'environnement du conteneur contient `REVISOR_TOKEN_ARCHIVO`, qui est un **chemin**, pas une valeur. Et les montages montrent ce qu'est un secret de fichier de l'intérieur : un `bind` en lecture seule (`ro=true`) sur `/run/secrets/revisor_token`, à côté du `volume` de `/datos`. Le troisième objectif du cours (« aucun secret n'apparaît dans `docker history`, dans `docker inspect` ni dans les variables d'environnement du conteneur ») est atteint, pour sa partie d'exécution, avec le système complet.

#### 9.9.4 Dans ton dossier

Avec le fichier final dans `revisor/compose.yaml`, `servicio-prueba/` à côté et `secretos/revisor_token.txt` avec les permissions `640` et le groupe `65532` (9.8.4) :

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt   # el grupo del revisor puede leerlo...
chmod 640 secretos/revisor_token.txt          # ...y ningún otro usuario (9.8.4)
docker compose config --quiet && echo 'compose.yaml válido'
docker compose up -d --build
docker compose ps
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" 'http://127.0.0.1:8080/api/estados?formato=tabla'
```

Une remarque sur ce `curl` : pendant qu'il s'exécute, le token figure dans sa ligne de commande et n'importe quel compte peut le voir avec `ps`, même si le fichier est en `640`. Avec le token factice, cela n'a pas d'importance ; avec un vrai, passe-le depuis un fichier d'en-têtes (`curl -H @cabeceras.txt`, qui doit avoir ses propres permissions fermées).

Les scripts de cette leçon utilisent `644` dans un dossier temporaire, avec le token factice ; ton dossier n'en a pas besoin. Avec `644`, n'importe quel utilisateur de ton ordinateur peut lire le token (9.8.3), et sur un serveur partagé, cela n'est pas acceptable : la solution est le bon groupe ou le bon propriétaire (section 6.5.4 de la Leçon 6), pas l'ouvrir à tous.

Les noms seront `curso-docker-revisor-1`, `curso-docker-prueba-sano-1` et ainsi de suite, avec les réseaux `curso-docker_publica` et `curso-docker_interna` et le volume `curso-docker_reportes`. Si la Leçon 8 t'a laissé `curso-docker-revisor` en cours d'exécution avec le port 8080, arrête-le d'abord (`docker rm -f curso-docker-revisor curso-docker-prueba`), sinon le `up` se heurtera au port occupé de la Leçon 2. Et si tu as conservé le volume `curso-docker-reportes` de la Leçon 8, il ne gêne pas : celui de Compose est un autre, `curso-docker_reportes`, avec un tiret bas.

### 9.10 L'erreur qui va te coûter le plus : le secret en `600`

#### 9.10.1 La provoquer avec `uid`, `gid` et `mode` écrits

Le script `fig09_06.sh` prend le fichier final, change le secret vers la forme longue avec `uid: "65532"`, `gid: "65532"` et `mode: 0400` (ce qui « devrait » régler la permission), met le fichier du token en `600` et démarre. Ensuite, il corrige avec `644`, ce que ses scripts utilisent dans leur dossier temporaire avec le token factice (dans ton dossier, la correction est celle de 9.8.4). La partie qui change :

```bash
cp compose.yaml compose.final.yaml

echo "== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600"
python3 - <<'PY'
s = open("compose.yaml").read()
s = s.replace("""    secrets:
      - revisor_token
""", """    secrets:
      - source: revisor_token
        uid: "65532"
        gid: "65532"
        mode: 0400
""")
open("compose.yaml", "w").write(s)
PY
chmod 600 secretos/revisor_token.txt
muestra "diff compose.final.yaml compose.yaml"
muestra "stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
sleep 3
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/run/secrets/revisor_token\"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)"
cp compose.final.yaml compose.yaml
chmod 644 secretos/revisor_token.txt   # 644: solo porque el token es de mentira (9.8.4)
muestra "stat -c '%a %n' secretos/revisor_token.txt"
muestra "docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "tabla"
```

```text
$ ./fig09_06.sh
== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600
$ diff compose.final.yaml compose.yaml
41c41,44
<       - revisor_token
---
>       - source: revisor_token
>         uid: "65532"
>         gid: "65532"
>         mode: 0400
[código de salida: 1]
$ stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'
600 <tu usuario> secretos/revisor_token.txt
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker inspect --format '{{range .Mounts}}{{if eq .Destination "/run/secrets/revisor_token"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true

== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)
$ stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.10.2 Le lire

1. **Le `diff`** montre la forme longue, et `stat` montre le fichier en `600`, appartenant à ton utilisateur (le numéro est masqué car il dépend de la machine).
2. **`Started`.** Compose dit que le `revisor` a démarré, et c'est vrai : le processus a démarré. Mais les journaux racontent la suite : `leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied`. Le `revisor` n'a pas pu lire son token et a préféré mourir avec le code 1 plutôt que de rester à l'écoute sans protection (Leçon 6). Le `sort -u` du script regroupe les lignes répétées, parce que le message sort une fois par tentative.
3. **`Status=restarting ExitCode=1`.** Des tentatives ? Oui : le fichier final porte `restart: unless-stopped`, donc le daemon le redémarre chaque fois qu'il meurt, avec des attentes de plus en plus longues, et chaque fois il meurt de la même façon. C'est ce que tu verras dans un système réel quand un secret a de mauvaises permissions : un conteneur qui entre et sort, et un `docker compose ps` qui dit `Restarting`. La politique de redémarrage s'occupe de la mort du processus, comme tu l'as vu dans la Leçon 7 ; elle ne peut pas en corriger la cause.
4. **Le montage.** Le secret est un `bind` en lecture seule, avec `uid`, `gid` et `mode` déclarés. Les trois attributs n'ont rien fait. C'est exactement ce que dit la référence, mesuré.
5. **La correction du script** : `644` et le fichier de la leçon, avec la forme courte. C'est la correction la plus courte, pas la meilleure : elle ouvre le token à toute la machine (9.8.3). Dans ton dossier, utilise celle de 9.8.4. `--force-recreate revisor` demande à Compose de recréer ce service même si sa configuration est la même que celle du conteneur existant ; ici c'est nécessaire parce que la seule chose qui a changé est la permission d'un fichier sur ta machine, et cela, Compose ne le compare pas. Le `revisor` arrive à `(healthy)` et le tableau revient.

Si cela t'arrive dans ton dossier : `ls -l secretos/`, et si cela affiche `-rw-------`, donne la lecture **uniquement** au groupe du `revisor` (`sudo chgrp +65532 secretos/revisor_token.txt` et `chmod 640 secretos/revisor_token.txt`, 9.8.4) puis `docker compose up -d --force-recreate revisor`. `chmod 644` règle aussi le problème, mais laisse le token visible de toute ta machine : uniquement avec un token factice. Ce qui n'est **pas** une correction : retirer le `USER` de l'image ou mettre `user: "0"` dans le service pour que `root` le lise. Cela échange un problème de permissions d'un fichier contre un conteneur entier qui s'exécute en tant que `root`.

### 9.11 Deux erreurs de Compose qu'il vaut mieux connaître d'avance

Le script `fig09_07.sh` provoque les deux erreurs propres à ce fichier et mesure ce qui se passe sans `pull_policy: never` (la question restée ouverte en 9.6.3). La partie qui change :

```bash
cp compose.yaml compose.final.yaml

echo "== 1. Las tres copias del servicio de prueba con «build»"
# Pone «build» en el ancla común (las tres copias la heredan) y quita la de prueba-sano.
sed -i -e 's|^  image: \(.*prueba:fig09\)$|  build: ../servicio-prueba\n  image: \1|' \
       -e '/^    build: ..\/servicio-prueba$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
# Es una carrera: a veces una de las tres termina antes de que empiecen las otras
# y no choca. Por eso se intenta cinco veces, borrando la etiqueta entre una y otra.
for i in 1 2 3 4 5; do
  docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1
  echo "-- intento $i"
  muestra "docker compose build >build.log 2>&1; echo \"build salió con \$?\"; grep -h '^target' build.log || true"
done
docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1

echo
echo "== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir"
cp compose.final.yaml compose.yaml
sed -i '/^  pull_policy: never$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'"
docker compose down --remove-orphans >/dev/null 2>&1

echo
echo "== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar"
cp compose.final.yaml compose.yaml
docker compose build >/dev/null 2>&1
inicio=$(date +%s)
muestra "docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1"
echo "(tardó $(( $(date +%s) - inicio )) s)"
muestra "docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1"
muestra "docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 4. Lo que sí funciona: up -d y esperar la salud del revisor"
esperar revisor healthy && echo "revisor: healthy"
muestra "tabla"
```

```text
$ ./fig09_07.sh
== 1. Las tres copias del servicio de prueba con «build»
$ diff compose.final.yaml compose.yaml
15a16
>   build: ../servicio-prueba
67d67
<     build: ../servicio-prueba
[código de salida: 1]
-- intento 1
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 2
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0
-- intento 3
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 4
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-lento: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 5
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0

== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir
$ diff compose.final.yaml compose.yaml
17d16
<   pull_policy: never
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Building
Image curso-docker-prueba:fig09 Built

== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar
$ docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
(tardó 11 s)
$ docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (health: starting)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)

== 4. Lo que sí funciona: up -d y esperar la salud del revisor
revisor: healthy
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.11.1 Trois constructions du même tag

Avec `build` dans l'ancre, les trois services de test construisent la même image avec le même nom, et Compose lance les trois constructions **en même temps**. Les trois se terminent avec la même image et les trois essaient de lui donner le même nom à la fin ; celle qui arrive après trouve le nom occupé : `target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists`, et `build` se termine avec `1`. Remarque deux choses. La première : le service qui signale la collision peut être n'importe lequel des trois, selon celui qui termine en dernier ; dans cette exécution, ce fut `prueba-sano` aux tentatives 1 et 3, et `prueba-lento` à la 4. La seconde : aux tentatives 2 et 5, il n'y a **pas** eu de collision, et `build` s'est terminé avec `0`. C'est une situation de compétition (race condition), et parfois on la gagne : dans cette exécution, elle a échoué à 3 tentatives sur 5. Une erreur qui apparaît « parfois » est pire qu'une qui apparaît toujours, parce qu'elle te fait croire que tu l'as corrigée alors que tu as juste eu de la chance.

La cause est une question de conception, pas de chance : **une image se construit une fois et s'utilise plusieurs fois**. C'est pourquoi le fichier final met `build` dans un seul service et `pull_policy: never` dans les deux autres (9.6.3). Dans ton terminal, le message complet est précédé des étapes de BuildKit ; cherche la ligne qui commence par `target`, qui te dit dans quel service l'échec s'est produit.

#### 9.11.2 Sans `pull_policy: never`

Le bloc 2 retire la ligne `pull_policy: never` de l'ancre (le `diff` le montre) et démarre avec l'image du service de test encore non construite (le bloc 1 l'a supprimée à la fin). Les événements de l'image racontent ce que nous avons dit en 9.6.3 : deux `Pulling` et deux `Error pull access denied`, un pour chaque service qui **ne** construit **pas** l'image (`prueba-lento` et `prueba-caido`) et qui, sans `never`, la cherche d'abord sur Docker Hub. Ensuite, `Building` et `Built` : Compose voit qu'un autre service du projet construit cette même image, laisse passer l'erreur et continue. Le système démarre quand même. C'est pourquoi `pull_policy: never` n'est pas là pour que ça fonctionne, mais pour que ça **ne pose pas la question** : sans la ligne, le démarrage dépend du fait qu'il n'existe sur Docker Hub rien portant ce nom, et remplit ton terminal d'erreurs que tu dois apprendre à ignorer, ce qui est la pire habitude qu'on puisse avoir face à une erreur.

#### 9.11.3 `--wait` avec un service qui échoue volontairement

`docker compose up --wait` existe pour les scripts et pour l'intégration continue : selon sa référence, il attend que les services soient « en cours d'exécution ou sains », et implique le mode détaché ; `--wait-timeout` fixe le nombre maximal de secondes d'attente ([référence de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Cela semble parfait pour attendre le `revisor`, mais regarde le bloc 3 : `container curso-docker-fig09-prueba-caido-1 is unhealthy`, code `1`, en onze secondes d'après le script lui-même (`tardó 11 s`). `--wait` attend **tous** les services qui ont un contrôle de santé, et `prueba-caido` ne sera jamais sain ; dès que Docker la marque `unhealthy`, `--wait` abandonne. Et ne nommer que le `revisor` (`up --wait revisor`) donne la même erreur : pour démarrer le `revisor`, Compose démarre ses dépendances, et attend aussi après elles.

Remarque le `ps` qui suit : le système est resté **actif** et fonctionnel, avec le `revisor` `(healthy)`. `--wait` n'a rien défait ; il a seulement signalé, par un code différent de 0, que tout n'est pas sain. Dans un vrai système, c'est exactement ce que tu veux savoir. Dans celui-ci, où un service est en panne volontairement, le cours utilise `up -d` puis attend la santé du **`revisor`** avec `docker inspect`, ce que fait la fonction `esperar` des scripts. Le bloc 4 le démontre, et le tableau s'affiche complet.

### 9.12 Le cycle de vie : changer, arrêter, conserver

Le script `fig09_08.sh` démarre le système final, demande un rapport pour qu'il y ait quelque chose d'enregistré, puis parcourt ce que tu feras tous les jours. La partie qui change :

```bash
cp compose.yaml compose.final.yaml
docker compose up -d --build >/dev/null 2>&1
esperar revisor healthy
curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados"

echo "== 1. Cambiar un servicio: prueba-caido pasa a modo sano"
sed -i '/^  prueba-caido:/,/^[a-z]/s/PRUEBA_MODO: caido/PRUEBA_MODO: sano/' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'"
esperar prueba-caido healthy
muestra "tabla"
cp compose.final.yaml compose.yaml
docker compose up -d >/dev/null 2>&1

echo
echo "== 2. down sin --volumes: el reporte sigue ahí, en su volumen"
muestra "docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker run --rm -v ${COMPOSE_PROJECT_NAME}_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'"
docker compose up -d >/dev/null 2>&1
esperar revisor healthy

echo
echo "== 3. Apagado ordenado"
inicio=$(date +%s%3N); docker compose stop revisor >/dev/null 2>&1; fin=$(date +%s%3N)
echo "docker compose stop revisor tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker compose logs --no-log-prefix revisor | tail -2"

echo
echo "== 4. down --volumes: ahora sí, también el reporte"
muestra "docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}' | wc -l"
```

```text
$ ./fig09_08.sh
== 1. Cambiar un servicio: prueba-caido pasa a modo sano
$ diff compose.final.yaml compose.yaml
79c79
<       PRUEBA_MODO: caido
---
>       PRUEBA_MODO: sano
[código de salida: 1]
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-prueba-caido-1 Recreate
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-caido-1 Started
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     OK            <t>  200
lento     LENTO     <t>  200
sano      OK            <t>  200

== 2. down sin --volumes: el reporte sigue ahí, en su volumen
$ docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker run --rm -v curso-docker-fig09_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'
total 4
-rw-------    1 65532    65532          269 <fecha> reporte.json

== 3. Apagado ordenado
docker compose stop revisor tardó 203 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
ExitCode=0
$ docker compose logs --no-log-prefix revisor | tail -2
revisor: recibí terminated, apagando
revisor: apagado limpio

== 4. down --volumes: ahora sí, también el reporte
$ docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Volume curso-docker-fig09_reportes Removed
Network curso-docker-fig09_publica Removed
Network curso-docker-fig09_interna Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}' | wc -l
0
```

1. **Changer un service.** Le fichier passe `prueba-caido` en mode sain et on demande `up -d`. Compose laisse trois conteneurs en `Running` et **recrée uniquement `prueba-caido`**. Même le `revisor`, qui en dépend, n'est pas touché : sa configuration n'a pas changé, et son `depends_on` ne demande pas de redémarrage quand une dépendance change (l'option `restart: true` existe dans `depends_on` pour cela ; la documentation la décrit pour un service qui doit se reconnecter quand sa base de données est recréée, et le `revisor` n'en a pas besoin parce qu'il ouvre une nouvelle connexion à chaque vérification) ([Docker, « Control startup order »](https://docs.docker.com/compose/how-tos/startup-order/)). Le tableau suivant dit `caido OK 200` : le nom du service reste `caido`, mais il répond désormais sainement. C'est le modèle de Compose dans un exemple : tu décris l'état que tu veux, et l'outil calcule le changement minimal. Le script remet le fichier dans sa forme finale avant de continuer.
2. **`down` sans `--volumes`.** Les conteneurs et les réseaux sont supprimés ; le volume reste dans `docker volume ls`. Le conteneur auxiliaire `alpine` de la Leçon 8 le lit en lecture seule et `reporte.json` est là, appartenant à `65532`, avec ses permissions `600` (le `revisor` le crée ainsi : le rapport appartient à celui qui l'écrit). Quand le script redemande `up -d`, le nouveau `revisor` monte le même volume. C'est le cinquième objectif du cours, « le rapport survit », désormais avec le système complet.
3. **Arrêt ordonné.** `docker compose stop revisor` prend moins d'une seconde (dans cette exécution, 203 ms) et le `revisor` se termine avec `ExitCode=0`. Ses journaux le racontent : `recibí terminated, apagando` et `apagado limpio`. `stop` utilise en interne le même `SIGTERM` et le même délai de 10 s que `docker stop` de la Leçon 7 ; `init: true` et le gestionnaire de signaux du `revisor` font le reste.
4. **`down --volumes`.** Cette fois le volume part, et avec lui le rapport. Utilise-le quand tu veux vraiment repartir de zéro, en sachant qu'il n'y a pas de corbeille.

### 9.13 Et `docker init` ?

Le plan du cours prévoyait de comparer ton fichier avec celui que génère `docker init`, une commande qui crée un `Dockerfile`, un `.dockerignore`, un `compose.yaml` et un `README.Docker.md` à partir d'un modèle par langage (Go, Python, Node, Java, Rust et d'autres) ([référence de `docker init`](https://docs.docker.com/reference/cli/docker/init/)). La première phrase de cette même page est celle qui compte ici : « Docker Desktop fournit la commande `docker init` ». Elle ne fait pas partie de Docker Engine, qui est ce que tu as installé sur ton Mint dans la Leçon 1. Le script `fig09_09.sh` le vérifie (il ne crée rien, donc il n'a pas besoin du démarrage des autres) :

```bash
#!/usr/bin/env bash
# fig09_09.sh — docker init es una función de Docker Desktop: en Docker Engine,
# el que instalaste en la Lección 1, el comando no existe. No crea nada.
set -uo pipefail
echo "\$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
echo "\$ docker compose version"
docker compose version
echo "\$ docker init"
docker init 2>&1
echo "[código de salida: $?]"
```

```text
$ ./fig09_09.sh
$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
Cliente: 29.2.1  Daemon: 29.2.1
$ docker compose version
Docker Compose version v5.0.2
$ docker init
docker: unknown command: docker init

Run 'docker --help' for more information
[código de salida: 1]
```

Le cours n'en dépend donc pas, et la comparaison se fait avec ce que montre la documentation officielle. Le guide de Docker pour conteneuriser une application Python commence par ce `compose.yaml` à un seul service (ici sans ses commentaires d'en-tête) ([Docker, « Containerize a Python application »](https://docs.docker.com/guides/python/containerize/)) :

```yaml
services:
  server:
    build:
      context: .
    ports:
      - 8000:8000
```

C'est un bon point de départ, et un fichier très différent du tien. L'Exercice 4 te demande de trouver les différences, une par une, et de dire quelle leçon du cours explique chacune. Un générateur t'épargne de l'écriture ; il ne t'épargne pas de comprendre ce qu'il a écrit. Si un jour tu utilises `docker init` sur une machine avec Docker Desktop, lis son `compose.yaml` avec `docker compose config` et passe-le par la liste de l'habitude de sécurité de cette leçon avant de l'utiliser.

### 9.14 Ce que tu vas trouver dans les vieux tutoriels

- **`docker-compose`, avec un tiret.** C'est Compose « V1 », un programme distinct écrit en Python. Docker le déclare retiré : « Compose v1 n'est plus maintenu, et les utilisateurs doivent migrer vers Compose v2 » ([Docker, « Retired features »](https://docs.docker.com/retired/)). Aujourd'hui, c'est `docker compose`, avec une espace. Si un tutoriel dit `docker-compose up`, traduis-le.
- **Des noms de conteneur avec un tiret bas**, comme `proyecto_web_1`. C'étaient ceux de V1. L'annonce de Compose V2 le dit ainsi : les noms de conteneur « utilisent désormais des tirets comme séparateurs au lieu de tirets bas », et si un script dépend de ces noms, il va casser ; c'est pourquoi elle recommande, en général, de ne pas dépendre des noms des conteneurs ([Docker, « Announcing Compose V2 General Availability »](https://www.docker.com/blog/announcing-compose-v2-general-availability/)). Si un vieux script cherche `curso-docker_revisor_1` (le nom qu'aurait en V1 le `curso-docker-revisor-1` de cette leçon), il ne le trouvera pas.
- **`version: "3.8"`** (ou `"2"`, ou `"3"`) au début du fichier. Obsolète ; il ne produit qu'un avertissement (9.2.3).
- **`docker-compose.yml`** comme nom de fichier. Il est encore accepté pour la compatibilité, mais le nom préféré est `compose.yaml`.
- **`links:`** dans un service. C'est le `--link` de la Leçon 8 sous forme de clé ; dans les réseaux d'un projet, les services se trouvent déjà par leur nom.
- **Le token dans `environment:`**, ou dans un fichier `.env` utilisé pour remplir `environment`. Ça marche, et c'est ce que la Leçon 6 t'a appris à ne pas faire : il reste dans `docker inspect`. C'est pour cela que les `secrets` existent.

## L'erreur que tu vas voir

Cette leçon compte trois erreurs principales. Toutes sont déjà apparues, et chacune se distingue par l'endroit où on la voit.

**Dans le rapport : `read-only file system` dans `/datos`.**

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Le conteneur est `healthy` et le rapport échoue. Cela se lit de droite à gauche, comme ceux des Leçons 7 et 8 : `read-only file system` est dit par le noyau ; `/datos/.reporte-<n>.tmp` dit que le problème est le dossier `/datos` ; et le `500` est posé par le `revisor`, qui ne fait pas semblant. La question qui le résout est : « qu'est-ce qui est monté sur `/datos` ? ». La réponse est donnée par `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' <conteneur>`. Si `/datos` n'apparaît pas, le volume manque dans le service. Correction : `volumes: [reportes:/datos]` dans le service et `reportes: {}` en haut, puis `docker compose up -d` (qui recrée uniquement le `revisor`). Ce qui n'est pas une correction : `read_only: false`.

**Dans les journaux : `permission denied` dans `/run/secrets/`.**

```text
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
```

Et dans `docker compose ps`, un `revisor` qui affiche `Restarting`. Le `Started` dans la sortie de `up` ne te préviendra pas : le processus a bien démarré, et il est mort ensuite. Le diagnostic se fait avec `docker compose logs revisor` et `ls -l secretos/`. Si le fichier est en `600`, l'utilisateur `65532` du conteneur ne peut pas le lire, et `uid`, `gid` et `mode` dans le `compose.yaml` ne changent rien, parce qu'avec un secret de fichier, Compose les ignore. Correction : que le groupe du fichier soit `65532` et la permission `640` (`sudo chgrp +65532 secretos/revisor_token.txt` et `chmod 640 secretos/revisor_token.txt`), ou que le propriétaire soit `65532` avec `600`, puis `docker compose up -d --force-recreate revisor`. `chmod 644` règle aussi le problème, mais ouvre le token à toute la machine : uniquement avec un token factice (9.8.4).

**Dans la commande : `--wait` qui ne se termine pas bien.**

```text
container curso-docker-fig09-prueba-caido-1 is unhealthy
```

(Dans ton dossier, `curso-docker-prueba-caido-1`.) Code `1`, même si tu ne nommes que le `revisor`. Ce n'est pas une défaillance du système : c'est `--wait` qui attend aussi un service qui ne peut pas être sain. Dans ce projet, `up -d` puis attendre la santé du `revisor`. Dans un projet sans services qui échouent volontairement, ce message est bel et bien une alarme : il te dit exactement quel conteneur examiner.

**Et une erreur secondaire, à la construction** :

```text
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
```

(Dans ton dossier, le tag sera le tien, `curso-docker-prueba:1.0.0`, et le service peut être n'importe lequel des trois.) Plusieurs services avec `build` et la même `image`. Elle apparaît parfois, pas toujours : dans l'exécution de 9.11, à 3 tentatives sur 5. Correction : `build` dans un seul service, `pull_policy: never` dans les autres.

## L'habitude de sécurité de la leçon

**Le `compose.yaml` naît avec tout ce qui précède, et ses secrets vivent hors du fichier.** C'est l'habitude que le README du cours attribue à cette leçon, et elle se vérifie avec une liste que tu peux appliquer à n'importe quel `compose.yaml`, le tien ou celui d'un autre, en lisant son `docker compose config` :

- Chaque port publié porte `host_ip: 127.0.0.1` (Leçon 2), et ce qui n'a pas besoin de port n'en publie pas.
- Chaque service porte `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges` et `init: true` (Leçon 7), ainsi que des limites de mémoire, de CPU et de processus (Leçon 2).
- Les images portent une version, jamais `latest` (Leçon 3), et celles que tu construis toi-même ne sont pas cherchées sur internet (`pull_policy: never`).
- Ce qui écrit, écrit dans un volume nommé monté exactement là où il le faut (Leçon 8).
- Ce qui n'a pas besoin d'internet vit dans un réseau `internal: true`, et il n'y a pas de `network_mode: host` (Leçon 8).
- Aucune valeur secrète dans `environment`, dans `build.args` ni dans le fichier lui-même : les secrets vont dans `secrets:`, à partir de fichiers qui ne sont pas versionnés dans le dépôt, et un `grep` de la valeur dans `docker compose config` et dans `docker inspect` donne zéro (Leçon 6 et celle-ci).

L'accident qu'elle évite est celui de la scène : que le système qui tourne ne soit pas celui que tu as testé. Un fichier durci une fois est durci pour tous ceux qui l'utilisent ; six commandes durcies dépendent du fait que personne ne copie la mauvaise.

## Ce qui se fait de travers

**Écrire `version:` en haut du fichier.** C'est obsolète et ne produit qu'un avertissement. Et cela trahit presque toujours que le reste du fichier a été copié d'un vieux tutoriel : relis-le avec plus d'attention.

**Des ports sans `127.0.0.1`.** `"8080:8080"` dans un `compose.yaml` est le `-p 8080:8080` de la Leçon 2 : le port ouvert à tout ton réseau. C'est la première chose qui se perd quand on copie un exemple.

**Retirer `read_only` « parce que ça échoue ».** Si ça échoue, le programme écrit quelque part que tu n'avais pas prévu. Trouve où (l'erreur te le dit) et monte-y un volume ou un `tmpfs`.

**`depends_on` sans condition pour quelque chose qui doit être prêt.** La forme courte attend seulement que le conteneur tourne. Si ton service a besoin qu'un autre soit sain, `condition: service_healthy`, et que cet autre ait son contrôle de santé.

**`service_healthy` pour tout.** Avec un service qui ne sera jamais sain, celui qui en dépend ne démarre jamais. Ne demande la santé qu'à ce qui en a besoin.

**Le token dans `environment:` ou dans un `.env`.** Il reste dans `docker inspect` pour n'importe qui du groupe `docker`. C'est pour cela que `secrets:` existe.

**Se fier à `uid`, `gid` et `mode` d'un secret de fichier.** Compose les ignore en silence. La permission est celle du fichier sur ta machine.

**`build` dans plusieurs services avec la même `image`.** Une situation de compétition (race condition) que l'un des deux camps gagne « presque toujours ». Construis dans un seul service et utilise l'image dans les autres.

**`docker compose down --volumes` par habitude.** Il supprime le rapport. Utilise-le quand tu veux repartir de zéro, pas pour arrêter.

**Supprimer manuellement avec `docker rm` ce que Compose a créé.** Ça marche, mais Compose ne sait plus dans quel état se trouve le tout. Ce qui est créé avec Compose s'arrête avec `docker compose stop` ou `docker compose down`.

**Deux projets avec le même nom.** Deux `compose.yaml` avec `name: curso-docker`, même dans des dossiers différents, s'écrasent mutuellement : Compose croit que les conteneurs de l'un appartiennent à l'autre. Un projet, un nom.

## Exercices

Fais-les dans l'ordre. Avant d'exécuter chacun, écris dans ton [journal de bord](bitacora.md) ce que tu crois qu'il va se passer ; comparer ensuite est la moitié de l'apprentissage. À la fin, laisse ton projet avec le fichier final et arrête-le avec `docker compose down` (sans `--volumes`, si tu veux conserver le rapport).

### Exercice 1 — Traduis un `docker run`

Voici la commande du service de test de la Leçon 8, section 8.10.3 :

```text
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Écris le service Compose équivalent, nommé `prueba`, sans regarder `fig09_01.compose.yaml`. Ensuite, dis : quelle option de la commande n'a **pas** de clé dans ton service, et pourquoi ? Qu'est-ce qui devrait exister dans le fichier, en dehors du service, pour que ton `networks` fonctionne ?

### Exercice 2 — Que recrée Compose ?

Avec le système final actif, prédis, pour chaque changement pris séparément, quels conteneurs afficheront `Running` et lesquels `Recreated` lors du prochain `docker compose up -d`. Ensuite, vérifie, et remets le fichier dans sa forme finale avant le suivant :

1. Tu changes la durée de `lento` dans `REVISOR_SERVICIOS` de `5s` à `4s`.
2. Tu changes `mem_limit: 32m` en `mem_limit: 24m` dans l'ancre `x-prueba`.
3. Tu ne changes pas le fichier, mais tu fais `chmod 600 secretos/revisor_token.txt`.

Question supplémentaire : dans le cas 3, que devrais-tu faire pour voir l'erreur de 9.10, et quelle commande l'annule ?

### Exercice 3 — Diagnostique sans exécuter

Une collègue t'envoie ceci, copié depuis son terminal (c'est le bloc « Ejercicio 3 » de `fig09_10.sh`, donc les noms sont les noms auxiliaires et le numéro du fichier temporaire est masqué). Le `revisor` dit `healthy` et pourtant son rapport ne fonctionne pas :

```text
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

1. Les `(unhealthy)` de `prueba-caido` et `prueba-lento` sont-ils le problème ? Pourquoi ?
2. Quelles lignes manquent à coup sûr à son `compose.yaml` ? Avec quelle commande le vérifierais-tu sans ouvrir le fichier ?
3. Qu'est-ce qui te dit que le token est, lui, **bien** en place ?

### Exercice 4 — Ton fichier face à celui du guide

Prends le `compose.yaml` du guide officiel Python de la section 9.13 et dresse la liste de **tout** ce que ton fichier final a et que celui-là n'a pas, appliquée au service `server`. Pour chaque différence, dis quelle leçon du cours l'explique et quel risque elle ferme. Ensuite, réponds : y a-t-il quelque chose dans le fichier du guide que tu n'aurais **pas** à changer ?

## Solutions

Les solutions qui disent « mesuré » proviennent du script `fig09_10.sh`, qui fait chaque changement sous tes yeux avec `sed`, le vérifie et l'annule. Sa sortie complète :

```text
$ ./fig09_10.sh
== Ejercicio 1. Un servicio en una red que no está declarada arriba
$ docker compose config --quiet
service "prueba-lento" refers to undefined network otra: invalid compose project
[código de salida: 1]

== Ejercicio 2.1. lento: de 5s a 4s en REVISOR_SERVICIOS
$ cambios
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started

== Ejercicio 2.2. mem_limit: de 32m a 24m en el ancla x-prueba
$ docker compose config | grep mem_limit
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "67108864"
  mem_limit: 24m
$ cambios
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-prueba-sano-1 Recreated
Container curso-docker-fig09-prueba-lento-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-caido-1 Started

== Ejercicio 2.3. Sin cambiar el archivo: chmod 600 al token
$ cambios
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Running
$ tabla | head -2
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
$ docker compose restart revisor 2>&1 | eventos | grep -v Restarting
Container curso-docker-fig09-revisor-1 Started
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 Started'
Container curso-docker-fig09-revisor-1 Started
revisor: healthy

== Ejercicio 3. El revisor sin volumen en /datos, con los cuatro servicios
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
$ docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes
[código de salida: 1]
$ docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-fig09-revisor-1
/run/secrets/revisor_token 
```

### Solution 1

```yaml
  prueba:
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
```

C'est le service de `fig09_01.compose.yaml`, sauf le `build` (que la commande de la Leçon 8 n'apportait pas, parce que l'image existait déjà). L'option sans clé est `--name curso-docker-prueba` : le nom du conteneur est attribué par Compose (`curso-docker-prueba-1` dans ton dossier), et les autres le trouvent par le nom du **service**, `prueba`. `-d` n'a pas de clé non plus : c'est une option de la commande (`docker compose up -d`), pas du service. Pour que `networks: [interna]` fonctionne, le réseau doit être déclaré en haut, dans `networks:` ; sinon, le fichier n'est pas valide. Et pour que ce soit toujours le réseau sans sortie de la Leçon 8, cette déclaration porte `internal: true`. Mesuré : avec l'ancre pointant vers un réseau `otra` qui n'existe pas en haut, `docker compose config --quiet` répond `service "prueba-lento" refers to undefined network otra: invalid compose project` et se termine avec `1` (il nomme l'une des trois copies qui héritent de l'ancre ; ce peut être une autre dans ton exécution). C'est le genre d'erreur que `config` attrape avant de créer quoi que ce soit.

### Solution 2

Mesuré (blocs « Ejercicio 2 » de `fig09_10.sh`) :

1. **Seul le `revisor` est recréé.** `REVISOR_SERVICIOS` fait partie de sa configuration ; les services de test ne changent pas et affichent `Running`. C'est la même chose que ce que tu as vu dans le bloc 2 de `fig09_03.sh`, avec un autre changement.
2. **Les trois copies du service de test sont recréées**, et le `revisor` reste en `Running`. Pour Compose, ce qui compte est le résultat de la copie de l'ancre dans les trois services, donc modifier l'ancre revient à modifier les trois. `docker compose config | grep mem_limit` le confirme avant de démarrer : trois fois `25165824` (24 Mo en octets) et une fois `67108864` (le `revisor`). La dernière ligne, `mem_limit: 24m` sans guillemets et avec moins d'indentation, est `x-prueba` lui-même : `config` conserve les champs `x-` dans sa sortie, même s'il ne les utilise pas pour créer quoi que ce soit.
3. **Rien n'est recréé** : les quatre en `Running`, et le tableau continue de s'afficher. La permission d'un fichier de ta machine ne fait pas partie de la configuration que Compose compare, et le `revisor` a déjà lu son token au démarrage, donc il continue de fonctionner. Pour voir l'erreur de 9.10, il faut le forcer à redémarrer : `docker compose restart revisor` dit `Started`, et trois secondes plus tard `docker inspect` dit `Status=restarting ExitCode=1`. Tu l'annules en remettant la permission précédente (dans le dossier temporaire du script, `644` avec le token factice ; dans le tien, le `640` avec le groupe `65532` de 9.8.4) suivie de `docker compose up -d --force-recreate revisor`, la même commande que dans 9.10. La leçon de ce cas : une erreur de permissions peut rester **dormante** pendant des jours, jusqu'au redémarrage suivant.

### Solution 3

1. **Non.** Ils sont `unhealthy` parce qu'ils échouent volontairement : le service en panne répond `503` et le lent met 3 s alors que son contrôle exige moins de 2. C'est attendu, et c'est pourquoi le `revisor` ne demande `service_healthy` qu'à la saine. Le `revisor` est `healthy` parce que `/salud` n'écrit rien.
2. Il manque le volume du `revisor` dans `/datos` : les deux lignes `volumes:` et `- reportes:/datos` du service. C'est le bloc 1 de `fig09_03.sh`. Tu le vérifies sans ouvrir le fichier avec `docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes`, qui ne trouve rien et se termine avec `1` ; ou, sur le conteneur, avec `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-revisor-1`, qui affiche `/run/secrets/revisor_token` et n'affiche pas `/datos`. Les deux choses figurent dans la sortie de `fig09_10.sh`.
3. Le fait que la réponse n'est **pas** un `401`. Avec un token erroné ou absent, le `revisor` répond `{"error":"falta el token o no es válido"}` avant de rien tenter. Ici, il a passé cette vérification et a échoué à l'enregistrement. Et si le fichier du token était en `600`, le `revisor` ne serait même pas `Up` : il serait en train de redémarrer en boucle (9.10).

### Solution 4

Ce que ton fichier a et que celui du guide n'a pas, dans le service :

- **`127.0.0.1` dans le port** (Leçon 2). `8000:8000` publie sur toutes les interfaces de ta machine ; n'importe qui sur ton réseau atteint le service.
- **`image:` avec un nom et une version** (Leçon 3). Sans elle, c'est Compose qui décide du nom de l'image, et il ne dit pas quelle version tourne.
- **`read_only`, `cap_drop`, `no-new-privileges` et `init`** (Leçon 7). Sans eux, celui qui prend le contrôle du processus peut écrire sur le disque du conteneur, utiliser les capacités de `root` que Docker laisse par défaut et gagner des privilèges avec un programme *setuid* ; et un programme qui ne sait pas être le processus 1 ne s'arrête pas correctement.
- **Des limites de mémoire, de CPU et de processus** (Leçon 2). Sans elles, une erreur du programme peut prendre toute la machine.
- **`restart`** (Leçon 7). Sans politique, si le processus meurt, il reste mort.
- **Des réseaux propres, avec l'interne sans sortie** (Leçon 8). Le guide utilise le réseau par défaut du projet, avec accès à internet pour tous.
- **Un volume nommé là où il écrit** (Leçon 8). Dans cet exemple, ce n'est pas nécessaire parce que l'application n'enregistre rien ; le jour où elle enregistrera, elle en aura besoin.
- **`secrets:`** (Leçon 6 et celle-ci). Le guide dont provient l'exemple ajoute plus loin une base de données avec son mot de passe comme secret : le schéma est le même.

Ce que tu ne changerais pas : `build` avec `context: .`, qui est exactement ce que fait ton `revisor`, et l'absence de `version:`. Et une précision équitable : l'étape finale du Dockerfile de ce guide s'exécute sans `root` par défaut, comme le dit la page elle-même, donc le `USER` de la Leçon 3 est réglé dans son Dockerfile, pas dans le `compose.yaml`. Un fichier généré n'est pas mauvais : c'est un point de départ, et ton travail est de l'amener jusqu'ici.

## Comment je sais que j'ai réussi

Coche chaque point uniquement si tu peux le faire **sans relire le texte** :

- [ ] Dans ton dossier `revisor/`, `docker compose config --quiet && echo 'compose.yaml válido'` affiche `compose.yaml válido`, et `grep -c '^version' compose.yaml` donne `0`.
- [ ] `docker compose up -d --build` démarre les quatre services à partir de zéro, `docker compose ps` montre `curso-docker-revisor-1` en `(healthy)` avec `127.0.0.1:8080->8080/tcp`, et dans les événements de `up`, `prueba-sano-1 Healthy` apparaît **avant** `revisor-1 Started`.
- [ ] Le tableau du `revisor`, demandé avec le token, montre `caido FALLA`, `lento LENTO` et `sano OK`, sans que tu aies changé un seul mode manuellement.
- [ ] `docker inspect curso-docker-revisor-1 | grep -c "$(cat secretos/revisor_token.txt)"` donne `0`, et de même avec `docker compose config`.
- [ ] Tu expliques pourquoi le `revisor` n'attend avec `service_healthy` que `prueba-sano`, en utilisant les mots *santé*, *503* et *2 secondes*.
- [ ] Tu provoques le `read-only file system` en retirant le volume de `/datos`, et le `permission denied` du secret avec `chmod 600`, et tu expliques pourquoi `uid`, `gid` et `mode` ne l'évitent pas.
- [ ] Avec `stat -c '%a %U:%G'` et `sudo -u nobody cat`, tu vérifies que ton `secretos/revisor_token.txt` n'est **pas** lisible par un autre compte, et que le `revisor`, lui, le lit (`640` avec le groupe `65532`, ou `600` avec le propriétaire `65532`) ; et `git check-ignore -v secretos/revisor_token.txt` indique que le `.gitignore` de ton projet le couvre.
- [ ] Après `docker compose down` (sans `--volumes`), `docker run --rm -v curso-docker_reportes:/datos:ro alpine:3.24.2 ls -ln /datos` montre `reporte.json` appartenant à `65532`.
- [ ] `docker compose stop revisor` prend moins d'une seconde et laisse `ExitCode=0`.
- [ ] Tu exécutes les scripts de [`programas/09-compose/`](../programas/09-compose) (avec ton projet arrêté, ou avec un autre port : `PUERTO=18080 ./fig09_05.sh` ; la fonction `nombres` réécrit le port dans la sortie) et tes sorties coïncident avec celles de cette leçon, sauf les durées, les dates, le numéro du fichier temporaire, l'ordre des événements simultanés, le service que nomme l'erreur de l'Exercice 1 et les tentatives et services de la collision de 9.11. Et à la fin, `docker ps -a --filter name=fig09`, `docker volume ls --filter name=fig09` et `docker network ls --filter name=fig09` n'affichent rien.

## Résumé

Réponds sans regarder la leçon :

1. Quelle différence y a-t-il entre un service et un conteneur, et quel nom les autres conteneurs utilisent-ils pour en trouver un ?
2. D'où vient le nom d'un projet, dans quel ordre se décide-t-il, et comment se voit-il dans les noms de conteneurs, de réseaux et de volumes ?
3. Que fait `docker compose config`, et qu'est-ce qu'il t'a appris sur `depends_on: [prueba]` et sur `"127.0.0.1:8080:8080"` ?
4. Pourquoi demander `docker compose up -d` deux fois ne fait rien la seconde fois, et que fait-il quand tu modifies un service ?
5. Pourquoi le `revisor` avec `read_only: true` a-t-il toujours besoin de quelque chose de monté dans `/datos` ?
6. À quoi servent ensemble un champ `x-` et une ancre YAML ?
7. Quelle différence y a-t-il entre `service_started` et `service_healthy`, et pourquoi ne peut-on pas demander `service_healthy` à `prueba-caido` ?
8. Où apparaît un secret Compose à l'intérieur du conteneur, et pourquoi un fichier en `600` donne-t-il `permission denied` même si tu déclares `uid`, `gid` et `mode` ? Qui peut lire le même fichier avec `644`, et comment le laisser pour que le `revisor` et toi le lisiez, mais personne d'autre ?
9. Pourquoi un seul service de test porte-t-il `build`, et que fait `pull_policy: never` dans les deux autres ?
10. Que supprime `docker compose down`, qu'ajoute `--volumes`, et pourquoi `up --wait` échoue-t-il dans ce projet alors que tout fonctionne ?

## Sources

Toutes consultées le 21 octobre 2026.

- [Docker, « Docker Compose »](https://docs.docker.com/compose/) : ce qu'est Compose.
- [Docker, « How Compose works »](https://docs.docker.com/compose/intro/compose-application-model/) : le nom `compose.yaml` (préféré) et les noms hérités ; ce qu'est un projet ; services, réseaux, volumes, configurations et secrets.
- [Spécification Compose](https://docs.docker.com/reference/compose-file/) : le document qui définit les clés du fichier et ses éléments de premier niveau.
- [Spécification, `version` et `name`](https://docs.docker.com/reference/compose-file/version-and-name/) : que `version` est purement informatif et produit un avertissement d'obsolescence ; `name` comme nom du projet.
- [Référence des services Compose](https://docs.docker.com/reference/compose-file/services/) : `depends_on` et ses trois conditions ; `pull_policy: never` ; `read_only`, `cap_drop`, `security_opt` et les trois formes de `no-new-privileges` ; `init` ; `mem_limit`, `cpus`, `pids_limit` ; `restart` ; `image` à côté de `build` ; la forme longue de `secrets` et le fait qu'avec un fichier comme source, `uid`, `gid` et `mode` sont ignorés en silence.
- [Spécification, extensions](https://docs.docker.com/reference/compose-file/extension/) : que Compose ignore les champs qui commencent par `x-` et qu'ils servent à réutiliser de la configuration.
- [Spécification, fragments](https://docs.docker.com/reference/compose-file/fragments/) : ancres, alias et la clé de fusion `<<` ; que la fusion ne s'applique qu'aux mappings ; `environment` sous forme de map quand on utilise des fragments.
- [Docker, « Specify a project name »](https://docs.docker.com/compose/how-tos/project-name/) : l'ordre dans lequel se décide le nom du projet, les caractères admis et le fait qu'il sert à isoler les environnements.
- [Docker, « Networking in Compose »](https://docs.docker.com/compose/how-tos/networking/) : le réseau `<projet>_default`, le nom de service dans le DNS et les réseaux propres avec `networks`.
- [Docker, « Control startup order »](https://docs.docker.com/compose/how-tos/startup-order/) : que Compose n'attend pas qu'un conteneur soit prêt, seulement en cours d'exécution ; `service_healthy` ; l'ordre d'arrêt par dépendances ; `restart: true` dans `depends_on`.
- [Docker, « Secrets in Compose »](https://docs.docker.com/compose/how-tos/use-secrets/) : ce qu'est un secret, le chemin `/run/secrets/<nom>`, le fait que Docker crée un montage (`bind mount`) à ce chemin, que l'accès est contrôlé par les permissions normales du système de fichiers et que seul le service à qui il est accordé le reçoit.
- [Spécification, `secrets` de premier niveau](https://docs.docker.com/reference/compose-file/secrets/) : que le secret est créé avec le contenu du fichier de `file` (ou avec une variable d'environnement de `environment`).
- [Référence de `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/) : qu'il affiche le modèle qui sera appliqué, sous forme canonique ; `--quiet`, `--services`, `--volumes`.
- [Référence de `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/) : ce que fait `up` ; qu'il recrée quand la configuration ou l'image changent et conserve les volumes ; `-d`, `--build`, `--wait`, `--wait-timeout`, `--no-recreate`.
- [Référence de `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/) : ce qu'il supprime par défaut et ce qu'ajoute `--volumes`.
- [Référence de `docker init`](https://docs.docker.com/reference/cli/docker/init/) : qu'il est fourni par Docker Desktop, les fichiers qu'il crée et ses modèles.
- [Docker, « Containerize a Python application »](https://docs.docker.com/guides/python/containerize/) : le `compose.yaml` à un service utilisé en 9.13 et dans l'Exercice 4.
- [Docker, « Retired features »](https://docs.docker.com/retired/) : que Compose v1 n'est plus maintenu et qu'il faut migrer vers Compose v2.
- [Docker, « Announcing Compose V2 General Availability »](https://www.docker.com/blog/announcing-compose-v2-general-availability/) : le passage du tiret bas au tiret dans les noms des conteneurs et l'avertissement de ne pas en dépendre.
- [Spécification, `models`](https://docs.docker.com/reference/compose-file/models/) : l'élément de premier niveau pour les modèles d'IA, mentionné en 9.1.1.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : les versions et dates de « À propos des exécutions ».
- [Colima](https://github.com/abiosoft/colima) : l'outil avec lequel les programmes ont été exécutés sous macOS.

### Termes de cette leçon

| | |
|---|---|
| **ancre et alias** (YAML) | `&nom` marque un bloc ; `*nom` y renvoie ; `<<: *nom` copie ses clés dans un autre mapping |
| **bloc replié** (YAML) | `>-` : réunit plusieurs lignes en une seule, avec des espaces, et supprime le saut final |
| **champ `x-`** | champ de premier niveau que Compose ignore ; sert à conserver des blocs réutilisables |
| **Compose** | l'outil (`docker compose`) qui lit un `compose.yaml` et crée, recrée ou supprime ce qu'il faut pour que ce qu'il décrit existe |
| **`depends_on`** | ordre de démarrage entre services, avec une condition : `service_started`, `service_healthy` ou `service_completed_successfully` |
| **forme canonique** | la version longue et complète du fichier, avec toutes les valeurs par défaut écrites ; `docker compose config` l'affiche |
| **projet** | un déploiement d'un `compose.yaml` ; son nom est placé devant tout ce que Compose crée |
| **secret Compose** | fichier que Compose monte en lecture seule dans `/run/secrets/<nom>`, uniquement dans les services qui le demandent |
| **service** | la recette d'un conteneur dans le `compose.yaml` ; son nom est celui utilisé dans le DNS du projet |

---

**Suivante :** [Leçon 10 — Livrer l'image](10-entregar-la-imagen.md)
