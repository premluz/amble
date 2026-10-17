"""Logo lockups and launch images for tool/brand_assets.py.

The in-app logo (assets/branding/Logo_on_light.svg and Logo_on_dark.svg) is
the mark from AppIcon.icon beside the wordmark from
assets/branding/source/wordmark.svg, joined with SVG transforms only. The
native launch screens show the app-icon tile. Replace the lockups with
designed artwork when it exists; docs/BRANDING_ASSETS.md says how.
"""
from __future__ import annotations

import re
import subprocess

from PIL import Image

from brand_android import rounded
from brand_spec import *  # noqa: F401,F403 - constants only


def _inner(svg: str) -> str:
    return re.search(r"<svg[^>]*>(.*)</svg>", svg, re.S).group(1).strip()


def _numbers(svg: str, attribute: str) -> list[float]:
    raw = re.search(attribute + r'="([^"]+)"', svg).group(1)
    return [float(v) for v in raw.split()]


def lockup(letters: str) -> tuple[str, float, float]:
    """The lockup SVG text, its width and its height."""
    mark = MARK_SVG.read_text()
    word = WORDMARK.read_text()
    mx, my, mw, mh = 0, 0, *_numbers(mark, "viewBox")[2:]
    wx, wy, ww, wh = _numbers(word, "viewBox")
    scale = wh / mh
    word_x = mw * scale + LOCKUP_GAP
    width = word_x + ww
    body = (
        f'<g transform="scale({scale:.5f})">{_inner(mark)}</g>'
        f'<g transform="translate({word_x:.3f} {-wy:.3f}) translate({-wx:.3f} 0)">'
        f'{_inner(word).replace("#1a1a1a", letters)}</g>'
    )
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width:.2f} {wh:.2f}"'
           f' width="{width:.2f}" height="{wh:.2f}" fill="none">{body}</svg>\n')
    return svg, width, wh


def _preview(name: str, svg: str, width: float, height: float, backdrop: str) -> None:
    """A square PNG of the lockup on its backdrop, for docs and review."""
    side = max(width, height) * 1.6
    tx, ty = (side - width) / 2, (side - height) / 2
    inner = _inner(svg)
    wrapped = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {side:.1f} {side:.1f}">'
        f'<rect width="100%" height="100%" fill="{backdrop}"/>'
        f'<g transform="translate({tx:.1f} {ty:.1f})">{inner}</g></svg>'
    )
    tmp = ROOT / f".{name}.preview.svg"
    tmp.write_text(wrapped)
    try:
        subprocess.run(["qlmanage", "-t", "-s", str(PREVIEW_SIZE), "-o", str(ROOT), str(tmp)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        (ROOT / f"{tmp.name}.png").replace(ROOT / f"assets/branding/{name}.png")
    finally:
        tmp.unlink(missing_ok=True)


def write_lockups() -> None:
    for name, letters, backdrop in (
        ("Logo_on_light", LETTERS_ON_LIGHT, "#FFFFFF"),
        ("Logo_on_dark", LETTERS_ON_DARK, "#20211F"),
    ):
        svg, width, height = lockup(letters)
        (ROOT / f"assets/branding/{name}.svg").write_text(svg)
        _preview(name, svg, width, height, backdrop)


def write_launch_images(master: Image.Image) -> None:
    """The app-icon tile on the launch background (white; the tile is dark)."""
    for scale in (1, 2, 3):
        px = LAUNCH_TILE_PX * scale
        tile = rounded(master.resize((px, px), Image.LANCZOS))
        suffix = "" if scale == 1 else f"@{scale}x"
        for stem in ("LaunchImage", "LaunchImage-dark"):
            tile.save(IOS_LAUNCH / f"{stem}{suffix}.png")
    tile = rounded(master.resize((ANDROID_LAUNCH_PX,) * 2, Image.LANCZOS))
    for folder in ("drawable", "drawable-night"):
        tile.save(ANDROID_RES / folder / "launch_image.png")
