use std::{fs, path::Path, process::Command, thread};

use amane::{
    Argument, Bus, Center, Column, End, Pointer, Rectangle, Row, ScrollArea, Service, Text, Value,
    Weight, Widget, children,
};

use super::{hover, hovered};
use crate::{
    fonts,
    overlay::Overlay,
    theme::{self, Theme},
};

const CONTROL: &str = "/run/current-system/sw/bin/battery-charge";
const BATTERY: &str = "/sys/class/power_supply/BAT0";

fn level_icon(percent: Option<f64>) -> &'static str {
    match percent
        .filter(|p| p.is_finite())
        .map(|p| (p.clamp(0.0, 100.0) / 10.0).round() as u8)
    {
        Some(0) => "󰂎",
        Some(1) => "󰁺",
        Some(2) => "󰁻",
        Some(3) => "󰁼",
        Some(4) => "󰁽",
        Some(5) => "󰁾",
        Some(6) => "󰁿",
        Some(7) => "󰂀",
        Some(8) => "󰂁",
        Some(9) => "󰂂",
        Some(_) => "󰁹",
        None => "󰂑",
    }
}

pub fn tab_icon() -> &'static str {
    level_icon(Charge::read().state.percent)
}

#[derive(Default, PartialEq)]
struct Snapshot {
    enabled: Option<bool>,
    plugged: bool,
    start: u32,
    end: u32,
    percent: Option<f64>,
    status: String,
    model: String,
    health: Option<f64>,
    energy: Option<f64>,
    full: Option<f64>,
    design: Option<f64>,
    rate: Option<f64>,
    voltage: Option<f64>,
    temperature: Option<f64>,
    cycles: Option<f64>,
    to_empty: Option<f64>,
    to_full: Option<f64>,
}

fn number(properties: &Value, name: &str) -> Option<f64> {
    match properties.get(name) {
        Value::Number(n) if n.is_finite() && *n >= 0.0 => Some(*n),
        _ => None,
    }
}

impl Snapshot {
    fn read() -> Self {
        let read = |name: &str| fs::read_to_string(Path::new(BATTERY).join(name)).ok();
        let start = read("charge_control_start_threshold")
            .and_then(|s| s.trim().parse().ok())
            .unwrap_or(0);
        let end = read("charge_control_end_threshold")
            .and_then(|s| s.trim().parse().ok())
            .unwrap_or(0);
        // UPower's threshold flag can be stale after authenticated firmware writes.
        let enabled = if Path::new(CONTROL).exists() {
            read("charge_types").map(|mode| mode.contains("[Custom]") && end < 100)
        } else {
            None
        };
        let properties = Bus::system().call(
            "org.freedesktop.UPower",
            "/org/freedesktop/UPower/devices/battery_BAT0",
            "org.freedesktop.DBus.Properties",
            "GetAll",
            &[Argument::from("org.freedesktop.UPower.Device")],
        );
        Self {
            enabled,
            plugged: fs::read_to_string("/sys/class/power_supply/AC/online")
                .is_ok_and(|s| s.trim() == "1"),
            start,
            end,
            percent: read("capacity").and_then(|s| s.trim().parse().ok()),
            status: read("status").unwrap_or_default().trim().to_owned(),
            model: read("model_name").unwrap_or_default().trim().to_owned(),
            health: number(&properties, "Capacity").filter(|n| *n > 0.0),
            energy: number(&properties, "Energy"),
            full: number(&properties, "EnergyFull").filter(|n| *n > 0.0),
            design: number(&properties, "EnergyFullDesign").filter(|n| *n > 0.0),
            rate: number(&properties, "EnergyRate"),
            voltage: number(&properties, "Voltage").filter(|n| *n > 0.0),
            temperature: number(&properties, "Temperature").filter(|n| *n > 0.0),
            cycles: number(&properties, "ChargeCycles"),
            to_empty: number(&properties, "TimeToEmpty").filter(|n| *n > 0.0),
            to_full: number(&properties, "TimeToFull").filter(|n| *n > 0.0),
        }
    }

