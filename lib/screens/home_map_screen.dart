import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../admin/admin_approval_screen.dart';
import '../core/services/application_service.dart';
import '../models/job_model.dart';
import '../services/app_language.dart';
import '../services/location_service.dart';
import 'add_job_screen.dart';
import 'company_details_screen.dart';
import 'notifications_screen.dart';
import 'payment_checkout_screen.dart';
import 'profile_screen.dart';
import '../services/payment_service.dart';

typedef LatLng = latlong.LatLng;

class _CategoryMeta {
  final Color color;
  final IconData icon;
  const _CategoryMeta(this.color, this.icon);
}

class _JobMarkerBadge extends StatefulWidget {
  final _CategoryMeta meta;
  final String salaryLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _JobMarkerBadge({
    required this.meta,
    required this.salaryLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_JobMarkerBadge> createState() => _JobMarkerBadgeState();
}

class _JobMarkerBadgeState extends State<_JobMarkerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        scale: widget.isSelected ? 1.1 : 1.0,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulse = widget.isSelected ? _pulseController.value : 0.0;
            final glowColor = Color.lerp(
              const Color(0xFF22D3EE),
              const Color(0xFF2563EB),
              pulse,
            )!;
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF121824).withOpacity(0.90),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isSelected ? glowColor : Colors.white24,
                    width: widget.isSelected ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                    if (widget.isSelected)
                      BoxShadow(
                        color: glowColor.withOpacity(0.3 + pulse * 0.3),
                        blurRadius: 12 + pulse * 8,
                        spreadRadius: 1 + pulse * 1.5,
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.meta.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(widget.meta.icon, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      widget.salaryLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  final ApplicationService _applicationService = ApplicationService();
  final TextEditingController _searchController = TextEditingController();

  final MapController _mapController = MapController();
  bool _isMapReady = false;
  LatLng _mapCenter = const LatLng(40.3750, 49.8430);
  bool _isMapLoading = true;
  bool _isJobsLoading = false;
  String? _selectedJobId;
  bool _isSatelliteMode = false;
  bool _isFilterOpen = false;
  String _selectedCategory = 'all';
  String _selectedJobType = 'all';
  double _radiusKm = 10.0;
  RangeValues _salaryRange = const RangeValues(300, 3000);
  bool _showOnlyVerified = false;

  final List<String> _categories = const [
    'all',
    'cat_catering',
    'cat_it',
    'cat_sales',
    'cat_logistics',
    'cat_customer_service',
    'cat_construction',
    'cat_education',
    'cat_medicine',
    'cat_beauty',
  ];

  final List<Map<String, dynamic>> mockJobs = [
    {
      'title': 'Barista / Kofe Mütəxəssisi',
      'companyName': 'Urban Cafe 28',
      'category': 'Kafe & Restoran',
      'salary': '600 - 800 AZN',
      'jobType': 'Tam iş günü',
      'address': '28 May küç., 28 Mall yaxınlığı',
      'latitude': 40.3798,
      'longitude': 49.8472,
      'description': 'Aktiv, mehriban və kofe hazırlamağı sevən barista axtarılır.',
      'imageUrl': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Kassir',
      'companyName': 'Baku Book & Stationery',
      'category': 'Satış & Retail',
      'salary': '550 - 650 AZN',
      'jobType': 'Tam iş günü',
      'address': '28 May m/s çıxışı',
      'latitude': 40.3805,
      'longitude': 49.8490,
      'description': 'Kassa aparatları ilə işləyə bilən diqqətli əməkdaş.',
      'imageUrl': 'https://images.unsplash.com/photo-1556742049-0a670f4a4591',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Florist / Çiçək Dizayneri',
      'companyName': 'Rose Boutique',
      'category': 'Xidmət & Dizayn',
      'salary': '600 - 900 AZN',
      'jobType': 'Tam iş günü',
      'address': 'Rəşid Behbudov küç.',
      'latitude': 40.3770,
      'longitude': 49.8420,
      'description': 'Gül buketlərinin və kompozisiyalarının yığılması.',
      'imageUrl': 'https://images.unsplash.com/photo-1561181286-d3fee7d55364',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Satıcı-Məsləhətçi',
      'companyName': 'Trendy Fashion Store',
      'category': 'Satış & Retail',
      'salary': '500 - 700 AZN + %',
      'jobType': 'Növbəli',
      'address': 'Nizami küç. (Torqovaya)',
      'latitude': 40.3712,
      'longitude': 49.8372,
      'description': 'Geyim mağazasına aktiv satış təmsilçisi tələb olunur.',
      'imageUrl': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Hostess / Qonaq Qarşılayan',
      'companyName': 'Anadolu Restaurant',
      'category': 'Kafe & Restoran',
      'salary': '600 - 750 AZN',
      'jobType': 'Növbəli',
      'address': 'Puşkin küç., Sahil m/s',
      'latitude': 40.3705,
      'longitude': 49.8450,
      'description': 'Restorana gələn qonaqların qarşılanması və masalara yönləndirilməsi.',
      'imageUrl': 'https://images.unsplash.com/photo-1560066984-138dadb4c035',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Qəlyanaltı / Fast Food Ustası',
      'companyName': 'Burger House',
      'category': 'Kafe & Restoran',
      'salary': '650 - 800 AZN',
      'jobType': 'Tam iş günü',
      'address': 'Fəvvarələr Meydanı',
      'latitude': 40.3725,
      'longitude': 49.8360,
      'description': 'Burger və fast-food təamlarının hazırlanması.',
      'imageUrl': 'https://images.unsplash.com/photo-1550547660-d9450f859349',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Ofisiant (Part-time)',
      'companyName': 'Coffee Moffie',
      'category': 'Kafe & Restoran',
      'salary': '400 - 600 AZN + Çay pulu',
      'jobType': 'Yarım iş günü',
      'address': 'Elmlər Akademiyası m/s yaxınlığı',
      'latitude': 40.3745,
      'longitude': 49.8135,
      'description': 'Tələbələr üçün dərslərdən sonra 4-5 saatlıq rahat iş qrafiki.',
      'imageUrl': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Kopyalama və Print Operatoru',
      'companyName': 'Copy Center Elmlər',
      'category': 'Xidmət',
      'salary': '450 - 550 AZN',
      'jobType': 'Növbəli',
      'address': 'Hüseyn Cavid pr.',
      'latitude': 40.3720,
      'longitude': 49.8150,
      'description': 'Tələbə sənədlərinin çapı və kopyalanması xidməti.',
      'imageUrl': 'https://images.unsplash.com/photo-1562654501-a0ccc0fc3fb1',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Piyada Kuryer',
      'companyName': 'Express Delivery',
      'category': 'Çatdırılma',
      'salary': '600 - 900 AZN',
      'jobType': 'Sərbəst qrafik',
      'address': 'Nəriman Nərimanov m/s',
      'latitude': 40.4028,
      'longitude': 49.8711,
      'description': 'Şəhər mərkəzində kiçik bağlamaların çatdırılması.',
      'imageUrl': 'https://images.unsplash.com/photo-1526367790999-0150786686a2',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'SMM & Kontent Menecer',
      'companyName': 'Creative Agency Studio',
      'category': 'Marketing / Media',
      'salary': '700 - 1000 AZN',
      'jobType': 'Hibrid',
      'address': 'Təbriz küç., Nərimanov',
      'latitude': 40.4050,
      'longitude': 49.8680,
      'description': 'Reels/TikTok kontentləri hazırlayacaq kreativ komanda üzvü.',
      'imageUrl': 'https://images.unsplash.com/photo-1531482615713-2afd69097998',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Məhsul Qablaşdırıcısı',
      'companyName': 'SuperMarket Network',
      'category': 'Anbar & Logistika',
      'salary': '500 - 600 AZN',
      'jobType': 'Tam iş günü',
      'address': 'Gənclik m/s, Atatürk pr.',
      'latitude': 40.4001,
      'longitude': 49.8523,
      'description': 'Vitrinlərin düzülməsi və məhsulların qablaşdırılması.',
      'imageUrl': 'https://images.unsplash.com/photo-1578916171728-46686eac8d58',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Fitness Konsultant',
      'companyName': 'Ganjlik Gym & Sport',
      'category': 'İdman & Sağlamlıq',
      'salary': '600 - 850 AZN',
      'jobType': 'Növbəli',
      'address': 'Gənclik Mall yaxınlığı',
      'latitude': 40.3980,
      'longitude': 49.8550,
      'description': 'Zala gelen müştərilərin qarşılanması və abunəlik satışı.',
      'imageUrl': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Resepsionist',
      'companyName': 'City Beauty Studio',
      'category': 'Xidmət',
      'salary': '600 - 750 AZN',
      'jobType': 'Növbəli',
      'address': 'İçərişəhər m/s yaxınlığı',
      'latitude': 40.3661,
      'longitude': 49.8322,
      'description': 'Gözəllik salonuna qonaqları qarşılayacaq əməkdaş.',
      'imageUrl': 'https://images.unsplash.com/photo-1560066984-138dadb4c035',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Qrafik Dizayner (Junior)',
      'companyName': 'Print Art Baku',
      'category': 'Dizayn',
      'salary': '500 - 700 AZN',
      'jobType': 'Tam iş günü',
      'address': 'Nizami m/s, Cəfər Cabbarlı',
      'latitude': 40.3790,
      'longitude': 49.8280,
      'description': 'Sosial media postlarının və reklam banerlərinin hazırlanması.',
      'imageUrl': 'https://images.unsplash.com/photo-1626785774573-4b799315345d',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Satış Təmsilçisi',
      'companyName': 'Auto Care Center',
      'category': 'Avto & Xidmət',
      'salary': '700 - 1000 AZN',
      'jobType': 'Tam iş günü',
      'address': 'Xətai m/s, Xocalı pr.',
      'latitude': 40.3830,
      'longitude': 49.8720,
      'description': 'Avto aksesuarların və ehtiyat hissələrinin satışı.',
      'imageUrl': 'https://images.unsplash.com/photo-1580273916550-e323be2ae537',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Ofis Meneceri',
      'companyName': 'White City Logistics',
      'category': 'Ofis & İnzibati',
      'salary': '700 - 900 AZN',
      'jobType': 'Tam iş günü',
      'address': 'Ağ Şəhər (White City)',
      'latitude': 40.3775,
      'longitude': 49.8890,
      'description': 'Zənglərin cavablandırılması və ofis daxili sənədləşmə.',
      'imageUrl': 'https://images.unsplash.com/photo-1497366216548-37526070297c',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Apotek Satıcısı / Əczaçı',
      'companyName': 'Zəfəran Aptek',
      'category': 'Səhiyyə & Tibb',
      'salary': '600 - 800 AZN',
      'jobType': 'Növbəli',
      'address': 'İnşaatçılar m/s çıxışı',
      'latitude': 40.3890,
      'longitude': 49.8030,
      'description': 'Dərman vasitələrinin satışı və müştəri konsultasiyası.',
      'imageUrl': 'https://images.unsplash.com/photo-1586015555751-63c205a30620',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Call Center Operatoru',
      'companyName': 'Baku Telecom Partner',
      'category': 'Xidmət & Zəng Mərkəzi',
      'salary': '500 - 650 AZN',
      'jobType': 'Növbəli',
      'address': 'Yasamal, Şərifzadə küç.',
      'latitude': 40.3840,
      'longitude': 49.8080,
      'description': 'Gələn zənglərin qəbulu və sualların cavablandırılması.',
      'imageUrl': 'https://images.unsplash.com/photo-1534536281715-e28d76689b4d',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Anbar Fəhləsi / Anbardar',
      'companyName': 'Baku Depot Park',
      'category': 'Anbar & Logistika',
      'salary': '550 - 700 AZN',
      'jobType': 'Tam iş günü',
      'address': 'Koroğlu m/s yaxınlığı',
      'latitude': 40.4210,
      'longitude': 49.9180,
      'description': 'Anbara gələn malların qəbulu və boşaldılması.',
      'imageUrl': 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d',
      'createdAt': DateTime.now().toIso8601String(),
    },
    {
      'title': 'Avtoyuyan / Detailer',
      'companyName': 'VIP Car Wash',
      'category': 'Xidmət',
      'salary': '600 - 1000 AZN (Faizlə)',
      'jobType': 'Tam iş günü',
      'address': 'Heydər Əliyev pr.',
      'latitude': 40.4120,
      'longitude': 49.9010,
      'description': 'Nəqliyyat vasitələrinin kimyəvi təmizlənməsi və yuyulması.',
      'imageUrl': 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f',
      'createdAt': DateTime.now().toIso8601String(),
    },
  ];

  List<Map<String, dynamic>> _allJobs = [];

  @override
  void initState() {
    super.initState();
    appLang.addListener(_onLanguageChanged);
    _loadUserLocation();
    _fetchJobs();
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchJobs() async {
    if (mounted) setState(() => _isJobsLoading = true);

    try {
      final response = await supabase.Supabase.instance.client
          .from('jobs')
          .select();
      debugPrint('TOTAL JOBS FROM SUPABASE: ${response.length}');

      final jobs = List<Map<String, dynamic>>.from(response).map((job) {
        final normalizedJob = Map<String, dynamic>.from(job);
        normalizedJob['company_name'] ??= normalizedJob['company'];
        normalizedJob['job_type'] ??= normalizedJob['employment_type'];
        normalizedJob['salary'] ??= normalizedJob['salary_amount'];

        final rawLat = normalizedJob['latitude'] ?? normalizedJob['lat'];
        final rawLng = normalizedJob['longitude'] ?? normalizedJob['lng'];
        final lat = double.tryParse(rawLat?.toString() ?? '');
        final lng = double.tryParse(rawLng?.toString() ?? '');
        if (lat == null || lng == null) {
          debugPrint(
            'JOB SKIPPED (INVALID COORDS): '
            'ID=${normalizedJob['id']}, '
            'title=${normalizedJob['title']}, '
            'lat=$rawLat, lng=$rawLng',
          );
        } else {
          normalizedJob['point'] = LatLng(lat, lng);
        }
        return normalizedJob;
      }).toList();

      _allJobs = jobs.isEmpty ? _buildMockJobs() : jobs;
    } catch (error) {
      debugPrint('Error fetching jobs: $error');
      _allJobs = _buildMockJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Elanlar yüklənmədi, demo məlumat göstərilir: $error')),
      );
    }

    if (!mounted) return;
    setState(() => _isJobsLoading = false);
    debugPrint('LOADED JOBS COUNT: ${_allJobs.length}');
  }

  Future<void> _loadUserLocation() async {
    Position? position;
    try {
      position = await LocationService.GetCurrentLocation();
    } catch (_) {
      position = null;
    } finally {
      if (mounted) {
        setState(() {
          _mapCenter = position == null
              ? const LatLng(40.3750, 49.8430)
              : LatLng(position.latitude, position.longitude);
          _isMapLoading = false;
        });
      }
    }

    if (mounted && position != null) _moveTo(_mapCenter, 14.0);
  }

  void _moveTo(LatLng target, double zoom) {
    if (_isMapReady) _mapController.move(target, zoom);
  }

  double _calculateDistance(LatLng first, LatLng second) {
    const degreesToRadians = 0.017453292519943295;
    final value = 0.5 -
        cos((second.latitude - first.latitude) * degreesToRadians) / 2 +
        cos(first.latitude * degreesToRadians) *
            cos(second.latitude * degreesToRadians) *
            (1 - cos((second.longitude - first.longitude) * degreesToRadians)) /
            2;
    return 12742 * asin(sqrt(value));
  }

  String _jobText(Map<String, dynamic> job, String key, String fallback) {
    final value = job[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  double? _safeParseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double _jobSalary(Map<String, dynamic> job) {
    final value = job['salary'] ?? job['salary_amount'];
    return _safeParseDouble(value) ?? 0.0;
  }

  String _jobSalaryLabel(Map<String, dynamic> job) {
    final salary = _jobSalary(job);
    return salary <= 0 ? 'Razılaşma ilə' : '${salary.round()} ₼';
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Restoran & Kafeler':
        return Icons.restaurant;
      case 'İT & Proqramlaşdırma':
        return Icons.code;
      case 'Satış & Marketinq':
        return Icons.shopping_bag;
      case 'Logistika & Çatdırılma':
        return Icons.local_shipping;
      case 'Müştəri Xidmətləri':
        return Icons.headset_mic;
      case 'Tikinti & Təmir':
        return Icons.construction;
      case 'Təhsil & Tədris':
        return Icons.school;
      case 'Səhiyyə & Tibb':
        return Icons.medical_services;
      case 'Gözəllik & Salonda İş':
        return Icons.content_cut;
      default:
        return Icons.work;
    }
  }

  LatLng? _jobPoint(Map<String, dynamic> job) {
    final point = job['point'];
    if (point is LatLng) return point;
    final latitude = (job['latitude'] ?? job['lat']);
    final longitude = (job['longitude'] ?? job['lng']);
    final lat = _safeParseDouble(latitude);
    final lng = _safeParseDouble(longitude);
    return lat == null || lng == null ? null : LatLng(lat, lng);
  }

  IconData _jobIcon(Map<String, dynamic> job) {
    return job['icon'] is IconData
        ? job['icon'] as IconData
        : Icons.work_outline_rounded;
  }

  _CategoryMeta _categoryMeta(String? rawCategory) {
    final normalized = (rawCategory ?? '').toLowerCase();
    bool has(String needle) => normalized.contains(needle);

    if (has('it') || has('proqram') || has('software')) {
      return const _CategoryMeta(Color(0xFF00E676), Icons.code_rounded);
    }
    if (has('restoran') || has('kafe') || has('catering')) {
      return const _CategoryMeta(Color(0xFFFF6D00), Icons.restaurant_rounded);
    }
    if (has('sat') || has('marketinq') || has('marketing')) {
      return const _CategoryMeta(Color(0xFF2979FF), Icons.storefront_rounded);
    }
    if (has('səhiyyə') || has('tibb') || has('medicine') || has('health')) {
      return const _CategoryMeta(
          Color(0xFF00E5FF), Icons.medical_services_rounded);
    }
    if (has('logistika') || has('anbar') || has('çatdırılma') || has('logistics')) {
      return const _CategoryMeta(
          Color(0xFFD500F9), Icons.local_shipping_rounded);
    }
    if (has('müştəri') || has('customer') || has('zəng') || has('xidmət')) {
      return const _CategoryMeta(Color(0xFF2979FF), Icons.headset_mic_rounded);
    }
    if (has('tikinti') || has('construction') || has('inşaat')) {
      return const _CategoryMeta(
          Color(0xFFFFAB00), Icons.construction_rounded);
    }
    if (has('təhsil') || has('education')) {
      return const _CategoryMeta(Color(0xFFD500F9), Icons.school_rounded);
    }
    if (has('gözəllik') || has('beauty') || has('salon') || has('idman')) {
      return const _CategoryMeta(
          Color(0xFFFF5252), Icons.content_cut_rounded);
    }
    return const _CategoryMeta(Color(0xFF2979FF), Icons.work_rounded);
  }

  List<Marker> _buildMarkers() {
    return _allJobs.where((job) => _jobPoint(job) != null).map((job) {
      final point = _jobPoint(job)!;
      final jobId = job['id']?.toString();
      final isSelected =
          _selectedJobId != null && _selectedJobId == jobId;
      return Marker(
        point: latlong.LatLng(point.latitude, point.longitude),
        width: 130,
        height: 40,
        child: _JobMarkerBadge(
          meta: _categoryMeta(job['category']?.toString()),
          salaryLabel: _jobSalaryLabel(job),
          isSelected: isSelected,
          onTap: () {
            setState(() => _selectedJobId = jobId);
            _centerAndShowJob(job);
          },
        ),
      );
    }).toList();
  }

  Widget _buildClusterBadge(int count) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.7),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '+$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildMockJobs() {
    return mockJobs.map((job) {
      final rawCategory = job['category']?.toString() ?? 'Kafe & Restoran';
      final rawJobType = job['jobType']?.toString() ?? 'Tam iş günü';
      final rawSalary = job['salary']?.toString() ?? '0';
      final firstNumberMatch = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(rawSalary);
      final salaryValue = firstNumberMatch == null
          ? 0.0
          : double.tryParse(firstNumberMatch.group(0)!.replaceAll(',', '.')) ?? 0.0;

      final category = switch (rawCategory) {
        'Kafe & Restoran' => 'cat_catering',
        'Satış & Retail' => 'cat_sales',
        'Xidmət & Dizayn' || 'Xidmət' || 'Xidmət & Zəng Mərkəzi' => 'cat_customer_service',
        'Çatdırılma' || 'Anbar & Logistika' => 'cat_logistics',
        'Marketing / Media' => 'cat_it',
        'Ofis & İnzibati' => 'cat_customer_service',
        'Səhiyyə & Tibb' => 'cat_medicine',
        'İdman & Sağlamlıq' => 'cat_beauty',
        'Dizayn' || 'Avto & Xidmət' => 'cat_beauty',
        _ => 'cat_catering',
      };

      final jobType = switch (rawJobType) {
        'Tam iş günü' => 'full_time',
        'Yarım iş günü' => 'part_time',
        'Növbəli' => 'part_time',
        'Sərbəst qrafik' => 'part_time',
        'Hibrid' => 'remote',
        _ => 'full_time',
      };

      final latitude = (job['latitude'] is num) ? (job['latitude'] as num).toDouble() : 40.3750;
      final longitude = (job['longitude'] is num) ? (job['longitude'] as num).toDouble() : 49.8430;

      return {
        'id': 'demo_${mockJobs.indexOf(job) + 1}',
        'status': 'active',
        'company_name': job['companyName'] ?? 'Şirkət',
        'title': job['title'] ?? 'Vakansiya',
        'salary': salaryValue,
        'salary_text': rawSalary,
        'category': category,
        'job_type': jobType,
        'point': LatLng(latitude, longitude),
        'address': job['address'] ?? 'Bakı',
        'is_verified': true,
        'posted_time': 'Bugün',
        'icon': _getCategoryIcon(category),
        'description': job['description'] ?? 'Detallar göstərilir.',
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredJobs {
    final query = _searchController.text.toLowerCase().trim();
    return _allJobs.where((job) {
      final point = _jobPoint(job);
      if (point == null) return false;
      final title = _jobText(job, 'title', 'Vakansiya').toLowerCase();
      final company = _jobText(job, 'company_name', 'Şirkət').toLowerCase();
      final salary = _jobSalary(job);
      final distance = _calculateDistance(_mapCenter, point);

      return (query.isEmpty ||
              title.contains(query) ||
              company.contains(query)) &&
          distance <= _radiusKm &&
          (_selectedJobType == 'all' ||
              _jobText(job, 'job_type', 'Tam iş günü') == _selectedJobType) &&
          salary >= _salaryRange.start &&
          salary <= _salaryRange.end &&
          (!_showOnlyVerified || job['is_verified'] == true);
    }).toList();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Future<void> _centerAndShowJob(Map<String, dynamic> job) async {
    final point = _jobPoint(job);
    if (point == null) return;
    _moveTo(point, 16);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    _showJobDetailsBottomSheet(job);
  }

  Future<void> _applyForJob(Map<String, dynamic> job) async {
    Navigator.pop(context);

    try {
      final jobId = job['id']?.toString();
      if (jobId == null || jobId.isEmpty) {
        throw Exception('Vakansiya məlumatı tapılmadı');
      }
      if (await _applicationService.hasAlreadyApplied(jobId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Bu vakansiyaya artıq müraciət etmisiniz.')),
        );
        return;
      }

      await _applicationService.applyForJob(jobId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${job['title']} ${appLang.translate('applied_msg')}'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Müraciət göndərilmədi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appLang,
      builder: (context, child) {
        final isDark = _isDark;
        final filteredJobs = _filteredJobs;

        return Scaffold(
          body: Stack(
            children: [
              RepaintBoundary(
                child: _isMapLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const latlong.LatLng(40.4093, 49.8671),
                          initialZoom: 12.0,
                          onMapReady: () {
                            _isMapReady = true;
                            _moveTo(_mapCenter, 13);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: _isSatelliteMode
                                ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.workspot',
                          ),
                          MarkerClusterLayerWidget(
                            options: MarkerClusterLayerOptions(
                              maxClusterRadius: 55,
                              size: const Size(46, 46),
                              markers: _buildMarkers(),
                              builder: (context, clusterMarkers) =>
                                  _buildClusterBadge(clusterMarkers.length),
                            ),
                          ),
                        ],
                      ),
              ),
              RepaintBoundary(
                child: SafeArea(
                  child: Column(
                    children: [
                      _buildSearchBar(isDark),
                      if (_isFilterOpen) _buildFilterPanel(isDark),
                      _buildCategoryList(isDark),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 24,
                child: RepaintBoundary(
                  child: _buildMapActions(filteredJobs, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded,
                color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: appLang.translate('search_hint'),
                  hintStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isFilterOpen
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_outlined,
                color:
                    _isFilterOpen ? const Color(0xFF2563EB) : Colors.grey[700],
              ),
              onPressed: () => setState(() => _isFilterOpen = !_isFilterOpen),
            ),
            _buildVipBizButton(),
            IconButton(
              icon: const Icon(Icons.admin_panel_settings,
                  color: Colors.blueAccent),
              tooltip: 'Admin Paneli',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminApprovalScreen()),
                );
                if (mounted) await _fetchJobs();
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Color(0xFF2563EB)),
              onPressed: () async {
                try {
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddJobScreen()),
                  );
                  if (!mounted || !context.mounted) return;
                  await _fetchJobs();
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vakansiya ekranı açıla bilmədi: $error')),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.person_outline_rounded),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildVipBizButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: appLang.translate('vip_biznes_button'),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openVipBusinessCheckout,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE066), Color(0xFFB8860B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.55)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.45),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  void _openVipBusinessCheckout() {
    final userId =
        supabase.Supabase.instance.client.auth.currentUser?.id ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentCheckoutScreen(
          targetId: userId,
          targetType: PaymentTargetType.proSubscription,
        ),
      ),
    );
  }

  Widget _buildFilterPanel(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appLang.translate('filter_title'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              TextButton(
                onPressed: _resetFilters,
                child: Text(appLang.translate('reset'),
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appLang.translate('search_radius')),
              Text('${_radiusKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ],
          ),
          Slider(
            value: _radiusKm,
            min: 1,
            max: 30,
            divisions: 29,
            activeColor: const Color(0xFF2563EB),
            onChanged: (value) => setState(() => _radiusKm = value),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(appLang.translate('salary_range')),
              Text(
                  '${_salaryRange.start.round()} ₼ - ${_salaryRange.end.round()} ₼',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ],
          ),
          RangeSlider(
            values: _salaryRange,
            min: 200,
            max: 5000,
            divisions: 48,
            activeColor: const Color(0xFF2563EB),
            onChanged: (values) => setState(() => _salaryRange = values),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', appLang.translate('all_modes'), isDark),
                const SizedBox(width: 6),
                _buildFilterChip(
                    'full_time', appLang.translate('full_time'), isDark),
                const SizedBox(width: 6),
                _buildFilterChip(
                    'part_time', appLang.translate('part_time'), isDark),
                const SizedBox(width: 6),
                _buildFilterChip('remote', appLang.translate('remote'), isDark),
              ],
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yalnız təsdiqlənmiş elanlar'),
            value: _showOnlyVerified,
            onChanged: (value) => setState(() => _showOnlyVerified = value),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedJobType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      labelStyle:
          TextStyle(color: isSelected ? Colors.white : null, fontSize: 11),
      onSelected: (_) => setState(() => _selectedJobType = value),
    );
  }

  Widget _buildCategoryList(bool isDark) {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Text(appLang.translate(category)),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : const Color(0xFF0F172A)),
                fontSize: 12,
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              selectedColor: const Color(0xFF2563EB),
              onSelected: (_) async {
                setState(() => _selectedCategory = category);
                await _fetchJobs();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapActions(List<Map<String, dynamic>> jobs, bool isDark) {
    return Column(
      children: [
        FloatingActionButton.small(
          heroTag: 'refresh_jobs',
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: const Color(0xFF2563EB),
          tooltip: 'Elanları yenilə',
          onPressed: _isJobsLoading ? null : _fetchJobs,
          child: _isJobsLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'satellite_toggle',
          backgroundColor: _isSatelliteMode
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          foregroundColor:
              _isSatelliteMode ? Colors.white : const Color(0xFF2563EB),
          tooltip: _isSatelliteMode
              ? appLang.translate('vector_mode')
              : appLang.translate('satellite_mode'),
          onPressed: () {
            if (!mounted) return;
            setState(() => _isSatelliteMode = !_isSatelliteMode);
          },
          child: Icon(_isSatelliteMode
              ? Icons.map_rounded
              : Icons.satellite_alt_rounded),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.small(
          heroTag: 'job_list',
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: const Color(0xFF2563EB),
          tooltip: appLang.translate('found_jobs'),
          onPressed: () => _showJobsListBottomSheet(jobs, isDark),
          child: const Icon(Icons.format_list_bulleted_rounded),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'my_location',
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          tooltip: 'Mövqeyim',
          onPressed: () => _moveTo(_mapCenter, 14.5),
          child: const Icon(Icons.my_location_rounded),
        ),
      ],
    );
  }

  void _resetFilters() {
    setState(() {
      _radiusKm = 10;
      _selectedJobType = 'all';
      _salaryRange = const RangeValues(300, 3000);
      _showOnlyVerified = false;
      _selectedCategory = 'all';
    });
  }

  void _showJobDetailsBottomSheet(Map<String, dynamic> job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: SizedBox(
                  width: 38,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF64748B),
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _jobIcon(job),
                      color: const Color(0xFF60A5FA),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _jobText(job, 'title', 'Vakansiya'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _jobText(job, 'company_name', 'Şirkət'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _jobText(job, 'salary_text', '${_jobSalary(job)} AZN'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _jobTag(_jobText(job, 'job_type', 'Tam iş günü')),
                  const SizedBox(width: 8),
                    _jobTag(_jobText(
                      job, 'posted_time', appLang.translate('status_new'))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: Color(0xFF60A5FA), size: 19),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        _jobText(
                          job, 'address', appLang.translate('city_baku')),
                      style: const TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _jobText(
                  job, 'description', appLang.translate('no_description')),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openFullJobDetails(job);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF475569)),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(appLang.translate('view_details')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _applyForJob(job),
                      icon: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 17),
                      label: Text(appLang.translate('apply_now'),
                          style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _jobTag(String value) {
    final label = switch (value) {
      'full_time' || 'Tam iş günü' || 'Tam İş Qrafiki' =>
        appLang.translate('full_time'),
      'part_time' || 'Yarım iş günü' || 'Yarım İş Qrafiki' =>
        appLang.translate('part_time'),
      'remote' || 'Uzaqdan (Remote)' => appLang.translate('remote_work'),
      'Yeni' => appLang.translate('status_new'),
      _ => value,
    };
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
        ),
      ),
    );
  }

  void _openFullJobDetails(Map<String, dynamic> job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyDetailsScreen(
          companyName: _jobText(job, 'company_name', 'Şirkət'),
          companyJobs: [
            JobModel(
              id: job['id']?.toString() ?? '',
              title: _jobText(job, 'title', 'Vakansiya'),
              companyName: _jobText(job, 'company_name', 'Şirkət'),
              category: _jobText(job, 'category', 'Digər'),
              employmentType: _jobText(job, 'job_type', 'Tam iş günü'),
              salaryAmount: _jobSalary(job),
              lat: _jobPoint(job)?.latitude ?? 40.3725,
              lng: _jobPoint(job)?.longitude ?? 49.8372,
              distanceMeters: 0,
            ),
          ],
        ),
      ),
    );
  }

  void _showJobsListBottomSheet(List<Map<String, dynamic>> jobs, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('${appLang.translate('found_jobs')} (${jobs.length})',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 12),
              Expanded(
                child: jobs.isEmpty
                    ? Center(child: Text(appLang.translate('no_jobs_found')))
                    : ListView.builder(
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            child: ListTile(
                              leading: Icon(_jobIcon(job),
                                  color: const Color(0xFF2563EB)),
                              title: Text(_jobText(job, 'title', 'Vakansiya'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              subtitle: Text(
                                  '${_jobText(job, 'company_name', 'Şirkət')} • ${_jobText(job, 'address', 'Bakı')}',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Text('${job['salary']} ₼',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB))),
                              onTap: () {
                                Navigator.pop(sheetContext);
                                _centerAndShowJob(job);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
