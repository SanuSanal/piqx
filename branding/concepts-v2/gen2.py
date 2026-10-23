"""Piqx logo concepts, round 2 — aligned to the app's design language.

Design language (lib/theme/app_theme.dart): dark-first surfaces (#111318), electric green #00F59B
(primary), vibrant cyan #00D2FF (secondary), signal red reserved for LIVE, Space Grotesk 600/700 display
type with tight tracking, 12-16 px card radii and pills. Name is set "PiqX".
"""
import json, math, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "out2"
os.makedirs(OUT, exist_ok=True)
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "pylib"))
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.boundsPen import BoundsPen

FONT = "D:/claude/piqx/assets/fonts/SpaceGrotesk-700.ttf"

# palette (dark / light)
SURFACE = "#111318"; ON_DARK = "#E2E2E9"; ON_LIGHT = "#111318"
GREEN = "#00F59B"; CYAN = "#00D2FF"; GREEN_L = "#00965E"; CYAN_L = "#007C99"


def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def pt(p):
    return f"{f(p[0])} {f(p[1])}"

def svg(w, h, body, title, defs=""):
    d = f"<defs>{defs}</defs>" if defs else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(w)} {f(h)}" role="img">'
            f'<title>{title}</title>{d}{body}</svg>\n')

def save(name, content):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fh:
        fh.write(content)

def circle_path(cx, cy, r, ccw=False):
    s = 0 if ccw else 1
    return (f"M{f(cx-r)} {f(cy)}A{f(r)} {f(r)} 0 1 {s} {f(cx+r)} {f(cy)}"
            f"A{f(r)} {f(r)} 0 1 {s} {f(cx-r)} {f(cy)}Z")

def fillet(A, V, B, r):
    u1 = (A[0]-V[0], A[1]-V[1]); l1 = math.hypot(*u1); u1 = (u1[0]/l1, u1[1]/l1)
    u2 = (B[0]-V[0], B[1]-V[1]); l2 = math.hypot(*u2); u2 = (u2[0]/l2, u2[1]/l2)
    th = math.acos(max(-1, min(1, u1[0]*u2[0] + u1[1]*u2[1])))
    d = r / math.tan(th/2)
    T1 = (V[0]+u1[0]*d, V[1]+u1[1]*d); T2 = (V[0]+u2[0]*d, V[1]+u2[1]*d)
    cross = (V[0]-A[0])*(B[1]-V[1]) - (V[1]-A[1])*(B[0]-V[0])
    return T1, T2, 1 if cross > 0 else 0

def rounded_poly(pts, r):
    n = len(pts); out = ""
    for i in range(n):
        T1, T2, s = fillet(pts[i-1], pts[i], pts[(i+1) % n], r)
        out += (f"M{pt(T1)}" if i == 0 else f"L{pt(T1)}") + f"A{f(r)} {f(r)} 0 0 {s} {pt(T2)}"
    return out + "Z"

def line_circle(P, d, c, r):
    fx, fy = P[0]-c[0], P[1]-c[1]
    a = d[0]**2 + d[1]**2; b = 2*(fx*d[0] + fy*d[1]); cc = fx*fx + fy*fy - r*r
    disc = math.sqrt(b*b - 4*a*cc)
    return sorted([(-b - disc)/(2*a), (-b + disc)/(2*a)])

def arc_to(P, Q, c, r):
    d = (Q[0]-P[0], Q[1]-P[1])
    sweep = 1 if ((c[0]-P[0])*(-d[1]) + (c[1]-P[1])*d[0]) > 0 else 0
    return f"A{f(r)} {f(r)} 0 0 {sweep} {pt(Q)}"


# ------------------------------------------------------------------ C: Match point X
def x_ball(top, bot, w, rc, ball, cx, cy, r=0.0):
    """X at exact 60 degrees, horizontal terminals, crossing cut by a disc, ball inside."""
    h = bot - top; ang = math.radians(60)
    hw = w / math.sin(ang)
    width = h / math.tan(ang) + hw
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
            # upper arm: round the two terminal corners
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
    return "".join(arms), circle_path(cx, cy, ball), (left, right)