    fn estimate(&self) -> String {
        let hours = |energy: Option<f64>| -> Option<f64> {
            let rate = self.rate.filter(|n| *n > 0.1)?;
            Some(energy?.max(0.0) / rate * 3600.0)
        };
        let (seconds, target) = match self.status.as_str() {
            "Discharging" => (
                self.to_empty.or_else(|| hours(self.energy)),
                "remaining".to_owned(),
            ),
            "Charging" => {
                if self.enabled == Some(true) {
                    let remaining = self
                        .full
                        .zip(self.energy)
                        .map(|(full, energy)| full * f64::from(self.end) / 100.0 - energy);
                    (hours(remaining), format!("until {}%", self.end))
                } else {
                    (
                        self.to_full.or_else(|| {
                            hours(
                                self.full
                                    .zip(self.energy)
                                    .map(|(full, energy)| full - energy),
                            )
                        }),
                        "until full".to_owned(),
                    )
                }
            }
            "Full" if self.enabled == Some(true) => {
                return format!("Charge limit reached ({}%)", self.end);
            }
            "Full" => return "Fully charged".to_owned(),
            "Not charging" if self.enabled == Some(true) => {
                return if self.percent.is_some_and(|p| p >= f64::from(self.end)) {
                    format!("At or above the {}% charge limit", self.end)
                } else {
                    format!("Charging resumes below {}%", self.start)
                };
            }
            "Not charging" => return "Charging paused".to_owned(),
            _ => return "Time estimate unavailable".to_owned(),
        };
        seconds
            .and_then(duration)
            .map(|time| format!("~{time} {target}"))
            .unwrap_or_else(|| "Time estimate unavailable".to_owned())
    }
}

fn duration(seconds: f64) -> Option<String> {
    if !seconds.is_finite() || seconds <= 0.0 {
        return None;
    }
    let minutes = (seconds / 60.0).ceil() as u64;
    Some(if minutes < 60 {
        format!("{minutes} min")
    } else {
        format!("{} h {} min", minutes / 60, minutes % 60)
    })
}
#[derive(Default)]
struct Charge {
    state: Snapshot,
    busy: bool,
    failed: bool,
}

impl Service for Charge {
    fn new() -> Self {
        Self::default()
    }

    fn listen() {
        let mut signals =
            Bus::system().signals("org.freedesktop.DBus.Properties", "PropertiesChanged");
        loop {
            // Read hardware outside the UI's service lock.
            let state = Snapshot::read();
            let changed = {
                let charge = Self::read();
                !charge.busy && charge.state != state
            };
            if changed {
                let mut charge = Self::write();
                if !charge.busy {
                    charge.state = state;
                }
            }
            // UPower already monitors the battery. Do not continually query
            // Dell firmware while the panel is closed (or the desktop idle).
            if !signals.any(|signal| signal.path().starts_with("/org/freedesktop/UPower")) {
                return;
            }
        }
    }
}

fn toggle() {
    let enable = {
        let mut charge = Charge::write();
        let Some(enabled) = charge.state.enabled else {
            return;
        };
        if charge.busy || (enabled && !charge.state.plugged) {
            return;
        }
        charge.busy = true;
        charge.failed = false;
        !enabled
    };
    thread::spawn(move || {
        let result = Command::new(CONTROL)
            .arg(if enable { "care" } else { "full" })
            .status();
        let state = Snapshot::read();
        let cancelled = result
            .as_ref()
            .is_ok_and(|status| status.code() == Some(130));
        let failed = !cancelled
            && (!result.is_ok_and(|status| status.success()) || state.enabled != Some(enable));
        let mut charge = Charge::write();
        charge.state = state;
        charge.failed = failed;
        charge.busy = false;
    });
}

