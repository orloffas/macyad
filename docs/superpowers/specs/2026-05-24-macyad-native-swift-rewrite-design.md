# Design: Macyad Native Swift Rewrite

## Контекст

Текущая версия `Macyad` собрана как `Tauri`-приложение с `React` UI и `Rust` backend. По итогам ручного тестирования и UX-оценки пользователь подтвердил, что текущий интерфейс и shell-поведение не подходят для целевого продукта:

- onboarding зависает на шаге после подключения `rclone` и не даёт явного действия `Проверить снова`;
- создание `pair` непонятно и спрятано в неудачную inline-форму;
- отсутствует цельный нативный `macOS` shell;
- нет ожидаемого поведения окна, `Dock`, `menu bar` и copy-to-clipboard affordances;
- часть проектной документации и артефактов всё ещё остаётся на английском языке;
- текущий визуальный язык воспринимается как неудачный web-first UI, а не как native `macOS` приложение.

На этом фоне пользователь выбрал не incremental migration, а полный rewrite:

- полностью отказаться от `Tauri`;
- полностью отказаться от `Rust`-слоя;
- переписать приложение целиком на `Swift` и `SwiftUI`;
- считать новую версию `clean start`, без автоматической миграции данных из старого приложения.

## Цель rewrite

Построить нативное `macOS` приложение, которое:

1. ощущается как профессиональный desktop utility, а не web shell;
2. стартует в фоне и живёт в `menu bar`, но имеет полноценное главное окно;
3. использует `SwiftUI` как основной UI и state layer;
4. допускает только узкий `AppKit` bridge для конкретных native-возможностей;
5. сохраняет продуктовую модель `Macyad` вокруг `rclone`, `pair`, `check/pull/push`, scheduler и severity;
6. в первой нативной версии сразу закрывает branding, UX и documentation-polish замечания.

## Зафиксированные продуктовые решения

| Тема | Зафиксированное решение |
|---|---|
| Технологический стек | Полный rewrite на `Swift` без `Tauri` и без `Rust` |
| Старт состояния | `clean start`, без data migration |
| UI-стратегия | `SwiftUI-first + narrow AppKit bridge` |
| Shell-модель | `Dock app + menu bar helper` |
| Поведение после onboarding | Приложение стартует в фоне, живёт в `menu bar`, окно открывается по требованию |
| Scope первой нативной версии | `parity + cleanup docs/branding` |
| Роль `AppKit` | Только точечные `PlatformAdapters`, без расползания в feature UI |

## Архитектурный подход

### Почему не `Pure SwiftUI`

Чистый `SwiftUI` был бы привлекательнее по простоте, но product requirements включают несколько типично `macOS`-специфичных возможностей:

- `menu bar` integration;
- управление `Dock`/window lifecycle;
- закрытие окна без выхода из процесса;
- потенциальные bridges для native таблиц, pasteboard и responder-chain behavior.

Эти требования слишком легко превращают “чистый `SwiftUI`” в серию хрупких workarounds.

### Почему не `AppKit shell + SwiftUI inside`

Полностью `AppKit`-centric shell дал бы максимальный контроль, но для данного scope это лишняя сложность:

- выше support burden;
- больше imperative glue-кода;
- слабее maintainability;
- выше риск, что `AppKit` начнёт определять архитектуру всего продукта.

### Принятый подход

Выбран `SwiftUI-first + narrow AppKit bridge`:

- основной UI и state живут в `SwiftUI`;
- продуктовая логика, domain и infrastructure пишутся на `Swift`;
- `AppKit` используется только в отдельных adapter-файлах внутри `PlatformAdapters`;
- `SwiftUI` остаётся владельцем state, а `AppKit` является реализационной деталью.

## Архитектурные принципы

1. `SwiftUI` — default слой для screen composition, navigation и state ownership.
2. `AppKit` — только узкий bridge под конкретную `macOS`-capability.
3. `import AppKit` не появляется в feature views, `ViewModels`, `Domain` и `Infrastructure`.
4. Source of truth состояния остаётся в `SwiftUI`/`ViewModels`, а не в bridge-слое.
5. `PlatformAdapters` решают ровно одну platform-задачу каждый.
6. `AppDelegateBridge` не превращается в `god object`.
7. `rclone`-интеграция не размазывается по UI, а живёт в отдельном сервисном слое.

## Целевая структура проекта

