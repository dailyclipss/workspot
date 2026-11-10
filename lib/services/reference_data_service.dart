import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';
import '../models/district.dart';
import '../utils/text_normalize.dart';
import 'app_language.dart';
import 'reference_fallback.dart';

typedef ReferenceFetcher = Future<List<Map<String, dynamic>>> Function(
    String table);

/// Job categories and districts: Supabase tables with a 24h SharedPreferences
/// cache and a built-in fallback identical to the migration seed.
class ReferenceDataService extends ChangeNotifier {
  ReferenceDataService({ReferenceFetcher? fetcher, DateTime Function()? clock})
      : _fetcher = fetcher ?? _defaultFetcher,
        _clock = clock ?? DateTime.now {
    _index();
  }

  static final ReferenceDataService instance = ReferenceDataService();

  static const Duration cacheTtl = Duration(hours: 24);
  static const String _categoriesKey = 'ref_job_categories_v1';
  static const String _districtsKey = 'ref_districts_v1';
  static const String _timestampKey = 'ref_data_fetched_at_v1';

  final ReferenceFetcher _fetcher;
  final DateTime Function() _clock;

  List<JobCategory> _categories = fallbackCategories;
  List<District> _districts = fallbackDistricts;
  bool _fromRemote = false;
  Future<void>? _loading;

  final Map<int, JobCategory> _categoryById = {};
  final Map<int, District> _districtById = {};
  final Map<String, JobCategory> _categoryByName = {};
  final List<MapEntry<String, District>> _districtCandidates = [];

  List<JobCategory> get categories => _categories;
  List<District> get districts => _districts;
  bool get usingRemoteData => _fromRemote;

  static Future<List<Map<String, dynamic>>> _defaultFetcher(
      String table) async {
    final rows = await Supabase.instance.client
        .from(table)
        .select()
        .order('sort')
        .timeout(const Duration(seconds: 8));
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> load({bool force = false}) {
    return _loading ??= _load(force).whenComplete(() => _loading = null);
  }

  Future<void> _load(bool force) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    var fresh = false;
    if (prefs != null) {
      final cached = _readCache(prefs);
      if (cached != null) {
        _apply(cached.$1, cached.$2, remote: true);
        final ts = DateTime.fromMillisecondsSinceEpoch(
            prefs.getInt(_timestampKey) ?? 0);
        fresh = _clock().difference(ts) < cacheTtl;
      }
    }
    if (fresh && !force) return;

    try {
      final catRows = await _fetcher('job_categories');
      final distRows = await _fetcher('districts');
      final cats = catRows.map(JobCategory.fromJson).toList();
      final dists = distRows.map(District.fromJson).toList();
      if (cats.isEmpty || dists.isEmpty) return;
      cats.sort((a, b) => a.sort.compareTo(b.sort));
      dists.sort((a, b) => a.sort.compareTo(b.sort));
      _apply(cats, dists, remote: true);
      if (prefs != null) {
        await prefs.setString(
            _categoriesKey, jsonEncode(cats.map((e) => e.toJson()).toList()));
        await prefs.setString(
            _districtsKey, jsonEncode(dists.map((e) => e.toJson()).toList()));
        await prefs.setInt(_timestampKey, _clock().millisecondsSinceEpoch);
      }
    } catch (_) {
      // Network or parse failure: keep cached or built-in data.
    }
  }

