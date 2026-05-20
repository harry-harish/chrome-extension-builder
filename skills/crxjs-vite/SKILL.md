---
name: crxjs-vite
description: Use when converting an existing Vite + React/Vue/Svelte project into a Chrome extension, or when the user explicitly picks CRXJS in /chrome-ext:new. CRXJS (crxjs/chrome-extension-tools) is a Vite plugin — not a framework — that adds extension support to a Vite app with content-script HMR. Chromium-only; slowed release cadence. Use when the user already has a Vite app and wants to keep their existing config, or when they need CRXJS's specific content-script HMR.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
license: Apache-2.0
---

# CRXJS + Vite

CRXJS (`crxjs/chrome-extension-tools`) is a Vite plugin that adds Chrome extension support to a standard Vite project. **It's not a framework** — you keep full control of `vite.config.ts` and `manifest.config.ts`.

## When to use

- You have an existing Vite + React (or Vue/Svelte) app you're converting into an extension.
- You need CRXJS's content-script HMR specifically (it's excellent).
- You're Chromium-first and don't need Firefox/Safari builds.

If none of those apply, **use WXT instead** — CRXJS has had slower releases through 2025-2026.

## Scaffold

Start from a standard Vite project:

```bash
pnpm create vite@latest <project-name> --template react-ts
cd <project-name>
pnpm install
pnpm add -D @crxjs/vite-plugin@beta
```

Add CRXJS to `vite.config.ts`:

```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { crx } from '@crxjs/vite-plugin';
import manifest from './manifest.config.ts';

export default defineConfig({
  plugins: [react(), crx({ manifest })],
  server: { port: 5173, strictPort: true, hmr: { port: 5173 } },
  build: { outDir: 'dist' },
});
```

Create `manifest.config.ts`:

```ts
import { defineManifest } from '@crxjs/vite-plugin';

export default defineManifest({
  manifest_version: 3,
  name: '__MSG_extension_name__',
  description: '__MSG_extension_description__',
  default_locale: 'en',
  version: '0.1.0',
  icons: {
    16: 'src/icons/16.png',
    32: 'src/icons/32.png',
    48: 'src/icons/48.png',
    128: 'src/icons/128.png',
  },
  action: { default_popup: 'src/popup/index.html', default_title: '__MSG_action_title__' },
  background: { service_worker: 'src/background.ts', type: 'module' },
  content_scripts: [
    {
      matches: ['*://*.example.com/*'],
      js: ['src/content/index.ts'],
      run_at: 'document_idle',
    },
  ],
  permissions: ['storage', 'activeTab'],
  content_security_policy: {
    extension_pages: "script-src 'self'; object-src 'self'",
  },
});
```

## Layout

```
<project-name>/
├── src/
│   ├── background.ts        # service worker
│   ├── content/
│   │   └── index.ts         # content script
│   ├── popup/
│   │   ├── index.html
│   │   └── main.tsx
│   ├── options/
│   │   ├── index.html
│   │   └── main.tsx
│   └── icons/
├── public/
│   └── _locales/
├── manifest.config.ts
├── vite.config.ts
└── package.json
```

## Dev and build

```bash
pnpm dev              # Vite dev server + extension auto-reload
pnpm build            # production build to dist/
```

To load the dev extension: open `chrome://extensions`, enable Developer mode, "Load unpacked", select `dist/` (after first `pnpm dev`).

CRXJS's content-script HMR works in the dev server — edits to content scripts hot-reload without losing page state.

## Manifest overrides per browser

Manual: maintain `manifest.firefox.config.ts` alongside `manifest.config.ts` and conditionally import based on env var. Or use a build script that patches the manifest after `vite build`.

This is one of the reasons CRXJS is Chromium-first — multi-browser support is your problem to solve.

## Things not to do

- ❌ Don't hand-edit `manifest.json` in `dist/` — it's regenerated. Edit `manifest.config.ts`.
- ❌ Don't put assets like icons in `public/` — CRXJS expects them in `src/` so it can rewrite paths.
- ❌ Don't expect WXT-level multi-browser support. If Firefox/Safari matter, switch to WXT.
- ❌ Don't pick CRXJS over WXT for a greenfield project unless you specifically need its content-script HMR.
