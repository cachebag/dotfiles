# diskring

Disk usage scanner behind the Quickshell storage overlay (`quickshell/Storage.qml`).

## Build

```sh
cargo build --release
install -m755 target/release/diskring ~/.local/bin/diskring
```

## CLI

```sh
diskring [PATH]                 # largest entries under PATH
diskring tree [PATH] -d 4       # pruned tree as JSON
diskring drives                 # mounted drives as JSON
diskring serve                  # JSON lines over stdio, used by the overlay
```

Scans stay on one filesystem, count on-disk blocks (like `du`), and count
hardlinks once. Deletes go through `gio trash`, so they can be undone.

## Overlay

`Super + Shift + D`, or `qs ipc call storage toggle`.
`qs ipc call storage browse ~/Downloads` opens zoomed into a directory.

| Input | Action |
|-------|--------|
| click | zoom into a directory |
| click centre / `⌫` | up one level |
| right-click / `d` | mark for trash |
| `o` | open in default app |
| `r` | rescan |
