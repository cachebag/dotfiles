import QtQuick
import Quickshell
import Quickshell.Io

// Battery level and charge state, read straight from sysfs (no upower).
// Hidden on machines without a battery.
Item {
    id: root

    required property var bar

    // macsmc-battery on Apple Silicon (Asahi); BAT0 elsewhere.
    property string supply: "/sys/class/power_supply/macsmc-battery"

    readonly property bool present: capacityFile.loaded && capacity >= 0
    readonly property int capacity: {
        const n = parseInt(String(capacityFile.text()).trim());
        return isNaN(n) ? -1 : n;
    }
    readonly property string status: String(statusFile.text()).trim()
    // macsmc_power_fast reports AC online at connector insertion, ~0.4 s
    // before the charger finishes negotiating and the battery leaves
    // "Discharging". Treat that window as plugged in.
    // Likewise on unplug, AC goes offline before the battery status file is
    // re-read, so an offline charger overrides a stale "Full"/"Charging".
    readonly property bool unplugged: Power.acOnline === false
    readonly property bool pending: Power.acOnline === true && status === "Discharging"
    readonly property bool charging: !unplugged && (status === "Charging" || (pending && capacity < 95))
    readonly property bool full: !unplugged && (status === "Full" || ((status === "Not charging" || pending) && capacity >= 95))
    readonly property bool low: !charging && !full && capacity <= 15

    // µW and µWh from the kernel.
    readonly property real powerNow: parseFloat(String(powerFile.text()).trim()) || 0
    readonly property real energyNow: parseFloat(String(energyNowFile.text()).trim()) || 0
    readonly property real energyFull: parseFloat(String(energyFullFile.text()).trim()) || 0

    visible: present
    implicitWidth: present ? btn.implicitWidth : 0
    implicitHeight: Theme.barHeight - 8

    FileView { id: capacityFile;   path: root.supply + "/capacity";     printErrors: false }
    FileView { id: statusFile;     path: root.supply + "/status";       printErrors: false }
    FileView { id: powerFile;      path: root.supply + "/power_now";    printErrors: false }
    FileView { id: energyNowFile;  path: root.supply + "/energy_now";   printErrors: false }
    FileView { id: energyFullFile; path: root.supply + "/energy_full";  printErrors: false }

    function reloadAll() {
        capacityFile.reload();
        statusFile.reload();
        powerFile.reload();
        energyNowFile.reload();
        energyFullFile.reload();
    }

    // Plug/unplug and charge-state changes arrive as kernel uevents (Power.qml),
    // so they show up immediately.
    Connections {
        target: Power
        function onChanged() { root.reloadAll(); }
    }

    // Capacity and wattage drift without an event: keep a slow poll for those.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.reloadAll()
    }

    function levelIcon() {
        if (root.charging)
            return String.fromCodePoint(0xf0084);          // battery-charging
        if (root.full)
            return String.fromCodePoint(0xf06a5);          // power-plug
        if (root.capacity >= 95)
            return String.fromCodePoint(0xf0079);          // battery (full)
        if (root.capacity < 5)
            return String.fromCodePoint(0xf008e);          // battery-outline
        // battery-10 .. battery-90 are consecutive code points.
        const step = Math.max(0, Math.min(8, Math.floor(root.capacity / 10) - 1));
        return String.fromCodePoint(0xf007a + step);
    }

    function remaining() {
        if (root.powerNow <= 0)
            return "";
        let hours;
        if (root.charging)
            hours = (root.energyFull - root.energyNow) / root.powerNow;
        else if (!root.full)
            hours = root.energyNow / root.powerNow;
        else
            return "";
        if (!isFinite(hours) || hours <= 0 || hours > 48)
            return "";
        const h = Math.floor(hours);
        const m = Math.round((hours - h) * 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    function describe() {
        const watts = (root.powerNow / 1e6).toFixed(1) + " W";
        const left = root.remaining();
        if (root.charging)
            return "Charging, " + root.capacity + "%" + (left ? ", full in " + left : "") + " (" + watts + ")";
        if (root.full)
            return "Plugged in, " + root.capacity + "%";
        return "On battery, " + root.capacity + "%" + (left ? ", " + left + " left" : "") + " (" + watts + ")";
    }

    BarButton {
        id: btn
        anchors.fill: parent
        icon: root.levelIcon()
        label: root.capacity + "%"
        contentColor: root.low ? Theme.urgent : (root.charging ? Theme.accent : Theme.fg)
    }

    Tooltip {
        bar: root.bar
        owner: root
        show: btn.containsMouse
        text: root.describe()
    }
}
