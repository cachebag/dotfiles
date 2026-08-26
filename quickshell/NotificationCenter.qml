import QtQuick
import Quickshell

Item {
    id: root

    required property var bar

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    readonly property int unread: Notifications.unread

    BarButton {
        id: btn
        anchors.fill: parent

        icon: Notifications.dnd ? "󰂛" : root.unread > 0 ? "󰅸" : "󰂚"
        contentColor: Notifications.dnd ? Theme.muted : root.unread > 0 ? Theme.accent : Theme.fg
        active: panel.visible

        onClicked: panel.toggle()
        onRightClicked: Notifications.dnd = !Notifications.dnd
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 2
        visible: root.unread > 0 && !panel.visible
        width: Math.max(13, badge.implicitWidth + 5)
        height: 13
        radius: 6.5
        color: Theme.urgent

        Text {
            id: badge
            anchors.centerIn: parent
            text: root.unread > 9 ? "9+" : root.unread
            color: Theme.bg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 5
            font.bold: true
        }
    }

    Popup {
        id: panel
        bar: root.bar
        owner: root
        cardWidth: 400
        cardHeight: 460

        onVisibleChanged: if (visible)
            Notifications.markRead()

        Column {
            anchors.fill: parent
            spacing: 8

            Item {
                width: parent.width
                height: 30

                Text {
                    id: title
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰂚  Notifications"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                Text {
                    anchors.left: title.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifications.count > 0
                    text: Notifications.count
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    BarButton {
                        hpad: 6
                        icon: Notifications.dnd ? "󰂛" : "󰂚"
                        label: Notifications.dnd ? "dnd" : ""
                        contentColor: Notifications.dnd ? Theme.accent : Theme.muted
                        onClicked: Notifications.dnd = !Notifications.dnd
                    }

                    BarButton {
                        hpad: 6
                        icon: "󰩺"
                        visible: Notifications.count > 0
                        contentColor: containsMouse ? Theme.urgent : Theme.muted
                        onClicked: Notifications.dismissAll()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }

            Item {
                width: parent.width
                height: parent.height - 47

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: Notifications.count === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰂛"
                        color: Theme.alpha(Theme.fg, 0.25)
                        font.family: Theme.font
                        font.pixelSize: 28
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Notifications.dnd ? "do not disturb" : "nothing new"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                ListView {
                    id: feed
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: Notifications.log
                    visible: Notifications.count > 0

                    delegate: NotificationCard {
                        required property var modelData

                        entry: modelData
                        width: feed.width
                    }
                }
            }
        }
    }
}
