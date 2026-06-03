<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# specs

## Purpose

Архивные design-документы, созданные в рамках Superpowers framework workflow. Каждый spec соответствует одному plan из `../plans/` и содержит design rationale, контекст и детали принятых решений. Сохранены как историческая запись; Superpowers framework runtime удалён из проекта.

## Key Files

| File | Description |
|------|-------------|
| `2026-05-24-language-policy-design.md` | Design-документ языковой политики: контекст, rationale, исключения для технических терминов |
| `2026-05-24-macyad-mvp-design.md` | Исторический design Tauri/React MVP; помечен как устаревший артефакт |
| `2026-05-24-macyad-native-swift-rewrite-design.md` | Design нативного Swift rewrite: архитектура, core flows, multi-account, conflict safety |

## For AI Agents

### Working In This Directory

- Все файлы — архив только для чтения; не редактировать, не удалять, не дополнять.
- `2026-05-24-macyad-mvp-design.md` помечен как устаревший Tauri-артефакт — не использовать как актуальный design guide.
- `2026-05-24-macyad-native-swift-rewrite-design.md` содержит `[!NOTE]` с обновлением от 2026-05-26 об актуальном продуктовом baseline.
- Для актуального design source of truth использовать корневой `DESIGN_PRINCIPLES.md`.

### Testing Requirements

Документация не требует автоматизированного тестирования.

### Common Patterns

- Файлы содержат `> [!WARNING]` или `> [!NOTE]` callouts с пометкой об устаревании или актуализации.
- Структура: контекст → цель → детали реализации → rationale.

## Dependencies

### Internal

- `../AGENTS.md` (`superpowers/AGENTS.md`) — родительские правила.
- `../plans/` — соответствующие implementation plans.
- Корневой `DESIGN_PRINCIPLES.md` — актуальные UI/UX guidelines.

### External

Нет внешних зависимостей.

<!-- MANUAL: -->
