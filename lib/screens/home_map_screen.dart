import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
import 'profile_screen.dart';

typedef LatLng = latlong.LatLng;

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
  List<Marker> _markers = [];
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

  List<Map<String, dynamic>> _allJobs = [
    {
      'id': 'job_1',
      'status': 'active',
      'company_name': 'Anadolu Restaurant',
      'title': 'Baş Ofisiant / Garson',
      'salary': 600,
      'salary_text': '600 - 800 ₼',
      'category': 'cat_catering',
      'job_type': 'full_time',
      'point': const LatLng(40.3772, 49.8381),
      'address': 'Puşkin küç. 14, Bakı',
      'is_verified': true,
      'posted_time': '2 saat əvvəl',
      'icon': Icons.restaurant_rounded,
      'description':
          'Təcrübəli baş ofisiant tələb olunur. Növbəli iş qrafiki, pulsuz nahar verilir.',
    },
    {
      'id': 'job_2',
      'status': 'active',
      'company_name': 'Urban Cafe Baku',
      'title': 'Barista / Qəhvə Ustası',
      'salary': 650,
      'salary_text': '650 ₼',
      'category': 'cat_catering',
      'job_type': 'full_time',
      'point': const LatLng(40.3750, 49.8430),
      'address': 'Nizami küç. 83 (Tarqovı)',
      'is_verified': true,
      'posted_time': 'Dünən',
      'icon': Icons.local_cafe_rounded,
      'description':
          'Espresso maşınları ilə işləməyi bacaran pozitiv barista axtarırıq.',
    },
    {
      'id': 'job_3',
      'status': 'active',
      'company_name': 'Coffee Moffie',
      'title': 'Kassa Operatoru',
      'salary': 550,
      'salary_text': '550 ₼',
      'category': 'cat_catering',
      'job_type': 'part_time',
      'point': const LatLng(40.3725, 49.8405),
      'address': 'Rəşid Behbudov küç. 22',
      'is_verified': false,
      'posted_time': '3 gün əvvəl',
      'icon': Icons.coffee_rounded,
      'description':
          'R-Keeper proqramını bilən gənc və dinamik kassa operatoru.',
    },
    {
      'id': 'job_4',
      'status': 'active',
      'company_name': 'Zara (Port Baku)',
      'title': 'Satış Məsləhətçisi',
      'salary': 800,
      'salary_text': '800 - 1000 ₼',
      'category': 'cat_sales',
      'job_type': 'full_time',
      'point': const LatLng(40.3740, 49.8580),
      'address': 'Port Baku Mall, 1-ci mərtəbə',
      'is_verified': true,
      'posted_time': '5 saat əvvəl',
      'icon': Icons.checkroom_rounded,
      'description':
          'Geyim mağazasında müştərilərə xidmət və geyimlərin nizamlanması.',
    },
    {
      'id': 'job_5',
      'status': 'active',
      'company_name': 'Wolt Azerbaijan',
      'title': 'Kuryer (Moped / Avto)',
      'salary': 1200,
      'salary_text': '1000 - 1500 ₼',
      'category': 'cat_logistics',
      'job_type': 'part_time',
      'point': const LatLng(40.3690, 49.8480),
      'address': 'Səbail rayonu, Bakı',
      'is_verified': true,
      'posted_time': 'Bugün',
      'icon': Icons.delivery_dining_rounded,
      'description':
          'Sərbəst iş qrafiki ilə kuryer fəaliyyəti. Gündəlik ödəniş imkanı.',
    },
    {
      'id': 'job_6',
      'status': 'active',
      'company_name': 'Matrix Software',
      'title': 'Flutter Developer',
      'salary': 2200,
      'salary_text': '2000 - 2500 ₼',
      'category': 'cat_it',
      'job_type': 'remote',
      'point': const LatLng(40.3810, 49.8250),
      'address': 'Jalə Plaza, 8-ci mərtəbə',
      'is_verified': true,
      'posted_time': '1 saat əvvəl',
      'icon': Icons.code_rounded,
      'description':
          'Dart, Flutter, REST API və Supabase təcrübəsi olan proqramçı axtarılır.',
    },
  ];

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
        final List<Marker> newMarkers = [];
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
          newMarkers.add(
            Marker(
              point: latlong.LatLng(lat, lng),
              width: 45,
              height: 45,
              child: GestureDetector(
                onTap: () => _centerAndShowJob(normalizedJob),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getCategoryIcon(normalizedJob['category']?.toString()),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          );
        }
        return normalizedJob;
      }).toList();

      _allJobs = jobs;

      if (!mounted) return;
      setState(() {
        _markers = newMarkers;
        _isJobsLoading = false;
      });
      debugPrint('RENDERED MARKERS COUNT: ${_markers.length}');
    } catch (error) {
      debugPrint('Error fetching jobs: $error');
      if (!mounted) return;
      setState(() => _isJobsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Elanlar yüklənmədi: $error')),
      );
    }
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
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.workspot',
                          ),
                          MarkerLayer(markers: _markers),
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
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AddJobScreen())),
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
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          foregroundColor: const Color(0xFF2563EB),
          tooltip: _isSatelliteMode
              ? appLang.translate('vector_mode')
              : appLang.translate('satellite_mode'),
          onPressed: () => setState(() => _isSatelliteMode = !_isSatelliteMode),
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
