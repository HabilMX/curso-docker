# Lição 3 — O primeiro Dockerfile

São 18h40 de uma sexta-feira e a janela para atualizar o servidor fecha às 19h. O plano era simples: parar o `revisor` antigo, iniciar o novo, ir para casa. Digita-se `docker stop` e o terminal fica em silêncio. Um segundo. Três. Sete. Aos dez, finalmente, ele volta. Tenta-se com a próxima cópia e de novo: exatamente dez segundos de silêncio. Olham-se os logs e falta a linha que o `revisor` sempre escreve ao desligar, `apagado limpio`; o último relatório ficou pela metade. Alguém da equipe encontra o estado do contêiner e lê em voz alta: `ExitCode=137`. Ninguém o matou de propósito, e no entanto ele foi morto. O culpado não está no código do `revisor`, que sabe desligar direito. Está em uma linha de três palavras no final do seu Dockerfile, uma que parece inofensiva e que é escrita assim em muitos tutoriais. Esta lição ensina a escrever essa linha, e todas as outras, sabendo o que cada uma faz.

**Tempo:** 2 × 45 min

**O que se constrói:** a primeira imagem do `revisor`, `curso-docker-revisor:1.0.0`, em um único estágio, com seu `Dockerfile` e seu `.dockerignore`. Roda sem privilégios, desliga em uma fração de segundo e leva uma versão no nome.

**O que se aprende:** o que é um Dockerfile e o que faz cada uma de suas instruções básicas (`FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`); a diferença entre a forma *exec* e a forma *shell*, medida com um cronômetro; o que é o contexto de build e para que serve o `.dockerignore`; por que o primeiro Dockerfile já traz `USER`; como se nomeia uma imagem e se coloca nela uma tag de versão; e como revisar um Dockerfile antes de construí-lo com `docker build --check`.

**De onde se parte.** Da [Lição 2](02-contenedores-dia-a-dia.md) traz-se a prática do dia a dia: inicia-se um contêiner com `docker run`, examina-se com `ps`, `logs`, `inspect` e `exec`, publica-se sua porta só em `127.0.0.1` e apaga-se sem deixar lixo. Lá foi construída a imagem do serviço de teste com um único comando, sem perguntar o que havia em seu Dockerfile. Da [Lição 0](00-que-es-un-contenedor.md) traz-se o mapa: um contêiner é um processo; uma imagem é o modelo de que ele nasce; e o código 137 significa que o kernel matou o processo com o sinal 9. Essa última ideia vai voltar aqui com outra cara. Do curso vem também o código do `revisor`, em `programas/revisor/`, tal como o curso o entrega: um serviço HTTP escrito em Go que ainda não tem Dockerfile. Não é preciso saber Go: não se vai mudar uma linha do programa.

**O que esta lição não faz.** Não deixa a imagem pequena: a que sai daqui pesa mais de um gigabyte, e por enquanto é bom que seja assim, porque vê-la grande é a melhor forma de entender depois por que convém reduzi-la (o plano do curso deixa isso para a [Lição 5](05-multi-stage.md)). Também não ordena o Dockerfile para que a reconstrução seja rápida nem explica as camadas uma a uma: isso é matéria da [Lição 4](04-capas-cache-contexto.md). Não conecta o `revisor` a outros contêineres (por isso, nesta lição, o `revisor` verifica a si mesmo) e não coloca nele health check nem segredos. Um único estágio, uma única imagem, tudo à vista.

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4, a mesma base do Linux Mint 22, o sistema de referência do curso. Os cinco scripts foram executados naquele dia a partir do cliente do Mac (Docker 29.8.2) contra o daemon dessa máquina virtual (Docker 29.2.1, Buildx v0.31.1). Essa mesma máquina era usada ao mesmo tempo por outras execuções, então, para não haver conflito, os scripts foram lançados com outro prefixo de nomes e outra porta: eles trazem as variáveis `PREFIJO` (por padrão `curso-docker-`) e `PUERTO` (por padrão `8080`), e foram executados com `PREFIJO=curso-docker-l03-` e `PUERTO=18030`. Nas saídas de `fig03_05` e `fig03_07`, onde aparecem nomes e porta, a lição mostra os valores padrão, que são os que vão aparecer no Mint: `curso-docker-revisor` em vez de `curso-docker-l03-revisor` e `8080` em vez de `18030`; essa é a única alteração, e os arquivos `.salida.txt` guardam a execução tal como foi. As saídas de `fig03_02`, `fig03_04` e `fig03_08` não mostram nomes nem porta e vão sem alteração. Mais duas coisas do Mac: o `date` do macOS não dá milissegundos, então a função auxiliar `t` dos scripts recorre ao `python3` quando necessário (no Mint não é necessário); e a primeira linha de `docker build --check` diz `building with "colima" instance`, porque esse é o nome do contexto do Docker no Mac; no Mint dirá `"default"`. O curso foi planejado com o Docker Engine 29.8.2, e a versão mais recente publicada naquele dia era a 29.9.2, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)); nada desta lição muda entre essas versões. O que **muda** no Mint, e é avisado onde aparece: os números de processo (PID), os tempos de build e de desligamento (os desta lição incluem ainda a ida e volta entre o Mac e sua máquina virtual, então no Mint devem sair um pouco menores), e, se a máquina for Intel ou AMD, a arquitetura (`amd64` em vez de `arm64`), que aqui não é impressa, mas decide que variante da imagem do Go é baixada. Os programas estão em [`programas/03-primer-dockerfile/`](../programas/03-primer-dockerfile), cada um com sua saída ao lado; `estado/` guarda o `Dockerfile` e o `.dockerignore` tal como ficam ao terminar.

## Ao terminar, será possível

- Escrever um Dockerfile de um único estágio para um programa já pronto e dizer, linha por linha, se aquela instrução age ao **construir** a imagem ou ao **rodar** o contêiner.
- Construir uma imagem com um nome e uma tag de versão, e explicar por que o `revisor` do curso se chama `curso-docker-revisor:1.0.0` e não `revisor` nem `revisor:latest`.
- Mostrar com `docker exec ... id` que o contêiner não roda como `root`, e explicar o que `USER 10001:10001` muda.
- Escrever um `.dockerignore` e comprovar, olhando dentro da imagem, que um arquivo `.env` não viajou.
- Medir quanto `docker stop` demora com `CMD` na forma *exec* e na forma *shell*, e explicar com `docker top` por que uma demora uma fração de segundo e a outra pouco mais de 10 s com código 137.
- Rodar `docker build --check` antes de construir e ler o aviso `JSONArgsRecommended`.

## O porquê antes do como

Na Lição 2, trabalhou-se com uma imagem entregue pronta. Funciona, mas tem uma armadilha: sem saber como ela foi montada, não se sabe o que ela traz nem como vai se comportar. Roda como `root`? Leva para dentro os arquivos de configuração? Desliga quando se pede ou espera ser morta? Essas três perguntas não se respondem olhando o contêiner rodando; respondem-se lendo sua **receita**.

