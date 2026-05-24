# Design: Macyad MVP Menu Bar Sync App For Yandex Disk On macOS

> [!WARNING]
> Этот документ сохранён как исторический артефакт раннего `MVP`-подхода на `Tauri`/`React`.
> Он больше не является актуальным design source of truth для репозитория.
> Актуальный нативный дизайн находится в [2026-05-24-macyad-native-swift-rewrite-design.md](2026-05-24-macyad-native-swift-rewrite-design.md).

## Контекст

Пользователь хочет получить трудоспособное приложение для macOS, которое заменяет нативный клиент Yandex Disk в конкретном рабочем сценарии:

- синхронизируются только выбранные папки;
- приложение живёт в `menu bar`;
- сначала пользователь вручную подтягивает данные `Yandex -> Mac`;
- дальше приложение по расписанию выполняет `Mac -> Yandex` push;
- если на стороне Yandex есть опасные пересечения с локальными изменениями, push должен останавливаться;
- при необходимости повторного `Yandex -> Mac` pull это действие запускается вручную;
- в первом релизе нужен один Yandex account, но приложение должно быть пригодно для установки не только на один личный Mac, а для небольшого круга пользователей.

Исходное исследование по теме уже показало, что `rclone` является наиболее реалистичной технической основой для такого продукта, но его встроенные модели `sync` и особенно `bisync` не совпадают один-в-один с желаемым пользовательским сценарием.

## Реальная цель

Построить не просто GUI-обёртку над `rclone`, а предсказуемое `menu bar` приложение-оркестратор, которое:

1. управляет одной или несколькими sync-парами внутри собственного workspace;
2. использует `rclone` как engine выполнения transfer-операций;
3. сохраняет безопасную модель работы:
   - `manual pull` из Yandex;
   - `scheduled push` в Yandex;
   - отдельная проверка remote drift;
   - жёсткая остановка при опасных коллизиях;
4. с первого релиза закладывает международную основу UI минимум для `ru` и `en`.

## Целевая аудитория

### Основная аудитория MVP

- технически уверенные пользователи macOS;
- небольшая команда или круг знакомых пользователей;
- люди, которым нужен рабочий sync-процесс для выбранных папок, но не нужен полный нативный клиент Yandex Disk.

### Не целевая аудитория MVP

- массовый consumer rollout;
- пользователи, которым нужен Finder-like cloud browser для всего диска;
- пользователи, ожидающие “магический” real-time bidirectional sync без понимания конфликтов и ограничений.

## Success Criteria

Изменение считается успешным, если пользователь может:

1. установить приложение на macOS и запустить его как `menu bar app`;
2. пройти onboarding:
   - подключить уже существующий `rclone remote`, либо
   - установить/подхватить `rclone` и создать app-managed remote;
3. создать sync-пару внутри managed workspace приложения;
4. вручную выполнить первичный `Yandex -> Mac` import;
5. дальше автоматически выполнять `Mac -> Yandex` push по фиксированному расписанию;
6. отдельно запускать `Check Yandex` и `Pull From Yandex`;
7. видеть в UI и уведомлениях различие между `info`, `warning` и `alarm`;
8. получать жёсткую блокировку scheduled push при `alarm`;
9. использовать UI минимум на `ru` и `en`.

## Подтверждённые продуктовые решения

Ниже перечислены решения, подтверждённые в рамках brainstorming-сессии.

| Тема | Зафиксированное решение |
|---|---|
| Scope релиза | `single-account MVP` |
| Распространение | приложение должно быть пригодно для небольшой команды / нескольких пользователей |
| Локальная модель | только managed workspace приложения |
| Sync engine | внешний `rclone`, но приложение помогает с установкой и подключением |
| Daily mode | manual initial pull, далее scheduled `Mac -> Yandex` push |
| Remote side | приложение может отдельно проверять Yandex на изменения, но не делает auto-pull |
| Severity model | `info`, `warning`, `alarm` |
| Stop rule | push обязан останавливаться при `alarm` |
| Onboarding | guided setup + attach existing remote |
| GUI | минимальный рабочий `menu bar` UI, более богатые экраны идут в roadmap |
| Фоновая работа | фиксированное расписание + ручные действия |
| Delete policy | настраиваемая; по умолчанию локальные удаления зеркалятся в Yandex, полагаясь на корзину Yandex |
| `rclone` config | отдельный app-managed config/profile |
| Установка `rclone` | гибридный режим: использовать уже установленный, `Homebrew`, либо скачать managed binary |
| Уведомления | внутри приложения для всех событий, системные `macOS notifications` минимум для `warning` и `alarm` |
| Языки UI | минимум `ru` и `en` с первого релиза |

