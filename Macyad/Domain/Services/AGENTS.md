<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Services

## Purpose

Бизнес-логика и оркестрация операций. Сервисы получают модели из `Models/`, вызывают Infrastructure через protocol-injected зависимости и возвращают обновлённые модели или outcome-структуры. Здесь реализованы Push/Pull/Check-операции, конфликтное планирование, scheduled push, управление аккаунтами и парами, онбординг и агрегация статуса.

## Key Files

| File | Description |
|------|-------------|
| `AccountService.swift` | Создание, удаление и reconciliation `YandexAccount`; валидация (пустое имя, дубликат remoteName, аккаунт используется парами); автосуггест `remoteName` |
| `ActivityIssueFormatter.swift` | Форматирование `ActivityFileIssue` в локализованные строки и raw comparison block для Issue Review UI; вычисление идеальных ширин колонок таблицы через `NSFont` (`ActivityIssueTableLayout`); геометрия окна (`IssueReviewWindowLayout`) |
| `DriftService.swift` | Интерпретация rclone check output (stdout/stderr/exitCode) в `CheckDisposition` (healthy/warning/alarm) и `Severity` |
| `LocalFolderInspector.swift` | Протокол `LocalFolderInspecting` и реализация `FileManagerLocalFolderInspector`: рекурсивная проверка, содержит ли локальная папка user-visible файлы с учётом rclone exclude patterns |
| `OnboardingService.swift` | Протокол `OnboardingServicing` и реализация: определяет текущий шаг онбординга (`installRclone` / `configureRemote` / `createFirstPair`) через `RcloneLocating` и `RcloneConfigInspector` |
| `PairConflictPlanner.swift` | Baseline-aware анализ расхождений: сравнивает local/remote snapshots с baseline, классифицирует каждый path (`unchanged`, `localOnlyChanged`, `remoteOnlyChanged`, `conflict`, `deleteVsModifyConflict`); `bootstrapDisposition` для первичного создания baseline |
| `PairService.swift` | Создание, обновление и удаление `SyncPair`; валидация полей; запрет удаления последней пары |
| `SchedulerService.swift` | `actor`-сервис: тиковый цикл (60 с) scheduled push для всех пар, применяет `PushEligibilityPolicy`, делегирует в `SyncService` через `SerialOperationCoordinator`; возвращает `[ScheduledPushResult]` |
| `SerialOperationCoordinator.swift` | `actor`-очередь: гарантирует последовательное выполнение операций Push/Pull/Check; хранит `OperationState` (queued/running) и нотифицирует об изменениях через `StateDidChange` callback |
| `StatusService.swift` | Вычисляет `MenuBarSummary` (title + alarmCount + warningCount) из списка пар и шага онбординга для отображения в menu bar |
| `SyncService.swift` | Центральный оркестратор sync-операций: `push`, `pull`, `check`, `applyResolutions`; baseline-aware логика блокировки; взаимодействует с `RcloneProcessRunning`, `PairSnapshotProviding`, `PairConflictStateStoring`, `LocalFolderInspecting`, `LocalConflictFileManaging` |

## For AI Agents

### Working In This Directory

- Все зависимости на Infrastructure — только через протоколы (никаких прямых импортов конкретных реализаций).
- `import SwiftUI` — запрещён. `import AppKit` — только в `ActivityIssueFormatter` для `NSFont`.
- `actor` применяется только для типов с изменяемым состоянием (`SchedulerService`, `SerialOperationCoordinator`); остальные сервисы — `struct`.
- Новый сервис создаётся в отдельном файле; если требует инъекции — принимает зависимости через `init`.
- Операционный контракт `SyncService`: `push`/`pull`/`check` возвращают `OperationOutcome`, не бросают ошибок — внутренние ошибки конвертируются в `severity: .alarm`.

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
- `Policies/PushEligibilityPolicy.swift` — используется в `SchedulerService`
- `Infrastructure/` — через протоколы: `RcloneProcessRunning`, `RcloneLocating`, `PairSnapshotProviding`, `PairConflictStateStoring`, `RcloneExcludeFilePreparing`, `LocalConflictFileManaging`, `RcloneOperationInspecting`
- `App/AppPaths.swift` — передаётся в `OnboardingService` через `init`

### External

`Foundation` (UUID, Date, URL, FileManager, ProcessInfo); `AppKit` (только `ActivityIssueFormatter` — NSFont, CGFloat, CGRect, CGSize).

<!-- MANUAL: -->
