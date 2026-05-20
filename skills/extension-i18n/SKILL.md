---
name: extension-i18n
description: Use when adding internationalization to a Chrome extension via `_locales/{locale}/messages.json` and `chrome.i18n.getMessage()`. Load when scaffolding a new extension (add from day one), adding translations, integrating Crowdin/Weblate, or migrating user-visible strings out of code.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
license: Apache-2.0
---

# Extension i18n

Every reference extension in 2026 ships `_locales/` — Refined GitHub, Privacy Badger, Bitwarden, Vimium C. **Add it from day one** because retrofitting i18n into a working extension is painful.

## Layout

```
<project>/
├── public/                       (WXT/Plasmo) or src/ (CRXJS)
│   └── _locales/
│       ├── en/
│       │   └── messages.json     # canonical
│       ├── es/
│       │   └── messages.json
│       └── ...
└── manifest.json
    "default_locale": "en"
```

`default_locale` in the manifest tells Chrome which folder to fall back to.

## messages.json format

```json
{
  "extension_name": {
    "message": "My Extension",
    "description": "Shown in toolbar tooltip and CWS listing"
  },
  "extension_description": {
    "message": "Highlights pull requests on GitHub.",
    "description": "Short description (≤132 chars for CWS)"
  },
  "action_title": {
    "message": "Open $APP_NAME$ options",
    "description": "Tooltip on toolbar icon",
    "placeholders": {
      "app_name": {
        "content": "My Extension",
        "example": "My Extension"
      }
    }
  }
}
```

Each entry: `message` is required, `description` is for translators (highly recommended), `placeholders` for variable interpolation.

## Manifest references

Use `__MSG_<key>__` in any user-visible manifest field:

```json
{
  "name": "__MSG_extension_name__",
  "description": "__MSG_extension_description__",
  "default_locale": "en",
  "action": {
    "default_title": "__MSG_action_title__"
  }
}
```

Chrome resolves these at install time per the user's locale.

## In code

```ts
const name = chrome.i18n.getMessage('extension_name');
const title = chrome.i18n.getMessage('action_title');
```

For React/Vue/Svelte components:

```tsx
// src/lib/i18n.ts
export const t = (key: string, substitutions?: string[] | string) =>
  chrome.i18n.getMessage(key, substitutions);
```

```tsx
// In a component
<h1>{t('extension_name')}</h1>
```

## In HTML

`chrome.i18n` doesn't auto-process HTML. Use a small `i18n.ts` that walks the DOM on load:

```ts
// public/i18n-replace.ts
document.querySelectorAll('[data-i18n]').forEach(el => {
  const key = el.getAttribute('data-i18n')!;
  el.textContent = chrome.i18n.getMessage(key);
});
```

Or use `i18n-helper` libraries.

## Translation workflows

### Crowdin

The most popular for browser extensions (used by Bitwarden, Vimium C). Connect the repo's `_locales/` directory; translators edit `messages.json` per locale; Crowdin syncs back via PR.

`crowdin.yml`:

```yaml
project_id: "12345"
api_token_env: CROWDIN_TOKEN
preserve_hierarchy: true
files:
  - source: /public/_locales/en/messages.json
    translation: /public/_locales/%two_letters_code%/messages.json
```

### Weblate

Used by Privacy Badger (EFF). Open-source, self-hostable, good for orgs that prefer GPL infrastructure.

### GitHub-based

For small projects: keep `_locales/` in the repo and accept translation PRs. Add a `CONTRIBUTING.md#translations` section that links to a starter template.

## RTL languages

Languages like Arabic and Hebrew need RTL handling. Add to your CSS:

```css
[dir="rtl"] .popup {
  direction: rtl;
  text-align: right;
}
```

And in your popup/options HTML:

```html
<html dir="ltr" data-locale-detect>
```

Detect:

```ts
const ui = chrome.i18n.getUILanguage();
document.documentElement.dir = ['ar', 'he', 'fa', 'ur'].includes(ui.split('-')[0]) ? 'rtl' : 'ltr';
```

## Pluralization

`chrome.i18n` does NOT support ICU MessageFormat plurals. For plurals, ship multiple keys:

```json
{
  "items_zero": { "message": "No items" },
  "items_one":  { "message": "1 item" },
  "items_many": { "message": "$COUNT$ items", "placeholders": { "count": { "content": "$1" } } }
}
```

And select in code:

```ts
const items = (n: number) => {
  if (n === 0) return t('items_zero');
  if (n === 1) return t('items_one');
  return t('items_many', [String(n)]);
};
```

Or adopt a real i18n library (FormatJS, i18next) — but only if the extension has substantial user-visible text. For most extensions, `chrome.i18n` is fine.

## CI checks

Lint that:

1. Every key in `en/messages.json` has a `description`.
2. No code references a missing key (grep `getMessage\(['"]([^'"]+)` vs keys in messages.json).
3. Every locale has the same key set as `en/`.

`scripts/check-i18n.sh` (bundled with this skill) does this.

## Things not to do

- ❌ Hardcode user-visible strings in TSX/HTML — even just for the popup.
- ❌ Forget `description` fields. Translators need them.
- ❌ Skip i18n because "we're only shipping English." Adding it later is multi-day work.
- ❌ Use `<i18n>foo</i18n>` custom tags — `chrome.i18n` doesn't process them.
- ❌ Hardcode RTL/LTR; detect at runtime.
