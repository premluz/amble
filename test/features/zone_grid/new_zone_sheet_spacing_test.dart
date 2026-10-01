import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/component_tokens.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_chip_strip.dart';
import 'package:amble/core/widgets/app_segmented_time_field.dart';
import 'package:amble/core/widgets/app_sheet_header.dart';
import 'package:amble/core/widgets/app_text_field.dart';
import 'package:amble/features/zone_grid/new_zone_sheet.dart';
import 'package:amble/shared/models/zone_facet.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';

import '../../support/memory_zone_repositories.dart';

/// Requested directly: the add-zone sheet's spacing aligns with the
/// add-task sheet's (`TaskSheetFields`) — header, name, chips, next row.
void main() {
  testWidgets('add-zone sheet spacing matches the add-task sheet', (
    tester,
  ) async {
    final facets = MemoryZoneFacetRepository();
    await facets.save(ZoneFacet.create('Deep work'));
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          zoneRepositoryProvider.overrideWithValue(MemoryZoneRepository()),
          zoneFacetRepositoryProvider.overrideWithValue(facets),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                NewZoneSheet(
                  target: NewZoneTarget(
                    day: DateTime(2026, 9, 30),
                    startMinutes: 9 * 60,
                    endMinutes: 10 * 60,
                  ),
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final theme = AmbleTheme.light;
    final header = tester.getRect(find.byType(AppSheetHeader));
    final name = tester.getRect(find.byType(AppTextField));
    final chips = tester.getRect(find.byType(AppChipStrip<ZoneFacet>));
    final times = tester.getRect(find.byType(AppSegmentedTimeField).first);

    expect(name.top - header.bottom, SheetTokens.headerToFieldGap(theme));
    expect(chips.top - name.bottom, theme.spacingMd);
    expect(times.top - chips.bottom, theme.spacingSm);
    expect(header.left, theme.spacingLg);
    expect(name.left, theme.spacingLg);
  });
}
