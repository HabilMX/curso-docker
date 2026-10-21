# Lição 0 — O que é um contêiner e o que NÃO é

São 2h14 da madrugada e o alerta dispara: o servidor de testes parou de responder. A gente entra como pode e a primeira coisa que vê é que o banco de dados, que vivia nessa mesma máquina, não está mais rodando. O log do sistema diz que o kernel o matou por falta de memória. Alguém no chat da equipe escreve, convencido: “Não pode ser o `revisor`, ele roda em um contêiner; está isolado, é como uma máquina à parte”. Dez minutos depois aparece o culpado: o contêiner do `revisor`, sem nenhum limite, tinha devorado a memória da máquina inteira até que o kernel teve de escolher quem matar, e escolheu o banco de dados. Ninguém mentiu. O que aconteceu é que essa pessoa tinha uma ideia errada do que é um contêiner, e essa ideia custou uma noite. Esta lição existe para que a gente não tenha essa ideia.

**Tempo:** 90 min

**O que se constrói:** nada ainda. É uma lição de leitura: aqui se monta o mapa mental com o qual o resto do curso se torna previsível. Traz nove programas curtos para ver com os próprios olhos o que a lição afirma.

**O que se aprende:** que um contêiner é um processo isolado e não uma máquina virtual; com que peças do kernel do Linux esse isolamento é construído (namespaces e cgroups); a diferença entre uma imagem e um contêiner; que o Docker são dois programas, um cliente e um daemon; e o que um contêiner compartilha com o host e por que isso decide a segurança.

**De onde se parte.** Não se traz nada deste curso: ainda não se instalou o Docker. Traz-se, sim, o que o curso dá por sabido: usar um terminal com desenvoltura, saber o que é um processo (um programa que está rodando) e o que é um servidor HTTP. Talvez já se tenha escrito o `revisor` no curso de Go, Rust ou TypeScript da Hábil. Se não, basta isto: é um programa que consulta uma lista de serviços ao mesmo tempo e entrega um relatório de quais estão no ar, quais lentos e quais fora do ar. O que provavelmente não se traz é uma ideia precisa de como um contêiner é por dentro, e é essa ideia que será necessária toda vez que algo falhar.

**O que esta lição não faz.** Não instala nada (isso é a [Lição 1](01-instalacion.md)) e não ensina os comandos do Docker um por um (isso começa na [Lição 2](02-contenedores-dia-a-dia.md)). Os programas desta lição são scripts de *bash* de dez a trinta linhas que chamam `docker` e ferramentas normais do Linux como `ps` e `uname`. Não é preciso entender cada opção ainda, embora cada uma seja explicada: o que importa é o que eles **imprimem**. Eles são executados depois da Lição 1, quando o Docker já estiver instalado.

**Sobre as execuções.** As saídas desta lição foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual de Linux para poder rodar contêineres. Essa máquina virtual tem Ubuntu 24.04.4, que é a mesma base do Linux Mint 22, então **os scripts foram executados dentro dela** e é ali que aparece o “host” nas saídas: no Mint, o host é o próprio computador e os mesmos comandos funcionam sem mudanças. A versão do Docker dentro dessa máquina era a 29.2.1 (cliente e daemon). O curso foi planejado com a 29.8.2 e, no dia desta execução, a mais recente publicada era a 29.9.2, de 20 de outubro de 2026, segundo as [notas de versão oficiais](https://docs.docker.com/engine/release-notes/29/). Nada do que esta lição mostra muda entre essas versões; a Lição 1 ensina a ver a versão instalada. O que **sim** muda de uma execução para outra, e é avisado onde ocorre: os números de processo (PID), os números dos namespaces, os tempos e, se o computador tem processador Intel ou AMD, a palavra `arm64`, que nele dirá `amd64`. Os programas estão em [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor), no repositório do curso, cada um com a sua saída guardada ao lado.

## Ao terminar, será possível

- Mostrar com `ps` que um contêiner em execução é mais um processo do host, e encontrar o número do processo dele a partir de fora.
- Explicar com um exemplo por que um contêiner não é uma máquina virtual, usando a palavra *kernel*.
- Nomear os namespaces que o Docker isola e os dois que, por padrão, não isola.
- Ler em `/sys/fs/cgroup` os limites de memória, CPU e processos de um contêiner, e dizer o que acontece quando não há nenhum.
- Distinguir uma imagem de um contêiner, e prever o que acontece com um arquivo escrito dentro de um contêiner quando esse contêiner é apagado.
- Explicar o que fazem o cliente `docker` e o daemon `dockerd`, e por onde eles conversam.
- Dizer o que um contêiner compartilha com o host e por que isso transforma o “root dentro do contêiner” em uma questão de segurança.

## O porquê antes do como

Imagine que se termina o `revisor` e alguém pede para colocá-lo para rodar em um servidor. O mais direto é copiar o executável e iniciá-lo. Funciona, até deixar de funcionar: o servidor tem outra versão de alguma biblioteca, ou a porta 8080 já é usada por outro programa, ou o `revisor` tem um erro que o faz consumir memória sem parar e arrasta junto tudo o mais que roda ali. E quando finalmente se descobre que na própria máquina funcionava, a frase “na minha máquina funciona” já não serve a ninguém.

Os contêineres nasceram para resolver isso: entregar um programa **junto com tudo de que ele precisa para rodar**, e rodá-lo **separado** dos demais, com limites. Isso é verdade e é muito útil. O problema começa quando essa descrição se converte em uma imagem mental errada: “um contêiner é um computadorzinho dentro do meu”. Com essa imagem, a cena do início é impossível: como um computadorzinho vai matar um programa do computador grande? Com a imagem correta, a cena é óbvia.

A imagem correta é esta, e é a que a própria documentação do Docker usa: um contêiner é um **processo isolado** ([Docker, “What is a container?”](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)). Não é outro computador. É um programa que roda no **mesmo** computador, sobre o **mesmo** kernel do Linux, ao qual o kernel põe paredes (para que não veja o que não deve) e um orçamento (para que não gaste o que não deve). Se as paredes estão bem postas, o processo acredita estar sozinho. Se não há orçamento, ele pode gastar tudo.

A lição tem sete partes, nesta ordem:

1. **Um contêiner é um processo** (0.1): olhá-lo de dentro e de fora.
2. **Não é uma máquina virtual** (0.2): o kernel compartilhado e o que isso implica.
3. **As paredes: namespaces** (0.3).
4. **O orçamento: cgroups** (0.4), com o erro desta lição.
5. **Imagem versus contêiner** (0.5).
6. **O cliente e o daemon** (0.6).
7. **O que é compartilhado e a segurança** (0.7), e um pouco de história para se situar (0.8).

Com esse destino em mente, isto é o que se verá na seção 0.4, quando um contêiner com um limite de memória tentar passar dele. É o que faltou ao contêiner da cena:

```text
voy a comer memoria...
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

## Os conceitos

### 0.1 Um contêiner é um processo

#### 0.1.1 Olhar de dentro e de fora

A forma mais rápida de se livrar da ideia do “computadorzinho” é iniciar um contêiner e procurá-lo com as ferramentas de sempre. O programa `fig00_01.sh` inicia um contêiner que não faz nada além de dormir cinco minutos (`sleep 300`), olha-o de dentro, olha-o de fora e o apaga ao terminar:

```bash
#!/usr/bin/env bash
# fig00_01.sh — Un contenedor es un proceso del equipo anfitrión.
# Arranca un contenedor que solo duerme, lo mira desde dentro y desde fuera,
# y lo borra al final.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-dormilon
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null

echo "== 1. Desde DENTRO del contenedor: todos sus procesos"
docker exec "$NOMBRE" ps -o pid,user,args

echo
echo "== 2. Desde FUERA: el mismo proceso, visto por Docker"
PID_ANFITRION=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
echo "PID en el anfitrión: $PID_ANFITRION"

echo
echo "== 3. Desde FUERA: el mismo proceso, visto por el sistema operativo"
ps -o pid,ppid,user,args -p "$PID_ANFITRION"

echo
echo "== 4. Quién es su padre en el anfitrión"
PPID_ANFITRION=$(ps -o ppid= -p "$PID_ANFITRION" | tr -d ' ')
ps -o pid,user,comm -p "$PPID_ANFITRION"
```

```text
$ ./fig00_01.sh
== 1. Desde DENTRO del contenedor: todos sus procesos
PID   USER     COMMAND
    1 root     sleep 300
    7 root     ps -o pid,user,args

== 2. Desde FUERA: el mismo proceso, visto por Docker
PID en el anfitrión: 836426

== 3. Desde FUERA: el mismo proceso, visto por el sistema operativo
    PID    PPID USER     COMMAND
 836426  836402 root     sleep 300

== 4. Quién es su padre en el anfitrión
    PID USER     COMMAND
 836402 root     containerd-shim
```

Os números `836426` e `836402` mudam a cada execução; todo o resto sai igual. Antes de ler a saída, as linhas do script que importam. `set -euo pipefail` faz o script parar no primeiro erro, em vez de seguir como se nada tivesse acontecido. `trap ... EXIT` deixa programado que, aconteça o que acontecer, ao sair o contêiner seja apagado: assim não sobra lixo na máquina, um hábito que a Lição 2 transforma em regra. `docker run -d` inicia o contêiner “em segundo plano” (*detached*) e dá um nome a ele com `--name`; todos os nomes deste curso começam com `curso-docker-` para saber num relance o que pertence ao curso. `docker exec` executa um comando **dentro** de um contêiner que já está rodando, e `docker inspect` consulta os dados de um contêiner; aqui, o número do processo dele no host.

Agora a saída, bloco por bloco:

1. **De dentro**, o contêiner vê apenas dois processos: `sleep 300`, que tem o número **1**, e o `ps` que acabou de ser lançado. Ele não vê o navegador, nem o terminal, nem nada do que roda na máquina. Do ponto de vista dele, ele é o primeiro processo do sistema.
2. **De fora**, o Docker diz que esse mesmo processo tem o número 836426 no host.
3. E **o sistema operacional do host** confirma com um `ps` normal, o mesmo que se usaria para qualquer outro programa: ali está `sleep 300`, rodando como `root`. Não há outro computador. Há um processo a mais na lista da máquina.
4. O pai dele é `containerd-shim`, um pequeno programa que o Docker põe para cuidar de cada contêiner. (O nome completo é `containerd-shim-runc-v2`; o `ps` o corta porque o campo `comm` só guarda 15 caracteres.)

🔑 **Leia isso de novo: o mesmo processo tem dois números.** Dentro é o 1; fora é o 836426. Não são dois processos: é um só, visto de dois lugares. O fato de ter dois números é a primeira pista de como funciona o isolamento, e a seção 0.3 a explica.

#### 0.1.2 O que significa ser um processo

Que um contêiner seja um processo não é um detalhe técnico; tem consequências que se sentem ao longo do curso inteiro:

- **Inicia em milissegundos**, porque iniciar um processo é rápido. Não há sistema operacional para inicializar.
- **Morre como um processo.** Se o programa principal termina, o contêiner termina. Se o kernel o mata, o contêiner morre. Na Lição 7 se verá que isso inclui os sinais: `docker stop` manda a esse processo número 1 o mesmo sinal que se mandaria com `kill`.
- **Gasta como um processo.** Usa a memória e a CPU da máquina, do mesmo reservatório que todos os outros programas. Se ninguém lhe põe um limite, ele não tem limite.
- **Vê-se com as ferramentas de sempre.** `ps`, `top` e o monitor do sistema o mostram. Isso é útil para diagnosticar e é um aviso: quem tem poder sobre os processos do host tem poder sobre os contêineres.

> [!NOTE]
> 🔧 **Observação de engenharia 0.1**
> Uma boa imagem mental se reconhece porque prevê. Com “é um computadorzinho”, não se consegue prever que o contêiner apareça no `ps` do host. Com “é um processo isolado”, prevê-se isso antes de rodar o programa. Ao longo do curso, quando algo causar surpresa, pergunte-se primeiro o que um processo normal faria naquela situação.

### 0.2 Não é uma máquina virtual

#### 0.2.1 Duas distribuições, um único kernel

Uma **máquina virtual** é um programa que imita um computador completo: um processador, memória, disco e placa de rede simulados. Dentro desse computador simulado inicia-se um sistema operacional inteiro, **com o seu próprio kernel**. Por isso, em uma máquina virtual é possível rodar Windows sobre Linux ou Linux sobre um Mac.

O **kernel** (núcleo) é a parte do sistema operacional que manda no hardware: reparte a memória, decide qual processo usa a CPU a cada instante, fala com o disco e a rede. Todo o resto (o *shell*, `ls`, o gerenciador de pacotes, as bibliotecas) roda por cima dele e lhe pede as coisas. A isso que fica por cima costuma-se chamar de **espaço de usuário**.

Um contêiner não traz kernel. Traz apenas espaço de usuário. É o que prova o `fig00_02.sh`, que pergunta a distribuição e a versão do kernel no host e em dois contêineres de distribuições diferentes:

```bash
#!/usr/bin/env bash
# fig00_02.sh — Dos imágenes de dos distribuciones distintas, un solo núcleo.
set -euo pipefail
ALPINE=alpine:3.24.2
DEBIAN=debian:13.7-slim

distro() { grep '^PRETTY_NAME=' "$1" | cut -d= -f2 | tr -d '"'; }

echo "== El anfitrión"
echo "distribución: $(distro /etc/os-release)"
echo "núcleo:       $(uname -r)"

for IMAGEN in "$ALPINE" "$DEBIAN"; do
  echo
  echo "== Un contenedor de $IMAGEN"
  docker run --rm --name curso-docker-distro "$IMAGEN" sh -c '
    echo "distribución: $(grep "^PRETTY_NAME=" /etc/os-release | cut -d= -f2 | tr -d "\"")"
    echo "núcleo:       $(uname -r)"'
