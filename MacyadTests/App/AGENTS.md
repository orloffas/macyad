<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# MacyadTests/App

## Purpose

Тесты типов, относящихся к lifecycle и инициализации приложения из `MacyadCore`. Покрывают логику выбора режима запуска (`AppLaunchMode`) по аргументам командной строки и переменным окружения, а также корректность построения и создания файловой иерархии `AppPaths` — набора URL-путей к данным приложения (пары, аккаунты, rclone-конфиг, фильтры, конфликты).

## Key Files

| File | Description |
|------|-------------|
| `AppLaunchModeTests.swift` | Проверяет, что `AppLaunchMode` корректно разбирает аргументы `UITEST_*` и `MACYAD_FORCE_FOREGROUND`, устанавливает `shouldForceForegroundWindow` и `usesEphemeralPaths`, UI-тест режимы имеют приоритет над флагом foreground |
| `AppPathsTests.swift` | Проверяет, что `AppPaths.makeForTesting(rootURL:)` строит канонические URL-пути, а `AppPaths.live(appSupportDirectory:fileManager:)` физически создаёт нужные каталоги на диске |

## For AI Agents

### Working In This Directory

- `AppLaunchModeTests` — чистая логика без файловой системы, не требует временных каталогов.
- `AppPathsTests.testLiveCreatesAppSupportAndWorkspaceDirectories` создаёт реальный каталог в `FileManager.default.temporaryDirectory`; очистка через `defer`.
- При добавлении новых launch-аргументов в `AppLaunchMode` — добавлять соответствующий тест здесь.

### Testing Requirements

```bash
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
# или
./script/test.sh unit
```

### Common Patterns

- `AppLaunchMode(arguments: [...])` — прямой init без моков.
- `AppPaths.makeForTesting(rootURL:)` — in-memory paths для проверки URL-логики без реального диска.
- `AppPaths.live(appSupportDirectory:fileManager:)` — integration с реальным `FileManager`, требует временного каталога.

## Dependencies

### Internal

- `MacyadCore` (`AppLaunchMode`, `AppPaths`).

### External

- `XCTest`, `Foundation`.
