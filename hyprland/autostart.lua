hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- hyprpaper, hypridle and the wal watcher aren't set up on this Mac yet.
-- Add them back here as they're installed.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell")
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)
