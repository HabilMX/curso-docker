# Lição 8 — Volumes e redes

É segunda-feira, 9h05 da manhã. Às 10h há uma reunião de revisão com a área de operações e pediram para levar o último relatório do `revisor`: quais serviços falharam durante o fim de semana. Na sexta à noite alguém atualizou o contêiner como sempre se faz: `docker rm -f`, `docker run` com a imagem nova, e para casa. O terminal é aberto, o relatório é procurado e não está lá. Não está no contêiner novo, que acaba de nascer, e o velho já não existe. Enquanto isso é assimilado, nota-se outra coisa: o contêiner novo diz `FALLA` para o serviço de teste, com uma mensagem que ainda não tinha aparecido: `lookup curso-docker-prueba ... no such host`. O serviço de teste está rodando, o `docker ps` o mostra, o `curl` da máquina chega até ele. Mas o `revisor` jura que ele não existe. São 9h12. Há dois problemas que parecem distintos e são a mesma pergunta: **onde vive o que um contêiner precisa conservar, e por onde ele encontra os demais?** Esta lição existe para que essa pergunta possa ser respondida antes das dez: o relatório é guardado em um lugar que sobrevive ao contêiner, com o dono correto, e os contêineres se encontram por nome em uma rede definida por quem opera, com a parte que não precisa de internet trancada em uma rede sem saída.

**Tempo:** 2 × 45 min

**O que se constrói:** o relatório que sobrevive e dois contêineres que conversam. A imagem `curso-docker-revisor:1.5.0` traz uma pasta `/datos` que pertence ao usuário sem privilégios `65532` e guarda ali seu relatório por padrão. Um volume nomeado, `curso-docker-reportes`, é montado nessa pasta e conserva o relatório mesmo que o contêiner seja apagado. O serviço de teste vive **apenas** em uma rede interna, `curso-docker-interna`, sem saída para a internet; o `revisor` vive em uma rede definida por quem opera, `curso-docker-red`, por onde expõe sua porta, e se conecta também à interna para verificar o serviço de teste pelo nome.

**O que se aprende:** onde um contêiner escreve e por que isso se perde; os três tipos de montagem (volumes nomeados, *bind mounts* e `tmpfs`) e quando usar cada um; `-v` versus `--mount`; quem é o dono dos arquivos quando o processo não é `root`, e como corrigir isso a partir da imagem e não com `root`; o que acontece com o conteúdo de uma pasta quando se monta algo por cima (às vezes é copiado, às vezes é coberto); a rede padrão e por que ali não há nomes; as redes definidas pelo usuário e seu DNS interno; e as redes internas, sem saída.

**De onde se parte.** Da [Lição 7](07-salud-y-ciclo-de-vida.md) traz-se a imagem `curso-docker-revisor:1.4.0`, com seu `HEALTHCHECK` e seu `STOPSIGNAL`, e a forma de rodá-la reforçada: sistema de arquivos somente leitura, sem capabilities, sem escalada de privilégios, com `--init` e com limites. Traz-se também uma promessa: na Lição 7 o relatório era guardado em um `tmpfs`, que morre com o contêiner, e ficou pendente dar-lhe um lugar que dure. Da [Lição 6](06-configuracion-y-secretos.md) traz-se a montagem de um arquivo avulso (o token em `/run/secrets/`), usada sem explicação a fundo, e o erro de permissões com o usuário `65532`: hoje esse mesmo erro volta, em uma pasta inteira. Da [Lição 2](02-contenedores-dia-a-dia.md) traz-se a imagem `curso-docker-prueba:1.0.0` e o costume de publicar portas só em `127.0.0.1`. E da [Lição 3](03-primer-dockerfile.md), uma frase que hoje ganha sentido: o `revisor` verificava a si mesmo «porque ainda não há rede entre contêineres».

**O que esta lição não faz.** Não usa o Compose: tudo é feito com `docker volume`, `docker network` e `docker run`, para que se veja cada peça; a [Lição 9](09-compose.md) escreve o mesmo em um `compose.yaml`. Não ensina drivers de volumes remotos (armazenamento em rede, na nuvem) nem redes que cruzam várias máquinas (*overlay*): este curso trabalha em uma única máquina, e o que se aprende aqui (o dono dos arquivos, o DNS por nome, a rede sem saída) é o que essas outras ferramentas também exigem. Não usa a rede `host` a não ser para dizer por que ela não se usa. E não faz backup nem restaura volumes com ferramentas especiais: o relatório é lido com um contêiner auxiliar, que é a forma de olhar dentro de um volume que funciona em qualquer máquina.