def c_mark(arm="#000", ball_fill="#000"):
    arms, ballp, _ = x_ball(32, 224, 46, 46, 31, 128, 128, r=6)
    return f'<path d="{arms}" fill="{arm}"/><path d="{ballp}" fill="{ball_fill}"/>'


# ------------------------------------------------------------------ B: On-air P
def b_mark(body="#000", dot="#000"):
    top, bot = 32, 224; R = 68; rin = 34; stem = 38; r = 6
    width = stem + rin + R          # stem + counter radius + outer radius
    sx = 128 - width/2; cx = sx + stem + rin; cy = top + R
    d = (f"M{f(sx)} {f(top+r)}A{r} {r} 0 0 1 {f(sx+r)} {f(top)}H{f(cx)}"
         f"A{R} {R} 0 0 1 {f(cx)} {f(top+2*R)}H{f(sx+stem)}V{f(bot-r)}"
         f"A{r} {r} 0 0 1 {f(sx+stem-r)} {f(bot)}H{f(sx+r)}A{r} {r} 0 0 1 {f(sx)} {f(bot-r)}Z")
    d += circle_path(cx, cy, rin, ccw=True)
    return (f'<path d="{d}" fill="{body}" fill-rule="evenodd"/>'
            f'<path d="{circle_path(cx, cy, 17)}" fill="{dot}"/>')


# ------------------------------------------------------------------ A: Play diamond (evolution)
def rsquare(cx, cy, side, r):
    h = side/2
    return rounded_poly([(cx-h, cy-h), (cx+h, cy-h), (cx+h, cy+h), (cx-h, cy+h)], r)

def a_mark(tri="#000", ring="#000", uid="a"):
    dcx, dcy = 156, 128; so, si = 120, 72; gap = 10
    rot = f'transform="rotate(45 {dcx} {dcy})"'
    ringd = rsquare(dcx, dcy, so, 26) + rsquare(dcx, dcy, si, 12)
    knock = rsquare(dcx, dcy, so + 2*gap, 36) + rsquare(dcx, dcy, si - 2*gap, 6)
    h = 86; x0 = 26; tip = x0 + h*math.sqrt(3)
    trid = rounded_poly([(x0, 128-h), (tip, 128), (x0, 128+h)], 12)
    defs = (f'<mask id="k{uid}" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256">'
            f'<rect width="256" height="256" fill="#fff"/>'
            f'<path d="{knock}" fill="#000" fill-rule="evenodd" {rot}/></mask>')
    body = (f'<path d="{trid}" fill="{tri}" mask="url(#k{uid})"/>'
            f'<path d="{ringd}" fill="{ring}" fill-rule="evenodd" {rot}/>')
    return body, defs


# ------------------------------------------------------------------ wordmark (Space Grotesk Bold outlines)
font = TTFont(FONT); gs = font.getGlyphSet(); cmap = font.getBestCmap()
CAP = 700; TRACK = -18

def glyph(ch, k, x, base):
    g = cmap[ord(ch)]
    pen = SVGPathPen(gs)
    gs[g].draw(TransformPen(pen, (k, 0, 0, -k, x, base)))
    bp = BoundsPen(gs); gs[g].draw(bp)
    return pen.getCommands(), font['hmtx'][g][0], bp.bounds

def wordmark(k, base, x0, text_fill, x_fill, custom_x=None):
    """'PiqX' with P i q from Space Grotesk Bold; X either the font's (coloured) or the Match point X."""
    parts = []; x = x0
    _, _, bP = glyph("P", 1, 0, 0)
    x -= bP[0]*k                      # start the ink at x0
    for ch in "Piq":
        d, adv, _ = glyph(ch, k, x, base)
        parts.append(d); x += (adv + TRACK)*k
    body = f'<path d="{"".join(parts)}" fill="{text_fill}"/>'
    if custom_x is None:
        d, adv, b = glyph("X", k, x, base)
        body += f'<path d="{d}" fill="{x_fill}"/>'
        right = x + b[2]*k
    else:
        arm_fill, ball_fill = custom_x
        lsb = 22*k
        top, bot = base - CAP*k, base
        w = 136*k; rc = 124*k; ball = 76*k
        hw = w / math.sin(math.radians(60)); width = (bot-top)/math.tan(math.radians(60)) + hw
        cx = x + lsb + width/2; cy = (top + bot)/2
        arms, ballp, (l, rgt) = x_ball(top, bot, w, rc, ball, cx, cy)
        body += f'<path d="{arms}" fill="{arm_fill}"/><path d="{ballp}" fill="{ball_fill}"/>'
        right = rgt
    return body, right

