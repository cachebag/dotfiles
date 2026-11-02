hl.monitor({
    output   = "desc:LG Electronics LG ULTRAGEAR 304NTJJCH612",
    mode     = "2560x1440@165",
    position = "0x0",
    scale    = 1,
})

-- portrait, to the right, vertically centered on the main monitor
hl.monitor({
    output    = "desc:LG Electronics LG ULTRAGEAR 103NTPCF4760",
    mode      = "2560x1440@144",
    position  = "2560x-560",
    scale     = 1,
    transform = 3,
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
        monitor    = "desc:LG Electronics LG ULTRAGEAR 304NTJJCH612",
        default    = i == 1,
        persistent = true,
    })
end

for i = 6, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = "desc:LG Electronics LG ULTRAGEAR 103NTPCF4760",
        default    = i == 6,
        persistent = true,
    })
end
