<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# ViewModels

## Purpose
`ObservableObject`-классы, реализующие UI-логику для Views. Три вьюмодели (`CreatePairViewModel`, `OnboardingViewModel`, `PairDetailViewModel`) находятся в таргете `MacyadCore` и могут тестироваться без UI-зависимостей. Две вьюмодели (`AppModel`, `SettingsViewModel`) находятся в таргете `Macyad` — они используют `AppKit`-типы или связывают несколько Domain-сервисов и не могут быть включены в framework без усложнения. Все классы аннотированы `@MainActor`.

## Key Files

| File | Target | Description |
|------|--------|-------------|
| `AppModel.swift` | Macyad (app) | Центральная вьюмодель приложения: навигация (`sidebarSelection`), список пар и аккаунтов, события активности, `statusSummary` для MenuBar; содержит замыкания-команды (`openMainWindow`, `presentIssueReviewWindow` и др.), которые `MacyadApp` назначает при старте |
| `SettingsViewModel.swift` | Macyad (app) | Управляет настройками (`AppPreferences`): язык, автозапуск, расписание; управляет аккаунтами Yandex через `AccountService`; через `languageDidChange` уведомляет `AppModel` о смене языка |
| `CreatePairViewModel.swift` | MacyadCore | Форма создания/редактирования `SyncPair`: хранит черновик полей, вызывает `FolderPicking.pickFolder()`, строит финальный `SyncPair` через `PairService.makePair()` / `updatePair()` |
| `OnboardingViewModel.swift` | MacyadCore | Обёртка над `OnboardingServicing`: публикует `OnboardingState`, управляет флагом `isRefreshing`, копирует команды в буфер обмена через `PasteboardWriting` |
| `PairDetailViewModel.swift` | MacyadCore | Лёгкая вьюмодель детальной панели пары: публикует `operationPhase` (`.idle` / `.queued` / `.running`), `latestSeverity`, `lastErrorMessage`; обновляется извне через сеттеры |

## For AI Agents

### Working In This Directory
- `CreatePairViewModel`, `OnboardingViewModel` и `PairDetailViewModel` — публичные (`public`) типы в `MacyadCore`; изменение их интерфейса требует проверки всех мест использования в таргете `Macyad`.
- `AppModel` и `SettingsViewModel` — `internal` типы таргета `Macyad`; не импортируют `MacyadCore`-протоколы напрямую — только конкретные типы из `MacyadCore`.
- Зависимости инжектируются через инициализатор (не через синглтоны). `FolderPicking` и `PasteboardWriting` — протоколы из `MacyadCore`, что позволяет тестировать `CreatePairViewModel` и `OnboardingViewModel` с моками.
- `AppModel` содержит замыкания-команды (`var openMainWindow: () -> Void = {}`); `MacyadApp` назначает их в `configureAppModel()`. Не вызывай UIKit/AppKit напрямую из `AppModel`.
- Обновление `AppModel.pairs`, `accounts` и `activityEvents` происходит только через `applyPersistedState(...)` — не мутируй их по отдельности из `BackgroundSyncController`.

### Testing Requirements
- `CreatePairViewModel`, `OnboardingViewModel`, `PairDetailViewModel` — тестируются в `MacyadTests/ViewModels/` с мок-реализациями протоколов `FolderPicking`, `PasteboardWriting`, `OnboardingServicing`.
- `AppModel` и `SettingsViewModel` — тестируются вручную через `./script/build_and_run.sh`; для изоляции I/O используй `AppLaunchMode.uiTestReadyState`.

### Common Patterns
- Все классы помечены `@MainActor final`; async-операции запускаются через `Task { ... }` внутри синхронных методов.
- Локализованные строки берутся через `AppCopy(language: language)` или `AppCopy.current` — не используй строковые литералы напрямую.
- `SettingsViewModel.languageDidChange` — коллбэк, а не Combine-паблишер: `AppModel` регистрирует его при старте в `MacyadApp.configureAppModel()`.
- `PairDetailViewModel.operationPhase` обновляется снаружи (из `PairSyncCoordinator`/Views) через `setOperationPhase(_:)` и `setOperationInFlight(_:)`.

## Dependencies

### Internal
- `MacyadCore` — `SyncPair`, `YandexAccount`, `OnboardingState`, `ActivityEvent`, `AppPreferences`, `PairService`, `AccountService`, `AppCopy`, `AppPaths`, `RcloneCommandBuilder`
- `App/AppRouter.swift` — `AppRoute`, `SidebarSelection` (используется в `AppModel`)
- `PlatformAdapters/PasteboardBridge.swift` — конкретная реализация `PasteboardWriting`, инжектируется через `AppEnvironment`

### External
- `Combine` — `ObservableObject`, `@Published`
- `AppKit` — `NSWindow` (только в `AppModel.presentIssueReviewWindow`)
- `Foundation` — `UUID`, `Date`, `URL`

<!-- MANUAL: -->
