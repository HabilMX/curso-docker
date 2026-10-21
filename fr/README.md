# Cours de Docker — empaquette un service et exploite-le comme on le fait vraiment

**Par Dorian Chávez, fondateur de Hábil et architecte d'intégration.**

**À qui il s'adresse :** à qui a déjà programmé quelque chose —le `revisor` des cours de [Go](https://www.habil.mx/fr/cours/go/), de [Rust](https://www.habil.mx/fr/cours/rust/) ou de [TypeScript](https://www.habil.mx/fr/cours/typescript/) de Hábil, ou son propre service— et a besoin de l'empaqueter, de le faire tourner et de l'exploiter dans des conteneurs sans copier des commandes à l'aveugle. Niveau intermédiaire : on suppose que tu utilises un terminal avec aisance et que tu sais ce qu'est un serveur HTTP. On ne suppose pas que tu aies déjà touché à Docker : chaque concept est expliqué au moment où il apparaît, et l'on explique pourquoi il existe, pas seulement comment il s'écrit. Et il n'est pas nécessaire de programmer quoi que ce soit de nouveau : le cours te livre le service déjà fait.

**Ce que tu sauras faire à la fin :** transformer un service en une petite image, sans privilèges et reproductible ; le faire tourner avec des limites, un contrôle de santé (health check) et un arrêt propre ; gérer sa configuration et ses secrets sans les laisser à l'intérieur de l'image ; démarrer plusieurs conteneurs qui se parlent par leur nom avec une seule commande ; et lire ce que Docker te dit quand quelque chose échoue, au lieu de chercher la réponse à l'aveugle.

**Où cela continue :** ce cours est l'étape préalable au [cours de **Kubernetes avec kind**](https://www.habil.mx/fr/cours/kubernetes/) de Hábil, qui reprend l'image avec laquelle tu termines ici et la déploie, la configure, la met à l'échelle et la protège dans un cluster local.

**Ce dont tu as besoin avant de commencer :** un ordinateur avec Linux Mint 22.x et les droits d'administrateur (`sudo`). La [Leçon 1](01-instalacion.md) installe Docker de zéro. Si tu viens du cours de Go, de Rust ou de TypeScript, tu connais déjà le problème que résout le `revisor` ; sinon, la leçon 0 le présente en deux paragraphes.

## Le projet que tu vas construire

