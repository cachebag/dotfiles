import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors {
        left: true
        right: true
        bottom: true
    }

    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.bg, Theme.barOpacity)

        Behavior on color {
            ColorAnimation {
                duration: Theme.slow
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: 1
            color: Theme.line
        }
    }

    RowLayout {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            leftMargin: Theme.gap
            right: centerRow.left
            rightMargin: Theme.gap
        }
        spacing: Theme.gap

        LauncherButton {
            Layout.alignment: Qt.AlignVCenter
        }

        Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }

        TaskBar {
            bar: bar
            Layout.fillWidth: true
            Layout.maximumWidth: 560
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
        }
    }

    RowLayout {
        id: centerRow
        anchors {
            top: parent.top
            bottom: parent.bottom
        }
        spacing: Theme.gap

        // Centred while there's room, otherwise slid left just far enough to clear
        // the right-hand group — the pill keeps its width instead of truncating.
        // The floor stops it from crowding the launcher/workspaces on the left.
        // Must not reference leftRow: that anchors to centerRow.left, so reading
        // its width here would be a binding loop.
        x: Math.max(240, Math.min((bar.width - width) / 2, bar.width - rightRow.width - Theme.gap * 2 - width))

        Behavior on x {
            NumberAnimation {
                duration: Theme.normal
                easing.type: Theme.easeOut
            }
        }

        MediaPill {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }
    }

    RowLayout {
        id: rightRow

        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            rightMargin: Theme.gap
        }
        spacing: 2

        NotificationCenter {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }

        TrayArea {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            width: 1
            height: 16
            color: Theme.line
        }

        AudioControl {
            Layout.alignment: Qt.AlignVCenter
        }

        BluetoothControl {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }

        Resources {
            Layout.alignment: Qt.AlignVCenter
        }

        Network {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }

        WallpaperPicker {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }

        Clock {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }

        PowerMenu {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
