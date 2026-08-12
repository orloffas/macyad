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
| `ScreenshotUITests.swift` | Снимает скриншоты для `README.md` / `README.ru.md` на seeded конфигурации, по одному прогону на язык; заодно проверяет, что каждая панель отрисовалась |

## For AI Agents

### Working In This Directory
- **Две установленные копии приложения ломают весь таргет.** Если `MacYaD.app` лежит и в `/Applications`, и в `~/Applications`, прогон падает на старте с `The test runner failed to initialize for UI testing. (Underlying Error: Timed out while enabling automation mode.)` — сообщение никак не намекает на причину. Проверять: `mdfind "kMDItemCFBundleIdentifier == 'me.orloff.macyad'"`, оставлять ровно один путь. С 2026-08-12 `build_and_run.sh` ставит в `/Applications` — туда же, куда кладёт DMG, — так что дубликат обычно означает старую копию в `~/Applications`.
- Существования элемента недостаточно: при провале раскладки окно рисуется пустым, а дерево доступности остаётся полным, и `waitForExistence` проходит. Ключевые экраны проверять через `isHittable` — неотрисованный элемент недоступен для нажатия. Именно так пропустили баг с пустым окном 2026-08-11.
- `-UITEST_SEEDED_PAIRS` поднимает приложение с парами, журналом и настроенным remote во временных путях: без данных целые ветки UI (например, состояние «настроено» в онбординге) не рендерятся вообще.
- `saveWindowScreenshot` в `PairFlowUITests` пишет снимок окна в контейнер раннера и печатает путь в лог — единственный способ увидеть, что панель действительно нарисована.
- Файлы, записанные в `FileManager.default.temporaryDirectory` раннера, снаружи забрать нельзя. Для скриншотов, которые нужны после прогона, — только `XCTAttachment` с `lifetime = .keepAlways`, дальше `xcrun xcresulttool export attachments --path <bundle>.xcresult --output-path <dir>`; имена вложений лежат в `manifest.json`.
- В строках сайдбара (`Label` внутри `List`) текст приходит в `value`, а не в `label` — `NSPredicate(format: "label == …")` их не находит. Ищи их через `app.staticTexts["<точная строка>"]`, подставляя строку по языку запуска.
- Скриншоты README снимаются **только** на `-UITEST_SEEDED_PAIRS`: реальная установка пользователя в кадр попадать не должна. Флаг `-UITEST_LANG_RU` рядом с ним переключает seeded-состояние на русский. Пересъём:

  ```bash
  xcodebuild test -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS' \
    -only-testing:MacyadUITests/ScreenshotUITests \
    -resultBundlePath shots.xcresult
  xcrun xcresulttool export attachments --path shots.xcresult --output-path shots
  ```

  Гейта по переменной окружения у этих тестов нет намеренно: на macOS до тестового процесса не доходит ни обычная переменная, переданная `xcodebuild`, ни документированный префикс `TEST_RUNNER_` (проверено 2026-08-11 — `ProcessInfo.processInfo.environment` в раннере пуст по обоим именам). Гейт молча пропускал бы весь класс.

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

- `XCUIApplication()` + `app.launchArguments = ["-UITEST_..."]` + `app.launch()`.
- Ведущий дефис в launch-аргументе обязателен: голое слово AppKit принимает за путь к открываемому документу, приложение стартует по document-open семантике и SwiftUI не создаёт окно `WindowGroup` — тогда все запросы XCUITest находят ноль элементов. `AppLaunchMode` сравнивает аргументы без ведущих дефисов, поэтому режим распознаётся в обеих формах.
- `app.windows.firstMatch.waitForExistence(timeout: 5)` — ожидание готовности окна.
- `app.buttons["accessibility.identifier"]` — поиск по `accessibilityIdentifier`.
- Двойная проверка локализации: `englishWindow.waitForExistence(...) || russianWindow.waitForExistence(...)`.

## Dependencies

### Internal

- App target `Macyad` (запускается как отдельный процесс).

### External

- `XCTest`, `XCUIApplication`.
