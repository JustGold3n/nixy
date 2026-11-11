use nixy_tools::{Result, output};
use serde_json::{Value, json};
use std::{
    collections::HashSet,
    path::Path,
    process::{Child, Command, Stdio},
    time::Duration,
};

const DESTINATION: &str = "org.freedesktop.impl.portal.desktop.termfilechooser";
const OBJECT: &str = "/org/freedesktop/portal/desktop";
struct Backend(Child);
impl Drop for Backend {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}
fn picker(args: &[std::ffi::OsString]) -> Result {
    use std::os::unix::fs::MetadataExt;
    let control: Value = serde_json::from_slice(&std::fs::read(
        std::env::var_os("PORTAL_TEST_CONTROL").ok_or("missing control")?,
    )?)?;
    let path = Path::new(args.get(5).ok_or("picker needs output argument")?);
    let info = path.metadata()?;
    std::fs::write(
        std::env::var_os("PORTAL_TEST_RECORD").ok_or("missing record")?,
        serde_json::to_vec(
            &json!({"output": path, "mode": info.mode(), "uid": info.uid(), "args": args[1..].iter().map(|a| a.to_string_lossy()).collect::<Vec<_>>(), "empty": std::fs::read(path)?.is_empty()}),
        )?,
    )?;
    let paths = control["paths"].as_array().ok_or("invalid control")?;
    std::fs::write(
        path,
        paths
            .iter()
            .map(|p| format!("{}\n", p.as_str().unwrap()))
            .collect::<String>(),
    )?;
    std::process::exit(control["exit"].as_i64().unwrap_or(0) as i32);
}
struct Fixture<'a> {
    root: &'a Path,
    gdbus: &'a str,
    seen: HashSet<String>,
}
impl Fixture<'_> {
    fn command(&self) -> Command {
        let mut command = Command::new(self.gdbus);
        command.args([
            "call",
            "--session",
            "--dest",
            DESTINATION,
            "--object-path",
            OBJECT,
            "--method",
        ]);
        command
    }
    fn call(
        &mut self,
        name: &str,
        method: &str,
        paths: &[&Path],
        options: &str,
        exit: i32,
    ) -> Result<Value> {
        std::fs::write(
            self.root.join("control.json"),
            serde_json::to_vec(&json!({"paths": paths, "exit": exit}))?,
        )?;
        let result = output(
            self.command()
                .arg(format!("org.freedesktop.impl.portal.FileChooser.{method}"))
                .args([
                    "/org/freedesktop/portal/desktop/request/test/security",
                    "test.security",
                    "",
                    name,
                    options,
                ]),
            None,
            Duration::from_secs(10),
        )?;
        let observed: Value =
            serde_json::from_slice(&std::fs::read(self.root.join("record.json"))?)?;
        let path = Path::new(observed["output"].as_str().ok_or("missing output")?);
        assert!(
            path.file_name()
                .unwrap()
                .to_string_lossy()
                .starts_with("termfilechooser-")
        );
        assert_ne!(
            path.file_name().unwrap(),
            std::ffi::OsStr::new(&format!("termfilechooser-{}.portal", unsafe {
                libc::getuid()
            }))
        );
        assert!(
            self.seen.insert(path.to_string_lossy().into_owned()),
            "requests reused a result file"
        );
        assert_eq!(observed["empty"], true);
        assert_eq!(observed["mode"].as_u64().unwrap() & 0o777, 0o600);
        assert_eq!(observed["uid"], unsafe { libc::getuid() });
        assert!(!path.exists(), "result file leaked");
        let stdout = String::from_utf8_lossy(&result.stdout);
        if exit != 0 {
            assert!(!result.status.success() || !stdout.starts_with("(uint32 0,"));
        } else {
            assert!(
                result.status.success(),
                "{}",
                String::from_utf8_lossy(&result.stderr)
            );
            assert!(
                stdout.starts_with(&format!(
                    "(uint32 {},",
                    if paths.is_empty() { 1 } else { 0 }
                )),
                "{stdout}"
            );
            for path in paths {
                assert!(stdout.contains(&uri(path)), "{stdout}");
            }
        }
        println!("PASS: {name}");
        Ok(observed)
    }
}
fn uri(path: &Path) -> String {
    use std::os::unix::ffi::OsStrExt;
    let mut result = "file://".to_owned();
    for byte in path.as_os_str().as_bytes() {
        if byte.is_ascii_alphanumeric() || b"/._~-".contains(byte) {
            result.push(*byte as char);
        } else {
            result.push_str(&format!("%{byte:02X}"));
        }
    }
    result
}
fn run() -> Result {
    let args: Vec<_> = std::env::args_os().collect();
    if Path::new(&args[0])
        .file_name()
        .is_some_and(|s| s == "picker")
    {
        return picker(&args);
    }
    let usage = "Usage: dbus-run-session -- test-termfilechooser --backend PATH [--gdbus PATH]";
    if args.len() == 2 && args[1] == "--help" {
        println!("{usage}");
        return Ok(());
    }
    let mut backend = None;
    let mut gdbus = "gdbus".to_string();
    let mut index = 1;
    while index < args.len() {
        match args[index].to_str() {
            Some("--backend") => {
                index += 1;
                backend = Some(std::fs::canonicalize(args.get(index).ok_or(usage)?)?);
            }
            Some("--gdbus") => {
                index += 1;
                gdbus = args.get(index).ok_or(usage)?.to_str().ok_or(usage)?.into();
            }
            _ => return Err(usage.into()),
        }
        index += 1;
    }
    let backend = backend.ok_or(usage)?;
    let temporary = tempfile::tempdir()?;
    let root = temporary.path();
    let picker = root.join("picker");
    std::os::unix::fs::symlink(std::env::current_exe()?, &picker)?;
    let config = root.join("config");
    std::fs::write(
        &config,
        format!(
            "[filechooser]\ncmd={}\ndefault_dir={}\nopen_mode=suggested\nsave_mode=suggested\ncreate_help_file=0\n",
            picker.display(),
            root.display()
        ),
    )?;
    let log = std::fs::File::create(root.join("backend.log"))?;
    let mut backend = Backend(
        Command::new(backend)
            .arg("-c")
            .arg(config)
            .current_dir(root)
            .env("XDG_CONFIG_HOME", root.join("xdg-config"))
            .env("XDG_STATE_HOME", root.join("state"))
            .env("PORTAL_TEST_CONTROL", root.join("control.json"))
            .env("PORTAL_TEST_RECORD", root.join("record.json"))
            .stdout(Stdio::from(log.try_clone()?))
            .stderr(Stdio::from(log))
            .spawn()?,
    );
    let mut ready = false;
    for _ in 0..100 {
        if output(
            Command::new(&gdbus).args([
                "introspect",
                "--session",
                "--dest",
                DESTINATION,
                "--object-path",
                OBJECT,
            ]),
            None,
            Duration::from_secs(2),
        )?
        .status
        .success()
        {
            ready = true;
            break;
        }
        if backend.0.try_wait()?.is_some() {
            return Err(format!(
                "backend exited during startup: {}",
                std::fs::read_to_string(root.join("backend.log"))?
            )
            .into());
        }
        std::thread::sleep(Duration::from_millis(50));
    }
    if !ready {
        return Err("backend did not acquire its D-Bus name".into());
    }
    let mut fixture = Fixture {
        root,
        gdbus: &gdbus,
        seen: HashSet::new(),
    };
    let first = root.join("žluťoučký file's name.txt");
    let second = root.join("second.txt");
    std::fs::write(&first, "unchanged")?;
    std::fs::write(&second, "second")?;
    fixture.call("single", "OpenFile", &[&first], "{}", 0)?;
    fixture.call(
        "multiple",
        "OpenFile",
        &[&first, &second],
        "{'multiple': <true>}",
        0,
    )?;
    fixture.call("directory", "OpenFile", &[root], "{'directory': <true>}", 0)?;
    fixture.call("cancel", "OpenFile", &[], "{}", 0)?;
    let target = root.join("new.txt");
    let options = format!(
        "{{'current_folder': <b'{}'>, 'current_name': <'new.txt'>}}",
        root.display()
    );
    fixture.call("save", "SaveFile", &[&target], &options, 0)?;
    fixture.call("cancel save", "SaveFile", &[], &options, 0)?;
    fixture.call("picker error", "OpenFile", &[], "{}", 1)?;
    let name = "quote'$(touch INJECTION_MARKER);`touch INJECTION_MARKER`.txt";
    let path = root.join(name);
    let options = format!(
        "{{'current_folder': <b'{}'>, 'current_name': <{}>}}",
        root.display(),
        json!(name)
    );
    let observed = fixture.call(
        "literal shell metacharacters",
        "SaveFile",
        &[&path],
        &options,
        0,
    )?;
    assert_eq!(observed["args"][3], path.to_str().unwrap());
    assert!(!root.join("INJECTION_MARKER").exists());
    assert_eq!(std::fs::read_to_string(&first)?, "unchanged");
    assert!(!target.exists());
    Ok(())
}
fn main() {
    nixy_tools::main_result(run());
}
