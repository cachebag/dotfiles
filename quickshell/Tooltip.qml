import QtQuick
import Quickshell

PopupWindow {
    id: root

    required property var bar
    required property var owner
    property bool show: false
    property string text: ""

    visible: root.show && root.text !== "" && delay.ready

    anchor {
        item: root.owner
        edges: Edges.Top
        gravity: Edges.Top
        margins.bottom: 8
    }

    implicitWidth: label.implicitWidth + 18
    implicitHeight: label.implicitHeight + 12
    color: "transparent"

    QtObject {
        id: delay
        property bool ready: false
    }

    Timer {
        interval: 400
        running: root.show
        onTriggered: delay.ready = true
    }

    onShowChanged: if (!root.show)
        delay.ready = false

    Rectangle {
        id: box
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        opacity: 0
        y: 6

        Component.onCompleted: {
            opacity = 1;
            y = 0;
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fast
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Theme.easeOut
            }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
