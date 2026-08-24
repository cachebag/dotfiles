import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property var bar
    required property var owner
    property int cardWidth: 320
    property int cardHeight: 220

    default property alias content: inner.data

    implicitWidth: cardWidth
    implicitHeight: cardHeight
    color: "transparent"
    grabFocus: true

    anchor {
        item: root.owner
        edges: Edges.Top
        gravity: Edges.Top
        margins.bottom: 8
    }

    function open() {
        root.visible = true;
    }
    function close() {
        root.visible = false;
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
        y: 14

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

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: 14
        }
    }

    Connections {
        target: root
        function onVisibleChanged() {
            card.opacity = root.visible ? 1 : 0;
            card.y = root.visible ? 0 : 14;
        }
    }
}
