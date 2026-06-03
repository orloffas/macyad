<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# MacyadTests/Domain

## Purpose

Тесты domain-сервисов и value-типов `MacyadCore`. Покрывают полный цикл операций с sync-парами (создание, обновление, удаление, валидация), логику планировщика и политику eligibility для scheduled push, baseline-aware обнаружение конфликтов и их классификацию (`PairConflictPlanner`), сервисы синхронизации (`SyncService`: push, pull, check, applyResolutions), онбординг (`OnboardingService`), агрегацию статуса (`StatusService`), форматирование activity-событий и issue-блоков (`ActivityIssueFormatter`), сворачивание повторяющихся событий в runs (`ActivityEventRun`), локализацию через `AppCopy`, дефолты `AppPreferences`, инспекцию локальных папок (`LocalFolderInspector`) и JSON round-trip моделей.

## Key Files

| File | Description |
|------|-------------|
| `AccountServiceTests.swift` | Зеркало `AccountService`: валидация дубликатов remote-имён, reconcile legacy-пар в аккаунты, предложение имён, состояние удаления аккаунта с blocking-парами |
| `ActivityEventRunTests.swift` | Зеркало `ActivityEventRun`: схлопывание последовательных одинаковых событий в runs, поведение при прерывании и разных details |
| `ActivityEventTests.swift` | JSON round-trip `ActivityEvent`: legacy-декодирование без `details`, `issueSet` с `ActivityFileIssue`, `routeToken` |
| `ActivityIssueFormatterTests.swift` | `ActivityIssueFormatter`: текстовые блоки для каждого вида `problemKind`, разбивка `directoryPath`/`fileName`, вычисление ширины колонок таблицы, layout окна issue review |
| `AppCopyTests.swift` | Проверяет все строки `AppCopy` для `.english` и `.russian`: заголовки, кнопки, статусы, счётчики событий, сообщения об ошибках |
| `AppPreferencesTests.swift` | Зеркало `AppPreferences`: дефолты первого запуска (`selectedLanguage`, `launchAtLoginEnabled`, `defaultScheduleMinutes`) |
| `LocalFolderInspectorTests.swift` | `FileManagerLocalFolderInspector`: скрытые/excluded файлы не считаются user-visible content, глубокая вложенность с literal directory patterns, реальный диск в temp-каталоге |
| `OnboardingServiceTests.swift` | Зеркало `OnboardingService`: stub `RcloneLocating`, шаги `installRclone` → `configureRemote` → `createFirstPair`, чтение реального rclone.conf из temp-каталога |
| `PairConflictPlannerTests.swift` | `PairConflictPlanner`: классификация `remoteOnlyChanged`, `conflict`, `deleteVsModifyConflict`, bootstrap-режим, safe initial push/pull, observedDifferences |
| `PairServiceTests.swift` | Зеркало `PairService`: валидация пустых полей, сохранение identity при update, запрет удаления последней пары, локализация ошибок через `AppLanguageState` |
| `SchedulerServiceTests.swift` | `SchedulerService` + `PushEligibilityPolicy`: соблюдение интервала расписания, пропуск alarm-пар, маркировка failures, начальный push в пустой remote, дедупликация blocked-попыток |
| `StatusServiceTests.swift` | Зеркало `StatusService`: агрегация severity по парам в summary-title и счётчики alarmCount/warningCount |
| `SyncPairTests.swift` | JSON round-trip `SyncPair`: legacy-декодирование с дефолтными excludes, явные exclude-листы, хелперы `remoteName`/`remoteSubpath`/`composeRemotePath` |
| `SyncServiceTests.swift` | `SyncService`: push/pull/check с stub processClient и snapshotProvider, блокировки при remote drift, initial push/pull, applyResolutions, детекция уже запущенного rclone copy, CommandFailedError локализация |

## For AI Agents

### Working In This Directory

- Большинство тестов объявляют stub/spy-типы в конце файла как `private struct/actor`, реализующие production-протоколы.
- `AppLanguageState.update(.english)` в setUp, `defer { AppLanguageState.update(previousLanguage) }` для изоляции.
- `SyncServiceTests` и `SchedulerServiceTests` содержат inline `InMemoryBaselineStore`, `StubSnapshotProvider`, `RecordingProcessClient` — не выносить в shared helpers без явной задачи.
- Тесты `LocalFolderInspectorTests` и `OnboardingServiceTests` используют реальный диск через `FileManager.default.temporaryDirectory` + `defer`-очистка.
- При добавлении нового `problemKind` в `ActivityFileIssue` — добавить case в `ActivityIssueFormatterTests`.

### Testing Requirements

```bash
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
# или
./script/test.sh unit
```

### Common Patterns

- Stub-протоколы локальны для файла (`private struct StubLocalFolderInspector: LocalFolderInspecting`).
- Фиксированные snapshot через вспомогательный `private func snapshot(_ files: (String, String)...) -> PairSnapshot`.
- `AppPaths.makeForTesting(rootURL:)` + `FileManager.default.temporaryDirectory` для файловых тестов.
- Actor-based spy: `actor RecordingProcessClient` с `private var argumentsLog: [[String]]`.

## Dependencies

### Internal

- `MacyadCore` (все domain-сервисы и value-типы).

### External

- `XCTest`, `Foundation`.
