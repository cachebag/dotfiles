import QtQuick

// A quick-settings toggle: icon, name, and a status line underneath.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool on: false
    property bool available: true

    signal clicked
    signal rightClicked

    implicitHeight: 54
    radius: Theme.radius + 2
    opacity: root.available ? 1 : 0.4
    color: root.on ? Theme.alpha(Theme.accent, mouse.containsMouse ? 0.30 : 0.22) : mouse.containsMouse ? Theme.alpha(Theme.fg, 0.09) : Theme.alpha(Theme.fg, 0.05)
    border.width: 1
    border.color: root.on ? Theme.alpha(Theme.accent, 0.45) : Theme.line
    scale: mouse.pressed ? 0.96 : 1

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

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.on ? Theme.accent : Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 6
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
        }

        Text {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            elide: Text.ElideRight
            color: root.on ? Theme.alpha(Theme.fg, 0.75) : Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 3
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.available
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (e) {
            if (e.button === Qt.RightButton)
                root.rightClicked();
            else
                root.clicked();
        }
    }
}
