# Урок 5 — Multi-stage: от гигабайти до мегабайти

7:50 сутринта е, а клонът отваря в 9. `revisor` трябва да е инсталиран преди този час на сървъра в комуникационното помещение, който се свързва с останалия свят през скромна връзка. Пускаш изтеглянето на образа и лентата напредва капка по капка: образът тежи 1.32 GB. Докато чакаш, пристига съобщение от човека по сигурността, който преглежда всяка инсталация: „Преди да го стартираш, ще ми обясниш ли защо този образ включва `gcc`, `git`, `curl`, `apt-get` и *shell*? `revisor` е една-единствена програма. Ако някой успее да влезе в този контейнер, му оставяш цяла работилница: с какво да изтегли инструменти, с какво да ги компилира и с какво да ги изпълни“. Имаш четирийсет минути и два проблема, които изглеждат различни: образът е огромен и образът е опасен. Този урок те учи, че това е един и същ проблем и че се решава с един-единствен, по-добре написан Dockerfile: образът, който излиза оттук, тежи 16.1 MB, няма *shell* и не работи като `root`.

**Време:** 2 × 45 мин

**Какво изграждаш:** крайния образ на `revisor`, `curso-docker-revisor:1.2.0`: Dockerfile от четири етапа, който компилира и тества в голям образ и предава в минимален, с основа, фиксирана по версия и по *digest*. Тежи 16.1 MB, няма *shell*, нито компилатор, и работи с непривилегирования потребител 65532.

**Какво научаваш:** какво е изграждане в няколко етапа (*multi-stage*) и как се прехвърлят файлове от един етап в друг с `COPY --from`; как да сложиш тестовете вътре в изграждането, така че счупен тест да го спре, и мълчаливата грешка, която ги прескача; какво е минимален базов образ без *shell* (*distroless*) и какво се променя при работата с него; какво е *digest* и защо основата се фиксира с него освен с тага; и защо двоичен файл, който не е статичен, не стартира в минимален образ, с точното съобщение, което ще видиш.

**Откъде идваш.** От [Урок 4](04-capas-cache-contexto.md) носиш образа `curso-docker-revisor:1.1.0`: същият `revisor` от Урок 3, но с Dockerfile, подреден заради кеша (първо `go.mod`, после кодът), и с кеша за компилация на Go в монтиране, което не остава вътре в образа. Умееш да разчиташ `docker history`, знаеш какво е слой и какво пътува в контекста. Носиш и едно число, записано в дневника ти: този образ тежи **1.32 GB**. От [Урок 3](03-primer-dockerfile.md) носиш `USER`, формата *exec* и папката `~/curso-docker/revisor`, където живее проектът ти. А от [Урок 2](02-contenedores-dia-a-dia.md) носиш един спомен: опита да влезеш с `docker exec` в тестовата услуга и нямаше `sh`. Тук ще разбереш защо и ще направиш същото с `revisor`.

**Какво не прави този урок.** Не пипа кода на `revisor` и не му добавя функции: програмата е същата като в Уроци 3 и 4. Не дава версия на двоичния файл (затова `revisor version` все още казва `desarrollo`; версията и конфигурацията са в [Урок 6](06-configuracion-y-secretos.md)). Не му добавя `HEALTHCHECK` и не подсилва защитата му при изпълнение (файлова система само за четене, премахнати capabilities): това е Урок 7. И не изгражда за няколко платформи, нито сканира за уязвимости: това е Урок 10. Тук задачата е една-единствена: това, което се **предава**, да бъде само онова, което е **нужно, за да работи**.

