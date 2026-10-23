# Lição 9 — Compose: o sistema completo

É quinta-feira, 17h40. Amanhã às 9h entra uma estagiária nova na equipe e sua primeira tarefa é subir o `revisor` no computador dela para ver como ele trabalha. Foram enviados a ela, pelo chat, os comandos usados por quem a recebe: seis comandos da Lição 8, copiados do histórico. Duas redes, um volume, dois `docker run` de três e cinco linhas, um `docker network connect`. Às 17h52 ela responde com uma captura de tela: o `revisor` diz `FALLA` para o serviço de teste, com um `no such host`. Os comandos que ela copiou são revisados e o problema aparece: ela pulou o `docker network connect`, o último, porque achou que era opcional. Explica-se. Às 18h05 ela manda outra captura: agora sai `OK`, mas o contêiner do `revisor` não tem `--read-only` nem `--cap-drop ALL`, porque ela copiou o `docker run` da Lição 3, que estava mais acima no mesmo chat. E amanhã o chefe quer que o relatório mostre três serviços ao mesmo tempo, um saudável, um lento e um fora do ar, para apresentá-lo na reunião. Isso são quatro contêineres, com sua ordem de inicialização, e alguém terá de se lembrar de tudo. São 18h10. A pergunta já não é como se roda um contêiner, e sim **como se escreve um sistema inteiro de modo que ninguém tenha de se lembrar de nada**. Esta lição existe para que amanhã se mande um único arquivo e um único comando, e para que o que subir seja exatamente o que foi testado, reforçado, com o token fora do arquivo e com o relatório em seu lugar.

**Tempo:** 2 × 45 min

**O que se constrói:** um `compose.yaml` na pasta `revisor/` que descreve o sistema completo: o `revisor`, construído a partir de seu Dockerfile, e três cópias do serviço de teste (saudável, lenta e fora do ar) para que o relatório mostre `OK`, `LENTO` e `FALLA` sem mexer em nada à mão. As duas redes da Lição 8 (uma normal e uma interna sem saída), o volume do relatório, o token como segredo do Compose e todas as opções de segurança das Lições 2 a 8, escritas uma única vez. Com `docker compose up -d --build` o sistema sobe do zero; com `docker compose down`, é desligado sem perder o relatório.

**O que se aprende:** o que é o Compose e o que é um projeto; como cada opção do `docker run` se traduz em uma chave do arquivo; `docker compose config` para validar e para ver o que o Compose entendeu; `up`, `ps`, `logs`, `stop` e `down`, e por que pedir `up` duas vezes não faz nada na segunda; como o Compose nomeia seus contêineres, redes e volumes; `depends_on` com `service_healthy` e por que «iniciado» não é «pronto»; os segredos do Compose e a armadilha de suas permissões; as âncoras do YAML e os campos `x-` para não repetir; `pull_policy: never`; o erro de três serviços que constroem a mesma imagem e o de `--wait` com um serviço que falha de propósito; e o que é `docker init` e por que não o usamos.

**De onde se parte.** Da [Lição 8](08-volumenes-y-redes.md) traz-se o estado final que esta lição passa para um arquivo: a imagem `curso-docker-revisor:1.5.0`, que guarda seu relatório em `/datos` por padrão e traz essa pasta com dono `65532`; o volume do relatório; a rede normal por onde se publica a porta e a rede interna sem saída onde vive o serviço de teste. Da [Lição 7](07-salud-y-ciclo-de-vida.md) traz-se as opções reforçadas (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`, limites), a política de reinício `unless-stopped` e uma promessa: usar a saúde para ordenar a inicialização de vários serviços. Da [Lição 6](06-configuracion-y-secretos.md) traz-se o token em `secretos/revisor_token.txt`, com permissões `644` (uma permissão que só vale para um token de mentira: em 9.8.3 mede-se quem pode lê-lo e em 9.8.4 ele é fechado), e outra promessa: os segredos do Compose. E da [Lição 2](02-contenedores-dia-a-dia.md), a imagem `curso-docker-prueba:1.0.0` e o costume de publicar portas só em `127.0.0.1`. A pasta do projeto tem `revisor/` (com seu `Dockerfile`, seu `.dockerignore` e `secretos/`) e, ao lado, `servicio-prueba/`.

**O que esta lição não faz.** Não muda o Dockerfile: a imagem é a mesma 1.5.0 da Lição 8, só que agora quem a constrói é o Compose. Não ensina Docker Swarm nem os campos de `deploy` que só fazem sentido em um cluster: este curso trabalha em uma máquina, e a passagem para várias máquinas é o curso de Kubernetes. Não usa perfis, arquivos de sobreposição (`compose.override.yaml`) nem `include`: são úteis quando um projeto cresce, e com um único arquivo se aprende primeiro o que todos eles combinam. Não usa `docker compose watch` nem montagens de código para desenvolvimento, porque o `revisor` aqui é entregue, não programado. E não publica a imagem em nenhum registry: isso é a [Lição 10](10-entregar-la-imagen.md).

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4, a mesma base do Linux Mint 22, o sistema de referência do curso, com kernel 6.8 e processador `arm64`. Os scripts foram executados **dentro** dessa máquina virtual, com Docker 29.2.1 (cliente e daemon), **Docker Compose v5.0.2** e Buildx v0.31.1, e com a pasta de trabalho no disco próprio do Linux; isso importa na seção 9.10, que trata das permissões de um arquivo, porque as pastas compartilhadas entre o Mac e a máquina virtual mentem sobre elas. No Mint esse problema não existe. O curso foi planejado com Docker Engine 29.8.2 e Compose v5.6.0 (medidos em 7 de outubro), e a versão mais recente do Engine publicada no dia das execuções era a 29.9.2, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)); não se espera que nada desta lição mude entre essas versões, mas as saídas foram medidas com o Compose v5.0.2: se a versão instalada der outro texto em um erro, compare-o pelo sentido. Confira as versões instaladas com `docker version` e `docker compose version`. **Os nomes.** Para não tocar no que é da pessoa, os scripts usam um projeto do Compose próprio, `curso-docker-fig09`, e suas próprias imagens, `curso-docker-revisor:fig09` e `curso-docker-prueba:fig09`; assim nunca tocam no projeto `curso-docker`, em `curso-docker-revisor:1.5.0` nem em `curso-docker-prueba:1.0.0`, e ao sair apagam só o que criaram. Por isso, nas saídas, os contêineres se chamam `curso-docker-fig09-revisor-1` e não `curso-docker-revisor-1`, que é como se vão chamar na pasta do projeto (a seção 9.4 explica de onde sai cada parte do nome). Além disso, como na mesma máquina rodavam outras lições, os scripts foram lançados com outro prefixo e outra porta (as variáveis `PREFIJO` e `PUERTO` que eles trazem); uma função `nombres`, à vista em cada script, volta a escrever esse prefixo como `curso-docker-` e a porta como `8080`, e com os valores padrão não muda nada. O que **muda** de uma execução para outra, e é avisado onde aparece: os tempos da tabela do `revisor` (ocultados com `<t>`, e por isso às vezes a coluna fica um espaço mais à esquerda ou à direita), os segundos de `Up N`, o número do arquivo temporário do relatório (`<n>`), as datas, a ordem de alguns eventos que ocorrem ao mesmo tempo, o serviço que um erro de validação nomeia e, em 9.11, em quais tentativas e em qual dos três serviços ocorre o choque. Os programas estão em [`programas/09-compose/`](../programas/09-compose), cada um com sua saída ao lado, e `estado/` guarda os arquivos do projeto como ficam ao terminar.

## Ao terminar, será possível

- Traduzir os comandos `docker run`, `docker network create` e `docker volume create` da Lição 8 para um `compose.yaml` sem `version:`, e explicar que chave corresponde a cada opção.
- Validar o arquivo com `docker compose config --quiet` e ler em `docker compose config` a forma longa do que foi escrito na forma curta.
- Subir, olhar e desligar o sistema com `up -d --build`, `ps`, `logs`, `stop` e `down`, e prever que contêineres o Compose recria quando o arquivo muda.
- Provocar e explicar o `500` de `read-only file system` quando o `revisor` reforçado não tem nada montado em `/datos`.
- Ordenar a inicialização com `depends_on` e `condition: service_healthy`, e explicar por que o `revisor` espera só a cópia saudável.
- Entregar o token como segredo do Compose, comprovar que ele não aparece no `docker inspect` nem no `docker compose config`, e diagnosticar o `permission denied` de um arquivo em `600`.
- Medir quem pode ler o arquivo do token com `644`, `600` e `640` (com `ls -l`, `stat` e uma conta sem privilégios), e deixá-lo com a permissão mínima que ainda deixa o `revisor` trabalhar.
- Reconhecer o choque de três serviços que constroem a mesma tag e a falha do `up --wait` com um serviço fora do ar de propósito, e escolher a alternativa correta.

## O porquê antes do como

O que foi feito na Lição 8 funciona, e é justamente como deve ser aprendido: cada peça com seu comando, para ver o que ela traz. Mas tem três problemas que aparecem no dia em que outra pessoa o usa, ou no dia em que a própria pessoa o usa três semanas depois.

O primeiro é que **o sistema vive no histórico**. Seis comandos, em uma ordem que importa, com opções que ninguém escreve igual duas vezes. A cena do início não é exagerada: basta pular um `docker network connect` para que o `revisor` não encontre o serviço de teste, e basta copiar o `docker run` errado para perder o reforço da Lição 7 sem que nada avise. Um serviço que depende de alguém lembrar seis comandos depende, na verdade, da memória dessa pessoa.

O segundo é que **a ordem é feita à mão**. As redes antes dos contêineres, o volume antes do `revisor`, o serviço de teste antes de quem o verifica. E ao desligar, ao contrário: primeiro os contêineres, porque uma rede ou um volume em uso não se apaga. Na Lição 8 essa ordem era feita à mão; com quatro contêineres em vez de dois, e com um que deve esperar que outro esteja **saudável** e não só rodando, a ordem já não cabe na cabeça.

O terceiro é que **não há como saber o que está rodando em comparação com o que deveria**. Se amanhã o modo de um serviço de teste mudar, que contêineres precisam ser apagados e criados de novo? Com `docker run` a resposta é dada por quem opera. O ideal é que uma ferramenta compare o que foi pedido com o que existe e toque apenas no que mudou.

O Compose resolve as três coisas com uma ideia: **descrever o sistema em um arquivo, e deixar que uma ferramenta o faça existir**. Sua documentação o define como «uma ferramenta para definir e executar aplicações com vários contêineres» ([Docker, «Docker Compose»](https://docs.docker.com/compose/)). O arquivo, `compose.yaml`, diz que serviços existem, em que redes vivem, que volumes e segredos usam, e com que opções rodam. O comando `docker compose up` lê o arquivo, compara com o que já existe e cria, recria ou deixa em paz o que for necessário, na ordem correta. O arquivo é guardado junto ao código, é revisado como o código e é enviado à estagiária no lugar de seis comandos.

Com esse destino em mente, isto é o que se terá no final, na seção 9.9: o sistema completo no ar com um comando, e o relatório do `revisor` mostrando os três comportamentos do serviço de teste sem que nada tenha sido tocado à mão:

```text
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200
```

(É o bloco 3 do `fig09_05.sh`; os espaços antes de `<t>` mudam com o tempo que foi ocultado.) Essa tabela é a primeira das metas do curso: «`docker compose up` sobe tudo do zero e o relatório mostra o serviço de teste fora do ar como `FALLA`».

## Os conceitos

### 9.1 O que é o Compose, e o que é um projeto

#### 9.1.1 Um *plugin*, um arquivo, uma especificação

O Compose vem com a instalação da Lição 1: o pacote `docker-compose-plugin` acrescenta o subcomando `docker compose` (com espaço). Não é um programa à parte que precise ser instalado com `pip` nem um binário baixado à mão; é uma extensão do cliente `docker`, e por isso sua versão se pergunta com `docker compose version`.

O arquivo se chama `compose.yaml`. A documentação diz que o caminho padrão é `compose.yaml` («preferido») ou `compose.yml` na pasta de trabalho, e que o Compose também aceita `docker-compose.yaml` e `docker-compose.yml` «por compatibilidade com versões anteriores» ([Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/)). Este curso usa o nome preferido.

O que vai dentro do arquivo não é inventado pelo Docker a cada ano: é definido pela **especificação do Compose**, um documento público que descreve cada chave e o que ela significa ([especificação do Compose](https://docs.docker.com/reference/compose-file/)). Os elementos de nível superior que serão usados hoje são cinco: `name`, `services`, `networks`, `volumes` e `secrets`. Há outros que esta lição não usa: `configs` (arquivos de configuração que não são segredos; o `revisor` se configura por variáveis e não precisa deles), `include` (para unir vários arquivos) e `models` (que, segundo a especificação, «declara os modelos de IA que sua aplicação do Compose usa», [especificação, `models`](https://docs.docker.com/reference/compose-file/models/)); e `version`, que já é obsoleto (9.2.3). A documentação os apresenta assim: os componentes de uma aplicação «são definidos como serviços», os serviços «se comunicam entre si por meio de redes», e «guardam e compartilham dados persistentes em volumes» ([Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/)).

#### 9.1.2 Um serviço não é um contêiner

Aqui está a primeira ideia nova, e convém não passá-la depressa. Na Lição 8 eram criados **contêineres**: `curso-docker-revisor`, `curso-docker-prueba`. No Compose descrevem-se **serviços**: `revisor`, `prueba`. Um serviço é a receita («rode esta imagem, com estas opções, nestas redes»); o contêiner é o que sai de aplicar a receita. Normalmente um serviço dá um contêiner, mas a diferença importa por duas razões que se verão na lição. Uma: o nome que convém usar para encontrá-lo por DNS é o do **serviço** (`prueba`), não o do contêiner. O nome do contêiner também resolve dentro da rede (foi comprovado), mas leva o nome do projeto e um número de réplica, que mudam de uma pasta para outra. Duas: quando a receita muda, o Compose joga fora o contêiner velho e cria um novo; o serviço continua sendo o mesmo.

#### 9.1.3 O projeto: o sobrenome de tudo

Um **projeto** é, segundo a documentação, «uma implantação individual de uma especificação de aplicação» ([Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/)). Na prática, é o nome que o Compose coloca na frente de tudo o que cria, para saber o que é seu. O `compose.yaml` do curso começa com `name: curso-docker`, e por isso tudo o que ele cria leva esse nome: contêineres, redes e volumes. Se não for escrito, o Compose usa o nome da pasta onde está o arquivo, que neste caso seria `revisor`: um sobrenome genérico demais para ser reconhecido entre outros projetos.

O nome do projeto pode ser fixado de cinco formas, e a documentação diz qual ganha: primeiro a opção `-p` da linha de comando; depois a variável de ambiente `COMPOSE_PROJECT_NAME`; depois o `name:` do arquivo; depois o nome da pasta do arquivo; e por último o nome da pasta atual. Só admite «letras minúsculas, dígitos decimais, hífens e sublinhados» ([Docker, «Specify a project name»](https://docs.docker.com/compose/how-tos/project-name/)). Essa mesma página diz para que serve: «o Compose usa um nome de projeto para isolar os ambientes uns dos outros». Os scripts desta lição aproveitam isso: fixam `COMPOSE_PROJECT_NAME=curso-docker-fig09`, que vale mais que o `name:` do arquivo, e assim sua execução nunca se mistura com o projeto `curso-docker`, embora o arquivo seja o mesmo.

### 9.2 Do `docker run` ao arquivo

#### 9.2.1 O estado final da Lição 8, escrito uma vez

O concreto primeiro. Este é o estado final da Lição 8, o da seção 8.10.3, em um arquivo. Guarde-o na pasta `revisor/` com o nome `compose.yaml`:

```yaml
# fig09_01.compose.yaml — Lección 9, primer paso: el estado final de la
# Lección 8 (sección 8.10.3), escrito en un archivo en vez de en seis comandos.
# Un solo servicio de prueba, sin token. Va en tu carpeta revisor/ como compose.yaml.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: "prueba http://prueba:9000/ 2s"
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      - prueba
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

  prueba:
    build: ../servicio-prueba
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}
```

Leia-o de baixo para cima, que é como o Compose o constrói. No final estão as **redes** e o **volume**: `publica`, `interna` (com `internal: true`, o `--internal` da Lição 8) e `reportes`. As chaves vazias `{}` dizem «com as opções padrão»: uma rede `bridge` e um volume local. Em cima estão os dois **serviços**. Cada serviço lista suas redes pelo nome curto (`publica`, `interna`) e monta o volume pelo nome curto (`reportes:/datos`); o Compose coloca o sobrenome do projeto ao criá-los. O serviço de teste só está na `interna`; o `revisor`, nas duas. Exatamente como em 8.10.3, mas sem o passo do `docker network connect` que a estagiária esqueceu: aqui não há passos, há uma descrição.

#### 9.2.2 Cada opção, sua chave

Quase toda opção do `docker run` tem uma chave com nome parecido. Esta tabela é a que se usa para traduzir qualquer comando das lições anteriores:

| `docker run` | `compose.yaml` | Nota |
|---|---|---|
| `curso-docker-revisor:1.5.0` (a imagem) | `image:` | com `build:` ao lado, é o nome que a imagem construída recebe |
| `docker build --build-arg VERSION=1.5.0 .` | `build: { context: ., args: { VERSION: "1.5.0" } }` | o Compose constrói antes de criar o contêiner |
| `-e REVISOR_SERVICIOS=…` | `environment:` | como mapa (`CHAVE: valor`), sem aspas que cheguem ao valor |
| `-p 127.0.0.1:8080:8080` | `ports: ["127.0.0.1:8080:8080"]` | o endereço `127.0.0.1` se escreve igual à Lição 2 |
| `-v curso-docker-reportes:/datos` | `volumes: [reportes:/datos]` + `volumes:` em cima | o volume é declarado uma vez no nível superior |
| `--network …` e `docker network connect …` | `networks: [publica, interna]` + `networks:` em cima | todas as redes do serviço em uma lista |
| `--read-only` | `read_only: true` | |
| `--cap-drop ALL` | `cap_drop: [ALL]` | |
| `--security-opt no-new-privileges` | `security_opt: ["no-new-privileges:true"]` | |
| `--init` | `init: true` | |
| `--memory 64m`, `--cpus 0.5`, `--pids-limit 50` | `mem_limit: 64m`, `cpus: 0.5`, `pids_limit: 50` | |
| `--restart unless-stopped` | `restart: unless-stopped` | aparece no arquivo final (9.9) |
| `--name curso-docker-revisor` | (nada) | o nome é colocado pelo Compose: projeto, serviço e número |

A referência dos serviços descreve cada uma com a mesma intenção conhecida na Lição 7: `read_only` cria o contêiner «com um sistema de arquivos somente leitura»; `init` roda «um processo init (PID 1) dentro do contêiner que reenvia sinais e recolhe processos»; `cpus` define quantas CPUs, «potencialmente virtuais», lhe são atribuídas; e `pids_limit` ajusta o limite de processos ([referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/)). Não há mágica nova: são as mesmas opções do daemon, escritas em outro lugar.

Há duas chaves da tabela que merecem mais uma frase. A primeira, `security_opt`: a referência diz que as opções booleanas como `no-new-privileges` podem ser escritas de três formas equivalentes (`no-new-privileges`, `no-new-privileges=true` e `no-new-privileges:true`). O curso usa a última porque é a que menos dúvidas deixa. A segunda, `depends_on: [prueba]`: não tem equivalente no `docker run`, porque ordenar contêineres era trabalho de quem operava. Diz ao Compose que o `revisor` é criado e iniciado depois de `prueba`. Mais adiante (9.7) se verá que «depois» não significa «quando já está pronto».

#### 9.2.3 Sem `version:`

O arquivo não começa com `version: "3.8"` nem nada parecido, e não é descuido. A especificação diz que o elemento `version` existe só por compatibilidade, que «é apenas informativo» e que, se for usado, será recebido «um aviso de que é obsoleto» ([especificação, `version` e `name`](https://docs.docker.com/reference/compose-file/version-and-name/)). Ele aparece em quase todos os tutoriais de alguns anos atrás, porque o Compose antigo o exigia para saber que chaves aceitar. O de hoje aplica a especificação vigente na versão instalada e não precisa desse campo. Se for encontrado, apague-o.

### 9.3 Validar e ler o que o Compose entendeu

#### 9.3.1 `docker compose config`

Antes de subir qualquer coisa, convém saber se o arquivo é válido e se o Compose entendeu o que se queria dizer. Para isso existe o `docker compose config`, que segundo sua referência «mostra o modelo de dados real que será aplicado no Docker Engine»: resolve as variáveis e «expande a notação curta para a forma canônica» ([referência do `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/)). Três opções o tornam útil no dia a dia: `--quiet` só valida e não imprime nada (se o arquivo está errado, o erro sai e o código não é 0); `--services` lista os serviços, um por linha; e `--volumes`, os volumes.

