// Isolated-world relay between page.js (window.postMessage) and the
// extension's service worker (runtime port). Reconnects if the worker sleeps.
(() => {
  const CH = "qs-am";
  let port = null;
  let backoff = 500;

  function connect() {
    try {
      port = chrome.runtime.connect({ name: "am" });
    } catch (e) {
      port = null; // extension reloaded: this script is orphaned
      return;
    }
    backoff = 500;
    port.onMessage.addListener(m => window.postMessage({ [CH]: "in", msg: m }, "https://music.apple.com"));
    port.onDisconnect.addListener(() => {
      port = null;
      backoff = Math.min(backoff * 2, 5000);
      setTimeout(connect, backoff);
    });
  }
  connect();

  window.addEventListener("message", e => {
    if (e.source !== window || !e.data || e.data[CH] !== "out" || !port) return;
    try {
      port.postMessage(e.data.msg);
    } catch (err) {
      port = null;
    }
  });
})();
