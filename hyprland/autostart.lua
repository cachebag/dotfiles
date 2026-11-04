hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Nothing autostarts yet: quickshell, hyprpaper and hypridle aren't installed
-- on this Mac. Add them back here as they're set up.
hl.on("hyprland.start", function()
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)
