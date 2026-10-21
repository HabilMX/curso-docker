# Lição 4 — Camadas, cache e contexto

São 11h20 da manhã e ao meio-dia há uma demonstração para a área que vai usar o `revisor`. Falta um detalhe: a tabela do relatório imprime uma coluna deslocada um espaço. É uma mudança de uma linha. Faz-se a mudança, constrói-se a imagem e espera-se. Treze segundos. Testa-se, não ficou certo, corrige-se de novo. Mais treze. E mais treze. Na quinta volta, percebe-se que se passou mais tempo olhando o terminal compilar do que pensando no problema, e que cada build compila **todo** o programa do zero, embora só um arquivo tenha sido tocado. Enquanto isso, a colega, que trabalha na própria cópia do projeto, pergunta por que o build dela diz que «enviou» 62 MB se o código do `revisor` pesa alguns kilobytes. Na cópia dela alguém apagou o `.dockerignore`, e na pasta há um backup e o histórico do Git. As duas perguntas têm a mesma resposta, e ela não está no código do `revisor`: está na ordem de quatro linhas do Dockerfile e em um arquivo chamado `.dockerignore`. No final desta lição, essa mesma mudança de uma linha é reconstruída em menos de dois segundos.

**Tempo:** 2 × 45 min

**O que se constrói:** a mesma imagem da Lição 3, agora como `curso-docker-revisor:1.1.0`, com um Dockerfile reordenado para aproveitar o cache, uma montagem de cache para a compilação do Go e um `.dockerignore` mais completo. Faz exatamente o mesmo que a `1.0.0`; é reconstruída em segundos e sua camada de compilação pesa 100 MB a menos.

**O que se aprende:** que uma imagem é uma pilha de camadas e como vê-las com `docker history`; como o builder decide se uma camada sai do cache ou é refeita; por que a **ordem** das instruções decide quanto é reconstruído; como ler um build com `--progress=plain`; o que é uma montagem de cache (`RUN --mount=type=cache`) e por que seu conteúdo não fica na imagem; e o que viaja no contexto de build e o que não viaja.

**De onde se parte.** Da [Lição 3](03-primer-dockerfile.md) traz-se o primeiro Dockerfile: um único estágio sobre `golang:1.27.3-trixie`, um `COPY . .` que coloca todo o projeto, um `RUN go build`, `USER 10001:10001` e `CMD ["revisor"]` na forma *exec*. Traz-se também seu `.dockerignore` de cinco linhas e a imagem `curso-docker-revisor:1.0.0`, de 1.45 GB. Lá se disse, de passagem, que copiar tudo de uma vez deixa a reconstrução lenta; aqui isso vai ser medido e corrigido. Da [Lição 0](00-que-es-un-contenedor.md) traz-se a ideia de que uma imagem é feita de **camadas** somente leitura. Até agora era uma frase; nesta lição elas vão ser contadas uma por uma.

**O que esta lição não faz.** Não reduz a imagem de verdade: 1.32 GB continua sendo enorme, porque a imagem ainda traz o compilador do Go e um Debian inteiro. Separar a compilação da imagem final é o tema da [Lição 5](05-multi-stage.md). Também não mexe no código do `revisor`, nem em sua configuração, nem em seus segredos. E não ensina a «baixar as dependências em uma camada separada», um truque muito comum nos tutoriais de Go, porque o `revisor` não tem dependências externas: só usa a biblioteca padrão. O que ele tem, e muito, é **compilação**, e esse é o cache ensinado aqui. A seção 4.8 diz como reconhecer o outro truque quando ele aparecer.

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4, a mesma base do Linux Mint 22, o sistema de referência do curso. Os scripts foram executados **dentro** dessa máquina virtual, com Docker 29.2.1 (cliente e daemon) e Buildx v0.31.1. O curso foi planejado com o Docker Engine 29.8.2, e a versão mais recente publicada naquele dia era a 29.9.2, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)); nada do que esta lição ensina muda entre essas versões. Três avisos sobre estas execuções. Primeiro: a máquina estava ocupada com outros builds ao mesmo tempo, então os **tempos** têm ruído; o que se mantém em todas as execuções é a **diferença** entre um Dockerfile e outro, não os milissegundos exatos. Segundo: nessa mesma máquina estavam sendo escritas outras lições do curso, que criam imagens com os mesmos nomes (`curso-docker-revisor:1.0.0`, `:1.1.0`). Para não apagar nada delas nem sobrescrever uma tag, os scripts desta lição foram lançados com outro prefixo de nomes, graças à variável `PREFIJO` que eles trazem, e o prefixo foi devolvido ao normal do curso **no próprio comando**, à vista: a primeira linha de cada saída salva diz exatamente como foi executada, por exemplo `PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'`. No Mint, `./fig04_03.sh` puro imprime o mesmo sem esse `sed`. É a única exceção a «executa-se como está», e existe só por causa da máquina compartilhada. Terceiro: o Mac das execuções não tem o Go 1.27.3 instalado; por isso o erro do Go da Solução 3 foi medido dentro da imagem `golang:1.27.3-trixie`. O que **muda** no Mint: os tempos, os identificadores do cache e, se a máquina for Intel ou AMD, a variante da imagem do Go que é baixada (`amd64` em vez de `arm64`), embora o *digest* que aparece na linha do `FROM` seja o mesmo, porque é o do índice de plataformas. Os programas estão em [`programas/04-capas-cache-contexto/`](../programas/04-capas-cache-contexto), cada um com sua saída ao lado, e `estado/` guarda o `Dockerfile`, o `.dockerignore` e o `Dockerfile.leccion3` (a cópia do da Lição 3, só para comparar) tal como ficam ao terminar.

## Ao terminar, será possível

- Listar com `docker history` as camadas de uma imagem e dizer quais acrescentam arquivos e quais só dados.
- Prever, antes de construir, que passos de um Dockerfile vão sair do cache depois de uma mudança, e comprovar isso com `--progress=plain`.
- Reordenar um Dockerfile para que uma mudança no código não repita os passos que não dependem dela.
- Acrescentar uma montagem de cache a um `RUN` de compilação e mostrar que seu conteúdo vive no builder e não na imagem.
- Medir com um arquivo de 50 MB o que viaja no contexto de build, com e sem `.dockerignore`.
- Apagar só o próprio cache de compilação, sem mexer no de outros projetos da mesma máquina.

## O porquê antes do como

Construir uma imagem é repetir uma receita. Na primeira vez, cada passo é feito de verdade: baixa-se a base, copiam-se os arquivos, compila-se. Na segunda vez, quase tudo é igual à primeira: a mesma base, o mesmo `go.mod`, quase o mesmo código. Seria absurdo repetir tudo. Por isso o builder guarda o resultado de cada passo e, na vez seguinte, se nada do que esse passo usa mudou, **reutiliza** o resultado em vez de repeti-lo. Isso se chama **cache de build**.

O problema é que o cache tem regras, e não são as que se supõe. Não é «reutiliza o que não mudou». É «reutiliza **até** o primeiro passo que mudou, e dali para baixo repete tudo». Essa diferença é a cena do começo. No Dockerfile da Lição 3, o código entra com um único `COPY . .` e na linha seguinte se compila. Qualquer mudança, mesmo que seja um comentário, muda esse `COPY`, e como o `RUN go build` vem depois, a compilação completa se repete. Com o Dockerfile desta lição, a mesma mudança é reconstruída assim (isso vai ser medido na seção 4.5):

```text
## 3. Cambio un comentario en internal/reporte/tabla.go
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
...
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
```

De treze segundos para menos de dois, com o mesmo código, a mesma mudança e a mesma imagem resultante. Em uma máquina menos ocupada ou em um projeto maior, a diferença cresce. E a segunda pergunta da cena, a dos 62 MB, é o outro lado da mesma moeda: o builder também precisa saber **que arquivos** pode usar, e se todos forem enviados a ele, ele envia todos.

A lição tem oito partes:

1. **Uma imagem é uma pilha de camadas** (4.1): vê-las com `docker history`.
2. **Como o cache decide** (4.2): as regras, com o Dockerfile da Lição 3 como mau exemplo.
3. **A ordem importa** (4.3): o Dockerfile novo, linha por linha.
4. **O cache que não é camada** (4.4): `RUN --mount=type=cache`.
5. **Medir** (4.5): o cronômetro e `--progress=plain`.
6. **O que viaja no contexto** (4.6), com o erro da lição.
7. **Revisar antes de construir** (4.7).
8. **O que aparece em outros projetos** (4.8).

## Os conceitos

### 4.1 Uma imagem é uma pilha de camadas

#### 4.1.1 Uma camada por passo

