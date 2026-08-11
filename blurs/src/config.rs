use layer_shell::Edge;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Anchor {
    TopLeft,
    Top,
    TopRight,
    Left,
    Center,
    Right,
    BottomLeft,
    Bottom,
    BottomRight,
    /// Place the panel at the pointer, so it lands over whichever bar module
    /// was clicked. Falls back to TopRight where the pointer can't be read.
    Cursor,
}

impl Anchor {
    pub fn parse(s: &str) -> Option<Self> {
        let k: String = s
            .trim()
            .to_ascii_lowercase()
            .chars()
            .filter(|c| !matches!(c, ' ' | '_' | '-'))
            .collect();
        Some(match k.as_str() {
            "topleft" | "lefttop" => Self::TopLeft,
            "top" | "topcenter" | "centertop" => Self::Top,
            "topright" | "righttop" => Self::TopRight,
            "left" | "leftcenter" | "centerleft" => Self::Left,
            "center" | "centre" | "middle" => Self::Center,
            "right" | "rightcenter" | "centerright" => Self::Right,
            "bottomleft" | "leftbottom" => Self::BottomLeft,
            "bottom" | "bottomcenter" | "centerbottom" => Self::Bottom,
            "bottomright" | "rightbottom" => Self::BottomRight,
            "cursor" | "pointer" | "mouse" => Self::Cursor,
            _ => return None,
        })
    }

    /// Edges to anchor to. An axis with no anchored edge is centered by the
    /// compositor, which is how the *-center variants work.
    pub fn edges(self) -> &'static [Edge] {
        match self {
            Self::TopLeft => &[Edge::Top, Edge::Left],
            Self::Top => &[Edge::Top],
            Self::TopRight => &[Edge::Top, Edge::Right],
            Self::Left => &[Edge::Left],
            Self::Center => &[],
            Self::Right => &[Edge::Right],
            Self::BottomLeft => &[Edge::Bottom, Edge::Left],
            Self::Bottom => &[Edge::Bottom],
            Self::BottomRight => &[Edge::Bottom, Edge::Right],
            // Positioned from computed margins instead; see ui::place_at_cursor.
            Self::Cursor => &[Edge::Top, Edge::Left],
        }
    }
}

/// Margins that put a `width`-wide panel over `cursor`, within `monitor`.
///
/// Horizontal is centred on the pointer; vertical is just `gap` from whichever
/// edge the pointer is nearest. Using the edge rather than the pointer's own y
/// means layer-shell's exclusive-zone handling puts the panel directly against
/// the bar, instead of leaving a gap the cursor has to cross to reach it.
pub fn cursor_margins(
    cursor: (i32, i32),
    monitor: (i32, i32, i32, i32),
    width: i32,
    gap: i32,
) -> (i32, i32, bool) {
    let (cx, cy) = cursor;
    let (mx, my, mw, mh) = monitor;

    // Centre on the pointer, but never let the panel hang off the monitor.
    let max_left = (mw - width - gap).max(gap);
    let left = (cx - mx - width / 2).clamp(gap, max_left);

    let below = (cy - my) < mh / 2;
    (left, gap, below)
}

#[derive(Clone, Copy, Debug)]
pub struct Config {
    pub anchor: Anchor,
    pub margin: i32,
    pub width: i32,
    pub max_height: i32,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            anchor: Anchor::TopRight,
            margin: 6,
            width: 360,
            max_height: 420,
        }
    }
}

pub const HELP: &str = "\
blurs — a tiny Bluetooth applet

USAGE:
    blurs [OPTIONS]

OPTIONS:
    -a, --anchor <POS>   Where to draw, relative to the screen.
                         top-left     top      top-right
                         left         center   right
                         bottom-left  bottom   bottom-right
                         [default: top-right]
    -m, --margin <PX>    Gap from the anchored screen edges [default: 6]
    -w, --width <PX>     Panel width [default: 360]
        --max-height <PX>  Max device-list height before scrolling [default: 420]
    -h, --help           Show this message

CONFIG:
    ~/.config/blurs/config, one `key = value` per line, same names as the
    long options above. Command-line arguments win.

    anchor = bottom-right
    margin = 8
";

fn apply(cfg: &mut Config, key: &str, value: &str) -> Result<(), String> {
    let num = |v: &str| v.parse::<i32>().map_err(|_| format!("{key}: not a number: {v}"));
    match key {
        "anchor" => {
            cfg.anchor =
                Anchor::parse(value).ok_or_else(|| format!("unknown anchor: {value}"))?;
        }
        "margin" => cfg.margin = num(value)?,
        "width" => cfg.width = num(value)?,
        "max-height" | "max_height" => cfg.max_height = num(value)?,
        _ => return Err(format!("unknown option: {key}")),
    }
    Ok(())
}

fn from_file(cfg: &mut Config) {
    let Some(home) = std::env::var("HOME").ok() else {
        return;
    };
    let Ok(text) = std::fs::read_to_string(format!("{home}/.config/blurs/config")) else {
        return;
    };
    for line in text.lines() {
        let line = line.split('#').next().unwrap_or("").trim();
        if line.is_empty() {
            continue;
        }
        if let Some((k, v)) = line.split_once('=')
            && let Err(e) = apply(cfg, k.trim(), v.trim())
        {
            eprintln!("blurs: config: {e}");
        }
    }
}

