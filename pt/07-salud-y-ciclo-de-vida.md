# Lição 7 — Verificação de saúde e ciclo de vida

São 23h15 de sexta-feira e a janela de manutenção fecha às 23h30. O plano é simples: atualizar o servidor onde roda o `revisor` e outros dezenove contêineres, reiniciá-lo e voltar para casa. Alguém os para um por um, com um laço `for … docker stop`, e o terminal fica pensando. Dez segundos. Outros dez. Outros dez. Três minutos depois termina, e quase todos ficaram marcados com um `Exited (137)`, que significa «mataram». O servidor volta a subir às 23h24 e tudo diz `Up`. Às 23h26, o painel de monitoramento continua vermelho: um dos serviços está «no ar», mas responde `503` a tudo, e o contêiner que dependia dele reinicia uma e outra vez, cada vez um pouco mais tarde. Ninguém sabe se os contêineres que morreram com 137 chegaram a salvar o que estavam escrevendo. Faltam quatro minutos e a pergunta é a de sempre: o que está rodando, o que está saudável e o que está fingindo? Esta lição existe para que essa pergunta possa ser respondida em segundos: um contêiner que diz como está, que morre em ordem quando se pede e que, enquanto vive, não pode fazer mais do que precisa.

**Tempo:** 2 × 45 min

**O que se constrói:** um contêiner que diz como está e morre bem. A imagem `curso-docker-revisor:1.4.0` traz sua própria verificação de saúde (`HEALTHCHECK`), feita com o mesmo binário e sem `curl`, e declara seu sinal de desligamento (`STOPSIGNAL`). E o contêiner roda reforçado: sistema de arquivos somente leitura, sem nenhuma capability de `root`, sem poder ganhar novos privilégios, com um *init* minúsculo como processo número 1, com limites e com uma política de reinício. Essas opções são as que a Lição 9 passa para o Compose.

**O que se aprende:** o que é um sinal, por que o processo número 1 de um contêiner é especial e como ler os códigos `0`, `1`, `137` e `143`; o prazo do `docker stop` e como mudá-lo; o que faz `--init` e o que é um zumbi; `HEALTHCHECK` sem `curl` e a diferença entre «rodando» e «saudável»; as quatro políticas de reinício e o que elas **não** fazem; `--read-only` com um `tmpfs` onde for necessário; `--cap-drop ALL`; e `no-new-privileges`, com um programa *setuid* que o demonstra.

**De onde se parte.** Da [Lição 6](06-configuracion-y-secretos.md) traz-se a imagem `curso-docker-revisor:1.3.0`: multi-stage, 16.1 MB, sem *shell*, com o usuário `65532`, sua versão gravada e nada de nenhum ambiente. Da [Lição 3](03-primer-dockerfile.md) traz-se uma medição que não se esquece: com `CMD` em forma *shell*, o `docker stop` demorou mais de dez segundos e o contêiner morreu com `137`, porque o sinal nunca chegou ao `revisor`. Da [Lição 2](02-contenedores-dia-a-dia.md) traz-se o `(health: starting)` visto no serviço de teste sem que ainda se soubesse de onde saía, e o costume de pôr limites de memória, CPU e processos. E da [Lição 0](00-que-es-un-contenedor.md) traz-se a ideia central: um contêiner é um processo da máquina, com o mesmo kernel, e o `root` de dentro tem catorze capabilities que hoje serão retiradas.

**O que esta lição não faz.** Não explica a fundo as montagens: o `tmpfs` da seção 7.7 é usado aqui para uma única pasta, e a [Lição 8](08-volumenes-y-redes.md) explica volumes, *bind mounts* e `tmpfs` por completo. Não usa a saúde para ordenar a inicialização de vários serviços (`depends_on` com `service_healthy`): isso é a [Lição 9](09-compose.md). Não toca em perfis de *seccomp* nem de AppArmor, nem em Docker sem `root`: são camadas que o Docker já aplica por padrão ou que exigem outra instalação, e este curso fica com as opções que qualquer pessoa pode escrever em um `docker run`. E não reinicia o daemon do Docker para testar `unless-stopped` contra `always`: isso derrubaria todos os contêineres da máquina, e a diferença se explica com a documentação.

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4, a mesma base do Linux Mint 22, o sistema de referência do curso, com kernel 6.8 e processador `arm64`. Os scripts foram executados **dentro** dessa máquina virtual, com Docker 29.2.1 (cliente e daemon), e com a pasta de trabalho no disco próprio do Linux. Para não colidir com outras execuções que usavam a mesma máquina, os scripts foram lançados com outro prefixo de nomes e outras portas (as variáveis `PREFIJO` e `PUERTO` que eles trazem); nenhum nome de contêiner nem de imagem, nem a porta da máquina, aparece nas saídas, de modo que o que se vê é exatamente o que foi impresso. Com seus valores padrão, os scripts usam nomes de apoio próprios que levam `fig07` (a imagem `curso-docker-revisor:fig07`, o contêiner `curso-docker-revisor-fig07`): assim nunca tocam na imagem `curso-docker-revisor:1.4.0` nem no contêiner `curso-docker-revisor`, e ao sair apagam só o que criaram. O curso foi planejado com Docker Engine 29.8.2, e a mais recente publicada naquele dia era a 29.9.2, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)); nada desta lição muda entre essas versões. O que **muda** de uma execução para outra, e é avisado onde aparece: os números de processo (ocultados com `<pid>` no próprio script; os scripts que os usam param se o contêiner não está rodando, porque um número `0` apontaria para processos da máquina), os milissegundos de cada `docker stop` e de cada reinício, os segundos de `Up` e o número do arquivo temporário do relatório (ocultado com `<n>`). A máquina virtual era compartilhada com outros trabalhos e, em algumas execuções, estava carregada: por isso alguns tempos saíram mais longos que outros, e onde importa isso é dito. Os scripts publicam nas portas 8080 (`fig07_03.sh` e `fig07_06.sh`) e 9000 (`fig07_04.sh`) da máquina: se o `curso-docker-revisor` ou o `curso-docker-prueba` estiverem rodando, apague-os antes ou lance o script com outra porta, por exemplo `PUERTO=18080 ./fig07_03.sh`; se não, o script para com `port is already allocated`. Um script, `fig07_05.sh`, usa `sudo` uma vez, para matar um processo de fora como faria o kernel; no Mint, ele vai pedir a senha de administrador. Os programas estão em [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida), cada um com sua saída ao lado, e `estado/` guarda os arquivos do projeto como ficam ao terminar.

## Ao terminar, será possível

- Ler o código de saída de um contêiner (`0`, `1`, `137`, `143`) e dizer que sinal o terminou ou se ele terminou sozinho.
- Explicar por que um programa que morre com `SIGTERM` no terminal ignora o mesmo sinal quando é o processo número 1 de um contêiner, e corrigir isso com `--init`.
- Medir quanto demora o `docker stop` e mudar seu prazo e seu sinal com `-t`, `--stop-timeout`, `STOPSIGNAL` e `--stop-signal`.
- Escrever um `HEALTHCHECK` em forma *exec* para uma imagem sem *shell* nem `curl`, e ler a saúde de um contêiner com `docker ps` e `docker inspect`.
- Escolher uma política de reinício para um serviço e prever o que o Docker faz quando o processo morre sozinho, quando é parado manualmente e quando está `unhealthy`.
- Rodar o `revisor` com `--read-only`, `--cap-drop ALL` e `--security-opt no-new-privileges`, e comprovar em `/proc` que o kernel aplica as três coisas.

## O porquê antes do como

Até agora o contêiner foi tratado como algo que inicia. Esta lição cuida de todo o resto: de como ele **morre**, de como diz **se está bem** enquanto vive e do **que pode fazer** nesse meio-tempo. São três perguntas distintas, e as três apareceram na cena do início.

A primeira é a do desligamento. Um contêiner não se desliga como uma máquina: o Docker manda um **sinal** ao seu processo principal e espera. Se o processo atende o sinal, termina o que estava fazendo e sai; se não, ao vencer o prazo o Docker o mata. Isso já apareceu na Lição 3 com a forma *shell*. A novidade é que não basta escrever bem o `CMD`: há programas que, sendo o processo número 1, não recebem o sinal mesmo em forma *exec*, e a lição mostra um, mede quanto isso custa e o corrige.

A segunda é a saúde. Para o Docker, um contêiner está `Up` enquanto seu processo existir. Ele não sabe se esse processo responde, se responde bem ou se ficou travado esperando algo que nunca vai chegar. O README do curso o põe como um de seus dois critérios: **um contêiner «rodando» não é um serviço saudável**. Uma verificação de saúde (*health check*) é a forma de o contêiner, por dentro, dizer ao Docker a diferença. E a imagem do `revisor` não tem `curl` nem *shell*, então a verificação precisa vir de outro lugar.

A terceira é o poder. Um contêiner que funciona bem pode, mesmo assim, ser o ponto de entrada de um ataque: se alguém encontra uma falha no programa, herda tudo o que o processo pode fazer. As lições 3 e 5 já retiraram dele o `root` e o *shell*. Aqui se retiram mais três coisas: a possibilidade de escrever no próprio sistema de arquivos, as capabilities de `root` que ele não usa e a possibilidade de ganhar novos privilégios ao executar outro programa.

Com esse destino em mente, isto é o que vai aparecer na seção 7.10, quando as três respostas se juntarem. O `revisor` roda com tudo o que a lição ensina, o kernel confirma que ele não tem nenhuma capability e que não pode ganhar privilégios, e mesmo assim ele se desliga em ordem em umas poucas décimas de segundo:

```text
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
```

## Os conceitos

### 7.1 O processo número 1 e os sinais

#### 7.1.1 O que é um sinal

Um **sinal** é um aviso curto que o kernel do Linux entrega a um processo. Não leva dados: só um número, que diz o que aconteceu ou o que se pede. Quando se pressiona `Ctrl+C` no terminal, o kernel manda ao programa o sinal `SIGINT`; quando um administrador escreve `kill <pid>`, manda `SIGTERM`. O manual do Linux os lista com seu número e sua **ação padrão**, que é o que acontece se o programa não fez nada especial para atendê-los ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)):

| Sinal | Número | O que pede | Ação padrão |
|---|---|---|---|
| `SIGINT` | 2 | interrupção pelo teclado (`Ctrl+C`) | terminar |
| `SIGKILL` | 9 | morrer, já | terminar; **não pode ser capturado, bloqueado nem ignorado** |
| `SIGTERM` | 15 | terminar, por favor | terminar |

Um programa pode **instalar um handler** para um sinal: uma função que é executada quando o sinal chega, no lugar da ação padrão. É isso que o `revisor` faz: pede ao kernel que o avise de `SIGTERM` e de `SIGINT`, e quando um chega ele deixa de aceitar requisições novas, espera até cinco segundos que as que estavam em andamento terminem e sai com código 0. É o que se vê desde a Lição 3 em seus logs: `recibí terminated, apagando` e `apagado limpio`. Para `SIGKILL` não há handler possível; o manual diz isso com todas as letras: «`SIGKILL` e `SIGSTOP` não podem ser capturados, bloqueados nem ignorados».

#### 7.1.2 Como se lê o fim de um contêiner

Quando um processo termina, deixa um **código de saída**. Se terminou sozinho, é o número que o programa escolheu: `0` para «tudo bem», qualquer outro para «algo falhou» (o `revisor` usa `1` quando falta configuração). Se um sinal o terminou, a convenção dos *shells*, que o Docker segue, é **128 mais o número do sinal**. Daí saem os dois números que mais vão aparecer:

| Código | Como se lê |
|---|---|
| `0` | terminou sozinho e bem; com o `revisor`, depois de um desligamento em ordem |
| `1` | terminou sozinho, com um erro do próprio programa |
| `137` | 128 + 9: foi morto por `SIGKILL`; ninguém lhe perguntou nada |
| `143` | 128 + 15: foi terminado por `SIGTERM` com a ação padrão, sem handler |

