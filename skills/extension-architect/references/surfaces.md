# Extension surfaces — when to use which

A Manifest V3 extension can declare these surfaces:

| Surface | Manifest key | When to use |
|---|---|---|
| Browser action (toolbar) | `action` | Always — every extension should have a toolbar icon, even if it just opens options |
| Popup | `action.default_popup` | Brief interactions (≤30s); closes on click-outside |
| Options page | `options_page` or `options_ui` | Configuration |
| Side panel | `side_panel.default_path` | Persistent UI while user browses; requires `sidePanel` perm |
| Content scripts | `content_scripts[]` | DOM manipulation, page enhancement |
| Background service worker | `background.service_worker` | Coordination layer; ephemeral |
| DevTools panel | `devtools_page` | Custom dev tools |
| New-tab override | `chrome_url_overrides.newtab` | Replace the new-tab page (rarely a good idea) |
| Bookmarks/history overrides | `chrome_url_overrides.bookmarks/history` | Even more rarely justified |
| Omnibox | `omnibox.keyword` | Keyword-triggered actions in the address bar |
| Context menus | (registered at runtime via `chrome.contextMenus`) | Right-click actions |

## Trade-offs

### Popup vs. options vs. side panel

- **Popup**: tiny, closes immediately on click-outside or focus loss. State resets unless you persist to `chrome.storage`. Don't try to fit a complex form in a popup.
- **Options page**: full-page React app, ideal for settings. Persists URL-addressable state. Use `chrome.storage.sync` for prefs that sync across browsers.
- **Side panel**: persists while the user browses. Best for ongoing tasks (notes, AI chat, comparison shopping). Requires `"sidePanel"` permission.

### Content scripts: when to inject vs. when to ask user

Content scripts run on pages matching `content_scripts[].matches`. The narrower the pattern, the safer the extension:

- ✅ `["*://*.github.com/*"]` — narrow, only GitHub
- ⚠️ `["*://*.example.com/*", "*://*.example.net/*"]` — multiple specific origins
- ❌ `["<all_urls>"]` — fires on every page; triggers CWS manual review and the broad warning

Alternative: don't declare `content_scripts` at all; inject on user invocation with `chrome.scripting.executeScript({ target: { tabId }, files: ['cs.js'] })` plus `chrome.activeTab`. Zero install-time warnings.

### Background SW: lifecycle

- **Wakes up** on any registered event (`onMessage`, `onAlarm`, `onInstalled`, `onClicked`, …).
- **Suspends** after ~30s of inactivity. State in memory is lost.
- **Persist** anything you need across wakeups via `chrome.storage.local`/`session`/`sync`.
- **Don't** use timers (`setInterval`) — use `chrome.alarms.create` instead.
- **Don't** rely on global state. Re-hydrate from storage on wake.

Pattern: SW as dispatcher. On message, look up the handler in a registry, call it, persist any state changes, return response. Done.

```ts
// entrypoints/background.ts
const handlers: Record<string, (cmd: Cmd) => Promise<unknown>> = {
  getTabs: async () => chrome.tabs.query({}),
  // ...
};

chrome.runtime.onMessage.addListener((cmd, _sender, sendResponse) => {
  const handler = handlers[cmd.type];
  if (!handler) {
    sendResponse({ error: `Unknown command: ${cmd.type}` });
    return;
  }
  handler(cmd).then((result) => sendResponse({ ok: true, result }))
              .catch((err) => sendResponse({ ok: false, error: String(err) }));
  return true;  // async response
});
```

### DevTools panel: the MV3 way

Under MV3, you cannot inject into the page world from a content script the way MV2 allowed. React DevTools' approach (also documented in their README) is the canonical pattern:

1. `devtools_page` declares an HTML page that runs in the devtools context.
2. That page uses `chrome.devtools.inspectedWindow.eval` or `chrome.scripting.executeScript({ target, world: 'MAIN' })` to inject into the inspected page.
3. The injected page-world script communicates back via `window.postMessage` with strict origin/nonce checks.

See `references/devtools-injection.md` for the full pattern.

### New-tab override: think twice

Users notice new-tab overrides and often uninstall. Consider:

- Is the override actually offering more value than the default new-tab page?
- Could you do this as a side panel instead?
- Is it bundling unwanted ads/links?

If you must, keep it lightweight, no telemetry, no tracking, fast to load.

## Surface combinations

Most extensions use 2–3 surfaces. Examples:

- **Productivity** (Refined GitHub): toolbar action + many content scripts on github.com
- **Privacy** (uBlock Origin Lite): toolbar action + declarativeNetRequest rules + minimal background
- **Password manager** (Bitwarden): toolbar action + popup + options + content script (autofill) + background
- **Theme/style** (Dark Reader): toolbar action + popup + background + content script on all pages
- **Userscript host** (Violentmonkey): toolbar action + popup + options + 80+ feature contents + background

## When you don't need a surface

- "I want to schedule a daily task" → `chrome.alarms`, no popup needed.
- "I want a right-click action" → `chrome.contextMenus`, no popup needed.
- "I want a keyboard shortcut" → `commands` in manifest, plus `chrome.commands.onCommand`.
- "I want to detect when a tab matching X is opened" → `chrome.webNavigation` in background.

Avoid creating surfaces just because you can.
