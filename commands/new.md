---
description: Scaffold a new production-ready Chrome (MV3) extension. 8-phase guided workflow — discovery, framework selection, scaffold, implement, validate, test, docs.
argument-hint: "[optional one-line description of the extension]"
---

# /chrome-ext:new — Build a new Chrome extension end-to-end

You are the orchestrator for a production-grade Chrome Manifest V3 extension build. Run the 8-phase workflow below. Hard user gates are marked **CRITICAL: DO NOT SKIP** — wait for explicit user confirmation at those phases.

The user may have provided a brief: `$ARGUMENTS`.

## Setup

Load the `extension-architect` skill for orientation, but do not load framework skills (`wxt-framework`, `plasmo-framework`, `crxjs-vite`) yet — pick one in Phase 3 and load only that.

Read user defaults from the plugin's `userConfig` (set by the user during `/plugin install` or via `/plugin config chrome-extension-builder`):

- `default_framework` — `wxt` | `plasmo` | `crxjs` | `vanilla`. Default `wxt`.
- `default_ui_framework` — `react` | `vue` | `svelte` | `solid` | `vanilla`. Default `react`.
- `target_browsers` — comma-separated. Default `chrome,edge,firefox`.
- `typescript` — bool. Default `true`.
- `package_manager` — `pnpm` | `npm` | `yarn` | `bun`. Default `pnpm`.

Use these as starting points; the user can override in Phase 1 / Phase 3.

Run the doctor probe to confirm runtime requirements before Phase 1, using the configured package manager:

```bash
node -v
command -v ${PM:-pnpm} 2>/dev/null && ${PM:-pnpm} --version
python3 -c "import sys; print(sys.version)"
```

Substitute `${PM}` with the value from `userConfig.package_manager` (or `pnpm` if unset). If the configured PM is not installed, ask the user whether to switch or install it. Report any missing requirements but do not block on Playwright/Chromium — those are only needed in Phase 7.

---

## Phase 1 — Discovery

Ask the user **one consolidated question** that gathers all of this in a single round trip:

1. **What does the extension do?** (1–2 sentence elevator pitch — the single-purpose statement Chrome Web Store requires.)
2. **Target browsers?** (Chrome, Edge, Firefox, Safari — defaults to chrome+edge+firefox.)
3. **Auth/storage needs?** (None / `chrome.storage.local` only / `chrome.storage.sync` / encrypted vault / OAuth / Web3 wallet.)
4. **Surfaces?** (popup / options page / side panel / new-tab override / content scripts / devtools panel / background-only.)
5. **Any host-permission needs?** (Site-specific, all sites, activeTab-only.)

Use AskUserQuestion if available, otherwise ask in plain prose.

If the user already specified some answers in `$ARGUMENTS`, fill those in and only ask for the missing ones. Pre-fill defaults from `userConfig`:
- Target browsers default to `userConfig.target_browsers`.
- UI framework default is `userConfig.default_ui_framework`.
- Package manager default is `userConfig.package_manager`.

The user can always override.

---

## Phase 2 — Reference analysis

Based on the discovery answers, identify which reference patterns from the `skills/extension-architect/examples/` and `skills/extension-security/examples/` directories apply. Examples:

- DOM injection / GitHub-style content scripts → load `examples/refined-github-pattern.md`
- Theme/style manipulation → load `examples/dark-reader-pattern.md`
- Vault, crypto, or shared cross-client code → load `examples/bitwarden-pattern.md`
- Web3 wallet, in-page provider, or sensitive deps → load `examples/metamask-pattern.md`
- Network filtering or DNR rules → load `examples/ubo-lite-pattern.md`
- Userscript host or in-page injection → load `examples/violentmonkey-pattern.md`
- Crowdsourced data with backend → load `examples/sponsorblock-pattern.md`

Summarize the chosen patterns in 3–5 bullets so the user can see what architectural decisions you're inheriting.

---

## Phase 3 — Architecture decision **CRITICAL: DO NOT SKIP**

Pick the framework. Defaults from `userConfig.default_framework`:

