pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property int limit: 50

    property bool dnd: false
    property int unread: 0

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

    function hideToast(key) {
        root.toasts = root.toasts.filter(function (e) {
            return e.key !== key;
        });
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

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick++
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
            root.unread++;

            if (!root.dnd)
                root.toasts = [entry].concat(root.toasts).slice(0, 4);
        }
    }
}
