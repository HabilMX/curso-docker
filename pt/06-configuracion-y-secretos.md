# Lição 6 — Configuração e segredos

É quinta-feira, 18h40, e a equipe quer liberar o `revisor` às sete. Falta um detalhe: o ambiente de testes precisa de outra lista de serviços e de um token diferente. Alguém propõe o caminho rápido: «Troco o token no Dockerfile, reconstruo e envio; são cinco minutos». Faz isso, e a imagem vai para o registry compartilhado. Às 18h52, um colega de outra equipe pergunta no chat, com toda a inocência do mundo, por que a imagem do `revisor` traz uma variável `REVISOR_TOKEN` com um valor que parece uma senha. Ele não precisou entrar em nenhum servidor nem quebrar nada: bastou um `docker inspect` sobre uma imagem que ele tinha permissão para baixar. Agora o token precisa ser dado como perdido, é preciso gerar outro e descobrir quem mais baixou a imagem. A liberação das sete já não sai. Esta lição existe para que essa conversa não aconteça: a imagem não leva nem a configuração de um ambiente nem seus segredos, e vai ser possível comprovar com os próprios olhos o que fica dentro dela.

**Tempo:** 90 min

**O que se constrói:** o `revisor` configurado sem reconstruir. A imagem `curso-docker-revisor:1.3.0` leva gravada sua versão, que não é secreta, e nada mais de nenhum ambiente. A lista de serviços chega ao rodar o contêiner, por variáveis de ambiente ou por um arquivo de variáveis. O token de acesso chega como um arquivo somente leitura, nunca como variável. E o padrão para usar um segredo **durante o build** fica pronto no Dockerfile sem deixar rastro na imagem.

**O que se aprende:** o que é configuração e o que é segredo; `ARG` versus `ENV` (quando cada um existe e onde fica); `-e` e `--env-file`; os rótulos OCI com a versão; os segredos de build com `--mount=type=secret` e `--secret`; os segredos de execução por arquivo e por que não por variável; e, sobretudo, a **olhar** com `docker history` e `docker inspect` o que viaja dentro de uma imagem.

**De onde se parte.** Da [Lição 5](05-multi-stage.md), em que o `revisor` ficou em uma imagem de quatro estágios, `curso-docker-revisor:1.2.0`, de 16.1 MB, sem *shell*, sem compilador e com o usuário `65532`. Essa imagem tem uma lacuna que talvez tenha chamado atenção: seu subcomando `version` diz `desarrollo`, porque ninguém disse a ele que versão é. Traz-se também da [Lição 3](03-primer-dockerfile.md) o `.dockerignore` que deixa de fora `.env` e `secretos/`, e da [Lição 2](02-contenedores-dia-a-dia.md) o costume de publicar portas só em `127.0.0.1`. E da Lição 3, o erro de iniciar o `revisor` sem `REVISOR_SERVICIOS`: hoje vai ficar claro por que essa variável não vai no Dockerfile.

**O que esta lição não faz.** Não explica a fundo as montagens: o token chega com um `--mount type=bind` de um único arquivo, e por enquanto basta saber que ele coloca um arquivo da máquina dentro do contêiner. A [Lição 8](08-volumenes-y-redes.md) explica as montagens completas. Também não usa os segredos do Compose, que são a forma cômoda de fazer o mesmo e chegam na [Lição 9](09-compose.md). Não ensina gerenciadores de segredos externos (cofres, serviços de nuvem): este curso trabalha na máquina local, e o que se aprende aqui é a parte de que esses gerenciadores também precisam, que o segredo chegue como arquivo e não fique na imagem. E não é preciso ter módulos privados de Go: o `revisor` não os usa, e o segredo de build é ensinado com um valor falso.

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4, a mesma base do Linux Mint 22, o sistema de referência do curso. Os scripts foram executados **dentro** dessa máquina virtual, com Docker 29.2.1 (cliente e daemon) e Buildx v0.31.1, e com sua pasta de trabalho no disco próprio do Linux. Isso importa nesta lição: as pastas compartilhadas entre o Mac e a máquina virtual mentem sobre as permissões (um arquivo com permissões `600` é lido do mesmo jeito por um contêiner de outro usuário), e a seção 6.5 trata justamente de permissões. No Mint esse problema não existe. Para não haver conflito com outras execuções que usavam a mesma máquina, os scripts foram lançados com outro prefixo de nomes e outras portas (as variáveis `PREFIJO` e `PUERTO` que eles trazem); nenhum nome de contêiner nem de imagem, nem a porta da máquina, aparece em suas saídas, então o que se vê é exatamente o que eles imprimiram. Com seus valores padrão, os scripts usam nomes de apoio próprios que levam `fig06` (a imagem `curso-docker-revisor:fig06`, o contêiner `curso-docker-revisor-fig06`): assim nunca tocam na imagem `curso-docker-revisor:1.3.0` nem no contêiner `curso-docker-revisor` locais, e ao sair apagam só o que criaram. O curso foi planejado com o Docker Engine 29.8.2, e a mais recente publicada naquele dia era a 29.9.2, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)); nada desta lição muda entre essas versões. O que **muda** de uma execução para outra, e é avisado onde aparece: os tempos da tabela do `revisor` (escondidos com `<t>` no próprio script), os tempos e a data das linhas de build, e a palavra `arm64` no histórico da imagem, que em uma máquina Intel ou AMD diz `amd64`. Os programas estão em [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos), cada um com sua saída ao lado, e `estado/` guarda os arquivos do projeto tal como ficam ao terminar.

## Ao terminar, será possível

- Classificar uma informação do `revisor` como código, configuração ou segredo, e dizer onde cada um deve viver.
- Explicar a diferença entre `ARG` e `ENV` dizendo quando cada um existe e onde fica escrito, e comprovar isso com `docker history` e `docker image inspect`.
- Rodar a mesma imagem com duas configurações diferentes, com `-e` e com `--env-file`, sem reconstruir.
- Encontrar um segredo deixado em uma imagem por `ARG` ou por `ENV`, e ler a advertência `SecretsUsedInArgOrEnv` de `docker build --check`.
- Entregar o token do `revisor` como arquivo somente leitura, e corrigir o erro `permission denied` que aparece ao fazer isso.
- Usar um segredo durante o build com `--secret` e demonstrar que ele não ficou na imagem.

## O porquê antes do como

Até a Lição 5, tudo o que o `revisor` precisava para rodar saía da imagem ou de alguns `-e` escritos na hora. Funcionava porque havia um único ambiente: a máquina local. Assim que aparece um segundo ambiente (testes, produção, o computador de um colega), aparece a pergunta desta lição: **o que muda entre um ambiente e outro, e onde isso é escrito?**