| Framework | When to pick |
|---|---|
| **WXT** (default) | Almost always. Active maintenance, MV3-only, multi-browser (Chrome+Edge+Firefox+Safari), 400 KB typical bundle, file-based entrypoints, best-in-class HMR. |
| Plasmo | Only if you have an existing Plasmo project or specifically need its CSUI (content-script-UI in Shadow DOM) system. Note: per WXT's official comparison, Plasmo "appears to be in maintenance mode." |
| CRXJS | Only if you're converting an existing Vite + React app into an extension. Chromium-only; slowed release cadence. |
| Vanilla | Only for tiny extensions (<1k LOC) or maximum learning. No HMR, no auto-manifest, no cross-browser. |

Present the recommendation and the trade-offs in a short table. Then ask:

> "Confirm framework choice: **WXT** (recommended), Plasmo, CRXJS, or vanilla?"

**WAIT for the user's confirmation before proceeding.** Do not scaffold until they answer.

After confirmation, load **exactly one** framework skill: `wxt-framework`, `plasmo-framework`, `crxjs-vite`, or `extension-architect`'s vanilla section.

---

## Phase 4 — Scaffold

Run the scaffolding script from the chosen framework skill. Use the package manager from `userConfig.package_manager` (default `pnpm`); the snippets below show `pnpm` but substitute the configured one.

Pick the WXT template name from `userConfig.default_ui_framework` (default `react`). If `userConfig.typescript` is `true` (the default — and the locked-in plugin default), append `-ts`. So the standard case is `react-ts`; the matrix:

| `default_ui_framework` | `typescript: true` (default) | `typescript: false` |
|---|---|---|
| `react` | `react-ts` | `react` |
| `vue` | `vue-ts` | `vue` |
| `svelte` | `svelte-ts` | `svelte` |
| `solid` | `solid-ts` | `solid` |
| `vanilla` | `vanilla` (TS-aware) | `vanilla` |

For WXT (default):

```bash
# WXT init is interactive: it prompts for template and package manager.
# Use --template to pre-select (skips that prompt); the package-manager
# prompt is answered by whichever PM is active when invoking via dlx.
#
# Run from the parent dir; WXT creates <project-name>/.
# Pinned to ~0.20.26 (minimum tested) — 0.20.x moved the defineBackground /
# defineContentScript exports, so a floating @latest can break the scaffold.
${PM} dlx wxt@~0.20.26 init <project-name> --template react-ts
cd <project-name>
${PM} install
```

If `react-ts` errors on an older WXT release that doesn't ship that template name, fall back to `--template react` — the React template ships TypeScript regardless in current WXT versions. Verify by `grep '"typescript"' package.json` after init.

For **fully non-interactive** scaffolding (CI, headless agent runs), use the bundled helper, which writes the WXT project files (TypeScript by default) directly:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/wxt-framework/scripts/scaffold-wxt.sh" <project-name> ${UI_FRAMEWORK:-react} ${PM:-pnpm}
```

For Plasmo (only for an existing Plasmo project or when CSUI is specifically
needed — otherwise steer the user to WXT):

```bash
${PM} create plasmo <project-name>
cd <project-name>
# Upstream create-plasmo (0.90.x) pins "plasmo": "workspace:*", which breaks the
# next install with ERR_PNPM_WORKSPACE_PKG_NOT_FOUND. Repin to a real version
# first. (Skip if package.json already shows a normal "plasmo": "^x.y.z".)
${PM} pkg set dependencies.plasmo=latest
${PM} install
```

For CRXJS, follow `skills/crxjs-vite/SKILL.md`. For vanilla, copy the template under `skills/extension-architect/templates/vanilla/` and run `${PM} init -y` if you want a `package.json`.

After scaffolding:
1. Verify the directory was created and has a `package.json`.
2. Add `_locales/en/messages.json` with extension `name`, `short_name`, `description` placeholders.
3. Commit the initial scaffold with `git init && git add . && git commit -m "chore: initial scaffold"` (only if the user is in a git repo or just initialized one).

---

## Phase 5 — Implement

Generate entrypoints based on Phase 1 surfaces. For each surface chosen, write code that follows the security patterns from the loaded reference examples:

- **Background service worker** — a dispatcher that receives typed messages and delegates to controllers, never a doer. (See `skills/extension-security/references/message-passing.md`.)
- **Content scripts** — feature-module pattern; lazy init based on URL detection; minimal lifetime. (See `skills/extension-architect/examples/refined-github-pattern.md`.)
- **Popup / options / side panel** — React + TypeScript + Tailwind by default. Use `chrome.storage.sync` for prefs, `chrome.storage.local` for state, `chrome.storage.session` for ephemeral cache.
- **DevTools panel** — Use the secure injected-page-script pattern from `skills/extension-security/references/devtools-injection.md`.

Write a typed `messages.ts` (or `types/messages.d.ts`) defining all message shapes — never use stringly-typed `chrome.runtime.sendMessage`.

Apply CSP hardening from `skills/extension-security/references/csp-hardening.md`: no `unsafe-eval`, no `unsafe-inline`, all scripts shipped locally.

---

## Phase 6 — Validate **CRITICAL: DO NOT SKIP**

Dispatch the `manifest-auditor` subagent with read-only tools to run:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/skills/extension-architect/scripts/validate-manifest.py <project>/manifest.json
python3 ${CLAUDE_PLUGIN_ROOT}/skills/extension-security/scripts/validate-permissions.py <project>/manifest.json
bash ${CLAUDE_PLUGIN_ROOT}/skills/extension-security/scripts/validate-csp.sh <project>/manifest.json
bash ${CLAUDE_PLUGIN_ROOT}/skills/extension-testing/scripts/lint-extension.sh <project>
```

