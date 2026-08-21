import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    BarButton {
        id: btn
        anchors.fill: parent

        icon: root.muted ? "󰝟" : root.volume > 0.66 ? "󰕾" : root.volume > 0.33 ? "󰖀" : "󰕿"
        label: root.muted ? "muted" : Math.round(root.volume * 100) + "%"
        contentColor: root.muted ? Theme.muted : Theme.fg

        onClicked: if (root.sink?.audio)
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
}
