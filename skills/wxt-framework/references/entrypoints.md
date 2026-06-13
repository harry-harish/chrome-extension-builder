# WXT entrypoints — file conventions

WXT discovers entrypoints by directory layout. Each entrypoint becomes a corresponding manifest entry.

```
entrypoints/
├── background.ts              → background.service_worker
├── content.ts                 → single content_scripts entry
├── content/                   → multiple content scripts as files under content/
│   ├── github.ts              → content_scripts entry matching GitHub
│   └── reddit.ts              → another content_scripts entry
├── popup/                     → action.default_popup
│   ├── index.html             # WXT generates this if you only have main.tsx
│   ├── main.tsx               # React entry
│   └── App.tsx
├── options/                   → options_page
│   ├── index.html
│   └── main.tsx
├── sidepanel/                 → side_panel.default_path (requires sidePanel perm)
│   ├── index.html
│   └── main.tsx
├── devtools/                  → devtools_page
│   ├── devtools.html
│   └── devtools.ts
├── devtools-panel/            → custom panel created from devtools.ts
│   └── main.tsx
├── newtab/                    → chrome_url_overrides.newtab
└── injected/                  → page-world scripts (not in manifest; chrome.scripting at runtime)
    └── provider.ts
```

## background.ts

```ts
import { defineBackground } from 'wxt/utils/define-background';

export default defineBackground({
  type: 'module',          // ES module SW (modern; preferred)
  persistent: false,       // (default for MV3; explicit for clarity)
  main() {
    console.log('Background SW started');

    chrome.runtime.onInstalled.addListener((details) => {
      if (details.reason === 'install') {
        // first install
      }
    });

    chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
      // dispatch...
      return true;  // async response
    });
  },
});
```

Notes:

- The `main()` function runs every time the SW wakes up. Don't put initialization there that should only run once on install — use `onInstalled`.
- Don't use global `setInterval` — use `chrome.alarms`. SWs suspend.
- Imports are real ES module imports; WXT bundles them into a single SW file.

## Content scripts

Single content script (most common):

```ts
// entrypoints/content.ts
import { defineContentScript } from 'wxt/utils/define-content-script';

export default defineContentScript({
  matches: ['*://github.com/*'],
  runAt: 'document_idle',
  allFrames: false,
  matchAboutBlank: false,
  excludeMatches: ['*://github.com/settings/*'],
  cssInjectionMode: 'ui',       // or 'manifest' or 'manual'
  main(ctx) {
    // ctx is a ContentScriptContext with abort signal
    console.log('Content script loaded');

    // Optional: handle invalidation when extension reloads
    ctx.onInvalidated(() => {
      console.log('content script invalidated; cleanup');
    });

    // Use ctx.signal for AbortController-aware APIs
    window.addEventListener('click', handler, { signal: ctx.signal });
  },
});
```

Multiple content scripts — put them under `entrypoints/content/`:

```ts
// entrypoints/content/github.ts
export default defineContentScript({ matches: ['*://github.com/*'], main(ctx) { /* ... */ } });

// entrypoints/content/reddit.ts
export default defineContentScript({ matches: ['*://reddit.com/*'], main(ctx) { /* ... */ } });
```

Each file becomes a separate `content_scripts` entry. Narrower `matches` per file = less to load on any given page.

## Popup, options, side panel — UI surfaces

Each is a small HTML + JS app. With the React module:

```tsx
// entrypoints/popup/main.tsx
import React from 'react';
import { createRoot } from 'react-dom/client';
import './style.css';
import App from './App';

createRoot(document.getElementById('app')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
```

```tsx
// entrypoints/popup/App.tsx
export default function App() {
  return <div>Hello popup</div>;
}
```

You can write `entrypoints/popup/index.html` explicitly if you want control over `<head>`. Otherwise WXT generates a minimal one.

### Popup sizing

CSS sizing applies; popups are constrained to 800×600 max. Start with a fixed size:

```css
body { width: 360px; min-height: 200px; }
```

### Options page

Two forms:

```ts
// Option 1 (preferred): full options page
manifest: {
  options_page: 'options.html',
}
```

