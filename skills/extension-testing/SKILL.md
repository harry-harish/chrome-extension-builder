---
name: extension-testing
description: Use when setting up or running tests for a Chrome extension. Covers Vitest for unit tests, Playwright for E2E (the canonical pattern for loading unpacked extensions in Chromium), and Mozilla's `web-ext lint` for static analysis of the manifest and source. Load when adding tests, debugging test failures, or running the validation pipeline in /chrome-ext:new Phase 6–7.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
license: Apache-2.0
---

# Extension Testing

Three layers: unit (Vitest), static (web-ext lint), end-to-end (Playwright).

## Unit tests — Vitest

For pure functions, message-handler logic, validators — anything that doesn't touch `chrome.*` APIs or the DOM.

```bash
pnpm add -D vitest @types/chrome
```

Add to `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

For code that calls `chrome.*`, stub it at the test boundary:

```ts
// src/lib/storage.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

beforeEach(() => {
  globalThis.chrome = {
    storage: {
      local: {
        get: vi.fn().mockResolvedValue({ theme: 'dark' }),
        set: vi.fn().mockResolvedValue(undefined),
      },
    },
  } as any;
});

describe('getTheme', () => {
  it('returns the stored theme', async () => {
    const { getTheme } = await import('./storage');
    expect(await getTheme()).toBe('dark');
  });
});
```

For more realistic chrome API mocks, use `sinon-chrome` or roll your own minimal stub.

## Static lint — web-ext

Mozilla's `web-ext` ships `addons-linter`, which lints any MV3 manifest (yes, even Chrome-only extensions):

```bash
pnpm dlx web-ext@latest lint --source-dir=.output/chrome-mv3 --self-hosted
```

The `--self-hosted` flag suppresses warnings about Mozilla signing. Run this against the **built** output, not source — WXT/Plasmo/CRXJS process the manifest, and you want to lint what actually ships.

In CI, add it as a job:

```yaml
- name: Lint extension
  run: pnpm dlx web-ext@latest lint --source-dir=.output/chrome-mv3 --self-hosted
```

`scripts/lint-extension.sh` (bundled in this skill) wraps this and adds a `--target chrome|firefox|all` flag. `addons-linter` is Mozilla-maintained and enforces Firefox-MV3 requirements (`ADDON_ID_REQUIRED`, `BACKGROUND_SERVICE_WORKER_NOFALLBACK`, `STORAGE_SYNC`, `MISSING_DATA_COLLECTION_PERMISSIONS`) that don't apply to a Chrome-only extension. With `--target chrome` (the default) those rules are demoted from errors/warnings to a separate "Firefox-only demoted" section, so a clean Chrome-only extension can exit 0. Use `--target firefox` when shipping to Firefox (the extension then *must* include `browser_specific_settings.gecko.id` and a `background.scripts` fallback). `--target all` shows raw `addons-linter` output.

## End-to-end — Playwright

Per `playwright.dev/docs/chrome-extensions`: *"Google Chrome and Microsoft Edge removed the command-line flags needed to side-load extensions, so use Chromium that comes bundled with Playwright."*

Setup:

```bash
pnpm add -D @playwright/test
pnpm exec playwright install chromium
```

The canonical pattern uses `chromium.launchPersistentContext`:

```ts
// tests/smoke.spec.ts
import { test, expect, chromium, type BrowserContext } from '@playwright/test';
import path from 'node:path';

const EXTENSION_PATH = path.resolve(__dirname, '../.output/chrome-mv3');

test.describe('extension smoke', () => {
  let context: BrowserContext;
  let extensionId: string;

  test.beforeAll(async () => {
    context = await chromium.launchPersistentContext('', {
      channel: 'chromium',
      args: [
        `--disable-extensions-except=${EXTENSION_PATH}`,
        `--load-extension=${EXTENSION_PATH}`,
      ],
    });
    // Find the extension's service worker to extract the extension ID
    let [sw] = context.serviceWorkers();
    if (!sw) sw = await context.waitForEvent('serviceworker');
    extensionId = sw.url().split('/')[2];
  });

  test.afterAll(async () => {
    await context.close();
  });

  test('background SW responds to ping', async () => {
    const sw = context.serviceWorkers()[0];
    const result = await sw.evaluate(async () => {
      return new Promise((resolve) => {
        chrome.runtime.sendMessage({ type: 'ping' }, resolve);
      });
    });
    expect(result).toBeTruthy();
  });

  test('popup opens', async () => {
    const page = await context.newPage();
    await page.goto(`chrome-extension://${extensionId}/popup.html`);
    await expect(page.locator('body')).toBeVisible();
  });

  test('content script runs on matching URL', async () => {
    const page = await context.newPage();
    await page.goto('https://example.com');
    // your content script should set window.__cs_loaded = true
    await page.waitForFunction(() => (window as any).__cs_loaded === true, undefined, { timeout: 5000 });
  });
});
```

This file is bundled at `scripts/smoke.spec.ts`. Customize the matchers for your extension's URL patterns and surfaces.

### Headless mode

Playwright supports headless extension testing as of late 2024. Add `headless: true` to the launch options. Useful in CI.

### Multi-browser

For Firefox extension tests, Playwright supports `firefox.launchPersistentContext` with `web-ext` integration. Different API surface — see `references/playwright-firefox.md`.

## Smoke test signals to look for

Each test should fail loudly if:

1. Build failed → no `.output/chrome-mv3/` directory.
2. Manifest is invalid → Playwright can't load the extension.
3. SW failed to start → `context.serviceWorkers()` returns empty.
4. Popup HTML is missing or errors → `page.goto` returns non-200.
5. Content script doesn't run → sentinel never set.

## Things not to do

- ❌ Skip lint because the build succeeded. They check different things.
- ❌ Retry flaky tests in a loop. Investigate the flake.
- ❌ Mock `chrome.*` in E2E tests. The whole point is to drive a real browser.
- ❌ Test against `chrome.exe` directly. Playwright bundles Chromium; that's what works.
- ❌ Commit `playwright-report/` and `test-results/`. Gitignore them.

## Scripts in this skill

- `scripts/run-tests.sh` — runs lint + unit + E2E in sequence.
- `scripts/lint-extension.sh` — wraps `web-ext lint`.
- `scripts/smoke.spec.ts` — bundled Playwright smoke test.
