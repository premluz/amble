import 'package:flutter/material.dart';

abstract final class AppViewTransitionMotion {
  static Map<String, Offset> sample({
    required bool slide,
    required bool forward,
    required double progress,
    required Map<String, double> sourceWeights,
    required Map<String, Offset> sourceTranslations,
    required String? activeViewId,
  }) {
    if (!slide) return const {};
    final exit = Offset(forward ? -1 : 1, 0);
    final translations = <String, Offset>{};
    for (final id in sourceWeights.keys) {
      translations[id] = Offset.lerp(
        sourceTranslations[id] ?? Offset.zero,
        exit,
        progress,
      )!;
    }
    final id = activeViewId;
    if (id != null) {
      translations[id] = Offset((forward ? 1 : -1) * (1 - progress), 0);
    }
    return translations;
  }

  static Offset translation({
    required String id,
    required String? activeViewId,
    required bool forward,
    required double progress,
    required Map<String, Offset> sourceTranslations,
  }) {
    if (id == activeViewId) {
      return Offset((forward ? 1 : -1) * (1 - progress), 0);
    }
    return Offset.lerp(
      sourceTranslations[id] ?? Offset.zero,
      Offset(forward ? -1 : 1, 0),
      progress,
    )!;
  }
}
