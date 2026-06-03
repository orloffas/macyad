<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# MacyadUITests

## Purpose

UI-тесты приложения `Macyad` через `XCUIApplication`. Покрывают критические user flows в сценариях онбординга и управления парами: отображение элементов управления при отсутствии rclone, наличие кнопки создания новой пары в ready-состоянии, открытие окна настроек через toolbar-кнопку. Тесты запускаются поверх реального app binary с launch arguments, которые переводят приложение в эфемерное тестовое состояние (`UITEST_*`).

## Key Files

| File | Description |
|------|-------------|
| `OnboardingUITests.swift` | Запуск с `UITEST_ONBOARDING_MISSING_RCLONE`: проверяет наличие кнопок `onboarding.retry` и `onboarding.copyCommand` в onboarding-окне |
| `PairFlowUITests.swift` | Запуск с `UITEST_READY_STATE`: проверяет наличие кнопки `pair.new` (или локализованного "Новая пара"), открытие Settings-окна по кнопке `settings.open` |

## For AI Agents

### Working In This Directory

- Target type: `bundle.ui-testing`, зависит от app target `Macyad` — импорт `MacyadCore` недоступен.
- Launch arguments (`UITEST_ONBOARDING_MISSING_RCLONE`, `UITEST_READY_STATE`) обрабатываются `AppLaunchMode` и переводят приложение в эфемерное состояние с изолированными путями (`usesEphemeralPaths`).
- Элементы UI идентифицируются по `accessibilityIdentifier` (строки вида `"onboarding.retry"`, `"pair.new"`) — не по заголовкам, за исключением локализованных fallback.
- Метод `waitForExistence(timeout: 5)` обязателен для первого элемента после `app.launch()`.
- При добавлении нового UI-элемента в app — назначать `accessibilityIdentifier` и добавлять тест здесь.
- Тесты не проверяют содержимое данных, только структуру и доступность UI-элементов.

### Testing Requirements

```bash
# UI-тесты входят в схему Macyad
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test

# Только unit-тесты без UI:
./script/test.sh unit
```

UI-тесты запускают реальное приложение — требуют сборки app target и macOS среды с графическим сеансом.

### Common Patterns

- `XCUIApplication()` + `app.launchArguments = ["UITEST_..."]` + `app.launch()`.
- `app.windows.firstMatch.waitForExistence(timeout: 5)` — ожидание готовности окна.
- `app.buttons["accessibility.identifier"]` — поиск по `accessibilityIdentifier`.
- Двойная проверка локализации: `englishWindow.waitForExistence(...) || russianWindow.waitForExistence(...)`.

## Dependencies

### Internal

- App target `Macyad` (запускается как отдельный процесс).

### External

- `XCTest`, `XCUIApplication`.
