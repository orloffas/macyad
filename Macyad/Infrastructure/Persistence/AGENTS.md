<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Persistence

## Purpose

JSON-хранилища для всех persisted-данных приложения: sync-пары, Yandex-аккаунты, лог активности, настройки пользователя и per-pair состояния конфликтов. Базовый примитив — `JSONFileStore<Value>` (generic actor) с atomic writes. Все репозитории выше — тонкие обёртки над ним, кроме `PairConflictStateRepository`, который хранит файлы per-pair по UUID.

## Key Files

| File | Description |
|------|-------------|
| `JSONFileStore.swift` | Generic `actor` с `load(default:)` и `save(_:)` через `data.write(options:.atomic)`; базовый примитив для всех репозиториев |
| `AccountRepository.swift` | `actor`; хранит `[YandexAccount]` в `accounts.json`; при сохранении сортирует по `displayName` |
| `ActivityRepository.swift` | `actor`; хранит `[ActivityEvent]` в `activity.json`; при загрузке и сохранении автоматически prune события старше 48 ч |
| `AppPreferencesStore.swift` | `actor`; хранит `AppPreferences` в `preferences.json`; возвращает `AppPreferences.defaults` при отсутствии файла |
| `PairConflictStateRepository.swift` | `actor`; реализует `PairConflictStateStoring`; хранит per-pair JSON-файлы в `conflicts/<UUID>.json` с atomic writes |
| `PairRepository.swift` | `actor`; хранит `[SyncPair]` в `pairs.json` |

## For AI Agents

### Working In This Directory

- Всегда использовать `JSONFileStore` для новых scalar/array хранилищ — не создавать отдельный file I/O.
- `PairConflictStateRepository` хранит файлы в `AppPaths.conflictStateDirectory` (`conflicts/`), а **не** в `appSupportRoot` напрямую.
- Все репозитории принимают `AppPaths` в публичном инициализаторе; для тестов есть внутренний `init(store:)`.
- Никаких ручных `try FileManager.default.removeItem` в репозиториях, кроме `PairConflictStateRepository.remove(pairID:)`.
- Не добавлять бизнес-логику в репозитории (исключение: pruning в `ActivityRepository` — это retention policy, не бизнес-логика).

### Testing Requirements

| Тест | Покрывает |
|------|-----------|
| `MacyadTests/Infrastructure/AccountRepositoryTests.swift` | `AccountRepository` |
| `MacyadTests/Infrastructure/ActivityRepositoryTests.swift` | `ActivityRepository` |
| `MacyadTests/Infrastructure/PairConflictStateRepositoryTests.swift` | `PairConflictStateRepository` |
| `MacyadTests/Infrastructure/PairRepositoryTests.swift` | `PairRepository` |

Запуск см. `../../AGENTS.md`.

### Common Patterns

- Все типы — `actor` (Swift concurrency, не `@MainActor`).
- Файлы приложения: `~/Library/Application Support/MacYaD/pairs.json`, `accounts.json`, `preferences.json`, `activity.json`, `conflicts/<UUID>.json`.
- `JSONEncoder` / `JSONDecoder` создаются как instance properties на actor — безопасно, т.к. доступ сериализован.

## Dependencies

### Internal

`SyncPair`, `YandexAccount`, `ActivityEvent`, `AppPreferences`, `PairConflictBaselineState`, `AppPaths`

### External

`Foundation`

<!-- MANUAL: -->
