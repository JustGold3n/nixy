use crate::theme::{self, Theme};
use amane::{Color, Gradient};

// The material follows the live wallpaper palette, including light mode.
// Only background fills are translucent; text, icons and controls stay crisp.
pub fn tint(theme: &Theme) -> Color {
    theme::with_opacity(
        theme::mix(
            theme.background,
            theme.accent,
            if theme.light { 0.04 } else { 0.09 },
        ),
        if theme.light { 0.78 } else { 0.68 },
    )
}

pub fn fill(theme: &Theme) -> Gradient {
    let base = tint(theme);
    let sheen = theme::mix(base, Color::WHITE, if theme.light { 0.12 } else { 0.07 });
    Gradient::linear(0.0, [(0.0, base), (0.65, base), (1.0, sheen)])
}

pub fn edge(theme: &Theme) -> Color {
    theme::with_opacity(theme::mix(theme.accent, Color::WHITE, 0.65), 0.30)
}

pub fn card(theme: &Theme) -> Color {
    theme::with_opacity(theme.surface, if theme.light { 0.52 } else { 0.42 })
}
