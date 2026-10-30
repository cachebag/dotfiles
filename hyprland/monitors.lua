hl.monitor({
    output   = "desc:LG Electronics LG ULTRAGEAR 304NTJJCH612",
    mode     = "2560x1440@165",
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
        monitor    = "desc:LG Electronics LG ULTRAGEAR 304NTJJCH612",
        default    = i == 1,
        persistent = true,
    })
end
