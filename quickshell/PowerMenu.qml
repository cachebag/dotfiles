import QtQuick
import Quickshell

Item {
    id: root

    required property var bar

    readonly property string home: Quickshell.env("HOME")

    readonly property var actions: [
        {
            glyph: "󰌾",
            name: "Lock",
            cmd: [home + "/dotfiles/scripts/lock.sh"]
        },
        {
            glyph: "󰗽",
            name: "Log out",
            cmd: ["hyprctl", "dispatch", "exit"]
        },
        {
            glyph: "󰤄",
            name: "Suspend",
            cmd: ["systemctl", "suspend"]
        },
        {
            glyph: "󰜉",
            name: "Reboot",
            cmd: ["systemctl", "reboot"]
        },
        {
            glyph: "󰐥",
            name: "Power off",
            cmd: ["systemctl", "poweroff"]
        }
    ]

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    BarButton {
        id: btn
        anchors.fill: parent
        icon: "󰐥"
        contentColor: menu.visible ? Theme.urgent : Theme.fg
        active: menu.visible
        onClicked: menu.toggle()
    }

    Popup {
        id: menu
        bar: root.bar
        owner: root
        cardWidth: 190
        cardHeight: root.actions.length * 36 + 28

        Column {
            anchors.fill: parent
            spacing: 2

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 34
                    radius: Theme.radius
                    color: hover.pressed ? Theme.press : hover.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: hover.containsMouse ? 14 : 10
                        spacing: 12

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.fast
                                easing.type: Theme.easeOut
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.glyph
                            color: row.index === 4 ? Theme.urgent : Theme.accent
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 2
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.close();
                            Quickshell.execDetached(row.modelData.cmd);
                        }
                    }
                }
            }
        }
    }
}
