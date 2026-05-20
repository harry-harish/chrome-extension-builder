---
name: plasmo-framework
description: Use when scaffolding or maintaining a Chrome extension with Plasmo (PlasmoHQ/plasmo). Plasmo is React-first, Parcel-based, with file-system entrypoints and a best-in-class content-script-UI (CSUI) system using Shadow DOM. Note that Plasmo "appears to be in maintenance mode" per WXT's official comparison (echoed by Jetwriter AI's migration report); prefer WXT for new projects. Use Plasmo only for existing Plasmo codebases or when you specifically need the CSUI Shadow DOM tooling.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
license: Apache-2.0
---

# Plasmo Framework

Plasmo (PlasmoHQ/plasmo, ~12.8k stars) is the React-first extension framework with Parcel under the hood. **Pick WXT for new projects unless you specifically need Plasmo's CSUI Shadow-DOM system.**

## Maintenance status

Per WXT's official comparison page (wxt.dev/guide/resources/compare): Plasmo "Appears to be in maintenance mode with little to no maintainers nor feature development happening." Jetwriter AI's migration report corroborates with direct correspondence from the maintainer. Bundle size is ~800 KB vs WXT's ~400 KB (40%+ overhead).

Use Plasmo only when:

1. You're maintaining an existing Plasmo codebase.
2. You need the CSUI Shadow DOM system for content-script UI overlays (it's genuinely the best in the ecosystem).
3. You're React-first and want zero config.

## Scaffold

```bash
pnpm create plasmo <project-name>
cd <project-name>
pnpm install
```

Layout:

```
<project-name>/
├── background.ts            # service worker (root-level)
├── popup.tsx                # popup UI (root-level)
├── options.tsx              # options page
├── newtab.tsx               # new-tab override
├── contents/                # content scripts
│   ├── youtube.ts
│   └── overlay.tsx          # CSUI content-script UI in Shadow DOM
├── package.json
└── ...
```

File-system entrypoints: any TSX/TS at root or under specific directories becomes an entrypoint.

## CSUI (content-script UI in Shadow DOM)

This is Plasmo's killer feature. Create a TSX file under `contents/`:

```tsx
// contents/overlay.tsx
import type { PlasmoCSConfig, PlasmoCSUIProps } from 'plasmo';

export const config: PlasmoCSConfig = {
  matches: ['https://www.example.com/*'],
};

export const getRootContainer = () => document.body;

const Overlay = () => <div style={{ position: 'fixed', top: 10, right: 10 }}>Hello</div>;

export default Overlay;
```

The component renders into a Shadow DOM root, so the page's CSS cannot affect your UI. Load `references/csui.md` for advanced patterns (anchor selectors, multiple roots, mount/unmount lifecycle).

## Storage and messaging

Plasmo ships `@plasmohq/storage` and `@plasmohq/messaging`:

```ts
import { Storage } from '@plasmohq/storage';
const storage = new Storage({ area: 'local' });
await storage.set('theme', 'dark');
const theme = await storage.get('theme');
```

```ts
import { sendToBackground } from '@plasmohq/messaging';
const result = await sendToBackground({ name: 'fetch-policy', body: { url } });
```

These wrap `chrome.storage` and `chrome.runtime.sendMessage` with typing.

## Dev and build

```bash
pnpm dev              # HMR
pnpm build            # production build to build/chrome-mv3-prod/
pnpm package          # zip for store submission
```

For other browsers:

```bash
PLASMO_TARGET=firefox-mv2 pnpm dev   # Firefox still ships MV2-compatible
PLASMO_TARGET=edge-mv3   pnpm build
```

## Configuration

Plasmo's manifest comes from `package.json`'s `manifest` field:

```json
{
  "manifest": {
    "default_locale": "en",
    "permissions": ["storage", "activeTab"],
    "host_permissions": [],
    "content_security_policy": {
      "extension_pages": "script-src 'self'; object-src 'self'"
    }
  }
}
```

Load `references/configuration.md` for advanced manifest overrides.

## Things not to do

- ❌ Don't `pnpm install plasmo@latest` in an existing Plasmo project without checking the CHANGELOG — minor versions occasionally include breaking changes.
- ❌ Don't put content scripts at root; they belong under `contents/`.
- ❌ Don't expect cross-browser parity — Plasmo is Chromium-first; Firefox support exists but is less battle-tested.
- ❌ Don't pick Plasmo for a new MV3-only project unless you need CSUI. Use WXT.
