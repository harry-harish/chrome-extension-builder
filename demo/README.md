# Demo recording script

A 20-second GIF that proves the plugin works. The README links to
`./demo/chrome-extension-builder-demo.gif` — recording lives here.

## Goal

A viewer should understand the plugin in under 20 seconds.

## Recording flow

1. Open Claude Code in a clean project folder.
2. Run, exactly:

   ```text
   /plugin marketplace add harry-harish/chrome-extension-builder
   /plugin install chrome-extension-builder@chrome-extension-builder-marketplace
   /chrome-ext:new "Build a tab manager extension with a popup and keyboard shortcuts"
   ```

3. Show the scaffold landing in the repo (terminal split or quick filetree shot).
4. Show one generated extension surface, preferably the popup UI plus `manifest.json`.
5. Run `/chrome-ext:validate`.
6. End on a successful validation summary or a runnable `pnpm build` output.

## Recording rules

- Under 20 seconds.
- No music.
- No intro card.
- No cursor flourishes.
- 1.25x–1.5x playback if needed.
- Crop tightly so the command and result are visible.

## Caption (for README alt-text or social preview)

> Install the plugin, scaffold a new MV3 extension, validate it, and get a project you can keep building.

## Suggested tools

| Tool | Notes |
|---|---|
| `terminalizer` | npm-installable, produces GIF directly from a YAML recording config. Good for clean reproducible recordings. |
| `vhs` (Charm) | Scriptable terminal recording with a tape file. Best for headless / CI recordings. |
| QuickTime + `gifski` | Manual: screen-record a window, then convert. Best fidelity if you want UI screenshots alongside terminal. |
| `asciinema` + `agg` | Records to `.cast` then converts to GIF. Lightweight. |

## Output

Save the final asset as:

```
demo/chrome-extension-builder-demo.gif
```

The README already references that exact path; no other paths need to change.

## Still screenshot (optional)

If the GIF feels busy, also save a clean post-validation screenshot at
`demo/validation-summary.png` and reference it from the README's
`What it checks` section.
