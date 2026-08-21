import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    required property var bar

    readonly property var list: ToplevelManager.toplevels.values

    implicitHeight: Theme.barHeight - 8
    implicitWidth: row.implicitWidth
    clip: true

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Repeater {
            model: root.list

            delegate: Item {
                id: task
                required property var modelData

                readonly property bool isActive: ToplevelManager.activeToplevel === modelData
                readonly property string appId: modelData.appId ?? ""
                readonly property string appTitle: modelData.title ?? ""

                readonly property string iconSource: AppIcons.resolve(task.appId, task.appTitle)

                height: root.height
                width: content.implicitWidth + Theme.pad * 2

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.normal
                        easing.type: Theme.easeOut
                    }
                }

                TextMetrics {
                    id: metrics
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    text: task.appTitle
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: task.isActive ? Theme.alpha(Theme.accent, 0.15) : mouse.pressed ? Theme.press : mouse.containsMouse ? Theme.hover : "transparent"
                    scale: mouse.pressed ? 0.94 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 6

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        asynchronous: true
                        source: task.iconSource
                        opacity: task.isActive ? 1.0 : 0.75

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.fast
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: task.isActive ? Math.min(metrics.width, 180) : 0
                        visible: width > 0
                        clip: true
                        elide: Text.ElideRight
                        text: task.appTitle
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.normal
                                easing.type: Theme.easeOut
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 2
                    radius: 1
                    width: task.isActive ? parent.width * 0.5 : 0
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.normal
                            easing.type: Theme.easeBack
                        }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    onClicked: function (e) {
                        if (e.button === Qt.MiddleButton)
                            task.modelData.close();
                        else
                            task.modelData.activate();
                    }
                }

                Tooltip {
                    bar: root.bar
                    owner: task
                    show: mouse.containsMouse && !task.isActive
                    text: task.appTitle !== "" ? task.appTitle : task.appId
                }
            }
        }
    }
}
