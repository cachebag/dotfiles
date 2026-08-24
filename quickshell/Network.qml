import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    Process {
        id: probe
        command: [Quickshell.shellPath("nmrs")]
    }

    BarButton {
        id: btn
        anchors.fill: parent
        icon: "🖧"
        contentColor: root.cpu > 85 ? Theme.urgent : Theme.fg

        onClicked: Quickshell.execDetached(["nmrs"])
    }
}
