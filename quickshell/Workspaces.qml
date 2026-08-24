import QtQuick
import Quickshell.Hyprland

Item {
    id: root

    readonly property int slot: 26
    readonly property int spacing: 2

    readonly property var list: {
        const v = Hyprland.workspaces.values.filter(w => w.id > 0);
        v.sort((a, b) => a.id - b.id);
        return v;
    }

    readonly property int activeIndex: {
        const f = Hyprland.focusedWorkspace;
        if (!f)
            return 0;
        for (var i = 0; i < list.length; i++)
            if (list[i].id === f.id)
                return i;
        return 0;
    }

    implicitWidth: Math.max(1, list.length) * (slot + spacing) - spacing + Theme.pad
    implicitHeight: Theme.barHeight - 8

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Theme.easeOut
        }
    }

    Rectangle {
        id: pill
        y: (parent.height - height) / 2
        x: Theme.pad / 2 + root.activeIndex * (root.slot + root.spacing)
        width: root.slot
        height: parent.height
        radius: Theme.radius
        color: Theme.alpha(Theme.accent, 0.20)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.45)
        visible: root.list.length > 0

        Behavior on x {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Theme.easeBack
                easing.overshoot: 1.1
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.pad / 2
        spacing: root.spacing

        Repeater {
            model: root.list

            delegate: Item {
                id: ws
                required property var modelData
                required property int index

                readonly property bool isActive: index === root.activeIndex
                readonly property int windowCount: modelData.lastIpcObject?.windows ?? 0

                width: root.slot
                height: root.height

                Text {
                    anchors.centerIn: parent
                    text: ws.modelData.name
                    color: ws.isActive ? Theme.accent : ws.windowCount > 0 ? Theme.fg : Theme.muted
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: ws.isActive
                    scale: ws.isActive ? 1.0 : hover.containsMouse ? 1.12 : 0.92

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.fast
                            easing.type: Theme.easeBack
                        }
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 3
                    height: 3
                    radius: 1.5
                    color: Theme.accentAlt
                    opacity: !ws.isActive && ws.windowCount > 0 ? 0.9 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.normal
                        }
                    }
                }

                MouseArea {
                    cursorShape: Qt.PointingHandCursor
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + ws.modelData.id + " })")
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function (e) {
            Hyprland.dispatch(e.angleDelta.y > 0 ? 'hl.dsp.focus({ workspace = "e-1" })' : 'hl.dsp.focus({ workspace = "e+1" })');
        }
    }
}