Repare na diferença entre `0` e `143`. Os dois são desligamentos pedidos com `SIGTERM`; no primeiro, o programa atendeu o sinal e saiu por conta própria; no segundo, o kernel o terminou porque o programa não tinha handler. Os dois são razoáveis. O que deve preocupar é o `137` em um desligamento normal: significa que o prazo acabou e o Docker teve de matar.

#### 7.1.3 Por que o número 1 é especial

Na Lição 0 viu-se que, dentro de um contêiner, o programa principal é o processo número 1. Esse número recebe um tratamento especial no Linux, que o manual dos namespaces de processos descreve assim: ao processo «*init*» de um namespace só se podem mandar os sinais **para os quais ele estabeleceu um handler**; os demais não lhe fazem nada. E há uma exceção: `SIGKILL` e `SIGSTOP` «são entregues à força quando vêm de um namespace ancestral» ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). A referência do `docker run` resume isso em uma frase: um processo que roda como PID 1 «ignora qualquer sinal cuja ação seja a padrão» ([referência do `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).

Leia com calma, porque é o centro desta seção. Um programa que **não** instalou um handler para `SIGTERM` morre com ele no terminal, porque a ação padrão é terminar. O mesmo programa, sendo o número 1 de um contêiner, **não** morre: a ação padrão deixa de se aplicar. A proteção faz sentido para o *init* de uma máquina, que nunca deveria morrer por acidente; em um contêiner, o *init* é o programa, e essa proteção vira um problema.

#### 7.1.4 Medi-lo com um programa que não sabe se desligar

O `revisor` instala seu handler, então não serve para ver o problema. Para vê-lo é preciso um programa que não o instale, e há um em todas as imagens do Debian: `sleep`, que apenas espera os segundos pedidos. O script `fig07_02.sh` não constrói nada; usa a imagem do Go que já está na máquina desde a Lição 3:

```bash
#!/usr/bin/env bash
# fig07_02.sh — El proceso número 1 y las señales, con un programa que NO sabe
# apagarse: sleep. Mide cuánto tarda docker stop, con qué código muere el
# contenedor, qué cambia con -t y con --init, y quién recoge a los zombis.
# No construye nada: usa la imagen de Go que ya bajaste para el revisor.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor
# ni tu imagen curso-docker-revisor:1.4.0, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}fig07-sleep"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
# detener [opciones de docker stop]: detiene el contenedor, mide y dice cómo murió
detener() {
  local inicio fin
  inicio=$(t); docker stop "$@" "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop${*:+ $*} tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
  docker rm -f "$NOMBRE" >/dev/null
}

echo "== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
PID1=$(pid_de "$NOMBRE")
grep -E '^SigCgt' "/proc/$PID1/status"
detener

echo
echo "== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
detener -t 2

echo
echo "== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM"
sleep 300 & HIJO=$!
kill -TERM "$HIJO"; rc=0; wait "$HIJO" || rc=$?
echo "sleep en el equipo murió con código $rc"

echo
echo "== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep"
docker run -d --init --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
detener

echo
echo "== 5. Zombis: un hijo huérfano termina y nadie lo recoge"
# El subshell lanza «sleep 1» y se va; ese sleep queda huérfano y el núcleo se
# lo entrega al proceso 1. Después, exec convierte al shell en «sleep 300».
docker run -d --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- docker top:"
docker top "$NOMBRE" -o pid,stat,args | sed -E 's/^ *[0-9]+ /<pid> /'
echo "-- ps en el equipo, hijos del proceso 1 del contenedor:"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. Lo mismo con --init: el init recoge al huérfano"
docker run -d --init --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
```

```text
$ ./fig07_02.sh
== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM
PID                 PPID                COMMAND
<pid> <ppid>             sleep 300
SigCgt:	0000000000000000
docker stop tardó 11315 ms; ExitCode=137

== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)
docker stop -t 2 tardó 2707 ms; ExitCode=137

== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM
sleep en el equipo murió con código 143

== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep
PID                 PPID                COMMAND
<pid> <ppid>             /sbin/docker-init -- sleep 300
<pid> <ppid>             sleep 300
docker stop tardó 251 ms; ExitCode=143

== 5. Zombis: un hijo huérfano termina y nadie lo recoge
-- docker top:
PID                 STAT                COMMAND
<pid>             Ss                  sleep 300
-- ps en el equipo, hijos del proceso 1 del contenedor:
STAT COMMAND
Z    [sleep] <defunct>

== 6. Lo mismo con --init: el init recoge al huérfano
-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):
STAT COMMAND
S    sleep 300
```

Há linhas novas no script. A função `detener` mede quanto o `docker stop` demora e lê o código de saída com `docker inspect`, como na Lição 3. O `sed` que vem depois do `docker top` oculta os números de processo com `<pid>` e `<ppid>`, porque eles mudam a cada execução. E o `grep` do bloco 1 lê um arquivo que não é do contêiner, e sim do kernel: `/proc/<número>/status`, o estado de um processo visto da máquina. `docker inspect --format '{{.State.Pid}}'` dá o número que esse processo tem **na máquina**, que não é 1; o 1 é o número que ele tem dentro.

Agora os blocos 1 a 3; os demais são lidos em 7.3.

1. **`sleep` é o número 1 e não atende nada.** `docker top` mostra um único processo, `sleep 300`. A linha `SigCgt` diz que sinais o processo tem **capturados**, isto é, para quais instalou um handler, como uma máscara de bits em hexadecimal: cada bit ligado é um sinal. Tudo em zero: nenhum. E o `docker stop` demorou **11,315 ms** e deixou `ExitCode=137` (em uma execução com a máquina menos carregada, 10,097 ms: o prazo são os 10,000, e o resto é o Docker e a carga da máquina). A sequência é a da Lição 3: `SIGTERM` ao número 1, que o ignora porque não tem handler; dez segundos de espera; `SIGKILL`, que chega à força.
2. **O prazo pode ser mudado.** Com `docker stop -t 2`, o mesmo `sleep` morreu em **2,707 ms**, também com `137` (2,124 na execução menos carregada). O prazo mudou; o final, não. Encurtar o prazo não resolve nada: só faz com que matem mais cedo.
3. **Fora do contêiner, o mesmo programa morre.** O script lança `sleep 300` na própria máquina, manda-lhe `SIGTERM` com `kill` e lê seu código: `143`, que é 128 + 15. Mesmo programa, mesmo sinal, nenhum handler: na máquina o `sleep` é um processo qualquer e a ação padrão se aplica; no contêiner ele era o número 1 e não.

Compare este bloco 1 com a forma *shell* da Lição 3. Lá o número 1 era `/bin/sh` e o `revisor` estava embaixo; aqui não há *shell* no meio, o `CMD` é *exec* e mesmo assim acontece o mesmo. A forma *exec* faz o Docker lançar o programa diretamente, sem um *shell* no meio, e por isso ele fica como o número 1; **não** garante que o programa saiba se comportar como tal.

> [!NOTE]
> 🔧 **Observação de engenharia 7.1**
> Muitos programas não instalam handlers porque, em uma máquina normal, não precisam: a ação padrão de `SIGTERM` já os termina. Scripts de *shell*, ferramentas de linha de comando, servidores escritos com pressa. Quando são colocados em um contêiner como número 1, cada `docker stop` lhes custa o prazo completo. Antes de decidir qualquer coisa, olhe a linha `SigCgt` do processo: se o bit de `SIGTERM` (o valor `4000` em hexadecimal) está desligado, esse programa precisa de ajuda.

### 7.2 O prazo do `docker stop`, e quem decide o sinal

#### 7.2.1 O que o `docker stop` faz, passo a passo

A documentação o descreve assim: o processo principal do contêiner «recebe `SIGTERM` e, depois de um período de graça, `SIGKILL`». Se o contêiner não tem outro sinal configurado, usa-se `SIGTERM`. O prazo «é determinado pelo daemon» e é de **10 segundos** para contêineres Linux (30 para os de Windows); com `-t` ou `--timeout` ele muda para aquela chamada, e com `-t -1` o Docker espera para sempre ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

Há três lugares onde o comportamento pode ser mudado, e convém saber qual ganha:

| Onde | O que muda | Alcance |
|---|---|---|
| `STOPSIGNAL` no Dockerfile | o sinal que o `docker stop` manda | todos os contêineres dessa imagem |
| `docker run --stop-signal` | o sinal, para esse contêiner | ganha sobre o da imagem |
| `docker run --stop-timeout` | o prazo, para esse contêiner | fica guardado no contêiner |
| `docker stop -t N` / `-s SINAL` | prazo e sinal, para essa chamada | ganha sobre tudo o que vem antes |

A referência do Dockerfile esclarece que `STOPSIGNAL` só vale para os sinais que o Docker manda (`docker stop` e o próprio daemon); um `Ctrl+C` em um terminal conectado ao contêiner continua mandando `SIGINT` direto ao processo ([referência do Dockerfile](https://docs.docker.com/reference/dockerfile/)). Se não se passa `--stop-signal` ao rodar nem `-s` ao parar, o Docker usa o `STOPSIGNAL` da imagem, e se a imagem não declara nenhum, `SIGTERM` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

E existe o `docker kill`, que não espera: manda um sinal e pronto. Sem `-s`, o sinal é `SIGKILL` ([`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/)). Serve quando algo travou e não há nada a salvar; não é a forma normal de desligar.

#### 7.2.2 `STOPSIGNAL` no `revisor`

O Dockerfile desta lição declara `STOPSIGNAL SIGTERM`. É o sinal padrão, então não muda o comportamento; o comentário do Dockerfile diz isso: escrevê-lo documenta a intenção. Quem ler a imagem, ou quem a inspecionar com `docker image inspect --format '{{.Config.StopSignal}}'`, sabe que sinal o programa espera sem abrir seu código. Há programas que esperam outro (alguns servidores web fazem um desligamento ordenado com `SIGQUIT` e um brusco com `SIGTERM`); nesses casos `STOPSIGNAL` deixa de ser documentação e se torna necessário.

#### 7.2.3 Por que o `revisor` espera cinco segundos e não dez

O código do `revisor` tem uma constante, `PlazoApagado`, de cinco segundos: é o que ele espera pelas requisições em andamento antes de desistir. Seu comentário explica o número: é menor que os dez do `docker stop` «para que o processo termine sozinho e não o matem». É a regra que convém seguir com qualquer serviço: **o prazo interno de desligamento tem de caber no prazo de quem desliga**. Se um programa precisa de vinte segundos para esvaziar uma fila, deve-se aumentar o prazo do contêiner com `--stop-timeout 30`; não se deve esperar que o Docker adivinhe.

### 7.3 `--init`: um *init* minúsculo para o número 1

#### 7.3.1 O que faz

