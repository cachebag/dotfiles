// Runs in music.apple.com's own page context and drives the site's MusicKit
// instance (the same object the web player uses, with your login). Talks to
// bridge.js over window.postMessage. It never touches the DOM.
(() => {
  const CH = "qs-am";
  const post = msg => window.postMessage({ [CH]: "out", msg }, "https://music.apple.com");

  let mk = null;
  const wait = setInterval(() => {
    try { mk = window.MusicKit && MusicKit.getInstance(); } catch (e) { mk = null; }
    if (mk) { clearInterval(wait); init(); }
  }, 500);

  const sf = () => mk.storefrontId || "us";
  const art = (a, s) => a && a.url ? a.url.replace("{w}", s).replace("{h}", s).replace("{f}", "jpg") : "";

  function info(it) {
    if (!it) return null;
    const a = it.attributes || {};
    const pp = a.playParams || {};
    const lib = String(it.id).startsWith("i.") || pp.isLibrary === true;
    return {
      id: it.id,
      catalogId: pp.catalogId || (lib ? "" : it.id),
      library: lib,
      name: a.name || "",
      artist: a.artistName || "",
      album: a.albumName || "",
      art: art(a.artwork, 300),
      duration: (a.durationInMillis || 0) / 1000
    };
  }

  // Per-song love / in-library flags, cached so the icons don't flicker.
  const flags = {};
  const keyOf = item => item.catalogId || item.id;
  const flagsOf = item => (flags[keyOf(item)] = flags[keyOf(item)] || { loved: false, inLibrary: item.library });
  const ratingPath = item => item.library && !item.catalogId ? "/v1/me/ratings/library-songs" : "/v1/me/ratings/songs";

  async function fetchFlags(item) {
    if (!item) return;
    const f = flagsOf(item);
    try {
      const r = await mk.api.music(ratingPath(item), { ids: keyOf(item) });
      const d = r && r.data && r.data.data;
      f.loved = !!(d && d.length && d[0].attributes && d[0].attributes.value === 1);
    } catch (e) {
      f.loved = false; // 404 = not rated
    }
    if (!f.inLibrary && item.catalogId) {
      try {
        const r = await mk.api.music(`/v1/catalog/${sf()}/songs/${item.catalogId}`, { relate: "library" });
        const d = r && r.data && r.data.data && r.data.data[0];
        const lib = d && d.relationships && d.relationships.library && d.relationships.library.data;
        f.inLibrary = !!(lib && lib.length);
      } catch (e) {}
    }
    pushState();
  }

  function queueInfo() {
    const q = mk.queue;
    if (!q || !q.items) return { queue: [], queuePosition: -1, queueLength: 0 };
    const pos = q.position;
    const queue = q.items.slice(pos + 1, pos + 7).map((it, i) => Object.assign(info(it) || {}, { index: pos + 1 + i }));
    return { queue, queuePosition: pos, queueLength: q.items.length };
  }

  function state() {
    const item = info(mk.nowPlayingItem);
    const f = item ? flagsOf(item) : { loved: false, inLibrary: false };
    return Object.assign({
      type: "state",
      playing: !!mk.isPlaying,
      position: mk.currentPlaybackTime || 0,
      duration: mk.currentPlaybackDuration || (item ? item.duration : 0),
      item,
      loved: f.loved,
      inLibrary: f.inLibrary,
      shuffle: mk.shuffleMode | 0,
      repeat: mk.repeatMode | 0
    }, queueInfo());
  }

  let pushTimer = null;
  function pushState() {
    clearTimeout(pushTimer);
    pushTimer = setTimeout(() => post(state()), 60); // coalesce event bursts
  }

  function init() {
    const E = MusicKit.Events;
    ["nowPlayingItemDidChange", "playbackStateDidChange", "queueItemsDidChange", "queuePositionDidChange", "shuffleModeDidChange", "repeatModeDidChange"]
      .forEach(n => E[n] && mk.addEventListener(E[n], pushState));
    mk.addEventListener(E.nowPlayingItemDidChange, () => fetchFlags(info(mk.nowPlayingItem)));

    let last = -1;
    mk.addEventListener(E.playbackTimeDidChange, ev => {
      const t = (ev && ev.currentPlaybackTime) || mk.currentPlaybackTime || 0;
      const p = Math.floor(t);
      if (p !== last) {
        last = p;
        // Exact time, once a second: the shell interpolates between updates.
        post({ type: "position", position: t, duration: mk.currentPlaybackDuration || 0 });
      }
    });

    fetchFlags(info(mk.nowPlayingItem));
    pushState();
    setInterval(pushState, 10000); // heartbeat: a restarted shell catches up
  }

  // ---- commands from the shell --------------------------------------------

  async function handle(c) {
    if (!mk || !c || !c.cmd) return;
    try {
      switch (c.cmd) {
      case "state": break;
      case "play": await mk.play(); break;
      case "pause": await mk.pause(); break;
      case "toggle": mk.isPlaying ? await mk.pause() : await mk.play(); break;
      case "next": await mk.skipToNextItem(); break;
      case "prev": await mk.skipToPreviousItem(); break;
      case "seek": await mk.seekToTime(Number(c.time) || 0); break;
      case "shuffle": mk.shuffleMode = c.value ? 1 : 0; break;
      case "repeat": mk.repeatMode = Number(c.value) || 0; break;
      case "queueIndex": await mk.changeToMediaAtIndex(Number(c.index)); break;
      case "love": await love(!!c.value); break;
      case "library": await addToLibrary(); break;
      case "search": await search(c.term || "", c.rid); break;
      case "browse": await browse(c.what, c.rid); break;
      case "lyrics": await lyrics(c.rid); break;
      case "api": { // raw query for debugging from the shell: result shape, not full payload
        const now = info(mk.nowPlayingItem);
        const path = String(c.path).replace("{id}", now ? (now.catalogId || now.id) : "");
        let d;
        try {
          const r = await mk.api.music(path, c.params || {});
          d = r && r.data;
        } catch (e) {
          d = { thrown: String((e && e.message) || e), status: e && (e.status || (e.data && e.data.status)) };
        }
        const arr = d && Array.isArray(d.data) ? d.data : null;
        const first = arr && arr[0];
        const attrs = (first && first.attributes) || {};
        post({ type: "api", rid: c.rid, path, keys: d ? Object.keys(d) : [], count: arr ? arr.length : -1,
          errors: d && d.errors ? d.errors.map(x => ({ status: x.status, title: x.title, detail: x.detail })) : (d && d.thrown ? [d] : null),
          sample: first ? { type: first.type, id: first.id, attrs: Object.keys(attrs), rels: Object.keys(first.relationships || {}),
            ttml: typeof attrs.ttml === "string" ? attrs.ttml.length + " chars: " + attrs.ttml.slice(0, 400) : undefined } : null });
        break;
      }
      case "playItem": await playItem(c.kind, c.id); break;
      }
    } catch (e) {
      post({ type: "error", cmd: c.cmd, message: String((e && e.message) || e) });
      if (c.cmd === "love" || c.cmd === "library")
        setTimeout(() => fetchFlags(info(mk.nowPlayingItem)), 1500); // undo optimistic flag if it failed
    }
    pushState();
  }

  async function love(on) {
    const item = info(mk.nowPlayingItem);
    if (!item) return;
    flagsOf(item).loved = on;
    pushState();
    await mk.api.music(ratingPath(item) + "/" + keyOf(item), {}, {
      fetchOptions: on
        ? { method: "PUT", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ type: "rating", attributes: { value: 1 } }) }
        : { method: "DELETE" }
    });
  }

  async function addToLibrary() {
    const item = info(mk.nowPlayingItem);
    if (!item || !item.catalogId) return;
    flagsOf(item).inLibrary = true;
    pushState();
    await mk.api.music("/v1/me/library", { "ids[songs]": item.catalogId }, { fetchOptions: { method: "POST" } });
  }

  async function search(term, rid) {
    term = term.trim();
    if (!term) { post({ type: "results", rid, term, results: [] }); return; }
    const r = await mk.api.music(`/v1/catalog/${sf()}/search`, { term, types: "songs,albums,artists,playlists", limit: 5 });
    const res = (r && r.data && r.data.results) || {};
    const out = [];
    const take = (kind, n, sub) => {
      const arr = (res[kind + "s"] && res[kind + "s"].data) || [];
      arr.slice(0, n).forEach(x => {
        const a = x.attributes || {};
        out.push({ kind, id: x.id, name: a.name || "", sub: sub(a), art: art(a.artwork, 120) });
      });
    };
    take("song", 4, a => a.artistName || "");
    take("album", 2, a => (a.artistName ? a.artistName + " · " : "") + "Album");
    take("artist", 1, () => "Artist");
    take("playlist", 2, a => (a.curatorName ? a.curatorName + " · " : "") + "Playlist");
    post({ type: "results", rid, term, results: out });
  }

  // Library resources (library-albums, library-playlists…) play with the same
  // setQueue keys as catalog ones; their ids (l.xxx / p.xxx) carry the scope.
  const KIND = {
    songs: "song", albums: "album", playlists: "playlist", stations: "station", artists: "artist",
    "library-songs": "song", "library-albums": "album", "library-playlists": "playlist", "library-artists": "artist"
  };
  function entry(x) {
    const a = x.attributes || {};
    const kind = KIND[x.type] || x.type;
    const sub = a.artistName || a.curatorName || (kind === "station" ? "Station" : kind === "playlist" ? "Playlist" : kind === "album" ? "Album" : "");
    return { kind, id: x.id, name: a.name || "", sub, art: art(a.artwork, 120) };
  }

  // Apple documents no "pinned" endpoint; try the plausible ones and report back.
  const PIN_PATHS = ["/v1/me/pins", "/v1/me/library/pins", "/v1/me/library/pinned", "/v1/me/pinned", "/v1/me/library/pinned-items"];

  async function browse(what, rid) {
    let items = [], note = "";
    if (what === "playlists") {
      const r = await mk.api.music("/v1/me/library/playlists", { limit: 100 });
      items = ((r && r.data && r.data.data) || []).map(entry);
    } else if (what === "recent") {
      const r = await mk.api.music("/v1/me/recent/played", { limit: 10 });
      items = ((r && r.data && r.data.data) || []).map(entry);
    } else if (what === "pinned") {
      note = "unavailable";
      for (const p of PIN_PATHS) {
        try {
          const r = await mk.api.music(p, { limit: 50 });
          items = ((r && r.data && r.data.data) || []).map(entry);
          note = p;
          break;
        } catch (e) {}
      }
    }
    post({ type: "browse", what, rid, items, note });
  }

  // ---- lyrics: Apple's TTML, word timings when the song has them ----------

  // "12.3", "1:02.3", "0:01:02.3", optional trailing "s".
  function t2s(t) {
    if (!t) return 0;
    const parts = String(t).replace(/s$/, "").split(":").map(Number);
    let s = 0;
    for (const x of parts) s = s * 60 + (isNaN(x) ? 0 : x);
    return s;
  }

  // Words of one <p>, skipping background vocals (ttm:role="x-bg" spans).
  // `sp` marks a space after the token, so syllables of one word stay joined.
  function wordsOf(p) {
    const out = [];
    const walk = node => {
      for (const ch of node.childNodes) {
        if (ch.nodeType === 1 && ch.localName === "span") {
          if (ch.getAttribute("ttm:role") === "x-bg") continue;
          if (ch.hasAttribute("begin") && !ch.querySelector("span[begin]")) {
            const next = ch.nextSibling;
            out.push({ t: ch.textContent, b: t2s(ch.getAttribute("begin")), e: t2s(ch.getAttribute("end")),
              sp: !!(next && next.nodeType === 3 && /\s/.test(next.textContent)) });
          } else {
            walk(ch);
          }
        }
      }
    };
    walk(p);
    return out;
  }

  function parseTTML(x) {
    const doc = new DOMParser().parseFromString(x, "text/xml");
    const lines = [];
    for (const p of doc.getElementsByTagName("p")) {
      const w = wordsOf(p);
      const text = w.length ? w.map(k => k.t + (k.sp ? " " : "")).join("").trim() : p.textContent.replace(/\s+/g, " ").trim();
      if (!text) continue;
      lines.push({ b: t2s(p.getAttribute("begin")), e: t2s(p.getAttribute("end")), t: text, w });
    }
    return lines;
  }

  async function lyrics(rid) {
    const now = info(mk.nowPlayingItem);
    if (!now) { post({ type: "lyrics", rid, id: "", kind: "none", lines: [] }); return; }
    const id = now.catalogId || now.id;
    let ttml = "", kind = "none", err = "";
    for (const ep of ["syllable-lyrics", "lyrics"]) {
      try {
        const r = await mk.api.music(`/v1/catalog/${sf()}/songs/${id}/${ep}`);
        const d = r && r.data && r.data.data && r.data.data[0];
        if (d && d.attributes && d.attributes.ttml) {
          ttml = d.attributes.ttml;
          kind = ep === "lyrics" ? "line" : "syllable";
          break;
        }
      } catch (e) {
        err = ep + ": " + String((e && e.message) || e);
      }
    }
    // The web player's own route: lyrics as an include on the song resource.
    if (!ttml) {
      try {
        const r = await mk.api.music(`/v1/catalog/${sf()}/songs/${id}`, { include: "syllable-lyrics,lyrics" });
        const song = r && r.data && r.data.data && r.data.data[0];
        const rel = (song && song.relationships) || {};
        for (const key of ["syllable-lyrics", "lyrics"]) {
          const d = rel[key] && rel[key].data && rel[key].data[0];
          if (d && d.attributes && d.attributes.ttml) {
            ttml = d.attributes.ttml;
            kind = key === "lyrics" ? "line" : "syllable";
            break;
          }
        }
      } catch (e) {
        err += " | include: " + String((e && e.message) || e);
      }
    }
    const lines = ttml ? parseTTML(ttml) : [];
    // Line-level files have no spans; syllable files sometimes have untimed lines.
    if (kind === "syllable" && !lines.some(l => l.w.length)) kind = "line";
    post({ type: "lyrics", rid, id: now.id, kind, lines, err });
  }

  async function playItem(kind, id) {
    const opts = { startPlaying: true };
    if (kind === "artist") {
      const r = await mk.api.music(`/v1/catalog/${sf()}/artists/${id}/view/top-songs`, { limit: 25 });
      const ids = ((r && r.data && r.data.data) || []).map(x => x.id);
      if (!ids.length) return;
      opts.songs = ids;
    } else {
      opts[kind] = id; // song | album | playlist | station
    }
    await mk.setQueue(opts);
    if (!mk.isPlaying) await mk.play();
  }

  window.addEventListener("message", e => {
    if (e.source !== window || !e.data || e.data[CH] !== "in") return;
    handle(e.data.msg);
  });
})();
