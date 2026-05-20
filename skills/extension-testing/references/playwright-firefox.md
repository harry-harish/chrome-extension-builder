# Playwright + Firefox extension testing

Firefox extension testing under Playwright is meaningfully different from Chrome. Three things differ:

1. **Launch flow** — Firefox uses `firefox.launchPersistentContext` but does NOT accept `--load-extension`. Instead you install via `web-ext` integration or remote-debugging-protocol.
2. **Service worker availability** — Firefox MV3 SWs exist, but the debugging API surface lags Chrome's. `context.serviceWorkers()` may not always show them.
3. **Permission model** — Firefox has stricter `host_permissions` runtime requests; UI dialogs trigger differently.

## Setup

```bash
pnpm add -D @playwright/test web-ext
pnpm exec playwright install firefox
```

## Loading the extension

The official Playwright recipe uses `web-ext run` under the hood. Two patterns:

### Pattern A — `web-ext run` controls Firefox

Have `web-ext` launch Firefox with your extension, then connect Playwright via remote debugging:

```ts
import { test, expect, firefox, type BrowserContext } from '@playwright/test';
import { execa } from 'execa';
import path from 'node:path';

const EXTENSION_DIR = path.resolve(__dirname, '../.output/firefox-mv3');
const RDP_PORT = 9222;

let webExtProc: ReturnType<typeof execa>;
let browser: any;

test.beforeAll(async () => {
  // Launch Firefox via web-ext with remote debugging enabled
  webExtProc = execa('npx', [
    'web-ext', 'run',
    '--source-dir', EXTENSION_DIR,
    '--firefox', 'firefox',
    '--no-reload',
    '--start-url', 'about:blank',
    '--arg', `--remote-debugging-port=${RDP_PORT}`,
  ], { stdout: 'pipe', stderr: 'pipe' });

  // Wait for Firefox to be ready
  await new Promise((r) => setTimeout(r, 5000));

  // Connect Playwright over remote-debugging
  browser = await firefox.connect(`ws://localhost:${RDP_PORT}`);
});

test.afterAll(async () => {
  await browser?.close();
  webExtProc?.kill();
});

test('extension loads in Firefox', async () => {
  // ... use browser as usual
});
```

This is brittle. The Playwright-Firefox-RDP integration is less polished than Chrome's.

### Pattern B — install the .xpi via `web-ext sign` ahead of time

For nightly CI runs, pre-build a signed .xpi and have Firefox install it from disk:

```bash
pnpm dlx web-ext sign --source-dir .output/firefox-mv3 --api-key=$AMO_JWT_ISSUER --api-secret=$AMO_JWT_SECRET
```

This requires AMO credentials. Not viable for ephemeral CI runs of unreleased extensions.

## Realistic recommendation

For most Firefox testing, **don't try to drive Playwright + Firefox**. Instead:

1. Run unit tests (Vitest) on the same code — they catch the bulk of logic bugs cross-browser.
2. Run `web-ext lint` against the built Firefox bundle — catches manifest incompatibilities.
3. Run Playwright + Chromium for the full E2E pass — catches actual interactive bugs.
4. For Firefox-specific behaviors, write **manual test checklists** that a human runs before each release. Document them in `docs/manual-tests.md`.

`web-ext` ships a `web-ext run --source-dir=.output/firefox-mv3` command that launches Firefox with the extension pre-loaded for manual testing:

```bash
pnpm dlx web-ext run --source-dir=.output/firefox-mv3 --start-url=about:debugging#/runtime/this-firefox
```

Open it for 5 minutes of manual exercise per release. That's more effective than fragile Playwright-Firefox automation.

## What you can test cross-browser

Pure logic (no `chrome.*`) is cross-browser identical. Test in Vitest with `chrome.*` mocked once:

```ts
// vitest.setup.ts
beforeEach(() => {
  globalThis.chrome = globalThis.browser = {
    storage: {
      local: {
        get: vi.fn().mockResolvedValue({}),
        set: vi.fn().mockResolvedValue(undefined),
      },
    },
    runtime: {
      sendMessage: vi.fn(),
      onMessage: { addListener: vi.fn() },
    },
  } as any;
});
```

This covers ~80% of the codebase. The remaining 20% (DOM injection, popup interactions, content script side effects) needs real browser testing — and Chrome is the right surface for the automated part of that.

## When Firefox-specific testing matters

- You ship a Firefox-only release branch.
- You use Firefox-specific APIs (e.g., `browser.contextualIdentities`, `browser.tabs.captureTab`).
- You have past bug reports specific to Firefox.

In those cases, invest in Pattern A above and accept the brittleness. Otherwise, save the time.

## Status of Playwright's Firefox extension support

As of mid-2026, Playwright's Firefox extension testing is documented but underdeveloped. The bug tracker has several open issues (`microsoft/playwright#18854`, `#20783`, others) about extension reliability on Firefox. Watch for updates; until then, the manual + Chromium-driven approach is more reliable.

## Alternative: Selenium with geckodriver

Selenium has more mature Firefox extension support via `addonInstall`. If you genuinely need automated Firefox E2E, Selenium remains a reasonable choice — but the API is older and slower to iterate against.
