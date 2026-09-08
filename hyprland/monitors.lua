-- Monitor layout for three situations: home desk, office desk, laptop alone.
--
-- Which one applies is decided by reading the EDID of every connected DRM
-- connector and looking for a known panel. Matching on EDID rather than on a
-- connector name means it still works if the cable moves to another port.

local CONNECTORS = {
    "eDP-1",
    "HDMI-A-1", "HDMI-A-2", "HDMI-A-3",
    "DP-1", "DP-2", "DP-3", "DP-4", "DP-5", "DP-6",
}

local function read_file(path, mode)
    local f = io.open(path, mode or "r")
    if not f then
        return nil
    end
    local data = f:read("*a")
    f:close()
    return data
end

-- True when some connected output's EDID contains `needle`.
local function panel_present(needle)
    for card = 0, 3 do
        for _, conn in ipairs(CONNECTORS) do
            local base = string.format("/sys/class/drm/card%d-%s/", card, conn)
            local status = read_file(base .. "status")
            if status and status:match("^connected") then
                local edid = read_file(base .. "edid", "rb")
                if edid and edid:find(needle, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end

-- True when anything other than the laptop's own panel is connected.
local function external_present()
    for card = 0, 3 do
        for _, conn in ipairs(CONNECTORS) do
            if conn ~= "eDP-1" then
                local status = read_file(string.format("/sys/class/drm/card%d-%s/status", card, conn))
                if status and status:match("^connected") then
                    return true
                end
            end
        end
    end
    return false
end

-- Which GPU composites. Both the home LG and the office HPs are wired to the
-- NVIDIA A3000 (PCI 01:00.0); the laptop panel is on the Intel iGPU (00:02.0).
-- Left to itself Hyprland makes the Intel chip primary, so every external frame
-- is rendered there and copied across the bus, and at 1440p@144 that pins the
-- iGPU at its max clock. Docked, put NVIDIA first. Undocked, leave Intel first
-- so the NVIDIA card can power down on battery.
--
-- Read once at startup only: changing it needs a logout, not a reload.
--
-- AQ_DRM_DEVICES is split on ":", so /dev/dri/by-path names (which contain
-- colons) cannot be used. /dev/dri/cardN numbering changes between boots, so
-- the node for each PCI slot is looked up in sysfs at startup instead.
local function card_for_pci(slot)
    for n = 0, 9 do
        local uevent = read_file(string.format("/sys/class/drm/card%d/device/uevent", n))
        if uevent and uevent:find("PCI_SLOT_NAME=" .. slot, 1, true) then
            local node = string.format("/dev/dri/card%d", n)
            local f = io.open(node, "r")
            if f then
                f:close()
                return node
            end
        end
    end
    return nil
end

local nvidia = card_for_pci("0000:01:00.0")
local intel = card_for_pci("0000:00:02.0")

-- Only ever hand Hyprland a complete, verified list. Anything less falls back
-- to its own GPU choice rather than a backend that cannot start.
if nvidia and intel then
    if external_present() then
        hl.env("AQ_DRM_DEVICES", nvidia .. ":" .. intel)
    else
        hl.env("AQ_DRM_DEVICES", intel .. ":" .. nvidia)
    end
end

local LG_DESC = "desc:LG Electronics LG ULTRAGEAR 304NTJJCH612"
local HP_LEFT = "desc:HP Inc. HP E24u G4 CN4243130S"
local HP_RIGHT = "desc:HP Inc. HP E24u G4 CN424312V5"

local at_home = panel_present("ULTRAGEAR")
local at_office = panel_present("HP E24u G4")

-- 143.99 is the ceiling for 1440p over HDMI 2.0. Change to @165 only after
-- moving this monitor to DisplayPort, which has the bandwidth for it.
if at_home then
    hl.monitor({
        output = LG_DESC,
        mode = "2560x1440@143.99",
        position = "0x0",
        scale = 1,
    })
elseif at_office then
    hl.monitor({
        output = HP_LEFT,
        mode = "1920x1080@60",
        position = "0x0",
        scale = 1,
    })
    hl.monitor({
        output = HP_RIGHT,
        mode = "1920x1080@60",
        position = "1920x0",
        scale = 1,
    })
end

-- The laptop sits to the right of whatever externals are present, and is the
-- only screen when there are none. Positions are explicit: "auto-right" is
-- resolved in the order Hyprland enumerates outputs, which puts the internal
-- panel before the DP ports and would wedge it between the two HPs.
local laptop_x = "0x0"
if at_home then
    laptop_x = "2560x0"
elseif at_office then
    laptop_x = "3840x0"
end

hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = laptop_x,
    scale = 1,
})

-- Anything unrecognised still gets a sane layout instead of being left off.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto-right",
    scale = 1,
})

-- Workspaces follow the primary screen for the current desk, with one parked
-- on the laptop panel.
local primary = at_home and LG_DESC or (at_office and HP_LEFT or "eDP-1")
local secondary = at_office and HP_RIGHT or primary

hl.workspace_rule({ workspace = "1", monitor = primary, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = secondary, default = true, persistent = true })

if at_home or at_office then
    hl.workspace_rule({ workspace = "3", monitor = "eDP-1", default = true, persistent = true })
end
