# MetaMask pattern — LavaMoat sandboxing + controller-based state

## Source

`MetaMask/metamask-extension` and `MetaMask/core` on GitHub. MIT-licensed. React + Redux + Webpack/Browserify. The `MetaMask/core` repo is a separate monorepo of ~80 controller packages.

## What to copy

Two things stand out about MetaMask's architecture: **LavaMoat for supply-chain defense**, and **controller-based state** with explicit dependency graphs.

## 1. LavaMoat sandboxing

MetaMask handles cryptocurrency private keys. Their threat model includes "any npm package in the dep graph might be malicious." LavaMoat exists because of incidents like the November 2018 `event-stream` attack, in which a malicious `flatmap-stream` dep was added to event-stream v3.3.6 to exfiltrate BitPay Copay wallet keys. Per Snyk's post-mortem and npm's incident reports, ~867,232 downloads of the malicious package occurred before detection.

LavaMoat does two things:

1. **`@lavamoat/allow-scripts`** — blocks `postinstall` scripts unless explicitly listed in `package.json#lavamoat.allowScripts`. Prevents an arbitrary `npm install` from running native code.
2. **Bundled-code sandboxing** — at runtime, each package gets a SES (Secure ECMAScript) compartment. A compromised dep can't access globals or other deps' modules.

In MetaMask's repo, `lavamoat/browserify/*/policy.json` files declare what each package is allowed to access. They're regenerated automatically when production deps change (`yarn lavamoat:webapp:auto`).

### Setup

```bash
pnpm add -D @lavamoat/allow-scripts lavamoat
```

`package.json`:

```json
{
  "lavamoat": {
    "allowScripts": {
      "$root$": true,
      "esbuild": true,
      "@swc/core": true
    }
  },
  "scripts": {
    "postinstall": "allow-scripts"
  }
}
```

Initial allow-list: run `pnpm allow-scripts auto` to generate it.

For full bundle-time sandboxing, integrate `lavamoat-browserify` or `lavamoat-webpack` into your build:

```js
// lavamoat.config.js (browserify example)
module.exports = {
  policy: './lavamoat/browserify/policy.json',
  policyOverride: './lavamoat/browserify/policy-override.json',
};
```

WXT/Plasmo/CRXJS users: LavaMoat doesn't directly integrate with Vite yet (as of mid-2026). For Vite-based extensions, the practical advice is:

- Use `@lavamoat/allow-scripts` for postinstall safety (works regardless of bundler).
- Audit your dep graph with `pnpm why <package>` for suspicious deps.
- Consider switching to Browserify or Webpack for the supply-chain-critical sections if you handle keys.

### When to adopt

- ✅ Your extension handles cryptocurrency keys, wallet seeds, or HSM credentials.
- ✅ Your `package.json` has >20 production deps (each is a supply-chain risk).
- ✅ You can't audit every transitive dep.
- ⚠️ Your extension is small and pure-UI. LavaMoat is overhead; allow-scripts alone is enough.

## 2. Controller-based state

`MetaMask/core` is ~80 packages, each one a "controller":

```
core/
├── packages/
│   ├── accounts-controller
│   ├── account-tree-controller
│   ├── address-book-controller
│   ├── approval-controller
│   ├── assets-controllers
│   ├── bridge-controller
│   ├── controller-utils      # the base class
│   ├── keyring-controller    # the most security-critical
│   ├── network-controller
│   ├── notification-controller
│   ├── permission-controller
│   ├── selected-network-controller
│   ├── transaction-controller
│   ├── user-storage-controller
│   └── ...
```

Each controller:

1. Owns a slice of state.
2. Has a `BaseController` lineage with consistent action/event APIs.
3. Declares its dependencies on other controllers explicitly.
4. Is independently testable.

The `MetaMask/core` README is a Mermaid graph of all controller dependencies — making the graph visible *forces* clean dependencies. If you can't draw the graph cleanly, your architecture is wrong.

### Adapting for a smaller extension

You don't need 80 controllers. But the pattern scales down to 3–10:

