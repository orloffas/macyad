<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-06-03 | Updated: 2026-06-03 -->

# docs

## Purpose

Документация проекта MacYaD: рабочий to-do лист и скриншоты для README.

## Key Files

| File | Description |
|------|-------------|
| `todo.md` | Рабочий список текущих открытых задач и известных проблем |
| `yandex-oauth-app.md`, `yandex-oauth-app.ru.md` | Публичная инструкция: своё OAuth-приложение Яндекса вместо заблокированного встроенного приложения rclone (`410 GoneError`) и `script/connect_yandex.py` |
| `local-signing.md`, `local-signing.ru.md` | Стабильная self-signed подпись локальных сборок |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `images/` | Скриншоты для обеих языковых половин `README.md`; снимаются автоматически (см. `MacyadUITests/AGENTS.md`) |
| `images/yandex-oauth/` | Снимки страниц oauth.yandex.ru для `yandex-oauth-app*.md`. Сняты вручную, не автоматически: перед заменой закрасить почту, ClientID и Client secret и снять метаданные (`magick … -strip`) |

## For AI Agents

### Working In This Directory

- `todo.md` — живой рабочий список; обновлять при появлении новых задач или закрытии старых.
- Репозиторий публичный. Не размещай здесь транскрипты агентских сессий, вывод `ps`, абсолютные пути вида `/Users/<имя>/…` и что-либо, привязанное к конкретной машине.
- Новую документацию размещать в корне `docs/` или создавать новые подкаталоги по необходимости.
- Все документы ведутся на русском; технические идентификаторы (имена файлов, команды, API) — без перевода.

### Testing Requirements

Документация не требует автоматизированного тестирования.

### Common Patterns

- Формат файлов — Markdown.
- Даты в именах файлов и в записях `todo.md` — `YYYY-MM-DD`.

## Dependencies

### Internal

- Корневой `AGENTS.md` (`../AGENTS.md`) — project-wide правила и language policy.
- `README.md` в корне репозитория — продуктовый обзор.

### External

Нет внешних зависимостей.

<!-- MANUAL: -->
