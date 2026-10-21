# Curso de Docker — empacote um serviço e opere-o como se faz de verdade

**Por Dorian Chávez, fundador da Hábil e arquiteto de integração.**

**Para quem é:** quem já programou alguma coisa —o `revisor` dos cursos de [Go](https://www.habil.mx/pt/cursos/go/), [Rust](https://www.habil.mx/pt/cursos/rust/) ou [TypeScript](https://www.habil.mx/pt/cursos/typescript/) da Hábil, ou um serviço próprio— e precisa empacotá-lo, rodá-lo e operá-lo em contêineres sem copiar comandos às cegas. Nível intermediário: supõe-se que a gente use um terminal com desenvoltura e saiba o que é um servidor HTTP. Não se supõe que já tenha mexido com o Docker: cada conceito é explicado quando aparece, e explica-se por que existe, não só como se escreve. E não é preciso programar nada novo: o curso entrega o serviço pronto.

**O que se vai saber ao terminar:** converter um serviço em uma imagem pequena, sem privilégios e reproduzível; rodá-lo com limites, com verificação de saúde (*health check*) e com encerramento ordenado; gerenciar a configuração e os segredos dele sem deixá-los dentro da imagem; subir vários contêineres que conversam pelo nome com um só comando; e ler o que o Docker diz quando algo falha, em vez de procurar a resposta às cegas.

**Onde continua:** este curso é o degrau anterior ao [curso de **Kubernetes com kind**](https://www.habil.mx/pt/cursos/kubernetes/) da Hábil, que pega a imagem com que se termina aqui e a implanta, a configura, a escala e a protege em um cluster local.

**O que é preciso antes de começar:** um computador com Linux Mint 22.x e permissão de administrador (`sudo`). A [Lição 1](01-instalacion.md) instala o Docker do zero. Quem vem do curso de Go, Rust ou TypeScript já conhece o problema que o `revisor` resolve; se não for o caso, a lição 0 o apresenta em dois parágrafos.

## O projeto que se vai construir

O **`revisor`**: um servidor HTTP que consulta uma lista de serviços **ao mesmo tempo** e entrega, por `GET /api/estados`, um relatório com o nome, o estado e o tempo de resposta de cada um; e por `GET /salud`, a resposta curta que diz se o próprio processo está vivo. Ele é configurado com variáveis de ambiente (a porta, a lista de serviços, o caminho onde salva o relatório e um token de acesso). O servidor do `revisor` é escrito em **Go** (vem do curso de Go da Hábil) e compila para um binário estático; escuta na porta 8080, atende `GET /salud` e `GET /api/estados`, é configurado por variáveis de ambiente e traz um subcomando `healthcheck` para poder vigiar a si mesmo sem `curl`. Não é preciso saber Go: o curso o entrega e a gente o empacota.

O curso já o entrega pronto, junto com um **serviço de teste que falha de propósito** em três modos: saudável, lento e fora do ar. Com esse par de peças faz-se todo o trabalho do curso: empacotar, aplicar *hardening*, configurar, adicionar verificação de saúde, guardar dados, conectar e entregar. É o mesmo problema dos cursos de Go, Rust e TypeScript da Hábil: já se sabe o que o `revisor` faz, então toda a atenção fica no que é novo, que é **como ele viaja e como é operado**.

## As onze lições

| Lição | | O que se constrói | O que se aprende |
|---|---|---|---|
| 0 | [O que é um contêiner e o que NÃO é](00-que-es-un-contenedor.md) | nada ainda (leitura) | um contêiner é um processo isolado, não uma máquina virtual; imagem versus contêiner; o cliente e o daemon; o que é compartilhado com o host e por que isso decide a segurança |
| 1 | [Instalar o Docker no Linux Mint](01-instalacion.md) | o ambiente e o primeiro contêiner | Docker Engine a partir do repositório oficial; o Mint não é plataforma oficial e o que fazer; remover os pacotes em conflito; o grupo `docker` equivale a `root` |
| 2 | [Contêineres no dia a dia](02-contenedores-dia-a-dia.md) | o serviço de teste rodando, consultado e limpo | `run`, `ps`, `logs`, `exec`, `stop`, `rm`, `inspect`; publicar portas só em `127.0.0.1`; limites de memória e CPU; não deixar lixo |
| 3 | [O primeiro Dockerfile](03-primer-dockerfile.md) | `curso-docker-revisor:1.x.0` em uma única etapa | instruções do Dockerfile; forma *exec* versus forma *shell*; `.dockerignore`; `USER`; tags com versão; `docker build --check` |
| 4 | [Camadas, cache e contexto](04-capas-cache-contexto.md) | a mesma imagem, reconstruída em segundos | como se monta uma imagem camada por camada; a ordem das instruções; `--progress=plain` e `docker history`; cache de compilação (`--mount=type=cache`); o que viaja no contexto |
| 5 | [Multi-stage: de gigabytes a megabytes](05-multi-stage.md) | a imagem final mínima e sem privilégios | etapas de compilação, de testes e final; base mínima sem shell; versão e *digest* da base; o binário que não inicia por não ser estático |
| 6 | [Configuração e segredos](06-configuracion-y-secretos.md) | o `revisor` configurado sem reconstruir | variáveis de ambiente; `ARG` versus `ENV`; segredos de construção; segredos em execução por arquivo; ver com os próprios olhos o que fica dentro da imagem |
| 7 | [Verificação de saúde e ciclo de vida](07-salud-y-ciclo-de-vida.md) | um contêiner que informa o próprio estado e encerra de forma ordenada | PID 1 e sinais; o prazo do `docker stop`; `HEALTHCHECK` sem `curl`; políticas de reinício; sistema de arquivos somente leitura; `--cap-drop`; `no-new-privileges` |
| 8 | [Volumes e redes](08-volumenes-y-redes.md) | o relatório que sobrevive e dois contêineres que conversam | volumes com nome, *bind mounts* e `tmpfs`; o dono dos arquivos com um usuário sem privilégios; redes definidas pelo usuário; DNS por nome; redes internas |
| 9 | [Compose: o sistema completo](09-compose.md) | `compose.yaml` com o `revisor` e o serviço que falha | serviços, redes, volumes e segredos em um arquivo; `depends_on` com `service_healthy`; `compose config`; comparar o próprio arquivo com o do `docker init` |
| 10 | [Entregar a imagem](10-entregar-la-imagen.md) | a imagem publicada, verificada e pronta para o Kubernetes | tags e *digest*; *registry* local; varredura de vulnerabilidades com Trivy; lista de materiais (SBOM) e proveniência (*provenance*); várias plataformas; a ponte para `kind load docker-image` |

**Nomes com prefixo.** Tudo o que o curso cria na máquina (imagens, contêineres, redes, volumes) leva o prefixo `curso-docker-`; por isso a imagem da lição 3 se chama `curso-docker-revisor:1.x.0` e não `revisor`. Assim ela não colide com nada que já exista, e dá para apagar só o que é do curso sem mexer no resto.

No final de cada lição há exercícios com as respectivas soluções. E o [diário de bordo](bitacora.md) é de uso pessoal: anote ali o que foi difícil.

## Três princípios que atravessam todo o curso

**A segurança não é uma lição, é um hábito.** Não há um módulo final de segurança. Há um hábito por lição, e cada um é praticado no `revisor` e não em um exemplo à parte:

| Lição | O hábito que se instala |
|---|---|
| 0 | saber o que um contêiner compartilha com a máquina (o kernel) e o que não compartilha |
| 1 | o grupo `docker` equivale a `root`: só é concedido sabendo disso |
| 2 | portas publicadas só em `127.0.0.1`; limites de memória e CPU; jamais `--privileged` nem o *socket* do Docker dentro de um contêiner |
| 3 | o primeiro Dockerfile já traz `USER`; `.dockerignore` desde o primeiro dia; tags com versão, nunca `latest` |
| 4 | o contexto de construção não leva `.git`, `.env` nem chaves; a ferramenta de revisão do Dockerfile é executada sempre |
| 5 | base mínima e sem shell; a base é fixada por versão e por *digest*; a etapa de testes roda antes de empacotar |
| 6 | os segredos não passam por `ARG` nem `ENV`; confere-se com `docker history` e `docker inspect` que não ficaram lá |
| 7 | sistema de arquivos somente leitura, sem capacidades que não são usadas, sem escalada de privilégios, com um `init` |
| 8 | volumes com o dono correto; redes internas; nunca a rede do host |
| 9 | o `compose.yaml` final já inclui desde o início tudo o que veio antes, e os segredos dele vivem fora do arquivo |
| 10 | o que é publicado passa por varredura, traz a lista de materiais e é referenciado por *digest* |

Um tema que fica para o final é um tema que não se aprende.

**Um contêiner “rodando” não é um serviço saudável.** Quase todas as falhas de operação deste tema nascem de confundir as duas coisas: o processo existe, mas não atende. O serviço de teste falha de propósito e cada lição ensina a distinguir **o que o Docker acredita do que realmente acontece**.

**Só se ensina o que está em vigor, e o obsoleto é citado para ser reconhecido.** O Compose é `docker compose` (o *plugin*), o arquivo se chama `compose.yaml` e não leva `version:`; `MAINTAINER` está em desuso. Quando algo antigo aparece em um tutorial que vai ser encontrado de todo modo, o curso explica o que é e por que não se usa mais. E cada versão é informada com a respectiva data: as deste curso foram medidas em 7 de outubro de 2026 (Docker Engine 29.8.2, Compose v5.6.0).

## Como se sabe que terminou

O curso não termina quando se acaba de ler a lição 10, mas quando o projeto cumpre estas seis coisas. Os números são metas de projeto: são medidos e ajustados ao escrever as lições, e cada lição repete a meta que cabe a ela já medida.

1. **`docker compose up` sobe tudo do zero** e o relatório mostra o serviço de teste fora do ar como `FALLA`, sem precisar reiniciar nada manualmente.
2. **A imagem final pesa dezenas de megabytes** (meta), não centenas, não traz shell nem compilador, e **não roda como `root`** (o que se comprova com `docker exec` e com `docker inspect`).
3. **Nenhum segredo aparece** em `docker history`, em `docker inspect` nem nas variáveis de ambiente do contêiner.
4. **`docker stop` encerra o contêiner em poucos segundos** (meta: menos de dois), porque o processo recebe o sinal e se desliga de forma ordenada; e `docker ps` mostra `(healthy)` e, ao quebrar o serviço, `(unhealthy)`.
5. **O relatório sobrevive a `docker rm`** e o `revisor` encontra o outro contêiner pelo nome.
6. **A imagem publicada é referenciada por *digest***, passa pela varredura do Trivy com o limite definido e é carregada em um cluster `kind` sem um único erro de download.