pub fn view(overlay: &Overlay, theme: &Theme, width: f32, height: f32) -> Column {
    let charge = Charge::read();
    let state = &charge.state;
    let header = Rectangle::new()
        .width(width)
        .height(90.0)
        .radius(16.0)
        .fill(theme.surface)
        .padding(12.0)
        .child(
            Row::new(children![
                Rectangle::new()
                    .width(44.0)
                    .height(44.0)
                    .radius(12.0)
                    .fill(theme.selected_surface)
                    .align_child(Center, Center)
                    .child(
                        Rectangle::new()
                            .width(30.0)
                            .height(30.0)
                            .rotate(90.0)
                            .align_child(Center, Center)
                            .child(
                                Text::new(level_icon(state.percent))
                                    .font(fonts::NERD)
                                    .size(26.0)
                                    .tight()
                                    .color(theme.accent)
                            )
                    ),
                Column::new(children![
                    Text::new(
                        state
                            .percent
                            .map(|p| format!("{p:.0}%"))
                            .unwrap_or_else(|| "—".to_owned())
                    )
                    .font(fonts::BODY)
                    .size(25.0)
                    .weight(Weight::SemiBold)
                    .color(theme.text),
                    Text::new(if state.status.is_empty() {
                        "Battery unavailable"
                    } else {
                        &state.status
                    })
                    .font(fonts::BODY)
                    .size(11.0)
                    .color(theme.text),
                    Text::new(state.estimate())
                        .font(fonts::BODY)
                        .size(10.0)
                        .color(theme.muted_text),
                ])
                .gap(2.0),
            ])
            .gap(12.0)
            .align(Center),
        );

    let value = |n: Option<f64>, unit: &str| {
        n.map(|n| format!("{n:.1} {unit}"))
            .unwrap_or_else(|| "Not reported".to_owned())
    };
    let mode = match state.enabled {
        Some(true) => format!("Battery care · {}–{}%", state.start, state.end),
        Some(false) => "Full charge · 100%".to_owned(),
        None => "Unavailable".to_owned(),
    };
    let entries = [
        ("Charge mode", mode),
        (
            "Power source",
            if state.plugged {
                "Plugged in"
            } else {
                "Battery"
            }
            .to_owned(),
        ),
        (
            "Health",
            state
                .health
                .map(|n| format!("{n:.0}% of design"))
                .unwrap_or_else(|| "Not reported".to_owned()),
        ),
        ("Energy now", value(state.energy, "Wh")),
        ("Full capacity", value(state.full, "Wh")),
        ("Design capacity", value(state.design, "Wh")),
        (
            if state.status == "Charging" {
                "Charging rate"
            } else {
                "Power draw"
            },
            if matches!(state.status.as_str(), "Charging" | "Discharging") {
                value(state.rate, "W")
            } else {
                "Idle".to_owned()
            },
        ),
        ("Voltage", value(state.voltage, "V")),
        ("Temperature", value(state.temperature, "°C")),
        (
            "Charge cycles",
            state
                .cycles
                .map(|n| format!("{n:.0}"))
                .unwrap_or_else(|| "Not reported".to_owned()),
        ),
        (
            "Model",
            if state.model.is_empty() {
                "Not reported".to_owned()
            } else {
                state.model.clone()
            },
        ),
    ];
    let count = entries.len() as f32;
    let rows: Vec<Box<dyn Widget>> = entries
        .into_iter()
        .map(|(label, value)| {
            Box::new(detail(theme, width - 20.0, label, value)) as Box<dyn Widget>
        })
        .collect();
    let details = Rectangle::new()
        .width(width)
        .height(count * 26.0 + 20.0)
        .radius(12.0)
        .fill(theme.surface)
        .padding(10.0)
        .child(Column::new(rows));
    let area = Rectangle::new()
        .width(width)
        .height((height - 90.0 - 48.0 - 32.0 - 30.0).max(0.0))
        .child(ScrollArea::new("battery-details", details));
    let note = if charge.failed {
        "Charge change failed · try again"
    } else {
        "BIOS administrator password required"
    };
    let footer = Rectangle::new()
        .width(width)
        .height(32.0)
        .align_child(Center, Center)
        .child(
            Column::new(children![
                Text::new(note)
                    .font(fonts::BODY)
                    .size(10.0)
                    .color(if charge.failed {
                        theme.danger
                    } else {
                        theme.muted_text
                    }),
                Text::new("Restoring after unplugging asks again")
                    .font(fonts::BODY)
                    .size(10.0)
                    .color(theme.muted_text),
            ])
            .align(Center)
            .gap(3.0),
        );
    Column::new(children![
        header,
        area,
        mode_button(overlay, theme, &charge, width),
        footer
    ])
    .gap(10.0)
}

