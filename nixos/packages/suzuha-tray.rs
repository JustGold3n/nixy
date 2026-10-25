use crate::{
    bar, fonts,
    settings::Settings,
    theme::{self, Theme},
};
use amane::tray::{self, Item, MenuEntry, Tray};
use amane::{
    Button, Center, Color, Column, Full, Horizontal, Image, Key, Keyboard, Layer, LayerWindow,
    Margin, Monitor, Padding, Parent, Pointer, Rectangle, Row, ScrollArea, Service, Start, Text,
    Vertical, Widget, Zone,
};

#[derive(Default)]
struct Popup {
    open: bool,
    monitor: String,
    item: Option<Item>,
    rows: Vec<MenuEntry>,
    parents: Vec<i32>,
    generation: u64,
    loading: bool,
    hover: String,
}
impl Service for Popup {
    fn new() -> Self {
        Self::default()
    }
    fn listen() {}
}
fn close() {
    let mut state = Popup::write();
    state.open = false;
    state.generation += 1;
}
fn show_apps(monitor: String) {
    let mut state = Popup::write();
    state.open = true;
    state.monitor = monitor;
    state.item = None;
    state.rows.clear();
    state.parents.clear();
    state.generation += 1;
    state.loading = false;
}
fn show_menu(item: Item, monitor: String, parents: Vec<i32>) {
    let parent = *parents.last().unwrap_or(&0);
    let generation = {
        let mut state = Popup::write();
        state.open = true;
        state.monitor = monitor;
        state.item = Some(item.clone());
        state.rows.clear();
        state.parents = parents;
        state.loading = true;
        state.generation += 1;
        state.generation
    };
    std::thread::spawn(move || {
        let rows = tray::menu(&item, parent);
        let mut state = Popup::write();
        if state.generation != generation {
            state.quiet();
            return;
        }
        state.loading = false;
        if let Some(rows) = rows {
            state.rows = rows;
        } else {
            state.open = false;
        }
    });
}
fn click(item: Item, monitor: String, button: Button) {
    match button {
        Button::Right => show_menu(item, monitor, vec![0]),
        Button::Middle => tray::activate(item, true),
        Button::Left if item.menu_only => show_menu(item, monitor, vec![0]),
        Button::Left => {
            close();
            tray::activate(item, false);
        }
    }
}
fn hover(key: String, inside: bool) {
    let mut state = Popup::write();
    if inside {
        state.hover = key;
    } else if state.hover == key {
        state.hover.clear();
    } else {
        state.quiet();
    }
}
fn image(item: &Item, theme: &Theme) -> Rectangle {
    let icon = Rectangle::new()
        .width(18.0)
        .height(18.0)
        .align_child(Center, Center);
    if let Some(path) = &item.icon {
        icon.fill(Image::contain(path))
    } else {
        icon.child(
            Text::new(item.title.chars().next().unwrap_or('?').to_string())
                .font(fonts::BODY)
                .size(13.0)
                .color(theme.text),
        )
    }
}
fn icon(item: &Item, theme: &Theme, monitor: &str) -> Rectangle {
    let active = Popup::read().hover == item.key;
    let clicked = item.clone();
    let scrolled = item.clone();
    let key = item.key.clone();
    let monitor = monitor.to_string();
    Rectangle::new()
        .width(26.0)
        .height(bar::ITEM_HEIGHT)
        .radius(7.0)
        .fill(if item.attention {
            theme.selected_surface
        } else if active {
            theme.hover_surface
        } else {
            Color::TRANSPARENT
        })
        .align_child(Center, Center)
        .child(image(item, theme))
        .cursor(Pointer)
        .on_hover(move |inside| hover(key.clone(), inside))
        .on_click(move |button| click(clicked.clone(), monitor.clone(), button))
        .on_scroll(move |scroll| {
            let horizontal = scroll.x.abs() > scroll.y.abs();
            let amount = if horizontal { scroll.x } else { -scroll.y };
            tray::scroll(scrolled.clone(), (amount * 120.0) as i32, horizontal);
        })
}
pub fn icons(theme: &Theme, monitor: &Monitor, available: f32) -> Option<Row> {
    let items = Tray::read();
    if items.items.is_empty() {
        return None;
    }
    let capacity = ((available - 240.0) / 28.0).floor().clamp(1.0, 8.0) as usize;
    let overflow = items.items.len() > capacity;
    let visible = if overflow {
        capacity.saturating_sub(1)
    } else {
        capacity
    };
    let mut children: Vec<Box<dyn Widget>> = items
        .items
        .iter()
        .take(visible)
        .map(|item| Box::new(icon(item, theme, &monitor.name)) as Box<dyn Widget>)
        .collect();
    if overflow {
        let monitor = monitor.name.clone();
        children.push(Box::new(
            Rectangle::new()
                .width(26.0)
                .height(bar::ITEM_HEIGHT)
                .radius(7.0)
                .fill(theme.surface)
                .align_child(Center, Center)
                .cursor(Pointer)
                .child(
                    Text::new("…")
                        .font(fonts::BODY)
                        .size(17.0)
                        .color(theme.text),
                )
                .on_click(move |_| show_apps(monitor.clone())),
        ));
    }
    Some(Row::new(children).gap(2.0).align(Center))
}
fn shown(state: &Popup) -> bool {
    state.open
        && state.item.as_ref().is_none_or(|item| {
            Tray::read()
                .items
                .iter()
                .any(|current| current.key == item.key)
        })
}
pub fn dismiss(monitor: &Monitor) -> LayerWindow {
    let state = Popup::read();
    let visible = shown(&state);
    let _ = monitor;
    LayerWindow::new()
        .width(Full)
        .height(Full)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .namespace("amane-tray-dismiss")
        .visible(visible)
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .fill(Color::TRANSPARENT)
                .on_click(|_| close()),
        )
}
fn text_row(label: &str, theme: &Theme) -> Rectangle {
    Rectangle::new()
        .width(Parent)
        .height(30.0)
        .padding(Padding::from(6.0))
        .align_child(Start, Center)
        .clip()
        .child(
            Text::new(label)
                .font(fonts::BODY)
                .size(13.0)
                .color(theme.text),
        )
}
pub fn popup(monitor: &Monitor) -> LayerWindow {
    let state = Popup::read();
    let visible = shown(&state) && state.monitor == monitor.name;
    let theme = theme::current();
    let bottom = Settings::read().text("bar_position") == "bottom";
    let mut rows: Vec<Box<dyn Widget>> = Vec::new();
    let header = state
        .item
        .as_ref()
        .map(|i| i.title.as_str())
        .unwrap_or("Background apps");
    rows.push(Box::new(text_row(header, &theme)));
    if state.parents.len() > 1 {
        let item = state.item.clone().unwrap();
        let monitor = state.monitor.clone();
        let mut parents = state.parents.clone();
        parents.pop();
        rows.push(Box::new(
            text_row("‹ Back", &theme)
                .cursor(Pointer)
                .on_click(move |_| show_menu(item.clone(), monitor.clone(), parents.clone())),
        ));
    }
    if state.loading {
        rows.push(Box::new(text_row("Loading…", &theme)));
    } else if let Some(item) = &state.item {
        if state.rows.is_empty() {
            rows.push(Box::new(text_row("No menu actions", &theme)));
        }
        for entry in &state.rows {
            if entry.separator {
                rows.push(Box::new(
                    Rectangle::new()
                        .width(Parent)
                        .height(1.0)
                        .fill(theme.border),
                ));
                continue;
            }
            let mark = match entry.checked {
                Some(true) => "✓ ",
                Some(false) => "○ ",
                None => "",
            };
            let label = format!(
                "{mark}{}{}",
                entry.label,
                if entry.submenu { "  ›" } else { "" }
            );
            let key = format!("menu:{}", entry.id);
            let background = if state.hover == key && entry.enabled {
                theme.hover_surface
            } else {
                Color::TRANSPARENT
            };
            let row = text_row(&label, &theme)
                .fill(background)
                .radius(6.0)
                .opacity(if entry.enabled { 1.0 } else { 0.45 });
            if !entry.enabled {
                rows.push(Box::new(row));
                continue;
            }
            let entry = entry.clone();
            let item = item.clone();
            let monitor = state.monitor.clone();
            let parents = state.parents.clone();
            rows.push(Box::new(
                row.cursor(Pointer)
                    .on_hover(move |inside| hover(key.clone(), inside))
                    .on_click(move |_| {
                        if entry.submenu {
                            let mut parents = parents.clone();
                            parents.push(entry.id);
                            show_menu(item.clone(), monitor.clone(), parents);
                        } else {
                            close();
                            tray::invoke(item.clone(), entry.id);
                        }
                    }),
            ));
        }
    } else {
        for item in &Tray::read().items {
            let clicked = item.clone();
            let monitor = monitor.name.clone();
            let row = Row::new(vec![
                Box::new(image(item, &theme)) as Box<dyn Widget>,
                Box::new(
                    Text::new(&item.title)
                        .font(fonts::BODY)
                        .size(13.0)
                        .color(theme.text),
                ),
            ])
            .gap(10.0)
            .align(Center);
            rows.push(Box::new(
                Rectangle::new()
                    .width(Parent)
                    .height(32.0)
                    .padding(Padding::from(6.0))
                    .clip()
                    .child(row)
                    .cursor(Pointer)
                    .on_click(move |button| click(clicked.clone(), monitor.clone(), button)),
            ));
        }
    }
    let content_height: f32 = rows.iter().map(|_| 34.0).sum();
    let height = (content_height + 16.0)
        .min(600.0)
        .min(monitor.height as f32 - bar::height() - 24.0)
        .max(48.0);
    let width = 300.0_f32.min(monitor.width as f32 - 24.0);
    let offset = bar::height() as i32 + 8;
    let margin = Margin {
        top: if bottom { 0 } else { offset },
        bottom: if bottom { offset } else { 0 },
        left: 0,
        right: 8,
    };
    LayerWindow::new()
        .width(width)
        .height(height)
        .layer(Layer::Overlay)
        .space(Zone::Ignore)
        .anchor_horizontal(Horizontal::Right)
        .anchor_vertical(if bottom {
            Vertical::Bottom
        } else {
            Vertical::Top
        })
        .margin(margin)
        .namespace("amane-tray-menu")
        .visible(visible)
        .keyboard(Keyboard::Exclusive)
        .on_key(|key| {
            if key == Key::Escape {
                close();
            }
        })
        .child(
            Rectangle::new()
                .width(Parent)
                .height(Parent)
                .radius(12.0)
                .fill(theme.surface)
                .padding(Padding::from(8.0))
                .clip()
                .child(ScrollArea::new(
                    "amane-tray-menu",
                    Column::new(rows).width(Parent).gap(3.0),
                )),
        )
}

// Keyboard entry point and a read-only status useful when checking the tray.
pub fn ipc(arguments: &[String]) -> String {
    match arguments.first().map(String::as_str) {
        Some("close") => {
            close();
            "ok".into()
        }
        Some("status") => {
            let popup = Popup::read();
            format!(
                "items={} menu_open={} loading={} menu_rows={}",
                Tray::read().items.len(),
                popup.open,
                popup.loading,
                popup.rows.len()
            )
        }
        command => {
            let monitor = amane::Workspaces::read()
                .list()
                .iter()
                .find(|w| w.focused())
                .and_then(|w| w.output())
                .unwrap_or("eDP-1")
                .to_string();
            if command == Some("menu") {
                let index = arguments
                    .get(1)
                    .and_then(|s| s.parse::<usize>().ok())
                    .unwrap_or(0);
                let item = Tray::read().items.get(index).cloned();
                if let Some(item) = item {
                    show_menu(item, monitor, vec![0]);
                } else {
                    return "No such tray item".into();
                }
            } else if Popup::read().open {
                close();
            } else {
                show_apps(monitor);
            }
            "ok".into()
        }
    }
}