Se o programa não sabe ser o número 1, a saída limpa é não pô-lo como número 1. `docker run --init` inicia primeiro um programa pequeno, o `docker-init`, que se torna o número 1 e inicia o programa como seu filho. A referência do `docker run` diz que um processo *init* garante que «as responsabilidades usuais de um sistema *init*, como recolher processos zumbis, sejam cumpridas dentro do contêiner», e que esse `docker-init`, incluído na instalação normal, é feito com o [tini](https://github.com/krallin/tini). O próprio projeto do tini se descreve como um *init* mínimo que inicia um único filho e espera que ele termine «recolhendo zumbis e reenviando sinais nesse meio-tempo», e avisa que desde o Docker 1.13 ele vem incluído no Docker, sem instalar nada na imagem.

São dois trabalhos, e os blocos 4 a 6 do `fig07_02.sh` mostram os dois.

#### 7.3.2 O primeiro trabalho: reenviar sinais

O bloco 4 roda o mesmo `sleep 300` com `--init`. `docker top` agora mostra dois processos: `/sbin/docker-init -- sleep 300` e, embaixo, `sleep 300`. O número 1 é o `docker-init`, que tem handlers para os sinais; quando o `docker stop` lhe manda `SIGTERM`, ele o reenvia ao filho. Para o filho, `SIGTERM` é um sinal qualquer, porque ele **não** é o número 1, então a ação padrão se aplica e ele morre. O `docker-init` vê o filho morrer e sai com o mesmo código. Resultado: **251 ms** em vez de 11,315 (88 ms na execução menos carregada), e `ExitCode=143`, o mesmo 128 + 15 que se obteve no terminal no bloco 3. Sem mudar uma linha do programa.

#### 7.3.3 O segundo trabalho: recolher zumbis

Quando um processo termina, não desaparece por completo: fica uma linha na tabela de processos com seu código de saída, esperando que o pai a leia. Enquanto ninguém a lê, esse processo é um **zumbi**: não roda, não usa memória, mas ocupa um número de processo. Se o pai morre antes do filho, o kernel atribui ao órfão um novo pai: o *init* de seu namespace. Assim, dentro de um contêiner, todos os órfãos acabam como filhos do número 1, e o número 1 tem de recolhê-los.

O bloco 5 provoca isso. O contêiner roda `sh -c '(sleep 1 &); exec sleep 300'`: um *subshell* lança `sleep 1` em segundo plano e vai embora, então esse `sleep 1` fica órfão e passa a ser filho do número 1; depois, `exec` substitui o *shell* por `sleep 300`, que se torna o número 1. Um segundo depois o órfão termina, e seu novo pai, `sleep 300`, não faz ideia de que deve recolhê-lo. Observe as duas visões do bloco:

- **`docker top` não o mostra.** Só aparece `sleep 300`. `docker top` pergunta pelos processos que pertencem ao cgroup do contêiner, e um processo que já terminou sai desse grupo mesmo que sua linha continue na tabela. É uma medição que vale a pena lembrar: quem procura zumbis, `docker top` não é a ferramenta.
- **`ps` na máquina o mostra.** Com `--ppid` pedem-se os filhos do número 1 do contêiner, e aparece `Z    [sleep] <defunct>`: estado `Z`, de zumbi, e a palavra `defunct`, defunto.

O bloco 6 repete o mesmo com `--init`. Agora o órfão é atribuído ao `docker-init`, que sabe recolher filhos. Os filhos do número 1 são apenas o *shell* convertido em `sleep 300`; do zumbi, nada.

Um zumbi não faz mal; milhares, sim. Cada um ocupa um número de processo, e na Lição 2 foi colocado no contêiner `--pids-limit 50`. Um programa que lança processos auxiliares e não os recolhe acaba, com o tempo, sem poder lançar mais nenhum.

#### 7.3.4 E o `revisor`? Ele precisa menos do que parece

Sejamos precisos, porque aqui é fácil exagerar. O `revisor` instala seu handler para `SIGTERM` (ele se desliga em menos de um segundo sem `--init`, como se verá na seção 7.4) e não lança processos filhos, então não deixa zumbis. Hoje **não precisa** de `--init`. O curso o usa mesmo assim, por duas razões. A primeira: custa quase nada (um processo minúsculo a mais, e quatro letras). A segunda: no dia em que alguém mudar o programa, ou o envolver em um script de inicialização, ou lhe acrescentar uma ferramenta que lance processos, a imagem continua se desligando bem sem que ninguém tenha de se lembrar desta lição. É um seguro barato, e por isso entra nas opções de reforço que a Lição 9 copia para o Compose.

### 7.4 `HEALTHCHECK` sem `curl`

#### 7.4.1 A instrução

`HEALTHCHECK` diz ao Docker como perguntar a um contêiner se ele está bem. O Docker executa esse comando **dentro** do contêiner de tempos em tempos e olha seu código de saída. A referência do Dockerfile define três valores: `0` é sucesso («o contêiner está saudável e pronto para uso»), `1` é «não saudável» e `2` está reservado: não o use. As opções, com seus valores padrão segundo a mesma referência ([referência do Dockerfile](https://docs.docker.com/reference/dockerfile/)):

| Opção | O que é | Padrão | No `revisor` |
|---|---|---|---|
| `--interval` | de quanto em quanto tempo se verifica | `30s` | `10s` |
| `--timeout` | quanto uma verificação pode demorar antes de contar como falha | `30s` | `3s` |
| `--start-period` | tempo de inicialização: as falhas aqui não contam | `0s` | `5s` |
| `--start-interval` | de quanto em quanto tempo se verifica **durante** a inicialização | `5s` | (o padrão) |
| `--retries` | quantas falhas seguidas são necessárias para declará-lo não saudável | `3` | `3` |

Um Dockerfile só pode ter **um** `HEALTHCHECK`; se houver vários, vale o último. `HEALTHCHECK NONE` desliga o que for herdado da imagem base. O que o comando escreve em sua saída é guardado junto ao resultado e se lê com `docker inspect`; só se guardam os primeiros 4,096 bytes.

Com essas opções, o contêiner passa por três estados de saúde: `starting` enquanto não há uma resposta que conte, `healthy` assim que uma verificação sai com `0`, e `unhealthy` quando se juntam tantas falhas seguidas quanto `--retries` indicar. Qualquer sucesso zera a sequência de falhas.

#### 7.4.2 O Dockerfile desta lição

É o da Lição 6 com duas instruções novas no final:

```dockerfile
# syntax=docker/dockerfile:1
# fig07_01.Dockerfile — Lección 7: la imagen dice cómo está (HEALTHCHECK) y muere bien.
# Parte de la de la Lección 6; lo nuevo está al final.

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
# La salud la revisa el propio binario: la imagen no tiene shell ni curl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/revisor", "healthcheck"]
# Señal de apagado explícita (es la de omisión; escribirla documenta la intención).
STOPSIGNAL SIGTERM
ENTRYPOINT ["/revisor"]
```

O que mudou:

1. **`HEALTHCHECK ... CMD ["/revisor", "healthcheck"]`.** A verificação é feita pelo próprio binário: o subcomando `healthcheck` do `revisor` pergunta ao seu próprio processo por `GET /salud` em `127.0.0.1`, com dois segundos de limite; se responde `200`, imprime `sano` e sai com `0`; se não, imprime `no sano: …` e sai com `1`. Vai em forma *exec*, com colchetes, como o `ENTRYPOINT`: pela mesma razão da Lição 3, e por mais uma que será vista daqui a pouco.
2. **Os tempos.** `--interval=10s` porque o `revisor` não precisa ser vigiado a cada cinco segundos, e trinta (o padrão) é demais para perceber um problema. `--timeout=3s` deixa folga sobre os dois segundos que o próprio subcomando se dá. `--start-period=5s` lhe dá tempo de iniciar, e durante esse tempo o Docker pergunta a cada cinco segundos (`--start-interval`), de modo que a primeira resposta chega rápido. `--retries=3` pede três falhas seguidas antes de declará-lo não saudável: um tropeço não basta.
3. **`STOPSIGNAL SIGTERM`**, visto em 7.2.2.

#### 7.4.3 Por que não `curl`

A forma mais comum de escrever uma verificação de saúde, a que se encontra em quase todos os tutoriais, é `HEALTHCHECK CMD curl -f http://localhost:8080/salud || exit 1`. Ela tem dois problemas na imagem do `revisor`, e o script desta seção os provoca. O primeiro é evidente: a imagem não tem `curl`. O segundo é mais sutil: essa linha está em forma *shell*, e a forma *shell* precisa de `/bin/sh`, que também não existe. O mesmo vale para `docker run --health-cmd`, que é a forma de definir ou mudar a verificação ao rodar: o que se escreve ali o Docker executa com o *shell*.

A saída fácil seria acrescentar o `curl` à imagem. Não convém: são megabytes de uma ferramenta de rede, com sua própria história de vulnerabilidades, enfiados na imagem que na Lição 5 ficou sem nada que não fosse necessário, só para fazer uma pergunta que o programa já sabe fazer. A saída boa é a que o `revisor` traz: um subcomando do mesmo binário. Zero bytes extras, e a verificação pergunta exatamente o que o programa sabe de si mesmo. O serviço de teste faz o mesmo com seu `servicio-prueba healthcheck`, e por isso desde a Lição 2 ele tem verificação de saúde sem ter `curl`.

#### 7.4.4 Vê-lo falhar e vê-lo funcionar

O script `fig07_03.sh` constrói a imagem, tenta primeiro vigiá-la com `curl` e depois a roda com sua própria verificação:

```bash
#!/usr/bin/env bash
# fig07_03.sh — HEALTHCHECK sin curl. Construye el revisor con fig07_01.Dockerfile,
# provoca primero el error de vigilarlo con curl (la imagen no tiene ni shell ni
# curl), lo corre con su propia revisión de salud y lo detiene midiendo el tiempo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

t() { date +%s%3N; }
# esperar_salud ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
# estado: lo que dice docker ps, sin el nombre
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
# bitacora_salud: las revisiones guardadas, una por renglón: código y salida
bitacora_salud() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{printf "%q" .Output}}{{println}}{{end}}' "$NOMBRE" | sed '/^$/d'
}
SERVICIOS='propio http://127.0.0.1:8080/salud'

echo "== 1. Construir y leer la revisión de salud que trae la imagen"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null
docker image inspect --format '{{json .Config.Healthcheck}}' "$IMAGEN"
docker image inspect --format 'StopSignal={{.Config.StopSignal}}' "$IMAGEN"

echo
echo "== 2. El error: vigilarlo con curl, como en los tutoriales"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  --health-cmd 'curl -fs http://127.0.0.1:8080/salud || exit 1' \
  --health-interval 2s --health-retries 2 --health-start-period 1ms "$IMAGEN" >/dev/null
inicio=$(t); esperar_salud unhealthy; fin=$(t)
estado
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud | tail -1
echo "-- y sin embargo, el servicio contesta:"
docker exec "$NOMBRE" /revisor healthcheck
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Con la revisión de la imagen: el propio binario se pregunta"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
estado
inicio=$(t); esperar_salud healthy; fin=$(t)
estado
echo "pasó a healthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud
docker inspect --format 'Status={{.State.Status}} Health={{.State.Health.Status}} FailingStreak={{.State.Health.FailingStreak}}' "$NOMBRE"

echo
echo "== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_03.sh
== 1. Construir y leer la revisión de salud que trae la imagen
{"Test":["CMD","/revisor","healthcheck"],"Interval":10000000000,"Timeout":3000000000,"StartPeriod":5000000000,"Retries":3}
StopSignal=SIGTERM

== 2. El error: vigilarlo con curl, como en los tutoriales
Up 4 seconds (unhealthy)
pasó a unhealthy en 5 s
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
-- y sin embargo, el servicio contesta:
sano

== 3. Con la revisión de la imagen: el propio binario se pregunta
Up 1 second (health: starting)
Up 6 seconds (healthy)
pasó a healthy en 5 s
0 "sano\n"
Status=running Health=healthy FailingStreak=0

== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM
docker stop tardó 657 ms
ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Novidades do script: `esperar_salud` pergunta a cada meio segundo por `.State.Health.Status` até que diga o que se espera; `estado` mostra a coluna `STATUS` do `docker ps` sem o nome; e `bitacora_salud` percorre `.State.Health.Log`, a lista das últimas verificações que o Docker guarda, com o código e a saída de cada uma. O `printf "%q"` escreve a saída entre aspas e com as quebras de linha como `\n`, para que se veja exatamente o que o comando imprimiu.

Bloco por bloco:

1. **A imagem traz sua verificação.** `docker image inspect` a mostra em JSON: o comando em forma *exec* (`"CMD"` seguido da lista) e os tempos em nanossegundos (`10000000000` são dez segundos). O sinal de desligamento ficou anotado: `StopSignal=SIGTERM`.
2. **Com `curl`, `unhealthy`.** O script pediu uma verificação a cada dois segundos e duas falhas para desistir, e aos 5 segundos o contêiner já estava `(unhealthy)`: duas verificações falhas, aos 2 e aos 4 segundos, mais o que cada uma demora. Repare em `--health-start-period 1ms`. Uma opção `--health-*` em `0s` **não** desliga o tempo de inicialização: para o Docker, um zero significa «use o valor da imagem», e o contêiner manteria os 5 segundos de inicialização do Dockerfile. `1ms` é a forma de pedir uma inicialização quase nula; o Exercício 2 mostra a diferença medida. O histórico de saúde diz por quê, e o código não é `1`, e sim **`-1`**: o Docker nem sequer conseguiu executar a verificação. A mensagem é a da Lição 2, quando se tentou `docker exec ... sh`, com outra redação: `exec: "/bin/sh": stat /bin/sh: no such file or directory`. E o mais importante vem depois: `docker exec ... /revisor healthcheck` responde `sano`. **O serviço estava bem; a verificação estava quebrada.** É o erro mais traiçoeiro desta lição, porque o estado `unhealthy` acusa o programa de algo que é culpa de quem escreveu a verificação.
3. **Com a verificação da imagem, `healthy` aos 5 segundos.** Primeiro `(health: starting)`, depois `(healthy)`. Os cinco segundos são o `--start-interval`: a primeira pergunta chegou ao terminar o primeiro intervalo da inicialização, e deu certo. A referência do Dockerfile diz que a primeira verificação chega depois de um `--interval`, que aqui seriam dez segundos; medido com o Docker 29.2.1, durante a inicialização o Docker usa o `--start-interval`, e a primeira chegou aos cinco. Quando a documentação e a medição não coincidem, vale a medição (isso reaparece em 7.6.3). O histórico tem uma entrada: código `0` e a saída `sano\n`. A última linha lê o mesmo por partes: o processo está `running`, sua saúde é `healthy` e a sequência de falhas (`FailingStreak`) é `0`.
4. **O desligamento.** Sem `--init`, o `revisor` é o número 1, mas desta vez **tem** handler. O `docker stop` demorou **657 ms** nesta execução, com a máquina carregada (562 ms na Lição 3, segundo sua saída guardada), e o código é `0`, não `143`: o programa não morreu pelo sinal, ele o atendeu e saiu por conta própria. Os logs contam isso com suas próprias palavras (o `grep -v` deixa de fora os `GET /salud` de cada verificação).

#### 7.4.5 Na pasta do projeto

O projeto vive em `~/curso-docker/revisor` desde a Lição 3. A partir da raiz do repositório do curso, coloque ali o Dockerfile desta lição e construa a imagem que será conservada:

```bash
cp programas/07-salud-y-ciclo-de-vida/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.4.0 -t curso-docker-revisor:1.4.0 .
docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0
```

O último comando tem de imprimir o mesmo JSON do bloco 1. O `.dockerignore` e a pasta `secretos/` não mudam. O `Dockerfile.malo`, o da Lição 6, já não é necessário; pode ser removido da pasta ou mantido, porque o `.dockerignore` impede que ele viaje. A imagem é rodada reforçada na seção 7.10, quando já se souber o que cada opção faz.

### 7.5 Rodando não é saudável

#### 7.5.1 O que o Docker faz com a saúde, e o que não faz

Uma verificação de saúde muda **um rótulo**: o que aparece entre parênteses no `docker ps`. Nada mais. O Docker não reinicia um contêiner `unhealthy`, não lhe corta o tráfego e não avisa ninguém. A informação está ali para que alguém a use: a pessoa que olha o `docker ps`; o Compose, que com `depends_on` e `condition: service_healthy` espera que um serviço esteja saudável antes de iniciar o seguinte (Lição 9); um orquestrador, que pode substituir o contêiner doente. Esta seção demonstra isso com o serviço de teste, que tem um truque que o `revisor` não tem: muda de modo sem reiniciar.

#### 7.5.2 O serviço de teste adoece

O script `fig07_04.sh` constrói uma cópia do serviço de teste, inicia-a com `--restart always` (a política mais insistente, que será vista em 7.6) e a leva por seus três modos:

```bash
#!/usr/bin/env bash
# fig07_04.sh — Corriendo no es sano. El servicio de prueba, con su propio
# HEALTHCHECK (cada 5 s, 2 reintentos), pasa a modo caído y a modo lento sin
# reiniciarse: el proceso sigue vivo y Docker lo marca unhealthy. Y una política
# de reinicio NO reinicia a un contenedor por estar unhealthy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-9000}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
resumen() {
  docker inspect --format '{{.State.Status}} / {{.State.Health.Status}} / racha={{.State.Health.FailingStreak}} / reinicios={{.RestartCount}}' "$NOMBRE"
}
ultima_revision() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{end}}' "$NOMBRE" | sed '/^$/d' | tail -1
}

echo "== 1. Arranca sano, con --restart always"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:9000" --restart always "$IMAGEN" >/dev/null
esperar_salud healthy
estado

echo
echo "== 2. Modo caído: el proceso sigue vivo, pero responde 503"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/caido"
inicio=$(t); esperar_salud unhealthy; fin=$(t)
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
estado
resumen
ultima_revision

echo
echo "== 3. Diez segundos después, sigue unhealthy y nadie lo reinició"
sleep 10
resumen

echo
echo "== 4. De vuelta a sano, sin reiniciar nada"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/sano"
inicio=$(t); esperar_salud healthy; fin=$(t)
echo "volvió a healthy en $(( (fin - inicio + 500) / 1000 )) s"
resumen

echo
echo "== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/lento"
esperar_salud unhealthy
resumen
ultima_revision
echo "-- y sin embargo, contesta 200:"
curl -s -o /dev/null -w '%{http_code} en %{time_total}s\n' "http://127.0.0.1:$PUERTO/"
```

```text
$ ./fig07_04.sh
== 1. Arranca sano, con --restart always
Up 5 seconds (healthy)

== 2. Modo caído: el proceso sigue vivo, pero responde 503
modo: caido
pasó a unhealthy en 10 s
Up 15 seconds (unhealthy)
running / unhealthy / racha=2 / reinicios=0
1 no sano: GET / respondió 503

== 3. Diez segundos después, sigue unhealthy y nadie lo reinició
running / unhealthy / racha=4 / reinicios=0

== 4. De vuelta a sano, sin reiniciar nada
modo: sano
volvió a healthy en 5 s
running / healthy / racha=0 / reinicios=0

== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2
modo: lento
running / unhealthy / racha=2 / reinicios=0
1 no sano: Get "http://127.0.0.1:9000/": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
-- y sin embargo, contesta 200:
200 en 3.012887s
```

O serviço de teste traz seu próprio `HEALTHCHECK` desde a Lição 2: a cada 5 segundos, com 2 tentativas, e sua verificação exige um `200` em menos de 2 segundos. Com isso:

1. **Inicia saudável**, aos 5 segundos.
2. **No modo fora do ar, `unhealthy` aos 10 segundos.** Duas verificações falhas, cinco segundos entre uma e outra: são os `--retries=2` vezes o `--interval=5s` do Dockerfile. Agora olhe a linha de `resumen`: `running / unhealthy / racha=2 / reinicios=0`. O processo **roda**; a saúde diz que **não presta**; a sequência de falhas é 2; e ninguém o reiniciou. A última verificação explica a causa com o texto exato de seu código: `1 no sano: GET / respondió 503`.
3. **Dez segundos depois, igual.** A sequência subiu para 4 e os reinícios continuam em 0. Nem a saúde nem o `--restart always` fizeram nada. Isto é o que acontecia na cena do início: um contêiner `Up`, `unhealthy` e abandonado.
4. **De volta a saudável em 5 segundos**, sem reiniciar nada: uma verificação boa zera a sequência e põe a saúde em `healthy`. A saúde não é um estado que se conquista uma vez: ela é recalculada a cada verificação.
5. **No modo lento, também `unhealthy`.** E aqui está a lição mais fina. O serviço responde `200`, o código de «tudo bem», mas demora 3 segundos, e sua verificação espera apenas 2: `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, que é a forma de o Go dizer «o tempo acabou esperando a resposta». O `curl` do final confirma: `200 en 3.01s`. Para a verificação, um serviço que responde tarde é um serviço que não responde. Essa é uma decisão de projeto: quem escreve a verificação decide o que significa «saudável», e aqui significa «responde bem **e** a tempo».

#### 7.5.3 O que uma boa verificação pergunta

Uma verificação de saúde responde a uma única pergunta: **este processo consegue atender?** No `revisor`, o `/salud` responde que o servidor HTTP está vivo e atendendo, e nada mais. Não verifica os serviços que o `revisor` vigia: se verificasse, um serviço de teste fora do ar poria o `revisor` em `unhealthy`, quando ele está perfeitamente bem fazendo seu trabalho, que é reportar a queda. Também não verifica se ele consegue escrever seu relatório, e em 7.7 será visto o que isso significa. Uma verificação que depende de outros serviços transforma a falha de um na falha de todos; por isso convém que pergunte pelo próprio processo e seja barata: ela será executada a cada dez segundos durante toda a vida do contêiner.

### 7.6 Políticas de reinício

#### 7.6.1 As quatro políticas

Uma **política de reinício** diz ao daemon o que fazer quando o processo de um contêiner termina. Escolhe-se com `docker run --restart` e há quatro, que a documentação descreve assim ([Docker, «Start containers automatically»](https://docs.docker.com/engine/containers/start-containers-automatically/)):

| Política | O que faz |
|---|---|
| `no` | nunca reinicia; é a padrão |
| `on-failure[:máximo]` | reinicia se o processo sai com um código diferente de 0; com `:máximo`, só essa quantidade de vezes. Não reinicia o contêiner quando o daemon é reiniciado |
| `always` | reinicia sempre que o processo para. Se foi parado manualmente, só volta a iniciar quando o daemon do Docker é reiniciado ou quando é iniciado de novo |
| `unless-stopped` | como `always`, exceto que, se o contêiner estava parado, não volta a iniciar nem quando o daemon é reiniciado |

Dois detalhes a mais da documentação importam. Um: se um contêiner é parado manualmente, sua política é ignorada até que o daemon seja reiniciado ou que ele seja iniciado de novo; assim não há como brigar com o Docker para desligar algo. E dois: entre um reinício e o seguinte, o Docker espera cada vez mais: o dobro da vez anterior, começando em 100 milissegundos e com um teto de um minuto; se o contêiner consegue ficar no ar por pelo menos 10 segundos, a espera volta a 100 ms ([referência do `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). Isso evita que um contêiner quebrado reinicie mil vezes por segundo.

#### 7.6.2 Medir o que cada uma faz

O script `fig07_05.sh` constrói o `revisor` e o faz morrer de várias formas:

```bash
#!/usr/bin/env bash
# fig07_05.sh — Políticas de reinicio. Un revisor sin configuración muere con
# código 1 en cuanto arranca: con on-failure:3, Docker lo reintenta tres veces,
# cada vez esperando más. Y con always: qué hace Docker cuando el proceso muere
# solo, y qué hace cuando lo detienes tú. Usa sudo una vez, para matar al
# proceso desde fuera como lo haría el núcleo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}reinicios-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
resumen() {
  docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}}' "$NOMBRE"
}

echo "== 1. on-failure:3 con un revisor sin configuración"
desde=$(date +%s)
docker run -d --name "$NOMBRE" --restart on-failure:3 "$IMAGEN" >/dev/null
sleep 8
resumen
echo "-- lo que escribió en sus cuatro vidas:"
docker logs "$NOMBRE" 2>&1 | sort | uniq -c
echo "-- cuánto esperó Docker entre un arranque y el siguiente:"
docker events --since "$desde" --until "$(date +%s)" \
  --filter "container=$NOMBRE" --filter event=start --format '{{.TimeNano}}' |
  awk 'NR > 1 { printf "arranque %d: %d ms después del anterior\n", NR, ($1 - previo) / 1000000 } { previo = $1 }'
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. Sin política (no, la de omisión): muere y se queda muerto"
docker run -d --name "$NOMBRE" "$IMAGEN" >/dev/null
sleep 3
resumen
docker rm -f "$NOMBRE" >/dev/null

SERVICIOS='propio http://127.0.0.1:8080/salud'
echo
echo "== 3. --restart always con el revisor bien configurado"
docker run -d --name "$NOMBRE" --restart always -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
sleep 2
echo "-- el núcleo mata al proceso (como haría el asesino de memoria):"
PID1=$(pid_de "$NOMBRE")
sudo kill -KILL "$PID1"
sleep 3
resumen
echo "-- lo detienes tú, con docker stop:"
docker stop "$NOMBRE" >/dev/null
sleep 3
resumen
echo "-- lo vuelves a arrancar tú, y lo matas con docker kill:"
docker start "$NOMBRE" >/dev/null
sleep 2
docker kill "$NOMBRE" >/dev/null
sleep 3
resumen
```

```text
$ ./fig07_05.sh
== 1. on-failure:3 con un revisor sin configuración
Status=exited ExitCode=1 RestartCount=3
-- lo que escribió en sus cuatro vidas:
      4 revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
-- cuánto esperó Docker entre un arranque y el siguiente:
arranque 2: 181 ms después del anterior
arranque 3: 294 ms después del anterior
arranque 4: 490 ms después del anterior

== 2. Sin política (no, la de omisión): muere y se queda muerto
Status=exited ExitCode=1 RestartCount=0

== 3. --restart always con el revisor bien configurado
-- el núcleo mata al proceso (como haría el asesino de memoria):
Status=running ExitCode=0 RestartCount=1
-- lo detienes tú, con docker stop:
Status=exited ExitCode=0 RestartCount=1
-- lo vuelves a arrancar tú, y lo matas con docker kill:
Status=exited ExitCode=137 RestartCount=0
```

Novidades do script: `docker events` lista o que o daemon fez a um contêiner em um intervalo de tempo (aqui, só as inicializações, `event=start`), e `{{.TimeNano}}` dá a hora exata de cada uma em nanossegundos. O `awk` subtrai cada inicialização da anterior e passa o resultado a milissegundos. E `sudo kill -KILL` manda `SIGKILL` ao processo do contêiner **de fora do Docker**, como faria o kernel quando um processo estoura o limite de memória; é preciso `sudo` porque o processo é do usuário `65532`, não de quem executa o script.

1. **`on-failure:3` com um `revisor` sem configuração.** Morre com `1` assim que inicia. O Docker o iniciou outras três vezes e desistiu: `Status=exited ExitCode=1 RestartCount=3`. Os logs são a prova: a mesma mensagem quatro vezes, uma por vida. E as esperas são as da documentação, mais o que cada inicialização demora: **181, 294 e 490 ms**, que são os 100, 200 e 400 da espera crescente, mais uns 80 a 90 ms de inicialização. Em uma execução com a máquina carregada por outros trabalhos saíram 530, 1,483 e 2,399 ms: a espera é definida pelo Docker, mas o que cada inicialização demora é definido pela máquina. O `revisor` não tinha conserto (falta-lhe uma variável), e por isso um teto é boa ideia: três tentativas bastam para saber que não é um tropeço.
2. **Sem política, fica morto.** `RestartCount=0`. É o que se quer para algo que roda uma vez e termina.
3. **`always` com o `revisor` bem configurado.** Três formas de morrer, três resultados:
   - **O kernel o mata.** O Docker o iniciou de novo: `Status=running RestartCount=1`. Para isso existe a política. (`ExitCode=0` é do contêiner que está rodando agora; ele ainda não terminou, então não tem código próprio.)
   - **Parado com `docker stop`.** Fica parado, com `ExitCode=0` porque se desligou em ordem. A política respeita a decisão.
   - **Morto com `docker kill`.** Também fica parado, agora com `137`. O Docker conta o `docker kill` como uma parada manual, igual ao `docker stop`, ainda que o processo morra com `SIGKILL`. E repare em `RestartCount=0`: a contagem voltou a zero quando ele foi iniciado com `docker start`.

#### 7.6.3 Uma frase da documentação que convém ler com cuidado

A página das políticas de reinício diz que uma política «só tem efeito depois que um contêiner inicia com sucesso», e que isso significa estar no ar «por pelo menos 10 segundos». O bloco 1 a contradiz à primeira vista: o `revisor` sem configuração não durou nem um segundo e o Docker o reiniciou três vezes. O que a medição mostra é o que diz a referência do `docker run`: os 10 segundos decidem quando a espera volta a 100 ms, não se há nova tentativa. Quando uma documentação e a medição não coincidem, vale a medição, e anota-se a versão com que se mediu: Docker 29.2.1.

#### 7.6.4 Qual escolher para o `revisor`

`unless-stopped`. O `revisor` é um serviço que deve estar sempre no ar, então precisa ser reiniciado se o kernel o matar ou se a máquina for reiniciada; isso descarta `no` e `on-failure`, que não o põe de volta depois de um reinício do daemon. Entre `always` e `unless-stopped`, a diferença aparece só quando o daemon é reiniciado, por exemplo ao reiniciar a máquina: com `always`, um contêiner que tinha sido parado de propósito volta à vida; com `unless-stopped`, respeita-se que ele foi parado. Isso não foi medido aqui, porque reiniciar o daemon derruba todos os contêineres da máquina; está na tabela da documentação. E lembre-se do que se viu em 7.5: nenhuma das quatro reinicia um contêiner por estar `unhealthy`. Uma política de reinício trata da morte do processo, não de sua saúde.

### 7.7 Sistema de arquivos somente leitura

#### 7.7.1 Por quê

A imagem é somente leitura desde sempre; o que se escreve ao rodar vai para uma camada nova, própria do contêiner, vista na Lição 4. `--read-only` fecha essa camada: o sistema de arquivos raiz do contêiner é montado «como somente leitura» ([referência do `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). O programa continua podendo ler tudo o que a imagem traz, mas não pode criar, mudar nem apagar nenhum arquivo.

O ganho é de segurança e de ordem. De segurança, porque quem conseguir controlar o processo não pode deixar um programa próprio no disco, nem mudar um arquivo de configuração, nem substituir o binário. De ordem, porque obriga a saber exatamente **onde o programa escreve**: cada caminho gravável passa a ser uma decisão, e não um acidente.

#### 7.7.2 Provocá-lo e corrigi-lo

O script `fig07_06.sh` usa a opção `REVISOR_REPORTE`, que diz ao `revisor` onde guardar o último relatório. O `revisor` o escreve com um arquivo temporário e uma troca de nome na mesma pasta, para que ninguém leia um relatório pela metade. Os blocos 1 e 2 são esta seção; o 3, a 7.10:

```bash
#!/usr/bin/env bash
# fig07_06.sh — Solo lectura y el revisor endurecido completo. Primero el error:
# con --read-only, el revisor no puede guardar su reporte. Después el arreglo,
# un tmpfs solo donde hace falta escribir. Y al final, todas las opciones de la
# lección juntas: lo que Docker anotó, lo que el núcleo aplica y cómo se apaga.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
SERVICIOS='propio http://127.0.0.1:8080/salud'
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. --read-only, y el revisor guardando su reporte en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El arreglo: un tmpfs pequeño solo en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=1m \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '[%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range $ruta, $opciones := .HostConfig.Tmpfs}}{{$ruta}} {{$opciones}}{{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Todo junto: el revisor endurecido"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
echo "-- lo que Docker anotó:"
docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecurityOpt={{.HostConfig.SecurityOpt}} Init={{.HostConfig.Init}} Restart={{.HostConfig.RestartPolicy.Name}}' "$NOMBRE"
echo "-- los procesos:"
docker top "$NOMBRE" -o pid,ppid,user,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
echo "-- lo que el núcleo aplica al revisor (el hijo de docker-init):"
PID1=$(pid_de "$NOMBRE")
HIJO=$(pgrep -P "$PID1" | head -1)
grep -E '^(CapEff|CapBnd|NoNewPrivs)' "/proc/$HIJO/status"
echo "-- docker stop:"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_06.sh
== 1. --read-only, y el revisor guardando su reporte en /tmp
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
-- /salud no escribe nada, así que sigue contestando:
{"estado":"vivo","version":"1.4.0"}
 [200]

== 2. El arreglo: un tmpfs pequeño solo en /tmp
[200]
/tmp rw,noexec,nosuid,size=1m

== 3. Todo junto: el revisor endurecido
Up 5 seconds (healthy)
-- lo que Docker anotó:
ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped
-- los procesos:
PID                 PPID                USER                COMMAND
<pid> <ppid>             65532               /sbin/docker-init -- /revisor
<pid> <ppid>             65532               /revisor
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

1. **Com `--read-only`, `500`.** O `revisor` tentou criar seu arquivo temporário em `/tmp` e o kernel respondeu `read-only file system`. O `revisor` não esconde o erro: responde `500` e a causa exata. O número do arquivo temporário muda a cada execução, e o script o oculta com `<n>`. E olhe a linha seguinte: **`/salud` continua respondendo `200`**. A verificação de saúde diria `healthy` enquanto cada consulta a `/api/estados` falha. É o que 7.5.3 antecipava: a saúde diz se o processo atende, não se cada função funciona. Por isso, ao reforçar um contêiner, não basta ver que ele inicia e está saudável: é preciso exercitar o que ele faz.
2. **Com `--tmpfs /tmp`, `200`.** Um **`tmpfs`** é uma pasta que vive na memória da máquina: segundo a documentação, diferentemente de volumes e *bind mounts*, «é temporário e só persiste na memória do host», e quando o contêiner para, o que foi escrito ali desaparece ([Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/)). É justo o que um arquivo temporário precisa. O sistema de arquivos raiz continua somente leitura; só `/tmp` aceita escrita, e com três opções: `noexec` impede executar programas dali (quem conseguir escrever um arquivo não pode rodá-lo), `nosuid` faz com que o bit *setuid* não tenha efeito ali (será visto em 7.9) e `size=1m` lhe impõe um teto de um megabyte. Sem `size`, o kernel impõe como teto metade da memória da máquina, e sua permissão é `1777`, gravável por qualquer um (a documentação dá esses valores para `--mount type=tmpfs`; com `--tmpfs` são os mesmos, porque é o kernel que os define). Além disso, a mesma página avisa que o que se escreve ali conta contra o limite de memória do contêiner: com o `--memory 64m` da Lição 2, um `tmpfs` sem teto poderia levar o `revisor` ao seu limite. A última linha mostra como ficou anotado.

Este conserto é para esta lição. Na Lição 8 o relatório será guardado em um volume, porque precisa sobreviver ao contêiner, e o que vive em um `tmpfs` morre com ele.

### 7.8 Capabilities fora

#### 7.8.1 O `root` partido em pedaços

Na Lição 0 viu-se que o Docker não dá ao `root` todo o seu poder: deixa-lhe catorze **capabilities**. O manual do Linux explica o conceito: o Linux «divide os privilégios tradicionalmente associados ao superusuário em unidades distintas», chamadas capabilities, que podem ser ligadas e desligadas separadamente ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Algumas das que o Docker deixa por padrão, com sua definição do manual:

| Capability | O que permite |
|---|---|
| `CAP_CHOWN` | mudar à vontade o usuário e o grupo donos de um arquivo |
| `CAP_DAC_OVERRIDE` | contornar as verificações de permissão de leitura, escrita e execução de arquivos |
| `CAP_KILL` | contornar as verificações de permissão para enviar sinais |
| `CAP_SETUID` | mudar à vontade o usuário de um processo |
| `CAP_NET_BIND_SERVICE` | escutar em portas menores que 1024 |

O `revisor` roda como `65532`, que não é `root`, então em princípio não tem nenhuma. Para que retirá-las? Porque a lista com que um contêiner roda não é só a do seu processo: é também o **teto** do que qualquer processo desse contêiner poderia chegar a ter (o *bounding set* do manual). Se alguém encontra uma forma de se tornar `root` dentro do contêiner, herda esse teto. Com `--cap-drop ALL`, o teto é zero: nem sequer um `root` de dentro tem alguma.

#### 7.8.2 Vê-lo com um `root` de verdade

Para ver o que muda é preciso um contêiner que rode como `root` e tenha ferramentas, e a imagem do Go tem as duas coisas. O script `fig07_07.sh` não constrói nada e cada contêiner se apaga sozinho:

```bash
#!/usr/bin/env bash
# fig07_07.sh — Capacidades y no-new-privileges, vistos en un contenedor que SÍ
# tiene shell y herramientas: la imagen de Go que ya bajaste. Qué puede hacer
# root con sus 14 capacidades, qué deja de poder sin ellas, y cómo un programa
# setuid convierte a un usuario normal en root… salvo con no-new-privileges.
# No construye nada y cada contenedor se borra solo (--rm).
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombre de apoyo con «fig07»: el guion nunca toca tus contenedores del curso.
NOMBRE="${PREFIJO}fig07-caps"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# correr [opciones de docker run] -- COMANDO: corre COMANDO con sh en un contenedor desechable
correr() {
  local opciones=()
  while [ "$1" != "--" ]; do opciones+=("$1"); shift; done
  shift
  docker run --rm --name "$NOMBRE" "${opciones[@]}" "$GO" sh -c "$1" 2>&1 || echo "[código de salida: $?]"
}
# La prueba: ¿puede root regalarle un archivo a otro usuario?
REGALAR='grep CapEff /proc/self/status; touch /tmp/a && chown 10001 /tmp/a && echo "chown: hecho"'

echo "== 1. root, con las capacidades que Docker deja por omisión"
correr -- "$REGALAR"

echo
echo "== 2. El mismo root, con --cap-drop ALL"
correr --cap-drop ALL -- "$REGALAR"

echo
echo "== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta"
correr --cap-drop ALL --cap-add CHOWN -- "$REGALAR"

# La otra prueba: un usuario normal ejecuta una copia de «id» con el bit setuid.
SETUID='cp /usr/bin/id /tmp/id-suid && chmod u+s /tmp/id-suid && ls -l /tmp/id-suid | cut -d" " -f1,3
setpriv --reuid 10001 --regid 10001 --clear-groups sh -c "id; /tmp/id-suid; grep NoNewPrivs /proc/self/status"'

echo
echo "== 4. Un programa setuid de root, ejecutado por el usuario 10001"
correr -- "$SETUID"

echo
echo "== 5. Lo mismo con --security-opt no-new-privileges"
correr --security-opt no-new-privileges -- "$SETUID"

echo
echo "== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80"
correr --user 10001:10001 --cap-drop ALL -- \
  'cat /proc/sys/net/ipv4/ip_unprivileged_port_start; perl -MIO::Socket::INET -e '"'"'IO::Socket::INET->new(LocalPort => 80, Listen => 1, ReuseAddr => 1) or die "no pude: $!\n"; print "escuchando en el 80\n"'"'"
```

```text
$ ./fig07_07.sh
== 1. root, con las capacidades que Docker deja por omisión
CapEff:	00000000a80425fb
chown: hecho

== 2. El mismo root, con --cap-drop ALL
CapEff:	0000000000000000
chown: changing ownership of '/tmp/a': Operation not permitted
[código de salida: 1]

== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta
CapEff:	0000000000000001
chown: hecho

== 4. Un programa setuid de root, ejecutado por el usuario 10001
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 euid=0(root) groups=10001
NoNewPrivs:	0

== 5. Lo mismo con --security-opt no-new-privileges
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 groups=10001
NoNewPrivs:	1

== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80
0
escuchando en el 80
```

A função `correr` monta um `docker run --rm` com as opções passadas antes de `--` e executa o comando com `sh -c`. A prova dos três primeiros blocos é a mesma: mostrar a linha `CapEff` (as capabilities **efetivas**, as que o processo pode usar neste momento) e dar um arquivo de presente ao usuário `10001` com `chown`.

1. **`root` com o padrão.** `CapEff: 00000000a80425fb`, a mesma máscara das catorze que foram decodificadas na Lição 0. O `chown` funciona.
2. **`root` com `--cap-drop ALL`.** `CapEff` em zero, e o `chown` falha com `Operation not permitted`, código 1. É `root` (continua sendo o usuário 0), mas um `root` sem capabilities não pode fazer o que torna o `root` especial.
3. **`--cap-drop ALL --cap-add CHOWN`.** A máscara vale `1`: um único bit, o de `CAP_CHOWN`, que é a capability número 0. O `chown` volta a funcionar. É o padrão para um programa que de fato precisa de uma: retirar todas e devolver só essa, com nome, à vista de quem ler o comando.

#### 7.8.3 As portas baixas já não precisam de capability

O bloco 6 responde a uma dúvida que vai surgir: se `CAP_NET_BIND_SERVICE` é a que permite escutar em portas menores que 1024, um servidor web na porta 80 precisa conservá-la? Em um contêiner do Docker, não. O usuário `10001`, **sem nenhuma capability**, abriu a porta 80. A primeira linha explica por quê: dentro do contêiner, o ajuste do kernel `ip_unprivileged_port_start`, que diz a partir de que porta um usuário sem privilégios pode escutar, vale `0`. O Docker o define assim por padrão desde a versão 20.10, em cada contêiner com rede própria ([moby/moby #41030](https://github.com/moby/moby/pull/41030)), e como esse ajuste vale só para a rede do contêiner, não muda nada na máquina. O `revisor` escuta na 8080 e de qualquer forma não precisa disso, mas assim fica sabido que `--cap-drop ALL` não obriga a mudar um serviço de porta.

### 7.9 `no-new-privileges`

#### 7.9.1 O bit *setuid*

No Linux, um arquivo executável pode ter ligado o bit ***setuid***: quem o executar, seja quem for, o roda **com o usuário dono do arquivo**. É assim que funcionam `passwd` ou `su`, que um usuário normal executa e que precisam ser `root` por um instante. O manual de capabilities diz isto sobre o caso que importa: um programa *setuid* de `root` ganha todas as capabilities, exceto as que o teto (*bounding set*) não permite ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). É uma porta legítima para elevar privilégios, e por isso é a favorita de quem tenta elevá-los sem permissão.

`--security-opt no-new-privileges` fecha essa porta. Liga no processo uma marca do kernel, `no_new_privs`, que a documentação do kernel define assim: com ela, `execve` (executar outro programa) promete «não conceder o privilégio de fazer nada que não pudesse ter sido feito sem essa chamada»; em concreto, «os bits *setuid* e *setgid* já não mudam o uid nem o gid», e as capabilities de um arquivo não se somam. A marca é herdada por todos os filhos e **não pode ser desligada** ([Linux, «No New Privileges Flag»](https://docs.kernel.org/userspace-api/no_new_privs.html)). A referência do `docker run` diz isso em termos práticos: com esta opção, «os comandos que elevam privilégios, como `su` ou `sudo`, deixam de funcionar».

#### 7.9.2 Vê-lo

Os blocos 4 e 5 do `fig07_07.sh` fazem a prova. Como `root`, o script copia o programa `id` para `/tmp/id-suid` e liga o bit *setuid* (o `s` de `-rwsr-xr-x`, dono `root`). Depois, com `setpriv`, uma ferramenta do Debian que troca de usuário, torna-se o usuário `10001` e executa duas vezes o `id`: o normal e a cópia *setuid*.

4. **Sem `no-new-privileges`.** O `id` normal diz `uid=10001`. A cópia diz `uid=10001 ... euid=0(root)`: o usuário **efetivo** é `root`. Um usuário qualquer executou um arquivo e, enquanto ele roda, tem os poderes de `root`. `NoNewPrivs: 0`.
5. **Com `no-new-privileges`.** Os dois dizem `uid=10001` e nada mais. O bit continua ali (`-rwsr-xr-x`), mas o kernel já não lhe dá importância. `NoNewPrivs: 1`.

Por que isso importa no `revisor`, que não tem programas *setuid*? Pela mesma razão que `--cap-drop ALL`: não é pelo que há hoje na imagem, e sim pelo que alguém possa colocar ou encontrar amanhã. E combina com o anterior: o `tmpfs` de `/tmp` leva `nosuid` e `noexec`, o sistema de arquivos raiz é somente leitura e o teto de capabilities é zero. Para elevar privilégios, um atacante precisaria escrever um programa, executá-lo e fazer com que o bit *setuid* valesse; cada uma das três opções lhe fecha um passo.

### 7.10 Tudo junto: o `revisor` reforçado

#### 7.10.1 O comando

Estas são as opções com que o `revisor` roda daqui em diante. A Lição 9 as escreve no `compose.yaml` com seus equivalentes em YAML (`read_only: true`, `cap_drop: [ALL]`, `security_opt`, `init: true`), e não como opções de linha de comando:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' \
  curso-docker-revisor:1.4.0
```

Cada linha vem de uma lição: a porta em `127.0.0.1` e os limites, da 2; a imagem sem `root` nem *shell*, da 3 e da 5; a configuração por `-e`, da 6; e a segunda linha e a política de reinício, desta. Não leva `--tmpfs` porque aqui não se pede que ele guarde o relatório; na Lição 8 ele terá um volume para isso.

Essas opções reduzem muito o que um intruso pode fazer, mas não substituem mais nada: um programa que de fato precise de uma capability concreta ou de escrever em um lugar concreto pede `--cap-add` ou um volume, um por um, e o resto da defesa (que código roda, o que se monta nele) continua sendo trabalho de quem opera.

#### 7.10.2 Comprová-lo

O bloco 3 do `fig07_06.sh` roda exatamente essas opções e pergunta a cada parte o que lhe cabe:

1. **A saúde:** `(healthy)` aos 5 segundos, com tudo ligado. Nenhuma das opções atrapalhou o `revisor`.
2. **O que o Docker anotou:** `ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped`. É o que foi pedido, lido da configuração do contêiner.
3. **Os processos:** `docker-init` como número 1 e `/revisor` como seu filho, os dois com o usuário `65532`.
4. **O que o kernel aplica**, lido de `/proc` do filho, que é o `revisor` (o script o encontra com `pgrep -P`, que busca os filhos de um processo): `CapEff` em zero (não tem capabilities), `CapBnd` em zero (nem poderia ganhá-las) e `NoNewPrivs: 1`. Dos três, `CapBnd` é o que demonstra o `--cap-drop ALL`: o `revisor` roda como `65532`, e seu `CapEff` estaria em zero mesmo sem retirar nada; o teto, em compensação, seria o das catorze capabilities. Isso é mais do que o Docker informa: é o que o kernel faz cumprir. Uma opção mal escrita poderia ficar anotada sem ser aplicada; `/proc` não mente.
5. **O desligamento:** o `docker stop` demorou **206 ms** e o código é `0`. O `docker-init` passou o sinal ao `revisor`, o `revisor` o atendeu e se despediu em seus logs. Tudo reforçado, e morre tão bem quanto sem nada.

Na pasta do projeto, rode o comando de 7.10.1, espere alguns segundos e confira com `docker ps --filter name=curso-docker-revisor` se diz `(healthy)`. Quando aparecer `(healthy)`, apague-o com `docker rm -f curso-docker-revisor` **antes dos exercícios**, que usam esse nome e essa porta; a imagem `curso-docker-revisor:1.4.0` fica para a Lição 8.

### 7.11 O que se encontra em tutoriais antigos

- **`HEALTHCHECK CMD curl -f http://localhost/ || exit 1`.** Funciona em imagens que trazem *shell* e `curl`, e obriga a colocar as duas coisas onde não deveriam estar. Na seção 7.4.4 viu-se como ele falha em uma imagem mínima: `unhealthy` com um serviço saudável. Se o programa é um servidor, convém dar-lhe um subcomando de saúde.
- **Instalar `tini` ou `dumb-init` dentro do Dockerfile** e pô-lo no `ENTRYPOINT`. Era necessário antes de o Docker trazer seu próprio *init*; hoje `--init` faz o mesmo sem tocar na imagem. Continua fazendo sentido se a imagem vai rodar em um lugar onde não se pode pedir `--init`.
- **Um script de inicialização que termina em `revisor` em vez de `exec revisor`.** É a forma *shell* da Lição 3 escondida em um arquivo: o *shell* fica como número 1 e o sinal não chega.
- **`--restart always` em tudo, «para que não caia».** Não conserta um programa quebrado (reinicia-o uma e outra vez, cada vez mais tarde) e não faz nada com um doente que continua rodando. Além disso, segundo a documentação, um contêiner com `always` que foi parado de propósito ressuscita quando o daemon é reiniciado.
- **`--privileged` para «tirar problemas de permissão».** É o contrário desta lição: dá ao contêiner todas as capabilities e acesso aos dispositivos da máquina. A referência do `docker run` explica que, por padrão, o Docker retira as capabilities mais perigosas, como `CAP_SYS_ADMIN`; `--privileged` as devolve todas. Se um programa precisa de uma capability, `--cap-add` com o nome dela.

## O erro que se vai ver

Esta lição tem um erro principal e dois que aparecem com ele.

**O erro principal: a verificação de saúde que não pode ser executada.** É o do `fig07_03.sh`:

```text
Up 4 seconds (unhealthy)
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
```

Lê-se assim. `-1` não é um código do programa: é o Docker dizendo que nem conseguiu começar a verificação. `OCI runtime exec failed` diz quem falhou, o componente que executa processos dentro do contêiner. E o final diz o que ele buscou e não encontrou: `/bin/sh`. A verificação estava em forma *shell* (ou foi passada com `--health-cmd`, que é o mesmo) e a imagem não tem *shell*. Corrige-se com uma verificação em forma *exec* que chame um programa que a imagem tenha: `HEALTHCHECK CMD ["/revisor", "healthcheck"]`. Se em vez de `/bin/sh` a mensagem disser `curl`, a imagem tem *shell*, mas não `curl`; a correção é a mesma. E antes de culpar o programa, pergunte a ele: `docker exec <contêiner> /revisor healthcheck`. Se responder `sano`, o problema está na verificação, não no serviço.

**O que aparece com ele: somente leitura.** O do `fig07_06.sh`:

```text
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
```

`read-only file system` é dito pelo kernel: o contêiner roda com `--read-only` e o programa tentou escrever. A pergunta que resolve é «onde meu programa escreve, e por quê?». Se é algo temporário, um `--tmpfs` nessa pasta; se precisa durar, um volume (Lição 8). O que não é uma correção: tirar `--read-only`.

**O código que denuncia um mau desligamento: `137` depois de `docker stop`.** Se o `docker stop` demora o prazo completo e deixa `ExitCode=137`, o sinal não serviu ao processo número 1: ou há um *shell* no meio (Lição 3), ou é um programa que não instalou handler (7.1.4). Olhe o `docker top` para saber quem é o número 1 e o `SigCgt` para saber o que ele atende. Se não é possível mudar o programa, `--init`.

## O hábito de segurança da lição

**O contêiner roda com o mínimo: sistema de arquivos somente leitura, zero capabilities e sem ganhar privilégios, e se comprova em `/proc` que o kernel o aplica.** São três opções que se escrevem juntas (`--read-only --cap-drop ALL --security-opt no-new-privileges`) e uma comprovação que se faz uma vez por imagem. Cada uma tira um passo de quem conseguir controlar o processo por uma falha do programa: não pode escrever no disco, não tem nenhum dos poderes partidos do `root` e não pode virar `root` executando um programa *setuid*. O acidente que isso evita não é hipotético: quase todas as formas de passar de «controlo um processo» a «controlo a máquina» precisam escrever algo, usar uma capability ou subir de usuário. E a metade que se esquece é a segunda: não basta escrever as opções, é preciso ver `CapBnd: 0000000000000000` (o teto: nem um `root` de dentro poderia ganhar capabilities) e `NoNewPrivs: 1`. `CapEff` em zero não basta como prova: um usuário que não é `root`, como o `65532` do `revisor`, já o tem em zero sem `--cap-drop ALL`. O que se acrescenta depois se acrescenta com nome: uma pasta gravável com `--tmpfs` ou um volume, uma capability com `--cap-add`.

## O que se faz errado

**Encurtar o prazo do `docker stop` para que «não demore tanto».** Com `-t 2`, um programa que não atende o sinal morre em 2 segundos em vez de 10, mas morre igualmente mal: `137`, sem terminar o que fazia. A correção é fazer o sinal chegar (`--init`, forma *exec*, um handler), não matar mais cedo.

**Um prazo interno de desligamento maior que o do Docker.** Se o programa espera 15 segundos pelas suas requisições e o Docker lhe dá 10, o desligamento ordenado nunca termina. Ajuste um ou outro (`--stop-timeout`), mas de modo que caiba.

**Confundir `Up` com «funciona».** O `docker ps` diz `Up` enquanto o processo existir. Se o contêiner não tem `HEALTHCHECK`, ninguém está perguntando se ele atende.

**Uma verificação de saúde que depende de outros serviços.** Se a saúde do `revisor` dependesse dos serviços que ele verifica, uma queda alheia o poria `unhealthy`. A verificação pergunta pelo próprio processo.

**Uma verificação cara.** Ela roda a cada poucos segundos durante toda a vida do contêiner. Uma consulta completa a um banco de dados, ou um relatório inteiro, a cada dez segundos, é carga que ninguém pediu.

**Esperar que `--restart` cure um contêiner `unhealthy`.** Nenhuma política olha a saúde. Viu-se em 7.5: sequência de quatro falhas, zero reinícios.

**Tirar `--read-only` porque «o programa precisa escrever».** O programa precisa escrever em **um** lugar. Dê a ele esse lugar, com nome.

**`--privileged` ou `--cap-add ALL` para se livrar do problema.** Desfaz a lição inteira. Se algo pede uma capability, descubra qual e acrescente só essa.

**Acreditar no que diz o `docker inspect` sem olhar o `/proc`.** O `docker inspect` mostra o que foi pedido. O `/proc/<pid>/status` mostra o que o kernel aplica. Normalmente coincidem; quando não, quem manda é o kernel.

## Exercícios

Faça-os em ordem. Antes de rodar cada um, escreva no [diário de bordo](bitacora.md) o que se acredita que vai acontecer; compará-lo depois é metade do aprendizado. Ao terminar, apague o que foi criado: tudo leva o prefixo `curso-docker-`.

### Exercício 1 — Leia o final

Sem rodar nada, diga que `ExitCode` cada contêiner deixa e quanto o `docker stop` demoraria aproximadamente, quando se aplicar. Use a tabela de 7.1.2.

1. O `revisor` 1.4.0, rodando bem, parado com `docker stop`.
2. A imagem do Go rodando `sleep 300`, sem `--init`, parada com `docker stop`.
3. A mesma, com `--init`, parada com `docker stop`.
4. O `revisor` 1.4.0 sem `REVISOR_SERVICIOS`, sem política de reinício.
5. O `revisor` 1.4.0 rodando bem, terminado com `docker kill`.
6. Um contêiner `(unhealthy)` cujo histórico de saúde diz `-1 "OCI runtime exec failed: ..."`. Que código tem o **contêiner**?

### Exercício 2 — Quanto tempo leva para adoecer?

Com a imagem `curso-docker-prueba:1.0.0` da Lição 2, preveja quanto tempo leva para passar a `unhealthy` um contêiner que inicia em modo fora do ar com estas opções, e quanto vale sua sequência de falhas nesse momento:

```bash
docker run -d --name curso-docker-prueba -e PRUEBA_MODO=caido \
  --health-interval 2s --health-retries 5 --health-start-period 1ms \
  curso-docker-prueba:1.0.0
```

Depois meça: pergunte a cada meio segundo com `docker inspect --format '{{.State.Health.Status}}' curso-docker-prueba` e conte os segundos desde que foi iniciado. As opções `--health-*` do `docker run` mudam as da imagem para esse contêiner. Apague-o com `docker rm -f curso-docker-prueba` e repita com `--health-start-period 0s`. Antes de rodar, preveja: demora o mesmo? Dica: releia o ponto 2 de 7.4.4. No fim, `docker rm -f curso-docker-prueba`.

### Exercício 3 — Outro sinal de desligamento (projeto)

Se o contêiner de 7.10 continua rodando, apague-o primeiro com `docker rm -f curso-docker-revisor`. Depois rode a imagem com outro sinal de desligamento:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --stop-signal SIGINT \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.4.0
```

Antes de pará-lo, preveja três coisas: o que seu log dirá ao se desligar (`docker logs curso-docker-revisor`), com que código ele terminará e que sinal mostrará `docker inspect --format '{{.Config.StopSignal}}' curso-docker-revisor`. Depois pare-o com `docker stop curso-docker-revisor`, meça o tempo com `time` e compare. Dica: veja que sinais o `revisor` atende em 7.1.1. Pergunta extra: o que aconteceria com `--stop-signal SIGHUP`, um sinal que o código do `revisor` não pediu? No fim, `docker rm -f curso-docker-revisor`.

### Exercício 4 — Reforce o serviço de teste

Rode o serviço de teste com as opções reforçadas de 7.10.1 (sem a porta e sem `-e`, que ele não precisa):

```bash
docker run -d --name curso-docker-prueba \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  curso-docker-prueba:1.0.0
```

Antes, preveja: chegará a `healthy`? Precisa de um `--tmpfs`? Quem será o número 1 e com que usuário? Com que código terminará ao ser parado? Depois confira com `docker ps --filter name=curso-docker-prueba`, `docker top curso-docker-prueba -o pid,user,args`, `docker stop curso-docker-prueba`, `docker inspect --format '{{.State.ExitCode}}' curso-docker-prueba` e `docker logs curso-docker-prueba`. No fim, `docker rm -f curso-docker-prueba`.

## Soluções

As soluções 2, 3 e 4 foram medidas com dois scripts que fazem o mesmo que os exercícios, com nomes de apoio `fig07` e sem publicar portas: `fig07_08.sh` (serviço de teste) e `fig07_09.sh` (`revisor`).

### Solução 1

1. **`0`**, em décimos de segundo: o `revisor` atende `SIGTERM` e sai por conta própria (7.4.4).
2. **`137`**, em um pouco mais de 10 segundos: `sleep` é o número 1, não tem handler, o sinal é ignorado e no fim chega `SIGKILL` (7.1.4).
3. **`143`**, em décimos de segundo: o `docker-init` reenvia o sinal, o `sleep` já não é o número 1 e morre com a ação padrão de `SIGTERM`, 128 + 15 (7.3.2).
4. **`1`**: o `revisor` termina sozinho, com seu próprio código de erro, sem que ninguém lhe mande nada. O `docker stop` não se aplica: ele já está parado.
5. **`137`**: o `docker kill` manda `SIGKILL` sem esperar. E, se tivesse política `always`, não voltaria a iniciar, porque conta como parada manual (7.6.2).
6. **Nenhum**, porque o contêiner continua rodando: `unhealthy` é um rótulo, não uma morte. O `-1` é o código da **verificação**, não do contêiner. Seu `.State.ExitCode` vale `0` enquanto roda.

### Solução 2

```bash
#!/usr/bin/env bash
# fig07_08.sh — Las soluciones de los Ejercicios 2 y 4, con el servicio de prueba:
# cuánto tarda en enfermarse con otros tiempos de salud, y cómo corre con las
# opciones endurecidas de la lección.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}

for arranque in 0s 1ms; do
  echo "== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period $arranque"
  inicio=$(t)
  docker run -d --name "$NOMBRE" -e PRUEBA_MODO=caido \
    --health-interval 2s --health-retries 5 --health-start-period "$arranque" "$IMAGEN" >/dev/null
  esperar_salud unhealthy; fin=$(t)
  echo "pasó a unhealthy a los $(( (fin - inicio) / 100 ))00 ms de arrancar"
  docker inspect --format 'racha={{.State.Health.FailingStreak}} StartPeriod={{.Config.Healthcheck.StartPeriod}}' "$NOMBRE"
  docker rm -f "$NOMBRE" >/dev/null
  echo
done

echo "== Ejercicio 4: el servicio de prueba con las opciones endurecidas"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
docker top "$NOMBRE" -o pid,user,args | sed -E 's/^ *[0-9]+ /<pid> /'
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1
```

```text
$ ./fig07_08.sh
== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 0s
pasó a unhealthy a los 13400 ms de arrancar
racha=5 StartPeriod=5s

== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 1ms
pasó a unhealthy a los 10900 ms de arrancar
racha=5 StartPeriod=1ms

== Ejercicio 4: el servicio de prueba con las opciones endurecidas
Up 5 seconds (healthy)
PID                 USER                COMMAND
<pid>             65532               /sbin/docker-init -- /servicio-prueba
<pid>             65532               /servicio-prueba
docker stop tardó 234 ms; ExitCode=0
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando
```

Com `--health-start-period 1ms`, passou a `unhealthy` aos **10.9 segundos**, com `racha=5`. A conta é 5 falhas com 2 segundos entre verificações, 10 segundos, mais o que cada verificação demora (executar um processo dentro do contêiner não é de graça). A sequência vale exatamente o que foi pedido em `--health-retries`: a saúde muda justo na falha número 5.

Com `--health-start-period 0s` demorou **13.4 segundos**, e a linha do `docker inspect` diz por quê: `StartPeriod=5s`. Um zero em uma opção `--health-*` do `docker run` não desliga nada; significa «use o da imagem», e o Dockerfile do serviço de teste diz `--start-period=5s`. Durante esses 5 segundos o Docker pergunta a cada `--start-interval` (5 s), de modo que a primeira verificação chegou aos 5 segundos, e as seguintes a cada 2: aos 5, 7, 9, 11 e 13. A quinta falha cai aos 13. Se a previsão foi «uns dez segundos» para o primeiro e «uns treze» para o segundo, a conta e a armadilha foram entendidas. Os tempos exatos mudam de uma execução para outra; as sequências, não.

### Solução 3

```bash
#!/usr/bin/env bash
# fig07_09.sh — La solución del Ejercicio 3: el revisor con otra señal de apagado.
# SIGINT, que el revisor atiende, y SIGHUP, que no pidió, sin y con --init.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

t() { date +%s%3N; }
SERVICIOS='propio http://127.0.0.1:8080/salud'

for prueba in "SIGINT" "SIGHUP" "SIGHUP --init"; do
  set -- $prueba
  echo "== --stop-signal $1 ${2:-sin --init}"
  docker run -d --name "$NOMBRE" --stop-signal "$1" ${2:-} -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
  sleep 1
  inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop tardó $(( fin - inicio )) ms"
  docker inspect --format 'ExitCode={{.State.ExitCode}} StopSignal={{.Config.StopSignal}}' "$NOMBRE"
  docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
  docker rm -f "$NOMBRE" >/dev/null
  echo
done
```

```text
$ ./fig07_09.sh
== --stop-signal SIGINT sin --init
docker stop tardó 102 ms
ExitCode=0 StopSignal=SIGINT
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí interrupt, apagando
revisor: apagado limpio

== --stop-signal SIGHUP sin --init
docker stop tardó 72 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))

