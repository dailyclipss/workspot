import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/theme_service.dart';
import '../services/app_language.dart';
import 'add_job_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeMapScreen extends StatefulWidget {
  const HomeMapScreen({super.key});

  @override
  State<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends State<HomeMapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'all';
  double _radiusKm = 10.0;
  bool _isFilterOpen = false;
  bool _isSatelliteMode = false;
  String _selectedJobType = 'all';
  RangeValues _salaryRange = const RangeValues(300, 3000);
  bool _showOnlyVerified = false;

  final LatLng _userLocation = const LatLng(40.3750, 49.8430);

  final List<String> _categories = [
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

  final List<Map<String, dynamic>> _allJobs = [
    {
      'id': 'job_1',
      'company_name': 'Anadolu Restaurant',
      'title': 'Baş Ofisiant / Garson',
      'salary': 600,
      'salary_text': '600 - 800 ₼',
      'category': 'cat_catering',
      'job_type': 'full_time',
      'point': const LatLng(40.3772, 49.8381),
      'address': 'Puşkin küç. 14, Bakı',
      'is_verified': true,
      'rating': 4.8,
      'views': 240,
      'posted_time': '2 saat əvvəl',
      'icon': Icons.restaurant_rounded,
      'description': 'Təcrübəli baş ofisiant tələb olunur. Növbəli iş qrafiki, pulsuz nahar verilir.',
    },
    {
      'id': 'job_2',
      'company_name': 'Urban Cafe Baku',
      'title': 'Barista / Qəhvə Ustası',
      'salary': 650,
      'salary_text': '650 ₼',
      'category': 'cat_catering',
      'job_type': 'full_time',
      'point': const LatLng(40.3750, 49.8430),
      'address': 'Nizami küç. 83 (Tarqovı)',
      'is_verified': true,
      'rating': 4.9,
      'views': 410,
      'posted_time': 'Dünən',
      'icon': Icons.local_cafe_rounded,
      'description': 'Espresso maşınları ilə işləməyi bacaran pozitiv barista axtarırıq.',
    },
    {
      'id': 'job_3',
      'company_name': 'Coffee Moffie',
      'title': 'Kassa Operatoru',
      'salary': 550,
      'salary_text': '550 ₼',
      'category': 'cat_catering',
      'job_type': 'part_time',
      'point': const LatLng(40.3725, 49.8405),
      'address': 'Rəşid Behbudov küç. 22',
      'is_verified': false,
      'rating': 4.5,
      'views': 180,
      'posted_time': '3 gün əvvəl',
      'icon': Icons.coffee_rounded,
      'description': 'R-Keeper proqramını bilən gənc və dinamik kassa operatoru.',
    },
    {
      'id': 'job_4',
      'company_name': 'Zara (Port Baku)',
      'title': 'Satış Məsləhətçisi',
      'salary': 800,
      'salary_text': '800 - 1000 ₼',
      'category': 'cat_sales',
      'job_type': 'full_time',
      'point': const LatLng(40.3740, 49.8580),
      'address': 'Port Baku Mall, 1-ci mərtəbə',
      'is_verified': true,
      'rating': 4.7,
      'views': 890,
      'posted_time': '5 saat əvvəl',
      'icon': Icons.checkroom_rounded,
      'description': 'Geyim mağazasında müştərilərə xidmət və geyimlərin nizamlanması.',
    },
    {
      'id': 'job_5',
      'company_name': 'Wolt Azerbaijan',
      'title': 'Kuryer (Moped / Avto)',
      'salary': 1200,
      'salary_text': '1000 - 1500 ₼',
      'category': 'cat_logistics',
      'job_type': 'part_time',
      'point': const LatLng(40.3690, 49.8480),
      'address': 'Səbail rayonu, Bakı',
      'is_verified': true,
      'rating': 4.6,
      'views': 1200,
      'posted_time': 'Bugün',
      'icon': Icons.delivery_dining_rounded,
      'description': 'Sərbəst iş qrafiki ilə kuryer fəaliyyəti. Gündəlik ödəniş imkanı.',
    },
    {
      'id': 'job_6',
      'company_name': 'Matrix Software',
      'title': 'Flutter Developer',
      'salary': 2200,
      'salary_text': '2000 - 2500 ₼',
      'category': 'cat_it',
      'job_type': 'remote',
      'point': const LatLng(40.3810, 49.8250),
      'address': 'Jalə Plaza, 8-ci mərtəbə',
      'is_verified': true,
      'rating': 5.0,
      'views': 650,
      'posted_time': '1 saat əvvəl',
      'icon': Icons.code_rounded,
      'description': 'Dart, Flutter, REST API və Supabase təcrübəsi olan proqramçı axtarılır.',
    },
  ];

  double _calculateDistance(LatLng point1, LatLng point2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((point2.latitude - point1.latitude) * p) / 2 +
        c(point1.latitude * p) *
            c(point2.latitude * p) *
            (1 - c((point2.longitude - point1.longitude) * p)) /
            2;
    return (12742 * asin(sqrt(a))).toDouble();
  }

  List<Map<String, dynamic>> get _filteredJobs {
    final query = _searchController.text.toLowerCase().trim();
    return _allJobs.where((job) {
      if (query.isNotEmpty) {
        final title = job['title'].toString().toLowerCase();
        final company = job['company_name'].toString().toLowerCase();
        if (!title.contains(query) && !company.contains(query)) return false;
      }

      if (_selectedCategory != 'all' && job['category'] != _selectedCategory) {
        return false;
      }

      final distance = _calculateDistance(_userLocation, job['point']);
      if (distance > _radiusKm) return false;

      if (_selectedJobType != 'all' && job['job_type'] != _selectedJobType) {
        return false;
      }

      final salary = (job['salary'] as num).toDouble();
      if (salary < _salaryRange.start || salary > _salaryRange.end) {
        return false;
      }

      if (_showOnlyVerified && job['is_verified'] != true) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filteredList = _filteredJobs;

    return ListenableBuilder(
      listenable: appLang,
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _userLocation,
                  initialZoom: 13.8,
                  minZoom: 9,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: _isSatelliteMode
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.workspot.app',
                    maxZoom: 19,
                  ),
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _userLocation,
                        radius: _radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: const Color(0xFF2563EB).withOpacity(0.08),
                        borderColor: const Color(0xFF2563EB).withOpacity(0.4),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userLocation,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: filteredList.map((job) {
                      return Marker(
                        point: job['point'],
                        width: 125,
                        height: 60,
                        child: GestureDetector(
                          onTap: () => _showJobDetailsBottomSheet(job, isDark),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: job['is_verified'] == true
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey.shade400,
                                    width: 1.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(job['icon'], size: 14, color: const Color(0xFF2563EB)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${job['salary']} ₼',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (job['is_verified'] == true) ...[
                                      const SizedBox(width: 3),
                                      const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF2563EB)),
                                    ]
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B).withOpacity(0.94)
                              : Colors.white.withOpacity(0.94),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.search_rounded, color: Color(0xFF2563EB), size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: appLang.translate('search_hint'),
                                  hintStyle: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isFilterOpen ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                                color: _isFilterOpen ? const Color(0xFF2563EB) : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isFilterOpen = !_isFilterOpen;
                                });
                              },
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, size: 21),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB), size: 23),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AddJobScreen()),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_outline_rounded, size: 21),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),
                    if (_isFilterOpen)
                      Container(
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
                                Text(
                                  appLang.translate('filter_title'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _radiusKm = 10.0;
                                      _selectedJobType = 'all';
                                      _salaryRange = const RangeValues(300, 3000);
                                      _showOnlyVerified = false;
                                      _selectedCategory = 'all';
                                    });
                                  },
                                  child: Text(
                                    appLang.translate('reset'),
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  appLang.translate('search_radius'),
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                                ),
                                Text(
                                  '${_radiusKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                            Slider(
                              value: _radiusKm,
                              min: 1.0,
                              max: 30.0,
                              divisions: 29,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() {
                                  _radiusKm = val;
                                });
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  appLang.translate('salary_range'),
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                                ),
                                Text(
                                  '${_salaryRange.start.round()} ₼ - ${_salaryRange.end.round()} ₼',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                ),
                              ],
                            ),
                            RangeSlider(
                              values: _salaryRange,
                              min: 200,
                              max: 5000,
                              divisions: 48,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (values) {
                                setState(() {
                                  _salaryRange = values;
                                });
                              },
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip('all', appLang.translate('all_modes'), isDark),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('full_time', appLang.translate('full_time'), isDark),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('part_time', appLang.translate('part_time'), isDark),
                                  const SizedBox(width: 6),
                                  _buildFilterChip('remote', appLang.translate('remote'), isDark),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final catKey = _categories[index];
                          final isSelected = _selectedCategory == catKey;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              selected: isSelected,
                              showCheckmark: false,
                              label: Text(
                                appLang.translate(catKey),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.grey[300] : const Color(0xFF0F172A)),
                                ),
                              ),
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B).withOpacity(0.9)
                                  : Colors.white.withOpacity(0.9),
                              selectedColor: const Color(0xFF2563EB),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                                ),
                              ),
                              onSelected: (val) {
                                setState(() {
                                  _selectedCategory = catKey;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 16,
                bottom: 24,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'sat_toggle',
                      backgroundColor: _isSatelliteMode ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      foregroundColor: _isSatelliteMode ? Colors.white : const Color(0xFF2563EB),
                      tooltip: _isSatelliteMode ? appLang.translate('vector_mode') : appLang.translate('satellite_mode'),
                      child: Icon(_isSatelliteMode ? Icons.map_rounded : Icons.satellite_alt_rounded),
                      onPressed: () {
                        setState(() {
                          _isSatelliteMode = !_isSatelliteMode;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'list_view',
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      foregroundColor: const Color(0xFF2563EB),
                      child: const Icon(Icons.format_list_bulleted_rounded),
                      onPressed: () {
                        _showJobsListBottomSheet(filteredList, isDark);
                      },
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'my_loc',
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.my_location_rounded),
                      onPressed: () {
                        _mapController.move(_userLocation, 14.5);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label, bool isDark) {
    final isSelected = _selectedJobType == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]))),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
      onSelected: (selected) {
        setState(() {
          _selectedJobType = value;
        });
      },
    );
  }

  void _showJobDetailsBottomSheet(Map<String, dynamic> job, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(job['icon'], color: const Color(0xFF2563EB), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              job['company_name'],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            if (job['is_verified'] == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2563EB)),
                            ]
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job['title'],
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appLang.translate('salary_label'),
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        Text(
                          job['salary_text'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          appLang.translate('posted_label'),
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        Text(
                          job['posted_time'],
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                appLang.translate('job_info'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                job['description'],
                style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${job['company_name']} profilinə keçid tezliklə aktiv olacaq!'),
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                        );
                      },
                      icon: const Icon(Icons.business_rounded, size: 18),
                      label: Text(appLang.translate('company_profile')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${job['title']} ${appLang.translate('applied_msg')}'),
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: Text(appLang.translate('apply_now'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        minimumSize: const Size(0, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  void _showJobsListBottomSheet(List<Map<String, dynamic>> jobs, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${appLang.translate('found_jobs')} (${jobs.length})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
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
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              leading: Icon(job['icon'], color: const Color(0xFF2563EB)),
                              title: Text(job['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${job['company_name']} • ${job['address']}', style: const TextStyle(fontSize: 12)),
                              trailing: Text('${job['salary']} ₼', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                              onTap: () {
                                Navigator.pop(context);
                                _mapController.move(job['point'], 16);
                                _showJobDetailsBottomSheet(job, isDark);
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