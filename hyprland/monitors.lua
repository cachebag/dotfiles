hl.monitor({
    output   = "desc:HP Inc. HP E24u G4 CN4243130S",
    mode     = "1920x1080@60",
    position = "0x0",
    scale    = 1,
})
hl.monitor({
    output   = "desc:HP Inc. HP E24u G4 CN424312V5",
    mode     = "1920x1080@60",
    position = "1920x0",
    scale    = 1,
})
hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@60",
    position = "3840x250",
    scale    = 1,
})
hl.workspace_rule({
    workspace = "1",
    monitor = "desc:HP Inc. HP E24u G4 CN4243130S",
    default = true,
    persistent = true,
})
hl.workspace_rule({
    workspace = "2",
    monitor = "desc:HP Inc. HP E24u G4 CN424312V5",
    default = true,
    persistent = true,
})
hl.workspace_rule({
    workspace = "3",
    monitor = "eDP-1",
    default = true,
    persistent = true,
})
