use std::fmt::Write as _;

const FALLBACK: &[(&str, &str)] = &[
    ("background", "#0b090b"),
    ("foreground", "#b2c7b1"),
    ("color1", "#353b44"),
    ("color2", "#3c4348"),
    ("color3", "#11586b"),
    ("color4", "#4a7a8c"),
    ("color5", "#6b9aa8"),
    ("color8", "#7c8b7b"),
];

/// pywal's colors.sh is `name='#rrggbb'` per line. Chosen over colors.json
/// purely to keep a JSON parser out of the binary.
fn parse_colors_sh(text: &str) -> Vec<(String, String)> {
    let mut out = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('#') {
            continue;
        }
        let Some((name, value)) = line.split_once('=') else {
            continue;
        };
        let name = name.trim();
        let value = value.trim().trim_matches('\'').trim_matches('"');

        // colors.sh also holds wallpaper='/path/to.jpg', so require a hex shape.
        let is_hex = value.len() == 7
            && value.starts_with('#')
            && value[1..].chars().all(|c| c.is_ascii_hexdigit());
        if is_hex && !name.is_empty() {
            out.push((name.to_string(), value.to_string()));
        }
    }
    out
}

fn home() -> Option<String> {
    std::env::var("HOME").ok()
}

fn color_definitions() -> String {
    let colors = home()
        .map(|h| format!("{h}/.cache/wal/colors.sh"))
        .and_then(|p| std::fs::read_to_string(p).ok())
        .map(|t| parse_colors_sh(&t))
        .filter(|c| !c.is_empty())
        .unwrap_or_default();

    let lookup = |key: &str| -> Option<&str> {
        colors
            .iter()
            .find(|(n, _)| n == key)
            .map(|(_, v)| v.as_str())
            .or_else(|| FALLBACK.iter().find(|(n, _)| *n == key).map(|(_, v)| *v))
    };

    let pairs = [
        ("bl_bg", "background"),
        ("bl_fg", "foreground"),
        ("bl_dim", "color8"),
        ("bl_accent", "color3"),
        ("bl_accent_soft", "color2"),
        ("bl_surface", "color1"),
        ("bl_hover", "color2"),
    ];

    let mut css = String::new();
    for (gtk_name, wal_name) in pairs {
        if let Some(v) = lookup(wal_name) {
            let _ = writeln!(css, "@define-color {gtk_name} {v};");
        }
    }
    css
}

pub fn stylesheet() -> String {
    let base = home()
        .map(|h| format!("{h}/.config/blurs/style.css"))
        .and_then(|p| std::fs::read_to_string(p).ok())
        .unwrap_or_else(|| include_str!("../style.css").to_string());

    format!("{}\n{}", color_definitions(), base)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ignores_the_wallpaper_path() {
        let sh = "wallpaper='/home/x/a.jpg'\nbackground='#0B090B'\ncolor1='#353B44'\n";
        assert_eq!(
            parse_colors_sh(sh),
            vec![
                ("background".to_string(), "#0B090B".to_string()),
                ("color1".to_string(), "#353B44".to_string()),
            ]
        );
    }

    #[test]
    fn skips_comments_and_malformed_lines() {
        let sh = "# Shell variables\nnot_a_pair\nfg='#zzzzzz'\ncolor2='#3C4348'\n";
        assert_eq!(
            parse_colors_sh(sh),
            vec![("color2".to_string(), "#3C4348".to_string())]
        );
    }

    #[test]
    fn every_semantic_color_is_defined_without_pywal() {
        let css = color_definitions();
        for name in ["bl_bg", "bl_fg", "bl_dim", "bl_accent", "bl_surface"] {
            assert!(css.contains(name), "missing {name} in:\n{css}");
        }
    }
}
