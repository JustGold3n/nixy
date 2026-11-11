use amane::{
    Arc, Battery, Bluetooth, Canvas, Cap, Circle, Color, Link, Network, Notifications, Path,
    Service, Shape,
};

use crate::theme::Theme;

// A larger status ring makes the Bluetooth symbol and connection dots legible.
pub const SIZE: f32 = 28.0;
pub const THICKNESS: f32 = 3.5;
const START: f32 = 230.0;
const SWEEP: f32 = 260.0;

// The gap at the bottom of the battery arc holds three Wi-Fi dots and one
// notification dot. All geometry is in logical pixels, independent of fonts.
pub fn view(theme: &Theme) -> Canvas {
    let battery = Battery::read();
    let bluetooth = Bluetooth::read();
    let network = Network::read();
    let pending = !Notifications::read().list().is_empty();

    let battery_color = if battery.charging() {
        theme.success
    } else if battery.percent() < 20 {
        theme.danger
    } else if battery.percent() < 50 {
        // Amber, with enough contrast against either theme's surface.
        if theme.light {
            Color::rgb(0xa1, 0x62, 0x07)
        } else {
            Color::rgb(0xf9, 0xc7, 0x4f)
        }
    } else {
        theme.text
    };
    let bluetooth_off = !bluetooth.available() || !bluetooth.powered();
    let bluetooth_color = if bluetooth_off {
        theme.muted_text
    } else if bluetooth.devices().iter().any(|device| device.connected()) {
        theme.accent
    } else {
        theme.text
    };

    // Prefer the current link's signal. An active access point also lets Wi-Fi
    // remain visible when a VPN or Ethernet is NetworkManager's primary link.
    let strength = if !network.wifi_enabled() || network.connecting() {
        None
    } else if network.link() == Link::Wifi {
        Some(network.strength())
    } else {
        network
            .access_points()
            .iter()
            .find(|ap| ap.active())
            .map(|ap| ap.strength())
    };
    let lit = match strength {
        None => 0,
        Some(0..=33) => 1,
        Some(34..=66) => 2,
        Some(_) => 3,
    };

    let arc = |sweep, color| {
        Arc::new()
            .center(SIZE / 2.0, SIZE / 2.0)
            .radius((SIZE - THICKNESS) / 2.0)
            .start(START)
            .sweep(sweep)
            .stroke(THICKNESS, color)
            .cap(Cap::Round)
    };
    let mut shapes: Vec<Box<dyn Shape>> = vec![Box::new(arc(SWEEP, theme.border))];
    if battery.present() {
        shapes.push(Box::new(arc(
            SWEEP * f32::from(battery.percent().min(100)) / 100.0,
            battery_color,
        )));
    }

    // Scale the original 26px symbol and dots together with the ring.
    let px = |value: f32| value * SIZE / 26.0;
    shapes.push(Box::new(
        Path::new()
            .move_to(px(10.25), px(10.5))
            .line_to(px(15.5), px(15.5))
            .line_to(px(13.0), px(18.0))
            .line_to(px(13.0), px(8.0))
            .line_to(px(15.5), px(10.5))
            .line_to(px(10.25), px(15.5))
            .stroke(px(1.3), bluetooth_color)
            .cap(Cap::Round),
    ));
    if bluetooth_off {
        shapes.push(Box::new(
            Path::new()
                .move_to(px(9.0), px(8.5))
                .line_to(px(17.0), px(17.5))
                .stroke(px(1.3), bluetooth_color)
                .cap(Cap::Round),
        ));
    }

    for index in 0..4 {
        let color = if index == 3 && pending {
            theme.accent
        } else if index < lit {
            theme.text
        } else {
            theme.border
        };
        shapes.push(Box::new(
            Circle::new()
                .center(px(6.25 + index as f32 * 4.5), px(23.0))
                .radius(px(1.45))
                .fill(color),
        ));
    }

    Canvas::new().width(SIZE).height(SIZE).shapes(shapes)
}
