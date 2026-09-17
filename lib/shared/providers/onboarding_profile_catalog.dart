import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/onboarding_profile.dart';

part 'onboarding_profile_catalog.g.dart';

/// Path to the bundled Profile catalog — versioned with app releases, not
/// fetched remotely, per this app's local-only architecture. See
/// `OnboardingProfile`'s own doc comment for why this is plain JSON, not
/// Hive data.
const onboardingProfileCatalogAssetPath = 'assets/onboarding/profiles.json';

/// Parses [onboardingProfileCatalogAssetPath] into the list of
/// [OnboardingProfile]s the quiz scores against and the browse-all-profiles
/// screen lists. `keepAlive: true` — this is fixed, bundled content read
/// once per app session, not screen-scoped state; re-parsing it on every
/// screen visit would be wasted work for data that can never change
/// without a new app release.
@Riverpod(keepAlive: true)
Future<List<OnboardingProfile>> onboardingProfileCatalog(Ref ref) async {
  final raw = await rootBundle.loadString(onboardingProfileCatalogAssetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final profilesJson = decoded['profiles'];
  if (profilesJson is! List) {
    throw const FormatException(
      'onboarding profile catalog: missing "profiles" array',
    );
  }
  return profilesJson
      .map((p) => OnboardingProfile.fromJson(p as Map<String, dynamic>))
      .toList();
}
