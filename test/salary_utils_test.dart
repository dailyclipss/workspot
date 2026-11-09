import 'package:flutter_test/flutter_test.dart';
import 'package:workspot/utils/salary_utils.dart';

void main() {
  group('parseSalary', () {
    test('range without spaces', () {
      expect(parseSalary({'salary': '600-2000'}),
          const SalaryRange(min: 600, max: 2000));
    });

    test('range with spaces and currency', () {
      expect(parseSalary({'salary': '600 - 900 AZN'}),
          const SalaryRange(min: 600, max: 900));
    });

    test('single number', () {
      final range = parseSalary({'salary': '600'});
      expect(range, const SalaryRange(min: 600));
      expect(formatSalaryText(range), '600 AZN');
    });

    test('empty and null', () {
      expect(parseSalary({'salary': ''}).isEmpty, isTrue);
      expect(parseSalary({'salary': null}).isEmpty, isTrue);
      expect(parseSalary({}).isEmpty, isTrue);
      expect(parseSalary({'salary': '0', 'salary_amount': 0}).isEmpty, isTrue);
    });

    test('min greater than max is swapped', () {
      expect(parseSalary({'salary_min': 900, 'salary_max': 600}),
          const SalaryRange(min: 600, max: 900));
      expect(parseSalary({'salary': '900-600'}),
          const SalaryRange(min: 600, max: 900));
    });

    test('only max', () {
      final range = parseSalary({'salary_max': 1500});
      expect(range.lower, 1500);
      expect(range.isRange, isFalse);
      expect(formatSalaryText(range), '1500 AZN');
    });

    test('letters mixed in', () {
      expect(parseSalary({'salary': 'təxminən 600 AZN'}),
          const SalaryRange(min: 600));
      expect(parseSalary({'salary': 'abc'}).isEmpty, isTrue);
    });

    test('columns win over text, text over amount', () {
      expect(
          parseSalary({
            'salary_min': 700,
            'salary_max': 800,
            'salary': '1-2',
            'salary_amount': 5
          }),
          const SalaryRange(min: 700, max: 800));
      expect(parseSalary({'salary_amount': 450}), const SalaryRange(min: 450));
    });
  });

  group('negotiable', () {
    const label = 'Razılaşma ilə';
    test('null, 0 and negotiable type show negotiable, never 0', () {
      for (final job in <Map<String, dynamic>>[
        {'salary_amount': null},
        {'salary_amount': 0, 'salary': '0'},
        {'salary': 'Razılaşma ilə'},
        {'salary_type': 'negotiable', 'salary': '600 AZN', 'salary_min': 600},
      ]) {
        final r = parseSalary(job);
        expect(r.isEmpty, isTrue, reason: '$job');
        expect(formatSalaryDisplay(r), label);
        expect(formatSalaryCompact(r), label);
        expect(formatSalaryDisplay(r), isNot(contains('0 ')));
      }
    });

    test('custom empty label', () {
      expect(formatSalaryDisplay(SalaryRange.empty, empty: 'Negotiable'), 'Negotiable');
      expect(formatSalaryCompact(SalaryRange.empty, empty: 'Negotiable'), 'Negotiable');
    });
  });

  group('format and payload', () {
    test('range payload', () {
      final payload = salaryPayload(const SalaryRange(min: 600, max: 2000));
      expect(payload['salary'], '600 - 2000 AZN');
      expect(payload['salary_min'], 600);
      expect(payload['salary_max'], 2000);
      expect(payload['salary_amount'], 600);
    });

    test('only max payload uses max as amount', () {
      final payload = salaryPayload(const SalaryRange(max: 900));
      expect(payload['salary_amount'], 900);
      expect(payload['salary'], '900 AZN');
    });

    test('empty payload', () {
      final payload = salaryPayload(SalaryRange.empty);
      expect(payload['salary'], 'Razılaşma ilə');
      expect(payload['salary_min'], isNull);
      expect(payload['salary_max'], isNull);
      expect(payload['salary_amount'], isNull);
      expect(payload['salary_type'], 'negotiable');
    });

    test('real salary can reset negotiable type', () {
      final p = salaryPayload(const SalaryRange(min: 500), clearNegotiable: true);
      expect(p.containsKey('salary_type'), isTrue);
      expect(p['salary_type'], isNull);
      expect(salaryPayload(const SalaryRange(min: 500)).containsKey('salary_type'), isFalse);
    });

    test('display and compact', () {
      expect(formatSalaryDisplay(const SalaryRange(min: 600, max: 2000)),
          '600 - 2000 ₼');
      expect(formatSalaryCompact(const SalaryRange(min: 600, max: 2000)),
          '600-2000 ₼');
    });
  });

  group('validation and filter', () {
    test('validation', () {
      String? v(String a, String b) => validateSalaryInputs(a, b,
          invalidMessage: 'bad', orderMessage: 'order');
      expect(v('', ''), isNull);
      expect(v('600', ''), isNull);
      expect(v('', '900'), isNull);
      expect(v('600', '900'), isNull);
      expect(v('900', '600'), 'order');
      expect(v('abc', ''), 'bad');
    });

    test('overlap', () {
      const r = SalaryRange(min: 600, max: 2000);
      expect(salaryOverlaps(r, filterMin: 0, filterMax: 500), isFalse);
      expect(salaryOverlaps(r, filterMin: 1500, filterMax: 3000), isTrue);
      expect(salaryOverlaps(r, filterMin: 2100), isFalse);
      expect(salaryOverlaps(SalaryRange.empty, filterMin: 0), isTrue);
      expect(salaryOverlaps(SalaryRange.empty, filterMin: 100), isFalse);
    });
  });
}
