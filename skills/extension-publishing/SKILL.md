---
name: extension-publishing
description: Use when preparing or executing a Chrome Web Store submission. Covers single-purpose statement, privacy practices disclosure, Limited Use disclosure, screenshots spec, listing copy, and programmatic upload via chrome-webstore-upload-cli. Load during /chrome-ext:publish or when the user asks how to submit to the store.
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
license: Apache-2.0
---

# Extension Publishing

End-to-end Chrome Web Store submission prep.

## What the store requires

Per Chrome Web Store policies (developer.chrome.com/docs/webstore/program-policies):

1. **Single-purpose statement** — One sentence describing what the extension does. Narrow. Concrete. Not "a useful tool" — "highlights merged pull requests on GitHub."
2. **Privacy practices disclosure** — What data is collected, for what purpose, whether it's sold/shared, whether it's encrypted in transit. The CWS dashboard prompts checkboxes + a privacy policy URL.
3. **Limited Use disclosure** — Required if you call any restricted-scope Google API (Gmail, Drive, etc.).
4. **Permissions justifications** — Each manifest permission must be justified in the dashboard. `<all_urls>` triggers manual review.
5. **Icons** — 128×128 (store), 48×48 (extensions page), 16×16 (toolbar). Add 32×32 for HiDPI.
6. **Screenshots** — 1–5 images at 1280×800 or 640×400. PNG or JPEG.
7. **Promotional tile** (optional) — 440×280.
8. **Marquee tile** (featured-only) — 1400×560.
9. **Listing copy** — Name (≤45 chars), short description (≤132 chars), detailed description (no limit but keep skimmable).

## Listing copy template

Write into `docs/store-listing.md`:

```markdown
# Store Listing — <Extension Name>

## Single-purpose statement
<One sentence. Required.>

## Short description (≤132 chars)
<Search-result snippet. Lead with verb.>

## Detailed description

<Open with the single-purpose statement.>

What it does:
- <Feature 1>
- <Feature 2>

What it does NOT do:
- <Concrete reassurance about privacy / scope.>

Privacy: <Plaintext summary of what data is collected and why. Link to full policy.>

Permissions:
- `<permission>` — <one-line justification>

## Privacy policy URL
<https://your-domain.com/privacy>

## Category
<Productivity | Developer Tools | Accessibility | Social & Communication | News & Weather | Photos | Search Tools | Shopping | Sports | Fun>

## Permissions justifications (for the dashboard)
- `storage`: To persist user preferences.
- `activeTab`: To inject the highlight overlay on user invocation.
- `<all_urls>`: REQUIRED because <single-purpose justification>. If you cannot justify <all_urls>, remove it.
```

Don't invent privacy claims. Ask the user explicitly what data is collected; if they say "none," verify by grepping for `fetch(`, `XMLHttpRequest`, `chrome.identity`, analytics SDKs, third-party scripts.

## Screenshots spec

Write into `docs/screenshots-spec.md`:

```markdown
# Screenshots Spec — <Extension Name>

Dimensions: 1280×800 (preferred) or 640×400. PNG or JPEG, <5 MB each.

## Screenshot 1 — Primary value prop
Show: <Concrete scene that demonstrates the single-purpose statement.>
Example: A GitHub PR list with the extension's highlight visible.

## Screenshot 2 — Settings / options
Show: The options page with annotated callouts.

## Screenshot 3 — Edge case / power feature
Show: A less-obvious capability that converts power users.

## Screenshot 4 — Multi-context
Show: The extension working across the user's typical workflow (popup + content script visible together).

## Screenshot 5 — Trust signal
Show: A "no data collected" indicator, the permissions screen, or social proof (testimonials, GitHub stars).
```

The user takes the screenshots; this plugin can't.

## OAuth setup for programmatic upload

The Chrome Web Store has a publish API guarded by Google OAuth. To upload from CI:

1. Create a Google Cloud project at console.cloud.google.com.
2. Enable the Chrome Web Store API.
3. Create OAuth 2.0 credentials (Desktop app type).
4. Save the `CLIENT_ID` and `CLIENT_SECRET`.
5. Visit `https://accounts.google.com/o/oauth2/auth?response_type=code&scope=https://www.googleapis.com/auth/chromewebstore&client_id=YOUR_CLIENT_ID&redirect_uri=urn:ietf:wg:oauth:2.0:oob` and grant access.
6. Exchange the resulting code for a refresh token (one-time `curl` to `https://accounts.google.com/o/oauth2/token`).
7. Store `CLIENT_ID`, `CLIENT_SECRET`, `REFRESH_TOKEN` in GitHub Actions secrets (or your local `.env`).
8. The `EXTENSION_ID` only exists after your first manual upload to the dashboard — the first-ever submission must be done by hand.

