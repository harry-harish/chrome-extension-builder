---
name: wxt-framework
description: Use when scaffolding, configuring, building, or shipping a Chrome extension with WXT (wxt.dev). WXT is the recommended default framework for 2026 — active maintenance, Vite-based, MV3-only, multi-browser (Chrome/Edge/Firefox/Safari), file-based entrypoints, best-in-class HMR, ~400 KB typical bundle. Load when the user picks WXT in /chrome-ext:new Phase 3, or when working in a project with `wxt` in package.json.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
license: Apache-2.0
---

# WXT Framework

WXT (`wxt.dev`, by @aklinker1) is the recommended default for new Chrome extensions in 2026.

## When to use WXT (default)

Always, unless the user has a specific reason to pick something else. Per ExtensionBooster's 2026 framework comparison and Jetwriter AI's published Plasmo→WXT migration: WXT produces ~400 KB bundles vs Plasmo's ~800 KB (40%+ overhead from the framework itself). WXT is also actively maintained (last npm publish within days as of mid-2026), supports all four browsers including Safari, and has the best HMR in the ecosystem.

## Scaffold

`wxt init` is interactive: it prompts for **template** and **package manager**. The `--template` flag pre-selects the template so only the package-manager prompt remains; the PM prompt defaults to whichever PM you invoked `dlx`/`exec` through.

```bash
pnpm dlx wxt@latest init <project-name> --template react-ts
cd <project-name>
pnpm install
```

**Default to the `-ts` variant** (`react-ts`, `vue-ts`, `svelte-ts`, `solid-ts`) — every reference extension in 2026 uses TypeScript and the plugin's `userConfig.typescript` defaults to `true`. Pick the non-TS variant only when you specifically opt out.

Templates available (as of WXT 0.20+): `vanilla`, `react`, `react-ts`, `vue`, `vue-ts`, `svelte`, `svelte-ts`, `solid`, `solid-ts`. If `react-ts` errors on an older WXT release that doesn't ship the explicit `-ts` name, fall back to `--template react` — current WXT React templates ship TypeScript regardless. Verify with `grep '"typescript"' package.json` after init.

For **fully non-interactive** scaffolding (CI, headless agent runs), use this skill's `scripts/scaffold-wxt.sh` helper, which writes the project files (TypeScript by default) directly without going through `wxt init`'s prompts.

After scaffolding, the layout is:

```
<project-name>/
├── entrypoints/
│   ├── background.ts          # service worker
│   ├── content.ts             # content script (or content/index.ts)
│   ├── popup/                 # popup UI (popup/index.html + popup/main.tsx)
│   ├── options/               # options page
│   └── ...
├── public/
│   └── icon/                  # 16, 32, 48, 96, 128 PNGs
├── wxt.config.ts              # WXT config (manifest, build options)
├── package.json
├── tsconfig.json
└── .wxt/                      # generated; gitignore'd
```

## Configuration (`wxt.config.ts`)

```ts
import { defineConfig } from 'wxt';

export default defineConfig({
  modules: ['@wxt-dev/module-react'],
  manifest: {
    name: '__MSG_extension_name__',
    description: '__MSG_extension_description__',
    default_locale: 'en',
    permissions: ['storage', 'activeTab'],
    optional_host_permissions: ['<all_urls>'],
    action: { default_title: '__MSG_action_title__' },
    content_security_policy: {
      extension_pages: "script-src 'self'; object-src 'self'"
    },
    web_accessible_resources: [
      { resources: ['icon/*.png'], matches: ['<all_urls>'] }
    ],
  },
  browser: 'chrome',  // or 'firefox', 'edge', 'safari'
  outDir: '.output',
  zip: { name: '{{name}}-{{browser}}-{{version}}.zip' },
});
```

Load `references/wxt-config.md` for the full config reference (build hooks, custom modules, multi-browser builds).

## Entrypoints

