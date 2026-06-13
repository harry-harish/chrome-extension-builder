# Pre-launch deep audit — design

**Date:** 2026-06-13
**Plugin:** chrome-extension-builder v1.3.1 (HEAD `8565827`)
**Goal:** Surface and fix latent issues before wider launch, and add CI guardrails so the same classes can't regress. Driven by the pattern that the same failure mode (a schema/runtime/API mismatch slipping past checks) has bitten this plugin three times already (userConfig.enum, hooks wrapper, wxt/sandbox).

## Why now

We've verified the WXT scaffold+build and the vanilla-template validators end-to-end this session. We have NOT verified: Plasmo/CRXJS scaffold+build, dependency-drift exposure across non-WXT frameworks, validator false-pass/false-miss behavior under adversarial input, or Windows execution of the bundled scripts. Each is a plausible "issue later." This audit closes those gaps.

## Method

Hybrid, three stages:

1. **Parallel adversarial discovery (multi-agent workflow).** One auditor per dimension runs concurrently; each finding is checked by an independent skeptic agent before it's accepted, to kill false positives. Output: a verified, deduplicated findings list with severity + repro.
2. **Sequential remediation.** Fix each confirmed finding with a real build/verify loop (no parallel code edits), each behind a green CI run, versioned per `RELEASING.md`.
3. **CI hardening.** Add guardrail jobs so every fixed class is enforced going forward.

Rejected alternatives: fully-sequential manual audit (weaker coverage, no independent verification); workflow-does-everything-including-fixes (fixes need iterative rebuild loops that don't parallelize and must pass the CI gate individually).

## Scope — four dimensions

### D1. User-facing breakage across all four frameworks
For **WXT (re-confirm), Plasmo, CRXJS, vanilla MV3**, against *current* upstream package versions:
- Run the scaffold path the plugin actually uses (interactive `wxt init` / `pnpm create plasmo` / the CRXJS skill flow / vanilla template copy), plus the bundled non-interactive helpers where they exist.
- `pnpm install` → `pnpm build` → run the bundled validators + `web-ext lint --target chrome` on the built output.
- Each framework either passes clean or yields a captured, reproducible failure.
- Explicitly check whether Plasmo/CRXJS guidance or scaffolds reference APIs at risk of the same `wxt/sandbox`-style removal.

### D2. Dependency drift / future-proofing
- Enumerate every external dependency the plugin **pins** (in `scaffold-wxt.sh`'s generated `package.json`, any other generated manifests, skill-doc snippets) or **invokes** via `dlx`/`npx`: `wxt`, `plasmo`, `crxjs`/`@crxjs/vite-plugin`, `web-ext`, `playwright`, `chrome-webstore-upload-cli`.
- Flag floating `^`/unpinned ranges on fast-moving packages; recommend defensive pins (the `^0.20.0`→0.20.26 drift is the reference failure).
- For `dlx`-invoked tools, confirm the cited commands/flags still exist (e.g. `web-ext lint --no-config-discovery`, `chrome-webstore-upload-cli ... --auto-publish`).

### D3. Validator correctness (false pass / false miss)
- **Known-bad fixtures:** a manifest carrying each MV3 violation the validators claim to catch (MV2 version, unsafe-eval, unsafe-inline, remote script-src, `<all_urls>`, `webRequestBlocking`, MV2-form CSP/web_accessible_resources, missing referenced files for every surface) → assert each is caught with a critical and nonzero exit.
- **Known-good fixture:** a clean MV3 manifest → assert zero critical, no false flags.
- **Coverage-gap pass:** enumerate MV3 violations the validators do NOT currently check (icon pixel dimensions [issue #2], declarativeNetRequest rule limits, `web_accessible_resources` match scoping, `options_ui`/`side_panel`/`devtools_page` edge cases) and decide which to add.
- Confirm the critical→exit≥1 contract holds for all validators (the `audit-deps.sh` exit-0-on-critical bug is the reference failure).

### D4. Security/safety + cross-platform
- Re-audit the three hook commands for shell-injection via crafted file paths, the `--auto-publish` gate bypass surface, and the `python3 -c` stdin-parse robustness.
- Confirm agent tool grants at HEAD: `extension-architect` no Bash/Write; `manifest-auditor` and `extension-test-runner` no Edit/Write.
- Flag Windows gaps: the bundled `.sh` scripts assume bash; document or mitigate for Windows-without-WSL users. Confirm the `.py` validators are cross-platform.
- Sanity-check supply-chain guidance (`audit-deps.sh`, LavaMoat references).

## Remediation policy
Fix every confirmed finding. Each fix: edit → local build/validate → commit → push → CI green → (version bump + release if user-facing) per `RELEASING.md`. Cosmetic/doc findings batched; behavior changes individually gated.

## CI guardrails added
1. **Per-framework matrix job** — scaffold + `pnpm build` + validators + `web-ext lint` for WXT/Plasmo/CRXJS/vanilla. Fails if any framework's generated project doesn't build clean.
2. **Dependency-drift check** — a script that fails CI on floating ranges in generated templates / scaffold scripts for the fast-moving packages.
3. **Adversarial validator fixtures** — the known-bad/known-good fixture suite from D3, asserting expected critical counts, run on every PR.

## Success criteria
- All four frameworks scaffold + build + validate clean against current upstream.
- No floating ranges on fast-moving deps in anything the plugin generates.
- Validators catch every known-bad fixture and pass every known-good; all validators honor the critical→nonzero-exit contract.
- Hooks pass shell-injection/bypass checks; agent tool grants confirmed minimal; Windows gaps documented or mitigated.
- The three CI guardrail jobs are live and green, so each fixed class is regression-protected.

## Out of scope
- New plugin features or commands.
- Non-Chrome store flows beyond what already exists (Firefox/Edge/Safari remain secondary).
- The `@claude-community` SHA-pin lag (external to the repo; tracked in community#33).

## Risks / notes
- Plasmo/CRXJS scaffolds pull their own latest versions at run time, so D1 results are a point-in-time snapshot; the CI matrix job (guardrail 1) is what keeps it honest over time.
- Some D1 framework builds need network (pnpm install); CI already has network, local runs need it too.
- If D1 surfaces multiple framework breaks, remediation could be sizable; findings will be severity-ranked so launch-blockers are fixed first.
