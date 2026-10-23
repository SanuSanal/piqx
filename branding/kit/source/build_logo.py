"""Build the PiqX "Match point" logo masters (SVG).

The X of PiqX is drawn at exactly 60 degrees; a disc is cut from its crossing and a ball sits inside it,
so the "vs" of every fixture carries the live game at its heart. "Piq" and the tagline are outlines of
Space Grotesk (SIL Open Font License), the app's display face.

Requires fontTools (pip install fonttools). Usage:
    python build_logo.py [out_dir]
"""
import math, os, re, sys

from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "svg")
os.makedirs(OUT, exist_ok=True)

# Palette — matches lib/theme/app_theme.dart
NIGHT = "#111318"        # surface (dark)
MIST = "#E2E2E9"         # onSurface (dark)
GREEN = "#00F59B"        # primaryContainer — electric green
CYAN = "#00D2FF"         # secondaryContainer — vibrant cyan
GREEN_DEEP = "#00965E"   # primaryText (light)
CYAN_DEEP = "#007C99"    # secondaryText (light)

SCHEMES = {
    # name: (text, arms, ball)
    "on-dark": (MIST, GREEN, CYAN),
    "on-light": (NIGHT, GREEN_DEEP, CYAN_DEEP),
    "white": ("#FFFFFF", "#FFFFFF", "#FFFFFF"),
    "black": ("#000000", "#000000", "#000000"),
}


def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def pt(p):
    return f"{f(p[0])} {f(p[1])}"

def svg(box, body, title):
    x, y, w, h = box
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{f(x)} {f(y)} {f(w)} {f(h)}" '
            f'width="{f(w)}" height="{f(h)}" role="img"><title>{title}</title>{body}</svg>\n')

def save(name, content):
    content = re.sub(r"-?\d+\.\d{3,}", lambda m: f(float(m.group())), content)  # 2-decimal precision
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fh:
        fh.write(content)

def circle_path(cx, cy, r):
    return (f"M{f(cx-r)} {f(cy)}A{f(r)} {f(r)} 0 1 1 {f(cx+r)} {f(cy)}"
            f"A{f(r)} {f(r)} 0 1 1 {f(cx-r)} {f(cy)}Z")

def fillet(A, V, B, r):
    """Tangent points and sweep flag for rounding corner V between neighbours A and B."""
    u1 = (A[0]-V[0], A[1]-V[1]); l1 = math.hypot(*u1); u1 = (u1[0]/l1, u1[1]/l1)
    u2 = (B[0]-V[0], B[1]-V[1]); l2 = math.hypot(*u2); u2 = (u2[0]/l2, u2[1]/l2)
    th = math.acos(max(-1, min(1, u1[0]*u2[0] + u1[1]*u2[1])))
    d = r / math.tan(th/2)
    cross = (V[0]-A[0])*(B[1]-V[1]) - (V[1]-A[1])*(B[0]-V[0])
    return (V[0]+u1[0]*d, V[1]+u1[1]*d), (V[0]+u2[0]*d, V[1]+u2[1]*d), 1 if cross > 0 else 0

def line_circle(P, d, c, r):
    fx, fy = P[0]-c[0], P[1]-c[1]
    a = d[0]**2 + d[1]**2; b = 2*(fx*d[0] + fy*d[1]); cc = fx*fx + fy*fy - r*r
    disc = math.sqrt(b*b - 4*a*cc)
    return sorted([(-b - disc)/(2*a), (-b + disc)/(2*a)])

def arc_to(P, Q, c, r):
    d = (Q[0]-P[0], Q[1]-P[1])
    sweep = 1 if ((c[0]-P[0])*(-d[1]) + (c[1]-P[1])*d[0]) > 0 else 0
    return f"A{f(r)} {f(r)} 0 0 {sweep} {pt(Q)}"


