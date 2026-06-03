# Changelog

All notable changes to this plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.3.0] - 2026-06-03

### Added

- **Scaffold attribution footer.** Generated project READMEs (WXT scaffold
  and the vanilla template) now end with a single, clearly-removable
  attribution line linking back to the plugin. README-footer only — never
  in extension UI, manifests, or store listings.
- **Issue templates** (`.github/ISSUE_TEMPLATE/`): bug-report and
  feature-request forms with framework/command checkboxes — the plugin's
  telemetry-free way of learning which paths people actually use. Plus a
  config routing security reports to the private advisory form and
  questions to Discussions.
- **GitHub Discussions enabled** with a public
  [Roadmap](https://github.com/harry-harish/chrome-extension-builder/discussions/1)
  and three starter issues (icon-dimension validation, headless smoke-test
  docs, vue/svelte/solid popup templates).
- **README badge row** (CI, license, plugin, release) and a repo social
  preview card at `.github/social-preview.png`.

### Changed

- Eight new GitHub topics for discoverability (`chrome-web-store`, `mv3`,
  `cli`, `developer-tools`, `scaffolding`, `firefox`, `edge`, `vite`).

## [1.2.3] - 2026-06-01

### Changed

- **Removed the `version` field from the plugin entry in
  `marketplace.json`.** Per [affaan-m/everything-claude-code#37][1] and
  the empirical pattern in the official catalog (190 of 204 plugins in
  `anthropics/claude-plugins-official` omit this field), a `version`
  field on the plugin entry blocks Claude Code's auto-update detection
  and the upstream SHA-bump CI for `claude-plugins-community`. The
  plugin's own `.claude-plugin/plugin.json` retains its `version` —
  only the marketplace-level duplicate was removed.

  Motivation: our community-marketplace pin has been stuck at the
  initial v1.0.0 commit since approval (2026-05-20). Removing this
  field is the most likely fix to unblock automatic bumps going
  forward. It does not retroactively update the existing pin — that
  still needs an Anthropic-side intervention — but it removes one
  known blocker on our side.

  [1]: https://github.com/affaan-m/everything-claude-code/issues/37

## [1.2.2] - 2026-05-22

### Fixed

- **Hook load failed at runtime** with
  `Invalid input: expected record, received undefined` at path `hooks`.
  The runtime expects `hooks/hooks.json` to wrap the event arrays in an
  outer `"hooks"` key:

      { "hooks": { "PostToolUse": [...], "PreToolUse": [...], ... } }

  Our file had `PostToolUse`/`PreToolUse`/`UserPromptSubmit` at the top
  level (matching the format that `~/.claude/settings.json` accepts and
  that older plugin docs showed). The plugin loader rejected it. Wrapped
  the existing arrays under `hooks:` — every individual hook command,
  matcher, and timeout is byte-identical to v1.2.1; only the outer
  structure changed.

  Same class of bug as v1.1.1's `userConfig.enum` rejection: `claude
  plugin validate` accepted the bad schema, but the runtime did not.

## [1.2.1] - 2026-05-21

### Changed

- **Demo GIF replaced.** The v1.2.0 demo accidentally captured the
  author's Claude API account organization name in the Claude Code
  status bar. The new GIF was re-recorded from a trimmed clip with
  that frame range removed and was manually verified clean. Same
  20.7s / 960×540 / ~3.8 MB encoding profile.

### Note

- The v1.2.0 demo asset is still reachable via the GitHub blob CDN by
  direct commit SHA for the standard ~30-day object-retention window
  before GitHub's GC runs. Anyone with `4354549` or `v1.2.0` can still
  fetch it. The leaked content was an organization-name identifier
  only; no credentials or business-sensitive data were involved.

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