(For WXT/Plasmo, `manifest.json` lives at `.output/chrome-mv3/manifest.json` after a build. Run `pnpm build` first if needed.)

Report results in a summary table:

> Validation complete. Issues found: **N critical**, **M warnings**.
> 
> Critical issues (must fix):
> - ...
> 
> Warnings:
> - ...
> 
> Would you like me to fix the critical issues now, or proceed?

**If critical issues exist, WAIT for the user's confirmation before proceeding** — do not auto-fix and skip ahead. Fix only what the user authorizes.

---

## Phase 7 — Test

Dispatch the `extension-test-runner` subagent (it has Bash + Read + Glob; not Edit/Write) to:

1. Run `pnpm build` (or `wxt build -b chrome`).
2. Run `pnpm exec web-ext lint --source-dir=.output/chrome-mv3` (Mozilla's linter works against MV3).
3. Run any unit tests (`pnpm test --run` if Vitest is configured).
4. Run the Playwright smoke harness from `skills/extension-testing/scripts/smoke.spec.ts` — loads the unpacked extension via `chromium.launchPersistentContext` and verifies the popup opens and background SW responds to a ping.

Report any failures with exact stderr. Do not claim success without seeing all of them pass.

---

## Phase 8 — Documentation and publishing prep

Generate or update:

1. **`README.md`** in the project — name, what it does, install (load-unpacked), development (`pnpm dev`), build (`pnpm build`), test (`pnpm test`), publish (`pnpm zip`).
2. **`CHANGELOG.md`** with v0.1.0 entry.
3. **`docs/store-listing.md`** — single-purpose statement, short description, detailed description, privacy practices disclosure, Limited Use disclosure. (Use `skills/extension-publishing/references/store-listing.md` as the template.)
4. **`docs/screenshots-spec.md`** — 1280×800 or 640×400, 1–5 screenshots, what each one should show. (See `skills/extension-publishing/references/screenshots-spec.md`.)
5. **`.github/workflows/release.yml`** — GitHub Action that runs lint+test+build on push, uploads zip artifact on tags. (See `skills/extension-publishing/references/github-actions.md`.)

End with a punchlist of what's left for the user to do manually:

- Take screenshots that match `docs/screenshots-spec.md`.
- Configure Google Cloud OAuth and obtain `CLIENT_ID`/`CLIENT_SECRET`/`REFRESH_TOKEN` (link to `skills/extension-publishing/references/oauth-setup.md`).
- Run `/chrome-ext:publish` when ready to submit.

---

## Final summary

Print:

```
Built: <project-name>
Framework: <WXT|Plasmo|CRXJS|vanilla>
Browsers: <chrome,edge,firefox,...>
Surfaces: <popup,options,...>
Validation: <N critical, M warnings — all resolved? yes/no>
Tests: <N passed, M failed>
Next: run `cd <project-name> && pnpm dev` to develop, or `/chrome-ext:publish` to submit.
```
