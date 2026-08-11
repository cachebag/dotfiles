-- was: appearance.conf

local colors = require("colors")

hl.config({
    general = {
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
    },

    animations = {
        enabled = false,
    },
})
