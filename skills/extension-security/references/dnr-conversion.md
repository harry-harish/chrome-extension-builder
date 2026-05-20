# Converting webRequest blocking → declarativeNetRequest

## Why this matters

`chrome.webRequest.onBeforeRequest(..., ['blocking'])` was MV2's mechanism for blocking network requests at runtime. **It's gone in MV3 for non-enterprise extensions.** You can still observe requests (without `blocking`), but you cannot synchronously block them.

For ad blockers, tracker blockers, malware filters, and any extension that needs to intercept network requests, the replacement is `declarativeNetRequest` (DNR).

## The trade-off

| | webRequest (MV2) | declarativeNetRequest (MV3) |
|---|---|---|
| Block requests | ✅ at runtime, any logic | ✅ only via predefined rules |
| Modify headers | ✅ at runtime | ✅ static or dynamic rules |
| Redirect | ✅ at runtime | ✅ with restrictions |
| Per-request callbacks | ✅ | ❌ (rules are declarative) |
| Sees actual URL contents | ✅ | partial (matched URL only) |
| Number of rules | unlimited (memory permitting) | 300k shared / 30k guaranteed per extension |

The big loss: you can't run JS for each request decision. The big win: it's massively faster (rules are matched in C++ at network layer, not by your JS).

## Rule structure

DNR rules look like:

```json
{
  "id": 1,
  "priority": 1,
  "action": { "type": "block" },
  "condition": {
    "urlFilter": "||doubleclick.net^",
    "resourceTypes": ["script", "sub_frame"]
  }
}
```

- `id` (required) — unique per rule.
- `priority` (default 1) — higher priority wins on conflicts.
- `action.type` — `block`, `allow`, `redirect`, `upgradeScheme`, `modifyHeaders`, `allowAllRequests`.
- `condition.urlFilter` — a pattern matching the URL. Uses uBlock-style syntax (`||domain^`, wildcards, etc.).
- `condition.resourceTypes` — `script`, `image`, `stylesheet`, `xmlhttprequest`, `media`, `font`, `sub_frame`, `main_frame`, `csp_report`, `object`, `other`, `websocket`.

Full `urlFilter` syntax: see `developer.chrome.com/docs/extensions/reference/api/declarativeNetRequest#property-RuleCondition-urlFilter`.

## Three rule sources

### 1. Static rules (compiled at extension build time)

Best for ship-with-extension blocklists. Declared in manifest:

```json
{
  "permissions": ["declarativeNetRequest"],
  "declarative_net_request": {
    "rule_resources": [
      {
        "id": "default",
        "enabled": true,
        "path": "rules/default.json"
      },
      {
        "id": "tracking",
        "enabled": false,
        "path": "rules/tracking.json"
      }
    ]
  }
}
```

Toggle at runtime:

```ts
await chrome.declarativeNetRequest.updateEnabledRulesets({
  enableRulesetIds: ['tracking'],
  disableRulesetIds: ['default'],
});
```

### 2. Dynamic rules (set by your code)

For user-customizable blocking:

```ts
await chrome.declarativeNetRequest.updateDynamicRules({
  addRules: [{
    id: 1000,
    priority: 1,
    action: { type: 'block' },
    condition: { urlFilter: '||evil.com^', resourceTypes: ['script'] },
  }],
  removeRuleIds: [999],
});
```

Limited to a smaller quota (typically 5k dynamic rules).

### 3. Session rules (cleared on browser restart)

Same API as dynamic, but `updateSessionRules`. Useful for "block this for the current session only."

## Conversion from webRequest

### Pattern A: block ad domains

MV2:

```ts
chrome.webRequest.onBeforeRequest.addListener(
  (details) => {
    if (details.url.includes('doubleclick.net')) return { cancel: true };
    return {};
  },
  { urls: ['<all_urls>'] },
  ['blocking'],
);
```

MV3 DNR:

```json
[{
  "id": 1,
  "action": { "type": "block" },
  "condition": { "urlFilter": "||doubleclick.net^" }
}]
```

### Pattern B: add headers

MV2:

