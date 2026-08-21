import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root

    required property var bar

    readonly property var player: {
        const ps = Mpris.players.values;
        if (!ps || ps.length === 0)
            return null;
        for (var i = 0; i < ps.length; i++)
            if (ps[i].isPlaying)
                return ps[i];
        return ps[0];
    }

    readonly property bool has: player !== null
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""

    property real pos: 0
    property real lastReal: -1

    Timer {
        interval: 500
        running: root.has
        repeat: true
        onTriggered: {
            const p = root.player;
            if (!p)
                return;
            const real = p.position ?? 0;
            if (Math.abs(real - root.lastReal) > 0.05) {
                root.lastReal = real;
                root.pos = real;
            } else if (p.isPlaying) {
                root.pos += 0.5;
            }
        }
    }

    implicitHeight: Theme.barHeight - 8
    implicitWidth: has ? pill.implicitWidth : 0
    visible: has

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Theme.easeOut
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.radius
        implicitWidth: pillRow.implicitWidth + Theme.pad * 2
        color: mouse.containsMouse ? Theme.hover : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.player?.isPlaying ? "󰏤" : "󰐊"
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                scale: playMouse.pressed ? 0.8 : playMouse.containsMouse ? 1.15 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.fast
                        easing.type: Theme.easeBack
                    }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: playMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    onClicked: root.player?.togglePlaying()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
                text: root.artist !== "" ? root.title + "  ·  " + root.artist : root.title
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 1
            height: 2
            radius: 1
            color: Theme.accent
            opacity: 0.8
            width: {
                const len = root.player?.length ?? 0;
                return len > 0 ? parent.width * Math.min(1, root.pos / len) : 0;
            }

            Behavior on width {
                NumberAnimation {
                    duration: 500
                }
            }
        }

        MouseArea {
            cursorShape: Qt.PointingHandCursor
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (e) {
                if (e.button === Qt.RightButton)
                    root.player?.next();
                else
                    popup.toggle();
            }
            onWheel: function (e) {
                if (e.angleDelta.y > 0)
                    root.player?.previous();
                else
                    root.player?.next();
            }
        }
    }

    Popup {
        id: popup
        bar: root.bar
        owner: root
        cardWidth: 340
        cardHeight: 150

        Row {
            anchors.fill: parent
            spacing: 14

            Rectangle {
                width: 110
                height: 110
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.radius
                color: Theme.alpha(Theme.fg, 0.06)
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    source: root.player?.trackArtUrl ?? ""
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.slow
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "󰎈"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 28
                }
            }

            Column {
                width: parent.width - 124
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.title
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.artist
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.player?.identity ?? ""
                    color: Theme.alpha(Theme.muted, 0.7)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                }

                Item {
                    width: 1
                    height: 6
                }

                Rectangle {
                    id: track
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Theme.alpha(Theme.fg, 0.15)

                    Rectangle {
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                        width: {
                            const len = root.player?.length ?? 0;
                            return len > 0 ? parent.width * Math.min(1, root.pos / len) : 0;
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 400
                            }
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: function (e) {
                            const p = root.player;
                            const len = p?.length ?? 0;
                            if (!p || len <= 0)
                                return;
                            const target = (e.x / track.width) * len;
                            try {
                                p.position = target;
                                root.pos = target;
                            } catch (err) {
                            }
                        }
                    }
                }

                Item {
                    width: 1
                    height: 4
                }

                Row {
                    spacing: 18

                    Repeater {
                        model: [
                            {
                                glyph: "󰒮",
                                act: "prev"
                            },
                            {
                                glyph: root.player?.isPlaying ? "󰏤" : "󰐊",
                                act: "toggle"
                            },
                            {
                                glyph: "󰒭",
                                act: "next"
                            }
                        ]

                        delegate: Text {
                            required property var modelData
                            text: modelData.glyph
                            color: ctl.containsMouse ? Theme.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize + 4
                            scale: ctl.pressed ? 0.82 : ctl.containsMouse ? 1.18 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.fast
                                    easing.type: Theme.easeBack
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }

                            MouseArea {
                                cursorShape: Qt.PointingHandCursor
                                id: ctl
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                onClicked: {
                                    const p = root.player;
                                    if (!p)
                                        return;
                                    if (parent.modelData.act === "prev")
                                        p.previous();
                                    else if (parent.modelData.act === "next")
                                        p.next();
                                    else
                                        p.togglePlaying();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
