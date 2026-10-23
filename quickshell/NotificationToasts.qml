import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    // Hidden while the control center is open: it lists the same entries.
    visible: Notifications.toasts.length > 0 && !Notifications.centerOpen

    // Overlay so critical toasts survive fullscreen windows; no keyboard grab so
    // typing in the focused app is never interrupted.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-toasts"

    anchors {
        right: true
        bottom: true
    }

    margins {
        right: 10
        bottom: 10
    }

    implicitWidth: 380
    implicitHeight: stack.implicitHeight
    color: "transparent"
    exclusiveZone: 0

    // Unread entries that aren't on screen as toasts.
    readonly property int overflow: Math.max(0, Notifications.unread - Notifications.toasts.length)

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifications.toasts

            delegate: Item {
                id: slot
                required property var modelData

                readonly property int duration: Notifications.toastDuration(slot.modelData)
                property real remaining: duration
                property bool leaving: false

                width: stack.width
                implicitHeight: card.implicitHeight

                NotificationCard {
                    id: card
                    entry: slot.modelData
                    floating: true
                    width: parent.width

                    opacity: slot.leaving ? 0 : 1 - Math.min(0.7, Math.abs(x) / width)
                    x: 24

                    Component.onCompleted: x = 0

                    Behavior on opacity {
                        enabled: !swipe.active
                        NumberAnimation {
                            duration: Theme.normal
                        }
                    }
                    Behavior on x {
                        enabled: !swipe.active
                        NumberAnimation {
                            duration: Theme.normal
                            easing.type: Theme.easeOut
                        }
                    }

                    // Time left before the toast tucks itself into the center.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Theme.radius
                        anchors.bottomMargin: 1
                        visible: slot.duration > 0
                        height: 2
                        radius: 1
                        width: (parent.width - Theme.radius * 2) * Math.max(0, slot.remaining / Math.max(1, slot.duration))
                        color: Notifications.urgencyColor(slot.modelData.urgency)
                        opacity: dwell.hovered ? 0.25 : 0.6
                    }
                }

                // Pointer handlers sit beside the card's own buttons: hovering and
                // middle-click don't steal clicks, and a drag only takes over once
                // it passes the threshold.
                HoverHandler {
                    id: dwell
                }

                TapHandler {
                    acceptedButtons: Qt.MiddleButton
                    onTapped: Notifications.remove(slot.modelData.key)
                }

                DragHandler {
                    id: swipe
                    target: null
                    yAxis.enabled: false

                    onTranslationChanged: card.x = Math.max(-40, translation.x)
                    onActiveChanged: {
                        if (active)
                            return;
                        // Flung far enough right: dismiss for good. Otherwise snap back.
                        if (card.x > slot.width * 0.3) {
                            slot.leaving = true;
                            card.x = slot.width + 20;
                            gone.start();
                        } else {
                            card.x = 0;
                        }
                    }
                }

                Timer {
                    id: gone
                    interval: Theme.normal
                    onTriggered: Notifications.remove(slot.modelData.key)
                }

                // Paused while hovered, replying or mid-swipe, so a toast can't
                // vanish while you're reading or touching it.
                Timer {
                    interval: 50
                    repeat: true
                    running: slot.duration > 0 && !dwell.hovered && !card.replying && !swipe.active && !slot.leaving
                    onTriggered: {
                        slot.remaining -= interval;
                        if (slot.remaining <= 0)
                            Notifications.hideToast(slot.modelData.key);
                    }
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            visible: win.overflow > 0
            width: more.implicitWidth + 20
            height: 24
            radius: 12
            color: Theme.surface
            border.width: 1
            border.color: Theme.line

            Text {
                id: more
                anchors.centerIn: parent
                text: "+" + win.overflow + " more"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.centerOpen = true
            }
        }
    }
}
