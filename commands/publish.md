---
description: Prepare Chrome Web Store submission — generate listing assets, run final checks, build the zip, optionally upload via chrome-webstore-upload-cli.
argument-hint: "[optional path to extension root]"
---

# /chrome-ext:publish — Prepare and submit to Chrome Web Store

Prepare a Chrome Web Store submission for the extension in `$ARGUMENTS` (defaults to cwd).

## Procedure

### 1. Pre-flight check

Dispatch the `manifest-auditor` to run all validators. **Do not proceed if any critical issues exist.**

Run `check-store-readiness.sh`:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/extension-publishing/scripts/check-store-readiness.sh
```

The script verifies:
- `manifest.json` has `name`, `description`, `version`, `icons` (16, 32, 48, 128).
- `_locales/en/messages.json` exists if `default_locale` is set.
- All referenced files in the manifest exist on disk.
- No source maps, no `node_modules/`, no `.env` in the build dir.
- `description` is ≤132 chars (Chrome Web Store limit).
- `name` is ≤45 chars.

### 2. Listing assets

Load `skills/extension-publishing/SKILL.md` and walk the user through:

- **Short description** (≤132 chars) — appears in search results.
- **Detailed description** — single-purpose statement first, then features, then privacy practices link.
- **Category** — Productivity / Developer Tools / Privacy & Security / Accessibility / etc.
- **Single-purpose statement** — required by CWS policy. One sentence that narrowly describes what the extension does.
- **Privacy practices disclosure** — what data is collected, why, whether it's sold/shared. The CWS dashboard requires checkbox answers + a public privacy policy URL.
- **Limited Use disclosure** — required if you use any Google API restricted scope.
- **Screenshots** — 1280×800 or 640×400, 1–5 images. Generate `docs/screenshots-spec.md` describing what each should show; the user takes them.
- **Promotional tile** (optional) — 440×280.
- **Marquee promotional tile** (featured-extension only) — 1400×560.

Write all of these into `docs/store-listing.md` so the user can paste into the CWS dashboard. Do not invent privacy claims — ask the user explicitly what data is collected.

### 3. Build the zip

Detect the framework from `package.json` (the same way `add-feature.md` does):

| Detected in deps | Build commands |
|---|---|
| `wxt` | `${PM} exec wxt zip -b chrome` |
| `plasmo` | `${PM} run build && ${PM} run package` |
| `@crxjs/vite-plugin` | `${PM} run build && (cd dist && zip -r ../extension.zip .)` |
| (none of the above; vanilla) | `zip -r extension.zip . -x 'node_modules/*' '.git/*' '*.zip' '.env*' 'tests/*'` |

`${PM}` is `userConfig.package_manager` (default `pnpm`) detected by lockfile (`pnpm-lock.yaml` → `pnpm`, `yarn.lock` → `yarn`, `bun.lockb` → `bun`, else `npm`). Or call the bundled helper which does all of the above automatically:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/extension-publishing/scripts/build-zip.sh" .
```

Confirm the zip exists and report its size. Flag if it exceeds 10 MB (CWS soft limit; review takes longer).

### 4. Submit (optional — only if user has credentials configured)

`chrome-webstore-upload-cli` (v4) takes a subcommand: `upload` creates a new **draft** version, `publish` pushes the last uploaded version **live**, and running it with **no subcommand uploads and publishes live in one shot**. Credentials are read from required environment variables (`CLIENT_ID`, `CLIENT_SECRET`, `REFRESH_TOKEN`); `EXTENSION_ID` can be an env var or the `--extension-id` flag. The old `--client-id`/`--client-secret`/`--refresh-token`/`--auto-publish` flags were removed in v4.

If the user has set `CLIENT_ID`, `CLIENT_SECRET`, `REFRESH_TOKEN`, and `EXTENSION_ID` in the environment, offer to upload as a **draft only** (the `upload` subcommand):

```bash
pnpm dlx chrome-webstore-upload-cli@4 upload \
  --source <zip-path> \
  --extension-id "$EXTENSION_ID"
```

**Default to the `upload` (draft) subcommand. Never run `publish` or a bare `chrome-webstore-upload` without explicit user confirmation** — both push live. The plugin's PreToolUse hook blocks the `publish` subcommand and bare invocations unless the command is prefixed with `CONFIRM_PUBLISH_LIVE=1`; the `upload` (draft) subcommand is always allowed.

To go live after the user explicitly confirms, the user runs (themselves, outside the agent) the separate `publish` step:

```bash
CONFIRM_PUBLISH_LIVE=1 pnpm dlx chrome-webstore-upload-cli@4 publish \
  --extension-id "$EXTENSION_ID"
```

If credentials are not configured, link to `skills/extension-publishing/references/oauth-setup.md` for setting them up.

### 5. Post-submit

Report:

```
Submission prepared.
- Zip: <path> (<size>)
- Store listing: docs/store-listing.md
- Screenshots needed: 1–5 per docs/screenshots-spec.md
- Uploaded as draft: <yes|no>
- Next: review the draft in the CWS dashboard at https://chrome.google.com/webstore/devconsole, attach screenshots, fill in privacy practices, submit for review.
```

## Caveats to communicate

- The Chrome Web Store review is human-mediated. Expect 1–14 days. Single-purpose violations and overbroad permissions are the top rejection reasons.
- Once a version is published, you cannot republish the same version number. Bump `version` in `manifest.json` before each upload.
- The `EXTENSION_ID` only exists after the first manual upload via the dashboard. The first-ever submission must be done by hand to create the listing.
