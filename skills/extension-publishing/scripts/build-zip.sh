#!/usr/bin/env bash
# build-zip.sh — Build and zip a Chrome extension for CWS submission.
#
# Usage: build-zip.sh [extension-root]

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

# Detect PM
if [ -f pnpm-lock.yaml ]; then PM=pnpm
elif [ -f yarn.lock ]; then PM=yarn
elif [ -f bun.lockb ]; then PM=bun
else PM=npm
fi

# Detect framework
if grep -q '"wxt"' package.json 2>/dev/null; then
  FRAMEWORK=wxt
elif grep -q '"plasmo"' package.json 2>/dev/null; then
  FRAMEWORK=plasmo
elif grep -q '"@crxjs/vite-plugin"' package.json 2>/dev/null; then
  FRAMEWORK=crxjs
else
  FRAMEWORK=vanilla
fi

echo "── Building with $FRAMEWORK ($PM) ──"

# Resolve a manifest field, following __MSG_<key>__ placeholders through
# _locales/{default_locale}/messages.json. Used so a manifest with
# name: "__MSG_extension_name__" produces a zip filename of the resolved
# English string (or a sanitized project-dir fallback) rather than the
# literal placeholder.
#
# Usage: resolve_manifest_field <manifest-path> <field-name>
resolve_manifest_field() {
  python3 - "$1" "$2" <<'PY'
import json, os, re, sys
manifest_path, field = sys.argv[1], sys.argv[2]
try:
    with open(manifest_path) as f:
        m = json.load(f)
except Exception as e:
    print("", end="")
    sys.exit(0)

value = m.get(field, "") or ""
ext_dir = os.path.dirname(os.path.abspath(manifest_path))

# If the field is an __MSG_*__ placeholder, look it up in messages.json
msg_match = re.fullmatch(r"__MSG_([A-Za-z0-9_]+)__", value)
if msg_match:
    key = msg_match.group(1)
    default_locale = m.get("default_locale", "en")
    msgs_path = os.path.join(ext_dir, "_locales", default_locale, "messages.json")
    try:
        with open(msgs_path) as f:
            msgs = json.load(f)
        resolved = msgs.get(key, {}).get("message", "")
        if resolved:
            value = resolved
        else:
            # Fall back to sanitized parent dir name
            value = os.path.basename(ext_dir) or "extension"
    except (FileNotFoundError, json.JSONDecodeError):
        value = os.path.basename(ext_dir) or "extension"

print(value, end="")
PY
}

# Sanitize a string into a filename-safe slug.
slugify() {
  echo "$1" | tr -cd '[:alnum:]_- ' | tr ' ' '-' | tr -s '-' | sed 's/^-//;s/-$//' | cut -c1-60
}

case "$FRAMEWORK" in
  wxt)
    $PM exec wxt build -b chrome
    $PM exec wxt zip -b chrome
    ZIP=$(ls -t .output/*.zip 2>/dev/null | head -1)
    ;;
  plasmo)
    $PM run build
    $PM run package
    ZIP=$(ls -t build/*.zip 2>/dev/null | head -1)
    ;;
  crxjs)
    $PM run build
    BUILT=dist
    NAME=$(python3 -c "import json; print(json.load(open('package.json'))['name'])")
    VERSION=$(python3 -c "import json; print(json.load(open('package.json'))['version'])")
    NAME=$(slugify "$NAME")
    ZIP="${NAME:-extension}-$VERSION.zip"
    (cd "$BUILT" && zip -r "../$ZIP" .)
    ;;
  vanilla)
    RAW_NAME=$(resolve_manifest_field manifest.json name)
    NAME=$(slugify "$RAW_NAME")
    if [ -z "$NAME" ]; then
      NAME=$(basename "$(pwd)" | tr -cd '[:alnum:]_-')
      NAME="${NAME:-extension}"
    fi
    VERSION=$(python3 -c "import json; print(json.load(open('manifest.json'))['version'])")
    ZIP="${NAME}-${VERSION}.zip"
    # Exclude lists kept conservative — the goal is "only what the browser
    # needs to load the extension." Docs, repo metadata, tests, env files,
    # and editor config never belong in a store-submission zip.
    zip -r "$ZIP" . \
      -x "node_modules/*" \
      -x ".git/*" \
      -x ".github/*" \
      -x ".vscode/*" \
      -x ".idea/*" \
      -x "*.zip" \
      -x ".env*" \
      -x "tests/*" \
      -x "test/*" \
      -x "docs/*" \
      -x "README.md" \
      -x "CHANGELOG.md" \
      -x "CONTRIBUTING.md" \
      -x "LICENSE" \
      -x "LICENSE.*" \
      -x ".gitignore" \
      -x ".editorconfig" \
      -x ".prettierrc*" \
      -x ".eslintrc*" \
      -x "tsconfig*.json" \
      -x "package.json" \
      -x "package-lock.json" \
      -x "pnpm-lock.yaml" \
      -x "yarn.lock" \
      -x "bun.lockb"
    ;;
esac

if [ -z "${ZIP:-}" ] || [ ! -f "$ZIP" ]; then
  echo "✗ no zip was produced" >&2
  exit 1
fi

SIZE=$(du -h "$ZIP" | cut -f1)
echo "── Built: $ZIP ($SIZE) ──"
echo "$ZIP"
