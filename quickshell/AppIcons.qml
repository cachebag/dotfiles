pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell

Singleton {
    id: root

    readonly property string iconDir: Quickshell.env("HOME") + "/dotfiles/applications/icons"

    property var map: ({})

    readonly property int entryCount: DesktopEntries.applications.values.length

    readonly property var patterns: [
        {
            match: "music.apple.com",
            icon: "am"
        },
        {
            match: "apple music",
            icon: "am"
        },
        {
            match: "apple-music",
            icon: "am"
        },
        {
            match: "applemusic",
            icon: "am"
        },
        {
            match: "mail.proton.me",
            icon: "pm"
        },
        {
            match: "proton mail",
            icon: "pm"
        },
        {
            match: "proton-mail",
            icon: "pm"
        },
        {
            match: "protonmail",
            icon: "pm"
        },
        {
            match: "teams.microsoft.com",
            icon: "teams"
        },
        {
            match: "web.whatsapp.com",
            icon: "whatsapp"
        },
        {
            match: "chat.com",
            icon: "chatgpt"
        },
        {
            match: "chatgpt",
            icon: "chatgpt"
        },
        {
            match: "app.zoom.us",
            icon: "zoom"
        }
    ]

    FolderListModel {
        id: files
        folder: "file://" + root.iconDir
        nameFilters: ["*.png", "*.svg", "*.jpg", "*.jpeg"]
        showDirs: false
        onCountChanged: root.rebuild()
    }

    function rebuild() {
        const m = {};
        for (var i = 0; i < files.count; i++) {
            const name = String(files.get(i, "fileName"));
            const base = name.replace(/\.[^.]+$/, "").toLowerCase();
            m[base] = root.iconDir + "/" + name;
        }
        root.map = m;
    }

    Component.onCompleted: root.rebuild()

    function isChromiumApp(appId) {
        const id = String(appId || "").toLowerCase();
        return id.indexOf("chrome-") === 0 || id.indexOf("chromium") !== -1;
    }

    function lookupCustom(appId, title) {
        const hay = (String(appId || "") + " " + String(title || "")).toLowerCase();
        if (hay.trim() === "")
            return "";

        for (var i = 0; i < root.patterns.length; i++) {
            const p = root.patterns[i];
            if (hay.indexOf(p.match) !== -1 && root.map[p.icon])
                return "file://" + root.map[p.icon];
        }

        const keys = Object.keys(root.map);
        keys.sort(function (a, b) {
            return b.length - a.length;
        });

        for (var j = 0; j < keys.length; j++) {
            const k = keys[j];
            if (k.length >= 4 && hay.indexOf(k) !== -1)
                return "file://" + root.map[k];
        }

        return "";
    }

    function themed(name) {
        if (!name || name === "")
            return "";
        if (name.charAt(0) === "/")
            return "file://" + name;
        return Quickshell.iconPath(name, true);
    }

    function fromEntry(appId) {
        if (root.entryCount === 0 || !appId)
            return "";
        const entry = DesktopEntries.heuristicLookup(String(appId));
        return entry ? root.themed(entry.icon) : "";
    }

    // Match a desktop entry whose Name matches the window title (e.g. Steam/Proton games).
    function fromTitle(title) {
        const t = String(title || "").toLowerCase().trim();
        if (t === "" || root.entryCount === 0)
            return "";
        const apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            const n = String(apps[i].name || "").toLowerCase().replace(/[®™©]/g, "").trim();
            if (n !== "" && n === t)
                return root.themed(apps[i].icon);
        }
        return "";
    }

    // Returns "" when no real icon exists, so callers can draw their own fallback.
    function resolve(appId, title) {
        const id = String(appId || "");

        if (root.isChromiumApp(id)) {
            const custom = root.lookupCustom(id, title);
            return custom !== "" ? custom : root.themed("chromium");
        }

        const steam = id.match(/^steam_app_(\d+)$/);
        if (steam) {
            const s = root.themed("steam_icon_" + steam[1]);
            if (s !== "")
                return s;
        }

        const candidates = [
            root.fromEntry(id),
            root.fromTitle(title),
            root.lookupCustom(id, title),
            root.themed(id.toLowerCase()),
            steam ? root.themed("steam") : ""
        ];
        for (var i = 0; i < candidates.length; i++)
            if (candidates[i] !== "")
                return candidates[i];
        return "";
    }
}
