use std::io;
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::Duration;

use super::{Lock, Session, pam};
use crate::Service;

// A separate process lets password authentication proceed independently and
// lets us release the reader immediately when the lock ends, even if PAM waits.
const PAMTESTER: &str = "@pamtester@";
const POLL: Duration = Duration::from_millis(25);

impl Lock {
    pub(crate) fn start_fingerprint() {
        let Ok(user) = std::env::var("USER") else {
            return;
        };
        let attempt = Arc::new(Session::default());
        let restart = {
            let mut lock = Self::write();
            if lock.unlocked || lock.fingerprint.is_some() {
                lock.quiet();
                return;
            }
            lock.fingerprint = Some(attempt.clone());
            lock.fingerprint_restart.clone()
        };
        let current = attempt.clone();
        let worker = thread::Builder::new()
            .name(String::from("amane-fingerprint"))
            .spawn(move || {
                let mut command = Command::new(PAMTESTER);
                // Both operations must succeed; fingerprint matches cannot
                // bypass account expiry or other account restrictions.
                command.args(["amane-fingerprint", &user, "authenticate", "acct_mgmt"]);
                if verify_until_accepted(&mut command, &current, &restart) {
                    Self::fingerprint_accepted(&current);
                    return;
                }
                let mut lock = Self::write();
                if current.is_current(&lock.fingerprint) {
                    lock.fingerprint = None;
                } else {
                    lock.quiet();
                }
            });
        if let Err(error) = worker {
            attempt.abort();
            let mut lock = Self::write();
            if attempt.is_current(&lock.fingerprint) {
                lock.fingerprint = None;
            } else {
                lock.quiet();
            }
            eprintln!("amane: cannot start fingerprint verification: {error}");
        }
    }

    fn fingerprint_accepted(attempt: &Arc<Session>) {
        let password = {
            let mut lock = Self::write();
            // A killed helper or an earlier lock's late success cannot unlock.
            if attempt.aborted() || !attempt.is_current(&lock.fingerprint) || lock.unlocked {
                lock.quiet();
                return;
            }
            lock.stop_fingerprint();
            let password = lock.attempt.take();
            if let Some(password) = &password {
                password.abort();
            }
            lock.checking = false;
            lock.failed = false;
            lock.unlocked = true;
            password
        };
        if let Some(password) = password {
            pam::abort_session(&password);
        }
        Self::notify_unlocked();
    }
}

fn verify_until_accepted(command: &mut Command, attempt: &Session, restart: &AtomicBool) -> bool {
    while !attempt.aborted() {
        match verify_once(command, attempt, restart) {
            Ok(Some(true)) => return true,
            Ok(None) => return false,
            Ok(Some(false)) => {}
            Err(error) => eprintln!("amane: fingerprint verification failed: {error}"),
        }
        // Retry failed scans and transient helper errors without disabling the
        // scanner. Keep cancellation responsive during the retry delay too.
        for _ in 0..10 {
            if attempt.aborted() {
                return false;
            }
            thread::sleep(POLL);
        }
    }
    false
}

