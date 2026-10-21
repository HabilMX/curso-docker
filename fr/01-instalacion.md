# Leçon 1 — Installer Docker sur ton Linux Mint

Il est 9 h 40 un lundi, et la démonstration devant l'équipe a lieu à 11 h. C'est à toi de montrer le `revisor` qui tourne dans un conteneur, et sur ton Linux Mint il n'y a toujours pas de Docker. Tu ouvres le premier tutoriel qui apparaît, tu copies cinq commandes, et la quatrième te répond en rouge : `E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.` Tu essaies un autre tutoriel ; celui-ci installe un paquet nommé `docker.io` depuis la logithèque, et tout semble fonctionner, jusqu'à ce que `docker compose` t'annonce qu'il n'existe pas. À 10 h 25, tu trouves un troisième tutoriel qui te recommande, pour te débarrasser du `permission denied` qui s'affiche désormais à chaque commande, de donner les permissions `777` au fichier du *socket*. Ça marche. Et tu viens d'ouvrir la porte de `root` de ton ordinateur à n'importe quel programme qui s'y exécute. Aucun des trois tutoriels ne t'a expliqué pourquoi chaque chose arrivait. Cette leçon fait l'installation une seule fois, dans l'ordre, avec chaque erreur provoquée exprès et expliquée, pour que la prochaine fois cela te prenne vingt minutes et non une matinée.

**Durée :** 90 min

**Ce que tu construis :** l'environnement du cours. Docker Engine installé sur ton Linux Mint depuis le dépôt officiel de Docker, ton utilisateur dans le groupe `docker` en sachant ce que cela signifie, et ton premier conteneur, `hello-world`. La leçon apporte sept courts programmes, de diagnostic et de vérification, dans [`programas/01-instalacion/`](../programas/01-instalacion).

**Ce que tu apprends :** quelles pièces tu installes et à quoi sert chacune ; pourquoi Linux Mint n'est pas une plateforme officielle de Docker et que faire à ce sujet (le mot-clé est `UBUNTU_CODENAME`) ; supprimer les paquets qui entrent en conflit avec les paquets officiels ; comment ajouter un dépôt à `apt` avec sa clé ; comment vérifier que l'installation fonctionne ; et pourquoi entrer dans le groupe `docker` équivaut à avoir `root`.

**D'où tu viens.** De la [Leçon 0](00-que-es-un-contenedor.md), tu apportes la carte : un conteneur est un processus isolé qui s'exécute sur le noyau de ta machine ; Docker, ce sont deux programmes, le client `docker` et le daemon `dockerd`, qui communiquent par un *socket* UNIX dans `/var/run/docker.sock` ; et le daemon s'exécute en tant que `root`. Cette leçon installe ces pièces et te fait regarder la dernière phrase en face. Pour l'ensemble du cours, on suppose que tu es à l'aise avec un terminal et que tu sais ce qu'est `sudo`. Il n'est pas nécessaire d'avoir utilisé `apt` au-delà d'`apt install` : ce dont tu as besoin est expliqué ici.

