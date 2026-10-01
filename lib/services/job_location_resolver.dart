import 'package:google_maps_flutter/google_maps_flutter.dart';

class JobLocationResolver {
  static const LatLng fallbackCenter = LatLng(40.4093, 49.8671);

  static final Map<String, LatLng> _districtPoints = {
    'nərimanov': const LatLng(40.4001, 49.8523),
    'nerimanov': const LatLng(40.4001, 49.8523),
    'gənclik': const LatLng(40.4001, 49.8523),
    'genclik': const LatLng(40.4001, 49.8523),
    'gənclik mall': const LatLng(40.3980, 49.8550),
    'genclik mall': const LatLng(40.3980, 49.8550),
    '28 may': const LatLng(40.3798, 49.8472),
    'sahil': const LatLng(40.3705, 49.8450),
    'içərişəhər': const LatLng(40.3661, 49.8322),
    'icərişəhər': const LatLng(40.3661, 49.8322),
    'icerişəhər': const LatLng(40.3661, 49.8322),
    'nizami': const LatLng(40.3712, 49.8372),
    'elmlər': const LatLng(40.3745, 49.8135),
    'elmler': const LatLng(40.3745, 49.8135),
    'nizami m/s': const LatLng(40.3790, 49.8280),
    'köroğlu': const LatLng(40.4150, 49.8600),
    'koroğlu': const LatLng(40.4150, 49.8600),
    'koroglu': const LatLng(40.4150, 49.8600),
    'xətai': const LatLng(40.3770, 49.8750),
    'xetai': const LatLng(40.3770, 49.8750),
    'həzi aslanov': const LatLng(40.3960, 49.9540),
    'hezi aslanov': const LatLng(40.3960, 49.9540),
    '8 noyabr': const LatLng(40.4090, 49.8800),
    '20 yanvar': const LatLng(40.4040, 49.8250),
    'badamdar': const LatLng(40.3470, 49.8210),
    'yasamal': const LatLng(40.3950, 49.8080),
    'yasamal rayonu': const LatLng(40.3950, 49.8080),
    'binəqədi': const LatLng(40.4700, 49.8350),
    'bineqedi': const LatLng(40.4700, 49.8350),
    'sabunçu': const LatLng(40.4420, 49.9480),
    'sabuncu': const LatLng(40.4420, 49.9480),
    'suraxanı': const LatLng(40.4310, 49.9750),
    'suraxani': const LatLng(40.4310, 49.9750),
    'qaradağ': const LatLng(40.3000, 49.7330),
    'qaradag': const LatLng(40.3000, 49.7330),
    'nəsimi': const LatLng(40.3950, 49.8340),
    'nesimi': const LatLng(40.3950, 49.8340),
  };

  static LatLng resolve({
    String? district,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    if (latitude != null && longitude != null && latitude != 0 && longitude != 0) {
      return LatLng(latitude, longitude);
    }

    final searchSpace = <String>[
      district ?? '',
      address ?? '',
    ]
        .join(' ')
        .toLowerCase()
        .replaceAll('ə', 'e')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('ş', 's');

    for (final entry in _districtPoints.entries) {
      if (searchSpace.contains(entry.key)) {
        return entry.value;
      }
    }

    return fallbackCenter;
  }

  static Map<String, dynamic> ensureCoordinates(Map<String, dynamic> job) {
    final district = job['district']?.toString();
    final address = job['address']?.toString();
    final rawLat = job['latitude'];
    final rawLng = job['longitude'];
    final lat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '');
    final lng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '');
    final resolved = resolve(district: district, address: address, latitude: lat, longitude: lng);

    return <String, dynamic>{
      ...job,
      'latitude': resolved.latitude,
      'longitude': resolved.longitude,
      'point': resolved,
    };
  }
}