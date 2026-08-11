<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# Resources

## Purpose
Ресурсы бандла таргета `Macyad` (app): asset catalog с иконками, файлы локализации для двух языков. Все три подкаталога включены в build phase `Copy Bundle Resources`. Здесь нет Swift-кода — только статические ресурсы, на которые ссылается runtime и система сборки.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Assets.xcassets/` | Asset catalog: `AppIcon.appiconset` (иконка приложения и Dock), `MenuBarTemplate.imageset` (Template image для `NSStatusItem`) |
| `en.lproj/` | Английская локализация (`Localizable.strings`) |
| `ru.lproj/` | Русская локализация (`Localizable.strings`), используется по умолчанию |

## For AI Agents

### Working In This Directory
- `AppIcon` подключается через build setting `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` в `project.yml`; изменение имени набора в xcassets требует синхронного обновления этого setting.
- PNG в `AppIcon.appiconset` уже содержат прозрачные поля: тело иконки занимает 824×824 внутри холста 1024×1024 (по 100 px с каждой стороны), как требует macOS HIG. Иконка во весь холст выглядит в Dock крупнее соседних и перекрывает индикатор запущенного приложения. Перегенерация — `swift script/make_app_icon.swift`; скрипт меряет непрозрачный bounding box, поэтому повторный запуск ничего не портит.
- `MenuBarTemplate` должен оставаться Template image (`isTemplate = true` выставляется программно в `StatusBarBridge`); PNG экспортируется только в 1x/2x, без цвета — чёрный на прозрачном фоне.
- Локализация в приложении переключается динамически через `AppLanguage` и `AppCopy` без перезапуска (за исключением системных строк, для которых требуется `ApplicationRelauncher.relaunch()`). `ru.lproj` — default: при отсутствии ключа в `en.lproj` система использует русский вариант.
- Новые локализованные строки добавляются в оба файла `Localizable.strings` одновременно. Ключи строк должны совпадать с полями `AppCopy` (`Domain/Models/AppCopy.swift`).
- Не создавай AGENTS.md внутри подкаталогов `Assets.xcassets/`, `en.lproj/`, `ru.lproj/` — это не code-директории.

### Testing Requirements
Корректность ресурсов проверяется вручную через `./script/build_and_run.sh`:
- Иконка в Dock и строке меню отображается корректно.
- Переключение языка в Settings обновляет UI без перезапуска (для строк, проходящих через `AppCopy`).
- Template image в строке меню адаптируется к светлой и тёмной теме macOS.

### Common Patterns
- `NSImage(named: "MenuBarTemplate")` — способ загрузки Template image в `StatusBarBridge`; fallback — SF Symbol `externaldrive.badge.icloud`.
- `NSImage(named: "AppIcon")` используется в `AppDelegateBridge.makeApplicationIcon()` как второй fallback после `CFBundleIconFile`.
- Строки локализации в коде не обращаются к `NSLocalizedString` напрямую — все строки проходят через `AppCopy`, что позволяет переключать язык в runtime без перезапуска системы локализации.

## Dependencies

### Internal
- `PlatformAdapters/StatusBarBridge.swift` — загружает `MenuBarTemplate` через `NSImage(named:)`
- `PlatformAdapters/AppDelegateBridge.swift` — загружает `AppIcon` через `NSImage(named:)` и `Bundle.main`
- `Domain/Models/AppCopy.swift` — ключи строк должны соответствовать полям `AppCopy`

### External
- `AppKit` — `NSImage`, `NSImage.isTemplate`
- Xcode asset catalog compiler (`actool`) — обрабатывает `Assets.xcassets` во время сборки

<!-- MANUAL: -->
