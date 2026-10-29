"""Send desktop notifications when NetworkManager or BlueZ state changes."""

from dataclasses import dataclass
from html import escape
import logging

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

PROPERTIES = "org.freedesktop.DBus.Properties"
OBJECTS = "org.freedesktop.DBus.ObjectManager"
NM = "org.freedesktop.NetworkManager"
NM_PATH = "/org/freedesktop/NetworkManager"
ACTIVE = NM + ".Connection.Active"
BLUEZ = "org.bluez"
ADAPTER = BLUEZ + ".Adapter1"
DEVICE = BLUEZ + ".Device1"


@dataclass(frozen=True)
class State:
    enabled: bool
    title: str
    body: str
    icon: str
    on: str = "connected"
    off: str = "disconnected"


def changes(previous, current):
    """Ignore the initial snapshot and metadata-only updates."""
    if previous is None:
        return
    for key in sorted(previous.keys() | current.keys()):
        old, new = previous.get(key), current.get(key)
        before, after = bool(old and old.enabled), bool(new and new.enabled)
        if before != after:
            state = new or old
            yield f"{state.title} {state.on if after else state.off}", state


def properties(bus, name, path, interface):
    proxy = bus.get_object(name, path, introspect=False)
    return dbus.Interface(proxy, PROPERTIES).GetAll(interface, timeout=5)


def network_state(bus):
    manager = properties(bus, NM, NM_PATH, NM)
    states = {
        "wifi-radio": State(
            bool(manager["WirelessEnabled"] and manager["WirelessHardwareEnabled"]),
            "Wi-Fi", "Wireless radio", "network-wireless", "enabled", "disabled",
        )
    }
    kinds = {
        "802-11-wireless": ("Wi-Fi", "network-wireless"),
        "802-3-ethernet": ("Ethernet", "network-wired"),
        "vpn": ("VPN", "network-vpn"),
        "wireguard": ("VPN", "network-vpn"),
        "gsm": ("Mobile network", "network-cellular"),
        "cdma": ("Mobile network", "network-cellular"),
    }
    for path in manager["ActiveConnections"]:
        try:
            connection = properties(bus, NM, path, ACTIVE)
        except dbus.DBusException as error:
            # A connection can disappear between enumerating and reading it.
            if error.get_dbus_name() == "org.freedesktop.DBus.Error.UnknownObject":
                continue
            raise
        kind = kinds.get(str(connection["Type"]))
        if kind and connection["State"] == 2:  # NM_ACTIVE_CONNECTION_STATE_ACTIVATED
            title, icon = kind
            states[str(path)] = State(True, title, str(connection["Id"]), icon)
    return states


def bluetooth_state(bus):
    proxy = bus.get_object(BLUEZ, "/", introspect=False)
    objects = dbus.Interface(proxy, OBJECTS).GetManagedObjects(timeout=5)
    states = {}
    for path, interfaces in objects.items():
        if ADAPTER in interfaces:
            adapter = interfaces[ADAPTER]
            states[str(path)] = State(
                bool(adapter["Powered"]), "Bluetooth",
                str(adapter.get("Alias", "Bluetooth adapter")),
                "bluetooth", "enabled", "disabled",
            )
        if DEVICE in interfaces:
            device = interfaces[DEVICE]
            if device.get("Connected", False):
                states[str(path)] = State(
                    True, "Bluetooth device",
                    str(device.get("Alias", device.get("Address", "Bluetooth device"))),
                    "bluetooth",
                )
    return states


class Watcher:
    def __init__(self, bus, name, read, notify):
        self.bus, self.name, self.read, self.notify = bus, name, read, notify
        self.previous = None
        self.pending = None
        bus.add_signal_receiver(
            self.owner_changed, signal_name="NameOwnerChanged",
            dbus_interface="org.freedesktop.DBus", arg0=name,
        )
        bus.add_signal_receiver(
            self.properties_changed, signal_name="PropertiesChanged",
            dbus_interface=PROPERTIES, bus_name=name,
        )
        if name == BLUEZ:
            for signal in ("InterfacesAdded", "InterfacesRemoved"):
                bus.add_signal_receiver(
                    self.schedule, signal_name=signal,
                    dbus_interface=OBJECTS, bus_name=name,
                )
        self.refresh()

    def properties_changed(self, interface, changed, invalidated):
        relevant = {
            NM: {"ActiveConnections", "WirelessEnabled", "WirelessHardwareEnabled"},
            ACTIVE: {"State"},
            ADAPTER: {"Powered"},
            DEVICE: {"Connected"},
        }
        if relevant.get(interface, set()) & (set(changed) | set(invalidated)):
            self.schedule()

    def owner_changed(self, name, old, new):
        # Rebaseline after a daemon restart, avoiding a burst of stale events.
        self.previous = None
        self.schedule()

    def schedule(self, *args):
        if self.pending is None:
            self.pending = GLib.timeout_add(200, self.refresh)

    def refresh(self):
        self.pending = None
        try:
            if not self.bus.name_has_owner(self.name):
                self.previous = None
                return False
            current = self.read(self.bus)
        except dbus.DBusException:
            logging.exception("Cannot read %s; retrying", self.name)
            self.pending = GLib.timeout_add_seconds(3, self.refresh)
            return False
        for summary, state in changes(self.previous, current):
            self.notify(summary, state)
        self.previous = current
        return False


def main():
    logging.basicConfig(level=logging.INFO)
    DBusGMainLoop(set_as_default=True)
    system = dbus.SystemBus()
    session = dbus.SessionBus()

    def notify(summary, state):
        try:
            proxy = session.get_object(
                "org.freedesktop.Notifications", "/org/freedesktop/Notifications",
                introspect=False,
            )
            # New IDs also let Suzuha show a popup for a repeated connection.
            dbus.Interface(proxy, "org.freedesktop.Notifications").Notify(
                "System", dbus.UInt32(0), state.icon, summary, escape(state.body),
                dbus.Array([], signature="s"),
                dbus.Dictionary({"urgency": dbus.Byte(1)}, signature="sv"),
                dbus.Int32(5000), timeout=5,
            )
        except dbus.DBusException:
            logging.exception("Cannot send desktop notification")

    watchers = [
        Watcher(system, NM, network_state, notify),
        Watcher(system, BLUEZ, bluetooth_state, notify),
    ]
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
