import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    // Derived from the palette rather than read from disk: whatever pywal last
    // produced is the truth, so this can never disagree with what you see.
    readonly property bool light: (Theme.bg.r * 0.299 + Theme.bg.g * 0.587 + Theme.bg.b * 0.114) > 0.5

    property bool busy: false

    Process {
        id: toggle
        command: [Quickshell.env("HOME") + "/dotfiles/scripts/theme-mode.sh", "toggle"]
        onExited: root.busy = false
    }

    BarButton {
        id: btn
        anchors.fill: parent

        // Shows the mode you are in, not the one you would switch to.
        icon: root.busy ? "󰑓" : root.light ? "󰖨" : "󰖔"
        contentColor: root.busy ? Theme.muted : Theme.fg

        onClicked: {
            if (root.busy)
                return;
            root.busy = true;
            toggle.running = true;
        }
    }
}