WXT discovers entrypoints by file convention. Background:

```ts
// entrypoints/background.ts
import { defineBackground } from 'wxt/sandbox';

export default defineBackground(() => {
  console.log('Background SW started');
  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    // delegate to controllers
  });
});
```

Content script:

```ts
// entrypoints/content.ts
import { defineContentScript } from 'wxt/sandbox';

export default defineContentScript({
  matches: ['*://*.github.com/*'],
  runAt: 'document_idle',
  main() {
    // your content script logic
  },
});
```

Popup (`entrypoints/popup/index.html` + `entrypoints/popup/main.tsx`):

```tsx
// entrypoints/popup/main.tsx
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';

createRoot(document.getElementById('app')!).render(<App />);
```

Load `references/entrypoints.md` for options page, side panel, devtools panel, new-tab override.

## Dev and build

```bash
pnpm dev              # HMR for all surfaces; opens Chrome with extension loaded
pnpm dev:firefox      # same for Firefox
pnpm build            # production build to .output/chrome-mv3/
pnpm build -b firefox # firefox build to .output/firefox-mv3/
pnpm zip              # build + zip for store submission
```

The dev command launches a fresh Chrome profile with the extension pre-loaded. No "load unpacked" dance.

## Multi-browser

```bash
pnpm build && pnpm build -b firefox && pnpm build -b edge && pnpm build -b safari
```

WXT auto-translates manifest differences (Firefox uses `browser_specific_settings.gecko.id`, Safari needs entitlements, etc.). Load `references/multi-browser.md` for the details.

## i18n

WXT respects `default_locale` in the manifest and copies `public/_locales/` into the build. Use `chrome.i18n.getMessage('key')` in code; reference messages from `manifest.json` as `__MSG_key__`.

Generate the directory:

```bash
mkdir -p public/_locales/en
```

`public/_locales/en/messages.json`:

```json
{
  "extension_name": {
    "message": "My Extension",
    "description": "The name shown in the toolbar and store listing."
  }
}
```

Load `references/i18n.md` for Crowdin/Weblate integration.

## Storage helpers

WXT ships `wxt/storage` — a typed wrapper over `chrome.storage`:

```ts
import { storage } from 'wxt/storage';

const theme = storage.defineItem<'light' | 'dark'>('local:theme', {
  fallback: 'light',
});

await theme.setValue('dark');
const v = await theme.getValue();
```

Use this instead of raw `chrome.storage.local.set` — it's typed, validated, and supports migrations.

## Messaging

WXT does **not** ship a messaging library. Build your own typed `sendCmd<T>`:

```ts
// types/messages.ts
export type Cmd =
  | { type: 'getTabs' }
  | { type: 'fetchPolicy'; url: string }
  | { type: 'saveItem'; item: { id: string; data: string } };

export type CmdResponse<C extends Cmd> =
  C extends { type: 'getTabs' } ? chrome.tabs.Tab[] :
  C extends { type: 'fetchPolicy' } ? { ok: boolean; data?: string } :
  C extends { type: 'saveItem' } ? { saved: boolean } :
  never;

export async function sendCmd<C extends Cmd>(cmd: C): Promise<CmdResponse<C>> {
  return chrome.runtime.sendMessage(cmd);
}
```

Load `references/messaging.md` for the four-execution-context pattern.

## Scripts in this skill

- `scripts/scaffold-wxt.sh` — runs `pnpm dlx wxt@latest init` with sane defaults.

## Things not to do

- ❌ Edit `.output/`, `.wxt/`, or `node_modules/`. They are regenerated.
- ❌ Hand-maintain `manifest.json` in the project root — WXT generates it. Edit `wxt.config.ts` instead.
- ❌ Use `localStorage` or `IndexedDB` directly — use `wxt/storage`.
- ❌ Use `<all_urls>` in `host_permissions` — put it in `optional_host_permissions` and request at runtime via `chrome.permissions.request`.
