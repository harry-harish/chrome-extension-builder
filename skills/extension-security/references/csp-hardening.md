# CSP hardening for Manifest V3 extensions

## MV3 default

Per Chrome docs, MV3 enforces a default CSP equivalent to:

```
script-src 'self'; object-src 'self';
```

This is strict — no inline scripts, no remote scripts, no `eval`. **Don't relax it.** Best-architected extensions also tighten it:

```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
  }
}
```

## Directives that matter

### `script-src 'self'`

Only allow scripts from the extension's own origin. **No `unsafe-eval`. No `unsafe-inline`. No remote URLs.**

If a library you depend on needs `eval` (some templating engines, some JIT WASM loaders), do one of:

1. Replace the library with a CSP-safe alternative.
2. Move that code to a sandbox page (see below).
3. Drop the feature.

### `object-src 'self'`

Disallows `<object>`, `<embed>`, `<applet>`. There's no good reason to allow them in 2026. Lock down.

### `base-uri 'self'`

Prevents `<base>` tag injection from rewriting all relative URLs. Cheap, valuable.

### `form-action 'self'`

Forms can only submit to the extension's own origin. Prevents data exfil via injected `<form>`.

### `frame-ancestors 'none'`

Extension pages can't be embedded in iframes. Defense against UI redress.

### `connect-src`

Controls where `fetch`/`XMLHttpRequest`/`WebSocket` can go. Default lets you connect anywhere; locking down helps catch exfil:

```
connect-src 'self' https://api.your-backend.com https://*.your-cdn.com;
```

### `style-src 'self' 'unsafe-inline'`

This is the one place `'unsafe-inline'` is hard to avoid — React inline styles, dynamic theming, etc. Strict CSP fans split styles into separate files; pragmatists allow `'unsafe-inline'` here only.

If you can manage external stylesheets only:

```
style-src 'self';
```

## Sandbox pages

If you genuinely need `eval` (some JS templating libraries, some legacy code), put it in a sandbox page:

```json
{
  "content_security_policy": {
    "extension_pages": "script-src 'self'; object-src 'self'",
    "sandbox": "sandbox allow-scripts; script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval'; child-src 'self';"
  },
  "web_accessible_resources": [{
    "resources": ["sandbox.html"],
    "matches": ["<all_urls>"]
  }]
}
```

Then load `sandbox.html` in an iframe and `postMessage` to it:

```ts
// in your popup or options
const iframe = document.createElement('iframe');
iframe.src = chrome.runtime.getURL('sandbox.html');
iframe.style.display = 'none';
document.body.appendChild(iframe);
iframe.addEventListener('load', () => {
  iframe.contentWindow!.postMessage({ template: '...', data: {...} }, '*');
});
window.addEventListener('message', (e) => {
  if (e.source === iframe.contentWindow) {
    // result from sandboxed evaluation
  }
});
```

The sandbox runs in a null origin with no `chrome.*` access. Even if compromised, it can only damage itself.

## WebAssembly

If you bundle WASM, add `'wasm-unsafe-eval'`:

```
script-src 'self' 'wasm-unsafe-eval'; object-src 'self';
```

This is allowed in MV3 — it doesn't enable regular `eval`, only WebAssembly compilation.

## blob: and data: URLs

Worker scripts loaded from `blob:` URLs (common pattern for inline workers) need:

```
worker-src 'self' blob:;
```

`data:` URLs in `script-src` are forbidden by MV3. Avoid `<script src="data:application/javascript,…">`.

## Content scripts have their own CSP

Content scripts inherit the **page's** CSP for resources they load via the page. They can use `chrome.scripting.insertCSS({ css: '...' })` and `chrome.scripting.executeScript({ files: ['cs.js'] })` regardless of the page's CSP.

Anything your content script `fetch()`es from inside the content script uses the page's CSP and origin. To bypass the page's CSP, `sendCmd` to the background and have it fetch.

## Common CSP violations and fixes

| Violation | Fix |
|---|---|
| `<script>alert(1)</script>` inline in HTML | Move to external `.js` file |
| `<button onclick="foo()">` | Use `addEventListener('click', foo)` in external script |
| `<a href="javascript:foo()">` | Use real `<button>` with handler |
| `setTimeout('foo()', 100)` (string form) | `setTimeout(() => foo(), 100)` (function form) |
| `new Function('return 1+1')()` | Replace with actual function definitions |
| `eval('1+1')` | Replace with actual expression |
| `<iframe src="https://example.com">` (in extension page) | Either bundle the page locally or use `connect-src` to fetch and render |
| `<img src="data:image/svg+xml,…">` | Allowed (img-src defaults to *); but inline SVG `<script>` runs into CSP |

## Auditing your CSP

The `validate-csp.sh` script (in this plugin) checks for:

- `unsafe-eval` in `extension_pages` (CRITICAL)
- `unsafe-inline` in `extension_pages` (CRITICAL)
- Remote `https?://...` sources (CRITICAL)
- Missing `script-src` / `object-src` directives (INFO)

Run it after every manifest change. The PostToolUse hook in this plugin runs it automatically.

## CSP reporting

For production extensions, configure `report-uri` or `report-to` to learn about violations users hit:

```
script-src 'self'; report-uri https://your-backend.com/csp-report;
```

The browser POSTs JSON violation reports to that URL. Treat them like crash reports.

## Why this matters

Most extension security incidents stem from CSP violations — XSS, data exfil, malicious payload injection. A strict CSP closes most of those paths automatically. **Be explicit even when MV3 has defaults.**
