#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Macyad"
SCHEME="Macyad"
PROJECT="Macyad.xcodeproj"
BUNDLE_ID="me.orloff.macyad"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/macos"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
PROJECT_PATH="$ROOT_DIR/$PROJECT"

case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodegen generate

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

launched_app_asn() {
  /usr/bin/lsappinfo find "bundleid=$BUNDLE_ID" 2>/dev/null | head -n 1 | sed -E 's/^ASN:([^:]+):$/\1/'
}

verify_launched_app() {
  local attempt app_list

  for attempt in {1..10}; do
    app_list="$(/usr/bin/lsappinfo list 2>/dev/null || true)"
    if [[ "$app_list" == *"bundle path=\"$APP_BUNDLE\""* ]]; then
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

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    APP_PID=""
    open_app
    verify_launched_app
    APP_PID="$(launched_app_pid)"
    if [[ -z "$APP_PID" ]]; then
      echo "failed to resolve $APP_NAME PID from LaunchServices" >&2
      exit 1
    fi
    lldb -p "$APP_PID"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"me.orloff.macyad\""
    ;;
  --verify|verify)
    open_app
    verify_launched_app
    ;;
esac
