-- was: autostart.conf

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Dropped from autostart.conf: `splash = false`. It was never a real Hyprland
-- keyword (it belongs to hyprpaper.conf) and hyprlang silently swallowed it --
-- `hyprctl getoption misc:disable_splash_rendering` confirmed it was still unset.
-- Dropping it is behaviour-preserving. If you *did* want the splash text gone,
-- add `misc = { disable_splash_rendering = true }` in appearance.lua.

hl.workspace_rule({ workspace = "1", monitor = "DP-2",      default = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1", default = true })

local home = os.getenv("HOME") or ""

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("bash -c 'sleep 0.5 && hyprpaper --config " .. home .. "/.config/hypr/hyprpaper.conf'")
    hl.exec_cmd("hypridle")
    hl.exec_cmd(home .. "/dotfiles/scripts/wal-watch.sh")

    -- was: exec-once = hyprctl dispatch ... (now dispatched natively)
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
    hl.dispatch(hl.dsp.focus({ monitor = "DP-2" }))
end)
