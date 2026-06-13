# Pre-launch audit — verified findings

**Date:** 2026-06-13 · **Discovery:** 4-dimension adversarial workflow (29 agents) · **Plugin:** v1.3.1 (`8565827`)
**Verified actionable: 16** · Confirmed-clean: 2 (WXT, vanilla) · Refuted false positives: 7 (incl. "React 19 from ^18.3.0" — semver-impossible, and "vite@latest broken" — works at vite 8.x).

Work-list for Phase 2, severity order. Each fix: reproduce → fix → verify → CI-green → mark resolved.

---

## BLOCKER

### B1 — Publish safety hook guards a nonexistent flag; real live-publish bypasses it — ✅ RESOLVED
**Fixed:** hook rewritten (allows only `upload` draft subcommand; blocks `publish`/bare unless `CONFIRM_PUBLISH_LIVE=1`) and verified against 11 real invocations; publish.md/SKILL.md/github-actions.md/oauth-setup.md updated to the v4 CLI + env-var auth, `dlx` pinned to `@4`. L2 resolved by the same anchored pattern.

**Verified directly against `chrome-webstore-upload-cli@4.0.1`.** The tool has **no `--auto-publish` flag**. Its CLI: `chrome-webstore-upload [upload|publish]`; **with no subcommand it does upload + publish (live)**. So:
- `commands/publish.md` + `extension-publishing/SKILL.md` document `--auto-publish` (and `--client-id`/`--client-secret`/`--refresh-token` flags, now env-vars) → users' publish flow errors out.
- **`hooks/hooks.json` PreToolUse guards `--auto-publish`** → guards a flag that doesn't exist. The real live-publish paths (`chrome-webstore-upload publish`, bare `chrome-webstore-upload`) are **not blocked**. The guard provides false safety.
- **Fix:** Rewrite the PreToolUse guard to block the real live-publish invocations — `chrome-webstore-upload(-cli)?` when the command is `publish` OR has no subcommand — unless `CONFIRM_PUBLISH_LIVE=1`; allow the `upload` (draft) subcommand. Update publish.md + SKILL.md + the GitHub Actions template to the real `upload`/`publish` CLI and env-var auth (`EXTENSION_ID`/`CLIENT_ID`/`CLIENT_SECRET`/`REFRESH_TOKEN`).

### B2 — Plasmo scaffold produces a non-installable project (upstream) — ✅ RESOLVED (document + warn + workaround)
**Fixed:** `plasmo-framework/SKILL.md` + `commands/new.md` Phase 3 now carry an upstream-breakage warning, the `pnpm pkg set dependencies.plasmo=latest` workaround, and explicit steering to WXT for new projects (existing-Plasmo users are unaffected). Upstream bug itself can't be fixed here.

`pnpm create plasmo` (create-plasmo v0.90.5) generates `package.json` with `"plasmo": "workspace:*"`, so `pnpm install` fails with `ERR_PNPM_WORKSPACE_PKG_NOT_FOUND`. The `/chrome-ext:new` → Plasmo path is broken end-to-end. This is an **upstream create-plasmo bug** we can't fix directly.
- **Fix:** In `plasmo-framework/SKILL.md` + `commands/new.md` Phase 3, document the known breakage + the workaround (`pnpm pkg set dependencies.plasmo=latest` then install, or `npm install`), and steer new projects to WXT (consistent with the existing "Plasmo is in maintenance mode" note). Decide: document-and-warn vs de-emphasize the Plasmo path.

---

## HIGH

### H1 — `validate-csp.sh` violates the exit-code contract — ✅ RESOLVED
**Fixed:** `exit $((critical > 0 ? 1 : 0))`; verified bad→1, good→0.

