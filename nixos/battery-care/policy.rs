use crate::Result;
use std::path::Path;
use std::sync::atomic::{AtomicBool, Ordering};

pub const FIRMWARE: &str = "/sys/class/firmware-attributes/dell-wmi-sysman";
pub const BATTERY: &str = "/sys/class/power_supply/BAT0";
pub const AC: &str = "/sys/class/power_supply/AC/online";

pub fn protected(root: &Path) -> Result<bool> {
    Ok(std::fs::read_to_string(root.join("authentication/Admin/is_enabled"))?.trim() == "1")
}
pub fn is_care(battery: &Path) -> Result<bool> {
    Ok(
        std::fs::read_to_string(battery.join("charge_types"))?.contains("[Custom]")
            && std::fs::read_to_string(battery.join("charge_control_start_threshold"))?.trim()
                == "50"
            && std::fs::read_to_string(battery.join("charge_control_end_threshold"))?.trim()
                == "80",
    )
}

/// Erase credential buffers even if a fallible operation returns early.
pub struct Secret(pub Vec<u8>);
impl Drop for Secret {
    fn drop(&mut self) {
        for byte in &mut self.0 {
            // Volatile writes keep the compiler from eliminating this cleanup.
            unsafe {
                std::ptr::write_volatile(byte, 0);
            }
        }
    }
}

pub fn disable_core_dumps() -> Result {
    let limit = libc::rlimit {
        rlim_cur: 0,
        rlim_max: 0,
    };
    if unsafe { libc::setrlimit(libc::RLIMIT_CORE, &limit) } != 0 {
        return Err(std::io::Error::last_os_error().into());
    }
    Ok(())
}

pub fn set_policy(
    mode: &str,
    password: &[u8],
    root: &Path,
    battery: &Path,
    ac: &Path,
    interrupted: &AtomicBool,
) -> Result {
    set_policy_with(
        mode,
        password,
        root,
        battery,
        ac,
        interrupted,
        |path, value| {
            std::fs::write(path, value)?;
            Ok(())
        },
    )
}

fn set_policy_with(
    mode: &str,
    password: &[u8],
    root: &Path,
    battery: &Path,
    ac: &Path,
    interrupted: &AtomicBool,
    mut write: impl FnMut(&Path, &[u8]) -> Result,
) -> Result {
    if !matches!(mode, "care" | "full") {
        return Err("Expected care or full".into());
    }
    if mode == "full" && std::fs::read_to_string(ac)?.trim() != "1" {
        return Err("Plug in the charger before enabling a full charge.".into());
    }
    if password.len() > 4096
        || password.iter().any(|b| matches!(b, b'\n' | b'\r' | 0))
        || std::str::from_utf8(password).is_err()
    {
        return Err("Invalid password input.".into());
    }
    if protected(root)? && password.is_empty() {
        return Err("A BIOS administrator password is required.".into());
    }
    let auth = root.join("authentication/Admin/current_password");
    let mut credential = Secret(password.to_vec());
    credential.0.push(b'\n');
    let operation: Result = (|| {
        write(&auth, &credential.0)?;
        for (name, value) in if mode == "care" {
            vec![
                ("PrimaryBattChargeCfg", "Custom\n"),
                ("CustomChargeStart", "50\n"),
                ("CustomChargeStop", "80\n"),
            ]
        } else {
            vec![("PrimaryBattChargeCfg", "Standard\n")]
        } {
            if interrupted.load(Ordering::Relaxed) {
                return Err("Battery setting interrupted.".into());
            }
            write(
                &root.join(format!("attributes/{name}/current_value")),
                value.as_bytes(),
            )?;
        }
        Ok(())
    })();
    // Always clear Dell's kernel credential, including rejected writes and signals.
    let cleared = write(&auth, b"\n");
    cleared?;
    operation?;
    if interrupted.load(Ordering::Relaxed) {
        return Err("Battery setting interrupted.".into());
    }
    if (mode == "care" && !is_care(battery)?)
        || (mode == "full"
            && !std::fs::read_to_string(battery.join("charge_types"))?.contains("[Standard]"))
    {
        return Err("Firmware accepted the settings but has not applied them. Reboot and check the battery mode.".into());
    }
    Ok(())
}

