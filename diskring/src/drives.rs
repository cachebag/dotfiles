//! Mounted block devices with their usage, straight from /proc and /sys.

use std::collections::HashMap;
use std::ffi::CString;
use std::fs;
use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};
use std::process::Command;

use serde::Serialize;

#[derive(Serialize)]
pub struct Drive {
    pub device: String,
    pub mount: String,
    pub fs: String,
    pub label: Option<String>,
    pub size: u64,
    pub used: u64,
    pub avail: u64,
    pub removable: bool,
}

pub fn list() -> Vec<Drive> {
    let mounts = fs::read_to_string("/proc/self/mounts").unwrap_or_default();
    let labels = labels();
    let mut out: Vec<Drive> = Vec::new();

    for line in mounts.lines() {
        let mut it = line.split(' ');
        let (Some(src), Some(mnt), Some(fs)) = (it.next(), it.next(), it.next()) else {
            continue;
        };
        if !src.starts_with("/dev/") || src.starts_with("/dev/loop") || fs == "squashfs" {
            continue;
        }
        // btrfs subvolumes and bind mounts repeat the device; the first is the real one.
        if out.iter().any(|d| d.device == src) {
            continue;
        }
        let mount = unescape(mnt);
        let Some((size, avail, free)) = statvfs(Path::new(&mount)) else {
            continue;
        };
        let real = fs::canonicalize(src).unwrap_or_else(|_| PathBuf::from(src));
        out.push(Drive {
            device: src.to_string(),
            label: labels.get(&real).cloned(),
            removable: removable(&real),
            fs: fs.to_string(),
            mount,
            size,
            used: size.saturating_sub(free),
            avail,
        });
    }
    out
}

/// Unmount, then power the drive down so it can be pulled. Goes through
/// udisks, so polkit decides and no sudo is involved.
pub fn eject(device: &str) -> Result<(), String> {
    for verb in ["unmount", "power-off"] {
        let out = Command::new("udisksctl")
            .args([verb, "-b", device, "--no-user-interaction"])
            .output()
            .map_err(|e| format!("udisksctl: {e}"))?;
        if !out.status.success() {
            return Err(String::from_utf8_lossy(&out.stderr).trim().to_string());
        }
    }
    Ok(())
}

/// (total, available to us, free including the root reserve), in bytes.
fn statvfs(path: &Path) -> Option<(u64, u64, u64)> {
    let c = CString::new(path.as_os_str().as_bytes()).ok()?;
    let mut s: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c.as_ptr(), &mut s) } != 0 {
        return None;
    }
    let f = s.f_frsize as u64;
    Some((s.f_blocks as u64 * f, s.f_bavail as u64 * f, s.f_bfree as u64 * f))
}

fn removable(dev: &Path) -> bool {
    let Some(name) = dev.file_name() else {
        return false;
    };
    let Ok(sys) = fs::canonicalize(Path::new("/sys/class/block").join(name)) else {
        return false;
    };
    if sys.to_string_lossy().contains("/usb") {
        return true;
    }
    // Partitions don't carry the flag; their parent disk does.
    [sys.join("removable"), sys.with_file_name("removable")]
        .iter()
        .find_map(|p| fs::read_to_string(p).ok())
        .is_some_and(|s| s.trim() == "1")
}

fn labels() -> HashMap<PathBuf, String> {
    let Ok(dir) = fs::read_dir("/dev/disk/by-label") else {
        return HashMap::new();
    };
    dir.flatten()
        .filter_map(|e| {
            let dev = fs::canonicalize(e.path()).ok()?;
            Some((dev, unescape(&e.file_name().to_string_lossy())))
        })
        .collect()
}

/// Undo the octal (`\040`) and hex (`\x20`) escapes in mounts and udev names.
fn unescape(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'\\' {
            let (radix, start, len) = if b.get(i + 1) == Some(&b'x') { (16, i + 2, 2) } else { (8, i + 1, 3) };
            let digits = b.get(start..start + len).and_then(|d| std::str::from_utf8(d).ok());
            if let Some(v) = digits.and_then(|d| u8::from_str_radix(d, radix).ok()) {
                out.push(v);
                i = start + len;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}