fn detail(theme: &Theme, width: f32, label: &str, value: String) -> Row {
    Row::new(children![
        Rectangle::new()
            .width(100.0)
            .height(26.0)
            .align_child(amane::Start, Center)
            .child(
                Text::new(label.to_owned())
                    .font(fonts::BODY)
                    .size(11.0)
                    .color(theme.muted_text)
            ),
        Rectangle::new()
            .width(width - 100.0)
            .height(26.0)
            .align_child(End, Center)
            .child(
                Text::new(value)
                    .font(fonts::BODY)
                    .size(11.0)
                    .color(theme.text)
                    .elide()
            ),
    ])
    .width(width)
    .height(26.0)
}

fn mode_button(overlay: &Overlay, theme: &Theme, charge: &Charge, width: f32) -> Rectangle {
    let available = !charge.busy
        && charge.state.enabled.is_some()
        && (charge.state.plugged || charge.state.enabled == Some(false));
    let label = if charge.busy {
        "Waiting for BIOS authentication…"
    } else if charge.state.enabled == Some(false) {
        "Use battery care (80%)"
    } else {
        "Charge to 100%"
    };
    let button = Rectangle::new()
        .width(width)
        .height(48.0)
        .radius(24.0)
        .fill(if hovered(overlay, "battery:mode") {
            theme::mix(theme.accent, theme.on_accent, 0.12)
        } else {
            theme.accent
        })
        .align_child(Center, Center)
        .child(
            Text::new(label)
                .font(fonts::BODY)
                .size(12.0)
                .weight(Weight::SemiBold)
                .color(theme.on_accent),
        );
    if !available {
        return button.opacity(0.5);
    }
    button
        .cursor(Pointer)
        .on_hover(|inside| hover("battery:mode".to_owned(), inside))
        .on_click(|_| toggle())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn draining_uses_reported_time_or_energy_estimate() {
        let mut s = Snapshot {
            status: "Discharging".to_owned(),
            to_empty: Some(5400.0),
            energy: Some(40.0),
            rate: Some(10.0),
            ..Snapshot::default()
        };
        assert_eq!(s.estimate(), "~1 h 30 min remaining");
        s.to_empty = None;
        assert_eq!(s.estimate(), "~4 h 0 min remaining");
    }

    #[test]
    fn care_estimates_to_limit_instead_of_full() {
        let s = Snapshot {
            status: "Charging".to_owned(),
            enabled: Some(true),
            end: 80,
            full: Some(50.0),
            energy: Some(30.0),
            rate: Some(10.0),
            to_full: Some(7200.0),
            ..Snapshot::default()
        };
        assert_eq!(s.estimate(), "~1 h 0 min until 80%");
    }

    #[test]
    fn full_charge_uses_reported_time() {
        let s = Snapshot {
            status: "Charging".to_owned(),
            enabled: Some(false),
            to_full: Some(2700.0),
            ..Snapshot::default()
        };
        assert_eq!(s.estimate(), "~45 min until full");
    }

    #[test]
    fn paused_above_limit_never_claims_to_be_charging() {
        let mut s = Snapshot {
            status: "Not charging".to_owned(),
            enabled: Some(true),
            start: 50,
            end: 80,
            percent: Some(96.0),
            to_full: Some(1200.0),
            ..Snapshot::default()
        };
        assert_eq!(s.estimate(), "At or above the 80% charge limit");
        s.percent = Some(60.0);
        assert_eq!(s.estimate(), "Charging resumes below 50%");
    }

    #[test]
    fn missing_rates_and_invalid_times_are_not_zero_estimates() {
        let s = Snapshot {
            status: "Discharging".to_owned(),
            energy: Some(40.0),
            rate: Some(0.0),
            ..Snapshot::default()
        };
        assert_eq!(s.estimate(), "Time estimate unavailable");
        assert_eq!(duration(0.0), None);
        assert_eq!(duration(f64::NAN), None);
        assert_eq!(duration(f64::INFINITY), None);
    }
}
