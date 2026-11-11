use dbus::{
    Path,
    arg::{PropMap, RefArg, Variant},
    blocking::{
        Connection,
        stdintf::org_freedesktop_dbus::{ObjectManager, Properties},
    },
    message::MatchRule,
};
use nixy_tools::Result;
use std::{
    collections::{BTreeMap, BTreeSet, HashMap},
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

const NM: &str = "org.freedesktop.NetworkManager";
const NM_PATH: &str = "/org/freedesktop/NetworkManager";
const ACTIVE: &str = "org.freedesktop.NetworkManager.Connection.Active";
const BLUEZ: &str = "org.bluez";
const ADAPTER: &str = "org.bluez.Adapter1";
const DEVICE: &str = "org.bluez.Device1";
const UPOWER: &str = "org.freedesktop.UPower";
const UPOWER_PATH: &str = "/org/freedesktop/UPower";
const POWER_DEVICE: &str = "org.freedesktop.UPower.Device";
const NOTIFY: &str = "org.freedesktop.Notifications";

#[derive(Clone, Debug, PartialEq)]
struct State {
    enabled: bool,
    title: String,
    body: String,
    icon: String,
    on: String,
    off: String,
    key: String,
}
impl State {
    fn new(enabled: bool, title: &str, body: &str, icon: &str, key: &str) -> Self {
        Self {
            enabled,
            title: title.into(),
            body: body.into(),
            icon: icon.into(),
            on: "connected".into(),
            off: "disconnected".into(),
            key: key.into(),
        }
    }
    fn radio(mut self) -> Self {
        self.on = "enabled".into();
        self.off = "disabled".into();
        self
    }
}
type Snapshot = BTreeMap<String, State>;
fn changes(previous: Option<&Snapshot>, current: &Snapshot) -> Vec<(String, State)> {
    let Some(previous) = previous else {
        return vec![];
    };
    let keys: BTreeSet<_> = previous.keys().chain(current.keys()).collect();
    keys.into_iter()
        .filter_map(|key| {
            let old = previous.get(key);
            let new = current.get(key);
            let before = old.is_some_and(|s| s.enabled);
            let after = new.is_some_and(|s| s.enabled);
            if before == after {
                return None;
            }
            let state = new.or(old).unwrap();
            if state.on == "enabled"
                && previous
                    .values()
                    .chain(current.values())
                    .any(|s| s.enabled && s.on == "connected" && s.icon == state.icon)
            {
                return None;
            }
            Some((
                format!(
                    "{} {}",
                    state.title,
                    if after { &state.on } else { &state.off }
                ),
                state.clone(),
            ))
        })
        .collect()
}
fn properties(
    bus: &Connection,
    name: &str,
    path: &str,
    interface: &str,
) -> std::result::Result<PropMap, dbus::Error> {
    bus.with_proxy(name, path, Duration::from_secs(5))
        .get_all(interface)
}
fn text<'a>(props: &'a PropMap, key: &str) -> &'a str {
    props.get(key).and_then(|v| v.0.as_str()).unwrap_or("")
}
fn number(props: &PropMap, key: &str) -> u64 {
    props.get(key).and_then(|v| v.0.as_u64()).unwrap_or(0)
}
fn network_state(bus: &Connection) -> Result<Snapshot> {
    let manager = properties(bus, NM, NM_PATH, NM)?;
    let mut states = Snapshot::from([(
        "wifi-radio".into(),
        State::new(
            number(&manager, "WirelessEnabled") != 0
                && number(&manager, "WirelessHardwareEnabled") != 0,
            "Wi-Fi",
            "Wireless radio",
            "network-wireless",
            "wifi",
        )
        .radio(),
    )]);
    let paths = manager
        .get("ActiveConnections")
        .and_then(|v| v.0.as_iter())
        .ok_or("NetworkManager omitted ActiveConnections")?;
    for path in paths {
        let path = path.as_str().ok_or("invalid active connection path")?;
        let connection = match properties(bus, NM, path, ACTIVE) {
            Ok(value) => value,
            Err(error)
                if matches!(
                    error.name(),
                    Some(
                        "org.freedesktop.DBus.Error.UnknownObject"
                            | "org.freedesktop.DBus.Error.UnknownMethod"
                    )
                ) =>
            {
                continue;
            }
            Err(error) => return Err(error.into()),
        };
        let (title, icon) = match text(&connection, "Type") {
            "802-11-wireless" => ("Wi-Fi", "network-wireless"),
            "802-3-ethernet" => ("Ethernet", "network-wired"),
            "vpn" | "wireguard" => ("VPN", "network-vpn"),
            "gsm" | "cdma" => ("Mobile network", "network-cellular"),
            _ => continue,
        };
        if number(&connection, "State") != 2 {
            continue;
        }
        let uuid = text(&connection, "Uuid");
        let identity = if uuid.is_empty() { path } else { uuid };
        states.insert(
            identity.into(),
            State::new(
                true,
                title,
                text(&connection, "Id"),
                icon,
                if title == "Wi-Fi" { "wifi" } else { identity },
            ),
        );
    }
    Ok(states)
}
fn bluetooth_state(bus: &Connection) -> Result<Snapshot> {
    let objects = bus
        .with_proxy(BLUEZ, "/", Duration::from_secs(5))
        .get_managed_objects()?;
    let mut states = Snapshot::new();
    for (path, interfaces) in objects {
        if let Some(adapter) = interfaces.get(ADAPTER) {
            let alias = text(adapter, "Alias");
            states.insert(
                path.to_string(),
                State::new(
                    number(adapter, "Powered") != 0,
                    "Bluetooth",
                    if alias.is_empty() {
                        "Bluetooth adapter"
                    } else {
                        alias
                    },
                    "bluetooth",
                    &path,
                )
                .radio(),
            );
        }
        if let Some(device) = interfaces
            .get(DEVICE)
            .filter(|p| number(p, "Connected") != 0)
        {
            let alias = text(device, "Alias");
            let address = text(device, "Address");
            states.insert(
                path.to_string(),
                State::new(
                    true,
                    "Bluetooth device",
                    if !alias.is_empty() {
                        alias
                    } else if !address.is_empty() {
                        address
                    } else {
                        "Bluetooth device"
                    },
                    "bluetooth",
                    &path,
                ),
            );
        }
    }
    Ok(states)
}
fn power_state(bus: &Connection) -> Result<Snapshot> {
    let (paths,): (Vec<Path<'static>>,) = bus
        .with_proxy(UPOWER, UPOWER_PATH, Duration::from_secs(5))
        .method_call(UPOWER, "EnumerateDevices", ())?;
    let mut online = false;
    for path in paths
        .iter()
        .filter(|p| p.starts_with(&format!("{UPOWER_PATH}/devices/line_power_")))
    {
        online |= number(&properties(bus, UPOWER, path, POWER_DEVICE)?, "Online") != 0;
    }
    Ok(power_snapshot(online))
}
fn power_snapshot(online: bool) -> Snapshot {
    let mut state = State::new(
        online,
        "Charger",
        if online {
            "External power connected"
        } else {
            "Running on battery"
        },
        "ac-adapter",
        "charger",
    );
    state.on = "plugged in".into();
    state.off = "unplugged".into();
    Snapshot::from([("charger".into(), state)])
}
fn relevant(interface: &str, changed: impl Iterator<Item = impl AsRef<str>>) -> bool {
    let keys: &[&str] = match interface {
        NM => &[
            "ActiveConnections",
            "WirelessEnabled",
            "WirelessHardwareEnabled",
        ],
        ACTIVE => &["State"],
        ADAPTER => &["Powered"],
        DEVICE => &["Connected"],
        POWER_DEVICE => &["Online"],
        _ => &[],
    };
    changed.into_iter().any(|k| keys.contains(&k.as_ref()))
}
#[derive(Default)]
struct Watcher {
    previous: Option<Snapshot>,
    pending: Option<Instant>,
}
impl Watcher {
    fn schedule(&mut self) {
        self.pending = Some(Instant::now() + Duration::from_millis(500));
    }
    fn restarted(&mut self) {
        self.previous = None;
        self.schedule();
    }
}
type Payload = (String, String, String);
#[derive(Default)]
struct Notifier {
    active: HashMap<String, (u32, Payload)>,
}
impl Notifier {
    fn closed(&mut self, id: u32) {
        self.active.retain(|_, v| v.0 != id);
    }
    fn notify(&mut self, bus: &Connection, summary: &str, state: &State) -> Result {
        let key = if state.key.is_empty() {
            format!("{}\0{}", state.title, state.body)
        } else {
            state.key.clone()
        };
        let payload = (summary.to_string(), state.body.clone(), state.icon.clone());
        let previous = self.active.get(&key);
        if previous.is_some_and(|p| p.1 == payload) {
            return Ok(());
        }
        let id = previous.map_or(0, |p| p.0);
        let body = state
            .body
            .replace('&', "&amp;")
            .replace('<', "&lt;")
            .replace('>', "&gt;")
            .replace('"', "&quot;")
            .replace('\'', "&#x27;");
        let hints: PropMap = HashMap::from([
            ("urgency".into(), Variant(Box::new(1u8) as Box<dyn RefArg>)),
            (
                "transient".into(),
                Variant(Box::new(true) as Box<dyn RefArg>),
            ),
        ]);
        let (id,): (u32,) = bus
            .with_proxy(
                NOTIFY,
                "/org/freedesktop/Notifications",
                Duration::from_secs(5),
            )
            .method_call(
                NOTIFY,
                "Notify",
                (
                    "System",
                    id,
                    state.icon.as_str(),
                    summary,
                    body,
                    Vec::<String>::new(),
                    hints,
                    5000i32,
                ),
            )?;
        self.active.insert(key, (id, payload));
        Ok(())
    }
}
fn run() -> Result {
    let system = Connection::new_system()?;
    let session = Connection::new_session()?;
    let session_events = Connection::new_session()?;
    system.set_signal_match_mode(true);
    let watchers: Arc<Mutex<[Watcher; 3]>> =
        Arc::new(Mutex::new(std::array::from_fn(|_| Watcher {
            previous: None,
            pending: Some(Instant::now()),
        })));
    let notifier = Arc::new(Mutex::new(Notifier::default()));
    for (index, name) in [NM, BLUEZ, UPOWER].iter().enumerate() {
        let state = watchers.clone();
        let mut rule =
            MatchRule::new_signal("org.freedesktop.DBus.Properties", "PropertiesChanged");
        rule.sender = Some((*name).into());
        system.add_match(
            rule,
            move |(interface, changed, invalidated): (String, PropMap, Vec<String>), _, _| {
                let source = match interface.as_str() {
                    NM | ACTIVE => Some(0),
                    ADAPTER | DEVICE => Some(1),
                    POWER_DEVICE => Some(2),
                    _ => None,
                };
                if source == Some(index)
                    && relevant(&interface, changed.keys().chain(invalidated.iter()))
                {
                    state.lock().unwrap()[index].schedule();
                }
                true
            },
        )?;
        if *name != NM {
            let (interface, signals) = if *name == BLUEZ {
                (
                    "org.freedesktop.DBus.ObjectManager",
                    ["InterfacesAdded", "InterfacesRemoved"],
                )
            } else {
                (UPOWER, ["DeviceAdded", "DeviceRemoved"])
            };
            for signal in signals {
                let state = watchers.clone();
                let mut rule = MatchRule::new_signal(interface, signal);
                rule.sender = Some((*name).into());
                use dbus::channel::MatchingReceiver;
                system.add_match_no_cb(&rule.match_str())?;
                system.start_receive(
                    rule,
                    Box::new(move |_, _| {
                        state.lock().unwrap()[index].schedule();
                        true
                    }),
                );
            }
        }
    }
    let state = watchers.clone();
    system.add_match(
        MatchRule::new_signal("org.freedesktop.DBus", "NameOwnerChanged"),
        move |(name, _, _): (String, String, String), _, _| {
            if let Some(index) = [NM, BLUEZ, UPOWER].iter().position(|n| *n == name) {
                state.lock().unwrap()[index].restarted();
            }
            true
        },
    )?;
    let state = notifier.clone();
    let mut rule = MatchRule::new_signal(NOTIFY, "NotificationClosed");
    rule.sender = Some(NOTIFY.into());
    session_events.add_match(rule, move |(id, _): (u32, u32), _, _| {
        state.lock().unwrap().closed(id);
        true
    })?;
    let state = notifier.clone();
    session_events.add_match(
        MatchRule::new_signal("org.freedesktop.DBus", "NameOwnerChanged"),
        move |(name, _, _): (String, String, String), _, _| {
            if name == NOTIFY {
                state.lock().unwrap().active.clear();
            }
            true
        },
    )?;
    // A dedicated connection blocks on session signals without delaying
    // notification method replies or waking to check a quiet system bus.
    std::thread::spawn(move || {
        loop {
            if let Err(error) = session_events.process(Duration::from_secs(86400)) {
                eprintln!("Notification bus disconnected: {error}");
                std::process::exit(1);
            }
        }
    });
    loop {
        // Drain messages queued by synchronous snapshots before sleeping.
        while system.process(Duration::ZERO)? {}
        let timeout = watchers
            .lock()
            .unwrap()
            .iter()
            .filter_map(|watcher| watcher.pending)
            .min()
            .map(|deadline| deadline.saturating_duration_since(Instant::now()))
            .unwrap_or(Duration::from_secs(86400));
        system.process(timeout)?;
        for (index, name) in [NM, BLUEZ, UPOWER].iter().enumerate() {
            if watchers.lock().unwrap()[index]
                .pending
                .is_none_or(|time| time > Instant::now())
            {
                continue;
            }
            let (owner,): (bool,) = system
                .with_proxy(
                    "org.freedesktop.DBus",
                    "/org/freedesktop/DBus",
                    Duration::from_secs(5),
                )
                .method_call("org.freedesktop.DBus", "NameHasOwner", (*name,))?;
            if !owner {
                let mut states = watchers.lock().unwrap();
                states[index].previous = None;
                states[index].pending = None;
                continue;
            }
            let result = [network_state, bluetooth_state, power_state][index](&system);
            match result {
                Ok(current) => {
                    let events = {
                        let mut states = watchers.lock().unwrap();
                        let watcher = &mut states[index];
                        let events = changes(watcher.previous.as_ref(), &current);
                        watcher.previous = Some(current);
                        watcher.pending = None;
                        events
                    };
                    for (summary, state) in events {
                        if let Err(error) =
                            notifier.lock().unwrap().notify(&session, &summary, &state)
                        {
                            eprintln!("Cannot send desktop notification: {error}");
                        }
                    }
                }
                Err(error) => {
                    eprintln!("Cannot read {name}; retrying: {error}");
                    watchers.lock().unwrap()[index].pending =
                        Some(Instant::now() + Duration::from_secs(3));
                }
            }
        }
    }
}
fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args == ["--help"] {
        println!("Usage: system-notifications");
        return;
    }
    if !args.is_empty() {
        eprintln!("Usage: system-notifications");
        std::process::exit(2);
    }
    nixy_tools::main_result(run());
}

