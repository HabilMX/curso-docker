# Lição 5 — Multi-stage: de gigabytes a megabytes

São 7h50 da manhã e a filial abre às 9h. O `revisor` precisa ficar instalado antes desse horário no servidor da sala de comunicações, que se conecta ao resto do mundo por um link modesto. Dispara-se o download da imagem e a barra avança a conta-gotas: a imagem pesa 1.32 GB. Durante a espera, chega uma mensagem da pessoa de segurança que revisa cada instalação: «Antes de iniciar, pode me explicar por que essa imagem traz `gcc`, `git`, `curl`, `apt-get` e um *shell*? O `revisor` é um único programa. Se alguém conseguir entrar nesse contêiner, vai encontrar uma oficina completa: com o que baixar ferramentas, com o que compilá-las e com o que executá-las». Há quarenta minutos e dois problemas que parecem diferentes: a imagem é enorme e a imagem é perigosa. Esta lição mostra que são o mesmo problema, e que ele se resolve com um único Dockerfile mais bem escrito: a imagem que sai daqui pesa 16.1 MB, não tem *shell* e não roda como `root`.

**Tempo:** 2 × 45 min

**O que se constrói:** a imagem final do `revisor`, `curso-docker-revisor:1.2.0`: um Dockerfile de quatro estágios que compila e testa em uma imagem grande e entrega em uma mínima, com a base fixada por versão e por *digest*. Pesa 16.1 MB, não tem *shell* nem compilador e roda com o usuário sem privilégios 65532.

**O que se aprende:** o que é um build em vários estágios (*multi-stage*) e como se passam arquivos de um estágio para outro com `COPY --from`; como colocar os testes dentro do build para que um teste quebrado o interrompa, e o erro silencioso que os pula; o que é uma imagem base mínima sem *shell* (*distroless*) e o que muda ao operá-la; o que é um *digest* e por que a base é fixada com ele além da tag; e por que um binário que não é estático não inicia em uma imagem mínima, com a mensagem exata que vai aparecer.

**De onde se parte.** Da [Lição 4](04-capas-cache-contexto.md) traz-se a imagem `curso-docker-revisor:1.1.0`: o mesmo `revisor` da Lição 3, mas com o Dockerfile ordenado para o cache (primeiro `go.mod`, depois o código) e com o cache de compilação do Go em uma montagem que não fica dentro da imagem. Já se sabe ler `docker history`, o que é uma camada e o que viaja no contexto. Traz-se também um número anotado no diário de bordo: essa imagem pesa **1.32 GB**. Da [Lição 3](03-primer-dockerfile.md) trazem-se `USER`, a forma *exec* e a pasta `~/curso-docker/revisor`, onde vive o projeto. E da [Lição 2](02-contenedores-dia-a-dia.md) traz-se uma lembrança: tentou-se entrar com `docker exec` no serviço de teste e não havia `sh`. Aqui vai ficar claro por quê, e o mesmo vai ser feito com o `revisor`.

**O que esta lição não faz.** Não mexe no código do `revisor` nem acrescenta funções: o programa é o mesmo das Lições 3 e 4. Não coloca versão no binário (por isso `revisor version` ainda diz `desarrollo`; a versão e a configuração são da [Lição 6](06-configuracion-y-secretos.md)). Não acrescenta `HEALTHCHECK` nem faz o hardening da execução (sistema de arquivos somente leitura, capabilities removidas): isso é a Lição 7. E não constrói para várias plataformas nem faz varredura de vulnerabilidades: isso é a Lição 10. Aqui o trabalho é um só: que o que se **entrega** seja só o que é **necessário para rodar**.

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4, a mesma base do Linux Mint 22, o sistema de referência do curso. Os scripts foram executados **dentro** dessa máquina virtual, com Docker 29.2.1 (cliente e daemon) e Buildx v0.31.1. O curso foi planejado com o Docker Engine 29.8.2, e a versão mais recente publicada naquele dia era a 29.9.2, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)); nada desta lição muda entre essas versões. A mesma máquina era usada ao mesmo tempo por outras execuções do curso, então, para não haver conflito, cada script foi lançado com outro prefixo de nomes e outra porta, com as variáveis `PREFIJO` e `PUERTO` que todos trazem, e a saída foi salva passando por um `sed` que devolve os nomes do curso. O comando foi, para cada figura: `PREFIJO=curso-docker-l05- PUERTO=18050 ./fig05_NN.sh 2>&1 | sed -e 's/curso-docker-l05-/curso-docker-/g' -e 's/127\.0\.0\.1:18050/127.0.0.1:8080/g'`. Nada disso é necessário no Mint: sem variáveis, os scripts usam os nomes e a porta do curso, e o que imprimem é o que aparece aqui. O que **muda** no Mint, e é avisado onde aparece: os números de processo (PID), os tempos, as datas dos arquivos e, se a máquina for Intel ou AMD, a arquitetura: onde aqui está `arm64` ou `aarch64`, lá estará `amd64` ou `x86_64`, e os tamanhos podem variar alguns megabytes. Os programas estão em [`programas/05-multi-stage/`](../programas/05-multi-stage), cada um com sua saída ao lado; `inicio/` guarda o `Dockerfile` e o `.dockerignore` com que a Lição 4 termina, e `estado/`, os que ficam ao terminar esta.

## Ao terminar, será possível

- Explicar, com os números da própria imagem, por que uma imagem de um único estágio pesa mais de um gigabyte quando o programa que ela leva pesa menos de dez megabytes.
- Escrever um Dockerfile de vários estágios com nome (`FROM ... AS`), passar um arquivo de um estágio para outro com `COPY --from` e construir só até um estágio com `--target`.
- Colocar os testes dentro do build de modo que um teste quebrado o interrompa, e demonstrar com uma execução por que o estágio do binário deve sair do estágio de testes e não do de compilação.
- Mostrar com `docker exec`, `docker inspect` e `docker top` que a imagem final não tem *shell* e não roda como `root`, e listar todos os seus arquivos sem entrar nela.
- Fixar uma imagem base por tag e por *digest*, e dizer o que cada um garante.
- Ler a mensagem `exec /revisor: no such file or directory`, explicar qual é o arquivo que falta e corrigir isso com `CGO_ENABLED=0`.

## O porquê antes do como

Na Lição 3, o `revisor` foi construído em um único estágio: partiu-se da imagem do Go, copiou-se o código, compilou-se e disse-se ao Docker o que rodar. Funciona, e era a forma correta de começar porque tudo estava à vista. Mas essa receita tem um defeito de design que nenhum ajuste de ordem corrige: **a imagem que serve para construir e a imagem que é entregue são a mesma**. Tudo o que foi necessário para compilar — o compilador do Go, o de C, um Debian completo com seu gerenciador de pacotes, as ferramentas de rede — fica dentro da imagem que vai para o servidor, embora o `revisor` não use nada disso ao rodar.

Isso custa em três lugares ao mesmo tempo, e a cena do começo os junta:

