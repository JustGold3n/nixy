use dbus::{arg::PropMap, blocking::LocalConnection, message::MatchRule};
use nixy_tools::{
    Result,
    battery::{self, Restore},
};
use std::{
    cell::RefCell,
    path::Path,
    process::{Child, Command},
    rc::Rc,
    time::{Duration, Instant},
};

fn run() -> Result {
    let bus = LocalConnection::new_system()?;
    let restore = Rc::new(RefCell::new(Restore::login()));
    let state = restore.clone();
    let mut rule = MatchRule::new_signal("org.freedesktop.DBus.Properties", "PropertiesChanged");
    rule.sender = Some("org.freedesktop.UPower".into());
    rule.path = Some("/org/freedesktop/UPower".into());
    bus.add_match(
        rule,
        move |(interface, changed, _): (String, PropMap, Vec<String>), _, _| {
            if interface == "org.freedesktop.UPower" {
                state
                    .borrow_mut()
                    .changed(changed.get("OnBattery").and_then(|v| v.0.as_u64()) == Some(1));
            }
            true
        },
    )?;
    let binary = std::env::current_exe()?.with_file_name("battery-charge");
    let mut prompt: Option<Child> = None;
    let mut next = Instant::now();
    loop {
        // Block on UPower while settled. Only a pending prompt needs retries;
        // reading Dell's charge thresholds repeatedly also wakes the firmware.
        let timeout = if restore.borrow().pending || prompt.is_some() {
            next.saturating_duration_since(Instant::now())
        } else {
            Duration::from_secs(86400)
        };
        bus.process(timeout)?;
        if (!restore.borrow().pending && prompt.is_none()) || Instant::now() < next {
            continue;
        }
        next = Instant::now() + Duration::from_secs(5);
        let result = (|| -> Result {
            let exit = match prompt.as_mut().map(Child::try_wait).transpose()?.flatten() {
                Some(status) => {
                    prompt = None;
                    Some(status.code().unwrap_or(1))
                }
                None => None,
            };
            let care = if prompt.is_none() && (restore.borrow().pending || exit == Some(75)) {
                battery::is_care(Path::new(battery::BATTERY))?
            } else {
                false
            };
            if restore.borrow_mut().reconcile(prompt.is_some(), exit, care) {
                match Command::new(&binary).arg("care").spawn() {
                    Ok(child) => prompt = Some(child),
                    Err(error) => {
                        restore.borrow_mut().pending = true;
                        return Err(error.into());
                    }
                }
            }
            Ok(())
        })();
        if let Err(error) = result {
            eprintln!("Battery care: {error}");
        }
    }
}
fn main() {
    let args: Vec<_> = std::env::args().skip(1).collect();
    if args == ["--help"] {
        println!("Usage: battery-care-watch");
        return;
    }
    if !args.is_empty() {
        eprintln!("Usage: battery-care-watch");
        std::process::exit(2);
    }
    nixy_tools::main_result(run());
}
