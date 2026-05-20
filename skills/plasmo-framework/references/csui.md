# Plasmo CSUI — content-script UI in Shadow DOM

CSUI is Plasmo's most distinctive feature: render a React (or Vue/Svelte) component into a Shadow DOM root on the inspected page, isolated from the page's CSS.

## When to use

- You want a UI overlay on a page that ignores the page's CSS.
- You need multiple overlays anchored to specific page elements.
- You need lifecycle (mount/unmount) tied to URL changes or DOM events.

If none of those apply and you just need DOM manipulation, a plain content script is simpler.

## Basic CSUI component

```tsx
// contents/overlay.tsx
import type { PlasmoCSConfig, PlasmoCSUIProps } from 'plasmo';

export const config: PlasmoCSConfig = {
  matches: ['https://www.example.com/*'],
};

// Where to attach the Shadow DOM root. Default: document.body.
export const getRootContainer = () => document.body;

const Overlay = ({ anchor }: PlasmoCSUIProps) => (
  <div
    style={{
      position: 'fixed',
      top: 12,
      right: 12,
      padding: '8px 12px',
      background: '#4f46e5',
      color: '#fff',
      borderRadius: 8,
      fontFamily: 'system-ui',
      fontSize: 14,
      zIndex: 999999,
    }}
  >
    Hello from CSUI
  </div>
);

export default Overlay;
```

The component renders inside a Shadow DOM root attached to `document.body`. Page CSS does not reach into your component, and your CSS does not bleed out.

## Anchor mode — one overlay per page element

Render an overlay next to every `<h1>` on the page:

```tsx
// contents/h1-tag.tsx
import type { PlasmoCSConfig, PlasmoGetInlineAnchorList } from 'plasmo';

export const config: PlasmoCSConfig = {
  matches: ['<all_urls>'],
};

export const getInlineAnchorList: PlasmoGetInlineAnchorList = () =>
  document.querySelectorAll('h1');

const Inline = () => (
  <span style={{ marginLeft: 8, padding: '2px 6px', background: 'gold', borderRadius: 4 }}>
    ★
  </span>
);

export default Inline;
```

Plasmo finds every `<h1>`, attaches a Shadow DOM after each, and renders `Inline` inside. As the page mutates and new `<h1>`s appear, Plasmo re-runs the anchor list. (Throttle if needed via `getOverlayAnchorList` + observer config.)

## Multiple roots, single mount

```tsx
import type { PlasmoCSConfig, PlasmoGetRootContainerList } from 'plasmo';

export const config: PlasmoCSConfig = {
  matches: ['https://app.example.com/*'],
};

export const getRootContainerList: PlasmoGetRootContainerList = () => {
  return Array.from(document.querySelectorAll('.product-card'));
};

const ProductOverlay = ({ anchor }: PlasmoCSUIProps) => {
  // anchor.element is the .product-card DOM node
  const productId = anchor.element.getAttribute('data-product-id');
  return <button>Save {productId}</button>;
};

export default ProductOverlay;
```

## Custom render position

If `default_position: 'inline'` isn't what you want, override the mount logic:

```tsx
import { mount, unmount } from 'plasmo-internal';  // pseudo; check Plasmo docs

export const render = ({ anchor, createRootContainer }) => {
  // Custom positioning
  const container = createRootContainer();
  anchor.element.insertAdjacentElement('beforebegin', container);
  return container;
};
```

The exact API surface varies by Plasmo version; check the docs.

## Styling inside Shadow DOM

Inside a Shadow DOM root, the page's global CSS doesn't reach you. But that also means Tailwind classes loaded into the page don't reach you either. Three options:

1. **Inline styles** (`style={{...}}`). Simple, no setup.
2. **Inline CSS strings via `getStyle`**:

   ```tsx
   export const getStyle = () => {
     const style = document.createElement('style');
     style.textContent = `
       .overlay { position: fixed; top: 12px; right: 12px; }
       .overlay-btn { padding: 8px 12px; background: #4f46e5; color: #fff; }
     `;
     return style;
   };
   ```

3. **Tailwind via Plasmo's tailwind plugin.** Plasmo can inject your Tailwind build into each Shadow DOM root. Configure `tailwind.config.js` and Plasmo handles the rest.

## React state inside CSUI

Each CSUI mount is a separate React tree with its own state. To share state across CSUI instances and with the popup/background, use `@plasmohq/storage`:

```tsx
import { useStorage } from '@plasmohq/storage/hook';

const Overlay = () => {
  const [count, setCount] = useStorage('overlay-count', 0);
  return <button onClick={() => setCount(count + 1)}>Clicked {count} times</button>;
};
```

`useStorage` syncs across all surfaces in real-time.

## Lifecycle (mount, unmount)

Plasmo handles mount automatically. For unmount cleanup (e.g., tearing down a WebSocket), use React `useEffect`:

```tsx
const Overlay = () => {
  useEffect(() => {
    const ws = new WebSocket('wss://example.com');
    return () => ws.close();
  }, []);
  return <div>Live</div>;
};
```

## Limits

- Pages with strict CSP (`frame-ancestors`, etc.) may prevent some CSUI features. Shadow DOM itself is allowed under any CSP; the issues come from loading additional resources (images, fonts) the CSP blocks.
- Pages that aggressively mutate the DOM (e.g., re-render the entire body on route change) will drop your CSUI mounts unless `getRootContainer*` re-attaches them. Plasmo's MutationObserver covers most cases but not all.
- Shadow DOM is not inheritance: `position: fixed` inside the Shadow DOM still works relative to the viewport, but `position: absolute` is relative to the Shadow DOM host's containing block.

## WXT's CSUI equivalent

WXT does not ship a CSUI-style helper. If you need Shadow DOM in a WXT project, do it manually:

```ts
// entrypoints/content.ts (WXT)
import { defineContentScript } from 'wxt/sandbox';

export default defineContentScript({
  matches: ['<all_urls>'],
  main() {
    const host = document.createElement('div');
    const shadow = host.attachShadow({ mode: 'closed' });
    shadow.innerHTML = `
      <style>:host { position: fixed; top: 12px; right: 12px; z-index: 999999; }</style>
      <div>Hello from Shadow DOM</div>
    `;
    document.body.appendChild(host);
  },
});
```

This is the one feature where Plasmo is meaningfully ahead of WXT. If CSUI is your primary need and you're not blocked on Plasmo's maintenance status, Plasmo remains the right pick.
