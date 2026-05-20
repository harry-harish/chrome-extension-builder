# LavaMoat setup

## When to adopt

- **Always**: extensions that handle credentials, wallets, or crypto.
- **Strongly recommended**: extensions with >20 production deps.
- **Optional**: small UI-only extensions with carefully audited deps.

The reason LavaMoat exists: the November 2018 `event-stream` attack injected `flatmap-stream` to exfiltrate BitPay Copay wallet keys. ~867,232 downloads occurred before detection. Any extension with a deep dep graph is at risk of similar attacks.

## Two distinct tools

### 1. `@lavamoat/allow-scripts` — postinstall script guard

Blocks `postinstall` scripts unless explicitly allowed. Easy to adopt; works with any package manager and any bundler.

```bash
pnpm add -D @lavamoat/allow-scripts
```

`package.json`:

```json
{
  "scripts": {
    "postinstall": "allow-scripts"
  },
  "lavamoat": {
    "allowScripts": {
      "$root$": true,
      "esbuild": true,
      "@swc/core": true,
      "playwright": true
    }
  }
}
```

Generate the initial allow-list:

```bash
pnpm allow-scripts auto
```

This inspects your dep tree, finds packages with postinstall scripts, and lists them. Review each one:

- ✅ Allow scripts from packages you trust (esbuild, swc, etc. that need native binaries).
- ❌ Deny scripts from packages where the postinstall isn't obviously needed.

When you add a new dep that has a postinstall, `pnpm install` will fail with a clear message telling you to add it to the allow-list. **Always investigate before adding.**

### 2. `lavamoat` (bundle-time sandboxing)

Runs your bundled code with per-package SES (Secure ECMAScript) compartments. A compromised dep can't reach globals or other deps' modules.

This is more invasive. MetaMask uses `lavamoat-browserify` because that's where the integration is mature.

For Vite-based projects (WXT, CRXJS), bundle-time LavaMoat isn't as mature. Practical advice:

1. Use `@lavamoat/allow-scripts` (works everywhere).
2. Audit your dep graph with `pnpm why <package>` for any suspicious deps.
3. For the most security-critical sections (vault decryption, key derivation), consider isolating into a separate package built with Browserify + LavaMoat, and load via a sandboxed iframe.

## Dep-graph auditing

LavaMoat itself doesn't replace `pnpm audit`. Run both:

```bash
pnpm audit --prod
pnpm dlx better-npm-audit audit -p
```

Pay special attention to:

- Recently-published packages with sudden adoption (signal of a compromise).
- Packages that imitate popular ones (typosquatting: `lodahs` instead of `lodash`).
- Packages with single maintainers and no recent commits but high downloads.

The `scripts/audit-deps.sh` in this plugin wraps these checks and recommends LavaMoat when appropriate.

## Pinning dependencies

LavaMoat helps but doesn't substitute for pinning:

```json
{
  "dependencies": {
    "react": "18.2.0",            // ✅ pinned
    "react-dom": "^18.2.0",       // ⚠️ range — accepts patches automatically
    "axios": "*"                  // ❌ catastrophic — any version, any update
  }
}
```

For extensions:

- Use exact versions (`"18.2.0"`) for crypto/security-sensitive deps.
- Use caret (`"^18.2.0"`) for UI libraries where minor patches matter.
- Never use `"*"` or `"latest"`.

Combine with a lockfile (`pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`) committed to the repo. `pnpm install --frozen-lockfile` in CI prevents drift.

## Reproducible builds

For trust-sensitive extensions (wallets, password managers), ensure a third party can rebuild your release and verify the bundle:

1. Commit lockfile and `.nvmrc`.
2. Pin Node version in `package.json#engines.node`.
3. Don't include timestamps in output (set `SOURCE_DATE_EPOCH` if your bundler honors it).
4. Document the exact build command in README.
5. Consider committing the signed Firefox Add-ons artifact as Dark Reader does.

## Threat model boundaries

LavaMoat defends against:

- ✅ Malicious npm packages.
- ✅ Hijacked maintainer accounts.
- ✅ Postinstall script attacks.

LavaMoat does NOT defend against:

- ❌ Malicious code in your own repo (your engineers).
- ❌ Compromised CI (build server signs malicious code).
- ❌ Browser zero-days.
- ❌ Phishing of user credentials.

Adopt accordingly. LavaMoat is a layer, not a panacea.

## Cheap wins before LavaMoat

If full LavaMoat is too much overhead, these cheap wins help:

1. **Reduce dep count.** Replace small deps with inline code (do you really need `is-odd`?).
2. **Avoid native deps.** They run arbitrary build-time code.
3. **Audit on every `pnpm install`.** Configure CI to run `pnpm audit` and fail on critical.
4. **Subscribe to GitHub Dependabot.** Get notified of CVEs in your deps.
5. **Pin lockfiles.** No floating versions.

## When you handle crypto

If your extension touches `crypto.subtle.encrypt`, `crypto.subtle.deriveKey`, or any keys:

- ✅ Adopt LavaMoat allow-scripts.
- ✅ Isolate crypto into a single audited package (Bitwarden pattern).
- ✅ Use Web Crypto API — never bundle your own RSA/AES implementation.
- ✅ Run a security audit before each release.
- ✅ Set up a `security.txt` and bug bounty.

The cost of getting it wrong is loss of user funds / credentials. The cost of LavaMoat is a few hours of setup.
