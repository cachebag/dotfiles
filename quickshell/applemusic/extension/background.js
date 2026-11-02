// Service worker: owns the native-messaging connection to host.py and fans
// messages out to every music.apple.com tab (normally just the app window).
const HOST = "dev.cachebag.applemusic";
const tabs = new Set();
let native = null;
let retry = 1000;

function connectNative() {
  if (native) return native;
  try {
    native = chrome.runtime.connectNative(HOST);
  } catch (e) {
    native = null;
    return null;
  }
  native.onMessage.addListener(m => {
    // `qs ipc call applemusic reload`: pick up edited extension files
    // without visiting chrome://extensions (content scripts reinject on page reload).
    if (m && m.cmd === "reloadExtension") {
      chrome.runtime.reload();
      return;
    }
    for (const p of tabs) {
      try { p.postMessage(m); } catch (e) {}
    }
  });
  native.onDisconnect.addListener(() => {
    native = null; // host missing or shell restarted: back off and retry
    retry = Math.min(retry * 2, 10000);
    setTimeout(connectNative, retry);
  });
  retry = 1000;
  return native;
}

chrome.runtime.onConnect.addListener(p => {
  if (p.name !== "am") return;
  tabs.add(p);
  p.onMessage.addListener(m => {
    const n = connectNative();
    if (n) {
      try { n.postMessage(m); } catch (e) {}
    }
  });
  p.onDisconnect.addListener(() => tabs.delete(p));
  connectNative();
});

connectNative();

// After a reload, re-inject by reloading the app page(s); orphaned content
// scripts from the previous version cannot reconnect.
chrome.runtime.onInstalled.addListener(details => {
  if (details.reason !== "update") return;
  chrome.tabs.query({ url: "https://music.apple.com/*" }).then(tabs => tabs.forEach(t => chrome.tabs.reload(t.id)));
});
