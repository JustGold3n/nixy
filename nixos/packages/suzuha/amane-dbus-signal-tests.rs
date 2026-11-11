use std::sync::mpsc;
use std::thread;
use std::time::Duration;

use super::*;

#[test]
fn property_bursts_do_not_block_shared_bus_calls() {
    // Run under dbus-run-session. Keep the refresh consumer idle to model a
    // service taking a snapshot while wake-up signals arrive in a burst.
    let bus = Bus::session();
    let changes = bus.property_changes("/org/nixy/Watched");
    let emitter = zbus::blocking::Connection::session().unwrap();
    for _ in 0..256 {
        emitter
            .emit_signal(
                None::<&str>,
                "/org/nixy/Watched",
                "org.freedesktop.DBus.Properties",
                "PropertiesChanged",
                &(),
            )
            .unwrap();
    }
    // Round-trip on the sender after all its signals have reached the bus.
    emitter
        .call_method(
            Some("org.freedesktop.DBus"),
            "/org/freedesktop/DBus",
            Some("org.freedesktop.DBus"),
            "GetId",
            &(),
        )
        .unwrap();

    let (sent, reply) = mpsc::channel();
    thread::spawn(move || {
        let owned = bus.call(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "NameHasOwner",
            &["org.freedesktop.DBus".into()],
        );
        let _ = sent.send(owned.bool());
    });
    assert_eq!(reply.recv_timeout(Duration::from_secs(3)), Ok(true));
    assert_eq!(changes.recv_timeout(Duration::from_secs(3)), Ok(()));
}