**Sobre as execuções.** Todas as saídas são reais e foram obtidas em 21 de outubro de 2026 em um Mac com [Colima](https://github.com/abiosoft/colima), que sobe uma máquina virtual com Ubuntu 24.04.4, a mesma base do Linux Mint 22, o sistema de referência do curso, com kernel 6.8 e processador `arm64`. Os scripts foram executados **dentro** dessa máquina virtual, com Docker 29.2.1 (cliente e daemon) e Buildx v0.31.1, e com a pasta de trabalho no disco próprio do Linux. Isso importa muito nesta lição, que trata de donos e permissões: as pastas compartilhadas entre o Mac e a máquina virtual mentem sobre eles, e nenhum exemplo de donos foi medido em uma dessas pastas. No Mint esse problema não existe. Duas diferenças que se verão com os próprios olhos: na máquina virtual o usuário que executou os scripts é o `501`, com grupo `1000`, de modo que onde a saída diz `501:1000` o Mint dirá quase certamente `1000:1000`, o primeiro usuário criado ao instalar; e as datas dos `ls -l` estão na hora da máquina virtual, que é a do meridiano de Greenwich. Para não colidir com outras execuções que usavam a mesma máquina, os scripts foram lançados com outro prefixo de nomes e outra porta (as variáveis `PREFIJO` e `PUERTO` que eles trazem). Como nesta lição os nomes de redes, volumes e contêineres **aparecem** nas saídas (o DNS os usa), os scripts que mostram nomes trazem uma função `nombres` que, à vista, volta a escrever esse prefixo como `curso-docker-`; com o prefixo padrão não muda nada, de modo que o que se vê é o que se verá na máquina de quem estuda. Com seus valores padrão, os scripts usam nomes de apoio próprios que levam `fig08` (a imagem `curso-docker-revisor:fig08`, e `:fig08-l7`, a 1.4.0 que o `fig08_02.sh` constrói; o contêiner `curso-docker-revisor-fig08`, o volume `curso-docker-reportes-fig08`, as redes `curso-docker-red-fig08` e `curso-docker-interna-fig08`): assim nunca tocam na imagem `curso-docker-revisor:1.5.0`, no contêiner `curso-docker-revisor`, no volume `curso-docker-reportes` nem nas redes do projeto, e ao sair apagam só o que criaram. Pela mesma razão publicam sua porta, por padrão, em `127.0.0.1:8081`, e não na `8080` do `revisor`: assim podem ser executados com o estado final no ar (se a `8081` estiver ocupada, passe-lhes outra, por exemplo `PUERTO=8082 ./fig08_03.sh`; a porta não aparece nas saídas). Usam, sem modificá-las, duas imagens que já estão na máquina: `curso-docker-prueba:1.0.0`, da Lição 2, e `alpine:3.24.2`, um contêiner auxiliar com *shell* para olhar volumes e redes, porque as duas imagens do curso não têm *shell*. O curso foi planejado com Docker Engine 29.8.2, e a mais recente publicada naquele dia era a 29.9.2, de 20 de outubro de 2026 ([notas de versão](https://docs.docker.com/engine/release-notes/29/)); nada desta lição muda entre essas versões. O que **muda** de uma execução para outra, e é avisado onde aparece: os tempos da tabela do `revisor` (ocultados com `<t>`), o número do arquivo temporário do relatório (ocultado com `<n>`), os endereços IP dos contêineres e o do DNS da máquina (ocultados com `<IP>` e `<DNS del anfitrión>`), os identificadores de contêiner (`<id>`) e as datas. Tudo é ocultado no próprio script, à vista, nunca editando a saída. Os programas estão em [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes), cada um com sua saída ao lado, e `estado/` guarda os arquivos do projeto como ficam ao terminar.

## Ao terminar, será possível

- Explicar por que o que um contêiner escreve em seu próprio sistema de arquivos se perde com `docker rm`, e escolher entre um volume nomeado, um *bind mount* e um `tmpfs` para cada dado do `revisor`.
- Provocar e diagnosticar o `permission denied` de um volume novo com um processo sem privilégios, e corrigi-lo na imagem com `COPY --chown`, sem rodar como `root`.
- Demonstrar que o relatório sobrevive ao `docker rm` lendo-o a partir de um contêiner auxiliar.
- Prever o que acontece com o conteúdo de uma pasta quando se monta por cima um volume novo, um volume com dados ou um *bind mount*, e explicar a diferença entre `-v` e `--mount` quando a pasta da máquina não existe.
- Rodar o `revisor` com um *bind mount* de uma pasta própria, acertando o dono com `--user`, e montar como somente leitura o que o contêiner não deve mudar.
- Mostrar que na rede padrão um contêiner não encontra outro pelo nome, e que em uma rede definida pelo usuário encontra, lendo qual servidor DNS cada um usa.
- Trancar o serviço de teste em uma rede interna sem saída para a internet e conectar o `revisor` às duas redes, sem reiniciá-lo.

## O porquê antes do como

Até agora cada contêiner do curso foi uma ilha descartável. Era criado, perguntava-se algo a ele, era apagado. Isso foi bom para aprender, porque um contêiner descartável não pode guardar surpresas. Mas um serviço de verdade tem duas necessidades que uma ilha não cobre.

A primeira é **guardar algo que dure mais que ele**. O `revisor` escreve um relatório; esse relatório é justamente o que alguém vai pedir na segunda-feira. E um contêiner foi feito para ser substituído: cada atualização, cada mudança de configuração, cada reinício da máquina com `--rm` acaba em um contêiner novo. A documentação do Docker diz isso sem rodeios: o que se escreve na camada do contêiner «não persiste quando o contêiner é destruído», e além disso «pode ser difícil tirar os dados do contêiner se outro processo precisar deles» ([Docker, «Storage»](https://docs.docker.com/engine/storage/)). Se o relatório vive dentro do contêiner, vive o que o contêiner viver. E desde a Lição 7 o problema é ainda mais direto: o sistema de arquivos do `revisor` é **somente leitura**. Não é que o relatório vá se perder; é que nem sequer se pode escrevê-lo. Faz falta um lugar gravável, fora do contêiner, que o `revisor` possa usar sem deixar de ser somente leitura.

A segunda é **falar com outros contêineres**. O `revisor` existe para verificar serviços, e até hoje só verificou a si mesmo (`propio http://127.0.0.1:8080/salud`), porque dentro de um contêiner `127.0.0.1` é o próprio contêiner. Para verificar o serviço de teste ele precisa chegar a outro contêiner. Poderia usar o endereço IP, mas os endereços são distribuídos pelo Docker ao iniciar e mudam; ninguém quer escrever em `REVISOR_SERVICIOS` um endereço que deixa de valer no reinício seguinte. O que se quer é o que qualquer programa na internet faz: usar um **nome**. E assim que os contêineres se falam, aparece a pergunta de segurança da lição: se o serviço de teste só existe para que o `revisor` o consulte, por que ele deveria poder sair para a internet?

Então a lição tem duas metades, e as duas seguem o mesmo caminho: primeiro o erro, depois a correção.

1. **Armazenamento** (8.1 a 8.7): onde um contêiner escreve, os três tipos de montagem, o erro de dono que se vai encontrar com um usuário sem privilégios e sua correção na imagem, o que acontece com o que já havia na pasta, e o `tmpfs` para o que não deve durar.
2. **Redes** (8.8 a 8.11): a rede padrão, que não tem nomes; a rede definida por quem opera, que tem; e a rede interna, que não tem saída.

Com esse destino em mente, isto é o que se terá no final, na seção 8.10: o serviço de teste em uma rede sem saída, o `revisor` nas duas, encontrando-o pelo nome, e um contêiner que tenta sair para a internet a partir da rede interna e não consegue sequer resolver o nome do site:

```text
== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
```

## Os conceitos

### 8.1 Onde um contêiner escreve

#### 8.1.1 A camada gravável, e por que ela não serve para guardar

Na Lição 4 viu-se que uma imagem é uma pilha de camadas somente leitura. Quando o Docker cria um contêiner, coloca por cima **uma camada a mais, gravável e própria desse contêiner**. Tudo o que o processo escreve (um arquivo novo, um arquivo modificado, um arquivo apagado) fica nessa camada; as da imagem não são tocadas, e por isso cem contêineres podem sair da mesma imagem sem interferir uns nos outros.

Essa camada tem três problemas para guardar um relatório:

- **Morre com o contêiner.** O `docker rm` a apaga. O `docker run --rm` a apaga ao sair. Uma atualização que substitui o contêiner a joga fora.
- **É difícil tirar algo dela.** Está em algum lugar do armazenamento interno do Docker, com um caminho que não é para uso direto. Outro contêiner não consegue lê-la.
- **No `revisor` reforçado ela não existe para escrever.** Com `--read-only`, a camada gravável não aceita escritas. É justo o que se queria na Lição 7: quem tomar o controle do processo não pode escrever no disco. Mas o próprio `revisor` também não.

A saída é **montar** algo por cima de uma pasta do contêiner: um lugar gravável que não faz parte da camada do contêiner, que tem seu próprio ciclo de vida e que é montado só onde faz falta. O resto do sistema de arquivos continua somente leitura.

#### 8.1.2 Os três tipos de montagem

O Docker oferece três tipos de montagem de interesse aqui (há outros dois que não serão usados: os *named pipes*, só do Windows, e as montagens de imagem, que colocam o conteúdo de outra imagem dentro do contêiner e exigem o armazenamento de imagens do containerd). A documentação os apresenta assim ([Docker, «Storage»](https://docs.docker.com/engine/storage/)):

| Tipo | O que é | Onde vivem os dados | Quanto duram | Para quê |
|---|---|---|---|---|
| **Volume** (nomeado) | armazenamento «administrado pelo daemon do Docker» | em uma pasta do armazenamento do Docker, que não se toca | até que o volume seja apagado, mesmo que todos os contêineres sejam apagados | dados do serviço que devem durar: o relatório |
| ***Bind mount*** | «um vínculo direto» entre um caminho da máquina e um do contêiner | em uma pasta própria, onde se disser | o que durar essa pasta | arquivos que a pessoa e o contêiner devem ver: código em desenvolvimento, um arquivo de configuração, o token da Lição 6 |
| **`tmpfs`** | arquivos «diretamente na memória» da máquina | na memória | até que o contêiner pare | temporários que não devem durar nem tocar o disco |

A mesma página dá a recomendação curta: os volumes são para o armazenamento de longo prazo; os *bind mounts*, «quando é preciso acessar os arquivos tanto do contêiner quanto da máquina»; e os `tmpfs`, «apenas quando os dados não precisam persistir além da sessão do contêiner». No `revisor` isso se traduz em uma regra simples: **o relatório vai em um volume**. Os *bind mounts* já foram usados para o token e serão usados hoje para entender o problema dos donos; o `tmpfs`, para o que não deve sobreviver.

#### 8.1.3 Duas formas de escrever o mesmo: `-v` e `--mount`

O Docker aceita duas sintaxes para montar, e elas aparecem por toda parte:

- **`-v origem:destino[:opções]`** (ou `--volume`). Curta. Se a origem é um nome (`curso-docker-reportes`), é um volume; se é um caminho absoluto (`/home/usuario/reportes`), é um *bind mount*. As opções vão no final, separadas por vírgulas: `ro` para somente leitura, por exemplo.
- **`--mount type=…,src=…,dst=…[,opções]`**. Longa, com nomes em cada campo: `type=volume`, `type=bind` ou `type=tmpfs`, e depois `src` (a origem), `dst` (o destino), `readonly`, e as opções próprias de cada tipo.

A documentação de volumes diz que, «em geral, `--mount` é preferível», porque «é mais explícito e admite todas as opções disponíveis» ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). `--mount` admite todas as opções de cada tipo de montagem; `-v` só algumas. Para um volume, `-v` admite poucas: as de acesso (`ro` e `rw`), as de rotulagem do SELinux (`z` e `Z`, que no Mint não fazem falta) e a de não copiar o conteúdo da imagem, que será vista em 8.5. Essa segunda tem uma armadilha medida: a página de volumes a chama de `volume-nocopy` também com `-v`, mas o Docker 29.2.1 rejeita esse nome com `invalid mode: volume-nocopy`; com `-v` se escreve `nocopy` (`-v vol:/datos:nocopy`), e com `--mount`, `volume-nocopy`. Vê-se isso no `fig08_09.sh`, a solução do Exercício 4. E há uma diferença de comportamento que importa: quando a pasta da máquina **não existe**, `-v` a cria e `--mount`, por padrão, se recusa (8.5). Este curso usa `-v` para os volumes nomeados, porque é o que se lê na maioria dos exemplos e é igualmente claro (`-v curso-docker-reportes:/datos` não deixa dúvidas), e `--mount` para os *bind mounts* e os `tmpfs`, onde sua precisão evita erros.

### 8.2 Volumes nomeados

#### 8.2.1 Criar, olhar, apagar

Um volume é criado com `docker volume create <nome>`, listado com `docker volume ls`, inspecionado com `docker volume inspect` e apagado com `docker volume rm`. Se em um `docker run` se monta um volume que não existe, o Docker o cria naquele momento; mesmo assim, criá-lo antes com seu nome deixa claro que é algo que se decidiu ter, e não um efeito colateral.

Os volumes do driver padrão, `local`, vivem em uma pasta da máquina dentro do armazenamento do Docker: a documentação mostra o caminho `/var/lib/docker/volumes/<nome>/_data` ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). Essa pasta é do Docker e do `root`. Pode ser vista com `sudo`, mas não é para ser mexida à mão: para olhar dentro de um volume, o curso usa um **contêiner auxiliar**, um `alpine` descartável que monta o volume como somente leitura e roda `ls` ou `cat`. Funciona igual no Mint, em um Mac ou em um servidor, não precisa de `sudo` e não há como estragar os dados.

Um volume **não é apagado** com o contêiner. Essa é a sua razão de existir. Nem `docker rm`, nem `docker rm -f`, nem `docker stop` o tocam. A única exceção são os volumes **anônimos** (os criados sem nome, por exemplo com `-v /datos` sem origem): a documentação diz que esses são destruídos com o contêiner somente se ele foi criado com `--rm` ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). Um volume nomeado vive até que seja apagado com `docker volume rm`. Por isso o curso sempre lhes dá nome, e com o prefixo `curso-docker-`: um volume anônimo é um identificador de 64 caracteres de que ninguém lembra de quem é, e que acaba ocupando disco para sempre.

### 8.3 O erro: um volume novo sobre uma pasta que a imagem não traz

#### 8.3.1 Provocá-lo

Com o que foi visto, o plano parece óbvio: criar um volume, montá-lo em `/datos`, dizer ao `revisor` que guarde ali seu relatório com `REVISOR_REPORTE=/datos/reporte.json`. O script `fig08_02.sh` faz exatamente isso com a imagem da Lição 7, reforçada como ficou:

```bash
#!/usr/bin/env bash
# fig08_02.sh — El error: un volumen nuevo sobre una carpeta que la imagen NO trae.
# Construye el revisor de la Lección 7 (la 1.4.0, sin /datos), le monta un volumen
# con nombre recién creado en /datos y le pide guardar su reporte ahí.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.4.0,
# tu contenedor curso-docker-revisor ni tu volumen curso-docker-reportes, y al
# salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08-l7"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$NOMBRE-mira" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + el Dockerfile de la Lección 7.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/../07-salud-y-ciclo-de-vida/estado/Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
# Con el prefijo por omisión esto no cambia nada.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. ¿La imagen de la Lección 7 trae una carpeta /datos?"
docker create --name "$NOMBRE-mira" "$IMAGEN" >/dev/null
docker export "$NOMBRE-mira" | tar -tv --numeric-owner | grep -c ' datos/' || true
docker rm "$NOMBRE-mira" >/dev/null

echo
echo "== 2. Un volumen con nombre, nuevo y vacío"
docker volume create "$VOLUMEN" | nombres
docker volume inspect --format 'Driver={{.Driver}} Mountpoint={{.Mountpoint}}' "$VOLUMEN" | nombres

echo
echo "== 3. El revisor de la Lección 7, endurecido, con el volumen en /datos"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -v "$VOLUMEN":/datos -e REVISOR_REPORTE=/datos/reporte.json \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"

echo
echo "== 4. ¿De quién es /datos? Lo mira un contenedor ayudante, de solo lectura"
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
echo "-- y el revisor corre como:"
docker inspect --format '{{.Config.User}}' "$NOMBRE"
```

```text
$ ./fig08_02.sh
== 1. ¿La imagen de la Lección 7 trae una carpeta /datos?
0

== 2. Un volumen con nombre, nuevo y vacío
curso-docker-reportes-fig08
Driver=local Mountpoint=/var/lib/docker/volumes/curso-docker-reportes-fig08/_data

== 3. El revisor de la Lección 7, endurecido, con el volumen en /datos
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
-- /salud no escribe nada, así que sigue contestando:
{"estado":"vivo","version":"1.4.0"}
 [200]

== 4. ¿De quién es /datos? Lo mira un contenedor ayudante, de solo lectura
drwxr-xr-x    2 0        0             4096 Oct 21 09:58 /datos
-- y el revisor corre como:
65532:65532
```

As linhas novas do script, antes de ler a saída. O `docker create` cria um contêiner sem iniciá-lo, e o `docker export` extrai seu sistema de arquivos completo como um arquivo `tar`; o `tar -tv` o lista sem desempacotar, e `--numeric-owner` mostra os donos como números. É a forma de olhar **que pastas uma imagem traz** quando ela não tem *shell* para rodar `ls`. O `docker volume inspect` mostra o que o Docker sabe de um volume. E `-v "$VOLUMEN":/datos:ro` no auxiliar monta o volume como somente leitura: o auxiliar apenas olha.

Agora a saída, bloco por bloco:

1. **A imagem da Lição 7 não traz `/datos`.** A contagem de linhas do `tar` que terminam em ` datos/` é `0`. Ninguém a criou: na Lição 7 o relatório ia para `/tmp`.
2. **O volume é novo e está vazio.** Seu driver é `local` e ele vive em `/var/lib/docker/volumes/curso-docker-reportes-fig08/_data`, o caminho que a documentação indica.
3. **O `revisor` inicia, responde `/salud` e falha ao guardar.** `/api/estados` responde `500` com `permission denied` ao abrir o arquivo temporário do relatório. (Lembre-se, da Lição 3, de que o `revisor` escreve primeiro um arquivo temporário na mesma pasta e depois o renomeia: por isso o erro menciona `.reporte-<n>.tmp` e não `reporte.json`.) `/salud` continua em `200`, porque não escreve nada; e como o `HEALTHCHECK` usa `/salud`, o Docker diria que este contêiner está `healthy`. Rodando, saudável para o Docker, e sem poder fazer seu trabalho: o segundo critério do curso, outra vez.
4. **A pasta é do `root`.** O auxiliar mostra `/datos` com dono `0` e grupo `0`, permissões `drwxr-xr-x`: só o dono escreve. E o `revisor` roda como `65532:65532`.

#### 8.3.2 Por que acontece

Quando se monta um volume em um caminho que a imagem não traz, o Docker precisa criar esse ponto de montagem, e o volume novo nasce com uma pasta raiz que pertence ao `root`. Ninguém disse outra coisa. Enquanto o processo do contêiner foi `root` (como em tantos tutoriais), isso não se notava: o `root` escreve onde quer. Mas o `revisor` deixou de ser `root` na Lição 3, e um usuário sem privilégios não ignora as permissões de ninguém. Então o kernel faz o que faria com qualquer usuário da máquina que tenta escrever em uma pasta alheia: nega.

É o mesmo erro da Lição 6 com o arquivo do token, em outra forma. Lá o arquivo era da pessoa e o processo, `65532`; aqui a pasta é do `root` e o processo, `65532`. A pergunta que resolve é a mesma: **quem é o dono, e com que usuário roda o processo?**

Há três correções que se veem na internet, e só uma é boa:

- **Rodar como `root`** (`--user 0`). Funciona e desfaz o trabalho de cinco lições. Não.
- **Mudar o dono do volume por fora**, com um contêiner auxiliar que rode `chown 65532:65532 /datos` antes de iniciar o `revisor`. Funciona, mas é um passo a mais que alguém tem de lembrar em cada máquina, e um contêiner que roda como `root` só para isso.
- **Fazer a imagem trazer a pasta, com o dono correto.** É a correção desta lição, e funciona por uma regra dos volumes que se explica em 8.4.

### 8.4 A correção: a imagem traz `/datos`, do usuário correto

#### 8.4.1 A regra que a torna possível

A documentação de volumes descreve o que acontece quando se monta um volume **vazio** em uma pasta do contêiner que **já tem** arquivos ou pastas: «esses arquivos ou pastas são propagados (copiados) para o volume» ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)). A documentação fala do conteúdo; o que ela não diz, e será medido em 8.4.3, é que a cópia leva também o dono e as permissões da pasta da imagem. Se a imagem traz `/datos` com dono `65532`, um volume novo montado ali nasce com dono `65532`. A correção, então, não está no `docker run`: está no Dockerfile.

#### 8.4.2 O Dockerfile desta lição

Este é o Dockerfile com que a lição termina. É o da Lição 7 com três mudanças, marcadas abaixo:

