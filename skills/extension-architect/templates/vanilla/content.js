// Content script — runs in the page's DOM (isolated JS world).
// Has chrome.runtime + chrome.storage, no DOM-less APIs.

(function () {
  // Sentinel for smoke tests
  window.__cs_loaded = true;

  console.log('Content script loaded on', location.href);

  // Example: send a ping to the background
  chrome.runtime.sendMessage({ type: 'ping' }, (response) => {
    if (chrome.runtime.lastError) {
      console.warn('Background not reachable:', chrome.runtime.lastError);
      return;
    }
    console.log('Background ping response:', response);
  });
})();
