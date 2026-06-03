<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# .codex

## Purpose

Codex CLI environment-конфигурация для репозитория. Не часть продукта — задаёт repo-specific environment для Codex агентов: доступные actions и команды запуска.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `environments/` | Environment-конфигурации для Codex CLI (см. `environments/AGENTS.md`) |

## For AI Agents

### Working In This Directory

- Не редактировать конфигурацию вручную без необходимости — изменения влияют на поведение Codex агентов в этом репозитории.
- При обновлении `./script/build_and_run.sh` (например, добавление новых флагов или изменение entry-point) проверить актуальность `environments/environment.toml`.
- Файлы в `.codex/` не являются частью продукта и не включаются в app bundle.

### Testing Requirements

Конфигурация не требует автоматизированного тестирования. Проверка вручную: убедиться, что action `Run` в Codex CLI корректно вызывает `./script/build_and_run.sh`.

### Common Patterns

- Конфигурация в формате TOML.
- Каждый action задаётся блоком `[[actions]]` с полями `name`, `icon`, `command`.

## Dependencies

### Internal

- `../script/build_and_run.sh` — команда, вызываемая action `Run`.
- `../AGENTS.md` — project-wide правила.

### External

- Codex CLI — читает конфигурацию из `.codex/environments/environment.toml`.

<!-- MANUAL: -->
