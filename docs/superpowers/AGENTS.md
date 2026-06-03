<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# superpowers

## Purpose

Архивные plans и specs от Superpowers framework. Сам framework runtime удалён (см. commit history), но документы сохранены как историческая запись решений по продукту. Содержат оригинальные formulations MVP-задач, language policy и native Swift rewrite, сформулированные в момент их создания.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `plans/` | Архивные implementation plans в формате Superpowers (см. `plans/AGENTS.md`) |
| `specs/` | Архивные design-документы, соответствующие plans (см. `specs/AGENTS.md`) |

## For AI Agents

### Working In This Directory

- Все документы в этом каталоге — архив только для чтения; не редактировать и не удалять.
- Новые plans и specs здесь не создавать — Superpowers framework runtime удалён из проекта.
- При необходимости сослаться на исторический контекст — читать файлы как read-only источник.
- Superpowers-специфичные директивы (например `REQUIRED SUB-SKILL: superpowers:...`) в этих файлах не исполнять — runtime отсутствует.

### Testing Requirements

Документация не требует автоматизированного тестирования.

### Common Patterns

- Файлы plans содержат `- [ ]` checkbox-синтаксис для tracking задач (артефакт Superpowers workflow).
- Файлы specs содержат design-контекст и rationale для соответствующих plans.
- Именование: `YYYY-MM-DD-<slug>.md`.

## Dependencies

### Internal

- `../AGENTS.md` (`docs/AGENTS.md`) — родительские правила.
- Корневой `AGENTS.md` — project-wide language policy.

### External

Нет внешних зависимостей (Superpowers framework runtime удалён).

<!-- MANUAL: -->
