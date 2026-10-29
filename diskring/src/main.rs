//! Disk usage for the Quickshell sunburst. `serve` keeps scans in memory and
//! speaks JSON lines over stdio, so zooming around the ring never rescans.

mod drives;
mod scan;

use std::collections::HashMap;
use std::io::{self, BufRead, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode, Stdio};
use std::sync::atomic::{AtomicBool, Ordering::Relaxed};
use std::time::{Duration, Instant};

use serde::{Deserialize, Serialize};

use scan::{Dir, Progress};

const USAGE: &str = "diskring — disk usage behind the Quickshell sunburst

usage:
  diskring [PATH]                       largest entries under PATH (default .)
  diskring tree [PATH] [-d DEPTH] [-m FRACTION]
                                        pruned tree as JSON
  diskring drives                       mounted drives as JSON
  diskring serve                        JSON lines on stdin/stdout (for the overlay)";

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let res = match args.first().map(String::as_str) {
        Some("-h" | "--help") => {
            println!("{USAGE}");
            Ok(())
        }
        Some("serve") => serve(),
        Some("drives") => emit(&drives::list()),
        Some("tree") => tree_cmd(&args[1..]),
        _ => ls_cmd(&args),
    };
    match res {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("diskring: {e}");
            ExitCode::FAILURE
        }
    }
}

fn emit<T: Serialize>(v: &T) -> io::Result<()> {
    let mut out = io::stdout().lock();
    serde_json::to_writer(&mut out, v)?;
    out.write_all(b"\n")?;
    out.flush()
}

fn scan_quiet(path: &Path) -> io::Result<Dir> {
    scan::scan(path, &Progress::default())
}

fn tree_cmd(args: &[String]) -> io::Result<()> {
    let (mut path, mut depth, mut frac) = (PathBuf::from("."), 4, 0.004);
    let mut it = args.iter();
    while let Some(a) = it.next() {
        let mut val = || it.next().ok_or_else(|| io::Error::other(format!("{a} needs a value")));
        match a.as_str() {
            "-d" | "--depth" => depth = val()?.parse().map_err(io::Error::other)?,
            "-m" | "--min" => frac = val()?.parse().map_err(io::Error::other)?,
            p => path = PathBuf::from(p),
        }
    }
    let dir = scan_quiet(&path)?;
    emit(&scan::view(&dir, depth, (dir.size as f64 * frac) as u64))
}

fn ls_cmd(args: &[String]) -> io::Result<()> {
    let path = PathBuf::from(args.first().map_or(".", String::as_str));
    let dir = scan_quiet(&path)?;
    let node = scan::view(&dir, 1, 0);
    let total = node.size.max(1);
    let mut out = io::stdout().lock();
    let res = writeln!(out, "{}  {}", human(node.size), path.display()).and_then(|()| {
        node.children.iter().take(25).try_for_each(|c| {
            let bar = (c.size * 20 / total) as usize;
            let name = if c.kind == "dir" { format!("{}/", c.name) } else { c.name.clone() };
            writeln!(out, "{:>9}  {:<20}  {name}", human(c.size), "█".repeat(bar))
        })
    });
    // `diskring | head` closing the pipe early is not a failure.
    match res {
        Err(e) if e.kind() == io::ErrorKind::BrokenPipe => Ok(()),
        r => r,
    }
}

fn human(b: u64) -> String {
    const UNITS: [&str; 6] = ["B", "K", "M", "G", "T", "P"];
    let mut v = b as f64;
    let mut u = 0;
    while v >= 1024.0 && u < UNITS.len() - 1 {
        v /= 1024.0;
        u += 1;
    }
    if u == 0 { format!("{b}B") } else { format!("{v:.1}{}", UNITS[u]) }
}

// ---- serve ---------------------------------------------------------------

#[derive(Deserialize)]
#[serde(tag = "cmd", rename_all = "lowercase")]
enum Cmd {
    /// Scan `root` unless a scan younger than `max_age` seconds is held.
    Open {
        root: PathBuf,
        #[serde(default)]
        max_age: u64,
    },
    Tree {
        root: PathBuf,
        path: PathBuf,
        #[serde(default = "default_depth")]
        depth: u32,
        #[serde(default = "default_min")]
        min: f64,
    },
    Trash {
        root: PathBuf,
        paths: Vec<PathBuf>,
    },
    Drives,
    Eject {
        device: String,
    },
}

fn default_depth() -> u32 {
    5
}
fn default_min() -> f64 {
    0.004
}

