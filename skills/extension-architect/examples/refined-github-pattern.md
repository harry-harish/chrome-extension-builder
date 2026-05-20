# Refined GitHub pattern — feature-module architecture

## Source

`refined-github/refined-github` on GitHub. ~31k stars, MIT, TypeScript. ~100+ self-contained features.

## What to copy

Refined GitHub's `source/features/` directory contains 100+ files, each one a self-contained "feature." Every feature exports an `init` function and metadata describing when it should run. The entry point (`source/refined-github.ts`, ~225 lines) iterates over the features and activates the matching ones.

```ts
// source/features/highlight-collaborators.tsx
import features from '../feature-manager';
import * as pageDetect from 'github-url-detection';

function init(signal: AbortSignal): void {
  observe('.js-issue-title', (element) => {
    if (isCollaborator(...)) {
      element.classList.add('rgh-collaborator-highlight');
    }
  }, { signal });
}

void features.add(import.meta.url, {
  include: [pageDetect.isIssue, pageDetect.isPR],
  init,
});
```

## Why it works

1. **Bounded blast radius.** A buggy feature can only break itself; it can't take down the whole extension.
2. **Cheap to delete.** When a feature becomes obsolete (GitHub ships native support), delete the one file.
3. **Easy to test.** Each feature has its own activation predicate and init function.
4. **URL-detection factoring.** `github-url-detection` is factored out as a standalone npm package (`pageDetect.isIssue`, `pageDetect.isPR`, etc.). Reusable across the codebase and the wider ecosystem.
5. **AbortSignal lifecycle.** Each feature gets an `AbortSignal` it must respect for cleanup. URL changes (GitHub is a SPA) cancel old signals and run new init.

## Adaptation for your extension

```
src/
├── features/
│   ├── feature-a.ts
│   ├── feature-b.ts
│   └── feature-c.tsx
├── feature-manager.ts
├── content.ts                # entry: iterate features, dispatch to matching
└── lib/
    ├── url-detection.ts      # your version of pageDetect
    ├── observe.ts            # your MutationObserver helper
    └── dom-utils.ts
```

```ts
// src/feature-manager.ts
type FeatureInit = (signal: AbortSignal) => void | Promise<void>;
type FeatureMeta = {
  id: string;
  include: Array<() => boolean>;
  exclude?: Array<() => boolean>;
  init: FeatureInit;
};

const features = new Map<string, FeatureMeta>();

function add(url: string, meta: Omit<FeatureMeta, 'id'>): void {
  const id = url.split('/').pop()!.replace(/\.(tsx?|jsx?)$/, '');
  features.set(id, { id, ...meta });
}

async function runMatching(signal: AbortSignal): Promise<void> {
  for (const f of features.values()) {
    if (f.include.some((p) => p()) && !(f.exclude ?? []).some((p) => p())) {
      try {
        await f.init(signal);
      } catch (err) {
        console.error(`feature ${f.id} failed:`, err);
        // continue with other features
      }
    }
  }
}

export default { add, runMatching };
```

## Lifecycle libraries Refined GitHub uses

- `delegate-it` — event delegation that auto-cleans on AbortSignal.
- `select-dom` — typed safer alternative to `document.querySelector` (won't return null surprises).
- `dom-chef` — JSX → real DOM nodes (no React; tiny runtime).

These are all factored out as standalone npm packages. Consider adopting `select-dom` and `delegate-it` even if you don't go full feature-module.

## CSS-only fast path

Some Refined GitHub features are pure CSS (no JS init). They're loaded via the manifest's `content_scripts[].css` and tagged with their own filename so they can be disabled per-instance.

```json
{
  "content_scripts": [{
    "matches": ["https://github.com/*"],
    "js": ["content.js"],
    "css": ["css/highlight-collaborators.css", "css/reorder-tabs.css"]
  }]
}
```

The advantage: zero runtime cost for CSS-only enhancements; users can disable specific CSS files via a `webext-options-sync` integration.

## What to skip if your extension is smaller

If you have <10 features, the full feature-module architecture is overkill. A simple `features/` directory with one file per feature and a list in `content.ts` is enough:

```ts
// src/content.ts
import { highlightCollaborators } from './features/highlight-collaborators';
import { reorderTabs } from './features/reorder-tabs';

const controller = new AbortController();
window.addEventListener('beforeunload', () => controller.abort());

if (location.pathname.includes('/issues/')) highlightCollaborators(controller.signal);
if (location.pathname.includes('/pull/')) reorderTabs(controller.signal);
```

Scale up when you cross ~10 features and the conditional chain becomes painful.

## Caveats

- Feature-module isn't the only good architecture; it's optimized for "lots of small, independent enhancements to one site." For "one big complex feature on many sites," a flatter controller-based architecture (MetaMask pattern) is better.
- Refined GitHub is GitHub-specific. They have one URL pattern and very rich URL semantics. If your extension runs on many origins, your URL-detection layer will look different.
