<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-04 -->

# Services

## Purpose

Бизнес-логика и оркестрация операций. Сервисы получают модели из `Models/`, вызывают Infrastructure через protocol-injected зависимости и возвращают обновлённые модели или outcome-структуры. Здесь реализованы Push/Pull/Check-операции, конфликтное планирование, плановая синхронизация (Auto-Push / Auto-Pull), управление аккаунтами и парами, онбординг и агрегация статуса.

## Key Files

| File | Description |
|------|-------------|
| `AccountService.swift` | Создание, удаление и reconciliation `YandexAccount`; валидация (пустое имя, дубликат remoteName, аккаунт используется парами); автосуггест `remoteName` |
| `ActivityIssueFormatter.swift` | Форматирование `ActivityFileIssue` в локализованные строки и raw comparison block для Issue Review UI; вычисление идеальных ширин колонок таблицы через `NSFont` (`ActivityIssueTableLayout`); геометрия окна (`IssueReviewWindowLayout`) |
| `DriftService.swift` | Интерпретация rclone check output (stdout/stderr/exitCode) в `CheckDisposition` (healthy/warning/alarm) и `Severity` |
| `LocalFolderInspector.swift` | Протокол `LocalFolderInspecting` и реализация `FileManagerLocalFolderInspector`: рекурсивная проверка, содержит ли локальная папка user-visible файлы с учётом rclone exclude patterns |
| `OnboardingService.swift` | Протокол `OnboardingServicing` и реализация: `refresh(pairCount:)` определяет текущий шаг (`installRclone` / `configureRemote` / `createFirstPair` / `complete`) через `RcloneLocating` и `RcloneConfigInspector`; заполняет `configuredRemoteName`, `rcloneVersion` и `pairsCount` для чеклиста окружения |
| `PairConflictPlanner.swift` | Baseline-aware анализ расхождений: сравнивает local/remote snapshots с baseline, классифицирует каждый path (`unchanged`, `localOnlyChanged`, `remoteOnlyChanged`, `conflict`, `deleteVsModifyConflict`); `bootstrapDisposition` для первичного создания baseline |
| `LiveMonitorPresenting.swift` | Протокол `LiveMonitorPresenting` + `LiveMonitorSlot` (`.running` / `.archived`): абстракция показа окна Live monitor. Конкретная реализация (`LiveMonitorWindowBridge`) живёт в `PlatformAdapters/`. Используется в `MacyadApp` для проброса presenter в `AppModel` и в lifecycle scheduled push |
| `PairService.swift` | Создание, обновление и удаление `SyncPair`; валидация полей; запрет удаления последней пары |
| `RcloneOutputObserver.swift` | Протокол `RcloneOutputObserver` — единая точка стрима stdout/stderr rclone-строк наблюдателю (Live monitor view-model). Реализация-замыкание `LiveMonitorClosureObserver` — в `PlatformAdapters/` |
| `ScheduledSyncLifecycle.swift` | `Sendable`-структура с двумя hook'ами: `willStart(SyncPair) -> RcloneOutputObserver?` и `didFinish(SyncPair) -> Void`. Передаётся в `SchedulerService` и `BackgroundSyncController`; используется в `MacyadApp` для подключения Live monitor к scheduled push (создать VM, стримить вывод rclone, архивировать лог по завершении). Default — `.noop` |
| `SchedulerService.swift` | `actor`-сервис: тиковый цикл (60 с) плановой синхронизации для всех пар, применяет `ScheduledSyncEligibilityPolicy` и выбирает направление по `pair.autoSyncMode` (`.push` → `syncService.push`, `.pull` → `syncService.pull`, оба в `executionMode: .scheduled`), делегирует в `SyncService` через `SerialOperationCoordinator`; принимает `ScheduledSyncLifecycle` (default `.noop`) и вокруг каждой операции вызывает `willStart` (передавая полученный observer) и `didFinish`; возвращает `[ScheduledSyncResult]` с фактическим `direction` |
| `SerialOperationCoordinator.swift` | `actor`-очередь: гарантирует последовательное выполнение операций Push/Pull/Check; хранит `OperationState` (queued/running) и нотифицирует об изменениях через `StateDidChange` callback |
| `ConfigurationTransferService.swift` | Чистая логика экспорта и импорта конфигурации. `makeExport` вырезает непереносимое: security-scoped bookmarks (привязаны к машине и её TCC-разрешениям) и историю прогонов. `prepareImport` строит `ConfigurationImportPlan`, не записывая ничего: переписывает `configPath` аккаунтов на путь этой машины, пересоздаёт bookmark для существующих папок, собирает `ConfigurationImportIssue` для отсутствующих папок и ненастроенных remote, и **принудительно** ставит `autoSyncMode = .off` и глобальную паузу — плановый push с политикой mirror по непроверенной папке способен очистить remote |
| `StatusService.swift` | Вычисляет `MenuBarSummary` (title + alarmCount + warningCount) из списка пар и шага онбординга для отображения в menu bar |
| `SyncService.swift` | Центральный оркестратор sync-операций: `push`, `pull`, `check`, `applyResolutions`; baseline-aware логика блокировки; взаимодействует с `RcloneProcessRunning`, `PairSnapshotProviding`, `PairConflictStateStoring`, `LocalFolderInspecting`, `LocalConflictFileManaging`. В Live monitor проставляет timestamped маркеры через `RcloneOutputObserver`: запуск rclone, exit-код, а также post-rclone фаза `refreshBaseline` (чтобы пользователь видел, почему footer остаётся `Running…` после строки `rclone exited with code 0`) |

