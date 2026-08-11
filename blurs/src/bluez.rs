use std::collections::HashMap;

use futures_util::StreamExt;
use zbus::zvariant::OwnedValue;
use zbus::{Connection, proxy};

const BLUEZ: &str = "org.bluez";
const ADAPTER_IFACE: &str = "org.bluez.Adapter1";
const DEVICE_IFACE: &str = "org.bluez.Device1";

#[proxy(interface = "org.bluez.Adapter1", default_service = "org.bluez")]
trait Adapter1 {
    fn start_discovery(&self) -> zbus::Result<()>;
    fn stop_discovery(&self) -> zbus::Result<()>;
    fn remove_device(&self, device: &zbus::zvariant::ObjectPath<'_>) -> zbus::Result<()>;

    #[zbus(property)]
    fn set_powered(&self, value: bool) -> zbus::Result<()>;
}

#[proxy(interface = "org.bluez.Device1", default_service = "org.bluez")]
trait Device1 {
    fn connect(&self) -> zbus::Result<()>;
    fn disconnect(&self) -> zbus::Result<()>;
    fn pair(&self) -> zbus::Result<()>;

    #[zbus(property)]
    fn set_trusted(&self, value: bool) -> zbus::Result<()>;
}

#[derive(Clone, Debug, PartialEq)]
pub struct Device {
    pub path: String,
    pub address: String,
    pub alias: String,
    pub icon: String,
    pub paired: bool,
    pub connected: bool,
    pub trusted: bool,
    pub rssi: Option<i16>,
}

impl Device {
    fn rank(&self) -> (u8, i32) {
        let tier = if self.connected {
            0
        } else if self.paired {
            1
        } else {
            2
        };
        (tier, -i32::from(self.rssi.unwrap_or(-127)))
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct State {
    pub present: bool,
    pub powered: bool,
    pub discovering: bool,
    pub adapter_name: String,
    pub devices: Vec<Device>,
}

#[derive(Debug)]
pub enum Cmd {
    SetPowered(bool),
    SetDiscovery(bool),
    Connect(String),
    Disconnect(String),
    Pair(String),
    SetTrusted(String, bool),
    Forget(String),
}

#[derive(Debug)]
pub enum Evt {
    State(Box<State>),
    Error(Option<String>, String),
}

fn as_string(props: &HashMap<String, OwnedValue>, key: &str) -> Option<String> {
    props
        .get(key)
        .and_then(|v| String::try_from(v.clone()).ok())
}

fn as_bool(props: &HashMap<String, OwnedValue>, key: &str) -> bool {
    props
        .get(key)
        .and_then(|v| bool::try_from(v.clone()).ok())
        .unwrap_or(false)
}

async fn object_manager(conn: &Connection) -> zbus::Result<zbus::fdo::ObjectManagerProxy<'_>> {
    zbus::fdo::ObjectManagerProxy::builder(conn)
        .destination(BLUEZ)?
        .path("/")?
        .build()
        .await
}

async fn snapshot(conn: &Connection) -> zbus::Result<State> {
    let objects = object_manager(conn).await?.get_managed_objects().await?;
    let mut state = State::default();
    let mut adapter: Option<String> = None;

    for (path, ifaces) in &objects {
        let Some(props) = ifaces.get(ADAPTER_IFACE) else {
            continue;
        };
        if adapter.as_deref().is_none_or(|p| path.as_str() < p) {
            adapter = Some(path.to_string());
            state.present = true;
            state.powered = as_bool(props, "Powered");
            state.discovering = as_bool(props, "Discovering");
            state.adapter_name = as_string(props, "Alias")
                .or_else(|| as_string(props, "Name"))
                .unwrap_or_else(|| "Bluetooth".into());
        }
    }

    for (path, ifaces) in &objects {
        let Some(props) = ifaces.get(DEVICE_IFACE) else {
            continue;
        };
        let address = as_string(props, "Address").unwrap_or_default();
        let alias = as_string(props, "Alias")
            .or_else(|| as_string(props, "Name"))
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| address.clone());

        state.devices.push(Device {
            path: path.to_string(),
            address,
            alias,
            icon: as_string(props, "Icon").unwrap_or_default(),
            paired: as_bool(props, "Paired"),
            connected: as_bool(props, "Connected"),
            trusted: as_bool(props, "Trusted"),
            rssi: props
                .get("RSSI")
                .and_then(|v| i16::try_from(v.clone()).ok()),
        });
    }

    state.devices.sort_by(|a, b| {
        a.rank()
            .cmp(&b.rank())
            .then_with(|| a.alias.to_lowercase().cmp(&b.alias.to_lowercase()))
    });

    Ok(state)
}

async fn adapter_path(conn: &Connection) -> zbus::Result<String> {
    let objects = object_manager(conn).await?.get_managed_objects().await?;
    objects
        .iter()
        .filter(|(_, ifaces)| ifaces.contains_key(ADAPTER_IFACE))
        .map(|(path, _)| path.to_string())
        .min()
        .ok_or_else(|| zbus::Error::Failure("no Bluetooth adapter".into()))
}

/// BlueZ errors arrive as `org.bluez.Error.Failed: <reason>`; keep the reason.
fn reason(e: &zbus::Error) -> String {
    let s = e.to_string();
    s.rsplit(": ").next().unwrap_or(&s).to_string()
}

async fn adapter(conn: &Connection) -> zbus::Result<Adapter1Proxy<'_>> {
    Adapter1Proxy::builder(conn)
        .path(adapter_path(conn).await?)?
        .build()
        .await
}

