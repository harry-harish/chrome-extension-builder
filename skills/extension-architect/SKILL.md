---
name: extension-architect
description: Use when designing or auditing a Chrome/browser extension's architecture under Manifest V3. Covers service worker lifecycle, message-passing topology, storage tiers (local/session/sync), feature-module layout, permissions minimization, and MV2→MV3 migration. Load when the user asks about extension architecture, MV3 patterns, "how should I structure my extension," or how to migrate from MV2. Default companion to /chrome-ext:new Phase 1–3 and /chrome-ext:migrate-mv2.
allowed-tools: [Read, Grep, Glob, Bash, WebFetch]
license: Apache-2.0
---

# Extension Architect

This skill carries the architectural defaults a Manifest V3 extension should adopt in 2026 and routes Claude to deeper references when needed.

## Core principles (apply to every extension)

1. **Manifest V3 only.** Chrome 139 (2025-07-24) removed MV2; the enterprise re-enable policy expired June 2025. Reject `manifest_version: 2` outright.
2. **TypeScript everywhere.** Every reference extension in 2026 uses TS — Refined GitHub, Dark Reader, Bitwarden, MetaMask, Vimium C, SponsorBlock.
3. **Service worker as dispatcher, not doer.** SWs are ephemeral. Route typed messages → controllers → respond → suspended. Persist state via `chrome.storage`, not in-memory.
4. **Typed message passing.** Discriminated unions in `types/messages.ts`. Wrap `chrome.runtime.sendMessage` in `sendCmd<T>`. Never `message.action === "doThing"`.
5. **Minimal permissions.** `chrome.activeTab` over `host_permissions`. `optional_host_permissions` for non-core. uBlock Origin Lite's tiered model is canonical.
6. **Feature-module architecture.** 100+ self-contained modules under `src/features/`, not a god background script. Refined GitHub and MetaMask are exemplars.
7. **Strict CSP.** `script-src 'self'`. No `unsafe-eval`, no `unsafe-inline`, no remote code.
8. **Storage tiers.** `chrome.storage.local` for persistent state, `chrome.storage.session` for ephemeral cache (MV3-only), `chrome.storage.sync` for user prefs.
9. **i18n from day one.** `_locales/{locale}/messages.json` + `chrome.i18n.getMessage('key')`. Adding later is painful.
10. **Reproducible builds.** Commit lockfile; bundle commit SHA into version string; consider committing store-signed artifacts (Dark Reader does this).

## Decision: framework

Load `references/framework-decision.md` for the full matrix. Default: **WXT**. Fall back to Plasmo only for existing projects, CRXJS for Vite migrations, vanilla for tiny extensions or learning.

## Decision: surfaces

Load `references/surfaces.md` for trade-offs between popup, options, side panel, content script, devtools panel, new-tab override.

## Decision: messaging topology

Load `references/message-passing.md` for the typed-`sendCmd` pattern and the four-execution-context model from Violentmonkey.

## Decision: storage

Load `references/storage-tiers.md` for which kind of state goes in which tier, plus the `chrome.storage.session` ephemeral cache pattern.

## Decision: permissions

Load `references/permissions.md` for the uBO Lite tiered/optional permissions model and `chrome.activeTab` usage.

## Reference patterns (load only the matching one)

These are in `examples/`:

- **`refined-github-pattern.md`** — Feature-module architecture; lazy URL-based init; CSS-only fast path; 100+ features without spaghetti.
- **`dark-reader-pattern.md`** — Pure-TS no-framework build; same codebase as standalone npm library; reproducible signatures.
- **`bitwarden-pattern.md`** — Multi-client monorepo with shared `libs/`; how to structure crypto-sensitive code.
- **`metamask-pattern.md`** — LavaMoat for supply-chain defense; controller-based state; in-page provider injection.
- **`ubo-lite-pattern.md`** — Optional/tiered permissions; build-time compilation of filter lists to DNR.
- **`violentmonkey-pattern.md`** — Explicit four-execution-context architecture; SW startup race retry logic; verified builds.
- **`sponsorblock-pattern.md`** — Crowdsourced data with backend; CORS off the content script; SW handles network.
- **`stylus-pattern.md`** — Tiny content-script footprint (~10 KB, ~1 ms per site); CodeMirror bundled locally.

## MV2 → MV3 migration

Load `references/mv2-to-mv3-migration.md` for the full delta list and conversion playbook. Use `/chrome-ext:migrate-mv2` to apply it.

## Scripts

- `scripts/validate-manifest.py` — schema validation + best-practice checks. Wrapped by the `manifest-auditor` agent.

## Templates

- `templates/vanilla/` — minimal MV3 starter with no framework. For learning or tiny extensions.

## Output style

When asked to architect, produce a structured doc:

1. Single-purpose statement
2. Surfaces (which, why)
3. Framework + UI stack
4. File tree
5. Message-passing topology
6. Storage strategy
7. Permissions (each justified)
8. CSP
9. Reference patterns inherited
10. Risks

End with the framework confirmation question.
