// Popup script — runs as ES module.

// Apply i18n to data-i18n attributes
document.querySelectorAll('[data-i18n]').forEach((el) => {
  const key = el.getAttribute('data-i18n');
  const msg = chrome.i18n.getMessage(key);
  if (msg) el.textContent = msg;
});

const button = document.getElementById('action-btn');
const output = document.getElementById('output');

button?.addEventListener('click', async () => {
  const response = await chrome.runtime.sendMessage({ type: 'ping' });
  output.textContent = JSON.stringify(response, null, 2);
});
