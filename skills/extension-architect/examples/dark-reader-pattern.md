# Dark Reader pattern — pure-TS, no-framework, reproducible builds

## Source

`darkreader/darkreader`. ~22k stars, MIT, TypeScript. Distributed as both a Chrome extension and a standalone npm library.

## What to copy

Dark Reader is one of the cleanest examples of a high-performance, **no-framework** extension. The build system is a hand-rolled Node script (no Webpack, no Vite, no Rollup). The same TypeScript codebase ships as:

1. The browser extension (Chrome + Firefox + Safari + Edge)
2. A standalone npm package (`npm install darkreader`)
3. A CLI utility

That triple-distribution is the killer feature to copy if your domain logic is reusable outside the extension context.

## Architectural anchors

1. **No framework.** Pure TS + custom build script (`src/build.js` runs as Node or Deno). Surface tree:

   ```
   src/
   ├── background/        # background SW logic
   ├── inject/            # injected page-world scripts
   ├── ui/                # popup/options UI (no React; uses Malevic, the author's tiny VDOM lib)
   ├── generators/        # the core color-analysis engine — reused in the npm lib
   ├── utils/
   └── api/               # public API exposed when imported as a library
   ```

2. **Same code, different targets.** Color analysis is in `src/generators/`. It has no dependencies on `chrome.*` APIs. The extension wraps it in chrome-storage handlers; the npm library exposes it directly to web apps.

3. **`chrome.storage.sync` with `local` fallback.** Sync first, fallback to local if sync quota is exceeded.

   ```ts
   try {
     await chrome.storage.sync.set({ settings });
   } catch (e) {
     console.warn('sync quota exceeded; falling back to local', e);
     await chrome.storage.local.set({ settings });
   }
   ```

4. **Site-fixes are bundled, not synced.** Dark Reader maintains a list of per-site CSS overrides for sites with quirky dark-theme support. These are **bundled at build time** and shipped with the extension. Live sync of fixes from a GitHub repo is intentionally disabled by default — the author's note in the README explains that GitHub doesn't allow being used as a CDN.

5. **Reproducible builds.** The repo includes digitally-signed artifacts from the Firefox Add-ons store. Mozilla reviewers can build from source and bit-compare against the published bundle. This level of reproducibility is rare but valuable for trust-sensitive extensions.

## Adaptation for your extension

### If your domain logic is reusable as a library

Structure your code so that anything not chrome-specific lives in `src/core/` (or wherever). Have a separate `src/extension/` that imports from `core/` and wraps it in `chrome.*` APIs. Add an `src/library/` entry point that re-exports `core/` as an npm package.

```ts
// src/core/transform.ts
export function transformImage(input: ImageData, options: Options): ImageData {
  // pure logic; no chrome.*
}

// src/extension/background.ts
import { transformImage } from '../core/transform';
chrome.runtime.onMessage.addListener(async (msg) => {
  if (msg.type === 'transform') return transformImage(msg.input, msg.options);
});

// src/library/index.ts
export { transformImage } from '../core/transform';
```

Add a separate `package.json` field:

```json
{
  "name": "my-cool-extension",
  "exports": {
    ".": "./dist/library/index.js"
  }
}
```

Now `npm install my-cool-extension` gets the library; the `.zip` bundle has the extension. One repo, two products.

### If you want reproducible builds

1. Commit `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`.
2. Use a fixed Node version in `.nvmrc` and `package.json#engines.node`.
3. Don't use timestamps in generated artifacts. Set `SOURCE_DATE_EPOCH` if your bundler supports it.
4. Bundle commit SHA into your version string only at build time; don't read `git rev-parse` at runtime.
5. Ship the build script with your release artifact so reviewers can rebuild.

### If you want a no-framework UI

Dark Reader uses `Malevic`, a tiny VDOM library by the same author (~3 KB). If your UI is genuinely simple (popup with a toggle, status display), framework-free is great:

- Direct DOM manipulation: fastest, smallest bundle.
- `Malevic` / `Mithril` / `Preact` (compatible): small VDOM, no React overhead.
- `lit-html`: web components.

Bundle size matters because popups should open instantly.

## Performance notes

Dark Reader transforms CSS for every page in real-time. To keep this fast:

- The analysis runs in the content script's isolated world, not in the background SW (which would require shipping pixels back and forth).
- It runs on `document_start` so the user never sees the original light theme.
- Computed transformations are cached in `chrome.storage.session` per URL.

Lessons: do CPU work where it belongs (content script for DOM, background for coordination). Cache anything you compute that's per-page.

## What not to copy

- **No framework**: only do this if your UI is genuinely simple. Adding React/Vue/Svelte to a complex popup later is painful.
- **Custom build script**: Dark Reader can afford this because it has dedicated maintainers. For most projects, WXT or Plasmo's automation pays for itself.
- **Reproducible builds**: nice-to-have for non-sensitive extensions; mandatory for credential/crypto-handling ones.

## When to study Dark Reader more deeply

If your extension:
- Manipulates CSS or computed styles on every page
- Needs to work fast on `document_start`
- Could plausibly be useful outside the browser as a library
- Handles untrusted CSS input safely

… then read `src/generators/css-rules.ts` (the core color analysis), `src/inject/dynamic-theme.ts` (the runtime CSS rewriter), and the README's "Architecture" section.
