use nixy_tools::{Result, checked};
use serde_json::{Value, json};
use std::{path::Path, process::Command};

fn run() -> Result {
    let args: Vec<_> = std::env::args_os().collect();
    if Path::new(&args[0]).file_name().is_some_and(|s| s == "sudo") {
        std::fs::write(
            std::env::var_os("NIXY_TEST_RECORD").ok_or("missing test record")?,
            serde_json::to_vec(
                &args[1..]
                    .iter()
                    .map(|a| a.to_string_lossy())
                    .collect::<Vec<_>>(),
            )?,
        )?;
        std::process::exit(
            std::env::var("NIXY_TEST_STATUS")
                .unwrap_or("0".into())
                .parse()?,
        );
    }
    if args.len() == 2 && args[1] == "--help" {
        println!("Usage: test-nixy /path/to/nixy");
        return Ok(());
    }
    if args.len() != 2 {
        return Err("Usage: test-nixy /path/to/nixy".into());
    }
    let binary = std::fs::canonicalize(&args[1])?;
    let root = tempfile::tempdir()?;
    let root = root.path();
    let home = root.join("home with spaces '$(touch INJECTION_MARKER)");
    let repo = home.join(".config/nixos");
    std::fs::create_dir_all(&repo)?;
    checked(Command::new("git").args(["init", "-q"]).arg(&repo))?;
    std::fs::write(repo.join("tracked.nix"), "{}\n")?;
    checked(
        Command::new("git")
            .arg("-C")
            .arg(&repo)
            .args(["add", "tracked.nix"]),
    )?;
    std::fs::write(
        repo.join("local-secret.txt"),
        "test credential, not a real secret\n",
    )?;
    let before = std::fs::read(repo.join(".git/index"))?;
    let bin = root.join("bin");
    std::fs::create_dir(&bin)?;
    std::os::unix::fs::symlink(std::env::current_exe()?, bin.join("sudo"))?;
    let record = root.join("args.json");
    let path = format!("{}:{}", bin.display(), std::env::var("PATH")?);
    let command = || {
        let mut command = Command::new(&binary);
        command
            .current_dir(root)
            .env("HOME", &home)
            .env("PATH", &path)
            .env("NIXY_TEST_RECORD", &record);
        command
    };
    let extras = [
        "--option",
        "test-setting",
        "two words",
        "*",
        "",
        "$(touch INJECTION_MARKER)",
    ];
    for (action, expected) in [("test", "test"), ("rebuild", "switch")] {
        checked(command().arg(action).args(extras))?;
        let observed: Value = serde_json::from_slice(&std::fs::read(&record)?)?;
        assert_eq!(
            observed,
            json!([
                "env",
                "NIX_REMOTE=daemon",
                "nixos-rebuild",
                expected,
                "--flake",
                ".",
                "--option",
                "test-setting",
                "two words",
                "*",
                "",
                "$(touch INJECTION_MARKER)"
            ])
        );
        assert_eq!(
            std::fs::read(repo.join(".git/index"))?,
            before,
            "rebuild changed the Git index"
        );
        assert!(!root.join("INJECTION_MARKER").exists());
        assert!(!repo.join("INJECTION_MARKER").exists());
        println!("PASS: {action} preserves arguments and does not stage secrets");
    }
    assert_eq!(
        command()
            .arg("test")
            .env("NIXY_TEST_STATUS", "42")
            .status()?
            .code(),
        Some(42)
    );
    assert!(!command().arg("unknown").status()?.success());
    println!("PASS: command failures propagate");
    Ok(())
}
fn main() {
    nixy_tools::main_result(run());
}
