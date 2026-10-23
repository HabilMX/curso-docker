# Урок 6 — Конфигурация и тайни

Четвъртък е, 6:40 следобед, и екипът иска да пусне `revisor` в седем. Остава един детайл: тестовата среда има нужда от друг списък с услуги и от различен токен. Някой предлага бързия вариант: „Сменям токена в Dockerfile, изграждам наново и го качвам; пет минути работа“. Прави го и образът отива в споделения регистър (registry). В 6:52 колега от друг екип пита в чата, с цялата невинност на света, защо образът на `revisor` носи променлива `REVISOR_TOKEN` със стойност, която прилича на парола. Не му се е наложило да влиза в никой сървър, нито да чупи нещо: стигнал му е един `docker inspect` върху образ, който е имал право да изтегли. Сега токенът трябва да се смята за изгубен, да се генерира нов и да се разбере кой още е изтеглил образа. Пускането в седем вече няма да стане. Този урок съществува, за да не се стига до този разговор: образът не носи нито конфигурацията на дадена среда, нито нейните тайни, и ще провериш със собствените си очи какво остава вътре в него.

**Време:** 90 мин

**Какво изграждаш:** `revisor`, конфигуриран без повторно изграждане. Образът `curso-docker-revisor:1.3.0` носи записана своята версия, която не е тайна, и нищо друго от която и да е среда. Списъкът с услуги пристига при стартирането на контейнера, чрез променливи на средата или чрез файл с променливи. Токенът за достъп пристига като файл само за четене, никога като променлива. А моделът за използване на тайна **по време на изграждането** остава готов в Dockerfile, без да оставя следа в образа.

**Какво научаваш:** какво е конфигурация и какво е тайна; `ARG` срещу `ENV` (кога съществува всяко от тях и къде остава); `-e` и `--env-file`; OCI етикетите (labels) с версията; тайните при изграждане с `--mount=type=secret` и `--secret`; тайните при изпълнение като файл и защо не като променлива; и най-вече да **гледаш** с `docker history` и `docker inspect` какво пътува вътре в един образ.

**Откъде идваш.** От [Урок 5](05-multi-stage.md), където `revisor` остана в образ с четири етапа, `curso-docker-revisor:1.2.0`, от 16.1 MB, без *shell*, без компилатор и с потребителя `65532`. Този образ има дупка, която може би си забелязал: подкомандата му `version` казва `desarrollo`, защото никой не му е казал коя версия е. От [Урок 3](03-primer-dockerfile.md) носиш и `.dockerignore`, който оставя извън контекста `.env` и `secretos/`, а от [Урок 2](02-contenedores-dia-a-dia.md) — навика да публикуваш портове само на `127.0.0.1`. И пак от Урок 3 — грешката при стартиране на `revisor` без `REVISOR_SERVICIOS`: днес ще видиш защо тази променлива не се слага в Dockerfile.

**Какво не прави този урок.** Не обяснява в дълбочина монтиранията: токенът пристига с `--mount type=bind` на един-единствен файл и засега е достатъчно да знаеш, че то поставя файл от компютъра ти вътре в контейнера. [Урок 8](08-volumenes-y-redes.md) обяснява монтиранията изцяло. Не използва и тайните на Compose, които са удобният начин да се направи същото и идват в [Урок 9](09-compose.md). Не преподава външни мениджъри на тайни (трезори, облачни услуги): този курс работи на твоя компютър, а онова, което научаваш тук, е частта, от която и тези мениджъри имат нужда — тайната да пристига като файл и да не остава в образа. И не е нужно да имаш частни модули на Go: `revisor` не използва такива, а тайната при изграждане се показва със симулирана стойност.