#[cfg(test)]
mod tests {
    use super::*;
    fn wifi() -> State {
        State::new(true, "Wi-Fi", "Home", "network-wireless", "wifi")
    }
    #[test]
    fn initial_and_metadata_updates_are_quiet() {
        let old = Snapshot::from([("wifi".into(), wifi())]);
        let mut new = old.clone();
        new.get_mut("wifi").unwrap().body = "New name".into();
        assert!(changes(None, &old).is_empty());
        assert!(changes(Some(&old), &old).is_empty());
        assert!(changes(Some(&old), &new).is_empty());
    }
    #[test]
    fn disconnect_reconnect_and_radio_coalescing() {
        let mut old = Snapshot::from([
            ("wifi".into(), wifi()),
            (
                "radio".into(),
                State::new(true, "Wi-Fi", "Radio", "network-wireless", "wifi").radio(),
            ),
        ]);
        let mut radio = old["radio"].clone();
        radio.enabled = false;
        let new = Snapshot::from([("radio".into(), radio)]);
        assert_eq!(
            changes(Some(&old), &new)
                .iter()
                .map(|v| v.0.as_str())
                .collect::<Vec<_>>(),
            ["Wi-Fi disconnected"]
        );
        old.remove("radio");
        assert_eq!(
            changes(Some(&Snapshot::new()), &old)[0].0,
            "Wi-Fi connected"
        );
        assert_eq!(
            changes(Some(&old), &Snapshot::new())[0].0,
            "Wi-Fi disconnected"
        );
        assert_eq!(changes(Some(&Snapshot::new()), &new).len(), 0);
    }
    #[test]
    fn charger_only_notifies_on_external_power_changes() {
        let mut previous = None;
        let mut events = Vec::new();
        for online in [false, true, true, true, true, false] {
            let current = power_snapshot(online);
            events.extend(
                changes(previous.as_ref(), &current)
                    .into_iter()
                    .map(|v| v.0),
            );
            previous = Some(current);
        }
        assert_eq!(events, ["Charger plugged in", "Charger unplugged"]);
        assert!(!relevant(POWER_DEVICE, ["State", "Percentage"].into_iter()));
        assert!(relevant(POWER_DEVICE, ["Online"].into_iter()));
        assert!(!relevant(
            "org.freedesktop.NetworkManager.AccessPoint",
            ["Strength"].into_iter()
        ));
    }
    #[test]
    fn daemon_restart_rebaselines_and_bursts_debounce() {
        let mut watcher = Watcher {
            previous: Some(Snapshot::from([("wifi".into(), wifi())])),
            pending: None,
        };
        watcher.restarted();
        assert!(
            changes(
                watcher.previous.as_ref(),
                &Snapshot::from([("wifi".into(), wifi())])
            )
            .is_empty()
        );
        let before = watcher.pending.unwrap();
        watcher.schedule();
        assert!(watcher.pending.unwrap() >= before);
    }
    #[test]
    fn popup_expiration_preserves_other_devices() {
        let mut notifier = Notifier::default();
        let payload = ("connected".into(), "Headphones".into(), "bluetooth".into());
        notifier
            .active
            .insert("/device/1".into(), (10, payload.clone()));
        notifier.active.insert("/device/2".into(), (11, payload));
        notifier.closed(10);
        assert_eq!(notifier.active.len(), 1);
        assert!(notifier.active.contains_key("/device/2"));
        notifier.active.clear();
        assert!(notifier.active.is_empty());
    }
}
