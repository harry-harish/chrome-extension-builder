---
description: Audit a Manifest V2 extension and produce an MV3 migration plan with concrete patches.
argument-hint: "[optional path to MV2 extension root]"
---

# /chrome-ext:migrate-mv2 — Audit and migrate from MV2 to MV3

Audit the MV2 extension in `$ARGUMENTS` (or cwd) and produce an MV3 migration plan. Optionally apply the patches if the user authorizes.

**Context**: MV2 was removed from consumer Chrome (Chrome 139, 2025-07-24). Any MV2 extension is no longer installable on current Chrome. Firefox is mid-deprecation as of mid-2026 (current ESR still loads MV2 add-ons, but Firefox release channels are pushing MV3 hard and AMO listings increasingly require MV3 for new submissions). Plan to migrate even if your only target today is Firefox — the runway is short.

## Procedure

### 1. Read `manifest.json` and inventory MV2-isms

Look for and catalog:

- `manifest_version: 2`
- `background.scripts: [...]` (must become `background.service_worker`)
- `background.persistent: true` (must be removed; SWs are ephemeral)
- `browser_action` (must become `action`)
- `page_action` (must become `action` with conditional display via `chrome.action.disable/enable`)
- `chrome.tabs.executeScript(...)` calls (must become `chrome.scripting.executeScript`)
- `chrome.tabs.insertCSS(...)` calls (must become `chrome.scripting.insertCSS`)
- `chrome.extension.getBackgroundPage()` (cannot work on SW; refactor to message passing)
- `chrome.webRequest.onBeforeRequest` with blocking semantics (must become `declarativeNetRequest` rulesets)
- `content_security_policy: "..."` as string (must become object with `extension_pages` and `sandbox` keys)
- `web_accessible_resources` as array of strings (must become array of `{resources, matches}` objects)
- `optional_permissions` includes `<all_urls>` (must move to `optional_host_permissions`)

Grep the source for runtime API calls that changed:

```bash
grep -rn 'chrome\.tabs\.executeScript\|chrome\.tabs\.insertCSS\|chrome\.extension\.getBackgroundPage\|chrome\.runtime\.onMessageExternal' src/ 2>/dev/null
```

### 2. Produce the migration plan

Output a structured plan:

```
MV2 → MV3 migration plan for <project>

Manifest changes:
  manifest.json
  - manifest_version: 2 → 3
  - background.scripts → background.service_worker (combine into one entry file)
  - browser_action → action
  - content_security_policy → { extension_pages: "..." }
  - web_accessible_resources → [{resources: [...], matches: [...]}]

Code changes (N call sites):
  src/background.js:42 — chrome.tabs.executeScript → chrome.scripting.executeScript
  src/popup.js:18 — chrome.extension.getBackgroundPage → chrome.runtime.sendMessage
  ...

Architecture changes:
  - Background page is now an ephemeral service worker. Replace any in-memory caches with chrome.storage.session (MV3).
  - chrome.webRequest blocking handlers → declarativeNetRequest static rulesets. (M existing handlers to convert.)
  - <all_urls> host permissions are showing 'this extension can read all your data on all websites' warning. Consider chrome.activeTab + chrome.scripting.executeScript on user invocation.

Estimated effort: <Small (<1 day) | Medium (1-5 days) | Large (1+ weeks)>
Risk areas: <list of patterns that need manual review>
```

### 3. Apply patches (with confirmation)

For each change in the plan, ask the user whether to apply. Apply only what they authorize.

For the `webRequest → declarativeNetRequest` conversion specifically, **do not auto-convert** unless the rules are trivial. Output a manual conversion guide referencing `skills/extension-security/references/dnr-conversion.md` instead.

### 4. Validate

After patches, run `/chrome-ext:validate` on the migrated extension. Iterate until clean.

### 5. Test

Dispatch `extension-test-runner` to verify the migrated extension still loads and the core flows work. Provide a manual test checklist if Playwright tests don't exist yet.

## Reference

- Chrome MV2 deprecation timeline: https://developer.chrome.com/docs/extensions/develop/migrate/mv2-deprecation-timeline
- Official migration guide: https://developer.chrome.com/docs/extensions/develop/migrate
- Local detailed reference: `skills/extension-architect/references/mv2-to-mv3-migration.md`
