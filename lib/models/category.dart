class JobCategory {
  final int id;
  final String slug;
  final String nameAz;
  final String nameRu;
  final String nameEn;
  final String? icon;
  final int sort;

  const JobCategory({
    required this.id,
    required this.slug,
    required this.nameAz,
    required this.nameRu,
    required this.nameEn,
    this.icon,
    this.sort = 0,
  });

  factory JobCategory.fromJson(Map<String, dynamic> json) {
    return JobCategory(
      id: (json['id'] as num).toInt(),
      slug: json['slug'].toString(),
      nameAz: json['name_az'].toString(),
      nameRu: json['name_ru'].toString(),
      nameEn: json['name_en'].toString(),
      icon: json['icon']?.toString(),
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name_az': nameAz,
        'name_ru': nameRu,
        'name_en': nameEn,
        'icon': icon,
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