fn verify_once(
    command: &mut Command,
    attempt: &Session,
    restart: &AtomicBool,
) -> io::Result<Option<bool>> {
    if attempt.aborted() {
        return Ok(None);
    }
    // Starting a new helper also fulfils a restart requested between scans.
    restart.store(false, Ordering::Release);
    let mut child = command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;
    let result = loop {
        if attempt.aborted() {
            break Ok(None);
        }
        if restart.swap(false, Ordering::AcqRel) {
            // A password failure also recovers a reader stuck after suspend.
            // Reap this helper before the retry loop claims the reader again.
            break Ok(Some(false));
        }
        match child.try_wait() {
            Ok(Some(status)) => break Ok(Some(status.success())),
            Ok(None) => thread::sleep(POLL),
            Err(error) => break Err(error),
        }
    };
    // Reap every helper, including when the session was cancelled while PAM
    // blocked. Closing its D-Bus connection releases the fingerprint reader.
    let _ = child.kill();
    let _ = child.wait();
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{PamError, PamResult};
    use std::sync::Mutex;
    use std::time::Instant;

    static SERIAL: Mutex<()> = Mutex::new(());

    fn setup() -> Arc<Session> {
        Lock::reset();
        let attempt = Arc::new(Session::default());
        Lock::write().fingerprint = Some(attempt.clone());
        attempt
    }

    #[test]
    fn fingerprint_can_win_while_password_is_pending() {
        let _serial = SERIAL.lock().unwrap();
        let finger = setup();
        let password = Arc::new(Session::default());
        {
            let mut lock = Lock::write();
            lock.attempt = Some(password.clone());
            lock.checking = true;
        }
        Lock::fingerprint_accepted(&finger);
        assert!(Lock::read().unlocked());
        assert!(password.aborted());
        assert!(!Lock::read().checking());
        Lock::finished(&password, &PamResult::Rejected(PamError::UserChanged));
        assert!(
            Lock::read().unlocked(),
            "late password failure undid fingerprint success"
        );
        Lock::reset();
    }

    #[test]
    fn password_success_cancels_fingerprint_and_old_scans_cannot_unlock_again() {
        let _serial = SERIAL.lock().unwrap();
        let finger = setup();
        let password = Arc::new(Session::default());
        Lock::write().attempt = Some(password.clone());
        Lock::finished(&password, &PamResult::Success);
        assert!(Lock::read().unlocked());
        assert!(finger.aborted());
        let current = setup();
        Lock::fingerprint_accepted(&finger);
        assert!(!Lock::read().unlocked());
        Lock::abort();
        Lock::fingerprint_accepted(&current);
        assert!(!Lock::read().unlocked());
    }

    #[test]
    fn password_failure_keeps_scanner_available() {
        let _serial = SERIAL.lock().unwrap();
        let finger = setup();
        let password = Arc::new(Session::default());
        Lock::write().attempt = Some(password.clone());
        Lock::finished(&password, &PamResult::Rejected(PamError::UserChanged));
        assert!(!Lock::read().unlocked());
        assert!(!finger.aborted());
        assert!(Lock::read().fingerprint_restart.load(Ordering::Acquire));
        Lock::fingerprint_accepted(&finger);
        assert!(Lock::read().unlocked());
        Lock::reset();
    }

    #[test]
    fn helper_failure_is_rejected_and_success_is_accepted() {
        let attempt = Session::default();
        let restart = AtomicBool::new(false);
        assert_eq!(
            verify_once(
                Command::new("sh").args(["-c", "exit 1"]),
                &attempt,
                &restart
            )
            .unwrap(),
            Some(false)
        );
        assert_eq!(
            verify_once(
                Command::new("sh").args(["-c", "exit 0"]),
                &attempt,
                &restart
            )
            .unwrap(),
            Some(true)
        );
    }

    #[test]
    fn cancellation_interrupts_a_blocked_helper() {
        let attempt = Arc::new(Session::default());
        let worker_attempt = attempt.clone();
        let worker = thread::spawn(move || {
            verify_once(
                Command::new("sh").args(["-c", "exec sleep 30"]),
                &worker_attempt,
                &AtomicBool::new(false),
            )
        });
        thread::sleep(Duration::from_millis(100));
        let start = Instant::now();
        attempt.abort();
        assert_eq!(worker.join().unwrap().unwrap(), None);
        assert!(start.elapsed() < Duration::from_secs(2));
    }

    #[test]
    fn password_retry_interrupts_a_stuck_scan_and_allows_a_fresh_scan() {
        let attempt = Arc::new(Session::default());
        let restart = Arc::new(AtomicBool::new(false));
        let worker_attempt = attempt.clone();
        let worker_restart = restart.clone();
        let worker = thread::spawn(move || {
            verify_once(
                Command::new("sh").args(["-c", "exec sleep 30"]),
                &worker_attempt,
                &worker_restart,
            )
        });
        thread::sleep(Duration::from_millis(100));
        let start = Instant::now();
        restart.store(true, Ordering::Release);
        assert_eq!(worker.join().unwrap().unwrap(), Some(false));
        assert!(start.elapsed() < Duration::from_secs(2));
        assert!(!attempt.aborted());
        assert!(verify_until_accepted(
            Command::new("sh").args(["-c", "exit 0"]),
            &attempt,
            &restart,
        ));
    }

    #[test]
    fn failed_scan_is_retried_without_keyboard_interaction() {
        use std::time::{SystemTime, UNIX_EPOCH};

        let marker = std::env::temp_dir().join(format!(
            "amane-fingerprint-retry-{}-{}",
            std::process::id(),
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos(),
        ));
        let accepted = verify_until_accepted(
            Command::new("sh")
                .args([
                    "-c",
                    "if test -e \"$1\"; then exit 0; fi; : > \"$1\"; exit 1",
                    "test",
                ])
                .arg(&marker),
            &Session::default(),
            &AtomicBool::new(false),
        );
        std::fs::remove_file(marker).unwrap();
        assert!(accepted);
    }
}
