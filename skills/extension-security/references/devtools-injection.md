# DevTools injection under MV3

## The problem

In MV2, you could inject a page-world script by appending `<script src="…">` from a content script. The page would execute it in the page's main world.

MV3 disallows that. Per React DevTools' own README: *"As we migrate to a Chrome Extension Manifest V3, we start to use a new method to hook the DevTools with the inspected page. This new method is more secure, but relies on a new API that's only supported in Chrome v102+."*

## The MV3 approach: `chrome.scripting.executeScript({ world: 'MAIN' })`

```ts
// background.ts
chrome.scripting.executeScript({
  target: { tabId },
  world: 'MAIN',           // runs in the page's main world
  files: ['inject/page-world.js'],
  injectImmediately: true,  // before page scripts (Chrome ≥111)
});
```

The injected script lives in the page's JS world. It has `window`, `document`, access to page globals — but **no `chrome.*` APIs**.

## DevTools architecture

A devtools extension typically has four pieces:

```
1. devtools.html              # loaded in the devtools context
2. devtools.js                # creates the devtools panel
3. panel.html / panel.js      # the actual UI of your custom panel
4. content-script.js + inject/page-world.js   # the bridge to the inspected page
```

### devtools.html and devtools.js

`manifest.json`:

```json
{
  "devtools_page": "devtools.html"
}
```

`devtools.html`:

```html
<!DOCTYPE html>
<script src="devtools.js"></script>
```

`devtools.js`:

```ts
chrome.devtools.panels.create(
  'My Panel',                      // tab name
  'icon.png',
  'panel.html',
  (panel) => {
    panel.onShown.addListener((win) => {
      // panel was shown
    });
    panel.onHidden.addListener(() => {
      // panel was hidden
    });
  },
);
```

### panel.html and panel.js

The custom panel is just an extension page rendered inside the devtools chrome. It has access to `chrome.devtools.*`:

```ts
// panel.js
const tabId = chrome.devtools.inspectedWindow.tabId;

// Talk to the page via inspectedWindow.eval or via the background
chrome.devtools.inspectedWindow.eval(
  'window.getElementById("foo")?.outerHTML',
  (result, isException) => {
    if (!isException) console.log(result);
  },
);
```

### Bridge to the page

`chrome.devtools.inspectedWindow.eval` is **dangerous** — it runs arbitrary code in the page's main world. Avoid for untrusted input.

The safer pattern:

1. Background SW injects a page-world script via `chrome.scripting.executeScript({ world: 'MAIN' })`.
2. The page-world script registers a fixed protocol (e.g., `window.__myExt = { ... }`).
3. Your content script in the isolated world bridges via `window.postMessage` with nonce + origin checks.
4. Your panel talks to the background, which talks to the content script.

```ts
// background.ts
chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
  if (cmd.type === 'devtools.getState') {
    // forward to the inspected tab's content script
    chrome.tabs.sendMessage(cmd.tabId, cmd, sendResponse);
    return true;
  }
});

// content.ts
chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
  if (cmd.type === 'devtools.getState') {
    // postMessage to page-world script with a nonce
    const requestId = crypto.randomUUID();
    pending.set(requestId, sendResponse);
    window.postMessage({
      source: 'devtools-cs',
      requestId,
      nonce: PAGE_NONCE,
      query: cmd.query,
    }, window.location.origin);
    return true;
  }
});

// inject/page-world.ts (injected via chrome.scripting w/ world:MAIN)
window.addEventListener('message', (e) => {
  if (e.source !== window) return;
  if (e.origin !== window.location.origin) return;
  if (e.data?.source !== 'devtools-cs') return;
  if (e.data?.nonce !== window.__ext_nonce) return;
  // ... handle, then post back with replyNonce
});
```

## React DevTools as the canonical example

React DevTools' source is the best reference. It does this dance precisely:

1. The injected page-world script (`renderer.js`) hooks into React's internal `__REACT_DEVTOOLS_GLOBAL_HOOK__`.
2. A content script bridge (`bridge.js`) shuttles messages between the hook and the extension's background.
3. The panel (`panel.html`) renders the component tree using messages from the bridge.

Their challenges (and yours):

- **The page must load React before the hook is installed.** The injected script must run at `document_start`.
- **Pages don't always have React.** Detect gracefully; don't crash the panel.
- **Source maps for variables.** React DevTools uses heuristics to display readable names; raw bundle names are unhelpful.

## Permission scope

`devtools_page` doesn't grant any extra permissions. You still need:

- `scripting` permission to use `chrome.scripting.executeScript`.
- Host permission for the URLs you'll inject into (or `activeTab` if you can rely on user invocation).

## Things to be careful about

- ❌ Don't `inspectedWindow.eval` user-supplied strings. Build a fixed protocol instead.
- ❌ Don't store anything sensitive in the page world (page code can read it).
- ❌ Don't rely on the page-world script running once — pages reload; you need to re-inject.
- ❌ Don't assume the page's main world hasn't been tampered with — frameworks can patch `window`, `Object.prototype`, etc.

## What if Chrome <102?

`world: 'MAIN'` requires Chrome ≥102. If you need older Chrome (rare in 2026), use the legacy `<script>` injection trick — but document it and plan to drop support.

```ts
// fallback: insert a <script> from the content script
const s = document.createElement('script');
s.src = chrome.runtime.getURL('inject/page-world.js');
(document.head || document.documentElement).appendChild(s);
s.remove();
```

For this to work, the script file must be in `web_accessible_resources`:

```json
{
  "web_accessible_resources": [{
    "resources": ["inject/page-world.js"],
    "matches": ["<all_urls>"]
  }]
}
```

This makes the script file URL public — every page can fetch it. That's usually fine for an injected script (it's already in the page anyway), but be aware.

## Mental model

The devtools panel is just another extension UI surface — like the popup. It happens to be rendered inside Chrome's devtools chrome and has access to `chrome.devtools.*`.

The complexity is in the bridge from the panel down to the inspected page's main world. That bridge crosses three boundaries: panel → background → content script → page-world script. Each boundary needs explicit, validated messaging.
