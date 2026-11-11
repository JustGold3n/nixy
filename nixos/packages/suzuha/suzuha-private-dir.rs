//! Private, uniquely created conversion workspaces; never reuse a shared profile.
use std::ffi::OsString;
use std::fs;
use std::io;
use std::os::unix::ffi::{OsStrExt, OsStringExt};
use std::path::{Path, PathBuf};
use std::process::Command;

const MKTEMP: &str = "@mktemp@";

pub struct PrivateDir(PathBuf);

impl PrivateDir {
    pub fn new_in(parent: &Path) -> io::Result<Self> {
        let mut location = OsString::from("--tmpdir=");
        location.push(fs::canonicalize(parent)?);
        // GNU mktemp atomically creates a fresh directory with mode 0700.
        let output = Command::new(MKTEMP)
            .arg("--directory")
            .arg(location)
            .args(["--", "suzuha-convert.XXXXXXXXXX"])
            .output()?;
        if !output.status.success() {
            return Err(io::Error::other("Could not create a private conversion directory"));
        }
        let mut path = output.stdout;
        if path.pop() != Some(b'\n') || path.is_empty() {
            return Err(io::Error::other("Invalid mktemp result"));
        }
        Ok(Self(PathBuf::from(OsString::from_vec(path))))
    }

    pub fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for PrivateDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

pub fn file_uri(path: &Path) -> String {
    let mut uri = String::from("file://");
    for &byte in path.as_os_str().as_bytes() {
        if byte.is_ascii_alphanumeric() || b"/-._~".contains(&byte) {
            uri.push(char::from(byte));
        } else {
            uri.push_str(&format!("%{byte:02X}"));
        }
    }
    uri
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::{PermissionsExt, symlink};

    #[test]
    fn workspaces_are_private_unique_and_removed_on_drop() {
        let root = PrivateDir::new_in(&std::env::temp_dir()).unwrap();
        let first = PrivateDir::new_in(root.path()).unwrap();
        let second = PrivateDir::new_in(root.path()).unwrap();
        assert_ne!(first.path(), second.path());
        assert_eq!(fs::metadata(first.path()).unwrap().permissions().mode() & 0o777, 0o700);
        let path = first.path().to_owned();
        fs::write(path.join("private-document"), b"test content").unwrap();
        drop(first);
        assert!(!path.exists());
        assert!(second.path().exists());
    }

    #[test]
    fn preexisting_profiles_and_symlinks_are_not_reused_or_deleted() {
        let root = PrivateDir::new_in(&std::env::temp_dir()).unwrap();
        let target = root.path().join("target");
        fs::create_dir(&target).unwrap();
        fs::write(target.join("keep"), b"unchanged").unwrap();
        symlink(&target, root.path().join("amane-libreoffice")).unwrap();
        symlink(&target, root.path().join("suzuha-convert.XXXXXXXXXX")).unwrap();
        let work = PrivateDir::new_in(root.path()).unwrap();
        symlink(&target, work.path().join("link")).unwrap();
        drop(work);
        assert_eq!(fs::read(target.join("keep")).unwrap(), b"unchanged");
        assert!(root.path().join("amane-libreoffice").is_symlink());
    }

    #[test]
    fn profile_uri_escapes_spaces_delimiters_and_unicode() {
        assert_eq!(file_uri(Path::new("/tmp/a b#%?ž/profile")),
            "file:///tmp/a%20b%23%25%3F%C5%BE/profile");
    }
}
