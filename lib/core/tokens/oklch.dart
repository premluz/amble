import 'dart:math' as math;
import 'dart:ui';

/// Converts an OKLCH color to a Flutter [Color] (sRGB, alpha = 1.0).
///
/// Pipeline: OKLCH → OKLab → linear sRGB → gamma-corrected sRGB.
/// OKLCH/OKLab are perceptually uniform — equal steps in [lightness],
/// [chroma], or [hueDegrees] look equal, which raw hex/RGB doesn't
/// guarantee. Not `const`-evaluable (cube roots, matrix math), so callers
/// must use `static final`, not `static const`.
///
/// - [lightness]: 0.0 (black) to 1.0 (white)
/// - [chroma]: 0.0 (gray) upward; ~0.0–0.4 covers the sRGB gamut
/// - [hueDegrees]: 0–360
///
/// Reference: Björn Ottosson, "A perceptual color space for image
/// processing" (https://bottosson.github.io/posts/oklab/).
Color oklch(double lightness, double chroma, double hueDegrees) {
  final hueRadians = hueDegrees * math.pi / 180.0;
  final a = chroma * math.cos(hueRadians);
  final b = chroma * math.sin(hueRadians);

  // OKLab -> LMS (nonlinear)
  final l_ = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = lightness - 0.0894841775 * a - 1.2914855480 * b;

  final l = l_ * l_ * l_;
  final m = m_ * m_ * m_;
  final s = s_ * s_ * s_;

  // LMS -> linear sRGB
  final rLinear = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final gLinear = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final bLinear = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;

  return Color.fromARGB(
    255,
    _toSrgbByte(rLinear),
    _toSrgbByte(gLinear),
    _toSrgbByte(bLinear),
  );
}

/// Gamma-corrects a linear sRGB channel and quantizes to a clamped byte.
int _toSrgbByte(double linear) {
  final clampedLinear = linear.clamp(0.0, 1.0);
  final gammaCorrected = clampedLinear <= 0.0031308
      ? clampedLinear * 12.92
      : 1.055 * math.pow(clampedLinear, 1.0 / 2.4) - 0.055;
  return (gammaCorrected.clamp(0.0, 1.0) * 255.0).round();
}
