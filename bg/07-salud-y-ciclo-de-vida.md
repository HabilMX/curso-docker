# Урок 7 — Проверка на състоянието и жизнен цикъл

11:15 вечерта в петък е, а прозорецът за поддръжка се затваря в 11:30. Планът е прост: да се обнови сървърът, на който работят `revisor` и още деветнайсет контейнера, да се рестартира и да се прибереш у дома. Някой ги спира един по един с цикъл `for … docker stop`, а терминалът остава да мисли. Десет секунди. Още десет. Още десет. Три минути по-късно приключва, а почти всички са останали отбелязани с `Exited (137)`, което означава „убит“. Сървърът стартира отново в 11:24 и всичко казва `Up`. В 11:26 таблото за наблюдение е все още червено: една от услугите е „горе“, но отговаря с `503` на всичко, а контейнерът, който зависеше от нея, се рестартира отново и отново, всеки път малко по-късно. Никой не знае дали контейнерите, умрели със 137, са успели да запишат онова, което са писали. Остават четири минути, а въпросът е обичайният: какво работи, какво е здраво и какво се преструва? Този урок съществува, за да можеш да отговориш за секунди: контейнер, който казва как е, който умира подредено, когато го поискаш, и който, докато е жив, не може да прави повече от необходимото.

**Време:** 2 × 45 мин

**Какво изграждаш:** контейнер, който казва как е и умира правилно. Образът `curso-docker-revisor:1.4.0` съдържа собствена проверка на състоянието (`HEALTHCHECK`), направена със същия двоичен файл и без `curl`, и декларира сигнала си за спиране (`STOPSIGNAL`). А контейнерът работи с подсилена защита (hardening): файлова система само за четене, без нито една от capabilities на `root`, без възможност да придобие нови привилегии, с миниатюрен *init* като процес номер 1, с ограничения и с политика за рестартиране. Това са опциите, които Урок 9 пренася в Compose.

**Какво научаваш:** какво е сигнал, защо процесът номер 1 в контейнер е специален и как да разчиташ кодовете `0`, `1`, `137` и `143`; срока на `docker stop` и как се променя; какво прави `--init` и какво е зомби процес; `HEALTHCHECK` без `curl` и разликата между „работи“ и „здрав“; четирите политики за рестартиране и онова, което те **не** правят; `--read-only` с `tmpfs` там, където е нужно; `--cap-drop ALL`; и `no-new-privileges`, с програма със *setuid*, която го демонстрира.

**Откъде идваш.** От [Урок 6](06-configuracion-y-secretos.md) носиш образа `curso-docker-revisor:1.3.0`: в няколко етапа, 16.1 MB, без *shell*, с потребителя `65532`, със записана версия и без нищо от която и да е среда. От [Урок 3](03-primer-dockerfile.md) носиш едно измерване, което не се забравя: с `CMD` във формата *shell* `docker stop` отне повече от десет секунди и контейнерът умря със `137`, защото сигналът така и не стигна до `revisor`. От [Урок 2](02-contenedores-dia-a-dia.md) носиш `(health: starting)`, което видя в тестовата услуга, без още да знаеш откъде идва, и навика да слагаш ограничения за памет, CPU и процеси. А от [Урок 0](00-que-es-un-contenedor.md) носиш централната идея: контейнерът е процес на твоя компютър, със същото ядро, а `root` вътре има четиринайсет capabilities, които днес ще му отнемеш.

**Какво не прави този урок.** Не обяснява в дълбочина монтиранията: `tmpfs` от раздел 7.7 се използва тук за една-единствена папка, а [Урок 8](08-volumenes-y-redes.md) обяснява изцяло томовете, *bind mounts* и `tmpfs`. Не използва проверката на състоянието, за да подрежда стартирането на няколко услуги (`depends_on` със `service_healthy`): това е [Урок 9](09-compose.md). Не пипа профили на *seccomp*, нито на AppArmor, нито Docker без `root`: това са слоеве, които Docker вече слага по подразбиране или които изискват друга инсталация, а този курс остава при опциите, които всеки може да напише в `docker run`. И не рестартира демона на Docker, за да изпробва `unless-stopped` срещу `always`: това би спряло всички контейнери на компютъра, а разликата се обяснява с документацията.