/// Returns `Err(message)` for `--help` and for bad input; the caller prints it
/// and exits, so this stays free of process control.
pub fn load(args: impl Iterator<Item = String>) -> Result<Config, String> {
    let mut cfg = Config::default();
    from_file(&mut cfg);

    let mut args = args.peekable();
    while let Some(arg) = args.next() {
        let (key, inline) = match arg.split_once('=') {
            Some((k, v)) => (k.to_string(), Some(v.to_string())),
            None => (arg, None),
        };
        let name = match key.as_str() {
            "-h" | "--help" => return Err(HELP.to_string()),
            "-a" | "--anchor" => "anchor",
            "-m" | "--margin" => "margin",
            "-w" | "--width" => "width",
            "--max-height" => "max-height",
            other => return Err(format!("unknown argument: {other}\n\n{HELP}")),
        };
        let value = match inline {
            Some(v) => v,
            None => args
                .next()
                .ok_or_else(|| format!("{key} needs a value\n\n{HELP}"))?,
        };
        apply(&mut cfg, name, &value)?;
    }
    Ok(cfg)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn load_args(v: &[&str]) -> Result<Config, String> {
        load(v.iter().map(|s| s.to_string()))
    }

    #[test]
    fn anchor_spelling_is_forgiving() {
        for s in ["bottom-right", "bottom_right", "BottomRight", " RIGHT-BOTTOM "] {
            assert_eq!(Anchor::parse(s), Some(Anchor::BottomRight), "failed on {s:?}");
        }
        assert_eq!(Anchor::parse("sideways"), None);
    }

    #[test]
    fn center_variants_anchor_one_axis_only() {
        assert_eq!(Anchor::Top.edges(), &[Edge::Top]);
        assert!(Anchor::Center.edges().is_empty());
        assert_eq!(Anchor::BottomLeft.edges().len(), 2);
    }

    #[test]
    fn args_parse_both_split_and_inline() {
        let a = load_args(&["--anchor", "bottom-left", "--margin", "12"]).unwrap();
        assert_eq!(a.anchor, Anchor::BottomLeft);
        assert_eq!(a.margin, 12);

        let b = load_args(&["--anchor=top-left", "-m=3"]).unwrap();
        assert_eq!(b.anchor, Anchor::TopLeft);
        assert_eq!(b.margin, 3);
    }

    // DP-2 in the real setup: 2560x1440 at the origin.
    const MON: (i32, i32, i32, i32) = (0, 0, 2560, 1440);

    #[test]
    fn cursor_centres_the_panel_horizontally() {
        let (left, _, _) = cursor_margins((1200, 1400), MON, 360, 8);
        assert_eq!(left, 1200 - 180);
    }

    #[test]
    fn cursor_near_an_edge_does_not_hang_off_screen() {
        let (left, _, _) = cursor_margins((5, 1400), MON, 360, 8);
        assert_eq!(left, 8, "clamped to the left gap");

        let (left, _, _) = cursor_margins((2555, 1400), MON, 360, 8);
        assert_eq!(left, 2560 - 360 - 8, "clamped to the right gap");
    }

    #[test]
    fn vertical_side_follows_which_half_the_pointer_is_in() {
        let (_, v, below) = cursor_margins((1200, 1400), MON, 360, 8);
        assert!(!below, "bottom half opens upward");
        assert_eq!(v, 8);

        let (_, v, below) = cursor_margins((1200, 20), MON, 360, 8);
        assert!(below, "top half opens downward");
        assert_eq!(v, 8);
    }

    #[test]
    fn vertical_margin_ignores_pointer_distance_from_the_edge() {
        // Both are in the bottom half; the panel should sit against the bar
        // either way rather than tracking how high up the bar the pointer was.
        let (_, a, _) = cursor_margins((1200, 1400), MON, 360, 8);
        let (_, b, _) = cursor_margins((1200, 1200), MON, 360, 8);
        assert_eq!(a, b);
    }

    #[test]
    fn cursor_margins_are_monitor_local() {
        // HDMI-A-1 sits at x=2560, so a pointer there maps back near zero.
        let right = (2560, -25, 2560, 1440);
        let (left, _, _) = cursor_margins((2560 + 1200, -25 + 1400), right, 360, 8);
        assert_eq!(left, 1200 - 180);
    }

    #[test]
    fn a_panel_wider_than_the_monitor_still_yields_a_sane_margin() {
        let tiny = (0, 0, 200, 400);
        let (left, _, _) = cursor_margins((100, 380), tiny, 360, 8);
        assert_eq!(left, 8, "gap wins rather than producing a negative margin");
    }

    #[test]
    fn bad_input_is_reported_not_ignored() {
        assert!(load_args(&["--anchor", "nowhere"]).is_err());
        assert!(load_args(&["--margin", "wide"]).is_err());
        assert!(load_args(&["--nonsense"]).is_err());
        assert!(load_args(&["--anchor"]).is_err());
        assert!(load_args(&["--help"]).is_err());
    }
}