# ---------------------------------------------------------------- the X
def match_point(top, bot, w, rc, ball, cx, r=0.0):
    """Arms and ball of the Match point X.

    top/bot: terminal lines; w: perpendicular arm weight; rc: radius of the disc cut from the crossing
    (kept > w so the inner crotches fall inside the cut and never leave a sliver); ball: ball radius;
    r: corner radius on the terminals. Returns (arms_d, ball_d, left, right).
    """
    assert rc > w, "crotch must fall inside the cut"
    cy = (top + bot) / 2
    ang = math.radians(60)
    hw = w / math.sin(ang)
    width = (bot - top) / math.tan(ang) + hw
    left, right = cx - width/2, cx + width/2
    c = (cx, cy); arms = []
    bars = [(((left, top), (right - hw, bot)), ((left + hw, top), (right, bot))),
            (((right - hw, top), (left, bot)), ((right, top), (left + hw, bot)))]
    for e1, e2 in bars:
        hits = []
        for P, Q in (e1, e2):
            d = (Q[0]-P[0], Q[1]-P[1]); t0, t1 = line_circle(P, d, c, rc)
            hits.append(((P[0]+d[0]*t0, P[1]+d[1]*t0), (P[0]+d[0]*t1, P[1]+d[1]*t1)))
        (a_in, a_out), (b_in, b_out) = hits
        if r:
            A1, A2, s1 = fillet(a_in, e1[0], e2[0], r)
            B1, B2, s2 = fillet(e1[0], e2[0], b_in, r)
            arms.append(f"M{pt(A1)}A{f(r)} {f(r)} 0 0 {s1} {pt(A2)}L{pt(B1)}A{f(r)} {f(r)} 0 0 {s2} {pt(B2)}"
                        f"L{pt(b_in)}{arc_to(b_in, a_in, c, rc)}Z")
            C1, C2, s3 = fillet(a_out, e1[1], e2[1], r)
            D1, D2, s4 = fillet(e1[1], e2[1], b_out, r)
            arms.append(f"M{pt(a_out)}L{pt(C1)}A{f(r)} {f(r)} 0 0 {s3} {pt(C2)}L{pt(D1)}"
                        f"A{f(r)} {f(r)} 0 0 {s4} {pt(D2)}L{pt(b_out)}{arc_to(b_out, a_out, c, rc)}Z")
        else:
            arms.append(f"M{pt(e1[0])}L{pt(e2[0])}L{pt(b_in)}{arc_to(b_in, a_in, c, rc)}Z")
            arms.append(f"M{pt(e1[1])}L{pt(a_out)}{arc_to(a_out, b_out, c, rc)}L{pt(e2[1])}Z")
    return "".join(arms), circle_path(cx, cy, ball), left, right

# Symbol on the 256 grid: X 192 tall, arms 46, cut 52, ball 34 (gap 18), terminals rounded 6.
SYMBOL = dict(top=32, bot=224, w=46, rc=52, ball=34, cx=128, r=6)
# Small-size cut (<= 32 px): heavier arms, wider gap, bigger ball.
SYMBOL_SMALL = dict(top=28, bot=228, w=54, rc=60, ball=38, cx=128, r=5)

def symbol_body(arms_fill, ball_fill, spec=SYMBOL):
    arms, ball, _, _ = match_point(**spec)
    return f'<path d="{arms}" fill="{arms_fill}"/><path d="{ball}" fill="{ball_fill}"/>'


# ---------------------------------------------------------------- type
FONTS = os.path.join(ROOT, "assets", "fonts")
BOLD = TTFont(os.path.join(FONTS, "SpaceGrotesk-700.ttf"))
SEMI = TTFont(os.path.join(FONTS, "SpaceGrotesk-600.ttf"))
CAP, DOT_TOP, DESC = 700, 714, 200
TRACK = -18   # ~ -2 %, as the app's display styles

def glyph(font, ch, k, x, base):
    gs = font.getGlyphSet(); g = font.getBestCmap()[ord(ch)]
    pen = SVGPathPen(gs)
    gs[g].draw(TransformPen(pen, (k, 0, 0, -k, x, base)))
    bp = BoundsPen(gs); gs[g].draw(bp)
    return pen.getCommands(), font["hmtx"][g][0], bp.bounds

