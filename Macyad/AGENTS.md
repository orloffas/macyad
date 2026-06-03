<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Macyad

## Purpose
Корень исходного кода обоих Swift-таргетов приложения MacYaD. Таргет `MacyadCore` (framework) содержит слои Domain и часть Infrastructure/ViewModels, доступные для шаринга; таргет `Macyad` (app) содержит Views, PlatformAdapters, оставшиеся ViewModels, Resources и точку входа приложения. Слои выстроены по цепочке зависимостей: App → Views/ViewModels → Domain → Infrastructure/PlatformAdapters; обратные зависимости запрещены.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| App | Точка входа приложения, routing, окружение, метаданные и пути |
| Domain | Модели предметной области, сервисы, политики — чистый Swift без UI и I/O |
| Infrastructure | Реализации I/O: Process (rclone), Persistence, Filesystem, Notifications, Scheduling |
| PlatformAdapters | Мосты AppKit↔SwiftUI: StatusBar, FolderPicker, WindowAccessor, Pasteboard, AppDelegate |
| Resources | Ресурсы бандла: иконки, локализация, конфиги Xcode |
| ViewModels | `@Observable`/`ObservableObject` модели для Views; содержат бизнес-логику UI |
| Views | SwiftUI-вьюхи, сгруппированные по фичевым областям |

## For AI Agents

### Working In This Directory
- Не добавляй файлы прямо в `Macyad/` — любой новый файл относится к одному из подкаталогов.
- При изменении принадлежности файла к таргету обновляй `project.yml` (XcodeGen).
- Зависимости между таргетами: `Macyad` импортирует `MacyadCore`; обратный импорт запрещён.

### Testing Requirements
Сборка и запуск через `./script/build_and_run.sh`. UI-тесты расположены в `MacyadUITests/`. Unit-тесты доменной логики — в `MacyadTests/`.

### Common Patterns
- Локализуемые строки берутся из `AppCopy` (`Domain/Models/AppCopy.swift`) через `appModel.copy`.
- `AppEnvironment` передаётся через `@EnvironmentObject` — не создавай его в Views напрямую.
- Swift 6.0: весь публичный API, требующий MainActor, должен быть явно аннотирован.

## Dependencies

### Internal
Все слои ссылаются вверх по цепочке; конкретные зависимости описаны в AGENTS.md подкаталогов.

### External
SwiftUI, AppKit, Combine, UserNotifications, ServiceManagement, Foundation

<!-- MANUAL: -->