#[derive(Default)]
pub struct Restore {
    pub pending: bool,
}
impl Restore {
    pub fn login() -> Self {
        Self { pending: true }
    }
    pub fn changed(&mut self, on_battery: bool) {
        self.pending |= on_battery;
    }
    pub fn reconcile(&mut self, running: bool, exit: Option<i32>, care: bool) -> bool {
        if running {
            return false;
        }
        self.pending |= exit == Some(75);
        let launch = self.pending && !care;
        self.pending = false;
        launch
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture() -> Result<tempfile::TempDir> {
        let root = tempfile::tempdir()?;
        for (name, value) in [
            ("authentication/Admin/is_enabled", "1"),
            ("authentication/Admin/current_password", ""),
            ("attributes/PrimaryBattChargeCfg/current_value", "Adaptive"),
            ("attributes/CustomChargeStart/current_value", "50"),
            ("attributes/CustomChargeStop/current_value", "80"),
            ("battery/charge_types", "Custom [Adaptive] Standard"),
            ("battery/charge_control_start_threshold", "50"),
            ("battery/charge_control_end_threshold", "80"),
            ("online", "1"),
        ] {
            let path = root.path().join(name);
            std::fs::create_dir_all(path.parent().unwrap())?;
            std::fs::write(path, value)?;
        }
        Ok(root)
    }
    #[test]
    fn applies_custom_before_thresholds_and_clears_auth() -> Result {
        for mode in ["care", "full"] {
            let fixture = fixture()?;
            let root = fixture.path();
            set_policy_with(
                mode,
                b"fixture-password",
                root,
                &root.join("battery"),
                &root.join("online"),
                &AtomicBool::new(false),
                |path, bytes| {
                    if matches!(
                        path.parent().unwrap().file_name().unwrap().to_str(),
                        Some("CustomChargeStart" | "CustomChargeStop")
                    ) {
                        assert_eq!(
                            std::fs::read_to_string(
                                root.join("attributes/PrimaryBattChargeCfg/current_value")
                            )?,
                            "Custom\n"
                        );
                    }
                    std::fs::write(path, bytes)?;
                    if path.parent().unwrap().ends_with("PrimaryBattChargeCfg") {
                        std::fs::write(
                            root.join("battery/charge_types"),
                            format!("[{}]", std::str::from_utf8(bytes)?.trim()),
                        )?;
                    }
                    Ok(())
                },
            )?;
            assert_eq!(
                std::fs::read_to_string(root.join("authentication/Admin/current_password"))?,
                "\n"
            );
            assert_eq!(is_care(&root.join("battery"))?, mode == "care");
        }
        Ok(())
    }
    #[test]
    fn rejection_interruption_and_failed_readback_clear_auth() -> Result {
        for failure in ["reject", "interrupt", "readback"] {
            let fixture = fixture()?;
            let root = fixture.path();
            let signal = AtomicBool::new(false);
            let result = set_policy_with(
                "care",
                b"fixture-password",
                root,
                &root.join("battery"),
                &root.join("online"),
                &signal,
                |path, bytes| {
                    if path.file_name().unwrap() == "current_value" {
                        if failure == "reject" {
                            return Err("Firmware rejected authentication".into());
                        }
                        if failure == "interrupt" {
                            signal.store(true, Ordering::Relaxed);
                        }
                    }
                    std::fs::write(path, bytes)?;
                    Ok(())
                },
            );
            assert!(result.is_err());
            assert_eq!(
                std::fs::read_to_string(root.join("authentication/Admin/current_password"))?,
                "\n"
            );
        }
        Ok(())
    }
    #[test]
    fn invalid_inputs_and_unplugged_full_charge_cannot_write() -> Result {
        let fixture = fixture()?;
        let root = fixture.path();
        for (mode, password) in [
            ("erase", b"x".as_slice()),
            ("care", b""),
            ("care", b"x\ny"),
            ("care", b"x\0y"),
        ] {
            assert!(
                set_policy(
                    mode,
                    password,
                    root,
                    &root.join("battery"),
                    &root.join("online"),
                    &AtomicBool::new(false)
                )
                .is_err()
            );
        }
        std::fs::write(root.join("online"), "0")?;
        assert!(
            set_policy(
                "full",
                b"x",
                root,
                &root.join("battery"),
                &root.join("online"),
                &AtomicBool::new(false)
            )
            .is_err()
        );
        assert_eq!(
            std::fs::read_to_string(root.join("authentication/Admin/current_password"))?,
            ""
        );
        Ok(())
    }
    #[test]
    fn prompt_lifecycle_remembers_brief_unplug_and_busy_lock() {
        let mut restore = Restore::login();
        assert!(!restore.reconcile(false, None, true));
        restore.changed(true);
        restore.changed(false);
        assert!(restore.reconcile(false, None, false));
        assert!(!restore.reconcile(false, Some(130), false));
        restore.changed(true);
        assert!(!restore.reconcile(true, None, false));
        assert!(restore.reconcile(false, Some(130), false));
        assert!(restore.reconcile(false, Some(75), false));
    }
}
