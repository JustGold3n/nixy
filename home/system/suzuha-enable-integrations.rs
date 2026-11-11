use nixy_tools::{Result, atomic_write};
use std::path::Path;

fn enable(state: &Path, marker: &str, names: &[&str]) -> Result {
    let marker = state.join(marker);
    if marker.exists() {
        return Ok(());
    }
    let settings = state.join("settings");
    let old = match std::fs::read_to_string(&settings) {
        Ok(value) => value,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => String::new(),
        Err(error) => return Err(error.into()),
    };
    let mut keys: Vec<_> = names
        .iter()
        .map(|name| format!("integration_{name}"))
        .collect();
    keys.sort();
    let mut lines: Vec<_> = old
        .lines()
        .filter(|line| !keys.iter().any(|key| line.split('=').next() == Some(key)))
        .map(str::to_owned)
        .collect();
    lines.extend(keys.iter().map(|key| format!("{key}=true")));
    atomic_write(&settings, format!("{}\n", lines.join("\n")))?;
    std::fs::write(marker, "")?;
    Ok(())
}

fn run() -> Result {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() == 1 && args[0] == "--help" {
        println!("Usage: suzuha-enable-integrations STATE_DIR CONFIG_DIR");
        return Ok(());
    }
    if args.len() != 2 {
        return Err("Usage: suzuha-enable-integrations STATE_DIR CONFIG_DIR".into());
    }
    let state = Path::new(&args[0]);
    std::fs::create_dir_all(state)?;
    enable(
        state,
        "theme-integrations-enabled",
        &[
            "gtk", "terminal", "tmux", "neovim", "vesktop", "spotify", "btop", "cava",
        ],
    )?;
    enable(state, "neovim-wallpaper-enabled", &["neovim"])?;
    let palette = state.join("terminal-colors-foot.ini");
    match std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(palette)
    {
        Ok(mut file) => {
            use std::io::Write;
            file.write_all(b"# Populated by Suzuha at startup.\n")?;
        }
        Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => {}
        Err(error) => return Err(error.into()),
    }
    std::fs::create_dir_all(Path::new(&args[1]).join("vesktop/settings"))?;
    Ok(())
}
fn main() {
    nixy_tools::main_result(run());
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn migration_preserves_other_settings_and_subsequent_changes() -> Result {
        let dir = tempfile::tempdir()?;
        let settings = dir.path().join("settings");
        std::fs::write(&settings, "other=value\nintegration_gtk=false\n")?;
        enable(dir.path(), "marker", &["gtk", "neovim"])?;
        assert_eq!(
            std::fs::read_to_string(&settings)?,
            "other=value\nintegration_gtk=true\nintegration_neovim=true\n"
        );
        std::fs::write(&settings, "integration_gtk=false\n")?;
        enable(dir.path(), "marker", &["gtk"])?;
        assert_eq!(
            std::fs::read_to_string(settings)?,
            "integration_gtk=false\n"
        );
        Ok(())
    }
}
