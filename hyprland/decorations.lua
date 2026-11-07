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

-- Apple Music web app: lives in a hidden scratchpad, playing in the background.
-- Option+U (or the island's music button) slides it in and out.
hl.window_rule({
    name      = "apple-music-scratchpad",
    -- Chromium ignores --class for --app windows on Wayland; the class is URL-derived.
    match     = { class = "^chrome-music\\.apple\\.com.*$" },
    workspace = "special:music silent",
})

hl.window_rule({
    name   = "float-thunar",
    match  = { class = "thunar" },
    float  = true,
    center = true,
    size   = "900 600",
})