```text
Macyad
├─ App
│  ├─ MacyadApp.swift
│  ├─ AppRouter.swift
│  └─ AppEnvironment.swift
├─ Views
│  ├─ Shell
│  ├─ Onboarding
│  ├─ Pairs
│  ├─ Activity
│  └─ Settings
├─ ViewModels
├─ Domain
│  ├─ Models
│  ├─ Services
│  ├─ UseCases
│  └─ Policies
├─ Infrastructure
│  ├─ Persistence
│  ├─ Process
│  ├─ Filesystem
│  ├─ Notifications
│  └─ Scheduling
└─ PlatformAdapters
   ├─ AppDelegateBridge.swift
   ├─ StatusBarBridge.swift
   ├─ WindowAccessor.swift
   ├─ TableViewBridge.swift
   └─ PasteboardBridge.swift
```

## Information Architecture

Новая нативная версия состоит из трёх основных поверхностей.

### 1. `Menu bar`

Это быстрый operational surface, а не второй полноразмерный интерфейс.

В `menu bar popover` живут:

- общий health/status;
- summary по `Healthy/Warning/Alarm`;
- `Open Main Window`;
- быстрые действия `Sync Now`, `Check Yandex`, `Pull From Yandex`;
- 3-5 последних событий;
- быстрый доступ к `Settings` и `Quit`.

Там не живут:

- создание `pair`;
- длинные формы;
- полноценный onboarding flow;
- deep diagnostics;
- многослойная навигация.

### 2. `Main window`

Это основной рабочий интерфейс приложения.

Рекомендуемый layout: `NavigationSplitView` с тремя ролями:

- sidebar: список `pair`, onboarding state, системные разделы;
- detail: состояние выбранной `pair`, действия, schedule, пути, последние результаты;
- optional inspector: технические детали, события, drift explanation, logs.

Главное окно должно решать основную UX-проблему текущей версии: пользователь должен понимать, где создаётся и как управляется `pair`, без скрытых форм и web-like card layout.

### 3. `Settings`

`Settings` выносится в отдельную `Settings` scene. Это отдельная preference surface, а не вкладка внутри operational UI.

Там живут:

- язык;
- launch behavior;
- launch at login;
- default schedule;
- notifications policy;
- `rclone` integration policy;
- support/debug information.

## Screen model и user flows

### Запуск приложения

После завершённого onboarding приложение:

- стартует в фоне;
- поднимает `menu bar` icon;
- держит scheduler;
- не открывает главное окно автоматически;
- позволяет открыть окно по требованию из `menu bar`, `Dock` или command-path.

Если onboarding не завершён:

- `menu bar` показывает заметный статус `Setup required`;
- действие по умолчанию переводит пользователя в главное окно на onboarding-секцию.

### Onboarding

Onboarding строится как desktop-first flow внутри главного окна, а не как mobile-like wizard.

Ключевые шаги:

1. Проверка наличия `rclone`.
2. Если `rclone` не найден:
   - показать `brew install rclone`;
   - показать кнопку copy;
   - показать кнопку `Проверить снова`.
3. Если `rclone` найден:
   - показать источник (`system` / `managed`);
   - перевести к следующему шагу.
4. Подключение remote:
   - guided setup, либо
   - attach существующего config/remote.
5. Переход к созданию первой `pair`.

Onboarding state должен быть сохраняемым: пользователь может закрыть окно и вернуться позже.

### Создание `pair`

Создание `pair` делается first-class сценарием:

- отдельный `sheet`, либо dedicated detail-state в главном окне;
- обязательные поля:
  - `Pair name`
  - локальная папка через `folder picker`
  - `remote path`
  - `schedule`
  - `delete policy`
- рядом показывается compact summary того, что будет происходить.

После сохранения:

- новая `pair` появляется в sidebar;
- она становится выбранной;
- пользователь попадает в detail view этой `pair`.

### Main window workflow

Главное окно вокруг выбранной `pair` показывает:

- health/severity;
- `Sync Now`;
- `Check Yandex`;
- `Pull From Yandex`;
- `schedule`;
- `local path` / `remote path`;
- `last run` / `next run`;
- короткое объяснение текущего состояния.

Inspector показывает:

- последние события;
- drift details;
- технические детали ошибок и предупреждений.

### Menu bar workflow

`Menu bar popover` должен открываться быстро и быть компактным.

Он нужен для:

- мгновенного понимания состояния;
- запуска high-value ручных действий;
- быстрого открытия главного окна.

