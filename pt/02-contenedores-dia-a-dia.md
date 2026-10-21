# Lição 2 — Contêineres no dia a dia

Faltam doze minutos para a demonstração e o serviço não inicia. Digita-se o mesmo comando que ontem funcionou e o Docker responde com uma linha em inglês terminando em `port is already allocated`. Tenta-se de novo e agora a mensagem é outra: `The container name ... is already in use`. Alguém ao lado sugere reiniciar o computador. Antes de fazer isso, roda-se `docker ps -a` e a tela se enche: contêineres da semana passada, alguns parados, outros ainda rodando, um deles publicado na porta 9000 **para qualquer pessoa na mesma rede sem fio da cafeteria** onde se trabalhou na terça-feira. Ninguém fez isso por maldade. Simplesmente ninguém aprendeu a iniciar, examinar, parar e apagar contêineres de forma organizada. Restam dez minutos, e esta lição é o que teria sido preciso saber.

**Tempo:** 2 × 45 min

**O que se constrói:** o serviço de teste do curso rodando em um contêiner, com a porta publicada apenas para a própria máquina e com limites de memória, CPU e processos; consulta-se o serviço em três modos (saudável, lento e fora do ar), lê-se o registro dele, inspeciona-se, para-se e apaga-se o contêiner. Ao final, não fica nenhum contêiner do curso na máquina; a imagem `curso-docker-prueba:1.0.0`, por outro lado, permanece, porque as lições seguintes voltam a usá-la.

**O que se aprende:** os comandos do dia a dia (`run`, `ps`, `logs`, `exec`, `inspect`, `stats`, `stop`, `start` e `rm`); o que significa publicar uma porta e por que neste curso ela sempre é publicada em `127.0.0.1`; como definir limites de memória, CPU e processos e como comprovar que ficaram definidos; o ciclo de vida de um contêiner (criado, rodando, parado, apagado); e como limpar apenas o que é do curso sem mexer no que é de outras pessoas.

**De onde se parte.** Da [Lição 0](00-que-es-un-contenedor.md) traz-se o mapa: um contêiner é um processo isolado, a imagem é o modelo e o contêiner a cópia viva, e o cliente `docker` pede tudo ao daemon por um *socket*. Da [Lição 1](01-instalacion.md) traz-se o Docker instalado no Mint e o usuário no grupo `docker`, sabendo que isso equivale a `root`. Também é necessário ter o repositório do curso na máquina: dele será usada a pasta `programas/servicio-prueba/`, que traz o serviço de teste já escrito e com o `Dockerfile` pronto. Não é preciso saber Go nem saber ler esse `Dockerfile` ainda.

**O que esta lição não faz.** Não escreve nenhum `Dockerfile`: o do serviço de teste é usado tal como vem, e aprender a lê-lo é trabalho das Lições 3 a 5. Não mexe ainda no `revisor`, o projeto principal do curso, porque para rodá-lo é preciso primeiro empacotá-lo, e isso começa na [Lição 3](03-primer-dockerfile.md). Também não explica volumes nem redes entre contêineres; aqui cada contêiner vive isolado e a comunicação com ele é feita a partir da própria máquina.

**Sobre as execuções.** As saídas desta lição foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual de Linux com Ubuntu 24.04.4 (a mesma base do Linux Mint 22), processador ARM de 64 bits. Os scripts foram executados **dentro dessa máquina virtual**, com Docker 29.2.1 (cliente e daemon, API 1.53). O cliente do Mac era a versão 29.8.2, com a qual o curso foi planejado, e a mais recente publicada naquele dia era a 29.9.2, de 20 de outubro de 2026, segundo as [notas de versão oficiais](https://docs.docker.com/engine/release-notes/29/). Três avisos sobre como foi executado. **Primeiro:** nessa máquina eram escritas ao mesmo tempo várias lições do curso, então, para não haver conflitos, as execuções usaram nomes com um prefixo próprio (`curso-docker-l02-` em vez de `curso-docker-`) e as portas 18020 e 18021 em vez de 9000 e 9001. Nas saídas apresentadas aqui, e nos arquivos `.salida.txt` dos programas, foram restaurados os nomes e portas que serão usados no curso, e foram reajustados os espaços das tabelas, porque a largura de cada coluna depende do nome mais longo; nada mais foi alterado. É uma exceção à regra do curso de não editar uma saída, e foi adotada de propósito: executar os scripts com os nomes reais nessa máquina compartilhada teria sido perigoso, não apenas incômodo, porque o `trap` de cada script apaga `curso-docker-prueba` ao sair, e esse contêiner poderia ser o de outra lição rodando naquele momento. No Mint não há mais ninguém, e os scripts rodam tal como estão escritos. **Segundo:** a saída de `fig02_01.sh` é a da primeira construção, quando a imagem ainda não existia; a imagem base de Go já estava baixada, então a construção da seção 2.1 não mostra downloads; na primeira execução, será exibido primeiro o download das duas imagens base, a de Go e a mínima, e isso vai demorar mais. **Terceiro:** o que muda no Mint é a arquitetura (`amd64` em vez de `arm64` se o processador for Intel ou AMD), os identificadores, os tempos e a memória total informada por `docker stats`. As soluções dos exercícios que citam uma saída também foram verificadas nessa máquina, com o mesmo prefixo. Os programas estão em [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia), cada um com a saída salva ao lado.

## Ao terminar, será possível

- Construir a imagem do serviço de teste com um único comando e encontrá-la com `docker image ls`.
- Iniciar um contêiner em segundo plano com nome, porta publicada em `127.0.0.1` e limites de memória, CPU e processos, e explicar cada opção do comando.
- Listar os contêineres com `docker ps`, filtrá-los por nome e escolher quais colunas exibir.
- Ler o registro de um contêiner com `docker logs`, completo ou apenas as últimas linhas, e executar um programa dentro dele com `docker exec`.
- Comprovar com `docker inspect` e `docker stats` que os limites ficaram definidos, e com `ss` em quais interfaces a máquina escuta.
- Ler e resolver os dois erros de todos os dias: nome repetido e porta ocupada.
- Parar, reiniciar e apagar contêineres, deixando a máquina sem nenhum contêiner `curso-docker-` ao terminar.

## O porquê antes do como

Na Lição 0 foram examinados contêineres por dentro, para entender o que são. Agora é a vez do contrário: usá-los todos os dias sem pensar em namespaces nem em cgroups. E aqui aparece um problema que não tem nada de técnico e que causa mais dano do que muitos erros do kernel: **a desorganização**.

Um contêiner é muito fácil de criar. Basta um `docker run`. E, como não faz barulho, é muito fácil de esquecer. Ao final de uma semana de testes, acumulam-se contêineres parados ocupando disco, contêineres rodando que ocupam memória e portas, e nomes que já não podem ser reutilizados. O pior não é o disco: é que algum deles ficou escutando em todas as interfaces de rede da máquina, sem que ninguém saiba. A cena do início não foi causada por um erro raro; foi causada por três hábitos que ninguém corrigiu: publicar portas sem dizer onde, rodar sem limites e não limpar.

Esta lição fornece o conjunto completo de comandos para gerenciar um contêiner do início ao fim e, junto com cada comando, o hábito que evita a desorganização. Isso será feito com o **serviço de teste** do curso, um servidor HTTP minúsculo que falha de propósito. Ele tem três modos: em modo **sano** (saudável) responde `200` imediatamente; em modo **lento** demora três segundos e depois responde `200`; em modo **caído** (fora do ar) responde `503`, o código HTTP para «serviço indisponível». E o modo é alterado com o serviço em execução, sem reinicialização, com uma requisição `POST`. Esse serviço será, ao longo do curso, o alvo monitorado pelo `revisor`; aqui ele serve como prática segura, e tudo o que for feito com ele será repetido com o `revisor`: ao empacotá-lo na Lição 3, ele será iniciado com este mesmo tipo de comando, mudando apenas o nome, a imagem e a porta 8080. E serve para ver uma ideia que o curso repete constantemente: **o fato de um contêiner constar como «rodando» não significa que o serviço esteja saudável**.

A lição segue esta ordem:

1. **Construir a imagem** do serviço de teste (2.1), errando primeiro.
2. **Iniciar** um contêiner e entender cada parte do comando (2.2).
3. **Examiná-lo**: `ps` (2.3), consultá-lo (2.4) e ler o registro com `logs` (2.5).
4. **Entrar**, ou tentar fazê-lo, com `exec` (2.6).
5. **Inspecioná-lo** com `inspect` e `stats` (2.7).
6. **As portas**: `127.0.0.1` versus todas as interfaces (2.8), e **os limites** (2.9).
7. **O ciclo de vida**: parar, reiniciar e apagar (2.10), e **não deixar lixo** (2.11).

Este é o comando ao qual se vai chegar. Ao final da lição, cada palavra terá uma razão de ser:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

## Os conceitos

### 2.1 Construir a imagem do serviço de teste

#### 2.1.1 Primeiro, o erro

Para rodar um contêiner é preciso uma imagem. Antes de construí-la, vale a pena ver o que acontece se esse passo for ignorado, porque é um erro muito comum no dia a dia: alguém passa um comando, ele é colado no terminal e a imagem não existe na máquina. O script `fig02_01.sh` faz exatamente isso e, em seguida, constrói a imagem:

```bash
#!/usr/bin/env bash
# fig02_01.sh — Correr una imagen que todavía no existe, y después construirla.
# Primero el error (la imagen no está en tu equipo ni en Docker Hub); luego el
# único comando que necesitas para construir el servicio de prueba.
set -uo pipefail
cd "$(dirname "$0")/.."          # la carpeta programas/, donde está servicio-prueba/
IMAGEN=curso-docker-prueba:1.0.0
# Si la imagen ya existía, el bloque 1 no falla y SÍ crea un contenedor: se borra al salir.
trap 'docker rm -f curso-docker-prueba >/dev/null 2>&1 || true' EXIT

echo "== 1. Correr la imagen antes de construirla"
docker run -d --name curso-docker-prueba "$IMAGEN"
echo "código de salida: $?"

echo
echo "== 2. Construirla: un solo comando"
docker build -t "$IMAGEN" servicio-prueba
echo "código de salida: $?"

echo
echo "== 3. La imagen ya está en tu equipo"
docker image ls "$IMAGEN"

echo
echo "== 4. Y el intento fallido no dejó contenedores"
docker ps -a --filter name=curso-docker-prueba --format '{{.Names}} {{.Status}}' | wc -l
```

O script usa `set -uo pipefail` e não `set -euo pipefail` como os da Lição 0: a opção `-e` foi retirada de propósito, porque o primeiro comando **deve** falhar e queremos que o script continue. `cd "$(dirname "$0")/.."` vai para a pasta `programas/`, que é onde está `servicio-prueba/`, não importando de onde o script seja executado. E o `trap ... EXIT` agenda a remoção do contêiner ao sair: na primeira vez não há nada a apagar, mas se o script for executado com a imagem já construída, o bloco 1 não falha mais, cria o contêiner e o `trap` o remove. Esta é a primeira parte da saída:

```text
$ ./fig02_01.sh
== 1. Correr la imagen antes de construirla
Unable to find image 'curso-docker-prueba:1.0.0' locally
docker: Error response from daemon: pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'

Run 'docker run --help' for more information
código de salida: 125
```

A leitura é feita em dois tempos. A primeira linha diz que a imagem não está **na máquina local** (*locally*). Isso ainda não é um erro: quando o `docker run` não encontra uma imagem, ele a busca em um registro (*registry*), que por padrão é o Docker Hub. A documentação explica isso com a opção `--pull`, cujo valor padrão é `missing`: baixa a imagem apenas se ela ainda não estiver na máquina local ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). A segunda linha é o erro de verdade: o Docker Hub não tem um repositório público chamado `curso-docker-prueba` e nenhuma credencial foi fornecida, então o download foi negado. A mensagem não tem como saber qual das duas coisas acontece (se não existe ou se é privado), por isso menciona as duas.

