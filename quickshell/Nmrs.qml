import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var bar

    property string appId: "nmrs-popup"
    property var status: null

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    readonly property var primary: root.status ? root.status.primary : null
    readonly property var wifi: root.status ? root.status.wifi : null
    readonly property bool portal: root.status ? root.status.connectivity === "portal" : false
    readonly property bool vpnUp: root.status ? root.status.vpn.length > 0 : false
    readonly property bool wifiOn: root.status ? root.status.radios.wifi.enabled : true

    function iconFor(strength) {
        if (strength >= 80)
            return "󰤨";
        if (strength >= 60)
            return "󰤥";
        if (strength >= 40)
            return "󰤢";
        if (strength >= 20)
            return "󰤟";
        return "󰤯";
    }

    function clip(s, n) {
        return s.length > n ? s.slice(0, n - 1) + "…" : s;
    }

    function open(page) {
        const cmd = ["nmrs-gui", "--toggle", "--app-id", root.appId, "--layout", "compact"];
        if (page)
            cmd.push("--page", page);
        Quickshell.execDetached(cmd);
    }

    readonly property string icon: {
        if (!root.status)
            return "󰤫";
        if (root.status.airplane)
            return "󰀝";
        if (root.portal)
            return "󰗹";
        if (!root.primary)
            return root.wifiOn ? "󰤭" : "󰤮";
        if (root.primary.kind === "ethernet")
            return "󰈀";
        return root.iconFor(root.wifi ? root.wifi.strength : 0);
    }

    readonly property string label: {
        if (!root.status)
            return "";
        if (root.status.airplane)
            return "airplane";
        if (!root.primary)
            return root.wifiOn ? "offline" : "off";
        return root.clip(root.primary.name, 16);
    }

    readonly property string details: {
        if (!root.status)
            return "nmrs-gui is not running";
        const lines = [];
        if (root.primary)
            lines.push(root.primary.name + " · " + root.primary.interface);
        if (root.wifi)
            lines.push(root.wifi.security + " · " + (root.wifi.band ?? "") + " · " + root.wifi.strength + "%" + (root.wifi.ip4 ? " · " + root.wifi.ip4 : ""));
        for (var i = 0; i < root.status.ethernet.length; i++) {
            const e = root.status.ethernet[i];
            lines.push(e.interface + (e.speed_mbps ? " · " + e.speed_mbps + " Mb/s" : "") + (e.ip4 ? " · " + e.ip4 : ""));
        }
        for (var j = 0; j < root.status.vpn.length; j++)
            lines.push("󰦝 " + root.status.vpn[j].name + " · " + root.status.vpn[j].kind);
        lines.push(root.status.connectivity);
        return lines.join("\n");
    }

    // One long-lived stream instead of polling nmcli; nmrs-gui pushes a line per change.
    Process {
        id: stream
        command: ["nmrs-gui", "--status", "--watch"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    root.status = JSON.parse(data);
                } catch (e) {}
            }
        }

        onExited: {
            root.status = null;
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: stream.running = true
    }

    BarButton {
        id: btn
        anchors.fill: parent

        icon: root.icon
        label: root.label
        contentColor: root.portal ? Theme.urgent : root.primary ? Theme.fg : Theme.muted

        onClicked: root.open()
        onRightClicked: root.open("vpn")
        onMiddleClicked: root.open("network")
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

    Tooltip {
        bar: root.bar
        owner: root
        show: btn.containsMouse
        text: root.details
    }
}
