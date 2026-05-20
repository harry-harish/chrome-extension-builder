# Privacy Policy

_Last updated: 2026-05-20_

## TL;DR

**This plugin collects no data.** It runs entirely on your local machine
inside Claude Code, makes no network calls of its own, ships no
analytics or telemetry SDK, and stores no information about you, your
project, your prompts, or your generated extensions.

## What runs locally

Everything in this plugin executes on your machine:

| Component | Where it runs | Network access |
|---|---|---|
| Slash commands (`/chrome-ext:*`) | Local Claude Code session | None (the model is invoked through Claude Code, whose own data handling is governed by [Anthropic's privacy policy](https://www.anthropic.com/legal/privacy)) |
| Agents (`extension-architect`, `manifest-auditor`, `extension-test-runner`) | Local Claude Code session | None of their own |
| Skills (`SKILL.md` documents) | Read into the model's context locally | None |
| Hooks (`PostToolUse`, `PreToolUse`, `UserPromptSubmit`) | Local shell scripts in `hooks/` and `skills/*/scripts/` | None |
| Validators (`validate-manifest.py`, `validate-csp.sh`, `validate-permissions.py`, `check-store-readiness.sh`, `check-i18n.sh`, `audit-deps.sh`) | Local Python / bash | None |
| Scaffolders (`scaffold-wxt.sh`, `build-zip.sh`) | Local bash + `zip` | None — the WXT/Plasmo install they invoke is the user's package manager, governed by its own policies |
| Smoke harness (`smoke.spec.ts`) | Local Playwright + Chromium | Loads `https://example.com` only if the user's extension declares a content script matching it; no data is sent anywhere |

The plugin reads files from your project directory only when you
explicitly invoke a command that needs them (e.g., `manifest.json` for
validation). Nothing is read in the background.

## What the plugin does NOT do

- Does not phone home.
- Does not ship any analytics SDK (no Amplitude, Mixpanel, Segment,
  PostHog, Google Analytics, Sentry, etc.).
- Does not contain any `curl`, `wget`, `nc`, or other network primitive
  in its hooks.
- Does not store credentials. The Chrome Web Store OAuth values
  (`CLIENT_ID`, `CLIENT_SECRET`, `REFRESH_TOKEN`, `EXTENSION_ID`) are
  read from your shell environment by `chrome-webstore-upload-cli` —
  they are never logged, persisted, or transmitted by this plugin.
- Does not access your browser profile, browsing history, cookies, or
  any other browser state.
- Does not modify files outside your current project directory.

## Third-party tools the plugin invokes

When you run certain commands, the plugin shells out to third-party
tools. Each has its own privacy and data-handling posture:

- **`pnpm` / `npm` / `yarn` / `bun`** — your chosen package manager,
  used to install WXT/Plasmo/CRXJS dependencies and to run lint/test.
- **`web-ext`** — Mozilla's extension linter (`addons-linter`), invoked
  via `npx`/`dlx` during `/chrome-ext:validate`. Runs locally.
- **`@playwright/test`** — invoked during the smoke-test phase. Drives
  a bundled Chromium binary locally.
- **`chrome-webstore-upload-cli`** — only invoked if you explicitly run
  `/chrome-ext:publish` with Chrome Web Store OAuth credentials set in
  your environment. Talks to the [Chrome Web Store API](https://developer.chrome.com/docs/webstore/api), governed by [Google's privacy policy](https://policies.google.com/privacy).

The plugin does not bundle any of these tools — it invokes whatever is
installed on your system or fetches them through your package manager.

## Generated extensions

The Chrome extensions this plugin _generates_ are your code. You own
them, you ship them, and **their** privacy practices are entirely yours
to define. The plugin will scaffold a `docs/store-listing.md` with
prompts for you to fill in your generated extension's data-collection
disclosures — but the plugin itself never sees what you write there.

## Changes

If a future version of the plugin ever adds data collection (e.g., an
optional opt-in telemetry hook for usage metrics), this document will
be updated in the same commit, the change will be called out in
`CHANGELOG.md`, and the affected functionality will be off by default
with an explicit consent prompt.

## Contact

Questions or concerns? Open an issue at
<https://github.com/harry-harish/chrome-extension-builder/issues>.
