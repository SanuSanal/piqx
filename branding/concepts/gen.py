"""Generate Piqx logo concepts (black, 256 grid)."""
import math, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)

def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s

def pt(p):
    return f"{f(p[0])} {f(p[1])}"

def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {f(w)} {f(h)}" role="img">'
            f'<title>{title}</title>{body}</svg>\n')

def save(name, content):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as fh:
        fh.write(content)

def fillet(A, V, B, r):
    """Tangent points + sweep for rounding vertex V between A and B."""
    u1 = ((A[0]-V[0]), (A[1]-V[1])); l1 = math.hypot(*u1); u1 = (u1[0]/l1, u1[1]/l1)
    u2 = ((B[0]-V[0]), (B[1]-V[1])); l2 = math.hypot(*u2); u2 = (u2[0]/l2, u2[1]/l2)
    th = math.acos(max(-1, min(1, u1[0]*u2[0] + u1[1]*u2[1])))
    d = r / math.tan(th/2)
    T1 = (V[0]+u1[0]*d, V[1]+u1[1]*d); T2 = (V[0]+u2[0]*d, V[1]+u2[1]*d)
    cross = (V[0]-A[0])*(B[1]-V[1]) - (V[1]-A[1])*(B[0]-V[0])
    return T1, T2, 1 if cross > 0 else 0

def circle_path(cx, cy, r, ccw=False):
    s = 0 if ccw else 1
    return (f"M{f(cx-r)} {f(cy)}A{f(r)} {f(r)} 0 1 {s} {f(cx+r)} {f(cy)}"
            f"A{f(r)} {f(r)} 0 1 {s} {f(cx-r)} {f(cy)}Z")

def rect_path(x, y, w, h):
    return f"M{f(x)} {f(y)}H{f(x+w)}V{f(y+h)}H{f(x)}Z"

# ---------------------------------------------------------------- wordmark
# Geometric lowercase: x-height 64..176, stroke 28, bowls R=56. "piq" mirrors around the i.
S = 28; R = 56; RO = 57.5; XT, XB = 64, 176; CY = (XT + XB) / 2; DESC = 232; GAP = 24

def ring(cx, cy, ro, ri):
    return circle_path(cx, cy, ro) + circle_path(cx, cy, ri, ccw=True)

def wordmark_paths(dot_cls=""):
    parts = []; stems = []
    x = 0
    # p
    stems.append(rect_path(x, XT, S, DESC - XT))
    parts.append(ring(x + RO, CY, RO, RO - S))
    p_right = x + 2*RO
    # i
    ix = p_right + GAP
    stems.append(rect_path(ix, XT, S, XB - XT))
    axis = ix + S/2
    # q (mirror of p around axis)
    q_left = 2*axis - p_right
    parts.append(ring(q_left + RO, CY, RO, RO - S))
    stems.append(rect_path(q_left + 2*RO - S, XT, S, DESC - XT))
    q_right = q_left + 2*RO
    # x: two bars, perpendicular weight S
    h = XB - XT
    ang = math.radians(60)               # bar direction: exact 60 degrees
    hw = S / math.sin(ang) / 2 * 0.94    # half horizontal width (slightly thinned for optical weight)
    x0 = q_right + GAP; W = h / math.tan(ang) + 2*hw; x1 = x0 + W
    bar1 = f"M{f(x0-hw+hw)} {f(XT)}H{f(x0+2*hw)}L{f(x1)} {f(XB)}H{f(x1-2*hw)}Z"
    bar2 = f"M{f(x1-2*hw)} {f(XT)}H{f(x1)}L{f(x0+2*hw)} {f(XB)}H{f(x0)}Z"
    body = "".join(parts)
    dot = circle_path(axis, 32, 17)
    return body, "".join(stems) + bar1 + bar2, dot, x1, axis

wm_body, wm_x, wm_dot, WM_W, WM_AXIS = wordmark_paths()
A_STEMS = 'M' + 'M'.join(wm_x.split('M')[1:4])

def wordmark_group(dot_fill="#000"):
    # bars of the x overlap: use nonzero for them separately
    return (f'<path d="{wm_body}" fill-rule="evenodd"/>'
            f'<path d="{wm_x}"/>'
            f'<path d="{wm_dot}" fill="{dot_fill}"/>')

PAD = 8
save("a-wordmark.svg", svg(WM_W + 2*PAD, 256,
     f'<g transform="translate({PAD} 0)">{wordmark_group()}</g>', "Piqx wordmark"))