```ts
// Option 2: embedded options
manifest: {
  options_ui: { page: 'options.html', open_in_tab: false },
}
```

`open_in_tab: false` opens options inline within `chrome://extensions`. Most users prefer `options_page` (full tab).

### Side panel

```ts
// entrypoints/sidepanel/main.tsx
// (same React/Vue/Svelte pattern as popup)
```

```ts
// wxt.config.ts
manifest: {
  permissions: ['sidePanel'],
  side_panel: { default_path: 'sidepanel.html' },
},
```

Open programmatically:

```ts
chrome.action.onClicked.addListener(async (tab) => {
  await chrome.sidePanel.open({ tabId: tab.id });
});
```

Or set per-tab:

```ts
await chrome.sidePanel.setOptions({
  tabId: tab.id,
  path: 'sidepanel.html',
  enabled: true,
});
```

## DevTools panel

Two-file pattern:

```html
<!-- entrypoints/devtools/devtools.html -->
<!DOCTYPE html>
<script src="devtools.ts" type="module"></script>
```

```ts
// entrypoints/devtools/devtools.ts
chrome.devtools.panels.create(
  'My Panel',
  '/icon/48.png',
  'devtools-panel.html',
  () => {
    console.log('Panel created');
  },
);
```

```tsx
// entrypoints/devtools-panel/main.tsx
import { createRoot } from 'react-dom/client';
import App from './App';

createRoot(document.getElementById('app')!).render(<App />);
```

Wire `manifest.devtools_page` automatically via the entrypoint convention; no manual config needed.

## Injected (page-world) scripts

These aren't manifest entries; you load them via `chrome.scripting.executeScript({ world: 'MAIN' })`. Place them under `entrypoints/injected/`:

```ts
// entrypoints/injected/provider.ts
(function() {
  if (window.myExt) return;
  window.myExt = { /* in-page API */ };
})();
```

WXT bundles `entrypoints/injected/*.ts` to `.output/chrome-mv3/injected/*.js`. Register as `web_accessible_resources` if you load them via classic `<script>` injection, or call `chrome.scripting.executeScript({ files: ['/injected/provider.js'] })` from background.

```ts
// wxt.config.ts
manifest: {
  web_accessible_resources: [
    {
      resources: ['injected/*.js'],
      matches: ['<all_urls>'],
    },
  ],
}
```

## New-tab override

```tsx
// entrypoints/newtab/main.tsx
import { createRoot } from 'react-dom/client';
import App from './App';
createRoot(document.getElementById('app')!).render(<App />);
```

```ts
// wxt.config.ts
manifest: {
  chrome_url_overrides: { newtab: 'newtab.html' },
}
```

Users notice new-tab overrides immediately and often uninstall. Reconsider whether a side panel would do.

## Per-entrypoint manifest extras

You can override per-entrypoint:

```ts
export default defineContentScript({
  matches: ['*://github.com/*'],
  runAt: 'document_idle',
  cssInjectionMode: 'manifest',  // emits content_scripts.css instead of injecting at runtime
});
```

```ts
export default defineBackground({
  type: 'module',
  persistent: false,
});
```

These translate into the generated manifest's fields.

## When not to use an entrypoint

Some "surfaces" aren't really surfaces:

- "I want to handle a context menu click" → no entrypoint; `chrome.contextMenus.create` + `chrome.contextMenus.onClicked` in `background.ts`.
- "I want a keyboard shortcut" → manifest `commands` + `chrome.commands.onCommand` listener.
- "I want to react to web navigation" → `chrome.webNavigation` listeners in background.

These all live in `background.ts`, not as separate entrypoints.

## Debugging entrypoints

In dev (`pnpm wxt dev`), Chrome's `chrome://extensions` page shows:

- **service worker** link → opens devtools attached to your background SW.
- Each content script and popup is debuggable in the page's devtools.

If your entrypoint isn't loading, check:

1. WXT terminal output for build errors.
2. `chrome://extensions/?errors=<extension-id>` for runtime errors.
3. The generated `.output/chrome-mv3/manifest.json` — does it reference your file?