done
```

```text
$ ./fig00_02.sh
== El anfitrión
distribución: Ubuntu 24.04.4 LTS
núcleo:       6.8.0-100-generic

== Un contenedor de alpine:3.24.2
distribución: Alpine Linux v3.24
núcleo:       6.8.0-100-generic

== Un contenedor de debian:13.7-slim
distribución: Debian GNU/Linux 13 (trixie)
núcleo:       6.8.0-100-generic
```

No Mint, a primeira linha dirá `Linux Mint 22...` e o kernel será o da própria máquina; o que importa é que **os três números de kernel serão iguais entre si**. O arquivo `/etc/os-release` é onde cada distribuição escreve o seu nome, e `uname -r` pergunta ao kernel a sua versão. A opção `--rm` pede ao Docker que apague o contêiner assim que ele terminar.

Veja o que aconteceu. Dentro do contêiner do Alpine, o arquivo diz que o sistema é Alpine 3.24. Dentro do contêiner do Debian, que é Debian 13. Mas quando se pergunta **ao kernel**, os três respondem o mesmo: `6.8.0-100-generic`, o do host. Os arquivos são do Alpine ou do Debian; o kernel é um só, compartilhado. É exatamente o que diz a documentação: “ao rodar vários contêineres, todos compartilham o mesmo kernel” ([Docker, “What is a container?”](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/)).

Daqui sai uma regra que convém gravar: **uma “imagem de Debian” não é Debian**. É o espaço de usuário do Debian (seus programas, suas bibliotecas, seu gerenciador de pacotes) rodando sobre o kernel disponível. Quase sempre isso basta, porque a interface do kernel do Linux muda muito pouco entre versões. Mas se um programa precisa de uma função de um kernel mais novo que o instalado, a imagem não vai trazê-la.

#### 0.2.2 A prova ao contrário: por que um Mac precisa de uma máquina virtual

Se um contêiner de Linux precisa de um kernel de Linux, o que acontece em um computador que não tem um? Acontece o que se viu em “Sobre as execuções”: é preciso arranjar um. No macOS, o Colima sobe uma máquina virtual de Linux e dentro dela roda o Docker. O Docker Desktop, o aplicativo de desktop do Docker, faz o mesmo com a sua própria máquina virtual: segundo a documentação, “o daemon do Docker e os contêineres rodam em uma máquina virtual leve de Linux administrada pelo Docker” ([Docker Desktop, permissões no Mac](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/)).

Essa máquina virtual não é um acidente; é a confirmação de tudo o que foi dito. Se os contêineres trouxessem o seu próprio kernel, não precisariam dela. O Mint não precisa dela: o kernel do Linux já está lá, e os contêineres rodam direto sobre ele. Esse é um dos motivos pelos quais o curso usa o Linux como sistema de referência: o que se vê é o que há, sem uma camada no meio.

#### 0.2.3 A comparação completa

| | Máquina virtual | Contêiner |
|---|---|---|
| O que é | um computador imitado por software | um processo com paredes e orçamento |
| Kernel | o seu próprio | o do host, compartilhado |
| O que inicia | um sistema operacional completo | um programa |
| Tempo de inicialização | segundos a minutos | milissegundos |
| Pode rodar outro sistema operacional | sim (Windows sobre Linux, por exemplo) | não: um contêiner de Linux precisa de um kernel de Linux |
| O que a separa do host | o hipervisor, que imita hardware | o kernel, que põe as paredes |
| Se algo escapa do isolamento | chega à máquina imitada | chega ao kernel que todos compartilham |

A última linha é a que importa para a segurança, e a retomamos em 0.7.

Sobre o tempo de inicialização, não é preciso acreditar: mede-se. O `fig00_09.sh` cria, roda e apaga um contêiner que não faz nada (`true` é um programa que termina de imediato), cinco vezes seguidas:

```bash
#!/usr/bin/env bash
# fig00_09.sh — Cuánto tarda en nacer, trabajar y morir un contenedor.
# Cinco veces seguidas, con una imagen que ya está descargada.
set -euo pipefail
IMAGEN=alpine:3.24.2
for i in 1 2 3 4 5; do
  inicio=$(date +%s%N)
  docker run --rm --name curso-docker-rapido "$IMAGEN" true
  fin=$(date +%s%N)
  echo "corrida $i: $(( (fin - inicio) / 1000000 )) ms"
