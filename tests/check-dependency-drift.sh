#!/usr/bin/env bash
#
# check-dependency-drift.sh — fail if a fast-moving dependency drifts back to an
# unpinned/floating spec in anything the plugin generates or tells users to run.
#
# This is a regression guard for the version pins the pre-launch audit set. The
# reference failure is the wxt 0.20.x break: a floating `wxt@latest` scaffolded a
# project whose entrypoint imports no longer resolved. We pin the fast movers and
# this check keeps them pinned.
#
# Scanned: commands/, skills/, hooks/ (the shipped command snippets + scaffolds).
# NOT scanned: docs/, README, CHANGELOG, LAUNCH-POSTS — prose may name @latest.
#
# Intentionally-allowed floats (do NOT flag): `pnpm create vite@latest` (the Vite
# scaffolder) and `web-ext@latest` (stable, slow-moving) — both verified safe.
#
# Run from the repo root:  bash tests/check-dependency-drift.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2

SCAN_DIRS=(commands skills hooks)
fail=0

# flag <regex> <human message>
flag() {
  local pattern="$1" message="$2"
  local hits
  hits=$(grep -rnE "$pattern" "${SCAN_DIRS[@]}" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "  ❌ $message"
    echo "$hits" | sed 's/^/        /'
    fail=1
  else
    echo "  ✅ $message — none found"
  fi
}

echo "── fast-moving dependency pins (must stay pinned) ──"
# WXT must be pinned to a tested line, never @latest (the 0.20.x reference break).
flag 'wxt@latest'                         "WXT must be pinned (use wxt@~0.20.26), not wxt@latest"
flag '"wxt": *"\^'                         "generated package.json must pin wxt with ~, not ^"
flag '"wxt": *"(latest|\*)"'               "generated package.json must pin wxt to a version, not latest/*"
# chrome-webstore-upload-cli v3->v4 changed its CLI; pin the major.
flag 'chrome-webstore-upload-cli@latest'  "chrome-webstore-upload-cli must be pinned (@4), not @latest"
# CRXJS: recommend the stable line, not the stale @beta tag.
flag '@crxjs/vite-plugin@beta'            "@crxjs/vite-plugin must use stable @^2.6, not @beta"

echo
if [ "$fail" -eq 0 ]; then
  echo "── dependency drift: all pins intact ──"
else
  echo "── dependency drift: DRIFT DETECTED above ──"
fi
exit "$fail"
