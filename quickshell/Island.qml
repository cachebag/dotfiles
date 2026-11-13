import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// Dynamic Island, one per monitor. A pure-black capsule that reserves a strip at
// the top so windows sit below it; larger states overlay windows.
//   rest     – small capsule. Active media: art on the left, waveform on the right,
//              middle left empty (the iPhone "compact" layout). Privacy dot trailing.
//   compact  – wider capsule for quick values: volume meter, workspace number
//   banner   – medium rounded panel: bluetooth, mic mute, notifications
//   expanded – on hover: full player, or clock + what is using the mic/camera,
//              plus a toolbar (do not disturb, wallpapers)
//   walls    – wallpaper grid; `qs ipc call island walls`, Esc or leaving closes it
//   music    – Apple Music panel (MusicPanel.qml); `qs ipc call island music`
// Right-click toggles do not disturb (`qs ipc call island dnd`).
PanelWindow {
    id: win

    // ---- placement --------------------------------------------------------

    required property var modelData
    screen: modelData

    readonly property var monitor: Hyprland.monitorFor(modelData)
    // Pop-ups only on the monitor you're working on; hover works on any of them.
    property bool focused: Hyprland.focusedMonitor === monitor
    visible: !(monitor?.activeWorkspace?.hasFullscreen ?? false)

    readonly property int restH: 32
    readonly property int restY: 4

    // Full width so the lyric capsule beside the island has room to grow;
    // the input mask keeps everything but the pills click-through.
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 560
    exclusiveZone: restH + restY * 2
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-island"
    // Keyboard only while a panel is open (arrows, typing, Enter, Esc).
    WlrLayershell.keyboardFocus: panel !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only the island itself takes input; the rest of the window is click-through.
    mask: Region {
        item: hit
    }

    // ---- media ------------------------------------------------------------

    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0)
            return null;
        for (var i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i];
        return ps[0];
    }
    // One media source for the whole island. Apple Music's bridge wins while it
    // is playing, or when it has a track and nothing else is playing; Chromium's
    // MPRIS for that page only carries the window title and no artwork.
    readonly property bool amActive: AppleMusic.hasItem && (AppleMusic.playing || !(player?.isPlaying ?? false))
    readonly property bool hasMedia: amActive || (player !== null && (player.trackTitle ?? "") !== "")
    readonly property bool playing: amActive ? AppleMusic.playing : (player?.isPlaying ?? false)
    readonly property string art: amActive ? (AppleMusic.artFile || AppleMusic.artUrl) : (player?.trackArtUrl ?? "")
    readonly property string title: amActive ? AppleMusic.item.name : (player?.trackTitle ?? "")
    readonly property string artist: amActive ? AppleMusic.item.artist : (player?.trackArtist ?? "")
    readonly property real mediaLength: amActive ? AppleMusic.duration : (player?.length ?? 0)
    readonly property real mediaPosition: amActive ? AppleMusic.position : (player?.position ?? 0)
    readonly property bool canSeek: amActive || (player?.canSeek ?? false)
    readonly property bool canPrev: amActive || (player?.canGoPrevious ?? false)
    readonly property bool canNext: amActive || (player?.canGoNext ?? false)
    readonly property bool canToggle: amActive || (player?.canTogglePlaying ?? false)
    function mediaToggle() {
        amActive ? AppleMusic.toggle() : player?.togglePlaying();
    }
    function mediaPrev() {
        amActive ? AppleMusic.prev() : player?.previous();
    }
    function mediaNext() {
        amActive ? AppleMusic.next() : player?.next();
    }
    function mediaSeek(t) {
        if (amActive)
            AppleMusic.seek(t);
        else if (player)
            player.position = t;
    }
    // Browsers often hand over a black frame as "art"; treat that as no art.
    readonly property bool artUsable: art !== "" && (!art.startsWith("file://") || (quant.colors ?? []).some(c => c.hsvValue > 0.1))

    ColorQuantizer {
        id: quant
        source: win.art.startsWith("file://") ? win.art : ""
        depth: 3
        rescaleSize: 48
    }

    // Most saturated, not-too-dark swatch from the cover; theme accent otherwise.
    readonly property color glow: {
        const cs = quant.colors ?? [];
        var best = null, score = -1;
        for (var i = 0; i < cs.length; i++) {
            const c = cs[i];
            const s = c.hsvSaturation * (0.35 + c.hsvValue);
            if (c.hsvValue > 0.25 && s > score) {
                score = s;
                best = c;
            }
        }
        return best ? Qt.hsva(best.hsvHue, Math.min(1, best.hsvSaturation * 1.15), Math.max(0.65, best.hsvValue), 1) : Theme.accent;
    }

    Timer {
        // MPRIS position is not pushed; nudge the binding while it is on screen.
        interval: 500
        repeat: true
        running: win.mode === "expanded" && win.playing && !win.amActive
        onTriggered: win.player?.positionChanged()
    }

    // ---- audio ------------------------------------------------------------

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    PwObjectTracker {
        objects: [win.sink, win.source]
    }

    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    function volIcon() {
        if (muted || vol <= 0.001)
            return "󰖁";
        return vol < 0.34 ? "󰕿" : vol < 0.67 ? "󰖀" : "󰕾";
    }
    function showVolume() {
        if (!ready)
            return;
        pop({
            kind: "compact",
            prio: 2,
            ms: 1600,
            icon: volIcon(),
            text: muted ? "Muted" : Math.round(vol * 100) + "%",
            value: muted ? 0 : Math.min(1, vol)
        });
    }
    onVolChanged: showVolume()
    onMutedChanged: showVolume()
    onMicMutedChanged: {
        if (ready)
            pop({
                kind: "banner",
                prio: 2,
                ms: 1600,
                icon: micMuted ? "󰍭" : "󰍬",
                tint: micMuted ? Theme.urgent : "",
                text: micMuted ? "Microphone muted" : "Microphone on"
            });
    }

    // ---- privacy ----------------------------------------------------------

    // Node properties stay empty until the node is tracked.
    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(n => n.isStream || String(n.name).indexOf("xdph") === 0)
    }

    function appsOf(pred) {
        const out = [];
        const ns = Pipewire.nodes.values;
        for (var i = 0; i < ns.length; i++) {
            const n = ns[i];
            const p = n.properties ?? {};
            if (!pred(n, p))
                continue;
            var name = p["application.name"] || n.description || n.name || "?";
            // Chromium/Electron voice streams all report "WEBRTC VoiceEngine".
            if (/webrtc/i.test(name) && p["application.process.binary"])
                name = p["application.process.binary"];
            name = name.charAt(0).toUpperCase() + name.slice(1);
            if (out.indexOf(name) === -1)
                out.push(name);
        }
        return out;
    }
    readonly property var micApps: appsOf((n, p) => p["media.class"] === "Stream/Input/Audio")
    readonly property var camApps: appsOf((n, p) => p["media.class"] === "Stream/Input/Video" || (p["media.class"] === "Video/Source" && String(n.name).indexOf("xdph") === 0))
    readonly property bool micOn: micApps.length > 0
    readonly property bool camOn: camApps.length > 0
    readonly property color micColor: "#ff9f0a"
    readonly property color camColor: "#30d158"

    // ---- bluetooth --------------------------------------------------------

    property var btPrev: []
    readonly property var btNow: Bluetooth.devices.values.filter(d => d.connected)
    onBtNowChanged: {
        const prevAddr = btPrev.map(d => d.address);
        const nowAddr = btNow.map(d => d.address);
        if (ready) {
            const added = btNow.filter(d => prevAddr.indexOf(d.address) === -1);
            const gone = btPrev.filter(d => nowAddr.indexOf(d.address) === -1);
            if (added.length > 0) {
                const d = added[0];
                pop({
                    kind: "banner",
                    prio: 3,
                    ms: 3000,
                    icon: "󰂱",
                    tint: Theme.accent,
                    text: d.name || d.deviceName || "Bluetooth device",
                    sub: d.batteryAvailable ? "Connected · " + Math.round(d.battery * 100) + "%" : "Connected"
                });
            } else if (gone.length > 0) {
                pop({
                    kind: "banner",
                    prio: 3,
                    ms: 2500,
                    icon: "󰂲",
                    text: gone[0].name,
                    sub: "Disconnected"
                });
            }
        }
        // Snapshot plain data: device objects can vanish after disconnect.
        btPrev = btNow.map(d => ({
                    address: d.address,
                    name: d.name || d.deviceName || "Bluetooth device"
                }));
    }

    // ---- workspace / notifications ----------------------------------------

    readonly property int wsId: Hyprland.focusedWorkspace?.id ?? 0
    onWsIdChanged: {
        if (ready && wsId > 0)
            pop({
                kind: "compact",
                prio: 0,
                ms: 900,
                icon: "󰍹",
                text: String(wsId)
            });
    }

    property int lastToast: 0
    Connections {
        target: Notifications
        function onToastsChanged() {
            const t = Notifications.toasts[0];
            if (!t || t.key <= win.lastToast)
                return;
            win.lastToast = t.key;
            win.pop({
                kind: "banner",
                prio: 3,
                ms: 3000,
                image: t.image || "",
                appIcon: t.appIcon || "",
                text: t.summary || t.appName,
                sub: t.appName
            });
        }
    }

    // ---- do not disturb ---------------------------------------------------

    readonly property bool dnd: Notifications.dnd
    readonly property color dndColor: "#bf5af2"
    onDndChanged: {
        if (ready)
            pop({
                kind: "compact",
                prio: 3,
                ms: 1600,
                icon: "󰽥",
                tint: dnd ? dndColor : "",
                text: dnd ? "Focus on" : "Focus off"
            });
    }
    function toggleDnd() {
        Notifications.dnd = !Notifications.dnd;
    }

    // ---- wallpapers -------------------------------------------------------

    readonly property string wallDir: Quickshell.env("HOME") + "/wallpapers"
    readonly property string thumbDir: Quickshell.env("HOME") + "/.cache/quickshell/wall-thumbs"
    // Panels take over the island until Esc, a click away or the mouse leaves.
    property string panel: ""
    readonly property bool walls: panel === "walls"
    property string applying: ""

    function closePanel() {
        panel = "";
        panelClose.stop();
    }

    function openWalls() {
        thumbs.running = true;
        panel = "walls";
        wallPicker.open();
    }
    function openMusic() {
        if (!AppleMusic.connected) {
            AppleMusic.launch();
            pop({
                kind: "compact",
                prio: 3,
                ms: 2500,
                icon: "󰀵",
                tint: "#fc3c44",
                text: "Opening"
            });
            return;
        }
        panel = "music";
        musicPanel.open();
    }

    FileView {
        id: currentWall
        path: Quickshell.env("HOME") + "/.config/hypr/current_wallpaper"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property string wallNow: currentWall.text().trim()

    // Builds any missing thumbnails; cheap when they all exist.
    Process {
        id: thumbs
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/wall-thumbs.sh"]
    }

    Process {
        id: wallApply
        onExited: {
            win.applying = "";
            Theme.reload();
        }
    }
    function applyWall(path) {
        if (wallApply.running)
            return;
        applying = path;
        wallApply.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh", path];
        wallApply.running = true;
    }

    Timer {
        id: panelClose
        interval: 450
        onTriggered: win.closePanel()
    }

    IpcHandler {
        target: "island"
        // Every monitor has an island; only the focused one answers.
        enabled: win.focused

        function walls(): void {
            win.walls ? win.closePanel() : win.openWalls();
        }
        function music(): void {
            win.panel === "music" ? win.closePanel() : win.openMusic();
        }
        function dnd(): void {
            win.toggleDnd();
        }
    }

    // ---- state machine ----------------------------------------------------

    // Swallow the burst of "changes" that every binding reports on startup.
    property bool ready: false
    Timer {
        interval: 1500
        running: true
        onTriggered: win.ready = true
    }

    property var cur: null
    function pop(p) {
        if (cur && popTimer.running && (cur.prio ?? 0) > (p.prio ?? 0) && cur.kind !== p.kind)
            return;
        cur = p;
        popTimer.interval = p.ms ?? 2000;
        popTimer.restart();
    }
    Timer {
        id: popTimer
        onTriggered: win.cur = null
    }

    property bool hovering: false
    Timer {
        id: hoverIn
        interval: 60
        onTriggered: win.hovering = true
    }
    Timer {
        id: hoverOut
        interval: 120
        onTriggered: win.hovering = false
    }

    readonly property int morph: 280
    readonly property string mode: panel !== "" ? panel : hovering ? "expanded" : (cur && focused) ? cur.kind : "rest"

    // ---- geometry ---------------------------------------------------------

    readonly property bool active: hasMedia || micOn || camOn
    readonly property real wallsW: Math.min(win.width - 20, 840)
    readonly property real targetW: {
        switch (mode) {
        case "walls":
            return wallsW;
        case "music":
            return 440;
        case "expanded":
            return hasMedia ? 420 : 300;
        case "banner":
            return Math.max(300, Math.min(440, bannerText.implicitWidth + 96));
        case "compact":
            return Math.max(250, compactText.implicitWidth + 80);
        default:
            return hasMedia ? 210 : (active || dnd) ? 150 : 124;
        }
    }
    readonly property real targetH: {
        switch (mode) {
        case "walls":
            return wallPicker.implicitHeight + 36;
        case "music":
            return musicPanel.implicitHeight + 36;
        case "expanded":
            return (hasMedia ? 176 : (micOn || camOn ? 112 : 84)) + 48;
        case "banner":
            return 64;
        default:
            return restH;
        }
    }

    // ---- lyrics capsule: the current line, beside the resting island --------
    // Outside `hit`, so it never takes input; fades while the island is bigger.

    readonly property var lyricLines: AppleMusic.lines
    readonly property real lyricPos: AppleMusic.livePos + 0.08  // render lead
    readonly property int lyricCur: {
        const ls = win.lyricLines;
        var i = -1;
        for (var k = 0; k < ls.length; k++) {
            if (ls[k].b <= win.lyricPos)
                i = k;
            else
                break;
        }
        return i;
    }
    readonly property bool lyricGap: lyricCur < 0 || (win.lyricPos > lyricLines[lyricCur].e + 2.5 && (lyricCur + 1 >= lyricLines.length || lyricLines[lyricCur + 1].b - lyricLines[lyricCur].e > 4))
    readonly property bool lyricShown: AppleMusic.lyricsOn && AppleMusic.hasLyrics && win.mode === "rest"

    function esc(s) {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    // Each word a span; grey level encodes progress on its own beat.
    readonly property string lyricHtml: {
        if (lyricCur < 0)
            return "";
        const line = lyricLines[lyricCur];
        if (!line.w.length)
            return esc(line.t);
        var html = "";
        for (var k = 0; k < line.w.length; k++) {
            const w = line.w[k];
            const prog = Math.max(0, Math.min(1, (lyricPos - w.b) / Math.max(0.05, w.e - w.b)));
            const v = Math.round(255 * (0.45 + 0.55 * prog)).toString(16).padStart(2, "0");
            html += '<font color="#' + v + v + v + '">' + esc(w.t) + "</font>" + (w.sp ? " " : "");
        }
        return html;
    }
    onLyricCurChanged: lyricIn.restart()

    Rectangle {
        id: lyric
        x: hit.x + hit.width + 2
        y: win.restY
        height: win.restH
        // As wide as the line needs; the screen edge is the only limit.
        readonly property real room: win.width - x - 8
        width: win.lyricGap ? 46 : Math.min(room, lyricText.implicitWidth + 28)
        radius: height / 2
        color: "#000000"
        opacity: win.lyricShown ? 1 : 0
        visible: opacity > 0
        clip: true

        Behavior on width {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Theme.easeOut
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fast
            }
        }

        Text {
            id: lyricText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, lyric.width - 28)
            visible: !win.lyricGap
            maximumLineCount: 1
            elide: Text.ElideRight
            textFormat: Text.StyledText
            text: win.lyricHtml
            color: "#ffffff"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 1

            // New line: nudge up into place.
            transform: Translate {
                id: lyricSlide
            }
            SequentialAnimation {
                id: lyricIn
                PropertyAction {
                    target: lyricSlide
                    property: "y"
                    value: 6
                }
                NumberAnimation {
                    target: lyricSlide
                    property: "y"
                    to: 0
                    duration: Theme.normal
                    easing.type: Theme.easeOut
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: win.lyricGap
            text: "•••"
            color: "#ffffff"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            SequentialAnimation on opacity {
                running: win.lyricGap && win.lyricShown
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.3
                    duration: 900
                }
                NumberAnimation {
                    to: 1
                    duration: 900
                }
            }
        }
    }

    // Hover/input area: the island plus a margin, reaching the screen edge so
    // the top centre is a reliable hover target. The island is a child of it,
    // so hovering the island's buttons still counts as hovering this.
    // Sized from the target (not animated) size to avoid a binding loop.
    Item {
        id: hit
        x: Math.round((win.width - win.targetW) / 2) - 6
        y: 0
        width: win.targetW + 12
        height: win.restY + win.targetH + 6

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    hoverOut.stop();
                    panelClose.stop();
                    hoverIn.restart();
                } else {
                    hoverIn.stop();
                    hoverOut.restart();
                    if (win.panel !== "")
                        panelClose.restart();
                }
            }
        }

    // Shader-drawn shadow: no offscreen layer, no per-frame blur.
    RectangularShadow {
        anchors.fill: island
        radius: island.radius
        blur: 28
        offset: Qt.vector2d(0, 4)
        color: Qt.rgba(0, 0, 0, win.mode === "rest" ? 0 : 0.55)
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }

    Rectangle {
        id: island

        width: win.targetW
        height: win.targetH
        x: Math.round((win.width - width) / 2) - hit.x
        y: win.restY
        radius: win.mode === "expanded" || win.panel !== "" ? 40 : height / 2
        color: "#000000"
        clip: true

        // One fixed-length ease with a small overshoot: every morph lands at
        // the same moment, unlike a spring that keeps wobbling as it settles.
        Behavior on width {
            NumberAnimation {
                duration: win.morph
                easing.type: Easing.OutBack
                easing.overshoot: 0.9
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: win.morph
                easing.type: Easing.OutBack
                easing.overshoot: 0.9
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: win.morph
                easing.type: Theme.easeOut
            }
        }

        // ---- rest: leading art, empty middle, trailing waveform/dots ----
        Item {
            anchors.fill: parent
            opacity: win.mode === "rest" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }

            Cover {
                anchors.left: parent.left
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                visible: win.hasMedia
                size: 20
                radius: 6
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: win.dnd && !win.hasMedia
                text: "󰽥"
                color: win.dndColor
                font.family: Theme.font
                font.pixelSize: 15
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 13
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: win.dnd && win.hasMedia
                    text: "󰽥"
                    color: win.dndColor
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Dot {
                    visible: win.micOn
                    color: win.micColor
                }
                Dot {
                    visible: win.camOn
                    color: win.camColor
                }
                Wave {
                    visible: win.hasMedia
                    active: win.playing && win.mode === "rest" && win.visible
                    color: win.glow
                }
            }
        }

        // ---- compact: leading glyph, trailing value ----
        Item {
            anchors.fill: parent
            opacity: win.mode === "compact" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }

            readonly property var p: win.mode === "compact" ? win.cur : ({})

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: parent.p?.icon ?? ""
                color: parent.p?.tint ? parent.p.tint : "#ffffff"
                font.family: Theme.font
                font.pixelSize: 16
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.p?.value !== undefined
                width: 72
                height: 5
                radius: 2.5
                color: Qt.rgba(1, 1, 1, 0.18)
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: parent.width * (parent.parent.p?.value ?? 0)
                    color: "#ffffff"
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                }
            }
            Text {
                id: compactText
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.p?.value === undefined
                text: parent.p?.text ?? ""
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
            }
        }

        // ---- banner: icon, title, subtitle ----
        Item {
            id: bannerBox
            anchors.fill: parent
            opacity: win.mode === "banner" ? 1 : 0
            visible: opacity > 0 || win.mode === "banner"
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }

            readonly property var p: win.cur ?? ({})
            readonly property string img: p.image ? p.image : p.appIcon ? (p.appIcon.startsWith("/") ? "file://" + p.appIcon : Quickshell.iconPath(p.appIcon, true)) : ""

            ClippingRectangle {
                id: bannerIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 20
                color: Qt.rgba(1, 1, 1, 0.1)
                Image {
                    anchors.fill: parent
                    visible: bannerBox.img !== ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(80, 80)
                    source: bannerBox.img
                }
                Text {
                    anchors.centerIn: parent
                    visible: bannerBox.img === ""
                    text: bannerBox.p.icon ?? "󰂚"
                    color: bannerBox.p.tint ? bannerBox.p.tint : "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: 18
                }
            }

            Column {
                id: bannerText
                anchors.left: bannerIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    width: Math.min(implicitWidth, 320)
                    elide: Text.ElideRight
                    text: bannerBox.p.text ?? ""
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }
                Text {
                    visible: text !== ""
                    width: Math.min(implicitWidth, 320)
                    elide: Text.ElideRight
                    text: bannerBox.p.sub ?? ""
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
            }
        }

        // ---- expanded ----
        Item {
            anchors.fill: parent
            anchors.margins: 20
            anchors.topMargin: 18
            anchors.bottomMargin: 66
            opacity: win.mode === "expanded" ? 1 : 0
            visible: opacity > 0 || win.mode === "expanded"
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }

            // Player.
            Item {
                anchors.fill: parent
                visible: win.hasMedia

                Cover {
                    id: bigCover
                    size: 52
                    radius: 12
                }

                Column {
                    anchors.left: bigCover.right
                    anchors.leftMargin: 12
                    anchors.right: bigWave.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: bigCover.verticalCenter
                    spacing: 2
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: win.title
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize + 1
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: win.artist
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                }

                Wave {
                    id: bigWave
                    anchors.right: parent.right
                    anchors.verticalCenter: bigCover.verticalCenter
                    active: win.playing && win.mode === "expanded"
                    color: win.glow
                }

                // Scrubber.
                Item {
                    id: seek
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: bigCover.bottom
                    anchors.topMargin: 16
                    height: 14

                    readonly property real len: win.mediaLength
                    readonly property real posn: win.mediaPosition
                    readonly property real frac: len > 0 ? Math.max(0, Math.min(1, posn / len)) : 0

                    function fmt(s) {
                        s = Math.max(0, Math.floor(s));
                        const m = Math.floor(s / 60), r = s % 60;
                        return m + ":" + (r < 10 ? "0" : "") + r;
                    }

                    Text {
                        id: tPos
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: seek.fmt(seek.posn)
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                    Text {
                        id: tLeft
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: seek.len > 0 ? "-" + seek.fmt(seek.len - seek.posn) : "--:--"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                    Rectangle {
                        id: track
                        anchors.left: tPos.right
                        anchors.leftMargin: 10
                        anchors.right: tLeft.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: seekMouse.containsMouse ? 7 : 5
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.18)
                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.fast
                            }
                        }
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * seek.frac
                            color: "#ffffff"
                        }
                        MouseArea {
                            id: seekMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            enabled: win.canSeek
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: m => {
                                const f = Math.max(0, Math.min(1, (m.x - 6) / track.width));
                                win.mediaSeek(f * seek.len);
                            }
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    spacing: 44
                    Ctl {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰒮"
                        size: 22
                        enabled: win.canPrev
                        onClicked: win.mediaPrev()
                    }
                    Ctl {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: win.playing ? "󰏤" : "󰐊"
                        size: 30
                        enabled: win.canToggle
                        onClicked: win.mediaToggle()
                    }
                    Ctl {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰒭"
                        size: 22
                        enabled: win.canNext
                        onClicked: win.mediaNext()
                    }
                }
            }

            // No media: clock + privacy.
            Column {
                anchors.centerIn: parent
                visible: !win.hasMedia
                spacing: 4

                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: 24
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
                PrivacyLine {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: win.micOn
                    color: win.micColor
                    glyph: "󰍬"
                    apps: win.micApps
                }
                PrivacyLine {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: win.camOn
                    color: win.camColor
                    glyph: "󰄀"
                    apps: win.camApps
                }
            }
        }

        // Toolbar under the expanded view.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            spacing: 10
            opacity: win.mode === "expanded" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }

            Chip {
                glyph: "󰽥"
                label: "Focus"
                on: win.dnd
                tint: win.dndColor
                onClicked: win.toggleDnd()
            }
            Chip {
                glyph: "󰸉"
                label: "Wallpapers"
                onClicked: win.openWalls()
            }
            Chip {
                glyph: "󰀵"
                label: "Music"
                tint: "#fc3c44"
                on: AppleMusic.playing
                onClicked: win.openMusic()
            }
        }

        // ---- walls: filterable thumbnail grid ----
        WallPicker {
            id: wallPicker
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 18
            // Fixed (not the morphing island width): the grid lays out once.
            width: win.wallsW - 36
            dir: win.wallDir
            thumbDir: win.thumbDir
            current: win.wallNow
            applying: win.applying
            onPick: path => win.applyWall(path)
            onClose: win.closePanel()
            opacity: win.mode === "walls" ? 1 : 0
            visible: opacity > 0 || win.mode === "walls"
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }
        }

        // ---- music: Apple Music panel ----
        MusicPanel {
            id: musicPanel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            opacity: win.mode === "music" ? 1 : 0
            visible: opacity > 0 || win.mode === "music"
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.fast
                }
            }
            onClose: win.closePanel()
        }

        // Right-click anywhere toggles do not disturb.
        TapHandler {
            acceptedButtons: Qt.RightButton
            enabled: win.panel === ""
            onTapped: win.toggleDnd()
        }

        // Scroll anywhere on the island for volume.
        WheelHandler {
            enabled: win.panel === ""
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                if (!win.sink?.audio)
                    return;
                const step = e.angleDelta.y > 0 ? 0.05 : -0.05;
                win.sink.audio.volume = Math.max(0, Math.min(1, win.sink.audio.volume + step));
            }
        }
    }

    }

    // ---- small components -------------------------------------------------

    component Dot: Rectangle {
        anchors.verticalCenter: parent?.verticalCenter
        width: 6
        height: 6
        radius: 3
    }

    // Album art, or a note on a tinted square when there is none.
    component Cover: ClippingRectangle {
        id: cov
        property int size: 20
        width: size
        height: size
        color: Theme.alpha(win.glow, 0.2)
        Text {
            anchors.centerIn: parent
            visible: !win.artUsable
            text: "󰎈"
            color: win.glow
            font.family: Theme.font
            font.pixelSize: cov.size * 0.6
        }
        Image {
            anchors.fill: parent
            visible: win.artUsable
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(cov.size * 2, cov.size * 2)
            source: win.art
        }
    }

    component Ctl: Text {
        id: ctl
        property string glyph
        property int size: 16
        signal clicked
        text: glyph
        color: enabled ? "#ffffff" : Qt.rgba(1, 1, 1, 0.3)
        opacity: ctlMouse.containsMouse ? 0.75 : 1
        font.family: Theme.font
        font.pixelSize: size
        scale: ctlMouse.pressed ? 0.85 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.fast
            }
        }
        MouseArea {
            id: ctlMouse
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            enabled: ctl.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ctl.clicked()
        }
    }

    // Pill toggle/button used in the expanded toolbar.
    component Chip: Rectangle {
        id: chip
        property string glyph
        property string label
        property bool on: false
        property color tint: "#ffffff"
        signal clicked
        width: chipRow.implicitWidth + 24
        height: 30
        radius: 15
        color: on ? Theme.alpha(tint, 0.9) : chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.1)
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
        scale: chipMouse.pressed ? 0.94 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.fast
            }
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: chip.glyph
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: 14
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component PrivacyLine: Row {
        property color color
        property string glyph
        property var apps: []
        spacing: 6
        Text {
            text: parent.glyph
            color: parent.color
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        Text {
            text: parent.apps.join(", ")
            color: "#ffffff"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    // Centre-anchored waveform tinted by the cover, flat when paused.
    // A "now playing" indicator, not real audio levels.
    component Wave: Row {
        id: wave
        property bool active: false
        property color color: Theme.accent
        spacing: 2
        height: 14
        Repeater {
            model: 5
            Rectangle {
                id: bar
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: 2.5
                radius: 1.25
                color: wave.color
                height: 3
                Behavior on height {
                    enabled: !wave.active
                    NumberAnimation {
                        duration: Theme.normal
                    }
                }
                Connections {
                    target: wave
                    function onActiveChanged() {
                        if (!wave.active)
                            bar.height = 3;
                    }
                }
                SequentialAnimation on height {
                    running: wave.active
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: [9, 14, 11, 13, 7][index]
                        duration: [320, 260, 380, 240, 300][index]
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: [4, 6, 3, 5, 4][index]
                        duration: [280, 340, 240, 360, 260][index]
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
