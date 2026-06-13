# Messaging with WXT

WXT does not ship a built-in messaging library. (Plasmo does, via `@plasmohq/messaging`.) You roll your own typed `sendCmd`. This page covers the four-execution-context messaging model specifically as it applies to WXT projects.

For deeper trust-boundary discussion, see `extension-security/references/message-passing.md`. For the architectural pattern, see `extension-architect/references/message-passing.md`.

## The four contexts in a WXT project

| Context | WXT file(s) | Has `chrome.*`? | Notes |
|---|---|---|---|
| Background SW | `entrypoints/background.ts` | ✅ all | ephemeral; suspends after ~30s idle |
| Content script (isolated world) | `entrypoints/content.ts` or `entrypoints/content/*.ts` | partial | lives in page DOM, isolated JS |
| Page main world | `entrypoints/injected/*.ts` (loaded via `chrome.scripting.executeScript({ world: 'MAIN' })`) | ❌ | runs in the inspected page's JS env |
| Extension UI | `entrypoints/popup/`, `entrypoints/options/`, `entrypoints/sidepanel/`, `entrypoints/devtools-panel/` | ✅ all | renders as extension pages |

## Typed messages — the `sendCmd` pattern

Define a discriminated union in a shared types file:

```ts
// src/types/messages.ts
export type Cmd =
  | { type: 'ping' }
  | { type: 'getTabs' }
  | { type: 'fetchPolicy'; url: string }
  | { type: 'saveItem'; item: { id: string; data: string } };

export type CmdResponse<C extends Cmd> =
  C extends { type: 'ping' }         ? { ok: true; pong: number } :
  C extends { type: 'getTabs' }      ? chrome.tabs.Tab[] :
  C extends { type: 'fetchPolicy' }  ? { ok: true; data: string } | { ok: false; error: string } :
  C extends { type: 'saveItem' }     ? { saved: boolean } :
  never;
```

Sender helper with SW startup-race retry (Violentmonkey pattern):

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

Background dispatcher:

```ts
// entrypoints/background.ts
import { defineBackground } from 'wxt/utils/define-background';
import type { Cmd } from '../src/types/messages';

const handlers = {
  ping: async () => ({ ok: true, pong: Date.now() }),
  getTabs: async () => chrome.tabs.query({}),
  fetchPolicy: async ({ url }) => {
    const r = await fetch(url);
    return r.ok
      ? { ok: true as const, data: await r.text() }
      : { ok: false as const, error: r.statusText };
  },
  saveItem: async ({ item }) => {
    await chrome.storage.local.set({ [`item:${item.id}`]: item });
    return { saved: true };
  },
};

export default defineBackground({
  type: 'module',
  main() {
    chrome.runtime.onMessage.addListener((cmd: Cmd, sender, sendResponse) => {
      if (sender.id !== chrome.runtime.id) {
        sendResponse({ error: 'untrusted-sender' });
        return;
      }
      const handler = (handlers as any)[cmd.type];
      if (!handler) {
        sendResponse({ error: `unknown command: ${cmd.type}` });
        return;
      }
      handler(cmd)
        .then((result: unknown) => sendResponse(result))
        .catch((err: unknown) => sendResponse({ error: String(err) }));
      return true; // async response
    });
  },
});
```

Use from any other surface:

```ts
import { sendCmd } from '@/lib/send-cmd';

const tabs = await sendCmd({ type: 'getTabs' });           // tabs: chrome.tabs.Tab[]
const policy = await sendCmd({ type: 'fetchPolicy', url }); // typed union
```

## Long-lived ports

For streaming or many round-trips, use `chrome.runtime.connect`:

```ts
// content script
const port = chrome.runtime.connect({ name: 'cs-bg' });
port.postMessage({ type: 'subscribe', topic: 'tabs' });
port.onMessage.addListener((msg) => { /* ... */ });

// background
chrome.runtime.onConnect.addListener((port) => {
  if (port.name === 'cs-bg' && port.sender?.id === chrome.runtime.id) {
    port.onMessage.addListener((msg) => { /* ... */ });
  } else {
    port.disconnect();
  }
});
```

Ports auto-disconnect when the other side suspends. Wrap state accordingly — don't assume a port survives a SW restart.

## Content script ↔ page-world bridge

If you inject a page-world script (via `chrome.scripting.executeScript({ world: 'MAIN' })`), it has no `chrome.*` APIs. It must talk to the content script via `window.postMessage`.

Use a nonce + origin check (see `extension-security/references/content-script-isolation.md` for the full pattern):

```ts
// entrypoints/injected/page-world.ts
(function () {
  const NONCE = crypto.randomUUID();
  window.postMessage({ source: 'my-ext-page', nonce: NONCE, type: 'init' }, window.location.origin);

  window.addEventListener('message', (e) => {
    if (e.source !== window) return;
    if (e.origin !== window.location.origin) return;
    if (e.data?.source !== 'my-ext-cs') return;
    if (e.data?.replyNonce !== NONCE) return;
    // ... reply from content script
  });
})();
```

```ts
// entrypoints/content.ts
import { defineContentScript } from 'wxt/utils/define-content-script';

export default defineContentScript({
  matches: ['*://example.com/*'],
  async main(ctx) {
    // Inject page-world script
    await chrome.scripting.executeScript({
      target: { tabId: (await chrome.tabs.getCurrent())?.id ?? 0 },
      world: 'MAIN',
      files: ['/injected/page-world.js'],
    });

    window.addEventListener('message', (e) => {
      if (e.source !== window) return;
      if (e.origin !== window.location.origin) return;
      if (e.data?.source !== 'my-ext-page') return;
      // ... forward to background via sendCmd
    }, { signal: ctx.signal });
  },
});
```

Page-world scripts must also be in `web_accessible_resources`:

```ts
// wxt.config.ts
manifest: {
  web_accessible_resources: [
    {
      resources: ['/injected/page-world.js'],
      matches: ['<all_urls>'],
    },
  ],
}
```

## Trust boundaries

A reminder of which surfaces can call which commands. WXT doesn't enforce this — your dispatcher must:

- ✅ Popup, options, side panel, devtools panel → fully trusted; can call any command.
- ⚠️ Content script → semi-trusted; lives in page DOM. Treat as untrusted for sensitive commands (vault unlock, signing).
- ❌ External pages via `externally_connectable` → untrusted; expose only narrow read-only commands.

In the background dispatcher, branch on `Boolean(sender.tab)`:

```ts
const fromContent = Boolean(sender.tab);
if (cmd.type === 'unlockVault' && fromContent) {
  sendResponse({ error: 'not-allowed-from-content' });
  return;
}
```

## Don'ts

- ❌ Don't use stringly-typed `cmd.action === 'doThing'`. Use discriminated unions.
- ❌ Don't forward `window.postMessage` data to the background without validating origin and nonce.
- ❌ Don't assume the SW is awake when sending — wrap with retry.
- ❌ Don't expose write-side commands via `externally_connectable`. Read-only only, and re-validate origin.
- ❌ Don't put `chrome.runtime.onMessage` listeners outside `defineBackground`'s `main()` — WXT's HMR might double-register them.
