//! StatusNotifier watcher/host and DBusMenu transport. All I/O stays off the UI thread.
use crate::dbus::convert;
use crate::services::apps::icons;
use crate::{Argument, Service, Value};
use std::collections::{BTreeSet, HashMap};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, LazyLock, Mutex};
use std::thread;
use std::time::Duration;
use zbus::blocking::Connection;
use zbus::message::Header;

const WATCHER: &str = "org.kde.StatusNotifierWatcher";
const WATCH_PATH: &str = "/StatusNotifierWatcher";
const ITEM: &str = "org.kde.StatusNotifierItem";
const MENU: &str = "com.canonical.dbusmenu";
static CONNECTION: LazyLock<Option<Connection>> = LazyLock::new(|| {
    zbus::blocking::connection::Builder::session()
        .ok()?
        .method_timeout(Duration::from_secs(2))
        .build()
        .ok()
});
type Registry = Arc<Mutex<BTreeSet<String>>>;

struct Watcher {
    registry: Registry,
}
#[zbus::interface(name = "org.kde.StatusNotifierWatcher")]
impl Watcher {
    fn register_status_notifier_item(
        &self,
        service: &str,
        #[zbus(header)] header: Header<'_>,
    ) -> zbus::fdo::Result<()> {
        let sender = header.sender().map(|s| s.as_str()).unwrap_or("");
        let endpoint = registration(service, sender)
            .ok_or_else(|| zbus::fdo::Error::InvalidArgs("Invalid tray endpoint".into()))?;
        self.registry.lock().unwrap().insert(endpoint);
        Ok(())
    }
    fn register_status_notifier_host(&self, _service: &str) {}
    #[zbus(property)]
    fn registered_status_notifier_items(&self) -> Vec<String> {
        self.registry.lock().unwrap().iter().cloned().collect()
    }
    #[zbus(property)]
    fn is_status_notifier_host_registered(&self) -> bool {
        true
    }
    #[zbus(property)]
    fn protocol_version(&self) -> i32 {
        0
    }
    #[zbus(signal)]
    async fn status_notifier_item_registered(
        emitter: &zbus::object_server::SignalEmitter<'_>,
        service: &str,
    ) -> zbus::Result<()>;
    #[zbus(signal)]
    async fn status_notifier_item_unregistered(
        emitter: &zbus::object_server::SignalEmitter<'_>,
        service: &str,
    ) -> zbus::Result<()>;
    #[zbus(signal)]
    async fn status_notifier_host_registered(
        emitter: &zbus::object_server::SignalEmitter<'_>,
    ) -> zbus::Result<()>;
}
fn registration(service: &str, sender: &str) -> Option<String> {
    let (name, path) = if service.starts_with('/') {
        (sender, service)
    } else {
        (service, "/StatusNotifierItem")
    };
    zbus::names::BusName::try_from(name).ok()?;
    zbus::zvariant::ObjectPath::try_from(path).ok()?;
    Some(format!("{name}{path}"))
}
fn endpoint(key: &str) -> Option<(&str, &str)> {
    let slash = key.find('/')?;
    Some((&key[..slash], &key[slash..]))
}
fn call(name: &str, path: &str, interface: &str, method: &str, args: &[Argument]) -> Option<Value> {
    let connection = CONNECTION.as_ref()?;
    let reply = if args.is_empty() {
        connection
            .call_method(Some(name), path, Some(interface), method, &())
            .ok()?
    } else {
        connection
            .call_method(
                Some(name),
                path,
                Some(interface),
                method,
                &convert::body(args),
            )
            .ok()?
    };
    let mut values = convert::arguments(&reply);
    Some(if values.len() == 1 {
        values.remove(0)
    } else {
        Value::List(values)
    })
}
fn property(name: &str, path: &str, interface: &str, key: &str) -> Value {
    call(
        name,
        path,
        "org.freedesktop.DBus.Properties",
        "Get",
        &[interface.into(), key.into()],
    )
    .unwrap_or_default()
}
fn alive(name: &str) -> bool {
    call(
        "org.freedesktop.DBus",
        "/org/freedesktop/DBus",
        "org.freedesktop.DBus",
        "NameHasOwner",
        &[name.into()],
    )
    .is_some_and(|v| v.bool())
}

