#!/usr/bin/env bash
#
# run-validator-fixtures.sh — adversarial fixture suite for the bundled validators.
#
# Asserts that each known-bad manifest is caught (the targeted validator exits 1)
# and the known-good manifest passes every validator (exit 0). This locks the
# critical -> nonzero-exit contract so a future edit can't silently stop catching
# a violation class (the reference failure: audit-deps.sh exit-0-on-critical, and
# validate-csp.sh exiting the raw count).
#
# Run from the repo root:  bash tests/run-validator-fixtures.sh
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
F="$ROOT/tests/fixtures/manifests"

MANIFEST="python3 $ROOT/skills/extension-architect/scripts/validate-manifest.py"
CSP="bash $ROOT/skills/extension-security/scripts/validate-csp.sh"
PERMS="python3 $ROOT/skills/extension-security/scripts/validate-permissions.py"

fail=0

# assert <validator-cmd> <fixture> <expected-exit> <description>
assert() {
  local cmd="$1" fixture="$2" expected="$3" desc="$4"
  $cmd "$F/$fixture" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$expected" ]; then
    echo "  ✅ $fixture → exit $got  ($desc)"
  else
    echo "  ❌ $fixture → exit $got, expected $expected  ($desc)"
    fail=1
  fi
}

echo "── known-good: must pass every validator (exit 0) ──"
assert "$MANIFEST" good-clean.json 0 "manifest"
assert "$CSP"      good-clean.json 0 "csp"
assert "$PERMS"    good-clean.json 0 "permissions"

echo "── known-bad: targeted validator must catch it (exit 1) ──"
assert "$MANIFEST" bad-mv2-version.json      1 "manifest_version 2"
assert "$MANIFEST" bad-mv2-fields.json       1 "MV2-only fields under MV3"
assert "$MANIFEST" bad-missing-file.json     1 "references a nonexistent file"
assert "$CSP"      bad-csp-unsafe-eval.json  1 "CSP allows unsafe-eval"
assert "$CSP"      bad-csp-remote-script.json 1 "CSP allows a remote script-src"
assert "$PERMS"    bad-webrequestblocking.json 1 "MV2-only webRequestBlocking"

echo
if [ "$fail" -eq 0 ]; then
  echo "── validator fixtures: all assertions passed ──"
else
  echo "── validator fixtures: FAILURES above ──"
fi
exit "$fail"
