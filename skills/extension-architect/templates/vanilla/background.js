// Background service worker — MV3.
//
// Runs as an ES module. Ephemeral: suspends after ~30s idle.
// Treat as a dispatcher, not a doer.

/**
 * @typedef {{ type: 'ping' }} PingCmd
 * @typedef {{ type: 'getStorage', key: string }} GetStorageCmd
 * @typedef {{ type: 'setStorage', key: string, value: unknown }} SetStorageCmd
 * @typedef {PingCmd | GetStorageCmd | SetStorageCmd} Cmd
 */

const handlers = {
  ping: async () => ({ ok: true, pong: Date.now() }),

  getStorage: async ({ key }) => {
    const result = await chrome.storage.local.get(key);
    return { value: result[key] ?? null };
  },

  setStorage: async ({ key, value }) => {
    await chrome.storage.local.set({ [key]: value });
    return { saved: true };
  },
};

chrome.runtime.onMessage.addListener((cmd, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id) {
    sendResponse({ error: 'untrusted-sender' });
    return;
  }
  const handler = handlers[cmd.type];
  if (!handler) {
    sendResponse({ error: `unknown command: ${cmd.type}` });
    return;
  }
  handler(cmd, sender)
    .then((result) => sendResponse(result))
    .catch((err) => sendResponse({ error: String(err) }));
  return true; // async response
});

chrome.runtime.onInstalled.addListener((details) => {
  if (details.reason === 'install') {
    console.log('Extension installed.');
  } else if (details.reason === 'update') {
    console.log(`Updated from ${details.previousVersion} to ${chrome.runtime.getManifest().version}.`);
  }
});
