# Урок 8 — Томове и мрежи

Понеделник е, 9:05 сутринта. В 10:00 има преглед с отдел „Операции“ и са те помолили да донесеш последния отчет на `revisor`: кои услуги са се провалили през уикенда. В петък вечерта някой е обновил контейнера както винаги: `docker rm -f`, `docker run` с новия образ и у дома. Отваряш терминала, търсиш отчета и го няма. Няма го в новия контейнер, който току-що се е родил, а старият вече не съществува. Докато го осмисляш, забелязваш още нещо: новият контейнер казва `FALLA` за тестовата услуга, със съобщение, което не си виждал: `lookup curso-docker-prueba ... no such host`. Тестовата услуга работи, `docker ps` я показва, `curl` от компютъра ти стига до нея. Но `revisor` се кълне, че не съществува. 9:12 е. Имаш два проблема, които изглеждат различни, а са един и същ въпрос: **къде живее онова, което един контейнер трябва да запази, и как намира останалите?** Този урок съществува, за да можеш да отговориш преди десет: отчетът се пази на място, което оцелява след контейнера, с правилния собственик, а контейнерите се намират по име в мрежа, която определяш ти, като частта, която няма нужда от интернет, е затворена в мрежа без изход.

**Време:** 2 × 45 мин

**Какво изграждаш:** отчета, който оцелява, и два контейнера, които си говорят. Образът `curso-docker-revisor:1.5.0` съдържа папка `/datos`, която принадлежи на потребителя без привилегии `65532`, и по подразбиране пази там отчета си. Именуван том, `curso-docker-reportes`, се монтира в тази папка и запазва отчета, дори да изтриеш контейнера. Тестовата услуга живее **само** във вътрешна мрежа, `curso-docker-interna`, без изход към интернет; `revisor` живее в мрежа, определена от теб, `curso-docker-red`, през която е достъпен портът му, и освен това се свързва с вътрешната, за да проверява тестовата услуга по името ѝ.

**Какво научаваш:** къде пише един контейнер и защо това се губи; трите вида монтиране (именувани томове, *bind mounts* и `tmpfs`) и кога да използваш всеки; `-v` срещу `--mount`; кой е собственикът на файловете, когато процесът не е `root`, и как да го поправиш от образа, а не с `root`; какво става със съдържанието на папка, когато монтираш нещо отгоре (понякога се копира, понякога се закрива); мрежата по подразбиране и защо там няма имена; мрежите, определени от потребителя, и вътрешния им DNS; и вътрешните мрежи, без изход.

**Откъде идваш.** От [Урок 7](07-salud-y-ciclo-de-vida.md) носиш образа `curso-docker-revisor:1.4.0`, с неговите `HEALTHCHECK` и `STOPSIGNAL`, и начина да го стартираш с подсилена защита: файлова система само за четене, без capabilities, без повишаване на привилегиите, с `--init` и с ограничения. Носиш и едно обещание: в Урок 7 отчетът се пазеше в `tmpfs`, който умира с контейнера, и остана да му се даде място, което да трае. От [Урок 6](06-configuracion-y-secretos.md) носиш монтирането на отделен файл (токена в `/run/secrets/`), използвано без да се обясни в дълбочина, и грешката с правата с потребителя `65532`: днес същата грешка се връща, в цяла папка. От [Урок 2](02-contenedores-dia-a-dia.md) носиш образа `curso-docker-prueba:1.0.0` и навика да публикуваш портове само на `127.0.0.1`. А от [Урок 3](03-primer-dockerfile.md) — едно изречение, което днес придобива смисъл: `revisor` проверяваше сам себе си, „защото още няма мрежа между контейнерите“.

**Какво не прави този урок.** Не използва Compose: всичко се прави с `docker volume`, `docker network` и `docker run`, за да видиш всяка част; [Урок 9](09-compose.md) пише същото в `compose.yaml`. Не учи драйвери за отдалечени томове (мрежово хранилище, в облака), нито мрежи, които обхващат няколко машини (*overlay*): този курс работи на един компютър, а онова, което научаваш тук (собственикът на файловете, DNS по име, мрежата без изход), е нужно и на тези други инструменти. Не използва мрежата `host` за друго, освен за да каже защо не се използва. И не прави резервни копия, нито възстановява томове със специални инструменти: отчетът се чете с помощен контейнер, което е начинът да погледнеш в том, който работи на всеки компютър.

