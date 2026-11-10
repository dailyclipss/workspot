class District {
  static const String kindRayon = 'rayon';
  static const String kindArea = 'area';
  static const String kindCity = 'city';

  final int id;
  final String slug;
  final String nameAz;
  final String nameRu;
  final String nameEn;
  final String city;
  final String kind;
  final int sort;

  const District({
    required this.id,
    required this.slug,
    required this.nameAz,
    required this.nameRu,
    required this.nameEn,
    required this.city,
    required this.kind,
    this.sort = 0,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: (json['id'] as num).toInt(),
      slug: json['slug'].toString(),
      nameAz: json['name_az'].toString(),
      nameRu: json['name_ru'].toString(),
      nameEn: json['name_en'].toString(),
      city: json['city'].toString(),
      kind: json['kind'].toString(),
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name_az': nameAz,
        'name_ru': nameRu,
        'name_en': nameEn,
        'city': city,
        'kind': kind,
        'sort': sort,
      };

  String localizedName(String lang) {
    switch (lang) {
      case 'ru':
        return nameRu;
      case 'en':
        return nameEn;
      default:
        return nameAz;
    }
  }
}
