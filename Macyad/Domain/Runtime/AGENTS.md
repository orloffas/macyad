<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Runtime

## Purpose

Enum-флаги, определяющие режим запуска приложения. Используются в точке входа (`App`) для выбора конфигурации: нормальный запуск, принудительный foreground, UI-тестовые режимы с заглушками. Отделены от Domain-логики, чтобы тест-специфичные ветки не попадали в production-сервисы.

## Key Files

| File | Description |
|------|-------------|
| `AppLaunchMode.swift` | Enum с кейсами `normal`, `foreground`, `uiTestOnboardingMissingRclone`, `uiTestReadyState`; парсит `ProcessInfo.arguments` и `environment`; предоставляет вычисляемые свойства `shouldForceForegroundWindow`, `stubbedRcloneLocation`, `usesEphemeralPaths` и `presentsWindowOnLaunch(isUserActivated:)` — решение «показывать окно и иконку в Dock» собирается из аргументов и признака активации, потому что по одним аргументам двойной клик от автозапуска не отличить |

## For AI Agents

### Working In This Directory

- Типы здесь — только enum / struct без I/O; чтение `ProcessInfo` допустимо исключительно в `init`.
- UI-тестовые кейсы должны устанавливать `usesEphemeralPaths = true` — это сигнал для `App` использовать временные директории.
- При добавлении нового launch-флага: добавить кейс в `AppLaunchMode`, соответствующее вычисляемое свойство и константу аргумента командной строки.

### Testing Requirements

Тесты в `MacyadTests/Domain/Runtime/` или `MacyadTests/`. Запуск: `./script/test.sh unit`. Тестировать `init(arguments:environment:)` на все распознаваемые аргументы.

### Common Patterns

- `public enum AppLaunchMode: Sendable, Equatable`.
- Аргументы запуска — строковые константы (`"UITEST_READY_STATE"`, `"MACYAD_FORCE_FOREGROUND"`), не magic strings в вызывающем коде.
- `MACYAD_FORCE_FOREGROUND` поддерживается через аргументы и environment-переменную со значениями `1 / true / yes / on`.

## Dependencies

### Internal

Не зависит от других директорий Domain.

### External

`Foundation` (ProcessInfo).

<!-- MANUAL: -->
