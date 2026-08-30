#!/usr/bin/env python3
"""Compose the As Told App Store screenshot set at 1320x2868 (6.9").

Real app UI comes from raw/*.png, captured via simctl at native resolution and
composited untouched — the marketing layer never redraws a pixel of the product.

Compositions vary deliberately across the set: full device, oversized UI crop,
editorial split, bento, and two dark frames for carousel rhythm.

Drop a 1320x2868 image at plates/<name>.png to override a frame's background.
"""
import os
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 2868
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
PLATES = os.path.join(HERE, "plates")
OUT = os.path.join(HERE, "6.9")
os.makedirs(OUT, exist_ok=True)

PAPER = (246, 242, 233)      # warm paper
CHALK = (251, 250, 247)      # soft chalk
STONE = (238, 236, 231)      # soft stone
CHARCOAL = (26, 26, 28)      # dark frames
INK = (28, 28, 30)
INK_SOFT = (91, 91, 97)
PAPER_INK = (243, 242, 238)  # type on dark
PAPER_SOFT = (168, 166, 162)
ACCENT = (49, 77, 99)        # muted blue-gray
ACCENT_DK = (138, 169, 190)

NY = "/System/Library/Fonts/NewYork.ttf"
SF = "/System/Library/Fonts/SFNS.ttf"


def ny(size, weight=600, opsz=40):
    """New York, the brand serif (Core/DesignSystem/AppMark.swift).

    The Optical Size axis defaults to its 256 maximum — a poster grade whose
    hairline crossbars make "Hindi" read as "I Iindi". Pin it near the rendered
    point size so the headline matches the wordmark the app itself draws.
    """
    f = ImageFont.truetype(NY, size)
    f.set_variation_by_axes([opsz, weight, 0])
    return f


def sf(size, weight=400, opsz=20):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_axes([100, opsz, 400, weight])
    return f