def wordmark(k, base, x0, text, arms, ball):
    """'Piq' in Space Grotesk Bold + the Match point X at text weight. Returns (body, right)."""
    x = x0 - glyph(BOLD, "P", 1, 0, 0)[2][0]*k
    parts = []
    for ch in "Piq":
        d, adv, _ = glyph(BOLD, ch, k, x, base)
        parts.append(d); x += (adv + TRACK)*k
    a, b, _, right = match_point(top=base - CAP*k, bot=base, w=136*k, rc=150*k, ball=98*k,
                                 cx=0, r=0)  # measure width first
    width = right * 2
    a, b, _, right = match_point(top=base - CAP*k, bot=base, w=136*k, rc=150*k, ball=98*k,
                                 cx=x + 40*k + width/2, r=0)
    body = (f'<path d="{"".join(parts)}" fill="{text}"/>'
            f'<path d="{a}" fill="{arms}"/><path d="{b}" fill="{ball}"/>')
    return body, right

def tagline(text, track, top, x0, width, fill):
    """Set `text` in Space Grotesk SemiBold with `track` units of tracking, scaled to exactly `width`.
    Returns (body, baseline)."""
    glyphs = [glyph(SEMI, ch, 1, 0, 0) if ch != " " else (None, SEMI["hmtx"]["space"][0], None) for ch in text]
    first_l = glyphs[0][2][0]
    natural = sum(g[1] for g in glyphs[:-1]) + glyphs[-1][2][2] - first_l
    k = width / (natural + track*(len(text) - 1))
    base = top + CAP*k
    x = x0 - first_l*k; parts = []
    for ch, g in zip(text, glyphs):
        if ch != " ":
            parts.append(glyph(SEMI, ch, k, x, base)[0])
        x += (g[1] + track)*k
    return f'<path d="{"".join(parts)}" fill="{fill}"/>', base


# ---------------------------------------------------------------- outputs
def build():
    # Wordmark: cap height 140 at k=0.2; ink box is tight to i-dot / q-descender / X edges.
    k = 0.2; base = DOT_TOP*k
    _, right = wordmark(k, base, 0, "#000", "#000", "#000")
    ink_w, ink_h = right, (DOT_TOP + DESC)*k
    ring = 2*150*k            # clear-space unit: diameter of the disc cut from the X
    for name, (t, a, b) in SCHEMES.items():
        body, _ = wordmark(k, base, 0, t, a, b)
        save(f"piqx-wordmark-{name}.svg", svg((-ring/2, -ring/2, ink_w + ring, ink_h + ring), body, "PiqX"))
        save(f"piqx-wordmark-{name}-tight.svg", svg((0, 0, ink_w, ink_h), body, "PiqX"))

    # Stacked: wordmark over the tagline, tracked to the wordmark's width.
    for name, (t, a, b) in SCHEMES.items():
        body, _ = wordmark(k, base, 0, t, a, b)
        tag, h = tagline("LIVE SCORES & STREAMS", 140, ink_h + 0.4*CAP*k, 0, ink_w, t)
        save(f"piqx-stacked-{name}.svg",
             svg((-ring/2, -ring/2, ink_w + ring, h + ring), body + tag, "PiqX — live scores &amp; streams"))

    # Symbol (transparent), small-size cut, and app-icon tile.
    for name, (_, a, b) in SCHEMES.items():
        save(f"piqx-symbol-{name}.svg", svg((0, 0, 256, 256), symbol_body(a, b), "PiqX symbol"))
        save(f"piqx-symbol-small-{name}.svg", svg((0, 0, 256, 256), symbol_body(a, b, SYMBOL_SMALL), "PiqX symbol"))
    for name, spec, scale in (("piqx-app-icon.svg", SYMBOL, 0.68), ("piqx-app-icon-small.svg", SYMBOL_SMALL, 0.74)):
        t = 128 - 128*scale
        save(name, svg((0, 0, 256, 256),
                       f'<rect width="256" height="256" rx="56" fill="{NIGHT}"/>'
                       f'<g transform="translate({f(t)} {f(t)}) scale({scale})">{symbol_body(GREEN, CYAN, spec)}</g>',
                       "PiqX app icon"))
    print(f"wordmark ink {ink_w:.1f} x {ink_h:.1f}, ring {ring:.1f}")


if __name__ == "__main__":
    build()
