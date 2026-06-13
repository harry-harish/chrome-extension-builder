# Launch posts — paste-ready

Copy blocks verbatim. Install commands are verified working (v1.3.1,
`@claude-community` pin live). Demo video:
https://github.com/harry-harish/chrome-extension-builder/releases/tag/v1.3.1

Install (used in posts):

```
/plugin marketplace add anthropics/claude-plugins-community
/plugin install chrome-extension-builder@claude-community
```

Fallback (also works): `/plugin marketplace add harry-harish/chrome-extension-builder`
then `/plugin install chrome-extension-builder@chrome-extension-builder-marketplace`

Suggested order: Show HN (Sat/Sun ~12:00 UTC) → r/ClaudeCode (+4–6h) →
r/ClaudeAI + r/chrome_extensions (next day, different bodies) → X/Bluesky →
WXT/Plasmo Discords → dev.to article. Be online ~6h after Show HN to reply.

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
Hey all — I built a Claude Code plugin that scaffolds <FRAMEWORK> extensions with MV3 validation baked in (manifest schema, permission audit, CSP checks, Chrome Web Store pre-submission checklist). <FRAMEWORK> is one of the supported scaffolding targets.

Repo: https://github.com/harry-harish/chrome-extension-builder

Would love feedback on where it falls short for real <FRAMEWORK> projects.
```

---

## 7. dev.to article

**Title:** `What I learned building a Claude Code plugin for MV3 Chrome extensions`
**Tags:** `claude, chromeextensions, webdev, opensource`

Section outline (expand each in your own voice; keep it a real walkthrough, not a pitch — dev.to removes primarily-promotional posts):
1. The repeated pain in extension work
2. Why generic coding assistants are not enough here
3. The command model: create, validate, add feature, publish, migrate
4. Why safety rails matter more than one-shot generation
5. WXT as default, but not mandatory
6. Rough edges and what still needs human judgment
7. Link to repo + invitation for real-repo feedback

---

## Rules (verified — don't trip these)
- Different body per subreddit (duplicate text gets shadow-flagged).
- No upvote solicitation on HN (voting-ring detection).
- Don't submit a blog post as Show HN (blog posts are off-topic there — submit the repo).
- Don't lead with MV2 migration as the hook (stale in 2026); CWS-review pain is the live hook.
- Write HN title/comments yourself, not LLM-generated (HN penalizes that).
