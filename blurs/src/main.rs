//! GTK owns the main thread; a single tokio thread owns the D-Bus connection.
//! They exchange Cmd/Evt over async-channel, which glib can await directly, so
//! there is no locking and nothing blocks the UI.

mod bluez;
mod config;
mod pointer;
mod theme;
mod ui;

use gtk::glib;
use gtk::prelude::*;

const APP_ID: &str = "org.blurs.ui";

fn main() -> glib::ExitCode {
    let cfg = match config::load(std::env::args().skip(1)) {
        Ok(cfg) => cfg,
        Err(msg) => {
            // --help lands here too; it is not an error worth a nonzero status.
            let help = msg.starts_with("blurs —");
            if help {
                println!("{msg}");
            } else {
                eprintln!("blurs: {msg}");
            }
            return if help {
                glib::ExitCode::SUCCESS
            } else {
                glib::ExitCode::FAILURE
            };
        }
    };

    // Stays unique so a second launch toggles the open applet shut rather than
    // stacking another; run_with_args below is what keeps GTK off our flags.
    let app = gtk::Application::builder().application_id(APP_ID).build();

    let (cmd_tx, cmd_rx) = async_channel::unbounded::<bluez::Cmd>();
    let (evt_tx, evt_rx) = async_channel::unbounded::<bluez::Evt>();

    std::thread::Builder::new()
        .name("blurs-dbus".into())
        .spawn(move || {
            let rt = match tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
            {
                Ok(rt) => rt,
                Err(e) => {
                    eprintln!("blurs: cannot start runtime: {e}");
                    return;
                }
            };
            rt.block_on(bluez::worker(cmd_rx, evt_tx));
        })
        .expect("spawn dbus thread");

    let channels = std::cell::RefCell::new(Some((cmd_tx, evt_rx)));
    app.connect_activate(move |app| {
        if let Some(w) = app.active_window() {
            w.close();
            return;
        }
        ui::load_css();
        if let Some((cmd_tx, evt_rx)) = channels.borrow().clone() {
            ui::build(app, cfg, cmd_tx, evt_rx);
        }
    });

    app.run_with_args::<&str>(&[])
}
