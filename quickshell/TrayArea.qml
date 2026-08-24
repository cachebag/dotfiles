import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Item {
    id: root

    required property var bar

    implicitHeight: Theme.barHeight - 8
    implicitWidth: Math.max(row.implicitWidth, 1)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: entry
                required property var modelData

                width: 28
                height: root.height

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.radius
                    color: mouse.pressed ? Theme.press : mouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                }

                IconImage {
                    id: img
                    anchors.centerIn: parent
                    implicitSize: 16
                    asynchronous: true
                    source: entry.modelData.icon
                    scale: mouse.pressed ? 0.85 : mouse.containsMouse ? 1.12 : 1.0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.fast
                            easing.type: Theme.easeBack
                        }
                    }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: function (e) {
                        const item = entry.modelData;

                        if (e.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                            return;
                        }

                        if (e.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu)
                                menu.toggle();
                            return;
                        }

                        item.activate();
                    }
                }

                TrayMenu {
                    id: menu
                    bar: root.bar
                    owner: entry
                    trayItem: entry.modelData
                }

                Tooltip {
                    bar: root.bar
                    owner: entry
                    show: mouse.containsMouse
                    text: entry.modelData.tooltipTitle || entry.modelData.title || entry.modelData.id
                }
            }
        }
    }
}
