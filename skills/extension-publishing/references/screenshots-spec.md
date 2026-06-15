# Chrome Web Store screenshots — what to provide

## Requirements

- **Dimensions**: 1280×800 (recommended) or 640×400.
- **Format**: PNG or JPEG.
- **Quantity**: 1 minimum, 5 maximum.
- **File size**: <5 MB each.

The first screenshot is the "hero" — most prominent in the listing. Pick it deliberately.

## The five-screenshot pattern

```markdown
# Screenshots — <Extension Name>

## 1 — Primary value prop (HERO)

**Show**: <The single most concrete thing your extension does, in action.>

Examples:
- For an ad blocker: a website with ads visible vs. blocked, side by side.
- For a PR highlighter: a GitHub PR list with the extension's overlay clearly visible.
- For a password manager: the autofill button visible on a login form.

**Do**:
- Use a real-looking page (not a contrived demo).
- Make the extension's contribution unmistakable (highlight, arrow, before/after).
- Show value in <3 seconds of viewing.

**Don't**:
- Show the popup floating above an empty page.
- Use generic stock images.
- Try to explain the architecture.

## 2 — Settings / configuration

**Show**: The options page with sensible defaults filled in, ideally with a callout on one important setting.

**Why**: Reassures users that the extension is configurable, not opaque.

## 3 — Edge case / power feature

**Show**: A less-obvious capability that converts power users.

Examples:
- Keyboard shortcuts in action.
- Multiple monitors / multi-tab support.
- An integration with another tool.

## 4 — Multi-context

**Show**: The extension working across the user's typical workflow — popup + content script visible at the same time, or two surfaces (popup + side panel) used together.

**Why**: Demonstrates the full feature set.

## 5 — Trust signal

**Show**: One of:
- The permissions screen with narrow permissions visible ("activeTab", "storage" — no scary `<all_urls>`).
- A "no data collected" indicator in your own UI.
- A privacy-policy snippet rendered cleanly.
- A "open source" badge linking to the repo.

**Why**: The last screenshot before the user clicks "Add to Chrome" is the most influential. Use it for trust, not for another feature.
```

## Annotations

Annotations are allowed but should be minimal:

- ✅ Short text labels ("← Skip button appears here")
- ✅ Arrows pointing to specific UI elements
- ✅ Before/after labels
- ❌ Marketing copy ("BEST EXTENSION EVER!")
- ❌ Comparison with named competitors (against CWS policy)
- ❌ Heavily filtered or stylized photographs

Tools: Skitch, CleanShot X, ShareX. Whatever is fastest for you.

## Don'ts (rejection bait)

- ❌ Screenshots that show functionality not present in the extension.
- ❌ Stock images from getty/shutterstock (or any image you don't have rights to).
- ❌ Screenshots that show data you don't actually have (mock-up users that look like real people).
- ❌ Screenshots that look like Chrome itself (the user thinks they're looking at Chrome, not an extension).
- ❌ Mention of trademarked names in screenshots (Gmail, Google, Facebook) unless the extension genuinely works with them and you have justification.
- ❌ Adult/violent imagery.

## Localized screenshots

If you ship in multiple locales, you can provide locale-specific screenshots in the CWS dashboard. Most extensions don't bother for the initial release — English-only is fine. Add localized screenshots after launch if your user base in a non-English market grows.

## Promotional tile

The promotional tile is **optional** but recommended:

- **Dimensions**: 440×280.
- **Used**: in CWS category pages, search results.
- **Don't**: try to fit too much. One image + 2-4 words.

Example for a PR highlighter:

```
[Image: GitHub PR list with one row clearly highlighted]
"Highlight your PRs"
```

## Marquee promotional tile (featured-only)

- **Dimensions**: 1400×560.
- **Used**: only on the CWS homepage if your extension gets featured (rare, the Chrome Web Store's editorial choice).
- **Optional**.

If you ever provide it, use the same hero shot as Screenshot 1 but at 1400×560.

## Process

1. Set up the extension in a dev profile with example data.
2. Set browser zoom to 100% and window to a fixed size.
3. Take screenshots at the spec'd dimensions. If your window isn't the right size, resize and retake.
4. Annotate if needed.
5. Compress the PNG (use [pngquant](https://pngquant.org/) or [ImageOptim](https://imageoptim.com/)) — CWS limits 5 MB each but smaller loads faster for users.
6. Name them `01-hero.png`, `02-settings.png`, ..., `05-trust.png`.
7. Save in `docs/screenshots/` in the repo so future updates can reproduce them.

## When you need new screenshots

- Major UI redesign (mandatory).
- Adding a new feature that should be in the hero.
- Annual refresh — even without changes, refreshing screenshots signals active maintenance.
- After a Chrome UI refresh changes how extensions appear in the toolbar.

## Reviewer perspective

Reviewers spend ~10 seconds on screenshots. They're checking:

1. Does the hero match the single-purpose statement?
2. Are screenshots showing the extension, or just Chrome with the extension installed?
3. Any obvious policy violations (deceptive imagery, fake reviews, copyrighted content)?

Make the answers easy: clear hero, extension features visible, no shortcuts.
