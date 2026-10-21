# Journal de bord

Ce carnet t'appartient. C'est lui qui fait de ce cours *ton* cours.

**Ce qu'il faut noter :** ce que tu n'as pas compris du premier coup · le message d'erreur que tu n'as pas su lire · ce que tu croyais savoir des conteneurs et qui s'est avéré faux · ce qui t'a surpris · les chiffres que tu as mesurés (tailles, temps).

**Pourquoi c'est important :** dans deux semaines, tu ne te souviendras plus de ce qui t'a donné du mal. Et c'est exactement ce qu'il faut réviser.

---

## Leçon 0 — Ce qu'est un conteneur et ce qu'il n'est PAS

_date :_

- Ce que je croyais qu'était un conteneur :
- Avec mes mots, la différence entre image et conteneur :
- Ce qui m'a surpris :

## Leçon 1 — Installer Docker sur ton Linux Mint

_date :_

- Versions que j'ai obtenues (`docker version`, `docker compose version`) :
- L'erreur de permissions que j'ai provoquée exprès et comment je l'ai lue :
- Avais-je des paquets en conflit ? Lesquels :

## Leçon 2 — Conteneurs au quotidien

_date :_

- Un conteneur que j'ai laissé tourner sans m'en rendre compte :
- Ce qui change entre `-p 8080:8080` et `-p 127.0.0.1:8080:8080` (je l'ai vérifié avec `ss -ltn`) :

## Leçon 3 — Ton premier Dockerfile

_date :_

- Taille de `revisor:1.0.0` : ____ MB
- Ce que m'a signalé `docker build --check` :
- Combien de temps prend `docker stop` avec la forme *shell* et avec la forme *exec* : ____ s et ____ s

## Leçon 4 — Couches, cache et contexte

_date :_

- Reconstruction avant le réordonnancement : ____ s → après : ____ s
- Taille du contexte avec et sans `.dockerignore` :
- La couche la plus lourde de mon image (`docker history`) :

## Leçon 5 — Multi-stage : des gigaoctets aux mégaoctets

_date :_

- Taille avant : ____ → après : ____
- L'erreur « no such file or directory » que j'ai vue avec le binaire non statique et pourquoi :
- Ce que j'ai épinglé pour l'image de base : version, *digest* ou les deux :

## Leçon 6 — Configuration et secrets

_date :_

- Un secret que j'ai mis dans `ENV` et où je l'ai trouvé ensuite :
- Comment je l'ai passé au `revisor` de la bonne façon :

## Leçon 7 — Contrôle de santé et cycle de vie

_date :_

- États que j'ai vus dans le healthcheck (`starting`, `healthy`, `unhealthy`) et ce qui les a provoqués :
- Ce qui a cassé quand j'ai mis le système de fichiers en lecture seule et comment je l'ai résolu :
- Capacités dont le `revisor` n'avait pas besoin :

## Leçon 8 — Volumes et réseaux

_date :_

- Ce qui a disparu quand j'ai monté un volume sur un répertoire avec du contenu :
- La permission qui m'a empêché d'écrire dans le volume et comment je l'ai corrigée sans revenir à `root` :
- Nom avec lequel le `revisor` a trouvé l'autre conteneur :

## Leçon 9 — Compose : le système complet

_date :_

- Ce qui s'est passé quand j'ai retiré la condition `service_healthy` :
- Quelles différences j'ai trouvées entre mon `compose.yaml` et celui qu'a généré `docker init` :

## Leçon 10 — Livrer l'image

_date :_

- Vulnérabilités qu'a trouvées l'analyse et lesquelles m'importent vraiment :
- Le tag et le *digest* de mon image finale :
- Ce qu'il me manque pour l'emmener sur Kubernetes :

---

## Ce que je veux construire ensuite

_La liste des choses qui te viennent à l'esprit pendant que tu avances. C'est le meilleur signe que le cours a fonctionné._

-
