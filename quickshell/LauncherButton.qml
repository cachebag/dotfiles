import Quickshell

BarButton {
    icon: "󰣇"
    contentColor: Theme.accent
    onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/rofi/launchers/type-3/launcher.sh"])
}
