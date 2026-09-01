#!/usr/bin/env python3
"""Compose the As Told App Store screenshot set at 1320x2868 (6.9").

Real app UI comes from raw/library/*.png — the canonical raw library, captured via simctl at native
resolution on one device, one dataset, one clock — and is composited untouched. The marketing layer
never redraws a pixel of the product (App Review 2.3.3: the screen must be the app).

Rebuilt 2026-09-01 as ONE system across all ten frames, rather than the varied compositions of the
2026-08-29 set: the same lockup, the same headline position and scale rule, the same device width
and top edge, the same rule and support line. What varies is the ground (light / dark, in a rhythm)
and, once, the number of phones. A carousel is read as a sequence, and a sequence with one grammar
is read as one product.

Drop a 1320x2868 image at plates/<name>.png to override a frame's background — that is where a
generated plate (GPT Image 2 or otherwise) goes. The plate is the stage; the screen is never touched.
"""
import os
import random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 2868
HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw", "library")
PLATES = os.path.join(HERE, "plates")
OUT = os.path.join(HERE, "6.9")
ICON = os.path.join(HERE, "..", "..", "Resources", "Assets.xcassets", "AppIcon.appiconset",
                    "icon-1024.png")
os.makedirs(OUT, exist_ok=True)

# The app's own palette since 2026-08-30 is neutral — no cream, no brand colour on a content surface
# — so the frames stopped being warm paper on the same day. Light is the grouped canvas the app
# draws Home on; dark is the ink the editor uses at night. Same family as the screen inside them.
LIGHT = (241, 241, 245)
DARK = (18, 18, 20)
INK = (28, 28, 30)
INK_SOFT = (96, 98, 104)
PAPER_INK = (240, 240, 238)
PAPER_SOFT = (170, 172, 178)
ACCENT = (49, 77, 99)          # the app's Accent
ACCENT_DK = (143, 176, 200)

NY = "/System/Library/Fonts/NewYork.ttf"
SF = "/System/Library/Fonts/SFNS.ttf"

# One geometry for every frame.
MARGIN = 92
LOCKUP_TOP = 150          # icon + wordmark
HEAD_TOP = 318            # first headline line
DEVICE_TOP = 900          # every single phone starts here …
DEVICE_W = 860            # … at this width: fully visible, bottom at 2769, nothing cut off
PAIR_TOP, PAIR_W, PAIR_XOFF = 1000, 590, 312   # 45px clear of each edge, bezel included


def ny(size, weight=600, opsz=40):
    """New York, the brand serif (Core/DesignSystem/AppMark.swift).

    The Optical Size axis defaults to its 256 maximum — a poster grade whose hairline crossbars make
    "Hindi" read as "I Iindi". Pin it near the rendered point size so the headline matches the
    wordmark the app itself draws.
    """
    f = ImageFont.truetype(NY, size)
    f.set_variation_by_axes([opsz, weight, 0])
    return f


def sf(size, weight=400, opsz=20):
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_axes([100, opsz, 400, weight])
    return f


