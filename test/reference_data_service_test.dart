import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workspot/models/job_model.dart';
import 'package:workspot/services/app_language.dart';
import 'package:workspot/services/reference_data_service.dart';
import 'package:workspot/services/reference_fallback.dart';
import 'package:workspot/utils/category_icons.dart';
import 'package:workspot/widgets/reference_pickers.dart';
import 'package:flutter/material.dart';

Map<String, dynamic> _cat(int id) => {
      'id': id,
      'slug': 'c$id',
      'name_az': 'Kat $id',
      'name_ru': 'Кат $id',
      'name_en': 'Cat $id',
      'icon': 'work',
      'sort': id,
    };

Map<String, dynamic> _dist(int id) => {
      'id': id,
      'slug': 'd$id',
      'name_az': 'Rayon $id',
      'name_ru': 'Район $id',
      'name_en': 'District $id',
      'city': 'Bakı',
      'kind': 'rayon',
      'sort': id,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => appLang.changeLanguage('az'));

  group('fallback data', () {
    test('has 35 categories and 20 districts with unique ids and slugs', () {
      expect(fallbackCategories.length, 35);
      expect(fallbackDistricts.length, 20);
      expect(fallbackCategories.map((c) => c.id).toSet().length, 35);
      expect(fallbackCategories.map((c) => c.slug).toSet().length, 35);
      expect(fallbackDistricts.map((d) => d.id).toSet().length, 20);
      expect(fallbackCategories.last.slug, 'diger');
    });

    test('district kinds: 12 rayon, 5 area, 3 city', () {
      int n(String k) => fallbackDistricts.where((d) => d.kind == k).length;
      expect(n('rayon'), 12);
      expect(n('area'), 5);
      expect(n('city'), 3);
    });

    test('every name is filled in all languages', () {
      for (final c in fallbackCategories) {
        expect([c.nameAz, c.nameRu, c.nameEn].every((s) => s.isNotEmpty), isTrue);
      }
      for (final d in fallbackDistricts) {
        expect([d.nameAz, d.nameRu, d.nameEn].every((s) => s.isNotEmpty), isTrue);
      }
    });

    test('every category icon resolves to a non-default icon', () {
      for (final c in fallbackCategories) {
        expect(iconForCategory(c), isNot(Icons.work), reason: c.slug);
      }
      expect(iconForCategory(null), Icons.work);
    });
  });

  group('localization', () {
    test('picks name by language', () {
      final c = fallbackCategories.firstWhere((c) => c.slug == 'kassir');
      expect(c.localizedName('az'), 'Kassir');
      expect(c.localizedName('ru'), 'Кассир');
      expect(c.localizedName('en'), 'Cashier');
    });

    test('label follows appLang and never shows id or General', () {
      final svc = ReferenceDataService(fetcher: (_) async => []);
      final job = {'category_id': 12, 'category': 'x', 'district_id': 9};
      appLang.changeLanguage('en');
      expect(svc.categoryLabel(job), svc.categoryById(12)!.nameEn);
      appLang.changeLanguage('ru');
      expect(svc.districtLabel(job), svc.districtById(9)!.nameRu);

      expect(svc.categoryLabel({'category': 'General'}), '');
      expect(svc.categoryLabel({'category_id': null, 'category': ''}, fallback: '—'),
          '—');
      expect(svc.categoryLabel({'category': 'Naməlum sahə'}), 'Naməlum sahə');
    });

    test('legacy text resolves to localized name', () {
      final svc = ReferenceDataService(fetcher: (_) async => []);
      appLang.changeLanguage('en');
      expect(svc.categoryLabel({'category': 'Restoran & Kafe'}),
          'Restaurant & Cafe (waiter, service)');
      expect(svc.districtLabel({'district': 'Nərimanov'}), 'Narimanov');
    });
  });

  group('district matching', () {
    final svc = ReferenceDataService(fetcher: (_) async => []);

    test('Narimanov ≈ Nərimanov', () {
      expect(svc.matchDistrict('Narimanov')?.slug,
          svc.matchDistrict('Nərimanov')?.slug);
      expect(svc.matchDistrict('Nərimanov')?.nameAz, 'Nərimanov');
    });

    test('geocoder style strings', () {
      expect(svc.matchDistrict('Yasamal rayonu')?.nameAz, 'Yasamal');
      expect(svc.matchDistrict('Bakı'), isNull);
      expect(svc.matchDistrict(''), isNull);
      expect(svc.matchDistrict(null), isNull);
    });

    test('districtFromLocation gives a district in central Baku', () {
      expect(svc.districtFromLocation(40.4093, 49.8671), isNotNull);
      expect(svc.districtFromLocation(10, 10), isNull);
    });
  });

  group('category selection and filter', () {
    final svc = ReferenceDataService(fetcher: (_) async => []);
    final restoran = svc.categoryById(1)!;
    final it = fallbackCategories.firstWhere((c) => c.slug == 'it');
    final tikinti = fallbackCategories.firstWhere((c) => c.slug == 'tikinti');

    test('matches by id', () {
      expect(svc.categoryMatches({'category_id': 1}, restoran), isTrue);
      expect(svc.categoryMatches({'category_id': 1}, it), isFalse);
      expect(svc.categoryMatches({'category_id': '1'}, restoran), isTrue);
    });

    test('id wins over conflicting text', () {
      expect(
          svc.categoryMatches(
              {'category_id': it.id, 'category': 'Restoran & Kafe'}, restoran),
          isFalse);
    });

    test('text fallback when category_id is null', () {
      expect(svc.categoryMatches({'category': 'Restoran & Kafe'}, restoran),
          isTrue);
      expect(svc.categoryMatches({'category': 'İT'}, it), isTrue);
      expect(svc.categoryMatches({'category': 'Tikinti'}, tikinti), isTrue);
      expect(svc.categoryMatches({'category': 'Tikinti'}, it), isFalse);
    });

    test('short text "it" does not leak into other categories', () {
      final others = fallbackCategories.where((c) => c.slug != 'it');
      for (final c in others) {
        expect(svc.categoryMatches({'category': 'İT'}, c), isFalse,
            reason: c.slug);
      }
    });

    test('unknown or empty text matches nothing', () {
      expect(svc.categoryMatches({'category': ''}, restoran), isFalse);
      expect(svc.categoryMatches({}, restoran), isFalse);
    });

    test('filterCategories searches across languages and folds letters', () {
      expect(filterCategories(fallbackCategories, 'asp').map((c) => c.slug),
          contains('ashpaz-metbex'));
      expect(filterCategories(fallbackCategories, 'cashier').map((c) => c.slug),
          ['kassir']);
      expect(filterCategories(fallbackCategories, 'Кассир').length, 1);
      expect(filterCategories(fallbackCategories, '').length, 35);
      expect(filterCategories(fallbackCategories, 'zzzz'), isEmpty);
    });

    test('filterDistricts folds letters', () {
      expect(filterDistricts(fallbackDistricts, 'narimanov').single.slug,
          'narimanov');
    });
  });

  group('loading and cache', () {
    test('uses remote data and caches it', () async {
      var calls = 0;
      final svc = ReferenceDataService(fetcher: (table) async {
        calls++;
        return table == 'job_categories' ? [_cat(1), _cat(2)] : [_dist(1)];
      });
      await svc.load();
      expect(svc.categories.length, 2);
      expect(svc.districts.length, 1);
      expect(svc.usingRemoteData, isTrue);
      expect(calls, 2);

      final second = ReferenceDataService(fetcher: (_) async {
        calls++;
        return [];
      });
      await second.load();
      expect(second.categories.length, 2);
      expect(calls, 2, reason: 'fresh cache must not hit the network');
    });

    test('refetches after 24 hours', () async {
      var now = DateTime(2026, 1, 1);
      var calls = 0;
      Future<List<Map<String, dynamic>>> fetch(String table) async {
        calls++;
        return table == 'job_categories' ? [_cat(1)] : [_dist(1)];
      }

      final svc = ReferenceDataService(fetcher: fetch, clock: () => now);
      await svc.load();
      expect(calls, 2);
      now = now.add(const Duration(hours: 25));
      await svc.load();
      expect(calls, 4);
    });

    test('network error keeps fallback', () async {
      final svc = ReferenceDataService(fetcher: (_) async => throw Exception('x'));
      await svc.load();
      expect(svc.categories.length, 35);
      expect(svc.districts.length, 20);
      expect(svc.usingRemoteData, isFalse);
    });

    test('empty response keeps fallback', () async {
      final svc = ReferenceDataService(fetcher: (_) async => []);
      await svc.load();
      expect(svc.categories.length, 35);
      expect(svc.districts.length, 20);
    });

    test('stale cache is used when the network fails', () async {
      var now = DateTime(2026, 1, 1);
      final ok = ReferenceDataService(
          fetcher: (t) async => t == 'job_categories' ? [_cat(1)] : [_dist(1)],
          clock: () => now);
      await ok.load();
      now = now.add(const Duration(days: 3));
      final offline = ReferenceDataService(
          fetcher: (_) async => throw Exception('offline'), clock: () => now);
      await offline.load();
      expect(offline.categories.length, 1);
    });
  });

  group('JobModel', () {
    test('no General default; ids parsed', () {
      final empty = JobModel.fromJson({'id': '1'});
      expect(empty.category, '');
      expect(empty.categoryId, isNull);
      final withIds = JobModel.fromJson(
          {'id': '2', 'category_id': 3, 'district_id': '4', 'category': 'x'});
      expect(withIds.categoryId, 3);
      expect(withIds.districtId, 4);
    });
  });
}
