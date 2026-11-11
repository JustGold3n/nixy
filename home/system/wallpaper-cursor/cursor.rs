use nixy_tools::{Result, atomic_write, checked};
use sha2::{Digest, Sha256};
use std::{
    collections::{HashMap, HashSet},
    path::Path,
    process::Command,
};

const MAGIC: u32 = 0x72756358;
const IMAGE: u32 = 0xfffd0002;
const PREFIX: &str = "ArcStarry-Wallpaper-";

fn word(data: &[u8], offset: usize) -> Result<u32> {
    Ok(u32::from_le_bytes(
        data.get(offset..offset.checked_add(4).ok_or("invalid cursor offset")?)
            .ok_or("truncated Xcursor")?
            .try_into()?,
    ))
}
fn hls(r: f64, g: f64, b: f64) -> (f64, f64, f64) {
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let light = (max + min) / 2.0;
    if max == min {
        return (0.0, light, 0.0);
    }
    let delta = max - min;
    let sat = if light <= 0.5 {
        delta / (max + min)
    } else {
        delta / (2.0 - max - min)
    };
    let hue = if max == r {
        (g - b) / delta
    } else if max == g {
        (b - r) / delta + 2.0
    } else {
        (r - g) / delta + 4.0
    };
    ((hue / 6.0).rem_euclid(1.0), light, sat)
}
fn rgb(h: f64, l: f64, s: f64) -> [f64; 3] {
    let m2 = if l <= 0.5 {
        l * (1.0 + s)
    } else {
        l + s - l * s
    };
    let m1 = 2.0 * l - m2;
    [h + 1.0 / 3.0, h, h - 1.0 / 3.0].map(|v| {
        let v = v.rem_euclid(1.0);
        if v < 1.0 / 6.0 {
            m1 + (m2 - m1) * v * 6.0
        } else if v < 0.5 {
            m2
        } else if v < 2.0 / 3.0 {
            m1 + (m2 - m1) * (2.0 / 3.0 - v) * 6.0
        } else {
            m1
        }
    })
}
fn accent(value: &str) -> Result<[f64; 3]> {
    if value.len() != 6 || !value.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("invalid wallpaper accent".into());
    }
    Ok([0, 2, 4].map(|i| u8::from_str_radix(&value[i..i + 2], 16).unwrap() as f64 / 255.0))
}
fn recolor(data: &[u8], color: &str, cache: &mut HashMap<u32, u32>) -> Result<Vec<u8>> {
    let [r, g, b] = accent(color)?;
    let (hue, _, saturation) = hls(r, g, b);
    let reference = hls(192.0 / 255.0, 144.0 / 255.0, 232.0 / 255.0).2;
    let header = word(data, 4)? as usize;
    let count = word(data, 12)? as usize;
    if word(data, 0)? != MAGIC
        || header < 16
        || header
            .checked_add(count.checked_mul(12).ok_or("invalid table size")?)
            .ok_or("invalid table offset")?
            > data.len()
    {
        return Err("invalid Xcursor header".into());
    }
    let mut result = data.to_vec();
    let mut visited = HashSet::new();
    for index in 0..count {
        let entry = header + index * 12;
        let offset = word(data, entry + 8)? as usize;
        if word(data, entry)? != IMAGE || !visited.insert(offset) {
            continue;
        }
        let chunk = word(data, offset)? as usize;
        let width = word(data, offset + 16)? as usize;
        let height = word(data, offset + 20)? as usize;
        let _delay = word(data, offset + 32)?;
        if word(data, offset + 4)? != IMAGE
            || chunk < 36
            || word(data, offset + 24)? as usize >= width
            || word(data, offset + 28)? as usize >= height
        {
            return Err("invalid Xcursor image".into());
        }
        let start = offset.checked_add(chunk).ok_or("invalid image offset")?;
        let end = start
            .checked_add(
                width
                    .checked_mul(height)
                    .and_then(|v| v.checked_mul(4))
                    .ok_or("invalid image size")?,
            )
            .ok_or("invalid image size")?;
        if end > data.len() {
            return Err("truncated Xcursor pixels".into());
        }
        for pos in (start..end).step_by(4) {
            let pixel = word(data, pos)?;
            let replacement = *cache.entry(pixel).or_insert_with(|| {
                let alpha = pixel >> 24;
                if alpha == 0 {
                    return pixel;
                }
                let [r, g, b] = [16, 8, 0]
                    .map(|shift| (((pixel >> shift) & 255) as f64 / alpha as f64).min(1.0));
                let (_, light, old_sat) = hls(r, g, b);
                if old_sat <= 0.08 {
                    return pixel;
                }
                let [r, g, b] = rgb(hue, light, (old_sat * saturation / reference).min(1.0))
                    .map(|v| ((v * alpha as f64).round_ties_even() as u32).min(alpha));
                (alpha << 24) | (r << 16) | (g << 8) | b
            });
            result[pos..pos + 4].copy_from_slice(&replacement.to_le_bytes());
        }
    }
    Ok(result)
}
fn generate(source: &Path, icons: &Path, color: &str) -> Result<String> {
    accent(color)?;
    let digest = format!(
        "{:x}",
        Sha256::digest(format!("{}{color}v1", source.display()))
    );
    let name = format!("{PREFIX}{}", &digest[..12]);
    let target = icons.join(&name);
    if target.join(".wallpaper-generated").is_file() {
        std::fs::File::open(&target)?.set_modified(std::time::SystemTime::now())?;
        return Ok(name);
    }
    std::fs::create_dir_all(icons)?;
    let temporary = tempfile::Builder::new()
        .prefix(".wallpaper-cursor-")
        .tempdir_in(icons)?;
    let pending = temporary.path().join(&name);
    let cursors = pending.join("cursors");
    std::fs::create_dir_all(&cursors)?;
    let mut cache = HashMap::new();
    for item in std::fs::read_dir(source.join("cursors"))? {
        let item = item?;
        let path = item.path();
        let output = cursors.join(item.file_name());
        if item.file_type()?.is_symlink() {
            let link = std::fs::read_link(&path)?;
            if link.components().count() != 1
                || !matches!(
                    link.components().next(),
                    Some(std::path::Component::Normal(_))
                )
            {
                return Err("cursor alias must stay inside the theme".into());
            }
            std::os::unix::fs::symlink(link, output)?;
        } else if item.file_type()?.is_file() {
            std::fs::write(output, recolor(&std::fs::read(path)?, color, &mut cache)?)?;
        }
    }
    std::fs::write(
        pending.join("index.theme"),
        format!(
            "[Icon Theme]\nName={name}\nComment=Wallpaper-colored ArcStarry cursors\nInherits=ArcStarry-Purple\n"
        ),
    )?;
    std::fs::write(pending.join(".wallpaper-generated"), format!("{color}\n"))?;
    std::fs::rename(pending, &target)?;
    let mut previous = Vec::new();
    for item in std::fs::read_dir(icons)? {
        let item = item?;
        let path = item.path();
        if path != target
            && item.file_name().to_string_lossy().starts_with(PREFIX)
            && item.file_type()?.is_dir()
            && path.join(".wallpaper-generated").is_file()
        {
            previous.push((item.metadata()?.modified()?, path));
        }
    }
    previous.sort_by_key(|item| std::cmp::Reverse(item.0));
    for (_, path) in previous.into_iter().skip(7) {
        std::fs::remove_dir_all(path)?;
    }
    Ok(name)
}
fn palette_accent(path: &Path) -> Result<String> {
    let content = std::fs::read_to_string(path)?;
    let mut section = "";
    let mut values = HashMap::new();
    for line in content
        .lines()
        .map(str::trim)
        .filter(|l| !l.starts_with(['#', ';']) && !l.is_empty())
    {
        if line.starts_with('[') && line.ends_with(']') {
            section = &line[1..line.len() - 1];
        } else if let Some((key, value)) = line.split_once('=') {
            values.insert((section, key.trim()), value.trim());
        } else {
            return Err("invalid palette INI".into());
        }
    }
    let mode = values
        .get(&("main", "initial-color-theme"))
        .copied()
        .unwrap_or("dark");
    let section = format!("colors-{mode}");
    let color = values
        .get(&(section.as_str(), "cursor"))
        .and_then(|v| v.split_whitespace().last())
        .ok_or("missing cursor accent")?
        .to_lowercase();
    accent(&color)?;
    Ok(color)
}
fn run() -> Result {
    let args: Vec<_> = std::env::args().skip(1).collect();
    let usage = "Usage: wallpaper-cursor --source DIR --state DIR --icons DIR --size PIXELS --dconf PATH --systemctl PATH";
    if args == ["--help"] {
        println!("{usage}");
        return Ok(());
    }
    if args.len() != 12 {
        return Err(usage.into());
    }
    let mut options = HashMap::new();
    for pair in args.chunks_exact(2) {
        if ![
            "--source",
            "--state",
            "--icons",
            "--size",
            "--dconf",
            "--systemctl",
        ]
        .contains(&pair[0].as_str())
            || options.insert(pair[0].as_str(), pair[1].as_str()).is_some()
        {
            return Err(usage.into());
        }
    }
    let source = Path::new(options["--source"]);
    let state = Path::new(options["--state"]);
    let icons = Path::new(options["--icons"]);
    let size: u32 = options["--size"].parse()?;
    if size == 0 {
        return Err("cursor size must be positive".into());
    }
    let mut last = String::new();
    let palette = state.join("terminal-colors-foot.ini");
    // Subscribe before the initial read, so a concurrent rename is not lost.
    let mut watch = nixy_tools::file_watch::FileWatch::new(&palette)?;
    loop {
        let result = (|| -> Result {
            let color = palette_accent(&palette)?;
            if color != last {
                let name = generate(source, icons, &color)?;
                atomic_write(
                    &state.join("niri-cursor.kdl"),
                    format!(
                        "// Generated from the wallpaper palette.\ncursor {{\n    xcursor-theme \"{name}\"\n    xcursor-size {size}\n}}\n"
                    ),
                )?;
                checked(Command::new(options["--dconf"]).args([
                    "write",
                    "/org/gnome/desktop/interface/cursor-theme",
                    &format!("'{name}'"),
                ]))?;
                checked(Command::new(options["--dconf"]).args([
                    "write",
                    "/org/gnome/desktop/interface/cursor-size",
                    &size.to_string(),
                ]))?;
                checked(Command::new(options["--systemctl"]).args([
                    "--user",
                    "set-environment",
                    &format!("XCURSOR_THEME={name}"),
                    &format!("XCURSOR_SIZE={size}"),
                ]))?;
                last = color;
            }
            Ok(())
        })();
        // Let systemd retry transient generation/dconf failures. A successful
        // run waits indefinitely for the next palette event.
        result?;
        watch.wait(palette.file_name().unwrap())?;
    }
}
fn main() {
    nixy_tools::main_result(run());
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture() -> Vec<u8> {
        let mut words = vec![MAGIC, 16, 0x10000, 2, IMAGE, 24, 40, IMAGE, 24, 92];
        for delay in [50, 100] {
            words.extend([
                36, IMAGE, 24, 1, 2, 2, 1, 0, delay, 0xffc090e8, 0x80604874, 0xffffffff, 0xff000000,
            ]);
        }
        words.into_iter().flat_map(u32::to_le_bytes).collect()
    }
    #[test]
    fn preserves_animation_geometry_alpha_neutrals_and_premultiplication() -> Result {
        let original = fixture();
        let changed = recolor(&original, "55ddaa", &mut HashMap::new())?;
        assert_eq!(&changed[..40], &original[..40]);
        for start in [40, 92] {
            assert_eq!(&changed[start..start + 36], &original[start..start + 36]);
            for i in 0..4 {
                let before = word(&original, start + 36 + i * 4)?;
                let after = word(&changed, start + 36 + i * 4)?;
                assert_eq!(before >> 24, after >> 24);
                assert!(
                    [16, 8, 0]
                        .iter()
                        .all(|s| ((after >> s) & 255) <= after >> 24)
                );
                if i >= 2 {
                    assert_eq!(before, after);
                } else {
                    assert_ne!(before, after);
                }
            }
        }
        assert_ne!(
            recolor(&original, "dd5566", &mut HashMap::new())?,
            recolor(&original, "5599dd", &mut HashMap::new())?
        );
        Ok(())
    }
    #[test]
    fn rejects_truncation_and_overflow() {
        for bytes in [vec![], b"not a cursor".repeat(5), fixture()[..143].to_vec()] {
            assert!(recolor(&bytes, "5599dd", &mut HashMap::new()).is_err());
        }
        let mut bytes = fixture();
        bytes[56..60].copy_from_slice(&u32::MAX.to_le_bytes());
        bytes[60..64].copy_from_slice(&u32::MAX.to_le_bytes());
        assert!(recolor(&bytes, "5599dd", &mut HashMap::new()).is_err());
    }
    #[test]
    fn cache_is_complete_bounded_and_preserves_user_themes_and_aliases() -> Result {
        let root = tempfile::tempdir()?;
        let source = root.path().join("source");
        let icons = root.path().join("icons");
        std::fs::create_dir_all(source.join("cursors"))?;
        std::fs::write(source.join("cursors/left_ptr"), fixture())?;
        std::os::unix::fs::symlink("left_ptr", source.join("cursors/default"))?;
        let name = generate(&source, &icons, "5599dd")?;
        assert_eq!(generate(&source, &icons, "5599dd")?, name);
        assert!(icons.join(&name).join("index.theme").is_file());
        assert_eq!(
            std::fs::read(icons.join(&name).join("cursors/default"))?,
            std::fs::read(icons.join(&name).join("cursors/left_ptr"))?
        );
        let user = icons.join(format!("{PREFIX}user-owned"));
        std::fs::create_dir(&user)?;
        for i in 0..12 {
            generate(&source, &icons, &format!("55{i:02x}dd"))?;
        }
        assert!(user.exists());
        assert_eq!(
            std::fs::read_dir(&icons)?
                .filter_map(|i| i.ok())
                .filter(|i| i.path().join(".wallpaper-generated").is_file())
                .count(),
            8
        );
        assert_eq!(std::fs::read(source.join("cursors/left_ptr"))?, fixture());
        std::os::unix::fs::symlink("../escape", source.join("cursors/bad"))?;
        assert!(generate(&source, &icons, "123456").is_err());
        Ok(())
    }
    #[test]
    fn reads_active_palette_and_validates_color() -> Result {
        let root = tempfile::tempdir()?;
        let path = root.path().join("palette.ini");
        std::fs::write(
            &path,
            "[main]\ninitial-color-theme=light\n[colors-light]\ncursor=ffffff 1188dd\n[colors-dark]\ncursor=000000 ff3355\n",
        )?;
        assert_eq!(palette_accent(&path)?, "1188dd");
        std::fs::write(&path, "[colors-dark]\ncursor=000000 invalid\n")?;
        assert!(palette_accent(&path).is_err());
        Ok(())
    }
}
