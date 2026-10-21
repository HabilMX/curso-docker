# Lição 1 — Instalar o Docker no Linux Mint

São 9h40 de uma segunda-feira e a demonstração com a equipe é às 11h. A tarefa é mostrar o `revisor` rodando em um contêiner, e no Linux Mint ainda não há Docker. Abre-se o primeiro tutorial que aparece, copiam-se cinco comandos, e o quarto responde em vermelho: `E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.` Tenta-se outro tutorial; esse instala um pacote chamado `docker.io` pela loja de software, e parece funcionar, até que `docker compose` diz que não existe. Às 10h25 aparece um terceiro tutorial que recomenda, para se livrar do `permission denied` que agora surge em cada comando, dar permissões `777` ao arquivo do *socket*. Funciona. E acaba-se de abrir a porta de `root` do computador para qualquer programa que rode nele. Nenhum dos três tutoriais explicou por que cada coisa acontecia. Esta lição faz a instalação uma única vez, em ordem, com cada erro provocado de propósito e explicado, para que da próxima vez leve vinte minutos, e não uma manhã.

**Tempo:** 90 min

**O que se constrói:** o ambiente do curso. Docker Engine instalado no Linux Mint a partir do repositório oficial do Docker, o usuário no grupo `docker` sabendo o que isso significa, e o primeiro contêiner, `hello-world`. Traz sete programas curtos, de diagnóstico e de verificação, em [`programas/01-instalacion/`](../programas/01-instalacion).

**O que se aprende:** que peças são instaladas e para que serve cada uma; por que o Linux Mint não é uma plataforma oficial do Docker e o que fazer a respeito (a palavra-chave é `UBUNTU_CODENAME`); remover os pacotes que conflitam com os oficiais; como se acrescenta um repositório ao `apt` com sua chave; como comprovar que a instalação funciona; e por que entrar no grupo `docker` equivale a ter `root`.

**De onde se parte.** Da [Lição 0](00-que-es-un-contenedor.md) traz-se o mapa: um contêiner é um processo isolado que roda sobre o kernel da máquina; o Docker são dois programas, o cliente `docker` e o daemon `dockerd`, que conversam por um *socket* UNIX em `/var/run/docker.sock`; e o daemon roda como `root`. Esta lição instala essas peças e obriga a encarar de frente a última frase. Do curso, em geral, supõe-se desenvoltura com o terminal e saber o que é `sudo`. Não é preciso ter usado o `apt` além de `apt install`: o que é necessário dele se explica aqui.

