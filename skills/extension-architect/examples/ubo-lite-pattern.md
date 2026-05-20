# uBlock Origin Lite pattern — optional permissions + declarativeNetRequest

## Source

`gorhill/uBlock` in `platform/mv3/`. The "Lite" Chrome version of uBlock Origin, written specifically for MV3 constraints. Vanilla JavaScript, no framework.

## What to copy

uBlock Origin Lite (uBOL) is the canonical example of **building a permissions-free extension that escalates only on user request**, and of **moving complexity from runtime to build time**.

## 1. Tiered/optional permissions

uBOL ships in three permission modes, all selectable by the user:

| Mode | Permissions | Capability |
|---|---|---|
| **No permissions** | `declarativeNetRequest`, `storage` (no host permissions) | Static filter lists only; can't see what's on any page |
| **Per-site permission** | adds `chrome.permissions.request({ origins })` for specific sites | Can apply site-specific cosmetic filtering on opted-in sites |
| **All-sites permission** | adds `<all_urls>` | Full per-page filtering on every site |

The manifest:

```json
{
  "permissions": ["declarativeNetRequest", "storage", "scripting"],
  "host_permissions": [],
  "optional_host_permissions": ["<all_urls>"]
}
```

And in code:

```ts
async function upgradeToAllSites(): Promise<boolean> {
  const granted = await chrome.permissions.request({
    origins: ['<all_urls>']
  });
  if (granted) {
    await chrome.storage.local.set({ mode: 'all-sites' });
  }
  return granted;
}

async function upgradeToSite(origin: string): Promise<boolean> {
  return chrome.permissions.request({ origins: [origin] });
}
```

Users see:

- **Install**: "This extension wants to: communicate with cooperating websites." (essentially zero-warning install.)
- **Upgrade**: a runtime dialog the user sees when they click "enable filtering on this site."

This is enormously powerful. uBOL passes Chrome Web Store review without the broad-permissions friction that the full uBlock Origin (which requires `webRequest`) cannot pass on Chrome MV3.

## 2. declarativeNetRequest at build time

MV3's `chrome.webRequest` lost its blocking capability. uBOL replaces it with `declarativeNetRequest` (DNR), which works by static rules compiled at extension build time.

```
platform/mv3/
├── make-rulesets.js          # Node script: EasyList → DNR JSON
├── rulesets/
│   ├── main/                 # compiled DNR rules (built artifact)
│   │   ├── default.json
│   │   ├── ublock-filters.json
│   │   └── ...
│   └── ...
└── manifest.json             # references rule_resources
```

The manifest:

```json
{
  "declarative_net_request": {
    "rule_resources": [
      {
        "id": "default",
        "enabled": true,
        "path": "rulesets/main/default.json"
      },
      {
        "id": "easyprivacy",
        "enabled": false,
        "path": "rulesets/main/easyprivacy.json"
      }
    ]
  }
}
```

Per Chrome's docs, the DNR limits are: "a 300,000-rule shared pool plus a 30,000-rule guaranteed allowance per extension, meaning a single installed content-filtering extension can reach 330,000 static DNR rules."

uBOL's build pipeline parses EasyList syntax and emits JSON rules:

```js
// platform/mv3/make-rulesets.js (paraphrased)
import easylistParse from './easylist-parser';
import fs from 'fs';

const easylistRules = easylistParse(fs.readFileSync('lists/easylist.txt', 'utf8'));
const dnrRules = easylistRules.map((r, i) => ({
  id: i + 1,
  priority: 1,
  action: { type: r.allow ? 'allow' : 'block' },
  condition: r.toDnrCondition(),
}));
fs.writeFileSync('rulesets/main/default.json', JSON.stringify(dnrRules));
```

Runtime code is minimal — DNR enforces the rules at network layer; the extension just toggles rulesets on/off.

## 3. Storage tier choice

uBOL uses:

- `chrome.storage.session` for ephemeral state ("rulesets compiled this session," "pending fetch results")
- `chrome.storage.local` for persisted state (selected rulesets, user customizations)

This is the textbook MV3 storage pattern — load `references/storage-tiers.md` for the full guide.

## Adaptation for your extension

### If you're building a content blocker / filter

Copy uBOL's full pattern: tiered permissions, DNR rulesets compiled at build time, minimal runtime. Read `platform/mv3/make-rulesets.js` directly.

### If you're not building a content blocker but want low-friction install

Adopt the "no host permissions by default; opt up when needed" pattern:

```json
{
  "permissions": ["storage", "activeTab"],
  "host_permissions": [],
  "optional_host_permissions": ["*://*.specific.com/*", "<all_urls>"]
}
```

Build an onboarding flow:

1. First run shows "Want filtering on github.com? [Enable]"
2. The button calls `chrome.permissions.request({ origins: ['*://github.com/*'] })`
3. On grant, your background SW registers the relevant content script via `chrome.scripting.registerContentScripts`:

```ts
await chrome.scripting.registerContentScripts([{
  id: 'github-feature',
  matches: ['*://github.com/*'],
  js: ['features/github.js'],
  runAt: 'document_idle',
}]);
```

This is opposite the usual "declare content_scripts statically in manifest" approach — you register dynamically only after the user grants permission.

### Listen for permission changes

Users can revoke permissions in `chrome://extensions`. Handle it:

```ts
chrome.permissions.onRemoved.addListener(async (changes) => {
  for (const origin of changes.origins ?? []) {
    await chrome.scripting.unregisterContentScripts({ ids: [`feature-${origin}`] });
  }
});

chrome.permissions.onAdded.addListener(async (changes) => {
  // ... register scripts for newly-granted origins
});
```

## What not to copy

- **uBOL's vanilla-JS no-framework approach**: it works for them because they have years of engineering investment in raw DOM. For a new project, WXT + React is a saner default unless you specifically need the tiny bundle size.
- **uBOL's filter-list compilation pipeline**: domain-specific to content filtering. Don't try to compile filter lists if your extension doesn't block ads.

## Why this pattern matters

Most extensions ask for too much at install time, get rejected by skeptical users, and never get installed. uBOL's tiered model shows you can ship a high-power extension that **starts with zero permissions** and only asks for what the user explicitly opts into.

This is also the design Chrome's review process rewards: the lower your default permissions, the faster and friendlier review goes.
