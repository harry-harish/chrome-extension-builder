# Plasmo configuration

Plasmo's "config" is split between `package.json#manifest` (manifest overrides), CLI environment variables (build targets), and per-file `export const config` (entrypoint config).

## package.json manifest field

The `manifest` field is merged into the auto-generated manifest. Use it to override or add fields Plasmo doesn't infer.

```json
{
  "name": "my-extension",
  "version": "0.1.0",
  "manifest": {
    "default_locale": "en",
    "permissions": ["storage", "activeTab"],
    "host_permissions": [],
    "optional_host_permissions": ["<all_urls>"],
    "content_security_policy": {
      "extension_pages": "script-src 'self'; object-src 'self'; base-uri 'self'"
    },
    "web_accessible_resources": [
      {
        "resources": ["assets/*"],
        "matches": ["<all_urls>"]
      }
    ],
    "browser_specific_settings": {
      "gecko": {
        "id": "my-extension@your-domain.com",
        "strict_min_version": "109.0"
      }
    }
  }
}
```

Plasmo merges these on top of the auto-inferred fields (background SW path, content script `matches`, action default popup, etc.). It does not let you override `manifest_version` (always 3) or `version` (read from `package.json#version`).

## Build targets via env vars

```bash
# Default — Chrome MV3
pnpm build

# Specific target
PLASMO_TARGET=chrome-mv3 pnpm build
PLASMO_TARGET=firefox-mv2 pnpm build   # Firefox still supports MV2
PLASMO_TARGET=firefox-mv3 pnpm build
PLASMO_TARGET=edge-mv3 pnpm build
PLASMO_TARGET=opera-mv3 pnpm build
PLASMO_TARGET=brave-mv3 pnpm build
```

Output paths follow `build/<target>-prod/`:

- `build/chrome-mv3-prod/`
- `build/firefox-mv2-prod/`
- `build/edge-mv3-prod/`

`PLASMO_TAG=preview` produces preview builds with separate output paths.

## Entrypoint config

Each content script and CSUI component can export a `config`:

```ts
// contents/youtube.ts
import type { PlasmoCSConfig } from 'plasmo';

export const config: PlasmoCSConfig = {
  matches: ['https://www.youtube.com/*'],
  run_at: 'document_idle',
  all_frames: false,
};

export default function() {
  // content script logic
}
```

Available fields (subset; see Plasmo docs for the full list):

- `matches` — URL match patterns.
- `exclude_matches` — exclusions.
- `match_about_blank` — run in `about:blank` frames.
- `run_at` — `document_start | document_end | document_idle`.
- `all_frames` — inject into every frame.
- `world` — `MAIN | ISOLATED` (MV3, for page-world injection).

Background scripts don't need a config — Plasmo just bundles `background.ts` as the SW.

## Public assets

Files in `assets/` (or any directory named `assets/` anywhere in `src/`) are bundled and accessible at runtime:

```tsx
import iconUrl from 'data-base64:~assets/icon.png';

const Popup = () => <img src={iconUrl} />;
```

The `data-base64:` prefix bundles the asset as a base64 data URL. Other prefixes:

- `data-url:` — produces a `data:` URL.
- `data-text:` — produces the file contents as text.
- `url:` — produces a regular file URL (file goes into web_accessible_resources).

## Environment variables at build time

Prefix env vars with `PLASMO_PUBLIC_` to expose them to the bundled code:

```bash
PLASMO_PUBLIC_API_URL=https://api.example.com pnpm build
```

```ts
const apiUrl = process.env.PLASMO_PUBLIC_API_URL;
```

Variables without the prefix are not bundled — useful for build-time secrets.

## .env files

Plasmo reads `.env`, `.env.local`, `.env.production`, `.env.development`. Pattern matches what Vite uses.

```
# .env
PLASMO_PUBLIC_API_URL=https://api.example.com
SECRET_KEY=server-side-only
```

Only `PLASMO_PUBLIC_*` vars are exposed to the browser.

## Plasmo storage scoping

`@plasmohq/storage` defaults to `chrome.storage.local`. Change with `area`:

```ts
import { Storage } from '@plasmohq/storage';

const localStorage = new Storage({ area: 'local' });
const syncStorage = new Storage({ area: 'sync' });
const sessionStorage = new Storage({ area: 'session' });
```

For sensitive data, use `secret` storage (Plasmo encrypts):

```ts
import { SecureStorage } from '@plasmohq/storage/secure';

const secret = new SecureStorage();
await secret.setPassword('user-passphrase');
await secret.set('vault', 'sensitive-value');
```

`SecureStorage` encrypts at rest. The encryption key is derived from the passphrase you pass — see `extension-security/references/key-storage.md` for the broader pattern.

## Hot reload behavior

`pnpm dev` reloads:
- Popup, options pages: HMR (no extension reload needed).
- Content scripts: HMR.
- Background SW: extension reload (Plasmo notifies you in the console).

For full reset (sometimes needed after manifest changes), restart `pnpm dev` and reload the extension in `chrome://extensions`.

## Customizing the build

Plasmo's build is Parcel-based, but config knobs are limited. For deep customization:

1. Add Parcel transformers via `package.json#@parcel/transformer-*`.
2. Patch the generated manifest in a post-build script.
3. Switch to WXT if you need full control over the bundler.

## Per-browser overrides

Plasmo's manifest field doesn't have first-class per-browser branching. Use env vars + multiple `package.json` entries, or run a post-build patch script:

```js
// scripts/patch-firefox.mjs
import fs from 'node:fs';
const manifestPath = 'build/firefox-mv2-prod/manifest.json';
const m = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
m.browser_specific_settings = {
  gecko: { id: 'my-extension@your-domain.com', strict_min_version: '109.0' },
};
fs.writeFileSync(manifestPath, JSON.stringify(m, null, 2));
```

Run after `PLASMO_TARGET=firefox-mv2 pnpm build`.

This is one of Plasmo's pain points vs WXT — multi-browser support is your problem to solve.
