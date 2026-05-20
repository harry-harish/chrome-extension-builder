# Stylus pattern — tiny content script + embedded code editor

## Source

`openstyles/stylus` on GitHub. ~6.6k stars, GPL-3.0, JavaScript.

## What to copy

Stylus is the canonical example of:

1. **A tiny content script** (~10 KB, ~1 ms per site).
2. **An embedded code editor** (CodeMirror) inside the extension's options UI.
3. **Multi-cloud sync** (Dropbox, GDrive, OneDrive, WebDAV).
4. **Explicit no-analytics/no-tracking policy** — Stylus exists because the original Stylish was sold to a Web-analytics company.

## Tiny content script

Stylus injects user-authored CSS into pages. The content script does only:

1. Receive the matching CSS payload from background.
2. Inject `<style>` into the page.
3. Listen for updates.

That's it. No DOM walking, no MutationObserver beyond what's strictly needed, no heavy computation. The script is loaded synchronously at `document_start` so users never see un-styled content.

```ts
// content.ts — pattern (paraphrased)
chrome.runtime.sendMessage({ type: 'getStyles', url: location.href }, (styles) => {
  if (!styles || !styles.length) return;
  const styleEl = document.createElement('style');
  styleEl.textContent = styles.map((s) => s.css).join('\n');
  (document.head || document.documentElement).appendChild(styleEl);
});
```

The lesson: **content scripts should be small.** Anything compute-heavy belongs in the background SW or in a popup the user opens deliberately.

## Embedded CodeMirror

Stylus ships CodeMirror inside the extension. Under MV3's CSP, this requires:

1. Bundle CodeMirror with the extension (don't fetch from CDN).
2. Avoid CodeMirror modes that use `eval` (some legacy ones do).
3. Use the ES module build, not the legacy script-tag build.

```html
<!-- options.html -->
<script type="module" src="codemirror-bundled.js"></script>
```

Or with WXT:

```ts
// entrypoints/options/main.ts
import { EditorView, basicSetup } from 'codemirror';
import { css } from '@codemirror/lang-css';

new EditorView({
  doc: 'body { background: red; }',
  extensions: [basicSetup, css()],
  parent: document.querySelector('#editor')!,
});
```

This works in MV3 because everything is local. No `eval`, no remote scripts.

## Multi-cloud sync abstraction

Stylus syncs to Dropbox, Google Drive, OneDrive, and WebDAV. The pattern is a clean abstraction:

```ts
// src/sync/provider.ts
interface SyncProvider {
  authenticate(): Promise<void>;
  upload(filename: string, content: string): Promise<void>;
  download(filename: string): Promise<string>;
  list(): Promise<string[]>;
}

class DropboxProvider implements SyncProvider { /* ... */ }
class GDriveProvider implements SyncProvider { /* ... */ }
class OneDriveProvider implements SyncProvider { /* ... */ }
class WebDAVProvider implements SyncProvider { /* ... */ }

const providers: Record<string, () => SyncProvider> = {
  dropbox:  () => new DropboxProvider(),
  gdrive:   () => new GDriveProvider(),
  onedrive: () => new OneDriveProvider(),
  webdav:   () => new WebDAVProvider(),
};
```

Each provider handles its own OAuth and quirks. The sync engine doesn't care which one is selected.

Use `chrome.identity.launchWebAuthFlow` for OAuth where possible — it manages the redirect URI for you:

```ts
const url = await chrome.identity.launchWebAuthFlow({
  url: `https://www.dropbox.com/oauth2/authorize?client_id=…&response_type=token&redirect_uri=${chrome.identity.getRedirectURL()}`,
  interactive: true,
});
const token = new URL(url).hash.match(/access_token=([^&]+)/)?.[1];
```

## "No analytics" as a feature

Stylus's README explicitly states no analytics, no tracking, no telemetry. This isn't just principles — it's a competitive advantage:

- Users frustrated with Stylish (sold to analytics company) actively seek out Stylus.
- Privacy advocates link to Stylus as an example.
- CWS review is faster — no "what data do you collect?" friction.

If your extension can credibly do without telemetry, advertise that fact:

- Add to README: "No analytics. No tracking. No telemetry. Verified by reading the source."
- Add to CWS listing's privacy disclosure: "This extension does not collect any user data."
- In code, grep regularly to ensure no analytics SDKs sneak in via deps.

If you must collect data (crash reports, opt-in usage stats), make it opt-in and clearly explained.

## Adaptation for your extension

### If you have a popup/options with a complex editor

CodeMirror or Monaco both work in MV3 if bundled locally. CodeMirror is smaller (~150 KB) and easier to bundle than Monaco (~5 MB). For most extensions, CodeMirror is the right pick.

### If you sync to user's cloud

Abstract behind a `SyncProvider` interface. Don't bake assumptions about which provider into your code. Make WebDAV one of the options — it's the open-standard fallback.

### If you want a tiny content script

Keep these out of your content script:

- ❌ Heavy libraries (React, Vue, lodash if you only need one function)
- ❌ Bundle-time imports of crypto, fetch, URL polyfills (the page already has these)
- ❌ MutationObservers that walk all elements
- ❌ Computation that doesn't need DOM access

Keep these in:

- ✅ Specific selectors and event handlers
- ✅ Lightweight DOM additions
- ✅ Postback to background for anything heavier

## What not to copy

- Stylus's vanilla-JS approach: it works for them; for new projects, TypeScript + WXT pays off.
- Their multi-provider sync if you don't actually need it. Most extensions can get away with `chrome.storage.sync` alone (with the 100 KB / 8 KB caveats).

## Why this matters

The user experience of an extension with a 10 KB content script vs a 200 KB one is night and day. The 10 KB extension feels instant; the 200 KB one feels like a tax on every page load.

Performance is a feature. Keep content scripts lean.
