# Урок 9 — Compose: цялата система

Четвъртък е, 5:40 следобед. Утре в 9:00 в екипа постъпва нова стажантка и първата ѝ задача е да стартира `revisor` на компютъра си, за да види как работи. Изпратил си ѝ в чата онова, което използваш: шест команди от Урок 8, копирани от историята ти. Две мрежи, един том, два `docker run` от три и пет реда, един `docker network connect`. В 5:52 тя ти отговаря с екранна снимка: `revisor` казва `FALLA` за тестовата услуга, с `no such host`. Преглеждаш командите, които е копирала, и намираш проблема: прескочила е `docker network connect`, последната, защото е решила, че е по избор. Обясняваш ѝ. В 6:05 изпраща друга снимка: сега излиза `OK`, но контейнерът на `revisor` няма `--read-only`, нито `--cap-drop ALL`, защото е копирала `docker run` от Урок 3, който беше по-нагоре в същия чат. А утре шефът ти иска отчетът да показва три услуги едновременно — една здрава, една бавна и една неработеща, — за да го покаже на срещата. Това са четири контейнера, с ред на стартиране, и някой ще трябва да помни всичко. 6:10 е. Въпросът вече не е как се стартира контейнер, а **как се пише цяла система така, че никой да не трябва да помни нищо**. Този урок съществува, за да ѝ изпратиш утре един-единствен файл и една-единствена команда и онова, което тя стартира, да е точно онова, което ти си тествал, с подсилена защита, с токена извън файла и с отчета на мястото му.

**Време:** 2 × 45 мин

**Какво изграждаш:** `compose.yaml` в папката ти `revisor/`, който описва цялата система: `revisor`, изграден от своя Dockerfile, и три копия на тестовата услуга (здрава, бавна и неработеща), така че отчетът да показва `OK`, `LENTO` и `FALLA`, без да пипаш нищо ръчно. Двете мрежи от Урок 8 (една нормална и една вътрешна без изход), томът на отчета, токенът като тайна на Compose и всички опции за сигурност от Уроци 2 до 8, написани един-единствен път. С `docker compose up -d --build` системата се стартира от нулата; с `docker compose down` се спира, без отчетът да се загуби.

**Какво научаваш:** какво е Compose и какво е проект; как всяка опция на `docker run` се превежда в ключ на файла; `docker compose config` за валидиране и за да видиш какво е разбрал Compose; `up`, `ps`, `logs`, `stop` и `down`, и защо, ако поискаш `up` два пъти, вторият път не прави нищо; как Compose именува своите контейнери, мрежи и томове; `depends_on` със `service_healthy` и защо „стартиран“ не значи „готов“; тайните на Compose и капана с правата им; котвите на YAML и полетата `x-`, за да не се повтаряш; `pull_policy: never`; грешката на три услуги, които изграждат един и същ образ, и тази на `--wait` с услуга, която се проваля нарочно; и какво е `docker init` и защо не го използваме.

**Откъде идваш.** От [Урок 8](08-volumenes-y-redes.md) носиш крайното състояние, което този урок пренася във файл: образа `curso-docker-revisor:1.5.0`, който по подразбиране пази отчета си в `/datos` и носи тази папка със собственик `65532`; тома на отчета; нормалната мрежа, през която се публикува портът, и вътрешната мрежа без изход, в която живее тестовата услуга. От [Урок 7](07-salud-y-ciclo-de-vida.md) носиш опциите с подсилена защита (`--read-only`, `--cap-drop ALL`, `no-new-privileges`, `--init`, ограничения), политиката за рестартиране `unless-stopped` и едно обещание: да използваш проверката на състоянието, за да подредиш стартирането на няколко услуги. От [Урок 6](06-configuracion-y-secretos.md) носиш токена в `secretos/revisor_token.txt`, с права `644` (права, които са приемливи само за симулиран токен: в 9.8.3 ще измериш кой може да го прочете, а в 9.8.4 ще го затвориш), и още едно обещание: тайните на Compose. А от [Урок 2](02-contenedores-dia-a-dia.md) — образа `curso-docker-prueba:1.0.0` и навика да публикуваш портове само на `127.0.0.1`. Папката ти има `revisor/` (със своя `Dockerfile`, своя `.dockerignore` и `secretos/`), а до нея — `servicio-prueba/`.

**Какво не прави този урок.** Не променя Dockerfile: образът е същият 1.5.0 от Урок 8, само че сега го изгражда Compose. Не учи Docker Swarm, нито полетата на `deploy`, които имат смисъл само в клъстер: този курс работи на един компютър, а преходът към няколко компютъра е курсът по Kubernetes. Не използва профили, файлове за заместване (`compose.override.yaml`), нито `include`: те са полезни, когато един проект порасне, а с един-единствен файл първо се научава онова, което всички те комбинират. Не използва `docker compose watch`, нито монтиране на код за разработка, защото `revisor` тук се предава, а не се програмира. И не публикува образа в никакъв регистър: това е [Урок 10](10-entregar-la-imagen.md).

