-- Hyprland config entry point.
--
-- Migrated from the hyprlang .conf format (deprecated since 0.55, removed in 0.57).
-- The old .conf files are kept alongside these; Hyprland prefers hyprland.lua and
-- falls back to hyprland.conf, so renaming this file is a complete rollback.
--
-- require() resolves relative to this directory (~/.config/hypr).

require("monitors")
require("autostart")
require("appearance")
require("decorations")
require("keybinds")
require("input")
