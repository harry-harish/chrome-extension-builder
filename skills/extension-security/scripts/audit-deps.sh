#!/usr/bin/env bash
# audit-deps.sh — Audit dependencies for known vulnerabilities and check
# whether LavaMoat should be adopted.
#
# Usage: audit-deps.sh [project-root]
#
# Exit code 1 if any CRITICAL issues; 0 otherwise.

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

if [ ! -f package.json ]; then
  echo "CRITICAL  <project>  no package.json"
  exit 2
fi

# Detect PM and verify it has a lockfile (most PM `audit` commands silently
# error or emit ENOLOCK without one).
PM=""
LOCKFILE=""
if [ -f pnpm-lock.yaml ]; then PM=pnpm; LOCKFILE=pnpm-lock.yaml
elif [ -f yarn.lock ]; then PM=yarn; LOCKFILE=yarn.lock
elif [ -f bun.lockb ]; then PM=bun; LOCKFILE=bun.lockb
elif [ -f package-lock.json ]; then PM=npm; LOCKFILE=package-lock.json
fi

critical=0
warnings=0

# 1. Audit (gated behind a lockfile so we don't drown the user in ENOLOCK noise)
if [ -n "$LOCKFILE" ]; then
  echo "── Running $PM audit (lockfile: $LOCKFILE) ──"
  case "$PM" in
    pnpm) pnpm audit --prod || true ;;
    yarn) yarn npm audit --severity moderate || true ;;
    bun)
      # bun has no native audit; fall back to npm if package-lock.json exists,
      # otherwise skip with a warning.
      if [ -f package-lock.json ]; then
        npm audit --omit=dev || true
      else
        echo "INFO  bun has no audit command and no package-lock.json present; skipping vuln audit. Consider 'bun pm audit' (preview) or running 'npm i --package-lock-only' to generate one."
      fi
      ;;
    npm)  npm audit --omit=dev || true ;;
  esac
else
  echo "WARNING  <project>  no lockfile found (pnpm-lock.yaml / yarn.lock / bun.lockb / package-lock.json). Skipping vulnerability audit — install deps first, then re-run."
  warnings=$((warnings + 1))
fi

# 2. Count production dependencies
PROD_DEP_COUNT=$(python3 -c "
import json
m = json.load(open('package.json'))
print(len(m.get('dependencies', {})))
")
echo ""
echo "── Production dependencies: $PROD_DEP_COUNT ──"

# 3. LavaMoat recommendation
HAS_LAVAMOAT=$(python3 -c "
import json
m = json.load(open('package.json'))
deps = list(m.get('dependencies', {}).keys()) + list(m.get('devDependencies', {}).keys())
print('yes' if any('lavamoat' in d for d in deps) else 'no')
")

if [ "$HAS_LAVAMOAT" = "no" ] && [ "$PROD_DEP_COUNT" -gt 20 ]; then
  echo "RECOMMEND  <project>  ${PROD_DEP_COUNT} production deps; consider adopting LavaMoat (@lavamoat/allow-scripts at minimum)"
  warnings=$((warnings + 1))
fi

# 4. Detect crypto/wallet keywords → strongly recommend LavaMoat
if grep -qE '"(ethers|web3|wagmi|viem|@metamask|@solana|secp256k1|bcrypt|argon2|webcrypto)"' package.json 2>/dev/null; then
  if [ "$HAS_LAVAMOAT" = "no" ]; then
    echo "CRITICAL  <project>  crypto/wallet deps detected without LavaMoat. Adopt LavaMoat for supply-chain defense."
    critical=$((critical + 1))
  fi
fi

# 5. Postinstall scripts present in deps?
echo ""
echo "── Checking for postinstall scripts in deps ──"
if [ "$PM" = "pnpm" ] && [ -n "$LOCKFILE" ]; then
  pnpm rebuild --dry-run 2>&1 | head -20 || true
elif [ -z "$LOCKFILE" ]; then
  echo "(skipped — no lockfile)"
fi

echo ""
echo "── Dep audit: critical=$critical warnings=$warnings ──"
exit $((critical > 0 ? 1 : 0))
