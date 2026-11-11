import QtQuick
import Quickshell
import Quickshell.Widgets

// Apple Music panel shown inside the island: search, now playing with love and
// add-to-library, shuffle/repeat transport, scrubber and Up Next.
// All state comes from the AppleMusic singleton.
Item {
    id: root

    signal close

    readonly property color dim: Qt.rgba(1, 1, 1, 0.55)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.12)
    readonly property color red: "#fc3c44"
    readonly property bool showResults: AppleMusic.term.trim() !== ""
    readonly property bool showBrowse: !showResults && AppleMusic.browse !== ""
    readonly property bool showNow: !showResults && !showBrowse

    implicitHeight: col.implicitHeight

    function open() {
        field.text = "";
        AppleMusic.clearSearch();
        AppleMusic.closeBrowse();
        field.forceActiveFocus();
    }

    function play(r) {
        AppleMusic.playItem(r.kind, r.id);
        field.text = "";
        AppleMusic.clearSearch();
        AppleMusic.closeBrowse();
    }

    Column {
        id: col
        width: parent.width
        spacing: 14

        // ---- search field
        Rectangle {
            width: parent.width
            height: 34
            radius: 17
            color: field.activeFocus ? Qt.rgba(1, 1, 1, 0.16) : root.faint
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    color: root.dim
                    font.family: Theme.font
                    font.pixelSize: 14
                }

                TextInput {
                    id: field
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 44
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    selectionColor: root.red
                    selectedTextColor: "#ffffff"
                    clip: true
                    onTextEdited: AppleMusic.search(text)
                    Keys.onEscapePressed: {
                        if (text !== "") {
                            text = "";
                            AppleMusic.clearSearch();
                        } else if (AppleMusic.browse !== "") {
                            AppleMusic.closeBrowse();
                        } else {
                            root.close();
                        }
                    }
                    Keys.onReturnPressed: if (AppleMusic.results.length > 0)
                        root.play(AppleMusic.results[0])
                    Keys.onEnterPressed: if (AppleMusic.results.length > 0)
                        root.play(AppleMusic.results[0])

                    Text {
                        anchors.fill: parent
                        visible: field.text === ""
                        text: "Search Apple Music"
                        color: root.dim
                        font: field.font
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: AppleMusic.searching
                    text: "󰑓"
                    color: root.dim
                    font.family: Theme.font
                    font.pixelSize: 13
                    RotationAnimation on rotation {
                        running: AppleMusic.searching
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                    }
                }
            }
        }

        // ---- library tabs
        Row {
            spacing: 6
            visible: !root.showResults
            Repeater {
                model: [
                    {
                        key: "playlists",
                        glyph: "󰲸",
                        label: "Playlists"
                    },
                    {
                        key: "pinned",
                        glyph: "󰐃",
                        label: "Pinned"
                    },
                    {
                        key: "recent",
                        glyph: "󰔟",
                        label: "Recent"
                    }
                ]
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool on: AppleMusic.browse === modelData.key
                    width: tabRow.implicitWidth + 20
                    height: 26
                    radius: 13
                    color: on ? Qt.rgba(1, 1, 1, 0.92) : tabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : root.faint
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: tab.modelData.glyph
                            color: tab.on ? "#000000" : "#ffffff"
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.label
                            color: tab.on ? "#000000" : "#ffffff"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                        }
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppleMusic.openBrowse(tab.modelData.key)
                    }
                }
            }

            // Lyrics overlay toggle; red while on.
            Rectangle {
                width: lyrRow.implicitWidth + 20
                height: 26
                radius: 13
                color: AppleMusic.lyricsOn ? root.red : lyrMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : root.faint
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }
                Row {
                    id: lyrRow
                    anchors.centerIn: parent
                    spacing: 5
                    Text {
                        text: "󰎈"
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Lyrics"
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
                MouseArea {
                    id: lyrMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppleMusic.toggleLyrics()
                }
            }
        }

        // ---- browse list (playlists / pinned / recent)
        Item {
            width: parent.width
            visible: root.showBrowse
            height: AppleMusic.browseItems.length > 0 ? list.height : 32

            ListView {
                id: list
                width: parent.width
                height: Math.min(count, 6) * 42
                clip: true
                spacing: 2
                model: AppleMusic.browseItems
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: brow
                    required property var modelData
                    width: list.width
                    height: 40
                    radius: 10
                    color: browMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 10
                        spacing: 10
                        ClippingRectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 30
                            radius: brow.modelData.kind === "artist" ? 15 : 6
                            color: root.faint
                            Image {
                                anchors.fill: parent
                                source: brow.modelData.art ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(60, 60)
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !(brow.modelData.art)
                                text: brow.modelData.kind === "station" ? "󰐹" : "󰲸"
                                color: root.dim
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 40
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: brow.modelData.name
                                color: "#ffffff"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                visible: text !== ""
                                width: parent.width
                                elide: Text.ElideRight
                                text: brow.modelData.sub ?? ""
                                color: root.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                    }
                    MouseArea {
                        id: browMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.play(brow.modelData)
                    }
                }
            }

            Text {
                visible: AppleMusic.browseItems.length === 0
                leftPadding: 8
                topPadding: 8
                text: AppleMusic.browsing ? "Loading…" : AppleMusic.browseNote === "unavailable" ? "Pinned items aren't exposed by Apple Music's web API" : "Nothing here"
                color: root.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
        }

        // ---- search results
        Column {
            width: parent.width
            spacing: 2
            visible: root.showResults

            Repeater {
                model: AppleMusic.results
                delegate: Rectangle {
                    id: res
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 44
                    radius: 10
                    color: resMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : index === 0 ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 10
                        spacing: 10
                        ClippingRectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: res.modelData.kind === "artist" ? 16 : 6
                            color: root.faint
                            Image {
                                anchors.fill: parent
                                source: res.modelData.art
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(64, 64)
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 42 - (hint.visible ? hint.width + 10 : 0)
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: res.modelData.name
                                color: "#ffffff"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: res.modelData.sub
                                color: root.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }
                        Text {
                            id: hint
                            anchors.verticalCenter: parent.verticalCenter
                            visible: res.index === 0
                            text: "↵"
                            color: root.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                    MouseArea {
                        id: resMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.play(res.modelData)
                    }
                }
            }

            Text {
                visible: !AppleMusic.searching && AppleMusic.results.length === 0
                leftPadding: 8
                topPadding: 6
                text: "No results"
                color: root.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }
        }

        // ---- now playing
        Item {
            width: parent.width
            height: 56
            visible: root.showNow

            ClippingRectangle {
                id: cover
                width: 56
                height: 56
                radius: 10
                color: root.faint
                Image {
                    anchors.fill: parent
                    source: AppleMusic.item?.art ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(112, 112)
                }
                Text {
                    anchors.centerIn: parent
                    visible: !(AppleMusic.item?.art)
                    text: "󰀵"
                    color: root.red
                    font.family: Theme.font
                    font.pixelSize: 24
                }
            }

            Column {
                anchors.left: cover.right
                anchors.leftMargin: 12
                anchors.right: actions.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: AppleMusic.hasItem ? AppleMusic.item.name : AppleMusic.connected ? "Nothing playing" : "Apple Music not running"
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: AppleMusic.hasItem ? AppleMusic.item.artist + (AppleMusic.item.album ? " — " + AppleMusic.item.album : "") : "Search above to start something"
                    color: root.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                IconBtn {
                    glyph: AppleMusic.loved ? "󰋑" : "󰋕"
                    tint: AppleMusic.loved ? root.red : "#ffffff"
                    enabled: AppleMusic.hasItem
                    tip: AppleMusic.loved ? "Loved" : "Love"
                    onClicked: AppleMusic.toggleLove()
                }
                IconBtn {
                    glyph: AppleMusic.inLibrary ? "󰄬" : "󰐕"
                    tint: AppleMusic.inLibrary ? root.red : "#ffffff"
                    enabled: AppleMusic.hasItem
                    tip: AppleMusic.inLibrary ? "In your library" : "Add to library"
                    onClicked: AppleMusic.addToLibrary()
                }
                IconBtn {
                    glyph: "󰏌"
                    size: 14
                    tip: "Show the app"
                    onClicked: {
                        AppleMusic.raise();
                        root.close();
                    }
                }
            }
        }

        // ---- scrubber
        Item {
            id: seek
            width: parent.width
            height: 14
            visible: root.showNow

            readonly property real frac: AppleMusic.duration > 0 ? Math.max(0, Math.min(1, AppleMusic.position / AppleMusic.duration)) : 0
            function fmt(s) {
                s = Math.max(0, Math.floor(s));
                const m = Math.floor(s / 60), r = s % 60;
                return m + ":" + (r < 10 ? "0" : "") + r;
            }

            Text {
                id: tPos
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: seek.fmt(AppleMusic.position)
                color: root.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }
            Text {
                id: tLeft
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: AppleMusic.duration > 0 ? "-" + seek.fmt(AppleMusic.duration - AppleMusic.position) : "--:--"
                color: root.dim
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
                color: root.faint
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
                    enabled: AppleMusic.hasItem
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: m => {
                        const f = Math.max(0, Math.min(1, (m.x - 6) / track.width));
                        AppleMusic.seek(f * AppleMusic.duration);
                    }
                }
            }
        }

        // ---- transport
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 30
            visible: root.showNow
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰒝"
                size: 16
                tint: AppleMusic.shuffle ? root.red : "#ffffff"
                enabled: AppleMusic.connected
                onClicked: AppleMusic.toggleShuffle()
            }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰒮"
                size: 22
                enabled: AppleMusic.hasItem
                onClicked: AppleMusic.prev()
            }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: AppleMusic.playing ? "󰏤" : "󰐊"
                size: 30
                enabled: AppleMusic.hasItem
                onClicked: AppleMusic.toggle()
            }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "󰒭"
                size: 22
                enabled: AppleMusic.hasItem
                onClicked: AppleMusic.next()
            }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: AppleMusic.repeat === 1 ? "󰑘" : "󰑖"
                size: 16
                tint: AppleMusic.repeat ? root.red : "#ffffff"
                enabled: AppleMusic.connected
                onClicked: AppleMusic.cycleRepeat()
            }
        }

        // ---- up next
        Column {
            width: parent.width
            spacing: 2
            visible: root.showNow && AppleMusic.queue.length > 0

            Text {
                leftPadding: 6
                bottomPadding: 4
                text: "Up Next"
                color: root.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: true
            }

            Repeater {
                model: AppleMusic.queue.slice(0, 4)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    width: parent.width
                    height: 36
                    radius: 8
                    color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 6
                        anchors.rightMargin: 10
                        spacing: 10
                        ClippingRectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26
                            height: 26
                            radius: 5
                            color: root.faint
                            Image {
                                anchors.fill: parent
                                source: row.modelData.art ?? ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(52, 52)
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 36
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: (row.modelData.name ?? "") + "  " + (row.modelData.artist ?? "")
                            color: "#ffffff"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppleMusic.playQueueIndex(row.modelData.index)
                    }
                }
            }
        }
    }

    component IconBtn: Item {
        id: btn
        property string glyph
        property int size: 16
        property color tint: "#ffffff"
        property string tip: ""
        signal clicked
        width: Math.max(28, label.implicitWidth + 10)
        height: 28
        opacity: enabled ? 1 : 0.3
        Text {
            id: label
            anchors.centerIn: parent
            text: btn.glyph
            color: btn.tint
            font.family: Theme.font
            font.pixelSize: btn.size
            scale: btnMouse.pressed ? 0.85 : btnMouse.containsMouse ? 1.1 : 1
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.fast
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Theme.fast
                }
            }
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
