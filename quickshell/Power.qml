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

    // null until the first read, so startup never chimes.
    property var acOnline: null

    signal changed()

    function setOnline(v) {
        if (root.acOnline === false && v === true)
            chimeProc.running = true;
        root.acOnline = v;
    }

    FileView {
        path: root.acSupply + "/online"
        printErrors: false
        onLoaded: if (root.acOnline === null) root.setOnline(String(text()).trim() === "1")
    }

    Process {
        id: monitor
        running: true
        command: ["udevadm", "monitor", "--kernel", "--property", "--subsystem-match=power_supply"]

        property string dev: ""

        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("POWER_SUPPLY_NAME=")) {
                    monitor.dev = line.slice(18);
                } else if (line.startsWith("POWER_SUPPLY_ONLINE=") && monitor.dev === "macsmc-ac") {
                    root.setOnline(line.slice(20) === "1");
                } else if (line === "") {
                    // End of one event block.
                    monitor.dev = "";
                    burst.restart();
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