**O que esta lição não faz.** Não ensina os comandos do Docker um a um: isso é tema da [Lição 2](02-contenedores-dia-a-dia.md). Não instala o Docker Desktop, o aplicativo de desktop do Docker, e em 1.1 se diz por quê. Não instala o Docker em modo *rootless* (sem `root`), embora em 1.9 se explique o que é e quando conviria. O `revisor` ainda não aparece: esta lição prepara a máquina onde ele vai rodar, e empacotá-lo começa na Lição 3. E não cobre outras distribuições: para Ubuntu, Debian ou Fedora, a [documentação oficial](https://docs.docker.com/engine/install/) tem um guia para cada uma, e o que se aprende aqui serve para lê-lo.

**Sobre as execuções.** Esta lição é diferente das outras em um ponto, e convém dizer isso antes de tudo: **a instalação em si não foi executada em um Linux Mint**, porque a máquina em que o curso foi escrito é um Mac. Para não apresentar saídas inventadas, cada bloco de saída desta lição diz de onde vem, com um destes três rótulos:

| Rótulo | O que significa |
|---|---|
| **Execução real · Mint simulado** | Foi executado de verdade, em 21 de outubro de 2026, em um contêiner de Ubuntu 24.04 para `amd64` (a base do Mint 22, na arquitetura de uma máquina Intel ou AMD) que recebeu o arquivo `/etc/os-release` **do Linux Mint 22.3**, tirado do pacote oficial `base-files` do [repositório do Linux Mint](http://packages.linuxmint.com/) (versão `13ubuntu10mint22.3.0`; a cópia está em `programas/01-instalacion/os-release-mint-22.3.txt`). Esse arquivo é a única coisa que distingue o Mint nos passos da instalação, e por isso a simulação é fiel no que importa. O que **não** é igual: o contêiner não tem os repositórios próprios do Mint, então os `apt update` no Mint mostrarão também linhas de `packages.linuxmint.com`; e os pacotes que um desktop completo já traz (`curl`, por exemplo) precisaram ser instalados no contêiner. Antes de rodar os scripts, instalou-se `sudo` no contêiner, que o Mint já traz. |
| **Execução real · máquina virtual** | Foi executado de verdade, no mesmo dia, na máquina virtual Ubuntu 24.04.4 (arm64) que o [Colima](https://github.com/abiosoft/colima) sobe no Mac. Nessa máquina, o Docker 29.2.1 está instalado **com os mesmos pacotes oficiais** que se instalam no Mint (`docker-ce`, `containerd.io` e companhia, de `download.docker.com`), então as verificações pós-instalação ficam iguais. O que muda na máquina de quem segue a lição: as versões, e `arm64` dirá `amd64`. |
| **Da documentação** | Não foi executado: é o texto do [guia oficial de instalação para Ubuntu](https://docs.docker.com/engine/install/ubuntu/) ou dos [passos pós-instalação](https://docs.docker.com/engine/install/linux-postinstall/), consultados em 21 de outubro de 2026. É usado só onde não havia forma honesta de executá-lo. |

As versões: o curso foi planejado com Docker Engine 29.8.2 e Compose v5.6.0 (medidas em 7 de outubro de 2026). No dia destas execuções, o repositório oficial oferecia a **29.9.2**, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)), com Compose 5.6.0 e Buildx 0.38.1, e é isso que se instalaria naquele dia; a máquina virtual das execuções tinha a 29.2.1. Nada do que esta lição ensina muda entre essas versões, e em 1.7 se aprende a ver a instalada. Os programas estão em [`programas/01-instalacion/`](../programas/01-instalacion), cada um com sua saída salva ao lado.

## Ao terminar, será possível

- Ler `/etc/os-release` e dizer que codinome do Ubuntu corresponde ao Mint instalado, e por que esse e não o do Mint.
- Remover os pacotes que conflitam com o Docker Engine e explicar por que conflitam.
- Acrescentar o repositório oficial do Docker ao `apt`, explicando para que serve cada linha, inclusive a chave.
- Instalar os cinco pacotes do Docker Engine e dizer o que cada um faz.
- Comprovar com quatro comandos que o serviço está rodando, que versão está instalada e que é possível criar um contêiner.
- Ler o erro `permission denied while trying to connect to the docker API` e corrigi-lo colocando o usuário no grupo `docker`.
- Demonstrar com um comando por que o grupo `docker` equivale a `root`, e citar duas alternativas.

## O porquê antes do como

Instalar um programa no Linux costuma ser uma linha: `sudo apt install algo`. Com o Docker dá para fazer assim — o Mint oferece um pacote chamado `docker.io` — e o guia oficial do Docker pede exatamente o contrário: **removê-lo**. Por que tanta cerimônia?

Porque há duas fontes de pacotes do Docker e elas não são iguais. A primeira é a distribuição: o Ubuntu (e portanto o Mint) empacota o Docker com seus próprios nomes, no seu próprio ritmo, e muitas vezes em uma versão que fica para trás. A segunda é o Docker, a empresa, que publica seus pacotes em seu próprio repositório, `download.docker.com`, no mesmo dia em que publica cada versão. O guia oficial chama os primeiros de «não oficiais» e pede os segundos ([Docker, instalar no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)). Este curso usa os oficiais por um motivo prático: tudo o que ele ensina — o *plugin* do Compose, o builder Buildx, as versões mencionadas — foi medido com eles, e o que se lê na documentação do Docker se refere a eles.

O segundo motivo para a cerimônia é o próprio Mint. O Mint é feito sobre o Ubuntu, mas não é o Ubuntu, e o Docker não o suporta oficialmente. Isso não significa que não funcione: significa que, em um ponto exato da instalação, é preciso dizer ao `apt` que se comporte como se a máquina fosse um Ubuntu. É uma única linha, e é a que quebrou o primeiro tutorial da cena.

E o terceiro é a segurança. Ao terminar a instalação, o daemon roda como `root` e escuta em um *socket*. Quem consegue escrever nesse *socket* manda no daemon, e quem manda no daemon manda na máquina. Por isso a instalação termina com uma decisão tomada conscientemente: quem pode falar com o daemon.

A lição segue a ordem em que a instalação seria feita:

1. **O que vai ser instalado** (1.1).
2. **Mint não é Ubuntu: o codinome** (1.2).
3. **Antes de instalar: o firewall** (1.3).
4. **Remover o que conflita** (1.4).
5. **O repositório oficial**, com o erro do Mint provocado e corrigido (1.5).
6. **Instalar os pacotes** (1.6) e **verificar** (1.7).
7. **O grupo `docker`** (1.8) e **por que ele equivale a `root`** (1.9).
8. **Atualizar e desinstalar** (1.10).

Com esse destino em mente, isto é o que vai aparecer no final de 1.7, quando tudo estiver no lugar (execução real · máquina virtual):

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

## Os conceitos

### 1.1 O que vai ser instalado

#### 1.1.1 As cinco peças

O guia oficial instala cinco pacotes com um único comando. Convém saber o que é cada um antes de instalá-los, porque cada um corresponde a uma peça do mapa da Lição 0:

| Pacote | O que traz | No mapa da Lição 0 |
|---|---|---|
| `docker-ce` | o daemon, `dockerd` (*CE* é *Community Edition*, a edição gratuita e aberta) | o servidor que faz o trabalho |
| `docker-ce-cli` | o cliente, o comando `docker` que se digita | o cliente |
| `containerd.io` | `containerd`, que administra os contêineres por baixo do daemon, e `runc`, que os cria | a cadeia que termina no `containerd-shim-runc-v2` que apareceu como pai de um contêiner |
| `docker-buildx-plugin` | Buildx, o builder de imagens | vai ser usado ao escrever o primeiro Dockerfile |
| `docker-compose-plugin` | Compose, que sobe vários contêineres a partir de um arquivo | o subcomando `docker compose` |

Os dois últimos são *plugins*: não são programas chamados pelo nome, e sim subcomandos acrescentados ao cliente. Por isso se escreve `docker compose`, com espaço, e não `docker-compose`, com hífen. O com hífen é o Compose antigo, um programa à parte, e seu pacote está na lista dos que precisam ser removidos (1.4).

Repare no nome `containerd.io`. O Docker Engine precisa de `containerd` e `runc`, e a distribuição também os oferece com esses nomes. O guia oficial explica: o Docker os empacota juntos em um só, `containerd.io`, e se os da distribuição foram instalados antes, é preciso removê-los para que não conflitem ([Docker, instalar no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

#### 1.1.2 O que não vai ser instalado, e por quê

**Docker Desktop.** É um aplicativo de desktop do Docker que também existe para Linux, e o guia o apresenta como «a forma mais fácil e rápida de começar». O curso não o usa por um motivo já conhecido: segundo sua própria documentação, «o Docker Desktop no Linux roda uma máquina virtual» ([Docker Desktop para Linux](https://docs.docker.com/desktop/setup/install/linux/)). Lembre-se de 0.2: o motivo para usar Linux como sistema de referência é que os contêineres rodam direto sobre o kernel, sem uma camada no meio. O Docker Desktop coloca essa camada de volta. Se um dia ele for instalado, já se sabe por que `ps` no Mint não mostra os processos dos contêineres: eles estão dentro de outra máquina.

**O script de conveniência.** O Docker publica em `get.docker.com` um script que detecta a distribuição e instala tudo de uma vez. O guia diz que ele «não é recomendado para ambientes de produção», que instala dependências e recomendações sem perguntar, que quase não deixa escolher nada e que não foi feito para atualizar uma instalação existente ([Docker, script de conveniência](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)). Há outro motivo, mais simples: em um curso, um script que faz tudo tira justamente o que se veio aprender. Se ele aparecer em um tutorial, já se sabe o que é.

**O modo *rootless*.** É uma forma de rodar o daemon sem `root`. Ele aparece em 1.9, como alternativa; o curso usa o modo normal, que é o que o guia instala e o que se encontra em quase qualquer servidor.

### 1.2 Mint não é Ubuntu: o codinome

#### 1.2.1 O que o Docker diz do Mint

O guia oficial para Ubuntu lista as versões que suporta: 26.10, 26.04, 24.04 e 22.04, todas de 64 bits. E logo abaixo traz esta nota: «a instalação em distribuições derivadas do Ubuntu, como o Linux Mint, não tem suporte oficial (embora possa funcionar)» ([Docker, instalar no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

«Sem suporte oficial» tem um significado preciso: o Docker não testa seus pacotes no Mint e não publica uma pasta para o Mint em seu repositório. O que existe é uma pasta para cada versão do Ubuntu. E o Mint 22 é construído sobre os pacotes do Ubuntu 24.04. A própria página de downloads do Linux Mint diz isso na coluna «Package base»: Mint 22, 22.1, 22.2 e 22.3 têm como base o «Ubuntu Noble», com suporte até abril de 2029 ([Linux Mint, todas as versões](https://www.linuxmint.com/download_all.php)). *Noble* é o codinome do Ubuntu 24.04. Então o truque é este: no Mint 22 usam-se os pacotes do Docker **para o Ubuntu Noble**, porque são os que correspondem às bibliotecas do sistema.

#### 1.2.2 O arquivo que diz tudo: `/etc/os-release`

Cada distribuição Linux descreve quem é em um arquivo de texto, `/etc/os-release`. É um arquivo de variáveis de *shell*: linhas com `NOME=valor`, que qualquer script pode carregar. `fig01_01.sh` o lê e diz que codinome usar. Não muda nada na máquina; só lê:

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

Execução real · Mint simulado:

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

Com o Mint 22, 22.1 ou 22.2, `VERSION` e `VERSION_CODENAME` dirão `wilma`, `xia` ou `zara`; todo o resto sai igual. Antes de ler a saída, as linhas do script que não são óbvias. O ponto sozinho (`. "$ARCHIVO"`) carrega o arquivo no script, igual a `source`: depois dessa linha, `$NAME` ou `$UBUNTU_CODENAME` têm os valores do arquivo. `${VERSION:-}` quer dizer «o valor de `VERSION`, ou nada se não existir»; sem isso, `set -u` interromperia o script ao encontrar uma variável inexistente. E `dpkg --print-architecture` pergunta ao gerenciador de pacotes para que processador o sistema foi feito; como ele pergunta ao sistema e não ao arquivo, se outro `os-release` for passado como argumento, esse último bloco continua mostrando a arquitetura da própria máquina.

Agora a saída, que tem a chave de toda a lição:

1. **O Mint diz que é o Mint.** `NAME=Linux Mint`, `ID=linuxmint`. Se um programa pergunta «é Ubuntu?» olhando `ID`, a resposta é não.
2. **Mas diz de quem descende.** `ID_LIKE=ubuntu debian` significa «pareço com o Ubuntu, e o Ubuntu parece com o Debian».
3. **Há dois codinomes.** `VERSION_CODENAME=zena` é o do Mint 22.3. `UBUNTU_CODENAME=noble` é o da versão do Ubuntu sobre a qual ele foi feito. O segundo existe justamente para casos como este. (`DEBIAN_CODENAME` não existe no Mint nem no Ubuntu; em 1.2.3 aparece quem a traz.)
4. **A regra do guia oficial escolhe o correto.** A expressão `${UBUNTU_CODENAME:-$VERSION_CODENAME}` se lê «use `UBUNTU_CODENAME` se existir; se não, `VERSION_CODENAME`». No Mint ela existe, e sai `noble`. Em um Ubuntu de verdade, as duas variáveis valem o mesmo, então tanto faz qual se usa. Essa expressão é, letra por letra, a que o guia oficial traz na linha `Suites` do repositório (1.5).
5. **A arquitetura é `amd64`**, a dos processadores Intel e AMD de 64 bits, que é a de quase qualquer computador com Mint. É o valor que vai no campo `Architectures` do repositório.

Para ver o outro lado, este é o mesmo script na máquina virtual das execuções, que é um Ubuntu de verdade (execução real · máquina virtual; está em `fig01_01.salida-ubuntu.txt`):

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

No Ubuntu, os dois codinomes coincidem. No Mint, não. Toda a diferença de instalar no Mint cabe nessas duas linhas.

#### 1.2.3 E se a máquina tiver LMDE?

O Linux Mint tem uma segunda edição, o **LMDE** (*Linux Mint Debian Edition*), que não é feito sobre o Ubuntu, e sim sobre o Debian. A página de downloads do Mint lista o LMDE 7, «Gigi», com base «Debian Trixie» ([Linux Mint, todas as versões](https://www.linuxmint.com/download_all.php)). Com LMDE, esta lição serve em tudo menos no repositório: é preciso seguir o [guia oficial para Debian](https://docs.docker.com/engine/install/debian/), que usa `https://download.docker.com/linux/debian` (também para a chave: `…/linux/debian/gpg`).

Na linha `Suites`, o guia do Debian usa `$VERSION_CODENAME`, que no LMDE 7 vale `gigi`, um nome que o Docker não tem: é o mesmo erro de 1.5.2 em versão Debian. O guia só diz que em uma distribuição derivada pode ser preciso substituir o codinome pelo da versão do Debian correspondente. Não é preciso escrevê-lo à mão: o LMDE traz em seu `/etc/os-release` uma variável feita para isso, `DEBIAN_CODENAME`, assim como o Mint traz `UBUNTU_CODENAME`. É o que diz o `os-release` do pacote oficial `base-files` do LMDE 7 (versão `13.8+lmde1`, do [repositório do Linux Mint](http://packages.linuxmint.com/); a cópia está em `programas/01-instalacion/os-release-lmde-7.txt`). A linha fica assim:

```text
Suites: $(. /etc/os-release && echo "${DEBIAN_CODENAME:-$VERSION_CODENAME}")
```

É um fragmento, não um programa: vai no lugar da linha `Suites` do bloco do guia do Debian. Para saber qual edição está instalada, `fig01_01.sh` responde: `ID` vale `linuxmint` nas duas, mas no LMDE `NAME=LMDE`, `ID_LIKE=debian`, sem `ubuntu`, e aparece `DEBIAN_CODENAME`.

> [!WARNING]
> Com LMDE, **não rode `fig01_03.sh` nem `fig01_04.sh`**: os dois apontam para o repositório do Ubuntu, e `fig01_04.sh` escreveria `Suites: gigi` contra ele e deixaria o `apt update` falhando. Siga o guia do Debian (inclusive sua própria lista de pacotes em conflito) com a linha `Suites` acima, e retome a lição em 1.7. Nas verificações, onde estiver `noble`, aparecerá `trixie`, e nas versões dos pacotes, `debian.13~trixie`.

> [!NOTE]
> 🔧 **Observação de engenharia 1.1**
> «Sem suporte oficial» não é «não funciona», nem «funciona igual». É «ninguém além de nós vai verificar se funciona». Ao usar algo fora do que o fornecedor suporta, anote exatamente o que foi feito de diferente (aqui: um codinome) para que, se algo falhar, se saiba por onde começar.

### 1.3 Antes de instalar: o firewall

O guia oficial abre com uma advertência de segurança, antes de qualquer comando, e convém lê-la antes de instalar, e não no dia em que ela morder: quem usa **ufw** ou **firewalld** para administrar o firewall deve saber que, «ao expor as portas de um contêiner com o Docker, essas portas ignoram as regras do firewall» ([Docker, instalar no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)).

O *ufw* (*Uncomplicated Firewall*) é a ferramenta de firewall que vem com o Ubuntu, e que pode estar ativa no Mint. A página do Docker sobre firewalls explica o mecanismo: ao publicar uma porta de um contêiner, o tráfego é desviado na tabela `nat` do kernel, **antes** de chegar às cadeias `INPUT` e `OUTPUT` que o ufw usa; os pacotes são roteados antes que as regras do firewall possam ser aplicadas, «na prática ignorando a configuração» ([Docker, filtragem de pacotes e firewalls](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw)).

O que isso significa na prática: com `ufw deny 8080` e um contêiner que publica a porta 8080 em todas as interfaces, essa porta fica aberta para a rede. O ufw nem fica sabendo. Por isso, neste curso, as portas são publicadas só em `127.0.0.1`, o endereço que só a própria máquina alcança: ela não depende do firewall para ficar fechada, porque nunca é aberta para a rede. A Lição 2 deve mostrar isso com uma porta aberta de propósito.

A mesma advertência traz um segundo ponto, mais técnico: o Docker só é compatível com `iptables-nft` e `iptables-legacy`, e as regras de firewall escritas diretamente com `nft` não têm suporte em um sistema com Docker. Quem administra regras manualmente deve escrevê-las com `iptables` ou `ip6tables` e colocá-las na cadeia `DOCKER-USER`. Se este parágrafo não fizer sentido, o mais provável é que ele não se aplique: é para quem já tem um firewall escrito manualmente.

### 1.4 Remover o que conflita

#### 1.4.1 Os pacotes em conflito

Antes de instalar os pacotes oficiais, é preciso remover os não oficiais, porque os dois conjuntos trazem arquivos com os mesmos nomes (o comando `docker`, o daemon, `containerd`) e o `apt` não pode ter os dois ao mesmo tempo. O guia dá a lista exata ([Docker, instalar no Ubuntu](https://docs.docker.com/engine/install/ubuntu/)):

| Pacote | O que é |
|---|---|
| `docker.io` | o Docker empacotado pelo Ubuntu |
| `docker-compose` | o Compose antigo, o programa com hífen |
| `docker-compose-v2` | o Compose novo, empacotado pelo Ubuntu |
| `docker-doc` | a documentação do pacote do Ubuntu |
| `docker-buildx` | Buildx, empacotado pelo Ubuntu |
| `podman-docker` | um imitador: faz o comando `docker` chamar o Podman, outra ferramenta de contêineres |
| `containerd`, `runc` | as versões do Ubuntu do que `containerd.io` traz junto |

Se nada do Docker foi instalado antes, o mais provável é que nenhum deles esteja presente. O guia adverte: «o `apt` pode informar que nenhum desses pacotes está instalado».

#### 1.4.2 O comando, peça por peça

`fig01_02.sh` primeiro pergunta quais estão instalados e depois roda o comando do guia, copiado tal como está:

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

Execução real · Mint simulado (o sistema recém-instalado, sem nada do Docker):

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

O `…` substitui seis linhas idênticas às de cima; a saída completa está em `fig01_02.salida.txt`. O número de pacotes a atualizar (`3 not upgraded`) depende da máquina.

O comando do guia se lê de dentro para fora:

1. `dpkg --get-selections <paquetes>` pergunta ao `dpkg`, o gerenciador de pacotes de baixo nível, por cada pacote da lista. Para os instalados, escreve uma linha com o nome, uma tabulação e a palavra `install`. Para os não instalados, reclama na saída de erro: `no packages found matching …`. Essas reclamações não são um problema; são a resposta «não está instalado».
2. `| cut -f1` fica com a primeira coluna de cada linha, ou seja, só os nomes.
3. `$( … )` coloca esses nomes na linha de comando de `sudo apt remove`.

Assim, `apt remove` recebe só os pacotes que **estão** instalados. Se não houver nenhum, recebe uma lista vazia e diz `0 to remove`. Se houvesse, por exemplo, `docker.io`, ele mostraria o que vai remover e perguntaria se deve continuar: leia a lista antes de responder que sim.

O aviso `WARNING: apt does not have a stable CLI interface` aparece porque, nessa execução, a saída do `apt` não ia para um terminal, e sim para um arquivo: foi assim que as saídas do curso foram salvas. O `apt` é a ferramenta para pessoas, e avisa que seu formato pode mudar quando quem lê sua saída é outro programa. Rodando o script no terminal, esse aviso não aparece, e em compensação aparecem `Done` no final de `Reading package lists...` e barras de progresso. Para scripts existe o `apt-get`, que é estável; em 1.5.3 ele é usado.

#### 1.4.3 O que `apt remove` não remove

O guia adverte algo que importa para quem já teve Docker: as imagens, contêineres, volumes e redes que vivem em `/var/lib/docker/` **não são apagados** ao desinstalar. Desinstalar o pacote remove os programas; os dados ficam. Para começar do zero de verdade, 1.10 diz como. Se não, os pacotes novos vão encontrar esses dados e usá-los.

### 1.5 O repositório oficial

#### 1.5.1 O que é um repositório do `apt`

O `apt` não baixa programas de qualquer lugar: baixa de uma lista de **repositórios**, servidores que publicam pacotes com um índice assinado. O Mint já traz os do Ubuntu e os do Mint. Acrescentar o do Docker são duas coisas:

- **A chave.** O Docker assina seu índice com uma chave criptográfica. O `apt` precisa da parte pública dessa chave para comprovar que o que baixa vem do Docker e que ninguém o alterou no caminho.
- **A fonte.** Um arquivo em `/etc/apt/sources.list.d/` que diz ao `apt` onde está o repositório, que parte dele corresponde à máquina e com que chave ele é verificado.

Esta é a parte do guia oficial, completa (da documentação). **Não digite ainda**: nesta lição ela vai ser executada em dois tempos. `fig01_03.sh` faz a parte da chave igual ao guia e escreve a fonte com o erro do Mint; `fig01_04.sh` reescreve a fonte corretamente. Para não provocar o erro na máquina, digite este bloco como está, pule a seção 1.5.2 e, em 1.5.3, leia a saída em vez de rodar o script:

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

Linha por linha:

- `sudo apt update` atualiza os índices dos repositórios já configurados, para que o próximo `apt install` encontre as versões em dia.
- `ca-certificates` traz os certificados das autoridades que assinam os sites HTTPS, e `curl` baixa arquivos. Em um Mint de desktop, quase certamente já estão instalados; pedi-los não faz mal.
- `install -m 0755 -d /etc/apt/keyrings` cria a pasta onde ficam as chaves de repositórios externos, com permissões `0755`: o dono (`root`) escreve, todos leem.
- `curl -fsSL … -o /etc/apt/keyrings/docker.asc` baixa a chave pública do Docker. `-f` faz falhar se o servidor responder com erro, em vez de salvar uma página de erro como se fosse a chave; `-s` e `-S` o silenciam, exceto nos erros; `-L` segue redirecionamentos.
- `chmod a+r` faz com que todos possam ler a chave, porque o `apt` a lê com um usuário sem privilégios.
- `sudo tee … <<EOF` escreve o arquivo da fonte. Usa-se `tee` com `sudo` porque um redirecionamento `>` é feito pelo *shell*, que não é `root`, e não conseguiria escrever em `/etc`. O que vai entre `<<EOF` e `EOF` é o conteúdo, e as `$( … )` são substituídas **antes** de escrevê-lo.

O arquivo `docker.sources` está no formato **deb822**: um campo por linha, com nome. O manual do `apt` o descreve junto ao formato antigo, de uma única linha (`deb [opciones] url versión componente`), e diz que a intenção é que o deb822 vire aos poucos o formato padrão ([sources.list(5)](https://manpages.debian.org/trixie/apt/sources.list.5.en.html)). Há tutoriais com um arquivo `docker.list` de uma linha; funciona igual, é a forma anterior. Os campos:

| Campo | Valor | O que significa |
|---|---|---|
| `Types` | `deb` | pacotes já compilados (não código-fonte) |
| `URIs` | `https://download.docker.com/linux/ubuntu` | onde está o repositório; repare no `ubuntu` no final |
| `Suites` | o codinome | a versão do Ubuntu cujos pacotes se quer; **aqui está a questão do Mint** |
| `Components` | `stable` | só versões estáveis, não de teste |
| `Architectures` | `amd64` no Mint | para que processador |
| `Signed-By` | `/etc/apt/keyrings/docker.asc` | com que chave **este** repositório é verificado, e só este |

Esse último campo merece mais uma linha. Antes, as chaves de repositórios externos eram acrescentadas com `apt-key` a um chaveiro comum, e uma chave servia para verificar **qualquer** repositório: a do Docker poderia ter assinado um pacote que dissesse vir do Ubuntu. O `apt-key` está obsoleto: o manual da versão do `apt` do Ubuntu 24.04, a base do Mint 22, diz que ele estará disponível pela última vez no Debian 12 e no Ubuntu 24.04 ([apt-key(8), Ubuntu noble](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html)). O Mint 22 ainda o traz, e por isso um tutorial antigo com `apt-key add` parece funcionar: funciona, mas deixa a chave do Docker valendo para todos os repositórios. Com `Signed-By`, a chave do Docker só vale para o repositório do Docker. Se um tutorial mandar usar `apt-key add`, ele é de antes da adoção do `Signed-By`, e não deve ser seguido.

#### 1.5.2 O erro do Mint, provocado

Agora o erro da cena, de propósito. `fig01_03.sh` é o mesmo passo do guia com **uma única diferença**: em `Suites` usa `VERSION_CODENAME` em vez de `${UBUNTU_CODENAME:-$VERSION_CODENAME}`. É assim que muitos guias antigos para Ubuntu o escrevem, com `$VERSION_CODENAME` ou com `$(lsb_release -cs)`, que no Mint também responde o nome do Mint (ele o tira de `DISTRIB_CODENAME` em `/etc/lsb-release`); e é assim que o guia oficial **para Debian** o escreve, que não tem o problema porque o Debian não tem `UBUNTU_CODENAME` ([Docker, instalar no Debian](https://docs.docker.com/engine/install/debian/)). Quem copia do guia errado, no Mint, cai aqui.

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

Execução real · Mint simulado. É a saída a partir da linha escrita pelo `tee` até o final; antes vêm as de `apt update` e a instalação do `curl`, que estão completas em `fig01_03.error-esperado.txt`:

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

O endereço IP entre colchetes é o do servidor do Docker que respondeu e muda de uma execução para outra. As linhas `Hit:` são os repositórios do Ubuntu, que respondem; a ordem em que aparecem pode variar. O resto é estável, exceto o codinome se o Mint não for o 22.3. No terminal aparecerão também linhas `Hit:` dos repositórios do Mint.

Lê-se de cima para baixo:

1. `tee` mostra o que escreveu, e ali está o problema à vista: `Suites: zena`.
2. `apt update` pede ao servidor do Docker o índice da versão `zena` do Ubuntu. Primeiro procura `InRelease` (o índice com a assinatura dentro) e o ignora (`Ign`) porque não existe; depois procura `Release` e o servidor responde **404**, «não encontrado».
3. O erro final diz em palavras: o repositório `… zena Release` não tem um arquivo `Release`. Traduzindo: **não existe uma versão do Ubuntu chamada `zena`**. E é verdade: `zena` é o Mint.
4. O `apt` sai com código 100, seu código de erro geral.

Um detalhe que engana: a chave foi baixada corretamente e o servidor respondeu. Não é um problema de rede, nem de permissões, nem da chave. É um nome errado em um arquivo de texto.

#### 1.5.3 A correção

Corrige-se reescrevendo a fonte com a linha do guia oficial. `fig01_04.sh` faz isso (não baixa a chave de novo: usa a que `fig01_03.sh` deixou em `/etc/apt/keyrings/docker.asc`; sem ela, `apt update` falharia pela chave ausente), atualiza os índices e, em vez de instalar, pergunta: de onde viria o `docker-ce` e em que versão?

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

Execução real · Mint simulado:

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

Mudam na máquina de quem segue a lição: as versões (as deste bloco são as de 21 de outubro de 2026), o número de pacotes a atualizar e, sobretudo, o total da última linha. O contêiner da simulação é um Ubuntu mínimo, quase vazio, e faltam a ele dezenas de peças que um Mint de desktop já tem (`systemd`, `perl`, `git`…); no Mint, o total será bem menor. E essas linhas de `apt update` são da **segunda** vez que o script rodou, com os índices já baixados (`Hit`). Na primeira vez, as do Docker saíram como downloads: `Get:1 https://download.docker.com/linux/ubuntu noble InRelease [48.5 kB]` e, depois, a lista de pacotes de `noble/stable amd64`.

O que a saída diz:

1. **`Suites: noble`**. O mesmo Mint, agora com o nome do Ubuntu.
2. **`apt update` já não reclama**, e entre os repositórios aparece `https://download.docker.com/linux/ubuntu noble`.
3. **`apt-cache policy`** responde à pergunta «se eu instalar `docker-ce`, que versão e de onde?». `Installed: (none)`: não está instalado. `Candidate`: a versão que seria instalada. E na tabela, a origem: `download.docker.com`, `noble/stable`. Se em vez disso aparecesse uma origem de `archive.ubuntu.com`, algo deu errado: não existe um `docker-ce` no Ubuntu, mas existe um `docker.io`, e por isso convém verificar de onde vem cada coisa antes de instalar.
4. **O número da versão** se lê assim: `5:` é a «época», um contador que só serve para o `apt` ordenar as versões corretamente; `29.9.2` é a versão do Docker; `-1~ubuntu.24.04~noble` diz para que distribuição foi empacotado.
5. **A simulação** mostra seis pacotes do Docker, não cinco. O sexto, `docker-ce-rootless-extras`, não foi pedido: o `apt` o traz como *recomendação* de `docker-ce`. São as ferramentas do modo *rootless* (1.9); não atrapalham.

`apt-get install -s` (de *simulate*) calcula tudo o que uma instalação faria e imprime em linhas `Inst`, sem mexer em nada. É um bom costume antes de qualquer instalação grande: ver o que vai entrar.

### 1.6 Instalar os pacotes

Com o repositório no lugar, a instalação é um único comando (da documentação):

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

O `apt` mostrará a lista de pacotes, quanto vai baixar e quanto espaço vai usar, e perguntará se deve continuar. A saída deste comando **não é colada aqui** porque não foi executada em um Mint de verdade, e na máquina de cada um depende do que já está instalado. O que procurar nela: que entre os pacotes novos estejam os seis da simulação acima, e que no final não haja linhas começando com `E:`.

**Fixar uma versão.** O comando acima instala a mais recente. Para uma versão exata — para que a máquina coincida com um servidor, por exemplo —, o guia dá a receita (da documentação):

```bash
apt list --all-versions docker-ce
VERSION_STRING=5:29.8.2-1~ubuntu.24.04~noble
sudo apt install docker-ce=$VERSION_STRING docker-ce-cli=$VERSION_STRING containerd.io docker-buildx-plugin docker-compose-plugin
```

O primeiro comando lista as versões disponíveis, como fez `fig01_04.sh`. O segundo guarda em uma variável a desejada, com seu número completo, época incluída. O terceiro instala `docker-ce` e `docker-ce-cli` nessa versão exata: `paquete=versión` é a forma de o `apt` pedir uma versão precisa. A 29.8.2 do exemplo é justamente a versão com que este curso foi planejado; não é preciso fixá-la para acompanhá-lo.

**O que a instalação faz além de copiar arquivos.** No Debian e no Ubuntu, o serviço do Docker é configurado para iniciar sozinho, agora e toda vez que a máquina for ligada: os passos pós-instalação dizem isso, «no Debian e no Ubuntu, o serviço do Docker inicia com o sistema por padrão» ([Docker, passos pós-instalação](https://docs.docker.com/engine/install/linux-postinstall/)). E o grupo `docker` é criado, vazio. As duas coisas são verificadas em 1.7 e em 1.8.

### 1.7 Verificar

#### 1.7.1 O que o guia pede

O guia oficial termina com duas verificações (da documentação):

```bash
sudo systemctl status docker
sudo docker run hello-world
```

`systemctl status docker` pergunta ao *systemd*, o programa que inicia e vigia os serviços do sistema, como está o serviço `docker`. Se ele não estiver rodando, o guia diz para iniciá-lo com `sudo systemctl start docker`. E `sudo docker run hello-world` cria o primeiro contêiner. Repare no `sudo` nos dois: recém-instalado, o usuário ainda não pode falar com o daemon. Isso se corrige em 1.8, e por isso as verificações deste curso são feitas sem `sudo`, depois.

#### 1.7.2 As verificações do curso

`fig01_05.sh` junta tudo o que se quer saber de uma instalação recém-feita. Rode-o **depois** de 1.8, sem `sudo`:

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

Execução real · máquina virtual:

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

O que muda na máquina de quem segue a lição: as versões (instalando em 21 de outubro de 2026, apareceriam 29.9.2, Compose v5.6.0 e Buildx v0.38.1), os identificadores de camada e o *digest* da imagem, e `(arm64v8)`, que dirá `(amd64)`. Se `hello-world` já tinha rodado antes, o bloco de download não aparece: a imagem já está na máquina.

Bloco por bloco:

1. **`active` e `enabled`.** `is-active` responde se o serviço está rodando **agora**; `is-enabled`, se vai iniciar **sozinho** na próxima vez que a máquina for ligada. São perguntas diferentes e convém fazer as duas: um serviço pode estar rodando porque foi iniciado manualmente e não voltar depois de reiniciar.
2. **Os cinco pacotes**, cada um com sua versão e o sufixo `ubuntu.24.04~noble`, que diz que vêm do repositório oficial para Noble. `dpkg-query -W` pergunta por pacotes instalados com o formato pedido.
3. **As versões.** `docker version` informa duas, a do cliente e a do daemon, porque são dois programas (Lição 0, seção 0.6). `API: 1.53` é a versão da língua em que eles conversam. `docker compose version` e `docker buildx version` confirmam que os dois *plugins* estão no lugar: se `docker compose` respondesse `docker: unknown command: docker compose`, faltaria `docker-compose-plugin` (com o Docker 29.2.1, é assim que o cliente responde a um subcomando que não conhece: `docker noexiste` imprimiu `docker: unknown command: docker noexiste`).
4. **O primeiro contêiner.** O daemon não encontrou a imagem `hello-world` na máquina (`Unable to find image … locally`), baixou-a do Docker Hub, criou um contêiner, rodou-o e, como foi pedido `--rm`, apagou-o ao terminar. O texto que o contêiner imprime descreve, em quatro passos, o caminho do mapa da Lição 0: o cliente fala com o daemon, o daemon baixa a imagem, cria um contêiner e devolve sua saída. `hello-world` é a única imagem deste curso usada sem versão fixa (`latest`), porque é a única tag que ela publica.
5. **O *socket*.** `srw-rw----`: o `s` diz que é um *socket*; `rw-` para o dono, `root`; `rw-` para o grupo, `docker`; e `---` para todos os outros. Essa última coluna de hífens é a que impede um usuário fora do grupo de falar com o daemon (1.8).
6. **Zero contêineres do curso.** `--rm` fez seu trabalho. Todos os nomes deste curso começam com `curso-docker-` para que seja possível encontrar e apagar o que é do curso sem mexer em mais nada; é um costume que convém ter desde o primeiro contêiner.

### 1.8 O grupo `docker`

#### 1.8.1 O erro de permissões

Com o Docker recém-instalado, digitar `docker ps` sem `sudo` mostra o erro desta seção. `fig01_06.sh` o provoca sem tirar ninguém do grupo: usa o usuário `nobody`, que existe em qualquer Linux e não pertence a nenhum grupo útil:

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

Execução real · máquina virtual:

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

Esta saída é estável. A última linha dirá `no` se o passo de 1.8.2 ainda não foi feito, e esse é o estado em que o erro aparece com o próprio usuário.

`sudo -u nobody` roda o comando como o usuário `nobody`. Esse usuário só está no grupo `nogroup`, então, diante do *socket* `srw-rw---- root docker`, cai na terceira coluna: sem permissão para nada. A mensagem se lê igual à da Lição 0, com outra causa no final: o cliente **encontrou** o *socket* em `/var/run/docker.sock` (o daemon está ali), mas não tem permissão para abri-lo. Compare com o `no such file or directory` da Lição 0, que significava «não há daemon nesse caminho». Duas causas diferentes, duas correções diferentes: aqui não adianta reiniciar o serviço.

#### 1.8.2 Entrar no grupo

Há três formas de se livrar do erro, e convém conhecê-las antes de escolher:

1. **Usar `sudo docker` sempre.** Funciona e não dá nenhuma permissão nova, mas é incômodo, e os arquivos de configuração do cliente acabam pertencendo a `root` (isso aparece em 1.8.3).
2. **Entrar no grupo `docker`.** É o que quase todo mundo faz e o que este curso faz. A partir desse momento, qualquer programa que rode com o nosso usuário pode falar com o daemon.
3. **O grupo sob demanda**, com senha (1.9.3).

A forma 2 são três passos (da documentação):

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

- `groupadd docker` cria o grupo. O guia avisa que em algumas distribuições o pacote já o cria ao instalar; no Ubuntu e no Mint é assim, e o comando vai dizer `groupadd: group 'docker' already exists`. Não é um erro de verdade: o grupo já existia.
- `usermod -aG docker $USER` acrescenta o usuário ao grupo. O `-a` (*append*) é importante: sem ele, `-G` **substitui** todos os grupos do usuário por `docker`, e ele ficaria fora do `sudo`, entre outros. `$USER` é o nome do usuário.
- A mudança não se aplica às sessões já abertas, porque os grupos de um processo são fixados ao iniciar a sessão. O guia pede para **encerrar a sessão e entrar de novo** (e, se o Linux roda em uma máquina virtual, talvez reiniciá-la). `newgrp docker` é o atalho: abre um *shell* novo com o grupo já aplicado, só naquele terminal.

Depois, `id -nG` deve incluir a palavra `docker`, e `docker run hello-world` deve funcionar sem `sudo`. Esse é o momento de rodar `fig01_05.sh`.

#### 1.8.3 O erro de depois: `config.json`

Se antes de entrar no grupo foram rodados comandos com `sudo docker`, isto pode aparecer ao usar `docker` sem `sudo` (da documentação; `user` é o usuário):

```text
WARNING: Error loading config file: /home/user/.docker/config.json -
stat /home/user/.docker/config.json: permission denied
```

O cliente guarda sua configuração na pasta `.docker` do diretório pessoal. Quando ele rodou com `sudo`, essa pasta foi criada com dono `root`, e agora o usuário não consegue lê-la. O guia dá duas correções: apagar `~/.docker/` (ela é recriada sozinha, mas perde-se a configuração que tivesse), ou devolver a pasta ao usuário:

```bash
sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
sudo chmod g+rwx "$HOME/.docker" -R
```

É um bom exemplo de por que `sudo docker` não é tão inocente: não dá mais poder que o grupo, mas deixa rastros de `root` onde não deveriam estar.

### 1.9 Por que o grupo `docker` equivale a `root`

#### 1.9.1 A advertência

Os passos pós-instalação colocam esta advertência logo antes dos comandos de 1.8.2: «o grupo `docker` concede privilégios de nível `root` ao usuário» ([Docker, passos pós-instalação](https://docs.docker.com/engine/install/linux-postinstall/)). E o guia de segurança explica por quê: o daemon precisa de `root` e o Docker permite compartilhar uma pasta do host com um contêiner «sem limitar os direitos de acesso do contêiner»; é possível iniciar um contêiner em que `/host` seja a pasta `/` da máquina, «e o contêiner pode alterar o sistema de arquivos do host sem nenhuma restrição» ([Docker Engine security](https://docs.docker.com/engine/security/#docker-daemon-attack-surface)).

Uma advertência se esquece; uma demonstração, não. Por isso este curso não pede que se acredite nela.

#### 1.9.2 Ver com os próprios olhos

`/etc/shadow` é o arquivo onde o Linux guarda as senhas cifradas dos usuários. Só `root` pode lê-lo. `fig01_07.sh` tenta lê-lo duas vezes: primeiro com o próprio usuário, sem `sudo`; depois, pedindo ao daemon do Docker. Para não imprimir nada secreto, só conta as linhas e mostra o primeiro **nome** de usuário:

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

Execução real · máquina virtual:

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

Mudam na máquina de quem segue a lição: o número de linhas (uma por usuário do sistema), os identificadores do download e o bloco de download inteiro se a imagem já estava lá. O resto é estável.

Leia as duas metades juntas:

1. **Com o próprio usuário, o sistema diz não.** `/etc/shadow` pertence a `root` e ao grupo `shadow`, e os outros não têm nenhuma permissão (`---`). `cat` falha com `Permission denied`, como deve ser.
2. **Pedindo ao daemon, ele diz sim.** `-v /etc:/anfitrion-etc:ro` monta a pasta `/etc` da máquina dentro do contêiner, em `/anfitrion-etc`. Lá dentro, o processo é `uid=0(root)` e, como o namespace de usuários não é isolado por padrão (Lição 0, seção 0.3), é o **mesmo** usuário 0 da máquina. Ele lê o arquivo sem problema: 26 linhas, começando pela de `root`.

Não houve `sudo`. Nenhuma senha foi digitada. Bastou estar no grupo `docker`. E o `:ro` da montagem (somente leitura) não é uma proteção: foi colocado por nós, e nada impedia de removê-lo e montar `/` inteiro com permissão de escrita. É isso que significa «equivale a `root`»: não que o grupo `docker` tenha uma permissão especial, e sim que ele dá acesso a um programa que roda como `root` e faz o que lhe for pedido.

A mesma lógica explica as outras duas proibições da cena. Dar permissões `777` ao *socket* é colocar **todos** os usuários e programas da máquina no grupo `docker` sem perguntar a eles. E montar o *socket* dentro de um contêiner é dar essa chave ao que rodar lá dentro.

#### 1.9.3 As alternativas

A documentação oferece três caminhos para quem não quer esse poder sempre disponível:

- **`sudo docker`**, toda vez. O poder é o mesmo, mas é preciso pedi-lo com senha, e fica registrado.
- **O grupo sob demanda.** O usuário fica **fora** do grupo `docker`, coloca-se uma senha no grupo (`sudo gpasswd docker`) e, quando o Docker é necessário, abre-se um *shell* com `newgrp docker` e digita-se essa senha. O guia diz para que serve e para que não serve: reduz o acesso «ambiente» ao *socket*, porque só o têm os programas iniciados a partir desse *shell*, mas não reduz os privilégios uma vez concedido o acesso, e «não é uma fronteira de segurança» contra código malicioso que já roda com o nosso usuário ([Docker, passos pós-instalação](https://docs.docker.com/engine/install/linux-postinstall/#access-the-docker-group-on-demand)).
- **O modo *rootless*.** O daemon e os contêineres rodam dentro de um namespace de usuários, sem privilégios de `root`, para mitigar possíveis vulnerabilidades do daemon e do runtime ([Docker, modo *rootless*](https://docs.docker.com/engine/security/rootless/)). É a única das três que muda o fundo da questão. Tem seus próprios requisitos e limitações, e alguns detalhes que este curso ensina ficariam diferentes nele; por isso não é o caminho do curso.

O curso usa o grupo, em uma máquina que é nossa e onde somos nós que decidimos o que roda. A regra que importa: **colocar alguém no grupo `docker` é dar `root` a essa pessoa**. Quem não daria a senha de `root` a uma pessoa ou a um programa também não deve colocá-los no grupo.

> [!NOTE]
> 🔧 **Observação de engenharia 1.2**
> A pergunta útil não é «esta permissão é perigosa?», e sim «o que dá para fazer **por meio** desta permissão?». O grupo `docker` não diz `root` em lugar nenhum; o caminho até `root` passa por um intermediário que é `root`. Muitos problemas de segurança têm essa forma: uma permissão modesta que abre a porta para alguém com mais poder.

### 1.10 Atualizar e desinstalar

**Atualizar.** Como o Docker vive em um repositório do `apt`, ele é atualizado como todo o resto: `sudo apt update` e `sudo apt upgrade`, ou repetindo o comando de 1.6 com a nova versão desejada ([Docker, instalar no Ubuntu](https://docs.docker.com/engine/install/ubuntu/#upgrade-docker-engine)).

**Desinstalar.** São três passos, e cada um remove uma coisa diferente (da documentação):

```bash
sudo apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
sudo rm /etc/apt/sources.list.d/docker.sources
sudo rm /etc/apt/keyrings/docker.asc
```

O primeiro remove os programas (`purge`, diferentemente de `remove`, remove também sua configuração). Repare que a lista inclui `docker-ce-rootless-extras`, o sexto pacote que apareceu na simulação de 1.5.3. O segundo par **apaga todas as imagens, contêineres e volumes**, que o primeiro deixou intactos: é irreversível, então antes de rodá-lo confirme que não há nada ali que se queira preservar. O terceiro par remove a fonte e a chave, para que o `apt` deixe de consultar o repositório do Docker. O guia acrescenta que os arquivos de configuração editados manualmente precisam ser apagados manualmente.

## O erro que se vai ver

Esta lição tem dois erros principais, os dois provocados em suas seções, e um secundário já conhecido.

**O erro do Mint: «does not have a Release file».** É o de `fig01_03.sh` (1.5.2):

```text
Err:2 https://download.docker.com/linux/ubuntu zena Release
  404  Not Found [IP: 3.161.44.57 443]
E: The repository 'https://download.docker.com/linux/ubuntu zena Release' does not have a Release file.
```

Lê-se assim: o `apt` pediu ao repositório do Docker a versão `zena` e o servidor respondeu que ela não existe (404). A palavra que importa é a que está entre o endereço e `Release`: se ali aparece um nome do Mint (`wilma`, `xia`, `zara`, `zena`), o problema é a linha `Suites` de `/etc/apt/sources.list.d/docker.sources`. Corrige-se reescrevendo esse arquivo com a linha do guia oficial, que usa `UBUNTU_CODENAME` (1.5.3), e rodando `sudo apt update` de novo. Se em vez do nome do Mint aparece `noble` e ainda assim falha, o problema é outro (a rede, ou a URL mal escrita); e se aparece o nome de uma versão do Ubuntu que o Docker não suporta, confira a lista de 1.2.1.

**O erro de permissões: «permission denied while trying to connect to the docker API».** É o de `fig01_06.sh` (1.8.1):

```text
permission denied while trying to connect to the docker API at unix:///var/run/docker.sock
```

Lê-se assim: o daemon **está** lá (o *socket* existe), mas o usuário não tem permissão para abrir o *socket*. Corrige-se com `sudo usermod -aG docker $USER` e encerrando a sessão (1.8.2), **sabendo o que isso significa** (1.9). O que não se faz: `chmod 666` ou `777` sobre o *socket*, que o abre para todos os usuários da máquina. Além disso, o *socket* é recriado pelo *systemd* (a unidade `docker.socket`) com suas permissões de sempre, `root:docker` e `0660`, toda vez que a máquina inicia, então a «correção» desaparece na próxima reinicialização, e a tentação é repeti-la.

**O erro secundário: o daemon não está lá.** Ele apareceu na Lição 0, provocado com um caminho de teste (execução real daquela lição):

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

No Mint, com o serviço parado, o caminho será `/var/run/docker.sock` e o resto da mensagem, o mesmo. Agora dá para diagnosticá-lo de ponta a ponta: `systemctl is-active docker` diz se o serviço está rodando; se não, `sudo systemctl start docker` o inicia, e `sudo journalctl -u docker` mostra o log do serviço para saber por que ele parou. Se `is-enabled` disser `disabled`, o serviço não vai iniciar sozinho ao ligar a máquina: `sudo systemctl enable docker` corrige isso.

## O hábito de segurança da lição

**O grupo `docker` equivale a `root`: é concedido conscientemente, e só a quem se daria `root`.** Este hábito evita dois acidentes concretos. O primeiro é o da cena: «corrigir» o erro de permissões abrindo o *socket* para todos, com o que qualquer programa da máquina — inclusive um baixado sem revisão — pode pedir ao daemon que monte o disco. O segundo é mais silencioso: colocar no grupo, «para facilitar», outra pessoa ou uma conta de serviço que só precisava ver alguns logs. Nos dois casos o dano não se nota até alguém usá-lo.

Junto com esse hábito vem outro, menor, que esta lição também instala: **a chave de um repositório vale só para esse repositório** (`Signed-By`), e nada que peça `apt-key` ou um script baixado e executado sem ler entra na máquina.

## O que se faz errado

**Instalar `docker.io` «porque é mais fácil».** É o pacote da distribuição, não o do Docker: outra versão, outro ritmo de atualizações, e os *plugins* com outros nomes. Tendo-o e instalando também os oficiais, eles conflitam. Este curso foi medido com os oficiais.

**Copiar o guia de instalação do Debian, ou um guia antigo, no Mint.** Eles usam `VERSION_CODENAME`, que no Mint é o nome do Mint. O resultado é o erro de 1.5.2.

**Escrever `noble` à mão «porque funciona».** Funciona hoje, mas amarra o comando a uma única versão: passado a alguém com Mint 21 (`jammy`), ou rodado de novo no dia em que o Mint mudar de base do Ubuntu, ele escreve um nome errado. A expressão do guia tira o valor de `/etc/os-release` no momento em que é executada. Atenção: nos dois casos o arquivo guarda o nome já resolvido; se um dia a versão do Mint mudar, o que se repete é o comando de 1.5.3, e não se edita o arquivo no olho.

**`chmod 777 /var/run/docker.sock`.** Dá à máquina inteira o que o grupo `docker` dá a seus membros: `root`. E nem sequer dura, porque o *systemd* recria o *socket* ao iniciar a máquina.

**Colocar qualquer pessoa no grupo `docker`.** É dar `root` a ela (1.9).

**Usar `apt-key add`.** Está obsoleto (o Mint 22 ainda o traz, por isso parece funcionar), e coloca a chave em um chaveiro que vale para todos os repositórios.

**Rodar o script de `get.docker.com` sem lê-lo.** O próprio guia pede para revisar os scripts baixados antes de rodá-los, e não o recomenda para produção. Um script baixado e executado com `sudo` tem `root` na máquina, igual ao grupo `docker`.

**Esquecer o `-a` em `usermod -aG`.** `usermod -G docker` deixa o usuário **só** no grupo `docker`, e fora do `sudo`.

**Dar a instalação por terminada sem verificá-la.** O `apt` não ter dado erro não diz que o serviço está rodando, nem que vai iniciar sozinho, nem que o usuário pode usá-lo. As verificações de `fig01_05.sh` levam dois segundos.

## Exercícios

Escreva as respostas e as previsões no [diário de bordo](bitacora.md) antes de ver as soluções.

### Exercício 1 — Ler o `os-release` (projeto)

Rode `fig01_01.sh` no Mint. Antes de rodar, preveja o que dirão `VERSION_CODENAME`, `UBUNTU_CODENAME` e `Suites`. Depois responda: se um colega tem LMDE 7, o que essas três linhas diriam na máquina dele, que guia de instalação cabe a ele e que codinome vai em seu `Suites`? Dica: rode `./fig01_01.sh os-release-lmde-7.txt` dentro de `programas/01-instalacion/` e procure uma variável que o Mint não tem. O último bloco mostrará a arquitetura da própria máquina, não a dele.

### Exercício 2 — Diagnosticar sem rodar nada

Um colega manda três mensagens de erro, uma por dia. São os erros desta lição tal como ele os veria, com o nome da sua versão do Mint e o caminho do *socket* da sua máquina. Para cada um, diga qual é a causa e que comando ou mudança a corrige:

1. `E: The repository 'https://download.docker.com/linux/ubuntu xia Release' does not have a Release file.`
2. `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`
3. `failed to connect to the docker API at unix:///var/run/docker.sock; check if the path is correct and if the daemon is running: dial unix /var/run/docker.sock: connect: no such file or directory`

### Exercício 3 — De onde vem cada coisa?

Sem instalar nada novo, rode estes dois comandos no Mint (já com o Docker instalado) e responda às perguntas:

```bash
apt-cache policy docker-ce docker.io | grep -E '^[a-z]|Installed|Candidate'
cat /etc/apt/sources.list.d/docker.sources
```

1. Que versão de `docker-ce` está instalada, e qual seria instalada ao atualizar?
2. O `docker.io` está instalado? Algum repositório o oferece?
3. O que diz a linha `Suites` e por quê?

### Exercício 4 — A chave do daemon

Sem rodar, responda: se em `fig01_07.sh` `-v /etc:/anfitrion-etc:ro` fosse trocado por `-v /:/anfitrion` (sem `:ro`), o que o contêiner poderia fazer? Cite uma coisa concreta que ele poderia mudar na máquina. Depois explique em duas frases por que `chmod 777 /var/run/docker.sock` é pior que colocar o usuário no grupo `docker`.

## Soluções

### Solução 1

Em um Mint 22.x: `VERSION_CODENAME` diz o nome do Mint (`wilma`, `xia`, `zara` ou `zena`), `UBUNTU_CODENAME` diz `noble` e `Suites` diz `noble`, porque a regra `${UBUNTU_CODENAME:-$VERSION_CODENAME}` prefere a primeira variável quando ela existe. Se o `Suites` disse outra coisa, confira se é o Mint 22 e não uma versão anterior: o Mint 21 é feito sobre o Ubuntu Jammy e diria `jammy`, que também é uma versão suportada.

No LMDE 7, `VERSION_CODENAME=gigi`, `UBUNTU_CODENAME` sai `(no existe)` e por isso `Suites: gigi`, um nome que o Docker não tem. Mas o `os-release` dele traz `DEBIAN_CODENAME=trixie`, a variável que o Mint não tem, e é ela que vai na linha `Suites` do guia do Debian: `${DEBIAN_CODENAME:-$VERSION_CODENAME}` (1.2.3). Esta é a saída da dica (execução real · máquina virtual, por isso `arm64`; está em `fig01_01.salida-lmde.txt`):

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

### Solução 2

1. **O codinome do Mint no repositório.** `xia` é o Mint 22.1. A linha `Suites` de `/etc/apt/sources.list.d/docker.sources` tem o nome do Mint; reescreve-se o arquivo com a linha do guia oficial (`${UBUNTU_CODENAME:-$VERSION_CODENAME}`) e roda-se `sudo apt update` (1.5.3).
2. **O usuário não está no grupo `docker`.** O daemon está rodando; falta permissão para o *socket*. `sudo usermod -aG docker $USER`, encerrar a sessão e entrar de novo (ou `newgrp docker`), sabendo que isso equivale a dar `root` (1.8 e 1.9).
3. **O daemon não está rodando.** Não há *socket* nesse caminho. `systemctl is-active docker` confirma; `sudo systemctl start docker` o inicia, `sudo journalctl -u docker` diz por que ele tinha parado e `sudo systemctl enable docker` o deixa iniciando sozinho.

Quem confundiu o 2 com o 3 deve reler o final de cada mensagem: `permission denied` versus `no such file or directory`. A causa está sempre nas últimas palavras.

### Solução 3

1. No bloco de `docker-ce`, `Installed` é a versão instalada e `Candidate` a que seria instalada com `sudo apt upgrade`. Se forem iguais, está em dia.
2. Seguindo a lição, `docker.io` dirá `Installed: (none)`. Seu `Candidate` provavelmente mostra uma versão: o pacote existe nos repositórios do Ubuntu que o Mint usa, mesmo sem ser instalado. Esse é o motivo pelo qual convém saber de onde vem cada pacote.
3. `Suites: noble`, porque a expressão do guia pegou o `UBUNTU_CODENAME` do `/etc/os-release`: o repositório do Docker tem pastas por versão do Ubuntu, não por versão do Mint.

### Solução 4

Com `/` montado com escrita, o contêiner, como `root`, poderia mudar qualquer arquivo da máquina: por exemplo, acrescentar um usuário novo com permissões de administrador editando `/etc/passwd` e `/etc/sudoers`, apagar `/etc/shadow` ou substituir um programa de `/usr/bin` por outro. É a frase do guia de segurança: o contêiner «pode alterar o sistema de arquivos do host sem nenhuma restrição».

`chmod 777` é pior porque não dá esse poder só ao nosso usuário, e sim a **todos** os usuários e programas da máquina, sem que nenhum precise estar em um grupo nem saiba disso. E além disso não dura: o *systemd* recria o *socket* com suas permissões ao reiniciar a máquina, então quem o usa se acostuma a repeti-lo.

## Como sei que consegui

Marque cada ponto só se ele se cumprir na **própria** máquina:

- [ ] `fig01_01.sh` mostra `Suites: noble` (ou, no LMDE, sabe-se por que não e que guia cabe).
- [ ] `cat /etc/apt/sources.list.d/docker.sources` mostra o formato de seis campos de 1.5.1, com `Suites: noble` (no LMDE, `trixie` e a URL de `linux/debian`) e `Signed-By: /etc/apt/keyrings/docker.asc`, e `sudo apt update` não mostra nenhuma linha `E:`.
- [ ] `systemctl is-active docker` imprime `active` e `systemctl is-enabled docker` imprime `enabled`.
- [ ] `id -nG` inclui `docker`, e `docker version` sem `sudo` mostra a versão do cliente **e** a do daemon.
- [ ] `fig01_05.sh`, sem `sudo`, termina com `Hello from Docker!` no bloco 4, `srw-rw---- root docker /var/run/docker.sock` no bloco 5 e `0` no bloco 6. O que não se compara, porque muda: as versões, os identificadores e o *digest* do download, e a arquitetura entre parênteses.
- [ ] `fig01_06.sh` imprime o `permission denied` para `nobody` e `sí` para o próprio usuário.
- [ ] `fig01_07.sh` imprime `Permission denied` no bloco 1 e `uid=0(root)` no bloco 2, e dá para explicar em voz alta por quê.
- [ ] Ao terminar, `docker ps -a --filter name=curso-docker-` não mostra nada.
- [ ] Ficou anotado no diário de bordo que versão do Docker foi instalada e em que data.

## Resumo

Responda sem olhar a lição:

1. Por que o curso instala os pacotes de `download.docker.com` e não `docker.io`?
2. O que `/etc/os-release` diz no Mint que não diz no Ubuntu, e por que isso importa para instalar o Docker?
3. O que faz a expressão `${UBUNTU_CODENAME:-$VERSION_CODENAME}`?
4. Que cinco pacotes o guia instala, e que peça do mapa da Lição 0 é cada um?
5. Para que serve o campo `Signed-By`, e que problema o `apt-key` tinha?
6. O que significa «does not have a Release file» ao acrescentar o repositório no Mint?
7. Qual é a diferença entre `permission denied` e `no such file or directory` ao falar com o daemon?
8. Por que o grupo `docker` equivale a `root`, e que alternativas existem?
9. Por que o ufw não protege as portas que o Docker publica, e o que este curso faz a respeito?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [Docker, «Install Docker Engine on Ubuntu»](https://docs.docker.com/engine/install/ubuntu/): as versões do Ubuntu suportadas, a nota sobre o Linux Mint, a advertência do firewall, os pacotes em conflito, o repositório com sua chave, os cinco pacotes, como fixar uma versão, o script de conveniência, as verificações, a atualização e a desinstalação.
- [Docker, «Install Docker Engine on Debian»](https://docs.docker.com/engine/install/debian/): a linha `Suites` com `VERSION_CODENAME` e a nota para distribuições derivadas (LMDE).
- [Docker, «Linux post-installation steps for Docker Engine»](https://docs.docker.com/engine/install/linux-postinstall/): o grupo `docker`, a advertência de que equivale a `root`, o erro de `config.json`, o grupo sob demanda com senha e a inicialização do serviço com *systemd*.
- [Docker Engine security, «Docker daemon attack surface»](https://docs.docker.com/engine/security/#docker-daemon-attack-surface): por que quem controla o daemon controla o host.
- [Docker, «Packet filtering and firewalls»](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw): por que as portas publicadas ignoram o ufw.
- [Docker, «Rootless mode»](https://docs.docker.com/engine/security/rootless/): o que é o modo sem `root`.
- [Docker Desktop para Linux](https://docs.docker.com/desktop/setup/install/linux/): que o Docker Desktop no Linux roda uma máquina virtual.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): a versão 29.9.2 e sua data.
- [Linux Mint, todas as versões](https://www.linuxmint.com/download_all.php): as versões do Mint 22, sua base Ubuntu Noble e o LMDE 7 sobre Debian Trixie.
- [Repositório de pacotes do Linux Mint](http://packages.linuxmint.com/): o pacote `base-files` `13ubuntu10mint22.3.0`, de onde vem o `/etc/os-release` do Mint 22.3 usado nas execuções.
- [sources.list(5), manual do `apt`](https://manpages.debian.org/trixie/apt/sources.list.5.en.html): os formatos de uma linha e deb822.
- [apt-key(8), manual do `apt` no Ubuntu 24.04](https://manpages.ubuntu.com/manpages/noble/man8/apt-key.8.html): o `apt-key` obsoleto e até que versão estará disponível.
- [Colima](https://github.com/abiosoft/colima): a máquina virtual das execuções.

### Termos desta lição

| | |
|---|---|
| **`apt`** | o gerenciador de pacotes do Mint, do Ubuntu e do Debian; baixa e instala pacotes a partir de repositórios |
| **deb822** | o formato dos arquivos `.sources` do `apt`: um campo com nome por linha |
| **`dpkg`** | o gerenciador de pacotes de baixo nível, sobre o qual o `apt` trabalha |
| **grupo `docker`** | o grupo do Linux cujos membros podem falar com o daemon sem `sudo`; equivale a `root` |
| **LMDE** | *Linux Mint Debian Edition*, a edição do Mint feita sobre o Debian e não sobre o Ubuntu |
| **chave (de repositório)** | a parte pública de uma chave criptográfica com a qual o `apt` comprova que os pacotes vêm de quem dizem |
| **codinome** | o nome curto de uma versão de uma distribuição: `noble` para o Ubuntu 24.04, `zena` para o Mint 22.3 |
| ***plugin*** | um programa acrescentado ao cliente `docker` como subcomando: `docker compose`, `docker buildx` |
| **repositório** | um servidor que publica pacotes com um índice assinado |
| ***rootless*** | modo em que o daemon e os contêineres rodam sem privilégios de `root` |
| ***systemd*** | o programa que inicia e vigia os serviços do sistema; é operado com `systemctl` |
| **ufw** | *Uncomplicated Firewall*, a ferramenta de firewall do Ubuntu |

---

**Anterior:** [Lição 0 — O que é um contêiner e o que NÃO é](00-que-es-un-contenedor.md) · **Próxima:** [Lição 2 — Contêineres no dia a dia](02-contenedores-dia-a-dia.md)