#[derive(Clone, Debug, PartialEq)]
pub struct Item {
    pub key: String,
    pub title: String,
    pub icon: Option<PathBuf>,
    pub attention: bool,
    pub menu: String,
    pub menu_only: bool,
}
#[derive(Default)]
pub struct Tray {
    pub items: Vec<Item>,
}
impl Service for Tray {
    fn new() -> Self {
        Self::default()
    }
    fn listen() {
        let Some(connection) = CONNECTION.as_ref() else {
            return;
        };
        let registry = Registry::default();
        if connection
            .object_server()
            .at(
                WATCH_PATH,
                Watcher {
                    registry: registry.clone(),
                },
            )
            .is_err()
        {
            return;
        }
        let host = format!("org.kde.StatusNotifierHost.amane{}", std::process::id());
        let _ = connection.request_name(host.as_str());
        let mut owns = false;
        let mut announced = BTreeSet::new();
        let folders = icons::read_icon_folders();
        let mut cache: HashMap<String, (Value, Option<PathBuf>)> = HashMap::new();
        loop {
            // If another watcher is present, use it as a host; take over only after it leaves.
            if !owns && !alive(WATCHER) {
                owns = connection
                    .request_name_with_flags(
                        WATCHER,
                        zbus::fdo::RequestNameFlags::DoNotQueue.into(),
                    )
                    .is_ok_and(|r| {
                        matches!(
                            r,
                            zbus::fdo::RequestNameReply::PrimaryOwner
                                | zbus::fdo::RequestNameReply::AlreadyOwner
                        )
                    });
                if owns {
                    let _ = connection.emit_signal(
                        None::<&str>,
                        WATCH_PATH,
                        WATCHER,
                        "StatusNotifierHostRegistered",
                        &(),
                    );
                }
            }
            let keys: BTreeSet<String> = if owns {
                // Never hold the registry lock while making a remote call.
                let previous = registry.lock().unwrap().clone();
                let gone: Vec<_> = previous
                    .iter()
                    .filter(|key| endpoint(key).is_none_or(|(name, _)| !alive(name)))
                    .cloned()
                    .collect();
                let mut current = registry.lock().unwrap();
                for key in gone {
                    current.remove(&key);
                }
                current.clone()
            } else {
                let _ = call(
                    WATCHER,
                    WATCH_PATH,
                    WATCHER,
                    "RegisterStatusNotifierHost",
                    &[host.as_str().into()],
                );
                property(
                    WATCHER,
                    WATCH_PATH,
                    WATCHER,
                    "RegisteredStatusNotifierItems",
                )
                .list()
                .iter()
                .map(|v| v.text().to_string())
                .collect()
            };
            if owns {
                for key in keys.difference(&announced) {
                    let _ = connection.emit_signal(
                        None::<&str>,
                        WATCH_PATH,
                        WATCHER,
                        "StatusNotifierItemRegistered",
                        &(key.as_str(),),
                    );
                }
                for key in announced.difference(&keys) {
                    let _ = connection.emit_signal(
                        None::<&str>,
                        WATCH_PATH,
                        WATCHER,
                        "StatusNotifierItemUnregistered",
                        &(key.as_str(),),
                    );
                }
                announced = keys.clone();
            }
            let mut items = Vec::new();
            for key in &keys {
                let Some((name, path)) = endpoint(key) else {
                    continue;
                };
                let Some(props) = call(
                    name,
                    path,
                    "org.freedesktop.DBus.Properties",
                    "GetAll",
                    &[ITEM.into()],
                ) else {
                    continue;
                };
                let attention = props.get("Status").text() == "NeedsAttention";
                let icon_data = Value::List(vec![
                    props
                        .get(if attention {
                            "AttentionIconName"
                        } else {
                            "IconName"
                        })
                        .clone(),
                    props
                        .get(if attention {
                            "AttentionIconPixmap"
                        } else {
                            "IconPixmap"
                        })
                        .clone(),
                    props.get("IconThemePath").clone(),
                    props.get("IconName").clone(),
                    props.get("IconPixmap").clone(),
                ]);
                let icon = match cache.get(key) {
                    Some((old, path)) if old == &icon_data => path.clone(),
                    _ => {
                        let path = find_icon(&icon_data, &folders);
                        cache.insert(key.clone(), (icon_data, path.clone()));
                        path
                    }
                };
                let mut title = props.get("Title").text().to_string();
                if title.is_empty() {
                    title = props.get("Id").text().to_string();
                }
                if title.is_empty() {
                    title = name.to_string();
                }
                items.push(Item {
                    key: key.clone(),
                    title,
                    icon,
                    attention,
                    menu: props.get("Menu").text().to_string(),
                    menu_only: props.get("ItemIsMenu").bool(),
                });
            }
            cache.retain(|key, _| keys.contains(key));
            let used: BTreeSet<_> = cache.values().filter_map(|(_, p)| p.as_ref()).collect();
            if let Ok(files) = fs::read_dir(icon_folder()) {
                for file in files.flatten() {
                    if !used.contains(&file.path()) {
                        remove_icon(&file.path());
                    }
                }
            }
            let mut tray = Self::write();
            if tray.items == items {
                tray.quiet();
            } else {
                tray.items = items;
            }
            drop(tray);
            thread::sleep(Duration::from_secs(1));
        }
    }
}
fn icon_folder() -> PathBuf {
    PathBuf::from(
        std::env::var_os("XDG_RUNTIME_DIR").unwrap_or_else(|| std::env::temp_dir().into()),
    )
    .join(format!("amane-tray-{}", std::process::id()))
}
fn remove_icon(path: &Path) {
    if path.parent() == Some(icon_folder().as_path()) {
        let _ = fs::remove_file(path);
    }
}
fn find_icon(data: &Value, folders: &[Vec<PathBuf>]) -> Option<PathBuf> {
    let values = data.list();
    for (name, pixmaps) in [
        (values[0].text(), &values[1]),
        (values[3].text(), &values[4]),
    ] {
        if !name.is_empty() {
            let path = PathBuf::from(name);
            if path.is_absolute() && path.is_file() {
                return Some(path);
            }
            let theme = values[2].text();
            if !theme.is_empty() {
                for ext in ["png", "svg"] {
                    let path = Path::new(theme).join(format!("{name}.{ext}"));
                    if path.is_file() {
                        return Some(path);
                    }
                }
            }
            if let Some(path) = icons::look_up_icon_file(name, folders) {
                return Some(path);
            }
        }
        if let Some((width, height, rgba)) = pixmap(pixmaps) {
            use std::hash::{Hash, Hasher};
            let mut hash = std::collections::hash_map::DefaultHasher::new();
            (width, height, &rgba).hash(&mut hash);
            let folder = icon_folder();
            fs::create_dir_all(&folder).ok()?;
            let path = folder.join(format!("{:x}.png", hash.finish()));
            let mut encoder = png::Encoder::new(fs::File::create(&path).ok()?, width, height);
            encoder.set_color(png::ColorType::Rgba);
            encoder.set_depth(png::BitDepth::Eight);
            encoder.write_header().ok()?.write_image_data(&rgba).ok()?;
            return Some(path);
        }
    }
    None
}
fn pixmap(value: &Value) -> Option<(u32, u32, Vec<u8>)> {
    value
        .list()
        .iter()
        .filter_map(|entry| {
            let [width, height, bytes] = entry.list() else {
                return None;
            };
            let (width, height) = (width.number() as u32, height.number() as u32);
            if width == 0 || height == 0 || width > 512 || height > 512 {
                return None;
            }
            if bytes.list().len() != (width * height * 4) as usize {
                return None;
            }
            let mut rgba = Vec::with_capacity(bytes.list().len());
            for pixel in bytes.list().chunks_exact(4) {
                rgba.extend([
                    pixel[1].number() as u8,
                    pixel[2].number() as u8,
                    pixel[3].number() as u8,
                    pixel[0].number() as u8,
                ]);
            }
            Some((width, height, rgba))
        })
        .min_by_key(|(w, _, _)| w.abs_diff(24))
}