def wordmark_svg(name, text_fill, x_fill, custom_x=None, bg=None):
    k = 0.24
    base = 128 + (714 - 200)*k/2    # fit i-dot to q descender inside 256
    body, right = wordmark(k, base, 12, text_fill, x_fill, custom_x)
    W = right + 24
    bgr = f'<rect width="{f(W)}" height="256" fill="{bg}"/>' if bg else ""
    save(name, svg(W, 256, bgr + body, "PiqX wordmark"))
    return W

def tile(inner, defs="", bg=SURFACE, scale=0.70):
    t = (128 - 128*scale)
    return (f'<rect width="256" height="256" rx="56" fill="{bg}"/>'
            f'<g transform="translate({f(t)} {f(t)}) scale({scale})">{inner}</g>'), defs

def lockup_svg(name, mark_body, defs, text_fill, x_fill, custom_x=None, bg=None):
    k = 0.16; base = 128 + CAP*k/2
    wm, right = wordmark(k, base, 256 + 24, text_fill, x_fill, custom_x)
    W = right + 24
    bgr = f'<rect width="{f(W)}" height="256" fill="{bg}"/>' if bg else ""
    save(name, svg(W, 256, bgr + mark_body + wm, "PiqX lockup", defs))
    return W


# ------------------------------------------------------------------ outputs
# A
a_body, a_defs = a_mark(GREEN, CYAN, "a")
save("a-mark.svg", svg(256, 256, a_body, "PiqX A mark", a_defs))
a_bk, a_bkd = a_mark("#000", "#000", "ab")
save("a-mark-black.svg", svg(256, 256, a_bk, "PiqX A mark black", a_bkd))
tb, td = tile(*a_mark(GREEN, CYAN, "at"))
save("a-icon.svg", svg(256, 256, tb, "PiqX A icon", td))
al, ald = a_mark(GREEN_L, CYAN_L, "al")
lockup_svg("a-lockup-light.svg", al, ald, ON_LIGHT, GREEN_L)
ad, add = a_mark(GREEN, CYAN, "ad")
lockup_svg("a-lockup-dark.svg", ad, add, ON_DARK, GREEN, bg=SURFACE)

# B
save("b-mark.svg", svg(256, 256, b_mark(GREEN, CYAN), "PiqX B mark"))
save("b-mark-black.svg", svg(256, 256, b_mark(), "PiqX B mark black"))
tb, td = tile(b_mark(GREEN, CYAN))
save("b-icon.svg", svg(256, 256, tb, "PiqX B icon"))
lockup_svg("b-lockup-light.svg", b_mark(GREEN_L, CYAN_L), "", ON_LIGHT, GREEN_L)
lockup_svg("b-lockup-dark.svg", b_mark(GREEN, CYAN), "", ON_DARK, GREEN, bg=SURFACE)

# C
save("c-mark.svg", svg(256, 256, c_mark(GREEN, CYAN), "PiqX C mark"))
save("c-mark-black.svg", svg(256, 256, c_mark(), "PiqX C mark black"))
tb, td = tile(c_mark(GREEN, CYAN))
save("c-icon.svg", svg(256, 256, tb, "PiqX C icon"))
lockup_svg("c-lockup-light.svg", c_mark(GREEN_L, CYAN_L), "", ON_LIGHT, None, (GREEN_L, CYAN_L))
lockup_svg("c-lockup-dark.svg", c_mark(GREEN, CYAN), "", ON_DARK, None, (GREEN, CYAN), bg=SURFACE)
wordmark_svg("c-wordmark-dark.svg", ON_DARK, None, (GREEN, CYAN), bg=SURFACE)
wordmark_svg("c-wordmark-light.svg", ON_LIGHT, None, (GREEN_L, CYAN_L))
wordmark_svg("c-wordmark-black.svg", "#000", None, ("#000", "#000"))
wordmark_svg("ab-wordmark-dark.svg", ON_DARK, GREEN, bg=SURFACE)
print("ok")


