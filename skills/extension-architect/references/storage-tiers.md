# Storage tiers — what goes where

Chrome's `chrome.storage` API has four areas. Pick deliberately.

| Area | Persistence | Quota | Sync across devices | Available in MV3? |
|---|---|---|---|---|
| `chrome.storage.local` | Until extension uninstall | ~10 MB by default; can be raised with `unlimitedStorage` permission | No | Yes |
| `chrome.storage.sync` | Until extension uninstall | 100 KB total; 8 KB per item; ≤512 items | Yes (signed-in Chrome users) | Yes |
| `chrome.storage.session` | Until browser closes | ~10 MB | No | **MV3 only** |
| `chrome.storage.managed` | Set by enterprise policy | n/a | No (admin-set) | Yes (read-only) |

## Decision tree

```
What kind of state is this?

├─ User preferences (theme, language, opt-ins)
│  └─ chrome.storage.sync   (small, syncs across devices)
│
├─ User-generated content (notes, bookmarks, saved items)
│  ├─ Fits in 100 KB? → chrome.storage.sync
│  └─ Bigger? → chrome.storage.local
│
├─ Cache (computed results, API responses)
│  ├─ Useful past browser restart? → chrome.storage.local (with TTL)
│  └─ Only useful during session? → chrome.storage.session  (MV3-only)
│
├─ SW ephemeral state (current selection, in-flight request)
│  └─ chrome.storage.session  (clears on browser close; survives SW suspension)
│
├─ Sensitive data (passwords, tokens, private keys)
│  └─ chrome.storage.local + encrypt with Web Crypto / Argon2
│
└─ Enterprise-managed config
   └─ chrome.storage.managed  (read-only)
```

## chrome.storage.session — the killer MV3 feature

Before MV3, extension SWs (then background pages) had in-memory state that lived as long as the page did. Under MV3, SWs suspend after ~30 seconds idle and lose all in-memory state.

`chrome.storage.session` solves this: it survives SW suspension but resets when the browser closes. It's the SW's "warm memory."

Use it for:
- Current decrypted vault (Bitwarden pattern)
- In-flight OAuth state
- Computed lookup caches (filter ruleset metadata)
- "Currently active tab" tracking
- Rate-limit counters

```ts
import { storage } from 'wxt/storage';

const currentVault = storage.defineItem<Vault | null>('session:vault', {
  fallback: null,
});

await currentVault.setValue(decryptedVault);
const v = await currentVault.getValue();
```

If you're not using WXT:

```ts
await chrome.storage.session.set({ vault: decryptedVault });
const { vault } = await chrome.storage.session.get('vault');
```

## chrome.storage.sync — quotas matter

Sync storage has hard limits:

- 100 KB total
- 8 KB per item
- 512 max items
- 120 writes/min (rate-limited)
- 1,800,000 writes/hour

If you exceed the rate limit, writes silently fail. Wrap with debouncing:

```ts
import debounce from 'lodash.debounce';

const writeSync = debounce(async (data) => {
  await chrome.storage.sync.set(data);
}, 500);
```

For settings that may grow large (saved sites list, custom filters), consider a sync/local split: small index in sync, full data in local.

## chrome.storage.local — defaults and quotas

10 MB default quota. Add `"unlimitedStorage"` to permissions to lift it:

```json
{
  "permissions": ["storage", "unlimitedStorage"]
}
```

The `unlimitedStorage` permission triggers the broad CWS review attention. Justify it.

## What NOT to use

### ❌ `localStorage` / `sessionStorage` (window)

- Available in popup/options/content scripts but NOT in SW (no DOM).
- Synchronous → blocks UI.
- Subject to the page's storage policy (in content scripts, you'd be using the page's localStorage, not yours).
- Not accessible from background.

### ❌ `IndexedDB` directly

- Works in SW under MV3 (via `self.indexedDB`).
- More complex API than `chrome.storage`.
- Use only if you need >10 MB and complex queries. Most extensions don't.

### ❌ Cookies for extension state

- Visible to the user; can be modified.
- Synced across browsers in unpredictable ways.
- Never use for extension-internal state.

### ❌ In-memory globals

- Lost on SW suspension. Always.
- Acceptable for content scripts and popups (they're page-scoped), but anything in background must persist.

## Encryption for sensitive data

`chrome.storage.local` is **not encrypted at rest**. For credentials, OAuth refresh tokens, private keys:

```ts
// Derive a key from a user passphrase
const enc = new TextEncoder();
const keyMaterial = await crypto.subtle.importKey(
  'raw', enc.encode(passphrase), 'PBKDF2', false, ['deriveKey']
);
const key = await crypto.subtle.deriveKey(
  { name: 'PBKDF2', salt, iterations: 600_000, hash: 'SHA-256' },
  keyMaterial,
  { name: 'AES-GCM', length: 256 },
  false,
  ['encrypt', 'decrypt'],
);

// Encrypt before storing
const iv = crypto.getRandomValues(new Uint8Array(12));
const ciphertext = await crypto.subtle.encrypt(
  { name: 'AES-GCM', iv },
  key,
  enc.encode(JSON.stringify(secret)),
);

await chrome.storage.local.set({
  vault: {
    iv: Array.from(iv),
    salt: Array.from(salt),
    ciphertext: Array.from(new Uint8Array(ciphertext)),
  },
});
```

Use ≥600,000 PBKDF2 iterations (OWASP 2026 recommendation), or Argon2 via WebAssembly for stronger key derivation.

Bitwarden's pattern (see `examples/bitwarden-pattern.md`): a separate `key-management` module owns all crypto; other modules never touch `crypto.subtle` directly.

## Migrations

Storage schemas drift. Plan for it:

1. Version your stored data: `{ version: 2, ... }`.
2. On read, check version; migrate if needed.
3. On write, always write the latest version.

```ts
const STORAGE_VERSION = 2;

async function readPrefs() {
  const { prefs } = await chrome.storage.sync.get('prefs');
  if (!prefs) return defaultPrefs();
  if (prefs.version === 1) return migratePrefsV1toV2(prefs);
  return prefs;
}
```

WXT's `storage.defineItem` supports migrations natively via the `migrations` field.
