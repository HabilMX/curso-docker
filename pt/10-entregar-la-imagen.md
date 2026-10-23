# Lição 10 — Entregar a imagem

É sexta-feira, 17h20. Na segunda, às 9h, começa o curso de Kubernetes da equipe, e o instrutor quer que cada pessoa leve ao seu cluster **a mesma imagem do `revisor`**, aquela que já foi testada. Na terça, o comando `docker run curso-docker-revisor:1.6.0` foi enviado ao colega Tomás e funcionou para ele. Na quarta, apareceu um erro pequeno, a imagem foi reconstruída e enviada de novo com a mesma tag, `1.6.0`, porque «é a mesma versão, só corrigi um detalhe». Hoje, sexta, Tomás escreve: «aqui o relatório sai diferente do seu». Os dois têm uma imagem com exatamente o mesmo nome. Confere-se, e nenhum dos dois sabe dizer qual das duas é a boa. E não é só isso: a pessoa que cuida da segurança da equipe faz três perguntas que ninguém sabe responder com certeza. O que essa imagem leva dentro? Com que foi construída e de onde saiu cada peça? Ela tem algum componente com uma falha conhecida? São 17h34. Tomás usa um processador diferente e, por isso, nem sequer há certeza de que a imagem construída na máquina de origem *funcione* na dele. A pergunta já não é como se constrói uma imagem, e sim **como se entrega uma imagem para que quem a receba saiba exatamente qual é, o que ela traz, de onde vem e em que máquinas roda**. Esta lição existe para que, na segunda-feira, em vez de «já mandei, acho que é a boa», se possa dizer: «aqui está o digest, aqui a lista de materiais, aqui a varredura de hoje, e há um binário para cada processador, com a prova de que o de `amd64` inicia».

**Tempo:** 2 × 45 min

**O que se constrói:** a entrega da imagem do `revisor`, versão 1.6.0, em cinco movimentos. Um registry local que escuta apenas em `127.0.0.1`. Um `Dockerfile` que compila o mesmo binário para dois processadores (`linux/amd64` e `linux/arm64`) sem emulação. Uma publicação dessa imagem com sua **lista de materiais** (SBOM) e sua **proveniência** (*provenance*), que se podem ler com um comando. Uma varredura de vulnerabilidades com o Trivy, feita sem entregar ao Trivy o *socket* do Docker. E a ponte para o curso seguinte: a imagem carregada em um cluster `kind` com `kind load docker-image`, e um pod que inicia sem tentar baixar nada.

**O que se aprende:** o que é um registry e como se compõe uma referência de imagem; a diferença entre uma **tag**, que pode ser movida, e um ***digest***, que não pode; o que é um índice de imagens e por que uma mesma tag pode trazer vários processadores; as três maneiras de construir para várias plataformas e por que aqui se usa a compilação cruzada; o que são atestações e como ler um SBOM e uma proveniência (modos `min` e `max`, e o que o `max` expõe); o que se pode esperar, e o que não, de um rebuild «idêntico»; como baixar uma imagem **por digest** e executá-la reforçada; como varrer com o Trivy, o que é um limiar (*threshold*) e por que `UNKNOWN` também conta para o código de saída; como aceitar um achado por escrito ou resolvê-lo renovando a base; e como levar a imagem a um cluster `kind` sem registry.

