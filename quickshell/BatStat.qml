import QtQuick

// Part of the battery detail panel (Battery.qml).
Rectangle {
    property string icon
    property string title
    property string value
    property string sub: ""
    property color tint: Theme.fg
    property real fill: -1          // 0–1 progress strip, or -1 for none

    implicitHeight: 58
    radius: Theme.radius
    color: Theme.alpha(Theme.fg, 0.04)
    border.width: 1
    border.color: Theme.line

    Column {
        anchors.fill: parent
        anchors.margins: 9
        spacing: 2

        Text {
            text: parent.parent.icon + "  " + parent.parent.title.toUpperCase()
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            font.letterSpacing: 0.5
        }
        Row {
            spacing: 6
            Text {
                text: parent.parent.parent.value
                color: parent.parent.parent.tint
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }
            Text {
                anchors.baseline: parent.children[0].baseline
                text: parent.parent.parent.sub
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }
    }
    Rectangle {
        visible: parent.fill >= 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 9
        height: 3
        radius: 1.5
        color: Theme.line
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.parent.fill))
            height: parent.height
            radius: parent.radius
            color: parent.parent.tint
        }
    }
}
