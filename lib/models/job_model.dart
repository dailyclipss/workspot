class JobModel {
  final String id;
  final String businessName;
  final String category;
  final String district;
  final String instagram;
  final String phoneWhatsapp;
  final String contactPerson;
  final bool hasVacancy;
  final String salary;
  final String schedule;
  final String address;
  final double latitude;
  final double longitude;
  final String responseStatus;
  final String adStatus;
  final DateTime lastCheckedAt;
  final double distanceMeters;
  final bool isVip;

  JobModel({
    required this.id,
    String? businessName,
    String? category,
    String? district,
    String? instagram,
    String? phoneWhatsapp,
    String? contactPerson,
    bool? hasVacancy,
    String? salary,
    String? schedule,
    String? address,
    double? latitude,
    double? longitude,
    String? responseStatus,
    String? adStatus,
    DateTime? lastCheckedAt,
    double? distanceMeters,
    bool? isVip,
    String? title,
    String? companyName,
    String? employmentType,
    double? salaryAmount,
    double? lat,
    double? lng,
  })  : businessName = businessName ?? companyName ?? title ?? 'Məkan / Şirkət',
        category = category ?? 'General',
        district = district ?? '',
        instagram = instagram ?? '',
        phoneWhatsapp = phoneWhatsapp ?? '',
        contactPerson = contactPerson ?? '',
        hasVacancy = hasVacancy ?? true,
        salary = salary ?? (salaryAmount != null ? salaryAmount.toStringAsFixed(0) : '0'),
        schedule = schedule ?? employmentType ?? 'Tam iş günü',
        address = address ?? '',
        latitude = latitude ?? lat ?? 40.3725,
        longitude = longitude ?? lng ?? 49.8372,
        responseStatus = responseStatus ?? '',
        adStatus = adStatus ?? '',
        lastCheckedAt = lastCheckedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        distanceMeters = distanceMeters ?? 0.0,
        isVip = isVip ?? false;

  String get title => businessName;
  String get companyName => businessName;
  String get employmentType => schedule;
  double get salaryAmount => double.tryParse(salary.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.')) ?? 0.0;
  double get lat => latitude;
  double get lng => longitude;
  bool get isVerified => adStatus == 'active' && hasVacancy;

  static String _stringValue(Map<String, dynamic> json, List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  static bool _boolValue(Map<String, dynamic> json, List<String> keys, [bool fallback = false]) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is bool) return value;
      final normalized = value.toString().trim().toLowerCase();
      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }
    return fallback;
  }

  static DateTime _dateTimeValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is DateTime) return value;
      final parsed = DateTime.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    final rawLat = json['latitude'] ?? json['lat'];
    final rawLng = json['longitude'] ?? json['lng'];
    final fetchedLat = rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '') ?? 40.3725;
    final fetchedLng = rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '') ?? 49.8372;

    return JobModel(
      id: json['id']?.toString() ?? '',
      businessName: _stringValue(json, ['business_name', 'company_name', 'company', 'title'], 'Məkan / Şirkət'),
      category: _stringValue(json, ['category'], 'General'),
      district: _stringValue(json, ['district'], ''),
      instagram: _stringValue(json, ['instagram'], ''),
      phoneWhatsapp: _stringValue(json, ['phone_whatsapp', 'phone', 'whatsapp'], ''),
      contactPerson: _stringValue(json, ['contact_person'], ''),
      hasVacancy: _boolValue(json, ['has_vacancy', 'is_vacancy'], true),
      salary: _stringValue(json, ['salary'], _stringValue(json, ['salary_amount'], '0')),
      schedule: _stringValue(json, ['schedule', 'employment_type', 'job_type'], 'Tam iş günü'),
      address: _stringValue(json, ['address'], ''),
      latitude: fetchedLat,
      longitude: fetchedLng,
      responseStatus: _stringValue(json, ['response_status'], ''),
      adStatus: _stringValue(json, ['ad_status', 'status'], ''),
      lastCheckedAt: _dateTimeValue(json, ['last_checked_at', 'updated_at', 'created_at']),
      distanceMeters: (json['dist_meters'] as num?)?.toDouble() ?? 0.0,
      isVip: _boolValue(json, ['is_vip'], false),
    );
  }
}