O código de saída **125** também tem significado. A documentação do Docker reserva três códigos: 125 significa que o erro é do próprio daemon do Docker; 126, que o comando do contêiner não pôde ser invocado; e 127, que o comando do contêiner não foi encontrado. Qualquer outro número é o código com o qual o programa interno terminou ([Docker, “Running containers”](https://docs.docker.com/engine/containers/run/)). Aqui o contêiner nem sequer chegou a existir: a falha foi do Docker, não do serviço. Um código 127 será visto na seção 2.6.

> [!NOTE]
> 🔧 **Observação de engenharia 2.1**
> A ordem de busca tem uma consequência de segurança. Se houver um erro ao digitar o nome de uma imagem local e por acaso existir uma imagem pública com esse nome, o Docker vai baixá-la e executá-la sem pedir confirmação. O risco está sobretudo nos nomes que trazem usuário ou organização, como `alguem/imagem`, porque nesses espaços qualquer pessoa pode publicar; um nome de uma única parte, como o deste curso, é buscado entre as imagens oficiais do Docker Hub. Por isso convém que os nomes das imagens locais sejam inconfundíveis; o prefixo `curso-docker-` deste curso cumpre esse papel, além de permitir limpar apenas o que é do curso com um filtro (2.11).

#### 2.1.2 Um único comando para construí-la

O serviço de teste é entregue com a receita pronta: o arquivo `programas/servicio-prueba/Dockerfile`. Construí-lo exige apenas um comando:

```bash
docker build -t curso-docker-prueba:1.0.0 servicio-prueba
```

Ele tem duas partes. `-t curso-docker-prueba:1.0.0` define o **nome e a tag** da imagem resultante: o nome é `curso-docker-prueba` e a tag, o que vem depois dos dois pontos, é `1.0.0`. E `servicio-prueba`, no final, é a pasta que o Docker usa como **contexto**: é ali que ele procura o `Dockerfile` e de onde obtém os arquivos que a receita manda copiar. A Lição 4 é dedicada inteiramente ao contexto; aqui basta saber que se trata de uma pasta.

A saída da construção é longa; esta é a parte central (o arquivo completo está em `fig02_01.salida.txt`):

```text
== 2. Construirla: un solo comando
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 836B done
#1 DONE 0.0s
[…]
#6 [1/4] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#6 resolve docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c 0.0s done
#6 DONE 0.0s
[…]
#12 [compilacion 4/4] RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/servicio-prueba .
#12 DONE 32.9s

#13 [stage-1 2/2] COPY --from=compilacion /out/servicio-prueba /servicio-prueba
#13 DONE 0.1s

#14 exporting to image
[…]
#14 naming to docker.io/library/curso-docker-prueba:1.0.0 done
#14 unpacking to docker.io/library/curso-docker-prueba:1.0.0 0.1s done
#14 DONE 0.5s
código de salida: 0
```

Não é preciso entender cada linha hoje, mas três pontos merecem destaque. A construção ocorre em **etapas numeradas** (`#1`, `#2`…) e cada uma informa quanto tempo durou: a mais demorada, 32.9 segundos, é a que compila o programa em Go dentro de uma imagem que traz o compilador. No final aparece `naming to docker.io/library/curso-docker-prueba:1.0.0`: o nome curto fornecido é, por completo, o de uma imagem do Docker Hub na biblioteca oficial (`library`), mesmo que nunca vá ser enviada a lugar nenhum; é assim que o Docker nomeia tudo o que não traz um registro explícito. E o código de saída é **0**: tudo correu bem. As Lições 3, 4 e 5 ensinam a ler esse arquivo linha por linha.

#### 2.1.3 Encontrar a imagem

```text
== 3. La imagen ya está en tu equipo
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE                       ID             DISK USAGE   CONTENT SIZE   EXTRA
curso-docker-prueba:1.0.0   06306fe8744c   15.1MB       3.37MB

== 4. Y el intento fallido no dejó contenedores
0
```

Para quem vem de tutoriais antigos, essa tabela vai parecer diferente. A partir da versão 29.0, `docker image ls` exibe uma visualização nova por padrão, «como `--tree`, mas recolhida», e esconde as imagens sem tag a menos que se passe `--all` ([notas de versão do Docker Engine 29](https://docs.docker.com/engine/release-notes/29/)). A página de referência do comando ainda mostra as colunas anteriores (`REPOSITORY`, `TAG`, `IMAGE ID`, `CREATED`, `SIZE`) ([docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/)), portanto não é motivo de estranheza se a saída e um tutorial não coincidirem. O aviso `WARNING` da primeira linha é dado pelo próprio Docker: essa exibição foi feita para leitura humana; se a saída for processada por um script, deve-se usar `--format`, que é o que o restante da lição faz.

A coluna usada neste curso para falar do tamanho de uma imagem é **DISK USAGE**: 15.1 MB é o espaço que a imagem ocupa em disco. A coluna **CONTENT SIZE** é menor; tudo indica que conta o conteúdo comprimido da imagem, tal como viaja pela rede, mas a documentação de referência ainda não a descreve, de modo que neste curso ela não é usada para nada. Com uma formatação personalizada obtém-se diretamente o tamanho:

```bash
docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

Na saída das execuções do curso, esse comando imprimiu `curso-docker-prueba:1.0.0 15.1MB`.

O bloco 4 confirma algo importante para a limpeza: o `docker run` com falha da seção 2.1.1 **não deixou contêiner**. Como não havia imagem, não havia de onde criá-lo. Na seção 2.8 será visto um erro que de fato deixa um contêiner para trás.

### 2.2 Iniciar um contêiner

#### 2.2.1 O comando, opção por opção

Com a imagem pronta, o comando desta lição:

```bash
docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Lê-se da esquerda para a direita. Cada opção responde a uma pergunta que, se não for respondida, o Docker responde por conta própria, e quase nunca da forma mais conveniente:

| Opção | Pergunta que responde | O que acontece se for omitida |
|---|---|---|
| `-d` | devolve o controle do terminal? | o contêiner fica preso ao terminal; se a janela for fechada ou se Ctrl+C for pressionado, o sinal chega a ele |
| `--name curso-docker-prueba` | como se chama? | o Docker inventa um nome aleatório, como `busy_goldwasser`, difícil de lembrar |
| `-p 127.0.0.1:9000:9000` | quem pode falar com ele, e por qual porta? | nenhuma outra máquina, e o acesso local só ocorre pelo endereço interno do contêiner, não por `127.0.0.1`; e caso se use `-p 9000:9000` sem endereço, **qualquer pessoa na rede** |
| `--memory 64m` | quanta memória pode usar? | toda a memória da máquina |
| `--cpus 0.5` | quanta CPU? | toda |
| `--pids-limit 50` | quantos processos pode criar? | quantos quiser |
| `curso-docker-prueba:1.0.0` | a partir de qual imagem? | (obrigatório) |

`-d` é a forma curta de `--detach`: segundo a documentação, executa o contêiner em segundo plano e imprime o identificador dele ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Sem `-d`, a saída do serviço aparece no terminal e o terminal fica bloqueado até o contêiner terminar. Isso às vezes serve para um teste rápido; para um servidor, quase nunca.

`--name` atribui um nome. A documentação indica que, se o nome não for informado, o daemon gera um aleatoriamente ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Um nome próprio serve para duas coisas: para escrever `docker logs curso-docker-prueba` em vez de copiar um identificador de 64 caracteres, e para que o nome lembre a quem pertence o contêiner. Mas há uma consequência: **em um mesmo daemon não pode haver dois contêineres com o mesmo nome**, nem mesmo se um deles estiver parado. Esse é o primeiro erro da cena inicial, provocado na seção 2.8.

`-p` é a forma curta de `--publish`, e possui três partes separadas por dois-pontos: `endereço:porta-do-host:porta-do-contêiner`. `127.0.0.1:9000:9000` significa «na máquina local, apenas no endereço `127.0.0.1` e na porta 9000, receba conexões e repasse-as à porta 9000 do contêiner». Os dois números não precisam ser iguais: com `127.0.0.1:18000:9000`, a comunicação seria pela 18000 e o serviço continuaria escutando na porta 9000 dele. Convém lembrar da Lição 0 que cada contêiner tem a própria rede. Sem `-p`, a porta 9000 só é acessível a partir da rede interna do Docker: a partir dos outros contêineres dessa rede e a partir da própria máquina hospedeira, usando o endereço interno do contêiner; a documentação descreve assim: as portas dos contêineres em redes do tipo ponte (*bridge*) são acessíveis a partir do host mesmo que não sejam publicadas ([Docker, “Port publishing and mapping”](https://docs.docker.com/engine/network/port-publishing/)). O que não se alcança sem `-p` é a porta a partir de `127.0.0.1` da máquina nem a partir de qualquer outra máquina. A seção 2.8 é dedicada ao endereço, que é a parte mais importante.

`--memory`, `--cpus` e `--pids-limit` formam o orçamento que a Lição 0 ensinou a ler em `/sys/fs/cgroup`. A seção 2.9 explica o motivo desses números.

#### 2.2.2 Iniciá-lo e esperar até que responda

O script `fig02_02.sh` inicia o contêiner e faz com ele o que se faria em um dia normal. Este é o script completo; a saída é dividida nas seções 2.2 a 2.5:

```bash
#!/usr/bin/env bash
# fig02_02.sh — El servicio de prueba corriendo: arrancar, listar, consultar y leer su bitácora.
# Puerto publicado solo en 127.0.0.1 y con límites de memoria, CPU y procesos.
set -euo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

echo "== 1. Arrancar en segundo plano"
docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
# Esperar a que conteste (máximo 10 s), en vez de dormir un número fijo.
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo
echo "== 2. Lo que está corriendo"
docker ps --filter name="$NOMBRE" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== 3. Consultarlo en sus tres modos"
curl -s http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/caido
curl -s -w 'código HTTP: %{http_code}\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/lento
curl -s -w 'código HTTP: %{http_code} en %{time_total} s\n' http://127.0.0.1:9000/
curl -s -X POST http://127.0.0.1:9000/modo/sano
curl -s http://127.0.0.1:9000/modo

echo
echo "== 4. Su bitácora completa"
docker logs "$NOMBRE"

echo
echo "== 5. Solo los dos últimos renglones"
docker logs --tail 2 "$NOMBRE"
```

```text
$ ./fig02_02.sh
== 1. Arrancar en segundo plano
c516467655b6
```

A única coisa impressa por `docker run -d` é o **identificador** do contêiner, um número hexadecimal de 64 caracteres; o script o encurta para os primeiros 12 com `cut -c1-12`, que é como o Docker o exibe em quase todos os lugares. Muda a cada execução. O fato de ele aparecer significa que o contêiner foi criado e recebeu a ordem de iniciar; **não** significa que o serviço interno já esteja atendendo requisições.

Por isso a linha seguinte do script é um laço: tenta uma requisição com `curl` a cada meio segundo, até vinte vezes, e sai assim que uma responder com sucesso. `curl -f` faz o `curl` falhar se o servidor responder com erro, `-s` silencia o comando e `-o /dev/null` descarta a resposta. É melhor do que um `sleep 3` fixo por dois motivos: em um computador rápido não se espera além da conta, e em um lento não se avança antes da hora. Esse padrão vai aparecer em todos os scripts do curso que se comunicam com o serviço; onde não houver comunicação com ele, não é preciso esperar.

O `trap ... EXIT` acima é o mesmo hábito da Lição 0: aconteça o que acontecer, ao sair o script apaga o respectivo contêiner. Nos scripts desta lição ele estará sempre presente, porque a seção 2.11 transforma isso em regra.

### 2.3 Ver o que está rodando: `docker ps`

```text
== 2. Lo que está corriendo
NAMES                 IMAGE                       STATUS                            PORTS
curso-docker-prueba   curso-docker-prueba:1.0.0   Up 2 seconds (health: starting)   127.0.0.1:9000->9000/tcp
```

`docker ps` lista os contêineres. Por padrão mostra apenas **os que estão rodando**; com `-a` (`--all`) exibe também os parados ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). Essa diferença é o que esconde o lixo: um contêiner parado não aparece no `docker ps`, mas continua existindo, consome disco e retém o nome.

O script usa duas opções que vale a pena aprender desde já. `--filter name=curso-docker-prueba` mantém apenas os contêineres cujo nome contém esse texto; a documentação informa que o filtro `name` casa com «todo ou parte» do nome ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)). E `--format 'table ...'` escolhe as colunas: `{{.Names}}`, `{{.Image}}`, `{{.Status}}` e `{{.Ports}}` são campos, e a palavra `table` no início solicita cabeçalhos e colunas alinhadas. O que vai entre chaves duplas é um modelo (*template*) da linguagem Go; não é preciso saber Go para usá-lo, apenas os nomes dos campos listados na página do comando. Existem outros filtros úteis; o de estado, por exemplo, aceita `created`, `restarting`, `running`, `removing`, `paused`, `exited` e `dead` ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)).

As colunas, uma a uma:

- **NAMES** é o nome atribuído ao contêiner.
- **IMAGE**, a imagem da qual ele nasceu.
- **STATUS** indica `Up 2 seconds`: está rodando há dois segundos. E traz mais uma informação, `(health: starting)`, que merece um parágrafo próprio.
- **PORTS** indica `127.0.0.1:9000->9000/tcp`: a porta 9000 da máquina, apenas em `127.0.0.1`, encaminha para a 9000 do contêiner, via TCP.

O `(health: starting)` aparece porque o `Dockerfile` do serviço de teste traz uma instrução `HEALTHCHECK`: ela diz ao Docker para executar dentro do contêiner, a cada cinco segundos, o subcomando `servicio-prueba healthcheck`, que pergunta ao próprio serviço se ele está respondendo bem. Enquanto a primeira verificação não termina, o estado é `starting`; depois passará a `healthy` ou `unhealthy`. Hoje o objetivo é apenas lê-lo; como se escreve uma verificação de saúde (health check) e o que o Docker faz com ela é assunto da Lição 7. Mas convém notar desde já que **`Up` e o resultado da verificação de saúde são duas coisas distintas**: `Up` diz que o processo existe; a verificação de saúde diz se ele está atendendo. A seção seguinte demonstra isso.

### 2.4 Falar com o serviço

```text
== 3. Consultarlo en sus tres modos
sano
modo: caido
caido
código HTTP: 503
modo: lento
lento
código HTTP: 200 en 3.081298 s
modo: sano
modo: sano
```

Lê-se cada par de linhas como pergunta e resposta:

1. `GET /` em modo saudável responde `sano`.
2. `POST /modo/caido` altera o modo e confirma `modo: caido`. A partir desse instante, `GET /` responde o texto `caido` com o código **503**. A opção `-w` do `curl` imprime dados da requisição após a resposta; aqui, o código HTTP.
3. `POST /modo/lento` e o `GET /` seguinte leva **3.08 segundos** para responder `lento` com um 200. Os três segundos correspondem ao atraso do modo lento; o restante é o tempo de ida e volta. Esse número varia ligeiramente a cada execução; em outra execução do curso foram registrados 3.003 segundos.
4. `POST /modo/sano` restaura a normalidade, e `GET /modo` confirma.

Agora a pergunta fundamental. Enquanto o serviço respondia `503`, o que dizia o `docker ps`? Dizia `Up`. Para o Docker, o contêiner estava perfeito: o processo existia e não havia terminado. Para quem tentasse utilizá-lo, estava fora do ar. **O Docker não sabe o que o serviço responde**, a menos que isso lhe seja ensinado com uma verificação de saúde (health check). É o princípio que o curso repete a cada lição: um contêiner rodando não é garantia de serviço saudável. O `revisor`, o projeto a ser empacotado a partir da Lição 3, existe exatamente para fazer essa verificação de fora.

### 2.5 O registro: `docker logs`

```text
== 4. Su bitácora completa
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: modo cambiado a caido
servicio-prueba: GET / en modo caido
servicio-prueba: modo cambiado a lento
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano

== 5. Solo los dos últimos renglones
servicio-prueba: GET / en modo lento
servicio-prueba: modo cambiado a sano
```

Tudo o que o programa principal do contêiner escreve na **saída padrão** e na **saída de erros** (o que no terminal seria visto com `printf` ou com `echo`) é armazenado pelo Docker, e o `docker logs` devolve essas mensagens. A documentação descreve assim: o comando entrega os registros existentes no momento da execução e, com `--follow`, continua transmitindo o que de novo for enviado para o `STDOUT` e o `STDERR` do contêiner ([docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/)).

Nota-se que o registro conta a história completa da seção anterior, em ordem: a inicialização, as duas primeiras requisições (a do laço de espera e a do comando), cada mudança de modo e cada requisição com o respectivo modo. As requisições a `/modo` não deixam rastro porque o serviço não as registra; um programa só deixa no log aquilo que quem o escreveu decidiu registrar. E um aviso: a verificação de saúde da imagem (2.3) também realiza um `GET /` a cada cinco segundos, e cada uma deixa uma linha. Esta execução durou menos de cinco segundos, então nenhuma aparece; em um contêiner que passa mais tempo em execução, serão vistas linhas `GET / en modo …` que ninguém disparou manualmente. Foi o Docker quem disparou.

As opções de uso diário, todas retiradas da [página do comando](https://docs.docker.com/reference/cli/docker/container/logs/):

| Opção | O que faz |
|---|---|
| `--tail N` (ou `-n N`) | apenas as últimas N linhas; por padrão, todas |
| `--follow` (ou `-f`) | permanece escutando e exibe novidades conforme chegam; sai-se com Ctrl+C |
| `--since 10m` | apenas os registros dos últimos dez minutos; também aceita data e hora |
| `--timestamps` (ou `-t`) | adiciona no início de cada linha o horário em que o Docker a recebeu |

`--tail` importa mais do que parece. Um serviço em execução há semanas pode ter milhões de linhas, e um `docker logs` sem limites sobrecarrega o terminal. O bom hábito é rodar `docker logs --tail 50 <nome>` primeiro, e `-f` se houver necessidade de continuar acompanhando.

Dois avisos que evitam sustos. **O registro sobrevive ao `docker stop`, mas não ao `docker rm`:** ele vive com o contêiner, portanto pode ser lido após pará-lo (como será visto em 2.10) e desaparece quando o contêiner é apagado. Se um contêiner morreu de forma inesperada, **é fundamental ler o registro dele antes de apagá-lo**. E **o `docker logs` só enxerga o que o programa principal escreve em suas duas saídas**: se o programa grava o log em um arquivo dentro do contêiner, o `docker logs` não o vê. Por isso programas projetados para contêineres, como o serviço de teste e o `revisor`, escrevem tudo na saída padrão.

### 2.6 Entrar no contêiner: `docker exec`

#### 2.6.1 A imagem não traz shell

Nos tutoriais vê-se com frequência este comando: `docker exec -it <nome> sh`, «para entrar no contêiner». O `docker exec` executa um programa **dentro** de um contêiner que já está rodando; `-i` mantém a entrada padrão aberta e `-t` aloca um pseudo-terminal, para que seja possível digitar comandos ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)). Vale testar isso com o serviço de teste, que é o que o script `fig02_03.sh` faz (sem `-it`, já que em um script não há ninguém digitando):

