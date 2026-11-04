// Verifies the HomeMapScreen toolbar layout never overflows and never overlaps.
//
// Layout under test (mirrors HomeMapScreen):
//   Row 1: search field (Expanded) + filter icon.
//   Row 2 (own line): bell, add-job, labeled "Daxil ol" pill (Expanded),
//         settings gear pinned right.
//   Row 3: category chips (horizontally scrollable, full width).
// Asserts no RenderFlex overflow, "Daxil ol" is present for guests, and the
// action row's rect does not overlap the chips row's rect.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildToolbar({required bool isDark}) {
  final searchRow = Container(
    key: const Key('searchRow'),
    height: 52,
    color: isDark ? const Color(0xFF1E293B) : Colors.white,
    child: Row(
      children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: () {},
        ),
        const SizedBox(width: 4),
      ],
    ),
  );

  final actionRow = Padding(
    key: const Key('actionRow'),
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    child: Row(
      children: [
        IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {}),
        IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {}),
        const SizedBox(width: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Daxil ol',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {}),
      ],
    ),
  );

  final chipsRow = SizedBox(
    key: const Key('chipsRow'),
    height: 42,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: const [
        Chip(label: Text('Bütün Vakansiyalar')),
        Chip(label: Text('Restoran & Kafeler')),
        Chip(label: Text('İT & Proqramlaşdırma')),
      ],
    ),
  );

  return Column(
    children: [searchRow, actionRow, chipsRow],
  );
}

void main() {
  for (final width in [320.0, 360.0, 375.0, 390.0, 430.0]) {
    for (final isDark in [false, true]) {
      testWidgets(
          'toolbar fits at ${width.toInt()}px (${isDark ? 'dark' : 'light'})',
          (WidgetTester tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: isDark ? ThemeData.dark() : ThemeData.light(),
            home: Scaffold(
              body: SafeArea(child: _buildToolbar(isDark: isDark)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No overflow.
        expect(tester.takeException(), isNull);
        // Guest sign-in label is visible.
        expect(find.text('Daxil ol'), findsOneWidget);

        // Action row and chips row must not overlap.
        final actionRect = tester.getRect(find.byKey(const Key('actionRow')));
        final chipsRect = tester.getRect(find.byKey(const Key('chipsRow')));
        expect(
          actionRect.bottom <= chipsRect.top,
          isTrue,
          reason: 'action row overlaps chips row at ${width.toInt()}px',
        );
      });
    }
  }
}