O script `fig09_02.sh` pega o primeiro `compose.yaml` e o passa por todo o ciclo: validar, ler, subir, pedir de novo e desligar. É o primeiro script da lição, então aqui vai completo; os seguintes repetem a mesma abertura (os nomes de apoio, a pasta de trabalho e as funções `muestra`, `eventos`, `esperar` e `tabla`) e na lição só se mostra a parte que muda:

```bash
#!/usr/bin/env bash
# fig09_02.sh — El primer compose.yaml (fig09_01): validarlo, leer lo que Compose
# entiende, levantarlo, pedir el reporte, volver a pedir «up» y apagarlo.
# Construye sus propias imágenes de apoyo; no usa ni toca las tuyas.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig09»: el proyecto de Compose se llama curso-docker-fig09
# y las imágenes curso-docker-revisor:fig09 y curso-docker-prueba:fig09. Así el
# guion nunca toca tu proyecto curso-docker, tu curso-docker-revisor:1.5.0 ni tu
# curso-docker-prueba:1.0.0, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d "${TMPDIR:-/tmp}/${PREFIJO}fig09.XXXXXX")"
export COMPOSE_PROJECT_NAME="${PREFIJO}fig09"   # gana sobre el «name:» del archivo
trap 'cd "$TRABAJO/revisor" 2>/dev/null && docker compose down --volumes --remove-orphans >/dev/null 2>&1
      docker rmi -f "${PREFIJO}revisor:fig09" "${PREFIJO}prueba:fig09" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso, el estado de la Lección 8 (con el
# token de la Lección 6) y el compose.yaml de fig09_01.compose.yaml, con los nombres de apoyo
# y el puerto del guion.
mkdir -p "$TRABAJO/revisor"
cp -R "$AQUI/../revisor/." "$TRABAJO/revisor/"
cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
cp -R "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$AQUI/estado/secretos" "$TRABAJO/revisor/"
chmod 644 "$TRABAJO/revisor/secretos/revisor_token.txt"   # 644: solo porque el token es de mentira (9.8.4)
sed -e "s/curso-docker-revisor:1.5.0/${PREFIJO}revisor:fig09/" \
    -e "s/curso-docker-prueba:1.0.0/${PREFIJO}prueba:fig09/" \
    -e "s/127.0.0.1:8080:8080/127.0.0.1:${PUERTO}:8080/" \
    "$AQUI/fig09_01.compose.yaml" > "$TRABAJO/revisor/compose.yaml"
cd "$TRABAJO/revisor"
TOKEN="$(cat secretos/revisor_token.txt)"   # se lee del archivo; nunca se escribe

# Si corres el guion con otro PREFIJO o PUERTO, la salida se escribe con los del
# curso. Con los valores por omisión esto no cambia nada.
nombres() { sed -e "s/${PREFIJO}/curso-docker-/g" -e "s/127.0.0.1:${PUERTO}->/127.0.0.1:8080->/g" \
                -e "s/127.0.0.1:${PUERTO}\//127.0.0.1:8080\//g" -e "s/published: \"${PUERTO}\"/published: \"8080\"/"; }
# muestra COMANDO: lo imprime con «$ », lo corre y dice el código si no fue 0
muestra() {
  printf '$ %s\n' "$*" | nombres
  eval "$@" 2>&1 | nombres
  local rc=${PIPESTATUS[0]}
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# eventos: de lo que imprime Compose, solo los renglones «Objeto nombre Estado»
eventos() { grep -E '^ *(Image|Network|Volume|Container) ' | sed -E 's/^ +//; s/ +$//'; }
# esperar SERVICIO ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar() {
  for _ in $(seq 60); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "${COMPOSE_PROJECT_NAME}-$1-1" 2>/dev/null)" = "$2" ] && return 0
    sleep 1
  done
  echo "($1 no llegó a $2)"; return 1
}
# tabla: el reporte en forma de tabla, con el token y con los tiempos tapados
tabla() { curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados?formato=tabla" | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'; }

echo "== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config --volumes"

echo
echo "== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto"
muestra "docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'"
muestra "docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'"

echo
echo "== 3. Levantarlo todo"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s 'http://127.0.0.1:${PUERTO}/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'"

echo
echo "== 4. Pedir «up» otra vez, sin cambiar nada"
muestra "docker compose up -d 2>&1 | eventos"

echo
echo "== 5. Apagar: down borra contenedores y redes; el volumen se queda"
muestra "docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
```

E sua saída:

```text
$ ./fig09_02.sh
== 1. ¿Es válido? ¿Qué servicios y volúmenes declara?
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba
revisor
$ docker compose config --volumes
reportes

== 2. Lo que Compose entendió: la forma larga de lo que escribiste corto
$ docker compose config | sed -n '/^  revisor:/,/^  prueba:/p' | grep -E -A5 '^    (ports|volumes|depends_on):'
    depends_on:
      prueba:
        condition: service_started
        required: true
    environment:
      REVISOR_SERVICIOS: prueba http://prueba:9000/ 2s
--
    ports:
      - mode: ingress
        host_ip: 127.0.0.1
        target: 8080
        published: "8080"
        protocol: tcp
--
    volumes:
      - type: volume
        source: reportes
        target: /datos
        volume: {}
networks:
$ docker compose config | grep -E '^  [a-z]+:$|^    (cpus|mem_limit|pids_limit|read_only|internal|init):'
  prueba:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  revisor:
    cpus: 0.5
    init: true
    mem_limit: "67108864"
    pids_limit: 50
    read_only: true
  interna:
    internal: true
  publica:
  reportes:

== 3. Levantarlo todo
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-prueba:fig09 Built
Image curso-docker-revisor:fig09 Built
Network curso-docker-fig09_interna Created
Network curso-docker-fig09_publica Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-1 Started
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp
$ curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla' | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /'
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200

== 4. Pedir «up» otra vez, sin cambiar nada
$ docker compose up -d 2>&1 | eventos
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Running

== 5. Apagar: down borra contenedores y redes; el volumen se queda
$ docker compose down 2>&1 | eventos | grep -vE 'Stopping|Removing'
Container curso-docker-fig09-revisor-1 Stopped
Container curso-docker-fig09-revisor-1 Removed
Container curso-docker-fig09-prueba-1 Stopped
Container curso-docker-fig09-prueba-1 Removed
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
```

#### 9.3.2 Ler os blocos 1 e 2

1. **Válido, com dois serviços e um volume.** O `config --quiet` não imprime nada se o arquivo está certo; o `echo` do script o diz por ele. Repare que `prueba` sai antes de `revisor`, embora no arquivo tenha sido escrito depois. O Compose não lista pela ordem em que foi escrito: primeiro saem as dependências e no final quem depende delas, e isso é decidido pelo `depends_on`. (Isso ficará mais claro em 9.9, com quatro serviços: as três cópias do serviço de teste primeiro, entre elas em ordem alfabética, e o `revisor` no final. O que varia de uma execução para outra é a ordem dos eventos do `up`, porque várias coisas ocorrem ao mesmo tempo.)
2. **A forma longa.** Aqui está o que realmente interessa a quem revisa um arquivo alheio. O `depends_on: [prueba]` virou `condition: service_started` e `required: true`: a forma curta é a forma longa com os valores padrão. O `"127.0.0.1:8080:8080"` virou um bloco com `host_ip: 127.0.0.1`, `target: 8080` (a porta do contêiner) e `published: "8080"` (a da máquina): se algum dia houver dúvida sobre qual número é qual, o `config` diz com nomes. O `reportes:/datos` virou `type: volume`, `source: reportes`, `target: /datos`. E no segundo comando, `mem_limit: 64m` aparece como `"67108864"`, que são 64 × 1024 × 1024 bytes, o mesmo número que o `docker inspect` mostrou na Lição 2. O `config` é a melhor ferramenta para revisar um `compose.yaml` que não foi escrito por quem revisa: não diz o que o autor quis, diz o que vai acontecer.

Um costume que convém adotar desde hoje: **toda vez que o arquivo for editado, rode `docker compose config --quiet` antes do `up`**. Um erro de indentação em YAML muda o significado sem dar erro de sintaxe (uma chave que ficou dentro do serviço errado, por exemplo), e o `config` é onde isso é visto antes que o contêiner inicie com outra configuração.

### 9.4 Subir, olhar e desligar

#### 9.4.1 `up`: criar o que falta, em ordem