```bash
#!/usr/bin/env bash
# fig02_03.sh — exec: ejecutar un programa dentro de un contenedor que ya corre.
# La imagen del servicio de prueba no trae shell: se ve el error y lo que sí funciona.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Pedir un shell"
docker exec "$NOMBRE" sh
echo "código de salida: $?"

echo
echo "== 2. Ejecutar un programa que la imagen SÍ trae"
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 3. Lo mismo, con el servicio en modo caído"
curl -s -X POST http://127.0.0.1:9000/modo/caido >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"

echo
echo "== 4. exec en un contenedor detenido"
docker stop "$NOMBRE" >/dev/null
docker exec "$NOMBRE" /servicio-prueba healthcheck
echo "código de salida: $?"
```

```text
$ ./fig02_03.sh
== 1. Pedir un shell
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
código de salida: 127

== 2. Ejecutar un programa que la imagen SÍ trae
sano
código de salida: 0

== 3. Lo mismo, con el servicio en modo caído
no sano: GET / respondió 503
código de salida: 1

== 4. exec en un contenedor detenido
Error response from daemon: container 78614f9ea0da425237a13924f63235bf6a1e45629efd4000d3764b5c54e23dcb is not running
código de salida: 1
```

O primeiro bloco é o erro. Lê-se da direita para a esquerda, que é como quase todos os erros do Docker são lidos: a causa fica no final. `exec: "sh": executable file not found in $PATH` diz que não existe nenhum programa chamado `sh` nas pastas onde programas são procurados. O trecho anterior, `OCI runtime exec failed`, indica quem descobriu isso: o `runc`, o programa que cria os processos dos contêineres (apresentado na Lição 0). E o código **127**, como visto em 2.1.1, é o que o Docker reserva para «o comando não foi encontrado».