1. **Em tempo e em disco.** Cada servidor que rodar o `revisor` baixa e guarda mais de um gigabyte. Em um link lento, essa é a diferença entre chegar ou não às 9h.
2. **Em segurança.** Cada programa que viaja na imagem é algo que um intruso pode usar. Um contêiner com *shell*, `curl` e um compilador poupa a quem entra quase todo o trabalho. Um contêiner que só tem o `revisor` não deixa nada com que continuar.
3. **Em ruído.** Um scanner de vulnerabilidades revisa todos os pacotes da imagem. Se a imagem traz duzentos pacotes do Debian que o `revisor` nunca toca, o relatório se enche de achados que não importam e esconde os que importam. O próprio projeto das imagens mínimas do Google diz assim: uma imagem sem o que sobra «melhora a relação sinal-ruído dos scanners» ([distroless](https://github.com/GoogleContainerTools/distroless)).

A solução que vai ser construída separa os dois trabalhos: uma imagem grande para **construir e testar**, que nunca sai da máquina local, e uma imagem mínima para **rodar**, que é a que se entrega. As duas são descritas no mesmo Dockerfile, e a passagem de uma para a outra é uma única linha: copiar o binário. A documentação do Docker resume isso em uma frase: com os builds em vários estágios «é possível copiar seletivamente artefatos de um estágio para outro, deixando para trás tudo o que não se quer na imagem final» ([Docker, «Multi-stage builds»](https://docs.docker.com/build/building/multi-stage/)).

A lição tem oito partes, nesta ordem:

1. **O que há dentro de 1.32 GB** (5.1): medir antes de reduzir.
2. **A ideia dos estágios** (5.2): `FROM ... AS`, `COPY --from` e `--target`.
3. **O Dockerfile de quatro estágios** (5.3), linha por linha.
4. **Construir e medir** (5.4): de 1.32 GB para 16.1 MB.
5. **Os testes dentro do build** (5.5), com o erro silencioso desta lição.
6. **A base mínima** (5.6): sem *shell* e sem `root`.
7. **Versão e *digest*** (5.7): fixar a base de verdade.
8. **O binário que não inicia** (5.8), o erro principal da lição.

Com esse destino em mente, isto é o que vai aparecer na seção 5.4, ao colocar lado a lado a imagem com que se chega e a que é construída aqui:

```text
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB
```

## Os conceitos

### 5.1 O que há dentro de 1.32 GB

#### 5.1.1 Medir antes de reduzir

Antes de mudar uma única linha, convém saber o que há na imagem e que parte desse peso é o `revisor`. Reduzir sem medir é adivinhar. O programa `fig05_01.sh` constrói a imagem da Lição 4 a partir de `inicio/` e pergunta três coisas a ela: quanto o `revisor` pesa, que outras ferramentas viajam com ele e quanto ocupam as pastas mais pesadas:

```bash
#!/usr/bin/env bash
# fig05_01.sh — Qué hay dentro de la imagen con la que termina la Lección 4.
# La construye desde inicio/ (el Dockerfile y el .dockerignore de la Lección 4),
# mide su tamaño y busca adentro lo que el revisor necesita para correr y lo que
# no. Borra lo que crea al salir.
set -euo pipefail
# PREFIJO cambia el principio de todos los nombres (imágenes, contenedores y la
# caché de compilación). Con el valor por omisión, el guion usa los nombres del
# curso; otro valor sirve para que dos corridas en la misma máquina no choquen.
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/inicio/Dockerfile" "$AQUI/inicio/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

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
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
IMAGEN="${PREFIJO}revisor:1.1.0"
MIRAR="docker run --rm --name ${PREFIJO}mirar $IMAGEN"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "La imagen de la Lección 4"
muestra "docker build -q -t $IMAGEN . >/dev/null && docker image ls $IMAGEN --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Lo único que el revisor necesita para correr"
muestra "$MIRAR ls -lh /usr/local/bin/revisor"

titulo "Lo demás que viaja con él"
muestra "$MIRAR sh -c 'for p in sh bash apt-get gcc go git curl; do printf \"%-8s %s\n\" \$p \"\$(command -v \$p || echo no-esta)\"; done'"
muestra "$MIRAR du -sh /usr/local/go /usr/lib /usr/bin /usr/share"
muestra "$MIRAR sh -c 'dpkg-query -W | wc -l'"
muestra "$MIRAR id"
```

Antes da saída, as linhas novas do script. A estrutura é a mesma dos scripts da Lição 3: monta-se o projeto em uma pasta temporária (`mktemp -d`) com o código que o curso entrega mais os arquivos da lição, definem-se as funções auxiliares `titulo` e `muestra` (que imprime cada comando com `$ ` na frente antes de executá-lo, para que se saiba o que produziu cada linha), e um `trap ... EXIT` apaga a imagem e a pasta ao sair. O `sed` do início muda o nome do cache de compilação só se o `PREFIJO` mudar; com o valor padrão, não muda nada. `MIRAR` é uma abreviação para não repetir `docker run --rm --name ... imagen` em cada pergunta.

```text
$ ./fig05_01.sh

## La imagen de la Lección 4
$ docker build -q -t curso-docker-revisor:1.1.0 . >/dev/null && docker image ls curso-docker-revisor:1.1.0 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB

## Lo único que el revisor necesita para correr
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 ls -lh /usr/local/bin/revisor
-rwxr-xr-x 1 root root 9.5M Oct 21 08:46 /usr/local/bin/revisor

## Lo demás que viaja con él
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'for p in sh bash apt-get gcc go git curl; do printf "%-8s %s\n" $p "$(command -v $p || echo no-esta)"; done'
sh       /usr/bin/sh
bash     /usr/bin/bash
apt-get  /usr/bin/apt-get
gcc      /usr/bin/gcc
go       /usr/local/go/bin/go
git      /usr/bin/git
curl     /usr/bin/curl
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 du -sh /usr/local/go /usr/lib /usr/bin /usr/share
277M	/usr/local/go
276M	/usr/lib
120M	/usr/bin
140M	/usr/share
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 sh -c 'dpkg-query -W | wc -l'
208
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:1.1.0 id
uid=10001 gid=10001 groups=10001
```

A data e a hora do arquivo mudam a cada build; em uma máquina Intel ou AMD os tamanhos podem variar alguns megabytes. O resto sai igual.

#### 5.1.2 Ler os números

Coloque os números em uma única frase e o problema aparece sozinho: **o `revisor` pesa uns 10 MB e viaja em uma imagem de 1.32 GB**. Menos de um por cento do que se baixa é o programa que vai rodar. Os 99 % restantes são bagagem:

- **O compilador do Go**, em `/usr/local/go`: 277 MB. (`ls -lh` e `du -sh` contam em potências de 1024: os `9.5M` do `revisor` são 9,5 MiB, uns 10 MB; `docker image ls` conta em potências de 1000.) Foi necessário para compilar; ao rodar, o `revisor` não o usa nem uma vez.
- **Um Debian quase completo**: 208 pacotes instalados (`dpkg-query -W` lista um por linha e `wc -l` os conta), com suas bibliotecas em `/usr/lib` e seus programas em `/usr/bin`.
- **As ferramentas que preocupavam a pessoa de segurança da cena**: um *shell* (`sh` e `bash`), um gerenciador de pacotes (`apt-get`), um compilador de C (`gcc`), `git` e `curl`. Cada uma está ali por um bom motivo para **construir**: a imagem oficial do Go as traz para que compilar funcione com quase qualquer projeto. Para **rodar** o `revisor`, nenhuma.

A última linha é um bom lembrete de que a Lição 3 não foi em vão: a imagem roda com o usuário `10001`, não com `root`. Mas esse usuário tem à mão `curl` para baixar o que quiser e `sh` para executar. Sem privilégios, sim; desarmado, não.

Repare também no que **não** está na lista: nada disso se resolve apagando arquivos. Acrescentando ao Dockerfile um `RUN rm -rf /usr/local/go`, a imagem não diminui nem um byte: a Lição 4 ensinou que cada instrução acrescenta uma camada por cima das anteriores, e que o que uma camada apaga continua guardado na camada de baixo. Apagar em uma camada nova só esconde. Para que o compilador não viaje, a imagem final precisa **nascer sem ele**.

> [!NOTE]
> 🔧 **Observação de engenharia 5.1**
> Meça antes de otimizar, e meça a proporção, não só o total. «A imagem pesa 1.32 GB» convida a procurar onde cortar. «O programa é menos de 1 % da imagem» diz que não há nada a cortar: é preciso trocar de imagem.

### 5.2 A ideia dos estágios

#### 5.2.1 Vários `FROM` em um mesmo Dockerfile

Até agora cada Dockerfile tinha um único `FROM`, e tudo o que vinha depois se empilhava sobre essa base. A ideia central desta lição é que **um Dockerfile pode ter vários `FROM`**. Cada `FROM` começa um **estágio** novo, do zero, com sua própria base. A referência do Dockerfile diz assim: `FROM` «pode aparecer várias vezes em um mesmo Dockerfile» para criar várias imagens ou para usar um estágio como dependência de outro ([referência do Dockerfile, `FROM`](https://docs.docker.com/reference/dockerfile/#from)).

O que torna essa ideia útil são três peças, que aparecem em um fragmento de quatro linhas antes do Dockerfile completo:

```dockerfile
FROM golang:1.27.3-trixie AS compilacion
RUN ... go build -o /out/revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=compilacion /out/revisor /revisor
```

Este bloco é um fragmento para ler, não um programa: faltam linhas para ele ser construído. O que ele mostra:

1. **O nome do estágio.** `AS compilacion`, no final do `FROM`, dá nome ao estágio. A documentação recomenda nomeá-los assim, em vez de se referir a eles por número ([Docker, «Name your build stages»](https://docs.docker.com/build/building/multi-stage/#name-your-build-stages)). Um nome sobrevive a alguém acrescentar ou tirar estágios; um número, não.
2. **A cópia entre estágios.** `COPY --from=compilacion` copia um arquivo **de outro estágio**, não do contexto. A referência esclarece que `--from` aceita um estágio, uma imagem ou um contexto com nome ([referência, `COPY --from`](https://docs.docker.com/reference/dockerfile/#copy---from)). Aqui, o estágio de compilação deixa o binário em `/out/revisor` e o último estágio o recolhe.
3. **A imagem que sai.** A imagem que `docker build` constrói é a do **último** estágio. Tudo o que aconteceu nos anteriores — o compilador, o código-fonte, o cache — fica para trás. Essa é a frase da documentação: copiar o que se quer e deixar para trás o que não se quer.

Para quem vem da programação, uma comparação ajuda: um estágio é como uma função que retorna um valor. O estágio de compilação «retorna» um arquivo; o estágio final só recebe esse arquivo, não as variáveis locais com que ele foi calculado.

#### 5.2.2 Construir até um estágio: `--target`

A segunda ferramenta é poder construir **só até** um estágio. `docker build --target pruebas` constrói o estágio chamado `pruebas` (e os de que ele precisar) e para ali; a imagem resultante é a desse estágio, não a final ([Docker, «Stop at a specific build stage»](https://docs.docker.com/build/building/multi-stage/#stop-at-a-specific-build-stage); na referência da linha de comando, `--target` é «o estágio de build a construir», [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)). Serve para duas coisas que vão ser usadas nesta lição: rodar só os testes, e olhar por dentro um estágio intermediário que tem ferramentas.

#### 5.2.3 O que o BuildKit constrói e o que não constrói

A terceira peça é a menos conhecida e a que mais surpreende. O builder do Docker, o BuildKit, não constrói todos os estágios do arquivo em ordem: **constrói só os estágios de que depende o estágio pedido**. A documentação diz isso sem rodeios: «o BuildKit só constrói os estágios de que o estágio-alvo depende» ([Docker, «Differences between legacy builder and BuildKit»](https://docs.docker.com/build/building/multi-stage/#differences-between-legacy-builder-and-buildkit)). Um estágio de que ninguém precisa não roda.

Isso é uma vantagem (não se perde tempo com o que não é necessário) e uma armadilha, que vai ser provocada em 5.5: se os testes vivem em um estágio do qual a imagem final não depende, o BuildKit não os roda, e o build sai verde com um teste quebrado dentro. Guarde essa frase; é a chave do erro silencioso desta lição.

### 5.3 O Dockerfile de quatro estágios, linha por linha

#### 5.3.1 A receita completa

Este é o Dockerfile com que a lição termina. Ele substitui o da Lição 4 na pasta local, e o `.dockerignore` não muda:

```dockerfile
# syntax=docker/dockerfile:1
# fig05_02.Dockerfile — Lección 5: multi-stage: compilar y probar en una imagen grande, entregar en una mínima.

# --- Etapa 1: el código, sobre la imagen de Go (fijada por versión Y por digest) ---
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

# --- Etapa 2: las pruebas. Si fallan, la construcción se detiene aquí ---
FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

# --- Etapa 3: el binario, estático (CGO_ENABLED=0), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

São quatro estágios encadeados, e cada um tem um único trabalho:

| Estágio | Parte de | Seu trabalho | Viaja na imagem final? |
|---|---|---|---|
| `compilacion` | a imagem oficial do Go | deixar o código pronto para compilar | não |
| `pruebas` | `compilacion` | rodar `go test ./...` | não |
| `binario` | `pruebas` | produzir `/out/revisor`, estático | só esse arquivo |
| `final` | *distroless* `static`, sem *shell* | rodar o `revisor` | é a imagem final |

Os nomes dos estágios são os do curso e se repetem nas lições seguintes: `compilacion`, `pruebas`, `binario` e `final`. Vão sem acento de propósito, porque são identificadores que vão ser digitados em `--target` e em `COPY --from`.

#### 5.3.2 Cada linha no seu momento

**O estágio `compilacion`.** É quase a metade de cima do Dockerfile da Lição 4: a mesma base, o mesmo `WORKDIR /src` e os mesmos três `COPY` na ordem que o cache agradece (primeiro `go.mod`, que quase nunca muda; depois o código). A única novidade está no `FROM`: depois da tag `1.27.3-trixie` vem `@sha256:6041…`, o *digest*, e no final `AS compilacion`. O *digest* tem seção própria (5.7). Este estágio ainda não compila nada: só deixa o código no lugar, para que os dois seguintes partam dele.

**O estágio `pruebas`.** `FROM compilacion AS pruebas` diz «comece onde `compilacion` terminou». É a primeira vez que aparece um `FROM` que não nomeia uma imagem da internet, e sim um estágio do mesmo arquivo. Seu único `RUN` roda `go test ./...`, os testes dos cinco pacotes do `revisor`, com a mesma montagem de cache da Lição 4 (o `id=curso-docker-go-build` é o mesmo, então os dois estágios compartilham o cache de compilação do Go). Se um teste falha, `go test` sai com um código diferente de zero, o `RUN` falha e o build para: não há imagem.

**O estágio `binario`.** `FROM pruebas AS binario` é a linha mais importante do arquivo, embora pareça um detalhe. Diz que o binário é compilado **sobre** o estágio de testes, não sobre o de compilação. Por 5.2.3 já se sabe por que isso importa: como o estágio final copia de `binario`, e `binario` sai de `pruebas`, o BuildKit é obrigado a rodar os testes para chegar à imagem final. Se `binario` saísse de `compilacion`, os testes ficariam fora do caminho e ninguém os rodaria. Isso vai ser medido em 5.5.

O `RUN` deste estágio traz três novidades no comando do Go:

- **`CGO_ENABLED=0`** pede um binário **estático**: um que não depende de bibliotecas do sistema para iniciar. É a peça que torna possível o estágio final, e removê-la é o erro principal da lição (5.8).
- **`-trimpath`** tira do binário os caminhos da máquina onde ele foi compilado (aqui, `/src`): no lugar ficam os nomes dos módulos ([`go help build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies)). Assim o binário não depende da pasta em que foi compilado nem a revela.
- **`-ldflags="-s -w"`** passa duas opções ao linker do Go: `-s` «omite a tabela de símbolos e as informações de depuração», e `-w` «omite a tabela de símbolos DWARF» ([cmd/link](https://pkg.go.dev/cmd/link)). Isso é o que se usaria com um depurador; um serviço em produção não precisa disso, e removê-lo deixa o arquivo menor. (`-s` já implica `-w`, segundo essa mesma documentação; escrevem-se as duas por costume, e é assim que elas aparecem em quase todos os Dockerfiles de Go.) Compare: o binário da Lição 4 media 9,5 MiB segundo `ls -lh`, uns 10 MB; este vai medir 6,68 MB (6.684.832 bytes). Parte da diferença é `-s -w`, e parte é que ele já não leva o código de *cgo* (5.8).

O binário fica em `/out/revisor`, uma pasta que só existe para isso: ter um lugar fixo e limpo de onde o estágio final o recolha.

**O estágio `final`.** Começa do zero sobre `gcr.io/distroless/static-debian13:nonroot`, fixada por *digest*. De tudo o que veio antes, só traz um arquivo: `COPY --from=binario /out/revisor /revisor`. Depois:

- `USER 65532:65532` é o usuário `nonroot` que a própria imagem *distroless* traz em seu `/etc/passwd`; isso vai aparecer em 5.4. A partir daqui, o curso deixa o `10001` das imagens de um único estágio e usa o `65532`, porque é o que a base já conhece.
- `EXPOSE 8080` continua sendo só uma anotação, igual à Lição 3.
- **`ENTRYPOINT ["/revisor"]`** substitui o `CMD ["revisor"]` das lições anteriores. A diferença é prática. A referência explica: os argumentos escritos depois do nome da imagem em `docker run` «são acrescentados depois de todos os elementos» de um `ENTRYPOINT` na forma *exec*, e por outro lado «substituem tudo o que o `CMD` disser» ([referência, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). Com `ENTRYPOINT`, `docker run curso-docker-revisor:1.2.0 version` executa `/revisor version`: a imagem se comporta como o programa, e seus subcomandos (`version`, e na Lição 7 `healthcheck`) são pedidos do mesmo jeito que no terminal. Com o `CMD` de antes, esse `version` teria substituído o programa inteiro e o Docker teria tentado executar um arquivo chamado `version`. Continua na forma *exec*, por tudo o que foi medido na Lição 3. E o caminho vai completo, `/revisor`, porque o arquivo está na raiz do sistema de arquivos, `/`, que não é nenhuma das pastas onde o `PATH` da imagem procura programas.

#### 5.3.3 Na pasta local

Os scripts do curso trabalham em pastas temporárias e apagam o que criam; o projeto vive em `~/curso-docker/revisor` desde a Lição 3. A partir da raiz do repositório do curso, coloque ali o Dockerfile desta lição e construa a imagem que vai ser mantida:

```bash
cp programas/05-multi-stage/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q -t curso-docker-revisor:1.2.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

O `.dockerignore` da Lição 4 fica como está. A imagem `1.1.0` também pode ficar, para comparar; quando não for mais necessária, `docker rmi curso-docker-revisor:1.1.0`.

### 5.4 Construir e medir

#### 5.4.1 O build, estágio por estágio

`fig05_03.sh` constrói as duas imagens — a da Lição 4, para comparar, e a desta — e faz cinco perguntas à nova: que passos de que estágio rodaram, quanto ela pesa, de que camadas é feita, de onde vem seu tamanho e que arquivos traz:

```bash
#!/usr/bin/env bash
# fig05_03.sh — Construir el revisor en cuatro etapas y medir lo que se entrega.
# Construye la imagen de la Lección 4 (para comparar) y la de esta lección,
# muestra qué etapas corrieron, compara tamaños, lee las capas y lista los
# archivos de la imagen final. Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/inicio/Dockerfile" "$TRABAJO/revisor/Dockerfile.leccion4"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.leccion4 && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

VIEJA="${PREFIJO}revisor:1.1.0"
NUEVA="${PREFIJO}revisor:1.2.0"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$VIEJA" "$NUEVA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

docker build -q -t "$VIEJA" -f Dockerfile.leccion4 . >/dev/null

titulo "Construir: qué pasos de qué etapa corrieron"
muestra "docker build --progress=plain -t $NUEVA . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[\$0]++'"

titulo "Antes y después"
muestra "docker image ls --filter reference='${PREFIJO}revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Las capas de la imagen nueva"
muestra "docker history $NUEVA --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90"

titulo "De dónde salen los 16.1 MB"
muestra "docker history $NUEVA --format '{{.Size}}' --human=false | awk '{s+=\$1} END {print \"suma de las capas desempacadas:\", s, \"bytes\"}'"
muestra "docker image inspect $NUEVA --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'"

titulo "Todos los archivos de la imagen nueva"
docker create --name "${PREFIJO}mirar" "$NUEVA" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -v '/\$' | wc -l"
muestra "docker export ${PREFIJO}mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo"
muestra "docker export ${PREFIJO}mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |\$)|/?(revisor|passwd)\$' || echo '(nada más)'"
muestra "docker export ${PREFIJO}mirar | tar -xO etc/passwd"
```

O arquivo do repositório traz as funções auxiliares completas; aqui elas são resumidas em um comentário para não repeti-las. Duas ferramentas novas: `grep -oE` imprime só o pedaço de cada linha que coincide com o padrão (aqui, o número do passo, o estágio e os primeiros 60 caracteres da instrução), e `awk '!visto[$0]++'` tira as linhas repetidas sem mudar a ordem.

```text
$ ./fig05_03.sh

## Construir: qué pasos de qué etapa corrieron
$ docker build --progress=plain -t curso-docker-revisor:1.2.0 . 2>&1 | grep -oE '^#[0-9]+ \[(compilacion|pruebas|binario|final) [0-9]/[0-9]\] .{0,60}' | awk '!visto[$0]++'
#7 [final 1/2] FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757
#8 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
#10 [compilacion 3/5] COPY go.mod ./
#11 [compilacion 4/5] COPY cmd/ cmd/
#12 [compilacion 5/5] COPY internal/ internal/
#13 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/
#15 [compilacion 2/5] WORKDIR /src
#16 [final 2/2] COPY --from=binario /out/revisor /revisor

## Antes y después
$ docker image ls --filter reference='curso-docker-revisor:1.[12].0' --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB

## Las capas de la imagen nueva
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}\t{{.CreatedBy}}' | cut -c1-90
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
319kB	bazel build //common:cacerts_debian13_arm64_…
16.4kB	bazel build //common:os_release_debian13
12.3kB	bazel build //static:nsswitch
8.19kB	bazel build //common:tmp
12.3kB	bazel build //common:group
16.4kB	bazel build //common:home
12.3kB	bazel build //common:passwd
4.1kB	bazel build //common:rootfs
160kB	bazel build @trixie//media-types/arm64:data_…
2.15MB	bazel build @trixie//tzdata-legacy/arm64:dat…
2.24MB	bazel build @trixie//tzdata/arm64:data_statu…
86kB	bazel build @trixie//netbase/arm64:data_stat…
741kB	bazel build @trixie//base-files/arm64:data_s…

## De dónde salen los 16.1 MB
$ docker history curso-docker-revisor:1.2.0 --format '{{.Size}}' --human=false | awk '{s+=$1} END {print "suma de las capas desempacadas:", s, "bytes"}'
suma de las capas desempacadas: 12468224 bytes
$ docker image inspect curso-docker-revisor:1.2.0 --format 'capas comprimidas (las que se descargan): {{.Size}} bytes'
capas comprimidas (las que se descargan): 3679492 bytes

## Todos los archivos de la imagen nueva
$ docker export curso-docker-mirar | tar -t | grep -v '/$' | wc -l
1301
$ docker export curso-docker-mirar | tar -t | cut -d/ -f1 | sort -u | tr '\n' ' '; echo
.dockerenv bin boot dev etc home lib proc revisor root run sbin sys tmp usr var 
$ docker export curso-docker-mirar | tar -tv | grep -E '(^| |/)(sh|bash|dash|ash|busybox)( |$)|/?(revisor|passwd)$' || echo '(nada más)'
-rw-r--r-- 0/0             149 1969-12-31 18:00 etc/passwd
-rwxr-xr-x 0/0         6684832 2026-10-21 01:55 revisor
$ docker export curso-docker-mirar | tar -xO etc/passwd
root:x:0:0:root:/root:/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/sbin/nologin
nonroot:x:65532:65532:nonroot:/home/nonroot:/sbin/nologin
```

Mudam a cada execução: os números de passo (`#7`, `#8`…) e sua ordem, a data do arquivo `revisor`, e em uma máquina Intel ou AMD a palavra `arm64` das camadas e os tamanhos, por alguns kilobytes ou megabytes. O estável: os quatro estágios, os dois tamanhos em sua ordem de grandeza, que a soma das duas cifras de bytes dá o tamanho de `docker image ls`, a lista de pastas e o conteúdo de `/etc/passwd`.

#### 5.4.2 Ler o build

O primeiro bloco mostra os passos com seu estágio entre colchetes: `[compilacion 4/5]` é o quarto dos cinco passos do estágio `compilacion`. Aparecem os quatro estágios, e dois detalhes ensinam como o BuildKit trabalha:

- **A ordem não é a do arquivo.** O `FROM` do estágio `final` aparece primeiro (`#7`), antes de tudo o que é de `compilacion`, e o `WORKDIR` (`[compilacion 2/5]`) sai quase no final, depois dos `COPY`. O BuildKit monta um grafo com o que depende do quê e roda em paralelo o que pode: baixar a base mínima não precisa esperar o código ser copiado. O estágio final só espera `binario` em seu segundo passo, o `COPY --from`.
- **Os números de passo não são os do estágio.** `#13` é um número do BuildKit para este build; `[pruebas 1/1]` é a posição dentro do estágio. Rodando o script duas vezes, os primeiros podem mudar e a ordem também; os rótulos entre colchetes, não. (Em outra execução desta mesma lição, com mais coisas já no cache, o BuildKit nem chegou a imprimir os passos 1 e 2 de `compilacion`; por isso não convém contar linhas desta saída, e sim ler que estágios aparecem.)

#### 5.4.3 Ler os tamanhos

O segundo bloco é o que justifica a lição: **de 1.32 GB para 16.1 MB**, umas oitenta vezes menos. A imagem nova cabe dezessete vezes no que antes ocupava só o compilador do Go (277 MB em `/usr/local/go`, em 5.1). E o terceiro bloco, `docker history`, diz o que há dentro: a camada grande é `COPY /out/revisor /revisor`, de **6.69 MB**, o binário; as demais são da base *distroless* e somam uns 5,8 MB, a maior de 2.24 MB (os fusos horários, `tzdata`). As camadas da base dizem `bazel build`: é a ferramenta com que o Google constrói essas imagens, e no histórico delas não há nem um `RUN apt-get`, porque não foram montadas instalando pacotes com um gerenciador. Compare com a Lição 4, em que `docker history` mostrava camadas de 290 MB, 281 MB e 208 MB.

Somando essas camadas manualmente, não se chega a 16.1 MB, e vale a pena saber por quê antes que isso confunda. O quarto bloco as soma: **12.468.224 bytes**, uns 12,5 MB. Faltam 3,6 MB. E a segunda consulta desse bloco os encontra: `docker image inspect` informa **3.679.492 bytes**, e 12.468.224 + 3.679.492 = 16.147.716 bytes, os 16.1 MB de `docker image ls`. A explicação está em como o Docker Engine 29 guarda as imagens, com o armazenamento do containerd: segundo sua documentação, esse armazenamento «guarda as imagens em formato compactado e descompactado»: mantém as camadas compactadas tal como chegaram do registry **e além disso** as descompacta no disco ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)). O número de `docker image ls` conta as duas cópias; `docker history` conta só as camadas descompactadas, e `docker image inspect`, nesta máquina, a parte compactada, que é o que se baixa. Para o que importa nesta lição, nada muda: compare sempre imagens com o **mesmo** comando, e as duas cifras de `docker image ls` (1.32 GB e 16.1 MB) foram medidas do mesmo jeito.

Uma pergunta natural é onde ficaram os estágios `compilacion`, `pruebas` e `binario`. Ficaram no cache de build da máquina, que é o que torna rápido o build seguinte, mas **não fazem parte da imagem**: o `docker history` da `1.2.0` não tem nenhuma camada deles. A única coisa que passou de um lado para o outro é o arquivo que o `COPY --from` nomeia.

#### 5.4.4 Olhar dentro sem entrar

A última parte do script responde à pergunta da cena: o que há nesta imagem? Como ela não tem *shell* (isso vai ser comprovado em 5.6), não dá para entrar e olhar com `docker exec`. Mas dá para pedir ao Docker os arquivos dela. `docker create` cria um contêiner da imagem **sem iniciá-lo**, e `docker export` extrai todo o sistema de arquivos desse contêiner como um arquivo `tar`, que `tar -t` lista sem descompactar. É a forma de inspecionar uma imagem mínima de fora.

O que ele diz:

- **1.301 arquivos** no total (`grep -v '/$'` tira as pastas da conta). Parece muito, até se ver o que são: quase todos são os fusos horários e os certificados das autoridades da internet, de que um serviço que consulta outros por HTTPS precisa.
- **As pastas de primeiro nível** são as de qualquer Linux (`bin`, `etc`, `usr`, `var`…), mais `revisor` e `.dockerenv`, um arquivo vazio que o Docker acrescenta a todo contêiner. Existir uma pasta `bin` não significa que haja programas dentro.
- **A busca por *shells*** pedia, em qualquer pasta, um arquivo chamado `sh`, `bash`, `dash`, `ash` ou `busybox`, além de `revisor` e `passwd` como controle: se o padrão estivesse mal escrito, esses dois também não sairiam. Saíram os dois de controle e nenhum *shell*. Não há *shell*, e em 5.6 isso é confirmado de outra forma: tentando executá-lo. O `revisor` mede 6.684.832 bytes, os 6.69 MB da camada.
- **A data de `/etc/passwd`**, `1969-12-31 18:00`, é a data zero do relógio do Unix (1º de janeiro de 1970 em tempo universal) vista no fuso horário da máquina das execuções. Os arquivos da base levam essa data de propósito: assim dois builds da mesma base dão exatamente os mesmos bytes. O `revisor`, por outro lado, leva a data em que foi compilado. A que aparece aqui é da madrugada desse mesmo dia: o binário saiu do cache de build, porque nada do que o produz tinha mudado desde a execução anterior nessa máquina. Na máquina de cada um aparecerá outra data.
- **O conteúdo de `/etc/passwd`** tem três usuários, e o terceiro é o que o estágio final usa: `nonroot`, com número **65532**. Ali está o motivo do `USER 65532:65532`. Repare também na última coluna dos três: `/sbin/nologin`. Nem `root` tem um *shell* atribuído.

> [!NOTE]
> 🔧 **Observação de engenharia 5.2**
> A imagem final não foi «limpa»: nasceu sem o que sobrava. É a diferença entre arrumar um quarto e se mudar para um vazio levando só uma mala. O primeiro se desfaz com o tempo; o segundo começa limpo a cada build.

### 5.5 Os testes dentro do build

#### 5.5.1 Rodar só os testes

Os testes viverem em seu próprio estágio permite rodá-los **sozinhos**, sem construir a imagem final. `fig05_04.sh` constrói até o estágio `pruebas`, obrigando-o a rodar mesmo que esteja no cache, e mede a imagem intermediária resultante:

```bash
#!/usr/bin/env bash
# fig05_04.sh — La etapa de pruebas, sola: construye solo hasta «pruebas»,
# obligándola a correr de nuevo, y mide la imagen intermedia que queda.
# Borra lo que crea al salir.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

PRUEBAS="${PREFIJO}revisor:pruebas"
trap 'docker rmi -f "$PRUEBAS" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Solo hasta la etapa de pruebas"
muestra "docker build --target pruebas --no-cache-filter pruebas --progress=plain -t $PRUEBAS . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[\$0]++'"

titulo "La imagen intermedia: sirve para probar, no para entregar"
muestra "docker image ls $PRUEBAS --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

`--no-cache-filter pruebas` diz ao BuildKit para não usar o cache nesse estágio ([docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)): sem isso, como nada mudou, os testes sairiam do cache e não apareceria nem uma linha de `go test`.

```text
$ ./fig05_04.sh

## Solo hasta la etapa de pruebas
$ docker build --target pruebas --no-cache-filter pruebas --progress=plain -t curso-docker-revisor:pruebas . 2>&1 | grep -E '^#[0-9]+ \[(compilacion|pruebas)|^#[0-9]+ [0-9.]+ (ok|FAIL|---)' | grep -v -e DONE -e CACHED | awk '!visto[$0]++'
#6 [compilacion 1/5] FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#8 [compilacion 3/5] COPY go.mod ./
#9 [compilacion 4/5] COPY cmd/ cmd/
#10 [compilacion 2/5] WORKDIR /src
#11 [compilacion 5/5] COPY internal/ internal/
#12 [pruebas 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     go test ./...
#12 15.92 ok  	github.com/habil/revisor/cmd/revisor	0.008s
#12 15.92 ok  	github.com/habil/revisor/internal/config	0.005s
#12 15.92 ok  	github.com/habil/revisor/internal/reporte	0.004s
#12 16.06 ok  	github.com/habil/revisor/internal/revisar	0.141s
#12 16.06 ok  	github.com/habil/revisor/internal/servicio	0.003s

## La imagen intermedia: sirve para probar, no para entregar
$ docker image ls curso-docker-revisor:pruebas --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:pruebas 1.31GB
```

Mudam os números de passo, os segundos da terceira coluna (`15.92` são os segundos desde que aquele passo começou) e os tempos de cada pacote. O estável: os cinco pacotes com `ok`.

Três coisas para ler aqui. A primeira: **só rodaram `compilacion` e `pruebas`**. Não há nem uma linha de `binario` nem de `final`: é a regra de 5.2.3 em ação, o BuildKit construiu só o que o estágio pedido precisava. A segunda: os cinco pacotes do `revisor` passaram nos testes **dentro** do build, com o mesmo compilador da imagem fixada; isso não depende de ter o Go instalado na máquina, nem de que versão. A terceira: a imagem `pruebas` pesa **1.31 GB**. Serve para testar e para olhar, nunca para entregar. Por isso é um estágio e não a imagem final.

#### 5.5.2 Um teste quebrado interrompe o build... se estiver no caminho

Agora o erro desta seção, e sua versão silenciosa. `fig05_05.sh` acrescenta um teste que falha de propósito, `rota_test.go`, e constrói duas vezes: com o Dockerfile da lição e com uma variante que muda **uma única linha**, para que o estágio `binario` saia de `compilacion` em vez de `pruebas`:

```bash
#!/usr/bin/env bash
# fig05_05.sh — Una prueba rota detiene la construcción... si el Dockerfile la
# pone en el camino. Agrega una prueba que falla a propósito y construye dos
# veces: con el Dockerfile de la lección y con una variante donde la etapa
# «binario» sale de «compilacion» en vez de «pruebas». Borra lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# La variante equivocada: un solo renglón distinto.
sed 's/^FROM pruebas AS binario/FROM compilacion AS binario/' Dockerfile > Dockerfile.salta-pruebas

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

ROTA="${PREFIJO}revisor:rota"
trap 'docker rmi -f "$ROTA" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

cat > cmd/revisor/rota_test.go <<'GO'
package main

import "testing"

func TestRotaAProposito(t *testing.T) { t.Fatal("esta prueba falla a propósito") }
GO

titulo "Con el Dockerfile de la lección"
muestra "docker build --progress=plain -t $ROTA . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit \${PIPESTATUS[0]})"
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"

titulo "Con la variante: binario sale de compilacion"
muestra "diff Dockerfile Dockerfile.salta-pruebas"
muestra "docker build --progress=plain -t $ROTA -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo \"construcción: código \${PIPESTATUS[0]}\""
muestra "docker image ls $ROTA --format '{{.Repository}}:{{.Tag}} {{.Size}}'"
```

O script usa `set -uo pipefail`, sem `-e`, porque deve continuar depois da falha que provoca. `${PIPESTATUS[0]}` é uma variável do *bash* que guarda o código de saída do **primeiro** comando do pipe anterior, o `docker build`, e não o do `grep` que filtra sua saída; `(exit N)` o devolve para que a função `muestra` o anote.

```text
$ ./fig05_05.sh

## Con el Dockerfile de la lección
$ docker build --progress=plain -t curso-docker-revisor:rota . 2>&1 | grep -E 'rota_test|^#[0-9]+ [0-9.]+ FAIL|^ERROR'; (exit ${PIPESTATUS[0]})
#14 1.127     rota_test.go:5: esta prueba falla a propósito
#14 1.127 FAIL
#14 1.127 FAIL	github.com/habil/revisor/cmd/revisor	0.008s
#14 1.128 FAIL
1.127     rota_test.go:5: esta prueba falla a propósito
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1
[código de salida: 1]
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'

## Con la variante: binario sale de compilacion
$ diff Dockerfile Dockerfile.salta-pruebas
17c17
< FROM pruebas AS binario
---
> FROM compilacion AS binario
[código de salida: 1]
$ docker build --progress=plain -t curso-docker-revisor:rota -f Dockerfile.salta-pruebas . 2>&1 | grep -E 'rota_test|FAIL|^ERROR|\[(pruebas|binario) '; echo "construcción: código ${PIPESTATUS[0]}"
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
#14 [binario 1/1] RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build     CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor
construcción: código 0
$ docker image ls curso-docker-revisor:rota --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:rota 16.1MB
```

Mudam os números de passo e os segundos. O `[código de salida: 1]` depois do `diff` não é um erro: `diff` sai com 1 quando encontra diferenças, que é justamente o que se pediu para ele mostrar.

**A primeira metade é o comportamento desejado.** (A linha do teste sai duas vezes: a primeira, com `#14`, é a saída do passo enquanto roda; a segunda, sem número, é o resumo que o BuildKit repete logo antes do `ERROR` com as últimas linhas do passo que falhou.) O teste falha, `go test` imprime `FAIL` com o arquivo e a linha (`rota_test.go:5`) e a mensagem, e o BuildKit para tudo com um `ERROR` que diz que processo falhou e com que código: `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. O build sai com 1 e, o mais importante, o segundo comando não imprime nada: **a imagem `rota` não existe**. Um código com um teste quebrado não produz imagem. Se o servidor de build publica o que constrói, é isso que impede publicar algo quebrado.

**A segunda metade é o erro silencioso.** O `diff` confirma que a variante muda uma única linha: `binario` sai de `compilacion`. O teste quebrado continua ali. E o build termina com **código 0** e uma imagem de 16.1 MB. Não há `FAIL` nem `ERROR` porque **os testes nunca rodaram**: o filtro procurava linhas de `pruebas` e de `binario`, e só aparece `binario` (duas vezes, porque o BuildKit imprimiu de novo o cabeçalho do passo ao terminá-lo). O estágio `pruebas` continua escrito no arquivo, mas o estágio final copia de `binario`, `binario` sai de `compilacion`, e ninguém no caminho precisa de `pruebas`. Pela regra de 5.2.3, o BuildKit não o constrói.

É o pior tipo de erro: não avisa. O Dockerfile *parece* certo, tem um estágio de testes com seu comentário, e quem o revisa de passagem acredita que os testes protegem a imagem. Por isso o `FROM pruebas AS binario` não é um detalhe de estilo: é o que transforma os testes em uma condição para a imagem existir.

> [!NOTE]
> 🔧 **Observação de engenharia 5.3**
> Uma verificação que pode ser pulada sem que ninguém perceba não é uma verificação. A forma de saber se uma barreira funciona é a desta seção: quebrá-la de propósito e comprovar que ela interrompe o build. Um build verde não demonstra que os testes passaram; pode demonstrar só que eles não rodaram.

### 5.6 A base mínima: sem *shell* e sem `root`

#### 5.6.1 O que é *distroless*

O estágio final parte de `gcr.io/distroless/static-debian13`. *Distroless* é uma família de imagens base publicada pelo Google, e o nome já explica a ideia: «sem distribuição». Sua documentação diz assim: elas contêm «só a aplicação e suas dependências de execução», e não trazem «gerenciadores de pacotes, *shells* nem nenhum outro programa que se esperaria encontrar em uma distribuição Linux normal» ([distroless](https://github.com/GoogleContainerTools/distroless)).

A família tem várias variantes, conforme o que o programa precisa para rodar: `base`, `cc`, e outras com o ambiente de Python, Java ou Node.js já instalado. A que o `revisor` usa é a menor de todas, **`static`**: para programas que já trazem tudo dentro e não dependem de nada do sistema. Sua documentação a dá como «cerca de 2 MiB». As medições não dão esse número, e convém dizer isso: nas camadas de 5.4 ela ocupava uns 5,8 MB já descompactada, e sua versão compactada para `arm64`, a que é baixada, soma 855.334 bytes em suas treze camadas (medido no mesmo dia com `docker buildx imagetools inspect --raw` sobre o *digest* de `arm64` de 5.7). A documentação não diz como mediu seus 2 MiB, então tome isso como uma ordem de grandeza: alguns poucos megabytes, contra as centenas de uma base com distribuição completa. Dos 5,8 MB descompactados, quase 4,4 MB são os fusos horários (`tzdata` e `tzdata-legacy`). Ela traz o mínimo de que um programa estático ainda precisa do mundo: os certificados das autoridades (para falar HTTPS), os fusos horários, `/etc/passwd` com seus três usuários e uma pasta `/tmp`. São as camadas vistas em 5.4.

O nome completo tem três partes que convém ler uma a uma:

- `static`: a variante, para binários estáticos.
- `debian13`: de que versão do Debian vêm os poucos arquivos que ela traz (certificados, fusos horários). A documentação recomenda escrever sempre a versão do Debian no nome, para que o build não mude de base sem aviso no dia em que sair a seguinte.
- `:nonroot`: a tag. A *distroless* publica poucas tags, que são nomes e não versões: `latest`, `nonroot`, `debug` e `debug-nonroot`, e as mesmas com um sufixo de arquitetura, como `nonroot-arm64` ([distroless](https://github.com/GoogleContainerTools/distroless)); nenhuma leva versão. `nonroot` é a mesma imagem, mas configurada para rodar com o usuário `nonroot` em vez de `root`. As variantes `debug` trazem um *shell* mínimo para depurar; não são para produção.

#### 5.6.2 Rodá-la

`fig05_06.sh` roda a imagem mínima das duas formas em que o `revisor` é usado — como programa que faz uma coisa e termina, e como serviço — e comprova o que a lição prometeu:

```bash
#!/usr/bin/env bash
# fig05_06.sh — Correr la imagen mínima: su versión, su salud, su reporte, que
# no tiene shell, que no es root y cuánto tarda en detenerse. Borra lo que crea.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile && rm -f Dockerfile.bak
# PUERTO: el puerto del equipo donde se publica el revisor, siempre en 127.0.0.1.
PUERTO="${PUERTO:-8080}"

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

IMAGEN="${PREFIJO}revisor:1.2.0"
NOMBRE="${PREFIJO}revisor"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1; docker rmi -f "$IMAGEN" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT
docker build -q -t "$IMAGEN" . >/dev/null

titulo "Un subcomando, sin servidor"
muestra "docker run --rm --name ${PREFIJO}version $IMAGEN version"

titulo "Como servicio"
muestra "docker run -d --name $NOMBRE -p 127.0.0.1:$PUERTO:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' $IMAGEN >/dev/null"
esperar_http "http://127.0.0.1:$PUERTO/salud"
muestra "curl -s http://127.0.0.1:$PUERTO/salud; echo"
muestra "curl -s 'http://127.0.0.1:$PUERTO/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'"

titulo "Sin shell y sin root"
muestra "docker exec $NOMBRE sh"
muestra "docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' $NOMBRE"
muestra "docker top $NOMBRE -o pid,user,args"

titulo "Detenerlo"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' $NOMBRE"
muestra "docker logs $NOMBRE"
```

Como na Lição 3, o `revisor` verifica a si mesmo (`propio http://127.0.0.1:8080/salud`) porque ainda não está conectado a outros contêineres; isso é a Lição 8. O `sed` do relatório esconde, à vista, o tempo de resposta, que muda a cada execução.

```text
$ ./fig05_06.sh

## Un subcomando, sin servidor
$ docker run --rm --name curso-docker-version curso-docker-revisor:1.2.0 version
desarrollo

## Como servicio
$ docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0 >/dev/null
$ curl -s http://127.0.0.1:8080/salud; echo
{"estado":"vivo","version":"desarrollo"}

$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/[0-9.]+(ms|µs)/<tiempo>/'
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <tiempo>  200

## Sin shell y sin root
$ docker exec curso-docker-revisor sh
OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH
[código de salida: 127]
$ docker inspect --format 'User={{.Config.User}} Entrypoint={{.Config.Entrypoint}} Cmd={{.Config.Cmd}}' curso-docker-revisor
User=65532:65532 Entrypoint=[/revisor] Cmd=[]
$ docker top curso-docker-revisor -o pid,user,args
PID                 USER                COMMAND
1451351             65532               /revisor

## Detenerlo
docker stop tardó 298 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-revisor
ExitCode=0
$ docker logs curso-docker-revisor
revisor desarrollo escuchando en :8080 (1 servicio(s))
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /salud 200 0s
revisor: GET /api/estados 200 8ms
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Mudam o PID (`1451351`), o tempo de `docker stop`, o tempo de `/api/estados` no log e quantas vezes aparece `GET /salud` (depende de quantas tentativas o script fez enquanto esperava o serviço responder). O resto sai igual.

#### 5.6.3 Ler a execução

- **`version` funcionou como subcomando.** `docker run ... curso-docker-revisor:1.2.0 version` executou `/revisor version`, graças ao `ENTRYPOINT`. Imprime `desarrollo` porque o binário ainda não leva versão gravada; a Lição 6 a coloca.
- **Como serviço, faz o mesmo que antes.** `/salud` responde, o relatório em tabela diz `OK`. A imagem diminuiu oitenta vezes e o comportamento não mudou em nada: tudo o que foi tirado era, de verdade, bagagem.
- **Não há *shell*.** `docker exec curso-docker-revisor sh` falha com a mesma mensagem vista com o serviço de teste na Lição 2: `exec: "sh": executable file not found in $PATH`, código 127. Agora se sabe por quê: a base é *distroless* e `sh` não existe. Para a cena do começo, esta é a resposta: quem conseguisse executar algo dentro deste contêiner não encontraria nem um *shell*, nem `curl`, nem um compilador.
- **Não é `root`.** `docker inspect` diz `User=65532:65532`, e `docker top`, que olha o processo a partir do host, confirma: o processo é do usuário 65532. Também diz `Entrypoint=[/revisor] Cmd=[]`: o programa é fixado pelo `ENTRYPOINT`, e não há argumentos padrão.
- **Desliga direito.** `docker stop` levou 298 ms, o código foi 0 e o log termina com `recibí terminated, apagando` e `apagado limpio`: a forma *exec* faz o sinal chegar ao `revisor`, que é o processo número 1. Repare que na coluna `COMMAND` de `docker top` está só `/revisor`, sem um `/bin/sh -c` na frente: nem poderia haver, porque não há *shell*.

#### 5.6.4 O custo de não ter *shell*

Uma imagem sem *shell* tem um preço, e convém dizer: **não dá para entrar e bisbilhotar**. Não há `ls`, `cat`, `ps` nem `sh`. Quando algo falhar, as ferramentas que sobram são as de fora, e elas bastam:

- `docker logs`, para o que o programa escreve;
- `docker inspect`, para a configuração e o estado;
- `docker top`, para ver o processo a partir do host;
- `docker export` com `tar`, para ver os arquivos, como em 5.4.4;
- e o estágio `binario` construído com `--target`, que tem todas as ferramentas, para examinar o programa por dentro. Ele vai ser usado em 5.8.

O que **não** se faz é trocar a base final por uma com *shell* «para poder depurar». Se um *shell* junto ao processo for realmente necessário, existem ferramentas para conectar um de fora, temporariamente, sem colocá-lo na imagem; este curso não precisa delas.

### 5.7 Versão e *digest* da base

#### 5.7.1 Uma tag é um apelido que se move

Na Lição 3 viu-se que uma tag como `1.27.3-trixie` é mais específica que `latest`, e que mesmo assim pode mudar: quem publica a imagem pode reenviá-la. O guia de boas práticas do Docker diz isso com todas as letras: «as tags de imagem são mutáveis, o que significa que quem publica pode atualizar uma tag para apontar para uma imagem nova» ([boas práticas, fixar a versão da base](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Para a *distroless* a questão é ainda mais clara: sua tag `nonroot` não tem versão, então **por definição** aponta para o último que foi publicado. Escrever só `static-debian13:nonroot` é, na prática, escrever `latest`.

#### 5.7.2 O que é um *digest*

Um ***digest*** é o identificador do conteúdo de uma imagem: é calculado passando seus bytes por uma função de hash, SHA-256, e se escreve `sha256:` seguido de 64 caracteres hexadecimais. A especificação de imagens da OCI o define como um «identificador de conteúdo» que «identifica o conteúdo de forma única», calculado com uma função de hash resistente a colisões ([OCI, descritores](https://github.com/opencontainers/image-spec/blob/main/descriptor.md)). A consequência prática é a que importa: **se um único byte da imagem muda, o *digest* muda**. Um *digest* não pode ser movido para outra imagem, porque ele é a imagem.

`fig05_09.sh` pergunta ao registry que *digest* as duas bases do Dockerfile têm hoje, sem construir nem criar nada:

```bash
#!/usr/bin/env bash
# fig05_09.sh — Etiqueta contra digest: qué hay detrás de las dos bases.
# Solo consulta el registro y la copia local; no construye ni crea nada.
set -euo pipefail

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}

titulo "La base de compilación: la etiqueta y el digest que hoy le corresponde"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'"
muestra "docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'"
muestra "docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie"

titulo "La base final: distroless no publica versiones, solo nombres"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'"
muestra "docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'"
```

`docker buildx imagetools inspect` pergunta ao registry o que há por trás de um nome, sem baixar a imagem. `docker image inspect` com `.RepoDigests` diz de que *digest* veio a cópia que já está na máquina.

```text
$ ./fig05_09.sh

## La base de compilación: la etiqueta y el digest que hoy le corresponde
$ docker buildx imagetools inspect golang:1.27.3-trixie | sed -n '1,3p'
Name:      docker.io/library/golang:1.27.3-trixie
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
$ docker buildx imagetools inspect golang:1.27.3-trixie | grep -E 'Platform: +linux/(amd64|arm64)'
  Platform:    linux/amd64
  Platform:    linux/arm64/v8
$ docker image inspect --format '{{index .RepoDigests 0}}' golang:1.27.3-trixie
golang@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c

## La base final: distroless no publica versiones, solo nombres
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | sed -n '1,3p'
Name:      gcr.io/distroless/static-debian13:nonroot
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot | grep -B2 -E 'Platform: +linux/(amd64|arm64)' | grep -E 'Name|Platform'
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a
  Platform:  linux/amd64
  Name:      gcr.io/distroless/static-debian13:nonroot@sha256:6964c30f0122730c54f70f8f51a777490f85d077d25da672830c43968c14993e
  Platform:  linux/arm64/v8
```

Esta saída é a de 21 de outubro de 2026. **É a que mais pode mudar em toda a lição**, e não por causa da máquina: no dia em que o Google publicar uma base nova com a tag `nonroot`, o `Digest` da quarta consulta será outro. O de `golang:1.27.3-trixie` também pode mudar se quem a publica a reconstruir. E se a imagem do Go nunca foi baixada, a terceira consulta falha porque não há cópia local.

#### 5.7.3 Ler a saída

- **O `MediaType` diz `image.index`.** O que há por trás dessas tags não é uma imagem, e sim um **índice**: uma lista de imagens, uma por plataforma. Por isso a segunda e a quinta consulta encontram uma entrada para `linux/amd64` e outra para `linux/arm64/v8`, cada uma com seu próprio *digest*. O *digest* que o Dockerfile escreve é o **do índice**: com ele, a mesma linha serve no Mint de processador Intel ou AMD e na máquina ARM destas execuções, e o Docker escolhe dentro do índice a imagem da plataforma local.
- **Os dois *digests* do Dockerfile coincidem com os daquele dia**: `6041…` para o Go e `5167…` para a *distroless*. A cópia local do Go veio desse mesmo *digest*.
- **Escrevendo o *digest* de uma plataforma** (por exemplo, o `6964…` de `arm64`) em vez do do índice, a base fica amarrada a essa arquitetura: quem construir em outra já não recebe a base da sua. É um erro fácil de cometer ao copiar o *digest* da linha errada.

#### 5.7.4 Tag **e** *digest*

O Dockerfile escreve as duas coisas juntas: `golang:1.27.3-trixie@sha256:6041…`. A sintaxe é permitida pela referência: `FROM <imagen>[@<digest>] [AS <nombre>]` ([referência, `FROM`](https://docs.docker.com/reference/dockerfile/#from)). Quando há *digest*, quem manda é o *digest*: o Docker baixa exatamente esses bytes, diga o que disser hoje a tag. Então, para que a tag? Para as pessoas: `@sha256:6041…` não diz a ninguém que versão do Go é; `1.27.3-trixie` diz. A tag documenta; o *digest* garante.

O guia de boas práticas explica a garantia e também seu preço. A garantia: com o *digest*, «garante-se usar sempre a mesma versão da imagem, mesmo que quem publica substitua a tag por uma imagem nova». O preço: um *digest* fixado **não se atualiza sozinho**, então as correções de segurança da base também não chegam sozinhas ([boas práticas](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Fixar não é esquecer: é decidir quando trocar de base, revisando, em vez de deixar que ela mude sem aviso no meio de um build. O mesmo guia menciona ferramentas que abrem pedidos de mudança automáticos quando sai um *digest* novo. E a Lição 10 ensina a fazer a varredura da base fixada para saber quando é hora de renová-la.

> [!NOTE]
> 🔧 **Observação de engenharia 5.4**
> Um build reproduzível é o que dá o mesmo resultado hoje e daqui a três meses com o mesmo código. Sem *digest*, o mesmo Dockerfile pode produzir duas imagens diferentes sem que ninguém tenha mexido em nada, e no dia em que algo falhar não vai dar para saber se foi a nossa mudança ou a da base.

### 5.8 O binário que não inicia

#### 5.8.1 Provocá-lo

Esta é a parte da lição em que tudo parece certo e nada funciona. `fig05_07.Dockerfile` é o Dockerfile da lição com **uma única mudança**: o `RUN` do estágio `binario` não diz `CGO_ENABLED=0`:

```dockerfile
# syntax=docker/dockerfile:1
# fig05_07.Dockerfile — Lección 5: el error a propósito: el mismo Dockerfile SIN CGO_ENABLED=0.

# --- Etapa 1: el código, sobre la imagen de Go (fijada por versión Y por digest) ---
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/

# --- Etapa 2: las pruebas. Si fallan, la construcción se detiene aquí ---
FROM compilacion AS pruebas
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go test ./...

# --- Etapa 3: el binario, estático (CGO_ENABLED=0), sale DESPUÉS de las pruebas ---
FROM pruebas AS binario
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/revisor ./cmd/revisor

# --- Etapa final: sin shell, sin compilador, sin root ---
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=binario /out/revisor /revisor
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/revisor"]
```

O comentário do estágio 3 continua dizendo «estático», de propósito: é assim que esses erros aparecem na vida real, com um comentário que já não diz a verdade. `fig05_08.sh` constrói essa imagem, roda-a e depois examina os dois binários, o desta imagem e o da lição, a partir do estágio `binario`, que tem ferramentas:

```bash
#!/usr/bin/env bash
# fig05_08.sh — El error de esta lección: el binario que no es estático.
# Construye la imagen de fig05_07.Dockerfile (sin CGO_ENABLED=0), la corre, y
# después mira los dos binarios del revisor por dentro, el de esa imagen y el
# de la lección. Borra lo que crea al salir.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"

# El proyecto: el código que entrega el curso + los archivos de la lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cp "$AQUI/fig05_07.Dockerfile" "$TRABAJO/revisor/Dockerfile.dinamico"
cd "$TRABAJO/revisor"
sed -i.bak "s/id=curso-docker-go-build/id=${PREFIJO}go-build/" Dockerfile Dockerfile.dinamico && rm -f ./*.bak

# (titulo, muestra, t y esperar_http: las mismas ayudas de fig05_01.sh)

DINAMICO="${PREFIJO}revisor:dinamico"
B_DIN="${PREFIJO}revisor:binario-dinamico"
B_EST="${PREFIJO}revisor:binario-estatico"
trap 'docker rm -f "${PREFIJO}mirar" >/dev/null 2>&1; docker rmi -f "$DINAMICO" "$B_DIN" "$B_EST" >/dev/null 2>&1; rm -rf "$TRABAJO"' EXIT

titulo "Construye sin error... y no arranca"
muestra "docker build -q -t $DINAMICO -f Dockerfile.dinamico . >/dev/null; echo \"construcción: código \$?\""
muestra "docker run --rm --name ${PREFIJO}dinamico $DINAMICO version"

titulo "Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)"
docker build -q --target binario -t "$B_DIN" -f Dockerfile.dinamico . >/dev/null
docker build -q --target binario -t "$B_EST" . >/dev/null
muestra "docker run --rm --name ${PREFIJO}mirar $B_DIN sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'"
muestra "docker run --rm --name ${PREFIJO}mirar $B_EST sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo \"(sin intérprete)\"'"

titulo "¿Está ese intérprete en la imagen final?"
docker create --name "${PREFIJO}mirar" "$DINAMICO" >/dev/null
muestra "docker export ${PREFIJO}mirar | tar -t | grep -E 'ld-linux|libc\\.so' || echo '(no está)'"
```

`ldd` é uma ferramenta do Linux que lista as bibliotecas compartilhadas de que um programa precisa para iniciar. `readelf -l` mostra os cabeçalhos de um executável do Linux (formato ELF), e entre eles a linha que diz que programa precisa carregá-lo. As duas existem na imagem do Go, não na *distroless*: por isso são usadas a partir do estágio `binario`, construído com `--target`.

```text
$ ./fig05_08.sh

## Construye sin error... y no arranca
$ docker build -q -t curso-docker-revisor:dinamico -f Dockerfile.dinamico . >/dev/null; echo "construcción: código $?"
construcción: código 0
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]

## Los dos binarios, vistos desde la etapa «binario» (que sí tiene herramientas)
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-dinamico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter'
	linux-vdso.so.1 (0x0000fd7da7955000)
	libc.so.6 => /lib/aarch64-linux-gnu/libc.so.6 (0x0000fd7da7750000)
	/lib/ld-linux-aarch64.so.1 (0x0000fd7da7910000)
      [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
$ docker run --rm --name curso-docker-mirar curso-docker-revisor:binario-estatico sh -c 'ldd /out/revisor; readelf -l /out/revisor | grep -i interpreter || echo "(sin intérprete)"'
	not a dynamic executable
(sin intérprete)

## ¿Está ese intérprete en la imagen final?
$ docker export curso-docker-mirar | tar -t | grep -E 'ld-linux|libc\.so' || echo '(no está)'
(no está)
```

Mudam os endereços entre parênteses (`0x0000fd7d…`), que são diferentes em cada execução. Em uma máquina Intel ou AMD, os caminhos dizem `x86_64` em vez de `aarch64`: o intérprete é `/lib64/ld-linux-x86-64.so.2` e a biblioteca está em `/lib/x86_64-linux-gnu/`. A mensagem do erro e o código 255 saem iguais.

#### 5.8.2 Ler o erro

O build saiu com **código 0**: nada no Dockerfile está mal escrito, os testes passaram e o binário foi compilado. O erro só aparece ao **rodar**: `exec /revisor: no such file or directory`, com código 255. Esse código não foi colocado pelo `revisor`, que nunca chegou a ser executado: a falha aconteceu ao tentar iniciá-lo.

A mensagem é das mais confusas que aparecem no Docker, porque **o arquivo `/revisor` existe**: foi copiado pelo `COPY --from`, e em 5.4 ele apareceu na lista de arquivos da imagem. O que não existe é **outro** arquivo, e a segunda parte da saída diz qual:

- `ldd` do binário desta imagem lista três coisas de que ele precisa do sistema: `libc.so.6`, a biblioteca C do Debian, e `/lib/ld-linux-aarch64.so.1`, o **carregador dinâmico** (`linux-vdso.so.1` é colocada pelo próprio kernel e não é um arquivo). `readelf` confirma com uma linha explícita: `Requesting program interpreter: /lib/ld-linux-aarch64.so.1`, «peço como intérprete do programa `/lib/ld-linux-aarch64.so.1`».
- O binário da lição, por outro lado, é `not a dynamic executable` e não pede intérprete: é **estático**, traz dentro tudo de que precisa.
- E a última consulta procura o carregador e a biblioteca C na imagem final: `(no está)`. A base `static` não os traz, porque é para programas estáticos.

O manual do Linux explica a cadeia. Um programa dinâmico não inicia sozinho: o kernel lê no próprio executável qual é seu carregador, o que está «guardado na seção `.interp` do programa», e o executa para que ele procure e carregue «os objetos compartilhados (bibliotecas compartilhadas) de que precisa» ([ld.so(8)](https://man7.org/linux/man-pages/man8/ld.so.8.html)). Se esse carregador não existe, a chamada de sistema que inicia programas, `execve`, falha com o erro `ENOENT`, que o manual descreve assim: «o caminho, ou um intérprete de *script* ou de ELF, não existe» ([execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html)). `ENOENT` é justamente o erro impresso como `no such file or directory`. A mensagem não mente; só não diz **qual** arquivo falta, e o que falta não é o que ela nomeia.

#### 5.8.3 Por que o Go fez um binário dinâmico

O Go é famoso por produzir binários que não dependem de nada, e isso é verdade quase sempre. A exceção é o *cgo*, o mecanismo com que um programa Go chama código em C. A documentação do Go diz que o *cgo* «está ativado por padrão nas compilações nativas, nos sistemas em que se espera que funcione», e que é desativado com a variável `CGO_ENABLED=0` ([cmd/cgo](https://pkg.go.dev/cmd/cgo)). A imagem do Go traz um compilador de C (apareceu em 5.1: `gcc`), então ali o *cgo* está ativado.

E para que o `revisor` iria querer código em C, se não tem nem uma linha de C? Por causa da rede. O `revisor` usa o pacote `net` da biblioteca padrão, para seu servidor e para consultar outros serviços. Esse pacote traz duas formas de converter um nome em um endereço: uma escrita em Go puro e outra que chama as funções da biblioteca C do sistema. Normalmente usa a do Go, mas sob certas configurações do sistema usa a de C ([pacote net, «Name Resolution»](https://pkg.go.dev/net#hdr-Name_Resolution)). Para poder escolher ao rodar, quando o *cgo* está disponível o binário leva as duas, e foi isso que apareceu com `ldd` em 5.8.1: a dependência de `libc.so.6` e do carregador. Com `CGO_ENABLED=0`, o Go usa só sua implementação própria e o binário fica estático.

A correção, então, é a do estágio `binario` da lição: `CGO_ENABLED=0` na frente do `go build`. Não é preciso trocar de base nem copiar bibliotecas manualmente.

> [!NOTE]
> 🔧 **Observação de engenharia 5.5**
> Um build verde não garante uma imagem que inicia. Entre construir e rodar há um acordo implícito entre o binário e a base: o que um pede, a outra precisa ter. Por isso cada imagem nova é **rodada** antes de ser dada como boa, nem que seja com um subcomando tão simples quanto `version`.

### 5.9 O que aparece em tutoriais antigos

Os builds em vários estágios chegaram ao Docker na versão 17.05, de 4 de maio de 2017: as notas dessa versão anunciam «suporte a builds em vários estágios» e, na mesma lista, a opção para indicar o estágio-alvo ([notas do Docker Engine 17.05](https://docs.docker.com/engine/release-notes/17.05/)). Antes disso, o problema desta lição era resolvido com truques que ainda aparecem em repositórios antigos:

- **O «padrão do builder» com dois Dockerfiles.** Um `Dockerfile.build` construía uma imagem com o compilador; um script de *shell* criava um contêiner dessa imagem, tirava o binário com `docker cp` e depois construía uma segunda imagem com outro Dockerfile. Funcionava, mas eram três passos que precisavam ser mantidos sincronizados manualmente. Um único build com vários estágios faz o mesmo.
- **`RUN` encadeados com `&&` que instalam, compilam e apagam em uma única linha**, para que o que foi apagado não fique em nenhuma camada. Era a forma de economizar espaço com um único estágio; continua sendo menos eficaz do que não colocar o compilador na imagem final.
- **`FROM scratch`.** `scratch` é uma imagem vazia, sem um único arquivo. Um binário estático pode rodar ali, e muitos tutoriais fazem isso. Falta o que a *distroless* `static` traz: certificados para HTTPS, fusos horários e um `/etc/passwd` com um usuário sem privilégios. Para o `revisor`, que consulta serviços e não deve rodar como `root`, a base do curso poupa ter de acrescentar essas peças manualmente.
- **`FROM alpine` como base final «porque é pequenininha».** A Alpine é pequena, mas traz *shell* e gerenciador de pacotes, e usa outra biblioteca C (musl), diferente da do Debian: um binário dinâmico compilado na imagem do Go do Debian não inicia nela, pelo mesmo motivo de 5.8.
- **`COPY --from=0`**, com número em vez de nome. Funciona, mas quebra em silêncio no dia em que alguém acrescentar um estágio no início.

## O erro que se vai ver

Esta lição tem um erro principal e um que não se vê.

**O erro principal: `exec /revisor: no such file or directory`.** É o de `fig05_08.sh`:

```text
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]
```

Lê-se assim: o contêiner não conseguiu **iniciar** o programa, e o programa nunca foi executado (por isso não imprimiu nada próprio). O traiçoeiro é que o arquivo nomeado existe. O que falta é o que esse arquivo precisa para iniciar: seu carregador dinâmico e as bibliotecas que ele pede. Ao ver essa mensagem com uma base mínima, a sequência é:

1. Construa o estágio do binário com `--target` e olhe o programa com `ldd` e `readelf -l`. Se disser `not a dynamic executable`, o problema é outro (confira o caminho do `ENTRYPOINT`). Se listar bibliotecas e um intérprete, a causa foi encontrada.
2. Corrija na compilação: para Go, `CGO_ENABLED=0`. Se um programa realmente precisa da biblioteca C, a base correta é uma que a traga, não a variante `static`: a *distroless* tem variantes mais completas, como `base` e `cc`, e sua documentação diz o que cada uma traz.
3. O que **não** se faz é copiar bibliotecas soltas para a imagem final até ela iniciar, nem trocar a base por uma com *shell* «para funcionar». O primeiro é frágil e o segundo desfaz a lição.

**O erro que não se vê: o estágio de testes que ninguém roda.** É a segunda metade de `fig05_05.sh`: com `FROM compilacion AS binario`, um teste quebrado não interrompe o build, porque o BuildKit não constrói um estágio do qual a imagem final não depende. Não há mensagem para ler; o sintoma é justamente **não haver** `FAIL`. A única forma de encontrá-lo é a daquela figura: acrescentar um teste quebrado de propósito e comprovar que o build falha com `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. Se terminar com código 0, confira de que estágio sai o estágio do binário.

## O hábito de segurança da lição

**Entregar só o que é necessário para rodar, sobre uma base mínima, fixada e sem `root`.** A imagem final não tem *shell*, nem gerenciador de pacotes, nem compilador, nem `curl`; roda com o usuário 65532; e sua base está fixada por *digest*. Este hábito evita três acidentes concretos. O primeiro é o da cena: quem conseguir executar algo dentro do contêiner — por um erro do programa, por exemplo — não encontra ferramentas com que baixar, compilar nem executar mais nada; precisa trazer tudo, e sem *shell* nem sequer tem com que executar. O segundo é a base que muda sozinha: sem *digest*, um build de amanhã pode trazer uma base diferente da de hoje sem que ninguém decida isso. O terceiro é o ruído: um scanner que revisa 16 MB com alguns pacotes diz algo que dá para ler; um que revisa 1.32 GB com duzentos pacotes do Debian, não. A imagem ainda diminuir oitenta vezes de tamanho é a consequência, não o objetivo.

## O que se faz errado

**Reduzir a imagem apagando arquivos com `RUN rm`.** O que foi apagado continua na camada de baixo; a imagem não diminui. O que não deve viajar fica em outro estágio.

**Entregar a imagem de um único estágio «porque funciona».** Funciona igual à de 16 MB, e leva uma oficina completa para quem entrar. Rodar não é o critério; o critério é o que mais ela leva.

**Tirar o binário do estágio de compilação e deixar os testes em um estágio separado de que ninguém precisa.** Parece que há testes, e não há (5.5). O binário sai **do** estágio de testes.

**Fixar a base só pela tag, ou usar a tag `nonroot` da *distroless* sem *digest*.** É usar `latest` com outro nome. Tag para ler, *digest* para garantir.

**Copiar o *digest* de uma plataforma em vez do do índice.** A base fica amarrada a uma única arquitetura, e quem construir em outra não recebe a que lhe corresponde. O *digest* que vai no `FROM` é o da linha `Digest:` de cima, a do índice.

**Trocar a base final por uma com *shell* «para poder depurar».** Depura-se de fora (`logs`, `inspect`, `top`, `export`) e a partir do estágio de build com `--target`; a imagem entregue não carrega ferramentas por precaução.

**Usar `CMD` quando a imagem é um programa com subcomandos.** Com `CMD ["revisor"]`, `docker run imagen version` substitui o programa inteiro. Com `ENTRYPOINT ["/revisor"]`, ele é acrescentado como argumento.

**Dar uma imagem como boa porque ela foi construída.** O binário dinâmico de 5.8 é construído sem um único erro. Uma imagem é dada como boa quando **roda**.

## Exercícios

Faça-os em ordem. Antes de cada um, escreva no [diário de bordo](bitacora.md) o que se espera que aconteça; comparar depois é metade do aprendizado. Se algo for rodado, ao terminar apague o que foi criado: tudo leva o prefixo `curso-docker-`.

### Exercício 1 — Que estágios rodam?

Com o Dockerfile da lição (fig05_02), e supondo que o cache está vazio, diga que estágios o BuildKit constrói em cada caso:

1. `docker build -t curso-docker-revisor:1.2.0 .`
2. `docker build --target pruebas -t curso-docker-revisor:pruebas .`
3. `docker build --target compilacion -t curso-docker-revisor:compilacion .`
4. Com a variante de `fig05_05.sh` (`FROM compilacion AS binario`): `docker build -t curso-docker-revisor:1.2.0 .`

E mais uma pergunta: no caso 2, a imagem resultante tem o binário `/out/revisor`?

### Exercício 2 — Corrigir o Dockerfile alheio

Um colega passa este Dockerfile «de vários estágios» para o `revisor`. Encontre **seis** problemas que causam um acidente, diga qual acidente cada um causa e escreva a versão corrigida. (Há também dois detalhes de estilo que vale a pena corrigir; eles não contam entre os seis.)

```dockerfile
FROM golang:latest
WORKDIR /src
COPY . .
RUN go test ./...

FROM golang:latest
WORKDIR /src
COPY . .
RUN go build -o /revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=1 /revisor /revisor
CMD ["/revisor"]
```

Dica: um dos seis é o erro principal da lição e outro é o erro que não se vê.

### Exercício 3 — O `FROM` correto

Com a saída de `fig05_09.sh` à vista, escreva o `FROM` do estágio final para estes três casos, e diga qual dos três é o correto para o curso:

1. Só por tag.
2. Por tag e pelo *digest* que serve em qualquer plataforma.
3. Por tag e pelo *digest* da plataforma local, se o Mint for Intel ou AMD.

O que acontece com o caso 3 se um colega com um computador ARM construir esse Dockerfile?

### Exercício 4 — A imagem, medida (projeto)

Na pasta `~/curso-docker/revisor`, com a imagem `curso-docker-revisor:1.2.0` construída em 5.3.3, comprove sem olhar a lição:

1. Seu tamanho, comparado com o da `1.1.0` anotado na Lição 4. Anote os dois no diário de bordo.
2. Que ela não tem *shell*.
3. Que ela não roda como `root`, de duas formas diferentes: uma que leia a configuração da imagem e outra que olhe o processo a partir do host.
4. Que o binário da imagem é estático, sem entrar na imagem final.

O exercício se autocorrige: terminou quando há quatro comandos cujas saídas dizem, respectivamente, uns 16 MB, `executable file not found`, `65532` (duas vezes) e `not a dynamic executable`.

## Soluções

### Solução 1

1. Os quatro: `final` copia de `binario`, `binario` sai de `pruebas` e `pruebas` sai de `compilacion`. É a corrente que obriga a rodar os testes. Isso apareceu no primeiro bloco de `fig05_03.sh`.
2. `compilacion` e `pruebas`, e nada mais. É exatamente o que `fig05_04.sh` mostrou: nem uma linha de `binario` nem de `final`.
3. Só `compilacion`.
4. `compilacion`, `binario` e `final`. **`pruebas` não roda**, porque ninguém no caminho do estágio final precisa dele: é a segunda metade de `fig05_05.sh`, que terminou com código 0 e uma imagem, com um teste quebrado dentro.

A pergunta extra: **não**. O estágio `pruebas` só roda `go test`; o binário é produzido no estágio `binario`, que vem depois e não foi construído. A imagem `pruebas` tem o código-fonte e o compilador, por isso pesa 1.31 GB.

### Solução 2

1. **`golang:latest`.** A base pode mudar em qualquer build, e com ela a versão do Go: o mesmo código compila diferente de um dia para outro. O certo é `golang:1.27.3-trixie@sha256:…`.
2. **O estágio do binário não sai do de testes.** É um `FROM golang:latest` separado, então o estágio de testes não está no caminho do final e o BuildKit **não o roda**: um teste quebrado não interrompe nada (o erro que não se vê, 5.5). O estágio do binário deve sair do de testes.
3. **Falta `CGO_ENABLED=0`.** O binário sai dinâmico e na *distroless* `static` falha com `exec /revisor: no such file or directory` (o erro principal, 5.8).
4. **`COPY --from=1` com número.** No dia em que alguém acrescentar ou tirar um estágio no início, o número aponta para outro estágio e copia-se o que não é, sem aviso. Com nomes (`COPY --from=binario`), isso não acontece.
5. **A base final sem *digest*.** A tag `nonroot` sem *digest* é `latest` com outro nome: a base pode mudar sem que ninguém decida (5.7).
6. **`CMD` em vez de `ENTRYPOINT`.** Com `CMD ["/revisor"]`, `docker run imagen version` substitui o programa inteiro e o Docker tenta executar um arquivo chamado `version`, que não existe (5.3.2).

Os dois detalhes de estilo: o `COPY . .` repetido em dois estágios (copia duas vezes todo o contexto; com um estágio `compilacion` comum basta uma vez, e com `COPY` seletivos, como na Lição 4) e o `USER` implícito (a base `nonroot` já roda como 65532, porque sua configuração diz `"User": "65532"`, mas escrever `USER 65532:65532` deixa a intenção à vista de quem lê o Dockerfile).

A versão corrigida é o Dockerfile da lição, `fig05_02.Dockerfile`.

### Solução 3

1. `FROM gcr.io/distroless/static-debian13:nonroot AS final`
2. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final`
3. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a AS final`

O correto é o 2: o *digest* do índice, o da linha `Digest:`, que serve em `amd64` e em `arm64`. Com o 3, a base fica amarrada à imagem de `linux/amd64`: no computador ARM do colega, o Docker já não consegue escolher dentro do índice a base da plataforma dele, porque o `FROM` não nomeia o índice, e sim uma única de suas imagens, e a imagem final dele terminaria com uma base de arquitetura diferente da do binário. Esta lição não executou esse caso; o que importa é que, com o *digest* do índice, a pergunta nem aparece. Os *digests* desta solução são os de 21 de outubro de 2026; se `fig05_09.sh` mostrar outros, use os novos e anote no diário de bordo que a base mudou.

### Solução 4

Uma forma de fazer:

```bash
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.2.0
docker exec curso-docker-revisor sh
docker inspect --format '{{.Config.User}}' curso-docker-revisor
docker top curso-docker-revisor -o pid,user,args
docker build -q --target binario -t curso-docker-revisor:binario .
docker run --rm curso-docker-revisor:binario ldd /out/revisor
docker rm -f curso-docker-revisor && docker rmi curso-docker-revisor:binario
```

As saídas esperadas são as da lição: `16.1MB` (alguns megabytes a mais ou a menos em Intel ou AMD) contra `1.32GB`; o erro `exec: "sh": executable file not found in $PATH` com código 127; `65532:65532` em `inspect` e `65532` na coluna `USER` de `top`; e `not a dynamic executable` em `ldd` (como em `fig05_08.sh`). Se no último passo `ldd` listar `libc.so.6`, o Dockerfile perdeu o `CGO_ENABLED=0`.

## Como sei que consegui

Marque cada ponto só se ele puder ser feito **sem voltar a ver o texto**:

- [ ] `docker image ls curso-docker-revisor` mostra a tag `1.2.0` com uns **16 MB**, e o antes e o depois ficaram anotados no diário de bordo (na execução desta lição, 1.32 GB → 16.1 MB).
- [ ] `docker run --rm curso-docker-revisor:1.2.0 version` imprime `desarrollo`.
- [ ] `docker exec` com `sh` sobre um contêiner da imagem falha com `executable file not found in $PATH`, e `docker top` mostra o processo com o usuário `65532`.
- [ ] Um teste quebrado foi acrescentado à pasta, `docker build -t curso-docker-revisor:rota .` falhou com `exit code: 1` e `docker image ls curso-docker-revisor:rota` não mostra nada; depois o teste foi apagado.
- [ ] Dá para explicar por que `FROM pruebas AS binario` e não `FROM compilacion AS binario`, com a frase do BuildKit sobre que estágios ele constrói.
- [ ] Dá para explicar que arquivo falta quando aparece `exec /revisor: no such file or directory`, e como confirmar isso com `ldd` ou `readelf` a partir do estágio `binario`.
- [ ] Dá para dizer o que a tag garante, o que o *digest* garante e por que o *digest* do `FROM` é o do índice.
- [ ] Os scripts de [`programas/05-multi-stage/`](../programas/05-multi-stage) foram rodados e as saídas coincidem com as desta lição no que cada seção marca como estável. O que não se compara: os números de passo, os PID, os tempos, as datas, os endereços de `ldd`, a arquitetura, os tamanhos em alguns megabytes, e os *digests* de `fig05_09.sh` se a base foi publicada de novo. E ao terminar, `docker ps -a --filter name=curso-docker-` não mostra contêineres desta lição.

## Resumo

Responda sem olhar a lição:

1. Por que a imagem da Lição 4 pesava 1.32 GB se o `revisor` pesava 9,5 MB? Por que apagar o compilador com um `RUN rm` não a reduz?
2. O que é um estágio? O que fazem `AS`, `COPY --from` e `--target`?
3. Que estágios o BuildKit constrói quando se pede a imagem final? Que consequência isso tem para o estágio de testes?
4. O que a base *distroless* `static` traz e o que não traz? Que ferramentas sobram para depurar uma imagem sem *shell*?
5. Por que o Dockerfile usa `ENTRYPOINT ["/revisor"]` em vez de `CMD ["revisor"]`?
6. O que é um *digest*? Por que a tag e o *digest* são escritos juntos, e que preço tem fixar a base?
7. O que significa `exec /revisor: no such file or directory` quando o arquivo existe? O que `CGO_ENABLED=0` faz?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [Docker, «Multi-stage builds»](https://docs.docker.com/build/building/multi-stage/): vários `FROM`, copiar seletivamente entre estágios, nomear os estágios, `--target`, e que o BuildKit só constrói os estágios de que o estágio-alvo depende.
- [Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/): que o armazenamento do containerd guarda cada camada compactada e descompactada, o que explica o tamanho de `docker image ls`.
- [Docker, boas práticas de build](https://docs.docker.com/build/building/best-practices/): os estágios para reduzir o tamanho, a base mínima, as tags mutáveis e a fixação por *digest* com seu preço.
- [Referência do Dockerfile](https://docs.docker.com/reference/dockerfile/): a sintaxe `FROM <imagen>[@<digest>] [AS <nombre>]`, `COPY --from` e como `ENTRYPOINT` e `CMD` recebem os argumentos de `docker run`.
- [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/): as opções `--target` e `--no-cache-filter`.
- [Docker Engine 17.05, notas de versão](https://docs.docker.com/engine/release-notes/17.05/): a chegada dos builds em vários estágios e do estágio-alvo, em 4 de maio de 2017.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões e datas de «Sobre as execuções».
- [distroless (GoogleContainerTools)](https://github.com/GoogleContainerTools/distroless): o que as imagens *distroless* trazem e não trazem, o tamanho de `static-debian13`, suas tags e a recomendação de nomear a versão do Debian.
- [golang no Docker Hub](https://hub.docker.com/_/golang): a tag `1.27.3-trixie` e seus aliases.
- [OCI Image Specification, descritores](https://github.com/opencontainers/image-spec/blob/main/descriptor.md): o que é um *digest* e por que ele identifica o conteúdo.
- [cmd/cgo](https://pkg.go.dev/cmd/cgo): quando o *cgo* está ativado e como é desativado com `CGO_ENABLED=0`.
- [Pacote net do Go, «Name Resolution»](https://pkg.go.dev/net#hdr-Name_Resolution): as duas formas de resolver nomes, a de Go puro e a que usa a biblioteca C.
- [cmd/link](https://pkg.go.dev/cmd/link): as opções `-s` e `-w` do linker, e que `-s` implica `-w`.
- [cmd/go, `go build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies): a opção `-trimpath`.
- [ld.so(8), manual do Linux](https://man7.org/linux/man-pages/man8/ld.so.8.html): o carregador dinâmico e a seção `.interp`.
- [execve(2), manual do Linux](https://man7.org/linux/man-pages/man2/execve.2.html): o erro `ENOENT` quando falta o intérprete de um ELF.
- [Colima](https://github.com/abiosoft/colima): a ferramenta com que os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **binário dinâmico** | executável que precisa de bibliotecas do sistema e de um carregador para iniciar |
| **binário estático** | executável que traz dentro tudo de que precisa; não depende de bibliotecas do sistema |
| **carregador dinâmico** | programa (`ld-linux…`) que inicia um binário dinâmico e carrega suas bibliotecas |
| ***cgo*** | mecanismo com que um programa Go chama código em C; é desativado com `CGO_ENABLED=0` |
| ***digest*** | hash SHA-256 do conteúdo de uma imagem ou de um índice; se um byte muda, ele muda |
| ***distroless*** | família de imagens base mínimas, sem *shell* nem gerenciador de pacotes |
| **estágio** (*stage*) | cada parte de um Dockerfile que começa com um `FROM`; só o último é a imagem entregue |
| **estágio-alvo** (*target*) | o estágio até o qual se constrói com `--target` |
| **índice** (*image index*) | lista de imagens de um mesmo nome, uma por plataforma |
| ***multi-stage*** | build em vários estágios dentro de um mesmo Dockerfile |

---

**Próxima:** [Lição 6 — Configuração e segredos](06-configuracion-y-secretos.md)
