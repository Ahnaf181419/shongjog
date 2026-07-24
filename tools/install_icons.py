"""
Install generated icons into Android and iOS native directories.
Run after generate_icon.py.

Run: python tools/install_icons.py
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / "tools" / "generated_icon"

# ── Android mipmap ──────────────────────────────────────
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"

ANDROID_MAP = {
    "mdpi": "ic_launcher_mdpi.png",
    "hdpi": "ic_launcher_hdpi.png",
    "xhdpi": "ic_launcher_xhdpi.png",
    "xxhdpi": "ic_launcher_xxhdpi.png",
    "xxxhdpi": "ic_launcher_xxxhdpi.png",
}

for density, src_name in ANDROID_MAP.items():
    dest_dir = ANDROID_RES / f"mipmap-{density}"
    dest = dest_dir / "ic_launcher.png"
    src = GEN / src_name
    if src.exists():
        dest_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(src), str(dest))
        print(f"  Android {density}: {dest}")

# Remove old flutter_launcher_icons adaptive icon files
for f in [
    ANDROID_RES / "mipmap-anydpi-v26" / "ic_launcher.xml",
    ANDROID_RES / "values" / "colors.xml",
]:
    if f.exists():
        f.unlink()
        print(f"  Removed old: {f}")

# Remove old foreground drawables
for d in ANDROID_RES.glob("drawable-*"):
    fg = d / "ic_launcher_foreground.png"
    if fg.exists():
        fg.unlink()
        print(f"  Removed old: {fg}")

# Remove empty mipmap-anydpi-v26 dir
anydpi = ANDROID_RES / "mipmap-anydpi-v26"
if anydpi.exists() and not any(anydpi.iterdir()):
    anydpi.rmdir()
    print(f"  Removed empty: {anydpi}")

# ── iOS AppIcon ─────────────────────────────────────────
IOS_ICONSET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

IOS_MAP = {
    "Icon-App-20x20@1x.png": "Icon-App-20x20@1x.png",
    "Icon-App-20x20@2x.png": "Icon-App-20x20@2x.png",
    "Icon-App-20x20@3x.png": "Icon-App-20x20@3x.png",
    "Icon-App-29x29@1x.png": "Icon-App-29x29@1x.png",
    "Icon-App-29x29@2x.png": "Icon-App-29x29@2x.png",
    "Icon-App-29x29@3x.png": "Icon-App-29x29@3x.png",
    "Icon-App-40x40@1x.png": "Icon-App-40x40@1x.png",
    "Icon-App-40x40@2x.png": "Icon-App-40x40@2x.png",
    "Icon-App-40x40@3x.png": "Icon-App-40x40@3x.png",
    "Icon-App-60x60@2x.png": "Icon-App-60x60@2x.png",
    "Icon-App-60x60@3x.png": "Icon-App-60x60@3x.png",
    "Icon-App-76x76@1x.png": "Icon-App-76x76@1x.png",
    "Icon-App-76x76@2x.png": "Icon-App-76x76@2x.png",
    "Icon-App-83.5x83.5@2x.png": "Icon-App-83.5x83.5@2x.png",
    "Icon-App-1024x1024@1x.png": "Icon-App-1024x1024@1x.png",
}

for src_name, dest_name in IOS_MAP.items():
    src = GEN / src_name
    dest = IOS_ICONSET / dest_name
    if src.exists():
        shutil.copy2(str(src), str(dest))
        print(f"  iOS: {dest_name}")

print("\nIcons installed.")
