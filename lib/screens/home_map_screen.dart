import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_maps_cluster_manager_2/google_maps_cluster_manager_2.dart' as cm;
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:google_maps_flutter/google_maps_flutter.dart' hide Cluster, ClusterManager;
import 'package:url_launcher/url_launcher.dart';
import 'admin_dashboard_screen.dart';
import '../core/services/application_service.dart';
import '../models/job_model.dart';
import '../services/app_language.dart';
import '../services/location_service.dart';
import '../services/job_location_resolver.dart';
import 'add_job_screen.dart' hide LatLng;
import 'company_details_screen.dart';
import 'notifications_screen.dart';
import 'payment_checkout_screen.dart';
import 'profile_screen.dart';
import '../services/payment_service.dart';

class _CategoryMeta {
  final Color color;
  final IconData icon;
  const _CategoryMeta(this.color, this.icon);
}

class _JobClusterItem with cm.ClusterItem {
  final Map<String, dynamic> job;
  final LatLng point;

  _JobClusterItem({required this.job, required this.point});

  @override
  LatLng get location => point;
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

Widget _buildMarkerWidget(Map<String, dynamic> job) {
  // Safe bool parse for VIP/Verified status
  final isVip = job['is_vip'] == true ||
                job['is_vip'] == 1 ||
                job['is_vip'].toString().toLowerCase() == 'true' ||
                job['is_verified'] == true;

  final salary = job['salary'] ?? '0';

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF181A20),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isVip ? const Color(0xFF3B82F6) : const Color(0xFF3B82F6), // FORCED BLUE BORDER
        width: 1.5,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(_getCategoryIcon(job['category']), size: 12, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(
          '$salary ₼',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isVip) ...[
          const SizedBox(width: 4),
          const Icon(Icons.verified, size: 12, color: Color(0xFF3B82F6)),
        ],
      ],
    ),
  );
}

class HomeMapScreen extends StatefulWidget {
  final String? flashMessage;

