hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

local home = os.getenv("HOME") or ""

hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.exec_cmd("bash -c 'sleep 0.5 && hyprpaper --config " .. home .. "/.config/hypr/hyprpaper.conf'")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(home .. "/dotfiles/scripts/wal-watch.sh")
    hl.exec_cmd("bash -c 'nmrs-gui --tray --app-id nmrs-popup --layout compact'")
    -- Apple Music into its scratchpad. First Chromium instance of the session,
    -- so the autoplay flag applies: the island can start playback with no click.
    hl.exec_cmd("chromium --app=https://music.apple.com/us/home --class=Apple-Music --autoplay-policy=no-user-gesture-required")

    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)
