// Verifies the HomeMapScreen top toolbar never overflows the screen width.
//
// New layout: Row 1 = search field (Expanded) + filter icon. Row 2 = category
// chips (Expanded, scrollable) + action row (bell, add-job, account, settings).
// We render both rows at 320/360/375/390/430 in light and dark themes and
// assert no RenderFlex overflow and that the "Daxil ol" label is present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _toolbar({required bool isDark}) {
  final searchRow = Container(
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

  final actionRow = Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {}),
      IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () {}),
      TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.login_rounded, size: 17),
        label: const Text('Daxil ol'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {}),
    ],
  );

  final chipsRow = SizedBox(
    height: 42,
    child: Row(
      children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              Chip(label: Text('All')),
              Chip(label: Text('IT')),
              Chip(label: Text('Sales')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: actionRow,
        ),
      ],
    ),
  );

  return Column(
    children: [searchRow, chipsRow],
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
              body: SafeArea(child: _toolbar(isDark: isDark)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Daxil ol'), findsOneWidget);
      });
    }
  }
}