Não se trata de uma falha do contêiner: é uma decisão de projeto. A imagem do serviço de teste foi construída sobre uma base mínima, das chamadas *distroless*, que **traz apenas o programa e o estritamente indispensável para que ele rode**: não traz `sh`, nem `ls`, nem `cat`, nem gerenciador de pacotes. Isso tem um preço, que acaba de ser pago: não dá para «entrar» e bisbilhotar. E tem uma vantagem, que a Lição 5 aproveita para o `revisor`: se alguém conseguisse executar algo dentro desse contêiner, não encontraria ferramentas para prosseguir. Uma imagem sem shell é uma imagem com menos recursos para um ataque.

#### 2.6.2 O que de fato é possível fazer

O segundo bloco mostra que o `exec` funciona perfeitamente com um programa que a imagem **de fato** traz: o próprio `/servicio-prueba`, com o subcomando `healthcheck`. O programa pergunta ao serviço que roda ao lado dele se está respondendo, imprime `sano` e termina com 0. O terceiro bloco repete a pergunta com o serviço em modo fora do ar: `no sano: GET / respondió 503`, e sai com código 1. Esse subcomando é o mesmo que a instrução `HEALTHCHECK` executa a cada cinco segundos; acabou de ser executado manualmente. Observe que aqui o código não é 127, mas 1: o programa foi de fato encontrado e executado; simplesmente respondeu «não».

Duas regras de `exec` que vêm da documentação do comando ([docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/)):

- **Só funciona enquanto o processo principal do contêiner estiver rodando.** É o quarto bloco: com o contêiner parado, o daemon responde `container ... is not running`. Para verificar o que aconteceu com um contêiner parado não se usa `exec`, usam-se `logs` e `inspect`.
- **O comando precisa ser um executável**, não uma linha de shell. `docker exec <nome> "echo ola && ls"` não funciona; se a imagem tiver shell, escreve-se `docker exec <nome> sh -c 'echo ola && ls'`.

Quando a imagem traz shell, como a `alpine:3.24.2` da Lição 0, o comando famoso funciona e permite digitar comandos lá dentro:

```bash
docker run -d --name curso-docker-dormilon --memory 16m --cpus 0.25 --pids-limit 20 \
  alpine:3.24.2 sleep 300
docker exec -it curso-docker-dormilon sh
```

Use isso para **olhar**, nunca para **consertar**. Isso foi aprendido na Lição 0: o que for alterado lá dentro vive na camada do contêiner e vai embora com ele. E apague o contêiner ao terminar: `docker rm -f curso-docker-dormilon`.

### 2.7 O que o Docker sabe de um contêiner: `inspect` e `stats`

#### 2.7.1 `docker inspect` com um modelo

`docker inspect` retorna «informações de baixo nível» sobre um objeto do Docker ([docker inspect](https://docs.docker.com/reference/cli/docker/inspect/)): tudo o que o daemon sabe a respeito dele, em JSON. É bastante coisa. O script `fig02_04.sh` o utiliza com modelos para extrair apenas o que interessa, e compara o contêiner com limites com outro idêntico sem limites:

```bash
#!/usr/bin/env bash
# fig02_04.sh — inspect y stats: lo que Docker sabe de un contenedor, con y sin límites.
set -euo pipefail
CON=curso-docker-prueba
SIN=curso-docker-sin-limites
trap 'docker rm -f "$CON" "$SIN" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$CON" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name "$SIN" curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

FORMATO='{{.Name}}: memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}'

echo "== 1. inspect, con una plantilla: solo los campos que me importan"
docker inspect --format "$FORMATO" "$CON" "$SIN"

echo
echo "== 2. inspect: estado, puerto publicado y comando principal"
docker inspect --format 'estado={{.State.Status}} pid1={{.Config.Entrypoint}} puertos={{json .HostConfig.PortBindings}}' "$CON"

echo
echo "== 3. stats: lo que gastan ahora mismo, contra su límite"
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.PIDs}}' "$CON" "$SIN"

echo
echo "== 4. Cuántos renglones trae inspect completo"
docker inspect "$CON" | wc -l
```

```text
$ ./fig02_04.sh
== 1. inspect, con una plantilla: solo los campos que me importan
/curso-docker-prueba: memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532
/curso-docker-sin-limites: memoria=0 cpus(nano)=0 pids=<no value> usuario=65532:65532

== 2. inspect: estado, puerto publicado y comando principal
estado=running pid1=[/servicio-prueba] puertos={"9000/tcp":[{"HostIp":"127.0.0.1","HostPort":"9000"}]}

== 3. stats: lo que gastan ahora mismo, contra su límite
NAME                       MEM USAGE / LIMIT     PIDS
curso-docker-prueba        1.59MiB / 64MiB       8
curso-docker-sin-limites   1.496MiB / 15.59GiB   7

== 4. Cuántos renglones trae inspect completo
224
```

Todo o primeiro bloco é estável: esses números saem iguais no Mint. Leia-os:

- `memoria=67108864` são 64 × 1024 × 1024 bytes: os 64 MiB solicitados, o mesmo número que a Lição 0 leu em `memory.max`.
- `cpus(nano)=500000000`: o Docker armazena a CPU em bilionésimos de CPU; 500 milhões equivalem a meia CPU.
- `pids=50`, o teto de processos.
- `usuario=65532:65532`: o serviço **não roda como `root`**. Isso foi determinado pela imagem, com uma instrução `USER` que a Lição 3 ensina a escrever. Compare com o `sleep` da Lição 0, que rodava como usuário 0.

E a linha do contêiner sem limites indica `memoria=0`, `cpus(nano)=0` e `pids=<no value>`. Nesse campo, **zero não significa «nada de memória»: significa «sem limite»**. É a forma como o Docker registra «nenhum limite foi solicitado». `<no value>` é o que o modelo imprime quando o campo nem sequer existe. Ao analisar um contêiner de terceiros, um zero aqui é sinal de alerta, não de tranquilidade.

O nome aparece com uma barra na frente, `/curso-docker-prueba`. Não é um erro: é assim que o Docker armazena os nomes internamente, e por isso a mensagem de nome repetido da seção 2.8 também traz essa barra.

O segundo bloco exibe outros três campos. `.State.Status` é o estado (`running`). `.Config.Entrypoint` é o programa que a imagem inicia como processo principal. E `{{json .HostConfig.PortBindings}}` usa a função `json` dos modelos para imprimir um campo composto exatamente como está: a porta 9000 do contêiner está vinculada ao endereço `127.0.0.1`, porta 9000, da máquina hospedeira.

O quarto bloco explica por que se usam modelos: o `inspect` completo desse contêiner, que é dos mais simples, tem **224 linhas**. Lê-lo por inteiro é útil uma vez, para conhecer o conteúdo. Para consultar algo pontual, usa-se modelo.

#### 2.7.2 `docker stats`: o consumo no momento

`inspect` informa quais são os limites; `docker stats` diz **quanto está sendo consumido**. Por padrão é uma tela com atualização contínua, semelhante ao `top`; com `--no-stream` faz uma única leitura e termina, que é o que um script precisa ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)). A coluna **MEM USAGE / LIMIT** mostra a memória que o contêiner usa em relação ao teto permitido, e **PIDS** quantos processos e threads foram criados ([docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/)).

O serviço de teste usa entre 1 e 2 MiB e tem algumas threads (8 nesta execução, 6 em outra; o número varia). O relevante é a coluna do limite. Com limites, indica `64MiB`. Sem limites, mostra `15.59GiB`, que é **toda a memória da máquina** onde foi executado (a máquina virtual do Colima). No Mint, esse número corresponderá à memória total do computador. É o cenário da Lição 0 visto a partir do Docker: um contêiner sem limite tem como limite o computador inteiro.

### 2.8 As portas: `127.0.0.1` versus todas as interfaces

#### 2.8.1 O que significa o endereço

O computador tem várias **interfaces de rede**, que funcionam como portas por onde entram conexões: a da rede sem fio, talvez a do cabo de rede, e uma especial chamada ***loopback***, com o endereço `127.0.0.1`. A interface de *loopback* não leva a lugar nenhum fora da própria máquina: o que entra por ali só pode vir do próprio computador.