Full walkthrough: `references/oauth-setup.md`.

## Programmatic upload

`chrome-webstore-upload-cli` (v4) takes a subcommand: `upload` creates a new draft version, `publish` pushes the last uploaded version live, and **running it with no subcommand uploads and publishes live in one shot**. Credentials come from required environment variables (`CLIENT_ID`, `CLIENT_SECRET`, `REFRESH_TOKEN`); `EXTENSION_ID` is an env var or the `--extension-id` flag. The v3 `--client-id`/`--client-secret`/`--refresh-token`/`--auto-publish` flags were removed in v4.

Draft upload (recommended default — the `upload` subcommand):

```bash
pnpm dlx chrome-webstore-upload-cli@4 upload \
  --source <zip-path> \
  --extension-id "$EXTENSION_ID"
```

Publish live (only with explicit user authorization — the separate `publish` step):

```bash
CONFIRM_PUBLISH_LIVE=1 pnpm dlx chrome-webstore-upload-cli@4 publish \
  --extension-id "$EXTENSION_ID"
```

**Default to the `upload` (draft) subcommand.** The plugin's PreToolUse hook blocks the `publish` subcommand and bare `chrome-webstore-upload` invocations (both publish live) unless prefixed with `CONFIRM_PUBLISH_LIVE=1`; the `upload` subcommand is always allowed.

A bad release going live is much worse than a draft sitting unreviewed. Drafts can be reviewed and discarded in the CWS dashboard; live releases must be replaced with a new version.

## GitHub Actions template

`references/github-actions.md` ships a complete `release.yml`:

```yaml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'pnpm' }
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec wxt lint || true
      - run: pnpm dlx web-ext@latest lint --source-dir=.output/chrome-mv3 --self-hosted
      - run: pnpm build && pnpm zip
      - uses: actions/upload-artifact@v4
        with:
          name: extension-${{ github.ref_name }}
          path: .output/*.zip
      - run: |
          pnpm dlx chrome-webstore-upload-cli@4 upload \
            --source .output/*.zip \
            --extension-id "$EXTENSION_ID"
        env:
          EXTENSION_ID: ${{ secrets.EXTENSION_ID }}
          CLIENT_ID: ${{ secrets.CW_CLIENT_ID }}
          CLIENT_SECRET: ${{ secrets.CW_CLIENT_SECRET }}
          REFRESH_TOKEN: ${{ secrets.CW_REFRESH_TOKEN }}
```

## Reviewer expectations

The CWS review is human-mediated. Most rejections fall in:

1. **Single-purpose violations** — extension does multiple unrelated things.
2. **Overbroad permissions** — `<all_urls>` without a single-purpose reason.
3. **Privacy disclosure mismatch** — code calls a tracker that's not declared.
4. **Remote code** — `eval` of fetched JS, dynamically loaded scripts.
5. **Misleading listing** — screenshots show functionality that isn't there.

Mitigations are all in the listing prep above. The plugin can prepare; it cannot guarantee approval.

## Other stores (briefly)

- **Firefox Add-ons** (AMO): use `web-ext sign` or the `addons.mozilla.org` API. Manual review by Mozilla; slower than CWS.
- **Microsoft Edge Add-ons**: use `microsoft-edge-publish-api` (similar OAuth flow).
- **Safari**: requires Xcode + an Apple Developer account. Convert via `xcrun safari-web-extension-converter`.

## Scripts in this skill

- `scripts/check-store-readiness.sh` — verifies the built extension is submission-ready (icons present, descriptions within limits, no source maps, no `.env`, no `node_modules/`).
- `scripts/build-zip.sh` — packages `.output/chrome-mv3/` into a CWS-ready zip.

## Things not to do

- ❌ Don't publish live from CI on the first release. Upload as draft and review in the dashboard.
- ❌ Don't commit `CLIENT_SECRET` or `REFRESH_TOKEN` to git. Use Actions secrets.
- ❌ Don't include `node_modules/`, `.env`, or source maps in the zip.
- ❌ Don't reuse a version number — Chrome silently fails the upload.
- ❌ Don't lie on the privacy disclosure. Audit before you submit.