pub fn activate(item: Item, secondary: bool) {
    thread::spawn(move || {
        if let Some((name, path)) = endpoint(&item.key) {
            let method = if secondary {
                "SecondaryActivate"
            } else {
                "Activate"
            };
            let _ = call(name, path, ITEM, method, &[0.into(), 0.into()]);
        }
    });
}
pub fn scroll(item: Item, delta: i32, horizontal: bool) {
    thread::spawn(move || {
        if let Some((name, path)) = endpoint(&item.key) {
            let _ = call(
                name,
                path,
                ITEM,
                "Scroll",
                &[
                    delta.into(),
                    (if horizontal { "horizontal" } else { "vertical" }).into(),
                ],
            );
        }
    });
}
#[derive(Clone, Debug, PartialEq)]
pub struct MenuEntry {
    pub id: i32,
    pub label: String,
    pub enabled: bool,
    pub separator: bool,
    pub checked: Option<bool>,
    pub submenu: bool,
}
fn label(value: &str) -> String {
    let mut result = String::new();
    let mut chars = value.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '_' {
            if chars.peek() == Some(&'_') {
                chars.next();
                result.push('_');
            }
        } else {
            result.push(c);
        }
    }
    result
}
fn entries(layout: &Value) -> Vec<MenuEntry> {
    let [_, _, children] = layout.list() else {
        return Vec::new();
    };
    children
        .list()
        .iter()
        .filter_map(|child| {
            let [id, props, children] = child.list() else {
                return None;
            };
            if props.get("visible") == &Value::Bool(false) {
                return None;
            }
            Some(MenuEntry {
                id: id.number() as i32,
                label: label(props.get("label").text()),
                enabled: props.get("enabled") != &Value::Bool(false),
                separator: props.get("type").text() == "separator",
                checked: (!props.get("toggle-type").text().is_empty())
                    .then(|| props.get("toggle-state").number() > 0.0),
                submenu: props.get("children-display").text() == "submenu"
                    || !children.list().is_empty(),
            })
        })
        .collect()
}
// Called from a worker by the shell, never while rendering.
pub fn menu(item: &Item, parent: i32) -> Option<Vec<MenuEntry>> {
    let (name, path) = endpoint(&item.key)?;
    if item.menu.is_empty() || item.menu == "/" {
        let _ = call(name, path, ITEM, "ContextMenu", &[0.into(), 0.into()]);
        return None;
    }
    let _ = call(name, &item.menu, MENU, "AboutToShow", &[parent.into()]);
    let layout = call(
        name,
        &item.menu,
        MENU,
        "GetLayout",
        &[parent.into(), 1.into(), Argument::TextList(Vec::new())],
    )?;
    let [_, root] = layout.list() else {
        return None;
    };
    Some(entries(root))
}
pub fn invoke(item: Item, id: i32) {
    thread::spawn(move || {
        if let Some((name, _)) = endpoint(&item.key) {
            let _ = call(
                name,
                &item.menu,
                MENU,
                "Event",
                &[
                    id.into(),
                    "clicked".into(),
                    Argument::Variant(Box::new(0.into())),
                    Argument::Unsigned(0),
                ],
            );
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn watcher_dbus_contract_and_duplicate_registration() {
        let registry = Registry::default();
        let server = zbus::blocking::connection::Builder::session()
            .unwrap()
            .serve_at(
                WATCH_PATH,
                Watcher {
                    registry: registry.clone(),
                },
            )
            .unwrap()
            .name(WATCHER)
            .unwrap()
            .build()
            .unwrap();
        let client = Connection::session().unwrap();
        let proxy = zbus::blocking::Proxy::new(&client, WATCHER, WATCH_PATH, WATCHER).unwrap();
        let _: () = proxy
            .call("RegisterStatusNotifierItem", &("/TestItem",))
            .unwrap();
        let _: () = proxy
            .call("RegisterStatusNotifierItem", &("/TestItem",))
            .unwrap();
        let items: Vec<String> = proxy.get_property("RegisteredStatusNotifierItems").unwrap();
        assert_eq!(
            items,
            vec![format!("{}/TestItem", client.unique_name().unwrap())]
        );
        assert!(
            proxy
                .get_property::<bool>("IsStatusNotifierHostRegistered")
                .unwrap()
        );
        assert_eq!(proxy.get_property::<i32>("ProtocolVersion").unwrap(), 0);
        assert!(
            proxy
                .call::<_, _, ()>("RegisterStatusNotifierItem", &("/bad path",))
                .is_err()
        );
        let _: () = proxy
            .call("RegisterStatusNotifierHost", &("org.test.Host",))
            .unwrap();
        drop(server);
    }
    #[test]
    fn registration_accepts_names_and_sender_paths() {
        assert_eq!(
            registration("/org/test/Item", ":1.7").as_deref(),
            Some(":1.7/org/test/Item")
        );
        assert_eq!(
            registration("org.test.App", ":1.7").as_deref(),
            Some("org.test.App/StatusNotifierItem")
        );
        assert!(registration("/bad path", ":1.7").is_none());
        assert!(registration("/Item", "").is_none());
        assert!(registration("invalid", ":1.7").is_none());
    }
    #[test]
    fn network_argb_becomes_rgba_and_bad_dimensions_are_rejected() {
        let n = |n| Value::Number(n as f64);
        let sample = |w, h, bytes: Vec<Value>| {
            Value::List(vec![Value::List(vec![n(w), n(h), Value::List(bytes)])])
        };
        assert_eq!(
            pixmap(&sample(1, 1, vec![n(128), n(1), n(2), n(3)])),
            Some((1, 1, vec![1, 2, 3, 128]))
        );
        assert!(pixmap(&sample(513, 1, vec![])).is_none());
        assert!(pixmap(&sample(1, 1, vec![n(0)])).is_none());
    }
    #[test]
    fn menu_preserves_visibility_disabled_checks_and_submenus() {
        let props = |pairs: Vec<(&str, Value)>| {
            Value::Map(pairs.into_iter().map(|(k, v)| (k.to_string(), v)).collect())
        };
        let node = |id, p| Value::List(vec![Value::Number(id as f64), p, Value::List(vec![])]);
        let root = Value::List(vec![
            Value::Number(0.0),
            Value::Nothing,
            Value::List(vec![
                node(1, props(vec![("visible", Value::Bool(false))])),
                node(
                    2,
                    props(vec![
                        ("label", Value::Text("_Show __app".into())),
                        ("enabled", Value::Bool(false)),
                        ("toggle-type", Value::Text("checkmark".into())),
                        ("toggle-state", Value::Number(1.0)),
                        ("children-display", Value::Text("submenu".into())),
                    ]),
                ),
                node(3, props(vec![("type", Value::Text("separator".into()))])),
            ]),
        ]);
        let rows = entries(&root);
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].label, "Show _app");
        assert!(!rows[0].enabled);
        assert_eq!(rows[0].checked, Some(true));
        assert!(rows[0].submenu);
        assert!(rows[1].separator);
    }
}
