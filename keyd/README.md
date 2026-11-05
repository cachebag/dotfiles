# keyd — Mac keyboard remap (MacBook only)

Makes ⌘ act as Ctrl (native macOS app shortcuts everywhere) and the left
Option key act as Super (the Hyprland WM modifier). See `default.conf`.

keyd isn't in the ALARM repos and its AUR package gates out aarch64, so build
it from source:

```sh
git clone --depth 1 https://github.com/rvaiya/keyd.git ~/keyd-build
cd ~/keyd-build && make
sudo make install                      # installs keyd + the systemd unit

sudo mkdir -p /etc/keyd
sudo cp ~/dotfiles/keyd/default.conf /etc/keyd/default.conf
sudo systemctl enable --now keyd
sudo keyd reload                        # applies default.conf
```

Check it: `sudo keyd monitor` then tap ⌘ (should report `leftcontrol`) and
left ⌥ (should report `leftmeta`). Ctrl-C to quit the monitor.

To undo: `sudo systemctl disable --now keyd`.
