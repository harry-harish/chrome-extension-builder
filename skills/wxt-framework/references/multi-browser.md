# Multi-browser builds with WXT

WXT supports Chrome, Edge, Firefox, and Safari from one codebase. Run:

```bash
pnpm build           # default browser (Chrome)
pnpm build -b chrome
pnpm build -b firefox
pnpm build -b edge
pnpm build -b safari
```

Each produces a separate output dir: `.output/chrome-mv3/`, `.output/firefox-mv3/`, etc. (Firefox uses `firefox-mv2` if you specifically target Firefox MV2.)

## Manifest differences WXT handles automatically

- **Chrome / Edge**: vanilla MV3.
- **Firefox**: WXT adds `browser_specific_settings.gecko` if you set it in config. Firefox needs the addon ID for AMO submission.
- **Safari**: WXT emits a Safari-compatible bundle, but Safari extensions also need an Xcode project to wrap them. See WXT's Safari guide.

## Configuring per-browser overrides

Use a callable `manifest`:

```ts
import { defineConfig } from 'wxt';

export default defineConfig({
  manifest: ({ browser, manifestVersion, mode }) => {
    const base = {
      name: '__MSG_extension_name__',
      description: '__MSG_extension_description__',
      default_locale: 'en',
      permissions: ['storage', 'activeTab'],
      content_security_policy: {
        extension_pages: "script-src 'self'; object-src 'self'",
      },
    };

    if (browser === 'firefox') {
      return {
        ...base,
        browser_specific_settings: {
          gecko: {
            id: 'my-ext@your-domain.com',
            strict_min_version: '109.0',
          },
        },
      };
    }

    if (browser === 'safari') {
      // Safari has stricter CSP defaults; ensure object-src is explicit
      return {
        ...base,
        content_security_policy: {
          extension_pages: "script-src 'self'; object-src 'self'; img-src 'self' data:",
        },
      };
    }

    return base;
  },
});
```

## Zipping for each store

```bash
pnpm zip -b chrome    # → .output/<name>-chrome-<version>.zip
pnpm zip -b firefox   # → .output/<name>-firefox-<version>.zip
pnpm zip -b edge      # → .output/<name>-edge-<version>.zip
```

Chrome Web Store, Firefox AMO, and Edge Add-ons each take a different zip — submit independently.

## Sources zip for Firefox AMO review

AMO sometimes asks for a sources zip (a reproducible-build verification). WXT generates this with `--sources`:

```bash
pnpm zip -b firefox --sources
```

The sources zip excludes `node_modules`, build output, and dev configs by default. Customize via `wxt.config.ts`:

```ts
zip: {
  includeSources: ['src/**', 'public/**', 'wxt.config.ts', 'package.json', 'pnpm-lock.yaml'],
  excludeSources: ['**/*.test.ts', '**/*.spec.ts'],
}
```

## Safari

Safari extensions are a different beast — Safari requires:

1. An Xcode project that wraps the web extension.
2. An Apple Developer account for distribution.
3. The build to be processed through `xcrun safari-web-extension-converter` or built manually in Xcode.

WXT's `safari` target produces the web extension portion. You then run:

```bash
xcrun safari-web-extension-converter .output/safari-mv3 \
  --project-location ./safari-app \
  --bundle-identifier com.your-domain.your-extension \
  --no-open
```

This generates an Xcode project at `./safari-app/`. Open in Xcode, archive, distribute. Safari extensions can ship via Mac App Store or self-host as DMG.

Safari support in WXT is best-effort; ecosystem tooling is thinner than Chrome/Firefox. Test thoroughly.

## Caveats

- **Firefox MV3** has API differences from Chrome MV3. Notably: Firefox uses `browser.*` namespace by default (Chrome uses `chrome.*`). WXT's auto-imports normalize this. If you reference `chrome.*` explicitly, it works on Firefox MV3 too (Firefox provides a `chrome` alias), but `browser.*` is more idiomatic.
- **Firefox `chrome.storage.session`** was added later than Chrome's; check the Firefox version baseline you support.
- **Safari `chrome.storage.sync`** has quotas that differ from Chrome; don't assume parity.
- **Edge** is Chromium-based and behaves like Chrome for almost everything. Distribution is the only thing that differs (Microsoft Edge Add-ons store).

## When you don't need multi-browser

If your single audience is Chrome-only (corporate Chromebook fleets, very specific use cases), don't build for Firefox/Safari. The extra surface area to test isn't worth it.

If you do, treat Firefox as a first-class target from day one — retrofitting Firefox support later means catching every Chrome-specific assumption you made.
