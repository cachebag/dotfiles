import QtQuick

Item {
    id: root

    property string icon: ""
    property string label: ""
    property color contentColor: Theme.fg
    property bool active: false
    property bool showBackground: true
    property int hpad: Theme.pad
    property alias containsMouse: mouse.containsMouse

    signal clicked
    signal rightClicked
    signal middleClicked
    signal wheel(int delta)

    implicitWidth: Math.max(row.implicitWidth + hpad * 2, height)
    implicitHeight: Theme.barHeight - 8

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Theme.radius
        color: root.active ? Theme.alpha(Theme.accent, 0.18) : mouse.pressed ? Theme.press : mouse.containsMouse ? Theme.hover : "transparent"
        scale: mouse.pressed ? 0.94 : 1.0

        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.fast
                easing.type: Theme.easeOut
            }
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.active ? Theme.accent : root.contentColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2

            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
        }

        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.contentColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        cursorShape: Qt.PointingHandCursor
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function (e) {
            if (e.button === Qt.RightButton)
                root.rightClicked();
            else if (e.button === Qt.MiddleButton)
                root.middleClicked();
            else
                root.clicked();
        }

        onWheel: function (e) {
            root.wheel(e.angleDelta.y);
        }
    }
}
