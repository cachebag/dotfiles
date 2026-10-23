hl.config({
    decoration = {
        active_opacity   = 0.95,
        inactive_opacity = 0.80,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "0xaa000000",
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            vibrancy          = 0.15,
            new_optimizations = true,
            ignore_opacity    = false,
            xray              = false,
        },
    },
})

hl.layer_rule({
    name         = "blurs-blur",
    match        = { namespace = "^blurs$" },
    blur         = true,
    ignore_alpha = 0.3,
})

hl.window_rule({
    name   = "float-yazi",
    match  = { class = "wallpaper-picker" },
    float  = true,
    center = true,
    size   = "900 600",
})

hl.window_rule({
    name   = "float-thunar",
    match  = { class = "thunar" },
    float  = true,
    center = true,
    size   = "900 600",
})

-- Overwatch: real fullscreen (hides the bar), no blur/transparency, tearing allowed
hl.config({ general = { allow_tearing = true } })

hl.window_rule({
    name       = "overwatch",
    match      = { class = "^steam_app_2357570$" },
    fullscreen = true,
    immediate  = true,
    no_blur    = true,
    opaque     = true,
})
