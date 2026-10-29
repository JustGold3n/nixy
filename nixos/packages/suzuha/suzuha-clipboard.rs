use std::io::Write;
use std::process::{Command, Stdio};
use std::thread;

use amane::Service;

use super::results::{Entry, Kind};
use super::Overlay;

const CLIPHIST: &str = "@cliphist@";
const WL_COPY: &str = "@wlcopy@";

#[derive(Default)]
struct History {
    entries: Vec<Item>,
    generation: u64,
    loading: bool,
    copying: bool,
    error: Option<&'static str>,
}

struct Item {
    id: String,
    preview: String,
}

impl Service for History {
    fn new() -> Self {
        Self::default()
    }
}

pub fn refresh() {
    let generation = {
        let mut history = History::write();
        history.generation = history.generation.wrapping_add(1);
        history.entries.clear();
        history.error = None;
        history.loading = true;
        history.copying = false;
        history.generation
    };
    thread::spawn(move || {
        let result = list(Command::new(CLIPHIST));
        let mut history = History::write();
        if history.generation != generation {
            return;
        }
        history.loading = false;
        match result {
            Ok(entries) => history.entries = entries,
            Err(error) => history.error = Some(error),
        }
    });
}

pub fn find(query: &str) -> Vec<Entry> {
    let history = History::read();
    if history.loading || history.copying || history.error.is_some() {
        return Vec::new();
    }
    let search = query.trim().to_lowercase();
    history.entries.iter()
        .filter(|item| item.preview.to_lowercase().contains(&search))
        .map(|item| {
            let binary = item.preview.starts_with("[[ binary data");
            Entry {
                name: item.preview.clone(),
                description: Some(String::from(if binary {
                    "Image or file · Enter to copy"
                } else {
                    "Text · Enter to copy"
                })),
                glyph: Some(if binary { "\u{f021f}" } else { "\u{f014d}" }),
                kind: Kind::Clipboard(item.id.clone()),
            }
        })
        .collect()
}

pub fn empty_text() -> &'static str {
    let history = History::read();
    if history.loading {
        "Loading clipboard history…"
    } else if history.copying {
        "Restoring clipboard…"
    } else if let Some(error) = history.error {
        error
    } else if history.entries.is_empty() {
        "Your clipboard history is empty"
    } else {
        "No matching clipboard entries"
    }
}

pub fn copy(id: String) {
    let generation = {
        let mut history = History::write();
        if history.loading || history.copying {
            return;
        }
        history.copying = true;
        history.error = None;
        history.generation
    };
    thread::spawn(move || {
        let result = decode(Command::new(CLIPHIST), &id).and_then(|bytes| {
            // Keep raw bytes intact; wl-copy infers the MIME type for images.
            input(Command::new(WL_COPY), &bytes, false).map(|_| ())
                .map_err(|_| "Could not restore the clipboard. Reopen to retry.")
        });
        {
            let mut history = History::write();
            if history.generation != generation {
                return;
            }
            history.copying = false;
            history.error = result.err();
        }
        if result.is_ok() {
            // A completed worker must not close a newly opened app launcher.
            let mut overlay = Overlay::write();
            if overlay.clipboard_mode && History::read().generation == generation {
                overlay.launcher.hide();
            }
        }
    });
}

fn list(mut command: Command) -> Result<Vec<Item>, &'static str> {
    let output = command.arg("list").output()
        .map_err(|_| "Could not load clipboard history. Reopen to retry.")?;
    if !output.status.success() {
        // cliphist has no database until the first clipboard entry is stored.
        if String::from_utf8_lossy(&output.stderr).contains("please store something first") {
            return Ok(Vec::new());
        }
        return Err("Could not load clipboard history. Reopen to retry.");
    }
    Ok(String::from_utf8_lossy(&output.stdout).lines().filter_map(|line| {
        let (id, preview) = line.split_once('\t')?;
        if id.is_empty() || !id.bytes().all(|byte| byte.is_ascii_digit()) {
            return None;
        }
        Some(Item { id: id.to_owned(), preview: preview.to_owned() })
    }).collect())
}

fn decode(mut command: Command, id: &str) -> Result<Vec<u8>, &'static str> {
    command.arg("decode");
    // An ID alone must not have a trailing newline (cliphist parses it as-is).
    input(command, id.as_bytes(), true)
        .map_err(|_| "That entry is no longer available. Reopen the clipboard picker.")
}

fn input(mut command: Command, bytes: &[u8], capture: bool) -> Result<Vec<u8>, ()> {
    let mut child = command.stdin(Stdio::piped())
        .stdout(if capture { Stdio::piped() } else { Stdio::null() })
        .stderr(Stdio::null()).spawn().map_err(|_| ())?;
    let written = child.stdin.take().ok_or(())?.write_all(bytes);
    let output = child.wait_with_output().map_err(|_| ())?;
    if written.is_ok() && output.status.success() {
        Ok(output.stdout)
    } else {
        Err(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicUsize, Ordering};

    static NEXT: AtomicUsize = AtomicUsize::new(0);
    struct Database(PathBuf);
    impl Database {
        fn new() -> Self {
            let path = std::env::temp_dir().join(format!("amane-clipboard-{}-{}",
                std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed)));
            std::fs::create_dir(&path).unwrap();
            Self(path)
        }
        fn command(&self) -> Command {
            let mut command = Command::new(CLIPHIST);
            command.arg("-db-path").arg(self.0.join("db"));
            command
        }
        fn store(&self, bytes: &[u8]) {
            let mut command = self.command();
            command.arg("store");
            input(command, bytes, false).unwrap();
        }
    }
    impl Drop for Database {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn empty_history_and_missing_entry_are_handled() {
        let db = Database::new();
        assert!(list(db.command()).unwrap().is_empty());
        assert!(decode(db.command(), "999999").is_err());
    }

    #[test]
    fn duplicate_previews_keep_distinct_ids_and_exact_content() {
        let db = Database::new();
        let first = format!("{}first", "a".repeat(200));
        let second = format!("{}second", "a".repeat(200));
        db.store(first.as_bytes());
        db.store(second.as_bytes());
        let entries = list(db.command()).unwrap();
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].preview, entries[1].preview);
        assert_ne!(entries[0].id, entries[1].id);
        assert_eq!(decode(db.command(), &entries[0].id).unwrap(), second.as_bytes());
        assert_eq!(decode(db.command(), &entries[1].id).unwrap(), first.as_bytes());
    }

    #[test]
    fn unicode_whitespace_and_binary_data_round_trip() {
        let db = Database::new();
        for bytes in ["  Příliš žluťoučký\t🦋\n\n".as_bytes(), b"\x89PNG\r\n\x1a\n\0\xff\x80binary"] {
            db.store(bytes);
            let entries = list(db.command()).unwrap();
            assert_eq!(decode(db.command(), &entries[0].id).unwrap(), bytes);
        }
    }
}
