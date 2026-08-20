hl.monitor({
    output   = "DP-2",
    mode     = "2560x1440@165",
    position = "0x0",
    scale    = 1,
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "2560x1440@165",
    position = "2560x-25",
    scale    = 1,
})

hl.workspace_rule({ workspace = "1", monitor = "DP-2",     default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-2",                     persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-2",                     persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", default = true, persistent = true })
