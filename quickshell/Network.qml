import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Item {
    id: root

    required property var bar

    property string askName: ""
    property string errorText: ""

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    readonly property var wifi: {
        const devs = Networking.devices.values;
        var found = null;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi)
                found = devs[i];
        }
        return found;
    }

    // Read every `connected` so the binding tracks all of them, not just up to a match.
    readonly property var active: {
        if (!root.wifi)
            return null;
        const nets = root.wifi.networks.values;
        var found = null;
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected)
                found = nets[i];
        }
        return found;
    }

    readonly property var networks: {
        if (!root.wifi || !Networking.wifiEnabled)
            return [];
        const nets = root.wifi.networks.values.slice();
        // Name breaks ties so rows don't shuffle as signal strengths drift.
        nets.sort(function (a, b) {
            if (b.signalStrength !== a.signalStrength)
                return b.signalStrength - a.signalStrength;
            return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
        });
        return nets;
    }

    readonly property bool portal: Networking.connectivity === NetworkConnectivity.Portal
    readonly property bool vpnUp: tun.loaded

    function iconFor(strength) {
        if (!Networking.wifiEnabled)
            return "󰤮";
        const s = strength * 100;
        if (s >= 80)
            return "󰤨";
        if (s >= 60)
            return "󰤥";
        if (s >= 40)
            return "󰤢";
        if (s >= 20)
            return "󰤟";
        return "󰤯";
    }

    function locked(sec) {
        return sec !== WifiSecurityType.Open && sec !== WifiSecurityType.Owe;
    }

    function needsPsk(sec) {
        return sec === WifiSecurityType.WpaPsk || sec === WifiSecurityType.Wpa2Psk || sec === WifiSecurityType.Sae;
    }

    function clip(s, n) {
        return s.length > n ? s.slice(0, n - 1) + "…" : s;
    }

    function tap(net) {
        root.errorText = "";
        if (net.connected) {
            net.disconnect();
            return;
        }
        // Unsaved PSK network will always want a passphrase; skip the doomed round trip.
        if (!net.known && root.needsPsk(net.security)) {
            root.askName = root.askName === net.name ? "" : net.name;
            return;
        }
        root.askName = "";
        net.connect();
    }

    // The Networking backend models wifi and ethernet only, so the tunnel is read from sysfs.
    FileView {
        id: tun
        path: "/sys/class/net/tun0/operstate"
        // Without preload nothing reads the file, so `loaded` would never flip.
        preload: true
        printErrors: false
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tun.reload()
    }

    BarButton {
        id: btn
        anchors.fill: parent

        icon: root.portal ? "󰗹" : root.iconFor(root.active?.signalStrength ?? 0)
        label: !Networking.wifiEnabled ? "off" : root.active ? root.clip(root.active.name, 16) : "offline"
        contentColor: root.portal ? Theme.urgent : !Networking.wifiEnabled || !root.active ? Theme.muted : Theme.fg
        active: menu.visible

        onClicked: menu.toggle()
        onRightClicked: menu.toggle()
    }

    // Tunnel indicator: the bar should say at a glance whether traffic is wrapped.
    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 3
        anchors.topMargin: 1
        visible: root.vpnUp
        text: "󰦝"
        color: Theme.accent
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 4
    }

    Popup {
        id: menu
        bar: root.bar
        owner: root
        cardWidth: 340
        cardHeight: 430

        onVisibleChanged: {
            root.askName = "";
            root.errorText = "";
            if (root.wifi)
                root.wifi.scannerEnabled = menu.visible;
            if (menu.visible)
                Networking.checkConnectivity();
        }

        Column {
            anchors.fill: parent
            spacing: 8

            Item {
                width: parent.width
                height: 32

                Text {
                    id: headIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.iconFor(root.active?.signalStrength ?? 0)
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                }

                Row {
                    id: headActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    BarButton {
                        hpad: 6
                        icon: Networking.wifiEnabled ? "󰖩" : "󰖪"
                        contentColor: Networking.wifiEnabled ? Theme.accent : Theme.muted
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }

                Column {
                    anchors.left: headIcon.right
                    anchors.leftMargin: 8
                    anchors.right: headActions.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: !Networking.wifiEnabled ? "Wi-Fi off" : root.active ? root.active.name : "Not connected"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        visible: root.active !== null
                        text: (root.wifi?.address ?? "") + (root.vpnUp ? "  󰦝 vpn" : "")
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                }
            }

            // Captive portals are why this widget exists; say so plainly.
            Rectangle {
                width: parent.width
                height: visible ? 26 : 0
                visible: root.portal
                radius: Theme.radius
                color: Theme.alpha(Theme.urgent, 0.15)

                Text {
                    anchors.centerIn: parent
                    text: "󰗹  sign-in required — open a browser"
                    color: Theme.urgent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 3
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }

            Text {
                width: parent.width
                visible: root.errorText !== ""
                text: root.errorText
                color: Theme.urgent
                wrapMode: Text.WordWrap
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 60 - (root.portal ? 34 : 0) - (root.errorText !== "" ? 24 : 0)
                clip: true
                spacing: 2
                model: root.networks

                delegate: Column {
                    required property var modelData

                    width: list.width
                    spacing: 4

                    Connections {
                        target: modelData

                        function onConnectionFailed(reason) {
                            if (reason === ConnectionFailReason.NoSecrets) {
                                root.askName = modelData.name;
                                root.errorText = modelData.known ? "Saved password rejected" : "";
                            } else {
                                root.errorText = modelData.name + ": " + ConnectionFailReason.toString(reason);
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 32
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
                                text: modelData.stateChanging ? "󰑓" : root.iconFor(modelData.signalStrength)
                                color: modelData.connected ? Theme.accent : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize

                                RotationAnimator on rotation {
                                    running: modelData.stateChanging
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 90
                                elide: Text.ElideRight
                                text: modelData.name
                                color: modelData.connected ? Theme.accent : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                font.bold: modelData.connected
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: modelData.known
                                text: "󰃀"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.locked(modelData.security)
                                text: "󰌾"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !forget.visible
                                text: Math.round(modelData.signalStrength * 100) + "%"
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
                            visible: modelData.known && !modelData.connected && (hover.containsMouse || containsMouse)
                            hpad: 4
                            icon: "󰩺"
                            contentColor: containsMouse ? Theme.urgent : Theme.muted
                            onClicked: modelData.forget()
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: visible ? 30 : 0
                        visible: root.askName === modelData.name
                        radius: Theme.radius
                        color: Theme.alpha(Theme.fg, 0.06)
                        border.width: 1
                        border.color: Theme.accent

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰌾"
                                color: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                            }

                            TextInput {
                                id: pw
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 60
                                echoMode: TextInput.Password
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                focus: root.askName === modelData.name

                                onAccepted: {
                                    root.errorText = "";
                                    root.askName = "";
                                    modelData.connectWithPsk(text);
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: pw.text === ""
                                    text: "password, then Enter"
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }

                            BarButton {
                                anchors.verticalCenter: parent.verticalCenter
                                hpad: 4
                                icon: "󰌑"
                                contentColor: Theme.accent
                                onClicked: {
                                    root.errorText = "";
                                    root.askName = "";
                                    modelData.connectWithPsk(pw.text);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
