<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-04 -->

# PlatformAdapters

## Purpose
Узкие мосты между AppKit и SwiftUI: каждый файл инкапсулирует ровно одну AppKit-концепцию (`NSStatusItem`, `NSOpenPanel`, `NSPasteboard`, `NSWindow`, `NSApplicationDelegate`, `NSWorkspace`), которую SwiftUI не моделирует надёжно. Все адаптеры находятся исключительно в таргете `Macyad` (app). Правило слоя: здесь нет целых экранов на AppKit — только точечные мосты. Полноценный UI реализуется в SwiftUI Views.

## Key Files

| File | Description |
|------|-------------|
| `AppDelegateBridge.swift` | `NSApplicationDelegateAdaptor` + `NSWindowDelegate` + `UNUserNotificationCenterDelegate`; управляет видимостью главного окна, политикой активации (`NSApp.setActivationPolicy`), иконкой в Dock и роутингом уведомлений; на старте зовёт `AppCoordinator.start(delegate:)`. Также содержит `IssueReviewWindowBridge` — управляет отдельным `NSWindow` для экрана разбора конфликтов. Содержит `openMainWindowIfMissing(after:)`: SwiftUI создаёт окно `WindowGroup` в ответ на `kAEOpenApplication` от LaunchServices, а процесс, запущенный напрямую (так делает XCUITest) или поднятый автозапуском, это событие не получает и остаётся без окна — поэтому событие досылается себе, если окно не появилось само. Тем же путём окно создаётся по требованию из `showMainWindow()`. |
| `StatusBarBridge.swift` | Создаёт и управляет `NSStatusItem` в системном меню; хостит SwiftUI-поповер (`MenuBarPopoverView`) через `NSHostingController`; изображение кнопки — `MenuBarTemplate` (Template image) |
| `FolderPickerBridge.swift` | Реализует протокол `FolderPicking` из `MacyadCore`; показывает `NSOpenPanel` и возвращает security-scoped bookmark + путь для отображения |
| `PasteboardBridge.swift` | Реализует протокол `PasteboardWriting` из `MacyadCore`; записывает строку в `NSPasteboard.general` |
| `FinderFolderOpenerBridge.swift` | Реализует локальный протокол `FolderOpening`; открывает папку в Finder через `NSWorkspace.open` (не `activateFileViewerSelecting` — строки «Рабочая папка» и «Локальная папка» ведут внутрь папки, а не выделяют её в родителе). Существование пути намеренно не проверяется: без выданного TCC-доступа папка читается как отсутствующая, и кнопка гасла бы зря |
| `ConfigurationFilePanelBridge.swift` | Реализует локальный протокол `ConfigurationFilePicking`: `NSSavePanel`/`NSOpenPanel` для файла конфигурации и создание нового security-scoped bookmark для папки импортируемой пары (bookmark из файла экспорта непереносим, он привязан к конкретной машине и её TCC-разрешениям) |
| `WindowAccessor.swift` | `NSViewRepresentable`, который в `onResolve`-коллбэке возвращает `NSWindow`, в котором размещена SwiftUI-вьюха; используется в `MacyadApp` для передачи `NSWindow` в `AppDelegateBridge` |
| `ApplicationRelauncher.swift` | Статический хелпер: запускает новый экземпляр приложения через `NSWorkspace.shared.openApplication` и завершает текущий |
| `LiveMonitorWindowBridge.swift` | Реализация протокола `LiveMonitorPresenting` из `MacyadCore`: per-pair `LiveMonitorViewModel` для двух слотов (`.running` / `.archived`), независимые `NSWindow`-ы под каждый слот, distinct title prefixes («Live · …» / «Last run · …» — RU: «Сейчас · …» / «Последний прогон · …»). `archiveRunningLog(for:)` переносит running VM в archived и освобождает running-слот; повторное открытие того же слота переактивирует существующее окно вместо создания нового |
| `LiveMonitorClosureObserver.swift` | Замыкание-обёртка над `RcloneOutputObserver` (`@Sendable @MainActor (String) -> Void`); используется в `MacyadApp` (scheduled push через `ScheduledSyncLifecycle`) и в `MainWindowView` (manual push) для проброса rclone-вывода в `LiveMonitorViewModel.appendLine` |

## For AI Agents

### Working In This Directory
- Никаких полноценных экранов на AppKit. Если нужно создать новый экран — делай его на SwiftUI; используй `WindowAccessor` для получения `NSWindow`, если потребуется.
- Протоколы `FolderPicking` и `PasteboardWriting` объявлены в `MacyadCore` (не здесь). `FolderPickerBridge` и `PasteboardBridge` — конкретные реализации для production; в тестах подставляются моки.
- `AppDelegateBridge` получает `NSWindow` не из системного коллбэка, а через явный вызов `attachMainWindow(_:)` из `WindowAccessor` в `MacyadApp`. Показать окно или спрятать, решает сам делегат: при автозапуске он выставляет `hidesWindowOnAttach`.
- Ручной запуск от автозапуска отличается активацией: LaunchServices выводит приложение на передний план по действию пользователя, login item — нет. `NSApplication.launchIsDefaultUserInfoKey` для этого не годится, замерено 2026-08-13 — приходит `false` и при `open -a`, и при `open -ga`.
- `StatusBarBridge` создаётся один раз в `AppCoordinator.configureStatusBar(delegate:)`; обновление контента — через `update(rootView:)`, не пересоздавая объект.
- `ApplicationRelauncher.relaunch()` вызывается из `SettingsViewModel` после смены языка (требует полного перезапуска); гарантии вызова на `MainActor` обеспечены через `Task { @MainActor in }`.

### Testing Requirements
Все адаптеры используют AppKit-API, требующий работающего приложения. Тестирование — вручную через `./script/build_and_run.sh`. Юнит-тесты ViewModels, использующих адаптеры, работают через протоколы (`FolderPicking`, `PasteboardWriting`) с мок-реализациями из `MacyadTests/`.

### Common Patterns
- Все классы аннотированы `@MainActor`; `AppDelegateBridge` и `IssueReviewWindowBridge` — `final class NSObject`.
- `NSHostingController<AnyView>` — стандартный способ хостинга SwiftUI внутри AppKit-контейнеров (поповер, отдельное окно).
- Template image (`isTemplate = true`) для `NSStatusItem` автоматически адаптируется к светлой/тёмной теме без дополнительного кода.
- `windowShouldClose` перехватывает закрытие главного окна и скрывает его вместо завершения приложения; `NSApp.setActivationPolicy(.accessory)` убирает иконку из Dock.

## Dependencies

### Internal
- `MacyadCore` — `FolderPicking`, `PasteboardWriting`, `AppCopy`, `ActivityRouteToken`, `AppLaunchMode`, `LiveMonitorPresenting`, `LiveMonitorSlot`, `LiveMonitorViewModel`, `RcloneOutputObserver`, `SyncPair`
- `App/AppMetadata.swift` — `AppMetadata.displayName` (используется в `StatusBarBridge` как fallback accessibilityDescription)

### External
- `AppKit` — `NSStatusBar`, `NSStatusItem`, `NSPopover`, `NSHostingController`, `NSOpenPanel`, `NSPasteboard`, `NSWindow`, `NSWorkspace`, `NSApplication`, `NSApplicationDelegate`, `NSWindowDelegate`
- `SwiftUI` — `NSViewRepresentable`, `NSHostingController`, `AnyView`
- `UserNotifications` — `UNUserNotificationCenterDelegate`, `UNNotificationResponse` (в `AppDelegateBridge`)
- `Foundation` — `Bundle`, `ProcessInfo`

<!-- MANUAL: -->