A receita de uma imagem se chama **Dockerfile**. É um arquivo de texto com instruções, uma por linha, que o Docker lê de cima para baixo para fabricar a imagem. A documentação o define assim: o Docker constrói imagens lendo as instruções de um Dockerfile, «um arquivo de texto que contém as instruções para construir o código-fonte» ([referência do Dockerfile](https://docs.docker.com/reference/dockerfile/)). O que importa é que a receita é **reproduzível**: a mesma receita com o mesmo código dá a mesma imagem, hoje, na sexta às 18h40 e na máquina de um colega. O que na Lição 0 se chamou de «não se conserta uma imagem entrando no contêiner» tem aqui sua outra metade: uma imagem se conserta **mudando sua receita e reconstruindo**.

E cada linha dessa receita é uma decisão. A cena do começo não foi causada por um erro de programação: foi causada por escrever `CMD revisor` em vez de `CMD ["revisor"]`. Parecem quase iguais. Esta é a diferença que vai ser medida na seção 3.6, com a mesma imagem e o mesmo programa:

```text
## docker stop con forma exec
tardó 299 ms

## docker stop con forma shell
tardó 10485 ms
ExitCode=137
```

Alguns décimos de segundo contra dez segundos e um cadáver. Esses são os números da execução desta lição; em outra execução, feita dentro da máquina virtual e sem a ida e volta a partir do Mac, saíram 161 ms contra 10.112 ms (10,1 s), com o mesmo `ExitCode=137`. Os milissegundos mudam; os dez segundos e o 137, não. A lição tem sete partes:

1. **O que é construir** (3.1): a receita, o contexto e quem faz o trabalho.
2. **O Dockerfile do `revisor`, linha por linha** (3.2).
3. **O nome e a tag** (3.3): por que `curso-docker-revisor:1.0.0`.
4. **`USER`: não rodar como `root`** (3.4).
5. **O contexto e o `.dockerignore`** (3.5), com um segredo falso que entra sem ser convidado.
6. **Construir, falhar e rodar** (3.6), e a **forma *exec* versus a forma *shell*** (3.7), com o cronômetro.
7. **Revisar antes de construir** (3.8) e o que há de antigo nos tutoriais (3.9).

## Os conceitos

### 3.1 O que é construir uma imagem

#### 3.1.1 A receita, os ingredientes e a cozinha

Construir uma imagem tem três peças, e convém separá-las desde o início, porque cada uma falha de um jeito diferente:

- **A receita**: o Dockerfile.
- **Os ingredientes**: os arquivos que a receita pode usar. Chamam-se **contexto de build**, e quase sempre são o conteúdo de uma pasta. No comando `docker build .`, o ponto final é essa pasta: «o contexto é esta pasta em que estou».
- **A cozinha**: o builder, que no Docker se chama **BuildKit** e faz parte do daemon. Lembre-se da Lição 0: o cliente `docker` não faz o trabalho; pede ao daemon. Ao construir, o cliente envia a receita e os ingredientes que a receita pede, e o daemon cozinha.

A documentação de build diz isso com essas mesmas peças: o contexto é o conjunto de arquivos a que o build tem acesso, e as instruções do Dockerfile só podem pegar arquivos dali ([Docker, «Build context»](https://docs.docker.com/build/concepts/context/)). Isso tem uma consequência prática que vai ser usada em 3.5: **o que não está no contexto não pode entrar na imagem**, e o que está no contexto pode entrar mesmo sem ser desejado.

#### 3.1.2 Dois momentos: construir e rodar

Há uma ideia que organiza todo o resto desta lição: um Dockerfile descreve **dois momentos diferentes**.

1. **Ao construir** (`docker build`): o Docker parte de uma imagem base, copia arquivos e executa comandos. O resultado fica guardado na imagem. Isso acontece uma vez, na máquina local ou em um servidor de build.
2. **Ao rodar** (`docker run`): o Docker cria um contêiner a partir dessa imagem e inicia **um** processo. Isso acontece toda vez que alguém roda a imagem, em qualquer máquina.

Algumas instruções agem no primeiro momento e outras só deixam **anotado** o que fazer no segundo. Quem confunde os dois momentos escreve coisas como um `RUN` que tenta iniciar o servidor (seria executado ao construir, ficaria esperando e o build nunca terminaria) ou espera que um `EXPOSE` abra uma porta (ele só anota). A tabela de 3.2.2 separa cada instrução por momento.

### 3.2 O Dockerfile do `revisor`, linha por linha

#### 3.2.1 A receita completa

Este é o Dockerfile com que a lição termina. Fica na raiz do projeto do `revisor`, junto de `go.mod`, e se chama exatamente `Dockerfile`, sem extensão, que é o nome que `docker build` procura por padrão:

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

Doze linhas, das quais sete são instruções. Vamos uma por uma.

**`# syntax=docker/dockerfile:1`.** Parece um comentário, e para quase todo o arquivo é, mas na primeira linha é uma **diretiva**: diz ao BuildKit que versão da sintaxe do Dockerfile usar. A referência explica assim: serve para «declarar a versão da sintaxe do Dockerfile que será usada no build», e permite usar recursos novos sem atualizar o Docker ([referência do Dockerfile, *syntax*](https://docs.docker.com/reference/dockerfile/#syntax)). O `1` significa «a versão 1 mais recente». Por isso, nas saídas de build, aparece o Docker resolvendo primeiro `docker.io/docker/dockerfile:1`: ele vai buscar o intérprete da receita antes de lê-la. Todos os Dockerfiles do curso começam com essa linha.

**`FROM golang:1.27.3-trixie`.** Toda imagem parte de outra. `FROM` diz qual é a **imagem base**: aqui, a oficial do Go na versão 1.27.3, construída sobre o Debian 13, cujo codinome é *trixie*. O `revisor` é escrito em Go e para compilá-lo é preciso o compilador do Go; esta imagem o traz, junto com um Debian inteiro. O Docker Hub lista essa tag entre as vigentes da imagem do Go, e esclarece que nomes como *bookworm* ou *trixie* são os codinomes das versões do Debian sobre as quais ela é feita ([golang no Docker Hub](https://hub.docker.com/_/golang)).

**`WORKDIR /src`.** Fixa a pasta de trabalho dentro da imagem: tudo o que vier depois (`COPY`, `RUN`, `CMD`) acontece ali. Se a pasta não existir, o Docker a cria ([referência, `WORKDIR`](https://docs.docker.com/reference/dockerfile/#workdir)). É melhor do que escrever `RUN cd /src`, que não funciona: cada `RUN` começa de novo e o `cd` se perde ao terminar aquela linha.

**`COPY . .`.** Copia do contexto (o primeiro ponto) para a pasta de trabalho da imagem (o segundo ponto, que aqui é `/src`). É a única porta pela qual os arquivos entram na imagem. Copiar **tudo** é o mais simples e o mais perigoso: entra tudo o que estiver no contexto. Por isso existe o `.dockerignore` de 3.5. (Copiar tudo de uma vez também deixa a reconstrução lenta; o plano do curso trata disso na Lição 4.)

**`RUN go build -o /usr/local/bin/revisor ./cmd/revisor`.** Executa um comando **ao construir** e guarda o resultado na imagem. Aqui compila o `revisor` e deixa o executável em `/usr/local/bin/revisor`, uma pasta que já está na variável `PATH` da imagem. Por isso, mais abaixo, basta escrever `revisor`, sem caminho.

**`USER 10001:10001`.** Daqui em diante, e sobretudo ao rodar, o processo usa o usuário 10001 e o grupo 10001 em vez de `root`. Tem seção própria, a 3.4.

**`EXPOSE 8080`.** Anota que o programa escuta na porta 8080. Só anota: a referência é clara em que `EXPOSE` «na verdade não publica a porta»; para publicá-la é preciso `-p` ao rodar ([referência, `EXPOSE`](https://docs.docker.com/reference/dockerfile/#expose)). Serve como documentação para quem lê a imagem e para ferramentas que a consultam. A porta é publicada, como se aprendeu na Lição 2, com `-p 127.0.0.1:8080:8080`.

**`CMD ["revisor"]`.** Anota que processo iniciar **ao rodar** o contêiner. Só pode haver um efetivo: com vários `CMD`, vence o último ([referência, `CMD`](https://docs.docker.com/reference/dockerfile/#cmd)). E é um valor padrão: se `docker run` receber um comando depois do nome da imagem, esse comando substitui o `CMD` ([Docker, «Running containers»](https://docs.docker.com/engine/containers/run/)). Os colchetes e as aspas não são decoração: são a forma *exec*, o tema de 3.7.

#### 3.2.2 Cada instrução no seu momento

| Instrução | Quando age | O que deixa na imagem |
|---|---|---|
| `FROM` | ao construir | todo o conteúdo da imagem base |
| `WORKDIR` | ao construir, e anota a pasta para rodar | a pasta, e a informação de onde iniciar |
| `COPY` | ao construir | os arquivos copiados |
| `RUN` | ao construir | o que o comando escreveu em disco |
| `USER` | anota para rodar (e para os `RUN` que vierem depois) | a informação do usuário |
| `EXPOSE` | só anota | a informação da porta; não abre nada |
| `CMD` | só anota | o comando que cada contêiner vai iniciar |

Leia a terceira coluna com cuidado: as três últimas instruções não acrescentam arquivos, acrescentam **dados** à configuração da imagem. Eles podem ser lidos com `docker inspect` e, mais adiante, no histórico da imagem. Tenha em mente que a ordem importa: um `USER` antes de um `RUN` faz esse `RUN` ser executado com esse usuário. Por isso aqui o `USER` vem depois de compilar: a compilação precisa escrever em pastas de `root`, o servidor não.

> [!NOTE]
> 🔧 **Observação de engenharia 3.1**
> Para cada linha de um Dockerfile, pergunte: «isto acontece uma vez, quando construo, ou toda vez, quando alguém roda?». O que acontece ao construir pode ser lento e pesado, porque se paga uma única vez. O que acontece ao rodar precisa ser rápido e mínimo, porque se paga a cada inicialização, e em um dia ruim, a cada reinício.

### 3.3 O nome e a tag

#### 3.3.1 As partes de um nome

Ao construir, dá-se nome à imagem com `-t`. O nome completo de uma imagem tem esta forma, segundo a documentação de `docker image tag`: `[ANFITRIÓN[:PUERTO]/]ESPACIO/REPOSITORIO[:ETIQUETA]` ([`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/)). Para uma imagem que só vive na máquina local, bastam duas partes:

- o **repositório**, que diz o que ela é: `curso-docker-revisor`;
- a **tag**, depois dos dois-pontos, que diz qual das suas versões: `1.0.0`.

A mesma documentação diz algo que convém destacar: «se nenhuma tag for informada, o Docker usa `latest`». Ou seja, `latest` **não** significa «a mais nova». Significa «não colocaram tag». Uma imagem construída há dois anos sem tag se chama `latest` do mesmo jeito que uma de hoje. Na cena do começo, se as imagens se chamassem `revisor:latest`, nem daria para saber que versão estava rodando quando o problema começou.

As tags, além disso, são **apelidos que se movem**. Veja a linha da imagem base no Docker Hub: o mesmo conteúdo leva ao mesmo tempo as tags `1.27.3-trixie`, `1.27-trixie`, `1-trixie` e `trixie` ([golang no Docker Hub](https://hub.docker.com/_/golang)). Quando sair o Go 1.27.4, `1.27-trixie` vai passar a apontar para outra coisa e `1.27.3-trixie` vai ficar onde está. Por isso o `FROM` desta lição usa a tag mais específica que existe. Nem essa é uma garantia absoluta, porque quem publica pode reenviar uma tag: o guia de boas práticas adverte que «as tags de imagem são mutáveis» e que, para fixar uma versão de verdade, é preciso usar seu *digest* ([boas práticas](https://docs.docker.com/build/building/best-practices/)). O plano do curso deixa esse passo para a Lição 5; aqui basta não usar `latest`.

#### 3.3.2 Por que `curso-docker-revisor` e não `revisor`

O plano do curso, na tabela de lições, diz que nesta lição se constrói `revisor:1.0.0`. Aqui a imagem se chama `curso-docker-revisor:1.0.0`. A diferença é proposital, e é uma lição em si: **o prefixo do curso**.

Desde a Lição 0, tudo o que o curso cria na máquina começa com `curso-docker-`: os contêineres, as redes, os volumes e, a partir de agora, as imagens. Esse prefixo faz três coisas:

1. **Evita conflitos.** `revisor` é um nome que qualquer um usaria. Se na máquina já existir uma imagem `revisor:1.0.0` de outro projeto (de outro curso da Hábil, por exemplo), o `docker build -t revisor:1.0.0` toma o nome dela sem perguntar: a imagem antiga fica sem tag e a nova toma seu lugar. Não é hipotético: na máquina em que esta lição foi executada já havia uma imagem chamada `revisor:1.0.0`, de outro projeto, que não tem nada a ver com este Dockerfile. Com o prefixo, as duas convivem.
2. **Permite limpar só o que é do curso.** Os filtros do Docker trabalham por nome. `docker ps -a --filter name=curso-docker-` lista só os contêineres do curso, e `docker image ls 'curso-docker-*'` só suas imagens. Apagar «tudo o que é do curso» vira um comando seguro, que não toca nos bancos de dados nem nas imagens de outros projetos que estejam na mesma máquina.
3. **Diz de onde veio.** Daqui a seis meses, ao fazer uma limpeza e encontrar `curso-docker-revisor:1.0.0`, vai dar para saber o que é sem investigar.

A regra de versões do `revisor` neste curso é simples: toda vez que uma lição muda a imagem, a versão sobe. Esta é a `1.0.0`: a primeira que funciona por completo. Quando o Dockerfile mudar, a tag não é reutilizada; cria-se outra.

> [!NOTE]
> 🔧 **Observação de engenharia 3.2**
> Um nome de imagem é uma promessa: «isto é tal coisa, em tal versão». `latest` não promete nada, e um nome sem prefixo promete algo que outro projeto também pode estar prometendo. Os dois erros se pagam no dia em que é preciso saber o que está rodando, que costuma ser o pior dia para descobrir.

### 3.4 `USER`: o primeiro Dockerfile já não roda como `root`

#### 3.4.1 O que acontece quando nada é dito

Na Lição 0 viu-se que `root` dentro de um contêiner é o usuário 0 do mesmo kernel, com catorze capabilities ativadas. Agora a pergunta concreta: se o Dockerfile não diz nada sobre o usuário, com quem o `revisor` roda? Depende da imagem base. `fig03_02.sh` pergunta à imagem do Go:

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

Esta saída é estável. Na primeira vez, `docker pull` baixa a imagem do Go, que pesa centenas de megabytes; é preciso paciência. `--user` faz ao rodar o mesmo que `USER` faz no Dockerfile, e aqui serve para testar o usuário sem construir nada.

Leia de cima para baixo. A imagem base declara um usuário vazio, e vazio quer dizer `root`: o bloco 2 confirma, com `uid=0(root)`. Um Dockerfile que parte de `golang` e não diz nada herda isso, e o `revisor` atenderia requisições da rede como o usuário 0 do kernel. Com o usuário 10001, o bloco 3 diz `uid=10001 gid=10001`, **sem nome entre parênteses**. E o bloco 4 explica por quê: esse usuário não existe no `/etc/passwd` da imagem.

#### 3.4.2 Um número basta

Isso está correto, e é proposital. Para o kernel, um usuário é um número; o nome é uma comodidade que vive em `/etc/passwd`. A referência de `USER` aceita um nome ou um número, na forma `USER <UID>[:<GID>]` ([referência, `USER`](https://docs.docker.com/reference/dockerfile/#user)), e escrever os dois números tem duas vantagens. A primeira: não é preciso criar o usuário na imagem. A segunda: o grupo fica fixo; se for dado um usuário sem grupo e esse usuário não tiver grupo principal, a referência avisa que o processo roda com o grupo de `root`. Com `10001:10001` não há surpresa.

Por que 10001? Porque está longe dos números que as distribuições usam para seus próprios usuários e para as pessoas da equipe (no Mint, o usuário costuma ser o 1000). Um número alto e próprio reduz a chance de o processo do contêiner coincidir com um usuário real do host.

O guia de boas práticas pede isso sem rodeios: «se um serviço pode rodar sem privilégios, use `USER` para trocar para um usuário que não seja `root`» ([boas práticas, `USER`](https://docs.docker.com/build/building/best-practices/#user)). O `revisor` não precisa de nada de `root`: escuta na 8080, uma porta alta, e não escreve em pastas do sistema. (As portas abaixo de 1024 são as que, no Linux, exigem uma capability especial; dentro de um contêiner Docker nem isso se aplica: `docker run --rm --user 10001:10001 golang:1.27.3-trixie cat /proc/sys/net/ipv4/ip_unprivileged_port_start` imprimiu `0` na máquina desta lição, o que quer dizer que qualquer porta pode ser aberta sem privilégios.) Então, desde o primeiro Dockerfile, ele roda como 10001. O plano do curso diz assim: segurança não é uma lição, é um costume.

### 3.5 O contexto e o `.dockerignore`

#### 3.5.1 O que viaja acaba dentro

Agora o ingrediente perigoso: `COPY . .`. Ele copia **todo** o contexto. Em um projeto real, a pasta tem mais do que código: um `.git` com o histórico, um `.env` com senhas para testar localmente, um backup `.tar` deixado ali na semana passada. `fig03_04.sh` constrói o `revisor` com o Dockerfile desta lição e um arquivo `.env` **falso** na pasta, primeiro sem `.dockerignore` e depois com um, e olha o que ficou em `/src` dentro da imagem:

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

Esta saída é estável. O script trabalha em uma pasta temporária (`mktemp -d`) para não sujar `programas/revisor/`, que é o código que o curso entrega e que não é editado, e apaga suas duas imagens ao sair. `docker build -q` constrói em silêncio (*quiet*); `ls -A` lista também os arquivos que começam com ponto. Os dois builds demoram o mesmo que um normal, porque cada um compila de novo: na execução desta lição, o script completo levou pouco mais de um minuto, com a imagem base já baixada.

Veja o primeiro bloco. O `.env` entrou na imagem e é lido com um `cat`. Qualquer um que tenha a imagem — um colega, o servidor, um registry público se um dia ela for enviada para lá — tem também esse segredo. E não é preciso rodar a imagem para extraí-lo: basta salvá-la em um arquivo e abri-lo. Entrou também o próprio `Dockerfile`, que não serve para nada lá dentro. No segundo bloco, com o `.dockerignore`, `/src` tem só o que o programa precisa para ser compilado: `cmd`, `go.mod` e `internal`.

#### 3.5.2 O `.dockerignore` da lição

Este é o arquivo. Chama-se exatamente `.dockerignore`, com o ponto, e fica na raiz do contexto, junto do `Dockerfile`:

```text
# fig03_03.dockerignore
# Lo que nunca viaja al daemon al construir.
.git
.env
*.tar
Dockerfile*
.dockerignore
```

Cada linha é um padrão, parecido com os curingas do *shell*; as linhas com `#` são comentários ([Docker, «Build context», arquivos `.dockerignore`](https://docs.docker.com/build/concepts/context/#dockerignore-files)). A documentação diz onde ele é procurado: o cliente procura um arquivo chamado `.dockerignore` «na pasta raiz do contexto». Cada linha tem seu porquê:

- **`.git`**: o histórico completo do projeto. Pode pesar muito mais que o código e pode guardar segredos que alguém apagou do código, mas não do histórico.
- **`.env`**: o lugar onde as pessoas guardam senhas para testar localmente. É justamente o arquivo da figura.
- **`*.tar`**: backups e arquivos exportados que ficam na pasta sem que ninguém se lembre.
- **`Dockerfile*` e `.dockerignore`**: a receita não precisa estar dentro do prato. E então como o Docker constrói, se o Dockerfile é excluído? A documentação responde: esses dois arquivos «são enviados ao builder de qualquer forma, porque ele precisa deles para construir»; o que o padrão impede é que o `COPY` os coloque na imagem. O asterisco de `Dockerfile*` alcança também o `Dockerfile.forma-shell` de 3.7.

Um detalhe de leitura: uma linha que começa com `!` abre uma exceção («isto sim, mesmo que um padrão anterior o exclua»), e quando vários padrões coincidem com um arquivo, vence o último. Não é necessário hoje, mas aparece em projetos alheios.

> [!NOTE]
> 🔧 **Observação de engenharia 3.3**
> O `.dockerignore` é uma lista do que **não** viaja. Isso significa que tudo o que for esquecido viaja. Por isso o primeiro Dockerfile de um projeto já leva seu `.dockerignore`, mesmo que hoje a pasta esteja limpa: a pasta não vai continuar limpa, e no dia em que alguém deixar um `.env` ali, o arquivo já vai estar esperando por ele.

### 3.6 Construir, falhar e rodar

#### 3.6.1 Construir

Com o `Dockerfile` e o `.dockerignore` na pasta do `revisor`, o build é um único comando. `fig03_05.sh` monta o projeto em uma pasta temporária, constrói, provoca o primeiro erro, roda o serviço corretamente, consulta-o e o para:

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

O script é longo por causa das funções auxiliares do início, que vão reaparecer nos próximos: `muestra` imprime cada comando com um `$` na frente antes de executá-lo, para que na saída se saiba o que produziu o quê, e se o comando falha, anota seu código de saída em vez de interromper o script; `t` dá a hora em milissegundos para cronometrar; `esperar_http` pergunta pelo health check do serviço até ele responder, porque um contêiner recém-iniciado leva um instante para escutar. A primeira parte da saída:

```text
## Construir y medir
$ docker build -q -t curso-docker-revisor:1.0.0 . >/dev/null && docker image ls curso-docker-revisor:1.0.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.0.0 1.45GB
```

**1.45 GB.** O `revisor` compilado é um único arquivo de poucos megabytes; todo o resto é o que a imagem base traz: um Debian completo, o compilador do Go e suas ferramentas, mais o que a compilação deixou na imagem. Nada disso é necessário para **rodar** o `revisor`, só para **construí-lo**. Anote o número no diário de bordo: é o ponto de partida, e o plano do curso dedica a Lição 5 a reduzi-lo. Na máquina de cada um, o número pode variar um pouco conforme a arquitetura.

#### Na pasta local: a imagem que fica

Os scripts do curso trabalham em pastas temporárias e **apagam o que criam** ao sair: servem para ver e medir, não para deixar nada. O projeto local, por outro lado, precisa ficar, porque a Lição 4 parte dele. A partir da raiz do repositório do curso, monte a pasta e construa a imagem que vai ser mantida:

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

O identificador que `docker build -q` imprime é o *digest* da imagem e muda em cada máquina; aqui foi cortado. Esta execução usou na tag o prefixo de execução de «Sobre as execuções», e é mostrada com o nome padrão; a ordem em que `ls -A` lista os arquivos pode variar com o idioma do sistema. Daqui em diante, quando a lição disser «na pasta do `revisor`», é `~/curso-docker/revisor`, e **esta** `curso-docker-revisor:1.0.0` é a que fica na máquina ao terminar. Os comandos de 3.6.2 e 3.6.3 podem ser digitados ali como estão.

#### 3.6.2 O primeiro erro: iniciar sem configuração

```text
## El error: arrancar sin configuración
$ docker run --name curso-docker-revisor curso-docker-revisor:1.0.0
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]
$ docker ps -a --filter name=curso-docker-revisor --format '{{.Names}} {{.Status}}'
curso-docker-revisor Exited (1) Less than a second ago
```

A imagem está certa; o contêiner iniciou e o `revisor` se recusou a trabalhar. O `revisor` é configurado com variáveis de ambiente, e a única obrigatória é `REVISOR_SERVICIOS`, a lista de serviços que ele deve verificar. Sem ela, imprime o que falta, com um exemplo, e sai com código 1. `docker ps -a` o mostra como `Exited (1)`: o processo terminou sozinho, com um erro próprio. Compare com o 137 da Lição 0: lá alguém matou o processo; aqui o processo decidiu ir embora. Saber ler essa diferença evita procurar o problema no lugar errado. Repare também que o contêiner ficou criado, embora tenha terminado: o script o apaga com `docker rm` antes de continuar, porque o nome está ocupado.

#### 3.6.3 Rodá-lo corretamente

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

O número de processo `1387809` muda a cada execução; todo o resto é estável, exceto, em outra execução, o tempo da tabela (o `sed` do comando está ali para escondê-lo se sair em milissegundos; nesta execução saiu `0s` e não houve nada a esconder).

`-e` passa uma variável de ambiente ao contêiner. Aqui o `revisor` verifica **a si mesmo**: a lista tem um único serviço, `propio`, que aponta para seu próprio health check. É uma forma de comprovar que tudo funciona sem outro contêiner, porque conectar contêineres entre si é tema de redes, e o plano do curso deixa isso para a Lição 8. A tabela diz `OK` e `200`.

`/salud` responde `"version":"desarrollo"`. Não é um erro: a imagem foi construída sem gravar uma versão no programa, e o `revisor` é feito para denunciar isso assim. Atenção à diferença: a **imagem** tem a tag `1.0.0`, mas o **programa** lá dentro não sabe em que versão está. São duas coisas diferentes, e uni-las é tarefa de uma lição posterior.

Agora as duas últimas linhas, que são as importantes desta seção. `docker exec ... id` diz `uid=10001`: o `USER` do Dockerfile funcionou. E `docker top`, que lista os processos de um contêiner vistos a partir do host, mostra **um único processo**: `revisor`, do usuário 10001. Essa linha única é a forma *exec* funcionando. Guarde-a na memória, porque na próxima seção vai aparecer uma com **duas** linhas.

### 3.7 Forma *exec* versus forma *shell*

#### 3.7.1 Duas formas de escrever a mesma coisa

`CMD` (e também `RUN` e `ENTRYPOINT`) pode ser escrito de duas maneiras ([referência do Dockerfile, formas *shell* e *exec*](https://docs.docker.com/reference/dockerfile/#shell-and-exec-form)):

- **Forma *exec***: uma lista em formato JSON, com colchetes e aspas duplas: `CMD ["revisor"]`. O Docker inicia esse programa diretamente, sem nada no meio.
- **Forma *shell***: um texto normal: `CMD revisor`. O Docker o envolve em um *shell*; no Linux, em `/bin/sh -c "revisor"`. A referência diz assim: diferentemente da forma *exec*, as instruções na forma *shell* «sempre usam um *shell*».

A forma *shell* existe por um motivo: com um *shell* no meio dá para usar variáveis (`$HOME`), pipes (`|`) e encadear comandos (`&&`). Por isso nos `RUN` ela é muito usada e não há problema em usá-la. O problema aparece quando ela é usada para o processo **principal** do contêiner, o que o `CMD` inicia.

Para ver isso, a lição traz uma cópia do Dockerfile em que só muda a última linha. Ela existe apenas para comparar:

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

No projeto, ela é salva como `Dockerfile.forma-shell`, e é construída com `docker build -f Dockerfile.forma-shell`: a opção `-f` diz ao Docker que receita usar quando não é a que se chama `Dockerfile`.

#### 3.7.2 A medição

Primeiro, a metade já vista: o final de `fig03_05.sh`, que para o contêiner com forma *exec* e mostra seus logs:

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

Os tempos (299 ms, e os `0s` e `1ms` de cada requisição) mudam a cada execução; a sequência de linhas é estável, embora o número de `GET /salud` dependa de quantas vezes `esperar_http` perguntou antes de o serviço responder. As duas linhas finais são as que importam: o `revisor` **recebeu** o sinal (`terminated` é o nome que o Go dá ao `SIGTERM`), terminou o que estava fazendo e se despediu. Tudo em 299 milissegundos nesta execução (161 na outra, dentro da máquina virtual).

Agora a outra metade. `fig03_07.sh` constrói a imagem com forma *shell*, roda-a com a mesma configuração, olha seus processos e a para:

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

As funções auxiliares do início são as mesmas de `fig03_05.sh`. A tag `1.0.0-shell` e o nome `curso-docker-revisor-shell` são de apoio: vivem só enquanto o script dura.

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

Os números de processo mudam; o tempo muda alguns milissegundos, mas sempre fica **um pouco acima de 10 segundos**; `ExitCode=137` e o log de uma única linha são estáveis. É a cena do começo, completa.

#### 3.7.3 O que aconteceu: o sinal que não chegou

Coloque as duas saídas de `docker top` lado a lado. Com forma *exec* havia **um** processo, `revisor`. Com forma *shell* há **dois**: `/bin/sh -c revisor` e, como filho dele, `revisor`. O *shell* iniciou primeiro, então o *shell* é o processo número 1 do contêiner (lembre-se da Lição 0: dentro do contêiner, o programa principal é o 1). O `revisor` ficou como o número 2 lá dentro, mais um filho.

Agora, a cadeia de `docker stop`, segundo sua documentação: ele envia ao processo principal do contêiner o sinal `SIGTERM`, espera um prazo que por padrão é de **10 segundos** no Linux e, se o processo continuar vivo, envia `SIGKILL` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)). O «processo principal» é o número 1. Com forma *exec*, o número 1 é o `revisor`, que foi escrito para tratar `SIGTERM`: recebe-o, desliga em ordem e sai. Com forma *shell*, o número 1 é `/bin/sh`.

Aqui se juntam dois fatos. O primeiro: o *shell* não repassa o sinal ao filho. A explicação da regra `JSONArgsRecommended` diz isso textualmente: com forma *shell*, o programa «roda como processo filho de um *shell*, que não repassa os sinais» ([Docker, `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/)). A referência do Dockerfile diz isso da forma *shell* de `ENTRYPOINT` com todas as letras: o executável «não será o PID 1 do contêiner e não receberá sinais Unix» ([referência, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). O segundo fato é do kernel e é mais sutil: o processo número 1 de um namespace de processos é especial. `docker stop` envia o sinal de fora do contêiner, do namespace do host, que é o «ancestral» do contêiner. Para esse caso, o manual do Linux diz que ao processo número 1 só chegam os sinais para os quais ele estabeleceu um handler, e que `SIGKILL` e `SIGSTOP` são a exceção: esses dois «são entregues à força» quando vêm de um namespace ancestral ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). O *shell* não instalou um handler para `SIGTERM`, então o sinal nem sequer o mata: ele se perde.

Com isso, a saída se lê sozinha:

1. `docker stop` envia `SIGTERM` ao número 1, o *shell*. O sinal se perde. O `revisor`, abaixo, nunca fica sabendo.
2. Passam-se 10 segundos. Esse é quase todo o tempo medido: 10.485 ms são os 10.000 do prazo mais o que levam o Docker, o kernel e, nesta execução, a ida e volta a partir do Mac (na execução dentro da máquina virtual foram 10.112 ms).
3. `docker stop` envia `SIGKILL`, que, segundo o manual de sinais, «não pode ser capturado, bloqueado nem ignorado» ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)). O *shell* e o `revisor` morrem de uma vez.
4. O Docker anota `ExitCode=137`. Isso já se sabe ler desde a Lição 0: 128 mais 9, e 9 é o número do `SIGKILL`.
5. O log tem uma única linha. Não diz `recibí terminated` porque o `revisor` não recebeu nada, e não diz `apagado limpio` porque ele não desligou: foi morto no meio do que fazia. Se naquele instante ele estava escrevendo um relatório, o relatório ficou pela metade.

Repare que o código do `revisor` é exatamente o mesmo nas duas imagens. Ele sabe desligar: demonstrou isso em alguns décimos de segundo. O que mudou é que, com um *shell* no meio, o sinal nunca chegou a ele. E não convém descobrir como o *shell* de cada imagem base se comporta: com a forma *exec* não há *shell* no meio e a pergunta desaparece.

> [!NOTE]
> 🔧 **Observação de engenharia 3.4**
> Dez segundos parecem pouco. Multiplique: uma atualização que para vinte contêineres um depois do outro perde mais de três minutos esperando, e em cada um corta-se o que ele estava fazendo. E o 137 contamina os alarmes: se cada desligamento normal termina em 137, no dia em que um contêiner morrer de verdade por falta de memória, com o mesmo 137, ninguém vai perceber.

#### 3.7.4 Quando um *shell* é necessário

Às vezes a inicialização precisa de algo que só um *shell* dá, como ler uma variável. A mesma página da regra dá duas saídas que continuam sendo honestas: escrever um pequeno script de inicialização e chamá-lo na forma *exec*, ou declarar o *shell* de propósito com a instrução `SHELL`. Nos dois casos o programa volta a ser filho de um *shell* e o sinal volta a ser responsabilidade de quem escreve, por exemplo com `exec` no final do script, que substitui o *shell* pelo programa. O `revisor` não precisa de nada disso: ele mesmo lê suas variáveis. A regra prática deste curso fica assim: **`CMD` e `ENTRYPOINT`, sempre na forma *exec***.

### 3.8 Revisar antes de construir: `docker build --check`

O que acabou de ser medido com um cronômetro o Docker pode detectar lendo a receita, sem construir nada. `docker build --check` roda as **verificações de build** (*build checks*): regras que procuram erros comuns no Dockerfile. A documentação diz que, em vez de executar os passos de build, o comando «só roda as verificações e informa o que encontra», e que elas existem desde a versão 1.8 da sintaxe do Dockerfile e o Buildx 0.15.0 ([Docker, «Build checks»](https://docs.docker.com/build/checks/)). O Docker instalado traz uma versão muito mais nova. `fig03_08.sh` revisa os dois Dockerfiles da lição:

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

O primeiro, o correto:

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

Os tempos e o *digest* longo depois de `dockerfile:1@sha256:` mudam (esse *digest* é a versão exata do intérprete da sintaxe que o Docker usou naquele dia); também mudam o tamanho em bytes de `transferring dockerfile`, que depende dos comentários do arquivo, e o nome do contexto na linha `#0` (aqui `colima`; no Mint, `default`). O estável é a sequência de passos e a última linha. Os passos numerados são o que o BuildKit fez: carregar a receita (`#1`), resolver o intérprete pedido pela linha `# syntax` (`#2` e `#3`), perguntar pelos dados da imagem base sem baixá-la inteira (`#4`) e ler o `.dockerignore` (`#5`). Não houve `COPY` nem `RUN`: nada foi construído. E no final, `Check complete, no warnings found.`

O segundo, o da forma *shell*:

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

Ali está a cena do começo, encontrada antes de construir. O aviso tem quatro partes. O nome da regra, `JSONArgsRecommended`, com o endereço de sua explicação. A frase: «argumentos JSON são recomendados em `CMD` para evitar comportamentos indesejados relacionados aos sinais do sistema operacional». O lugar exato: `Dockerfile.forma-shell:10`. E a linha apontada com `>>>`. Além disso, o comando sai com **código 1**: a documentação esclarece que, diferentemente de um build normal, com `--check` qualquer violação faz o comando terminar com um código diferente de zero. É isso que o torna útil em um servidor de build: um aviso interrompe o processo em vez de se perder na tela.

Um build **normal** (`docker build` sem `--check`) também roda essas verificações e mostra o mesmo aviso, mas termina com sucesso e constrói a imagem de qualquer forma. É fácil não vê-lo no meio de centenas de linhas. Por isso o hábito é rodar `--check` antes, de propósito. E para que nenhum build passe com avisos, o Dockerfile pode declarar isso em sua segunda linha, logo depois de `# syntax`, com `# check=error=true`: assim o aviso interrompe também um `docker build` normal ([Docker, «Build checks»](https://docs.docker.com/build/checks/)).

### 3.9 O que aparece em tutoriais antigos

Vão aparecer Dockerfiles de outras pessoas, e alguns trazem coisas que este curso não usa. Convém reconhecê-las:

- **`MAINTAINER nombre`.** Declarava o autor da imagem. Está obsoleta: a referência indica que `LABEL` é «uma versão muito mais flexível» e que deve ser usada no lugar, por exemplo `LABEL org.opencontainers.image.authors="..."` ([referência, `MAINTAINER`](https://docs.docker.com/reference/dockerfile/#maintainer-deprecated)).
- **`ADD` para copiar arquivos locais.** `ADD` faz mais que `COPY`: também baixa da internet e descompacta. Essa mágica surpreende. O guia de boas práticas usa `COPY` para copiar e reserva `ADD` para quando é realmente necessário trazer algo remoto ([boas práticas, `ADD` ou `COPY`](https://docs.docker.com/build/building/best-practices/#add-or-copy)). Neste curso, `ADD` não é necessário.
- **`FROM algo:latest` ou `FROM algo` sem tag.** Já se sabe por que não (3.3).
- **`CMD comando` e `ENTRYPOINT comando` na forma *shell*.** Já se sabe medir por que não (3.7).
- **Instalar `sudo` na imagem.** O guia o desaconselha por seu comportamento imprevisível com os terminais e com o repasse de sinais. Se algo precisa de `root` ao construir, vai antes do `USER`; ao rodar, não deveria precisar.

## O erro que se vai ver

Esta lição tem três erros, do menos ao mais grave. Os três já foram provocados.

**1. O aviso de `docker build --check`.**

```text
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
Dockerfile.forma-shell:10
```

Lê-se assim: há uma regra que não é cumprida (`JSONArgsRecommended`); a explicação dela está no endereço; e a linha 10 de `Dockerfile.forma-shell` é a culpada. Corrige-se trocando `CMD revisor` por `CMD ["revisor"]`. Se um *shell* for realmente necessário na inicialização, veja 3.7.4. O que não se faz é ignorar o aviso porque «a imagem foi construída bem»: ela é construída bem e desliga mal.

**2. O contêiner que sai com 1 ao iniciar.**

```text
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
curso-docker-revisor Exited (1) Less than a second ago
```

Lê-se assim: o contêiner iniciou, o programa leu sua configuração, não encontrou algo obrigatório e saiu por conta própria com 1. Não é um problema da imagem nem do Docker. A primeira pergunta diante de um `Exited (1)` recém-iniciado é sempre `docker logs <contenedor>`: ali quase sempre está a causa, escrita pelo próprio programa. Corrige-se passando a variável com `-e`.

**3. O `docker stop` de 10 segundos e o código 137.**

```text
tardó 10485 ms
ExitCode=137
```

Lê-se assim: o processo principal não tratou o `SIGTERM`, o prazo acabou e o Docker o matou com `SIGKILL` (137 = 128 + 9). Antes de culpar o programa, olhe `docker top <contenedor>`: se a primeira linha for `/bin/sh -c ...`, o sinal ficou no *shell*. Corrige-se com `CMD` na forma *exec*. Há outras causas possíveis de um 137 — a falta de memória da Lição 0 é a outra grande, e se distingue porque `docker inspect` diz `OOMKilled=true` —, mas quando o tempo de `docker stop` é exatamente o prazo, a suspeita principal é esta. O que **não** se faz é aumentar o prazo de `docker stop` para que «dê tempo»: um prazo mais longo só alonga a espera, porque o sinal continua sem chegar.

## O hábito de segurança da lição

**O primeiro Dockerfile já traz `USER`, `.dockerignore` e uma tag com versão.** Os três são baratos no primeiro dia e caros de acrescentar depois, quando já há contêineres rodando e gente que depende deles.

- **`USER 10001:10001`** evita que um erro no `revisor` — ou em qualquer biblioteca que ele use — dê a quem o explorar o usuário 0 do kernel. Isso foi comprovado com `docker exec ... id`.
- **`.dockerignore`** evita o acidente de 3.5: um `.env`, uma chave ou o histórico do `.git` colocados em uma imagem que depois viaja para outras máquinas. Isso foi comprovado olhando `/src` dentro da imagem.
- **A tag com versão e o prefixo** evitam rodar «qualquer coisa que se chame assim»: sabe-se que imagem está rodando e ela pode ser apagada sem mexer no que é dos outros.

## O que se faz errado

**Escrever `CMD` na forma *shell* «porque é mais fácil de ler».** Lê-se mais fácil e desliga pior: 10 segundos de espera e um 137 em cada `docker stop`. A forma *exec* são dois colchetes e umas aspas.

**Usar `latest`, ou não colocar tag, que é a mesma coisa.** `latest` não quer dizer «a mais nova»; quer dizer «sem tag». No dia do problema, não vai dar para saber que versão estava rodando.

**Nomear a imagem com um nome genérico como `revisor` ou `app`.** Conflita com imagens de outros projetos na mesma máquina e toma o nome delas sem avisar.

**Deixar o Dockerfile sem `USER` porque «é só para testar».** O que é para testar termina em produção com o mesmo Dockerfile. Custa uma linha.

**`COPY . .` sem `.dockerignore`.** Tudo o que está na pasta viaja e fica na imagem, inclusive os arquivos que ninguém se lembra de ter deixado ali.

**Usar `RUN` para iniciar o serviço.** `RUN` é executado ao construir: o build ficaria esperando o servidor para sempre. O que é executado ao rodar vai em `CMD`.

**Achar que `EXPOSE` publica a porta.** Só anota. Sem `-p` ao rodar, ninguém de fora chega. E com `-p`, a porta é publicada em `127.0.0.1`, como se aprendeu na Lição 2.

**Ignorar os avisos do build.** Um build normal mostra o aviso de `JSONArgsRecommended` e termina com sucesso. Rodar `docker build --check` antes transforma o aviso em um erro que não pode passar despercebido.

## Exercícios

Faça-os em ordem. Antes de rodar cada um, escreva no [diário de bordo](bitacora.md) o que se espera que aconteça; comparar depois é metade do aprendizado. Ao terminar, apague o que foi criado: tudo leva o prefixo `curso-docker-`.

### Exercício 1 — Ao construir ou ao rodar?

Sem olhar a tabela de 3.2.2, classifique cada linha: age **ao construir**, só **anota algo para rodar**, ou as duas coisas?

1. `FROM golang:1.27.3-trixie`
2. `COPY . .`
3. `RUN go build -o /usr/local/bin/revisor ./cmd/revisor`
4. `USER 10001:10001`
5. `EXPOSE 8080`
6. `CMD ["revisor"]`

E uma pergunta capciosa: mudando a ordem e colocando `USER 10001:10001` **antes** do `RUN go build`, com que usuário a compilação é executada?

### Exercício 2 — Um `.dockerignore` próprio (projeto)

Trabalhe na pasta `~/curso-docker/revisor` (a do bloco «Na pasta local» de 3.6.1). Afaste por um momento o `.dockerignore` da lição com `mv .dockerignore ../dockerignore-leccion3` e crie ali três coisas: um arquivo `.env` com um segredo falso, um arquivo `notas.md` e uma pasta `secretos/` com um arquivo dentro. Construa `curso-docker-revisor:1.0.0-ej2` e liste `/src` dentro da imagem com `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src`. Depois escreva um `.dockerignore` novo que deixe de fora as três coisas, além de tudo o que o da lição excluía (ele está em `../dockerignore-leccion3`), reconstrua com a mesma tag e liste de novo. O exercício se autocorrige: terminou quando `/src` mostra exatamente `cmd`, `go.mod` e `internal`. No final, `docker rmi curso-docker-revisor:1.0.0-ej2`. O `.dockerignore` ampliado pode ficar: ele exclui tudo o que o da lição excluía e algo mais, então a `curso-docker-revisor:1.0.0` não muda.

### Exercício 3 — O cronômetro na máquina local

Rode `fig03_05.sh` e `fig03_07.sh` no Mint (depois da Lição 1 e com a imagem do Go baixada). Anote no diário de bordo, na linha que a Lição 3 traz para isso, os dois tempos de `docker stop`. Antes de rodá-los, preveja:

1. Qual dos dois tempos vai mudar mais de uma execução para outra, e qual vai ficar quase igual?
2. Que número vai sair em `ExitCode` na forma *shell*? E que número se esperaria na forma *exec*, sabendo que o `revisor` foi escrito para terminar com 0 depois de um desligamento limpo? Confira acrescentando, depois do `docker stop` de `fig03_05.sh`, um `docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor`.

### Exercício 4 — Corrigir o Dockerfile alheio

Um colega passa este Dockerfile para o `revisor`. Encontre **seis** problemas, cinco no arquivo e um que falta ao lado dele; diga que acidente cada um pode causar e escreva a versão corrigida. Depois confira a versão corrigida com `docker build --check`: ele precisa dizer `Check complete, no warnings found.`

```dockerfile
FROM golang
MAINTAINER alguien@ejemplo.invalid
COPY . /src
RUN cd /src && go build -o /usr/local/bin/revisor ./cmd/revisor
EXPOSE 8080
CMD revisor
```

Dica: `docker build --check` encontra dois dos seis; os outros quatro é preciso encontrar sem ajuda.

## Soluções

### Solução 1

1. **Ao construir.** Traz todo o conteúdo da imagem base.
2. **Ao construir.** Copia os arquivos do contexto para a imagem.
3. **Ao construir.** Compila e deixa o executável na imagem. Não é executado de novo ao rodar.
4. **As duas coisas.** Anota o usuário com que o contêiner vai rodar e, além disso, afeta os `RUN` que vierem depois no Dockerfile.
5. **Só anota.** Não publica nada (3.2).
6. **Só anota** o processo que cada contêiner vai iniciar.

A pergunta capciosa: com o usuário **10001**, porque `USER` muda o usuário de tudo o que vem depois, também ao construir. E a compilação falha. O Go tenta criar seu cache na pasta pessoal do usuário e, como o 10001 não existe em `/etc/passwd`, essa pasta é `/`, onde ele não consegue escrever. Medido na máquina desta lição com `docker build --progress=plain` (o `#10` e o `0.881` são o número do passo e os segundos, e mudam):

```text
#10 0.881 failed to initialize build cache at /.cache/go-build: mkdir /.cache: permission denied
ERROR: failed to build: failed to solve: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Mesmo que o cache funcionasse, ele também não conseguiria escrever em `/usr/local/bin`. Por isso o `USER` vem depois de compilar.

### Solução 2

Um `.dockerignore` que cumpre o pedido:

```text
.git
.env
*.tar
*.md
secretos/
Dockerfile*
.dockerignore
```

Com ele, `ls -A /src` dentro da imagem mostra só `cmd`, `go.mod` e `internal`, igual ao segundo bloco de `fig03_04.sh`. Se na lista ainda aparecer `notas.md` ou `secretos`, confira se o padrão está bem escrito e se o arquivo `.dockerignore` está na raiz do contexto, junto do `Dockerfile`, e não em uma subpasta. Se aparecer `.dockerignore` ou `Dockerfile`, faltaram as duas últimas linhas. Uma variante também válida é trocar `*.md` por `notas.md`: exclui só esse arquivo. A de cima é mais previdente, porque o `revisor` não precisa de nenhum `.md` para ser compilado.

### Solução 3

1. O tempo da forma *exec* muda mais de uma execução para outra (dezenas ou centenas de milissegundos, conforme o quanto a máquina está ocupada); o da forma *shell* fica quase igual, sempre um pouco acima de 10.000 ms, porque quase tudo é o prazo fixo de `docker stop`.
2. Na forma *shell*, `ExitCode=137`, como em `fig03_07.sh`. Na forma *exec*, `ExitCode=0`: o `revisor` recebe `SIGTERM`, escreve `apagado limpio` e seu código termina com 0. Se a execução der outro número, olhe `docker logs`: se não aparecer `apagado limpio`, o sinal não chegou, e a primeira suspeita é que o Dockerfile está na forma *shell*.

### Solução 4

Os cinco problemas do arquivo:

1. **`FROM golang` sem tag**, que é `golang:latest`: cada build pode usar outra versão do Go. Correção: `FROM golang:1.27.3-trixie`.
2. **`MAINTAINER`**, obsoleta. Correção: removê-la, ou usar `LABEL org.opencontainers.image.authors="..."`.
3. **`RUN cd /src && ...` em vez de `WORKDIR`.** Funciona naquela linha, mas o `cd` se perde depois, e o contêiner inicia em `/`. Correção: `WORKDIR /src` e `COPY . .`.
4. **Sem `USER`**: o `revisor` rodaria como `root`. Correção: `USER 10001:10001` depois de compilar.
5. **`CMD revisor` na forma *shell***: 10 segundos e 137 em cada `docker stop`. Correção: `CMD ["revisor"]`. É exatamente o que `docker build --check` aponta.

E o sexto, o que não está no arquivo: **falta o `.dockerignore`**, e com `COPY . /src` todo o contexto entra na imagem. A versão corrigida é o `fig03_01.Dockerfile` desta lição mais o `fig03_03.dockerignore`.

`docker build --check .` sobre o Dockerfile original encontra dois dos seis. Medido na máquina desta lição (mostram-se só as linhas dos avisos):

```text
Check complete, 2 warnings have been found!
WARNING: MaintainerDeprecated - https://docs.docker.com/go/dockerfile/rule/maintainer-deprecated/
Maintainer instruction is deprecated in favor of using label
WARNING: JSONArgsRecommended - https://docs.docker.com/go/dockerfile/rule/json-args-recommended/
JSON arguments recommended for CMD to prevent unintended behavior related to OS signals
```

`MaintainerDeprecated` é o problema 2: a regra diz que `MAINTAINER` está obsoleta e que se deve usar um rótulo (`LABEL`) no lugar ([Docker, `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/)). `JSONArgsRecommended` é o problema 5. Os outros quatro (`latest`, o `cd`, a falta de `USER` e a do `.dockerignore`) não são detectados por nenhuma das regras que rodaram aqui: por isso o `--check` ajuda, mas não substitui ler a receita. A versão corrigida precisa dizer `Check complete, no warnings found.`

## Como sei que consegui

Marque cada ponto só se ele foi comprovado na própria máquina:

- [ ] `docker build --check .` em `~/curso-docker/revisor` termina com `Check complete, no warnings found.` e código 0.
- [ ] `docker image ls 'curso-docker-revisor'` mostra `curso-docker-revisor` com a tag `1.0.0`, e o tamanho dela ficou anotado no diário de bordo (na execução desta lição, 1.45 GB).
- [ ] Sem `REVISOR_SERVICIOS`, o contêiner fica `Exited (1)` e `docker logs` diz o que falta.
- [ ] Com a variável, `curl -s http://127.0.0.1:8080/salud` responde `{"estado":"vivo","version":"desarrollo"}`.
- [ ] `docker exec curso-docker-revisor id` diz `uid=10001 gid=10001 groups=10001`.
- [ ] `docker top curso-docker-revisor -o pid,user,args` mostra **um único** processo, `revisor`.
- [ ] `docker stop curso-docker-revisor` leva menos de um segundo e `docker logs` termina com `revisor: apagado limpio`.
- [ ] Com a imagem da forma *shell*, foram medidos os 10 segundos e o 137, e dá para explicar com `docker top` por quê.
- [ ] Dentro da imagem, `ls -A /src` não mostra `.env`, `.git` nem `Dockerfile`.
- [ ] Ao terminar, `docker ps -a --filter name=curso-docker-revisor` não mostra nada, e `docker image ls 'curso-docker-revisor'` mostra só `curso-docker-revisor:1.0.0`, a construída na pasta local e que a Lição 4 usa.

## Resumo

Responda sem olhar a lição:

1. O que é um Dockerfile, o que é o contexto e quem faz o trabalho de construir?
2. Que instruções agem ao construir e quais só anotam algo para rodar?
3. O que a tag `latest` significa de verdade? Por que a imagem do curso se chama `curso-docker-revisor:1.0.0` e não `revisor:1.0.0`?
4. Com que usuário uma imagem roda se ninguém escreveu `USER`? Por que um número basta?
5. O que o `.dockerignore` faz e o que acontece com um `.env` sem ele?
6. Que diferença há entre `CMD ["revisor"]` e `CMD revisor`? O que `docker top` mostra em cada caso?
7. Por que, com a forma *shell*, `docker stop` leva 10 segundos e deixa 137? O que é o 137?
8. O que `docker build --check` faz e com que código sai se encontrar algo?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [Referência do Dockerfile](https://docs.docker.com/reference/dockerfile/): as instruções `FROM`, `WORKDIR`, `COPY`, `RUN`, `USER`, `EXPOSE`, `CMD`, `ENTRYPOINT` e `MAINTAINER`; as formas *shell* e *exec*; a diretiva `syntax`.
- [Docker, «Build context»](https://docs.docker.com/build/concepts/context/): o contexto de build e os arquivos `.dockerignore`.
- [Docker, «Build checks»](https://docs.docker.com/build/checks/): `docker build --check`, seu código de saída e as versões mínimas.
- [Docker, regra `MaintainerDeprecated`](https://docs.docker.com/reference/build-checks/maintainer-deprecated/): o aviso sobre `MAINTAINER` do exercício 4.
- [Docker, regra `JSONArgsRecommended`](https://docs.docker.com/reference/build-checks/json-args-recommended/): por que a forma *shell* não repassa os sinais, e as duas alternativas quando um *shell* é necessário.
- [Docker, boas práticas para construir imagens](https://docs.docker.com/build/building/best-practices/): `USER`, `sudo`, `ADD` versus `COPY`, tags mutáveis e `.dockerignore`.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM`, o prazo de 10 segundos e `SIGKILL`.
- [`docker image tag`](https://docs.docker.com/reference/cli/docker/image/tag/): as partes do nome de uma imagem e a tag `latest` padrão.
- [Docker, «Running containers»](https://docs.docker.com/engine/containers/run/): substituir o `CMD` a partir de `docker run`.
- [golang no Docker Hub](https://hub.docker.com/_/golang): a tag `1.27.3-trixie` e seus apelidos, e o significado de *trixie*.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões de «Sobre as execuções».
- [pid_namespaces(7), manual do Linux](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html): os sinais que o processo número 1 de um namespace pode receber.
- [signal(7), manual do Linux](https://man7.org/linux/man-pages/man7/signal.7.html): os números de `SIGTERM` (15) e `SIGKILL` (9), e que `SIGKILL` não pode ser capturado.
- [Colima](https://github.com/abiosoft/colima): a ferramenta com que os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **BuildKit** | o builder de imagens que o Docker usa; faz parte do daemon |
| **contexto de build** | os arquivos que o build pode usar; quase sempre, uma pasta |
| **Dockerfile** | a receita em texto com a qual se constrói uma imagem |
| **`.dockerignore`** | a lista do que não viaja no contexto nem pode entrar na imagem |
| **tag** | a parte do nome de uma imagem depois dos dois-pontos; diz que versão ela é |
| **forma *exec*** | instrução escrita como lista JSON: `CMD ["revisor"]`; inicia o programa sem *shell* |
| **forma *shell*** | instrução escrita como texto: `CMD revisor`; é envolvida por `/bin/sh -c` |
| **imagem base** | a imagem da qual outra parte, a do `FROM` |
| **`latest`** | a tag que o Docker coloca quando nenhuma é informada; não significa «a mais nova» |
| **PID 1** | o primeiro processo de um contêiner; o que recebe o sinal de `docker stop` |
| **verificação de build** (*build check*) | regra que procura erros comuns em um Dockerfile sem construí-lo |
| **`SIGTERM`** | o sinal 15: «termine, por favor»; o que `docker stop` envia primeiro |
| **`SIGKILL`** | o sinal 9: morte imediata; não pode ser capturado; deixa o código 137 |

---

**Próxima:** [Lição 4 — Camadas, cache e contexto](04-capas-cache-contexto.md)
