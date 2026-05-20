# Chrome Web Store listing — template

Use this as the starting point for the project's `docs/store-listing.md`. The fields map to what the CWS dashboard asks for.

```markdown
# Store Listing — <Extension Name>

## Required identity

**Extension name** (≤45 chars):
<Name>

**Short description** (≤132 chars, shown in search results):
<Lead with verb. Concrete. No marketing fluff.>

## Single-purpose statement (required, ≤1 sentence)

<Narrow. Concrete. Not "a useful tool for browsing." More like
"highlights merged pull requests on GitHub.com" or
"converts the current article into a printable PDF.">

## Detailed description (no length limit, but keep skimmable)

<Open with the single-purpose statement.>

What it does:
- <Feature 1 in one sentence>
- <Feature 2>
- <Feature 3>

What it does NOT do:
- <One concrete reassurance about privacy or scope.>
- <Another.>

Privacy:
<Plain summary of what data is collected. If none: "This extension does not collect any user data." Link to the full privacy policy URL.>

Permissions:
- `<permission>`: <one-sentence justification>
- `<permission>`: <one-sentence justification>

Source code: <https://github.com/your-org/your-extension>
Bug reports: <https://github.com/your-org/your-extension/issues>
Privacy policy: <https://your-domain.com/privacy>

## Privacy policy URL (required if you collect any data)

<https://your-domain.com/privacy>

## Category (pick one)

- Productivity (default for most)
- Developer Tools
- Accessibility
- Social & Communication
- News & Weather
- Photos
- Search Tools
- Shopping
- Sports
- Fun
- Workflow & Planning

## Languages

<Comma-separated list of locales your extension supports
based on `_locales/` directories.>

## Permission justifications (for the dashboard — required)

| Permission | Justification |
|---|---|
| `storage` | Persist user preferences across sessions. |
| `activeTab` | Inject the highlight overlay when the user clicks the toolbar icon. |
| `<all_urls>` | <CRITICAL: this triggers manual review. Justify in terms of single-purpose statement, or remove.> |
| `scripting` | Required to inject the content script via chrome.scripting.executeScript on user invocation. |
| ... | ... |

## Single-purpose statement justification (for the dashboard)

<One paragraph reiterating the single-purpose statement and explaining
why the chosen permissions are necessary to achieve that single purpose.
Reviewers read this. Be specific.>

## Privacy practices disclosure (for the dashboard — checkbox section)

Indicate honestly:

- [ ] Personally identifiable information (name, address, email, age, ID)
- [ ] Health information
- [ ] Financial information (transactions, credit card numbers, bank details)
- [ ] Authentication information (passwords, credentials, tokens)
- [ ] Personal communications (emails, texts, chats)
- [ ] Location (region, IP, GPS)
- [ ] Web history (URLs visited)
- [ ] User activity (clicks, mouse movements, scrolling)
- [ ] Website content (text, images, audio captured from sites)

For each you check, explain how it's used and where it's stored.

Also indicate:

- [ ] Data is sold to third parties — must be FALSE
- [ ] Data is used or transferred for non-extension-purposes — must be FALSE
- [ ] Data is used or transferred to determine creditworthiness or for lending — must be FALSE

## Limited Use disclosure (if you use restricted-scope Google APIs)

If your extension uses Gmail API, Drive API, or other restricted Google scopes, you must include the Limited Use statement verbatim:

> Use of information received from Google APIs will adhere to the
> [Chrome Web Store User Data Policy](https://developer.chrome.com/docs/webstore/program-policies/user-data-faq),
> including the Limited Use requirements.

## Trader status (required for EU compliance)

Indicate whether the publisher is a "trader" or a "non-trader":

- **Trader**: a person or business making the extension available in the course of a trade or business.
- **Non-trader**: individuals making it available outside a commercial context.

Most paid extensions and many free-but-business-backed extensions are traders. Hobby extensions by individuals are non-traders.

## Pricing

- [ ] Free (recommended for first release)
- [ ] Paid (requires payments setup; ID + tax info)
- [ ] In-app purchases

If charging, set the trial period (typically 30 days).

## Distribution

- [ ] Public — listed in CWS, anyone can install
- [ ] Unlisted — installable only via direct link
- [ ] Private — restricted to specific email allowlist or Google Workspace domains

Start with **unlisted** for early testing, then promote to **public** once stable.

## Regions

Default: all regions where Chrome Web Store is available. Restrict only if you have a legal reason (GDPR-specific feature, regional data residency, etc.).
```

## Things reviewers consistently reject

1. **Single-purpose violations.** Two unrelated features in one extension. Split into separate extensions.
2. **Overbroad permissions.** `<all_urls>` without a single-purpose reason. Narrow or justify.
3. **Privacy mismatch.** Code calls a tracker or analytics service that's not declared in privacy disclosures. Audit before submitting.
4. **Misleading listing.** Screenshots show functionality that isn't actually in the extension.
5. **Remote code.** Loading scripts from CDNs at runtime. MV3 should block this automatically; some extensions get clever and reviewers notice.
6. **Affiliate injection without disclosure.** Adding affiliate parameters to URLs without saying so in the listing.
7. **Bait-and-switch.** Listing description doesn't match what the extension does.

## Things reviewers look at favorably

1. **Specific single-purpose statement.** "Adds dark mode to Wikipedia" beats "improves browsing."
2. **Narrow permissions.** `activeTab` instead of `<all_urls>` shows you understand the model.
3. **Open source link.** Reviewers can verify behavior matches description.
4. **Clear privacy policy.** Plain language, not boilerplate.
5. **Active maintenance.** Recent commits, responsive to issues.
6. **i18n.** Suggests a polished, mature extension.

## Reviewer's mental model

The CWS reviewer is checking: "Does this extension do what it says it does, and only what it says it does?"

The listing is your spec. The code must match it. Every gap between what the listing says and what the code does is a potential rejection.
