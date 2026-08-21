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

    function fromEntry(appId) {
        if (root.entryCount === 0)
            return "";

        const entry = appId ? DesktopEntries.heuristicLookup(String(appId)) : null;
        const named = entry ? entry.icon : "";

        if (!named || named === "")
            return "";

        if (named.charAt(0) === "/")
            return "file://" + named;

        return Quickshell.iconPath(named, "application-x-executable");
    }

    function resolve(appId, title) {
        if (root.isChromiumApp(appId)) {
            const custom = root.lookupCustom(appId, title);
            if (custom !== "")
                return custom;

            return Quickshell.iconPath("chromium", "application-x-executable");
        }

        const native = root.fromEntry(appId);
        if (native !== "")
            return native;

        const rescue = root.lookupCustom(appId, title);
        if (rescue !== "")
            return rescue;

        return Quickshell.iconPath(String(appId || "").toLowerCase(), "application-x-executable");
    }
}
