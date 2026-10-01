import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../shared/providers/onboarding_profile_catalog.dart';
import '../../shared/services/onboarding_materializer.dart';

/// The bundled catalog id of the made-up starter person.
const demoProfileId = 'demo';

/// Developer-only: adds the Demo profile (labels, presets, patterns, zones,
/// Things and a full day) on top of whatever is already there — requested
/// directly: "we need one starter profile, Demo."
class DemoProfileButton extends ConsumerStatefulWidget {
  const DemoProfileButton({super.key, required this.theme});

  final AmbleTheme theme;

  @override
  ConsumerState<DemoProfileButton> createState() => _DemoProfileButtonState();
}

class _DemoProfileButtonState extends ConsumerState<DemoProfileButton> {
  bool _busy = false;
  String? _status;

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final catalog = await ref.read(onboardingProfileCatalogProvider.future);
      final demo = catalog.singleWhere((p) => p.id == demoProfileId);
      await materializeOnboardingProfile(ref, demo);
      if (mounted) setState(() => _status = 'Demo profile added.');
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Could not load the Demo profile: $error');
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          label: 'Load Demo profile',
          variant: AppButtonVariant.secondary,
          isLoading: _busy,
          onPressed: _busy ? null : _load,
        ),
        if (_status case final status?) ...[
          SizedBox(height: theme.spacingSm),
          Text(
            status,
            style: theme.textBody.copyWith(color: theme.colorTextPrimary),
          ),
        ],
      ],
    );
  }
}
