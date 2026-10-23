import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Slide-out panel on the right: quick toggles, sliders, media and the
// notification history. Opened from the bell, or `qs ipc call notifications toggle`.
PanelWindow {
    id: win

    readonly property int panelWidth: 420
    property real offset: Notifications.centerOpen ? 0 : panelWidth + 20

    Behavior on offset {
        NumberAnimation {
            duration: Theme.slow
            easing.type: Theme.easeOut
        }
    }

    visible: offset < panelWidth + 20

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-center"

    anchors {
        top: true
        right: true
        bottom: true
    }

    margins {
        top: 10
        right: 10
        bottom: 10
    }

    implicitWidth: panelWidth
    color: "transparent"
    exclusiveZone: 0

    // Clicking anywhere outside closes it.
    HyprlandFocusGrab {
        windows: [win]
        active: Notifications.centerOpen
        onCleared: {
            Notifications.closedAt = Date.now();
            Notifications.centerOpen = false;
        }
    }

    Connections {
        target: Notifications
        function onCenterOpenChanged() {
            if (Notifications.centerOpen) {
                Notifications.markRead();
                Notifications.toasts = [];
                brightness.read();
                keys.forceActiveFocus();
            }
        }
    }

    // ---- state ----------------------------------------------------------

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [win.sink, win.source].filter(n => n)
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)

    readonly property var wifi: {
        const devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi)
                return devs[i];
        }
        return null;
    }
    readonly property string ssid: {
        if (!win.wifi)
            return "";
        const nets = win.wifi.networks.values;
        var name = "";
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected)
                name = nets[i].name;
        }
        return name;
    }

    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0)
            return null;
        for (var i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i];
        return ps[0];
    }

    // Mpris position isn't pushed, so poll it while visible.
    Timer {
        interval: 1000
        repeat: true
        running: win.visible && win.player !== null && win.player.isPlaying
        onTriggered: win.player.positionChanged()
    }

    function fmt(secs) {
        if (!(secs > 0))
            return "0:00";
        const s = Math.floor(secs % 60);
        return Math.floor(secs / 60) + ":" + (s < 10 ? "0" : "") + s;
    }

    // Monitor brightness over DDC/CI. Reads are slow (~100ms+), so read on open
    // and debounce writes while dragging.
    QtObject {
        id: brightness
        property real value: -1
        property real pending: -1

        function read() {
            if (!getter.running)
                getter.running = true;
        }
        function set(v) {
            value = v;
            pending = v;
            debounce.restart();
        }
    }

    Process {
        id: getter
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "VCP 10 C <current> <max>"
                const m = this.text.match(/VCP 10 C (\d+) (\d+)/);
                if (m)
                    brightness.value = parseInt(m[1]) / Math.max(1, parseInt(m[2]));
            }
        }
    }

    Process {
        id: setter
        onExited: if (brightness.pending >= 0)
            debounce.restart()
    }

    Timer {
        id: debounce
        interval: 250
        onTriggered: {
            if (setter.running || brightness.pending < 0)
                return;
            setter.command = ["ddcutil", "setvcp", "10", String(Math.round(brightness.pending * 100))];
            brightness.pending = -1;
            setter.running = true;
        }
    }

    Timer {
        id: clock
        property date now: new Date()
        interval: 1000
        repeat: true
        running: win.visible
        triggeredOnStart: true
        onTriggered: now = new Date()
    }

    // ---- layout ---------------------------------------------------------

    Rectangle {
        id: card
        x: win.offset
        width: win.panelWidth
        height: parent.height
        radius: Theme.radius + 4
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: Notifications.centerOpen = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Header: time and date.
            RowLayout {
                Layout.fillWidth: true

                Column {
                    Layout.fillWidth: true
                    Text {
                        text: Qt.formatTime(clock.now, "HH:mm")
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 30
                        font.bold: true
                    }
                    Text {
                        text: Qt.formatDate(clock.now, "dddd, MMMM d")
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                }

                BarButton {
                    Layout.alignment: Qt.AlignTop
                    hpad: 6
                    icon: "󰅖"
                    contentColor: containsMouse ? Theme.urgent : Theme.muted
                    onClicked: Notifications.centerOpen = false
                }
            }

            // Quick toggles.
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                ControlTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: Networking.wifiEnabled ? "󰖩" : "󰖪"
                    label: "Wi-Fi"
                    detail: !win.wifi ? "no adapter" : !Networking.wifiEnabled ? "off" : win.ssid !== "" ? win.ssid : "on"
                    on: Networking.wifiEnabled
                    available: win.wifi !== null
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: win.btAdapter?.enabled ? "󰂯" : "󰂲"
                    label: "Bluetooth"
                    detail: !win.btAdapter ? "no adapter" : !win.btAdapter.enabled ? "off" : win.btConnected.length === 1 ? (win.btConnected[0].name || "1 device") : win.btConnected.length > 1 ? win.btConnected.length + " devices" : "on"
                    on: win.btAdapter?.enabled ?? false
                    available: win.btAdapter !== null
                    onClicked: win.btAdapter.enabled = !win.btAdapter.enabled
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: Notifications.dnd ? "󰂛" : "󰂚"
                    label: "DND"
                    detail: Notifications.dnd ? "on" : "off"
                    on: Notifications.dnd
                    onClicked: Notifications.dnd = !Notifications.dnd
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    readonly property bool muted: win.sink?.audio?.muted ?? false
                    icon: muted ? "󰝟" : "󰕾"
                    label: "Sound"
                    detail: muted ? "muted" : Math.round((win.sink?.audio?.volume ?? 0) * 100) + "%"
                    on: !muted
                    available: win.sink?.audio !== undefined
                    onClicked: win.sink.audio.muted = !win.sink.audio.muted
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    readonly property bool muted: win.source?.audio?.muted ?? false
                    icon: muted ? "󰍭" : "󰍬"
                    label: "Mic"
                    detail: muted ? "muted" : "live"
                    on: !muted
                    available: win.source?.audio !== undefined
                    onClicked: win.source.audio.muted = !win.source.audio.muted
                }

                ControlTile {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    icon: "󰊴"
                    label: "Game quiet"
                    detail: Notifications.quietWhenFullscreen ? (Notifications.fullscreen ? "active" : "in fullscreen") : "off"
                    on: Notifications.quietWhenFullscreen
                    onClicked: Notifications.gameQuiet = !Notifications.quietWhenFullscreen
                }
            }

            // Sliders.
            Column {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: [
                        {
                            kind: "sink",
                            icon: "󰕾",
                            mutedIcon: "󰝟"
                        },
                        {
                            kind: "source",
                            icon: "󰍬",
                            mutedIcon: "󰍭"
                        },
                        {
                            kind: "brightness",
                            icon: "󰃠",
                            mutedIcon: "󰃠"
                        }
                    ]

                    delegate: Row {
                        id: srow
                        required property var modelData

                        readonly property var node: modelData.kind === "sink" ? win.sink : modelData.kind === "source" ? win.source : null
                        readonly property bool isLight: modelData.kind === "brightness"
                        readonly property bool muted: srow.node?.audio?.muted ?? false
                        readonly property real value: srow.isLight ? Math.max(0, brightness.value) : (srow.node?.audio?.volume ?? 0)

                        width: parent.width
                        height: 22
                        spacing: 10
                        visible: !srow.isLight || brightness.value >= 0

                        BarButton {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: 22
                            hpad: 3
                            icon: srow.muted ? srow.modelData.mutedIcon : srow.modelData.icon
                            contentColor: srow.muted ? Theme.muted : Theme.fg
                            onClicked: if (srow.node?.audio)
                                srow.node.audio.muted = !srow.node.audio.muted
                        }

                        AudioSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 30 - pct.width - 20
                            value: srow.value
                            dimmed: srow.muted
                            onMoved: function (v) {
                                if (srow.isLight) {
                                    brightness.set(v);
                                    return;
                                }
                                if (!srow.node?.audio)
                                    return;
                                srow.node.audio.muted = false;
                                srow.node.audio.volume = v;
                            }
                        }

                        Text {
                            id: pct
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(srow.value * 100) + "%"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }
            }

            // Media.
            Rectangle {
                Layout.fillWidth: true
                visible: win.player !== null
                implicitHeight: 76
                radius: Theme.radius + 2
                color: Theme.alpha(Theme.fg, 0.05)
                border.width: 1
                border.color: Theme.line
                clip: true

                Image {
                    id: art
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    width: height
                    source: win.player?.trackArtUrl ?? ""
                    visible: source !== ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 120
                    asynchronous: true
                }

                Column {
                    anchors.left: art.visible ? art.right : parent.left
                    anchors.leftMargin: art.visible ? 10 : 12
                    anchors.right: controls.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: win.player?.trackTitle || win.player?.identity || ""
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: win.player?.trackArtist ?? ""
                        visible: text !== ""
                        elide: Text.ElideRight
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }

                    Item {
                        width: parent.width
                        height: 14
                        visible: (win.player?.length ?? 0) > 0

                        Rectangle {
                            id: track
                            anchors.left: parent.left
                            anchors.right: times.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height: 3
                            radius: 2
                            color: Theme.line

                            Rectangle {
                                height: parent.height
                                radius: 2
                                width: parent.width * Math.min(1, (win.player?.position ?? 0) / Math.max(1, win.player?.length ?? 1))
                                color: Theme.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.topMargin: -5
                                anchors.bottomMargin: -5
                                cursorShape: Qt.PointingHandCursor
                                enabled: win.player?.canSeek ?? false
                                onClicked: e => win.player.position = win.player.length * e.x / width
                            }
                        }

                        Text {
                            id: times
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: win.fmt(win.player?.position) + " / " + win.fmt(win.player?.length)
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 4
                        }
                    }
                }

                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    BarButton {
                        hpad: 5
                        icon: "󰒮"
                        contentColor: win.player?.canGoPrevious ? Theme.fg : Theme.muted
                        onClicked: if (win.player?.canGoPrevious)
                            win.player.previous()
                    }
                    BarButton {
                        hpad: 5
                        icon: win.player?.isPlaying ? "󰏤" : "󰐊"
                        contentColor: Theme.accent
                        onClicked: if (win.player?.canTogglePlaying)
                            win.player.togglePlaying()
                    }
                    BarButton {
                        hpad: 5
                        icon: "󰒭"
                        contentColor: win.player?.canGoNext ? Theme.fg : Theme.muted
                        onClicked: if (win.player?.canGoNext)
                            win.player.next()
                    }
                }
            }

            // Notifications.
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Notifications"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                Text {
                    visible: Notifications.count > 0
                    text: Notifications.count
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }

                Item {
                    Layout.fillWidth: true
                }

                BarButton {
                    hpad: 6
                    visible: Notifications.count > 0
                    icon: "󰩺"
                    label: "clear"
                    contentColor: containsMouse ? Theme.urgent : Theme.muted
                    onClicked: Notifications.dismissAll()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.line
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: Notifications.count === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Notifications.dnd ? "󰂛" : "󰂚"
                        color: Theme.alpha(Theme.fg, 0.25)
                        font.family: Theme.font
                        font.pixelSize: 32
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Notifications.dnd ? "do not disturb" : "all caught up"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                ListView {
                    id: feed
                    anchors.fill: parent
                    clip: true
                    spacing: 14
                    visible: Notifications.count > 0
                    model: Notifications.groups
                    boundsBehavior: Flickable.StopAtBounds

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.normal
                        }
                    }

                    delegate: NotificationGroup {
                        required property var modelData
                        group: modelData
                        width: feed.width
                    }
                }
            }
        }
    }
}
