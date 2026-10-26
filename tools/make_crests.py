#!/usr/bin/env python3
"""Generates assets/crests/<id>.svg: original vector crests for clubs and school houses.
Varied badge shapes (shield, roundel, teardrop, star, diamond, oval, pentagon, pennant) and one figure per
club following the canon description in "Quidditch Through the Ages" ch. 7 (arrow, bat, catapult, CC,
hawk, talon, KK, magpie, star, bulrushes, tornado, cleaver, wasp...). For the houses, each house's animal.
These are original illustrations: the film or Pottermore crests are not copied. If the user places
assets/crests/<id>.png, the game uses it instead of the SVG.
Usage: python3 tools/make_crests.py"""
import json, glob, os, math

OUT = "assets/crests"
W, H = 128, 148


def hexrgb(c):
    return int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)


def darken(c, f):
    r, g, b = hexrgb(c)
    return "#%02X%02X%02X" % tuple(int(v * (1 - f)) for v in (r, g, b))


def lum(c):
    r, g, b = hexrgb(c)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255


GOLD, GOLD_D, SILVER, SILVER_D, INK, CREAM = "#D9B64B", "#8E6A1C", "#D2D6DB", "#6F767E", "#1B1B1B", "#F4EFE0"
WOOD, WOOD_D = "#8B5A2B", "#4E3015"


