import QtQuick
import Quickshell

Rectangle {
    id: root

    required property var entry
    // Toasts float over other windows and need their own backdrop; rows in the
    // center sit on the popup surface already.
    property bool floating: false

    property bool replying: false

    // Live handle while the sending app still owns it, null once closed. Read
    // through it when present so in-place updates show, fall back to the snapshot.
    readonly property var live: root.entry.notif

    readonly property string appName: (root.live ? root.live.appName : root.entry.appName) || ""
    readonly property string summary: (root.live ? root.live.summary : root.entry.summary) || ""
    readonly property string body: (root.live ? root.live.body : root.entry.body) || ""
    readonly property int urgency: root.live ? root.live.urgency : root.entry.urgency
    readonly property var actions: root.live ? root.live.actions : []
    readonly property bool canReply: root.live ? root.live.hasInlineReply : false

    readonly property string iconSource: {
        const img = root.live ? root.live.image : root.entry.image;
        if (img !== "")
            return img;
        const ico = root.live ? root.live.appIcon : root.entry.appIcon;
        if (ico !== "")
            return Quickshell.iconPath(ico, true);
        return "";
    }

    implicitHeight: layout.implicitHeight + 20

    radius: Theme.radius + 2
    color: root.floating ? Theme.surface : Theme.alpha(Theme.fg, hover.containsMouse ? 0.07 : 0.04)
    border.width: root.floating ? 1 : 0
    border.color: Theme.line

    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }

    // Urgency stripe — the only thing that distinguishes a critical alert at a glance.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: 2
        radius: 1
        color: Notifications.urgencyColor(root.urgency)
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    Column {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        anchors.topMargin: 10
        spacing: 4

        Item {
            width: parent.width
            height: 16

            Image {
                id: appIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.iconSource === "" ? 0 : 14
                height: 14
                visible: root.iconSource !== ""
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                sourceSize.width: 28
            }

            Text {
                anchors.left: appIcon.right
                anchors.leftMargin: root.iconSource === "" ? 0 : 6
                anchors.right: meta.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: root.appName !== "" ? root.appName : "notification"
                color: Notifications.urgencyColor(root.urgency)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
                font.bold: true
            }

            Row {
                id: meta
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifications.age(root.entry)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 4
                }

                BarButton {
                    anchors.verticalCenter: parent.verticalCenter
                    hpad: 3
                    icon: "󰅖"
                    contentColor: containsMouse ? Theme.urgent : Theme.muted
                    onClicked: Notifications.remove(root.entry.key)
                }
            }
        }

        Text {
            width: parent.width
            visible: root.summary !== ""
            text: root.summary
            color: Theme.fg
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: true
        }

        Text {
            width: parent.width
            visible: root.body !== ""
            text: root.body
            color: Theme.muted
            // The server advertises markup, so let Text render it.
            textFormat: Text.StyledText
            elide: Text.ElideRight
            maximumLineCount: root.floating ? 3 : 6
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
            onLinkActivated: link => Qt.openUrlExternally(link)
        }

        // Actions only exist while the sending app is still listening.
        Row {
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: (root.actions.length > 0 || root.canReply) && !root.replying
            spacing: 4
            topPadding: 4

            Repeater {
                model: root.actions

                delegate: BarButton {
                    required property var modelData

                    hpad: 8
                    label: modelData.text !== "" ? modelData.text : modelData.identifier
                    contentColor: containsMouse ? Theme.accent : Theme.fg
                    onClicked: modelData.invoke()
                }
            }

            BarButton {
                visible: root.canReply
                hpad: 8
                icon: "󰑚"
                label: "reply"
                contentColor: containsMouse ? Theme.accent : Theme.fg
                onClicked: root.replying = true
            }
        }

        Rectangle {
            width: parent.width
            height: visible ? 28 : 0
            visible: root.replying && root.live !== null
            radius: Theme.radius
            color: Theme.alpha(Theme.fg, 0.06)
            border.width: 1
            border.color: Theme.accent

            Row {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 6

                TextInput {
                    id: reply
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    focus: root.replying

                    onAccepted: root.send(text)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: reply.text === ""
                        text: root.live && root.live.inlineReplyPlaceholder !== "" ? root.live.inlineReplyPlaceholder : "reply, then Enter"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                }

                BarButton {
                    anchors.verticalCenter: parent.verticalCenter
                    hpad: 4
                    icon: "󰌑"
                    contentColor: Theme.accent
                    onClicked: root.send(reply.text)
                }
            }
        }
    }

    function send(text) {
        if (text === "" || !root.live)
            return;
        root.live.sendInlineReply(text);
        root.replying = false;
    }
}