done
```

```text
$ ./fig00_09.sh
corrida 1: 136 ms
corrida 2: 154 ms
corrida 3: 431 ms
corrida 4: 347 ms
corrida 5: 507 ms
```

Estes números sempre mudam: dependem da máquina e do que mais ela estiver fazendo naquele momento. Em outra execução na mesma máquina saíram entre 135 e 194 ms. O que é estável é a ordem de grandeza: **décimos de segundo**, para criar o contêiner, iniciar o processo, esperá-lo e apagar tudo. Uma máquina virtual leva esse tempo só para começar a carregar o seu kernel.

### 0.3 As paredes: namespaces

#### 0.3.1 O que é um namespace

Voltemos à pista de 0.1: o mesmo processo é o número 1 dentro e o 836426 fora. Como um processo pode ter dois números? Porque o kernel do Linux tem um recurso chamado **namespaces** (espaços de nomes). Um namespace é uma “visão” privada de algum recurso do sistema. Os processos que estão dentro de um namespace veem a sua própria versão desse recurso, e não veem a dos demais.

O Docker diz isso sem rodeios: usa “uma tecnologia chamada *namespaces* para fornecer o espaço de trabalho isolado que se chama contêiner” ([Docker, “What is Docker?”](https://docs.docker.com/get-started/docker-overview/)). Há oito tipos, e cada um isola uma coisa diferente. A lista vem do manual do Linux ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)):

| Tipo | Nome em `/proc` | O que isola | O que se vê em um contêiner |
|---|---|---|---|
| PID | `pid` | os números de processo | o programa é o número 1 e ele não vê os processos do host |
| Mount | `mnt` | os pontos de montagem | vê a sua própria árvore de arquivos, a da imagem, e não a do host |
| Network | `net` | interfaces, endereços, portas | tem a sua própria rede e a sua própria porta 8080 |
| UTS | `uts` | o nome da máquina | tem o seu próprio *hostname* |
| IPC | `ipc` | a comunicação entre processos por memória compartilhada | não se cruza com a de outros programas |
| Cgroup | `cgroup` | a raiz dos cgroups | vê o seu próprio grupo como se fosse a raiz (0.4) |
| User | `user` | os números de usuário e grupo | **por padrão, não é isolado** |
| Time | `time` | certos relógios do sistema | **por padrão, não é isolado** |

A linha de Network explica algo que se usa a partir da Lição 2: dois contêineres podem escutar na porta 8080 ao mesmo tempo sem brigar, porque cada um tem a sua própria rede. A de Mount explica por que o contêiner do Debian via arquivos do Debian embora a máquina seja Mint.

#### 0.3.2 Ver com os próprios olhos

Cada processo do Linux tem uma pasta `/proc/<número>/ns/` com um link para cada tipo de namespace. O que esse link contém é o tipo e um número, por exemplo `pid:[4026531836]`. O manual explica assim: se dois processos estão no mesmo namespace, esse número é o mesmo ([namespaces(7)](https://man7.org/linux/man-pages/man7/namespaces.7.html)). Então basta comparar números. É o que faz o `fig00_03.sh`, que lê os oito links do host e de um contêiner e os põe lado a lado:

```bash
#!/usr/bin/env bash
# fig00_03.sh — Los espacios de nombres (namespaces) del anfitrión y de un contenedor.
# Si el número entre corchetes coincide, los dos procesos comparten ese espacio.
set -euo pipefail
IMAGEN=alpine:3.24.2
TIPOS="cgroup ipc mnt net pid time user uts"

LISTA='for n in '"$TIPOS"'; do echo "$n $(readlink /proc/self/ns/$n)"; done'

ANFITRION=$(sh -c "$LISTA")
CONTENEDOR=$(docker run --rm --name curso-docker-ns "$IMAGEN" sh -c "$LISTA")

printf '%-7s %-20s %-20s %s\n' TIPO ANFITRION CONTENEDOR ¿IGUAL?
for n in $TIPOS; do
  a=$(echo "$ANFITRION"  | awk -v t="$n" '$1==t {print $2}')
  c=$(echo "$CONTENEDOR" | awk -v t="$n" '$1==t {print $2}')
  if [ "$a" = "$c" ]; then igual="sí, compartido"; else igual="no, aislado"; fi
  printf '%-7s %-20s %-20s %s\n' "$n" "${a#*:}" "${c#*:}" "$igual"
done
```

```text
$ ./fig00_03.sh
TIPO    ANFITRION            CONTENEDOR           ¿IGUAL?
cgroup  [4026531835]         [4026532382]         no, aislado
ipc     [4026531839]         [4026532379]         no, aislado
mnt     [4026531841]         [4026532377]         no, aislado
net     [4026531840]         [4026532383]         no, aislado
pid     [4026531836]         [4026532380]         no, aislado
time    [4026531834]         [4026531834]         sí, compartido
user    [4026531837]         [4026531837]         sí, compartido
uts     [4026531838]         [4026532378]         no, aislado
```

Os números entre colchetes mudam de uma máquina para outra e os do contêiner mudam a cada execução; a coluna `¿IGUAL?` sai igual sempre que se usa a configuração padrão do Docker. `/proc/self` é um atalho que sempre aponta para o processo que o lê, e `readlink` mostra para onde um link aponta.

Seis paredes e dois buracos. O contêiner tem os seus próprios processos, a sua própria árvore de arquivos, a sua própria rede, o seu próprio nome de máquina, a sua própria memória compartilhada e a sua própria visão dos cgroups. Mas compartilha com o host os relógios (`time`) e, sobretudo, **os usuários** (`user`). Que o namespace de usuários seja o mesmo significa que o número de usuário 0, `root`, é **o mesmo `root`** dentro e fora. Já se viu isso em 0.1: o `sleep 300` aparecia no host como sendo de `root`. O Docker suporta isolar também os usuários, mas não o faz por padrão ([Docker Engine security](https://docs.docker.com/engine/security/)). Tudo isso vale para o Docker no seu modo normal, o que a Lição 1 instala: o daemon roda como `root` e sem remapeamento de usuários. Há dois modos que mudam a história. Com [`userns-remap`](https://docs.docker.com/engine/security/userns-remap/), o `root` de dentro é, no host, um número de usuário alto e sem privilégios; no [modo *rootless*](https://docs.docker.com/engine/security/rootless/), o daemon e seus contêineres rodam dentro de um namespace de usuários sem privilégios. Nos dois, a linha `user` da tabela diria “não, isolado”. A máquina destas execuções usa o modo normal: `docker info --format '{{.SecurityOptions}}'` imprimiu `[name=apparmor name=seccomp,profile=builtin name=cgroupns]`, sem `rootless` nem `userns`, e assim se pode conferir em qualquer máquina. Essa é a metade da história de segurança de 0.7.

> [!NOTE]
> 🔧 **Observação de engenharia 0.2**
> Um namespace **esconde**; não **limita**. Que o contêiner não veja os processos do host não o impede de gastar toda a memória dele. O primeiro é trabalho dos namespaces; o segundo, dos cgroups. A cena do início é a confusão entre as duas coisas.

### 0.4 O orçamento: cgroups

#### 0.4.1 O que é um cgroup

Os **cgroups** (*control groups*, grupos de controle) são a outra metade do trabalho. São um mecanismo do kernel para acomodar processos em grupos e repartir entre esses grupos os recursos do sistema (memória, CPU, número de processos, leitura e escrita de disco) de forma controlada ([documentação do kernel, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). O guia de segurança do Docker resume isso em uma frase: os cgroups “implementam a contabilidade e o limite de recursos” ([Docker Engine security](https://docs.docker.com/engine/security/)).

Cada contêiner vive no seu próprio grupo. O kernel leva a conta de quanto esse grupo gasta e, se há um limite, não o deixa passar dali. Os limites podem ser lidos como arquivos de texto em `/sys/fs/cgroup`. Três deles vão aparecer ao longo do curso:

- `memory.max`: quanta memória o grupo pode usar. Se chega a esse limite e não consegue liberar nada, o kernel chama o “assassino por falta de memória” (*OOM killer*) **dentro desse grupo** ([cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)).
- `cpu.max`: dois números, “quanto tempo” e “a cada quanto”. Por padrão vale `max 100000`, o que significa sem teto em cada período de 100.000 microssegundos (um décimo de segundo).
- `pids.max`: quantos processos o grupo pode ter no máximo.

#### 0.4.2 Sem limite não há limite

O mais importante desta seção é o que o Docker faz **se nada lhe é pedido**. A documentação é explícita: “por padrão, um contêiner não tem restrições de recursos” e pode usar tudo o que o escalonador do kernel deixar ([Docker, “Resource constraints”](https://docs.docker.com/engine/containers/resource_constraints/)). O `fig00_04.sh` lê os três arquivos em um contêiner sem limites e em outro com limites:

```bash
#!/usr/bin/env bash
# fig00_04.sh — Los grupos de control (cgroups): lo que el núcleo deja gastar.
# Primero sin límites, después con límites de memoria, CPU y procesos.
set -euo pipefail
IMAGEN=alpine:3.24.2
LEER='for f in memory.max cpu.max pids.max; do printf "%-11s %s\n" "$f" "$(cat /sys/fs/cgroup/$f)"; done'

