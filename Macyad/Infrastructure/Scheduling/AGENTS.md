<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-04 -->

# Scheduling

## Purpose

Фоновый контроллер периодической синхронизации: запускает цикл с интервалом 60 секунд, проверяет расписание через `SchedulerService`, выполняет push/pull-операции для пар, записывает `ActivityEvent` и отправляет уведомления об ошибках. Является точкой сборки для `PairStoreControlling`, `ActivityStoreControlling` и `UserNotificationSending`.

## Key Files

| File | Description |
|------|-------------|
| `BackgroundSyncController.swift` | `actor`; управляет lifecycle background-Task (`start`/`stop`/`runCycle`); принимает `ScheduledSyncLifecycle` (default `.noop`) и пробрасывает его в `SchedulerService.runScheduledSyncs` — это даёт UI-слою (`MacyadApp`) подключать Live monitor к scheduled push без зависимости Scheduling → UI. Содержит конформансы-расширения `PairRepository: PairStoreControlling`, `ActivityRepository: ActivityStoreControlling`, `AppPreferencesStore: PreferencesStoreControlling`, `UserNotificationClient: UserNotificationSending` |

## For AI Agents

### Working In This Directory

- `start()` идемпотентен — повторный вызов при активной Task ничего не делает.
- Переданный `ScheduledSyncLifecycle` не уходит в `SchedulerService` напрямую: `instrumentedLifecycle()` оборачивает его и в `willStart` пишет событие журнала с `inFlightOperation` до начала работы, запоминая его `id` в `inFlightEventIDs`. Итоговое событие идёт через `activityStore.replace` с тем же `id`. Без этого прогон, прерванный выходом из приложения, не оставлял следа — а плановый push с политикой mirror к этому моменту мог уже удалить файлы на remote. Записи, оставшиеся «в полёте», закрывает `MainWindowView.recoverInterruptedEvents` при следующем запуске.
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

`SchedulerService`, `ScheduledSyncLifecycle`, `SyncPair`, `ActivityEvent`, `AppPreferences`, `PairStoreControlling` (протокол), `ActivityStoreControlling` (протокол), `PreferencesStoreControlling` (протокол), `UserNotificationSending` (протокол), `PairRepository`, `ActivityRepository`, `AppPreferencesStore`, `UserNotificationClient`, `AppCopy`

### External

`Foundation`

<!-- MANUAL: -->