```dockerfile
# syntax=docker/dockerfile:1
# fig08_01.Dockerfile — Lección 8: la imagen trae la carpeta /datos, con el dueño
# correcto, para que un volumen nuevo herede ese dueño. Parte de la Lección 7.

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

As três mudanças:

1. **`&& mkdir -p /out/datos` no estágio `binario`.** Cria uma pasta vazia junto ao binário. É criada no estágio de compilação porque a imagem final, *distroless*, não tem *shell* nem `mkdir`: não há com que criar uma pasta ali. Acrescenta-se ao mesmo `RUN` que compila para não somar uma camada a mais a esse estágio; dá no mesmo na imagem final, que só recebe o que é copiado.
2. **`COPY --from=binario --chown=65532:65532 /out/datos /datos` no estágio `final`.** Copia essa pasta vazia para `/datos` e lhe dá dono e grupo `65532`. Segundo a referência do Dockerfile, `--chown` «define o dono dos arquivos copiados», e sem essa opção eles ficam com usuário e grupo `0` ([referência do Dockerfile](https://docs.docker.com/reference/dockerfile/)). Usam-se números e não nomes porque a imagem final não tem por que saber quem é `nonroot`; o número é o que o kernel compara.
3. **`REVISOR_REPORTE=/datos/reporte.json` no `ENV`.** O valor padrão de onde o relatório é guardado. É configuração, não segredo (Lição 6), e vale em qualquer ambiente, porque a pasta vem na imagem. Quem rodar a imagem sem dizer nada guarda em `/datos`, e se montar ali um volume, o relatório dura.

Essa terceira mudança tem uma consequência que convém ver antes que surpreenda. A imagem 1.5.0 **espera** que `/datos` seja gravável. Se for rodada com `--read-only` e **sem** volume, como na Lição 7, `/api/estados` volta a falhar, agora com `read-only file system`. Isso se verá no bloco 6 do `fig08_03.sh`, em 8.4.3.

Não é um defeito: é a imagem dizendo onde guarda. A partir desta lição, o `revisor` reforçado roda com algo gravável montado em `/datos`: quase sempre um volume nomeado, e um *bind mount* quando outra ferramenta da máquina precisa ler os relatórios (8.6). Isso se verá em todos os scripts seguintes, inclusive os de redes, e no `compose.yaml` da Lição 9.

#### 8.4.3 Vê-lo funcionar, e vê-lo sobreviver

O script `fig08_03.sh` constrói a imagem 1.5.0, olha seu `/datos`, monta nela um volume novo e depois apaga o contêiner para ver o que sobra:

```bash
#!/usr/bin/env bash
# fig08_03.sh — El arreglo: la imagen 1.5.0 trae /datos del usuario 65532, y un
# volumen nuevo copia ese dueño. Después, el reporte sobrevive a docker rm, y un
# volumen en uso no se deja borrar.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0,
# tu contenedor curso-docker-revisor ni tu volumen curso-docker-reportes, y al
# salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$NOMBRE-mira" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# Los identificadores de contenedor cambian en cada corrida: se tapan a la vista.
tapar_id() { sed -E 's/[0-9a-f]{64}/<id>/g'; }
revisor() {
  docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
    -v "$VOLUMEN":/datos -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
}

echo "== 1. Construir la 1.5.0 y mirar /datos dentro de la imagen"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null
docker image ls "$IMAGEN" --format 'tamaño: {{.Size}}'
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$IMAGEN" | grep REVISOR
docker create --name "$NOMBRE-mira" "$IMAGEN" >/dev/null
docker export "$NOMBRE-mira" | tar -tv --numeric-owner | grep ' datos/' | awk '{print $1, $2, $NF}'
docker rm "$NOMBRE-mira" >/dev/null

echo
echo "== 2. Un volumen nuevo, montado en /datos: hereda el dueño de la imagen"
docker volume create "$VOLUMEN" >/dev/null
revisor
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -ln /datos

echo
echo "== 3. Un volumen en uso no se deja borrar"
salida=$(docker volume rm "$VOLUMEN" 2>&1) && rc=0 || rc=$?
echo "$salida" | nombres | tapar_id
echo "[código de salida: $rc]"

echo
echo "== 4. Borrar el contenedor: el volumen se queda, y el reporte con él"
docker rm -f "$NOMBRE" >/dev/null
echo "contenedores con ese nombre: $(docker ps -a --filter "name=^${NOMBRE}\$" --format '{{.Names}}' | wc -l)"
docker volume ls --filter "name=^${VOLUMEN}\$" --format 'volumen: {{.Name}} ({{.Driver}})' | nombres
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" cat /datos/reporte.json

echo
echo "== 5. Un contenedor nuevo con el mismo volumen sigue donde iba el otro"
revisor
docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -ln /datos | awk 'NR>1 {print $1, $3, $4, $NF}'
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE" | nombres
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. La 1.5.0 endurecida SIN volumen en /datos: la raíz es de solo lectura"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'
```

```text
$ ./fig08_03.sh
== 1. Construir la 1.5.0 y mirar /datos dentro de la imagen
tamaño: 16.2MB
REVISOR_PUERTO=8080
REVISOR_REPORTE=/datos/reporte.json
drwxr-xr-x 65532/65532 datos/

== 2. Un volumen nuevo, montado en /datos: hereda el dueño de la imagen
/api/estados: [200]
drwxr-xr-x    2 65532    65532         4096 Oct 21 13:10 /datos
total 4
-rw-------    1 65532    65532           92 Oct 21 13:10 reporte.json

== 3. Un volumen en uso no se deja borrar
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
[código de salida: 1]

== 4. Borrar el contenedor: el volumen se queda, y el reporte con él
contenedores con ese nombre: 0
volumen: curso-docker-reportes-fig08 (local)
[
  {
    "servicio": "propio",
    "ok": true,
    "codigo": 200,
    "tiempo_ms": 1
  }
]

== 5. Un contenedor nuevo con el mismo volumen sigue donde iba el otro
-rw------- 65532 65532 reporte.json
/api/estados: [200]
volume curso-docker-reportes-fig08 -> /datos (escribible: true)

== 6. La 1.5.0 endurecida SIN volumen en /datos: la raíz es de solo lectura
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Bloco por bloco:

1. **A imagem pesa 16.2 MB**; a 1.4.0 da Lição 7 media 16.1 MB. Uma pasta vazia quase não pesa: a diferença é de arredondamento. Seu ambiente traz os dois valores padrão, `REVISOR_PUERTO=8080` e `REVISOR_REPORTE=/datos/reporte.json`. E o `tar` de seu sistema de arquivos já mostra `datos/` com dono `65532/65532`.
2. **O volume novo herdou o dono.** `/api/estados` responde `200`. O auxiliar mostra `/datos` com dono `65532`, não `0`: é a cópia de 8.4.1. Dentro está `reporte.json`, de `65532`, com permissões `-rw-------`: só seu dono o lê e o escreve. (Esse `600` é decidido pelo `revisor`: ele cria o arquivo temporário com a função `os.CreateTemp` do Go, que usa essas permissões, e depois o renomeia. O auxiliar consegue lê-lo porque roda como `root`.) O número de bytes depende de quantos serviços ele verifica.
3. **Um volume em uso não se deixa apagar.** `docker volume rm` sai com código `1` e diz quem o está usando: `volume is in use`, com o identificador do contêiner entre colchetes. É uma proteção: não se pode tirar o chão de um contêiner que está escrevendo.
4. **O contêiner vai embora; o volume e o relatório ficam.** Depois do `docker rm -f`, não há nenhum contêiner com esse nome, o volume continua na lista e o auxiliar lê o relatório completo: um serviço, `propio`, saudável, com código `200` (o tempo muda a cada execução). Isto é o que faltava na manhã de segunda-feira.
5. **Um contêiner novo retoma o volume.** O `revisor` nasce de novo, encontra o relatório anterior em seu lugar, o substitui com a verificação seguinte (`200`) e o `docker inspect` mostra a montagem: `volume curso-docker-reportes-fig08 -> /datos (escribible: true)`. O sistema de arquivos do contêiner continua sendo somente leitura; `/datos` é a única exceção, e tem nome.
6. **Sem o volume, a 1.5.0 reforçada não consegue guardar.** É a consequência de 8.4.2: `read-only file system` e `500`. A imagem já diz onde guarda; quem a roda com `--read-only` tem de dar a ela esse lugar.

#### 8.4.4 Na pasta do projeto

O projeto vive em `~/curso-docker/revisor` desde a Lição 3. A partir da raiz do repositório do curso, coloque ali o Dockerfile desta lição, construa a imagem que será conservada e crie o volume:

```bash
cp programas/08-volumenes-y-redes/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.5.0 -t curso-docker-revisor:1.5.0 .
docker volume create curso-docker-reportes
```

O `.dockerignore` e a pasta `secretos/` não mudam. Antes de seguir, repita à mão o erro e a correção com nomes próprios: rode `curso-docker-revisor:1.4.0` com um volume recém-criado em `/datos` e `-e REVISOR_REPORTE=/datos/reporte.json`, e veja o `500`; apague-o junto com esse volume; e rode `curso-docker-revisor:1.5.0` com `curso-docker-reportes`. A única coisa que muda em relação aos scripts são os nomes. Os scripts desta lição não tocam em nada disso: usam nomes de apoio com `fig08` e apagam só o que é deles.

### 8.5 Copiar versus cobrir: o que já havia na pasta

#### 8.5.1 Quatro casos que convém não confundir

A regra de 8.4.1 tem condições, e quase todos os sustos com montagens vêm de esquecê-las. Quando se monta algo sobre uma pasta do contêiner que já tem conteúdo, acontece uma destas coisas:

| O que se monta | O que o contêiner vê | O que acontece com o conteúdo da imagem |
|---|---|---|
| um volume **novo e vazio** | o conteúdo da imagem | é **copiado** para o volume, com donos e permissões |
| um volume novo com `volume-nocopy` | uma pasta vazia | não é copiado; fica coberto |
| um volume **que já tem dados** | o que há no volume | fica **coberto**; nada é copiado |
| um ***bind mount*** | o que há na pasta da máquina | fica **coberto**; nada é copiado |

«Coberto» é a palavra da documentação: se se monta um volume com dados onde já havia arquivos, «os arquivos prévios ficam ocultos pela montagem» ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)); com um *bind mount*, «o conteúdo existente da pasta fica oculto» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). Não são apagados: continuam na camada da imagem, embaixo, e reaparecem se um contêiner for rodado sem a montagem. Mas enquanto a montagem existir, o contêiner não os vê.

Observe a terceira linha, porque ela tem uma consequência prática: a cópia ocorre **somente na primeira vez**, quando o volume está vazio. Se o volume `curso-docker-reportes` foi criado com a imagem 1.5.0 e amanhã uma imagem 1.6.0 traz algo diferente em `/datos`, o volume não é atualizado: ele já tem dados, então vale o volume. Para um relatório isso é exatamente o que se quer (os dados do serviço não devem mudar porque a imagem mudou). Para quem guarda em um volume arquivos que deveriam vir da imagem, é uma fonte clássica de «atualizei e continua igual».

#### 8.5.2 Vê-lo com um contêiner auxiliar

O script `fig08_04.sh` mostra os quatro casos com o `alpine` auxiliar, sobre sua pasta `/etc/apk`, que traz cinco entradas. No final testa a diferença entre `-v` e `--mount` com uma pasta da máquina que não existe:

```bash
#!/usr/bin/env bash
# fig08_04.sh — Copiar contra tapar. Un volumen NUEVO montado sobre una carpeta
# con contenido recibe una copia de ese contenido; un bind mount, en cambio, la
# tapa. Y la diferencia entre -v y --mount cuando la carpeta del equipo no existe.
# No construye nada: usa el contenedor ayudante alpine:3.24.2.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus volúmenes del curso, y al
# salir borra solo lo que creó.
TRABAJO="$(mktemp -d)"
VOLUMEN="${PREFIJO}copia-fig08"
VOLUMEN_SIN_COPIA="${PREFIJO}sin-copia-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker volume rm "$VOLUMEN" "$VOLUMEN_SIN_COPIA" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT
cd "$TRABAJO"
# La ruta de la carpeta temporal cambia en cada corrida: se escribe como «.».
tapar_ruta() { sed "s#$TRABAJO#.#g"; }

echo "== 1. La carpeta /etc/apk de la imagen, sin montar nada"
docker run --rm "$AYUDANTE" ls /etc/apk

echo
echo "== 2. Un volumen NUEVO montado ahí: el contenedor ve lo mismo..."
docker run --rm -v "$VOLUMEN":/etc/apk "$AYUDANTE" ls /etc/apk
echo "-- ...porque Docker copió el contenido al volumen. Míralo montado en otra ruta:"
docker run --rm -v "$VOLUMEN":/mirar:ro "$AYUDANTE" ls /mirar

echo
echo "== 3. Lo mismo con volume-nocopy: el volumen se queda vacío"
docker run --rm --mount type=volume,src="$VOLUMEN_SIN_COPIA",dst=/etc/apk,volume-nocopy \
  "$AYUDANTE" ls /etc/apk | wc -l

echo
echo "== 4. Un bind mount de una carpeta vacía del equipo: tapa lo de la imagen"
mkdir vacia
docker run --rm --mount type=bind,src="$TRABAJO/vacia",dst=/etc/apk "$AYUDANTE" ls /etc/apk | wc -l
echo "-- y en el equipo, la carpeta sigue vacía: no se copió nada en ningún sentido"
ls vacia | wc -l

echo
echo "== 5. -v con una carpeta del equipo que NO existe: Docker la crea... como root"
docker run --rm -v "$TRABAJO/no-existia":/datos "$AYUDANTE" true
stat -c '%U:%G %n' no-existia

echo
echo "== 6. --mount con una carpeta que no existe: se niega"
docker run --rm --mount type=bind,src="$TRABAJO/tampoco-existe",dst=/datos "$AYUDANTE" true 2>&1 | tapar_ruta
echo "[código de salida: ${PIPESTATUS[0]}]"
```

