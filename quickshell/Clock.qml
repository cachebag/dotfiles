import QtQuick
import Quickshell

Item {
    id: root

    required property var bar

    property date now: new Date()

    property int vYear: now.getFullYear()
    property int vMonth: now.getMonth()

    readonly property var cells: {
        const first = new Date(vYear, vMonth, 1).getDay();
        const days = new Date(vYear, vMonth + 1, 0).getDate();
        const out = [];
        for (var i = 0; i < first; i++)
            out.push(0);
        for (var d = 1; d <= days; d++)
            out.push(d);
        while (out.length % 7 !== 0)
            out.push(0);
        return out;
    }

    implicitWidth: btn.implicitWidth
    implicitHeight: Theme.barHeight - 8

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    BarButton {
        id: btn
        anchors.fill: parent
        icon: "󰥔"
        label: Qt.formatDateTime(root.now, "HH:mm")
        active: cal.visible
        onClicked: {
            root.vYear = root.now.getFullYear();
            root.vMonth = root.now.getMonth();
            cal.toggle();
        }
    }

    Popup {
        id: cal
        bar: root.bar
        owner: root
        cardWidth: 280
        cardHeight: 290

        Column {
            anchors.fill: parent
            spacing: 8

            Row {
                width: parent.width

                Text {
                    text: "󰅁"
                    color: prevM.containsMouse ? Theme.accent : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: prevM
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: {
                            if (root.vMonth === 0) {
                                root.vMonth = 11;
                                root.vYear--;
                            } else
                                root.vMonth--;
                        }
                    }
                }

                Text {
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(new Date(root.vYear, root.vMonth, 1), "MMMM yyyy")
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    text: "󰅂"
                    color: nextM.containsMouse ? Theme.accent : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        id: nextM
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: {
                            if (root.vMonth === 11) {
                                root.vMonth = 0;
                                root.vYear++;
                            } else
                                root.vMonth++;
                        }
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 7

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]

                    delegate: Text {
                        required property var modelData
                        width: parent.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                    }
                }
            }

            Grid {
                width: parent.width
                columns: 7

                Repeater {
                    model: root.cells

                    delegate: Item {
                        required property var modelData
                        required property int index

                        readonly property bool isToday: modelData === root.now.getDate() && root.vMonth === root.now.getMonth() && root.vYear === root.now.getFullYear()

                        width: parent.width / 7
                        height: 30

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: Theme.radius
                            color: parent.isToday ? Theme.accent : "transparent"
                            scale: parent.isToday ? 1 : 0.8

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.normal
                                    easing.type: Theme.easeBack
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: parent.modelData > 0
                            text: parent.modelData
                            color: parent.isToday ? Theme.bg : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            font.bold: parent.isToday
                        }
                    }
                }
            }
        }
    }
}