  (List<JobCategory>, List<District>)? _readCache(SharedPreferences prefs) {
    try {
      final rawCats = prefs.getString(_categoriesKey);
      final rawDists = prefs.getString(_districtsKey);
      if (rawCats == null || rawDists == null) return null;
      final cats = (jsonDecode(rawCats) as List)
          .map((e) => JobCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final dists = (jsonDecode(rawDists) as List)
          .map((e) => District.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (cats.isEmpty || dists.isEmpty) return null;
      return (cats, dists);
    } catch (_) {
      return null;
    }
  }

  void _apply(List<JobCategory> cats, List<District> dists,
      {required bool remote}) {
    _categories = List.unmodifiable(cats);
    _districts = List.unmodifiable(dists);
    _fromRemote = remote;
    _index();
    notifyListeners();
  }

  void _index() {
    _categoryById
      ..clear()
      ..addEntries(_categories.map((c) => MapEntry(c.id, c)));
    _districtById
      ..clear()
      ..addEntries(_districts.map((d) => MapEntry(d.id, d)));
    _categoryByName.clear();
    for (final c in _categories) {
      for (final name in [c.nameAz, c.nameRu, c.nameEn, c.slug]) {
        _categoryByName.putIfAbsent(normalizeAz(name), () => c);
      }
    }
    _districtCandidates.clear();
    for (final d in _districts) {
      final names = <String>{
        normalizeAz(d.nameAz),
        normalizeAz(d.nameEn),
        normalizeAz(d.nameRu),
        normalizeAz(d.slug),
      }..removeWhere((n) => n.length < 3);
      for (final n in names) {
        _districtCandidates.add(MapEntry(n, d));
      }
    }
    _districtCandidates
        .sort((a, b) => b.key.length.compareTo(a.key.length));
  }

  JobCategory? categoryById(int? id) => id == null ? null : _categoryById[id];
  District? districtById(int? id) => id == null ? null : _districtById[id];

  static int? asId(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  JobCategory? categoryForText(String? text) {
    final key = normalizeAz(text);
    if (key.isEmpty) return null;
    final direct = _categoryByName[key];
    if (direct != null) return direct;
    final slug = legacyCategoryAliases[key];
    if (slug == null) return null;
    for (final c in _categories) {
      if (c.slug == slug) return c;
    }
    return null;
  }

  /// Matches geocoder / free text to a district; "Bakı" alone never matches.
  District? matchDistrict(String? text) {
    final key = normalizeAz(text);
    if (key.isEmpty) return null;
    for (final entry in _districtCandidates) {
      if (entry.key == key) return entry.value;
    }
    for (final entry in _districtCandidates) {
      if (containsWords(key, entry.key)) return entry.value;
    }
    return null;
  }

  /// Coarse central-Baku guess used only when the geocoder gives no district.
  District? districtFromLocation(double lat, double lng) {
    String? slug;
    if (lat >= 40.40 && lng >= 49.86) {
      slug = 'narimanov';
    } else if (lat >= 40.37 && lat < 40.40 && lng >= 49.83 && lng < 49.86) {
      slug = '28-may';
    } else if (lat >= 40.36 && lng < 49.84) {
      slug = 'yasamal';
    } else if (lat >= 40.39 && lng < 49.81) {
      slug = 'nizami';
    } else if (lat < 40.37 && lng >= 49.84) {
      slug = 'xetai';
    }
    if (slug == null) return null;
    for (final d in _districts) {
      if (d.slug == slug) return d;
    }
    return null;
  }

  JobCategory? categoryOfJob(Map<String, dynamic> job) =>
      categoryById(asId(job['category_id'])) ??
      categoryForText(job['category']?.toString());

  District? districtOfJob(Map<String, dynamic> job) =>
      districtById(asId(job['district_id'])) ??
      matchDistrict(job['district']?.toString());

  /// Localized category name, or the legacy text; never a raw id or "General".
  String categoryLabel(Map<String, dynamic> job, {String fallback = ''}) {
    final c = categoryOfJob(job);
    if (c != null) return c.localizedName(appLang.currentLanguage);
    final text = job['category']?.toString().trim() ?? '';
    if (text.isEmpty || text == 'General') return fallback;
    return text;
  }

  String districtLabel(Map<String, dynamic> job, {String fallback = ''}) {
    final d = districtOfJob(job);
    if (d != null) return d.localizedName(appLang.currentLanguage);
    final text = job['district']?.toString().trim() ?? '';
    if (text.isEmpty) return fallback;
    return text;
  }

  /// Filter match: by category_id, falling back to text for rows without an id.
  bool categoryMatches(Map<String, dynamic> job, JobCategory selected) {
    final id = asId(job['category_id']);
    if (id != null) return id == selected.id;
    final text = job['category']?.toString() ?? '';
    final byText = categoryForText(text);
    if (byText != null) return byText.id == selected.id;
    final key = normalizeAz(text);
    if (key.isEmpty) return false;
    final name = normalizeAz(selected.nameAz);
    return key.contains(name) || name.contains(key);
  }
}
