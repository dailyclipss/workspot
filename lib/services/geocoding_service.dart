import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AddressSuggestion {
  const AddressSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.district,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final String? district;
}

/// Address autocomplete (forward) and reverse geocoding on top of the
/// OpenStreetMap Nominatim API, which allows browser (CORS) requests.
class GeocodingService {
  GeocodingService._();

  static const String _base = 'https://nominatim.openstreetmap.org';

  static Future<List<AddressSuggestion>> search(String query, {String lang = 'az'}) async {
    final text = query.trim();
    if (text.length < 3) return const [];
    try {
      final uri = Uri.parse('$_base/search').replace(queryParameters: {
        'q': text,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '6',
        'countrycodes': 'az',
        'accept-language': lang,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body);
      if (data is! List) return const [];
      final results = <AddressSuggestion>[];
      for (final item in data) {
        if (item is! Map) continue;
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lng = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lng == null) continue;
        results.add(AddressSuggestion(
          displayName: item['display_name']?.toString() ?? text,
          latitude: lat,
          longitude: lng,
          district: _districtOf(item['address']),
        ));
      }
      return results;
    } catch (e) {
      debugPrint('GeocodingService.search failed: $e');
      return const [];
    }
  }

  static Future<AddressSuggestion?> reverse(double lat, double lng, {String lang = 'az'}) async {
    try {
      final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
        'accept-language': lang,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map || data['display_name'] == null) return null;
      return AddressSuggestion(
        displayName: data['display_name'].toString(),
        latitude: lat,
        longitude: lng,
        district: _districtOf(data['address']),
      );
    } catch (e) {
      debugPrint('GeocodingService.reverse failed: $e');
      return null;
    }
  }

  static String? _districtOf(dynamic address) {
    if (address is! Map) return null;
    for (final key in const ['city_district', 'suburb', 'borough', 'district']) {
      final value = address[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