# ------------------------------------------------------------------ in-app preview (splash + header)
def g(body, x, y, sc):
    return f'<g transform="translate({f(x)} {f(y)}) scale({f(sc)})">{body}</g>'

def preview():
    PW, PH, M = 380, 640, 24
    defs = (f'<radialGradient id="glow"><stop offset="0" stop-color="{GREEN}" stop-opacity=".16"/>'
            f'<stop offset=".5" stop-color="{CYAN}" stop-opacity=".05"/><stop offset="1" stop-color="{CYAN}" stop-opacity="0"/></radialGradient>')
    out = ""
    concepts = [("A", "Play diamond"), ("B", "On-air P"), ("C", "Match point")]
    for i, (letter, name) in enumerate(concepts):
        ox = M + i*(PW + M); oy = 56
        out += (f'<text x="{ox}" y="36" font-family="Space Grotesk, sans-serif" font-weight="700" font-size="18" fill="#111318">'
                f'{letter} · {name}</text>')
        out += f'<rect x="{ox}" y="{oy}" width="{PW}" height="{PH}" rx="28" fill="{SURFACE}"/>'
        # header bar
        out += f'<rect x="{ox}" y="{oy}" width="{PW}" height="64" rx="28" fill="#1A1B21"/><rect x="{ox}" y="{oy+36}" width="{PW}" height="28" fill="#1A1B21"/>'
        hy = oy + 32
        if letter == "C":
            k = 18/CAP; body, right = wordmark(k, hy + 9, ox + 16, ON_DARK, None, (GREEN, CYAN))
            out += body
        else:
            if letter == "A":
                mb, md = a_mark(GREEN, CYAN, f"h{i}"); defs += md
            else:
                mb = b_mark(GREEN, CYAN)
            sc = 26/192
            out += g(mb, ox + 16 - 32*sc, hy - 128*sc, sc)
            k = 16/CAP; body, _ = wordmark(k, hy + 8, ox + 16 + 26 + 8, ON_DARK, GREEN)
            out += body
        # splash
        cy = oy + PH/2 + 10
        out += f'<circle cx="{ox+PW/2}" cy="{cy}" r="160" fill="url(#glow)"/>'
        if letter == "C":
            k = 200/ (2100) ; body, right = wordmark(k, 0, 0, ON_DARK, None, (GREEN, CYAN))
            w = right; k2 = k * 168 / w
            body, right = wordmark(k2, cy + CAP*k2/2, ox + PW/2 - 84, ON_DARK, None, (GREEN, CYAN))
            out += body
        else:
            if letter == "A":
                mb, md = a_mark(GREEN, CYAN, f"s{i}"); defs += md
            else:
                mb = b_mark(GREEN, CYAN)
            sc = 64/192
            k = 0.16*sc
            _, right = wordmark(k, 0, 0, ON_DARK, GREEN)
            total = 256*sc - 32*sc*2 + 24*sc + right   # mark ink + gap + wordmark
            x0 = ox + PW/2 - total/2
            out += g(mb, x0 - 32*sc, cy - 128*sc, sc)
            body, _ = wordmark(k, cy + CAP*k/2, x0 + 192*sc + 24*sc, ON_DARK, GREEN)
            out += body
        out += (f'<text x="{ox+PW/2}" y="{cy+76}" text-anchor="middle" font-family="Space Grotesk, sans-serif" font-weight="600" '
                f'font-size="11" letter-spacing=".7" fill="#B9CBBD">LIVE FOOTBALL &amp; CRICKET STREAMS</text>')
        # progress track
        out += (f'<rect x="{ox+PW/2-70}" y="{oy+PH-56}" width="140" height="4" rx="2" fill="#fff" fill-opacity=".12"/>'
                f'<rect x="{ox+PW/2-70}" y="{oy+PH-56}" width="90" height="4" rx="2" fill="{GREEN}"/>')
    W = M + 3*(PW + M)
    save("preview.svg", svg(W, oy + PH + M, f'<rect width="{W}" height="{oy+PH+M}" fill="#F4F6F9"/>' + out, "PiqX in app", defs))
preview()
