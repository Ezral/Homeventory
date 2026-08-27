#!/usr/bin/env python3
"""Generate Android / web launcher icons from assets/brand/app_icon_{light,dark}.png."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "assets" / "brand"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
WEB = ROOT / "web"

LIGHT_BG = (243, 246, 244, 255)  # AppColors.paper
DARK_BG = (17, 17, 17, 255)
DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}


def trim(im: Image.Image, alpha_min: int = 8) -> Image.Image:
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    alpha = im.split()[-1]
    bbox = alpha.point(lambda p: 255 if p >= alpha_min else 0).getbbox()
    return im.crop(bbox) if bbox else im


def white_on_transparent(im: Image.Image) -> Image.Image:
    """Keep light strokes; treat near-black as transparent."""
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    pixels = []
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            lum = (r + g + b) / 3
            pixels.append((255, 255, 255, int(round(lum))))
    out = Image.new("RGBA", rgba.size)
    out.putdata(pixels)
    return trim(out)


def black_on_transparent(im: Image.Image) -> Image.Image:
    """Keep dark strokes on a transparent field."""
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    pixels = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                pixels.append((0, 0, 0, 0))
                continue
            lum = (r + g + b) / 3
            stroke = a if a < 250 else int(round(255 - lum))
            pixels.append((18, 24, 21, max(0, min(255, stroke))))
    out = Image.new("RGBA", rgba.size)
    out.putdata(pixels)
    return trim(out)


def fit(im: Image.Image, size: int, padding: float) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = max(1, int(round(size * (1 - 2 * padding))))
    copy = im.copy()
    copy.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    x = (size - copy.width) // 2
    y = (size - copy.height) // 2
    canvas.paste(copy, (x, y), copy)
    return canvas


def composite(fg: Image.Image, bg: tuple[int, int, int, int], size: int, padding: float) -> Image.Image:
    layer = fit(fg, size, padding)
    out = Image.new("RGBA", (size, size), bg)
    out.alpha_composite(layer)
    return out


def save_png(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG", optimize=True)


def main() -> None:
    light_src = Image.open(BRAND / "app_icon_light.png")
    dark_src = Image.open(BRAND / "app_icon_dark.png")
    black_fg = black_on_transparent(light_src)
    white_fg = white_on_transparent(dark_src)

    # Adaptive foreground: 108dp, artwork in the inner ~66% safe zone.
    for name, scale in DENSITIES.items():
        size = int(round(108 * scale))
        save_png(
            fit(black_fg, size, 0.18),
            ANDROID_RES / f"drawable-{name}" / "ic_launcher_foreground.png",
        )
        save_png(
            fit(white_fg, size, 0.18),
            ANDROID_RES / f"drawable-night-{name}" / "ic_launcher_foreground.png",
        )
        legacy = int(round(48 * scale))
        save_png(
            composite(black_fg, LIGHT_BG, legacy, 0.14),
            ANDROID_RES / f"mipmap-{name}" / "ic_launcher.png",
        )
        save_png(
            composite(white_fg, DARK_BG, legacy, 0.14),
            ANDROID_RES / f"mipmap-night-{name}" / "ic_launcher.png",
        )
        notify = int(round(24 * scale))
        save_png(
            fit(white_fg, notify, 0.08),
            ANDROID_RES / f"drawable-{name}" / "ic_stat_notify.png",
        )

    # Themed / monochrome (system tints this).
    save_png(
        fit(black_fg, 432, 0.18),
        ANDROID_RES / "drawable-xxxhdpi" / "ic_launcher_monochrome.png",
    )

    # Web / PWA
    save_png(composite(black_fg, LIGHT_BG, 32, 0.08), WEB / "favicon.png")
    save_png(composite(white_fg, DARK_BG, 32, 0.08), WEB / "favicon-dark.png")
    save_png(composite(black_fg, LIGHT_BG, 192, 0.12), WEB / "icons" / "Icon-192.png")
    save_png(composite(black_fg, LIGHT_BG, 512, 0.12), WEB / "icons" / "Icon-512.png")
    save_png(composite(black_fg, LIGHT_BG, 192, 0.18), WEB / "icons" / "Icon-maskable-192.png")
    save_png(composite(black_fg, LIGHT_BG, 512, 0.18), WEB / "icons" / "Icon-maskable-512.png")
    save_png(composite(white_fg, DARK_BG, 192, 0.12), WEB / "icons" / "Icon-dark-192.png")
    save_png(composite(white_fg, DARK_BG, 512, 0.12), WEB / "icons" / "Icon-dark-512.png")
    print("Wrote Android mipmaps, adaptive foregrounds, notification icon, and web icons.")


if __name__ == "__main__":
    main()
