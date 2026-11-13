import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets

// Wallpaper picker shown inside the island: a filter field over a scrolling
// grid of thumbnails. Type to filter by name, arrows move, Enter applies,
// Esc clears the filter then closes. Wheel scrolls the grid.
Item {
    id: root

    required property string dir
    required property string thumbDir
    required property string current       // path of the wallpaper in use
    required property string applying      // path being applied, "" when idle
    property int columns: 4
    property int rows: 3

    signal pick(string path)
    signal close

    readonly property color dim: Qt.rgba(1, 1, 1, 0.55)
    readonly property color faint: Qt.rgba(1, 1, 1, 0.12)
    readonly property int cellW: Math.floor(width / columns)
    readonly property int cellH: Math.round(cellW * 0.625)

    implicitHeight: field.height + 12 + grid.height

    function open() {
        field.text = "";
        term = "";
        rebuild();
        grid.currentIndex = Math.max(0, indexOf(current));
        // The model was just rebuilt: lay out first, or the position is stale.
        grid.forceLayout();
        grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
        Qt.callLater(() => grid.positionViewAtIndex(grid.currentIndex, GridView.Center));
        input.forceActiveFocus();
    }
    function indexOf(path) {
        for (var i = 0; i < list.length; i++)
            if (list[i].path === path)
                return i;
        return -1;
    }

    function pickCurrent() {
        if (grid.currentIndex >= 0 && grid.currentIndex < list.length)
            root.pick(list[grid.currentIndex].path);
    }
    function pickRandom() {
        if (list.length < 2)
            return;
        var i;
        do
            i = Math.floor(Math.random() * list.length);
        while (list[i].path === current);
        grid.currentIndex = i;
        grid.positionViewAtIndex(i, GridView.Contain);
        root.pick(list[i].path);
    }

    // ---- model: folder listing filtered by the typed term ----
    FolderListModel {
        id: files
        folder: "file://" + root.dir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Time
        sortReversed: true
        onCountChanged: root.rebuild()
    }
    property string term: ""
    property var list: []
    onTermChanged: {
        rebuild();
        grid.currentIndex = list.length > 0 ? 0 : -1;
        grid.positionViewAtBeginning();
    }
    function rebuild() {
        const t = term.trim().toLowerCase();
        const out = [];
        for (var i = 0; i < files.count; i++) {
            const n = String(files.get(i, "fileName"));
            if (t === "" || n.toLowerCase().indexOf(t) !== -1)
                out.push({
                    name: n,
                    path: String(files.get(i, "filePath"))
                });
        }
        list = out;
    }

    // ---- filter field + count + random ----
    Rectangle {
        id: field
        width: parent.width
        height: 34
        radius: 17
        color: input.activeFocus ? Qt.rgba(1, 1, 1, 0.16) : root.faint
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
        property alias text: input.text

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 6
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰸉"
                color: root.dim
                font.family: Theme.font
                font.pixelSize: 14
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 44 - counter.width - 8 - randomBtn.width - 8
                color: "#ffffff"
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                selectionColor: Qt.rgba(1, 1, 1, 0.35)
                selectedTextColor: "#ffffff"
                clip: true
                onTextEdited: root.term = text

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Filter wallpapers"
                    color: Qt.rgba(1, 1, 1, 0.3)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }

                Keys.onEscapePressed: {
                    if (text !== "") {
                        text = "";
                        root.term = "";
                    } else {
                        root.close();
                    }
                }
                Keys.onReturnPressed: root.pickCurrent()
                Keys.onEnterPressed: root.pickCurrent()
                Keys.onLeftPressed: grid.moveCurrentIndexLeft()
                Keys.onRightPressed: grid.moveCurrentIndexRight()
                Keys.onUpPressed: grid.moveCurrentIndexUp()
                Keys.onDownPressed: grid.moveCurrentIndexDown()
                Keys.onPressed: e => {
                    if (e.key === Qt.Key_PageDown) {
                        grid.contentY = Math.min(grid.contentHeight - grid.height, grid.contentY + grid.height);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_PageUp) {
                        grid.contentY = Math.max(0, grid.contentY - grid.height);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Home && text === "") {
                        grid.currentIndex = 0;
                        e.accepted = true;
                    } else if (e.key === Qt.Key_End && text === "") {
                        grid.currentIndex = root.list.length - 1;
                        e.accepted = true;
                    }
                }
            }

            Text {
                id: counter
                anchors.verticalCenter: parent.verticalCenter
                text: root.term === "" ? files.count + "" : root.list.length + " / " + files.count
                color: Qt.rgba(1, 1, 1, 0.4)
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }

            // Random pick.
            Rectangle {
                id: randomBtn
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26
                radius: 13
                color: randomMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.08)
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.fast
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰒝"
                    color: "#ffffff"
                    font.family: Theme.font
                    font.pixelSize: 14
                }
                MouseArea {
                    id: randomMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickRandom()
                }
            }
        }
    }

    // ---- grid ----
    GridView {
        id: grid
        anchors.top: field.bottom
        anchors.topMargin: 12
        width: parent.width
        height: root.rows * root.cellH
        clip: true
        model: root.list
        cellWidth: root.cellW
        cellHeight: root.cellH
        cacheBuffer: root.cellH * 3
        boundsBehavior: Flickable.StopAtBounds
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 0
        preferredHighlightBegin: 0
        preferredHighlightEnd: height
        highlightRangeMode: GridView.ApplyRange
        keyNavigationWraps: false

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: e => {
                const max = Math.max(0, grid.contentHeight - grid.height);
                grid.contentY = Math.max(0, Math.min(max, grid.contentY - e.angleDelta.y * 1.2));
            }
        }

        delegate: Item {
            id: cell
            required property int index
            required property var modelData

            readonly property bool isNow: modelData.path === root.current
            readonly property bool isSel: GridView.isCurrentItem

            width: grid.cellWidth
            height: grid.cellHeight

            ClippingRectangle {
                id: tile
                anchors.fill: parent
                anchors.margins: 5
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                scale: cellMouse.containsMouse ? 1.04 : 1
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.fast
                        easing.type: Theme.easeOut
                    }
                }

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize: Qt.size(400, 250)
                    source: "file://" + root.thumbDir + "/" + cell.modelData.name + ".jpg"
                    // No thumbnail yet: fall back to the full image.
                    onStatusChanged: if (status === Image.Error)
                        source = "file://" + cell.modelData.path
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.normal
                        }
                    }
                }

                // Name, on hover or selection.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 24
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(0, 0, 0, 0.75)
                        }
                    }
                    opacity: cellMouse.containsMouse || (cell.isSel && input.activeFocus) ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        anchors.bottomMargin: 4
                        text: cell.modelData.name.replace(/\.[^.]+$/, "")
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.5)
                    visible: root.applying === cell.modelData.path
                    Text {
                        anchors.centerIn: parent
                        text: "󰑓"
                        color: "#ffffff"
                        font.family: Theme.font
                        font.pixelSize: 22
                        RotationAnimation on rotation {
                            running: root.applying === cell.modelData.path
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                    }
                }
            }

            // Current wallpaper: solid ring; keyboard selection: faint ring.
            Rectangle {
                anchors.fill: tile
                anchors.margins: -2
                radius: 14
                color: "transparent"
                border.width: 2
                border.color: cell.isNow ? "#ffffff" : Qt.rgba(1, 1, 1, 0.4)
                visible: cell.isNow || (cell.isSel && input.activeFocus)
            }

            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    grid.currentIndex = cell.index;
                    root.pick(cell.modelData.path);
                }
            }
        }

    }

    // Thin scrollbar (outside the view: Flickable children scroll with the content).
    Rectangle {
        anchors.right: grid.right
        anchors.rightMargin: -2
        width: 3
        radius: 1.5
        color: Qt.rgba(1, 1, 1, 0.3)
        visible: grid.contentHeight > grid.height
        height: Math.max(20, grid.height * grid.height / Math.max(1, grid.contentHeight))
        y: grid.y + (grid.height - height) * (grid.contentY / Math.max(1, grid.contentHeight - grid.height))
    }

    Text {
        anchors.centerIn: grid
        visible: root.list.length === 0
        text: files.count === 0 ? "No images in " + root.dir : "No match"
        color: root.dim
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }
}
