# Bitwarden pattern — multi-client monorepo with shared `libs/`

## Source

`bitwarden/clients` on GitHub. ~12.8k stars, GPL-3.0, TypeScript. Houses `apps/browser` (extension), `apps/web`, `apps/desktop` (Electron), `apps/cli`.

## What to copy

Bitwarden is the gold standard for **multi-client architecture in security-critical software**. The browser extension is one of four clients; they share all sensitive logic via `libs/`.

```
clients/
├── apps/
│   ├── browser/              # the Chrome/Firefox/Edge extension
│   ├── desktop/              # the Electron desktop app
│   ├── web/                  # the web vault at vault.bitwarden.com
│   └── cli/                  # the bw command-line tool
└── libs/
    ├── common/               # shared services, abstractions, models
    ├── angular/              # shared Angular widgets used by browser+web+desktop
    ├── auth/                 # all auth flows
    ├── key-management/       # crypto + key derivation
    ├── platform/             # platform abstractions (storage, messaging)
    └── ...
```

The browser extension imports from `libs/`; it never duplicates auth, crypto, or vault logic across clients. **One bug fix in `libs/auth` propagates to browser + web + desktop + CLI simultaneously.**

## Why it matters for security

When you have credential-handling code in three places (extension, web app, desktop), you inevitably have three slightly different implementations. Subtle differences (e.g., a key-derivation iteration count off by 10x in one place) become security incidents. Bitwarden's `libs/` ensures everyone reads from the same source.

## Adaptation for your extension

### If you have multiple clients

Use a monorepo:

```
my-project/
├── apps/
│   ├── extension/              # the Chrome extension (WXT)
│   ├── web/                    # the dashboard at app.mybrand.com
│   └── cli/                    # the my-tool CLI
├── packages/
│   ├── core/                   # all business logic
│   ├── crypto/                 # key derivation, encryption
│   ├── api-client/             # backend HTTP client
│   └── ui/                     # shared React components
├── package.json                # workspaces: ["apps/*", "packages/*"]
└── pnpm-workspace.yaml         # if pnpm
```

With pnpm:

```yaml
# pnpm-workspace.yaml
packages:
  - 'apps/*'
  - 'packages/*'
```

`apps/extension/package.json`:

```json
{
  "dependencies": {
    "@my-project/core": "workspace:*",
    "@my-project/crypto": "workspace:*",
    "@my-project/api-client": "workspace:*"
  }
}
```

The extension imports as if these were npm packages; pnpm symlinks them so changes are picked up instantly.

### If you have only an extension (for now) but might add a web app later

Still factor business logic into a separate package, even if there's only one consumer:

```
my-extension/
├── apps/
│   └── extension/
└── packages/
    ├── core/                  # the logic that has no chrome.* dependency
    └── extension-shell/       # chrome.* wiring; pulls from core
```

When you later add `apps/web/`, you don't have to refactor.

### The crypto-isolation rule

In Bitwarden, `libs/key-management/` is the only module that touches `crypto.subtle.deriveKey` or `crypto.subtle.encrypt`. Every other module asks `key-management` to do crypto on its behalf.

This pattern:

- Centralizes audit surface — security review reads one module.
- Catches regressions — adding `crypto.subtle.*` anywhere else triggers a code review flag.
- Makes upgrades easier — switching from PBKDF2 to Argon2 means changing one file.

Adopt the rule even if your "crypto module" is just one file:

```
packages/crypto/
├── src/
│   ├── index.ts        # public API: encrypt(), decrypt(), deriveKey()
│   └── internal/       # implementations
└── package.json
```

ESLint rule to enforce:

```js
// .eslintrc.cjs at the root
module.exports = {
  rules: {
    'no-restricted-properties': ['error', {
      object: 'crypto',
      property: 'subtle',
      message: 'Use the @my-project/crypto package, not crypto.subtle directly.',
    }],
  },
  overrides: [{
    files: ['packages/crypto/**/*.ts'],
    rules: { 'no-restricted-properties': 'off' },
  }],
};
```

## State management — RxJS / Observables

Bitwarden uses Angular + RxJS. Their pattern: services expose `Observable<State>`; components subscribe in templates with `| async`. Updates flow through reducers/actions.

If you're React-based, the equivalents are Zustand, Jotai, or React Query for server state. Pick one and stick with it; mixing leads to chaos.

The principle: **state is in one place, with a typed API, observed reactively.** Avoid `chrome.storage.local.get(...)` in random places.

```ts
// packages/core/src/state/vault.ts
import { storage } from 'wxt/storage';
import { BehaviorSubject } from 'rxjs';

const vaultItem = storage.defineItem<Vault | null>('local:vault', { fallback: null });
const vault$ = new BehaviorSubject<Vault | null>(null);

vaultItem.watch((v) => vault$.next(v));
vaultItem.getValue().then((v) => vault$.next(v));

export { vault$ };
```

Components / popups subscribe to `vault$`. Storage and state stay in sync.

## When to skip the monorepo

If you have one extension and no other clients, no plans to expand, and the team is 1–3 people, a monorepo is overhead. A flat `src/` with disciplined module boundaries is enough.

The signal that it's time to monorepo:

- A second client is being planned (web app, CLI).
- You're copy-pasting logic from extension to another project.
- Your `src/` has separable layers (UI / business / crypto) and you'd benefit from enforcement.

## Licensing note

Bitwarden's clients are GPL-3.0. If you copy substantial code, your derivative work must also be GPL-3.0. **Architectural patterns** (like the `libs/` layout described here) are not copyrightable, so you can adopt them freely.

## What not to copy

- **Angular**: Bitwarden uses Angular for historical reasons. For new browser extensions, React/Vue/Svelte/Solid (or no framework) are more common and have better extension-specific tooling (WXT, Plasmo, CRXJS all support these but not Angular).
- **Their full monorepo size**: ~660 open issues, ~1.8k forks. The complexity comes from supporting many platforms with high security guarantees. Don't replicate it for a small project.
