pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int barHeight: 38
    readonly property int gap: 8
    readonly property int pad: 10
    readonly property int radius: 6

    readonly property int fast: 120
    readonly property int normal: 200
    readonly property int slow: 380
    readonly property int easeOut: Easing.OutCubic
    readonly property int easeBack: Easing.OutBack

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12

    property color bg: "#111313"
    property color fg: "#dbd3c3"
    property var palette: ["#111313", "#C12A20", "#947253", "#79854E", "#A09561", "#C4A168", "#CCB59E", "#dbd3c3", "#9a948b", "#C12A20", "#947253", "#79854E", "#A09561", "#C4A168", "#CCB59E", "#dbd3c3"]

    readonly property color accent: palette[5]
    readonly property color accentAlt: palette[4]
    readonly property color muted: palette[8]
    readonly property color urgent: palette[1]

    readonly property real barOpacity: 0.92
    readonly property color line: Qt.rgba(fg.r, fg.g, fg.b, 0.10)
    readonly property color hover: Qt.rgba(fg.r, fg.g, fg.b, 0.09)
    readonly property color press: Qt.rgba(fg.r, fg.g, fg.b, 0.16)
    readonly property color surface: Qt.darker(bg, 1.35)

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    Process {
        id: reader
        command: ["cat", Quickshell.env("HOME") + "/.cache/wal/colors.json"]

        stdout: StdioCollector {
            id: out
        }

        onExited: root.ingest(String(out.text))
    }

    function ingest(raw) {
        try {
            const data = JSON.parse(raw);
            if (!data || !data.colors || !data.special)
                return;

            const next = [];
            for (var i = 0; i < 16; i++) {
                const c = data.colors["color" + i];
                if (!c)
                    return;
                next.push(c);
            }

            root.bg = data.special.background;
            root.fg = data.special.foreground;
            root.palette = next;
        } catch (e) {
            return;
        }
    }

    function reload() {
        reader.running = true;
    }

    Component.onCompleted: root.reload()

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.reload()
    }
}
