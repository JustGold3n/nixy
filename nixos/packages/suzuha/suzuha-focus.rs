use std::fs;
use std::path::PathBuf;

use amane::Service;

pub struct Focus {
    pub enabled: bool,
}

fn path() -> PathBuf {
    PathBuf::from(crate::integrations::state_home()).join("niri-focus-mode.kdl")
}

impl Service for Focus {
    fn new() -> Self {
        Self { enabled: path().exists() }
    }
}

// The optional Niri include and bar state are toggled together. No persistent
// shell settings are changed, so toggling off restores the user's appearance.
pub fn ipc(_: &[String]) -> String {
    let mut focus = Focus::write();
    let path = path();
    let result = if focus.enabled {
        fs::remove_file(&path)
    } else {
        fs::create_dir_all(path.parent().unwrap()).and_then(|_| {
            let partial = path.with_extension("partial");
            fs::write(&partial, concat!(
                "layout { gaps 0; }\n",
                "animations { off; }\n",
                "window-rule { geometry-corner-radius 0; opacity 1.0; }\n",
            ))?;
            fs::rename(partial, &path)
        })
    };
    match result {
        Ok(()) => {
            focus.enabled = !focus.enabled;
            format!("Focus mode {}", if focus.enabled { "on" } else { "off" })
        }
        Err(error) => format!("Could not toggle focus mode: {error}"),
    }
}