```text
$ ./fig08_04.sh
== 1. La carpeta /etc/apk de la imagen, sin montar nada
arch
keys
protected_paths.d
repositories
world

== 2. Un volumen NUEVO montado ahí: el contenedor ve lo mismo...
arch
keys
protected_paths.d
repositories
world
-- ...porque Docker copió el contenido al volumen. Míralo montado en otra ruta:
arch
keys
protected_paths.d
repositories
world

== 3. Lo mismo con volume-nocopy: el volumen se queda vacío
0

== 4. Un bind mount de una carpeta vacía del equipo: tapa lo de la imagen
0
-- y en el equipo, la carpeta sigue vacía: no se copió nada en ningún sentido
0

== 5. -v con una carpeta del equipo que NO existe: Docker la crea... como root
root:root no-existia

== 6. --mount con una carpeta que no existe: se niega
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe

Run 'docker run --help' for more information
[código de salida: 125]
```

Bloco por bloco:

1. **Sem montagem**, `/etc/apk` tem cinco entradas: `arch`, `keys`, `protected_paths.d`, `repositories` e `world`.
2. **Com um volume novo**, o contêiner vê as mesmas cinco. E não é que veja as da imagem «através» do volume: montado em outro caminho (`/mirar`), em um contêiner distinto, o volume as tem. O Docker as copiou ao montá-lo pela primeira vez.
3. **Com `volume-nocopy`**, zero entradas. A opção diz ao Docker que não copie mesmo que o volume esteja vazio ([Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/)); com `-v` também existe, mas se escreve `nocopy` (8.1.3). Se algum dia ela aparecer em um `docker run` do `revisor`, já se sabe o que vai acontecer: o volume nasce com sua pasta de `root`, como em 8.3, e volta o `permission denied`. Isso será comprovado no Exercício 4.
4. **Com um *bind mount* de uma pasta vazia**, zero entradas: o da imagem ficou coberto. E a pasta da máquina continua vazia: um *bind mount* não copia nada em nenhum sentido. O contêiner vê **a pasta da máquina**, tal como está, e nada mais.
5. **`-v` com um caminho da máquina que não existe**: o contêiner inicia sem reclamar, e na máquina aparece a pasta `no-existia`... com dono `root:root`. Foi criada pelo daemon, que roda como `root`. A documentação diz assim: com `-v`, «o Docker cria a pasta no host para quem a pediu» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). O que ela não diz tão alto é o dono, e é o que morde: um erro de digitação no caminho deixa uma pasta de `root` no projeto, um contêiner escrevendo no lugar errado e, se o processo não é `root`, outro `permission denied`.
6. **`--mount` com um caminho que não existe**: recusa. `invalid mount config for type "bind": bind source path does not exist`, com código `125`, o que o `docker run` usa quando o erro é do próprio Docker e não do programa. É o comportamento desejado: um erro de digitação aparece na hora. (O caminho aparece como `./tampoco-existe` porque o script oculta a pasta temporária, que muda a cada execução.) É o comportamento padrão: `--mount` também pode criar a pasta se isso for pedido com a opção `bind-create-src`, que segundo a documentação «cria automaticamente a pasta de origem no host se ela não existir» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). Este curso não a usa, porque o que se busca é justamente que o erro de digitação seja visto. Por isso usa `--mount` para os *bind mounts*.

### 8.6 *Bind mounts* e o dono dos arquivos

#### 8.6.1 Quando um *bind mount* e não um volume

Um *bind mount* serve quando, a partir da própria máquina, é preciso ver ou colocar os arquivos sem passar pelo Docker: o código de um programa enquanto é desenvolvido, um arquivo de configuração editado à mão, o token da Lição 6, ou um relatório que outra ferramenta da máquina vai recolher. O preço é que o contêiner escreve **diretamente no sistema de arquivos da máquina**. A documentação avisa: com um *bind mount* «é possível mudar o sistema de arquivos do host a partir de processos que rodam em um contêiner», e os *bind mounts* têm, por padrão, «acesso de escrita aos arquivos do host» ([Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/)). Por isso, quando o contêiner só precisa ler, a montagem vai com `readonly`, como o token.

#### 8.6.2 O mesmo erro, pelo lado contrário

Com um volume, a pasta era de `root` e a correção foi fazer a imagem trazer a sua. Com um *bind mount* isso não serve: o contêiner vê a pasta **da máquina**, com o dono **dela**, e o que a imagem traga em `/datos` fica coberto (8.5). Então o choque volta, agora entre o usuário da máquina e o `65532`. O script `fig08_05.sh` o provoca e o corrige sem `root`:

```bash
#!/usr/bin/env bash
# fig08_05.sh — Bind mount: la carpeta es tuya, el proceso es 65532. Primero el
# error de permisos; después el arreglo sin root (correr con TU usuario); y al
# final el mismo montaje de solo lectura.
# Córrelo en el disco propio de Linux: una carpeta compartida con otro sistema
# miente con los dueños y los permisos.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
SERVICIOS='propio http://127.0.0.1:8080/salud'
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. Una carpeta tuya en el equipo"
mkdir reportes
stat -c '%u:%g %a %n' reportes
echo "tu usuario: $(id -u):$(id -g)"

echo
echo "== 2. Montada en /datos con un bind mount; el revisor corre como 65532"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. El arreglo sin root: correr el contenedor con TU usuario"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '/api/estados: [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
echo "-- el reporte, visto desde el equipo, sin docker ni sudo:"
stat -c '%u:%g %a %n' reportes/reporte.json
head -c 60 reportes/reporte.json | tr -d '\n '; echo " …"
echo "-- lo que anotó Docker:"
docker inspect --format 'User={{.Config.User}}{{range .Mounts}} | {{.Type}} -> {{.Destination}} (escribible: {{.RW}}){{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 4. El mismo bind mount, de solo lectura"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  --user "$(id -u):$(id -g)" \
  --mount type=bind,src="$TRABAJO/reportes",dst=/datos,readonly \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
```

```text
$ ./fig08_05.sh
== 1. Una carpeta tuya en el equipo
501:1000 775 reportes
tu usuario: 501:1000

== 2. Montada en /datos con un bind mount; el revisor corre como 65532
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]

== 3. El arreglo sin root: correr el contenedor con TU usuario
/api/estados: [200]
-- el reporte, visto desde el equipo, sin docker ni sudo:
501:1000 600 reportes/reporte.json
[{"servicio":"propio","ok":true,"codigo" …
-- lo que anotó Docker:
User=501:1000 | bind -> /datos (escribible: true)

== 4. El mismo bind mount, de solo lectura
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Bloco por bloco:

1. **A pasta é do usuário da máquina**: dono `501:1000`, permissões `775` (o usuário e seu grupo escrevem; os demais, não). No Mint dirá `1000:1000`. O script imprime o usuário para que seja comparado.
2. **Montada em `/datos`, `permission denied`.** O `revisor` roda como `65532`, que não é o dono nem está no grupo `1000`, e para «os demais» a pasta não é gravável. A montagem não traduz nada: dentro do contêiner a pasta tem o mesmo dono numérico que fora. (Com Docker sem `root` ou com remapeamento de usuários, o número de dentro é traduzido para outro fora; a instalação da Lição 1 não faz isso.)
3. **A correção: rodar o contêiner com o usuário da máquina.** `--user "$(id -u):$(id -g)"` substitui o `65532` da imagem pelos números da pessoa, e agora o processo é o dono da pasta: `200`. E o relatório, visto da máquina, é dela (`501:1000`, `600`): lê-se sem `docker` e sem `sudo`. Repare no que **não** mudou: o processo continua sem ser `root`, continua sem capabilities e o sistema de arquivos continua somente leitura. Trocou-se um usuário sem privilégios por outro usuário sem privilégios, o da pessoa. Atenção: se o comando for executado com `sudo`, `$(id -u)` vale `0` e o contêiner estaria rodando como `root` sem que se percebesse. Por isso na Lição 1 entrou-se no grupo `docker`: esses comandos vão sem `sudo`. O `docker inspect` confirma: `User=501:1000`, e a montagem `bind -> /datos (escribible: true)`.
4. **Como somente leitura, o kernel recusa.** Com `readonly`, o `revisor` volta a falhar, agora com `read-only file system`: nem sendo o dono ele consegue escrever. Para o relatório não faz sentido, mas é exatamente o que se quer para um arquivo de configuração ou um segredo: o contêiner o lê e não consegue mudá-lo.

Por que não `chmod 777` na pasta? Porque isso deixa **qualquer usuário da máquina** escrever ali, e qualquer contêiner com qualquer usuário enchê-la. É a versão em pasta do `644` da Lição 6, mas pior, porque aqui se escreve, não só se lê. `--user` com os números da pessoa resolve o problema onde ele nasce: o dono.

### 8.7 `tmpfs`: o que não deve durar

#### 8.7.1 Para quê

Na Lição 7 usou-se `--tmpfs /tmp` para que o `revisor` pudesse escrever seu relatório com o sistema de arquivos somente leitura. Funcionou, e o relatório morria com o contêiner. Agora o relatório tem seu volume, mas o `tmpfs` continua tendo um lugar: tudo o que um programa escreve e **não** deve sobreviver. Arquivos temporários, caches de uma única execução, um arquivo com um segredo decifrado que não deve tocar o disco. A documentação resume: diferentemente de volumes e *bind mounts*, um `tmpfs` «é temporário e só persiste na memória do host», e «quando o contêiner para, a montagem `tmpfs` é removida» ([Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/)). Também não pode ser compartilhado entre contêineres.

Dois valores padrão dessa página que convém saber: sem tamanho, o teto de um `tmpfs` é **a metade da memória da máquina**, e sua permissão é `1777`, gravável por qualquer um (com o bit que impede apagar arquivos alheios, o mesmo do `/tmp` no Mint). E um aviso honesto: o kernel pode mandar para a memória de troca (*swap*) o que há em um `tmpfs`, então «em memória» não é garantia de que nunca toque o disco.

#### 8.7.2 Volume e `tmpfs`, lado a lado

O script `fig08_06.sh` roda um contêiner somente leitura com as duas montagens, escreve em ambas, o reinicia e olha o que sobreviveu:

```bash
#!/usr/bin/env bash
# fig08_06.sh — tmpfs contra volumen. Un contenedor de solo lectura con dos
# lugares escribibles: un volumen en /datos y un tmpfs de 1 MB en /cache. Escribe
# en los dos, se reinicia, y se ve qué sobrevivió. También el tope del tmpfs.
# No construye nada: usa el contenedor ayudante alpine:3.24.2.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores ni tus
# volúmenes del curso, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}ayudante-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true' EXIT
# en COMANDO: corre COMANDO con sh dentro del contenedor y avisa si falló
en() { docker exec "$NOMBRE" sh -c "$1" 2>&1 || echo "[código de salida: $?]"; }

echo "== 1. Solo lectura, con un volumen en /datos y un tmpfs en /cache"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --mount type=volume,src="$VOLUMEN",dst=/datos \
  --mount type=tmpfs,dst=/cache,tmpfs-size=1m \
  "$AYUDANTE" sleep 300 >/dev/null
echo "-- dónde está montado cada uno, de qué tipo y con qué opciones:"
en 'awk "\$2 == \"/datos\" || \$2 == \"/cache\" {print \$2, \$3, \$4}" /proc/mounts'
en 'stat -c "%a %n" /cache'

echo
echo "== 2. Escribir en los dos, y en la raíz"
en 'echo reporte > /datos/a.txt && echo temporal > /cache/b.txt && ls /datos /cache'
en 'echo hola > /c.txt'

echo
echo "== 3. El tmpfs tiene tope: 2 MB no caben en 1 MB"
en 'dd if=/dev/zero of=/cache/grande bs=1k count=2000 2>&1 | head -1'
en 'rm -f /cache/grande'

