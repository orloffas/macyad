<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# MacyadTests

## Purpose

Unit-тесты framework `MacyadCore`. Покрывают domain-логику (сервисы, планировщик, форматтеры, модели данных), инфраструктурный слой (репозитории, rclone-обёртки, фоновый контроллер), а также ViewModel-слой из `MacyadCore`. Все тесты выполняются без запуска app target — зависимости на I/O и процессы заменяются протокольными stub/spy-объектами.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `App/` | Тесты app-lifecycle типов из `MacyadCore`: `AppLaunchMode`, `AppPaths` |
| `Domain/` | Тесты domain-сервисов и value-типов: sync, scheduling, conflict planning, activity, локализация |
| `Infrastructure/` | Тесты инфраструктурных компонентов: репозитории, rclone-утилиты, фоновый контроллер |
| `ViewModels/` | Тесты ViewModel-классов из `MacyadCore`: `CreatePairViewModel`, `OnboardingViewModel` |

## For AI Agents

### Working In This Directory

- Тесты импортируют `MacyadCore` через `@testable import MacyadCore` — не app target.
- Асинхронные операции тестируются через `async/await` с `XCTestCase` (не `XCTestExpectation`).
- I/O-зависимости заменяются stub-структурами или `actor`-типами, реализующими production-протоколы (`RcloneProcessRunning`, `PairSnapshotProviding`, `PairConflictStateStoring` и др.).
- Тесты, требующие реального файлового доступа, создают временный каталог через `FileManager.default.temporaryDirectory` с уникальным `UUID().uuidString` и удаляют его в `defer`-блоке.
- Не использовать реальные сетевые соединения или production rclone-бинарник в unit-тестах.
- `AppLanguageState.update()` в setUp-паттернах должен восстанавливать исходное значение в `defer`.

### Testing Requirements

```bash
# Полный прогон unit-тестов
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test

# Альтернатива с отдельным derivedDataPath (для запуска вне sandbox)
./script/test.sh unit
```

### Common Patterns

- Временные каталоги: `FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)` + `defer { try? fileManager.removeItem(at: rootURL) }`.
- In-memory репозитории: `actor InMemoryBaselineStore: PairConflictStateStoring` — типичный шаблон замены disk-персистентности.
- Запись вызовов: `actor RecordingProcessClient: RcloneProcessRunning` — сохраняет аргументы для проверки.
- Тестирование с фиксированным временем: `Date(timeIntervalSince1970: ...)` — конкретные timestamp вместо `Date()`.
- `AppPaths.makeForTesting(rootURL:)` — фабричный метод для создания путей поверх временного каталога.

## Dependencies

### Internal

- `MacyadCore` — единственный тестируемый framework target.

### External

- `XCTest`, `Foundation`.
