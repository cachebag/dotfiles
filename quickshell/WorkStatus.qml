import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var bar

    property string tunnel: "?"
    property string proxy: "?"
    property int krb: -1

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    readonly property bool tunnelOk: tunnel === "up"
    readonly property bool proxyOk: proxy === "NA"
    readonly property bool krbOk: krb > 0
    // Under 30 minutes is worth surfacing before it bites mid-task.
    readonly property bool krbLow: krb > 0 && krb < 1800
    readonly property bool allOk: tunnelOk && proxyOk && krbOk && !krbLow

    function hhmm(secs) {
        if (secs <= 0)
            return "expired";
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        return h > 0 ? h + "h" + (m < 10 ? "0" : "") + m : m + "m";
    }

    // Worst problem first — the bar has room for one word.
    readonly property string summary: {
        if (!root.tunnelOk)
            return "vpn down";
        if (!root.krbOk)
            return "no ticket";
        if (root.krbLow)
            return "ticket " + root.hhmm(root.krb);
        if (!root.proxyOk)
            return root.proxy === "off" ? "proxy off" : "proxy " + root.proxy;
        return "";
    }

    Process {
        id: probe
        command: [Quickshell.shellPath("scripts/workstatus.sh")]

        stdout: StdioCollector {
            id: out
        }

        onExited: {
            const parts = String(out.text).trim().split(/\s+/);
            for (var i = 0; i < parts.length; i++) {
                const kv = parts[i].split(":");
                if (kv[0] === "TUNNEL")
                    root.tunnel = kv[1];
                else if (kv[0] === "PROXY")
                    root.proxy = kv[1];
                else if (kv[0] === "KRB")
                    root.krb = parseInt(kv[1]);
            }
        }
    }

    // Nothing here changes fast; 30s keeps it cheap.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: action
        onExited: probe.running = true
    }

    function run(argv) {
        action.command = argv;
        action.running = true;
    }

    // kinit prompts for a password, so it needs a terminal.
    function term(cmd) {
        root.run(["kitty", "zsh", "-ic", cmd]);
    }

    BarButton {
        id: btn
        anchors.fill: parent

        icon: root.allOk ? "󰕥" : "󰻍"
        label: root.summary
        contentColor: !root.tunnelOk || !root.krbOk ? Theme.urgent : root.krbLow || !root.proxyOk ? Theme.accent : Theme.muted
        active: panel.visible

        onClicked: panel.toggle()
        onRightClicked: panel.toggle()
    }

    Popup {
        id: panel
        bar: root.bar
        owner: root
        cardWidth: 320
        cardHeight: 250

        onVisibleChanged: if (visible)
            probe.running = true

        Column {
            anchors.fill: parent
            spacing: 8

            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.allOk ? "󰕥" : "󰻍"
                    color: root.allOk ? Theme.accent : Theme.urgent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Work access"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.line
            }

            // The chain in the order it actually breaks: tunnel, then proxy, then ticket.
            StatusRow {
                width: parent.width
                icon: "󰖂"
                title: "VPN tunnel"
                detail: root.tunnelOk ? "connected" : "disconnected"
                ok: root.tunnelOk
                actionText: root.tunnelOk ? "" : "connect"
                onTriggered: root.term("osd-vpn-connect")
            }

            StatusRow {
                width: parent.width
                icon: "󰒍"
                title: "Proxy"
                detail: root.proxy === "off" ? "not running" : root.proxy === "idle" ? "no upstream yet" : root.proxy
                ok: root.proxyOk
                actionText: root.proxyOk ? "" : "restart"
                onTriggered: root.run(["systemctl", "--user", "restart", "proxy.service"])
            }

            StatusRow {
                width: parent.width
                icon: "󰌾"
                title: "Kerberos"
                detail: root.krbOk ? "expires in " + root.hhmm(root.krb) : "no ticket"
                ok: root.krbOk && !root.krbLow
                actionText: root.krbOk && !root.krbLow ? "" : "kinit"
                onTriggered: root.term("kinit")
            }

            Item {
                width: parent.width
                height: 4
            }

            BarButton {
                anchors.horizontalCenter: parent.horizontalCenter
                hpad: 12
                icon: "󰑓"
                label: "run vpnfix"
                contentColor: containsMouse ? Theme.accent : Theme.muted
                onClicked: {
                    root.term("vpnfix");
                    panel.close();
                }
            }
        }
    }
}
