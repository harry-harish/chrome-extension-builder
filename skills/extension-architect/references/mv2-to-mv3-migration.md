# MV2 → MV3 migration

## Status (2026)

- **Chrome**: MV2 fully removed in Chrome 139 (2025-07-24). Enterprise re-enable policy expired June 2025.
- **Firefox**: still supports MV2 alongside MV3. If your only target is Firefox, migration is optional.
- **Edge**: follows Chrome's timeline.
- **Safari**: its own format (Safari Web Extensions); MV3 mostly compatible but with quirks.

For any Chrome-targeted extension in 2026, migration is mandatory.

## The delta

### Manifest changes

| MV2 | MV3 |
|---|---|
| `manifest_version: 2` | `manifest_version: 3` |
| `background.scripts: [...]` | `background.service_worker: "bg.js"` (single file, ES module if `type: "module"`) |
| `background.persistent: true` | (remove; SWs are ephemeral) |
| `browser_action` | `action` |
| `page_action` | `action` (use `chrome.action.disable/enable` for conditional display) |
| `content_security_policy: "..."` (string) | `content_security_policy: { extension_pages: "...", sandbox: "..." }` (object) |
| `web_accessible_resources: ["a.png", "b.png"]` (string array) | `web_accessible_resources: [{ resources: [...], matches: [...] }]` (object array) |
| `optional_permissions: ["<all_urls>"]` | `optional_host_permissions: ["<all_urls>"]` (split between permissions and host permissions) |
| `permissions: ["webRequestBlocking"]` | `declarativeNetRequest` static or dynamic rules |

### API changes

| MV2 API | MV3 replacement |
|---|---|
| `chrome.tabs.executeScript(tabId, { file: 'cs.js' })` | `chrome.scripting.executeScript({ target: { tabId }, files: ['cs.js'] })` |
| `chrome.tabs.insertCSS(tabId, { file: 'cs.css' })` | `chrome.scripting.insertCSS({ target: { tabId }, files: ['cs.css'] })` |
| `chrome.extension.getBackgroundPage()` | (gone) Send a message to the SW instead |
| `chrome.runtime.onMessageExternal` with allowlist | Same, but stricter validation; declare `externally_connectable` |
| `chrome.webRequest.onBeforeRequest` with `["blocking"]` | `declarativeNetRequest` static rulesets (build-time) or dynamic rules |
| `chrome.extension.connectNative` | `chrome.runtime.connectNative` (same, namespace moved) |
| XHR sync mode in content script | Always async; use `fetch` |
| `eval()` and `new Function()` in extension pages | Forbidden by MV3 CSP |
| Inline event handlers (`<button onclick>`) | Forbidden by MV3 CSP |
| Remote-hosted scripts (`<script src="cdn://">`) | Forbidden by MV3 CSP |

### Architectural changes

1. **Background page → service worker.**
   - SW is ephemeral; in-memory state vanishes after ~30s idle.
   - `setInterval` doesn't work reliably → use `chrome.alarms`.
   - Singleton state → use `chrome.storage.session` or `chrome.storage.local`.
   - SWs can't access `document`, `window`, `XMLHttpRequest`, `localStorage`. They have `self`, `fetch`, `crypto.subtle`, `indexedDB`.

2. **CSP is stricter.**
   - No `unsafe-eval` in extension pages.
   - No remote scripts.
   - Inline scripts in HTML are forbidden by default (use external files).
   - This breaks libraries that use `eval()` (some templating engines, some JIT WASM loaders).

3. **DevTools injection model.**
   - The MV2 trick of injecting via the content script into the page world no longer works the same way.
   - Use `chrome.scripting.executeScript({ world: 'MAIN' })` — only available on Chrome ≥102.
   - React DevTools' migration story is the reference (`docs.react-devtools/MIGRATION.md`).

## Step-by-step migration

### 1. Update manifest

```diff
- "manifest_version": 2,
+ "manifest_version": 3,
  "name": "...",
  "version": "1.0.0",

- "background": {
-   "scripts": ["background.js"],
-   "persistent": false
- },
+ "background": {
+   "service_worker": "background.js"
+ },

- "browser_action": {
-   "default_popup": "popup.html"
- },
+ "action": {
+   "default_popup": "popup.html"
+ },

- "content_security_policy": "script-src 'self'; object-src 'self'",
+ "content_security_policy": {
+   "extension_pages": "script-src 'self'; object-src 'self'"
+ },

- "web_accessible_resources": ["images/*", "styles/*"],
+ "web_accessible_resources": [
+   {
+     "resources": ["images/*", "styles/*"],
+     "matches": ["<all_urls>"]
+   }
+ ],

- "permissions": ["tabs", "webRequest", "webRequestBlocking", "<all_urls>"],
+ "permissions": ["tabs", "declarativeNetRequest"],
+ "host_permissions": ["<all_urls>"]
```

### 2. Convert background

If you had multiple background scripts (`background.scripts: [a.js, b.js, c.js]`), bundle into one entry file.

```diff
- // a.js
- chrome.browserAction.onClicked.addListener(...)
+ // background.js (single entry)
+ import { initA } from './a';
+ import { initB } from './b';
+ initA();
+ initB();
+ chrome.action.onClicked.addListener(...)
```

Replace `chrome.browserAction.*` → `chrome.action.*`.

Move any singleton state from globals into `chrome.storage`:

