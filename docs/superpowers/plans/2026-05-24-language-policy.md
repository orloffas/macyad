# Language Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Зафиксировать языковую политику проекта для всех участников через `AGENTS.md` и `README.md`, чтобы ответы, рабочая коммуникация и документация велись на русском языке с явными исключениями для professional terms и code entities.

**Architecture:** Политика хранится в двух синхронизированных корневых markdown-файлах. `AGENTS.md` выступает как источник инструкций для AI-агентов, а `README.md` дублирует правило как общую конвенцию проекта для людей.

**Tech Stack:** Markdown, Git

---

### Task 1: Добавить `AGENTS.md` с обязательным языковым правилом

**Files:**
- Create: `AGENTS.md`

- [ ] **Step 1: Подтвердить, что корневой `AGENTS.md` ещё не существует**

Run: `test ! -f /Users/zerotool/Documents/Dev/macyad/AGENTS.md`
Expected: команда завершается успешно без вывода

- [ ] **Step 2: Создать `AGENTS.md` с правилом для AI-агентов**

```md
# Project Instructions

## Language Policy

Язык проекта по умолчанию — русский.

Даже если исходные материалы, задачи, сообщения или prompt'ы приходят на английском языке, все ответы, внутренняя рабочая коммуникация и проектная документация должны вестись на русском языке.

Для сохранения точности разрешено не переводить устоявшиеся professional terms и code entities.

Не переводятся названия `API`, `SDK`, `library`, `framework`, `tool`, `service`, `CLI command`, а также имена файлов, переменных, классов, функций, таблиц и другие технические идентификаторы.

Если перевод ухудшает точность или искажает смысл, термин должен оставаться в оригинале.
```

- [ ] **Step 3: Проверить итоговое содержимое `AGENTS.md`**

Run: `sed -n '1,200p' /Users/zerotool/Documents/Dev/macyad/AGENTS.md`
Expected: файл содержит заголовки `# Project Instructions` и `## Language Policy`, а также явное требование вести ответы и документацию на русском языке

- [ ] **Step 4: Зафиксировать изменение**

```bash
git add /Users/zerotool/Documents/Dev/macyad/AGENTS.md
git commit -m "docs: add agent language policy"
```

### Task 2: Добавить `README.md` с общей языковой конвенцией проекта

**Files:**
- Create: `README.md`

- [ ] **Step 1: Подтвердить, что корневой `README.md` ещё не существует**

Run: `test ! -f /Users/zerotool/Documents/Dev/macyad/README.md`
Expected: команда завершается успешно без вывода

- [ ] **Step 2: Создать `README.md` с коротким описанием проекта и разделом `Language Policy`**

```md
# macyad

Начальная структура репозитория и базовые проектные соглашения.

## Language Policy

Язык проекта по умолчанию — русский.

Даже если исходные материалы, задачи, сообщения или prompt'ы приходят на английском языке, вся внутренняя рабочая коммуникация и проектная документация должны вестись на русском языке.

Устоявшиеся professional terms, product names, команды, пути, code entities и другие технические идентификаторы можно оставлять без перевода, если это нужно для точности.
```

- [ ] **Step 3: Проверить итоговое содержимое `README.md`**

Run: `sed -n '1,200p' /Users/zerotool/Documents/Dev/macyad/README.md`
Expected: файл содержит раздел `## Language Policy` и формулировку, согласованную с `AGENTS.md`

- [ ] **Step 4: Зафиксировать изменение**

```bash
git add /Users/zerotool/Documents/Dev/macyad/README.md
git commit -m "docs: add project language policy to readme"
```

### Task 3: Сверить формулировки и подтвердить выполнение спецификации

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Check: `docs/superpowers/specs/2026-05-24-language-policy-design.md`

- [ ] **Step 1: Сравнить оба итоговых файла с требованиями из спецификации**

Run: `sed -n '1,220p' /Users/zerotool/Documents/Dev/macyad/docs/superpowers/specs/2026-05-24-language-policy-design.md`
Expected: в спецификации перечислены требования про русский язык по умолчанию, исключения для professional terms и синхронизацию между `AGENTS.md` и `README.md`

- [ ] **Step 2: Проверить наличие ключевых формулировок в обоих файлах**

Run: `rg -n "Язык проекта по умолчанию|prompt'ы|русском языке|professional terms|API|SDK" /Users/zerotool/Documents/Dev/macyad/AGENTS.md /Users/zerotool/Documents/Dev/macyad/README.md`
Expected: поиск находит совпадения в обоих файлах и подтверждает наличие одинаковой языковой политики

- [ ] **Step 3: При необходимости выровнять тексты так, чтобы они не противоречили друг другу**

```md
Язык проекта по умолчанию — русский.

Даже если исходные материалы, задачи, сообщения или prompt'ы приходят на английском языке, ответы, рабочая коммуникация и проектная документация должны вестись на русском языке.

Устоявшиеся professional terms и технические идентификаторы можно оставлять без перевода, если это нужно для точности.
```

- [ ] **Step 4: Выполнить финальную проверку состояния репозитория**

Run: `git status --short`
Expected: в рабочем дереве остаются только ожидаемые изменения, связанные с `AGENTS.md` и `README.md`, либо дерево чистое после commit

- [ ] **Step 5: Зафиксировать итоговое выравнивание, если были дополнительные правки**

```bash
git add /Users/zerotool/Documents/Dev/macyad/AGENTS.md /Users/zerotool/Documents/Dev/macyad/README.md
git commit -m "docs: align language policy wording"
```
