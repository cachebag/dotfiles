import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Full-screen storage overlay: drives across the top, a sunburst of the
// selected one, and a trash queue. Backed by `diskring serve`, which holds the
// scan in memory so zooming never touches the disk.
// Opened with `qs ipc call storage toggle`.
PanelWindow {
    id: win

    property bool open: false
    property real fade: open ? 1 : 0

    Behavior on fade {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Theme.easeOut
        }
    }

    visible: fade > 0
    screen: target

    property var target: Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-storage"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ---- state ----------------------------------------------------------

    property string root: "/"
    property string path: "/"
    property var tree: null
    property var drives: []
    property bool scanning: false
    property real scanFiles: 0
    property real scanBytes: 0
    property var scanned: null
    property var hover: null
    property var queue: []
    property bool confirming: false
    property string flash: ""
    property bool flashBad: false

    readonly property var marked: {
        const m = {};
        for (var i = 0; i < queue.length; i++)
            m[queue[i].path] = true;
        return m;
    }
    readonly property real queued: queue.reduce((s, q) => s + q.size, 0)

    function toggle() {
        open ? close() : show();
    }

    function show() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        target = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
        idle.stop();
        open = true;
        keys.forceActiveFocus();
        if (!server.running) {
            server.running = true;
            return; // onStarted picks it up.
        }
        refresh(120);
    }

    function browse(dir) {
        const p = dir.length > 1 ? dir.replace(/\/+$/, "") : dir;
        var best = "/";
        for (var i = 0; i < drives.length; i++) {
            const m = drives[i].mount;
            if ((p === m || p.startsWith(m === "/" ? m : m + "/")) && m.length > best.length)
                best = m;
        }
        if (best !== root) {
            root = best;
            queue = [];
            tree = null;
        }
        path = p;
        if (open)
            refresh(120);
        else
            show();
    }

    function close() {
        open = false;
        confirming = false;
        hover = null;
        idle.restart();
    }

    function refresh(maxAge) {
        send({
            cmd: "drives"
        });
        scanning = true;
        scanFiles = 0;
        scanBytes = 0;
        send({
            cmd: "open",
            root: root,
            max_age: maxAge
        });
    }

    function go(p) {
        send({
            cmd: "tree",
            root: root,
            path: p,
            depth: ring.rings,
            min: 0.003
        });
    }

    function up() {
        if (path === root)
            return;
        const cut = path.lastIndexOf("/");
        const parent = cut <= 0 ? "/" : path.slice(0, cut);
        go(parent.length < root.length ? root : parent);
    }

    function pickDrive(d) {
        if (d.mount === root || scanning)
            return;
        root = d.mount;
        path = d.mount;
        queue = [];
        tree = null;
        refresh(120);
    }

    function mark(p, name, size) {
        if (!p)
            return;
        if (queue.some(q => q.path === p)) {
            queue = queue.filter(q => q.path !== p);
            return;
        }
        // Covered by a queued parent: nothing to add.
        if (queue.some(q => p.startsWith(q.path + "/")))
            return;
        queue = queue.filter(q => !q.path.startsWith(p + "/")).concat([
            {
                path: p,
                name: name,
                size: size
            }
        ]);
        confirming = false;
    }

    function trash() {
        if (queue.length === 0)
            return;
        if (!confirming) {
            confirming = true;
            unconfirm.restart();
            return;
        }
        confirming = false;
        send({
            cmd: "trash",
            root: root,
            paths: queue.map(q => q.path)
        });
    }

    function say(text, bad) {
        flash = text;
        flashBad = !!bad;
        flashTimer.restart();
    }

    function fmt(b) {
        const u = ["B", "K", "M", "G", "T", "P"];
        var i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return (i === 0 ? b : b.toFixed(b < 10 ? 2 : 1)) + u[i];
    }

    function count(n) {
        if (n >= 1e6)
            return (n / 1e6).toFixed(1) + "M";
        if (n >= 1e3)
            return (n / 1e3).toFixed(1) + "k";
        return String(n);
    }

    function child(name) {
        return path.endsWith("/") ? path + name : path + "/" + name;
    }

    // ---- diskring -------------------------------------------------------

    function send(obj) {
        if (server.running)
            server.write(JSON.stringify(obj) + "\n");
    }

    Process {
        id: server
        command: [Quickshell.env("HOME") + "/.local/bin/diskring", "serve"]
        stdinEnabled: true

        onStarted: win.refresh(120)
        onExited: (code, status) => {
            win.scanning = false;
            if (win.open)
                win.say("diskring exited (" + code + ")", true);
        }

        stdout: SplitParser {
            onRead: data => win.receive(data)
        }
    }

    // A scan of / holds ~60MB; let it go once the overlay has been shut a while.
    Timer {
        id: idle
        interval: 5 * 60 * 1000
        onTriggered: server.running = false
    }

    Timer {
        id: unconfirm
        interval: 3000
        onTriggered: win.confirming = false
    }

    Timer {
        id: flashTimer
        interval: 3500
        onTriggered: win.flash = ""
    }

    function receive(line) {
        var m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (m.type) {
        case "progress":
            if (m.root === root) {
                scanFiles = m.files;
                scanBytes = m.bytes;
            }
            break;
        case "scanned":
            if (m.root !== root)
                break;
            scanning = false;
            scanned = m;
            go(path.startsWith(root) ? path : root);
            break;
        case "tree":
            if (m.root !== root)
                break;
            path = m.path;
            hover = null;
            tree = m.node;
            break;
        case "trashed":
            queue = [];
            if (m.count > 0)
                say("Moved " + m.count + " to trash · " + fmt(m.bytes) + " freed");
            if (m.failed.length > 0)
                say(m.failed.length + " could not be trashed", true);
            go(path);
            send({
                cmd: "drives"
            });
            break;
        case "drives":
            drives = m.drives;
            break;
        case "ejected":
            say(m.error ? m.error : "Ejected " + m.device, !!m.error);
            send({
                cmd: "drives"
            });
            break;
        case "error":
            scanning = false;
            say(m.message, true);
            if (m.message.endsWith("not found"))
                go(root);
            break;
        }
    }

    IpcHandler {
        target: "storage"

        function toggle(): void {
            win.toggle();
        }
        function open(): void {
            win.show();
        }
        function close(): void {
            win.close();
        }
        // Open zoomed into a directory, on whichever drive holds it.
        function browse(dir: string): void {
            win.browse(dir);
        }
    }

    // ---- view -----------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, 0.55)
        opacity: win.fade

        MouseArea {
            anchors.fill: parent
            onClicked: win.close()
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) {
                if (win.confirming)
                    win.confirming = false;
                else
                    win.close();
            } else if (k === Qt.Key_Backspace || k === Qt.Key_Left || k === Qt.Key_H) {
                win.up();
            } else if (k === Qt.Key_R) {
                win.refresh(0);
            } else if ((k === Qt.Key_D || k === Qt.Key_Delete) && win.hover && win.hover.path) {
                win.mark(win.hover.path, win.hover.node.name, win.hover.node.size);
            } else if (k === Qt.Key_O && win.hover && win.hover.path) {
                Quickshell.execDetached(["xdg-open", win.hover.path]);
            } else {
                return;
            }
            event.accepted = true;
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1180)
        height: Math.min(parent.height - 80, 760)
        radius: Theme.radius + 4
        color: Theme.alpha(Theme.surface, 0.97)
        border.width: 1
        border.color: Theme.line
        opacity: win.fade
        scale: 0.96 + 0.04 * win.fade

        // Swallow clicks so they don't reach the backdrop.
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // header: title, breadcrumbs, scan stats
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "󰋊"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 6
                }

                Row {
                    Layout.fillWidth: true
                    spacing: 2
                    clip: true

                    Repeater {
                        model: {
                            const rel = win.path.slice(win.root.length).split("/").filter(s => s);
                            const out = [
                                {
                                    label: win.root,
                                    path: win.root
                                }
                            ];
                            var acc = win.root;
                            for (var i = 0; i < rel.length; i++) {
                                acc = acc.endsWith("/") ? acc + rel[i] : acc + "/" + rel[i];
                                out.push({
                                    label: rel[i],
                                    path: acc
                                });
                            }
                            return out;
                        }

                        delegate: Row {
                            id: crumb
                            required property var modelData
                            required property int index
                            spacing: 2

                            Text {
                                visible: crumb.index > 0
                                text: "›"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize + 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: crumbText.implicitWidth + 12
                                height: 24
                                radius: Theme.radius
                                color: crumbMouse.containsMouse ? Theme.hover : "transparent"

                                Text {
                                    id: crumbText
                                    anchors.centerIn: parent
                                    text: crumb.modelData.label
                                    color: crumb.modelData.path === win.path ? Theme.fg : Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 2
                                    font.bold: crumb.modelData.path === win.path
                                }

                                MouseArea {
                                    id: crumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.go(crumb.modelData.path)
                                }
                            }
                        }
                    }
                }

                Text {
                    text: win.scanned ? win.count(win.scanned.files) + " files · " + (win.scanned.ms / 1000).toFixed(1) + "s" + (win.scanned.errors > 0 ? " · " + win.scanned.errors + " unreadable" : "") : ""
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }

                IconButton {
                    icon: "󰑓"
                    tip: "Rescan (r)"
                    onClicked: win.refresh(0)
                }

                IconButton {
                    icon: "󰅖"
                    tip: "Close (esc)"
                    onClicked: win.close()
                }
            }

            // drives
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: win.drives

                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool active: modelData.mount === win.root
                        readonly property real used: modelData.size > 0 ? modelData.used / modelData.size : 0

                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        radius: Theme.radius
                        color: active ? Theme.alpha(Theme.accent, 0.14) : chipMouse.containsMouse ? Theme.hover : Theme.alpha(Theme.fg, 0.04)
                        border.width: active ? 1 : 0
                        border.color: Theme.alpha(Theme.accent, 0.6)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.fast
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: win.pickDrive(chip.modelData)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: chip.modelData.removable ? "󰕓" : "󰋊"
                                    color: chip.active ? Theme.accent : Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 1
                                }
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: (chip.modelData.label || chip.modelData.mount) + (chip.modelData.label ? "  " + chip.modelData.mount : "")
                                    color: Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: chip.active
                                }
                                Text {
                                    text: win.fmt(chip.modelData.avail) + " free"
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                }
                                IconButton {
                                    visible: chip.modelData.removable
                                    icon: "󰭰"
                                    tip: "Eject"
                                    size: 20
                                    onClicked: win.send({
                                        cmd: "eject",
                                        device: chip.modelData.device
                                    })
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 4
                                radius: 2
                                color: Theme.alpha(Theme.fg, 0.08)

                                Rectangle {
                                    width: parent.width * chip.used * win.fade
                                    height: parent.height
                                    radius: 2
                                    color: chip.used > 0.9 ? Theme.urgent : Theme.accent
                                }
                            }
                        }
                    }
                }
            }

            // ring + side panel
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 18

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Sunburst {
                        id: ring
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        path: win.path
                        tree: win.tree
                        marked: win.marked
                        hoverPath: win.hover ? win.hover.path : ""
                        visible: !win.scanning && win.tree !== null

                        onHovered: arc => win.hover = arc
                        onClicked: arc => {
                            if (arc.node.kind === "dir")
                                win.go(arc.path);
                        }
                        onMarking: arc => win.mark(arc.path, arc.node.name, arc.node.size)
                        onUp: win.up()
                    }

                    // centre readout: what's under the pointer, else the current dir
                    Column {
                        anchors.centerIn: parent
                        width: ring.hole * 1.7
                        spacing: 2
                        visible: ring.visible

                        readonly property var subject: win.hover ? win.hover.node : win.tree

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            text: parent.subject ? (win.hover ? parent.subject.name : (win.path === "/" ? "/" : win.path.slice(win.path.lastIndexOf("/") + 1))) : ""
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: parent.subject ? win.fmt(parent.subject.size) : ""
                            color: win.hover ? Theme.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 10
                            font.bold: true
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                const s = parent.subject;
                                if (!s || !win.tree)
                                    return "";
                                if (win.hover)
                                    return (100 * s.size / Math.max(1, win.tree.size)).toFixed(1) + "% · " + win.count(s.files || 1) + " files";
                                return win.path === win.root ? win.count(s.files) + " files" : "click to go up";
                            }
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }

                    // scanning
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: win.scanning

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰑓"
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 34

                            RotationAnimator on rotation {
                                running: win.scanning && win.visible
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Scanning " + win.root
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: win.count(win.scanFiles) + " files · " + win.fmt(win.scanBytes)
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                }

                // side panel
                ColumnLayout {
                    Layout.preferredWidth: 360
                    Layout.maximumWidth: 360
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: 10

                    Text {
                        text: "Largest here"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: win.tree ? win.tree.children || [] : []
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property string fullPath: modelData.kind === "rest" ? "" : win.child(modelData.name)
                            readonly property bool isMarked: fullPath !== "" && win.marked[fullPath] === true
                            readonly property bool lit: win.hover !== null && fullPath !== "" && (win.hover.path === fullPath || win.hover.path.startsWith(fullPath + "/"))

                            width: list.width
                            height: 34
                            radius: Theme.radius
                            color: isMarked ? Theme.alpha(Theme.urgent, 0.18) : lit || rowMouse.containsMouse ? Theme.hover : "transparent"

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: row.modelData.kind === "dir" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: if (row.fullPath)
                                    win.hover = {
                                        path: row.fullPath,
                                        node: row.modelData
                                    }
                                onExited: win.hover = null
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton)
                                        win.mark(row.fullPath, row.modelData.name, row.modelData.size);
                                    else if (row.modelData.kind === "dir")
                                        win.go(row.fullPath);
                                }
                            }

                            // share-of-parent bar behind the text
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * row.modelData.size / Math.max(1, win.tree.size) * win.fade
                                radius: Theme.radius
                                color: Theme.alpha(row.modelData.kind === "rest" ? Theme.muted : ring.hue(row.index), 0.16)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 8

                                Text {
                                    text: row.modelData.kind === "dir" ? "󰉋" : row.modelData.kind === "file" ? "󰈔" : "󰇘"
                                    color: row.modelData.kind === "rest" ? Theme.muted : ring.hue(row.index)
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize + 1
                                }
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                    text: row.modelData.kind === "rest" ? win.count(row.modelData.files) + " smaller items" : row.modelData.name
                                    color: row.modelData.kind === "rest" ? Theme.muted : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                }
                                Text {
                                    text: win.fmt(row.modelData.size)
                                    color: Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                }
                                IconButton {
                                    visible: row.fullPath !== "" && (rowMouse.containsMouse || row.isMarked || hovered)
                                    icon: row.isMarked ? "󰆴" : "󰩹"
                                    tip: row.isMarked ? "Unmark" : "Mark for trash"
                                    size: 24
                                    tint: row.isMarked ? Theme.urgent : Theme.muted
                                    onClicked: win.mark(row.fullPath, row.modelData.name, row.modelData.size)
                                }
                            }
                        }
                    }

                    // trash queue
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: win.queue.length > 0 ? 92 : 0
                        visible: Layout.preferredHeight > 1
                        clip: true
                        radius: Theme.radius
                        color: Theme.alpha(Theme.urgent, 0.10)
                        border.width: 1
                        border.color: Theme.alpha(Theme.urgent, 0.35)

                        Behavior on Layout.preferredHeight {
                            NumberAnimation {
                                duration: Theme.normal
                                easing.type: Theme.easeOut
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: win.queue.length + " marked · " + win.queue.map(q => q.name).join(", ")
                                    color: Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                }
                                Text {
                                    text: "clear"
                                    color: clearMouse.containsMouse ? Theme.fg : Theme.muted
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            win.queue = [];
                                            win.confirming = false;
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radius
                                color: win.confirming ? Theme.urgent : trashMouse.containsMouse ? Theme.alpha(Theme.urgent, 0.45) : Theme.alpha(Theme.urgent, 0.28)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.fast
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: win.confirming ? "Click again to move " + win.fmt(win.queued) + " to trash" : "󰩹  Move to trash · " + win.fmt(win.queued)
                                    color: win.confirming ? Theme.bg : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                }

                                MouseArea {
                                    id: trashMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.trash()
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: win.flash !== "" ? win.flash : "click: zoom · right-click / d: mark · o: open · ⌫: up · r: rescan"
                        color: win.flash !== "" ? (win.flashBad ? Theme.urgent : Theme.accent) : Theme.alpha(Theme.muted, 0.7)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: btn
        property string icon
        property string tip
        property int size: 28
        property color tint: Theme.muted
        readonly property bool hovered: btnMouse.containsMouse
        signal clicked

        implicitWidth: size
        implicitHeight: size
        Layout.preferredWidth: size
        Layout.preferredHeight: size
        radius: Theme.radius
        color: btnMouse.pressed ? Theme.press : hovered ? Theme.hover : "transparent"

        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: btn.hovered ? Theme.fg : btn.tint
            font.family: Theme.font
            font.pixelSize: btn.size * 0.55
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