**За изпълненията.** Всички изходи са реални и са получени на 21 октомври 2026 г. на Mac с [Colima](https://github.com/abiosoft/colima), която стартира виртуална машина с Ubuntu 24.04.4, същата основа като Linux Mint 22, референтната система на курса, с ядро 6.8 и процесор `arm64`. Скриптовете бяха пуснати **вътре** в тази виртуална машина, с Docker 29.2.1 (клиент и демон), **Docker Compose v5.0.2** и Buildx v0.31.1, и с работната им папка на собствения диск на Linux; това е важно в раздел 9.10, който се занимава с правата на файл, защото папките, споделени между Mac и виртуалната машина, лъжат за тях. В твоя Mint този проблем не съществува. Курсът беше планиран с Docker Engine 29.8.2 и Compose v5.6.0 (измерени на 7 октомври), а най-новата публикувана версия на Engine в деня на изпълненията беше 29.9.2, от 20 октомври 2026 г. ([бележки към версиите](https://docs.docker.com/engine/release-notes/29/)); не очакваме нищо от този урок да се промени между тези версии, но изходите са измерени с Compose v5.0.2: ако твоята версия дава друг текст при грешка, сравни го по смисъла. Провери своите с `docker version` и `docker compose version`. **Имената.** За да не пипат твоето, скриптовете използват собствен проект на Compose, `curso-docker-fig09`, и собствени образи, `curso-docker-revisor:fig09` и `curso-docker-prueba:fig09`; така никога не пипат твоя проект `curso-docker`, твоя `curso-docker-revisor:1.5.0`, нито твоя `curso-docker-prueba:1.0.0`, а при излизане изтриват само онова, което са създали. Затова в изходите контейнерите се казват `curso-docker-fig09-revisor-1`, а не `curso-docker-revisor-1`, както ще се казват в твоята папка (раздел 9.4 обяснява откъде идва всяка част от името). Освен това, тъй като на същата машина работеха и други уроци, скриптовете бяха пуснати с друг префикс и друг порт (променливите `PREFIJO` и `PUERTO`, които имат); функцията `nombres`, видима във всеки скрипт, изписва отново този префикс като `curso-docker-` и порта като `8080`, а със стойностите по подразбиране не променя нищо. Което **се** променя от едно изпълнение до друго, и се казва там, където се появява: времената в таблицата на `revisor` (скрити с `<t>`, и затова понякога колоната остава с един интервал по-наляво или по-надясно), секундите на `Up N`, номерът на временния файл на отчета (`<n>`), датите, редът на някои събития, които стават едновременно, услугата, която назовава грешка при валидиране, и, в 9.11, при кои опити и в коя от трите услуги става сблъсъкът. Програмите са в [`programas/09-compose/`](../programas/09-compose), всяка с изхода си до нея, а `estado/` пази файловете на проекта такива, каквито остават накрая.

## След урока ще можеш да

- Преведеш командите `docker run`, `docker network create` и `docker volume create` от Урок 8 в `compose.yaml` без `version:` и да обясниш кой ключ на коя опция отговаря.
- Валидираш файла с `docker compose config --quiet` и да разчетеш в `docker compose config` дългата форма на онова, което си написал кратко.
- Стартираш, наблюдаваш и спираш системата с `up -d --build`, `ps`, `logs`, `stop` и `down` и да предскажеш кои контейнери Compose пресъздава, когато промениш файла.
- Предизвикаш и обясниш `500` с `read-only file system`, когато `revisor` с подсилена защита няма нищо монтирано в `/datos`.
- Подредиш стартирането с `depends_on` и `condition: service_healthy` и да обясниш защо `revisor` чака само здравото копие.
- Предадеш токена като тайна на Compose, да провериш, че не се появява в `docker inspect`, нито в `docker compose config`, и да диагностицираш `permission denied` на файл с `600`.
- Измериш кой може да чете файла на токена с `644`, `600` и `640` (с `ls -l`, `stat` и акаунт без привилегии) и да го оставиш с минималните права, които все още позволяват на `revisor` да работи.
- Разпознаеш сблъсъка на три услуги, които изграждат един и същ таг, и провала на `up --wait` с услуга, която е неработеща нарочно, и да избереш правилната алтернатива.

## Защо, преди как

Онова, което направи в Урок 8, работи и точно така трябва да се учи: всяка част със своята команда, за да видиш какво допринася. Но има три проблема, които се появяват в деня, в който някой друг го използва, или в деня, в който самият ти го използваш три седмици по-късно.

Първият е, че **системата живее в историята ти**. Шест команди, в ред, който има значение, с опции, които никой не пише еднакво два пъти. Сцената от началото не е преувеличена: стига да се прескочи един `docker network connect` и `revisor` не намира тестовата услуга, стига да се копира грешният `docker run` и подсилената защита от Урок 7 се губи, без нищо да предупреди. Услуга, която зависи от това някой да помни шест команди, всъщност зависи от паметта на този човек.

Вторият е, че **редът се спазва ръчно**. Мрежите преди контейнерите, томът преди `revisor`, тестовата услуга преди онзи, който я проверява. А при спиране — обратното: първо контейнерите, защото мрежа или том в употреба не се изтриват. В Урок 8 ти спазваше този ред; с четири контейнера вместо два и с един, който трябва да изчака друг да е **здрав**, а не само да работи, редът вече не се побира в главата.

Третият е, че **няма как да разбереш какво работи в сравнение с онова, което би трябвало**. Ако утре смениш режима на една тестова услуга, кои контейнери трябва да изтриеш и да създадеш отново? С `docker run` отговорът го даваш ти. Идеалното е инструмент да сравни поисканото със съществуващото и да пипне само онова, което се е променило.

Compose решава и трите неща с една идея: **да се опише системата във файл и да се остави инструмент да я накара да съществува**. Документацията му го определя като „инструмент за дефиниране и изпълнение на приложения от няколко контейнера“ ([Docker, „Docker Compose“](https://docs.docker.com/compose/)). Файлът, `compose.yaml`, казва какви услуги има, в какви мрежи живеят, какви томове и какви тайни използват и с какви опции работят. Командата `docker compose up` чете файла, сравнява го с онова, което вече съществува, и създава, пресъздава или оставя на мира необходимото, в правилния ред. Файлът се пази заедно с кода, преглежда се като кода и се изпраща на стажантката вместо шест команди.

С тази цел пред очи, ето какво ще имаш накрая, в раздел 9.9: цялата система, стартирана с една команда, и отчета на `revisor`, който показва трите поведения на тестовата услуга, без да си пипал нищо ръчно:

```text
$ tabla
SERVICIO  ESTADO    TIEMPO  DETALLE
caido     FALLA        <t>  codigo 503
lento     LENTO     <t>  200
sano      OK            <t>  200
```

(Това е блок 3 на `fig09_05.sh`; интервалите преди `<t>` се променят според скритото време.) Тази таблица е първата от целите на курса: „`docker compose up` стартира всичко от нулата, а отчетът показва неработещата тестова услуга като `FALLA`“.

## Понятията

### 9.1 Какво е Compose и какво е проект

#### 9.1.1 Един *plugin*, един файл, една спецификация

Compose идва с инсталацията от Урок 1: пакетът `docker-compose-plugin` добавя подкомандата `docker compose` (с интервал). Това не е отделна програма, която трябва да инсталираш с `pip`, нито двоичен файл, който изтегляш ръчно; това е разширение на клиента `docker` и затова версията му се пита с `docker compose version`.

Файлът се казва `compose.yaml`. Документацията казва, че пътят по подразбиране е `compose.yaml` („предпочитан“) или `compose.yml` в работната папка и че Compose приема и `docker-compose.yaml` и `docker-compose.yml` „за съвместимост с по-стари версии“ ([Docker, „How Compose works“](https://docs.docker.com/compose/intro/compose-application-model/)). Този курс използва предпочитаното име.

Онова, което влиза във файла, не го измисля Docker всяка година: определя го **спецификацията на Compose**, публичен документ, който описва всеки ключ и какво означава ([спецификация на Compose](https://docs.docker.com/reference/compose-file/)). Елементите от най-горното ниво, които ще използваш днес, са пет: `name`, `services`, `networks`, `volumes` и `secrets`. Има и други, които този урок не използва: `configs` (конфигурационни файлове, които не са тайни; `revisor` се конфигурира с променливи и няма нужда от него), `include` (за обединяване на няколко файла) и `models` (който, според спецификацията, „декларира AI моделите, които използва твоето приложение на Compose“, [спецификация, `models`](https://docs.docker.com/reference/compose-file/models/)); и `version`, който вече е остарял (9.2.3). Документацията ги представя така: компонентите на едно приложение „се дефинират като услуги“, услугите „комуникират помежду си чрез мрежи“ и „пазят и споделят постоянни данни в томове“ ([Docker, „How Compose works“](https://docs.docker.com/compose/intro/compose-application-model/)).

#### 9.1.2 Услугата не е контейнер

Ето първата нова идея и е добре да не я подминаваш бързо. В Урок 8 създаваше **контейнери**: `curso-docker-revisor`, `curso-docker-prueba`. В Compose описваш **услуги**: `revisor`, `prueba`. Услугата е рецептата („стартирай този образ, с тези опции, в тези мрежи“); контейнерът е онова, което излиза от прилагането на рецептата. Обикновено една услуга дава един контейнер, но разликата има значение по две причини, които ще видиш в урока. Първо: името, което е добре да се използва, за да се намери чрез DNS, е това на **услугата** (`prueba`), а не на контейнера. Името на контейнера също се разрешава вътре в мрежата (проверено е), но съдържа името на проекта и номер на реплика, които се променят от папка до папка. Второ: когато промениш рецептата, Compose изхвърля стария контейнер и създава нов; услугата остава същата.

#### 9.1.3 Проектът: фамилията на всичко

**Проектът** е, според документацията, „отделно разгръщане на спецификация на приложение“ ([Docker, „How Compose works“](https://docs.docker.com/compose/intro/compose-application-model/)). На практика това е името, което Compose слага пред всичко, което създава, за да знае кое е негово. `compose.yaml` на курса започва с `name: curso-docker` и затова всичко, което създава, носи това име: контейнери, мрежи и томове. Ако не го напишеш, Compose използва името на папката, в която е файлът, което в твоя случай би било `revisor`: твърде обща фамилия, за да я разпознаеш сред други проекти.

Името на проекта може да се зададе по пет начина и документацията казва кой печели: първо опцията `-p` на командния ред; след това променливата на средата `COMPOSE_PROJECT_NAME`; след това `name:` във файла; след това името на папката на файла; и накрая името на текущата папка. Приема само „малки букви, десетични цифри, тирета и долни черти“ ([Docker, „Specify a project name“](https://docs.docker.com/compose/how-tos/project-name/)). Същата страница казва за какво служи: „Compose използва име на проект, за да изолира средите една от друга“. Скриптовете в този урок се възползват от това: задават `COMPOSE_PROJECT_NAME=curso-docker-fig09`, което печели пред `name:` във файла, и така изпълнението им никога не се смесва с твоя проект `curso-docker`, макар файлът да е същият.

### 9.2 От `docker run` към файла

#### 9.2.1 Крайното състояние от Урок 8, написано веднъж

Първо конкретното. Ето крайното състояние от Урок 8, това от раздел 8.10.3, във файл. Запази го в папката си `revisor/` с име `compose.yaml`:

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

Чети го отдолу нагоре — така го изгражда Compose. Накрая са **мрежите** и **томът**: `publica`, `interna` (с `internal: true`, `--internal` от Урок 8) и `reportes`. Празните фигурни скоби `{}` казват „с опциите по подразбиране“: мрежа `bridge` и локален том. Отгоре са двете **услуги**. Всяка услуга изброява мрежите си по краткото име (`publica`, `interna`) и монтира тома по краткото име (`reportes:/datos`); Compose им слага фамилията на проекта, когато ги създава. Тестовата услуга е само във `interna`; `revisor` — в двете. Точно както в 8.10.3, но без стъпката `docker network connect`, която стажантката забрави: тук няма стъпки, има описание.

#### 9.2.2 Всяка опция — своя ключ

Почти всяка опция на `docker run` има ключ с подобно име. Тази таблица е тази, която ще използваш, за да превеждаш всяка команда от предишните уроци:

| `docker run` | `compose.yaml` | Бележка |
|---|---|---|
| `curso-docker-revisor:1.5.0` (образът) | `image:` | с `build:` до него, това е името, което получава изграденият образ |
| `docker build --build-arg VERSION=1.5.0 .` | `build: { context: ., args: { VERSION: "1.5.0" } }` | Compose изгражда, преди да създаде контейнера |
| `-e REVISOR_SERVICIOS=…` | `environment:` | като речник (`КЛЮЧ: стойност`), без кавички, които да стигнат до стойността |
| `-p 127.0.0.1:8080:8080` | `ports: ["127.0.0.1:8080:8080"]` | адресът `127.0.0.1` се пише както в Урок 2 |
| `-v curso-docker-reportes:/datos` | `volumes: [reportes:/datos]` + `volumes:` отгоре | томът се декларира веднъж на най-горното ниво |
| `--network …` и `docker network connect …` | `networks: [publica, interna]` + `networks:` отгоре | всички мрежи на услугата в един списък |
| `--read-only` | `read_only: true` | |
| `--cap-drop ALL` | `cap_drop: [ALL]` | |
| `--security-opt no-new-privileges` | `security_opt: ["no-new-privileges:true"]` | |
| `--init` | `init: true` | |
| `--memory 64m`, `--cpus 0.5`, `--pids-limit 50` | `mem_limit: 64m`, `cpus: 0.5`, `pids_limit: 50` | |
| `--restart unless-stopped` | `restart: unless-stopped` | появява се в крайния файл (9.9) |
| `--name curso-docker-revisor` | (нищо) | името го слага Compose: проект, услуга и номер |

Справочникът на услугите описва всеки от тях със същото намерение, което познаваш от Урок 7: `read_only` създава контейнера „с файлова система само за четене“; `init` изпълнява „процес init (PID 1) вътре в контейнера, който препраща сигнали и събира процеси“; `cpus` определя колко CPU, „потенциално виртуални“, му се отделят; а `pids_limit` задава ограничението на процесите ([справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/)). Няма нова магия: това са същите опции на демона, написани на друго място.

Два от ключовете в таблицата заслужават още едно изречение. Първият, `security_opt`: справочникът казва, че булевите опции като `no-new-privileges` могат да се пишат по три равностойни начина (`no-new-privileges`, `no-new-privileges=true` и `no-new-privileges:true`). Курсът използва последния, защото оставя най-малко съмнения. Вторият, `depends_on: [prueba]`: той няма еквивалент в `docker run`, защото подреждането на контейнерите беше твоя работа. Казва на Compose, че `revisor` се създава и стартира след `prueba`. По-нататък (9.7) ще видиш, че „след“ не означава „когато вече е готов“.

#### 9.2.3 Без `version:`

Файлът не започва с `version: "3.8"`, нито с нещо подобно, и това не е небрежност. Спецификацията казва, че елементът `version` съществува само за съвместимост, че „е само информативен“ и че ако го използваш, ще получиш „предупреждение, че е остарял“ ([спецификация, `version` и `name`](https://docs.docker.com/reference/compose-file/version-and-name/)). Ще го видиш в почти всички ръководства отпреди няколко години, защото старият Compose го изискваше, за да знае какви ключове да приема. Днешният прилага актуалната спецификация във версията, която имаш инсталирана, и няма нужда от това поле. Ако го срещнеш, изтрий го.

### 9.3 Валидиране и разчитане на онова, което Compose е разбрал

#### 9.3.1 `docker compose config`

Преди да стартираш каквото и да е, е добре да знаеш дали файлът е валиден и дали Compose е разбрал онова, което си искал да кажеш. За това съществува `docker compose config`, който според справочника си „показва реалния модел на данни, който ще бъде приложен в Docker Engine“: разрешава променливите и „разгръща кратката нотация до каноничната форма“ ([справочник на `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/)). Три опции го правят полезен в ежедневието: `--quiet` само валидира и не отпечатва нищо (ако файлът е грешен, грешката излиза и кодът не е 0); `--services` изброява услугите, по една на ред; а `--volumes` — томовете.

Скриптът `fig09_02.sh` взема първия ти `compose.yaml` и го прекарва през целия цикъл: валидиране, разчитане, стартиране, повторно искане и спиране. Това е първият скрипт в урока, затова тук е целият; следващите повтарят същото начало (помощните имена, работната папка и функциите `muestra`, `eventos`, `esperar` и `tabla`) и в урока се показва само частта, която се променя:

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

А ето изхода му:

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

#### 9.3.2 Разчитане на блокове 1 и 2

1. **Валиден, с две услуги и един том.** `config --quiet` не отпечатва нищо, ако файлът е наред; `echo` на скрипта го казва вместо него. Обърни внимание, че `prueba` излиза преди `revisor`, макар във файла да си я написал след него. Compose не изброява по реда, в който си писал: първо излизат зависимостите, а накрая — онзи, който зависи от тях, и това го решава `depends_on`. (Ще го видиш по-ясно в 9.9, с четири услуги: първо трите копия на тестовата услуга, помежду си по азбучен ред, и накрая `revisor`. Онова, което наистина варира от изпълнение до изпълнение, е редът на събитията на `up`, защото няколко неща стават едновременно.)
2. **Дългата форма.** Ето какво наистина иска да знае онзи, който преглежда чужд файл. Твоят `depends_on: [prueba]` е станал `condition: service_started` и `required: true`: кратката форма е дългата със стойностите по подразбиране. Твоят `"127.0.0.1:8080:8080"` е станал блок с `host_ip: 127.0.0.1`, `target: 8080` (портът на контейнера) и `published: "8080"` (този на компютъра ти): ако някога се съмняваш кое число какво е, `config` ти го казва с имена. Твоят `reportes:/datos` е станал `type: volume`, `source: reportes`, `target: /datos`. А във втората команда `mem_limit: 64m` се появява като `"67108864"`, което са 64 × 1024 × 1024 байта, същото число, което `docker inspect` ти показа в Урок 2. `config` е най-добрият инструмент за преглед на `compose.yaml`, който не си писал ти: не ти казва какво е искал авторът, казва ти какво ще стане.

Един навик, който е добре да приемеш още днес: **всеки път, когато редактираш файла, пускай `docker compose config --quiet` преди `up`**. Грешка в отстъпа в YAML променя смисъла, без да дава синтактична грешка (ключ, който е останал вътре в грешната услуга, например), а `config` е мястото, където го виждаш, преди контейнерът да стартира с друга конфигурация.

### 9.4 Стартиране, наблюдение и спиране

#### 9.4.1 `up`: създаване на липсващото, по ред

`docker compose up` е централната команда. Справочникът му я обобщава в един ред: „изгражда, (пре)създава, стартира и се закача към контейнерите на една услуга“ ([справочник на `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). С `-d` („откачен режим“) оставя контейнерите във фонов режим и ти връща терминала; с `--build` изгражда образите преди стартиране, дори да съществуват.

Блок 3 на `fig09_02.sh` показва какво е направил, в реда, в който го е направил. Първо **двата образа**, `Built`. След това **мрежите**, `curso-docker-fig09_interna` и `curso-docker-fig09_publica`, и **томът**, `curso-docker-fig09_reportes`. След това **контейнерите**: `Created` и двата и `Started` първо `prueba`, а после `revisor`, защото `revisor` зависи от него. Това е редът, който в Урок 8 спазваше ръчно, сега решен от файла. (Скриптът маха от списъка междинните редове, като `Building`, `Creating` или `Starting`, за да се четат резултатите; в терминала си ще ги видиш всички.)

#### 9.4.2 Как се казват нещата

Погледни внимателно имената, защото ще ги пишеш в `docker inspect`, в `docker logs` и в помощника `alpine`:

- **Контейнери**: `<проект>-<услуга>-<номер>`. В изхода — `curso-docker-fig09-revisor-1`; в твоята папка, с `name: curso-docker` — `curso-docker-revisor-1`. Номерът съществува, защото една услуга може да има няколко реплики; тук винаги е `1`.
- **Мрежи и томове**: `<проект>_<име>`, с долна черта. `curso-docker-fig09_interna`, `curso-docker-fig09_reportes`; в твоята папка — `curso-docker_interna` и `curso-docker_reportes`.

Тъй като проектът започва с `curso-docker`, всичко продължава да има префикса на курса и навикът от Урок 2 (да можеш да изтриеш нещата на курса, без да пипаш останалото) се запазва. Освен това Compose слага на всяко нещо, което създава, етикета (label) `com.docker.compose.project=<проект>`. Това е чистият начин да попиташ „какво е на този проект“, и блок 5 го използва: `docker volume ls --filter label=com.docker.compose.project=…`.

И един въпрос, който сигурно си задаваш: ако контейнерът се казва `curso-docker-fig09-prueba-1`, защо `revisor` го търси като `http://prueba:9000/`? Защото в мрежите на един проект всеки контейнер се регистрира във вградения DNS (`127.0.0.11` от Урок 8) с името на своята **услуга**, а също и със собственото си; при отделна проба двете имена се разрешиха до един и същ адрес. Това на услугата е онова, което е добре да пишеш, защото е единственото, което не зависи от проекта, нито от номера на репликата. Документацията го обяснява със своя пример: контейнерът на услугата `web` се присъединява към мрежата „с името `web`“ ([Docker, „Networking in Compose“](https://docs.docker.com/compose/how-tos/networking/)). Това ти позволява да пишеш `REVISOR_SERVICIOS`, без да знаеш как ще се казва проектът: един и същ файл работи в твоята папка, в тази на стажантката и в скрипта.

Същата страница казва какво става, ако не декларираш мрежи: Compose създава **една** мрежа, `<проект>_default`, и свързва там всички услуги. Твоят файл декларира своите и затова в изхода няма нито една `_default`. Това не е детайл: с мрежата по подразбиране на Compose тестовата услуга би имала изход към интернет, а Урок 8 реши, че няма нужда от него.

#### 9.4.3 `ps`: какво има и как е

`docker compose ps` е `docker ps` на проекта: показва само неговите контейнери. Блок 3 го използва със собствен формат (име, състояние и портове) и скрива секундите на `Up` с `Up N`. Двата са `(healthy)`, защото двата образа носят своя `HEALTHCHECK` от Уроци 2 и 7, а портът на `revisor` е на `127.0.0.1:8080`. Тестовата услуга не публикува нищо: няма нужда, `revisor` говори с нея през вътрешната мрежа. А таблицата на `revisor` казва `prueba OK`.

#### 9.4.4 Да поискаш `up` отново: нищо не става, и това е хубавото

Блок 4 пуска отново `docker compose up -d`, без да променя нищо. Compose отговаря `Running` за двата и не пипа нито един. Това е най-важната разлика със скрипт от `docker run`: повторен скрипт се опитва да създаде отново и се сблъсква с повтореното име от Урок 2. Compose, напротив, **сравнява** онова, което искаш, с онова, което има. Справочникът на `up` го казва така: ако конфигурацията или образът на дадена услуга са се променили, Compose „поема промените, като спира и пресъздава контейнерите“, и запазва монтираните томове ([справочник на `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Ако нищо не се е променило, нищо не се пипа. Затова `docker compose up -d` е безопасно да се повтаря: това е начинът да кажеш „нека това съществува“, а не „създай това“.

#### 9.4.5 `down`: томът остава

Блок 5 спира с `docker compose down`. Спира и изтрива контейнерите (първо `revisor`, който зависи от `prueba`; Compose спира в обратния ред на зависимостите) и изтрива мрежите. А томът **остава**: `docker volume ls` продължава да го показва. Справочникът на `down` изброява какво изтрива по подразбиране: контейнерите на услугите, мрежите от раздела `networks` и мрежата по подразбиране, ако е била използвана ([справочник на `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/)). Именуваните томове не са в този списък; за да ги изтриеш, трябва да го поискаш с `--volumes`, който изтрива „именуваните томове, декларирани в раздела `volumes`“. Това е правилното решение: спирането на системата не бива да ти струва отчета. В 9.12 ще го видиш да оцелява.

### 9.5 Грешката: `revisor` с подсилена защита без нищо в `/datos`

#### 9.5.1 Да я предизвикаш

От образа 1.5.0 от Урок 8 насам `revisor` пази отчета си в `/datos/reporte.json` **по подразбиране**: образът носи `REVISOR_REPORTE=/datos/reporte.json` в своя `ENV`. А `compose.yaml` го стартира с `read_only: true`. Какво става, ако някой, докато преписва файла на чисто, изтрие реда с тома, защото „отчета не го използваме“? Скриптът `fig09_03.sh` го прави видимо, със `sed`, и показва разликата с `diff`, преди да стартира. Частта от скрипта, която се различава от `fig09_02.sh`:

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

#### 9.5.2 Разчитане

1. **`diff`** показва двата липсващи реда (и излиза с `1`, което при `diff` означава „има разлики“, а не „провали се“). Файлът остава валиден: услуга без томове е напълно законна и затова `config --quiet` не би те спасил тук. Контейнерът стартира и стига до `(healthy)`, защото `/salud` не записва нищо. Docker е доволен.
2. **Но отчетът дава `500`**: `open /datos/.reporte-<n>.tmp: read-only file system`. Това е грешката от раздел 7.7 на Урок 7, в друга папка: `revisor` се опитва да създаде временния си файл в `/datos`, а `/datos` е част от файловата система на контейнера, която е само за четене. Отгоре няма нищо монтирано, което да приема записи. Обърни внимание, че `revisor` не пада и не се преструва: отговаря с `500` и с точната причина. Това е вторият принцип на курса в действие: контейнерът е `healthy`, а услугата не прави онова, което трябва.
3. **Поправката** — връщането на двата реда, и вторият урок за Compose за деня. `up -d` създава тома, който сега наистина се използва (`Volume … Created`), оставя тестовата услуга каквато си е (`Running`) и **пресъздава само `revisor`** (`Recreate`, `Recreated`, `Started`), защото конфигурацията му се е променила. Отчетът се връща на `200`.

Правилото, което отнасяш: **с `read_only: true` всяка папка, в която програмата пише, има нужда от нещо монтирано отгоре**. В `revisor` тя е само една, `/datos`, и файлът на курса винаги я монтира. Ако някой ден смениш `REVISOR_REPORTE` на друг път, този път също ще има нужда от свой том (или от свой `tmpfs`, ако не бива да трае).

### 9.6 Три копия на тестовата услуга, без да пишеш три пъти едно и също

#### 9.6.1 Защо три

С една-единствена тестова услуга отчетът винаги казва `OK`, освен ако не смениш режима ѝ ръчно с `POST /modo/caido`. Но тестовата услуга живее във вътрешна мрежа и не публикува порт: за да ѝ смениш режима, ще трябва да влезеш отнякъде другаде. Има по-добър начин да се покажат трите поведения едновременно и той е онзи, който шефът от сцената поиска: **три контейнера от един и същ образ, всеки стартиран в различен режим** с `PRUEBA_MODO`. Така отчетът показва `OK`, `LENTO` и `FALLA` веднага щом системата стартира, без да пипаш нищо.

Три почти еднакви услуги означават един и същ блок опции с подсилена защита, написан три пъти, а повторен блок е блок, който някой ден някой променя в две от трите копия. Compose има два инструмента за това и те се използват заедно.

#### 9.6.2 Полета `x-` и котви на YAML

Първият е правило на Compose: полетата от първо ниво, които започват с `x-`, се пренебрегват. Документацията го казва дословно: „Compose пренебрегва всяко поле, което започва с `x-`“, и това е „единственото изключение“, при което мълчаливо пренебрегва поле, което не разпознава; служат за „модуларизиране на конфигурации, които искаш да използваш отново“ ([спецификация, разширения](https://docs.docker.com/reference/compose-file/extension/)).

Вторият не е на Compose, а на YAML: **котвите** и **псевдонимите**. Котва се слага с `&име` пред блок; псевдоним, `*име`, се отнася до този блок; а ключът за сливане `<<: *име` копира ключовете на блока вътре в друг речник, където можеш да добавиш или замениш които искаш. Документацията на Compose предупреждава за два детайла: сливането „се прилага само за речници и не може да се използва с последователности“, а когато се използват фрагменти, променливите на средата се пишат като речник (`КЛЮЧ: стойност`), а не като списък (`- КЛЮЧ=стойност`) ([спецификация, фрагменти](https://docs.docker.com/reference/compose-file/fragments/)). Затова целият `environment` на курса е написан като речник.

Заедно изглеждат така, във фрагмент от крайния файл:

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

`x-prueba` не е услуга (Compose я пренебрегва), но съдържанието ѝ съществува за YAML с котвата `&prueba`. `prueba-lento` копира целия този блок с `<<: *prueba` и добавя своя `environment`. Блок 1 на `fig09_05.sh`, по-долу, ти го доказва, като иска от `config` услугата `prueba-lento`: появяват се `image`, `pull_policy`, `read_only`, `mem_limit` и `networks`, които не са написани в услугата, а в котвата.

#### 9.6.3 Кой изгражда, и `pull_policy: never`

Остава едно решение: кой изгражда образа `curso-docker-prueba:1.0.0`? Ако котвата съдържаше `build: ../servicio-prueba`, трите копия щяха да го наследят и Compose би пуснал **три едновременни изграждания на един и същ таг**. Това води до сблъсък и в 9.11 ще го предизвикаш. Крайният файл прави друго: само `prueba-sano` има `build`. Другите две използват образа, който изгражда първата.

А за да не тръгнат тези две да го търсят в интернет, котвата съдържа `pull_policy: never`. Справочникът го определя така: с `never` Compose „не изтегля образа от регистър и разчита на образа, запазен на платформата“ ([справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/)). Какво става без този ред? Ще го измериш в блок 2 на `fig09_07.sh` (раздел 9.11): на машина, на която образът още не съществува, Compose първо тръгва да го търси в Docker Hub за всяка услуга, която не го изгражда, получава два пъти `pull access denied` от Урок 2 и след това, тъй като друга услуга в проекта го изгражда, продължава, изгражда го и стартира всичко. Работи, но прави заявки към интернет, които не ти трябват, пълни изхода с грешки, които не са грешки, и оставя резултата в ръцете на онова, което някой е публикувал с това име. С `pull_policy: never` името на образа престава да бъде въпрос към интернет и става препратка към нещо, което ти си изградил.

Едно последствие, което е добре да знаеш: тъй като само `prueba-sano` изгражда, ако поискаш отделна услуга на компютър, на който образът още не съществува (например `docker compose up prueba-lento` веднага след клониране на проекта), няма кой да го изгради. При отделна проба с несъществуващ образ и `pull_policy: never` Compose завърши с код `1` и съобщението `No such image`. Стартирай целия проект с `docker compose up -d --build` или първо изгради с `docker compose build prueba-sano`.

### 9.7 „Стартиран“ не значи „готов“: `depends_on` с условие

#### 9.7.1 Какво прави `depends_on` по подразбиране

В първия файл написа `depends_on: [prueba]`, а `config` ти показа, че това е `condition: service_started`. Документацията е много ясна за това какво означава: „При стартиране Compose не чака контейнерът да е „готов“, а само да работи“ ([Docker, „Control startup order“](https://docs.docker.com/compose/how-tos/startup-order/)). Това е същото объркване от Урок 7, пренесено в реда на стартиране: процесът съществува, но може би още не обслужва.

#### 9.7.2 Трите условия

Дългата форма на `depends_on` приема три условия ([справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/)):

| Условие | Compose чака зависимостта да… |
|---|---|
| `service_started` | работи (това прави кратката форма) |
| `service_healthy` | е „здрава“, според своя `healthcheck` |
| `service_completed_successfully` | приключи успешно (за еднократни задачи, като подготовка на нещо предварително) |

Условието в този урок е `service_healthy`: „Compose чака да минат проверките на състоянието на зависимостите, отбелязани със `service_healthy`“ ([Docker, „Control startup order“](https://docs.docker.com/compose/how-tos/startup-order/)). За това зависимостта има нужда от проверка на състоянието, а тестовата услуга я носи в образа си от Урок 2 (на всеки 5 s, с 2 повторни опита). Това е обещанието от Урок 7: проверката на състоянието не рестартира нищо, но някой я използва. Днес я използва Compose.

#### 9.7.3 Защо `revisor` чака само здравата

Ето най-финото решение във файла и то заслужава да се чете бавно. `revisor` зависи от трите копия, но **не** със същото условие:

```yaml
    depends_on:
      prueba-sano:
        condition: service_healthy
      prueba-lento:
        condition: service_started
      prueba-caido:
        condition: service_started
```

Помисли какво би станало, ако и трите бяха `service_healthy`. `prueba-caido` отговаря винаги с `503`: проверката на състоянието ѝ **никога** не минава, така че Compose би чакал Docker да я обяви за `unhealthy` (с 2 повторни опита на всеки 5 s — около десет секунди) и тогава би се отказал: при отделна проба със зависимост, която винаги се проваля (проверка на всеки 2 s, 2 повторни опита), `docker compose up -d` завърши за 5 s с код `1` и съобщението `dependency failed to start: container ... is unhealthy`, а услугата, която зависеше от нея, остана в `Created`, без да стартира. Това е същата грешка, която ще видиш в 9.11.3. Резултатът е един и същ: `revisor` никога не би стартирал. И `prueba-lento` също: проверката ѝ изисква отговор за по-малко от 2 секунди, а в бавен режим тя отнема 3. Услугите, които се провалят нарочно, не могат да бъдат здрави, защото провалът е тяхната работа. Онова, което `revisor` има нужда, е те да **съществуват** (за да е името им в DNS) и поне една да е готова, за да има първият отчет какво да каже. Затова: здравата — `service_healthy`; другите — `service_started`.

Това е общото правило и ще го използваш във всичките си проекти: **`service_healthy` за онова, което услугата ти има нужда да е здраво, за да стартира (база данни, например), и `service_started` за онова, за което ѝ стига да съществува**. И едно честно предупреждение: `depends_on` подрежда само **стартирането**. Ако някоя зависимост падне час по-късно, Compose не спира, нито рестартира онзи, който зависи от нея. `revisor` се справя добре с това, защото работата му е точно да докладва за онзи, който не отговаря.

### 9.8 Тайни на Compose

#### 9.8.1 Какво са и къде се появяват

В Урок 6 монтира токена с `--mount type=bind` на един-единствен файл, в `/run/secrets/revisor_token`, и каза къде сочи с `REVISOR_TOKEN_ARCHIVO`. Compose има елемент за това. Документацията му определя тайната като „всякакви данни, като парола, сертификат или API ключ“, които не бива да пътуват без защита, и казва къде се появява: тайните „се монтират като файл в `/run/secrets/<име_на_тайната>` вътре в контейнера“ ([Docker, „Secrets in Compose“](https://docs.docker.com/compose/how-tos/use-secrets/)). Затова `revisor` използва този път от Урок 6 насам: това е конвенцията на Compose.

Декларират се на две места, като мрежите и томовете. Отгоре — откъде идва:

```yaml
secrets:
  revisor_token:
    file: ./secretos/revisor_token.txt
```

А в услугата — кой я получава:

```yaml
    secrets:
      - revisor_token
```

Тази втора част е важна: „услугите имат достъп до тайните само когато им е даден изрично с атрибут `secrets`“ ([Docker, „Secrets in Compose“](https://docs.docker.com/compose/how-tos/use-secrets/)). Трите копия на тестовата услуга не я получават и затова не я виждат. Стойността никога не се пише във файла: `compose.yaml` казва **къде** е токенът, а не **какъв** е. Така файлът може да отиде в хранилището, а `secretos/` — не: това са два файла за изключване, по един за всяка цел. `.dockerignore` я оставя извън образа (прави го от Урок 6 насам), а `.gitignore` я оставя извън хранилището (9.8.4). Материалът на този курс наистина съдържа своята папка `secretos/` в хранилището, нарочно, защото токенът му е симулиран; твоята, с истински токен — не.

#### 9.8.2 Капанът: правата са тези на файла

Следващото е най-важното в този раздел, защото е грешка, която документацията обяснява в една бележка и която почти никой не чете. Дългата форма на тайна в услугата приема `uid`, `gid` и `mode`, и те изглеждат като идеалното решение: „файлът вътре в контейнера да е на потребител 65532, с права `0400`“. Но **когато тайната идва от файл, Compose ги пренебрегва**. Справочникът го казва така: с файл като източник Compose използва отдолу монтиране, което не позволява смяна на собственика, „и тези атрибути се пренебрегват безшумно“; работят само когато тайната идва от променлива на средата ([справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/)).

На практика това означава, че тайната на Compose е **същото монтиране от Урок 6**, със собственика и правата, които файлът има на компютъра ти. Ако файлът е с `600`, само твоят потребител го чете; `revisor` работи като `65532`; резултатът е `permission denied` и `revisor` излиза с код 1. Ако е с `644`, го чете. Ще го предизвикаш в 9.10, с декларирани `uid`, `gid` и `mode`, за да видиш, че не променят нищо. Затова курсът използва кратката форма (`- revisor_token`): да пишеш `uid`, `gid` и `mode` при тайна от файл не служи за нищо друго, освен да създаде фалшиво усещане за сигурност.

Практическото последствие е, че **правата на файла на компютъра ти са решение за сигурност, което взимаш ти**, а не Compose. `644` позволява на `revisor` да стартира, но позволява и на всеки друг акаунт на компютъра ти да прочете токена. Следващите два раздела го измерват и показват безопасния начин; раздел 6.5.4 от Урок 6 казва същото, с други думи.

#### 9.8.3 Измерване на това кой може да прочете токена

Права като `644` са три цифри, по една за всяка група хора: **собственика** на файла, **групата** на файла и **всички останали**. Всяка цифра събира `4` (четене), `2` (запис) и `1` (изпълнение). Така `644` е „собственикът чете и пише (`6 = 4 + 2`), групата чете (`4`) и всички останали четат (`4`)“. „Всички останали“ не е начин да се каже „ти“: това е **всеки акаунт на компютъра ти**, този на друг човек с отворена сесия на споделен сървър, този на услуга, която работи със собствен потребител, или този на програма, която някой е успял да пусне като друг потребител. С `600` го чете само собственикът, а с `640` го четат собственикът и групата, и никой друг.

Проверява се с две команди. `ls -l secretos/` показва правата с букви: `-rw-r--r--` е `644`, `-rw-------` е `600`, а `-rw-r-----` е `640`. А `stat -c '%a %U:%G' secretos/revisor_token.txt` ги показва като число, заедно със собственика и групата. Когато номерът на собственика не съответства на никой акаунт на компютъра ти (`65532` на `revisor` не е акаунт), `stat` пише `UNKNOWN`; за да видиш номера, поискай го с `%u:%g` или използвай `ls -ln`.

Но да погледнеш правата не е същото като да ги **изпробваш**. Скриптът `fig09_11.sh` прави и двете и във всеки случай пита едно и също: чете ли го друг потребител без привилегии?, четеш ли го ти?, чете ли го `revisor`, който работи като `65532`? За „друг потребител“ използва `sudo -u nobody`: `nobody` е акаунт без привилегии, който идва с всеки Linux и служи, за да се представиш за който и да е друг потребител. Преди всяко `Permission denied` на `nobody` има контрола: `sudo -u nobody stat` доказва, че `nobody` **стига до файла** (папката е отворена), така че ако следващият `cat` се провали, то е заради правата на файла, а не заради нещо друго. (На тестовата машина личната папка е с `750` и това спира само онзи, който се опита да влезе в нея; не разчитай на това: проектът може да е на друг път или някой може да отвори папката някой ден.) Скриптът има нужда от `sudo`, за да се представи за `nobody` и за да смени собственика на файла. Случаи 3 и 4 следват **точно** опции B и A от 9.8.4, като тръгват от `644`, с който идваш от Урок 6. Частта, която се променя, със симулирания файл на токена:

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

Обобщение на показаното, случай по случай:

| Права и собственик | Чете ли го друг потребител? | Четеш ли го ти? | Чете ли го `revisor`? |
|---|---|---|---|
| `644`, твоят потребител | **да** | да | да |
| `600`, твоят потребител | не | да | **не** (`permission denied`) |
| `600`, собственик `65532` (опция B) | не | не, освен със `sudo` | да |
| `640`, твоят потребител, група `65532` (опция A) | не | да | да |

1. **`644`: чете го всеки.** Първият блок е находката: `sudo -u nobody cat` отпечатва целия токен. `revisor` стартира здрав и затова `644` изглежда като „решението“: работи. Но работи, защото отваря файла за всички, а не само за `revisor`.
2. **`600` на твоя потребител: затваря се, и се затваря и за `revisor`.** `nobody` получава `Permission denied`, но и `revisor` също: това е грешката от Урок 6 и от 9.10. Файлът е на твоя потребител, `revisor` е потребителят `65532`, а за ядрото `revisor` е „друг потребител“ като `nobody`. Редът `se reinició` потвърждава, че `revisor` влиза и излиза в цикъл.
3. **`600` със собственик `65532` (опция B): затворен за всички, освен за `revisor`.** Само собственикът на файла (`revisor`) и `root` могат да го четат. `nobody` получава `Permission denied`, и ти също, защото вече не си собственикът; за да го видиш или промениш, ти трябва `sudo cat`. `revisor` стига до `(healthy)` и таблицата излиза с токена. Цената: твоето удобство. А `UNKNOWN:UNKNOWN` в първия `stat` не е грешка: номерът `65532` няма име на акаунт на компютъра ти. Обърни внимание на **реда**: първо `chmod 600`, а после `sudo chown`.
4. **`640` с група `65532` (опция A): удобният изход.** Ти оставаш собственик (четеш го и го редактираш без `sudo`), а **групата** на файла е `65532`. `revisor` работи като `65532:65532` (потребител и група, които идват от образа: `docker inspect --format '{{.Config.User}}'`), така че за ядрото той влиза през цифрата на групата. `nobody` не е в тази група и не чете нищо. Това са минималните права, които позволяват на двете страни да работят. Важи същото като в Урок 6: числата вътре и отвън трябва да са еднакви (нормалната инсталация от Урок 1). С Docker без `root` или с пренасочване на потребителите `65532` вътре съответства отвън на друго число (началото на твоя диапазон в `/etc/subuid` и `/etc/subgid` плюс 65532; това начало се сменя от инсталация на инсталация и се чете в тези файлове. Като пример, [документацията на `userns-remap`](https://docs.docker.com/engine/security/userns-remap/) разказва, че с диапазон, който започва от `231072`, `231073` е потребител `1` вътре; `231072` е само стойността от този пример), и тази рецепта не важи такава, каквато е: `revisor` ще даде `permission denied`, и няма изтичане, но няма и бързо решение; диагнозата е тази с `ls -ln` от Урок 6.
5. **Папката `secretos/` със `700` не пречи.** Блок 5 я затваря (`chmod 700 secretos`), а `revisor` се пресъздава и остава `(healthy)`: монтирането на един-единствен файл го установява демонът, а не твоят потребител. Затвори и папката, не само файла: който не може да влезе в нея, дори не вижда, че токенът съществува.
6. **Грешният ред оставя токена отворен.** Блок 6 прави опция B наобратно: първо `sudo chown 65532:65532` и после `chmod 600`. `chmod` се проваля с `Operation not permitted`, защото вече не си собственикът, а ядрото позволява смяна на правата само на собственика (или на `root`). Файлът остава с `644`, сега на `65532`, а `nobody` отпечатва токена. Винаги **първо се затваря, после се подарява**, и накрая се проверява.
7. **Групата `65532` не е изключително на `revisor`.** Това е потребителят и групата `nonroot` в образите *distroless* (крайният образ на `revisor` е `gcr.io/distroless/static-debian13:nonroot`) и в тези на Chainguard, така че всеки контейнер от тези образи, на който монтираш този файл, го чете през цифрата на групата. А ако на компютъра ти съществуваше истинска група с този номер, членовете ѝ също. Затова последният блок пита `getent group 65532`: ако не отпечата нищо (както тук, с код на изход 2), номерът не е на никого на компютъра ти.

Онова, което никакви права не предотвратяват: `root` чете всичко, а който може да говори с демона на Docker (групата `docker` от Урок 1), може да монтира папката ти в контейнер и да я прочете. Затова се внимава кой е в тази група; това е още една причина да не подаряваш файла на „всички останали“.

#### 9.8.4 Безопасният начин в твоята папка

Има два начина файлът да остане затворен, от най-удобния към най-строгия. И двата позволяват на `revisor` да чете и оставят останалите навън. **Избери един**; не ги прилагай един след друг.

**Опция A**: ти си собственикът, а групата на `revisor` може да чете.

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt
chmod 640 secretos/revisor_token.txt
```

`+` казва на `chgrp`, че `65532` е номер на група, а не име (без `+` също го приема като номер, ако не съществува група с това име).

**Опция B**: собственикът е самият `revisor`. На теб ти трябва `sudo`, за да го прочетеш.

```bash
cd revisor
chmod 600 secretos/revisor_token.txt               # primero se cierra, mientras aún eres el dueño
sudo chown 65532:65532 secretos/revisor_token.txt  # después se regala; ya no podrás cambiarlo sin sudo
```

Редът е важен: ако първо подариш, `chmod` се проваля и файлът остава какъвто си беше (блок 6 от 9.8.3).

Която и да избереш, **винаги я проверявай**:

```bash
ls -l secretos/revisor_token.txt
stat -c '%a %U:%G' secretos/revisor_token.txt
sudo -u nobody cat secretos/revisor_token.txt   # debe decir: Permission denied
chmod 700 secretos                              # y cierra también la carpeta
```

След това — `docker compose up -d --force-recreate revisor` (смяната на правата на файл не е промяна на конфигурацията за Compose, а `revisor` чете токена си само при стартиране).

**Копията също се броят.** Всяко копие на токена се ражда със собствени права: `cp` без `-p` оставя файла на твое име, с твоята група и твоя `umask`; а резервното копие на редактор (`revisor_token.txt~`), архивът на личната ти папка или копие на USB памет или в облака не запазват `640`. Проверявай ги със същия `stat` или не ги прави.

**За да създадеш нова тайна**, нека се роди затворена, вместо да се отваря и после да се затваря. Виж своя `umask` с `umask`: това е „изваждането“ на права, което системата прилага към всеки нов файл. В Ubuntu и Linux Mint обикновено е `0002` (измерено на тестовата машина, Ubuntu 24.04), а нов файл излиза с `664`: чете го всеки, също като с `644`. `644`, който видя в Урок 6, не го е сложил `umask`: сложил го е `chmod` на курса. Два начина да създадеш затворен файл:

```bash
install -m 600 /dev/null secretos/token.txt                              # crea el archivo vacío, ya en 600
(umask 077; read -rs VALOR; printf '%s' "$VALOR" > secretos/token2.txt)  # pegas el valor sin que se vea
```

Три предупреждения. Двата начина са за файл, който **още не съществува**: ако вече съществува, `umask` не му променя правата (затвори го с `chmod 600`), а `install` го заменя с празен, без да предупреди. И двата го оставят с `600` **на твое име**, което е случай 2 от 9.8.3: `revisor` все още не може да го чете, така че довърши с опция A или B. И **не пиши стойността в командния ред** (`VALOR=... ` или `echo ... >`): тя остава в историята на терминала ти; затова примерът използва `read -rs`, или я постави от редактор.

**А кога все пак `644`?** Само в една ситуация: симулиран токен, на компютър, който е само твой, за упражнение. Скриптовете на този урок го използват във временна папка, която се изтрива накрая, и затова го оставят с `644`. Три предупреждения, без дребен шрифт:

- **Токенът на курса е измислен** (`curso-docker-token-de-mentira-7f3a9c`); не отваря нищо.
- **`644` позволява на всеки локален акаунт да го чете**, както току-що измери.
- **Никога не използвай `644` с истинска тайна**: нито на лаптопа си, нито на сървър, нито „за малко, докато тествам“.

А другата половина от хигиената на тайната: **да не стигне до хранилището**. В твоя проект `secretos/` отива в `.gitignore` от първия ден и се проверява:

```bash
echo 'secretos/' >> .gitignore
git check-ignore -v secretos/revisor_token.txt
```

```text
.gitignore:1:secretos/	secretos/revisor_token.txt
```

Ако `git check-ignore` не отпечата нищо, файлът **не** е игнориран. (Едно изключение: ако `git` вече следи файла отпреди да го игнорираш, `.gitignore` не го пуска; маха се с `git rm --cached`, а вече публикуваният токен се смята за изгубен и се сменя, както в Урок 6.) Казаното за Compose в 9.8.1 остава така: `compose.yaml` казва къде е токенът, `.gitignore` го държи извън хранилището, `.dockerignore` го държи извън образа, а правата на файла го държат извън обсега на останалите на компютъра ти.

### 9.9 Крайният файл

#### 9.9.1 Всичко заедно

Ето `compose.yaml`, с който завършваш урока. Замени с него първия в папката си `revisor/`; той е същият като този, който пази `estado/compose.yaml`:

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

Какво се промени спрямо първия, услуга по услуга:

- **`x-prueba`**: общият блок на трите копия (9.6), със същите опции с подсилена защита като `revisor`, включително `init: true`. Имат по-малки ограничения (32 MB и една четвърт CPU), защото почти не правят нищо.
- **`revisor`**: три услуги в `REVISOR_SERVICIOS`, токенът като тайна с `REVISOR_TOKEN_ARCHIVO`, сочещ към `/run/secrets/revisor_token`, `depends_on` с условията му (9.7) и `restart: unless-stopped`, политиката, която Урок 7 избра за `revisor`.
- **`prueba-sano`, `prueba-lento`, `prueba-caido`**: котвата плюс режима. Само здравата изгражда.
- **Отгоре**: същите мрежи и същият том, плюс тайната.

Един детайл на YAML в `REVISOR_SERVICIOS`: `>-` е **сгънат блок**. YAML съединява трите реда в един, с интервал там, където е имало нови редове, а `-` маха новия ред в края. Така всяка услуга е на собствен ред във файла, лесна за четене и за промяна, а `revisor` получава един-единствен низ, разделен със запетаи, какъвто очаква. Блок 5 от следващото изпълнение ти показва стойността такава, каквато е стигнала до контейнера.

#### 9.9.2 Да го видиш да работи

Скриптът `fig09_05.sh` го стартира от нулата и го преглежда отвътре. Частта, която се променя:

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

#### 9.9.3 Разчитане на изпълнението

1. **Валидиране.** Четири услуги. А услугата `prueba-lento`, прочетена от `config`, съдържа `image`, `pull_policy: never`, `read_only`, `mem_limit` (32 MB, в байтове) и `networks`, които са дошли от котвата. Котвата работи.
2. **Стартиране.** Обърни внимание на реда на събитията, който е сърцевината на този урок. Изграждат се двата образа (само два, макар да има четири услуги), създават се мрежите, томът и четирите контейнера. Стартират трите копия на тестовата услуга. И тогава се появяват `prueba-sano-1 Waiting` и `prueba-sano-1 Healthy`: Compose **изчака** здравата да мине проверката си на състоянието и едва след това стартира `revisor`. Това е `service_healthy` в действие. Редът, в който стартират трите копия, може да се промени от изпълнение до изпълнение, защото стартират едновременно.
3. **`ps`.** Състоянието разказва цялата история: `prueba-caido` е `(unhealthy)`, което е нейната работа; `prueba-lento` е `(health: starting)` и ще завърши като `unhealthy` (отнема 3 s, а проверката ѝ изисква по-малко от 2); `prueba-sano` и `revisor` — `(healthy)`. Четири контейнера `Up`, а само два здрави: вторият принцип на курса, в една-единствена таблица.
4. **Отчетът.** Без токен — `401` със съобщението на `revisor`: тайната е стигнала и `revisor` я изисква. С токена — таблицата с трите състояния: `FALLA` с `codigo 503`, `LENTO` (отговорила е с `200`, но за повече от секунда) и `OK`. Това е целта на курса.
5. **Какво е създал Compose.** Две мрежи, вътрешната с `interna=true`; един том; и `revisor` с цялата подсилена защита от Урок 7, приложена от демона: файлова система само за четене, `CapDrop=[ALL]`, `Init=true`, 64 MB, потребител `65532:65532` (който идва от образа) и политиката за рестартиране.
6. **Токенът не се вижда.** `grep -c` преброява нула пъти стойността на токена в целия `docker inspect` и в целия `docker compose config` (`[código de salida: 1]` е на `grep`, който излиза с 1, когато не намери нищо: тук това е добрата новина). Средата на контейнера има `REVISOR_TOKEN_ARCHIVO`, което е **път**, а не стойност. А монтиранията показват какво е отвътре тайна от файл: `bind` само за четене (`ro=true`) в `/run/secrets/revisor_token`, до `volume` на `/datos`. Третата цел на курса („никоя тайна не се появява в `docker history`, в `docker inspect`, нито в променливите на средата на контейнера“) е изпълнена, в частта си за изпълнението, с цялата система.

#### 9.9.4 В твоята папка

С крайния файл в `revisor/compose.yaml`, `servicio-prueba/` до него и `secretos/revisor_token.txt` с права `640` и група `65532` (9.8.4):

```bash
cd revisor
sudo chgrp +65532 secretos/revisor_token.txt   # el grupo del revisor puede leerlo...
chmod 640 secretos/revisor_token.txt          # ...y ningún otro usuario (9.8.4)
docker compose config --quiet && echo 'compose.yaml válido'
docker compose up -d --build
docker compose ps
curl -s -H "Authorization: Bearer $(cat secretos/revisor_token.txt)" 'http://127.0.0.1:8080/api/estados?formato=tabla'
```

Една бележка за този `curl`: докато работи, токенът е в командния му ред и всеки акаунт може да го види с `ps`, дори файлът да е с `640`. Със симулирания токен това няма значение; с истински го подай от файл със заглавки (`curl -H @cabeceras.txt`, който трябва да има собствени затворени права).

Скриптовете на този урок използват `644` във временна папка, със симулирания токен; твоята папка няма нужда от това. С `644` всеки потребител на компютъра ти може да прочете токена (9.8.3), а на споделен сървър това не се приема: поправката е правилната група или правилният собственик (раздел 6.5.4 от Урок 6), а не отварянето му за всички.

Имената ще бъдат `curso-docker-revisor-1`, `curso-docker-prueba-sano-1` и така нататък, с мрежи `curso-docker_publica` и `curso-docker_interna` и том `curso-docker_reportes`. Ако Урок 8 те е оставил с работещ `curso-docker-revisor` на порт 8080, спри го преди това (`docker rm -f curso-docker-revisor curso-docker-prueba`), иначе `up` ще се сблъска със заетия порт от Урок 2. А ако си запазил тома `curso-docker-reportes` от Урок 8, той не пречи: този на Compose е друг, `curso-docker_reportes`, с долна черта.

### 9.10 Грешката, която ще ти струва най-много: тайната с `600`

#### 9.10.1 Да я предизвикаш с написани `uid`, `gid` и `mode`

Скриптът `fig09_06.sh` взема крайния файл, сменя тайната към дългата форма с `uid: "65532"`, `gid: "65532"` и `mode: 0400` (онова, което „би трябвало“ да поправи правата), слага файла на токена на `600` и стартира. След това го поправя с `644`, което скриптовете му използват във временната си папка със симулирания токен (в твоята папка поправката е тази от 9.8.4). Частта, която се променя:

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

#### 9.10.2 Разчитане

1. **`diff`** показва дългата форма, а `stat` показва файла с `600`, на твоя потребител (номерът е скрит, защото зависи от компютъра).
2. **`Started`.** Compose казва, че `revisor` е стартирал, и това е вярно: процесът е стартирал. Но логовете разказват останалото: `leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied`. `revisor` не е успял да прочете токена си и е предпочел да умре с код 1, вместо да остане да слуша без защита (Урок 6). `sort -u` на скрипта съединява повторените редове, защото съобщението излиза по веднъж за всеки опит.
3. **`Status=restarting ExitCode=1`.** Опити? Да: крайният файл има `restart: unless-stopped`, така че демонът го стартира отново всеки път, когато умре, с все по-дълги чакания, и всеки път умира по същия начин. Това ще видиш в реална система, когато една тайна има грешни права: контейнер, който влиза и излиза, и `docker compose ps`, който казва `Restarting`. Политиката за рестартиране се грижи за смъртта на процеса, както видя в Урок 7; не може да поправи причината ѝ.
4. **Монтирането.** Тайната е `bind` само за четене, въпреки декларираните `uid`, `gid` и `mode`. Трите атрибута не направиха нищо. Точно това казва справочникът, измерено.
5. **Поправката на скрипта**: `644` и файлът на урока, с кратката форма. Това е най-кратката поправка, а не най-добрата: отваря токена за целия компютър (9.8.3). В твоята папка използвай тази от 9.8.4. `--force-recreate revisor` иска от Compose да пресъздаде тази услуга, макар конфигурацията ѝ да е същата като тази на съществуващия контейнер; тук е нужно, защото единственото, което се е променило, са правата на файл на компютъра ти, а това Compose не го сравнява. `revisor` стига до `(healthy)` и таблицата се връща.

Ако това ти се случи в папката ти: `ls -l secretos/`, и ако казва `-rw-------`, дай право за четене **само** на групата на `revisor` (`sudo chgrp +65532 secretos/revisor_token.txt` и `chmod 640 secretos/revisor_token.txt`, 9.8.4) и `docker compose up -d --force-recreate revisor`. `chmod 644` също го поправя, но оставя токена пред очите на целия ти компютър: само със симулиран токен. Което **не** е поправка: да махнеш `USER` от образа или да сложиш `user: "0"` в услугата, за да го чете `root`. Това заменя проблем с правата на един файл с цял контейнер, работещ като `root`.

### 9.11 Две грешки на Compose, които е добре да познаваш предварително

Скриптът `fig09_07.sh` предизвиква двете грешки, характерни за този файл, и измерва какво става без `pull_policy: never` (въпросът, който остана отворен в 9.6.3). Частта, която се променя:

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

#### 9.11.1 Три изграждания на един и същ таг

С `build` в котвата трите тестови услуги изграждат един и същ образ с едно и също име и Compose пуска трите изграждания **едновременно**. Трите завършват с един и същ образ и трите се опитват да му дадат едно и също име накрая; онова, което пристигне по-късно, намира името заето: `target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists`, а `build` излиза с `1`. Обърни внимание на две неща. Първо: услугата, която съобщава за сблъсъка, може да е която и да е от трите, според това коя приключи по-късно; при това изпълнение беше `prueba-sano` при опити 1 и 3 и `prueba-lento` при 4-ия. Второ: при опити 2 и 5 сблъсък **нямаше** и `build` излезе с `0`. Това е надпревара (race condition) и понякога се печели: при това изпълнение се провали в 3 от 5 опита. Грешка, която се появява „понякога“, е по-лоша от такава, която се появява винаги, защото те кара да вярваш, че си я поправил, когато просто си имал късмет.

Причината е в дизайна, а не в късмета: **образът се изгражда веднъж и се използва многократно**. Затова крайният файл слага `build` в една-единствена услуга и `pull_policy: never` в другите две (9.6.3). В терминала ти пълното съобщение е предшествано от стъпките на BuildKit; търси реда, който започва с `target`, който ти казва в коя услуга се е провалило.

#### 9.11.2 Без `pull_policy: never`

Блок 2 маха реда `pull_policy: never` от котвата (`diff` го показва) и стартира с още неизградения образ на тестовата услуга (блок 1 го изтри накрая). Събитията на образа разказват казаното в 9.6.3: два `Pulling` и два `Error pull access denied`, по един за всяка услуга, която **не** изгражда образа (`prueba-lento` и `prueba-caido`) и която, без `never`, първо го търси в Docker Hub. След това — `Building` и `Built`: Compose вижда, че друга услуга в проекта изгражда същия образ, пропуска грешката и продължава. Системата стартира въпреки това. Затова `pull_policy: never` не е, за да работи, а за да **не пита**: без този ред стартирането зависи от това в Docker Hub да няма нещо с това име, и пълни терминала ти с грешки, които трябва да се научиш да пренебрегваш, а това е най-лошият навик, който може да се има пред лицето на грешка.

#### 9.11.3 `--wait` с услуга, която се проваля нарочно

`docker compose up --wait` съществува за скриптове и за непрекъсната интеграция: според справочника си чака услугите да са „работещи или здрави“ и предполага откачения режим; `--wait-timeout` задава колко секунди най-много да се чака ([справочник на `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/)). Звучи идеално за чакане на `revisor`, но погледни блок 3: `container curso-docker-fig09-prueba-caido-1 is unhealthy`, код `1`, за единайсет секунди според самия скрипт (`tardó 11 s`). `--wait` чака **всички** услуги с проверка на състоянието, а `prueba-caido` никога няма да е здрава; щом Docker я отбележи като `unhealthy`, `--wait` се отказва. А ако назовеш само `revisor` (`up --wait revisor`), се получава същата грешка: за да стартира `revisor`, Compose стартира зависимостите му и чака и тях.

Обърни внимание на `ps` след това: системата е останала **горе** и работи, с `revisor` `(healthy)`. `--wait` не е развалил нищо; само е съобщил с код, различен от 0, че не всичко е здраво. В истинска система точно това искаш да знаеш. В тази, където една услуга е неработеща нарочно, курсът използва `up -d` и след това чака състоянието на **`revisor`** с `docker inspect`, което прави функцията `esperar` на скриптовете. Блок 4 го доказва и таблицата излиза цялата.

### 9.12 Жизненият цикъл: промяна, спиране, запазване

Скриптът `fig09_08.sh` стартира крайната система, иска отчет, за да има нещо запазено, и след това минава през онова, което ще правиш всеки ден. Частта, която се променя:

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

1. **Промяна на услуга.** Файлът превключва `prueba-caido` в здрав режим и се иска `up -d`. Compose оставя три контейнера в `Running` и **пресъздава само `prueba-caido`**. Дори `revisor`, който зависи от нея, не се пипа: конфигурацията му не се е променила, а неговият `depends_on` не иска рестартиране, когато една зависимост се промени (за това съществува опцията `restart: true` вътре в `depends_on`; документацията я описва за услуга, която трябва да се свърже отново, когато базата ѝ данни бъде пресъздадена, а `revisor` няма нужда от нея, защото отваря нова връзка при всяка проверка) ([Docker, „Control startup order“](https://docs.docker.com/compose/how-tos/startup-order/)). Следващата таблица казва `caido OK 200`: името на услугата остава `caido`, но сега отговаря като здрава. Това е моделът на Compose в един пример: описваш състоянието, което искаш, а инструментът изчислява минималната промяна. Скриптът връща файла в крайната му форма, преди да продължи.
2. **`down` без `--volumes`.** Изтриват се контейнерите и мрежите; томът остава в `docker volume ls`. Помощникът `alpine` от Урок 8 го чете само за четене и там е `reporte.json`, на `65532`, с права `600` (`revisor` го създава така: отчетът е на онзи, който го пише). Когато скриптът поиска отново `up -d`, новият `revisor` монтира същия том. Това е петата цел на курса, „отчетът оцелява“, сега с цялата система.
3. **Подредено спиране.** `docker compose stop revisor` отнема по-малко от секунда (при това изпълнение — 203 ms) и `revisor` завършва с `ExitCode=0`. Логовете му го разказват: `recibí terminated, apagando` и `apagado limpio`. `stop` използва отдолу същия `SIGTERM` и същия срок от 10 s като `docker stop` от Урок 7; `init: true` и обработчикът на `revisor` правят останалото.
4. **`down --volumes`.** Сега томът наистина си отива, а с него и отчетът. Използвай го, когато наистина искаш да започнеш от нулата, като знаеш, че няма кошче.

### 9.13 А `docker init`?

Планът на курса искаше да се сравни твоят файл с онзи, който генерира `docker init`, команда, която създава `Dockerfile`, `.dockerignore`, `compose.yaml` и `README.Docker.md` от шаблон за всеки език (Go, Python, Node, Java, Rust и други) ([справочник на `docker init`](https://docs.docker.com/reference/cli/docker/init/)). Първото изречение на същата страница е онова, което има значение тук: „Docker Desktop предоставя командата `docker init`“. Тя не е част от Docker Engine, който инсталира на своя Mint в Урок 1. Скриптът `fig09_09.sh` го проверява (не създава нищо, така че не му трябва началото на другите):

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

Така че курсът не зависи от нея, а сравнението се прави с онова, което официалната документация показва. Ръководството на Docker за поставяне на Python приложение в контейнер започва с този `compose.yaml` с една-единствена услуга (тук без заглавните му коментари) ([Docker, „Containerize a Python application“](https://docs.docker.com/guides/python/containerize/)):

```yaml
services:
  server:
    build:
      context: .
    ports:
      - 8000:8000
```

Това е добра отправна точка и файл, много различен от твоя. Упражнение 4 те кара да намериш разликите, една по една, и да кажеш кой урок от курса обяснява всяка. Генераторът ти спестява писането; не ти спестява разбирането на написаното. Ако някой ден използваш `docker init` на компютър с Docker Desktop, прочети неговия `compose.yaml` с `docker compose config` и го прекарай през списъка от навика за сигурност на този урок, преди да го използваш.

### 9.14 Какво ще срещнеш в стари ръководства

- **`docker-compose`, с тире.** Това е Compose „V1“, отделна програма, написана на Python. Docker го обявява за изведен от поддръжка: „Compose v1 вече не се поддържа и потребителите трябва да мигрират към Compose v2“ ([Docker, „Retired features“](https://docs.docker.com/retired/)). Днес е `docker compose`, с интервал. Ако ръководство казва `docker-compose up`, преведи го.
- **Имена на контейнери с долна черта**, като `proyecto_web_1`. Те бяха тези на V1. Обявяването на Compose V2 го казва така: имената на контейнерите „вече използват тирета като разделители вместо долни черти“, а ако скрипт зависи от тези имена, ще се счупи; затова по принцип препоръчва да не се зависи от имената на контейнерите ([Docker, „Announcing Compose V2 General Availability“](https://www.docker.com/blog/announcing-compose-v2-general-availability/)). Ако стар скрипт търси `curso-docker_revisor_1` (името, което в V1 би имал `curso-docker-revisor-1` от този урок), няма да го намери.
- **`version: "3.8"`** (или `"2"`, или `"3"`) в началото на файла. Остаряло; само дава предупреждение (9.2.3).
- **`docker-compose.yml`** като име на файл. Все още се приема за съвместимост, но предпочитаното е `compose.yaml`.
- **`links:`** вътре в услуга. Това е `--link` от Урок 8 във формата на ключ; в мрежите на един проект услугите вече се намират по име.
- **Токенът в `environment:`** или във файл `.env`, който се използва за попълване на `environment`. Работи, и това е онова, което Урок 6 те научи да не правиш: остава в `docker inspect`. За това съществуват `secrets`.

## Грешката, която ще видиш

Този урок има три основни грешки. Всички вече се появиха, а всяка се различава по това къде я виждаш.

**В отчета: `read-only file system` в `/datos`.**

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
 [500]
```

Контейнерът е `healthy`, а отчетът се проваля. Чете се отдясно наляво, като тези от Уроци 7 и 8: `read-only file system` го казва ядрото; `/datos/.reporte-<n>.tmp` казва, че проблемът е папката `/datos`; а `500` го слага `revisor`, който не се преструва. Въпросът, който я решава, е: „какво е монтирано в `/datos`?“. Отговорът го дава `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' <контейнер>`. Ако `/datos` не се появява, липсва томът в услугата. Поправка: `volumes: [reportes:/datos]` в услугата и `reportes: {}` отгоре, и `docker compose up -d` (пресъздава само `revisor`). Което не е поправка: `read_only: false`.

**В логовете: `permission denied` в `/run/secrets/`.**

```text
revisor: leyendo el token de REVISOR_TOKEN_ARCHIVO: open /run/secrets/revisor_token: permission denied
```

А в `docker compose ps` — `revisor`, който казва `Restarting`. `Started` в изхода на `up` няма да те предупреди: процесът наистина е стартирал, а е умрял след това. Диагностицира се с `docker compose logs revisor` и `ls -l secretos/`. Ако файлът е с `600`, потребителят `65532` на контейнера не може да го прочете, а `uid`, `gid` и `mode` в `compose.yaml` не го променят, защото при тайна от файл Compose ги пренебрегва. Поправка: групата на файла да е `65532`, а правата `640` (`sudo chgrp +65532 secretos/revisor_token.txt` и `chmod 640 secretos/revisor_token.txt`), или собственикът да е `65532` с `600`, и `docker compose up -d --force-recreate revisor`. `chmod 644` също го поправя, но отваря токена за целия компютър: само със симулиран токен (9.8.4).

**В командата: `--wait`, който не завършва добре.**

```text
container curso-docker-fig09-prueba-caido-1 is unhealthy
```

(В твоята папка — `curso-docker-prueba-caido-1`.) Код `1`, дори да назовеш само `revisor`. Това не е повреда на системата: това е `--wait`, който чака и услуга, която не може да е здрава. В този проект — `up -d` и чакане на състоянието на `revisor`. В проект без услуги, които се провалят нарочно, това съобщение наистина е аларма: казва ти точно кой контейнер да провериш.

**И една второстепенна, при изграждане**:

```text
target prueba-sano: failed to solve: image "docker.io/library/curso-docker-prueba:fig09": already exists
```

(В твоята папка тагът ще е твоят, `curso-docker-prueba:1.0.0`, а услугата може да е която и да е от трите.) Няколко услуги с `build` и един и същ `image`. Появява се понякога, не винаги: при изпълнението от 9.11 — в 3 от 5 опита. Поправка: `build` в една-единствена услуга, `pull_policy: never` в останалите.

## Навикът за сигурност на урока

**`compose.yaml` се ражда с всичко предишно, а тайните му живеят извън файла.** Това е навикът, който README на курса определя за този урок, и се проверява със списък, през който можеш да прекараш всеки `compose.yaml`, твой или чужд, като четеш неговия `docker compose config`:

- Всеки публикуван порт има `host_ip: 127.0.0.1` (Урок 2), а онова, което няма нужда от порт, не го публикува.
- Всяка услуга има `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges` и `init: true` (Урок 7) и ограничения за памет, CPU и процеси (Урок 2).
- Образите имат версия, никога `latest` (Урок 3), а онези, които изграждаш ти, не се търсят в интернет (`pull_policy: never`).
- Онова, което пише, пише в именуван том, монтиран точно там, където е нужно (Урок 8).
- Онова, което няма нужда от интернет, живее в мрежа `internal: true`, и няма `network_mode: host` (Урок 8).
- Никаква тайна стойност в `environment`, в `build.args`, нито в самия файл: тайните отиват в `secrets:`, от файлове, които не се качват в хранилището, а `grep` на стойността в `docker compose config` и в `docker inspect` дава нула (Урок 6 и този).

Произшествието, което предотвратява, е онова от сцената: системата, която работи, да не е онази, която си тествал. Файл с подсилена защита, направена веднъж, е с подсилена защита за всички, които го използват; шест команди с подсилена защита зависят от това никой да не копира грешната.

## Какво се прави погрешно

**Да пишеш `version:` в началото на файла.** Остаряло е и само дава предупреждение. И почти винаги издава, че останалата част от файла е копирана от старо ръководство: прегледай го по-внимателно.

**Портове без `127.0.0.1`.** `"8080:8080"` в `compose.yaml` е `-p 8080:8080` от Урок 2: портът, отворен за цялата ти мрежа. Това е първото, което се губи при копиране на пример.

**Да махнеш `read_only`, „защото се проваля“.** Ако се проваля, програмата пише на място, което не си предвидил. Намери кое (грешката ти го казва) и монтирай там том или `tmpfs`.

**`depends_on` без условие за нещо, което трябва да е готово.** Кратката форма чака само контейнерът да работи. Ако услугата ти има нужда друга да е здрава — `condition: service_healthy`, и онази друга да има своя проверка на състоянието.

**`service_healthy` за всичко.** С услуга, която никога няма да е здрава, онази, която зависи от нея, никога не стартира. Искай здраве само от онова, което има нужда.

**Токенът в `environment:` или в `.env`.** Остава в `docker inspect` за всеки от групата `docker`. За това съществува `secrets:`.

**Да разчиташ на `uid`, `gid` и `mode` на тайна от файл.** Compose ги пренебрегва безшумно. Правата са тези на файла на компютъра ти.

**`build` в няколко услуги с един и същ `image`.** Надпревара, която „почти винаги“ печели другият. Изграждай в една и използвай образа в останалите.

**`docker compose down --volumes` по навик.** Изтрива отчета. Използвай го, когато искаш да започнеш от нулата, а не за спиране.

**Да изтриваш ръчно с `docker rm` онова, което е създал Compose.** Работи, но Compose вече не знае в какво състояние е останало всичко. Онова, което се създава с Compose, се спира с `docker compose stop` или `docker compose down`.

**Два проекта с едно и също име.** Два `compose.yaml` с `name: curso-docker`, дори в различни папки, си пречат взаимно: Compose мисли, че контейнерите на единия са на другия. Един проект — едно име.

## Упражнения

Прави ги поред. Преди да изпълниш всяко, запиши в [дневника](bitacora.md) какво мислиш, че ще стане; сравнението след това е половината от ученето. Накрая остави проекта си с крайния файл и го спри с `docker compose down` (без `--volumes`, ако искаш да запазиш отчета).

### Упражнение 1 — Преведи `docker run`

Това е командата на тестовата услуга от Урок 8, раздел 8.10.3:

```text
docker run -d --name curso-docker-prueba --network curso-docker-interna \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 curso-docker-prueba:1.0.0
```

Напиши еквивалентната услуга на Compose, с име `prueba`, без да гледаш `fig09_01.compose.yaml`. След това кажи: коя опция на командата **няма** ключ в твоята услуга и защо? Какво би трябвало да съществува във файла, извън услугата, за да работи твоят `networks`?

### Упражнение 2 — Какво пресъздава Compose?

С работещата крайна система предскажи, за всяка промяна поотделно, кои контейнери ще кажат `Running` и кои `Recreated` при следващия `docker compose up -d`. След това провери и върни файла в крайната му форма преди следващата:

1. Сменяш времето на `lento` в `REVISOR_SERVICIOS` от `5s` на `4s`.
2. Сменяш `mem_limit: 32m` с `mem_limit: 24m` в котвата `x-prueba`.
3. Не променяш файла, но правиш `chmod 600 secretos/revisor_token.txt`.

Допълнителен въпрос: в случай 3 какво би трябвало да направиш, за да видиш грешката от 9.10, и коя команда я отменя?

### Упражнение 3 — Диагностицирай, без да изпълняваш

Една колежка ти изпраща това, копирано от терминала си (това е блокът „Ejercicio 3“ на `fig09_10.sh`, така че имената са помощните, а номерът на временния файл е скрит). `revisor` казва `healthy` и въпреки това отчетът му не работи:

```text
$ docker compose ps --format '{{.Service}} | {{.Status}}' | sed -E 's/Up [0-9]+ (seconds|minutes)/Up N/'
prueba-caido | Up N (unhealthy)
prueba-lento | Up N (unhealthy)
prueba-sano | Up N (healthy)
revisor | Up N (healthy)
$ curl -s -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8080/api/estados | sed -E 's/reporte-[0-9]+/reporte-<n>/'
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: read-only file system"}
```

1. Проблемът ли са `(unhealthy)` на `prueba-caido` и `prueba-lento`? Защо?
2. Кои редове със сигурност липсват в нейния `compose.yaml`? С коя команда би го проверил, без да отваряш файла?
3. Какво ти казва, че токенът **е** наред?

### Упражнение 4 — Твоят файл срещу този от ръководството

Вземи `compose.yaml` от официалното ръководство за Python от раздел 9.13 и направи списък на **всичко**, което крайният ти файл има, а онзи няма, приложено към услугата `server`. За всяка разлика кажи кой урок от курса я обяснява и какъв риск затваря. След това отговори: има ли нещо във файла на ръководството, което **не** би трябвало да промениш?

## Решения

Решенията, които казват „измерено“, идват от скрипта `fig09_10.sh`, който прави всяка промяна видимо със `sed`, проверява я и я отменя. Пълният му изход:

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

### Решение 1

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

Това е услугата от `fig09_01.compose.yaml`, с изключение на `build` (който командата от Урок 8 нямаше, защото образът вече съществуваше). Опцията без ключ е `--name curso-docker-prueba`: името на контейнера го слага Compose (`curso-docker-prueba-1` в твоята папка), а останалите го намират по името на **услугата**, `prueba`. `-d` също няма ключ: това е опция на командата (`docker compose up -d`), а не на услугата. За да работи `networks: [interna]`, мрежата трябва да е декларирана отгоре, в `networks:`; иначе файлът не е валиден. А за да остане мрежата без изход от Урок 8, тази декларация съдържа `internal: true`. Измерено: с котва, сочеща към мрежа `otra`, която не съществува отгоре, `docker compose config --quiet` отговаря `service "prueba-lento" refers to undefined network otra: invalid compose project` и излиза с `1` (назовава едно от трите копия, които наследяват котвата; при твоето изпълнение може да е друго). Това е видът грешка, която `config` хваща, преди да създаде каквото и да е.

### Решение 2

Измерено (блоковете „Ejercicio 2“ на `fig09_10.sh`):

1. **Пресъздава се само `revisor`.** `REVISOR_SERVICIOS` е част от неговата конфигурация; тестовите услуги не се променят и казват `Running`. Това е същото, което видя в блок 2 на `fig09_03.sh`, с друга промяна.
2. **Пресъздават се трите копия на тестовата услуга**, а `revisor` остава в `Running`. За Compose важи резултатът от копирането на котвата в трите услуги, така че промяната на котвата е промяна на трите. `docker compose config | grep mem_limit` го потвърждава преди стартиране: три пъти `25165824` (24 MB в байтове) и веднъж `67108864` (`revisor`). Последният ред, `mem_limit: 24m` без кавички и с по-малък отстъп, е самият `x-prueba`: `config` запазва полетата `x-` в изхода си, макар да не ги използва, за да създава каквото и да е.
3. **Нищо не се пресъздава**: четирите в `Running`, а таблицата продължава да излиза. Правата на файл на компютъра ти не са част от конфигурацията, която Compose сравнява, а `revisor` вече е прочел токена си при стартиране, така че продължава да работи. За да видиш грешката от 9.10, трябва да го принудиш да стартира отново: `docker compose restart revisor` казва `Started`, а три секунди по-късно `docker inspect` казва `Status=restarting ExitCode=1`. Отменяш го, като върнеш предишните права (във временната папка на скрипта — `644` със симулирания токен; в твоята — `640` с група `65532` от 9.8.4), последвано от `docker compose up -d --force-recreate revisor`, същата команда от 9.10. Урокът от този случай: грешка в правата може да **спи** с дни, до следващото рестартиране.

### Решение 3

1. **Не.** Те са `unhealthy`, защото се провалят нарочно: неработещата отговаря с `503`, а бавната отнема 3 s, когато проверката ѝ изисква по-малко от 2. Това е очакваното и затова `revisor` иска `service_healthy` само от здравата. `revisor` е `healthy`, защото `/salud` не записва нищо.
2. Липсва томът на `revisor` в `/datos`: двата реда `volumes:` и `- reportes:/datos` на услугата. Това е блок 1 на `fig09_03.sh`. Проверяваш го, без да отваряш файла, с `docker compose config | sed -n '/^  revisor:/,/^  [a-z]/p' | grep -A4 volumes`, който не намира нищо и излиза с `1`; или, върху контейнера, с `docker inspect --format '{{range .Mounts}}{{.Destination}} {{end}}' curso-docker-revisor-1`, който показва `/run/secrets/revisor_token` и не показва `/datos`. И двете неща са в изхода на `fig09_10.sh`.
3. Това, че отговорът **не** е `401`. С грешен или липсващ токен `revisor` отговаря `{"error":"falta el token o no es válido"}`, преди да опита каквото и да е. Тук е минал тази проверка и се е провалил при записа. А ако файлът на токена беше с `600`, `revisor` дори нямаше да е `Up`: щеше да се рестартира (9.10).

### Решение 4

Какво има твоят файл, а този от ръководството няма, в услугата:

- **`127.0.0.1` в порта** (Урок 2). `8000:8000` публикува на всички интерфейси на компютъра ти; всеки от мрежата ти стига до услугата.
- **`image:` с име и версия** (Урок 3). Без него името на образа го решава Compose и то не казва коя версия работи.
- **`read_only`, `cap_drop`, `no-new-privileges` и `init`** (Урок 7). Без тях който поеме контрола над процеса може да пише на диска на контейнера, да използва capabilities на `root`, които Docker оставя по подразбиране, и да придобие привилегии с програма *setuid*; а програма, която не знае как да бъде процес 1, не спира правилно.
- **Ограничения за памет, CPU и процеси** (Урок 2). Без тях грешка в програмата може да заеме целия компютър.
- **`restart`** (Урок 7). Без политика, ако процесът умре, остава мъртъв.
- **Собствени мрежи, с вътрешната без изход** (Урок 8). Ръководството използва мрежата по подразбиране на проекта, с изход към интернет за всички.
- **Именуван том там, където пише** (Урок 8). В този пример не е нужен, защото приложението не пази нищо; в деня, в който запази, ще има нужда от него.
- **`secrets:`** (Урок 6 и този). Ръководството, от което идва примерът, добавя по-нататък база данни с паролата ѝ като тайна: моделът е същият.

Какво не би променил: `build` с `context: .`, което е точно онова, което прави твоят `revisor`, и липсата на `version:`. И едно справедливо уточнение: крайният етап на Dockerfile от това ръководство работи без `root` по подразбиране, както казва самата страница, така че `USER` от Урок 3 е решен в неговия Dockerfile, а не в `compose.yaml`. Генерираният файл не е лош: той е отправна точка, а твоята работа е да го доведеш дотук.

## Как разбирам, че съм успял

Отбележи всяка точка само ако можеш да я направиш, **без да поглеждаш отново текста**:

- [ ] В папката ти `revisor/` `docker compose config --quiet && echo 'compose.yaml válido'` отпечатва `compose.yaml válido`, а `grep -c '^version' compose.yaml` дава `0`.
- [ ] `docker compose up -d --build` стартира четирите услуги от нулата, `docker compose ps` показва `curso-docker-revisor-1` в `(healthy)` с `127.0.0.1:8080->8080/tcp`, а в събитията на `up` се появява `prueba-sano-1 Healthy` **преди** `revisor-1 Started`.
- [ ] Таблицата на `revisor`, поискана с токена, показва `caido FALLA`, `lento LENTO` и `sano OK`, без да си сменял ръчно никакъв режим.
- [ ] `docker inspect curso-docker-revisor-1 | grep -c "$(cat secretos/revisor_token.txt)"` дава `0`, и същото с `docker compose config`.
- [ ] Обясняваш защо `revisor` чака със `service_healthy` само `prueba-sano`, като използваш думите *проверка на състоянието*, *503* и *2 секунди*.
- [ ] Предизвикваш `read-only file system`, като махнеш тома от `/datos`, и `permission denied` на тайната с `chmod 600`, и обясняваш защо `uid`, `gid` и `mode` не го предотвратяват.
- [ ] Със `stat -c '%a %U:%G'` и `sudo -u nobody cat` проверяваш, че твоят `secretos/revisor_token.txt` **не** се чете от друг акаунт, а `revisor` го чете (`640` с група `65532` или `600` със собственик `65532`); а `git check-ignore -v secretos/revisor_token.txt` казва, че `.gitignore` на проекта ти го покрива.
- [ ] След `docker compose down` (без `--volumes`) `docker run --rm -v curso-docker_reportes:/datos:ro alpine:3.24.2 ls -ln /datos` показва `reporte.json` на `65532`.
- [ ] `docker compose stop revisor` отнема по-малко от секунда и оставя `ExitCode=0`.
- [ ] Пускаш скриптовете от [`programas/09-compose/`](../programas/09-compose) (със спрян проект или с друг порт: `PUERTO=18080 ./fig09_05.sh`; функцията `nombres` пренаписва порта в изхода) и изходите ти съвпадат с тези от урока, с изключение на времената, датите, номера на временния файл, реда на едновременните събития, услугата, която назовава грешката от Упражнение 1, и опитите и услугите при сблъсъка от 9.11. А накрая `docker ps -a --filter name=fig09`, `docker volume ls --filter name=fig09` и `docker network ls --filter name=fig09` не показват нищо.

## Обобщение

Отговори, без да гледаш урока:

1. Каква е разликата между услуга и контейнер и какво име използват останалите контейнери, за да намерят един?
2. Откъде идва името на проекта, в какъв ред се решава и как се вижда в имената на контейнерите, мрежите и томовете?
3. Какво прави `docker compose config` и какво те научи за `depends_on: [prueba]` и за `"127.0.0.1:8080:8080"`?
4. Защо, ако поискаш `docker compose up -d` два пъти, вторият път не прави нищо, и какво прави, когато промениш услуга?
5. Защо `revisor` с `read_only: true` има нужда винаги от нещо монтирано в `/datos`?
6. За какво служат заедно поле `x-` и котва на YAML?
7. Каква е разликата между `service_started` и `service_healthy` и защо не може да се иска `service_healthy` от `prueba-caido`?
8. Къде се появява тайна на Compose вътре в контейнера и защо файл с `600` дава `permission denied`, дори да декларираш `uid`, `gid` и `mode`? Кой може да чете същия файл с `644` и как го оставяш така, че да го четете `revisor` и ти, но никой друг?
9. Защо само една тестова услуга има `build` и какво прави `pull_policy: never` в другите две?
10. Какво изтрива `docker compose down`, какво добавя `--volumes` и защо `up --wait` се проваля в този проект, макар всичко да работи?

## Източници

Всички проверени на 21 октомври 2026 г.

- [Docker, „Docker Compose“](https://docs.docker.com/compose/): какво е Compose.
- [Docker, „How Compose works“](https://docs.docker.com/compose/intro/compose-application-model/): името `compose.yaml` (предпочитано) и наследените имена; какво е проект; услуги, мрежи, томове, конфигурации и тайни.
- [Спецификация на Compose](https://docs.docker.com/reference/compose-file/): документът, който определя ключовете на файла и елементите му от първо ниво.
- [Спецификация, `version` и `name`](https://docs.docker.com/reference/compose-file/version-and-name/): че `version` е само информативен и дава предупреждение, че е остарял; `name` като име на проекта.
- [Справочник на услугите в Compose](https://docs.docker.com/reference/compose-file/services/): `depends_on` и трите му условия; `pull_policy: never`; `read_only`, `cap_drop`, `security_opt` и трите форми на `no-new-privileges`; `init`; `mem_limit`, `cpus`, `pids_limit`; `restart`; `image` до `build`; дългата форма на `secrets` и че с файл като източник `uid`, `gid` и `mode` се пренебрегват безшумно.
- [Спецификация, разширения](https://docs.docker.com/reference/compose-file/extension/): че Compose пренебрегва полетата, които започват с `x-`, и че те служат за повторно използване на конфигурация.
- [Спецификация, фрагменти](https://docs.docker.com/reference/compose-file/fragments/): котви, псевдоними и ключът за сливане `<<`; че сливането се прилага само за речници; `environment` като речник при използване на фрагменти.
- [Docker, „Specify a project name“](https://docs.docker.com/compose/how-tos/project-name/): редът, в който се решава името на проекта, знаците, които приема, и че служи за изолиране на средите.
- [Docker, „Networking in Compose“](https://docs.docker.com/compose/how-tos/networking/): мрежата `<проект>_default`, името на услугата в DNS и собствените мрежи с `networks`.
- [Docker, „Control startup order“](https://docs.docker.com/compose/how-tos/startup-order/): че Compose не чака контейнерът да е готов, а само да работи; `service_healthy`; редът на изтриване по зависимости; `restart: true` вътре в `depends_on`.
- [Docker, „Secrets in Compose“](https://docs.docker.com/compose/how-tos/use-secrets/): какво е тайна, пътят `/run/secrets/<име>`, че Docker създава монтиране (`bind mount`) на този път, че достъпът се контролира с нормалните права на файловата система и че я получава само услугата, на която е дадена.
- [Спецификация, `secrets` от първо ниво](https://docs.docker.com/reference/compose-file/secrets/): че тайната се създава със съдържанието на файла от `file` (или с променлива на средата от `environment`).
- [Справочник на `docker compose config`](https://docs.docker.com/reference/cli/docker/compose/config/): че показва модела, който ще бъде приложен, в канонична форма; `--quiet`, `--services`, `--volumes`.
- [Справочник на `docker compose up`](https://docs.docker.com/reference/cli/docker/compose/up/): какво прави `up`; че пресъздава при промяна на конфигурацията или образа и запазва томовете; `-d`, `--build`, `--wait`, `--wait-timeout`, `--no-recreate`.
- [Справочник на `docker compose down`](https://docs.docker.com/reference/cli/docker/compose/down/): какво изтрива по подразбиране и какво добавя `--volumes`.
- [Справочник на `docker init`](https://docs.docker.com/reference/cli/docker/init/): че го предоставя Docker Desktop, файловете, които създава, и шаблоните му.
- [Docker, „Containerize a Python application“](https://docs.docker.com/guides/python/containerize/): `compose.yaml` с една услуга, използван в 9.13 и в Упражнение 4.
- [Docker, „Retired features“](https://docs.docker.com/retired/): че Compose v1 вече не се поддържа и трябва да се мигрира към Compose v2.
- [Docker, „Announcing Compose V2 General Availability“](https://www.docker.com/blog/announcing-compose-v2-general-availability/): смяната от долна черта към тире в имената на контейнерите и предупреждението да не се зависи от тях.
- [Спецификация, `models`](https://docs.docker.com/reference/compose-file/models/): елементът от първо ниво за AI модели, споменат в 9.1.1.
- [Docker Engine 29, бележки към версиите](https://docs.docker.com/engine/release-notes/29/): версиите и датите от „За изпълненията“.
- [Colima](https://github.com/abiosoft/colima): инструментът, с който програмите са изпълнени на macOS.

### Термини от този урок

| | |
|---|---|
| **котва и псевдоним** (YAML) | `&име` отбелязва блок; `*име` се отнася до него; `<<: *име` копира ключовете му вътре в друг речник |
| **сгънат блок** (YAML) | `>-`: съединява няколко реда в един, с интервали, и маха новия ред в края |
| **поле `x-`** | поле от първо ниво, което Compose пренебрегва; използва се за пазене на блокове за повторна употреба |
| **Compose** | инструментът (`docker compose`), който чете `compose.yaml` и създава, пресъздава или изтрива необходимото, за да съществува онова, което описва |
| **`depends_on`** | ред на стартиране между услугите, с условие: `service_started`, `service_healthy` или `service_completed_successfully` |
| **канонична форма** | дългата и пълна версия на файла, с всички изписани стойности по подразбиране; показва я `docker compose config` |
| **проект** | разгръщане на един `compose.yaml`; името му стои пред всичко, което Compose създава |
| **тайна на Compose** | файл, който Compose монтира само за четене в `/run/secrets/<име>`, само в услугите, които я искат |
| **услуга** | рецептата на контейнер в `compose.yaml`; името ѝ е онова, което се използва в DNS на проекта |

---

**Следващ:** [Урок 10 — Предаване на образа](10-entregar-la-imagen.md)