echo
echo "== 4. Reiniciar el contenedor"
docker restart -t 2 "$NOMBRE" >/dev/null
en 'ls /datos; echo "-- /cache tiene $(ls /cache | wc -l) archivos"'
```

```text
$ ./fig08_06.sh
== 1. Solo lectura, con un volumen en /datos y un tmpfs en /cache
-- dónde está montado cada uno, de qué tipo y con qué opciones:
/cache tmpfs rw,nosuid,nodev,noexec,relatime,size=1024k,inode64
/datos ext4 rw,relatime,discard,errors=remount-ro,commit=30
1777 /cache

== 2. Escribir en los dos, y en la raíz
/cache:
b.txt

/datos:
a.txt
sh: can't create /c.txt: Read-only file system
[código de salida: 1]

== 3. El tmpfs tiene tope: 2 MB no caben en 1 MB
dd: error writing '/cache/grande': No space left on device

== 4. Reiniciar el contenedor
a.txt
-- /cache tiene 0 archivos
```

1. **As duas montagens e suas opções**, lidas de `/proc/mounts`, a lista que o kernel mantém. `/datos` é `ext4`: o volume vive no disco da máquina. `/cache` é `tmpfs`, com `size=1024k` (o `1m` pedido) e três opções que o Docker pôs por conta própria ao montá-lo com `--mount`: `nosuid`, `nodev` e `noexec`. Na Lição 7 elas foram escritas à mão com `--tmpfs`; com `--mount type=tmpfs` vêm sozinhas. A permissão é `1777`.
2. **Escreve-se nas duas e não na raiz.** `a.txt` no volume, `b.txt` no `tmpfs`; e `/c.txt` falha com `Read-only file system`, porque fora das montagens tudo é somente leitura. Três pastas, três comportamentos, e cada um foi pedido pelo nome.
3. **O `tmpfs` tem teto.** Escrever 2 MB em um `tmpfs` de 1 MB termina em `No space left on device`. Sem `size`, esse teto seria a metade da memória da máquina: um programa com um erro que escreve sem parar poderia ocupar muito mais do que se imaginava. Com o teto, o erro aparece na hora e com uma mensagem clara.
4. **Depois do `docker restart`, o volume conserva `a.txt` e o `tmpfs` está vazio.** Um reinício basta para esvaziar o `tmpfs`; não é preciso apagar o contêiner.

A documentação prefere `--mount type=tmpfs` e reconhece que `--tmpfs` «é menos verboso» e admite mais opções de montagem ([Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/)). As duas servem. O importante é definir o tamanho.

#### 8.7.3 Qual usar, no `revisor`

| Dado | Montagem | Por quê |
|---|---|---|
| o relatório (`/datos/reporte.json`) | volume nomeado em `/datos` | precisa sobreviver ao contêiner; ninguém precisa editá-lo à mão |
| o token (`/run/secrets/revisor_token`) | *bind mount* de um arquivo, `readonly` | é colocado de fora; o contêiner só o lê |
| um temporário que o programa não deva conservar | `tmpfs` com tamanho | deve morrer com o contêiner e não ocupar disco |
| o código do programa | nenhuma: vai na imagem | é código, não dados (Lição 6) |

### 8.8 Redes: a rede padrão não tem nomes

#### 8.8.1 O que é uma rede do Docker

Cada contêiner tem sua própria pilha de rede: suas interfaces, seu endereço IP, sua tabela de rotas, seu `127.0.0.1`. É um dos isolamentos da Lição 0. Para que os contêineres se falem, o Docker os conecta a **redes**: por baixo, no Linux, uma ponte virtual (*bridge*) à qual se conecta uma interface de cada contêiner, como cabos em um mesmo switch. O driver padrão se chama justamente `bridge`.

O Docker cria três redes ao ser instalado, `bridge`, `host` e `none` (vistas com `docker network ls`), e se nada mais for dito, todo contêiner se conecta à `bridge`. Ali esteve cada contêiner do curso até hoje. Essa rede tem uma limitação que a documentação diz sem enfeites: na rede padrão, os contêineres «só podem ser alcançados por endereço IP». Mais ainda: «a rede `bridge` padrão é considerada um detalhe legado do Docker e não é recomendada para produção» ([Docker, driver `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)).

#### 8.8.2 Vê-lo: por nome não, por IP sim

O script `fig08_07.sh` coloca o `revisor` e o serviço de teste na rede padrão, e pede ao `revisor` que verifique `http://curso-docker-prueba-fig08:9000/`. Depois faz o mesmo em uma rede definida pelo usuário, e no final derruba o serviço de teste a partir de outro contêiner:

```bash
#!/usr/bin/env bash
# fig08_07.sh — Redes. En la red por omisión, el revisor no encuentra al servicio
# de prueba por su nombre (por IP sí). En una red definida por el usuario, sí lo
# encuentra, porque ahí hay un DNS. Y al romper el servicio, el reporte lo ve.
# Usa tu imagen curso-docker-prueba:1.0.0 (de la Lección 2) sin modificarla.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores, tus redes
# ni tus imágenes del curso, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
PRUEBA="${PREFIJO}prueba-fig08"
RED="${PREFIJO}red-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
IMAGEN_PRUEBA=curso-docker-prueba:1.0.0
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null 2>&1 || true
      docker network rm "$RED" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

docker image inspect "$IMAGEN_PRUEBA" >/dev/null 2>&1 \
  || { echo "falta $IMAGEN_PRUEBA: constrúyela como en la Lección 2"; exit 1; }
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
# Si corres el guion con otro PREFIJO, sus nombres se escriben como los del curso.
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
# Lo que depende de cada equipo se tapa a la vista: los tiempos de la tabla, la
# dirección del DNS del anfitrión y las direcciones IP de los contenedores.
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" \
    | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /; s/on [0-9.]+:53/on <DNS del anfitrión>:53/' | nombres
}
tapar_ip() { sed -E 's/(^|[^0-9])(10|172|192)\.[0-9]+\.[0-9]+\.[0-9]+/\1<IP>/g'; }
revisor() {  # revisor [opciones de red]
  docker run -d --name "$NOMBRE" "$@" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO -v "$VOLUMEN":/datos \
    -e REVISOR_SERVICIOS="prueba http://$PRUEBA:9000/ 2s" "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
}

echo "== 1. Los dos en la red por omisión (bridge): por nombre, no"
docker run -d --name "$PRUEBA" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
revisor
tabla
echo "-- la red de cada uno:"
docker inspect --format '{{.Name}}: {{range $red, $v := .NetworkSettings.Networks}}{{$red}}{{end}}' "$NOMBRE" "$PRUEBA" | nombres
echo "-- el DNS que reciben los contenedores de esa red es el del anfitrión:"
docker run --rm "$AYUDANTE" grep nameserver /etc/resolv.conf | sed -E 's/[0-9.]+$/<DNS del anfitrión>/' | head -1
echo "-- por IP, en cambio, sí llega:"
IP=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PRUEBA")
echo "IP del servicio de prueba: $IP" | tapar_ip
docker run --rm "$AYUDANTE" wget -qO- "http://$IP:9000/"
docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null

echo
echo "== 2. Una red definida por el usuario"
docker network create "$RED" >/dev/null
docker network inspect --format '{{.Name}} driver={{.Driver}} interna={{.Internal}}' "$RED" | nombres
docker run -d --name "$PRUEBA" --network "$RED" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
revisor --network "$RED"
tabla
echo "-- en esta red, el DNS es el que Docker pone dentro de cada contenedor:"
docker run --rm --network "$RED" "$AYUDANTE" grep nameserver /etc/resolv.conf
docker run --rm --network "$RED" "$AYUDANTE" nslookup "$PRUEBA" 2>&1 \
  | grep -E '^(Server|Name|Address)' | nombres | tapar_ip
echo "-- quién está conectado a la red:"
docker network inspect --format '{{range .Containers}}{{.Name}}{{println}}{{end}}' "$RED" | sed '/^$/d' | sort | nombres

echo
echo "== 3. Romper el servicio de prueba desde otro contenedor de la misma red"
docker run --rm --network "$RED" "$AYUDANTE" wget -qO- --post-data= "http://$PRUEBA:9000/modo/caido"
tabla
```

```text
$ ./fig08_07.sh
== 1. Los dos en la red por omisión (bridge): por nombre, no
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
-- la red de cada uno:
/curso-docker-revisor-fig08: bridge
/curso-docker-prueba-fig08: bridge
-- el DNS que reciben los contenedores de esa red es el del anfitrión:
nameserver <DNS del anfitrión>
-- por IP, en cambio, sí llega:
IP del servicio de prueba: <IP>
sano

== 2. Una red definida por el usuario
curso-docker-red-fig08 driver=bridge interna=false
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
-- en esta red, el DNS es el que Docker pone dentro de cada contenedor:
nameserver 127.0.0.11
Server:		127.0.0.11
Address:	127.0.0.11:53
Name:	curso-docker-prueba-fig08
Address: <IP>
-- quién está conectado a la red:
curso-docker-prueba-fig08
curso-docker-revisor-fig08

== 3. Romper el servicio de prueba desde otro contenedor de la misma red
modo: caido
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA         <t>  codigo 503
```

A primeira metade da saída, a rede padrão:

