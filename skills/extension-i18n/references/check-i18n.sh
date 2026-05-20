#!/usr/bin/env bash
# check-i18n.sh — Validate _locales/ structure and key coverage.
#
# Usage: check-i18n.sh [project-root]

set -euo pipefail

ROOT="${1:-.}"

# Find _locales/ (could be at root, in public/, or in src/)
LOCALES_DIR=""
for candidate in "$ROOT/_locales" "$ROOT/public/_locales" "$ROOT/src/_locales"; do
  if [ -d "$candidate" ]; then
    LOCALES_DIR="$candidate"
    break
  fi
done

if [ -z "$LOCALES_DIR" ]; then
  echo "WARNING  <project>  no _locales/ directory found"
  exit 0
fi

if [ ! -f "$LOCALES_DIR/en/messages.json" ]; then
  echo "CRITICAL  $LOCALES_DIR  no en/messages.json (default English locale missing)"
  exit 1
fi

# Helper: pipe a messages.json path as argv to avoid shell-quoting hazards
keys_of() {
  python3 - "$1" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    print("\n".join(json.load(f).keys()))
PY
}

EN_KEYS=$(keys_of "$LOCALES_DIR/en/messages.json" | sort)

critical=0
warnings=0

# Check each other locale has the same keys
for locale_dir in "$LOCALES_DIR"/*/; do
  locale=$(basename "$locale_dir")
  if [ "$locale" = "en" ]; then continue; fi

  if [ ! -f "$locale_dir/messages.json" ]; then
    echo "WARNING  $locale  messages.json missing"
    warnings=$((warnings + 1))
    continue
  fi

  LOCALE_KEYS=$(keys_of "$locale_dir/messages.json" | sort)

  MISSING=$(comm -23 <(echo "$EN_KEYS") <(echo "$LOCALE_KEYS"))
  if [ -n "$MISSING" ]; then
    echo "WARNING  $locale  missing keys: $(echo "$MISSING" | tr '\n' ',' | sed 's/,$//')"
    warnings=$((warnings + 1))
  fi

  EXTRA=$(comm -13 <(echo "$EN_KEYS") <(echo "$LOCALE_KEYS"))
  if [ -n "$EXTRA" ]; then
    echo "INFO  $locale  extra keys (not in en/): $(echo "$EXTRA" | tr '\n' ',' | sed 's/,$//')"
  fi
done

# Check for keys referenced in code but not in en/messages.json
USED_KEYS=$(grep -rhoE "getMessage\(['\"]([a-zA-Z0-9_]+)" "$ROOT/src" "$ROOT/entrypoints" 2>/dev/null | sed -E "s/getMessage\\(['\"]//" | sort -u || true)
if [ -n "$USED_KEYS" ]; then
  UNDEFINED=$(comm -23 <(echo "$USED_KEYS") <(echo "$EN_KEYS"))
  if [ -n "$UNDEFINED" ]; then
    echo "CRITICAL  code  references undefined keys: $(echo "$UNDEFINED" | tr '\n' ',' | sed 's/,$//')"
    critical=$((critical + 1))
  fi

  UNUSED=$(comm -13 <(echo "$USED_KEYS") <(echo "$EN_KEYS"))
  if [ -n "$UNUSED" ]; then
    echo "INFO  en/messages.json  unused keys: $(echo "$UNUSED" | tr '\n' ',' | sed 's/,$//')"
  fi
fi

# Check for description fields
NO_DESC=$(python3 - "$LOCALES_DIR/en/messages.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
print("\n".join(k for k, v in m.items() if not v.get("description")))
PY
)
if [ -n "$NO_DESC" ]; then
  echo "INFO  en/messages.json  keys missing 'description': $(echo "$NO_DESC" | tr '\n' ',' | sed 's/,$//')"
fi

echo ""
echo "── i18n check: critical=$critical warnings=$warnings ──"
exit $((critical > 0 ? 1 : 0))
