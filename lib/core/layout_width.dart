import 'package:flutter/widgets.dart';

import 'tokens/component_tokens.dart';

/// Whether the window is wide (desktop, web, iPad landscape): at least
/// [ShellLayoutTokens.sideNavMinWindowWidth]. The one definition of the
/// phone / wide split, used by the shell and by details that differ between
/// them.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= ShellLayoutTokens.sideNavMinWindowWidth;
