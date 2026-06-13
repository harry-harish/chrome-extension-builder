#!/usr/bin/env bash
# validate-csp.sh — Check Content Security Policy in a Chrome extension manifest.
#
# Usage: validate-csp.sh path/to/manifest.json
#
# Exit code 1 if any CRITICAL issues; 0 otherwise.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 path/to/manifest.json" >&2
  exit 2
fi

MANIFEST="$1"

if [ ! -f "$MANIFEST" ]; then
  echo "CRITICAL  <file>  manifest not found: $MANIFEST" >&2
  exit 2
fi

# Read CSP via Python, passing the path as argv[1] (no shell interpolation
# into the script body, so paths with quotes/spaces are safe).
read_csp() {
  python3 - "$MANIFEST" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as f:
        m = json.load(f)
except Exception as e:
    print(f"error:{e}")
    sys.exit(0)
csp = m.get("content_security_policy")
if csp is None:
    print("none|")
elif isinstance(csp, str):
    print(f"string|{csp}")
elif isinstance(csp, dict):
    ext = csp.get("extension_pages", "")
    sandbox = csp.get("sandbox", "")
    # Use newline-safe separator
    print(f"object|{ext}\x1f{sandbox}")
else:
    print("unknown|")
PY
}

CSP_RAW=$(read_csp)
CSP_TYPE="${CSP_RAW%%|*}"
CSP_REST="${CSP_RAW#*|}"

critical=0

case "$CSP_TYPE" in
  error:*)
    echo "CRITICAL  <file>  cannot parse manifest: ${CSP_TYPE#error:}" >&2
    exit 2
    ;;
  none)
    echo "WARNING   content_security_policy  not declared. MV3 has safe defaults but explicit CSP is best practice."
    ;;
  string)
    echo "CRITICAL  content_security_policy  is a string (MV2 form). MV3 requires an object with 'extension_pages' and/or 'sandbox' keys."
    critical=$((critical + 1))
    ;;
  object)
    EXT_PAGES="${CSP_REST%%$'\x1f'*}"
    SANDBOX="${CSP_REST#*$'\x1f'}"

    if echo "$EXT_PAGES" | grep -q "unsafe-eval"; then
      echo "CRITICAL  content_security_policy.extension_pages  contains 'unsafe-eval'. Forbidden in MV3."
      critical=$((critical + 1))
    fi
    if echo "$EXT_PAGES" | grep -q "unsafe-inline"; then
      echo "CRITICAL  content_security_policy.extension_pages  contains 'unsafe-inline'. Strongly discouraged; refactor inline handlers."
      critical=$((critical + 1))
    fi
    if echo "$EXT_PAGES" | grep -qE "https?://[^ ;]+"; then
      MATCHES=$(echo "$EXT_PAGES" | grep -oE "https?://[^ ;]+" | tr '\n' ' ')
      echo "CRITICAL  content_security_policy.extension_pages  contains remote sources: $MATCHES. MV3 forbids remote code."
      critical=$((critical + 1))
    fi
    if [ -n "$EXT_PAGES" ] && ! echo "$EXT_PAGES" | grep -q "script-src"; then
      echo "INFO      content_security_policy.extension_pages  no explicit script-src. Add 'script-src \\'self\\';' for clarity."
    fi
    if [ -n "$EXT_PAGES" ] && ! echo "$EXT_PAGES" | grep -q "object-src"; then
      echo "INFO      content_security_policy.extension_pages  no explicit object-src. Add 'object-src \\'self\\';' for safety."
    fi

    # Sandbox is allowed to be looser, but flag remote sources for visibility
    if echo "$SANDBOX" | grep -qE "https?://[^ ;]+"; then
      echo "WARNING   content_security_policy.sandbox  contains remote sources. Sandbox pages can load remote content but be intentional."
    fi
    ;;
  *)
    echo "CRITICAL  content_security_policy  unexpected type"
    critical=$((critical + 1))
    ;;
esac

echo ""
echo "── CSP validation: critical=$critical ──"
# Exit-code contract: 1 if any critical finding, 0 otherwise (not the raw count).
exit $((critical > 0 ? 1 : 0))