== --stop-signal SIGHUP --init
docker stop tardó 87 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
```

Com `SIGINT`: `interrupt` é como o Go nomeia o `SIGINT`, assim como `terminated` é `SIGTERM`. O `revisor` instalou handler para os dois, então se desliga igualmente bem com qualquer um: código `0`, em milissegundos. O `--stop-signal` ficou anotado na configuração do contêiner (`StopSignal=SIGINT`) e ganha sobre o `STOPSIGNAL SIGTERM` da imagem.

Pergunta extra, com `SIGHUP`: morreu em milissegundos com `ExitCode=129` (128 + 1), sem e com `--init`, e seu log fica em `escuchando`, sem `apagando` nem `apagado limpio`. Não esperou os 10 segundos, embora sem `--init` seja o número 1, porque todo programa em Go traz de fábrica um handler para esse sinal: a documentação do Go diz que «`SIGHUP`, `SIGINT` ou `SIGTERM` fazem o programa terminar» ([os/signal](https://pkg.go.dev/os/signal)). Há handler, então o sinal chega; mas esse handler de fábrica termina o programa de uma vez, sem o desligamento em ordem que o `revisor` faz apenas com `SIGTERM` e `SIGINT`. O fato de o código sair `129` também com o `revisor` como número 1 depende de como o *runtime* do Go termina o programa; é o que o Docker 29.2.1 mediu com o Go 1.27.3. A regra prática não muda: o sinal de desligamento se escolhe olhando o código, e o `STOPSIGNAL` o deixa escrito.

### Solução 4

É o último bloco do `fig07_08.sh`. Chega a `healthy` sem `--tmpfs`, porque o serviço de teste não escreve nenhum arquivo. O número 1 é o `docker-init` e seu filho é o serviço, os dois com `65532`, o usuário que seu Dockerfile fixa. Para em décimos de segundo com `0`: atende `SIGTERM`, como o `revisor`. É a mesma linha de opções que a Lição 8 aplica ao serviço de teste quando o coloca em uma rede interna, e por isso lá já não será preciso pensar nela.

## Como sei que consegui

Marque cada ponto só se for possível fazê-lo **sem voltar a olhar o texto**:

- [ ] Na pasta do projeto, `docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0` mostra `["CMD","/revisor","healthcheck"]` com `Interval` de dez segundos.
- [ ] Explica-se em um minuto por que `sleep 300` morre com `SIGTERM` no terminal e não como número 1 de um contêiner, usando as palavras *handler*, *ação padrão* e *número 1*.
- [ ] Mede-se o `docker stop` de um `sleep` sem e com `--init`, e obtém-se um pouco mais de 10 segundos com `137`, e décimos de segundo com `143`.
- [ ] Vê-se um zumbi com `ps --ppid` na máquina, e explica-se por que o `docker top` não o mostra.
- [ ] Põe-se o serviço de teste em modo fora do ar e lê-se no `docker inspect` `running / unhealthy`, a sequência de falhas e a causa `GET / respondió 503`, com zero reinícios.
- [ ] Diz-se o que fazem `no`, `on-failure:3`, `always` e `unless-stopped` quando o processo morre sozinho, quando é parado com `docker stop` e quando o daemon é reiniciado.
- [ ] Roda-se o `revisor` com as opções de 7.10.1, ele chega a `(healthy)`, e em `/proc/<pid do revisor>/status` lê-se `CapBnd: 0000000000000000` e `NoNewPrivs: 1` (e explica-se por que `CapEff` em zero não prova nada com um usuário que não é `root`).
- [ ] Provoca-se `read-only file system` com `REVISOR_REPORTE=/tmp/reporte.json` e corrige-se com um `--tmpfs` de tamanho fixo, sem tirar `--read-only`.
- [ ] Rodam-se os scripts de [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida) (com outra porta em `PUERTO`, se as da máquina estiverem ocupadas) e as saídas coincidem com as desta lição, exceto os milissegundos, os segundos de `Up` e das esperas, e os números ocultados. E ao terminar, `docker ps -a --filter name=curso-docker-` não mostra contêineres desta lição.

## Resumo

Responda sem olhar a lição:

1. O que é um sinal, e em que `SIGTERM` e `SIGKILL` se diferenciam?
2. Como se lê um `ExitCode` de `137`? E um de `143`? E um de `0` depois de `docker stop`?
3. Por que o processo número 1 de um contêiner não morre com `SIGTERM` se não instalou um handler?
4. O que faz o `docker stop` passo a passo, e com que opções se mudam seu prazo e seu sinal?
5. Que dois trabalhos faz o `--init`, e por que o curso o usa com o `revisor` embora hoje ele não precise?
6. O que significam os códigos `0`, `1` e `2` de uma verificação de saúde, e o que significa `-1` em seu histórico?
7. Por que a verificação do `revisor` é um subcomando do mesmo binário e não `curl`?
8. O que o Docker faz com um contêiner `unhealthy`? E uma política de reinício?
9. Em que `always` e `unless-stopped` se diferenciam?
10. O que mudam `--read-only`, `--cap-drop ALL` e `--security-opt no-new-privileges`, e onde se comprova que o kernel os aplica?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html): os sinais `SIGINT`, `SIGKILL` e `SIGTERM`, seus números e ações padrão, e que `SIGKILL` e `SIGSTOP` não podem ser capturados, bloqueados nem ignorados.
- [pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html): o processo *init* de um namespace só recebe os sinais para os quais tem handler, exceto `SIGKILL` e `SIGSTOP` vindos de um namespace ancestral; e os órfãos passam a ser seus filhos.
- [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html): o que são as capabilities, as definições de `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_KILL`, `CAP_SETUID` e `CAP_NET_BIND_SERVICE`, o teto (*bounding set*) e o que ganha um programa *setuid* de `root`.
- [Linux, «No New Privileges Flag»](https://docs.kernel.org/userspace-api/no_new_privs.html): o que `no_new_privs` faz com o `execve`, os bits *setuid* e *setgid*, e que ela é herdada e não pode ser desligada.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM` e depois `SIGKILL`, o prazo de 10 segundos no Linux, `-t`, `-s` e `-t -1`.
- [`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/): que manda `SIGKILL` por padrão.
- [Referência do `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `--init` e `docker-init`, o PID 1 que ignora os sinais com ação padrão, `--stop-signal`, `--stop-timeout`, `--read-only`, `--tmpfs`, `no-new-privileges`, as opções `--health-*`, a espera crescente entre reinícios e o que o Docker retira por padrão em comparação com `--privileged`.
- [Referência do Dockerfile](https://docs.docker.com/reference/dockerfile/): `HEALTHCHECK` (opções, valores padrão, códigos 0, 1 e 2, um por Dockerfile, `NONE`, 4,096 bytes de saída) e `STOPSIGNAL`.
- [Docker, «Start containers automatically»](https://docs.docker.com/engine/containers/start-containers-automatically/): as quatro políticas de reinício e a parada manual.
- [Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/): que um `tmpfs` vive na memória e desaparece com o contêiner, seu tamanho máximo padrão e sua permissão `1777`.
- [tini](https://github.com/krallin/tini): o *init* mínimo por trás do `docker-init`: um único filho, recolher zumbis e reenviar sinais.
- [os/signal](https://pkg.go.dev/os/signal): que um programa em Go termina por padrão com `SIGHUP`, `SIGINT` ou `SIGTERM`.
- [moby/moby #41030](https://github.com/moby/moby/pull/41030): a mudança que define `net.ipv4.ip_unprivileged_port_start=0` por padrão nos contêineres, desde o Docker 20.10.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões e datas de «Sobre as execuções».
- [Colima](https://github.com/abiosoft/colima): a ferramenta com que os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **capability** | um dos pedaços em que o Linux divide o poder do `root`; retiram-se com `--cap-drop` e acrescentam-se com `--cap-add` |
| **código de saída** | o número com que um processo termina; 128 + *n* se foi terminado pelo sinal *n* |
| **`HEALTHCHECK`** | instrução que diz ao Docker como perguntar a um contêiner se ele está saudável |
| ***init*** | o processo número 1; com `--init`, um programa minúsculo que reenvia sinais e recolhe zumbis |
| **handler** | função que um programa instala para atender um sinal no lugar da ação padrão |
| **`no-new-privileges`** | marca do kernel que impede que um processo ganhe privilégios ao executar outro programa |
| **prazo** (do `docker stop`) | o que o Docker espera entre `SIGTERM` e `SIGKILL`; 10 segundos por padrão |
| **política de reinício** | o que o daemon faz quando o processo de um contêiner termina |
| **sinal** | aviso curto do kernel a um processo, identificado por um número |
| ***setuid*** | bit de um executável que o faz rodar com o usuário dono do arquivo |
| **`tmpfs`** | pasta que vive na memória e desaparece com o contêiner |
| **zumbi** | processo que já terminou e espera que o pai leia seu código de saída |

---

**Seguinte:** [Lição 8 — Volumes e redes](08-volumenes-y-redes.md)
