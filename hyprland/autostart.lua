hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

local home = os.getenv("HOME") or ""

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("bash -c 'sleep 0.5 && hyprpaper --config " .. home .. "/.config/hypr/hyprpaper.conf'")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(home .. "/dotfiles/scripts/wal-watch.sh")

    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
    hl.dispatch(hl.dsp.focus({ monitor = "DP-2" }))
end)
