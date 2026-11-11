use nixy_tools::{
    Result,
    battery::{self, Secret},
};
use std::{
    fs::OpenOptions,
    io::Write,
    os::fd::AsRawFd,
    path::Path,
    process::{Command, Output, Stdio},
};

fn run(mode: &str) -> Result<i32> {
    battery::disable_core_dumps()?;
    let lock = OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .open(
            Path::new(&std::env::var_os("XDG_RUNTIME_DIR").ok_or("XDG_RUNTIME_DIR is not set")?)
                .join("battery-care.lock"),
        )?;
    if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
        let error = std::io::Error::last_os_error();
        if error.kind() == std::io::ErrorKind::WouldBlock {
            return Ok(75);
        }
        return Err(error.into());
    }
    if mode == "care" && battery::is_care(Path::new(battery::BATTERY))? {
        return Ok(0);
    }
    let zenity = option_env!("NIXY_ZENITY").unwrap_or("zenity");
    let helper = std::env::current_exe()?
        .parent()
        .ok_or("binary has no parent")?
        .join("battery-charge-firmware");
    dialog(
        mode,
        battery::protected(Path::new(battery::FIRMWARE))?,
        zenity,
        &helper,
        execute,
    )
}

fn execute(command: &mut Command, input: Option<&[u8]>) -> Result<Output> {
    if let Some(input) = input {
        let mut child = command
            .stdin(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;
        if let Err(error) = child.stdin.take().unwrap().write_all(input) {
            let _ = child.kill();
            let _ = child.wait();
            return Err(error.into());
        }
        Ok(child.wait_with_output()?)
    } else {
        Ok(command.output()?)
    }
}

fn dialog(
    mode: &str,
    protected: bool,
    zenity: &str,
    helper: &Path,
    mut execute: impl FnMut(&mut Command, Option<&[u8]>) -> Result<Output>,
) -> Result<i32> {
    let mut password = Secret(vec![b'\n']);
    if protected {
        let action = if mode == "care" {
            "Restore battery care (50–80%)."
        } else {
            "Allow charging to 100%."
        };
        let prompt = format!(
            "Enter your BIOS / UEFI administrator password.\nThis is the password used to unlock BIOS setup.\n\n{action}\nThe password will not be saved. Restoring battery care asks again."
        );
        let dialog = execute(
            Command::new(zenity).args([
                "--password",
                "--title=BIOS administrator password",
                &format!("--text={prompt}"),
            ]),
            None,
        )?;
        if !dialog.status.success() {
            return Ok(130);
        }
        password = Secret(dialog.stdout);
    }
    let result = execute(
        Command::new("/run/wrappers/bin/pkexec")
            .arg(helper)
            .arg(mode),
        Some(&password.0),
    )?;
    drop(password);
    if !result.status.success() {
        let error = String::from_utf8_lossy(&result.stderr);
        eprint!("{error}");
        execute(
            Command::new(zenity).args([
                "--error",
                "--title=Battery charging",
                &format!("--text={error}"),
            ]),
            None,
        )?;
    }
    Ok(result.status.code().unwrap_or(1))
}

fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args == ["--help"] {
        println!("Usage: battery-charge care|full");
        return;
    }
    if args.len() != 1 || !matches!(args[0].as_str(), "care" | "full") {
        eprintln!("Usage: battery-charge care|full");
        std::process::exit(2);
    }
    match run(&args[0]) {
        Ok(code) => std::process::exit(code),
        Err(error) => nixy_tools::main_result(Err(error)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::process::ExitStatusExt;
    fn output(code: i32, stdout: &[u8]) -> Output {
        Output {
            status: std::process::ExitStatus::from_raw(code << 8),
            stdout: stdout.to_vec(),
            stderr: vec![],
        }
    }
    #[test]
    fn secret_goes_only_to_helper_stdin() -> Result {
        let mut calls = 0;
        let result = dialog(
            "full",
            true,
            "zenity",
            Path::new("/fixed/helper"),
            |command, input| {
                calls += 1;
                assert!(!format!("{command:?}").contains("fixture-secret"));
                if calls == 1 {
                    assert_eq!(command.get_program(), "zenity");
                    assert!(input.is_none());
                    Ok(output(0, b"fixture-secret\n"))
                } else {
                    assert_eq!(
                        command.get_args().collect::<Vec<_>>(),
                        ["/fixed/helper", "full"]
                    );
                    assert_eq!(input, Some(b"fixture-secret\n".as_slice()));
                    Ok(output(0, b""))
                }
            },
        )?;
        assert_eq!(result, 0);
        assert_eq!(calls, 2);
        Ok(())
    }
    #[test]
    fn cancellation_never_runs_privileged_helper() -> Result {
        let mut calls = 0;
        assert_eq!(
            dialog(
                "care",
                true,
                "zenity",
                Path::new("/fixed/helper"),
                |command, _| {
                    calls += 1;
                    assert_eq!(command.get_program(), "zenity");
                    Ok(output(1, b""))
                }
            )?,
            130
        );
        assert_eq!(calls, 1);
        Ok(())
    }
    #[test]
    fn unprotected_firmware_uses_empty_stdin_password() -> Result {
        let mut calls = 0;
        assert_eq!(
            dialog(
                "care",
                false,
                "zenity",
                Path::new("/fixed/helper"),
                |command, input| {
                    calls += 1;
                    assert_eq!(command.get_program(), "/run/wrappers/bin/pkexec");
                    assert_eq!(input, Some(b"\n".as_slice()));
                    Ok(output(0, b""))
                }
            )?,
            0
        );
        assert_eq!(calls, 1);
        Ok(())
    }
}