Le **`revisor`** : un serveur HTTP qui interroge une liste de services **en même temps** et livre, par `GET /api/estados`, un rapport avec le nom, l'état et le temps de réponse de chacun ; et par `GET /salud`, la réponse courte qui dit si le processus lui-même est en vie. Il se configure avec des variables d'environnement (le port, la liste de services, le chemin où il enregistre le rapport et un jeton d'accès). Le serveur du `revisor` est écrit en **Go** (il vient du cours de Go de Hábil) et compile en un binaire statique ; il écoute sur le port 8080, répond à `GET /salud` et `GET /api/estados`, se configure par variables d'environnement et embarque une sous-commande `healthcheck` pour pouvoir se surveiller lui-même sans `curl`. Tu n'as pas besoin de connaître Go : le cours te le livre et toi, tu l'empaquettes.

Le cours te le livre déjà fait, accompagné d'un **service de test qui échoue exprès** selon trois modes —sain, lent et en panne—. Avec ces deux éléments, tu fais tout le travail du cours : empaqueter, durcir, configurer, ajouter un contrôle de santé, persister les données, connecter et livrer. C'est le même problème que dans les cours de Go, de Rust et de TypeScript de Hábil : tu sais déjà ce que fait le `revisor`, si bien que toute ton attention reste sur ce qui est nouveau, c'est-à-dire **comment on le distribue et comment on l'exploite**.

## Les onze leçons

| Leçon | | Ce que tu construis | Ce que tu apprends |
|---|---|---|---|
| 0 | [Ce qu'est un conteneur et ce qu'il n'est PAS](00-que-es-un-contenedor.md) | rien pour l'instant (lecture) | un conteneur est un processus isolé, pas une machine virtuelle ; image contre conteneur ; le client et le daemon ; ce qui est partagé avec l'hôte et pourquoi c'est déterminant pour la sécurité |
| 1 | [Installer Docker sur ton Linux Mint](01-instalacion.md) | l'environnement et ton premier conteneur | Docker Engine depuis le dépôt officiel ; Mint n'est pas une plateforme officielle et que faire ; retirer les paquets en conflit ; le groupe `docker` équivaut à `root` |
| 2 | [Les conteneurs au quotidien](02-contenedores-dia-a-dia.md) | le service de test qui tourne, interrogé et nettoyé | `run`, `ps`, `logs`, `exec`, `stop`, `rm`, `inspect` ; publier des ports uniquement sur `127.0.0.1` ; limites de mémoire et de CPU ; ne rien laisser traîner |
| 3 | [Ton premier Dockerfile](03-primer-dockerfile.md) | `curso-docker-revisor:1.x.0` en une seule étape | instructions du Dockerfile ; forme *exec* contre forme *shell* ; `.dockerignore` ; `USER` ; tags versionnés ; `docker build --check` |
| 4 | [Couches, cache et contexte](04-capas-cache-contexto.md) | la même image, reconstruite en quelques secondes | comment se construit une image couche par couche ; l'ordre des instructions ; `--progress=plain` et `docker history` ; cache de compilation (`--mount=type=cache`) ; ce qui voyage dans le contexte |
| 5 | [Multi-stage : des gigaoctets aux mégaoctets](05-multi-stage.md) | l'image finale minimale et sans privilèges | étapes de compilation, de tests et finale ; base minimale sans shell ; version et *digest* de la base ; le binaire qui ne démarre pas parce qu'il n'est pas statique |
| 6 | [Configuration et secrets](06-configuracion-y-secretos.md) | le `revisor` configuré sans reconstruire | variables d'environnement ; `ARG` contre `ENV` ; secrets de construction ; secrets à l'exécution par fichier ; voir de tes yeux ce qui reste à l'intérieur de l'image |
| 7 | [Contrôle de santé et cycle de vie](07-salud-y-ciclo-de-vida.md) | un conteneur qui dit comment il va et meurt proprement | PID 1 et signaux ; le délai de `docker stop` ; `HEALTHCHECK` sans `curl` ; politiques de redémarrage ; système de fichiers en lecture seule ; `--cap-drop` ; `no-new-privileges` |
| 8 | [Volumes et réseaux](08-volumenes-y-redes.md) | le rapport qui survit et deux conteneurs qui se parlent | volumes nommés, *bind mounts* et `tmpfs` ; le propriétaire des fichiers avec un utilisateur sans privilèges ; réseaux définis par l'utilisateur ; DNS par nom ; réseaux internes |
| 9 | [Compose : le système complet](09-compose.md) | `compose.yaml` avec le `revisor` et son service qui échoue | services, réseaux, volumes et secrets dans un fichier ; `depends_on` avec `service_healthy` ; `compose config` ; comparer ton fichier avec celui de `docker init` |
| 10 | [Livrer l'image](10-entregar-la-imagen.md) | l'image publiée, vérifiée et prête pour Kubernetes | tags et *digest* ; registre local ; analyse de vulnérabilités avec Trivy ; nomenclature logicielle (SBOM) et provenance ; plusieurs plateformes ; le pont vers `kind load docker-image` |

**Noms avec préfixe.** Tout ce que le cours crée sur ta machine (images, conteneurs, réseaux, volumes) porte le préfixe `curso-docker-` ; c'est pourquoi l'image de la leçon 3 s'appelle `curso-docker-revisor:1.x.0` et non `revisor`. Ainsi elle n'entre en conflit avec rien de ce que tu as déjà, et tu peux supprimer uniquement ce qui appartient au cours sans toucher au reste.

À la fin de chaque leçon, il y a des exercices avec leurs solutions. Et le [journal de bord](bitacora.md) est à toi : note-y ce qui t'a donné du mal.

## Trois principes qui traversent tout le cours

**La sécurité n'est pas une leçon, c'est une habitude.** Il n'y a pas de module final de sécurité. Il y a une habitude par leçon, et chacune se pratique sur le `revisor` et non dans un exemple à part :

| Leçon | L'habitude qui s'installe |
|---|---|
| 0 | savoir ce qu'un conteneur partage avec la machine (le noyau) et ce qu'il ne partage pas |
| 1 | le groupe `docker` équivaut à `root` : on l'accorde en connaissance de cause |
| 2 | ports publiés uniquement sur `127.0.0.1` ; limites de mémoire et de CPU ; jamais `--privileged` ni le *socket* de Docker à l'intérieur d'un conteneur |
| 3 | le premier Dockerfile contient déjà `USER` ; `.dockerignore` dès le premier jour ; tags versionnés, jamais `latest` |
| 4 | le contexte de construction n'emporte ni `.git`, ni `.env`, ni clés ; l'outil de vérification du Dockerfile s'exécute toujours |
| 5 | base minimale et sans shell ; la base est figée par version et par *digest* ; l'étape de tests s'exécute avant d'empaqueter |
| 6 | les secrets ne passent ni par `ARG` ni par `ENV` ; on vérifie avec `docker history` et `docker inspect` qu'ils n'y sont pas restés |
| 7 | système de fichiers en lecture seule, sans capacités inutilisées, sans élévation de privilèges, avec un `init` |
| 8 | volumes avec le bon propriétaire ; réseaux internes ; jamais le réseau de l'hôte |
| 9 | le `compose.yaml` final naît avec tout ce qui précède, et ses secrets vivent hors du fichier |
| 10 | ce qui est publié est analysé, apporte sa nomenclature logicielle (SBOM) et est référencé par *digest* |

Un sujet qu'on laisse pour la fin est un sujet qu'on n'apprend pas.

**Un conteneur « qui tourne » n'est pas un service sain.** Presque toutes les pannes d'exploitation dans ce domaine naissent de la confusion entre les deux choses : le processus existe, mais il ne répond pas. Le service de test échoue exprès et chaque leçon t'apprend à distinguer **ce que Docker croit de ce qui se passe vraiment**.

**On n'enseigne que ce qui est en vigueur, et ce qui est obsolète est nommé pour le reconnaître.** Compose est `docker compose` (le *plugin*), le fichier s'appelle `compose.yaml` et ne comporte pas `version:` ; `MAINTAINER` est déprécié. Quand quelque chose d'ancien apparaît dans un tutoriel sur lequel tu tomberas de toute façon, le cours te dit ce que c'est et pourquoi cela n'a plus cours. Et chaque version est donnée avec sa date : celles de ce cours ont été relevées le 7 octobre 2026 (Docker Engine 29.8.2, Compose v5.6.0).

## Comment savoir que tu as terminé

Le cours ne se termine pas quand tu as lu la leçon 10, mais quand ton projet remplit ces six conditions. Les chiffres sont des objectifs de conception : on les mesure et on les ajuste lors de l'écriture des leçons, et chaque leçon répète celui qui la concerne une fois mesuré.

1. **`docker compose up` démarre tout de zéro** et le rapport affiche le service de test en panne comme `FALLA`, sans que tu aies à redémarrer quoi que ce soit manuellement.
2. **L'image finale pèse quelques dizaines de mégaoctets** (objectif), pas des centaines, n'embarque ni shell ni compilateur, et **ne tourne pas en tant que `root`** (tu le vérifies avec `docker exec` et avec `docker inspect`).
3. **Aucun secret n'apparaît** dans `docker history`, dans `docker inspect` ni dans les variables d'environnement du conteneur.
4. **`docker stop` arrête le conteneur en quelques secondes** (objectif : moins de deux), parce que le processus reçoit le signal et s'éteint proprement ; et `docker ps` affiche `(healthy)` et, quand on casse le service, `(unhealthy)`.
5. **Le rapport survit à `docker rm`** et le `revisor` trouve l'autre conteneur par son nom.
6. **L'image publiée est référencée par *digest***, passe l'analyse de Trivy avec le seuil que tu as fixé et se charge dans un cluster `kind` sans une seule erreur de téléchargement.
