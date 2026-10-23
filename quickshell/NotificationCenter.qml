import QtQuick
import Quickshell

// Bell in the bar: opens the control center, right-click toggles do-not-disturb.
Item {
    id: root

    required property var bar

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    readonly property int unread: Notifications.unread

    BarButton {
        id: btn
        anchors.fill: parent

        icon: Notifications.dnd ? "󰂛" : root.unread > 0 ? "󰅸" : "󰂚"
        contentColor: Notifications.dnd ? Theme.muted : root.unread > 0 ? Theme.accent : Theme.fg
        active: Notifications.centerOpen

        // The center's outside-click grab closes it on this same click; don't reopen.
        onClicked: {
            if (!Notifications.centerOpen && Date.now() - Notifications.closedAt < 300)
                return;
            Notifications.centerOpen = !Notifications.centerOpen;
        }
        onRightClicked: Notifications.dnd = !Notifications.dnd
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 2
        visible: root.unread > 0 && !Notifications.centerOpen
        width: Math.max(13, badge.implicitWidth + 5)
        height: 13
        radius: 6.5
        color: Theme.urgent

        Text {
            id: badge
            anchors.centerIn: parent
            text: root.unread > 9 ? "9+" : root.unread
            color: Theme.bg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 5
            font.bold: true
        }
    }
}