**За изпълненията.** Всички изходи са реални и са получени на 21 октомври 2026 г. на Mac с [Colima](https://github.com/abiosoft/colima), която стартира виртуална машина с Ubuntu 24.04.4, същата основа като Linux Mint 22, референтната система на курса, с ядро 6.8 и процесор `arm64`. Скриптовете бяха пуснати **вътре** в тази виртуална машина, с Docker 29.2.1 (клиент и демон) и Buildx v0.31.1, и с работната им папка на собствения диск на Linux. Това е много важно в този урок, който се занимава със собственици и права: папките, споделени между Mac и виртуалната машина, лъжат за тях, и нито един пример за собственици не е измерен в такава папка. В твоя Mint този проблем не съществува. Две разлики, които ще видиш с очите си: във виртуалната машина потребителят, пуснал скриптовете, е `501`, с група `1000`, така че там, където изходът казва `501:1000`, твоят Mint почти сигурно ще каже `1000:1000`, първия потребител, създаден при инсталирането; а датите на `ls -l` са в часа на виртуалната машина, който е по Гринуич. За да не се сблъскват с други изпълнения, които използваха същата машина, скриптовете бяха пуснати с друг префикс на имената и друг порт (променливите `PREFIJO` и `PUERTO`, които имат). Тъй като в този урок имената на мрежи, томове и контейнери **се** появяват в изходите (DNS ги използва), скриптовете, които показват имена, имат функция `nombres`, която видимо изписва отново този префикс като `curso-docker-`; с префикса по подразбиране не променя нищо, така че онова, което виждаш, е онова, което ще видиш и ти. Със стойностите си по подразбиране скриптовете използват собствени помощни имена, които съдържат `fig08` (образът `curso-docker-revisor:fig08`, и `:fig08-l7`, 1.4.0, който изгражда `fig08_02.sh`; контейнерът `curso-docker-revisor-fig08`, томът `curso-docker-reportes-fig08`, мрежите `curso-docker-red-fig08` и `curso-docker-interna-fig08`): така никога не пипат твоя образ `curso-docker-revisor:1.5.0`, твоя контейнер `curso-docker-revisor`, твоя том `curso-docker-reportes`, нито твоите мрежи, а при излизане изтриват само онова, което са създали. По същата причина по подразбиране публикуват порта си на `127.0.0.1:8081`, а не на `8080` на твоя `revisor`: така можеш да ги пускаш, докато крайното ти състояние работи (ако `8081` ти е зает, подай им друг, например `PUERTO=8082 ./fig08_03.sh`; портът не се появява в изходите). Използват, без да ги променят, два образа, които вече имаш: `curso-docker-prueba:1.0.0` от Урок 2 и `alpine:3.24.2`, помощен контейнер с *shell* за разглеждане на томове и мрежи, защото двата образа на курса нямат *shell*. Курсът беше планиран с Docker Engine 29.8.2, а най-новата публикувана в този ден беше 29.9.2, от 20 октомври 2026 г. ([бележки към версиите](https://docs.docker.com/engine/release-notes/29/)); нищо в този урок не се променя между тези версии. Което **се** променя от едно изпълнение до друго, и се казва там, където се появява: времената в таблицата на `revisor` (скрити с `<t>`), номерът на временния файл на отчета (скрит с `<n>`), IP адресите на контейнерите и този на DNS на компютъра ти (скрити с `<IP>` и `<DNS del anfitrión>`), идентификаторите на контейнери (`<id>`) и датите. Всичко се скрива в самия скрипт, видимо, никога чрез редактиране на изхода. Програмите са в [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes), всяка с изхода си до нея, а `estado/` пази файловете на проекта такива, каквито остават накрая.

## След урока ще можеш да

- Обясниш защо онова, което един контейнер пише в собствената си файлова система, се губи с `docker rm`, и да избереш между именуван том, *bind mount* и `tmpfs` за всяка от данните на `revisor`.
- Предизвикаш и диагностицираш `permission denied` на нов том с процес без привилегии и да го поправиш в образа с `COPY --chown`, без да работиш като `root`.
- Докажеш, че отчетът оцелява след `docker rm`, като го прочетеш от помощен контейнер.
- Предскажеш какво става със съдържанието на папка, когато монтираш отгоре нов том, том с данни или *bind mount*, и да обясниш разликата между `-v` и `--mount`, когато папката на компютъра не съществува.
- Стартираш `revisor` с *bind mount* на твоя папка, като поправиш собственика с `--user`, и да монтираш само за четене онова, което контейнерът не бива да променя.
- Покажеш, че в мрежата по подразбиране един контейнер не намира друг по името му, а в мрежа, определена от потребителя — да, като разчетеш кой DNS сървър използва всеки.
- Затвориш тестовата услуга във вътрешна мрежа без изход към интернет и да свържеш `revisor` с двете мрежи, без да го рестартираш.

## Защо, преди как

Досега всеки контейнер в курса беше остров за еднократна употреба. Създаваше го, питаше го нещо, изтриваше го. Това беше добре за учене, защото контейнер за еднократна употреба не може да крие изненади. Но истинската услуга има две нужди, които един остров не покрива.

Първата е **да пази нещо, което трае повече от нея**. `revisor` пише отчет; този отчет е точно онова, което някой ще поиска в понеделник. А контейнерът е направен, за да бъде заменян: всяко обновяване, всяка промяна на конфигурацията, всяко рестартиране на машината с `--rm` завършва с нов контейнер. Документацията на Docker го казва без заобикалки: записаното в слоя на контейнера „не се запазва, когато контейнерът бъде унищожен“, а освен това „може да е трудно данните да се извадят от контейнера, ако друг процес има нужда от тях“ ([Docker, „Storage“](https://docs.docker.com/engine/storage/)). Ако отчетът живее вътре в контейнера, живее колкото контейнера. А от Урок 7 насам проблемът е още по-пряк: файловата система на `revisor` е **само за четене**. Не че отчетът ще се изгуби; той дори не може да бъде записан. Нужно е място с право на запис, извън контейнера, което `revisor` да може да използва, без да престава да е само за четене.

Втората е **да говори с други контейнери**. `revisor` съществува, за да проверява услуги, а досега е проверявал само себе си (`propio http://127.0.0.1:8080/salud`), защото вътре в контейнер `127.0.0.1` е самият контейнер. За да провери тестовата услуга, трябва да стигне до друг контейнер. Би могъл да използва IP адреса ѝ, но адресите ги раздава Docker при стартиране и те се променят; никой не иска да пише в `REVISOR_SERVICIOS` адрес, който престава да важи при следващото рестартиране. Онова, което искаш, е онова, което прави всяка програма в интернет: да използва **име**. А щом контейнерите започнат да си говорят, се появява въпросът за сигурността в този урок: ако тестовата услуга съществува само за да я пита `revisor`, защо изобщо да може да излиза в интернет?

Така че урокът има две половини и двете следват един и същ път: първо грешката, после поправката.

1. **Съхранение** (8.1 до 8.7): къде пише контейнерът, трите вида монтиране, грешката със собственика, която ще срещнеш с потребител без привилегии, и поправката ѝ в образа, какво става с онова, което вече е имало в папката, и `tmpfs` за онова, което не бива да трае.
2. **Мрежи** (8.8 до 8.11): мрежата по подразбиране, която няма имена; мрежата, която определяш ти, която има; и вътрешната мрежа, която няма изход.

С тази цел пред очи, ето какво ще имаш накрая, в раздел 8.10: тестовата услуга в мрежа без изход, `revisor` в двете, който я намира по име, и контейнер, който се опитва да излезе в интернет от вътрешната мрежа и не може дори да разреши името на сайта:

```text
== 3. Conectar el revisor también a la interna, sin reiniciarlo
SERVICIO  ESTADO    TIEMPO  DETALLE
prueba    OK           <t>  200
curso-docker-interna-fig08 curso-docker-red-fig08 

== 4. Desde la red interna no hay salida a internet
wget: bad address 'www.docker.com'
[código de salida: 1]
```

## Понятията

### 8.1 Къде пише един контейнер

#### 8.1.1 Слоят за запис и защо не става за съхранение

В Урок 4 видя, че образът е купчина от слоеве само за четене. Когато Docker създава контейнер, слага отгоре **още един слой, с право на запис и собствен на този контейнер**. Всичко, което процесът пише (нов файл, променен файл, изтрит файл), остава в този слой; слоевете на образа не се пипат и затова сто контейнера могат да произлизат от един и същ образ, без да си пречат.

Този слой има три проблема за съхраняването на отчет:

- **Умира с контейнера.** `docker rm` го изтрива. `docker run --rm` го изтрива при излизане. Обновяване, което заменя контейнера, го изхвърля.
- **Трудно е да извадиш нещо от него.** Намира се някъде във вътрешното хранилище на Docker, с път, който не е за теб. Друг контейнер не може да го прочете.
- **В `revisor` с подсилена защита той не съществува за запис.** С `--read-only` слоят за запис не приема записи. Точно това искаше в Урок 7: който поеме контрола над процеса, не може да пише на диска. Но и самият `revisor` не може.

Изходът е да се **монтира** нещо върху папка на контейнера: място с право на запис, което не е част от слоя на контейнера, което има собствен жизнен цикъл и което се монтира само там, където е нужно. Останалата файлова система остава само за четене.

#### 8.1.2 Трите вида монтиране

Docker предлага три вида монтиране, които те интересуват тук (има още два, които няма да използваш: именуваните канали, само за Windows, и монтиранията на образи, които слагат съдържанието на друг образ вътре в контейнера и изискват хранилището за образи на containerd). Документацията ги представя така ([Docker, „Storage“](https://docs.docker.com/engine/storage/)):

| Вид | Какво е | Къде живеят данните | Колко траят | За какво |
|---|---|---|---|---|
| **Том** (именуван) | хранилище, „управлявано от демона на Docker“ | в папка от хранилището на Docker, която ти не пипаш | докато не изтриеш тома, дори да изтриеш всички контейнери | данните на услугата, които трябва да траят: отчетът |
| ***Bind mount*** | „пряка връзка“ между път на компютъра и път в контейнера | в твоя папка, там, където кажеш | колкото трае тази папка | файлове, които и ти, и контейнерът трябва да виждате: код в разработка, конфигурационен файл, токенът от Урок 6 |
| **`tmpfs`** | файлове „направо в паметта“ на компютъра | в паметта | докато контейнерът не спре | временни файлове, които не бива да траят, нито да докосват диска |

Същата страница дава кратката препоръка: томовете са за дългосрочно съхранение; *bind mounts* — „когато трябва да имаш достъп до файловете както от контейнера, така и от компютъра“; а `tmpfs` — „само когато данните не трябва да се запазват след сесията на контейнера“. При `revisor` това се превежда в просто правило: **отчетът отива в том**. *Bind mounts* вече ги използва за токена и днес ще ги използваш, за да разбереш проблема със собствениците; `tmpfs` — за онова, което не бива да оцелее.

#### 8.1.3 Два начина да се напише едно и също: `-v` и `--mount`

Docker приема два синтаксиса за монтиране и ще ги виждаш навсякъде:

- **`-v източник:цел[:опции]`** (или `--volume`). Кратък. Ако източникът е име (`curso-docker-reportes`), това е том; ако е абсолютен път (`/home/tu/reportes`), това е *bind mount*. Опциите са в края, разделени със запетаи: `ro` за само четене, например.
- **`--mount type=…,src=…,dst=…[,опции]`**. Дълъг, с имена на всяко поле: `type=volume`, `type=bind` или `type=tmpfs`, а след това `src` (източникът), `dst` (целта), `readonly` и опциите, присъщи на всеки вид.

Документацията за томовете казва, че „по принцип се предпочита `--mount`“, защото „е по-изричен и поддържа всички налични опции“ ([Docker, „Volumes“](https://docs.docker.com/engine/storage/volumes/)). `--mount` поддържа всички опции на всеки вид монтиране; `-v` — само някои. За том `-v` поддържа малко: тези за достъп (`ro` и `rw`), тези за етикетиране на SELinux (`z` и `Z`, които на теб в Mint не ти трябват) и тази за некопиране на съдържанието на образа, която ще видиш в 8.5. Последната има измерен капан: страницата за томовете я нарича `volume-nocopy` и при `-v`, но Docker 29.2.1 отхвърля това име с `invalid mode: volume-nocopy`; с `-v` се пише `nocopy` (`-v vol:/datos:nocopy`), а с `--mount` — `volume-nocopy`. Виждаш го във `fig08_09.sh`, решението на Упражнение 4. И има разлика в поведението, която е важна: когато папката на компютъра **не съществува**, `-v` я създава, а `--mount` по подразбиране отказва (8.5). Този курс използва `-v` за именуваните томове, защото това ще четеш в повечето примери и е също толкова ясно (`-v curso-docker-reportes:/datos` не оставя съмнения), и `--mount` за *bind mounts* и `tmpfs`, където точността му предотвратява грешки.

### 8.2 Именувани томове

#### 8.2.1 Създаване, разглеждане, изтриване

Том се създава с `docker volume create <име>`, изброява се с `docker volume ls`, разглежда се с `docker volume inspect` и се изтрива с `docker volume rm`. Ако в `docker run` монтираш том, който не съществува, Docker го създава в този момент; въпреки това създаването му предварително, с име, показва ясно, че това е нещо, което си решил да имаш, а не страничен ефект.

Томовете на драйвера по подразбиране, `local`, живеят в папка на компютъра, вътре в хранилището на Docker: документацията показва пътя `/var/lib/docker/volumes/<име>/_data` ([Docker, „Volumes“](https://docs.docker.com/engine/storage/volumes/)). Тази папка е на Docker и на `root`. Можеш да я видиш със `sudo`, но не е за ръчно пипане: за да погледне в том, курсът използва **помощен контейнер** — `alpine` за еднократна употреба, който монтира тома само за четене и изпълнява `ls` или `cat`. Работи еднакво на Mint, на Mac или на сървър, не изисква `sudo` и няма как да повреди данните.

Томът **не се изтрива** с контейнера. Това е причината да съществува. Нито `docker rm`, нито `docker rm -f`, нито `docker stop` го пипат. Единственото изключение са **анонимните** томове (онези, които се създават без име, например с `-v /datos` без източник): документацията казва, че те се унищожават с контейнера само ако си го създал с `--rm` ([Docker, „Volumes“](https://docs.docker.com/engine/storage/volumes/)). Именуваният том живее, докато не го изтриеш с `docker volume rm`. Затова курсът винаги им дава име, и то с префикса `curso-docker-`: анонимният том е идентификатор от 64 знака, за който никой не помни чий е и който накрая заема диск завинаги.

### 8.3 Грешката: нов том върху папка, която образът няма

#### 8.3.1 Да я предизвикаш

С казаното дотук планът изглежда очевиден: да създадеш том, да го монтираш в `/datos` и да кажеш на `revisor` да пази там отчета си с `REVISOR_REPORTE=/datos/reporte.json`. Скриптът `fig08_02.sh` прави точно това с образа от Урок 7, с подсилена защита, както го остави:

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

Новите редове в скрипта, преди да разчетем изхода. `docker create` създава контейнер, без да го стартира, а `docker export` изважда цялата му файлова система като `tar` файл; `tar -tv` я изброява, без да я разопакова, а `--numeric-owner` показва собствениците като числа. Това е начинът да видиш **какви папки съдържа образ**, който няма *shell*, за да се изпълни `ls`. `docker volume inspect` показва какво знае Docker за един том. А `-v "$VOLUMEN":/datos:ro` в помощния контейнер монтира тома само за четене: помощникът само гледа.

Сега изходът, блок по блок:

1. **Образът от Урок 7 няма `/datos`.** Броят на редовете от `tar`, които завършват на ` datos/`, е `0`. Никой не я е създал: в Урок 7 отчетът отиваше в `/tmp`.
2. **Томът е нов и празен.** Драйверът му е `local` и живее в `/var/lib/docker/volumes/curso-docker-reportes-fig08/_data`, пътя, който казва документацията.
3. **`revisor` стартира, отговаря на `/salud` и се проваля при запис.** `/api/estados` отговаря с `500` с `permission denied` при отварянето на временния файл на отчета. (Спомни си от Урок 3, че `revisor` първо пише временен файл в същата папка и после го преименува: затова грешката споменава `.reporte-<n>.tmp`, а не `reporte.json`.) `/salud` остава на `200`, защото не записва нищо; а тъй като `HEALTHCHECK` използва `/salud`, Docker би казал, че този контейнер е `healthy`. Работи, здрав е за Docker и не може да си върши работата: вторият принцип на курса, отново.
4. **Папката е на `root`.** Помощникът показва `/datos` със собственик `0` и група `0`, права `drwxr-xr-x`: само собственикът пише. А `revisor` работи като `65532:65532`.

#### 8.3.2 Защо се случва

Когато монтираш том на път, който образът няма, Docker трябва да създаде тази точка на монтиране, а новият том се ражда с коренова папка, която принадлежи на `root`. Никой не му е казал друго. Докато процесът на контейнера беше `root` (както в толкова много ръководства), това не се забелязваше: `root` пише, където си иска. Но `revisor` престана да бъде `root` в Урок 3, а потребител без привилегии не заобикаля ничии права. Така ядрото прави онова, което би направило с всеки потребител на компютъра ти, който се опитва да пише в чужда папка: отказва.

Това е същата грешка от Урок 6 с файла на токена, в друга форма. Там файлът беше твой, а процесът — `65532`; тук папката е на `root`, а процесът — `65532`. Въпросът, който я решава, е същият: **кой е собственикът и с какъв потребител работи процесът?**

Има три поправки, които ще видиш в интернет, и само една е добра:

- **Да работиш като `root`** (`--user 0`). Работи и разваля работата от пет урока. Не.
- **Да смениш собственика на тома отвън**, с помощен контейнер, който изпълнява `chown 65532:65532 /datos`, преди да стартира `revisor`. Работи, но това е още една стъпка, която някой трябва да помни на всеки компютър, и контейнер, който работи като `root` само за това.
- **Образът да съдържа папката, с правилния собственик.** Това е поправката в този урок и тя работи благодарение на едно правило на томовете, което се обяснява в 8.4.

### 8.4 Поправката: образът съдържа `/datos`, на правилния потребител

#### 8.4.1 Правилото, което я прави възможна

Документацията за томовете описва какво става, когато монтираш **празен** том в папка на контейнера, която **вече има** файлове или папки: „тези файлове или папки се разпространяват (копират) в тома“ ([Docker, „Volumes“](https://docs.docker.com/engine/storage/volumes/)). Документацията говори за съдържанието; онова, което не казва и ще измериш в 8.4.3, е, че копието носи и собственика и правата на папката от образа. Ако образът съдържа `/datos` със собственик `65532`, нов том, монтиран там, се ражда със собственик `65532`. Значи поправката не е в `docker run`: тя е в Dockerfile.

#### 8.4.2 Dockerfile от този урок

Ето Dockerfile, с който завършва урокът. Това е онзи от Урок 7 с три промени, отбелязани по-долу:

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

Трите промени:

1. **`&& mkdir -p /out/datos` в етапа `binario`.** Създава празна папка до двоичния файл. Създава се в етапа на компилиране, защото крайният образ, *distroless*, няма *shell*, нито `mkdir`: там няма с какво да се създаде папка. Добавя се към същия `RUN`, който компилира, за да не се добавя още един слой към този етап; в крайния образ няма значение, защото той получава само онова, което се копира.
2. **`COPY --from=binario --chown=65532:65532 /out/datos /datos` в етапа `final`.** Копира тази празна папка в `/datos` и ѝ задава собственик и група `65532`. Според справочника на Dockerfile `--chown` „задава собственика на копираните файлове“, а без тази опция те остават с потребител и група `0` ([справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/)). Използват се числа, а не имена, защото крайният образ няма защо да знае кой е `nonroot`; числото е онова, което ядрото сравнява.
3. **`REVISOR_REPORTE=/datos/reporte.json` в `ENV`.** Стойността по подразбиране за това къде се пази отчетът. Това е конфигурация, не тайна (Урок 6), и важи във всяка среда, защото папката идва с образа. Който стартира образа, без да казва нищо, пази в `/datos`, а ако монтира там том, отчетът трае.

Тази трета промяна има последствие, което е добре да видиш, преди да те изненада. Образът 1.5.0 **очаква** `/datos` да е с право на запис. Ако го стартираш с `--read-only` и **без** том, както в Урок 7, `/api/estados` пак се проваля, сега с `read-only file system`. Ще го видиш в блок 6 на `fig08_03.sh`, в 8.4.3.

Това не е дефект: това е образът, който ти казва къде пази. От този урок нататък `revisor` с подсилена защита се стартира с нещо с право на запис, монтирано в `/datos`: почти винаги именуван том, а *bind mount* — когато друг инструмент на компютъра трябва да чете отчетите (8.6). Ще го виждаш във всички следващи скриптове, включително тези за мрежите, и в `compose.yaml` от Урок 9.

#### 8.4.3 Да я видиш да работи и да я видиш да оцелява

Скриптът `fig08_03.sh` изгражда образа 1.5.0, разглежда неговата `/datos`, монтира му нов том и след това изтрива контейнера, за да види какво остава:

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

Блок по блок:

1. **Образът тежи 16.2 MB**; 1.4.0 от Урок 7 беше 16.1 MB. Празна папка почти не тежи: разликата е от закръгляне. Средата му съдържа двете стойности по подразбиране, `REVISOR_PUERTO=8080` и `REVISOR_REPORTE=/datos/reporte.json`. А `tar` на файловата му система вече показва `datos/` със собственик `65532/65532`.
2. **Новият том е наследил собственика.** `/api/estados` отговаря с `200`. Помощникът показва `/datos` със собственик `65532`, а не `0`: това е копието от 8.4.1. Вътре е `reporte.json`, на `65532`, с права `-rw-------`: само собственикът му го чете и пише. (Това `600` го решава `revisor`: създава временния файл с функцията `os.CreateTemp` на Go, която използва тези права, и след това го преименува. Помощникът може да го прочете, защото работи като `root`.) Броят байтове зависи от това колко услуги проверява.
3. **Том в употреба не може да бъде изтрит.** `docker volume rm` излиза с код `1` и ти казва кой го използва: `volume is in use`, с идентификатора на контейнера в квадратни скоби. Това е защита: не можеш да издърпаш пода изпод контейнер, който пише.
4. **Контейнерът си отива; томът и отчетът остават.** След `docker rm -f` няма контейнер с това име, томът е още в списъка, а помощникът чете целия отчет: една услуга, `propio`, здрава, с код `200` (времето се променя при всяко изпълнение). Това липсваше в понеделник сутринта.
5. **Нов контейнер поема тома.** `revisor` се ражда отново, намира предишния отчет на мястото му, заменя го със следващата проверка (`200`), а `docker inspect` показва монтирането: `volume curso-docker-reportes-fig08 -> /datos (escribible: true)`. Файловата система на контейнера остава само за четене; `/datos` е единственото изключение и то има име.
6. **Без тома 1.5.0 с подсилена защита не може да записва.** Това е последствието от 8.4.2: `read-only file system` и `500`. Образът вече казва къде пази; който го стартира с `--read-only`, трябва да му даде това място.

#### 8.4.4 В твоята папка

Проектът ти живее в `~/curso-docker/revisor` от Урок 3 насам. От корена на хранилището на курса сложи там Dockerfile от този урок, изгради образа, който ще запазиш, и създай тома си:

```bash
cp programas/08-volumenes-y-redes/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.5.0 -t curso-docker-revisor:1.5.0 .
docker volume create curso-docker-reportes
```

`.dockerignore` и папката `secretos/` не се променят. Преди да продължиш, повтори ръчно грешката и поправката със собствените си имена: стартирай `curso-docker-revisor:1.4.0` с току-що създаден том в `/datos` и `-e REVISOR_REPORTE=/datos/reporte.json` и виж `500`; изтрий го заедно с този том; и стартирай `curso-docker-revisor:1.5.0` с `curso-docker-reportes`. Единственото, което се различава от скриптовете, са имената. Скриптовете на този урок не пипат нищо от това: използват помощни имена с `fig08` и изтриват само своето.

### 8.5 Копиране срещу закриване: онова, което вече е имало в папката

#### 8.5.1 Четири случая, които е добре да не се бъркат

Правилото от 8.4.1 има условия и почти всички стряскания с монтиранията идват от забравянето им. Когато монтираш нещо върху папка на контейнера, която вече има съдържание, става едно от следните неща:

| Какво монтираш | Какво вижда контейнерът | Какво става със съдържанието на образа |
|---|---|---|
| **нов и празен** том | съдържанието на образа | **копира се** в тома, със собственици и права |
| нов том с `volume-nocopy` | празна папка | не се копира; остава закрито |
| том, **който вече има данни** | онова, което има в тома | остава **закрито**; нищо не се копира |
| ***bind mount*** | онова, което има в папката на компютъра | остава **закрито**; нищо не се копира |

„Закрито“ е думата от документацията: ако монтираш том с данни там, където вече е имало файлове, „предишните файлове остават скрити от монтирането“ ([Docker, „Volumes“](https://docs.docker.com/engine/storage/volumes/)); при *bind mount* „съществуващото съдържание на папката остава скрито“ ([Docker, „Bind mounts“](https://docs.docker.com/engine/storage/bind-mounts/)). Не се изтриват: остават в слоя на образа, отдолу, и се появяват отново, ако стартираш контейнер без монтирането. Но докато монтирането е там, контейнерът не ги вижда.

Обърни внимание на третия ред, защото има практическо последствие: копирането става **само първия път**, когато томът е празен. Ако томът `curso-docker-reportes` е създаден с образа 1.5.0, а утре образ 1.6.0 носи нещо различно в `/datos`, томът не се обновява: вече има данни, така че печели томът. За отчет това е точно каквото искаш (данните на услугата не бива да се променят, защото се е променил образът). За онзи, който пази в том файлове, които би трябвало да идват от образа, това е класически източник на „обнових, а пак е същото“.

#### 8.5.2 Да го видиш с помощен контейнер

Скриптът `fig08_04.sh` показва четирите случая с помощния `alpine`, върху неговата папка `/etc/apk`, която съдържа пет записа. Накрая изпробва разликата между `-v` и `--mount` с папка на компютъра, която не съществува:

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

Блок по блок:

1. **Без монтиране** `/etc/apk` има пет записа: `arch`, `keys`, `protected_paths.d`, `repositories` и `world`.
2. **С нов том** контейнерът вижда същите пет. И не че вижда тези на образа „през“ тома: монтиран на друг път (`/mirar`), в друг контейнер, томът ги има. Docker ги е копирал, когато го е монтирал за първи път.
3. **С `volume-nocopy`** — нула записа. Опцията казва на Docker да не копира, макар томът да е празен ([Docker, „Volumes“](https://docs.docker.com/engine/storage/volumes/)); с `-v` също съществува, но се пише `nocopy` (8.1.3). Ако някога я видиш в `docker run` на `revisor`, вече знаеш какво ще стане: томът се ражда с папка на `root`, както в 8.3, и `permission denied` се връща. Ще го провериш в Упражнение 4.
4. **С *bind mount* на празна папка** — нула записа: онова от образа е останало закрито. А папката на компютъра остава празна: *bind mount* не копира нищо в никоя посока. Контейнерът вижда **твоята папка**, такава, каквато е, и нищо повече.
5. **`-v` с път на компютъра, който не съществува**: контейнерът стартира, без да се оплаква, а на компютъра ти се появява папката `no-existia`... със собственик `root:root`. Създал я е демонът, който работи като `root`. Документацията го казва така: с `-v` „Docker създава папката на компютъра вместо теб“ ([Docker, „Bind mounts“](https://docs.docker.com/engine/storage/bind-mounts/)). Онова, което не казва толкова високо, е собственикът, а точно това хапе: правописна грешка в пътя ти оставя папка на `root` в проекта, контейнер, който пише на грешното място, и, ако процесът не е `root`, още едно `permission denied`.
6. **`--mount` с път, който не съществува**: отказва. `invalid mount config for type "bind": bind source path does not exist`, с код `125`, който `docker run` използва, когато грешката е на самия Docker, а не на програмата. Това е поведението, което искаш: правописната грешка се вижда веднага. (Пътят се появява като `./tampoco-existe`, защото скриптът скрива временната папка, която се променя при всяко изпълнение.) Това е поведението по подразбиране: `--mount` също може да създаде папката, ако го поискаш с опцията `bind-create-src`, която според документацията „автоматично създава папката източник на компютъра, ако не съществува“ ([Docker, „Bind mounts“](https://docs.docker.com/engine/storage/bind-mounts/)). Този курс не я използва, защото целта е точно правописната грешка да се вижда. Затова използва `--mount` за *bind mounts*.

### 8.6 *Bind mounts* и собственикът на файловете

#### 8.6.1 Кога *bind mount*, а не том

*Bind mount* е полезен, когато ти, от компютъра си, трябва да виждаш или да слагаш файловете, без да минаваш през Docker: кода на програма, докато я разработваш, конфигурационен файл, който редактираш ръчно, токена от Урок 6 или отчет, който друг инструмент на компютъра ти ще прибере. Цената е, че контейнерът пише **направо във файловата ти система**. Документацията предупреждава: с *bind mount* „можеш да променяш файловата система на компютъра от процеси, които работят в контейнер“, а *bind mounts* имат по подразбиране „право на запис във файловете на компютъра“ ([Docker, „Bind mounts“](https://docs.docker.com/engine/storage/bind-mounts/)). Затова, когато контейнерът трябва само да чете, монтирането е с `readonly`, като токена.

#### 8.6.2 Същата грешка, от обратната страна

При тома папката беше на `root`, а поправката беше образът да носи своя. При *bind mount* това не помага: контейнерът вижда **твоята** папка, с **твоя** собственик, а онова, което образът носи в `/datos`, остава закрито (8.5). Така сблъсъкът се връща, сега между твоя потребител и `65532`. Скриптът `fig08_05.sh` го предизвиква и го поправя без `root`:

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

Блок по блок:

1. **Папката е твоя**: собственик `501:1000`, права `775` (ти и групата ти пишете; останалите — не). В твоя Mint ще казва `1000:1000`. Скриптът отпечатва потребителя ти, за да сравниш.
2. **Монтирана в `/datos` — `permission denied`.** `revisor` работи като `65532`, който не е собственикът, нито е в групата `1000`, а за „останалите“ папката не е с право на запис. Монтирането не превежда нищо: вътре в контейнера папката има същия числов собственик като отвън. (С Docker без `root` или с пренасочване на потребителите числото вътре се превежда в друго отвън; инсталацията от Урок 1 не прави това.)
3. **Поправката: стартиране на контейнера с твоя потребител.** `--user "$(id -u):$(id -g)"` заменя `65532` на образа с твоите числа и сега процесът е собственикът на папката: `200`. А отчетът, видян от компютъра ти, е твой (`501:1000`, `600`): четеш го без `docker` и без `sudo`. Обърни внимание на онова, което **не** се промени: процесът продължава да не е `root`, продължава да е без capabilities, а файловата система остава само за четене. Смени един потребител без привилегии с друг потребител без привилегии — твоя. Внимание: ако изпълниш командата със `sudo`, `$(id -u)` е `0` и би работил като `root`, без да усетиш. Затова в Урок 1 влезе в групата `docker`: тези команди се изпълняват без `sudo`. `docker inspect` го потвърждава: `User=501:1000`, и монтирането `bind -> /datos (escribible: true)`.
4. **Само за четене — ядрото отказва.** С `readonly` `revisor` пак се проваля, сега с `read-only file system`: дори като собственик не може да пише. За отчета това няма смисъл, но е точно каквото искаш за конфигурационен файл или тайна: контейнерът го чете и не може да го промени.

Защо не `chmod 777` на папката? Защото позволява на **всеки потребител на компютъра ти** да пише там и на всеки контейнер с всеки потребител да я пълни. Това е версията за папка на `644` от Урок 6, но по-лоша, защото тук се пише, а не само се чете. `--user` с твоите числа решава проблема там, където се ражда: в собственика.

### 8.7 `tmpfs`: онова, което не бива да трае

#### 8.7.1 За какво

В Урок 7 използва `--tmpfs /tmp`, за да може `revisor` да пише отчета си при файлова система само за четене. Получи се, а отчетът умираше с контейнера. Сега отчетът има своя том, но `tmpfs` продължава да има място: всичко, което програмата пише и **не** бива да оцелее. Временни файлове, кешове за едно изпълнение, файл с декриптирана тайна, който не бива да докосва диска. Документацията го обобщава: за разлика от томовете и *bind mounts* `tmpfs` „е временен и се пази само в паметта на компютъра“, а „когато контейнерът спре, монтирането `tmpfs` се премахва“ ([Docker, „tmpfs mounts“](https://docs.docker.com/engine/storage/tmpfs/)). Освен това не може да се споделя между контейнери.

Две стойности по подразбиране от тази страница, които е добре да знаеш: без размер таванът на `tmpfs` е **половината от паметта на компютъра**, а правата му са `1777`, с право на запис за всеки (с бита, който не позволява изтриване на чужди файлове, същия като на `/tmp` в твоя Mint). И едно честно предупреждение: ядрото може да изпрати в паметта за размяна (*swap*) онова, което има в `tmpfs`, така че „в паметта“ не е гаранция, че никога няма да докосне диска.

#### 8.7.2 Том и `tmpfs`, един до друг

Скриптът `fig08_06.sh` пуска контейнер само за четене с двете монтирания, пише и в двете, рестартира го и гледа какво е оцеляло:

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

1. **Двете монтирания и опциите им**, прочетени от `/proc/mounts`, списъка, който води ядрото. `/datos` е `ext4`: томът живее на диска на компютъра. `/cache` е `tmpfs`, със `size=1024k` (`1m`, което поиска) и три опции, които Docker му е сложил сам, когато го е монтирал с `--mount`: `nosuid`, `nodev` и `noexec`. В Урок 7 ги написа ръчно с `--tmpfs`; с `--mount type=tmpfs` идват сами. Правата са `1777`.
2. **Пише се в двете, но не и в корена.** `a.txt` в тома, `b.txt` в `tmpfs`; а `/c.txt` се проваля с `Read-only file system`, защото извън монтиранията всичко е само за четене. Три папки, три поведения, и всяко си го поискал по име.
3. **`tmpfs` има таван.** Записването на 2 MB в `tmpfs` от 1 MB завършва с `No space left on device`. Без `size` този таван би бил половината от паметта на компютъра: програма с грешка, която пише без спиране, би могла да заеме много повече, отколкото си представяш. С тавана грешката се появява веднага и с ясно съобщение.
4. **След `docker restart` томът пази `a.txt`, а `tmpfs` е празен.** Едно рестартиране стига, за да се изтрие `tmpfs`; не е нужно да се изтрива контейнерът.

Документацията предпочита `--mount type=tmpfs` и признава, че `--tmpfs` „е по-малко многословен“ и поддържа повече опции за монтиране ([Docker, „tmpfs mounts“](https://docs.docker.com/engine/storage/tmpfs/)). И двата стават. Важното е да му сложиш размер.

#### 8.7.3 Кое да използваш в `revisor`

| Данни | Монтиране | Защо |
|---|---|---|
| отчетът (`/datos/reporte.json`) | именуван том в `/datos` | трябва да оцелее след контейнера; никой няма нужда да го редактира ръчно |
| токенът (`/run/secrets/revisor_token`) | *bind mount* на файл, `readonly` | слагаш го ти отвън; контейнерът само го чете |
| временен файл, който програмата не бива да пази | `tmpfs` с размер | трябва да умре с контейнера и да не заема диск |
| кодът на програмата | никакво: отива в образа | това е код, не данни (Урок 6) |

### 8.8 Мрежи: мрежата по подразбиране няма имена

#### 8.8.1 Какво е мрежа на Docker

Всеки контейнер има собствен мрежов стек: своите интерфейси, своя IP адрес, своята маршрутна таблица, своя `127.0.0.1`. Това е една от изолациите от Урок 0. За да могат контейнерите да си говорят, Docker ги свързва с **мрежи**: отдолу, в Linux, виртуален мост (*bridge*), към който се свързва по един интерфейс на всеки контейнер, като кабели към един и същ комутатор. Драйверът по подразбиране се казва точно `bridge`.

Docker създава три мрежи при инсталирането, `bridge`, `host` и `none` (виждаш ги с `docker network ls`), и ако не кажеш друго, всеки контейнер се свързва с `bridge`. Там е бил всеки контейнер от курса досега. Тази мрежа има ограничение, което документацията казва без украшения: в мрежата по подразбиране контейнерите „могат да се достигат само по IP адрес“. Нещо повече: „мрежата `bridge` по подразбиране се смята за наследен детайл на Docker и не се препоръчва за продукция“ ([Docker, драйвер `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)).

#### 8.8.2 Да го видиш: по име — не, по IP — да

Скриптът `fig08_07.sh` слага `revisor` и тестовата услуга в мрежата по подразбиране и иска от `revisor` да провери `http://curso-docker-prueba-fig08:9000/`. След това прави същото в мрежа, определена от потребителя, а накрая чупи тестовата услуга от друг контейнер:

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

Първата половина от изхода, мрежата по подразбиране:

1. **`FALLA`, с `no such host`.** Цялото съобщение се чете отдясно наляво: `no such host` (името не съществува), `lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53` (попитал е DNS сървъра на компютъра ти, на порт 53, този на DNS), `dial tcp` (искал е да отвори връзка) и `Get "http://…"` (за да направи тази заявка). DNS сървърът на компютъра ти няма представа кои контейнери работят в Docker, затова отговаря единственото, което може: това име не съществува. Реалният адрес на този сървър зависи от всяка мрежа и скриптът го скрива.
2. **Двата са в една и съща мрежа**, `bridge`. Не че са разделени: заедно са и въпреки това не се намират по име.
3. **DNS, който получават, е този на хоста.** Документацията обяснява, че контейнерите в мрежата по подразбиране получават копие на `/etc/resolv.conf` от компютъра ти ([Docker, „Networking“](https://docs.docker.com/engine/network/)). Помощникът го показва: `nameserver <DNS del anfitrión>`. Един нюанс за твоя Mint: ако в своя `/etc/resolv.conf` виждаш `nameserver 127.0.0.53` (локалният резолвер на *systemd*, нормалното в Mint и Ubuntu), този адрес вътре в контейнера би сочил към самия контейнер, където няма никакъв DNS, затова Docker не го копира такъв, какъвто е; контейнерът получава други сървъри. Документацията „Networking“ не описва подробно това преобразуване; за да разбереш какво е получил твоят, сравни с помощника, точно за това служи.
4. **По IP — стига.** Скриптът пита Docker за адреса на тестовата услуга (скрит като `<IP>`), а помощникът ѝ прави пряка заявка: `sano`. Мрежата работи; липсват имената. А IP адрес не става за конфигуриране на `revisor`, защото го раздава Docker при стартиране и може да се промени при следващото.

В старите ръководства ще видиш предишното решение за това, `--link`. Раздел 8.12 обяснява защо вече не.

### 8.9 Мрежи, определени от потребителя: имена без усилие

#### 8.9.1 Какво се променя

Мрежа, която създаваш с `docker network create` (също с драйвера `bridge`), се държи различно. Документацията изброява разликите ([Docker, драйвер `bridge`](https://docs.docker.com/engine/network/drivers/bridge/)):

- **Автоматичен DNS**: „мрежите *bridge*, определени от потребителя, дават автоматично DNS разрешаване между контейнерите“. Всеки контейнер се намира по името си.
- **По-добра изолация**: само контейнерите, свързани с тази мрежа, си говорят помежду си. В мрежата по подразбиране, напротив, всеки контейнер, който някой стартира, без да мисли, остава до твоите.
- **Свързване и разкачване в движение**: контейнер може да се свърже с мрежа, определена от потребителя, или да се разкачи от нея „в движение“, без да се пресъздава. Ще го направиш в 8.10.

DNS го дава сървър, който Docker слага **вътре** във всеки контейнер в тези мрежи, на адрес `127.0.0.11`. Документацията го нарича вграден DNS сървър и обяснява, че той отговаря за имената на контейнерите в мрежата и препраща всичко останало към DNS сървърите на компютъра ([Docker, „Networking“](https://docs.docker.com/engine/network/)). Затова контейнер в твоя мрежа разрешава както `curso-docker-prueba`, така и `www.docker.com`.

#### 8.9.2 Разчитане на втората половина от изпълнението

Обратно към изхода на `fig08_07.sh`, блок 2:

1. **Мрежата**: `curso-docker-red-fig08`, драйвер `bridge`, `interna=false` (има изход; в 8.10 ще създадеш такава, която няма).
2. **`OK`, `200`.** Същият `revisor`, със същата конфигурация, намира тестовата услуга по името ѝ. Не смени нито буква в `REVISOR_SERVICIOS`: смени мрежата.
3. **DNS сега е `127.0.0.11`.** Помощникът, свързан със същата мрежа, го показва в своя `/etc/resolv.conf`, а `nslookup` го пита за името на тестовата услуга: сървърът `127.0.0.11` отговаря с адреса ѝ (скрит).
4. **Кой е свързан**: двата контейнера и никой друг. Помощникът не се появява, защото вече е приключил (`--rm`).

И блок 3, който оправдава целия курс: контейнер от същата мрежа прави `POST /modo/caido` към тестовата услуга (`modo: caido`), а следващата проверка на `revisor` казва `FALLA`, `codigo 503`. Тестовата услуга продължава да работи; `revisor`, който я проверява по име през мрежата, различава онова, което Docker мисли (контейнерът е горе), от онова, което става (отговаря с `503`). (Колоната `TIEMPO` на последния ред излиза с един интервал повече, защото скриптът скрива време с различна ширина; това е таблицата, а не грешка.)

Една бележка за името: `revisor` търси `curso-docker-prueba-fig08`, защото така се казва контейнерът на скрипта. В твоята папка контейнерът се казва `curso-docker-prueba`, а `REVISOR_SERVICIOS` казва `prueba http://curso-docker-prueba:9000/ 2s`. Името на контейнера **е** неговото име в мрежата; ако го смениш, сменяш адреса му.

### 8.10 Вътрешни мрежи: без изход

#### 8.10.1 Защо да затвориш тестовата услуга

Тестовата услуга съществува само за да я пита `revisor`. Няма нужда да изтегля нищо, няма нужда да вика никого, няма нужда от интернет. А всичко, до което един контейнер може да стигне, е нещо, до което може да стигне и нападател, който го контролира: да изтегли инструмент, да изпрати данни навън, да го използва като трамплин. Отговорът е **вътрешна мрежа**: `docker network create --internal`. Справочникът на `docker network create` я описва с едно изречение, „ограничава външния достъп до мрежата“, и я обяснява така: контейнерите във вътрешна мрежа „могат да комуникират помежду си, но не и с никоя друга мрежа, защото не се конфигурира маршрут по подразбиране и се слагат правила на защитната стена, които отхвърлят целия трафик към или от други мрежи“ ([справочник на `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/)).

Дизайнът е онзи, който самата документация използва като пример: вътрешна мрежа „за комуникация с контейнери, на които работят вътрешни услуги, които нямат нужда от достъп до външната мрежа“ ([Docker, „Networking“](https://docs.docker.com/engine/network/)). Тестовата услуга — **само** във вътрешната. `revisor` — в нормалната мрежа (през която портът му е изложен към твоя `127.0.0.1`) **и** във вътрешната (през която проверява тестовата услуга). Контейнерът може да е в няколко мрежи едновременно: има по един интерфейс във всяка.

#### 8.10.2 Да го видиш

Скриптът `fig08_08.sh` сглобява това състояние, което е крайното състояние на урока, на две стъпки, за да видиш какво допринася всяка мрежа:

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

1. **Две мрежи**, и двете с драйвер `bridge`; едната с `interna=true`.
2. **`revisor` само в нормалната мрежа не намира тестовата услуга.** Сега съобщението казва `lookup … on 127.0.0.11:53: no such host`. Сравни го с това от 8.8: там попита DNS на компютъра ти (мрежата по подразбиране); тук попита вградения DNS на Docker (мрежа, определена от потребителя), който съществува, но отговаря само за имената в **мрежите на самия контейнер**. Тестовата услуга е в друга мрежа, така че за `revisor` тя не съществува. Това е изолацията от 8.9.1 в действие: да си на един и същ компютър не стига, трябва да споделяш мрежа. Да разчетеш към кой DNS сървър е отправен въпросът, ти казва за какъв вид мрежа става дума.
3. **`docker network connect` без рестартиране.** Свързваш `revisor` и с вътрешната, в движение, а следващата проверка казва `OK`. `docker inspect` показва двете мрежи на `revisor` (по азбучен ред, с интервал в края, който слага шаблонът). А `docker port` потвърждава, че публикуваният порт остава на `127.0.0.1` (номерът на компютъра е скрит, защото скриптът го получава в `PUERTO`).
4. **От вътрешната мрежа няма изход.** Помощник във вътрешната се опитва да изтегли `https://www.docker.com/` и се проваля, преди да опита да се свърже: `wget: bad address 'www.docker.com'`, код `1`. Дори не може да разреши името: заявката излиза от контейнера към вградения DNS на Docker, а вътрешната мрежа няма изход навън, през който тази заявка да стигне до външен сървър на имена. (Документацията не уточнява в коя точно точка се прекъсва заявката, затова урокът твърди само измереното: името не се разрешава и изтеглянето дори не започва.) Но вътрешната мрежа не е изолирана от всичко: същият помощник показва маршрутната си таблица, с един-единствен ред (самата вътрешна мрежа, без маршрут по подразбиране навън), и въпреки това шлюзът ѝ отговаря на `ping` (`1 packets received`). От нормалната мрежа изтеглянето работи. Вътрешната мрежа не е обещание: навън няма маршрут, но шлюзът си остава там.

Едно уточнение, за да не си създадеш погрешна представа: „без изход“ не означава „недостижима от компютъра ти“. Справочникът казва, че компютърът може да комуникира директно с адресите на контейнерите във вътрешна мрежа. Онова, което вътрешната мрежа прекъсва, е пътят на контейнера към **други мрежи**, включително интернет. А в обратната посока има пролука, която е добре да познаваш, онази, която току-що измери: същият справочник уточнява, че „комуникацията с адреса на шлюза (а чрез него и с услугите на компютъра, конфигурирани за това) е възможна“. Програма на компютъра ти, която слуша на `0.0.0.0` (всички интерфейси), например база данни за разработка, остава достъпна за контейнерите във вътрешната мрежа. Това е още една причина за навика от Урок 2: онова, което работи на компютъра ти, слуша на `127.0.0.1`, а не на всички интерфейси. Затова курсът публикува порта на `revisor` през нормалната мрежа, която има път навън, а вътрешната оставя само за разговор с тестовата услуга.

#### 8.10.3 В твоята папка: крайното състояние

С твоя образ `curso-docker-revisor:1.5.0`, твоя том `curso-docker-reportes` и образа `curso-docker-prueba:1.0.0` от Урок 2, ето командите за крайното състояние, с имената на курса:

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

(Ако вече си създал тома в 8.4.4, `docker volume create` само ти връща името му: не го изпразва.) Провери с `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'`, че тестовата услуга излиза `OK`, и с `docker ps --filter name=curso-docker-`, че двата стигат до `(healthy)`. Тестовата услуга има същите опции с подсилена защита като `revisor`, без порт и без `-e`: това е Упражнение 4 от Урок 7 и вече знаеш, че не ѝ трябва дори `tmpfs`, защото не пише нищо. Тези два контейнера, двете мрежи и томът са онова, което Урок 9 записва в `compose.yaml`.

Когато приключиш урока, изтрий ги в този ред (първо контейнерите, защото мрежа или том в употреба не се изтриват): `docker rm -f curso-docker-revisor curso-docker-prueba` и `docker network rm curso-docker-red curso-docker-interna`. Томът, ако искаш да запазиш отчета, остава; ако не — `docker volume rm curso-docker-reportes`.

### 8.11 Какво **не** се прави: мрежата на хоста

Друга от мрежите, които Docker създава при инсталирането, е `host`. Контейнер в нея **няма собствена мрежа**: според документацията мрежовият му стек „не е изолиран от компютъра“ и контейнерът „не получава собствен IP адрес“ ([Docker, драйвер `host`](https://docs.docker.com/engine/network/drivers/host/)). Слуша директно на интерфейсите на компютъра ти, вижда всичките му портове и всичките му локални връзки, а `-p` престава да има ефект: Docker го пренебрегва с предупреждението `WARNING: Published ports are discarded when using host network mode`. Последното анулира с един удар навика от Урок 2: вече не решаваш дали портът остава на `127.0.0.1` или на всички интерфейси; остава там, където програмата реши да слуша.

Понякога се използва, „защото така работи“, когато един контейнер не намира друг, или за да се спечелят няколко микросекунди в мрежата. И двете причини имат по-добър отговор: за да намериш друг контейнер — мрежа, определена от потребителя; за производителността — първо измерване, защото почти никога мрежата на контейнера не е онова, което ограничава. README на курса го поставя като навик на този урок: **никога мрежата на хоста**. Навикът е за приложни услуги като `revisor`; има легитимни употреби в инфраструктурата (например агент, който мери мрежата на самия компютър), които не са тема на този курс, а който има нужда от тях, вече знае, че съзнателно се отказва от изолацията.

### 8.12 Какво ще срещнеш в стари ръководства

- **`--link`.** Старият начин един контейнер да намира друг по име в мрежата по подразбиране. Документацията вече не го препоръчва: връзките в мрежата по подразбиране са „остарели и планирани за премахване в Docker Engine 30.0“, и иска да се използват „мрежи, определени от потребителя, вместо наследения флаг `--link`“ ([Docker, наследени връзки](https://docs.docker.com/engine/network/links/)). Ако го видиш, преведи го в мрежа.
- **„Контейнери само за данни“ и `--volumes-from`.** Преди да съществуват именуваните томове, се създаваше контейнер, който никога не работеше, само за да „притежава“ том, а останалите го монтираха с `--volumes-from`. Днес томът има собствено име и няма нужда от контейнер, който да го държи.
- **`VOLUME /datos` в Dockerfile, „за да се запазват данните“.** Инструкцията съществува и прави нещо: отбелязва път като точка на монтиране и ако при стартиране не монтираш нищо там, Docker създава **анонимен** том, който се инициализира с онова, което образът има на този път ([справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/)). Резултатът е точно обратното на търсеното: по един том без име за всеки контейнер, който никой не разпознава и който се натрупва. А инструкцията не може да избере папка на компютъра. Този курс не я използва: `revisor` носи папката `/datos` със собственика ѝ, а именувания том го решава онзи, който стартира контейнера.
- **`chmod -R 777` върху папката с данни**, за да се „поправят правата“. Вече видя в 8.3 и 8.6, че проблемът е собственикът; `777` го скрива и отваря папката за всеки.

## Грешката, която ще видиш

Този урок има две основни грешки, по една на половина, и три второстепенни. Всички вече се появиха.

**Основната грешка при съхранението: новият том, в който процесът не може да пише.** Тази от `fig08_02.sh`:

```text
{"error":"no pude guardar el reporte: open /datos/.reporte-<n>.tmp: permission denied"}
 [500]
```

Чете се отдясно наляво, като тази от Урок 6. `permission denied` го казва ядрото: процесът няма право да създаде файл там. `open /datos/.reporte-<n>.tmp` казва кой файл, с пътя **вътре** в контейнера: това е временният файл, който `revisor` пише, преди да го преименува, така че проблемът е **папката**, а не `reporte.json`. А `no pude guardar el reporte` го добавя `revisor`, който освен това отговаря с `500`, вместо да се преструва, че всичко е наред. Въпросът, който я решава, е обичайният: „кой е собственикът на папката и с какъв потребител работи процесът?“. Първия отговор ти дава помощник (`docker run --rm -v <том>:/datos:ro alpine:3.24.2 ls -lnd /datos`); втория — `docker inspect --format '{{.Config.User}}' <контейнер>`. Ако папката е на `0`, а процесът е `65532`, това е том, роден без папка от образа, която да се копира: или образът няма `/datos` (1.4.0), или някой е използвал `volume-nocopy`. Поправката е образът да носи папката с `COPY --chown`, а томът да е нов. Това, че томът е съществувал отпреди, не пречи на копирането: докато е **празен**, първото монтиране върху папка от образа я получава, дори да си го създал ти с `docker volume create` (това прави блок 2 на `fig08_03.sh`, и го повторихме ръчно: том, създаден предварително и монтиран преди това с `nocopy`, пак получи папката на `65532`, когато беше монтиран по-късно с добрия образ). Онова, което пречи, е томът **вече да има нещо вътре**, например файл, записан някога от процес на `root`: тогава печели томът, папката остава на `root` и `permission denied` се връща. В такъв случай, ако няма какво да се пази, `docker volume rm` и нека следващият `docker run` го създаде наново.

При *bind mount* същият текст има друг произход: папката е **твоя**, а процесът — `65532`. Поправка: `--user "$(id -u):$(id -g)"` или папката да е на `65532`. Което не е поправка, в нито един от двата случая: `--user 0` или `chmod 777`.

**Основната грешка при мрежите: името, което не съществува.**

```text
prueba    FALLA        <t>  no responde: Get "http://curso-docker-prueba-fig08:9000/": dial tcp: lookup curso-docker-prueba-fig08 on <DNS del anfitrión>:53: no such host
```

`no such host` казва, че името не е могло да бъде разрешено. Онова, което диагностицира случая, е **кого е попитал**, точно преди `:53`:

- **Адресът на DNS на компютъра ти**: контейнерът е в мрежата по подразбиране, която няма DNS за контейнери. Поправка: мрежа, определена от потребителя, за двата.
- **`127.0.0.11`**: контейнерът е в твоя мрежа, с вградения DNS на Docker, но другият контейнер не е в **никоя от мрежите му** (или се казва различно, или не работи). Поправка: `docker network connect` или проверка на името с `docker ps`.

Този детайл превръща общо съобщение в диагноза от един ред.

**Второстепенните:**

```text
docker: Error response from daemon: invalid mount config for type "bind": bind source path does not exist: ./tampoco-existe
```

`--mount type=bind` с път на компютъра, който не съществува (излиза с `125`; пътят в съобщението е този, който си написал). Почти винаги е правописна грешка или относителен път спрямо грешното място. С `-v` не би видял тази грешка: Docker би създал папката, на `root`, и контейнерът би стартирал с празна папка.

```text
Error response from daemon: remove curso-docker-reportes-fig08: volume is in use - [<id>]
```

`docker volume rm` върху том, който някой контейнер, работещ или спрян, все още е монтирал. Първо изтрий контейнера (идентификаторът в квадратните скоби ти казва кой). Същото става с `docker network rm` и мрежа със свързани контейнери.

```text
wget: bad address 'www.docker.com'
```

От контейнер във вътрешна мрежа — всяко външно име. Ако го видиш в контейнер, който **би трябвало** да има изход, провери мрежите му с `docker inspect`: вероятно е само във вътрешна.

## Навикът за сигурност на урока

**Данните се монтират по име, с правилния собственик и само там, където са нужни; мрежите са твои, тази на вътрешните услуги няма изход, а тази на хоста не се използва.** Това са три навика, които се пишат заедно и се проверяват заедно. Първият: файловата система остава само за четене и всяка папка с право на запис има име (том в `/datos`, `tmpfs` с размер); никоя не се поправя с `root`, нито със `777`, защото проблемът е собственикът и се поправя в образа или с `--user`. Вторият: всеки контейнер е само в мрежите, които му трябват; онзи, който няма нужда от интернет, живее в мрежа `--internal`, а ти го проверяваш, като го помолиш да излезе (`bad address`). Третият: никога `--network host`, който заличава с един удар мрежовата изолация и `127.0.0.1` от Урок 2. Произшествието, което предотвратява, е конкретно: компрометирана вътрешна услуга, която не може да изтегли нищо, нито да изпрати нищо навън, и която освен това не може да пише никъде, освен в папка, която ти си избрал.

## Какво се прави погрешно

**Да пазиш данни в слоя на контейнера.** Работи до първия `docker rm`, който при услуга е следващото обновяване. А с `--read-only` дори не работи.

**Да работиш като `root`, за да може томът да се пише.** Заменя проблем със собственика с проблем със сигурността и разваля Уроци 3, 5 и 7. Образът носи папката си с `COPY --chown`.

**`chmod 777` на папка на компютъра.** Отваря я за всички потребители и всички контейнери. Поправката е собственикът: `--user` с твоите числа.

**`-v` с пътища на компютъра.** Правописна грешка създава мълчаливо папка на `root`. За *bind mounts* — `--mount type=bind`, който по подразбиране отказва.

**Да монтираш за четене и запис онова, което контейнерът само чете.** Конфигурация, тайни, сертификати: `readonly`. *Bind mount* с право на запис е врата от контейнера към диска ти.

**Анонимни томове, чрез `VOLUME` в Dockerfile или чрез `-v /datos` без име.** Натрупват се, без никой да знае чии са. Дай им име, с префикса на проекта.

**Да изтриваш томове „за всеки случай“.** `docker volume rm` няма кошче. А `docker volume prune -a` изтрива **всички** томове, които никой контейнер не използва, със или без име, включително данните на спрени проекти, които не са твои (без `-a` `prune` изтрива само анонимните, според [справочника му](https://docs.docker.com/reference/cli/docker/volume/prune/)). Изтривай по точно име.

**Да пишеш IP адреси на контейнери в конфигурацията.** Раздава ги Docker и те се променят. Използвай имена в мрежа, определена от потребителя.

**Да оставиш всичко в мрежата по подразбиране.** Без имена и с всеки контейнер, който някой стартира, без да мисли, в същата мрежа като твоите. Самата документация я нарича наследен детайл.

**Да даваш интернет на онзи, който няма нужда от него.** Вътрешна услуга с изход е трамплин. `--internal`.

**`--network host`, „защото така работи“.** Ако един контейнер не намира друг, отговорът е твоя мрежа, а не премахване на изолацията.

## Упражнения

Прави ги поред. Преди да изпълниш всяко, запиши в [дневника](bitacora.md) какво мислиш, че ще стане; сравнението след това е половината от ученето. Накрая изтрий онова, което си създал: всичко има префикса `curso-docker-`.

### Упражнение 1 — Том, *bind mount*, `tmpfs` или нищо?

За всяка от данните избери едно от четирите и кажи защо с едно изречение:

1. Тестова база данни, която една услуга използва и която трябва да оцелее при обновяване на контейнера.
2. Файл `config.yaml`, който редактираш на компютъра си и който контейнерът само чете.
3. Файловете на сесията на една програма, които се генерират наново при всяко стартиране.
4. Изходният код на програма, докато я разработваш и я тестваш в контейнер.
5. Двоичният файл на `revisor`.
6. Отчетът на `revisor`, който друг инструмент на компютъра ти, извън Docker, ще прибира всеки час.

### Упражнение 2 — Разчети `no such host`

Без да изпълняваш нищо, кажи каква мрежова ситуация е произвела всяко съобщение и с каква команда би я поправил. И двете са на `revisor`, който търси контейнер, който **наистина** работи:

```text
A) … lookup curso-docker-prueba on <DNS del anfitrión>:53: no such host
B) … lookup curso-docker-prueba on 127.0.0.11:53: no such host
```

Допълнителен въпрос: в случай B кои други две причини, които нямат общо с мрежите, биха дали точно същото съобщение?

### Упражнение 3 — Отчетът, който оцелява (проект)

В папката си, с работещото крайно състояние от 8.10.3, направи тази последователност и **преди** всяка стъпка предскажи резултата:

1. Поискай таблицата веднъж: `curl -s 'http://127.0.0.1:8080/api/estados?formato=tabla'`.
2. Изтрий контейнера на `revisor` с `docker rm -f curso-docker-revisor`.
3. Прочети отчета с помощник, без нито един работещ `revisor`.
4. Създай отново `revisor` с командата от 8.10.3, **без** `docker network connect`, и поискай таблицата.
5. С този работещ `revisor` опитай `docker volume rm curso-docker-reportes`.
6. Свържи го с вътрешната и поискай таблицата отново.

### Упражнение 4 — `volume-nocopy`

Предскажи какво става, ако стартираш образа `curso-docker-revisor:1.5.0`, с подсилена защита, с **нов** том, монтиран така:

```text
--mount type=volume,src=curso-docker-sin-copia,dst=/datos,volume-nocopy
```

Какво отговаря `/api/estados`? Чия е `/datos` вътре в тома? Провери го, като публикуваш порта на `127.0.0.1:8081` (или като спреш преди това своя `curso-docker-revisor`, който заема `8080`), и кажи как се свързва с грешката от 8.3. Допълнителен въпрос: как се пише същото с `-v`? Накрая изтрий контейнера и тома.

## Решения

### Решение 1

1. **Именуван том.** Трябва да трае повече от контейнера и никой няма нужда да пипа файловете ръчно. Това е случаят с отчета.
2. ***Bind mount* само за четене.** Редактираш го ти на компютъра си, а контейнерът само го чете; с `readonly` контейнерът не може да го промени, дори да иска.
3. **`tmpfs` с размер.** Не бива да оцелее след контейнера и така не заема диск, нито оставя следа.
4. ***Bind mount***. Ти го редактираш, а контейнерът трябва да види промяната веднага. Това е употребата, която документацията дава като пример. (В контейнер, който само го изпълнява — само за четене.)
5. **Нищо: отива в образа.** Това е код (Урок 6). Монтирането му отвън би довело дотам, че тестваният образ не е онзи, който работи.
6. ***Bind mount*** **на твоя папка**, с `--user` с твоите числа, както в 8.6. Инструмент на компютъра ти извън Docker трябва да го чете в твой път, без `sudo`. С том би трябвало да минава през помощен контейнер.

### Решение 2

- **A)** Попитан е DNS на компютъра ти: `revisor` е в **мрежата по подразбиране**, която няма DNS за контейнери. Поправка: да се създаде мрежа (`docker network create curso-docker-red`) и двата контейнера да се стартират с `--network curso-docker-red` или да се свържат с нея с `docker network connect`.
- **B)** Попитан е вграденият DNS (`127.0.0.11`): `revisor` **е** в мрежа, определена от потребителя, но тестовата услуга не е в никоя от мрежите му. Това видя в блок 2 на `fig08_08.sh`. Поправка: `docker network connect <мрежата на другия> curso-docker-revisor` (или да се свърже другият с мрежата на `revisor`).

Допълнителен въпрос: същото съобщение излиза, ако името е **написано грешно** в `REVISOR_SERVICIOS` (DNS не гадае), или ако другият контейнер **не работи**: вграденият DNS отговаря само за имената на контейнерите, свързани в този момент. `docker ps --filter name=curso-docker-` отговаря и на двете съмнения.

### Решение 3

Стъпки 2, 5 и първата таблица от 4 са измерени със същия компютър и същата версия на Docker като урока, в скриптовете `fig08_03.sh` и `fig08_08.sh` (с наставката `-fig08` в имената); останалите се извеждат от тях, а в твоята папка трябва да излязат така:

1. `200`, а таблицата казва `prueba OK`.
2. Контейнерът изчезва; томът — не (блок 4 на `fig08_03.sh`).
3. Помощникът (`docker run --rm -v curso-docker-reportes:/datos:ro alpine:3.24.2 cat /datos/reporte.json`) трябва да отпечата последния отчет, в JSON. В блок 4 на `fig08_03.sh` услугата се казваше `propio`; в крайното ти състояние трябва да се казва `prueba`, с `"ok": true` и `"codigo": 200`.
4. Таблицата казва `FALLA` с `lookup curso-docker-prueba on 127.0.0.11:53: no such host`, както в блок 2 на `fig08_08.sh`: `revisor` е в твоя мрежа, а тестовата услуга — в друга.
5. `docker volume rm` отказва: `volume is in use`, с идентификатора на контейнера в квадратни скоби, и излиза с код `1` (блок 3 на `fig08_03.sh`).
6. След `docker network connect` — `OK` (блок 3 на `fig08_08.sh`).

### Решение 4

Това е скриптът `fig08_09.sh`, който изпробва опцията с `--mount` и с `-v`:

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

Това е грешката от 8.3 с добрия образ. Образът 1.5.0 носи `/datos` на `65532`, но `volume-nocopy` казва на Docker да не копира нищо в новия том, а онова, което не се копира, включва и собственика: томът се ражда с папка на `root`, както когато образът нямаше папката (блок 3 на `fig08_04.sh`). Урокът: поправката от 8.4 зависи от копирането при първото монтиране. Всичко, което му пречи (`volume-nocopy` при първото монтиране или том, който вече има съдържание и затова печели пред образа), връща `permission denied`. Том, който е съществувал отпреди, но е празен, не пречи: измерено е, че получава папката по същия начин.

Допълнителен въпрос: с `-v` опцията се пише `nocopy` (блок 3). Името от `--mount` не става с `-v`: Docker 29.2.1 го отхвърля с `invalid mode: volume-nocopy` и код `125`, макар страницата за томовете да го документира с това име (блок 2). Това е добър пример защо курсът изпълнява всяка команда, вместо да я копира от документацията.

## Как разбирам, че съм успял

Отбележи всяка точка само ако можеш да я направиш, **без да поглеждаш отново текста**:

- [ ] В папката ти `docker image inspect --format '{{range .Config.Env}}{{println .}}{{end}}' curso-docker-revisor:1.5.0` показва `REVISOR_REPORTE=/datos/reporte.json`, а `docker create` + `docker export` + `tar -tv --numeric-owner` показват `datos/` със собственик `65532/65532`.
- [ ] Предизвикваш `permission denied` с образа 1.4.0 и нов том и го обясняваш, като използваш думите *собственик*, `0` и `65532`.
- [ ] Отчетът оцелява след `docker rm -f curso-docker-revisor`: четеш го с помощник само за четене.
- [ ] Обясняваш с пример кога съдържанието на папка се **копира** при монтиране и кога се **закрива**, и защо `--mount` е по-сигурен от `-v` за *bind mount*.
- [ ] Стартираш `revisor` с *bind mount* на твоя папка и `--user "$(id -u):$(id -g)"`, а `stat` показва, че отчетът е твой.
- [ ] Контейнер с `--read-only` пише в том и в `tmpfs` със `size`, а след `docker restart` файлът в тома остава, а този в `tmpfs` — не.
- [ ] Показваш `no such host` в мрежата по подразбиране и `OK` в твоя мрежа и казваш кой DNS сървър използва всяка (`/etc/resolv.conf` на помощник).
- [ ] Крайното състояние от 8.10.3 работи: тестовата услуга само в `curso-docker-interna`, `revisor` в двете, таблицата в `OK`, а помощник във вътрешната мрежа получава `bad address`, когато опита да излезе.
- [ ] Пускаш скриптовете от [`programas/08-volumenes-y-redes/`](../programas/08-volumenes-y-redes) и изходите ти съвпадат с тези от урока, с изключение на времената, датите, номерата на потребителя и групата на компютъра ти и онова, което скриптовете видимо скриват. (Скриптовете публикуват на `8081`, така че не се сблъскват с твоя `revisor` на `8080`.) А накрая `docker ps -a --filter name=fig08`, `docker volume ls --filter name=fig08` и `docker network ls --filter name=fig08` не показват нищо.

## Обобщение

Отговори, без да гледаш урока:

1. Какво е слоят за запис на контейнер и какви три проблема има за съхраняването на отчета на `revisor`?
2. Каква е разликата между именуван том, *bind mount* и `tmpfs` по отношение на това къде живеят данните и колко траят?
3. Защо нов том, монтиран в папка, която образът няма, дава `permission denied` с потребител без привилегии?
4. Какво прави `COPY --chown=65532:65532` и защо поправката зависи от това томът да е нов и празен?
5. Кога се копира и кога се закрива съдържанието на папка, когато монтираш нещо отгоре?
6. Какво прави `-v` и какво прави `--mount`, когато папката на компютъра не съществува?
7. Как поправяш `permission denied` на *bind mount* без `root` и без `777`?
8. Защо в мрежата по подразбиране един контейнер не намира друг по име и какво се променя в мрежа, определена от потребителя?
9. Какво е `127.0.0.11` и какво ти казва този адрес в `no such host`?
10. Какво прекъсва мрежата `--internal`, какво не прекъсва и защо портът на `revisor` е изложен през другата мрежа?

## Източници

Всички проверени на 21 октомври 2026 г.

- [Docker, „Storage“](https://docs.docker.com/engine/storage/): че записаното в слоя на контейнера не се запазва и трудно се изважда; видовете монтиране (включително монтиранията на образи) и кога да се използва всеки.
- [Docker, „Volumes“](https://docs.docker.com/engine/storage/volumes/): копирането на съдържанието на образа в празен том и опцията `volume-nocopy`; че том с данни закрива онова, което е имало; че се предпочита `--mount`; пътят `/var/lib/docker/volumes/<име>/_data`; че томовете оцеляват след контейнера, а анонимните се изтриват с `--rm`.
- [Docker, „Bind mounts“](https://docs.docker.com/engine/storage/bind-mounts/): че закриват съществуващото съдържание; че `-v` създава папката, а `--mount` по подразбиране — не, с текста `bind source path does not exist`, и опцията `bind-create-src`; че по подразбиране дават право на запис в компютъра; опцията `readonly`.
- [Справочник на `docker volume prune`](https://docs.docker.com/reference/cli/docker/volume/prune/): че по подразбиране изтрива само анонимните томове и че `-a` изтрива всички, които не се използват.
- [Docker, „tmpfs mounts“](https://docs.docker.com/engine/storage/tmpfs/): че `tmpfs` живее в паметта и изчезва, когато контейнерът спре; че не се споделя; максималният му размер (50 % от паметта) и правата му (`1777`) по подразбиране; че се предпочита `--mount`; предупреждението за паметта за размяна.
- [Docker, „Networking“](https://docs.docker.com/engine/network/): вграденият DNS сървър на `127.0.0.11` и препращането на външните заявки; че контейнерите в мрежата по подразбиране получават копие на `/etc/resolv.conf` от компютъра; вътрешните мрежи за услуги без външен достъп.
- [Docker, драйвер `bridge`](https://docs.docker.com/engine/network/drivers/bridge/): разликите между мрежата по подразбиране и тези, определени от потребителя (автоматичен DNS, изолация, свързване в движение), и че мрежата по подразбиране е наследен детайл, който не се препоръчва за продукция.
- [Справочник на `docker network create`](https://docs.docker.com/reference/cli/docker/network/create/): опцията `--internal` и вътрешният режим (без маршрут по подразбиране, отхвърлен трафик към други мрежи, достъпен шлюз и компютър, който стига до контейнерите).
- [Docker, драйвер `host`](https://docs.docker.com/engine/network/drivers/host/): че контейнерът няма собствена мрежа, нито IP адрес и че публикуваните портове се отхвърлят с предупреждение.
- [Docker, наследени връзки](https://docs.docker.com/engine/network/links/): че `--link` в мрежата по подразбиране е остарял и планиран за премахване в Engine 30.0.
- [Справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/): `COPY --chown` и собственикът `0` по подразбиране; инструкцията `VOLUME` и нейният том, инициализиран със съдържанието на образа.
- [Справочник на `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `-v`, `--mount`, `--tmpfs`, `--network` и `--user`.
- [Docker Engine 29, бележки към версиите](https://docs.docker.com/engine/release-notes/29/): версиите и датите от „За изпълненията“.
- [Colima](https://github.com/abiosoft/colima): инструментът, с който програмите са изпълнени на macOS.

### Термини от този урок

| | |
|---|---|
| ***bind mount*** | монтиране на папка или файл от компютъра вътре в контейнера; контейнерът вижда точно това, със собственика и правата му |
| **слой за запис** | собственият слой на всеки контейнер, над тези на образа; изтрива се с контейнера |
| **помощен контейнер** | контейнер за еднократна употреба (`--rm`), който се използва за разглеждане на том или мрежа; тук — `alpine:3.24.2` |
| **вграден DNS** | сървър на имена, който Docker слага на `127.0.0.11` вътре в контейнерите в мрежите, определени от потребителя |
| **мрежа, определена от потребителя** | мрежа, създадена с `docker network create`; дава имена чрез DNS и изолира от останалите контейнери |
| **вътрешна мрежа** | мрежа, създадена с `--internal`; контейнерите ѝ си говорят помежду си, но не излизат към други мрежи, нито към интернет |
| **мрежа по подразбиране** (`bridge`) | мрежата, с която Docker свързва контейнер, ако не кажеш друго; без имена, само IP адреси |
| **`tmpfs`** | монтиране, което живее в паметта, с размер, и изчезва, когато контейнерът спре |
| **именуван том** | хранилище, управлявано от Docker, което оцелява след контейнерите; създава се, изброява се и се изтрива с `docker volume` |
| **анонимен том** | том без име, създаден от `VOLUME` или от `-v /път`; труден за разпознаване и лесен за забравяне |

---

**Следващ:** [Урок 9 — Compose: цялата система](09-compose.md)
