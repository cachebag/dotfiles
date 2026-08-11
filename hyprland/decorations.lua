-- was: decorations.conf

hl.config({
    decoration = {
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xaa000000, -- was rgba(000000aa)
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

hl.window_rule({
    name  = "float-nmrs",
    match = { class = "org.nmrs.ui" },
    float = true,
})

hl.window_rule({
    name   = "float-yazi",
    match  = { class = "wallpaper-picker" },
    float  = true,
    center = true,
    size   = "900 600",
})

-- NOTE: in decorations.conf this block had no `match:` line at all -- a
-- copy-paste slip, so its float/center/size never applied to anything (thunar
-- only floated because of the separate `windowrule = float 1, match:class thunar`
-- line). A match-less rule is still accepted by the Lua parser but risks applying
-- to every window, so the intended match is now explicit. This is the one place
-- where behaviour changes: thunar now also gets centered at 900x600.
hl.window_rule({
    name   = "float-thunar",
    match  = { class = "thunar" },
    float  = true,
    center = true,
    size   = "900 600",
})
