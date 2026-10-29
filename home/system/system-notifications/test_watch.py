"""Regression tests; run with the watcher's Python environment."""

import unittest
from unittest.mock import Mock, patch

import watch


class NotificationsTest(unittest.TestCase):
    def setUp(self):
        self.wifi = watch.State(True, "Wi-Fi", "Home", "network-wireless")
        self.headset = watch.State(True, "Bluetooth device", "Headphones", "bluetooth")

    def test_login_and_unchanged_state_are_quiet(self):
        snapshot = {"wifi": self.wifi, "headset": self.headset}
        self.assertEqual(list(watch.changes(None, snapshot)), [])
        self.assertEqual(list(watch.changes(snapshot, snapshot)), [])

    def test_connect_disconnect_and_reconnect(self):
        connected = {"headset": self.headset}
        events = []
        for before, after in [({}, connected), (connected, {}), ({}, connected)]:
            events.extend(title for title, _ in watch.changes(before, after))
        self.assertEqual(events, [
            "Bluetooth device connected", "Bluetooth device disconnected",
            "Bluetooth device connected",
        ])

    def test_renaming_a_device_does_not_notify(self):
        renamed = watch.State(True, "Bluetooth device", "New name", "bluetooth")
        self.assertEqual(list(watch.changes({"bt": self.headset}, {"bt": renamed})), [])

    def test_wifi_radio_toggle(self):
        on = watch.State(True, "Wi-Fi", "Wireless radio", "network-wireless", "enabled", "disabled")
        off = watch.State(False, "Wi-Fi", "Wireless radio", "network-wireless", "enabled", "disabled")
        self.assertEqual(list(watch.changes({"radio": on}, {"radio": off}))[0][0], "Wi-Fi disabled")

    @patch.object(watch, "properties")
    def test_only_completed_real_network_connections_notify(self, properties):
        properties.side_effect = [
            {"WirelessEnabled": True, "WirelessHardwareEnabled": True,
             "ActiveConnections": ["/wifi", "/vpn", "/lo", "/connecting"]},
            {"Type": "802-11-wireless", "State": 2, "Id": "Home"},
            {"Type": "wireguard", "State": 2, "Id": "Work"},
            {"Type": "loopback", "State": 2, "Id": "lo"},
            {"Type": "802-3-ethernet", "State": 1, "Id": "Wired"},
        ]
        states = watch.network_state(Mock())
        self.assertEqual(set(states), {"wifi-radio", "/wifi", "/vpn"})
        self.assertEqual(states["/vpn"].title, "VPN")

    @patch.object(watch.dbus, "Interface")
    def test_bluetooth_discovery_does_not_create_connection_events(self, interface):
        interface.return_value.GetManagedObjects.return_value = {
            "/adapter": {watch.ADAPTER: {"Powered": True, "Alias": "Laptop"}},
            "/headset": {watch.DEVICE: {"Connected": True, "Alias": "Headphones"}},
            "/nearby": {watch.DEVICE: {"Connected": False, "Alias": "Nearby phone"}},
        }
        states = watch.bluetooth_state(Mock())
        self.assertEqual(set(states), {"/adapter", "/headset"})

    @patch.object(watch.GLib, "timeout_add", return_value=1)
    def test_daemon_restart_rebaselines_without_replaying_connections(self, timer):
        bus, notify = Mock(), Mock()
        reader = Mock(return_value={"wifi": self.wifi})
        watcher = watch.Watcher(bus, watch.NM, reader, notify)
        watcher.owner_changed(watch.NM, "old-owner", "new-owner")
        watcher.refresh()
        notify.assert_not_called()
        reader.return_value = {}
        watcher.refresh()
        notify.assert_called_once_with("Wi-Fi disconnected", self.wifi)

    @patch.object(watch.GLib, "timeout_add", return_value=1)
    def test_signal_strength_updates_are_ignored_and_events_are_coalesced(self, timer):
        watcher = watch.Watcher(Mock(), watch.NM, Mock(return_value={}), Mock())
        watcher.properties_changed(watch.NM + ".AccessPoint", {"Strength": 90}, [])
        timer.assert_not_called()
        watcher.properties_changed(watch.ACTIVE, {"State": 2}, [])
        watcher.properties_changed(watch.NM, {"ActiveConnections": []}, [])
        timer.assert_called_once()


if __name__ == "__main__":
    unittest.main()
