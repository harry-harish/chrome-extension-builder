---
description: Run all validators on the current Chrome extension directory — manifest schema, permissions, CSP, web-ext lint.
argument-hint: "[optional path to extension root, defaults to cwd]"
---

# /chrome-ext:validate — Validate current extension

Validate the Chrome extension in `$ARGUMENTS` (defaults to current directory).

## Procedure

1. **Locate `manifest.json`**:
   - For raw extensions: `./manifest.json`.
   - For WXT projects: `.output/chrome-mv3/manifest.json` (after `pnpm build`).
   - For Plasmo: `build/chrome-mv3-prod/manifest.json` (after `pnpm build`).
   - For CRXJS: `dist/manifest.json` (after `pnpm build`).

   If no built manifest exists, ask whether to run the build first.

2. **Dispatch the `manifest-auditor` subagent** (read-only tools) with the manifest path. The auditor runs:

   ```bash
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/extension-architect/scripts/validate-manifest.py "$MANIFEST"
   python3 ${CLAUDE_PLUGIN_ROOT}/skills/extension-security/scripts/validate-permissions.py "$MANIFEST"
   bash   ${CLAUDE_PLUGIN_ROOT}/skills/extension-security/scripts/validate-csp.sh "$MANIFEST"
   bash   ${CLAUDE_PLUGIN_ROOT}/skills/extension-testing/scripts/lint-extension.sh "$EXTENSION_DIR"
   bash   ${CLAUDE_PLUGIN_ROOT}/skills/extension-publishing/scripts/check-store-readiness.sh "$EXTENSION_DIR"
   ```

3. **Aggregate and report**:

   ```
   Validation summary for: <path>
   
   ✗ Critical: <N>
   ⚠ Warnings: <M>
   ℹ Info: <K>
   
   Critical issues:
   - <file:line> — <message>
   ...
   
   Warnings:
   - <file:line> — <message>
   ...
   ```

4. **Offer fixes**: for each critical issue, suggest the minimal patch (manifest_version bump, permission narrowing, CSP tightening). Apply only those the user authorizes.

## Definitions

- **Critical**: blocks Chrome Web Store submission or fails `addons-linter`. Includes `manifest_version: 2`, missing required fields, invalid CSP directives, references to nonexistent files.
- **Warning**: deviates from a best practice but won't block submission. Includes `<all_urls>` without justification, missing `_locales/`, missing icons at all standard sizes, missing privacy disclosures.
- **Info**: opportunity for improvement (e.g., "consider `chrome.activeTab` instead of `host_permissions`").