```ts
chrome.webRequest.onBeforeSendHeaders.addListener(
  (details) => {
    details.requestHeaders!.push({ name: 'X-Custom', value: 'foo' });
    return { requestHeaders: details.requestHeaders };
  },
  { urls: ['https://api.example.com/*'] },
  ['blocking', 'requestHeaders'],
);
```

MV3 DNR:

```json
[{
  "id": 2,
  "action": {
    "type": "modifyHeaders",
    "requestHeaders": [{ "header": "X-Custom", "operation": "set", "value": "foo" }]
  },
  "condition": { "urlFilter": "*", "domains": ["api.example.com"] }
}]
```

### Pattern C: redirect

MV2:

```ts
chrome.webRequest.onBeforeRequest.addListener(
  () => ({ redirectUrl: 'https://my-cdn.com/blocked.png' }),
  { urls: ['*://*.evil.com/*'] },
  ['blocking'],
);
```

MV3 DNR:

```json
[{
  "id": 3,
  "action": {
    "type": "redirect",
    "redirect": { "url": "https://my-cdn.com/blocked.png" }
  },
  "condition": { "urlFilter": "||evil.com^" }
}]
```

Or redirect to an extension-bundled resource:

```json
[{
  "id": 4,
  "action": {
    "type": "redirect",
    "redirect": { "extensionPath": "/assets/blocked.png" }
  },
  "condition": { "urlFilter": "||evil.com^" }
}]
```

The file must be in `web_accessible_resources`.

## Compiling filter lists (uBO Lite pattern)

uBO Lite parses EasyList syntax and emits DNR rules at build time:

```ts
// build/compile-rules.ts
import easylist from 'easylist-parser';
import fs from 'fs';

const text = fs.readFileSync('lists/easylist.txt', 'utf8');
const rules = easylist.parse(text);

const dnr = rules.map((r, i) => ({
  id: i + 1,
  priority: 1,
  action: { type: r.allow ? 'allow' : 'block' },
  condition: {
    urlFilter: r.toUrlFilter(),
    resourceTypes: r.resourceTypes(),
    initiatorDomains: r.initiatorDomains(),
    excludedInitiatorDomains: r.excludedInitiatorDomains(),
  },
}));

fs.writeFileSync('rules/default.json', JSON.stringify(dnr));
```

Then the manifest references `rules/default.json`. The runtime is just a toggle.

This is also where uBO Lite's tiered permissions live: rules that only match user-opted sites are in a separate ruleset, enabled only after `chrome.permissions.request`.

## Things webRequest could do but DNR cannot

- **Dynamic logic per request.** "If the URL is suspicious *and* the user is in incognito, block." DNR can't combine those.
- **Reading the response body.** DNR sees only URL/headers, never body.
- **Modifying request body.** Not supported.
- **Inspecting after the fact.** `webRequest.onCompleted` still works (without `blocking`), but can't unblock or unredirect.

For these cases, you either drop the feature, work around with a content script that intercepts at the JS layer, or accept the DNR limitations.

## Tools

- **`declarativeNetRequest` debug**: `chrome://extensions/?errors=<extension-id>` shows rule errors.
- **`chrome.declarativeNetRequest.testMatchOutcome`** — programmatically test a rule against a sample URL.
- **`chrome.declarativeNetRequest.getMatchedRules`** — see which rules matched recent requests (useful for diagnostics).

## Migration playbook for an ad blocker

1. Export your current MV2 rules (typically in a JSON or EasyList file).
2. Write a build-time compiler from your rule format → DNR JSON.
3. Split into rulesets: default-on (lightweight) + opt-in (heavier).
4. Decide which `host_permissions` you need vs which can move to `optional_host_permissions`.
5. Replace `chrome.webRequest.*` handlers with `chrome.declarativeNetRequest.updateDynamicRules` for user-added rules.
6. Test that totals stay under the per-extension limit (start with 30k, raise if needed).
7. Validate via `addons-linter` / `web-ext lint`.

## Don't try

- Don't reintroduce `webRequest` blocking via the enterprise `ExtensionManifestV2Availability` policy — it expired June 2025.
- Don't expect the same flexibility. DNR is a declarative system, by design.
