<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Views/Shell

## Purpose
Навигационная оболочка приложения. `MainWindowView` — единственная точка сборки полного UI главного окна: `NavigationSplitView` (sidebar + content + optional inspector), оркестрация sync-операций, модальные листы (создание пары, подтверждение удаления) и обработка результатов операций. `MenuBarPopoverView` — компактный popover menu bar, отображающий статус, последние события и кнопки быстрых действий для активной пары.

## Key Files
| File | Description |
|------|-------------|
| MainWindowView.swift | Главная оболочка окна: `NavigationSplitView` с sidebar (список пар + app-routes), content area (PairDetailView / OnboardingView / overview), управление операциями Push/Pull/Check через `PairOperationKind`; определяет `ActivityReviewApplyResult` |
| MenuBarPopoverView.swift | Компактный menu bar popover: статус-сводка, кнопки Push/Pull/Check для активной пары (`controlSize(.small)`), список последних событий |

## For AI Agents

### Working In This Directory
- `MainWindowView` — единственная вьюха, которая запускает sync-операции и управляет их очередью (`PairOperationKind`); не перемещай эту логику в `PairDetailView` или ViewModel.
- `NSWindow`/AppKit-интеграция (если нужна) должна идти через `PlatformAdapters/WindowAccessor`, а не напрямую в Shell-вьюхах.
- `MenuBarPopoverView` работает в контексте `StatusBarBridge` (PlatformAdapters) — размер popover фиксирован; не добавляй сложные layout-элементы, требующие динамической высоты.
- `AppRoute.allCases` определяет порядок секций в сайдбаре — изменения маршрутизации требуют обновления `App/AppRouter.swift`.
- `ActivityReviewApplyResult` объявлен в `MainWindowView.swift` — при перемещении в Domain обновляй импорты во всех потребителях.
- Результат прогона (ручной, разбор файлов) пишется через `recordRunResult`, а не `replacePair`: он сливает поля результата на текущую пару (`SyncPair.withRunResult(of:)`) за один шаг на MainActor. Прогон держит копию пары с момента постановки в очередь — записав её целиком, он откатил бы правки, сделанные пока он ждал. `replacePair` — только для прямых правок пары.
- «Push All» / «Проверить все» на Overview (`runForAllPairs`) ставят каждую подходящую пару через тот же `run(_:for:)` в общую очередь; отбор — `OverviewViewModel.bulkRunPairs` (занятые пропускаются, Push — без Auto-Pull). Пары помечаются занятыми сразу, иначе двойной клик ставит всё дважды.
- Ручная операция пишет событие журнала **дважды**: `run(_:for:)` сохраняет запись с `inFlightOperation` до старта работы и заменяет её (`activityRepository.replace`, тот же `id`) результатом или ошибкой. Не возвращай `append` в финальные ветки — иначе на одну операцию появится два события, а прерванный прогон снова не оставит следа. `loadPairsIfNeeded()` при старте прогоняет `recoverInterruptedEvents` и закрывает записи, оставшиеся «в полёте» от прошлого запуска.

- Статус локальной папки пары (`appModel.localFolderStatuses`) проверяется один раз при загрузке пар (все пары), при выборе пары и после сохранения пары — без опроса по таймеру. `adoptMovedFolder()` записывает новый путь и свежий bookmark из `.moved`. Проверка идёт через `environment.localFolderChecker`; в UI-тестовых режимах это `Noop`, чтобы сид-пары с выдуманными путями не получали предупреждений.

### Testing Requirements
Ручное тестирование через `./script/build_and_run.sh`. Проверять: открытие Settings, sidebar-навигация, запуск Push/Pull/Check, появление popover из menu bar. UI-тесты — `MacyadUITests/`.

### Common Patterns
- `NavigationSplitView` с тремя колонками (sidebar / content / inspector через `PairDetailView`).
- `PairOperationKind` enum с `queueLabel` для последовательного выполнения операций.
- `@Environment(\.openSettings)` для открытия Settings-окна.
- `@State private var createPairViewModel` инициализируется в `MainWindowView` и передаётся в `CreatePairSheetView`.
- Menu bar popover использует `controlSize(.small)` для компактных кнопок действий.

## Dependencies

### Internal
`ViewModels/AppModel`, `ViewModels/CreatePairViewModel`, `Domain/Models/SyncPair`, `Domain/Models/ActivityEvent`, `Domain/Models/ActivityIssueSet`, `App/AppRouter`, `PlatformAdapters/FolderPickerBridge`; `Views/Pairs/*`, `Views/Activity/*`, `Views/Onboarding/OnboardingView`

### External
SwiftUI, AppKit (через PlatformAdapters), MacyadCore

<!-- MANUAL: -->