Он не должен пытаться заменить основное окно.

### Window behavior

Красная кнопка закрывает окно, но не завершает процесс.

После закрытия:

- приложение остаётся в фоне;
- `menu bar` icon остаётся доступным;
- scheduler и notifications продолжают работать.

## UX и branding-исправления, которые обязательно входят в первую нативную версию

Следующие замечания входят в scope первой реализации и не считаются “потом polish”:

1. Исправить onboarding для `rclone`:
   - добавить `Проверить снова`;
   - сделать `brew install rclone` copyable;
   - дать понятный state transition после обнаружения `rclone`.
2. Сделать создание `pair` явным и понятным desktop flow.
3. Добавить `Dock` icon.
4. Добавить `menu bar` icon.
5. Исправить `bundle identifier` с `com.orloff.macyad` на `me.orloff.macyad`.
6. Переименовать product-facing app name из `Macyad` в `MacYaD` во всех user-facing местах native версии.
7. Сделать copy affordance для команд и подобных значений с нативным visual feedback.
8. Исправить close behavior: закрытие окна не должно завершать приложение.
9. Привести project docs и QA-артефакты к русскому default, включая текущие английские документы вроде `qa-macyad-mvp-checklist.md`.

## App lifecycle и scene model

`MacyadApp.swift` остаётся `SwiftUI`-entry point.

Внутри app shell должны жить:

- главное окно через `WindowGroup`;
- `Settings`;
- `menu bar` surface;
- `AppEnvironment`, инжектируемый в UI.

`AppDelegateBridge` используется только там, где `SwiftUI` сам по себе недостаточен:

- coordination между `Dock`, `menu bar` и окнами;
- launch/activation behavior;
- close-window-without-quit behavior;
- отдельные lifecycle edge cases.

## State model

Рекомендуется три уровня состояния.

### `AppState`

Глобальное состояние приложения:

- onboarding status;
- список `pair`;
- selected `pair`;
- app-wide preferences;
- summary для `menu bar`.

### Screen state

Состояние конкретных экранов:

- drafts форм;
- loading/error flags;
- inspector visibility;
- search/filter state.

### Domain state

Нормализованные модели:

- `SyncPair`;
- `SyncStatus`;
- `Severity`;
- `DriftReport`;
- `AppPreferences`.

Критичный принцип: ни один `PlatformAdapter` не должен становиться владельцем бизнес-состояния.

## Domain / Services

В domain-слое предлагаются следующие core-сервисы.

### `OnboardingService`

Отвечает за:

- проверку `rclone`;
- определение onboarding step;
- attach/create remote.

### `PairService`

Отвечает за:

- создание, обновление и удаление `pair`;
- валидацию путей, schedule и policy.

### `SyncService`

Отвечает за:

- `sync now`;
- `check yandex`;
- `pull from yandex`;
- интерпретацию результатов операций.

### `DriftService`

Отвечает за:

- анализ remote drift;
- классификацию в `info`, `warning`, `alarm`.

### `SchedulerService`

Отвечает за:

- регистрацию и запуск scheduled jobs;
- применение `stop-on-alarm` policy.

### `StatusService`

Отвечает за:

- агрегирование статуса для main window и `menu bar`.

Поверх core-сервисов допускается тонкий слой `UseCases`, чтобы UI вызывал продуктовые операции, а не набор разрозненных сервисов.

## Интеграция с `rclone`

`rclone`-слой рекомендуется разложить на отдельные роли:

- `RcloneLocator`
- `RcloneCommandBuilder`
- `RcloneProcessRunner`
- `RcloneOutputParser`
- `RcloneFacade`

Тогда `Domain` и UI работают не с shell-командами, а с typed operations:

- `detectInstallation()`
- `validateRemote()`
- `checkRemote(pair)`
- `pull(pair)`
- `push(pair)`

Это упрощает тестирование и не допускает shell-логики в `ViewModels`.

## Persistence и clean start

Так как новая версия не мигрирует старые данные, persistence можно проектировать заново под native app.

Рекомендуемые роли:

- `AppPreferencesStore`
- `PairRepository`
- `ActivityRepository`
- `WorkspaceLayoutManager`

Архитектурно важно следующее:

- хранение отделено от UI;
- workspace layout управляется централизованно;
- onboarding, `pair`, activity и settings проходят через repository/store interfaces.