# A symbol: the "piq" core — two mirrored bowls with the live i between.
def a_symbol():
    # crop the piq part: x 0 .. q_right, scale to fit 256 box
    q_right = 2*WM_AXIS
    w = q_right; h = DESC - 18
    sc = 216 / w
    tx = (256 - w*sc)/2; ty = (256 - (DESC-18)*sc)/2 - 18*sc - 4
    stems_only = wm_x.split("M" + wm_x.split("M")[4])[0] if False else None
    body = (f'<path d="{wm_body}" fill-rule="evenodd"/><path d="{A_STEMS}"/><path d="{wm_dot}"/>')
    return f'<g transform="translate({f(tx)} {f(ty)}) scale({f(sc)})">{body}</g>'
save("a-symbol.svg", svg(256, 256, a_symbol(), "Piqx A symbol"))

# ---------------------------------------------------------------- B: on-air p
def b_symbol():
    st = 34; Rb = 74; inner = Rb - st; dot = 21
    sx, top, bot = 56, 34, 234
    cx, cy = sx + Rb, top + Rb
    # centre the footprint at (128,126)
    fw = 2*Rb; fh = bot - top
    dx = 128 - (sx + fw/2); dy = 126 - (top + fh/2)
    sx += dx; cx += dx; top += dy; bot += dy; cy += dy
    d = rect_path(sx, top, st, bot - top) + ring(cx, cy, Rb, inner)
    return f'<path d="{d}" fill-rule="nonzero"/>'.replace('fill-rule="nonzero"', '') , (cx, cy, dot, sx, top, st, bot, Rb, inner)

def b_symbol_svg():
    _, (cx, cy, dot, sx, top, st, bot, Rb, inner) = b_symbol()
    # stem + ring as one evenodd-safe compound: draw ring with hole, stem separately but
    # stem overlaps ring only on the solid band, so union by separate paths.
    ringd = ring(cx, cy, Rb, inner)
    # stem must not cover the counter: stem right edge = sx+st = ring inner left edge at cy
    stem = rect_path(sx, top, st, bot - top)
    return (f'<path d="{ringd}" fill-rule="evenodd"/><path d="{stem}"/>'
            f'<path d="{circle_path(cx, cy, dot)}"/>')
save("b-symbol.svg", svg(256, 256, b_symbol_svg(), "Piqx B symbol"))

# ---------------------------------------------------------------- C: face-off
def c_shapes(rc=36, ball=24, r=14, tip_angle=60, half_h=64):
    tipx, tipy = 128, 128
    run = half_h / math.tan(math.radians(tip_angle/2))
    x0 = tipx - run
    TL, BL, TIP = (x0, tipy - half_h), (x0, tipy + half_h), (tipx, tipy)
    def toward(P, Q, dist):
        dx, dy = Q[0]-P[0], Q[1]-P[1]; l = math.hypot(dx, dy)
        return (Q[0] - dx/l*dist, Q[1] - dy/l*dist)
    P1 = toward(TL, TIP, rc); P2 = toward(BL, TIP, rc)
    # TL fillet (between BL and P1), BL fillet (between P2 and TL)
    a1, a2, s1 = fillet(BL, TL, P1, r)
    b1, b2, s2 = fillet(P2, BL, TL, r)
    left = (f"M{pt(a2)}L{pt(P1)}A{f(rc)} {f(rc)} 0 0 0 {pt(P2)}L{pt(b1)}"
            f"A{f(r)} {f(r)} 0 0 {s2} {pt(b2)}L{pt(a1)}A{f(r)} {f(r)} 0 0 {s1} {pt(a2)}Z")
    return left, circle_path(tipx, tipy, ball), x0

def c_symbol_svg():
    left, ballp, _ = c_shapes()
    return (f'<path d="{left}"/><path d="{left}" transform="matrix(-1 0 0 1 256 0)"/>'
            f'<path d="{ballp}"/>')
save("c-symbol.svg", svg(256, 256, c_symbol_svg(), "Piqx C symbol"))

# ---------------------------------------------------------------- lockups
def lockup(name, sym_inner, sym_box=(0, 0, 256, 256)):
    # symbol at full 256 height, wordmark scaled so its x-height ~ 46% of symbol
    sc = 0.62
    gap = 36
    wx = 256 + gap
    wy = (256 - 256*sc)/2 + 6
    total = wx + WM_W*sc + PAD
    body = (f'<g>{sym_inner}</g>'
            f'<g transform="translate({f(wx)} {f(wy)}) scale({sc})">{wordmark_group()}</g>')
    save(name, svg(total, 256, body, "Piqx lockup"))

lockup("b-lockup.svg", b_symbol_svg())
lockup("c-lockup.svg", c_symbol_svg())
save("a-lockup.svg", svg(WM_W + 2*PAD, 256,
     f'<g transform="translate({PAD} 0)">{wordmark_group()}</g>', "Piqx wordmark"))
print("ok", WM_W)

