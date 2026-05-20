# Violentmonkey pattern — explicit four-execution-context architecture

## Source

`violentmonkey/violentmonkey` on GitHub. ~8.2k stars, MIT, JavaScript. ~50,000 LOC. Vue.js UI.

## What to copy

Violentmonkey makes the **four execution contexts** in a Chrome extension explicit. Most extensions have them implicitly and get confused. Violentmonkey's directory layout enforces the boundary.

```
src/
├── background/         # background SW context
├── content/            # content script context (isolated world)
├── injected/           # page script context (page main world)
├── popup/              # popup UI
├── options/            # options UI
└── common/             # shared utilities
```

Each context has different capabilities:

| Context | Has `chrome.*`? | Has `document`? | Has page's JS globals? |
|---|---|---|---|
| Background SW | ✅ all of it | ❌ | ❌ |
| Content script | partial (mostly `chrome.runtime.*`) | ✅ (shared with page) | ❌ (isolated) |
| Injected page script | ❌ | ✅ (shared with page) | ✅ (lives in page world) |
| Popup/options | ✅ all of it | ✅ (its own document) | ❌ |

Messages must explicitly cross context boundaries. Violentmonkey wraps `chrome.runtime.sendMessage` in `sendCmd`:

```ts
// src/common/sendCmd.ts
export async function sendCmd(cmd: string, data?: any) {
  // For fast path when background is awake, getBgPage() returns direct access
  const bg = await getBgPage();
  if (bg && bg.handleCmd) {
    return bg.handleCmd(cmd, data);  // synchronous direct call
  }
  // Fallback to async message
  return chrome.runtime.sendMessage({ cmd, data });
}
```

The `getBgPage` direct-access path is a Violentmonkey-specific optimization that bypasses message-passing serialization when both sides are in the same browser process. It also includes **retry logic for SW startup races**:

```ts
async function sendCmdReliable(cmd: string, data?: any, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      return await sendCmd(cmd, data);
    } catch (e) {
      if (i === retries - 1) throw e;
      await new Promise((r) => setTimeout(r, 100 * (i + 1)));
    }
  }
}
```

This solves: a content script loaded right as the user activates the tab might send a message before the SW has woken up. Without retry, that message is lost.

## Adaptation for your extension

### Step 1: name your contexts explicitly

In `src/`:

```
entrypoints/
├── background.ts            # background context
├── content.ts               # content context (isolated)
├── popup/index.tsx          # popup UI
└── options/index.tsx        # options UI
src/
├── injected/
│   └── page-world.ts        # injected page-world script
└── lib/
    ├── send-cmd.ts          # typed message helper
    └── trust.ts             # sender validation
```

For each file, **name the context in a comment at the top**:

```ts
// Background SW context. Has all chrome.* APIs. No DOM. Ephemeral lifecycle.
import { Cmd, CmdResponse } from '../types/messages';
```

```ts
// Content script context. Lives in the page's DOM but isolated JS world.
// Cannot access page's globals; can postMessage to inject/page-world.
```

```ts
// Injected page-world script. Lives in the page's main JS world.
// Has page's globals; NO chrome.* APIs. Communicates via window.postMessage.
```

This is documentation-as-architecture. New contributors see immediately what is and isn't allowed in each file.

### Step 2: handle SW wakeup races

Adopt the retry pattern in your `sendCmd`:

```ts
// src/lib/send-cmd.ts
import type { Cmd, CmdResponse } from '../types/messages';

export async function sendCmd<C extends Cmd>(cmd: C, retries = 3): Promise<CmdResponse<C>> {
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const response = await chrome.runtime.sendMessage(cmd);
      if (response?.error) throw new Error(response.error);
      return response;
    } catch (e) {
      if (attempt === retries - 1) throw e;
      await new Promise((r) => setTimeout(r, 100 * (attempt + 1)));
    }
  }
  throw new Error('unreachable');
}
```

### Step 3: validate sender at every boundary

```ts
// src/lib/trust.ts
import type { Cmd } from '../types/messages';

export function isTrustedSender(sender: chrome.runtime.MessageSender): boolean {
  return sender.id === chrome.runtime.id;
}

export function isFromContentScript(sender: chrome.runtime.MessageSender): boolean {
  return Boolean(sender.tab);
}

export function isFromExtensionUI(sender: chrome.runtime.MessageSender): boolean {
  return !sender.tab;
}
```

```ts
// background.ts
chrome.runtime.onMessage.addListener((cmd: Cmd, sender, sendResponse) => {
  if (!isTrustedSender(sender)) {
    sendResponse({ error: 'untrusted' });
    return;
  }

  // Some commands are only safe from extension UI, never from content scripts
  if (cmd.type === 'getVaultEntry' && isFromContentScript(sender)) {
    sendResponse({ error: 'not-allowed-from-content' });
    return;
  }

  // ... handle
});
```

The principle: just because a message has the right `extension id` doesn't mean it should be allowed to do anything. Content scripts share the page's DOM and can be manipulated. Vault unlock from a content script should never succeed.

### Step 4: page-world ↔ content-script bridge with nonces

```ts
// src/injected/page-world.ts — runs in page's main world via chrome.scripting.executeScript({world:'MAIN'})
(function() {
  const NONCE = crypto.randomUUID();

  window.postMessage({ source: 'my-ext', nonce: NONCE, type: 'init' }, window.location.origin);

  window.addEventListener('message', (event) => {
    if (event.source !== window) return;
    if (event.origin !== window.location.origin) return;
    if (event.data?.source !== 'my-ext-cs') return;
    if (event.data?.replyNonce !== NONCE) return;
    // ... handle reply from content script
  });
})();
```

```ts
// src/content/index.ts — content script (isolated world)
const PAGE_NONCE = new Map<string, string>();

window.addEventListener('message', async (event) => {
  if (event.source !== window) return;
  if (event.origin !== window.location.origin) return;
  if (event.data?.source !== 'my-ext') return;

  const nonce = event.data.nonce;
  if (!nonce) return;
  PAGE_NONCE.set(nonce, nonce);

  // Forward to background
  const result = await sendCmd({ type: 'pageRequest', payload: event.data });

  // Reply to page world with the same nonce
  window.postMessage({
    source: 'my-ext-cs',
    replyNonce: nonce,
    result,
  }, window.location.origin);
});
```

## Reproducible builds

Violentmonkey is reviewed by AMO/MEA reviewers who build from source and bit-compare against the published bundle. This requires:

1. Pinned dependency versions (commit lockfile).
2. Fixed Node version (`.nvmrc` + `package.json#engines`).
3. No timestamps in output.
4. Build script ships with the release; reviewers run it identically.

If your extension targets stores with this level of review (Firefox AMO, Edge MEA), follow Violentmonkey's `package.json` build scripts as a template.

## Why this pattern matters

The four execution contexts cause more bugs than any other source. Violentmonkey's explicit separation means:

- A buggy content script can't corrupt SW state — it can only send bad messages.
- A hostile page can't talk to the SW directly — it must go through nonce+origin checks at the content script.
- Code review becomes "is this allowed in this context?" instead of guessing.

If your extension is non-trivial (>5k LOC) and has all four contexts, adopt this layout. It pays for itself within weeks.
