pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Charger / battery change events, pushed by the kernel instead of polled.
//
// macsmc-power (Asahi) calls power_supply_changed() on every SMC power event,
// which sends a KOBJ_CHANGE uevent on the kernel netlink socket within a few
// ms of the plug moving. `udevadm monitor --kernel` reads that socket (no root
// needed) and flushes one block per event, so we see the charger as soon as
// USB-PD finishes negotiating (~0.4 s after insertion on a J514S), not on
// the next 5 s poll.
//
// `changed()` fires after each burst so readers can reload their sysfs files.
// Plugging in plays macOS's charger chime from `chime` below, if present.
// It's Apple's file, so it isn't in this repo: copy it from the macOS system
// volume, /System/Library/CoreServices/PowerChime.app/Contents/Resources/
// connect_power.aif.
Singleton {
    id: root

    property string acSupply: "/sys/class/power_supply/macsmc-ac"
    property string chime: Quickshell.env("HOME") + "/.local/share/sounds/macos/connect_power.aif"

    property string batSupply: "/sys/class/power_supply/macsmc-battery"

    // null until the first read, so startup never chimes.
    property var acOnline: null

    // When the charger last connected or disconnected (ms since epoch), and
    // the battery level at that moment. Kept in ~/.cache so a quickshell
    // restart doesn't reset it; if the saved state doesn't match (e.g. it
    // changed while powered off), it starts counting from now.
    property real since: 0
    property real sinceEnergy: 0     // µWh
    property int sinceCapacity: -1

    signal changed()

    function setOnline(v) {
        if (root.acOnline === v)
            return;
        if (root.acOnline === false && v === true)
            chimeProc.running = true;
        const first = root.acOnline === null;
        root.acOnline = v;
        if (first && root.restoreSince(v))
            return;
        root.markSince(v);
    }

    function markSince(v) {
        energyFile.reload();
        capFile.reload();
        root.since = Date.now();
        root.sinceEnergy = parseFloat(String(energyFile.text()).trim()) || 0;
        root.sinceCapacity = parseInt(String(capFile.text()).trim());
        sinceFile.setText(JSON.stringify({
            online: v,
            since: root.since,
            energy: root.sinceEnergy,
            capacity: root.sinceCapacity
        }));
    }

    function restoreSince(v) {
        try {
            const d = JSON.parse(sinceFile.text());
            if (d.online !== v || !(d.since > 0) || d.since > Date.now())
                return false;
            root.since = d.since;
            root.sinceEnergy = d.energy || 0;
            root.sinceCapacity = d.capacity ?? -1;
            return true;
        } catch (e) {
            return false;
        }
    }

    FileView { id: energyFile; path: root.batSupply + "/energy_now"; blockLoading: true; printErrors: false }
    FileView { id: capFile;    path: root.batSupply + "/capacity";   blockLoading: true; printErrors: false }
    FileView {
        id: sinceFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/ac-since.json"
        blockLoading: true
        printErrors: false
    }

    FileView {
        path: root.acSupply + "/online"
        printErrors: false
        onLoaded: if (root.acOnline === null) root.setOnline(String(text()).trim() === "1")
    }

    Process {
        id: monitor
        running: true
        // stdbuf: into a pipe udevadm's stdout is block-buffered, so the tail
        // of a burst (the one that flips ONLINE=1) sat in the buffer until the
        // next event ~1.5 s later. Line-buffer it.
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--kernel", "--property", "--subsystem-match=power_supply"]

        property string dev: ""

        stdout: SplitParser {
            onRead: line => {
                // Every line pushes the reload out; it fires 15 ms after the
                // burst goes quiet. (Don't key this on the blank line between
                // events: SplitParser doesn't reliably deliver empty lines.)
                burst.restart();
                if (line.startsWith("KERNEL[")) {
                    monitor.dev = "";
                } else if (line.startsWith("POWER_SUPPLY_NAME=")) {
                    monitor.dev = line.slice(18);
                } else if (line.startsWith("POWER_SUPPLY_ONLINE=") && monitor.dev === "macsmc-ac") {
                    root.setOnline(line.slice(20) === "1");
                }
            }
        }

        // Shouldn't exit; if it does, restart it.
        onExited: respawn.start()
    }
    Timer { id: respawn; interval: 1000; onTriggered: monitor.running = true }

    // SMC events arrive in bursts of ~10 within a few ms; reload once per burst.
    Timer { id: burst; interval: 15; onTriggered: root.changed() }

    Process {
        id: chimeProc
        command: ["pw-play", root.chime]
    }
}
