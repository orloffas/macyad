<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Filesystem

## Purpose

Реализует файловые операции для управления конфликтами и инициализации структуры каталогов приложения. `LocalConflictFileManager` создаёт копии конфликтующих файлов с суффиксом `(MacYaD conflict <дата>)`, перемещает и удаляет канонические локальные файлы внутри папки пары. `WorkspaceLayoutManager` создаёт `appSupportRoot` и `workspaceRoot` при первом запуске.

## Key Files

| File | Description |
|------|-------------|
| `LocalConflictFileManager.swift` | Реализует `LocalConflictFileManaging`: создание conflict-копий, перемещение и удаление канонических файлов пары |
| `WorkspaceLayoutManager.swift` | Создаёт корневые каталоги `~/Library/Application Support/MacYaD/` и `Workspace/` если они отсутствуют |

## For AI Agents

### Working In This Directory

- `LocalConflictFileManager` принимает `FileManager` через DI — в тестах передавать mock; в prod использовать `.default`.
- Конфликтные копии складываются **в ту же директорию**, что и оригинал, рядом с ним — не в отдельный `conflicts/` каталог.
- Имя conflict-файла формируется как `<base> (MacYaD conflict <дата>).<ext>` через статический `conflictDateFormatter`.
- `WorkspaceLayoutManager` использует `FileManager.default` напрямую (не инжектируется) — это намеренно, вызывается только при старте.

### Testing Requirements

Прямых тестовых файлов для этого подкаталога нет в `MacyadTests/Infrastructure/`. Логика `LocalConflictFileManager` покрывается интеграционными тестами через `PairConflictStateRepositoryTests.swift`. Запуск см. `../../AGENTS.md`.

### Common Patterns

- `LocalConflictFileManaging` — публичный протокол, `LocalConflictFileManager` — `@unchecked Sendable` struct (FileManager thread-safe при использовании `.default`).
- Перед копированием/перемещением всегда создаётся промежуточная директория через `createDirectory(withIntermediateDirectories: true)`.
- Если destination уже существует при `makeConflictCopy` — удалить перед копированием.

## Dependencies

### Internal

`SyncPair` (для `localFolderDisplayPath`), `AppPaths` (через `WorkspaceLayoutManager`)

### External

`Foundation`

<!-- MANUAL: -->
