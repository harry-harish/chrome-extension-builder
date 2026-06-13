# Pre-launch Deep Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Find and fix latent issues across all four framework paths, dependency drift, validator correctness, and hook/agent security — then add CI guardrails so each class is regression-protected before launch.

**Architecture:** Three phases. Phase 1 runs a parallel adversarial discovery workflow (one auditor per dimension, each finding verified by a skeptic) producing a verified findings doc. Phase 2 fixes confirmed findings sequentially, each behind a green CI run. Phase 3 adds three CI guardrail jobs (per-framework build matrix, dependency-drift check, adversarial validator fixtures) so the fixed classes can't regress.

**Tech Stack:** bash + python validators, `vhs`/`ffmpeg` (n/a here), GitHub Actions, `pnpm`/`wxt`/`plasmo`/`@crxjs/vite-plugin`, `web-ext`, `claude plugin validate`/`install`. Spec: `docs/superpowers/specs/2026-06-13-plugin-pre-launch-audit-design.md`.

---

## File structure

| Path | Responsibility | Phase |
|---|---|---|
| `docs/superpowers/audit/findings.md` (Create) | Verified findings from the discovery workflow (the input to Phase 2) | 1 |
| Various plugin files (Modify) | Per-finding fixes; exact files determined by findings | 2 |
| `tests/fixtures/manifests/` (Create) | Known-bad + known-good manifest fixtures for validator assertions | 3 |
| `tests/run-validator-fixtures.sh` (Create) | Asserts each fixture produces the expected critical count / exit code | 3 |
| `tests/check-dependency-drift.sh` (Create) | Fails on floating ranges for fast-moving deps in generated templates/scaffolds | 3 |
| `.github/workflows/validate.yml` (Modify) | Add 3 guardrail jobs: `framework-matrix`, `dependency-drift`, `validator-fixtures` | 3 |
| `CHANGELOG.md` / `.claude-plugin/plugin.json` (Modify) | Version bump if any fix is user-facing | 2 |

Existing CI jobs (do not duplicate): `plugin-validate`, `validators`, `plugin-install`, `shell-syntax`.

---

## Phase 1 — Discovery (adversarial workflow)

### Task 1: Run the 4-dimension discovery workflow

**Files:**
- Create: `docs/superpowers/audit/findings.md` (workflow output, hand-written from results)

- [ ] **Step 1: Launch the discovery workflow**

Invoke the Workflow tool with a script that fans out one auditor per spec dimension and verifies each finding with an independent skeptic. Structure:

```
Phase 'Discover': parallel auditors, each returns FINDINGS_SCHEMA
  - D1 cross-framework: for plasmo, crxjs, vanilla (+ re-confirm wxt) — scaffold, pnpm install,
    pnpm build, run bundled validators + web-ext lint; report each PASS or a captured repro.
    (Agent has Bash; runs real installs in a temp dir.)
  - D2 dependency-drift: enumerate pinned/dlx-invoked deps across scaffold-wxt.sh, skill docs,
    commands/*.md; flag floating ^ ranges on wxt/plasmo/crxjs/@crxjs/web-ext/playwright/
    chrome-webstore-upload-cli; check cited flags still exist.
  - D3 validator-correctness: craft known-bad manifests (one per MV3 violation class) + a clean
    one; run each validator; report any false-pass (violation not caught) or false-fail, and
    coverage gaps (violations not checked at all); confirm critical->exit>=1 for every validator.
  - D4 security/cross-platform: re-audit the 3 hook commands for shell-injection via crafted
    paths + the --auto-publish bypass; confirm agent tool grants at HEAD; flag .sh Windows gaps.
Phase 'Verify': for each finding, an independent skeptic agent tries to REFUTE it (repro it or
  show it's a non-issue). Keep only findings that survive.
Return: {findings: [...verified...]} with severity (blocker/high/medium/low), repro, fix-hint.
```

Each finding's schema: `{dimension, severity, title, repro, affected_files, fix_hint, verified}`.

- [ ] **Step 2: Write the verified findings to `docs/superpowers/audit/findings.md`**

Transcribe the workflow's verified findings into a severity-ranked table: `# | dimension | severity | title | repro | affected files | fix`. Blockers first. This file is the work-list for Phase 2.