## Внешние технические факты, которые были дополнительно проверены

Ниже перечислены только те внешние факты, на которые реально опирается design.

- У `rclone` есть официальный backend `Yandex Disk`, а документация явно описывает настройку remote, работу с путями, поддержку modification times и нативную поддержку `MD5`: [rclone.org/yandex](https://rclone.org/yandex/)
- `rclone bisync` официально помечен как advanced command и требует аккуратного использования, особенно вокруг `--resync` и recovery semantics: [rclone.org/bisync](https://rclone.org/bisync/), [rclone.org/commands/rclone_bisync](https://rclone.org/commands/rclone_bisync/)
- Yandex предоставляет `WebDAV API`, но в этом design он не выбирается как primary transport, потому что `rclone yandex` backend лучше совпадает с целевой моделью приложения: [yandex.com/dev/disk/webdav](https://yandex.com/dev/disk/webdav/?version=1)
- `Tauri 2` официально позиционируется как desktop framework с любым frontend stack и Rust logic, что делает его актуальным кандидатом для такого класса приложений: [tauri.app](https://tauri.app/), [v2.tauri.app/develop](https://v2.tauri.app/develop/)

## Рекомендуемый продуктовый подход

### Отклонённые подходы

#### 1. `Bisync-centric`

Использовать `rclone bisync` как основную ежедневную модель.

Почему отклонено:

- плохо совпадает с требованием “push по расписанию, pull вручную”;
- слишком сильно переносит продуктовые правила в поведение `bisync`;
- усложняет прозрачную модель `info / warning / alarm`;
- делает UX восстановления зависимым от внутренней логики `bisync`, а не от предсказуемых правил продукта.

#### 2. Полностью кастомный sync engine

Сразу писать собственный diffing/sync engine поверх Yandex API/WebDAV.

Почему отклонено для MVP:

- слишком дорого по времени;
- резко повышает correctness burden;
- откладывает выход рабочего приложения без достаточной пользы для первого релиза.

### Принятый подход

`Push-centric controller`.

Приложение само владеет state machine и safety rules, а `rclone` используется как execution engine:

- для `pull`, `push`, listing и проверки состояния;
- без делегирования ему продуктовых решений уровня “когда sync можно продолжать” и “что считать опасной коллизией”.

Это лучший баланс между:

- скоростью выхода в рабочий MVP;
- безопасностью;
- предсказуемостью;
- возможностью дальше наращивать функциональность.

## Границы MVP

### Входит в MVP

- один Yandex account;
- isolated app-managed `rclone` config;
- managed workspace приложения;
- onboarding с guided setup и attach existing remote;
- ручной `Yandex -> Mac` import;
- scheduled `Mac -> Yandex` push;
- отдельный `Check Yandex`;
- `info / warning / alarm`;
- stop-on-alarm;
- `menu bar` dropdown;
- detail-view sync-пары;
- `ru` и `en`.

### Не входит в MVP

- multiple accounts;
- automatic conflict resolution;
- intelligent merge UI;
- rich history center;
- advanced diagnostics center;
- real-time watcher-triggered sync;
- Finder extension;
- полноценный cloud browser для всего Yandex Disk;
- smart sync / selective offline model а-ля full cloud client.

## Архитектура приложения

Приложение проектируется как resident `menu bar app`, которое запускается при логине пользователя и держит scheduler в собственном процессе. Отдельный background helper или отдельный `launchd` sync-daemon в MVP не вводится.

### Почему именно так

- пользователь и так хочет приложение, которое “живёт в menu bar”;
- это упрощает reasoning о состоянии системы;
- это уменьшает количество фоновых процессов и hidden execution paths в первом релизе;
- если пользователь явно выгружает приложение, фоновые sync-задачи тоже прекращаются, что предсказуемо.

### Компоненты

#### 1. `Menu Bar Host`

Отвечает за:

- status icon;
- dropdown UI;
- переход в detail-view и settings;
- ручные действия пользователя.

`Menu Bar Host` не содержит sync-логики сам по себе.

#### 2. `Sync Controller`

Главный orchestration-слой.

Отвечает за:

- жизненный цикл sync-пар;
- запуск push/pull/check сценариев;
- lock management;
- принятие решения, можно ли выполнять push;
- обновление состояния после операций;
- публикацию событий в UI и notification subsystem.

#### 3. `Rclone Adapter`

Изолированный слой интеграции с `rclone`.

Отвечает за:

- поиск существующего `rclone`;
- скачивание managed binary при необходимости;
- работу с app-managed config;
- валидацию remote;
- запуск команд;
- нормализацию stdout/stderr/log output в типизированные результаты приложения.

#### 4. `Workspace Manager`

Отвечает за:

- создание и поддержку managed workspace, например `~/Macyad/`;
- создание локальных каталогов sync-пар;
- защиту от выхода в произвольные системные папки в MVP;
- открытие конкретной локальной папки по user action.

#### 5. `Remote Drift Checker`

Отдельный сервисный слой.

Отвечает за:

- сравнение текущего remote state с baseline;
- классификацию отклонений как `info`, `warning` или `alarm`;
- выдачу результата для scheduler decision.

#### 6. `State Store`

Локальное хранилище состояния и метаданных приложения.

#### 7. `Notification Service`

Отвечает за:

- системные `macOS notifications` для `warning` и `alarm`;
- нормализованные сообщения для UI;
- дедупликацию шумных уведомлений.

#### 8. `Localization Layer`

Обязательный инфраструктурный слой с первого релиза.

Отвечает за:

- `ru`/`en` словари;
- fallback rules;
- локализацию frontend и backend user-facing messages.

## Жизненный цикл sync-пары

### 1. Создание sync-пары

Пользователь выбирает:

- логическое имя пары;
- remote path внутри Yandex;
- локальную папку внутри managed workspace;
- расписание push;
- delete policy.

На этом этапе приложение валидирует remote и локальный каталог, но ещё не выполняет обычный push-loop.

### 2. Initial Pull

Пользователь вручную запускает `Pull From Yandex`.

Цель:

- заполнить локальную папку из Yandex;
- зафиксировать начальный baseline;
- перевести пару в “operational” состояние.

### 3. Сохранение baseline

После успешного initial pull приложение сохраняет:

- локальный snapshot;
- remote snapshot;
- время последнего manual pull;
- хэш/метаданные baseline;
- текущую policy-конфигурацию.

### 4. Scheduled Push Cycle

Дальше по расписанию выполняется такой цикл:

1. scheduler будит sync-пару;
2. controller проверяет, нет ли lock и незавершённого прошлого запуска;
3. drift checker сравнивает текущий Yandex state с baseline;
4. если нет `alarm`, controller строит push-plan;
5. `rclone adapter` выполняет `Mac -> Yandex` push;
6. при успехе baseline и last-run metadata обновляются.

### 5. Manual Pull After MVP Start

Повторный `Yandex -> Mac` pull не выполняется автоматически. Это всегда отдельное осознанное действие пользователя.

## Conflict Model И Severity Semantics

### Общий принцип

Система должна различать не просто “что-то изменилось”, а разную степень риска для автоматического push.

### `Info`

Определение:

- на стороне Yandex были изменения после последнего manual pull;
- при этом нет явного признака прямого конфликта по одному и тому же объекту.

MVP-реакция:

- событие видно внутри приложения;
- push не блокируется только из-за `info`;
- системное уведомление не обязательно.

### `Warning`

Определение:

- есть заметный общий drift между workspace и Yandex в рамках sync-пары;
- это уже attention-worthy состояние;
- но нет доказанного same-object collision.

MVP-реакция:

- системное уведомление показывается;
- sync-пара помечается как требующая внимания;
- push ещё может продолжаться, если нет `alarm`.

### `Alarm`

Определение:

- изменения с обеих сторон затрагивают один и тот же объект;
- либо существует прямой риск перезаписи без однозначно безопасного решения.

MVP-реакция:

- scheduled push блокируется полностью;
- системное уведомление обязательно;
- пользователь должен вручную выбрать дальнейшее действие.

### Явная техническая граница MVP

В MVP same-object collision определяется по относительному пути внутри sync-пары и сопоставимым file metadata (`size`, `modtime`, `checksum`, когда доступен). Система не пытается интеллектуально распознавать сложные rename/move equivalence scenarios между сторонами.

Следствие:

- сложные rename/edit кейсы могут попадать в `warning` или `alarm` более консервативно;
- это допустимо для MVP, потому что безопасность и предсказуемость важнее “умной магии”.

### Scheduler Policy Matrix

| Уровень | Что показываем | Можно ли продолжать scheduled push |
|---|---|---|
| `Info` | внутренний журнал, статус пары | да |
| `Warning` | журнал + system notification + attention state | да, если нет `alarm` |
| `Alarm` | журнал + system notification + explicit blocked state | нет |

## Delete Policy

Delete policy должна настраиваться для каждой sync-пары отдельно.

### Default policy

По умолчанию:

- локальные удаления зеркалятся в Yandex;
- приложение не включает hard delete режим;
- удалённые объекты должны попадать в корзину Yandex по обычной семантике удалений.

Это соответствует пользовательскому ожиданию, что Yandex не удаляет такие файлы окончательно мгновенно.

### Допустимые policy варианты в MVP

1. `Mirror deletions to Yandex` — default.
2. `Do not propagate deletions automatically`.
3. `Require confirmation before propagating deletions`.

Внутренняя реализация конкретных command-paths остаётся задачей implementation plan, но продуктовая семантика фиксируется уже здесь.

## Onboarding И Установка `rclone`

### Принцип

Приложение не требует от пользователя заранее идеально подготовленного CLI environment.

### Поддерживаемые сценарии

#### 1. `rclone` уже установлен

Приложение находит бинарник и предлагает использовать его.

#### 2. Есть `Homebrew`

Приложение может провести пользователя через guided install flow с использованием `Homebrew`.

#### 3. `rclone` отсутствует

Приложение может скачать managed binary в своё контролируемое расположение.

### Безопасность onboarding flow

Даже если пользователь подключает “уже существующий remote”, приложение не должно работать напрямую поверх shared user `rclone.conf`.

Принятый принцип:

- приложение использует свой отдельный config;
- attach existing remote означает импорт или пересоздание нужной конфигурации внутрь app-managed profile;
- продукт не должен зависеть от побочных изменений в общем `rclone`-конфиге пользователя.

## Data Model И State Store

В качестве state store выбирается `SQLite`.

### Почему `SQLite`

- достаточно для локального single-user desktop app;
- удобно хранить structured metadata;
- легко делать миграции схемы;
- не требует отдельного сервера и минимален по операционным рискам.

### Минимальные сущности

#### `app_settings`

- UI language;
- start at login;
- default scheduler interval;
- diagnostic preferences;
- preferred `rclone` binary mode.

#### `accounts`

- один активный account в MVP;
- metadata remote/profile;
- auth validity state.

#### `sync_pairs`

- id;
- user-visible name;
- local relative path in workspace;
- remote path;
- schedule;
- delete policy;
- enabled/disabled flag;
- last known severity.

#### `pair_baselines`

- sync_pair_id;
- last successful manual pull timestamp;
- last successful push timestamp;
- saved local snapshot reference;
- saved remote snapshot reference;
- current baseline version.

#### `pair_events`

- sync_pair_id;
- event type;
- severity;
- timestamp;
- localized summary key;
- diagnostic payload reference.

#### `pair_runs`

- sync_pair_id;
- run type (`pull`, `push`, `check`);
- start/end timestamps;
- result state;
- normalized error code;
- log artifact reference.

### Snapshot representation

MVP не обязан хранить полный content-index файлов в richly queryable human-facing форме, но обязан хранить достаточно metadata, чтобы:

- понимать, когда baseline устарел;
- сравнивать local/remote state;
- классифицировать drift;
- восстанавливать reasoning по событиям.

Точная структура snapshot serialization определяется implementation plan.

## GUI И UX

### Основная повседневная поверхность: `menu bar dropdown`

Dropdown должен быть коротким и operational.

Он обязан показывать:

- глобальный статус приложения;
- время следующего push;
- quick actions:
  - `Sync Now`
  - `Check Yandex`
  - `Pull From Yandex`
- список sync-пар;
- последние несколько событий;
- доступ к settings и detail-view.

### Sync-пары как operational cards

Каждая карточка sync-пары должна показывать:

- имя пары;
- локальный и remote путь;
- текущий severity/status;
- last push;
- next push;
- drift summary;
- delete policy.

### Detail-view sync-пары

Detail-view должен отвечать на вопросы:

- что именно произошло;
- почему push идёт или блокируется;
- когда были последний pull и push;
- какие объекты попали в проблему;
- какие ручные действия доступны сейчас.

### Сознательное ограничение MVP

В MVP не добавляется тяжёлый `conflict center` и не создаётся полноценный merge UI.

Detail-view нужен для:

- прозрачности;
- диагностики;
- безопасного ручного следующего шага.

## Internationalization (`i18n`)

### Обязательное требование

С первого релиза приложение проектируется минимум с двумя локалями:

- `ru`
- `en`

### Что обязательно локализуется

- menu bar UI;
- onboarding;
- настройки;
- status labels;
- notification texts;
- error messages;
- recovery hints;
- detail-view descriptions.

### Что не переводится автоматически

- имена sync-пар, заданные пользователем;
- пути;
- raw `rclone` output;
- технические identifiers;
- code-like entities и product names там, где перевод ухудшает точность.

### Языковое поведение

Явное решение для MVP:

- приложение пытается выбрать язык по system locale;
- если system locale = `ru`, используется `ru`;
- если system locale = `en`, используется `en`;
- в остальных случаях fallback идёт в `ru` как project default;
- пользователь может переключить язык вручную в settings.

### Архитектурное правило

Ни frontend, ни backend не должны хранить user-facing тексты как raw strings в продуктовой логике. Все сообщения проходят через localization keys и словари.

## Рекомендуемый Tech Stack

### Выбранный стек

- `Tauri 2` как desktop shell;
- `Rust` как core/backend язык;
- `TypeScript + Vite + React` как UI-слой;
- `SQLite` как state store.

### Почему это рекомендуемый стек

#### Почему `Tauri 2`

- подходит для desktop utility app;
- поддерживает web-based UI и Rust core;
- даёт хороший баланс между desktop integration и скоростью доставки продукта;
- лучше совпадает с split “thin UI + strong orchestration backend”, чем чисто browser-like подход.

#### Почему `Rust` core

- удобен для process orchestration;
- хорошо подходит для typed state machine и error modeling;
- логично сочетается с `Tauri`.

#### Почему `React` UI

- достаточно зрелый и предсказуемый слой для menu bar/dropdown/detail UI;
- ускоряет разработку нескольких состояний интерфейса;
- хорошо вписывается в Tauri workflow.

#### Почему не `Electron`

- heavier runtime without clear compensating benefit for this specific MVP.

#### Почему не рекомендован чистый `Swift/SwiftUI` по умолчанию

Он остаётся допустимым вариантом, но в этом design не выбирается как базовая рекомендация, потому что:

- orchestration и CLI/process integration здесь играют большую роль;
- `Tauri + Rust` даёт более ровный split между UI и core-logic для первого релиза.

## Планировщик И Фоновая Модель

### Принятое решение

В MVP используется resident app model:

- приложение запускается как `menu bar app`;
- по настройке запускается при логине;
- scheduler живёт в процессе приложения;
- если пользователь осознанно завершает приложение, автоматические scheduled runs прекращаются.

### Почему это важно

Такой подход делает поведение понятным:

- приложение работает — sync идёт;
- приложение выгружено — sync не идёт.

В MVP не нужен отдельный скрытый background daemon.

## Error Handling Model

### Классы ошибок

#### 1. `Setup Errors`

- `rclone` не найден;
- managed install не удался;
- remote не сконфигурирован;
- app-managed config повреждён.

#### 2. `Runtime Sync Errors`

- push/pull/check завершился неуспешно;
- lock уже занят;
- предыдущий run завис или остался в неопределённом состоянии;
- Yandex недоступен.

#### 3. `Conflict-State Errors`

- обнаружен `alarm`;
- push был сознательно остановлен правилами продукта.

#### 4. `User-Actionable Warnings`

- remote drift;
- stale baseline;
- manual pull давно не делался;
- invalid pair config.

### UX-принцип обработки ошибок

Пользователю показывается не raw CLI output как основной интерфейс, а нормализованное сообщение:

- что произошло;
- что это значит;
- что можно сделать дальше.

Raw logs сохраняются для диагностики, но не являются primary UX surface.

## Testing Strategy

### 1. Unit Tests

- классификация `info / warning / alarm`;
- schedule decision logic;
- delete policy behavior;
- lock semantics;
- language fallback;
- event normalization.

### 2. Integration Tests

- `rclone adapter`;
- app-managed config behavior;
- onboarding flows;
- initial pull;
- scheduled push;
- blocked push.

### 3. Scenario Tests

- healthy pair;
- remote drift без same-object collision;
- same-object collision с blocked push;
- missing `rclone`;
- broken remote auth;
- user re-runs manual pull after drift;
- `ru`/`en` UI messages на ключевых сценариях.

### 4. Manual macOS QA

- menu bar behavior;
- start at login;
- notifications;
- quitting/relaunching app;
- workspace opening;
- managed binary and existing binary flows.

## Roadmap

### Следующий этап после MVP

- richer detail screens;
- conflict center;
- local-change-triggered push with debounce;
- более гибкие scheduler settings;
- richer diagnostics and logs;
- multiple accounts.

### Более дальний этап

- advanced recovery assistant;
- richer run history;
- smarter rename/conflict heuristics;
- improved binary/update management for `rclone`;
- more powerful policy controls per pair.

## Риски И Ограничения

### Product risks

- модель `push by default, pull manually` остаётся менее “магической”, чем у полноценных cloud clients;
- пользователи могут ожидать auto-resolution, которого MVP сознательно не даёт.

### Technical risks

- корректная классификация `warning` vs `alarm` может быть нетривиальной;
- Yandex/rclone edge cases могут потребовать более консервативного поведения;
- background lifecycle на macOS требует внимательной проработки startup/relaunch semantics.

### Deliberate limitations

- нет automatic merge;
- нет smart rename intelligence;
- нет multiple accounts;
- нет arbitrary local folders outside managed workspace.

Эти ограничения приняты сознательно ради предсказуемости первой версии.

## Assumptions

1. Пользователь согласен работать внутри managed workspace приложения.
2. Автоматический daily mode важнее полного bidirectional real-time поведения.
3. Безопасность и прозрачность важнее автоматической “магии”.
4. Двух локалей `ru/en` достаточно как архитектурной основы первого релиза.
5. Если приложение выгружено пользователем, остановка scheduler acceptable for MVP.

## Acceptance Criteria Для Дизайна

Design считается валидным, если implementation plan сможет на его основе построить приложение, которое:

1. живёт в `menu bar`;
2. работает с одним Yandex account;
3. использует isolated app-managed `rclone` profile;
4. выполняет manual initial pull;
5. выполняет scheduled push;
6. отдельно умеет `Check Yandex`;
7. различает `info / warning / alarm`;
8. блокирует scheduled push на `alarm`;
9. поддерживает `ru` и `en`;
10. не требует от пользователя понимать внутренние детали `rclone`, чтобы пользоваться основным UX.

## Итоговая рекомендация

Строить `Macyad MVP` нужно как `menu bar orchestration app`, а не как thin wrapper вокруг `rclone bisync`.

Ключевая формула релиза:

`manual initial pull` + `scheduled push` + `separate drift check` + `stop on alarm` + `isolated app-managed rclone profile` + `ru/en i18n from day one`.
