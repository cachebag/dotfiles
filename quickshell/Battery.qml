import QtQuick
import Quickshell
import Quickshell.Services.UPower

Item {
    id: root

    required property var bar

    readonly property var battery: UPower.displayDevice
    readonly property bool available: battery.ready && battery.isLaptopBattery && battery.isPresent
    readonly property real percentage: Math.max(0, Math.min(1, battery.percentage))
    readonly property int percentageRounded: Math.round(percentage * 100)
    readonly property int state: battery.state
    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool discharging: state === UPowerDeviceState.Discharging || state === UPowerDeviceState.PendingDischarge
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property real secondsRemaining: charging ? battery.timeToFull : discharging ? battery.timeToEmpty : 0

    property bool showTime: false

    visible: available
    implicitWidth: available ? btn.implicitWidth : 0
    implicitHeight: Theme.barHeight - 8

    function levelIcon() {
        const icons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        const index = Math.min(icons.length - 1, Math.floor(percentage * icons.length));
        return icons[index];
    }

    function icon() {
        if (charging)
            return "󰂄";
        if (full)
            return "󰁹";
        return levelIcon();
    }

    function stateLabel() {
        switch (state) {
        case UPowerDeviceState.Charging:
            return "charging";
        case UPowerDeviceState.Discharging:
            return "discharging";
        case UPowerDeviceState.Empty:
            return "empty";
        case UPowerDeviceState.FullyCharged:
            return "fully charged";
        case UPowerDeviceState.PendingCharge:
            return "plugged in";
        case UPowerDeviceState.PendingDischarge:
            return "on battery";
        default:
            return UPower.onBattery ? "on battery" : "plugged in";
        }
    }

    function formatDuration(seconds) {
        if (!Number.isFinite(seconds) || seconds <= 0)
            return "";

        const totalMinutes = Math.max(1, Math.round(seconds / 60));
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours === 0)
            return minutes + "m";
        if (minutes === 0)
            return hours + "h";
        return hours + "h " + minutes + "m";
    }

    function contentColor() {
        if (charging || full)
            return Theme.accent;
        if (percentage <= 0.15)
            return Theme.urgent;
        if (percentage <= 0.30)
            return Theme.accentAlt;
        return Theme.fg;
    }

    function tooltipText() {
        const lines = [(percentage * 100).toFixed(1) + "% · " + stateLabel()];
        const duration = formatDuration(secondsRemaining);
        const rate = Math.abs(battery.changeRate);

        if (duration !== "")
            lines.push(duration + (charging ? " until full" : " remaining"));
        if (Number.isFinite(rate) && rate >= 0.1)
            lines.push("Power: " + rate.toFixed(rate < 10 ? 1 : 0) + " W");
        if (battery.energyCapacity > 0)
            lines.push("Energy: " + battery.energy.toFixed(1) + " / " + battery.energyCapacity.toFixed(1) + " Wh");
        if (battery.healthSupported && battery.healthPercentage > 0)
            lines.push("Health: " + battery.healthPercentage.toFixed(0) + "%");

        return lines.join("\n");
    }

    BarButton {
        id: btn
        anchors.fill: parent

        icon: root.icon()
        label: root.showTime && root.secondsRemaining > 0 ? root.formatDuration(root.secondsRemaining) : root.percentageRounded + "%"
        contentColor: root.contentColor()
        active: root.charging

        onClicked: root.showTime = !root.showTime
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: (parent.width - Theme.pad * 2) * root.percentage
        height: 2
        radius: 1
        color: root.contentColor()
        opacity: 0.85

        Behavior on width {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Theme.easeOut
            }
        }
    }

    Tooltip {
        bar: root.bar
        owner: btn
        show: btn.containsMouse
        text: root.tooltipText()
    }
}
