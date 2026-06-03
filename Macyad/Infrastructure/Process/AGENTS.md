<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Process

## Purpose

Весь код взаимодействия с бинарником rclone: поиск исполняемого файла, построение аргументов команд, запуск процессов, парсинг stdout/stderr, инспекция rclone-конфига, управление exclude-файлами и получение снапшотов файловой системы через `rclone lsjson`. Инкапсулирует `Foundation.Process` за протоколом `RcloneProcessRunning` — нигде в Services не создаётся `Process()` напрямую.

## Key Files

| File | Description |
|------|-------------|
| `RcloneProcessClient.swift` | Реализует `RcloneProcessRunning`; запускает rclone как subprocess и возвращает `(stdout, stderr, exitCode)`; также содержит `RcloneOperationInspecting` для детекции активной copy-операции через `pgrep` |
| `RcloneCommandBuilder.swift` | Статические методы построения аргументов для `sync`, `check`, `pull`, `lsjson`, `config create/reconnect/delete` с поддержкой exclude-файлов и patterns |
| `RcloneConfigInspector.swift` | Парсит rclone.conf через regex для получения списка имён remote-ов |
| `RcloneExcludeFileStore.swift` | Реализует `RcloneExcludeFilePreparing`; материализует exclude-паттерны в файл `rclone/filters/<UUID>.<mode>.txt` перед запуском rclone |
| `RcloneExcludeMatcher.swift` | Локальный матчер exclude-паттернов (без запуска rclone): поддерживает glob, `/**`, literal-directory и path-паттерны |
| `RcloneLocator.swift` | Реализует `RcloneLocating`; ищет rclone по фиксированному списку кандидатов (`/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin`) |
| `RcloneOutputParser.swift` | Статические методы парсинга stdout/stderr: `differenceCount(_:stderr:)` и `containsRemoteChanges(_:stderr:)` |
| `RcloneSnapshotProvider.swift` | Реализует `PairSnapshotProviding`; запускает `rclone lsjson` и декодирует JSON-ответ в `PairSnapshot` |

## For AI Agents

### Working In This Directory

- Никогда не создавать `Foundation.Process()` напрямую за пределами `RcloneProcessClient` — все вызовы через `RcloneProcessRunning`.
- `RcloneCommandBuilder` — только pure static методы; не добавлять state или async.
- Exclude-файлы материализуются в `AppPaths.rcloneFiltersDirectory` (`rclone/filters/`); `RcloneExcludeFileStore` управляет lifecycle этих файлов.
- `RcloneExcludeMatcher` работает локально (без rclone), используется для preview и фильтрации до запуска синхронизации.
- `RcloneConfigInspector` читает файл через `String(contentsOf:)` — только для config-файла, не для произвольных путей.
- При добавлении новых rclone-команд: сначала добавить аргументы в `RcloneCommandBuilder`, затем вызов через `RcloneProcessClient`.

### Testing Requirements

| Тест | Покрывает |
|------|-----------|
| `MacyadTests/Infrastructure/RcloneCommandBuilderTests.swift` | `RcloneCommandBuilder` |
| `MacyadTests/Infrastructure/RcloneConfigInspectorTests.swift` | `RcloneConfigInspector` |
| `MacyadTests/Infrastructure/RcloneExcludeFileStoreTests.swift` | `PersistentRcloneExcludeFileStore` |
| `MacyadTests/Infrastructure/RcloneExcludeMatcherTests.swift` | `RcloneExcludeMatcher` |
| `MacyadTests/Infrastructure/RcloneLocatorTests.swift` | `RcloneLocator` |
| `MacyadTests/Infrastructure/RcloneProcessClientTests.swift` | `RcloneProcessClient` |

Запуск см. `../../AGENTS.md`.

### Common Patterns

- Protocol-first: `RcloneProcessRunning`, `RcloneLocating`, `RcloneExcludeFilePreparing`, `PairSnapshotProviding`, `RcloneOperationInspecting` — все тестируются через mock-реализации.
- `async/await` для всех subprocess-вызовов; синхронные методы только для pure computation (`RcloneCommandBuilder`, `RcloneOutputParser`, `RcloneExcludeMatcher`).
- `Sendable`-structs для stateless компонентов; actor-isolation не нужна там, где нет mutable state.

## Dependencies

### Internal

`SyncPair`, `AppPaths`, `PairSnapshot`, `RcloneExcludeFileMode`

### External

`Foundation`

<!-- MANUAL: -->
