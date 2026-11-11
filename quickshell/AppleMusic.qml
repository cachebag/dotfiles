pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// State of the Apple Music web app, fed by the bridge extension through
// applemusic/host.py over a unix socket. `connected` means the page has
// reported in within the last 25 s; everything is empty otherwise.
Singleton {
    id: root

    readonly property string sockPath: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-applemusic.sock"

    property bool connected: false
    property bool playing: false
    property real position: 0
    property real duration: 0
    property var item: null          // { id, name, artist, album, art, duration }
    property bool loved: false
    property bool inLibrary: false
    property int shuffle: 0          // 0 off, 1 songs
    property int repeat: 0           // 0 off, 1 one, 2 all
    property var queue: []           // upcoming: [{ index, name, artist, art }]
    property int queueLength: 0

    property string term: ""
    property var results: []
    property bool searching: false
    property int rid: 0

    property string browse: ""       // "" | playlists | pinned | recent
    property var browseItems: []
    property bool browsing: false    // request in flight
    property string browseNote: ""
    property int brid: 0

    readonly property bool hasItem: connected && item !== null && (item.name ?? "") !== ""

    // Artwork cached to disk so the island's ColorQuantizer (local files only)
    // can tint from it. "" until the download finishes.
    readonly property string artDir: Quickshell.env("HOME") + "/.cache/quickshell/am-art"
    readonly property string artUrl: item?.art ?? ""
    property string artFile: ""
    onArtUrlChanged: {
        artFile = "";
        artFetch.running = false;
        if (artUrl === "")
            return;
        const path = artDir + "/" + Qt.md5(artUrl) + ".jpg";
        artFetch.target = path;
        artFetch.command = ["sh", "-c", 'mkdir -p "$1" && { [ -s "$2" ] || curl -sfL --max-time 10 -o "$2" "$3"; }', "_", artDir, path, artUrl];
        artFetch.running = true;
    }
    Process {
        id: artFetch
        property string target: ""
        onExited: code => {
            if (code === 0 && root.artUrl !== "")
                root.artFile = "file://" + target;
        }
    }

    property var client: null
    property real lastSeen: 0

    // Hot-reload race: the replacement server binds the path, then the old
    // server's teardown unlinks it, leaving a listener with no file. Binding a
    // moment after load lets the old one finish first.
    property bool serverReady: false
    Timer {
        interval: 400
        running: true
        onTriggered: root.serverReady = true
    }

    SocketServer {
        active: root.serverReady
        path: root.sockPath
        handler: Socket {
            id: sock
            parser: SplitParser {
                onRead: data => root.handle(data)
            }
            onConnectedChanged: {
                if (connected) {
                    root.client = sock;
                    root.send({
                        cmd: "state"
                    });
                } else if (root.client === sock) {
                    root.client = null;
                    root.reset();
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: root.connected
        repeat: true
        onTriggered: if (Date.now() - root.lastSeen > 25000)
            root.reset()
    }

    function reset() {
        connected = false;
        playing = false;
        item = null;
        queue = [];
        clearSearch();
        closeBrowse();
    }

    function send(obj) {
        if (!client)
            return false;
        client.write(JSON.stringify(obj) + "\n");
        return true;
    }

    function handle(line) {
        var m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (m.type) {
        case "state":
            lastSeen = Date.now();
            connected = true;
            playing = !!m.playing;
            position = m.position ?? 0;
            duration = m.duration ?? 0;
            item = m.item ?? null;
            loved = !!m.loved;
            inLibrary = !!m.inLibrary;
            shuffle = m.shuffle ?? 0;
            repeat = m.repeat ?? 0;
            queue = m.queue ?? [];
            queueLength = m.queueLength ?? 0;
            break;
        case "position":
            lastSeen = Date.now();
            position = m.position ?? position;
            if (m.duration)
                duration = m.duration;
            break;
        case "results":
            if (m.rid === rid) {
                results = m.results ?? [];
                searching = false;
            }
            break;
        case "browse":
            console.log("applemusic browse:", m.what, m.note || "", (m.items ?? []).length, "items");
            if (m.rid === brid && m.what === browse) {
                browseItems = m.items ?? [];
                browseNote = m.note ?? "";
                browsing = false;
            }
            break;
        case "api":
            console.log("applemusic api:", m.path, JSON.stringify({
                keys: m.keys,
                count: m.count,
                sample: m.sample
            }));
            break;
        case "error":
            console.warn("applemusic:", m.cmd, m.message);
            break;
        }
    }

    // Debug/automation hooks: `qs ipc call applemusic cmd '{"cmd":"state"}'`.
    IpcHandler {
        target: "applemusic"

        function cmd(json: string): void {
            try {
                root.send(JSON.parse(json));
            } catch (e) {
                console.warn("applemusic: bad json", json);
            }
        }
        function reload(): void {
            root.send({
                cmd: "reloadExtension"
            });
        }
    }

    // ---- transport (optimistic where it is cheap to be) -------------------

    function toggle() {
        send({
            cmd: "toggle"
        });
    }
    function next() {
        send({
            cmd: "next"
        });
    }
    function prev() {
        send({
            cmd: "prev"
        });
    }
    function seek(t) {
        position = t;
        send({
            cmd: "seek",
            time: t
        });
    }
    function toggleShuffle() {
        shuffle = shuffle ? 0 : 1;
        send({
            cmd: "shuffle",
            value: shuffle
        });
    }
    // Same order as the app: off → all → one → off.
    function cycleRepeat() {
        repeat = repeat === 0 ? 2 : repeat === 2 ? 1 : 0;
        send({
            cmd: "repeat",
            value: repeat
        });
    }
    function toggleLove() {
        loved = !loved;
        send({
            cmd: "love",
            value: loved
        });
    }
    function addToLibrary() {
        if (inLibrary)
            return;
        inLibrary = true;
        send({
            cmd: "library"
        });
    }
    function playQueueIndex(i) {
        send({
            cmd: "queueIndex",
            index: i
        });
    }
    function playItem(kind, id) {
        send({
            cmd: "playItem",
            kind: kind,
            id: id
        });
    }

    // ---- search -----------------------------------------------------------

    Timer {
        id: debounce
        interval: 220
        onTriggered: root.runSearch()
    }
    function search(t) {
        term = t;
        if (t.trim() === "") {
            clearSearch();
            return;
        }
        searching = true;
        debounce.restart();
    }
    function runSearch() {
        rid++;
        send({
            cmd: "search",
            term: term,
            rid: rid
        });
    }
    function clearSearch() {
        debounce.stop();
        term = "";
        results = [];
        searching = false;
    }

    // ---- browse: playlists / pinned / recently played ----------------------

    function openBrowse(what) {
        if (browse === what) {
            closeBrowse();
            return;
        }
        browse = what;
        browseItems = [];
        browseNote = "";
        browsing = true;
        brid++;
        send({
            cmd: "browse",
            what: what,
            rid: brid
        });
    }
    function closeBrowse() {
        browse = "";
        browseItems = [];
        browsing = false;
    }

    // ---- the app window ---------------------------------------------------

    // The app lives in the hidden `music` special workspace (hyprland rule);
    // raise() slides it in and out.
    // Chromium names --app windows after the URL, not --class.
    readonly property bool windowOpen: ToplevelManager.toplevels.values.some(t => String(t.appId).startsWith("chrome-music.apple.com"))

    function toggleWindow() {
        Hyprland.dispatch('hl.dsp.workspace.toggle_special("music")');
    }
    // Chromium opens a second app window rather than activating the first, so
    // never launch while one exists: show it instead.
    function launch() {
        if (windowOpen) {
            toggleWindow();
            return;
        }
        const entry = DesktopEntries.byId("applemusic");
        if (entry)
            entry.execute();
        else
            Quickshell.execDetached(["chromium", "--app=https://music.apple.com/us/home", "--class=Apple-Music", "--autoplay-policy=no-user-gesture-required"]);
    }
    function raise() {
        windowOpen ? toggleWindow() : launch();
    }
}
