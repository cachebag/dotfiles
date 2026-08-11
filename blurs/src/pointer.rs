use std::io::{Read, Write};
use std::os::unix::net::UnixStream;

/// Global pointer position, via Hyprland's IPC socket.
///
/// Wayland deliberately gives clients no way to query the global pointer, and
/// layer-shell cannot anchor one surface to another, so placing the panel over
/// the waybar module that launched it needs a compositor-specific answer.
/// Returns None anywhere that socket isn't present, and the caller falls back
/// to a fixed anchor.
pub fn cursor_position() -> Option<(i32, i32)> {
    let runtime = std::env::var("XDG_RUNTIME_DIR").ok()?;
    let sig = std::env::var("HYPRLAND_INSTANCE_SIGNATURE").ok()?;

    let mut sock = UnixStream::connect(format!("{runtime}/hypr/{sig}/.socket.sock")).ok()?;
    sock.write_all(b"cursorpos").ok()?;

    let mut reply = String::new();
    sock.read_to_string(&mut reply).ok()?;

    parse(&reply)
}

fn parse(reply: &str) -> Option<(i32, i32)> {
    let (x, y) = reply.trim().split_once(',')?;
    Some((x.trim().parse().ok()?, y.trim().parse().ok()?))
}

#[cfg(test)]
mod tests {
    use super::parse;

    #[test]
    fn reads_the_ipc_reply_shape() {
        assert_eq!(parse("2333, 160"), Some((2333, 160)));
        assert_eq!(parse("0,0\n"), Some((0, 0)));
        assert_eq!(parse(" -12 , 40 \n"), Some((-12, 40)));
    }

    #[test]
    fn rejects_anything_else() {
        for bad in ["", "no", "1", "a, b", "1;2"] {
            assert_eq!(parse(bad), None, "accepted {bad:?}");
        }
    }
}
