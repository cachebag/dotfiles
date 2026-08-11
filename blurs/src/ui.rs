use std::cell::RefCell;
use std::rc::Rc;

use gtk::prelude::*;
use gtk::{Align, Orientation, gdk, glib};
use layer_shell::{Edge, KeyboardMode, Layer, LayerShell};

use crate::bluez::{Cmd, Device, Evt, State};
use crate::config::{Anchor, Config, cursor_margins};

/// Anchors the window over the pointer. Returns false if the pointer or its
/// monitor can't be resolved, leaving the caller to use a fixed anchor.
fn place_at_cursor(window: &gtk::ApplicationWindow, cfg: Config) -> bool {
    let Some(cursor) = crate::pointer::cursor_position() else {
        return false;
    };
    let Some(display) = gdk::Display::default() else {
        return false;
    };

    // Pick the monitor containing the pointer so margins are monitor-local.
    let monitors = display.monitors();
    let mut found = None;
    for i in 0..monitors.n_items() {
        let Some(m) = monitors.item(i).and_then(|o| o.downcast::<gdk::Monitor>().ok()) else {
            continue;
        };
        let g = m.geometry();
        if cursor.0 >= g.x()
            && cursor.0 < g.x() + g.width()
            && cursor.1 >= g.y()
            && cursor.1 < g.y() + g.height()
        {
            found = Some((m, g));
            break;
        }
    }
    let Some((monitor, geo)) = found else {
        return false;
    };

    let (left, vertical, below) = cursor_margins(
        cursor,
        (geo.x(), geo.y(), geo.width(), geo.height()),
        cfg.width,
        cfg.margin,
    );

    window.set_monitor(Some(&monitor));
    window.set_anchor(Edge::Left, true);
    window.set_margin(Edge::Left, left);

    let edge = if below { Edge::Top } else { Edge::Bottom };
    window.set_anchor(edge, true);
    window.set_margin(edge, vertical);
    true
}

/// Maps BlueZ's `Icon` property onto names guaranteed by the icon theme.
fn icon_name(icon: &str) -> &'static str {
    match icon {
        "audio-headset" | "audio-headphones" => "audio-headphones-symbolic",
        "audio-card" | "multimedia-player" => "audio-speakers-symbolic",
        "input-keyboard" => "input-keyboard-symbolic",
        "input-mouse" => "input-mouse-symbolic",
        "input-gaming" => "input-gaming-symbolic",
        "input-tablet" => "input-tablet-symbolic",
        "phone" => "phone-symbolic",
        "computer" => "computer-symbolic",
        "printer" => "printer-symbolic",
        "camera-photo" | "camera-video" => "camera-photo-symbolic",
        _ => "bluetooth-symbolic",
    }
}

fn signal_label(rssi: Option<i16>) -> &'static str {
    match rssi {
        Some(r) if r >= -60 => "strong",
        Some(r) if r >= -75 => "ok",
        Some(_) => "weak",
        None => "",
    }
}

fn meta_text(d: &Device) -> String {
    let mut parts: Vec<&str> = Vec::new();
    if d.connected {
        parts.push("connected");
    } else if d.paired {
        parts.push("paired");
    }
    if d.trusted {
        parts.push("trusted");
    }
    let sig = signal_label(d.rssi);
    if !sig.is_empty() && !d.connected {
        parts.push(sig);
    }
    if parts.is_empty() {
        d.address.clone()
    } else {
        parts.join(" · ")
    }
}

struct Ui {
    list: gtk::ListBox,
    power: gtk::Switch,
    scan: gtk::ToggleButton,
    spinner: gtk::Spinner,
    status: gtk::Label,
    subtitle: gtk::Label,
    /// Guards the widget handlers while we write state from a D-Bus snapshot,
    /// which would otherwise echo the change straight back to BlueZ.
    syncing: RefCell<bool>,
    busy: RefCell<Vec<String>>,
}