## For AI Agents

### Working In This Directory

- Все зависимости на Infrastructure — только через протоколы (никаких прямых импортов конкретных реализаций).
- `import SwiftUI` — запрещён. `import AppKit` — только в `ActivityIssueFormatter` для `NSFont`.
- `actor` применяется только для типов с изменяемым состоянием (`SchedulerService`, `SerialOperationCoordinator`); остальные сервисы — `struct`.
- Новый сервис создаётся в отдельном файле; если требует инъекции — принимает зависимости через `init`.
- Операционный контракт `SyncService`: `push`/`pull`/`check` возвращают `OperationOutcome`, не бросают ошибок — внутренние ошибки конвертируются в `severity: .alarm`.
- `OnboardingService.refresh(pairCount:)` требует контекста снаружи: шаг `.complete` выставляется только когда rclone найден, remote настроен и `pairCount > 0`. Не вычисляй «настройка завершена» во вьюхе — это единственная точка решения, её же читает `StatusService` через `AppModel.onboardingState`.

### Testing Requirements

Тесты в `MacyadTests/Domain/Services/`. Запуск: `./script/test.sh unit`. Для тестирования сервисов с I/O используются mock-реализации протоколов (`RcloneProcessRunning`, `PairSnapshotProviding` и т.д.).

### Common Patterns

- `async/await` — для операций с I/O (run rclone, load/save baseline, snapshot).
- Protocol-injected зависимости с default-значениями в `init` для production-пути (упрощает вызов).
- `OperationOutcome` — унифицированный результат всех sync-операций: `severity`, `summary`, `details?`, `issueSet?`.
- `PairConflictPlanner` — pure value type без I/O; используется и в `SyncService`, и в тестах напрямую.
- `AppCopy.current` вызывается внутри методов (не в init) — уважает текущий язык на момент вызова.

## Dependencies

### Internal

- `Models/` — все типы данных (SyncPair, YandexAccount, ActivityEvent, ActivityIssueSet, PairConflictBaselineState, Severity, AppCopy, …)
- `Policies/ScheduledSyncEligibilityPolicy.swift` — используется в `SchedulerService`
- `Infrastructure/` — через протоколы: `RcloneProcessRunning`, `RcloneLocating`, `PairSnapshotProviding`, `PairConflictStateStoring`, `RcloneExcludeFilePreparing`, `LocalConflictFileManaging`, `RcloneOperationInspecting`
- `App/AppPaths.swift` — передаётся в `OnboardingService` через `init`

### External

`Foundation` (UUID, Date, URL, FileManager, ProcessInfo); `AppKit` (только `ActivityIssueFormatter` — NSFont, CGFloat, CGRect, CGSize).

<!-- MANUAL: -->
