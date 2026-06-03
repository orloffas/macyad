<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Policies

## Purpose

Правила допустимости операций — чистые функции без побочных эффектов, принимающие модели и возвращающие булевы решения. Отделены от сервисов, чтобы логика блокировки операций оставалась тестируемой изолированно от I/O.

## Key Files

| File | Description |
|------|-------------|
| `PushEligibilityPolicy.swift` | Определяет допустимость scheduled push для пары: возвращает `false`, если `lastKnownSeverity == .alarm` |

## For AI Agents

### Working In This Directory

- Только stateless `struct` с чистыми методами — никаких свойств с изменяемым состоянием.
- Методы принимают модели из `Models/` и возвращают `Bool` или простые enum-решения.
- Никакого async/await — правила синхронные.
- При добавлении нового policy — создавать отдельный файл, не расширять `PushEligibilityPolicy`.

### Testing Requirements

Тесты в `MacyadTests/Domain/Policies/`. Запуск: `./script/test.sh unit`. Каждый метод должен быть покрыт тестами на граничные значения входных моделей.

### Common Patterns

- `public struct PolicyName: Sendable` с `public init() {}`.
- Входные параметры — только типы из `Models/`.
- Нет зависимостей на сервисы или infrastructure.

## Dependencies

### Internal

`Models/SyncPair.swift`, `Models/Severity.swift` — используются как входные типы.

### External

Нет (`import` не требуется).

<!-- MANUAL: -->
