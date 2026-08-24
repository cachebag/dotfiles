import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int cpu: 0
    property int mem: 0

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    Process {
        id: probe
        command: [Quickshell.shellPath("scripts/sysinfo.sh")]

        stdout: StdioCollector {
            id: out
        }

        onExited: {
            const parts = String(out.text).trim().split(/\s+/);
            if (parts.length >= 2) {
                root.cpu = parseInt(parts[0]) || 0;
                root.mem = parseInt(parts[1]) || 0;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    BarButton {
        id: btn
        anchors.fill: parent
        icon: "󰍛"
        label: root.cpu + "%  " + root.mem + "%"
        contentColor: root.cpu > 85 ? Theme.urgent : Theme.fg

        onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
    }
}