**За изпълненията.** Всички изходи са реални и са получени на 21 октомври 2026 г. на Mac с [Colima](https://github.com/abiosoft/colima), която стартира виртуална машина с Ubuntu 24.04.4, същата основа като Linux Mint 22, референтната система на курса. Скриптовете бяха изпълнени **вътре** в тази виртуална машина, с Docker 29.2.1 (клиент и демон) и Buildx v0.31.1, а работната им папка беше на собствения диск на Linux. Последното е важно в този урок: споделените папки между Mac и виртуалната машина лъжат за правата (файл с права `600` се чете по същия начин от контейнер на друг потребител), а раздел 6.5 е посветен точно на правата. В твоя Mint този проблем не съществува. За да не се сблъскват с други изпълнения, които използваха същата машина, скриптовете бяха пуснати с друг префикс за имената и други портове (променливите `PREFIJO` и `PUERTO`, които имат); никое име на контейнер или образ, нито портът на компютъра, не се появява в изходите им, така че това, което виждаш, е точно онова, което отпечатаха. Със стойностите си по подразбиране скриптовете използват собствени помощни имена, съдържащи `fig06` (образът `curso-docker-revisor:fig06`, контейнерът `curso-docker-revisor-fig06`): така никога не пипат твоя образ `curso-docker-revisor:1.3.0`, нито твоя контейнер `curso-docker-revisor`, а при излизане изтриват само онова, което са създали. Курсът беше планиран с Docker Engine 29.8.2, а най-новата публикувана версия в този ден беше 29.9.2, от 20 октомври 2026 г. ([бележки към версиите](https://docs.docker.com/engine/release-notes/29/)); нищо от този урок не се променя между тези версии. Което **се** променя от едно изпълнение до друго и се отбелязва там, където се появява: времената в таблицата на `revisor` (скрити с `<t>` в самия скрипт), времената и датата в редовете от изграждането, и думата `arm64` в историята на образа, която на компютър с Intel или AMD е `amd64`. Програмите са в [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos), всяка с изхода си до нея, а `estado/` пази файловете на проекта такива, каквито остават в края.

## След урока ще можеш да

- Класифицираш стойност на `revisor` като код, конфигурация или тайна и кажеш къде трябва да живее всяка.
- Обясниш разликата между `ARG` и `ENV`, като кажеш кога съществува всяко от тях и къде остава записано, и го провериш с `docker history` и `docker image inspect`.
- Стартираш един и същ образ с две различни конфигурации, с `-e` и с `--env-file`, без повторно изграждане.
- Намериш тайна, оставена в образ чрез `ARG` или `ENV`, и разчетеш предупреждението `SecretsUsedInArgOrEnv` от `docker build --check`.
- Предадеш токена на `revisor` като файл само за четене и поправиш грешката `permission denied`, която се появява при това.
- Използваш тайна по време на изграждането с `--secret` и докажеш, че не е останала в образа.

## Защо, преди как

До Урок 5 всичко, от което `revisor` имаше нужда, за да работи, идваше от образа или от няколко `-e`, написани в движение. Работеше, защото имаше само една среда: твоят компютър. Щом се появи втора среда (тестова, продукционна, компютърът на колега), се появява и въпросът на този урок: **какво се променя от една среда в друга и къде се записва?**

Класическият отговор идва от едно често цитирано ръководство, *The Twelve-Factor App*, което определя конфигурацията на едно приложение като „всичко, което е вероятно да се различава между разгръщанията“ ([12factor.net, „Config“](https://12factor.net/config)). В `revisor` това е списъкът с услуги, които проверява, портът, пътят на отчета и токенът. Онова, което **не** се променя, е кодът и версията: `1.3.0` е `1.3.0` навсякъде. Същото ръководство предлага прост тест дали си разделил добре: би ли могъл да публикуваш кода си като отворен в този момент, без да разкриеш нито една идентификационна информация? Този курс е отворен, така че тестът не е хипотетичен: Dockerfile на `revisor` е публикуван и затова не може да съдържа нищо, което не искаш светът да прочете.

При образите въпросът има още едно измерение. Образът не е просто файл, който се изпълнява; той е пакет, който **пътува**: качва се в регистър, изтегля се на други машини, пази се в кешове, копира се в клъстер. Всичко, което сложиш в него, го получава всеки, който може да го изтегли. А образът пази повече, отколкото изглежда: освен файловете на слоевете си, пази своята **конфигурация** (средата, потребителя, етикетите) и своята **история** (инструкцията, създала всеки слой, със стойностите, които е имала). Документацията на Docker го казва без заобикалки: аргументите при изграждане и променливите на средата „не са подходящи за предаване на тайни към изграждането“, защото „се запазват в крайния образ“ ([Docker, „Build secrets“](https://docs.docker.com/build/building/secrets/)).

Затова този урок прави три неща, в този ред:

1. **Изважда конфигурацията от образа** (6.1 до 6.3): образът носи версията си и стойности по подразбиране, които не са тайни; останалото пристига при стартиране.
2. **Показва ти с очите ти какво става, когато тайна влезе в образа** (6.4): ще я сложиш нарочно, със симулирани стойности, и ще я намериш.
3. **Прави го както трябва** (6.5 и 6.6): тайната при изпълнение — като файл само за четене, а тайната при изграждане — като монтиране, което трае колкото трае един `RUN`.

С тази цел пред очи, ето какво ще видиш в раздел 6.4, когато търсиш вътре в зле направен образ. Симулираната стойност е там, в историята, макар самият `RUN` да е изтрил файла, който я съдържаше:

```text
== 3. Pero el historial guardó el valor del ARG, en dos renglones
RUN |1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be /bin/sh -c echo "machine ejemplo.invalid password ${TOKEN_MODULOS}" > /root/.netrc  && CGO_ENABLED=0 go build -o /usr/local/bin/revisor ./cmd/revisor  && rm /root/.netrc # buildkit
ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be
```

## Понятията

### 6.1 Код, конфигурация и тайна: три различни неща

#### 6.1.1 Да класифицираш това, от което `revisor` има нужда

Преди да напишеш и един ред, е добре да дадеш име на всяка стойност. Има три кутии:

| Кутия | Какво е | В `revisor` | Къде живее |
|---|---|---|---|
| **Код** | това, което програмата прави; еднакво във всички среди | двоичният файл, компилиран във версия `1.3.0` | вътре в образа |
| **Конфигурация** | това, което се променя от една среда в друга и не е тайна | `REVISOR_SERVICIOS`, `REVISOR_PUERTO`, `REVISOR_REPORTE` | извън образа; пристига при стартиране |
| **Тайна** | конфигурация, която, ако изтече, някой може да използва срещу теб | токенът на `/api/estados`; идентификационни данни за изтегляне на частни модули | извън образа **и** извън променливите на средата; пристига като файл |

Две стойности заслужават коментар. **Портът** е конфигурация, но има разумна стойност по подразбиране (`8080`), която не е тайна, и затова образът го декларира с `ENV`: служи като документация и като стойност по подразбиране, а всяка среда може да го смени. **Версията** не е конфигурация: не се променя между средите, тя описва кода. Затова се записва при изграждане и не се иска при стартиране.

Тайната има собствена кутия, защото изпълнява двете условия: променя се между средите (тестовият токен не е продукционният) и стойността ѝ не бива да остава на показ. Именно второто условие изключва променливите на средата, както ще видиш в 6.5.

#### 6.1.2 Тайните в този курс са симулирани и го казват

Всички тайни, които се появяват в този урок, са **измислени за упражнението** и го обявяват в самата си стойност: `curso-docker-token-de-mentira-7f3a9c`, `curso-docker-modulos-de-mentira-41be`. Не отключват нищо. Живеят в папката `secretos/` на проекта, която курсът публикува нарочно, за да можеш да изпълниш всичко. В истински проект тази папка **никога** не се публикува: слага се в `.gitignore` и в `.dockerignore`, а стойностите ѝ идват от мястото, където екипът ти пази идентификационните данни.

`.dockerignore`, който носиш от уроци 3 и 4, вече я изключва, заедно с `.env` и `Dockerfile*`:

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

Това означава, че никой `COPY` не може да вкара по невнимание файл от `secretos/` в образа: той дори не стига до демона. Това е първата врата, и най-евтината. Този урок затваря другите три: историята, конфигурацията на образа и конфигурацията на контейнера.

### 6.2 `ARG` срещу `ENV`

#### 6.2.1 Две инструкции, които си приличат и не си приличат

Двете инструкции дефинират променливи с име и стойност и двете се използват с `${NOMBRE}` вътре в Dockerfile. Онова, което ги разделя, е **кога съществуват**:

- **`ARG`** декларира **аргумент при изграждане** (build argument). Съществува само докато се изгражда образът, а стойността му може да се смени отвън с `docker build --build-arg NOMBRE=valor`. Контейнерите, които произлизат от образа, не го получават. Документацията го обобщава така: аргументите при изграждане „не са достъпни и не присъстват в контейнерите“, създадени от образа, но стойностите им „могат да се запазят в метаданните на образа“, в атестациите за произход (provenance) и **в историята** ([Docker, „Build variables“](https://docs.docker.com/build/building/variables/)).
- **`ENV`** дефинира **променлива на средата**, която съществува по време на изграждането и която освен това образът предава на всеки контейнер, произлязъл от него: „променливите на средата, дефинирани с `ENV`, се запазват, когато се стартира контейнер от образа“, и могат да се видят с `docker inspect` и да се сменят с `docker run --env` ([справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/)).

Казано в един ред: `ARG` е стойност за **изграждане**; `ENV` е стойност за **изпълнение**. И нито едното, нито другото е скривалище: и двете оставят стойността си записана в образа — едното в историята, другото в конфигурацията.

Има един детайл за обхвата, който обърква всички първия път. Един `ARG` важи **в етапа, където е деклариран** (и в етапите, които произлизат от него). В Dockerfile с няколко етапа, ако етапът `final` също има нужда от стойността, я декларира отново. Точно това прави Dockerfile на този урок с `VERSION`.

#### 6.2.2 Dockerfile на този урок

Това е Dockerfile, с който завършва урокът. Той е този от Урок 5 с четири промени, като всяка се обяснява по-долу:

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

Четирите промени, в реда, в който се появяват:

1. **`ARG VERSION=desarrollo` в етапа `binario`.** Декларира аргумента със стойност по подразбиране. Ако изграждаш без `--build-arg`, стойността е `desarrollo`, което е точно онова, което `revisor` казваше в Урок 5; така нищо не се чупи за този, който изгражда, без да знае за този аргумент.
2. **`-X main.version=${VERSION}` в `go build`.** Това е опция на линкера на Go, която при компилиране заменя стойността на текстова променлива в програмата ([cmd/link](https://pkg.go.dev/cmd/link)). `revisor` има променлива `version` в пакета си `main`, чиято стойност е `desarrollo`, ако никой не я пипне. С тази опция номерът остава **вътре в двоичния файл**, което е единственото място, където не може да се изгуби, нито да бъде опроверган.
3. **`--mount=type=secret,...,required=false`** в същия `RUN`. Това е тайната при изграждане; тя има собствен раздел, 6.6. Засега е достатъчно да знаеш, че понеже е незадължителна, изграждането работи еднакво с нея и без нея.
4. **В етапа `final`: `ARG VERSION` отново, `LABEL` и `ENV`.** `ARG` се повтаря, защото всеки етап има собствен обхват (6.2.1). С него `LABEL` закача към образа три **етикета** (*labels*) с имена от един стандарт, този на *Open Container Initiative*: `org.opencontainers.image.title` е „четимото заглавие“ на образа, `org.opencontainers.image.version` е „версията на пакетирания софтуер“, а `org.opencontainers.image.source` е „URL адресът за получаване на изходния код“, с който е изграден образът ([OCI, предварително дефинирани анотации](https://github.com/opencontainers/image-spec/blob/main/annotations.md)). Тук той сочи към страницата на курса, която е публичният референтен адрес на този материал; в собствения си проект сложи адреса на хранилището, което е и онова, което спецификацията изисква. Всеки инструмент, който може да чете тези етикети (регистър, скенер, Урок 10), знае какво е образът, без да го стартира. А `ENV REVISOR_PUERTO=8080` оставя стойността по подразбиране на порта пред очите на всеки, който инспектира образа.

Обърни внимание на онова, което **няма**: нито `REVISOR_SERVICIOS`, нито `REVISOR_TOKEN`, нито `REVISOR_TOKEN_ARCHIVO`. Образът не знае в каква среда ще работи и така трябва да бъде.

#### 6.2.3 Изграждане и проверка къде е останало всяко нещо

Скриптът `fig06_02.sh` изгражда образа с `--build-arg VERSION=1.3.0` и после го пита, без да стартира сървъра, какво съдържа:

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

Пет блока, пет различни места, където живее информацията на един образ:

1. **Размерът не се промени**: 16.1 MB, колкото и `1.2.0`. Етикетите, `ENV` и `ARG` не тежат: те са метаданни, а не файлове.
2. **Версията е в двоичния файл.** Подкомандата `version` отпечатва `1.3.0`. Тя е същата, която връща `GET /salud`, и същата, която `revisor` пише при стартиране (`revisor 1.3.0 escuchando en :8080`), както ще видиш в 6.5.
3. **OCI етикетите** са в конфигурацията на образа и се четат с `docker image inspect`, без да се стартира нищо. Шаблонът `{{range $k, $v := .Config.Labels}}` обхожда картата с етикети; `docker` ги подрежда по име.
4. **Средата**, която ще получи всеки контейнер: две променливи, които идват от основата *distroless* (`PATH` и `SSL_CERT_FILE`, пътят до доверените сертификати), и нашата, `REVISOR_PUERTO=8080`. Виж добре какво **липсва**: `VERSION`. `ARG` не е преминал в средата. Никой контейнер няма да го получи.
5. **Историята**, от най-новото към най-старото. Всеки ред е инструкция от етапа `final` (другите етапи ги няма: те не са част от предадения образ, както видя в Урок 5). Тези, които не създават файлове, тежат `0B`. `…` е `docker history`, който съкращава дългите редове; с `--no-trunc` се виждат изцяло. А сега редът, който има значение за останалата част от урока: **`ARG VERSION=1.3.0`**. Стойността на аргумента е записана в историята, пред очите на всеки, който има образа. За версия това е напълно наред: не е тайна и дори помага. За токен би било изтичане. Запомни този образ; в 6.4 ще го видиш със стойност, която не би трябвало да е там.

Последният ред (`bazel build //common:cacerts_debian13_arm64_…`) е слой от основата *distroless*: авторите ѝ я изграждат с инструмент на име Bazel и историята го записва. В твоя Mint с процесор Intel или AMD пише `amd64` там, където тук пише `arm64`.

#### 6.2.4 В твоята папка

Скриптовете на курса работят във временни папки и изтриват онова, което създават; твоят проект живее в `~/curso-docker/revisor` от Урок 3. От корена на хранилището на курса сложи там Dockerfile на този урок и папката със симулирани тайни и изгради образа, който ще запазиш:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cp -R programas/06-configuracion-y-secretos/estado/secretos ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 -t curso-docker-revisor:1.3.0 .
docker run --rm curso-docker-revisor:1.3.0 version
```

Последната команда трябва да отпечата `1.3.0`. `.dockerignore` не се променя: вече изключва `secretos/`. В `estado/` е и `Dockerfile.malo`, сгрешената рецепта от 6.4. Копирай и нея, защото „Как да разбера, че съм успял“ иска от теб да повториш този експеримент; `.dockerignore` (който изключва `Dockerfile*`) не ѝ позволява да пътува в контекста. А когато стигнеш до 6.6, изгради отново образа си с тайната при изграждане, за да провериш, че не оставя следа:

```bash
cp programas/06-configuracion-y-secretos/estado/Dockerfile.malo ~/curso-docker/revisor/
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.3.0 --secret id=netrc,src=secretos/token_modulos.txt -t curso-docker-revisor:1.3.0 .
```

Скриптовете на този урок не пипат нищо от това: използват помощни имена с `fig06` и изтриват само своето.

### 6.3 Конфигуриране без повторно изграждане

#### 6.3.1 `-e` и `--env-file`

Образът вече не знае кои услуги да проверява. Това му се казва **при стартиране** и има два начина:

- **`-e NOMBRE=valor`** (или `--env`), по една за всяка променлива, на същия ред с `docker run`. Това използваш от Урок 2. Ако напишеш само `-e NOMBRE`, без стойност, Docker взема стойността, която тази променлива има в терминала ти, и я предава; ако в терминала ти не съществува, контейнерът не я получава ([справочник на `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).
- **`--env-file archivo`**: текстов файл с по един `NOMBRE=valor` на ред. Редовете, които **започват** с `#`, са коментари; `#` в средата на реда е част от стойността. Ред само с `NOMBRE`, без `=`, взема стойността от терминала ти, точно като `-e NOMBRE`. Служи, за да държиш конфигурацията на всяка среда в собствен файл (`pruebas.env`, `local.env`), а не в команда от три реда, която никой не помни.

Двата начина могат да се комбинират и двата имат предимство пред онова, което казва `ENV` на образа. Това е смисълът на стойността по подразбиране: да е там, докато някой не каже друго.

#### 6.3.2 Един и същ образ, три конфигурации

Скриптът `fig06_03.sh` изгражда `curso-docker-revisor:1.3.0` веднъж и го стартира три пъти с различни конфигурации. Първата съдържа нарочна грешка:

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

Преди да прочетеш изхода, новите редове в скрипта. Функцията `tabla` иска отчета под формата на таблица и скрива времето за отговор с `<t>`, защото то е единственото, което се променя между изпълненията; скрива го **в самата команда**, на видно място, а не чрез редактиране на изхода. Услугата `propio` е `revisor`, който проверява самия себе си: вътре в контейнера `127.0.0.1:8080` е самият контейнер, а не компютърът ти. А услугата `inexistente` сочи към порт 9, където нищо не слуша; тя е там, за да видиш отказ.

Сега изходът, блок по блок:

1. **Една буква по-малко.** `REVISOR_SERVICIO` не е променлива, която `revisor` познава, така че той я пренебрегва безшумно, както всяка програма пренебрегва променливите, които не чете. За него `REVISOR_SERVICIOS` просто не съществува и той отказва да стартира с код 1. Това е същата грешка като в Урок 3, но сега знаеш защо е толкова честа: Docker не валидира имената на променливите; няма как да знае кои чете програмата ти. Валидира програмата и затова е добре, че `revisor` се проваля шумно и с пример, вместо да стартира с празен списък и да се преструва, че всичко е наред.
2. **С `-e`, една услуга.** Отчетът съдържа един ред, `propio`, в изправност.
3. **С `--env-file`, две услуги.** Файлът съдържа коментар и една променлива. Обърни внимание, че стойността **няма кавички**: във файл за `docker run --env-file` всичко след `=` е стойността, включително кавичките. Това е класически капан и Упражнение 3 те кара да стъпиш в него. Внимавай, когато пренасяш това правило в Урок 9: `env_file` на Compose е друг четец и **маха** кавичките ([справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/)). Измерено с Compose v5.0.2: същият ред с кавички стигна до контейнера като `REVISOR_SERVICIOS=propio http://127.0.0.1:8080/salud`, без тях. Един и същ вид файл, два четеца, два резултата. Сега таблицата има два реда: `inexistente` с `FALLA` и точната причина, и `propio` с `OK`.
4. **Онова, което получи контейнерът**, е сумата от онова, което носи образът (`REVISOR_PUERTO=8080`, от неговия `ENV`), и онова, което пристигна при стартиране (`REVISOR_SERVICIOS`, от файла). `grep REVISOR` оставя настрана `PATH` и `SSL_CERT_FILE`, които също са там.
5. **Един и същ образ.** Скриптът запази идентификатора на образа на първия контейнер и го сравни с този на втория: еднакви са. Две различни поведения, нула повторни изграждания. В това е целият смисъл на отделянето на конфигурацията.

#### 6.3.3 Какво ти дава това

Отделянето на конфигурацията от образа не е въпрос на стил. То има три практически последици. Първата: **образът, който си тествал, е този, който предаваш**. Ако за преминаване от тестова среда към продукция трябваше да изграждаш наново с друга конфигурация, продукционният образ щеше да е такъв, който никой не е тествал. Втората: **смяната на конфигурацията струва секунди** — колкото отнема стартирането на контейнер, а не колкото отнема едно изграждане. Третата: **образът може да се публикува**, защото не носи нищо от никоя среда. Тези три заедно са онова, което позволява в Урок 10 да се публикува един-единствен образ и да се занесе в Kubernetes.

### 6.4 Така НЕ: да видиш с очите си какво остава вътре в образа

#### 6.4.1 Сгрешената рецепта

За да се научиш да намираш тайна в образ, най-добре е да скриеш една и да я потърсиш. Този Dockerfile прави двете неща, които урокът забранява. Има един-единствен етап, както в Урок 4, за да е всичко пред очите ти:

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

Двете грешки подражават на реални случаи:

- **Грешка 1** е онова, което прави този, който има нужда от идентификационни данни, за да изтегли частни зависимости. Go, като много други инструменти, чете идентификационните данни от файл `.netrc` в папката на потребителя: ред `machine <сървър> password <тайна>`. Рецептата записва файла със стойността на един `ARG`, компилира и го изтрива **в същия `RUN`**. Който я е написал, е знаел, че файл, изтрит в по-късен `RUN`, остава в предишния слой, и затова е направил всичко наведнъж. Изглежда предпазливо. Не е достатъчно. (Сървърът е `ejemplo.invalid`, резервиран домейн, който не съществува в интернет.)
- **Грешка 2** е прекият път от сцената в началото: токенът на `revisor` като `ENV`, за да „идва вече конфигуриран“.

#### 6.4.2 Да го потърсиш

Скриптът `fig06_05.sh` изгражда тази рецепта, като ѝ подава симулирания токен за модулите, и после търси двете тайни там, където може да търси всеки, който има образа:

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

#### 6.4.3 Да разчетеш какво си намерил

1. **Файлът вече го няма.** Вътре в образа `/root` има обичайните файлове на основата и кешовете, оставени от `go build` (`.cache`, `.config`), но не и `.netrc`. Скриптът използва `--user 0` само за да може да погледне в `/root`, която не е четима за потребителя `10001` на образа. Ако спреш дотук, би казал, че рецептата е проработила.
2. **Историята я има, два пъти.** Единият ред е самата инструкция, `ARG TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`, със стойността, която е получила. Другият е `RUN`, който започва с `|1 TOKEN_MODULOS=curso-docker-modulos-de-mentira-41be`. Това `|1` е **брояч**: „в тази стъпка имаше 1 аргумент при изграждане“; след него идват всички, със стойността си. Изтриването на файла не изтри стойността, защото стойността никога не е била само във файла. Това е същият механизъм, който в 6.2.3 остави `ARG VERSION=1.3.0` на показ; разликата е само в това, което си сложил в аргумента.
3. **Конфигурацията съдържа токена за изпълнение**, точно както в сцената в началото: `REVISOR_TOKEN=curso-docker-token-de-mentira-en-env`.
4. **И всеки контейнер го получава.** `printenv` го отпечатва отвътре, без никой да му го е подал при стартиране: идва от образа.
5. **`docker build --check` беше предупредил**, без да изгражда нищо. Той проверява Dockerfile с правилата на BuildKit и за всяка находка ти казва името на правилото (`SecretsUsedInArgOrEnv`), връзка към обяснението му, коя инструкция го е задействала (`ARG "TOKEN_MODULOS"`, `ENV "REVISOR_TOKEN"`), файла и реда, и откъса от Dockerfile със стрелка `>>>`. Излиза с код 1, когато намери нещо, така че може да спре автоматизиран процес. Правилото гледа **името** на променливата: документацията казва, че то отбелязва ключовете, които „показват, че съдържат чувствителни данни“, без да дава списъка ([Docker, правило `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/)); тук го задейства `TOKEN`, а в Упражнение 4 ще видиш име на испански, което минава без предупреждение. Затова то е предпазна мрежа, а не гаранция. Ако искаш нормален `docker build` (не само `--check`) да спира при всяко предупреждение, директивата `# check=error=true`, на реда след `# syntax=`, прави точно това ([Docker, „Build checks“](https://docs.docker.com/build/checks/)). Редовете, които започват с `#0`… `#5`, са предварителната работа на BuildKit, за да може да прочете Dockerfile; могат да се пренебрегнат.
6. **Един `ARG` замърсява всеки `RUN`, който идва след него.** Последният блок използва рецепта с два етапа, написана в самия скрипт, в която **нито един** `RUN` не споменава аргументите. Въпреки това `RUN` от етапа `base` носи `|1 TOKEN_MODULOS=…`, а този от етапа `hija`, който произлиза от `base` и освен това декларира `VERSION`, носи `|2 TOKEN_MODULOS=… VERSION=1.3.0`. BuildKit записва във всеки `RUN` всички аргументи, декларирани в неговия етап и в етапа, от който произлиза, независимо дали ги използва. Токен в `ARG` не оставя една следа: оставя по една за всеки следващ `RUN`.

Важното в този експеримент е начинът на търсене, защото него ще използваш в собствените си образи:

```bash
docker history --no-trunc --format '{{.CreatedBy}}' <imagen>
docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <imagen>
```

Две команди, никакви специални права, никакъв допълнителен инструмент. Всеки, който може да изтегли образа ти, може да ги изпълни. А ако тайна вече е стигнала до публикуван образ, няма команда, която да го поправи: тайната се смята за изгубена и се **сменя** в услугата, която я е издала. Изтриването на образа от регистъра не го премахва от машините и кешовете, които вече са го изтеглили.

### 6.5 Тайната при изпълнение: файл, а не променлива

#### 6.5.1 Защо не променлива на средата, дори да пристига при стартиране

Да извадиш токена от Dockerfile и да го подадеш с `-e REVISOR_TOKEN=...` при стартиране е по-добре, отколкото да го оставиш в образа: вече не пътува до регистъра. Но не е достатъчно, по две причини, които документацията на Compose обобщава така: променливите на средата „обикновено са достъпни за всички процеси и може да е трудно да се проследи достъпът“, и „също така могат да бъдат отпечатани в логовете при отстраняване на грешки, без да знаеш“ ([Docker, „Secrets in Compose“](https://docs.docker.com/compose/how-tos/use-secrets/)). Към това се добавя нещо, характерно за Docker: конфигурацията на **контейнера** пази цялата му среда и всеки, който може да използва `docker inspect` на този компютър, я чете. А от Урок 1 знаеш кой може да използва `docker`: групата `docker`, която е равносилна на `root`. Има още една следа, която няма общо с Docker: ако напишеш стойността буквално в терминала (`-e REVISOR_TOKEN=abc…`, и същото важи за `--build-arg`), тя остава в историята на твоя *shell* и, докато командата работи, в списъка с процеси на компютъра ти. Скриптовете на този урок никога не пишат стойност ръчно: четат я от файла с `$(cat secretos/…)` и това предотвратява първото — стойността да остане в историята на твоя *shell*. **Второто не го предотвратява.** Твоят *shell* замества `$(cat …)`, преди да стартира `docker`, така че стойността стига до `docker` като още един аргумент и, докато командата работи, всеки, който може да изброява процеси (`ps` или четене на `/proc/<pid>/cmdline`), я вижда, все едно си я написал. Тук това няма значение, защото токените в урока са измислени. С истинска тайна решението е да не я подаваш като аргумент: да я предадеш като монтиран файл, както прави останалата част от този урок, или, при изграждане, с `--secret` (6.6).

`revisor` приема двата начина, но не ги третира еднакво. `REVISOR_TOKEN` работи и отпечатва предупреждение. `REVISOR_TOKEN_ARCHIVO` получава **пътя** до файл и чете токена оттам; ако са зададени и двете, печели файлът. Конвенцията за пътя е `/run/secrets/<име>`: там Compose слага своите тайни и там BuildKit слага по подразбиране тайните при изграждане, както ще видиш в 6.6.

#### 6.5.2 Двата начина и грешката, на която ще попаднеш първо

Скриптът `fig06_06.sh` пробва двата начина и по средата предизвиква най-честата грешка на правилния начин. Използва симулирания файл `secretos/revisor_token.txt`, който съдържа `curso-docker-token-de-mentira-7f3a9c`:

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

#### 6.5.3 Да разчетеш изпълнението

1. **Чрез променлива работи и се вижда.** `revisor` стартира, но първото, което пише в лога си, е предупреждение: `el token llegó por REVISOR_TOKEN: cualquiera con docker inspect lo puede leer`. И `docker inspect` го потвърждава, с целия токен. Не се наложи да влизаме в контейнера, нито да имаме образа: стигаше да можем да говорим с демона. (Версията `1.3.0` в съобщението при стартиране е тази, която записа в 6.2.)
2. **Чрез файл, с `600`, не стартира.** Това е грешката на урока. Файлът на компютъра ти принадлежи на твоя потребител и има права `600`: само собственикът му може да го чете. Когато го монтираш, контейнерът вижда **същия файл**, със същия собственик (номер на потребител) и същите права; монтирането не копира и не превежда нищо. А вътре в контейнера `revisor` работи като потребителя `65532`, който не е собственикът. Ядрото прави онова, което би направило с всеки друг потребител на компютъра ти: `permission denied`. Това е пряко следствие от нещо, което видя в Урок 0: при нормалната инсталация от Урок 1 номерата на потребителите вътре и вън са едни и същи. (При Docker без `root` или с преназначаване на потребителите (user namespace remapping) номерът отвътре се превежда в друг отвън и диагностиката с `ls -ln` се променя.) Обърни внимание и на това, че `revisor` **не стартира наполовина**: ако си му казал, че има файл с токен, а той не може да го прочете, предпочита да умре с код 1, отколкото да слуша без защита.
3. **С `644` работи.** `644` дава право за четене на всеки; сега потребителят `65532` може да го прочете. И не само той: **всеки друг акаунт на компютъра ти** също (6.5.4). Тук токенът е симулиран. `/salud` отговаря без токен (за да може състоянието да се наблюдава, Урок 7), а `/api/estados` отговаря с `401` без токен и с таблицата, когато има токен. Изходът съдържа празен ред след JSON-а от `/salud`: това е `echo` от скрипта, който добавя нов ред към този, който `revisor` вече е изпратил. А редът на променливите в `docker inspect` в блок 4 може да се различава от едно изпълнение до друго; важното е кои са.
4. **`docker inspect` вече не показва тайната.** Показва `REVISOR_TOKEN_ARCHIVO=/run/secrets/revisor_token`, път, който не върши никаква работа без файла. А монтирането се появява като `escribible: false`: опцията `readonly` не позволява на контейнера да промени файла на компютъра, дори да има права за това.

#### 6.5.4 Не е ли опасно `644`?

Да, и краткият отговор е: **с истинска тайна — никога**. `644` означава, че **всеки друг акаунт на компютъра ти** може да чете файла: този на друг човек на споделен сървър, този на услуга, която работи със собствен потребител, този на програма, която някой е пуснал като друг потребител. Урок 9 го доказва с акаунт без привилегии (`sudo -u nobody cat`, раздел 9.8.3): с `644` отпечатва целия токен. Курсът използва `644` в този урок, защото токенът е симулиран (`curso-docker-token-de-mentira-7f3a9c` не отваря нищо), а упражнението е на твоя компютър; това е най-краткият начин да видиш, че `revisor` стартира. Не го копирай в истински проект.

Добрите решения атакуват една и съща причина (на кого принадлежи файлът, а не само колко е отворен) и се проверяват с `ls -l` или със `stat -c '%a %U:%G' secretos/revisor_token.txt`:

- **Групата на файла да е тази на контейнера**: `sudo chgrp +65532 secretos/revisor_token.txt` и `chmod 640 secretos/revisor_token.txt` (`+` показва, че `65532` е номер на група). Оставаш собственик (четеш го и го редактираш без `sudo`), `revisor` го чете, защото работи като `65532:65532`, и никой друг, освен `root` и онзи, който управлява Docker (9.8.3). Избери този **или** следващия вариант, не и двата.
- **Файлът да принадлежи на потребителя на контейнера**: `chmod 600 secretos/revisor_token.txt` и **след това** `sudo chown 65532:65532 secretos/revisor_token.txt`, в този ред: когато собственикът вече е `65532`, твоят `chmod` се проваля с `Operation not permitted` и файлът остава отворен. Така го четат само този потребител и `root`. Цената е, че твоят потребител вече не може да го чете без `sudo`.
- **Да го предаде оркестратор, с една важна уговорка.** Тайните на Compose (Урок 9) слагат файла в `/run/secrets/`, но когато тайната идва от **файл**, Compose го монтира такъв, какъвто е, точно като `--mount` от този урок: собственикът и правата остават тези на файла на компютъра ти. Справочникът му го казва: с файл като източник Compose използва отдолу монтиране, което не позволява смяна на собственика, а атрибутите `uid`, `gid` и `mode` „се пренебрегват безшумно“; работят само когато тайната идва от променлива на средата ([справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/)). Измерихме го с Compose v5.0.2: файлът с `600`, с `uid: "65532"`, `gid: "65532"` и `mode: 0400`, декларирани в `compose.yaml`, даде точно същото `permission denied` като в 6.5.2. Затова Урок 9 измерва четирите случая (`644`, `600` твой, `600` на `65532` и `640` с група `65532`) и оставя файла ти в последния. Kubernetes наистина монтира тайните си с правата, които декларираш, но това е материал за курса по Kubernetes.

И тайната да не стигне до хранилището: `secretos/` отива в `.gitignore` на проекта ти, както и в `.dockerignore`. Този курс държи своята `secretos/` в хранилището, нарочно, защото токенът е симулиран.

Онова, което **не** е решение: да смениш `USER` на образа на `root`, „за да може да чете“. Това заменя проблем с правата с проблем със сигурността и разваля работата от уроци 3 и 5.

### 6.6 Тайната при изграждане: монтиране, което трае един `RUN`

#### 6.6.1 Кога е нужна

Понякога тайната не е за изпълнение, а за **изграждане**: идентификационни данни за изтегляне на частни модули на Go, пакети от частно хранилище на npm или Maven, сертификат за достъп до вътрешен сървър със зависимости. `revisor` няма външни зависимости, така че днес не му трябва, но моделът остава в неговия Dockerfile за деня, в който ще му потрябва.

BuildKit има инструмент, направен точно за това: **монтирането на тайна** (secret mount). В Dockerfile един `RUN` иска тайната с `--mount=type=secret,id=<име>`; при изграждане ти му я предаваш с `docker build --secret id=<име>,src=<файл>` (или `env=<ПРОМЕНЛИВА>`, ако я имаш в променлива в терминала си). Според документацията монтирането прави тайната достъпна „временно вътре в контейнера за изграждане, по време на инструкцията“ ([Docker, „Build secrets“](https://docs.docker.com/build/building/secrets/)). Опциите, които използва `revisor`, със стойностите им по подразбиране според [справочника на Dockerfile](https://docs.docker.com/reference/dockerfile/):

| Опция | Какво прави | По подразбиране |
|---|---|---|
| `id` | името, с което `--secret` я предава | името на файла от `target` |
| `target` | къде се появява файлът по време на `RUN` | `/run/secrets/<id>` |
| `required` | ако е `true`, инструкцията се проваля, когато не ѝ подадат тайната | `false` |
| `mode` | права на файла | `0400` |
| `uid`, `gid` | собственик на файла | `0` (`root`) |
| `env` | вместо файл (или в допълнение) слага тайната в променлива на средата, която съществува **само по време на този `RUN`** | без стойност: само файл |

**Внимавай с потребителя по време на изграждането.** Монтирането предава файла със собственик `0` (`root`) и права `0400` по подразбиране. Ако етапът ти на компилиране вече е преминал към потребител без привилегии с `USER`, този потребител няма да може да прочете тайната и `RUN` ще се провали с `permission denied`: това е същият капан с правата от 6.5. Решава се, като се посочи собственикът в монтирането (`uid=` и `gid=`) или като се разхлаби режимът (`mode=0444`, като се има предвид, че тайната съществува само по време на този `RUN`). В Dockerfile от този урок не е нужно, защото етапът, който я използва, работи като `root`.

Внимавай с двете `env`. В `docker build --secret id=x,env=MI_VAR` `env` казва **от коя променлива в терминала ти** се чете тайната. В `--mount=type=secret,id=x,env=TOKEN` казва **с какво име я вижда `RUN`**. Тази втора променлива не е `ENV`: ражда се и умира с инструкцията и не остава нито в образа, нито в историята. Това е начинът, който самата документация използва в правилния пример за правилото `SecretsUsedInArgOrEnv`, и този, който е за предпочитане, когато инструментът чете идентификационните си данни от променлива, а не от файл. „Променливата на средата“ не е лоша сама по себе си; лошото е да остане записана там, където пътува образът, или там, където всеки може да я прочете.

`revisor` използва `target=/root/.netrc`, защото там Go търси идентификационните си данни, и `required=false`, защото този курс няма частни модули: така изграждането му работи и с `--secret`, и без него.

#### 6.6.2 Да я видиш как се появява и изчезва

За да видиш монтирането в действие, е нужен `RUN`, който прави нещо видимо с тайната. Този демонстрационен Dockerfile я получава, брои байтовете ѝ и показва файла, **без да отпечатва стойността**. Използва `required=true`, за да видиш грешката, когато я забравиш:

```dockerfile
# syntax=docker/dockerfile:1
# fig06_07.Dockerfile — Lección 6: dónde vive un secreto de construcción.
# Solo para mirar: un RUN que recibe el secreto, lo cuenta y no lo imprime.
FROM golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c
RUN --mount=type=secret,id=netrc,target=/root/.netrc,required=true \
    echo "durante el RUN: /root/.netrc existe y mide $(wc -c < /root/.netrc) bytes" \
 && ls -l /root/.netrc
```

Скриптът `fig06_08.sh` го изгражда два пъти (без и с тайната), гледа какво е останало и завършва, като изгражда истинския `revisor` с `--secret`:

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

Новите опции в скрипта: `--no-cache` принуждава `RUN` да се изпълни дори при наличен кеш, за да отпечата нещо; `--progress=plain` показва изхода на всяка стъпка като обикновен текст, вместо изгледа, който се прерисува в терминала. Всеки ред от този изход започва с номера на стъпката (`#7`) и секундите от нейното начало; тези числа и датата на файла се променят при всяко изпълнение (датата е по часа на виртуалната машина, който е по Гринуич). `|| true` в края са там, защото `grep -c` излиза с код 1, когато преброи нула, а тук нулата е точно онова, което искаме да видим.

И изходът:

1. **Забравянето на тайната** при `required=true` спира изграждането с кратко съобщение: `secret netrc: not found`. Това искаш, когато тайната е задължителна: ясна грешка при изграждане, а не компилация, която се проваля три стъпки по-късно с „неупълномощен“, който никой не разбира. `revisor` използва `required=false`, защото за него тайната е незадължителна.
2. **С `--secret` `RUN` я вижда**: файл от 37 байта (36 знака на симулираната стойност плюс новия ред), с права `-r--------` (`0400` по подразбиране) и собственик `root`, потребителят, с който работи този `RUN`.
3. **След края на `RUN` я няма.** В `/root` има само файловете на основата. За разлика от `rm` в 6.4, тук никой не трябваше да изтрива нищо: файлът никога не е бил записан в слоя; беше монтиран отгоре, като заем, и беше върнат в края на инструкцията.
4. **Историята записва инструкцията и нищо повече.** Нито стойността, нито дори опциите `--mount`. Броят на редовете със стойността на тайната е `0`.
5. **Истинският `revisor`**, изграден с незадължителната си тайна: също `0`.

Сложи този изход до този от 6.4. С `ARG` стойността остана записана, макар файлът да беше изтрит. С `--secret` стойността така и не беше записана.

#### 6.6.3 Петте пътя, заедно

Вече видя всеки механизъм да работи поотделно. Тази таблица ги събира, защото въпросът, който ще си задаваш в собствения си проект, винаги е един и същ: откъде влиза тази стойност и къде остава записана?

| Механизъм | Кога съществува | Как се предава | Къде остава записан | Става ли за тайни? |
|---|---|---|---|---|
| `ARG` | само при изграждане | `docker build --build-arg` | в историята, на собствения си ред и във всеки следващ `RUN` от етапа (6.4); в атестацията за произход в режим `max` (6.7) | не |
| `ENV` | при изграждане и във всеки контейнер | Dockerfile; сменя се с `-e` | в конфигурацията на образа (`docker image inspect`) | не |
| `-e` / `--env-file` | при стартиране | `docker run` | в конфигурацията на контейнера (`docker inspect`) | не |
| `--mount=type=secret` | само по време на един `RUN` | `docker build --secret` | никъде (6.6.2) | да, при изграждане |
| файл в `/run/secrets/` | при стартиране | монтиране само за четене | `docker inspect` показва пътя, не стойността (6.5) | да, при изпълнение |

Първите три реда са за конфигурация; последните два — за тайни. Ако чувствителна стойност е в който и да е от първите три, тя вече е записана някъде, където друг човек може да я прочете.

#### 6.6.4 Защо не се промъква през кеша

Разумно съмнение: ако тайната се смени, кешът на BuildKit изпълнява ли отново `RUN`? Не. Документацията го казва така: „съдържанието на тайните при изграждане не е част от кеша“ и „смяната на стойността на тайна не обезсилва кеша“; онова, което има значение, са свойствата ѝ, като `id` и пътят на монтирането ([Docker, „Build cache invalidation“](https://docs.docker.com/build/cache/invalidation/)). Документацията не обяснява защо; на практика е важно да знаеш, че стойността не се отчита от кеша, а `id` и пътят на монтирането — да. Ако смениш тайната и имаш нужда `RUN` да се повтори, документацията предлага да подадеш и някакъв аргумент при изграждане, който сменяш едновременно с нея (аргументите обезсилват кеша), или можеш да го принудиш с `--no-cache`, както направи скриптът. Това е малко неудобство в замяна на това стойността да не се появява в никой лог от изграждането.

### 6.7 Какво ще намериш в стари ръководства

- **`ARG` за токени на npm, на GitHub или на частен регистър**, с коментара „не се притеснявай, ще го изтрием в края на `RUN`“. Вече видя в 6.4, че стойността остава в историята. Монтиранията на тайни съществуват, откакто BuildKit ги въведе, и са документираният път.
- **Изграждане в няколко етапа, „за да не стигне `ARG` до крайния образ“.** Вярно е, че историята на предадения образ показва само крайния етап (видя го в 6.2.3), но стойностите може да останат и в **атестациите за произход** (provenance attestations), записа за това как е изграден образът, който Урок 10 прикачва към него. В минималния режим, който се използва по подразбиране, стойностите на аргументите не се включват; с `--provenance=mode=max`, който използва Урок 10, документацията предупреждава, че този режим „разкрива стойностите на аргументите при изграждане“ от всички етапи ([Docker, SLSA provenance](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)). Помага, но не е решението.
- **`docker run -e PASSWORD=...` в инструкциите на някой образ.** Много популярни образи приемат тайни чрез променлива, защото така е най-лесно за документиране, а много предлагат и вариант `_FILE`, който чете от файл, като `REVISOR_TOKEN_ARCHIVO` на `revisor`. Когато съществува вариантът с файл, използвай него.
- **„Сплескване“ на слоевете, за да изчезнат тайните.** Някои стари ръководства предлагат всички слоеве да се обединят в един. Дори това да махне файл от междинен слой, то не пипа конфигурацията на образа: `ENV` с токен остава там, както видя в 6.4. Сегашният път е тайната никога да не влиза.

## Грешката, която ще видиш

Този урок има една основна грешка и две второстепенни. И трите вече се появиха.

**Основната грешка: файлът с тайната, който контейнерът не може да прочете.** Това е грешката от `fig06_06.sh`:

```text
600 secretos/revisor_token.txt
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
[código de salida: 1]
```

Чете се отдясно наляво. `permission denied` го казва ядрото: процесът няма право да отвори този файл. `open /run/secrets/revisor_token` казва кой файл, с пътя **вътре** в контейнера; пътят на компютъра е този на монтирането. А `leyendo el token de REVISOR_TOKEN_ARCHIVO` го добавя `revisor`, за да знаеш какво е правел. Въпросът, който я решава, е „кой е собственикът на файла и с какъв потребител работи контейнерът?“. Първия отговор дава `ls -ln` на компютъра ти; втория — `docker inspect --format '{{.Config.User}}'` върху образа (`65532:65532`). Ако не съвпадат и правата са `600`, това е резултатът. Решения: правилната група или правилният собственик, които позволяват на `revisor` да чете, а на никой друг (6.5.4); `644` също работи, но е приемливо само със симулиран токен. Което не е решение: да работиш като `root`.

**Второстепенната грешка: тайната при изграждане, която не е пристигнала.**

```text
ERROR: failed to build: failed to solve: secret netrc: not found
```

Виждаш я, когато Dockerfile иска тайна с `required=true`, а `docker build` не съдържа `--secret id=netrc,...`. Решението е да я добавиш. Ако си написал `--secret`, но с друг `id` (например `id=nettrc`), си в същия случай: `RUN` е поискал тайната `netrc` и никой не му я е дал, така че провери дали двата `id` съвпадат буква по буква. С `required=false`, както при `revisor`, грешка няма: `RUN` се изпълнява без файла.

**Предупреждението, което трябва да третираш като грешка: `SecretsUsedInArgOrEnv`.**

```text
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ARG "TOKEN_MODULOS")
```

Това е предупреждение, а не грешка: нормален `docker build` го отпечатва и изгражда въпреки това. Затова е лесно да се пренебрегне. С `docker build --check` резултатът е код 1 и така е добре да се изпълнява: преди всяко изграждане, което ще се публикува. Помни, че гледа само имената: липсата на предупреждение не доказва, че няма тайни.

## Навикът за сигурност от урока

**Тайните не минават през `ARG`, нито през `ENV`, а с `docker history` и `docker inspect` се проверява, че не са останали.** Навикът има две половини и втората е тази, която се забравя. Първата е правилото: тайната при изграждане влиза с `--secret`, тази при изпълнение — като файл само за четене в `/run/secrets/`. Втората е проверката: преди да публикуваш образ, търсиш в пълната му история и в конфигурацията му с двете команди от 6.4.3 и не намираш нищо. Този навик предотвратява инцидента от сцената в началото (токен, публикуван в регистър, до който имат достъп повече хора, отколкото си мислиш) и още един, по-тих: токен, подаден с `-e`, който се озовава в лог с грешки, на споделения екран по време на видеоразговор или в изхода на `docker inspect`, който някой е поставил в чат, за да поиска помощ.

## Често срещани грешки

**Повторно изграждане на образа, за да смениш средата.** Ако продукционният образ е различен от тестовия, продукционния никой не го е тествал. Един образ, много конфигурации.

**Слагане на конфигурацията на дадена среда в `ENV` на Dockerfile.** `ENV` е за стойности по подразбиране, които стават навсякъде, като порта. Списък с тестови услуги в `ENV` те принуждава да изграждаш наново за продукция и остава в образа завинаги.

**Подаване на тайна чрез `ARG` и изтриването ѝ „в същия `RUN`“.** Файлът изчезва; стойността остава в историята (6.4). Предпазливостта да го направиш в един `RUN` защитава от грешка, различна от тази, която наистина се случва.

**Подаване на токена с `-e`, защото „вече не е в образа“.** Вече не пътува до регистъра, но остава в конфигурацията на контейнера, пред очите на всеки с достъп до `docker`, и в средата на всички дъщерни процеси.

**Поправяне на `permission denied` с `--user root` или `chmod 777`.** Първото разваля подсилването на защитата (hardening) на образа; второто прави файла записваем за всички на компютъра. Проблемът е в собственика; поправи го там.

**Пазене на папката с тайни в хранилището.** Този курс го прави нарочно и със симулирани стойности. Твоят проект — не: `secretos/` отива в `.gitignore` и в `.dockerignore` от първия ден.

**Да се довериш, че `docker build --check` не е казал нищо.** Проверява имена, не стойности. Променлива `X` с токен вътре минава чисто.

**Копиране на монтираната тайна на друг път.** Монтирането не оставя следа, но онова, което `RUN` запише, остава: ако `cp /run/secrets/…` или някой инструмент запази идентификационните данни в собствената си конфигурация (`.npmrc`, файл с идентификационни данни), това копие остава в слоя като всеки друг файл. Тайната се чете в `RUN` и не се записва никъде.

**Отпечатване на тайна „само за отстраняване на грешки“.** `RUN cat /run/secrets/...` или `echo $TOKEN` оставя стойността в изхода от изграждането или в логовете на контейнера, които се пазят и споделят. За да разбереш дали тайната е пристигнала, преброй байтовете ѝ, както направи `fig06_07.Dockerfile`.

## Упражнения

Прави ги поред. Преди да изпълниш всяко, запиши в [дневника](bitacora.md) какво мислиш, че ще стане; сравнението после е половината от ученето. Накрая изтрий онова, което си създал: всичко носи префикса `curso-docker-`.

### Упражнение 1 — Код, конфигурация или тайна?

Класифицирай всяка стойност в една от трите кутии от 6.1.1 и кажи къде трябва да живее (вътре в образа, в `ENV` като стойност по подразбиране, чрез `-e`/`--env-file` или като файл в `/run/secrets/`):

1. Версията `1.3.0` на `revisor`.
2. Списъкът с услуги, които проверява тестовата среда.
3. Токенът, който защитава `/api/estados` в продукция.
4. Портът `8080`.
5. Пътят, където `revisor` пази отчета си (`REVISOR_REPORTE`).
6. Идентификационни данни за изтегляне на частни модули на Go при компилиране.

### Упражнение 2 — Без `--build-arg` (проект)

В папката си `~/curso-docker/revisor`, с Dockerfile на този урок, изгради образ **без** `--build-arg` и с тага `curso-docker-revisor:sin-version`. Преди да изграждаш, предскажи какво ще кажат тези три неща, а после го провери:

1. `docker run --rm curso-docker-revisor:sin-version version`
2. Етикетът `org.opencontainers.image.version` на образа.
3. Редът `ARG` в неговия `docker history`.

Упражнението се самопроверява: ако трите ти предсказания съвпаднат с онова, което виждаш, си разбрал откъде идва стойността на един `ARG`. Накрая — `docker rmi curso-docker-revisor:sin-version`.

### Упражнение 3 — Кавичките във файла с променливи

Създай файл `comillas.env` с този единствен ред, включително кавичките:

```text
REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"
```

Преди да го изпълниш, предскажи: `revisor` стартира ли, или отказва? Ако стартира, какво ще покаже таблицата му? После го изпълни с `docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --env-file comillas.env curso-docker-revisor:1.3.0`, поискай таблицата с `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'` и прочети с `docker inspect` каква точно стойност е получил. Поправи файла, така че услугата да излезе `OK`. Накрая — `docker rm -f curso-docker-revisor`.

### Упражнение 4 — Намери изтичането

Колега ти дава тази рецепта и се кълне, че „не оставя нищо, защото тайната се изтрива“. Без да я изграждаш, кажи **къде** би останала всяка от двете чувствителни стойности и с каква команда би я намерил. После пренапиши частта с тайната при изграждане с монтиране на тайна и кажи коя опция на `docker build` я предава:

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.27.3-trixie
ARG CLAVE_REGISTRO
ENV API_KEY=valor-de-mentira-para-el-ejercicio
RUN echo "${CLAVE_REGISTRO}" > /tmp/clave && go env -w GOPRIVATE=ejemplo.invalid && rm /tmp/clave
```

Допълнителен въпрос: коя от двете променливи би отбелязал `docker build --check` и коя — не? Помисли как решава правилото.

## Решения

### Решение 1

1. **Код.** Вътре в образа: записана в двоичния файл с `-X main.version` и в OCI етикета. Не се променя между средите.
2. **Конфигурация.** Чрез `-e` или `--env-file` при стартиране. Променя се между средите и не е тайна.
3. **Тайна.** Като файл само за четене в `/run/secrets/revisor_token`, с `REVISOR_TOKEN_ARCHIVO`, сочеща към него. Никога в `ENV`, нито чрез `-e`.
4. **Конфигурация със стойност по подразбиране.** `ENV REVISOR_PUERTO=8080` в образа; всяка среда го сменя с `-e`.
5. **Конфигурация.** Чрез `-e` или `--env-file`. (Урок 8 ѝ дава стойност по подразбиране вътре в образа, когато има папка `/datos`, подготвена за това.)
6. **Тайна при изграждане.** С `--mount=type=secret` в `RUN`, който има нужда от нея, предадена с `docker build --secret`. Никога в `ARG`.

### Решение 2

Измерено със същия компютър и същата версия на Docker като в урока:

1. `desarrollo`. Без `--build-arg` `VERSION` взема стойността по подразбиране от декларацията си, `ARG VERSION=desarrollo`, и тъкмо нея `-X main.version` записва в двоичния файл.
2. Също `desarrollo`, защото етапът `final` декларира свой собствен `ARG VERSION=desarrollo` и етикетът го използва.
3. `ARG VERSION=desarrollo`. Историята записва стойността, която аргументът е имал **при това изграждане**, независимо дали е от `--build-arg`, или от декларацията. Точно затова тайна не може да отиде там.

### Решение 3

Измерено със същия компютър и същата версия на Docker като в урока. `revisor` **стартира** (`revisor 1.3.0 escuchando en :8080 (1 servicio(s))`), но таблицата казва:

```text
SERVICIO  ESTADO    TIEMPO  DETALLE
"propio   FALLA        1ms  codigo 404
```

Времето се променя при всяко изпълнение. Кавичките са пристигнали като част от стойността: `docker inspect` показва `REVISOR_SERVICIOS="propio http://127.0.0.1:8080/salud"`. `revisor` е прочел услуга с име `"propio` (с кавичката) и с адрес `http://127.0.0.1:8080/salud"` (с кавичката накрая); този път не съществува и сървърът отговаря с `404`. Това е най-лошият вид грешка в конфигурацията: не пречи на стартирането, а само дава грешен резултат. Решението е да махнеш кавичките: във файл за `--env-file` всичко след `=` е стойността, такава, каквато е. (В терминала кавички се слагат, защото там ги интерпретира *shell*-ът и те не стигат до контейнера. А в `env_file` на Compose, Урок 9, също могат да се използват, защото този четец ги маха.)

### Решение 4

- `CLAVE_REGISTRO` остава **в историята**, на реда на `RUN`, във вида `|1 CLAVE_REGISTRO=<стойност> /bin/sh -c ...`. Намира се с `docker history --no-trunc --format '{{.CreatedBy}}' <образ>`. `rm /tmp/clave` не го предотвратява, точно както в 6.4.
- `API_KEY` остава **в конфигурацията на образа** и в средата на всеки контейнер. Намира се с `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' <образ>`.

Пренаписването на тайната при изграждане:

```dockerfile
RUN --mount=type=secret,id=clave_registro,target=/root/.netrc,required=true \
    go env -w GOPRIVATE=ejemplo.invalid && go mod download
```

Тук тайната се **използва**: `go mod download` изтегля частните модули и, за да влезе в сървъра, чете идентификационните данни от `/root/.netrc`, който съществува само по време на този `RUN` (файлът с тайната би съдържал реда `machine ejemplo.invalid password …`, както в 6.4). Ако инструментът, от който имаш нужда, чете идентификационните си данни от променлива, а не от файл, сменяш `target=…` с `env=CLAVE_REGISTRO` и променливата съществува само по време на този `RUN` (6.6.1). Предава се с `docker build --secret id=clave_registro,src=<файл> .` (или `env=<ПРОМЕНЛИВА>` от терминала ти). Без `ARG`, без файл за изтриване и без нито един ред в историята със стойността. А `API_KEY` излиза от Dockerfile: ако програмата има нужда от нея при изпълнение, пристига като файл.

Допълнителен въпрос: правилото решава по **името** на променливата. Измерено със същия компютър и същата версия на Docker като в урока, `docker build --check .` върху рецептата излиза с код 1 и едно-единствено предупреждение:

```text
Check complete, 1 warning has been found!
WARNING: SecretsUsedInArgOrEnv - https://docs.docker.com/go/dockerfile/rule/secrets-used-in-arg-or-env/
Do not use ARG or ENV instructions for sensitive data (ENV "API_KEY")
```

`API_KEY` има такова име, каквото правилото търси. `CLAVE_REGISTRO`, на испански, минава без предупреждение, а това е точно стойността, която се озовава в историята. Поуката, която има значение: предупреждението е мрежа, а не катинар.

## Как да разбера, че съм успял

Отбележи всяка точка само ако можеш да го направиш, **без да поглеждаш отново текста**:

- [ ] В твоята папка `docker run --rm curso-docker-revisor:1.3.0 version` отпечатва `1.3.0`, а `docker image inspect` показва етикета `org.opencontainers.image.version = 1.3.0`.
- [ ] `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.3.0` показва `REVISOR_PUERTO=8080` и никоя друга променлива `REVISOR_*`.
- [ ] Стартираш един и същ образ с два различни списъка с услуги, единия чрез `-e`, а другия чрез `--env-file`, без повторно изграждане.
- [ ] Обясняваш за една минута разликата между `ARG` и `ENV`, като използваш думите *изграждане*, *изпълнение*, *история* и *конфигурация*.
- [ ] Изграждаш `Dockerfile.malo` и намираш двете симулирани тайни с две команди; а `docker build --check -f Dockerfile.malo .` ти дава двете предупреждения и код 1.
- [ ] `revisor` стартира с `REVISOR_TOKEN_ARCHIVO` и файл, монтиран само за четене; `/api/estados` отговаря с `401` без токен и с таблицата с токен; а `docker inspect` на контейнера не показва стойността на токена.
- [ ] Предизвикваш `permission denied` с `chmod 600` и обясняваш защо се случва, като използваш думите *собственик* и `65532`.
- [ ] `docker history --no-trunc --format '{{.CreatedBy}}' curso-docker-revisor:1.3.0 | grep -c 'modulos-de-mentira'` дава `0` след изграждане с `--secret`.
- [ ] Изпълняваш скриптовете от [`programas/06-configuracion-y-secretos/`](../programas/06-configuracion-y-secretos) и изходите ти съвпадат с тези от урока, с изключение на времената, номерата на стъпките при изграждане, датата на файла от `fig06_08.sh`, реда на променливите в `docker inspect` и архитектурата в историята. А накрая `docker ps -a --filter name=curso-docker-` не показва контейнери от този урок.

## Обобщение

Отговори, без да поглеждаш урока:

1. Какво е конфигурация според *The Twelve-Factor App* и какъв тест предлага, за да разбереш дали си я отделил добре?
2. Кога съществува един `ARG` и кога един `ENV`? Къде остава записана стойността на всеки от тях?
3. Защо Dockerfile на `revisor` декларира `ARG VERSION` два пъти?
4. Каква е разликата между `-e` и `--env-file` и какво става с кавичките във файл с променливи?
5. Защо изтриването на файл в същия `RUN` не защитава тайна, пристигнала чрез `ARG`?
6. Какво проверява `docker build --check` с правилото `SecretsUsedInArgOrEnv` и какво не може да види?
7. Защо токен чрез `-e` продължава да е лоша идея, макар да не е в образа?
8. Защо файл с тайна с права `600` дава `permission denied` вътре в контейнера и кои са добрите решения?
9. Какво прави `--mount=type=secret`, къде се появява файлът по подразбиране и какво означава `required`?

## Източници

Всички са прегледани на 21 октомври 2026 г.

- [The Twelve-Factor App, „Config“](https://12factor.net/config): определението за конфигурация като онова, което се различава между разгръщанията, тестът с публикуването на кода като отворен и конфигурацията в променливи на средата.
- [Docker, „Build variables“](https://docs.docker.com/build/building/variables/): `ARG` срещу `ENV`, това, че аргументите не стигат до контейнерите, но могат да се запазят в метаданните, историята и атестациите, обхватът по етапи и предупреждението за тайните.
- [Docker, „Build secrets“](https://docs.docker.com/build/building/secrets/): защо аргументите и променливите на средата не са подходящи за тайни, монтирането на тайна, пътят му по подразбиране `/run/secrets/<id>`, `target` и формите `src` и `env` на `--secret`.
- [Справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/): опциите на `RUN --mount=type=secret` (`id`, `target`, `required`, `mode`) и стойностите им по подразбиране, `LABEL` и четенето му с `docker image inspect`, и това, че `ENV` се запазва в контейнерите и се сменя с `docker run --env`.
- [Docker, „Build cache invalidation“](https://docs.docker.com/build/cache/invalidation/): това, че съдържанието на тайна не е част от кеша, и как да се принуди стъпката да се повтори.
- [Справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/): това, че при файл като източник атрибутите `uid`, `gid` и `mode` на тайна се пренебрегват, и как `env_file` чете кавичките.
- [Docker, SLSA provenance](https://docs.docker.com/build/metadata/attestations/slsa-provenance/): това, че минималният режим, този по подразбиране, не включва стойностите на аргументите, а режимът `max` ги разкрива.
- [Docker, „Build checks“](https://docs.docker.com/build/checks/): директивата `# check=error=true`.
- [Docker, правило `SecretsUsedInArgOrEnv`](https://docs.docker.com/reference/build-checks/secrets-used-in-arg-or-env/): какво отчита правилото и правилният пример с монтирания на тайни.
- [Справочник на `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `-e`, `-e` без стойност и форматът на `--env-file` с коментарите му.
- [Docker, „Secrets in Compose“](https://docs.docker.com/compose/how-tos/use-secrets/): защо променливите на средата не са добро място за тайни и пътят `/run/secrets/<име>`.
- [OCI Image Specification, анотации](https://github.com/opencontainers/image-spec/blob/main/annotations.md): определенията на `org.opencontainers.image.title`, `.version` и `.source`.
- [cmd/link](https://pkg.go.dev/cmd/link): опцията `-X` на линкера на Go, която задава стойността на текстова променлива при компилиране.
- [Docker Engine 29, бележки към версиите](https://docs.docker.com/engine/release-notes/29/): версиите и датите от „За изпълненията“.
- [Colima](https://github.com/abiosoft/colima): инструментът, с който програмите бяха изпълнени под macOS.

### Термини от този урок

| | |
|---|---|
| **аргумент при изграждане** (`ARG`) | променлива, която съществува само докато се изгражда образът; сменя се с `--build-arg`, а стойността ѝ остава в историята |
| **конфигурация** | това, което се променя от една среда в друга; пристига при стартиране, не е в образа |
| **етикет** (*label*) | двойка име–стойност, закачена към образа като метаданни; чете се с `docker image inspect` |
| **OCI етикети** | етикети със стандартни имена (`org.opencontainers.image.*`), които всеки инструмент разбира |
| **история** (*history*) | списъкът с инструкциите, създали образа, със стойностите им; чете се с `docker history` |
| **монтиране на тайна** (*secret mount*) | файл, който BuildKit предоставя на един-единствен `RUN` и който не остава в никой слой |
| **тайна** | конфигурация, която, ако изтече, някой може да използва срещу теб: токени, пароли, идентификационни данни |
| **тайна при изграждане** | тази, която е нужна за изграждането на образа; предава се с `docker build --secret` |
| **тайна при изпълнение** | тази, от която програмата има нужда при работа; предава се като файл в `/run/secrets/` |
| **променлива на средата** (`ENV`, `-e`) | двойка име–стойност, която процесът получава при стартиране; видима е в `docker inspect` |

---

**Следващ:** [Урок 7 — Проверка на състоянието и жизнен цикъл](07-salud-y-ciclo-de-vida.md)