## `PlatformAdapters`: где допускается `AppKit`

### `AppDelegateBridge.swift`

Для:

- launch/activation behavior;
- close-window-without-quit;
- coordination между `Dock`, окном и `menu bar`.

### `StatusBarBridge.swift`

Для:

- точечной работы со status item, если `MenuBarExtra` не даст нужного контроля.

### `WindowAccessor.swift`

Для:

- узкого доступа к `NSWindow` под точечные настройки.

### `TableViewBridge.swift`

Для:

- native table behavior, если `SwiftUI Table` окажется недостаточным по density, selection или keyboard-path.

### `PasteboardBridge.swift`

Для:

- native copy behavior и visual feedback на copy buttons.

## Что считается слишком широким bridge

Следующее запрещается архитектурно:

- `import AppKit` внутри feature views;
- `AppKit`-логика внутри `ViewModels`;
- хранение business state внутри adapters;
- превращение `AppDelegateBridge` в orchestration-центр всего приложения;
- использование `AppKit` “на всякий случай”, пока `SwiftUI` ещё не исчерпан.

## Error handling

Ошибки делятся на три группы.

### `User-actionable`

Примеры:

- `rclone` не найден;
- remote невалиден;
- локальная папка недоступна;
- конфигурация `pair` не проходит валидацию.

Для таких ошибок UI обязан показывать понятное следующее действие.

### `Operational`

Примеры:

- операция `sync` завершилась неуспешно;
- `check yandex` обнаружил drift/problem;
- scheduler пропустил запуск или не смог выполнить задачу.

Для таких ошибок:

- обновляется severity;
- пишется событие в activity stream;
- при необходимости показывается notification.

### `Internal`

Примеры:

- parse failure;
- persistence corruption;
- bridge misuse;
- internal bug.

Их нельзя скрывать за vague UI-сообщениями: нужны подробные логи и нормализованная user-facing ошибка.

## Observability

Даже первая нативная версия должна иметь минимальный structured observability layer.

Минимум:

- structured local logger;
- activity/event timeline;
- launch/session markers;
- operation ids;
- source tagging: `manual`, `scheduled`, `onboarding`.

Минимальная модель события:

- timestamp;
- operation type;
- `pair id`;
- severity;
- short summary;
- optional technical detail.

Это позволяет:

- показать последние события в `menu bar`;
- показать полный activity feed в main window/inspector;
- упростить поддержку и отладку.

## Testing strategy

### `Domain/UseCase tests`

Покрывают:

- onboarding step resolution;
- severity classification;
- `stop-on-alarm` policy;
- create/update `pair` validation;
- menu bar summary aggregation.

### `Infrastructure tests`

Покрывают:

- repository/store behavior;
- workspace layout creation;
- `rclone` command building;
- output parsing;
- scheduler behavior.

### Adapter boundary tests

Нужны только smoke-level tests для узких `PlatformAdapters`, а не гигантская матрица UI-интеграций.

### UI tests

Нужны для high-value flows:

- onboarding с missing `rclone`;
- `Проверить снова`;
- создание `pair`;
- закрытие окна без завершения приложения;
- открытие main window из `menu bar`.

## Scope первой реализации

### Входит

- новое нативное приложение на `Swift`;
- `Dock app + menu bar helper`;
- background start после onboarding;
- main window + settings + `menu bar` popover;
- onboarding с `rclone` detection, copy и `Проверить снова`;
- создание, просмотр и базовое управление `pair`;
- `Sync Now`, `Check Yandex`, `Pull From Yandex`;
- исправленное window lifecycle behavior;
- `Dock` icon и `menu bar` icon;
- корректный `bundle identifier`;
- documentation language cleanup;
- базовый event/activity stream;
- launch/login и notifications preferences.

### Не входит

- data migration из старой `Tauri`-версии;
- multiple accounts;
- advanced history center;
- complex diagnostics studio;
- rich conflict resolver;
- premature `AppKit` refactor без конкретного native-ограничения.

## Риски и ограничения

Главный риск — scope creep: желание использовать rewrite как повод “заодно улучшить всё”.

Чтобы rewrite остался поставляемым, порядок должен быть таким:

1. Собрать новый native shell и core flows.
2. Закрыть parity и branding/polish.
3. Только после этого углублять diagnostics и desktop optimizations.

Если проект начнёт расти за пределы этих границ, это уже отдельная следующая фаза, а не часть первой нативной версии.
