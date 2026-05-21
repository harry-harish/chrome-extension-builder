# Contributing

This plugin is small, focused, and opinionated. PRs that match that posture are welcome.

## Before you open a PR

- Open an issue first for anything beyond a typo or doc fix. Surprise PRs waste your time and ours.
- Read the README's `Non-goals` section. The plugin will say no to scope creep.

## Where contributions actually move the needle

- New reference patterns in `skills/extension-architect/examples/` distilled from production MV3 extensions.
- Sharper validator coverage in `skills/extension-architect/scripts/`, `skills/extension-security/scripts/`, `skills/extension-publishing/scripts/`.
- Skills for surfaces or APIs the current plugin handles poorly (devtools, side panels, declarativeNetRequest).

## Local setup

```bash
git clone https://github.com/harry-harish/chrome-extension-builder
cd chrome-extension-builder
claude --plugin-dir .
```

## Required before PR

1. `claude plugin validate .` exits 0.
2. Every shipped `.sh` passes `shellcheck --severity=warning`.
3. The CI workflow at `.github/workflows/validate.yml` is green on your branch.
4. New skills/agents follow the existing `description: Use when...` trigger pattern.
5. New validators emit `CRITICAL`/`WARNING`/`INFO` with the same column format as existing ones.
6. No telemetry. No network calls in hooks. No hardcoded credentials.

## PR description

Include:

- What problem does this solve?
- What did you change to solve it?
- How did you verify it works?
- What does it intentionally not do?

That's it. Don't pad the description.

## Reviews

Expect direct feedback. The default is to close PRs that miss the scope of `Non-goals` rather than negotiate.

## Reporting bugs

Open an issue with:

- Reproducer (manifest snippet, command sequence, expected vs actual)
- Claude Code version (`claude --version`)
- Plugin version (`gh release list` or `cat .claude-plugin/plugin.json | jq .version`)
- OS

## Security

See `SECURITY.md`. Do not file security issues as public GitHub issues.
