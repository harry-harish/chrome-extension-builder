# Anthropic plugin directory submission (and the case for "Anthropic Verified")

Prep doc for submitting chrome-extension-builder to the **Anthropic plugin
directory** (the web directory at claude.com/plugins, where the "Anthropic
Verified" badge lives). This is separate from the `claude-community` CLI
marketplace listing we already have. There is no standalone "apply for
Verified" form: you submit to the directory, meet every requirement, and
Anthropic grants Verified at its discretion after additional quality/safety
review. So the plan is to clear every published requirement and make the
quality/safety case strong.

Sources for the criteria: the Anthropic Software Directory Policy
(support.claude.com/en/articles/13145358) and the pre-submission checklist
(claude.com/docs/connectors/building/review-criteria).

## Which form

This is a personal project (author: harry-harish), not company work. Use the
**Console form for individual authors**: https://platform.claude.com/plugins/submit
(The claude.ai form at claude.ai/admin-settings/directory/submissions/plugins/new
requires a Team/Enterprise org with directory-management access. Do not route a
personal project through CapillaryTech's org access.)
Landing page: https://clau.de/plugin-directory-submission

## Form fields (paste-ready)

- **Plugin name:** chrome-extension-builder
- **Tagline:** A Claude Code plugin that scaffolds, validates, and ships Manifest V3 Chrome extensions.
- **Category:** Developer tools / Coding
- **Public GitHub repo:** https://github.com/harry-harish/chrome-extension-builder
- **License:** MIT
- **Marketplace install:** `/plugin marketplace add anthropics/claude-plugins-community` then `/plugin install chrome-extension-builder@claude-community`
- **Privacy policy URL:** https://github.com/harry-harish/chrome-extension-builder/blob/main/PRIVACY.md
- **Security / disclosure:** https://github.com/harry-harish/chrome-extension-builder/blob/main/SECURITY.md
- **Support channel:** GitHub issues (https://github.com/harry-harish/chrome-extension-builder/issues); private security reports via GitHub advisory or the email in SECURITY.md.
- **Public documentation:** README.md (public, in repo) covers install, commands, agents, defaults, and runtime requirements. A dev.to launch article is drafted and can be posted by the publish date if a separate write-up is preferred.

### Long description (paste)

chrome-extension-builder gives Claude Code extension-specific commands for Manifest V3 work: scaffold a new extension, validate an existing one, add a popup or content script, prep a Chrome Web Store release, and migrate a Manifest V2 codebase to V3. It supports WXT (default), Plasmo, CRXJS, and vanilla MV3.

The design catches MV3-specific mistakes deterministically rather than relying on the model. A model that writes plausible code also writes a plausible manifest, but in MV3 plausible and valid diverge: unsafe-eval in the CSP, overbroad host permissions, MV2 background pages, remote script. Validators and hooks flag these before they reach a reviewer or a browser. Defaults are opinionated and safe: MV3-only, TypeScript, activeTab over broad host permissions, strict CSP, typed message passing.

## Three working examples (required)

1. **Scaffold a new extension.** Prompt: "Create a new Manifest V3 Chrome extension with a popup and a content script that runs on docs.google.com." Runs `/chrome-ext:new`, an eight-phase guided scaffold (WXT by default), producing a buildable MV3 project with safe defaults.
2. **Validate before submission.** Prompt: "Check this extension's manifest, CSP, and permissions for Chrome Web Store problems before I submit." Runs `/chrome-ext:validate`, which flags issues like an unsafe-eval CSP, a remote script-src, or an overbroad `<all_urls>` permission, with a nonzero exit on anything critical.
3. **Migrate MV2 to MV3.** Prompt: "Migrate my Manifest V2 extension to MV3." Runs `/chrome-ext:migrate-mv2`, which produces a structured migration plan (background page to service worker, blocking webRequest to declarativeNetRequest, CSP and web_accessible_resources reshaping).

## Testing / sample data for reviewers

No account or credentials are required. The plugin runs entirely on the local
machine (see PRIVACY.md), so there is no backend to provision. Reviewers can
verify full functionality two ways:

- **Scaffolding:** run `/chrome-ext:new` in an empty directory. It produces a WXT MV3 project that installs and builds (`pnpm install && pnpm build`).
- **Validation, with bundled sample data:** the repo ships `tests/fixtures/manifests/` with six known-bad manifests (one per MV3 violation class) and one known-good manifest. `bash tests/run-validator-fixtures.sh` asserts each bad one is caught and the good one passes, so a reviewer can confirm the validators behave as described in one command. The README, CHANGELOG, and a demo video/GIF document the rest.

## The case for "Anthropic Verified" (quality + safety)

Map of our posture to the directory's stated review axes (safety, security, compatibility, quality):

- **No data collection / no memory access.** PRIVACY.md: the plugin makes no network calls of its own, ships no analytics, stores no credentials, and never queries Claude's memory, chat history, or files. Hooks read only the tool input needed to validate, locally. This directly satisfies the policy's data-collection and memory-access prohibitions.
- **Least-privilege by construction.** Three agents with deliberately narrow tool grants: an architect that designs but cannot run shell or write files, a read-only manifest auditor, and a test-runner that can build and lint but cannot edit. The component that audits your manifest physically cannot rewrite it. This mirrors the checklist's "separate read and write" principle at the agent level.
- **Safety-positive hooks.** A PreToolUse hook blocks an accidental live Chrome Web Store publish unless explicitly confirmed; a PostToolUse hook re-validates manifests on write. The plugin adds guardrails, it does not evade any.
- **Accurate descriptions.** Command and agent descriptions state exactly what they do; the validators are tested against fixtures so behavior matches the description (a checklist requirement).
- **Pre-launch adversarial audit.** v1.4.0 shipped after a multi-agent adversarial audit that found and fixed 16 verified issues, including a publish-guard gap, plus three CI guardrails (validator fixtures, dependency-drift check, real install+build matrix) so the fixed classes cannot regress. CHANGELOG documents all of it.
- **Open source + passes validation.** MIT-licensed, public repo, `claude plugin validate` green in CI on every push, and a CI job that runs the real `claude plugin install` to catch runtime-schema divergence.
- **Supported use case.** A developer tool, not a financial, ad, or AI-media-generation use case (the policy's prohibited categories).

## Pre-submission checklist

- [x] Public GitHub repo, MIT-licensed
- [x] `claude plugin validate` passes (CI + local)
- [x] Public documentation (README; dev.to article drafted if a separate write-up is wanted)
- [x] Privacy policy (PRIVACY.md, public URL)
- [x] Contact + support channel (GitHub issues; SECURITY.md for private reports)
- [x] Three working example prompts (above)
- [x] Sample data for reviewers (tests/fixtures/manifests + scaffold path)
- [ ] Confirm ownership of the repo/domains at submission (author owns the GitHub repo; no other domains/APIs)
- [ ] Accept the Software Directory Terms in the form
- [ ] Submit via the Console individual-author form
