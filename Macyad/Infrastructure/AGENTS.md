<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Infrastructure

## Purpose

Слой реализации контрактов Domain: реальные файловые операции, запуск и парсинг rclone-процессов, JSON-persistence для пар/аккаунтов/активности/настроек, планировщик фоновой синхронизации, уведомления через UNUserNotificationCenter и регистрация login item через ServiceManagement. Весь код слоя (кроме `System/LoginItemService.swift`) компилируется в framework target `MacyadCore`.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Filesystem/` | Управление файлами конфликтов и структурой рабочего каталога (см. `Filesystem/AGENTS.md`) |
| `Notifications/` | Отправка и запрос разрешений через `UNUserNotificationCenter` (см. `Notifications/AGENTS.md`) |
| `Persistence/` | JSON-хранилища для аккаунтов, пар, активности, настроек и состояний конфликтов (см. `Persistence/AGENTS.md`) |
| `Process/` | Построение команд, запуск и парсинг вывода rclone (см. `Process/AGENTS.md`) |
| `Scheduling/` | Контроллер фоновой периодической синхронизации (см. `Scheduling/AGENTS.md`) |
| `System/` | Системный сервис регистрации login item (см. `System/AGENTS.md`) |

## For AI Agents

### Working In This Directory

- Этот слой реализует протоколы, объявленные в Domain. Не добавлять бизнес-логику сюда — только адаптеры к системным API.
- `MacyadCore` включает весь каталог `Macyad/Infrastructure` **кроме** `System/LoginItemService.swift` (он linked в app target `Macyad`).
- При изменении структуры каталога обновить `project.yml` и перегенерировать: `xcodegen generate`.

### Testing Requirements

Тесты живут в `MacyadTests/Infrastructure/`. Запуск см. `../../AGENTS.md`.

### Common Patterns

- Protocol-based DI: каждый компонент реализует публичный протокол из Domain или объявляет собственный в том же файле.
- Изоляция через `actor` для всех компонентов с mutable state (репозитории, `BackgroundSyncController`).
- Atomic writes через `data.write(to:options:.atomic)` — никогда не писать файл напрямую без `.atomic`.

## Dependencies

### Internal

Domain-модели: `SyncPair`, `YandexAccount`, `ActivityEvent`, `AppPreferences`, `PairConflictBaselineState`, `AppPaths`, `SchedulerService`

### External

`Foundation`, `OSLog`, `UserNotifications`, `ServiceManagement`

<!-- MANUAL: -->
