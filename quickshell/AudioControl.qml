import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    required property var bar

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Hardware endpoints only, matched on PwNode.type: `properties` stays empty
    // until a node is bound, so media.class can't be used for the list. The
    // Bluetooth autoswitch's real HFP node is "Audio/Source/Internal", which
    // types as Untracked, so the headset mic is listed once (its virtual source).
    function devices(type) {
        const all = Pipewire.nodes.values;
        const out = [];
        for (var i = 0; i < all.length; i++) {
            const n = all[i];
            if (n.audio && n.type === type)
                out.push(n);
        }
        out.sort(function (a, b) {
            return root.label(a) < root.label(b) ? -1 : 1;
        });
        return out;
    }

    readonly property var sinks: devices(PwNodeType.AudioSink)
    readonly property var sources: devices(PwNodeType.AudioSource)

    function label(node) {
        return node.description || node.nickname || node.name;
    }

    function btAddress(node) {
        if (!node)
            return "";
        const a = node.properties["api.bluez5.address"];
        if (a)
            return a;
        const m = node.name.match(/^bluez_\w+\.([0-9A-F]{2}(?:[:_][0-9A-F]{2}){5})/i);
        return m ? m[1].replace(/_/g, ":") : "";
    }

    function iconFor(node, input) {
        const n = node.name;
        if (n.indexOf("bluez") === 0)
            return "󰋋";
        if (n.indexOf("hdmi") >= 0 || n.indexOf("DisplayPort") >= 0)
            return "󰍹";
        if (input)
            return n.indexOf("Webcam") >= 0 || n.indexOf("webcam") >= 0 ? "󰄀" : "󰍬";
        if (n.indexOf("Headphones") >= 0)
            return "󰋋";
        if (n.indexOf("SPDIF") >= 0 || n.indexOf("iec958") >= 0)
            return "󰓃";
        return "󰓃";
    }

    readonly property string headset: btAddress(sink) || btAddress(source)

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    PwObjectTracker {
        objects: menu.visible ? root.sinks.concat(root.sources) : [root.sink, root.source].filter(n => n)
    }

    Process {
        id: fixer
        property string what: ""
        onExited: what = ""
    }

    function fix(addr) {
        if (fixer.running)
            return;
        fixer.what = addr ? "reconnecting headset…" : "restarting audio…";
        fixer.command = addr ? [Quickshell.shellPath("scripts/audio-fix.sh"), addr] : [Quickshell.shellPath("scripts/audio-fix.sh")];
        fixer.running = true;
    }

    BarButton {
        id: btn
        anchors.fill: parent

        icon: root.muted ? "󰝟" : root.volume > 0.66 ? "󰕾" : root.volume > 0.33 ? "󰖀" : "󰕿"
        label: (root.muted ? "muted" : Math.round(root.volume * 100) + "%") + (root.micMuted ? "  󰍭" : "")
        contentColor: root.muted ? Theme.muted : Theme.fg
        active: menu.visible

        onClicked: menu.toggle()
        onRightClicked: menu.toggle()
        onMiddleClicked: if (root.sink?.audio)
            root.sink.audio.muted = !root.sink.audio.muted

        onWheel: function (delta) {
            if (!root.sink?.audio)
                return;
            const step = delta > 0 ? 0.02 : -0.02;
            root.sink.audio.muted = false;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        height: 2
        radius: 1
        width: (parent.width - Theme.pad * 2) * (root.muted ? 0 : root.volume)
        color: Theme.accent
        opacity: root.muted ? 0 : 0.85

        Behavior on width {
            NumberAnimation {
                duration: Theme.fast
                easing.type: Theme.easeOut
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fast
            }
        }
    }

    // Opt-in: monitoring the Bluetooth virtual mic counts as recording, which
    // flips the headset into low-quality HFP. Never run it just because the
    // popup is open.
    PwNodePeakMonitor {
        id: meter
        node: root.source
        enabled: false
    }

    Popup {
        id: menu
        bar: root.bar
        owner: root
        cardWidth: 340
        cardHeight: body.implicitHeight + 28

        onVisibleChanged: if (!visible)
            meter.enabled = false

        Column {
            id: body
            width: parent.width
            spacing: 10

            Section {
                title: "Output"
                node: root.sink
                model: root.sinks
                input: false
                ctl: root
                mon: meter
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }

            Section {
                title: "Input"
                node: root.source
                model: root.sources
                input: true
                ctl: root
                mon: meter
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }

            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: fixer.running ? fixer.what : "Fix"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    BarButton {
                        visible: root.headset !== ""
                        hpad: 8
                        icon: "󰂰"
                        label: "reconnect headset"
                        contentColor: fixer.running ? Theme.muted : Theme.fg
                        onClicked: root.fix(root.headset)
                    }

                    BarButton {
                        hpad: 8
                        icon: "󰑓"
                        label: "restart"
                        contentColor: fixer.running ? Theme.muted : Theme.fg
                        onClicked: root.fix("")
                    }
                }
            }
        }
    }

    component Section: Column {
        id: sec

        property string title
        property var node
        property var model
        property bool input
        // Inline components get their own id scope, so the outer ids come in as properties.
        property var ctl
        property var mon

        readonly property bool muted: node?.audio?.muted ?? false

        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: 26

            Text {
                id: secIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: sec.input ? (sec.muted ? "󰍭" : "󰍬") : (sec.muted ? "󰝟" : "󰕾")
                color: sec.muted ? Theme.muted : Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
            }

            Text {
                anchors.left: secIcon.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: sec.title
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                BarButton {
                    visible: sec.input
                    hpad: 6
                    icon: "󰔊"
                    label: "test"
                    active: sec.mon.enabled
                    contentColor: Theme.muted
                    onClicked: sec.mon.enabled = !sec.mon.enabled
                }

                BarButton {
                    hpad: 6
                    icon: sec.muted ? (sec.input ? "󰍭" : "󰝟") : (sec.input ? "󰍬" : "󰕾")
                    contentColor: sec.muted ? Theme.urgent : Theme.muted
                    onClicked: if (sec.node?.audio)
                        sec.node.audio.muted = !sec.node.audio.muted
                }
            }
        }

        Row {
            width: parent.width
            spacing: 10

            AudioSlider {
                width: parent.width - pct.width - 10
                anchors.verticalCenter: parent.verticalCenter
                value: sec.node?.audio?.volume ?? 0
                dimmed: sec.muted
                level: sec.input && sec.mon.enabled ? sec.mon.peak : -1
                onMoved: function (v) {
                    if (!sec.node?.audio)
                        return;
                    sec.node.audio.muted = false;
                    sec.node.audio.volume = v;
                }
            }

            Text {
                id: pct
                width: 34
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Math.round((sec.node?.audio?.volume ?? 0) * 100) + "%"
                color: sec.muted ? Theme.muted : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Text {
            visible: sec.input && sec.mon.enabled
            width: parent.width
            wrapMode: Text.WordWrap
            text: "speak — the light bar is your live level"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 4
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: sec.model

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool current: modelData === sec.node

                    width: parent.width
                    height: 30
                    radius: Theme.radius
                    color: current ? Theme.alpha(Theme.accent, 0.12) : hover.pressed ? Theme.press : hover.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    Text {
                        id: devIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        text: sec.ctl.iconFor(modelData, sec.input)
                        color: current ? Theme.accent : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        anchors.left: devIcon.right
                        anchors.leftMargin: 8
                        anchors.right: check.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: sec.ctl.label(modelData)
                        color: current ? Theme.accent : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        font.bold: current
                    }

                    Text {
                        id: check
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: current ? "󰄬" : ""
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (sec.input)
                                Pipewire.preferredDefaultAudioSource = modelData;
                            else
                                Pipewire.preferredDefaultAudioSink = modelData;
                        }
                    }
                }
            }
        }
    }
}
