pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    property int unread: 0
    property bool centerOpen: false
    // When the center last closed itself on an outside click, so the bell
    // click that caused it doesn't immediately reopen it.
    property real closedAt: 0
    // App name -> true for groups expanded in the center.
    property var expandedApps: ({})

    // Our own log, NOT server.trackedNotifications. Apps like Teams close their
    // own notifications seconds after sending, which deletes them server-side —
    // binding history to the tracked model made them vanish before you could read them.
    property var log: []

    // Entries currently shown as on-screen toasts. A subset of log.
    property var toasts: []

    property int seq: 0

    // Bumped on a timer purely so relative-time bindings re-evaluate.
    property int tick: 0

    readonly property int count: log.length

    // notify.json, next to this file. Watched, so edits apply without a reload.
    property var config: ({})
    readonly property int limit: config.historyLimit ?? 100
    readonly property bool soundsOn: config.sounds ?? true
    // Session override from the control center tile; falls back to notify.json.
    property var gameQuiet: undefined
    readonly property bool quietWhenFullscreen: gameQuiet !== undefined ? gameQuiet : (config.quietWhenFullscreen ?? true)

    readonly property bool fullscreen: Hyprland.focusedWorkspace?.hasFullscreen ?? false

    // Newest group first; entries inside a group stay newest first.
    readonly property var groups: {
        const byApp = {};
        const order = [];
        for (var i = 0; i < root.log.length; i++) {
            const e = root.log[i];
            const k = e.appName || "notification";
            if (!byApp[k]) {
                byApp[k] = {
                    app: k,
                    icon: root.iconFor(e),
                    entries: []
                };
                order.push(byApp[k]);
            }
            byApp[k].entries.push(e);
        }
        return order;
    }

    // Notification image, then the app's icon, then an icon theme lookup by
    // desktop entry or app name. Returns a loadable source or "".
    function iconFor(e) {
        if (e.image)
            return e.image;
        const names = [e.appIcon, e.desktopEntry, (e.appName || "").toLowerCase()];
        for (var i = 0; i < names.length; i++) {
            const n = names[i] || "";
            if (n === "")
                continue;
            if (n.indexOf("/") === 0 || n.indexOf("file:") === 0)
                return n;
            const p = Quickshell.iconPath(n, true);
            if (p !== "")
                return p;
        }
        return "";
    }

    function entryFor(key) {
        for (var i = 0; i < root.log.length; i++) {
            if (root.log[i].key === key)
                return root.log[i];
        }
        return null;
    }

    // The app (or we) closed it: keep the text, drop the dead handle.
    function markClosed(key) {
        root.log = root.log.map(function (e) {
            if (e.key !== key)
                return e;
            const copy = Object.assign({}, e);
            copy.notif = null;
            return copy;
        });
        root.toasts = root.toasts.filter(function (e) {
            return e.key !== key;
        });
    }

    // The user dismissed it: drop it entirely.
    function remove(key) {
        const e = root.entryFor(key);
        root.log = root.log.filter(function (x) {
            return x.key !== key;
        });
        root.toasts = root.toasts.filter(function (x) {
            return x.key !== key;
        });
        if (e && e.notif)
            e.notif.dismiss();
    }

    function removeGroup(app) {
        const keys = root.log.filter(function (e) {
            return (e.appName || "notification") === app;
        }).map(function (e) {
            return e.key;
        });
        for (var i = 0; i < keys.length; i++)
            root.remove(keys[i]);
    }

    function hideToast(key) {
        root.toasts = root.toasts.filter(function (e) {
            return e.key !== key;
        });
    }

    function defaultAction(entry) {
        if (!entry || !entry.notif)
            return null;
        const acts = entry.notif.actions;
        for (var i = 0; i < acts.length; i++) {
            if (acts[i].identifier === "default")
                return acts[i];
        }
        return null;
    }

    // Clicking a notification runs its default action, if the app offered one.
    function activate(key) {
        const act = root.defaultAction(root.entryFor(key));
        if (!act)
            return;
        act.invoke();
        root.hideToast(key);
    }

    function markRead() {
        root.unread = 0;
    }

    function dismissAll() {
        const live = root.log.slice();
        root.log = [];
        root.toasts = [];
        root.unread = 0;
        for (var i = 0; i < live.length; i++) {
            if (live[i].notif)
                live[i].notif.dismiss();
        }
    }

    function age(entry) {
        root.tick; // dependency, forces re-evaluation on tick
        const secs = Math.floor((Date.now() - entry.time) / 1000);
        if (secs < 60)
            return "now";
        if (secs < 3600)
            return Math.floor(secs / 60) + "m";
        if (secs < 86400)
            return Math.floor(secs / 3600) + "h";
        return Math.floor(secs / 86400) + "d";
    }

    function urgencyColor(urgency) {
        if (urgency === NotificationUrgency.Critical)
            return Theme.urgent;
        if (urgency === NotificationUrgency.Low)
            return Theme.muted;
        return Theme.accent;
    }

    // Critical notifications must be dismissed deliberately, never on a timer.
    function toastDuration(entry) {
        if (entry.urgency === NotificationUrgency.Critical)
            return 0;
        if (entry.expireTimeout > 0)
            return entry.expireTimeout * 1000;
        return entry.urgency === NotificationUrgency.Low ? 4000 : 7000;
    }

    // Every rule whose `app` (and optional `summary`) regex matches, merged in
    // file order so later rules override earlier ones.
    function ruleFor(appName, summary) {
        const rules = root.config.rules || [];
        const out = {};
        for (var i = 0; i < rules.length; i++) {
            const r = rules[i];
            try {
                if (r.app && !new RegExp(r.app, "i").test(appName || ""))
                    continue;
                if (r.summary && !new RegExp(r.summary, "i").test(summary || ""))
                    continue;
            } catch (e) {
                continue;
            }
            Object.assign(out, r);
        }
        return out;
    }

    function playSound(urgency, rule) {
        if (!root.soundsOn || rule.sound === false)
            return;
        const name = typeof rule.sound === "string" ? rule.sound : urgency === NotificationUrgency.Critical ? "dialog-warning" : urgency === NotificationUrgency.Low ? "" : "message";
        if (name === "")
            return;
        const file = name.indexOf("/") >= 0 ? name : "/usr/share/sounds/freedesktop/stereo/" + name + ".oga";
        Quickshell.execDetached(["pw-play", file]);
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    FileView {
        id: configFile
        path: Quickshell.shellPath("notify.json")
        watchChanges: true
        preload: true
        printErrors: false

        onFileChanged: configFile.reload()
        onLoaded: {
            try {
                root.config = JSON.parse(configFile.text()) || {};
            } catch (e) {
                console.warn("notify.json:", e);
            }
        }
    }

    // History survives restarts. Live handles can't, so restored entries come
    // back closed (no actions or reply), and in-memory images are dropped.
    FileView {
        id: store
        path: Quickshell.statePath("notifications.json")
        preload: true
        atomicWrites: true
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(store.text());
                const entries = (data.log || []).map(function (e) {
                    e.notif = null;
                    return e;
                });
                // Anything that arrived before the file finished loading stays on top.
                root.log = root.log.concat(entries).slice(0, root.limit);
                root.unread += data.unread || 0;
                for (var i = 0; i < root.log.length; i++)
                    root.seq = Math.max(root.seq, root.log[i].key);
            } catch (e) {}
            saver.armed = true;
        }
        onLoadFailed: saver.armed = true
    }

    Timer {
        id: saver
        property bool armed: false
        interval: 1000
        onTriggered: {
            const plain = root.log.map(function (e) {
                return {
                    key: e.key,
                    id: e.id,
                    appName: e.appName,
                    appIcon: e.appIcon,
                    desktopEntry: e.desktopEntry,
                    image: (e.image || "").indexOf("image://") === 0 ? "" : e.image,
                    summary: e.summary,
                    body: e.body,
                    urgency: e.urgency,
                    expireTimeout: e.expireTimeout,
                    time: e.time
                };
            });
            store.setText(JSON.stringify({
                unread: root.unread,
                log: plain
            }));
        }
    }

    onLogChanged: if (saver.armed)
        saver.restart()
    onUnreadChanged: if (saver.armed)
        saver.restart()

    // qs ipc call notifications <fn>
    IpcHandler {
        target: "notifications"

        function toggle(): void {
            root.centerOpen = !root.centerOpen;
        }
        function open(): void {
            root.centerOpen = true;
        }
        function close(): void {
            root.centerOpen = false;
        }
        function toggleDnd(): void {
            root.dnd = !root.dnd;
        }
        function clear(): void {
            root.dismissAll();
        }
    }

    NotificationServer {
        id: server

        // Nothing survives a shell reload; stale toasts on restart are worse than none.
        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: function (n) {
            const rule = root.ruleFor(n.appName, n.summary);

            // Muted apps are dropped outright: no log, no toast, no sound.
            if (rule.mute) {
                n.dismiss();
                return;
            }

            // Without this the server drops it as soon as this handler returns.
            n.tracked = true;

            const key = ++root.seq;

            // Snapshot every field the card renders, so the entry outlives the
            // Notification object once the sending app closes it.
            const entry = {
                key: key,
                id: n.id,
                appName: n.appName,
                appIcon: n.appIcon,
                desktopEntry: n.desktopEntry,
                image: n.image,
                summary: n.summary,
                body: n.body,
                urgency: n.urgency,
                expireTimeout: n.expireTimeout,
                time: Date.now(),
                notif: n
            };

            // closed() is emitted before the object is destroyed, so this is safe.
            n.closed.connect(function () {
                root.markClosed(key);
            });

            root.log = [entry].concat(root.log).slice(0, root.limit);
            if (!root.centerOpen)
                root.unread++;

            // Critical always breaks through; otherwise DND, an open center, a
            // fullscreen game (unless the rule allows it) or a rule hide the toast.
            const critical = n.urgency === NotificationUrgency.Critical;
            const quiet = root.dnd || (root.quietWhenFullscreen && root.fullscreen && !rule.fullscreen);
            if (rule.toast === false || root.centerOpen || (quiet && !critical))
                return;

            root.toasts = [entry].concat(root.toasts).slice(0, 5);
            root.playSound(n.urgency, rule);
        }
    }
}
