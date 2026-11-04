-- MacBook Pro 14" M3 Pro: built-in panel, 120 Hz on the Aurora kernel
hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = 2,
})

-- catch-all so any display plugged in later gets placed automatically
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
