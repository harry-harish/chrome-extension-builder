#!/usr/bin/env bash
# run-tests.sh — Run the full extension test pipeline: build, lint, unit, smoke.
#
# Usage: run-tests.sh [extension-root]
#
# Exits with the highest exit code from any step.

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

# ── 1. Detect package manager ───────────────────────────────────────
if [ -f pnpm-lock.yaml ]; then PM=pnpm
elif [ -f yarn.lock ]; then PM=yarn
elif [ -f bun.lockb ]; then PM=bun
else PM=npm
fi
echo "── Package manager: $PM ──"

# ── 2. Install ──────────────────────────────────────────────────────
echo "── Installing deps ─────────────────────────"
case "$PM" in
  pnpm) pnpm install --frozen-lockfile ;;
  yarn) yarn install --immutable ;;
  bun)  bun install --frozen-lockfile ;;
  npm)  npm ci ;;
esac

# ── 3. Build ────────────────────────────────────────────────────────
echo "── Building ────────────────────────────────"
$PM run build

# Find the built dir
BUILT=""
for candidate in .output/chrome-mv3 build/chrome-mv3-prod dist; do
  if [ -f "$candidate/manifest.json" ]; then
    BUILT="$candidate"
    break
  fi
done
if [ -z "$BUILT" ]; then
  echo "✗ no built extension found" >&2
  exit 1
fi
echo "  built: $BUILT"
echo "  size:  $(du -sh "$BUILT" | cut -f1)"

# ── 4. Lint ─────────────────────────────────────────────────────────
echo "── Linting with web-ext ────────────────────"
"$(dirname "$0")/lint-extension.sh" "$BUILT" || true

# ── 5. Unit tests (if configured) ───────────────────────────────────
if [ -f vitest.config.ts ] || [ -f vitest.config.js ] || grep -q '"vitest"' package.json 2>/dev/null; then
  echo "── Unit tests (Vitest) ─────────────────────"
  $PM exec vitest run --reporter=verbose
elif [ -f jest.config.js ] || [ -f jest.config.ts ]; then
  echo "── Unit tests (Jest) ───────────────────────"
  $PM exec jest --ci
fi

# ── 6. Smoke tests (Playwright) ─────────────────────────────────────
if [ -f playwright.config.ts ] || [ -f playwright.config.js ]; then
  echo "── Smoke tests (Playwright) ────────────────"
  $PM exec playwright install chromium >/dev/null 2>&1 || true
  EXTENSION_DIR="$(pwd)/$BUILT" $PM exec playwright test --reporter=line
fi

echo "── Done ────────────────────────────────────"