#[derive(Serialize)]
#[serde(tag = "type", rename_all = "lowercase")]
enum Msg<'a> {
    Progress {
        root: &'a Path,
        files: u64,
        bytes: u64,
    },
    Scanned {
        root: &'a Path,
        size: u64,
        files: u64,
        errors: u64,
        ms: u128,
        age: u64,
    },
    Tree {
        root: &'a Path,
        path: &'a Path,
        node: scan::Node,
    },
    Trashed {
        root: &'a Path,
        bytes: u64,
        count: usize,
        failed: Vec<String>,
    },
    Drives {
        drives: Vec<drives::Drive>,
    },
    Ejected {
        device: &'a str,
        error: Option<String>,
    },
    Error {
        message: String,
    },
}

struct Held {
    dir: Dir,
    at: Instant,
    errors: u64,
    ms: u128,
}

fn serve() -> io::Result<()> {
    let mut scans: HashMap<PathBuf, Held> = HashMap::new();
    for line in io::stdin().lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        let msg = match serde_json::from_str::<Cmd>(&line) {
            Ok(cmd) => handle(cmd, &mut scans),
            Err(e) => Err(format!("bad command: {e}")),
        };
        if let Err(message) = msg {
            emit(&Msg::Error { message })?;
        }
    }
    Ok(())
}

fn handle(cmd: Cmd, scans: &mut HashMap<PathBuf, Held>) -> Result<(), String> {
    let io = |e: io::Error| e.to_string();
    match cmd {
        Cmd::Open { root, max_age } => {
            let fresh = scans
                .get(&root)
                .is_some_and(|h| h.at.elapsed() < Duration::from_secs(max_age));
            if !fresh {
                let held = scan_with_progress(&root).map_err(|e| format!("{}: {e}", root.display()))?;
                scans.insert(root.clone(), held);
            }
            let h = &scans[&root];
            emit(&Msg::Scanned {
                root: &root,
                size: h.dir.size,
                files: h.dir.files,
                errors: h.errors,
                ms: h.ms,
                age: h.at.elapsed().as_secs(),
            })
            .map_err(io)
        }
        Cmd::Tree { root, path, depth, min } => {
            let h = scans.get(&root).ok_or("root not scanned")?;
            let rel = scan::relative(&root, &path).ok_or("path outside root")?;
            let dir = h.dir.find(&rel).ok_or_else(|| format!("{} not found", path.display()))?;
            let node = scan::view(dir, depth, (dir.size as f64 * min) as u64);
            emit(&Msg::Tree { root: &root, path: &path, node }).map_err(io)
        }
        Cmd::Trash { root, paths } => {
            let h = scans.get_mut(&root).ok_or("root not scanned")?;
            let (mut bytes, mut count, mut failed) = (0, 0, Vec::new());
            for p in &paths {
                // Never the root itself or anything outside it.
                let rel = scan::relative(&root, p).filter(|r| !r.as_os_str().is_empty());
                let ok = rel.is_some()
                    && Command::new("gio")
                        .arg("trash")
                        .arg("--")
                        .arg(p)
                        .stderr(Stdio::null())
                        .status()
                        .is_ok_and(|s| s.success());
                match rel {
                    Some(rel) if ok => {
                        bytes += h.dir.remove(&rel).unwrap_or(0);
                        count += 1;
                    }
                    _ => failed.push(p.display().to_string()),
                }
            }
            emit(&Msg::Trashed { root: &root, bytes, count, failed }).map_err(io)
        }
        Cmd::Drives => emit(&Msg::Drives { drives: drives::list() }).map_err(io),
        Cmd::Eject { device } => {
            let error = drives::eject(&device).err();
            emit(&Msg::Ejected { device: &device, error }).map_err(io)
        }
    }
}

fn scan_with_progress(root: &Path) -> io::Result<Held> {
    let progress = Progress::default();
    let done = AtomicBool::new(false);
    let start = Instant::now();
    let (dir, ms) = std::thread::scope(|s| {
        s.spawn(|| {
            while !done.load(Relaxed) {
                std::thread::sleep(Duration::from_millis(120));
                let _ = emit(&Msg::Progress {
                    root,
                    files: progress.files.load(Relaxed),
                    bytes: progress.bytes.load(Relaxed),
                });
            }
        });
        let dir = scan::scan(root, &progress);
        done.store(true, Relaxed);
        (dir, start.elapsed().as_millis())
    });
    Ok(Held {
        dir: dir?,
        at: Instant::now(),
        errors: progress.errors.load(Relaxed),
        ms,
    })
}
