<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Domain

## Purpose

Слой бизнес-логики приложения MacYaD. Содержит чистые модели данных, правила допустимости операций, runtime-флаги запуска и сервисы-оркестраторы. Слой не зависит от UIKit, SwiftUI и конкретных инфраструктурных реализаций — вся внешняя функциональность поступает через protocol-injected зависимости. Компилируется в составе target `MacyadCore`.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Models/` | Value types — данные без поведения (см. `Models/AGENTS.md`) |
| `Policies/` | Правила допустимости операций (см. `Policies/AGENTS.md`) |
| `Runtime/` | Enum-флаги режима запуска приложения (см. `Runtime/AGENTS.md`) |
| `Services/` | Бизнес-логика и оркестрация операций (см. `Services/AGENTS.md`) |

## For AI Agents

### Working In This Directory

- Файлы размещаются строго в соответствующем подкаталоге по роли: модель данных → `Models/`, правило → `Policies/`, сервис-оркестратор → `Services/`.
- Новые зависимости на Infrastructure-слой добавляются только через протоколы, объявленные в `Infrastructure/`.
- Никакого `import SwiftUI` или `import AppKit` в Domain (исключение: `ActivityIssueFormatter` использует `AppKit` для расчёта ширины колонок таблицы — это осознанное исключение).
- Весь публичный API маркируется `public` — `MacyadCore` экспортирует Domain во внешние targets.

### Testing Requirements

Unit-тесты Domain находятся в `MacyadTests/Domain/`. Запуск:
```bash
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
```
или через `./script/test.sh unit`.

### Common Patterns

- Все типы — `Sendable` (Swift 6 strict concurrency).
- Value types (`struct`, `enum`) — для моделей и сервисов без изменяемого состояния.
- `actor` — только если тип управляет изменяемым состоянием (см. `SchedulerService`, `SerialOperationCoordinator`).
- Инъекция зависимостей — через init-параметры, не через синглтоны.

## Dependencies

### Internal

Использует `App/AppPaths.swift` (передаётся через init); зависимостей на `Views/`, `ViewModels/` или `PlatformAdapters/` нет.

### External

`Foundation` — во всех файлах. `AppKit` — только в `Services/ActivityIssueFormatter.swift` (расчёт ширины колонок).

<!-- MANUAL: -->
