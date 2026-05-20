# Message passing — the typed `sendCmd` pattern

The single biggest improvement you can make over hand-rolled `chrome.runtime.sendMessage` is to type the messages.

## The anti-pattern

```ts
// ❌ Stringly-typed; no type safety; no autocomplete
chrome.runtime.sendMessage({ action: 'getTabs' }, (resp) => {
  // resp is `any`
});

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.action === 'getTabs') {
    chrome.tabs.query({}, (tabs) => sendResponse(tabs));
  } else if (msg.action === 'getTbs') {  // typo, silent failure
    // ...
  }
  return true;
});
```

Problems:
- Typos in action names silently fail.
- Response shape is `any`.
- No exhaustiveness check across handlers.

## The pattern

Define a discriminated union in a shared types file:

```ts
// types/messages.ts
export type Cmd =
  | { type: 'getTabs' }
  | { type: 'fetchPolicy'; url: string }
  | { type: 'saveItem'; item: { id: string; data: string } }
  | { type: 'getVaultEntry'; key: string };

export type CmdResponse<C extends Cmd> =
  C extends { type: 'getTabs' }        ? chrome.tabs.Tab[] :
  C extends { type: 'fetchPolicy' }    ? { ok: true; data: string } | { ok: false; error: string } :
  C extends { type: 'saveItem' }       ? { saved: true } :
  C extends { type: 'getVaultEntry' }  ? { value: string | null } :
  never;
```

Sender helper:

```ts
// lib/sendCmd.ts
import type { Cmd, CmdResponse } from '../types/messages';

export async function sendCmd<C extends Cmd>(cmd: C): Promise<CmdResponse<C>> {
  return chrome.runtime.sendMessage(cmd);
}
```

Background dispatcher:

```ts
// entrypoints/background.ts
import type { Cmd } from '../types/messages';

type Handler<C extends Cmd> = (cmd: C, sender: chrome.runtime.MessageSender) => Promise<unknown>;
type Handlers = { [K in Cmd['type']]: Handler<Extract<Cmd, { type: K }>> };

const handlers: Handlers = {
  getTabs: async () => chrome.tabs.query({}),
  fetchPolicy: async ({ url }) => {
    const r = await fetch(url);
    return r.ok ? { ok: true, data: await r.text() } : { ok: false, error: r.statusText };
  },
  saveItem: async ({ item }) => {
    await chrome.storage.local.set({ [`item:${item.id}`]: item });
    return { saved: true };
  },
  getVaultEntry: async ({ key }) => {
    // ... decrypt vault, return entry
    return { value: null };
  },
};

chrome.runtime.onMessage.addListener((cmd: Cmd, sender, sendResponse) => {
  // Trust check: must come from this extension
  if (sender.id !== chrome.runtime.id) {
    sendResponse({ error: 'untrusted-sender' });
    return;
  }
  const handler = (handlers as any)[cmd.type] as Handler<typeof cmd> | undefined;
  if (!handler) {
    sendResponse({ error: `unknown command: ${cmd.type}` });
    return;
  }
  handler(cmd, sender)
    .then((result) => sendResponse(result))
    .catch((err) => sendResponse({ error: String(err) }));
  return true;  // tell Chrome the response is async
});
```

Now callers get full type safety:

```ts
const tabs = await sendCmd({ type: 'getTabs' });          // tabs: chrome.tabs.Tab[]
const policy = await sendCmd({ type: 'fetchPolicy', url: 'https://...' });
// policy: { ok: true; data: string } | { ok: false; error: string }
```

## Trust boundaries

`sender.id === chrome.runtime.id` confirms the message came from your extension (any surface). But within the extension, different senders have different trust levels:

| Sender | Trust level |
|---|---|
| `popup`, `options`, `side panel` | Fully trusted — user-driven UI |
| `devtools` | Trusted — only opens via developer action |
| Content scripts | **Partially trusted** — they live in a page-shared world; hostile page JS can use `window.postMessage` to talk to your content script |
| External web pages via `externally_connectable` | Untrusted — explicitly validate origin |

If a content script forwards page-originated data to the background, **re-validate at the background boundary**. Treat it like an external API call.

## Four-execution-context model (Violentmonkey pattern)

Violentmonkey's codebase makes explicit what most extensions have implicitly:

1. **Background SW** — has all `chrome.*` APIs
2. **Content script** — isolated world, can touch DOM
3. **Injected page script** — runs in the page's main world (via `chrome.scripting.executeScript({ world: 'MAIN' })`)
4. **Extension UI** — popup, options, side panel; renders extension pages

Messages flow:

```
ExtUI ←→ Background ←→ ContentScript ←(postMessage)→ PageScript
```

`runtime.sendMessage` works for the first two hops. The CS↔PageScript boundary uses `window.postMessage` with strict origin and nonce checks.

```ts
// content script
const NONCE = crypto.randomUUID();

window.postMessage({ source: 'my-ext', nonce: NONCE, cmd: 'init' }, '*');

window.addEventListener('message', (event) => {
  if (event.source !== window) return;
  if (event.data.source !== 'my-ext') return;
  if (event.data.nonce !== NONCE) return;
  // ... handle response from page script
});
```

The page script does the inverse — listens for the source + nonce.

## Long-lived connections

For streaming data or many round trips, use `chrome.runtime.connect` ports instead of `sendMessage`:

```ts
// content script
const port = chrome.runtime.connect({ name: 'cs-bg' });
port.postMessage({ type: 'subscribe', topic: 'tabs' });
port.onMessage.addListener((msg) => { /* ... */ });

// background
chrome.runtime.onConnect.addListener((port) => {
  if (port.name === 'cs-bg') {
    port.onMessage.addListener((msg) => { /* ... */ });
  }
});
```

Ports auto-disconnect when the other side suspends, which is useful signaling.

## Don't fight the SW lifecycle

Background SWs suspend after ~30s idle. Long-running computation must:

- Re-trigger itself via `chrome.alarms` for delayed work
- Use `chrome.storage.session` to checkpoint progress
- Accept that `port` connections will break and reconnect

If you need a long-lived in-memory engine (e.g., a transformer model running in WASM), reconsider — extensions are not the right home for that. Use a sidecar native messaging host or a web worker in a tab.

## SW startup race (Violentmonkey lesson)

When a content script sends a message right as it's loaded, the SW may not be awake yet. Violentmonkey has explicit retry logic:

```ts
async function sendCmdReliable<C extends Cmd>(cmd: C, retries = 3): Promise<CmdResponse<C>> {
  for (let i = 0; i < retries; i++) {
    try {
      return await sendCmd(cmd);
    } catch (e) {
      if (i === retries - 1) throw e;
      await new Promise((r) => setTimeout(r, 100 * (i + 1)));
    }
  }
  throw new Error('unreachable');
}
```

Or — better — register an event in the manifest that wakes the SW first, like `chrome.runtime.onInstalled`, then have your content script wait for an `onConnect` handshake before sending real messages.
