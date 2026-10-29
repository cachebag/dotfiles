import QtQuick

// Ring chart of a diskring tree. Each ring is one directory level, arc sweep is
// bytes on disk. Drawn on a Canvas and hit-tested with polar math, so a few
// thousand arcs cost one paint rather than one item each.
Item {
    id: root

    property var tree: null
    property string path: ""
    property var marked: ({})
    property string hoverPath: ""
    property int rings: 5

    signal hovered(var arc)
    signal clicked(var arc)
    signal marking(var arc)
    signal up

    readonly property real outer: Math.min(width, height) / 2 - 6
    readonly property real hole: outer * 0.30
    readonly property real ringWidth: (outer - hole) / rings

    property var arcs: []
    property real reveal: 1

    NumberAnimation {
        id: sweep
        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: 650
        easing.type: Easing.OutCubic
    }

    onTreeChanged: {
        arcs = layout(tree, path);
        sweep.restart();
    }
    onRevealChanged: canvas.requestPaint()
    onHoverPathChanged: canvas.requestPaint()
    onMarkedChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Connections {
        target: Theme
        function onPaletteChanged() {
            root.arcs = root.layout(root.tree, root.path);
            canvas.requestPaint();
        }
    }

    function join(base, name) {
        return base.endsWith("/") ? base + name : base + "/" + name;
    }

    // Canvas wants CSS colour strings, not QML colour values.
    function css(c) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a + ")";
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // pywal's 1..6 are the accent hues; cycle them across the top level. Dark
    // wallpapers give near-black accents, so pull lightness into a range that
    // reads against the card while keeping the hue.
    function hue(i) {
        const c = Qt.color(Theme.palette[1 + (i % 6)]);
        const h = Math.max(0, c.hslHue);
        const sat = c.hslHue < 0 ? 0 : Math.max(0.35, c.hslSaturation);
        return Qt.hsla(h, sat, Math.min(0.68, Math.max(0.52, c.hslLightness)), 1);
    }

    function layout(node, base) {
        const out = [];
        if (!node)
            return out;
        const walk = (n, p, a0, a1, depth, color) => {
            const kids = n.children || [];
            const span = a1 - a0;
            var a = a0;
            for (var i = 0; i < kids.length; i++) {
                const k = kids[i];
                const s = n.size > 0 ? span * k.size / n.size : 0;
                const kp = k.kind === "rest" ? "" : join(p, k.name);
                const c = depth === 0 ? hue(i) : color;
                // Siblings alternate shade so neighbours of one hue stay apart.
                const fill = mix(c, Theme.bg, Math.min(0.6, depth * 0.11 + (i % 2) * 0.08));
                out.push({
                    a0: a,
                    a1: a + s,
                    depth: depth + 1,
                    node: k,
                    path: kp,
                    fill: fill
                });
                if (k.children && depth + 1 < root.rings)
                    walk(k, kp, a, a + s, depth + 1, c);
                a += s;
            }
        };
        walk(node, base, 0, Math.PI * 2, 0, null);
        return out;
    }

    function isMarked(p) {
        for (const m in marked)
            if (p === m || p.startsWith(m + "/"))
                return true;
        return false;
    }

    function arcAt(x, y) {
        const dx = x - width / 2, dy = y - height / 2;
        const r = Math.sqrt(dx * dx + dy * dy);
        if (r < hole)
            return {
                center: true
            };
        if (r > outer)
            return null;
        const depth = Math.floor((r - hole) / ringWidth) + 1;
        // Clockwise from twelve o'clock, matching the paint.
        var t = Math.atan2(dy, dx) + Math.PI / 2;
        if (t < 0)
            t += Math.PI * 2;
        for (var i = 0; i < arcs.length; i++) {
            const a = arcs[i];
            if (a.depth === depth && t >= a.a0 && t < a.a1)
                return a;
        }
        return null;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.ringWidth < 4)
                return;
            const cx = width / 2, cy = height / 2;
            const off = -Math.PI / 2;
            const hp = root.hoverPath;
            const rev = root.reveal;

            for (var i = 0; i < root.arcs.length; i++) {
                const a = root.arcs[i];
                // Rings unfold outward: each starts a little after the one inside it.
                const local = Math.max(0, Math.min(1, rev * 1.6 - (a.depth - 1) * 0.12));
                if (local <= 0)
                    continue;
                const s = off + a.a0 * local, e = off + a.a1 * local;
                if (e - s < 0.002)
                    continue;
                const r0 = root.hole + (a.depth - 1) * root.ringWidth + 1;
                const r1 = r0 + root.ringWidth * (0.6 + 0.4 * local) - 2;

                const inBranch = hp !== "" && a.path !== "" && (a.path === hp || a.path.startsWith(hp + "/"));
                var fill;
                if (a.node.kind === "rest")
                    fill = Theme.alpha(Theme.muted, 0.18);
                else if (a.path !== "" && root.isMarked(a.path))
                    fill = Theme.alpha(Theme.urgent, 0.85);
                else
                    fill = inBranch ? Qt.lighter(a.fill, 1.35) : a.fill;

                ctx.globalAlpha = hp !== "" && !inBranch ? 0.45 : 1;
                ctx.beginPath();
                ctx.arc(cx, cy, r1, s, e, false);
                ctx.arc(cx, cy, r0, e, s, true);
                ctx.closePath();
                ctx.fillStyle = css(fill);
                ctx.fill();
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = css(Theme.bg);
                ctx.stroke();

                // Label arcs that have the room, written along the ring.
                const mid = root.hole + (a.depth - 0.5) * root.ringWidth;
                const room = (e - s) * mid;
                if (local === 1 && a.depth <= 3 && room > 44 && a.node.kind !== "rest") {
                    ctx.globalAlpha = hp !== "" && !inBranch ? 0.4 : 0.9;
                    ctx.font = "10px '" + Theme.font + "'";
                    var label = a.node.name;
                    while (label.length > 2 && ctx.measureText(label).width > room - 12)
                        label = label.slice(0, -2) + "…";
                    const m = (s + e) / 2;
                    // Keep text upright on the lower half.
                    const flip = Math.sin(m) > 0;
                    ctx.save();
                    ctx.translate(cx + Math.cos(m) * mid, cy + Math.sin(m) * mid);
                    ctx.rotate(m + (flip ? -Math.PI / 2 : Math.PI / 2));
                    ctx.fillStyle = css(Theme.bg);
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillText(label, 0, 0);
                    ctx.restore();
                }
            }
            ctx.globalAlpha = 1;
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property var current: null

        function track(mouse) {
            const a = root.arcAt(mouse.x, mouse.y);
            cursorShape = a && (a.center || a.node.kind === "dir") ? Qt.PointingHandCursor : Qt.ArrowCursor;
            if (a !== current) {
                current = a;
                root.hovered(a && !a.center ? a : null);
            }
        }

        onPositionChanged: mouse => track(mouse)
        onExited: {
            current = null;
            root.hovered(null);
        }
        onClicked: mouse => {
            const a = root.arcAt(mouse.x, mouse.y);
            if (!a)
                return;
            if (a.center) {
                if (mouse.button === Qt.LeftButton)
                    root.up();
            } else if (mouse.button === Qt.RightButton) {
                root.marking(a);
            } else {
                root.clicked(a);
            }
        }
    }
}
