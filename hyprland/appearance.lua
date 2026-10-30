local colors = require("colors")

hl.config({
    general = {
        gaps_in  = 0,
        gaps_out = 0,
        col = {
            active_border   = colors.backgroundCol,
            inactive_border = colors.backgroundCol,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
        -- G-Sync over DisplayPort, fullscreen windows only (games), so the
        -- desktop doesn't flicker at low refresh rates.
        vrr = 2,
    },

    animations = {
        enabled = false,
    },
})
