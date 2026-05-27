#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacYaD"
SCHEME="Macyad"
PROJECT="Macyad.xcodeproj"
BUNDLE_ID="me.orloff.macyad"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${MACYAD_BUILD_DIR:-$HOME/Library/Caches/MacYaD/Build}"
TEST_BUILD_DIR="${MACYAD_TEST_BUILD_DIR:-$HOME/Library/Caches/MacYaD/TestBuild}"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
STAGED_APP_DIR="${MACYAD_STAGED_APP_DIR:-$HOME/Applications}"
STAGED_APP_BUNDLE="$STAGED_APP_DIR/$APP_NAME.app"
LAUNCH_APP_BUNDLE="$STAGED_APP_BUNDLE"
PROJECT_PATH="$ROOT_DIR/$PROJECT"
PACKAGE_DIR="$BUILD_DIR/Package"
DMG_PATH="$PACKAGE_DIR/$APP_NAME.dmg"
LSREGISTER_BIN="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

MODE="run"
LAUNCH_STYLE="foreground"
CLEAN_SCOPE="none"
SHOULD_LAUNCH="yes"
SHOULD_PACKAGE="no"
INTERACTIVE="1"

usage() {
  cat <<EOF
usage: $0 [run|debug|logs|telemetry|verify|package] [--clean|--clean-all] [--launch|--no-launch] [--package-dmg|--package-after-build] [--foreground|--background] [--prompt|--no-prompt]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    run)
      MODE="run"
      ;;
    --debug|debug)
      MODE="debug"
      LAUNCH_STYLE="foreground"
      ;;
    --logs|logs)
      MODE="logs"
      SHOULD_LAUNCH="yes"
      LAUNCH_STYLE="background"
      ;;
    --telemetry|telemetry)
      MODE="telemetry"
      SHOULD_LAUNCH="yes"
      LAUNCH_STYLE="background"
      ;;
    --verify|verify)
      MODE="verify"
      SHOULD_LAUNCH="yes"
      LAUNCH_STYLE="foreground"
      ;;
    package|--package|--package-dmg)
      MODE="package"
      SHOULD_PACKAGE="yes"
      SHOULD_LAUNCH="no"
      ;;
    --clean)
      CLEAN_SCOPE="build"
      ;;
    --clean-all|--clean-everywhere)
      CLEAN_SCOPE="all"
      ;;
    --launch)
      SHOULD_LAUNCH="yes"
      ;;
    --no-launch)
      SHOULD_LAUNCH="no"
      ;;
    --package-after-build)
      SHOULD_PACKAGE="yes"
      ;;
    --foreground)
      LAUNCH_STYLE="foreground"
      ;;
    --background)
      LAUNCH_STYLE="background"
      ;;
    --prompt)
      INTERACTIVE="1"
      ;;
    --no-prompt)
      INTERACTIVE="0"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

clean_build_artifacts() {
  rm -rf \
    "$BUILD_DIR" \
    "$TEST_BUILD_DIR" \
    "$HOME/Library/Caches/macyad/Build" \
    "$HOME/Library/Caches/macyad/TestBuild"
}

clean_everywhere() {
  clean_build_artifacts
  rm -rf \
    "$STAGED_APP_BUNDLE" \
    "$HOME/Library/Application Support/MacYaD" \
    "$HOME/Library/Application Support/macyad" \
    "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState" \
    "$HOME/Library/Saved Application State/com.orloff.macyad.savedState"
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
  defaults delete "com.orloff.macyad" >/dev/null 2>&1 || true
}

open_app() {
  if [[ "${1:-foreground}" == "foreground" ]]; then
    /usr/bin/open "$LAUNCH_APP_BUNDLE" --args --force-foreground
  else
    /usr/bin/open -g "$LAUNCH_APP_BUNDLE"
  fi
}

launched_app_asn() {
  /usr/bin/lsappinfo find "bundleid=$BUNDLE_ID" 2>/dev/null | head -n 1 | sed -E 's/^ASN:([^:]+):$/\1/'
}

verify_launched_app() {
  local attempt app_list

  for attempt in {1..10}; do
    app_list="$(/usr/bin/lsappinfo list 2>/dev/null || true)"
    if [[ "$app_list" == *"bundle path=\"$LAUNCH_APP_BUNDLE\""* ]]; then
      return 0
    fi
    sleep 1
  done

  return 1
}

