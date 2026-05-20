#!/usr/bin/env bash
# check-store-readiness.sh — Verify a built Chrome extension is ready for CWS submission.
#
# Usage: check-store-readiness.sh [extension-dir]
#
# Exit code 1 if any CRITICAL issues; 0 otherwise.

set -euo pipefail

EXT_DIR="${1:-}"
if [ -z "$EXT_DIR" ]; then
  for candidate in .output/chrome-mv3 build/chrome-mv3-prod dist .; do
    if [ -f "$candidate/manifest.json" ]; then
      EXT_DIR="$candidate"
      break
    fi
  done
fi

if [ -z "$EXT_DIR" ] || [ ! -f "$EXT_DIR/manifest.json" ]; then
  echo "CRITICAL  <dir>  no manifest.json found." >&2
  exit 2
fi

MANIFEST="$EXT_DIR/manifest.json"
critical=0
warnings=0

emit() {
  printf "%-8s  %s  %s\n" "$1" "$2" "$3"
}

# Read all manifest fields we care about in one Python pass, with the path
# passed via argv (no shell interpolation into the script body — safe for
# paths with quotes/spaces/metachars).
read_field() {
  python3 - "$MANIFEST" "$1" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    m = json.load(f)
key = sys.argv[2]
# Support dotted lookups: icons.16, action.default_popup, etc.
cur = m
for part in key.split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        cur = ""
        break
if isinstance(cur, (dict, list)):
    print(json.dumps(cur))
else:
    print(cur if cur is not None else "")
PY
}

# ── 1. Required fields present and non-empty ───────────────────────
for field in name version description; do
  VAL=$(read_field "$field")
  if [ -z "$VAL" ]; then
    emit "CRITICAL" "manifest.$field" "missing or empty"
    critical=$((critical + 1))
  fi
done

# ── 2. Length limits ───────────────────────────────────────────────
NAME=$(read_field name)
NLEN=${#NAME}
if [[ "$NAME" != __MSG_* ]] && [ "$NLEN" -gt 45 ]; then
  emit "CRITICAL" "manifest.name" "$NLEN chars exceeds 45-char CWS limit"
  critical=$((critical + 1))
fi

DESC=$(read_field description)
DLEN=${#DESC}
if [[ "$DESC" != __MSG_* ]] && [ "$DLEN" -gt 132 ]; then
  emit "CRITICAL" "manifest.description" "$DLEN chars exceeds 132-char CWS limit"
  critical=$((critical + 1))
fi

# ── 3. Icons ───────────────────────────────────────────────────────
for size in 16 32 48 128; do
  ICON=$(read_field "icons.$size")
  if [ -z "$ICON" ]; then
    emit "WARNING" "manifest.icons.$size" "missing"
    warnings=$((warnings + 1))
  elif [ ! -f "$EXT_DIR/$ICON" ]; then
    emit "CRITICAL" "manifest.icons.$size" "file $ICON not found on disk"
    critical=$((critical + 1))
  fi
done

# ── 4. _locales/ for i18n if default_locale set ────────────────────
DEFAULT_LOCALE=$(read_field default_locale)
if [ -n "$DEFAULT_LOCALE" ]; then
  if [ ! -f "$EXT_DIR/_locales/$DEFAULT_LOCALE/messages.json" ]; then
    emit "CRITICAL" "_locales/$DEFAULT_LOCALE/messages.json" "missing (default_locale='$DEFAULT_LOCALE')"
    critical=$((critical + 1))
  fi
fi

# ── 5. No source maps or node_modules in build ─────────────────────
if find "$EXT_DIR" -name "*.map" -type f 2>/dev/null | head -1 | grep -q .; then
  emit "WARNING" "<build>" "contains *.map source maps. Strip before submission to reduce zip size and prevent source leakage."
  warnings=$((warnings + 1))
fi

if [ -d "$EXT_DIR/node_modules" ]; then
  emit "CRITICAL" "<build>" "contains node_modules/ — do NOT submit this. Re-run the build."
  critical=$((critical + 1))
fi

# ── 6. No .env or credentials leaking into build ───────────────────
if find "$EXT_DIR" -maxdepth 3 \( -name ".env" -o -name ".env.*" -o -name "credentials.json" \) 2>/dev/null | head -1 | grep -q .; then
  LEAKS=$(find "$EXT_DIR" -maxdepth 3 \( -name ".env" -o -name ".env.*" -o -name "credentials.json" \) 2>/dev/null | tr '\n' ' ')
  emit "CRITICAL" "<build>" "credentials in build: $LEAKS"
  critical=$((critical + 1))
fi

# ── 7. Version is a valid semver-ish ──────────────────────────────
VERSION=$(read_field version)
if ! echo "$VERSION" | grep -qE '^[0-9]+(\.[0-9]+){0,3}$'; then
  emit "CRITICAL" "manifest.version" "'$VERSION' is not a valid Chrome version (must be 1–4 dot-separated integers)"
  critical=$((critical + 1))
fi

# ── 8. Zip size hint ──────────────────────────────────────────────
SIZE_KB=$(du -sk "$EXT_DIR" | cut -f1)
SIZE_MB=$((SIZE_KB / 1024))
if [ "$SIZE_MB" -gt 10 ]; then
  emit "WARNING" "<build>" "build dir is ${SIZE_MB}MB — exceeds CWS soft limit of 10MB, review takes longer"
  warnings=$((warnings + 1))
fi

echo ""
echo "── Store readiness: critical=$critical warnings=$warnings ──"
exit "$((critical > 0 ? 1 : 0))"
