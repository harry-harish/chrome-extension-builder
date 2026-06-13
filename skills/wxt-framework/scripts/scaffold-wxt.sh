#!/usr/bin/env bash
# scaffold-wxt.sh — Non-interactive WXT scaffold.
#
# Usage: scaffold-wxt.sh <project-name> [template] [package-manager]
#
# Defaults: template=react, package-manager=pnpm.
# Templates: vanilla, react, vue, svelte, solid.
#
# `wxt init` is interactive (prompts for template + PM). This script writes
# the minimal project files directly and runs `<pm> install`, so it is safe
# to invoke from a headless agent. The resulting project is functionally
# equivalent to `wxt init --template <template>` plus the i18n/CSP defaults
# the plugin recommends.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <project-name> [template] [package-manager]" >&2
  exit 2
fi

PROJECT="$1"
TEMPLATE="${2:-react}"
PM="${3:-pnpm}"

if [ -e "$PROJECT" ]; then
  echo "Error: '$PROJECT' already exists." >&2
  exit 1
fi

case "$PM" in
  pnpm|npm|yarn|bun) ;;
  *) echo "Error: unknown package manager '$PM'. Use pnpm|npm|yarn|bun." >&2; exit 2 ;;
esac

case "$TEMPLATE" in
  vanilla|react|vue|svelte|solid) ;;
  *) echo "Error: unknown template '$TEMPLATE'. Use vanilla|react|vue|svelte|solid." >&2; exit 2 ;;
esac

if ! command -v "$PM" >/dev/null 2>&1; then
  echo "Error: '$PM' is not installed. Install it first." >&2
  exit 2
fi

echo "── Scaffolding $PROJECT (template=$TEMPLATE, pm=$PM) ──"

mkdir -p "$PROJECT"/{entrypoints/popup,public/_locales/en,public/icon,docs}
cd "$PROJECT"

# ── package.json ───────────────────────────────────────────────────
cat > package.json <<EOF
{
  "name": "$PROJECT",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "wxt",
    "dev:firefox": "wxt -b firefox",
    "build": "wxt build",
    "build:firefox": "wxt build -b firefox",
    "zip": "wxt zip",
    "zip:firefox": "wxt zip -b firefox",
    "compile": "tsc --noEmit",
    "postinstall": "wxt prepare"
  },
  "devDependencies": {
    "wxt": "~0.20.26",
    "typescript": "^5.5.0"
  }
}
EOF

# Add framework-specific deps
case "$TEMPLATE" in
  react)
    python3 - <<'PY'
import json
m = json.load(open('package.json'))
m['dependencies'] = {'react': '^18.3.0', 'react-dom': '^18.3.0'}
m['devDependencies']['@types/react'] = '^18.3.0'
m['devDependencies']['@types/react-dom'] = '^18.3.0'
m['devDependencies']['@wxt-dev/module-react'] = '^1.1.0'
json.dump(m, open('package.json', 'w'), indent=2)
PY
    ;;
  vue)
    python3 - <<'PY'
import json
m = json.load(open('package.json'))
m['dependencies'] = {'vue': '^3.4.0'}
m['devDependencies']['@wxt-dev/module-vue'] = '^1.0.0'
json.dump(m, open('package.json', 'w'), indent=2)
PY
    ;;
  svelte)
    python3 - <<'PY'
import json
m = json.load(open('package.json'))
m['dependencies'] = {'svelte': '^4.2.0'}
m['devDependencies']['@wxt-dev/module-svelte'] = '^1.0.0'
json.dump(m, open('package.json', 'w'), indent=2)
PY
    ;;
  solid)
    python3 - <<'PY'
import json
m = json.load(open('package.json'))
m['dependencies'] = {'solid-js': '^1.8.0'}
m['devDependencies']['@wxt-dev/module-solid'] = '^1.0.0'
json.dump(m, open('package.json', 'w'), indent=2)
PY
    ;;
esac

# ── wxt.config.ts ─────────────────────────────────────────────────
# Build the modules line conditionally so non-matching templates leave no
# blank lines in the output.
case "$TEMPLATE" in
  react)  MODULES_LINE="  modules: ['@wxt-dev/module-react']," ;;
  vue)    MODULES_LINE="  modules: ['@wxt-dev/module-vue']," ;;
  svelte) MODULES_LINE="  modules: ['@wxt-dev/module-svelte']," ;;
  solid)  MODULES_LINE="  modules: ['@wxt-dev/module-solid']," ;;
  *)      MODULES_LINE="" ;;
esac

