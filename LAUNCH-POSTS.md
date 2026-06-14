# Launch posts — paste-ready

> Note: `@claude-community` installs cleanly and now serves **v1.4.0** — the
> community catalog pin has caught up to the latest release, so the earlier
> WXT-scaffold caveat no longer applies. The repo-direct path
> (`harry-harish/chrome-extension-builder`) also always serves the latest release.

Copy blocks verbatim. Latest release:
https://github.com/harry-harish/chrome-extension-builder/releases/tag/v1.4.0

Install (used in posts):

```
/plugin marketplace add anthropics/claude-plugins-community
/plugin install chrome-extension-builder@claude-community
```

Repo-direct fallback (works today, always the latest release): `/plugin marketplace add harry-harish/chrome-extension-builder` then `/plugin install chrome-extension-builder@chrome-extension-builder-marketplace`

Suggested order: Show HN (Sat/Sun ~12:00 UTC) → r/ClaudeCode (+4–6h) →
r/ClaudeAI + r/chrome_extensions (next day, different bodies) → X/Bluesky →
WXT/Plasmo Discords → dev.to article. Be online ~6h after Show HN to reply.

LinkedIn (#7) and the CapillaryTech Slack post (#8) are independent of that public
sequence — post them whenever. LinkedIn lands best Tue–Thu morning; the Slack
heads-up can go any workday. Both are written to stand alone.

---

## 1. Show HN

**Title** (paste exactly):
```
Show HN: Claude Code plugin for building MV3 Chrome extensions
```

**URL:** `https://github.com/harry-harish/chrome-extension-builder`

**First comment** (post immediately after it goes live):
```
Built this after spending too much time on the parts of extension work that are easy to get wrong and annoying to repeat: manifest cleanup, permission review, CSP mistakes, scaffolding the same surfaces again, and prepping for Web Store submission.

The plugin gives Claude Code a set of extension-specific commands for creating a new MV3 project, validating an existing one, adding common surfaces like popup or content scripts, and preparing release artifacts. It supports WXT, Plasmo, CRXJS, and vanilla MV3 flows, with WXT as the default path.

What I want feedback on is where the workflow still feels naive: framework choice, validator gaps, rough edges in publish prep, or places where a real extension repo breaks the assumptions.
```

**Canned replies** (only when asked):
- *Why not just use WXT directly?* → You still can. This sits one layer above and handles the repeated extension-specific workflow around scaffolding, validation, and release prep.
- *Why support Plasmo if WXT is the default?* → Because people already have extension codebases. The goal is to meet existing repos where they are, not force a rewrite.
- *Does it guarantee Web Store approval?* → No. It catches common mistakes and prepares the submission path, but review is still human.
- *Why a Claude Code plugin instead of a CLI?* → The hard parts are contextual. It's useful when the agent can inspect the repo, generate files, run validators, and fix issues in one session.
- *How is this different from no-code builders (Kromio/Emergent/etc.)?* → Those are hosted SaaS for non-coders — you get a deployed artifact, not a codebase. This is for developers who want real MV3 code in their own repo, their framework, validated against store policy before submission.

---

## 2. Reddit — r/ClaudeCode

**Title:** `Built a Claude Code plugin for MV3 Chrome extension work. Looking for gaps before wider launch.`
```
Built a plugin for Chrome extension development in Claude Code.

Main commands right now:
- create a new MV3 extension
- validate manifest, permissions, CSP, and packaging
- add popup/options/content-script/background surfaces
- prep Chrome Web Store submission
- audit MV2 repos and sketch migration plans

Supports WXT, Plasmo, CRXJS, and vanilla MV3 flows.

Not trying to claim magic here. Mostly trying to remove the repetitive parts that keep showing up in extension work. Curious where people think the blind spots are.

https://github.com/harry-harish/chrome-extension-builder
```

---

## 3. Reddit — r/ClaudeAI

(Check the current flair dropdown before posting; use a Showcase/Project flair if one exists.)

**Title:** `I built a Claude Code plugin for building and validating MV3 Chrome extensions`
```
This is a focused Claude Code plugin for browser-extension work.

It helps with scaffolding, manifest validation, CSP and permission review, adding common extension surfaces, and preparing for Chrome Web Store submission.

Would be useful to hear from people who are actually shipping extensions. The main question is whether the command split and validator path match real workflows.

https://github.com/harry-harish/chrome-extension-builder
```

---

## 4. Reddit — r/chrome_extensions

**Title:** `Tool for scaffolding, validating, and prepping MV3 extensions for Web Store submission`
```
Built a Claude Code plugin around the repetitive parts of extension work: MV3 scaffolding, manifest and permission checks, CSP review, feature-surface generation, and submission prep.

It supports WXT, Plasmo, CRXJS, and vanilla MV3. The goal is not to replace framework docs. It is to catch mistakes earlier and cut down the busywork.

Posting because people here have probably seen the failure modes better than most. What would you expect a tool like this to catch before release?

https://github.com/harry-harish/chrome-extension-builder
```

---

## 5. X / Bluesky thread (6 posts, reply-chained)

```
Built a Claude Code plugin for MV3 Chrome extension work.
```
```
The repeated pain is not writing the feature. It is manifest drift, permissions, CSP, packaging, and store-prep.
```
```
This plugin gives Claude Code commands for creating, validating, extending, and prepping Chrome extensions for release.
```
```
Supports WXT, Plasmo, CRXJS, and vanilla MV3. WXT is the default path, not a hard requirement.
```
```
Added safety rails: validator hooks on manifest writes and guarded publish behavior.
```
```
Looking for extension developers to break the assumptions.

github.com/harry-harish/chrome-extension-builder
```

---

## 6. Discord (WXT / Plasmo / CRXJS — swap framework name)

```
Hey all, I built a Claude Code plugin that scaffolds <FRAMEWORK> extensions with MV3 validation baked in (manifest schema, permission audit, CSP checks, Chrome Web Store pre-submission checklist). <FRAMEWORK> is one of the supported scaffolding targets.

Repo: https://github.com/harry-harish/chrome-extension-builder

Would love feedback on where it falls short for real <FRAMEWORK> projects.
```

---

## 7. LinkedIn (public, builder announcement)

Post to your personal LinkedIn. Paste the body below. Put the repo link in the **first comment** (LinkedIn deprioritizes posts with outbound links in the body); the two `/plugin` lines are commands, not URLs, so they stay in the body and double as the CTA. Attach the **validators GIF** as the single media artifact (proves the claim, autoplays silent, low-friction for a skimmed feed). Hold the narrated video and vertical cut for a follow-up.

```
A model that writes plausible code will also write a plausible manifest. And in MV3, plausible and valid aren't the same thing. That gap is where extensions quietly break.

So I built chrome-extension-builder and open-sourced it (MIT). It's a Claude Code plugin for Manifest V3 work.

Run /chrome-ext:new and you go from an empty folder to a scaffolded, validated extension in one pass. /chrome-ext:validate checks the manifest, CSP, and permissions before any of it reaches a reviewer or a browser. The checks are deterministic, not prompt-tuning.

One design choice I care about: the agent that audits your manifest has no write access, so it physically can't rewrite what it just flagged. The reviewer and the writer aren't the same process.

Before launch I ran an adversarial audit on my own plugin. It found 16 real issues. My favorite: the hook that was meant to block an accidental live publish had been guarding a flag the Web Store CLI removed back in its v4, so the real publish command walked straight past it. A safety check guarding nothing. Fixed now, with CI to keep it that way.

Five commands (new, validate, add-feature, publish, migrate-mv2). WXT by default, but Plasmo, CRXJS, and vanilla all work. It won't get you through Web Store review. It just kills the dumb ways to fail first.

It's listed in Anthropic's community plugin marketplace, which means it cleared their submission review (plugin validation plus automated safety screening) before landing there, not just a self-published repo. The same care shows up inside the plugin: least-privilege agents, deterministic checks, and a guard against shipping something you didn't mean to.

/plugin marketplace add anthropics/claude-plugins-community
/plugin install chrome-extension-builder@claude-community

Tell me where it still feels naive.
```

**First comment** (post within a minute of publishing):
```
Repo and v1.4.0 release notes: https://github.com/harry-harish/chrome-extension-builder
```

Hashtags (optional, append to body): `#chromeextensions #manifestv3 #claudecode`

---

## 8. CapillaryTech internal Slack (mixed, global channel)

For a general channel with a mixed, non-engineering, global audience. The main message stays plain and short and leads with the Anthropic-marketplace credibility (the part everyone understands). Post the technical depth as a **thread reply** so it doesn't clutter the main message for non-developers. Keep the language simple for non-native English readers: short sentences, no jargon in the main post. Wrap the install lines in a Slack code block (triple backticks) so the leading slash is not read as a Slack command. Attach the **validators GIF** to the thread reply, not the main message.

**Main message:**

```
I built and open-sourced a developer tool, and it's now live on Anthropic's official Claude Code plugin marketplace. Getting listed there means it passed Anthropic's review, including an automated safety check.

In plain terms: it helps developers build Chrome browser extensions using Claude Code, and it automatically checks their work for the common mistakes that get an extension rejected by the Chrome Web Store. Less trial and error, fewer surprises at submission.

It's called chrome-extension-builder. Free and open source.

If you build extensions, or just want to try it, install is two lines in Claude Code:
/plugin marketplace add anthropics/claude-plugins-community
/plugin install chrome-extension-builder@claude-community

Repo and details: https://github.com/harry-harish/chrome-extension-builder

Happy to give a quick demo to anyone curious. Feedback welcome.
```

**Thread reply (for the engineers):**

```
A bit more on how it's built, for anyone interested. It splits the work across separate agents with deliberate limits, so the agent that reviews your manifest can't edit files. It can only flag problems, never silently rewrite them. The checks run deterministically through hooks, not by asking the model nicely.

Before release I ran a multi-agent audit against the plugin and it found 16 real issues. My favorite: a safety check that was supposed to prevent an accidental live publish had been watching for an old command flag the Chrome Web Store tool already removed, so the real publish command slipped right past it. Fixed, with CI added so it can't come back.
```

---

## 9. dev.to article (complete, paste-ready)

In the dev.to editor, set **Title** and **Tags** in their fields, then paste the body below.

**Title:** What I learned building a Claude Code plugin for MV3 Chrome extensions

**Tags:** `claude`, `chromeextensions`, `webdev`, `opensource`

**Body:**

Claude Code writes extension code fine. That was never the problem.

Ask it for a content script that highlights matched text, or a background service worker that debounces a fetch, and it produces something reasonable on the first try. Where it trips is everything around the code: the Manifest V3 rules, the permission model, the content security policy, and the unwritten expectations of Chrome Web Store review. Those are the parts that fail late, at install, at build, or three weeks after you thought you shipped. And they fail quietly.

I spent a while turning that gap into a plugin called Chrome Extension Builder. This is less a pitch for the plugin and more a writeup of the four things that broke while I built it, because each one taught me something I'd want to know if I were building any developer tool, plugin or not.

## The actual problem

A model that writes plausible code will also write a plausible manifest. The trouble is that "plausible" and "valid" diverge hard in MV3. A manifest with `content_security_policy.extension_pages` containing `unsafe-eval` looks fine to a generator that learned from years of MV2 examples. It is forbidden in MV3 and the extension will not load. The same goes for over-broad host permissions (`<all_urls>` when `activeTab` would do), MV2 background pages instead of a service worker, and remote script in the CSP.

So the design constraint was never "make Claude write extensions." It was: catch the MV3-specific mistakes deterministically, before they reach a human reviewer or a user's browser. That pushed the whole thing toward validators and hooks rather than cleverer prompts.

The command surface ended up small on purpose. Five slash commands: `/chrome-ext:new` runs an eight-phase guided scaffold; `/chrome-ext:validate` runs the manifest, CSP, and permission checks; `/chrome-ext:add-feature` wires in a popup or content script; `/chrome-ext:publish` builds release artifacts; and `/chrome-ext:migrate-mv2` walks an old extension forward. Three agents back them: an architect that designs but has no Bash, a read-only manifest auditor, and a test runner that can build, lint, and drive Playwright but cannot edit files. The capability boundaries are deliberate: the thing that audits your manifest physically cannot rewrite it.

The defaults are opinionated. MV3 only, TypeScript, `activeTab` over `<all_urls>`, a strict CSP with no `unsafe-eval`, no inline, no remote, `_locales` for i18n, typed message passing, reproducible builds. WXT is the default framework, but not mandatory. Plasmo, CRXJS, and vanilla MV3 are all supported. I'll come back to why "default but not mandatory" matters, because the default framework is exactly what broke first.

## War story 1: a floating dependency drifted onto a breaking release

WXT 0.20.26 removed the `wxt/sandbox` export.

My scaffold and skill docs imported `defineBackground` and `defineContentScript` from `wxt/sandbox`, the way the docs showed when I wrote them. The dependency was pinned at `^0.20.0`. So the day 0.20.26 published, a fresh scaffold started failing at `pnpm install` (the `wxt prepare` postinstall step choked) and again at `pnpm build`, with `./sandbox is not exported`. Nobody changed my code. The caret did.

The fix was mechanical: import from `wxt/utils/define-background` and `wxt/utils/define-content-script`, and pin `~0.20.26` instead of letting the caret float across a minor that turned out to carry a breaking change.

The lesson is older than this plugin and I keep relearning it. A scaffolding tool's job is to emit code that compiles today and tomorrow. A floating range on a fast-moving dependency quietly delegates that promise to an upstream maintainer's versioning discipline. When the thing you generate is supposed to be a known-good starting point, pin it. The whole value of a scaffold is that it works on the first run; a caret can take that away without a single line of your own changing.

This is also the clearest argument for "WXT default, not mandatory." Betting the entire tool on one framework's API stability is how one upstream release becomes your outage. Keeping Plasmo, CRXJS, and vanilla MV3 as real paths means a break in one default doesn't take everyone down with it.

## War story 2: the validator that lies (politely)

`claude plugin validate` passes manifests that the runtime loader then rejects.

I hit this twice. Once with a `userConfig` field that included an `enum` key: `validate` was happy, install was not. Once with a `hooks.json` that was missing its outer `"hooks"` wrapper. Again: `validate` green, install red. Both times I'd run the validator, seen it pass, committed, and only found out at the real install step that the CLI validator is a strict subset of the runtime schema. It checks for a class of errors. It does not check for all of them.

The fix wasn't to argue with the validator. It was to stop trusting it as the source of truth. I added a CI job that runs the actual `claude plugin install` against the built plugin, because the only ground truth for "does this load" is loading it. (I also filed the divergence upstream.)

The same trap waits in any toolchain: a validator is a model of correctness, and every model is incomplete. If a green check from a linter or schema validator is your release gate, you are gating on the model, not on reality. Where it's cheap to run the real thing (an actual install, an actual boot, an actual build), make that the gate and let the fast validator be the early warning, not the verdict.

Here's where the project's own validators sit on the other side of that line: they run against real manifests, not a schema's idea of one. A clean run looks like:

```
── Summary ─ critical: 0, warnings: 0 ──
```

And when I deliberately feed it an MV3 manifest with `unsafe-eval` in the CSP, it catches it and exits non-zero:

```
CRITICAL  content_security_policy.extension_pages  contains 'unsafe-eval'. Forbidden in MV3.
── CSP validation: critical=1 ──
```

That `critical=1` isn't cosmetic. The PostToolUse hook runs these validators on every manifest write and exits 2 on a critical finding, so a generated manifest with a forbidden CSP fails the write instead of sailing through to a build. There's a PreToolUse hook too, which blocks a live Chrome Web Store publish (`chrome-webstore-upload`'s `publish` subcommand, or a bare invocation that uploads-and-publishes) unless `CONFIRM_PUBLISH_LIVE=1` is set, so the tool does not push a live store release by accident. And a UserPromptSubmit hook nudges when it sees MV2 mentions, since "convert my MV2 extension" is where a lot of the forbidden-API mistakes originate.

## War story 3: don't force-push a repo something else pins by SHA

This one cost me three weeks and I didn't notice for most of them.

The community marketplace pins each plugin to a specific commit SHA and auto-bumps that pin over time. I force-pushed my repo (to fix a commit author identity, of all things), and that force-push orphaned the exact commit the marketplace had pinned. The auto-bump, finding its anchor gone, silently skipped my plugin. For about three weeks the published install served a stale, broken version. No error surfaced to me. The CI was green. My local was fine. The only people seeing the problem were the people installing it, and I wasn't one of them.

The lesson is specific and I'll state it plainly: if an external system pins your commits by SHA, your history is now an API. Rewriting it is a breaking change to a consumer you can't see. Force-push is a local-feeling operation with a remote, invisible blast radius. The author-identity cleanup I wanted was not worth orphaning a pinned commit; a fresh commit on top would have cost nothing.

More generally: the failure modes that hurt most are the ones with no error message. A red build you fix in an hour. A silently-skipped auto-bump you find when someone mentions in passing that the install "doesn't work for them." Build the alarm for the silent failures first.

## War story 4: I audited my own plugin and found a safety check guarding nothing

Before the 1.4 release I did something I'd recommend to anyone shipping a tool other people run: I turned a fleet of agents loose on it adversarially, one per risk area, each finding double-checked by a separate skeptic agent whose only job was to disprove it. It came back with 16 real issues. Most were ordinary. One was not.

The plugin has a hook that is supposed to stop you from publishing a live Chrome Web Store release by accident. It worked by blocking any command containing `--auto-publish`. Reasonable, except the Web Store upload CLI had dropped `--auto-publish` back in its v4. The live-publish path was now a bare invocation, or a separate `publish` subcommand, and the guard checked for neither. So the safety check was guarding a flag that no longer existed. It would have waved the real publish command straight through while looking, in the code and in my head, exactly like protection.

That is worse than having no guard, because a guard you trust changes how carefully you behave. The fix was easy once I saw it: match the actual live-publish invocations and require an explicit `CONFIRM_PUBLISH_LIVE=1` to get past them. That is the guard described back in war story two. The harder fix was structural. I turned the audit's findings into CI: an adversarial fixture suite that asserts each validator still catches the bad manifests it claims to, a drift check that fails if a pinned dependency floats again, and a job that scaffolds and builds a real project end to end.

The lesson is the uncomfortable one. A safety mechanism is a claim about the world ("this command is dangerous"), and the world moves. The flag gets renamed, the API splits one method into two, the dependency ships a major. If you never re-verify the claim against the real downstream thing, the mechanism quietly decays into decoration. The way you find that out is to attack your own tool on purpose, before someone else does it by accident.

## The honest non-goals

I want to be precise about what this does not do, because the failures above made me allergic to overpromising.

It does not guarantee Chrome Web Store approval. Review is done by humans against policy, and no validator predicts a reviewer. It does not replace the WXT, Plasmo, or CRXJS docs; it leans on them and points you at them, it is not a substitute for reading them. It does not make unsafe permissions acceptable; it makes them visible and harder to ship by accident, which is not the same thing. And it does not publish a live store release by accident; that's the whole point of the confirmation gate.

What I actually learned, across all four stories, is that the hard part of a code-generation tool isn't the generation. It's the verification, the pinning, and the boring discipline around the seams where your tool meets someone else's system. The model writes the content script. The work is making sure the manifest around it survives install, build, store review, and the next upstream release.

## If you want to try it or break it

The plugin is MIT and lives at [github.com/harry-harish/chrome-extension-builder](https://github.com/harry-harish/chrome-extension-builder).

```
/plugin marketplace add anthropics/claude-plugins-community
/plugin install chrome-extension-builder@claude-community
```

It's new, so I'm more interested in real-repo feedback than stars. If you run `/chrome-ext:new` on a real extension and it generates something that won't install, or `/chrome-ext:validate` misses a CSP problem it should have caught, open an issue with the manifest. The validators only get better against manifests that actually broke, and after war story two, I trust real failures more than green checks.
