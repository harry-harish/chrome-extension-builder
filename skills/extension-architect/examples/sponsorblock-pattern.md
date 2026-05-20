# SponsorBlock pattern — crowdsourced data + clean SW/CS split

## Source

`ajayyy/SponsorBlock` on GitHub. ~12.1k stars, GPL-3.0, TypeScript. Plus the `SponsorBlockServer` backend (Node + Postgres/SQLite).

## What to copy

SponsorBlock is the reference for an extension that **synchronizes with a community backend**. Two things stand out:

1. **CORS goes through the SW, not the content script.** Under MV3, content scripts run in the page's origin and trigger CORS preflight checks against your backend. The background SW makes API calls in the extension's own origin.

2. **Clean separation**: content script handles only DOM/video interactions. Background SW handles all submission and API.

## Architecture

```
Backend (SponsorBlockServer)
└── api.sponsor.ajay.app
    ├── GET /api/skipSegments?videoID=…
    ├── POST /api/skipSegments       (user submission)
    ├── POST /api/voteOnSponsorTime
    └── …

Extension
├── background.ts               # all fetch() calls; handles submission queue
├── content.ts                  # observes video; injects skip UI
└── popup.tsx                   # configuration; shows community stats
```

The content script never calls `fetch()`. When it needs data:

```ts
// content.ts
async function getSegments(videoId: string) {
  return sendCmd({ type: 'getSegments', videoId });
  // background handles: fetch, cache, error retry, rate limiting
}
```

```ts
// background.ts
chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
  if (cmd.type === 'getSegments') {
    fetchWithCache(`https://api.sponsor.ajay.app/api/skipSegments?videoID=${cmd.videoId}`)
      .then(sendResponse);
    return true;
  }
  if (cmd.type === 'submitSegment') {
    submitWithRetry(cmd.segment).then(sendResponse);
    return true;
  }
});
```

## Adaptation for your extension

### If you have a backend

Move all `fetch()` to the background:

```ts
// src/lib/api.ts (background only)
const BASE_URL = 'https://api.mybackend.com';

export async function getThing(id: string): Promise<Thing> {
  const r = await fetch(`${BASE_URL}/things/${id}`, {
    headers: { 'X-Extension-Version': chrome.runtime.getManifest().version },
  });
  if (!r.ok) throw new Error(`API error ${r.status}`);
  return r.json();
}
```

In content scripts / popup / options:

```ts
const thing = await sendCmd({ type: 'getThing', id: 'abc' });
```

Add `host_permissions` for your API origin (or `optional_host_permissions` if it's only needed for premium features):

```json
{
  "host_permissions": ["https://api.mybackend.com/*"]
}
```

### CORS notes

Background SW fetches happen in the extension's own origin (`chrome-extension://<id>/`). Your backend's CORS policy:

- **Origin match**: respond to `Origin: chrome-extension://<extension-id>` with `Access-Control-Allow-Origin: <that-extension-id>`. Or use `Access-Control-Allow-Origin: *` if your endpoints are safe to be public.
- **Credentials**: if you need cookies, use `Access-Control-Allow-Credentials: true` and a specific origin (not `*`).
- **Preflight**: ensure `OPTIONS /endpoint` returns 200 with the right headers.

### Submission queue with retry

Crowdsourced submissions need to survive flaky networks and SW suspension:

```ts
// background.ts
type Submission = { id: string; payload: any; attempts: number };

async function enqueue(payload: any): Promise<void> {
  const { queue = [] } = await chrome.storage.local.get('queue');
  queue.push({ id: crypto.randomUUID(), payload, attempts: 0 });
  await chrome.storage.local.set({ queue });
  chrome.alarms.create('flushQueue', { delayInMinutes: 0.1 });
}

chrome.alarms.onAlarm.addListener(async (a) => {
  if (a.name !== 'flushQueue') return;
  const { queue = [] } = await chrome.storage.local.get('queue');
  const remaining: Submission[] = [];
  for (const item of queue) {
    try {
      await fetch(`${BASE_URL}/submit`, {
        method: 'POST',
        body: JSON.stringify(item.payload),
        headers: { 'Content-Type': 'application/json' },
      });
    } catch (e) {
      if (item.attempts < 5) remaining.push({ ...item, attempts: item.attempts + 1 });
    }
  }
  await chrome.storage.local.set({ queue: remaining });
  if (remaining.length > 0) {
    chrome.alarms.create('flushQueue', { delayInMinutes: Math.min(5, 0.1 * Math.pow(2, remaining[0].attempts)) });
  }
});
```

### Open data is a feature

SponsorBlock's segment database is publicly downloadable as a Postgres dump. Users can self-host the backend. This:

- Builds trust ("not a black box").
- Lets users keep working if your backend goes down.
- Makes the data more valuable (researchers, third-party tools).

If your extension is built around community data, consider publishing the data dump. License it (CC-BY-SA, CC0, ODbL — pick deliberately).

## Privacy considerations

Backends see every request. For privacy-sensitive data:

- Don't send user IDs by default. Use opaque per-extension-instance random tokens.
- Don't log user IPs. Use Cloudflare's "Last 7 days" or shorter retention.
- Aggregate before storing. If you need stats, store counters not events.
- Be honest in the privacy disclosure. CWS reviewers check.

## Rate limiting (your side)

If your backend gets popular, an extension that bursts requests on page load can DDoS you. Coalesce requests:

```ts
const inflight = new Map<string, Promise<any>>();

async function getSegmentsCoalesced(videoId: string) {
  if (inflight.has(videoId)) return inflight.get(videoId);
  const promise = fetch(`...&videoID=${videoId}`).then((r) => r.json()).finally(() => {
    inflight.delete(videoId);
  });
  inflight.set(videoId, promise);
  return promise;
}
```

## What not to copy

- SponsorBlock-specific UI (the skip button rendering on YouTube): your domain is probably different.
- The exact submission policy / vote weighting: domain-specific.

The general lesson is: **the SW is the only context that should talk to your backend.** Content scripts request data; popups request data; the SW does the actual `fetch`. This is cleaner, safer, and avoids CORS pain.