**За изпълненията.** Всички изходи са реални и са получени на 21 октомври 2026 г. на Mac с [Colima](https://github.com/abiosoft/colima), която стартира виртуална машина с Ubuntu 24.04.4, същата основа като Linux Mint 22, референтната система на курса, с ядро 6.8 и процесор `arm64`. Скриптовете бяха пуснати **вътре** в тази виртуална машина, с Docker 29.2.1 (клиент и демон), и с работната им папка на собствения диск на Linux. За да не се сблъскват с други изпълнения, които използваха същата машина, скриптовете бяха пуснати с друг префикс на имената и с други портове (променливите `PREFIJO` и `PUERTO`, които имат); нито едно име на контейнер или образ, нито портът на компютъра, не се появява в изходите им, така че това, което виждаш, е точно онова, което са отпечатали. Със стойностите си по подразбиране скриптовете използват собствени помощни имена, които съдържат `fig07` (образът `curso-docker-revisor:fig07`, контейнерът `curso-docker-revisor-fig07`): така никога не пипат твоя образ `curso-docker-revisor:1.4.0`, нито твоя контейнер `curso-docker-revisor`, а при излизане изтриват само онова, което са създали. Курсът беше планиран с Docker Engine 29.8.2, а най-новата публикувана в този ден беше 29.9.2, от 20 октомври 2026 г. ([бележки към версиите](https://docs.docker.com/engine/release-notes/29/)); нищо в този урок не се променя между тези версии. Което **се** променя от едно изпълнение до друго, и се казва там, където се появява: номерата на процесите (скрити със `<pid>` в самия скрипт; скриптовете, които ги използват, спират, ако контейнерът не работи, защото номер `0` би сочил към процеси на компютъра ти), милисекундите на всеки `docker stop` и на всяко рестартиране, секундите на `Up` и номерът на временния файл на отчета (скрит с `<n>`). Виртуалната машина беше споделена с други задачи и при някои изпълнения беше натоварена: затова някои времена излязоха по-дълги от други, а там, където това има значение, е казано. Скриптовете публикуват на портове 8080 (`fig07_03.sh` и `fig07_06.sh`) и 9000 (`fig07_04.sh`) на компютъра ти: ако твоите `curso-docker-revisor` или `curso-docker-prueba` работят, изтрий ги преди това или пусни скрипта с друг порт, например `PUERTO=18080 ./fig07_03.sh`; иначе скриптът спира с `port is already allocated`. Един скрипт, `fig07_05.sh`, използва `sudo` веднъж, за да убие процес отвън, както би го направило ядрото; в твоя Mint ще поиска паролата ти. Програмите са в [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida), всяка с изхода си до нея, а `estado/` пази файловете на проекта такива, каквито остават накрая.

## След урока ще можеш да

- Разчетеш кода на изход на контейнер (`0`, `1`, `137`, `143`) и да кажеш кой сигнал го е прекратил или дали е приключил сам.
- Обясниш защо програма, която умира от `SIGTERM` в терминала ти, пренебрегва същия сигнал, когато е процес номер 1 в контейнер, и да го поправиш с `--init`.
- Измериш колко трае `docker stop` и да промениш срока и сигнала му с `-t`, `--stop-timeout`, `STOPSIGNAL` и `--stop-signal`.
- Напишеш `HEALTHCHECK` във формата *exec* за образ без *shell* и без `curl` и да разчетеш състоянието на контейнер с `docker ps` и `docker inspect`.
- Избереш политика за рестартиране за дадена услуга и да предскажеш какво прави Docker, когато процесът умре сам, когато го спреш ти и когато е `unhealthy`.
- Стартираш `revisor` с `--read-only`, `--cap-drop ALL` и `--security-opt no-new-privileges` и да провериш в `/proc`, че ядрото прилага и трите.

## Защо, преди как

Досега се отнасяше към контейнера като към нещо, което стартира. Този урок се занимава с всичко останало: с това как **умира**, как казва **дали е добре**, докато е жив, и **какво може да прави** междувременно. Това са три различни въпроса и и трите се появиха в сцената от началото.

Първият е за спирането. Контейнерът не се изключва като машина: Docker изпраща **сигнал** на главния му процес и чака. Ако процесът обработи сигнала, довършва онова, което е правел, и излиза; ако не, при изтичане на срока Docker го убива. Вече го видя в Урок 3 с формата *shell*. Новото е, че не е достатъчно да напишеш правилно `CMD`: има програми, които, бидейки процес номер 1, не получават сигнала, макар да са във формата *exec*, а урокът ти показва една такава, измерва колко струва и я поправя.

Вторият е състоянието. За Docker един контейнер е `Up`, докато процесът му съществува. Не знае дали този процес отговаря, дали отговаря правилно, или е заседнал в очакване на нещо, което никога няма да дойде. README на курса го поставя като един от двата си принципа: **„работещ“ контейнер не е здрава услуга**. Проверката на състоянието (health check) е начинът контейнерът, отвътре, да каже на Docker разликата. А образът на `revisor` няма `curl`, нито *shell*, така че проверката трябва да дойде отнякъде другаде.

Третият е властта. Контейнер, който работи добре, пак може да бъде входна точка за атака: ако някой открие пробив в програмата, наследява всичко, което процесът може да прави. Уроци 3 и 5 вече му отнеха `root` и *shell*. Тук се отнемат още три неща: възможността да пише в собствената си файлова система, capabilities на `root`, които не използва, и възможността да придобие нови привилегии, когато изпълни друга програма.

С тази цел пред очи, ето какво ще видиш в раздел 7.10, когато трите отговора се съберат. `revisor` работи с всичко от урока, ядрото потвърждава, че няма нито една capability и че не може да придобие привилегии, и въпреки това спира подредено за няколко десети от секундата:

```text
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
```

## Понятията

### 7.1 Процесът номер 1 и сигналите

#### 7.1.1 Какво е сигнал

**Сигналът** е кратко известие, което ядрото на Linux предава на процес. Не носи данни: само число, което казва какво се е случило или какво се иска. Когато натиснеш `Ctrl+C` в терминала, ядрото изпраща на програмата сигнала `SIGINT`; когато администратор напише `kill <pid>`, изпраща `SIGTERM`. Наръчникът на Linux ги изброява с номера им и с **действието им по подразбиране**, което е онова, което става, ако програмата не е направила нищо специално, за да ги обработи ([signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html)):

| Сигнал | Номер | Какво иска | Действие по подразбиране |
|---|---|---|---|
| `SIGINT` | 2 | прекъсване от клавиатурата (`Ctrl+C`) | прекратяване |
| `SIGKILL` | 9 | умри, веднага | прекратяване; **не може да бъде уловен, блокиран, нито пренебрегнат** |
| `SIGTERM` | 15 | приключи, моля | прекратяване |

Програмата може да **инсталира обработчик** (handler) за даден сигнал: функция, която се изпълнява, когато сигналът пристигне, вместо действието по подразбиране. Това прави `revisor`: иска от ядрото да го уведомява за `SIGTERM` и за `SIGINT` и когато пристигне един от тях, спира да приема нови заявки, чака до пет секунди текущите да приключат и излиза с код 0. Това виждаш от Урок 3 насам в логовете му: `recibí terminated, apagando` и `apagado limpio`. За `SIGKILL` не е възможен обработчик; наръчникът го казва черно на бяло: „`SIGKILL` и `SIGSTOP` не могат да бъдат уловени, блокирани, нито пренебрегнати“.

#### 7.1.2 Как се разчита краят на един контейнер

Когато процес приключи, оставя **код на изход**. Ако е приключил сам, това е числото, което програмата е избрала: `0` за „всичко е наред“, всяко друго — за „нещо се провали“ (`revisor` използва `1`, когато му липсва конфигурация). Ако го е прекратил сигнал, конвенцията на *shell*-овете, която Docker следва, е **128 плюс номера на сигнала**. Оттам идват двете числа, които ще виждаш най-често:

| Код | Как се разчита |
|---|---|
| `0` | приключил е сам и успешно; при `revisor` — след подредено спиране |
| `1` | приключил е сам, с грешка на самата програма |
| `137` | 128 + 9: убил го е `SIGKILL`; никой не го е питал |
| `143` | 128 + 15: прекратил го е `SIGTERM` с действието по подразбиране, без обработчик |

Обърни внимание на разликата между `0` и `143`. И двете са спирания, поискани със `SIGTERM`; при първото програмата е обработила сигнала и е излязла сама; при второто ядрото я е прекратило, защото програмата не е имала обработчик. И двете са разумни. Онова, което трябва да те тревожи, е `137` при нормално спиране: означава, че срокът е изтекъл и Docker е трябвало да убие.

#### 7.1.3 Защо номер 1 е специален

В Урок 0 видя, че вътре в контейнер главната програма е процесът номер 1. Този номер има специално отношение в Linux, което наръчникът за пространствата от имена на процеси описва така: на процеса „*init*“ на едно пространство от имена могат да се изпращат само сигналите, **за които е установил обработчик**; останалите не му правят нищо. И има изключение: `SIGKILL` и `SIGSTOP` „се доставят принудително, когато идват от пространство от имена предшественик“ ([pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html)). Справочникът на `docker run` го обобщава в едно изречение: процес, който работи като PID 1, „пренебрегва всеки сигнал, чието действие е това по подразбиране“ ([справочник на `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)).

Прочети го спокойно, защото това е сърцевината на този раздел. Програма, която **не** е инсталирала обработчик за `SIGTERM`, умира от него в терминала ти, защото действието по подразбиране е прекратяване. Същата програма, когато е номер 1 в контейнер, **не** умира: действието по подразбиране вече не се прилага. Защитата има смисъл за *init* на една машина, който никога не бива да умре случайно; в контейнер *init* е твоята програма и тази защита се превръща в проблем.

#### 7.1.4 Измерване с програма, която не знае как да спре

`revisor` инсталира обработчика си, така че не става, за да се види проблемът. За това е нужна програма, която не го инсталира, а такава има във всички образи на Debian: `sleep`, която само чака колкото секунди ѝ поискаш. Скриптът `fig07_02.sh` не изгражда нищо; използва образа на Go, който имаш от Урок 3:

```bash
#!/usr/bin/env bash
# fig07_02.sh — El proceso número 1 y las señales, con un programa que NO sabe
# apagarse: sleep. Mide cuánto tarda docker stop, con qué código muere el
# contenedor, qué cambia con -t y con --init, y quién recoge a los zombis.
# No construye nada: usa la imagen de Go que ya bajaste para el revisor.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor
# ni tu imagen curso-docker-revisor:1.4.0, y al salir borra solo lo que creó.
NOMBRE="${PREFIJO}fig07-sleep"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
# t: milisegundos desde la época, para medir duraciones
t() { date +%s%3N; }
# detener [opciones de docker stop]: detiene el contenedor, mide y dice cómo murió
detener() {
  local inicio fin
  inicio=$(t); docker stop "$@" "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop${*:+ $*} tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
  docker rm -f "$NOMBRE" >/dev/null
}

echo "== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
PID1=$(pid_de "$NOMBRE")
grep -E '^SigCgt' "/proc/$PID1/status"
detener

echo
echo "== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)"
docker run -d --name "$NOMBRE" "$GO" sleep 300 >/dev/null
detener -t 2

echo
echo "== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM"
sleep 300 & HIJO=$!
kill -TERM "$HIJO"; rc=0; wait "$HIJO" || rc=$?
echo "sleep en el equipo murió con código $rc"

echo
echo "== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep"
docker run -d --init --name "$NOMBRE" "$GO" sleep 300 >/dev/null
docker top "$NOMBRE" -o pid,ppid,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
detener

echo
echo "== 5. Zombis: un hijo huérfano termina y nadie lo recoge"
# El subshell lanza «sleep 1» y se va; ese sleep queda huérfano y el núcleo se
# lo entrega al proceso 1. Después, exec convierte al shell en «sleep 300».
docker run -d --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- docker top:"
docker top "$NOMBRE" -o pid,stat,args | sed -E 's/^ *[0-9]+ /<pid> /'
echo "-- ps en el equipo, hijos del proceso 1 del contenedor:"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 6. Lo mismo con --init: el init recoge al huérfano"
docker run -d --init --name "$NOMBRE" "$GO" sh -c '(sleep 1 &); exec sleep 300' >/dev/null
sleep 3
echo "-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):"
PID1=$(pid_de "$NOMBRE")
ps -o stat,args --ppid "$PID1"
```

```text
$ ./fig07_02.sh
== 1. sleep es el proceso 1 y no instaló manejador para SIGTERM
PID                 PPID                COMMAND
<pid> <ppid>             sleep 300
SigCgt:	0000000000000000
docker stop tardó 11315 ms; ExitCode=137

== 2. El mismo sleep, con un plazo de 2 segundos (-t 2)
docker stop -t 2 tardó 2707 ms; ExitCode=137

== 3. Fuera del contenedor, el mismo sleep sí muere con SIGTERM
sleep en el equipo murió con código 143

== 4. Con --init: un init diminuto es el proceso 1 y le pasa la señal a sleep
PID                 PPID                COMMAND
<pid> <ppid>             /sbin/docker-init -- sleep 300
<pid> <ppid>             sleep 300
docker stop tardó 251 ms; ExitCode=143

== 5. Zombis: un hijo huérfano termina y nadie lo recoge
-- docker top:
PID                 STAT                COMMAND
<pid>             Ss                  sleep 300
-- ps en el equipo, hijos del proceso 1 del contenedor:
STAT COMMAND
Z    [sleep] <defunct>

== 6. Lo mismo con --init: el init recoge al huérfano
-- ps en el equipo, hijos del proceso 1 del contenedor (ahora, docker-init):
STAT COMMAND
S    sleep 300
```

В скрипта има нови редове. Функцията `detener` мери колко трае `docker stop` и чете кода на изход с `docker inspect`, както направи в Урок 3. `sed` след `docker top` скрива номерата на процесите със `<pid>` и `<ppid>`, защото се променят при всяко изпълнение. А `grep` в блок 1 чете файл, който не е на контейнера, а на ядрото: `/proc/<номер>/status`, състоянието на процес, видяно от компютъра ти. `docker inspect --format '{{.State.Pid}}'` дава номера, който този процес има **на компютъра ти**, който не е 1; 1 е номерът, който има вътре.

Сега блокове 1 до 3; останалите се разчитат в 7.3.

1. **`sleep` е номер 1 и не обработва нищо.** `docker top` показва един-единствен процес, `sleep 300`. Редът `SigCgt` казва кои сигнали процесът е **уловил**, тоест за кои е инсталирал обработчик, като битова маска в шестнайсетичен вид: всеки включен бит е един сигнал. Всичко е нула: нито един. А `docker stop` отне **11 315 ms** и остави `ExitCode=137` (при изпълнение с по-малко натоварена машина — 10 097 ms: срокът е 10 000, а останалото е Docker и натоварването на компютъра). Последователността е тази от Урок 3: `SIGTERM` към номер 1, който го пренебрегва, защото няма обработчик; десет секунди чакане; `SIGKILL`, който пристига принудително.
2. **Срокът може да се промени.** С `docker stop -t 2` същият `sleep` умря за **2 707 ms**, също със `137` (2 124 при по-малко натовареното изпълнение). Срокът се промени; краят — не. Скъсяването на срока не поправя нищо: само кара да убият по-рано.
3. **Извън контейнера същата програма умира.** Скриптът пуска `sleep 300` на собствения ти компютър, изпраща му `SIGTERM` с `kill` и чете кода му: `143`, което е 128 + 15. Същата програма, същият сигнал, никакъв обработчик: на компютъра ти `sleep` е обикновен процес и действието по подразбиране се прилага; в контейнера беше номер 1 и не се прилагаше.

Сравни този блок 1 с формата *shell* от Урок 3. Там номер 1 беше `/bin/sh`, а `revisor` беше под него; тук няма *shell* по средата, `CMD` е *exec* и въпреки това става същото. Формата *exec* кара Docker да стартира програмата ти директно, без *shell* по средата, и затова тя остава номер 1; тя **не** гарантира, че програмата ти знае как да се държи като такъв.

> [!NOTE]
> 🔧 **Инженерно наблюдение 7.1**
> Много програми не инсталират обработчици, защото на обикновена машина не им трябват: действието по подразбиране на `SIGTERM` вече ги прекратява. *Shell* скриптове, инструменти за командния ред, сървъри, писани набързо. Когато ги сложиш в контейнер като номер 1, всеки `docker stop` им струва целия срок. Преди да решиш каквото и да е, погледни реда `SigCgt` на процеса си: ако битът на `SIGTERM` (стойността `4000` в шестнайсетичен вид) е изключен, тази програма има нужда от помощ.

### 7.2 Срокът на `docker stop` и кой решава сигнала

#### 7.2.1 Какво прави `docker stop`, стъпка по стъпка

Документацията го описва така: главният процес на контейнера „получава `SIGTERM` и след гратисен период — `SIGKILL`“. Ако за контейнера не е конфигуриран друг сигнал, се използва `SIGTERM`. Срокът „се определя от демона“ и е **10 секунди** за контейнери на Linux (30 за тези на Windows); с `-t` или `--timeout` го променяш за това извикване, а с `-t -1` Docker чака вечно ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

Има три места, където поведението може да се промени, и е добре да знаеш кое печели:

| Къде | Какво променя | Обхват |
|---|---|---|
| `STOPSIGNAL` в Dockerfile | сигнала, който изпраща `docker stop` | всички контейнери на този образ |
| `docker run --stop-signal` | сигнала, за този контейнер | печели пред този на образа |
| `docker run --stop-timeout` | срока, за този контейнер | остава запазен в контейнера |
| `docker stop -t N` / `-s СИГНАЛ` | срок и сигнал, за това извикване | печели пред всичко предишно |

Справочникът на Dockerfile уточнява, че `STOPSIGNAL` важи само за сигналите, които изпраща Docker (`docker stop` и самият демон); `Ctrl+C` в терминал, свързан с контейнера, продължава да изпраща `SIGINT` директно на процеса ([справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/)). Ако не подадеш `--stop-signal` при стартиране, нито `-s` при спиране, Docker използва `STOPSIGNAL` на образа, а ако образът не декларира такъв — `SIGTERM` ([`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/)).

И има `docker kill`, който не чака: изпраща сигнал и толкова. Без `-s` сигналът е `SIGKILL` ([`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/)). Използва се, когато нещо е увиснало и няма какво да се спасява; не е нормалният начин за спиране.

#### 7.2.2 `STOPSIGNAL` в `revisor`

Dockerfile от този урок декларира `STOPSIGNAL SIGTERM`. Това е сигналът по подразбиране, така че не променя поведението; коментарът в Dockerfile го казва: изписването му документира намерението. Който чете образа или го инспектира с `docker image inspect --format '{{.Config.StopSignal}}'`, знае какъв сигнал очаква програмата, без да отваря кода ѝ. Има програми, които очакват друг (някои уеб сървъри правят подредено спиране със `SIGQUIT` и рязко — със `SIGTERM`); тогава `STOPSIGNAL` престава да бъде документация и става необходимост.

#### 7.2.3 Защо `revisor` чака пет секунди, а не десет

Кодът на `revisor` има константа, `PlazoApagado`, от пет секунди: толкова чака текущите заявки, преди да се откаже. Коментарът ѝ обяснява числото: то е по-малко от десетте на `docker stop`, „за да приключи процесът сам и да не го убият“. Това е правилото, което е добре да следваш с всяка услуга: **вътрешният ти срок за спиране трябва да се побира в срока на онзи, който те спира**. Ако програмата ти има нужда от двайсет секунди, за да изпразни опашка, увеличи срока на контейнера с `--stop-timeout 30`; не очаквай Docker да се досети.

### 7.3 `--init`: миниатюрен *init* за номер 1

#### 7.3.1 Какво прави

Ако програмата не знае как да бъде номер 1, чистият изход е да не я правиш номер 1. `docker run --init` стартира първо малка програма, `docker-init`, която става номер 1 и стартира твоята програма като свое дете. Справочникът на `docker run` казва, че процесът *init* гарантира, че „обичайните отговорности на една система *init*, като събирането на зомби процеси, се изпълняват вътре в контейнера“, и че този `docker-init`, включен в нормалната инсталация, е направен с [tini](https://github.com/krallin/tini). Самият проект tini се описва като минимален *init*, който стартира едно-единствено дете и чака то да приключи, „събирайки зомбита и препращайки сигнали междувременно“, и предупреждава, че от Docker 1.13 е включен в Docker, без да се инсталира нищо в образа.

Това са две задачи и блокове 4 до 6 на `fig07_02.sh` показват и двете.

#### 7.3.2 Първата задача: препращане на сигнали

Блок 4 пуска същия `sleep 300` с `--init`. `docker top` сега показва два процеса: `/sbin/docker-init -- sleep 300` и, под него, `sleep 300`. Номер 1 е `docker-init`, който има обработчици за сигналите; когато `docker stop` му изпрати `SIGTERM`, той го препраща на детето си. За детето `SIGTERM` е обикновен сигнал, защото то **не** е номер 1, така че действието по подразбиране се прилага и то умира. `docker-init` вижда, че детето му е умряло, и излиза със същия код. Резултат: **251 ms** вместо 11 315 (88 ms при по-малко натовареното изпълнение) и `ExitCode=143`, същото 128 + 15, което получи в терминала си в блок 3. Без да се промени нито ред от програмата.

#### 7.3.3 Втората задача: събиране на зомбита

Когато процес приключи, той не изчезва напълно: остава ред в таблицата на процесите с кода му на изход, който чака родителят му да го прочете. Докато никой не го прочете, този процес е **зомби**: не работи, не използва памет, но заема номер на процес. Ако родителят умре преди детето, ядрото назначава на сирачето нов родител: *init* на неговото пространство от имена. Така че вътре в контейнер всички сирачета накрая стават деца на номер 1, а номер 1 трябва да ги събира.

Блок 5 го предизвиква. Контейнерът изпълнява `sh -c '(sleep 1 &); exec sleep 300'`: един *subshell* пуска `sleep 1` във фонов режим и си отива, така че този `sleep 1` остава сираче и става дете на номер 1; след това `exec` заменя *shell* със `sleep 300`, който става номер 1. Секунда по-късно сирачето приключва, а новият му родител, `sleep 300`, няма представа, че трябва да го събере. Виж двата изгледа в блока:

- **`docker top` не го показва.** Появява се само `sleep 300`. `docker top` пита за процесите, които принадлежат на контролната група на контейнера, а процес, който вече е приключил, излиза от тази група, макар редът му да остава в таблицата. Това е измерване, което си струва да запомниш: ако търсиш зомбита, `docker top` не е инструментът.
- **`ps` на компютъра ти го показва.** С `--ppid` искаш децата на номер 1 на контейнера и се появява `Z    [sleep] <defunct>`: състояние `Z`, от зомби, и думата `defunct` — покойник.

Блок 6 повтаря същото с `--init`. Сега сирачето се назначава на `docker-init`, който знае как да събира деца. Децата на номер 1 са само *shell*, превърнат в `sleep 300`; от зомбито — нищо.

Едно зомби не вреди; хиляди — да. Всяко заема номер на процес, а в Урок 2 сложи на контейнера `--pids-limit 50`. Програма, която пуска помощни процеси и не ги събира, с времето остава без възможност да пусне нито един повече.

#### 7.3.4 А `revisor`? Нуждае се от него по-малко, отколкото изглежда

Нека бъдем точни, защото тук е лесно да се преувеличи. `revisor` инсталира обработчика си за `SIGTERM` (ще го видиш да спира за по-малко от секунда без `--init` в раздел 7.4) и не пуска дъщерни процеси, така че не оставя зомбита. Днес той **не се нуждае** от `--init`. Курсът все пак го използва, по две причини. Първата: струва почти нищо (още един миниатюрен процес и четири букви). Втората: в деня, в който някой промени програмата, или я обвие в стартов скрипт, или ѝ добави инструмент, който пуска процеси, образът продължава да спира правилно, без някой да трябва да си спомня за този урок. Това е евтина застраховка и затова е сред опциите с подсилена защита, които Урок 9 копира в Compose.

### 7.4 `HEALTHCHECK` без `curl`

#### 7.4.1 Инструкцията

`HEALTHCHECK` казва на Docker как да пита един контейнер дали е добре. Docker изпълнява тази команда **вътре** в контейнера през определено време и гледа кода ѝ на изход. Справочникът на Dockerfile определя три стойности: `0` е успех („контейнерът е здрав и готов за използване“), `1` е „нездрав“, а `2` е запазена: не я използвай. Опциите, със стойностите им по подразбиране според същия справочник ([справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/)):

| Опция | Какво е | По подразбиране | В `revisor` |
|---|---|---|---|
| `--interval` | през колко време се проверява | `30s` | `10s` |
| `--timeout` | колко може да трае една проверка, преди да се брои за провал | `30s` | `3s` |
| `--start-period` | време за стартиране: провалите тук не се броят | `0s` | `5s` |
| `--start-interval` | през колко време се проверява **по време на** стартирането | `5s` | (по подразбиране) |
| `--retries` | колко поредни провала са нужни, за да бъде обявен за нездрав | `3` | `3` |

Един Dockerfile може да има само **един** `HEALTHCHECK`; ако напишеш няколко, важи последният. `HEALTHCHECK NONE` изключва проверката, наследена от базовия образ. Онова, което командата напише в изхода си, се пази заедно с резултата и се чете с `docker inspect`; пазят се само първите 4096 байта.

С тези опции контейнерът минава през три състояния: `starting`, докато няма отговор, който да се брои, `healthy`, щом една проверка излезе с `0`, и `unhealthy`, когато се натрупат толкова поредни провала, колкото казва `--retries`. Всеки успех нулира серията от провали.

#### 7.4.2 Dockerfile от този урок

Това е онзи от Урок 6 с две нови инструкции накрая:

```dockerfile
# syntax=docker/dockerfile:1
# fig07_01.Dockerfile — Lección 7: la imagen dice cómo está (HEALTHCHECK) y muere bien.
# Parte de la de la Lección 6; lo nuevo está al final.

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
# La salud la revisa el propio binario: la imagen no tiene shell ni curl.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/revisor", "healthcheck"]
# Señal de apagado explícita (es la de omisión; escribirla documenta la intención).
STOPSIGNAL SIGTERM
ENTRYPOINT ["/revisor"]
```

Какво се промени:

1. **`HEALTHCHECK ... CMD ["/revisor", "healthcheck"]`.** Проверката я прави самият двоичен файл: подкомандата `healthcheck` на `revisor` пита собствения му процес за `GET /salud` на `127.0.0.1`, с ограничение от две секунди; ако отговори `200`, отпечатва `sano` и излиза с `0`; ако не, отпечатва `no sano: …` и излиза с `1`. Във формата *exec* е, с квадратни скоби, като `ENTRYPOINT`: по същата причина от Урок 3, и по още една, която ще видиш след малко.
2. **Времената.** `--interval=10s`, защото `revisor` няма нужда да бъде наблюдаван на всеки пет секунди, а трийсет (по подразбиране) е твърде много, за да се забележи проблем. `--timeout=3s` оставя резерв над двете секунди, които самата подкоманда си дава. `--start-period=5s` му дава време да стартира, а през това време Docker пита на всеки пет секунди (`--start-interval`), така че първият отговор идва бързо. `--retries=3` иска три поредни провала, преди да го обяви за нездрав: едно препъване не стига.
3. **`STOPSIGNAL SIGTERM`**, който видя в 7.2.2.

#### 7.4.3 Защо не `curl`

Най-разпространеният начин за писане на проверка на състоянието, който ще срещнеш в почти всички ръководства, е `HEALTHCHECK CMD curl -f http://localhost:8080/salud || exit 1`. Той има два проблема в образа на `revisor` и скриптът от този раздел ги предизвиква. Първият е очевиден: образът няма `curl`. Вторият е по-фин: този ред е във формата *shell*, а формата *shell* изисква `/bin/sh`, който също го няма. Същото става с `docker run --health-cmd`, който е начинът проверката да се зададе или промени при стартиране: онова, което пишеш там, Docker го изпълнява с *shell*.

Лесният изход би бил да се добави `curl` в образа. Не си струва: това са мегабайти мрежов инструмент, със собствена история на уязвимости, сложени в образа, който в Урок 5 остави без нищо излишно, само за да зададеш въпрос, който програмата вече знае как да зададе. Добрият изход е онзи, който `revisor` вече има: подкоманда на същия двоичен файл. Нула допълнителни байта, а проверката пита точно онова, което програмата знае за себе си. Тестовата услуга прави същото със своя `servicio-prueba healthcheck` и затова от Урок 2 има проверка на състоянието, без да има `curl`.

#### 7.4.4 Да я видиш да се проваля и да я видиш да работи

Скриптът `fig07_03.sh` изгражда образа, опитва първо да го наблюдава с `curl`, а след това го стартира със собствената му проверка:

```bash
#!/usr/bin/env bash
# fig07_03.sh — HEALTHCHECK sin curl. Construye el revisor con fig07_01.Dockerfile,
# provoca primero el error de vigilarlo con curl (la imagen no tiene ni shell ni
# curl), lo corre con su propia revisión de salud y lo detiene midiendo el tiempo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

# El proyecto: el código que entrega el curso + los archivos de esta lección.
cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"

t() { date +%s%3N; }
# esperar_salud ESTADO: espera hasta 60 s a que la salud del contenedor sea ESTADO
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
# estado: lo que dice docker ps, sin el nombre
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
# bitacora_salud: las revisiones guardadas, una por renglón: código y salida
bitacora_salud() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{printf "%q" .Output}}{{println}}{{end}}' "$NOMBRE" | sed '/^$/d'
}
SERVICIOS='propio http://127.0.0.1:8080/salud'

echo "== 1. Construir y leer la revisión de salud que trae la imagen"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null
docker image inspect --format '{{json .Config.Healthcheck}}' "$IMAGEN"
docker image inspect --format 'StopSignal={{.Config.StopSignal}}' "$IMAGEN"

echo
echo "== 2. El error: vigilarlo con curl, como en los tutoriales"
docker run -d --name "$NOMBRE" -e REVISOR_SERVICIOS="$SERVICIOS" \
  --health-cmd 'curl -fs http://127.0.0.1:8080/salud || exit 1' \
  --health-interval 2s --health-retries 2 --health-start-period 1ms "$IMAGEN" >/dev/null
inicio=$(t); esperar_salud unhealthy; fin=$(t)
estado
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud | tail -1
echo "-- y sin embargo, el servicio contesta:"
docker exec "$NOMBRE" /revisor healthcheck
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Con la revisión de la imagen: el propio binario se pregunta"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
estado
inicio=$(t); esperar_salud healthy; fin=$(t)
estado
echo "pasó a healthy en $(( (fin - inicio + 500) / 1000 )) s"
bitacora_salud
docker inspect --format 'Status={{.State.Status}} Health={{.State.Health.Status}} FailingStreak={{.State.Health.FailingStreak}}' "$NOMBRE"

echo
echo "== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms"
docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_03.sh
== 1. Construir y leer la revisión de salud que trae la imagen
{"Test":["CMD","/revisor","healthcheck"],"Interval":10000000000,"Timeout":3000000000,"StartPeriod":5000000000,"Retries":3}
StopSignal=SIGTERM

== 2. El error: vigilarlo con curl, como en los tutoriales
Up 4 seconds (unhealthy)
pasó a unhealthy en 5 s
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
-- y sin embargo, el servicio contesta:
sano

== 3. Con la revisión de la imagen: el propio binario se pregunta
Up 1 second (health: starting)
Up 6 seconds (healthy)
pasó a healthy en 5 s
0 "sano\n"
Status=running Health=healthy FailingStreak=0

== 4. docker stop: el revisor es el proceso 1 y atiende SIGTERM
docker stop tardó 657 ms
ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

Новото в скрипта: `esperar_salud` пита на всеки половин секунда за `.State.Health.Status`, докато не каже онова, което очаква; `estado` показва колоната `STATUS` на `docker ps` без името; а `bitacora_salud` обхожда `.State.Health.Log`, списъка с последните проверки, който Docker пази, с кода и изхода на всяка. `printf "%q"` пише изхода в кавички и с новите редове като `\n`, за да се види точно какво е отпечатала командата.

Блок по блок:

1. **Образът съдържа своята проверка.** `docker image inspect` я показва в JSON: командата във формата *exec* (`"CMD"`, последвано от списъка) и времената в наносекунди (`10000000000` са десет секунди). Сигналът за спиране е записан: `StopSignal=SIGTERM`.
2. **С `curl` — `unhealthy`.** Скриптът поиска проверка на всеки две секунди и два провала, за да се откаже, и на 5-ата секунда контейнерът вече беше `(unhealthy)`: две неуспешни проверки, на 2-рата и на 4-тата секунда, плюс времето, което отнема всяка. Обърни внимание на `--health-start-period 1ms`. Опция `--health-*` със стойност `0s` **не** изключва времето за стартиране: за Docker нулата означава „използвай стойността на образа“ и контейнерът би запазил 5-те секунди за стартиране от Dockerfile. `1ms` е начинът да поискаш почти нулево стартиране; Упражнение 2 ти показва измерената разлика. Логът на проверките казва защо, а кодът не е `1`, а **`-1`**: Docker дори не е успял да изпълни проверката. Съобщението е онова от Урок 2, когато опита `docker exec ... sh`, с друга формулировка: `exec: "/bin/sh": stat /bin/sh: no such file or directory`. А най-важното идва след това: `docker exec ... /revisor healthcheck` отговаря `sano`. **Услугата беше наред; проверката беше счупена.** Това е най-коварната грешка в този урок, защото състоянието `unhealthy` обвинява програмата за нещо, което е вина на онзи, който е написал проверката.
3. **С проверката на образа — `healthy` на 5-ата секунда.** Първо `(health: starting)`, после `(healthy)`. Петте секунди са `--start-interval`: първият въпрос пристигна в края на първия интервал от стартирането и мина успешно. Справочникът на Dockerfile казва, че първата проверка идва след един `--interval`, което тук би било десет секунди; измерено с Docker 29.2.1, по време на стартирането Docker използва `--start-interval` и първата дойде на петата секунда. Когато документацията и измерването не съвпадат, печели измерването (ще го видиш отново в 7.6.3). Логът на проверките има един запис: код `0` и изход `sano\n`. Последният ред чете същото по части: процесът е `running`, състоянието му е `healthy`, а серията от провали (`FailingStreak`) е `0`.
4. **Спирането.** Без `--init` `revisor` е номер 1, но този път **има** обработчик. `docker stop` отне **657 ms** при това изпълнение, с натоварена машина (562 ms в Урок 3, според запазения му изход), а кодът е `0`, а не `143`: програмата не е умряла от сигнала, а го е обработила и е излязла сама. Логовете го разказват със собствените си думи (`grep -v` оставя навън `GET /salud` от всяка проверка).

#### 7.4.5 В твоята папка

Проектът ти живее в `~/curso-docker/revisor` от Урок 3 насам. От корена на хранилището на курса сложи там Dockerfile от този урок и изгради образа, който ще запазиш:

```bash
cp programas/07-salud-y-ciclo-de-vida/estado/Dockerfile ~/curso-docker/revisor/Dockerfile
cd ~/curso-docker/revisor
docker build -q --build-arg VERSION=1.4.0 -t curso-docker-revisor:1.4.0 .
docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0
```

Последната команда трябва да отпечата същия JSON като в блок 1. `.dockerignore` и папката `secretos/` не се променят. `Dockerfile.malo`, този от Урок 6, вече не ти трябва; можеш да го махнеш от папката си или да го оставиш, защото `.dockerignore` не му позволява да пътува. Образът се стартира с подсилена защита в раздел 7.10, когато вече знаеш какво прави всяка опция.

### 7.5 Работещ не значи здрав

#### 7.5.1 Какво прави Docker със състоянието и какво не прави

Проверката на състоянието променя **един етикет**: онзи, който виждаш в скоби в `docker ps`. Нищо повече. Docker не рестартира контейнер `unhealthy`, не му спира трафика и не уведомява никого. Информацията е там, за да я използва някой: ти, когато гледаш `docker ps`; Compose, който с `depends_on` и `condition: service_healthy` чака една услуга да е здрава, преди да стартира следващата (Урок 9); оркестратор, който може да замени болния контейнер. Този раздел го доказва с тестовата услуга, която има трик, който `revisor` няма: сменя режима си, без да се рестартира.

#### 7.5.2 Тестовата услуга се разболява

Скриптът `fig07_04.sh` изгражда копие на тестовата услуга, стартира го с `--restart always` (най-настойчивата политика, която ще видиш в 7.6) и го прекарва през трите му режима:

```bash
#!/usr/bin/env bash
# fig07_04.sh — Corriendo no es sano. El servicio de prueba, con su propio
# HEALTHCHECK (cada 5 s, 2 reintentos), pasa a modo caído y a modo lento sin
# reiniciarse: el proceso sigue vivo y Docker lo marca unhealthy. Y una política
# de reinicio NO reinicia a un contenedor por estar unhealthy.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-9000}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
estado() { docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'; }
resumen() {
  docker inspect --format '{{.State.Status}} / {{.State.Health.Status}} / racha={{.State.Health.FailingStreak}} / reinicios={{.RestartCount}}' "$NOMBRE"
}
ultima_revision() {
  docker inspect --format '{{range .State.Health.Log}}{{.ExitCode}} {{.Output}}{{end}}' "$NOMBRE" | sed '/^$/d' | tail -1
}

echo "== 1. Arranca sano, con --restart always"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:9000" --restart always "$IMAGEN" >/dev/null
esperar_salud healthy
estado

echo
echo "== 2. Modo caído: el proceso sigue vivo, pero responde 503"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/caido"
inicio=$(t); esperar_salud unhealthy; fin=$(t)
echo "pasó a unhealthy en $(( (fin - inicio + 500) / 1000 )) s"
estado
resumen
ultima_revision

echo
echo "== 3. Diez segundos después, sigue unhealthy y nadie lo reinició"
sleep 10
resumen

echo
echo "== 4. De vuelta a sano, sin reiniciar nada"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/sano"
inicio=$(t); esperar_salud healthy; fin=$(t)
echo "volvió a healthy en $(( (fin - inicio + 500) / 1000 )) s"
resumen

echo
echo "== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2"
curl -s -X POST "http://127.0.0.1:$PUERTO/modo/lento"
esperar_salud unhealthy
resumen
ultima_revision
echo "-- y sin embargo, contesta 200:"
curl -s -o /dev/null -w '%{http_code} en %{time_total}s\n' "http://127.0.0.1:$PUERTO/"
```

```text
$ ./fig07_04.sh
== 1. Arranca sano, con --restart always
Up 5 seconds (healthy)

== 2. Modo caído: el proceso sigue vivo, pero responde 503
modo: caido
pasó a unhealthy en 10 s
Up 15 seconds (unhealthy)
running / unhealthy / racha=2 / reinicios=0
1 no sano: GET / respondió 503

== 3. Diez segundos después, sigue unhealthy y nadie lo reinició
running / unhealthy / racha=4 / reinicios=0

== 4. De vuelta a sano, sin reiniciar nada
modo: sano
volvió a healthy en 5 s
running / healthy / racha=0 / reinicios=0

== 5. Modo lento: contesta 200, pero tarda 3 s y la revisión espera 2
modo: lento
running / unhealthy / racha=2 / reinicios=0
1 no sano: Get "http://127.0.0.1:9000/": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
-- y sin embargo, contesta 200:
200 en 3.012887s
```

Тестовата услуга има собствен `HEALTHCHECK` от Урок 2: на всеки 5 секунди, с 2 повторни опита, а проверката ѝ изисква `200` за по-малко от 2 секунди. С това:

1. **Стартира здрава**, на 5-ата секунда.
2. **В неработещ режим — `unhealthy` на 10-ата секунда.** Две неуспешни проверки, с пет секунди между тях: това са `--retries=2` по `--interval=5s` от неговия Dockerfile. Сега погледни реда `resumen`: `running / unhealthy / racha=2 / reinicios=0`. Процесът **работи**; проверката на състоянието казва, че **не става**; серията от провали е 2; и никой не го е рестартирал. Последната проверка обяснява причината с точния текст от кода си: `1 no sano: GET / respondió 503`.
3. **Десет секунди по-късно — същото.** Серията стигна 4, а рестартиранията остават 0. Нито проверката на състоянието, нито `--restart always` направиха нещо. Това ставаше в сцената от началото: контейнер `Up`, `unhealthy` и изоставен.
4. **Обратно в здрав за 5 секунди**, без да се рестартира нищо: една добра проверка нулира серията и прави състоянието `healthy`. Състоянието не се печели веднъж завинаги: преизчислява се при всяка проверка.
5. **В бавен режим — също `unhealthy`.** И тук е най-финият урок. Услугата отговаря с `200`, кода за „всичко е наред“, но отнема 3 секунди, а проверката ѝ чака само 2: `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, което е начинът, по който Go казва „времето за чакане на отговора изтече“. `curl` накрая го потвърждава: `200 en 3.01s`. За проверката услуга, която отговаря късно, е услуга, която не отговаря. Това е дизайнерско решение: който пише проверката, решава какво означава „здрав“, а тук означава „отговаря правилно **и** навреме“.

#### 7.5.3 Какво пита една добра проверка

Проверката на състоянието отговаря на един-единствен въпрос: **може ли този процес да обслужва?** При `revisor` `/salud` отговаря, че HTTP сървърът е жив и обслужва, и нищо повече. Не проверява услугите, които `revisor` наблюдава: ако проверяваше това, неработеща тестова услуга би направила `revisor` `unhealthy`, а той е напълно наред и си върши работата, която е да докладва срива. Не проверява и дали може да запише отчета си, а в 7.7 ще видиш какво означава това. Проверка, която зависи от други услуги, превръща провала на една в провал на всички; затова е добре да пита за собствения процес и да е евтина: ще се изпълнява на всеки десет секунди през целия живот на контейнера.

### 7.6 Политики за рестартиране

#### 7.6.1 Четирите политики

**Политиката за рестартиране** казва на демона какво да прави, когато процесът на контейнер приключи. Избира се с `docker run --restart` и са четири, които документацията описва така ([Docker, „Start containers automatically“](https://docs.docker.com/engine/containers/start-containers-automatically/)):

| Политика | Какво прави |
|---|---|
| `no` | никога не рестартира; тя е по подразбиране |
| `on-failure[:максимум]` | рестартира, ако процесът излезе с код, различен от 0; с `:максимум` — само толкова пъти. Не рестартира контейнера, когато се рестартира демонът |
| `always` | рестартира винаги, когато процесът спре. Ако си го спрял ти, стартира отново само когато демонът на Docker се рестартира или когато ти го стартираш |
| `unless-stopped` | като `always`, само че ако контейнерът е бил спрян, не стартира отново дори когато демонът се рестартира |

Още два детайла от документацията са важни. Първо: ако спреш контейнер ръчно, политиката му се пренебрегва, докато демонът не се рестартира или докато не го стартираш отново; така няма как да се бориш с Docker, за да изключиш нещо. И второ: между едно рестартиране и следващото Docker чака все по-дълго: двойно повече от предишния път, като започва от 100 милисекунди и с таван от една минута; ако контейнерът успее да остане горе поне 10 секунди, чакането се връща на 100 ms ([справочник на `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). Това не позволява счупен контейнер да се рестартира хиляди пъти в секунда.

#### 7.6.2 Измерване на това, което прави всяка

Скриптът `fig07_05.sh` изгражда `revisor` и го кара да умира по няколко начина:

```bash
#!/usr/bin/env bash
# fig07_05.sh — Políticas de reinicio. Un revisor sin configuración muere con
# código 1 en cuanto arranca: con on-failure:3, Docker lo reintenta tres veces,
# cada vez esperando más. Y con always: qué hace Docker cuando el proceso muere
# solo, y qué hace cuando lo detienes tú. Usa sudo una vez, para matar al
# proceso desde fuera como lo haría el núcleo.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}reinicios-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
resumen() {
  docker inspect --format 'Status={{.State.Status}} ExitCode={{.State.ExitCode}} RestartCount={{.RestartCount}}' "$NOMBRE"
}

echo "== 1. on-failure:3 con un revisor sin configuración"
desde=$(date +%s)
docker run -d --name "$NOMBRE" --restart on-failure:3 "$IMAGEN" >/dev/null
sleep 8
resumen
echo "-- lo que escribió en sus cuatro vidas:"
docker logs "$NOMBRE" 2>&1 | sort | uniq -c
echo "-- cuánto esperó Docker entre un arranque y el siguiente:"
docker events --since "$desde" --until "$(date +%s)" \
  --filter "container=$NOMBRE" --filter event=start --format '{{.TimeNano}}' |
  awk 'NR > 1 { printf "arranque %d: %d ms después del anterior\n", NR, ($1 - previo) / 1000000 } { previo = $1 }'
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. Sin política (no, la de omisión): muere y se queda muerto"
docker run -d --name "$NOMBRE" "$IMAGEN" >/dev/null
sleep 3
resumen
docker rm -f "$NOMBRE" >/dev/null

SERVICIOS='propio http://127.0.0.1:8080/salud'
echo
echo "== 3. --restart always con el revisor bien configurado"
docker run -d --name "$NOMBRE" --restart always -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
sleep 2
echo "-- el núcleo mata al proceso (como haría el asesino de memoria):"
PID1=$(pid_de "$NOMBRE")
sudo kill -KILL "$PID1"
sleep 3
resumen
echo "-- lo detienes tú, con docker stop:"
docker stop "$NOMBRE" >/dev/null
sleep 3
resumen
echo "-- lo vuelves a arrancar tú, y lo matas con docker kill:"
docker start "$NOMBRE" >/dev/null
sleep 2
docker kill "$NOMBRE" >/dev/null
sleep 3
resumen
```

```text
$ ./fig07_05.sh
== 1. on-failure:3 con un revisor sin configuración
Status=exited ExitCode=1 RestartCount=3
-- lo que escribió en sus cuatro vidas:
      4 revisor: falta REVISOR_SERVICIOS (ejemplo: REVISOR_SERVICIOS="prueba http://curso-docker-prueba:9000/ 2s")
-- cuánto esperó Docker entre un arranque y el siguiente:
arranque 2: 181 ms después del anterior
arranque 3: 294 ms después del anterior
arranque 4: 490 ms después del anterior

== 2. Sin política (no, la de omisión): muere y se queda muerto
Status=exited ExitCode=1 RestartCount=0

== 3. --restart always con el revisor bien configurado
-- el núcleo mata al proceso (como haría el asesino de memoria):
Status=running ExitCode=0 RestartCount=1
-- lo detienes tú, con docker stop:
Status=exited ExitCode=0 RestartCount=1
-- lo vuelves a arrancar tú, y lo matas con docker kill:
Status=exited ExitCode=137 RestartCount=0
```

Новото в скрипта: `docker events` изброява какво е направил демонът с контейнер в даден интервал от време (тук само стартиранията, `event=start`), а `{{.TimeNano}}` дава точния час на всяко в наносекунди. `awk` изважда всяко стартиране от предишното и го превръща в милисекунди. А `sudo kill -KILL` изпраща `SIGKILL` на процеса на контейнера **извън Docker**, както би го направило ядрото, когато процес надхвърли ограничението на паметта; нужен е `sudo`, защото процесът е на потребителя `65532`, а не на твоя.

1. **`on-failure:3` с `revisor` без конфигурация.** Умира с `1` веднага щом стартира. Docker го стартира още три пъти и се отказа: `Status=exited ExitCode=1 RestartCount=3`. Логовете са доказателството: същото съобщение четири пъти, по едно на живот. А чаканията са тези от документацията, плюс времето за стартиране всеки път: **181, 294 и 490 ms**, което са 100, 200 и 400 от нарастващото чакане, плюс около 80 до 90 ms стартиране. При изпълнение с машина, натоварена от други задачи, излязоха 530, 1483 и 2399 ms: чакането го задава Docker, но колко трае всяко стартиране, зависи от компютъра. `revisor` нямаше как да се поправи (липсва му променлива), и затова таванът е добра идея: три опита стигат, за да разбереш, че това не е препъване.
2. **Без политика остава мъртъв.** `RestartCount=0`. Това искаш за нещо, което се изпълнява веднъж и приключва.
3. **`always` с правилно конфигуриран `revisor`.** Три начина да умре, три резултата:
   - **Ядрото го убива.** Docker го стартира отново: `Status=running RestartCount=1`. За това съществува политиката. (`ExitCode=0` е на контейнера, който работи сега; той още не е приключил, така че няма собствен код.)
   - **Спираш го ти с `docker stop`.** Остава спрян, с `ExitCode=0`, защото е спрял подредено. Политиката уважава решението ти.
   - **Убиваш го ти с `docker kill`.** И той остава спрян, сега със `137`. Docker брои `docker kill` за ръчно спиране, също като `docker stop`, макар процесът да умира от `SIGKILL`. И обърни внимание на `RestartCount=0`: броячът се нулира, когато го стартира с `docker start`.

#### 7.6.3 Едно изречение от документацията, което е добре да се чете внимателно

Страницата за политиките за рестартиране казва, че една политика „влиза в сила само след като контейнерът стартира успешно“ и че това означава да е горе „поне 10 секунди“. Блок 1 му противоречи на пръв поглед: `revisor` без конфигурация не издържа и секунда, а Docker го рестартира три пъти. Онова, което измерването показва, е казаното в справочника на `docker run`: 10-те секунди решават кога чакането се връща на 100 ms, а не дали се прави нов опит. Когато документацията и твоето измерване не съвпадат, печели измерването, а ти записваш версията, с която си мерил: Docker 29.2.1.

#### 7.6.4 Коя да изберем за `revisor`

`unless-stopped`. `revisor` е услуга, която трябва винаги да е горе, така че има нужда да бъде рестартирана, ако ядрото я убие или ако компютърът се рестартира; това изключва `no` и `on-failure`, която не я стартира след рестартиране на демона. Между `always` и `unless-stopped` разликата се появява само когато демонът се рестартира, например при рестартиране на компютъра: с `always` контейнер, който си спрял нарочно, се връща към живота; с `unless-stopped` се уважава това, че си го спрял. Това не беше измерено тук, защото рестартирането на демона спира всички контейнери на компютъра; то е в таблицата на документацията. И помни какво видя в 7.5: никоя от четирите не рестартира контейнер, защото е `unhealthy`. Политиката за рестартиране се грижи за смъртта на процеса, а не за състоянието му.

### 7.7 Файлова система само за четене

#### 7.7.1 Защо

Образът винаги е бил само за четене; онова, което се пише при работа, отива в нов слой, собствен на контейнера, който видя в Урок 4. `--read-only` затваря този слой: кореновата файлова система на контейнера се монтира „като само за четене“ ([справочник на `docker run`](https://docs.docker.com/reference/cli/docker/container/run/)). Програмата продължава да може да чете всичко, което образът съдържа, но не може да създава, променя, нито изтрива нито един файл.

Печалбата е в сигурността и в реда. В сигурността, защото който успее да поеме контрола над процеса, не може да остави своя програма на диска, нито да промени конфигурационен файл, нито да замени двоичния файл. В реда, защото те принуждава да знаеш точно **къде пише програмата ти**: всеки път с право на запис става решение, а не случайност.

#### 7.7.2 Да го предизвикаш и да го поправиш

Скриптът `fig07_06.sh` използва опцията `REVISOR_REPORTE`, която казва на `revisor` къде да запази последния отчет. `revisor` го записва с временен файл и преименуване в същата папка, за да не може никой никога да прочете недописан отчет. Блокове 1 и 2 са този раздел; 3 е 7.10:

```bash
#!/usr/bin/env bash
# fig07_06.sh — Solo lectura y el revisor endurecido completo. Primero el error:
# con --read-only, el revisor no puede guardar su reporte. Después el arreglo,
# un tmpfs solo donde hace falta escribir. Y al final, todas las opciones de la
# lección juntas: lo que Docker anotó, lo que el núcleo aplica y cómo se apaga.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
PUERTO="${PUERTO:-8080}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

# pid_de NOMBRE: el número que tiene EN EL EQUIPO el proceso 1 del contenedor.
# Se detiene si vale 0 (el contenedor no está corriendo): un 0 en kill, pgrep -P
# o ps --ppid apuntaría a otros procesos del equipo, no al contenedor.
pid_de() {
  local pid; pid=$(docker inspect --format '{{.State.Pid}}' "$1")
  [ "$pid" -gt 0 ] || { echo "(el contenedor $1 no está corriendo)" >&2; return 1; }
  echo "$pid"
}
t() { date +%s%3N; }
esperar_http() {
  for _ in $(seq 40); do curl -fsS -o /dev/null "$1" 2>/dev/null && return 0; sleep 0.5; done
  echo "(no respondió $1)"; return 1
}
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}
SERVICIOS='propio http://127.0.0.1:8080/salud'
# El número del archivo temporal cambia en cada corrida: se tapa a la vista.
tapar() { sed -E 's/reporte-[0-9]+\.tmp/reporte-<n>.tmp/'; }

echo "== 1. --read-only, y el revisor guardando su reporte en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados" | tapar
echo "-- /salud no escribe nada, así que sigue contestando:"
curl -s -w ' [%{http_code}]\n' "http://127.0.0.1:$PUERTO/salud"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 2. El arreglo: un tmpfs pequeño solo en /tmp"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=1m \
  -e REVISOR_REPORTE=/tmp/reporte.json -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_http "http://127.0.0.1:$PUERTO/salud"
curl -s -o /dev/null -w '[%{http_code}]\n' "http://127.0.0.1:$PUERTO/api/estados"
docker inspect --format '{{range $ruta, $opciones := .HostConfig.Tmpfs}}{{$ruta}} {{$opciones}}{{end}}' "$NOMBRE"
docker rm -f "$NOMBRE" >/dev/null

echo
echo "== 3. Todo junto: el revisor endurecido"
docker run -d --name "$NOMBRE" -p "127.0.0.1:$PUERTO:8080" \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
echo "-- lo que Docker anotó:"
docker inspect --format 'ReadonlyRootfs={{.HostConfig.ReadonlyRootfs}} CapDrop={{.HostConfig.CapDrop}} SecurityOpt={{.HostConfig.SecurityOpt}} Init={{.HostConfig.Init}} Restart={{.HostConfig.RestartPolicy.Name}}' "$NOMBRE"
echo "-- los procesos:"
docker top "$NOMBRE" -o pid,ppid,user,args | sed -E 's/^ *[0-9]+ +[0-9]+ /<pid> <ppid> /'
echo "-- lo que el núcleo aplica al revisor (el hijo de docker-init):"
PID1=$(pid_de "$NOMBRE")
HIJO=$(pgrep -P "$PID1" | head -1)
grep -E '^(CapEff|CapBnd|NoNewPrivs)' "/proc/$HIJO/status"
echo "-- docker stop:"
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
```

```text
$ ./fig07_06.sh
== 1. --read-only, y el revisor guardando su reporte en /tmp
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
-- /salud no escribe nada, así que sigue contestando:
{"estado":"vivo","version":"1.4.0"}
 [200]

== 2. El arreglo: un tmpfs pequeño solo en /tmp
[200]
/tmp rw,noexec,nosuid,size=1m

== 3. Todo junto: el revisor endurecido
Up 5 seconds (healthy)
-- lo que Docker anotó:
ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped
-- los procesos:
PID                 PPID                USER                COMMAND
<pid> <ppid>             65532               /sbin/docker-init -- /revisor
<pid> <ppid>             65532               /revisor
-- lo que el núcleo aplica al revisor (el hijo de docker-init):
CapEff:	0000000000000000
CapBnd:	0000000000000000
NoNewPrivs:	1
-- docker stop:
tardó 206 ms; ExitCode=0
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí terminated, apagando
revisor: apagado limpio
```

1. **С `--read-only` — `500`.** `revisor` се опита да създаде временния си файл в `/tmp`, а ядрото отговори `read-only file system`. `revisor` не крие грешката: отговаря с `500` и с точната причина. Номерът на временния файл се променя при всяко изпълнение и скриптът го скрива с `<n>`. И погледни следващия ред: **`/salud` продължава да отговаря с `200`**. Проверката на състоянието би казала `healthy`, докато всяко запитване към `/api/estados` се проваля. Това предвещаваше 7.5.3: проверката на състоянието казва дали процесът обслужва, а не дали всяка функция работи. Затова при подсилването на защитата на контейнер не стига да видиш, че стартира и е здрав: трябва да изпробваш онова, което прави.
2. **С `--tmpfs /tmp` — `200`.** **`tmpfs`** е папка, която живее в паметта на компютъра: според документацията, за разлика от томовете и *bind mounts*, „е временна и се пази само в паметта на хоста“, а когато контейнерът спре, записаното там изчезва ([Docker, „tmpfs mounts“](https://docs.docker.com/engine/storage/tmpfs/)). Точно това е нужно на един временен файл. Кореновата файлова система остава само за четене; само `/tmp` приема запис, и то с три опции: `noexec` не позволява изпълнение на програми оттам (който успее да запише файл, не може да го пусне), `nosuid` кара бита *setuid* да няма ефект там (ще видиш какво е в 7.9), а `size=1m` му слага таван от един мегабайт. Без `size` ядрото му слага за таван половината от паметта на компютъра, а правата му са `1777`, с право на запис за всеки (документацията дава тези стойности за `--mount type=tmpfs`; с `--tmpfs` са същите, защото ги задава ядрото). Освен това същата страница предупреждава, че записаното там се брои към ограничението на паметта на контейнера: с `--memory 64m` от Урок 2 `tmpfs` без таван би могъл да доведе `revisor` до ограничението му. Последният ред показва как е записано.

Тази поправка е за този урок. В Урок 8 отчетът ще се пази в том, защото трябва да оцелее след контейнера, а онова, което живее в `tmpfs`, умира с него.

### 7.8 Capabilities навън

#### 7.8.1 `root`, разделен на парчета

В Урок 0 видя, че Docker не дава на `root` цялата му власт: оставя му четиринайсет **capabilities**. Наръчникът на Linux обяснява понятието: Linux „разделя привилегиите, традиционно свързани със суперпотребителя, на отделни единици“, наречени capabilities, които могат да се включват и изключват поотделно ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Някои от онези, които Docker оставя по подразбиране, с определението им от наръчника:

| Capability | Какво позволява |
|---|---|
| `CAP_CHOWN` | произволна смяна на потребителя и групата собственици на файл |
| `CAP_DAC_OVERRIDE` | заобикаляне на проверките на правата за четене, запис и изпълнение на файлове |
| `CAP_KILL` | заобикаляне на проверките на правата за изпращане на сигнали |
| `CAP_SETUID` | произволна смяна на потребителя на процес |
| `CAP_NET_BIND_SERVICE` | слушане на портове под 1024 |

`revisor` работи като `65532`, който не е `root`, така че по принцип няма нито една. Защо да ги махаме? Защото списъкът, с който работи един контейнер, не е само този на процеса му: той е и **таванът** на онова, което всеки процес в този контейнер би могъл да получи (*bounding set* в наръчника). Ако някой намери начин да стане `root` вътре в контейнера, наследява този таван. С `--cap-drop ALL` таванът е нула: дори `root` вътре няма нито една.

#### 7.8.2 Да го видиш с истински `root`

За да се види какво се променя, е нужен контейнер, който работи като `root` и има инструменти, а образът на Go има и двете. Скриптът `fig07_07.sh` не изгражда нищо и всеки контейнер се изтрива сам:

```bash
#!/usr/bin/env bash
# fig07_07.sh — Capacidades y no-new-privileges, vistos en un contenedor que SÍ
# tiene shell y herramientas: la imagen de Go que ya bajaste. Qué puede hacer
# root con sus 14 capacidades, qué deja de poder sin ellas, y cómo un programa
# setuid convierte a un usuario normal en root… salvo con no-new-privileges.
# No construye nada y cada contenedor se borra solo (--rm).
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombre de apoyo con «fig07»: el guion nunca toca tus contenedores del curso.
NOMBRE="${PREFIJO}fig07-caps"
GO="golang:1.27.3-trixie@sha256:604106102d33b1084e37ca08adf98ac0813624ae8595bd0d7f3965ecebded09c"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true' EXIT

# correr [opciones de docker run] -- COMANDO: corre COMANDO con sh en un contenedor desechable
correr() {
  local opciones=()
  while [ "$1" != "--" ]; do opciones+=("$1"); shift; done
  shift
  docker run --rm --name "$NOMBRE" "${opciones[@]}" "$GO" sh -c "$1" 2>&1 || echo "[código de salida: $?]"
}
# La prueba: ¿puede root regalarle un archivo a otro usuario?
REGALAR='grep CapEff /proc/self/status; touch /tmp/a && chown 10001 /tmp/a && echo "chown: hecho"'

echo "== 1. root, con las capacidades que Docker deja por omisión"
correr -- "$REGALAR"

echo
echo "== 2. El mismo root, con --cap-drop ALL"
correr --cap-drop ALL -- "$REGALAR"

echo
echo "== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta"
correr --cap-drop ALL --cap-add CHOWN -- "$REGALAR"

# La otra prueba: un usuario normal ejecuta una copia de «id» con el bit setuid.
SETUID='cp /usr/bin/id /tmp/id-suid && chmod u+s /tmp/id-suid && ls -l /tmp/id-suid | cut -d" " -f1,3
setpriv --reuid 10001 --regid 10001 --clear-groups sh -c "id; /tmp/id-suid; grep NoNewPrivs /proc/self/status"'

echo
echo "== 4. Un programa setuid de root, ejecutado por el usuario 10001"
correr -- "$SETUID"

echo
echo "== 5. Lo mismo con --security-opt no-new-privileges"
correr --security-opt no-new-privileges -- "$SETUID"

echo
echo "== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80"
correr --user 10001:10001 --cap-drop ALL -- \
  'cat /proc/sys/net/ipv4/ip_unprivileged_port_start; perl -MIO::Socket::INET -e '"'"'IO::Socket::INET->new(LocalPort => 80, Listen => 1, ReuseAddr => 1) or die "no pude: $!\n"; print "escuchando en el 80\n"'"'"
```

```text
$ ./fig07_07.sh
== 1. root, con las capacidades que Docker deja por omisión
CapEff:	00000000a80425fb
chown: hecho

== 2. El mismo root, con --cap-drop ALL
CapEff:	0000000000000000
chown: changing ownership of '/tmp/a': Operation not permitted
[código de salida: 1]

== 3. --cap-drop ALL --cap-add CHOWN: solo la que hace falta
CapEff:	0000000000000001
chown: hecho

== 4. Un programa setuid de root, ejecutado por el usuario 10001
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 euid=0(root) groups=10001
NoNewPrivs:	0

== 5. Lo mismo con --security-opt no-new-privileges
-rwsr-xr-x root
uid=10001 gid=10001 groups=10001
uid=10001 gid=10001 groups=10001
NoNewPrivs:	1

== 6. ¿Y los puertos bajos? Un usuario sin capacidades escucha en el 80
0
escuchando en el 80
```

Функцията `correr` сглобява `docker run --rm` с опциите, които ѝ подадеш преди `--`, и изпълнява командата със `sh -c`. Пробата в първите три блока е една и съща: да се покаже редът `CapEff` (**ефективните** capabilities, онези, които процесът може да използва в този момент) и да се подари файл на потребителя `10001` с `chown`.

1. **`root` с подразбиращите се.** `CapEff: 00000000a80425fb`, същата маска на четиринайсетте, която декодира в Урок 0. `chown` работи.
2. **`root` с `--cap-drop ALL`.** `CapEff` е нула, а `chown` се проваля с `Operation not permitted`, код 1. Това е `root` (продължава да е потребител 0), но `root` без capabilities не може да прави онова, което прави `root` специален.
3. **`--cap-drop ALL --cap-add CHOWN`.** Маската е `1`: един-единствен бит, този на `CAP_CHOWN`, която е capability номер 0. `chown` отново работи. Това е моделът за програма, която наистина има нужда от една: махаш всички и връщаш само нея, по име, пред очите на всеки, който чете командата.

#### 7.8.3 Ниските портове вече не изискват capability

Блок 6 отговаря на съмнение, което ще имаш: ако `CAP_NET_BIND_SERVICE` е онази, която позволява да се слуша на портове под 1024, трябва ли уеб сървър на порт 80 да я запази? В контейнер на Docker — не. Потребителят `10001`, **без нито една capability**, отвори порт 80. Първият ред обяснява защо: вътре в контейнера настройката на ядрото `ip_unprivileged_port_start`, която казва от кой порт нататък може да слуша потребител без привилегии, е `0`. Docker я задава така по подразбиране от версия 20.10 нататък, във всеки контейнер със собствена мрежа ([moby/moby #41030](https://github.com/moby/moby/pull/41030)), а тъй като тази настройка важи само за мрежата на контейнера, не променя нищо на компютъра ти. `revisor` слуша на 8080 и така или иначе няма нужда от нея, но така вече знаеш, че `--cap-drop ALL` не те принуждава да местиш услуга на друг порт.

### 7.9 `no-new-privileges`

#### 7.9.1 Битът *setuid*

В Linux един изпълним файл може да има включен бит ***setuid***: който и да го изпълни, го изпълнява **с потребителя собственик на файла**. Така работят `passwd` или `su`, които обикновен потребител изпълнява и които трябва за момент да бъдат `root`. Наръчникът за capabilities казва за важния случай: програма *setuid* на `root` получава всички capabilities, освен онези, които таванът (*bounding set*) не позволява ([capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html)). Това е легитимна врата за повишаване на привилегиите и затова е любимата на онзи, който се опитва да ги повиши без разрешение.

`--security-opt no-new-privileges` затваря тази врата. Тя включва в процеса флаг на ядрото, `no_new_privs`, който документацията на ядрото определя така: с него `execve` (изпълнението на друга програма) обещава „да не дава привилегията да се прави нещо, което не би могло да се направи без това извикване“; конкретно, „битовете *setuid* и *setgid* вече не променят uid, нито gid“, а capabilities на даден файл не се добавят. Флагът се наследява от всички деца и **не може да бъде изключен** ([Linux, „No New Privileges Flag“](https://docs.kernel.org/userspace-api/no_new_privs.html)). Справочникът на `docker run` го казва с практически думи: с тази опция „командите, които повишават привилегиите, като `su` или `sudo`, вече не работят“.

#### 7.9.2 Да го видиш

Блокове 4 и 5 на `fig07_07.sh` правят пробата. Като `root` скриптът копира програмата `id` в `/tmp/id-suid` и включва бита ѝ *setuid* (`s` в `-rwsr-xr-x`, собственик `root`). След това, със `setpriv`, инструмент на Debian, който сменя потребителя, става потребител `10001` и изпълнява `id` два пъти: нормалния и копието със *setuid*.

4. **Без `no-new-privileges`.** Нормалният `id` казва `uid=10001`. Копието казва `uid=10001 ... euid=0(root)`: **ефективният** потребител е `root`. Произволен потребител е изпълнил файл и, докато той работи, има властта на `root`. `NoNewPrivs: 0`.
5. **С `no-new-privileges`.** И двата казват `uid=10001` и нищо повече. Битът още е там (`-rwsr-xr-x`), но ядрото вече не му обръща внимание. `NoNewPrivs: 1`.

Защо има значение за `revisor`, който няма програми със *setuid*? По същата причина като `--cap-drop ALL`: не заради онова, което има днес в образа, а заради онова, което някой би могъл да вкара или да намери утре. И се съчетава с предишното: `tmpfs` в `/tmp` има `nosuid` и `noexec`, кореновата файлова система е само за четене, а таванът на capabilities е нула. За да повиши привилегиите, нападателят би трябвало да запише програма, да я изпълни и битът *setuid* да се брои; всяка от трите опции му затваря по една стъпка.

### 7.10 Всичко заедно: `revisor` с подсилена защита

#### 7.10.1 Командата

Това са опциите, с които `revisor` работи отсега нататък. Урок 9 ги записва в `compose.yaml` с еквивалентите им в YAML (`read_only: true`, `cap_drop: [ALL]`, `security_opt`, `init: true`), а не като опции на командния ред:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' \
  curso-docker-revisor:1.4.0
```

Всеки ред идва от някой урок: портът на `127.0.0.1` и ограниченията — от 2; образът без `root` и без *shell* — от 3 и 5; конфигурацията чрез `-e` — от 6; а вторият ред и политиката за рестартиране — от този. Няма `--tmpfs`, защото тук не му се иска да пази отчета; в Урок 8 ще има том за това.

Тези опции силно намаляват онова, което натрапник може да направи, но не заместват нищо друго: програма, която наистина има нужда от конкретна capability или от запис на конкретно място, иска `--cap-add` или том, едно по едно, а останалата защита (какъв код работи, какво му се монтира) остава твоя работа.

#### 7.10.2 Проверка

Блок 3 на `fig07_06.sh` изпълнява точно тези опции и пита всеки за неговото:

1. **Състоянието:** `(healthy)` на 5-ата секунда, с всичко приложено. Никоя от опциите не попречи на `revisor`.
2. **Какво е записал Docker:** `ReadonlyRootfs=true CapDrop=[ALL] SecurityOpt=[no-new-privileges] Init=true Restart=unless-stopped`. Това е поисканото, прочетено от конфигурацията на контейнера.
3. **Процесите:** `docker-init` като номер 1 и `/revisor` като негово дете, и двата с потребител `65532`.
4. **Какво прилага ядрото**, прочетено от `/proc` на детето, което е `revisor` (скриптът го намира с `pgrep -P`, който търси децата на процес): `CapEff` е нула (няма capabilities), `CapBnd` е нула (не би могъл и да ги получи) и `NoNewPrivs: 1`. От трите `CapBnd` е онова, което доказва `--cap-drop ALL`: `revisor` работи като `65532` и неговият `CapEff` би бил нула, дори да не махнеш нищо; таванът обаче би бил този на четиринайсетте capabilities. Това е повече от казаното от Docker: това е онова, което ядрото налага. Неправилно написана опция би могла да остане записана, без да се приложи; `/proc` не лъже.
5. **Спирането:** `docker stop` отне **206 ms**, а кодът е `0`. `docker-init` предаде сигнала на `revisor`, `revisor` го обработи и се сбогува в логовете си. Всичко с подсилена защита, а умира точно толкова добре, колкото и без нищо.

В папката си изпълни командата от 7.10.1, изчакай няколко секунди и провери с `docker ps --filter name=curso-docker-revisor`, че казва `(healthy)`. Когато го видиш `(healthy)`, изтрий го с `docker rm -f curso-docker-revisor` **преди упражненията**, които използват това име и този порт; образът `curso-docker-revisor:1.4.0` остава за Урок 8.

### 7.11 Какво ще срещнеш в стари ръководства

- **`HEALTHCHECK CMD curl -f http://localhost/ || exit 1`.** Работи в образи, които имат *shell* и `curl`, и принуждава да ги сложиш в онези, които ги нямат. В раздел 7.4.4 видя как се проваля в минимален образ: `unhealthy` със здрава услуга. Ако програмата ти е сървър, дай ѝ подкоманда за проверка на състоянието.
- **Инсталиране на `tini` или `dumb-init` вътре в Dockerfile** и поставянето му в `ENTRYPOINT`. Беше нужно, преди Docker да има собствен *init*; днес `--init` прави същото, без да пипа образа. Все още има смисъл, ако образът ще работи на място, където не можеш да поискаш `--init`.
- **Стартов скрипт, който завършва с `revisor` вместо с `exec revisor`.** Това е формата *shell* от Урок 3, скрита във файл: *shell* остава номер 1 и сигналът не стига.
- **`--restart always` навсякъде, „за да не пада“.** Не поправя счупена програма (рестартира я отново и отново, всеки път по-късно) и не прави нищо с болна програма, която продължава да работи. Освен това, според документацията, контейнер с `always`, който си спрял нарочно, оживява, когато демонът се рестартира.
- **`--privileged`, за да „махнеш проблемите с правата“.** Това е обратното на този урок: дава на контейнера всички capabilities и достъп до устройствата на компютъра. Справочникът на `docker run` обяснява, че по подразбиране Docker маха най-опасните capabilities, като `CAP_SYS_ADMIN`; `--privileged` ги връща всичките. Ако програма има нужда от capability — `--cap-add` с името ѝ.

## Грешката, която ще видиш

Този урок има една основна грешка и две, които се появяват с нея.

**Основната грешка: проверката на състоянието, която не може да се изпълни.** Тази от `fig07_03.sh`:

```text
Up 4 seconds (unhealthy)
-1 "OCI runtime exec failed: exec failed: unable to start container process: exec: \"/bin/sh\": stat /bin/sh: no such file or directory"
```

Чете се така. `-1` не е код на програмата: това е Docker, който казва, че дори не е успял да започне проверката. `OCI runtime exec failed` казва кой се е провалил — компонентът, който изпълнява процеси вътре в контейнера. А краят казва какво е търсил и не е намерил: `/bin/sh`. Проверката е била във формата *shell* (или е подадена с `--health-cmd`, което е същото), а образът няма *shell*. Поправя се с проверка във формата *exec*, която извиква програма, каквато образът наистина има: `HEALTHCHECK CMD ["/revisor", "healthcheck"]`. Ако вместо `/bin/sh` съобщението казва `curl`, образът има *shell*, но няма `curl`; поправката е същата. И преди да обвиниш програмата, попитай я ти: `docker exec <контейнер> /revisor healthcheck`. Ако отговори `sano`, проблемът е в проверката, а не в услугата.

**Онази, която се появява с нея: само за четене.** Тази от `fig07_06.sh`:

```text
{"error":"no pude guardar el reporte: open /tmp/.reporte-<n>.tmp: read-only file system"}
 [500]
```

`read-only file system` го казва ядрото: контейнерът работи с `--read-only`, а програмата се е опитала да пише. Въпросът, който я решава, е „къде пише програмата ми и защо?“. Ако е нещо временно — `--tmpfs` в тази папка; ако трябва да трае — том (Урок 8). Което не е поправка: да махнеш `--read-only`.

**Кодът, който издава лошо спиране: `137` след `docker stop`.** Ако `docker stop` трае целия срок и оставя `ExitCode=137`, сигналът не е послужил на процес номер 1: или по средата има *shell* (Урок 3), или това е програма, която не е инсталирала обработчик (7.1.4). Погледни `docker top`, за да разбереш кой е номер 1, и `SigCgt`, за да разбереш какво обработва. Ако не можеш да промениш програмата — `--init`.

## Навикът за сигурност на урока

**Контейнерът работи с минимума: файлова система само за четене, нула capabilities и без придобиване на привилегии, а в `/proc` се проверява, че ядрото го прилага.** Това са три опции, които се пишат заедно (`--read-only --cap-drop ALL --security-opt no-new-privileges`), и една проверка, която се прави веднъж за всеки образ. Всяка отнема по една стъпка на онзи, който успее да поеме контрола над процеса чрез пробив в програмата: не може да пише на диска, няма нито една от разделените сили на `root` и не може да стане `root`, като изпълни програма със *setuid*. Произшествието, което предотвратява, не е хипотетично: почти всички начини да се мине от „контролирам процес“ към „контролирам машината“ изискват да се запише нещо, да се използва capability или да се смени потребителят. А половината, която се забравя, е втората: не стига да напишеш опциите, трябва да видиш `CapBnd: 0000000000000000` (таванът: дори `root` вътре не би могъл да получи capabilities) и `NoNewPrivs: 1`. `CapEff` равно на нула не стига като доказателство: потребител, който не е `root`, като `65532` на `revisor`, вече го има нула без `--cap-drop ALL`. Онова, което добавяш после, се добавя по име: папка с право на запис с `--tmpfs` или том, capability с `--cap-add`.

## Какво се прави погрешно

**Да скъсиш срока на `docker stop`, за да „не трае толкова“.** С `-t 2` програма, която не обработва сигнала, умира за 2 секунди вместо за 10, но умира точно толкова лошо: `137`, без да довърши онова, което е правила. Поправката е сигналът да стигне (`--init`, формата *exec*, обработчик), а не да убиват по-рано.

**Вътрешен срок за спиране, по-дълъг от този на Docker.** Ако програмата ти чака заявките си 15 секунди, а Docker ѝ дава 10, подреденото спиране никога не завършва. Нагласи едното или другото (`--stop-timeout`), но така, че да се побира.

**Да бъркаш `Up` с „работи“.** `docker ps` казва `Up`, докато процесът съществува. Ако контейнерът няма `HEALTHCHECK`, никой не пита дали обслужва.

**Проверка на състоянието, която зависи от други услуги.** Ако състоянието на `revisor` зависеше от услугите, които проверява, чужд срив би го направил `unhealthy`. Проверката пита за собствения процес.

**Скъпа проверка.** Изпълнява се на всеки няколко секунди през целия живот на контейнера. Цяла заявка към база данни или цял отчет на всеки десет секунди е натоварване, което никой не е поискал.

**Да очакваш, че `--restart` ще излекува контейнер `unhealthy`.** Никоя политика не гледа състоянието. Видя го в 7.5: серия от четири провала, нула рестартирания.

**Да махнеш `--read-only`, защото „програмата трябва да пише“.** Програмата трябва да пише на **едно** място. Дай ѝ това място по име.

**`--privileged` или `--cap-add ALL`, за да се измъкнеш набързо.** Разваля целия урок. Ако нещо иска capability, разбери коя и добави само нея.

**Да вярваш на казаното от `docker inspect`, без да погледнеш в `/proc`.** `docker inspect` показва какво си поискал. `/proc/<pid>/status` показва какво прилага ядрото. Обикновено съвпадат; когато не, решава ядрото.

## Упражнения

Прави ги поред. Преди да изпълниш всяко, запиши в [дневника](bitacora.md) какво мислиш, че ще стане; сравнението след това е половината от ученето. Накрая изтрий онова, което си създал: всичко има префикса `curso-docker-`.

### Упражнение 1 — Разчети края

Без да изпълняваш нищо, кажи какъв `ExitCode` оставя всеки контейнер и колко приблизително би траял `docker stop`, когато е приложимо. Използвай таблицата от 7.1.2.

1. `revisor` 1.4.0, работещ правилно, спрян с `docker stop`.
2. Образът на Go, изпълняващ `sleep 300`, без `--init`, спрян с `docker stop`.
3. Същият, с `--init`, спрян с `docker stop`.
4. `revisor` 1.4.0 без `REVISOR_SERVICIOS`, без политика за рестартиране.
5. `revisor` 1.4.0, работещ правилно, прекратен с `docker kill`.
6. Контейнер `(unhealthy)`, чийто лог на проверките казва `-1 "OCI runtime exec failed: ..."`. Какъв код има **контейнерът**?

### Упражнение 2 — Колко време му трябва, за да се разболее?

С образа `curso-docker-prueba:1.0.0` от Урок 2 предскажи колко време му трябва, за да стане `unhealthy`, на контейнер, който стартира в неработещ режим с тези опции, и колко е серията му от провали в този момент:

```bash
docker run -d --name curso-docker-prueba -e PRUEBA_MODO=caido \
  --health-interval 2s --health-retries 5 --health-start-period 1ms \
  curso-docker-prueba:1.0.0
```

След това го измери: питай на всеки половин секунда с `docker inspect --format '{{.State.Health.Status}}' curso-docker-prueba` и брой секундите от стартирането. Опциите `--health-*` на `docker run` променят тези на образа за този контейнер. Изтрий го с `docker rm -f curso-docker-prueba` и повтори с `--health-start-period 0s`. Преди да го изпълниш, предскажи: трае ли същото? Подсказка: прочети отново точка 2 от 7.4.4. Накрая — `docker rm -f curso-docker-prueba`.

### Упражнение 3 — Друг сигнал за спиране (проект)

Ако контейнерът от 7.10 още работи, изтрий го първо с `docker rm -f curso-docker-revisor`. След това стартирай образа си с друг сигнал за спиране:

```bash
docker run -d --name curso-docker-revisor -p 127.0.0.1:8080:8080 --stop-signal SIGINT \
  -e REVISOR_SERVICIOS='propio http://127.0.0.1:8080/salud' curso-docker-revisor:1.4.0
```

Преди да го спреш, предскажи три неща: какво ще каже логът му при спиране (`docker logs curso-docker-revisor`), с какъв код ще завърши и какъв сигнал ще покаже `docker inspect --format '{{.Config.StopSignal}}' curso-docker-revisor`. След това го спри с `docker stop curso-docker-revisor`, измери времето с `time` и сравни. Подсказка: виж кои сигнали обработва `revisor` в 7.1.1. Допълнителен въпрос: какво би станало със `--stop-signal SIGHUP`, сигнал, който кодът на `revisor` не е поискал? Накрая — `docker rm -f curso-docker-revisor`.

### Упражнение 4 — Подсили защитата на тестовата услуга

Стартирай тестовата услуга с опциите с подсилена защита от 7.10.1 (без порта и без `-e`, които не ѝ трябват):

```bash
docker run -d --name curso-docker-prueba \
  --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped \
  curso-docker-prueba:1.0.0
```

Преди това предскажи: ще стигне ли до `healthy`? Трябва ли ѝ `--tmpfs`? Кой ще е номер 1 и с какъв потребител? С какъв код ще завърши, когато я спреш? После провери с `docker ps --filter name=curso-docker-prueba`, `docker top curso-docker-prueba -o pid,user,args`, `docker stop curso-docker-prueba`, `docker inspect --format '{{.State.ExitCode}}' curso-docker-prueba` и `docker logs curso-docker-prueba`. Накрая — `docker rm -f curso-docker-prueba`.

## Решения

Решения 2, 3 и 4 са измерени с два скрипта, които правят същото като упражненията, с помощни имена `fig07` и без публикуване на портове: `fig07_08.sh` (тестова услуга) и `fig07_09.sh` (`revisor`).

### Решение 1

1. **`0`**, за десети от секундата: `revisor` обработва `SIGTERM` и излиза сам (7.4.4).
2. **`137`**, за малко над 10 секунди: `sleep` е номер 1, няма обработчик, сигналът се пренебрегва и накрая идва `SIGKILL` (7.1.4).
3. **`143`**, за десети от секундата: `docker-init` препраща сигнала, `sleep` вече не е номер 1 и умира с действието по подразбиране на `SIGTERM`, 128 + 15 (7.3.2).
4. **`1`**: `revisor` приключва сам, със собствения си код за грешка, без някой да му изпраща нищо. `docker stop` не е приложим: вече е спрян.
5. **`137`**: `docker kill` изпраща `SIGKILL`, без да чака. И ако имаше политика `always`, нямаше да стартира отново, защото се брои за ръчно спиране (7.6.2).
6. **Никакъв**, защото контейнерът продължава да работи: `unhealthy` е етикет, а не смърт. `-1` е кодът на **проверката**, а не на контейнера. Неговият `.State.ExitCode` е `0`, докато работи.

### Решение 2

```bash
#!/usr/bin/env bash
# fig07_08.sh — Las soluciones de los Ejercicios 2 y 4, con el servicio de prueba:
# cuánto tarda en enfermarse con otros tiempos de salud, y cómo corre con las
# opciones endurecidas de la lección.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-prueba:1.0.0
# ni tu contenedor curso-docker-prueba, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}prueba:fig07"
NOMBRE="${PREFIJO}prueba-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../servicio-prueba" "$TRABAJO/servicio-prueba"
docker build -q -t "$IMAGEN" "$TRABAJO/servicio-prueba" >/dev/null

t() { date +%s%3N; }
esperar_salud() {
  for _ in $(seq 120); do
    [ "$(docker inspect --format '{{.State.Health.Status}}' "$NOMBRE")" = "$1" ] && return 0
    sleep 0.5
  done
  echo "(no llegó a $1)"; return 1
}

for arranque in 0s 1ms; do
  echo "== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period $arranque"
  inicio=$(t)
  docker run -d --name "$NOMBRE" -e PRUEBA_MODO=caido \
    --health-interval 2s --health-retries 5 --health-start-period "$arranque" "$IMAGEN" >/dev/null
  esperar_salud unhealthy; fin=$(t)
  echo "pasó a unhealthy a los $(( (fin - inicio) / 100 ))00 ms de arrancar"
  docker inspect --format 'racha={{.State.Health.FailingStreak}} StartPeriod={{.Config.Healthcheck.StartPeriod}}' "$NOMBRE"
  docker rm -f "$NOMBRE" >/dev/null
  echo
done

echo "== Ejercicio 4: el servicio de prueba con las opciones endurecidas"
docker run -d --name "$NOMBRE" --read-only --cap-drop ALL --security-opt no-new-privileges --init \
  --memory 64m --cpus 0.5 --pids-limit 50 --restart unless-stopped "$IMAGEN" >/dev/null
esperar_salud healthy
docker ps --filter "name=^${NOMBRE}\$" --format '{{.Status}}'
docker top "$NOMBRE" -o pid,user,args | sed -E 's/^ *[0-9]+ /<pid> /'
inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
echo "docker stop tardó $(( fin - inicio )) ms; $(docker inspect --format 'ExitCode={{.State.ExitCode}}' "$NOMBRE")"
docker logs "$NOMBRE" 2>&1
```

```text
$ ./fig07_08.sh
== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 0s
pasó a unhealthy a los 13400 ms de arrancar
racha=5 StartPeriod=5s

== Ejercicio 2: modo caído, revisión cada 2 s, 5 fallas, --health-start-period 1ms
pasó a unhealthy a los 10900 ms de arrancar
racha=5 StartPeriod=1ms

== Ejercicio 4: el servicio de prueba con las opciones endurecidas
Up 5 seconds (healthy)
PID                 USER                COMMAND
<pid>             65532               /sbin/docker-init -- /servicio-prueba
<pid>             65532               /servicio-prueba
docker stop tardó 234 ms; ExitCode=0
servicio-prueba escuchando en :9000 en modo sano
servicio-prueba: GET / en modo sano
servicio-prueba: recibí terminated, apagando
```

С `--health-start-period 1ms` стана `unhealthy` на **10.9 секунди**, с `racha=5`. Сметката е 5 провала с 2 секунди между проверките, 10 секунди, плюс онова, което отнема всяка проверка (изпълнението на процес вътре в контейнера не е безплатно). Серията е точно толкова, колкото поиска в `--health-retries`: състоянието се сменя точно на провал номер 5.

С `--health-start-period 0s` отне **13.4 секунди**, а редът на `docker inspect` казва защо: `StartPeriod=5s`. Нула в опция `--health-*` на `docker run` не изключва нищо; означава „използвай тази на образа“, а Dockerfile на тестовата услуга казва `--start-period=5s`. През тези 5 секунди Docker пита на всеки `--start-interval` (5 s), така че първата проверка дойде на 5-ата секунда, а следващите — на всеки 2: на 5, 7, 9, 11 и 13. Петият провал се пада на 13-ата. Ако предвиждането ти беше „около десет секунди“ за първия и „около тринайсет“ за втория, разбрал си сметката и капана. Точните времена се променят от изпълнение до изпълнение; сериите — не.

### Решение 3

```bash
#!/usr/bin/env bash
# fig07_09.sh — La solución del Ejercicio 3: el revisor con otra señal de apagado.
# SIGINT, que el revisor atiende, y SIGHUP, que no pidió, sin y con --init.
set -euo pipefail
PREFIJO="${PREFIJO:-curso-docker-}"
# Nombres de apoyo con «fig07»: el guion nunca toca tu curso-docker-revisor:1.4.0
# ni tu contenedor curso-docker-revisor, y al salir borra solo lo que creó.
AQUI="$(cd "$(dirname "$0")" && pwd)"
TRABAJO="$(mktemp -d)"
IMAGEN="${PREFIJO}revisor:fig07"
NOMBRE="${PREFIJO}revisor-fig07"
trap 'docker rm -f "$NOMBRE" >/dev/null 2>&1 || true; docker rmi -f "$IMAGEN" >/dev/null 2>&1 || true; rm -rf "$TRABAJO"' EXIT

cp -R "$AQUI/../revisor/." "$TRABAJO/"
cp "$AQUI/estado/.dockerignore" "$TRABAJO/"
cp "$AQUI/fig07_01.Dockerfile" "$TRABAJO/Dockerfile"
cd "$TRABAJO"
docker build -q --build-arg VERSION=1.4.0 -t "$IMAGEN" . >/dev/null

t() { date +%s%3N; }
SERVICIOS='propio http://127.0.0.1:8080/salud'

for prueba in "SIGINT" "SIGHUP" "SIGHUP --init"; do
  set -- $prueba
  echo "== --stop-signal $1 ${2:-sin --init}"
  docker run -d --name "$NOMBRE" --stop-signal "$1" ${2:-} -e REVISOR_SERVICIOS="$SERVICIOS" "$IMAGEN" >/dev/null
  sleep 1
  inicio=$(t); docker stop "$NOMBRE" >/dev/null; fin=$(t)
  echo "docker stop tardó $(( fin - inicio )) ms"
  docker inspect --format 'ExitCode={{.State.ExitCode}} StopSignal={{.Config.StopSignal}}' "$NOMBRE"
  docker logs "$NOMBRE" 2>&1 | grep -v 'GET /salud'
  docker rm -f "$NOMBRE" >/dev/null
  echo
done
```

```text
$ ./fig07_09.sh
== --stop-signal SIGINT sin --init
docker stop tardó 102 ms
ExitCode=0 StopSignal=SIGINT
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
revisor: recibí interrupt, apagando
revisor: apagado limpio

== --stop-signal SIGHUP sin --init
docker stop tardó 72 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))

== --stop-signal SIGHUP --init
docker stop tardó 87 ms
ExitCode=129 StopSignal=SIGHUP
revisor 1.4.0 escuchando en :8080 (1 servicio(s))
```

Със `SIGINT`: `interrupt` е начинът, по който Go нарича `SIGINT`, както `terminated` е `SIGTERM`. `revisor` е инсталирал обработчик и за двата, така че спира еднакво добре с всеки от тях: код `0`, за милисекунди. `--stop-signal` е записан в конфигурацията на контейнера (`StopSignal=SIGINT`) и печели пред `STOPSIGNAL SIGTERM` на образа.

Допълнителен въпрос, със `SIGHUP`: умря за милисекунди с `ExitCode=129` (128 + 1), без и с `--init`, а логът му остава на `escuchando`, без `apagando` и без `apagado limpio`. Не изчака 10-те секунди, макар без `--init` да е номер 1, защото всяка програма на Go има фабрично вграден обработчик за този сигнал: документацията на Go казва, че „`SIGHUP`, `SIGINT` или `SIGTERM` карат програмата да приключи“ ([os/signal](https://pkg.go.dev/os/signal)). Има обработчик, така че сигналът стига; но този фабричен обработчик прекратява програмата рязко, без подреденото спиране, което `revisor` прави само при `SIGTERM` и `SIGINT`. Това, че кодът излиза `129` и когато `revisor` е номер 1, зависи от начина, по който *runtime*-ът на Go прекратява програмата; това измери Docker 29.2.1 с Go 1.27.3. Практическото правило не се променя: сигналът за спиране се избира, като се гледа кодът, а `STOPSIGNAL` го оставя записан.

### Решение 4

Това е последният блок на `fig07_08.sh`. Стига до `healthy` без `--tmpfs`, защото тестовата услуга не записва никакъв файл. Номер 1 е `docker-init`, а детето му е услугата, и двата с `65532`, потребителя, който задава нейният Dockerfile. Спира за десети от секундата с `0`: обработва `SIGTERM`, като `revisor`. Това е същият ред опции, който Урок 8 слага на тестовата услуга, когато я вкарва във вътрешна мрежа, и затова там вече няма да се налага да мислиш за него.

## Как разбирам, че съм успял

Отбележи всяка точка само ако можеш да я направиш, **без да поглеждаш отново текста**:

- [ ] В папката ти `docker image inspect --format '{{json .Config.Healthcheck}}' curso-docker-revisor:1.4.0` показва `["CMD","/revisor","healthcheck"]` с `Interval` от десет секунди.
- [ ] Обясняваш за една минута защо `sleep 300` умира от `SIGTERM` в терминала ти, но не и като номер 1 в контейнер, като използваш думите *обработчик*, *действие по подразбиране* и *номер 1*.
- [ ] Измерваш `docker stop` на `sleep` без и с `--init` и получаваш малко над 10 секунди със `137` и десети от секундата със `143`.
- [ ] Виждаш зомби с `ps --ppid` на компютъра си и обясняваш защо `docker top` не го показва.
- [ ] Слагаш тестовата услуга в неработещ режим и разчиташ в `docker inspect` `running / unhealthy`, серията от провали и причината `GET / respondió 503`, с нула рестартирания.
- [ ] Казваш какво правят `no`, `on-failure:3`, `always` и `unless-stopped`, когато процесът умре сам, когато го спреш с `docker stop` и когато демонът се рестартира.
- [ ] Стартираш `revisor` с опциите от 7.10.1, стига до `(healthy)` и в `/proc/<pid на revisor>/status` разчиташ `CapBnd: 0000000000000000` и `NoNewPrivs: 1` (и обясняваш защо `CapEff` равно на нула не доказва нищо при потребител, който не е `root`).
- [ ] Предизвикваш `read-only file system` с `REVISOR_REPORTE=/tmp/reporte.json` и го поправяш с `--tmpfs` с фиксиран размер, без да махаш `--read-only`.
- [ ] Пускаш скриптовете от [`programas/07-salud-y-ciclo-de-vida/`](../programas/07-salud-y-ciclo-de-vida) (с друг `PUERTO`, ако твоите са заети) и изходите ти съвпадат с тези от урока, с изключение на милисекундите, секундите на `Up` и на чаканията и скритите числа. А накрая `docker ps -a --filter name=curso-docker-` не показва контейнери от този урок.

## Обобщение

Отговори, без да гледаш урока:

1. Какво е сигнал и с какво се различават `SIGTERM` и `SIGKILL`?
2. Как се разчита `ExitCode` със стойност `137`? А `143`? А `0` след `docker stop`?
3. Защо процесът номер 1 в контейнер не умира от `SIGTERM`, ако не е инсталирал обработчик?
4. Какво прави `docker stop` стъпка по стъпка и с кои опции променяш срока и сигнала му?
5. Кои две задачи изпълнява `--init` и защо курсът го използва с `revisor`, макар днес да не му е нужен?
6. Какво означават кодовете `0`, `1` и `2` на проверката на състоянието и какво означава `-1` в лога ѝ?
7. Защо проверката на `revisor` е подкоманда на същия двоичен файл, а не `curl`?
8. Какво прави Docker с контейнер `unhealthy`? А политиката за рестартиране?
9. С какво се различават `always` и `unless-stopped`?
10. Какво променят `--read-only`, `--cap-drop ALL` и `--security-opt no-new-privileges` и къде проверяваш, че ядрото ги прилага?

## Източници

Всички проверени на 21 октомври 2026 г.

- [signal(7)](https://man7.org/linux/man-pages/man7/signal.7.html): сигналите `SIGINT`, `SIGKILL` и `SIGTERM`, номерата им и действията им по подразбиране, и че `SIGKILL` и `SIGSTOP` не могат да бъдат уловени, блокирани, нито пренебрегнати.
- [pid_namespaces(7)](https://man7.org/linux/man-pages/man7/pid_namespaces.7.html): процесът *init* на едно пространство от имена получава само сигналите, за които има обработчик, освен `SIGKILL` и `SIGSTOP` от пространство предшественик; и сирачетата стават негови деца.
- [capabilities(7)](https://man7.org/linux/man-pages/man7/capabilities.7.html): какво са capabilities, определенията на `CAP_CHOWN`, `CAP_DAC_OVERRIDE`, `CAP_KILL`, `CAP_SETUID` и `CAP_NET_BIND_SERVICE`, таванът (*bounding set*) и какво получава програма *setuid* на `root`.
- [Linux, „No New Privileges Flag“](https://docs.kernel.org/userspace-api/no_new_privs.html): какво прави `no_new_privs` с `execve`, битовете *setuid* и *setgid*, и че се наследява и не може да бъде изключен.
- [`docker container stop`](https://docs.docker.com/reference/cli/docker/container/stop/): `SIGTERM` и след това `SIGKILL`, срокът от 10 секунди в Linux, `-t`, `-s` и `-t -1`.
- [`docker container kill`](https://docs.docker.com/reference/cli/docker/container/kill/): че по подразбиране изпраща `SIGKILL`.
- [Справочник на `docker run`](https://docs.docker.com/reference/cli/docker/container/run/): `--init` и `docker-init`, PID 1, който пренебрегва сигналите с действие по подразбиране, `--stop-signal`, `--stop-timeout`, `--read-only`, `--tmpfs`, `no-new-privileges`, опциите `--health-*`, нарастващото чакане между рестартиранията и какво маха Docker по подразбиране в сравнение с `--privileged`.
- [Справочник на Dockerfile](https://docs.docker.com/reference/dockerfile/): `HEALTHCHECK` (опции, стойности по подразбиране, кодове 0, 1 и 2, по един на Dockerfile, `NONE`, 4096 байта изход) и `STOPSIGNAL`.
- [Docker, „Start containers automatically“](https://docs.docker.com/engine/containers/start-containers-automatically/): четирите политики за рестартиране и ръчното спиране.
- [Docker, „tmpfs mounts“](https://docs.docker.com/engine/storage/tmpfs/): че `tmpfs` живее в паметта и изчезва с контейнера, максималният му размер по подразбиране и правата му `1777`.
- [tini](https://github.com/krallin/tini): минималният *init* зад `docker-init`: едно-единствено дете, събиране на зомбита и препращане на сигнали.
- [os/signal](https://pkg.go.dev/os/signal): че програма на Go по подразбиране приключва при `SIGHUP`, `SIGINT` или `SIGTERM`.
- [moby/moby #41030](https://github.com/moby/moby/pull/41030): промяната, която задава `net.ipv4.ip_unprivileged_port_start=0` по подразбиране в контейнерите, от Docker 20.10 нататък.
- [Docker Engine 29, бележки към версиите](https://docs.docker.com/engine/release-notes/29/): версиите и датите от „За изпълненията“.
- [Colima](https://github.com/abiosoft/colima): инструментът, с който програмите са изпълнени на macOS.

### Термини от този урок

| | |
|---|---|
| **capability** | едно от парчетата, на които Linux разделя властта на `root`; махат се с `--cap-drop` и се добавят с `--cap-add` |
| **код на изход** | числото, с което приключва един процес; 128 + *n*, ако го е прекратил сигнал *n* |
| **`HEALTHCHECK`** | инструкция, която казва на Docker как да пита един контейнер дали е здрав |
| ***init*** | процесът номер 1; с `--init` — миниатюрна програма, която препраща сигнали и събира зомбита |
| **обработчик** (*handler*) | функция, която програмата инсталира, за да обработи сигнал вместо действието по подразбиране |
| **`no-new-privileges`** | флаг на ядрото, който не позволява на процес да придобие привилегии, когато изпълни друга програма |
| **срок** (на `docker stop`) | колко чака Docker между `SIGTERM` и `SIGKILL`; 10 секунди по подразбиране |
| **политика за рестартиране** | какво прави демонът, когато процесът на контейнер приключи |
| **сигнал** | кратко известие от ядрото към процес, идентифицирано с число |
| ***setuid*** | бит на изпълним файл, който го кара да работи с потребителя собственик на файла |
| **`tmpfs`** | папка, която живее в паметта и изчезва с контейнера |
| **зомби** | процес, който вече е приключил и чака родителят му да прочете кода му на изход |

---

**Следващ:** [Урок 8 — Томове и мрежи](08-volumenes-y-redes.md)
