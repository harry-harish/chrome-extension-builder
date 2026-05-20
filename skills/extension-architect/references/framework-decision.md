# Framework decision matrix (2026)

## TL;DR

**WXT is the default for new Chrome extensions in 2026.** Pick a different framework only when you have a specific reason.

| Framework | Pick when | Don't pick when |
|---|---|---|
| **WXT** | Almost always | (no compelling reason against) |
| Plasmo | Existing Plasmo codebase; need CSUI Shadow DOM | New project; multi-browser non-Chromium; bundle size matters |
| CRXJS | Converting existing Vite project; need its content-script HMR | Need Firefox/Safari; greenfield project |
| Vanilla | <1k LOC; learning; max control | Multi-browser; non-trivial UI; want HMR |

## WXT — the default

- **Bundler**: Vite
- **MV support**: MV3 (with MV2 fallback handled internally)
- **Browsers**: Chrome, Edge, Firefox, Safari
- **HMR**: best-in-class — works for background SW, content scripts, popup, options
- **UI frameworks**: React, Vue, Svelte, Solid, Vanilla (via `@wxt-dev/module-*`)
- **Bundle size**: ~400 KB typical
- **Maintenance**: very active (last npm publish was days before this writing)
- **License**: MIT
- **GitHub**: 9,200+ stars
- **Maintainer**: Aaron Klinker (@aklinker1)
- **URL**: wxt.dev

WXT generates `manifest.json` from `wxt.config.ts` and your file conventions. Entrypoints under `entrypoints/` get auto-discovered. Multi-browser builds are one flag away (`wxt build -b firefox`).

## Plasmo — pick only with reason

- **Bundler**: Parcel
- **MV support**: MV3
- **Browsers**: Chrome, Edge, Firefox (less mature)
- **HMR**: good, but not as fast as WXT
- **UI frameworks**: React-first; Vue/Svelte possible but second-class
- **Bundle size**: ~800 KB typical (40%+ overhead vs WXT)
- **Maintenance**: per WXT's official comparison page, "Appears to be in maintenance mode with little to no maintainers nor feature development happening." Jetwriter AI's migration report corroborates with direct correspondence from the maintainer.
- **License**: MIT
- **GitHub**: ~12.8k stars
- **URL**: plasmo.com

The killer feature is **CSUI** — content-script UI rendered into a Shadow DOM root. If you need that specifically, Plasmo is the best in class.

## CRXJS — Vite plugin, not framework

- **Bundler**: Vite (via plugin)
- **MV support**: Either, you configure
- **Browsers**: Chromium only (Chrome, Edge, Brave). Firefox is manual.
- **HMR**: excellent for content scripts
- **UI frameworks**: any (it's a Vite plugin)
- **Bundle size**: small
- **Maintenance**: slowed release cadence through 2025-2026
- **License**: MIT
- **GitHub**: ~6k stars
- **URL**: crxjs.dev

You keep full control of `vite.config.ts` and `manifest.config.ts`. Best for converting an existing Vite app into an extension.

## Vanilla — for learning or tiny extensions

- No build tooling magic
- Hand-maintain `manifest.json`
- HMR? You write your own
- Cross-browser? Manual
- Best for: <1k LOC extensions, learning the underlying mechanics, or maximum control

## Comparison table

| | WXT | Plasmo | CRXJS | Vanilla |
|---|---|---|---|---|
| Bundler | Vite | Parcel | Vite plugin | none / DIY |
| MV3 | ✅ | ✅ | configurable | configurable |
| Chrome | ✅ | ✅ | ✅ | ✅ |
| Edge | ✅ | ✅ | ✅ | ✅ |
| Firefox | ✅ | partial | manual | manual |
| Safari | ✅ | ❌ | ❌ | manual |
| HMR (SW + content) | ✅ best | partial | ✅ excellent | ❌ |
| File-based entrypoints | ✅ | ✅ | ❌ | ❌ |
| Built-in storage helpers | ✅ (`wxt/storage`) | ✅ (`@plasmohq/storage`) | ❌ | ❌ |
| Built-in messaging | ❌ (DIY) | ✅ (`@plasmohq/messaging`) | ❌ | ❌ |
| Auto-publishing CLI | ✅ | ✅ (BPP) | ❌ | DIY |
| Bundle size (typical) | ~400 KB | ~800 KB | small | varies |
| Active maintenance | ✅ | ⚠️ maintenance mode | ⚠️ slowed | n/a |
| GitHub stars | 9,200 | ~12.8k | ~6k | n/a |

## Decision flowchart

```
Q: New project, no existing extension code?
├─ Yes → WXT (default)
└─ No → existing project:
    ├─ Plasmo? → keep Plasmo unless migrating
    ├─ Vite + React/Vue/Svelte? → add CRXJS plugin
    └─ Vanilla? → consider migrating to WXT for the multi-browser support

Q: Need Firefox or Safari builds?
└─ Yes → WXT (Plasmo and CRXJS are weaker here)

Q: Bundle size <500 KB matters?
└─ Yes → WXT or vanilla (Plasmo's 40% overhead disqualifies it)

Q: Need content-script UI overlays with Shadow DOM isolation?
└─ Yes → Plasmo's CSUI is best-in-class (the one valid reason to pick Plasmo new)

Q: Converting existing Vite app to extension?
└─ Yes → CRXJS
```

## Real-world data points

- **Jetwriter AI** published a Plasmo→WXT migration in 2025 reporting: their build ZIP went from 700 KB (Plasmo) to 400 KB (WXT) — a 43% reduction.
- **ExtensionBooster's 2026 benchmark** confirmed the general pattern: "A typical Plasmo extension compiles to ~800 KB compared to ~400 KB for the equivalent WXT extension."
- **Socket.dev's npm analysis** of WXT's React module: 133,730 weekly downloads (`@wxt-dev/module-react`).
- **The wxt.dev official comparison page** describes Plasmo as in maintenance mode (note: it's a competitor, so cross-reference with Plasmo's commit activity).

## When to revisit this decision

- If Plasmo's maintainer publishes a major release or new maintainer announcement, reconsider for projects where Plasmo's strengths (CSUI) matter.
- If WXT introduces a breaking change you can't accept, the migration to a hand-rolled Vite + CRXJS setup is feasible because WXT's file conventions map cleanly to manual setups.
- If your team has zero React/Vue/Svelte experience and writes plain TS, consider Extension.js as an alternative to WXT (zero-config CLI; less ecosystem but simpler mental model).
