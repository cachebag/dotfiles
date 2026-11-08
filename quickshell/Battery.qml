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

    // Detail files, only read while the panel is open.
    FileView { id: fullDesignFile; path: root.supply + "/energy_full_design";   printErrors: false }
    FileView { id: cyclesFile;     path: root.supply + "/cycle_count";          printErrors: false }
    FileView { id: tempFile;       path: root.supply + "/temp";                 printErrors: false }
    FileView { id: voltFile;       path: root.supply + "/voltage_now";          printErrors: false }
    FileView { id: healthFile;     path: root.supply + "/health";               printErrors: false }
    FileView { id: limitFile;      path: root.supply + "/charge_control_end_threshold"; printErrors: false }
    FileView { id: ttfFile;        path: root.supply + "/time_to_full_now";     printErrors: false }
    FileView { id: tteFile;        path: root.supply + "/time_to_empty_now";    printErrors: false }
    FileView { id: yearFile;       path: root.supply + "/manufacture_year";     printErrors: false }
    FileView { id: monthFile;      path: root.supply + "/manufacture_month";    printErrors: false }
    FileView { id: modelFile;      path: root.supply + "/model_name";           printErrors: false }
    FileView { id: adapterFile;    path: Power.acSupply + "/input_power_limit"; printErrors: false }

    function num(f) {
        const n = parseFloat(String(f.text()).trim());
        return isNaN(n) ? -1 : n;
    }

    readonly property real energyDesign: num(fullDesignFile)
    readonly property real healthPct: energyDesign > 0 && energyFull > 0 ? energyFull / energyDesign * 100 : -1
    readonly property int cycles: num(cyclesFile)
    readonly property real tempC: num(tempFile) / 10
    readonly property real volts: num(voltFile) / 1e6
    readonly property string healthText: String(healthFile.text()).trim()
    readonly property int limit: num(limitFile)
    readonly property real adapterW: num(adapterFile) / 1e6
    // SMC estimates in seconds; it reports 65535-ish junk when not applicable.
    readonly property real smcToFull: num(ttfFile)
    readonly property real smcToEmpty: num(tteFile)

    function reloadDetails() {
        for (const f of [fullDesignFile, cyclesFile, tempFile, voltFile, healthFile, limitFile,
                         ttfFile, tteFile, yearFile, monthFile, modelFile, adapterFile])
            f.reload();
    }

    function reloadAll() {
        capacityFile.reload();
        statusFile.reload();
        powerFile.reload();
        energyNowFile.reload();
        energyFullFile.reload();
        if (panel.visible)
            root.reloadDetails();
    }

    // Wattage over the last 10 minutes (one sample per 5 s poll), for the graph.
    property var history: []
    function sample() {
        const h = root.history.slice(-119);
        h.push(Math.abs(root.powerNow) / 1e6);
        root.history = h;
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
        triggeredOnStart: true
        onTriggered: {
            root.reloadAll();
            root.sample();
        }
    }

    // Ticks the "for 2h 14m" counters while the panel is open.
    property real now: Date.now()
    Timer {
        interval: 30000
        running: panel.visible
        repeat: true
        onTriggered: root.now = Date.now()
    }

    function dur(ms) {
        const m = Math.floor(ms / 60000);
        if (m < 1)
            return "<1m";
        const d = Math.floor(m / 1440), h = Math.floor(m % 1440 / 60), mm = m % 60;
        if (d > 0)
            return d + "d " + h + "h";
        return h > 0 ? h + "h " + mm + "m" : mm + "m";
    }

    function age() {
        const y = root.num(yearFile), mo = root.num(monthFile);
        if (y < 2000 || mo < 1)
            return "";
        const d = new Date();
        const months = (d.getFullYear() - y) * 12 + (d.getMonth() + 1 - mo);
        const yy = Math.floor(months / 12), m = months % 12;
        return yy > 0 ? yy + "y " + m + "mo" : m + "mo";
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
        const smc = root.charging ? root.smcToFull : (!root.full ? root.smcToEmpty : -1);
        if (smc > 0 && smc < 48 * 3600)
            return root.dur(smc * 1000);
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
        active: panel.visible

        onClicked: panel.toggle()
    }

    Tooltip {
        bar: root.bar
        owner: root
        show: btn.containsMouse && !panel.visible
        text: root.describe()
    }

    // ── Detail panel (BatStat / BatCaption / BatValue) ─────────────────────
    Popup {
        id: panel
        bar: root.bar
        owner: root
        cardWidth: 340
        cardHeight: body.implicitHeight + 28

        onVisibleChanged: if (visible) {
            root.now = Date.now();
            root.reloadDetails();
        }

        Column {
            id: body
            width: parent.width
            spacing: 12

            // Header: level and state.
            Row {
                width: parent.width
                spacing: 12

                Text {
                    text: root.levelIcon()
                    color: root.low ? Theme.urgent : (root.charging ? Theme.accent : Theme.fg)
                    font.family: Theme.font
                    font.pixelSize: 34
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: root.capacity + "%"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 26
                        font.bold: true
                    }
                    BatCaption {
                        font.pixelSize: Theme.fontSize - 1
                        text: {
                            const left = root.remaining();
                            if (root.charging)
                                return "Charging" + (left ? " · full in " + left : "");
                            if (root.full)
                                return "Plugged in · " + (root.limit > 0 && root.limit < 100 ? "held at " + root.limit + "%" : "fully charged");
                            return "On battery" + (left ? " · " + left + " left" : "");
                        }
                    }
                }
            }

            // Level bar.
            Rectangle {
                width: parent.width
                height: 6
                radius: 3
                color: Theme.line
                Rectangle {
                    width: parent.width * Math.max(0, root.capacity) / 100
                    height: parent.height
                    radius: parent.radius
                    color: root.low ? Theme.urgent : Theme.accent
                    Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Theme.easeOut } }
                }
                // Charge limit marker.
                Rectangle {
                    visible: root.limit > 0 && root.limit < 100
                    x: parent.width * root.limit / 100 - 1
                    width: 2
                    height: parent.height + 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    opacity: 0.6
                }
            }

            // Time in the current state.
            Rectangle {
                width: parent.width
                implicitHeight: sinceCol.implicitHeight + 18
                radius: Theme.radius
                color: Theme.alpha(Theme.fg, 0.04)
                border.width: 1
                border.color: Theme.line
                visible: Power.since > 0

                Column {
                    id: sinceCol
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 3

                    readonly property real elapsed: Math.max(0, root.now - Power.since)
                    readonly property real usedWh: (Power.sinceEnergy - root.energyNow) / 1e6
                    readonly property int usedPct: Power.sinceCapacity >= 0 ? Power.sinceCapacity - root.capacity : 0

                    Row {
                        spacing: 6
                        BatCaption { text: Power.acOnline ? "󰚥  ON CHARGER" : "󰂃  ON BATTERY" }
                        BatValue {
                            text: root.dur(sinceCol.elapsed)
                            font.bold: true
                            anchors.baseline: parent.children[0].baseline
                        }
                    }
                    BatCaption {
                        visible: text !== ""
                        text: {
                            const hrs = sinceCol.elapsed / 3600000;
                            if (Power.acOnline) {
                                const gained = -sinceCol.usedPct;
                                return gained > 0 ? "+" + gained + "% since plugged in (from " + Power.sinceCapacity + "%)" : "";
                            }
                            if (sinceCol.usedPct <= 0 && sinceCol.usedWh <= 0)
                                return "";
                            const avg = hrs > 0.05 ? " · avg " + (sinceCol.usedWh / hrs).toFixed(1) + " W" : "";
                            return "Used " + Math.max(0, sinceCol.usedPct) + "% (" + Math.max(0, sinceCol.usedWh).toFixed(1) + " Wh)" + avg;
                        }
                    }
                }
            }

            // Power graph.
            Column {
                width: parent.width
                spacing: 4

                Row {
                    width: parent.width
                    BatCaption { text: "󱐋  " + (root.charging ? "CHARGING AT" : "DRAWING"); width: parent.width - wattText.width }
                    BatValue {
                        id: wattText
                        text: (Math.abs(root.powerNow) / 1e6).toFixed(1) + " W"
                        font.bold: true
                    }
                }
                Canvas {
                    id: graph
                    width: parent.width
                    height: 46

                    property var data: root.history
                    property color stroke: root.charging ? Theme.accent : Theme.fg
                    onDataChanged: requestPaint()
                    onStrokeChanged: requestPaint()
                    onVisibleChanged: if (visible) requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const d = graph.data, n = d.length;
                        if (n < 2)
                            return;
                        const max = Math.max(5, ...d) * 1.15;
                        const step = width / 119;
                        const x0 = width - (n - 1) * step;
                        const y = v => height - 1 - v / max * (height - 2);

                        ctx.beginPath();
                        ctx.moveTo(x0, height);
                        for (let i = 0; i < n; i++)
                            ctx.lineTo(x0 + i * step, y(d[i]));
                        ctx.lineTo(width, height);
                        ctx.closePath();
                        ctx.fillStyle = Theme.alpha(stroke, 0.12);
                        ctx.fill();

                        ctx.beginPath();
                        for (let i = 0; i < n; i++)
                            i === 0 ? ctx.moveTo(x0, y(d[0])) : ctx.lineTo(x0 + i * step, y(d[i]));
                        ctx.lineWidth = 1.5;
                        ctx.strokeStyle = stroke;
                        ctx.stroke();
                    }
                }
                Row {
                    width: parent.width
                    BatCaption { text: "10 min ago"; width: parent.width - nowCap.width }
                    BatCaption { id: nowCap; text: "now" }
                }
            }

            // Stats.
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                readonly property real cell: (width - columnSpacing) / 2

                BatStat {
                    width: parent.cell
                    icon: "󰣐"
                    title: "Health"
                    value: root.healthPct >= 0 ? root.healthPct.toFixed(1) + "%" : "—"
                    sub: root.healthText && root.healthText !== "Good" ? root.healthText : (root.healthPct >= 80 ? "good" : root.healthPct >= 0 ? "service soon" : "")
                    tint: root.healthPct >= 0 && root.healthPct < 80 ? Theme.urgent : Theme.fg
                    fill: root.healthPct / 100
                }
                BatStat {
                    width: parent.cell
                    icon: "󰑓"
                    title: "Cycles"
                    value: root.cycles >= 0 ? root.cycles : "—"
                    sub: "of 1000"
                    fill: root.cycles >= 0 ? root.cycles / 1000 : -1
                    tint: root.cycles > 900 ? Theme.urgent : Theme.fg
                }
                BatStat {
                    width: parent.cell
                    icon: "󰔏"
                    title: "Temp"
                    value: root.tempC > 0 ? root.tempC.toFixed(1) + "°C" : "—"
                    tint: root.tempC >= 40 ? Theme.urgent : Theme.fg
                }
                BatStat {
                    width: parent.cell
                    icon: "󰚥"
                    title: "Adapter"
                    value: Power.acOnline && root.adapterW > 0 ? Math.round(root.adapterW) + " W" : "—"
                    sub: Power.acOnline ? "" : "unplugged"
                }
                BatStat {
                    width: parent.cell
                    icon: "󰂄"
                    title: "Energy"
                    value: (root.energyNow / 1e6).toFixed(1) + " Wh"
                    sub: "of " + (root.energyFull / 1e6).toFixed(1)
                }
                BatStat {
                    width: parent.cell
                    icon: "󱊦"
                    title: "Voltage"
                    value: root.volts > 0 ? root.volts.toFixed(2) + " V" : "—"
                }
            }

            // Footer.
            Row {
                width: parent.width
                BatCaption {
                    width: parent.width - limitCap.width - (limitCap.text ? 8 : 0)
                    elide: Text.ElideRight
                    text: {
                        const parts = [];
                        const design = root.energyDesign / 1e6;
                        if (design > 0)
                            parts.push(design.toFixed(1) + " Wh design");
                        const a = root.age();
                        if (a)
                            parts.push(a + " old");
                        const m = String(modelFile.text()).trim();
                        if (m)
                            parts.push(m);
                        return parts.join(" · ");
                    }
                }
                BatCaption {
                    id: limitCap
                    text: root.limit > 0 && root.limit < 100 ? "limit " + root.limit + "%" : ""
                }
            }
        }
    }
}
