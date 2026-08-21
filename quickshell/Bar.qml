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
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            bottom: parent.bottom
        }
        spacing: Theme.gap

        MediaPill {
            bar: bar
            Layout.alignment: Qt.AlignVCenter
        }
    }

    RowLayout {
        anchors {
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            rightMargin: Theme.gap
        }
        spacing: 2

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

        Resources {
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
