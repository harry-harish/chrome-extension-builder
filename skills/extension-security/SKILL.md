---
name: extension-security
description: Use when implementing or auditing security-sensitive parts of a Chrome extension — content-script isolation, key/secret storage, CSP hardening, message-passing trust boundaries, dependency supply-chain (LavaMoat), permissions minimization, devtools injection. Load when the extension handles credentials, crypto, OAuth, Web3, or any sensitive data. Carries patterns distilled from MetaMask, Bitwarden, uBlock Origin Lite, and the Snyk post-mortem of the November 2018 event-stream supply-chain attack.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
license: Apache-2.0
---

# Extension Security

Production-grade security patterns for Chrome extensions, distilled from real codebases.

## The threat model

A Chrome extension is one of the most privileged pieces of software a user installs. It can read every page they visit (with the right permissions), see their cookies, modify the DOM, and call any API. Its threat model includes:

1. **Malicious dependencies.** The November 2018 `event-stream` attack injected `flatmap-stream` to exfiltrate BitPay Copay wallet keys; 867,232 downloads of the malicious package occurred before detection. LavaMoat exists because of incidents like this.
2. **Compromised CDN / remote code.** MV3 forbids this; the well-architected extensions go further and disable any remote config loading by default (Dark Reader's site-fix sync is opt-in for this reason).
3. **Content-script isolation breach.** Content scripts share the page's DOM. A naive content script can be tricked by hostile page JS.
4. **Background SW privilege escalation.** Background SWs have access to all `chrome.*` APIs. An attacker who can send arbitrary messages to the SW can call any of them.
5. **Storage compromise.** `chrome.storage.local` is not encrypted at rest by default. Sensitive data needs an app-level vault.

## Core patterns

### 1. Strict CSP

In your manifest:

```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'; base-uri 'self'",
    "sandbox": "sandbox allow-scripts; script-src 'self' 'unsafe-eval'; child-src 'self'"
  }
}
```

Rules:
- ❌ Never `unsafe-eval` in `extension_pages`. (The `sandbox` directive can allow it, but only for genuinely sandboxed pages.)
- ❌ Never `unsafe-inline`.
- ❌ Never a remote `script-src` (e.g., `https://cdn.example.com`). MV3 enforces this anyway.
- ✅ Always explicit `'self'` even though MV3 defaults to it.

Load `references/csp-hardening.md` for advanced cases (Wasm, blob: URLs, sandbox pages).

### 2. Typed message-passing with trust validation

Stringly-typed `chrome.runtime.sendMessage({ action: 'doThing' })` is an anti-pattern. Use:

```ts
// types/messages.ts
export type Cmd =
  | { type: 'getSecret'; key: string }
  | { type: 'callApi'; endpoint: string; payload: unknown };

export type CmdSender = 'popup' | 'options' | 'content' | 'devtools';

// background.ts
chrome.runtime.onMessage.addListener((cmd: Cmd, sender, sendResponse) => {
  // 1. Validate sender origin
  if (sender.id !== chrome.runtime.id) {
    sendResponse({ error: 'Untrusted sender' });
    return;
  }
  // 2. Discriminate by type
  switch (cmd.type) {
    case 'getSecret':
      // ... handle, with explicit auth check
      break;
    case 'callApi':
      // ... handle
      break;
  }
  return true;  // async response
});
```

Critical: **never trust messages from content scripts as if they came from the user**. A content script lives in a shared page world; hostile page JS can call `window.postMessage` to talk to your content script. If a content script forwards page-originated data to the background, mark it as untrusted and re-validate.

Load `references/message-passing.md` for the full trust-boundary model (Violentmonkey's four-execution-context architecture is the reference).

### 3. Content-script ↔ page isolation

Content scripts run in an "isolated world" — separate from the page's JS. But:

- The DOM is shared. If you store secrets in `data-*` attributes, the page sees them.
- `window.postMessage` is a cross-world channel. Validate `event.origin` and use a nonce.
- `dom-chef` / `select-dom` (used by Refined GitHub) are safe DOM helpers; raw `innerHTML` is not.

Pattern: keep content scripts dumb. They observe the DOM, dispatch messages to the background, and apply UI changes — they should not hold credentials or call APIs directly.

Load `references/content-script-isolation.md` for the page-script injection pattern (`<script>` tag added by content script to run in the page world — used by MetaMask's in-page provider).

### 4. Secret storage

`chrome.storage.local` is unencrypted at rest. For sensitive data (vault contents, OAuth refresh tokens, private keys):

- Encrypt before storing. Use Web Crypto API (`crypto.subtle.encrypt`) with a key derived from a user passphrase (`PBKDF2` with ≥600k iterations, or `Argon2` via WebAssembly).
- Store the encrypted blob in `chrome.storage.local`; never log decrypted values.
- For session-only secrets (e.g., decrypted vault), use `chrome.storage.session` (MV3-only) — it's cleared when the browser closes.
- For OAuth: prefer the `chrome.identity` API over manual flows; it manages the redirect URI.

Pattern from Bitwarden: a separate `libs/key-management` module owns all key derivation and crypto. Other libs depend on it; no other code touches `crypto.subtle` directly. Load `examples/bitwarden-pattern.md`.

### 5. LavaMoat for supply-chain defense

If your `package.json` has more than 20 production dependencies, or you handle credentials/crypto, adopt LavaMoat:

```bash
pnpm add -D @lavamoat/allow-scripts lavamoat
```

`@lavamoat/allow-scripts` blocks postinstall scripts unless explicitly allowed in `package.json#lavamoat.allowScripts`. `lavamoat` runs your bundled code in per-package SES sandboxes so a compromised dep cannot escape.

MetaMask is the reference: its `lavamoat/browserify/*/policy.json` files are auto-regenerated when production deps change (`yarn lavamoat:webapp:auto`).

Load `references/lavamoat-setup.md`.

### 6. Permissions minimization

- `chrome.activeTab` > `host_permissions`. activeTab grants temporary host permission for the current tab on user invocation; no install-time warning.
- `optional_host_permissions` > `host_permissions`. Request at runtime via `chrome.permissions.request({ origins: [...] })` only when the user explicitly opts in. uBlock Origin Lite is the canonical example.
- `<all_urls>` is a manual-review trigger in Chrome Web Store. Justify it in the single-purpose statement or narrow.

Load `../extension-architect/references/permissions.md` (the canonical location; permissions are inherently architectural).

### 7. No remote code

MV3 forbids it. But also:

- Don't load CSS or fonts from CDNs in extension pages — fingerprintable + violates the same MV3 spirit.
- Don't sync site-fix CSS from GitHub raw URLs — GitHub explicitly disallows being used as a CDN. Dark Reader's pattern is to ship a default-bundled list and offer the sync as an opt-in.
- Don't load native messaging hosts without verifying their signature.

### 8. DevTools injection (MV3)

The MV2 trick of injecting via the content script no longer works. React DevTools' README states: *"As we migrate to a Chrome Extension Manifest V3, we start to use a new method to hook the DevTools with the inspected page. This new method is more secure, but relies on a new API that's only supported in Chrome v102+."*

Use `chrome.scripting.executeScript({ world: 'MAIN' })` to inject into the page world; the content script bridges via `window.postMessage` with strict origin/nonce checks.

Load `references/devtools-injection.md`.

## Reference examples (load only the matching one)

- `examples/metamask-pattern.md` — LavaMoat policy management, controller architecture, in-page provider.
- `examples/bitwarden-pattern.md` — Monorepo with shared `libs/`, separate key-management lib.
- `examples/ubo-lite-pattern.md` — Tiered/optional permissions; declarativeNetRequest.

## Scripts in this skill

- `scripts/validate-permissions.py` — flags `<all_urls>`, broad `host_permissions`, suggests `activeTab` / `optional_host_permissions`.
- `scripts/validate-csp.sh` — checks CSP for `unsafe-eval`, `unsafe-inline`, remote sources.
- `scripts/audit-deps.sh` — runs `pnpm audit` + checks for LavaMoat config when deps > 20.

## Things never to do

- ❌ Store decrypted secrets in `chrome.storage.local`.
- ❌ Log secret values, even at debug level. (Logging frameworks often persist to disk.)
- ❌ Accept messages from content scripts as authenticated user input.
- ❌ Use `innerHTML` with user/page data in content scripts.
- ❌ Use `unsafe-eval` to enable a small library — find a CSP-compliant alternative.
- ❌ Skip LavaMoat for an extension that handles wallets or credentials.
- ❌ Ship without an explicit CSP (don't rely on MV3 defaults — be explicit).
