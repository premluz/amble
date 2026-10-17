"""Shared constants for tool/brand_assets.py: paths and the icon's geometry."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICON = ROOT / "assets/branding/AppIcon.icon"
ICTOOL = Path(
    "/Applications/Xcode.app/Contents/Applications/"
    "Icon Composer.app/Contents/Executables/ictool"
)

# The flat icon (iOS fallback, Android legacy, store listings) repeats the
# .icon's layout by hand, since Icon Composer only exports masked renders.
# Values are read off AppIcon.icon: its fill, its layer's scale/translation,
# and the shapes in its SVG layer. Change the .icon, change these.
BACKGROUND = (51, 51, 51)          # the .icon fill as rendered (#333333)
MARK_SCALE = 2.69                  # layer scale: canvas px per SVG unit @1024
MARK_CENTER = (97.5, 153.0)        # centre of the SVG layer (195 x 306)
MARK_OFFSET = (0, -10)             # layer translation, canvas px @1024
PURPLE, BLUE, TEAL = "#CBACE7", "#BAD0F5", "#7EDFD7"
# (x, y, width, height, corner radius, colour) in SVG units.
SHAPES = [
    (0, 49, 81, 257, 40.5, PURPLE),
    (114, 0, 81, 180, 40.5, BLUE),
    (114, 193, 78, 78, 39, TEAL),
]

MASTER = ROOT / "assets/branding/icon-App-1024x1024@1x.png"
MACOS_SET = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_SET = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES = ROOT / "android/app/src/main/res"
STORE = ROOT / "store"
MACOS_SIZES = (16, 32, 64, 128, 256, 512, 1024)
LEGACY_DENSITIES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
LEGACY_CORNER = 0.225              # corner radius as a share of the size
PLAY_STORE_SIZE = 512
# Android adaptive icon: 108 dp canvas; only a 66 dp circle is always visible.
ADAPTIVE_CANVAS = 108
ADAPTIVE_SCALE = 0.19              # dp per SVG unit: a ~58 dp tall mark, inside the 66 dp safe circle
SUPERSAMPLE = 4

# Logo lockup (tool/brand_logo.py): the mark from the .icon's SVG layer beside
# the wordmark in assets/branding/source/wordmark.svg.
WORDMARK = ROOT / "assets/branding/source/wordmark.svg"
MARK_SVG = ICON / "Assets/Group 2087328553.svg"
LETTERS_ON_LIGHT = "#20211F"
LETTERS_ON_DARK = "#E7E7E7"
LOCKUP_GAP = 96                    # between mark and wordmark, wordmark units
PREVIEW_SIZE = 1024
LAUNCH_TILE_PX = 168               # iOS LaunchImage @1x; 2x/3x are multiples
ANDROID_LAUNCH_PX = 480
IOS_LAUNCH = ROOT / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
