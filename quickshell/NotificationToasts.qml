import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    visible: Notifications.toasts.length > 0

    // Overlay so toasts survive fullscreen windows; no keyboard grab so typing
    // in the focused app is never interrupted.
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

    Column {
        id: stack
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifications.toasts

            delegate: Item {
                id: slot
                required property var modelData

                width: stack.width
                implicitHeight: card.implicitHeight

                NotificationCard {
                    id: card
                    entry: slot.modelData
                    floating: true
                    width: parent.width

                    opacity: 0
                    x: 24

                    Component.onCompleted: {
                        opacity = 1;
                        x = 0;
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.normal
                        }
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.normal
                            easing.type: Theme.easeOut
                        }
                    }
                }

                // Hovering pauses the countdown so a toast can't vanish mid-read.
                MouseArea {
                    id: dwell
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.MiddleButton
                    onClicked: Notifications.remove(slot.modelData.key)
                }

                // Only hides the toast — the entry stays in the center.
                Timer {
                    interval: Notifications.toastDuration(slot.modelData)
                    running: interval > 0 && !dwell.containsMouse && !card.replying
                    onTriggered: Notifications.hideToast(slot.modelData.key)
                }
            }
        }
    }
}