A documentação do Docker define uma camada assim: «cada camada de uma imagem contém um conjunto de mudanças no sistema de arquivos: acréscimos, remoções ou modificações», e explica que isso é útil porque «permite reutilizar camadas entre imagens» ([Docker, «Understanding the image layers»](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/)). E a página do cache de build conecta as camadas à receita: «cada instrução deste Dockerfile se traduz em uma camada da imagem final» ([Docker, «Docker build cache»](https://docs.docker.com/build/cache/)).

Na Lição 0 apareceu a consequência das camadas para os contêineres: cada contêiner acrescenta uma camada própria, por cima, onde escreve. Aqui importa a outra metade: como as camadas de baixo são empilhadas ao **construir**. `FROM` não acrescenta uma camada própria: coloca embaixo todas as camadas da imagem base. Depois, cada `COPY` e cada `RUN` deixa uma camada com os arquivos que acrescentou ou mudou, e `WORKDIR` também deixa uma, pequena, quando precisa criar a pasta. As instruções que só anotam algo, como `USER`, `EXPOSE` e `CMD`, deixam uma linha no histórico, mas de zero bytes: acrescentam dados à configuração, não arquivos.

#### 4.1.2 Vê-las com `docker history`

`docker history` mostra «o histórico de uma imagem», uma linha por passo, do mais recente ao mais antigo ([`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/)). Com `--format` escolhem-se as colunas: `.Size` é o tamanho que aquele passo acrescentou e `.CreatedBy`, o comando que o criou. Este é o histórico da imagem da Lição 3, tirado de `fig04_03.sh` (o script completo aparece em 4.5; aqui só se olha sua seção 5):

```text
$ docker history curso-docker-revisor:1.0.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
110MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
115kB	COPY . . # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
```

Esta saída é estável em uma máquina `arm64`; em `amd64` os tamanhos podem diferir um pouco. O `head -7` fica com as sete linhas de cima e o `cut -c1-70` corta cada linha em 70 caracteres para caber; a `…` é do Docker, que também corta os comandos longos (com `--no-trunc` ele não corta).

Leia de baixo para cima, que é a ordem em que foi construído:

- `WORKDIR /go` **não é nosso**. É o último passo da imagem do Go. Sem o `head -7`, aparecem embaixo mais uma dúzia de linhas, todas de `golang:1.27.3-trixie`: na execução de referência do curso, a maior era uma camada de 290 MB com a instalação do Go e, mais abaixo, várias de 281, 208 e 156 MB com o Debian de base. A nossa imagem **começa** onde a do Go termina.
- `WORKDIR /src`, 8.19 kB: o primeiro passo nosso. Cria a pasta.
- `COPY . . # buildkit`, 115 kB: o projeto inteiro. O comentário `# buildkit` diz que a camada foi criada pelo BuildKit, o builder apresentado na Lição 3.
- `RUN /bin/sh -c go build ...`, **110 MB**. Repare: o `RUN` é executado com `/bin/sh -c`, porque no Dockerfile ele está na forma *shell*. Para um `RUN`, isso não é problema; a regra da forma *exec* era para `CMD` e `ENTRYPOINT`.
- `USER`, `EXPOSE`, `CMD`: zero bytes. Só dados.

Agora a pergunta que abre esta lição: o `revisor` compilado pesa uns 10 MB. O que são os outros 100 MB dessa camada? A resposta está na seção 4.4, e é o motivo pelo qual a imagem nova pesa menos.

> [!NOTE]
> 🔧 **Observação de engenharia 4.1**
> Uma camada nunca é apagada de cima. Se um `RUN` cria um arquivo de 100 MB e o `RUN` seguinte o apaga, a imagem continua pesando esses 100 MB: a segunda camada só anota «este arquivo não aparece mais». O que entra em uma camada fica na imagem. Por isso o que não deve estar na imagem é evitado **antes** de entrar, não limpo depois.

### 4.2 Como o cache decide

#### 4.2.1 As três regras

A documentação do cache as explica em duas páginas, e elas cabem em três regras:

1. **Para `COPY` e `ADD`, contam os arquivos, menos sua data.** A documentação diz que o builder «calcula um checksum do cache a partir dos metadados dos arquivos» e que o cache é invalidado «se os metadados de qualquer um dos arquivos envolvidos mudaram». Na prática, que vai ser medida no Exercício 1: mudar o conteúdo de um arquivo o invalida, e mudar só sua data, não. A documentação diz assim: a data de modificação **não** conta; «se só o `mtime` dos arquivos copiados mudou, o cache não é invalidado» ([Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/)).
2. **Para `RUN`, conta só o texto do comando.** Fora `ADD` e `COPY`, a verificação do cache não olha os arquivos; «só a string do comando é usada para encontrar uma correspondência» (mesma página). Um `RUN go build` já executado com a mesma camada de baixo sai do cache, mesmo que lá fora tenha saído outra versão de alguma coisa.
3. **Uma vez que algo é invalidado, tudo o que está abaixo se repete.** «Se uma camada muda, todas as camadas que vêm depois também são afetadas. Mesmo que não fossem construir nada diferente, ainda assim precisam rodar de novo» ([Docker, «Docker build cache»](https://docs.docker.com/build/cache/)). A página de invalidação diz o mesmo: uma vez invalidado o cache, os comandos seguintes geram imagens novas e o cache não é usado.

A terceira regra é a que importa para a ordem. O cache não é um mapa de «o que mudou»; é uma corrente. Cada elo depende do de cima. Se um se rompe, rompem-se todos os de baixo.

#### 4.2.2 O Dockerfile da Lição 3, à luz das regras

Releia o Dockerfile da Lição 3 com as três regras em mãos:

```dockerfile
FROM golang:1.27.3-trixie
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

(É um fragmento: o arquivo completo é `estado/Dockerfile.leccion3`, idêntico ao da Lição 3.) O `COPY . .` depende de **todos** os arquivos do contexto. Muda-se um comentário em `internal/reporte/tabla.go`: regra 1, o conteúdo mudou, o `COPY` é invalidado. Regra 3: o `RUN go build` vem depois, então se repete. E como o `RUN` começa em uma camada nova, sem nada da compilação anterior, o Go compila **tudo** do zero: o programa, cada pacote de `internal/` e cada pacote da biblioteca padrão que ele usa.

Foi assim que `fig04_03.sh` viu isso (seção 3), no formato que 4.5 explica:

```text
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 13011 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 10.1s RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

`CACHED` quer dizer «saiu do cache»; `DONE` com um tempo, «foi feito de verdade». O `WORKDIR` saiu do cache; o `COPY` e a compilação foram refeitos. O passo 1, o `FROM`, sempre diz `DONE 0.0s`: o builder confirma que tem a imagem base, que já estava baixada, e não faz mais nada.

### 4.3 A ordem importa

#### 4.3.1 O Dockerfile da lição

O guia de otimização do Docker diz isso em uma linha: «os passos que mudam com frequência deveriam ficar perto do final do Dockerfile» ([Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/)). Para o `revisor`, isso resulta neste Dockerfile. Ele substitui o da Lição 3, na raiz do projeto, e se chama `Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
# fig04_01.Dockerfile — Lección 4: la misma imagen que la 3, ordenada para la caché.
FROM golang:1.27.3-trixie

WORKDIR /src

# Primero lo que casi nunca cambia (la descripción del módulo)...
COPY go.mod ./
# ...después el código, que cambia en cada edición.
COPY cmd/ cmd/
COPY internal/ internal/

# La caché de compilación de Go vive en un montaje de caché: sobrevive entre
# construcciones, acelera la siguiente y NO queda dentro de la imagen.
RUN --mount=type=cache,id=curso-docker-go-build,target=/root/.cache/go-build \
    go build -o /usr/local/bin/revisor ./cmd/revisor

USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

Comparado com o da Lição 3, mudam duas coisas: o `COPY . .` foi dividido em três, e o `RUN` ganhou uma opção `--mount`. O resto é igual, linha por linha, e a imagem resultante faz o mesmo.

#### 4.3.2 Os três `COPY`

**`COPY go.mod ./`.** O arquivo `go.mod` descreve o módulo: seu nome e a versão do Go que ele pede. No `revisor` tem duas linhas e quase nunca muda. Copiá-lo primeiro, sozinho, cria uma camada que sobrevive a qualquer mudança do código. Em um projeto com dependências, aqui iriam também o `go.sum` e o passo de download (4.8); no `revisor`, o benefício é pequeno, mas o hábito é o mesmo: o que muda menos fica mais acima.

**`COPY cmd/ cmd/` e `COPY internal/ internal/`.** O código, em duas camadas. `cmd/revisor/` é o servidor HTTP; `internal/` são os pacotes que vêm do curso de Go (configuração, consulta, relatório). Separá-los não muda muito a velocidade, mas deixa mais claro em `docker history` que parte mudou, e a ordem segue a regra: `internal/`, que muda mais enquanto se desenvolve o relatório, fica embaixo.

Repare em um efeito colateral que vale ouro e que é medido em 4.6: com `COPY` seletivos, **só esses três caminhos** podem entrar na imagem. Um `.env` esquecido na pasta não entra mesmo que o `.dockerignore` o esqueça, porque nenhum `COPY` o pede. O `.dockerignore` continua sendo obrigatório, mas já não é a única barreira.

#### 4.3.3 A mesma mudança, com a ordem nova

Agora o mesmo comentário em `tabla.go`, com este Dockerfile. É a seção 3 de `fig04_03.sh`, segunda metade:

```text
curso-docker-revisor:1.1.0 (Dockerfile): 1847 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.8s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

As regras, de novo. `go.mod` não mudou: cache. `cmd/` não mudou: cache. `internal/` mudou: é refeito e, pela regra 3, o `RUN` também. Até aqui a ordem economizou pouco, porque a compilação continua se repetindo. Mas veja o tempo do `RUN`: **0,8 segundo**, contra 10,1 do Dockerfile antigo. A compilação se repetiu e, no entanto, quase não compilou nada. Isso não foi feito pela ordem. Foi feito pelo `--mount`, e é a seção seguinte.

Antes de continuar, a prova de que a imagem nova faz o mesmo que a antiga. A seção 7 de `fig04_03.sh` roda a `1.1.0` como na Lição 3, com o `revisor` verificando a si mesmo, e pergunta pelo health check de dentro do contêiner (a imagem do Go traz `curl`; assim não é preciso publicar uma porta):

```text
## 7. La imagen nueva hace lo mismo que la vieja
$ docker exec curso-docker-revisor curl -s http://127.0.0.1:8080/salud
{"estado":"vivo","version":"desarrollo"}
```

Igual à `1.0.0`. O `"desarrollo"` continua ali porque a versão ainda não é gravada no programa; isso chega na Lição 6.

### 4.4 O cache que não é uma camada: `RUN --mount=type=cache`

#### 4.4.1 O Go já tem seu próprio cache

O compilador do Go não compila duas vezes a mesma coisa se puder evitar. Sua documentação diz assim: «o comando `go` guarda em cache os resultados de compilação para reutilizá-los em compilações futuras», e por padrão os guarda em uma pasta chamada `go-build` dentro da pasta de cache do usuário ([documentação do `go`, «Build and test caching»](https://pkg.go.dev/cmd/go#hdr-Build_and_test_caching)). No Linux, para o usuário `root`, essa pasta é `/root/.cache/go-build`. Ao mudar um arquivo de `internal/reporte`, o Go só recompila esse pacote e os que dependem dele, e pega o resto do cache.

Na máquina local, esse cache funciona sozinho. Dentro de um build do Docker, não: cada `RUN` começa na camada que o passo anterior deixou, e no Dockerfile da Lição 3 essa camada não tem cache do Go, porque o `COPY` acabou de ser refeito. Pior ainda: o que o Go escreve em `/root/.cache/go-build` durante o `RUN` **fica na camada do `RUN`**. São esses os 100 MB que sobravam em 4.1.2.

#### 4.4.2 A montagem de cache

`RUN --mount` permite «criar montagens do sistema de arquivos que o build pode acessar», e o tipo `cache` serve para que «o contêiner de build guarde em cache pastas de compiladores e gerenciadores de pacotes» ([referência do Dockerfile, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache)). O guia de otimização completa o quadro: uma montagem de cache é «um local de cache persistente» para os builds; o cache se acumula entre builds e é compartilhado entre vários deles ([Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/)).

Traduzindo: durante esse `RUN`, a pasta `/root/.cache/go-build` não faz parte da camada. É uma pasta que o **builder** guarda à parte e monta de novo a cada build. O Go encontra ali o que compilou da vez anterior, e o que ele escreve ali não acaba na imagem.

As opções que o `revisor` usa:

- **`type=cache`**: o tipo de montagem.
- **`target=/root/.cache/go-build`**: onde a pasta aparece dentro do `RUN`. É a pasta padrão do cache do Go, então o Go a usa sem configurar nada. O guia do Docker usa esse mesmo caminho em seu exemplo de Go.
- **`id=curso-docker-go-build`**: o nome do cache. A referência diz que é opcional e serve para «identificar caches separados»; se não for informado, vale o mesmo que `target`. Mais abaixo aparece por que convém informá-lo.

Há outras opções (`sharing`, `mode`, `uid`…), e a referência as lista; o `revisor` não precisa delas. Uma nota: a montagem é usada ao construir, quando o usuário ainda é `root`; o `USER 10001:10001` vem depois e não a afeta.

#### 4.4.3 O cache vive no builder, não na imagem

Afirmações se comprovam. A seção 6 de `fig04_03.sh` procura o cache nos dois lugares onde ele poderia estar:

```text
## 6. La caché de compilación vive en el constructor, no en la imagen
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID                           RECLAIMABLE   SIZE      LAST ACCESSED
xq0we4j0a5g4a98ftg4xaezzc*   true          99.59MB   1 second ago
$ docker buildx du --verbose --filter 'description~=curso-docker-fig04-go-build' | grep -E '^(Description|Type):'
Description:  cached mount /root/.cache/go-build from exec /bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor with id "/curso-docker-fig04-go-build"
Type:         exec.cachemount
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.1.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
du: cannot access '/root/.cache/go-build': No such file or directory
[código de salida: 1]
$ docker run --rm --name curso-docker-mira --user 0 curso-docker-revisor:1.0.0 sh -c 'du -sh /root/.cache/go-build 2>&1'
95M	/root/.cache/go-build
```

O identificador da primeira linha e o «1 second ago» mudam; os tamanhos podem variar alguns megabytes. `docker buildx du` mostra o que o builder ocupa em disco (*disk usage*), e `--filter description~=...` fica com os registros cuja descrição contém esse texto. Com `--verbose` ele mostra cada registro completo; o `grep` fica com a descrição e o tipo, que vão ser necessários em 4.4.5. Os dois `docker run` entram em cada imagem como `root` (`--user 0`, só para poder ler `/root`) e medem a pasta.

Três linhas, três fatos:

1. **No builder** há um cache de 99.59 MB, do tipo `exec.cachemount` (montagem de cache), com o `id` do script. Ali está o que o Go compilou.
2. **Na imagem `1.1.0`**, a pasta nem existe. O cache não viajou.
3. **Na imagem `1.0.0`**, a da Lição 3, a pasta pesa 95 MB. Ali estavam os 100 MB a mais.

E por que o script usa `curso-docker-fig04-go-build` e não o `curso-docker-go-build` do Dockerfile? Porque o script muda o `id` ao montar sua cópia do projeto, para ter um cache **só dele**, começar de verdade a frio e poder apagá-lo ao terminar sem mexer no do projeto local. É a mesma ideia que aparece em 4.4.5.

E a seção 5 do mesmo script confirma isso a partir das imagens:

```text
$ docker history curso-docker-revisor:1.1.0 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70
0B	CMD ["revisor"]
0B	EXPOSE [8080/tcp]
0B	USER 10001:10001
10MB	RUN /bin/sh -c go build -o /usr/local/bin/re…
77.8kB	COPY internal/ internal/ # buildkit
41kB	COPY cmd/ cmd/ # buildkit
12.3kB	COPY go.mod ./ # buildkit
8.19kB	WORKDIR /src
4.1kB	WORKDIR /go
$ docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^curso-docker-revisor:1\.[01]\.0 '
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.0.0 1.45GB
$ for i in curso-docker-revisor:1.0.0 curso-docker-revisor:1.1.0; do docker image inspect --format "$i {{.Size}}" $i; done
curso-docker-revisor:1.0.0 337298513
curso-docker-revisor:1.1.0 314341606
```

O `RUN` passou de 110 MB para **10 MB**: agora a camada tem só o executável. As três camadas de código somam o mesmo que o `COPY . .` de antes, distribuído. Esse é o número firme: **a camada emagreceu 100 MB**, sem tirar nada de que o `revisor` precise.

As outras duas linhas contam o tamanho da imagem de duas formas, e convém não confundi-las. `docker image inspect` dá o tamanho do **conteúdo**, compactado como é guardado e transferido: 337.3 MB contra 314.3 MB, 23 MB a menos. `docker image ls` dá 1.45 GB contra 1.32 GB, uns 130 MB a menos. A diferença entre as duas formas vem do armazenamento de imagens do Docker Engine 29, que segundo sua documentação guarda as imagens «em formato compactado e descompactado» ([Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/)). Os 130 MB batem com essa explicação: uns 100 MB da camada descompactada mais uns 23 MB compactados, com o arredondamento dos gigabytes. Essa soma é uma conta nossa, não uma regra da documentação; o que é certo é a camada de `docker history`. É uma economia que não se buscava, e chegou por fazer bem o que se buscava.

> [!NOTE]
> 🔧 **Observação de engenharia 4.2**
> Há dois caches e convém não confundi-los. O **cache de camadas** decide se um passo se repete ou não: é tudo ou nada. A **montagem de cache** faz com que, quando um passo se repete, ele se repita barato. A ordem do Dockerfile trabalha sobre o primeiro; o `--mount`, sobre o segundo. Com os dois juntos, o `RUN go build` quase nunca é pulado, mas quase nunca custa.

#### 4.4.4 Os dois caches são independentes

Um detalhe que vai poupar uma confusão: são duas coisas separadas, e são tratadas separadamente. `--no-cache` pede ao builder que não use o cache de **camadas**; para que uma medição a frio seja honesta, a seção 1 de `fig04_03.sh` além disso apaga sua **montagem** antes de começar, com seu próprio `id` (4.4.5). E ao contrário: um passo que sai do cache de camadas não executa seu `RUN`, então nem lê nem enche a montagem. Construindo uma vez com tudo no cache de camadas, a montagem continua tão vazia ou tão cheia quanto estava.

#### 4.4.5 Um `id` próprio, e por que nunca uma remoção ampla

A montagem de cache ocupa disco, e um dia vai ser preciso apagá-la. O comando é `docker buildx prune`, que apaga cache do builder, e sua opção `--filter` permite escolher o que apagar: por idade (`until`), por tipo (`type`, e um dos tipos é `exec.cachemount`, justamente o das montagens) ou por um texto da descrição (`description`) ([`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/)). Em 4.4.3 apareceu como é a descrição de uma montagem de cache: `cached mount /root/.cache/go-build from exec … with id "/curso-docker-fig04-go-build"`. O `id` aparece no final, depois de uma barra e entre aspas. Por isso o `id` importa: é o rótulo que permite encontrar **o nosso** cache e só ele.

Aqui está o perigo. Um filtro amplo, como `description~=go-build`, pega o cache de compilação de **qualquer** projeto Go da máquina que use o caminho padrão. Não é hipotético: na máquina destas execuções, enquanto esta lição era escrita, `docker buildx du --filter 'description~=go-build'` encontrou dois registros, o desta lição e o de outro projeto que estava sendo construído ao mesmo tempo. Um `prune` com esse filtro teria apagado o cache do outro, e o build seguinte dele teria demorado sem que ninguém soubesse por quê. Em uma máquina compartilhada (um servidor de build, o computador de uma equipe, ou o nosso com vários projetos), uma remoção ampla é apagar o que é dos outros.

A regra deste curso tem duas partes:

1. **Cada projeto, seu `id`.** O `revisor` usa `curso-docker-go-build`. Se amanhã outro projeto Go for empacotado, ele recebe outro. Sem `id`, todos os projetos que usam `target=/root/.cache/go-build` compartilham o mesmo cache, porque o `id` padrão é o caminho.
2. **Apagar com o `id` completo e o tipo.** É assim que os scripts desta lição fazem ao sair:

```bash
docker buildx prune -f --filter type=exec.cachemount \
  --filter "description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]"
```

O `type=exec.cachemount` limita a remoção a montagens de cache. O `~=` compara com uma expressão regular, e o `[^a-z0-9-]` de cada lado («qualquer caractere que não seja letra minúscula, número nem hífen») exige que o `id` apareça **completo**: na descrição, o que envolve o `id` são a barra de antes e a aspa de depois, e as duas cumprem a condição. Assim, um `id` mais longo que o contenha, como `curso-docker-fig04-go-build-viejo`, não é apagado por acidente. Por que não escrever diretamente a barra e as aspas no filtro? Porque com a versão do Buildx destas execuções (v0.31.1), um filtro com espaços, aspas ou `/` não encontrou nada: isso foi medido com `docker buildx du` antes de usá-lo. É um bom costume: **testar um filtro com `du`, que só olha, antes de usá-lo com `prune`, que apaga.**

Uma remoção que não avisa se não apagou nada não demonstra nada, então a seção 8 de `fig04_03.sh` apaga à vista e depois procura de novo:

```text
## 8. Borro SOLO mi caché de compilación y compruebo que ya no está
$ docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]curso-docker-fig04-go-build[^a-z0-9-]' | tail -1
Total:	99.59MB
$ docker buildx du --filter 'description~=curso-docker-fig04-go-build'
ID        RECLAIMABLE   SIZE      LAST ACCESSED
```

O `prune` informa o que liberou (`Total: 99.59MB`, o mesmo cache da seção 6), e o `du` seguinte já não encontra nada: só sobra o cabeçalho da tabela. Para o projeto local, o mesmo comando com `curso-docker-go-build` apaga o cache do `revisor` e nada mais; o build seguinte vai ser lento uma vez e vai enchê-lo de novo.

### 4.5 Medir: o cronômetro e `--progress=plain`

#### 4.5.1 Ver o que o builder faz

Ao construir em um terminal, o BuildKit desenha uma tela que se redesenha e se colore. É bom para olhar, mas não dá para salvar nem buscar nela. A opção `--progress` decide o formato. Segundo a referência de `docker buildx build`, o valor padrão é `auto`, que usa o modo `tty` (o interativo, «com cor e redesenho») se a saída for um terminal, e `plain` se não for; `plain` «imprime o progresso do build em texto puro» ([`docker buildx build`, `--progress`](https://docs.docker.com/reference/cli/docker/buildx/build/#progress)). Em um servidor de build, onde não há terminal, sempre aparece `plain`, então convém saber lê-lo.

O texto puro tem esta forma: cada passo é um número com `#` na frente. Primeiro aparece a linha que o nomeia, como `#10 [5/6] COPY internal/ internal/`, e depois as linhas do que ele fez, todas com o mesmo número. Um passo termina normalmente com uma de duas linhas: `#10 CACHED`, se saiu do cache, ou `#10 DONE 0.5s`, se foi feito, com seu tempo. Se falha, termina com `#10 ERROR: …`, como aparece em 4.6.2. Os passos `[internal]` são os que o builder faz por conta própria: ler o Dockerfile, o `.dockerignore`, o contexto.

#### 4.5.2 O script da medição

`fig04_03.sh` constrói os dois Dockerfiles em quatro situações, cronometra cada build e resume o log de `--progress=plain` em uma tabela de passos. É o script mais longo da lição, e suas seções 5 a 8 são as já vistas em 4.1.2, 4.3.3, 4.4.3 e 4.4.5:

```bash
#!/usr/bin/env bash
# fig04_03.sh — Capas y caché: el Dockerfile de la Lección 3 contra el de la
# Lección 4. Construye los dos en frío, otra vez sin cambios y después de
# cambiar un archivo; cronometra cada construcción, muestra qué pasos salieron
# de la caché (--progress=plain) y compara las capas con docker history.
# Borra al salir sus imágenes y su caché de compilación.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L3="${PREFIJO}revisor:1.0.0"
L4="${PREFIJO}revisor:1.1.0"

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
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
t() { date +%s%3N; }
# construir ETIQUETA DOCKERFILE [opciones...]: construye con --progress=plain,
# guarda el registro en ../construccion.log e imprime cuánto tardó
construir() {
  local etiqueta="$1" archivo="$2" inicio fin; shift 2
  inicio=$(t)
  docker build --progress=plain "$@" -t "$etiqueta" -f "$archivo" . > ../construccion.log 2>&1
  fin=$(t)
  echo "$etiqueta ($archivo${*:+ $*}): $(( fin - inicio )) ms"
}
# pasos: de ../construccion.log, cada paso [n/m] con su estado final
pasos() {
  awk '
    /^#[0-9]+ \[([a-z0-9-]+ )?[0-9]+\/[0-9]+\]/ {
      if (!($1 in paso)) {
        l=$0; sub(/^#[0-9]+ \[([a-z0-9-]+ )?/, "", l); split(l, p, "/"); i=p[1]+0
        sub(/^[0-9]+\/[0-9]+\] /, "", l); sub(/--mount=[^ ]+ +/, "", l); paso[$1]=i; nombre[i]=l; if (i > k) k=i
      }
    }
    /^#[0-9]+ (CACHED|DONE)/ { if ($1 in paso) estado[paso[$1]]=$2 ($2=="DONE" ? " " $3 : "") }
    END { for (i=1; i<=k; i++) printf "  paso %d  %-10s %s\n", i, estado[i], substr(nombre[i], 1, 60) }
  ' ../construccion.log
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rm -f "${PREFIJO}revisor" >/dev/null 2>&1; docker rmi -f "$L3" "$L4" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "1. En frío: sin caché de capas y con la caché de compilación vacía"
borrar_cache
construir "$L3" Dockerfile.leccion3 --no-cache
pasos
construir "$L4" Dockerfile --no-cache
pasos

titulo "2. Otra vez, sin cambiar nada"
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "3. Cambio un comentario en internal/reporte/tabla.go"
echo "// cambio de prueba $(date +%s)" >> internal/reporte/tabla.go
construir "$L3" Dockerfile.leccion3
pasos
construir "$L4" Dockerfile
pasos

titulo "4. Cambio un archivo que el .dockerignore deja fuera"
echo "notas de trabajo $(date +%s)" > NOTAS.md
construir "$L4" Dockerfile
pasos

titulo "5. Las capas de cada imagen: solo los pasos de la receta"
muestra "docker history $L3 --format '{{.Size}}\t{{.CreatedBy}}' | head -7 | cut -c1-70"
muestra "docker history $L4 --format '{{.Size}}\t{{.CreatedBy}}' | head -9 | cut -c1-70"
muestra "docker image ls --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E '^${PREFIJO}revisor:1\.[01]\.0 '"
muestra "for i in $L3 $L4; do docker image inspect --format \"\$i {{.Size}}\" \$i; done"

titulo "6. La caché de compilación vive en el constructor, no en la imagen"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
muestra "docker buildx du --verbose --filter 'description~=${CACHE_ID}' | grep -E '^(Description|Type):'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L4 sh -c 'du -sh /root/.cache/go-build 2>&1'"
muestra "docker run --rm --name ${PREFIJO}mira --user 0 $L3 sh -c 'du -sh /root/.cache/go-build 2>&1'"

titulo "7. La imagen nueva hace lo mismo que la vieja"
docker run -d --name "${PREFIJO}revisor" -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$L4" >/dev/null
for _ in $(seq 40); do docker exec "${PREFIJO}revisor" curl -fsS -o /dev/null http://127.0.0.1:8080/salud 2>/dev/null && break; sleep 0.5; done
muestra "docker exec ${PREFIJO}revisor curl -s http://127.0.0.1:8080/salud"
docker rm -f "${PREFIJO}revisor" >/dev/null

titulo "8. Borro SOLO mi caché de compilación y compruebo que ya no está"
muestra "docker buildx prune -f --filter type=exec.cachemount --filter 'description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]' | tail -1"
muestra "docker buildx du --filter 'description~=${CACHE_ID}'"
```

As funções auxiliares do início são as da Lição 3 (`titulo`, `muestra`, `t`), mais três novas. `construir` constrói com `--progress=plain`, salva o log em um arquivo e cronometra. `pasos` é um pequeno programa `awk` que lê esse log e, para cada passo numerado `[n/m]`, imprime seu número, seu nome e seu estado final; tira do nome a opção `--mount=...` para que a linha caiba, e numera os passos ele mesmo porque, quando outro build compartilha passos idênticos na mesma máquina, o BuildKit pode mostrar o número de passo do outro. `borrar_cache` é a de 4.4.5.

Mais três detalhes. A mudança leva a hora (`$(date +%s)`) para ser diferente a cada execução: se o mesmo texto fosse escrito sempre, na segunda vez que o script rodasse esse conteúdo já estaria no cache de camadas, e a «mudança» sairia `CACHED`. (Isso aconteceu com quem escreve esta lição em uma primeira versão do script, e é uma boa amostra de que o cache lembra conteúdos, não momentos.) A seção 7 usa `docker exec ... curl` para falar com o `revisor` de dentro de seu contêiner, sem publicar portas. E o script, como os da Lição 3, apaga ao sair as imagens que criou; para manter a `1.1.0`, construa-a depois no projeto local com `docker build -t curso-docker-revisor:1.1.0 .`.

#### 4.5.3 Os números

As seções 1 e 2 da saída:

```text
$ PREFIJO=curso-docker-l04- ./fig04_03.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## 1. En frío: sin caché de capas y con la caché de compilación vacía
curso-docker-revisor:1.0.0 (Dockerfile.leccion3 --no-cache): 9909 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY . .
  paso 4  DONE 7.1s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile --no-cache): 12207 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 10.5s RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## 2. Otra vez, sin cambiar nada
curso-docker-revisor:1.0.0 (Dockerfile.leccion3): 1176 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY . .
  paso 4  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
curso-docker-revisor:1.1.0 (Dockerfile): 628 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

Os tempos mudam a cada execução; a sequência de `CACHED` e `DONE` é estável. (O `WORKDIR /src` sai `CACHED` mesmo com `--no-cache`. É um detalhe de como o BuildKit trata esse passo, que não acrescenta arquivos do contexto nem executa nada, e não muda o que importa: os `COPY` e o `RUN` foram refeitos.)

**A frio**, os dois compilam tudo do zero. Os tempos desta execução (9,9 e 12,2 s) dependem sobretudo do ruído da máquina: em execuções anteriores do mesmo script, com os mesmos builds e a máquina mais ou menos ocupada, saíram 12,5 contra 7,1 s, 18,6 contra 10,5 s e 20,2 contra 23,0 s, às vezes ganhando um e às vezes o outro. O estável é a ordem de grandeza: **dez a vinte segundos**, o custo de compilar tudo. Nenhuma ordem tira esse custo: o primeiro build sempre se paga.

**Sem mudanças**, os dois saem inteiros do cache em menos de um segundo. Também não há diferença aqui: o cache funciona igualmente bem com os dois Dockerfiles quando nada mudou.

A diferença aparece na seção 3, **com uma mudança**, que é a vista em 4.2.2 e 4.3.3: 13,0 s contra 1,8 s, e o `RUN` em 10,1 s contra 0,8 s. E esse é o caso que importa, porque é o de todos os dias: muda-se algo e constrói-se de novo.

A seção 4 fecha com um caso que se conecta com o que vem a seguir:

```text
## 4. Cambio un archivo que el .dockerignore deja fuera
curso-docker-revisor:1.1.0 (Dockerfile): 790 ms
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

Um `NOTAS.md` foi acrescentado à pasta e tudo saiu do cache. O arquivo nem chegou ao builder: o `.dockerignore` o deixou de fora (4.6). O que não viaja não pode invalidar nada.

> [!NOTE]
> 🔧 **Observação de engenharia 4.3**
> Um tempo de build sozinho, sem a tabela de passos, não diz nada útil: não se sabe se foi lento porque compilou, porque baixou ou porque a máquina estava ocupada. Quando um build demora mais do que o esperado, a primeira pergunta não é «quanto demorou?», e sim «que passo foi refeito, e por quê?». `--progress=plain` dá essa resposta passo a passo.

### 4.6 O que viaja no contexto

#### 4.6.1 O BuildKit só pede o que precisa

Na Lição 3 viu-se que o contexto é a pasta passada a `docker build` e que o `.dockerignore` diz o que não viaja. Falta uma peça: **o BuildKit não envia o contexto inteiro**. Entre as melhorias que sua documentação lista em relação ao builder anterior há duas que vão aparecer agora mesmo: «transferir de forma incremental só os arquivos que mudaram no contexto entre builds» e «detectar e pular a transferência de arquivos que não são usados no contexto» ([Docker, «BuildKit»](https://docs.docker.com/build/buildkit/)).

`fig04_04.sh` mede isso. Ele planta na pasta do projeto um backup de 50 MB e uma pasta `.git` falsa de 10 MB, e constrói três vezes:

```bash
#!/usr/bin/env bash
# fig04_04.sh — Qué viaja en el contexto. Siembra en la carpeta un respaldo de
# 50 MB y una carpeta .git falsa de 10 MB, y construye tres veces:
#   1) Dockerfile de esta lección (COPY selectivos), con .dockerignore;
#   2) Dockerfile de la Lección 3 (COPY . .), con .dockerignore;
#   3) Dockerfile de la Lección 3, SIN .dockerignore: falla a propósito.
# Borra al salir lo que crea.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
# La caché de compilación de ESTE guion, con un id propio: así nunca toca la
# caché curso-docker-go-build de tu proyecto ni la de otro proyecto.
CACHE_ID="${PREFIJO}fig04-go-build"
L4="${PREFIJO}revisor:1.1.0"
CON="${PREFIJO}revisor:con-ignore"
SIN="${PREFIJO}revisor:sin-ignore"

cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/.dockerignore" "$AQUI/estado/Dockerfile.leccion3" "$TRABAJO/revisor/"
sed "s/id=curso-docker-go-build/id=${CACHE_ID}/" "$AQUI/estado/Dockerfile" > "$TRABAJO/revisor/Dockerfile"
cd "$TRABAJO/revisor"

titulo() { printf '\n## %s\n' "$*"; }
muestra() {
  printf '$ %s\n' "$*"
  local rc=0
  eval "$@" 2>&1 || rc=$?
  [ "$rc" -ne 0 ] && echo "[código de salida: $rc]"
  return 0
}
# borrar_cache: borra SOLO la caché de compilación con este id exacto. El id
# va entre [^a-z0-9-] para que no atrape otro id que lo contenga.
borrar_cache() {
  docker buildx prune -f --filter type=exec.cachemount \
    --filter "description~=[^a-z0-9-]${CACHE_ID}[^a-z0-9-]" >/dev/null 2>&1 || true
}
trap 'docker rmi -f "$L4" "$CON" "$SIN" >/dev/null 2>&1; borrar_cache; rm -rf "$TRABAJO"' EXIT

titulo "La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB"
head -c 52428800 /dev/urandom > respaldo.tar
mkdir -p .git && head -c 10485760 /dev/urandom > .git/objeto-falso
muestra "for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size \$f; done"

titulo "1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore"
muestra "docker build --progress=plain -t $L4 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore"
muestra "docker build --progress=plain -t $CON -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"

titulo "3. Dockerfile de la Lección 3, SIN .dockerignore"
mv .dockerignore dockerignore.apartado
muestra "docker build --progress=plain -t $SIN -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo \"construcción: código \$?\"; grep 'transferring context' ../construccion.log | tail -1"
grep -E -A4 '^#[0-9]+ ERROR|error obtaining' ../construccion.log | head -8
mv dockerignore.apartado .dockerignore
```

`head -c 52428800 /dev/urandom` escreve 50 MB de bytes aleatórios: um arquivo que pesa como um backup real e que não pode ser compactado. `du -sh --apparent-size` mede o tamanho de cada coisa. De cada build, o script guarda o log e procura a linha `transferring context`, que diz quanto o cliente enviou ao builder. É `set -uo pipefail`, sem `-e`, porque o terceiro build falha de propósito e o script precisa continuar. Os três builds usam três tags diferentes (`1.1.0`, `con-ignore` e `sin-ignore`) para que na saída se leia o que é cada um.

```text
$ PREFIJO=curso-docker-l04- ./fig04_04.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## La carpeta: el código, un respaldo de 50 MB y un .git falso de 10 MB
$ for f in respaldo.tar .git cmd internal go.mod .; do du -sh --apparent-size $f; done
50M	respaldo.tar
10M	.git
15K	cmd
27K	internal
41	go.mod
61M	.

## 1. Dockerfile de la Lección 4 (COPY selectivos), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:1.1.0 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 42.80kB done

## 2. Dockerfile de la Lección 3 (COPY . .), con .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:con-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 0
#7 transferring context: 1.00kB done
```

Os números de passo (`#7`) e os tempos podem mudar; os tamanhos transferidos são estáveis rodando o script como está.

A pasta pesa **61 MB**, e o código, uns 42 kB. No primeiro build viajaram **42.80 kB**: o código e nada mais. No segundo viajou **1.00 kB**, embora o Dockerfile da Lição 3 peça tudo com `COPY . .`. As duas frases da documentação explicam os dois números:

- **«Pular o que não é usado»**: no primeiro, o backup e o `.git` não viajaram por dois motivos ao mesmo tempo. O `.dockerignore` os exclui, e além disso os `COPY` só pedem `go.mod`, `cmd/` e `internal/`.
- **«Só o que mudou»**: no segundo, o código já estava do lado do builder desde o primeiro, e não tinha mudado. Só foram enviadas diferenças. Por isso o número da linha `transferring context` depende do que foi construído antes nessa mesma pasta: na primeira vez envia o código; nas seguintes, quase nada.

#### 4.6.2 Sem `.dockerignore`: o erro da lição

O terceiro build é o do Dockerfile da Lição 3, com `COPY . .`, **sem** `.dockerignore`:

```text
## 3. Dockerfile de la Lección 3, SIN .dockerignore
$ docker build --progress=plain -t curso-docker-revisor:sin-ignore -f Dockerfile.leccion3 . > ../construccion.log 2>&1; echo "construcción: código $?"; grep 'transferring context' ../construccion.log | tail -1
construcción: código 1
#6 transferring context: 62.93MB 0.1s done
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
------
 > [4/4] RUN go build -o /usr/local/bin/revisor ./cmd/revisor:
0.344 error obtaining VCS status: exit status 128
0.344 	Use -buildvcs=false to disable VCS stamping.
------
```

Os números de passo e os tempos (`0.344`, `0.1s`) mudam; o resto é estável.

Duas coisas aconteceram. A primeira, a esperada: viajaram **62.93 MB**, o backup, o `.git` e o código. São os 62 MB da cena: os de uma pasta sem `.dockerignore`, com um backup e o histórico do Git. Na máquina local é um segundo; em um servidor de build que envia o contexto pela rede, a cada build, isso se nota. E o que viaja com `COPY . .` acaba dentro da imagem, como o `.env` da Lição 3.

A segunda é a surpresa: **o build falhou**, e não por causa do Docker. O `.git` chegou a `/src` dentro da imagem, e o Go, ao compilar, o viu. Por padrão, o Go tenta gravar no executável as informações do controle de versão (que *commit*, se havia mudanças não salvas), e faz isso quando o pacote principal, seu módulo e a pasta atual estão no mesmo repositório ([documentação do `go`, opção `-buildvcs`](https://pkg.go.dev/cmd/go#hdr-Build_flags)). Para isso chamou a ferramenta de controle de versão e, como o `.git` era falso, a ferramenta falhou: `exit status 128`. O Go parou e sugeriu `-buildvcs=false`.

Este erro aparece na vida real com um `.git` de verdade, mas incompleto, ou em uma imagem onde a ferramenta `git` não consegue ler o repositório. E com um repositório completo e saudável ele não falha, mas faz algo pior sem avisar: grava dados do repositório no executável, e o conteúdo da imagem passa a depender de haver mudanças não salvas na pasta.

#### 4.6.3 O `.dockerignore` da lição

A correção não é `-buildvcs=false`. É o `.git` não viajar. Este é o `.dockerignore` com que a lição termina; ele substitui o da Lição 3:

```text
# fig04_02.dockerignore
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

As cinco linhas da Lição 3 continuam ali, com seu porquê. Acrescentam-se três:

- **`*.md`**: as notas, o `README.md`, o diário de bordo. O `revisor` não precisa de nenhum arquivo Markdown para ser compilado, e na seção 4 de `fig04_03.sh` viu-se que, com esta linha, editar as notas não invalida nada.
- **`compose.yaml`**: o arquivo que descreve o sistema completo e que vai ser escrito na Lição 9. Descreve como a imagem **roda**; não tem nada a fazer **dentro** dela.
- **`secretos/`**: a pasta onde, a partir da Lição 6, vão viver os arquivos com tokens falsos. É excluída desde hoje, antes de existir, pelo mesmo motivo pelo qual na Lição 3 o `.env` foi excluído antes de haver um: no dia em que alguém criar essa pasta, o `.dockerignore` já vai estar esperando por ela.

Com este arquivo e os `COPY` seletivos, há duas barreiras entre a pasta e a imagem: o que o `.dockerignore` deixa viajar e, disso, só o que algum `COPY` pede.

> [!NOTE]
> 🔧 **Observação de engenharia 4.4**
> Os `COPY` seletivos fazem o `.dockerignore` parecer desnecessário: no build 1 não viajou nada a mais. Não confie nisso. No dia em que alguém acrescentar um `COPY . .` (por pressa, ou para copiar um arquivo novo), a única barreira que sobra é o `.dockerignore`. Defesas que se apoiam uma na outra se escrevem as duas.

### 4.7 Revisar antes de construir

O hábito da Lição 3 não se perde porque o Dockerfile mudou. `fig04_06.sh` revisa o Dockerfile novo com `docker build --check`, que roda as verificações sem construir nada ([Docker, «Build checks»](https://docs.docker.com/build/checks/)):

```bash
#!/usr/bin/env bash
# fig04_06.sh — Revisar el Dockerfile de la lección antes de construir, como en
# la Lección 3. No construye nada ni crea contenedores.
set -euo pipefail
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT
cp -R "$AQUI/../revisor" "$TRABAJO/revisor"
cp "$AQUI/estado/Dockerfile" "$AQUI/estado/.dockerignore" "$TRABAJO/revisor/"
cd "$TRABAJO/revisor"
docker build --check . 2>&1 | tail -1
```

```text
$ ./fig04_06.sh
Check complete, no warnings found.
```

Esta saída é estável. O `tail -1` deixa só o veredito; sem ele apareceriam os mesmos passos `[internal]` da Lição 3. O `RUN --mount` não incomoda a verificação: é sintaxe vigente do Dockerfile, e a linha `# syntax=docker/dockerfile:1` do início garante que o builder a entenda.

### 4.8 O que aparece em outros projetos

- **`COPY go.mod go.sum ./` seguido de `RUN go mod download`.** É o truque mais famoso para projetos Go com dependências: baixá-las em uma camada que só é refeita quando a lista muda. É uma boa ideia **quando há dependências**. O `revisor` não tem nenhuma (por isso não tem `go.sum`), então essa camada não teria nada a baixar. Ao empacotar um projeto com dependências, esse par de linhas vai exatamente onde aqui está `COPY go.mod ./`, e o guia do Docker usa ainda uma segunda montagem de cache, `target=/go/pkg/mod`, para os módulos baixados ([Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/)).
- **Tudo em um único `RUN` gigante com `&&`.** Faz sentido para instalar pacotes e limpar na mesma camada (lembre-se da Observação 4.1: o que é apagado em outra camada continua pesando). Não faz sentido para misturar passos que mudam em ritmos diferentes.
- **`DOCKER_BUILDKIT=0`.** Ativa o builder anterior ao BuildKit (o *legacy builder*), que não tem montagens de cache nem as transferências incrementais de 4.6. O BuildKit é o builder padrão do Docker Engine ([Docker, «BuildKit»](https://docs.docker.com/build/buildkit/)); se um tutorial pedir para desativá-lo, desconfie do tutorial. Não confunda com `docker builder`, que é só o grupo de comandos para administrar builds, como `docker builder prune` ([`docker builder`](https://docs.docker.com/reference/cli/docker/builder/)).
- **`docker system prune -a` ou `docker builder prune -a` «para liberar espaço».** Apagam o cache de **todos** os projetos da máquina. Já se sabe por que não (4.4.5).

## O erro que se vai ver

Esta lição tem um erro principal e um sintoma que não dá erro, mas custa tempo.

**1. O `.git` que quebra a compilação.**

```text
#10 0.344 error obtaining VCS status: exit status 128
#10 0.344 	Use -buildvcs=false to disable VCS stamping.
#10 ERROR: process "/bin/sh -c go build -o /usr/local/bin/revisor ./cmd/revisor" did not complete successfully: exit code: 1
```

Lê-se de cima para baixo: o Go tentou obter o estado do controle de versão (*VCS status*), a ferramenta falhou com o código 128, e o Go sugere não gravar essa informação. A última linha é do Docker: o `RUN` terminou com código 1 e o build parou. A causa quase nunca está no código: é que um `.git` chegou à imagem. Confira nesta ordem: o `.dockerignore` está na raiz do contexto, junto do `Dockerfile`? Ele diz `.git`? Há um `COPY . .` no Dockerfile? A correção é o `.git` não viajar. `-buildvcs=false` também tira o erro, mas deixa o `.git` viajando e entrando na imagem: é desligar o alarme sem apagar o fogo.

**2. Tudo é reconstruído embora pouco tenha mudado.** Não há mensagem de erro; só há espera. Diagnostica-se com `--progress=plain`: procure o **primeiro** passo que diz `DONE` em vez de `CACHED` depois do `FROM`. Esse é o passo cujo conteúdo mudou, e tudo o que está abaixo se repetiu pela regra 3. Se esse primeiro passo é um `COPY . .`, a correção já é conhecida (4.3). Se é um `COPY` de um arquivo que não foi tocado, procure o que mais mudou nesse caminho: um arquivo gerado, algumas notas, um backup. O que não deve invalidar o cache também não deve viajar: vai para o `.dockerignore`.

## O hábito de segurança da lição

**O contexto de build não leva `.git`, `.env`, backups nem segredos, e a verificação do Dockerfile é sempre executada.** O hábito evita dois acidentes. O primeiro é o de 4.6: um `.git`, um `.env` ou um backup que viajam para um servidor de build e, com um `COPY . .`, ficam dentro de uma imagem que depois é publicada. O `.git`, além disso, pode guardar segredos que alguém apagou do código, mas não do histórico. O segundo é mais silencioso: o cache de compilação com o `id` de outro projeto, ou uma remoção ampla que leva o de todos. Um `id` próprio e uma remoção com o `id` completo mantêm cada projeto em sua pista.

E um bônus de segurança trazido pela montagem de cache: o que o compilador deixa em seu cache não fica na imagem. Menos arquivos dentro é menos superfície, e menos coisas a explicar no dia em que alguém revisar o que a imagem traz.

## O que se faz errado

**`COPY . .` e depois compilar.** Qualquer mudança, mesmo que seja um comentário ou uma nota, repete a compilação completa. Copie primeiro o que muda pouco e no final o que muda muito.

**Confiar que o cache «percebe» o que mudou.** O cache é uma corrente: rompe-se no primeiro elo que muda e tudo o que está abaixo se repete. A ordem do Dockerfile é a ferramenta para que esse elo fique o mais abaixo possível.

**Apagar o cache de compilação com `rm -rf` no final do `RUN`.** Reduz a camada, mas também joga fora o que acelera o build seguinte. A montagem de cache dá as duas coisas: a camada pequena e o cache vivo.

**Usar `-buildvcs=false` para tirar o erro do `.git`.** Tira o sintoma e deixa o `.git` dentro da imagem.

**Medir só o tempo total.** Um número sem a tabela de passos não diz o que foi refeito. `--progress=plain` diz.

**Usar o `id` padrão ou um `id` genérico para a montagem de cache.** Projetos diferentes acabam compartilhando, e atropelando, o mesmo cache.

**Limpar com `prune -a` ou com um filtro amplo.** Leva o cache de outros projetos da mesma máquina. Apaga-se com o tipo e o `id` completo.

**Tirar linhas do `.dockerignore` porque «com `COPY` seletivos já não é necessário».** É necessário no dia em que alguém voltar a escrever `COPY . .`.

## Exercícios

Faça-os em ordem e escreva a previsão no [diário de bordo](bitacora.md) antes de rodar cada um. Ao terminar, apague o que foi criado: tudo leva o prefixo `curso-docker-`, e o cache de compilação dos exercícios é apagado com o comando de 4.4.5 e seu próprio `id`.

### Exercício 1 — Prever o cache

Com o Dockerfile da lição e um build anterior no cache, preveja para cada mudança que passos vão dizer `CACHED` e quais `DONE`. Faça isso no papel, usando as três regras de 4.2.1, e depois confira com `fig04_05.sh`, que aplica as quatro mudanças uma depois da outra:

a) Muda-se só a data de `internal/reporte/tabla.go` com `touch`, sem mexer no conteúdo.
b) Acrescenta-se um comentário no final de `cmd/revisor/main.go`.
c) Acrescenta-se um comentário no final de `go.mod`.
d) Acrescenta-se um comentário (`# ...`) no final do `Dockerfile`.

E mais uma pergunta: no caso c, espera-se que o `RUN go build` demore muito ou pouco? Por quê?

### Exercício 2 — O `.dockerignore` como única barreira (projeto)

Copie `programas/revisor/` para uma pasta própria e coloque nela o `.dockerignore` da lição e, como `Dockerfile.leccion3`, o Dockerfile da Lição 3, o do `COPY . .`. De propósito: com `COPY . .`, o `.dockerignore` é a única barreira. Construa uma vez `curso-docker-revisor:1.0.0-ej2` com `-f Dockerfile.leccion3 --progress=plain` e anote a linha `transferring context`. Depois crie na pasta um `README.md`, uma pasta `secretos/` com um arquivo `token.txt` falso e um arquivo `datos.json` de 5 MB (`head -c 5242880 /dev/urandom > datos.json`). Antes de reconstruir, preveja quais dos três viajam. Reconstrua e olhe a linha de novo. Depois acrescente ao `.dockerignore` o que for necessário e reconstrua uma terceira vez. O exercício se autocorrige: terminou quando o contexto transferido volta a ter poucos kilobytes e `docker run --rm curso-docker-revisor:1.0.0-ej2 ls -A /src` mostra só `cmd`, `go.mod` e `internal`. No final, `docker rmi curso-docker-revisor:1.0.0-ej2` e apague a pasta.

### Exercício 3 — Corrigir a ordem

Um colega escreveu este Dockerfile para o `revisor`. Funciona, mas cada mudança no código repete tudo:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
WORKDIR /src
COPY internal/ internal/
COPY cmd/ cmd/
RUN go build -o /usr/local/bin/revisor ./cmd/revisor
COPY go.mod ./
USER 10001:10001
EXPOSE 8080
CMD ["revisor"]
```

1. Antes de construir: este build funciona ou falha? Pense no que `go build` precisa para compilar um módulo.
2. Encontre os problemas de ordem e de cache, e escreva a versão corrigida.
3. Construa a versão corrigida duas vezes, a segunda depois de mudar um comentário em `internal/reporte/tabla.go`, e confira com `--progress=plain` que `COPY go.mod ./` e `COPY cmd/ cmd/` dizem `CACHED`.

### Exercício 4 — Explicar para a colega

A colega da cena pergunta: «Se agora o `RUN go build` diz `DONE` toda vez que mudo código, o que ganhamos com o `--mount`? Ele continua se repetindo». Responda em no máximo cinco frases, usando as palavras *cache de camadas*, *montagem de cache*, *builder* e *imagem*.

## Soluções

### Solução 1

A saída real de `fig04_05.sh`:

```text
$ PREFIJO=curso-docker-l04- ./fig04_05.sh 2>&1 | sed 's/curso-docker-l04-/curso-docker-/g'

## a) Solo cambia la fecha de un archivo (touch), no su contenido
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## b) Un comentario nuevo en cmd/revisor/main.go
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.4s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## c) Un comentario nuevo en go.mod
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  DONE 0.0s  COPY go.mod ./
  paso 4  DONE 0.0s  COPY cmd/ cmd/
  paso 5  DONE 0.0s  COPY internal/ internal/
  paso 6  DONE 0.3s  RUN go build -o /usr/local/bin/revisor ./cmd/revisor

## d) Un comentario nuevo en el Dockerfile
  paso 1  DONE 0.0s  FROM docker.io/library/golang:1.27.3-trixie@sha256:604106102
  paso 2  CACHED     WORKDIR /src
  paso 3  CACHED     COPY go.mod ./
  paso 4  CACHED     COPY cmd/ cmd/
  paso 5  CACHED     COPY internal/ internal/
  paso 6  CACHED     RUN go build -o /usr/local/bin/revisor ./cmd/revisor
```

a) **Tudo `CACHED`.** A data de modificação não conta para o cache (regra 1); só o conteúdo.
b) **De `COPY cmd/` para baixo.** `cmd/` mudou; `internal/` não, mas vem depois, então se repete pela regra 3 (por isso diz `DONE` embora não tenha nada diferente); e o `RUN` também.
c) **De `COPY go.mod` para baixo: tudo.** `go.mod` é o primeiro `COPY`, então uma mudança ali invalida toda a corrente. Por isso só vai primeiro o que quase nunca muda.
d) **Tudo `CACHED`.** O cache é calculado por instrução, e um comentário não é uma instrução: nenhum passo mudou. (Uma mudança em uma instrução, por outro lado, invalida esse passo e os de baixo.)

A pergunta extra: no caso c, o `RUN` se repete, mas demora **pouco** (0,3 s nesta execução), porque a montagem de cache já tem compilados todos os pacotes e um comentário em `go.mod` não muda o que o Go precisa compilar. O cache de camadas disse «repita o passo»; o cache do Go disse «mas quase não há nada a fazer». Se os tempos saírem diferentes, tudo bem; o que deve coincidir é a coluna de `CACHED` e `DONE`.

### Solução 2

No segundo build viaja **`datos.json`**, e a linha `transferring context` o denuncia: passa de kilobytes para uns 5 MB. `README.md` não viaja (é excluído por `*.md`) nem `secretos/` (tem sua linha). Com `COPY . .`, `datos.json` além disso entra na imagem: `ls -A /src` o mostra. A correção é mais uma linha no `.dockerignore`: `datos.json`, ou `*.json` se o `revisor` não precisa de nenhum JSON para ser compilado, que é o caso. Com isso, o terceiro build volta a transferir poucos kilobytes e `/src` fica com `cmd`, `go.mod` e `internal`. Se o número não baixar, confira se o `.dockerignore` está na raiz do contexto, junto dos Dockerfiles.

Repare que com o Dockerfile da lição, o dos `COPY` seletivos, `datos.json` não teria viajado nem sem essa linha, porque nenhum `COPY` o pede. É a Observação 4.4 em ação: com `COPY . .`, o `.dockerignore` é a única barreira; com `COPY` seletivos, é a segunda. Escreva-o do mesmo jeito.

### Solução 3

1. **Falha.** `go build` precisa do `go.mod` para saber que módulo está compilando, e neste Dockerfile o `go.mod` chega **depois** do `RUN`. Compilar sem `go.mod` dá este erro, medido dentro da imagem `golang:1.27.3-trixie` com um pacote `main` mínimo em `cmd/revisor`: `go: go.mod file not found in current directory or any parent directory; see 'go help modules'`. Dentro do build, ele aparece com o formato de um `RUN` que falha, como em 4.6.2.
2. Os problemas: `go.mod` vem depois do `RUN` (erro) e deveria vir primeiro (cache); `internal/` vem antes de `cmd/`, ao contrário da ordem da lição (menos grave, mas o que muda mais deve ficar embaixo); e o `RUN` não tem montagem de cache, então cada mudança compila do zero. A versão corrigida é `fig04_01.Dockerfile`.
3. Com a versão corrigida, depois da mudança em `tabla.go`, a tabela diz `CACHED` em `WORKDIR`, `COPY go.mod ./` e `COPY cmd/ cmd/`, e `DONE` em `COPY internal/ internal/` e no `RUN`, como em 4.3.3.

### Solução 4

Uma resposta possível: «O **cache de camadas** decide se um passo se repete e, como o código mudou, o `RUN go build` se repete: nada evita isso. O que a **montagem de cache** faz é que, quando ele se repete, o Go encontra ali tudo o que compilou da vez anterior e só recompila o pacote que foi tocado. Esse cache é guardado pelo **builder**, à parte, e não entra na **imagem**. Por isso o `RUN` passou de 10,1 para 0,8 segundo, e a camada da compilação pesa 100 MB a menos. Ele se repete, sim, mas quase de graça».

## Como sei que consegui

Marque cada ponto só se ele foi comprovado na própria máquina:

- [ ] `docker build --check .` com o Dockerfile da lição termina com `Check complete, no warnings found.`
- [ ] `docker history curso-docker-revisor:1.1.0` mostra três camadas `COPY` separadas e um `RUN` de uns 10 MB.
- [ ] `docker image ls curso-docker-revisor` mostra a `1.1.0` mais leve que a `1.0.0` (nestas execuções, 1.32 GB contra 1.45 GB).
- [ ] Depois de mudar um comentário em `internal/`, `--progress=plain` mostra `CACHED` em `COPY go.mod ./` e em `COPY cmd/ cmd/`, e o `RUN` leva menos de um par de segundos.
- [ ] Acrescentar ou editar um arquivo `.md` na pasta não invalida nenhum passo.
- [ ] Com um arquivo grande na pasta, a linha `transferring context` continua em kilobytes.
- [ ] Dá para ler o erro `error obtaining VCS status` e corrigi-lo com o `.dockerignore`, não com `-buildvcs=false`.
- [ ] O cache de compilação foi apagado com `docker buildx prune` filtrando por `type=exec.cachemount` e pelo `id` completo, e `docker buildx du --filter 'description~=curso-docker-go-build'` já não o mostra.
- [ ] Ao terminar, `docker ps -a --filter name=curso-docker-` não mostra nada, e das imagens do `revisor` só fica a que se quer manter.

## Resumo

Responda sem olhar a lição:

1. O que é uma camada? Que instruções acrescentam arquivos e quais só dados? Com que comando elas são vistas?
2. O que o cache olha para decidir se um `COPY` se repete? E para um `RUN`? A data de um arquivo conta?
3. O que acontece com os passos de baixo quando um é invalidado? Que consequência isso tem para a ordem do Dockerfile?
4. O que `RUN --mount=type=cache` faz? Onde vive esse cache e por que ele não fica na imagem?
5. Para que serve o `id` de uma montagem de cache, e por que um `prune` com um filtro amplo é perigoso?
6. O que significam `CACHED` e `DONE` em `--progress=plain`? Quando `plain` aparece mesmo sem ser pedido?
7. Que arquivos o cliente envia ao builder? Por que o segundo build transfere menos que o primeiro?
8. O que causa o erro `error obtaining VCS status` e qual é a correção certa?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [Docker, «Docker build cache»](https://docs.docker.com/build/cache/): uma camada por instrução e a invalidação em cadeia.
- [Docker, «Build cache invalidation»](https://docs.docker.com/build/cache/invalidation/): as regras para `COPY`, `ADD` e `RUN`, e que a data de modificação não conta.
- [Docker, «Optimize cache usage»](https://docs.docker.com/build/cache/optimize/): a ordem das camadas, o contexto pequeno, as montagens de cache e seu exemplo para Go.
- [Referência do Dockerfile, `RUN --mount=type=cache`](https://docs.docker.com/reference/dockerfile/#run---mounttypecache): as opções `id`, `target`, `sharing` e as demais, e o `id` padrão.
- [Docker, «Understanding the image layers»](https://docs.docker.com/get-started/docker-concepts/building-images/understanding-image-layers/): o que é uma camada e por que ela é reutilizada.
- [`docker image history`](https://docs.docker.com/reference/cli/docker/image/history/): o comando, `--format` e `--no-trunc`.
- [`docker buildx build`, opção `--progress`](https://docs.docker.com/reference/cli/docker/buildx/build/#progress): os modos `auto`, `tty`, `plain`, `quiet` e `rawjson`.
- [`docker buildx prune`](https://docs.docker.com/reference/cli/docker/buildx/prune/): os filtros `until`, `id`, `description` e `type`, com o tipo `exec.cachemount`.
- [Docker, «BuildKit»](https://docs.docker.com/build/buildkit/): a transferência incremental do contexto e o salto dos arquivos que não são usados.
- [`docker builder`](https://docs.docker.com/reference/cli/docker/builder/): o grupo de comandos para administrar builds.
- [Docker, «containerd image store»](https://docs.docker.com/engine/storage/containerd/): que o armazenamento guarda as imagens compactadas e descompactadas.
- [Docker, «Build checks»](https://docs.docker.com/build/checks/): `docker build --check`.
- [Documentação do comando `go`](https://pkg.go.dev/cmd/go): o cache de compilação («Build and test caching») e a opção `-buildvcs`.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões de «Sobre as execuções».
- [Colima](https://github.com/abiosoft/colima): a ferramenta com que os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| **cache de build** | os resultados de passos anteriores que o builder guarda para não repeti-los |
| **cache de camadas** | a parte do cache que decide se um passo inteiro se repete ou sai já pronto |
| **camada** (*layer*) | o conjunto de mudanças de arquivos que um passo do Dockerfile deixa |
| **`CACHED`** | em `--progress=plain`, o passo saiu do cache |
| **contexto de build** | os arquivos que o build pode usar; o BuildKit só transfere os que são pedidos e os que mudaram |
| **`DONE`** | em `--progress=plain`, o passo foi feito de verdade, com seu tempo |
| **invalidar** | um passo deixar de poder sair do cache porque algo do que ele usa mudou |
| **montagem de cache** | pasta que o builder guarda à parte e monta em um `RUN`; seu conteúdo não fica na imagem |
| **`--progress=plain`** | o formato de texto puro de um build, passo a passo |
| **VCS** (*version control system*) | o sistema de controle de versão, como o Git |

---

**Próxima:** [Lição 5 — Multi-stage: de gigabytes a megabytes](05-multi-stage.md)