def ground(spec):
    """Flat paper with a whisper of depth, or a two-tone editorial split."""
    if spec.get("split"):
        left, right = spec["split"]
        im = Image.new("RGB", (W, H), left)
        ImageDraw.Draw(im).rectangle([W // 2, 0, W, H], fill=right)
        # blend the seam over ~180px so the transition reads as considered
        ramp = Image.new("L", (W, 1), 0)
        rp = ramp.load()
        for x in range(W):
            t = (x - (W // 2 - 90)) / 180
            rp[x, 0] = 0 if t <= 0 else (255 if t >= 1 else int(255 * t))
        return Image.composite(Image.new("RGB", (W, H), right),
                               Image.new("RGB", (W, H), left),
                               ramp.resize((W, H)))
    base = Image.new("RGB", (W, H), spec["bg"])
    glow = Image.new("L", (W // 5, H // 5), 0)
    ImageDraw.Draw(glow).ellipse(
        [W / 5 * 0.06, H / 5 * 0.03, W / 5 * 0.72, H / 5 * 0.30], fill=44)
    glow = glow.filter(ImageFilter.GaussianBlur(22)).resize((W, H))
    lift = (58, 58, 62) if spec.get("dark") else (255, 255, 252)
    base = Image.composite(Image.new("RGB", (W, H), lift), base, glow)
    rnd = random.Random(spec.get("seed", 3))
    grain = Image.new("L", (W, H))
    grain.putdata([128 + rnd.randint(-4, 4) for _ in range(W * H)])
    return Image.blend(base, Image.merge("RGB", (grain,) * 3), 0.018)


def rounded(im, radius):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.size[0] - 1, im.size[1] - 1],
                                           radius=radius, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def shadow(canvas, box, radius, blur, alpha, dy, tint=(56, 48, 40)):
    x0, y0, x1, y1 = box
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([x0 + 12, y0 + dy, x1 - 12, y1 + dy - 8],
                                        radius=radius, fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new("RGBA", (W, H), tint + (255,))
    sh.putalpha(m)
    canvas.alpha_composite(sh)


def load(name, crop=None):
    im = Image.open(os.path.join(RAW, name)).convert("RGB")
    return im.crop(crop) if crop else im


def device(canvas, shot, width, top, xoff=0, dark=False):
    """Full phone in a subtle, accurate bezel. Radius matches the real display."""
    im = load(shot)
    h = int(im.size[1] * (width / im.size[0]))
    im = im.resize((width, h), Image.LANCZOS)
    inner_r = int(width * 0.125)
    bez = max(10, int(width * 0.0132))
    bw, bh = width + bez * 2, h + bez * 2
    outer_r = inner_r + bez
    x = (W - width) // 2 + xoff
    bx, by = x - bez, top - bez
    tint = (0, 0, 0) if dark else (56, 48, 40)
    shadow(canvas, (bx, by, bx + bw, by + bh), outer_r, 70, 52 if dark else 58, 46, tint)
    shadow(canvas, (bx, by, bx + bw, by + bh), outer_r, 18, 70, 10, tint)
    body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=outer_r, fill=(34, 34, 38, 255))
    bd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=outer_r,
                         outline=(88, 86, 84, 255), width=2)
    body.alpha_composite(rounded(im, inner_r), (bez, bez))
    canvas.alpha_composite(body, (bx, by))


def card(canvas, shot, crop, width, x, top, radius=44, dark=False):
    """A bezel-free crop of the real screen — detail, bento, and split frames."""
    im = load(shot, crop)
    h = int(im.size[1] * (width / im.size[0]))
    im = im.resize((width, h), Image.LANCZOS)
    tint = (0, 0, 0) if dark else (56, 48, 40)
    shadow(canvas, (x, top, x + width, top + h), radius, 54, 88 if dark else 74, 30, tint)
    canvas.alpha_composite(rounded(im, radius), (x, top))
    edge = Image.new("RGBA", (width, h), (0, 0, 0, 0))
    col = (255, 255, 255, 46) if dark else (28, 28, 30, 30)
    ImageDraw.Draw(edge).rounded_rectangle([0, 0, width - 1, h - 1],
                                           radius=radius, outline=col, width=3)
    canvas.alpha_composite(edge, (x, top))


def night_panel(canvas, x0, y0, radius=64):
    """Charcoal ground for the day/night frame, kept clear of the headline."""
    panel = Image.new("RGBA", (W - x0 + 60, H - y0 + 60), (0, 0, 0, 0))
    ImageDraw.Draw(panel).rounded_rectangle(
        [0, 0, panel.size[0] - 1, panel.size[1] - 1], radius=radius, fill=CHARCOAL + (255,))
    canvas.alpha_composite(panel, (x0, y0))


def wrap(draw, text, fnt, maxw):
    """Greedy wrap, except that a literal newline is honoured as a hard break.

    Greedy alone breaks "Write it. Or just say it." after "Or", which reads as a
    typo at poster size. A headline is four words of copy, not a paragraph, so
    where it breaks is a design decision — `\n` is how a frame states one.
    """
    out = []
    for para in text.split("\n"):
        words, cur = para.split(), ""
        for w in words:
            t = (cur + " " + w).strip()
            if draw.textlength(t, font=fnt) <= maxw or not cur:
                cur = t
            else:
                out.append(cur)
                cur = w
        if cur:
            out.append(cur)
    return out


def text_block(canvas, spec):
    d = ImageDraw.Draw(canvas)
    M = 92
    maxw = W - 2 * M
    dark = spec.get("dark")
    ink = PAPER_INK if dark else INK
    soft = PAPER_SOFT if dark else INK_SOFT
    rule = ACCENT_DK if dark else ACCENT
    align = spec["align"]

    size = 158
    while size > 88:
        hf = ny(size, weight=600, opsz=40)
        hl = wrap(d, spec["head"], hf, maxw)
        if len(hl) <= spec["lines"]:
            break
        size -= 3

    supf = sf(46, weight=400, opsz=20)
    sl = wrap(d, spec["sup"], supf, min(maxw, 980)) if spec.get("sup") else []

    def x_for(txt, fnt):
        tw = d.textlength(txt, font=fnt)
        return {"center": (W - tw) / 2, "right": W - M - tw, "left": M}[align]

    y = spec["ttop"]
    last_top = y
    for ln in hl:
        d.text((x_for(ln, hf), y), ln, font=hf, fill=ink)
        last_top = y
        y += int(size * 1.02)

    # The rule clears the *glyph box*, not the line advance. `size * 1.02` is
    # tighter than New York's ascent+descent, so measuring the gap from the
    # advance put the rule through the descender of "actually speak." — it read
    # as an underline on the "y". Ascent + descent is where the last line
    # actually ends, whatever it happens to end with.
    ascent, descent = hf.getmetrics()
    y = last_top + ascent + descent + 24
    rw = 84
    rx = {"center": (W - rw) / 2, "right": W - M - rw, "left": M}[align]
    d.rectangle([rx, y, rx + rw, y + 5], fill=rule)
    y += 40
    for ln in sl:
        d.text((x_for(ln, supf), y), ln, font=supf, fill=soft)
        y += 60


# Each frame gets its own composition; one shared type and colour system.
#
# Rebuilt 2026-08-29 for V2. The previous eight frames told the V1 story and frame 5 headlined
# "Telugu. Hindi. English." — the benchmark groups, not the product boundary (RULES.md §7, "Language
# claims"). This set leads with the two ways into a note, repositions voice as multilingual, and adds
# the work that shipped after the old raws were taken: Quick Voice, pause/resume, code cards, and the
# retained recording.
#
# Ten frames, which is Apple's maximum. The Share sheet is deliberately absent: a simulator has no
# Messages, Mail or AirDrop, so its sheet offers Reminders and Save to Files, and a frame implying
# those are the destinations is worse than no frame. Capture it on a device and it replaces whichever
# frame is weakest by then — `alt-daynight` is composed but unshipped and is the natural swap.
SHOTS = [
    dict(name="01-words", bg=PAPER, seed=3, align="center", lines=2, ttop=196,
         head="Anything you want to put into words.",
         sup="Write it. Say it. Keep it.",
         art=lambda c: device(c, "01-hero.png", 960, 820)),

    # Dark, and cropped tight. The Quick Voice screen is mostly empty canvas by design — shown as a
    # full device that emptiness reads as a bug, and cropped to the timer it reads as focus.
    dict(name="02-voice", bg=CHARCOAL, dark=True, seed=9, align="center", lines=2, ttop=210,
         head="Write it.\nOr just say it.",
         sup="Tap the mic and talk. There is no note to create first.",
         art=lambda c: device(c, "21-quickvoice-dark.png", 1000, 790, dark=True)),

    dict(name="03-languages", bg=STONE, seed=15, align="center", lines=2, ttop=196,
         head="Speak the way you actually speak.",
         sup="Switch languages mid-sentence. Your words stay in the language you used.",
         art=lambda c: device(c, "04-multilingual.png", 1090, 830)),

    dict(name="04-pause", bg=PAPER, seed=21, align="center", lines=2, ttop=196,
         head="Pause. Think. Keep going.",
         sup="A recording waits while you find the next sentence.",
         art=lambda c: device(c, "22-voice-paused.png", 920, 810)),

    dict(name="05-structure", bg=PAPER, seed=27, align="left", lines=2, ttop=196,
         head="Structure without the complexity.",
         sup="Headings, lists and checklists. No block picker.",
         # The crop starts at the "Before we go" heading, not below it: the support line
         # promises headings, lists and checklists, and this way one frame carries a
         # heading, a checklist, a numbered list, a bulleted list and the toolbar.
         art=lambda c: card(c, "10-editor-toolbar.png", (0, 850, 1320, 2868),
                            1240, 40, 958, radius=48)),

    dict(name="06-code", bg=CHARCOAL, dark=True, seed=33, align="center", lines=2, ttop=196,
         head="Code that still looks like code.",
         sup="Syntax colour, monospaced, and Copy Code.",
         art=lambda c: device(c, "25-code-dark.png", 1000, 830, dark=True)),

    dict(name="07-paste", bg=CHALK, seed=39, align="center", lines=2, ttop=196,
         head="Paste it. Keep the structure.",
         sup="Headings, lists and tables arrive intact.",
         art=lambda c: (device(c, "05-paste.png", 1040, 846),
                        card(c, "05-paste.png", (40, 930, 1290, 1645), 1150, 85, 1552))),

    dict(name="08-durable", bg=PAPER, seed=45, align="center", lines=2, ttop=196,
         head="Your words shouldn't disappear.",
         sup="A dropped connection never costs you the recording.",
         art=lambda c: device(c, "23-retry.png", 920, 810)),

    dict(name="09-find", bg=PAPER, seed=51, align="left", lines=1, ttop=210,
         head="Find it again.",
         sup="Search what you remember. Or start with the day.",
         art=lambda c: (device(c, "01-hero.png", 700, 1020, xoff=-290),
                        card(c, "12-calendar.png", (40, 150, 1280, 2400), 520, 760, 1040),
                        card(c, "11-search.png", (40, 2560, 1280, 2840), 1040, 140, 2440))),

    dict(name="10-privacy", bg=STONE, seed=57, align="center", lines=1, ttop=210,
         head="Private by default.",
         sup="No account. Your notes stay on your iPhone.",
         art=lambda c: device(c, "06-lock.png", 1000, 886)),

    # Composed, not shipped: the carousel is already at Apple's ten. Kept because it is the natural
    # swap when the Share frame arrives, and because dark mode otherwise appears only behind a
    # recorder and a code card.
    dict(name="alt-daynight", bg=PAPER, seed=63, align="center", lines=1,
         ttop=210, head="Yours, day or night.",
         art=lambda c: (night_panel(c, 660, 902),
                        device(c, "13-seattle-dark.png", 700, 1150, xoff=300, dark=True),
                        device(c, "02-structure.png", 700, 1030, xoff=-300))),
]


def main():
    for s in SHOTS:
        override = os.path.join(PLATES, f"{s['name']}.png")
        if os.path.exists(override):
            bg = Image.open(override).convert("RGB").resize((W, H), Image.LANCZOS)
        else:
            bg = ground(s)
        canvas = bg.convert("RGBA")
        s["art"](canvas)
        text_block(canvas, s)
        out = canvas.convert("RGB")
        assert out.size == (W, H), out.size
        out.save(os.path.join(OUT, f"{s['name']}.png"), "PNG")
        print(f"{s['name']}.png {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()
