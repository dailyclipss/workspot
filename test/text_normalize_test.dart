import 'package:flutter_test/flutter_test.dart';
import 'package:workspot/utils/text_normalize.dart';

void main() {
  group('normalizeAz', () {
    test('folds Azerbaijani letters', () {
      expect(normalizeAz('ə'), 'e');
      expect(normalizeAz('Ə'), 'e');
      expect(normalizeAz('ı'), 'i');
      expect(normalizeAz('İ'), 'i');
      expect(normalizeAz('ş'), 's');
      expect(normalizeAz('ç'), 'c');
      expect(normalizeAz('ğ'), 'g');
      expect(normalizeAz('ö'), 'o');
      expect(normalizeAz('ü'), 'u');
    });

    test('Narimanov matches Nərimanov', () {
      expect(normalizeAzLoose('Narimanov'), normalizeAzLoose('Nərimanov'));
      expect(normalizeAz('İçərişəhər'), 'iceriseher');
    });

    test('collapses separators and trims', () {
      expect(normalizeAz('  Restoran  &  Kafe / Bar '), 'restoran kafe bar');
      expect(normalizeAz('28 May'), '28 may');
    });

    test('null and empty', () {
      expect(normalizeAz(null), '');
      expect(normalizeAz(''), '');
    });

    test('containsWords is word based', () {
      expect(containsWords('nərimanov rayonu', 'nərimanov'), isTrue);
      expect(containsWords('narimanov rayonu', 'narimanov'), isTrue);
      expect(containsWords('xirdalan', 'xir'), isFalse);
    });
  });
}
