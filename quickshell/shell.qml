//@ pragma UseQApplication
//@ pragma Env QSG_USE_SIMPLE_ANIMATION_DRIVER=1

import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {}
        }
    }

    // Persistent top-centre island on every monitor: media, pop-ups, privacy dots.
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Island {}
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

    // Session lock, `qs ipc call lock lock`.
    Lock {}
}
