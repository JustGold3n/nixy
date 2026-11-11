use super::*;
use std::sync::atomic::{AtomicU64, Ordering};

struct Fixture(PathBuf);

impl Fixture {
    fn new() -> Self {
        static NEXT: AtomicU64 = AtomicU64::new(0);
        let dir = env::temp_dir().join(format!(
            "amane-app-icons-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir(&dir).unwrap();
        Self(dir)
    }

    fn roots(&self) -> Vec<PathBuf> {
        vec![self.0.join("user/icons"), self.0.join("system/icons")]
    }

    fn write(&self, path: &str, text: &str) -> PathBuf {
        let path = self.0.join(path);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(&path, text).unwrap();
        path
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

#[test]
fn steam_icons_use_system_index_and_largest_local_size() {
    let fixture = Fixture::new();
    fixture.write(
        "system/icons/hicolor/index.theme",
        "[Icon Theme]\nDirectories=16x16/apps,32x32/apps,128x128/apps\n",
    );
    fixture.write("user/icons/hicolor/16x16/apps/steam_icon_262060.png", "");
    let largest = fixture.write("user/icons/hicolor/128x128/apps/steam_icon_262060.png", "");
    let system = fixture.write("system/icons/hicolor/32x32/apps/system-app.png", "");
    assert!(!fixture.roots()[0].join("hicolor/index.theme").exists());

    let folders = read_theme_icon_folders("hicolor", &fixture.roots());
    assert_eq!(
        look_up_icon_file("steam_icon_262060", &folders),
        Some(largest)
    );
    assert_eq!(look_up_icon_file("system-app", &folders), Some(system));
    assert_eq!(look_up_icon_file("missing", &folders), None);
}

#[test]
fn first_index_applies_to_every_root_and_local_icons_keep_priority() {
    let fixture = Fixture::new();
    fixture.write(
        "user/icons/hicolor/index.theme",
        "[Icon Theme]\nDirectories=32x32/apps\nScaledDirectories=32x32@2/apps\n",
    );
    fixture.write(
        "system/icons/hicolor/index.theme",
        "[Icon Theme]\nDirectories=128x128/apps\n",
    );
    let local = fixture.write("user/icons/hicolor/32x32/apps/game.png", "");
    fixture.write("system/icons/hicolor/32x32/apps/game.svg", "");
    let scaled = fixture.write("system/icons/hicolor/32x32@2/apps/scaled.png", "");

    let folders = read_theme_icon_folders("hicolor", &fixture.roots());
    assert_eq!(look_up_icon_file("game", &folders), Some(local));
    assert_eq!(look_up_icon_file("scaled", &folders), Some(scaled));
}

#[test]
fn selected_theme_still_precedes_hicolor() {
    let fixture = Fixture::new();
    for theme in ["Papirus", "hicolor"] {
        fixture.write(
            &format!("system/icons/{theme}/index.theme"),
            "[Icon Theme]\nDirectories=32x32/apps\n",
        );
    }
    let themed = fixture.write("system/icons/Papirus/32x32/apps/game.svg", "");
    fixture.write("user/icons/hicolor/32x32/apps/game.png", "");
    let steam = fixture.write("user/icons/hicolor/32x32/apps/steam_icon_262060.png", "");

    let mut folders = read_theme_icon_folders("Papirus", &fixture.roots());
    folders.extend(read_theme_icon_folders("hicolor", &fixture.roots()));
    assert_eq!(look_up_icon_file("game", &folders), Some(themed));
    assert_eq!(
        look_up_icon_file("steam_icon_262060", &folders),
        Some(steam)
    );
}