`validate-csp.sh:103` does `exit "$critical"` → exits with the raw count (e.g. 3) instead of 1. Breaks the documented "exit 1 if any critical" contract and is inconsistent with the other validators (and the hook's `rc!=0` check still works, but anything keying on exit==1 breaks).
- **Fix:** `exit $((critical > 0 ? 1 : 0))`.

### H2 — CRXJS scaffold is incomplete → TS build fails — ✅ RESOLVED
**Fixed:** scaffold now adds `@types/chrome`, a "Complete the TypeScript + i18n setup" section adds `"types": ["chrome"]` to `tsconfig.app.json`.

Following `crxjs-vite/SKILL.md` exactly yields `TS2304: Cannot find name 'chrome'`. Missing: `@types/chrome` devDep, `"chrome"` in `tsconfig.app.json` types, and the `_locales/en/messages.json` setup.
- **Fix:** Add those three steps to the skill's scaffold section.

### H3 — CRXJS `_locales` not copied to build → validator warning — ✅ RESOLVED
**Fixed:** setup section now creates `public/_locales/en/messages.json` with the referenced `__MSG_*__` keys; clarified `_locales` is the `public/` exception.

CRXJS doesn't copy `_locales/` to `dist/`; `default_locale` is set but `_locales/` is absent in the build → validator warns.
- **Fix:** Document putting `_locales/` in `public/` (or drop `default_locale` from the template).

### H4 — Windows: bash scripts block non-WSL users — ✅ RESOLVED (documented)
**Fixed:** README Runtime requirements + Known rough edges now state the WSL/Git Bash requirement. Full Node port deferred post-launch (tracking issue not filed — needs user authorization for the external write; see phase-boundary note).

`/chrome-ext:new`, `validate`, `publish` invoke `bash …/*.sh`. Windows users without WSL/Git Bash hit `bash: command not found` — entire workflows blocked. Undocumented.
- **Fix (scope TBD):** At minimum document the WSL/Git Bash requirement in README + runtime requirements. (Full Node port of the scripts is larger; decide scope.)

### H5 — Windows: `build-zip.sh` needs `zip` — ✅ RESOLVED (documented)
**Fixed:** the `zip` requirement is called out in README Runtime requirements alongside the bash requirement; cross-platform archiver folded into the deferred Node-port item.

`build-zip.sh` vanilla/CRXJS branches call bare `zip` → fails on Windows without zip. (WXT/Plasmo use framework-native zip.)
- **Fix:** Document the `zip` requirement, or add a PowerShell/archiver fallback. Pairs with H4 (Windows requirements doc).

---

## MEDIUM

### M1 — `wxt@latest` floating in the interactive scaffold docs — ✅ RESOLVED
**Fixed:** `commands/new.md` + `wxt-framework/SKILL.md` interactive `dlx` calls pinned to `wxt@~0.20.26`; SKILL.md line 209 doc bug corrected (scaffold writes files directly, not `wxt init`).

`commands/new.md:118` + `wxt-framework/SKILL.md:21` use `dlx wxt@latest init`; `scaffold-wxt.sh` already pins `~0.20.26`. Also SKILL.md ~line 209 wrongly says scaffold-wxt.sh uses `@latest`. Future WXT minor could break the interactive path (the `wxt/sandbox` removal is the precedent).
- **Fix:** Pin the documented `dlx` calls to `wxt@~0.20.26`; fix the SKILL.md doc bug; document the minimum tested version.

### M2 — CRXJS skill recommends `@crxjs/vite-plugin@beta` (outdated) — ✅ RESOLVED
**Fixed:** scaffold now uses `@crxjs/vite-plugin@^2.6` with a note explaining why not `@beta`.

`@beta` resolves to `2.0.0-beta.33`; stable `2.6.1` exists.
- **Fix:** Recommend `@crxjs/vite-plugin@^2.6` (or `@latest`).

### M3 — `wxt init --template` minimum version undocumented — ✅ RESOLVED
**Fixed:** `~0.20.26` documented as the minimum tested version next to the interactive `wxt init` snippet (folded into M1).

Primary docs recommend `@latest` without stating the minimum tested version; fallback note exists but doesn't pin.
- **Fix:** Document `~0.20.26` as the minimum tested; folds into M1.

### M4 — Icon pixel dimensions not validated (coverage gap) — ✅ RESOLVED
**Fixed:** `validate-manifest.py` now reads PNG IHDR (stdlib `struct`, no Pillow) and WARNs when an icon's dimensions don't match its declared size key, for both `icons.*` and `action.default_icon.*`. Verified 64×64-declared-48 → WARNING, correct 128 → silent.

`validate-manifest.py` checks icon file existence but not dimensions; wrong-size icons pass locally, fail at CWS upload. (Tracked as issue #2.)
- **Fix:** Add a stdlib PNG-IHDR dimension check (no Pillow dep) emitting a WARNING on mismatch.

### M5 — Host-permission match-pattern syntax not validated (coverage gap) — ✅ RESOLVED
**Fixed:** `validate-permissions.py` adds `is_valid_match_pattern()` and WARNs on malformed patterns in `host_permissions`, `optional_host_permissions`, and content-script `matches`. Unit-tested against 7 valid + 7 invalid patterns.

`validate-permissions.py` only string-matches known broad patterns; malformed patterns like `**invalid**` pass silently.
- **Fix:** Validate host patterns against Chrome's match-pattern spec, or document the limit.

---

## LOW

### L1 — declarativeNetRequest rule-count limit not validated
No validator counts DNR rules vs Chrome's 30,000/ruleset limit; only fails at runtime. Fix: add a warning, or document.

### L2 — `--auto-publish` grep false-positives (moot after B1)
The PreToolUse pattern matches the string inside `echo`/comments. B1's rewrite should anchor to actual command position, resolving this too.

### L3 — No centralized agent-capability matrix (doc debt)
Grants are correct (architect no Bash/Write; auditor & test-runner no Edit/Write) but require reading three files to verify. Fix: add a capability table to README or AGENTS.md.

---

## Notes
- Confirmed-clean: WXT scaffold+build (both paths) and the vanilla template + validators (with correct-dimension icons).
- Refuted: web-ext@latest unpinned (stable 8–10); vite@latest (works at 8.x); Plasmo unversioned (scope); better-npm-audit; React ^18.3.0→19 (semver-impossible); Node/Python min-version runtime failure (works on 3.8, doc-accuracy only).
