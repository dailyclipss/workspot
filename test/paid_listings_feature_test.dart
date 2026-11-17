import 'package:flutter_test/flutter_test.dart';
import 'package:workspot/config/feature_flags.dart';

void main() {
  group('paid listings feature flag', () {
    test('is enabled on web', () {
      expect(paidListingsEnabledForPlatform(true), isTrue);
    });

    test('is disabled on native platforms', () {
      expect(paidListingsEnabledForPlatform(false), isFalse);
    });
  });
}