- [ ] **Step 3: Commit the findings**

```bash
git add docs/superpowers/audit/findings.md
git commit -m "Audit: discovery findings (4 dimensions, adversarially verified)"
git push origin main
```

- [ ] **Step 4: Triage gate**

If zero blocker/high findings: skip to Phase 3 (guardrails still add value). Otherwise proceed to Phase 2, fixing in severity order.

---

## Phase 2 — Remediation (per-finding protocol)

> Findings are not known until Phase 1 completes, so Phase 2 is a **repeated protocol**, not fixed code. Instantiate one task per finding from `findings.md`, in severity order. The worked example below is the exact shape (modeled on the real v1.3.1 `wxt/sandbox` fix).

### Task 2.x: Fix finding #x — `<title>`

**Files:** per the finding's `affected_files`.

- [ ] **Step 1: Reproduce the finding**

Run the finding's `repro` command and confirm the documented failure. Example (wxt/sandbox-class):
```bash
bash demo/video/setup-demo-ext.sh /tmp/aud && cd /tmp/aud/... && pnpm build
# Expected: the exact error from findings.md (e.g. `"./sandbox" is not exported`, rc=1)
```
If it does NOT reproduce, mark the finding stale in `findings.md` and skip.

- [ ] **Step 2: Apply the minimal fix**

Edit only the `affected_files`. Show the change inline in the per-finding task when instantiated. Example shape:
```
# scaffold-wxt.sh / SKILL.md / references:
#   import { defineBackground } from 'wxt/sandbox'  ->  'wxt/utils/define-background'
#   pin "wxt": "^0.20.0"  ->  "~0.20.26"
```

- [ ] **Step 3: Verify the fix locally**

Re-run the Step 1 repro; expect success (rc=0). For validator findings, run the relevant fixture. For scaffold findings, run scaffold → `pnpm install` → `pnpm build` and confirm a built `manifest.json`.
```bash
shellcheck --severity=warning <any-changed-.sh>   # CI gate
claude plugin validate .                           # marketplace schema
```

- [ ] **Step 4: Bump version + changelog if user-facing**

Per `RELEASING.md`: if the fix changes generated output or runtime behavior, bump `.claude-plugin/plugin.json` patch version and add a `CHANGELOG.md` entry. Doc-only/CI-only fixes skip the bump.

- [ ] **Step 5: Commit + push + wait for CI green**

```bash
git add <files>
git commit -m "Fix: <finding title> (audit #x)"
git push origin main
gh run watch --exit-status "$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')"
```
Do not start the next finding until CI is green.

- [ ] **Step 6: Mark the finding resolved in `findings.md`, commit that.**

(Repeat Task 2.x for each finding. Batch cosmetic/doc-only fixes into one commit; gate behavior changes individually.)

- [ ] **Final Phase-2 step: cut a release** if any user-facing fixes shipped, per `RELEASING.md` (tag + `gh release create`).

---

## Phase 3 — CI guardrails

### Task 3: Adversarial validator fixtures

**Files:**
- Create: `tests/fixtures/manifests/clean/manifest.json` + icons
- Create: `tests/fixtures/manifests/bad-*.json` (one per violation class)
- Create: `tests/run-validator-fixtures.sh`
- Test: the script self-asserts

- [ ] **Step 1: Write the known-good fixture**

`tests/fixtures/manifests/clean/manifest.json` — copy the vanilla template manifest; generate correct-dimension icons via the stdlib PNG writer from `demo/video/setup-demo-ext.sh`.

- [ ] **Step 2: Write known-bad fixtures (one per class)**

```
bad-mv2.json            : "manifest_version": 2
bad-unsafe-eval.json    : content_security_policy.extension_pages with 'unsafe-eval'
bad-unsafe-inline.json  : ... 'unsafe-inline'
bad-remote-csp.json     : ... https://cdn.example.com in script-src
bad-all-urls.json       : host_permissions ["<all_urls>"]
bad-webrequestblocking.json : permissions ["webRequestBlocking"]
bad-mv2-war.json        : web_accessible_resources as string array
bad-missing-file.json   : action.default_popup -> nonexistent.html
```

- [ ] **Step 3: Write `tests/run-validator-fixtures.sh`**

