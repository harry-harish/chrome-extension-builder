# Permissions — minimize, declare, justify

## The principle

Every permission shows up as an install-time prompt or runtime warning. Users uninstall extensions that ask for too much. Every permission is also a CWS review trigger. **Minimize.**

## Tiers (the uBO Lite model)

uBlock Origin Lite is the canonical example of tiered, optional permissions. It ships in three modes:

1. **No-permissions mode** — only static filter rules; no site-specific blocking.
2. **Per-site permission** — user opts in to specific sites; uses `chrome.permissions.request({ origins })`.
3. **All-sites permission** — user explicitly grants `<all_urls>` after understanding the trade-off.

Most users stay in mode 1 or 2. The extension is fully functional in each mode.

## activeTab — the most underused permission

`activeTab` grants a temporary host permission for the current tab in response to a user invocation (clicking the toolbar icon, using a keyboard shortcut, selecting from a context menu).

```json
{
  "permissions": ["activeTab"]
}
```

Per Chrome's docs: *"activeTab grants an extension temporary host permission for the current tab in response to a user invocation … activeTab does not trigger any warnings."*

When the user clicks your action, you can:

```ts
chrome.action.onClicked.addListener(async (tab) => {
  await chrome.scripting.executeScript({
    target: { tabId: tab.id! },
    func: () => {
      document.body.style.background = 'red';
    },
  });
});
```

No `host_permissions`, no `<all_urls>`, no scary install prompt.

Use this when:
- Your extension acts on demand (user clicks the icon).
- You don't need to observe every page passively.

Don't use this when:
- You need to inject on every page automatically (e.g., an ad blocker).
- You need `chrome.tabs.onUpdated` to fire for every navigation.

## Optional permissions

For capabilities users opt into:

```json
{
  "permissions": ["storage"],
  "optional_permissions": ["notifications", "clipboardRead"],
  "optional_host_permissions": ["*://*/*"]
}
```

Request at runtime:

```ts
const granted = await chrome.permissions.request({
  permissions: ['notifications'],
  origins: ['https://example.com/*'],
});
if (granted) {
  // ... use the capability
}
```

The user sees a runtime dialog. They can deny without uninstalling.

## Permissions that trigger CWS manual review

These get extra scrutiny:

| Permission | Why scrutinized |
|---|---|
| `<all_urls>` host permission | Sees every page |
| `tabs` | Tab metadata for every tab |
| `history` | Browsing history |
| `cookies` | Cookies on declared origins |
| `webRequest` | Sees every HTTP request |
| `nativeMessaging` | Communicates with native apps |
| `debugger` | Attaches to the page's debugger |
| `management` | Manages other extensions |
| `privacy` | Reads/changes browser privacy settings |

Justify each in your CWS listing. "Single-purpose statement says we filter every page → `<all_urls>` is necessary."

## Permissions that don't show warnings

Generally low-friction:

- `storage`
- `activeTab`
- `alarms`
- `notifications` (only the runtime "show notifications?" dialog)
- `contextMenus`
- `clipboardWrite`
- `unlimitedStorage` (no install warning, but flags CWS review)

## Permissions removed in MV3

- `webRequestBlocking` — replaced by `declarativeNetRequest` (with much lower rule limits)
- `background` (the `persistent: true` flag) — SWs are always ephemeral

If you grep your code and find these, run `/chrome-ext:migrate-mv2`.

## host_permissions decision tree

```
Do you need to act on every page passively (without user clicking)?
├─ Yes → host_permissions
│  ├─ All sites?
│  │  ├─ Yes, and you can justify single-purpose → host_permissions: ["<all_urls>"]
│  │  └─ No, just a few → host_permissions: ["*://*.example.com/*"]
│  └─ Specific sites only → host_permissions: ["*://*.specific.com/*"]
└─ No → use activeTab + chrome.scripting on user invocation
```

Then ask: can you make the broad case **optional**?

```json
{
  "host_permissions": [],
  "optional_host_permissions": ["<all_urls>"]
}
```

And add an onboarding flow that requests broad permission only when the user enables the feature that needs it.

## Common patterns

### Pattern 1: "click to activate" extension

```json
{
  "permissions": ["activeTab", "scripting"]
}
```

Zero host permissions. User clicks action → you inject the content script.

### Pattern 2: "always on, specific sites"

```json
{
  "permissions": ["storage"],
  "host_permissions": ["*://*.github.com/*"]
}
```

Refined GitHub's model: narrow host permission, no `<all_urls>`.

### Pattern 3: "tiered with opt-in"

```json
{
  "permissions": ["storage", "declarativeNetRequest"],
  "host_permissions": [],
  "optional_host_permissions": ["<all_urls>"]
}
```

uBO Lite's model: works with zero permissions; opts up only on user demand.

### Pattern 4: "needs notifications, but only sometimes"

```json
{
  "permissions": ["storage"],
  "optional_permissions": ["notifications"]
}
```

Request at runtime when the user enables notifications in settings.

## Lint your manifest

The `validate-permissions.py` script in this plugin flags:

- `<all_urls>` in `host_permissions` (suggests `optional_host_permissions`)
- `webRequestBlocking` (removed in MV3)
- `tabs` + `activeTab` together (redundant)
- Non-core perms missing from `optional_permissions`

Run it via `/chrome-ext:validate` or the auto-hook on manifest edits.

## CWS justification template

For each "scary" permission in your CWS listing, write:

```
<permission>: <one-sentence reason that ties to single-purpose statement>
```

Examples:

- `<all_urls>`: Required to highlight matching prices on every shopping site — the extension's single purpose.
- `tabs`: Required to display a per-tab counter in the toolbar showing items blocked.
- `webRequest`: Required to inspect ad URLs for blocking decisions (the single purpose is ad-blocking).

Vague or formulaic justifications get rejected. Specific ones tied to single-purpose pass.
