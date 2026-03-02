#!/usr/bin/env python3
"""Generate Ennui app icon: warm amber orb in deep dark space."""

import json, math, os, random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

MASTER = 1024
OUT = Path("Ennui/Assets.xcassets/AppIcon.appiconset")

VARIANTS = [
    ("icon_16x16.png", 16, 1), ("icon_16x16@2x.png", 32, 2),
    ("icon_32x32.png", 32, 1), ("icon_32x32@2x.png", 64, 2),
    ("icon_128x128.png", 128, 1), ("icon_128x128@2x.png", 256, 2),
    ("icon_256x256.png", 256, 1), ("icon_256x256@2x.png", 512, 2),
    ("icon_512x512.png", 512, 1), ("icon_512x512@2x.png", 1024, 2),
]


def radial(size, cx, cy, c_in, c_out, r_in, r_out):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if d <= r_in: t = 0.0
            elif d >= r_out: t = 1.0
            else: t = (d - r_in) / (r_out - r_in)
            t = t * t * (3.0 - 2.0 * t)  # smoothstep
            px[x, y] = tuple(int(c_in[i] + (c_out[i] - c_in[i]) * t) for i in range(4))
    return img


def draw():
    s = MASTER
    c = s // 2
    img = Image.new("RGBA", (s, s), (10, 8, 15, 255))

    # Faint purple-brown space wash
    img = Image.alpha_composite(img, radial(s, c, c, (30, 18, 35, 40), (10, 8, 15, 0), 0, int(s * 0.6)))

    # Asymmetric warm dust
    img = Image.alpha_composite(img, radial(s, int(c * 0.85), int(c * 1.1), (45, 25, 15, 25), (10, 8, 15, 0), 0, int(s * 0.45)))

    # Outermost orb glow
    g = radial(s, c, c, (90, 45, 15, 55), (30, 15, 8, 0), 0, int(s * 0.42))
    g = g.filter(ImageFilter.GaussianBlur(radius=s * 0.06))
    img = Image.alpha_composite(img, g)

    # Main amber glow
    g = radial(s, c, c, (210, 140, 55, 180), (120, 60, 20, 0), 0, int(s * 0.28))
    g = g.filter(ImageFilter.GaussianBlur(radius=s * 0.045))
    img = Image.alpha_composite(img, g)

    # Inner bright glow
    g = radial(s, c, c, (245, 195, 100, 210), (200, 120, 40, 0), 0, int(s * 0.16))
    g = g.filter(ImageFilter.GaussianBlur(radius=s * 0.025))
    img = Image.alpha_composite(img, g)

    # Hot core
    g = radial(s, c, c, (255, 248, 230, 250), (250, 200, 100, 0), 0, int(s * 0.065))
    g = g.filter(ImageFilter.GaussianBlur(radius=s * 0.012))
    img = Image.alpha_composite(img, g)

    # Brilliant centre dot
    img = Image.alpha_composite(img, radial(s, c, c, (255, 252, 245, 255), (255, 240, 200, 0), 0, int(s * 0.022)))

    # Stars
    stars = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stars)
    rng = random.Random(42)
    for _ in range(60):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(s * 0.25, s * 0.48)
        sx, sy = c + math.cos(a) * d, c + math.sin(a) * d
        p = d / (s * 0.48)
        b = int(rng.uniform(30, 90) * p)
        w = rng.uniform(0.6, 1.0)
        r = min(255, int(b * (0.85 + w * 0.15)))
        g2 = min(255, int(b * (0.80 + w * 0.10)))
        bl = min(255, int(b * (1.0 - w * 0.2)))
        rad = rng.uniform(0.5, 1.8)
        sd.ellipse([sx - rad, sy - rad, sx + rad, sy + rad], fill=(r, g2, bl, int(b * 0.85)))
    for _ in range(12):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(s * 0.30, s * 0.46)
        sx, sy = c + math.cos(a) * d, c + math.sin(a) * d
        b = rng.randint(80, 140)
        rad = rng.uniform(1.0, 2.5)
        sd.ellipse([sx - rad, sy - rad, sx + rad, sy + rad],
                   fill=(min(255, b), min(255, int(b * 0.88)), min(255, int(b * 0.72)), int(b * 0.8)))
    img = Image.alpha_composite(img, stars)

    # Vignette
    img = Image.alpha_composite(img, radial(s, c, c, (0, 0, 0, 0), (5, 3, 10, 80), int(s * 0.35), int(s * 0.50)))

    return img


OUT.mkdir(parents=True, exist_ok=True)
Path("Ennui/Assets.xcassets").joinpath("Contents.json").write_text(
    json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))

print("Drawing 1024×1024 master...")
master = draw()

images = []
for name, px, scale in VARIANTS:
    master.resize((px, px), Image.Resampling.LANCZOS).save(OUT / name, "PNG")
    images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{px // scale}x{px // scale}"})
    print(f"  {name} ({px}px)")

(OUT / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2))
print("Done!")
