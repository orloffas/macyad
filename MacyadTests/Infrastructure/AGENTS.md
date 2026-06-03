<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# MacyadTests/Infrastructure

## Purpose

Тесты инфраструктурного слоя `MacyadCore`. Покрывают JSON-репозитории (аккаунты, пары, конфликтные baseline-состояния, activity-события), построение аргументов командной строки rclone (`RcloneCommandBuilder`), парсинг rclone.conf (`RcloneConfigInspector`), запись и объединение exclude-файлов (`RcloneExcludeFileStore`), glob-матчинг паттернов exclude (`RcloneExcludeMatcher`), поиск rclone-бинарника (`RcloneLocator`), реальный запуск процессов и парсинг pgrep-вывода (`RcloneProcessClient`), фоновый цикл синхронизации (`BackgroundSyncController`) и сериализацию конкурентных операций (`SerialOperationCoordinator`).

## Key Files

| File | Description |
|------|-------------|
| `AccountRepositoryTests.swift` | Зеркало `AccountRepository`: JSON round-trip сохранения и загрузки `[YandexAccount]` через `JSONFileStore` в temp-каталоге |
| `ActivityRepositoryTests.swift` | `ActivityRepository`: автоматическое обрезание событий старше 48 часов при загрузке, персистентность обрезанного списка |
| `BackgroundSyncControllerTests.swift` | `BackgroundSyncController`: полный цикл `runCycle` — успешный push, safe initial push, failure с уведомлением, remote-only drift с уведомлением; `start/stop` не запускает sync до первого sleep-интервала |
| `PairConflictStateRepositoryTests.swift` | Зеркало `PairConflictStateRepository`: JSON round-trip `PairConflictBaselineState` с вложенными `PairSnapshot` в temp-каталоге |
| `PairRepositoryTests.swift` | `PairRepository`: JSON round-trip `[SyncPair]`; `WorkspaceLayoutManager.ensureLayout()` создаёт appSupportRoot и workspaceRoot |
| `RcloneCommandBuilderTests.swift` | Зеркало `RcloneCommandBuilder`: полные аргументы для sync, check, pull с explicit `--config` и `--exclude-from`; format команды `remoteCreateCommand` |
| `RcloneConfigInspectorTests.swift` | Зеркало `RcloneConfigInspector`: парсинг секций `[name]` из реального `.conf`-файла в temp-каталоге |
| `RcloneExcludeFileStoreTests.swift` | `PersistentRcloneExcludeFileStore`: запись sync-exclude файла (одна строка на паттерн), объединение sync + additional в check-режиме, расширение literal-directory паттернов с добавлением `/**` варианта |
| `RcloneExcludeMatcherTests.swift` | Зеркало `RcloneExcludeMatcher`: literal-directory паттерн матчит вложенные пути, не матчит несвязанные sibling-пути |
| `RcloneLocatorTests.swift` | Зеркало `RcloneLocator`: возвращает первый существующий кандидат из списка, возвращает `nil` при отсутствии всех кандидатов |
| `RcloneProcessClientTests.swift` | `RcloneProcessClient`: запуск реального процесса с большим stdout без deadlock; `SystemRcloneOperationInspector`: парсинг pgrep-вывода через временный stub-скрипт |
| `SerialOperationCoordinatorTests.swift` | `SerialOperationCoordinator`: строгий порядок выполнения операций, отображение queued/running состояний через `states()` |

## For AI Agents

### Working In This Directory

- Тесты репозиториев и file store используют `FileManager.default.temporaryDirectory` + `defer`-очистка — обязательный паттерн.
- `AppPaths.makeForTesting(rootURL:)` используется как единая точка построения путей в temp-каталоге.
- `BackgroundSyncControllerTests` содержит полный набор inline stub/actor-типов (`InMemoryPairStore`, `InMemoryActivityStore`, `RecordingNotificationClient` и др.) — они локальны для файла.
- `RcloneProcessClientTests.testRunCapturesLargeStdoutWithoutDeadlock` запускает реальный `/bin/sh` — это интеграционный тест, требует macOS среды.
- `SerialOperationCoordinatorTests` использует `actor Signal`, `actor Gate`, `actor Recorder` для синхронизации async-задач в тестах.
- При добавлении нового rclone-субкоманды — добавить тест в `RcloneCommandBuilderTests`.

### Testing Requirements

```bash
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
# или
./script/test.sh unit
```

### Common Patterns

- Temp-каталог: `fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)` + `defer { try? fileManager.removeItem(at: root) }`.
- In-memory actor-stores: `actor InMemoryPairStore: PairStoreControlling`, `actor InMemoryBaselineStore: PairConflictStateStoring`.
- Recording actor-клиенты: `actor RecordingNotificationClient: UserNotificationSending` с `private var notifications` и геттером.
- `AppPaths.makeForTesting(rootURL:)` для всех path-зависимых компонентов.

## Dependencies

### Internal

- `MacyadCore` (репозитории, rclone-утилиты, `BackgroundSyncController`, `SerialOperationCoordinator`).

### External

- `XCTest`, `Foundation`.