**За изпълненията.** Всички изходи са реални и са получени на 21 октомври 2026 г. на Mac с [Colima](https://github.com/abiosoft/colima), която стартира виртуална машина с Ubuntu 24.04.4, същата основа като Linux Mint 22, референтната система на курса. Скриптовете бяха изпълнени **вътре** в тази виртуална машина, с Docker 29.2.1 (клиент и демон) и Buildx v0.31.1. Курсът беше планиран с Docker Engine 29.8.2, а най-новата публикувана версия в този ден беше 29.9.2, от 20 октомври 2026 г. ([бележки към версиите](https://docs.docker.com/engine/release-notes/29/)); нищо от този урок не се променя между тези версии. Същата машина се използваше по същото време и от други изпълнения на курса, така че, за да не се сблъскват, всеки скрипт беше пуснат с друг префикс за имената и друг порт, чрез променливите `PREFIJO` и `PUERTO`, които всички имат, а изходът беше записан, минавайки през `sed`, който връща имената на курса. Командата за всяка фигура беше: `PREFIJO=curso-docker-l05- PUERTO=18050 ./fig05_NN.sh 2>&1 | sed -e 's/curso-docker-l05-/curso-docker-/g' -e 's/127\.0\.0\.1:18050/127.0.0.1:8080/g'`. На теб нищо от това не ти трябва: без променливи скриптовете използват имената и порта на курса, и това, което отпечатват, е онова, което виждаш тук. Което **се** променя в твоя Mint и се отбелязва там, където се появява: номерата на процесите (PID), времената, датите на файловете и, ако компютърът ти е с Intel или AMD, архитектурата: където тук пише `arm64` или `aarch64`, при теб ще пише `amd64` или `x86_64`, а размерите може да се различават с няколко мегабайта. Програмите са в [`programas/05-multi-stage/`](../programas/05-multi-stage), всяка с изхода си до нея; `inicio/` пази `Dockerfile` и `.dockerignore`, с които завършва Урок 4, а `estado/` — тези, които остават в края на този урок.

## След урока ще можеш да

- Да обясниш с числата на собствения си образ защо образ с един етап тежи повече от гигабайт, когато програмата в него тежи по-малко от десет мегабайта.
- Да напишеш Dockerfile с няколко именувани етапа (`FROM ... AS`), да прехвърлиш файл от един етап в друг с `COPY --from` и да изградиш само до определен етап с `--target`.
- Да сложиш тестовете вътре в изграждането така, че счупен тест да го спре, и да покажеш с изпълнение защо етапът на двоичния файл трябва да излиза от етапа на тестовете, а не от този на компилирането.
- Да покажеш с `docker exec`, `docker inspect` и `docker top`, че крайният образ няма *shell* и не работи като `root`, и да изброиш всичките му файлове, без да влизаш в него.
- Да фиксираш базов образ по таг и по *digest* и да кажеш какво осигурява всеки от тях.
- Да разчетеш съобщението `exec /revisor: no such file or directory`, да обясниш кой файл е този, който липсва, и да го поправиш с `CGO_ENABLED=0`.

## Защо, преди как

В Урок 3 изгради `revisor` в един-единствен етап: тръгна от образа на Go, копира кода, компилира и каза на Docker какво да изпълни. Работи, и това беше правилният начин да се започне, защото всичко беше пред очите ти. Но тази рецепта има дизайнерски дефект, който никакво пренареждане не поправя: **образът, който служи за изграждане, и образът, който се предава, са един и същ**. Всичко, което беше нужно за компилирането — компилаторът на Go, този на C, цял Debian с пакетния му мениджър, мрежовите инструменти —, остава в образа, който отива на сървъра, макар `revisor` да не използва нищо от това при работа.

Това струва на три места едновременно, а сцената от началото ги събира:

1. **Във време и диск.** Всеки сървър, на който работи `revisor`, изтегля и съхранява повече от гигабайт. При бавна връзка това е разликата между това да успееш или не до 9.
2. **В сигурност.** Всяка програма, която пътува в образа, е нещо, което натрапник може да използва. Контейнер с *shell*, `curl` и компилатор спестява на влезлия почти цялата работа. Контейнер, който има само `revisor`, не му оставя нищо, с което да продължи.
3. **В шум.** Скенерът за уязвимости проверява всички пакети в образа. Ако образът съдържа двеста пакета на Debian, които `revisor` никога не пипа, отчетът се пълни с находки, които нямат значение, и скрива тези, които имат. Самият проект за минимални образи на Google го казва така: образ без излишното „подобрява съотношението сигнал/шум на скенерите“ ([distroless](https://github.com/GoogleContainerTools/distroless)).

Решението, което ще изградиш, разделя двете задачи: голям образ за **изграждане и тестване**, който никога не напуска твоя компютър, и минимален образ за **изпълнение**, който е този, който се предава. Двата се описват в един и същ Dockerfile, а преходът от единия към другия е един-единствен ред: копирането на двоичния файл. Документацията на Docker го обобщава в едно изречение: с изгражданията в няколко етапа „можеш избирателно да копираш артефакти от един етап в друг, оставяйки зад себе си всичко, което не искаш в крайния образ“ ([Docker, „Multi-stage builds“](https://docs.docker.com/build/building/multi-stage/)).

Урокът има осем части, в този ред:

1. **Какво има вътре в 1.32 GB** (5.1): мерене преди смаляване.
2. **Идеята за етапите** (5.2): `FROM ... AS`, `COPY --from` и `--target`.
3. **Dockerfile от четири етапа** (5.3), ред по ред.
4. **Изграждане и мерене** (5.4): от 1.32 GB до 16.1 MB.
5. **Тестовете вътре в изграждането** (5.5), с мълчаливата грешка на този урок.
6. **Минималната основа** (5.6): без *shell* и без `root`.
7. **Версия и *digest*** (5.7): истинско фиксиране на основата.
8. **Двоичният файл, който не стартира** (5.8), основната грешка на урока.

С тази цел пред очи, ето какво ще видиш в раздел 5.4, когато поставиш един до друг образа, с който пристигаш, и този, който изграждаш тук:

```text
curso-docker-revisor:1.1.0 1.32GB
curso-docker-revisor:1.2.0 16.1MB
```

## Понятията

### 5.1 Какво има вътре в 1.32 GB

#### 5.1.1 Мерене преди смаляване

Преди да промениш дори един ред, е добре да знаеш какво има в образа и каква част от тази тежест е `revisor`. Смаляването без мерене е гадаене. Програмата `fig05_01.sh` изгражда образа от Урок 4 от `inicio/` и му задава три въпроса: колко тежи `revisor`, кои други инструменти пътуват с него и колко заемат най-тежките папки:

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

Преди изхода — новите редове в скрипта. Структурата е същата като в скриптовете от Урок 3: проектът се сглобява във временна папка (`mktemp -d`) с кода, който курсът предоставя, плюс файловете на урока, дефинират се помощните функции `titulo` и `muestra` (която отпечатва всяка команда с `$ ` отпред, преди да я изпълни, за да знаеш какво е произвело всеки ред), а един `trap ... EXIT` изтрива образа и папката при излизане. `sed` в началото сменя името на кеша за компилация само ако смениш `PREFIJO`; със стойността по подразбиране не променя нищо. `MIRAR` е съкращение, за да не се повтаря `docker run --rm --name ... imagen` при всеки въпрос.

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

Датата и часът на файла се променят при всяко изграждане; на компютър с Intel или AMD размерите може да се различават с няколко мегабайта. Останалото излиза същото.

#### 5.1.2 Разчитане на числата

Сложи числата в едно-единствено изречение и проблемът се вижда сам: **`revisor` тежи около 10 MB и пътува в образ от 1.32 GB**. По-малко от един процент от това, което се изтегля, е програмата, която ще изпълниш. Останалите 99 % са багаж:

- **Компилаторът на Go**, в `/usr/local/go`: 277 MB. (`ls -lh` и `du -sh` броят в степени на 1024: `9.5M` на `revisor` са 9.5 MiB, около 10 MB; `docker image ls` брои в степени на 1000.) Той беше нужен за компилирането; при работа `revisor` не го използва нито веднъж.
- **Почти пълен Debian**: 208 инсталирани пакета (`dpkg-query -W` изброява по един на ред, а `wc -l` ги брои), с библиотеките им в `/usr/lib` и програмите им в `/usr/bin`.
- **Инструментите, които тревожеха човека по сигурността от сцената**: *shell* (`sh` и `bash`), пакетен мениджър (`apt-get`), компилатор за C (`gcc`), `git` и `curl`. Всеки от тях е там по добра причина за **изграждането**: официалният образ на Go ги включва, за да може компилирането да работи с почти всеки проект. За **изпълнението** на `revisor` — нито един.

Последният ред е добро напомняне, че Урок 3 не беше напразно: образът работи с потребителя `10001`, а не с `root`. Но този потребител има подръка `curl`, за да изтегли каквото поиска, и `sh`, за да го изпълни. Без привилегии — да; обезоръжен — не.

Обърни внимание и на това, което **не** е в списъка: нищо от това не се поправя чрез изтриване на файлове. Ако добавиш в Dockerfile `RUN rm -rf /usr/local/go`, образът няма да олекне нито с байт: Урок 4 те научи, че всяка инструкция добавя слой върху предишните и че това, което един слой изтрива, остава запазено в слоя отдолу. Изтриването в нов слой само скрива. За да не пътува компилаторът, крайният образ трябва да се **роди без него**.

> [!NOTE]
> 🔧 **Наблюдение от инженерството 5.1**
> Мери, преди да оптимизираш, и мери съотношението, а не само общото. „Образът тежи 1.32 GB“ подканва да търсиш къде да режеш. „Програмата е под 1 % от образа“ ти казва, че няма какво да режеш: трябва да смениш образа.

### 5.2 Идеята за етапите

#### 5.2.1 Няколко `FROM` в един Dockerfile

Досега всеки Dockerfile имаше един-единствен `FROM` и всичко след него се трупаше върху тази основа. Централната идея на този урок е, че **един Dockerfile може да има няколко `FROM`**. Всеки `FROM` започва нов **етап** от нулата, със собствена основа. Справочникът на Dockerfile го казва така: `FROM` „може да се появи няколко пъти в един Dockerfile“, за да се създадат няколко образа или за да се използва един етап като зависимост на друг ([справочник на Dockerfile, `FROM`](https://docs.docker.com/reference/dockerfile/#from)).

Това, което прави тази идея полезна, са три части, които ще видиш във фрагмент от четири реда преди пълния Dockerfile:

```dockerfile
FROM golang:1.27.3-trixie AS compilacion
RUN ... go build -o /out/revisor ./cmd/revisor

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=compilacion /out/revisor /revisor
```

Този блок е фрагмент за четене, а не програма: липсват му редове, за да бъде изграден. Какво показва:

1. **Името на етапа.** `AS compilacion` в края на `FROM` дава име на етапа. Документацията препоръчва етапите да се именуват така, вместо да се сочат по номер ([Docker, „Name your build stages“](https://docs.docker.com/build/building/multi-stage/#name-your-build-stages)). Името оцелява, когато някой добави или махне етапи; номерът — не.
2. **Копирането между етапи.** `COPY --from=compilacion` копира файл **от друг етап**, а не от контекста. Справочникът уточнява, че `--from` приема етап, образ или именуван контекст ([справочник, `COPY --from`](https://docs.docker.com/reference/dockerfile/#copy---from)). Тук етапът на компилиране оставя двоичния файл в `/out/revisor`, а последният етап го взема.
3. **Образът, който излиза.** Образът, който изгражда `docker build`, е този на **последния** етап. Всичко, което се е случило в предишните — компилаторът, изходният код, кешът —, остава зад гърба. Това е изречението от документацията: копирай това, което искаш, и остави зад себе си това, което не искаш.

Ако идваш от програмирането, едно сравнение помага: етапът е като функция, която връща стойност. Етапът на компилиране „връща“ файл; крайният етап получава само този файл, а не локалните променливи, с които е изчислен.

#### 5.2.2 Изграждане до определен етап: `--target`

Вторият инструмент е възможността да изградиш **само до** определен етап. `docker build --target pruebas` изгражда етапа с име `pruebas` (и тези, от които той се нуждае) и спира там; полученият образ е този на този етап, а не крайният ([Docker, „Stop at a specific build stage“](https://docs.docker.com/build/building/multi-stage/#stop-at-a-specific-build-stage); в справочника на командния ред `--target` е „етапът на изграждане, който да се изгради“, [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)). Служи за две неща, които ще използваш в този урок: да пуснеш само тестовете и да погледнеш отвътре междинен етап, който има инструменти.

#### 5.2.3 Какво изгражда BuildKit и какво не

Третата част е най-малко известната и тази, която носи най-много изненади. Изграждащият инструмент на Docker, BuildKit, не изгражда всички етапи на файла по ред: **изгражда само етапите, от които зависи поисканият етап**. Документацията го казва без заобикалки: „BuildKit изгражда само етапите, от които зависи целевият етап“ ([Docker, „Differences between legacy builder and BuildKit“](https://docs.docker.com/build/building/multi-stage/#differences-between-legacy-builder-and-buildkit)). Етап, от който никой не се нуждае, не се изпълнява.

Това е предимство (не се губи време за ненужното) и капан, който ще предизвикаш в 5.5: ако тестовете живеят в етап, от който крайният образ не зависи, BuildKit не ги пуска и изграждането излиза зелено със счупен тест вътре. Запомни това изречение; то е ключът към мълчаливата грешка на този урок.

### 5.3 Dockerfile от четири етапа, ред по ред

#### 5.3.1 Пълната рецепта

Това е Dockerfile, с който завършва урокът. Той заменя този от Урок 4 в папката ти, а `.dockerignore` не се променя:

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

Това са четири свързани етапа и всеки има една-единствена задача:

| Етап | Тръгва от | Задачата му | Пътува ли в крайния образ? |
|---|---|---|---|
| `compilacion` | официалния образ на Go | да подготви кода за компилиране | не |
| `pruebas` | `compilacion` | да изпълни `go test ./...` | не |
| `binario` | `pruebas` | да произведе `/out/revisor`, статичен | само този файл |
| `final` | *distroless* `static`, без *shell* | да изпълнява `revisor` | той е крайният образ |

Имената на етапите са тези на курса и се повтарят в следващите уроци: `compilacion`, `pruebas`, `binario` и `final`. Те са без ударение нарочно, защото са идентификатори, които ще пишеш в `--target` и в `COPY --from`.

#### 5.3.2 Всеки ред в своя момент

**Етапът `compilacion`.** Това е почти горната половина на Dockerfile от Урок 4: същата основа, същият `WORKDIR /src` и същите три `COPY` в реда, за който кешът е благодарен (първо `go.mod`, който почти никога не се променя; после кодът). Единственото ново е във `FROM`: след тага `1.27.3-trixie` идва `@sha256:6041…`, *digest*-ът, а накрая `AS compilacion`. *Digest*-ът има собствен раздел (5.7). Този етап още не компилира нищо: само поставя кода на мястото му, за да тръгнат от него следващите два.

**Етапът `pruebas`.** `FROM compilacion AS pruebas` казва „започни там, където е свършил `compilacion`“. За първи път виждаш `FROM`, който не назовава образ от интернет, а етап от същия файл. Единственият му `RUN` изпълнява `go test ./...`, тестовете на петте пакета на `revisor`, със същото монтиране на кеша от Урок 4 (`id=curso-docker-go-build` е същият, така че двата етапа споделят кеша за компилация на Go). Ако тест се провали, `go test` излиза с код, различен от нула, `RUN` се проваля и изграждането спира: няма образ.

**Етапът `binario`.** `FROM pruebas AS binario` е най-важният ред във файла, макар да изглежда като подробност. Той казва, че двоичният файл се компилира **върху** етапа на тестовете, а не върху този на компилирането. От 5.2.3 вече знаеш защо е важно: тъй като крайният етап копира от `binario`, а `binario` излиза от `pruebas`, BuildKit е длъжен да изпълни тестовете, за да стигне до крайния образ. Ако `binario` излизаше от `compilacion`, тестовете щяха да останат извън пътя и никой нямаше да ги изпълни. Ще го измериш в 5.5.

`RUN` на този етап има три нови неща в командата на Go:

- **`CGO_ENABLED=0`** изисква **статичен** двоичен файл: такъв, който не зависи от системни библиотеки, за да стартира. Това е частта, която прави възможен крайния етап, а махането ѝ е основната грешка на урока (5.8).
- **`-trimpath`** маха от двоичния файл пътищата на машината, на която е компилиран (тук `/src`): на тяхно място остават имената на модулите ([`go help build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies)). Така двоичният файл не зависи от това в коя папка си го компилирал, нито я издава.
- **`-ldflags="-s -w"`** подава две опции на линкера на Go: `-s` „пропуска таблицата със символи и информацията за дебъгване“, а `-w` „пропуска таблицата със символи DWARF“ ([cmd/link](https://pkg.go.dev/cmd/link)). Това е, което би използвал с дебъгер; една услуга в продукция няма нужда от него, а махането му прави файла по-малък. (`-s` вече включва `-w` според същата документация; пишат се и двете по навик и така ще ги видиш в почти всички Dockerfile за Go.) Сравни: двоичният файл от Урок 4 беше 9.5 MiB според `ls -lh`, около 10 MB; този ще бъде 6.68 MB (6,684,832 байта). Част от разликата е `-s -w`, а част е, че вече не съдържа кода на *cgo* (5.8).

Двоичният файл остава в `/out/revisor`, папка, която съществува само за това: да има фиксирано и чисто място, от което крайният етап да го вземе.

**Етапът `final`.** Започва от нулата върху `gcr.io/distroless/static-debian13:nonroot`, фиксиран по *digest*. От всичко предишно взема само един файл: `COPY --from=binario /out/revisor /revisor`. След това:

- `USER 65532:65532` е потребителят `nonroot`, който самият образ *distroless* има в своя `/etc/passwd`; ще го видиш с очите си в 5.4. Оттук нататък курсът изоставя `10001` от образите с един етап и използва `65532`, защото основата вече го познава. Обърни внимание, че `COPY --from=binario` няма `--chown`: файлът `/revisor` остава собственост на `root` (ще го видиш като `0/0` в 5.4) с права `rwxr-xr-x`. Това е нарочно. Потребителят `65532` може да го изпълнява, но не може да го променя, нито да го замества; ако някой поеме контрола над процеса, няма да може да пренапише програмата на диска на образа.
- `EXPOSE 8080` продължава да бъде само анотация, точно както в Урок 3.
- **`ENTRYPOINT ["/revisor"]`** заменя `CMD ["revisor"]` от предишните уроци. Разликата е практическа. Справочникът я обяснява: аргументите, които пишеш след името на образа в `docker run`, „се добавят след всички елементи“ на `ENTRYPOINT` във форма *exec*, а вместо това „заменят всичко, което казва `CMD`“ ([справочник, `ENTRYPOINT`](https://docs.docker.com/reference/dockerfile/#entrypoint)). С `ENTRYPOINT` `docker run curso-docker-revisor:1.2.0 version` изпълнява `/revisor version`: образът се държи като програмата, а подкомандите ѝ (`version`, а в Урок 7 и `healthcheck`) се извикват както в терминала. С предишния `CMD` това `version` би заменило цялата програма и Docker би се опитал да изпълни файл с име `version`. Остава във форма *exec* заради всичко, което измери в Урок 3. А пътят е пълен, `/revisor`, защото файлът е в корена на файловата система, `/`, който не е нито една от папките, в които `PATH` на образа търси програми.

#### 5.3.3 В твоята папка

Скриптовете на курса работят във временни папки и изтриват това, което създават; твоят проект живее в `~/curso-docker/revisor` от Урок 3. От корена на хранилището на курса сложи там Dockerfile на този урок и изгради образа, който ще запазиш:

```bash
cp programas/05-multi-stage/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q -t curso-docker-revisor:1.2.0 .
docker image ls curso-docker-revisor --format '{{.Repository}}:{{.Tag}} {{.Size}}'
```

`.dockerignore` от Урок 4 остава какъвто е. Образът `1.1.0` също може да остане, за да сравняваш; когато вече не ти трябва — `docker rmi curso-docker-revisor:1.1.0`.

### 5.4 Изграждане и мерене

#### 5.4.1 Изграждането, етап по етап

`fig05_03.sh` изгражда двата образа — този от Урок 4, за сравнение, и този от този урок — и задава на новия пет въпроса: кои стъпки от кой етап са се изпълнили, колко тежи, от какви слоеве е направен, откъде идва размерът му и какви файлове съдържа:

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

Файлът в хранилището съдържа пълните помощни функции; тук те са обобщени в коментар, за да не се повтарят. Два нови инструмента: `grep -oE` отпечатва само частта от всеки ред, която съвпада с шаблона (тук — номера на стъпката, етапа и първите 60 знака от инструкцията), а `awk '!visto[$0]++'` маха повтарящите се редове, без да променя реда им.

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

При всяко изпълнение се променят: номерата на стъпките (`#7`, `#8`…) и редът им, датата на файла `revisor`, а на компютър с Intel или AMD думата `arm64` в слоевете и размерите, с няколко килобайта или мегабайта. Стабилното: четирите етапа, двата размера в техния порядък, това, че сумата от двете числа в байтове дава размера от `docker image ls`, списъкът с папки и съдържанието на `/etc/passwd`.

#### 5.4.2 Разчитане на изграждането

Първият блок показва стъпките с етапа им в квадратни скоби: `[compilacion 4/5]` е четвъртата от петте стъпки на етапа `compilacion`. Появяват се четирите етапа, а два детайла показват как работи BuildKit:

- **Редът не е този от файла.** `FROM` на етапа `final` се появява първи (`#7`), преди всичко от `compilacion`, а `WORKDIR` (`[compilacion 2/5]`) излиза почти накрая, след `COPY`-тата. BuildKit сглобява граф на това какво от какво зависи и изпълнява паралелно каквото може: изтеглянето на минималната основа не трябва да чака копирането на кода. Крайният етап чака `binario` едва във втората си стъпка, `COPY --from`.
- **Номерата на стъпките не са тези на етапа.** `#13` е номер на BuildKit за това изграждане; `[pruebas 1/1]` е позицията в етапа. Ако изпълниш скрипта два пъти, първите може да се променят, както и редът; етикетите в квадратни скоби — не. (При друго изпълнение на същия урок, с повече неща вече в кеша, BuildKit дори не отпечата стъпки 1 и 2 на `compilacion`; затова не е добре да се броят редовете в този изход, а да се чете кои етапи се появяват.)

#### 5.4.3 Разчитане на размерите

Вторият блок е този, който оправдава урока: **от 1.32 GB до 16.1 MB**, около осемдесет пъти по-малко. Новият образ се побира седемнайсет пъти в това, което преди заемаше само компилаторът на Go (277 MB в `/usr/local/go`, в 5.1). А третият блок, `docker history`, казва какво има вътре: големият слой е `COPY /out/revisor /revisor`, от **6.69 MB**, двоичният файл; останалите са от основата *distroless* и общо са около 5.8 MB, като най-големият е 2.24 MB (часовите зони, `tzdata`). Слоевете на основата казват `bazel build`: това е инструментът, с който Google изгражда тези образи, а в историята им няма нито един `RUN apt-get`, защото не са сглобени чрез инсталиране на пакети с мениджър. Сравни с Урок 4, където `docker history` показваше слоеве от 290 MB, 281 MB и 208 MB.

Ако събереш тези слоеве ръчно, няма да получиш 16.1 MB, и си струва да знаеш защо, преди това да те обърка. Четвъртият блок ги събира вместо теб: **12,468,224 байта**, около 12.5 MB. Липсват 3.6 MB. А втората заявка в този блок ги намира: `docker image inspect` отчита **3,679,492 байта**, а 12,468,224 + 3,679,492 = 16,147,716 байта, 16.1 MB от `docker image ls`. Обяснението е в това как Docker Engine 29 съхранява образите, с хранилището на containerd: според документацията му това хранилище „съхранява образите в компресиран и некомпресиран формат“: пази компресираните слоеве така, както са дошли от регистъра, **и освен това** ги разпакетира на диска ([Docker, „containerd image store“](https://docs.docker.com/engine/storage/containerd/)). Числото от `docker image ls` брои двете копия; `docker history` брои само разпакетираните слоеве, а `docker image inspect` на тази машина — компресираната част, която е това, което се изтегля. Всичко това важи за току-що инсталиран Docker Engine 29, който по подразбиране използва хранилището на containerd; документацията уточнява, че Docker, обновен от по-стара версия, остава с класическото хранилище, `overlay2`, докато не го включиш ръчно. В този случай `docker image ls` ще ти покаже около 12.5 MB вместо 16.1 MB, и `docker image inspect` също: това не е твоя грешка, а друго хранилище, което брои само едно копие. За това, което е важно в този урок, нищо не се променя: сравнявай винаги образи с **една и съща** команда, а двете числа от `docker image ls` (1.32 GB и 16.1 MB) са измерени по един и същ начин.

Естествен въпрос е къде останаха етапите `compilacion`, `pruebas` и `binario`. Останаха в кеша за изграждане на твоя компютър, който прави следващото изграждане бързо, но **не са част от образа**: `docker history` на `1.2.0` няма нито един техен слой. Единственото, което премина от едната страна на другата, е файлът, който назовава `COPY --from`.

#### 5.4.4 Поглед отвътре, без да влизаш

Последната част на скрипта отговаря на въпроса от сцената: какво има в този образ? Тъй като няма *shell* (ще го провериш в 5.6), не можеш да влезеш да погледнеш с `docker exec`. Но можеш да поискаш от Docker да ти даде файловете му. `docker create` създава контейнер от образа, **без да го стартира**, а `docker export` изважда цялата файлова система на този контейнер като архив `tar`, който `tar -t` изброява, без да разархивира. Това е начинът да се инспектира минимален образ отвън.

Какво казва:

- **1,301 файла** общо (`grep -v '/$'` маха папките от броенето). Изглежда много, докато не погледнеш какво са: почти всички са часовите зони и сертификатите на удостоверителните органи в интернет, от които се нуждае услуга, проверяваща други услуги по HTTPS.
- **Папките от първо ниво** са тези на всеки Linux (`bin`, `etc`, `usr`, `var`…), плюс `revisor` и `.dockerenv`, празен файл, който Docker добавя към всеки контейнер. Това, че съществува папка `bin`, не значи, че вътре има програми.
- **Търсенето на *shells*** искаше, във всяка папка, файл с име `sh`, `bash`, `dash`, `ash` или `busybox`, плюс `revisor` и `passwd` като контрола: ако шаблонът беше написан грешно, нямаше да излязат и тези два. Излязоха двата контролни и нито един *shell*. Няма *shell*, а в 5.6 го потвърждаваш по друг начин: като се опиташ да го изпълниш. `revisor` е 6,684,832 байта, 6.69 MB от слоя.
- **Датата на `/etc/passwd`**, `1969-12-31 18:00`, е нулевата дата на часовника на Unix (1 януари 1970 г. по универсално време), видяна в часовата зона на машината, на която са направени изпълненията. Файловете на основата имат тази дата нарочно: така датата на деня, в който е изградена основата, не променя файловете, и две изграждания на една и съща основа не се различават по тази стойност. (Изграждане, възпроизводимо до байт, изисква повече от фиксирането на датата — например фиксиран ред на файловете и детерминирана компресия; тук датата е само едно от тези парчета.) `revisor`, обратно, има датата, на която е компилиран. Тази, която виждаш тук, е от ранните часове на същия ден: двоичният файл излезе от кеша за изграждане, защото нищо от това, което го произвежда, не се беше променило от предишното изпълнение на тази машина. На твоята ще видиш друга дата.
- **Съдържанието на `/etc/passwd`** има трима потребители, а третият е този, който използва крайният етап: `nonroot`, с номер **65532**. Ето я причината за `USER 65532:65532`. Обърни внимание освен това на последната колона и при тримата: `/sbin/nologin`. Дори `root` няма назначен *shell*.

> [!NOTE]
> 🔧 **Наблюдение от инженерството 5.2**
> Крайният образ не беше „почистен“: той се роди без излишното. Това е разликата между това да подредиш стая и да се преместиш в празна, като носиш само един куфар. Първото се разваля с времето; второто започва чисто всеки път, когато изграждаш.

### 5.5 Тестовете вътре в изграждането

#### 5.5.1 Изпълнение само на тестовете

Това, че тестовете живеят в собствен етап, позволява да ги изпълниш **самостоятелно**, без да изграждаш крайния образ. `fig05_04.sh` изгражда до етапа `pruebas`, като го принуждава да се изпълни, дори да е в кеша, и измерва получения междинен образ:

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

`--no-cache-filter pruebas` казва на BuildKit да не използва кеша за този етап ([docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/)): без това, тъй като нищо не се е променило, тестовете щяха да излязат от кеша и нямаше да видиш нито един ред от `go test`.

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

Променят се номерата на стъпките, секундите в третата колона (`15.92` са секундите от началото на тази стъпка) и времената на всеки пакет. Стабилното: петте пакета с `ok`.

Три неща за разчитане тук. Първото: **изпълниха се само `compilacion` и `pruebas`**. Няма нито един ред от `binario`, нито от `final`: това е правилото от 5.2.3 в действие, BuildKit изгради само това, от което се нуждаеше поисканият етап. Второто: петте пакета на `revisor` минаха тестовете си **вътре** в изграждането, със същия компилатор от фиксирания образ; това не зависи от това дали имаш Go инсталиран на компютъра си, нито от версията му. Третото: образът `pruebas` тежи **1.31 GB**. Той служи за тестване и за разглеждане, никога за предаване. Затова е етап, а не крайният образ.

#### 5.5.2 Счупен тест спира изграждането... ако е на пътя

Сега грешката на този раздел и нейната мълчалива версия. `fig05_05.sh` добавя тест, който нарочно се проваля, `rota_test.go`, и изгражда два пъти: с Dockerfile на урока и с вариант, който променя **един-единствен ред**, така че етапът `binario` да излиза от `compilacion` вместо от `pruebas`:

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

Скриптът използва `set -uo pipefail`, без `-e`, защото трябва да продължи след провала, който предизвиква. `${PIPESTATUS[0]}` е променлива на *bash*, която пази кода на изход на **първата** команда от предходния конвейер, `docker build`, а не този на `grep`, който филтрира изхода ѝ; `(exit N)` го връща, за да го запише помощната функция `muestra`.

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

Променят се номерата на стъпките и секундите. `[código de salida: 1]` след `diff` не е грешка: `diff` излиза с 1, когато намери разлики, което е точно това, което беше поискано да покаже.

**Първата половина е поведението, което искаш.** (Редът на теста излиза два пъти: първият, с `#14`, е изходът на стъпката, докато се изпълнява; вторият, без номер, е обобщението, което BuildKit повтаря точно преди `ERROR` с последните редове на стъпката, която се е провалила.) Тестът се проваля, `go test` отпечатва `FAIL` с файла и реда (`rota_test.go:5`) и съобщението, а BuildKit спира всичко с `ERROR`, който казва кой процес се е провалил и с какъв код: `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. Изграждането излиза с 1 и, най-важното, втората команда не отпечатва нищо: **образът `rota` не съществува**. Код със счупен тест не произвежда образ. Ако сървърът ти за изграждане публикува това, което изгражда, именно това не позволява да се публикува нещо счупено.

**Втората половина е мълчаливата грешка.** `diff` потвърждава, че вариантът променя един-единствен ред: `binario` излиза от `compilacion`. Счупеният тест още е там. А изграждането завършва с **код 0** и образ от 16.1 MB. Няма `FAIL`, нито `ERROR`, защото **тестовете никога не са се изпълнили**: филтърът търсеше редове от `pruebas` и от `binario`, а се появява само `binario` (два пъти, защото BuildKit отпечата отново заглавието на стъпката при приключването ѝ). Етапът `pruebas` продължава да е написан във файла, но крайният етап копира от `binario`, `binario` излиза от `compilacion` и никой по пътя не се нуждае от `pruebas`. Според правилото от 5.2.3 BuildKit не го изгражда.

Това е най-лошият вид грешка: не предупреждава. Dockerfile *изглежда* добре, има етап за тестове с коментара си, а който го преглежда набързо, вярва, че тестовете пазят образа. Затова `FROM pruebas AS binario` не е стилов детайл: той превръща тестовете в условие за съществуването на образа.

> [!NOTE]
> 🔧 **Наблюдение от инженерството 5.3**
> Проверка, която може да бъде прескочена, без никой да разбере, не е проверка. Начинът да разбереш дали една бариера работи е този от раздела: счупи я нарочно и провери, че спира изграждането. Зелено изграждане не доказва, че тестовете са минали; може да доказва само, че не са се изпълнили.

### 5.6 Минималната основа: без *shell* и без `root`

#### 5.6.1 Какво е *distroless*

Крайният етап тръгва от `gcr.io/distroless/static-debian13`. *Distroless* е семейство базови образи, които Google публикува, и името им вече обяснява идеята: „без дистрибуция“. Документацията им го казва така: те съдържат „само твоето приложение и неговите зависимости за изпълнение“ и нямат вградени „пакетни мениджъри, *shells*, нито каквато и да е друга програма, която би очаквал да намериш в обикновена дистрибуция на Linux“ ([distroless](https://github.com/GoogleContainerTools/distroless)).

Семейството има няколко варианта според това, от което програмата се нуждае, за да работи: `base`, `cc` и други с вече инсталирана среда за Python, Java или Node.js. Този, който използва `revisor`, е най-малкият от всички, **`static`**: за програми, които вече носят всичко в себе си и не зависят от нищо в системата. Документацията му го посочва като „около 2 MiB“. Твоите измервания не дават това число, и е добре да се каже: в слоевете от 5.4 го видя да заема около 5.8 MB вече разпакетиран, а компресираната му версия за `arm64`, тази, която се изтегля, е общо 855,334 байта в тринайсетте му слоя (измерено в същия ден с `docker buildx imagetools inspect --raw` върху *digest*-а за `arm64` от 5.7). Документацията не казва как е измерила своите 2 MiB, така че го приеми като порядък: няколко мегабайта срещу стотиците на основа с пълна дистрибуция. От 5.8 MB в разпакетиран вид почти 4.4 MB са часовите зони (`tzdata` и `tzdata-legacy`). Носи минимума, от който статична програма все още се нуждае от света: сертификатите на удостоверителните органи (за да говори HTTPS), часовите зони, `/etc/passwd` с тримата му потребители и папка `/tmp`. Това са слоевете, които видя в 5.4.

Пълното име има три части, които е добре да се прочетат една по една:

- `static`: вариантът, за статични двоични файлове.
- `debian13`: от коя версия на Debian идват малкото файлове, които съдържа (сертификати, часови зони). Документацията препоръчва версията на Debian винаги да се пише в името, за да не смени изграждането ти основата си без предупреждение в деня, в който излезе следващата.
- `:nonroot`: тагът. *Distroless* публикува малко тагове, които са имена, а не версии: `latest`, `nonroot`, `debug` и `debug-nonroot`, както и същите с наставка за архитектурата, например `nonroot-arm64` ([distroless](https://github.com/GoogleContainerTools/distroless)); нито един няма версия. `nonroot` е същият образ, но конфигуриран да работи с потребителя `nonroot` вместо с `root`. Вариантите `debug` включват минимален *shell* за дебъгване; те не са за продукция.

#### 5.6.2 Стартиране

`fig05_06.sh` стартира минималния образ по двата начина, по които се използва `revisor` — като програма, която прави едно нещо и приключва, и като услуга — и проверява това, което урокът обеща:

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

Както в Урок 3, `revisor` проверява сам себе си (`propio http://127.0.0.1:8080/salud`), защото още не го свързваш с други контейнери; това е Урок 8. `sed` на отчета закрива, за прегледност, времето за отговор, което се променя при всяко изпълнение.

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

Променят се PID (`1451351`), времето на `docker stop`, времето на `/api/estados` в лога и колко пъти се появява `GET /salud` (зависи от това колко опита е направил скриптът, докато е чакал услугата да отговори). Останалото излиза същото.

#### 5.6.3 Разчитане на изпълнението

- **`version` проработи като подкоманда.** `docker run ... curso-docker-revisor:1.2.0 version` изпълни `/revisor version` благодарение на `ENTRYPOINT`. Отпечатва `desarrollo`, защото двоичният файл още няма записана версия; Урок 6 ще му я сложи.
- **Като услуга прави същото като преди.** `/salud` отговаря, отчетът в таблица казва `OK`. Образът намаля осемдесет пъти, а поведението не се промени изобщо: всичко, което беше махнато, наистина беше багаж.
- **Няма *shell*.** `docker exec curso-docker-revisor sh` се проваля със същото съобщение, което видя с тестовата услуга в Урок 2: `exec: "sh": executable file not found in $PATH`, код 127. Сега знаеш защо: основата е *distroless* и `sh` не съществува. За сцената от началото това е отговорът: който успее да изпълни нещо вътре в този контейнер, няма да намери нито *shell*, нито `curl`, нито компилатор.
- **Не е `root`.** `docker inspect` казва `User=65532:65532`, а `docker top`, който гледа процеса от хоста, го потвърждава: процесът е на потребителя 65532. Той казва също `Entrypoint=[/revisor] Cmd=[]`: програмата се фиксира от `ENTRYPOINT` и няма аргументи по подразбиране.
- **Спира правилно.** `docker stop` отне 298 ms, кодът беше 0, а логът завършва с `recibí terminated, apagando` и `apagado limpio`: формата *exec* прави така, че сигналът да стигне до `revisor`, който е процесът с номер 1. Обърни внимание, че в колоната `COMMAND` на `docker top` е само `/revisor`, без `/bin/sh -c` отпред: там дори не би могъл да има, защото няма *shell*.

#### 5.6.4 Цената на това да нямаш *shell*

Образ без *shell* има цена и е добре да се каже: **не можеш да влезеш да надникнеш**. Няма `ls`, `cat`, `ps`, нито `sh`. Когато нещо се провали, инструментите, които ти остават, са външните, и те са достатъчни:

- `docker logs` — за това, което програмата пише;
- `docker inspect` — за конфигурацията и състоянието;
- `docker top` — за да видиш процеса от хоста;
- `docker export` с `tar` — за да видиш файловете, както в 5.4.4;
- и етапът `binario`, изграден с `--target`, който има всички инструменти, за да разгледаш програмата отвътре. Ще го използваш в 5.8.

Това, което **не** се прави, е да се смени крайната основа с такава, която има *shell*, „за да може да се дебъгва“. Ако наистина ти трябва *shell* до процеса, има инструменти, с които да му се закачи такъв отвън, временно, без да се вкарва в образа; този курс няма нужда от тях.

### 5.7 Версия и *digest* на основата

#### 5.7.1 Тагът е прякор, който се мести

В Урок 3 видя, че таг като `1.27.3-trixie` е по-конкретен от `latest` и че въпреки това може да се промени: който публикува образа, може да го качи отново. Ръководството за добри практики на Docker го казва съвсем ясно: „таговете на образите са променливи, което означава, че публикуващият може да обнови таг така, че да сочи към нов образ“ ([добри практики, фиксиране на версията на основата](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). При *distroless* въпросът е още по-ясен: тагът му `nonroot` няма версия, така че **по определение** сочи към последното публикувано. Да пишеш само `static-debian13:nonroot` на практика е да пишеш `latest`.

#### 5.7.2 Какво е *digest*

***Digest*** е цифровият отпечатък на съдържанието на един образ: изчислява се, като байтовете му се прекарат през хеш функция, SHA-256, и се записва като `sha256:`, последвано от 64 шестнайсетични знака. Спецификацията за образи на OCI го определя като „идентификатор на съдържание“, който „идентифицира съдържанието по уникален начин“, изчислен с хеш функция, устойчива на колизии ([OCI, дескриптори](https://github.com/opencontainers/image-spec/blob/main/descriptor.md)). Практическото следствие е това, което има значение: **ако се промени дори един байт от образа, се променя и *digest*-ът**. *Digest* не може да бъде преместен към друг образ, защото той е самият образ.

`fig05_09.sh` пита регистъра какъв *digest* имат днес двете основи от Dockerfile, без да изгражда или създава нищо:

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

`docker buildx imagetools inspect` пита регистъра какво стои зад едно име, без да изтегля образа. `docker image inspect` с `.RepoDigests` казва от кой *digest* е дошло копието, което вече имаш на компютъра си.

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

Този изход е от 21 октомври 2026 г. **Той е този, който може да се промени най-много в целия урок**, и не заради твоя компютър: в деня, в който Google публикува нова основа с тага `nonroot`, `Digest` от четвъртата заявка ще бъде друг. Този на `golang:1.27.3-trixie` също може да се промени, ако публикуващият го изгради наново. А ако никога не си изтеглял образа на Go, третата заявка се проваля, защото нямаш локално копие.

#### 5.7.3 Разчитане на изхода

- **`MediaType` казва `image.index`.** Това, което стои зад тези тагове, не е образ, а **индекс**: списък от образи, по един за всяка платформа. Затова втората и петата заявка намират запис за `linux/amd64` и друг за `linux/arm64/v8`, всеки със собствен *digest*. *Digest*-ът, който пише Dockerfile, е **този на индекса**: с него същият ред работи и в твоя Mint с процесор Intel или AMD, и на ARM машината от тези изпълнения, а Docker избира образа за твоята платформа вътре в индекса.
- **Двата *digest*-а в Dockerfile съвпадат с тези от този ден**: `6041…` за Go и `5167…` за *distroless*. Локалното копие на Go е дошло от същия *digest*.
- **Ако напишеш *digest*-а на една платформа** (например `6964…` за `arm64`) вместо този на индекса, основата остава вързана за тази архитектура: който изгражда на друга, вече не получава основата за своята. Това е лесна за допускане грешка, ако копираш *digest*-а от грешния ред.

#### 5.7.4 Таг **и** *digest*

Dockerfile пише двете неща заедно: `golang:1.27.3-trixie@sha256:6041…`. Синтаксисът е позволен от справочника: `FROM <imagen>[@<digest>] [AS <nombre>]` ([справочник, `FROM`](https://docs.docker.com/reference/dockerfile/#from)). Когато има *digest*, командва *digest*-ът: Docker изтегля точно тези байтове, каквото и да казва днес тагът. Тогава за какво е тагът? За хората: `@sha256:6041…` не казва на никого коя версия на Go е; `1.27.3-trixie` — казва. Тагът документира; *digest*-ът фиксира съдържанието: осигурява, че Docker винаги ще изтегли едни и същи байтове, дори някой да е преместил тага в регистъра. Не осигурява, че регистърът ще пази този образ завинаги, нито че образът няма грешки или уязвимости.

Ръководството за добри практики обяснява гаранцията, а също и цената ѝ. Гаранцията: с *digest*-а „имаш гаранция, че винаги използваш една и съща версия на образа, дори ако публикуващият замени тага с нов образ“. Цената: фиксиран *digest* **не се обновява сам**, така че и поправките за сигурност на основата не идват сами ([добри практики](https://docs.docker.com/build/building/best-practices/#pin-base-image-versions)). Фиксирането не е забравяне: то е решение кога да смениш основата, като го прегледаш, вместо тя да се смени без предупреждение по средата на изграждане. Същото ръководство споменава инструменти, които отварят автоматични заявки за промяна, когато излезе нов *digest*. А Урок 10 те учи да сканираш фиксираната основа, за да знаеш кога е време да я обновиш.

> [!NOTE]
> 🔧 **Наблюдение от инженерството 5.4**
> Възпроизводимото изграждане е това, което дава същия резултат днес и след три месеца със същия код. Без *digest* един и същ Dockerfile може да произведе два различни образа, без никой да е пипал нищо, и в деня, в който нещо се провали, няма да можеш да разбереш дали е заради твоята промяна или заради тази на основата.

### 5.8 Двоичният файл, който не стартира

#### 5.8.1 Предизвикване

Това е частта от урока, в която всичко изглежда наред и нищо не работи. `fig05_07.Dockerfile` е Dockerfile на урока с **една-единствена промяна**: `RUN` на етапа `binario` не казва `CGO_ENABLED=0`:

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

# --- Etapa 3: el binario, SIN CGO_ENABLED=0 (el binario sale dinámico), sale DESPUÉS de las pruebas ---
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

Коментарът на етап 3 тук казва истината (без `CGO_ENABLED=0` двоичният файл излиза динамичен), но в реалния живот този коментар често продължава да казва „статичен“, без вече да е вярно: Dockerfile не предупреждава за нищо и грешката се появява чак когато образът заработи. `fig05_08.sh` изгражда този образ, стартира го и после разглежда двата двоични файла, този от този образ и този от урока, от етапа `binario`, който има инструменти:

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

`ldd` е инструмент на Linux, който изброява споделените библиотеки, нужни на една програма, за да стартира. `readelf -l` показва заглавията на изпълним файл на Linux (формат ELF), а сред тях и реда, който казва коя програма трябва да го зареди. Двата инструмента съществуват в образа на Go, но не и в *distroless*: затова се използват от етапа `binario`, изграден с `--target`.

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

Променят се адресите в скоби (`0x0000fd7d…`), които са различни при всяко изпълнение. На компютър с Intel или AMD пътищата казват `x86_64` вместо `aarch64`: интерпретаторът е `/lib64/ld-linux-x86-64.so.2`, а библиотеката е в `/lib/x86_64-linux-gnu/`. Съобщението за грешка и кодът 255 излизат същите.

#### 5.8.2 Разчитане на грешката

Изграждането излезе с **код 0**: нищо в Dockerfile не е написано грешно, тестовете минаха и двоичният файл се компилира. Грешката се появява едва при **изпълнение**: `exec /revisor: no such file or directory`, с код 255. Този код не го е сложил `revisor`, който така и не стигна до изпълнение: провалът се случи при опита той да бъде стартиран.

Съобщението е от най-объркващите, които ще видиш в Docker, защото **файлът `/revisor` съществува**: копира го `COPY --from`, а в 5.4 го видя в списъка с файлове на образа. Това, което не съществува, е **друг** файл, и втората част на изхода казва кой:

- `ldd` на двоичния файл от този образ изброява три неща, от които той се нуждае от системата: `libc.so.6`, библиотеката за C на Debian, и `/lib/ld-linux-aarch64.so.1`, **динамичния зареждач** (`linux-vdso.so.1` го слага самото ядро и не е файл). `readelf` го потвърждава с изричен ред: `Requesting program interpreter: /lib/ld-linux-aarch64.so.1` — „искам за интерпретатор на програмата `/lib/ld-linux-aarch64.so.1`“.
- Двоичният файл на урока, обратно, е `not a dynamic executable` и не иска интерпретатор: той е **статичен**, носи в себе си всичко, от което се нуждае.
- А последната заявка търси зареждача и библиотеката за C в крайния образ: `(no está)`. Основата `static` не ги съдържа, защото е за статични програми.

Ръководството на Linux обяснява веригата. Динамична програма не стартира сама: ядрото прочита в самия изпълним файл кой е неговият зареждач, този, който е „записан в секцията `.interp` на програмата“, и го изпълнява, за да потърси и зареди „споделените обекти (споделените библиотеки), от които тя се нуждае“ ([ld.so(8)](https://man7.org/linux/man-pages/man8/ld.so.8.html)). Ако този зареждач не съществува, системното извикване, което стартира програми, `execve`, се проваля с грешката `ENOENT`, която ръководството описва така: „пътят или интерпретатор на *script* или на ELF не съществува“ ([execve(2)](https://man7.org/linux/man-pages/man2/execve.2.html)). `ENOENT` е точно грешката, която се отпечатва като `no such file or directory`. Съобщението не лъже; то просто не казва **кой** файл липсва, а липсващият не е този, който то назовава.

#### 5.8.3 Защо Go направи динамичен двоичен файл

Go е известен с това, че произвежда двоични файлове, които не зависят от нищо, и това е вярно почти винаги. Изключението е *cgo*, механизмът, с който програма на Go извиква код на C. Документацията на Go казва, че *cgo* „е включен по подразбиране при нативните компилации, на системите, където се очаква да работи“, и че се изключва с променливата `CGO_ENABLED=0` ([cmd/cgo](https://pkg.go.dev/cmd/cgo)). Образът на Go съдържа компилатор за C (видя го в 5.1: `gcc`), така че там *cgo* е включен.

А за какво би му трябвал на `revisor` код на C, щом няма нито ред на C? Заради мрежата. `revisor` използва пакета `net` от стандартната библиотека — за сървъра си и за проверката на други услуги. Този пакет съдържа два начина за превръщане на име в адрес: един, написан на чист Go, и друг, който извиква функциите на системната библиотека за C. Обикновено използва този на Go, но при определени системни конфигурации използва този на C ([пакет net, „Name Resolution“](https://pkg.go.dev/net#hdr-Name_Resolution)). За да може да избира при изпълнение, когато *cgo* е наличен, двоичният файл включва и двата, и това е, което видя с `ldd` в 5.8.1: зависимостта от `libc.so.6` и от зареждача. С `CGO_ENABLED=0` Go използва само собствената си реализация и двоичният файл остава статичен.

Поправката тогава е тази от етапа `binario` на урока: `CGO_ENABLED=0` пред `go build`. Не е нужно да се сменя основата, нито да се копират библиотеки ръчно.

> [!NOTE]
> 🔧 **Наблюдение от инженерството 5.5**
> Зелено изграждане не гарантира образ, който стартира. Между изграждането и изпълнението има неявно споразумение между двоичния файл и основата: това, което единият иска, другата трябва да го има. Затова всеки нов образ се **изпълнява**, преди да бъде приет за добър, дори и с толкова проста подкоманда като `version`.

### 5.9 Какво ще срещнеш в стари уроци в интернет

Изгражданията в няколко етапа дойдоха в Docker с версия 17.05, от 4 май 2017 г.: бележките към тази версия обявяват „поддръжка на изграждания в няколко етапа“ и, в същия списък, опцията за посочване на целевия етап ([бележки към Docker Engine 17.05](https://docs.docker.com/engine/release-notes/17.05/)). Преди това проблемът от този урок се решаваше с трикове, които още ще виждаш в стари хранилища:

- **„Шаблонът на изграждащия“ с два Dockerfile.** `Dockerfile.build` изграждаше образ с компилатора; скрипт на *shell* създаваше контейнер от този образ, изваждаше двоичния файл с `docker cp` и после изграждаше втори образ с друг Dockerfile. Работеше, но това бяха три стъпки, които трябваше да се поддържат синхронизирани ръчно. Едно-единствено изграждане с няколко етапа прави същото.
- **Свързани `RUN` с `&&`, които инсталират, компилират и изтриват на един ред**, за да не остане изтритото в нито един слой. Това беше начинът да се спести място с един етап; той все още е по-малко ефективен от това да не вкарваш компилатора в крайния образ.
- **`FROM scratch`.** `scratch` е празен образ, без нито един файл. Статичен двоичен файл може да работи там и много уроци го правят. Липсва му това, което *distroless* `static` наистина включва: сертификати за HTTPS, часови зони и `/etc/passwd` с непривилегирован потребител. За `revisor`, който проверява услуги и не трябва да работи като `root`, основата на курса спестява ръчното добавяне на тези части.
- **`FROM alpine` като крайна основа, „защото е малка“.** Alpine е малък, но включва *shell* и пакетен мениджър и използва друга библиотека за C (musl), различна от тази на Debian: динамичен двоичен файл, компилиран в образа на Go с Debian, не стартира в него по същата причина като в 5.8.
- **`COPY --from=0`**, с номер вместо име. Работи, но се чупи мълчаливо в деня, в който някой добави етап в началото.

## Грешката, която ще видиш

Този урок има една основна грешка и една, която не се вижда.

**Основната грешка: `exec /revisor: no such file or directory`.** Това е тази от `fig05_08.sh`:

```text
$ docker run --rm --name curso-docker-dinamico curso-docker-revisor:dinamico version
exec /revisor: no such file or directory
[código de salida: 255]
```

Разчита се така: контейнерът не успя да **стартира** програмата и програмата никога не се изпълни (затова не отпечата нищо свое). Коварното е, че файлът, който назовава, съществува. Липсва това, от което този файл се нуждае, за да стартира: динамичният му зареждач и библиотеките, които иска. Когато видиш това съобщение с минимална основа, последователността е:

1. Изгради етапа на двоичния файл с `--target` и разгледай програмата с `ldd` и `readelf -l`. Ако казва `not a dynamic executable`, проблемът е друг (провери пътя в `ENTRYPOINT`). Ако изброява библиотеки и интерпретатор, намерил си причината.
2. Поправи го при компилирането: за Go — `CGO_ENABLED=0`. Ако една програма наистина се нуждае от библиотеката за C, правилната основа е такава, която я съдържа, а не вариантът `static`: *distroless* има по-пълни варианти, като `base` и `cc`, а документацията му казва какво съдържа всеки.
3. Това, което **не** се прави, е да се копират отделни библиотеки в крайния образ, докато не стартира, нито да се смени основата с такава, която има *shell*, „за да заработи“. Първото е крехко, а второто разваля урока.

**Грешката, която не се вижда: етапът на тестовете, който никой не изпълнява.** Това е втората половина на `fig05_05.sh`: с `FROM compilacion AS binario` счупен тест не спира изграждането, защото BuildKit не изгражда етап, от който крайният образ не зависи. Няма съобщение за разчитане; симптомът е точно това, че **няма** `FAIL`. Единственият начин да я откриеш е този от фигурата: добави нарочно счупен тест и провери, че изграждането се проваля с `process "/bin/sh -c go test ./..." did not complete successfully: exit code: 1`. Ако завърши с код 0, провери от кой етап излиза етапът ти за двоичния файл.

## Навикът за сигурност на урока

**Предавай само това, което е нужно за изпълнение, върху минимална, фиксирана основа и без `root`.** Крайният образ няма *shell*, нито пакетен мениджър, нито компилатор, нито `curl`; работи с потребителя 65532; а основата му е фиксирана по *digest*. Този навик предотвратява три конкретни инцидента. Първият е този от сцената: който успее да изпълни нещо вътре в контейнера — например заради грешка в програмата — не намира инструменти, с които да изтегли, компилира или изпълни нещо друго; трябва да донесе всичко, а без *shell* дори няма с какво да го изпълни. Вторият е основата, която се сменя сама: без *digest* едно утрешно изграждане може да донесе основа, различна от днешната, без никой да го е решил. Третият е шумът: скенер, който проверява 16 MB с няколко пакета, ти казва нещо, което можеш да прочетеш; такъв, който проверява 1.32 GB с двеста пакета на Debian — не. Това, че образът освен това намалява осемдесет пъти, е следствието, а не целта.

## Какво се прави погрешно

**Смаляване на образа чрез изтриване на файлове с `RUN rm`.** Изтритото остава в слоя отдолу; образът не олеква. Това, което не трябва да пътува, остава в друг етап.

**Предаване на образа с един етап, „защото работи“.** Работи точно както този от 16 MB и носи цяла работилница за онзи, който влезе. Това, че работи, не е критерият; критерият е какво друго носи.

**Изваждане на двоичния файл от етапа на компилиране и оставяне на тестовете в отделен етап, от който никой не се нуждае.** Изглежда, сякаш има тестове, а ги няма (5.5). Двоичният файл излиза **от** етапа на тестовете.

**Фиксиране на основата само по таг или използване на тага `nonroot` на *distroless* без *digest*.** Това е `latest` с друго име. Тагът е за четене, *digest*-ът — за фиксиране на съдържанието.

**Копиране на *digest*-а на една платформа вместо този на индекса.** Основата остава вързана за една-единствена архитектура и който изгражда на друга, не получава подходящата за него. *Digest*-ът, който отива във `FROM`, е този от реда `Digest:` отгоре — този на индекса.

**Смяна на крайната основа с такава, която има *shell*, „за да може да се дебъгва“.** Дебъгва се отвън (`logs`, `inspect`, `top`, `export`) и от етапа на изграждане с `--target`; образът, който се предава, не носи инструменти за всеки случай.

**Използване на `CMD` там, където образът е програма с подкоманди.** С `CMD ["revisor"]` `docker run imagen version` заменя цялата програма. С `ENTRYPOINT ["/revisor"]` се добавя като аргумент.

**Приемане на образ за добър, защото се е изградил.** Динамичният двоичен файл от 5.8 се изгражда без нито една грешка. Един образ се приема за добър, когато **работи**.

## Упражнения

Прави ги по ред. Преди всяко запиши в своя [дневник](bitacora.md) какво мислиш, че ще се случи; сравнението после е половината от ученето. Ако изпълниш нещо, накрая изтрий това, което си създал: всичко носи префикса `curso-docker-`.

### Упражнение 1 — Кои етапи се изпълняват?

С Dockerfile на урока (fig05_02) и при положение, че кешът е празен, кажи кои етапи изгражда BuildKit във всеки от случаите:

1. `docker build -t curso-docker-revisor:1.2.0 .`
2. `docker build --target pruebas -t curso-docker-revisor:pruebas .`
3. `docker build --target compilacion -t curso-docker-revisor:compilacion .`
4. С варианта от `fig05_05.sh` (`FROM compilacion AS binario`): `docker build -t curso-docker-revisor:1.2.0 .`

И още един въпрос: в случай 2, има ли полученият образ двоичния файл `/out/revisor`?

### Упражнение 2 — Поправи чуждия Dockerfile

Колега ти дава този Dockerfile „с няколко етапа“ за `revisor`. Намери **шест** проблема, които причиняват инцидент, кажи какво причинява всеки от тях и напиши поправената версия. (Има освен това два стилови детайла, които си струва да се поправят; те не влизат в шестте.)

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

Подсказка: един от шестте е основната грешка на урока, а друг е грешката, която не се вижда.

### Упражнение 3 — Правилният `FROM`

С изхода от `fig05_09.sh` пред очите си напиши `FROM` на крайния етап за тези три случая и кажи кой от трите е правилният за курса:

1. Само по таг.
2. По таг и по *digest*-а, който работи на всяка платформа.
3. По таг и по *digest*-а за твоята платформа, ако твоят Mint е на Intel или AMD.

Какво става със случай 3, ако колега с ARM компютър изгради твоя Dockerfile?

### Упражнение 4 — Твоят образ, измерен (проект)

В папката си `~/curso-docker/revisor`, с образа `curso-docker-revisor:1.2.0`, който изгради в 5.3.3, провери, без да гледаш урока:

1. Размера му в сравнение с този на `1.1.0`, който записа в Урок 4. Запиши двата в дневника си.
2. Че няма *shell*.
3. Че не работи като `root`, по два различни начина: един, който чете конфигурацията на образа, и друг, който гледа процеса от хоста.
4. Че двоичният файл на твоя образ е статичен, без да влизаш в крайния образ.

Упражнението се самопроверява: свършил си, когато имаш четири команди, чиито изходи казват съответно около 16 MB (или около 12.5 MB, ако твоят Docker използва класическото хранилище, виж 5.4.3), `executable file not found`, потребителя `65532` (като `65532:65532` в `inspect` и като `65532` в `top`) и `not a dynamic executable`.

## Решения

### Решение 1

1. И четирите: `final` копира от `binario`, `binario` излиза от `pruebas`, а `pruebas` излиза от `compilacion`. Това е веригата, която задължава тестовете да се изпълнят. Видя го в първия блок на `fig05_03.sh`.
2. `compilacion` и `pruebas`, и нищо повече. Точно това показа `fig05_04.sh`: нито ред от `binario`, нито от `final`.
3. Само `compilacion`.
4. `compilacion`, `binario` и `final`. **`pruebas` не се изпълнява**, защото никой по пътя на крайния етап не се нуждае от него: това е втората половина на `fig05_05.sh`, която завърши с код 0 и образ, със счупен тест вътре.

Допълнителният въпрос: **не**. Етапът `pruebas` само изпълнява `go test`; двоичният файл се произвежда в етапа `binario`, който идва след него и не е изграден. Образът `pruebas` съдържа изходния код и компилатора, затова тежи 1.31 GB.

### Решение 2

1. **`golang:latest`.** Основата може да се смени при всяко изграждане, а с нея и версията на Go: един и същ код се компилира различно от ден на ден. Трябва да е `golang:1.27.3-trixie@sha256:…`.
2. **Етапът на двоичния файл не излиза от този на тестовете.** Той е отделен `FROM golang:latest`, така че етапът на тестовете не е на пътя на крайния и BuildKit **не го изпълнява**: счупен тест не спира нищо (грешката, която не се вижда, 5.5). Етапът на двоичния файл трябва да излиза от етапа на тестовете.
3. **Липсва `CGO_ENABLED=0`.** Двоичният файл излиза динамичен и в *distroless* `static` се проваля с `exec /revisor: no such file or directory` (основната грешка, 5.8).
4. **`COPY --from=1` с номер.** В деня, в който някой добави или махне етап в началото, номерът сочи към друг етап и се копира не това, което трябва, без предупреждение. С имена (`COPY --from=binario`) това не се случва тихо: инструкцията продължава да сочи към етапа, който е написан в името ѝ, а ако някой изтрие този етап, изграждането се проваля с грешка, вместо да копира от друг.
5. **Крайната основа без *digest*.** Тагът `nonroot` без *digest* е `latest` с друго име: основата може да се смени, без никой да го е решил (5.7).
6. **`CMD` вместо `ENTRYPOINT`.** С `CMD ["/revisor"]` `docker run imagen version` заменя цялата програма и Docker се опитва да изпълни файл с име `version`, който не съществува (5.3.2).

Двата стилови детайла: повтореният `COPY . .` в два етапа (копира два пъти целия контекст; с общ етап `compilacion` е достатъчно веднъж, и то с избирателни `COPY`, както в Урок 4) и неявният `USER` (основата `nonroot` вече работи като 65532, защото конфигурацията ѝ казва `"User": "65532"`, но писането на `USER 65532:65532` оставя намерението видимо за онзи, който чете Dockerfile).

Поправената версия е Dockerfile на урока, `fig05_02.Dockerfile`.

### Решение 3

1. `FROM gcr.io/distroless/static-debian13:nonroot AS final`
2. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final`
3. `FROM gcr.io/distroless/static-debian13:nonroot@sha256:4682a3837fcb5c5100770c29c8174c41118a886edf209e75b5f815cf5d9a0d3a AS final`

Правилният е 2: *digest*-ът на индекса, този от реда `Digest:`, който работи на `amd64` и на `arm64`. С 3 основата остава вързана за образа за `linux/amd64`: на ARM компютъра на колегата ти Docker вече не може да избере основата за неговата платформа вътре в индекса, защото `FROM` не назовава индекса, а само един от образите му, и крайният му образ би завършил с основа за архитектура, различна от тази на двоичния му файл. Този урок не изпълни този случай; важното е, че с *digest*-а на индекса въпросът изобщо не възниква. *Digest*-ите в това решение са от 21 октомври 2026 г.; ако `fig05_09.sh` ти покаже други, използвай своите и запиши в дневника, че основата се е сменила.

### Решение 4

Един начин да го направиш:

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

Очакваните изходи са тези от урока: `16.1MB` (с няколко мегабайта повече или по-малко при Intel или AMD) срещу `1.32GB`; грешката `exec: "sh": executable file not found in $PATH` с код 127; `65532:65532` в `inspect` и `65532` в колоната `USER` на `top`; и `not a dynamic executable` в `ldd` (както във `fig05_08.sh`). Ако на последната стъпка `ldd` изброи `libc.so.6`, твоят Dockerfile е изгубил `CGO_ENABLED=0`.

## Как разбирам, че съм успял

Отбележи всяка точка само ако можеш да я направиш, **без да поглеждаш отново текста**:

- [ ] `docker image ls curso-docker-revisor` показва тага `1.2.0` с около **16 MB**, а ти си записал в дневника си преди и след (при изпълнението на този урок 1.32 GB → 16.1 MB).
- [ ] `docker run --rm curso-docker-revisor:1.2.0 version` отпечатва `desarrollo`.
- [ ] `docker exec` със `sh` върху контейнер от твоя образ се проваля с `executable file not found in $PATH`, а `docker top` показва процеса с потребителя `65532`.
- [ ] Добави счупен тест в папката си, `docker build -t curso-docker-revisor:rota .` се провали с `exit code: 1` и `docker image ls curso-docker-revisor:rota` не показва нищо; после изтри теста.
- [ ] Обясняваш защо `FROM pruebas AS binario`, а не `FROM compilacion AS binario`, с изречението на BuildKit за това кои етапи изгражда.
- [ ] Обясняваш кой файл липсва, когато се появи `exec /revisor: no such file or directory`, и как го потвърждаваш с `ldd` или `readelf` от етапа `binario`.
- [ ] Казваш какво осигурява тагът, какво осигурява *digest*-ът и защо *digest*-ът във `FROM` е този на индекса.
- [ ] Изпълни скриптовете от [`programas/05-multi-stage/`](../programas/05-multi-stage) и изходите ти съвпадат с тези от урока в това, което всеки раздел отбелязва като стабилно. Не се сравняват: номерата на стъпките, PID, времената, датите, адресите от `ldd`, архитектурата, размерите с точност до няколко мегабайта и *digest*-ите от `fig05_09.sh`, ако основата е била публикувана отново. А накрая `docker ps -a --filter name=curso-docker-` не показва контейнери от този урок.

## Обобщение

Отговори, без да поглеждаш урока:

1. Защо образът от Урок 4 тежеше 1.32 GB, ако `revisor` тежеше 9.5 MB? Защо изтриването на компилатора с `RUN rm` не го смалява?
2. Какво е етап? Какво правят `AS`, `COPY --from` и `--target`?
3. Кои етапи изгражда BuildKit, когато поискаш крайния образ? Какво следствие има това за етапа на тестовете?
4. Какво е вградено в основата *distroless* `static` и какво не е? Какви инструменти ти остават, за да дебъгваш образ без *shell*?
5. Защо Dockerfile използва `ENTRYPOINT ["/revisor"]` вместо `CMD ["revisor"]`?
6. Какво е *digest*? Защо тагът и *digest*-ът се пишат заедно и каква е цената на фиксирането на основата?
7. Какво означава `exec /revisor: no such file or directory`, когато файлът съществува? Какво прави `CGO_ENABLED=0`?

## Източници

Всички са прегледани на 21 октомври 2026 г.

- [Docker, „Multi-stage builds“](https://docs.docker.com/build/building/multi-stage/): няколко `FROM`, избирателно копиране между етапи, именуване на етапите, `--target` и това, че BuildKit изгражда само етапите, от които зависи целевият етап.
- [Docker, „containerd image store“](https://docs.docker.com/engine/storage/containerd/): това, че хранилището на containerd пази всеки слой компресиран и разпакетиран, което обяснява размера от `docker image ls`.
- [Docker, добри практики при изграждане](https://docs.docker.com/build/building/best-practices/): етапите за намаляване на размера, минималната основа, променливите тагове и фиксирането по *digest* с неговата цена.
- [Справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/): синтаксисът `FROM <imagen>[@<digest>] [AS <nombre>]`, `COPY --from` и как `ENTRYPOINT` и `CMD` получават аргументите на `docker run`.
- [docker buildx build](https://docs.docker.com/reference/cli/docker/buildx/build/): опциите `--target` и `--no-cache-filter`.
- [Docker Engine 17.05, бележки към версията](https://docs.docker.com/engine/release-notes/17.05/): появата на изгражданията в няколко етапа и на целевия етап, на 4 май 2017 г.
- [Docker Engine 29, бележки към версиите](https://docs.docker.com/engine/release-notes/29/): версиите и датите от „За изпълненията“.
- [distroless (GoogleContainerTools)](https://github.com/GoogleContainerTools/distroless): какво е вградено и какво не е в образите *distroless*, размерът на `static-debian13`, таговете му и препоръката да се назовава версията на Debian.
- [golang в Docker Hub](https://hub.docker.com/_/golang): тагът `1.27.3-trixie` и неговите псевдоними.
- [OCI Image Specification, дескриптори](https://github.com/opencontainers/image-spec/blob/main/descriptor.md): какво е *digest* и защо идентифицира съдържанието.
- [cmd/cgo](https://pkg.go.dev/cmd/cgo): кога *cgo* е включен и как се изключва с `CGO_ENABLED=0`.
- [Пакет net на Go, „Name Resolution“](https://pkg.go.dev/net#hdr-Name_Resolution): двата начина за разрешаване на имена — на чист Go и този, който използва библиотеката за C.
- [cmd/link](https://pkg.go.dev/cmd/link): опциите `-s` и `-w` на линкера и това, че `-s` включва `-w`.
- [cmd/go, `go build`](https://pkg.go.dev/cmd/go#hdr-Compile_packages_and_dependencies): опцията `-trimpath`.
- [ld.so(8), ръководство на Linux](https://man7.org/linux/man-pages/man8/ld.so.8.html): динамичният зареждач и секцията `.interp`.
- [execve(2), ръководство на Linux](https://man7.org/linux/man-pages/man2/execve.2.html): грешката `ENOENT`, когато липсва интерпретаторът на ELF.
- [Colima](https://github.com/abiosoft/colima): инструментът, с който програмите бяха изпълнени под macOS.

### Термини от този урок

| | |
|---|---|
| **динамичен двоичен файл** | изпълним файл, който се нуждае от системни библиотеки и зареждач, за да стартира |
| **статичен двоичен файл** | изпълним файл, който носи в себе си всичко, от което се нуждае; не зависи от системни библиотеки |
| **динамичен зареждач** | програма (`ld-linux…`), която стартира динамичен двоичен файл и зарежда библиотеките му |
| ***cgo*** | механизъм, с който програма на Go извиква код на C; изключва се с `CGO_ENABLED=0` |
| ***digest*** | SHA-256 отпечатък на съдържанието на образ или индекс; ако се промени един байт, отпечатъкът се променя |
| ***distroless*** | семейство минимални базови образи, без *shell* и без пакетен мениджър |
| **етап** (*stage*) | всяка част от Dockerfile, която започва с `FROM`; само последният е образът, който се предава |
| **целеви етап** (*target*) | етапът, до който се изгражда с `--target` |
| **индекс** (*image index*) | списък от образи с едно и също име, по един за всяка платформа |
| ***multi-stage*** | изграждане в няколко етапа в рамките на един Dockerfile |

---

**Следващ:** [Урок 6 — Конфигурация и тайни](06-configuracion-y-secretos.md)