```diff
- let cachedTabs = {};
- chrome.tabs.onUpdated.addListener(/* ... */);
+ chrome.tabs.onUpdated.addListener(async (tabId, change) => {
+   const { cachedTabs = {} } = await chrome.storage.session.get('cachedTabs');
+   cachedTabs[tabId] = change;
+   await chrome.storage.session.set({ cachedTabs });
+ });
```

Replace `setInterval` with `chrome.alarms`:

```diff
- setInterval(refresh, 30_000);
+ chrome.alarms.create('refresh', { periodInMinutes: 0.5 });
+ chrome.alarms.onAlarm.addListener((a) => { if (a.name === 'refresh') refresh(); });
```

### 3. Convert API calls

```diff
- chrome.tabs.executeScript(tabId, { file: 'cs.js' });
+ await chrome.scripting.executeScript({ target: { tabId }, files: ['cs.js'] });

- chrome.tabs.insertCSS(tabId, { file: 'cs.css' });
+ await chrome.scripting.insertCSS({ target: { tabId }, files: ['cs.css'] });

- const bg = chrome.extension.getBackgroundPage();
- bg.doSomething();
+ await chrome.runtime.sendMessage({ type: 'doSomething' });
```

Grep for these in your codebase:

```bash
grep -rn 'chrome\.tabs\.executeScript\|chrome\.tabs\.insertCSS\|chrome\.extension\.getBackgroundPage' src/
```

### 4. Convert webRequest blocking → declarativeNetRequest

This is the hardest step. `webRequest.onBeforeRequest` with `["blocking"]` is removed; you can still observe but not block at runtime (without enterprise enrollment).

Static rules at build time:

```json
{
  "permissions": ["declarativeNetRequest"],
  "declarative_net_request": {
    "rule_resources": [
      {
        "id": "default_rules",
        "enabled": true,
        "path": "rules.json"
      }
    ]
  }
}
```

`rules.json`:

```json
[
  {
    "id": 1,
    "priority": 1,
    "action": { "type": "block" },
    "condition": { "urlFilter": "||doubleclick.net^", "resourceTypes": ["script"] }
  }
]
```

Dynamic rules at runtime (per-user customization):

```ts
await chrome.declarativeNetRequest.updateDynamicRules({
  addRules: [{ id: 1001, priority: 1, action: { type: 'block' }, condition: { urlFilter: '||evil.com^' } }],
  removeRuleIds: [],
});
```

Quotas: per Chrome's docs, "a 300,000-rule shared pool plus a 30,000-rule guaranteed allowance per extension." uBO Lite's build pipeline compiles EasyList syntax to DNR; see `examples/ubo-lite-pattern.md`.

### 5. Convert CSP

```diff
- "content_security_policy": "script-src 'self' 'unsafe-eval'; object-src 'self'"
+ "content_security_policy": {
+   "extension_pages": "script-src 'self'; object-src 'self'"
+ }
```

If you can't avoid `eval` (some templating libs), move that code into a sandbox page:

```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'",
    "sandbox": "sandbox allow-scripts; script-src 'self' 'unsafe-eval';"
  },
  "web_accessible_resources": [
    { "resources": ["sandbox.html"], "matches": ["<all_urls>"] }
  ]
}
```

Use `chrome.runtime.getURL('sandbox.html')` to load it in an iframe; communicate via `postMessage`.

### 6. Convert web_accessible_resources

```diff
- "web_accessible_resources": ["a.png", "b.png"]
+ "web_accessible_resources": [{
+   "resources": ["a.png", "b.png"],
+   "matches": ["<all_urls>"]
+ }]
```

If you only want specific origins to load the resource, narrow `matches`. If you only want specific other extensions to load it, use `extension_ids` instead of `matches`.

### 7. Test

After all changes:

```bash
# Re-run validators
python3 ${CLAUDE_PLUGIN_ROOT}/skills/extension-architect/scripts/validate-manifest.py manifest.json

# Lint with web-ext
pnpm dlx web-ext@latest lint --self-hosted

# Load unpacked in Chrome 120+ and exercise every flow
```

Common failures after migration:
- **"Refused to execute inline script"** → move inline `<script>...</script>` to external file.
- **"Service worker registration failed"** → check `background.service_worker` file exists; check for syntax errors via the SW devtools panel (`chrome://extensions` → "service worker").
- **"window is not defined"** → SW doesn't have `window`. Replace `window.X` with `self.X` or refactor.
- **Storage looks empty** → in-memory globals lost across SW restarts. Move to `chrome.storage.session`.

## Tooling

- **GoogleChromeLabs/extension-manifest-converter** — auto-converts some manifest fields.
- **Chrome's official migration docs**: `developer.chrome.com/docs/extensions/develop/migrate`.
- **Firefox's MV3 docs** for cross-browser nuances: `extensionworkshop.com/documentation/develop/manifest-v3-migration-guide`.

## When to NOT migrate

If you target only Firefox: Firefox supports MV2 alongside MV3. You can stay on MV2 in Firefox, but you'll forgo Chrome distribution entirely.

If your extension uses `webRequestBlocking` in a fundamental way (e.g., a complex ad blocker with runtime rule modification) and you can't fit into declarativeNetRequest's quotas: the original `uBlock Origin` (not Lite) chose to drop Chrome support rather than migrate. This is a legitimate but painful choice.
