import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property var bar
    required property var owner
    required property var trayItem

    implicitWidth: 260
    implicitHeight: Math.max(24, body.implicitHeight + 16)
    color: "transparent"
    grabFocus: true

    anchor {
        item: root.owner
        edges: Edges.Top
        gravity: Edges.Top
        margins.bottom: 8
    }

    function toggle() {
        root.visible = !root.visible;
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radius + 2
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        opacity: 0
        y: 10

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.normal
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Theme.easeOut
            }
        }

        MenuLevel {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            handle: root.trayItem ? root.trayItem.menu : null
            menuRoot: root
        }
    }

    Connections {
        target: root
        function onVisibleChanged() {
            card.opacity = root.visible ? 1 : 0;
            card.y = root.visible ? 0 : 10;
        }
    }
}