def ground(spec):
    """A flat ground with a whisper of depth behind the headline, and a little grain."""
    dark = spec.get("dark")
    base = Image.new("RGB", (W, H), DARK if dark else LIGHT)
    glow = Image.new("L", (W // 5, H // 5), 0)
    ImageDraw.Draw(glow).ellipse(
        [W / 5 * 0.06, H / 5 * 0.03, W / 5 * 0.72, H / 5 * 0.30], fill=44)
    glow = glow.filter(ImageFilter.GaussianBlur(22)).resize((W, H))
    lift = (52, 52, 58) if dark else (255, 255, 255)
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


def shadow(canvas, box, radius, blur, alpha, dy, tint=(40, 40, 44)):
    x0, y0, x1, y1 = box
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([x0 + 12, y0 + dy, x1 - 12, y1 + dy - 8],
                                        radius=radius, fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new("RGBA", (W, H), tint + (255,))
    sh.putalpha(m)
    canvas.alpha_composite(sh)


def load(name):
    return Image.open(os.path.join(RAW, name)).convert("RGB")


def device(canvas, shot, width=DEVICE_W, top=DEVICE_TOP, xoff=0, dark=False):
    """The whole phone in a thin, accurate bezel. Radius matches the real display; nothing is
    cropped, nothing bleeds off the canvas."""
    im = load(shot)
    h = int(im.size[1] * (width / im.size[0]))
    im = im.resize((width, h), Image.LANCZOS)
    inner_r = int(width * 0.125)
    bez = max(10, int(width * 0.0132))
    bw, bh = width + bez * 2, h + bez * 2
    outer_r = inner_r + bez
    x = (W - width) // 2 + xoff
    bx, by = x - bez, top - bez
    tint = (0, 0, 0) if dark else (40, 40, 44)
    shadow(canvas, (bx, by, bx + bw, by + bh), outer_r, 70, 56 if dark else 52, 46, tint)
    shadow(canvas, (bx, by, bx + bw, by + bh), outer_r, 18, 70, 10, tint)
    body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=outer_r, fill=(34, 34, 38, 255))
    bd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=outer_r,
                         outline=(88, 86, 84, 255), width=2)
    body.alpha_composite(rounded(im, inner_r), (bez, bez))
    canvas.alpha_composite(body, (bx, by))


def night_panel(canvas, x0, y0, radius=64):
    """Charcoal ground for the dark half of the day/night frame, kept clear of the headline."""
    panel = Image.new("RGBA", (W - x0 + 60, H - y0 + 60), (0, 0, 0, 0))
    ImageDraw.Draw(panel).rounded_rectangle(
        [0, 0, panel.size[0] - 1, panel.size[1] - 1], radius=radius, fill=DARK + (255,))
    canvas.alpha_composite(panel, (x0, y0))


def lockup(canvas, dark=False):
    """The app icon and the wordmark, centred, the same on every frame.

    The 2026-08-29 set carried no logo — the icon already sits above the carousel. This set does, by
    decision (2026-09-01): a small lockup rather than the icon tile alone, so it reads as a name at
    the top of a page, not as a second icon.
    """
    size = 84
    icon = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    icon = rounded(icon.convert("RGB"), int(size * 0.225))
    f = ny(50, weight=600, opsz=40)
    d = ImageDraw.Draw(canvas)
    word = "As Told"
    tw = d.textlength(word, font=f)
    gap = 22
    total = size + gap + tw
    x = (W - total) / 2
    canvas.alpha_composite(icon, (int(x), LOCKUP_TOP))
    asc, desc = f.getmetrics()
    ty = LOCKUP_TOP + size / 2 - (asc - desc) / 2 - 4
    d.text((x + size + gap, ty), word, font=f, fill=PAPER_INK if dark else INK)


def wrap(draw, text, fnt, maxw):
    """Greedy wrap, except that a literal newline is honoured as a hard break — a headline is a
    few words of copy, and where it breaks is a design decision, not a paragraph's accident."""
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
    maxw = W - 2 * MARGIN
    dark = spec.get("dark")
    ink = PAPER_INK if dark else INK
    soft = PAPER_SOFT if dark else INK_SOFT
    rule = ACCENT_DK if dark else ACCENT

    # One size for the whole set would be ideal; the next best thing is one *rule*: the largest size
    # at which the headline holds in two lines, from a fixed ceiling. Every frame's copy was written
    # to land at or near that ceiling, so the set reads at one scale.
    size = 140
    while size > 96:
        hf = ny(size, weight=600, opsz=40)
        hl = wrap(d, spec["head"], hf, maxw)
        if len(hl) <= 2:
            break
        size -= 3

    supf = sf(46, weight=400, opsz=20)
    sl = wrap(d, spec["sup"], supf, min(maxw, 1090))

    def cx(txt, fnt):
        return (W - d.textlength(txt, font=fnt)) / 2

    y = HEAD_TOP
    last_top = y
    for ln in hl:
        d.text((cx(ln, hf), y), ln, font=hf, fill=ink)
        last_top = y
        y += int(size * 1.04)

    # The rule clears the glyph box (ascent + descent), not the line advance, so it never runs
    # through a descender.
    ascent, descent = hf.getmetrics()
    y = last_top + ascent + descent + 22
    rw = 84
    d.rectangle([(W - rw) / 2, y, (W + rw) / 2, y + 5], fill=rule)
    y += 40
    for ln in sl:
        d.text((cx(ln, supf), y), ln, font=supf, fill=soft)
        y += 60
    return y


# The ten frames (locked 2026-09-01). Every screen is a file in raw/library; every headline is a
# claim the screen under it proves; every support line says what the picture shows.
#
# Grounds alternate in a rhythm rather than strictly — light · dark · light · dark · light · light ·
# light · dark · split · light — so the two voice frames and the code frame sit on charcoal, where a
# near-empty recording screen reads as focus rather than as a blank page.
#
# No language is named anywhere (RULES.md §7), the voice allowance is not mentioned (§8), and the
# Share sheet is still absent: a simulator cannot capture the real one.
SHOTS = [
    dict(name="01-words", seed=3,
         head="Anything you want to put into words.",
         sup="Today and this week, in one quiet Home.",
         art=lambda c: device(c, "01-home-light.png")),

    dict(name="02-voice", seed=9, dark=True,
         head="Or just say it.",
         sup="Tap the mic on Home and start talking. No note to create first.",
         art=lambda c: device(c, "03-quickvoice-listening.png", dark=True)),

    dict(name="03-note", seed=15,
         head="Your words become a note.",
         sup="What you said, as an ordinary note you can keep editing.",
         art=lambda c: device(c, "05-voice-note-titleless.png")),

    dict(name="04-pause", seed=21, dark=True,
         head="Pause. Think.\nKeep going.",
         sup="One recording that waits while you find the next sentence.",
         art=lambda c: device(c, "04-quickvoice-paused.png", dark=True)),

    dict(name="05-structure", seed=27,
         head="Structure when you need it.",
         sup="Headings, numbered lists and checklists — drawn as circles.",
         art=lambda c: device(c, "06-japan-trip-light.png")),

    dict(name="06-find", seed=33,
         head="Find what you wrote, by day.",
         sup="Dots mark the busy days.\nTap one to see what you wrote.",
         art=lambda c: device(c, "09-calendar.png")),

    dict(name="07-paste", seed=39,
         head="Paste it. Keep the structure.",
         sup="A table stays a table, with your words around it.",
         art=lambda c: device(c, "10-trip-budget.png")),

    dict(name="08-code", seed=45, dark=True,
         head="Code that still looks like code.",
         sup="Syntax colour and the language named,\nwith Copy Code one tap away.",
         art=lambda c: device(c, "11-monthly-units-query.png", dark=True)),

    # Two phones, the same note at the same scroll position. The night panel starts under the
    # support line so the headline stays on one ground.
    dict(name="09-daynight", seed=51,
         head="Yours,\nday or night.",
         sup="The same note in Light and in Dark.",
         art=lambda c: (night_panel(c, 660, 880),
                        device(c, "06-japan-trip-light.png", PAIR_W, PAIR_TOP, xoff=-PAIR_XOFF),
                        device(c, "12-japan-trip-dark.png", PAIR_W, PAIR_TOP, xoff=PAIR_XOFF,
                               dark=True))),

    dict(name="10-privacy", seed=57,
         head="Your recording.\nYour choice.",
         sup="Audio leaves your iPhone only when you say so — and nothing else goes with it.",
         art=lambda c: device(c, "16-voice-consent.png")),
]


def main():
    for stale in os.listdir(OUT):
        if stale.endswith(".png") and stale[:-4] not in {s["name"] for s in SHOTS}:
            os.remove(os.path.join(OUT, stale))
    for s in SHOTS:
        override = os.path.join(PLATES, f"{s['name']}.png")
        if os.path.exists(override):
            bg = Image.open(override).convert("RGB").resize((W, H), Image.LANCZOS)
        else:
            bg = ground(s)
        canvas = bg.convert("RGBA")
        s["art"](canvas)
        lockup(canvas, dark=s.get("dark", False))
        text_end = text_block(canvas, s)
        assert text_end <= (PAIR_TOP if s["name"] == "09-daynight" else DEVICE_TOP) - 40, \
            f"{s['name']}: text runs to {text_end}, into the device"
        out = canvas.convert("RGB")
        assert out.size == (W, H), out.size
        out.save(os.path.join(OUT, f"{s['name']}.png"), "PNG")
        print(f"{s['name']}.png {out.size[0]}x{out.size[1]}  text ends {text_end}")


if __name__ == "__main__":
    main()
