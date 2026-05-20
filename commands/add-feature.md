---
description: Add a surface (popup, options, side panel, content script, devtools panel, background handler) to an existing Chrome extension.
argument-hint: "<surface> e.g. popup, options, side-panel, content, devtools, background-handler"
---

# /chrome-ext:add-feature — Add a feature to an existing extension

Add a new surface or feature to the Chrome extension in the current directory. The requested surface is: `$ARGUMENTS`.

## Procedure

1. **Detect framework** by reading `package.json`:
   - `wxt` in deps → WXT (use `entrypoints/<name>/`).
   - `plasmo` in deps → Plasmo (use root-level files).
   - `@crxjs/vite-plugin` in deps → CRXJS.
   - None of the above → vanilla (manual manifest edits).

   Report what you detected; ask the user to confirm if ambiguous.

2. **Identify the surface** the user requested. Match against:
   - `popup` — toolbar popup UI
   - `options` — options page
   - `side-panel` — Chrome side panel (MV3 only, requires `sidePanel` permission)
   - `content` — content script
   - `devtools` — devtools panel
   - `background-handler` — new message handler in the background SW
   - `new-tab` — new-tab override

3. **Load the relevant framework skill** if not already loaded. Refer to its `references/entrypoints.md`.

4. **Scaffold the surface**:
   - **WXT**: create `entrypoints/<name>/index.{tsx,ts}` and any associated `entrypoints/<name>.content.ts` for content scripts. Update the entrypoint's frontmatter `defineContentScript({ matches: [...] })` for content scripts.
   - **Plasmo**: create `<name>.tsx` (popup) or `contents/<name>.ts` (content) at project root.
   - **CRXJS**: create `src/<name>/<name>.tsx` and update `manifest.config.ts`.
   - **Vanilla**: create the HTML/JS files under `src/` and patch `manifest.json` to declare the surface.

5. **Wire up message passing**: if the new surface needs to communicate with the background SW or other surfaces, extend the typed `messages.ts` and the dispatcher in the background. Do not introduce stringly-typed actions.

6. **Add `_locales` entries**: if the surface has user-visible strings, add them to `_locales/en/messages.json` with `__MSG_<key>__` references in the HTML/TSX.

7. **Run the auditor** (`manifest-auditor` subagent) to verify the modified manifest is still MV3-compliant and permissions haven't widened unnecessarily.

8. **Update tests**: add a smoke test for the new surface in `tests/<name>.spec.ts` using the Playwright pattern from `skills/extension-testing/scripts/smoke.spec.ts`.

## Surface-specific notes

- **popup**: keep the React tree small; popups close on click-outside and reset state. Persist anything important to `chrome.storage.session`.
- **options**: full-page React; use `chrome.storage.sync` so settings sync across browsers.
- **side-panel**: requires `"side_panel": { "default_path": "..." }` in manifest and the `sidePanel` permission. Per-tab side panels need `chrome.sidePanel.setOptions` calls.
- **content**: pick the narrowest `matches` pattern possible. Default to `"run_at": "document_idle"`; only use `document_start` if you must beat the page's JS.
- **devtools**: requires the secure injected-page-script pattern under MV3. See `skills/extension-security/references/devtools-injection.md`.
- **background-handler**: don't grow the SW into a doer — make handlers delegate to controllers in `src/controllers/`.

## Output

Print a summary of files created/modified, the new manifest diff, and a "next steps" list (run dev, test the surface manually, write the smoke test, run `/chrome-ext:validate`).
