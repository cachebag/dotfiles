import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

Scope {
    id: root

    readonly property var flow: agent.flow

    PolkitAgent {
        id: agent
    }


    PanelWindow {
        id: win

        visible: root.flow !== null

        // Overlay + exclusive focus: this is a password prompt, it must be able to
        // take keyboard input even over a fullscreen window.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-polkit"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusiveZone: 0
        color: Theme.alpha(Theme.bg, 0.55)

        // Click-outside cancels, matching every other agent's behaviour.
        MouseArea {
            anchors.fill: parent
            onClicked: if (root.flow)
                root.flow.cancelAuthenticationRequest()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            implicitHeight: body.implicitHeight + 32
            height: implicitHeight
            radius: Theme.radius + 4
            color: Theme.surface
            border.width: 1
            border.color: Theme.line

            opacity: win.visible ? 1 : 0
            scale: win.visible ? 1 : 0.96

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.normal
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.normal
                    easing.type: Theme.easeOut
                }
            }

            // Swallow clicks so they don't reach the dismiss layer behind.
            MouseArea {
                anchors.fill: parent
            }

            // This window takes an exclusive keyboard grab, so Escape must always
            // work even on turns where no text input is shown to hold focus.
            focus: true
            Keys.onEscapePressed: if (root.flow)
                root.flow.cancelAuthenticationRequest()

            Column {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 16
                spacing: 10

                Row {
                    width: parent.width
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰌾"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 8
                    }

                    Column {
                        width: parent.width - 40
                        spacing: 2

                        Text {
                            width: parent.width
                            text: "Authentication required"
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                            font.bold: true
                        }

                        Text {
                            width: parent.width
                            visible: text !== ""
                            text: root.flow ? root.flow.message : ""
                            color: Theme.muted
                            wrapMode: Text.WordWrap
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.flow ? root.flow.actionId : ""
                    color: Theme.alpha(Theme.fg, 0.4)
                    elide: Text.ElideMiddle
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 4
                }

                // PAM's own prompts and errors ("Sorry, try again", 2FA, etc).
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError ? Theme.urgent : Theme.muted
                    wrapMode: Text.WordWrap
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }

                Rectangle {
                    width: parent.width
                    height: 32
                    visible: root.flow ? root.flow.isResponseRequired : false
                    radius: Theme.radius
                    color: Theme.alpha(Theme.fg, 0.06)
                    border.width: 1
                    border.color: Theme.accent

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: text !== ""
                            text: root.flow ? root.flow.inputPrompt : ""
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                        }

                        TextInput {
                            id: input
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 120
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            // The flow says whether this turn's input should be masked.
                            echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                            focus: true

                            onAccepted: root.submit()
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    BarButton {
                        hpad: 10
                        label: "Cancel"
                        contentColor: containsMouse ? Theme.urgent : Theme.muted
                        onClicked: if (root.flow)
                            root.flow.cancelAuthenticationRequest()
                    }

                    BarButton {
                        hpad: 10
                        label: "Authenticate"
                        contentColor: Theme.accent
                        onClicked: root.submit()
                    }
                }
            }
        }

    }

    function submit() {
        if (!root.flow)
            return;
        root.flow.submit(input.text);
        input.text = "";
    }

    Connections {
        target: root.flow

        // A fresh session starts after a failure, so clear the stale attempt.
        function onAuthenticationFailed() {
            input.text = "";
            input.forceActiveFocus();
        }
    }

    Connections {
        target: agent

        function onAuthenticationRequestStarted() {
            input.text = "";
            input.forceActiveFocus();
        }
    }
}
