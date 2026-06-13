# Changelog

All notable changes to this plugin are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-06-13

Pre-launch deep audit: a 4-dimension adversarial review (cross-framework
breakage, dependency drift, validator correctness, security/cross-platform)
that fixed 16 verified findings — including a publish-guard gap — and added CI
guardrails so each fixed class is regression-protected.

### Added

- **CI regression guardrails.** Three jobs in `.github/workflows/validate.yml`:
  an adversarial validator-fixture suite (known-bad manifests must be caught,
  known-good must pass), a dependency-drift check (fails if a fast-moving
  package un-pins), and a WXT scaffold→install→build→validate matrix (the exact
  path the `wxt/sandbox` break failed on). The drift check immediately caught a
  stray `wxt@latest` in the vanilla template README.
- **Agent capability matrix in the README.** A table now shows each specialist
  agent's tool grants, making the minimal-privilege design (no agent can
  Edit/Write or publish; only the architect plans without shell) verifiable at
  a glance instead of by reading three agent files.
- **Note that DNR rule-count limits aren't validated.** `dnr-conversion.md`
  already documented Chrome's ~30k static / ~5k dynamic limits; it now states
  explicitly that the bundled validators don't count rules, so authors track it.
- **Icon dimension validation.** `validate-manifest.py` now reads each PNG
  icon's actual pixel dimensions (stdlib only — no Pillow) and warns when they
  don't match the size key the icon is declared under. Wrong-size icons used to
  pass the file-existence check and only fail later at Chrome Web Store upload.
- **Host/match-pattern syntax validation.** `validate-permissions.py` now flags
  malformed match patterns in `host_permissions`, `optional_host_permissions`,
  and content-script `matches` (e.g. `**invalid**`), which Chrome silently drops
  at load time.

### Fixed

- **Windows requirements documented.** The bundled helper scripts assume a
  POSIX shell, and `build-zip.sh` shells out to `zip`. README now states that
  Windows users must run the plugin inside WSL or Git Bash. A cross-platform
  port of the helpers is planned post-launch.
- **Plasmo scaffold produced a project that wouldn't install (upstream bug).**
  `pnpm create plasmo` (create-plasmo 0.90.x) pins `"plasmo": "workspace:*"`,
  so the next `pnpm install` fails with `ERR_PNPM_WORKSPACE_PKG_NOT_FOUND`. The
  `plasmo-framework` skill and `/chrome-ext:new` Plasmo path now warn about the
  upstream breakage, document the `pnpm pkg set dependencies.plasmo=latest`
  workaround, and steer new projects to WXT. (Existing Plasmo projects are
  unaffected — they never re-run the scaffold.)
- **Interactive WXT scaffold docs pinned to `wxt@~0.20.26`.** `commands/new.md`
  and the `wxt-framework` skill used `wxt@latest init`; since 0.20.x relocated
  the `defineBackground`/`defineContentScript` exports, a floating `@latest`
  can scaffold a project that no longer imports correctly. Also corrected a doc
  line that wrongly said `scaffold-wxt.sh` runs `wxt init` (it writes files
  directly and already pins `~0.20.26`).
- **`validate-csp.sh` now honors the exit-code contract.** It exited with the
  raw critical count (e.g. `3`) instead of `1`; now `exit 1` on any critical,
  `0` otherwise — consistent with the other validators.
- **CRXJS scaffold was incomplete and failed to build.** The `react-ts`
  template doesn't include the `chrome.*` types and the skill didn't create the
  `_locales` file its manifest references, so a clean scaffold hit `TS2304:
  Cannot find name 'chrome'` and shipped unresolved `__MSG_*__` placeholders.
  Added `@types/chrome`, a `tsconfig.app.json` `types: ["chrome"]` step, and a
  `public/_locales/en/messages.json` step. Also moved the recommended plugin
  off `@crxjs/vite-plugin@beta` (an old `2.0.0-beta.x`) to stable `@^2.6`.

### Security

- **Publish guard rewritten to block the actual live-publish commands.** The
  PreToolUse hook previously blocked `--auto-publish`, a flag that
  `chrome-webstore-upload-cli` v4 no longer has — so the real live-publish
  paths (`chrome-webstore-upload publish`, or a bare `chrome-webstore-upload`
  that uploads-and-publishes in one shot) bypassed the guard entirely. The
  hook now allows only the explicit `upload` (draft) subcommand and blocks
  `publish`/bare invocations unless prefixed with `CONFIRM_PUBLISH_LIVE=1`.

### Changed

- **Publishing docs updated to the `chrome-webstore-upload-cli` v4 CLI.**
  v4 removed the `--client-id`/`--client-secret`/`--refresh-token`/`--auto-publish`
  flags: credentials now come from the `CLIENT_ID`/`CLIENT_SECRET`/`REFRESH_TOKEN`
  environment variables, and live publish uses a separate `publish` subcommand.
  Updated `commands/publish.md`, `extension-publishing/SKILL.md`, the GitHub
  Actions template, and the OAuth setup guide; pinned the `dlx` invocations to
  `chrome-webstore-upload-cli@4` so a future major can't break the flags again.

## [1.3.1] - 2026-06-13

### Fixed

- **WXT scaffold produced a project that wouldn't install or build.** WXT
  0.20.26 removed the `wxt/sandbox` export, but the scaffold and the
  `wxt-framework` skill docs still imported `defineBackground` /
  `defineContentScript` from `wxt/sandbox`. On a fresh scaffold, `pnpm
  install` (via the `wxt prepare` postinstall) and `pnpm build` both failed
  with `"./sandbox" is not exported`. Fixed across all 8 references
  (`scaffold-wxt.sh`, `wxt-framework/SKILL.md`, `references/entrypoints.md`,
  `references/messaging.md`, `plasmo-framework/references/csui.md`) to the
  current subpaths `wxt/utils/define-background` and
  `wxt/utils/define-content-script`. Verified end-to-end: scaffold → `pnpm
  install` (rc 0) → `pnpm build` (rc 0) → real `.output/chrome-mv3/manifest.json`
  → `web-ext lint` 0 errors.
- **Pinned WXT defensively.** `scaffold-wxt.sh` floated `"wxt": "^0.20.0"`
  (which is how it drifted onto the breaking 0.20.26); changed to
  `"wxt": "~0.20.26"` (patch-only) so a future minor can't silently break
  the scaffold again. Matches the project's reproducible-builds default.

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
