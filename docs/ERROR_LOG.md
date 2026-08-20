# Amble — Error Log

Append-only. One entry per real gotcha (not every typo) — the point is to catch recurring platform quirks before they cost time twice, especially since Flutter/Dart is newer terrain than TS.

Format per entry:

```
## [YYYY-MM-DD] Short title
**Symptom:**
**Cause:**
**Fix:**
**Prevent next time:**
```

---

## [2026-08-20] hive_generator compatibility conflict

**Symptom:** `flutter pub add --dev hive_generator` fails version solving: `riverpod_generator >=3.0.0 depends on source_gen >=3.0.0 <5.0.0` while `hive_generator >=1.0.1 depends on source_gen ^1.0.0` (and `<1.0.1` predates null safety). Classic `hive`/`hive_flutter` + `hive_generator` cannot coexist with our pinned `riverpod_generator ^4.0.8` in one pubspec.
**Cause:** Dart resolves one `analyzer`/`source_gen` version for the whole pubspec's dev_dependencies. `hive_generator` is unmaintained and stuck on `source_gen ^1.0.0`. Switching to `hive_ce_generator` (the maintained fork) fixes the `source_gen` conflict, but introduces a second, narrower one: `riverpod_generator ^4.0.8` requires `analyzer ^13.0.0`, and no published `hive_ce_generator` version targets `analyzer ^13.x` — the package jumps `^12.0.0` (v1.11.2) straight to `^14.0.0` (v1.11.3), skipping 13 entirely. Downgrading `riverpod_generator` to match `analyzer ^12.0.0` (v4.0.4) cascades into needing an older `riverpod_annotation` (4.0.3), which in turn is incompatible with our pinned `flutter_riverpod ^3.4.2` — not a viable fix without touching Riverpod itself, which is out of scope.
**Fix:** Replaced `hive` / `hive_flutter` with `hive_ce ^2.16.0` / `hive_ce_flutter ^2.3.4` (drop-in API-compatible fork, same `@HiveType`/`@HiveField` annotations). Added `hive_ce_generator: 1.11.2` (dev) pinned exactly, plus a `dependency_overrides: analyzer: ^13.0.0` to bridge the one-version caret gap — `hive_ce_generator 1.11.2` declares `analyzer ^12.0.0` but analyzer's generator-facing API is stable across this adjacent bump, confirmed by a clean `flutter pub get`, `dart run build_runner build`, `flutter analyze`, and `flutter test` (all green). `build_runner` also needed a version compatible with the overridden analyzer range: left at `^2.16.0` since the override makes the resolved analyzer 13.3.0, which build_runner 2.16.0 already accepts (`>=13.3.0 <15.0.0`).
**Working version combo:** `hive_ce: ^2.16.0`, `hive_ce_flutter: ^2.3.4`, `hive_ce_generator: 1.11.2` (exact pin — do not loosen to `^1.11.2`, since `1.11.3` jumps to `analyzer ^14.0.0` and would reopen the gap), `build_runner: ^2.16.0`, `riverpod_generator: ^4.0.8`, `dependency_overrides: { analyzer: ^13.0.0 }`.
**Prevent next time:** Before bumping `riverpod_generator` or `hive_ce_generator` in the future, re-check both packages' declared `analyzer` ranges actually overlap before touching the override — this gap closes/reopens with every release of either package.
