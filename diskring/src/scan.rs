//! Parallel walk of one filesystem into a directory-only tree. Files are folded
//! into their parent unless they are big enough to earn an arc on the ring,
//! which keeps a full scan of `/` in tens of MB rather than hundreds.

use std::collections::HashSet;
use std::ffi::OsStr;
use std::fs;
use std::io;
use std::os::unix::fs::MetadataExt;
use std::path::{Component, Path, PathBuf};
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering::Relaxed};

use rayon::prelude::*;
use serde::Serialize;

/// Files at least this large keep their own node.
const BIG_FILE: u64 = 1 << 20;
/// Per directory; anything past this is folded into `loose`.
const MAX_BIG: usize = 48;

pub struct Dir {
    pub name: Box<str>,
    /// Bytes on disk (st_blocks), including everything below.
    pub size: u64,
    pub files: u64,
    pub dirs: Vec<Dir>,
    pub big: Vec<File>,
    /// Small files directly in this directory, plus the directory inode itself.
    pub loose: u64,
    pub loose_files: u64,
}

pub struct File {
    pub name: Box<str>,
    pub size: u64,
}

#[derive(Default)]
pub struct Progress {
    pub files: AtomicU64,
    pub bytes: AtomicU64,
    pub errors: AtomicU64,
}

struct Ctx<'a> {
    dev: u64,
    progress: &'a Progress,
    /// Hardlinked inodes already counted, so `du`-style totals stay honest.
    links: Mutex<HashSet<(u64, u64)>>,
}

pub fn scan(root: &Path, progress: &Progress) -> io::Result<Dir> {
    let md = fs::metadata(root)?;
    if !md.is_dir() {
        return Err(io::Error::from(io::ErrorKind::NotADirectory));
    }
    let ctx = Ctx {
        dev: md.dev(),
        progress,
        links: Mutex::default(),
    };
    let name = root.file_name().map_or("/".into(), lossy);
    Ok(walk(root, name, md.blocks() * 512, &ctx))
}

fn lossy(s: &OsStr) -> Box<str> {
    s.to_string_lossy().into()
}

fn walk(path: &Path, name: Box<str>, own: u64, ctx: &Ctx) -> Dir {
    let mut dir = Dir {
        name,
        size: 0,
        files: 0,
        dirs: Vec::new(),
        big: Vec::new(),
        loose: own,
        loose_files: 0,
    };
    ctx.progress.bytes.fetch_add(own, Relaxed);

    let entries = match fs::read_dir(path) {
        Ok(e) => e,
        Err(_) => {
            ctx.progress.errors.fetch_add(1, Relaxed);
            dir.size = dir.loose;
            return dir;
        }
    };

    let mut subdirs = Vec::new();
    let (mut files, mut bytes) = (0, 0);
    for entry in entries.flatten() {
        // DirEntry::metadata is lstat: symlinks are counted, never followed.
        let Ok(md) = entry.metadata() else {
            ctx.progress.errors.fetch_add(1, Relaxed);
            continue;
        };
        if md.is_dir() {
            // Other mounts show up as their own drive, not inside this one.
            if md.dev() == ctx.dev {
                subdirs.push((entry.path(), lossy(&entry.file_name()), md.blocks() * 512));
            }
            continue;
        }
        let size = if md.nlink() > 1 && !ctx.links.lock().unwrap().insert((md.dev(), md.ino())) {
            0
        } else {
            md.blocks() * 512
        };
        files += 1;
        bytes += size;
        if size >= BIG_FILE {
            dir.big.push(File {
                name: lossy(&entry.file_name()),
                size,
            });
        } else {
            dir.loose += size;
            dir.loose_files += 1;
        }
    }
    ctx.progress.files.fetch_add(files, Relaxed);
    ctx.progress.bytes.fetch_add(bytes, Relaxed);

    dir.dirs = subdirs
        .into_par_iter()
        .map(|(p, n, own)| walk(&p, n, own, ctx))
        .collect();

    dir.big.sort_unstable_by_key(|x| std::cmp::Reverse(x.size));
    for f in dir.big.drain(MAX_BIG.min(dir.big.len())..) {
        dir.loose += f.size;
        dir.loose_files += 1;
    }
    dir.dirs.sort_unstable_by_key(|x| std::cmp::Reverse(x.size));
    dir.total();
    dir
}