pub fn build(
    app: &gtk::Application,
    cfg: Config,
    cmd_tx: async_channel::Sender<Cmd>,
    evt_rx: async_channel::Receiver<Evt>,
) {
    let window = gtk::ApplicationWindow::builder()
        .application(app)
        .resizable(false)
        .default_width(cfg.width)
        .build();
    window.add_css_class("blurs");

    window.init_layer_shell();
    window.set_layer(Layer::Overlay);
    if cfg.anchor != Anchor::Cursor || !place_at_cursor(&window, cfg) {
        for edge in cfg.anchor.edges() {
            window.set_anchor(*edge, true);
            window.set_margin(*edge, cfg.margin);
        }
    }
    // OnDemand, never Exclusive: Exclusive grabs the keyboard compositor-wide,
    // which makes every other window unusable while the applet is open. The
    // had_focus guard below is what keeps it from closing on an unfocused map.
    window.set_keyboard_mode(KeyboardMode::OnDemand);
    window.set_namespace(Some("blurs"));

    let card = gtk::Box::new(Orientation::Vertical, 0);
    card.add_css_class("card");
    card.set_width_request(cfg.width);

    let header = gtk::Box::new(Orientation::Horizontal, 8);
    let title_box = gtk::Box::new(Orientation::Vertical, 0);
    let title = gtk::Label::new(Some("Bluetooth"));
    title.add_css_class("header");
    title.set_halign(Align::Start);
    let subtitle = gtk::Label::new(Some(""));
    subtitle.add_css_class("subtle");
    subtitle.set_halign(Align::Start);
    title_box.append(&title);
    title_box.append(&subtitle);

    let spinner = gtk::Spinner::new();
    spinner.set_valign(Align::Center);

    let power = gtk::Switch::new();
    power.set_valign(Align::Center);
    power.set_tooltip_text(Some("Power adapter on/off"));

    header.append(&title_box);
    header.append(&gtk::Box::builder().hexpand(true).build());
    header.append(&spinner);
    header.append(&power);
    card.append(&header);

    let controls = gtk::Box::new(Orientation::Horizontal, 6);
    controls.set_margin_top(10);
    let scan = gtk::ToggleButton::with_label("Scan");
    scan.add_css_class("pill");
    scan.set_tooltip_text(Some("Discover nearby devices"));
    controls.append(&scan);
    card.append(&controls);

    card.append(&gtk::Separator::new(Orientation::Horizontal));

    let list = gtk::ListBox::new();
    list.add_css_class("devices");
    list.set_selection_mode(gtk::SelectionMode::None);

    let placeholder = gtk::Label::new(Some("No devices yet — hit Scan"));
    placeholder.add_css_class("placeholder");
    list.set_placeholder(Some(&placeholder));

    let scroller = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vscrollbar_policy(gtk::PolicyType::Automatic)
        .propagate_natural_height(true)
        .max_content_height(cfg.max_height)
        .child(&list)
        .build();
    card.append(&scroller);

    let status = gtk::Label::new(Some(""));
    status.add_css_class("status");
    status.set_halign(Align::Start);
    status.set_wrap(true);
    status.set_visible(false);
    card.append(&status);

    window.set_child(Some(&card));

    let ui = Rc::new(Ui {
        list,
        power: power.clone(),
        scan: scan.clone(),
        spinner,
        status,
        subtitle,
        syncing: RefCell::new(false),
        busy: RefCell::new(Vec::new()),
    });

    {
        let tx = cmd_tx.clone();
        let ui = ui.clone();
        power.connect_state_set(move |_, on| {
            if !*ui.syncing.borrow() {
                let _ = tx.try_send(Cmd::SetPowered(on));
            }
            glib::Propagation::Proceed
        });
    }
    {
        let tx = cmd_tx.clone();
        let ui = ui.clone();
        scan.connect_toggled(move |b| {
            if !*ui.syncing.borrow() {
                let _ = tx.try_send(Cmd::SetDiscovery(b.is_active()));
            }
        });
    }

    let key = gtk::EventControllerKey::new();
    {
        let window = window.clone();
        key.connect_key_pressed(move |_, k, _, _| {
            if k == gdk::Key::Escape {
                window.close();
                return glib::Propagation::Stop;
            }
            glib::Propagation::Proceed
        });
    }
    window.add_controller(key);

    {
        // Dismiss on pointer leave, not on focus loss. Under focus-follows-mouse
        // (input.follow_mouse) the panel loses keyboard focus the instant the
        // cursor crosses the gap between the bar and the panel, so a focus-based
        // rule closes it before it can ever be reached.
        //
        // Closing is deferred so that leaving and re-entering — or a jitter at
        // the border — cancels it rather than killing the panel.
        let inside = Rc::new(std::cell::Cell::new(false));
        let entered = Rc::new(std::cell::Cell::new(false));

        let motion = gtk::EventControllerMotion::new();
        {
            let inside = inside.clone();
            let entered = entered.clone();
            motion.connect_enter(move |_, _, _| {
                inside.set(true);
                entered.set(true);
            });
        }
        {
            let inside = inside.clone();
            let entered = entered.clone();
            let window = window.clone();
            motion.connect_leave(move |_| {
                inside.set(false);
                if !entered.get() {
                    return;
                }
                let inside = inside.clone();
                let window = window.clone();
                glib::timeout_add_local_once(std::time::Duration::from_millis(400), move || {
                    if !inside.get() {
                        window.close();
                    }
                });
            });
        }
        window.add_controller(motion);
    }

    {
        let tx = cmd_tx.clone();
        window.connect_close_request(move |_| {
            // Leaving discovery running drains the adapter and keeps waybar's
            // icon animating after the applet is gone.
            let _ = tx.try_send(Cmd::SetDiscovery(false));
            glib::Propagation::Proceed
        });
    }

    {
        let ui = ui.clone();
        let cmd_tx = cmd_tx.clone();
        glib::spawn_future_local(async move {
            while let Ok(evt) = evt_rx.recv().await {
                match evt {
                    Evt::State(st) => {
                        ui.busy.borrow_mut().clear();
                        apply_state(&ui, &st, &cmd_tx);
                    }
                    Evt::Error(path, msg) => {
                        if let Some(p) = path {
                            ui.busy.borrow_mut().retain(|b| b != &p);
                        }
                        ui.status.set_text(&msg);
                        ui.status.add_css_class("error");
                        ui.status.set_visible(true);
                    }
                }
            }
        });
    }

    window.present();
}

