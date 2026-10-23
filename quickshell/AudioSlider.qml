import QtQuick

Item {
    id: root

    property real value: 0
    property bool dimmed: false
    // 0–1 overlay drawn under the fill, e.g. a live mic level.
    property real level: -1

    signal moved(real value)

    implicitHeight: 16

    function set(x) {
        root.moved(Math.max(0, Math.min(1, x / track.width)));
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Theme.line

        Rectangle {
            visible: root.level >= 0
            height: parent.height
            radius: 2
            width: parent.width * Math.max(0, Math.min(1, root.level))
            color: Theme.alpha(Theme.accentAlt, 0.55)
        }

        Rectangle {
            height: parent.height
            radius: 2
            width: parent.width * root.value
            color: root.dimmed ? Theme.muted : Theme.accent
            opacity: root.level >= 0 ? 0.5 : 1

            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation {
                    duration: Theme.fast
                    easing.type: Theme.easeOut
                }
            }
        }
    }

    Rectangle {
        x: track.width * root.value - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: drag.pressed || drag.containsMouse ? 12 : 10
        height: width
        radius: width / 2
        color: root.dimmed ? Theme.muted : Theme.accent

        Behavior on width {
            NumberAnimation {
                duration: Theme.fast
            }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -4
        anchors.bottomMargin: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: function (e) {
            root.set(e.x);
        }
        onPositionChanged: function (e) {
            if (pressed)
                root.set(e.x);
        }
        onWheel: function (e) {
            root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.02 : -0.02))));
        }
    }
}
