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
