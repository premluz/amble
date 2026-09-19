import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_connected_buttons.dart';
import 'package:amble/core/widgets/app_option_switch_option.dart';
import 'package:amble/core/widgets/app_tab_switch.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

/// Amble's component gallery — requested directly to "keep consistency"
/// as the button/tab-switch/connected-buttons hierarchy grows. Renders the
/// REAL app widgets/theme (via the `amble` path dependency in this
/// package's own pubspec.yaml), never a reimplementation, so this gallery
/// can never silently drift from what actually ships.
///
/// **2026-09-19 — knobs, not a use-case-per-combination.** The first pass
/// had a separate `WidgetbookUseCase` per variant/shape/size combination
/// (11 for `AppButton` alone) — requested directly to fix instead: variant
/// and size are now live KNOBS (the right panel's dropdowns) on ONE use
/// case per component, matching how the existing theme addon already lets
/// light/dark be flipped live rather than needing a separate use case per
/// theme. Content-shape differences that a dropdown can't meaningfully
/// express (icon-only vs. label vs. both, loading, disabled) stay as
/// separate use cases, since those change WHAT is being shown, not a
/// parameter of the same thing.
void main() => runApp(const AmbleWidgetbookApp());

class AmbleWidgetbookApp extends StatelessWidget {
  const AmbleWidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: [
        WidgetbookFolder(
          name: 'Selection primitives',
          children: [
            WidgetbookComponent(
              name: 'AppButton',
              useCases: [
                WidgetbookUseCase(
                  name: 'Label',
                  builder: (context) => AppButton(
                    label: 'Get started',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Icon + label',
                  builder: (context) => AppButton(
                    icon: Icons.add_rounded,
                    label: 'Add task',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Icon only (circle)',
                  builder: (context) => AppButton(
                    icon: Icons.arrow_back_rounded,
                    shape: AppButtonShape.circle,
                    variant: context.variantKnob(),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Pill shape',
                  builder: (context) => AppButton(
                    label: 'Next',
                    shape: AppButtonShape.pill,
                    variant: context.variantKnob(),
                    size: context.sizeKnob(initial: AppButtonSize.lg),
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Loading',
                  builder: (context) => AppButton(
                    label: 'Saving…',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    isLoading: true,
                    onPressed: _noop,
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Disabled',
                  builder: (context) => AppButton(
                    label: 'Get started',
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                    onPressed: null,
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppTabSwitch',
              useCases: [
                WidgetbookUseCase(
                  name: 'Few options',
                  builder: (context) => _TabSwitchDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Many options (filter row)',
                  builder: (context) => _TabSwitchManyOptionsDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'AppConnectedButtons',
              useCases: [
                WidgetbookUseCase(
                  name: 'Two options',
                  builder: (context) => _ConnectedButtonsDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'Three options',
                  builder: (context) => _ConnectedButtonsThreeOptionsDemo(
                    variant: context.variantKnob(),
                    size: context.sizeKnob(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
      addons: [
        ThemeAddon<ThemeData>(
          themes: [
            WidgetbookTheme(
              name: 'Light',
              data: ThemeData(
                useMaterial3: true,
                extensions: [AmbleTheme.light],
              ),
            ),
            WidgetbookTheme(
              name: 'Dark',
              data: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                extensions: [AmbleTheme.dark],
              ),
            ),
          ],
          themeBuilder: (context, theme, child) => Theme(
            data: theme,
            child: child,
          ),
        ),
      ],
    );
  }
}

void _noop() {}

/// Shared knob helpers so every use case above gets the identical
/// variant/size dropdown, in the identical order, rather than each
/// reconstructing `context.knobs.list(...)` with slightly different labels.
extension _ButtonKnobs on BuildContext {
  AppButtonVariant variantKnob() => knobs.object.dropdown<AppButtonVariant>(
    label: 'Variant',
    options: AppButtonVariant.values,
    labelBuilder: (v) => v.name,
  );

  AppButtonSize sizeKnob({AppButtonSize initial = AppButtonSize.md}) =>
      knobs.object.dropdown<AppButtonSize>(
        label: 'Size',
        options: AppButtonSize.values,
        initialOption: initial,
        labelBuilder: (v) => v.name,
      );
}

/// Wraps a stateful demo around AppTabSwitch — a use case needs to show a
/// real, changeable selection, not a fixed prop, or tapping another option
/// in the gallery would visibly do nothing.
class _TabSwitchDemo extends StatefulWidget {
  const _TabSwitchDemo({required this.variant, required this.size});

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_TabSwitchDemo> createState() => _TabSwitchDemoState();
}

class _TabSwitchDemoState extends State<_TabSwitchDemo> {
  String _value = 'all';

  static const _options = [
    AppOptionSwitchOption(value: 'all', label: 'All'),
    AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
    AppOptionSwitchOption(value: 'stocks', label: 'Stocks'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppTabSwitch<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}

class _TabSwitchManyOptionsDemo extends StatefulWidget {
  const _TabSwitchManyOptionsDemo({required this.variant, required this.size});

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_TabSwitchManyOptionsDemo> createState() =>
      _TabSwitchManyOptionsDemoState();
}

class _TabSwitchManyOptionsDemoState
    extends State<_TabSwitchManyOptionsDemo> {
  String _value = 'all';

  static const _options = [
    AppOptionSwitchOption(value: 'all', label: 'All'),
    AppOptionSwitchOption(value: 'crypto', label: 'Crypto'),
    AppOptionSwitchOption(value: 'stocks', label: 'Stocks'),
    AppOptionSwitchOption(value: 'perps', label: 'Perps'),
    AppOptionSwitchOption(value: 'commodities', label: 'Commodities'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppTabSwitch<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}

class _ConnectedButtonsDemo extends StatefulWidget {
  const _ConnectedButtonsDemo({required this.variant, required this.size});

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_ConnectedButtonsDemo> createState() => _ConnectedButtonsDemoState();
}

class _ConnectedButtonsDemoState extends State<_ConnectedButtonsDemo> {
  String _value = 'money';

  static const _options = [
    AppOptionSwitchOption(value: 'money', label: 'Money'),
    AppOptionSwitchOption(value: 'investments', label: 'Investments'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppConnectedButtons<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}

class _ConnectedButtonsThreeOptionsDemo extends StatefulWidget {
  const _ConnectedButtonsThreeOptionsDemo({
    required this.variant,
    required this.size,
  });

  final AppButtonVariant variant;
  final AppButtonSize size;

  @override
  State<_ConnectedButtonsThreeOptionsDemo> createState() =>
      _ConnectedButtonsThreeOptionsDemoState();
}

class _ConnectedButtonsThreeOptionsDemoState
    extends State<_ConnectedButtonsThreeOptionsDemo> {
  String _value = 'day';

  static const _options = [
    AppOptionSwitchOption(value: 'day', label: 'Day'),
    AppOptionSwitchOption(value: 'week', label: 'Week'),
    AppOptionSwitchOption(value: 'month', label: 'Month'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: AppConnectedButtons<String>(
        options: _options,
        value: _value,
        variant: widget.variant,
        size: widget.size,
        onChanged: (value) => setState(() => _value = value),
      ),
    );
  }
}
