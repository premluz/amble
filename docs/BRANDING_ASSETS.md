# Branding assets: where they live and what to update

One page that answers "I changed the logo / icon: what else do I touch?".
Keep it in step with `tool/brand_assets.py`, which generates the app icons.

## Status (2026-10-12)

| Part | State |
|---|---|
| **App icon** (macOS, iOS, Android) | **Done.** New icon from `assets/branding/AppIcon.icon`; everything derived by `tool/brand_assets.py` and Xcode. |
| **Logo lockups** (`Logo_on_light/dark.svg|png`, splash, onboarding) | **Provisional.** Assembled by `tool/brand_logo.py` from the icon's mark + the stroked wordmark in `assets/branding/source/wordmark.svg` (copied from `~/Downloads/logorios.svg`), since no designed lockup was supplied. Replace when one exists. |
| **Native launch screens** (iOS `LaunchImage`, Android `launch_image`) | **Provisional.** The new app-icon tile (dark rounded square with the mark) on the white launch background. |
| Web, Windows, Linux icons, `promo/`, Widgetbook | **Not updated.** See "Not covered". |

## Sources of truth (edit these, nothing else)

| What | File | Edited with |
|---|---|---|
| App icon (all platforms) | `assets/branding/AppIcon.icon` | Icon Composer (Xcode 26+). A layered bundle: a dark fill plus the mark's SVG layer (`Assets/*.svg`). |
| Wordmark (letters) | `assets/branding/source/wordmark.svg` | A vector editor. Stroked letters in `#1a1a1a`; the script recolours them. Not bundled into the app (a subfolder of a non-recursive asset dir). |
| Logo lockups, in-app | `assets/branding/Logo_on_light.svg`, `Logo_on_dark.svg` (+ `.png` previews) | **Generated** by `tool/brand_logo.py` from the mark and the wordmark above. Dark letters (`#20211F`) for light surfaces, light (`#E7E7E7`) for dark. |
| Brand rules (colour, mark, wordmark, voice) | `docs/BRAND.md` | By hand. |

`Mac Icon/Untitled.icon` at the repo root is the original drop of the icon.
`assets/branding/AppIcon.icon` is the copy the projects use; edit that one, and
delete `Mac Icon/` when convenient.

## Changing the app icon

1. Edit `assets/branding/AppIcon.icon` in Icon Composer.
2. If the layout, colours or shapes changed, update the matching constants at
   the top of `tool/brand_spec.py` (they repeat the `.icon`'s fill, scale and
   shapes, because Icon Composer only exports masked renders, not the flat
   ones the stores and Android need).
3. `python3 tool/brand_assets.py`, then `python3 tool/brand_assets.py --verify`.
   Needs Xcode 26+ and Pillow (`pip3 install pillow`).
4. Look at `store/appstore-1024.png` and at an Android build (adaptive icon in
   the launcher, including the themed/monochrome one on Android 13+).
5. `flutter build macos --debug`, `flutter build ios --debug --no-codesign`,
   `flutter build apk --debug`.

## What produces what

| Platform | Files | Made by | Notes |
|---|---|---|---|
| macOS (26+) | `AppIcon.icon` compiled into `Assets.car` | **Xcode** (referenced in `macos/Runner.xcodeproj`) | Liquid Glass icon. Takes precedence over the PNG set below. |
| macOS (older Xcode) | `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{16..1024}.png` | `brand_assets.py` (Icon Composer `ictool`, masked renders) | Only used if the `.icon` is not compiled (Xcode before 26). Keep regenerated. |
| iOS (26+) | `AppIcon.icon` compiled into `Assets.car` | **Xcode** (referenced in `ios/Runner.xcodeproj`) | Also builds light/dark/tinted renditions. |
| iOS (older) | `AppIcon60x60@2x.png` etc. inside the built app | **Xcode**, from the `.icon` | Deployment target is iOS 15, so these exist. |
| iOS fallback set | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png` | `brand_assets.py` (flat, opaque) | Used only if the `.icon` is not compiled. The 1024 has no alpha, as the App Store requires. |
| App Store listing | `store/appstore-1024.png` | `brand_assets.py` | 1024, opaque, full-bleed square. Upload as the marketing icon. |
| Android 8+ adaptive | `res/mipmap-anydpi-v26/ic_launcher.xml`, `res/drawable/ic_launcher_foreground.xml`, `ic_launcher_monochrome.xml`, `res/values/ic_launcher_background.xml` | `brand_assets.py` | Foreground is the mark as vectors (about 58 dp tall, inside the 66 dp safe circle). Background is the icon's dark fill. Monochrome is the themed icon (Android 13+). |
| Android 7 (minSdk 24) | `res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` | `brand_assets.py` | Rounded-square legacy icon. |
| Google Play listing | `store/playstore-512.png` | `brand_assets.py` | 512, full-bleed. Google applies the mask. |
| iOS launch screen | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{,-dark}{,@2x,@3x}.png` | `brand_assets.py` (`brand_logo.py`) | The icon tile, 168 / 336 / 504 px, same image for light and dark (the launch background is white in both). |
| Android launch screen | `res/drawable/launch_image.png`, `res/drawable-night/launch_image.png` | `brand_assets.py` (`brand_logo.py`) | The icon tile, 480 px. |
| In-app logo | `assets/branding/Logo_on_light.svg`, `Logo_on_dark.svg` and `.png` previews | `brand_assets.py` (`brand_logo.py`) | Provisional lockups; see Status. |
| Flat master | `assets/branding/icon-App-1024x1024@1x.png` | `brand_assets.py` | The source of the flat outputs above. It is also bundled into the app. |

