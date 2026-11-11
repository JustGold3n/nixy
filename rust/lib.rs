use std::io::Write;
use std::process::{Command, Output, Stdio};
use std::time::{Duration, Instant};

pub type Result<T = ()> = std::result::Result<T, Box<dyn std::error::Error>>;

#[path = "../nixos/battery-care/policy.rs"]
pub mod battery;
pub mod file_watch;

pub fn main_result(result: Result) {
    if let Err(error) = result {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

/// Run with a deadline, draining output concurrently so a full pipe cannot hang
/// a service or a regression test. Kill and reap children that exceed it.
pub fn output(command: &mut Command, input: Option<&[u8]>, timeout: Duration) -> Result<Output> {
    command.stdout(Stdio::piped()).stderr(Stdio::piped());
    if input.is_some() {
        command.stdin(Stdio::piped());
    }
    let mut child = command.spawn()?;
    let stdout = child.stdout.take().unwrap();
    let stderr = child.stderr.take().unwrap();
    let read = |mut pipe: Box<dyn std::io::Read + Send>| {
        std::thread::spawn(move || {
            let mut bytes = Vec::new();
            pipe.read_to_end(&mut bytes).map(|_| bytes)
        })
    };
    let out = read(Box::new(stdout));
    let err = read(Box::new(stderr));
    if let Some(bytes) = input {
        let write = child.stdin.take().unwrap().write_all(bytes);
        if let Err(error) = write {
            let _ = child.kill();
            let _ = child.wait();
            return Err(error.into());
        }
    }
    let deadline = Instant::now() + timeout;
    let status = loop {
        if let Some(status) = child.try_wait()? {
            break status;
        }
        if Instant::now() >= deadline {
            child.kill()?;
            child.wait()?;
            return Err("command timed out".into());
        }
        std::thread::sleep(Duration::from_millis(10));
    };
    Ok(Output {
        status,
        stdout: out.join().map_err(|_| "stdout reader panicked")??,
        stderr: err.join().map_err(|_| "stderr reader panicked")??,
    })
}

pub fn checked(command: &mut Command) -> Result<String> {
    let result = output(command, None, Duration::from_secs(10))?;
    if !result.status.success() {
        return Err(format!(
            "command failed: {}",
            String::from_utf8_lossy(&result.stderr)
        )
        .into());
    }
    Ok(String::from_utf8(result.stdout)?)
}

pub fn atomic_write(path: &std::path::Path, contents: impl AsRef<[u8]>) -> Result {
    let parent = path.parent().ok_or("path has no parent")?;
    std::fs::create_dir_all(parent)?;
    let mut pending = tempfile::NamedTempFile::new_in(parent)?;
    pending.write_all(contents.as_ref())?;
    pending.persist(path)?;
    Ok(())
}