  const HomeMapScreen({super.key, this.flashMessage});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> {
  static const LatLng _bakuYouthHubCenter = LatLng(40.3800, 49.8450);

  final ApplicationService _applicationService = ApplicationService();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  bool _isMapReady = false;
  LatLng _mapCenter = _bakuYouthHubCenter;
  LatLng? _currentUserLocation;
  double _currentZoom = 12.8;
  bool _isMapLoading = true;
  String? _mapDebugMessage;
  bool _isJobsLoading = false;
  MapType _currentMapType = MapType.normal;
  bool _isFilterOpen = false;
  String _selectedCategory = 'all';
  String _selectedJobType = 'all';
  double _radiusKm = 10.0;
  RangeValues _salaryRange = const RangeValues(300, 3000);
  bool _showOnlyVerified = false;
  final Map<String, BitmapDescriptor> _singleMarkerIcons = {};
  final Map<String, BitmapDescriptor> _clusterBadgeIcons = {};
  final Map<String, BitmapDescriptor> _jobBadgeIcons = {};
  Set<Marker> _jobMarkers = {};
  Set<Marker> _clusterMarkers = {};
  late final cm.ClusterManager<_JobClusterItem> _clusterManager;
  StreamSubscription<List<Map<String, dynamic>>>? _jobsSubscription;
  String? _selectedJobId;

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
    _clusterManager = cm.ClusterManager<_JobClusterItem>(
      const [],
      _updateClusterMarkers,
      markerBuilder: _clusterMarkerBuilder,
      stopClusteringZoom: 17.0,
      extraPercent: 0.20,
    );
    appLang.addListener(_onLanguageChanged);
    _loadUserLocation();
    _fetchMapJobs();
    _listenToJobs();
    Future<void>.delayed(const Duration(seconds: 8)).then((_) {
      if (!mounted || _isMapReady || (_mapDebugMessage?.isNotEmpty ?? false)) {
        return;
      }
      _setMapDebugMessage(
        'Google Maps has not initialized yet. Check the iOS API key and native startup logs.',
      );
    });
    if (widget.flashMessage != null && widget.flashMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.flashMessage!)),
        );
      });
    }
  }

  @override
  void dispose() {
    appLang.removeListener(_onLanguageChanged);
    _jobsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  void _setMapDebugMessage(String message) {
    debugPrint('[GoogleMaps][MapScreen] $message');
    if (!mounted) return;
    setState(() {
      _mapDebugMessage = message;
    });
  }

  void _clearMapDebugMessage() {
    if (!mounted || _mapDebugMessage == null) return;
    setState(() {
      _mapDebugMessage = null;
    });
  }

  Future<void> _fetchMapJobs() async {
    if (mounted) setState(() => _isJobsLoading = true);

    try {
      final response = await supabase.Supabase.instance.client
          .from('jobs')
          .select('*');
      debugPrint('TOTAL JOBS FROM SUPABASE: ${response.length}');

      final rawJobs = List<Map<String, dynamic>>.from(response);
      final jobs = _normalizeJobs(rawJobs);
      final activeJobs = jobs.where(_shouldShowJobOnMap).toList();
      final jobsMissingCoords = rawJobs.where((job) => _rawJobMissingCoordinates(job)).toList();
      print('Fetched ${activeJobs.length} total active jobs. Jobs missing lat/lng: ${jobsMissingCoords.map(_jobDebugLabel).join(', ')}');
      _allJobs = activeJobs.isEmpty ? _buildMockJobs() : activeJobs;
      _clearMapDebugMessage();
      await _rebuildJobMarkers(_allJobs);
    } catch (error) {
      debugPrint('Error fetching jobs: $error');
      _setMapDebugMessage('Job fetch error: $error');
      _allJobs = _buildMockJobs();
      await _rebuildJobMarkers(_allJobs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Elanlar yüklənmədi, demo məlumat göstərilir: $error')),
      );
    }

    if (!mounted) return;
    setState(() => _isJobsLoading = false);
    _syncClusterItems();
    debugPrint('LOADED JOBS COUNT: ${_allJobs.length}');
  }

  void _listenToJobs() {
    _jobsSubscription?.cancel();
    _jobsSubscription = supabase.Supabase.instance.client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .listen((rows) async {
      final normalizedJobs = _normalizeJobs(rows);
      final jobs = normalizedJobs.where(_shouldShowJobOnMap).toList();
      final missingCoords = rows.where((job) => _rawJobMissingCoordinates(Map<String, dynamic>.from(job))).toList();
      print('Fetched ${jobs.length} total active jobs. Jobs missing lat/lng: ${missingCoords.map((job) => _jobDebugLabel(Map<String, dynamic>.from(job))).join(', ')}');
      if (!mounted) return;
      _clearMapDebugMessage();
      setState(() {
        _allJobs = jobs;
        _isJobsLoading = false;
      });
      await _rebuildJobMarkers(jobs);
      _syncClusterItems();
    }, onError: (error) {
      debugPrint('Jobs stream error: $error');
      _setMapDebugMessage('Jobs stream error: $error');
    });
  }

  Future<void> _rebuildJobMarkers(List<Map<String, dynamic>> jobsList) async {
    final Set<Marker> newMarkers = {};
    LatLng? latestMarkerPosition;

    for (var job in jobsList) {
      final point = _jobPoint(job);

      if (point != null) {
        final position = point;
        latestMarkerPosition = position;
        final isVip = job['is_vip'] == true;
        final jobId = job['id']?.toString() ?? UniqueKey().toString();
        final salaryLabel = _formatMarkerSalary(job['salary']);
        final categoryIcon = _markerCategoryIcon(job);
        final markerKey = '$salaryLabel|$isVip|${categoryIcon.codePoint}|${categoryIcon.fontFamily}|${categoryIcon.fontPackage}';
        final icon = _jobBadgeIcons[markerKey] ??= await _buildPillMarker(job);
        newMarkers.add(
          Marker(
            markerId: MarkerId(jobId),
            position: position,
            infoWindow: InfoWindow.noText,
            icon: icon,
            onTap: () => _showJobBottomSheet(job),
          ),
        );
      } else {
        print('MAP MARKER SKIPPED: job=${_jobDebugLabel(job)} lat=${job['latitude']} lng=${job['longitude']} district=${job['district']} address=${job['address']}');
      }
    }

    if (!mounted) return;
    setState(() {
      _jobMarkers = Set<Marker>.from(newMarkers);
      _clusterMarkers = Set<Marker>.from(newMarkers);
    });
    print('LOG: Total active markers set on map: ${newMarkers.length}');

    if (latestMarkerPosition != null && _isMapReady && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(latestMarkerPosition, 14.5),
      );
    }
  }

  List<Map<String, dynamic>> _normalizeJobs(List<Map<String, dynamic>> rawJobs) {
    return rawJobs.map((job) {
      final normalizedJob = Map<String, dynamic>.from(job);
      normalizedJob['business_name'] ??=
          normalizedJob['company_name'] ?? normalizedJob['company'] ?? normalizedJob['title'];
      normalizedJob['company_name'] ??= normalizedJob['business_name'];
      normalizedJob['district'] ??= normalizedJob['area'] ?? '';
      normalizedJob['instagram'] ??= normalizedJob['instagram_url'] ?? '';
      normalizedJob['phone_whatsapp'] ??=
          normalizedJob['phone'] ?? normalizedJob['whatsapp'] ?? normalizedJob['phone_number'] ?? '';
      normalizedJob['contact_person'] ??= normalizedJob['contact_name'] ?? '';
      normalizedJob['has_vacancy'] ??= normalizedJob['is_vacancy'] ?? true;
      normalizedJob['is_vacancy'] ??= normalizedJob['has_vacancy'] ?? true;
      normalizedJob['salary'] ??= normalizedJob['salary_amount'];
      normalizedJob['schedule'] ??=
          normalizedJob['employment_type'] ?? normalizedJob['job_type'] ?? 'Tam iş günü';
      normalizedJob['job_type'] ??= normalizedJob['schedule'];
      normalizedJob['response_status'] ??= normalizedJob['response'] ?? '';
      normalizedJob['ad_status'] ??= normalizedJob['status'] ?? '';
      normalizedJob['is_active'] ??= _jobBool(normalizedJob['is_active']) ||
          ['active', 'approved'].contains(normalizedJob['ad_status']?.toString().toLowerCase().trim()) ||
          ['active', 'approved'].contains(normalizedJob['status']?.toString().toLowerCase().trim());
      normalizedJob['last_checked_at'] ??=
          normalizedJob['updated_at'] ?? normalizedJob['created_at'];
      final adStatus = normalizedJob['ad_status']?.toString().toLowerCase().trim() ?? '';
      final hasVacancy = _jobHasVacancy(normalizedJob);
      normalizedJob['is_verified'] ??= (adStatus == 'active' || _jobBool(normalizedJob['is_vip'])) && hasVacancy;

      final resolved = JobLocationResolver.resolve(
        district: normalizedJob['district']?.toString(),
        address: normalizedJob['address']?.toString(),
        latitude: _safeParseDouble(normalizedJob['latitude'] ?? normalizedJob['lat']),
        longitude: _safeParseDouble(normalizedJob['longitude'] ?? normalizedJob['lng']),
      );
      normalizedJob['latitude'] ??= resolved.latitude;
      normalizedJob['longitude'] ??= resolved.longitude;
      normalizedJob['point'] ??= resolved;

      if (_rawJobMissingCoordinates(job)) {
        debugPrint(
          'JOB SKIPPED (INVALID COORDS): '
          'ID=${normalizedJob['id']}, '
          'title=${normalizedJob['title']}, '
          'lat=${normalizedJob['latitude']}, lng=${normalizedJob['longitude']}',
        );
      }
      return normalizedJob;
    }).toList();
  }

  bool _shouldShowJobOnMap(Map<String, dynamic> job) {
    final adStatus = _jobText(job, 'ad_status', _jobText(job, 'status', '')).toLowerCase().trim();
    if (adStatus == 'rejected' || adStatus == 'deleted') return false;
    if (!_jobHasVacancy(job)) return false;
    final isActiveFlag = _jobBool(job['is_active']);
    return adStatus == 'active' || adStatus == 'approved' || isActiveFlag || _jobBool(job['is_vip']);
  }

  bool _rawJobMissingCoordinates(Map<String, dynamic> job) {
    final lat = _safeParseDouble(job['latitude'] ?? job['lat']);
    final lng = _safeParseDouble(job['longitude'] ?? job['lng']);
    return lat == null || lng == null || lat == 0.0 || lng == 0.0;
  }

  String _jobDebugLabel(Map<String, dynamic> job) {
    final id = job['id']?.toString() ?? '?';
    final title = _jobText(job, 'title', _jobText(job, 'business_name', 'unknown'));
    return '$id:$title';
  }

  Future<void> _loadUserLocation() async {
    try {
      final position = await LocationService.GetCurrentLocation();
      if (position != null) {
        _currentUserLocation = LatLng(position.latitude, position.longitude);
        _mapCenter = _currentUserLocation!;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isMapLoading = false);
      }
    }
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  Future<void> _recenterMyLocation() async {
    final target = _currentUserLocation ?? _mapCenter;
    if (_isMapReady && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, 14.5),
      );
    }
  }

  void _moveTo(LatLng target, double zoom) {
    if (_isMapReady && _mapController != null) {
  _mapController!.animateCamera(
    CameraUpdate.newLatLngZoom(target, zoom.toDouble()),
  );
}
  }

  double _calculateDistance(LatLng first, LatLng second) {
    const degreesToRadians = 0.017453292519943295;
    final value = 0.5 -
      math.cos((second.latitude - first.latitude) * degreesToRadians) / 2 +
      math.cos(first.latitude * degreesToRadians) *
        math.cos(second.latitude * degreesToRadians) *
        (1 - math.cos((second.longitude - first.longitude) * degreesToRadians)) /
            2;
    return 12742 * math.asin(math.sqrt(value));
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

  String _jobSalaryString(Map<String, dynamic> job) {
    final value = job['salary'] ?? job['salary_text'] ?? job['salary_amount'];
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      final salary = _jobSalary(job);
      return salary <= 0 ? 'Razılaşma ilə' : '${salary.round()} ₼';
    }
    return text.contains('₼') ? text : '$text ₼';
  }

  String _jobBusinessName(Map<String, dynamic> job) {
    return _jobText(job, 'business_name', _jobText(job, 'company_name', _jobText(job, 'title', 'Şirkət')));
  }

  String _jobDistrict(Map<String, dynamic> job) {
    return _jobText(job, 'district', '');
  }

  String _jobSchedule(Map<String, dynamic> job) {
    return _jobText(job, 'schedule', _jobText(job, 'job_type', _jobText(job, 'employment_type', 'Tam iş günü')));
  }

  String _jobPhoneWhatsapp(Map<String, dynamic> job) {
    return _jobText(job, 'phone_whatsapp', _jobText(job, 'phone', _jobText(job, 'whatsapp', '')));
  }

  String _jobInstagram(Map<String, dynamic> job) {
    return _jobText(job, 'instagram', '');
  }

  bool _jobHasVacancy(Map<String, dynamic> job) {
    final value = job['has_vacancy'] ?? job['is_vacancy'] ?? true;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    return ['true', '1', 'yes', 'y'].contains(normalized);
  }

  bool _jobBool(dynamic value) {
    if (value is bool) return value;
    return ['true', '1', 'yes', 'y'].contains(value?.toString().toLowerCase().trim());
  }

  bool _jobIsVerified(Map<String, dynamic> job) {
    final adStatus = _jobText(job, 'ad_status', _jobText(job, 'status', '')).toLowerCase();
    return adStatus == 'active' && _jobHasVacancy(job);
  }

  String _jobResponseStatus(Map<String, dynamic> job) {
    return _jobText(job, 'response_status', '');
  }

  String _jobAddress(Map<String, dynamic> job) {
    return _jobText(job, 'address', appLang.translate('city_baku'));
  }

  String _jobLocationSummary(Map<String, dynamic> job) {
    final district = _jobDistrict(job).trim();
    final address = _jobAddress(job).trim();
    if (district.isNotEmpty && address.isNotEmpty) {
      return '$district • $address';
    }
    return district.isNotEmpty ? district : address;
  }

  String _jobContactPerson(Map<String, dynamic> job) {
    return _jobText(job, 'contact_person', '');
  }

  Future<void> _launchPhoneAction(
    String phone, {
    bool useWhatsApp = false,
  }) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = useWhatsApp
        ? Uri.parse('https://wa.me/${digits.replaceAll('+', '')}')
        : Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchInstagram(String instagram) async {
    if (instagram.trim().isEmpty) return;
    final value = instagram.trim();
    final uri = value.startsWith('http')
        ? Uri.parse(value)
        : Uri.parse('https://instagram.com/${value.replaceAll('@', '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _jobSalaryLabel(Map<String, dynamic> job) {
    final salary = _jobSalary(job);
    return salary <= 0 ? 'Razılaşma ilə' : '${salary.round()} ₼';
  }

  List<Map<String, dynamic>> get _jobs => _allJobs;

  List<_JobClusterItem> _buildClusterItems() {
    return _jobs.where((job) {
      return _jobPoint(job) != null && _shouldShowJobOnMap(job);
    }).map((job) {
      final point = _jobPoint(job)!;
      return _JobClusterItem(job: job, point: point);
    }).toList();
  }

  void _syncClusterItems() {
    final items = _buildClusterItems();
    _clusterManager.setItems(items);
    if (_isMapReady) {
      _clusterManager.updateMap();
    }
  }

  void _updateClusterMarkers(Set<Marker> markers) {
    if (!mounted) return;
    setState(() {
      _clusterMarkers = markers;
      _jobMarkers = {};
    });
    print('Loaded ${markers.length} markers to map');
  }

  String _singleMarkerKey(String salaryLabel, IconData icon) {
    return '$salaryLabel|${icon.codePoint}|${icon.fontFamily}|${icon.fontPackage}';
  }

  String _clusterBadgeKey(int count) => 'cluster|$count';

  Future<BitmapDescriptor> _buildPillMarker(Map<String, dynamic> job) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      throw StateError('No overlay available for marker rendering');
    }

    final double pixelRatio = 1.5;

    final GlobalKey boundaryKey = GlobalKey();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned(
          left: -10000,
          top: -10000,
          child: Material(
            color: Colors.transparent,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RepaintBoundary(
                key: boundaryKey,
                child: _buildMarkerWidget(job),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Failed to locate marker boundary');
      }

      final ui.Image image = await boundary.toImage(
        pixelRatio: pixelRatio,
      );
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Failed to encode marker bitmap');
      }
      return BitmapDescriptor.bytes(byteData.buffer.asUint8List());
    } finally {
      entry.remove();
    }
  }

  Future<Marker> _clusterMarkerBuilder(cm.Cluster<_JobClusterItem> cluster) async {
    if (cluster.isMultiple) {
      final key = _clusterBadgeKey(cluster.count);
      final icon = _clusterBadgeIcons[key] ??=
          BitmapDescriptor.bytes(await createClusterBadgeMarker(cluster.count));
      return Marker(
        markerId: MarkerId(cluster.getId()),
        position: cluster.location,
        anchor: const Offset(0.5, 0.5),
        icon: icon,
        infoWindow: InfoWindow.noText,
        onTap: () {
          final targetZoom = (_currentZoom + 2.0).clamp(0.0, 18.0).toDouble();
          _moveTo(cluster.location, targetZoom);
        },
      );
    }

    final item = cluster.items.first;
    final job = item.job;
    final jobId = job['id']?.toString() ?? cluster.getId();
    final isVip = job['is_vip'] == true;
    final salaryLabel = _formatMarkerSalary(job['salary']);
    final categoryIcon = _markerCategoryIcon(job);
    final icon = _singleMarkerIcons['$salaryLabel|$isVip|${categoryIcon.codePoint}|${categoryIcon.fontFamily}|${categoryIcon.fontPackage}'] ??= await _buildPillMarker(job);

    return Marker(
      markerId: MarkerId(jobId),
      position: item.location,
      anchor: const Offset(0.5, 1.0),
      icon: icon,
      infoWindow: InfoWindow.noText,
      onTap: () {
        setState(() => _selectedJobId = jobId);
        _showJobBottomSheet(job);
      },
    );
  }

  Future<Uint8List> createClusterBadgeMarker(int count) async {
    final label = count.toString();
    final textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double width = 36;
    const double height = 36;
    const double padding = 2;
    const double circleSize = 32;
    final double pixelRatio = 1.5;

    canvas.scale(pixelRatio, pixelRatio);
    canvas.translate(padding, padding);

    final bgPaint = Paint()
      ..color = const Color(0xFF181A20)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = const Offset(circleSize / 2, circleSize / 2);
    canvas.drawCircle(center, circleSize / 2, bgPaint);
    canvas.drawCircle(center, circleSize / 2, borderPaint);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.layers.codePoint),
        style: TextStyle(
          fontFamily: Icons.layers.fontFamily,
          package: Icons.layers.fontPackage,
          color: const Color(0xFF38BDF8),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final contentWidth = iconPainter.width + 3 + textPainter.width;
    final startX = (circleSize - contentWidth) / 2;
    final iconY = (circleSize - iconPainter.height) / 2 - 0.5;
    final textY = (circleSize - textPainter.height) / 2 - 0.5;

    iconPainter.paint(canvas, Offset(startX, iconY));
    textPainter.paint(
      canvas,
      Offset(startX + iconPainter.width + 3, textY),
    );

    final image = await recorder.endRecording().toImage(
      (width * pixelRatio).ceil(),
      (height * pixelRatio).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
    final lat = double.tryParse(latitude?.toString() ?? '') ?? 0.0;
    final lng = double.tryParse(longitude?.toString() ?? '') ?? 0.0;
    if (lat == 0.0 || lng == 0.0) return null;
    return LatLng(lat, lng);
  }

  IconData _jobIcon(Map<String, dynamic> job) {
    return job['icon'] is IconData
        ? job['icon'] as IconData
        : Icons.work_outline_rounded;
  }

  String _formatMarkerSalary(dynamic salaryValue) {
    final raw = salaryValue?.toString().trim() ?? '';
    if (raw.isEmpty) return '0 ₼';

    final cleaned = raw
        .replaceAll(RegExp(r'\b(AZN|MANAT)\b', caseSensitive: false), '')
        .replaceAll('₼', '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.isEmpty ? '0 ₼' : '$cleaned ₼';
  }

  IconData _markerCategoryIcon(Map<String, dynamic> job) {
    final raw = [
      job['category'],
      job['category_id'],
      job['categoryId'],
      job['category_name'],
    ]
        .where((value) => value != null)
        .map((value) => value.toString().toLowerCase())
        .join(' ');

    bool hasAny(List<String> needles) => needles.any(raw.contains);

    if (hasAny(['courier', 'delivery', 'çatdır', 'logistics', 'logistika'])) {
      return Icons.two_wheeler;
    }
    if (hasAny(['cafe', 'barista', 'kafe', 'coffee'])) {
      return Icons.local_cafe;
    }
    if (hasAny(['restaurant', 'waiter', 'restoran', 'garson'])) {
      return Icons.restaurant;
    }
    if (hasAny(['retail', 'clothes', 'fashion', 'satış', 'shop', 'store'])) {
      return Icons.checkroom;
    }
    if (hasAny(['office', 'admin', 'ofis', 'inzibati', 'assistant', 'clerical'])) {
      return Icons.business_center;
    }
    if (hasAny(['tech', 'it', 'software', 'program', 'proqram', 'developer'])) {
      return Icons.laptop;
    }

    return Icons.work_outline;
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
        'business_name': job['companyName'] ?? 'Şirkət',
        'company_name': job['companyName'] ?? 'Şirkət',
        'title': job['title'] ?? 'Vakansiya',
        'district': '',
        'instagram': '',
        'phone_whatsapp': '',
        'contact_person': '',
        'has_vacancy': true,
        'salary': rawSalary,
        'salary_amount': salaryValue,
        'schedule': jobType == 'full_time' ? 'Tam iş günü' : 'Növbəli',
        'employment_type': jobType == 'full_time' ? 'Tam iş günü' : 'Növbəli',
        'salary_text': rawSalary,
        'category': category,
        'job_type': jobType,
        'point': LatLng(latitude, longitude),
        'address': job['address'] ?? 'Bakı',
        'response_status': 'responded',
        'ad_status': 'active',
        'last_checked_at': DateTime.now().toIso8601String(),
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
      if (point == null || !_shouldShowJobOnMap(job)) return false;
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

  void _showJobBottomSheet(Map<String, dynamic> job) {
    _centerAndShowJob(job);
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
        Widget mapSurface;
        try {
          mapSurface = RepaintBoundary(
            child: _isMapLoading
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _bakuYouthHubCenter,
                      zoom: 12.8,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      try {
                        _clusterManager.setMapId(controller.mapId);
                        setState(() {
                          _isMapReady = true;
                        });
                        _mapController = controller;
                        _clearMapDebugMessage();
                        _syncClusterItems();
                      } catch (error) {
                        _setMapDebugMessage('Map initialization error: $error');
                      }
                    },
                    onCameraMove: (cameraPosition) {
                      try {
                        _currentZoom = cameraPosition.zoom;
                        _mapCenter = cameraPosition.target;
                        _clusterManager.onCameraMove(cameraPosition);
                      } catch (error) {
                        _setMapDebugMessage('Map camera update error: $error');
                      }
                    },
                    onCameraIdle: () {
                      try {
                        _clusterManager.updateMap();
                      } catch (error) {
                        _setMapDebugMessage('Map cluster update error: $error');
                      }
                    },
                    markers: _clusterMarkers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    mapType: _currentMapType,
                  ),
          );
        } catch (error) {
          _setMapDebugMessage('Map build error: $error');
          mapSurface = Container(
            color: const Color(0xFF0F172A),
            alignment: Alignment.center,
            child: const Icon(Icons.map_outlined, color: Colors.white54, size: 44),
          );
        }

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: mapSurface),
              if (_mapDebugMessage != null)
                Positioned(
                  left: 12,
                  right: 12,
                  top: MediaQuery.of(context).padding.top + 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1.0),
                      ),
                      child: Text(
                        _mapDebugMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
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
                      builder: (context) => const AdminDashboardScreen()),
                );
                if (mounted) await _fetchMapJobs();
              },
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
                if (mounted) await _fetchMapJobs();
              },
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
                  await _fetchMapJobs();
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
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                if (mounted) await _fetchMapJobs();
              },
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
                await _fetchMapJobs();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapActions(List<Map<String, dynamic>> jobs, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _MapActionButton(
          heroTag: 'satellite_toggle',
          icon: _currentMapType == MapType.normal
              ? Icons.satellite_alt_rounded
              : Icons.map_rounded,
          tooltip: _currentMapType == MapType.normal
              ? appLang.translate('satellite_mode')
              : appLang.translate('vector_mode'),
          onPressed: _toggleMapType,
          isActive: _currentMapType == MapType.satellite,
        ),
        const SizedBox(height: 10),
        _MapActionButton(
          heroTag: 'my_location',
          icon: Icons.my_location_rounded,
          tooltip: 'Mövqeyim',
          onPressed: _recenterMyLocation,
          isActive: false,
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _jobBusinessName(job),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (_jobIsVerified(job))
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.35)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 13, color: Color(0xFF22C55E)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Aktiv Vakansiya',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _jobText(job, 'category', 'General'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF60A5FA),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _jobTag(_jobDistrict(job).isEmpty ? _jobAddress(job) : _jobDistrict(job)),
                  _jobTag(_jobSchedule(job)),
                  _jobTag(_jobSalaryString(job)),
                  if (_jobResponseStatus(job).isNotEmpty) _jobTag(_jobResponseStatus(job)),
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
                      _jobLocationSummary(job),
                      style: const TextStyle(
                          color: Color(0xFFCBD5E1), fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (_jobContactPerson(job).isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        color: Color(0xFF64748B), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Əlaqədar şəxs: ${_jobContactPerson(job)}',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(
                _jobText(job, 'description', appLang.translate('no_description')),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchPhoneAction(
                        _jobPhoneWhatsapp(job),
                        useWhatsApp: true,
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded,
                          color: Colors.white, size: 17),
                      label: const Text('WhatsApp',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _launchPhoneAction(_jobPhoneWhatsapp(job)),
                      icon: const Icon(Icons.call_rounded,
                          color: Colors.white, size: 17),
                      label: const Text('Call',
                          style: TextStyle(color: Colors.white)),
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
              const SizedBox(height: 10),
              if (_jobInstagram(job).isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _launchInstagram(_jobInstagram(job)),
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D1B69), Color(0xFF7E22CE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF472B6).withOpacity(0.7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7E22CE).withOpacity(0.22),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              size: 17, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Instagram',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
          companyName: _jobBusinessName(job),
          companyJobs: [
            JobModel.fromJson(job),
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

class _MapActionButton extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  const _MapActionButton({
    required this.heroTag,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isActive
      ? const Color(0xFF2563EB).withValues(alpha: 0.96)
      : const Color(0xFF18181B).withValues(alpha: 0.78);

    return SizedBox(
      width: 46,
      height: 46,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}