echo "== Sin límites (lo que Docker hace si no le pides nada)"
docker run --rm --name curso-docker-sin-limites "$IMAGEN" sh -c "$LEER"

echo
echo "== Con --memory 64m --cpus 0.5 --pids-limit 50"
docker run --rm --name curso-docker-con-limites \
  --memory 64m --cpus 0.5 --pids-limit 50 \
  "$IMAGEN" sh -c "$LEER"
```

```text
$ ./fig00_04.sh
== Sin límites (lo que Docker hace si no le pides nada)
memory.max  max
cpu.max     max 100000
pids.max    max

== Con --memory 64m --cpus 0.5 --pids-limit 50
memory.max  67108864
cpu.max     50000 100000
pids.max    50
```

Esta saída é estável, com duas condições. A primeira, a versão 2 dos cgroups, que é a que o Ubuntu 24.04, a base do Mint 22, tem (a máquina destas execuções a utiliza: `stat -fc %T /sys/fs/cgroup` imprime `cgroup2fs`). A segunda, que estejam habilitados os *controladores* `memory`, `cpu` e `pids`, que são as peças do kernel que levam cada conta: na versão 2 eles são habilitados um por um, e um arquivo como `memory.max` só aparece em um grupo se o seu controlador estiver habilitado ([documentação do kernel, cgroup v2](https://docs.kernel.org/admin-guide/cgroup-v2.html)). Em uma instalação normal do Mint eles estão; para conferir, `cat /sys/fs/cgroup/cgroup.controllers` deve incluir essas três palavras (na máquina destas execuções imprimiu `cpuset cpu io memory hugetlb pids rdma misc`). Se faltar alguma, o Docker pode avisar com um `WARNING` no final de `docker info` ([Docker, restrições de recursos](https://docs.docker.com/engine/containers/resource_constraints/)), o arquivo correspondente não existe dentro do contêiner e a saída não será parecida com esta. Sem limites, os três arquivos dizem `max`: o contêiner pode usar toda a memória da máquina, toda a CPU e criar todos os processos que quiser. Esse era o contêiner da cena.

Com limites, cada opção de `docker run` se converte em um número que o kernel faz cumprir:

- `--memory 64m` virou `67108864`, que são 64 × 1024 × 1024 bytes: 64 MiB exatos.
- `--cpus 0.5` virou `50000 100000`: a cada décimo de segundo, o grupo pode usar a CPU durante a metade, 50.000 microssegundos. É meia CPU.
- `--pids-limit 50` virou `50`.

Repare na cadeia de responsabilidades. Escreve-se uma opção em `docker run`; o Docker a traduz e a escreve em um arquivo do kernel; o kernel é quem a aplica. O Docker não vigia o contêiner: quem vigia é o kernel. Por isso o limite funciona mesmo que o programa de dentro seja malicioso ou esteja quebrado.

#### 0.4.3 O que acontece quando o limite é alcançado

Um limite que nunca é tocado não ensina nada. O `fig00_05.sh` inicia um contêiner com 32 MiB de memória e sem *swap*, e pede a ele algo que não pode cumprir: `tail /dev/zero` lê um arquivo infinito de zeros procurando o final da última linha e, como nunca chega uma quebra de linha, guarda tudo na memória sem parar:

```bash
#!/usr/bin/env bash
# fig00_05.sh — El error de esta lección: el núcleo mata al proceso que pasa su límite.
# El contenedor intenta llenar la memoria; tiene un tope de 32 MiB y sin swap.
set -uo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-gloton
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run --name "$NOMBRE" --memory 32m --memory-swap 32m \
  "$IMAGEN" sh -c 'echo "voy a comer memoria..."; tail /dev/zero'
echo "código de salida: $?"

echo
echo "== Lo que Docker anotó"
docker inspect --format 'OOMKilled={{.State.OOMKilled}}  ExitCode={{.State.ExitCode}}' "$NOMBRE"
```

```text
$ ./fig00_05.sh
voy a comer memoria...
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

Esta saída é estável. Aqui não se usa `--rm`, de propósito: se o Docker apagasse o contêiner ao terminar, não seria possível perguntar depois o que aconteceu com ele. `--memory-swap 32m` fixa o total de memória mais *swap* no mesmo valor da memória, ou seja, zero de *swap*; sem isso, o processo demoraria mais para morrer porque primeiro encheria o *swap*.

