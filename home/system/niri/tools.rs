use nixy_tools::{Result, checked};
use regex::Regex;
use serde_json::{Value, json};
use std::{
    io::{BufRead, Write},
    os::unix::{net::UnixStream, process::CommandExt},
    process::{Command, Stdio},
    time::Duration,
};

const EXCLUDED: &[&str] = &[
    "help",
    "spawn",
    "spawn-sh",
    "do-screen-transition",
    "toggle-debug-tint",
    "debug-toggle-opaque-regions",
    "debug-toggle-damage",
    "toggle-window-urgent",
    "set-window-urgent",
    "unset-window-urgent",
    "set-workspace-name",
    "unset-workspace-name",
];
fn read(args: &[&str]) -> Result<String> {
    checked(Command::new("niri").arg("msg").args(args))
}
fn data(command: &str) -> Result<Value> {
    Ok(serde_json::from_str(&read(&["--json", command])?)?)
}
fn array(value: &Value) -> Result<&Vec<Value>> {
    value.as_array().ok_or_else(|| "invalid Niri array".into())
}
fn display(value: &Value) -> String {
    match value {
        Value::Null => String::new(),
        Value::String(s) => s.clone(),
        _ => value.to_string(),
    }
}
fn ipc_action(name: &str, parameters: Value) -> Result {
    let mut connection =
        UnixStream::connect(std::env::var_os("NIRI_SOCKET").ok_or("NIRI_SOCKET is not set")?)?;
    connection.set_read_timeout(Some(Duration::from_secs(5)))?;
    connection.set_write_timeout(Some(Duration::from_secs(5)))?;
    writeln!(connection, "{}", json!({"Action": {name: parameters}}))?;
    let mut reply = String::new();
    std::io::BufReader::new(connection).read_line(&mut reply)?;
    let reply: Value = serde_json::from_str(&reply)?;
    if let Some(error) = reply.get("Err") {
        return Err(display(error).into());
    }
    Ok(())
}
fn catalog() -> Result<Vec<(String, String)>> {
    let help = read(&["action", "--help"])?;
    let lines: Vec<_> = help.lines().collect();
    let pattern = Regex::new(r"^  [a-z][a-z-]+$")?;
    Ok(lines
        .windows(2)
        .filter(|pair| pattern.is_match(pair[0]) && !EXCLUDED.contains(&pair[0].trim()))
        .map(|pair| (pair[0].trim().into(), pair[1].trim().into()))
        .collect())
}
fn choose(rows: Vec<(String, String)>, prompt: &str) -> Result<Option<String>> {
    if rows.is_empty() {
        return Err("There are no available targets.".into());
    }
    let input = rows
        .into_iter()
        .map(|(key, label)| {
            format!(
                "{key}\t{}",
                label.split_whitespace().collect::<Vec<_>>().join(" ")
            )
        })
        .collect::<Vec<_>>()
        .join("\n");
    let mut child = Command::new("fzf")
        .args([
            "--layout=reverse",
            "--border",
            "--no-sort",
            "--delimiter=\t",
            "--with-nth=2..",
            "--prompt",
            &format!("{prompt} > "),
            "--header",
            "Type to search · Enter to choose · Esc to cancel",
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()?;
    // Write on another thread: a large window list must not block the menu.
    let mut stdin = child.stdin.take().unwrap();
    let writer = std::thread::spawn(move || stdin.write_all(input.as_bytes()));
    let output = child.wait_with_output()?;
    let _ = writer.join();
    if !output.status.success() {
        return Ok(None);
    }
    Ok(Some(
        String::from_utf8(output.stdout)?
            .trim_end_matches('\n')
            .split('\t')
            .next()
            .unwrap_or("")
            .to_string(),
    ))
}
fn ask(prompt: &str, pattern: &str) -> Result<Option<String>> {
    print!("{prompt} (blank cancels): ");
    std::io::stdout().flush()?;
    let mut value = String::new();
    std::io::stdin().read_line(&mut value)?;
    let value = value.trim();
    if value.is_empty() {
        return Ok(None);
    }
    if !Regex::new(&format!("^(?:{pattern})$"))?.is_match(value) {
        return Err("That value is not valid.".into());
    }
    Ok(Some(value.into()))
}
fn pick(rows: &[(&str, &str)], prompt: &str) -> Result<Option<Vec<String>>> {
    Ok(choose(
        rows.iter()
            .map(|(a, b)| (a.to_string(), b.to_string()))
            .collect(),
        prompt,
    )?
    .map(|v| vec![v]))
}
fn action_args(action: &str) -> Result<Option<Vec<String>>> {
    match action {
        "focus-window" => Ok(choose(
            array(&data("windows")?)?
                .iter()
                .filter(|w| w["app_id"] != "niri-tools")
                .map(|w| {
                    (
                        display(&w["id"]),
                        format!("{}: {}", display(&w["app_id"]), display(&w["title"])),
                    )
                })
                .collect(),
            "Window",
        )?
        .map(|v| vec!["--id".into(), v])),
        "focus-monitor"
        | "move-window-to-monitor"
        | "move-column-to-monitor"
        | "move-workspace-to-monitor" => Ok(choose(
            data("outputs")?
                .as_object()
                .ok_or("invalid outputs")?
                .keys()
                .map(|name| (name.clone(), name.clone()))
                .collect(),
            "Monitor",
        )?
        .map(|v| vec![v])),
        "focus-workspace" | "move-window-to-workspace" | "move-column-to-workspace" => Ok(choose(
            array(&data("workspaces")?)?
                .iter()
                .map(|w| {
                    (
                        display(&w["id"]),
                        format!(
                            "{} · {}",
                            display(if w["name"].is_null() {
                                &w["idx"]
                            } else {
                                &w["name"]
                            }),
                            display(&w["output"])
                        ),
                    )
                })
                .collect(),
            "Workspace",
        )?
        .map(|v| vec![v])),
        "focus-column"
        | "focus-window-in-column"
        | "move-column-to-index"
        | "move-workspace-to-index" => {
            Ok(ask("Position (starting from 1)", r"[1-9][0-9]*")?.map(|v| vec![v]))
        }
        "set-column-width" | "set-window-width" | "set-window-height" => Ok(ask(
            "Size: pixels, percentage, or adjustment (e.g. 800, 50%, -10%)",
            r"[+-]?[0-9]+(?:\.[0-9]+)?%?",
        )?
        .map(|v| vec!["--".into(), v])),
        "set-column-display" => pick(
            &[("normal", "Stacked windows"), ("tabbed", "Tabbed windows")],
            "Column layout",
        ),
        "switch-layout" => pick(
            &[
                ("next", "Next keyboard layout"),
                ("prev", "Previous keyboard layout"),
            ],
            "Keyboard layout",
        ),
        "move-floating-window" => {
            let Some(x) = ask(
                "Horizontal position or adjustment (e.g. 100, +40, -40)",
                r"[+-]?[0-9]+",
            )?
            else {
                return Ok(None);
            };
            Ok(ask(
                "Vertical position or adjustment (e.g. 100, +40, -40)",
                r"[+-]?[0-9]+",
            )?
            .map(|y| vec![format!("--x={x}"), format!("--y={y}")]))
        }
        "stop-cast" => {
            let mut sessions = std::collections::BTreeMap::new();
            for cast in array(&data("casts")?)? {
                let id = display(&cast["session_id"]);
                sessions.insert(
                    id.clone(),
                    format!("Sharing session {id} · {}", display(&cast["target"])),
                );
            }
            Ok(
                choose(sessions.into_iter().collect(), "Stop screen sharing")?
                    .map(|v| vec!["--session-id".into(), v]),
            )
        }
        _ => Ok(Some(vec![])),
    }
}
fn context() -> Result<Value> {
    Ok(serde_json::from_str(
        &std::env::var("NIRI_TOOL_CONTEXT").unwrap_or_else(|_| "{}".into()),
    )?)
}
fn restore_context(context: &Value) -> Result {
    if let Some(id) = context["window"]["id"].as_u64()
        && array(&data("windows")?)?.iter().any(|w| w["id"] == id)
    {
        read(&["action", "focus-window", "--id", &id.to_string()])?;
        return Ok(());
    }
    if let Some(id) = context["workspace"]["id"].as_u64()
        && array(&data("workspaces")?)?.iter().any(|w| w["id"] == id)
    {
        ipc_action("FocusWorkspace", json!({"reference": {"Id": id}}))?;
        return Ok(());
    }
    Err("The original window or workspace is no longer available.".into())
}
fn shortcut_rows(config: &str) -> Result<Vec<String>> {
    let binding = Regex::new(r"^\s*(\S+)\s+([^{}]*?)\{\s*(.*?)\s*;\s*\}")?;
    let title = Regex::new(r#"hotkey-overlay-title="([^"]+)""#)?;
    let store = Regex::new(r"/nix/store/[^/]+/bin/")?;
    let mut rows = Vec::new();
    for line in config.lines() {
        let Some(capture) = binding.captures(line) else {
            continue;
        };
        let key = &capture[1];
        if !key.contains('+') && key != "Print" && !key.starts_with("XF86") {
            continue;
        }
        let action = &capture[3];
        let label = if let Some(title) = title.captures(&capture[2]) {
            title[1].to_string()
        } else if let Some(spawn) = action.strip_prefix("spawn ") {
            store.replace_all(spawn, "").to_string()
        } else {
            let (verb, args) = action.split_once(' ').unwrap_or((action, ""));
            format!("{} {}", verb.replace('-', " "), args.replace('"', ""))
        };
        rows.push(format!("{:<34} {label}", key.replace("Mod+", "Super+")));
    }
    rows.extend([
        "Super + left mouse drag            Move window".into(),
        "Super + right mouse drag           Resize window".into(),
    ]);
    Ok(rows)
}
fn shortcuts() -> Result<Vec<String>> {
    let config = std::env::var_os("XDG_CONFIG_HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or(
            std::path::PathBuf::from(std::env::var_os("HOME").ok_or("HOME is not set")?)
                .join(".config"),
        );
    shortcut_rows(&std::fs::read_to_string(config.join("niri/config.kdl"))?)
}
fn execute_action(action: &str, mut parameters: Vec<String>, context: &Value) -> Result {
    let window = &context["window"];
    if window.is_null()
        && (action.contains("window") || action.contains("column"))
        && !action.starts_with("focus-")
    {
        return Err("There was no focused window when the menu opened.".into());
    }
    if matches!(
        action,
        "focus-workspace" | "move-window-to-workspace" | "move-column-to-workspace"
    ) {
        let mut fields = json!({"reference": {"Id": parameters.first().ok_or("missing workspace ID")?.parse::<u64>()?}});
        if action != "focus-workspace" {
            fields["focus"] = true.into();
        }
        if action == "move-window-to-workspace" {
            fields["window_id"] = window["id"].clone();
        }
        let name = action
            .split('-')
            .map(|s| format!("{}{}", s[..1].to_uppercase(), &s[1..]))
            .collect::<String>();
        return ipc_action(&name, fields);
    }
    if !window.is_null() && action != "focus-window" {
        let help = read(&["action", action, "--help"])?;
        let flag = if help.contains("--id <ID>") {
            Some("--id")
        } else if help.contains("--window-id <WINDOW_ID>") {
            Some("--window-id")
        } else {
            None
        };
        if let Some(flag) = flag {
            parameters.splice(0..0, [flag.into(), display(&window["id"])]);
        }
    }
    checked(
        Command::new("niri")
            .args(["msg", "action", action])
            .args(parameters),
    )?;
    Ok(())
}
fn run() -> Result {
    let usage = "Usage: niri-tools shortcuts|actions [--list] [--action ACTION] [--inside]";
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args == ["--help"] {
        println!("{usage}");
        return Ok(());
    }
    let mode = args
        .first()
        .filter(|v| matches!(v.as_str(), "shortcuts" | "actions"))
        .ok_or(usage)?;
    let (mut inside, mut list, mut action) = (false, false, None);
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--inside" => inside = true,
            "--list" => list = true,
            "--action" => {
                i += 1;
                action = Some(args.get(i).ok_or(usage)?.clone());
            }
            _ => return Err(usage.into()),
        }
        i += 1;
    }
    if mode == "shortcuts" && action.is_some() {
        return Err("--action requires actions mode".into());
    }
    if list {
        if mode == "shortcuts" {
            println!("{}", shortcuts()?.join("\n"));
        } else {
            for (key, label) in catalog()? {
                println!("{key}\t{label}");
            }
        }
        return Ok(());
    }
    if !inside {
        let workspaces = data("workspaces")?;
        let context = json!({"window": data("focused-window")?, "workspace": array(&workspaces)?.iter().find(|w| w["is_focused"] == true)});
        let mut command = Command::new("foot");
        command
            .args(["--app-id=niri-tools", &format!("--title=Niri {mode}"), "--"])
            .arg(std::env::current_exe()?)
            .args([mode, "--inside"])
            .env("NIRI_TOOL_CONTEXT", context.to_string());
        if let Some(action) = action {
            command.args(["--action", &action]);
        }
        return Err(command.exec().into());
    }
    if mode == "shortcuts" {
        let mut child = Command::new("fzf")
            .args([
                "--layout=reverse",
                "--border",
                "--no-sort",
                "--prompt=Search shortcuts > ",
                "--bind=enter:ignore",
                "--header=Read-only reference · Esc to close",
            ])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .spawn()?;
        let mut stdin = child.stdin.take().unwrap();
        let rows = shortcuts()?.join("\n");
        let writer = std::thread::spawn(move || stdin.write_all(rows.as_bytes()));
        child.wait()?;
        let _ = writer.join();
        return Ok(());
    }
    let actions = catalog()?;
    let action = match action {
        Some(action) => action,
        None => {
            let Some(action) = choose(actions.clone(), "Niri action")? else {
                return Ok(());
            };
            action
        }
    };
    if !actions.iter().any(|(key, _)| *key == action) {
        return Err("Unknown action.".into());
    }
    let Some(parameters) = action_args(&action)? else {
        return Ok(());
    };
    let context = context()?;
    restore_context(&context)?;
    execute_action(&action, parameters, &context)
}
fn main() {
    if let Err(error) = run() {
        eprintln!("Could not complete the action: {error}");
        use std::io::IsTerminal;
        if std::env::args().any(|a| a == "--inside") && std::io::stdin().is_terminal() {
            let mut line = String::new();
            eprintln!("Press Enter to close.");
            let _ = std::io::stdin().read_line(&mut line);
        }
        std::process::exit(1);
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn shortcut_reference_preserves_titles_and_removes_store_hashes() -> Result {
        let rows = shortcut_rows(
            "Mod+F1 hotkey-overlay-title=\"Search all shortcuts\" { spawn \"ignored\"; }\nMod+Return { spawn \"/nix/store/hash-foot/bin/foot\"; }\nXF86AudioMute { spawn \"mute\"; }",
        )?;
        assert!(rows[0].contains("Super+F1"));
        assert!(rows[0].contains("Search all shortcuts"));
        assert!(!rows[1].contains("/nix/store"));
        assert!(rows[1].contains("foot"));
        assert_eq!(rows.len(), 5);
        Ok(())
    }
}
