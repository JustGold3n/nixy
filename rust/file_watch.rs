//! Blocking Linux directory notifications, including atomic file replacement.
use std::{
    ffi::CString,
    fs::File,
    io::{self, Read},
    os::fd::FromRawFd,
    os::unix::ffi::OsStrExt,
    path::Path,
};

pub struct FileWatch(File);

impl FileWatch {
    pub fn new(path: &Path) -> io::Result<Self> {
        let directory = path
            .parent()
            .ok_or_else(|| io::Error::other("missing parent"))?;
        std::fs::create_dir_all(directory)?;
        let directory = CString::new(directory.as_os_str().as_bytes())?;
        let fd = unsafe { libc::inotify_init1(libc::IN_CLOEXEC) };
        if fd < 0 {
            return Err(io::Error::last_os_error());
        }
        let file = unsafe { File::from_raw_fd(fd) };
        let mask = libc::IN_CLOSE_WRITE
            | libc::IN_MOVED_TO
            | libc::IN_DELETE
            | libc::IN_DELETE_SELF
            | libc::IN_MOVE_SELF;
        if unsafe { libc::inotify_add_watch(fd, directory.as_ptr(), mask) } < 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(Self(file))
    }

    pub fn wait(&mut self, name: &std::ffi::OsStr) -> io::Result<()> {
        let mut buffer = [0u8; 8192];
        loop {
            let size = match self.0.read(&mut buffer) {
                Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
                result => result?,
            };
            if size == 0 {
                return Err(io::Error::other("file watch closed"));
            }
            let mut offset = 0;
            let mut changed = false;
            while offset + size_of::<libc::inotify_event>() <= size {
                // Kernel events may not be aligned in this byte buffer.
                let event = unsafe {
                    std::ptr::read_unaligned(
                        buffer.as_ptr().add(offset).cast::<libc::inotify_event>(),
                    )
                };
                offset += size_of::<libc::inotify_event>();
                let end = offset + event.len as usize;
                if end > size {
                    return Err(io::Error::other("truncated file event"));
                }
                if event.mask & (libc::IN_IGNORED | libc::IN_DELETE_SELF | libc::IN_MOVE_SELF) != 0
                {
                    return Err(io::Error::other(
                        "watched directory removed; restart required",
                    ));
                }
                let filename = buffer[offset..end]
                    .split(|byte| *byte == 0)
                    .next()
                    .unwrap_or_default();
                changed |= event.mask & libc::IN_Q_OVERFLOW != 0 || filename == name.as_bytes();
                offset = end;
            }
            if changed {
                return Ok(());
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn follows_atomic_replacements_and_ignores_its_own_outputs() -> crate::Result {
        let dir = tempfile::tempdir()?;
        let path = dir.path().join("palette");
        let mut watch = FileWatch::new(&path)?;
        for content in ["first", "second"] {
            crate::atomic_write(&dir.path().join("cursor"), "unrelated")?;
            crate::atomic_write(&path, content)?;
            watch.wait(path.file_name().unwrap())?;
            assert_eq!(std::fs::read_to_string(&path)?, content);
        }
        Ok(())
    }
}
