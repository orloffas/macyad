<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# System

## Purpose

Системный сервис регистрации приложения как login item через `SMAppService.mainApp`. Содержит единственный файл `LoginItemService.swift`.

> **Важно:** `LoginItemService.swift` включён в app target **`Macyad`**, а **не** в `MacyadCore`. Это явно указано в `project.yml` как отдельный source entry в секции Macyad-target. Причина: `SMAppService.mainApp` регистрирует именно запущенное app bundle, поэтому сервис должен компилироваться в контексте app target, а не framework.

## Key Files

| File | Description |
|------|-------------|
| `LoginItemService.swift` | Реализует `LoginItemControlling`; вызывает `SMAppService.mainApp.register()` / `unregister()` с проверкой текущего статуса перед изменением |

## For AI Agents

### Working In This Directory

- Этот файл **не** входит в `MacyadCore` — не импортировать его из framework-кода.
- `LoginItemControlling` — internal протокол (не `public`), используется только внутри app target.
- `setEnabled(_:)` — синхронный throwing метод; `SMAppService` операции выполняются синхронно.
- При изменении: убедиться, что `project.yml` по-прежнему содержит `LoginItemService.swift` в секции `Macyad` target, а не в `MacyadCore`.

### Testing Requirements

Прямых unit-тестов нет в `MacyadTests/Infrastructure/` — `SMAppService` требует реального app bundle и не мокируется стандартными средствами. Тестируется вручную через `./script/build_and_run.sh` и настройки «Вход в систему» в System Settings.

### Common Patterns

- Идемпотентность: проверка `SMAppService.mainApp.status` перед `register()`/`unregister()` — избегает ошибок при повторных вызовах.
- `struct` (не `actor`, не `class`) — нет mutable state; thread-safety обеспечена `SMAppService`.

## Dependencies

### Internal

Нет зависимостей от Domain или других Infrastructure-компонентов.

### External

`ServiceManagement`

<!-- MANUAL: -->
