# Amble — Architecture

Living document. Update as real folder structure and file names solidify — this is the starting reference, not a frozen spec.

## Layered architecture

Strict one-directional dependency. No layer reaches two levels down.

```
UI (screens/widgets)
   ↓ reads/writes via
State (Riverpod providers/notifiers)
   ↓ calls
Repository (interface only, e.g. TaskRepository)
   ↓ implemented by
Data source (HiveTaskRepository today → SupabaseTaskRepository later)
```

The repository pattern is the single most important architectural decision in this project. Every feature talks to `TaskRepository` / `EventRepository` interfaces, never to Hive directly.

## Folder structure (target shape)

```
lib/
├── main.dart
├── app/              # app shell, routing, top-level theme wiring
├── core/              # tokens, adaptive widget layer, shared utils
├── features/
│   ├── timeline/      # the core day view
│   ├── inbox/         # unscheduled capture
│   ├── task_detail/   # create/edit, completion, reschedule
│   └── settings/      # export/import, notification prefs
└── shared/            # models, repository interfaces + implementations, providers
    ├── models/
    ├── repositories/
    └── providers/      # Riverpod providers/notifiers over repositories — app-level
                         # state (e.g. task CRUD), not screen-specific, so it lives
                         # here rather than under features/
```

Don't scaffold all of this manually ahead of need — create folders as features are actually built, per the work-order sequence.

## Design system: three-tier token architecture

- **Tier 1 — Primitives**: raw values, no semantic meaning. Color ramps, spacing scale, radii, type scale, motion durations/curves. Plain Dart `const` classes, no Flutter dependency — **except color**, see below.

  **Color primitives are OKLCH-defined, not `const`.** Colors are authored as OKLCH (L, C, H) triples for perceptual uniformity — equal steps in lightness/chroma/hue actually look equal, which plain hex/RGB doesn't guarantee (this is what caught the clay/ochre category-color distinguishability issue). Flutter's `Color` class has no native OKLCH support, so a small pure-Dart OKLCH→sRGB conversion (OKLCH → OKLab → linear sRGB → gamma-corrected sRGB) runs at the boundary. That conversion involves cube roots and matrix math Dart can't evaluate as `const`, so color primitives are `static final`, computed once at app init, not `const`. Every other Tier 1 category (spacing, radii, type, motion) stays `const` as originally specified.

- **Tier 2 — Semantic tokens**: meaning-bound references to Tier 1 (`colorSurfaceTimeline`, `colorTaskCompleted`, `spacingBlockGap`, `radiusTaskPill`). This is the layer widgets actually consume. Task-block colors are semantic categories, not literal hex values.
- **Tier 3 — Component tokens**: rare, per-component overrides where a component genuinely deviates from the semantic default. Kept deliberately small.

Implemented via Flutter's `ThemeExtension` mechanism — theme-aware (light/dark for free), testable independently of widgets.

## Adaptive widget layer

A thin layer of shared components (`AppButton`, `AppSheet`, `AppSwitch`, etc.) sitting on top of the token system, internally branching Cupertino vs. Material where needed. Screens never import platform widgets directly — see design principle 4 in the constitution.

## The capsule timeline block (signature component)

The rounded-capsule task blocks with icon badges overlapping the block boundary are the visual signature of the reference UI and the hardest piece to get right — not a standard widget, needs `ClipPath`/`CustomPainter` or carefully stacked `Container`s + `Positioned` icon badges. Budget real iteration time here; this is a design-taste problem as much as a code problem. Treat the reference as something to riff from, not a pixel target, if this ever moves toward public release.

## Data model reminders

See `CONSTITUTION.md` for the non-negotiables (UUIDs, status enum, `completedAt`, `originalScheduledAt`, `schemaVersion`). Models live in `shared/models/`, repository interfaces in `shared/repositories/`.

## Known open item

`hive_generator` compatibility conflict — resolution pending (likely `hive_ce` as the fix, pending confirmation of the actual error). Resolve before building out the Task/Event models, since it affects how typed adapters get generated.
