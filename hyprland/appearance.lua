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
        -- No vrr here: the built-in panel's 120 Hz comes from the driver's
        -- swap timestamps, and turning VRR on didn't help when tested.
    },

    -- The M3 Pro's display driver doesn't do hardware cursors yet.
    cursor = {
        no_hardware_cursors = true,
    },

    animations = {
        enabled = false,
    },
})
