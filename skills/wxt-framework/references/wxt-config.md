# wxt.config.ts — reference

A typical production WXT config:

```ts
import { defineConfig } from 'wxt';

export default defineConfig({
  modules: ['@wxt-dev/module-react'],

  manifest: {
    name: '__MSG_extension_name__',
    description: '__MSG_extension_description__',
    default_locale: 'en',

    permissions: ['storage', 'activeTab'],
    optional_permissions: ['notifications'],
    optional_host_permissions: ['<all_urls>'],

    action: {
      default_title: '__MSG_action_title__',
      default_icon: {
        16: '/icon/16.png',
        32: '/icon/32.png',
        48: '/icon/48.png',
        128: '/icon/128.png',
      },
    },

    icons: {
      16: '/icon/16.png',
      32: '/icon/32.png',
      48: '/icon/48.png',
      128: '/icon/128.png',
    },

    content_security_policy: {
      extension_pages: "script-src 'self'; object-src 'self'; base-uri 'self'",
    },

    web_accessible_resources: [
      {
        resources: ['icon/*.png'],
        matches: ['<all_urls>'],
      },
    ],

    // Optional manifest fields
    homepage_url: 'https://github.com/your-org/your-extension',
    author: { email: 'support@your-domain.com' },
    offline_enabled: true,
  },

  browser: 'chrome',
  outDir: '.output',

  zip: {
    name: '{{name}}-{{browser}}-{{version}}.zip',
    excludeSources: ['**/*.test.ts', '**/*.spec.ts'],
  },

  // Build hooks for advanced manipulation
  hooks: {
    'build:manifestGenerated': (wxt, manifest) => {
      // Bundle commit SHA into version_name (display only; "version" must remain numeric)
      if (process.env.GIT_SHA) {
        manifest.version_name = `${manifest.version} (${process.env.GIT_SHA.slice(0, 7)})`;
      }
    },
  },
});
```

## Field-by-field

### `modules`

Plug-ins from `@wxt-dev/module-*` packages. Common:

- `@wxt-dev/module-react` — adds React support and `entrypoints/popup/main.tsx` conventions.
- `@wxt-dev/module-vue` — Vue equivalent.
- `@wxt-dev/module-svelte` — Svelte equivalent.
- `@wxt-dev/module-solid` — Solid equivalent.

Use exactly one UI framework module. WXT also supports vanilla TypeScript with no module.

### `manifest`

Object that becomes the generated `manifest.json`. WXT adds defaults (`manifest_version: 3`, `version` from `package.json`, etc.).

Notes:

- Use `__MSG_*__` placeholders for any user-visible string (see `i18n.md`).
- Don't set `manifest_version` — WXT forces it to 3.
- Don't set `version` here — WXT reads it from `package.json`.
- Use `default_icon` inside `action` AND top-level `icons`. The top-level is the CWS-displayed icon; the action's is the toolbar.

### `browser`

`chrome` (default), `firefox`, `edge`, `safari`. Switch with `wxt build -b firefox`.

### `outDir`

Where built output lands. Default `.output`. Files end up in `.output/<browser>-mv3/`.

### `zip`

How the store-submission zip is named and packaged.

- `name`: template variables `{{name}}`, `{{browser}}`, `{{version}}`, `{{mode}}`.
- `excludeSources`: globs to exclude from the zip (tests, fixtures, source maps).

### `hooks`

Build-time hooks for advanced manipulation. Common ones:

- `build:manifestGenerated` — patch the manifest just before it's written. Used for git SHA injection, env-based feature flags, etc.
- `build:done` — runs after all builds finish.
- `zip:done` — runs after `wxt zip`.

Full hook list: `wxt.dev/api/cli/wxt-hooks`.

### `imports`

WXT auto-imports common APIs. Disable per-import or all:

```ts
imports: {
  presets: ['preact'],     // auto-imports for preact
  imports: [
    { name: 'useState', from: 'react' },
  ],
  // ... or to disable:
  // false,
}
```

This is a productivity feature; types and IDE support work. Disable if you prefer explicit imports.

### `runner`

Configuration for `wxt dev` (which launches Chrome with the extension auto-loaded):

```ts
runner: {
  startUrls: ['https://github.com'],
  chromiumArgs: ['--auto-open-devtools-for-tabs'],
}
```

`startUrls` is convenient — Chrome opens those tabs on launch. Defaults to `chrome://extensions`.

## Multi-browser build matrix

```bash
pnpm wxt build -b chrome
pnpm wxt build -b firefox
pnpm wxt build -b edge
```

WXT translates manifest differences automatically:

- Firefox: adds `browser_specific_settings.gecko` for the addon ID.
- Edge: largely same as Chrome.
- Safari: needs special handling; see `multi-browser.md`.

If you need browser-specific manifest entries, branch in config:

```ts
import { defineConfig } from 'wxt';

export default defineConfig({
  manifest: ({ browser, manifestVersion, mode }) => {
    const base = {
      permissions: ['storage', 'activeTab'],
    };
    if (browser === 'firefox') {
      return {
        ...base,
        browser_specific_settings: {
          gecko: { id: 'my-ext@your-domain.com', strict_min_version: '109.0' },
        },
      };
    }
    return base;
  },
});
```

## Dev vs prod

WXT distinguishes via `mode`:

```ts
manifest: ({ mode }) => ({
  name: mode === 'development' ? 'My Extension (DEV)' : '__MSG_extension_name__',
  // ...
});
```

This is useful for visually distinguishing the dev-loaded extension from the production one when both are installed.

## Common pitfalls

- ❌ Don't edit `manifest.json` directly — WXT regenerates it from `wxt.config.ts`. Edits will be overwritten.
- ❌ Don't put assets at `public/_locales/` if you also reference them in `manifest.icons` — the icons need to be at `public/icon/*.png` instead.
- ❌ Don't set CSP that conflicts with WXT's HMR in dev — WXT injects `'unsafe-eval'` for dev to make HMR work, but only in dev mode.
- ❌ Don't commit `.output/` or `.wxt/` — they're regenerated.

## When to outgrow WXT config

If you need:
- Custom Vite plugins beyond what WXT exposes → add them to `vite: { plugins: [...] }`.
- Custom Rollup options at build time → use the `build` field.
- Completely custom manifest generation → consider hand-rolling a minimal Vite + CRXJS setup.

WXT's escape hatches cover most cases without needing to leave the framework.
