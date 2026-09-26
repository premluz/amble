import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_modal_route.dart';
import 'settings_detail_scaffold.dart';
import 'settings_panel.dart';

Future<void> showAboutSettingsScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    directionalPageRoute((context) => const AboutSettingsScreen()),
  );
}

class AboutSettingsScreen extends StatefulWidget {
  const AboutSettingsScreen({super.key});

  @override
  State<AboutSettingsScreen> createState() => _AboutSettingsScreenState();
}

class _AboutSettingsScreenState extends State<AboutSettingsScreen> {
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return SettingsDetailScaffold(
      title: 'About',
      body: SettingsPanel(
        theme: theme,
        child: Text(
          _appVersion == null ? 'Amble' : 'Amble $_appVersion',
          // textBodyMono, not textBody — this line's whole reason for
          // being is the VERSION number ("version numbers... → stay
          // monospace" per the dual-font policy). The "Amble" wordmark
          // shares the line rather than warranting a Text.rich split for
          // one low-traffic About-screen row.
          style: theme.textBodyMono.copyWith(color: theme.colorTextSecondary),
        ),
      ),
    );
  }
}
