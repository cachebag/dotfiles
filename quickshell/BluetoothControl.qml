import QtQuick
import Quickshell
import Quickshell.Bluetooth

Item {
    id: root

    required property var bar

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter ? adapter.enabled : false

    // Read every `connected` so the binding tracks all of them.
    readonly property var connected: {
        const all = Bluetooth.devices.values;
        const out = [];
        for (var i = 0; i < all.length; i++) {
            if (all[i].connected)
                out.push(all[i]);
        }
        return out;
    }

    // Paired devices first, then anything discovered while scanning.
    readonly property var known: {
        if (!root.on)
            return [];
        const all = Bluetooth.devices.values.slice();
        all.sort(function (a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return a.deviceName < b.deviceName ? -1 : a.deviceName > b.deviceName ? 1 : 0;
        });
        return all;
    }

    function iconFor(device) {
        const i = device.icon;
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0)
            return "󰋋";
        if (i.indexOf("audio") >= 0 || i.indexOf("speaker") >= 0)
            return "󰓃";
        if (i.indexOf("mouse") >= 0)
            return "󰍽";
        if (i.indexOf("keyboard") >= 0)
            return "󰌌";
        if (i.indexOf("phone") >= 0)
            return "󰄜";
        return "󰂯";
    }

    function label(device) {
        return device.deviceName !== "" ? device.deviceName : device.address;
    }

    function tap(device) {
        if (device.connected)
            device.disconnect();
        else if (device.paired || device.bonded)
            device.connect();
        else
            device.pair();
    }

    BarButton {
        id: btn
        anchors.fill: parent

        icon: !root.on ? "󰂲" : root.connected.length > 0 ? "󰂱" : "󰂯"
        // Showing the device name is the point — "which headphones am I on?"
        label: root.connected.length === 1 ? root.label(root.connected[0]) : root.connected.length > 1 ? root.connected.length + " devices" : ""
        contentColor: !root.on ? Theme.muted : root.connected.length > 0 ? Theme.fg : Theme.muted
        active: menu.visible

        onClicked: menu.toggle()
        onRightClicked: menu.toggle()
    }

    Popup {
        id: menu
        bar: root.bar
        owner: root
        cardWidth: 320
        cardHeight: 380

        // Discovery is battery-expensive; only scan while the user is looking.
        onVisibleChanged: if (root.adapter)
            root.adapter.discovering = menu.visible && root.on

        Column {
            anchors.fill: parent
            spacing: 8

            Item {
                width: parent.width
                height: 30

                Text {
                    id: head
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.on ? "󰂯" : "󰂲"
                    color: root.on ? Theme.accent : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                }

                Column {
                    anchors.left: head.right
                    anchors.leftMargin: 8
                    anchors.right: toggle.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "Bluetooth"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: !root.adapter ? "no adapter" : !root.on ? "off" : root.adapter.discovering ? "scanning…" : root.connected.length + " connected"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                }

                BarButton {
                    id: toggle
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    hpad: 6
                    icon: root.on ? "󰂯" : "󰂲"
                    contentColor: root.on ? Theme.accent : Theme.muted
                    onClicked: if (root.adapter)
                        root.adapter.enabled = !root.adapter.enabled
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 47
                clip: true
                spacing: 2
                model: root.known

                delegate: Rectangle {
                    required property var modelData

                    width: list.width
                    height: 34
                    radius: Theme.radius
                    color: hover.pressed ? Theme.press : hover.containsMouse ? Theme.hover : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.pairing ? "󰑓" : root.iconFor(modelData)
                            color: modelData.connected ? Theme.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize

                            RotationAnimator on rotation {
                                running: modelData.pairing
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 100
                            spacing: 0

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: root.label(modelData)
                                color: modelData.connected ? Theme.accent : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: modelData.connected
                            }

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                visible: !modelData.paired
                                text: "not paired"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 4
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.batteryAvailable
                            text: Math.round(modelData.battery * 100) + "%"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.tap(modelData)
                    }

                    // Declared after the row's MouseArea so it receives its own clicks.
                    BarButton {
                        id: forget
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        visible: modelData.paired && !modelData.connected && (hover.containsMouse || containsMouse)
                        hpad: 4
                        icon: "󰩺"
                        contentColor: containsMouse ? Theme.urgent : Theme.muted
                        onClicked: modelData.forget()
                    }
                }
            }
        }
    }
}
