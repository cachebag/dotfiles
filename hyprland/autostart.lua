hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

local home = os.getenv("HOME") or ""

-- hypridle isn't set up on this Mac yet. Add it back here once installed.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("bash -c 'sleep 0.5 && hyprpaper --config " .. home .. "/.config/hypr/hyprpaper.conf'")
    -- Recolours from the wallpaper once python-pywal is installed.
    hl.exec_cmd(home .. "/dotfiles/scripts/wal-watch.sh")
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)