```
src/
├── controllers/
│   ├── base-controller.ts
│   ├── settings-controller.ts
│   ├── vault-controller.ts
│   ├── network-controller.ts
│   └── notification-controller.ts
├── background.ts             # entry point; wires controllers together
└── types/
```

```ts
// src/controllers/base-controller.ts
export abstract class BaseController<State> {
  protected state: State;
  protected listeners = new Set<(s: State) => void>();

  constructor(initialState: State) { this.state = initialState; }

  getState(): State { return this.state; }
  update(updater: (s: State) => State): void {
    this.state = updater(this.state);
    this.listeners.forEach((l) => l(this.state));
  }
  subscribe(listener: (s: State) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }
}
```

```ts
// src/controllers/vault-controller.ts
import { BaseController } from './base-controller';
import { storage } from 'wxt/storage';

type VaultState = { entries: Record<string, string>; locked: boolean };

const vaultItem = storage.defineItem<VaultState>('local:vault-state', {
  fallback: { entries: {}, locked: true },
});

export class VaultController extends BaseController<VaultState> {
  constructor(initial: VaultState) {
    super(initial);
    this.subscribe(async (s) => vaultItem.setValue(s));
  }

  static async create(): Promise<VaultController> {
    return new VaultController(await vaultItem.getValue());
  }

  async unlock(passphrase: string): Promise<void> { /* ... */ }
  async lock(): Promise<void> { this.update((s) => ({ ...s, locked: true })); }
  async addEntry(key: string, value: string): Promise<void> { /* ... */ }
}
```

### Wiring in background

```ts
// src/background.ts
import { SettingsController } from './controllers/settings-controller';
import { VaultController } from './controllers/vault-controller';

const settings = await SettingsController.create();
const vault = await VaultController.create();

chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
  switch (cmd.type) {
    case 'unlock-vault': vault.unlock(cmd.passphrase).then(sendResponse); return true;
    case 'add-entry':    vault.addEntry(cmd.key, cmd.value).then(sendResponse); return true;
    case 'get-settings': sendResponse(settings.getState()); return false;
  }
});
```

## 3. In-page provider injection (Web3-specific)

MetaMask injects `window.ethereum` into every page so dApps can talk to the wallet. Under MV3 this uses the `chrome.scripting.executeScript({ world: 'MAIN' })` API.

```ts
// src/inject/provider.ts — runs in the page world
(function() {
  if (window.ethereum) return;
  const ethereum = { /* JSON-RPC bridge */ };
  Object.defineProperty(window, 'ethereum', { value: ethereum, writable: false });
})();
```

```ts
// src/background.ts
chrome.tabs.onUpdated.addListener((tabId, change, tab) => {
  if (change.status !== 'loading') return;
  chrome.scripting.executeScript({
    target: { tabId },
    files: ['inject/provider.js'],
    world: 'MAIN',
    runAt: 'document_start',
  });
});
```

The provider in the page world `postMessage`s to a content script (isolated world) which then `chrome.runtime.sendMessage`s to the background.

This is sensitive code — both sides must validate nonces and origins to prevent hostile pages from impersonating dApps or vice versa.

## Remote feature flags

MetaMask injects remote feature flags at build time via a `_flags.remoteFeatureFlags` field in `manifest.json`, with `.manifest-overrides.json` for build-time overrides. This allows toggling experiments without shipping a new version — but the flags are fetched and validated, not arbitrary code, so it doesn't violate MV3's no-remote-code rule.

If you adopt this pattern, validate flag payloads against a schema and never `eval` them.

## What not to copy

- **MetaMask's full ~80-controller architecture**: that's for a wallet with massive scope. Most extensions need 3–10 controllers.
- **Browserify**: MetaMask uses Browserify primarily because LavaMoat integration is most mature there. New projects should pick WXT (Vite); add LavaMoat at the allow-scripts level only.
- **Their dev environment**: GitHub Codespaces with noVNC for Chrome testing is high-overhead. Use Playwright's `launchPersistentContext` for E2E (much simpler).

## Critical takeaway

If your extension handles credentials, secrets, crypto, or wallet keys: **adopt LavaMoat allow-scripts at minimum, and follow the controller-isolation pattern.** Don't roll your own crypto; don't trust npm deps without auditing.