fn set_status(ui: &Ui, text: &str) {
    ui.status.remove_css_class("error");
    ui.status.set_text(text);
    ui.status.set_visible(!text.is_empty());
}

fn apply_state(ui: &Rc<Ui>, st: &State, cmd_tx: &async_channel::Sender<Cmd>) {
    *ui.syncing.borrow_mut() = true;

    if st.present {
        ui.power.set_sensitive(true);
        ui.power.set_active(st.powered);
        ui.power.set_state(st.powered);
        ui.scan.set_sensitive(st.powered);
        ui.scan.set_active(st.discovering);

        let n = st.devices.iter().filter(|d| d.connected).count();
        ui.subtitle.set_text(&if !st.powered {
            "adapter off".to_string()
        } else if n == 0 {
            st.adapter_name.clone()
        } else if n == 1 {
            "1 connected".to_string()
        } else {
            format!("{n} connected")
        });
    } else {
        ui.subtitle.set_text("no adapter found");
        ui.power.set_sensitive(false);
        ui.scan.set_sensitive(false);
    }

    if st.discovering {
        ui.spinner.start();
    } else {
        ui.spinner.stop();
    }

    while let Some(child) = ui.list.first_child() {
        ui.list.remove(&child);
    }
    for d in &st.devices {
        ui.list.append(&device_row(ui, d, cmd_tx));
    }

    *ui.syncing.borrow_mut() = false;
}

