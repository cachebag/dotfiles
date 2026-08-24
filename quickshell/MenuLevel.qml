import QtQuick
import Quickshell
import Quickshell.Widgets

Column {
    id: level

    property var handle: null
    property var menuRoot: null
    property int depth: 0
    property int rowHeight: 28

    spacing: 0

    QsMenuOpener {
        id: opener
        menu: level.handle
    }

    Repeater {
        model: opener.children

        delegate: Column {
            id: rowWrap
            required property var modelData

            readonly property string label: modelData.text ?? modelData.label ?? ""
            readonly property bool sep: modelData.isSeparator ?? false
            readonly property bool kids: modelData.hasChildren ?? false
            readonly property bool on: modelData.enabled ?? true
            readonly property string glyph: modelData.icon ?? ""
            readonly property int check: modelData.checkState ?? 0

            property bool expanded: false

            width: level.width
            spacing: 0

            Item {
                visible: rowWrap.sep
                width: level.width
                height: rowWrap.sep ? 7 : 0

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8 + level.depth * 10
                    anchors.rightMargin: 8
                    height: 1
                    color: Theme.line
                }
            }

            Rectangle {
                visible: !rowWrap.sep
                width: level.width
                height: rowWrap.sep ? 0 : level.rowHeight
                radius: Theme.radius - 2
                color: !rowWrap.on ? "transparent" : hover.pressed ? Theme.press : hover.containsMouse ? Theme.hover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8 + level.depth * 12 + (hover.containsMouse && rowWrap.on ? 2 : 0)
                    spacing: 8

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.fast
                            easing.type: Theme.easeOut
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowWrap.check === 2
                        text: "󰄬"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: rowWrap.glyph !== ""
                        implicitSize: 14
                        asynchronous: true
                        source: rowWrap.glyph
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, level.width - 40 - level.depth * 12)
                        elide: Text.ElideRight
                        text: rowWrap.label
                        color: rowWrap.on ? Theme.fg : Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    visible: rowWrap.kids
                    text: "󰅂"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    rotation: rowWrap.expanded ? 90 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.normal
                            easing.type: Theme.easeOut
                        }
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: rowWrap.on

                    onClicked: {
                        if (rowWrap.kids) {
                            rowWrap.expanded = !rowWrap.expanded;
                            return;
                        }

                        rowWrap.modelData.triggered();
                        level.menuRoot.visible = false;
                    }
                }
            }

            Item {
                width: level.width
                clip: true
                height: rowWrap.expanded && sub.item ? sub.item.implicitHeight : 0

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Theme.easeOut
                    }
                }

                Loader {
                    id: sub
                    active: rowWrap.kids
                    width: level.width
                    source: "MenuLevel.qml"

                    onLoaded: {
                        item.handle = rowWrap.modelData.submenu ?? rowWrap.modelData;
                        item.menuRoot = level.menuRoot;
                        item.depth = level.depth + 1;
                        item.rowHeight = level.rowHeight;
                    }
                }
            }
        }
    }
}
