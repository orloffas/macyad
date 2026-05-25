# MacYaD UI Design Principles

## Product posture

MacYaD — это native macOS utility для синхронизации локальных папок с Yandex Disk через `menu bar` и главное окно управления.

Приложение должно ощущаться как профессиональный системный инструмент, а не как web dashboard или mobile-first оболочка.

Оптимизируем под:

- скорость
- ясность
- keyboard-first workflows
- information density
- быстрое сканирование состояния
- низкий visual noise
- предсказуемое поведение окна, `Dock` и `menu bar`

Не оптимизируем под:

- marketing presentation
- oversized touch targets
- большие пустые отступы как самоцель
- onboarding-heavy flows
- web dashboard familiarity

## Architecture direction

`SwiftUI` — основной UI layer.

`AppKit` разрешён только как узкий и явный bridge для поведения, которое `SwiftUI` не моделирует достаточно надёжно:

- `menu bar` / `NSStatusItem`
- `NSWindow` lifecycle и activation policy
- file/folder pickers
- responder-chain и другие system integration edges

Нельзя размывать границу и переносить целые экраны в `AppKit` без явной причины.

## Copy and language

Project-wide default language — русский.

User-facing copy, документация и UI labels должны быть на русском, если только English wording не нужен для точности или не является устоявшимся product term.

Названия действий должны быть явными и однообразными:

- `Push to Yandex`
- `Pull from Yandex`
- `Check Yandex`

Не использовать несколько конкурирующих названий для одной и той же операции.

## Shell and launch behavior

MacYaD — это единое приложение с `menu bar` utility shell и главным окном управления.

Обязательные ожидания:

- `menu bar` icon и `Dock` icon должны быть визуально согласованы и не мигать разными glyph во время launch, reopen, close и quit
- first foreground launch должен открывать главное окно осознанно и без лишнего flicker
- фоновая scheduled/manual activity не должна самовольно вытаскивать главное окно на передний план
- red close button скрывает главное окно, но не завершает `menu bar` utility
- явный quit выполняется только через пользовательскую команду завершения приложения
- не должно быть неожиданных permission prompts до явного user intent, если архитектурно этого можно избежать

## Canonical references

Качество и характер интерфейса сверяем с:

- Xcode
- TablePlus
- Raycast
- Nova
- Panic Transmit
- Tailscale
- VMware Fusion

Если новый экран не выглядит совместимым с этим семейством приложений, значит решение дрейфует в неверную сторону.

## Layout system

Главная форма приложения по умолчанию:

- sidebar + content + inspector

Предпочтения:

- split views
- resizable columns
- compact toolbars
- inline actions рядом с выбранной сущностью
- secondary detail в inspector или `sheet`, а не в случайных всплывающих паттернах

Избегать:

- single-column mobile composition на широком окне
- giant hero sections
- full-card dashboards как основной layout
- фиксированных коротких блоков там, где данные должны занимать доступную высоту окна

## Density and spacing

Интерфейс должен быть плотным, но читаемым.

Правила:

- показывать полезную информацию без лишнего скролла
- усиливать иерархию раньше, чем добавлять воздух
- держать row heights и controls компактными, если контент не требует иного
- использовать стандартную macOS typography вместо раздутых заголовков
- уменьшать padding раньше, чем добавлять ещё один контейнер

## Navigation and interaction

Предпочтения:

- keyboard-first navigation
- predictable selection model
- inspector-based secondary detail
- contextual menus
- command shortcuts для частых действий
- inline affordances для `Push to Yandex`, `Pull from Yandex` и `Check Yandex`

Критичные действия не должны быть спрятаны за hover-only или многослойной навигацией.

Warnings и alarms должны объясняться из UI в один клик, без необходимости читать внешний лог-файл вручную.

## Data presentation

Для operational data:

- предпочитать rows, lists и panes вместо декоративных cards
- держать status рядом с той сущностью, к которой он относится
- использовать monospaced text для путей, команд, timestamp и `rclone` logs, когда это помогает чтению
- activity events должны хранить как минимум severity, timestamp, краткий summary и подробности
- warning/alarm events должны сохранять полный `rclone` stderr/log, когда он доступен
- activity retention по умолчанию ограничивается окном в 48 часов, если отдельное product decision не задаёт другое правило

## Menu bar guidance

`Menu bar` popover должен открываться мгновенно и оставаться компактным.

Предпочтения:

- actionable first screen
- одна очевидная quick action группа для активной пары
- короткий recent activity block
- компактные grouped sections вместо длинного dashboard

Избегать:

- oversized popovers
- deep navigation stacks
- длинных scroll-heavy экранов
- расплывчатых action labels вроде просто `Pull`, когда нужен контекст `Pull from Yandex`

## Anti-patterns

Не ship'ить интерфейсы, похожие на:

- generic SaaS admin template
- Notion-style card canvas
- Electron dashboard с гигантскими отступами
- tablet UI, растянутый до desktop
- декоративный градиент как структурную основу layout

Также избегать:

- focus stealing во время background actions
- несогласованного поведения `Dock` и `menu bar`
- состояния, где warning/error есть, но его причина не видна из UI

## Review checklist

Перед принятием UI change спросить:

- Это ощущается как native macOS app, а не web-first оболочка?
- Достаточно ли информации видно сразу без лишнего скролла?
- Не стоит ли заменить cards на rows, panes или inspector?
- Быстрые действия находятся рядом с выбранной парой?
- Можно ли открыть warning/error и увидеть полные details и log?
- Предсказуемо ли ведут себя launch, close, reopen, `Dock` и `menu bar`?
- Удобно ли это keyboard-first пользователю?
