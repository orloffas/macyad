#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-unit}"
PROJECT="Macyad.xcodeproj"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${MACYAD_TEST_BUILD_DIR:-$HOME/Library/Caches/MacYaD/TestBuild}"
PROJECT_PATH="$ROOT_DIR/$PROJECT"
RUNS_UI_TESTS="0"

case "$MODE" in
  unit|core|MacyadCore)
    SCHEME="MacyadCore"
    ;;
  ui|all|Macyad)
    SCHEME="Macyad"
    RUNS_UI_TESTS="1"
    ;;
  *)
    echo "usage: $0 [unit|core|ui|all]" >&2
    exit 2
    ;;
esac

cd "$ROOT_DIR"

if [[ "$RUNS_UI_TESTS" == "1" ]]; then
  pkill -x MacYaD >/dev/null 2>&1 || true
  pkill -x MacyadUITests-Runner >/dev/null 2>&1 || true
fi

xcodegen generate

xcodebuild test \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR"

if [[ "$RUNS_UI_TESTS" == "1" ]]; then
  pkill -x MacYaD >/dev/null 2>&1 || true
  pkill -x MacyadUITests-Runner >/dev/null 2>&1 || true
fi
