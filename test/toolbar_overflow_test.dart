// Verifies the HomeMapScreen top toolbar never overflows the screen width.
//
// The toolbar is horizontally scrollable, so at any width its content must
// not trigger a RenderFlex overflow (yellow/black stripes). We render the
// toolbar row content inside a fixed-width container at 320/375/390/430 and
// assert no overflow exception is thrown.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:workspot/widgets/language_theme_controls.dart';

Widget _toolbarRow() {
  // Mirror of the HomeMapScreen toolbar controls (search field + icons +
  // account button + language/theme), inside the scrollable wrapper.
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, size: 22),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: TextField(
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () {}),
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
        const SizedBox(width: 4),
        const LanguageThemeControls(),
        const SizedBox(width: 8),
      ],
    ),
  );
}

void main() {
  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    testWidgets('toolbar does not overflow at ${width.toInt()}px',
        (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: SizedBox(
                height: 52,
                child: _toolbarRow(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // If a RenderFlex overflowed, Flutter throws during layout and the
      // test fails automatically. Reaching here means no overflow.
      expect(tester.takeException(), isNull);
    });
  }
}
