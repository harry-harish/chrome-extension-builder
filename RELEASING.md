# Releasing

Steps for cutting a new release without re-running the schema-mismatch saga
that produced v1.0.0 → v1.2.2.

## Pre-flight (do every release, no exceptions)

1. **CI must be green on the commit you're about to tag.**

   ```bash
   gh run list --limit 1 --json status,conclusion,headSha
   ```

   All jobs (`plugin-validate`, `validators`, `plugin-install`,
   `shell-syntax`, `validator-fixtures`, `dependency-drift`, and the
   `framework-matrix` legs) must report `success`. The `plugin-install`
   job is the one that catches schema-mismatch bugs the way the runtime
   does, and `validator-fixtures`/`dependency-drift`/`framework-matrix`
   guard the regression classes fixed in v1.4.0. If any is red,
   **do not tag**.

2. **Fresh install in a clean Claude Code session.** Belt-and-suspenders
   over CI, because the runtime occasionally moves faster than the
   schema CI uses:

   ```bash
   # In a fresh shell:
   mkdir -p ~/cext-release-check && cd ~/cext-release-check
   claude plugin marketplace update chrome-extension-builder-marketplace
   claude plugin install chrome-extension-builder@chrome-extension-builder-marketplace --scope local
   claude plugin uninstall chrome-extension-builder@chrome-extension-builder-marketplace --scope local
   ```

   Both commands must succeed. If `install` prints `Failed to install`,
   `invalid manifest`, or `Unrecognized key` — abort. (Note: the CLI
   exits 0 even on failure, so read the output, not the exit code.)

3. **`/doctor` is clean** on the just-installed copy. Open a Claude Code
   session, run `/doctor`, confirm no plugin errors against
   `chrome-extension-builder`.

4. **`claude plugin validate` passes locally.** Quick sanity check:

   ```bash
   claude plugin validate .
   ```

## Cutting the release

1. Bump `version` in **only** `.claude-plugin/plugin.json`. Do NOT add
   a `version` field to the plugin entry in
   `.claude-plugin/marketplace.json` — that blocks Anthropic's
   community-marketplace auto-bump CI (cf. v1.2.3 changelog and
   [affaan-m/everything-claude-code#37](https://github.com/affaan-m/everything-claude-code/issues/37)).

2. Add a `## [<version>] - YYYY-MM-DD` section to `CHANGELOG.md`.

3. Commit, tag, push:

   ```bash
   git add .claude-plugin/plugin.json CHANGELOG.md
   git commit -m "v<version> — <one-line summary>"
   git push origin main
   git tag -a v<version> -m "v<version> — <summary>"
   git push origin v<version>
   ```

4. Create the GitHub release:

   ```bash
   gh release create v<version> \
     --title "v<version> — <summary>" \
     --notes "$(awk '/^## \[<version>\]/,/^## \[/' CHANGELOG.md | sed '$d')"
   ```

5. **Wait for CI on the tagged commit to go green** before announcing.

## Things NOT to do

- **Never force-push `main`.** The original v1.0.0 commit (`0ad9221`)
  was abandoned by a force-push, and Anthropic's community-marketplace
  pin got stuck on the orphaned commit. GitHub eventually garbage-
  collects unreachable commits, at which point the pinned install
  starts returning 404 instead of just installing the wrong version.
  If history needs to change, do it via revert commits, not rewrites.

- **Never re-use a version number.** Chrome Web Store and `npm`-style
  package managers both refuse the upload. So does Claude Code's cache
  layer in practice — `~/.claude/plugins/cache/<plugin>/<version>/`
  paths conflict.

- **Never put a `version` field on the plugin entry in
  `marketplace.json`.** It blocks auto-update detection. The plugin's
  own `plugin.json` is the single source of truth for version.

- **Never trust `claude plugin validate` as the only pre-publish
  check.** It's accepted broken manifests on this plugin twice
  (`userConfig.enum` in v1.0.0 → v1.1.1; missing `hooks` wrapper in
  v1.2.0 → v1.2.2). The CI `plugin-install` job and the manual
  fresh-install step are the real gates.

## If a release goes out broken anyway

1. Cut a patch release with the fix as fast as possible. Don't try to
   delete/retract the tag — pinned consumers may already have the bad
   SHA.
2. Update `CHANGELOG.md` with the fix and how to recover (e.g.,
   `/plugin marketplace update` + reinstall).
3. If the `@claude-community` pin is on the broken SHA, comment on
   [anthropics/claude-plugins-community#33](https://github.com/anthropics/claude-plugins-community/issues/33)
   asking for a manual SHA bump.