# ---------------------------------------------------------------- C2: x with the ball at the crossing
def line_circle(P, d, c, r):
    """Intersections of line P + t*d with circle (c, r); returns sorted t."""
    fx, fy = P[0]-c[0], P[1]-c[1]
    a = d[0]**2 + d[1]**2; b = 2*(fx*d[0] + fy*d[1]); cc = fx*fx + fy*fy - r*r
    disc = math.sqrt(b*b - 4*a*cc)
    return sorted([(-b - disc)/(2*a), (-b + disc)/(2*a)])

def x_ball(top=32, bot=224, left=32, right=224, w=54, rc=50, ball=34, cx=128, cy=128):
    """Two diagonal bars (perpendicular weight w, horizontal terminals) minus a disc, plus a ball."""
    h = bot - top
    ang = math.atan2(h, (right - left))
    hw = w / math.sin(ang)            # horizontal width of a bar
    arms = []
    c = (cx, cy)
    for sign in (1, -1):
        if sign == 1:   # "\" bar
            e1 = ((left, top), (right - hw, bot))        # left long edge
            e2 = ((left + hw, top), (right, bot))        # right long edge
        else:           # "/" bar
            e1 = ((right - hw, top), (left, bot))
            e2 = ((right, top), (left + hw, bot))
        pts = []
        for (P, Q) in (e1, e2):
            d = (Q[0]-P[0], Q[1]-P[1])
            t0, t1 = line_circle(P, d, c, rc)
            pts.append(((P[0]+d[0]*t0, P[1]+d[1]*t0), (P[0]+d[0]*t1, P[1]+d[1]*t1)))
        (a_in, a_out), (b_in, b_out) = pts
        (P1, Q1), (P2, Q2) = e1, e2
        # upper arm: P1 -> P2 along top, down edge2 to b_in, arc to a_in, back up edge1
        sw_u = 1 if sign == 1 else 0
        arms.append(f"M{pt(P1)}L{pt(P2)}L{pt(b_in)}A{f(rc)} {f(rc)} 0 0 {sw_u} {pt(a_in)}Z")
        # lower arm: Q1 -> a_out, arc to b_out, -> Q2
        arms.append(f"M{pt(Q1)}L{pt(a_out)}A{f(rc)} {f(rc)} 0 0 {sw_u} {pt(b_out)}L{pt(Q2)}Z")
    return "".join(arms), circle_path(cx, cy, ball)

def c2_symbol_svg():
    arms, ballp = x_ball()
    return f'<path d="{arms}"/><path d="{ballp}"/>'
save("c-symbol.svg", svg(256, 256, c2_symbol_svg(), "Piqx C symbol"))
lockup("c-lockup.svg", c2_symbol_svg())

# A symbol alt: mirrored p q with the live dot between the bowls
def a2_symbol_svg():
    st = 32; Ro = 50; gap = 0
    cy = 118
    lc = 128 - Ro - 6; rc_ = 128 + Ro + 6
    d = ring(lc, cy, Ro, Ro - st) + ring(rc_, cy, Ro, Ro - st)
    stems = rect_path(lc - Ro, cy - Ro, st, 156) + rect_path(rc_ + Ro - st, cy - Ro, st, 156)
    return (f'<path d="{d}" fill-rule="evenodd"/><path d="{stems}"/>'
            f'<path d="{circle_path(128, cy - Ro - 26, 16)}"/>')
save("a-symbol-alt.svg", svg(256, 256, a2_symbol_svg(), "Piqx A symbol alt"))

def arc_to(P, Q, c, r):
    d = (Q[0]-P[0], Q[1]-P[1])
    sweep = 1 if ((c[0]-P[0])*(-d[1]) + (c[1]-P[1])*d[0]) > 0 else 0
    return f"A{f(r)} {f(r)} 0 0 {sweep} {pt(Q)}"

def x_ball2(top=32, bot=224, w=50, rc=48, ball=33, cx=128, cy=128):
    h = bot - top
    ang = math.radians(60)
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
        arms.append(f"M{pt(e1[0])}L{pt(e2[0])}L{pt(b_in)}{arc_to(b_in, a_in, c, rc)}Z")
        arms.append(f"M{pt(e1[1])}L{pt(a_out)}{arc_to(a_out, b_out, c, rc)}L{pt(e2[1])}Z")
    return "".join(arms), circle_path(cx, cy, ball)

def c3_symbol_svg():
    arms, ballp = x_ball2()
    return f'<path d="{arms}"/><path d="{ballp}"/>'
save("c-symbol.svg", svg(256, 256, c3_symbol_svg(), "Piqx C symbol"))
lockup("c-lockup.svg", c3_symbol_svg())
save("a-symbol.svg", svg(256, 256, a2_symbol_svg(), "Piqx A symbol"))
