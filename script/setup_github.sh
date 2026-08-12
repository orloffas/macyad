#!/usr/bin/env bash
set -euo pipefail

# Applies this repository's GitHub configuration: merge strategy, the branch
# ruleset that makes `main` pull-request-only, and the security features GitHub
# offers.
#
# Idempotent — run it again after changing .github/ruleset-main.json, or after
# flipping the repository to public, and it will bring the settings back in
# line. Anything that requires a public repository is reported as skipped
# rather than failing the run.
#
#   ./script/setup_github.sh            # apply
#   ./script/setup_github.sh --dry-run  # show what would be applied

REPO="${MACYAD_GITHUB_REPO:-orloffas/macyad}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULESET_FILE="$ROOT_DIR/.github/ruleset-main.json"
RULESET_NAME="main"
DRY_RUN=0

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# Messages go to stderr so that a caller redirecting a command's stdout to
# /dev/null does not swallow them along with the API response.
say() { printf '%s\n' "$*" >&2; }
skip() { printf 'skipped: %s\n' "$*" >&2; }

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'would run: %s\n' "$*" >&2
    return 0
  fi
  "$@"
}

# For settings that may legitimately be unavailable: reports what happened
# instead of pretending success under --dry-run.
try() {
  local description="$1"
  local unavailable="$2"
  shift 2

  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'would attempt: %s\n' "$description" >&2
    return 0
  fi

  if "$@" >/dev/null 2>&1; then
    say "ok: $description"
  else
    skip "$unavailable"
  fi
}

command -v gh >/dev/null || { echo "error: gh CLI is required" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "error: run 'gh auth login' first" >&2; exit 1; }

VISIBILITY="$(gh api "repos/$REPO" --jq .visibility)"
say "repository: $REPO ($VISIBILITY)"
say

# --- Repository settings -----------------------------------------------------
# Squash-only: the branch protection below allows nothing else, and a merge
# button offering strategies the ruleset rejects is a trap.
say "== repository settings =="
run gh api -X PATCH "repos/$REPO" \
  -F has_issues=true \
  -F has_wiki=false \
  -F has_projects=false \
  -F has_discussions=false \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F allow_auto_merge=true \
  -F delete_branch_on_merge=true \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  >/dev/null
say "ok: issues, squash-only merges, branch auto-delete"
say

# --- Branch ruleset ----------------------------------------------------------
# Rulesets are not available for private repositories on the Free plan.
say "== branch ruleset ($RULESET_NAME) =="
if ! RULESETS="$(gh api "repos/$REPO/rulesets" 2>/dev/null)"; then
  skip "rulesets need a public repository (or a paid plan for private ones)"
  skip "  after going public, re-run this script to make main pull-request-only"
else
  EXISTING_ID="$(printf '%s' "$RULESETS" | jq -r --arg n "$RULESET_NAME" '.[] | select(.name == $n) | .id' | head -1)"
  if [[ -n "$EXISTING_ID" ]]; then
    run gh api -X PUT "repos/$REPO/rulesets/$EXISTING_ID" --input "$RULESET_FILE" >/dev/null
    say "ok: updated existing ruleset #$EXISTING_ID"
  else
    run gh api -X POST "repos/$REPO/rulesets" --input "$RULESET_FILE" >/dev/null
    say "ok: created ruleset — direct pushes to main are now refused"
  fi
fi
say

# --- Security features -------------------------------------------------------
# Secret scanning and push protection run for free on public repositories and
# need a paid plan on private ones. Private vulnerability reporting is the
# private channel SECURITY.md points people at.
say "== security =="
try "secret scanning and push protection" \
  "secret scanning is not available for this repository yet (needs public)" \
  gh api -X PATCH "repos/$REPO" \
    -f 'security_and_analysis[secret_scanning][status]=enabled' \
    -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'

try "private vulnerability reporting" \
  "private vulnerability reporting is not available yet (needs public)" \
  gh api -X PUT "repos/$REPO/private-vulnerability-reporting"

# Dependabot watches the actions used by the workflows — the project has no
# package manifests — and these two turn its findings into alerts and pull
# requests rather than a page nobody opens.
try "Dependabot alerts" \
  "Dependabot alerts are not available yet (needs public)" \
  gh api -X PUT "repos/$REPO/vulnerability-alerts"

try "Dependabot security updates" \
  "Dependabot security updates are not available yet (needs public)" \
  gh api -X PUT "repos/$REPO/automated-security-fixes"

say
if [[ "$VISIBILITY" == "public" ]]; then
  say "Code scanning runs from .github/workflows/codeql.yml on every push and PR."
else
  say "Code scanning runs from .github/workflows/codeql.yml and skips itself"
  say "while the repository is private."
fi