def star_pts(cx, cy, r, n=5, inner=0.43, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        a = rot + i * math.pi / n
        rr = r if i % 2 == 0 else r * inner
        pts.append(f"{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}")
    return " ".join(pts)


def poly(points, fill, stroke=None, sw=1.5, extra=""):
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"' if stroke else ""
    return f'<polygon points="{points}" fill="{fill}"{st}{extra}/>'


def path(d, fill="none", stroke=None, sw=1.5, cap="round", extra=""):
    st = f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="{cap}" stroke-linejoin="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}"{st}{extra}/>'


SHAPES = {
    "shield": "M14 12 H114 V76 C114 108 90 130 64 140 C38 130 14 108 14 76 Z",
    "shield_round": "M18 14 H110 C114 14 116 16 116 20 V80 C116 112 92 134 64 142 C36 134 12 112 12 80 V20 C12 16 14 14 18 14 Z",
    "roundel": "M64 14 A62 62 0 1 1 63.9 14 Z",
    "teardrop": "M64 10 C96 10 118 36 118 70 C118 104 96 132 64 140 C32 132 10 104 10 70 C10 36 32 10 64 10 Z",
    "drop_left": "M6 76 C40 46 60 20 118 24 C122 60 118 110 100 134 C66 136 36 110 6 76 Z",
    "pennant": "M16 12 H112 V96 C112 120 90 136 64 140 C38 136 16 120 16 96 Z",
    "diamond": "M64 8 L122 76 L64 144 L6 76 Z",
    "oval": "M64 14 C100 14 120 42 120 76 C120 110 100 138 64 138 C28 138 8 110 8 76 C8 42 28 14 64 14 Z",
    "pentagon": "M64 8 L122 54 L100 136 L28 136 L6 54 Z",
    "star8": star_pts(64, 76, 66, 8, 0.72, -math.pi / 2),
    "arch": "M14 40 C14 16 114 16 114 40 V132 H14 Z",
}


def badge(shape, fill, border):
    d = SHAPES[shape]
    is_poly = shape == "star8"
    mk = (lambda f, s=None, sw=1.5, extra="": poly(d, f, s, sw, extra)) if is_poly else (lambda f, s=None, sw=1.5, extra="": path(d, f, s, sw, extra=extra))
    scale = ' transform="translate(64 76) scale(0.94) translate(-64 -76)" opacity="0.85"'
    return (f'<clipPath id="c">{mk("#000")}</clipPath>', mk("#000", extra=' transform="translate(3 4)" opacity="0.25"'),
            mk(fill), mk("none", border, 3.5), mk("none", GOLD, 1.4, scale))


def arrow_up(fill=SILVER, stroke=SILVER_D):
    return (path("M64 118 V44", None, fill, 7) + path("M64 118 V44", None, stroke, 1.2, extra=' opacity="0.5"')
            + poly("64,28 50,54 60,50 68,50 78,54", fill, stroke, 1.5)
            + poly("64,112 54,122 60,118 68,118 74,122", CREAM, stroke, 1.5)
            + path("M58 100 L50 110 M70 100 L78 110", None, CREAM, 3))


def bat(c, cx=64, cy=66, s=1.0):
    d = ("M64 60 C67 55 71 55 73 59 L72 64 C84 56 102 58 110 72 C101 72 97 77 97 84 C91 82 85 84 85 90 "
         "C79 88 72 90 70 96 L64 90 L58 96 C56 90 49 88 43 90 C43 84 37 82 31 84 C31 77 27 72 18 72 C26 58 44 56 56 64 "
         "L55 59 C57 55 61 55 64 60 Z")
    return (f'<g transform="translate({cx} {cy}) scale({s}) translate(-64 -66)">' + path(d, c, darken(c, 0.35), 1.5)
            + f'<circle cx="60" cy="66" r="1.6" fill="{CREAM}"/><circle cx="68" cy="66" r="1.6" fill="{CREAM}"/></g>')


def tower(c, cx=64, cy=108):
    return (f'<g transform="translate({cx} {cy})">' + path("M-14 14 V-10 H-8 V-16 H-2 V-10 H2 V-16 H8 V-10 H14 V14 Z", c, darken(c, 0.35), 1.2)
            + path("M-3 14 V2 H3 V14", darken(c, 0.5)) + "</g>")


def catapult():
    return (path("M30 118 L98 118 L94 108 L34 108 Z", WOOD, WOOD_D, 1.2)
            + path("M42 108 L70 56", None, WOOD, 7) + path("M66 58 C76 48 90 52 92 62", None, WOOD, 6)
            + f'<circle cx="94" cy="60" r="8" fill="{INK}"/><circle cx="92" cy="58" r="2.5" fill="#555"/>'
            + f'<circle cx="42" cy="116" r="6" fill="{WOOD_D}"/><circle cx="86" cy="116" r="6" fill="{WOOD_D}"/>'
            + path("M48 108 L58 84", None, WOOD_D, 3))


def letter(ch, x, y, h, fill, stroke, sw=None):
    w = h * 0.62
    sw = sw or h * 0.24
    if ch == "K":
        d = f'M{x-w/2} {y-h/2} V{y+h/2} M{x+w/2} {y-h/2} L{x-w/2+sw*0.5} {y+2} L{x+w/2} {y+h/2}'
    elif ch == "T":
        d = f'M{x-w/2} {y-h/2} H{x+w/2} M{x} {y-h/2} V{y+h/2}'
    elif ch == "C":
        d = f'M{x+w/2} {y-h/2+sw*0.35} A{w/2+1} {h/2-1} 0 1 0 {x+w/2} {y+h/2-sw*0.35}'
    elif ch == "W":
        d = f'M{x-w*0.7} {y-h/2} L{x-w*0.35} {y+h/2} L{x} {y-h*0.15} L{x+w*0.35} {y+h/2} L{x+w*0.7} {y-h/2}'
    else:
        d = f'M{x-w/2} {y+h/2} V{y-h/2} H{x+w/2}'
    return path(d, None, stroke, sw + 3) + path(d, None, fill, sw)


def falcon_head():
    return (path("M30 80 C30 58 48 46 68 48 C86 50 98 60 100 72 L98 80 C98 98 84 112 64 112 C46 112 32 100 30 86 Z", CREAM, "#555", 1.5)
            + path("M98 72 L120 78 L102 86 C102 80 100 76 98 72 Z", GOLD, GOLD_D, 1)
            + f'<circle cx="80" cy="68" r="5.5" fill="#111"/><circle cx="82" cy="66" r="1.8" fill="#fff"/>'
            + path("M66 60 L92 64", None, "#555", 2.5)
            + path("M30 86 C36 102 50 110 64 112 C48 114 36 106 30 94 Z", "#8A8F96"))


def talon(c=GOLD, cd=GOLD_D):
    g = f'<ellipse cx="64" cy="54" rx="18" ry="10" fill="{c}" stroke="{cd}" stroke-width="1.5"/>'
    for dx in (-22, 0, 22):
        g += path(f"M64 56 C{64+dx*0.25} 72 {64+dx*0.8} 90 {64+dx*1.1} 104", None, c, 8)
        g += path(f"M{64+dx*1.1} 104 C{64+dx*1.35} 112 {64+dx*1.0} 118 {64+dx*0.75} 116", None, cd, 5)
    return g


def magpie():
    body = INK
    return (path("M22 112 L62 92", None, WOOD, 4) + path("M40 102 L34 92 M52 96 L50 86", None, "#2E7D32", 2.5)
            + path("M40 92 C34 82 38 68 52 66 C58 56 72 52 82 58 L96 50 L90 62 C98 68 96 82 86 90 C82 100 70 106 56 102 C48 100 44 98 40 92 Z", body, "#000", 1.5)
            + path("M52 80 C60 76 70 76 78 84 C72 92 60 92 52 86 Z", CREAM)
            + path("M20 100 L46 90 L50 98 L28 108 Z", body)
            + path("M90 62 L108 66 L94 70 Z", "#555555", "#222", 1)
            + f'<circle cx="82" cy="62" r="2.6" fill="{CREAM}"/><circle cx="83" cy="62" r="1.2" fill="#111"/>'
            + path("M56 96 C50 104 44 106 38 104", None, CREAM, 2))


def big_star(fill=GOLD, stroke=GOLD_D, r=34):
    return poly(star_pts(64, 78, r), fill, stroke, 2)


def bulrushes():
    g = ""
    for sgn in (-1, 1):
        g += path(f"M{64-sgn*26} 124 L{64+sgn*12} 52", None, GOLD, 4.5)
        g += f'<rect x="{64+sgn*12-5.5}" y="40" width="11" height="26" rx="5.5" fill="{WOOD}" stroke="{WOOD_D}" stroke-width="1"/>'
        g += path(f"M{64+sgn*12} 40 L{64+sgn*12} 30", None, GOLD, 2.2)
        g += path(f"M{64-sgn*8} 100 C{64-sgn*26} 96 {64-sgn*32} 106 {64-sgn*38} 114", None, GOLD, 3)
    return g


def tornado(c=CREAM, cd="#6FA8DC"):
    return (path("M26 46 C40 36 88 36 102 46 C88 56 40 56 26 46 Z", c, cd, 1.5)
            + path("M38 58 C50 52 78 52 90 58 C78 66 50 66 38 58 Z", c, cd, 1.5)
            + path("M46 70 C56 66 72 66 82 70 C72 78 56 78 46 70 Z", c, cd, 1.5)
            + path("M54 82 C60 80 68 80 74 82 C68 90 60 90 54 82 Z", c, cd, 1.5)
            + path("M60 92 C62 92 66 92 68 92 C66 100 62 100 60 92 Z", c, cd, 1.5)
            + path("M62 102 L66 112", None, c, 4))


def cleaver(cx=64, cy=78):
    return (f'<g transform="translate({cx} {cy}) rotate(-35)">'
            + path("M-34 -22 H28 C32 -22 34 -18 32 -14 L28 14 H-28 C-32 14 -34 10 -34 6 Z", SILVER, SILVER_D, 1.5)
            + f'<circle cx="22" cy="-12" r="3" fill="{SILVER_D}"/>'
            + f'<rect x="28" y="-6" width="34" height="11" rx="4" fill="{WOOD}" stroke="{WOOD_D}" stroke-width="1.2"/>'
            + path("M-28 10 H24", None, CREAM, 2, extra=' opacity="0.6"') + "</g>")


def wasp():
    return (f'<ellipse cx="46" cy="70" rx="20" ry="10" fill="{CREAM}" opacity="0.9" transform="rotate(-28 46 70)"/>'
            f'<ellipse cx="82" cy="70" rx="20" ry="10" fill="{CREAM}" opacity="0.9" transform="rotate(28 82 70)"/>'
            f'<ellipse cx="64" cy="96" rx="15" ry="24" fill="#F2C200" stroke="{INK}" stroke-width="1.5"/>'
            + path("M50 86 H78 M49 97 H79 M52 108 H76", None, INK, 5.5)
            + f'<circle cx="64" cy="68" r="9" fill="{INK}"/>' + path("M58 62 L50 52 M70 62 L78 52", None, INK, 2)
            + path("M64 120 L64 128", None, INK, 3))


def hammer():
    return (f'<rect x="60" y="68" width="8" height="54" rx="2" fill="{WOOD}" stroke="{WOOD_D}" stroke-width="1.2"/>'
            + path("M34 50 H94 V72 H34 Z", SILVER, SILVER_D, 1.5) + path("M34 50 L28 56 V66 L34 72 Z", SILVER_D)
            + path("M40 54 H88", None, CREAM, 2, extra=' opacity="0.6"'))


def bomb():
    return (f'<circle cx="64" cy="92" r="24" fill="{INK}"/><ellipse cx="55" cy="83" rx="7" ry="4.5" fill="#555" transform="rotate(-30 55 83)"/>'
            f'<rect x="59" y="62" width="10" height="9" fill="#444"/>' + path("M66 62 C70 52 82 54 86 46", None, WOOD, 3)
            + poly("86,46 82,40 90,42 88,36 94,42 92,48", "#FF8F00") + f'<circle cx="88" cy="43" r="3" fill="#FFD54F"/>')


def broom_cross():
    g = ""
    for ang in (-35, 35):
        g += (f'<g transform="rotate({ang} 64 84)"><rect x="18" y="81" width="66" height="6" rx="3" fill="{WOOD}" stroke="{WOOD_D}" stroke-width="1"/>'
              + path("M84 76 L112 72 L116 84 L112 96 L84 92 Z", "#C9A24A", GOLD_D, 1.2) + path("M88 78 L108 76 M88 84 L112 84 M88 90 L108 92", None, GOLD_D, 1.2)
              + f'<rect x="80" y="76" width="6" height="16" fill="#3E3E3E"/></g>')
    return g


def bird(body, beak=GOLD, light=CREAM, crest=False, wing=None):
    wing = wing or darken(body, 0.25)
    g = (path("M40 96 C34 86 36 72 50 70 C56 60 70 56 80 62 L92 56 L86 66 C94 72 92 84 84 92 C80 102 68 108 54 104 C46 102 42 100 40 96 Z", body, darken(body, 0.35), 1.5)
         + path("M24 100 L46 92 L48 100 L30 108 Z", wing)
         + path("M50 80 C58 74 70 74 78 82 C70 90 58 90 50 86 Z", wing)
         + path("M86 66 L104 70 L90 74 Z", beak, darken(beak, 0.3), 1)
         + f'<circle cx="80" cy="66" r="2.6" fill="{light}"/><circle cx="81" cy="66" r="1.2" fill="#111"/>')
    if crest:
        g += path("M72 58 L74 48 L78 56 L84 50 L82 60 Z", beak)
    return g


def sun():
    g = ""
    for i in range(12):
        a = i * math.pi / 6
        g += path(f"M{64+math.cos(a)*24:.1f} {78+math.sin(a)*24:.1f} L{64+math.cos(a)*38:.1f} {78+math.sin(a)*38:.1f}", None, GOLD, 4)
    return g + f'<circle cx="64" cy="78" r="20" fill="{GOLD}" stroke="{GOLD_D}" stroke-width="1.5"/>'


def tree():
    return (f'<rect x="58" y="98" width="12" height="26" fill="{WOOD}"/>'
            + poly("64,40 92,82 78,82 98,110 30,110 50,82 36,82", "#2E7D32", "#1B4D1E", 1.5))


def fist_quaffle():
    return (f'<circle cx="82" cy="70" r="16" fill="#9B3B2E" stroke="#5E1F18" stroke-width="1.5"/>'
            + path("M74 60 C82 56 90 60 92 68", None, "#5E1F18", 1.5)
            + path("M34 92 C32 82 38 78 46 80 L66 80 C72 80 74 84 72 88 L70 102 C70 110 64 114 56 114 C44 114 34 106 34 92 Z", CREAM, "#555", 1.5)
            + path("M48 82 L48 96 M56 82 L56 98 M64 82 L64 96", None, "#555", 1.5))


def wand_sparkles():
    g = path("M30 122 L82 60", None, WOOD_D, 10) + path("M30 122 L82 60", None, WOOD, 6) + path("M82 60 L92 48", None, "#E8D2A8", 7)
    for cx, cy, r in ((96, 42, 13), (110, 60, 8), (76, 34, 6)):
        g += poly(star_pts(cx, cy, r), GOLD, GOLD_D, 1)
    return g


def bolt(fill=GOLD, stroke=GOLD_D, extra=""):
    return poly("72,40 44,88 62,88 52,124 86,76 68,76 80,40", fill, stroke, 1.5, extra)


def storm():
    return (path("M34 80 C30 64 50 58 56 66 C60 54 82 54 84 68 C98 66 102 84 90 86 L38 86 C32 86 30 82 34 80 Z", CREAM, "#78909C", 1.5)
            + poly("68,86 52,108 62,108 56,128 78,100 68,100 74,86", GOLD, GOLD_D, 1.2))


def meteor():
    return (poly("18,46 72,88 58,96", "#FFD54F", extra=' opacity="0.85"') + poly("24,62 72,92 64,100", "#FF8F00", extra=' opacity="0.8"')
            + f'<circle cx="78" cy="100" r="18" fill="#6E4A2E" stroke="#3E2A10" stroke-width="1.5"/><circle cx="72" cy="94" r="4" fill="#3E2A10"/><circle cx="84" cy="106" r="3" fill="#3E2A10"/>')


def gargoyle(s):
    return (path("M40 100 C34 80 40 62 64 60 C88 62 94 80 88 100 C80 106 48 106 40 100 Z", "#8A9199", "#4A5058", 1.5)
            + path("M46 66 L40 46 L56 60 Z M82 66 L88 46 L72 60 Z", "#6E757D", "#4A5058", 1.2)
            + path("M50 80 L60 84 L50 88 Z M78 80 L68 84 L78 88 Z", s)
            + path("M52 98 L58 92 L62 98 L66 92 L70 98 L76 92", None, "#4A5058", 2)
            + path("M30 70 C20 76 20 92 30 96 M98 70 C108 76 108 92 98 96", None, "#6E757D", 5))


def goblin():
    return (path("M44 92 C40 72 50 60 64 60 C78 60 88 72 84 92 C78 102 50 102 44 92 Z", "#9CB36A", "#4F6B2A", 1.5)
            + path("M46 72 L22 58 L44 80 Z M82 72 L106 58 L84 80 Z", "#9CB36A", "#4F6B2A", 1.5)
            + f'<circle cx="56" cy="78" r="3.5" fill="#222"/><circle cx="72" cy="78" r="3.5" fill="#222"/>'
            + path("M60 86 L64 92 L68 86", "#4F6B2A") + path("M54 96 C58 100 70 100 74 96", None, "#4F6B2A", 2)
            + path("M58 96 L60 100 M70 96 L68 100", None, CREAM, 2))


def giant(s):
    return (f'<circle cx="64" cy="62" r="11" fill="{CREAM}" stroke="#333" stroke-width="1.2"/>'
            + path("M44 78 C44 70 84 70 84 78 L86 110 L42 110 Z", s, darken(s, 0.3), 1.5)
            + path("M44 82 L28 98 M84 82 L100 98", None, CREAM, 7)
            + f'<rect x="96" y="54" width="8" height="50" rx="3" fill="{WOOD}" transform="rotate(20 100 78)"/>')


def warrior(s):
    return (path("M40 68 C40 50 88 50 88 68 L88 90 C88 102 74 112 64 112 C54 112 40 102 40 90 Z", SILVER, SILVER_D, 1.5)
            + path("M64 50 L64 112", None, SILVER_D, 3) + path("M46 84 H58 M70 84 H82", None, "#111", 4)
            + path("M48 58 C56 42 72 42 80 58", None, s, 6))


def tengu():
    return (path("M40 70 C40 52 88 52 88 70 L86 98 C84 108 72 114 64 114 C56 114 44 108 42 98 Z", "#C62828", "#7F0000", 1.5)
            + path("M64 80 L104 92 L64 96 Z", "#C62828", "#7F0000", 1.5) + path("M50 74 L60 78 M78 78 L68 74", None, "#111", 3)
            + path("M52 100 C58 106 70 106 76 100", None, "#111", 2) + path("M44 60 C50 50 78 50 84 60", None, "#111", 4))


def stick():
    return (f'<g transform="rotate(-35 64 84)"><rect x="22" y="80" width="82" height="8" rx="4" fill="{WOOD}" stroke="{WOOD_D}" stroke-width="1.2"/>'
            + path("M96 76 L118 70 L120 84 L118 98 L96 92 Z", "#E0C068", GOLD_D, 1.2) + "</g>")


def lion(c=GOLD, cd=GOLD_D):
    return (path("M46 112 L50 86 C40 80 36 64 48 56 C54 46 70 44 80 52 C90 58 92 70 86 78 L92 92 L82 94 L80 112 Z", c, cd, 1.5)
            + path("M44 58 C36 52 34 42 42 38 C48 36 54 40 56 46 M80 50 C86 42 96 42 98 50 C100 58 92 62 86 60", None, cd, 3)
            + f'<circle cx="60" cy="64" r="2.2" fill="{cd}"/><circle cx="74" cy="64" r="2.2" fill="{cd}"/>'
            + path("M62 74 L67 78 L72 74 M60 82 C64 86 70 86 74 82", None, cd, 2)
            + path("M50 86 L44 100 M80 94 L88 106", None, cd, 1.5) + path("M92 92 C104 88 108 100 100 108", None, c, 4))


def badger_head(c=INK):
    return (path("M38 92 C32 74 44 58 64 58 C84 58 96 74 90 92 C84 106 44 106 38 92 Z", CREAM, "#333", 1.5)
            + path("M44 64 C38 56 40 48 48 50 C52 52 54 56 54 60 Z M84 64 C90 56 88 48 80 50 C76 52 74 56 74 60 Z", c, "#333", 1)
            + path("M50 62 C44 74 46 90 56 100 C60 92 58 76 56 62 Z M78 62 C84 74 82 90 72 100 C68 92 70 76 72 62 Z", c)
            + f'<circle cx="56" cy="78" r="2.4" fill="#111"/><circle cx="72" cy="78" r="2.4" fill="#111"/>'
            + path("M60 92 C64 96 66 96 68 92 C66 90 62 90 60 92 Z", c))


def eagle(c="#946B2D", cd="#5C3F14"):
    return (path("M64 112 L58 86 C44 90 30 86 20 70 C34 72 44 68 50 62 C40 60 32 52 30 44 C42 50 54 50 60 46 C60 40 62 34 66 30 C70 34 72 40 72 46 C78 50 90 50 102 44 C100 52 92 60 82 62 C88 68 98 72 112 70 C102 86 88 90 74 86 L68 112 Z", c, cd, 1.5)
            + path("M60 34 L70 36 L66 42 Z", GOLD, GOLD_D, 1) + f'<circle cx="63" cy="32" r="1.6" fill="#111"/>'
            + path("M58 112 L52 124 L60 118 L64 128 L68 118 L76 124 L70 112", c, cd, 1.2))


def serpent(c=SILVER, cd=SILVER_D):
    d = "M38 54 C58 46 84 54 82 70 C80 84 54 82 50 94 C46 106 70 114 90 104"
    return (path(d, None, c, 9) + path(d, None, cd, 1.5, extra=' opacity="0.7"')
            + path("M30 56 C32 48 42 46 46 52 C46 58 38 60 30 56 Z", c, cd, 1.5)
            + f'<circle cx="38" cy="53" r="1.6" fill="#B71C1C"/>' + path("M30 56 L22 52 M30 56 L22 58", None, "#B71C1C", 1.5)
            + path("M90 104 L100 110", None, c, 5))


def horned_serpent():
    return serpent("#2E7D32", "#1B4D1E") + path("M34 46 L30 36 M42 48 L44 38", None, GOLD, 3)


def wampus(c="#5D4037"):
    return (path("M40 96 C34 80 42 62 64 60 C86 62 94 80 88 96 C80 104 48 104 40 96 Z", c, darken(c, 0.4), 1.5)
            + path("M46 66 L40 48 L56 60 Z M82 66 L88 48 L72 60 Z", c, darken(c, 0.4), 1.2)
            + f'<circle cx="56" cy="78" r="3" fill="{GOLD}"/><circle cx="72" cy="78" r="3" fill="{GOLD}"/>'
            + path("M60 88 L64 92 L68 88 M52 94 L44 96 M76 94 L84 96 M52 90 L44 88 M76 90 L84 88", None, CREAM, 1.5))


def thunderbird():
    return eagle("#1565C0", "#0D3C7A") + bolt("#FFC107", "#8E6A1C", ' transform="translate(38 58) scale(0.4)"')


def pukwudgie():
    return (path("M46 100 C42 84 50 70 64 70 C78 70 86 84 82 100 C76 108 52 108 46 100 Z", "#9E9E9E", "#555", 1.5)
            + path("M50 72 L64 40 L78 72 Z", "#B71C1C", "#7F0000", 1.5)
            + f'<circle cx="57" cy="84" r="2.6" fill="#111"/><circle cx="71" cy="84" r="2.6" fill="#111"/>'
            + path("M58 94 C62 98 66 98 70 94", None, "#111", 2) + path("M30 104 L46 92 M98 104 L82 92", None, WOOD, 4))


def compose(key, short, p, s):
    """Returns (shape, background colour, border colour, figure, background decoration)."""
    dark_p = darken(p, 0.55)
    chief = f'<path d="M0 0 H128 V40 H0 Z" fill="{s}" opacity="0.9"/>'
    if key == "silver_arrow":
        return "shield", p, dark_p, arrow_up(), ""
    if key == "scarlet_bat":
        return "roundel", CREAM, "#C8102E", bat("#C8102E", 64, 62, 0.95) + tower("#C8102E", 64, 106), '<circle cx="64" cy="76" r="56" fill="none" stroke="#C8102E" stroke-width="5"/>'
    if key == "vertical_stripes_catapult":
        stripes = "".join(f'<rect x="{i*25.6}" y="0" width="25.6" height="148" fill="{s}"/>' for i in range(5) if i % 2 == 1)
        return "star8", p, darken(s, 0.4), catapult(), stripes
    if key == "cannonball_double_c":
        return "drop_left", p, INK, (f'<circle cx="92" cy="80" r="17" fill="{INK}"/><circle cx="86" cy="74" r="4" fill="#555"/>'
                                     + letter("C", 46, 78, 34, INK, p, 8) + letter("C", 68, 78, 34, INK, p, 8)), ""
    if key == "falcon_head":
        return "arch", p, INK, falcon_head(), f'<rect x="14" y="16" width="100" height="24" fill="{s}" opacity="0.9"/>'
    if key == "golden_talon":
        return "shield", p, GOLD_D, talon(), ""
    if key == "double_k":
        diag = "".join(path(f"M{-20+i*44} 148 L{60+i*44} 0", None, darken(p, 0.2), 10) for i in range(4))
        return "shield_round", p, GOLD_D, letter("K", 46, 82, 48, "#F5D21F", darken(p, 0.5)) + letter("K", 82, 82, 48, "#F5D21F", darken(p, 0.5)), diag
    if key == "magpie":
        return "shield", CREAM, INK, magpie(), ""
    if key == "golden_star":
        return "roundel", p, GOLD, big_star(GOLD, GOLD_D, 42), f'<circle cx="64" cy="76" r="56" fill="none" stroke="{GOLD}" stroke-width="4"/>'
    if key == "crossed_bulrushes":
        return "shield", p, GOLD_D, bulrushes(), ""
    if key == "double_t":
        return "oval", p, "#1F3A6E", tornado(CREAM, "#6FA8DC"), ""
    if key == "meat_cleaver":
        return "diamond", "#C8102E", INK, cleaver(66, 70) + letter("W", 44, 104, 24, CREAM, INK) + letter("W", 84, 104, 24, CREAM, INK), ""
    if key == "horizontal_stripes_wasp":
        return "pentagon", INK, "#F2C200", wasp(), f'<path d="{SHAPES["pentagon"]}" fill="none" stroke="#F2C200" stroke-width="9" transform="translate(64 76) scale(0.9) translate(-64 -76)"/>'
    generic = {
        "bomb": ("roundel", bomb()), "broom_fleet": ("shield", broom_cross()), "finch": ("teardrop", bird("#F9A825", crest=True)),
        "giant": ("shield", giant(s)), "gargoyle": ("arch", gargoyle(s)), "goblin": ("shield_round", goblin()), "hammer": ("pennant", hammer()),
        "harrier_hawk": ("shield", bird("#6E4A2E")), "kite_bird": ("diamond", bird("#E53935")), "meteor": ("roundel", meteor()),
        "macaw": ("teardrop", bird("#1E88E5", beak="#FDD835", crest=True)), "stick": ("shield", stick()), "fist_quaffle": ("roundel", fist_quaffle()),
        "storm": ("shield", storm()), "sunray": ("roundel", sun()), "star": ("shield", big_star(CREAM, "#555555", 32)), "tree": ("shield", tree()),
        "charm": ("oval", wand_sparkles()), "thunder": ("shield", bolt()), "tengu": ("pentagon", tengu()), "vulture": ("shield", bird("#3E3E3E", beak="#C8102E")),
        "warrior": ("shield", warrior(s)),
    }
    if key in generic:
        shape, fig = generic[key]
        return shape, p, dark_p, fig, chief if shape in ("shield", "shield_round", "pennant", "arch") else ""
    initials = "".join(w[0] for w in short.split())[:2]
    fill = s if lum(p) < 0.5 else darken(p, 0.5)
    fig = "".join(letter(ch, 48 + i * 32, 84, 40, fill, darken(p, 0.4)) for i, ch in enumerate(initials))
    return "shield", p, dark_p, fig, chief


def house_compose(house, colors):
    p, s = colors["primary"], colors["secondary"]
    figs = {"gryffindor": lion(GOLD, GOLD_D), "hufflepuff": badger_head(INK), "ravenclaw": eagle("#946B2D", "#5C3F14"), "slytherin": serpent(SILVER, SILVER_D),
            "horned_serpent": horned_serpent(), "wampus": wampus(), "thunderbird": thunderbird(), "pukwudgie": pukwudgie(),
            # [FILLER]
            "abraxan": big_star(), "vouivre": serpent(), "melusine": serpent(), "tarasque": horned_serpent(),
            "lindworm": serpent(), "huldra": tree(), "jotunn": giant(s), "sleipnir": storm(),
            "zhar_ptitsa": bird("#FF8F00", crest=True), "leshy": tree(), "rusalka": wand_sparkles(), "zmey": horned_serpent(),
            "kirin": big_star(), "tengu": tengu(), "kitsune": wampus("#ECEFF1"), "ryu": horned_serpent(),
            "caipora": tree(), "iara": serpent(), "uirapuru": bird("#C62828", crest=True), "boto": meteor(),
            "impundulu": bolt(), "ninki_nanka": horned_serpent(), "anansi": wand_sparkles(), "kongamato": bat(INK),
            "yowie": giant(s), "min_min": sun(), "thylacine": wampus("#E65100"), "lyrebird": bird("#8D6E63", crest=True),
            "zumruduanka": bird("#2E7D32", crest=True), "sahmeran": serpent(), "tepegoz": giant(s), "ejder": horned_serpent(),
            "yali": lion(), "makara": horned_serpent(), "airavata": big_star(), "naga": serpent()}
    return "shield", p, darken(p, 0.5), figs.get(house, ""), f'<path d="M0 0 H128 V34 H0 Z" fill="{s}" opacity="0.9"/>'


import re as _re
THREAD_LIGHT, THREAD_DARK = "#101112", "#131415"


def embroider(fragment, light, dark):
    """Figure embroidered in two thread tones (like official patches): light colours -> light thread, dark -> dark thread."""
    def repl(m):
        c = m.group(0)
        if c in (THREAD_LIGHT, THREAD_DARK):
            return c
        return light if lum(c) >= 0.33 else dark
    return _re.sub(r"#[0-9A-Fa-f]{6}", repl, fragment)


def thread_colors(p, s):
    """Light thread: the secondary colour if it contrasts with the background; otherwise cream (dark background) or ink (light background)."""
    light = s if abs(lum(s) - lum(p)) > 0.25 else ("#E8DDB5" if lum(p) < 0.5 else "#2A2118")
    dark = darken(p, 0.6) if lum(p) >= 0.45 else darken(light, 0.35)
    return light, dark


def render(shape, fill, border, fig, deco, threads=None):
    if threads is not None:
        fig = embroider(fig, threads[0], threads[1])
    clip, shadow, body, outline, inner = badge(shape, fill, border)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
<defs>{clip}<linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0.25"/><stop offset="0.45" stop-color="#FFFFFF" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.28"/></linearGradient></defs>
{shadow}
{body}
<g clip-path="url(#c)">{deco}{fig}<rect x="0" y="0" width="128" height="148" fill="url(#g)"/></g>
{outline}
{inner}
</svg>'''


PACK_SHAPES = {}


def main():
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for f in sorted(glob.glob("data/packs/*/clubs/*.json")):
        d = json.load(open(f))
        shape, fill, border, fig, deco = compose(d.get("emblem_key", ""), d.get("short_name", d["name"]), d["colors"]["primary"], d["colors"]["secondary"])
        open(os.path.join(OUT, d["id"] + ".svg"), "w").write(render(shape, fill, border, fig, deco, thread_colors(fill, d["colors"]["secondary"])))
        PACK_SHAPES[d["id"]] = shape
        n += 1
    for f in sorted(glob.glob("data/packs/*/schools/*.json")):
        d = json.load(open(f))
        sid = d["school_id"].replace("school_", "")
        for house, colors in d.get("house_colors", {}).items():
            hid = f"hs_{sid}_{house.lower().replace(' ', '_')}"
            shape, fill, border, fig, deco = house_compose(house.lower().replace(" ", "_"), colors)
            open(os.path.join(OUT, hid + ".svg"), "w").write(render(shape, fill, border, fig, deco, thread_colors(colors["primary"], colors["secondary"])))
            PACK_SHAPES[hid] = shape
            n += 1
    print(f"{n} crests in {OUT}")
    export_templates()


def export_templates():
    """Templates for the clubs generated in each save (no JSON in the pack): same shapes and figures, with
    marker colours the game replaces with the club's own (Crest.texture_for). Written to data/ so they get exported."""
    P, S = "#0A0B0C", "#0D0E0F"
    keys = ["bomb", "broom_fleet", "finch", "giant", "gargoyle", "goblin", "hammer", "harrier_hawk", "kite_bird", "meteor", "macaw",
            "stick", "fist_quaffle", "storm", "sunray", "star", "tree", "charm", "thunder", "vulture", "warrior"]
    out = {"tokens": {"p": P, "s": S, "dp": darken(P, 0.55), "tl": THREAD_LIGHT, "td": THREAD_DARK}, "dark_factor": 0.55, "templates": {}, "template_shapes": {},
           "shapes": SHAPES, "pack_shapes": PACK_SHAPES, "size": [W, H]}
    for k in keys:
        shape, fill, border, fig, deco = compose(k, "XX", P, S)
        out["templates"][k] = render(shape, fill, border, fig, deco, (THREAD_LIGHT, THREAD_DARK))
        out["template_shapes"][k] = shape
    os.makedirs("data/shared", exist_ok=True)
    json.dump(out, open("data/shared/crest_templates.json", "w"))
    print(f"{len(keys)} templates in data/shared/crest_templates.json")


if __name__ == "__main__":
    main()