**Ce que cette leçon ne fait pas.** Elle n'enseigne pas les commandes de Docker une par une : c'est le sujet de la [Leçon 2](02-contenedores-dia-a-dia.md). Elle n'installe pas Docker Desktop, l'application de bureau de Docker, et la section 1.1 explique pourquoi. Elle n'installe pas Docker en mode *rootless* (sans `root`), bien que la section 1.9 explique ce que c'est et quand il conviendrait de l'utiliser. Le `revisor` n'apparaît pas encore : cette leçon prépare la machine sur laquelle il va tourner, et son empaquetage commence à la Leçon 3. Et elle ne couvre pas les autres distributions : si tu utilises Ubuntu, Debian ou Fedora, la [documentation officielle](https://docs.docker.com/engine/install/) propose un guide pour chacune, et ce que tu apprends ici te servira à le lire.

**À propos des exécutions.** Cette leçon diffère des autres sur un point, et il vaut mieux le dire d'emblée : **l'installation elle-même n'a pas été exécutée sur un Linux Mint**, car la machine sur laquelle le cours a été écrit est un Mac. Pour ne pas te présenter des sorties inventées, chaque bloc de sortie de cette leçon indique son origine, avec l'une de ces trois étiquettes :

| Étiquette | Ce qu'elle signifie |
|---|---|
| **Exécution réelle · Mint simulé** | Exécuté pour de vrai, le 21 octobre 2026, dans un conteneur Ubuntu 24.04 pour `amd64` (la base de Mint 22, dans l'architecture d'une machine Intel ou AMD) auquel on a donné le fichier `/etc/os-release` **de Linux Mint 22.3**, tiré du paquet officiel `base-files` du [dépôt de Linux Mint](http://packages.linuxmint.com/) (version `13ubuntu10mint22.3.0` ; la copie se trouve dans `programas/01-instalacion/os-release-mint-22.3.txt`). Ce fichier est la seule chose qui distingue Mint dans les étapes de l'installation, et c'est pourquoi la simulation est fidèle sur ce qui compte. Ce qui **n'est pas** identique : le conteneur n'a pas les dépôts propres à Mint, si bien que tes `apt update` afficheront en plus des lignes de `packages.linuxmint.com` ; et les paquets déjà présents dans un bureau complet (`curl`, par exemple) ont dû être installés dans le conteneur. Avant d'exécuter les scripts, on a installé `sudo` dans le conteneur, que ton Mint fournit déjà. |
| **Exécution réelle · machine virtuelle** | Exécuté pour de vrai, le même jour, dans la machine virtuelle Ubuntu 24.04.4 (arm64) que [Colima](https://github.com/abiosoft/colima) démarre sur le Mac. Sur cette machine, Docker 29.2.1 est installé **avec les mêmes paquets officiels** que ceux que tu installes (`docker-ce`, `containerd.io` et les autres, depuis `download.docker.com`), si bien que les vérifications après l'installation sont identiques. Ce qui change sur ta machine : les versions, et `arm64` deviendra `amd64`. |
| **Extrait de la documentation** | Non exécuté : c'est le texte du [guide officiel d'installation pour Ubuntu](https://docs.docker.com/engine/install/ubuntu/) ou des [étapes post-installation](https://docs.docker.com/engine/install/linux-postinstall/), consultés le 21 octobre 2026. Utilisé uniquement là où il n'y avait aucun moyen honnête de l'exécuter. |

Les versions : le cours a été planifié avec Docker Engine 29.8.2 et Compose v5.6.0 (mesurées le 7 octobre 2026). Le jour de ces exécutions, le dépôt officiel proposait la **29.9.2**, du 20 octobre 2026 ([notes de version](https://docs.docker.com/engine/release-notes/29/)), avec Compose 5.6.0 et Buildx 0.38.1, et c'est ce que tu aurais installé ce jour-là ; la machine virtuelle des exécutions avait la 29.2.1. Rien de ce qu'enseigne cette leçon ne change entre ces versions, et à la section 1.7 tu apprends à voir la tienne. Les programmes se trouvent dans [`programas/01-instalacion/`](../programas/01-instalacion), chacun avec sa sortie enregistrée à côté.

## À la fin, tu seras capable de

- Lire `/etc/os-release` et dire quel nom de code Ubuntu correspond à ton Mint, et pourquoi celui-là et non celui de Mint.
- Supprimer les paquets qui entrent en conflit avec Docker Engine et expliquer pourquoi ils entrent en conflit.
- Ajouter le dépôt officiel de Docker à `apt`, en expliquant à quoi sert chaque ligne, y compris la clé.
- Installer les cinq paquets de Docker Engine et dire ce que fait chacun.
- Vérifier avec quatre commandes que le service tourne, quelle version tu as et que tu peux créer un conteneur.
- Lire l'erreur `permission denied while trying to connect to the docker API` et la corriger en ajoutant ton utilisateur au groupe `docker`.
- Démontrer avec une commande pourquoi le groupe `docker` équivaut à `root`, et citer deux alternatives.

## Le pourquoi avant le comment

Installer un programme sous Linux tient d'habitude en une ligne : `sudo apt install quelquechose`. Avec Docker, on peut faire ainsi — ton Mint propose un paquet nommé `docker.io` — et le guide officiel de Docker te demande exactement le contraire : **le supprimer**. Pourquoi tant de cérémonie ?

Parce qu'il existe deux sources de paquets Docker, et qu'elles ne sont pas équivalentes. La première est ta distribution : Ubuntu (et donc Mint) empaquette Docker sous ses propres noms, à son propre rythme, et souvent dans une version qui prend du retard. La seconde est Docker, l'entreprise, qui publie ses paquets dans son propre dépôt, `download.docker.com`, le jour même où elle publie chaque version. Le guide officiel qualifie les premiers de « non officiels » et te demande les seconds ([Docker, installer sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/)). Ce cours utilise les paquets officiels pour une raison pratique : tout ce qu'il enseigne — le *plugin* Compose, le constructeur Buildx, les versions mentionnées — a été mesuré avec eux, et ce que tu lis dans la documentation de Docker s'y rapporte.

La deuxième raison de cette cérémonie, c'est Mint lui-même. Mint est construit sur Ubuntu, mais ce n'est pas Ubuntu, et Docker ne le prend pas officiellement en charge. Cela ne veut pas dire que ça ne fonctionne pas : cela veut dire qu'à un moment précis de l'installation, tu dois dire à `apt` de se comporter comme si tu étais Ubuntu. C'est une seule ligne, et c'est celle qui a fait échouer le premier tutoriel de la scène.

Et la troisième, c'est la sécurité. Une fois l'installation terminée, le daemon s'exécute en tant que `root` et écoute sur un *socket*. Qui peut écrire dans ce *socket* commande le daemon, et qui commande le daemon commande ta machine. C'est pourquoi l'installation se termine par une décision que tu prends toi-même, en sachant ce que tu décides : qui peut parler au daemon.

La leçon suit l'ordre dans lequel tu ferais l'installation :

1. **Ce que tu vas installer** (1.1).
2. **Mint n'est pas Ubuntu : le nom de code** (1.2).
3. **Avant d'installer : le pare-feu** (1.3).
4. **Supprimer ce qui entre en conflit** (1.4).
5. **Le dépôt officiel**, avec l'erreur de Mint provoquée puis corrigée (1.5).
6. **Installer les paquets** (1.6) et **vérifier** (1.7).
7. **Le groupe `docker`** (1.8) et **pourquoi il équivaut à `root`** (1.9).
8. **Mettre à jour et désinstaller** (1.10).

Avec cette destination en tête, voici ce que tu verras à la fin de la section 1.7, quand tout sera en place (exécution réelle · machine virtuelle) :

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

## Les concepts

### 1.1 Ce que tu vas installer

#### 1.1.1 Les cinq pièces

Le guide officiel installe cinq paquets en une seule commande. Il vaut la peine de savoir ce qu'est chacun avant de les installer, car chacun correspond à une pièce de la carte de la Leçon 0 :

| Paquet | Ce qu'il apporte | Sur la carte de la Leçon 0 |
|---|---|---|
| `docker-ce` | le daemon, `dockerd` (*CE* signifie *Community Edition*, l'édition gratuite et ouverte) | le serveur qui fait le travail |
| `docker-ce-cli` | le client, la commande `docker` que tu tapes | le client |
| `containerd.io` | `containerd`, qui gère les conteneurs sous le daemon, et `runc`, qui les crée | la chaîne qui aboutit au `containerd-shim-runc-v2` que tu as vu comme parent d'un conteneur |
| `docker-buildx-plugin` | Buildx, le constructeur d'images | tu l'utiliseras quand tu écriras ton premier Dockerfile |
| `docker-compose-plugin` | Compose, qui démarre plusieurs conteneurs à partir d'un fichier | la sous-commande `docker compose` |

Les deux derniers sont des *plugins* : ce ne sont pas des programmes que tu appelles par leur nom, mais des sous-commandes qui s'ajoutent au client. C'est pourquoi on écrit `docker compose`, avec une espace, et non `docker-compose`, avec un trait d'union. Celui avec le trait d'union est l'ancien Compose, un programme séparé, et son paquet figure dans la liste de ceux qu'il faut supprimer (1.4).

Remarque le nom `containerd.io`. Docker Engine a besoin de `containerd` et de `runc`, et ta distribution les propose aussi sous ces noms. Le guide officiel l'explique : Docker les empaquette ensemble dans un seul paquet, `containerd.io`, et si tu as installé auparavant ceux de ta distribution, il faut les supprimer pour éviter les conflits ([Docker, installer sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

#### 1.1.2 Ce que tu ne vas pas installer, et pourquoi

**Docker Desktop.** C'est une application de bureau de Docker qui existe aussi pour Linux, et le guide la présente comme « la façon la plus simple et la plus rapide de commencer ». Le cours ne l'utilise pas, pour une raison que tu connais déjà : selon sa propre documentation, « Docker Desktop sur Linux exécute une machine virtuelle » ([Docker Desktop pour Linux](https://docs.docker.com/desktop/setup/install/linux/)). Rappelle-toi la section 0.2 : la raison d'utiliser Linux comme système de référence, c'est que les conteneurs s'exécutent directement sur ton noyau, sans couche intermédiaire. Docker Desktop remet cette couche. Si un jour tu l'installes, tu sauras pourquoi `ps` sur ton Mint ne montre pas les processus des conteneurs : ils sont à l'intérieur d'une autre machine.

**Le script de commodité.** Docker publie sur `get.docker.com` un script qui détecte ta distribution et installe tout d'un coup. Le guide dit qu'il « n'est pas recommandé pour les environnements de production », qu'il installe des dépendances et des recommandations sans demander, qu'il ne laisse presque rien choisir et qu'il n'est pas conçu pour mettre à jour une installation existante ([Docker, script de commodité](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)). Il y a une autre raison, plus simple : dans un cours, un script qui fait tout t'enlève justement ce que tu viens apprendre. Si tu le croises dans un tutoriel, tu sais maintenant ce que c'est.

**Le mode *rootless*.** C'est une façon d'exécuter le daemon sans `root`. Tu le verras à la section 1.9, comme alternative ; le cours utilise le mode normal, qui est celui qu'installe le guide et celui que tu trouveras sur presque n'importe quel serveur.

### 1.2 Mint n'est pas Ubuntu : le nom de code

#### 1.2.1 Ce que Docker dit de Mint

Le guide officiel pour Ubuntu énumère les versions qu'il prend en charge : 26.10, 26.04, 24.04 et 22.04, toutes en 64 bits. Et juste en dessous figure cette note : « l'installation sur des distributions dérivées d'Ubuntu, comme Linux Mint, n'est pas officiellement prise en charge (bien qu'elle puisse fonctionner) » ([Docker, installer sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

« Pas officiellement prise en charge » a un sens précis : Docker ne teste pas ses paquets sur Mint et ne publie pas de dossier pour Mint dans son dépôt. Ce qui existe, en revanche, c'est un dossier pour chaque version d'Ubuntu. Et Mint 22 est construit sur les paquets d'Ubuntu 24.04. La page de téléchargements de Linux Mint le dit elle-même dans la colonne « Package base » : Mint 22, 22.1, 22.2 et 22.3 ont pour base « Ubuntu Noble », avec un support jusqu'en avril 2029 ([Linux Mint, toutes les versions](https://www.linuxmint.com/download_all.php)). *Noble* est le nom de code d'Ubuntu 24.04. L'astuce est donc la suivante : sur Mint 22, tu utilises les paquets Docker **pour Ubuntu Noble**, car ce sont ceux qui correspondent aux bibliothèques présentes sur ton système.

#### 1.2.2 Le fichier qui dit tout : `/etc/os-release`

Chaque distribution Linux décrit son identité dans un fichier texte, `/etc/os-release`. C'est un fichier de variables *shell* : des lignes `NOM=valeur`, que n'importe quel script peut charger. `fig01_01.sh` le lit et t'indique quel nom de code te correspond. Il ne modifie rien sur ta machine ; il se contente de lire :

```bash
#!/usr/bin/env bash
# fig01_01.sh — ¿Qué sistema tengo y qué nombre en clave le toca en el
# repositorio de Docker? Solo lee archivos: no cambia nada en tu equipo.
# Uso: ./fig01_01.sh            (lee /etc/os-release, el de tu sistema)
#      ./fig01_01.sh ARCHIVO    (lee otro archivo con el mismo formato)
set -euo pipefail
ARCHIVO="${1:-/etc/os-release}"

# os-release es un archivo de variables de shell: «.» lo carga en este guion.
. "$ARCHIVO"

echo "== Lo que dice $ARCHIVO"
echo "NAME=$NAME"
echo "VERSION=${VERSION:-}"
echo "ID=$ID  ID_LIKE=${ID_LIKE:-}"
echo "VERSION_CODENAME=${VERSION_CODENAME:-(vacío)}"
echo "UBUNTU_CODENAME=${UBUNTU_CODENAME:-(no existe)}"
echo "DEBIAN_CODENAME=${DEBIAN_CODENAME:-(no existe)}"

echo
echo "== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)"
echo "Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}"

echo
echo "== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)"
dpkg --print-architecture
```

Exécution réelle · Mint simulé :

```text
$ ./fig01_01.sh
== Lo que dice /etc/os-release
NAME=Linux Mint
VERSION=22.3 (Zena)
ID=linuxmint  ID_LIKE=ubuntu debian
VERSION_CODENAME=zena
UBUNTU_CODENAME=noble
DEBIAN_CODENAME=(no existe)

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: noble

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
amd64
```

Sur ta machine, si tu as Mint 22, 22.1 ou 22.2, `VERSION` et `VERSION_CODENAME` indiqueront `wilma`, `xia` ou `zara` ; tout le reste sera identique. Avant de lire la sortie, voici les lignes du script qui ne sont pas évidentes. Le point seul (`. "$ARCHIVO"`) charge le fichier dans le script, exactement comme `source` : après cette ligne, `$NAME` ou `$UBUNTU_CODENAME` contiennent les valeurs du fichier. `${VERSION:-}` signifie « la valeur de `VERSION`, ou rien si elle n'existe pas » ; sans cela, `set -u` arrêterait le script en rencontrant une variable absente. Et `dpkg --print-architecture` demande au gestionnaire de paquets pour quel processeur ton système est conçu ; comme il interroge ton système et non le fichier, si tu lui passes un autre `os-release` en argument, ce dernier bloc continue d'afficher l'architecture de ta propre machine.

Maintenant la sortie, qui contient la clé de toute la leçon :

1. **Mint dit qu'il est Mint.** `NAME=Linux Mint`, `ID=linuxmint`. Si un programme demande « es-tu Ubuntu ? » en regardant `ID`, la réponse est non.
2. **Mais il dit de qui il descend.** `ID_LIKE=ubuntu debian` signifie « je ressemble à Ubuntu, et Ubuntu ressemble à Debian ».
3. **Il y a deux noms de code.** `VERSION_CODENAME=zena` est celui de Mint 22.3. `UBUNTU_CODENAME=noble` est celui de la version d'Ubuntu sur laquelle il est construit. Le second existe précisément pour des cas comme celui-ci. (`DEBIAN_CODENAME` n'existe ni dans Mint ni dans Ubuntu ; à la section 1.2.3, tu verras qui la fournit.)
4. **La règle du guide officiel choisit le bon.** L'expression `${UBUNTU_CODENAME:-$VERSION_CODENAME}` se lit « utilise `UBUNTU_CODENAME` s'il existe ; sinon, `VERSION_CODENAME` ». Dans Mint, il existe, et on obtient `noble`. Dans un véritable Ubuntu, les deux variables ont la même valeur, donc peu importe laquelle on utilise. Cette expression est, à la lettre près, celle que donne le guide officiel dans la ligne `Suites` du dépôt (1.5).
5. **L'architecture est `amd64`**, celle des processeurs Intel et AMD 64 bits, qui est celle de presque tous les ordinateurs sous Mint. C'est la valeur qui va dans le champ `Architectures` du dépôt.

Pour que tu voies l'autre face, voici le même script dans la machine virtuelle des exécutions, qui est un véritable Ubuntu (exécution réelle · machine virtuelle ; il se trouve dans `fig01_01.salida-ubuntu.txt`) :

```text
$ ./fig01_01.sh
== Lo que dice /etc/os-release
NAME=Ubuntu
VERSION=24.04.4 LTS (Noble Numbat)
ID=ubuntu  ID_LIKE=debian
VERSION_CODENAME=noble
UBUNTU_CODENAME=noble
DEBIAN_CODENAME=(no existe)

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: noble

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
arm64
```

Dans Ubuntu, les deux noms de code coïncident. Dans Mint, non. Toute la différence d'une installation sur Mint tient dans ces deux lignes.

#### 1.2.3 Et si tu as LMDE ?

Linux Mint a une seconde édition, **LMDE** (*Linux Mint Debian Edition*), qui n'est pas construite sur Ubuntu mais sur Debian. La page de téléchargements de Mint liste LMDE 7, « Gigi », avec pour base « Debian Trixie » ([Linux Mint, toutes les versions](https://www.linuxmint.com/download_all.php)). Si ta machine est sous LMDE, cette leçon te sert en tout sauf pour le dépôt : tu dois suivre le [guide officiel pour Debian](https://docs.docker.com/engine/install/debian/), qui utilise `https://download.docker.com/linux/debian` (aussi pour la clé : `…/linux/debian/gpg`).

Dans sa ligne `Suites`, le guide Debian utilise `$VERSION_CODENAME`, qui dans LMDE 7 vaut `gigi`, un nom que Docker ne connaît pas : c'est la même erreur qu'à la section 1.5.2, version Debian. Le guide se contente de dire que, sur une distribution dérivée, tu devras peut-être remplacer le nom de code par celui de la version de Debian correspondante. Inutile de l'écrire manuellement : LMDE fournit dans son `/etc/os-release` une variable conçue pour cela, `DEBIAN_CODENAME`, tout comme Mint fournit `UBUNTU_CODENAME`. C'est ce qu'indique l'`os-release` du paquet officiel `base-files` de LMDE 7 (version `13.8+lmde1`, du [dépôt de Linux Mint](http://packages.linuxmint.com/) ; la copie se trouve dans `programas/01-instalacion/os-release-lmde-7.txt`). La ligne devient :

```text
Suites: $(. /etc/os-release && echo "${DEBIAN_CODENAME:-$VERSION_CODENAME}")
```

C'est un fragment, pas un programme : il prend la place de la ligne `Suites` dans le bloc du guide Debian. Pour savoir quelle édition tu as, `fig01_01.sh` te le dit : `ID` vaut `linuxmint` dans les deux, mais dans LMDE on a `NAME=LMDE`, `ID_LIKE=debian`, sans `ubuntu`, et `DEBIAN_CODENAME` apparaît.

> [!WARNING]
> Si tu as LMDE, **n'exécute ni `fig01_03.sh` ni `fig01_04.sh`** : les deux pointent vers le dépôt Ubuntu, et `fig01_04.sh` y écrirait `Suites: gigi`, ce qui ferait échouer ton `apt update`. Suis le guide Debian (y compris sa propre liste de paquets en conflit) avec la ligne `Suites` ci-dessus, et reprends la leçon à la section 1.7. Dans les vérifications, là où il est écrit `noble`, tu verras `trixie`, et dans les versions des paquets, `debian.13~trixie`.

> [!NOTE]
> 🔧 **Observation de génie logiciel 1.1**
> « Pas officiellement pris en charge » ne veut pas dire « ne fonctionne pas », ni non plus « fonctionne pareil ». Cela veut dire « personne d'autre que toi ne vérifiera que ça fonctionne ». Quand tu utilises quelque chose en dehors de ce que le fournisseur prend en charge, note exactement ce que tu as fait différemment (ici : un nom de code) pour que, si quelque chose échoue, tu saches par où commencer.

### 1.3 Avant d'installer : le pare-feu

Le guide officiel s'ouvre sur un avertissement de sécurité, avant toute commande, et il vaut mieux le lire avant d'installer plutôt que le jour où il te mord : si tu utilises **ufw** ou **firewalld** pour gérer ton pare-feu, « quand tu exposes les ports d'un conteneur avec Docker, ces ports contournent les règles de ton pare-feu » ([Docker, installer sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

*ufw* (*Uncomplicated Firewall*) est l'outil de pare-feu fourni par Ubuntu, et il peut être actif sur ton Mint. La page de Docker consacrée aux pare-feu explique le mécanisme : quand tu publies un port d'un conteneur, le trafic est dévié dans la table `nat` du noyau, **avant** d'atteindre les chaînes `INPUT` et `OUTPUT` qu'utilise ufw ; les paquets sont routés avant que les règles du pare-feu puissent s'appliquer, « ignorant de fait ta configuration » ([Docker, filtrage de paquets et pare-feu](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw)).

Ce que cela signifie en pratique : si tu as `ufw deny 8080` et que tu lances un conteneur qui publie le port 8080 sur toutes les interfaces, ce port reste ouvert sur ton réseau. ufw n'en sait rien. C'est pourquoi, dans ce cours, quand tu publies des ports, ils sont publiés uniquement sur `127.0.0.1`, l'adresse que seule ta propre machine peut atteindre : sa fermeture ne dépend pas du pare-feu, car elle n'est jamais ouverte au réseau. Il est prévu que la Leçon 2 le montre avec un port ouvert exprès.

Le même avertissement contient un second point, plus technique : Docker n'est compatible qu'avec `iptables-nft` et `iptables-legacy`, et les règles de pare-feu écrites directement avec `nft` ne sont pas prises en charge sur un système avec Docker. Si tu gères des règles manuellement, elles s'écrivent avec `iptables` ou `ip6tables` et se placent dans la chaîne `DOCKER-USER`. Si tu ne sais pas de quoi parle ce paragraphe, il est fort probable qu'il ne te concerne pas : il s'adresse à qui a déjà un pare-feu écrit manuellement.

### 1.4 Supprimer ce qui entre en conflit

#### 1.4.1 Les paquets en conflit

Avant d'installer les paquets officiels, il faut supprimer les paquets non officiels, car les deux ensembles contiennent des fichiers portant les mêmes noms (la commande `docker`, le daemon, `containerd`) et `apt` ne peut pas avoir les deux à la fois. Le guide donne la liste exacte ([Docker, installer sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/)) :

| Paquet | Ce que c'est |
|---|---|
| `docker.io` | le Docker empaqueté par Ubuntu |
| `docker-compose` | l'ancien Compose, le programme avec trait d'union |
| `docker-compose-v2` | le nouveau Compose, empaqueté par Ubuntu |
| `docker-doc` | la documentation du paquet Ubuntu |
| `docker-buildx` | Buildx, empaqueté par Ubuntu |
| `podman-docker` | un imitateur : il fait en sorte que la commande `docker` appelle Podman, un autre outil de conteneurs |
| `containerd`, `runc` | les versions Ubuntu de ce que `containerd.io` regroupe |

Si tu n'as jamais rien installé de Docker, il est fort probable que tu n'en aies aucun. Le guide le signale : « `apt` peut indiquer qu'aucun de ces paquets n'est installé ».

#### 1.4.2 La commande, pièce par pièce

`fig01_02.sh` demande d'abord lesquels tu as, puis exécute la commande du guide, copiée telle quelle :

```bash
#!/usr/bin/env bash
# fig01_02.sh — Quitar los paquetes que chocan con los oficiales de Docker.
# El segundo comando es, letra por letra, el de la guía oficial de Ubuntu.
set -uo pipefail
PAQUETES="docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc"

echo "== ¿Cuáles de los paquetes en conflicto tienes instalados?"
dpkg --get-selections $PAQUETES

echo
echo "== El comando de la guía oficial (quita los que encontró)"
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc | cut -f1)
echo "código de salida: $?"
```

Exécution réelle · Mint simulé (le système fraîchement installé, sans rien de Docker) :

```text
$ ./fig01_02.sh
== ¿Cuáles de los paquetes en conflicto tienes instalados?
dpkg: no packages found matching docker.io
dpkg: no packages found matching docker-compose
dpkg: no packages found matching docker-compose-v2
dpkg: no packages found matching docker-doc
dpkg: no packages found matching docker-buildx
dpkg: no packages found matching podman-docker
dpkg: no packages found matching containerd
dpkg: no packages found matching runc

== El comando de la guía oficial (quita los que encontró)
dpkg: no packages found matching docker.io
…
dpkg: no packages found matching runc

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Reading package lists...
Building dependency tree...
Reading state information...
0 upgraded, 0 newly installed, 0 to remove and 3 not upgraded.
código de salida: 0
```

Le `…` remplace six lignes identiques à celles du dessus ; la sortie complète se trouve dans `fig01_02.salida.txt`. Le nombre de paquets à mettre à jour (`3 not upgraded`) dépend de ta machine.

La commande du guide se lit de l'intérieur vers l'extérieur :

1. `dpkg --get-selections <paquets>` interroge `dpkg`, le gestionnaire de paquets de bas niveau, pour chaque paquet de la liste. Pour ceux qui sont installés, il écrit une ligne avec le nom, une tabulation et le mot `install`. Pour les autres, il se plaint sur la sortie d'erreur : `no packages found matching …`. Ces plaintes ne posent aucun problème ; elles sont la réponse « tu ne l'as pas ».
2. `| cut -f1` garde la première colonne de chaque ligne, c'est-à-dire uniquement les noms.
3. `$( … )` place ces noms sur la ligne de commande de `sudo apt remove`.

Ainsi, `apt remove` ne reçoit que les paquets que tu **as** effectivement. Si tu n'en as aucun, il reçoit une liste vide et indique `0 to remove`. Si tu en avais, par exemple `docker.io`, il te montrerait ce qu'il va supprimer et te demanderait si tu veux continuer : lis la liste avant de répondre oui.

L'avertissement `WARNING: apt does not have a stable CLI interface` apparaît parce que, lors de cette exécution, la sortie d'`apt` n'allait pas vers un terminal mais vers un fichier : c'est ainsi que les sorties du cours ont été enregistrées. `apt` est l'outil destiné aux personnes, et il prévient que son format peut changer quand c'est un autre programme qui lit sa sortie. Si tu exécutes le script dans ton terminal, tu ne le verras pas, et tu verras à la place `Done` à la fin de `Reading package lists...` et des barres de progression. Pour les scripts, il existe `apt-get`, qui est stable ; nous l'utilisons à la section 1.5.3.

#### 1.4.3 Ce qu'`apt remove` ne supprime pas

Le guide signale quelque chose d'important si tu as déjà eu Docker : les images, conteneurs, volumes et réseaux qui vivent dans `/var/lib/docker/` **ne sont pas effacés** lors de la désinstallation. Désinstaller le paquet supprime les programmes ; les données restent. Si tu veux vraiment repartir de zéro, la section 1.10 explique comment. Sinon, les nouveaux paquets trouveront ces données et les utiliseront.

### 1.5 Le dépôt officiel

#### 1.5.1 Ce qu'est un dépôt `apt`

`apt` ne télécharge pas les programmes n'importe où : il les télécharge depuis une liste de **dépôts**, des serveurs qui publient des paquets avec un index signé. Ton Mint inclut déjà ceux d'Ubuntu et ceux de Mint. Ajouter celui de Docker implique deux choses :

- **La clé.** Docker signe son index avec une clé cryptographique. `apt` a besoin de la partie publique de cette clé pour vérifier que ce qu'il télécharge vient bien de Docker et que personne ne l'a modifié en chemin.
- **La source.** Un fichier dans `/etc/apt/sources.list.d/` qui indique à `apt` où se trouve le dépôt, quelle partie te correspond et avec quelle clé on la vérifie.

Voici la partie du guide officiel, complète (extrait de la documentation). **Ne la tape pas encore** : dans cette leçon, tu vas l'exécuter en deux temps. `fig01_03.sh` fait la partie de la clé comme le guide et écrit la source avec l'erreur de Mint ; `fig01_04.sh` réécrit correctement la source. Si tu préfères ne pas provoquer l'erreur sur ta machine, tape ce bloc tel quel, saute la section 1.5.2 et, à la section 1.5.3, lis la sortie au lieu d'exécuter le script :

```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
```

Ligne par ligne :

- `sudo apt update` rafraîchit les index des dépôts que tu as déjà, pour que le prochain `apt install` trouve les versions à jour.
- `ca-certificates` apporte les certificats des autorités qui signent les sites HTTPS, et `curl` télécharge des fichiers. Sur un Mint de bureau, tu les as presque sûrement déjà ; les demander ne fait pas de mal.
- `install -m 0755 -d /etc/apt/keyrings` crée le dossier où vivent les clés des dépôts externes, avec les permissions `0755` : le propriétaire (`root`) écrit, tout le monde lit.
- `curl -fsSL … -o /etc/apt/keyrings/docker.asc` télécharge la clé publique de Docker. `-f` le fait échouer si le serveur répond par une erreur, au lieu d'enregistrer une page d'erreur comme s'il s'agissait de la clé ; `-s` et `-S` le rendent silencieux sauf en cas d'erreur ; `-L` suit les redirections.
- `chmod a+r` rend la clé lisible par tous, car `apt` la lit avec un utilisateur sans privilèges.
- `sudo tee … <<EOF` écrit le fichier de la source. On utilise `tee` avec `sudo` parce qu'une redirection `>` est effectuée par ton *shell*, qui n'est pas `root`, et qui ne pourrait pas écrire dans `/etc`. Ce qui se trouve entre `<<EOF` et `EOF` est le contenu, et les `$( … )` sont substitués **avant** de l'écrire.

Le fichier `docker.sources` est au format **deb822** : un champ par ligne, avec son nom. Le manuel d'`apt` le décrit à côté de l'ancien format, sur une seule ligne (`deb [options] url version composant`), et indique que l'intention est que deb822 devienne peu à peu le format par défaut ([sources.list(5)](https://manpages.debian.org/trixie/apt/sources.list.5.en.html)). Tu verras des tutoriels avec un fichier `docker.list` d'une ligne ; cela fonctionne de la même façon, c'est l'ancienne forme. Les champs :

| Champ | Valeur | Ce qu'il signifie |
|---|---|---|
| `Types` | `deb` | paquets déjà compilés (pas de code source) |
| `URIs` | `https://download.docker.com/linux/ubuntu` | où se trouve le dépôt ; remarque le `ubuntu` à la fin |
| `Suites` | le nom de code | la version d'Ubuntu dont tu veux les paquets ; **c'est ici que se joue l'affaire de Mint** |
| `Components` | `stable` | uniquement les versions stables, pas celles de test |
| `Architectures` | `amd64` sur ton Mint | pour quel processeur |
| `Signed-By` | `/etc/apt/keyrings/docker.asc` | avec quelle clé on vérifie **ce** dépôt, et lui seul |

Ce dernier champ mérite une ligne de plus. Autrefois, les clés des dépôts externes s'ajoutaient avec `apt-key` à un trousseau commun, et une clé servait à vérifier **n'importe quel** dépôt : celle de Docker aurait pu signer un paquet prétendant venir d'Ubuntu. `apt-key` est obsolète : le manuel de la version d'`apt` d'Ubuntu 24.04, la base de Mint 22, indique qu'il sera disponible pour la dernière fois dans Debian 12 et Ubuntu 24.04 ([apt-key(8), Ubuntu noble](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html)). Ton Mint 22 le fournit encore, et c'est pourquoi un vieux tutoriel avec `apt-key add` semble fonctionner : il fonctionne, mais il laisse la clé de Docker valable pour tous tes dépôts. Avec `Signed-By`, la clé de Docker ne vaut que pour le dépôt de Docker. Si un tutoriel te dit `apt-key add`, il date d'avant l'adoption de `Signed-By`, et tu ne dois pas le suivre.

#### 1.5.2 L'erreur de Mint, provoquée

Voici maintenant l'erreur de la scène, exprès. `fig01_03.sh` est la même étape que celle du guide, avec **une seule différence** : dans `Suites`, il utilise `VERSION_CODENAME` au lieu de `${UBUNTU_CODENAME:-$VERSION_CODENAME}`. C'est ainsi que l'écrivent beaucoup d'anciens guides pour Ubuntu, avec `$VERSION_CODENAME` ou avec `$(lsb_release -cs)`, qui dans Mint renvoie aussi le nom de Mint (il le tire de `DISTRIB_CODENAME` dans `/etc/lsb-release`) ; et c'est ainsi que l'écrit le guide officiel **pour Debian**, qui n'a pas le problème parce que Debian n'a pas `UBUNTU_CODENAME` ([Docker, installer sur Debian](https://docs.docker.com/engine/install/debian/)). Qui copie depuis le mauvais guide, sur Mint, tombe ici.

```bash
#!/usr/bin/env bash
# fig01_03.sh — EL ERROR DE MINT, provocado a propósito.
# Es el paso 1 de la guía oficial con UNA sola diferencia: «Suites» sale de
# VERSION_CODENAME (el nombre en clave de Mint) en vez de UBUNTU_CODENAME.
# Así lo escriben muchas guías viejas y la guía oficial de Debian.
set -uo pipefail

# Igual que la guía oficial: la llave con la que apt comprueba los paquetes.
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# La diferencia está en la línea Suites.
sudo tee /etc/apt/sources.list.d/docker.sources <<FIN
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
FIN

echo
echo "== apt update con ese repositorio"
sudo apt update
echo "código de salida: $?"
```

Exécution réelle · Mint simulé. C'est la sortie depuis la ligne qu'écrit `tee` jusqu'à la fin ; avant viennent celles d'`apt update` et de l'installation de `curl`, qui figurent en entier dans `fig01_03.error-esperado.txt` :

```text
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: zena
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc

== apt update con ese repositorio

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Ign:1 https://download.docker.com/linux/ubuntu zena InRelease
Err:2 https://download.docker.com/linux/ubuntu zena Release
  404  Not Found [IP: 3.161.44.57 443]
Hit:3 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:4 http://archive.ubuntu.com/ubuntu noble InRelease
Hit:5 http://archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:6 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Reading package lists...
E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.
código de salida: 100
```

L'adresse IP entre crochets est celle du serveur de Docker qui a répondu, et elle change d'une exécution à l'autre. Les lignes `Hit:` sont les dépôts d'Ubuntu, qui répondent bien ; leur ordre d'apparition peut varier. Le reste est stable, sauf le nom de code si ton Mint n'est pas la 22.3. Dans ton terminal, tu verras en plus des lignes `Hit:` des dépôts de Mint.

Elle se lit de haut en bas :

1. `tee` affiche ce qu'il a écrit, et le problème est là, bien visible : `Suites: zena`.
2. `apt update` demande au serveur de Docker l'index de la version `zena` d'Ubuntu. Il cherche d'abord `InRelease` (l'index avec la signature intégrée) et l'ignore (`Ign`) parce qu'il n'existe pas ; ensuite il cherche `Release` et le serveur répond **404**, « introuvable ».
3. L'erreur finale le dit en toutes lettres : le dépôt `… zena Release` n'a pas de fichier `Release`. Traduction : **il n'existe aucune version d'Ubuntu nommée `zena`**. Et c'est vrai : `zena`, c'est Mint.
4. `apt` sort avec le code 100, son code d'erreur générique.

Un détail trompeur : la clé a bien été téléchargée et le serveur a bien répondu. Ce n'est ni un problème de réseau, ni de permissions, ni de clé. C'est un nom mal placé dans un fichier texte.

#### 1.5.3 La correction

On corrige en réécrivant la source avec la ligne du guide officiel. `fig01_04.sh` le fait (il ne retélécharge pas la clé : il utilise celle que `fig01_03.sh` a laissée dans `/etc/apt/keyrings/docker.asc` ; sans elle, `apt update` échouerait à cause de la clé manquante), rafraîchit les index et, au lieu d'installer, pose la question : d'où viendrait `docker-ce`, et dans quelle version ?

```bash
#!/usr/bin/env bash
# fig01_04.sh — El arreglo: el repositorio de Docker con el nombre en clave de
# Ubuntu, como lo escribe la guía oficial. Después pregunta qué versión se
# instalaría y SIMULA la instalación (apt-get -s no instala nada).
set -euo pipefail

# Letra por letra, la línea Suites de la guía oficial de Ubuntu:
# UBUNTU_CODENAME si existe (Mint, Ubuntu) y, si no, VERSION_CODENAME.
sudo tee /etc/apt/sources.list.d/docker.sources <<FIN
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
FIN

echo
echo "== apt update"
sudo apt update

echo
echo "== ¿De dónde saldría docker-ce, y en qué versión?"
apt-cache policy docker-ce | sed -n 1,6p

echo
echo "== Las versiones más recientes que ofrece el repositorio"
apt list --all-versions docker-ce 2>/dev/null | grep docker-ce | sed -n 1,3p

echo
echo "== Simulación: los paquetes de Docker que instalaría el comando de la guía"
SIMULACION=$(apt-get install -s docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
echo "$SIMULACION" | grep -E '^Inst (docker-|containerd)' | cut -d' ' -f2,3 | tr -d '('
echo "paquetes en total, contando dependencias: $(echo "$SIMULACION" | grep -c '^Inst')"
```

Exécution réelle · Mint simulé :

```text
$ ./fig01_04.sh
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc

== apt update

WARNING: apt does not have a stable CLI interface. Use with caution in scripts.

Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Hit:2 https://download.docker.com/linux/ubuntu noble InRelease
Hit:3 http://archive.ubuntu.com/ubuntu noble-updates InRelease
Hit:4 http://security.ubuntu.com/ubuntu noble-security InRelease
Hit:5 http://archive.ubuntu.com/ubuntu noble-backports InRelease
Reading package lists...
Building dependency tree...
Reading state information...
3 packages can be upgraded. Run 'apt list --upgradable' to see them.

== ¿De dónde saldría docker-ce, y en qué versión?
docker-ce:
  Installed: (none)
  Candidate: 5:29.9.2-1~ubuntu.24.04~noble
  Version table:
     5:29.9.2-1~ubuntu.24.04~noble 500
        500 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages

== Las versiones más recientes que ofrece el repositorio
docker-ce/noble 5:29.9.2-1~ubuntu.24.04~noble amd64
docker-ce/noble 5:29.9.1-1~ubuntu.24.04~noble amd64
docker-ce/noble 5:29.9.0-1~ubuntu.24.04~noble amd64

== Simulación: los paquetes de Docker que instalaría el comando de la guía
containerd.io 2.4.2-3~ubuntu.24.04~noble
docker-ce-cli 5:29.9.2-1~ubuntu.24.04~noble
docker-ce 5:29.9.2-1~ubuntu.24.04~noble
docker-buildx-plugin 0.38.1-1~ubuntu.24.04~noble
docker-ce-rootless-extras 5:29.9.2-1~ubuntu.24.04~noble
docker-compose-plugin 5.6.0-1~ubuntu.24.04~noble
paquetes en total, contando dependencias: 96
```

Ce qui change sur ta machine : les versions (celles de ce bloc sont celles du 21 octobre 2026), le nombre de paquets à mettre à jour et, surtout, le total de la dernière ligne. Le conteneur de la simulation est un Ubuntu minimal, presque vide, auquel manquent des dizaines de pièces que ton Mint de bureau possède déjà (`systemd`, `perl`, `git`…) ; sur ta machine, le total sera bien plus faible. Et ces lignes d'`apt update` proviennent de la **deuxième** exécution du script, avec les index déjà téléchargés (`Hit`). La première fois, ceux de Docker sont apparus comme des téléchargements : `Get:1 https://download.docker.com/linux/ubuntu noble InRelease [48.5 kB]` puis la liste des paquets de `noble/stable amd64`.

Ce que dit la sortie :

1. **`Suites: noble`**. Le même Mint, désormais avec le nom d'Ubuntu.
2. **`apt update` ne se plaint plus**, et parmi les dépôts apparaît `https://download.docker.com/linux/ubuntu noble`.
3. **`apt-cache policy`** répond à la question « si j'installe `docker-ce`, quelle version et d'où ? ». `Installed: (none)` : tu ne l'as pas. `Candidate` : la version qui serait installée. Et dans le tableau, l'origine : `download.docker.com`, `noble/stable`. Si tu voyais à la place une origine `archive.ubuntu.com`, quelque chose s'est mal passé : il n'existe pas de `docker-ce` dans Ubuntu, mais il existe bien un `docker.io`, et c'est pourquoi il vaut mieux vérifier d'où vient chaque chose avant d'installer.
4. **Le numéro de version** se lit ainsi : `5:` est l'« époque », un compteur qui sert uniquement à ce qu'`apt` ordonne correctement les versions ; `29.9.2` est la version de Docker ; `-1~ubuntu.24.04~noble` indique pour quelle distribution le paquet a été construit.
5. **La simulation** montre six paquets Docker, et non cinq. Le sixième, `docker-ce-rootless-extras`, tu ne l'as pas demandé : `apt` l'ajoute en tant que *recommandation* de `docker-ce`. Ce sont les outils du mode *rootless* (1.9) ; ils ne gênent pas.

`apt-get install -s` (pour *simulate*) calcule tout ce que ferait une installation et l'affiche sur des lignes `Inst`, sans rien toucher. C'est une bonne habitude avant toute installation importante : voir ce qui va entrer.

### 1.6 Installer les paquets

Le dépôt étant en place, l'installation tient en une seule commande (extrait de la documentation) :

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

`apt` te montrera la liste des paquets, combien il va télécharger et combien d'espace il utilisera, et te demandera si tu veux continuer. La sortie de cette commande **n'est pas reproduite ici**, car elle n'a pas été exécutée sur un vrai Mint, et sur ta machine elle dépend de ce que tu as déjà installé. Ce que tu dois y chercher : que les nouveaux paquets incluent les six de la simulation ci-dessus, et qu'à la fin il n'y ait aucune ligne commençant par `E:`.

**Fixer une version.** La commande ci-dessus installe la plus récente. Si tu as besoin d'une version exacte — pour que ta machine corresponde à un serveur, par exemple —, le guide donne la recette (extrait de la documentation) :

```bash
apt list --all-versions docker-ce
VERSION_STRING=5:29.8.2-1~ubuntu.24.04~noble
sudo apt install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
```

La première commande liste les versions disponibles, comme l'a fait `fig01_04.sh`. La deuxième enregistre dans une variable celle que tu veux, avec son numéro complet, époque comprise. La troisième installe `docker-ce` et `docker-ce-cli` dans cette version exacte : `paquet=version` est la façon dont `apt` demande une version précise. La 29.8.2 de l'exemple est justement la version avec laquelle ce cours a été planifié ; il n'est pas nécessaire de la fixer pour le suivre.

**Ce que fait l'installation en plus de copier des fichiers.** Sur Debian et Ubuntu, le service Docker est configuré pour démarrer tout seul, maintenant et à chaque démarrage de la machine : les étapes post-installation le disent, « sur Debian et Ubuntu, le service Docker démarre au lancement du système par défaut » ([Docker, étapes post-installation](https://docs.docker.com/engine/install/linux-postinstall/)). Et le groupe `docker` est créé, vide. Tu vérifies ces deux points aux sections 1.7 et 1.8.

### 1.7 Vérifier

#### 1.7.1 Ce que demande le guide

Le guide officiel se termine par deux vérifications (extrait de la documentation) :

```bash
sudo systemctl status docker
sudo docker run hello-world
```

`systemctl status docker` demande à *systemd*, le programme qui démarre et surveille les services du système, dans quel état se trouve le service `docker`. S'il ne tournait pas, le guide dit de le démarrer avec `sudo systemctl start docker`. Et `sudo docker run hello-world` crée ton premier conteneur. Remarque le `sudo` dans les deux : juste après l'installation, ton utilisateur ne peut pas encore parler au daemon. Cela se corrige à la section 1.8, et c'est pourquoi les vérifications de ce cours se font sans `sudo`, ensuite.

#### 1.7.2 Les vérifications du cours

`fig01_05.sh` rassemble tout ce que tu veux savoir sur une installation toute fraîche. Exécute-le **après** la section 1.8, sans `sudo` :

```bash
#!/usr/bin/env bash
# fig01_05.sh — Las comprobaciones al terminar la instalación.
# Córrelo SIN sudo, después de entrar al grupo docker (sección 1.8).
set -uo pipefail

echo "== 1. El servicio: ¿corre ahora y arrancará con el equipo?"
systemctl is-active docker
systemctl is-enabled docker

echo
echo "== 2. Los cinco paquetes instalados"
dpkg-query -W -f='${Package} ${Version}\n' \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo
echo "== 3. Versiones"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}  API: {{.Server.APIVersion}}'
docker compose version
docker buildx version | cut -d' ' -f1,2

echo
echo "== 4. El primer contenedor"
docker run --rm --name curso-docker-hola hello-world

echo
echo "== 5. El socket: dueño root, grupo docker"
ls -l /var/run/docker.sock | awk '{print $1, $3, $4, $NF}'

echo
echo "== 6. Basura: contenedores curso-docker- que quedaron"
docker ps -a --filter name=curso-docker- --format '{{.Names}}' | wc -l
```

Exécution réelle · machine virtuelle :

```text
$ ./fig01_05.sh
== 1. El servicio: ¿corre ahora y arrancará con el equipo?
active
enabled

== 2. Los cinco paquetes instalados
containerd.io 2.2.1-1~ubuntu.24.04~noble
docker-buildx-plugin 0.31.1-1~ubuntu.24.04~noble
docker-ce 5:29.2.1-1~ubuntu.24.04~noble
docker-ce-cli 5:29.2.1-1~ubuntu.24.04~noble
docker-compose-plugin 5.0.2-1~ubuntu.24.04~noble

== 3. Versiones
Cliente: 29.2.1  Daemon: 29.2.1  API: 1.53
Docker Compose version v5.0.2
github.com/docker/buildx v0.31.1

== 4. El primer contenedor
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
58dee6a49ef1: Pulling fs layer
c3bdf82c34d1: Download complete
58dee6a49ef1: Download complete
58dee6a49ef1: Pull complete
Digest: sha256:11a3eb1597e864c51b3f56733cb2e8a90bf0c284bfc05f9444d81c558bc848aa
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/


== 5. El socket: dueño root, grupo docker
srw-rw---- root docker /var/run/docker.sock

== 6. Basura: contenedores curso-docker- que quedaron
0
```

Ce qui change sur ta machine : les versions (si tu avais installé le 21 octobre 2026, tu verrais 29.9.2, Compose v5.6.0 et Buildx v0.38.1), les identifiants des couches et le *digest* de l'image, et `(arm64v8)`, qui sur ta machine indiquera `(amd64)`. Si tu avais déjà exécuté `hello-world` auparavant, tu ne verras pas le bloc de téléchargement : l'image est déjà sur ta machine.

Bloc par bloc :

1. **`active` et `enabled`.** `is-active` répond à la question de savoir si le service tourne **maintenant** ; `is-enabled`, s'il démarrera **tout seul** au prochain démarrage de la machine. Ce sont deux questions différentes et il vaut mieux poser les deux : un service peut tourner parce que tu l'as démarré manuellement et ne pas revenir après un redémarrage.
2. **Les cinq paquets**, chacun avec sa version et le suffixe `ubuntu.24.04~noble`, qui indique qu'ils proviennent du dépôt officiel pour Noble. `dpkg-query -W` interroge les paquets installés avec le format que tu lui demandes.
3. **Les versions.** `docker version` en rapporte deux, celle du client et celle du daemon, car ce sont deux programmes (Leçon 0, section 0.6). `API: 1.53` est la version de la langue dans laquelle ils communiquent. `docker compose version` et `docker buildx version` confirment que les deux *plugins* sont en place : si `docker compose` répondait `docker: unknown command: docker compose`, il manquerait `docker-compose-plugin` (avec Docker 29.2.1, c'est ainsi que le client répond à une sous-commande qu'il ne connaît pas : `docker noexiste` a affiché `docker: unknown command: docker noexiste`).
4. **Le premier conteneur.** Le daemon n'a pas trouvé l'image `hello-world` sur ta machine (`Unable to find image … locally`), il l'a téléchargée depuis Docker Hub, a créé un conteneur, l'a exécuté et, comme tu as demandé `--rm`, l'a supprimé à la fin. Le texte qu'affiche le conteneur décrit, en quatre étapes, le chemin de la carte de la Leçon 0 : le client parle au daemon, le daemon télécharge l'image, crée un conteneur et te renvoie sa sortie. `hello-world` est la seule image de ce cours utilisée sans version fixe (`latest`), car c'est le seul tag qu'elle publie.
5. **Le *socket*.** `srw-rw----` : le `s` indique que c'est un *socket* ; `rw-` pour le propriétaire, `root` ; `rw-` pour le groupe, `docker` ; et `---` pour tous les autres. C'est cette dernière colonne de tirets qui empêche un utilisateur hors du groupe de parler au daemon (1.8).
6. **Zéro conteneur du cours.** `--rm` a fait son travail. Tous les noms de ce cours commencent par `curso-docker-` pour que tu puisses trouver et supprimer ce qui t'appartient sans toucher à rien d'autre ; c'est une habitude qu'il vaut mieux prendre dès le premier conteneur.

### 1.8 Le groupe `docker`

#### 1.8.1 L'erreur de permissions

Juste après l'installation de Docker, si tu tapes `docker ps` sans `sudo`, tu vas voir l'erreur de cette section. `fig01_06.sh` la provoque sans te retirer du groupe : il utilise l'utilisateur `nobody`, qui existe sur n'importe quel Linux et n'appartient à aucun groupe utile :

```bash
#!/usr/bin/env bash
# fig01_06.sh — El error de permisos: un usuario que NO está en el grupo docker.
# Usa al usuario «nobody», que existe en todo Linux y no pertenece a ningún
# grupo útil, para mostrar el error sin tener que sacarte a ti del grupo.
set -uo pipefail

echo "== ¿En qué grupos está nobody?"
id -nG nobody

echo
echo "== nobody intenta hablarle al daemon"
sudo -u nobody docker ps
echo "código de salida: $?"

echo
echo "== ¿Y tú? ¿Estás en el grupo docker?"
if id -nG | tr ' ' '\n' | grep -qx docker; then echo "sí"; else echo "no"; fi
```

Exécution réelle · machine virtuelle :

```text
$ ./fig01_06.sh
== ¿En qué grupos está nobody?
nogroup

== nobody intenta hablarle al daemon
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
código de salida: 1

== ¿Y tú? ¿Estás en el grupo docker?
sí
```

Cette sortie est stable. La dernière ligne indiquera `no` si tu n'as pas encore fait ce que décrit la section 1.8.2, et c'est dans cet état que tu verras l'erreur avec ton propre utilisateur.

`sudo -u nobody` exécute la commande en tant qu'utilisateur `nobody`. Cet utilisateur n'appartient qu'au groupe `nogroup`, si bien que, face au *socket* `srw-rw---- root docker`, il tombe dans la troisième colonne : aucune permission. Le message se lit comme celui de la Leçon 0, avec une autre cause à la fin : le client a **bien** trouvé le *socket* dans `/var/run/docker.sock` (le daemon est là), mais il n'a pas la permission de l'ouvrir. Compare-le avec le `no such file or directory` de la Leçon 0, qui signifiait « il n'y a pas de daemon à ce chemin ». Deux causes différentes, deux corrections différentes : ici, redémarrer le service ne sert à rien.

#### 1.8.2 Entrer dans le groupe

Il y a trois façons de te débarrasser de l'erreur, et il vaut mieux les connaître avant de choisir :

1. **Utiliser toujours `sudo docker`.** Ça fonctionne et ça ne donne aucune nouvelle permission, mais c'est peu pratique, et les fichiers de configuration du client finissent par appartenir à `root` (tu le vois à la section 1.8.3).
2. **Entrer dans le groupe `docker`.** C'est ce que fait presque tout le monde et ce que fait ce cours. À partir de ce moment, n'importe quel programme qui s'exécute sous ton identité peut parler au daemon.
3. **Le groupe à la demande**, avec mot de passe (1.9.3).

La façon 2 se fait en trois étapes (extrait de la documentation) :

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

- `groupadd docker` crée le groupe. Le guide prévient que, sur certaines distributions, le paquet le crée déjà à l'installation ; c'est le cas sur Ubuntu et sur Mint, et la commande te dira `groupadd: group 'docker' already exists`. Ce n'est pas une vraie erreur : le groupe existait déjà.
- `usermod -aG docker $USER` t'ajoute au groupe. Le `-a` (*append*) est important : sans lui, `-G` **remplace** tous tes groupes par `docker`, et tu te retrouverais exclu de `sudo`, entre autres. `$USER` est ton nom d'utilisateur.
- Le changement ne s'applique pas aux sessions déjà ouvertes, car les groupes d'un processus sont fixés à l'ouverture de session. Le guide demande de **fermer la session et de te reconnecter** (et, si ton Linux tourne dans une machine virtuelle, peut-être de la redémarrer). `newgrp docker` est le raccourci : il ouvre un nouveau *shell* avec le groupe déjà appliqué, uniquement dans ce terminal.

Ensuite, `id -nG` doit inclure le mot `docker`, et `docker run hello-world` doit fonctionner sans `sudo`. C'est le moment d'exécuter `fig01_05.sh`.

#### 1.8.3 L'erreur d'après : `config.json`

Si, avant d'entrer dans le groupe, tu as exécuté des commandes avec `sudo docker`, tu verras peut-être ceci en utilisant `docker` sans `sudo` (extrait de la documentation ; `user` est ton utilisateur) :

```text
WARNING: Error loading config file: /home/user/.docker/config.json -
stat /home/user/.docker/config.json: permission denied
```

Le client enregistre sa configuration dans le dossier `.docker` de ton répertoire personnel. Quand tu l'as exécuté avec `sudo`, ce dossier a été créé avec `root` comme propriétaire, et maintenant tu ne peux plus le lire. Le guide propose deux corrections : supprimer `~/.docker/` (il se recrée tout seul, mais tu perds la configuration qu'il contenait), ou te rendre la propriété du dossier :

```bash
sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
sudo chmod g+rwx "$HOME/.docker" -R
```

C'est un bon exemple de la raison pour laquelle `sudo docker` n'est pas si innocent : il ne donne pas plus de pouvoir que le groupe, mais il laisse des traces de `root` là où elles ne devraient pas être.

### 1.9 Pourquoi le groupe `docker` équivaut à `root`

#### 1.9.1 L'avertissement

Les étapes post-installation placent cet avertissement juste avant les commandes de la section 1.8.2 : « le groupe `docker` accorde à l'utilisateur des privilèges de niveau `root` » ([Docker, étapes post-installation](https://docs.docker.com/engine/install/linux-postinstall/)). Et le guide de sécurité explique pourquoi : le daemon a besoin de `root`, et Docker te permet de partager un dossier de l'hôte avec un conteneur « sans limiter les droits d'accès du conteneur » ; tu peux démarrer un conteneur dans lequel `/host` est le dossier `/` de ta machine, « et le conteneur peut modifier le système de fichiers de ton hôte sans aucune restriction » ([Docker Engine security](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)).

Un avertissement s'oublie ; une démonstration, non. C'est pourquoi ce cours ne te demande pas de le croire sur parole.

#### 1.9.2 Le voir de tes propres yeux

`/etc/shadow` est le fichier où Linux conserve les mots de passe chiffrés des utilisateurs. Seul `root` peut le lire. `fig01_07.sh` essaie de le lire deux fois : d'abord en tant que toi, sans `sudo` ; ensuite, en le demandant au daemon de Docker. Pour ne rien afficher de secret, il se contente de compter les lignes et de montrer le premier **nom** d'utilisateur :

```bash
#!/usr/bin/env bash
# fig01_07.sh — Por qué el grupo docker equivale a root.
# Córrelo SIN sudo, como tu usuario normal (que ya está en el grupo docker).
# Lee /etc/shadow, el archivo de contraseñas cifradas que solo root puede leer,
# y solo imprime cuántos renglones tiene y el primer NOMBRE de usuario: nada secreto.
set -uo pipefail
IMAGEN=debian:13.7-slim

echo "== 1. Tú, sin sudo, intentas leer /etc/shadow"
ls -l /etc/shadow | awk '{print $1, $3, $4, $NF}'
cat /etc/shadow > /dev/null
echo "código de salida: $?"

echo
echo "== 2. Lo mismo, pero se lo pides al daemon de Docker"
docker run --rm --name curso-docker-llave -v /etc:/anfitrion-etc:ro "$IMAGEN" sh -c '
  id
  echo "renglones de /etc/shadow que pude leer: $(wc -l < /anfitrion-etc/shadow)"
  echo "primer usuario de la lista: $(cut -d: -f1 /anfitrion-etc/shadow | head -1)"'
echo "código de salida: $?"
```

Exécution réelle · machine virtuelle :

```text
$ ./fig01_07.sh
== 1. Tú, sin sudo, intentas leer /etc/shadow
-rw-r----- root shadow /etc/shadow
cat: /etc/shadow: Permission denied
código de salida: 1

== 2. Lo mismo, pero se lo pides al daemon de Docker
Unable to find image 'debian:13.7-slim' locally
13.7-slim: Pulling from library/debian
ddc0c1e36a67: Pulling fs layer
d449c469d06c: Download complete
ddc0c1e36a67: Download complete
ddc0c1e36a67: Pull complete
Digest: sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad
Status: Downloaded newer image for debian:13.7-slim
uid=0(root) gid=0(root) groups=0(root)
renglones de /etc/shadow que pude leer: 26
primer usuario de la lista: root
código de salida: 0
```

Ce qui change sur ta machine : le nombre de lignes (une par utilisateur de ton système), les identifiants du téléchargement et l'intégralité du bloc de téléchargement si tu avais déjà l'image. Le reste est stable.

Lis les deux moitiés ensemble :

1. **En tant que toi, le système te dit non.** `/etc/shadow` appartient à `root` et au groupe `shadow`, et les autres n'ont aucune permission (`---`). `cat` échoue avec `Permission denied`, comme il se doit.
2. **En le demandant au daemon, il te dit oui.** `-v /etc:/anfitrion-etc:ro` monte le dossier `/etc` de ta machine à l'intérieur du conteneur, dans `/anfitrion-etc`. À l'intérieur, le processus est `uid=0(root)`, et comme l'espace de noms des utilisateurs n'est pas isolé par défaut (Leçon 0, section 0.3), c'est le **même** utilisateur 0 que sur ta machine. Il lit le fichier sans difficulté : 26 lignes, en commençant par celle de `root`.

Tu n'as pas utilisé `sudo`. Tu n'as tapé aucun mot de passe. Il a suffi d'être dans le groupe `docker`. Et le `:ro` du montage (lecture seule) n'est pas une protection : c'est toi qui l'as mis, et rien ne t'empêchait de l'enlever et de monter `/` en entier avec permission d'écriture. Voilà ce que signifie « équivaut à `root` » : non pas que le groupe `docker` ait une permission spéciale, mais qu'il donne accès à un programme qui s'exécute en tant que `root` et qui fait ce que tu lui demandes.

La même logique explique les deux autres interdits de la scène. Donner les permissions `777` au *socket*, c'est mettre **tous** les utilisateurs et programmes de la machine dans le groupe `docker` sans leur demander leur avis. Et monter le *socket* à l'intérieur d'un conteneur, c'est donner cette clé à ce qui s'exécute dedans.

#### 1.9.3 Les alternatives

La documentation propose trois voies pour qui ne veut pas de ce pouvoir disponible en permanence :

- **`sudo docker`**, à chaque fois. Le pouvoir est le même, mais il faut le demander avec un mot de passe, et cela laisse une trace.
- **Le groupe à la demande.** Ton utilisateur reste **hors** du groupe `docker`, on attribue un mot de passe au groupe (`sudo gpasswd docker`) et, quand tu as besoin de Docker, tu ouvres un *shell* avec `newgrp docker` et tu tapes ce mot de passe. Le guide dit à quoi cela sert et à quoi non : cela réduit l'accès « ambiant » au *socket*, car seuls les programmes que tu lances depuis ce *shell* l'ont, mais cela ne réduit pas les privilèges une fois l'accès accordé, et « ce n'est pas une frontière de sécurité » face à du code malveillant qui s'exécute déjà sous ton utilisateur ([Docker, étapes post-installation](https://docs.docker.com/engine/install/linux-postinstall/#access-the-docker-group-on-demand)).
- **Le mode *rootless*.** Le daemon et les conteneurs s'exécutent à l'intérieur d'un espace de noms des utilisateurs, sans privilèges `root`, pour atténuer d'éventuelles vulnérabilités du daemon et de l'environnement d'exécution ([Docker, mode *rootless*](https://docs.docker.com/engine/security/rootless/)). C'est la seule des trois qui change le fond du problème. Il a ses propres prérequis et limitations, et certains détails qu'enseigne ce cours y apparaîtraient différemment ; c'est pourquoi ce n'est pas la voie du cours.

Le cours utilise le groupe, sur une machine qui t'appartient et où c'est toi qui décides de ce qui s'y exécute. La règle qui compte : **mettre quelqu'un dans le groupe `docker`, c'est lui donner `root`**. Si tu ne donnerais pas le mot de passe `root` à une personne ou à un programme, ne le mets pas non plus dans le groupe.

> [!NOTE]
> 🔧 **Observation de génie logiciel 1.2**
> La question utile n'est pas « cette permission est-elle dangereuse ? », mais « que puis-je faire **à travers** cette permission ? ». Le groupe `docker` ne dit `root` nulle part ; le chemin vers `root` passe par un intermédiaire qui, lui, l'est. Beaucoup de problèmes de sécurité ont cette forme : une permission modeste qui ouvre la porte à quelqu'un de plus puissant.

### 1.10 Mettre à jour et désinstaller

**Mettre à jour.** Comme Docker vit dans un dépôt `apt`, il se met à jour comme tout le reste : `sudo apt update` et `sudo apt upgrade`, ou en répétant la commande de la section 1.6 avec la nouvelle version que tu veux ([Docker, installer sur Ubuntu](https://docs.docker.com/engine/install/ubuntu/#upgrade-docker-engine)).

**Désinstaller.** Il y a trois étapes, et chacune supprime une chose différente (extrait de la documentation) :

```bash
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm /etc/apt/sources.list.d/docker.sources
sudo rm /etc/apt/keyrings/docker.asc
```

La première supprime les programmes (`purge`, contrairement à `remove`, supprime aussi leur configuration). Remarque que la liste inclut `docker-ce-rootless-extras`, le sixième paquet que tu as vu dans la simulation de la section 1.5.3. La deuxième paire **efface toutes tes images, conteneurs et volumes**, que la première a laissés intacts : c'est irréversible, alors avant de l'exécuter, assure-toi qu'il n'y a rien là-dedans que tu veuilles garder. La troisième paire supprime la source et la clé, pour qu'`apt` cesse de consulter le dépôt de Docker. Le guide ajoute que les fichiers de configuration que tu as modifiés manuellement doivent être supprimés manuellement.

## L'erreur que tu vas voir

Cette leçon comporte deux erreurs principales, toutes deux provoquées dans leurs sections, et une erreur secondaire que tu connais déjà.

**L'erreur de Mint : « does not have a Release file ».** C'est celle de `fig01_03.sh` (1.5.2) :

```text
Err:2 https://download.docker.com/linux/ubuntu zena Release
  404  Not Found [IP: 3.161.44.57 443]
E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.
```

Elle se lit ainsi : `apt` a demandé au dépôt de Docker la version `zena` et le serveur a répondu qu'elle n'existe pas (404). Le mot qui compte est celui qui se trouve entre l'adresse et `Release` : si un nom de Mint y apparaît (`wilma`, `xia`, `zara`, `zena`), le problème vient de la ligne `Suites` de `/etc/apt/sources.list.d/docker.sources`. On corrige en réécrivant ce fichier avec la ligne du guide officiel, qui utilise `UBUNTU_CODENAME` (1.5.3), puis en relançant `sudo apt update`. Si, au lieu du nom de Mint, c'est `noble` qui apparaît et que cela échoue quand même, le problème est ailleurs (le réseau, ou l'URL mal écrite) ; et si c'est le nom d'une version d'Ubuntu que Docker ne prend pas en charge, revois la liste de la section 1.2.1.

**L'erreur de permissions : « permission denied while trying to connect to the docker API ».** C'est celle de `fig01_06.sh` (1.8.1) :

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

Elle se lit ainsi : le daemon est **bien** là (le *socket* existe), mais ton utilisateur n'a pas la permission d'ouvrir le *socket*. On corrige avec `sudo usermod -aG docker $USER` puis en fermant la session (1.8.2), **en sachant ce que cela signifie** (1.9). Ce qu'on ne fait pas : `chmod 666` ou `777` sur le *socket*, ce qui l'ouvre à tous les utilisateurs de la machine. De plus, le *socket* est recréé par *systemd* (l'unité `docker.socket`) avec ses permissions habituelles, `root:docker` et `0660`, à chaque démarrage de la machine, si bien que la « correction » disparaît au redémarrage suivant, et la tentation est de la répéter.

**L'erreur secondaire : le daemon est absent.** Tu l'as vue à la Leçon 0, provoquée avec un chemin de test (exécution réelle de cette leçon-là) :

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

Sur ton Mint, avec le service arrêté, le chemin sera `/var/run/docker.sock` et le reste du message, identique. Tu peux désormais le diagnostiquer de bout en bout : `systemctl is-active docker` te dit si le service tourne ; sinon, `sudo systemctl start docker` le démarre, et `sudo journalctl -u docker` te montre le journal du service pour savoir pourquoi il s'est arrêté. Si `is-enabled` indique `disabled`, le service ne démarrera pas tout seul au démarrage de la machine : `sudo systemctl enable docker` corrige cela.

## L'habitude de sécurité de la leçon

**Le groupe `docker` équivaut à `root` : on l'accorde en connaissance de cause, et uniquement à qui l'on donnerait `root`.** Cette habitude évite deux accidents concrets. Le premier est celui de la scène : « corriger » l'erreur de permissions en ouvrant le *socket* à tous, si bien que n'importe quel programme de la machine — y compris un programme téléchargé sans vérification — peut demander au daemon de monter ton disque. Le second est plus silencieux : mettre dans le groupe, « pour lui éviter des soucis », une autre personne ou un compte de service qui avait seulement besoin de consulter quelques journaux. Dans les deux cas, le dommage ne se voit pas tant que personne ne s'en sert.

Avec cette habitude en vient une autre, plus modeste, que cette leçon installe aussi : **la clé d'un dépôt ne vaut que pour ce dépôt** (`Signed-By`), et rien de ce que te demande `apt-key` ni un script téléchargé et exécuté sans être lu n'entre sur ta machine.

## Ce qui se fait de travers

**Installer `docker.io` « parce que c'est plus simple ».** C'est le paquet de ta distribution, pas celui de Docker : une autre version, un autre rythme de mises à jour, et les *plugins* sous d'autres noms. Si tu l'as et que tu installes en plus les paquets officiels, ils entrent en conflit. Ce cours a été mesuré avec les paquets officiels.

**Copier le guide d'installation de Debian, ou un vieux guide, sur Mint.** Ils utilisent `VERSION_CODENAME`, qui dans Mint est le nom de Mint. Le résultat est l'erreur de la section 1.5.2.

**Écrire `noble` manuellement « parce que ça marche ».** Ça marche aujourd'hui, mais cela lie la commande à une seule version : si tu la transmets à quelqu'un sous Mint 21 (`jammy`), ou si tu la réexécutes le jour où ton Mint change de base Ubuntu, elle écrit un mauvais nom. L'expression du guide tire la valeur de `/etc/os-release` au moment où on l'exécute. Attention : dans les deux cas, le fichier enregistre le nom déjà résolu ; si un jour tu changes de version de Mint, c'est la commande de la section 1.5.3 qu'il faut répéter, et non le fichier qu'il faut modifier à l'œil.

**`chmod 777 /var/run/docker.sock`.** Cela donne à toute la machine ce que le groupe `docker` donne à ses membres : `root`. Et cela ne dure même pas, car *systemd* recrée le *socket* au démarrage de la machine.

**Mettre n'importe qui dans le groupe `docker`.** C'est lui donner `root` (1.9).

**Utiliser `apt-key add`.** Il est obsolète (ton Mint 22 le fournit encore, c'est pourquoi il semble fonctionner), et il place la clé dans un trousseau valable pour tous les dépôts.

**Exécuter le script de `get.docker.com` sans le lire.** Le guide lui-même demande de vérifier les scripts téléchargés avant de les exécuter, et ne le recommande pas pour la production. Un script téléchargé puis exécuté avec `sudo` a `root` sur ta machine, tout comme le groupe `docker`.

**Oublier `-a` dans `usermod -aG`.** `usermod -G docker` te laisse **uniquement** dans le groupe `docker`, et hors de `sudo`.

**Considérer l'installation comme terminée sans la vérifier.** Qu'`apt` n'ait pas renvoyé d'erreur ne dit pas que le service tourne, ni qu'il démarre tout seul, ni que ton utilisateur peut l'utiliser. Les vérifications de `fig01_05.sh` prennent deux secondes.

## Exercices

Écris tes réponses et tes prédictions dans ton [journal de bord](bitacora.md) avant de consulter les solutions.

### Exercice 1 — Lis ton `os-release` (projet)

Exécute `fig01_01.sh` sur ton Mint. Avant de l'exécuter, prédis ce que diront `VERSION_CODENAME`, `UBUNTU_CODENAME` et `Suites`. Ensuite, réponds : si un collègue a LMDE 7, que diraient ces trois lignes sur sa machine, quel guide d'installation lui correspond et quel nom de code va dans sa ligne `Suites` ? Indice : exécute `./fig01_01.sh os-release-lmde-7.txt` dans `programas/01-instalacion/` et cherche une variable que Mint n'a pas. Le dernier bloc affichera l'architecture de ta machine, pas celle de la sienne.

### Exercice 2 — Diagnostique sans rien exécuter

Un collègue t'envoie trois messages d'erreur, un par jour. Ce sont les erreurs de cette leçon telles qu'il les verrait, avec le nom de sa version de Mint et le chemin du *socket* de sa machine. Pour chacune, donne la cause et la commande ou la modification qui la corrige :

1. `E: The repository 'https://download.docker.com/linux/ubuntu xia Release' does not have a Release file.`
2. `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`
3. `failed to connect to the docker API at unix:///var/run/docker.sock; check if the path is correct and if the daemon is running: dial unix /var/run/docker.sock: connect: no such file or directory`

### Exercice 3 — D'où vient chaque chose ?

Sans rien installer de nouveau, exécute ces deux commandes sur ton Mint (avec Docker déjà installé) et réponds aux questions :

```bash
apt-cache policy docker-ce docker.io | grep -E '^[a-z]|Installed|Candidate'
cat /etc/apt/sources.list.d/docker.sources
```

1. Quelle version de `docker-ce` as-tu installée, et laquelle serait installée si tu mettais à jour ?
2. As-tu `docker.io` installé ? Un dépôt le propose-t-il ?
3. Que dit la ligne `Suites`, et pourquoi ?

### Exercice 4 — La clé du daemon

Sans l'exécuter, réponds : si dans `fig01_07.sh` tu remplaçais `-v /etc:/anfitrion-etc:ro` par `-v /:/anfitrion` (sans `:ro`), que pourrait faire le conteneur ? Cite une chose concrète qu'il pourrait modifier sur ta machine. Ensuite, explique en deux phrases pourquoi `chmod 777 /var/run/docker.sock` est pire que de mettre ton utilisateur dans le groupe `docker`.

## Solutions

### Solution 1

Sur un Mint 22.x : `VERSION_CODENAME` indique le nom de ton Mint (`wilma`, `xia`, `zara` ou `zena`), `UBUNTU_CODENAME` indique `noble` et `Suites` indique `noble`, car la règle `${UBUNTU_CODENAME:-$VERSION_CODENAME}` préfère la première variable quand elle existe. Si ta ligne `Suites` a indiqué autre chose, vérifie que tu as bien Mint 22 et non une version antérieure : Mint 21 est construit sur Ubuntu Jammy et t'indiquerait `jammy`, qui est aussi une version prise en charge.

Sur LMDE 7, `VERSION_CODENAME=gigi`, `UBUNTU_CODENAME` donne `(no existe)` et c'est pourquoi on obtient `Suites: gigi`, un nom que Docker ne connaît pas. Mais son `os-release` contient `DEBIAN_CODENAME=trixie`, la variable que Mint n'a pas, et c'est elle qui va dans la ligne `Suites` du guide Debian : `${DEBIAN_CODENAME:-$VERSION_CODENAME}` (1.2.3). Voici la sortie de l'indice (exécution réelle · machine virtuelle, d'où le `arm64` ; elle se trouve dans `fig01_01.salida-lmde.txt`) :

```text
$ ./fig01_01.sh os-release-lmde-7.txt
== Lo que dice os-release-lmde-7.txt
NAME=LMDE
VERSION=7 (gigi)
ID=linuxmint  ID_LIKE=debian
VERSION_CODENAME=gigi
UBUNTU_CODENAME=(no existe)
DEBIAN_CODENAME=trixie

== El nombre en clave que va en Suites (la regla de la guía oficial de Ubuntu)
Suites: gigi

== Tu arquitectura, según dpkg (la de TU equipo: dpkg no lee ARCHIVO)
arm64
```

### Solution 2

1. **Le nom de code de Mint dans le dépôt.** `xia` est Mint 22.1. La ligne `Suites` de `/etc/apt/sources.list.d/docker.sources` contient le nom de Mint ; on réécrit le fichier avec la ligne du guide officiel (`${UBUNTU_CODENAME:-$VERSION_CODENAME}`) et on exécute `sudo apt update` (1.5.3).
2. **L'utilisateur n'est pas dans le groupe `docker`.** Le daemon tourne ; il manque la permission sur le *socket*. `sudo usermod -aG docker $USER`, fermer la session et se reconnecter (ou `newgrp docker`), en sachant que cela équivaut à lui donner `root` (1.8 et 1.9).
3. **Le daemon ne tourne pas.** Il n'y a pas de *socket* à ce chemin. `systemctl is-active docker` le confirme ; `sudo systemctl start docker` le démarre, `sudo journalctl -u docker` dit pourquoi il s'était arrêté et `sudo systemctl enable docker` le fait démarrer tout seul.

Si tu as confondu le 2 et le 3, relis la fin de chaque message : `permission denied` contre `no such file or directory`. La cause se trouve toujours dans les derniers mots.

### Solution 3

1. Dans le bloc de `docker-ce`, `Installed` est la version que tu as et `Candidate` celle qui serait installée avec `sudo apt upgrade`. Si elles sont identiques, tu es à jour.
2. Si tu as suivi la leçon, `docker.io` indiquera `Installed: (none)`. Son `Candidate` affichera probablement une version : le paquet existe dans les dépôts Ubuntu qu'utilise ton Mint, même si tu ne l'installes pas. C'est la raison pour laquelle il vaut mieux savoir d'où vient chaque paquet.
3. `Suites: noble`, car l'expression du guide a pris le `UBUNTU_CODENAME` de ton `/etc/os-release` : le dépôt de Docker a des dossiers par version d'Ubuntu, pas par version de Mint.

### Solution 4

Avec `/` monté en écriture, le conteneur, en tant que `root`, pourrait modifier n'importe quel fichier de ta machine : par exemple, ajouter un nouvel utilisateur avec des droits d'administrateur en modifiant `/etc/passwd` et `/etc/sudoers`, supprimer `/etc/shadow` ou remplacer un programme de `/usr/bin` par un autre. C'est la phrase du guide de sécurité : le conteneur « peut modifier le système de fichiers de ton hôte sans aucune restriction ».

`chmod 777` est pire parce qu'il ne donne pas ce pouvoir seulement à ton utilisateur, mais à **tous** les utilisateurs et programmes de la machine, sans qu'aucun ait besoin d'être dans un groupe ni d'en avoir conscience. Et en plus, cela ne dure pas : *systemd* recrée le *socket* avec ses permissions au redémarrage de la machine, si bien que celui qui l'utilise prend l'habitude de le répéter.

## Comment je sais que j'ai réussi

Coche chaque point uniquement s'il est vérifié sur **ta** machine :

- [ ] `fig01_01.sh` affiche `Suites: noble` (ou, sur LMDE, tu sais pourquoi ce n'est pas le cas et quel guide te correspond).
- [ ] `cat /etc/apt/sources.list.d/docker.sources` affiche le format à six champs de la section 1.5.1, avec `Suites: noble` (sur LMDE, `trixie` et l'URL `linux/debian`) et `Signed-By: /etc/apt/keyrings/docker.asc`, et `sudo apt update` n'affiche aucune ligne `E:`.
- [ ] `systemctl is-active docker` affiche `active` et `systemctl is-enabled docker` affiche `enabled`.
- [ ] `id -nG` inclut `docker`, et `docker version` sans `sudo` affiche la version du client **et** celle du daemon.
- [ ] `fig01_05.sh`, sans `sudo`, se termine avec `Hello from Docker!` dans le bloc 4, `srw-rw---- root docker /var/run/docker.sock` dans le bloc 5 et `0` dans le bloc 6. Ce qui ne se compare pas, parce que cela change : les versions, les identifiants et le *digest* du téléchargement, et l'architecture entre parenthèses.
- [ ] `fig01_06.sh` affiche le `permission denied` pour `nobody` et `sí` pour toi.
- [ ] `fig01_07.sh` affiche `Permission denied` dans le bloc 1 et `uid=0(root)` dans le bloc 2, et tu peux expliquer à voix haute pourquoi.
- [ ] À la fin, `docker ps -a --filter name=curso-docker-` n'affiche rien.
- [ ] Tu as noté dans ton journal de bord quelle version de Docker tu as installée et à quelle date.

## Résumé

Réponds sans regarder la leçon :

1. Pourquoi le cours installe-t-il les paquets de `download.docker.com` et non `docker.io` ?
2. Que dit `/etc/os-release` dans Mint qu'il ne dit pas dans Ubuntu, et pourquoi est-ce important pour installer Docker ?
3. Que fait l'expression `${UBUNTU_CODENAME:-$VERSION_CODENAME}` ?
4. Quels cinq paquets le guide installe-t-il, et à quelle pièce de la carte de la Leçon 0 correspond chacun ?
5. À quoi sert le champ `Signed-By`, et quel problème posait `apt-key` ?
6. Que signifie « does not have a Release file » lors de l'ajout du dépôt sur Mint ?
7. Quelle est la différence entre `permission denied` et `no such file or directory` quand on s'adresse au daemon ?
8. Pourquoi le groupe `docker` équivaut-il à `root`, et quelles alternatives existe-t-il ?
9. Pourquoi ufw ne protège-t-il pas les ports que publie Docker, et que fait ce cours à ce sujet ?

## Sources

Toutes consultées le 21 octobre 2026.

- [Docker, « Install Docker Engine on Ubuntu »](https://docs.docker.com/engine/install/ubuntu/) : les versions d'Ubuntu prises en charge, la note sur Linux Mint, l'avertissement sur le pare-feu, les paquets en conflit, le dépôt avec sa clé, les cinq paquets, comment fixer une version, le script de commodité, les vérifications, la mise à jour et la désinstallation.
- [Docker, « Install Docker Engine on Debian »](https://docs.docker.com/engine/install/debian/) : la ligne `Suites` avec `VERSION_CODENAME` et la note pour les distributions dérivées (LMDE).
- [Docker, « Linux post-installation steps for Docker Engine »](https://docs.docker.com/engine/install/linux-postinstall/) : le groupe `docker`, l'avertissement selon lequel il équivaut à `root`, l'erreur de `config.json`, le groupe à la demande avec mot de passe et le démarrage du service avec *systemd*.
- [Docker Engine security, « Docker daemon attack surface »](https://docs.docker.com/engine/security/#docker-daemon-attack-surface) : pourquoi qui contrôle le daemon contrôle l'hôte.
- [Docker, « Packet filtering and firewalls »](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw) : pourquoi les ports publiés contournent ufw.
- [Docker, « Rootless mode »](https://docs.docker.com/engine/security/rootless/) : ce qu'est le mode sans `root`.
- [Docker Desktop pour Linux](https://docs.docker.com/desktop/setup/install/linux/) : le fait que Docker Desktop sur Linux exécute une machine virtuelle.
- [Docker Engine 29, notes de version](https://docs.docker.com/engine/release-notes/29/) : la version 29.9.2 et sa date.
- [Linux Mint, toutes les versions](https://www.linuxmint.com/download_all.php) : les versions de Mint 22, leur base Ubuntu Noble et LMDE 7 sur Debian Trixie.
- [Dépôt de paquets de Linux Mint](http://packages.linuxmint.com/) : le paquet `base-files` `13ubuntu10mint22.3.0`, d'où provient le `/etc/os-release` de Mint 22.3 utilisé dans les exécutions.
- [sources.list(5), manuel d'`apt`](https://manpages.debian.org/trixie/apt/sources.list.5.en.html) : les formats sur une ligne et deb822.
- [apt-key(8), manuel d'`apt` sous Ubuntu 24.04](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html) : `apt-key` obsolète et jusqu'à quelle version il sera disponible.
- [Colima](https://github.com/abiosoft/colima) : la machine virtuelle des exécutions.

### Termes de cette leçon

| | |
|---|---|
| **`apt`** | le gestionnaire de paquets de Mint, Ubuntu et Debian ; il télécharge et installe des paquets depuis des dépôts |
| **deb822** | le format des fichiers `.sources` d'`apt` : un champ nommé par ligne |
| **`dpkg`** | le gestionnaire de paquets de bas niveau, sur lequel repose `apt` |
| **groupe `docker`** | le groupe Linux dont les membres peuvent parler au daemon sans `sudo` ; il équivaut à `root` |
| **LMDE** | *Linux Mint Debian Edition*, l'édition de Mint construite sur Debian et non sur Ubuntu |
| **clé (de dépôt)** | la partie publique d'une clé cryptographique avec laquelle `apt` vérifie que les paquets viennent bien de qui ils prétendent |
| **nom de code** | le nom court d'une version d'une distribution : `noble` pour Ubuntu 24.04, `zena` pour Mint 22.3 |
| ***plugin*** | un programme qui s'ajoute au client `docker` sous forme de sous-commande : `docker compose`, `docker buildx` |
| **dépôt** | un serveur qui publie des paquets avec un index signé |
| ***rootless*** | mode dans lequel le daemon et les conteneurs s'exécutent sans privilèges `root` |
| ***systemd*** | le programme qui démarre et surveille les services du système ; on le pilote avec `systemctl` |
| **ufw** | *Uncomplicated Firewall*, l'outil de pare-feu d'Ubuntu |

---

**Précédente :** [Leçon 0 — Ce qu'est un conteneur et ce qu'il n'est PAS](00-que-es-un-contenedor.md) · **Suivante :** [Leçon 2 — Les conteneurs au quotidien](02-contenedores-dia-a-dia.md)
