import QtQuick
import Quickshell

// One app's notifications. Collapsed shows the newest with a stack hint behind
// it; expanded lists them all.
Column {
    id: root

    required property var group
    readonly property int size: root.group.entries.length
    readonly property bool expanded: root.size > 1 && Notifications.expandedApps[root.group.app] === true

    readonly property string iconSource: root.group.icon

    spacing: 6

    function setExpanded(v) {
        const next = Object.assign({}, Notifications.expandedApps);
        next[root.group.app] = v;
        Notifications.expandedApps = next;
    }

    Item {
        width: parent.width
        height: 22

        Image {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSource === "" ? 0 : 16
            height: 16
            visible: root.iconSource !== ""
            source: root.iconSource
            sourceSize.width: 32
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            id: name
            anchors.left: icon.right
            anchors.leftMargin: root.iconSource === "" ? 2 : 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.group.app
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
        }

        Rectangle {
            anchors.left: name.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: root.size > 1
            width: countText.implicitWidth + 10
            height: 16
            radius: 8
            color: Theme.alpha(Theme.fg, 0.08)

            Text {
                id: countText
                anchors.centerIn: parent
                text: root.size
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 4
                font.bold: true
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            BarButton {
                visible: root.size > 1
                implicitHeight: 22
                hpad: 5
                icon: root.expanded ? "󰅃" : "󰅀"
                label: root.expanded ? "less" : "all"
                contentColor: containsMouse ? Theme.accent : Theme.muted
                onClicked: root.setExpanded(!root.expanded)
            }

            BarButton {
                implicitHeight: 22
                hpad: 5
                icon: "󰅖"
                contentColor: containsMouse ? Theme.urgent : Theme.muted
                onClicked: Notifications.removeGroup(root.group.app)
            }
        }
    }

    Repeater {
        model: root.expanded ? root.group.entries : root.group.entries.slice(0, 1)

        delegate: NotificationCard {
            required property var modelData
            entry: modelData
            showApp: false
            width: root.width
        }
    }

    // Collapsed stack: two slivers peeking out under the newest card.
    Item {
        width: parent.width
        height: visible ? 8 : 0
        visible: root.size > 1 && !root.expanded

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: -6
            width: parent.width - 16
            height: 6
            radius: 3
            color: Theme.alpha(Theme.fg, 0.05)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 0
            visible: root.size > 2
            width: parent.width - 32
            height: 5
            radius: 3
            color: Theme.alpha(Theme.fg, 0.03)
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setExpanded(true)
        }
    }
}