**De onde se parte.** Da [Lição 9](09-compose.md) traz-se o sistema completo em um `compose.yaml` e o estado da [Lição 8](08-volumenes-y-redes.md): uma imagem com menos de vinte megabytes, sem shell, sem `root`, que guarda seu relatório em `/datos`, pasta que pertence ao usuário `65532`. Da [Lição 7](07-salud-y-ciclo-de-vida.md), o reforço de segurança com que ela é executada (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`). Da [Lição 5](05-multi-stage.md), o costume de fixar a base por versão e por *digest*: hoje se vê quanto custa esse costume e como ele se paga. Da [Lição 2](02-contenedores-dia-a-dia.md), publicar portas apenas em `127.0.0.1` e não entregar o *socket* do Docker a um contêiner: esse hábito decide como a varredura é feita nesta lição. A pasta do projeto tem `revisor/` com seu `Dockerfile`, seu `.dockerignore` e `secretos/`, e ao lado `servicio-prueba/`.

**O que esta lição não faz.** Não publica nada em um registry público: nem Docker Hub, nem outro. Tudo acontece em um registry que se sobe na própria máquina, acessível apenas a partir dela, e que é apagado ao terminar. Não monta um registry de produção: isso exige TLS e controle de acesso, e a documentação do próprio registry o exige (a seção 10.1.1 a cita). Não assina imagens: uma assinatura criptográfica responde à pergunta «quem a publicou?», e a lição fica nas perguntas «qual é?», «o que traz?» e «como foi feita?». Não promete que uma imagem varrida seja uma imagem segura: a varredura confere o que suas bases de dados conhecem **hoje**, e a seção 10.10 explica o que significa um «0» e o que não significa. Não altera o `compose.yaml` da lição anterior, que continua construindo a 1.5.0: a 1.6.0 desta lição é a imagem que se entrega ao curso seguinte, e a única diferença em relação à 1.5.0 é o `Dockerfile`, que compila para dois processadores. E não implanta nada no Kubernetes: o último movimento apenas leva a imagem até a porta do cluster e comprova que o pod inicia; o resto é o [curso de Kubernetes com kind](https://www.habil.mx/pt/cursos/kubernetes/) da Hábil.

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026. Isto é o que se precisa saber sobre a origem delas, para comparar com as de cada pessoa:

- **A máquina.** Um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4 (a mesma base do Linux Mint 22, o sistema de referência do curso), kernel 6.8 e processador `arm64`. Os scripts de registry, construção e varredura foram executados **dentro** dessa máquina virtual, com Docker 29.2.1 (cliente e daemon), Buildx v0.31.1 e BuildKit v0.27.1. O passo do `kind` (seção 10.11) foi executado **no Mac**, onde vivem o `kind` v0.33.0 e o `kubectl` v1.37.1, contra o mesmo daemon.
- **As versões do curso.** Planejou-se com o Docker Engine 29.8.2 (medido em 7 de outubro), e no dia das execuções a mais recente publicada era a 29.9.2, de 20 de outubro ([notas de versão](https://docs.docker.com/engine/release-notes/29/)). Uma instalação de hoje traz, portanto, um Buildx e um BuildKit mais novos do que os destas execuções: se um texto de erro ou uma versão de ferramenta diferir, compare-os pelo sentido e confira as versões instaladas com `docker version` e `docker buildx version`. O scanner é o **Trivy 0.76.0**, publicado em 14 de outubro de 2026 ([notas da versão](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)); o registry é a imagem oficial `registry:3.1.2`.
- **O armazenamento de imagens.** O Docker desta máquina usa o *image store* do *containerd* (`docker info` diz `Storage Driver: overlayfs` com `driver-type: io.containerd.snapshotter.v1`), e a seção 10.1.4 explica por que isso importa e como comprová-lo na máquina de cada pessoa.
- **A emulação.** Nesta máquina, **compilar Go emulado para `amd64` não funcionou** (a seção 10.4 mostra a falha e o que ela significa), enquanto **iniciar** o binário `amd64` já compilado funcionou (seção 10.9.2). Em um Mint com processador `amd64`, a plataforma estranha seria `arm64` e o resultado pode ser outro.
- **Os nomes.** Para não tocar no que é da pessoa, os scripts usam nomes de apoio (o registry `curso-docker-registro-fig10`, a imagem `curso-docker-revisor:fig10`, o volume `curso-docker-trivy-cache-fig10`, o cluster `curso-docker-puente-fig10`), constroem com uma tag própria e, ao sair, apagam **por nome**, nunca por identificador; os que publicam uma porta verificam antes de iniciar que ela esteja livre e, se não estiver (por exemplo, porque já existe um registry da pessoa), param em vez de enviar para um registry que não é o deles: `fig10_02.sh` verifica a 5000 e a 8080; `fig10_04.sh`, `fig10_08.sh` e `fig10_09.sh` verificam apenas a 5000, que é a única que publicam; `fig10_00.sh`, `fig10_05.sh`, `fig10_06.sh` e `fig10_07.sh` não publicam nenhuma porta fixa e não verificam nenhuma. Esta execução os lançou, além disso, com o prefixo `curso-docker-l10-` e as portas 18100 e 18101, porque na mesma máquina trabalhavam outras lições; uma função `nombres`, à vista em cada script, volta a escrever esse prefixo como `curso-docker-` e as portas como `5000` e `8080`. Com os valores padrão nada muda. Na pasta de cada pessoa, o registry se chamará `curso-docker-registro` e a imagem, `curso-docker-revisor:1.6.0`.
- **O que muda de uma execução para outra**, e é avisado onde aparece: os *digests* (dependem da hora da construção), os tempos (um segundo, sessenta e cinco: dependem do que havia em cache), os tamanhos de arquivo em décimos de megabyte, as datas da base de dados do Trivy, as versões das ferramentas que assinam o SBOM (`syft` e BuildKit, no campo `creators`), o número de pacotes do SBOM e as mensagens exatas da emulação que falha.

Os programas estão em [`programas/10-entregar-la-imagen/`](../programas/10-entregar-la-imagen), cada um com sua saída ao lado, e `estado/` guarda os arquivos do projeto como ficam ao terminar.

## Ao terminar, será possível

- Subir um registry local apenas em `127.0.0.1`, publicar nele uma imagem e listar o que ele contém com `curl` contra sua API.
- Explicar, com uma medição própria, por que uma tag não identifica uma imagem e um *digest* identifica, e baixar e executar uma imagem **por digest**.
- Converter o `Dockerfile` da Lição 8 em um que compila para `linux/amd64` e `linux/arm64` sem emulação, e comprovar para qual processador ficou cada binário lendo seus bytes.
- Publicar um índice de duas plataformas com SBOM e proveniência em modo `max`, e ler com `docker buildx imagetools inspect` os pacotes que ele contém, com que foi construído e quais dados do construtor ficam expostos.
- Varrer a imagem com o Trivy a partir de um arquivo de `docker save`, sem montar o *socket* do Docker, e ler o resultado com seu limiar e seu código de saída.
- Decidir sobre um achado: aceitá-lo por escrito em um `.trivyignore`, com motivo e data, ou resolvê-lo renovando o *digest* da base, e comprovar o resultado.
- Carregar a imagem em um cluster `kind` com `kind load docker-image` e explicar por que o pod inicia com `imagePullPolicy: Never`.

## O porquê antes do como

Até agora a imagem vivia onde era construída: no *image store* do próprio Docker. Enquanto for assim, «a imagem» é um assunto entre a pessoa e a equipe dela. Entregá-la é tirá-la dali, e assim que ela sai aparecem quatro problemas que não existiam.

O primeiro é **o nome que mente**. A cena do início não é um descuido raro: é a consequência direta de `curso-docker-revisor:1.6.0` ser uma *tag*, um rótulo colado em uma imagem, e de um rótulo poder ser descolado e colado em outra. Quem recebe o nome não recebe garantia de nada. É preciso uma forma de se referir a *essa* imagem e não a «a que neste momento tiver este rótulo». Essa forma existe, chama-se *digest*, e será medida na seção 10.3.

O segundo é **o processador**. Uma imagem contém um binário já compilado, e um binário compilado para `arm64` (o Mac da cena, e muitos servidores na nuvem) não roda em `amd64` (o Mint do colega, e a maioria dos servidores). A imagem da Lição 8 foi construída para o processador de quem a construiu, e nada mais. Entregá-la a outra equipe exige poder dizer «aqui há uma para cada processador, sob o mesmo nome». E construí-la duas vezes tem seu próprio risco: se uma das duas construções rodar emulada, pode ser lentíssima ou, como se verá, não funcionar.

O terceiro é **a caixa-preta**. Uma imagem é um arquivo que alguém entrega e que será executado com permissões na máquina de quem o recebe e, mais adiante, em um cluster compartilhado. Antes de executá-la, quer-se saber o que ela leva dentro (lista de materiais), de onde saiu cada peça e com que instruções foi montada (proveniência), e se alguma de suas peças tem uma falha pública conhecida (varredura). Não é preciso desconfiar de ninguém para pedir essas três coisas: pedi-las é a forma normal de trabalhar quando algo vai rodar onde importa.

O quarto é **a porta de entrada do cluster**. No curso seguinte, o `revisor` precisa chegar a um cluster. Um cluster não enxerga o *image store* do Docker local: tem o seu próprio. É preciso decidir como a imagem chega até lá, e em um laboratório local a resposta é uma só linha (`kind load docker-image`), com uma armadilha que será provocada de propósito para ser lida.

Que o terceiro problema não é exagero de manual, mostra-o um caso público. Em 1º de abril de 2021, um cliente da Codecov, um serviço de cobertura de testes, percebeu que o *script* baixado da empresa para enviar seus resultados não tinha a mesma soma de verificação (*shasum*) que a publicada no GitHub. Avisou, e a empresa descobriu que alguém havia modificado esse *script* sem autorização desde 31 de janeiro: a linha alterada enviava a um servidor alheio o ambiente completo das máquinas de integração contínua onde ele rodava, com as credenciais que houvesse ali. A empresa recomendou, entre outras coisas, rotacionar as credenciais de quem o tivesse usado sem validar a soma ([Codecov, «Bash Uploader Security Update»](https://about.codecov.io/security-update/)). Não era uma imagem de contêiner, era um *script*, mas o mecanismo que o denunciou é exatamente o desta lição: **comparar a impressão do que se recebeu com a impressão do que foi publicado**. Quem comparava a soma com a publicada no GitHub podia detectar a alteração; o cliente que o fez a reportou em 1º de abril, dois meses depois de as alterações começarem, e os usuários afetados foram avisados em 15 de abril. Um *digest* serve como essa soma, com uma condição que o caso deixa ver: a impressão precisa chegar por um canal diferente do que serve o que é baixado. A soma da Codecov estava no GitHub e o *script* era servido de outro lugar. Com as imagens acontece o mesmo: o *digest* é enviado ao Tomás pelo canal de quem publica, e ele não o toma do mesmo registry que lhe serve a imagem.

Esta lição resolve os quatro com ferramentas que já se têm. Quase tudo é feito pelo `docker buildx`, que vem com a instalação da Lição 1. Um registry é só mais um programa, e por isso sobe em um contêiner. O único programa novo é o Trivy, que também roda em um contêiner, com o hábito da Lição 2: não se entrega a ele o *socket* do Docker. Com esse destino em mente, isto é o que se terá no final da seção 10.9: a imagem publicada, baixada de volta **por seu digest**, como faria uma máquina que não a construiu (o script apaga antes as cópias locais que a construção deixou e comprova isso), rodando reforçada:

```text
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

(É o final do `fig10_02.sh`. O contêiner foi criado com a referência `…@sha256:…`: já não com uma tag.) E esta é a meta do curso que cabe a esta lição, a sexta do README: a imagem publicada é referenciada por *digest*, passa na varredura do Trivy com o limiar fixado e é carregada em um cluster `kind` sem um único erro de download.

## Os conceitos

### 10.1 O que é um registry e como se lê o nome de uma imagem

#### 10.1.1 Um registry é um servidor de imagens

Um **registry** é um serviço que guarda imagens e as entrega a quem as pede. Já foi usado sem pensar: cada vez que um `FROM golang:1.27.3-trixie` ou um `docker pull` trouxe algo da internet, um registry respondeu. O serviço fala um protocolo HTTP padrão, e é por isso que esta lição pode subir um próprio com um contêiner e falar com ele usando `curl`. O projeto que o implementa, de código aberto, chama-se *Distribution*, e sua imagem oficial chama-se `registry`. A documentação o apresenta com um comando de uma linha para subi-lo (`docker run -d -p 5000:5000 --restart=always --name registry registry:3`) e com um aviso que convém ler completo: os primeiros exemplos são «apropriados apenas para testes», e «um registry pronto para produção deve ser protegido por TLS e, idealmente, usar algum mecanismo de controle de acesso» ([Distribution, «Deploy a registry server»](https://distribution.github.io/distribution/about/deploying/)). Por isso, nesta lição o registry vive em `127.0.0.1` e é apagado ao terminar. Se algum dia se publicar para outras máquinas, será preciso TLS, e isso é um tema de infraestrutura que este curso não cobre.

#### 10.1.2 As partes de uma referência

Uma **referência** a uma imagem é o texto que se diz ao Docker para apontar uma. Tem até quatro partes, e quase todo erro de «não encontra minha imagem» é uma parte mal escrita:

```text
localhost:5000 / curso-docker-revisor : 1.6.0
   registro        repositorio         etiqueta

localhost:5000 / curso-docker-revisor @ sha256:59e431fa44c7…
   registro        repositorio         digest
```

- O **registry** é onde ela está: um nome de máquina com uma porta opcional. Se nenhum for escrito, o Docker supõe o Docker Hub. Nesta lição é sempre `localhost:5000`.
- O **repositório** é o nome da imagem dentro do registry: `curso-docker-revisor`. Um repositório guarda todas as versões de uma imagem.
- A **tag** é um nome legível para uma versão: `1.6.0`. É, como diz a documentação do Kubernetes, algo que pode mudar: «as tags podem ser movidas para apontar para outras imagens, mas os *digests* são fixos» ([Kubernetes, «Images»](https://kubernetes.io/docs/concepts/containers/images/)).
- O ***digest*** é uma impressão do conteúdo, com o formato `sha256:` seguido de sessenta e quatro caracteres hexadecimais. A mesma página o define assim: «os *digests* são hashes do conteúdo da imagem, e são imutáveis».

Quando uma referência traz tag **e** *digest* ao mesmo tempo, a página do Kubernetes é explícita sobre qual manda: «apenas o *digest* será usado para baixar». A tag fica como comentário para humanos. É por isso que, mais adiante, em um manifesto ou em um `compose.yaml` onde importa saber o que se executa, convém escrever `repositorio:1.6.0@sha256:…`: a pessoa lê a versão e a máquina verifica o conteúdo.

#### 10.1.3 O que um registry guarda de verdade

Antes de subir o registry, convém saber o que será enviado a ele, porque isso muda a forma de ler as saídas da lição. Um registry não guarda «imagens» soltas; guarda **manifestos** e **blobs**. Um *blob* é um arquivo anônimo identificado por seu *digest* (uma camada comprimida, ou o arquivo de configuração da imagem). Um **manifesto** é um documento pequeno em formato JSON que lista os blobs que formam uma imagem. E acima dos manifestos pode haver um **índice** (*image index*): segundo a especificação da Open Container Initiative, é «um manifesto de nível mais alto que aponta para manifestos de imagem específicos», com um campo obrigatório `manifests` que é «uma lista de manifestos para plataformas específicas», e cada entrada pode trazer um objeto `platform` com a arquitetura (`architecture`, com os nomes de `GOARCH` do Go) e o sistema operacional (`os`, com os de `GOOS`) ([OCI, «Image Index»](https://github.com/opencontainers/image-spec/blob/main/image-index.md)). Dito no dia a dia: uma **tag** aponta para um **índice**; o índice diz «para `amd64` olhe este manifesto, para `arm64` aquele»; cada manifesto lista suas camadas. Quando se faz `docker pull` em uma máquina `amd64`, o Docker lê o índice, escolhe a entrada que corresponde ao seu processador e baixa só essa. Essa estrutura é a que será vista impressa, de verdade, na seção 10.5.

E há um terceiro tipo de entrada no índice, que não é uma imagem e sim um *documento sobre* uma imagem: as **atestações**. Elas são explicadas em 10.6.

#### 10.1.4 Antes de começar: o *image store* do Docker

Quase tudo o que vem a seguir (publicar um índice de duas plataformas com atestações, guardar uma plataforma com `docker save --platform`, ver a árvore com `docker image ls --tree`) depende de um detalhe da instalação: qual **image store** o Docker usa. O Docker 29 tem dois: o clássico, com drivers como o `overlay2`, e o do *containerd*. A documentação diz que o do *containerd* é o armazenamento padrão do Docker Engine 29.0 e posteriores **em instalações novas**, e que, se a pessoa vem de uma versão anterior, seu daemon «continua usando os drivers legados (`overlay2`) até que o do *containerd* seja ativado»; entre as vantagens, enumera guardar localmente imagens de várias plataformas e trabalhar com imagens que trazem atestações ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)). Comprova-se assim:

```bash
docker info -f '{{ .DriverStatus }}'
```

Na máquina das execuções respondeu `[[driver-type io.containerd.snapshotter.v1]]` (é o bloco 1 do `fig10_00.sh`, com sua saída ao lado), que é o que a documentação diz que aparece com o *image store* do *containerd* ativo. Se na máquina de quem estuda essa linha não aparecer (aparecerá algo com `overlay2`), a mesma página indica ativá-lo acrescentando `{"features": {"containerd-snapshotter": true}}` a `/etc/docker/daemon.json` e reiniciando o daemon com `sudo systemctl restart docker`. Um aviso honesto: esta lição **não testou** seus comandos com o armazenamento clássico, de modo que, se ele for mantido, os passos das seções 10.5 e 10.9 podem falhar ou dar outra saída; ative o do *containerd* antes de continuar.

### 10.2 Um registry local, apenas em `127.0.0.1`

#### 10.2.1 Subi-lo

É um contêiner como qualquer outro, com o hábito da Lição 2: a porta é publicada **apenas em `127.0.0.1`**, para que ninguém mais na rede possa enviar nada a ele nem pedir nada. A primeira parte do `fig10_02.sh` faz exatamente isso, espera que responda e pergunta quais repositórios ele tem:

```text
$ ./fig10_02.sh
== 1. Un registro local, publicado solo en 127.0.0.1
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba
$ curl -s http://127.0.0.1:5000/v2/_catalog
{"repositories":[]}
$ docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'
{"/var/lib/registry":{}}
```

Leia-se linha por linha. `-p 127.0.0.1:5000:5000` diz «a porta 5000 da máquina, apenas pelo endereço `127.0.0.1`, leva à porta 5000 do contêiner». A imagem é fixada em `registry:3.1.2`, uma versão concreta e não `registry:3` nem `latest`, pela mesma razão de cada imagem deste curso: dentro de seis meses a tag flutuante traria outra coisa. O `>/dev/null` esconde o identificador longo que o `docker run -d` imprime, e o `echo` confirma que o comando terminou bem. Depois, `/v2/_catalog` é um ponto da API padrão dos registries que lista os repositórios, e `/v2/` sozinho é a forma de perguntar «o serviço está vivo e fala o protocolo?» (os scripts o usam para esperar que ele inicie). A resposta `{"repositories":[]}` é a de um registry recém-nascido: o JSON é válido, o array está vazio. Não tem nada porque ainda não se enviou nada a ele.

Um detalhe de limpeza que convém conhecer: a imagem `registry` declara um volume em `/var/lib/registry` (pode-se comprovar com `docker image inspect registry:3.1.2 --format '{{json .Config.Volumes}}'`, que responde `{"/var/lib/registry":{}}`). Como na Lição 8 não o nomeamos, o Docker cria um **anônimo**, e um `docker rm` simples o deixa órfão no disco. Por isso os scripts apagam o registry com `docker rm -f -v`: o `-v` leva o volume anônimo junto com o contêiner. É o mesmo tipo de lixo que a Lição 2 ensinou a não deixar.

#### 10.2.2 Publicar sem TLS, e por que aqui se pode

Terá sido notado que enviar para `localhost:5000` não pede certificados nem senha. O que **foi medido** é isso: o `docker push` da seção seguinte funciona contra `localhost:5000` sem configurar nada. Por que se pode? Porque a documentação do daemon diz que os registries locais, «cujo endereço IP cai no intervalo `127.0.0.0/8`, são marcados automaticamente como inseguros» (isto é, são permitidos por HTTP sem TLS), e acrescenta que «não se recomenda depender disso, porque pode mudar no futuro» ([Docker, referência do `dockerd`](https://docs.docker.com/reference/cli/dockerd/)). É uma exceção de laboratório, e não um convite a copiar o costume: a documentação do registry diz que sem TLS isso só deve ser feito «para testes», e que, para o registry ser acessível a partir de outras máquinas, é preciso protegê-lo com TLS primeiro. Um registry que escuta em `0.0.0.0` sem TLS nem autenticação é uma porta aberta para que qualquer pessoa da rede troque o que os servidores baixam. Neste curso ele fica em `127.0.0.1`.

### 10.3 Tag versus *digest*: a medição da cena

#### 10.3.1 Provocar o problema de sexta-feira

A cena do início pode ser reproduzida em dois minutos, e convém fazê-lo com as próprias mãos porque é uma dessas ideias em que se acredita muito mais quando são medidas. O script `fig10_02.sh` constrói a imagem duas vezes com a **mesma tag** e versões diferentes, envia as duas vezes, e no fim pergunta ao registry o que cada referência traz. Para isso funcionar é preciso o `Dockerfile` desta lição, que é explicado em 10.4; por ora basta saber que ele constrói a mesma imagem da Lição 8 e aceita `--build-arg VERSION=…`, como sempre. As linhas que importam:

```text
== 2. Construir la 1.6.0 y publicarla con la etiqueta fig10
$ docker build -q --build-arg VERSION=1.6.0 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c"
$ curl -s http://127.0.0.1:5000/v2/_catalog; curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"repositories":["curso-docker-revisor"]}
{"name":"curso-docker-revisor","tags":["fig10"]}

== 3. Otra construcción (VERSION=1.6.1) con la MISMA etiqueta
$ docker build -q --build-arg VERSION=1.6.1 -t localhost:5000/curso-docker-revisor:fig10 . >/dev/null && docker push -q localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:f60d25f0809179fefc1966ea14609f73dd6caf3db196e40db52d7b55dc7f42a1"
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["fig10"]}
```

Vamos por partes. No bloco 2, `docker build -q` constrói em silêncio (o `-q` evita as dezenas de linhas do processo) e devolve o identificador da imagem, que o script descarta com `>/dev/null`; se o `build` terminar bem, entra o `docker push -q`, que envia a imagem ao registry e, com `-q`, imprime apenas a referência enviada. Repare no `-t localhost:5000/curso-docker-revisor:fig10`: para enviar ao *próprio* registry, o nome da imagem tem que **começar** com o endereço do registry. É a regra que explica quase todos os «push access denied» e «repository does not exist» dos iniciantes: sem o prefixo, o Docker supõe que se quer enviar ao Docker Hub. Depois, `imagetools inspect` com `--format '{{json .Manifest.Digest}}'` pergunta ao **registry** (não ao Docker local) qual é o *digest* do que há por trás dessa tag: `sha256:59e431fa…`. E a lista de tags do repositório, `tags/list`, diz uma só: `fig10`.

No bloco 3 repete-se com `VERSION=1.6.1`. Veja a saída: **a lista de tags continua sendo uma só, `fig10`**, mas o *digest* já não é `59e431fa…` e sim `f60d25f0…`. A tag se moveu de uma imagem para outra, sem avisar, sem erro, sem nenhuma mensagem que alerte alguém. O registry fez exatamente o que lhe foi pedido. O que se perdeu foi a garantia que se acreditava ter ao dizer «a 1.6.0».

#### 10.3.2 Perguntar por cada referência

Agora a prova de fogo: o que traz quem pede por tag, e o que traz quem pede por *digest*? O bloco 4 olha que cópia local a construção deixou (com `docker image ls`), apaga-a, olha de novo (para que o único que sobre seja o que o registry diz) e baixa as duas:

```text
== 4. Lo que trae cada referencia
(la copia local que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
(y después de borrarla)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor:fig10 && docker run --rm localhost:5000/curso-docker-revisor:fig10 version
localhost:5000/curso-docker-revisor:fig10
1.6.1
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c && docker run --rm localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c version
localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c
1.6.0
```

A imagem traz o subcomando `version` desde a Lição 3: imprime a versão que foi gravada na compilação. Quem pediu `:fig10` recebeu **1.6.1**, o último que foi enviado. Quem pediu o *digest* da primeira construção recebeu **1.6.0**, que é o que *essa* referência entrega, enquanto existir no registry. Os dois estão saudáveis, nenhum está «errado»: são duas imagens diferentes e a tag é um rótulo que passou de uma para a outra. Com isso, a cena de sexta-feira tem explicação e tem solução: se o Tomás e quem publicou tivessem usado a referência com *digest*, ou se cada correção tivesse sido publicada com uma tag nova (`1.6.1`), não haveria nada a discutir.

Três nuances para não tirar conclusões demais. **Uma:** o *digest* não é «mais seguro» por si só. O que ele dá é *imutabilidade de referência*: o que se pedir por *digest* ou se recebe idêntico ou não se recebe. Não diz nada sobre se a imagem tem falhas; isso é o que a varredura confere. **Duas:** quem publica pode apagar um *digest* do registry; então o `pull` falha em vez de trazer outra coisa, que é justamente o comportamento desejado. **Três:** o *digest* de um índice é diferente do de cada manifesto de plataforma que ele contém (neste exercício, `imagetools inspect` mostrou o de uma imagem de uma só plataforma; os dois níveis são vistos em 10.5). Até aqui só se trabalhou com uma plataforma; em 10.5 serão vistos os dois níveis.

A regra prática que sai daqui pode ser dita em uma linha: **a tag é para as pessoas conversarem; o *digest* é para as máquinas verificarem**. Publique-se uma tag nova para cada construção que for entregue e não se reutilize uma versão já publicada. E quando uma máquina tiver de executar exatamente o que foi testado, entregue-se a ela o *digest*. A documentação de boas práticas do Docker diz o mesmo sobre as bases: fixar a imagem por *digest* dá a garantia de que «sempre se usará a mesma versão da imagem, mesmo que quem a publica substitua a tag por uma imagem nova» ([Docker, «Building best practices», seção de bases fixadas](https://docs.docker.com/build/building/best-practices/)). Foi o que a Lição 5 fez com a base do `revisor`, e hoje se aplica à imagem do próprio `revisor`.

### 10.4 Um só `Dockerfile` para dois processadores

#### 10.4.1 O problema: um binário é de um processador

O `revisor` é escrito em Go e compila para um binário estático. «Estático» já se sabe o que significa (Lição 5): traz tudo de que precisa e não pede bibliotecas do sistema. Mas continua sendo código de máquina de **um** processador. Duas famílias dominam hoje: `amd64` (também chamada x86-64, a da maioria dos servidores e das máquinas com Linux Mint) e `arm64` (também chamada AArch64, a dos Macs com chip próprio da Apple e de muitos servidores na nuvem). O Docker as nomeia `linux/amd64` e `linux/arm64`: sistema operacional, barra, arquitetura. O nome da arquitetura é o mesmo que o Go usa, e é a razão pela qual o `Dockerfile` seguinte pode passar um nome do Docker direto ao compilador.

Para construir uma imagem que sirva nas duas, a documentação do Docker enumera três estratégias ([Docker, «Multi-platform builds»](https://docs.docker.com/build/building/multi-platform/)): **emulação** com QEMU; um construtor com **vários nós nativos** (uma máquina de cada arquitetura); e **compilação cruzada** (*cross-compilation*) com stages. Sobre a primeira, a mesma página adverte que a emulação «pode ser muito mais lenta do que as construções nativas», sobretudo em tarefas de computação intensiva como compilar, e recomenda nós nativos ou compilação cruzada «se possível». Com um compilador como o do Go, a terceira é possível e é a melhor. Agora se vai medir por quê.

#### 10.4.2 Testar a emulação (e ver que não funciona)

O script `fig10_03.sh` pega o `Dockerfile` da Lição 8, **sem mexer nele**, e pede ao Docker uma imagem para `linux/amd64` a partir de uma máquina `arm64`. O Docker aceita: no `docker buildx inspect` aparece `linux/amd64` entre as plataformas que ele sabe executar, porque traz o QEMU para fingir esse processador. Isto é o que aconteceu nesta máquina:

```text
$ ./fig10_03.sh
== 1. Este equipo y lo que su constructor sabe correr
$ uname -m
aarch64
$ docker buildx inspect | grep -E '^Platforms:'
Platforms:        linux/arm64, linux/amd64, linux/amd64/v2, linux/386

== 2. El Dockerfile de la Lección 8, para linux/amd64: todo corre emulado (QEMU)
$ docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada.log 2>&1; echo "construcción: código $?"
construcción: código 1
(tardó 0 s)
$ { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110
fatal error: fault
$ grep -E '^ERROR' emulada.log
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
(el mismo intento, dos veces más, para ver si el fallo es siempre el mismo)
$ for n in 2 3; do docker buildx build --no-cache --platform linux/amd64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-emulada emulada > emulada-$n.log 2>&1; echo "intento $n: código $?"; { grep -m1 -E 'fatal error|panic:|SIGSEGV|qemu:' emulada-$n.log || echo '(ningún renglón de error fatal)'; } | sed -E 's/^#[0-9]+ ([0-9.]+ )?//' | cut -c1-110; done
intento 2: código 1
fatal error: found pointer to free object
intento 3: código 1
fatal error: fault
```

Leia-se com calma, porque tem duas lições. `uname -m` diz `aarch64`, o nome longo de `arm64`: é uma máquina `arm64`, e a lista de plataformas confirma que seu construtor sabe executar quatro, três delas alheias ao seu processador (`amd64`, `amd64/v2` e `386`), graças à emulação. O comando de construção leva `--no-cache` (para que nada seja reaproveitado de uma execução anterior) e `-o type=local,dest=salida-emulada`, que em vez de criar uma imagem **deixa os arquivos finais em uma pasta**: aqui serve para comprovar o resultado sem encher o *image store*. Pede-se `--platform linux/amd64`.

O resultado: a construção **falha**, com código 1, quase instantaneamente (o script marcou 0 s). A mensagem é um `fatal error` do próprio programa Go, e a última linha diz onde ele disparou: no passo `go test ./...`, o da etapa de testes da Lição 5, que ao falhar com `exit code: 2` interrompe tudo. Para saber se a falha é constante ou casual, o script repete a tentativa mais duas vezes. Saíram **mensagens diferentes** nas três tentativas desta execução (`fault`, `found pointer to free object` e outra vez `fault`), e em execuções anteriores do mesmo script foram vistos outros dois, `found bad pointer in Go heap` e `wirep: already in go`, que não ficaram guardados nos arquivos. Todos são mensagens que o coletor de memória ou o escalonador do Go imprime quando algo que ele esperava da máquina não acontece: não são um erro do `Dockerfile` nem do código do `revisor`. O que aponta para a emulação é que o mesmo `Dockerfile`, com o mesmo código, compila bem no processador nativo e com compilação cruzada (10.4.3). **O que foi medido é a falha, não sua causa**, e não é garantia de que ela ocorrerá em outra máquina: em um Mint com `amd64` emulando `arm64` o comportamento pode ser outro, e com outras versões do QEMU, também. O que se pode tomar como regra é o que diz a documentação: a emulação é a última opção, não a primeira, e uma falha diferente a cada tentativa é a assinatura de uma emulação que não consegue reproduzir bem o processador. Dito como condição medida e sem promessas: **em um Mac com chip da Apple, com Colima, a compilação emulada de Go para `amd64` falhou nas três tentativas da execução guardada, e nas execuções anteriores deste mesmo script**; se algo parecido acontecer, não se insista nem se tente consertar a emulação: compile-se no processador nativo e deixe-se o Go gerar o binário da outra plataforma (compilação cruzada), que é o que vem a seguir e o que foi medido com sucesso (código 0, 65 segundos, um binário por plataforma). A documentação do Docker menciona ainda outra saída, um construtor com nós nativos de cada arquitetura, que esta lição não testou.

#### 10.4.3 A compilação cruzada: três mudanças

A ideia é simples. A compilação (que é o trabalho pesado) roda **no processador nativo de quem constrói**, e apenas o *resultado* recebe o rótulo de outro processador. Para isso o `Dockerfile` muda em três lugares. Antes de substituí-lo, guarde-se o da Lição 8 com `cp Dockerfile Dockerfile.leccion8`. Este é o arquivo completo, `fig10_01.Dockerfile`, que na pasta do projeto se chama `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
# arquitectura por sí mismo, así que las etapas de compilación corren en la
# plataforma de quien construye ($BUILDPLATFORM) y solo cambia el destino del binario.

FROM --platform=$BUILDPLATFORM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c AS compilacion
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
# Las pone BuildKit solo: la plataforma para la que se está construyendo.
ARG TARGETOS TARGETARCH
# Un secreto de CONSTRUCCIÓN (por ejemplo, credenciales para módulos privados)
# se monta solo durante este RUN y no queda en ninguna capa. Este curso no usa
# módulos privados: el montaje es opcional (required=false) y queda como patrón.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    --mount=type=secret,id=netrc,target=/root/.netrc,required=false \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" \
      -o /out/revisor ./cmd/revisor \
 && mkdir -p /out/datos

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
ARG VERSION=desarrollo
LABEL org.opencontainers.image.title="revisor" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.source="https://www.habil.mx/es/cursos/docker/"
# ENV solo para valores por omisión que NO son secretos.
ENV REVISOR_PUERTO=8080 \
    REVISOR_REPORTE=/datos/reporte.json
COPY --from=binario /out/revisor /revisor
# La carpeta de datos, del usuario sin privilegios. Un volumen con nombre que se
# monte aquí por primera vez copia este dueño.
COPY --from=binario --chown=65532:65532 /out/datos /datos
USER 65532:65532
EXPOSE 8080
# La salud la revisa el propio binario: la imagen no tiene shell ni curl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/revisor", "healthcheck"]
# Señal de apagado explícita (es la de omisión; escribirla documenta la intención).
STOPSIGNAL SIGTERM
ENTRYPOINT ["/revisor"]
```

É o `Dockerfile` da Lição 8 com **três linhas de código diferentes** (mais um comentário novo que as explica e os comentários do cabeçalho); se os dois arquivos forem comparados com `diff`, o código só muda aqui:

1. `FROM --platform=$BUILDPLATFORM golang:…`. `BUILDPLATFORM` é uma variável que o BuildKit define sozinho: a plataforma da máquina que está construindo (aqui, `linux/arm64`). Com esta opção a etapa de compilação **roda nativa**, não importa para que plataforma seja a imagem final. A documentação a nomeia junto com `TARGETPLATFORM`, `TARGETOS` e `TARGETARCH` como argumentos predefinidos de construção ([Docker, «Multi-platform builds»](https://docs.docker.com/build/building/multi-platform/)).
2. `ARG TARGETOS TARGETARCH`. Declara, dentro da etapa `binario`, que se quer usar o sistema operacional e a arquitetura de **destino**. O BuildKit os define sozinhos (`linux` e `amd64`, ou `linux` e `arm64`, conforme a plataforma que estiver sendo montada); declará-los com `ARG` é o que os torna visíveis no `RUN`.
3. `GOOS=$TARGETOS GOARCH=$TARGETARCH` antes do `go build`. São as variáveis com as quais o compilador do Go decide para que sistema e processador gera o binário, e os nomes de arquitetura do Docker (`amd64`, `arm64`) coincidem com os do Go, como os da especificação do índice da seção 10.1.3. Com `CGO_ENABLED=0` (que já estava) o binário é estático e não precisa de um compilador de C do outro processador.

E uma coisa que **não** muda, de propósito: a etapa `final` (`FROM gcr.io/distroless/…`) não leva `--platform`. Essa etapa sim tem que ser da plataforma de destino, porque é a imagem que será entregue; o BuildKit escolhe sozinho a variante correta da base distroless para cada plataforma, e essa base está publicada para ambas. As duas etapas de compilação (`compilacion` e `pruebas`) rodam nativas **uma única vez**, no processador de quem constrói. Isso tem um limite que convém dizer: os testes do Go validam o **código** nesse processador; não executam o binário da outra plataforma. Para um serviço em Go puro é razoável, mas o binário `amd64` só é verificado de verdade executando-o em um `amd64`. Em 10.9.2 ele é executado.

#### 10.4.4 Medir a compilação cruzada

O bloco 3 do `fig10_03.sh` constrói com esse `Dockerfile` para **as duas plataformas** ao mesmo tempo:

```text
== 3. fig10_01.Dockerfile, para las DOS plataformas: compila cruzado
$ docker buildx build --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 -o type=local,dest=salida-cruzada cruzada > cruzada.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 65 s)
$ grep -oE '\[linux/[a-z0-9>-]+ (pruebas|binario) [0-9]/[0-9]\]' cruzada.log | sort -u
[linux/arm64 binario 1/1]
[linux/arm64 pruebas 1/1]
[linux/arm64->amd64 binario 1/1]
$ ls salida-cruzada
linux_amd64
linux_arm64
$ maquina salida-cruzada/linux_amd64/revisor; maquina salida-cruzada/linux_arm64/revisor
salida-cruzada/linux_amd64/revisor: 3e 00 = x86-64 (amd64)
salida-cruzada/linux_arm64/revisor: b7 00 = AArch64 (arm64)
```

O código de saída é 0: **funcionou**, e com `--no-cache`, sem truque. Levou 65 segundos porque compilou do zero (com o cache do Go das lições anteriores, seria muito menos; a seção 10.5 o faz em segundos). O mais interessante está no `grep`. As linhas que o BuildKit imprime ao executar cada passo levam entre colchetes **a plataforma em que o passo é executado**, e o que se vê é: `[linux/arm64 pruebas 1/1]`, os testes rodaram em `arm64`, a nativa. `[linux/arm64 binario 1/1]`, o binário de `arm64` foi compilado em `arm64`. E `[linux/arm64->amd64 binario 1/1]`: o binário de **`amd64`** foi compilado *em* `arm64` (a seta diz «daqui para lá»). Nenhum passo da construção foi executado em `amd64`, nem sequer emulado. É a prova de que o erro da seção anterior não precisou ser resolvido consertando o QEMU, e sim evitando-o.

A última parte da saída é a comprovação que importa: cada arquivo é mesmo para o processador que diz ser? O `ls` mostra uma pasta por plataforma. E a função `maquina` do script **lê os bytes**: um cabeçalho de executável do Linux (formato ELF) guarda nos bytes 18 e 19 o campo `e_machine`, que identifica o processador de destino, e `od -An -tx1 -j18 -N2` os imprime em hexadecimal. `3e 00` é a marca do x86-64 e `b7 00` a do AArch64. Ou seja, não se confia no nome da pasta: olhou-se o interior do arquivo. (Para a tabela completa de códigos, ela está na especificação do formato ELF; os dois usados aqui podem ser comprovados em qualquer máquina com o comando `file` do Mint, que além disso os escreve com nome.)

**Quando esta técnica não basta.** A compilação cruzada funciona porque o Go sabe gerar código para outra arquitetura sem ajuda de ninguém. Se o serviço dependesse de uma biblioteca de C (com `CGO_ENABLED=1`), ou se o passo de construção tivesse de *executar* programas do processador de destino (instalar pacotes com `apt` dentro de uma base `amd64`, por exemplo), a compilação cruzada não bastaria e se voltaria à emulação ou aos nós nativos. Esse não é o caso do `revisor`, e é uma das razões pelas quais o curso escolheu um serviço escrito em Go.

### 10.5 Construir para duas plataformas e publicar o índice

#### 10.5.1 O comando completo

Já se tem o `Dockerfile` e um registry. Falta o comando que constrói para as duas plataformas, anexa a lista de materiais e a proveniência, e envia tudo. É longo; lê-se por partes:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg VERSION=1.6.0 \
  --sbom=true \
  --provenance=mode=max \
  -t localhost:5000/curso-docker-revisor:1.6.0 \
  --push .
```

- `docker buildx build` é o construtor moderno do Docker (BuildKit). Hoje `docker build` é um alias de `docker buildx build` ([Docker, «docker build»](https://docs.docker.com/reference/cli/docker/build-legacy/)), de modo que os dois fazem o mesmo; para publicar várias plataformas o que faz falta é o BuildKit e um destino que guarde índices (um registry com `--push`, ou o *image store* do *containerd*).
- `--platform linux/amd64,linux/arm64` pede **uma imagem por plataforma**, separadas por vírgula.
- `--build-arg VERSION=1.6.0` é o mesmo argumento das lições anteriores; fica gravado no binário e no label `org.opencontainers.image.version`.
- `--sbom=true` acrescenta a **lista de materiais** (seção 10.6) e `--provenance=mode=max` a **proveniência** em seu modo mais detalhado (seção 10.7).
- `-t …:1.6.0` é a referência, que começa com o endereço do registry local, como em 10.3.
- `--push` é a diferença que é preciso entender. Quando se constrói para **uma** plataforma, a imagem cai no *image store* local. Uma imagem de **várias** plataformas é um índice, e o armazenamento clássico do Docker não sabe guardar índices, de modo que historicamente o `buildx` exigia enviá-las direto a um registry. Com o *image store* do *containerd* (o desta máquina, ver «Sobre as execuções») já é possível guardar localmente imagens de várias plataformas e com atestações ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)), mas o comando de entrega faz o que se quer de qualquer forma: construir e publicar em um só passo. Um aviso medido: com esse armazenamento, o `--push` **também deixa a imagem na máquina** (a seção 10.9.1 mostra isso com `docker image ls`), de modo que essa cópia local existe e convém não confundi-la com a publicada.

A documentação do Docker descreve as atestações assim: as que são anexadas com `--sbom` e `--provenance` ficam «como um manifesto no índice da imagem», e seus dados são guardados «como blobs JSON» ([Docker, «Build attestations»](https://docs.docker.com/build/metadata/attestations/)). Isso será visto com os próprios olhos em algumas linhas.

O bloco 2 do script `fig10_04.sh` o executa e extrai do log de construção as linhas em que o BuildKit diz o que escreveu:

```text
$ ./fig10_04.sh
== 1. Registro local
$ docker run -d --name curso-docker-registro-fig10 -p 127.0.0.1:5000:5000 registry:3.1.2 >/dev/null && echo registro arriba
registro arriba

== 2. Construir para dos plataformas, con SBOM y procedencia max, y publicar
$ docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . > ../construccion.log 2>&1; echo "construcción: código $?"
construcción: código 0
(tardó 1 s)
$ grep -E 'exporting (manifest|attestation manifest|manifest list) sha256' ../construccion.log | sed -E 's/^#[0-9]+ //; s/ done$//; s/ [0-9.]+s$//' | sort -u
exporting attestation manifest sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
exporting attestation manifest sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
exporting manifest list sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
exporting manifest sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
exporting manifest sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

(Aqui a tag é `fig10` em vez de `1.6.0`, por causa dos nomes de apoio.) O código é 0 e levou **um segundo**: já não compilou do zero porque o cache do Go e as camadas da construção anterior foram reaproveitados; a seção 10.4 mediu os 65 segundos da construção a frio. O `grep` procura as linhas em que o BuildKit informa o que *exportou*, e saem cinco, que se leem assim: dois **manifestos** (um por plataforma, `b99bf1ad…` e `959af91e…`), dois **manifestos de atestação** (também um por plataforma) e uma **manifest list**, que é o nome antigo do índice e que tem o *digest* `a4246c5f…`. A linha que importa lembrar é a última, o índice: **é o *digest* que representa «a 1.6.0» inteira**, todas as plataformas e todas as atestações.

#### 10.5.2 Ler o índice

Agora o bloco 3 pergunta ao registry como ficou a tag. É o resultado mais importante da seção:

```text
== 3. El índice que quedó en el registro
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10
Name:      localhost:5000/curso-docker-revisor:fig10
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
           
Manifests: 
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d6939a710e122a030ac13e0b68b8aabc87da4d2f5a2eb4214a692e239613f6f0
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.digest: sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
    vnd.docker.reference.type:   attestation-manifest
               
  Name:        localhost:5000/curso-docker-revisor:fig10@sha256:d062f35ed5df81b21edeea621c65531f19c4d4075a27418745ba9b08c2080311
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: 
    vnd.docker.reference.type:   attestation-manifest
    vnd.docker.reference.digest: sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
```

Linha por linha. `docker buildx imagetools inspect` é a ferramenta para ver, **no registry**, o que há por trás de uma referência; sua documentação a descreve como mostrar «os detalhes de uma imagem no registry» ([Docker, `buildx imagetools inspect`](https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/)). É uma leitura remota: não precisa que a imagem esteja na máquina local.

- `MediaType: application/vnd.oci.image.index.v1+json` diz que o que há por trás da tag é um **índice** em formato OCI (o de 10.1.3), não uma imagem solta.
- `Digest: sha256:a4246c5f…` é o *digest* do índice: o mesmo número da linha `exporting manifest list` da seção anterior. O que se escrever depois de `@` para identificar «a 1.6.0» é isto.
- Depois, `Manifests` lista **quatro entradas**, não duas. As duas primeiras são as imagens: `Platform: linux/amd64` com seu *digest* `b99bf1ad…` e `Platform: linux/arm64` com `959af91e…`. Cada uma é um manifesto de imagem (`…image.manifest.v1+json`) com suas camadas. Esses são os *digests* que o Docker olha quando, em uma máquina `amd64`, resolve a tag: escolhe a entrada cuja plataforma coincide com a da máquina (em uma `amd64`, resulta ser a primeira).
- As outras duas têm `Platform: unknown/unknown`. Não são imagens que alguém possa executar: são as **atestações**. A anotação `vnd.docker.reference.type: attestation-manifest` diz isso, e `vnd.docker.reference.digest` aponta **para qual imagem elas descrevem**. Note-se que `d6939a71…` aponta para `b99bf1ad…` (a de `amd64`) e `d062f35e…` aponta para `959af91e…` (a de `arm64`): cada plataforma tem seu próprio documento. Essa anotação é o fio que une um documento à sua imagem, e é o que permite que `imagetools inspect --format '{{index .SBOM "linux/amd64"}}'` encontre o SBOM correto.

Uma consequência que convém notar agora para entendê-la em 10.9: as atestações **viajam dentro do índice**, não são um arquivo à parte. Quem baixar a imagem pelo *digest* do índice traz, ou pode pedir, suas atestações; quem trabalhar com um manifesto de plataforma solto não as vê.

### 10.6 A lista de materiais (SBOM)

#### 10.6.1 O que é e para que serve

Uma **lista de materiais de software** (*Software Bill of Materials*, SBOM) é, segundo a documentação do Docker, a «lista de artefatos de software que uma imagem contém, ou que foram usados para construí-la» ([Docker, «Build attestations»](https://docs.docker.com/build/metadata/attestations/)). É o equivalente à lista de ingredientes de uma embalagem. Seu valor aparece no dia em que surge uma falha pública em uma biblioteca: sem lista, a pergunta «o que está rodando usa essa biblioteca?» obriga a abrir cada imagem; com lista, é uma busca. E é a mesma lista que os scanners usam para decidir o que conferir.

O formato que o `--sbom=true` escreve neste Docker é **SPDX**, «um padrão aberto para comunicar informações de listas de materiais de software» ([SPDX, «Overview»](https://spdx.dev/about/overview/)). As duas linhas do final da saída seguinte o comprovam: a versão do formato e quais ferramentas escreveram o documento.

#### 10.6.2 Lê-la

O bloco 4 do `fig10_04.sh` pede ao registry o SBOM de `linux/amd64` e o percorre com um template do Go (`--format '{{…}}'`):

```text
== 4. La lista de materiales (SBOM) de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .SBOM "linux/amd64").SPDX.packages}}{{.name}} {{.versionInfo}}{{println}}{{end}}' | sort
base-files 13.8+deb13u7
ca-certificates 20250419
github.com/habil/revisor UNKNOWN
media-types 13.0.0
netbase 6.5
sbom <no value>
stdlib go1.27.3
tzdata 2026c-0+deb13u1
tzdata-legacy 2026c-0+deb13u1
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .SBOM "linux/amd64").SPDX.spdxVersion}} {{(index .SBOM "linux/amd64").SPDX.creationInfo.creators}}'; echo
SPDX-2.3 [Organization: Anchore, Inc Tool: syft-v1.51.0 Tool: buildkit-v0.27.1]
```

O template: `.SBOM` é o mapa de SBOMs por plataforma; `index .SBOM "linux/amd64"` pega o dessa plataforma (a documentação do comando explica que o `index` serve justamente para escolher uma plataforma em imagens multiplataforma); `.SPDX.packages` é a lista de pacotes do documento SPDX; e `{{.name}} {{.versionInfo}}` imprime o nome e a versão de cada um, um pacote por linha. O `| sort` os ordena. São **nove** linhas, e cada uma conta uma história da imagem:

- `base-files`, `media-types`, `netbase`, `tzdata`, `tzdata-legacy` e `ca-certificates` são os pacotes do Debian que a base distroless traz. Algumas versões levam o sufixo `+deb13u7`, que é a revisão desse pacote no Debian 13. `tzdata` é o banco de dados de fusos horários (`2026c`); `ca-certificates` é a lista de autoridades de confiança que permite a um programa verificar certificados HTTPS (o `revisor` precisa dela para consultar serviços por `https`). Sem shell nem gerenciador de pacotes, o pouco que há na imagem é isto. Repare-se na versão de `ca-certificates`: `20250419`. Voltar-se-á a ela em 10.10.
- `stdlib go1.27.3` é a biblioteca padrão do Go com a qual o binário foi compilado. Não é um pacote do Debian e sim o que a linguagem deixa dentro de cada programa que gera: por isso a versão do compilador (a da etapa `golang:1.27.3-trixie`) aparece na lista, e por isso um scanner pode dizer «esta imagem traz Go 1.27.3» sem executá-la.
- `github.com/habil/revisor UNKNOWN` é o próprio programa: seu módulo do Go, com versão `UNKNOWN` (o scanner não encontrou uma versão para ler; a lição não investigou o porquê).
- `sbom <no value>` é uma linha estranha, e vale a pena dizê-lo em voz alta: não parece um pacote da imagem; é um elemento sem versão que o gerador acrescenta ao documento (a lição não investigou a origem dele), e o template imprime `<no value>` quando o campo falta. Foi deixado na saída de propósito para que não assuste quando for visto.

E o último comando responde à pergunta «quem escreveu isto?»: formato `SPDX-2.3`, feito pelo **Syft** (da Anchore, versão 1.51.0) por meio do BuildKit v0.27.1. Não foi escrito pelo `Dockerfile` nem digitado por alguém: o BuildKit lança um scanner de conteúdo *dentro* da construção (na proveniência da seção seguinte ele aparecerá como mais um «material», `buildkit-syft-scanner`), lê a imagem terminada e anota o que reconhece. Isso tem um limite que convém saber: **um SBOM gerado assim descreve o que o scanner reconhece**, e ele reconhece pacotes de sistema e módulos de linguagens conhecidas. Um arquivo copiado à mão para a imagem sem que nenhum gerenciador de pacotes o registre não aparece. A lista é um bom inventário, não uma prova de que não há mais nada.

### 10.7 A proveniência: com que foi construída

#### 10.7.1 O que é

O SBOM diz **o que** há dentro. A **proveniência** (*provenance*) diz **como foi feita**. O padrão SLSA a define como «informação verificável sobre artefatos de software que descreve onde, quando e como algo foi produzido» ([SLSA, «Provenance»](https://slsa.dev/spec/v1.0/provenance)). Para uma imagem Docker, isso inclui: que construtor a montou, para qual plataforma, que imagens base usou (com seu *digest*), que argumentos recebeu, e a que horas começou e terminou.

#### 10.7.2 Lê-la

O bloco 5 pede três coisas da proveniência de `linux/amd64`:

```text
== 5. La procedencia de linux/amd64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format 'tipo: {{(index .Provenance "linux/amd64").SLSA.buildType}}{{println}}construida EN: {{(index .Provenance "linux/amd64").SLSA.invocation.environment.platform}}'; echo
tipo: https://mobyproject.org/buildkit@v1
construida EN: linux/arm64
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{range (index .Provenance "linux/amd64").SLSA.materials}}{{.uri}}{{println}}{{end}}' | cut -c1-100
pkg:docker/docker/buildkit-syft-scanner@stable-1?platform=linux%2Farm64
pkg:docker/docker/dockerfile@1
pkg:docker/golang@1.27.3-trixie?digest=sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965
pkg:docker/gcr.io/distroless/static-debian13@nonroot?digest=sha256:516757106de35205efb70b91ba03f6f12
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json (index .Provenance "linux/amd64").SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
```

- `tipo: https://mobyproject.org/buildkit@v1` é o tipo de construção: «isto foi montado pelo BuildKit, no formato de proveniência que o BuildKit define». É apenas um identificador.
- `construida EN: linux/arm64` é **um segundo testemunho da compilação cruzada**: foi escrito pelo BuildKit, não por quem construiu. É uma declaração do construtor, sem assinatura: confirma o que já foi medido, mas não substitui uma verificação independente. Pediu-se a proveniência da imagem `linux/amd64` e o documento diz que ela foi construída *em* `linux/arm64`. É exatamente o que a seção 10.4 mediu: a imagem de `amd64` foi construída em uma máquina `arm64`, sem emular.
- Os **materiais** são tudo o que entrou na construção, com seu identificador de pacote (`pkg:docker/…`, em formato *purl*, um padrão para nomear pacotes) e, quando há, seu *digest*. Aparecem quatro: o scanner de SBOM (`buildkit-syft-scanner`), o frontend de Dockerfile (`dockerfile@1`, que é o que a primeira linha `# syntax=docker/dockerfile:1` pedia), a imagem de compilação (`golang@1.27.3-trixie`, com o *digest* `604106…` que a Lição 5 fixou) e a base final (`gcr.io/distroless/static-debian13@nonroot`, com `516757…`). Os `cut -c1-100` do comando cortam as linhas para que caibam; o *digest* completo está no documento. Esses dois *digests* são os do `Dockerfile`: a proveniência é uma segunda leitura, escrita pelo BuildKit, de que o que foi usado era o que foi fixado (sem assinatura: qualquer pessoa com permissão de enviar ao registry poderia anexar outra).
- Os argumentos (`args`) são o que o construtor recebeu: `build-arg:VERSION: 1.6.0`, o comando do frontend e sua fonte.

Uma precisão sobre os nomes de campo que acabam de ser lidos (`invocation`, `materials`, `metadata`): o Docker escreve por padrão a proveniência na versão 0.2 do esquema SLSA, e a 1.0 é ativada com `version=v1` (por exemplo, `--provenance=mode=max,version=v1`) ([Docker, «SLSA provenance»](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). Com `version=v1` os campos mudam de lugar e os templates desta seção não funcionariam do jeito que estão; esta lição não a mediu.

#### 10.7.3 `min` versus `max`: o aviso

Foi usado `--provenance=mode=max`. Há dois modos, e a diferença não é de gosto. A documentação diz que `min` é o que se acrescenta **por padrão** às imagens, que inclui «carimbos de tempo, o frontend, os materiais, o repositório e a revisão da fonte, a plataforma de construção e a reprodutibilidade», e que «os valores dos argumentos de construção, as identidades dos segredos e os metadados ricos de camadas **não** são incluídos no `mode=min`», por isso «é seguro para todas as construções». O modo `max` «inclui tudo o que há no `min`» e acrescenta a definição interna da construção (LLB), **uma cópia do Dockerfile codificada em base64** e mapas de fonte que ligam passos a camadas. E traz um aviso que precisa ser lido inteiro: o `max` **expõe os valores dos argumentos de construção**; se credenciais estiverem sendo passadas como `--build-arg`, é preciso reescrever a construção para usar montagens de segredos, porque «as montagens de segredos não vazam para fora da construção e nunca são incluídas nas atestações de proveniência» ([Docker, «SLSA provenance»](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)).

É o tipo de aviso em que se acredita mais quando é visto. O bloco 6 constrói a imagem de `arm64` duas vezes, uma em cada modo, **passando de propósito um argumento que o `Dockerfile` nem sequer declara**: `NOTA=curso-docker-nota-de-mentira`. O nome diz que é de mentira: é um texto inventado para o exercício, e é o que representaria qualquer valor que alguém passe por engano em um `--build-arg`. As duas construções são idênticas, exceto pelo modo de proveniência (o script as repete em um laço com `mode=min` e `mode=max`):

```bash
docker buildx build -q --platform linux/arm64 \
  --build-arg VERSION=1.6.0 --build-arg NOTA=curso-docker-nota-de-mentira \
  --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10-max --push .
```

Depois pergunta ao registry o que cada uma guardou:

```text
== 6. Modo min contra modo max, con un argumento que el Dockerfile ni declara
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-min --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: (no aparecen)
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA.invocation.parameters.args}}'; echo
{
  "build-arg:NOTA": "curso-docker-nota-de-mentira",
  "build-arg:VERSION": "1.6.0",
  "cmdline": "docker/dockerfile:1",
  "source": "docker/dockerfile:1"
}
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys; d=json.load(sys.stdin); print("campos:", sorted(d)); print("secretos:", d["invocation"]["parameters"].get("secrets", "(no aparecen)"))'
campos: ['buildConfig', 'buildType', 'builder', 'invocation', 'materials', 'metadata']
secretos: [{'id': 'netrc', 'optional': True}]
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10-max --format '{{json .Provenance.SLSA}}' | python3 -c 'import json,sys,base64; d=json.load(sys.stdin); i=d["metadata"]["https://mobyproject.org/buildkit@v1#metadata"]["source"]["infos"][0]; print(i["filename"]); print("\n".join(base64.b64decode(i["data"]).decode().splitlines()[:3]))'
Dockerfile
# syntax=docker/dockerfile:1
# fig10_01.Dockerfile — Lección 10: la imagen que se entrega: la de la Lección 8,
# construida para varias plataformas SIN emulación. Go compila para otra
```

O que se vê, comparando:

1. **Os argumentos.** No `min` só estão `cmdline` e `source`: **nem `VERSION` nem `NOTA`**. No `max` aparecem os dois com seu valor, incluindo a «nota de mentira». É isso que o aviso descreve: o que alguém passar por `--build-arg` fica escrito, legível, em um documento que viaja com a imagem e que qualquer pessoa que possa baixá-la pode ler. Se essa nota fosse um token, o token estaria ali.
2. **Os campos.** O `min` tem cinco campos (`buildType`, `builder`, `invocation`, `materials`, `metadata`); o `max` acrescenta `buildConfig`, que é a definição interna dos passos.
3. **Os segredos.** No `min`, `(no aparecen)`: nem sequer a identidade. No `max` aparece `[{'id': 'netrc', 'optional': True}]`: o **nome** do segredo de construção (`--mount=type=secret,id=netrc`) e que ele é opcional (`required=false`, como lembra o `Dockerfile`), **mas não seu conteúdo**. É o comportamento que a documentação promete: a montagem de segredos não vaza o valor; deixa, sim, registro de que a construção pediu um segredo com esse nome.
4. **O `Dockerfile` completo.** O último comando decodifica a cópia em base64 que o `max` guarda e mostra suas primeiras linhas: é o `Dockerfile` que foi usado, com seus comentários, à vista de qualquer pessoa. Se o `Dockerfile` tivesse um comentário com algo que não deve ser sabido, sairia aqui.

A decisão que se depreende e que o curso adota: **publica-se com `mode=max` porque a proveniência completa é o que torna útil a entrega, e mantém-se limpa a origem**: nenhum segredo passa por `ARG`, nem por `ENV`, nem por `--build-arg` (o hábito da Lição 6), e quando a construção precisa de um, ele entra por `--mount=type=secret`. Com isso o `max` não expõe segredos, mas publica o `Dockerfile` completo e os valores de todos os `--build-arg`: revisem-se ambos antes de publicar. Em uma equipe onde isso não possa ser garantido, `min` é o modo seguro, e a própria documentação o diz. O que **não** é aceitável é usar o `max` sem saber que essa diferença existe.

### 10.8 «Idêntica» não é «igual»: o que muda ao reconstruir

Uma pergunta natural depois de falar de *digests*: se a mesma versão é construída duas vezes, com o mesmo `Dockerfile` e o mesmo código, obtém-se o mesmo *digest*? Esperar-se-ia que sim. O que se mede é outra coisa, e convém saber antes de prometer «reprodutibilidade» a alguém. O bloco 7 reconstrói idêntico (com cache) e compara:

```text
== 7. Otra construcción idéntica: ¿qué digest cambia?
$ docker buildx build -q --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
antes:   índice sha256:a4246c5fa0b2cfdfedeed2a5a25cfd6869079d488ba7550e6990939b89420631
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{json .Manifest.Digest}}'; echo
"sha256:04c19cbec864dd3ff9ccf5d71d676244acecd31ae1e1d9c363006bfac903c571"
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:b99bf1ad954b261a0574f3128d8beb91a0f839524eefceb0816c1d3e5266180c
arm64 sha256:959af91ef514e97c5bba49bb0a2b31000808ce7c1e15e441487a1659162dd73c
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --format '{{(index .Provenance "linux/amd64").SLSA.metadata.buildStartedOn}}'; echo
2026-10-21T18:18:15.739444508-06:00
```

O *digest* do **índice** mudou: de `a4246c5f…` para `04c19cbe…`. Mas os de **cada plataforma** (com `--raw`, o JSON cru do índice, filtrado para as entradas de Linux) são **os mesmos**: `b99bf1ad…` para `amd64` e `959af91e…` para `arm64`. Por que o do índice mudou? Porque o índice inclui, entre suas entradas, as atestações, e a proveniência leva dentro a hora em que a construção começou (o último comando a mostra: `buildStartedOn`). Outra hora, outro documento de proveniência, outro *digest* de atestação, outro índice. As imagens em si não mudaram nem um bit. Consequência prática: **duas entregas da mesma coisa podem ter índices diferentes**, e quem fixa pelo *digest* do índice fixa também essa hora. É o correto (identifica *esta* entrega), mas não é o que muita gente imagina ao ler «o *digest* é a impressão do conteúdo».

O bloco 8 repete a construção com `--no-cache`, que obriga a refazer cada passo:

```text
== 8. Y otra más, ahora SIN caché (--no-cache): ¿siguen iguales los de cada plataforma?
$ docker buildx build -q --no-cache --platform linux/amd64,linux/arm64 --build-arg VERSION=1.6.0 --sbom=true --provenance=mode=max -t localhost:5000/curso-docker-revisor:fig10 --push . >/dev/null 2>&1; echo "construcción: código $?"
construcción: código 0
$ docker buildx imagetools inspect localhost:5000/curso-docker-revisor:fig10 --raw | python3 -c 'import json,sys; [print(m["platform"]["architecture"], m["digest"]) for m in json.load(sys.stdin)["manifests"] if m["platform"]["os"]=="linux"]'
amd64 sha256:37dd082fe87a0b2779067a9098dab82e3c7d53e9924fa668d41638d8602dccfd
arm64 sha256:d9875545824d329af2bc6c206f52acc80145926a0cff399591bc1b4d6876e0c3
```

Agora **também** mudaram os de cada plataforma (`37dd082f…` e `d9875545…`). Sem cache, nada é reaproveitado, e a imagem resultante tem um *digest* diferente ainda que o código, o `Dockerfile` e a versão sejam os mesmos. **O que foi medido é o fato; a causa não foi investigada** (o mais provável é algum carimbo de tempo guardado na configuração ou nas camadas, mas esta lição não o verificou, e isso não deve ser lido como um dado). A lição prática é sóbria: **não se promete a ninguém que reconstruir devolve o mesmo *digest***. Promete-se o contrário, que é mais útil: *este* digest, uma vez publicado, identifica *aquela* imagem enquanto existir no registry. Se a fonte tiver de ser reproduzível bit a bit, esse é outro tema (o das construções reproduzíveis), que esta lição não resolve nem promete.

### 10.9 Baixá-la por *digest* e executá-la como se deve

#### 10.9.1 Como em uma máquina que nunca a construiu

Publicar não serve de nada se não se comprova que a imagem pode ser *recebida*. A prova honesta é feita como se fosse o Tomás: uma máquina que não tem a imagem, que só conhece o registry e um *digest*. (Um aviso para não confundir os números: os *digests* do `fig10_02.sh`, de uma só plataforma, e os do `fig10_04.sh`, um índice de duas, são de imagens diferentes e por isso não coincidem.) No bloco 9 do `fig10_04.sh`, antes de baixar qualquer coisa, o script **apaga as cópias locais** que a construção deixou (com o *image store* do *containerd*, mesmo com `--push` a imagem fica também na máquina local) e comprova isso com `docker image ls` antes e depois, para que o único que exista seja o que o registry diz. Depois baixa-se por *digest*:

```text
== 9. Traerla por digest, no por etiqueta
(copias locales de localhost:5000/curso-docker-revisor que dejó la construcción)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
localhost:5000/curso-docker-revisor:fig10
localhost:5000/curso-docker-revisor:fig10-min
localhost:5000/curso-docker-revisor:fig10-max
(y después de borrarlas)
$ docker image ls localhost:5000/curso-docker-revisor --format '{{.Repository}}:{{.Tag}}' | grep . || echo '(ninguna)'
(ninguna)
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker run --rm localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version
1.6.0
$ docker image inspect --format '{{json .RepoDigests}}' localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52; echo
["localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52"]
```

(O *digest* deste bloco é o do índice que ficou no registry após a última construção do script; muda a cada execução.) O `docker pull -q` com `@sha256:…` baixou **apenas o que corresponde a este processador**. `docker run … version` imprime `1.6.0`: a versão que foi gravada na compilação. E `RepoDigests` é o campo de uma imagem local que guarda **de que registry e com que *digest* ela veio**: é a constância de que a cópia local não é uma construção própria e sim um download, e é o que permite, meses depois, perguntar «isto que está rodando, de onde saiu?».

Convém dizer o que se espera que aconteça aqui, ainda que a saída não o imprima. A especificação de distribuição da Open Container Initiative, o documento que define como os clientes falam com os registries, diz que os clientes «DEVERIAM verificar que o corpo da resposta coincide com o *digest* pedido» (no original, «SHOULD verify that the response body matches the requested digest»; [OCI, «Distribution Specification»](https://github.com/opencontainers/distribution-spec/blob/main/spec.md)). É uma recomendação aos clientes e esta lição não a mediu com uma imagem alterada de propósito; o que se tem é a regra prática: pedir por *digest* é pedir algo que pode ser comprovado, e uma referência com *digest* que não coincide deve ser uma falha e não «outra imagem».

#### 10.9.2 O que foi baixado, e o que não

O bloco 10 mostra algo que surpreende na primeira vez: das duas plataformas do índice, a máquina baixou uma.

```text
== 10. Lo que bajó a este equipo: solo su plataforma
$ docker image ls --tree localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 2>/dev/null | sed -E 's/@sha256:([0-9a-f]{12})[0-9a-f]+/@sha256:\1…/'
IMAGE                                                                                                              ID             DISK USAGE   CONTENT SIZE   EXTRA
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8…   6956d5334dc8       16.8MB         4.34MB        
├─ linux/amd64                                                                                                     37dd082fe87a           0B             0B        
└─ linux/arm64                                                                                                     d9875545824d       16.2MB         3.68MB        

$ docker save --platform linux/arm64 -o ../propia.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/arm64'
guardada: linux/arm64
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
Error response from daemon: no suitable export target found: image with reference localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 was found but does not provide the specified platform (linux/amd64)
[código de salida: 1]
```

E o bloco 11, que baixa a outra plataforma e tenta executá-la:

```text
== 11. Traer la OTRA plataforma, guardarla y probar a correrla (linux/amd64)
$ docker pull -q --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52
$ docker save --platform linux/amd64 -o ../otra.tar localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 && echo 'guardada: linux/amd64'
guardada: linux/amd64
$ docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:6956d5334dc8f4cabfce3b0a0b6bc11270c47bd8ea889078ad646b4a4d546c52 version 2>&1 | head -3
1.6.0
```

`docker image ls --tree` é a visão que mostra o índice e suas plataformas. Lê-se assim: em cima, a referência com o *digest* do índice; embaixo, uma linha por plataforma com seu próprio identificador. A coluna `DISK USAGE` dá a pista: `linux/arm64` ocupa **16.2 MB** em disco (a imagem do `revisor`: o mesmo tamanho medido nas lições 8 e 9, 16.2 MB) e `linux/amd64` ocupa `0B`. Está na lista porque o índice a menciona, mas **suas camadas não foram baixadas**. É eficiente (ninguém baixa o que não vai executar), e tem uma consequência prática que o último comando provoca de propósito: `docker save --platform linux/arm64` funciona, e `docker save --platform linux/amd64` falha com `no suitable export target found … does not provide the specified platform`. A documentação do `docker image save` diz exatamente isso: o `--platform` guarda apenas as plataformas indicadas, e «um erro é produzido se a plataforma dada não estiver presente no *image store* local» ([Docker, `docker image save`](https://docs.docker.com/reference/cli/docker/image/save/)). A moral do erro: **se o arquivo da outra plataforma for necessário, é preciso baixá-la primeiro**; guardar não a baixa. O bloco 11 faz isso e, de passagem, responde à pergunta que a seção 10.4 deixou aberta: o binário da outra plataforma inicia de verdade?

O bloco 11 da saída acima se lê assim. `docker pull -q --platform linux/amd64 …@sha256:…` baixa as camadas da plataforma que faltava (a referência é a mesma; `--platform` escolhe a entrada do índice). Com ela no *image store*, o mesmo `docker save --platform linux/amd64` que havia falhado agora responde `guardada: linux/amd64`. E o último comando, `docker run --rm --platform linux/amd64 … version`, imprime `1.6.0`: **o binário de `amd64` iniciou e respondeu**. É preciso dizer em que condições isso foi medido, para não prometer demais: esta máquina é `arm64`, de modo que esse binário rodou **emulado** pelo QEMU; é uma prova de que o arquivo é um executável `amd64` válido que inicia, não uma prova de como ele se comporta em um `amd64` real, e iniciar um binário estático pequeno é uma exigência muito menor do que compilar com Go (que foi o que a emulação não aguentou em 10.4.2).

**Em uma máquina `amd64` (como o Mint do curso), esta é a comprovação que cabe a quem estuda**, e é a que de verdade conta: o mesmo comando, `docker run --rm --platform linux/amd64 localhost:5000/curso-docker-revisor@sha256:… version`, agora roda nativo. Em uma máquina `arm64`, a plataforma «da outra» é `linux/amd64` e a saída acima é a que deve ser obtida. Nos dois casos o resultado esperado é `1.6.0`.

Isso importa de imediato, porque a varredura da seção seguinte é feita sobre um `docker save`, e varre **uma** plataforma. Um índice de duas plataformas é varrido em duas passadas. Nesta lição o script varre a do processador da própria máquina, e essa limitação é dita em voz alta em 10.10.

#### 10.9.3 Executá-la reforçada: montar `/datos` outra vez

A imagem da Lição 8 guarda seu relatório em `/datos`, e desde a Lição 7 é executada com `--read-only`: o sistema de arquivos do contêiner é somente leitura. Isso tem uma consequência que já foi medida na Lição 8 e que aqui se vê de novo, com a imagem **baixada por *digest***, como outra pessoa a receberia: se nada for montado em `/datos`, o `revisor` saudável não consegue guardar seu relatório. O bloco 5 do `fig10_02.sh` executa a imagem com todas as medidas e **sem volume**:

```text
== 5. La de digest, endurecida como en la Lección 8: sin nada en /datos
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"1.6.0"}
$ curl -s -w ' [%{http_code}]\n' http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

O primeiro comando cria o contêiner com as medidas das lições 7 e 8 (`--read-only`, `--cap-drop ALL`, `--security-opt no-new-privileges`, `--init`) e a referência **por *digest***; o `>/dev/null && echo` apenas esconde o identificador e confirma que terminou bem. Depois, `/salud` responde `vivo` e `1.6.0`: o processo iniciou e a imagem é a que foi pedida. Em seguida, `/api/estados` responde `500` com uma mensagem que se interpreta da direita para a esquerda, como nas lições 6 e 8: `read-only file system` quem diz é o kernel (não se pode escrever ali), `open /datos/.reporte-<n>.tmp` diz qual arquivo (o temporário que o `revisor` escreve antes de renomeá-lo) e `no pude guardar el reporte` é acrescentado pelo `revisor`, que prefere responder `500` a fingir que tudo saiu bem. Não é um defeito da imagem entregue: é o sistema somente leitura funcionando como foi pedido. A solução é a de sempre, **montar algo gravável em `/datos`**:

```text
== 6. La misma, con un volumen en /datos (un contenedor no recibe un volumen después: se borra y se crea otro)
$ docker rm -f curso-docker-revisor-fig10 >/dev/null && echo 'contenedor anterior borrado'
contenedor anterior borrado
$ docker run -d --name curso-docker-revisor-fig10 -p 127.0.0.1:8080:8080 --read-only --cap-drop ALL --security-opt no-new-privileges --init -v curso-docker-reportes-fig10:/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' localhost:5000/curso-docker-revisor@sha256:59e431fa44c713637b6d1459ee762bb266764eb80941d7e9aec9109f6bf22b0c >/dev/null && echo 'contenedor arriba'
contenedor arriba
$ curl -s -o /dev/null -w '[%{http_code}]\n' http://127.0.0.1:8080/api/estados
[200]
$ docker inspect --format '{{.Config.Image}}' curso-docker-revisor-fig10 | sed -E 's/@sha256:([0-9a-f]{12}).*/@sha256:\1…/'
localhost:5000/curso-docker-revisor@sha256:59e431fa44c7…
```

Um contêiner não pode receber um volume depois de criado: por isso o bloco 6 começa apagando o anterior (`docker rm -f`) e cria outro com a mesma receita mais `-v curso-docker-reportes-fig10:/datos` (o volume de apoio do script; na pasta do projeto: `--name curso-docker-revisor` e `-v curso-docker-reportes:/datos`, o volume da Lição 8). Desta vez `/api/estados` responde `200`. E a última linha é o fechamento do que a seção «O porquê antes do como» prometia: `docker inspect` diz que o contêiner foi criado **com uma referência por *digest***. Nada em sua história depende de uma tag continuar apontando para onde apontava. Lembre-se de que o volume novo herda o dono `65532` da pasta que a imagem traz (Lição 8); por isso aqui não é preciso `--user` nem `chmod`.

Uma observação sobre `-e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud'`: é o serviço que o `revisor` consulta. Aqui é **ele mesmo**, em seu próprio `/salud`, para que o teste não dependa de nenhum outro contêiner. É uma forma de testar a imagem isolada, e a mesma que o pod do `kind` da seção 10.11 usa.

### 10.10 Varrer com o Trivy o que se entrega

#### 10.10.1 O que um scanner faz, e o que não faz

Um **scanner de vulnerabilidades** pega a lista do que há dentro de uma imagem (pacotes do sistema, módulos de linguagem, o próprio binário do Go) e a compara com **bases de dados de falhas conhecidas**. Cada falha pública tem um identificador (um número CVE, ou o da distribuição, como os *DSA* do Debian), uma gravidade e, às vezes, uma versão corrigida. O **Trivy** é um scanner de código aberto, feito pela Aqua Security, que roda como um programa de linha de comando, e aqui é usado a partir de sua imagem oficial `aquasec/trivy:0.76.0`, publicada em 14 de outubro de 2026 ([notas da versão 0.76.0](https://github.com/aquasecurity/trivy/releases/tag/v0.76.0)).

Dois avisos de entrada. O primeiro: **um scanner responde «que problemas *conhecidos* isto tem *hoje*?»**. Não responde «é seguro?». Um resultado de zero achados significa «nenhuma falha das que minha base de dados conhece, hoje, nos pacotes que reconheci»; amanhã pode deixar de ser zero sem que a imagem mude, porque uma falha nova será publicada. O segundo: a qualidade do resultado depende da atualidade da base de dados, e por isso o bloco 6 do `fig10_05.sh` a mede.

#### 10.10.2 O erro: pedir a imagem pelo nome

Para este exercício parte-se de uma imagem local com nome simples: o bloco 1 do `fig10_05.sh` a constrói com `docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 .` (na pasta do projeto, `curso-docker-revisor:1.6.0`), e `docker image ls` confirma seus 16.2 MB. O primeiro instinto é o comando curto: `trivy image minha-imagem`. Como o Trivy roda dentro de um contêiner, e a imagem está no Docker local, ele não a encontra. Sai um erro longo com uma lição valiosa. O bloco 2 do `fig10_05.sh` o provoca e o filtra:

```text
== 2. El error: pedirle a Trivy la imagen por su nombre, sin socket
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 image --quiet curso-docker-revisor:fig10 2>&1 | grep -oE 'unable to find the specified image.*|^\s+\* [a-z]+ error: .*' | cut -c1-120
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]: 4 erro
	* docker error: unable to inspect the image (curso-docker-revisor:fig10): failed to connect to the docker API at un
	* containerd error: containerd socket not found: /run/containerd/containerd.sock
	* podman error: unable to initialize Podman client: no podman socket found: stat podman/podman.sock: no such file or di
	* remote error: GET https://index.docker.io/v2/library/curso-docker-revisor/manifests/fig10: UNAUTHORIZED: authenti
[código de salida: 1]
```

Leitura. O comando monta um volume (`-v curso-docker-trivy-cache-fig10:/root/.cache`) onde o Trivy guarda sua base de dados para não baixá-la a cada execução, e lança `image --quiet curso-docker-revisor:fig10`. O `grep -oE` conserva apenas a linha do erro principal e as quatro tentativas fracassadas; o `cut` corta cada uma em 120 caracteres. A mensagem diz que o Trivy **procurou a imagem em quatro lugares**, nesta ordem: `docker` (falando com o daemon por seu *socket*), `containerd`, `podman` e `remote` (um registry). É a mesma ordem que o Trivy documenta: procura «primeiro no motor do Docker local, depois no *containerd*, no *podman* e, por último, em um registry de contêineres» ([Trivy, «Container Image»](https://trivy.dev/latest/docs/target/container_image/)). Em cada um falhou: o *socket* do Docker não está dentro do contêiner (`failed to connect to the docker API`), não há `containerd` nem `podman`, e como último recurso tentou baixar `curso-docker-revisor` do Docker Hub, onde não existe (`UNAUTHORIZED`).

A solução «de tutorial» para o primeiro erro é montar o *socket* do Docker dentro do contêiner do Trivy (`-v /var/run/docker.sock:/var/run/docker.sock`). **Não se deve fazer isso.** É o que a Lição 2 ensinou a não fazer: quem tem o *socket* do Docker controla o Docker, e portanto controla a máquina com as permissões de `root`. Entregá-lo a um contêiner para que «leia» uma imagem é dar a chave de tudo a um programa que, além disso, baixa dados da internet cada vez que roda. O caminho correto dá o mesmo resultado sem entregar nada: **guardar a imagem em um arquivo e entregar o arquivo ao Trivy**.

#### 10.10.3 Guardar e varrer o arquivo

O Trivy aceita imagens guardadas: sua documentação o diz, com o exemplo de `docker save` seguido de `trivy image --input arquivo.tar` ([Trivy, «Container Image»](https://trivy.dev/latest/docs/target/container_image/)), e a referência do comando descreve `--input` como o «caminho de um arquivo de entrada em vez de um nome de imagem» ([Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)). O bloco 3 faz as duas coisas:

```text
== 3. Guardar la imagen en un archivo y escanear el archivo
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --severity HIGH,CRITICAL --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#'

Report Summary

┌──────────────────────────────────────────┬──────────┬─────────────────┬─────────┐
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
├──────────────────────────────────────────┼──────────┼─────────────────┼─────────┤
│ revisor                                  │ gobinary │        0        │    -    │
└──────────────────────────────────────────┴──────────┴─────────────────┴─────────┘
Legend:
- '-': Not scanned
- '0': Clean (no security findings detected)
```

O primeiro comando guarda a imagem em um arquivo `.tar` de 3.6 MB, **apenas da plataforma da máquina** (`--platform linux/arm64`; em um Mint seria `linux/amd64`). Os 3.6 MB são a imagem comprimida; os 16.2 MB que o `docker image ls` mostrava são descomprimidos. O segundo comando, por partes:

- `docker run --rm` lança o Trivy e o apaga ao terminar; `-v curso-docker-trivy-cache-fig10:/root/.cache` é o cache da base de dados (na pasta do projeto, `-v curso-docker-trivy-cache:/root/.cache`), em um **volume nomeado** para que sobreviva entre execuções e possa ser apagado no final.
- `-v "$PWD":/trabajo:ro` monta a pasta atual em `/trabajo`, **somente leitura** (`:ro`): o Trivy pode ler o `.tar`, não escrever na pasta. É o privilégio mínimo aplicado ao scanner.
- `image --quiet --input /trabajo/revisor-1.6.0.tar` pede para varrer o arquivo, sem a barra de progresso.
- `--severity HIGH,CRITICAL` fixa o **limiar**: reporta apenas as falhas graves e críticas. A documentação de filtragem o ilustra com exatamente esta opção ([Trivy, «Filtering»](https://trivy.dev/latest/docs/configuration/filtering/)).
- `--exit-code 1` diz ao Trivy que código de saída devolver «quando encontrar problemas de segurança» (assim o descreve a referência do comando). Por padrão ele sai com 0 mesmo encontrando coisas (o bloco 4b mede isso); com `1`, um script ou um *pipeline* pode **falhar** se houver achados. Esse é o truque que converte um relatório em um portão de qualidade (*gate*).
- O `sin_fechas` e o `sed` são de apresentação no script: o primeiro remove os avisos com carimbo de hora que o Trivy imprime no início da linha (para que a saída possa ser comparada entre execuções) e o segundo encurta `/trabajo/` para `./`. Não são necessários ao executar o comando por conta própria.

A tabela se lê de cima para baixo. `Report Summary` é o cabeçalho; cada linha é um **alvo** varrido. O primeiro é `./revisor-1.6.0.tar (debian 13.7)`, do tipo `debian`: os pacotes do sistema da base, com **0** achados. O segundo é `revisor`, do tipo `gobinary`: o Trivy reconheceu que dentro do arquivo há um binário de Go, leu os módulos que ele traz gravados e os revisou também, com **0** achados. A coluna `Secrets` diz `-`. O Trivy procura vulnerabilidades e segredos por padrão (a referência do `trivy image` dá `vuln,secret` como valor de `--scanners`), mas para os segredos só registra achados, de modo que a documentação esclarece que o `-` dessa coluna significa «sem achados» e não distingue entre «não se procurou» e «procurou-se e não havia nada» ([Trivy, «Reporting»](https://trivy.dev/latest/docs/configuration/reporting/)). Outra razão para não ler um zero como garantia. E o `0` da legenda diz `Clean (no security findings detected)`: «limpo, sem achados de segurança detectados». Com o limiar `HIGH,CRITICAL`, o código de saída foi 0, e por isso o script não imprime `[código de salida: …]`. Repare-se na palavra da legenda: *detected*. É a nuance do aviso anterior.

#### 10.10.4 O limiar decide o que se vê, e `UNKNOWN` também conta

Agora a mesma imagem, **sem** `--severity`, com o mesmo `--exit-code 1`. O bloco 4 a varre com todas as gravidades e filtra o resultado para deixar as tabelas:

```text
== 4. El mismo archivo, con todas las severidades y el mismo --exit-code 1
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1 | sin_fechas | sed 's#/trabajo/#./#' | grep -E 'Total|│' 
│                  Target                  │   Type   │ Vulnerabilities │ Secrets │
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
│ revisor                                  │ gobinary │        0        │    -    │
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
│     Library     │ Vulnerability │ Severity │ Status │ Installed Version │  Fixed Version   │               Title               │
│ ca-certificates │ DSA-6572-1    │ UNKNOWN  │ fixed  │ 20250419          │ 20250419+deb13u1 │ ca-certificates - security update │
[código de salida: 1]
```

Aparece **um achado** que o limiar anterior escondia. É preciso ler cada coluna da última tabela: `Library` é o pacote (`ca-certificates`, o da lista de materiais de 10.6); `Vulnerability` é o identificador (`DSA-6572-1`, uma *Debian Security Advisory*, aviso de segurança do Debian); `Severity` é `UNKNOWN`, desconhecida; `Status` é `fixed`, corrigida; `Installed Version` é `20250419`, a que a imagem tem; `Fixed Version` é `20250419+deb13u1`, a versão do Debian que já corrige a falha; e `Title` é o título do aviso. Uma linha resume: `Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)`. As categorias são cinco e assim o Trivy as lista em seu resumo: `UNKNOWN`, `LOW`, `MEDIUM`, `HIGH`, `CRITICAL` ([Trivy, «Reporting»](https://trivy.dev/latest/docs/configuration/reporting/)). Quatro vão de menor a maior gravidade; `UNKNOWN` não é «menos grave que `LOW`»: é «sem classificação». A documentação do Trivy diz que ela é usada quando nenhuma fonte atribuiu uma gravidade ao achado («se nenhum provedor tem uma severidade, `UNKNOWN` será usada»; [Trivy, «Vulnerability»](https://trivy.dev/latest/docs/scanner/vulnerability/)). Por isso ela não é descartada sem ser examinada.

Três lições neste bloco:

1. **O limiar é uma decisão de quem varre, não um detalhe.** Com `HIGH,CRITICAL` a imagem «passa»; com todas as gravidades tem um achado. Nenhuma das duas é mentira, mas respondem a perguntas diferentes. Escolha-se o limiar antes de olhar o resultado, e escreva-se (no *pipeline*, no README do projeto) para que ninguém o ajuste depois a fim de que saia verde.
2. **`UNKNOWN` conta.** O achado é de gravidade `UNKNOWN`, e ainda assim `--exit-code 1` devolveu **1** (a linha `[código de salida: 1]`). Ou seja: sem `--severity`, até o que o scanner não sabe classificar derruba o portão. Se a preferência for que o desconhecido não falhe, declare-se isso com `--severity` listando as gravidades que importam. O que não convém é não saber.
3. **Um achado `fixed` é acionável.** O estado `fixed` e a coluna `Fixed Version` dizem que há uma versão corrigida. A solução não é esquecê-lo nem desligar o scanner: é atualizar o pacote. Como se atualiza um pacote de uma base distroless que foi fixada por *digest* é o tema da seção 10.12.

E o contraste que explica para que serve o `--exit-code`. O bloco 4b executa **a mesma varredura sem essa opção** e pede o código de saída do próprio Trivy com `echo "código de Trivy: $?"`:

```text
== 4b. Lo mismo, sin --exit-code: ¿con qué código sale Trivy por omisión?
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 0
```

Mesmo achado (`Total: 1`) e código **0**. Sem `--exit-code`, o Trivy informa mas não falha: um script que apenas o lança seguiria adiante com um achado grave sem perceber. Foi medido, não suposto: uma varredura em um *pipeline* sem `--exit-code` é um enfeite que diz «tudo bem» mesmo havendo achados. É o mesmo tipo de armadilha que já se conhece das lições anteriores: o código de saída é o que a máquina lê, e é preciso comprovar que ele realmente muda quando deve.

#### 10.10.5 `--ignore-unfixed`: uma intuição que dá errado

Há uma opção que parece o caminho fácil: `--ignore-unfixed`, que a referência do comando descreve como «mostrar apenas as vulnerabilidades corrigidas» (*display only fixed vulnerabilities*, [Trivy, `trivy image`](https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/)) e que a página de filtros apresenta como a forma de «ignorar todas as vulnerabilidades sem correção» (*skip all unfixed vulnerabilities*, [Trivy, «Filtering»](https://trivy.dev/latest/docs/configuration/filtering/)). A intuição diz: «ignoremos o que não tem correção, para que só falhe o que posso corrigir». O bloco 5 a testa, e é preciso ler bem o nome:

```text
== 5. ¿Y si se ignora lo que no tiene arreglo?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignore-unfixed --exit-code 1 2>&1 | sin_fechas | grep -E '^Total'
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
[código de salida: 1]
```

Continua o mesmo achado e continua o código 1. E não é um erro do Trivy: `--ignore-unfixed` esconde o que **não tem** versão corrigida, e este achado **tem** (`fixed`, `20250419+deb13u1`). A opção faz o que diz; o que ela não faz é resolver o problema, porque o problema é dos que têm correção. É um bom exemplo de por que uma opção se testa em vez de se assumir o que ela faz pelo nome.

#### 10.10.6 De quando é o que ele sabe?

O último bloco responde a uma pergunta que deveria acompanhar toda varredura: contra que data foi comparada?

```text
== 6. ¿De cuándo es la base de datos de vulnerabilidades?
$ docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache aquasec/trivy:0.76.0 version 2>&1 | sin_fechas
Version: 0.76.0
Vulnerability DB:
  Version: 2
  UpdatedAt: 2026-10-21 19:18:22.876313144 +0000 UTC
  NextUpdate: 2026-10-22 19:18:22.876312904 +0000 UTC
  DownloadedAt: 2026-10-22 00:17:14.540681058 +0000 UTC
```

`trivy version` imprime a versão do programa e os dados de sua base de dados: quando a última versão foi **publicada** (`UpdatedAt`: 21 de outubro, 19:18 UTC), quando se espera a seguinte (`NextUpdate`: um dia depois) e quando foi **baixada** para o cache (`DownloadedAt`). As três linhas do final são as que se guardam junto ao resultado da varredura: um «0 achados» sem data da base de dados é um dado sem idade, e dados sem idade apodrecem.

Dois limites da varredura feita assim, que a lição já deixou ver e agora se juntam. Um: varreu-se **uma plataforma**, a da máquina; o `amd64` do índice não foi revisado. Para uma entrega real, repetem-se o `docker save --platform` e a varredura para cada plataforma publicada. Dois: o scanner revisa o que há *dentro* da imagem; não revisa o `Dockerfile` nem as permissões de execução (isso foi coberto pelo `docker build --check` na Lição 3 e pelas medidas das lições 7 e 8). É uma camada de defesa, não a defesa.

### 10.11 A ponte para o Kubernetes: `kind load docker-image`

#### 10.11.1 Por que o cluster não enxerga a imagem

O curso seguinte, o de Kubernetes com `kind`, pega a imagem com que se sai daqui. O `kind` (*Kubernetes IN Docker*) sobe um cluster Kubernetes dentro de contêineres Docker: cada «nó» do cluster é um contêiner. Isso tem uma consequência que surpreende: embora o nó rode no Docker local, **ele tem seu próprio *image store*** por dentro. O que foi construído com `docker build` vive no *image store* do Docker, e o nó não o enxerga. Um pod que peça `curso-docker-revisor:1.6.0` tentaria baixá-la de um registry, e essa imagem está só na máquina local.

Há duas formas de resolver: publicar a imagem em um registry que o cluster consiga alcançar, ou **carregá-la diretamente nos nós**. Em um laboratório local, a segunda é a curta, e é a que esta lição usa. A documentação do `kind` a apresenta assim: «é possível carregar uma ou mais imagens no cluster `kind`» com `kind load docker-image minha-app:latest`, e se o cluster tiver nome, é preciso indicá-lo com `--name` ([kind, «Quick Start»](https://kind.sigs.k8s.io/docs/user/quick-start/)). A mesma página traz um aviso com duas condições que são justamente o que se verá: «a política de download padrão do Kubernetes é `IfNotPresent`, a menos que a tag seja `:latest` ou não seja escrita»; para que as imagens carregadas funcionem como esperado, **não se deve usar a tag `:latest`** e/ou se deve especificar `imagePullPolicy: IfNotPresent` ou `imagePullPolicy: Never` no contêiner.

A política `Never` é a que o teste usa. A documentação do Kubernetes a define assim: «o kubelet não tenta baixar a imagem. Se a imagem já estiver presente localmente, o kubelet tenta iniciar o contêiner; se não, a inicialização falha» ([Kubernetes, «Images»](https://kubernetes.io/docs/concepts/containers/images/)). Para um teste é a política ideal, porque ajuda a não esconder problemas de transporte: se a imagem não chegou ao nó, o pod não inicia e diz isso, em vez de tentar baixá-la da internet e demorar (ou, pior, baixar *outra* imagem com o mesmo nome). Um limite: se o nó já tivesse uma imagem velha com essa mesma tag, o `Never` a iniciaria sem avisar; por isso em testes se usa um cluster novo ou uma versão nova.

#### 10.11.2 Instalar `kind` e `kubectl`

Até agora tudo foi feito com Docker. Este passo precisa de dois programas a mais que **não** foram instalados nas lições anteriores: `kind` e `kubectl`. Em um Linux Mint como o do curso, instalem-se com os guias oficiais, com a versão fixada (as deste curso, medidas em 21 de outubro de 2026). O `kind` é baixado como um binário ([kind, «Quick Start»](https://kind.sigs.k8s.io/docs/user/quick-start/)); o `kubectl`, de `dl.k8s.io`, com uma verificação de sua soma `sha256` ([Kubernetes, «Install and Set Up kubectl on Linux»](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)):

```bash
# kind v0.33.0 (elige la línea de tu procesador; `uname -m` dice x86_64 o aarch64)
[ "$(uname -m)" = x86_64 ]  && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
[ "$(uname -m)" = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl v1.37.1
ARQ=amd64; [ "$(uname -m)" = aarch64 ] && ARQ=arm64
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl"
curl -LO "https://dl.k8s.io/release/v1.37.1/bin/linux/$ARQ/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

As duas primeiras linhas do `kind` são as do guia oficial: cada uma é executada somente se o processador for o que ela diz, de modo que em cada máquina roda exatamente uma. A linha do `sha256sum --check` é a que protege o download: deve responder `kubectl: OK`; se responder `FAILED`, apague-se o arquivo e baixe-se de novo. `sudo install -o root -g root -m 0755` copia o programa para `/usr/local/bin` com dono `root` e permissão de execução, que é a forma que o guia indica. A sequência de download e verificação foi testada dentro da máquina virtual das execuções (Ubuntu 24.04, `arm64`), com o script `fig10_00.sh` (blocos 2 e 3, com sua saída ao lado), sem a instalação em `/usr/local/bin` para não alterar o sistema, e respondeu:

```text
$ ./kind version
kind v0.33.0 go1.26.7 linux/arm64
$ echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
kubectl: OK
$ ./kubectl version --client
Client Version: v1.37.1
Kustomize Version: v5.8.1
```

(A versão do Go com a qual o `kind` foi compilado muda conforme a plataforma onde ele é executado: no Mac das execuções disse `go1.27.0 darwin/arm64`.) Confira-se a instalação com `kind version` e `kubectl version --client`.

#### 10.11.3 O cluster e a imagem

O script `fig10_06.sh` é executado no **Mac** (não dentro da máquina virtual) porque ali vivem o `kind` e o `kubectl`; eles falam com o mesmo daemon do Docker. Tem um detalhe que convém explicar antes de ler a saída: usa um arquivo de configuração do `kubectl` **próprio e temporário** (`export KUBECONFIG=…` dentro do script). Assim o cluster que ele cria não modifica o contexto do `kubectl` nem o arquivo `~/.kube/config`. **Na máquina de quem acompanha a lição, o desejável é o contrário:** que o `kind` mude o contexto para o cluster novo, e por isso os comandos abaixo não levam `KUBECONFIG`. Mesmo assim, e é um costume que vale a pena desde hoje, **antes de cada comando de `kubectl` confira-se em que cluster se está** com `kubectl config current-context`: um `kubectl delete` no contexto errado é o tipo de erro que não se desfaz.

As primeiras seções do script:

```text
$ ./fig10_06.sh
== 1. Versiones
$ kind version
kind v0.33.0 go1.27.0 darwin/arm64
$ kubectl version --client | head -1
Client Version: v1.37.1

== 2. La imagen, para la plataforma de este equipo
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker image ls curso-docker-revisor:fig10 --format '{{.Repository}}:{{.Tag}} {{.Size}}'
curso-docker-revisor:fig10 16.2MB

== 3. Un clúster kind de un nodo
$ kind create cluster --name curso-docker-puente-fig10 --wait 120s 2>&1 | grep -E '^Creating|Ready after|Set kubectl context' | sed -E 's/Ready after [0-9]+s/Ready after Ns/; s/ +[^ -~]+//g'
Creating cluster "curso-docker-puente-fig10" ...
 Ready after Ns
Set kubectl context to "kind-curso-docker-puente-fig10"
$ kubectl config current-context
kind-curso-docker-puente-fig10
```

As versões são as do curso: `kind` v0.33.0, que por padrão usa a imagem de nó `kindest/node:v1.37.0`, isto é, Kubernetes 1.37.0 ([kind, notas da v0.33.0](https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0)), e `kubectl` v1.37.1. Depois, `docker build` constrói a imagem **para a plataforma desta máquina** (aqui `arm64`). Na pasta do projeto, o comando é `docker build --build-arg VERSION=1.6.0 -t curso-docker-revisor:1.6.0 .`, que deixa a imagem no Docker com o nome que o curso seguinte usará; o script usa a tag de apoio `fig10`. `docker build` simples constrói para a plataforma nativa e deixa o resultado no *image store* local, que é justamente o que o `kind load` vai ler. Pesa 16.2 MB. `kind create cluster --name … --wait 120s` cria o cluster de um nó e espera até dois minutos para que esteja pronto; o `grep` e o `sed` do script deixam apenas as três linhas que importam (o resto são indicadores de progresso com símbolos), e a hora real (`Ready after Ns`) é encoberta porque muda de uma execução para outra. O `kind` terminou fixando o contexto: `kubectl config current-context` responde `kind-curso-docker-puente-fig10`. O contexto que o `kind` cria se chama `kind-` mais o nome do cluster (assim saiu na execução), de modo que o prefixo do curso (`curso-docker-`) é herdado até o nome do contexto.

#### 10.11.4 Provocar o erro antes da solução

O concreto primeiro: pede-se o pod **antes** de carregar a imagem e lê-se o que ele diz. Este é o bloco 4:

```text
== 4. El error: el pod ANTES de cargar la imagen
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
$ kubectl get events --field-selector involvedObject.name=revisor,reason=ErrImageNeverPull -o custom-columns=MENSAJE:.message | head -2 | cut -c1-110
MENSAJE
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
```

`kubectl run revisor --image=… --image-pull-policy=Never --port=8080 --env=…` cria um pod com um contêiner. `--image-pull-policy=Never` é a política de acima; `--port=8080` declara a porta que ele escuta; `--env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'` é a mesma variável das seções anteriores (o `revisor` consulta a si mesmo, para que o teste não dependa de outro pod). Depois, `kubectl get pod … -o custom-columns=…` imprime uma tabela com as colunas escolhidas, com seus caminhos dentro do objeto do pod: o estado (`phase`) é `Pending` e a razão de espera (`waiting.reason`) é **`ErrImageNeverPull`**. O nome já conta a história: erro de imagem, com a política `Never`, que não tentou baixá-la. O evento o confirma com uma frase completa: `Container image "…" is not present with pull policy of Never`: a imagem não está presente e a política proíbe baixá-la. Esse é o erro: o nó não tem a imagem. Não há nada quebrado na imagem nem no pod; falta o passo que a leve até lá. Antes de continuar, o script apaga o pod que falhou (`kubectl delete pod revisor --wait=true`), porque um pod não muda sua política por conta própria e começar do zero é mais limpo.

#### 10.11.5 Carregar a imagem e pedir o pod de novo

```text
== 5. Cargar la imagen en el nodo (sin registro) y volver a pedir el pod
$ kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10" with ID "sha256:0c8af76b8a5fbea25ddafedf41bc49ad9ec5f7144117559da98afbd1da0d2eaa" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10                dda2fbcae183b       3.68MB
$ kubectl run revisor --image=curso-docker-revisor:fig10 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=90s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image,REINICIOS:.status.containerStatuses[0].restartCount
NOMBRE    ESTADO    IMAGEN                           REINICIOS
revisor   Running   curso-docker-revisor:fig10   0
$ kubectl logs revisor
revisor 1.6.0 escuchando en :8080 (1 servicio(s))
$ kubectl get events --field-selector involvedObject.name=revisor -o custom-columns=RAZON:.reason,MENSAJE:.message | cut -c1-110
RAZON               MENSAJE
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
ErrImageNeverPull   Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
Failed              Error: ErrImageNeverPull
Scheduled           Successfully assigned default/revisor to curso-docker-puente-fig10-control-plane
Pulled              Container image "curso-docker-revisor:fig10" already present on machine and can be acc
Created             Container created
Started             Container started
```

`kind load docker-image curso-docker-revisor:fig10 --name curso-docker-puente-fig10` lê a imagem do Docker local e a copia para o nó. Imprime uma única linha, que se lê assim: a imagem com esse identificador (`ID "sha256:0c8af76b…"`) **ainda não estava presente no nó** `curso-docker-puente-fig10-control-plane`, e está sendo carregada. (Esse identificador é o da imagem local, não um *digest* de registry.) A seguir vem a comprovação que não deve ser pulada: perguntar ao **nó** que imagens ele tem, com `docker exec <nó> crictl images` (`crictl` é a ferramenta de linha de comando do runtime de contêineres que vem dentro do nó; o nó do `kind` é um contêiner Docker, por isso o `docker exec` entra nele). O `grep` deixa o cabeçalho e as linhas do `revisor`. Aparece `docker.io/library/curso-docker-revisor`, tag `fig10`, 3.68 MB: a imagem **está sim no nó**, com o nome completo que o Kubernetes dá a um nome curto. Essa linha é a evidência de que a carga funcionou, e é melhor do que confiar na mensagem `loading...`, como se verá em 10.11.6. Depois, o mesmo `kubectl run` de antes, e agora:

- `kubectl wait --for=condition=Ready pod/revisor --timeout=90s` espera até 90 segundos para que o pod esteja pronto; a resposta `condition met` é a condição cumprida.
- A tabela do pod diz `Running` com a imagem `curso-docker-revisor:fig10` e **0 reinícios**.
- `kubectl logs revisor` mostra o que o `revisor` imprime ao iniciar: `revisor 1.6.0 escuchando en :8080 (1 servicio(s))`. É a mesma linha da Lição 3. A versão `1.6.0` confirma que roda a imagem que foi construída.
- Os eventos são a prova de que a ponte funcionou sem baixar nada. As três primeiras linhas são da tentativa fracassada de antes (`ErrImageNeverPull`, `Failed`). Depois, o pod novo: `Scheduled` (atribuído ao nó), e então `Pulled` com a mensagem **`Container image "…" already present on machine`**: «a imagem já está presente na máquina». Embora o evento se chame `Pulled` (baixada), o texto diz que não houve download: ela a encontrou já no nó, onde o `kind load` a deixou. A mensagem sai cortada pelo `cut -c1-110` do script (`…and can be acc`, de «and can be accessed by the container»). Depois `Created` e `Started`.

Essa frase, `already present on machine`, é a prova que a meta 6 do curso procura: **o pod iniciou sem nenhuma tentativa de download**. Quando o curso de Kubernetes começar, essa ponte será repetida com `curso-docker-revisor:1.6.0` e o cluster `curso-docker-puente`.

Para deixar limpo o que foi feito na máquina (o cluster próprio, não o de um script): `kind delete cluster --name curso-docker-puente`. Apaga o cluster e remove seu contexto da configuração; a imagem do Docker não é tocada.

#### 10.11.6 Se a imagem não foi construída na própria máquina: a que vem de um registry

Há um caso que o curso seguinte pode encontrar: a imagem não é construída na máquina local e sim **baixada do registry** por seu *digest*, como em 10.9. Seria natural pensar que o `kind load docker-image` a aceita com essa mesma referência. Foi medido, e não é assim. O script `fig10_09.sh` publica um índice de duas plataformas, baixa-o por *digest* no Mac, cria o cluster e testa três caminhos:

```text
== 3. Cargar la imagen traída del registro, por su referencia con digest
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB

== 4. Guardarla con docker save y cargar el archivo
$ docker save --platform linux/arm64 -o revisor.tar localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 && du -h revisor.tar | cut -f1
3.5M
$ kind load image-archive revisor.tar --name curso-docker-puente-fig10

== 5. ¿Qué nombres tiene la imagen dentro del nodo?
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-120 | sed -E 's/([0-9a-f]{12})[0-9a-f]{52}/\1…/g'
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB

== 6. Pedir el pod con la MISMA referencia con digest, sin descarga
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,RAZON:.status.containerStatuses[0].state.waiting.reason
NOMBRE    ESTADO    RAZON
revisor   Pending   ErrImageNeverPull
```

E os dois caminhos restantes (o bloco 7 e o 8):

```text
== 7. Una etiqueta local sobre la misma imagen, y cargar esa etiqueta
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace
$ docker tag localhost:5000/curso-docker-revisor@sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993 curso-docker-revisor:fig10-registro
$ kind load docker-image curso-docker-revisor:fig10-registro --name curso-docker-puente-fig10
Image: "curso-docker-revisor:fig10-registro" with ID "sha256:7c9f949290181fc458b8053b9442bb722c7b0be2c5a68afbd562738840eaf993" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
$ kubectl run revisor --image=curso-docker-revisor:fig10-registro --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
pod/revisor condition met
$ kubectl get pod revisor -o custom-columns=NOMBRE:.metadata.name,ESTADO:.status.phase,IMAGEN:.spec.containers[0].image
NOMBRE    ESTADO    IMAGEN
revisor   Running   curso-docker-revisor:fig10-registro
$ kubectl delete pod revisor --wait=true
pod "revisor" deleted from default namespace

== 8. Traer solo el manifiesto de la plataforma (no el índice) y cargarlo
$ docker pull -q localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0
$ kind load docker-image localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --name curso-docker-puente-fig10
Image: "localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" with ID "sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0" not yet present on node "curso-docker-puente-fig10-control-plane", loading...
$ docker exec curso-docker-puente-fig10-control-plane crictl images 2>&1 | grep -E 'IMAGE|revisor|<none>' | cut -c1-100
IMAGE                                           TAG                  IMAGE ID            SIZE
docker.io/library/import-2026-10-22             <none>               3b73f89567870       2.32kB
docker.io/library/curso-docker-revisor      fig10-registro       011d6bb2f3c70       3.68MB
$ kubectl run revisor --image=localhost:5000/curso-docker-revisor@sha256:7d767818297cb2c958a3037e95b1405641c6b3d46f13b8dc4093fb824a1199e0 --image-pull-policy=Never --port=8080 --env='REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud'
pod/revisor created
$ kubectl wait --for=condition=Ready pod/revisor --timeout=60s
error: timed out waiting for the condition on pods/revisor
[código de salida: 1]
```

Lê-se assim. **Caminho 1, carregar a referência com *digest* (bloco 3).** O `kind load` imprime `not yet present on node … loading...` e não dá nenhum erro. Depois o script pergunta ao nó que imagens ele tem, com `crictl` (a ferramenta de linha de comando do runtime de contêineres que vem dentro do nó), e o filtro deixa passar as linhas com `revisor` **e as que não têm nome** (`<none>`). **Não há nenhuma imagem chamada `revisor`, mas há uma sem nome:** `docker.io/library/import-2026-10-22`, tag `<none>`, 3.68 MB. A imagem **chegou sim ao nó, sem o nome que o pod pede.** O `import-` seguido da data é o nome de preenchimento que o `ctr images import` (o comando com que o `kind` importa, segundo os relatos citados abaixo) dá ao que importa sem uma referência própria ([containerd, `ctr images import`](https://github.com/containerd/containerd/blob/main/cmd/ctr/commands/images/import.go)); a data é a do relógio do nó, que segue em UTC, e por isso diz 22 embora as execuções tenham sido em 21 na Cidade do México. **Caminho 2, guardar com `docker save --platform` e carregar o arquivo com `kind load image-archive` (bloco 4):** o comando termina sem erro e sem saída; o bloco 5 mostra a mesma linha de 3.68 MB e uma segunda sem nome, de 2.32 kB (não se investigou o que ela contém). O bloco 6 é a consequência: um pod que pede a referência com *digest* fica em `Pending` com `ErrImageNeverPull`, porque no nó não há nenhuma imagem com esse nome ainda que o conteúdo esteja lá. **Caminho 3, uma tag local (bloco 7):** `docker tag <referência com digest> curso-docker-revisor:fig10-registro` dá um nome local à imagem baixada, o `kind load docker-image` dessa tag deixa a imagem no nó **com nome** (o `crictl` a mostra como `docker.io/library/curso-docker-revisor`, com a tag `fig10-registro` e 3.68 MB; a linha sem nome de 3.68 MB já não está, porque era a mesma imagem: o mesmo identificador, `011d6bb2f3c70`) e o pod inicia: `Running`. Duas observações. Uma: o nó escreve o nome completo, `docker.io/library/…`, mas o pod que pede `curso-docker-revisor:fig10-registro` o encontra, porque o Kubernetes completa o nome curto da mesma maneira. Duas: **carregar a referência do manifesto da plataforma** (o bloco 8, que baixa `…@sha256:7d76…`, o manifesto de `arm64` em vez do índice) também não funcionou: o pod volta a esperar com `ErrImageNeverPull`. Portanto o problema não é o índice de várias plataformas e sim a referência com *digest*.

A regra prática: **o `kind load` funciona com um nome com tag; com uma referência com *digest* responde «loading» e não deixa no nó uma imagem que o pod possa encontrar por essa referência.** Se a imagem vier de um registry, ponha-se primeiro uma tag local com `docker tag` e carregue-se essa. **A fonte, dita com exatidão.** Não existe uma página do `kind` que descreva este caso tal qual (carregar por uma referência com *digest* e não receber nenhum erro). O que existe no repositório do `kind` são relatos vizinhos, de mesma origem: com o Docker 29 e seu *image store* do *containerd*, o `docker save` conserva o índice completo de uma imagem de várias plataformas ainda que só as camadas da plataforma local tenham sido baixadas, e o `kind load` (que importa com `ctr images import --all-platforms --digests`) falha com `content digest … not found`. Os mantenedores atribuem isso ao fato de que o `docker save` «introduziu mudanças que quebram a compatibilidade quando se usa o armazenamento baseado em *containerd*» e apontam como saída curta não usar esse armazenamento ([kind, issue #4066, «kind unable to load images with docker 29»](https://github.com/kubernetes-sigs/kind/issues/4066), fechada como duplicata da issue fixada, e ainda aberta, [#3795](https://github.com/kubernetes-sigs/kind/issues/3795); e [#4224](https://github.com/kubernetes-sigs/kind/issues/4224), que repete o erro em um Mac com processador Apple e OrbStack e foi resolvida importando com `ctr` sem `--all-platforms`). A diferença em relação ao que esta lição mediu é o sintoma: aqui **não houve erro**, e a imagem chegou ao nó **sem nome** (`<none>`), por isso o pod não a encontra. Para esse sintoma exato: **medido, sem fonte oficial.** Também não se investigou por que a tag local deixa a imagem com nome (hipótese não medida: a imagem da tag foi baixada só com as camadas da plataforma local e o nome curto muda o que o `kind` exporta). Por isso a regra prática é conferir sempre com `crictl images`, olhando também as linhas `<none>`. (É o aviso de maior consequência para o curso seguinte: o comando cômodo falha em silêncio, e o sintoma, `ErrImageNeverPull`, aparece depois, no pod.)

### 10.12 A base fixada envelhece: renovar o *digest*

Fica pendente o achado de 10.10: `ca-certificates`, versão `20250419`, com correção disponível em `20250419+deb13u1`. De onde sai essa versão velha? Da **base** da imagem, `gcr.io/distroless/static-debian13:nonroot`, que desde a Lição 5 está fixada por *digest*: `@sha256:516757106de35…`. Fixar por *digest* deu exatamente o que se buscava, que a base não mude debaixo dos pés. E o outro lado da mesma moeda é que **a base também não recebe correções sozinha**. A documentação do Docker diz isso com todas as letras: fixar em um *digest* implica «optar por não receber correções de segurança automáticas, o que provavelmente é algo que se quer receber», e que é «tedioso» procurar e escrever o *digest* novo; recomenda automatizar a revisão, com o Docker Scout (que informa se a base fixada já não é a vigente) ou com o Dependabot (que abre solicitações de mudança programadas para atualizar tags e *digests*) ([Docker, «Building best practices»](https://docs.docker.com/build/building/best-practices/)).

O que importa aqui é o procedimento, que é curto e pode ser feito à mão: (1) perguntar ao registry da base para que *digest* a tag aponta hoje; (2) trocar o *digest* no `Dockerfile`; (3) reconstruir; (4) varrer de novo; (5) testar de novo. Os Exercícios 2 e 4 fazem isso com medições. Um adiantamento que convém dizer com precisão, porque é fácil confundir: o que se moveu no dia das execuções foi **a tag** `nonroot`, não o *digest* fixado. Às nove da manhã, hora da Cidade do México, essa tag já apontava para `sha256:d62067879de8…`, enquanto o `Dockerfile` fixa `sha256:516757106de3…`; e o *digest* fixado **continua existindo e continua apontando para a mesma imagem de sempre** (o Exercício 2 comprova isso pedindo-o por seu *digest*). Isso é o que fixar prometia: que a base não mude sem que se decida. A consequência é o outro lado da mesma moeda: as correções que o Debian publica chegam apenas quando o *digest* é trocado. A decisão desta lição é ficar com a base fixada, porque todas as saídas lidas foram medidas com ela, e apresentar a renovação como o que é, **um ato deliberado** (o Exercício 4 a faz e mede que a varredura passa a 0 achados). A imagem `1.6.0` que o curso entrega conserva sua base fixada e seu achado documentado. Em um projeto real, o que se faz é renovar de propósito, com uma versão nova.

Há uma fronteira que não deve ser cruzada: **não se renova por renovar.** Uma base nova é uma mudança: pode trazer uma biblioteca diferente, pode alterar o comportamento de algo. Por isso o procedimento termina com os testes do `revisor` (que a etapa `pruebas` do `Dockerfile` já roda ao construir) e com executar a imagem de novo. E faz-se em uma construção com **versão nova** (`1.6.1`), pela regra de 10.3: não se reutiliza uma tag publicada.

## O erro que se vai ver

Esta lição tem seis mensagens que convém reconhecer, uma por ferramenta (duas são da ponte para o Kubernetes, a 1 e a 6). Todas já apareceram; aqui são reunidas para serem encontradas rapidamente.

**1. O pod que não inicia: `ErrImageNeverPull`.** É o do `fig10_06.sh`:

```text
revisor   Pending   ErrImageNeverPull
Container image "curso-docker-revisor:fig10" is not present with pull policy of Never
```

Interpreta-se da direita para a esquerda, como os das lições anteriores. «With pull policy of Never» diz que a política proíbe baixar; «is not present» diz que o nó não tem a imagem. Os dois juntos significam: ninguém a carregou. Resolve-se com `kind load docker-image <imagem> --name <cluster>`, comprovando que o nome e a tag sejam **exatamente** os do pod. Se a imagem foi carregada e continua falhando, costuma ser uma tag diferente: confira-se com `kubectl get pod revisor -o custom-columns=IMAGEN:.spec.containers[0].image` que nome o pod pede (é a mesma coluna `IMAGEN` que já foi usada).

**2. O Trivy que não encontra a imagem.**

```text
unable to find the specified image "curso-docker-revisor:fig10" in ["docker" "containerd" "podman" "remote"]
```

Quer dizer que ele procurou nesses quatro lugares e não a achou. A solução não é entregar a ele o *socket* do Docker: é guardar a imagem com `docker save` e varrer o arquivo com `--input`.

**3. `docker save` com uma plataforma que não se tem.**

```text
Error response from daemon: no suitable export target found: image with reference … was found but does not provide the specified platform (linux/amd64)
```

A imagem existe no *image store*, mas essa plataforma nunca foi baixada. A solução: baixar primeiro essa plataforma com `docker pull --platform linux/amd64 <referência>` e guardar de novo (o bloco 11 do `fig10_04.sh` mediu isso: depois do `pull`, o `save` responde `guardada: linux/amd64`).

**4. A construção emulada que estoura.**

```text
fatal error: fault
ERROR: failed to build: failed to solve: process "/bin/sh -c go test ./..." did not complete successfully: exit code: 2
```

Coincide com a emulação e não com o código: o mesmo `Dockerfile` compila bem no processador nativo e com compilação cruzada. Resolve-se evitando a emulação: compilação cruzada com `--platform=$BUILDPLATFORM` nas etapas de compilação e `GOOS=$TARGETOS GOARCH=$TARGETARCH` no `go build`.

**5. O `500` do relatório com `read-only file system`.** É o da Lição 8, que reaparece com a imagem baixada por *digest*:

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

A imagem está bem e o sistema somente leitura funciona: falta montar um volume em `/datos`.

**6. `kind load` que diz «loading» e não carrega.** É o de 10.11.6: ao carregar uma imagem baixada de um registry por uma referência com *digest*, o `kind` não dá erro e não deixa no nó uma imagem que o pod possa encontrar por essa referência (chega sem nome, como `<none>`), e o pod fica em `Pending` com `ErrImageNeverPull`. Resolve-se pondo antes uma tag local com `docker tag` e carregando essa tag; para comprovar que chegou, `docker exec <nó> crictl images` deve mostrar a imagem com o nome que o pod pede.

## O hábito de segurança da lição

Esta lição instala quatro costumes, e os quatro foram praticados com medições:

- **O que se executa é referenciado por *digest*.** Uma tag se move e um *digest* não; o acidente que isso evita é o da cena (duas pessoas com o «mesmo» nome e conteúdos diferentes) e o ataque que dificulta é o de substituir no registry uma imagem em que outros já confiam pelo nome. Medido em 10.3.
- **O que se publica traz sua lista de materiais e sua proveniência, e a proveniência é publicada limpa.** O `mode=max` expõe os valores dos argumentos de construção, de modo que nenhum segredo viaja por `--build-arg`: entra por `--mount=type=secret`. Medido em 10.7.
- **Varre-se sem entregar o *socket* do Docker a ninguém.** `docker save`, `--input`, pasta montada em `:ro`. O acidente que isso evita é entregar o controle do daemon a uma ferramenta que baixa dados da internet. Medido em 10.10.
- **A varredura tem um limiar escrito e uma data da base de dados.** Um «zero» sem limiar e sem data não é um dado. Medido em 10.10.4 e 10.10.6.

## O que se faz errado

- **Reutilizar uma tag publicada** («é a mesma versão, só corrigi algo»). É o erro da cena. Cada construção que se entrega leva uma tag nova; se algo for corrigido, é a `1.6.1`.
- **Publicar `latest`.** O Kubernetes a trata de forma diferente (sua política padrão muda com essa tag, e a documentação do `kind` pede para não usá-la com imagens carregadas), e ela não diz que versão é. A tag `latest` não é um nome de versão: é um nome qualquer que por convenção se move.
- **Entregar o *socket* do Docker ao Trivy** (ou a qualquer contêiner) «para que leia a imagem». Quem tem o *socket* controla o daemon, e com ele a máquina. Resolve-se com `docker save` e `--input`.
- **Varrer uma só vez e esquecer.** A base de dados de falhas muda diariamente. Um resultado vale com sua data, e uma entrega é varrida de novo antes de ser usada.
- **Fixar o limiar depois de ver o resultado.** Se a varredura falha e o limiar é baixado até passar, a varredura deixou de servir. O limiar é escrito antes.
- **Ignorar um achado sem motivo nem data de expiração.** Um `.trivyignore` com identificadores soltos é uma lista de problemas que alguém decidiu calar sem deixar o porquê. Cada linha leva um comentário com o motivo e um `exp:` com a data em que o aviso expira (Exercício 3).
- **Fixar a base por *digest* e não olhar mais para ela.** A fixação protege de mudanças inesperadas, e também de correções esperadas. Programa-se uma revisão (Docker Scout, Dependabot ou uma tarefa própria).
- **Passar segredos por `--build-arg` e publicar com `mode=max`.** Os valores ficam escritos na proveniência que viaja com a imagem. Os segredos de construção entram por `--mount=type=secret`.
- **Construir para outra plataforma por emulação quando se pode compilar de forma cruzada.** Mais lento, e nesta máquina nem sequer funcionou.
- **Um registry em `0.0.0.0:5000` sem TLS nem autenticação.** Qualquer pessoa da rede pode enviar ou baixar. Publica-se em `127.0.0.1`, ou põe-se TLS e controle de acesso.
- **Mandar uma imagem por chat como arquivo `.tar`.** Quem a recebe não sabe de quem é nem o que ela leva. Publica-se em um registry e compartilha-se o *digest*.
- **Tomar «varrida» por «segura».** A varredura confere o que suas bases de dados conhecem hoje nos pacotes que reconhece. É uma camada de revisão, não uma garantia.
- **Carregar com `kind load` uma imagem com a tag `latest` e esperar que o pod não a baixe.** Com essa tag a política padrão é outra. Escreva-se `imagePullPolicy` ou use-se uma tag de versão.

## Exercícios

Os quatro têm sua solução medida mais abaixo, com o script que a produziu. Tente-se cada um antes de olhar a solução.

### Exercício 1 — Duas tags, um *digest*

A `1.6.0` está publicada no registry local. Quer-se que quem pedir `1.6` (a «linha» 1.6, sem o último número) receba **exatamente a mesma imagem** que quem pede `1.6.0`, sem reconstruir nada. Acrescente-se a tag `1.6` à imagem já publicada, comprove-se com o registry que agora há duas tags, e demonstre-se com `imagetools inspect` que as duas têm o mesmo *digest*. Dica: `docker buildx imagetools create -t <destino> <origem>` cria uma tag nova a partir de uma referência que já está no registry.

### Exercício 2 — Que *digest* a base tem hoje?

O `Dockerfile` fixa a base `gcr.io/distroless/static-debian13:nonroot` por *digest*. Descubra-se (a) os doze primeiros caracteres do *digest* que o `Dockerfile` traz e (b) os do *digest* para o qual essa mesma tag aponta hoje no registry do Google. Decida-se com uma frase se a base está em dia. Dica: `docker buildx imagetools inspect` também serve para imagens de outros registries.

### Exercício 3 — Aceitar um achado por escrito

O Trivy reportou `DSA-6572-1` (`UNKNOWN`) em `ca-certificates`. Suponha-se que a base não possa ser renovada hoje. Escreva-se um arquivo `.trivyignore` que aceite **esse** achado, com um comentário que diga o motivo e com um `exp:` que ponha a data de expiração, e demonstrem-se quatro coisas: sem o arquivo, o Trivy sai com código 1; com o arquivo, sai com 0; se o arquivo ignora **outro** identificador, volta a sair com 1 (o arquivo cala apenas o que diz, não tudo); e se o `exp:` já passou, o achado volta e o Trivy sai com 1 outra vez.

### Exercício 4 — Renovar a base e varrer de novo

Troque-se no `Dockerfile` o *digest* da base pelo que foi descoberto no Exercício 2 (b), reconstrua-se a imagem, comprove-se que ela continua dizendo `1.6.0` com `version`, guarde-se a imagem de novo com `docker save` e varra-se de novo **com todas as gravidades** e com `--exit-code 1`. O que mudou no resultado? Escreva-se a resposta no diário de bordo com a data: sem a data, o resultado não serve.

## Soluções

### Solução 1

É a primeira parte do `fig10_08.sh`. Com a `1.6.0` já enviada, o `imagetools create` cria a tag nova diretamente no registry, a partir de uma referência que já está lá. O resultado, como se verá, é outro nome para o mesmo índice.

```text
$ ./fig10_08.sh
== Ejercicio 1. Dos etiquetas, un digest
$ docker buildx imagetools create -t localhost:5000/curso-docker-revisor:1.6 localhost:5000/curso-docker-revisor:1.6.0 >/dev/null 2>&1 && echo 'etiqueta 1.6 creada'
etiqueta 1.6 creada
$ curl -s http://127.0.0.1:5000/v2/curso-docker-revisor/tags/list
{"name":"curso-docker-revisor","tags":["1.6","1.6.0"]}
$ for t in 1.6.0 1.6; do docker buildx imagetools inspect localhost:5000/curso-docker-revisor:$t --format '{{json .Manifest.Digest}}'; echo; done
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
"sha256:125ba52e53985a3e2e0b7618baf1edaa6c4b4e9a1afd93cd98459f245b433be8"
```

Lê-se assim. `create -t …:1.6 …:1.6.0` diz «crie a tag `1.6` apontando para o que hoje é `1.6.0`»; o `>/dev/null 2>&1` esconde sua saída de progresso e o `&& echo` confirma que terminou bem. A lista de tags já traz duas, `1.6` e `1.6.0`. E o laço pergunta, para cada tag, o *digest* do índice: as duas linhas são **idênticas** (`125ba52e…`). Dois nomes, uma imagem. É o que se espera de uma tag que segue a linha 1.6: um nome móvel e legível que, neste instante, aponta para o mesmo que a fixa. A contrapartida, que já se sabe: a `1.6` é uma tag que **sim se move** (quando a `1.6.1` for publicada, ela seria apontada para esta), de modo que serve para as pessoas e nunca para verificar.

### Solução 2

Está no `fig10_07.sh`. O primeiro comando extrai do `Dockerfile` os doze primeiros caracteres do *digest* que ele fixa; o segundo pergunta ao registry do Google o da tag `nonroot` e corta o começo:

```text
$ ./fig10_07.sh
== Ejercicio 2. ¿Qué digest tiene HOY la etiqueta nonroot de la base?
$ grep -oE 'static-debian13:nonroot@sha256:[0-9a-f]{12}' Dockerfile
static-debian13:nonroot@sha256:516757106de3
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13:nonroot --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:d62067879de8
(y el digest que fija el Dockerfile, ¿sigue existiendo en el registro?)
$ docker buildx imagetools inspect gcr.io/distroless/static-debian13@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 --format '{{json .Manifest.Digest}}' | cut -c2-20
sha256:516757106de3
```

O `Dockerfile` fixa `516757106de3…`; o registry diz hoje `d62067879de8…`. **Não coincidem: a tag já não aponta para o que o `Dockerfile` fixou.** E a terceira linha da saída esclarece: pedir ao Google o *digest* fixado (`…nonroot@sha256:516757106de3…`) responde com esse mesmo *digest*; não se moveu nem desapareceu. O que mudou foi o destino da tag. O `grep -oE` com esse padrão imprime apenas o que coincide (`-o`) com uma expressão regular estendida (`-E`) que pede a cadeia `static-debian13:nonroot@sha256:` mais doze caracteres hexadecimais. O `cut -c2-20` remove a aspa inicial da saída JSON e deixa os primeiros 19 caracteres, isto é, `sha256:` mais doze. Que a tag tenha mudado de destino não diz que o novo seja melhor nem que o velho seja perigoso: diz que **há algo a examinar**. É o insumo do Exercício 4. (Esta medição é de 21 de outubro; se for repetida outro dia, pode dar outro resultado, e isso é normal: é a razão de se medir.)

### Solução 3

Também no `fig10_07.sh`. O arquivo, com seu motivo e sua data, e as três execuções:

```text
== Ejercicio 3. Aceptar el hallazgo por escrito, con razón y fecha
$ cat .trivyignore
# ca-certificates 20250419 en la base distroless fijada por digest.
# Debian ya lo corrigió (20250419+deb13u1); el arreglo llega al renovar el
# digest de la base (Ejercicio 4). Mientras tanto se acepta, por escrito.
# Revisado el 21-oct-2026. Borrar esta línea al renovar la base.
DSA-6572-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(el mismo archivo, con un identificador que NO es el del hallazgo)
$ sed -i.orig 's/^DSA-6572-1$/DSA-0000-1/' .trivyignore && tail -1 .trivyignore
DSA-0000-1
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1

== Ejercicio 3 (continuación). La fecha que Trivy SÍ hace cumplir: exp:
$ sed -i.orig 's/^DSA-0000-1$/DSA-6572-1 exp:2026-11-21/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-11-21
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
(la misma línea, con una fecha que ya pasó)
$ sed -i.orig 's/exp:2026-11-21/exp:2026-01-01/' .trivyignore
$ tail -1 .trivyignore
DSA-6572-1 exp:2026-01-01
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --ignorefile /trabajo/.trivyignore --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        1        │    -    │
./revisor-1.6.0.tar (debian 13.7)
Total: 1 (UNKNOWN: 1, LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0)
código de Trivy: 1
```

Lê-se em três tempos. **Sem** o arquivo: a tabela conta 1 achado, há `Total: 1` e o código é **1**. **Com** `--ignorefile /trabajo/.trivyignore`: a tabela conta **0** para a base, já não há linha `Total`, e o código é **0**. E na terceira execução o script trocou o identificador do arquivo por um inventado (`DSA-0000-1`): o achado real volta, `Total: 1`, código **1**. Por isso a solução completa tem a terceira execução: demonstra que o arquivo não é um interruptor geral e sim uma lista de identificadores concretos. No formato do arquivo, as linhas que começam com `#` são comentários e cada identificador vai sozinho em sua linha ([Trivy, «Filtering»](https://trivy.dev/latest/docs/configuration/filtering/)). Um comentário com uma data não obriga ninguém a voltar a olhar o achado; o que faz cumprir uma data é o campo `exp:` que essa mesma documentação mostra em seus exemplos (`CVE-2019-14697 exp:2023-01-01`). A segunda parte da solução, «continuação», mede isso com o identificador deste exercício: com `DSA-6572-1 exp:2026-11-21` (uma data futura) o Trivy sai com código **0**; com `exp:2026-01-01` (uma data já passada) o achado **volta** e o código é **1**. Ou seja, a aceitação expira sozinha. Os identificadores `DSA-…` não aparecem nos exemplos da documentação; a medição mostra que funcionam como os `CVE-…`. A prática recomendável é combinar as duas coisas: o comentário com o motivo e `exp:` com a data de revisão. A opção `--ignorefile` aponta para o caminho do arquivo *dentro do contêiner* (`/trabajo/.trivyignore`, porque `/trabajo` é a pasta montada), não para o da máquina local; a referência do comando indica que, por padrão, a opção vale `.trivyignore`, isto é, um arquivo com esse nome na pasta atual. E o comentário: não é enfeite. É o que permite que, dentro de dois meses, alguém saiba **por que** essa linha está ali e quando se deve voltar a decidir.

### Solução 4

A segunda parte do `fig10_08.sh`. Descobre o *digest* vigente da tag, escreve-o no `Dockerfile` com `sed`, reconstrói, comprova a versão, guarda e varre:

```text
== Ejercicio 4. Renovar el digest de la base y volver a escanear
$ diff Dockerfile.viejo Dockerfile | cut -c1-120 | sed -E 's/sha256:([0-9a-f]{12})[0-9a-f]+/sha256:\1…/'; true
32c32
< FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de3…
---
> FROM gcr.io/distroless/static-debian13:nonroot@sha256:d62067879de8…
$ docker build -q --build-arg VERSION=1.6.0 -t curso-docker-revisor:fig10 . >/dev/null && docker run --rm curso-docker-revisor:fig10 version
1.6.0
$ docker save --platform linux/arm64 -o revisor-1.6.0.tar curso-docker-revisor:fig10 && du -h revisor-1.6.0.tar | cut -f1
3.6M
$ { docker run --rm -v curso-docker-trivy-cache-fig10:/root/.cache -v "$PWD":/trabajo:ro aquasec/trivy:0.76.0 image --quiet --input /trabajo/revisor-1.6.0.tar --exit-code 1 2>&1; echo "código de Trivy: $?"; } | sin_fechas | grep -E '^Total|^código|tar \(' | sed 's#/trabajo/#./#'
│ ./revisor-1.6.0.tar (debian 13.7) │  debian  │        0        │    -    │
código de Trivy: 0
```

O `diff` mostra que **só muda a linha 32**, a do `FROM` final, e só o *digest*. A construção passa (com ela, os testes do Go da etapa `pruebas`), `version` continua dizendo `1.6.0`, e a varredura com **todas as gravidades** agora dá **0 achados na base e código 0**. Ou seja: o que o scanner via em `ca-certificates` desapareceu ao renovar a base, sem desligar nada nem calar nenhum aviso. Duas nuances para o diário de bordo. Uma: **o que foi medido é o resultado, não a causa**: não se abriu a lista de pacotes da base nova para comprovar que versão de `ca-certificates` ela traz; a varredura diz que já não há achado, e com isso se decide. Duas: varreu-se uma plataforma, a desta máquina. Para uma entrega real, repetir-se-ia a varredura com a outra (o bloco 11 de 10.9.2 a deixa guardada). E a entrega seria publicada com **uma tag nova** (`1.6.1`), segundo a regra de 10.3, não por cima da `1.6.0`.

## Como sei que consegui

Comprove-se cada ponto com um comando, não de memória:

1. **O registry escuta apenas em `127.0.0.1`.** `docker port curso-docker-registro` responde `5000/tcp -> 127.0.0.1:5000` e nada com `0.0.0.0`.
2. **A imagem publicada é um índice de duas plataformas.** `docker buildx imagetools inspect localhost:5000/curso-docker-revisor:1.6.0` mostra `application/vnd.oci.image.index.v1+json` e entradas `linux/amd64` e `linux/arm64`, mais duas do tipo `attestation-manifest`.
3. **Sabe-se ler a lista de materiais e a proveniência, e o Docker usa o *image store* do *containerd*.** `docker info -f '{{ .DriverStatus }}'` inclui `io.containerd.snapshotter.v1`. Com os templates de 10.6 e 10.7 obtêm-se os nove pacotes da lista e a linha `construida EN`.
4. **É possível demonstrar que uma tag se move e um *digest* não.** Repete-se a medição de 10.3 e veem-se dois *digests* diferentes sob a mesma tag.
5. **Roda por *digest*, nas duas plataformas, e reforçada.** Em uma máquina `amd64`, `docker run --rm --platform linux/amd64 <referência> version` responde `1.6.0`.
6. **Roda reforçada:** `docker run … --read-only --cap-drop ALL --security-opt no-new-privileges --init -v <volume>:/datos localhost:5000/curso-docker-revisor@sha256:…` responde `{"estado":"vivo","version":"1.6.0"}` em `/salud`, e `docker inspect --format '{{.Config.Image}}' <contêiner>` mostra uma referência com `@sha256:`.
7. **A varredura tem um limiar escrito, um código de saída e uma data.** Roda-se o Trivy com `--input`, sem o *socket* do Docker, e guarda-se junto ao resultado a saída de `trivy version` com a data da base.
8. **O pod inicia sem baixar nada.** `kubectl get events` mostra `already present on machine` e `kubectl get pod revisor` diz `Running` com `0` reinícios.
9. **A máquina ficou limpa.** Seguindo a limpeza da seção «Encerramento do curso», `docker ps -a`, `docker volume ls` e `kind get clusters` já não mostram o registry, os contêineres de apoio, o cache do Trivy nem o cluster desta lição; fica apenas a imagem `curso-docker-revisor:1.6.0`, que é a que o curso seguinte usará.

## Resumo

- Uma **tag** é um rótulo que pode ser movido; um ***digest*** é uma impressão do conteúdo que não se move. Publica-se com uma tag nova por entrega e verifica-se por *digest*.
- Uma tag aponta para um **índice**; o índice aponta para um manifesto por plataforma e para um manifesto de atestação por plataforma.
- Para entregar a dois processadores sem emulação, **compila-se de forma cruzada**: `--platform=$BUILDPLATFORM` nas etapas de compilação e `GOOS=$TARGETOS GOARCH=$TARGETARCH` no `go build`. Nesta máquina a emulação falhou.
- `--sbom=true` acrescenta a lista de materiais (SPDX, escrita pelo Syft); `--provenance=mode=max` acrescenta a proveniência completa, que **expõe os valores dos argumentos de construção**; `mode=min` não.
- Reconstruir «idêntico» não garante o mesmo *digest*: com cache mudou o do índice; sem cache, o de cada plataforma.
- Baixa-se apenas a plataforma correspondente; `docker save --platform` falha se essa plataforma não foi baixada.
- O Trivy roda **sem o *socket***: `docker save` e `--input`, com a pasta em `:ro`. O limiar é fixado por quem varre, `UNKNOWN` conta se não se declara `--severity`, e sem `--exit-code` o Trivy sai com 0 mesmo encontrando coisas.
- Um achado com correção se resolve renovando a base ou, enquanto isso, é aceito **por escrito** em um `.trivyignore` com motivo e data. Fixar por *digest* tem o custo de renovar de propósito.
- `kind load docker-image` leva a imagem aos nós; com `imagePullPolicy: Never`, o pod só inicia se ela chegou, e o evento `already present on machine` prova isso. Com uma imagem baixada de um registry, carrega-se por uma **tag local**: com uma referência com *digest* o `kind` não dá erro e não deixa no nó uma imagem que o pod possa encontrar por essa referência.
- O binário da outra plataforma é verificado executando-o: `docker run --rm --platform linux/amd64 <referência> version` (aqui rodou emulado; em um `amd64`, nativo).

## Encerramento do curso: como saber que terminou

O README do curso promete que ele não acaba ao ler a lição 10, e sim quando o projeto cumpre seis coisas. Com esta lição, as seis têm como ser comprovadas, e cada uma foi medida na lição que a instala:

1. **`docker compose up` sobe tudo do zero** e o relatório mostra o serviço de teste fora do ar como `FALLA` (Lição 9).
2. **A imagem final pesa dezenas de megabytes** —16.2 MB nas execuções das lições 8 a 10—, sem shell nem compilador, e não roda como `root` (Lições 5 e 8).
3. **Nenhum segredo aparece** no `docker history`, no `docker inspect` nem no ambiente (Lição 6).
4. **`docker stop` termina em poucos segundos** (nas lições 3, 5, 7 e 9 foram medidos entre 137 e 321 milissegundos com a forma *exec*) e `docker ps` distingue `(healthy)` de `(unhealthy)` (Lição 7).
5. **O relatório sobrevive ao `docker rm`** e o `revisor` encontra o outro contêiner pelo nome (Lição 8).
6. **A imagem publicada é referenciada por *digest*, passa na varredura com o limiar fixado** e é carregada em um cluster `kind` **sem um único erro de download** (esta lição).

Há uma frase que convém dizer com precisão, porque é fácil exagerá-la: a imagem sai deste curso **com sua varredura revisada**, não «segura» nem «aprovada». Tem um limiar escrito, uma data de base de dados e um achado conhecido, com seu motivo e com o caminho para resolvê-lo. É isso que significa trabalhar com rigor: não que não haja achados, e sim que se saiba quais existem, de quando são e o que será feito com eles. O [curso de Kubernetes com kind](https://www.habil.mx/pt/cursos/kubernetes/) continua a partir daqui: a imagem `curso-docker-revisor:1.6.0`, com a ponte do `kind load docker-image` que já foi percorrida.

Antes de fechar o diário de bordo, desligue-se e apague-se o que foi subido nesta lição e é de quem a seguiu, com os nomes que se deu a cada coisa, um por um (sem `docker system prune` nem `docker volume prune`, que levariam o que é alheio). Primeiro veja-se o que há com `docker ps -a`, `docker images` e `docker volume ls`, e apague-se apenas o que for reconhecido:

```bash
docker rm -f -v curso-docker-registro curso-docker-revisor   # el registro (con su volumen anónimo) y el contenedor de 10.9
docker images --digests --format '{{.Repository}}@{{.Digest}}' | grep '^localhost:5000/curso-docker-revisor@' | xargs -r docker rmi   # lo traído por digest
docker volume rm curso-docker-trivy-cache   # la caché de Trivy de 10.10
kind delete cluster --name curso-docker-puente
```

(O volume `curso-docker-reportes` **não** é apagado aqui: é o da Lição 8, guarda os relatórios que já foram gerados e é limpo, se for o caso, ao encerrar aquela lição. A imagem local `curso-docker-revisor:1.6.0`, a que é construída em 10.11.3, fica: o curso seguinte a usa. O `rmi` acima apaga por nome as cópias baixadas por *digest*, nunca por identificador.)

## Fontes

Todas foram consultadas em 21 de outubro de 2026.

- Docker, «Build attestations» (SBOM e proveniência): <https://docs.docker.com/build/metadata/attestations/>
- Docker, «SLSA provenance» (modos `min` e `max`): <https://docs.docker.com/build/metadata/attestations/slsa-provenance/>
- Docker, «Multi-platform builds»: <https://docs.docker.com/build/building/multi-platform/>
- Docker, `docker buildx imagetools inspect`: <https://docs.docker.com/reference/cli/docker/buildx/imagetools/inspect/>
- Docker, `docker image save`: <https://docs.docker.com/reference/cli/docker/image/save/>
- Docker, referência do `dockerd` (registries locais marcados como inseguros): <https://docs.docker.com/reference/cli/dockerd/>
- Docker, «containerd image store»: <https://docs.docker.com/engine/storage/containerd/>
- Docker, «Building best practices» (base fixada por *digest*): <https://docs.docker.com/build/building/best-practices/>
- Docker, notas de versão do Docker Engine 29 (29.2.1 de 2 de fevereiro de 2026, com BuildKit v0.27.1): <https://docs.docker.com/engine/release-notes/29/>
- Distribution (registry), «Deploy a registry server»: <https://distribution.github.io/distribution/about/deploying/>
- Distribution, notas da versão 3.1.2: <https://github.com/distribution/distribution/releases/tag/v3.1.2>
- Open Container Initiative, «Distribution Specification»: <https://github.com/opencontainers/distribution-spec/blob/main/spec.md>
- Open Container Initiative, «Image Index»: <https://github.com/opencontainers/image-spec/blob/main/image-index.md>
- Trivy, «Container Image» (`--input`, ordem das fontes): <https://trivy.dev/latest/docs/target/container_image/>
- Trivy, «Filtering» (`--severity`, `--ignore-unfixed`, `.trivyignore`): <https://trivy.dev/latest/docs/configuration/filtering/>
- Trivy, «Vulnerability» (quando `UNKNOWN` é usado): <https://trivy.dev/latest/docs/scanner/vulnerability/>
- Trivy, «Reporting» (tabela e níveis): <https://trivy.dev/latest/docs/configuration/reporting/>
- Trivy, referência do `trivy image` (`--exit-code`, `--input`, `--ignorefile`): <https://trivy.dev/latest/docs/references/configuration/cli/trivy_image/>
- Trivy, notas da versão 0.76.0 (14 de outubro de 2026): <https://github.com/aquasecurity/trivy/releases/tag/v0.76.0>
- kind, «Quick Start» (`kind load docker-image`): <https://kind.sigs.k8s.io/docs/user/quick-start/>
- kind, notas da versão 0.33.0 (nó `kindest/node:v1.37.0`): <https://github.com/kubernetes-sigs/kind/releases/tag/v0.33.0>
- Kubernetes, «Install and Set Up kubectl on Linux»: <https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/>
- Kubernetes, «Images» (`imagePullPolicy`, *digests*, `:latest`): <https://kubernetes.io/docs/concepts/containers/images/>
- SPDX, «Overview»: <https://spdx.dev/about/overview/>
- SLSA, «Provenance» (v1.0): <https://slsa.dev/spec/v1.0/provenance>
- Codecov, «Bash Uploader Security Update» (o caso da soma de verificação): <https://about.codecov.io/security-update/>

### Termos desta lição

- **Registry**: serviço que guarda imagens e as entrega por uma API HTTP padrão.
- **Repositório**: o nome de uma imagem dentro de um registry; guarda todas as suas versões.
- **Referência**: o texto que aponta uma imagem: registry, repositório e tag ou *digest*.
- **Tag**: nome legível e móvel de uma versão de uma imagem.
- ***Digest***: impressão `sha256:` do conteúdo de um manifesto ou de um blob; não muda.
- **Manifesto**: documento JSON que lista as camadas e a configuração de uma imagem.
- **Índice** (*image index*): manifesto que aponta para vários manifestos, um por plataforma, e para as atestações.
- **Plataforma**: sistema operacional mais arquitetura de processador, como `linux/arm64`.
- **Emulação (QEMU)**: fingir outro processador por software; lenta e, nesta máquina, instável.
- **Compilação cruzada** (*cross-compilation*): compilar em um processador um binário para outro, sem executar nada alheio.
- **Atestação**: documento sobre uma imagem que viaja em seu índice; aqui, o SBOM e a proveniência.
- **SBOM**: lista de materiais de software; o que a imagem traz dentro.
- **SPDX**: padrão aberto para listas de materiais.
- **Proveniência** (*provenance*): como, onde e com que a imagem foi construída.
- **SLSA**: framework e formato para descrever a proveniência.
- **Vulnerabilidade**: falha de segurança pública, com um identificador (CVE, DSA…) e uma gravidade.
- **Limiar** (*threshold*): gravidade mínima que conta como achado na varredura.
- **Código de saída**: número que um programa devolve ao terminar; 0 é sucesso.
- **`.trivyignore`**: arquivo com os identificadores de achados que são aceitos.
- **`kind load docker-image`**: copia uma imagem do Docker local para os nós de um cluster `kind`.
- **`imagePullPolicy: Never`**: política do Kubernetes que proíbe baixar a imagem.