O contêiner imprimiu a sua mensagem, começou a consumir memória e, ao chegar a 32 MiB, o kernel o matou. Ninguém mais na máquina ficou sabendo: o banco de dados da cena, se estivesse ali, continuaria vivo. O número **137** é a convenção para dizer “este processo morreu por um sinal”: é 128 mais o número do sinal, e o sinal 9 é `KILL`, o que não pode ser capturado nem ignorado. A convenção não foi inventada pelo Docker: é a do *shell*, cujo manual diz que, quando um comando termina pelo sinal N, o *bash* usa 128+N como código de saída ([manual do Bash](https://www.gnu.org/software/bash/manual/html_node/Exit-Status.html)); pode-se comprovar em qualquer *bash*: `bash -c 'kill -9 $$'; echo $?` imprime `137`. O Docker anota o mesmo número em `ExitCode`, e `docker run` o devolve tal qual, porque qualquer código diferente de 125, 126 e 127 é o do comando do contêiner ([Docker, códigos de saída](https://docs.docker.com/engine/containers/run/)). E `OOMKilled=true` é o Docker confirmando que foi por falta de memória. A seção “O erro que se vai ver” diz como ler isso quando aparecer sem ter sido provocado.

Agora se pode reescrever a cena com precisão. O contêiner do `revisor` estava no seu próprio namespace (não via o banco de dados), mas em um cgroup sem limite (gastava do mesmo reservatório). Quando o reservatório esvaziou, o kernel teve de matar alguém **na máquina inteira**, não só no grupo do contêiner, e escolheu outro. Com `--memory`, o assassino teria agido **dentro do grupo** do `revisor`, e só o `revisor` teria morrido. A Lição 2 põe limites desde o primeiro contêiner por esta razão.

### 0.5 Imagem versus contêiner

#### 0.5.1 O modelo e a cópia viva

Até aqui se usaram duas palavras como se fossem intercambiáveis, e não são. A documentação do Docker as define assim: uma **imagem** é “um modelo somente leitura com instruções para criar um contêiner”, e um **contêiner** é “uma instância executável de uma imagem” ([Docker, “What is Docker?”](https://docs.docker.com/get-started/docker-overview/)).

Uma comparação que ajuda, para quem vem da programação: a imagem é como um executável em disco e o contêiner é como o processo que roda a partir dele. Do mesmo executável é possível lançar dez processos; da mesma imagem é possível criar dez contêineres. Se o processo escreve algo na sua memória, o executável em disco não muda.

A peça que falta é onde um contêiner escreve quando cria um arquivo. A resposta, segundo a documentação de armazenamento do Docker: uma imagem é feita de **camadas** somente leitura, e ao criar um contêiner acrescenta-se por cima dela uma camada fina **na qual se pode escrever**, chamada de camada do contêiner. Tudo o que o contêiner muda vai para essa camada. Vários contêineres podem compartilhar a mesma imagem, cada um com a sua camada própria. E quando o contêiner é apagado, a sua camada é apagada com ele, enquanto a imagem de baixo “continua sem alterações” ([Docker, “Storage drivers”](https://docs.docker.com/engine/storage/drivers/)).

#### 0.5.2 Ver com os próprios olhos

O `fig00_06.sh` cria dois contêineres da mesma imagem, escreve um arquivo em um, vê se o outro o enxerga, pergunta o que mudou em cada um e, no final, apaga o primeiro:

```bash
#!/usr/bin/env bash
# fig00_06.sh — Imagen contra contenedor: una plantilla, dos copias vivas.
set -euo pipefail
IMAGEN=alpine:3.24.2
A=curso-docker-uno
B=curso-docker-dos
trap 'docker rm -f "$A" "$B" >/dev/null 2>&1 || true' EXIT

echo "== La imagen antes de empezar"
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22

docker run -d --name "$A" "$IMAGEN" sleep 300 >/dev/null
docker run -d --name "$B" "$IMAGEN" sleep 300 >/dev/null

echo
echo "== Escribo un archivo en el contenedor uno"
docker exec "$A" sh -c 'echo "hola desde uno" > /tmp/nota.txt && cat /tmp/nota.txt'

echo
echo "== ¿Lo ve el contenedor dos?"
docker exec "$B" cat /tmp/nota.txt || echo "(el contenedor dos no tiene ese archivo)"

echo
echo "== Lo que cambió en cada contenedor respecto de su imagen (docker diff)"
echo "-- uno:"; docker diff "$A"
echo "-- dos:"; docker diff "$B"; echo "(nada)"

echo
echo "== Borro el contenedor uno y miro la imagen otra vez"
docker rm -f "$A" >/dev/null
docker image inspect --format 'id={{.Id}}' "$IMAGEN" | cut -c1-22
docker run --rm --name curso-docker-tres "$IMAGEN" sh -c 'cat /tmp/nota.txt 2>&1 || true'
```

```text
$ ./fig00_06.sh
== La imagen antes de empezar
id=sha256:294b683cb724

== Escribo un archivo en el contenedor uno
hola desde uno

== ¿Lo ve el contenedor dos?
cat: can't open '/tmp/nota.txt': No such file or directory
(el contenedor dos no tiene ese archivo)

== Lo que cambió en cada contenedor respecto de su imagen (docker diff)
-- uno:
C /tmp
A /tmp/nota.txt
-- dos:
(nada)

== Borro el contenedor uno y miro la imagen otra vez
id=sha256:294b683cb724
cat: can't open '/tmp/nota.txt': No such file or directory
```

O identificador `294b683cb724` é o da imagem `alpine:3.24.2` para processadores ARM de 64 bits; em uma máquina Intel ou AMD será outro, mas será **o mesmo no início e no final** da execução, que é o que importa. `docker diff` mostra o que um contêiner mudou em relação à sua imagem: `A` significa adicionado (*added*) e `C`, alterado (*changed*); a pasta `/tmp` aparece como alterada porque agora contém algo novo.

Leia a saída como uma história de quatro momentos:

1. A imagem tem um identificador, um *digest* do seu conteúdo.
2. O contêiner um escreve `/tmp/nota.txt` e o lê sem problema. O contêiner dois, feito **da mesma imagem**, não o tem: cada um escreve na sua própria camada.
3. `docker diff` confirma: o um adicionou um arquivo; o dois não mudou nada.
4. O contêiner um é apagado. A imagem tem **o mesmo identificador**: nada do que o contêiner fez a tocou. E um contêiner novo dessa imagem também não tem a nota. O arquivo se foi com o contêiner.

As consequências para o resto do curso são duas, e as duas são importantes. A primeira: **o que se escreve dentro de um contêiner é descartável**. Se o `revisor` guarda o seu relatório dentro do contêiner e alguém o apaga, o relatório vai embora. Por isso existe a Lição 8, com os volumes. A segunda: **uma imagem não se conserta entrando no contêiner**. Entrar com `docker exec` para corrigir algo corrige essa cópia viva, não o modelo; o próximo contêiner nasce sem o conserto. As imagens se mudam reconstruindo-as a partir da sua receita, o `Dockerfile`, que é o que se aprende na Lição 3.

### 0.6 O cliente e o daemon

#### 0.6.1 Dois programas, não um

Quando se digita `docker run`, parece que um único programa faz tudo. Não é assim. O Docker usa uma arquitetura **cliente-servidor**: o programa `docker` que se digita é apenas um **cliente**, e o trabalho de verdade é feito por um **daemon** chamado `dockerd`, um programa que roda em segundo plano o tempo todo. Segundo a documentação, o daemon “escuta as requisições da API do Docker e administra os objetos do Docker” (imagens, contêineres, redes e volumes), e cliente e daemon conversam “usando uma API REST, sobre *sockets* de UNIX ou uma interface de rede” ([Docker, “What is Docker?”](https://docs.docker.com/get-started/docker-overview/)).

Um ***socket* de UNIX** é um arquivo especial que serve para que dois programas da mesma máquina troquem mensagens. O do daemon do Docker está, por padrão, em `/var/run/docker.sock`. E já se viu a quem cabe criar os contêineres: o `containerd-shim` que apareceu como pai do `sleep` em 0.1 faz parte da cadeia que o daemon aciona. Pede-se ao cliente; o cliente pede ao daemon; o daemon, com a ajuda de outras peças, pede ao kernel os namespaces e os cgroups.

O `fig00_07.sh` mostra as duas metades e o que acontece quando o cliente não encontra o daemon:

```bash
#!/usr/bin/env bash
# fig00_07.sh — El cliente y el daemon son dos programas distintos.
set -uo pipefail

echo "== Las dos versiones: la del cliente y la del daemon"
docker version --format 'cliente: {{.Client.Version}} ({{.Client.Os}}/{{.Client.Arch}})
daemon:  {{.Server.Version}} ({{.Server.Os}}/{{.Server.Arch}})'

echo
echo "== Por dónde habla el cliente con el daemon"
docker context inspect --format '{{.Endpoints.docker.Host}}'

echo
echo "== El cliente apuntando a un daemon que no existe"
DOCKER_HOST=unix:///tmp/curso-docker-no-hay-daemon.sock docker ps
echo "código de salida: $?"
```

```text
$ ./fig00_07.sh
== Las dos versiones: la del cliente y la del daemon
cliente: 29.2.1 (linux/arm64)
daemon:  29.2.1 (linux/arm64)

== Por dónde habla el cliente con el daemon
unix:///var/run/docker.sock

== El cliente apuntando a un daemon que no existe
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
código de salida: 1
```

Em cada máquina mudam as versões e, se for Intel ou AMD, dirá `amd64`. `docker context inspect` mostra para qual daemon o cliente aponta, e a variável de ambiente `DOCKER_HOST` serve para apontá-lo para outro; aqui, de propósito, para um que não existe.

Três coisas que se aprendem com esta saída:

1. **`docker version` mostra duas versões**, porque são dois programas. Quase sempre coincidem, mas não têm por que coincidir: no Mac destas execuções, o cliente do macOS era a 29.8.2 e o daemon da máquina virtual, a 29.2.1. Quando um comando se comporta de forma estranha, a primeira pergunta é qual das duas versões o está causando.
2. **O cliente e o daemon conversam pelo *socket***. É um ponto de entrada, e quem tiver acesso a ele manda no daemon.
3. **Sem daemon, o cliente não serve para nada.** A mensagem diz exatamente isso: não conseguiu se conectar à API do Docker nesse caminho; confira se o caminho está correto e se o daemon está rodando. No Mint se verá essa mensagem com o caminho `/var/run/docker.sock` no dia em que o serviço do Docker estiver parado.

#### 0.6.2 Por que importa saber isso

Parece uma curiosidade de arquitetura e não é. O daemon roda como `root`: o guia de segurança diz que ele “requer privilégios de `root`”, a menos que se ative o modo *rootless*, e que por isso “somente usuários de confiança” devem poder controlá-lo ([Docker Engine security](https://docs.docker.com/engine/security/)). Quem pode pedir coisas ao daemon pode pedir que ele crie um contêiner com a pasta raiz da máquina montada dentro, e ele o fará como `root`. Por isso a documentação de instalação adverte que o grupo `docker` “concede privilégios equivalentes aos de `root`” ao usuário ([Docker, passos posteriores à instalação no Linux](https://docs.docker.com/engine/install/linux-postinstall/)). A Lição 1 inclui o usuário nesse grupo e mostra a consequência sem rodeios. E a Lição 2 proíbe, com este mesmo argumento, montar o *socket* do daemon dentro de um contêiner: isso daria ao contêiner a chave da máquina.

### 0.7 O que é compartilhado e por que isso decide a segurança

#### 0.7.1 Root dentro é root fora

Já estão reunidas todas as peças para a pergunta mais séria da lição: quão separado está um contêiner do host? O `fig00_08.sh` pergunta quem é o usuário dentro, de quem é o processo visto de fora e que poderes ele tem:

```bash
#!/usr/bin/env bash
# fig00_08.sh — Lo que el contenedor comparte con el anfitrión: el usuario y el núcleo.
set -euo pipefail
IMAGEN=alpine:3.24.2
NOMBRE=curso-docker-quien
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== Dentro del contenedor, ¿quién soy?"
docker run --rm --name curso-docker-id "$IMAGEN" id

echo
echo "== Y desde el anfitrión, ¿de quién es ese proceso?"
docker run -d --name "$NOMBRE" "$IMAGEN" sleep 300 >/dev/null
PID=$(docker inspect --format '{{.State.Pid}}' "$NOMBRE")
ps -o uid,user,args -p "$PID"

echo
echo "== Las capacidades efectivas de ese root (máscara en hexadecimal)"
echo "$(docker run --rm --name curso-docker-cap1 "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, por omisión"
echo "$(docker run --rm --name curso-docker-cap2 --cap-drop ALL "$IMAGEN" grep CapEff /proc/self/status | cut -f2)  contenedor, con --cap-drop ALL"
echo "$(grep CapEff /proc/1/status | cut -f2)  proceso 1 del anfitrión (root)"
```

```text
$ ./fig00_08.sh
== Dentro del contenedor, ¿quién soy?
uid=0(root) gid=0(root) groups=0(root),0(root),1(bin),2(daemon),3(sys),4(adm),6(disk),10(wheel),11(floppy),20(dialout),26(tape),27(video)

== Y desde el anfitrión, ¿de quién es ese proceso?
  UID USER     COMMAND
    0 root     sleep 300

== Las capacidades efectivas de ese root (máscara en hexadecimal)
00000000a80425fb  contenedor, por omisión
0000000000000000  contenedor, con --cap-drop ALL
000001ffffffffff  proceso 1 del anfitrión (root)
```

Esta saída é estável com a configuração padrão do Docker. A última linha depende de quantas capacidades o kernel conhece; com um da série 6.8 sai igual.

Os dois primeiros blocos dizem o mesmo dos dois lados: dentro do contêiner o usuário é o 0, `root`, e fora esse processo **também** é do usuário 0. Não é um `root` de brinquedo com o mesmo nome: como o namespace de usuários não foi isolado (0.3), é o mesmo número de usuário para o mesmo kernel. Se esse processo conseguisse sair das suas paredes (por um erro do kernel, por uma pasta do host montada sem cuidado, pelo *socket* do daemon), chegaria ao host como `root`.

#### 0.7.2 Um root reduzido: as capacidades

Então, um contêiner é tão perigoso quanto um programa que roda como `root` na máquina? Não totalmente, e o terceiro bloco explica por quê. O Linux divide os poderes do `root` em unidades separadas chamadas **capacidades** (*capabilities*), que podem ser ativadas e desativadas uma por uma ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Mudar o dono de um arquivo é uma; abrir uma porta menor que 1024, outra; carregar módulos no kernel, outra.

A linha `CapEff` de `/proc/<pid>/status` diz quais capacidades um processo tem ativas, como uma máscara de bits em hexadecimal. O processo 1 do host, que é `root` de verdade, tem `000001ffffffffff`: as 41 capacidades que este kernel conhece, todas ativas. O `root` do contêiner tem `00000000a80425fb`, que são **14**. Ao decodificar essa máscara com a ferramenta `capsh` do host saem exatamente as catorze que a documentação do Docker lista como permitidas por padrão: `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `FSETID`, `KILL`, `SETGID`, `SETUID`, `SETPCAP`, `NET_BIND_SERVICE`, `NET_RAW`, `SYS_CHROOT`, `MKNOD`, `AUDIT_WRITE` e `SETFCAP` ([Docker, “Running containers”](https://docs.docker.com/engine/containers/run/)). O Docker usa uma lista do permitido, não do proibido: tira tudo e deixa só isso ([Docker Engine security](https://docs.docker.com/engine/security/)). E com `--cap-drop ALL` é possível tirar até essas catorze, como mostra a segunda linha; a Lição 7 ensina a tirar as que o `revisor` não usa.

A opção contrária existe e convém reconhecê-la para não usá-la: `--privileged` “dá todas as capacidades ao contêiner” e além disso acesso a todos os dispositivos do host ([Docker, “Running containers”](https://docs.docker.com/engine/containers/run/)). Com ela, quase não sobra parede.

#### 0.7.3 O mapa do que é compartilhado

| O que o contêiner tem de próprio, por padrão | O que ele compartilha com o host, por padrão |
|---|---|
| seus processos e seus números de processo | **o kernel**, o mesmo para todos os contêineres |
| sua árvore de arquivos (a da sua imagem e a da sua camada) | **os usuários**: `root` dentro é o usuário 0 fora |
| sua rede, suas portas, seu nome de máquina | os relógios do sistema |
| sua visão dos cgroups | **a memória, a CPU e o disco**, se não houver limites |
| | **o que for montado nele ou publicado para ele**: pastas, portas, o *socket* |

A coluna da direita é a lista do que é preciso cuidar. Cada lição do curso fecha uma parte: a 2 põe limites e publica portas apenas em `127.0.0.1`; a 3 deixa de usar `root` com `USER`; a 7 tira capacidades e põe o sistema de arquivos em somente leitura; a 8 cuida do que é montado. Não é paranoia: é a diferença entre um processo com paredes e um processo com paredes de papel.

> [!NOTE]
> 🔧 **Observação de engenharia 0.3**
> Em uma máquina virtual, para escapar é preciso quebrar o hipervisor, que imita um hardware simples. Em um contêiner, para escapar basta encontrar um erro no kernel, que é enorme e que todos os contêineres compartilham. Por isso os contêineres são endurecidos com várias camadas ao mesmo tempo (sem `root`, sem capacidades sobrando, com limites) e não se confia em uma só.

### 0.8 De onde saiu tudo isso

Nada do que foi dito acima foi inventado pelo Docker. As peças são do kernel do Linux e chegaram aos poucos. O guia de segurança do Docker conta: os namespaces entraram no kernel entre as versões 2.6.15 e 2.6.26, esta última de julho de 2008, e os cgroups começaram em 2006 e foram integrados na versão 2.6.24 ([Docker Engine security](https://docs.docker.com/engine/security/)). Durante anos houve ferramentas que os usavam, mas eram difíceis de usar.

O que mudou em 2013 foi a **forma de usá-los**. Em 15 de março daquele ano, em uma palestra relâmpago de cinco minutos na conferência PyCon, Solomon Hykes contou que na empresa dele usavam contêineres de Linux, que era complicado e que por isso não tinham falado disso, “até agora: Docker” ([PyCon US 2013, “The future of Linux Containers”](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html)). O Docker juntou as peças do kernel com duas ideias próprias: um formato de imagem que pode ser compartilhado e comandos que qualquer pessoa entende.

Dois anos depois, em 22 de junho de 2015, o Docker, a CoreOS e outras empresas fundaram a **Open Container Initiative** (OCI), e o Docker doou a ela o seu formato e o seu programa para criar contêineres, o `runc` ([OCI, “About”](https://opencontainers.org/about/overview/)). Hoje a OCI mantém três especificações: a do ambiente de execução, a do formato de imagem e a de distribuição. Na prática, isso significa que a imagem construída neste curso não é “uma imagem do Docker” trancada dentro do Docker, é uma imagem OCI, e por isso o cluster de Kubernetes do curso seguinte pode rodá-la sem o Docker. A propósito, `runc` é o programa que aparece no final do nome `containerd-shim-runc-v2` visto em 0.1.

### 0.9 O que vem no resto do curso

Com o mapa desta lição, cada lição seguinte é uma peça cujo lugar já se conhece:

- A **Lição 1** instala o cliente, o daemon e as peças do meio no Mint.
- A **Lição 2** lida com processos isolados: iniciá-los, olhá-los, dar-lhes orçamento (0.4) e apagá-los.
- As **Lições 3, 4 e 5** constroem a **imagem** do `revisor` (0.5): sua receita, suas camadas e como torná-la pequena.
- A **Lição 6** separa a configuração e os segredos da imagem.
- A **Lição 7** trata do processo número 1 (0.1) e de reduzir seus poderes (0.7).
- A **Lição 8** resolve que a camada do contêiner seja descartável (0.5) e conecta contêineres por rede (0.3).
- A **Lição 9** descreve tudo isso em um arquivo, e a **10** entrega a imagem OCI (0.8) pronta para o Kubernetes.

## O erro que se vai ver

Esta lição tem um erro principal, o do contêiner que o kernel mata, e um secundário, o do cliente sem daemon. Os dois vêm de seções anteriores.

**O erro principal: o código 137 e `OOMKilled=true`.** É o do `fig00_05.sh`:

```text
código de salida: 137

== Lo que Docker anotó
OOMKilled=true  ExitCode=137
```

Lê-se assim: o processo não terminou por conta própria; foi morto pelo sinal 9 (`137 = 128 + 9`), e o Docker anotou que a causa foi a falta de memória. O traiçoeiro é que na vida real o contêiner **não avisa**: não imprime nada, simplesmente desaparece, e se tem uma política de reinício volta a iniciar e a morrer repetidas vezes. Ao ver um 137, a primeira pergunta é `docker inspect --format '{{.State.OOMKilled}}' <contêiner>`. Se disser `true`, há dois consertos possíveis, conforme o caso: aumentar o limite de memória, se o programa realmente precisa de mais; ou corrigir o programa, se ele está gastando demais. O que **não** se faz é tirar o limite “para que não morra”: isso não resolve, só muda quem morre, como na cena.

**O erro secundário: o cliente que não encontra o daemon.**

```text
failed to connect to the docker API at unix:///tmp/curso-docker-no-hay-daemon.sock; check if the path is correct and if the daemon is running: dial unix /tmp/curso-docker-no-hay-daemon.sock: connect: no such file or directory
```

Lê-se da esquerda para a direita: o cliente não conseguiu se conectar à API do Docker nesse caminho; sugere conferir o caminho e se o daemon está rodando; e no final vem a causa técnica, que o arquivo do *socket* não existe. No Mint, com o caminho `/var/run/docker.sock`, quase sempre significa que o serviço do Docker está parado. Se em vez de `no such file or directory` disser `permission denied`, o daemon está lá, mas o usuário não tem permissão para falar com ele: isso é assunto da Lição 1.

## O hábito de segurança da lição

**Saber o que um contêiner compartilha com a máquina, e não confiar no que ele não isola.** O contêiner compartilha o kernel, os usuários e, se não lhe forem postos limites, a memória e a CPU. Esse hábito evita dois acidentes concretos. O primeiro é o da cena: um contêiner sem limite que derruba outros programas da mesma máquina. O segundo é mais grave: tratar um contêiner como se fosse uma máquina à parte e dar a ele coisas do host (o *socket* do daemon, a pasta raiz montada, `--privileged`) pensando que “lá dentro não acontece nada”. Lá dentro roda um processo de `root` do próprio kernel do host. Tudo o que lhe for dado será entregue a esse processo.

## O que se faz errado

**Dizer “é como uma máquina virtual leve”.** É a frase mais repetida e a que mais prejudica, porque leva a esperar um isolamento que não existe. Um contêiner é um processo isolado; uma máquina virtual é um computador imitado. Parecem-se no que se vê de fora e se diferenciam no que importa quando algo falha.

**Rodar contêineres sem limites “porque na minha máquina sobra memória”.** Por padrão não há limite, e o que sobra hoje não sobra no dia em que o programa tem um erro. O limite não é para o caso normal; é para o dia ruim.

**Entrar no contêiner para “consertar” algo.** O que se muda com `docker exec` vive na camada do contêiner e vai embora com ele. A correção se faz na receita da imagem e se reconstrói.

**Guardar dados importantes dentro do contêiner.** Pela mesma razão: a camada do contêiner é descartável. Os dados que devem sobreviver vão em volumes (Lição 8).

**Supor que `root` dentro é inofensivo.** É o usuário 0 do mesmo kernel, com 14 capacidades ativas. Menos que o `root` do host, mas muito mais que um usuário normal. A partir da Lição 3, o `revisor` não roda como `root`.

**Acreditar que uma imagem do Ubuntu ou do Debian traz esse sistema operacional completo.** Traz o seu espaço de usuário. O kernel é o do host. Se esse kernel não suporta algo, a imagem também não.

**Confundir o cliente com o daemon.** Quando um comando falha, saber se o problema está no cliente (versão, configuração, `DOCKER_HOST`) ou no daemon (parado, sem permissões, outra versão) poupa horas procurando no lugar errado.

## Exercícios

Os exercícios desta lição não precisam do Docker para serem respondidos: o primeiro e o quarto são de raciocínio, e o segundo e o terceiro são respondidos **antes** de rodar qualquer coisa e conferidos depois da Lição 1. Escreva as previsões no [diário de bordo](bitacora.md) antes de ver as soluções; compará-las é metade do aprendizado.

### Exercício 1 — A noite do `revisor` (projeto)

Volte à cena do início. Responda com as próprias palavras, usando o que foi aprendido:

1. Por que o contêiner do `revisor` não “via” o banco de dados, mas pôde matá-lo?
2. Que opção de `docker run` teria evitado que o banco de dados morresse, e quem teria morrido no lugar dele?
3. Se naquele momento fosse rodado `docker inspect` sobre o contêiner do `revisor`, o que se esperaria ver em `OOMKilled`? Pense bem: quem matou quem?

### Exercício 2 — Igual ou diferente?

Para cada par, preveja se o valor sai **igual** ou **diferente**. Suponha a configuração padrão do Docker.

1. `uname -r` no Mint e dentro de um contêiner de `debian:13.7-slim`.
2. `cat /etc/os-release` no Mint e dentro desse mesmo contêiner.
3. `readlink /proc/self/ns/net` no Mint e dentro de um contêiner.
4. `readlink /proc/self/ns/user` no Mint e dentro de um contêiner.
5. O número de processo do programa principal visto dentro do contêiner, e visto do host.
6. O identificador de uma imagem antes e depois de apagar um contêiner que escreveu arquivos.

### Exercício 3 — Preveja o `memory.max`

Preveja que número aparece em `/sys/fs/cgroup/memory.max` dentro de cada um destes contêineres, e depois confira mudando as opções do `fig00_04.sh`:

1. `docker run --rm alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
2. `docker run --rm --memory 128m alpine:3.24.2 cat /sys/fs/cgroup/memory.max`
3. `docker run --rm --memory 1g alpine:3.24.2 cat /sys/fs/cgroup/memory.max`

E uma de CPU: o que dirá `cpu.max` com `--cpus 1.5`?

### Exercício 4 — Explique em cinco frases

Um colega diz: “Instalei o Docker para ter uma máquina virtual de Ubuntu dentro do meu Mint”. Explique a ele em no máximo cinco frases o que ele tem na realidade, usando as palavras *processo*, *kernel*, *namespace*, *cgroup* e *imagem*. Sem olhar a lição.

## Soluções

### Solução 1

1. Porque o contêiner estava nos seus próprios **namespaces**: com o de processos (`pid`) não via os processos do host, entre eles o banco de dados. Mas ver e gastar são coisas diferentes: sem um limite no seu **cgroup**, ele gastava da mesma memória que a máquina inteira. Quando ela acabou, o kernel teve de matar alguém em todo o sistema, e escolheu o banco de dados.
2. `--memory` (por exemplo, `--memory 256m`; o número depende de quanto o `revisor` realmente precisa). Com esse limite, ao chegar ao teto o kernel teria agido **dentro do grupo** do contêiner, e quem teria morrido é o próprio `revisor`, com código 137 e `OOMKilled=true`. O banco de dados nem teria ficado sabendo.
3. O mais provável é `false`. Sem limite próprio, o contêiner não chegou a um teto do **seu** grupo: o que se esgotou foi a memória da máquina inteira, e o kernel matou o banco de dados, que não é um contêiner. O `revisor` continuou vivo. É justamente o que torna a cena enganosa: o culpado não tem a marca, a vítima é que tem (e no log do sistema, não no Docker).

### Solução 2

1. **Igual.** O kernel é um só, compartilhado (fig00_02).
2. **Diferente.** O arquivo vem da imagem, que traz o espaço de usuário do Debian (fig00_02).
3. **Diferente.** A rede está isolada: cada contêiner tem o seu namespace `net` (fig00_03).
4. **Igual.** Por padrão, o Docker não isola os usuários (fig00_03). Por isso `root` dentro é o usuário 0 fora (fig00_08).
5. **Diferente.** Dentro é o 1; fora, um número qualquer, como o 836426 do fig00_01. É o mesmo processo visto de dois namespaces de processos.
6. **Igual.** O que o contêiner escreveu vivia na sua camada própria e se foi com ele; a imagem não mudou (fig00_06).

Errar o 4 é o tropeço mais comum e o mais importante: é a razão de todo o bloco de segurança do curso.

### Solução 3

Valores conferidos com a mesma máquina e a mesma versão do Docker da lição:

1. `max`: sem `--memory` não há limite.
2. `134217728`, que é 128 × 1024 × 1024.
3. `1073741824`, que é 1024 × 1024 × 1024. O Docker interpreta o `g` como gibibytes (potências de 1024), assim como o `m` como mebibytes.

Com `--cpus 1.5`, `cpu.max` diz `150000 100000`: em cada período de 100.000 microssegundos, o grupo pode usar 150.000 microssegundos de CPU, repartidos entre os núcleos do processador. Uma CPU e meia.

### Solução 4

Uma resposta possível: “Isso não é uma máquina virtual; é um programa que cria **processos** isolados. Esses processos rodam sobre o **kernel** do Mint, o mesmo para todos, e por isso iniciam em décimos de segundo. Os **namespaces** põem paredes neles para que vejam seus próprios processos, arquivos e rede, e os **cgroups** dão a eles um orçamento de memória e CPU, quando se pede. O “Ubuntu” vem da **imagem**: ela traz os programas e bibliotecas do Ubuntu, mas não o seu kernel. E como o usuário `root` de dentro é o mesmo número de usuário que o de fora, é preciso tratá-lo com cuidado”.

## Como sei que consegui

Não há nada para construir nesta lição, então a lista mistura compreensão e, depois da Lição 1, verificação. Marque cada ponto só se for possível fazê-lo **sem olhar o texto de novo**:

- [ ] Explicar em um minuto por que um contêiner não é uma máquina virtual, incluindo a palavra *kernel* na explicação.
- [ ] Nomear os seis namespaces que o Docker isola por padrão e os dois que não.
- [ ] Dizer o que contêm `memory.max` e `cpu.max` sem limites, e o que significa `50000 100000`.
- [ ] Explicar o que significam o código 137 e `OOMKilled=true`, e o que **não** se deve fazer quando aparecem.
- [ ] Explicar o que acontece com um arquivo escrito dentro de um contêiner quando esse contêiner é apagado, e por que a imagem não muda.
- [ ] Desenhar o caminho do `docker run`: cliente → *socket* → daemon → kernel.
- [ ] Dizer por que o grupo `docker` equivale a `root`.
- [ ] Depois da Lição 1, rodar os nove scripts de [`programas/00-que-es-un-contenedor/`](../programas/00-que-es-un-contenedor) e verificar que as saídas coincidem com as desta lição no que cada seção marca como estável. O que não se compara, porque muda de uma máquina ou de uma execução para outra: os números de processo, os números dos namespaces, os tempos, as versões e a arquitetura; e se o Docker roda em modo *rootless* ou com remapeamento de usuários, ou se falta algum controlador dos cgroups, as diferenças previstas em 0.3 e 0.4.2. E ao terminar, `docker ps -a --filter name=curso-docker-` não mostra nada: não ficou lixo para trás.
- [ ] Anotar no diário de bordo o que se acreditava que era um contêiner antes desta lição.

## Resumo

Responda sem olhar a lição:

1. O que é um contêiner, em três palavras? Por que ele aparece no `ps` do host?
2. O que tem uma máquina virtual que um contêiner não tem? Por que um Mac precisa de uma máquina virtual para rodar contêineres de Linux?
3. O que faz um namespace? Dê três exemplos do que ele isola.
4. O que faz um cgroup? Que limite tem um contêiner se não se pede nenhum?
5. O que significam o 137 e `OOMKilled=true`?
6. O que é uma imagem e o que é um contêiner? Onde um contêiner escreve seus arquivos e o que acontece com eles ao apagá-lo?
7. O que fazem o cliente `docker` e o daemon `dockerd`, e por onde eles conversam?
8. Por que `root` dentro de um contêiner é uma questão de segurança, e o que o limita?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [Docker, “What is a container?”](https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/): a definição de contêiner como processo isolado e a comparação com as máquinas virtuais.
- [Docker, “What is Docker?”](https://docs.docker.com/get-started/docker-overview/): a arquitetura cliente-servidor, o daemon, as definições de imagem e contêiner, e o uso dos namespaces.
- [Docker Engine security](https://docs.docker.com/engine/security/): namespaces, cgroups, a superfície de ataque do daemon, as capacidades e os namespaces de usuário; também as datas de 0.8.
- [Docker, “Resource constraints”](https://docs.docker.com/engine/containers/resource_constraints/): que um contêiner não tem limites por padrão, e as opções `--memory`, `--memory-swap` e `--cpus`.
- [Docker, “Running containers”](https://docs.docker.com/engine/containers/run/): as catorze capacidades permitidas por padrão e o que faz `--privileged`.
- [Docker, “Storage drivers”](https://docs.docker.com/engine/storage/drivers/): as camadas somente leitura e a camada do contêiner.
- [Docker, passos posteriores à instalação no Linux](https://docs.docker.com/engine/install/linux-postinstall/): o aviso sobre o grupo `docker`.
- [Docker Desktop, permissões no Mac](https://docs.docker.com/desktop/setup/install/mac-permission-requirements/): a máquina virtual de Linux do Docker Desktop.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões e datas de “Sobre as execuções”.
- [namespaces(7), manual do Linux](https://man7.org/linux/man-pages/man7/namespaces.7.html): os oito tipos de namespaces e os links de `/proc/<pid>/ns`.
- [capabilities(7), manual do Linux](https://man7.org/linux/man-pages/man7/capabilities.7.html): processos privilegiados e capacidades.
- [Control Group v2, documentação do kernel do Linux](https://docs.kernel.org/admin-guide/cgroup-v2.html): `memory.max`, `cpu.max` e `pids.max`.
- [Open Container Initiative, “About”](https://opencontainers.org/about/overview/): a fundação da OCI e suas três especificações.
- [PyCon US 2013, “The future of Linux Containers”](https://pyvideo.org/pycon-us-2013/the-future-of-linux-containers.html): a palestra em que o Docker foi apresentado.
- [Colima](https://github.com/abiosoft/colima): a ferramenta com a qual os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **camada** (*layer*) | cada uma das partes somente leitura de uma imagem; o contêiner acrescenta uma camada própria onde escrever |
| **capacidade** (*capability*) | cada um dos poderes em que o Linux divide o usuário `root` |
| **cgroup** (grupo de controle) | mecanismo do kernel que conta e limita os recursos de um grupo de processos |
| **cliente** | o programa `docker` que se digita; manda requisições ao daemon |
| **contêiner** | um processo isolado criado a partir de uma imagem |
| **daemon** | programa que roda em segundo plano; o do Docker se chama `dockerd` |
| **espaço de usuário** | tudo o que roda por cima do kernel: programas, bibliotecas, *shell* |
| **host** (máquina hospedeira) | a máquina onde rodam os contêineres; no curso, o Linux Mint |
| **imagem** | modelo somente leitura a partir do qual os contêineres são criados |
| **kernel** (núcleo) | a parte do sistema operacional que manda no hardware |
| **máquina virtual** | um computador imitado por software, com o seu próprio kernel |
| **namespace** (espaço de nomes) | visão privada de um recurso do sistema (processos, rede, arquivos...) |
| **OCI** | *Open Container Initiative*, o padrão aberto de imagens e contêineres |
| **OOM killer** | a parte do kernel que mata processos quando a memória acaba |
| ***socket* de UNIX** | arquivo especial pelo qual dois programas da mesma máquina trocam mensagens |

---

**Próxima:** [Lição 1 — Instalar o Docker no Linux Mint](01-instalacion.md)
