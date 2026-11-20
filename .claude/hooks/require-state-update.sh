#!/usr/bin/env bash
# Не даёт закончить сессию, в которой менялись файлы, а STATE.md не тронут.
#
# Проблема, которую он решает: правило «в конце сессии обнови статус» записано
# текстом в нескольких репозиториях и не исполняется. В momentum
# `mom/docs/status.md` и `asr/docs/status.md` протухли с июля, а после них
# прошло 203 коммита; в cd-terraform-dev правило записано в CLAUDE.md
# отдельным разделом с пометкой «обязательно» и тоже не соблюдается.
# Текст агент может не прочитать или потерять из середины большого файла —
# хук исполняется без его участия.
#
# Механика: на событии Stop смотрим, менялись ли в этом репозитории файлы
# с начала сессии (рабочее дерево + коммиты), и есть ли среди них STATE.md.
# Если менялись, а STATE.md нет — одно блокирующее замечание с перечнем
# файлов. Повторно хук не срабатывает: stop_hook_active означает, что
# замечание уже выдано, и второй круг только запер бы сессию.
#
# Начало сессии берём как время создания файла транскрипта (stat -f %B).
# Поэтому чужой давний мусор в рабочем дереве (untracked-файлы прошлых
# сессий) блокировку не вызывает — учитываются только файлы, изменённые
# после старта.
#
# Репозиторий подключается к правилу самим фактом наличия файла состояния.
# По умолчанию это STATE.md в корне; где статус называется иначе, путь задаётся
# переменной AGENT_STATE_FILE прямо в команде хука, например
#   AGENT_STATE_FILE=docs/status.md "$CLAUDE_PROJECT_DIR/.claude/hooks/require-state-update.sh"
# Файла нет — хук молчит, это не его репозиторий.
#
# Fail-open by design: любая внутренняя ошибка означает exit 0. Хук, который
# запирает сессию из-за отсутствующего jq или кривого payload, хуже, чем
# отсутствие хука.
set -uo pipefail

payload=$(cat) || exit 0
command -v jq >/dev/null 2>&1 || exit 0

active=$(jq -r '.stop_hook_active // false' <<<"$payload" 2>/dev/null) || exit 0
[[ "$active" == "true" ]] && exit 0

transcript=$(jq -r '.transcript_path // empty' <<<"$payload" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null)
[[ -n "$cwd" && -d "$cwd" ]] || exit 0

state_file=${AGENT_STATE_FILE:-STATE.md}
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ -n "$root" && -f "$root/$state_file" ]] || exit 0

# Начало сессии. Без транскрипта считать нечего — молчим, а не гадаем.
[[ -n "$transcript" && -f "$transcript" ]] || exit 0
start=$(stat -f %B "$transcript" 2>/dev/null || stat -c %W "$transcript" 2>/dev/null) || exit 0
[[ "$start" =~ ^[0-9]+$ && "$start" -gt 0 ]] || exit 0

mtime_of() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null; }

changed=$(
  {
    # Рабочее дерево: только то, что тронуто после старта сессии.
    # Имя берём из позиции 4 — она переживает и "R  old -> new".
    git -C "$root" status --porcelain 2>/dev/null | while IFS= read -r line; do
      f=${line:3}
      f=${f##* -> }
      f=${f%\"}; f=${f#\"}
      [[ -n "$f" ]] || continue
      m=$(mtime_of "$root/$f")
      [[ -n "$m" && "$m" -ge "$start" ]] && printf '%s\n' "$f"
    done
    # Коммиты, сделанные в этой же сессии.
    git -C "$root" log --since="@$start" --name-only --pretty=format: 2>/dev/null
  } | sed '/^$/d' | sort -u
)

[[ -n "$changed" ]] || exit 0
grep -qxF "$state_file" <<<"$changed" && exit 0

count=$(wc -l <<<"$changed" | tr -d ' ')
list=$(head -10 <<<"$changed" | sed 's/^/  /')
[[ "$count" -gt 10 ]] && list="$list"$'\n'"  … и ещё $((count - 10))"

jq -n --arg list "$list" --arg n "$count" --arg f "$state_file" '{
  decision: "block",
  reason: ("В этой сессии изменено файлов: \($n), а \($f) не тронут.\n\n\($list)\n\n\($f) — вход в состояние репозитория: он грузится в начале каждой сессии. Не обновлённый статус означает, что следующая сессия начнёт с картины, которой уже нет.\n\nОбнови в \($f) то, что изменилось: что сделано (с хешами коммитов), что стало следующим шагом, какие решения приняты и какие вопросы открыты владельцу. Потом заверши работу — повторно это замечание не появится.")
}'