async fn run(conn: &Connection, cmd: Cmd) -> Result<(), (Option<String>, String)> {
    match cmd {
        Cmd::SetPowered(on) => {
            let a = adapter(conn).await.map_err(|e| (None, reason(&e)))?;
            a.set_powered(on)
                .await
                .map_err(|e| (None, format!("power: {}", reason(&e))))?;
        }
        Cmd::SetDiscovery(on) => {
            let a = adapter(conn).await.map_err(|e| (None, reason(&e)))?;
            if on {
                a.start_discovery()
                    .await
                    .map_err(|e| (None, format!("scan: {}", reason(&e))))?;
            } else {
                // Stopping a scan that isn't running is not worth surfacing.
                let _ = a.stop_discovery().await;
            }
        }
        Cmd::Forget(dev) => {
            let a = adapter(conn)
                .await
                .map_err(|e| (Some(dev.clone()), reason(&e)))?;
            let op = zbus::zvariant::ObjectPath::try_from(dev.as_str())
                .map_err(|e| (Some(dev.clone()), format!("bad path: {e}")))?;
            a.remove_device(&op)
                .await
                .map_err(|e| (Some(dev.clone()), format!("forget: {}", reason(&e))))?;
        }
        Cmd::Connect(_) | Cmd::Disconnect(_) | Cmd::Pair(_) | Cmd::SetTrusted(_, _) => {
            let (dev, label) = match &cmd {
                Cmd::Connect(d) => (d.clone(), "connect"),
                Cmd::Disconnect(d) => (d.clone(), "disconnect"),
                Cmd::Pair(d) => (d.clone(), "pair"),
                Cmd::SetTrusted(d, _) => (d.clone(), "trust"),
                _ => unreachable!(),
            };
            let fail = |e: zbus::Error| (Some(dev.clone()), format!("{label}: {}", reason(&e)));

            let p = Device1Proxy::builder(conn)
                .path(dev.clone())
                .map_err(fail)?
                .build()
                .await
                .map_err(fail)?;

            match cmd {
                Cmd::Connect(_) => p.connect().await.map_err(fail)?,
                Cmd::Disconnect(_) => p.disconnect().await.map_err(fail)?,
                Cmd::SetTrusted(_, v) => p.set_trusted(v).await.map_err(fail)?,
                Cmd::Pair(_) => {
                    p.pair().await.map_err(fail)?;
                    // A device that is paired but not trusted won't reconnect
                    // on its own, which isn't what "Pair" implies to a user.
                    let _ = p.set_trusted(true).await;
                    let _ = p.connect().await;
                }
                _ => unreachable!(),
            }
        }
    }
    Ok(())
}

/// Owns the D-Bus connection. Re-reads all of BlueZ on every signal instead of
/// applying deltas: with a handful of devices `GetManagedObjects` is one cheap
/// round-trip, and it rules out stale-state bugs entirely.
pub async fn worker(cmd_rx: async_channel::Receiver<Cmd>, evt_tx: async_channel::Sender<Evt>) {
    let conn = match Connection::system().await {
        Ok(c) => c,
        Err(e) => {
            let _ = evt_tx
                .send(Evt::Error(None, format!("cannot reach D-Bus: {e}")))
                .await;
            return;
        }
    };

    let om = match object_manager(&conn).await {
        Ok(om) => om,
        Err(e) => {
            let _ = evt_tx
                .send(Evt::Error(None, format!("BlueZ unavailable: {e}")))
                .await;
            return;
        }
    };

    let mut added = om.receive_interfaces_added().await.ok();
    let mut removed = om.receive_interfaces_removed().await.ok();

    // ObjectManager has no signal for property changes, so match those
    // separately. Scoped to /org/bluez to avoid waking on unrelated bus traffic.
    let mut props = match zbus::MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .interface("org.freedesktop.DBus.Properties")
        .and_then(|b| b.member("PropertiesChanged"))
        .and_then(|b| b.path_namespace("/org/bluez"))
        .map(|b| b.build())
    {
        Ok(rule) => zbus::MessageStream::for_match_rule(rule, &conn, Some(32))
            .await
            .ok(),
        Err(_) => None,
    };

    if let Ok(st) = snapshot(&conn).await {
        let _ = evt_tx.send(Evt::State(Box::new(st))).await;
    }

    loop {
        tokio::select! {
            cmd = cmd_rx.recv() => {
                match cmd {
                    Ok(cmd) => {
                        if let Err((path, msg)) = run(&conn, cmd).await {
                            let _ = evt_tx.send(Evt::Error(path, msg)).await;
                        }
                    }
                    Err(_) => return,
                }
            }
            Some(_) = async { match added.as_mut() { Some(s) => s.next().await, None => None } } => {}
            Some(_) = async { match removed.as_mut() { Some(s) => s.next().await, None => None } } => {}
            Some(_) = async { match props.as_mut() { Some(s) => s.next().await, None => None } } => {}
            else => return,
        }

        match snapshot(&conn).await {
            Ok(st) => {
                let _ = evt_tx.send(Evt::State(Box::new(st))).await;
            }
            Err(e) => {
                let _ = evt_tx
                    .send(Evt::Error(None, format!("refresh failed: {e}")))
                    .await;
            }
        }
    }
}
