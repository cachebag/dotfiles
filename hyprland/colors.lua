local FALLBACK = {
    foregroundCol = 0xffdcd4c7,
    backgroundCol = 0xff1c0f0b,
    color0        = 0xff1c0f0b,
    color1        = 0xff905834,
    color2        = 0xff947253,
    color3        = 0xff79854E,
    color4        = 0xffA09561,
    color5        = 0xffC4A168,
    color6        = 0xffCCB59E,
    color7        = 0xffdcd4c7,
    color8        = 0xff9a948b,
    color9        = 0xff905834,
    color10       = 0xff947253,
    color11       = 0xff79854E,
    color12       = 0xffA09561,
    color13       = 0xffC4A168,
    color14       = 0xffCCB59E,
    color15       = 0xffdcd4c7,
}
local function parse(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local out, found = {}, false
    for line in f:lines() do
        local key, value = line:match("^%s*%$([%w_]+)%s*=%s*(0[xX]%x+)%s*$")
        if key then
            local n = tonumber(value)
            if n then
                out[key] = n
                found = true
            end
        end
    end
    f:close()
    return found and out or nil
end
local home = os.getenv("HOME") or ""
local colors = parse(home .. "/.cache/wal/colors-hyprland.conf")
    or parse(home .. "/.config/hypr/colors.conf")
    or {}
for key, value in pairs(FALLBACK) do
    if colors[key] == nil then colors[key] = value end
end
return colors
