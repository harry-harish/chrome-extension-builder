# Changelog

All notable changes to this plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-05-21

### Added

- **Real demo GIF** at `demo/chrome-extension-builder-demo.gif` (20.7s,
  960×540, 4.0 MB). Captures an actual `/chrome-ext:new` session in
  Claude Code from the framework-decision table through to
  `/chrome-ext:validate` clean output. Replaces the broken README link
  that 404'd in v1.1.x.

## [1.1.1] - 2026-05-21

### Fixed

- **Plugin install broke at the runtime validator.** `userConfig` field
  entries had `enum: [...]` keys to constrain `default_framework`,
  `default_ui_framework`, and `package_manager` to a known set. `claude
  plugin validate` accepted this, but the in-app installer rejects it
  with `Unrecognized key: "enum"`. The schema only supports `type`,
  `title`, `description`, `default`, `sensitive`, `required`,
  `multiple`, `min`, `max`. Dropped the `enum` keys; moved the allowed-
  values list into each field's `description`. The orchestrator already
  validates the value at runtime, so behavior is unchanged for users
  who pick a valid value, and an unrecognized value now produces a
  clearer prompt than a silent failure.

## [1.1.0] - 2026-05-21

### Changed

- **License** flipped from Apache-2.0 to MIT to match the dominant
  convention in the npm/TypeScript extension ecosystem and to align with
  the MIT license already promised for generated scaffolds.
- **README** rewritten for sharper positioning. Install + first-run
  command now appear above the feature inventory. Added `Non-goals` and
  `Known rough edges` sections. No exaggerated claims.
- **Plugin description** rewritten across `plugin.json`,
  `marketplace.json`, and the GitHub repo description so all four
  surfaces use the same canonical short/long copy.
- **GitHub topics** added: `claude-code`, `claude-plugin`,
  `chrome-extension`, `manifest-v3`, `browser-extension`, `wxt`,
  `plasmo`, `crxjs`, `typescript`, `webstore`.

### Added

- `CONTRIBUTING.md` — short and strict; defines scope and required pre-PR
  checks.
- `SECURITY.md` — private-disclosure channels and clear in/out-of-scope
  list.
- `demo/` directory with a recording script for the 20-second install +
  scaffold + validate GIF that the README references.

## [1.0.0] - 2026-05-20

### Added

- **Commands** (5): `/chrome-ext:new`, `/chrome-ext:validate`,
  `/chrome-ext:add-feature`, `/chrome-ext:publish`, `/chrome-ext:migrate-mv2`.
- **Agents** (3): `extension-architect` (design-only, no Bash),
  `manifest-auditor` (read-only validators), `extension-test-runner`
  (build + lint + Playwright, no Edit/Write).
- **Skills** (8): `extension-architect`, `wxt-framework`, `plasmo-framework`,
  `crxjs-vite`, `extension-security`, `extension-testing`, `extension-i18n`,
  `extension-publishing`.
- **Hooks**: `PostToolUse` manifest validator (runs `validate-manifest.py`,
  `validate-csp.sh`, `validate-permissions.py` after any write to a
  `manifest.json`; exits 2 on critical findings). `PreToolUse` Chrome Web
  Store live-publish gate (blocks any Bash command containing
  `--auto-publish` unless prefixed with `CONFIRM_PUBLISH_LIVE=1`).
  `UserPromptSubmit` MV2-mention nudge.
- **Validators**: `validate-manifest.py` (MV3 schema, file existence for
  every surface — popup/options/side\_panel/devtools/chrome\_url\_overrides,
  CSP, length limits), `validate-csp.sh` (unsafe-eval / unsafe-inline /
  remote sources), `validate-permissions.py` (broad host permissions,
  webRequestBlocking, optional vs static), `check-store-readiness.sh`
  (icons, version semver, build cleanliness — no `node_modules`/`.env`/
  source maps), `check-i18n.sh` (locale key coverage and undefined-key
  references in code), `audit-deps.sh` (npm audit + LavaMoat recommendation).
- **Lint wrapper**: `lint-extension.sh` with `--target chrome|firefox|all`
  flag; demotes Firefox-only `web-ext lint` rules
  (`ADDON_ID_REQUIRED`, `BACKGROUND_SERVICE_WORKER_NOFALLBACK`, `STORAGE_SYNC`,
  `MISSING_DATA_COLLECTION_PERMISSIONS`) on Chrome-only manifests.
- **Scaffolders**: non-interactive `scaffold-wxt.sh` for headless agent
  runs; vanilla MV3 template under `skills/extension-architect/templates/vanilla/`.
- **Playwright smoke harness**: `smoke.spec.ts` using
  `chromium.launchPersistentContext` (the only supported way to side-load
  extensions in 2026).
- **Reference patterns** distilled from production extensions: Refined
  GitHub, Dark Reader, Bitwarden, MetaMask, uBlock Origin Lite,
  Violentmonkey, SponsorBlock, Stylus.

### Defaults locked in

- Manifest V3 only — MV2 was removed from Chrome 139 on 2025-07-24.
- WXT 0.20+ as the default framework (active maintenance, ~400 KB bundle).
- TypeScript everywhere.
- `chrome.activeTab` preferred over broad `host_permissions`.
- Strict CSP: no `unsafe-inline`, no `unsafe-eval`, no remote code.
- `_locales/`-based i18n generated by default.
- Reproducible builds — commit lockfile; bundle commit SHA into version
  string.
