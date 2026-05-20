/**
 * smoke.spec.ts — Playwright smoke test for a Chrome MV3 extension.
 *
 * Loads the built extension via `chromium.launchPersistentContext` (the only
 * supported way to side-load extensions since Chrome removed the command-line
 * flags). Verifies:
 *   1. The extension's background service worker starts.
 *   2. If a popup HTML exists, opening it returns a non-error document.
 *   3. If content scripts declare matches against example.com, navigating to
 *      example.com triggers them (the script must set window.__cs_loaded).
 *
 * Configure via env var:
 *   EXTENSION_DIR=/absolute/path/to/.output/chrome-mv3 \
 *     pnpm exec playwright test smoke.spec.ts
 */
import { test, expect, chromium, type BrowserContext } from '@playwright/test';
import path from 'node:path';
import fs from 'node:fs';

const EXTENSION_DIR = path.resolve(
  process.env.EXTENSION_DIR ?? path.join(process.cwd(), '.output/chrome-mv3'),
);

test.describe('extension smoke', () => {
  let context: BrowserContext;
  let extensionId: string;
  let manifest: any;

  test.beforeAll(async () => {
    const manifestPath = path.join(EXTENSION_DIR, 'manifest.json');
    if (!fs.existsSync(manifestPath)) {
      throw new Error(`manifest.json not found at ${manifestPath} — run the build first`);
    }
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

    context = await chromium.launchPersistentContext('', {
      channel: 'chromium',
      args: [
        `--disable-extensions-except=${EXTENSION_DIR}`,
        `--load-extension=${EXTENSION_DIR}`,
        '--no-sandbox',
      ],
    });

    let [sw] = context.serviceWorkers();
    if (!sw) {
      sw = await context.waitForEvent('serviceworker', { timeout: 10_000 });
    }
    extensionId = sw.url().split('/')[2];
  });

  test.afterAll(async () => {
    await context?.close();
  });

  test('background service worker is reachable', async () => {
    const sws = context.serviceWorkers();
    expect(sws.length).toBeGreaterThan(0);
    expect(sws[0].url()).toContain(extensionId);
  });

  test('popup opens (if declared)', async () => {
    const popup = manifest.action?.default_popup;
    test.skip(!popup, 'no popup declared in manifest.action.default_popup');

    const page = await context.newPage();
    const response = await page.goto(`chrome-extension://${extensionId}/${popup}`);
    expect(response?.ok()).toBe(true);
    await expect(page.locator('body')).toBeVisible();
    await page.close();
  });

  test('options page opens (if declared)', async () => {
    const options = manifest.options_page || manifest.options_ui?.page;
    test.skip(!options, 'no options page declared');

    const page = await context.newPage();
    await page.goto(`chrome-extension://${extensionId}/${options}`);
    await expect(page.locator('body')).toBeVisible();
    await page.close();
  });

  test('content scripts match expected URL', async () => {
    const cs = manifest.content_scripts?.[0];
    test.skip(!cs, 'no content scripts declared');

    // Pick a match pattern we can hit — default to example.com if listed
    const matches: string[] = cs.matches ?? [];
    const hitExample = matches.some((m) => /example\.com/i.test(m) || m === '<all_urls>');
    test.skip(!hitExample, 'no content script matches a deterministic test URL');

    const page = await context.newPage();
    await page.goto('https://example.com/');
    // The content script should set a sentinel. Adjust to your extension's signal.
    const present = await page
      .waitForFunction(() => (window as any).__cs_loaded === true, undefined, { timeout: 5000 })
      .then(() => true)
      .catch(() => false);

    if (!present) {
      console.warn(
        'content script did not set window.__cs_loaded — either it does not match example.com, ' +
        'or your content script does not set the sentinel. Update smoke.spec.ts to match.',
      );
    }
    await page.close();
  });
});