launched_app_pid() {
  local asn app_info

  asn="$(launched_app_asn)"
  if [[ -z "$asn" ]]; then
    return 1
  fi

  app_info="$(/usr/bin/lsappinfo info -app "$asn" 2>/dev/null || true)"
  sed -nE 's/.*pid = ([0-9]+).*/\1/p' <<<"$app_info" | head -n 1
}

package_dmg() {
  local staging_dir

  staging_dir="$PACKAGE_DIR/staging"
  rm -rf "$staging_dir" "$DMG_PATH"
  mkdir -p "$staging_dir"
  /usr/bin/ditto "$APP_BUNDLE" "$staging_dir/$APP_NAME.app"
  ln -s /Applications "$staging_dir/Applications"

  /usr/bin/hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

  echo "Created DMG at $DMG_PATH"
}

stage_app_bundle() {
  mkdir -p "$STAGED_APP_DIR"

  if [[ -x "$LSREGISTER_BIN" ]]; then
    "$LSREGISTER_BIN" -u "$STAGED_APP_BUNDLE" >/dev/null 2>&1 || true
    "$LSREGISTER_BIN" -u "$APP_BUNDLE" >/dev/null 2>&1 || true
  fi

  rm -rf "$STAGED_APP_BUNDLE"
  /usr/bin/ditto "$APP_BUNDLE" "$STAGED_APP_BUNDLE"
  /usr/bin/touch "$STAGED_APP_BUNDLE"

  if [[ -x "$LSREGISTER_BIN" ]]; then
    "$LSREGISTER_BIN" -f "$STAGED_APP_BUNDLE" >/dev/null 2>&1 || true
  fi
}

prompt_if_interactive() {
  local answer normalized prompt_input prompt_output

  if [[ "$INTERACTIVE" != "1" ]]; then
    return
  fi

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    prompt_input="/dev/tty"
    prompt_output="/dev/tty"
  elif [[ -t 0 ]]; then
    prompt_input="/dev/stdin"
    prompt_output="/dev/stdout"
  else
    return
  fi

  if [[ "$CLEAN_SCOPE" == "none" ]]; then
    printf "Очистить build [b], очистить везде [a], пропустить [Enter]? " >"$prompt_output"
    IFS= read -r answer <"$prompt_input"
    normalized="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$normalized" in
      b)
        CLEAN_SCOPE="build"
        ;;
      a)
        CLEAN_SCOPE="all"
        ;;
    esac
  fi

  if [[ "$MODE" == "run" && "$SHOULD_LAUNCH" == "yes" ]]; then
    printf "Запустить приложение после build? [Y/n] " >"$prompt_output"
    IFS= read -r answer <"$prompt_input"
    normalized="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$normalized" in
      n|no)
        SHOULD_LAUNCH="no"
        ;;
      *)
        SHOULD_LAUNCH="yes"
        ;;
    esac
  fi

  if [[ "$SHOULD_PACKAGE" == "no" ]]; then
    printf "Собрать DMG после build? [y/N] " >"$prompt_output"
    IFS= read -r answer <"$prompt_input"
    normalized="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
    case "$normalized" in
      y|yes)
        SHOULD_PACKAGE="yes"
        ;;
    esac
  fi
}

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
prompt_if_interactive

case "$CLEAN_SCOPE" in
  build)
    clean_build_artifacts
    ;;
  all)
    clean_everywhere
    ;;
esac

xcodegen generate

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  build

stage_app_bundle

if [[ "$SHOULD_PACKAGE" == "yes" ]]; then
  package_dmg
fi

case "$MODE" in
  run)
    if [[ "$SHOULD_LAUNCH" == "yes" ]]; then
      open_app "$LAUNCH_STYLE"
    fi
    ;;
  debug)
    APP_PID=""
    open_app foreground
    verify_launched_app
    APP_PID="$(launched_app_pid)"
    if [[ -z "$APP_PID" ]]; then
      echo "failed to resolve $APP_NAME PID from LaunchServices" >&2
      exit 1
    fi
    lldb -p "$APP_PID"
    ;;
  logs)
    open_app "$LAUNCH_STYLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  telemetry)
    open_app "$LAUNCH_STYLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  verify)
    if [[ "$SHOULD_LAUNCH" == "yes" ]]; then
      open_app foreground
      verify_launched_app
    fi
    ;;
  package)
    ;;
esac
