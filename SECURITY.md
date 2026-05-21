# Security Policy

## Reporting a vulnerability

If you find a security issue in this plugin, **do not open a public GitHub issue**. Report it privately so it can be triaged and patched before disclosure.

### Channels (in order of preference)

1. **GitHub private vulnerability report** — file at
   <https://github.com/harry-harish/chrome-extension-builder/security/advisories/new>.
   This is the preferred channel; it creates a private discussion thread tied to the repo.
2. **Email** — `22562634+harry-harish@users.noreply.github.com` (GitHub's
   privacy-preserving relay for harry-harish).

Please include:

- Plugin version (`cat .claude-plugin/plugin.json | jq .version`).
- A reproducer (command sequence, manifest snippet, hook input — whichever is relevant).
- Impact assessment (what an attacker could do).
- Your suggested patch, if you have one.

## What counts as a security issue

- A hook command that exfiltrates data, runs untrusted shell, or evaluates remote code.
- A validator that misses a class of MV3 violation that should always block.
- A scaffolder that emits a manifest with unsafe defaults (e.g. `unsafe-eval`,
  remote `script-src`, hardcoded secrets).
- The `--auto-publish` PreToolUse gate bypassable in an unintended way.
- An agent with tool grants broader than its stated job (e.g. an auditor
  agent gaining `Write`).
- Plugin commands that read or modify files outside the active project directory.

## What is NOT a security issue

- The plugin telling Claude to produce code you disagree with stylistically.
- `web-ext lint` flagging Firefox-only rules on a Chrome-targeted manifest
  (this is by design; use `--target chrome`).
- Chrome Web Store rejecting your submission (the plugin prepares the
  submission; it cannot override CWS review).
- Bugs in third-party tools the plugin invokes (`wxt`, `plasmo`,
  `web-ext`, `chrome-webstore-upload-cli`, Playwright) — report those to
  their upstream projects.

## Response targets

- Acknowledgement of report: within 72 hours.
- Triage decision (accept/reject/needs-info): within 7 days.
- Patch or workaround for accepted reports: within 30 days for high-impact,
  90 days for low-impact, communicated in the private thread.

## Disclosure

After a patch is released, the report will be summarized in a GitHub
Security Advisory tied to the affected version range. Reporters who
want credit will be named; reporters who prefer anonymity will not.

## Out of scope

- Issues that require physical access to the developer's machine.
- Issues in the Claude Code platform itself — report those at
  <https://github.com/anthropics/claude-code/issues>.
- Issues in generated user extensions (those are the user's code, not
  the plugin's).
