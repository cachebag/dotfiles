local mod = "SUPER"
local dsp = hl.dsp
local win = hl.dsp.window

local home = os.getenv("HOME") or ""

hl.bind(mod .. " + Return", dsp.exec_cmd("kitty"))
hl.bind(mod .. " + B",      dsp.exec_cmd("firefox"))
hl.bind(mod .. " + Q",      win.close())
hl.bind(mod .. " + E",      dsp.exec_cmd("thunar"))
hl.bind(mod .. " + A",      dsp.exec_cmd(home .. "/.config/rofi/launchers/type-3/launcher.sh"))
hl.bind(mod .. " + V",      win.float({ action = "toggle" }))
hl.bind(mod .. " + K",      win.pseudo())
hl.bind(mod .. " + M",      dsp.exit())
hl.bind(mod .. " + D",      dsp.exec_cmd("chromium --app=https://chat.com --class=ChatGPT"))
hl.bind(mod .. " + I",      dsp.exec_cmd("chromium --app=https://web.whatsapp.com --class=Whatsapp"))
hl.bind(mod .. " + W",      dsp.exec_cmd("kitty --class wallpaper-picker " .. home .. "/.config/hypr/scripts/wallpaper.sh"))
hl.bind(mod .. " + S",      dsp.exec_cmd([[grim -g "$(slurp)" - | wl-copy]]))
hl.bind(mod .. " + O",      dsp.exec_cmd("obsidian"))
hl.bind(mod .. " + Y",      dsp.exec_cmd("pkill quickshell; nohup quickshell >/dev/null 2>&1 &"))

hl.bind(mod .. " + P", dsp.exec_cmd(home .. "/dotfiles/scripts/power_menu.sh"))
hl.bind(mod .. " + L", dsp.exec_cmd(home .. "/dotfiles/scripts/lock.sh"))

local function fn_bind(key, command, repeating)
    hl.bind(key, dsp.exec_cmd(command), {
        locked = true,
        repeating = repeating or false,
    })
end

-- Speaker and microphone controls.
fn_bind("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", true)
fn_bind("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true)
fn_bind("XF86AudioMute",        "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
fn_bind("XF86AudioMicMute",     "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")

-- Screen and keyboard backlight controls.
fn_bind("XF86MonBrightnessUp",   "brightnessctl -q -e4 -n2 set 5%+", true)
fn_bind("XF86MonBrightnessDown", "brightnessctl -q -e4 -n2 set 5%-", true)
fn_bind("XF86KbdBrightnessUp",   "brightnessctl -q -c leds -d '*::kbd_backlight' -n 0 set +1", true)
fn_bind("XF86KbdBrightnessDown", "brightnessctl -q -c leds -d '*::kbd_backlight' -n 0 set 1-", true)

-- Media transport controls.
fn_bind("XF86AudioPlay",  "playerctl play-pause")
fn_bind("XF86AudioPause", "playerctl play-pause")
fn_bind("XF86AudioPrev",  "playerctl previous")
fn_bind("XF86AudioNext",  "playerctl next")
fn_bind("XF86AudioStop",  "playerctl stop")

for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,           dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,   win.move({ workspace = i }))
end

hl.bind(mod .. " + CTRL + Left",  dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + CTRL + Right", dsp.focus({ workspace = "e+1" }))

hl.bind(mod .. " + Left",  dsp.focus({ direction = "left" }))
hl.bind(mod .. " + Right", dsp.focus({ direction = "right" }))
hl.bind(mod .. " + Up",    dsp.focus({ direction = "up" }))
hl.bind(mod .. " + Down",  dsp.focus({ direction = "down" }))

hl.bind(mod .. " + mouse:272", win.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", win.resize(), { mouse = true })

hl.bind(mod .. " + SHIFT + Left",  win.resize({ x = -40, y = 0,   relative = true }))
hl.bind(mod .. " + SHIFT + Right", win.resize({ x = 40,  y = 0,   relative = true }))
hl.bind(mod .. " + SHIFT + Up",    win.resize({ x = 0,   y = -40, relative = true }))
hl.bind(mod .. " + SHIFT + Down",  win.resize({ x = 0,   y = 40,  relative = true }))