O `docker compose up` é o comando central. Sua referência o resume em uma linha: «constrói, (re)cria, inicia e se conecta aos contêineres de um serviço» ([referência do `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Com `-d` («modo separado») deixa os contêineres em segundo plano e devolve o terminal; com `--build`, constrói as imagens antes de iniciar, mesmo que já existam.

O bloco 3 do `fig09_02.sh` mostra o que ele fez, na ordem em que fez. Primeiro as **duas imagens**, `Built`. Depois as **redes**, `curso-docker-fig09_interna` e `curso-docker-fig09_publica`, e o **volume**, `curso-docker-fig09_reportes`. Depois os **contêineres**: `Created` os dois, e `Started` primeiro `prueba` e depois `revisor`, porque o `revisor` depende dele. É a ordem que na Lição 8 era feita à mão, agora decidida pelo arquivo. (O script remove da listagem as linhas intermediárias, como `Building`, `Creating` ou `Starting`, para que os resultados sejam lidos; no terminal elas aparecem todas.)

#### 9.4.2 Como as coisas se chamam

Olhe os nomes com cuidado, porque eles serão escritos no `docker inspect`, no `docker logs` e no auxiliar de `alpine`:

- **Contêineres**: `<projeto>-<serviço>-<número>`. Na saída, `curso-docker-fig09-revisor-1`; na pasta do projeto, com `name: curso-docker`, `curso-docker-revisor-1`. O número existe porque um serviço pode ter várias réplicas; aqui é sempre `1`.
- **Redes e volumes**: `<projeto>_<nome>`, com sublinhado. `curso-docker-fig09_interna`, `curso-docker-fig09_reportes`; na pasta do projeto, `curso-docker_interna` e `curso-docker_reportes`.

Como o projeto começa com `curso-docker`, tudo continua tendo o prefixo do curso, e o costume da Lição 2 (poder apagar o que é do curso sem tocar no resto) se mantém. Além disso, o Compose coloca em tudo o que cria o rótulo `com.docker.compose.project=<projeto>`. É a forma limpa de perguntar «o que é deste projeto», e o bloco 5 a usa: `docker volume ls --filter label=com.docker.compose.project=…`.

E uma pergunta que provavelmente surge: se o contêiner se chama `curso-docker-fig09-prueba-1`, por que o `revisor` o busca como `http://prueba:9000/`? Porque nas redes de um projeto, cada contêiner se registra no DNS integrado (o `127.0.0.11` da Lição 8) com o nome de seu **serviço** e também com o seu próprio; em um teste à parte, os dois nomes resolveram para o mesmo endereço. O do serviço é o que convém escrever, porque é o único que não depende do projeto nem do número de réplica. A documentação explica com seu exemplo: o contêiner do serviço `web` entra na rede «com o nome `web`» ([Docker, «Networking in Compose»](https://docs.docker.com/compose/how-tos/networking/)). Isso permite escrever `REVISOR_SERVICIOS` sem saber como o projeto vai se chamar: o mesmo arquivo funciona na pasta de quem estuda, na da estagiária e no script.

A mesma página diz o que acontece se redes não forem declaradas: o Compose cria **uma** rede, `<projeto>_default`, e conecta ali todos os serviços. O arquivo do curso declara as suas, e por isso na saída não há nenhuma `_default`. Não é um detalhe: com a rede padrão do Compose, o serviço de teste teria saída para a internet, e a Lição 8 decidiu que ele não precisa dela.

#### 9.4.3 `ps`: o que há, e como está

O `docker compose ps` é o `docker ps` do projeto: só mostra seus contêineres. O bloco 3 o usa com um formato próprio (nome, estado e portas) e oculta os segundos de `Up` com `Up N`. Os dois estão `(healthy)`, porque as duas imagens trazem seu `HEALTHCHECK` desde as Lições 2 e 7, e a porta do `revisor` está em `127.0.0.1:8080`. O serviço de teste não publica nada: não precisa, o `revisor` fala com ele pela rede interna. E a tabela do `revisor` diz `prueba OK`.

#### 9.4.4 Pedir `up` de novo: não acontece nada, e isso é o bom

O bloco 4 roda `docker compose up -d` outra vez, sem mudar nada. O Compose responde `Running` para os dois e não toca em nenhum. Esta é a diferença mais importante em relação a um script de `docker run`: um script repetido tenta criar de novo e esbarra no nome repetido da Lição 2. O Compose, ao contrário, **compara** o que se pede com o que há. A referência do `up` diz assim: se a configuração ou a imagem de um serviço mudaram, o Compose «assume as mudanças parando e recriando os contêineres», e conserva os volumes montados ([referência do `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Se nada mudou, nada é tocado. Por isso o `docker compose up -d` é seguro de repetir: é a forma de dizer «que isto exista», não «crie isto».

#### 9.4.5 `down`: o volume fica

O bloco 5 desliga com `docker compose down`. Para e apaga os contêineres (primeiro o `revisor`, que depende de `prueba`; o Compose desliga na ordem inversa das dependências) e apaga as redes. E o volume **fica**: o `docker volume ls` continua mostrando-o. A referência do `down` lista o que ele apaga por padrão: os contêineres dos serviços, as redes da seção `networks` e a rede padrão, se foi usada ([referência do `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/)). Os volumes nomeados não estão nessa lista; para apagá-los é preciso pedir com `--volumes`, que apaga «os volumes nomeados declarados na seção `volumes`». É a decisão correta: desligar o sistema não deveria custar o relatório. Em 9.12 se verá ele sobreviver.

### 9.5 O erro: o `revisor` reforçado sem nada em `/datos`

#### 9.5.1 Provocá-lo

Desde a imagem 1.5.0 da Lição 8, o `revisor` guarda seu relatório em `/datos/reporte.json` **por padrão**: a imagem traz `REVISOR_REPORTE=/datos/reporte.json` em seu `ENV`. E o `compose.yaml` o roda com `read_only: true`. O que acontece se alguém, ao passar o arquivo a limpo, apaga a linha do volume porque «o relatório não é usado»? O script `fig09_03.sh` faz isso à vista, com `sed`, e mostra a diferença com `diff` antes de subir. A parte do script que muda em relação ao `fig09_02.sh`:

```bash
cp compose.yaml compose.bueno.yaml

echo "== 1. Sin el volumen en /datos"
# Borra el renglón «volumes:» del revisor y el que le sigue («- reportes:/datos»).
sed -i '/^    volumes:$/{N;d;}' compose.yaml
muestra "diff compose.bueno.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'"

echo
echo "== 2. Con el volumen: Compose recrea SOLO el revisor"
cp compose.bueno.yaml compose.yaml
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'"
esperar revisor healthy
muestra "curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
```

```text
$ ./fig09_03.sh
== 1. Sin el volumen en /datos
$ diff compose.bueno.yaml compose.yaml
19,20d18
<     volumes:
<       - reportes:/datos
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Healthy)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]

== 2. Con el volumen: Compose recrea SOLO el revisor
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing'
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-1 Running
Container curso-docker-fig09-revisor-1 Recreate
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
```

#### 9.5.2 Lê-lo

1. **O `diff`** mostra as duas linhas que faltam (e sai com `1`, que no `diff` significa «há diferenças», não «falhou»). O arquivo continua sendo válido: um serviço sem volumes é perfeitamente legal, e por isso o `config --quiet` não salvaria aqui. O contêiner inicia e chega a `(healthy)`, porque `/salud` não escreve nada. O Docker está contente.
2. **Mas o relatório dá `500`**: `open /datos/.reporte-<n>.tmp: read-only file system`. É o erro da seção 7.7 da Lição 7, em outra pasta: o `revisor` tenta criar seu arquivo temporário em `/datos`, e `/datos` é parte do sistema de arquivos do contêiner, que é somente leitura. Não há nada montado por cima que aceite escritas. Repare que o `revisor` não cai nem finge: responde `500` com a causa exata. É o segundo critério do curso funcionando: o contêiner está `healthy` e o serviço não faz o que deve.
3. **A correção**, devolver as duas linhas, e a segunda lição do dia sobre o Compose. O `up -d` cria o volume que agora sim é usado (`Volume … Created`), deixa o serviço de teste como estava (`Running`) e **recria só o `revisor`** (`Recreate`, `Recreated`, `Started`), porque sua configuração mudou. O relatório volta a `200`.

A regra que fica: **com `read_only: true`, cada pasta onde o programa escreve precisa de algo montado por cima**. No `revisor` é uma só, `/datos`, e o arquivo do curso sempre a monta. Se algum dia `REVISOR_REPORTE` for mudado para outro caminho, esse caminho também precisa de seu volume (ou de seu `tmpfs`, se não deve durar).

### 9.6 Três cópias do serviço de teste sem escrever três vezes o mesmo

#### 9.6.1 Por que três

Com um único serviço de teste, o relatório sempre diz `OK`, a menos que seu modo seja mudado à mão com `POST /modo/caido`. Mas o serviço de teste vive em uma rede interna e não publica porta: para mudar seu modo seria preciso entrar por outro lado. Há uma forma melhor de mostrar os três comportamentos ao mesmo tempo, e é a que o chefe da cena pediu: **três contêineres da mesma imagem, cada um iniciado em um modo diferente** com `PRUEBA_MODO`. Assim o relatório mostra `OK`, `LENTO` e `FALLA` assim que o sistema inicia, sem tocar em nada.

Três serviços quase iguais significam o mesmo bloco de opções reforçadas escrito três vezes, e um bloco repetido é um bloco que algum dia alguém muda em duas das três cópias. O Compose tem duas ferramentas para isso, e são usadas juntas.

#### 9.6.2 Campos `x-` e âncoras do YAML

A primeira é uma regra do Compose: os campos de primeiro nível que começam com `x-` são ignorados. A documentação diz isso literalmente: «o Compose ignora qualquer campo que comece com `x-`», e é «a única exceção» em que ignora em silêncio um campo que não reconhece; servem para «modularizar configurações que se quer reutilizar» ([especificação, extensões](https://docs.docker.com/reference/compose-file/extension/)).

A segunda não é do Compose, e sim do YAML: as **âncoras** e os **aliases**. Uma âncora se coloca com `&nome` na frente de um bloco; um alias, `*nome`, refere-se a esse bloco; e a chave de mescla `<<: *nome` copia as chaves do bloco para dentro de outro mapa, onde podem ser acrescentadas ou substituídas as que se quiser. A documentação do Compose avisa de dois detalhes: a mescla «só se aplica a mapas, e não pode ser usada com sequências», e quando fragmentos são usados, as variáveis de ambiente vão como mapa (`CHAVE: valor`) e não como lista (`- CHAVE=valor`) ([especificação, fragmentos](https://docs.docker.com/reference/compose-file/fragments/)). Por isso todo o `environment` do curso está escrito como mapa.

Juntas se veem assim, em um trecho do arquivo final:

```yaml
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true

services:
  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento
```

`x-prueba` não é um serviço (o Compose o ignora), mas seu conteúdo existe para o YAML com a âncora `&prueba`. `prueba-lento` copia todo esse bloco com `<<: *prueba` e acrescenta seu `environment`. O bloco 1 do `fig09_05.sh`, mais adiante, demonstra isso pedindo ao `config` o serviço `prueba-lento`: aparecem `image`, `pull_policy`, `read_only`, `mem_limit` e `networks`, que não estão escritos no serviço, e sim na âncora.

#### 9.6.3 Quem constrói, e `pull_policy: never`

Resta uma decisão: quem constrói a imagem `curso-docker-prueba:1.0.0`? Se a âncora levasse `build: ../servicio-prueba`, as três cópias a herdariam, e o Compose lançaria **três construções ao mesmo tempo da mesma tag**. Isso colide, e em 9.11 será provocado. O arquivo final faz outra coisa: só `prueba-sano` leva `build`. As outras duas usam a imagem que a primeira constrói.

E para que essas duas não saiam procurando-a na internet, a âncora leva `pull_policy: never`. A referência o define assim: com `never`, o Compose «não baixa a imagem de um registry e se baseia na imagem armazenada na plataforma» ([referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/)). O que acontece sem essa linha? Será medido no bloco 2 do `fig09_07.sh` (seção 9.11): em uma máquina onde a imagem ainda não existe, o Compose primeiro vai buscá-la no Docker Hub para cada serviço que não a constrói, recebe duas vezes o `pull access denied` da Lição 2, e então, como outro serviço do projeto de fato a constrói, segue adiante, a constrói e sobe tudo. Funciona, mas faz consultas à internet de que não se precisa, enche a saída de erros que não o são, e deixa o resultado nas mãos do que alguém tenha publicado com esse nome. Com `pull_policy: never`, o nome da imagem deixa de ser uma pergunta à internet e passa a ser uma referência a algo que foi construído por quem opera.

Uma consequência que convém saber: como só `prueba-sano` constrói, pedir um serviço avulso em uma máquina onde a imagem ainda não existe (por exemplo, `docker compose up prueba-lento` com o projeto recém-clonado) não tem quem a construa. Em um teste à parte com uma imagem inexistente e `pull_policy: never`, o Compose terminou com código `1` e a mensagem `No such image`. Suba o projeto completo com `docker compose up -d --build`, ou construa primeiro com `docker compose build prueba-sano`.

### 9.7 «Iniciado» não é «pronto»: `depends_on` com condição

#### 9.7.1 O que o `depends_on` faz por padrão

No primeiro arquivo foi escrito `depends_on: [prueba]`, e o `config` mostrou que isso é `condition: service_started`. A documentação é muito clara sobre o que isso significa: «Ao iniciar, o Compose não espera que um contêiner esteja "pronto", apenas que esteja rodando» ([Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/)). É a mesma confusão da Lição 7 levada à ordem de inicialização: o processo existe, mas talvez ainda não atenda.

#### 9.7.2 As três condições

A forma longa do `depends_on` aceita três condições ([referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/)):

| Condição | O Compose espera que a dependência… |
|---|---|
| `service_started` | esteja rodando (é o que a forma curta faz) |
| `service_healthy` | esteja «saudável», segundo seu `healthcheck` |
| `service_completed_successfully` | termine com sucesso (para tarefas de uso único, como preparar algo antes) |

A desta lição é `service_healthy`: «o Compose espera que passem as verificações de saúde das dependências marcadas com `service_healthy`» ([Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/)). Para isso a dependência precisa de uma verificação de saúde, e o serviço de teste a traz em sua imagem desde a Lição 2 (a cada 5 s, com 2 tentativas). É a promessa da Lição 7: a saúde não reinicia nada, mas alguém a usa. Hoje quem a usa é o Compose.

#### 9.7.3 Por que o `revisor` espera só a saudável

Aqui está a decisão mais fina do arquivo, e merece ser lida devagar. O `revisor` depende das três cópias, mas **não** com a mesma condição:

```yaml
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
```

Pense no que aconteceria se as três fossem `service_healthy`. `prueba-caido` responde `503` sempre: sua verificação de saúde **nunca** passa, então o Compose esperaria que o Docker a declarasse `unhealthy` (com 2 tentativas a cada 5 s, uns dez segundos) e então desistiria: em um teste à parte com uma dependência que sempre falha (verificação a cada 2 s, 2 tentativas), o `docker compose up -d` terminou aos 5 s com código `1` e a mensagem `dependency failed to start: container ... is unhealthy`, e o serviço que dependia dela ficou em `Created`, sem iniciar. É o mesmo erro que se verá em 9.11.3. O resultado é o mesmo: o `revisor` nunca iniciaria. E `prueba-lento` também não: sua verificação exige resposta em menos de 2 segundos, e no modo lento ele leva 3. Os serviços que falham de propósito não podem ser saudáveis, porque falhar é o trabalho deles. O que o `revisor` precisa é que eles **existam** (para que seu nome esteja no DNS) e que ao menos um esteja pronto para que o primeiro relatório tenha algo a dizer. Por isso: a saudável, `service_healthy`; as outras, `service_started`.

Essa é a regra geral, e será usada em todos os projetos: **`service_healthy` para o que o serviço precisa saudável para iniciar (um banco de dados, por exemplo), e `service_started` para o que só precisa que exista**. E um aviso honesto: `depends_on` só ordena a **inicialização**. Se uma dependência cair uma hora depois, o Compose não para nem reinicia quem dependia dela. O `revisor` lida bem com isso porque seu trabalho é justamente reportar quem não responde.

### 9.8 Segredos do Compose

#### 9.8.1 O que são e onde aparecem

Na Lição 6 o token foi montado com um `--mount type=bind` de um único arquivo, em `/run/secrets/revisor_token`, e se disse para onde apontava com `REVISOR_TOKEN_ARCHIVO`. O Compose tem um elemento para isso. Sua documentação define um segredo como «qualquer dado, como uma senha, um certificado ou uma chave de API» que não deveria trafegar sem proteção, e diz onde ele aparece: os segredos «são montados como um arquivo em `/run/secrets/<nome_do_segredo>` dentro do contêiner» ([Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/)). Por isso o `revisor` usa esse caminho desde a Lição 6: é a convenção do Compose.

Declaram-se em dois lugares, como as redes e os volumes. Em cima, de onde vem:

```yaml
secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

E no serviço, quem o recebe:

```yaml
    secrets:
      - revisor_token
```

Essa segunda parte importa: «os serviços só podem acessar os segredos quando isso lhes é concedido explicitamente com um atributo `secrets`» ([Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/)). As três cópias do serviço de teste não o recebem, e por isso não o veem. O valor nunca é escrito no arquivo: o `compose.yaml` diz **onde** está o token, não **qual** é. Assim o arquivo pode ir para o repositório e `secretos/` não: são dois arquivos de exclusão, um por destino. O `.dockerignore` o deixa fora da imagem (já faz isso desde a Lição 6) e o `.gitignore` o deixa fora do repositório (9.8.4). O material deste curso leva sua pasta `secretos/` dentro do repositório, de propósito, porque o token é de mentira; a de um projeto real, com um token de verdade, não.

#### 9.8.2 A armadilha: as permissões são as do arquivo

O que vem a seguir é o mais importante desta seção, porque é um erro que a documentação explica em uma nota e que quase ninguém lê. A forma longa de um segredo no serviço aceita `uid`, `gid` e `mode`, e parecem a solução perfeita: «que o arquivo dentro do contêiner seja do usuário 65532, com permissão `0400`». Mas **quando o segredo sai de um arquivo, o Compose os ignora**. A referência diz assim: com um arquivo como fonte, o Compose usa por baixo uma montagem que não permite mudar o dono, «e esses atributos são ignorados em silêncio»; só funcionam quando o segredo sai de uma variável de ambiente ([referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/)).

Na prática, isso quer dizer que o segredo do Compose é **a mesma montagem da Lição 6**, com o dono e as permissões que o arquivo tiver na máquina. Se o arquivo está em `600`, só o usuário da máquina o lê; o `revisor` roda como `65532`; o resultado é `permission denied` e o `revisor` sai com código 1. Se está em `644`, ele lê. Isso será provocado em 9.10, com `uid`, `gid` e `mode` declarados, para que se veja que não mudam nada. Por isso o curso usa a forma curta (`- revisor_token`): escrever `uid`, `gid` e `mode` com um segredo de arquivo só serve para dar uma falsa sensação de segurança.

A consequência prática é que **a permissão do arquivo na máquina é uma decisão de segurança tomada por quem opera**, não pelo Compose. `644` faz o `revisor` iniciar, mas também deixa qualquer outra conta da máquina ler o token. As duas seções seguintes medem isso e mostram a forma segura; a seção 6.5.4 da Lição 6 diz o mesmo, com outras palavras.

#### 9.8.3 Medir quem pode ler o token

Uma permissão como `644` são três algarismos, um para cada grupo de pessoas: o **dono** do arquivo, o **grupo** do arquivo e **todos os demais**. Cada algarismo soma `4` (ler), `2` (escrever) e `1` (executar). Assim, `644` é «o dono lê e escreve (`6 = 4 + 2`), o grupo lê (`4`) e todos os demais leem (`4`)». «Todos os demais» não é uma forma de dizer «o usuário da máquina»: é **qualquer conta da máquina**, a de outra pessoa que tenha sessão aberta em um servidor compartilhado, a de um serviço que roda com seu próprio usuário, ou a de um programa que alguém conseguiu fazer rodar como outro usuário. Com `600` só o dono lê, e com `640` leem o dono e o grupo, e mais ninguém.

Comprova-se com dois comandos. `ls -l secretos/` mostra as permissões em letras: `-rw-r--r--` é `644`, `-rw-------` é `600` e `-rw-r-----` é `640`. E `stat -c '%a %U:%G' secretos/revisor_token.txt` as mostra em número, junto com o dono e o grupo. Quando o número de um dono não corresponde a nenhuma conta da máquina (o `65532` do `revisor` não é uma conta), o `stat` escreve `UNKNOWN`; para ver o número, peça com `%u:%g` ou use `ls -ln`.

Mas olhar as permissões não é o mesmo que **testá-las**. O script `fig09_11.sh` faz as duas coisas e em cada caso pergunta o mesmo: outro usuário sem privilégios consegue lê-lo?, o usuário da máquina consegue lê-lo?, o `revisor`, que roda como `65532`, consegue lê-lo? Para «outro usuário» usa `sudo -u nobody`: `nobody` é uma conta sem privilégios que vem em todo Linux, e serve para se fazer passar por qualquer outro usuário. Antes de cada `Permission denied` do `nobody` há um controle: `sudo -u nobody stat` demonstra que o `nobody` **chega até o arquivo** (a pasta está aberta), de modo que, se o `cat` seguinte falha, é pela permissão do arquivo e não por outra coisa. (Na máquina de testes, a pasta pessoal está em `750`, e isso só barra quem tenta entrar nela; não se deve contar com isso: o projeto pode estar em outro caminho, ou alguém pode abrir a pasta algum dia.) O script precisa de `sudo`, para se fazer passar por `nobody` e para trocar o dono do arquivo. Os casos 3 e 4 seguem **exatamente** as opções B e A de 9.8.4, partindo do `644` com que se chega da Lição 6. A parte que muda, com o arquivo do token de mentira:

```bash
# La cuenta sin privilegios: «nobody» existe en todo Linux y sirve para hacerse
# pasar por «otro usuario cualquiera de tu equipo». El nombre de tu usuario y de tu
# grupo se tapa con sed, porque depende del equipo.
SUBE="docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
PS_REV="docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
STAT="stat -c '%a %U:%G' secretos/revisor_token.txt"
TAPA_TODO="sed -E 's/ .*/ <tu usuario>:<tu grupo>/'"
TAPA_DUENO="sed -E 's/ [^:]+:/ <tu usuario>:/'"
# El control de cada negativa: «nobody» sí llega hasta el archivo (la carpeta está
# abierta); si el cat siguiente falla, es por el permiso del archivo.
CONTROL="sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt"
OTRO="sudo -u nobody cat secretos/revisor_token.txt"

echo "== 1. Permisos 644, dueño tu usuario"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "$PS_REV"

echo
echo "== 2. Permisos 600, dueño tu usuario"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_TODO"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
sleep 4
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "[ \"\$(docker inspect --format '{{.RestartCount}}' ${COMPOSE_PROJECT_NAME}-revisor-1)\" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'"

echo
echo "== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala"
muestra "chmod 644 secretos/revisor_token.txt"   # el estado con el que llegas de la Lección 6
muestra "chmod 600 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "$STAT"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "sudo cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"   # el archivo vuelve a ser tuyo
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chgrp +65532 secretos/revisor_token.txt"
muestra "chmod 640 secretos/revisor_token.txt"
muestra "$STAT | $TAPA_DUENO"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'"
muestra "$CONTROL"
muestra "$OTRO"
muestra "cat secretos/revisor_token.txt"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"

echo
echo "== 5. Lo mismo, más la carpeta secretos/ cerrada con 700"
muestra "chmod 700 secretos"
muestra "stat -c '%a' secretos"
muestra "$SUBE"
esperar revisor healthy
muestra "$PS_REV"
muestra "tabla"
muestra "chmod 755 secretos"

echo
echo "== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra"
muestra "sudo chown \"\$(id -un)\" secretos/revisor_token.txt"
muestra "chmod 644 secretos/revisor_token.txt"
muestra "sudo chown 65532:65532 secretos/revisor_token.txt"
muestra "chmod 600 secretos/revisor_token.txt"
muestra "stat -c '%a %u:%g' secretos/revisor_token.txt"
muestra "$CONTROL"
muestra "$OTRO"

echo
echo "== 7. ¿El grupo 65532 es de alguien en este equipo?"
muestra "getent group 65532"
```

```text
$ ./fig09_11.sh
== 1. Permisos 644, dueño tu usuario
$ chmod 644 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
644 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)

== 2. Permisos 600, dueño tu usuario
$ chmod 600 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ .*/ <tu usuario>:<tu grupo>/'
600 <tu usuario>:<tu grupo>
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ [ "$(docker inspect --format '{{.RestartCount}}' curso-docker-fig09-revisor-1)" -ge 1 ] && echo 'el revisor se reinició: no pudo leer su token'
el revisor se reinició: no pudo leer su token

== 3. Opción B de la lección, partiendo de 644: primero se cierra y luego se regala
$ chmod 644 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt
600 UNKNOWN:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt
600 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
600 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ sudo cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200

== 4. Opción A de la lección, partiendo de 644: tu usuario, grupo 65532, 640
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chgrp +65532 secretos/revisor_token.txt
$ chmod 640 secretos/revisor_token.txt
$ stat -c '%a %U:%G' secretos/revisor_token.txt | sed -E 's/ [^:]+:/ <tu usuario>:/'
640 <tu usuario>:UNKNOWN
$ stat -c '%a %u:%g' secretos/revisor_token.txt | sed -E 's/ [0-9]+:/ <tu uid>:/'
640 <tu uid>:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
640 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
cat: secretos/revisor_token.txt: Permission denied
[código de salida: 1]
$ cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA       <t>  codigo 503
lento     LENTO     <t>  200
sano      OK          <t>  200

== 5. Lo mismo, más la carpeta secretos/ cerrada con 700
$ chmod 700 secretos
$ stat -c '%a' secretos
700
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
$ chmod 755 secretos

== 6. El orden equivocado, partiendo de 644: primero se regala y luego se cierra
$ sudo chown "$(id -un)" secretos/revisor_token.txt
$ chmod 644 secretos/revisor_token.txt
$ sudo chown 65532:65532 secretos/revisor_token.txt
$ chmod 600 secretos/revisor_token.txt
chmod: changing permissions of 'secretos/revisor_token.txt': Operation not permitted
[código de salida: 1]
$ stat -c '%a %u:%g' secretos/revisor_token.txt
644 65532:65532
$ sudo -u nobody stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ sudo -u nobody cat secretos/revisor_token.txt
curso-docker-token-de-mentira-7f3a9c

== 7. ¿El grupo 65532 es de alguien en este equipo?
$ getent group 65532
[código de salida: 2]
```

Resumo do que foi mostrado, caso a caso:

| Permissões e dono | Outro usuário consegue ler? | O usuário da máquina consegue ler? | O `revisor` consegue ler? |
|---|---|---|---|
| `644`, usuário da máquina | **sim** | sim | sim |
| `600`, usuário da máquina | não | sim | **não** (`permission denied`) |
| `600`, dono `65532` (opção B) | não | não, exceto com `sudo` | sim |
| `640`, usuário da máquina, grupo `65532` (opção A) | não | sim | sim |

1. **`644`: qualquer um lê.** O primeiro bloco é a descoberta: `sudo -u nobody cat` imprime o token completo. O `revisor` inicia saudável, e por isso `644` parece «a solução»: funciona. Mas funciona porque abre o arquivo a todos, não só ao `revisor`.
2. **`600` do usuário da máquina: fecha-se, e fecha-se também ao `revisor`.** O `nobody` recebe `Permission denied`, mas o `revisor` também: é o erro da Lição 6 e de 9.10. O arquivo é do usuário da máquina, o `revisor` é o usuário `65532`, e para o kernel o `revisor` é «outro usuário» como o `nobody`. A linha `se reinició` confirma que o `revisor` entra e sai em um laço.
3. **`600` com dono `65532` (opção B): fechado a todos, menos ao `revisor`.** Só o dono do arquivo (o `revisor`) e o `root` podem lê-lo. O `nobody` recebe `Permission denied`, e o usuário da máquina também, porque já não é o dono; para vê-lo ou mudá-lo é preciso `sudo cat`. O `revisor` chega a `(healthy)` e a tabela sai com o token. O preço: a comodidade. E o `UNKNOWN:UNKNOWN` do primeiro `stat` não é um erro: o número `65532` não tem nome de conta na máquina. Repare na **ordem**: primeiro `chmod 600` e depois `sudo chown`.
4. **`640` com grupo `65532` (opção A): a saída cômoda.** O usuário da máquina continua sendo o dono (lê e edita sem `sudo`), e o **grupo** do arquivo é o `65532`. O `revisor` roda como `65532:65532` (usuário e grupo, que vêm da imagem: `docker inspect --format '{{.Config.User}}'`), então para o kernel ele entra pelo algarismo do grupo. O `nobody` não está nesse grupo e não lê nada. É a permissão mínima que deixa as duas partes trabalharem. Vale o mesmo da Lição 6: os números de dentro e de fora devem ser os mesmos (instalação normal da Lição 1). Com Docker sem `root` ou com remapeamento de usuários, o `65532` de dentro corresponde fora a outro número (o início do intervalo em `/etc/subuid` e `/etc/subgid` mais 65532; esse início muda de uma instalação para outra, e se lê nesses arquivos. Como exemplo, a [documentação do `userns-remap`](https://docs.docker.com/engine/security/userns-remap/) conta que, com um intervalo que começa em `231072`, o `231073` é o usuário `1` de dentro; o `231072` é apenas o valor desse exemplo), e esta receita não se aplica tal como está: o `revisor` dará `permission denied`, e não há vazamento, mas também não há solução rápida; o diagnóstico é o do `ls -ln` da Lição 6.
5. **A pasta `secretos/` em `700` não atrapalha.** O bloco 5 a fecha (`chmod 700 secretos`) e o `revisor` é recriado e continua `(healthy)`: a montagem de um único arquivo é estabelecida pelo daemon, não pelo usuário da máquina. Fecha-se a pasta além do arquivo: quem não consegue entrar nela nem sequer vê que o token existe.
6. **A ordem errada deixa o token aberto.** O bloco 6 faz a opção B ao contrário: `sudo chown 65532:65532` primeiro e `chmod 600` depois. O `chmod` falha com `Operation not permitted`, porque o usuário da máquina já não é o dono e o kernel só deixa mudar as permissões ao dono (ou ao `root`). O arquivo fica em `644`, agora de `65532`, e o `nobody` imprime o token. Sempre se **fecha primeiro e se entrega depois**, e se confere no final.
7. **O grupo `65532` não é exclusivo do `revisor`.** É o usuário e grupo `nonroot` das imagens *distroless* (a imagem final do `revisor` é `gcr.io/distroless/static-debian13:nonroot`) e das da Chainguard, de modo que qualquer contêiner dessas imagens em que este arquivo for montado o lê pelo algarismo do grupo. E se na máquina existisse um grupo real com esse número, seus membros também. Por isso o último bloco pergunta `getent group 65532`: se não imprime nada (como aqui, com código de saída 2), o número não é de ninguém na máquina.

O que nenhuma permissão impede: o `root` lê tudo, e quem puder falar com o daemon do Docker (o grupo `docker` da Lição 1) pode montar a pasta em um contêiner e lê-la. Por isso se cuida de quem está nesse grupo; é outro motivo para não entregar o arquivo a «todos os demais».

#### 9.8.4 A forma segura na pasta do projeto

Há duas formas de deixar o arquivo fechado, da mais cômoda à mais estrita. As duas deixam o `revisor` ler e deixam os demais de fora. **Escolha uma**; não aplique as duas em sequência.

**Opção A**: o usuário da máquina é o dono e o grupo do `revisor` pode ler.

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt
chmod 640 secretos/revisor_token.txt
```

O `+` diz ao `chgrp` que `65532` é um número de grupo e não um nome (sem o `+`, ele também o toma como número se não existir um grupo com esse nome).

**Opção B**: o dono é o próprio `revisor`. O usuário da máquina precisa de `sudo` para lê-lo.

```bash
cd revisor
chmod 600 secretos/revisor_token.txt               # primero se cierra, mientras aún eres el dueño
sudo chown 65532:65532 secretos/revisor_token.txt  # después se regala; ya no podrás cambiarlo sin sudo
```

A ordem importa: se se entrega primeiro, o `chmod` falha e o arquivo fica como estava (bloco 6 de 9.8.3).

Seja qual for a escolhida, **confira sempre**:

```bash
ls -l secretos/revisor_token.txt
stat -c '%a %U:%G' secretos/revisor_token.txt
sudo -u nobody cat secretos/revisor_token.txt   # debe decir: Permission denied
chmod 700 secretos                              # y cierra también la carpeta
```

Depois, `docker compose up -d --force-recreate revisor` (mudar a permissão de um arquivo não é uma mudança de configuração para o Compose, e o `revisor` só lê seu token ao iniciar).

**As cópias também contam.** Cada cópia do token nasce com suas próprias permissões: um `cp` sem `-p` deixa o arquivo em nome de quem copiou, com seu grupo e seu `umask`; e a cópia de segurança de um editor (`revisor_token.txt~`), o backup da pasta pessoal ou uma cópia para um pendrive USB ou para a nuvem não conservam o `640`. Confira-as com o mesmo `stat`, ou não as faça.

**Para criar um segredo novo**, que ele nasça fechado em vez de ser aberto e fechado depois. Veja o `umask` com `umask`: é a «subtração» de permissões que o sistema aplica a todo arquivo novo. No Ubuntu e no Linux Mint costuma valer `0002` (medido na máquina de testes, Ubuntu 24.04), e um arquivo novo sai em `664`: qualquer um lê, igual a `644`. O `644` visto na Lição 6 não foi posto pelo `umask`: foi posto pelo `chmod` do curso. Duas formas de criar um arquivo fechado:

```bash
install -m 600 /dev/null secretos/token.txt                              # crea el archivo vacío, ya en 600
(umask 077; read -rs VALOR; printf '%s' "$VALOR" > secretos/token2.txt)  # pegas el valor sin que se vea
```

Três avisos. As duas formas são para um arquivo que **ainda não existe**: se já existe, o `umask` não muda sua permissão (feche-o com `chmod 600`) e o `install` o substitui por um vazio, sem avisar. As duas o deixam em `600` **em nome de quem o criou**, que é o caso 2 de 9.8.3: o `revisor` ainda não consegue lê-lo, então termine com a opção A ou a B. E **não escreva o valor na linha de comando** (`VALOR=... ` ou `echo ... >`): ele fica no histórico do terminal; por isso o exemplo usa `read -rs`, ou cole-o a partir de um editor.

**E quando sim `644`?** Somente em uma situação: um token de mentira, em um computador que é só de quem estuda, para uma prática. Os scripts desta lição o usam dentro de uma pasta temporária que é apagada ao terminar, e por isso o deixam em `644`. Três avisos, sem letras miúdas:

- **O token do curso é fictício** (`curso-docker-token-de-mentira-7f3a9c`); não abre nada.
- **`644` deixa qualquer conta local lê-lo**, como acaba de ser medido.
- **Nunca use `644` com um segredo real**: nem no notebook, nem em um servidor, nem «só um instantinho enquanto testo».

E a outra metade da higiene do segredo: **que ele não chegue ao repositório**. No projeto, `secretos/` vai no `.gitignore` desde o primeiro dia, e se confere:

```bash
echo 'secretos/' >> .gitignore
git check-ignore -v secretos/revisor_token.txt
```

```text
.gitignore:1:secretos/	secretos/revisor_token.txt
```

Se o `git check-ignore` não imprime nada, o arquivo **não** está ignorado. (Uma exceção: se o `git` já acompanha o arquivo desde antes de ele ser ignorado, o `.gitignore` não o solta; retira-se com `git rm --cached` e o token já publicado é dado por perdido e trocado, como na Lição 6.) O que já foi visto do Compose em 9.8.1 fica assim: o `compose.yaml` diz onde está o token, o `.gitignore` o mantém fora do repositório, o `.dockerignore` o mantém fora da imagem, e a permissão do arquivo o mantém fora do alcance do resto da máquina.

### 9.9 O arquivo final

#### 9.9.1 Tudo junto

Este é o `compose.yaml` com que a lição termina. Ele substitui o primeiro na pasta `revisor/`; é o mesmo que guarda `estado/compose.yaml`:

```yaml
# fig09_04.compose.yaml — el compose.yaml final de la Lección 9. Va en tu carpeta
# revisor/ como compose.yaml (es el mismo que guarda estado/compose.yaml).
#
# Lección 9 — el sistema completo: el revisor y tres copias del servicio de
# prueba (sana, lenta y caída), con todo lo que se endureció en las lecciones 2 a 8.
#
# Sin «version:» a propósito: la especificación de Compose ya no la usa.
name: curso-docker

# Lo común a las tres copias del servicio de prueba, escrito una sola vez.
# Compose ignora los campos que empiezan con «x-»; sirven para anclas de YAML.
# Solo prueba-sano lleva «build»: si las tres construyeran la misma etiqueta a la
# vez, chocarían («image ... already exists»). Las otras dos usan la imagen que
# construye la primera y nunca la buscan en internet (pull_policy: never).
x-prueba: &prueba
  image: curso-docker-prueba:1.0.0
  pull_policy: never
  networks: [interna]
  read_only: true
  cap_drop: [ALL]
  security_opt: ["no-new-privileges:true"]
  init: true
  mem_limit: 32m
  cpus: 0.25
  pids_limit: 20

services:
  revisor:
    build:
      context: .
      args:
        VERSION: "1.5.0"
    image: curso-docker-revisor:1.5.0
    environment:
      REVISOR_SERVICIOS: >-
        sano http://prueba-sano:9000/ 2s,
        lento http://prueba-lento:9000/ 5s,
        caido http://prueba-caido:9000/ 2s
      REVISOR_TOKEN_ARCHIVO: /run/secrets/revisor_token
    secrets:
      - revisor_token
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - reportes:/datos
    networks:
      - publica
      - interna
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
    restart: unless-stopped

  prueba-sano:
    <<: *prueba
    build: ../servicio-prueba
    environment:
      PRUEBA_MODO: sano

  prueba-lento:
    <<: *prueba
    environment:
      PRUEBA_MODO: lento

  prueba-caido:
    <<: *prueba
    environment:
      PRUEBA_MODO: caido

networks:
  publica: {}
  interna:
    internal: true

volumes:
  reportes: {}

secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

O que mudou em relação ao primeiro, serviço por serviço:

- **`x-prueba`**: o bloco comum das três cópias (9.6), com as mesmas opções reforçadas do `revisor`, `init: true` incluído. Levam limites menores (32 MB e um quarto de CPU), porque quase não fazem nada.
- **`revisor`**: três serviços em `REVISOR_SERVICIOS`, o token como segredo com `REVISOR_TOKEN_ARCHIVO` apontando para `/run/secrets/revisor_token`, `depends_on` com suas condições (9.7), e `restart: unless-stopped`, a política que a Lição 7 escolheu para o `revisor`.
- **`prueba-sano`, `prueba-lento`, `prueba-caido`**: a âncora mais seu modo. Só a saudável constrói.
- **Em cima**: as mesmas redes e o mesmo volume, mais o segredo.

Um detalhe de YAML em `REVISOR_SERVICIOS`: o `>-` é um **bloco dobrado**. O YAML junta as três linhas em uma, com um espaço onde havia quebras de linha, e o `-` remove a quebra do final. Assim cada serviço fica em sua própria linha do arquivo, fácil de ler e de mudar, e o `revisor` recebe uma única cadeia separada por vírgulas, que é o que ele espera. O bloco 5 da execução seguinte mostra o valor tal como chegou ao contêiner.

#### 9.9.2 Vê-lo funcionar

O script `fig09_05.sh` o sobe do zero e o examina por dentro. A parte que muda:

```bash
echo "== 1. Validar"
muestra "docker compose config --quiet && echo 'compose.yaml válido'"
muestra "docker compose config --services"
muestra "docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'"

echo
echo "== 2. Levantar todo desde cero"
muestra "docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'"
esperar revisor healthy
muestra "docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 3. El reporte: sin token, 401; con token, la tabla"
muestra "curl -s -w ' [%{http_code}]\n' http://127.0.0.1:${PUERTO}/api/estados"
muestra "tabla"

echo
echo "== 4. Lo que creó Compose, todo con el nombre del proyecto"
muestra "docker network ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}} interna={{.Internal}}' | sort"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 5. El token no está a la vista"
muestra "docker inspect ${COMPOSE_PROJECT_NAME}-revisor-1 | grep -c \"\$TOKEN\""
muestra "docker compose config | grep -c \"\$TOKEN\""
muestra "docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1 | grep REVISOR_"
muestra "docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
```

```text
$ ./fig09_05.sh
== 1. Validar
$ docker compose config --quiet && echo 'compose.yaml válido'
compose.yaml válido
$ docker compose config --services
prueba-caido
prueba-lento
prueba-sano
revisor
$ docker compose config | sed -n '/^  prueba-lento:/,/^  prueba-sano:/p' | grep -E '^    (image|pull_policy|read_only|mem_limit|networks):|PRUEBA_MODO'
      PRUEBA_MODO: lento
    image: curso-docker-prueba:fig09
    mem_limit: "33554432"
    networks:
    pull_policy: never
    read_only: true

== 2. Levantar todo desde cero
$ docker compose up -d --build 2>&1 | eventos | grep -vE 'Building|Creating|Starting'
Image curso-docker-revisor:fig09 Built
Image curso-docker-prueba:fig09 Built
Network curso-docker-fig09_publica Created
Network curso-docker-fig09_interna Created
Volume curso-docker-fig09_reportes Created
Container curso-docker-fig09-prueba-caido-1 Created
Container curso-docker-fig09-prueba-sano-1 Created
Container curso-docker-fig09-prueba-lento-1 Created
Container curso-docker-fig09-revisor-1 Created
Container curso-docker-fig09-prueba-caido-1 Started
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-sano-1 Waiting
Container curso-docker-fig09-prueba-sano-1 Healthy
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps --format '{{.Name}} | {{.Status}} | {{.Ports}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-prueba-caido-1 | Up N (unhealthy) | 9000/tcp
curso-docker-fig09-prueba-lento-1 | Up N (health: starting) | 9000/tcp
curso-docker-fig09-prueba-sano-1 | Up N (healthy) | 9000/tcp
curso-docker-fig09-revisor-1 | Up N (healthy) | 127.0.0.1:8080->8080/tcp

== 3. El reporte: sin token, 401; con token, la tabla
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados
{"error":"falta el token o no es válido"}
 [401]
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200

== 4. Lo que creó Compose, todo con el nombre del proyecto
$ docker network ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}} interna={{.Internal}}' | sort
curso-docker-fig09_interna interna=true
curso-docker-fig09_publica interna=false
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} Init={{.HostConfig.Init}} Memory={{.HostConfig.Memory}} User={{.Config.User}} Restart={{.HostConfig.RestartPolicy.Name}}' curso-docker-fig09-revisor-1
ReadonlyRootfs=true CapDrop=[ALL] Init=true Memory=67108864 User=65532:65532 Restart=unless-stopped

== 5. El token no está a la vista
$ docker inspect curso-docker-fig09-revisor-1 | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker compose config | grep -c "$TOKEN"
0
[código de salida: 1]
$ docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-fig09-revisor-1 | grep REVISOR_
REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token
REVISOR_SERVICIOS=sano http://prueba-sano:9000/ 2s, lento http://prueba-lento:9000/ 5s, caido http://prueba-caido:9000/ 2s
REVISOR_PUERTO=8080
REVISOR_REPORTE=/datos/reporte.json
$ docker inspect --format '{{range .Mounts}}{{.Type}} {{.Destination}} ro={{not .RW}}{{println}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true
volume /datos ro=false
```

#### 9.9.3 Ler a execução

1. **Validar.** Quatro serviços. E o serviço `prueba-lento`, lido pelo `config`, traz `image`, `pull_policy: never`, `read_only`, `mem_limit` (32 MB, em bytes) e `networks`, que vieram da âncora. A âncora funciona.
2. **Subir.** Repare na ordem dos eventos, que é o centro desta lição. As duas imagens são construídas (apenas duas, embora haja quatro serviços), criam-se redes, volume e os quatro contêineres. As três cópias do serviço de teste iniciam. E então aparecem `prueba-sano-1 Waiting` e `prueba-sano-1 Healthy`: o Compose **esperou** que a saudável passasse sua verificação de saúde, e só depois iniciou o `revisor`. É o `service_healthy` funcionando. A ordem em que as três cópias iniciam pode mudar de uma execução para outra, porque elas iniciam ao mesmo tempo.
3. **`ps`.** O estado de saúde conta a história completa: `prueba-caido` está `(unhealthy)`, que é seu trabalho; `prueba-lento` está `(health: starting)` e vai terminar `unhealthy` (leva 3 s e sua verificação exige menos de 2); `prueba-sano` e o `revisor`, `(healthy)`. Quatro contêineres `Up`, e apenas dois saudáveis: o segundo critério do curso, em uma única tabela.
4. **O relatório.** Sem token, `401` com a mensagem do `revisor`: o segredo chegou e o `revisor` o está exigindo. Com o token, a tabela com os três estados: `FALLA` com `codigo 503`, `LENTO` (respondeu `200`, mas em mais de um segundo) e `OK`. Essa é a meta do curso.
5. **O que o Compose criou.** Duas redes, a interna com `interna=true`; um volume; e o `revisor` com todo o reforço da Lição 7 aplicado pelo daemon: sistema de arquivos somente leitura, `CapDrop=[ALL]`, `Init=true`, 64 MB, usuário `65532:65532` (que vem da imagem) e a política de reinício.
6. **O token não está à vista.** O `grep -c` conta zero vezes o valor do token em todo o `docker inspect` e em todo o `docker compose config` (o `[código de salida: 1]` é do `grep`, que sai com 1 quando não encontra nada: aqui, essa é a boa notícia). O ambiente do contêiner tem `REVISOR_TOKEN_ARCHIVO`, que é um **caminho**, não um valor. E as montagens mostram o que um segredo de arquivo é por dentro: um `bind` somente leitura (`ro=true`) em `/run/secrets/revisor_token`, junto ao `volume` de `/datos`. A terceira meta do curso («nenhum segredo aparece no `docker history`, no `docker inspect` nem nas variáveis de ambiente do contêiner») é cumprida, em sua parte de execução, com o sistema completo.

#### 9.9.4 Na pasta do projeto

Com o arquivo final em `revisor/compose.yaml`, `servicio-prueba/` ao lado e `secretos/revisor_token.txt` com permissões `640` e grupo `65532` (9.8.4):

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt   # el grupo del revisor puede leerlo...
chmod 640 secretos/revisor_token.txt          # ...y ningún otro usuario (9.8.4)
docker compose config --quiet && echo 'compose.yaml válido'
docker compose up -d --build
docker compose ps
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" 'http://127.0.0.1:8080/api/estados?formato=tabla'
```

Uma nota sobre esse `curl`: enquanto ele roda, o token vai em sua linha de comando e qualquer conta pode vê-lo com `ps`, mesmo que o arquivo esteja em `640`. Com o token de mentira não importa; com um real, passe-o a partir de um arquivo de cabeçalhos (`curl -H @cabeceras.txt`, que deve ter suas próprias permissões fechadas).

Os scripts desta lição usam `644` em uma pasta temporária, com o token de mentira; a pasta do projeto não precisa disso. Com `644`, qualquer usuário do computador pode ler o token (9.8.3), e em um servidor compartilhado isso não se aceita: a correção é o grupo ou o dono correto (seção 6.5.4 da Lição 6), não abri-lo a todos.

Os nomes serão `curso-docker-revisor-1`, `curso-docker-prueba-sano-1` e assim por diante, com redes `curso-docker_publica` e `curso-docker_interna` e o volume `curso-docker_reportes`. Se a Lição 8 deixou rodando `curso-docker-revisor` com a porta 8080, desligue-o antes (`docker rm -f curso-docker-revisor curso-docker-prueba`), ou o `up` esbarrará na porta ocupada da Lição 2. E se o volume `curso-docker-reportes` da Lição 8 foi conservado, ele não atrapalha: o do Compose é outro, `curso-docker_reportes`, com sublinhado.

### 9.10 O erro que mais vai custar: o segredo em `600`

#### 9.10.1 Provocá-lo com `uid`, `gid` e `mode` escritos

O script `fig09_06.sh` pega o arquivo final, muda o segredo para a forma longa com `uid: "65532"`, `gid: "65532"` e `mode: 0400` (o que «deveria» resolver a permissão), põe o arquivo do token em `600` e sobe. Depois o corrige com `644`, que é o que seus scripts usam em sua pasta temporária com o token de mentira (na pasta do projeto, a correção é a de 9.8.4). A parte que muda:

```bash
cp compose.yaml compose.final.yaml

echo "== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600"
python3 - <<'PY'
s = open("compose.yaml").read()
s = s.replace("""    secrets:
      - revisor_token
""", """    secrets:
      - source: revisor_token
        uid: "65532"
        gid: "65532"
        mode: 0400
""")
open("compose.yaml", "w").write(s)
PY
chmod 600 secretos/revisor_token.txt
muestra "diff compose.final.yaml compose.yaml"
muestra "stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
sleep 3
muestra "docker compose logs --no-log-prefix revisor | sort -u"
muestra "docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker inspect --format '{{range .Mounts}}{{if eq .Destination \"/run/secrets/revisor_token\"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' ${COMPOSE_PROJECT_NAME}-revisor-1"

echo
echo "== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)"
cp compose.final.yaml compose.yaml
chmod 644 secretos/revisor_token.txt   # 644: solo porque el token es de mentira (9.8.4)
muestra "stat -c '%a %n' secretos/revisor_token.txt"
muestra "docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'"
esperar revisor healthy
muestra "docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"
muestra "tabla"
```

```text
$ ./fig09_06.sh
== 1. El secreto en forma larga, con uid, gid y mode; el archivo en 600
$ diff compose.final.yaml compose.yaml
41c41,44
<       - revisor_token
---
>       - source: revisor_token
>         uid: "65532"
>         gid: "65532"
>         mode: 0400
[código de salida: 1]
$ stat -c '%a %u:%g %n' secretos/revisor_token.txt | sed -E 's/ [0-9]+:[0-9]+ / <tu usuario> /'
600 <tu usuario> secretos/revisor_token.txt
$ docker compose up -d --build 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose logs --no-log-prefix revisor | sort -u
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker inspect --format '{{range .Mounts}}{{if eq .Destination "/run/secrets/revisor_token"}}{{.Type}} {{.Destination}} ro={{not .RW}}{{end}}{{end}}' curso-docker-fig09-revisor-1
bind /run/secrets/revisor_token ro=true

== 2. El arreglo: 644 (y el compose.yaml de la lección, en forma corta)
$ stat -c '%a %n' secretos/revisor_token.txt
644 secretos/revisor_token.txt
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 (Started|Error)'
Container curso-docker-fig09-revisor-1 Started
$ docker compose ps revisor --format '{{.Name}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
curso-docker-fig09-revisor-1 | Up N (healthy)
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.10.2 Lê-lo

1. **O `diff`** mostra a forma longa, e o `stat` mostra o arquivo em `600`, do usuário da máquina (o número é ocultado porque depende da máquina).
2. **`Started`.** O Compose diz que o `revisor` iniciou, e é verdade: o processo iniciou. Mas os logs contam o resto: `leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied`. O `revisor` não conseguiu ler seu token e preferiu morrer com código 1 a ficar escutando sem proteção (Lição 6). O `sort -u` do script junta as linhas repetidas, porque a mensagem sai uma vez por tentativa.
3. **`Status=restarting ExitCode=1`.** Tentativas? Sim: o arquivo final leva `restart: unless-stopped`, então o daemon o inicia de novo cada vez que ele morre, com esperas cada vez mais longas, e cada vez ele morre igual. Isto é o que se verá em um sistema real quando um segredo tem as permissões erradas: um contêiner que entra e sai, e um `docker compose ps` que diz `Restarting`. A política de reinício trata da morte do processo, como se viu na Lição 7; não pode consertar a causa.
4. **A montagem.** O segredo é um `bind` somente leitura, com `uid`, `gid` e `mode` declarados e tudo. Os três atributos não fizeram nada. É exatamente o que a referência diz, medido.
5. **A correção do script**: `644` e o arquivo da lição, com a forma curta. É a correção mais curta, não a melhor: abre o token a toda a máquina (9.8.3). Na pasta do projeto, use a de 9.8.4. `--force-recreate revisor` pede ao Compose que recrie esse serviço mesmo que sua configuração seja a mesma do contêiner existente; aqui é necessário porque a única coisa que mudou foi a permissão de um arquivo na máquina, e isso o Compose não compara. O `revisor` chega a `(healthy)` e a tabela volta.

Se isso acontecer na pasta do projeto: `ls -l secretos/`, e se disser `-rw-------`, dê leitura **somente** ao grupo do `revisor` (`sudo chgrp +65532 secretos/revisor_token.txt` e `chmod 640 secretos/revisor_token.txt`, 9.8.4) e `docker compose up -d --force-recreate revisor`. `chmod 644` também resolve, mas deixa o token à vista de toda a máquina: só com um token de mentira. O que **não** é uma correção: tirar o `USER` da imagem ou pôr `user: "0"` no serviço para que o `root` o leia. Isso troca um problema de permissões de um arquivo por um contêiner inteiro rodando como `root`.

### 9.11 Dois erros do Compose que convém conhecer antes

O script `fig09_07.sh` provoca os dois erros próprios deste arquivo e mede o que acontece sem `pull_policy: never` (a pergunta que ficou aberta em 9.6.3). A parte que muda:

```bash
cp compose.yaml compose.final.yaml

echo "== 1. Las tres copias del servicio de prueba con «build»"
# Pone «build» en el ancla común (las tres copias la heredan) y quita la de prueba-sano.
sed -i -e 's|^  image: \(.*prueba:fig09\)$|  build: ../servicio-prueba\n  image: \1|' \
       -e '/^    build: ..\/servicio-prueba$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
# Es una carrera: a veces una de las tres termina antes de que empiecen las otras
# y no choca. Por eso se intenta cinco veces, borrando la etiqueta entre una y otra.
for i in 1 2 3 4 5; do
  docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1
  echo "-- intento $i"
  muestra "docker compose build >build.log 2>&1; echo \"build salió con \$?\"; grep -h '^target' build.log || true"
done
docker rmi -f "${PREFIJO}prueba:fig09" >/dev/null 2>&1

echo
echo "== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir"
cp compose.final.yaml compose.yaml
sed -i '/^  pull_policy: never$/d' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'"
docker compose down --remove-orphans >/dev/null 2>&1

echo
echo "== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar"
cp compose.final.yaml compose.yaml
docker compose build >/dev/null 2>&1
inicio=$(date +%s)
muestra "docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1"
echo "(tardó $(( $(date +%s) - inicio )) s)"
muestra "docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1"
muestra "docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'"

echo
echo "== 4. Lo que sí funciona: up -d y esperar la salud del revisor"
esperar revisor healthy && echo "revisor: healthy"
muestra "tabla"
```

```text
$ ./fig09_07.sh
== 1. Las tres copias del servicio de prueba con «build»
$ diff compose.final.yaml compose.yaml
15a16
>   build: ../servicio-prueba
67d67
<     build: ../servicio-prueba
[código de salida: 1]
-- intento 1
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 2
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0
-- intento 3
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 4
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 1
target prueba-lento: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
-- intento 5
$ docker compose build >build.log 2>&1; echo "build salió con $?"; grep -h '^target' build.log || true
build salió con 0

== 2. Sin «pull_policy: never», con la imagen de prueba todavía sin construir
$ diff compose.final.yaml compose.yaml
17d16
<   pull_policy: never
[código de salida: 1]
$ docker compose up -d --build 2>&1 | eventos | grep -E '^Image .*prueba'
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Pulling
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Error pull access denied for curso-docker-prueba, repository does not exist or may require 'docker login'
Image curso-docker-prueba:fig09 Building
Image curso-docker-prueba:fig09 Built

== 3. --wait espera a que TODOS estén sanos, y prueba-caido no lo va a estar
$ docker compose up -d --wait --wait-timeout 60 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
(tardó 11 s)
$ docker compose up -d --wait --wait-timeout 60 revisor 2>&1 | tail -1
container curso-docker-fig09-prueba-caido-1 is unhealthy
[código de salida: 1]
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (health: starting)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)

== 4. Lo que sí funciona: up -d y esperar la salud del revisor
revisor: healthy
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK           <t>  200
```

#### 9.11.1 Três construções da mesma tag

Com `build` na âncora, os três serviços de teste constroem a mesma imagem com o mesmo nome, e o Compose lança as três construções **ao mesmo tempo**. As três terminam com a mesma imagem e as três tentam dar o mesmo nome a ela no final; a que chega depois encontra o nome ocupado: `target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists`, e o `build` sai com `1`. Repare em duas coisas. A primeira: o serviço que reporta o choque pode ser qualquer um dos três, conforme qual termine depois; nesta execução foi `prueba-sano` nas tentativas 1 e 3, e `prueba-lento` na 4. A segunda: nas tentativas 2 e 5 **não** houve choque, e o `build` saiu com `0`. É uma corrida (*race condition*), e às vezes ela é ganha: nesta execução falhou em 3 de 5 tentativas. Um erro que aparece «às vezes» é pior que um que aparece sempre, porque faz acreditar que foi consertado quando só se teve sorte.

A causa é de projeto, não de sorte: **uma imagem se constrói uma vez e se usa muitas**. Por isso o arquivo final põe `build` em um único serviço e `pull_policy: never` nos outros dois (9.6.3). No terminal, a mensagem completa vem precedida dos passos do BuildKit; procure a linha que começa com `target`, que diz em que serviço falhou.

#### 9.11.2 Sem `pull_policy: never`

O bloco 2 remove a linha `pull_policy: never` da âncora (o `diff` a mostra) e sobe com a imagem do serviço de teste ainda sem construir (o bloco 1 a apagou no final). Os eventos da imagem contam o que foi dito em 9.6.3: dois `Pulling` e dois `Error pull access denied`, um para cada serviço que **não** constrói a imagem (`prueba-lento` e `prueba-caido`) e que, sem `never`, primeiro a buscam no Docker Hub. Depois, `Building` e `Built`: o Compose vê que outro serviço do projeto constrói essa mesma imagem, deixa o erro passar e segue. O sistema inicia igual. Por isso `pull_policy: never` não é para que funcione, e sim para que **não pergunte**: sem a linha, a inicialização depende de que no Docker Hub não exista algo com esse nome, e enche o terminal de erros que é preciso aprender a ignorar, que é o pior costume que se pode ter diante de um erro.

#### 9.11.3 `--wait` com um serviço que falha de propósito

O `docker compose up --wait` existe para scripts e para integração contínua: segundo sua referência, espera que os serviços estejam «rodando ou saudáveis», e implica o modo separado; `--wait-timeout` fixa quantos segundos esperar no máximo ([referência do `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Parece perfeito para esperar o `revisor`, mas veja o bloco 3: `container curso-docker-fig09-prueba-caido-1 is unhealthy`, código `1`, em onze segundos segundo o próprio script (`tardó 11 s`). O `--wait` espera **todos** os serviços com verificação de saúde, e `prueba-caido` nunca vai estar saudável; assim que o Docker o marca `unhealthy`, o `--wait` desiste. E nomear apenas o `revisor` (`up --wait revisor`) dá o mesmo erro: para subir o `revisor`, o Compose sobe suas dependências, e espera também por elas.

Repare no `ps` de depois: o sistema ficou **no ar** e funcionando, com o `revisor` `(healthy)`. O `--wait` não desfez nada; apenas reportou com um código diferente de 0 que nem tudo está saudável. Em um sistema de verdade isso é justamente o que se quer saber. Neste, onde um serviço está fora do ar de propósito, o curso usa `up -d` e depois espera a saúde do **`revisor`** com `docker inspect`, que é o que a função `esperar` dos scripts faz. O bloco 4 demonstra isso, e a tabela sai completa.

### 9.12 O ciclo de vida: mudar, desligar, conservar

O script `fig09_08.sh` sobe o sistema final, pede um relatório para que haja algo guardado, e depois percorre o que será feito todos os dias. A parte que muda:

```bash
cp compose.yaml compose.final.yaml
docker compose up -d --build >/dev/null 2>&1
esperar revisor healthy
curl -s -o /dev/null -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:${PUERTO}/api/estados"

echo "== 1. Cambiar un servicio: prueba-caido pasa a modo sano"
sed -i '/^  prueba-caido:/,/^[a-z]/s/PRUEBA_MODO: caido/PRUEBA_MODO: sano/' compose.yaml
muestra "diff compose.final.yaml compose.yaml"
muestra "docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'"
esperar prueba-caido healthy
muestra "tabla"
cp compose.final.yaml compose.yaml
docker compose up -d >/dev/null 2>&1

echo
echo "== 2. down sin --volumes: el reporte sigue ahí, en su volumen"
muestra "docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}'"
muestra "docker run --rm -v ${COMPOSE_PROJECT_NAME}_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'"
docker compose up -d >/dev/null 2>&1
esperar revisor healthy

echo
echo "== 3. Apagado ordenado"
inicio=$(date +%s%3N); docker compose stop revisor >/dev/null 2>&1; fin=$(date +%s%3N)
echo "docker compose stop revisor tardó $(( fin - inicio )) ms"
muestra "docker inspect --format 'ExitCode={{.State.ExitCode}}' ${COMPOSE_PROJECT_NAME}-revisor-1"
muestra "docker compose logs --no-log-prefix revisor | tail -2"

echo
echo "== 4. down --volumes: ahora sí, también el reporte"
muestra "docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'"
muestra "docker volume ls --filter label=com.docker.compose.project=${COMPOSE_PROJECT_NAME} --format '{{.Name}}' | wc -l"
```

```text
$ ./fig09_08.sh
== 1. Cambiar un servicio: prueba-caido pasa a modo sano
$ diff compose.final.yaml compose.yaml
79c79
<       PRUEBA_MODO: caido
---
>       PRUEBA_MODO: sano
[código de salida: 1]
$ docker compose up -d 2>&1 | eventos | grep -vE 'Creating|Starting|Stopping|Removing|Waiting|Healthy'
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-prueba-caido-1 Recreate
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-caido-1 Started
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     OK            <t>  200
lento     LENTO     <t>  200
sano      OK            <t>  200

== 2. down sin --volumes: el reporte sigue ahí, en su volumen
$ docker compose down 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Network curso-docker-fig09_interna Removed
Network curso-docker-fig09_publica Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}'
curso-docker-fig09_reportes
$ docker run --rm -v curso-docker-fig09_reportes:/datos:ro alpine:3.24.2 ls -ln /datos | sed -E 's/[A-Z][a-z]{2} [ 0-9]{2} [0-9:]{5}/<fecha>/'
total 4
-rw-------    1 65532    65532          269 <fecha> reporte.json

== 3. Apagado ordenado
docker compose stop revisor tardó 203 ms
$ docker inspect --format 'ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
ExitCode=0
$ docker compose logs --no-log-prefix revisor | tail -2
revisor: recibí terminated, apagando
revisor: apagado limpio

== 4. down --volumes: ahora sí, también el reporte
$ docker compose down --volumes 2>&1 | eventos | grep -E '^(Volume|Network) .* Removed'
Volume curso-docker-fig09_reportes Removed
Network curso-docker-fig09_publica Removed
Network curso-docker-fig09_interna Removed
$ docker volume ls --filter label=com.docker.compose.project=curso-docker-fig09 --format '{{.Name}}' | wc -l
0
```

1. **Mudar um serviço.** O arquivo passa `prueba-caido` ao modo saudável e pede-se `up -d`. O Compose deixa três contêineres em `Running` e **recria só o `prueba-caido`**. Nem sequer o `revisor`, que depende dele, é tocado: sua configuração não mudou, e seu `depends_on` não pede reinício quando uma dependência muda (existe a opção `restart: true` dentro de `depends_on` para isso; a documentação a descreve para um serviço que deve se reconectar quando seu banco de dados é recriado, e o `revisor` não precisa dela porque abre uma conexão nova a cada verificação) ([Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/)). A tabela seguinte diz `caido OK 200`: o nome do serviço continua sendo `caido`, mas agora ele responde saudável. É o modelo do Compose em um exemplo: descreve-se o estado desejado, e a ferramenta calcula a mudança mínima. O script devolve o arquivo à sua forma final antes de seguir.
2. **`down` sem `--volumes`.** Apagam-se contêineres e redes; o volume continua no `docker volume ls`. O auxiliar de `alpine` da Lição 8 o lê como somente leitura e ali está o `reporte.json`, de `65532`, com suas permissões `600` (o `revisor` o cria assim: o relatório é de quem o escreve). Quando o script pede `up -d` de novo, o `revisor` novo monta o mesmo volume. É a quinta meta do curso, «o relatório sobrevive», agora com o sistema completo.
3. **Desligamento ordenado.** `docker compose stop revisor` leva menos de um segundo (nesta execução, 203 ms) e o `revisor` termina com `ExitCode=0`. Seus logs contam: `recibí terminated, apagando` e `apagado limpio`. O `stop` usa por baixo o mesmo `SIGTERM` e o mesmo prazo de 10 s do `docker stop` da Lição 7; o `init: true` e o handler do `revisor` fazem o resto.
4. **`down --volumes`.** Agora sim o volume vai embora, e com ele o relatório. Use quando realmente se quiser começar do zero, sabendo que não há lixeira.

### 9.13 E o `docker init`?

O plano do curso pedia comparar o arquivo escrito com o que o `docker init` gera, um comando que cria um `Dockerfile`, um `.dockerignore`, um `compose.yaml` e um `README.Docker.md` a partir de um modelo por linguagem (Go, Python, Node, Java, Rust e outras) ([referência do `docker init`](https://docs.docker.com/reference/cli/docker/init/)). A primeira frase dessa mesma página é a que importa aqui: «O Docker Desktop fornece o comando `docker init`». Não faz parte do Docker Engine, que é o que foi instalado no Mint na Lição 1. O script `fig09_09.sh` confere isso (não cria nada, então não precisa da abertura dos demais):

```bash
#!/usr/bin/env bash
# fig09_09.sh — docker init es una función de Docker Desktop: en Docker Engine,
# el que instalaste en la Lección 1, el comando no existe. No crea nada.
set -uo pipefail
echo "\$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'"
docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
echo "\$ docker compose version"
docker compose version
echo "\$ docker init"
docker init 2>&1
echo "[código de salida: $?]"
```

```text
$ ./fig09_09.sh
$ docker version --format 'Cliente: {{.Client.Version}}  Daemon: {{.Server.Version}}'
Cliente: 29.2.1  Daemon: 29.2.1
$ docker compose version
Docker Compose version v5.0.2
$ docker init
docker: unknown command: docker init

Run 'docker --help' for more information
[código de salida: 1]
```

Assim, o curso não depende dele, e a comparação é feita com o que a documentação oficial mostra. O guia do Docker para colocar uma aplicação Python em contêiner começa com este `compose.yaml` de um único serviço (aqui sem seus comentários de cabeçalho) ([Docker, «Containerize a Python application»](https://docs.docker.com/guides/python/containerize/)):

```yaml
services:
  server:
    build:
      context: .
    ports:
      - 8000:8000
```

É um bom ponto de partida, e um arquivo muito diferente do escrito neste curso. O Exercício 4 pede para encontrar as diferenças, uma por uma, e dizer que lição do curso explica cada uma. Um gerador poupa de escrever; não poupa de entender o que ele escreveu. Se algum dia o `docker init` for usado em uma máquina com Docker Desktop, leia o `compose.yaml` gerado com `docker compose config` e passe-o pela lista do hábito de segurança desta lição antes de usá-lo.

### 9.14 O que se encontra em tutoriais antigos

- **`docker-compose`, com hífen.** É o Compose «V1», um programa à parte escrito em Python. O Docker o declara aposentado: «o Compose v1 já não recebe manutenção, e os usuários devem migrar para o Compose v2» ([Docker, «Retired features»](https://docs.docker.com/retired/)). Hoje é `docker compose`, com espaço. Se um tutorial diz `docker-compose up`, traduza-o.
- **Nomes de contêiner com sublinhado**, como `projeto_web_1`. Eram os da V1. O anúncio do Compose V2 diz assim: os nomes de contêiner «agora usam hífens como separadores em vez de sublinhados», e se um script depende desses nomes, vai quebrar; por isso recomenda, em geral, não depender dos nomes dos contêineres ([Docker, «Announcing Compose V2 General Availability»](https://www.docker.com/blog/announcing-compose-v2-general-availability/)). Se um script antigo busca `curso-docker_revisor_1` (o nome que teria na V1 o `curso-docker-revisor-1` desta lição), não o vai encontrar.
- **`version: "3.8"`** (ou `"2"`, ou `"3"`) no início do arquivo. Obsoleto; só produz um aviso (9.2.3).
- **`docker-compose.yml`** como nome de arquivo. Ainda é aceito por compatibilidade, mas o preferido é `compose.yaml`.
- **`links:`** dentro de um serviço. É o `--link` da Lição 8 em forma de chave; nas redes de um projeto, os serviços já se encontram pelo nome.
- **O token em `environment:`**, ou em um arquivo `.env` usado para preencher o `environment`. Funciona, e é o que a Lição 6 ensinou a não fazer: fica no `docker inspect`. Para isso existem os `secrets`.

## O erro que se vai ver

Esta lição tem três erros principais. Todos já apareceram, e cada um se distingue por onde é visto.

**No relatório: `read-only file system` em `/datos`.**

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

O contêiner está `healthy` e o relatório falha. Lê-se da direita para a esquerda, como os das Lições 7 e 8: `read-only file system` é dito pelo kernel; `/datos/.reporte-<n>.tmp` diz que o problema é a pasta `/datos`; e o `500` é posto pelo `revisor`, que não finge. A pergunta que resolve é: «o que está montado em `/datos`?». A resposta é dada por `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' <contêiner>`. Se `/datos` não aparece, falta o volume no serviço. Correção: `volumes: [reportes:/datos]` no serviço e `reportes: {}` em cima, e `docker compose up -d` (recria só o `revisor`). O que não é uma correção: `read_only: false`.

**Nos logs: `permission denied` em `/run/secrets/`.**

```text
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
```

E no `docker compose ps`, um `revisor` que diz `Restarting`. O `Started` na saída do `up` não vai avisar: o processo de fato iniciou, e morreu depois. Diagnostica-se com `docker compose logs revisor` e `ls -l secretos/`. Se o arquivo está em `600`, o usuário `65532` do contêiner não consegue lê-lo, e `uid`, `gid` e `mode` no `compose.yaml` não mudam isso, porque com um segredo de arquivo o Compose os ignora. Correção: que o grupo do arquivo seja `65532` e a permissão `640` (`sudo chgrp +65532 secretos/revisor_token.txt` e `chmod 640 secretos/revisor_token.txt`), ou que o dono seja `65532` com `600`, e `docker compose up -d --force-recreate revisor`. `chmod 644` também resolve, mas abre o token a toda a máquina: só com um token de mentira (9.8.4).

**No comando: `--wait` que não termina bem.**

```text
container curso-docker-fig09-prueba-caido-1 is unhealthy
```

(Na pasta do projeto, `curso-docker-prueba-caido-1`.) Código `1`, embora só o `revisor` seja nomeado. Não é uma falha do sistema: é o `--wait` esperando também por um serviço que não pode estar saudável. Neste projeto, `up -d` e esperar a saúde do `revisor`. Em um projeto sem serviços que falhem de propósito, essa mensagem sim é um alarme: diz exatamente que contêiner revisar.

**E um secundário, ao construir**:

```text
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
```

(Na pasta do projeto a tag será a própria, `curso-docker-prueba:1.0.0`, e o serviço pode ser qualquer um dos três.) Vários serviços com `build` e a mesma `image`. Aparece às vezes, não sempre: na execução de 9.11, em 3 de 5 tentativas. Correção: `build` em um único serviço, `pull_policy: never` nos demais.

## O hábito de segurança da lição

**O `compose.yaml` nasce com tudo o que veio antes, e seus segredos vivem fora do arquivo.** É o hábito que o README do curso atribui a esta lição, e se confere com uma lista que pode ser aplicada a qualquer `compose.yaml`, próprio ou alheio, lendo seu `docker compose config`:

- Cada porta publicada leva `host_ip: 127.0.0.1` (Lição 2), e o que não precisa de porta não a publica.
- Cada serviço leva `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges` e `init: true` (Lição 7), e limites de memória, CPU e processos (Lição 2).
- As imagens levam versão, nunca `latest` (Lição 3), e as que são construídas localmente não são buscadas na internet (`pull_policy: never`).
- O que escreve, escreve em um volume nomeado montado justo onde faz falta (Lição 8).
- O que não precisa de internet vive em uma rede `internal: true`, e não há `network_mode: host` (Lição 8).
- Nenhum valor secreto em `environment`, em `build.args` nem no próprio arquivo: os segredos vão em `secrets:`, a partir de arquivos que não sobem ao repositório, e o `grep` do valor em `docker compose config` e em `docker inspect` dá zero (Lição 6 e esta).

O acidente que isso evita é o da cena: que o sistema que roda não seja o que foi testado. Um arquivo reforçado uma vez fica reforçado para todos que o usarem; seis comandos reforçados dependem de que ninguém copie o errado.

## O que se faz errado

**Escrever `version:` no alto do arquivo.** É obsoleto e só produz um aviso. E quase sempre denuncia que o resto do arquivo foi copiado de um tutorial antigo: revise-o com mais cuidado.

**Portas sem `127.0.0.1`.** `"8080:8080"` em um `compose.yaml` é o `-p 8080:8080` da Lição 2: a porta aberta a toda a rede. É a primeira coisa que se perde ao copiar um exemplo.

**Tirar `read_only` «porque falha».** Se falha, o programa escreve em algum lugar que não foi previsto. Descubra qual (o erro diz) e monte ali um volume ou um `tmpfs`.

**`depends_on` sem condição para algo que deve estar pronto.** A forma curta só espera que o contêiner esteja rodando. Se o serviço precisa de outro saudável, `condition: service_healthy`, e que esse outro tenha sua verificação de saúde.

**`service_healthy` para tudo.** Com um serviço que nunca vai estar saudável, quem depende dele nunca inicia. Peça saúde só ao que dela precisa.

**O token em `environment:` ou em um `.env`.** Fica no `docker inspect` para qualquer um do grupo `docker`. Para isso existe `secrets:`.

**Confiar em `uid`, `gid` e `mode` de um segredo de arquivo.** O Compose os ignora em silêncio. A permissão é a do arquivo na máquina.

**`build` em vários serviços com a mesma `image`.** Uma corrida que «quase sempre» a outra ganha. Construa em um e use a imagem nos demais.

**`docker compose down --volumes` por costume.** Apaga o relatório. Use quando se quiser começar do zero, não para desligar.

**Apagar à mão com `docker rm` o que o Compose criou.** Funciona, mas o Compose já não sabe em que pé ficou tudo. O que se cria com o Compose se desliga com `docker compose stop` ou `docker compose down`.

**Dois projetos com o mesmo nome.** Dois `compose.yaml` com `name: curso-docker`, mesmo em pastas distintas, interferem um no outro: o Compose acredita que os contêineres de um são do outro. Um projeto, um nome.

## Exercícios

Faça-os em ordem. Antes de rodar cada um, escreva no [diário de bordo](bitacora.md) o que se acredita que vai acontecer; compará-lo depois é metade do aprendizado. Ao terminar, deixe o projeto com o arquivo final e desligue-o com `docker compose down` (sem `--volumes`, se se quiser conservar o relatório).

### Exercício 1 — Traduza um `docker run`

Este é o comando do serviço de teste da Lição 8, seção 8.10.3:

```text
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Escreva o serviço do Compose equivalente, chamado `prueba`, sem olhar o `fig09_01.compose.yaml`. Depois diga: que opção do comando **não** tem chave no serviço, e por quê? O que teria de existir no arquivo, fora do serviço, para que o `networks` funcione?

### Exercício 2 — O que o Compose recria?

Com o sistema final no ar, preveja, para cada mudança separadamente, que contêineres dirão `Running` e quais `Recreated` no `docker compose up -d` seguinte. Depois confira e devolva o arquivo à sua forma final antes da seguinte:

1. Muda-se o tempo de `lento` em `REVISOR_SERVICIOS` de `5s` para `4s`.
2. Muda-se `mem_limit: 32m` por `mem_limit: 24m` na âncora `x-prueba`.
3. Não se muda o arquivo, mas faz-se `chmod 600 secretos/revisor_token.txt`.

Pergunta extra: no caso 3, o que seria preciso fazer para ver o erro de 9.10, e que comando o desfaz?

### Exercício 3 — Diagnostique sem rodar

Uma colega envia isto, copiado de seu terminal (é o bloco «Exercício 3» do `fig09_10.sh`, então os nomes são os de apoio e o número do arquivo temporário está oculto). O `revisor` diz `healthy` e, no entanto, seu relatório não funciona:

```text
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

1. Os `(unhealthy)` de `prueba-caido` e `prueba-lento` são o problema? Por quê?
2. Que linhas faltam com toda certeza no `compose.yaml` dela? Com que comando seria comprovado sem abrir o arquivo?
3. O que diz que o token **está** certo?

### Exercício 4 — O arquivo do curso contra o do guia

Pegue o `compose.yaml` do guia oficial de Python da seção 9.13 e faça uma lista de **tudo** o que o arquivo final do curso tem e esse não, aplicado ao serviço `server`. Para cada diferença, diga que lição do curso a explica e que risco ela fecha. Depois responda: há algo no arquivo do guia que **não** seria preciso mudar?

## Soluções

As soluções que dizem «medido» saem do script `fig09_10.sh`, que faz cada mudança à vista com `sed`, a confere e a desfaz. Sua saída completa:

```text
$ ./fig09_10.sh
== Ejercicio 1. Un servicio en una red que no está declarada arriba
$ docker compose config --quiet
service "prueba-lento" refers to undefined network otra: invalid compose project
[código de salida: 1]

== Ejercicio 2.1. lento: de 5s a 4s en REVISOR_SERVICIOS
$ cambios
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Recreated
Container curso-docker-fig09-revisor-1 Started

== Ejercicio 2.2. mem_limit: de 32m a 24m en el ancla x-prueba
$ docker compose config | grep mem_limit
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "25165824"
    mem_limit: "67108864"
  mem_limit: 24m
$ cambios
Container curso-docker-fig09-prueba-caido-1 Recreated
Container curso-docker-fig09-prueba-sano-1 Recreated
Container curso-docker-fig09-prueba-lento-1 Recreated
Container curso-docker-fig09-revisor-1 Running
Container curso-docker-fig09-prueba-sano-1 Started
Container curso-docker-fig09-prueba-lento-1 Started
Container curso-docker-fig09-prueba-caido-1 Started

== Ejercicio 2.3. Sin cambiar el archivo: chmod 600 al token
$ cambios
Container curso-docker-fig09-prueba-caido-1 Running
Container curso-docker-fig09-prueba-lento-1 Running
Container curso-docker-fig09-prueba-sano-1 Running
Container curso-docker-fig09-revisor-1 Running
$ tabla | head -2
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
$ docker compose restart revisor 2>&1 | eventos | grep -v Restarting
Container curso-docker-fig09-revisor-1 Started
$ docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}}' curso-docker-fig09-revisor-1
Status=restarting ExitCode=1
$ docker compose up -d --force-recreate revisor 2>&1 | eventos | grep -E 'revisor-1 Started'
Container curso-docker-fig09-revisor-1 Started
revisor: healthy

== Ejercicio 3. El revisor sin volumen en /datos, con los cuatro servicios
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
$ docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes
[código de salida: 1]
$ docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-fig09-revisor-1
/run/secrets/revisor_token 
```

### Solução 1

```yaml
  prueba:
    image: curso-docker-prueba:1.0.0
    networks:
      - interna
    read_only: true
    cap_drop: [ALL]
    security_opt: ["no-new-privileges:true"]
    init: true
    mem_limit: 64m
    cpus: 0.5
    pids_limit: 50
```

É o serviço do `fig09_01.compose.yaml`, exceto o `build` (que o comando da Lição 8 não trazia, porque a imagem já existia). A opção sem chave é `--name curso-docker-prueba`: o nome do contêiner é colocado pelo Compose (`curso-docker-prueba-1` na pasta do projeto), e os demais o encontram pelo nome do **serviço**, `prueba`. `-d` também não tem chave: é uma opção do comando (`docker compose up -d`), não do serviço. Para que `networks: [interna]` funcione, a rede tem de estar declarada em cima, em `networks:`; se não, o arquivo não é válido. E para que continue sendo a rede sem saída da Lição 8, essa declaração leva `internal: true`. Medido: com a âncora apontando para uma rede `otra` que não existe em cima, `docker compose config --quiet` responde `service "prueba-lento" refers to undefined network otra: invalid compose project` e sai com `1` (nomeia uma das três cópias que herdam a âncora; pode ser outra na execução de quem estuda). É o tipo de erro que o `config` pega antes de criar qualquer coisa.

### Solução 2

Medido (blocos «Exercício 2» do `fig09_10.sh`):

1. **Só o `revisor` é recriado.** `REVISOR_SERVICIOS` faz parte de sua configuração; os serviços de teste não mudam e dizem `Running`. É o mesmo que se viu no bloco 2 do `fig09_03.sh`, com outra mudança.
2. **As três cópias do serviço de teste são recriadas**, e o `revisor` fica em `Running`. Para o Compose, o que conta é o resultado de copiar a âncora nos três serviços, então mudar a âncora é mudar os três. `docker compose config | grep mem_limit` confirma antes de subir: três vezes `25165824` (24 MB em bytes) e uma `67108864` (o `revisor`). A última linha, `mem_limit: 24m` sem aspas e com menos recuo, é o próprio `x-prueba`: o `config` conserva os campos `x-` em sua saída, embora não os use para criar nada.
3. **Nada é recriado**: os quatro em `Running`, e a tabela continua saindo. A permissão de um arquivo da máquina não faz parte da configuração que o Compose compara, e o `revisor` já leu seu token ao iniciar, então continua funcionando. Para ver o erro de 9.10 é preciso obrigá-lo a iniciar de novo: `docker compose restart revisor` diz `Started`, e três segundos depois o `docker inspect` diz `Status=restarting ExitCode=1`. Desfaz-se devolvendo a permissão anterior (na pasta temporária do script, `644` com o token de mentira; na do projeto, o `640` com grupo `65532` de 9.8.4) seguida de `docker compose up -d --force-recreate revisor`, o mesmo comando de 9.10. A lição deste caso: um erro de permissões pode ficar **adormecido** por dias, até o próximo reinício.

### Solução 3

1. **Não.** Estão `unhealthy` porque falham de propósito: o fora do ar responde `503` e o lento leva 3 s quando sua verificação exige menos de 2. É o esperado, e por isso o `revisor` só pede `service_healthy` à saudável. O `revisor` está `healthy` porque `/salud` não escreve nada.
2. Falta o volume do `revisor` em `/datos`: as duas linhas `volumes:` e `- reportes:/datos` do serviço. É o bloco 1 do `fig09_03.sh`. Comprova-se sem abrir o arquivo com `docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes`, que não encontra nada e sai com `1`; ou, sobre o contêiner, com `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-revisor-1`, que mostra `/run/secrets/revisor_token` e não mostra `/datos`. As duas coisas estão na saída do `fig09_10.sh`.
3. Que a resposta **não** é `401`. Com o token errado ou ausente, o `revisor` responde `{"error":"falta el token o no es válido"}` antes de tentar qualquer coisa. Aqui ele passou por essa verificação e falhou ao guardar. E se o arquivo do token estivesse em `600`, o `revisor` nem sequer estaria `Up`: estaria reiniciando (9.10).

### Solução 4

O que o arquivo do curso tem e o do guia não, no serviço:

- **`127.0.0.1` na porta** (Lição 2). `8000:8000` publica em todas as interfaces da máquina; qualquer um da rede chega ao serviço.
- **`image:` com nome e versão** (Lição 3). Sem ela, o nome da imagem é decidido pelo Compose e não diz que versão roda.
- **`read_only`, `cap_drop`, `no-new-privileges` e `init`** (Lição 7). Sem eles, quem tomar o controle do processo pode escrever no disco do contêiner, usar as capabilities de `root` que o Docker deixa por padrão e ganhar privilégios com um programa *setuid*; e um programa que não sabe ser o processo 1 não se desliga bem.
- **Limites de memória, CPU e processos** (Lição 2). Sem eles, um erro do programa pode tomar a máquina inteira.
- **`restart`** (Lição 7). Sem política, se o processo morre fica morto.
- **Redes próprias, com a interna sem saída** (Lição 8). O guia usa a rede padrão do projeto, com saída para a internet para todos.
- **Um volume nomeado onde escreve** (Lição 8). Nesse exemplo não faz falta porque a aplicação não guarda nada; no dia em que guardar, precisará.
- **`secrets:`** (Lição 6 e esta). O guia de onde sai o exemplo acrescenta mais adiante um banco de dados com sua senha como segredo: o padrão é o mesmo.

O que não seria mudado: `build` com `context: .`, que é exatamente o que o `revisor` faz, e a ausência de `version:`. E um esclarecimento justo: o estágio final do Dockerfile desse guia roda sem `root` por padrão, segundo a própria página, então o `USER` da Lição 3 está resolvido no Dockerfile dele, não no `compose.yaml`. Um arquivo gerado não é ruim: é um ponto de partida, e o trabalho é levá-lo até aqui.

## Como sei que consegui

Marque cada ponto só se for possível fazê-lo **sem voltar a olhar o texto**:

- [ ] Na pasta `revisor/`, `docker compose config --quiet && echo 'compose.yaml válido'` imprime `compose.yaml válido`, e `grep -c '^version' compose.yaml` dá `0`.
- [ ] `docker compose up -d --build` sobe os quatro serviços do zero, `docker compose ps` mostra `curso-docker-revisor-1` em `(healthy)` com `127.0.0.1:8080->8080/tcp`, e nos eventos do `up` aparece `prueba-sano-1 Healthy` **antes** de `revisor-1 Started`.
- [ ] A tabela do `revisor`, pedida com o token, mostra `caido FALLA`, `lento LENTO` e `sano OK`, sem que nenhum modo tenha sido mudado à mão.
- [ ] `docker inspect curso-docker-revisor-1 | grep -c "$(cat secretos/revisor_token.txt)"` dá `0`, e o mesmo com `docker compose config`.
- [ ] Explica-se por que o `revisor` espera com `service_healthy` só `prueba-sano`, usando as palavras *saúde*, *503* e *2 segundos*.
- [ ] Provoca-se o `read-only file system` tirando o volume de `/datos`, e o `permission denied` do segredo com `chmod 600`, e explica-se por que `uid`, `gid` e `mode` não o evitam.
- [ ] Com `stat -c '%a %U:%G'` e `sudo -u nobody cat` comprova-se que o `secretos/revisor_token.txt` **não** é lido por outra conta, e que o `revisor` o lê (`640` com grupo `65532`, ou `600` com dono `65532`); e `git check-ignore -v secretos/revisor_token.txt` diz que o `.gitignore` do projeto o cobre.
- [ ] Depois de `docker compose down` (sem `--volumes`), `docker run --rm -v curso-docker_reportes:/datos:ro alpine:3.24.2 ls -ln /datos` mostra `reporte.json` de `65532`.
- [ ] `docker compose stop revisor` leva menos de um segundo e deixa `ExitCode=0`.
- [ ] Rodam-se os scripts de [`programas/09-compose/`](../programas/09-compose) (com o projeto desligado, ou com outra porta: `PUERTO=18080 ./fig09_05.sh`; a função `nombres` reescreve a porta na saída) e as saídas coincidem com as desta lição, exceto os tempos, as datas, o número do arquivo temporário, a ordem dos eventos simultâneos, o serviço que o erro do Exercício 1 nomeia e as tentativas e serviços do choque de 9.11. E ao terminar, `docker ps -a --filter name=fig09`, `docker volume ls --filter name=fig09` e `docker network ls --filter name=fig09` não mostram nada.

## Resumo

Responda sem olhar a lição:

1. Que diferença há entre um serviço e um contêiner, e que nome os demais contêineres usam para encontrar um?
2. De onde sai o nome de um projeto, em que ordem é decidido, e como aparece nos nomes de contêineres, redes e volumes?
3. O que faz o `docker compose config`, e o que ele mostrou sobre `depends_on: [prueba]` e sobre `"127.0.0.1:8080:8080"`?
4. Por que pedir `docker compose up -d` duas vezes não faz nada na segunda, e o que faz quando um serviço muda?
5. Por que o `revisor` com `read_only: true` precisa sempre de algo montado em `/datos`?
6. Para que servem juntos um campo `x-` e uma âncora do YAML?
7. Que diferença há entre `service_started` e `service_healthy`, e por que não se pode pedir `service_healthy` a `prueba-caido`?
8. Onde aparece um segredo do Compose dentro do contêiner, e por que um arquivo em `600` dá `permission denied` mesmo com `uid`, `gid` e `mode` declarados? Quem pode ler o mesmo arquivo com `644`, e como deixá-lo para que o `revisor` e o usuário da máquina o leiam, mas mais ninguém?
9. Por que só um serviço de teste leva `build`, e o que faz `pull_policy: never` nos outros dois?
10. O que apaga o `docker compose down`, o que acrescenta `--volumes`, e por que o `up --wait` falha neste projeto embora tudo funcione?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [Docker, «Docker Compose»](https://docs.docker.com/compose/): o que é o Compose.
- [Docker, «How Compose works»](https://docs.docker.com/compose/intro/compose-application-model/): o nome `compose.yaml` (preferido) e os nomes legados; o que é um projeto; serviços, redes, volumes, configurações e segredos.
- [Especificação do Compose](https://docs.docker.com/reference/compose-file/): o documento que define as chaves do arquivo e seus elementos de nível superior.
- [Especificação, `version` e `name`](https://docs.docker.com/reference/compose-file/version-and-name/): que `version` é apenas informativo e produz um aviso de obsoleto; `name` como nome do projeto.
- [Referência dos serviços do Compose](https://docs.docker.com/reference/compose-file/services/): `depends_on` e suas três condições; `pull_policy: never`; `read_only`, `cap_drop`, `security_opt` e as três formas de `no-new-privileges`; `init`; `mem_limit`, `cpus`, `pids_limit`; `restart`; `image` junto a `build`; a forma longa de `secrets` e que com um arquivo como fonte `uid`, `gid` e `mode` são ignorados em silêncio.
- [Especificação, extensões](https://docs.docker.com/reference/compose-file/extension/): que o Compose ignora os campos que começam com `x-` e que servem para reutilizar configuração.
- [Especificação, fragmentos](https://docs.docker.com/reference/compose-file/fragments/): âncoras, aliases e a chave de mescla `<<`; que a mescla só se aplica a mapas; `environment` como mapa ao usar fragmentos.
- [Docker, «Specify a project name»](https://docs.docker.com/compose/how-tos/project-name/): a ordem em que o nome do projeto é decidido, os caracteres que admite e que serve para isolar ambientes.
- [Docker, «Networking in Compose»](https://docs.docker.com/compose/how-tos/networking/): a rede `<projeto>_default`, o nome do serviço no DNS e as redes próprias com `networks`.
- [Docker, «Control startup order»](https://docs.docker.com/compose/how-tos/startup-order/): que o Compose não espera que um contêiner esteja pronto, apenas rodando; `service_healthy`; a ordem de remoção por dependências; `restart: true` dentro de `depends_on`.
- [Docker, «Secrets in Compose»](https://docs.docker.com/compose/how-tos/use-secrets/): o que é um segredo, o caminho `/run/secrets/<nome>`, que o Docker cria uma montagem (`bind mount`) nesse caminho, que o acesso é controlado com as permissões normais do sistema de arquivos e que só o recebe o serviço a que é concedido.
- [Especificação, `secrets` de nível superior](https://docs.docker.com/reference/compose-file/secrets/): que o segredo é criado com o conteúdo do arquivo de `file` (ou com uma variável de ambiente de `environment`).
- [Referência do `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/): que mostra o modelo que será aplicado, em forma canônica; `--quiet`, `--services`, `--volumes`.
- [Referência do `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/): o que faz o `up`; que recria ao mudar configuração ou imagem e conserva os volumes; `-d`, `--build`, `--wait`, `--wait-timeout`, `--no-recreate`.
- [Referência do `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/): o que apaga por padrão e o que `--volumes` acrescenta.
- [Referência do `docker init`](https://docs.docker.com/reference/cli/docker/init/): que é fornecido pelo Docker Desktop, os arquivos que cria e seus modelos.
- [Docker, «Containerize a Python application»](https://docs.docker.com/guides/python/containerize/): o `compose.yaml` de um serviço usado em 9.13 e no Exercício 4.
- [Docker, «Retired features»](https://docs.docker.com/retired/): que o Compose v1 já não recebe manutenção e é preciso migrar para o Compose v2.
- [Docker, «Announcing Compose V2 General Availability»](https://www.docker.com/blog/announcing-compose-v2-general-availability/): a mudança de sublinhado para hífen nos nomes dos contêineres e o aviso de não depender deles.
- [Especificação, `models`](https://docs.docker.com/reference/compose-file/models/): o elemento de nível superior para modelos de IA, mencionado em 9.1.1.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões e datas de «Sobre as execuções».
- [Colima](https://github.com/abiosoft/colima): a ferramenta com que os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **âncora e alias** (YAML) | `&nome` marca um bloco; `*nome` se refere a ele; `<<: *nome` copia suas chaves para dentro de outro mapa |
| **bloco dobrado** (YAML) | `>-`: junta várias linhas em uma, com espaços, e remove a quebra final |
| **campo `x-`** | campo de nível superior que o Compose ignora; usa-se para guardar blocos reutilizáveis |
| **Compose** | a ferramenta (`docker compose`) que lê um `compose.yaml` e cria, recria ou apaga o necessário para que exista o que ele descreve |
| **`depends_on`** | ordem de inicialização entre serviços, com uma condição: `service_started`, `service_healthy` ou `service_completed_successfully` |
| **forma canônica** | a versão longa e completa do arquivo, com todos os valores padrão escritos; é mostrada pelo `docker compose config` |
| **projeto** | uma implantação de um `compose.yaml`; seu nome vai na frente de tudo o que o Compose cria |
| **segredo do Compose** | arquivo que o Compose monta como somente leitura em `/run/secrets/<nome>`, apenas nos serviços que o pedem |
| **serviço** | a receita de um contêiner no `compose.yaml`; seu nome é o usado no DNS do projeto |

---

**Seguinte:** [Lição 10 — Entregar a imagem](10-entregar-la-imagen.md)
