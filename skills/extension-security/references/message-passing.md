# Message-passing trust boundaries (security view)

This is the security-focused companion to `extension-architect/references/message-passing.md`. That one is about typing; this one is about trust.

## The four senders, in order of trust

1. **Popup, options, side panel** — fully trusted. The user opened these deliberately.
2. **DevTools panel** — trusted (devtools only opens via user action).
3. **Content script in the extension's isolated world** — partially trusted. The page might be hostile.
4. **External pages via `externally_connectable`** — untrusted. Specifically allowlisted origins.

The most sensitive commands (decrypting vault, sending money, granting permissions) should only be reachable from **(1)** — extension UI surfaces the user opened.

## Sender validation in background

```ts
chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
  // 1. Must be from this extension (or an allowlisted external origin)
  if (sender.id !== chrome.runtime.id) {
    sendResponse({ error: 'untrusted-extension' });
    return;
  }

  // 2. Inspect sender.tab — if present, came from a content script
  const fromContentScript = Boolean(sender.tab);

  // 3. Dispatch based on trust requirement of the command
  const cmdTrust = trustLevelFor(cmd.type);

  if (cmdTrust === 'extension-ui-only' && fromContentScript) {
    sendResponse({ error: 'not-allowed-from-content' });
    return;
  }

  // Proceed to actual handler
  handlers[cmd.type](cmd, sender, sendResponse);
  return true;
});

function trustLevelFor(cmdType: string): 'public' | 'tab-only' | 'extension-ui-only' {
  switch (cmdType) {
    case 'getPublicData':          return 'public';
    case 'autofillSelection':      return 'tab-only';
    case 'unlockVault':            return 'extension-ui-only';
    case 'signTransaction':        return 'extension-ui-only';
    case 'changeMasterPassphrase': return 'extension-ui-only';
    default:                       return 'extension-ui-only';  // default deny-broad
  }
}
```

## External messages

`externally_connectable` lets specific web pages talk to your extension:

```json
{
  "externally_connectable": {
    "matches": ["https://*.your-domain.com/*"]
  }
}
```

These messages arrive on `chrome.runtime.onMessageExternal`. Always validate the origin:

```ts
chrome.runtime.onMessageExternal.addListener((cmd, sender, sendResponse) => {
  const allowed = ['https://app.your-domain.com', 'https://docs.your-domain.com'];
  if (!sender.url || !allowed.some((a) => sender.url!.startsWith(a))) {
    sendResponse({ error: 'untrusted-origin' });
    return;
  }
  // Even now, treat as untrusted — only expose narrow read-only commands
  if (cmd.type !== 'getPublicVersion') {
    sendResponse({ error: 'not-exposed' });
    return;
  }
  sendResponse({ version: chrome.runtime.getManifest().version });
});
```

External pages should only invoke very narrow read-only commands. Never expose vault unlock, settings mutation, or anything write-side via `externally_connectable`.

## CORS as a trust signal

For your own backend, requests from the extension's SW have `Origin: chrome-extension://<id>`. You can use that to require the request came from your extension:

```js
// Express middleware
app.use((req, res, next) => {
  const origin = req.get('Origin');
  if (!origin?.startsWith('chrome-extension://')) {
    return res.status(403).json({ error: 'forbidden-origin' });
  }
  next();
});
```

But: the extension ID is public (in the CWS listing), so an attacker could forge `Origin` from any context. Treat this as a defense-in-depth signal, not a sole gate.

## Replay attacks

A captured message can be replayed. Defend with nonces or expiry timestamps:

```ts
// Page world sends a nonce
window.postMessage({ source: 'my-ext', requestId, expiresAt: Date.now() + 5000, ... }, '*');

// Content script checks
if (event.data.expiresAt < Date.now()) return;  // too old
if (seenIds.has(event.data.requestId)) return;  // replay
seenIds.add(event.data.requestId);
setTimeout(() => seenIds.delete(event.data.requestId), 10_000);
```

## Long-lived ports

`chrome.runtime.connect` ports survive multiple messages. Validate at port open:

```ts
chrome.runtime.onConnect.addListener((port) => {
  if (port.name !== 'expected-name') {
    port.disconnect();
    return;
  }
  if (port.sender?.id !== chrome.runtime.id) {
    port.disconnect();
    return;
  }
  port.onMessage.addListener((msg) => {
    // ... handle
  });
});
```

Don't trust the port after open just because it was once valid — re-check sensitive operations every time.

## Logging without leaking

Logging is essential for debugging, but logs often include user data. Strip sensitive fields:

```ts
function logCmd(cmd: Cmd) {
  const safe = { ...cmd };
  if ('passphrase' in safe) safe.passphrase = '[REDACTED]';
  if ('refreshToken' in safe) safe.refreshToken = '[REDACTED]';
  console.log('cmd:', safe);
}
```

Or whitelist allowed fields per command type.

## A worked example: signing a transaction

The pattern for a sensitive operation:

```ts
// User opens popup, types "send 1 ETH to 0xabc"
// popup.tsx
async function onSubmit() {
  const result = await sendCmd({
    type: 'signTransaction',
    transaction: { to: '0xabc', value: '1000000000000000000' },
  });
  // ... show result
}

// background.ts
async function handleSignTransaction(cmd: Cmd, sender: chrome.runtime.MessageSender) {
  // 1. Must come from extension UI, not content script
  if (sender.tab) throw new Error('not-from-extension-ui');

  // 2. Vault must be unlocked
  const vault = await getDecryptedVault();
  if (!vault) throw new Error('vault-locked');

  // 3. User must explicitly confirm — show a confirmation popup (or in-popup modal)
  const confirmed = await showConfirmationDialog(cmd.transaction);
  if (!confirmed) throw new Error('user-rejected');

  // 4. Sign
  const signature = await vault.sign(cmd.transaction);

  // 5. Log without sensitive fields
  console.log('signed transaction', { to: cmd.transaction.to, signature: 'OK' });

  return { signature };
}
```

Every layer is necessary. Skipping any of them is an incident waiting to happen.

## TL;DR

- Define explicit trust levels per command.
- Default to "extension UI only" — opt in to lower trust per command.
- Validate sender on every message.
- Re-validate on long-lived ports.
- Treat content scripts as semi-trusted, external as untrusted.
- Log without leaking.
