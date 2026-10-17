#!/usr/bin/env python3
"""Regenerates every app-icon file from the one source, assets/branding/AppIcon.icon.

    python3 tool/brand_assets.py            # regenerate everything
    python3 tool/brand_assets.py --verify   # check the outputs exist and are sized right

Needs Xcode 26+ (Icon Composer's `ictool`) and Python 3 with Pillow
(`pip3 install pillow`). What each output is, and what is NOT generated, is
in docs/BRANDING_ASSETS.md; keep the two in step. Geometry lives in
brand_spec.py, the Android outputs in brand_android.py.
"""
from __future__ import annotations

import json
import subprocess
import sys

from PIL import Image, ImageDraw

from brand_android import write_android_adaptive, write_android_legacy
from brand_logo import write_launch_images, write_lockups
from brand_spec import *  # noqa: F401,F403 - constants only


def flat_master(size: int = 1024) -> Image.Image:
    """The icon as an opaque full-bleed square, drawn supersampled."""
    big = size * SUPERSAMPLE
    image = Image.new("RGB", (big, big), BACKGROUND)
    draw = ImageDraw.Draw(image)
    k = big / 1024
    cx = big / 2 + MARK_OFFSET[0] * k
    cy = big / 2 + MARK_OFFSET[1] * k
    for x, y, w, h, r, colour in SHAPES:
        x0 = cx + (x - MARK_CENTER[0]) * MARK_SCALE * k
        y0 = cy + (y - MARK_CENTER[1]) * MARK_SCALE * k
        draw.rounded_rectangle(
            (x0, y0, x0 + w * MARK_SCALE * k, y0 + h * MARK_SCALE * k),
            radius=r * MARK_SCALE * k,
            fill=colour,
        )
    return image.resize((size, size), Image.LANCZOS)


def ictool_png(path: Path, size: int) -> None:
    subprocess.run(
        [str(ICTOOL), str(ICON), "--export-image", "--output-file", str(path),
         "--platform", "macOS", "--rendition", "Default",
         "--width", str(size), "--height", str(size), "--scale", "1"],
        check=True, stdout=subprocess.DEVNULL,
    )


def write_macos() -> None:
    for size in MACOS_SIZES:
        ictool_png(MACOS_SET / f"app_icon_{size}.png", size)


def write_ios(master: Image.Image) -> None:
    contents = json.loads((IOS_SET / "Contents.json").read_text())
    for entry in contents["images"]:
        side = float(entry["size"].split("x")[0])
        pixels = round(side * int(entry["scale"].rstrip("x")))
        master.resize((pixels, pixels), Image.LANCZOS).save(IOS_SET / entry["filename"])


def rounded(image: Image.Image) -> Image.Image:
    size = image.width
    mask = Image.new("L", (size * SUPERSAMPLE,) * 2, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, *mask.size), radius=LEGACY_CORNER * mask.width, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask.resize((size, size), Image.LANCZOS))
    return out


def write_android_legacy(master: Image.Image) -> None:
    for density, pixels in LEGACY_DENSITIES.items():
        small = master.resize((pixels, pixels), Image.LANCZOS)
        rounded(small).save(ANDROID_RES / f"mipmap-{density}/ic_launcher.png")


def write_store(master: Image.Image) -> None:
    STORE.mkdir(exist_ok=True)
    master.save(STORE / "appstore-1024.png")
    master.resize((PLAY_STORE_SIZE,) * 2, Image.LANCZOS).convert("RGBA").save(
        STORE / "playstore-512.png")


def generate() -> None:
    if not ICON.is_dir():
        sys.exit(f"Missing {ICON}")
    if not ICTOOL.exists():
        sys.exit("Icon Composer's ictool not found: install Xcode 26 or later.")
    master = flat_master()
    master.save(MASTER)
    write_macos()
    write_ios(master)
    write_android_legacy(master)
    write_android_adaptive()
    write_store(master)
    write_lockups()
    write_launch_images(master)
    print("Regenerated. Next: docs/BRANDING_ASSETS.md lists what else to check.")


def verify() -> int:
    failures = []

    def expect(path: Path, size: int, alpha: bool | None = None) -> None:
        if not path.exists():
            failures.append(f"missing {path.relative_to(ROOT)}")
            return
        with Image.open(path) as image:
            if image.size != (size, size):
                failures.append(f"{path.relative_to(ROOT)} is {image.size}, want {size}")
            if alpha is not None and (image.mode in ("RGBA", "LA")) != alpha:
                failures.append(f"{path.relative_to(ROOT)} alpha should be {alpha}")

    for size in MACOS_SIZES:
        expect(MACOS_SET / f"app_icon_{size}.png", size)
    contents = json.loads((IOS_SET / "Contents.json").read_text())
    for entry in contents["images"]:
        side = float(entry["size"].split("x")[0]) * int(entry["scale"].rstrip("x"))
        expect(IOS_SET / entry["filename"], round(side))
    expect(IOS_SET / "Icon-App-1024x1024@1x.png", 1024, alpha=False)
    expect(MASTER, 1024, alpha=False)
    expect(STORE / "appstore-1024.png", 1024, alpha=False)
    expect(STORE / "playstore-512.png", PLAY_STORE_SIZE)
    for density, pixels in LEGACY_DENSITIES.items():
        expect(ANDROID_RES / f"mipmap-{density}/ic_launcher.png", pixels)
    for name in ("mipmap-anydpi-v26/ic_launcher.xml",
                 "drawable/ic_launcher_foreground.xml",
                 "drawable/ic_launcher_monochrome.xml",
                 "values/ic_launcher_background.xml"):
        if not (ANDROID_RES / name).exists():
            failures.append(f"missing android res {name}")
    for scale in (1, 2, 3):
        suffix = "" if scale == 1 else f"@{scale}x"
        for stem in ("LaunchImage", "LaunchImage-dark"):
            expect(IOS_LAUNCH / f"{stem}{suffix}.png", LAUNCH_TILE_PX * scale)
    for folder in ("drawable", "drawable-night"):
        expect(ANDROID_RES / folder / "launch_image.png", ANDROID_LAUNCH_PX)
    for name in ("Logo_on_light", "Logo_on_dark"):
        for extension in ("svg", "png"):
            if not (ROOT / f"assets/branding/{name}.{extension}").exists():
                failures.append(f"missing {name}.{extension}")
    print("\n".join(failures) or "All brand icon outputs present and sized right.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(verify() if "--verify" in sys.argv else generate() or 0)