Quando se publica uma porta sem endereço, com `-p 9000:9000`, o Docker a publica **em todas as interfaces**. A documentação afirma com clareza: se nenhum endereço for fornecido, o daemon publica as portas em todos os endereços do host, `0.0.0.0` e `[::]`, e adverte em um quadro de destaque que «publicar portas de um contêiner é inseguro por padrão», porque a porta fica ao alcance não apenas do host, mas «do mundo exterior» ([Docker, “Port publishing and mapping”](https://docs.docker.com/engine/network/port-publishing/)). Com `127.0.0.1` na frente, «apenas o host pode acessar» a porta publicada (mesma fonte). Isso vale a partir do Docker 28: a mesma página alerta que, em versões anteriores à 28.0.0, máquinas no mesmo segmento de rede podiam alcançar as portas publicadas em `127.0.0.1`. É mais um motivo para instalar o Docker a partir do repositório oficial, como na Lição 1, e não uma versão antiga.

O script `fig02_05.sh` inicia duas cópias do serviço, uma de cada forma, e pergunta ao Docker e ao sistema operacional onde elas ficaram:

```bash
#!/usr/bin/env bash
# fig02_05.sh — Publicar en 127.0.0.1 contra publicar en todas las interfaces.
# Se corre en el anfitrión (tu Mint): ss lista los puertos en los que escucha el equipo.
set -euo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-abierto >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
docker run -d --name curso-docker-abierto -p 9001:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for p in 9000 9001; do
  for _ in $(seq 20); do curl -fs -o /dev/null "http://127.0.0.1:$p/" && break; sleep 0.5; done
done

echo "== 1. Lo que dice docker port"
echo "-- curso-docker-prueba:"; docker port curso-docker-prueba
echo "-- curso-docker-abierto:"; docker port curso-docker-abierto

echo
echo "== 2. Lo que dice el sistema operativo: dónde escucha el equipo"
ss -ltn | grep -E ':900[01] ' | awk '{print $4}' | sort
```

```text
$ ./fig02_05.sh
== 1. Lo que dice docker port
-- curso-docker-prueba:
9000/tcp -> 127.0.0.1:9000
-- curso-docker-abierto:
9000/tcp -> 0.0.0.0:9001
9000/tcp -> [::]:9001

== 2. Lo que dice el sistema operativo: dónde escucha el equipo
0.0.0.0:9001
127.0.0.1:9000
[::]:9001
```

`docker port` mostra, para um contêiner, qual porta dele vai para qual endereço e porta da máquina hospedeira. `ss -ltn` é uma ferramenta padrão do Linux que lista as portas onde a máquina escuta conexões TCP (`-l` escutando, `-t` TCP, `-n` com números em vez de nomes); o `grep` filtra apenas as linhas das portas 9000 e 9001, e o `awk` seleciona a coluna do endereço.

As duas fontes dizem a mesma coisa. O contêiner publicado corretamente escuta **apenas** em `127.0.0.1:9000`. O outro escuta em `0.0.0.0:9001`, que no jargão de redes significa «em todos os endereços IPv4 desta máquina», e em `[::]:9001`, o equivalente para IPv6. Se o Mint estiver conectado à rede de uma cafeteria, de uma universidade ou de um escritório, qualquer pessoa nessa rede pode digitar o endereço do computador e a porta 9001 e falar com o contêiner. O serviço de teste é inofensivo; um banco de dados de testes com senha de exemplo, não.

#### 2.8.2 O firewall não salva ninguém

Pode-se pensar que para isso existe um firewall. No Mint, o firewall de desktop é o `ufw`. Aqui está a armadilha: **as portas publicadas pelo Docker passam por cima das regras do `ufw`**. A referência do `docker run` alerta para isso: portas publicadas em todas as interfaces ficam acessíveis externamente mesmo que o `ufw` esteja configurado para bloqueá-las, porque o Docker gerencia as regras de filtragem de pacotes dele ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). O guia de firewall do Docker explica o mecanismo: o tráfego de um contêiner «é desviado antes de passar pela configuração do `ufw`» e os pacotes são roteados «antes que as regras do firewall possam ser aplicadas» ([Docker, “Packet filtering and firewalls”](https://docs.docker.com/engine/network/packet-filtering-firewalls/)).

Não teste isso em uma rede alheia sem autorização. Basta ter ciência do fato e da conclusão: **a proteção está no `-p`, não no firewall**. Por isso, neste curso, todas as portas são publicadas com `127.0.0.1:` na frente, e a única que não traz esse prefixo é a `9001` deste script, criada unicamente para demonstração e apagada logo em seguida.

> [!NOTE]
> 🔧 **Observação de engenharia 2.2**
> Uma porta publicada a mais não avisa. Não existe nenhuma mensagem que diga «este contêiner ficou aberto para a rede local». A única forma de saber é perguntando: `docker ps` na coluna PORTS (procure `0.0.0.0` ou `[::]`) ou `ss -ltn` na máquina. Crie o hábito de verificar isso sempre que houver conexão com uma rede que não seja confiável.

### 2.9 Os limites: memória, CPU e processos

A Lição 0 mostrou o que os limites fazem por dentro: o Docker escreve um número em um arquivo do kernel e o kernel o impõe. Aqui a questão é prática: **quais números definir**.

A documentação do Docker é explícita sobre o que acontece se nenhum limite for imposto: um contêiner «não tem restrições de recursos» e consome tudo o que o escalonador do kernel permitir; e quando a máquina fica sem memória, o kernel começa a matar processos (qualquer processo, incluindo o próprio Docker), o que «pode derrubar o sistema inteiro se o processo errado for morto» ([Docker, “Resource constraints”](https://docs.docker.com/engine/containers/resource_constraints/)). Os três limites do comando desta lição:

**`--memory 64m`.** O serviço de teste consome entre 1 e 2 MiB (medido em 2.7.2). 64 MiB oferecem uma margem de mais de trinta vezes. A regra geral é essa: **meça primeiro e defina um limite folgado acima do medido**, nunca abaixo. Se o programa ultrapassar o limite, o kernel o encerra dentro do próprio cgroup, como visto na Lição 0 (código 137 e `OOMKilled=true`), sem que mais ninguém na máquina seja afetado. A documentação estipula um mínimo de 6 MB para essa opção ([Docker, “Resource constraints”](https://docs.docker.com/engine/containers/resource_constraints/)).

**`--cpus 0.5`.** Meia CPU. Um serviço que apenas atende a requisições pequenas não precisa de mais do que isso, e se entrar em um laço infinito por algum erro, consumirá meia CPU e não o processador inteiro. A documentação explica com um exemplo próprio: em um computador com duas CPUs, `--cpus="1.5"` garante ao contêiner no máximo uma CPU e meia ([Docker, “Resource constraints”](https://docs.docker.com/engine/containers/resource_constraints/)). Diferentemente da memória, ultrapassar a CPU não mata ninguém: o kernel simplesmente concede menos tempo de execução, e o programa fica mais lento.

**`--pids-limit 50`.** Ajusta o teto de processos do contêiner; com `-1` o limite é removido ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). Esse limite protege contra algo bem específico: um programa que, por falha ou ataque, cria processos descontroladamente. Sem teto, ele pode esgotar a tabela de processos da máquina e impedir até mesmo a abertura de um novo terminal. O serviço tinha 8 (2.7.2); 50 é mais do que suficiente.

Observe que os três limites são definidos **desde o primeiro contêiner**, não «quando o serviço for para a produção». A Lição 0 destacou isso com a cena do banco de dados: o limite não serve para o dia normal, serve para o dia ruim, e o dia ruim não avisa quando chega.

### 2.10 O ciclo de vida: parar, reiniciar e apagar

#### 2.10.1 Os estados

Um contêiner passa por estados, e cada comando o move de um para outro:

| Estado | Como chega lá | O que se vê em `docker ps -a` |
|---|---|---|
| criado (`created`) | `docker create`, ou um `docker run` que não conseguiu iniciar | `Created` |
| rodando (`running`) | `docker run` ou `docker start` | `Up …` |
| parado (`exited`) | `docker stop`, ou o programa principal terminou sozinho | `Exited (código) …` |
| apagado | `docker rm` | não aparece mais |

O ponto mais importante da tabela é a diferença entre **parado** e **apagado**. Um contêiner parado não executa, mas existe: conserva a camada de escrita, os registros, a configuração e o respectivo nome. Ele pode ser iniciado novamente. Um contêiner apagado não existe mais, e com ele vão embora a camada e os registros dele.

O script `fig02_07.sh` percorre o ciclo completo e conclui com a verificação de limpeza:

```bash
#!/usr/bin/env bash
# fig02_07.sh — El ciclo de vida completo y la limpieza: stop, start, rm y --rm.
set -uo pipefail
NOMBRE=curso-docker-prueba
trap 'docker rm -f "$NOMBRE" curso-docker-efimero >/dev/null 2>&1 || true' EXIT
ms() { date +%s%3N; }

docker run -d --name "$NOMBRE" -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done

echo "== 1. Borrar un contenedor que está corriendo, sin -f"
docker rm "$NOMBRE"
echo "código de salida: $?"

echo
echo "== 2. Detenerlo, midiendo cuánto tarda"
inicio=$(ms); docker stop "$NOMBRE" >/dev/null; fin=$(ms)
echo "docker stop tardó $(( fin - inicio )) ms"
docker ps -a --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'
docker logs --tail 2 "$NOMBRE"

echo
echo "== 3. Detenido no es borrado: vuelve a arrancar con start"
docker start "$NOMBRE" >/dev/null
docker ps --filter name="$NOMBRE" --format '{{.Names}} {{.Status}}'

echo
echo "== 4. Ahora sí: borrarlo"
docker stop "$NOMBRE" >/dev/null
docker rm "$NOMBRE"

echo
echo "== 5. Un contenedor con --rm se borra solo al terminar"
# Lo que va después de la imagen reemplaza al comando por omisión: aquí, en vez
# de servir, el programa corre su subcomando healthcheck y termina.
docker run --rm --name curso-docker-efimero curso-docker-prueba:1.0.0 healthcheck
echo "código de salida: $?"
docker ps -a --filter name=curso-docker-efimero --format '{{.Names}}' | wc -l

echo
echo "== 6. La revisión final: ningún contenedor del curso"
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

```text
$ ./fig02_07.sh
== 1. Borrar un contenedor que está corriendo, sin -f
Error response from daemon: cannot remove container "curso-docker-prueba": container is running: stop the container before removing or force remove
código de salida: 1

== 2. Detenerlo, midiendo cuánto tarda
docker stop tardó 242 ms
curso-docker-prueba Exited (0) Less than a second ago
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando

== 3. Detenido no es borrado: vuelve a arrancar con start
curso-docker-prueba Up Less than a second (health: starting)

== 4. Ahora sí: borrarlo
curso-docker-prueba

== 5. Un contenedor con --rm se borra solo al terminar
no sano: Get "http://127.0.0.1:9000/": dial tcp 127.0.0.1:9000: connect: connection refused
código de salida: 1
0

== 6. La revisión final: ningún contenedor del curso
0
```

Os tempos variam em cada execução; tudo o mais sai idêntico.

#### 2.10.2 `docker rm` não apaga o que está rodando

O primeiro bloco traz uma proteção: o Docker não permite apagar um contêiner em execução. A mensagem dá duas saídas: pará-lo antes (*stop the container before removing*) ou forçar a remoção (*force remove*). Forçar é `docker rm -f`, e a documentação explica o que acontece: envia `SIGKILL` ao processo principal e depois apaga o contêiner ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)). `SIGKILL` é o sinal 9, aquele que a Lição 0 ensinou a reconhecer no código 137: não pode ser capturado, de modo que o programa não tem oportunidade de fechar nada. Para um contêiner de teste que será descartado, não há problema, e os `trap` destes scripts fazem uso disso. Para um serviço com dados, primeiro `stop`.

#### 2.10.3 `docker stop`: o sinal e o prazo

`docker stop` é o método educado. A documentação indica que ele envia ao processo principal o sinal `SIGTERM` (a menos que a imagem ou o contêiner configurem outro), aguarda um prazo (por padrão, **10 segundos** no Linux) e, se o contêiner continuar vivo, mata-o com `SIGKILL`. Esse prazo pode ser modificado com `--timeout` ([docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/)).

O segundo bloco demonstra que o serviço de teste encerra de forma correta. `docker stop` demorou **242 ms**, muito menos que os 10 segundos de tolerância (em outra execução do curso foram 120 ms, e em outra, 199 ms). O estado é `Exited (0)`: o programa terminou por conta própria e com código 0, que no Linux indica sucesso. E o registro, que continua disponível após a parada, mostra a razão: `recibí terminated, apagando`. O serviço foi programado para tratar o sinal `SIGTERM` (*terminated* é como Go nomeia esse sinal): ele o recebe, para de aceitar requisições e encerra. Se o programa ignorasse o sinal, veríamos `docker stop` demorar 10 segundos e o estado final seria `Exited (137)`. Por que um programa às vezes não recebe o sinal, mesmo tendo sido escrito para tratá-lo, é um problema real com nome próprio (o problema do processo número 1), e a Lição 7 trata disso.

#### 2.10.4 `docker start`: parado não é apagado

O terceiro bloco inicia novamente o mesmo contêiner com `docker start`. Não é necessário repetir as opções: o nome, a porta e os limites ficaram salvos no contêiner. `docker start` serve para retomar algo que foi parado; para mudar uma opção (outra porta, outro limite) é preciso apagar o contêiner e criar um novo com `docker run`. O quarto bloco realiza a limpeza em ordem: `stop` e depois `rm`, que imprime o nome do que foi apagado.

#### 2.10.5 `--rm`: contêineres que se apagam sozinhos

Para contêineres que apenas executam uma tarefa e terminam, existe o `--rm`: segundo a documentação, ele apaga o contêiner e os volumes anônimos dele automaticamente assim que a execução termina (os volumes são tema da Lição 8) ([docker container run](https://docs.docker.com/reference/cli/docker/container/run/)). O quinto bloco faz uso dele com um detalhe novo: após o nome da imagem, vem a palavra `healthcheck`. **O que se digita depois da imagem é passado como argumento para o programa principal**, e aqui isso transforma o serviço no próprio cliente: em vez de servir, executa a verificação de saúde e encerra. Como dentro daquele contêiner ninguém está escutando na porta 9000, a verificação falha com `connection refused` e código 1. E o `0` seguinte confirma que o contêiner já não existe: `--rm` o apagou.

Um detalhe verificado na escrita desta lição: com `docker run -d --rm`, a remoção ocorre **uma fração de segundo depois** de o contêiner parar, e não antes de o `docker stop` retornar. Em uma versão inicial deste script, que executava `docker stop` em um contêiner `-d --rm` e fazia a contagem imediatamente, o resultado foi `1`: o contêiner parado ainda estava ali por alguns milissegundos. Por isso o script utiliza a forma sem `-d`, na qual o `docker run` só retorna depois que o contêiner terminou e foi removido. Caso algum script passe a contar contêineres logo após parar um com `--rm`, já se sabe de onde vem o número a mais.

### 2.11 Não deixar lixo

#### 2.11.1 Apenas o que é do curso

O sexto bloco de `fig02_07.sh` é a verificação a ser feita ao final de cada lição do curso:

```bash
docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l
```

`-a` inclui os parados, que são os que costumam ser esquecidos. O filtro `name=^curso-docker-` mantém apenas os contêineres cujo nome **começa** com `curso-docker-`: o caractere `^` marca o início do nome. A documentação apenas menciona que o filtro faz correspondência com todo ou parte do nome, então isso foi testado na elaboração desta lição: em uma máquina com dez contêineres cujos nomes continham `dev-` no meio, `--filter name=dev-` encontrou todos os dez e `--filter name='^dev'` não encontrou nenhum. Sem o `^`, um filtro por `curso-docker-` também capturaria um contêiner chamado, por exemplo, `velho-curso-docker-x`. E `wc -l` conta as linhas. Se o resultado for `0`, nada foi deixado para trás.

Para **apagar** tudo o que pertence ao curso de uma só vez, a mesma lista serve de entrada para o `docker rm -f`:

```bash
docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f
```

`-q` solicita apenas os identificadores ([docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/)), `xargs` os repassa como argumentos ao comando seguinte, e `-r` faz com que o `xargs` não execute nada caso a lista esteja vazia.

Esse é o motivo principal da regra do curso de que **tudo o que for criado comece com `curso-docker-`**: isso permite limpar apenas o que é do curso sem afetar nada mais na máquina.

#### 2.11.2 O comando que não se deve usar às cegas

Mais cedo ou mais tarde alguém vai sugerir em um tutorial o comando `docker container prune`. Ele faz exatamente o que a documentação diz: «apaga **todos** os contêineres parados» ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). Todos: os do curso, os de outros projetos na mesma máquina e os de qualquer ferramenta que utilize o Docker nos bastidores. Um contêiner parado pode ser o banco de dados de outro projeto deixado desligado de propósito, com as configurações dele preservadas. O `prune` não pergunta de quem é; faz uma única pergunta («tem certeza?»), e com `--force` nem isso. Aceita filtros por rótulo (*label*) e por tempo de criação, mas não por nome ([docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/)). A própria documentação do `docker rm` o recomenda para apagar todos os parados ([docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/)); isso faz sentido em uma máquina dedicada a uma única tarefa. No computador de uso geral, prefira o filtro por nome: apague apenas o que se sabe que é do curso. O mesmo raciocínio se aplica aos comandos correlatos `docker system prune` e `docker volume prune`, que apagam ainda mais coisas.

> [!NOTE]
> 🔧 **Observação de engenharia 2.3**
> Limpar não é uma etapa a ser feita «no final, se sobrar tempo». Nos scripts desta lição, a limpeza é programada **antes** de criar qualquer coisa, com `trap ... EXIT`, para que aconteça mesmo se o script falhar no meio do caminho. É a mesma mentalidade para o trabalho diário: defina como algo será apagado no momento em que for criado, não depois.

## O erro que se vai ver

São dois, aqueles da cena do início, e ambos são provocados por `fig02_06.sh`:

```bash
#!/usr/bin/env bash
# fig02_06.sh — Los dos errores de todos los días: nombre repetido y puerto ocupado.
# Ojo con el segundo: el contenedor que falla SÍ queda creado.
set -uo pipefail
trap 'docker rm -f curso-docker-prueba curso-docker-otro >/dev/null 2>&1 || true' EXIT

docker run -d --name curso-docker-prueba -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 >/dev/null

echo "== 1. Otro contenedor con el MISMO nombre"
docker run -d --name curso-docker-prueba curso-docker-prueba:1.0.0
echo "código de salida: $?"

echo
echo "== 2. Otro contenedor en el MISMO puerto"
docker run -d --name curso-docker-otro -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0 | cut -c1-12
echo "código de salida: ${PIPESTATUS[0]}"

echo
echo "== 3. ¿Qué quedó?"
docker ps -a --filter name='^curso-docker-' --format 'table {{.Names}}\t{{.Status}}'
```

```text
$ ./fig02_06.sh
== 1. Otro contenedor con el MISMO nombre
docker: Error response from daemon: Conflict. The container name "/curso-docker-prueba" is already in use by container "c0117bd0d82f44831263964f4f0c3e80262188eee2be39287f270aef5b82cc4d". You have to remove (or rename) that container to be able to reuse that name.

Run 'docker run --help' for more information
código de salida: 125

== 2. Otro contenedor en el MISMO puerto
docker: Error response from daemon: failed to set up container networking: driver failed programming external connectivity on endpoint curso-docker-otro (482400ed3eb7fd3dab4753f6c5bf95038ed4b93f2b80fd70c3ac301e5f8059c2): Bind for 127.0.0.1:9000 failed: port is already allocated

Run 'docker run --help' for more information
1dad19130213
código de salida: 125

== 3. ¿Qué quedó?
NAMES                 STATUS
curso-docker-otro     Created
curso-docker-prueba   Up Less than a second (health: starting)
```

Os identificadores longos mudam a cada execução; as mensagens e os códigos saem idênticos. `${PIPESTATUS[0]}` é uma variável do *bash* que armazena o código de saída do **primeiro** comando de um encadeamento (*pipe*); ela é necessária porque `$?` devolveria o código do `cut`.

**O nome repetido.** A mensagem diz tudo: há um conflito (*Conflict*), o nome `/curso-docker-prueba` já está em uso pelo contêiner de tal identificador, e para reutilizar o nome é preciso remover ou renomear esse contêiner. Código **125**: a falha foi do Docker, não do serviço. A pegadinha é que o contêiner que retém o nome **pode estar parado**: não aparece em `docker ps`, apenas em `docker ps -a`. A solução, em ordem de preferência: se o antigo não serve mais, `docker rm` (ou `docker rm -f` se estiver rodando); se a intenção for preservá-lo, `docker rename <antigo> <novo>`; ou utilize outro nome para o novo.

**A porta ocupada.** Lê-se da direita para a esquerda: a causa é `port is already allocated`, a porta já está alocada; a tentativa foi `Bind for 127.0.0.1:9000`, vincular-se a esse endereço e porta; e quem tentava era a configuração de rede do contêiner `curso-docker-otro`. Novamente **125**. Para saber quem está ocupando a porta, consulte `docker ps` na coluna PORTS; se não for um contêiner, `ss -ltnp` mostra qual programa da máquina a está usando (o `p` solicita o processo; para ver processos de outros usuários é necessário `sudo`). A solução: parar quem está ocupando a porta, ou publicar o contêiner em outra porta do host (`-p 127.0.0.1:9002:9000`), o que não altera nada dentro do contêiner.

**E o detalhe que quase ninguém conta.** Repare no `1dad19130213` exibido após o erro de porta: é o identificador de um contêiner. O `docker run -d` o imprimiu porque **o contêiner de fato foi criado**; o que falhou foi inicializá-lo. O terceiro bloco confirma: `curso-docker-otro` permaneceu em estado `Created`. Não está rodando, não gasta memória, mas **retém o nome**. Se a porta for corrigida e o comando for repetido com o mesmo nome, o próximo erro a aparecer será o de nome repetido, dando a falsa impressão de que o Docker enlouqueceu. Na verdade, são dois erros em cadeia. Após um erro de «porta ocupada», apague o contêiner residual: `docker rm curso-docker-otro`. E não tente resgatá-lo com `docker start` quando a porta for liberada: o exercício 1 mostra o que acontece.

O erro de nome repetido com um contêiner **parado** e o de porta com o respectivo contêiner fantasma compõem, juntos, o cenário da cena inicial. Com `docker ps -a` e o filtro da seção 2.11, tudo se resolve em dez segundos.

## O hábito de segurança da lição

**Portas publicadas apenas em `127.0.0.1`, limites desde o primeiro contêiner, e nunca `--privileged` nem o *socket* do Docker dentro de um contêiner.**

Os dois primeiros já foram praticados. Publicar em `127.0.0.1` impede que um contêiner de testes fique ao alcance de qualquer pessoa na rede local, e o firewall não oferece proteção (2.8). Os limites evitam que um erro em um contêiner derrube os demais programas da máquina (2.9).

O terceiro é mencionado aqui porque em tutoriais do dia a dia encontram-se comandos que violam esse princípio, e convém reconhecê-los antes de colá-los no terminal. A Lição 0 ensinou que `--privileged` concede ao contêiner todas as capacidades do Linux e acesso aos dispositivos do host ([Docker, “Running containers”](https://docs.docker.com/engine/containers/run/)): quase nenhuma barreira permanece de pé. E ensinou também que o daemon roda como `root` e que apenas usuários de confiança devem ter permissão para controlá-lo ([Docker Engine security](https://docs.docker.com/engine/security/)), a ponto de o grupo `docker` equivaler a `root` ([Docker, passos posteriores à instalação no Linux](https://docs.docker.com/engine/install/linux-postinstall/)). Montar o *socket* dentro de um contêiner (em tutoriais isso costuma aparecer como `-v /var/run/docker.sock:/var/run/docker.sock`) concede a esse contêiner exatamente esse poder: ele pode pedir ao daemon que crie outro contêiner com a pasta raiz da máquina hospedeira montada, rodando como `root`. Se um comando a ser copiado trouxer qualquer uma dessas duas opções, pare e avalie se isso é realmente indispensável. Neste curso, nunca.

## O que se faz errado

**Publicar portas sem endereço, «porque o exemplo veio assim».** `-p 9000:9000` publica em todas as interfaces, e o `ufw` não bloqueia isso. Escreva sempre `-p 127.0.0.1:9000:9000` e, quando realmente for necessário que outra máquina acesse o contêiner, faça isso de forma deliberada.

**Rodar sem limites «porque é só um teste».** Os testes são justamente onde os programas apresentam falhas. `--memory`, `--cpus` e `--pids-limit` custam apenas uma linha.

**Interpretar `Up` como «está funcionando».** `Up` indica apenas que o processo existe. Isso foi demonstrado em 2.4: o serviço respondia `503` e o Docker continuava dizendo `Up`. Para saber se o serviço atende de fato, consulte o próprio serviço.

**Olhar apenas `docker ps`.** Sem `-a`, não se veem os contêineres parados, que são justamente os que retêm nomes e espaço em disco. Para examinar a máquina, use `docker ps -a`.

**Usar `docker exec` para consertar.** Tudo o que for alterado ali se perde com o contêiner. Além disso, em imagens mínimas, como a do serviço de teste, nem sequer existe shell, e é ótimo que seja assim.

**Usar `docker rm -f` por impulso.** Esse comando mata o processo com `SIGKILL`, sem permitir que o programa encerre de forma limpa o que estiver aberto. Para o que envolve dados, execute primeiro `docker stop`.

**Apagar um contêiner que falhou sem ler o registro dele.** O registro vai embora junto com o contêiner. Primeiro execute `docker logs --tail 50`, depois `rm`.

**Limpar com `prune` em uma máquina compartilhada.** Isso apaga o trabalho de todo mundo. Filtre pelo prefixo adotado.

**Deixar o contêiner fantasma da porta ocupada.** Ele permanece em `Created` retendo o nome; apague-o antes de tentar novamente.

## Exercícios

Os exercícios 1 e 4 são de raciocínio; o 2 e o 3 são executados no Mint. Registre as previsões no [diário de bordo](bitacora.md) antes de consultar as soluções.

### Exercício 1 — Prever o `docker ps -a`

Parte-se de uma máquina sem contêineres `curso-docker-`. Executa-se o seguinte, em ordem:

```bash
docker run -d --name curso-docker-a -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-b -p 127.0.0.1:9000:9000 curso-docker-prueba:1.0.0
docker stop curso-docker-a
docker run --rm --name curso-docker-c curso-docker-prueba:1.0.0 healthcheck
```

Estes comandos foram apresentados sem os limites para caber na página e facilitar a leitura da sequência; na máquina local, adicione `--memory 64m --cpus 0.5 --pids-limit 50`, o que não altera as respostas.

1. Quais dos quatro comandos terminam com erro, e com qual código?
2. Quais contêineres aparecem em `docker ps -a --filter name=^curso-docker-`, e em qual estado?
3. Se agora for executado `docker start curso-docker-b`, ele inicia? Por quê?
4. Quais dois comandos deixam a máquina completamente limpa?

### Exercício 2 — Outra porta, outro orçamento

Inicie o serviço de teste com estas condições: nome `curso-docker-ejercicio`, comunicação pela porta **9002** da máquina (apenas a partir da própria máquina), e com **32 MiB** de memória, um quarto de CPU e no máximo 20 processos. Em seguida:

1. Comprove com `curl` que ele responde `sano` na porta 9002.
2. Preveja o que dirão `memoria=` e `cpus(nano)=` com o modelo de `fig02_04.sh`, e comprove.
3. Preveja o que `docker stats --no-stream` exibirá na coluna do limite de memória.
4. Mude-o para o modo fora do ar e comprove que o `docker ps` continua indicando `Up`.
5. Deixe tudo limpo.

### Exercício 3 — O registro como evidência (projeto)

Imagine que o `revisor` indicou às 10:04 que o serviço de teste estava fora do ar, e deseja-se verificar isso sem depender do `revisor`. Inicie o serviço de teste, faça três requisições em modo saudável, mude para o modo fora do ar, faça mais duas requisições e volte ao modo saudável. Depois, usando **apenas** `docker logs` e suas opções:

1. Exiba apenas as últimas três linhas.
2. Exiba o registro com o horário de cada linha.
3. Exiba apenas as informações do último minuto.
4. Pare o contêiner e demonstre que o registro continua ali. Apague-o e demonstre que não existe mais.

### Exercício 4 — Explique a quem fez isso

Um colega da cena inicial diz: «Eu tenho o `ufw` ativo, então publicar com `-p 9000:9000` não tem nada demais». Em no máximo cinco frases, explique por que tem problema sim, e o que deveria ter sido digitado. Use as palavras *interface*, *127.0.0.1* e *firewall*.

## Soluções

### Solução 1

1. Falha o **segundo**: a porta 9000 de `127.0.0.1` já está ocupada por `curso-docker-a`; termina com `port is already allocated` e código 125. O quarto **não** é um erro do Docker, mas termina com código **1**: o subcomando `healthcheck` não encontra ninguém atendendo dentro daquele contêiner (`connection refused`), exatamente como no bloco 5 de `fig02_07.sh`.
2. Dois: `curso-docker-a` em `Exited (0)`, porque foi parado e o serviço encerra de forma limpa com `SIGTERM`; e `curso-docker-b` em `Created`, o contêiner fantasma da porta ocupada. `curso-docker-c` não aparece: tinha `--rm`, e o `docker run` sem `-d` só retorna depois que a remoção foi concluída.
3. **Inicia, mas sem a porta conectada**, e esta é a resposta que quase ninguém prevê. Isso foi verificado durante a elaboração da lição, com o Docker 29.2.1: `docker start curso-docker-b` terminou com código 0 e o `docker ps` o mostrou como `Up`, mas a coluna PORTS saiu **vazia**, `docker port` não imprimiu nada e um `curl` para `127.0.0.1:9000` não obteve resposta. O `docker inspect` mostrava a discrepância: em `.HostConfig.PortBindings` ainda constava a solicitação de `127.0.0.1:9000`, mas em `.NetworkSettings.Ports`, que reflete o que de fato ficou conectado, não havia nada. Quem previu «inicia e usa a 9000, que já ficou livre» seguiu um raciocínio lógico; o contêiner fantasma simplesmente não se comporta dessa forma. É mais uma razão para a regra da seção «O erro que se vai ver»: após uma falha de porta ocupada, **apague** o contêiner que ficou em `Created` e crie-o novamente com `docker run`, em vez de tentar resgatá-lo com `docker start`.
4. Um comando para apagar e outro para verificar: `docker ps -aq --filter name='^curso-docker-' | xargs -r docker rm -f` e depois `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l`, que deve imprimir `0`.

Os itens 1, 2 e 3 foram verificados executando essa mesma sequência na máquina de testes.

### Solução 2

```bash
docker run -d --name curso-docker-ejercicio -p 127.0.0.1:9002:9000 \
  --memory 32m --cpus 0.25 --pids-limit 20 curso-docker-prueba:1.0.0
curl -s http://127.0.0.1:9002/
docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}}' curso-docker-ejercicio
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' curso-docker-ejercicio
curl -s -X POST http://127.0.0.1:9002/modo/caido
docker ps --filter name=curso-docker-ejercicio --format '{{.Names}} {{.Status}}'
docker rm -f curso-docker-ejercicio
```

1. O aspecto fundamental é `-p 127.0.0.1:9002:9000`: 9002 é a porta **da máquina hospedeira**, e 9000 continua sendo a do serviço dentro do contêiner. Se for colocado `-p 127.0.0.1:9002:9002`, o `curl` não obtém resposta, porque dentro do contêiner ninguém escuta na 9002.
2. `memoria=33554432`, que corresponde a 32 × 1024 × 1024, e `cpus(nano)=250000000`, um quarto de bilhão: um quarto de CPU. É a mesma conta de 2.7.1 com outros valores.
3. A coluna exibirá `… / 32MiB`. O que vem antes da barra varia; o limite, não.
4. `Up`, com ou sem a indicação da verificação de saúde. Na elaboração da lição foi medido: logo após mudar para o modo fora do ar, `Up 2 seconds (health: starting)`; doze segundos depois, `Up 14 seconds (unhealthy)`. Continua indicando `Up` mesmo estando marcado como não saudável. O Docker toma conhecimento da queda por causa da verificação de saúde embutida na imagem, e não porque saiba por conta própria o que o serviço responde.
5. `docker rm -f` é adequado aqui: trata-se de um contêiner de teste sem dados persistentes.

### Solução 3

```bash
docker run -d --name curso-docker-bitacora -p 127.0.0.1:9000:9000 \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
for _ in $(seq 20); do curl -fs -o /dev/null http://127.0.0.1:9000/ && break; sleep 0.5; done
for i in 1 2 3; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/caido
for i in 1 2; do curl -s http://127.0.0.1:9000/; done
curl -s -X POST http://127.0.0.1:9000/modo/sano
docker logs --tail 3 curso-docker-bitacora
docker logs --timestamps curso-docker-bitacora
docker logs --since 1m curso-docker-bitacora
docker stop curso-docker-bitacora
docker logs --tail 3 curso-docker-bitacora
docker rm curso-docker-bitacora
docker logs curso-docker-bitacora
```

1. Se o bloco foi colado de uma só vez, as três últimas linhas são as duas requisições em modo fora do ar e a mudança para o modo saudável: `GET / en modo caido` duas vezes e `modo cambiado a sano`. Se os comandos foram digitados um por um com intervalos maiores que cinco segundos, entre eles surgirão linhas `GET / en modo …` da verificação de saúde (2.5): não foram requisitadas manualmente, foram disparadas pelo Docker, e a saída de `--tail 3` será diferente.
2. Com `--timestamps`, cada linha começa com a data e a hora em que o Docker a recebeu, em UTC (indicado pelo `Z` no final), com precisão de nanossegundos: na execução de validação, `2026-10-21T08:39:45.967466997Z servicio-prueba: GET / en modo caido`. Com essa coluna seria possível determinar em qual segundo exato a indisponibilidade começou; lembre-se de converter para o fuso horário local (em Brasília, subtraia 3 horas; na Cidade do México, subtraia 6 horas).
3. `--since 1m` mostra tudo, caso o exercício tenha sido feito em menos de um minuto: a inicialização, cada requisição (incluindo a do laço de espera) e cada mudança de modo, mais uma linha por cada verificação de saúde ocorrida nesse intervalo, de forma que o total aumenta de acordo com o tempo decorrido. É o recurso ideal para responder «o que aconteceu desde as 10:00», substituindo `1m` por um horário específico.
4. Após o `docker stop`, o registro permanece disponível, e agora a última linha é `servicio-prueba: recibí terminated, apagando`: o encerramento também ficou registrado. Após o `docker rm`, o `docker logs` falha com `Error response from daemon: No such container: curso-docker-bitacora`: o contêiner não existe mais, e os logs dele foram embora com ele. Essa é a evidência que se perderia se o contêiner fosse apagado antes da leitura.

### Solução 4

Uma resposta possível: «Sem endereço, `-p 9000:9000` publica a porta em todas as **interfaces** da máquina, incluindo a da rede sem fio, e não apenas na interface local. E o **firewall** `ufw` não impede isso, porque o Docker escreve as próprias regras de rede e o tráfego do contêiner passa antes de o `ufw` conseguir inspecioná-lo; a documentação do Docker adverte sobre isso. Assim, qualquer pessoa na rede da cafeteria conseguia se comunicar com o contêiner. O que deveria ter sido escrito é `-p 127.0.0.1:9000:9000`: **127.0.0.1** é a interface que leva apenas à própria máquina. A proteção está no `-p`, não no firewall».

## Como sei que consegui

Execute os sete scripts de [`programas/02-contenedores-dia-a-dia/`](../programas/02-contenedores-dia-a-dia) no Mint, em ordem (o `fig02_01.sh` constrói a imagem usada pelos demais; o bloco 1 só exibe o erro se a imagem ainda não existir), e compare as saídas com as desta lição. O que **não** se compara, por variar a cada execução: os identificadores de contêineres e imagens, os tempos (`Up 2 seconds`, `3.08 s`, `242 ms`, os tempos de compilação/construção), a memória em uso informada por `docker stats` e a memória total da máquina, além de `arm64` versus `amd64`. Todo o resto deve sair idêntico. Marque cada item:

- [ ] `docker image ls curso-docker-prueba:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'` imprime `curso-docker-prueba:1.0.0 15.1MB` (ou um tamanho muito próximo em `amd64`).
- [ ] Com o serviço rodando, `docker ps` mostra `127.0.0.1:9000->9000/tcp` na coluna PORTS, sem `0.0.0.0` nem `[::]`.
- [ ] `curl -s http://127.0.0.1:9000/` responde `sano`; em modo fora do ar, `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:9000/` responde `503`, e `docker ps` continua indicando `Up`.
- [ ] `docker inspect --format 'memoria={{.HostConfig.Memory}} cpus(nano)={{.HostConfig.NanoCpus}} pids={{.HostConfig.PidsLimit}} usuario={{.Config.User}}' curso-docker-prueba` imprime `memoria=67108864 cpus(nano)=500000000 pids=50 usuario=65532:65532`.
- [ ] Os dois erros de `fig02_06.sh` foram provocados e lidos, e está claro por que após o segundo é necessário apagar um contêiner em estado `Created`.
- [ ] `docker stop curso-docker-prueba` demora menos de um segundo e deixa `Exited (0)`; o registro termina em `recibí terminated, apagando`.
- [ ] É possível explicar, sem consultar o texto, a diferença entre parado e apagado, e o que se perde com cada um.
- [ ] Ao terminar, `docker ps -a --filter name='^curso-docker-' --format '{{.Names}}' | wc -l` imprime `0`, e a imagem `curso-docker-prueba:1.0.0` **permanece** no `docker image ls`: ela será necessária adiante.
- [ ] Foi anotado no diário de bordo o que muda entre `-p 9000:9000` e `-p 127.0.0.1:9000:9000`, comprovado com `ss -ltn`.

## Resumo

Responda sem consultar a lição:

1. O que significam os códigos de saída 125, 126 e 127 de `docker run`? Qual deles apareceu ao tentar rodar uma imagem inexistente, e qual ao pedir `sh` no serviço de teste?
2. Que pergunta cada opção do comando `docker run -d --name … -p 127.0.0.1:9000:9000 --memory 64m --cpus 0.5 --pids-limit 50 …` responde?
3. Que diferença existe entre `docker ps` e `docker ps -a`, e por que isso importa para a limpeza?
4. Por que o `docker ps` pode indicar `Up` para um serviço que responde `503`?
5. O que o `docker logs` enxerga e o que ele não enxerga? O que acontece com o registro após um `stop` e após um `rm`?
6. Por que `docker exec … sh` falha no serviço de teste, e por que isso é positivo?
7. O que significa `memoria=0` no `docker inspect`?
8. Que diferença existe entre publicar em `127.0.0.1` e não especificar endereço? Por que o `ufw` não protege nesse caso?
9. O que o `docker stop` faz, passo a passo, e em que ele se diferencia de `docker rm -f`?
10. Como se apagam apenas os contêineres do curso, e por que não se deve usar `docker container prune` em uma máquina compartilhada?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [docker container run](https://docs.docker.com/reference/cli/docker/container/run/): `-d`, `--name`, `-p`, `--rm`, `--pids-limit`, o valor padrão de `--pull` e a advertência sobre portas publicadas em todas as interfaces e o `ufw`.
- [Docker, “Running containers”](https://docs.docker.com/engine/containers/run/): os códigos de saída 125, 126 e 127, e o comportamento de `--privileged`.
- [docker container ls](https://docs.docker.com/reference/cli/docker/container/ls/): `-a`, `-q`, o filtro por nome e por estado, e os campos de `--format`.
- [docker container logs](https://docs.docker.com/reference/cli/docker/container/logs/): o que o comando entrega e as opções `--follow`, `--tail`, `--since` e `--timestamps`.
- [docker container exec](https://docs.docker.com/reference/cli/docker/container/exec/): `-i`, `-t`, o fato de funcionar apenas enquanto o processo principal roda e a exigência de que o comando seja um executável.
- [docker inspect](https://docs.docker.com/reference/cli/docker/inspect/): as informações de baixo nível e os modelos com `--format`.
- [docker container stats](https://docs.docker.com/reference/cli/docker/container/stats/): `--no-stream` e as colunas de memória e processos.
- [docker container stop](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, o prazo de 10 segundos, `SIGKILL` e `--timeout`.
- [docker container rm](https://docs.docker.com/reference/cli/docker/container/rm/): `--force` com `SIGKILL` e a recomendação de `prune`.
- [docker container prune](https://docs.docker.com/reference/cli/docker/container/prune/): o fato de apagar todos os contêineres parados, e os seus filtros.
- [docker image ls](https://docs.docker.com/reference/cli/docker/image/ls/): a exibição de referência do comando.
- [Docker, “Port publishing and mapping”](https://docs.docker.com/engine/network/port-publishing/): a publicação em todos os endereços por padrão, o aviso de insegurança e a publicação em `127.0.0.1`.
- [Docker, “Packet filtering and firewalls”](https://docs.docker.com/engine/network/packet-filtering-firewalls/): por que o tráfego de um contêiner não passa pelas regras do `ufw`.
- [Docker, “Resource constraints”](https://docs.docker.com/engine/containers/resource_constraints/): a ausência de limites por padrão, o risco de esgotamento de memória, o valor mínimo de `--memory` e o exemplo de `--cpus`.
- [Docker Engine security](https://docs.docker.com/engine/security/): o daemon rodando como `root` e a razão pela qual apenas usuários de confiança devem controlá-lo.
- [Docker, passos posteriores à instalação no Linux](https://docs.docker.com/engine/install/linux-postinstall/): o grupo `docker` e seus privilégios equivalentes a `root`.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões e datas de «Sobre as execuções» e o novo formato de `docker image ls` a partir da 29.0.
- [Colima](https://github.com/abiosoft/colima): a ferramenta com a qual os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **registro** (*logs*) | o que o programa principal de um contêiner escreve em sua saída padrão e de erros; armazenado pelo Docker e exibido por `docker logs` |
| **código de saída** | o número com o qual um programa termina; 0 indica que tudo correu bem |
| **contexto de construção** | a pasta que o `docker build` utiliza para procurar o `Dockerfile` e os arquivos que a receita copia |
| **distroless** | família de imagens base mínimas que trazem apenas o estritamente necessário para rodar um programa, sem shell |
| **estado de um contêiner** | criado, rodando, parado; apagado significa que não existe mais |
| **tag** | o que vem depois dos dois-pontos no nome de uma imagem: `1.0.0` em `curso-docker-prueba:1.0.0` |
| **interface de rede** | cada «porta» de comunicação de rede de uma máquina; `127.0.0.1` é a que leva exclusivamente ao próprio computador (*loopback*) |
| **publicar uma porta** | conectar uma porta do host a uma porta do contêiner, por meio de `-p` |
| **`SIGTERM`** | o sinal com o qual se solicita a finalização de um programa; pode ser tratado para um encerramento gracioso |
| **`SIGKILL`** | o sinal 9, que encerra imediatamente um programa sem lhe dar a chance de fechar arquivos ou conexões |

---

**Próxima:** [Lição 3 — O primeiro Dockerfile](03-primer-dockerfile.md)
