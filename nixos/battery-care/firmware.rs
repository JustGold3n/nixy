use nixy_tools::{
    Result,
    battery::{self, Secret},
};
use std::{
    io::{BufRead, Read},
    path::Path,
    sync::{Arc, atomic::AtomicBool},
};

fn run(mode: &str) -> Result {
    battery::disable_core_dumps()?;
    let interrupted = Arc::new(AtomicBool::new(false));
    for signal in [libc::SIGTERM, libc::SIGHUP, libc::SIGINT] {
        signal_hook::flag::register(signal, interrupted.clone())?;
    }
    let mut password = Secret(Vec::new());
    std::io::stdin()
        .lock()
        .take(4098)
        .read_until(b'\n', &mut password.0)?;
    if password.0.last() == Some(&b'\n') {
        password.0.pop();
    }
    battery::set_policy(
        mode,
        &password.0,
        Path::new(battery::FIRMWARE),
        Path::new(battery::BATTERY),
        Path::new(battery::AC),
        &interrupted,
    )
}
fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args == ["--help"] {
        println!(
            "Usage: battery-charge-firmware care|full\nRead the BIOS password from standard input."
        );
        return;
    }
    if args.len() != 1 || !matches!(args[0].as_str(), "care" | "full") {
        eprintln!("Usage: battery-charge-firmware care|full");
        std::process::exit(2);
    }
    if let Err(error) = run(&args[0]) {
        eprintln!("Battery setting failed: {error}");
        std::process::exit(1);
    }
}
