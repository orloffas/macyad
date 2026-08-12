#!/usr/bin/env bash
set -euo pipefail

# Packages an app bundle into the DMG users download: a window with the app on
# the left, an Applications alias on the right, and an arrow between them.
#
#   ./script/package_dmg.sh <path-to-MacYaD.app> <output.dmg>
#
# The layout comes from appdmg, which writes the window settings itself rather
# than driving Finder with AppleScript — the Finder route needs a real desktop
# session and is the usual reason DMG packaging is flaky on CI.
#
# Without appdmg the DMG is still produced, just unstyled: a plain window with
# two icons in it. Install it with `npm install -g appdmg` for the real thing.

APP="${1:?usage: package_dmg.sh <app-bundle> <output.dmg>}"
OUTPUT="${2:?usage: package_dmg.sh <app-bundle> <output.dmg>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG_DIR="$ROOT_DIR/script/dmg"
APP_NAME="$(basename "$APP")"

[[ -d "$APP" ]] || { echo "error: no app bundle at $APP" >&2; exit 1; }
rm -f "$OUTPUT"

plain_dmg() {
  local staging
  staging="$(mktemp -d)/dmg"
  mkdir -p "$staging"
  /usr/bin/ditto "$APP" "$staging/$APP_NAME"
  ln -s /Applications "$staging/Applications"

  /usr/bin/hdiutil create \
    -volname "MacYaD" \
    -srcfolder "$staging" \
    -ov -format UDZO \
    "$OUTPUT" >/dev/null
}

appdmg_cmd=()
if command -v appdmg >/dev/null 2>&1; then
  appdmg_cmd=(appdmg)
elif command -v npx >/dev/null 2>&1; then
  appdmg_cmd=(npx --yes appdmg)
fi

if [[ ${#appdmg_cmd[@]} -eq 0 ]]; then
  echo "warning: appdmg not found; building an unstyled DMG" >&2
  echo "warning: install it with 'npm install -g appdmg' for the drag-to-Applications window" >&2
  plain_dmg
  echo "created $OUTPUT (unstyled)"
  exit 0
fi

if [[ ! -f "$DMG_DIR/background.tiff" ]]; then
  echo "note: regenerating the DMG background" >&2
  (cd "$ROOT_DIR" && ./script/make_dmg_background.swift >/dev/null)
fi

# appdmg resolves every path in the spec relative to the spec file, and the app
# bundle is somewhere else entirely — so the committed file is a template and
# the real paths are filled in here.
CONFIG="$(mktemp -d)/appdmg.json"
ICON="$ROOT_DIR/Macyad/Resources/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"

sed \
  -e "s|{{APP}}|$(cd "$(dirname "$APP")" && pwd)/$APP_NAME|" \
  -e "s|{{BACKGROUND}}|$DMG_DIR/background.tiff|" \
  -e "s|{{ICON}}|$ICON|" \
  "$DMG_DIR/appdmg.json" > "$CONFIG"

if ! "${appdmg_cmd[@]}" "$CONFIG" "$OUTPUT"; then
  echo "warning: appdmg failed; falling back to an unstyled DMG" >&2
  plain_dmg
  echo "created $OUTPUT (unstyled)"
  exit 0
fi

echo "created $OUTPUT"