Asserts each bad fixture yields ≥1 critical and nonzero exit from the relevant validator, and the clean fixture yields 0 critical / exit 0. Uses canonical `/private/tmp` paths and stdlib-PNG icons (lessons from this session). Emits a PASS/FAIL summary, exits nonzero on any mismatch.

- [ ] **Step 4: Run it locally; expect all PASS**

```bash
bash tests/run-validator-fixtures.sh
# Expected: "N/N fixtures asserted correctly", exit 0
```
(If any bad fixture is NOT caught, that's itself a Phase-2 finding — fix the validator, then this passes.)

- [ ] **Step 5: shellcheck + commit**

```bash
shellcheck --severity=warning tests/run-validator-fixtures.sh
git add tests/ && git commit -m "Add adversarial validator fixtures"
```

### Task 4: Dependency-drift check

**Files:**
- Create: `tests/check-dependency-drift.sh`

- [ ] **Step 1: Write the script**

Greps generated `package.json`s and `scaffold-wxt.sh` for the fast-moving deps (`wxt`, `react`, `@wxt-dev/*`, and any Plasmo/CRXJS pins added in Phase 2); fails if any uses a floating `^`/`*`/`latest` range instead of a pinned `~x.y.z` or exact version. Allowlist may exempt deps that are intentionally floated (none expected).

- [ ] **Step 2: Run locally; expect PASS (Phase 2 already pinned wxt)**

```bash
bash tests/check-dependency-drift.sh
# Expected: "no floating ranges on fast-moving deps", exit 0
```

- [ ] **Step 3: shellcheck + commit**

```bash
shellcheck --severity=warning tests/check-dependency-drift.sh
git add tests/check-dependency-drift.sh && git commit -m "Add dependency-drift CI check"
```

### Task 5: Per-framework build matrix + wire all guardrails into CI

**Files:**
- Modify: `.github/workflows/validate.yml`

- [ ] **Step 1: Add a `framework-matrix` job**

A matrix over `[wxt, plasmo, crxjs, vanilla]`: install Claude Code CLI + pnpm + Node, scaffold each framework via the plugin's real path, `pnpm install`, `pnpm build` (vanilla: zip/validate), then run the bundled validators + `web-ext lint --target chrome` on the output. Job fails if any framework's generated project doesn't build clean. (Plasmo/CRXJS pull current upstream, so this is the standing guard against the next `wxt/sandbox`-class drift.)

- [ ] **Step 2: Add `validator-fixtures` + `dependency-drift` jobs**

Two jobs that run `bash tests/run-validator-fixtures.sh` and `bash tests/check-dependency-drift.sh` respectively on ubuntu-latest with Python 3.11.

- [ ] **Step 3: Push and confirm all jobs green**

```bash
git add .github/workflows/validate.yml
git commit -m "CI: add framework-matrix, validator-fixtures, dependency-drift guardrails"
git push origin main
gh run watch --exit-status "$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run view "$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')" --json jobs \
  --jq '.jobs[] | "\(.conclusion)  \(.name)"'
# Expected: all jobs success
```

- [ ] **Step 4: Update `RELEASING.md`** to reference the new guardrail jobs in the pre-flight checklist.

---

## Success criteria (from spec)
- [ ] All four frameworks scaffold + build + validate clean against current upstream (`framework-matrix` green).
- [ ] No floating ranges on fast-moving deps (`dependency-drift` green).
- [ ] Validators catch every known-bad fixture and pass the known-good (`validator-fixtures` green); all validators honor critical→exit≥1.
- [ ] Hooks pass shell-injection/bypass checks; agent grants confirmed minimal; Windows gaps documented (from Phase 1 D4, fixed in Phase 2).
- [ ] All three guardrail jobs live and green.

## Self-review notes
- Spec coverage: D1→Task1(D1)+Task5; D2→Task1(D2)+Task4; D3→Task1(D3)+Task3; D4→Task1(D4)+Phase2. All four dimensions have discovery + guardrail tasks.
- Remediation is finding-dependent by nature; the protocol (Task 2.x) is concrete and the worked example is the real wxt/sandbox fix. This is intentional, not a placeholder.
- Type/name consistency: fixture filenames, script paths, and CI job names match across tasks.
