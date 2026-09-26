import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SheetKeyboardFrame {
  const SheetKeyboardFrame({
    required this.inset,
    required this.fraction,
    required this.duration,
    required this.opening,
    this.available = true,
  });

  final double inset;
  final double fraction;
  final Duration duration;
  final bool opening;
  final bool available;

  static SheetKeyboardFrame decode(Object? value) => switch (value) {
    {'unavailable': true} => const SheetKeyboardFrame(
      inset: 0,
      fraction: 1,
      duration: Duration.zero,
      opening: false,
      available: false,
    ),
    {
      'inset': num inset,
      'fraction': num fraction,
      'durationMs': int milliseconds,
      'opening': bool opening,
    }
        when inset >= 0 &&
            fraction >= 0 &&
            fraction <= 1 &&
            milliseconds >= 0 =>
      SheetKeyboardFrame(
        inset: inset.toDouble(),
        fraction: fraction.toDouble(),
        duration: Duration(milliseconds: milliseconds),
        opening: opening,
      ),
    _ => throw FormatException(
      'Invalid Android keyboard animation frame',
      value,
    ),
  };
}

abstract final class SheetKeyboard {
  static const _channel = EventChannel('com.amble/keyboard_animation');
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static final Stream<SheetKeyboardFrame> frames = isAndroid
      ? _channel.receiveBroadcastStream().map(SheetKeyboardFrame.decode)
      : const Stream.empty();
}
