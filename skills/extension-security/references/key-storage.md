# Key and secret storage

`chrome.storage.local` is **not encrypted at rest**. If your extension stores credentials, OAuth refresh tokens, vault contents, or private keys, you must encrypt before storing.

## Threat model

What this defends against:

- Someone with read access to the user's profile directory finds your unencrypted secrets.
- A malicious extension installed by the user reads `chrome.storage.local` of other extensions (not actually possible by default, but defense in depth).

What this does NOT defend against:

- Malware running on the user's machine with the user's permissions can do anything — including key-log the passphrase.
- A compromised extension SW can decrypt the vault as long as it has the user's passphrase.
- Memory dumps of the running browser may contain decrypted secrets.

## Pattern: passphrase-derived key

User enters a passphrase. PBKDF2 (≥600k iterations, OWASP 2026 recommendation) or Argon2 (via WASM) derives an AES key. Use the key to encrypt before `chrome.storage.local.set`.

```ts
// src/crypto/key.ts — the only file that imports crypto.subtle

const enc = new TextEncoder();
const dec = new TextDecoder();

async function deriveKey(passphrase: string, salt: Uint8Array): Promise<CryptoKey> {
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    enc.encode(passphrase),
    'PBKDF2',
    false,
    ['deriveKey'],
  );
  return crypto.subtle.deriveKey(
    {
      name: 'PBKDF2',
      salt,
      iterations: 600_000,
      hash: 'SHA-256',
    },
    keyMaterial,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

export async function encryptVault(passphrase: string, vault: object): Promise<EncryptedBlob> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(passphrase, salt);
  const plaintext = enc.encode(JSON.stringify(vault));
  const ciphertext = await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv },
    key,
    plaintext,
  );
  return {
    version: 1,
    salt: Array.from(salt),
    iv: Array.from(iv),
    ciphertext: Array.from(new Uint8Array(ciphertext)),
  };
}

export async function decryptVault(passphrase: string, blob: EncryptedBlob): Promise<object> {
  const salt = new Uint8Array(blob.salt);
  const iv = new Uint8Array(blob.iv);
  const key = await deriveKey(passphrase, salt);
  const plaintext = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv },
    key,
    new Uint8Array(blob.ciphertext),
  );
  return JSON.parse(dec.decode(plaintext));
}

type EncryptedBlob = {
  version: number;
  salt: number[];
  iv: number[];
  ciphertext: number[];
};
```

Storage:

```ts
import { encryptVault, decryptVault } from '../crypto/key';

async function storeVault(passphrase: string, vault: object) {
  const blob = await encryptVault(passphrase, vault);
  await chrome.storage.local.set({ vault: blob });
}

async function loadVault(passphrase: string): Promise<object | null> {
  const { vault } = await chrome.storage.local.get('vault');
  if (!vault) return null;
  try {
    return await decryptVault(passphrase, vault);
  } catch {
    // wrong passphrase
    return null;
  }
}
```

## Decrypted state in memory

Once decrypted, where does the vault live? Three choices:

| Choice | Pros | Cons |
|---|---|---|
| Hold in SW memory | Fast | SW suspends → state lost; user re-enters passphrase |
| Store in `chrome.storage.session` | Survives SW suspension; clears on browser close | One layer less secure (any code in extension origin can read) |
| Hold a derived encryption key in `session`; re-decrypt vault on demand | Best balance | More crypto operations per access |

Bitwarden's pattern: store **decrypted vault** in `chrome.storage.session`. When the user locks (or browser closes), it's cleared. This is the right balance for most extensions — the threat model "someone with disk access" is mitigated; the threat model "compromised SW" already implies the attacker has live RAM access anyway.

## OAuth refresh tokens

Refresh tokens are highly valuable — they grant the bearer ongoing access without the user re-authenticating. Treat them like keys:

```ts
// Encrypt before storing
async function saveRefreshToken(token: string) {
  // Use chrome.identity to handle the OAuth flow, then encrypt the result
  const blob = await encryptVault(localPassphrase, { refreshToken: token });
  await chrome.storage.local.set({ refresh_token: blob });
}
```

If you can avoid storing refresh tokens at all (e.g., use `chrome.identity.getAuthToken` for Google OAuth, which manages the token internally), do that instead. The most secure secret is the one you don't have.

## Memorable passphrase prompts

Users hate typing passphrases. Bitwarden's compromise:

- Master passphrase entered on session start.
- Optionally auto-lock after N minutes of inactivity.
- Biometric unlock via `chrome.identity` + native messaging (when available).

`chrome.idle.queryState` + `chrome.alarms` lets you implement auto-lock:

```ts
chrome.alarms.create('auto-lock-check', { periodInMinutes: 1 });
chrome.alarms.onAlarm.addListener(async (a) => {
  if (a.name !== 'auto-lock-check') return;
  chrome.idle.queryState(60 * 5, (state) => {
    if (state !== 'active') {
      chrome.storage.session.clear();  // forget decrypted vault
    }
  });
});
```

## Never log secrets

Logging frameworks often persist to disk. Even debug logs.

```ts
// ❌ NEVER
console.log('Decrypted vault:', vault);
console.debug('Refresh token:', token);

// ✅ Log shapes, not values
console.log('Decrypted vault: %d entries', Object.keys(vault).length);
```

Add an ESLint rule:

```js
// .eslintrc.cjs
{
  rules: {
    'no-restricted-syntax': ['error', {
      selector: 'CallExpression[callee.object.name="console"][callee.property.name=/log|debug|info|warn|error/] :matches(Identifier[name=/^(passphrase|password|secret|token|key|vault)$/])',
      message: 'Do not log secret variables.',
    }],
  },
}
```

## When you don't need encryption

Some "secrets" are actually fine in plaintext:

- Public API keys with origin-restricted access.
- User preferences.
- Cached non-sensitive data.

Don't over-engineer. Encryption has a cost (performance, complexity, user-passphrase UX). Use it where the threat model justifies it.

## Audit checklist before shipping a secret-handling extension

- [ ] All `crypto.subtle.*` calls in one module.
- [ ] PBKDF2 ≥ 600k iterations OR Argon2 with appropriate parameters.
- [ ] AES-GCM (or ChaCha20-Poly1305), never ECB or unauthenticated modes.
- [ ] Fresh random salt and IV per encryption.
- [ ] No logging of secret values anywhere.
- [ ] No secrets in URL parameters or window.name.
- [ ] LavaMoat allow-scripts adopted.
- [ ] Production deps pinned and audited.
- [ ] Privacy disclosure declares what's encrypted and what's plaintext.
- [ ] Auto-lock implemented.
- [ ] Memory-clear on lock (no lingering decrypted state).