fn device_row(ui: &Rc<Ui>, d: &Device, cmd_tx: &async_channel::Sender<Cmd>) -> gtk::ListBoxRow {
    let row = gtk::ListBoxRow::new();
    row.add_css_class("device");
    if d.connected {
        row.add_css_class("connected");
    }

    let hbox = gtk::Box::new(Orientation::Horizontal, 10);

    let img = gtk::Image::from_icon_name(icon_name(&d.icon));
    img.add_css_class("devicon");
    hbox.append(&img);

    let vbox = gtk::Box::new(Orientation::Vertical, 0);
    let name = gtk::Label::new(Some(&d.alias));
    name.add_css_class("name");
    name.set_halign(Align::Start);
    name.set_ellipsize(gtk::pango::EllipsizeMode::End);
    name.set_max_width_chars(22);
    let meta = gtk::Label::new(Some(&meta_text(d)));
    meta.add_css_class("meta");
    meta.set_halign(Align::Start);
    vbox.append(&name);
    vbox.append(&meta);
    hbox.append(&vbox);

    hbox.append(&gtk::Box::builder().hexpand(true).build());

    let busy = ui.busy.borrow().iter().any(|p| p == &d.path);

    let primary = gtk::Button::with_label(if d.connected {
        "Disconnect"
    } else if d.paired {
        "Connect"
    } else {
        "Pair"
    });
    primary.add_css_class("flat");
    primary.set_valign(Align::Center);
    primary.set_sensitive(!busy);
    {
        let tx = cmd_tx.clone();
        let ui = ui.clone();
        let path = d.path.clone();
        let (connected, paired) = (d.connected, d.paired);
        primary.connect_clicked(move |b| {
            b.set_sensitive(false);
            ui.busy.borrow_mut().push(path.clone());
            set_status(
                &ui,
                if connected {
                    "Disconnecting…"
                } else if paired {
                    "Connecting…"
                } else {
                    "Pairing…"
                },
            );
            let cmd = if connected {
                Cmd::Disconnect(path.clone())
            } else if paired {
                Cmd::Connect(path.clone())
            } else {
                Cmd::Pair(path.clone())
            };
            let _ = tx.try_send(cmd);
        });
    }
    hbox.append(&primary);

    if d.paired {
        let trust = gtk::Button::with_label(if d.trusted { "Untrust" } else { "Trust" });
        trust.add_css_class("flat");
        trust.set_valign(Align::Center);
        trust.set_sensitive(!busy);
        {
            let tx = cmd_tx.clone();
            let path = d.path.clone();
            let trusted = d.trusted;
            trust.connect_clicked(move |b| {
                b.set_sensitive(false);
                let _ = tx.try_send(Cmd::SetTrusted(path.clone(), !trusted));
            });
        }
        hbox.append(&trust);

        let forget = gtk::Button::from_icon_name("user-trash-symbolic");
        forget.add_css_class("flat");
        forget.add_css_class("danger");
        forget.set_valign(Align::Center);
        forget.set_tooltip_text(Some("Forget this device"));
        forget.set_sensitive(!busy);
        {
            let tx = cmd_tx.clone();
            let ui = ui.clone();
            let path = d.path.clone();
            forget.connect_clicked(move |b| {
                b.set_sensitive(false);
                set_status(&ui, "Forgetting…");
                let _ = tx.try_send(Cmd::Forget(path.clone()));
            });
        }
        hbox.append(&forget);
    }

    row.set_child(Some(&hbox));
    row
}

pub fn load_css() {
    let provider = gtk::CssProvider::new();
    provider.load_from_string(&crate::theme::stylesheet());
    if let Some(display) = gdk::Display::default() {
        gtk::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}
