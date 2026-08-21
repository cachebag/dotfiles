import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var bar
    property string applying: ""

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    FolderListModel {
        id: files
        folder: "file://" + Quickshell.env("HOME") + "/wallpapers"
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.PNG"]
        showDirs: false
        sortField: FolderListModel.Time
        sortReversed: true
    }

    Process {
        id: applier
        onExited: {
            root.applying = "";
            Theme.reload();
        }
    }

    function apply(path) {
        root.applying = path;
        applier.command = [Quickshell.env("HOME") + "/.config/hypr/scripts/wallpaper.sh", path];
        applier.running = true;
    }

    BarButton {
        id: btn
        anchors.fill: parent
        icon: "󰸉"
        active: picker.visible
        onClicked: picker.toggle()
    }

    Popup {
        id: picker
        bar: root.bar
        owner: root
        cardWidth: 600
        cardHeight: 420

        Column {
            anchors.fill: parent
            spacing: 10

            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: "󰸉"
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                }

                Text {
                    text: "Wallpapers"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                Item {
                    width: parent.width - 200
                    height: 1
                }

                Text {
                    text: files.count + " files"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
            }

            GridView {
                id: grid
                width: parent.width
                height: parent.height - 40
                clip: true
                cellWidth: width / 4
                cellHeight: cellWidth * 0.62
                model: files
                cacheBuffer: 400

                delegate: Item {
                    id: cell
                    required property string fileName
                    required property string filePath
                    required property url fileUrl

                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property bool busy: root.applying === filePath

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Theme.radius
                        color: Theme.alpha(Theme.fg, 0.05)
                        border.width: cell.busy || hover.containsMouse ? 2 : 0
                        border.color: Theme.accent
                        clip: true
                        scale: hover.pressed ? 0.95 : hover.containsMouse ? 1.04 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.fast
                                easing.type: Theme.easeBack
                            }
                        }
                        Behavior on border.width {
                            NumberAnimation {
                                duration: Theme.fast
                            }
                        }

                        Image {
                            id: thumb
                            anchors.fill: parent
                            source: cell.fileUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 320
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.normal
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 20
                            color: Theme.alpha(Theme.bg, 0.85)
                            y: hover.containsMouse ? parent.height - height : parent.height

                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.normal
                                    easing.type: Theme.easeOut
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 10
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.fileName
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.alpha(Theme.bg, 0.6)
                            visible: cell.busy

                            Text {
                                anchors.centerIn: parent
                                text: "󰑓"
                                color: Theme.accent
                                font.family: Theme.font
                                font.pixelSize: 20

                                RotationAnimator on rotation {
                                    running: cell.busy
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                }
                            }
                        }

                        MouseArea {
                            cursorShape: Qt.PointingHandCursor
                            id: hover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.apply(cell.filePath)
                        }
                    }
                }
            }
        }
    }
}