A resposta clássica vem de um guia muito citado, *The Twelve-Factor App*, que define a configuração de uma aplicação como «tudo o que provavelmente varia entre deploys» ([12factor.net, «Config»](https://12factor.net/config)). No `revisor`, isso é a lista de serviços que ele verifica, a porta, o caminho do relatório e o token. O que **não** varia é o código e a versão: a `1.3.0` é a `1.3.0` em todo lugar. O mesmo guia propõe um teste simples para saber se a separação está boa: daria para publicar o código como aberto neste momento sem expor nenhuma credencial? Este curso é aberto, então o teste não é hipotético: o Dockerfile do `revisor` está publicado, e por isso não pode levar nada que não se queira que o mundo leia.

Com imagens, a pergunta tem mais uma volta. Uma imagem não é só um arquivo que roda; é um pacote que **viaja**: é enviado a um registry, baixado em outras máquinas, guardado em caches, copiado para um cluster. Tudo o que for colocado nela é recebido por qualquer um que possa baixá-la. E uma imagem guarda mais do que parece: além dos arquivos de suas camadas, guarda sua **configuração** (o ambiente, o usuário, os rótulos) e seu **histórico** (a instrução que criou cada camada, com os valores que ela tinha). A documentação do Docker diz isso sem rodeios: os argumentos de build e as variáveis de ambiente «não são apropriados para passar segredos ao build», porque «persistem na imagem final» ([Docker, «Build secrets»](https://docs.docker.com/build/building/secrets/)).

Então esta lição faz três coisas, nesta ordem:

1. **Tirar a configuração da imagem** (6.1 a 6.3): a imagem leva sua versão e valores padrão que não são secretos; o resto chega ao rodar.
2. **Ver com os próprios olhos o que acontece quando um segredo entra na imagem** (6.4): ele vai ser colocado de propósito, com valores falsos, e vai ser encontrado.
3. **Fazer certo** (6.5 e 6.6): o segredo de execução como arquivo somente leitura, e o segredo de build como montagem que dura o mesmo que um `RUN`.

Com esse destino em mente, isto é o que vai aparecer na seção 6.4, ao procurar dentro de uma imagem mal feita. O valor falso está ali, no histórico, embora o próprio `RUN` tenha apagado o arquivo que o continha:

```text
== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

## Os conceitos

### 6.1 Código, configuração e segredo: três coisas diferentes

#### 6.1.1 Classificar o que o `revisor` precisa

Antes de escrever uma única linha, convém dar nome a cada informação. Há três caixas:

| Caixa | O que é | No `revisor` | Onde vive |
|---|---|---|---|
| **Código** | o que o programa faz; igual em todos os ambientes | o binário, compilado na versão `1.3.0` | dentro da imagem |
| **Configuração** | o que muda de um ambiente para outro e não é secreto | `REVISOR_SERVICIOS`, `REVISOR_PUERTO`, `REVISOR_REPORTE` | fora da imagem; chega ao rodar |
| **Segredo** | configuração que, se vazar, alguém pode usar contra nós | o token de `/api/estados`; uma credencial para baixar módulos privados | fora da imagem **e** fora das variáveis de ambiente; chega como arquivo |

Duas informações merecem comentário. A **porta** é configuração, mas tem um valor padrão razoável (`8080`) que não é secreto, e por isso a imagem a traz declarada com `ENV`: serve como documentação e como valor padrão, e qualquer ambiente pode mudá-la. A **versão** não é configuração: não muda entre ambientes, descreve o código. Por isso é gravada ao construir e não é pedida ao rodar.

O segredo tem sua própria caixa porque cumpre as duas condições: muda entre ambientes (o token de testes não é o de produção) e seu valor não pode ficar à vista. Essa segunda condição é a que descarta as variáveis de ambiente, como aparece em 6.5.

#### 6.1.2 Os segredos deste curso são falsos, e dizem isso

Todos os segredos que aparecem nesta lição são **inventados para o exercício** e anunciam isso no próprio valor: `curso-docker-token-de-mentira-7f3a9c`, `curso-docker-modulos-de-mentira-41be`. Não abrem nada. Vivem na pasta `secretos/` do projeto, que o curso publica de propósito para que tudo possa ser rodado. Em um projeto de verdade essa pasta **nunca** é publicada: vai no `.gitignore` e no `.dockerignore`, e seus valores vêm de onde a equipe guarda as credenciais.

O `.dockerignore` que vem das lições 3 e 4 já a exclui, junto com `.env` e os `Dockerfile*`:

```text
# Lo que nunca viaja al daemon al construir.
.git
.env
*.tar
*.md
Dockerfile*
.dockerignore
compose.yaml
secretos/
```

Isso significa que nenhum `COPY` pode colocar por acidente um arquivo de `secretos/` na imagem: ele nem chega ao daemon. É a primeira porta, e a mais barata. Esta lição fecha as outras três: o histórico, a configuração da imagem e a configuração do contêiner.

### 6.2 `ARG` versus `ENV`

#### 6.2.1 Duas instruções que se parecem e não se parecem

As duas instruções definem variáveis com nome e valor, e as duas são usadas com `${NOMBRE}` dentro do Dockerfile. O que as separa é **quando existem**:

- **`ARG`** declara um **argumento de build**. Existe só enquanto a imagem é construída, e seu valor pode ser mudado de fora com `docker build --build-arg NOMBRE=valor`. Os contêineres que nascem da imagem não o recebem. A documentação resume assim: os argumentos de build «não são acessíveis nem estão presentes nos contêineres» criados a partir da imagem, mas seus valores «podem persistir nos metadados da imagem», nas atestações de procedência e **no histórico** ([Docker, «Build variables»](https://docs.docker.com/build/building/variables/)).
- **`ENV`** define uma **variável de ambiente** que existe durante o build e que, além disso, a imagem entrega a cada contêiner que nasce dela: «as variáveis de ambiente definidas com `ENV` persistem quando um contêiner é executado a partir da imagem», e podem ser vistas com `docker inspect` e mudadas com `docker run --env` ([referência do Dockerfile](https://docs.docker.com/reference/dockerfile/)).

Em uma linha: `ARG` é uma informação para **construir**; `ENV` é uma informação para **rodar**. E nenhum dos dois é um esconderijo: os dois deixam seu valor escrito na imagem, um no histórico e o outro na configuração.

Há um detalhe de escopo que confunde todo mundo na primeira vez. Um `ARG` vale **no estágio em que é declarado** (e nos estágios que saem dele). Em um Dockerfile de vários estágios, se o estágio `final` também precisa do valor, ele o declara de novo. É o que o Dockerfile desta lição faz com `VERSION`.

#### 6.2.2 O Dockerfile desta lição

Este é o Dockerfile com que a lição termina. É o da Lição 5 com quatro mudanças, e cada uma é explicada abaixo:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_01.Dockerfile — Lección 6: la imagen no lleva configuración de un ambiente ni secretos.
# Lo único que se le fija al construir es su VERSIÓN, que no es secreta.

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
ENTRYPOINT ["/revisor"]
```

As quatro mudanças, na ordem em que aparecem:

1. **`ARG VERSION=desarrollo` no estágio `binario`.** Declara o argumento com um valor padrão. Construindo sem `--build-arg`, ele vale `desarrollo`, que é exatamente o que o `revisor` dizia na Lição 5; assim nada quebra para quem constrói sem saber desse argumento.
2. **`-X main.version=${VERSION}` em `go build`.** É uma opção do linker do Go que substitui, ao compilar, o valor de uma variável de texto do programa ([cmd/link](https://pkg.go.dev/cmd/link)). O `revisor` tem uma variável `version` em seu pacote `main` que vale `desarrollo` se ninguém mexer nela. Com essa opção, o número fica **dentro do binário**, que é o único lugar onde ele não pode se perder nem ser contradito.
3. **`--mount=type=secret,...,required=false`** nesse mesmo `RUN`. É o segredo de build; tem sua própria seção, a 6.6. Por enquanto basta saber que, como é opcional, o build funciona igual com ou sem ele.
4. **No estágio `final`: `ARG VERSION` de novo, `LABEL` e `ENV`.** O `ARG` se repete porque cada estágio tem seu próprio escopo (6.2.1). Com ele, `LABEL` cola na imagem três **rótulos** (*labels*) com nomes de um padrão, o da *Open Container Initiative*: `org.opencontainers.image.title` é o «título legível» da imagem, `org.opencontainers.image.version` é a «versão do software empacotado» e `org.opencontainers.image.source` é a «URL para obter o código-fonte» com que a imagem é construída ([OCI, anotações predefinidas](https://github.com/opencontainers/image-spec/blob/main/annotations.md)). Aqui ele aponta para a página do curso, que é o endereço público de referência deste material; em um projeto próprio, coloque o endereço do repositório, que é o que a especificação pede. Qualquer ferramenta que saiba ler esses rótulos (um registry, um scanner, a Lição 10) sabe o que é a imagem sem rodá-la. E `ENV REVISOR_PUERTO=8080` deixa o valor padrão da porta à vista de quem inspecionar a imagem.

Repare no que **não** há: nem `REVISOR_SERVICIOS`, nem `REVISOR_TOKEN`, nem `REVISOR_TOKEN_ARCHIVO`. A imagem não sabe em que ambiente vai rodar, e é assim que tem de ser.

#### 6.2.3 Construir e ver onde ficou cada coisa

O script `fig06_02.sh` constrói a imagem com `--build-arg VERSION=1.3.0` e depois pergunta a ela, sem rodar o servidor, o que ela traz:

```bash
#!/usr/bin/env bash
# fig06_02.sh — Construir el revisor con su versión como ARG y mirar dónde quedó.
# Construye curso-docker-revisor:1.3.0 con fig06_01.Dockerfile y pregunta a la
# imagen qué trae: la versión, las etiquetas, el entorno y el historial.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

echo "== 1. Construir, pasando la versión como argumento de construcción"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'

echo
echo "== 2. La versión, grabada dentro del binario"
docker run --rm --name "${PREFIJO}revisor-fig06-version" "$IMAGEN" version

echo
echo "== 3. Las etiquetas OCI de la imagen"
docker image inspect --format '{{range $k, $v := .Config.Labels}}{{$k}} = {{$v}}{{println}}{{end}}' "$IMAGEN"

echo "== 4. El entorno que la imagen entrega a cada contenedor (ENV)"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN"

echo "== 5. El historial de la imagen final, de arriba (lo último) hacia abajo"
docker history --format '{{.Size}}	{{.CreatedBy}}' "$IMAGEN" | head -8
```

```text
$ ./fig06_02.sh
== 1. Construir, pasando la versión como argumento de construcción
tamaño: 16.1MB

== 2. La versión, grabada dentro del binario
1.3.0

== 3. Las etiquetas OCI de la imagen
org.opencontainers.image.source = https://www.habil.mx/es/cursos/docker/
org.opencontainers.image.title = revisor
org.opencontainers.image.version = 1.3.0

== 4. El entorno que la imagen entrega a cada contenedor (ENV)
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
REVISOR_PUERTO=8080

== 5. El historial de la imagen final, de arriba (lo último) hacia abajo
0B	ENTRYPOINT ["/revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 65532:65532
6.69MB	COPY /out/revisor /revisor # buildkit
0B	ENV REVISOR_PUERTO=8080
0B	LABEL org.opencontainers.image.title=revisor…
0B	ARG VERSION=1.3.0
319kB	bazel build //common:cacerts_debian13_arm64_…
```

Cinco blocos, cinco lugares diferentes onde vivem informações de uma imagem:

1. **O tamanho não mudou**: 16.1 MB, igual à `1.2.0`. Os rótulos, o `ENV` e o `ARG` não pesam: são metadados, não arquivos.
2. **A versão está no binário.** O subcomando `version` imprime `1.3.0`. É a mesma que `GET /salud` retorna e a mesma que o `revisor` escreve ao iniciar (`revisor 1.3.0 escuchando en :8080`), como aparece em 6.5.
3. **Os rótulos OCI** estão na configuração da imagem e são lidos com `docker image inspect`, sem rodar nada. O template `{{range $k, $v := .Config.Labels}}` percorre o mapa de rótulos; o `docker` os ordena por nome.
4. **O ambiente** que cada contêiner vai receber: duas variáveis que a base *distroless* traz (`PATH` e `SSL_CERT_FILE`, o caminho dos certificados confiáveis) e a nossa, `REVISOR_PUERTO=8080`. Repare bem no que **falta**: `VERSION`. O `ARG` não passou para o ambiente. Nenhum contêiner vai recebê-lo.
5. **O histórico**, do mais recente ao mais antigo. Cada linha é uma instrução do estágio `final` (os outros estágios não estão: não fazem parte da imagem entregue, como apareceu na Lição 5). As que não criam arquivos pesam `0B`. O `…` é o `docker history` cortando linhas longas; com `--no-trunc` elas aparecem completas. E agora a linha que importa para o resto da lição: **`ARG VERSION=1.3.0`**. O valor do argumento está escrito no histórico, à vista de qualquer um que tenha a imagem. Para uma versão, isso é perfeito: não é secreta, e até ajuda. Para um token seria um vazamento. Guarde essa imagem na cabeça; em 6.4 ela vai aparecer com um valor que não deveria estar ali.

A última linha (`bazel build //common:cacerts_debian13_arm64_…`) é uma camada da base *distroless*: seus autores a constroem com uma ferramenta chamada Bazel, e o histórico registra isso. No Mint com processador Intel ou AMD aparece `amd64` onde aqui está `arm64`.

#### 6.2.4 Na pasta local

Os scripts do curso trabalham em pastas temporárias e apagam o que criam; o projeto vive em `~/curso-docker/revisor` desde a Lição 3. A partir da raiz do repositório do curso, coloque ali o Dockerfile desta lição e a pasta de segredos falsos, e construa a imagem que vai ser mantida:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cp -R programas/06-configuracion-y-secretos/estado/secretos ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 -t curso-docker-revisor:1.3.0 .
docker run --rm curso-docker-revisor:1.3.0 version
```

O último comando precisa imprimir `1.3.0`. O `.dockerignore` não muda: já exclui `secretos/`. Em `estado/` também está `Dockerfile.malo`, a receita errada de 6.4. Copie-a também, porque «Como sei que consegui» pede para repetir esse experimento; o `.dockerignore` (que exclui `Dockerfile*`) impede que ela viaje no contexto. E ao chegar a 6.6, reconstrua a imagem com o segredo de build, para comprovar que ele não deixa rastro:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile.malo ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt -t curso-docker-revisor:1.3.0 .
```

Os scripts desta lição não mexem em nada disso: usam nomes de apoio com `fig06` e apagam só o que é deles.

### 6.3 Configurar sem reconstruir

#### 6.3.1 `-e` e `--env-file`

A imagem já não sabe que serviços verificar. Isso é dito a ela **ao rodar**, e há duas formas:

- **`-e NOMBRE=valor`** (ou `--env`), uma por variável, na mesma linha de `docker run`. É o que se usa desde a Lição 2. Escrevendo só `-e NOMBRE`, sem valor, o Docker pega o valor que essa variável tem no terminal e o passa; se ela não existir no terminal, o contêiner não a recebe ([referência de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).
- **`--env-file archivo`**: um arquivo de texto com um `NOMBRE=valor` por linha. As linhas que **começam** com `#` são comentários; um `#` no meio da linha faz parte do valor. Uma linha com só `NOMBRE`, sem `=`, pega o valor do terminal, igual a `-e NOMBRE`. Serve para ter a configuração de cada ambiente em seu próprio arquivo (`pruebas.env`, `local.env`) e não em um comando de três linhas de que ninguém se lembra.

As duas formas podem ser misturadas, e as duas vencem o que o `ENV` da imagem disser. Esse é o sentido de um valor padrão: estar ali até que alguém diga outra coisa.

#### 6.3.2 A mesma imagem, três configurações

O script `fig06_03.sh` constrói `curso-docker-revisor:1.3.0` uma vez e a roda três vezes com configurações diferentes. A primeira tem um erro de propósito:

```bash
#!/usr/bin/env bash
# fig06_03.sh — Configurar sin reconstruir: la MISMA imagen, tres configuraciones.
# Una variable mal escrita, una lista por -e y otra lista por --env-file.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# La tabla del revisor, con el tiempo tapado: es lo único que cambia entre corridas.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
}

echo "== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS"
rc=0
docker run --name "$NOMBRE" -e REVISOR_SERVICIO='propio http://127.0.0.1:8080/salud' "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. La configuración por -e: un solo servicio"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla
IMAGEN_1=$(docker inspect --format '{{.Image}}' "$NOMBRE")
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Otra configuración, desde un archivo con --env-file"
cat > revisor.env <<'FIN'
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
FIN
cat revisor.env
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --env-file revisor.env "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR

echo "== 5. ¿Las dos corridas usaron la misma imagen?"
IMAGEN_2=$(docker inspect --format '{{.Image}}' "$NOMBRE")
[ "$IMAGEN_1" = "$IMAGEN_2" ] && echo "sí: el mismo identificador de imagen en las dos" || echo "no: son imágenes distintas"
```

```text
$ ./fig06_03.sh
== 1. Una letra de menos: REVISOR_SERVICIO en vez de REVISOR_SERVICIOS
revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
[código de salida: 1]

== 2. La configuración por -e: un solo servicio
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 3. Otra configuración, desde un archivo con --env-file
# Configuración de un ambiente. Nada de esto es secreto.
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
SERVICIO     ESTADO    TIEMPO  DETALLE
inexistente  FALLA         <t>  no responde: Get "http://127.0.0.1:9/": dial tcp 127.0.0.1:9: connect: connection refused
propio       OK            <t>  200

== 4. Lo que recibió el contenedor: lo de la imagen más lo de la corrida
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud, inexistente http://127.0.0.1:9/ 1s
REVISOR_PUERTO=8080
== 5. ¿Las dos corridas usaron la misma imagen?
sí: el mismo identificador de imagen en las dos
```

Antes de ler a saída, as linhas novas do script. A função `tabla` pede o relatório em forma de tabela e esconde o tempo de resposta com `<t>`, porque é a única coisa que muda entre execuções; ela esconde **no próprio comando**, à vista, não editando a saída. O serviço `propio` é o `revisor` verificando a si mesmo: dentro do contêiner, `127.0.0.1:8080` é o próprio contêiner, não a máquina. E o serviço `inexistente` aponta para a porta 9, onde nada escuta; está ali para mostrar uma falha.

Agora a saída, bloco por bloco:

1. **Uma letra a menos.** `REVISOR_SERVICIO` não é uma variável que o `revisor` conheça, então ele a ignora em silêncio, como qualquer programa ignora as variáveis que não lê. Para ele, `REVISOR_SERVICIOS` simplesmente não existe, e ele se recusa a iniciar com código 1. É o mesmo erro da Lição 3, mas agora se sabe por que ele é tão comum: o Docker não valida nomes de variáveis; não tem como saber quais o programa lê. Quem valida é o programa, e por isso é bom que o `revisor` falhe de forma ruidosa e com um exemplo, em vez de iniciar com uma lista vazia e fingir que está tudo bem.
2. **Com `-e`, um serviço.** O relatório traz uma linha, `propio`, saudável.
3. **Com `--env-file`, dois serviços.** O arquivo traz um comentário e uma variável. Repare que o valor **não leva aspas**: em um arquivo de `docker run --env-file`, tudo o que vem depois do `=` é o valor, aspas incluídas. É uma armadilha clássica, e o Exercício 3 faz cair nela. Cuidado ao levar essa regra para a Lição 9: o `env_file` do Compose é outro leitor e **remove** as aspas ([referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/)). Medido com o Compose v5.0.2: a mesma linha com aspas chegou ao contêiner como `REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud`, sem elas. Mesmo tipo de arquivo, dois leitores, dois resultados. A tabela agora tem duas linhas: `inexistente` com `FALLA` e a causa exata, e `propio` com `OK`.
4. **O que o contêiner recebeu** é a soma do que a imagem traz (`REVISOR_PUERTO=8080`, por seu `ENV`) e do que chegou ao rodar (`REVISOR_SERVICIOS`, do arquivo). O `grep REVISOR` deixa de fora `PATH` e `SSL_CERT_FILE`, que também estão lá.
5. **A mesma imagem.** O script guardou o identificador de imagem do primeiro contêiner e o comparou com o do segundo: são iguais. Dois comportamentos diferentes, zero reconstruções. Esse é todo o sentido de separar a configuração.

#### 6.3.3 O que isso dá

Separar a configuração da imagem não é uma questão de estilo. Tem três consequências práticas. A primeira: **a imagem testada é a que se entrega**. Se para passar de testes para produção fosse preciso reconstruir com outra configuração, a imagem de produção seria uma que ninguém testou. A segunda: **mudar a configuração custa segundos**, o que um contêiner leva para iniciar, e não o que um build leva. A terceira: **a imagem pode ser publicada**, porque não leva nada de nenhum ambiente. Essas três juntas são o que permite, na Lição 10, publicar uma única imagem e levá-la ao Kubernetes.

### 6.4 Assim NÃO: ver com os próprios olhos o que fica dentro da imagem

#### 6.4.1 A receita errada

Para aprender a encontrar um segredo em uma imagem, o melhor é esconder um e procurá-lo. Este Dockerfile faz as duas coisas que a lição proíbe. Tem um único estágio, como na Lição 4, para que tudo fique à vista:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_04.Dockerfile — Lección 6: ASÍ NO. Dos formas de dejar un secreto dentro de la imagen.
# (Una sola etapa, como en la Lección 4, para que todo quede a la vista.)
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
WORKDIR /src
COPY go.mod ./
COPY cmd/ cmd/
COPY internal/ internal/
# Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
# aunque el RUN borre el archivo al final.
ARG TOKEN_MODULOS
RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
 && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
 && rm /root/.netrc
# Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
USER 10001:10001
CMD ["revisor"]
```

Os dois erros imitam casos reais:

- **Mal 1** é o que faz quem precisa de uma credencial para baixar dependências privadas. O Go, como muitas ferramentas, lê as credenciais de um arquivo `.netrc` na pasta do usuário: uma linha `machine <servidor> password <secreto>`. A receita escreve o arquivo com o valor de um `ARG`, compila e o apaga **no mesmo `RUN`**. Quem a escreveu sabia que um arquivo apagado em um `RUN` posterior continua na camada anterior, e por isso fez tudo em um só. Parece prudente. Não basta. (O servidor é `ejemplo.invalid`, um domínio reservado que não existe na internet.)
- **Mal 2** é o atalho da cena do começo: o token do `revisor` como `ENV`, para que «já venha configurado».

#### 6.4.2 Procurá-lo

O script `fig06_05.sh` constrói essa receita passando a ela o token de módulos falso e depois procura os dois segredos onde qualquer um que tenha a imagem pode procurar:

```bash
#!/usr/bin/env bash
# fig06_05.sh — ASÍ NO: dos secretos (de mentira) que quedan dentro de la imagen.
# Construye fig06_04.Dockerfile y busca los secretos donde cualquiera que tenga
# la imagen los puede buscar: el historial y la configuración.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
MALO="${PREFIJO}revisor:fig06-malo"
CADENA="${PREFIJO}revisor:fig06-cadena"
trap 'docker rmi -f "$MALO" "$CADENA" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_04.Dockerfile" "$TRABAJO/Dockerfile.malo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Construir pasando el token de módulos (de mentira) por ARG"
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" \
  -f Dockerfile.malo -t "$MALO" . >/dev/null && echo "construida"

echo
echo "== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" --user 0 "$MALO" ls -A /root

echo
echo "== 3. Pero el historial guardó el valor del ARG, en dos renglones"
docker history --no-trunc --format '{{.CreatedBy}}' "$MALO" | grep 'TOKEN_MODULOS='

echo
echo "== 4. Y la configuración de la imagen trae el token de ejecución"
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$MALO" | grep TOKEN

echo "== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$MALO" printenv REVISOR_TOKEN

echo
echo "== 6. docker build --check lo habría dicho antes de construir"
rc=0
docker build --check -f Dockerfile.malo . 2>&1 || rc=$?
echo "[código de salida: $rc]"

echo
echo "== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use"
cat > Dockerfile.cadena <<'FIN'
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS base
ARG TOKEN_MODULOS
RUN echo "paso 1: no uso ningún argumento"
FROM base AS hija
ARG VERSION=desarrollo
RUN echo "paso 2: tampoco"
FIN
docker build -q --build-arg TOKEN_MODULOS="$(cat secretos/token_modulos.txt)" --build-arg VERSION=1.3.0 \
  -f Dockerfile.cadena -t "$CADENA" . >/dev/null
docker history --no-trunc --format '{{.CreatedBy}}' "$CADENA" | head -4
```

```text
$ ./fig06_05.sh
== 1. Construir pasando el token de módulos (de mentira) por ARG
construida

== 2. El RUN borró /root/.netrc: dentro de la imagen ya no está
.bashrc
.cache
.config
.profile

== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be

== 4. Y la configuración de la imagen trae el token de ejecución
REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
== 5. Cualquier contenedor de esa imagen lo recibe, sin pedirlo
curso-docker-token-de-mentira-en-env

== 6. docker build --check lo habría dicho antes de construir
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile.malo
#1 transferring dockerfile: 892B done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 0.2s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 resolve docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e 0.1s done
#3 CACHED

#4 [internal] load metadata for docker.io/library/golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
#4 DONE 0.0s

#5 [internal] load .dockerignore
#5 transferring context: 155B done
#5 DONE 0.0s
Check complete, 2 warnings have been found!

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
Dockerfile.malo:11
--------------------
   9 |     # Mal 1: un secreto de construcción por ARG. Queda en el historial de la imagen,
  10 |     # aunque el RUN borre el archivo al final.
  11 | >>> ARG TOKEN_MODULOS
  12 |     RUN echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc \
  13 |      && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor \
--------------------

WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "REVISOR_TOKEN")
Dockerfile.malo:16
--------------------
  14 |      && rm /root/.netrc
  15 |     # Mal 2: el token de ejecución en ENV. Queda en la configuración de la imagen.
  16 | >>> ENV REVISOR_TOKEN=curso-docker-token-de-mentira-en-env
  17 |     USER 10001:10001
  18 |     CMD ["revisor"]
--------------------
[código de salida: 1]

== 7. Un ARG se anota en CADA RUN que viene después, aunque no lo use
RUN |2 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be VERSION=1.3.0 /bin/sh -c echo "paso 2: tampoco" # buildkit
ARG VERSION=1.3.0
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "paso 1: no uso ningún argumento" # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

#### 6.4.3 Ler o que foi encontrado

1. **O arquivo já não está lá.** Dentro da imagem, `/root` tem os arquivos de sempre da base e os caches que `go build` deixou (`.cache`, `.config`), mas não `.netrc`. O script usa `--user 0` só para poder olhar `/root`, que não é legível para o usuário `10001` da imagem. Parando aqui, seria possível dizer que a receita funcionou.
2. **O histórico o tem, duas vezes.** Uma linha é a própria instrução, `ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`, com o valor que recebeu. A outra é o `RUN`, que começa com `|1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`. Esse `|1` é uma **contagem**: «neste passo havia 1 argumento de build»; em seguida vêm todos, com seu valor. Apagar o arquivo não apagou o valor, porque o valor nunca esteve só no arquivo. É o mesmo mecanismo que em 6.2.3 deixou `ARG VERSION=1.3.0` à vista; a diferença é só o que foi colocado no argumento.
3. **A configuração tem o token de execução**, igual à cena do começo: `REVISOR_TOKEN=curso-docker-token-de-mentira-en-env`.
4. **E cada contêiner o recebe.** `printenv` o imprime de dentro sem que ninguém o tenha passado ao rodar: ele vem da imagem.
5. **`docker build --check` tinha avisado**, sem construir nada. Ele revisa o Dockerfile com as regras do BuildKit e, para cada achado, diz o nome da regra (`SecretsUsedInArgOrEnv`), um link para sua explicação, que instrução a disparou (`ARG "TOKEN_MODULOS"`, `ENV "REVISOR_TOKEN"`), o arquivo e a linha, e o trecho do Dockerfile com uma seta `>>>`. Sai com código 1 quando encontra algo, então serve para interromper um processo automatizado. A regra olha o **nome** da variável: a documentação diz que ela aponta as chaves que «indicam que contêm dados sensíveis», sem dar a lista ([Docker, regra `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/)); aqui `TOKEN` a disparou, e no Exercício 4 vai aparecer um nome em espanhol que passa sem advertência. Por isso é uma rede de segurança e não uma garantia. Para que um `docker build` normal (não só o `--check`) pare diante de qualquer advertência, a diretiva `# check=error=true`, na linha seguinte ao `# syntax=`, faz isso ([Docker, «Build checks»](https://docs.docker.com/build/checks/)). As linhas que começam com `#0`… `#5` são o trabalho prévio do BuildKit para poder ler o Dockerfile; podem ser ignoradas.
6. **Um `ARG` contamina cada `RUN` que vem depois.** O último bloco usa uma receita de dois estágios, escrita dentro do próprio script, em que **nenhum** `RUN` menciona os argumentos. Mesmo assim, o `RUN` do estágio `base` leva `|1 TOKEN_MODULOS=…`, e o do estágio `hija`, que saiu de `base` e declarou também `VERSION`, leva `|2 TOKEN_MODULOS=… VERSION=1.3.0`. O BuildKit anota em cada `RUN` todos os argumentos declarados em seu estágio e no estágio de que ele sai, sejam usados ou não. Um token em um `ARG` não deixa um rastro: deixa um para cada `RUN` posterior.

O importante deste experimento é a forma de procurar, porque é a que vai ser usada nas próprias imagens:

```bash
docker history --no-trunc --format '{{.CreatedBy}}' <imagen>
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>
```

Dois comandos, nenhuma permissão especial, nenhuma ferramenta extra. Qualquer um que possa baixar a imagem pode rodá-los. E se um segredo já chegou a uma imagem publicada, não há comando que conserte: o segredo é dado como perdido e **trocado** no serviço que o emitiu. Apagar a imagem do registry não a despublica das máquinas e caches que já a baixaram.

### 6.5 O segredo de execução: arquivo, não variável

#### 6.5.1 Por que não uma variável de ambiente, mesmo que chegue ao rodar

Tirar o token do Dockerfile e passá-lo com `-e REVISOR_TOKEN=...` ao rodar é melhor do que deixá-lo na imagem: ele já não viaja para o registry. Mas não basta, por dois motivos que a documentação do Compose resume assim: as variáveis de ambiente «costumam estar disponíveis para todos os processos, e pode ser difícil rastrear o acesso», e «também podem ser impressas nos logs ao depurar erros sem que se saiba» ([Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/)). A isso soma-se algo próprio do Docker: a configuração do **contêiner** guarda seu ambiente completo, e qualquer um que possa usar `docker inspect` nessa máquina o lê. E desde a Lição 1 se sabe quem pode usar `docker`: o grupo `docker`, que equivale a `root`. Há mais um rastro, que não tem a ver com o Docker: escrevendo o valor literal no terminal (`-e REVISOR_TOKEN=abc…`, e o mesmo vale para `--build-arg`), ele fica no histórico do *shell* e, enquanto o comando roda, na lista de processos da máquina. Os scripts desta lição nunca escrevem um valor à mão: eles o leem do arquivo com `$(cat secretos/…)`, e isso evita o primeiro problema, o de o valor ficar no histórico do *shell*. **Não evita o segundo.** O *shell* substitui o `$(cat …)` antes de lançar o `docker`, de modo que o valor chega ao `docker` como mais um argumento, e enquanto o comando roda qualquer um que consiga listar processos (`ps`, ou ler `/proc/<pid>/cmdline`) o vê igual a como se tivesse sido digitado. Aqui isso não importa, porque os tokens da lição são inventados. Com um segredo de verdade, a saída é não passá-lo como argumento: entregá-lo como arquivo montado, como faz o resto desta lição, ou, ao construir, com `--secret` (6.6).

O `revisor` aceita as duas formas, mas não as trata igual. `REVISOR_TOKEN` funciona e imprime um aviso. `REVISOR_TOKEN_ARCHIVO` recebe o **caminho** de um arquivo e lê o token dali; se as duas existirem, vence o arquivo. A convenção do caminho é `/run/secrets/<nombre>`: é onde o Compose coloca seus segredos e onde o BuildKit coloca por padrão os de build, como aparece em 6.6.

#### 6.5.2 As duas formas, e o erro que aparece primeiro

O script `fig06_06.sh` testa as duas formas, e no meio provoca o erro mais comum da forma certa. Ele usa o arquivo falso `secretos/revisor_token.txt`, que contém `curso-docker-token-de-mentira-7f3a9c`:

```bash
#!/usr/bin/env bash
# fig06_06.sh — El secreto de EJECUCIÓN: por variable de entorno (se ve) y por
# archivo (no se ve), con el error de permisos que vas a encontrar primero.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig06"
NOMBRE="${PREFIJO}revisor-fig06"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.3.0 -t "$IMAGEN" . >/dev/null
SERVICIOS='propio http://127.0.0.1:8080/salud'

esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}

echo "== 1. El token por -e: funciona, pero queda a la vista"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  -e REVISOR_TOKEN="$(cat secretos/revisor_token.txt)" "$IMAGEN" >/dev/null
sleep 1
echo "-- lo que dice el revisor al arrancar:"
docker logs "$NOMBRE" 2>&1
echo "-- lo que ve cualquiera con docker inspect:"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep TOKEN
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El token por archivo, con permisos 600"
chmod 600 secretos/revisor_token.txt
stat -c '%a %n' secretos/revisor_token.txt
rc=0
timeout 20 docker run --name "$NOMBRE" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" || rc=$?
echo "[código de salida: $rc]"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El token por archivo, con permisos 644 y montado de solo lectura"
chmod 644 secretos/revisor_token.txt   # 644: solo porque el token es de mentira (6.5.4)
stat -c '%a %n' secretos/revisor_token.txt
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --mount type=bind,src="$PWD/secretos/revisor_token.txt",dst=/run/secrets/revisor_token,readonly \
  -e REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token -e REVISOR_SERVICIOS="$SERVICIOS" \
  "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
echo "-- /salud no pide token:"
curl -s "http://127.0.0.1:$PUERTO/salud"; echo
echo "-- /api/estados sin token:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- /api/estados con el token:"
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" \
  "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'

echo
echo "== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto"
docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$NOMBRE" | grep REVISOR
docker inspect --format '{{range .Mounts}}{{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
```

```text
$ ./fig06_06.sh
== 1. El token por -e: funciona, pero queda a la vista
-- lo que dice el revisor al arrancar:
revisor: aviso: el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer; usa REVISOR_TOKEN_ARCHIVO
revisor 1.3.0 escuchando en :8080 (1 servicio(s))
-- lo que ve cualquiera con docker inspect:
REVISOR_TOKEN=curso-docker-token-de-mentira-7f3a9c

== 2. El token por archivo, con permisos 600
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]

== 3. El token por archivo, con permisos 644 y montado de solo lectura
644 secretos/revisor_token.txt
-- /salud no pide token:
{"estado":"vivo","version":"1.3.0"}

-- /api/estados sin token:
{"error":"falta el token o no es válido"}
 [401]
-- /api/estados con el token:
SERVICIO  ESTADO    TIEMPO  DETALLE
propio    OK           <t>  200

== 4. Lo que ve docker inspect ahora: la RUTA del secreto, no el secreto
REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_PUERTO=8080
/run/secrets/revisor_token (escribible: false)
```

#### 6.5.3 Ler a execução

1. **Por variável, funciona e fica visível.** O `revisor` inicia, mas a primeira coisa que escreve em seu log é um aviso: `el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer`. E `docker inspect` confirma, com o token completo. Não foi preciso entrar no contêiner nem ter a imagem: bastou poder falar com o daemon. (A versão `1.3.0` na mensagem de inicialização é a gravada em 6.2.)
2. **Por arquivo, com `600`, não inicia.** Este é o erro da lição. O arquivo na máquina pertence ao nosso usuário e tem permissões `600`: só seu dono o lê. Ao montá-lo, o contêiner vê **o mesmo arquivo**, com o mesmo dono (um número de usuário) e as mesmas permissões; uma montagem não copia nem traduz nada. E dentro do contêiner o `revisor` roda como o usuário `65532`, que não é o dono. O kernel faz o que faria com qualquer outro usuário da máquina: `permission denied`. É a consequência direta de algo visto na Lição 0: na instalação normal da Lição 1, os números de usuário de dentro e de fora são os mesmos. (Com Docker sem `root` ou com remapeamento de usuários, o número de dentro é traduzido para outro fora, e o diagnóstico com `ls -ln` muda.) Repare também que o `revisor` **não inicia pela metade**: se lhe foi dito que há um arquivo de token e ele não consegue lê-lo, prefere morrer com código 1 a ficar escutando sem proteção.
3. **Com `644`, funciona.** `644` dá leitura a qualquer um; agora o usuário `65532` consegue lê-lo. E não só ele: **qualquer outra conta da máquina** também (6.5.4). Aqui é um token de mentira. `/salud` responde sem token (é para que o health check possa ser monitorado, Lição 7), e `/api/estados` responde `401` sem token e a tabela com ele. A saída traz uma linha em branco depois do JSON de `/salud`: é o `echo` do script, que acrescenta uma quebra de linha à que o `revisor` já mandou. E a ordem das variáveis no `docker inspect` do bloco 4 pode variar de uma execução para outra; o que importa é quais estão lá.
4. **`docker inspect` já não mostra o segredo.** Mostra `REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token`, um caminho, que não serve para nada sem o arquivo. E a montagem aparece como `escribible: false`: a opção `readonly` impede que o contêiner modifique o arquivo da máquina, mesmo que tivesse permissão.

#### 6.5.4 Um `644` não é perigoso?

Sim, e a resposta curta é: **com um segredo de verdade, nunca**. `644` significa que **qualquer outra conta da máquina** pode ler o arquivo: a de outra pessoa em um servidor compartilhado, a de um serviço que roda com seu próprio usuário, a de um programa que alguém fez rodar como outro usuário. A Lição 9 demonstra isso com uma conta sem privilégios (`sudo -u nobody cat`, seção 9.8.3): com `644`, imprime o token completo. O curso usa `644` nesta lição porque o token é de mentira (`curso-docker-token-de-mentira-7f3a9c` não abre nada) e a prática é no computador de quem estuda; é a forma mais curta de ver que o `revisor` inicia. Não a copie para um projeto real.

As boas correções atacam a mesma causa (a quem o arquivo pertence, não só o quão aberto ele está), e se verificam com `ls -l` ou com `stat -c '%a %U:%G' secretos/revisor_token.txt`:

- **O grupo do arquivo ser o do contêiner**: `sudo chgrp +65532 secretos/revisor_token.txt` e `chmod 640 secretos/revisor_token.txt` (o `+` indica que `65532` é um número de grupo). Continuamos sendo o dono (lemos e editamos sem `sudo`), o `revisor` o lê porque roda como `65532:65532`, e mais ninguém, exceto `root` e quem controla o Docker (9.8.3). Escolha esta **ou** a seguinte, não as duas.
- **O arquivo ser do usuário do contêiner**: `chmod 600 secretos/revisor_token.txt` e **depois** `sudo chown 65532:65532 secretos/revisor_token.txt`, nessa ordem: quando o dono já é `65532`, o `chmod` falha com `Operation not permitted` e o arquivo fica aberto. Assim só esse usuário e `root` o leem. O preço é que o nosso usuário já não consegue lê-lo sem `sudo`.
- **Um orquestrador entregá-lo, com uma ressalva importante.** Os segredos do Compose (Lição 9) colocam o arquivo em `/run/secrets/`, mas quando o segredo vem de um **arquivo**, o Compose o monta como está, igual ao `--mount` desta lição: o dono e as permissões continuam sendo os do arquivo da máquina. Sua referência diz isso: com um arquivo como fonte, o Compose usa por baixo uma montagem que não permite mudar o dono, e os atributos `uid`, `gid` e `mode` «são ignorados em silêncio»; só funcionam quando o segredo vem de uma variável de ambiente ([referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/)). Medimos isso com o Compose v5.0.2: o arquivo em `600`, com `uid: "65532"`, `gid: "65532"` e `mode: 0400` declarados no `compose.yaml`, deu exatamente o mesmo `permission denied` de 6.5.2,. Por isso a Lição 9 mede os quatro casos (`644`, `600` do nosso usuário, `600` de `65532` e `640` com grupo `65532`) e deixa o arquivo no último. O Kubernetes monta seus segredos com as permissões declaradas, mas isso é matéria do curso de Kubernetes.

E o segredo não deve chegar ao repositório: `secretos/` vai no `.gitignore` do projeto, igual ao `.dockerignore`. Este curso leva seu `secretos/` no repositório, de propósito, porque o token é de mentira.

O que **não** é uma correção: mudar o `USER` da imagem para `root` «para conseguir ler». Isso troca um problema de permissões por um de segurança, e desfaz o trabalho das lições 3 e 5.

### 6.6 O segredo de build: uma montagem que dura um `RUN`

#### 6.6.1 Quando é necessário

Às vezes o segredo não é para rodar, e sim para **construir**: credenciais para baixar módulos privados de Go, pacotes de um repositório privado de npm ou de Maven, um certificado para entrar em um servidor interno de dependências. O `revisor` não tem dependências externas, então hoje não precisa disso, mas o padrão fica em seu Dockerfile para o dia em que precisar.

O BuildKit traz uma ferramenta feita para isso: a **montagem de segredo**. No Dockerfile, um `RUN` pede o segredo com `--mount=type=secret,id=<nombre>`; ao construir, ele é entregue com `docker build --secret id=<nombre>,src=<archivo>` (ou `env=<VARIABLE>`, se estiver em uma variável do terminal). Segundo a documentação, a montagem deixa o segredo disponível «temporariamente dentro do contêiner de build, durante a instrução» ([Docker, «Build secrets»](https://docs.docker.com/build/building/secrets/)). As opções que o `revisor` usa, com seus valores padrão segundo a [referência do Dockerfile](https://docs.docker.com/reference/dockerfile/):

| Opção | O que faz | Padrão |
|---|---|---|
| `id` | o nome com que `--secret` o entrega | o nome do arquivo de `target` |
| `target` | onde o arquivo aparece durante o `RUN` | `/run/secrets/<id>` |
| `required` | se for `true`, a instrução falha quando o segredo não é entregue | `false` |
| `mode` | permissões do arquivo | `0400` |
| `uid`, `gid` | dono do arquivo | `0` (`root`) |
| `env` | em vez de um arquivo (ou além dele), coloca o segredo em uma variável de ambiente que existe **só durante esse `RUN`** | sem valor: só arquivo |

**Cuidado com o usuário durante o build.** A montagem entrega o arquivo com dono `0` (`root`) e permissões `0400` por padrão. Se o estágio de compilação já mudou para um usuário sem privilégios com `USER`, esse usuário não conseguirá ler o segredo e o `RUN` falhará com `permission denied`: é a mesma armadilha de permissões de 6.5. Resolve-se indicando o dono na montagem (`uid=` e `gid=`) ou relaxando o modo (`mode=0444`, lembrando que o segredo só existe durante esse `RUN`). No Dockerfile desta lição não é necessário, porque o estágio que o usa roda como `root`.

Atenção aos dois `env`. Em `docker build --secret id=x,env=MI_VAR`, `env` diz **de que variável do terminal** o segredo é lido. Em `--mount=type=secret,id=x,env=TOKEN`, diz **com que nome o `RUN` o vê**. Essa segunda variável não é um `ENV`: nasce e morre com a instrução, e não fica nem na imagem nem no histórico. É a forma que a própria documentação usa no exemplo correto da regra `SecretsUsedInArgOrEnv`, e a que convém quando a ferramenta lê sua credencial de uma variável e não de um arquivo. «Variável de ambiente» não é ruim por si só; o ruim é ficar escrita onde a imagem viaja ou onde qualquer um a lê.

O `revisor` usa `target=/root/.netrc` porque é ali que o Go procura suas credenciais, e `required=false` porque este curso não tem módulos privados: assim seu build funciona com e sem `--secret`.

#### 6.6.2 Vê-lo aparecer e desaparecer

Para ver a montagem em ação, é preciso um `RUN` que faça algo visível com o segredo. Este Dockerfile de demonstração o recebe, conta seus bytes e lista o arquivo, **sem imprimir o valor**. Usa `required=true` para mostrar o erro de esquecê-lo:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_07.Dockerfile — Lección 6: dónde vive un secreto de construcción.
# Solo para mirar: un RUN que recibe el secreto, lo cuenta y no lo imprime.
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
RUN --mount=type=secret,id=netrc,target=/root/.netrc,required=true \
    echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes" \
 && ls -l /root/.netrc
```

O script `fig06_08.sh` o constrói duas vezes (sem e com o segredo), olha o que ficou e termina construindo o `revisor` real com `--secret`:

```bash
#!/usr/bin/env bash
# fig06_08.sh — El secreto de CONSTRUCCIÓN con --secret: está durante el RUN y
# en ningún otro lado. Primero el error de olvidarlo; después, el revisor real.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig06»: el guion nunca toca tu curso-docker-revisor:1.3.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
DEMO="${PREFIJO}revisor:fig06-demo-secreto"
IMAGEN="${PREFIJO}revisor:fig06"
trap 'docker rmi -f "$DEMO" "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig06_01.Dockerfile" "$TRABAJO/Dockerfile"
cp "$AQUI/fig06_07.Dockerfile" "$TRABAJO/Dockerfile.demo"
cp -R "$AQUI/estado/secretos" "$TRABAJO/secretos"
cd "$TRABAJO"

echo "== 1. Olvidar --secret cuando el Dockerfile dice required=true"
rc=0
docker build --no-cache --progress=plain -f Dockerfile.demo -t "$DEMO" . > salida-1.txt 2>&1 || rc=$?
grep -E '^ERROR' salida-1.txt
echo "[código de salida: $rc]"

echo
echo "== 2. Con --secret: el RUN lo recibe"
docker build --no-cache --progress=plain --secret id=netrc,src=secretos/token_modulos.txt \
  -f Dockerfile.demo -t "$DEMO" . 2>&1 | grep -E 'durante el RUN|/root/.netrc$' | grep -v '^#[0-9]* \[' 

echo
echo "== 3. Terminado el RUN, ¿qué quedó en /root?"
docker run --rm --name "${PREFIJO}revisor-fig06-mira" "$DEMO" ls -lA /root

echo
echo "== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | head -1
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$DEMO" | grep -c 'modulos-de-mentira' || true

echo
echo "== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)"
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt \
  -t "$IMAGEN" . >/dev/null && echo "construida"
echo "-- renglones del historial con el valor del secreto:"
docker history --no-trunc --format '{{.CreatedBy}}' "$IMAGEN" | grep -c 'modulos-de-mentira' || true
```

```text
$ ./fig06_08.sh
== 1. Olvidar --secret cuando el Dockerfile dice required=true
ERROR: failed to build: failed to solve: secret netrc: not found
[código de salida: 1]

== 2. Con --secret: el RUN lo recibe
#7 0.092 durante el RUN: /root/.netrc existe y mide 37 bytes
#7 0.093 -r-------- 1 root root 37 Oct 21 09:17 /root/.netrc

== 3. Terminado el RUN, ¿qué quedó en /root?
total 8
-rw-r--r-- 1 root root 607 Jul 17 17:05 .bashrc
-rw-r--r-- 1 root root 132 Jul 17 17:05 .profile

== 4. ¿Y en el historial? Ni el valor ni el archivo: solo la instrucción
RUN /bin/sh -c echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes"  && ls -l /root/.netrc # buildkit
-- renglones del historial con el valor del secreto:
0

== 5. El revisor real, construido con el secreto (opcional en su Dockerfile)
construida
-- renglones del historial con el valor del secreto:
0
```

As opções novas do script: `--no-cache` obriga a rodar o `RUN` mesmo havendo cache, para que ele imprima algo; `--progress=plain` mostra a saída de cada passo como texto puro, em vez da visão que se redesenha no terminal. Cada linha dessa saída começa com o número do passo (`#7`) e os segundos desde que ele começou; esses números e a data do arquivo mudam a cada execução (a data está na hora da máquina virtual, que é a do meridiano de Greenwich). Os `|| true` do final estão ali porque `grep -c` sai com código 1 quando conta zero, e aqui o zero é justamente o que se quer ver.

E a saída:

1. **Esquecer o segredo** com `required=true` interrompe o build com uma mensagem curta: `secret netrc: not found`. É o que se quer quando o segredo é indispensável: um erro claro ao construir, e não uma compilação que falha três passos depois com um «não autorizado» que ninguém entende. O `revisor` usa `required=false` porque para ele o segredo é opcional.
2. **Com `--secret`, o `RUN` o vê**: um arquivo de 37 bytes (36 caracteres do valor falso mais a quebra de linha), com permissões `-r--------` (o `0400` padrão) e dono `root`, o usuário com que esse `RUN` roda.
3. **Terminado o `RUN`, ele já não está lá.** `/root` só tem os arquivos da base. Diferentemente do `rm` de 6.4, aqui ninguém precisou apagar nada: o arquivo nunca foi escrito na camada; esteve montado por cima, como um empréstimo, e foi devolvido ao terminar a instrução.
4. **O histórico anota a instrução e nada mais.** Nem o valor, nem sequer as opções `--mount`. A contagem de linhas com o valor do segredo é `0`.
5. **O `revisor` real**, construído com seu segredo opcional: também `0`.

Coloque esta saída ao lado da de 6.4. Com `ARG`, o valor ficou escrito embora o arquivo tenha sido apagado. Com `--secret`, o valor nunca chegou a ser escrito.

#### 6.6.3 Os cinco caminhos, juntos

Cada mecanismo já apareceu funcionando separadamente. Este quadro os junta, porque a pergunta a fazer no próprio projeto é sempre a mesma: por onde esta informação entra, e onde fica escrita?

| Mecanismo | Quando existe | Como é entregue | Onde fica escrito | Serve para segredos? |
|---|---|---|---|---|
| `ARG` | só ao construir | `docker build --build-arg` | no histórico, em sua própria linha e em cada `RUN` posterior do estágio (6.4); na procedência em modo `max` (6.7) | não |
| `ENV` | ao construir e em cada contêiner | o Dockerfile; é mudado com `-e` | na configuração da imagem (`docker image inspect`) | não |
| `-e` / `--env-file` | ao rodar | `docker run` | na configuração do contêiner (`docker inspect`) | não |
| `--mount=type=secret` | só durante um `RUN` | `docker build --secret` | em lugar nenhum (6.6.2) | sim, de build |
| arquivo em `/run/secrets/` | ao rodar | montagem somente leitura | `docker inspect` mostra o caminho, não o valor (6.5) | sim, de execução |

As três primeiras linhas são para configuração; as duas últimas, para segredos. Se uma informação sensível está em qualquer uma das três primeiras, ela já está escrita em algum lugar que outra pessoa pode ler.

#### 6.6.4 Por que ele não escapa pelo cache

Uma dúvida razoável: se o segredo muda, o cache do BuildKit roda o `RUN` de novo? Não. A documentação diz assim: «o conteúdo dos segredos de build não faz parte do cache», e «mudar o valor de um segredo não invalida o cache»; o que conta são suas propriedades, como o `id` e o caminho da montagem ([Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/)). A documentação não explica o porquê; o prático é saber que o valor não conta para o cache, e que o `id` e o caminho da montagem contam. Se o segredo mudar e for preciso que o `RUN` se repita, a documentação propõe passar também um argumento de build qualquer que mude ao mesmo tempo (os argumentos invalidam o cache), ou dá para forçar com `--no-cache`, como o script fez. É um pequeno incômodo em troca de o valor não aparecer em nenhum log do build.

### 6.7 O que aparece em tutoriais antigos

- **`ARG` para tokens do npm, do GitHub ou de um registry privado**, com o comentário «não se preocupe, apagamos no final do `RUN`». Em 6.4 viu-se que o valor fica no histórico. As montagens de segredo existem desde que o BuildKit as trouxe, e são o caminho documentado.
- **Construir em vários estágios «para que o `ARG` não chegue à imagem final».** É verdade que o histórico da imagem entregue só mostra o estágio final (isso apareceu em 6.2.3), mas os valores também podem ficar nas **atestações de procedência**, o registro de como a imagem foi construída que a Lição 10 anexa a ela. No modo mínimo, o usado por padrão, os valores dos argumentos não são incluídos; com `--provenance=mode=max`, o que a Lição 10 usa, a documentação adverte que esse modo «expõe os valores dos argumentos de build», de todos os estágios ([Docker, procedência SLSA](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). Ajuda, mas não é a solução.
- **`docker run -e PASSWORD=...` nas instruções de uma imagem.** Muitas imagens populares aceitam segredos por variável porque é o mais fácil de documentar, e muitas oferecem também uma variante `_FILE` que lê de um arquivo, como o `REVISOR_TOKEN_ARCHIVO` do `revisor`. Quando existir a variante com arquivo, use-a.
- **«Achatar» as camadas para que os segredos desapareçam.** Alguns guias antigos propõem juntar todas as camadas em uma. Mesmo que isso tirasse um arquivo de uma camada intermediária, não toca na configuração da imagem: um `ENV` com um token continua ali, como se viu em 6.4. O caminho atual é o segredo nunca entrar.

## O erro que se vai ver

Esta lição tem um erro principal e dois secundários. Os três já apareceram.

**O erro principal: o arquivo do segredo que o contêiner não consegue ler.** É o de `fig06_06.sh`:

```text
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]
```

Lê-se da direita para a esquerda. `permission denied` é dito pelo kernel: o processo não tem permissão para abrir esse arquivo. `open /run/secrets/revisor_token` diz que arquivo, com o caminho **dentro** do contêiner; o caminho na máquina é o da montagem. E `leyendo el token de REVISOR_TOKEN_ARCHIVO` é acrescentado pelo `revisor` para que se saiba o que ele estava fazendo. A pergunta que resolve é «quem é o dono do arquivo, e com que usuário o contêiner roda?». A primeira resposta é dada por `ls -ln` na máquina; a segunda, por `docker inspect --format '{{.Config.User}}'` sobre a imagem (`65532:65532`). Se não coincidirem e as permissões forem `600`, este é o resultado. Correções: o grupo ou o dono correto, que deixam o `revisor` ler e mais ninguém (6.5.4); `644` também funciona, mas só vale com um token de mentira. O que não é uma correção: rodar como `root`.

**O erro secundário: o segredo de build que não chegou.**

```text
ERROR: failed to build: failed to solve: secret netrc: not found
```

Aparece quando o Dockerfile pede um segredo com `required=true` e o `docker build` não traz `--secret id=netrc,...`. A correção é acrescentá-lo. Se `--secret` foi escrito, mas com outro `id` (por exemplo, `id=nettrc`), é o mesmo caso: o `RUN` pediu o segredo `netrc` e ninguém o entregou, então confira se os dois `id` coincidem letra por letra. Com `required=false`, como no `revisor`, não há erro: o `RUN` roda sem o arquivo.

**A advertência que precisa ser tratada como erro: `SecretsUsedInArgOrEnv`.**

```text
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
```

É uma advertência, não um erro: um `docker build` normal a imprime e constrói mesmo assim. Por isso é fácil ignorá-la. Com `docker build --check` o resultado é código 1, e é assim que convém rodá-la: antes de cada build que vá ser publicado. Lembre-se de que ela só olha os nomes: a ausência de uma advertência não prova que não haja segredos.

## O hábito de segurança da lição

**Os segredos não passam por `ARG` nem por `ENV`, e comprova-se com `docker history` e `docker inspect` que eles não ficaram.** O hábito tem duas metades, e a segunda é a que se esquece. A primeira é a regra: o segredo de build entra com `--secret`, o de execução como arquivo somente leitura em `/run/secrets/`. A segunda é a verificação: antes de publicar uma imagem, procura-se em seu histórico completo e em sua configuração, com os dois comandos de 6.4.3, e não se encontra nada. Este hábito evita o acidente da cena do começo (um token publicado em um registry a que mais pessoas têm acesso do que se imagina) e outro mais silencioso: um token passado por `-e` que acaba em um log de erros, na tela compartilhada de uma videochamada ou na saída de `docker inspect` que alguém colou em um chat para pedir ajuda.

## O que se faz errado

**Reconstruir a imagem para mudar de ambiente.** Se a imagem de produção é diferente da de testes, a de produção ninguém testou. Uma imagem, muitas configurações.

**Colocar a configuração de um ambiente no `ENV` do Dockerfile.** `ENV` é para valores padrão que servem em qualquer lugar, como a porta. Uma lista de serviços de testes no `ENV` obriga a reconstruir para produção, e fica na imagem para sempre.

**Passar um segredo por `ARG` e apagá-lo «no mesmo `RUN`».** O arquivo desaparece; o valor fica no histórico (6.4). A prudência de fazer isso em um único `RUN` protege contra um erro diferente do que de fato acontece.

**Passar o token por `-e` porque «ele já não está na imagem».** Já não viaja para o registry, mas continua na configuração do contêiner, à vista de qualquer um com acesso a `docker`, e no ambiente de todos os processos filhos.

**Corrigir `permission denied` com `--user root` ou `chmod 777`.** O primeiro desfaz o hardening da imagem; o segundo deixa o arquivo gravável para a máquina inteira. O problema é o dono; corrija ali.

**Guardar a pasta de segredos no repositório.** Este curso faz isso de propósito e com valores falsos. Um projeto real, não: `secretos/` vai no `.gitignore` e no `.dockerignore` desde o primeiro dia.

**Confiar que `docker build --check` não disse nada.** Ele revisa nomes, não valores. Uma variável `X` com um token dentro passa limpa.

**Copiar o segredo montado para outro caminho.** A montagem não deixa rastro, mas o que o `RUN` escrever, sim: se um `cp /run/secrets/…` ou uma ferramenta salvar a credencial em sua própria configuração (um `.npmrc`, um arquivo de credenciais), essa cópia fica na camada como qualquer outro arquivo. O segredo é lido no `RUN` e não é escrito em lugar nenhum.

**Imprimir um segredo «só para depurar».** Um `RUN cat /run/secrets/...` ou um `echo $TOKEN` deixa o valor na saída do build ou nos logs do contêiner, que são guardados e compartilhados. Para saber se um segredo chegou, conte seus bytes, como fez `fig06_07.Dockerfile`.

## Exercícios

Faça-os em ordem. Antes de rodar cada um, escreva no [diário de bordo](bitacora.md) o que se espera que aconteça; comparar depois é metade do aprendizado. Ao terminar, apague o que foi criado: tudo leva o prefixo `curso-docker-`.

### Exercício 1 — Código, configuração ou segredo?

Classifique cada informação em uma das três caixas de 6.1.1 e diga onde ela deve viver (dentro da imagem, em `ENV` como valor padrão, por `-e`/`--env-file`, ou como arquivo em `/run/secrets/`):

1. A versão `1.3.0` do `revisor`.
2. A lista de serviços que o ambiente de testes verifica.
3. O token que protege `/api/estados` em produção.
4. A porta `8080`.
5. O caminho onde o `revisor` guarda seu relatório (`REVISOR_REPORTE`).
6. Uma credencial para baixar módulos privados de Go ao compilar.

### Exercício 2 — Sem `--build-arg` (projeto)

Na pasta `~/curso-docker/revisor`, com o Dockerfile desta lição, construa uma imagem **sem** `--build-arg` e com a tag `curso-docker-revisor:sin-version`. Antes de construir, preveja o que estas três coisas vão dizer, e depois confira:

1. `docker run --rm curso-docker-revisor:sin-version version`
2. O rótulo `org.opencontainers.image.version` da imagem.
3. A linha `ARG` de seu `docker history`.

O exercício se autocorrige: se as três previsões coincidirem com o que aparece, ficou claro de onde vem o valor de um `ARG`. No final, `docker rmi curso-docker-revisor:sin-version`.

### Exercício 3 — As aspas do arquivo de variáveis

Crie um arquivo `comillas.env` com esta única linha, aspas incluídas:

```text
REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"
```

Antes de rodar, preveja: o `revisor` inicia ou se recusa? Se iniciar, o que sua tabela vai dizer? Depois rode com `docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --env-file comillas.env curso-docker-revisor:1.3.0`, peça a tabela com `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` e leia com `docker inspect` que valor exatamente ele recebeu. Corrija o arquivo para que o serviço saia `OK`. No final, `docker rm -f curso-docker-revisor`.

### Exercício 4 — Encontrar o vazamento

Um colega passa esta receita e jura que «não deixa nada porque o segredo é apagado». Sem construí-la, diga **onde** ficaria cada um dos dois valores sensíveis e com que comando ele seria encontrado. Depois reescreva a parte do segredo de build com uma montagem de segredo, e diga que opção de `docker build` o entrega:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
ARG CLAVE_REGISTRO
ENV API_KEY=valor-de-mentira-para-el-ejercicio
RUN echo "${CLAVE_REGISTRO}" > /tmp/clave && go env -w GOPRIVATE=ejemplo.invalid && rm /tmp/clave
```

Pergunta extra: qual das duas variáveis `docker build --check` teria apontado, e qual não? Pense em como a regra decide.

## Soluções

### Solução 1

1. **Código.** Dentro da imagem: gravada no binário com `-X main.version` e no rótulo OCI. Não muda entre ambientes.
2. **Configuração.** Por `-e` ou `--env-file` ao rodar. Muda entre ambientes e não é secreta.
3. **Segredo.** Como arquivo somente leitura em `/run/secrets/revisor_token`, com `REVISOR_TOKEN_ARCHIVO` apontando para ele. Nunca em `ENV` nem por `-e`.
4. **Configuração com valor padrão.** `ENV REVISOR_PUERTO=8080` na imagem; qualquer ambiente a muda com `-e`.
5. **Configuração.** Por `-e` ou `--env-file`. (A Lição 8 lhe dá um valor padrão dentro da imagem, quando existir uma pasta `/datos` preparada para isso.)
6. **Segredo de build.** Com `--mount=type=secret` no `RUN` que precisa dele, entregue com `docker build --secret`. Nunca em `ARG`.

### Solução 2

Medido com a mesma máquina e a mesma versão do Docker da lição:

1. `desarrollo`. Sem `--build-arg`, `VERSION` assume o valor padrão de sua declaração, `ARG VERSION=desarrollo`, e é isso que `-X main.version` grava no binário.
2. `desarrollo` também, porque o estágio `final` declara seu próprio `ARG VERSION=desarrollo` e o rótulo o usa.
3. `ARG VERSION=desarrollo`. O histórico anota o valor que o argumento teve **naquele build**, seja o de `--build-arg` ou o da declaração. É exatamente por isso que um segredo não pode ir ali.

### Solução 3

Medido com a mesma máquina e a mesma versão do Docker da lição. O `revisor` **inicia** (`revisor 1.3.0 escuchando en :8080 (1 servicio(s))`), mas a tabela diz:

```text
SERVICIO  ESTADO    TIEMPO  DETALLE
"propio   FALLA        1ms  codigo 404
```

O tempo muda a cada execução. As aspas chegaram como parte do valor: `docker inspect` mostra `REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"`. O `revisor` leu um serviço chamado `"propio` (com a aspa) e cujo endereço é `http://127.0.0.1:8080/salud"` (com a aspa no final); esse caminho não existe e o servidor responde `404`. É o pior tipo de erro de configuração: não impede de iniciar, só dá um resultado errado. A correção é tirar as aspas: em um arquivo de `--env-file`, tudo o que vem depois do `=` é o valor, tal como está. (No terminal as aspas vão, sim, porque ali quem as interpreta é o *shell* e elas não chegam ao contêiner. E no `env_file` do Compose, Lição 9, também podem ser usadas, porque esse leitor as remove.)

### Solução 4

- `CLAVE_REGISTRO` fica **no histórico**, na linha do `RUN`, na forma `|1 CLAVE_REGISTRO=<valor> /bin/sh -c ...`. É encontrada com `docker history --no-trunc --format '{{.CreatedBy}}' <imagen>`. O `rm /tmp/clave` não evita isso, igual a 6.4.
- `API_KEY` fica **na configuração da imagem** e no ambiente de cada contêiner. É encontrada com `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>`.

A reescrita do segredo de build:

```dockerfile
RUN --mount=type=secret,id=clave_registro,target=/root/.netrc,required=true \
    go env -w GOPRIVATE=ejemplo.invalid && go mod download
```

Aqui o segredo é **usado**: `go mod download` baixa os módulos privados e, para entrar no servidor, lê a credencial de `/root/.netrc`, que só existe durante este `RUN` (o arquivo de segredo teria a linha `machine ejemplo.invalid password …`, como em 6.4). Se a ferramenta necessária lê sua credencial de uma variável e não de um arquivo, troca-se `target=…` por `env=CLAVE_REGISTRO`, e a variável existe só durante esse `RUN` (6.6.1). Entrega-se com `docker build --secret id=clave_registro,src=<archivo> .` (ou `env=<VARIABLE>` do terminal). Sem `ARG`, sem arquivo para apagar, e nenhuma linha do histórico com o valor. E `API_KEY` sai do Dockerfile: se o programa precisa dela ao rodar, ela chega como arquivo.

Pergunta extra: a regra decide pelo **nome** da variável. Medido com a mesma máquina e a mesma versão do Docker da lição, `docker build --check .` sobre a receita sai com código 1 e uma única advertência:

```text
Check complete, 1 warning has been found!
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "API_KEY")
```

`API_KEY` tem o tipo de nome que a regra procura. `CLAVE_REGISTRO`, em espanhol, passa sem advertência, e é justamente o valor que acaba no histórico. A lição que importa: a advertência é uma rede, não um cadeado.

## Como sei que consegui

Marque cada ponto só se ele puder ser feito **sem voltar a ver o texto**:

- [ ] Na pasta local, `docker run --rm curso-docker-revisor:1.3.0 version` imprime `1.3.0`, e `docker image inspect` mostra o rótulo `org.opencontainers.image.version = 1.3.0`.
- [ ] `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.3.0` mostra `REVISOR_PUERTO=8080` e nenhuma outra variável `REVISOR_*`.
- [ ] A mesma imagem roda com duas listas de serviços diferentes, uma por `-e` e outra por `--env-file`, sem reconstruir.
- [ ] Dá para explicar em um minuto a diferença entre `ARG` e `ENV` usando as palavras *construir*, *rodar*, *histórico* e *configuração*.
- [ ] `Dockerfile.malo` é construído e os dois segredos falsos são encontrados com dois comandos; e `docker build --check -f Dockerfile.malo .` dá as duas advertências e código 1.
- [ ] O `revisor` inicia com `REVISOR_TOKEN_ARCHIVO` e um arquivo montado somente leitura; `/api/estados` responde `401` sem token e a tabela com ele; e o `docker inspect` do contêiner não mostra o valor do token.
- [ ] O `permission denied` é provocado com `chmod 600` e dá para explicar por que ele ocorre usando as palavras *dono* e `65532`.
- [ ] `docker history --no-trunc --format '{{.CreatedBy}}' curso-docker-revisor:1.3.0 | grep -c 'modulos-de-mentira'` dá `0` depois de construir com `--secret`.
- [ ] Os scripts de [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos) foram rodados e as saídas coincidem com as desta lição, exceto os tempos, os números de passo do build, a data do arquivo de `fig06_08.sh`, a ordem das variáveis em `docker inspect` e a arquitetura do histórico. E ao terminar, `docker ps -a --filter name=curso-docker-` não mostra contêineres desta lição.

## Resumo

Responda sem olhar a lição:

1. O que é configuração, segundo *The Twelve-Factor App*, e que teste ele propõe para saber se a separação está boa?
2. Quando existe um `ARG` e quando existe um `ENV`? Onde fica escrito o valor de cada um?
3. Por que o Dockerfile do `revisor` declara `ARG VERSION` duas vezes?
4. Que diferença há entre `-e` e `--env-file`, e o que acontece com as aspas em um arquivo de variáveis?
5. Por que apagar um arquivo no mesmo `RUN` não protege um segredo que chegou por `ARG`?
6. O que `docker build --check` revisa com a regra `SecretsUsedInArgOrEnv`, e o que ele não consegue ver?
7. Por que um token por `-e` continua sendo uma má ideia mesmo não estando na imagem?
8. Por que um arquivo de segredo com permissões `600` dá `permission denied` dentro do contêiner, e quais são as boas correções?
9. O que `--mount=type=secret` faz, onde o arquivo aparece por padrão e o que significa `required`?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [The Twelve-Factor App, «Config»](https://12factor.net/config): a definição de configuração como o que varia entre deploys, o teste de publicar o código como aberto e a configuração em variáveis de ambiente.
- [Docker, «Build variables»](https://docs.docker.com/build/building/variables/): `ARG` versus `ENV`, que os argumentos não chegam aos contêineres mas podem persistir nos metadados, no histórico e nas atestações, o escopo por estágio e a advertência sobre segredos.
- [Docker, «Build secrets»](https://docs.docker.com/build/building/secrets/): por que os argumentos e as variáveis de ambiente não são apropriados para segredos, a montagem de segredo, seu caminho padrão `/run/secrets/<id>`, `target` e as formas `src` e `env` de `--secret`.
- [Referência do Dockerfile](https://docs.docker.com/reference/dockerfile/): as opções de `RUN --mount=type=secret` (`id`, `target`, `required`, `mode`) e seus valores padrão, `LABEL` e sua leitura com `docker image inspect`, e que `ENV` persiste nos contêineres e é mudado com `docker run --env`.
- [Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/): que o conteúdo de um segredo não faz parte do cache e como forçar o passo a se repetir.
- [Referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/): que, com um arquivo como fonte, os atributos `uid`, `gid` e `mode` de um segredo são ignorados, e como o `env_file` lê as aspas.
- [Docker, procedência SLSA](https://docs.docker.com/build/metadata/attestations/slsa-provenance/): que o modo mínimo, o padrão, não inclui os valores dos argumentos e que o modo `max` os expõe.
- [Docker, «Build checks»](https://docs.docker.com/build/checks/): a diretiva `# check=error=true`.
- [Docker, regra `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/): o que a regra informa e o exemplo correto com montagens de segredo.
- [Referência de `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `-e`, `-e` sem valor e o formato de `--env-file` com seus comentários.
- [Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/): por que as variáveis de ambiente não são um bom lugar para segredos e o caminho `/run/secrets/<nombre>`.
- [OCI Image Specification, anotações](https://github.com/opencontainers/image-spec/blob/main/annotations.md): as definições de `org.opencontainers.image.title`, `.version` e `.source`.
- [cmd/link](https://pkg.go.dev/cmd/link): a opção `-X` do linker do Go, que fixa o valor de uma variável de texto ao compilar.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões e datas de «Sobre as execuções».
- [Colima](https://github.com/abiosoft/colima): a ferramenta com que os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **argumento de build** (`ARG`) | variável que existe só enquanto a imagem é construída; é mudada com `--build-arg` e seu valor fica no histórico |
| **configuração** | o que muda de um ambiente para outro; chega ao rodar, não vai na imagem |
| **rótulo** (*label*) | par nome-valor colado na imagem como metadado; é lido com `docker image inspect` |
| **rótulos OCI** | rótulos com nomes padrão (`org.opencontainers.image.*`) que qualquer ferramenta entende |
| **histórico** (*history*) | a lista de instruções que criaram a imagem, com seus valores; é lido com `docker history` |
| **montagem de segredo** | arquivo que o BuildKit disponibiliza para um único `RUN` e que não fica em nenhuma camada |
| **segredo** | configuração que, se vazar, alguém pode usar contra nós: tokens, senhas, credenciais |
| **segredo de build** | o necessário para construir a imagem; é entregue com `docker build --secret` |
| **segredo de execução** | o que o programa precisa ao rodar; é entregue como arquivo em `/run/secrets/` |
| **variável de ambiente** (`ENV`, `-e`) | par nome-valor que um processo recebe ao iniciar; visível em `docker inspect` |

---

**Próxima:** [Lição 7 — Verificação de saúde e ciclo de vida](07-salud-y-ciclo-de-vida.md)
