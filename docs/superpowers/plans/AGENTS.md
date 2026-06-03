<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# plans

## Purpose

Архивные implementation plans, созданные в рамках Superpowers framework workflow. Охватывают три ключевых исторических решения: language policy проекта, первоначальный Tauri/React MVP и последующий native Swift rewrite. Сохранены как историческая запись; Superpowers framework runtime удалён из проекта.

## Key Files

| File | Description |
|------|-------------|
| `2026-05-24-language-policy.md` | Plan по фиксации языковой политики проекта через `AGENTS.md` и `README.md` |
| `2026-05-24-macyad-mvp.md` | Исторический MVP plan на `Tauri`/`React`; помечен как устаревший артефакт |
| `2026-05-24-macyad-native-swift-rewrite.md` | Plan полной замены `Tauri`/`React`/`Rust` реализации на нативное `Swift`/`SwiftUI` приложение |
| `qa-macyad-mvp-checklist.md` | QA checklist для native `MacYaD`: `menu bar`, onboarding, pair management, sync flows |

## For AI Agents

### Working In This Directory

- Все файлы — архив только для чтения; не редактировать, не удалять, не дополнять.
- Superpowers-директивы (`REQUIRED SUB-SKILL: superpowers:...`) в этих файлах не исполнять.
- `2026-05-24-macyad-mvp.md` явно помечен как устаревший Tauri-артефакт — не использовать как implementation guide.
- Актуальное состояние продукта описано в корневом `README.md` и `DESIGN_PRINCIPLES.md`.

### Testing Requirements

Документация не требует автоматизированного тестирования.

### Common Patterns

- Файлы содержат `- [ ]` checkbox-синтаксис (артефакт Superpowers task-tracking).
- Некоторые файлы содержат `> [!WARNING]` или `> [!NOTE]` callouts с пометкой об устаревании.

## Dependencies

### Internal

- `../AGENTS.md` (`superpowers/AGENTS.md`) — родительские правила.
- Корневой `README.md` и `DESIGN_PRINCIPLES.md` — актуальный product baseline.

### External

Нет внешних зависимостей.

<!-- MANUAL: -->
