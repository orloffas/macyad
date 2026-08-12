#!/usr/bin/env bash
set -euo pipefail

# Signs an app bundle with the project's self-signed identity.
#
#   ./script/sign_app.sh <path-to-MacYaD.app> [identity]
#
# One implementation for both the local build and the release workflow: the
# designated requirement has to come out identical, or macOS treats a release
# build and a local one as different applications and re-asks for folder
# access. Ad-hoc signing changes the CDHash on every build and does exactly
# that.
#
# Missing identity is not an error — the caller falls back to whatever Xcode
# produced, with a warning.

BUNDLE="${1:?usage: sign_app.sh <bundle> [identity]}"
IDENTITY="${2:-${MACYAD_CODESIGN_IDENTITY:-MacYaD Local Development}}"

[[ -d "$BUNDLE" ]] || { echo "error: no bundle at $BUNDLE" >&2; exit 1; }

# No -v: a self-signed certificate without a trust root is not "valid", but it
# signs perfectly well.
if ! /usr/bin/security find-identity -p codesigning | grep -Fq "$IDENTITY"; then
  echo "warning: codesign identity '$IDENTITY' not found; leaving the existing signature" >&2
  echo "warning: macOS will re-ask for folder permissions after every rebuild" >&2
  exit 0
fi

# Inside-out: nested frameworks first, then the bundle itself (--deep is
# deprecated and signs in the wrong order).
while IFS= read -r nested; do
  /usr/bin/codesign --force --timestamp=none --sign "$IDENTITY" "$nested"
done < <(find "$BUNDLE/Contents/Frameworks" -maxdepth 1 -name '*.framework' 2>/dev/null)

/usr/bin/codesign --force --timestamp=none --sign "$IDENTITY" "$BUNDLE"
/usr/bin/codesign --verify --strict "$BUNDLE"

echo "signed $BUNDLE with '$IDENTITY'"
