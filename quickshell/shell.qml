//@ pragma UseQApplication

import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {}
        }
    }

    // Single instance: toasts belong on one screen, not mirrored across all of them.
    NotificationToasts {}

    // Slide-out panel: toggles, sliders, media, notification history.
    ControlCenter {}

    // Sunburst disk usage overlay, `qs ipc call storage toggle`.
    Storage {}

    // Claims org.freedesktop.PolicyKit1.AuthenticationAgent for the session.
    PolkitDialog {}
}
