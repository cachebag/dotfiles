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
hl.bind(mod .. " + S",         dsp.exec_cmd([[grim -g "$(slurp)" - | tee ~/Pictures/screenshots/$(date +%F_%H-%M-%S).png | wl-copy]]))  -- screenshot region -> clipboard + ~/Pictures/screenshots
hl.bind(mod .. " + SHIFT + S", dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]))   -- screenshot region -> annotate

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
-- F1/F2: screen brightness (apple-panel-bl, from the t6030-brightness appledrm
-- backport; 5% steps on a perceptual curve, never fully off).
-- Option+F1/F2: keyboard backlight.
hl.bind("XF86MonBrightnessDown", dsp.exec_cmd("brightnessctl -e4 -n2 -d apple-panel-bl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   dsp.exec_cmd("brightnessctl -e4 -n2 -d apple-panel-bl set 5%+"), { locked = true, repeating = true })
hl.bind(mod .. " + XF86MonBrightnessDown", dsp.exec_cmd("brightnessctl -d white:kbd_backlight set 10%-"), { locked = true, repeating = true })
hl.bind(mod .. " + XF86MonBrightnessUp",   dsp.exec_cmd("brightnessctl -d white:kbd_backlight set +10%"), { locked = true, repeating = true })
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
