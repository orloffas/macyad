<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Scheduling

## Purpose

Фоновый контроллер периодической синхронизации: запускает цикл с интервалом 60 секунд, проверяет расписание через `SchedulerService`, выполняет push/pull-операции для пар, записывает `ActivityEvent` и отправляет уведомления об ошибках. Является точкой сборки для `PairStoreControlling`, `ActivityStoreControlling` и `UserNotificationSending`.

## Key Files

| File | Description |
|------|-------------|
| `BackgroundSyncController.swift` | `actor`; управляет lifecycle background-Task (`start`/`stop`/`runCycle`); содержит конформансы-расширения `PairRepository: PairStoreControlling`, `ActivityRepository: ActivityStoreControlling`, `UserNotificationClient: UserNotificationSending` |

## For AI Agents

### Working In This Directory

- `start()` идемпотентен — повторный вызов при активной Task ничего не делает.
- `sleep` и `now` инжектируются через DI-параметры — использовать в тестах для контроля времени.
- `stateDidChange` callback вызывается после каждого `refreshState` и `runCycle` — используется для обновления UI из app target.
- Конформансы `PairRepository: PairStoreControlling` и др. объявлены **здесь**, а не в файлах репозиториев — намеренно, чтобы не создавать зависимость Persistence → Scheduling.
- Не добавлять прямые вызовы rclone в этот файл — делегировать через `SchedulerService`.

### Testing Requirements

| Тест | Покрывает |
|------|-----------|
| `MacyadTests/Infrastructure/BackgroundSyncControllerTests.swift` | `BackgroundSyncController` (цикл, обработка ошибок, уведомления) |

Запуск см. `../../AGENTS.md`.

### Common Patterns

- `actor` с `Task<Void, Never>` как хранимым свойством — стандартный паттерн для cancellable background loop.
- `SleepOperation = @Sendable (Duration) async throws -> Void` — testable замена `Task.sleep(for:)`.
- `StateDidChange = @Sendable ([SyncPair], [ActivityEvent]) async -> Void` — async callback для bridge к `@MainActor`-UI.

## Dependencies

### Internal

`SchedulerService`, `SyncPair`, `ActivityEvent`, `PairStoreControlling` (протокол), `ActivityStoreControlling` (протокол), `UserNotificationSending` (протокол), `PairRepository`, `ActivityRepository`, `UserNotificationClient`, `AppCopy`

### External

`Foundation`

<!-- MANUAL: -->
