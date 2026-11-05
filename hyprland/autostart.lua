hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

local home = os.getenv("HOME") or ""

hl.on("hyprland.start", function()
    -- tty1 logs in automatically on this Mac (its text console is blank),
    -- so quickshell starts locked (Lock.qml): the password is asked here
    -- instead of at the console.
    hl.exec_cmd("QS_LOCK_ON_START=1 quickshell")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("bash -c 'sleep 0.5 && hyprpaper --config " .. home .. "/.config/hypr/hyprpaper.conf'")
    -- Recolours from the wallpaper once python-pywal is installed.
    hl.exec_cmd(home .. "/dotfiles/scripts/wal-watch.sh")
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)
