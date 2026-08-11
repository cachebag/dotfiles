# blurs

A tiny Bluetooth applet for Wayland.

![blurs](https://img.shields.io/badge/rust-2024-orange) ![size](https://img.shields.io/badge/binary-1.4M-blue)

## Build

```sh
cargo build --release
install -m755 target/release/blurs ~/.local/bin/blurs
```

Release profile is tuned for size (`opt-level="z"`, fat LTO, one codegen unit,
`panic=abort`, stripped).

## Integration

waybar (`waybar/config`) launches it from the bluetooth module:

```json
"bluetooth": { "on-click": "/home/cachebag/.local/bin/blurs" }
```

Hyprland needs a **layer** rule.

```lua
hl.layer_rule({
    name = "blurs-blur",
    match = { namespace = "^blurs$" },
    blur = true,
    ignore_alpha = 0.3,
})
```

## Placement

`~/.config/blurs/config`, or the same names as `--flags` (flags win):

```
anchor = cursor
margin = 8
width  = 360
max-height = 420
```

Anchors: `top-left` `top` `top-right` `left` `center` `right` `bottom-left`
`bottom` `bottom-right` `cursor`.

`cursor` opens the panel over the pointer, so it lands above whichever bar
module was clicked regardless of where that module sits. Wayland exposes no
global pointer and layer-shell can't anchor to another surface, so this reads
Hyprland's IPC socket; it falls back to a fixed corner where that's absent.

## Theming

Colors are read from `~/.cache/wal/colors.sh` at startup and emitted as GTK
`@define-color` values, so the applet re-tints with the wallpaper for free.
`colors.sh` is parsed instead of `colors.json` purely to keep a JSON parser out
of the binary.

Use `~/.config/blurs/style.css` to override the built-in stylesheet entirely;
the `@define-color` block is still prepended, so pywal names stay available.

# License

MIT
