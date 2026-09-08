local colors = require("colors")
hl.config({
    general = {
        gaps_in = 0,
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
    },
    animations = {
        enabled = false,
    },
    render = {
        -- Lets a fullscreen app's buffer go straight to the display instead of
        -- being composited first. Only helps fullscreen, but it is free.
        direct_scanout = true,
    },
})
