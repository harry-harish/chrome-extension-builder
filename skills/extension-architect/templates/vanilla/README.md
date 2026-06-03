# Vanilla MV3 starter

A minimal Manifest V3 Chrome extension with no framework. Use this for:

- Tiny extensions (<1k LOC).
- Learning the underlying mechanics.
- Maximum control with no build pipeline.

For anything non-trivial, use WXT instead (`pnpm dlx wxt@latest init`).

## Layout

```
.
├── manifest.json
├── background.js     # service worker
├── content.js        # content script
├── popup.html
├── popup.js
├── popup.css
├── _locales/
│   └── en/messages.json
├── icons/            # Add 16/32/48/128 PNGs here
└── README.md
```

## Develop

1. Open `chrome://extensions` in Chrome.
2. Enable **Developer mode** (top right).
3. Click **Load unpacked** and select this directory.
4. The extension appears in the toolbar. Click it to test the popup.

When you edit files, click the refresh icon in `chrome://extensions` for that extension. Content scripts also require reloading the affected page.

There's no HMR. That's the cost of not using a framework — and the reason WXT exists.

## Production

1. Add 16/32/48/128 PNG icons to `icons/`.
2. Update `manifest.json` with real `name`, `description`, `version`.
3. Update `_locales/en/messages.json`.
4. Zip the directory: `cd /this/dir && zip -r ../extension.zip . -x "*.zip"`.
5. Upload via the Chrome Web Store dashboard.

## Add a feature

The content script's `matches` is set to `https://example.com/*` for the smoke test sentinel. Change to your target site(s):

```json
"content_scripts": [
  {
    "matches": ["*://github.com/*"],
    "js": ["content.js"],
    "run_at": "document_idle"
  }
]
```

For more complex extensions, organize into folders:

```
src/
├── background/
│   └── index.js
├── content/
│   └── index.js
└── popup/
    ├── index.html
    └── main.js
```

Update `manifest.json` paths accordingly.

## Caveats

- No HMR. Every change requires reload.
- No TypeScript. Add a build step if you want it.
- No multi-browser. Manifest differences (Firefox `browser_specific_settings`) must be hand-managed.

When any of these become painful, migrate to WXT.

---

_Scaffolded with [Chrome Extension Builder](https://github.com/harry-harish/chrome-extension-builder), a Claude Code plugin. This line is safe to remove._
