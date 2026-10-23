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

    // Claims org.freedesktop.PolicyKit1.AuthenticationAgent for the session.
    PolkitDialog {}
}
