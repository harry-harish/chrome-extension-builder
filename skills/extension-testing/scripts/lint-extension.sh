#!/usr/bin/env bash
# lint-extension.sh — Wraps `web-ext lint` for any MV3 extension.
#
# Usage: lint-extension.sh [extension-dir] [--target chrome|firefox|all]
#
# Defaults extension-dir to the most likely built output:
#   .output/chrome-mv3   (WXT)
#   build/chrome-mv3-prod (Plasmo)
#   dist                  (CRXJS / vanilla)
#   .                     (fallback)
#
# Target controls how Firefox-specific lint rules are treated. `web-ext lint`
# is Mozilla's linter and enforces Firefox-MV3 requirements (e.g. background
# fallback scripts, gecko add-on ID) that don't apply to Chrome. For a
# Chrome-only extension those would otherwise surface as errors.
#   chrome   filter out Firefox-only rules (default)
#   firefox  enforce them (the manifest must include gecko/scripts)
#   all      show every rule, no filtering

set -euo pipefail

EXT_DIR=""
TARGET="chrome"
while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      TARGET="${2:-}"; shift 2
      ;;
    --target=*)
      TARGET="${1#--target=}"; shift
      ;;
    -*)
      echo "Unknown flag: $1" >&2; exit 2
      ;;
    *)
      EXT_DIR="$1"; shift
      ;;
  esac
done

case "$TARGET" in
  chrome|firefox|all) ;;
  *) echo "Invalid --target '$TARGET'. Use chrome|firefox|all." >&2; exit 2 ;;
esac

if [ -z "$EXT_DIR" ]; then
  for candidate in .output/chrome-mv3 build/chrome-mv3-prod dist .; do
    if [ -f "$candidate/manifest.json" ]; then
      EXT_DIR="$candidate"
      break
    fi
  done
fi

if [ -z "$EXT_DIR" ] || [ ! -f "$EXT_DIR/manifest.json" ]; then
  echo "CRITICAL  <dir>  no manifest.json found. Run the build first (pnpm build / wxt build)." >&2
  exit 2
fi

echo "── Linting $EXT_DIR (target=$TARGET) ─────────────────────────"

# Firefox-only rule codes that don't apply to a Chrome MV3 extension.
# Keep this list tight — only rules that produce false positives when the
# manifest is correct for Chrome but doesn't include Firefox-specific fields.
FIREFOX_ONLY_RULES=(
  ADDON_ID_REQUIRED                       # browser_specific_settings.gecko.id
  BACKGROUND_SERVICE_WORKER_NOFALLBACK    # background.scripts fallback
  STORAGE_SYNC                            # gecko.id needed for sync in dev
  MISSING_DATA_COLLECTION_PERMISSIONS     # Firefox-builtin data-consent UI
)

run_webext() {
  if command -v pnpm >/dev/null 2>&1; then
    pnpm dlx web-ext@latest lint --source-dir="$EXT_DIR" --self-hosted --no-config-discovery "$@"
  elif command -v npx >/dev/null 2>&1; then
    npx -y web-ext@latest lint --source-dir="$EXT_DIR" --self-hosted --no-config-discovery "$@"
  else
    echo "CRITICAL  <env>  neither pnpm nor npx found. Install Node.js with a package manager." >&2
    return 2
  fi
}

# Use --output=json so we can re-classify Firefox-only rules without losing
# the human-readable presentation. When target=chrome|firefox we re-render
# with `jq` if available; otherwise we fall back to filtering the text output.
if [ "$TARGET" = "all" ]; then
  run_webext
  exit $?
fi

JSON=$(run_webext --output=json 2>/dev/null || true)

# If JSON capture failed (web-ext exited nonzero before emitting JSON for some
# reason, e.g. environmental), fall back to the standard text run.
if [ -z "$JSON" ]; then
  echo "(JSON capture failed; running standard text lint and exiting with web-ext's code)" >&2
  run_webext
  exit $?
fi

# Filter the JSON: when target=chrome, demote FIREFOX_ONLY_RULES from errors
# to notices. JSON is written to a temp file and the path passed as argv[1]
# so message strings with quotes can't break the parser, and so the Python
# heredoc on stdin doesn't conflict with feeding JSON via a pipe.
JSON_FILE=$(mktemp -t webext-lint.XXXXXX.json)
trap 'rm -f "$JSON_FILE"' EXIT
printf '%s' "$JSON" > "$JSON_FILE"

python3 - "$JSON_FILE" "$TARGET" "${FIREFOX_ONLY_RULES[@]}" <<'PY'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)
target = sys.argv[2]
firefox_only = set(sys.argv[3:])

def reclassify(items):
    kept, demoted = [], []
    for it in items:
        code = it.get('code') or it.get('rule')
        if target == 'chrome' and code in firefox_only:
            demoted.append(it)
        else:
            kept.append(it)
    return kept, demoted

errors_kept, errors_demoted = reclassify(data.get('errors', []))
warnings_kept, warnings_demoted = reclassify(data.get('warnings', []))

print(f"── web-ext lint (target={target}) ─────────────────────────")
print(f"errors:   {len(errors_kept)}  (Firefox-only demoted: {len(errors_demoted)})")
print(f"warnings: {len(warnings_kept)}  (Firefox-only demoted: {len(warnings_demoted)})")
print(f"notices:  {len(data.get('notices', []))}")

def show(label, items):
    if not items:
        return
    print(f"\n{label}:")
    for it in items:
        code = it.get('code', '?')
        msg = it.get('message', '')
        file = it.get('file', '')
        print(f"  [{code}] {msg}  ({file})")

show("ERRORS", errors_kept)
show("WARNINGS", warnings_kept)

if (errors_demoted or warnings_demoted) and target == 'chrome':
    print("\nFirefox-only rules demoted (re-run with --target=firefox or --target=all to see):")
    for it in errors_demoted + warnings_demoted:
        print(f"  [{it.get('code', '?')}] {it.get('message', '')}")

sys.exit(1 if errors_kept else 0)
PY
