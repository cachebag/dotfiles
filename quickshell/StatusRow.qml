import QtQuick

Item {
    id: root

    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool ok: true
    // Empty hides the button — a healthy row needs no fix.
    property string actionText: ""

    signal triggered

    implicitHeight: 30
    height: implicitHeight

    Text {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.ok ? Theme.accent : Theme.urgent
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    Text {
        id: name
        anchors.left: glyph.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
    }

    BarButton {
        id: fix
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.actionText !== ""
        hpad: 8
        label: root.actionText
        contentColor: containsMouse ? Theme.accent : Theme.muted
        onClicked: root.triggered()
    }

    Text {
        anchors.left: name.right
        anchors.leftMargin: 8
        anchors.right: fix.visible ? fix.left : parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
        text: root.detail
        color: root.ok ? Theme.muted : Theme.urgent
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
    }
}