1. **`FALLA`, com `no such host`.** A mensagem completa se lê da direita para a esquerda: `no such host` (o nome não existe), `lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53` (perguntou ao servidor DNS da máquina, na porta 53, a do DNS), `dial tcp` (queria abrir uma conexão) e `Get "http://…"` (para fazer esta requisição). O servidor DNS da máquina não faz ideia de que contêineres rodam no Docker, então responde a única coisa que pode: esse nome não existe. O endereço real desse servidor depende de cada rede, e o script o oculta.
2. **Os dois estão na mesma rede**, `bridge`. Não é que estejam separados: estão juntos e mesmo assim não se encontram pelo nome.
3. **O DNS que recebem é o do host.** A documentação explica que os contêineres da rede padrão recebem uma cópia do `/etc/resolv.conf` da máquina ([Docker, «Networking»](https://docs.docker.com/engine/network/)). O auxiliar o mostra: `nameserver <DNS del anfitrión>`. Um detalhe para o Mint: se no `/etc/resolv.conf` da máquina aparece `nameserver 127.0.0.53` (o resolvedor local do *systemd*, o normal no Mint e no Ubuntu), esse endereço dentro do contêiner apontaria para o próprio contêiner, onde não há nenhum DNS, então o Docker não o copia como está; o contêiner recebe outros servidores. A documentação de «Networking» não detalha essa conversão; para saber o que o contêiner recebeu, compara-se com o auxiliar, que serve justamente para isso.
4. **Por IP, chega.** O script pergunta ao Docker o endereço do serviço de teste (ocultado como `<IP>`) e o auxiliar faz uma requisição direta: `sano`. A rede funciona; o que falta são os nomes. E um IP não serve para configurar o `revisor`, porque é distribuído pelo Docker ao iniciar e pode mudar no seguinte.

Nos tutoriais antigos aparece a solução de antes para isso, `--link`. A seção 8.12 explica por que ela já não vale.

### 8.9 Redes definidas pelo usuário: nomes de graça

#### 8.9.1 O que muda

Uma rede criada com `docker network create` (também com o driver `bridge`) se comporta de outro modo. A documentação lista as diferenças ([Docker, driver `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)):

- **DNS automático**: «as redes *bridge* definidas pelo usuário oferecem resolução DNS automática entre contêineres». Cada contêiner é encontrado pelo nome.
- **Melhor isolamento**: só os contêineres conectados a essa rede se falam entre si. Na rede padrão, em compensação, qualquer contêiner que alguém inicie sem pensar fica ao lado dos demais.
- **Conectar e desconectar com o contêiner em execução**: um contêiner pode ser conectado a uma rede definida pelo usuário, ou desconectado, «na hora», sem ser recriado. Isso será feito em 8.10.

O DNS é fornecido por um servidor que o Docker coloca **dentro** de cada contêiner dessas redes, no endereço `127.0.0.11`. A documentação o chama de servidor DNS integrado, e explica que ele responde os nomes dos contêineres da rede e reenvia todo o resto aos servidores DNS da máquina ([Docker, «Networking»](https://docs.docker.com/engine/network/)). Por isso um contêiner em uma rede própria resolve tanto `curso-docker-prueba` quanto `www.docker.com`.

#### 8.9.2 Ler a segunda metade da execução

De volta à saída do `fig08_07.sh`, bloco 2:

1. **A rede**: `curso-docker-red-fig08`, driver `bridge`, `interna=false` (tem saída; em 8.10 será criada uma que não tem).
2. **`OK`, `200`.** O mesmo `revisor`, com a mesma configuração, encontra o serviço de teste pelo nome. Não se mudou uma letra de `REVISOR_SERVICIOS`: mudou-se a rede.
3. **O DNS agora é `127.0.0.11`.** O auxiliar, conectado à mesma rede, o mostra em seu `/etc/resolv.conf`, e o `nslookup` pergunta pelo nome do serviço de teste: o servidor `127.0.0.11` responde com seu endereço (ocultado).
4. **Quem está conectado**: os dois contêineres, e mais ninguém. O auxiliar não aparece porque já terminou (`--rm`).

E o bloco 3, o que justifica o curso inteiro: um contêiner da mesma rede faz `POST /modo/caido` no serviço de teste (`modo: caido`), e a verificação seguinte do `revisor` diz `FALLA`, `codigo 503`. O serviço de teste continua rodando; o `revisor`, que o verifica pelo nome através da rede, distingue o que o Docker acredita (o contêiner está no ar) do que acontece (responde `503`). (A coluna `TIEMPO` da última linha sai com um espaço a mais porque o script oculta um tempo de largura distinta; é a tabela, não um erro.)

Uma nota sobre o nome: o `revisor` busca `curso-docker-prueba-fig08` porque é assim que se chama o contêiner do script. Na pasta do projeto o contêiner se chama `curso-docker-prueba`, e `REVISOR_SERVICIOS` diz `prueba http://curso-docker-prueba:9000/ 2s`. O nome do contêiner **é** seu nome na rede; se for mudado, muda-se seu endereço.

### 8.10 Redes internas: sem saída

#### 8.10.1 Por que trancar o serviço de teste

O serviço de teste só existe para que o `revisor` o consulte. Não precisa baixar nada, não precisa chamar ninguém, não precisa de internet. E tudo o que um contêiner pode alcançar é algo que um atacante que o controle também pode alcançar: baixar uma ferramenta, mandar dados para fora, usá-lo de trampolim. A resposta é uma **rede interna**: `docker network create --internal`. A referência do `docker network create` a descreve em uma frase, «restringe o acesso externo à rede», e a explica assim: os contêineres de uma rede interna «podem se comunicar entre si, mas não com nenhuma outra rede, porque não se configura uma rota padrão e se aplicam regras de firewall que descartam todo o tráfego de ou para outras redes» ([referência do `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/)).

O desenho é o que a própria documentação usa de exemplo: uma rede interna «para se comunicar com contêineres que rodam serviços internos que não precisam de acesso à rede externa» ([Docker, «Networking»](https://docs.docker.com/engine/network/)). O serviço de teste, **apenas** na interna. O `revisor`, na rede normal (por onde expõe sua porta para o `127.0.0.1` da máquina) **e** na interna (por onde verifica o serviço de teste). Um contêiner pode estar em várias redes ao mesmo tempo: tem uma interface em cada uma.

#### 8.10.2 Vê-lo

O script `fig08_08.sh` monta esse estado, que é o estado final da lição, em dois passos, para que se veja o que cada rede traz:

```bash
#!/usr/bin/env bash
# fig08_08.sh — Red interna. El servicio de prueba vive SOLO en una red interna,
# sin salida a internet. El revisor vive en la red normal (por donde expone
# su puerto) y se conecta además a la interna. Es el estado final de la lección.
# Usa tu imagen curso-docker-prueba:1.0.0 (de la Lección 2) sin modificarla.
set -uo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tus contenedores, tus redes,
# tus volúmenes ni tus imágenes del curso, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
PRUEBA="${PREFIJO}prueba-fig08"
RED="${PREFIJO}red-fig08"
INTERNA="${PREFIJO}interna-fig08"
VOLUMEN="${PREFIJO}reportes-fig08"
IMAGEN_PRUEBA=curso-docker-prueba:1.0.0
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" "$PRUEBA" >/dev/null 2>&1 || true
      docker network rm "$RED" "$INTERNA" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

docker image inspect "$IMAGEN_PRUEBA" >/dev/null 2>&1 \
  || { echo "falta $IMAGEN_PRUEBA: constrúyela como en la Lección 2"; exit 1; }
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null || exit 1

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
nombres() { sed "s/${PREFIJO}/curso-docker-/g"; }
tabla() {
  curl -s "http://127.0.0.1:$PUERTO/api/estados?formato=tabla" \
    | sed -E 's/ [0-9.]+(ms|µs|s) / <t> /' | nombres
}

echo "== 1. Dos redes: la normal y la interna"
docker network create "$RED" >/dev/null
docker network create --internal "$INTERNA" >/dev/null
docker network inspect --format '{{.Name}} driver={{.Driver}} interna={{.Internal}}' "$RED" "$INTERNA" | nombres

echo
echo "== 2. El servicio de prueba, solo en la interna; el revisor, solo en la normal"
docker run -d --name "$PRUEBA" --network "$INTERNA" $ENDURECIDO "$IMAGEN_PRUEBA" >/dev/null
docker run -d --name "$NOMBRE" --network "$RED" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO \
  -v "$VOLUMEN":/datos -e REVISOR_SERVICIOS="prueba http://$PRUEBA:9000/ 2s" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
tabla

echo
echo "== 3. Conectar el revisor también a la interna, sin reiniciarlo"
docker network connect "$INTERNA" "$NOMBRE"
tabla
docker inspect --format '{{range $red, $v := .NetworkSettings.Networks}}{{$red}} {{end}}' "$NOMBRE" | nombres
echo "-- el puerto publicado sigue en 127.0.0.1:"
docker port "$NOMBRE" | sed "s/:$PUERTO\$/:<puerto>/"

echo
echo "== 4. Desde la red interna no hay salida a internet"
docker run --rm --network "$INTERNA" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/
echo "[código de salida: $?]"
echo "-- pero la puerta de enlace de la red interna sí contesta:"
PUERTA=$(docker network inspect --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' "$INTERNA")
docker run --rm --network "$INTERNA" "$AYUDANTE" sh -c "ip route; ping -c 1 -W 2 $PUERTA | grep -E 'packets'" \
  | sed -E 's/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?/<IP>\1/g'
echo "-- desde la red normal, sí:"
docker run --rm --network "$RED" "$AYUDANTE" wget -q -T 5 -O /dev/null https://www.docker.com/ \
  && echo "desde la red normal sí hay salida"
```

```text
$ ./fig08_08.sh
== 1. Dos redes: la normal y la interna
curso-docker-red-fig08 driver=bridge interna=false
curso-docker-interna-fig08 driver=bridge interna=true

== 2. El servicio de prueba, solo en la interna; el revisor, solo en la normal
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on 127.0.0.11:53: no such host

== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 
-- el puerto publicado sigue en 127.0.0.1:
8080/tcp -> 127.0.0.1:<puerto>

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
-- pero la puerta de enlace de la red interna sí contesta:
<IP>/16 dev eth0 scope link  src <IP> 
1 packets transmitted, 1 packets received, 0% packet loss
-- desde la red normal, sí:
desde la red normal sí hay salida
```

1. **Duas redes**, as duas com driver `bridge`; uma com `interna=true`.
2. **O `revisor` apenas na rede normal não encontra o serviço de teste.** Agora a mensagem diz `lookup … on 127.0.0.11:53: no such host`. Compare-a com a de 8.8: lá ele perguntou ao DNS da máquina (rede padrão); aqui perguntou ao DNS integrado do Docker (rede definida pelo usuário), que existe, mas só responde os nomes **das redes do próprio contêiner**. O serviço de teste está em outra rede, então para o `revisor` ele não existe. É o isolamento de 8.9.1 funcionando: estar na mesma máquina não basta, é preciso compartilhar rede. Ler em que servidor DNS a pergunta foi feita diz de que tipo de rede se está falando.
3. **`docker network connect` sem reiniciar.** O `revisor` é conectado também à interna, com o contêiner em execução, e a verificação seguinte diz `OK`. O `docker inspect` mostra as duas redes do `revisor` (em ordem alfabética, com um espaço no final que o template coloca). E o `docker port` confirma que a porta publicada continua em `127.0.0.1` (o número da máquina é ocultado, porque o script o recebe em `PUERTO`).
4. **Da rede interna não há saída.** Um auxiliar na interna tenta baixar `https://www.docker.com/` e falha antes de tentar se conectar: `wget: bad address 'www.docker.com'`, código `1`. Nem sequer consegue resolver o nome: a consulta sai do contêiner para o DNS integrado do Docker, e uma rede interna não tem saída para fora por onde essa consulta possa chegar a um servidor de nomes externo. (A documentação não detalha em que ponto exato a consulta é cortada, então a lição afirma apenas o que foi medido: o nome não é resolvido e o download nem começa.) Mas a rede interna não está isolada de tudo: o mesmo auxiliar mostra sua tabela de rotas, com uma única linha (a própria rede interna, sem rota padrão para fora), e mesmo assim seu gateway responde ao `ping` (`1 packets received`). Da rede normal, o download funciona. A rede interna não é uma promessa: para fora não há rota, mas o gateway continua ali.

Um esclarecimento para não ficar com uma ideia a mais: «sem saída» não significa «inalcançável a partir da máquina». A referência diz que a máquina pode se comunicar diretamente com os endereços dos contêineres de uma rede interna. O que a rede interna corta é o caminho do contêiner para **outras redes**, a internet inclusive. E no outro sentido há uma fresta que convém conhecer, a que acaba de ser medida: a mesma referência esclarece que «a comunicação com o endereço do gateway (e, com ele, com os serviços do host configurados para isso) é possível». Um programa da máquina que escute em `0.0.0.0` (todas as interfaces), por exemplo um banco de dados de desenvolvimento, fica ao alcance dos contêineres da rede interna. É mais uma razão para o hábito da Lição 2: o que roda na máquina escuta em `127.0.0.1`, não em todas as interfaces. Por isso o curso publica a porta do `revisor` pela rede normal, a que tem caminho para fora, e deixa a interna só para falar com o serviço de teste.

#### 8.10.3 Na pasta do projeto: o estado final

Com a imagem `curso-docker-revisor:1.5.0`, o volume `curso-docker-reportes` e a imagem `curso-docker-prueba:1.0.0` da Lição 2, estes são os comandos do estado final, com os nomes do curso:

```bash
docker network create curso-docker-red
docker network create --internal curso-docker-interna
docker volume create curso-docker-reportes
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
docker run -d --name curso-docker-revisor --network curso-docker-red -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 \
  -v curso-docker-reportes:/datos \
  -e REVISOR_SERVICIOS='prueba http://curso-docker-prueba:9000/ 2s' curso-docker-revisor:1.5.0
docker network connect curso-docker-interna curso-docker-revisor
```

(Se o volume já foi criado em 8.4.4, o `docker volume create` apenas devolve seu nome: não o esvazia.) Confira com `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` que o serviço de teste sai `OK`, e com `docker ps --filter name=curso-docker-` que os dois chegam a `(healthy)`. O serviço de teste leva as mesmas opções reforçadas do `revisor`, sem porta e sem `-e`: é o Exercício 4 da Lição 7, e já se sabe que ele não precisa nem de um `tmpfs` porque não escreve nada. Estes dois contêineres, as duas redes e o volume são o que a Lição 9 escreve em um `compose.yaml`.

Ao terminar a lição, apague-os nesta ordem (primeiro os contêineres, porque uma rede ou um volume em uso não se apaga): `docker rm -f curso-docker-revisor curso-docker-prueba` e `docker network rm curso-docker-red curso-docker-interna`. O volume, se se quiser conservar o relatório, fica; se não, `docker volume rm curso-docker-reportes`.

### 8.11 O que **não** se faz: a rede do host

Outra das redes que o Docker cria ao ser instalado é a `host`. Um contêiner nela **não tem rede própria**: segundo a documentação, sua pilha de rede «não está isolada da máquina» e o contêiner «não recebe seu próprio endereço IP» ([Docker, driver `host`](https://docs.docker.com/engine/network/drivers/host/)). Escuta diretamente nas interfaces da máquina, vê todas as suas portas e todas as suas conexões locais, e `-p` deixa de ter efeito: o Docker o ignora com o aviso `WARNING: Published ports are discarded when using host network mode`. Isso último anula de uma só vez o hábito da Lição 2: já não se decide se a porta fica em `127.0.0.1` ou em todas as interfaces; fica onde o programa decidir escutar.

Às vezes se usa «porque assim funciona» quando um contêiner não encontra outro, ou para ganhar alguns microssegundos de rede. As duas razões têm melhor resposta: para encontrar outro contêiner, uma rede definida pelo usuário; para o desempenho, medir primeiro, porque quase nunca é a rede do contêiner que limita. O README do curso o põe como hábito desta lição: **nunca a rede do host**. O hábito vale para serviços de aplicação como o `revisor`; há usos legítimos em infraestrutura (por exemplo, um agente que mede a rede da própria máquina) que não são tema deste curso, e quem os necessita já sabe que está renunciando ao isolamento de propósito.

### 8.12 O que se encontra em tutoriais antigos

- **`--link`.** A forma antiga de um contêiner encontrar outro pelo nome na rede padrão. A documentação já não a recomenda: os links na rede padrão estão «obsoletos e programados para remoção no Docker Engine 30.0», e pede-se usar «redes definidas pelo usuário em vez da flag legada `--link`» ([Docker, links legados](https://docs.docker.com/engine/network/links/)). Se aparecer, deve ser traduzida para uma rede.
- **«Contêineres só de dados» e `--volumes-from`.** Antes de existirem os volumes nomeados, criava-se um contêiner que nunca rodava só para «ter» um volume, e os demais o montavam com `--volumes-from`. Hoje o volume tem nome próprio e não precisa de um contêiner que o sustente.
- **`VOLUME /datos` no Dockerfile «para que os dados persistam».** A instrução existe e faz algo: marca um caminho como ponto de montagem, e se ao rodar nada for montado ali, o Docker cria um volume **anônimo** que é inicializado com o que a imagem tiver nesse caminho ([referência do Dockerfile](https://docs.docker.com/reference/dockerfile/)). O resultado é justo o contrário do que se busca: um volume sem nome por contêiner, que ninguém reconhece e que se acumula. E a instrução não pode escolher uma pasta da máquina. Este curso não a usa: o `revisor` traz a pasta `/datos` com seu dono, e o volume nomeado é decidido por quem roda o contêiner.
- **`chmod -R 777` sobre a pasta de dados** para «consertar as permissões». Viu-se em 8.3 e 8.6 que o problema é o dono; um `777` o esconde e abre a pasta a qualquer um.

## O erro que se vai ver

Esta lição tem dois erros principais, um por metade, e três secundários. Todos já apareceram.

**O erro principal de armazenamento: o volume novo que o processo não consegue escrever.** É o do `fig08_02.sh`:

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
```

Lê-se da direita para a esquerda, como o da Lição 6. `permission denied` é dito pelo kernel: o processo não tem permissão para criar um arquivo ali. `open /datos/.reporte-<n>.tmp` diz que arquivo, com o caminho **dentro** do contêiner: é o temporário que o `revisor` escreve antes de renomeá-lo, de modo que o problema é a **pasta**, não o `reporte.json`. E `no pude guardar el reporte` é acrescentado pelo `revisor`, que além disso responde `500` em vez de fingir que está tudo bem. A pergunta que resolve é a de sempre: «quem é o dono da pasta, e com que usuário roda o processo?». A primeira resposta é dada por um auxiliar (`docker run --rm -v <volume>:/datos:ro alpine:3.24.2 ls -lnd /datos`); a segunda, por `docker inspect --format '{{.Config.User}}' <contêiner>`. Se a pasta é de `0` e o processo é `65532`, é um volume que nasceu sem uma pasta da imagem para copiar: ou a imagem não traz `/datos` (a 1.4.0), ou alguém usou `volume-nocopy`. A correção é fazer a imagem trazer a pasta com `COPY --chown` e o volume ser novo. O fato de o volume já existir não impede a cópia: enquanto estiver **vazio**, a primeira montagem sobre uma pasta da imagem a recebe, mesmo que tenha sido criado com `docker volume create` (é o que faz o bloco 2 do `fig08_03.sh`, e foi repetido à mão: um volume criado de antemão e montado antes com `nocopy` recebeu igualmente a pasta de `65532` ao ser montado depois com a imagem boa). O que a impede é o volume **já ter algo dentro**, por exemplo um arquivo que algum processo de `root` escreveu: então vale o volume, a pasta continua sendo de `root` e volta o `permission denied`. Nesse caso, se não há nada a conservar, `docker volume rm` e o `docker run` seguinte o cria de novo.

Com um *bind mount* o mesmo texto tem outra origem: a pasta é **da máquina** e o processo, `65532`. Correção: `--user "$(id -u):$(id -g)"`, ou fazer a pasta ser do `65532`. O que não é uma correção, em nenhum dos dois casos: `--user 0` ou `chmod 777`.

**O erro principal de redes: o nome que não existe.**

```text
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
```

`no such host` diz que o nome não pôde ser resolvido. O que diagnostica o caso é **a quem se perguntou**, logo antes do `:53`:

- **O endereço do DNS da máquina**: o contêiner está na rede padrão, que não tem DNS de contêineres. Correção: uma rede definida pelo usuário para os dois.
- **`127.0.0.11`**: o contêiner está de fato em uma rede definida pelo usuário, com o DNS integrado do Docker, mas o outro contêiner não está em **nenhuma de suas redes** (ou se chama diferente, ou não está rodando). Correção: `docker network connect`, ou conferir o nome com `docker ps`.

Esse detalhe transforma uma mensagem genérica em um diagnóstico de uma linha.

**Os secundários:**

```text
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe
```

Um `--mount type=bind` com um caminho da máquina que não existe (sai com `125`; o caminho da mensagem é o que foi escrito). Quase sempre é um erro de digitação ou um caminho relativo ao lugar errado. Com `-v` esse erro não teria aparecido: o Docker teria criado a pasta, de `root`, e o contêiner teria iniciado com uma pasta vazia.

```text
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
```

`docker volume rm` sobre um volume que algum contêiner, rodando ou parado, ainda tem montado. Apague primeiro o contêiner (o identificador entre colchetes diz qual). O mesmo vale para `docker network rm` e uma rede com contêineres conectados.

```text
wget: bad address 'www.docker.com'
```

Em um contêiner de uma rede interna, qualquer nome de fora. Se aparecer em um contêiner que **deveria** ter saída, confira suas redes com `docker inspect`: provavelmente ele está apenas em uma interna.

## O hábito de segurança da lição

**Os dados são montados com nome, com o dono correto e só onde fazem falta; as redes são definidas por quem opera, a dos serviços internos não tem saída, e a do host não se usa.** São três costumes que se escrevem juntos e se comprovam juntos. O primeiro: o sistema de arquivos continua somente leitura, e cada pasta gravável tem nome (um volume em `/datos`, um `tmpfs` com tamanho); nenhuma se conserta com `root` nem com `777`, porque o problema é o dono e se resolve na imagem ou com `--user`. O segundo: cada contêiner está apenas nas redes de que precisa; o que não precisa de internet vive em uma rede `--internal`, e isso se comprova pedindo-lhe que saia (`bad address`). O terceiro: nunca `--network host`, que apaga de uma vez o isolamento de rede e o `127.0.0.1` da Lição 2. O acidente que isso evita é concreto: um serviço interno comprometido que não pode baixar nada nem mandar nada para fora, e que também não pode escrever em mais do que uma pasta escolhida por quem opera.

## O que se faz errado

**Guardar dados na camada do contêiner.** Funciona até o primeiro `docker rm`, que em um serviço é a atualização seguinte. E com `--read-only` nem sequer funciona.

**Rodar como `root` para que o volume se deixe escrever.** Troca um problema de dono por um de segurança, e desfaz as Lições 3, 5 e 7. A imagem traz sua pasta com `COPY --chown`.

**`chmod 777` em uma pasta da máquina.** Abre-a a todos os usuários e a todos os contêineres. A correção é o dono: `--user` com os números da pessoa.

**`-v` com caminhos da máquina.** Um erro de digitação cria uma pasta de `root` em silêncio. Para *bind mounts*, `--mount type=bind`, que por padrão recusa.

**Montar com leitura e escrita o que o contêiner só lê.** Configuração, segredos, certificados: `readonly`. Um *bind mount* gravável é uma porta do contêiner para o disco.

**Volumes anônimos, por `VOLUME` no Dockerfile ou por `-v /datos` sem nome.** Acumulam-se sem que ninguém saiba de quem são. Dê-lhes nome, com o prefixo do projeto.

**Apagar volumes «por precaução».** `docker volume rm` não tem lixeira. E `docker volume prune -a` apaga **todos** os volumes que nenhum contêiner use, com nome ou sem ele, inclusive os dados de projetos parados que não são de quem executa (sem `-a`, o `prune` só apaga os anônimos, segundo sua [referência](https://docs.docker.com/reference/cli/docker/volume/prune/)). Apague pelo nome exato.

**Escrever endereços IP de contêineres na configuração.** São distribuídos pelo Docker e mudam. Use nomes em uma rede definida pelo usuário.

**Deixar tudo na rede padrão.** Sem nomes, e com qualquer contêiner que alguém inicie sem pensar na mesma rede dos demais. A própria documentação a chama de detalhe legado.

**Dar internet a quem não precisa.** Um serviço interno com saída é um trampolim. `--internal`.

**`--network host` «porque assim funciona».** Se um contêiner não encontra outro, a resposta é uma rede definida por quem opera, não retirar o isolamento.

## Exercícios

Faça-os em ordem. Antes de rodar cada um, escreva no [diário de bordo](bitacora.md) o que se acredita que vai acontecer; compará-lo depois é metade do aprendizado. Ao terminar, apague o que foi criado: tudo leva o prefixo `curso-docker-`.

### Exercício 1 — Volume, *bind mount*, `tmpfs` ou nada?

Para cada dado, escolha um dos quatro e diga por quê em uma frase:

1. Um banco de dados de teste que um serviço usa e que deve sobreviver a uma atualização do contêiner.
2. Um arquivo `config.yaml` que é editado na máquina e que o contêiner só lê.
3. Os arquivos de sessão de um programa, que são regenerados a cada inicialização.
4. O código-fonte de um programa enquanto é desenvolvido e testado em um contêiner.
5. O binário do `revisor`.
6. O relatório do `revisor`, que outra ferramenta da máquina, fora do Docker, vai recolher a cada hora.

### Exercício 2 — Leia o `no such host`

Sem rodar nada, diga que situação de rede produziu cada mensagem e com que comando seria corrigida. As duas são do `revisor`, buscando um contêiner que **está** rodando:

```text
A) … lookup curso-docker-prueba on <DNS del anfitrión>:53: no such host
B) … lookup curso-docker-prueba on 127.0.0.11:53: no such host
```

Pergunta extra: no caso B, que outras duas causas, que não têm a ver com as redes, dariam exatamente a mesma mensagem?

### Exercício 3 — O relatório que sobrevive (projeto)

Na pasta do projeto, com o estado final de 8.10.3 rodando, faça esta sequência e, **antes** de cada passo, preveja o resultado:

1. Peça a tabela uma vez: `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'`.
2. Apague o contêiner do `revisor` com `docker rm -f curso-docker-revisor`.
3. Leia o relatório com um auxiliar, sem nenhum `revisor` rodando.
4. Crie o `revisor` de novo com o comando de 8.10.3, **sem** o `docker network connect`, e peça a tabela.
5. Com esse `revisor` rodando, tente `docker volume rm curso-docker-reportes`.
6. Conecte-o à interna e peça a tabela outra vez.

### Exercício 4 — `volume-nocopy`

Preveja o que acontece se a imagem `curso-docker-revisor:1.5.0`, reforçada, for rodada com um volume **novo** montado assim:

```text
--mount type=volume,src=curso-docker-sin-copia,dst=/datos,volume-nocopy
```

O que responde `/api/estados`? De quem é `/datos` dentro do volume? Confira publicando a porta em `127.0.0.1:8081` (ou parando antes o `curso-docker-revisor`, que ocupa a `8080`), e diga como isso se relaciona com o erro de 8.3. Pergunta extra: como se escreve o mesmo com `-v`? No fim, apague o contêiner e o volume.

## Soluções

### Solução 1

1. **Volume nomeado.** Deve durar mais que o contêiner e ninguém precisa mexer nos arquivos à mão. É o caso do relatório.
2. ***Bind mount* somente leitura.** É editado na máquina e o contêiner só o lê; com `readonly`, o contêiner não pode mudá-lo mesmo que queira.
3. **`tmpfs` com tamanho.** Não deve sobreviver ao contêiner, e assim também não ocupa disco nem deixa rastro.
4. ***Bind mount***. A pessoa o edita e o contêiner precisa ver a mudança na hora. É o uso que a documentação dá como exemplo. (Em um contêiner que só o executa, somente leitura.)
5. **Nada: vai na imagem.** É código (Lição 6). Montá-lo de fora faria a imagem testada não ser a que roda.
6. ***Bind mount*** **de uma pasta da máquina**, com `--user` dos números da pessoa, como em 8.6. Uma ferramenta da máquina fora do Docker precisa lê-lo em um caminho próprio, sem `sudo`. Com um volume teria de passar por um contêiner auxiliar.

### Solução 2

- **A)** Perguntou-se ao DNS da máquina: o `revisor` está na **rede padrão**, que não tem DNS de contêineres. Correção: criar uma rede (`docker network create curso-docker-red`) e rodar os dois contêineres com `--network curso-docker-red`, ou conectá-los a ela com `docker network connect`.
- **B)** Perguntou-se ao DNS integrado (`127.0.0.11`): o `revisor` **está** em uma rede definida pelo usuário, mas o serviço de teste não está em nenhuma de suas redes. É o que se viu no bloco 2 do `fig08_08.sh`. Correção: `docker network connect <a rede do outro> curso-docker-revisor` (ou conectar o outro à rede do `revisor`).

Pergunta extra: a mesma mensagem sai se o nome está **escrito errado** em `REVISOR_SERVICIOS` (o DNS não adivinha), ou se o outro contêiner **não está rodando**: o DNS integrado só responde os nomes dos contêineres conectados naquele momento. `docker ps --filter name=curso-docker-` responde às duas dúvidas.

### Solução 3

Os passos 2, 5 e a primeira tabela do 4 foram medidos com a mesma máquina e a mesma versão do Docker da lição, nos scripts `fig08_03.sh` e `fig08_08.sh` (com o sufixo `-fig08` nos nomes); os demais se deduzem deles, e na pasta do projeto devem sair assim:

1. `200`, e a tabela diz `prueba OK`.
2. O contêiner desaparece; o volume não (bloco 4 do `fig08_03.sh`).
3. O auxiliar (`docker run --rm -v curso-docker-reportes:/datos:ro alpine:3.24.2 cat /datos/reporte.json`) deve imprimir o último relatório, em JSON. No bloco 4 do `fig08_03.sh` o serviço se chamava `propio`; no estado final deve se chamar `prueba`, com `"ok": true` e `"codigo": 200`.
4. A tabela diz `FALLA` com `lookup curso-docker-prueba on 127.0.0.11:53: no such host`, como no bloco 2 do `fig08_08.sh`: o `revisor` está em uma rede própria, e o serviço de teste, em outra.
5. `docker volume rm` recusa: `volume is in use`, com o identificador do contêiner entre colchetes, e sai com código `1` (bloco 3 do `fig08_03.sh`).
6. Depois do `docker network connect`, `OK` (bloco 3 do `fig08_08.sh`).

### Solução 4

É o script `fig08_09.sh`, que testa a opção com `--mount` e com `-v`:

```bash
#!/usr/bin/env bash
# fig08_09.sh — Solución del Ejercicio 4: volume-nocopy. La imagen 1.5.0 trae
# /datos de 65532, pero si el volumen nuevo se monta con volume-nocopy, Docker no
# copia nada (ni el dueño) y vuelve el permission denied. Se prueba con --mount
# y con -v, que también admite la opción, pero con OTRO nombre: nocopy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig08»: el guion nunca toca tu curso-docker-revisor:1.5.0,
# tu contenedor curso-docker-revisor ni tus volúmenes, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8081}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig08"
NOMBRE="${PREFIJO}revisor-fig08"
VOLUMEN="${PREFIJO}sin-copia-fig08"
AYUDANTE=alpine:3.24.2
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true
      docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true
      docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true
      rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig08_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.5.0 -t "$IMAGEN" . >/dev/null

ENDURECIDO="--read-only --cap-drop ALL --security-opt no-new-privileges --init --memory 64m --cpus 0.5 --pids-limit 50"
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
probar() {  # probar OPCIÓN-DE-MONTAJE…: corre el revisor con un volumen nuevo y mira /datos
  docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" $ENDURECIDO "$@" \
    -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' "$IMAGEN" >/dev/null
  esperar_http "http://127.0.0.1:$PUERTO/salud"
  curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'
  docker run --rm -v "$VOLUMEN":/datos:ro "$AYUDANTE" ls -lnd /datos
  docker rm -f "$NOMBRE" >/dev/null
  docker volume rm "$VOLUMEN" >/dev/null
}

echo "== 1. Con --mount …,volume-nocopy"
probar --mount type=volume,src="$VOLUMEN",dst=/datos,volume-nocopy

echo
echo "== 2. Con -v, el nombre de --mount no sirve"
salida=$(docker run --rm -v "$VOLUMEN":/datos:volume-nocopy "$IMAGEN" version 2>&1) && rc=0 || rc=$?
echo "$salida" | sed '/^$/d'
echo "[código de salida: $rc]"
docker volume rm "$VOLUMEN" >/dev/null 2>&1 || true

echo
echo "== 3. Con -v …:nocopy"
probar -v "$VOLUMEN":/datos:nocopy
```

```text
$ ./fig08_09.sh
== 1. Con --mount …,volume-nocopy
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
drwxr-xr-x    2 0        0             4096 Oct 21 13:11 /datos

== 2. Con -v, el nombre de --mount no sirve
docker: Error response from daemon: invalid mode: volume-nocopy
Run 'docker run --help' for more information
[código de salida: 125]

== 3. Con -v …:nocopy
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
drwxr-xr-x    2 0        0             4096 Oct 21 13:11 /datos
```

É o erro de 8.3 com a imagem boa. A imagem 1.5.0 traz `/datos` de `65532`, mas `volume-nocopy` diz ao Docker que não copie nada para o volume novo, e o que não se copia inclui o dono: o volume nasce com sua pasta de `root`, como quando a imagem não trazia a pasta (bloco 3 do `fig08_04.sh`). A lição: a correção de 8.4 depende da cópia na primeira montagem. Qualquer coisa que a impeça (`volume-nocopy` na primeira montagem, ou um volume que já tem conteúdo e por isso vale mais que a imagem) traz de volta o `permission denied`. Um volume que existia de antes mas está vazio não a impede: foi medido que ele recebe a pasta igualmente.

Pergunta extra: com `-v`, a opção se escreve `nocopy` (bloco 3). O nome de `--mount` não serve com `-v`: o Docker 29.2.1 o rejeita com `invalid mode: volume-nocopy` e código `125`, ainda que a página de volumes o documente com esse nome (bloco 2). É um bom exemplo de por que o curso roda cada comando em vez de copiá-lo da documentação.

## Como sei que consegui

Marque cada ponto só se for possível fazê-lo **sem voltar a olhar o texto**:

- [ ] Na pasta do projeto, `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.5.0` mostra `REVISOR_REPORTE=/datos/reporte.json`, e `docker create` + `docker export` + `tar -tv --numeric-owner` mostram `datos/` com dono `65532/65532`.
- [ ] Provoca-se o `permission denied` com a imagem 1.4.0 e um volume novo, e explica-se usando as palavras *dono*, `0` e `65532`.
- [ ] O relatório sobrevive ao `docker rm -f curso-docker-revisor`: lê-se com um auxiliar somente leitura.
- [ ] Explica-se com um exemplo quando o conteúdo de uma pasta é **copiado** ao montar e quando é **coberto**, e por que `--mount` é mais seguro que `-v` para um *bind mount*.
- [ ] Roda-se o `revisor` com um *bind mount* de uma pasta da máquina e `--user "$(id -u):$(id -g)"`, e o `stat` mostra que o relatório é de quem o rodou.
- [ ] Um contêiner com `--read-only` escreve em um volume e em um `tmpfs` com `size`, e depois do `docker restart` o arquivo do volume continua e o do `tmpfs`, não.
- [ ] Mostra-se o `no such host` na rede padrão e o `OK` em uma rede definida pelo usuário, e diz-se qual servidor DNS cada uma usa (`/etc/resolv.conf` de um auxiliar).
- [ ] O estado final de 8.10.3 está rodando: o serviço de teste apenas em `curso-docker-interna`, o `revisor` nas duas, a tabela em `OK`, e um auxiliar na rede interna recebe `bad address` ao tentar sair.
- [ ] Rodam-se os scripts de [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes) e as saídas coincidem com as desta lição, exceto os tempos, as datas, os números de usuário e grupo da máquina e o que os scripts ocultam à vista. (Os scripts publicam na `8081`, então não colidem com o `revisor` na `8080`.) E ao terminar, `docker ps -a --filter name=fig08`, `docker volume ls --filter name=fig08` e `docker network ls --filter name=fig08` não mostram nada.

## Resumo

Responda sem olhar a lição:

1. O que é a camada gravável de um contêiner, e que três problemas ela tem para guardar o relatório do `revisor`?
2. Que diferença há entre um volume nomeado, um *bind mount* e um `tmpfs`, em onde vivem os dados e quanto duram?
3. Por que um volume novo montado em uma pasta que a imagem não traz dá `permission denied` com um usuário sem privilégios?
4. O que faz `COPY --chown=65532:65532`, e por que a correção depende de o volume ser novo e vazio?
5. Quando o conteúdo de uma pasta é copiado e quando é coberto ao se montar algo por cima?
6. O que faz `-v` e o que faz `--mount` quando a pasta da máquina não existe?
7. Como se corrige o `permission denied` de um *bind mount* sem `root` e sem `777`?
8. Por que na rede padrão um contêiner não encontra outro pelo nome, e o que muda em uma rede definida pelo usuário?
9. O que é `127.0.0.11`, e o que diz ver esse endereço em um `no such host`?
10. O que uma rede `--internal` corta, o que não corta, e por que a porta do `revisor` é publicada pela outra rede?

## Fontes

Todas consultadas em 21 de outubro de 2026.

- [Docker, «Storage»](https://docs.docker.com/engine/storage/): que o escrito na camada do contêiner não persiste e é difícil de extrair; os tipos de montagem (incluídas as montagens de imagem) e quando usar cada um.
- [Docker, «Volumes»](https://docs.docker.com/engine/storage/volumes/): a cópia do conteúdo da imagem para um volume vazio e a opção `volume-nocopy`; que um volume com dados cobre o que havia; que `--mount` é o preferido; o caminho `/var/lib/docker/volumes/<nome>/_data`; que os volumes sobrevivem ao contêiner e os anônimos são apagados com `--rm`.
- [Docker, «Bind mounts»](https://docs.docker.com/engine/storage/bind-mounts/): que cobrem o conteúdo existente; que `-v` cria a pasta e `--mount` não, por padrão, com o texto `bind source path does not exist`, e a opção `bind-create-src`; que dão acesso de escrita ao host por padrão; a opção `readonly`.
- [Referência do `docker volume prune`](https://docs.docker.com/reference/cli/docker/volume/prune/): que por padrão só apaga os volumes anônimos e que `-a` apaga todos os que não estão em uso.
- [Docker, «tmpfs mounts»](https://docs.docker.com/engine/storage/tmpfs/): que um `tmpfs` vive em memória e desaparece quando o contêiner para; que não se compartilha; seu tamanho máximo (50 % da memória) e sua permissão (`1777`) por padrão; que `--mount` é o preferido; o aviso sobre a memória de troca.
- [Docker, «Networking»](https://docs.docker.com/engine/network/): o servidor DNS integrado em `127.0.0.11` e o reenvio de consultas externas; que os contêineres da rede padrão recebem uma cópia do `/etc/resolv.conf` da máquina; as redes internas para serviços sem acesso externo.
- [Docker, driver `bridge`](https://docs.docker.com/engine/network/drivers/bridge/): as diferenças entre a rede padrão e as definidas pelo usuário (DNS automático, isolamento, conectar com o contêiner em execução) e que a rede padrão é um detalhe legado não recomendado para produção.
- [Referência do `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/): a opção `--internal` e o modo interno (sem rota padrão, tráfego para outras redes descartado, o gateway alcançável e a máquina que sim alcança os contêineres).
- [Docker, driver `host`](https://docs.docker.com/engine/network/drivers/host/): que o contêiner não tem rede própria nem endereço IP e que as portas publicadas são descartadas com um aviso.
- [Docker, links legados](https://docs.docker.com/engine/network/links/): que `--link` na rede padrão está obsoleto e programado para remoção no Engine 30.0.
- [Referência do Dockerfile](https://docs.docker.com/reference/dockerfile/): `COPY --chown` e o dono `0` por padrão; a instrução `VOLUME` e seu volume inicializado com o conteúdo da imagem.
- [Referência do `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `-v`, `--mount`, `--tmpfs`, `--network` e `--user`.
- [Docker Engine 29, notas de versão](https://docs.docker.com/engine/release-notes/29/): as versões e datas de «Sobre as execuções».
- [Colima](https://github.com/abiosoft/colima): a ferramenta com que os programas foram executados no macOS.

### Termos desta lição

| | |
|---|---|
| ***bind mount*** | montagem de uma pasta ou de um arquivo da máquina dentro do contêiner; o contêiner vê exatamente isso, com seu dono e suas permissões |
| **camada gravável** | a camada própria de cada contêiner, por cima das da imagem; é apagada com o contêiner |
| **contêiner auxiliar** | contêiner descartável (`--rm`) usado para olhar um volume ou uma rede; aqui, `alpine:3.24.2` |
| **DNS integrado** | servidor de nomes que o Docker coloca em `127.0.0.11` dentro dos contêineres das redes definidas pelo usuário |
| **rede definida pelo usuário** | rede criada com `docker network create`; dá nomes por DNS e isola dos demais contêineres |
| **rede interna** | rede criada com `--internal`; seus contêineres se falam entre si, mas não saem para outras redes nem para a internet |
| **rede padrão** (`bridge`) | a rede a que o Docker conecta um contêiner se nenhuma outra for indicada; sem nomes, só endereços IP |
| **`tmpfs`** | montagem que vive em memória, com tamanho, e desaparece quando o contêiner para |
| **volume nomeado** | armazenamento administrado pelo Docker que sobrevive aos contêineres; é criado, listado e apagado com `docker volume` |
| **volume anônimo** | volume sem nome, criado por `VOLUME` ou por `-v /caminho`; difícil de reconhecer e fácil de esquecer |

---

**Seguinte:** [Lição 9 — Compose: o sistema completo](09-compose.md)