{
  echo "import { defineConfig } from 'wxt';"
  echo ""
  echo "export default defineConfig({"
  if [ -n "$MODULES_LINE" ]; then
    echo "$MODULES_LINE"
  fi
  cat <<'EOF'
  manifest: {
    name: '__MSG_extension_name__',
    description: '__MSG_extension_description__',
    default_locale: 'en',
    permissions: ['storage', 'activeTab'],
    optional_host_permissions: [],
    action: {
      default_title: '__MSG_action_title__',
    },
    content_security_policy: {
      extension_pages: "script-src 'self'; object-src 'self'; base-uri 'self'",
    },
  },
});
EOF
} > wxt.config.ts

# ── tsconfig.json (extends WXT's generated config) ────────────────
cat > tsconfig.json <<'EOF'
{
  "extends": "./.wxt/tsconfig.json",
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true
  }
}
EOF

# ── .gitignore ────────────────────────────────────────────────────
cat > .gitignore <<'EOF'
node_modules/
.output/
.wxt/
*.log
.DS_Store
.env
.env.local
EOF

# ── entrypoints/background.ts ─────────────────────────────────────
cat > entrypoints/background.ts <<'EOF'
import { defineBackground } from 'wxt/utils/define-background';

export default defineBackground({
  type: 'module',
  main() {
    chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
      if (sender.id !== chrome.runtime.id) {
        sendResponse({ error: 'untrusted-sender' });
        return;
      }
      // dispatch to handlers
      if (cmd?.type === 'ping') {
        sendResponse({ ok: true, pong: Date.now() });
        return;
      }
      sendResponse({ error: `unknown command: ${cmd?.type}` });
    });
  },
});
EOF

# ── entrypoints/popup ─────────────────────────────────────────────
case "$TEMPLATE" in
  react)
    cat > entrypoints/popup/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>Popup</title>
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="./main.tsx"></script>
  </body>
</html>
EOF
    cat > entrypoints/popup/main.tsx <<'EOF'
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

createRoot(document.getElementById('app')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
EOF
    cat > entrypoints/popup/App.tsx <<'EOF'
export default function App() {
  return (
    <main style={{ padding: 16, minWidth: 280 }}>
      <h1>{chrome.i18n.getMessage('extension_name')}</h1>
      <p>Edit entrypoints/popup/App.tsx to customize.</p>
    </main>
  );
}
EOF
    ;;
  vanilla)
    cat > entrypoints/popup/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head><meta charset="UTF-8" /><title>Popup</title></head>
  <body><h1 id="title"></h1><script type="module" src="./main.ts"></script></body>
</html>
EOF
    cat > entrypoints/popup/main.ts <<'EOF'
document.getElementById('title')!.textContent = chrome.i18n.getMessage('extension_name');
EOF
    ;;
  *)
    cat > entrypoints/popup/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
  <head><meta charset="UTF-8" /><title>Popup</title></head>
  <body>
    <h1>$PROJECT</h1>
    <p>$TEMPLATE template — fill in entrypoints/popup/.</p>
  </body>
</html>
EOF
    ;;
esac

# ── i18n ──────────────────────────────────────────────────────────
cat > public/_locales/en/messages.json <<EOF
{
  "extension_name": {
    "message": "$PROJECT",
    "description": "Shown in toolbar tooltip and Chrome Web Store listing"
  },
  "extension_description": {
    "message": "A new browser extension built with WXT.",
    "description": "Short description (≤132 chars for CWS)"
  },
  "action_title": {
    "message": "Open $PROJECT",
    "description": "Tooltip on the toolbar icon"
  }
}
EOF

# ── docs/ placeholders ────────────────────────────────────────────
cat > docs/store-listing.md <<'EOF'
# Store Listing

## Single-purpose statement
<fill in>

## Short description (≤132 chars)
<fill in>

## Detailed description
<fill in>

## Privacy policy URL
<fill in>
EOF

cat > docs/screenshots-spec.md <<'EOF'
# Screenshots Spec

Dimensions: 1280×800 (preferred) or 640×400. PNG or JPEG.

## Screenshot 1 — Primary value prop
<describe>
EOF

# ── README ────────────────────────────────────────────────────────
cat > README.md <<EOF
# $PROJECT

A WXT-based Chrome extension.

## Develop

\`\`\`
$PM install
$PM dev
\`\`\`

## Build

\`\`\`
$PM build
$PM zip
\`\`\`

---

_Scaffolded with [Chrome Extension Builder](https://github.com/harry-harish/chrome-extension-builder), a Claude Code plugin. This line is safe to remove._
EOF

# ── Install deps ──────────────────────────────────────────────────
echo "── Running $PM install ──"
"$PM" install

echo ""
echo "── Done ────────────────────────────────────"
echo "Next: cd $PROJECT && $PM dev"
