"""
Generate app launcher icons for Shongjog.
Programmatically creates a shield + heart icon — no external assets.

Run: python tools/generate_icon.py
"""
from pathlib import Path
from PIL import Image, ImageDraw
import math

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "tools" / "generated_icon"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Sizes needed by flutter_launcher_icons
SIZES = {
    "icon.png": 1024,           # iOS marketing / fallback
    "android": {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    },
    "ios": {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    },
}

TEAL = (13, 148, 136)        # #0D9488
DEEP_BLUE = (12, 74, 110)    # #0C4A6E
AMBER = (245, 158, 11)       # #F59E0B
WHITE = (255, 255, 255)


def draw_shield(draw: ImageDraw.ImageDraw, cx: float, cy: float, w: float, h: float, color, width: int = 4):
    """Draw a shield outline centered at (cx, cy) with given width/height."""
    # Shield path as a series of bezier-like line segments
    # Top center -> top right curve -> right side -> bottom point -> left side -> top left curve
    top = cy - h * 0.48
    bot = cy + h * 0.48
    left = cx - w * 0.46
    right = cx + w * 0.46
    mid_y = cy - h * 0.05

    points = []
    # Approximate shield shape with line segments
    steps = 60
    for i in range(steps + 1):
        t = i / steps
        if t <= 0.25:
            # Top center to top-right
            lt = t / 0.25
            x = cx + (right - cx) * lt
            y = top + (mid_y - top) * 0.1 * lt
        elif t <= 0.5:
            # Top-right to bottom point
            lt = (t - 0.25) / 0.25
            x = right - (right - cx) * lt
            y = mid_y + (bot - mid_y) * lt
        elif t <= 0.75:
            # Bottom point to top-left
            lt = (t - 0.5) / 0.25
            x = cx - (cx - left) * lt
            y = bot - (bot - mid_y) * lt
        else:
            # Top-left to top center
            lt = (t - 0.75) / 0.25
            x = left + (cx - left) * lt
            y = mid_y + (top - mid_y) * 0.1 * (1 - lt)
        points.append((x, y))

    # Draw smooth shield
    draw.polygon(points, outline=color, fill=None)
    # Thicker line by drawing multiple offsets
    for offset in range(1, width):
        scaled_points = []
        for x, y in points:
            dx = x - cx
            dy = y - cy
            scale = 1.0 + offset * 0.003
            scaled_points.append((cx + dx * scale, cy + dy * scale))
        draw.polygon(scaled_points, outline=color, fill=None)
        scaled_points2 = []
        for x, y in points:
            dx = x - cx
            dy = y - cy
            scale = 1.0 - offset * 0.003
            scaled_points2.append((cx + dx * scale, cy + dy * scale))
        draw.polygon(scaled_points2, outline=color, fill=None)


def draw_heart(draw: ImageDraw.ImageDraw, cx: float, cy: float, size: float, color):
    """Draw a heart icon centered at (cx, cy)."""
    s = size * 0.5
    # Heart using two circles and a triangle
    r = s * 0.32
    # Left circle center
    lx = cx - s * 0.26
    ly = cy - s * 0.12
    # Right circle center
    rx = cx + s * 0.26
    ry = cy - s * 0.12

    draw.ellipse([lx - r, ly - r, lx + r, ly + r], fill=color)
    draw.ellipse([rx - r, ry - r, rx + r, ry + r], fill=color)

    # Triangle for the bottom point
    draw.polygon([
        (cx - s * 0.52, cy - s * 0.02),
        (cx + s * 0.52, cy - s * 0.02),
        (cx, cy + s * 0.65),
    ], fill=color)


def create_icon(size: int) -> Image.Image:
    """Create a single icon at the given size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background: radial-ish gradient (simpler: solid teal circle on white)
    # For adaptive icons, the background is handled by the OS.
    # For the 1024 marketing icon, draw a full background.
    if size >= 120:
        # Gradient background approximation
        for y in range(size):
            t = y / size
            r = int(TEAL[0] * (1 - t) + DEEP_BLUE[0] * t)
            g = int(TEAL[1] * (1 - t) + DEEP_BLUE[1] * t)
            b = int(TEAL[2] * (1 - t) + DEEP_BLUE[2] * t)
            draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    else:
        # Small icons: solid teal
        draw.rectangle([0, 0, size, size], fill=(*TEAL, 255))

    cx, cy = size / 2, size / 2

    # Shield (white outline)
    shield_w = size * 0.7
    shield_h = size * 0.8
    line_w = max(2, size // 50)
    draw_shield(draw, cx, cy, shield_w, shield_h, (*WHITE, 255), line_w)

    # Heart (amber)
    heart_size = size * 0.28
    draw_heart(draw, cx, cy + size * 0.02, heart_size, (*AMBER, 255))

    return img


def main():
    # Generate the master 1024x1024 icon
    master = create_icon(1024)
    master_path = OUT_DIR / "icon.png"
    master.save(str(master_path), "PNG")
    print(f"Created {master_path} (1024x1024)")

    # Generate Android mipmap icons
    for density, px in SIZES["android"].items():
        resized = master.resize((px, px), Image.LANCZOS)
        out = OUT_DIR / f"ic_launcher_{density}.png"
        resized.save(str(out), "PNG")
        print(f"  Android {density}: {px}x{px} -> {out.name}")

    # Generate iOS icons
    for name, px in SIZES["ios"].items():
        resized = master.resize((px, px), Image.LANCZOS)
        out = OUT_DIR / name
        resized.save(str(out), "PNG")
        print(f"  iOS {name}: {px}x{px}")

    print(f"\nAll icons generated in {OUT_DIR}")


if __name__ == "__main__":
    main()
