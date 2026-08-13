<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# App

## Purpose
Точка входа и корневая инфраструктура приложения: `@main`-структура SwiftUI, координатор запуска, DI-контейнер, навигационный роутер, метаданные бандла и файловые пути. Шесть файлов разделены между двумя таргетами: `AppPaths.swift` живёт в `MacyadCore` (тестируется без UI), остальные пять — в таргете `Macyad` (app-only). Логика начального запуска (`BackgroundSyncController`, `StatusBarBridge`, связь `AppDelegateBridge` ↔ `AppModel`) живёт в `AppCoordinator.swift` и не зависит от окна.

## Key Files

| File | Target | Description |
|------|--------|-------------|
| `MacyadApp.swift` | Macyad (app) | `@main` SwiftUI `App`; только монтаж сцен `WindowGroup` + `Settings` и подписка на объекты координатора |
| `AppCoordinator.swift` | Macyad (app) | Владелец `AppEnvironment` и `AppModel`; `start(delegate:)` из `applicationDidFinishLaunching` поднимает статус-бар, замыкания `AppModel` и фоновую синхронизацию — независимо от того, создано ли окно |
| `AppEnvironment.swift` | Macyad (app) | DI-контейнер (`ObservableObject`); `bootstrap()` собирает граф зависимостей, конструирует все репозитории и вьюмодели, предоставляет `makeBackgroundSyncController()` |
| `AppRouter.swift` | Macyad (app) | `AppRoute` enum (`.onboarding`, `.overview`) и `SidebarSelection` enum (`.route`, `.pair(UUID)`) — значения навигации для sidebar |
| `AppMetadata.swift` | Macyad (app) | Константы бандла: `bundleIdentifier`, `displayName`, `loggingSubsystem`; плюс `version` / `build` / `versionDisplay`, читаемые из `Info.plist` (источник — `MARKETING_VERSION` в `project.yml`, см. корневой `AGENTS.md`) |
| `AppPaths.swift` | MacyadCore | `Sendable`-структура с URL всех файлов хранилища (`pairsFile`, `rcloneConfigFile`, `rcloneFiltersDirectory` и др.); `live()` создаёт директории на диске, `makeForTesting(rootURL:)` использует временную директорию |

## For AI Agents

### Working In This Directory
- `AppPaths` — единственный файл директории в таргете `MacyadCore`; все остальные файлы принадлежат таргету `Macyad`. При добавлении нового файла сначала определи таргет в `project.yml`.
- `AppEnvironment` — единственное место, где конструируются `PairRepository`, `AccountRepository`, `AppPreferencesStore` и другие репозитории. Не инициализируй их в Views или ViewModels напрямую.
- Стабы для UI-тестов (`StubRcloneLocator`, `StubOnboardingService`, `NoopLoginItemService`, `NoopUserNotificationClient`) объявлены как приватные вложенные типы внутри `AppEnvironment` — не выноси их наружу.
- `AppRoute` и `SidebarSelection` — единственный источник истины навигации. Изменение активного маршрута происходит только через `AppModel.sidebarSelection`.
- Закрытие главного окна скрывает его (`NSApp.setActivationPolicy(.accessory)`), а не завершает приложение — это поведение реализовано в `AppDelegateBridge.windowShouldClose(_:)`.

### Testing Requirements
- `AppPaths` тестируется через `MacyadTests/` — используй `AppPaths.makeForTesting(rootURL:)` с `FileManager.default.temporaryDirectory`.
- `AppEnvironment.bootstrap()`, `MacyadApp`, `AppRouter` и `AppMetadata` тестируются только вручную через `./script/build_and_run.sh`; UI-тесты задействуют `AppLaunchMode.uiTestReadyState` для подмены зависимостей.

### Common Patterns
- `AppEnvironment.bootstrap()` читает `ProcessInfo.processInfo.arguments` для определения `AppLaunchMode`; передавать аргументы явно нужно только в тестах.
- Все ViewModels (`OnboardingViewModel`, `SettingsViewModel`, `PairDetailViewModel`) создаются внутри `AppEnvironment.init` — не в `MacyadApp`.
- Ничего, что обязано работать при автозапуске, не вешать на `.onAppear` контента `WindowGroup`: при старте login item'ом SwiftUI не создаёт окно, и `.onAppear` не выполняется — так приложение однажды поднялось без иконки в меню-баре и без фоновой синхронизации. Место для такого кода — `AppCoordinator.start(delegate:)`.
- `MacyadApp` передаёт `environment` и `appModel` через `@EnvironmentObject`; `settingsViewModel` и другие вложенные вьюмодели достаются из `environment` по необходимости.

## Dependencies

### Internal
- `MacyadCore` — `AppPaths`, `OnboardingViewModel`, `PairRepository`, `AccountRepository`, все Domain-типы
- `PlatformAdapters/` — `AppDelegateBridge`, `StatusBarBridge`, `WindowAccessor`, `PasteboardBridge`
- `ViewModels/` — `AppModel`, `SettingsViewModel`
- `Infrastructure/System/` — `LoginItemService`

### External
- `SwiftUI` — `App`, `WindowGroup`, `Settings`, `@StateObject`, `@NSApplicationDelegateAdaptor`
- `AppKit` — `NSApp`, `NSApplication`, `NSWindow` (через AppDelegateBridge)
- `Combine` — `ObservableObject` в `AppEnvironment`
- `Foundation` — `ProcessInfo`, `FileManager`, `URL`

<!-- MANUAL: -->
