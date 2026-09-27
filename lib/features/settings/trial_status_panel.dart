import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_trial_gate.dart';
import '../../shared/providers/purchases_providers.dart';
import '../../shared/providers/trial_providers.dart';
import 'settings_panel.dart';

/// The Settings screen's first section — plain info, not a link row
/// (requested directly: "first section... that is not links but just...
/// 21 days left / Get Rios now > trigger paywall"). Shows the trial
/// countdown and a direct paywall trigger; disappears entirely once
/// `panta_pro` is active — a paying user has nothing to upgrade toward
/// here. Reuses [presentPaywallForTrialExpired] (`app_trial_gate.dart`),
/// the same paywall-presentation path every trial-expired create attempt
/// already goes through, rather than hand-rolling a second one.
class TrialStatusPanel extends ConsumerStatefulWidget {
  const TrialStatusPanel({super.key});

  @override
  ConsumerState<TrialStatusPanel> createState() => _TrialStatusPanelState();
}

class _TrialStatusPanelState extends ConsumerState<TrialStatusPanel> {
  bool _busy = false;

  Future<void> _presentPaywall() async {
    setState(() => _busy = true);
    try {
      await presentPaywallForTrialExpired(context, ref);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isPro = ref.watch(isPantaProProvider);
    if (isPro) return const SizedBox.shrink();

    final daysRemaining = ref.watch(daysRemainingInTrialProvider);
    final isInTrial = ref.watch(isInTrialPeriodProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacingMd),
      child: SettingsPanel(
        theme: theme,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isInTrial
                  ? '$daysRemaining day${daysRemaining == 1 ? '' : 's'} left'
                  : 'Your free trial has ended',
              style: theme.textBody.copyWith(
                color: theme.colorTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacingSm),
            AppButton(
              label: 'Get Rios now',
              onPressed: _busy ? null : _presentPaywall,
              isLoading: _busy,
            ),
          ],
        ),
      ),
    );
  }
}
