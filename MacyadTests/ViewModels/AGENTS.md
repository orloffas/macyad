<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# MacyadTests/ViewModels

## Purpose

Тесты ViewModel-классов, объявленных в `MacyadCore` (не в app target). Покрывают `CreatePairViewModel` — управление формой создания и редактирования sync-пары, включая выбор папки, парсинг exclude-текста, сохранение identity при edit-режиме; и `OnboardingViewModel` — обновление состояния онбординга через сервис, копирование команд в буфер обмена. `AppModel` и `SettingsViewModel` живут в app target `Macyad` и здесь не тестируются.

## Key Files

| File | Description |
|------|-------------|
| `CreatePairViewModelTests.swift` | `CreatePairViewModel`: `chooseFolder` заполняет поля из `FolderPicking`, init с дефолтным расписанием, `replaceAvailableAccounts` выбирает первый аккаунт, init из существующей пары (edit-режим), `buildPair` дедуплицирует и парсит exclude-текст, сохраняет id/severity/lastSyncAt |
| `OnboardingViewModelTests.swift` | `OnboardingViewModel`: `retry()` обновляет `state` через stub `OnboardingServicing`, `copy()` записывает в `PasteboardWriting` и устанавливает `lastCopiedCommand` |

## For AI Agents

### Working In This Directory

- Классы ViewModel помечены `@MainActor` — тесты объявлены `@MainActor final class`.
- Зависимости заменяются через протоколы: `FolderPicking` (stub), `OnboardingServicing` (stub), `PasteboardWriting` (spy).
- `CreatePairViewModelTests` не требует файловой системы — все операции in-memory.
- `OnboardingViewModelTests` проверяет async `retry()` через `await model.retry()`.
- При добавлении новых полей в `CreatePairViewModel` — добавить проверку в `testInitFromExistingPairPopulatesEditableFields` и `testBuildPairParsesDeduplicatedExcludesAndPreservesEditedPairIdentity`.

### Testing Requirements

```bash
xcodebuild -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS,arch=arm64' test
# или
./script/test.sh unit
```

### Common Patterns

- `@MainActor final class ... : XCTestCase` — обязательная аннотация для ViewModel-тестов.
- Stub-протоколы: `private final class StubFolderPicker: FolderPicking` (class, не struct — для `@MainActor`-совместимости).
- Spy-объект: `private final class StubPasteboard: PasteboardWriting` с `private(set) var copiedStrings`.
- `PairService()` используется напрямую — не заменяется stub-ом (pure logic, no I/O).

## Dependencies

### Internal

- `MacyadCore` (`CreatePairViewModel`, `OnboardingViewModel`, `PairService`, `YandexAccount`, `SyncPair`).

### External

- `XCTest`.
