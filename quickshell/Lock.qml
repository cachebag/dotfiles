import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris

// Session lock: blurred wallpaper, big clock, password pill, now playing and
// battery. `qs ipc call lock lock` locks; starting quickshell with
// QS_LOCK_ON_START=1 locks straight away (boot, after tty1 autologin).
Scope {
    id: root

    property string buffer: ""
    property bool checking: false
    property bool unlocking: false
    property string status: ""
    property int failures: 0

    signal failed

    function lock() {
        if (sessionLock.locked)
            return;
        root.buffer = "";
        root.status = "";
        root.checking = false;
        root.unlocking = false;
        sessionLock.locked = true;
    }

    function submit() {
        if (root.checking || root.unlocking || root.buffer.length === 0)
            return;
        root.checking = true;
        root.status = "";
        if (!pam.start()) {
            root.checking = false;
            root.status = "couldn't start the password check";
            root.failed();
        }
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("pam")
        config: "password.conf"

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.buffer);
        }

        onCompleted: result => {
            root.checking = false;
            root.buffer = "";
            if (result === PamResult.Success) {
                root.failures = 0;
                root.unlocking = true;
                unlockTimer.restart();
            } else {
                root.failures++;
                root.status = result === PamResult.MaxTries ? "too many attempts" : "wrong password";
                root.failed();
            }
        }

        onError: error => {
            root.checking = false;
            root.buffer = "";
            root.status = "authentication error";
            root.failed();
        }
    }

    // Lets the fade-out finish before the compositor drops the lock.
    Timer {
        id: unlockTimer
        interval: 420
        onTriggered: sessionLock.locked = false
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
    }

    // The wallpaper wallpaper.sh last applied.
    FileView {
        id: wallFile
        path: Quickshell.env("HOME") + "/.config/hypr/current_wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    readonly property string wallpaper: String(wallFile.text()).trim()

    // Battery, read the same way as Battery.qml.
    FileView { id: batCap; path: "/sys/class/power_supply/macsmc-battery/capacity"; printErrors: false }
    FileView { id: batStatus; path: "/sys/class/power_supply/macsmc-battery/status"; printErrors: false }
    Timer {
        interval: 10000
        running: sessionLock.locked
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batCap.reload();
            batStatus.reload();
        }
    }
    Connections {
        target: Power
        function onChanged() {
            batCap.reload();
            batStatus.reload();
        }
    }
    readonly property int battery: {
        const n = parseInt(String(batCap.text()).trim());
        return isNaN(n) ? -1 : n;
    }
    readonly property bool charging: String(batStatus.text()).trim() === "Charging"

    readonly property var player: {
        const ps = Mpris.players.values;
        for (let i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i];
        return ps.length > 0 ? ps[0] : null;
    }

    WlSessionLock {
        id: sessionLock
        locked: Quickshell.env("QS_LOCK_ON_START") === "1"

        WlSessionLockSurface {
            id: surface
            color: "black"

            Item {
                id: face
                anchors.fill: parent

                // Fade in on lock, out on unlock.
                opacity: root.unlocking ? 0 : 1
                Component.onCompleted: intro.start()

                Behavior on opacity {
                    NumberAnimation {
                        duration: 380
                        easing.type: Easing.InOutCubic
                    }
                }

                // ── Background ────────────────────────────────────────────────
                Image {
                    id: wall
                    anchors.fill: parent
                    source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    sourceSize.width: 1600
                }

                MultiEffect {
                    id: blurred
                    anchors.fill: parent
                    source: wall
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 64
                    saturation: 0.15
                    brightness: -0.18
                    scale: 1.08

                    NumberAnimation on scale {
                        id: intro
                        running: false
                        from: 1.16
                        to: 1.08
                        duration: 900
                        easing.type: Easing.OutCubic
                    }
                }

                // Fallback colour if there's no wallpaper yet.
                Rectangle {
                    anchors.fill: parent
                    visible: wall.status !== Image.Ready
                    color: Theme.bg
                }

                // Vignette, darker towards the bottom where the controls sit.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.bg, 0.15) }
                        GradientStop { position: 0.55; color: Theme.alpha(Theme.bg, 0.35) }
                        GradientStop { position: 1.0; color: Theme.alpha(Theme.bg, 0.85) }
                    }
                }

                // ── Clock ─────────────────────────────────────────────────────
                property date now: new Date()
                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: face.now = new Date()
                }

                Column {
                    id: clockBlock
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.verticalCenter
                    anchors.bottomMargin: -20
                    spacing: 6

                    Row {
                        id: clock
                        anchors.horizontalCenter: parent.horizontalCenter

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Theme.accent
                            shadowBlur: 1.0
                            shadowOpacity: 0.55
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }

                        Text {
                            text: Qt.formatTime(face.now, "HH")
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 150
                            font.weight: Font.Light
                            font.letterSpacing: -6
                        }

                        Text {
                            id: colon
                            text: ":"
                            color: Theme.accent
                            font.family: Theme.font
                            font.pixelSize: 150
                            font.weight: Font.Light

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 500; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                            }
                        }

                        Text {
                            text: Qt.formatTime(face.now, "mm")
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 150
                            font.weight: Font.Light
                            font.letterSpacing: -6
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(face.now, "dddd  ·  d MMMM").toLowerCase()
                        color: Theme.alpha(Theme.fg, 0.75)
                        font.family: Theme.font
                        font.pixelSize: 17
                        font.letterSpacing: 4
                    }
                }

                // ── Password ──────────────────────────────────────────────────
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: clockBlock.bottom
                    anchors.topMargin: 90
                    spacing: 14

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            const h = face.now.getHours();
                            const part = h < 5 ? "night" : h < 12 ? "morning" : h < 18 ? "afternoon" : "evening";
                            return "good " + part + ", " + Quickshell.env("USER");
                        }
                        color: Theme.alpha(Theme.fg, 0.6)
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.letterSpacing: 2
                    }

                    Rectangle {
                        id: pill
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 320
                        height: 52
                        radius: height / 2
                        color: Theme.alpha(Theme.bg, 0.55)
                        border.width: 1.5
                        border.color: root.status !== "" ? Theme.urgent : (root.checking ? Theme.accent : Theme.alpha(Theme.fg, 0.18))

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.normal }
                        }

                        // Pulse while PAM checks.
                        SequentialAnimation on opacity {
                            running: root.checking
                            loops: Animation.Infinite
                            onStopped: pill.opacity = 1
                            NumberAnimation { to: 0.55; duration: 420; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutSine }
                        }

                        transform: Translate { id: shakeX }

                        SequentialAnimation {
                            id: shake
                            NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 50 }
                            NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 60 }
                            NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 60 }
                            NumberAnimation { target: shakeX; property: "x"; to: 5; duration: 60 }
                            NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
                        }

                        Connections {
                            target: root
                            function onFailed() {
                                shake.restart();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.buffer.length === 0 && !root.checking
                            text: "enter password"
                            color: Theme.alpha(Theme.fg, 0.4)
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.letterSpacing: 2
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Repeater {
                                model: Math.min(root.buffer.length, 22)

                                Rectangle {
                                    width: 9
                                    height: 9
                                    radius: 4.5
                                    color: Theme.accent
                                    scale: 0

                                    Component.onCompleted: pop.start()
                                    NumberAnimation on scale {
                                        id: pop
                                        running: false
                                        from: 0
                                        to: 1
                                        duration: Theme.normal
                                        easing.type: Easing.OutBack
                                    }
                                }
                            }
                        }

                        TextInput {
                            id: input
                            anchors.fill: parent
                            opacity: 0
                            focus: true
                            echoMode: TextInput.Password
                            enabled: !root.checking && !root.unlocking

                            onTextChanged: {
                                if (text !== root.buffer)
                                    root.buffer = text;
                                if (text.length > 0)
                                    root.status = "";
                            }

                            Keys.onReturnPressed: root.submit()
                            Keys.onEnterPressed: root.submit()
                            Keys.onEscapePressed: input.text = ""

                            Connections {
                                target: root
                                function onBufferChanged() {
                                    if (root.buffer !== input.text)
                                        input.text = root.buffer;
                                }
                            }

                            Component.onCompleted: forceActiveFocus()
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.status
                        opacity: root.status !== "" ? 1 : 0
                        color: Theme.urgent
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.letterSpacing: 2

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.normal }
                        }
                    }
                }

                // ── Now playing ───────────────────────────────────────────────
                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 32
                    spacing: 12
                    visible: root.player !== null && (root.player.trackTitle ?? "") !== ""

                    Rectangle {
                        width: 46
                        height: 46
                        radius: 8
                        color: Theme.surface
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: (root.player?.isPlaying ? "󰐊  " : "󰏤  ") + (root.player?.trackTitle ?? "")
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 320)
                        }

                        Text {
                            text: root.player?.trackArtist ?? ""
                            color: Theme.alpha(Theme.fg, 0.6)
                            font.family: Theme.font
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 320)
                        }
                    }
                }

                // ── Battery ───────────────────────────────────────────────────
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 32
                    visible: root.battery >= 0
                    text: {
                        if (root.charging)
                            return String.fromCodePoint(0xf0084) + "  " + root.battery + "%";
                        const step = Math.max(0, Math.min(8, Math.floor(root.battery / 10) - 1));
                        const icon = root.battery >= 95 ? 0xf0079 : root.battery < 5 ? 0xf008e : 0xf007a + step;
                        return String.fromCodePoint(icon) + "  " + root.battery + "%";
                    }
                    color: !root.charging && root.battery <= 15 ? Theme.urgent : Theme.alpha(Theme.fg, 0.75)
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.letterSpacing: 1
                }
            }
        }
    }
}
