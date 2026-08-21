hl.monitor({
    output   = "HDMI-A-1",
    mode     = "2560x1440@144",
    position = "0x0",
    scale    = 1,
})

-- catch-all so any display plugged in later gets placed automatically
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

for i = 1, 5 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = "HDMI-A-1",
        default    = i == 1,
        persistent = true,
    })
end
