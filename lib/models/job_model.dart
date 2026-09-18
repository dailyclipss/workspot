class JobModel {
  final String id;
  final String title;
  final String companyName;
  final String category;
  final String employmentType;
  final double salaryAmount;
  final double lat;
  final double lng;
  final double distanceMeters;
  final bool isVip;

  JobModel({
    required this.id,
    required this.title,
    required this.companyName,
    required this.category,
    required this.employmentType,
    required this.salaryAmount,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    this.isVip = false,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    // PostGIS və ya standart LatLng oxunması
    double fetchedLat = 40.3725;
    double fetchedLng = 49.8372;

    if (json['lat'] != null && json['lng'] != null) {
      fetchedLat = (json['lat'] as num).toDouble();
      fetchedLng = (json['lng'] as num).toDouble();
    }

    return JobModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Vakansiya',
      companyName: json['company_name'] ?? 'Məkan / Şirkət',
      category: json['category'] ?? 'General',
      employmentType: json['employment_type'] ?? 'Tam iş günü',
      salaryAmount: (json['salary_amount'] as num?)?.toDouble() ?? 0.0,
      lat: fetchedLat,
      lng: fetchedLng,
      distanceMeters: (json['dist_meters'] as num?)?.toDouble() ?? 0.0,
      isVip: json['is_vip'] ?? false,
    );
  }
}