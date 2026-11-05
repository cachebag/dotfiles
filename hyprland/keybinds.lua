local mod = "SUPER"
local dsp = hl.dsp
local win = hl.dsp.window

local home = os.getenv("HOME") or ""

-- Your desktop's binds, limited to what's installed on this Mac so far.
hl.bind(mod .. " + Return", dsp.exec_cmd("kitty"))
hl.bind(mod .. " + B",      dsp.exec_cmd("firefox"))
hl.bind(mod .. " + A",      dsp.exec_cmd(home .. "/.config/rofi/launchers/type-3/launcher.sh"))
hl.bind(mod .. " + Q",      win.close())
hl.bind(mod .. " + SHIFT + F", win.float({ action = "toggle" }))
hl.bind(mod .. " + K",      win.pseudo())
hl.bind(mod .. " + M",      dsp.exit())
hl.bind(mod .. " + F",      win.fullscreen())
hl.bind(mod .. " + Y",      dsp.exec_cmd("pkill quickshell; nohup quickshell >/dev/null 2>&1 &"))
hl.bind(mod .. " + W",      dsp.exec_cmd("qs ipc call island walls"))
hl.bind(mod .. " + L",      dsp.exec_cmd("qs ipc call lock lock"))
hl.bind(mod .. " + N",         dsp.exec_cmd("qs ipc call notifications toggle"))
hl.bind(mod .. " + SHIFT + N", dsp.exec_cmd("qs ipc call notifications toggleDnd"))

for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,           dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,   win.move({ workspace = i }))
end

-- App edit shortcuts (Cmd+C/V/X/Z/A/T/W/F/L/Space ...) are NOT bound here.
-- keyd remaps the physical Command key to Ctrl (keyd/default.conf), so apps
-- get them natively, and the window-manager modifier below ("SUPER") is the
-- Option key. See keyd/README.md.

hl.bind(mod .. " + CTRL + Left",  dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + Right", dsp.focus({ workspace = "e+1" }))

hl.bind(mod .. " + Left",  dsp.focus({ direction = "left" }))
hl.bind(mod .. " + Right", dsp.focus({ direction = "right" }))
-- Cmd+Up/Down: previous / next workspace.
hl.bind(mod .. " + Up",    dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + Down",  dsp.focus({ workspace = "e+1" }))

-- Top-row media keys (hid_apple fnmode=3 sends these by default).
-- No screen-brightness keys: the panel has no backlight device yet.
hl.bind("XF86AudioRaiseVolume", dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioPlay",        dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",       dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind(mod .. " + mouse:272", win.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", win.resize(), { mouse = true })

hl.bind(mod .. " + SHIFT + Left",  win.resize({ x = -40, y = 0,   relative = true }))
hl.bind(mod .. " + SHIFT + Right", win.resize({ x = 40,  y = 0,   relative = true }))
hl.bind(mod .. " + SHIFT + Up",    win.resize({ x = 0,   y = -40, relative = true }))
hl.bind(mod .. " + SHIFT + Down",  win.resize({ x = 0,   y = 40,  relative = true }))