Android resources are all under `android/app/src/main/`; `AndroidManifest.xml`
points at `@mipmap/ic_launcher` and needs no change.

## Where the logo shows up in the app

| Where | Code | Asset |
|---|---|---|
| First-launch splash and onboarding carousel | `SplashLogo` in `lib/features/splash/splash_carousel_screen.dart` (also used by `splash_screen.dart`) | `assets/branding/Logo_on_dark.svg` or `Logo_on_light.svg`, by brightness. Sized by width (`spacingXl * 4`; the lockup's viewBox is tight around the artwork). Covered by `test/features/splash/splash_screen_test.dart`, which names both files. |
| Settings › About | `lib/features/settings/about_settings_screen.dart` | Text only ("Amble" plus version). No logo. |
| iOS cold-start screen (the loader) | `ios/Runner/Base.lproj/LaunchScreen.storyboard` | `LaunchImage*.png` (168 pt) on `LaunchBackground.colorset` |
| Android cold-start screen | `res/drawable/launch_background.xml`, `res/drawable-v21/launch_background.xml` | `res/drawable/launch_image.png`, `res/drawable-night/launch_image.png` (480 px) on the `launch_background` colour (`values/colors.xml`) |

`assets/branding/` is declared in `pubspec.yaml` (not recursively), so the
`AppIcon.icon` folder inside it is not bundled into the app.

## Not covered by `brand_assets.py` (still the old icon)

- **Web:** `web/favicon.png`, `web/icons/Icon-{192,512}.png`, `Icon-maskable-*.png`; `web/manifest.json` names them.
- **Windows:** `windows/runner/resources/app_icon.ico`.
- **Linux:** none in the repo.
- **`promo/`** and **Widgetbook** carry their own copies of brand images.

## When a designed logo lockup arrives

1. Replace `assets/branding/Logo_on_light.svg` and `Logo_on_dark.svg` with the real files (and stop `brand_logo.write_lockups` from overwriting them: remove that call from `generate()`). Keep the file names, or update `SplashLogo` and `splash_screen_test.dart` together.
2. Check the viewBox is tight around the artwork: `SplashLogo` sizes by width (`spacingXl * 4`).
3. If the launch screens should show the lockup instead of the icon tile, change `write_launch_images` in `tool/brand_logo.py` (and the storyboard's content mode if the aspect changes).
4. Update `docs/BRAND.md` and the Status table above.
5. Run `flutter test test/features/splash` and look at the splash in light and dark, and a cold start on a device.

## Gotchas

- Icon Composer exports (`ictool`) are masked with rounded corners and an edge highlight, so they are never used for App Store or Play files. Those come from the flat render.
- The `.icon` wins over `AppIcon.appiconset` whenever Xcode 26+ builds, so editing the PNGs alone changes nothing on current Xcode.
- Built iOS PNGs are Apple-optimised and unreadable by most image libraries; convert with `sips -s format png` first.
- The Android mark must stay inside the central 66 dp of the 108 dp canvas, or some launcher masks will crop it.
- A built app shows the old launch image until it is reinstalled: iOS caches launch screens, so delete the app (and restart the phone if it still shows) before judging the loader.
