use nixy_tools::{Result, output};
use serde_json::json;
use std::{
    path::{Path, PathBuf},
    process::Command,
    time::Duration,
};

#[derive(Default)]
struct Options {
    multiple: bool,
    directory: bool,
    save: bool,
    rejected: bool,
    cancel: bool,
    ui: bool,
    confirm: bool,
}
fn check(binary: &Path, root: &Path, name: &str, paths: &[PathBuf], options: Options) -> Result {
    let selection = root.join("selection");
    std::fs::write(&selection, "")?;
    let probe = root.join("probe.qml");
    let mut setup = String::new();
    let mut action = if options.cancel {
        "Qt.quit();".into()
    } else {
        format!(
            "var error = native.acceptChoice({}); console.log('CHOOSER_RESULT=' + JSON.stringify(error)); Qt.quit();",
            json!(paths)
        )
    };
    if options.ui {
        setup = r#"property var picker
Component.onCompleted: {
    var component = Qt.createComponent("qrc:/qt/qml/app/loaf/qml/main.qml");
    if (component.status !== Component.Ready) { console.error(component.errorString()); Qt.quit(); return; }
    picker = component.createObject(null);
}"#.into();
        action = "if (!picker || !picker.chooser.enabled) throw new Error('Picker window failed to load'); console.log('CHOOSER_RESULT=\"\"');".into();
        if options.cancel {
            action.push_str("picker.close(); Qt.quit();");
        } else {
            action.push_str(&format!(
                "picker.activePane.selectPaths({}); picker.acceptChoice();",
                json!(paths)
            ));
        }
        if options.confirm {
            action.push_str("if (!picker.anyModalOpen) throw new Error('Overwrite confirmation did not open'); picker.close(); Qt.quit();");
        }
    }
    std::fs::write(
        &probe,
        format!(
            "import QtQuick\nItem {{\n{setup}\nTimer {{ interval: 1000; running: true; onTriggered: {{ {action} }} }}\n}}\n"
        ),
    )?;
    let result = output(
        Command::new(binary)
            .arg("--new-window")
            .arg(root)
            .env("QT_QPA_PLATFORM", "offscreen")
            .env("QT_QUICK_BACKEND", "software")
            .env("QT_FORCE_STDERR_LOGGING", "1")
            .env("XDG_CONFIG_HOME", root.join("config"))
            .env("XDG_CACHE_HOME", root.join("cache"))
            .env("XDG_DATA_HOME", root.join("data"))
            .env("LOAF_QML", &probe)
            .env("LOAF_VERBOSE", "1")
            .env("LOAF_CHOOSER_OUTPUT", &selection)
            .env(
                "LOAF_CHOOSER_MULTIPLE",
                if options.multiple { "1" } else { "0" },
            )
            .env(
                "LOAF_CHOOSER_DIRECTORY",
                if options.directory { "1" } else { "0" },
            )
            .env("LOAF_CHOOSER_SAVE", if options.save { "1" } else { "0" })
            .env(
                "LOAF_CHOOSER_NAME",
                if options.save {
                    paths
                        .first()
                        .and_then(|p| p.file_name())
                        .unwrap_or_default()
                } else {
                    std::ffi::OsStr::new("")
                },
            ),
        None,
        Duration::from_secs(20),
    )?;
    let stderr = String::from_utf8_lossy(&result.stderr);
    assert!(result.status.success(), "{name}: {stderr}");
    if !options.cancel {
        assert_eq!(
            !stderr.contains("CHOOSER_RESULT=\"\""),
            options.rejected,
            "{name}: {stderr}"
        );
        assert!(stderr.contains("CHOOSER_RESULT="), "{name}: {stderr}");
    }
    let expected = if options.rejected || options.cancel || options.confirm {
        String::new()
    } else {
        paths.iter().map(|p| format!("{}\n", p.display())).collect()
    };
    assert_eq!(std::fs::read_to_string(selection)?, expected, "{name}");
    println!("PASS: {name}");
    Ok(())
}
fn run() -> Result {
    let args: Vec<_> = std::env::args_os().skip(1).collect();
    if args.len() == 1 && args[0] == "--help" {
        println!("Usage: test-loaf-chooser /path/to/loaf");
        return Ok(());
    }
    if args.len() != 1 {
        return Err("Usage: test-loaf-chooser /path/to/loaf".into());
    }
    let binary = std::fs::canonicalize(&args[0])?;
    let dir = tempfile::tempdir()?;
    let root = dir.path();
    let first = root.join("žluťoučký file's name.txt");
    let second = root.join("second.txt");
    let folder = root.join("folder");
    std::fs::write(&first, "original content")?;
    std::fs::write(&second, "original content")?;
    std::fs::create_dir(&folder)?;
    let d = Options::default;
    check(
        &binary,
        root,
        "single file with spaces, quotes and Czech text",
        std::slice::from_ref(&first),
        d(),
    )?;
    check(
        &binary,
        root,
        "multiple files",
        &[first.clone(), second.clone()],
        Options {
            multiple: true,
            ..d()
        },
    )?;
    check(
        &binary,
        root,
        "single mode rejects multiple files",
        &[first.clone(), second.clone()],
        Options {
            rejected: true,
            ..d()
        },
    )?;
    check(
        &binary,
        root,
        "directory",
        std::slice::from_ref(&folder),
        Options {
            directory: true,
            ..d()
        },
    )?;
    check(
        &binary,
        root,
        "file mode rejects directory",
        std::slice::from_ref(&folder),
        Options {
            rejected: true,
            ..d()
        },
    )?;
    check(
        &binary,
        root,
        "directory mode rejects file",
        std::slice::from_ref(&first),
        Options {
            directory: true,
            rejected: true,
            ..d()
        },
    )?;
    for (name, path, save) in [
        ("missing file", root.join("missing"), false),
        ("relative path", "relative".into(), false),
        ("line breaks", root.join("bad\nname"), true),
        ("save missing parent", root.join("missing/file"), true),
    ] {
        check(
            &binary,
            root,
            name,
            &[path],
            Options {
                save,
                rejected: true,
                ..d()
            },
        )?;
    }
    let destination = root.join("new file.txt");
    check(
        &binary,
        root,
        "save new file",
        std::slice::from_ref(&destination),
        Options { save: true, ..d() },
    )?;
    assert!(!destination.exists());
    check(
        &binary,
        root,
        "save existing file",
        std::slice::from_ref(&first),
        Options { save: true, ..d() },
    )?;
    check(
        &binary,
        root,
        "cancel",
        &[],
        Options {
            cancel: true,
            ..d()
        },
    )?;
    check(
        &binary,
        root,
        "picker UI: single file",
        std::slice::from_ref(&first),
        Options { ui: true, ..d() },
    )?;
    check(
        &binary,
        root,
        "picker UI: multiple files",
        &[first.clone(), second],
        Options {
            ui: true,
            multiple: true,
            ..d()
        },
    )?;
    for (name, path) in [
        ("picker UI: folder", &folder),
        ("picker UI: current folder", &root.to_path_buf()),
    ] {
        check(
            &binary,
            root,
            name,
            std::slice::from_ref(path),
            Options {
                ui: true,
                directory: true,
                ..d()
            },
        )?;
    }
    check(
        &binary,
        root,
        "picker UI: save new file",
        std::slice::from_ref(&destination),
        Options {
            ui: true,
            save: true,
            ..d()
        },
    )?;
    assert!(!destination.exists());
    check(
        &binary,
        root,
        "picker UI: overwrite confirmation",
        std::slice::from_ref(&first),
        Options {
            ui: true,
            save: true,
            confirm: true,
            ..d()
        },
    )?;
    check(
        &binary,
        root,
        "picker UI: cancel",
        &[],
        Options {
            ui: true,
            cancel: true,
            ..d()
        },
    )?;
    assert_eq!(std::fs::read_to_string(first)?, "original content");
    Ok(())
}
fn main() {
    nixy_tools::main_result(run());
}