impl Dir {
    fn total(&mut self) {
        self.size = self.loose
            + self.big.iter().map(|f| f.size).sum::<u64>()
            + self.dirs.iter().map(|d| d.size).sum::<u64>();
        self.files = self.loose_files
            + self.big.len() as u64
            + self.dirs.iter().map(|d| d.files).sum::<u64>();
    }

    pub fn find(&self, rel: &Path) -> Option<&Dir> {
        names(rel)?
            .iter()
            .try_fold(self, |d, n| d.dirs.iter().find(|c| *c.name == **n))
    }

    /// Drops `rel` from the tree and returns the bytes it held. `None` when it
    /// was never tracked on its own (a small file folded into its parent).
    pub fn remove(&mut self, rel: &Path) -> Option<u64> {
        let names = names(rel)?;
        self.remove_in(&names)
    }

    fn remove_in(&mut self, names: &[String]) -> Option<u64> {
        let (first, rest) = names.split_first()?;
        let freed = if rest.is_empty() {
            if let Some(i) = self.dirs.iter().position(|c| *c.name == **first) {
                self.dirs.remove(i).size
            } else {
                let i = self.big.iter().position(|f| *f.name == **first)?;
                self.big.remove(i).size
            }
        } else {
            self.dirs
                .iter_mut()
                .find(|c| *c.name == **first)?
                .remove_in(rest)?
        };
        self.dirs.sort_unstable_by_key(|x| std::cmp::Reverse(x.size));
        self.total();
        Some(freed)
    }
}

fn names(rel: &Path) -> Option<Vec<String>> {
    rel.components()
        .filter(|c| !matches!(c, Component::CurDir))
        .map(|c| match c {
            Component::Normal(s) => Some(s.to_string_lossy().into_owned()),
            _ => None,
        })
        .collect()
}

/// `path` relative to `root`, refusing anything that escapes it.
pub fn relative(root: &Path, path: &Path) -> Option<PathBuf> {
    path.strip_prefix(root).ok().map(Path::to_path_buf)
}

#[derive(Serialize)]
pub struct Node {
    pub name: String,
    pub size: u64,
    pub kind: &'static str,
    #[serde(skip_serializing_if = "is_zero")]
    pub files: u64,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub children: Vec<Node>,
}

fn is_zero(n: &u64) -> bool {
    *n == 0
}

/// A pruned copy of `dir` for drawing: `depth` rings deep, with anything
/// smaller than `min` bytes merged into one trailing "rest" node per level.
pub fn view(dir: &Dir, depth: u32, min: u64) -> Node {
    let mut children = Vec::new();
    if depth > 0 {
        let (mut rest, mut rest_files) = (dir.loose, dir.loose_files);
        for d in &dir.dirs {
            if d.size >= min {
                children.push(view(d, depth - 1, min));
            } else {
                rest += d.size;
                rest_files += d.files;
            }
        }
        for f in &dir.big {
            if f.size >= min {
                children.push(Node {
                    name: f.name.to_string(),
                    size: f.size,
                    kind: "file",
                    files: 1,
                    children: Vec::new(),
                });
            } else {
                rest += f.size;
                rest_files += 1;
            }
        }
        children.sort_unstable_by_key(|x| std::cmp::Reverse(x.size));
        if rest > 0 && rest >= min {
            children.push(Node {
                name: "smaller items".into(),
                size: rest,
                kind: "rest",
                files: rest_files,
                children: Vec::new(),
            });
        }
    }
    Node {
        name: dir.name.to_string(),
        size: dir.size,
        kind: "dir",
        files: dir.files,
        children,
    }
}
