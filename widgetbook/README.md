# Amble Widgetbook

Widgetbook is the interactive gallery for Amble's real shared widgets. Stories
import the app's widgets and theme through the local `amble` package; they are
not parallel implementations. Use the [component guide](../docs/COMPONENT_GUIDE.md)
to choose a component and the [design system contract](../docs/DESIGN_SYSTEM.md)
for settled usage and visual rules.

## Run the gallery

From this directory:

```sh
flutter run -t lib/main.dart
```

Choose a Flutter device when prompted. In Widgetbook, select a story from the
left navigation. Where available, use the right-side controls to change button
variant and size; use the theme and text-scale add-ons to inspect light/dark
appearance and larger text.

## Find examples

- **Selection primitives** — buttons, tabs, connected choices, and chip sizes.
- **Navigation** — top and bottom navigation, section navigation, date
  accordion, and sheet headers/handles.
- **Feedback** — task states, press response, surfaces, motion, context menus,
  and undo toast.
- **Voice** — waveform states.

The gallery is selective: a component without a story is not thereby free of a
usage contract. Check `docs/DESIGN_SYSTEM.md` and the component's source before
changing behavior. Add or extend a story when a reusable visual/state needs to
be reviewed interactively; keep stories built from production widgets and
theme tokens.
